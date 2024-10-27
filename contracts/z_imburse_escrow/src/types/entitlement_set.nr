use aztec::{
    context::{PrivateContext, UnconstrainedContext},
    encrypted_logs::{
        encrypted_note_emission::{encode_and_encrypt_note, encode_and_encrypt_note_unconstrained},
        encrypted_event_emission::{encode_and_encrypt_event, encode_and_encrypt_event_unconstrained}
    },
    keys::{getters::get_public_keys, public_keys::NpkM},
    note::{
        note_getter_options::{NoteStatus, NoteGetterOptions},
        note_viewer_options::NoteViewerOptions,
        constants::MAX_NOTES_PER_PAGE,
        note_getter::view_notes,
        note_emission::OuterNoteEmission
    },
    prelude::{NoteInterface, NullifiableNote, PrivateSet, Map},
    protocol_types::{
        constants::MAX_NOTE_HASH_READ_REQUESTS_PER_CALL,
        address::AztecAddress
    },
    utils::comparison::Comparator
};
use std::option::Option;
use crate::types::entitlement_note::EntitlementNote;

pub struct EntitlementSet<T, Context> {
    set: Map<AztecAddress, PrivateSet<T, Context>, Context>
}

impl<T, Context> EntitlementSet<T, Context> {
    pub fn new(context: Context, storage_slot: Field) -> Self {
        assert(storage_slot != 0, "Storage slot 0 not allowed. Storage slots must start from 1.");
        Self {
            set: Map::new(
                context,
                storage_slot,
                |context, slot| PrivateSet::new(context, slot)
            )
        }
    }
}

impl<T> EntitlementSet<T, UnconstrainedContext> {

    /**
     * Get entitlements stored in the PXE that match a set of criteria
     *
     * @param offset - the index of the first entitlement to return
     * @param scope - the storage scope of the entitlements to return (have to map so that txe collisions dont happen - might be worth removing to optimize?)
     * @param recipient - if included, restrict return to only entitlements that have the recipient set as this address
     * @param verifier_id - if included, restrict return to only entitlements that have the verifier_id set as this value
     * @param spot - if included and true, only return spot entitlements. if included and false, only return non-spot entitlements. If not included, return all entitlements
     * @return -
     *         0: The entitlements that match the criteria
     *         1: Whether or not there are more entitlements to fetch (will result in empty return on next call if exact # of entitlements % 10 = 0)
     */
    unconstrained pub fn view_entitlements<let T_SERIALIZED_LEN: u32>(
        self: Self,
        offset: u32,
        scope: AztecAddress,
        recipient: Option<AztecAddress>,
        verifier_id: Option<u8>,
        spot: Option<bool>
    ) -> (BoundedVec<T, MAX_NOTES_PER_PAGE>, bool) where T: NoteInterface<T_SERIALIZED_LEN> + NullifiableNote + Eq {
        let mut options = NoteViewerOptions::new()
            .set_offset(offset)
            .set_limit(MAX_NOTES_PER_PAGE)
            .set_status(NoteStatus.ACTIVE);
        // optionally select by recipient
        if recipient.is_some() {
            options.select(
                EntitlementNote::properties().recipient,
                Comparator.EQ,
                recipient.unwrap()
            )
        }
        // optionally select by verifier_id
        if verifier_id.is_some() {
            options.select(
                EntitlementNote::properties().verifier_id,
                Comparator.EQ,
                verifier_id.unwrap()
            )
        }
        // optionally select by spot
        if spot.is_some() {
            options.select(
                EntitlementNote::properties().spot,
                Comparator.EQ,
                spot.unwrap()
            )
        }
        // retrieve notes
        let notes = self.set.at(scope).view_notes(options);
        (notes, notes.len() == MAX_NOTES_PER_PAGE)
    }
}

impl<T> EntitlementSet<T, &mut PrivateContext> {

    /**
     * Determine if a given recipient has a matching spot/ recurring entitlement for a given verifier type
     *
     * @param scope - the storage scope of the entitlements to check
     * @param recipient - the address of the recipient to check
     * @param verifier_id - the verifier id to check for
     * @param spot - if true, check for spot entitlements. If false, check for recurring entitlements
     * @return - true if a matching entitlement is found, false otherwise
     */
    pub fn get_matching_entitlement<let T_SERIALIZED_LEN: u32>(
        self,
        scope: AztecAddress,
        recipient: AztecAddress,
        verifier_id: u8,
        spot: bool
    ) -> Option<T> where T: NoteInterface<T_SERIALIZED_LEN> + NullifiableNote + Eq {
        // get note matching criteria
        let options = NoteGetterOptions::new()
            .select(
                EntitlementNote::properties().recipient,
                Comparator.EQ,
                recipient
            ).select(
                EntitlementNote::properties().verifier_id,
                Comparator.EQ,
                verifier_id
            ).select(
                EntitlementNote::properties().spot,
                Comparator.EQ,
                spot
            ).set_limit(1);
        let notes = self.set.at(scope).get_notes(options);
        // return note if found
        if notes.len() > 0 {
            Option::some(notes.get_unchecked(0))
        } else {
            Option::none()
        }
    }

    /**
     * Add an entitlement for a recipient and also register it for the admin (who cannot spend it but can nullify it)
     *
     * @param admin - the address of the admin to register the entitlement for
     * @param recipient - the address of the recipient of the entitlement
     * @param note - the entitlement note to add
     */
    pub fn add_entitlement_with_receipt<let T_SERIALIZED_LEN: u32>(
        self,
        context: &mut PrivateContext,
        admin: AztecAddress,
        recipient: AztecAddress,
        note: &mut T
    ) where T: NoteInterface<T_SERIALIZED_LEN> + NullifiableNote + Eq {
        // encryption/ nullifier keys keys for admin and recipient
        let recipient_keys = get_public_keys(recipient);
        let admin_keys = get_public_keys(admin);
        // add note to recipient set and receipt to admin set
        // admin really has little reason to lie here- technically they could but it would destroy their own reimbursement platform
        self.set.at(admin).insert(note).emit(encode_and_encrypt_note_unconstrained(context, admin_keys.ovpk_m, admin_keys.ivpk_m, admin));
        self.set.at(recipient).insert(note).emit(encode_and_encrypt_note_unconstrained(context, recipient_keys.ovpk_m, recipient_keys.ivpk_m, recipient));
    }

    /**
     * Pop a note from the entitlement set, destroying it in the process.
     * @dev constrained to assert the note exists
     * @dev does not emit event here as would require an if statement that can be avoided
     *
     * @param scope - the storage scope of the entitlements to check
     * @param recipient - the address of the recipient to check
     * @param verifier_id - the verifier id to check for
     * @param spot - if true, check for spot entitlements. If false, check for recurring entitlements
     * @return - the entitlement note that was popped
     */
    pub fn nullify_entitlement<let T_SERIALIZED_LEN: u32>(
        self,
        scope: AztecAddress,
        recipient: AztecAddress,
        verifier_id: u8,
        spot: bool
    ) -> T where T: NoteInterface<T_SERIALIZED_LEN> + NullifiableNote + Eq {
        // get note matching criteria
        let options = NoteGetterOptions::new()
            .select(
                EntitlementNote::properties().recipient,
                Comparator.EQ,
                recipient
            ).select(
                EntitlementNote::properties().verifier_id,
                Comparator.EQ,
                verifier_id
            ).select(
                EntitlementNote::properties().spot,
                Comparator.EQ,
                spot
            ).set_limit(1);
        let notes = self.set.at(scope).pop_notes(options);
        assert(notes.len() > 0, "No matching entitlement found");
        notes.get_unchecked(0)
    }
}
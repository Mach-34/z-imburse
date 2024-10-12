use dep::aztec::protocol_types::{
    address::AztecAddress,
    traits::{Serialize, Deserialize},
    constants::GENERATOR_INDEX__NOTE_NULLIFIER,
    hash::{poseidon2_hash_with_separator, poseidon2_hash_bytes},
    utils::field::field_from_bytes,
    scalar::Scalar,
    point::Point
};
use dep::aztec::note::utils::compute_note_hash_for_nullify;
use dep::aztec::oracle::random::random;
use dep::aztec::macros::notes::note_custom_interface;
use dep::aztec::prelude::{NoteHeader, NullifiableNote, NoteInterface, PrivateContext};
use dep::aztec::keys::{
    getters::{get_public_keys, get_nsk_app},
    point_to_symmetric_key::point_to_symmetric_key
};
use dep::compressed_string::CompressedString;
use std::embedded_curve_ops::multi_scalar_mul;
use std::hash::from_field_unsafe;
use dep::generators::GENERATORS;

// serializes verifier_id and max_value into one field element
global RECURRING_ENTITLEMENT_NOTE_LENGTH: u32 = 4;

#[note_custom_interface]
pub struct RecurringEntitlementNote {
    // admin of the escrow contract (really just needed to comply with interface)
    admin: AztecAddress,
    // the user that is allowed to use this entitlement
    recipient: AztecAddress,
    // basically a selector for which sk and pk to use when nullifying
    is_admin: bool,
    // the type of receipt verifier that this entitlement can be used for
    verifier_id: u8,
    // the maximum value that can be withdrawn from the escrow using this entitlement
    max_value: U128,
    // blinding factor for the note
    randomness: Field,
}

impl NoteInterface<RECURRING_ENTITLEMENT_NOTE_LENGTH> for RecurringEntitlementNote {
    
    fn serialize_content(self) -> [Field; RECURRING_ENTITLEMENT_NOTE_LENGTH] {
        // serialize max_value and verifier_id together
        let max_value_bytes: [u8; 16] = self.max_value.to_le_bytes();
        let mut packed_bytes: [u8; 18] = [0; 18];
        for i in 0..16 {
            packed_bytes[i] = max_value_bytes[i];
        };
        packed_bytes[16] = self.verifier_id;
        packed_bytes[17] = self.is_admin as u8;
        let packed = field_from_bytes(packed_bytes, true);
        // return serialized content
        [
            self.admin.to_field(),
            self.recipient.to_field(),
            packed,
            self.randomness
        ]
    }

    fn deserialize_content(serialized_note: [Field; RECURRING_ENTITLEMENT_NOTE_LENGTH]) -> RecurringEntitlementNote {
        // unpack verifier_id and max_value
        let packed = serialized_note[2];
        let packed_bytes: [u8; 18] = packed.to_be_bytes();
        let verifier_id = packed_bytes[16];
        let is_admin = packed_bytes[17] == 1;
        let mut max_value_bytes: [u8; 16] = [0; 16];
        for i in 0..16 {
            max_value_bytes[i] = packed_bytes[i];
        }
        let max_value = U128::from_le_bytes(max_value_bytes);
        // return deserialized note
        RecurringEntitlementNote {
            admin: AztecAddress::from_field(serialized_note[0]),
            recipient: AztecAddress::from_field(serialized_note[1]),
            is_admin,
            verifier_id,
            max_value,
            randomness: serialized_note[3],
            header: NoteHeader::empty()
        }
    }

    fn to_be_bytes(self, storage_slot: Field) -> [u8; RECURRING_ENTITLEMENT_NOTE_LENGTH * 32 + 64] {
        let serialized_note = self.serialize_content();
        let mut buffer: [u8; RECURRING_ENTITLEMENT_NOTE_LENGTH * 32 + 64] = [0; RECURRING_ENTITLEMENT_NOTE_LENGTH * 32 + 64];
        let storage_slot_bytes: [u8; 32] = storage_slot.to_be_bytes();
        let note_type_id_bytes: [u8; 32] = RecurringEntitlementNote::get_note_type_id().to_be_bytes();
        for i in 0..32 {
            buffer[i] = storage_slot_bytes[i];
            buffer[32 + i] = note_type_id_bytes[i];
        }
        for i in 0..serialized_note.len() {
            let bytes: [u8; 32] = serialized_note[i].to_be_bytes();
            for j in 0..32 {
                buffer[64 + i * 32 + j] = bytes[j];
            }
        }
        buffer
    }

    fn get_note_type_id() -> Field { 
        comptime {
            let bytes = "RecurringEntitlementNote".as_bytes();
            let hash = poseidon2_hash_bytes(bytes);
            let hash_bytes = hash.to_be_bytes::<4>();
            field_from_bytes(hash_bytes, true)
        }
    }

     fn get_header(self) -> NoteHeader {
        self.header
    }

    fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }

    fn compute_note_hash(self) -> Field {
        let serialized = self.serialize_without_is_admin();
        std::embedded_curve_ops::multi_scalar_mul(
            [GENERATORS[0], GENERATORS[1], GENERATORS[2], GENERATORS[3], GENERATORS[4]],
            [
            from_field_unsafe(serialized[0]),
            from_field_unsafe(serialized[1]),
            from_field_unsafe(serialized[2]),
            from_field_unsafe(serialized[3]),
            from_field_unsafe(self.get_header().storage_slot)
        ]
        ).x
    }
}

impl NullifiableNote for RecurringEntitlementNote {
    fn compute_nullifier(self, context: &mut PrivateContext, note_hash_for_nullify: Field) -> Field {
        let secret = self.derive_nullifier_secret_with_context(context);
        poseidon2_hash_with_separator(
            [
            note_hash_for_nullify,
            secret
        ],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }
    // docs:end:nullifier

    unconstrained fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_nullify(self);
        let secret = self.derive_nullifier_secret();
        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER
        )
    }
}

impl Eq for RecurringEntitlementNote {
    fn eq(self, other: Self) -> bool {
        (self.admin == other.admin)
            & (self.recipient == other.recipient)
            & (self.max_value == other.max_value)
            & (self.randomness == other.randomness)
            & (self.verifier_id == other.verifier_id)
    }
}

impl RecurringEntitlementNote {
    /**
     * Entitlement Receipt, shadows an entitlement send to a recepient
     * Cannot be used to claim a reimbursement, but can be used to nullify the sent entitlement
     *
     * @param recipient - the address of the recipient of the entitlement (NOT THE OWNER OF THE NOTE)
     * @param npk_m_hash - the nullifying public key hash of the escrow admin (NOT THE RECIPIENT OF THE ENTITLEMENT)
     *                     note: this is a bit confusing but it is different because nullifcation of reads
     * @param verifier_id - the type of verifier that the entitlement can be used for
     * @param max_value - the maximum value that can be withdrawn from the escrow using the entitlement
     * @param randomness - blinding factor for the note (inputted since must be same between the two notes)
     */
    fn new(
        admin: AztecAddress,
        recipient: AztecAddress,
        is_admin: bool,
        verifier_id: u8,
        max_value: U128,
        randomness: Field
    ) -> Self {
        Self {
            admin,
            recipient,
            is_admin,
            verifier_id,
            max_value,
            randomness,
            header: NoteHeader::empty()
        }
    }

    /**
     * Derives the nullifier for recurring notes
     * @dev recurring notes are nullified for a scope (month) without destroying the ntoe
     *      prove nullifier non-inclusion to use
     *
     * @param timestamp - the timestamp (month/ year) from the email receipt verifier
     * @return - the month nullifier for the note
     */
    fn derive_recurring_nullifier(self, timestamp: Field) -> Field {
        let base_nullifier_secret = self.derive_nullifier_secret();
        poseidon2_hash_with_separator(
            [
                base_nullifier_secret,
                timestamp
            ],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }

    fn derive_nullifier_secret_with_context(self, context: &mut PrivateContext) -> Field {
        // get pubkeys for the admin and recipient
        let admin_keys = get_public_keys(self.admin);
        let recipient_keys = get_public_keys(self.recipient);
        // determine which sk and pk to use
        let mut sk: Scalar = Scalar::empty();
        let mut pk: Point = Point::empty();
        if self.is_admin {
            pk = recipient_keys.npk_m.to_point();
            let nsk_app = context.request_nsk_app(admin_keys.npk_m.hash());
            sk = from_field_unsafe(nsk_app);
        } else {
            pk = admin_keys.npk_m.to_point();
            let nsk_app = context.request_nsk_app(recipient_keys.npk_m.hash());
            sk = from_field_unsafe(nsk_app);
        }
        // derive the shared secret
        let mut secret_bytes = point_to_symmetric_key(sk, pk);
        // set the highest byte to be 0 to ensure that the secret is not too large
        secret_bytes[0] = 0;
        field_from_bytes(secret_bytes, false)
    }

    fn derive_nullifier_secret(self) -> Field {
        // get pubkeys for the admin and recipient
        let admin_keys = get_public_keys(self.admin);
        let recipient_keys = get_public_keys(self.recipient);
        // determine which sk and pk to use
        let mut sk: Scalar = Scalar::empty();
        let mut pk: Point = Point::empty();
        if self.is_admin {
            pk = recipient_keys.npk_m.to_point();
            let nsk_app = get_nsk_app(admin_keys.npk_m.hash());
            sk = from_field_unsafe(nsk_app);
        } else {
            pk = admin_keys.npk_m.to_point();
            let nsk_app = get_nsk_app(recipient_keys.npk_m.hash());
            sk = from_field_unsafe(nsk_app);
        }
        // derive the shared secret
        let mut secret_bytes = point_to_symmetric_key(sk, pk);
        // set the highest byte to be 0 to ensure that the secret is not too large
        secret_bytes[0] = 0;
        field_from_bytes(secret_bytes, false)
    }

    fn serialize_without_is_admin(self) -> [Field; RECURRING_ENTITLEMENT_NOTE_LENGTH] {
        // serialize max_value and verifier_id together
        let max_value_bytes: [u8; 16] = self.max_value.to_le_bytes();
        let mut packed_bytes: [u8; 17] = [0; 17];
        for i in 0..16 {
            packed_bytes[i] = max_value_bytes[i];
        };
        packed_bytes[16] = self.verifier_id;
        let packed = field_from_bytes(packed_bytes, true);
        // return serialized content
        [
            self.admin.to_field(),
            self.recipient.to_field(),
            packed,
            self.randomness
        ]
    }
}
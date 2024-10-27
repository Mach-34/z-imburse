use dep::aztec::protocol_types::{
    address::AztecAddress, traits::{Serialize, Deserialize}, constants::GENERATOR_INDEX__NOTE_NULLIFIER,
    hash::{poseidon2_hash_with_separator, poseidon2_hash_bytes}, utils::field::field_from_bytes,
    scalar::Scalar, point::Point
};
use dep::aztec::note::utils::compute_note_hash_for_nullify;
use dep::aztec::oracle::random::random;
use dep::aztec::macros::notes::note_custom_interface;
use dep::aztec::prelude::{NoteHeader, NullifiableNote, NoteInterface, PrivateContext};
use dep::aztec::keys::{getters::{get_public_keys, get_nsk_app}, point_to_symmetric_key::point_to_symmetric_key};
use dep::compressed_string::CompressedString;
use std::embedded_curve_ops::multi_scalar_mul;
use std::hash::from_field_unsafe;
use dep::generators::GENERATORS;

// serializes verifier_id and max_value into one field element
global ENTITLEMENT_NOTE_LENGTH: u32 = 7;

#[note_custom_interface]
pub struct EntitlementNote {
    // the user that is allowed to use this entitlement
    recipient: AztecAddress,
    // the type of receipt verifier that this entitlement can be used for
    verifier_id: u8,
    // the maximum value that can be withdrawn from the escrow using this entitlement
    max_value: U128,
    // date range that verified emails can be used for
    date_start: Field,
    date_end: Field,
    // destination if used for travel
    destination: Field,
    // blinding factor & nullifier secret for the note
    randomness: Field,
}

impl NoteInterface<ENTITLEMENT_NOTE_LENGTH> for EntitlementNote {

    fn serialize_content(self) -> [Field; ENTITLEMENT_NOTE_LENGTH] {

        [
            self.recipient.to_field(),
            self.verifier_id as Field,
            self.max_value.to_integer(),
            self.date_start,
            self.date_end,
            self.destination,
            self.randomness
        ]
    }

    fn deserialize_content(serialized_note: [Field; ENTITLEMENT_NOTE_LENGTH]) -> EntitlementNote {
        EntitlementNote {
            recipient: AztecAddress::from_field(serialized_note[0]),
            verifier_id: serialized_note[1] as u8,
            max_value: U128::from_integer(serialized_note[2]),
            date_start: serialized_note[3],
            date_end: serialized_note[4],
            destination: serialized_note[5],
            randomness: serialized_note[6],
            header: NoteHeader::empty()
        }
    }

    fn to_be_bytes(self, storage_slot: Field) -> [u8; ENTITLEMENT_NOTE_LENGTH * 32 + 64] {
        let serialized_note = self.serialize_content();
        let mut buffer: [u8; ENTITLEMENT_NOTE_LENGTH * 32 + 64] = [0; ENTITLEMENT_NOTE_LENGTH * 32 + 64];
        let storage_slot_bytes: [u8; 32] = storage_slot.to_be_bytes();
        let note_type_id_bytes: [u8; 32] = EntitlementNote::get_note_type_id().to_be_bytes();
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
        comptime
        {
            let bytes = "EntitlementNote".as_bytes();
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
        let serialized = self.serialize_content();
        std::embedded_curve_ops::multi_scalar_mul(
            [GENERATORS[0], GENERATORS[1], GENERATORS[2], GENERATORS[3], GENERATORS[4], GENERATORS[5], GENERATORS[6]],
            [
            from_field_unsafe(serialized[0]),
            from_field_unsafe(serialized[1]),
            from_field_unsafe(serialized[2]),
            from_field_unsafe(serialized[3]),
            from_field_unsafe(serialized[4]),
            from_field_unsafe(serialized[5]),
            from_field_unsafe(serialized[6]),
            // do not use slot so it can be used for the nullifier
        ]).x
    }
}

impl NullifiableNote for EntitlementNote {
    fn compute_nullifier(self, context: &mut PrivateContext, note_hash_for_nullify: Field) -> Field {
        let secret = self.randomness; // use as nullifier_secret so that admin and recipient can nullify
        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }
    // docs:end:nullifier

    unconstrained fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_nullify(self);
        let secret = self.randomness; // use as nullifier secret so that admin and recipient can nullify
        dep::aztec::oracle::debug_log::debug_log_format("\n\nNote_hash_for_nullify: {0}/n secret: {1}\n\n", [note_hash_for_nullify, secret]);

        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER
        )
    }
}

impl Eq for EntitlementNote {
    fn eq(self, other: Self) -> bool {
        (self.recipient == other.recipient)
            & (self.max_value == other.max_value)
            & (self.randomness == other.randomness)
            & (self.verifier_id == other.verifier_id)
    }
}

impl EntitlementNote {
    
    /**
     * EntitlementNote constructor for recurring entitlements
     *
     * @param recipient - the address of the recipient of the entitlement (NOT THE OWNER OF THE NOTE)
     * @param verifier_id - the type of verifier that the entitlement can be used for
     * @param max_value - the maximum value that can be withdrawn from the escrow using the entitlement
     * @param randomness - blinding factor for the note (inputted since must be same between the two notes)
     */
    fn new_spot(
        recipient: AztecAddress,
        verifier_id: u8,
        max_value: U128,
        date_start: Field,
        date_end: Field,
        destination: str<31>,
        randomness: Field
    ) -> Self {
        Self {
            recipient,
            verifier_id,
            max_value,
            date_start,
            date_end,
            destination: CompressedString::from_string(destination).value[0],
            randomness,
            header: NoteHeader::empty()
        }
    }

    /**
     * EntitlementNote constructor for recurring entitlements
     * @todo: allow destinations on recurring?
     *
     * @param recipient - the address of the recipient of the entitlement (NOT THE OWNER OF THE NOTE)
     * @param verifier_id - the type of verifier that the entitlement can be used for
     * @param max_value - the maximum value that can be withdrawn from the escrow using the entitlement
     * @param randomness - blinding factor for the note (inputted since must be same between the two notes)
     */
    fn new_recurring(
        recipient: AztecAddress,
        verifier_id: u8,
        max_value: U128,
        randomness: Field
    ) -> Self {
        Self {
            recipient,
            verifier_id,
            max_value,
            date_start: 0,
            date_end: 0,
            destination: 0,
            randomness,
            header: NoteHeader::empty()
        }
    }

    /**
     * Determine if the entitlement is a spot entitlement by checking if date_start is set
     *
     * @return true if entitlement can only be used once, and false if it is recurring
     */
    fn is_spot(self) -> bool {
        self.date_start != 0
    }

    /**
     * Return the destination of the entitlement
     *
     * @return the utf8 bytes of the destination
     */
    fn destination(self) -> [u8; 31] {
        CompressedString::<1, 31> { value: [self.destination] }.to_bytes()
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
        let base_nullifier_secret = self.randomness; //todo: switch to regular nullifier
        poseidon2_hash_with_separator(
            [self.randomness, timestamp],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }
}

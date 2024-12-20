use aztec::{
    macros::notes::note,
    note::utils::compute_note_hash_for_nullify,
    prelude::{NoteHeader, NullifiableNote, PrivateContext},
    protocol_types::{
        address::AztecAddress,
        constants::GENERATOR_INDEX__NOTE_NULLIFIER,
        hash::poseidon2_hash_with_separator,
    },
};
use compressed_string::CompressedString;

global ZERO_DESTINATION: str<31> = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

#[note]
pub struct EntitlementNote {
    // the user that is allowed to use this entitlement
    recipient: AztecAddress,
    // the type of receipt verifier that this entitlement can be used for
    verifier_id: u8,
    // the maximum value that can be withdrawn from the escrow using this entitlement
    max_value: U128,
    // date range that verified emails can be used for
    date_start: u32,
    date_end: u32,
    // destination if used for travel
    destination: Field,
    // whether or not the entitlement is a spot entitlement
    spot: bool,
    // blinding factor & nullifier secret for the note
    randomness: Field,
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
        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER
        )
    }
}

impl Eq for EntitlementNote {
    fn eq(self, other: Self) -> bool {
        (self.recipient == other.recipient)
            & (self.date_start == other.date_start)
            & (self.date_end == other.date_end)
            & (self.destination == other.destination)
            & (self.max_value == other.max_value)
            & (self.randomness == other.randomness)
            & (self.spot == other.spot)
            & (self.verifier_id == other.verifier_id)
    }
}

impl EntitlementNote {
        fn new(
        recipient: AztecAddress,
        verifier_id: u8,
        max_value: U128,
        date_start: u32,
        date_end: u32,
        destination: str<31>,
        spot: bool,
        randomness: Field
    ) -> Self {
        let destination_compressed: CompressedString<1, 31> = CompressedString::from_string(destination);

        // assert destination 
        if spot {
            assert(date_end == 0, "Date end must be zero if entitlement is spot.");
            assert(date_start == 0, "Date start must be zero if entitlement is spot.");
            assert(destination == ZERO_DESTINATION, "Destination must be empty if entitlement is spot.");
        }

        Self {
            recipient,
            verifier_id,
            max_value,
            date_start,
            date_end,
            destination: destination_compressed.value[0],
            spot,
            randomness,
            header: NoteHeader::empty()
        }
    }
}


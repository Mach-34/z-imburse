use aztec::{
    encrypted_logs::encrypted_event_emission::encode_and_encrypt_event,
    keys::getters::{get_nsk_app, get_public_keys},
    macros::notes::{note, note_custom_interface},
    note::utils::compute_note_hash_for_nullify,
    oracle::{random::random, notes::check_nullifier_exists, debug_log::debug_log_format},
    prelude::{NoteHeader, NullifiableNote, NoteInterface, PrivateContext},
    protocol_types::{
        address::AztecAddress,
        traits::{Serialize, Deserialize},
        constants::GENERATOR_INDEX__NOTE_NULLIFIER,
        hash::{poseidon2_hash_with_separator, poseidon2_hash_bytes},
        utils::field::field_from_bytes,
    },
};
use compressed_string::CompressedString;
use generators::GENERATORS;
use std::{embedded_curve_ops::multi_scalar_mul, hash::from_field_unsafe};
use crate::{ZERO_DESTINATION, ZImburseEscrow::{SpotReimbursementClaimed, RecurringReimbursementClaimed, EntitlementNullified}};

global ENTITLEMENT_NOTE_LENGTH: u32 = 8;

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

// impl NoteInterface<ENTITLEMENT_NOTE_LENGTH> for EntitlementNote {

//     fn serialize_content(self) -> [Field; ENTITLEMENT_NOTE_LENGTH] {

//         [
//             self.recipient.to_field(),
//             self.verifier_id as Field,
//             self.max_value.to_integer(),
//             self.date_start as Field,
//             self.date_end as Field,
//             self.destination,
//             self.spot as Field,
//             self.randomness
//         ]
//     }

//     fn deserialize_content(serialized_note: [Field; ENTITLEMENT_NOTE_LENGTH]) -> EntitlementNote {
//         EntitlementNote {
//             recipient: AztecAddress::from_field(serialized_note[0]),
//             verifier_id: serialized_note[1] as u8,
//             max_value: U128::from_integer(serialized_note[2]),
//             date_start: serialized_note[3] as u32,
//             date_end: serialized_note[4] as u32,
//             destination: serialized_note[5],
//             spot: serialized_note[6] as bool,
//             randomness: serialized_note[7],
//             header: NoteHeader::empty()
//         }
//     }

//     fn to_be_bytes(self, storage_slot: Field) -> [u8; ENTITLEMENT_NOTE_LENGTH * 32 + 64] {
//         let serialized_note = self.serialize_content();
//         let mut buffer: [u8; ENTITLEMENT_NOTE_LENGTH * 32 + 64] = [0; ENTITLEMENT_NOTE_LENGTH * 32 + 64];
//         let storage_slot_bytes: [u8; 32] = storage_slot.to_be_bytes();
//         let note_type_id_bytes: [u8; 32] = EntitlementNote::get_note_type_id().to_be_bytes();
//         for i in 0..32 {
//             buffer[i] = storage_slot_bytes[i];
//             buffer[32 + i] = note_type_id_bytes[i];
//         }
//         for i in 0..serialized_note.len() {
//             let bytes: [u8; 32] = serialized_note[i].to_be_bytes();
//             for j in 0..32 {
//                 buffer[64 + i * 32 + j] = bytes[j];
//             }
//         }
//         buffer
//     }

//     fn get_note_type_id() -> Field {
//         comptime
//         {
//             let bytes = "EntitlementNote".as_bytes();
//             let hash = poseidon2_hash_bytes(bytes);
//             let hash_bytes = hash.to_be_bytes::<4>();
//             field_from_bytes(hash_bytes, true)
//         }
//     }

//     fn get_header(self) -> NoteHeader {
//         self.header
//     }

//     fn set_header(&mut self, header: NoteHeader) {
//         self.header = header;
//     }

//     fn compute_note_hash(self) -> Field {
//         let serialized = self.serialize_content();
//         let generators = [
//             GENERATORS[0],
//             GENERATORS[1],
//             GENERATORS[2],
//             GENERATORS[3],
//             GENERATORS[4],
//             GENERATORS[5],
//             GENERATORS[6],
//             GENERATORS[7],
//             GENERATORS[8]
//         ];
//         let data = [
//             from_field_unsafe(serialized[0]),
//             from_field_unsafe(serialized[1]),
//             from_field_unsafe(serialized[2]),
//             from_field_unsafe(serialized[3]),
//             from_field_unsafe(serialized[4]),
//             from_field_unsafe(serialized[5]),
//             from_field_unsafe(serialized[6]),
//             from_field_unsafe(serialized[7]),
//             from_field_unsafe(self.get_header().storage_slot)
//         ];
//         std::embedded_curve_ops::multi_scalar_mul(generators, data).x
//     }
// }

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
    
    /**
     * EntitlementNote constructor
     *
     * @param recipient - the address of the recipient of the entitlement (NOT THE OWNER OF THE NOTE)
     * @param verifier_id - the type of verifier that the entitlement can be used for
     * @param max_value - the maximum value that can be withdrawn from the escrow using the entitlement
     * @param date_start - the start of the date range that the entitlement can be used for (0 for recurring)
     * @param date_end - the end of the date range that the entitlement can be used for (0 for recurring)
     * @param destination - the destination of the entitlement (ZERO_DESTINATION for recurring)
     * @param randomness - blinding factor for the note (inputted since must be same between the two notes)
     */
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
        if !spot {
            assert(date_end == 0, "Date end must be zero if entitlement is recurring.");
            assert(date_start == 0, "Date start must be zero if entitlement is recurring.");
            assert(destination == ZERO_DESTINATION, "Destination must be empty if entitlement is recurring.");
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

    /**
     * Return the destination of the entitlement
     *
     * @return the utf8 bytes of the destination
     */
    fn destination(self) -> [u8; 31] {
        CompressedString::<1, 31> { value: [self.destination] }.to_bytes()
    } 

    /**
     * Constrain a given timestamp to be within the date range of the entitlement
     *
     * @param timestamp - the timestamp to check
     */
    fn check_date_range(self, timestamp: u32) {
        debug_log_format("\n\n\n\nChecking date range:\nStart: {0}\nTimestamp:{1}\nEnd:{2}", [
            self.date_start as Field,
            timestamp as Field,
            self.date_end as Field
        ]);
        assert(
            (timestamp >= self.date_start) & (timestamp <= self.date_end),
            "Receipt is out of entitlement date range"
        );
    }

    /**
     * Determine the amount to reimburse for a given claimed amount (lesser of the two)
     *
     * @param claimed - the amount claimed by the user
     * @return the amount to reimburse
     */
    fn amount_to_reimburse(self, claimed: U128) -> Field {
        if self.max_value >= claimed {
            claimed.to_field()
        } else {
            self.max_value.to_field()
        }
    }

    fn derive_shared_nullifier(self) -> Field {
        poseidon2_hash_with_separator(
            self.serialize_content(),
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
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
        let serialized = self.serialize_content();
        let mut inputs: [Field; ENTITLEMENT_NOTE_LENGTH + 1] = [0; ENTITLEMENT_NOTE_LENGTH + 1];
        for i in 0..ENTITLEMENT_NOTE_LENGTH {
            inputs[i] = serialized[i];
        }
        inputs[ENTITLEMENT_NOTE_LENGTH] = timestamp;
        poseidon2_hash_with_separator(
            inputs,
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }

    /**
     * Assert that a recurring nullifier has not been used before and emits it
     * @dev uses oracle check_nullifier_exists which is technically unsafe but will be caught by kernel
     *
     * @param context - the private context to use for the oracle call
     * @param timestamp - the timestamp to check
     */
    fn check_and_emit_recurring_nullifier(self, context: &mut PrivateContext, timestamp: Field) {
        // derive recurring nullifier for the month
        let recurring_nullifier = self.derive_recurring_nullifier(timestamp);
        // check the nullifier has not been emitted via oracle call (rely on kernel to actually constrain)
        let recurring_nullifier_exists = unsafe { check_nullifier_exists(recurring_nullifier) };
        assert(!recurring_nullifier_exists, "Entitlement has already been claimed for this month");
        // emit the nullifier
        context.push_nullifier(recurring_nullifier);
    }

    /**
     * Emit an event to the admin notifying them of a recurring claim
     *
     * @param context - the private execution context
     * @param admin - the address of the admin of the escrow to notify
     * @param amount - the amount claimed
     * @param timestamp - the timestamp of the claim
     */
    fn emit_recurring_claim(self, context: &mut PrivateContext, admin: AztecAddress, amount: Field, timestamp: Field) {
        RecurringReimbursementClaimed {
            claimant: self.recipient,
            amount,
            verifier_id: self.verifier_id,
            timestamp
        }.emit(
            encode_and_encrypt_event(
                context,
                admin,
                admin
            )
        );
    }

    /**
     * Emit an event to the admin notifying them of a spot claim
     *
     * @param context - the private execution context
     * @param admin - the address of the admin of the escrow to notify
     * @param amount - the amount claimed
     */
    fn emit_spot_claim(self, context: &mut PrivateContext, admin: AztecAddress, amount: Field) {
        SpotReimbursementClaimed {
            claimant: self.recipient,
            amount,
            verifier_id: self.verifier_id,
        }.emit(
            encode_and_encrypt_event(
                context,
                admin,
                admin
            )
        );
    }

    /**
     * Admin or recipient notifies counterparty that note has been nullified
     * @dev admin emits event when revoking entitlement, recipient emits when claiming spot
     * @dev clients must scan for these events to prune notes that are no longer valid
     *
     * @param context - the private execution context
     * @param to - the address of the counterparty to notify
     * @param from - the address of the notifier who nullified the entitlement note
     */
    fn emit_nullified(self, context: &mut PrivateContext, to: AztecAddress, from: AztecAddress) {
        EntitlementNullified { randomness: self.randomness }.emit(
            encode_and_encrypt_event(
                context,
                to,
                to
            )
        );
    }
}

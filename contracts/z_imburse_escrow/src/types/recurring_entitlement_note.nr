use dep::aztec::protocol_types::{
    address::AztecAddress,
    traits::{Serialize, Deserialize},
    constants::{GENERATOR_INDEX__NOTE_NULLIFIER, MAX_NOTE_HASH_READ_REQUESTS_PER_CALL},
    hash::{poseidon2_hash_with_separator, poseidon2_hash_bytes},
    utils::field::field_from_bytes,
};
use dep::aztec::{note::utils::compute_note_hash_for_nullify, oracle::random::random};
use dep::compressed_string::CompressedString;
use dep::aztec::macros::notes::note_custom_interface;
use dep::aztec::prelude::{NoteHeader, NullifiableNote, NoteInterface, PrivateContext};
use dep::aztec::keys::getters::get_nsk_app;
use dep::aztec::generators::{Ga1, Ga2, Ga3, Ga4, Ga5, G_slot};
use std::embedded_curve_ops::multi_scalar_mul;
use std::hash::from_field_unsafe;

// serializes verifier_id and max_value into one field element
global RECURRING_ENTITLEMENT_NOTE_LENGTH: u32 = 5;

#[note_custom_interface]
pub struct RecurringEntitlementNote {
    // the user that is allowed to use this entitlement
    owner: AztecAddress,
    // The nullifying public key hash is used with the nsk_app to ensure that the note can be privately spent.
    npk_m_hash: Field,
    // The nullifying public key hash of the note issuer who can revoke the entitlement
    // constrain inclusion here since they could lie in oracle response
    revocation_npk_m_hash: Field,
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
        let mut packed_bytes: [u8; 17] = [0; 17];
        for i in 0..16 {
            packed_bytes[i] = max_value_bytes[i];
        };
        packed_bytes[16] = self.verifier_id;
        let packed_verifier_and_max_value = field_from_bytes(packed_bytes, true);
        // return serialized content
        [
            self.owner.to_field(),
            self.npk_m_hash,
            self.revocation_npk_m_hash,
            packed_verifier_and_max_value,
            self.randomness
        ]
    }

    fn deserialize_content(serialized_note: [Field; RECURRING_ENTITLEMENT_NOTE_LENGTH]) -> RecurringEntitlementNote {
        // unpack verifier_id and max_value
        let packed_verifier_and_max_value = serialized_note[3];
        let packed_bytes: [u8; 17] = packed_verifier_and_max_value.to_be_bytes();
        let verifier_id = packed_bytes[16];
        let mut max_value_bytes: [u8; 16] = [0; 16];
        for i in 0..16 {
            max_value_bytes[i] = packed_bytes[i];
        }
        let max_value = U128::from_le_bytes(max_value_bytes);
        // return deserialized note
        RecurringEntitlementNote {
            owner: AztecAddress::from_field(serialized_note[0]),
            npk_m_hash: serialized_note[1],
            revocation_npk_m_hash: serialized_note[2],
            verifier_id,
            max_value,
            randomness: serialized_note[4],
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
        let serialized = self.serialize_content();
        std::embedded_curve_ops::multi_scalar_mul(
            [Ga1, Ga2, Ga3, Ga4, Ga5, G_slot],
            [
            from_field_unsafe(serialized[0]),
            from_field_unsafe(serialized[1]),
            from_field_unsafe(serialized[2]),
            from_field_unsafe(serialized[3]),
            from_field_unsafe(serialized[4]),
            from_field_unsafe(self.get_header().storage_slot)
        ]
        ).x
    }
}

impl NullifiableNote for RecurringEntitlementNote {
    fn compute_nullifier(self, context: &mut PrivateContext, note_hash_for_nullify: Field) -> Field {
        let secret = context.request_nsk_app(self.npk_m_hash);
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
        let secret = get_nsk_app(self.npk_m_hash);
        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER
        )
    }
}

impl Eq for RecurringEntitlementNote {
    fn eq(self, other: Self) -> bool {
        (self.owner == other.owner)
            & (self.max_value == other.max_value)
            & (self.npk_m_hash == other.npk_m_hash)
            & (self.randomness == other.randomness)
            & (self.verifier_id == other.verifier_id)
            & (self.revocation_npk_m_hash == other.revocation_npk_m_hash)
    }
}

impl RecurringEntitlementNote {
    fn new(
        owner: AztecAddress,
        npk_m_hash: Field,
        revocation_npk_m_hash: Field,
        verifier_id: u8,
        max_value: U128,
        randomness: Field
    ) -> Self {
        Self {
            owner,
            npk_m_hash,
            revocation_npk_m_hash,
            max_value,
            verifier_id,
            randomness,
            header: NoteHeader::empty()
        }
    }

    /**
     * Compute the monthly recurring nullifier for this entitlement to be used recurringly
     * @dev timestamp must be constrained to output from the verifier circuit
     *      should compute the same unix timestamp according only to the month/ year
     * @dev weaker guarantees around nullificaiton as note read nullification must come before
     *
     * @param timestamp - the timestamp of the month to nullify
     */
    fn compute_recurring_nullifier(
        self,
        timestamp: Field,
    ) -> Field {
        let serialized = self.serialize_content();
        poseidon2_hash_with_separator(
            [
                serialized[0],
                serialized[1],
                serialized[2],
                serialized[3],
                serialized[4],
                timestamp
            ],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }

    /**
     * Compute the revocation nullifier that the escrow admin can emit to prevent further use of the entitlement
     *
     * @return the revocation nullifier
     */
    fn compute_revocation_nullifier(self) -> Field {
        let serialized = self.serialize_content();
        poseidon2_hash_with_separator(
            serialized,
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }
}
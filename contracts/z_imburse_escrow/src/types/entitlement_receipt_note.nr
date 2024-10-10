use dep::aztec::protocol_types::{
    address::AztecAddress,
    traits::{Serialize, Deserialize},
    constants::GENERATOR_INDEX__NOTE_NULLIFIER,
    hash::{poseidon2_hash_with_separator, poseidon2_hash_bytes},
    utils::field::field_from_bytes
};
use dep::aztec::note::utils::compute_note_hash_for_nullify;
use dep::aztec::oracle::random::random;
use dep::aztec::macros::notes::note_custom_interface;
use dep::aztec::prelude::{NoteHeader, NullifiableNote, NoteInterface, PrivateContext};
use dep::aztec::keys::getters::{get_public_keys, get_nsk_app};
use dep::aztec::generators::{Ga1, Ga2, Ga3, Ga4, G_slot};
use dep::compressed_string::CompressedString;
use std::embedded_curve_ops::multi_scalar_mul;
use std::hash::from_field_unsafe;

// serializes verifier_id and max_value into one field element
global ENTITLEMENT_RECEIPT_NOTE_LENGTH: u32 = 4;

#[note_custom_interface]
pub struct EntitlementReceiptNote {
    // the user that is allowed to use this entitlement
    recipient: AztecAddress,
    // The nullifying public key hash is used with the nsk_app to ensure that the note can be privately spent.
    npk_m_hash: Field,
    // the type of receipt verifier that this entitlement can be used for
    verifier_id: u8,
    // the maximum value that can be withdrawn from the escrow using this entitlement
    max_value: U128,
    // blinding factor for the note
    randomness: Field,
}

impl NoteInterface<ENTITLEMENT_RECEIPT_NOTE_LENGTH> for EntitlementReceiptNote {
    
    fn serialize_content(self) -> [Field; ENTITLEMENT_RECEIPT_NOTE_LENGTH] {
        // serialize max_value and verifier_id together
        let max_value_bytes: [u8; 16] = self.max_value.to_le_bytes();
        let mut packed_bytes: [u8; 32] = [0; 32];
        for i in 0..16 {
            packed_bytes[i + 16] = max_value_bytes[i];
        };
        packed_bytes[1] = self.verifier_id;
        let packed_verifier_and_max_value = field_from_bytes(packed_bytes, true);
        // return serialized content
        [
            self.recipient.to_field(),
            self.npk_m_hash,
            packed_verifier_and_max_value,
            self.randomness
        ]
    }

    fn deserialize_content(serialized_note: [Field; ENTITLEMENT_RECEIPT_NOTE_LENGTH]) -> EntitlementReceiptNote {
        // unpack verifier_id and max_value
        let packed_verifier_and_max_value = serialized_note[2];
        let packed_bytes: [u8; 32] = packed_verifier_and_max_value.to_be_bytes();
        let verifier_id = packed_bytes[1];
        let mut max_value_bytes: [u8; 16] = [0; 16];
        for i in 0..16 {
            max_value_bytes[i] = packed_bytes[i + 16];
        }
        let max_value = U128::from_le_bytes(max_value_bytes);
        // return deserialized note
        EntitlementReceiptNote {
            recipient: AztecAddress::from_field(serialized_note[0]),
            npk_m_hash: serialized_note[1],
            verifier_id,
            max_value,
            randomness: serialized_note[3],
            header: NoteHeader::empty()
        }
    }

    fn to_be_bytes(self, storage_slot: Field) -> [u8; ENTITLEMENT_RECEIPT_NOTE_LENGTH * 32 + 64] {
        let serialized_note = self.serialize_content();
        let mut buffer: [u8; ENTITLEMENT_RECEIPT_NOTE_LENGTH * 32 + 64] = [0; ENTITLEMENT_RECEIPT_NOTE_LENGTH * 32 + 64];
        let storage_slot_bytes: [u8; 32] = storage_slot.to_be_bytes();
        let note_type_id_bytes: [u8; 32] = EntitlementReceiptNote::get_note_type_id().to_be_bytes();
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
            let bytes = "EntitlementReceiptNote".as_bytes();
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
            [Ga1, Ga2, Ga3, Ga4, G_slot],
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

impl NullifiableNote for EntitlementReceiptNote {
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

impl Eq for EntitlementReceiptNote {
    fn eq(self, other: Self) -> bool {
        (self.recipient == other.recipient)
            & (self.max_value == other.max_value)
            & (self.randomness == other.randomness)
            & (self.verifier_id == other.verifier_id)
    }
}

impl EntitlementReceiptNote {
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
        recipient: AztecAddress,
        npk_m_hash: Field,
        verifier_id: u8,
        max_value: U128,
        randomness: Field
    ) -> Self {
        Self {
            recipient,
            npk_m_hash,
            max_value,
            verifier_id,
            randomness,
            header: NoteHeader::empty()
        }
    }

    /**
     * Constrained computation of revocation nullifier
     */
    fn compute_revocation_nullifier(self) -> Field {
        // get npk_m_hash for escrow owner from oracle
        // incentivized to not lie on oracle call here since revocation would just fail
        let recipient_npk_m_hash = get_public_keys(self.recipient).npk_m.hash();
        // hash note noramlly, relying on "randomness" as blinding factor
        let serialized = self.serialize_content();
        poseidon2_hash_with_separator(
            [
                serialized[0],
                recipient_npk_m_hash,
                serialized[1],
                serialized[2],
                serialized[3]
            ],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }
}
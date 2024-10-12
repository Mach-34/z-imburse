use dep::aztec::{
    protocol_types::{
    address::AztecAddress, constants::GENERATOR_INDEX__NOTE_NULLIFIER,
    hash::poseidon2_hash_with_separator, traits::{Serialize, Deserialize}
},
    note::{note_header::NoteHeader, note_interface::NullifiableNote, utils::compute_note_hash_for_nullify},
    oracle::random::random, keys::getters::get_nsk_app, context::PrivateContext,
    macros::notes::note
};
use dep::compressed_string::CompressedString;

global NAME_LENGTH: u32 = 60;
global NAME_SERIALIZED_LENGTH: u32 = 2;

#[note]
pub struct ParticipantNote {
    address: AztecAddress,
    name: [Field; 2],
    // The nullifying public key hash is used with the nsk_app to ensure that the note can be privately spent.
    npk_m_hash: Field,
    randomness: Field,
}

impl NullifiableNote for ParticipantNote {

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

    unconstrained fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_nullify(self);
        let secret = get_nsk_app(self.npk_m_hash);
        poseidon2_hash_with_separator(
            [
            note_hash_for_nullify,
            secret
        ],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field
        )
    }
}

impl Eq for ParticipantNote {
    // does not check for participant name
    fn eq(self, other: Self) -> bool {
        (self.address == other.address) & (self.npk_m_hash == other.npk_m_hash)
    }
}

impl ParticipantNote {
    pub fn new(address: AztecAddress, name: str<NAME_LENGTH>, npk_m_hash: Field) -> Self {
        let randomness = unsafe { random()};
        let name_serialized: CompressedString<NAME_SERIALIZED_LENGTH, NAME_LENGTH> = CompressedString::from_string(name);
        ParticipantNote { address, name: name_serialized.value, npk_m_hash, randomness, header: NoteHeader::empty() }
    }

    pub fn get_name(self) -> [u8; NAME_LENGTH] {
        CompressedString::<NAME_SERIALIZED_LENGTH, NAME_LENGTH> { value: self.name }.to_bytes()
    }
}

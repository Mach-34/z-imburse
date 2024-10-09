use dep::aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize}, constants::GENERATOR_INDEX__NOTE_NULLIFIER, hash::poseidon2_hash_with_separator};
use dep::aztec::{note::utils::compute_note_hash_for_nullify, oracle::random::random};
use dep::compressed_string::CompressedString;
use dep::aztec::macros::notes::note;
use dep::aztec::prelude::{NoteHeader, NullifiableNote, PrivateContext};
use dep::aztec::keys::getters::get_nsk_app;

// unique ids for each verifier type
mod HOSTING_VERIFIER_TYPE {
    global LINODE: u8 = 1; // supported
    global HEROKU: u8 = 2; // todo: supported
    global AWS: u8 = 3; // todo: supported
    global GCP: u8 = 4; // not supported in mvp
    global AZURE: u8 = 5; // not supported in mvp
    global HETZNER: u8 = 6; // not supported in mvp
    global DIGITAL_OCEAN: u8 = 7; // not supported in mvp
}

// trait OwnedNote {
//     fn new(
//         owner: AztecAddress,
//         external_nullifier_hash: Field,
//         npk_m_hash: Field,
//         max_value: U128,
//         verifier_type: u8,
//     ) -> Self;
// }

trait OwnedNote {
    fn new(
        owner: AztecAddress,
        npk_m_hash: Field,
        max_value: U128,
    ) -> Self;
}

#[note]
pub struct RecurringEntitlementNote {
    // the user that is allowed to use this entitlement
    owner: AztecAddress,
    // // the external nullifier that the admin can use to nullify the note
    // external_nullifier_hash: Field,
    // The nullifying public key hash is used with the nsk_app to ensure that the note can be privately spent.
    npk_m_hash: Field,
    // the maximum value that can be withdrawn from the escrow using this entitlement
    max_value: U128,
    // // the type of email verifier that should be used for this entitlement
    // verifier_type: u8,
    // random entropy to make the note private
    randomness: Field,
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
    }
}

impl OwnedNote for RecurringEntitlementNote {
    // fn new(
    //     owner: AztecAddress,
    //     external_nullifier_hash: Field,
    //     npk_m_hash: Field,
    //     max_value: U128,
    //     verifier_type: u8,
    //     randomness: Field
    // ) -> Self {
    //     Self {
    //         owner,
    //         external_nullifier_hash,
    //         npk_m_hash,
    //         max_value,
    //         verifier_type,
    //         randomness: unsafe_rand()
    //         header: NoteHeader::empty()
    //     }
    // }
    fn new(
        owner: AztecAddress,
        npk_m_hash: Field,
        max_value: U128,
    ) -> Self {
        Self {
            owner,
            npk_m_hash,
            max_value,
            randomness: unsafe { random() },
            header: NoteHeader::empty()
        }
    }
}
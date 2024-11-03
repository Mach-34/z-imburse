use aztec::prelude::PrivateContext;
use zimburse_verifiers::zkemail::partial_hash::{partial_sha256_var_end, partial_sha256_var_interstitial};
use crate::{
    capsule::{pop_capsule, arr_field_to_u8, remaining_chunks},
    HASH_CHUNK_MAX_LENGTH, ZImburseEscrow
};

/**
 * Ensures the deferred access to hashing is correct
 *
 * @param hash_state_after_body - the hash state after the body has been hashed
 * @param hash_state_before_date - the precomputed hash state before the destination has been hashed
 * @param hash_state_after_destination - the hash state after the destination has been hashed
 * @param signed_body_hash - the signed body hash
 * @param actual_length - the actual length of the entire email body
 * @param amount_to_date_length - the length of the body between the amount and date selection
 * @param remaining_length - the length of the body after all selections have been made
 * @param context - the private execution context from the function circuit being called
 */
#[contract_library_method]
fn finish_hash(
    hash_state_after_body: [u32; 8],
    hash_state_before_date: [u32; 8],
    hash_state_after_destination: [u32; 8],
    signed_body_hash: [u8; 32],
    actual_length: u32,
    amount_to_date_length: u32,
    remaining_length: u32,
    context: &mut PrivateContext,
) {
    // hash from amount to date
    let computed_hash_state_before_date = ZImburseEscrow::at(context.this_address())
        .interstitial_hashing(hash_state_after_body, amount_to_date_length)
        .call(context);
    // check the hashes match
    // ensures provenance over body up to to hash_state_after_destination
    assert(
        computed_hash_state_before_date == hash_state_before_date,
        "Could not verify body hash between amount and date/destination"
    );
    // hash the remaining data
    let interstitial = ZImburseEscrow::at(context.this_address())
        .interstitial_hashing(hash_state_after_destination, remaining_length)
        .call(context);
    // finalize the hash
    let data = unsafe { arr_field_to_u8(pop_capsule::<HASH_CHUNK_MAX_LENGTH>()) };  
    // complete the hash
    let remaining = unsafe {
        let mut size = HASH_CHUNK_MAX_LENGTH;
        if remaining_length % HASH_CHUNK_MAX_LENGTH != 0 {
            size = remaining_length % HASH_CHUNK_MAX_LENGTH;
        }
        size
    };
    let computed_body_hash = partial_sha256_var_end(
        interstitial,
        data,
        remaining as u64,
        actual_length as u64
    );
    // check the hashes match
    assert(
        computed_body_hash == signed_body_hash,
        "SHA256 hash computed over body does not match body hash found in DKIM-signed header"
    );
}

/**
 * Compress up to HASH_CHUNK_MAX_LENGTH chunks into a sha256 hash but do not complete it
 * @dev capable of handling < HASH_CHUNK_MAX_LENGTH chunks so long as bytes in are a multiple of 64
 *
 * @param state - the state of the sha256 hash before adding chunks
 * @param length - the number of bytes left to hash for the entire message
 * @param context - the private execution context from the function circuit being called
 * @return - the hash state after the chunks have been compressed in
 */
#[private]
#[internal]
pub fn interstitial_hash(
    state: [u32; 8],
    length: u32,
    context: &mut PrivateContext
) -> [u32; 8] {
    // get chunk from capsule oracle and convert to u8 (unconstrained, hash check will deal with it)
    let data = unsafe { arr_field_to_u8(pop_capsule::<HASH_CHUNK_MAX_LENGTH>()) };   
    // determine length of data to hash
    let (hash_length, resume) = unsafe { remaining_chunks(length) };
    // hash the data
    let mut interstitial = partial_sha256_var_interstitial(state, data, hash_length);
    // if there is more data to hash, continue hashing
    if resume {
        interstitial = ZImburseEscrow::at(context.this_address())
            .interstitial_hashing(interstitial, length - HASH_CHUNK_MAX_LENGTH)
            .call(context);
    }
    // return the interstitial hash
    interstitial
}
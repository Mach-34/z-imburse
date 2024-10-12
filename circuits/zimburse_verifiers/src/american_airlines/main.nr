use crate::american_airlines::{
    constants::{MAX_AA_EMAIL_BODY_LENGTH, MAX_AA_EMAIL_HEADER_LENGTH, TOTAL_COST_INDICE_LENGTH},
    utils::{check_from_aa_info, check_subject_aa_flight_confirmation, extract_billed_amount} 
};
use dep::zkemail::{KEY_LIMBS_2048, dkim::verify_dkim_2048};
use std::hash::pedersen_hash;

pub fn verify_american_airlines_flight_receipt(
    body: [u8; MAX_AA_EMAIL_BODY_LENGTH],
    body_hash_index: u32,
    body_length: u32,
    header: [u8; MAX_AA_EMAIL_HEADER_LENGTH],
    header_length: u32,
    pubkey: [Field; KEY_LIMBS_2048],
    pubkey_redc: [Field; KEY_LIMBS_2048],
    signature: [Field; KEY_LIMBS_2048],
    from_index: u32,
    subject_index: u32,
    total_cost_indices: [u32; TOTAL_COST_INDICE_LENGTH],
) -> [Field; 2] {

    // check the body and header lengths are within bounds
    assert(header_length <= MAX_AA_EMAIL_HEADER_LENGTH);
    assert(body_length <= MAX_AA_EMAIL_BODY_LENGTH);

    // verify the dkim signature over the header
    verify_dkim_2048(header, header_length, pubkey, pubkey_redc, signature);

    // // extract body hash and decode from base64
    // let body_hash_encoded = get_body_hash_by_index(header, body_hash_index);
    // let signed_body_hash = body_hash_base64_decode(body_hash_encoded);

    // // compute the hash of the asserted body
    // let computed_body_hash = sha256_var(body, body_length as u64);

    // // compare the retrieved body hash to the computed body hash
    // assert(
    //     signed_body_hash == computed_body_hash, "SHA256 hash computed over body does not match body hash found in DKIM-signed header"
    // );

    // assert email is from no-reply@info.email.aa.com
    check_from_aa_info(from_index, header);

    // assert this is a flight confirmation email from American Airlines
    check_subject_aa_flight_confirmation(subject_index, header);

    // // // extract billed amount
    // // note: the billed amount has 2 decimals
    let billed_amount = extract_billed_amount(body, total_cost_indices);
    
    // hash the dkim key used to verify the email
    let dkim_key_hash = pedersen_hash(pubkey);
    [dkim_key_hash, billed_amount as Field]
}

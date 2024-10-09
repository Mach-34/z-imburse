use crate::constants::{MAX_UNITED_EMAIL_BODY_LENGTH, MAX_UNITED_EMAIL_HEADER_LENGTH, UNITED_PURCHASE_SUMMARY_INDICE_LEN};
use crate::utils::{check_from_united_receipts, check_subject_united_flight_receipt, extract_billed_amount_united};
use dep::zkemail::{dkim::verify_dkim_2048, KEY_LIMBS_2048, get_body_hash_by_index, base64::body_hash_base64_decode};
use std::hash::pedersen_hash;

/// USE UNTIL WE HAVE AZTEC-NARGO v0.35.0
// use crate::sha256_var::sha256_var;

pub fn verify_united_flight_receipt(
    body: [u8; MAX_UNITED_EMAIL_BODY_LENGTH],
    body_hash_index: u32,
    body_length: u32, 
    header: [u8; MAX_UNITED_EMAIL_HEADER_LENGTH], 
    header_length: u32,
    pubkey: [Field; KEY_LIMBS_2048],
    pubkey_redc: [Field; KEY_LIMBS_2048],
    signature: [Field; KEY_LIMBS_2048],
    from_index: u32,
    subject_index: u32,
    purchase_summary_indices: [u32; UNITED_PURCHASE_SUMMARY_INDICE_LEN]
) -> [Field; 2] {
    // check the body and header lengths are within bounds
    assert(header_length <= MAX_UNITED_EMAIL_HEADER_LENGTH);
    assert(body_length <= MAX_UNITED_EMAIL_BODY_LENGTH);

    // verify the dkim signature over the header
    verify_dkim_2048(header, header_length, pubkey, pubkey_redc, signature);

    // extract body hash and decode from base64
    let body_hash_encoded = get_body_hash_by_index(header, body_hash_index);
    let signed_body_hash = body_hash_base64_decode(body_hash_encoded);

        // compute the hash of the asserted body
    // let computed_body_hash = sha256_var(body, body_length as u64);

    // // compare the retrieved body hash to the computed body hash
    // assert(
    //     signed_body_hash == computed_body_hash, "SHA256 hash computed over body does not match body hash found in DKIM-signed header"
    // );

    // assert email is from Receipts@united.com
    check_from_united_receipts(from_index, header);

    // assert this is a eTicket receipt from United
    check_subject_united_flight_receipt(subject_index, header);

    // extract billed amount
    // note: the billed amount has 2 decimals
    let billed_amount = extract_billed_amount_united(body, purchase_summary_indices);

    // hash the dkim key used to verify the email
    let dkim_key_hash = pedersen_hash(pubkey);
    [dkim_key_hash, billed_amount as Field]
}
use crate::united::{
    constants::{MAX_EMAIL_BODY_LENGTH, MAX_EMAIL_HEADER_LENGTH, PURCHASE_SUMMARY_INDICE_LEN},
    utils::{check_from_united_receipts, check_subject_united_flight_receipt, extract_billed_amount}
};
use dep::zkemail::{dkim::RSAPubkey, KEY_LIMBS_2048, headers::body_hash::get_body_hash};
use std::hash::pedersen_hash;
use zkemail::Sequence;

/// USE UNTIL WE HAVE AZTEC-NARGO v0.35.0
// use crate::sha256_var::sha256_var;

pub fn verify_united_flight_receipt(
    header: BoundedVec<u8, MAX_EMAIL_HEADER_LENGTH>,
    pubkey: RSAPubkey<KEY_LIMBS_2048>,
    signature: [Field; KEY_LIMBS_2048],
    body_hash_index: u32,
    body: BoundedVec<u8, MAX_EMAIL_HEADER_LENGTH>,
    from_index: u32,
    subject_index: u32,
    amount_sequence: Sequence
) -> [Field; 2] {
    // check the body and header lengths are within bounds
    assert(header.len() <= MAX_EMAIL_HEADER_LENGTH);
    assert(body.len() <= MAX_EMAIL_BODY_LENGTH);

    // verify the dkim signature over the header
    pubkey.verify_dkim_signature(header, signature);

    // extract body hash and decode from base64
    // let body_hash_encoded = get_body_hash_by_index(header, body_hash_index);
    // let signed_body_hash = body_hash_base64_decode(body_hash_encoded);

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
    let billed_amount = extract_billed_amount(body, amount_sequence);

    // hash the dkim key used to verify the email
    let dkim_key_hash = pedersen_hash(pubkey.modulus);
    [dkim_key_hash, billed_amount]
}
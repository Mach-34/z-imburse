use crate::united::{
    constants::{
    MAX_AMOUNT_SEQUENCE_LENGTH, MAX_DATETIME_SEQUENCE_LENGTH, MAX_DEST_AIRPORT_LENGTH,
    MAX_EMAIL_BODY_LENGTH, MAX_EMAIL_HEADER_LENGTH, PURCHASE_SUMMARY_INDICE_LEN
},
    utils::{
    check_from_united_receipts, check_subject_united_flight_receipt, extract_billed_amount,
    extract_departing_flight_date, extract_destination_airport
}
};
use crate::utils::field_from_bytes;
use std::hash::pedersen_hash;
use zkemail::{
    dkim::RSAPubkey, KEY_LIMBS_2048, headers::body_hash::get_body_hash,
    partial_hash::partial_sha256_var_interstitial, Sequence
};
use super::utils::client_side_interstitial;
use super::utils::server_side_interstitial;

/// USE UNTIL WE HAVE AZTEC-NARGO v0.35.0
// use crate::sha256_var::sha256_var;

pub fn verify_united_flight_receipt(
    header: BoundedVec<u8, MAX_EMAIL_HEADER_LENGTH>,
    pubkey: RSAPubkey<KEY_LIMBS_2048>,
    signature: [Field; KEY_LIMBS_2048],
    body_hash_index: u32,
    body: BoundedVec<u8, MAX_EMAIL_BODY_LENGTH>,
    from_index: u32,
    subject_index: u32,
    amount_sequence: Sequence,
    date_sequence: Sequence,
    airport_sequence: Sequence,
    partial_body_hash: [u32; 8],
    partial_body_hash_date: [u32; 8]
) -> [Field; 4] {
    // check the body and header lengths are within bounds
    assert(header.len() <= MAX_EMAIL_HEADER_LENGTH);
    assert(body.len() <= MAX_EMAIL_BODY_LENGTH);

    // verify the dkim signature over the header
    pubkey.verify_dkim_signature(header, signature);

    // extract body hash and decode from base64
    // let body_hash_encoded = get_body_hash(header, body_hash_index);
    // let signed_body_hash = body_hash_base64_decode(body_hash_encoded);

    // assert email is from Receipts@united.com
    check_from_united_receipts(from_index, header);

    // assert this is a eTicket receipt from United
    check_subject_united_flight_receipt(subject_index, header);

    // extract billed amount
    // note: the billed amount has 2 decimals
    let billed_amount = extract_billed_amount(body, amount_sequence);

    let date = extract_departing_flight_date(body, date_sequence);

    let destination = extract_destination_airport(body, airport_sequence);

    let (interstitial_hash_1, interstitial_hash_3) = client_side_interstitial(
        body,
        amount_sequence,
        date_sequence,
        partial_body_hash,
        partial_body_hash_date
    );

    // server_side_interstitial(body, interstitial_hash_1, interstitial_hash_3, amount_sequence);

    // hash the dkim key used to verify the email
    let dkim_key_hash = pedersen_hash(pubkey.modulus);
    [dkim_key_hash, billed_amount, date, destination]
}

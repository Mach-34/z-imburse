use crate::united::{
    constants::{
    MAX_AMOUNT_SEQUENCE_LENGTH, MAX_DATETIME_SEQUENCE_LENGTH, MAX_DEST_AIRPORT_LENGTH,
    MAX_EMAIL_BODY_LENGTH, MAX_UNITED_EMAIL_HEADER_LENGTH, PURCHASE_SUMMARY_INDICE_LEN,
    AMOUNT_SELECTION_LENGTH, DATE_AIRPORT_SELECTION_LENGTH
},
    utils::{
    check_from_united_receipts, check_subject_united_flight_receipt, extract_billed_amount,
    extract_departing_flight_date, extract_destination_airport
}
};
use zkemail::{
    dkim::RSAPubkey, KEY_LIMBS_2048, headers::body_hash::get_body_hash,
    partial_hash::partial_sha256_var_interstitial, Sequence
};
use super::utils::client_side_interstitial;
use super::utils::server_side_interstitial;



/// USE UNTIL WE HAVE AZTEC-NARGO v0.35.0
// use crate::sha256_var::sha256_var;

// body hash schema
// _
// |
// |
// | PRECOMPUTED
// _
// 256 bytes for the amount sequence
// _
// |
// |
// | INTERSTITIAL HASH BETWEEN AMOUNT AND DATE/ARRIVAL
// |
// _
// 320 bytes for the date / destination sequence
// _
// |
// | END HASH
// |
// _

// returns (first interstitial hash, second interstitial hash, signed body hash)
// and verifies header stuff
pub fn verify_united_deferred_hash(
    header: BoundedVec<u8, MAX_UNITED_EMAIL_HEADER_LENGTH>,
    pubkey: RSAPubkey<KEY_LIMBS_2048>,
    signature: [Field; KEY_LIMBS_2048],
    dkim_header_sequence: Sequence,
    body_hash_index: u32,
    from_index: u32,
    subject_index: u32,
    amount_sequence: Sequence,
    date_sequence: Sequence,
    airport_sequence: Sequence,
    // hash state precomputed up to amount selection
    partial_body_hash: [u32; 8],
    body_amount_selection: [u8; AMOUNT_SELECTION_LENGTH],
    // hash state to date/ destination selection
    partial_body_hash_date: [u32; 8],
    body_date_selection: [u8; DATE_AIRPORT_SELECTION_LENGTH]
) -> ([u32; 8], [u32; 8], [u8; 32], [Field; 3]) {
    // check the header length is within bounds
    assert(header.len() <= MAX_UNITED_EMAIL_HEADER_LENGTH);

    // verify the dkim signature over the header
    // pubkey.verify_dkim_signature(header, signature);

    // // assert email is from Receipts@united.com
    check_from_united_receipts(from_index, header);

    // assert this is a eTicket receipt from United
    check_subject_united_flight_receipt(subject_index, header);

    // get body hash from header
    let signed_body_hash = get_body_hash(header, dkim_header_sequence, body_hash_index);

    // hash the state up to the amount selection
    let hash_state_after_body = partial_sha256_var_interstitial(
        partial_body_hash,
        body_amount_selection,
        AMOUNT_SELECTION_LENGTH
    );

    // hash the state up to the date/destination selection
    let hash_state_after_destination = partial_sha256_var_interstitial(
        partial_body_hash_date,
        body_date_selection,
        DATE_AIRPORT_SELECTION_LENGTH
    );

    // extract billed amount
    let billed_selection_vec: BoundedVec<u8, AMOUNT_SELECTION_LENGTH> = BoundedVec::from_array(body_amount_selection);
    let billed_amount = extract_billed_amount(billed_selection_vec, amount_sequence);

    // extract date
    let date_selection_vec: BoundedVec<u8, DATE_AIRPORT_SELECTION_LENGTH> = BoundedVec::from_array(body_date_selection);
    let date = extract_departing_flight_date(date_selection_vec, date_sequence);

    // extract destination
    // broken??
    // let destination = extract_destination_airport(date_selection_vec, airport_sequence);

    // let return_values = [billed_amount, date, destination];
    let return_values = [billed_amount, date, 0];
    (hash_state_after_body, hash_state_after_destination, signed_body_hash, return_values)
}
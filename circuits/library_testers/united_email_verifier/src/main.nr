use dep::zimburse_verifiers::{
    united::{
    constants::{MAX_EMAIL_BODY_LENGTH, MAX_EMAIL_HEADER_LENGTH, PURCHASE_SUMMARY_INDICE_LEN},
    main::{verify_united_flight_receipt, united_flight_body_hash, AMOUNT_SELECTION_LENGTH, DATE_AIRPORT_SELECTION_LENGTH},
},
    zkemail::{dkim::RSAPubkey, KEY_LIMBS_2048, Sequence}
};

// fn main(
//     header: BoundedVec<u8, MAX_EMAIL_HEADER_LENGTH>,
//     pubkey: RSAPubkey<KEY_LIMBS_2048>,
//     signature: [Field; KEY_LIMBS_2048],
//     body_hash_index: u32,
//     body: BoundedVec<u8, MAX_EMAIL_BODY_LENGTH>,
//     from_index: u32,
//     subject_index: u32,
//     amount_sequence: Sequence,
//     date_sequence: Sequence,
//     airport_sequence: Sequence,
//     partial_body_hash: [u32; 8],
//     partial_body_hash_date: [u32; 8]
// ) -> pub [Field; 4] {
//     verify_united_flight_receipt(
//         header,
//         pubkey,
//         signature,
//         body_hash_index,
//         body,
//         from_index,
//         subject_index,
//         amount_sequence,
//         date_sequence,
//         airport_sequence,
//         partial_body_hash,
//         partial_body_hash_date
//     )
// }


fn main(
    header: BoundedVec<u8, MAX_EMAIL_HEADER_LENGTH>,
    pubkey: RSAPubkey<KEY_LIMBS_2048>,
    signature: [Field; KEY_LIMBS_2048],
    dkim_header_sequence: Sequence,
    body_hash_index: u32,
    from_index: u32,
    subject_index: u32,
    amount_sequence: Sequence,
    date_sequence: Sequence,
    airport_sequence: Sequence,
    partial_body_hash: [u32; 8],
    body_amount_selection: [u8; AMOUNT_SELECTION_LENGTH],
    partial_body_hash_date: [u32; 8],
    body_date_selection: [u8; DATE_AIRPORT_SELECTION_LENGTH]
) -> pub ([u32; 8], [u32; 8], [u8; 32], [Field; 3]) {
    united_flight_body_hash(
        header,
        pubkey,
        signature,
        dkim_header_sequence,
        body_hash_index,
        from_index,
        subject_index,
        amount_sequence,
        date_sequence,
        airport_sequence,
        partial_body_hash,
        body_amount_selection,
        partial_body_hash_date,
        body_date_selection
    )
}
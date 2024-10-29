use dep::zimburse_verifiers::{
    united::{
    constants::{MAX_EMAIL_BODY_LENGTH, MAX_EMAIL_HEADER_LENGTH, PURCHASE_SUMMARY_INDICE_LEN},
    main::verify_united_flight_receipt
},
    zkemail::{dkim::RSAPubkey, KEY_LIMBS_2048, Sequence}
};

fn main(
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
) -> pub [Field; 4] {
    verify_united_flight_receipt(
        header,
        pubkey,
        signature,
        body_hash_index,
        body,
        from_index,
        subject_index,
        amount_sequence,
        date_sequence,
        airport_sequence,
        partial_body_hash,
        partial_body_hash_date
    )
}

use crate::linode::{
    constants::{LinodeBillingParams, MAX_LINODE_EMAIL_BODY_LENGTH, MAX_LINODE_EMAIL_HEADER_LENGTH},
    utils::{check_from_linode_billing, check_subject_linode_billing_receipt, extract_billed_amount, extract_month_year}
};
use dep::zkemail::{KEY_LIMBS_2048, dkim::RSAPubkey, headers::body_hash::get_body_hash, Sequence};
use std::{hash::{sha256_var, pedersen_hash}, collections::bounded_vec::BoundedVec};

pub fn verify_linode_billing_receipt(
    header: BoundedVec<u8, MAX_LINODE_EMAIL_HEADER_LENGTH>,
    pubkey: RSAPubkey<KEY_LIMBS_2048>,
    signature: [Field; KEY_LIMBS_2048],
    dkim_header_field_sequence: Sequence,
    body: BoundedVec<u8, MAX_LINODE_EMAIL_BODY_LENGTH>,
    body_hash_index: u32,
    from_index: u32,
    subject_index: u32,
    amount_index: u32,
    date_index: u32,
    receipt_id_length: u32
) -> [Field; 3] {
    // check the body and header lengths are within bounds
    assert(header.len() <= MAX_LINODE_EMAIL_HEADER_LENGTH);
    assert(body.len() <= MAX_LINODE_EMAIL_BODY_LENGTH);

    // verify the dkim signature over the header
    pubkey.verify_dkim_signature(header, signature);

    // extract body hash and decode from base64
    let signed_body_hash = get_body_hash(header, dkim_header_field_sequence, body_hash_index);

    // compute the hash of the asserted body
    let computed_body_hash = sha256_var(body.storage, body.len() as u64);

    // compare the retrieved body hash to the computed body hash
    assert(
        signed_body_hash == computed_body_hash, "SHA256 hash computed over body does not match body hash found in DKIM-signed header"
    );

    // assert email is from billing@linode.com
    check_from_linode_billing(from_index, header);

    // assert this is a billing receipt email from Linode
    check_subject_linode_billing_receipt(subject_index, header, receipt_id_length);

    // extract billed amount
    // note: the billed amount has 2 decimals
    let billed_amount = extract_billed_amount(body, amount_index);

    // extract the timestamp header from the email
    let receipt_date = extract_month_year(body, date_index);

    // hash the dkim key used to verify the email
    let dkim_key_hash = pedersen_hash(pubkey.modulus);
    [dkim_key_hash, receipt_date, billed_amount as Field]
}

use dep::zkemail::{KEY_LIMBS_2048, dkim::verify_dkim_2048, body_hash::{compare_body_hash, get_body_hash_by_index}};
use crate::constants::{LinodeBillingParams, MAX_EMAIL_BODY_LENGTH, MAX_EMAIL_HEADER_LENGTH};
use crate::utils::{check_from_linode_billing, check_subject_billing_receipt, extract_billed_amount};

pub fn verify_linode_billing_receipt(
    body: [u8; MAX_EMAIL_BODY_LENGTH],
    body_hash_index: u32,
    body_length: u32,
    header: [u8; MAX_EMAIL_HEADER_LENGTH],
    header_length: u32,
    pubkey: [Field; KEY_LIMBS_2048],
    pubkey_redc: [Field; KEY_LIMBS_2048],
    signature: [Field; KEY_LIMBS_2048],
    from_index: u32,
    subject_index: u32,
    amount_index: u32,
    amount_length: u32,
    receipt_id_length: u32,
) -> u32 {

    // check the body and header lengths are within bounds
    assert(header_length <= MAX_EMAIL_HEADER_LENGTH);
    assert(body_length <= MAX_EMAIL_BODY_LENGTH);

    // verify the dkim signature over the header
    verify_dkim_2048(header, header_length, pubkey, pubkey_redc, signature);
    // manually extract the body hash from the header
    let body_hash_encoded = get_body_hash_by_index(header, body_hash_index);
    // compare the retrieved body hash to the computed body hash
    compare_body_hash(body_hash_encoded, body, body_length);
    // assert email is from billing@linode.com
    check_from_linode_billing(from_index, header);
    // assert this is a billing receipt email from Linode
    check_subject_billing_receipt(subject_index, header, receipt_id_length);
    // extract billed amount and serialize
    let billed_amount = extract_billed_amount(body, amount_index, amount_length);
    billed_amount
}

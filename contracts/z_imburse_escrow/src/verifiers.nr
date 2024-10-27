 use zimburse_verifiers::{
    linode::{
        constants::{MAX_LINODE_EMAIL_BODY_LENGTH, MAX_LINODE_EMAIL_HEADER_LENGTH},
        main::verify_linode_billing_receipt
    },
    zkemail::KEY_LIMBS_2048
};

pub struct LinodeReceiptOutput {
    dkim_key_hash: Field,
    timestamp: Field,
    billed_amount: U128,
}

pub mod verifier_ids {
    pub global AWS: u8 = 1;
    pub global LINODE: u8 = 2;
    pub global HEROKU: u8 = 3;
    pub global FRONTIER_AIRLINES: u8 = 4;
    pub global UNITED_AIRLINES: u8 = 5;
    pub global AMERICAN_AIRLINES: u8 = 6;
    pub global DELTA_AIRLINES: u8 = 7;
    pub global UBER: u8 = 8;
    pub global LYFT: u8 = 9;
}


/** Constrain the verification of a Linode billing receipt email and return formatted outputs */
pub fn verify_linode(
    body: [u8; MAX_LINODE_EMAIL_BODY_LENGTH],
    body_hash_index: u32,
    body_length: u32,
    header: [u8; MAX_LINODE_EMAIL_HEADER_LENGTH],
    header_length: u32,
    pubkey: [Field; KEY_LIMBS_2048],
    pubkey_redc: [Field; KEY_LIMBS_2048],
    signature: [Field; KEY_LIMBS_2048],
    from_index: u32,
    subject_index: u32,
    amount_index: u32,
    amount_length: u32,
    date_index: u32,
    receipt_id_length: u32,
) -> LinodeReceiptOutput {
    // verify the email receipt
    let linode_receipt_result = verify_linode_billing_receipt(
        body,
        body_hash_index,
        body_length,
        header,
        header_length,
        pubkey,
        pubkey_redc,
        signature,
        from_index,
        subject_index,
        amount_index,
        amount_length,
        date_index,
        receipt_id_length
    );
    // extract outputs
    let dkim_key_hash = linode_receipt_result[0];
    let timestamp = linode_receipt_result[1];
    let billed_amount = U128::from_integer(linode_receipt_result[2] * 10000);
    LinodeReceiptOutput { dkim_key_hash, timestamp, billed_amount }
}
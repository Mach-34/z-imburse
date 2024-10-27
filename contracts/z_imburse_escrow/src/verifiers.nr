 use zimburse_verifiers::{
    linode::{constants::LinodeBillingParams, main::verify_linode_billing_receipt},
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
pub fn verify_linode(inputs: LinodeBillingParams) -> LinodeReceiptOutput {
    // verify the email receipt
    let linode_receipt_result = verify_linode_billing_receipt(
        inputs.body,
        inputs.body_hash_index,
        inputs.body_length,
        inputs.header,
        inputs.header_length,
        inputs.pubkey,
        inputs.pubkey_redc,
        inputs.signature,
        inputs.from_index,
        inputs.subject_index,
        inputs.amount_index,
        inputs.amount_length,
        inputs.date_index,
        inputs.receipt_id_length
    );
    // extract outputs
    let dkim_key_hash = linode_receipt_result[0];
    let timestamp = linode_receipt_result[1];
    let billed_amount = U128::from_integer(linode_receipt_result[2] * 10000);
    LinodeReceiptOutput { dkim_key_hash, timestamp, billed_amount }
}
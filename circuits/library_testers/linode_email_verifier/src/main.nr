use dep::zimburse_verifiers::{
    constants::{LINODE_BILLING_SUBJECT_FIXED_START, LinodeBillingParams},
    linode::verify_linode_billing_receipt
};

fn main(params: LinodeBillingParams) -> pub u32 {

    let LinodeBillingParams { 
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
        receipt_id_length
    } = params;

    verify_linode_billing_receipt(body, body_hash_index, body_length, header, header_length, pubkey, pubkey_redc, signature, from_index, subject_index, amount_index, amount_length, receipt_id_length)
}
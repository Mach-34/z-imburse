use dep::zimburse_verifiers::{
    linode::{
        constants::LinodeBillingParams,
        main::verify_linode_billing_receipt
    }
};

fn main(params: LinodeBillingParams) -> pub [Field; 3] {
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
        date_index,
        receipt_id_length
    } = params;

    verify_linode_billing_receipt(
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
    )
}

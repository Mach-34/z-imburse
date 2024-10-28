use dep::zimburse_verifiers::{linode::{constants::LinodeBillingParams, main::verify_linode_billing_receipt}};

fn main(params: LinodeBillingParams) -> pub [Field; 3] {
    let LinodeBillingParams { 
        header,
        body,
        pubkey,
        signature,
        dkim_header_sequence,
        body_hash_index,
        from_index,
        subject_index,
        amount_sequence,
        date_index,
        receipt_id_length
    } = params;

    verify_linode_billing_receipt(
        header,
        pubkey,
        signature,
        dkim_header_sequence,
        body,
        body_hash_index,
        from_index,
        subject_index,
        amount_sequence,
        date_index,
        receipt_id_length
    )
}

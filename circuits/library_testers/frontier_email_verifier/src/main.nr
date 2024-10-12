use dep::zimburse_verifiers::{
    dep::zkemail::KEY_LIMBS_1024,
    frontier::{
        constants::{MAX_FRONTIER_EMAIL_BODY_LENGTH, MAX_FRONTIER_EMAIL_HEADER_LENGTH, PURCHASE_TOTAL_INDICE_LEN},
        main::verify_frontier_billing_receipt
    }
};

fn main(
    body: [u8; MAX_FRONTIER_EMAIL_BODY_LENGTH],
    body_hash_index: u32,
    body_length: u32,
    header: [u8; MAX_FRONTIER_EMAIL_HEADER_LENGTH],
    header_length: u32,
    pubkey: [Field; KEY_LIMBS_1024],
    pubkey_redc: [Field; KEY_LIMBS_1024],
    signature: [Field; KEY_LIMBS_1024],
    from_index: u32,
    subject_index: u32,
    purchase_total_indices: [u32; PURCHASE_TOTAL_INDICE_LEN]
) -> pub [Field; 2] {
    verify_frontier_billing_receipt(
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
        purchase_total_indices,
    ) 
}

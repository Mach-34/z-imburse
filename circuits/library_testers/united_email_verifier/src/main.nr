use dep::zimburse_verifiers::{
    united::{    
        constants::{MAX_EMAIL_BODY_LENGTH, MAX_EMAIL_HEADER_LENGTH, PURCHASE_SUMMARY_INDICE_LEN}, 
        main::verify_united_flight_receipt
    },
    zkemail::KEY_LIMBS_2048,
};

fn main(
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
    purchase_summary_indices: [u32; PURCHASE_SUMMARY_INDICE_LEN]
) -> pub [Field; 2] {

    verify_united_flight_receipt(
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
        purchase_summary_indices
    )
}

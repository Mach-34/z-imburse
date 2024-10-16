use dep::zimburse_verifiers::{
    american_airlines::{    
        constants::{MAX_AA_EMAIL_BODY_LENGTH, MAX_AA_EMAIL_HEADER_LENGTH, TOTAL_COST_INDICE_LENGTH}, 
        main::verify_american_airlines_flight_receipt
    },
    zkemail::KEY_LIMBS_2048,
};

fn main(
    body: [u8; MAX_AA_EMAIL_BODY_LENGTH],
    body_hash_index: u32,
    body_length: u32, 
    header: [u8; MAX_AA_EMAIL_HEADER_LENGTH], 
    header_length: u32,
    pubkey: [Field; KEY_LIMBS_2048],
    pubkey_redc: [Field; KEY_LIMBS_2048],
    signature: [Field; KEY_LIMBS_2048],
    from_index: u32,
    subject_index: u32,
    total_cost_indices: [u32; TOTAL_COST_INDICE_LENGTH]
) -> pub [Field; 2] {

    verify_american_airlines_flight_receipt(
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
        total_cost_indices
    )
}

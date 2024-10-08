use dep::zimburse_verifiers::{
    constants::{MAX_UNITED_EMAIL_BODY_LENGTH, MAX_UNITED_EMAIL_HEADER_LENGTH},
    united::verify_united_flight_receipt,
    zkemail::KEY_LIMBS_2048,
};

fn main(
    body: [u8; MAX_UNITED_EMAIL_BODY_LENGTH],
    body_hash_index: u32,
    body_length: u32, 
    header: [u8; MAX_UNITED_EMAIL_HEADER_LENGTH], 
    header_length: u32,
    pubkey: [Field; KEY_LIMBS_2048],
    pubkey_redc: [Field; KEY_LIMBS_2048],
    signature: [Field; KEY_LIMBS_2048],
    from_index: u32,
    subject_index: u32
) {
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
        subject_index
    );
}

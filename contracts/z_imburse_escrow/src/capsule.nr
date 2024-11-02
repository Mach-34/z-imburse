use crate::HASH_CHUNK_MAX_LENGTH;

#[oracle(popCapsule)]
unconstrained fn pop_capsule_oracle<let N: u32>() -> [Field; N] {}

unconstrained pub fn pop_capsule<let N: u32>() -> [Field; N] {
    pop_capsule_oracle()
}

/** casts a Field array to a u8 array unconstrained */
unconstrained pub fn arr_field_to_u8<let N: u32>(arr: [Field; N]) -> [u8; N] {
    let mut res: [u8; N] = [0; N];
    for i in 0..N {
        res[i] = arr[i] as u8;
    }
    res
}

/** determines length to use in hash function unconstrained - hash should just match */
unconstrained pub fn remaining_chunks(length: u32) -> (u32, bool) {
    let mut res = 0;
    let mut resume = false;
    // +1 to account for final iteration being done by finalize
    // determine the length of the chunk to hash
    if length >= HASH_CHUNK_MAX_LENGTH {
        res = HASH_CHUNK_MAX_LENGTH;
    } else {
        res = length;
    }
    // determine if there are more chunks to hash
    if (length > (HASH_CHUNK_MAX_LENGTH * 2) + 1) {
        resume = true;
    }
    (res, resume)
}
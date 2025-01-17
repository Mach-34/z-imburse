use aztec::prelude::PrivateContext;
use zimburse_verifiers::zkemail::partial_hash::{partial_sha256_var_end, partial_sha256_var_interstitial};
use crate::{
    capsule::{pop_capsule, arr_field_to_u8, remaining_chunks},
    HASH_CHUNK_MAX_LENGTH, ZImburseEscrow
};


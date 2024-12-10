use aztec::{context::public_context::PublicContext, unencrypted_logs::unencrypted_event_emission::emit};
use crate::{
    BULK_KEY_LENGTH,
    ZImburseRegistry::{DKIMKeyHashRegistered, Storage}
};

/**
 * Register a single DKIM key
 *
 * @param context - the contract context
 * @param storage - the contract storage
 * @param dkim_key_hash - the hash of the DKIM key to add to the registry
 * @param verifier_id - the verifier ID to register the DKIM key to
*/

pub fn register_dkim_key(context: &mut PublicContext, storage: Storage<&mut PublicContext>, dkim_key_hash: Field, verifier_id: Field) {
    let stored_id = storage.dkim_registry.at(dkim_key_hash).read();
    assert(stored_id == 0, "DKIM key has already been registered");
    storage.dkim_registry.at(dkim_key_hash).initialize(verifier_id);
    emit(
        context,
        DKIMKeyHashRegistered { dkim_key_hash, verifier_id }
    );
}

/**
 * Register multiple DKIM keys
 *
 * @param context - the contract context
 * @param storage - the contract storage
 * @param dkim_key_hashes - the hashes of the DKIM keys to add to the registry
 * @param verifier_ids - the verifier IDs to register the DKIM keys to
 */
pub fn register_dkim_keys_bulk(context: &mut PublicContext, storage: Storage<&mut PublicContext>, dkim_key_hashes: [Field; BULK_KEY_LENGTH], verifier_ids: [Field; BULK_KEY_LENGTH]) {
    for i in 0..BULK_KEY_LENGTH {
        if (verifier_ids[i] != 0) {
            register_dkim_key(context, storage, dkim_key_hashes[i], verifier_ids[i]);
        }
    }
}
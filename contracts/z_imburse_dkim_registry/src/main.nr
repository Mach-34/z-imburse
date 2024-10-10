use dep::aztec::macros::aztec;

pub global BULK_KEY_LENGTH: u32 = 4;

mod receipt_verifier_id {
    pub global AWS: u8 = 1;
    pub global LINODE: u8 = 2;
    pub global HEROKU: u8 = 3;
    pub global FRONTIER_AIRLINES: u8 = 4;
    pub global UNITED_AIRLINES: u8 = 5;
    pub global AMERICAN_AIRLINES: u8 = 6;
    pub global DELTA_AIRLINES: u8 = 7;
    pub global UBER: u8 = 8;
    pub global LYFT: u8 = 9;
}

#[aztec]
contract ZImburseDkimRegistry {
    use std::meta::derive;
    use dep::aztec::prelude::{AztecAddress, SharedImmutable, Map};
    use dep::aztec::macros::{storage::storage, events::event, functions::{private, public, view, initializer}};
    use dep::aztec::unencrypted_logs::unencrypted_event_emission::emit;
    use dep::aztec::protocol_types::traits::Serialize;
    use crate::BULK_KEY_LENGTH;

    #[storage]
    struct Storage<Context> {
        admin: SharedImmutable<AztecAddress, Context>,
        dkim_registry: Map<Field, SharedImmutable<Field, Context>, Context>,
    }

    #[event]
    #[derive(Serialize)]
    struct DKIMKeyRegistered {
        dkim_key_hash: Field,
        verifier_id: Field,
    }

    /**
     * Initialize the Z-Imburse DKIM registry contract
     *
     * @param registry - the address of the Z-Imburse registry contract
     */
    #[public]
    #[initializer]
    fn constructor(
        verifier_ids: [Field; BULK_KEY_LENGTH],
        dkim_key_hashes: [Field; BULK_KEY_LENGTH]
    ) {
        storage.admin.initialize(context.msg_sender());
        // bulk insert up to 8 dkim key hashes at initialization (max unencrypted logs per tx)
        for i in 0..BULK_KEY_LENGTH {
            if (verifier_ids[i] != 0) {
                // ensure that the dkim key has not already been registered
                let stored_id = storage.dkim_registry.at(dkim_key_hashes[i]).read_public();
                assert(stored_id == 0, "DKIM key has already been registered");
                storage.dkim_registry.at(dkim_key_hashes[i]).initialize(verifier_ids[i]);
                emit(&mut context, DKIMKeyRegistered {
                    dkim_key_hash: dkim_key_hashes[i],
                    verifier_id: verifier_ids[i]
                });
            }
        }
    }

    /**
     * Bulk registration of DKIM keys
     *
     * @param verifier_ids - the verifier IDs to register the DKIM keys to
     * @param dkim_key_hashes - the hashes of the DKIM keys
     */
    #[public]
    fn register_dkim_bulk(verifier_ids: [Field; BULK_KEY_LENGTH], dkim_key_hashes: [Field; BULK_KEY_LENGTH]) {
        // check that the sender is the admin
        let admin = storage.admin.read_public();
        assert(admin == context.msg_sender(), "Sender is not the registry contract");
        // bulk insert up to 50 dkim key hashes
        for i in 0..BULK_KEY_LENGTH {
            if (verifier_ids[i] != 0) {
                // ensure that the dkim key has not already been registered
                let stored_id = storage.dkim_registry.at(dkim_key_hashes[i]).read_public();
                assert(stored_id == 0, "DKIM key has already been registered");
                storage.dkim_registry.at(dkim_key_hashes[i]).initialize(verifier_ids[i]);
                emit(&mut context, DKIMKeyRegistered {
                    dkim_key_hash: dkim_key_hashes[i],
                    verifier_id: verifier_ids[i]
                });
            }
        }
    }

    /**
     * Register a DKIM key hash for email verifiers to anchor trust to
     *
     * @param verifier_id - the ID of the verifier
     * @param dkim_key_hash - the hash of the DKIM key
     */
    #[public]
    fn register_dkim(verifier_id: Field, dkim_key_hash: Field) {
        // check that the sender is the admin
        let admin = storage.admin.read_public();
        assert(admin == context.msg_sender(), "Sender is not the registry contract");
        // ensure that the dkim key has not already been registered
        let stored_id = storage.dkim_registry.at(dkim_key_hash).read_public();
        assert(stored_id == 0, "DKIM key has already been registered");
        storage.dkim_registry.at(dkim_key_hash).initialize(verifier_id);
        emit(&mut context, DKIMKeyRegistered { dkim_key_hash, verifier_id });
    }

    /**
     * Check which verifier type a DKIM key maps to using the DKIM key hash
     * @dev constrained in the public context
     * 
     * @param dkim_key_hash - the hash of the DKIM key
     * @return verifier_id - the ID of the verifier (returns 0 if none)
     */
    #[public]
    #[view]
    fn check_dkim_key_hash_public(dkim_key_hash: Field) -> Field {
        storage.dkim_registry.at(dkim_key_hash).read_public()
    }

    /**
     * Check which verifier type a DKIM key maps to using the DKIM key hash
     * @dev constrained in the private context
     * 
     * @param dkim_key_hash - the hash of the DKIM key
     * @return verifier_id - the ID of the verifier (returns 0 if none)
     */
    #[private]
    #[view]
    fn check_dkim_key_hash_private(dkim_key_hash: Field) -> Field {
        storage.dkim_registry.at(dkim_key_hash).read_private()
    }

}


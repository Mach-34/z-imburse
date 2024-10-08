use dep::aztec::macros::aztec;

mod types;

#[aztec]
contract ZImburseContractRegistry {
    use std::meta::derive;
    use dep::aztec::prelude::{AztecAddress, PublicMutable, PrivateSet, SharedImmutable, Map};
    use dep::aztec::macros::{storage::storage, functions::{private, public, view, initializer, event}};
    use dep::aztec::note::{
        note_viewer_options::NoteViewerOptions, note_getter_options::NoteGetterOptions,
        note_getter::{get_notes, view_notes}, constants::MAX_NOTES_PER_PAGE
    };
    use dep::aztec::oracle::{get_contract_instance::get_contract_instance, header::get_header_at_oracle};
    use dep::aztec::keys::getters::get_public_keys;
    use dep::aztec::utils::comparison::Comparator;
    use dep::aztec::encrypted_logs::encrypted_note_emission::{encode_and_encrypt_note_unconstrained, encode_and_encrypt_note};
    use dep::aztec::encrypted_event_emission::encode_and_encrypt_event;
    use dep::compressed_string::CompressedString;

    #[storage]
    struct Storage<Context> {
        registry: SharedImmutable<AztecAddress, Context>,
        dkim_registry: Map<Field, Field, Context>,
        verifier_id_to_name: Map<Field, Field>,
        verifier_name_to_id: Map<Field, Field>,
        verifier_id_index: PublicMutable<Field>,
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
    fn constructor(registry: AztecAddress) {
        storage.registry.initialize(contract_class_id);
    }

    /**
     * Set a dkim key in the registry
     * @dev the header will not include the contract address and the contract 
     *
     */
    #[public]
    fn register_dkim(dkim_key_hash: Field, verifier_name: str<31>) {
        // check that the sender is the registry contract
        let registry = storage.registry.read_public();
        assert(registry == context.msg_sender(), "Sender is not the registry contract");
        // ensure that the dkim key has not already been registered
        let stored_id = storage.dkim_registry.at(escrow_contract).read_public();
        assert(stored_id == 0, "DKIM key has already been registered");

        let compressed = CompressedString::<1, 31>::from_string(name).to_field();
        let mut verifier_id = storage.verifier_name_to_id.at(compressed).read_public();
        if verifier_id == 0 {
            // increment the verifier id index
            verifier_id = storage.verifier_id_index.read() + 1;
            storage.verifier_id_index.write(verifier_id);
            storage.verifier_name_to_id.at(compressed).initialize(verifier_id);
            storave.verifier_id_to_name.at(verifier_id).initialize(compressed);
        }
        // store the dkim key hash and verifier id
        storage.dkim_registry.at(dkim_key_hash).initialize(verifier_id);
        verifier_id
        
    }

    /**
     * Publicly set the contract registration status
     *
     * @param escrow_contract - the address of the escrow contract that has privately been constrained to be valid
     */
    #[public]
    #[internal]
    fn set_contract_registered(escrow_contract: AztecAddress) {
        storage.contract_registration.at(escrow_contract).initialize(true);
    }

    #[private]
    fn check_and_register_participant(participant: AztecAddress, participant_name: str<60>, escrow: AztecAddress) {
        // check that the sender is the admin
        let escrow_admin = ZImburseEscrow::at(escrow).get_admin_private().view(&mut context);
        assert(escrow_admin == context.msg_sender(), "Sender is not the admin of the escrow contract");
        // check that the escrow address is registered
        let registration_status = storage.contract_registration.at(escrow).read_private();
        assert(registration_status, "Escrow contract has not been registered");
        // check if the participant has already been registered
        let options = NoteGetterOptions::new().select(AddressNote::properties().address, Comparator.EQ, participant).set_limit(1);
        let participant_exists = storage.participants.at(escrow).get_notes(options).len() == 0;
        // if the participant has not been registered, enqueue a private call to register the participant
        // do this instead of if statement here to make adding first time expensive but cheap if already registered
        if participant_exists {
            ZImburseContractRegistry::at(context.this_address()).register_participant(participant, participant_name, context.msg_sender(), escrow).call(&mut context);
        }
    }

    #[private]
    #[interal]
    fn register_participant(
        participant: AztecAddress,
        participant_name: str<60>,
        admin: AztecAddress,
        escrow: AztecAddress
    ) {
        // add escrow to the participant's set of escrows
        let mut escrow_note = AddressNote::new(escrow, get_public_keys(participant).npk_m.hash());
        storage.participant_escrows.insert(&mut escrow_note).emit(encode_and_encrypt_note(&mut context, admin, participant));
        // add the participant to the admin set of participants
        let mut participant_note = ParticipantNote::new(
            participant,
            participant_name,
            get_public_keys(admin).npk_m.hash()
        );
        storage.participants.at(escrow).insert(&mut participant_note).emit(encode_and_encrypt_note_unconstrained(&mut context, admin, admin))
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
        storage.dkim_registry.at(dkim_key_hash: Field).read_public()
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

    /**
     * Check which verifier type a DKIM key maps to using the DKIM key hash
     * @dev unconstrained simulation
     *
     * @param dkim_key_hash - the hash of the DKIM key
     * @return verifier_id - the ID of the verifier (returns 0 if none)
     */
    unconstrained fn check_dkim_key_unconstrained(dkim_key_hash: Field) -> pub Field {
        storage.dkim_registry.at(context.msg_sender()).read_private()
    }

    /**
     * Get the UTF-8 encoded name of a verifier
     *
     * @param verifier_id - the ID of the verifier
     * @return verifier_name - the name of the verifier
     */
    unconstrained fn get_verifier_name(verifier_id) -> [u8; 31] {
        let serialized = storage.verifier_id_to_name.at(verifier_id).read_private();
    }

}


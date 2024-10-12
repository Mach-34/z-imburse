use dep::aztec::macros::aztec;

mod test;
mod types;

#[aztec]
contract ZImburseEscrowRegistry {
    use dep::aztec::prelude::{AztecAddress, PrivateImmutable, PrivateSet, SharedImmutable, Map};
    use dep::aztec::macros::{storage::storage, functions::{private, public, view, initializer}};
    use dep::aztec::note::{
        note_viewer_options::NoteViewerOptions, note_getter_options::NoteGetterOptions,
        note_getter::{get_notes, view_notes}, constants::MAX_NOTES_PER_PAGE
    };
    use dep::aztec::protocol_types::contract_instance::ContractInstance;
    use dep::aztec::oracle::{get_contract_instance::get_contract_instance, header::get_header_at_oracle};
    use dep::aztec::keys::getters::get_public_keys;
    use dep::aztec::utils::comparison::Comparator;
    use dep::aztec::encrypted_logs::encrypted_note_emission::{encode_and_encrypt_note_unconstrained, encode_and_encrypt_note};
    use dep::address_note::address_note::AddressNote;
    use dep::z_imburse_escrow::ZImburseEscrow;
    use dep::z_imburse_dkim_registry::{ZImburseDkimRegistry, BULK_KEY_LENGTH};
    use crate::types::{
        escrow_registry_definition::EscrowRegistryDefinition,
        participant_note::{ParticipantNote, NAME_LENGTH}
    };

    #[storage]
    struct Storage<Context> {
        // todo: decentralize dkim registry functionality
        definition: SharedImmutable<EscrowRegistryDefinition, Context>,
        managed_escrows: PrivateSet<AddressNote, Context>,
        participants: Map<AztecAddress, PrivateSet<ParticipantNote, Context>, Context>,
        participant_escrows: PrivateSet<AddressNote, Context>,
        contract_registration: Map<AztecAddress, SharedImmutable<bool, Context>, Context>
    }

    /**
     * Initialize the Z-Imburse registry contract by setting the class ID of the escrow contract
     *
     * @param contract_class_id - The class ID of the escrow contract that all escrows must be instances of
     */
    #[public]
    #[initializer]
    fn constructor(
        dkim_registry: AztecAddress,
        usdc: AztecAddress,
        escrow_contract_id: Field,
    ) {
        let definition = EscrowRegistryDefinition::new(
            dkim_registry,
            usdc,
            escrow_contract_id
        );
        storage.definition.initialize(definition);
    }

    // /**
    //  * Entrypoint for registering a DKIM key in bulk in the DKIM registry
    //  * @dev the DKIM registry is separate from escrow registry so both can import it
    //  *
    //  * @param dkim_verifier_ids - the verifier IDs to register the DKIM keys to
    //  * @param dkim_key_hashes - the hashes of the DKIM keys
    //  */
    // #[public]
    // fn register_dkim_bulk(
    //     dkim_verifier_ids: [Field; BULK_KEY_LENGTH],
    //     dkim_key_hashes: [Field; BULK_KEY_LENGTH]
    // ) {
    //     // check admin is sender
    //     let definition = storage.definition.read_public();
    //     assert(context.msg_sender() == definition.admin, "Only admin can update dkim");
    //     // forward call to DKIM registry
    //     ZImburseDkimRegistry::at(definition.dkim_registry)
    //         .register_dkim_bulk(dkim_verifier_ids, dkim_key_hashes)
    //         .call(&mut context);
    // }

    // /**
    //  * Entrypoint for registering a DKIM key in the DKIM registry
    //  * @dev the DKIM registry is separate from escrow registry so both can import it
    //  *
    //  * @param dkim_verifier_id - the verifier ID to register the DKIM key to
    //  * @param dkim_key_hash - the hash of the DKIM key
    //  */
    // #[public]
    // fn register_dkim(dkim_verifier_id: Field, dkim_key_hash: Field) {
    //     // check admin is sender
    //     let definition = storage.definition.read_public();
    //     assert(context.msg_sender() == definition.admin, "Only admin can update dkim");
    //     // forward call to DKIM registry
    //     ZImburseDkimRegistry::at(definition.dkim_registry)
    //         .register_dkim(dkim_verifier_id, dkim_key_hash)
    //         .call(&mut context);
    // }

    /**
     * Check the authenticity and deployment status of an escrow contract and register it in the Z-Imburse registry
     * @dev the header will not include the contract address and the contract 
     *
     * @param escrow_contract - the address of the escrow contract to register
     */
    #[private]
    fn register_escrow(escrow_contract: AztecAddress) {
        // check that the contract has not already been registered
        let registration_status = storage.contract_registration.at(escrow_contract).read_private();
        assert(!registration_status, "Escrow contract has already been registered");

        // check that the contract admin is the sender of the message
        let escrow_admin = ZImburseEscrow::at(escrow_contract).get_admin_private().view(&mut context);
        assert(escrow_admin == context.msg_sender(), "Escrow contract admin does not match sender of message");
        // todo: check that dkim registry matches

        // check that the contract has been deployed
        context.historical_header.prove_contract_initialization(escrow_contract);

        // check the contract class ID by recomputing the contract address
        let definition = storage.definition.read_private();
        let oracle_contract_id = unsafe { get_contract_instance(escrow_contract).contract_class_id.to_field() };
        // let expected_escrow_address = AztecAddress::compute(
        //     escrow_contract_instance.public_keys_hash
        // )
        dep::aztec::oracle::debug_log::debug_log_format("Note: DKIM: {0}, USDC: {1}, contract_id: {2}", [
            definition.dkim_registry.to_field(),
            definition.usdc.to_field(),
            definition.escrow_contract_id
        ]);

        dep::aztec::oracle::debug_log::debug_log_format("Actual: {0}", [oracle_contract_id]);

        assert(
            definition.escrow_contract_id == oracle_contract_id, "Escrow contract class ID does not match expected class ID"
        );

        // privately add the escrow contract to the list of managed escrows
        let admin_keys = get_public_keys(context.msg_sender());
        let mut escrow_note = AddressNote::new(escrow_contract, admin_keys.npk_m.hash());
        // use unconstrained - why would you lie here
        storage.managed_escrows.insert(&mut escrow_note).emit(
            encode_and_encrypt_note_unconstrained(&mut context, admin_keys.ovpk_m, admin_keys.ivpk_m, context.msg_sender())
        );

        // publicly add the escrow contract to the list of participant escrows
        ZImburseEscrowRegistry::at(context.this_address()).set_contract_registered(escrow_contract).enqueue(&mut context);
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
            ZImburseEscrowRegistry::at(context.this_address()).register_participant(participant, participant_name, context.msg_sender(), escrow).call(&mut context);
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
        let admin_keys = get_public_keys(admin);
        let participant_keys = get_public_keys(participant);
        // add escrow to the participant's set of escrows
        let mut escrow_note = AddressNote::new(escrow, participant_keys.npk_m.hash());
        storage.participant_escrows.insert(&mut escrow_note).emit(
            encode_and_encrypt_note(
                &mut context,
                admin_keys.ovpk_m,
                participant_keys.ivpk_m,
                participant
            )
        );
        // add the participant to the admin set of participants
        let mut participant_note = ParticipantNote::new(
            participant,
            participant_name,
            admin_keys.npk_m.hash()
        );
        storage.participants.at(escrow).insert(&mut participant_note).emit(
            encode_and_encrypt_note_unconstrained(
                &mut context,
                admin_keys.ovpk_m,
                admin_keys.ivpk_m,
                admin
            )
        );
    }

    // todo: add ability to remove participant
    // todo: add ability to remove participant escrows by looking up nullifications

    /** Get the class ID that all escrow contracts must match */
    #[public]
    #[view]
    fn get_escrow_class_id() -> Field {
        storage.definition.read_public().escrow_contract_id
    }

    /** Get the registration status of an escrow contract */
    #[public]
    #[view]
    fn get_contract_registration_status(escrow_contract: AztecAddress) -> bool {
        storage.contract_registration.at(escrow_contract).read_public()
    }

    /**
     * Get a page of the list of escrows administrated by a given address (private)
     *
     * @param admin - the address of the admin
     * @param page_index - the index of the page to retrieve
     * @return managed_escrows - the list of managed escrows
     * @return page_limit_reached - whether the page limit has been reached (keep calling until this is true)
     */
    unconstrained fn get_managed_escrows(
        admin: AztecAddress,
        page_index: u32
    ) -> pub ([AztecAddress; MAX_NOTES_PER_PAGE], bool, u32) {
        let offset = page_index * MAX_NOTES_PER_PAGE;
        let mut options = NoteViewerOptions::new();
        let notes = storage.managed_escrows.view_notes(options);
        let mut managed_escrows: [AztecAddress; MAX_NOTES_PER_PAGE] = [AztecAddress::from_field(0); MAX_NOTES_PER_PAGE];
        for i in 0..notes.len() {
            if i < notes.len() {
                managed_escrows[i] = notes.get_unchecked(i).address;
            }
        }
        let page_limit_reached = notes.len() != options.limit;
        (managed_escrows, page_limit_reached, notes.len())
    }

    /**
     * Get a page of the list of escrows participated in by a given address (private)
     *
     * @param admin - the address of the participant
     * @param page_index - the index of the page to retrieve
     * @return participant_escrows - the list of enrolled escrows
     * @return page_limit_reached - whether the page limit has been reached (keep calling until this is true)
     */
    unconstrained fn get_participant_escrows(
        participant: AztecAddress,
        page_index: u32
    ) -> pub ([AztecAddress; MAX_NOTES_PER_PAGE], bool) {
        let offset = page_index * MAX_NOTES_PER_PAGE;
        let mut options = NoteViewerOptions::new();
        let notes = storage.participant_escrows.view_notes(options);
        let mut participant_escrows: [AztecAddress; MAX_NOTES_PER_PAGE] = [AztecAddress::from_field(0); MAX_NOTES_PER_PAGE];
        for i in 0..notes.len() {
            if i < notes.len() {
                participant_escrows[i] = notes.get_unchecked(i).address;
            }
        }
        let page_limit_reached = notes.len() != options.limit;
        (participant_escrows, page_limit_reached)
    }

    /**
     * Get a page of the list of of participants in an escrow (private)
     *
     * @param admin - the address of the escrow
     * @param page_index - the index of the page to retrieve
     * @return participants - the list of participating addresses
     * @return page_limit_reached - whether the page limit has been reached (keep calling until this is true)
     */
    unconstrained fn get_participants(
        escrow: AztecAddress,
        page_index: u32
    ) -> pub ([AztecAddress; MAX_NOTES_PER_PAGE], [[u8; NAME_LENGTH]; MAX_NOTES_PER_PAGE], bool) {
        let offset = page_index * MAX_NOTES_PER_PAGE;
        let mut options = NoteViewerOptions::new();
        let notes = storage.participants.at(escrow).view_notes(options);
        let mut participants: [AztecAddress; MAX_NOTES_PER_PAGE] = [AztecAddress::from_field(0); MAX_NOTES_PER_PAGE];
        let mut participant_names: [[u8; NAME_LENGTH]; MAX_NOTES_PER_PAGE] = [[0; NAME_LENGTH]; MAX_NOTES_PER_PAGE];
        for i in 0..notes.len() {
            if i < notes.len() {
                let participant_note = notes.get_unchecked(i);
                participants[i] = participant_note.address;
                participant_names[i] = participant_note.get_name();
            }
        }
        let page_limit_reached = notes.len() != options.limit;
        (participants, participant_names, page_limit_reached)
    }
}


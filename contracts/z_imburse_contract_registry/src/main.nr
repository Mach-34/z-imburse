use dep::aztec::macros::aztec;

mod types;

#[aztec]
contract ZImburseContractRegistry {
    use dep::aztec::prelude::{AztecAddress, PrivateImmutable, PrivateSet, SharedImmutable, Map};
    use dep::aztec::macros::{storage::storage, functions::{private, public, view, initializer}};
    use dep::aztec::note::{note_viewer_options::NoteViewerOptions, note_getter_options::NoteGetterOptions, note_getter::{get_notes, view_notes}, constants::MAX_NOTES_PER_PAGE};
    use dep::aztec::oracle::{get_contract_instance::get_contract_instance, header::get_header_at_oracle};
    use dep::aztec::keys::getters::get_public_keys;
    use dep::aztec::utils::comparison::Comparator;
    use dep::aztec::encrypted_logs::encrypted_note_emission::encode_and_encrypt_note;
    use dep::address_note::address_note::AddressNote;
    use crate::types::participant_note::{ParticipantNote, NAME_LENGTH};
    // use dep::z_imburse_escrow::ZImburseEscrow;

    #[storage]
    struct Storage<Context> {
        escrow_contract_id: SharedImmutable<Field, Context>,
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
    fn constructor(contract_class_id: Field) {
        storage.escrow_contract_id.initialize(contract_class_id);
    }

    /**
     * Check the authenticity and deployment status of an escrow contract and register it in the Z-Imburse registry
     * @dev the header will not include the contract address and the contract 
     *
     */
    #[private]
    fn register_escrow(escrow_contract: AztecAddress) {
        // check that the contract has not already been registered
        let registration_status = storage.contract_registration.at(escrow_contract).read_private();
        assert(!registration_status, "Escrow contract has already been registered");

        // check that the contract admin is the sender of the message
        // let escrow_admin = ZImburseEscrow::at(escrow_contract).get_admin().call(&mut context);
        // assert(escrow_admin == context.msg_sender(), "Escrow contract admin does not match sender of message");

        // check that the contract has been deployed
        let header = context.historical_header;
        header.prove_contract_initialization(escrow_contract);

        // check the contract class ID
        let contract_class_id = get_contract_instance(escrow_contract).contract_class_id.to_field();
        let expected_class_id = storage.escrow_contract_id.read_private();
        assert(
            contract_class_id == expected_class_id, "Escrow contract class ID does not match expected class ID"
        );

        // privately add the escrow contract to the list of managed escrows
        let npk_m_hash = get_public_keys(context.msg_sender()).npk_m.hash();
        let mut escrow_note = AddressNote::new(escrow_contract, npk_m_hash);
        storage.managed_escrows.insert(&mut escrow_note);

        // publicly add the escrow contract to the list of participant escrows
        ZImburseContractRegistry::at(context.this_address()).set_contract_registered(escrow_contract).enqueue(&mut context);
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
   fn check_and_register_participant(
        participant: AztecAddress,
        participant_name: str<60>,
        admin: AztecAddress,
        escrow: AztecAddress
    ) {
        // check that the escrow address is registered
        let registration_status = storage.contract_registration.at(escrow).read_private();
        assert(registration_status, "Escrow contract has not been registered");
        // check if the participant has already been registered
        let options = NoteGetterOptions::new()
            .select(AddressNote::properties().address, Comparator.EQ, participant)
            .set_limit(1);
        let participant_exists = storage.participants.at(escrow).get_notes(options).len() == 0;
        // if the participant has not been registered, enqueue a private call to register the participant
        // do this instead of if statement here to make adding first time expensive but cheap if already registered
        if participant_exists {
            ZImburseContractRegistry::at(context.this_address()).register_participant(participant, participant_name, admin, context.msg_sender()).call(&mut context);
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
            storage.participant_escrows.insert(&mut escrow_note).emit(
                encode_and_encrypt_note(&mut context, admin, participant)
            );
            // add the participant to the admin set of participants
            let mut participant_note = ParticipantNote::new(participant, participant_name, get_public_keys(participant).npk_m.hash());
            storage.participants.at(escrow).insert(&mut participant_note).emit(
                encode_and_encrypt_note(&mut context, admin, admin)
            )
       }

    // todo: add ability to remove participant
    // todo: add ability to remove participant escrows by looking up nullifications

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
    ) -> pub ([AztecAddress; MAX_NOTES_PER_PAGE], bool) {
        let offset = page_index * MAX_NOTES_PER_PAGE;
        let mut options = NoteViewerOptions::new();
        let notes = storage.managed_escrows.view_notes(options.set_offset(offset));
        let mut managed_escrows: [AztecAddress; MAX_NOTES_PER_PAGE] = [AztecAddress::from_field(0); MAX_NOTES_PER_PAGE];
        for i in 0..notes.len() {
            if i < notes.len() {
                managed_escrows[i] = notes.get_unchecked(i).address;
            }
        }
        let page_limit_reached = notes.len() == options.limit;
        (managed_escrows, page_limit_reached)
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
        let notes = storage.managed_escrows.view_notes(options.set_offset(offset));
        let mut participant_escrows: [AztecAddress; MAX_NOTES_PER_PAGE] = [AztecAddress::from_field(0); MAX_NOTES_PER_PAGE];
        for i in 0..notes.len() {
            if i < notes.len() {
                participant_escrows[i] = notes.get_unchecked(i).address;
            }
        }
        let page_limit_reached = notes.len() == options.limit;
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
        participant: AztecAddress,
        page_index: u32
    ) -> pub ([AztecAddress; MAX_NOTES_PER_PAGE], [[u8; NAME_LENGTH]; MAX_NOTES_PER_PAGE], bool) {
        let offset = page_index * MAX_NOTES_PER_PAGE;
        let mut options = NoteViewerOptions::new();
        let notes = storage.participants.at(escrow).view_notes(options.set_offset(offset));
        let mut participants: [AztecAddress; MAX_NOTES_PER_PAGE] = [AztecAddress::from_field(0); MAX_NOTES_PER_PAGE];
        let mut participant_names: [[u8; NAME_LENGTH]; MAX_NOTES_PER_PAGE] = [[0; NAME_LENGTH]; MAX_NOTES_PER_PAGE];
        for i in 0..notes.len() {
            if i < notes.len() {
                let participant_note = notes.get_unchecked(i);
                participants[i] = participant_note.address;
                participant_names[i] = participant_note.get_name();
            }
        }
        let page_limit_reached = notes.len() == options.limit;
        (participants, participant_names, page_limit_reached)
    }
}


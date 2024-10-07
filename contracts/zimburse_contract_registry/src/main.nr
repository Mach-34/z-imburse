use dep::aztec::macros::aztec;

// mod constants;
// mod types;
// mod date_parser;

#[aztec]
contract ZImburseContractRegistry {
    use dep::aztec::prelude::{AztecAddress, PrivateImmutable, PrivateSet, SharedImmutable, Map};
    // use dep::aztec::encrypted_logs::encrypted_note_emission::encode_and_encrypt_note;
    use dep::aztec::macros::{storage::storage, functions::{private, public, view, initializer}};
    use dep::aztec::note::{note_viewer_options::NoteViewerOptions, note_getter::view_notes};
    use dep::aztec::oracle::{get_contract_instance::get_contract_instance, header::get_header_at_oracle};
    use dep::aztec::keys::getters::get_public_keys;
    use dep::aztec::utils::comparison::Comparator;
    use dep::aztec::encrypted_note_emission::encode_and_encrypt_note;
    use dep::address_note::address_note::AddressNote;
    use dep::zimburse_escrow::ZImburseEscrow;
    

    // use dep::aztec::keys::getters::get_public_keys;
    // use dep::address_note::address_note::AddressNote;
    // use dep::aztec::note::note_getter_options::NoteGetterOptions;
    // use dep::zimburse_verifiers::{
    //     constants::{MAX_EMAIL_BODY_LENGTH, MAX_EMAIL_HEADER_LENGTH},
    //     linode::verify_linode_billing_receipt,
    //     zkemail::KEY_LIMBS_2048
    // };
    
    // use crate::types::definition::{Definition, TITLE_LENGTH};
    // use crate::types::recurring_entitlement_note::RecurringEntitlementNote;
    // // use dep::aztec::macros::{storage::storage, functions::{private, initializer}};
    // use dep::token::Token;

    #[storage]
    struct Storage<Context> {
        escrow_contract_id: SharedImmutable<Field, Context>,
        managed_escrows: PrivateSet<AddressNote, Context>,
        participants: Map<PrivateSet<AddressNote, Context>, Context>,
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
        let escrow_admin = ZImburseEscrow::at(escrow_contract).get_admin().call(&mut context);
        assert(escrow_admin == context.msg_sender(), "Escrow contract admin does not match sender of message");

        // check that the contract has been deployed
        let header = context.historical_header;
        header.prove_contract_initialization(escrow_contract);

        // check the contract class ID
        let contract_class_id = get_contract_instance(escrow_contract).contract_class_id;
        let expected_class_id = storage.escrow_contract_id.read_private();
        assert(contract_class_id == expected_class_id, "Escrow contract class ID does not match expected class ID");

        // privately add the escrow contract to the list of managed escrows
        let npk_m_hash = get_public_keys(context.msg_sender()).npk_m.hash();
        let mut escrow_note = AddressNote::new(escrow_contract, npk_m_hash);
        storage.managed_escrows.insert(&mut escrow_note);

        // publicly add the escrow contract to the list of participant escrows
        ZImburseContractRegistry::at(context.this_address()).set_contract_registered(escrow_contract).enqueue_call(&mut context);
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
   fn check_and_register_participant(participant: AztecAddress, admin: AztecAddress) {
        // check that the caller is a registered escrow contract
        let registration_status = storage.contract_registration.at(context.msg_sender()).read_private();
        assert(registration_status, "Escrow contract has not been registered");

        // check if the participant has already been registered
        let viewer = NoteViewerOptions::new()
            .select(AdressNote::properties().address, Comparator.EQ, participant)
            .set_limit(1);
        let participant_exists = storage.participants.at(escrow_contract).view_notes(viewer).len();
        // if the participant has not been registered, enqueue a private call to register the participant
        // do this instead of if statement here to make adding first time expensive but cheap if already registered
        if participant_exists == 0 {
            ZImburseContractRegistry::at(context.this_address()).register_participant(participant, admin, context.msg_sender()).call(&mut context);
        }
   }

   #[private]
   #[interal]
   fn register_participant(participant: AztecAddress, admin: AztecAddress, escrow: AztecAddress) {
        // add escrow to the participant's set of escrows
        let participant_keys = get_public_keys(participant);
        let admin_keys = get_public_keys(admin);
        let mut escrow_note = AddressNote::new(escrow, participant_keys.npk_m.hash());
        storage.participant_escrows.at(participant).insert(&mut escrow_note).emit(
            encode_and_encrypt_note(&mut context, admin_keys.ovpk_m, participant_keys.ivpk_m)
        );
        // add the participant to the admin set of participants
        let mut participant_note = AddressNote::new(participant, admin_keys.npk_m.hash());
        storage.participants.at(escrow).insert(&mut participant_note).emit(
            encode_and_encrypt_note(&mut context, participant_keys.ovpk_m, admin_keys.ivpk_m)
        )
   }

   // todo: add ability to remove participant
   // todo: add ability to remove participant escrows by looking up nullifications
}


use dep::aztec::macros::aztec;

mod library_methods;
mod test;
mod types;

pub global BULK_KEY_LENGTH: u32 = 4;

#[aztec]
contract ZImburseRegistry {
    use dep::aztec::{
        prelude::{AztecAddress, PrivateSet, PublicImmutable, Map},
        macros::{storage::storage, events::event, functions::{private, public, view, initializer, internal}},
        note::{
            note_viewer_options::NoteViewerOptions, note_getter_options::NoteGetterOptions,
            note_getter::{get_notes, view_notes}, constants::MAX_NOTES_PER_PAGE
        },
        protocol_types::{
            contract_instance::ContractInstance, address::partial_address::PartialAddress,
            contract_class_id::ContractClassId, abis::function_selector::FunctionSelector, traits::Serialize
        },
        oracle::get_contract_instance::get_contract_instance,
        keys::getters::get_public_keys, utils::comparison::Comparator,
        encrypted_logs::encrypted_note_emission::{encode_and_encrypt_note_unconstrained, encode_and_encrypt_note},
        unencrypted_logs::unencrypted_event_emission::emit
    };
    use std::{meta::derive, collections::bounded_vec::BoundedVec};
    use dep::address_note::address_note::AddressNote;
    use dep::zimburse_verifiers::constants::verifier_ids;
    use dep::z_imburse_escrow::ZImburseEscrow;
    use crate::{
        library_methods::dkim::{register_dkim_key, register_dkim_keys_bulk},
        types::{registry_definition::RegistryDefinition, participant_note::{ParticipantNote, NAME_LENGTH}},
        BULK_KEY_LENGTH
    };

    #[derive(Serialize)]
    #[event]
    struct DKIMKeyHashRegistered {
        dkim_key_hash: Field,
        verifier_id: Field,
    }

    #[storage]
    struct Storage<Context> {
        definition: PublicImmutable<RegistryDefinition, Context>,
        escrow_registry: Map<AztecAddress, PublicImmutable<bool, Context>, Context>,
        dkim_registry: Map<Field, PublicImmutable<Field, Context>, Context>,
        managed_escrows: Map<AztecAddress, PrivateSet<AddressNote, Context>, Context>,
        participants: Map<AztecAddress, PrivateSet<ParticipantNote, Context>, Context>,
        participant_escrows: Map<AztecAddress, PrivateSet<AddressNote, Context>, Context>,
    }

    /**
     * Initialize the Z-Imburse registry contract
     *
     * @param usdc - The address of the USDC token
     * @param contract_class_id - The class ID of the escrow contract that all escrows must be instances of
     * @param verifier_ids - the verifier IDs to register the DKIM keys to
     * @param dkim_key_hashes - the hashes of the DKIM keys to add to the registry
     */
    #[public]
    #[initializer]
    fn constructor(
        usdc: AztecAddress,
        escrow_contract_id: Field,
        verifier_ids: [Field; BULK_KEY_LENGTH],
        dkim_key_hashes: [Field; BULK_KEY_LENGTH]
    ) {
        // initialize the registry definition
        let definition = RegistryDefinition::new(context.msg_sender(), usdc, escrow_contract_id);
        storage.definition.initialize(definition);
        // add any DKIM key hashes that were passed in at initialization
        register_dkim_keys_bulk(&mut context, storage, dkim_key_hashes, verifier_ids);
    }

    /**
     * Bulk registration of DKIM keys
     *
     * @param verifier_ids - the verifier IDs to register the DKIM keys to
     * @param dkim_key_hashes - the hashes of the DKIM keys
     */
    #[public]
    fn register_dkim_bulk(
        verifier_ids: [Field; BULK_KEY_LENGTH],
        dkim_key_hashes: [Field; BULK_KEY_LENGTH]
    ) {
        // check that the sender is the admin
        let admin = storage.definition.read().admin;
        assert(admin == context.msg_sender(), "Sender is not the registry admin");
        // bulk insert up to 50 dkim key hashes
        register_dkim_keys_bulk(&mut context, storage, dkim_key_hashes, verifier_ids);
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
        let admin = storage.definition.read().admin;
        assert(admin == context.msg_sender(), "Sender is not registry admin");
        // ensure that the dkim key has not already been registered
        register_dkim_key(&mut context, storage, dkim_key_hash, verifier_id);
    }

    /**
     * Check the authenticity and deployment status of an escrow contract and register it in the Z-Imburse registry
     * @dev the header will not include the contract address and the contract 
     *
     * @param escrow_contract - the address of the escrow contract to register
     */
    #[private]
    fn register_escrow(escrow_contract: AztecAddress) {
        // check the contract class ID by recomputing the contract address
        let definition = storage.definition.read();
        let contract_instance: ContractInstance = unsafe {
            get_contract_instance(escrow_contract)
        };
        let computed_escrow_address = AztecAddress::compute(
            contract_instance.public_keys,
            PartialAddress::compute(
                ContractClassId::from_field(definition.escrow_contract_id), // constrained here
                contract_instance.salt,
                contract_instance.initialization_hash,
                contract_instance.deployer
            )
        );
        assert(
            computed_escrow_address == escrow_contract, "Escrow contract class ID does not match expected class ID"
        );
        // check that the contract has been deployed
        // annoying that we can't use this in the deploy tx
        context.historical_header.prove_contract_initialization(escrow_contract);

        // check that the contract has not already been registered
        let registration_status = storage.escrow_registry.at(escrow_contract).read();
        assert(!registration_status, "Escrow contract has already been registered");

        let escrow_params = ZImburseEscrow::at(escrow_contract).get_registration_params().view(&mut context);
        assert(
            escrow_params[0] == context.this_address(), "Escrow contract registry does not match this contract"
        );
        assert(escrow_params[1] == definition.usdc, "Escrow contract USDC does not match registry USDC");
        assert(
            escrow_params[2] == context.msg_sender(), "Escrow contract admin does not match sender of message"
        );

        // privately add the escrow contract to the list of managed escrows
        let admin_keys = get_public_keys(context.msg_sender());
        let mut escrow_note = AddressNote::new(escrow_contract, admin_keys.npk_m.hash());

        // use unconstrained - why would you lie here
        storage.managed_escrows.at(context.msg_sender()).insert(&mut escrow_note).emit(
            encode_and_encrypt_note_unconstrained(
                &mut context,
                context.msg_sender(),
                context.msg_sender()
            )
        );

        // publicly add the escrow contract to the list of participant escrows
        ZImburseRegistry::at(context.this_address()).set_contract_registered(escrow_contract).enqueue(&mut context);
    }

    /**
     * Publicly set the contract registration status
     *
     * @param escrow_contract - the address of the escrow contract that has privately been constrained to be valid
     */
    #[public]
    #[internal]
    fn set_contract_registered(escrow_contract: AztecAddress) {
        storage.escrow_registry.at(escrow_contract).initialize(true);
    }

    #[private]
    fn check_and_register_participant(participant: AztecAddress, participant_name: str<60>, escrow: AztecAddress) -> bool {
        // todo: switch to check that the sender is an escrow
        // check that sender is admin
        let admin = storage.definition.read().admin;
        assert(admin == context.msg_sender(), "Sender is not the registry admin");
        let is_registered = storage.escrow_registry.at(escrow).read();
        assert(is_registered, "Escrow contract is not registered");
        // check if the participant has already been registered
        let options = NoteGetterOptions::new().select(AddressNote::properties().address, Comparator.EQ, participant).set_limit(1);
        let not_registered = storage.participants.at(escrow).get_notes(options).len() == 0;
        // if the participant has not been registered, enqueue a private call to register the participant
        // do this instead of if statement here to make adding first time expensive but cheap if already registered
        if not_registered {
            ZImburseRegistry::at(context.this_address()).register_participant(participant, participant_name, admin, escrow).call(&mut context);
        }
        // add escrow to participants private set
        ZImburseRegistry::at(context.this_address()).register_participant_escrow(participant, escrow).call(&mut context);
        not_registered
    }

    #[private]
    #[internal]
    fn register_participant(participant: AztecAddress, participant_name: str<60>, admin: AztecAddress, escrow: AztecAddress) {
        let admin_keys = get_public_keys(admin);
        // add the participant to the admin set of participants
        let mut participant_note = ParticipantNote::new(participant, participant_name, admin_keys.npk_m.hash());
        storage.participants.at(escrow).insert(&mut participant_note).emit(
            encode_and_encrypt_note_unconstrained(&mut context, admin, admin)
        );
    }

    #[private]
    #[internal]
    fn register_participant_escrow(participant: AztecAddress, escrow: AztecAddress) {
        let participant_keys = get_public_keys(participant);
        // add escrow to the participant's set of escrows
        let mut escrow_note = AddressNote::new(escrow, participant_keys.npk_m.hash());
        storage.participant_escrows.at(participant).insert(&mut escrow_note).emit(
            encode_and_encrypt_note(
                &mut context,
                participant,
                participant
            )
        );
    }

    // todo: add ability to remove participant
    // todo: add ability to remove participant escrows by looking up nullifications

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
        storage.dkim_registry.at(dkim_key_hash).read()
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
        storage.dkim_registry.at(dkim_key_hash).read()
    }

    /** Get the class ID that all escrow contracts must match */
    #[public]
    #[view]
    fn get_escrow_class_id() -> Field {
        storage.definition.read().escrow_contract_id
    }

    /** Get the registration status of an escrow contract */
    #[public]
    #[view]
    fn get_escrow_registry_status(escrow_contract: AztecAddress) -> bool {
        storage.escrow_registry.at(escrow_contract).read()
    }

    /**
     * Get a page of the list of escrows administrated by a given address (private)
     *
     * @param admin - the address of the admin
     * @param offset - the index of the page to retrieve
     * @return managed_escrows - the list of managed escrows
     * @return page_limit_reached - whether the page limit has been reached (keep calling until this is true)
     */
    unconstrained pub fn get_managed_escrows(admin: AztecAddress, offset: u32) -> pub (BoundedVec<AztecAddress, MAX_NOTES_PER_PAGE>, bool) {
        let mut options = NoteViewerOptions::new().set_offset(offset);
        let notes = storage.managed_escrows.at(admin).view_notes(options);
        let mut managed_escrows = BoundedVec::new();
        for i in 0..notes.len() {
            managed_escrows.push(notes.get_unchecked(i).address);
        }
        (managed_escrows, notes.len() == MAX_NOTES_PER_PAGE)
    }

    /**
     * Get a page of the list of escrows participated in by a given address (private)
     *
     * @param participant - the address of the participant
     * @param offset - the index of the page to retrieve
     * @return participant_escrows - the list of enrolled escrows
     * @return page_limit_reached - whether the page limit has been reached (keep calling until this is true)
     */
    unconstrained pub fn get_participant_escrows(
        participant: AztecAddress,
        offset: u32
    ) -> pub (BoundedVec<AztecAddress, MAX_NOTES_PER_PAGE>, bool) {
        let mut options = NoteViewerOptions::new().set_offset(offset);
        let notes = storage.participant_escrows.at(participant).view_notes(options);
        let mut participant_escrows: BoundedVec<AztecAddress, MAX_NOTES_PER_PAGE> = BoundedVec::new();
        for i in 0..notes.len() {
            participant_escrows.push(notes.get_unchecked(i).address);
        }
        (participant_escrows, notes.len() == MAX_NOTES_PER_PAGE)
    }

    /**
     * Get a page of the list of of participants in an escrow (private)
     *
     * @param admin - the address of the escrow
     * @param offset - the index of the page to retrieve
     * @return participants - the list of participating addresses
     * @return page_limit_reached - whether the page limit has been reached (keep calling until this is true)
     */
    unconstrained fn get_participants(
        escrow: AztecAddress,
        offset: u32
    ) -> pub (BoundedVec<ParticipantNote, MAX_NOTES_PER_PAGE>, bool) {
        let mut options = NoteViewerOptions::new().set_offset(offset);
        let notes = storage.participants.at(escrow).view_notes(options);
        (notes, notes.len() == MAX_NOTES_PER_PAGE)
    }
}


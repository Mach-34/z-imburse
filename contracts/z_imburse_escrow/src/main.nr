use aztec::macros::aztec;

mod contract_interfaces;
mod library_methods;
mod types;
mod verifiers;

#[aztec]
contract ZImburseEscrow {
    use std::{meta::derive, collections::bounded_vec::BoundedVec, option::Option};
    use aztec::{
        macros::{
            storage::storage,
            events::event,
            functions::{private, public, internal, view, initializer}
        },
        note::constants::MAX_NOTES_PER_PAGE,
        oracle::random::random,
        prelude::{AztecAddress, SharedImmutable},
        protocol_types::traits::Serialize,
    };
    use zimburse_verifiers::{
        linode::constants::LinodeBillingParams,
        united::{
            main::united_flight_body_hash,
            constants::MAX_EMAIL_HEADER_LENGTH,
        },
        zkemail::{KEY_LIMBS_2048, Sequence, dkim::RSAPubkey},
    };
    use crate::{
        library_methods::linode,
        types::{
            escrow_definition::{EscrowDefinition, TITLE_LENGTH},
            entitlement_note::EntitlementNote,
            entitlement_set::EntitlementSet
        },
    };

    #[event]
    #[derive(Serialize)]
    struct RecurringReimbursementClaimed {
        claimant: AztecAddress,
        amount: Field,
        verifier_id: u8,
        timestamp: Field
    }

    #[event]
    #[derive(Serialize)]
    struct SpotReimbursementClaimed {
        claimant: AztecAddress,
        amount: Field,
        verifier_id: u8
    }

    #[event]
    #[derive(Serialize)]
    struct EntitlementNullified {
        randomness: Field
    }

    #[storage]
    struct Storage<Context> {
        definition: SharedImmutable<EscrowDefinition, Context>,
        entitlements: EntitlementSet<EntitlementNote, Context>,
    }

    /**
     * Initialize the Z-Imburse contract by setting the owner and USDC token.
     *
     * @param registry The address of the Z-Imburse contract registry
     * @param usdc_token The address of the USDC token
     * @param title The title of the contract as a string of max length 60
     */
    #[public]
    #[initializer]
    fn constructor(registry: AztecAddress, usdc_token: AztecAddress, title: str<TITLE_LENGTH>) {
        let definition = EscrowDefinition::new(registry, context.msg_sender(), usdc_token, title);
        storage.definition.initialize(definition);
    }

    /**
     * Create a new spot entitlement for a user to reimburse themselves with
     * @dev spot = one-time use
     * 
     * @param recipient - the address to give the entitlement to
     * @param amount - the maximum amount the recipient can claim in the reimbursement
     * @param verifier_id - the id of the email receipt type to verify
     * @param date_start - the unix timestamp of the start that receipts are valid from
     * @param date_end - the unix timestamp of the end that receipts are valid until
     * @param destination - the destination that a travel receipt must go to (set to [0; 31] if not applicable)
     */
    #[private]
    pub fn give_spot_entitlement(recipient: AztecAddress, amount: Field, verifier_id: u8, date_start: u32, date_end: u32, destination: str<31>) {
        // check that no receipt exists for this recipient and verifier
        let entitlement_exists = storage.entitlements.get_matching_entitlement(
            context.msg_sender(),
            recipient,
            verifier_id,
            true // checks spot
        ).is_some();
        assert(!entitlement_exists, "An entitlement already exists for this recipient and verifier");

        // check is escrow admin
        let sender = context.msg_sender();
        let admin = storage.definition.read_private().admin;
        assert(sender == admin, "Only the escrow admin can give entitlements");

        // create the entitlement note
        let amount = U128::from_integer(amount);
        let blinding_factor = unsafe { random() };
        let mut entitlement = EntitlementNote::new_spot(recipient, verifier_id, amount, date_start, date_end, destination, blinding_factor);

        // insert the entitlement note for the recipient and the admin
        storage.entitlements.add_entitlement_with_receipt(
            &mut context,
            sender,
            recipient,
            &mut entitlement
        );
    }

    /**
     * Create a new recurring entitlement for a user to reimburse themselves with
     *
     * @param recipient - the address to give the entitlement to
     * @param amount - the maximum amount the recipient can claim in the reimbursement
     * @param verifier_id - the id of the email receipt type to verify
     */
    #[private]
    pub fn give_recurring_entitlement(recipient: AztecAddress, amount: Field, verifier_id: u8) {
        // check that no receipt exists for this recipient and verifier
        let entitlement_exists = storage.entitlements.get_matching_entitlement(
            context.msg_sender(),
            recipient,
            verifier_id,
            false // checks recurring
        ).is_some();
        assert(!entitlement_exists, "An entitlement already exists for this recipient and verifier");

        // check is escrow admin
        let sender = context.msg_sender();
        let admin = storage.definition.read_private().admin;
        assert(sender == admin, "Only the escrow admin can give entitlements");

        // create the entitlement note
        let amount = U128::from_integer(amount);
        let blinding_factor = unsafe { random() };
        let mut entitlement = EntitlementNote::new_recurring(recipient, verifier_id, amount, blinding_factor);

        // insert the entitlement note for the recipient and the admin
        storage.entitlements.add_entitlement_with_receipt(
            &mut context,
            sender,
            recipient,
            &mut entitlement
        );
    }
    
    /**
     * Claim a recurring reimbursement for a Linode hosting receipt
     * @dev use separate function from spot to optimize gates by avoiding if statements
     * 
     * @param email_receipt_inputs - the inputs from the email verifier
     * @param claim_secret_hash - the hash of the claim secret used to redeem the reimbursement
     * @return the amount reimbursed
     */
    #[private]
    pub fn reimburse_linode_recurring(
        email_receipt_inputs: LinodeBillingParams,
        claim_secret_hash: Field,
    ) -> Field {
        // common logic for claiming a Linode entitlement
        let (entitlement, admin, amount_to_reimburse, timestamp) = linode(
            email_receipt_inputs,
            claim_secret_hash,
            false, // recurring
            &mut context,
            storage
        );

        // check that the entitlement has not been nullified by the admin
        // let _ = entitlement.check_nullifier(&mut context); // <-- cant be used in txe
        let _ = entitlement.check_nullifier_txe(&mut context); // <-- doesn't actually constrain nullifier to exist

        // check and emit recurring nullification
        entitlement.check_and_emit_recurring_nullifier(&mut context, timestamp);

        // notify admin of reimbursement
        entitlement.emit_recurring_claim(&mut context, admin, amount_to_reimburse, timestamp);
        
        // return the amount reimbursed
        amount_to_reimburse
    }

    /**
     * Claim a spot reimbursement for a Linode hosting receipt
     * @dev use separate function from recurring to optimize gates by avoiding if statements
     * 
     * @param email_receipt_inputs - the inputs from the email verifier
     * @param claim_secret_hash - the hash of the claim secret used to redeem the reimbursement
     * @return the amount reimbursed
     */
    #[private]
    pub fn reimburse_linode_spot(
        email_receipt_inputs: LinodeBillingParams,
        claim_secret_hash: Field,
    ) -> Field {
        let sender = context.msg_sender();
        // common logic for claiming a Linode entitlement
        let (entitlement, admin, amount_to_reimburse, timestamp) = linode(
            email_receipt_inputs,
            claim_secret_hash,
            true, // spot
            &mut context,
            storage
        );

        // check that the receipt is valid for the entitlement date range
        entitlement.check_date_range(timestamp as u32);

        // check that the entitlement has not been nullified by the admin
        // let nullifier = entitlement.check_nullifier(&mut context); // <-- cant be used in txe
        let nullifier = entitlement.check_nullifier_txe(&mut context); // <-- doesn't actually constrain nullifier to exist

        // broadcast the note nullifier
        context.push_nullifier(nullifier);

        // emit event to notify admin of spot entitlement consumption
        entitlement.emit_nullified(&mut context, entitlement.recipient, sender);
        
        // notify admin of reimbursement
        entitlement.emit_spot_claim(
            &mut context,
            admin,
            amount_to_reimburse,
        );
        
        // return the amount reimbursed
        amount_to_reimburse
    }

    // #[private]
    // pub fn united_test(
    //     header: [u8; MAX_EMAIL_HEADER_LENGTH],
    //     header_length: u32,
    //     pubkey_modulus: [Field; KEY_LIMBS_2048],
    //     pubkey_redc: [Field; KEY_LIMBS_2048],
    //     signature: [Field; KEY_LIMBS_2048],
    //     dkim_header_sequence: Sequence,
    //     body_hash_index: u32,
    //     from_index: u32,
    //     subject_index: u32,
    //     partial_body_hash: [u32; 8],
    //     body_amount_selection: [u8; 256],
    //     partial_body_hash_date: [u32; 8],
    //     body_date_selection: [u8; 256]
    // ) {
    //     let header_vec: BoundedVec<u8, MAX_EMAIL_HEADER_LENGTH> = BoundedVec {
    //         storage: header,
    //         len: header_length
    //     };
    //     let pubkey: RSAPubkey<KEY_LIMBS_2048> = RSAPubkey {
    //         modulus: pubkey_modulus,
    //         redc: pubkey_redc
    //     };
    //     let (interstitial_hash_1, interstitial_hash_3, signed_body_hash) = united_flight_body_hash(
    //         header_vec,
    //         pubkey,
    //         signature,
    //         body_hash_index,
    //         dkim_header_sequence,
    //         from_index,
    //         subject_index,
    //         partial_body_hash,
    //         body_amount_selection,
    //         partial_body_hash_date,
    //         body_date_selection
    //     );
    // }

    /**
     * Emit the nullifier for an entitlement
     * @dev will fail @ kernel if already emitted
     *
     * @param recipient - the address to revoke entitlement for
     * @param verifier_type - the verifier type to revoke entitlement for
     * @param spot - whether the entitlement is spot or recurring
     */
    #[private]
    pub fn revoke_entitlement(recipient: AztecAddress, verifier_type: u8, spot: bool) {
        // check is escrow admin
        let sender = context.msg_sender();
        let defintion = storage.definition.read_private();
        assert(sender == defintion.admin, "Only the escrow admin can revoke entitlements");

        // try to pop a note for this recipient
        let entitlement = storage.entitlements.nullify_entitlement(
            sender,
            recipient,
            verifier_type,
            spot
        );
        // ensure the note is to/ from correctly
        assert(entitlement.recipient == recipient, "Entitlement does not belong to the recipient");

        // broadcast the note nullifier
        let nullifier = entitlement.compute_nullifier_without_context();
        context.push_nullifier(nullifier);

        // emit event to notify recipient of revocation
        entitlement.emit_nullified(&mut context, entitlement.recipient, sender);
    }

    /**
     * Get the title of the Z-Imburse escrow
     */
    #[public]
    #[view]
    pub fn get_title() -> [u8; TITLE_LENGTH] {
        storage.definition.read_public().title_as_string()
    }

    /**
     * Privately get the admin of the ZImburse escrow contract
     *
     * @return the admin of the ZImburse escrow contract
     */
    #[private]
    #[view]
    pub fn get_admin_private() -> AztecAddress {
        storage.definition.read_private().admin
    }

    /**
     * Get the params needed to constrain the escrow registration process
     * 
     * @return [registry, usdc, admin]
     */
    #[private]
    #[view]
    pub fn get_registration_params() -> [AztecAddress; 3] {
        let definition = storage.definition.read_private();
        [definition.registry, definition.usdc, definition.admin]
    }

    /**
     * Get the entitlements for a given recipient
     *
     * @param offset - the offset to start from
     * @param scope - the storage scope to check
     * @param recipient - the address of the recipient to check
     * @param verifier_id - the verifier id to check for
     * @param spot - if true, check for spot entitlements. If false, check for recurring entitlements
     * @return - the entitlement notes for the recipient
     */
    unconstrained pub fn view_entitlements(
        offset: u32,
        scope: AztecAddress,
        recipient: Option<AztecAddress>,
        verifier_id: Option<u8>,
        spot: Option<bool>
    ) -> (BoundedVec<EntitlementNote, MAX_NOTES_PER_PAGE>, bool) {
        storage.entitlements.view_entitlements(
            offset,
            scope,
            recipient,
            verifier_id,
            spot
        )
    }
}


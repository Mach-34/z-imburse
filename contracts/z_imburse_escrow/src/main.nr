use aztec::macros::aztec;

global HASH_CHUNK_MAX_LENGTH: u32 = 2048;
global ZERO_DESTINATION = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

mod capsule;
mod contract_interfaces;
mod library_methods;
mod types;
mod verifiers;

#[aztec]
contract ZImburseEscrow {
    use std::{
        meta::derive,
        collections::bounded_vec::BoundedVec,
        option::Option,
        hash::pedersen_hash
    };
    use aztec::{
        macros::{
            storage::storage,
            events::event,
            functions::{private, public, internal, view, initializer}
        },
        note::constants::MAX_NOTES_PER_PAGE,
        prelude::{AztecAddress, SharedImmutable},
        protocol_types::traits::Serialize,
    };
    use zimburse_verifiers::{
        united::constants::UnitedBillingParamsContract,
        zkemail::{
            KEY_LIMBS_2048,
            Sequence,
            dkim::RSAPubkey,
            partial_hash::{partial_sha256_var_interstitial, partial_sha256_var_end},
        },
        linode::constants::LinodeBillingParamsContract,
    };
    use crate::{
        capsule::{pop_capsule, arr_field_to_u8, remaining_chunks},
        HASH_CHUNK_MAX_LENGTH, ZERO_DESTINATION,
        library_methods::{
            linode::linode,
            united::{united_deferred, reimburse_united},
            hashing::{finish_hash, interstitial_hash},
            entitlements::give_entitlement
        },
        contract_interfaces::{check_dkim_key_hash_private, shield_to_claimant},
        verifiers::{verify_united_deferred, verifier_ids},
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
    pub fn give_spot_entitlement(
        recipient: AztecAddress,
        amount: Field,
        verifier_id: u8,
        date_start: u32,
        date_end: u32,
        destination: str<31>
    ) {
        give_entitlement(
            recipient,
            amount,
            verifier_id,
            date_start,
            date_end,
            destination,
            true, // spot
            storage,
            &mut context
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
        give_entitlement(
            recipient,
            amount,
            verifier_id,
            0,
            0,
            ZERO_DESTINATION,
            false, // spot
            storage,
            &mut context
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
        email_receipt_inputs: LinodeBillingParamsContract,
        // claim secret hash
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
    fn reimburse_linode_spot(
        email_receipt_inputs: LinodeBillingParamsContract,
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

    /**
     * Claim a spot reimbursement for a United Airlines receipt
     * 
     * @param email_inputs - the inputs from the email verifier in a contract-serializable format
     * @param amount_to_date_length - the length of the body between the amount and date selection
     * @param remaining_length - the length of the body after all selections have been made
     * @param actual_length - the actual length of the entire email body
     * @param claim_secret_hash - the hash of the claim secret used to redeem the reimbursement
     */
    #[private]
    fn reimburse_united_spot(
        email_inputs: UnitedBillingParamsContract,
        amount_to_date_length: u32,
        remaining_length: u32,
        actual_length: u32,
        claim_secret_hash: Field,
    ) -> Field {
        // mainly segregated for code audit
        reimburse_united(
            email_inputs,
            amount_to_date_length,
            remaining_length,
            actual_length,
            claim_secret_hash,
            storage,
            &mut context
        )
    }

    #[private]
    #[internal]
    pub fn united_deferred_verification(
        // general email inputs
        email_inputs: UnitedBillingParamsContract,
        // body lengths
        amount_to_date_length: u32,
        remaining_length: u32,
        actual_length: u32
    ) -> [Field; 3] {
        // mainly segregated for code audit
        united_deferred(
            email_inputs,
            amount_to_date_length,
            remaining_length,
            actual_length,
            &mut context
        )
    }

    /**
     * Ensures the deferred access to hashing is correct
     *
     * @param hash_state_after_body - the hash state after the body has been hashed
     * @param hash_state_before_date - the precomputed hash state before the destination has been hashed
     * @param hash_state_after_destination - the hash state after the destination has been hashed
     * @param signed_body_hash - the signed body hash
     * @param actual_length - the actual length of the entire email body
     * @param amount_to_date_length - the length of the body between the amount and date selection
     * @param remaining_length - the length of the body after all selections have been made
     */
    #[private]
    #[internal]
    pub fn finish_hashing(
        hash_state_after_body: [u32; 8],
        hash_state_before_date: [u32; 8],
        hash_state_after_destination: [u32; 8],
        signed_body_hash: [u8; 32],
        actual_length: u32,
        amount_to_date_length: u32,
        remaining_length: u32
    ) {
        // mainly segregated for code audit
        finish_hash(
            hash_state_after_body,
            hash_state_before_date,
            hash_state_after_destination,
            signed_body_hash,
            actual_length,
            amount_to_date_length,
            remaining_length,
            &mut context
        );
    }

    #[private]
    #[internal]
    pub fn interstitial_hashing(
        state: [u32; 8],
        length: u32,
    ) -> [u32; 8] {
        // mainly segregated for code audit
        interstitial_hash(state, length, &mut context)
    }

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


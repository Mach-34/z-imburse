use aztec::macros::aztec;

global HASH_CHUNK_MAX_LENGTH: u32 = 2048;
global ZERO_DESTINATION: str<31> = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";

mod capsule;
mod contract_interfaces;
mod library_methods;
mod types;
mod verifiers;

#[aztec]
contract ZImburseEscrow {
    use std::{
        meta::derive, collections::bounded_vec::BoundedVec, option::Option, hash::pedersen_hash,
    };
    use aztec::{
        macros::{
            storage::storage, events::event,
            functions::{private, public, internal, view, initializer},
        }, note::constants::MAX_NOTES_PER_PAGE, prelude::{AztecAddress, Map, PublicImmutable},
        protocol_types::traits::Serialize,
    };
    use zimburse_verifiers::{
        constants::{verifier_ids, USDC_DECIMALS},
        united::constants::UnitedBillingParamsContract,
        linode::constants::LinodeBillingParamsContract,
    };
    use crate::{
        capsule::{pop_capsule, arr_field_to_u8, remaining_chunks}, HASH_CHUNK_MAX_LENGTH,
        ZERO_DESTINATION,
        library_methods::{
            linode::linode,
            entitlements::give_entitlement,
        }, contract_interfaces::{check_dkim_key_hash_private, reimburse_to_claimant},
        verifiers::verify_united_deferred,
        types::{
            escrow_definition::{EscrowDefinition, TITLE_LENGTH}, entitlement_note::EntitlementNote,
            entitlement_set::EntitlementSet,
        },
    };
    use zkemail::{
        KEY_LIMBS_2048, Sequence, dkim::RSAPubkey,
        partial_hash::{partial_sha256_var_interstitial, partial_sha256_var_end},
    };
    
    #[derive(Serialize)]
    #[event]
    struct RecurringReimbursementClaimed {
        claimant: AztecAddress,
        amount: Field,
        verifier_id: u8,
        timestamp: Field,
    }

    #[derive(Serialize)]
    #[event]
    struct SpotReimbursementClaimed {
        claimant: AztecAddress,
        amount: Field,
        verifier_id: u8,
    }

    #[derive(Serialize)]
    #[event]
    struct EntitlementNullified {
        randomness: Field,
    }

    #[storage]
    struct Storage<Context> {
        definition: PublicImmutable<EscrowDefinition, Context>,
        entitlements: EntitlementSet<EntitlementNote, Context>,
        nullifiers: Map<Field, PublicImmutable<bool, Context>, Context>
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

    #[public]
    #[internal]
    pub fn init_nullifier(nullifier: Field) { 
        storage.nullifiers.at(nullifier).initialize(true);
    }

    /**
     * Claim a recurring reimbursement for a Linode hosting receipt
     * @dev use separate function from spot to optimize gates by avoiding if statements
     *
     * @param email_receipt_inputs - the inputs from the email verifier
     * @return the amount reimbursed
     */
    #[private]
    pub fn reimburse_linode_recurring(
        email_receipt_inputs: LinodeBillingParamsContract,
    ) -> Field {
        // common logic for claiming a Linode entitlement
        let (entitlement, admin, amount_to_reimburse, timestamp) = linode(
            email_receipt_inputs,
            false, // recurring
            &mut context,
            storage
        );

        // check that the entitlement has not been nullified by the admin
        let shared_nullifier = entitlement.derive_shared_nullifier();
        let is_nullified = storage.nullifiers.at(shared_nullifier).read();
        assert(!is_nullified, "Entitlement is nullified");

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
     * @return the amount reimbursed
     */
    #[private]
    fn reimburse_linode_spot(
        email_receipt_inputs: LinodeBillingParamsContract,
    ) -> Field {
        let sender = context.msg_sender();
        // common logic for claiming a Linode entitlement
        let (entitlement, admin, amount_to_reimburse, timestamp) = linode(
            email_receipt_inputs,
            true, // spot
            &mut context,
            storage
        );

        // check that the receipt is valid for the entitlement date range
        entitlement.check_date_range(timestamp as u32);

        // check that the entitlement has not been nullified by the admin
        let shared_nullifier = entitlement.derive_shared_nullifier();
        let is_nullified = storage.nullifiers.at(shared_nullifier).read();
        assert(!is_nullified, "Entitlement is nullified");

        // broadcast the note nullifier
        ZImburseEscrow::at(context.this_address())
            .init_nullifier(shared_nullifier)
            .enqueue(&mut context);

        // emit event to notify admin of spot entitlement consumption
        entitlement.emit_nullified(&mut context, admin, sender);

        // notify admin of reimbursement
        entitlement.emit_spot_claim(
            &mut context,
            admin,
            amount_to_reimburse
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
    ) -> Field {
        let extracted = [0, 0, 0];
        let billed_amount = U128::from_integer(extracted[0] * USDC_DECIMALS);
        let timestamp = extracted[1];
        let destination_airport = extracted[2];
        let sender = context.msg_sender();
        let note_wrapped = storage.entitlements.get_matching_entitlement(
            sender,
            sender,
            verifier_ids::UNITED_AIRLINES,
            true
        );
        assert(note_wrapped.is_some(), "No entitlements to redeem");
        let entitlement = note_wrapped.unwrap();
        assert(entitlement.recipient == sender, "Entitlement does not belong to the caller");
        let definition = storage.definition.read();
        let dkim_key_hash = pedersen_hash(email_inputs.pubkey_modulus);
        let registered_verifier_id = check_dkim_key_hash_private(
            &mut context,
            definition.registry,
            dkim_key_hash
        );
        assert(
            (registered_verifier_id as u8) == verifier_ids::UNITED_AIRLINES, 
            "DKIM key is not registered for United Airlines"
        );
        entitlement.check_date_range(timestamp as u32);
        let amount_to_reimburse = entitlement.amount_to_reimburse(billed_amount);
        reimburse_to_claimant(&mut context, definition.usdc, context.msg_sender(), amount_to_reimburse);
        let email_nullifier = pedersen_hash(email_inputs.signature);
        context.push_nullifier(email_nullifier);

        let shared_nullifier = entitlement.derive_shared_nullifier();
        let is_nullified = storage.nullifiers.at(shared_nullifier).read();
        assert(!is_nullified, "Entitlement is nullified");
        ZImburseEscrow::at(context.this_address()).init_nullifier(shared_nullifier).enqueue(&mut context);
        
        entitlement.emit_nullified(&mut context, definition.admin, sender);
        entitlement.emit_spot_claim(
            &mut context,
            definition.admin,
            amount_to_reimburse,
        );
        amount_to_reimburse
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
        // verify the email with deferred hashing
        let deferred_results = verify_united_deferred(email_inputs.marshal());
        ZImburseEscrow::at(context.this_address())
            .finish_hashing(
                deferred_results.hash_state_after_body,
                email_inputs.partial_body_hash_date,
                deferred_results.hash_state_after_destination,
                deferred_results.signed_body_hash,
                actual_length,
                amount_to_date_length,
                remaining_length
            )
            .call(&mut context);
        // return extracted values
        [ 
            deferred_results.billed_amount,
            deferred_results.timestamp,
            deferred_results.destination_airport
        ]
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
        remaining_length: u32,
    ) {
        // hash from amount to date
        let computed_hash_state_before_date = ZImburseEscrow::at(context.this_address())
            .interstitial_hashing(hash_state_after_body, amount_to_date_length)
            .call(&mut context);
        // check the hashes match
        // ensures provenance over body up to to hash_state_after_destination
        assert(
            computed_hash_state_before_date == hash_state_before_date,
            "Could not verify body hash between amount and date/destination",
        );
        // hash the remaining data
        let interstitial = ZImburseEscrow::at(context.this_address())
            .interstitial_hashing(hash_state_after_destination, remaining_length)
            .call(&mut context);
        // finalize the hash
        let data = unsafe { arr_field_to_u8(pop_capsule::<HASH_CHUNK_MAX_LENGTH>()) };
        // complete the hash
        let remaining = unsafe {
            let mut size = HASH_CHUNK_MAX_LENGTH;
            if remaining_length % HASH_CHUNK_MAX_LENGTH != 0 {
                size = remaining_length % HASH_CHUNK_MAX_LENGTH;
            }
            size
        };
        let computed_body_hash =
            partial_sha256_var_end(interstitial, data, remaining as u64, actual_length as u64);
        // check the hashes match
        assert(
            computed_body_hash == signed_body_hash,
            "SHA256 hash computed over body does not match body hash found in DKIM-signed header",
        );
    }

    #[private]
    #[internal]
    pub fn interstitial_hashing(state: [u32; 8], length: u32) -> [u32; 8] {
        // get chunk from capsule oracle and convert to u8 (unconstrained, hash check will deal with it)
        let data = unsafe { arr_field_to_u8(pop_capsule::<HASH_CHUNK_MAX_LENGTH>()) };
        // determine length of data to hash
        let (hash_length, resume) = unsafe { remaining_chunks(length) };
        // hash the data
        let mut interstitial = partial_sha256_var_interstitial(state, data, hash_length);
        // if there is more data to hash, continue hashing
        if resume {
            interstitial = ZImburseEscrow::at(context.this_address())
                .interstitial_hashing(interstitial, length - HASH_CHUNK_MAX_LENGTH)
                .call(&mut context);
        }
        // return the interstitial hash
        interstitial
    }

    /**
     * Emit the nullifiers for entitlements for which counterpart note has already been nullified
     * @dev will fail @ kernel if already emitted
     *
     * @param entropy_values - an BoundeVec containing entropy values to filter notes by
     */
    #[private]
    pub fn nullify_entitlement(entropy_values: [Field; 10]) {
        // check is escrow admin
        let sender = context.msg_sender();

        for i in 0..entropy_values.len() {
            if entropy_values[i] != 0 {
                // pop note for sender
                let entitlement = storage.entitlements.pop_entitlement(
                    sender,
                    Option::none(),
                    Option::none(),
                    Option::none(),
                    Option::some(entropy_values[i])
                );

                // ensure counterparty note has been nullfied
                let shared_nullifier = entitlement.derive_shared_nullifier();
                let is_nullified = storage.nullifiers.at(shared_nullifier).read();
                assert(!is_nullified, "Counterparty entitlement already nullified");
            }
        }
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
        let definition = storage.definition.read();
        assert(sender == definition.admin, "Only the escrow admin can revoke entitlements");

        // try to pop a note for this recipient
        let entitlement = storage.entitlements.pop_entitlement(
            sender,
            Option::some(recipient),
            Option::some(verifier_type),
            Option::some(spot),
            Option::none()
        );
        // ensure the note is to/ from correctly
        assert(entitlement.recipient == recipient, "Entitlement does not belong to the recipient");

        // nullify the entitlement
        let shared_nullifier = entitlement.derive_shared_nullifier();
        let is_nullified = storage.nullifiers.at(shared_nullifier).read();
        assert(!is_nullified, "Entitlement is already nullified");
        ZImburseEscrow::at(context.this_address())
            .init_nullifier(shared_nullifier)
            .enqueue(&mut context);
        
        // emit event to notify recipient of revocation
        entitlement.emit_nullified(&mut context, entitlement.recipient, sender);
    }

    /**
     * Get the title of the Z-Imburse escrow
     */
    #[public]
    #[view]
    pub fn get_title() -> [u8; TITLE_LENGTH] {
        storage.definition.read().title_as_string()
    }

    /**
     * Privately get the admin of the ZImburse escrow contract
     *
     * @return the admin of the ZImburse escrow contract
     */
    #[private]
    #[view]
    pub fn get_admin_private() -> AztecAddress {
        storage.definition.read().admin
    }

    /**
     * Get the params needed to constrain the escrow registration process
     *
     * @return [registry, usdc, admin]
     */
    #[private]
    #[view]
    pub fn get_registration_params() -> [AztecAddress; 3] {
        let definition = storage.definition.read();
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

    unconstrained pub fn get_shared_nullifier(
        offset: u32,
        scope: AztecAddress,
        recipient: AztecAddress,
        verifier_id: u8,
        spot: bool
    ) -> Option<Field> {
        let (entitlements, _) = storage.entitlements.view_entitlements(
            offset,
            scope,
            Option::some(recipient),
            Option::some(verifier_id),
            Option::some(spot)
        );
        if entitlements.len() == 0 {
            Option::none()
        } else {
            let entitlement = entitlements.get_unchecked(0);
            Option::some(entitlement.derive_shared_nullifier())
        }
    }
}


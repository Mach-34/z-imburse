use dep::aztec::macros::aztec;

mod constants;
mod registry_interface;
mod types;
mod verifiers;

#[aztec]
contract ZImburseEscrow {
    use std::{meta::derive, collections::bounded_vec::BoundedVec, option::Option};
    use aztec::{
        encrypted_logs::{
            encrypted_note_emission::{encode_and_encrypt_note, encode_and_encrypt_note_unconstrained},
            encrypted_event_emission::{encode_and_encrypt_event, encode_and_encrypt_event_unconstrained}
        },
        keys::getters::get_public_keys,
        macros::{storage::storage, events::event, functions::{private, public, internal, view, initializer}},
        note::{
            note_getter_options::{NoteStatus, NoteGetterOptions}, note_viewer_options::NoteViewerOptions,
            constants::MAX_NOTES_PER_PAGE
        },
        oracle::{random::random, notes::check_nullifier_exists, debug_log::debug_log_format},
        prelude::{AztecAddress, PrivateSet, SharedImmutable, Map}, protocol_types::traits::Serialize,
        utils::comparison::Comparator
    };
    use token::Token;
    use zimburse_verifiers::{
        linode::constants::{MAX_LINODE_EMAIL_BODY_LENGTH, MAX_LINODE_EMAIL_HEADER_LENGTH},
        zkemail::KEY_LIMBS_2048
    };
    use crate::{
        types::{
            escrow_definition::{EscrowDefinition, TITLE_LENGTH},
            entitlement_note::EntitlementNote,
            entitlement_set::EntitlementSet
        },
        registry_interface::check_dkim_key_hash_private,
        verifiers::{verifier_ids, verify_linode}
    };

    #[event]
    #[derive(Serialize)]
    struct RecurringReimbursementClaimed {
        claimant: AztecAddress,
        amount: Field,
        verifier_id: u8,
        datetime: Field
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
    struct EntitlementRevoked {
        verifier_id: u8,
        amount: Field
    }

    #[storage]
    struct Storage<Context> {
        definition: SharedImmutable<EscrowDefinition, Context>,
        entitlements: EntitlementSet<EntitlementNote, Context>,
        // entitlements: Map<AztecAddress, PrivateSet<EntitlementNote, Context>, Context>,
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

    // // #[private]
    // // fn give_spot_entitlement(to: AztecAddress, amount: Field, verifier_id: u8, date_start: u32, date_end: u32, destination: str<31>) -> {

    // // }

    #[private]
    fn give_recurring_entitlement(recipient: AztecAddress, amount: Field, verifier_id: u8) {
        // check that no receipt exists for this recipient and verifier
        let entitlement_exists = storage.entitlements.get_matching_entitlement(
            context.msg_sender(),
            recipient,
            verifier_id,
            false
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
    
    #[private]
    fn reimburse_linode_recurring(
        // email inputs
        body: [u8; MAX_LINODE_EMAIL_BODY_LENGTH],
        body_hash_index: u32,
        body_length: u32,
        header: [u8; MAX_LINODE_EMAIL_HEADER_LENGTH],
        header_length: u32,
        pubkey: [Field; KEY_LIMBS_2048],
        pubkey_redc: [Field; KEY_LIMBS_2048],
        signature: [Field; KEY_LIMBS_2048],
        from_index: u32,
        subject_index: u32,
        amount_index: u32,
        amount_length: u32,
        date_index: u32,
        receipt_id_length: u32,
        // claim hash
        claim_secret_hash: Field,
    ) -> Field {
        let sender = context.msg_sender();

        // retrieve a Linode hosting entitlement
        let note_wrapped = storage.entitlements.get_matching_entitlement(
            sender,
            sender,
            verifier_ids::LINODE,
            false
        );
        assert(note_wrapped.is_some(), "No entitlements to redeem");

        // check the msg sender can use the entitlement
        let entitlement = note_wrapped.unwrap();
        assert(entitlement.recipient == sender, "Entitlement does not belong to the caller");

        // verify linode billing receipt and extract amount, date, keyhash
        let linode_outputs = verify_linode(
            body,
            body_hash_index,
            body_length,
            header,
            header_length,
            pubkey,
            pubkey_redc,
            signature,
            from_index,
            subject_index,
            amount_index,
            amount_length,
            date_index,
            receipt_id_length
        );

        // handle recurring nullification
        entitlement.check_and_emit_recurring_nullifier(&mut context, linode_outputs.timestamp);

        // check the dkim key hash matches the linode verifier id
        let definition = storage.definition.read_private();
        let registered_verifier_id = check_dkim_key_hash_private(
            &mut context,
            definition.registry,
            linode_outputs.dkim_key_hash
        );
        assert((registered_verifier_id as u8) == verifier_ids::LINODE, "DKIM key is not registered for Linode");

        // determine the amount to reimburse
        let amount_to_reimburse = entitlement.amount_to_reimburse(linode_outputs.billed_amount);

        // notify admin of reimbursement
        RecurringReimbursementClaimed {
            claimant: sender,
            amount: amount_to_reimburse,
            verifier_id: verifier_ids::LINODE,
            datetime: linode_outputs.timestamp
        }.emit(
            encode_and_encrypt_event(
                &mut context,
                get_public_keys(sender).ovpk_m,
                get_public_keys(definition.admin).ivpk_m,
                definition.admin
            )
        );

        // release funds from escrow by shielding in public
        Token::at(definition.usdc).shield(
            context.this_address(),
            amount_to_reimburse,
            claim_secret_hash,
            0
        ).enqueue(&mut context);
        
        // return the amount reimbursed
        amount_to_reimburse
    }

    // #[private]
    // fn reimburse_linode_spot(
    //     // email inputs
    //     body: [u8; MAX_LINODE_EMAIL_BODY_LENGTH],
    //     body_hash_index: u32,
    //     body_length: u32,
    //     header: [u8; MAX_LINODE_EMAIL_HEADER_LENGTH],
    //     header_length: u32,
    //     pubkey: [Field; KEY_LIMBS_2048],
    //     pubkey_redc: [Field; KEY_LIMBS_2048],
    //     signature: [Field; KEY_LIMBS_2048],
    //     from_index: u32,
    //     subject_index: u32,
    //     amount_index: u32,
    //     amount_length: u32,
    //     date_index: u32,
    //     receipt_id_length: u32,
    //     // claim hash
    //     claim_secret_hash: Field,
    //     // spot selector
    //     is_spot: bool
    // ) -> Field {
    //     // retrieve a Linode hosting entitlement
    //     let notes = storage.entitlements.at(context.msg_sender()).get_notes(
    //         NoteGetterOptions::new()
    //             .select(EntitlementNote::properties().verifier_id, Comparator.EQ, verifiers::LINODE)
    //             .select(EntitlementNote::properties().spot, Comparator.EQ, is_spot)
    //             .set_limit(1)
    //     );
    //     assert(notes.len() == 1, "No entitlements to redeem");
    //     let note = notes.get_unchecked(0);
    //     assert(note.recipient == context.msg_sender(), "Entitlement does not belong to the recipient");

    //     // ensure the note has not been nullified by the admin
    //     // note: use check_nullifier_exists - much cheaper and will fail kernel if oracle lies
    //     let note_nullifier = note.compute_nullifier(&mut context, note.compute_note_hash());
    //     let exists = check_nullifier_exists(note.compute_nullifier(&mut context, note.compute_note_hash()));
    //     assert(!exists, "Entitlement has been nullified");

    //     // // verify linode billing receipt and extract amount, date, keyhash
    //     // // todo: create a new function with pop_capsule to handle custom logic & inputs per email
    //     let linode_receipt_result = verify_linode_billing_receipt(
    //         body,
    //         body_hash_index,
    //         body_length,
    //         header,
    //         header_length,
    //         pubkey,
    //         pubkey_redc,
    //         signature,
    //         from_index,
    //         subject_index,
    //         amount_index,
    //         amount_length,
    //         date_index,
    //         receipt_id_length
    //     );
    //     let dkim_key_hash = linode_receipt_result[0];
    //     let unix_month = linode_receipt_result[1]; // month and year
    //     // billed amount returns 2 decimals, so multiply billed_amount by 10,000
    //     let billed_amount = U128::from_integer(linode_receipt_result[2] * 10000);

    //     // check the dkim key hash matches the linode verifier id
    //     let definition = storage.definition.read_private();
    //     let registered_verifier_id = check_dkim_key_hash_private(&mut context, definition.registry, dkim_key_hash);
    //     assert((registered_verifier_id as u8) == verifiers::LINODE, "DKIM key is not registered for Linode");

    //     // determine the amount to reimburse
    //     let amount_to_reimburse = if note.max_value >= billed_amount {
    //         billed_amount.to_field()
    //     } else {
    //         note.max_value.to_field()
    //     };

    //     // notify admin of reimbursement
    //     RecurringReimbursementClaimed {
    //         claimant: context.msg_sender(),
    //         amount: amount_to_reimburse,
    //         verifier_id: verifiers::LINODE,
    //         datetime: unix_month
    //     }.emit(
    //         encode_and_encrypt_event(
    //             &mut context,
    //             get_public_keys(context.msg_sender()).ovpk_m,
    //             get_public_keys(definition.admin).ivpk_m,
    //             definition.admin
    //         )
    //     );



    //     // check that this entitlement has not been emitted for this month and add it
    //     // todo: check the nullifier non-inclusion once out of txe
    //     // constrained to use the year/month unix timestamp computed by email verifier
    //     // todo: silo nullifiers to contract address
    //     let recurring_nullifier = note.derive_recurring_nullifier(unix_month);
    //     let recurring_nullifier_exists = check_nullifier_exists(recurring_nullifier);
    //     assert(!recurring_nullifier_exists, "Entitlement has already been claimed for this month");
    //     // let recurring_nullifier_exists = storage.entitlement_nullifiers.at(recurring_nullifier).read_private();
    //     // context.historical_header.prove_nullifier_non_inclusion(recurring_nullifier);
    //     // dep::aztec::oracle::debug_log::debug_log_format("Proved recurring nullifier was not included", []);
    //     context.push_nullifier(recurring_nullifier);
    //     // dep::aztec::oracle::debug_log::debug_log_format("Pushed recurring nullifier", []);

    //     // release funds from escrow by shielding in public
    //     let token_address = storage.definition.read_private().usdc;
    //     Token::at(token_address).shield(
    //         context.this_address(),
    //         amount_to_reimburse,
    //         claim_secret_hash,
    //         0
    //     ).enqueue(&mut context);
    //     // todo: should we hash the claim secret inside and emit event so it ins't lost?
    //     amount_to_reimburse
    // }

    /**
     * Emit the nullifier for a recurring entitlement
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

        // emit event to notify recipient of revocation
        EntitlementRevoked { verifier_id: verifier_type, amount: entitlement.max_value.to_integer() }.emit(
            encode_and_encrypt_event(
                &mut context,
                get_public_keys(sender).ovpk_m,
                get_public_keys(recipient).ivpk_m,
                recipient
            )
        );
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


use dep::aztec::macros::aztec;

mod constants;
mod registry_interface;
mod types;
mod verifiers;

#[aztec]
contract ZImburseEscrow {
    use std::meta::derive;
    use dep::aztec::prelude::{AztecAddress, PrivateSet, SharedImmutable, Map};
    use dep::aztec::encrypted_logs::{
        encrypted_note_emission::{encode_and_encrypt_note, encode_and_encrypt_note_unconstrained},
        encrypted_event_emission::encode_and_encrypt_event
    };
    use dep::aztec::macros::{storage::storage,  events::event, functions::{private, public, internal, view, initializer}};
    use dep::aztec::keys::getters::get_public_keys;
    use dep::aztec::note::{note_getter_options::NoteGetterOptions, note_viewer_options::NoteViewerOptions};
    use dep::aztec::oracle::{random::random, notes::check_nullifier_exists};
    use dep::aztec::utils::comparison::Comparator;
    use dep::aztec::protocol_types::traits::Serialize;
    use dep::token::Token;
    use dep::address_note::address_note::AddressNote;
    use dep::zimburse_verifiers::{
        constants::{MAX_LINODE_EMAIL_BODY_LENGTH, MAX_LINODE_EMAIL_HEADER_LENGTH},
        linode::verify_linode_billing_receipt,
        zkemail::KEY_LIMBS_2048
    };
    use crate::{
        types::{
            escrow_definition::{EscrowDefinition, TITLE_LENGTH},
            recurring_entitlement_note::RecurringEntitlementNote
        },
        registry_interface::check_dkim_key_hash_private,
        verifiers,
    };

    #[event]
    #[derive(Serialize)]
    struct RecurringReimbursementClaimed {
        claimant: AztecAddress,
        amount: Field,
        verifier_id: u8,
        datetime: Field
    }
    
    
    #[storage]
    struct Storage<Context> {
        definition: SharedImmutable<EscrowDefinition, Context>,
        recurring_entitlements: Map<AztecAddress, PrivateSet<RecurringEntitlementNote, Context>, Context>,
        entitlement_nullifiers: Map<Field, SharedImmutable<bool, Context>, Context>
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
    fn constructor(
        registry: AztecAddress,
        usdc_token: AztecAddress,
        title: str<TITLE_LENGTH>
    ) {
        let definition = EscrowDefinition::new(
            registry,
            context.msg_sender(),
            usdc_token,
            title
        );
        storage.definition.initialize(definition);
    }


    #[private]
    fn give_recurring_entitlement(to: AztecAddress, amount: Field, verifier_id: u8) {
        // check that no receipt exists for this recipient and verifier
        // let options =  NoteGetterOptions::new()
                // .select(EntitlementReceiptNote::properties().recipient, dep::aztec::utils::comparison::Comparator::EQ, to)
                // .select(EntitlementReceiptNote::properties().verifier_id, dep::aztec::utils::comparison::Comparator::EQ, verifier_id)
                // .set_limit(1);
        // let notes = storage.entitlement_receipts.get_notes(options);
        // assert(notes.len() == 0, "An entitlement already exists for this recipient and verifier");
        // check is escrow admin
        let admin = storage.definition.read_private().admin;
        assert(context.msg_sender() == admin, "Only the escrow admin can give entitlements");

        // get nullifying keys for admin and recipient
        let recipient_keys = get_public_keys(to);
        let admin_keys = get_public_keys(admin);
        // create random value here since shared in both notes
        let blinding_factor = unsafe { random() };
        // add the note for the recipient
        // todo: will the header be mutated here or can we skip duplication
        let amount = U128::from_integer(amount);
        let mut entitlement_recipient = RecurringEntitlementNote::new(
            admin,
            to,
            false,
            verifier_id,
            amount,
            blinding_factor
        );
        storage.recurring_entitlements.at(to).insert(&mut entitlement_recipient).emit(
            encode_and_encrypt_note(&mut context, admin_keys.ovpk_m, recipient_keys.ivpk_m, to)
        );
        // add the note for the admin
        let mut entitlement_sender = RecurringEntitlementNote::new(
            admin,
            to,
            true,
            verifier_id,
            amount,
            blinding_factor
        );
        storage.recurring_entitlements.at(admin).insert(&mut entitlement_sender).emit(
            encode_and_encrypt_note(&mut context, admin_keys.ovpk_m, admin_keys.ivpk_m, admin)
        )
    }

    // #[private]
    // fn nullify_recurring_entitlement(to: AztecAddress, verifier_id: u8) {
    //     // check is escrow admin
    //     let admin = storage.definition.read_private().admin;
    //     assert(context.msg_sender() == admin, "Only the escrow admin can give entitlements");

    //     // get note receipt note for user and verifier type
    //     // pop notes to destroy them
    //     // let notes = storage.entitlement_receipts.pop_notes(
    //     //     NoteGetterOptions::new()
    //     //         .select(EntitlementReceiptNote::properties().recipient, Comparator::EQ, to)
    //     //         .select(EntitlementReceiptNote::properties().verifier_id, Comparator::EQ, verifier_id)
    //     //         .set_limit(1)
    //     // );
    //     // assert(notes.len() == 1, "No entitlements to nullify");
    //     // let note = notes.get_unchecked(0);
    //     // check that the revocation nullifier has not been emitted
    //     // let revocation_nullifier = note.compute_revocation_nullifier();
    //     // let revocation_nullifier_exists = storage.entitlement_nullifiers.at(revocation_nullifier).read_private();
    //     // assert(!revocation_nullifier_exists, "Entitlement has been revoked");

    //     // // emit the nullifier
    //     // ZImburseEscrow::at(context.this_address()).emit_entitlement_nullifier(revocation_nullifier).enqueue(&mut context);
    // }

    #[private]
    fn reimburse_linode(
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
        // retrieve a Linode hosting entitlement
        let notes = storage.recurring_entitlements.at(context.msg_sender()).get_notes(
            NoteGetterOptions::new()
                // .select(RecurringEntitlementNote::properties().verifier_id, Comparator.EQ, receipt_verifier_id::LINODE)
                .set_limit(1)
        );
        assert(notes.len() == 1, "No entitlements to redeem");
        let note = notes.get_unchecked(0);
        assert(note.recipient == context.msg_sender(), "Entitlement does not belong to the sender");
        
        // ensure the note has not been nullified by the admin
        // todo: switch for nullifier non-inclusion check once out of txe
        let note_nullifier = note.compute_nullifier(&mut context, note.compute_note_hash());
        context.historical_header.prove_nullifier_non_inclusion(note_nullifier);
        // let exists = check_nullifier_exists(note.compute_nullifier(&mut context, note.compute_note_hash()));
        // assert(!exists, "Entitlement has been nullified");

        // // verify linode billing receipt and extract amount, date, keyhash
        // // todo: create a new function with pop_capsule to handle custom logic & inputs per email
        let linode_receipt_result = verify_linode_billing_receipt(
            body, body_hash_index, body_length, header, header_length, pubkey, pubkey_redc, signature, from_index, subject_index, amount_index, amount_length, date_index, receipt_id_length
        );
        let dkim_key_hash = linode_receipt_result[0];
        let unix_month = linode_receipt_result[1]; // month and year
        // billed amount returns 2 decimals, so multiply billed_amount by 10,000
        let billed_amount = U128::from_integer(linode_receipt_result[2] * 10000);

        // check the dkim key hash matches the linode verifier id
        let registry = storage.definition.read_private().registry;
        let registered_verifier_id = check_dkim_key_hash_private(&mut context, registry, dkim_key_hash);
        assert(
            (registered_verifier_id as u8) == verifiers::LINODE,
            "DKIM key is not registered for Linode"
        );

        // determine the amount to reimburse
        let amount_to_reimburse = if note.max_value >= billed_amount {
            billed_amount.to_field()
        } else {
            note.max_value.to_field()
        };

        // notify admin of reimbursement
        RecurringReimbursementClaimed {
            claimant: context.msg_sender(),
            amount: amount_to_reimburse,
            verifier_id: verifiers::LINODE,
            datetime: unix_month
        }.emit(encode_and_encrypt_event(
            &mut context,
            get_public_keys(context.msg_sender()).ovpk_m,
            get_public_keys(note.admin).ivpk_m,
            note.admin
        ));

        // check that this entitlement has not been emitted for this month and add it
        // todo: check the nullifier non-inclusion once out of txe
        // constrained to use the year/month unix timestamp computed by email verifier
        // todo: silo nullifiers to contract address
        let recurring_nullifier = note.derive_recurring_nullifier(unix_month);
        // let recurring_nullifier_exists = storage.entitlement_nullifiers.at(recurring_nullifier).read_private();
        // assert(!recurring_nullifier_exists, "Entitlement has already been redeemed for this month");
        context.historical_header.prove_nullifier_non_inclusion(recurring_nullifier);
        context.push_nullifier(recurring_nullifier);

        // release funds from escrow by shielding in public
        // todo: do we need a private event? or is it sufficient to instantly claim?
        // worry would be waiting/ disconnection
        let token_address = storage.definition.read_private().usdc;
        Token::at(token_address).shield(context.this_address(), amount_to_reimburse, claim_secret_hash, 0).enqueue(&mut context);

        amount_to_reimburse
    }

    

    // /**
    //  * Emit the nullifier for a recurring entitlement
    //  *
    //  * @param from - the address to revoke entitlement for
    //  * @param verifier_type - the verifier type to revoke entitlement for
    //  */
    // #[private]
    // pub fn revoke_recurring_entitlement(from: AztecAddress, verifier_type: u8) {
    //     // check is escrow admin
    //     let defintion = storage.definition.read_private();
    //     assert(context.msg_sender() == defintion.admin, "Only the escrow admin can revoke entitlements");

    //     // try to pop a note for this recipient
    //     // should automatically emit the nullifier
    //     let notes = storage.recurring_entitlements.at(context.msg_sender()).pop_notes(
    //         NoteGetterOptions::new()
    //             .select(RecurringEntitlementNote::properties().verifier_id, Comparator::EQ, verifier_type)
    //             .select(RecurringEntitlementNote::properties().recipient, Comparator::EQ, from)
    //             .set_limit(1)
    //     );
        
    //     // ensure the note is to/ from correctly
    //     assert(notes.len() == 1, "No entitlements to revoke");
    //     let note = notes.get_unchecked(0);
    //     assert(note.recipient == from, "Entitlement does not belong to the recipient");
    //     // todo: emit event to recipient
    // }

    /**
     * Get the title of the Z-Imburse escrow
     */
    #[public]
    #[view]
    pub fn get_title() -> [u8; TITLE_LENGTH]{
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

    // #[private]
    // #[view]
    // pub fn get_recurring_entitlements_private(from: AztecAddress, verifier_id: u8, offset: u32) -> PrivateSet<RecurringEntitlementNote> {
    //     let options = NoteGetterOptions::new()
    //         .set
    // }
    
}


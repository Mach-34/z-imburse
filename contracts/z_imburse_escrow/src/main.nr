use dep::aztec::macros::aztec;

mod constants;
mod types;

#[aztec]
contract ZImburseEscrow {
    use dep::aztec::prelude::{AztecAddress, PrivateSet, SharedImmutable, Map};
    use dep::aztec::encrypted_logs::encrypted_note_emission::{encode_and_encrypt_note, encode_and_encrypt_note_unconstrained};
    use dep::aztec::macros::{storage::storage, functions::{private, public, internal, view, initializer}};
    use dep::aztec::keys::getters::get_public_keys;
    use dep::aztec::note::{note_getter_options::NoteGetterOptions, note_viewer_options::NoteViewerOptions};
    use dep::aztec::oracle::random::random;
    use dep::aztec::utils::comparison::Comparator;
    
    use dep::token::Token;
    use dep::address_note::address_note::AddressNote;
    use dep::zimburse_verifiers::{
        constants::{MAX_LINODE_EMAIL_BODY_LENGTH, MAX_LINODE_EMAIL_HEADER_LENGTH},
        linode::verify_linode_billing_receipt,
        zkemail::KEY_LIMBS_2048
    };
    use dep::z_imburse_dkim_registry::{ZImburseDkimRegistry, receipt_verifier_id};

    use crate::types::{
        escrow_definition::{EscrowDefinition, TITLE_LENGTH},
        recurring_entitlement_note::RecurringEntitlementNote,
        entitlement_receipt_note::EntitlementReceiptNote
    };
    
    #[storage]
    struct Storage<Context> {
        definition: SharedImmutable<EscrowDefinition, Context>,
        recurring_entitlements: Map<AztecAddress, PrivateSet<RecurringEntitlementNote, Context>, Context>,
        entitlement_receipts: PrivateSet<EntitlementReceiptNote, Context>,
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
        dkimRegistry: AztecAddress,
        escrowRegistry: AztecAddress,
        usdc_token: AztecAddress,
        title: str<TITLE_LENGTH>
    ) {
        let definition = EscrowDefinition::new(
            dkimRegistry,
            escrowRegistry,
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
        let admin_keys = get_public_keys(context.msg_sender());
        // create random value here since shared in both notes
        let blinding_factor = unsafe { random() };
        // create entitlement note for recipient to spend
        let amount = U128::from_integer(amount);
        let mut entitlement = RecurringEntitlementNote::new(
            to,
            recipient_keys.npk_m.hash(),
            admin_keys.npk_m.hash(),
            verifier_id,
            amount,
            blinding_factor
        );
        storage.recurring_entitlements.at(to).insert(&mut entitlement).emit(
            encode_and_encrypt_note(&mut context, admin_keys.ovpk_m, recipient_keys.ivpk_m, to)
        );
        // create entitlement receipt for admin to keep track of & potentially nullify
        let mut receipt = EntitlementReceiptNote::new(
            to,
            admin_keys.npk_m.hash(),
            verifier_id,
            amount,
            blinding_factor
        );
        storage.entitlement_receipts.insert(&mut receipt).emit(
            encode_and_encrypt_note_unconstrained(&mut context, admin_keys.ovpk_m, admin_keys.ivpk_m, context.msg_sender())
        );
    }

    #[private]
    fn nullify_recurring_entitlement(to: AztecAddress, verifier_id: u8) {
        // check is escrow admin
        let admin = storage.definition.read_private().admin;
        assert(context.msg_sender() == admin, "Only the escrow admin can give entitlements");

        // get note receipt note for user and verifier type
        // pop notes to destroy them
        // let notes = storage.entitlement_receipts.pop_notes(
        //     NoteGetterOptions::new()
        //         .select(EntitlementReceiptNote::properties().recipient, Comparator::EQ, to)
        //         .select(EntitlementReceiptNote::properties().verifier_id, Comparator::EQ, verifier_id)
        //         .set_limit(1)
        // );
        // assert(notes.len() == 1, "No entitlements to nullify");
        // let note = notes.get_unchecked(0);
        // check that the revocation nullifier has not been emitted
        // let revocation_nullifier = note.compute_revocation_nullifier();
        // let revocation_nullifier_exists = storage.entitlement_nullifiers.at(revocation_nullifier).read_private();
        // assert(!revocation_nullifier_exists, "Entitlement has been revoked");

        // // emit the nullifier
        // ZImburseEscrow::at(context.this_address()).emit_entitlement_nullifier(revocation_nullifier).enqueue(&mut context);
    }

    #[private]
    fn redeem_linode_entitlement(
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
    ) {
        // retrieve a Linode hosting entitlement
        let notes = storage.recurring_entitlements.at(context.msg_sender()).get_notes(
            NoteGetterOptions::new()
                // .select(RecurringEntitlementNote::properties().verifier_id, Comparator.EQ, receipt_verifier_id::LINODE)
                .set_limit(1)
        );
        assert(notes.len() == 1, "No entitlements to redeem");
        let note = notes.get_unchecked(0);
        assert(note.owner == context.msg_sender(), "Entitlement does not belong to the sender");
        // check that the revocation nullifier has not been emitted
        let revocation_nullifier = note.compute_revocation_nullifier();
        let revocation_nullifier_exists = storage.entitlement_nullifiers.at(revocation_nullifier).read_private();
        assert(!revocation_nullifier_exists, "Entitlement has been revoked");

        // verify linode billing receipt and extract amount, date, keyhash
        // todo: create a new function with pop_capsule to handle custom logic & inputs per email
        let linode_receipt_result = verify_linode_billing_receipt(
            body, body_hash_index, body_length, header, header_length, pubkey, pubkey_redc, signature, from_index, subject_index, amount_index, amount_length, date_index, receipt_id_length
        );
        let dkim_key_hash = linode_receipt_result[0];
        let unix_month = linode_receipt_result[1]; // month and year
        // billed amount returns 2 decimals, so multiply billed_amount by 10,000
        let billed_amount = U128::from_integer(linode_receipt_result[2] * 10000);

        // check the dkim key hash matches the linode verifier id
        let registry = storage.definition.read_private().dkimRegistry;
        let verifier_id = ZImburseDkimRegistry::at(registry).check_dkim_key_hash_private(dkim_key_hash).view(&mut context);
        assert(
            (verifier_id as u8) == receipt_verifier_id::LINODE,
            "DKIM key is not registered for Linode"
        );

        // check that this entitlement has not been emitted for this month
        // constrained to use the year/month unix timestamp computed by email verifier
        let recurring_nullifier = note.compute_recurring_nullifier(unix_month);
        let recurring_nullifier_exists = storage.entitlement_nullifiers.at(recurring_nullifier).read_private();
        assert(!recurring_nullifier_exists, "Entitlement has already been redeemed for this month");
        // enque emission of the nullifier too
        ZImburseEscrow::at(context.this_address()).emit_entitlement_nullifier(recurring_nullifier).enqueue(&mut context);

        // determine the amount to reimburse
        let amount_to_reimburse = if note.max_value >= billed_amount {
            billed_amount
        } else {
            note.max_value
        };

        // release funds from escrow by shielding in public
        // todo: do we need a private event? or is it sufficient to instantly claim?
        // worry would be waiting/ disconnection
        let token_address = storage.definition.read_private().usdc;
        Token::at(token_address).shield(context.this_address(), amount_to_reimburse.to_field(), claim_secret_hash, 0).enqueue(&mut context);
    }

    // #[private]
    // fn remove_nullified_recurring_notes() {
    //     let notes = storage.recurring_entitlements.at(context.msg_sender()).get_notes(
    //         NoteGetterOptions::new()
    //     );
    // }

    /**
     * Emit a nullifier from the private context for any reason (using spot, recurring, or revocation)
     * 
     * @param nullifier - the nullifier to emit
     */
    #[public]
    #[internal]
    pub fn emit_entitlement_nullifier(nullifier: Field) {
        storage.entitlement_nullifiers.at(nullifier).initialize(true);
        // todo: emit event on nullifier?
    }

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



    unconstrained fn log_note(from: AztecAddress) -> [Field; 6] {
        // retrieve a Linode hosting entitlement
        let notes = storage.recurring_entitlements.at(from).view_notes(
            NoteViewerOptions::new()
                // .select(RecurringEntitlementNote::properties().verifier_id, Comparator.EQ, receipt_verifier_id::LINODE)
                .set_limit(1)
        );
        let note = notes.get_unchecked(0);
        [
            note.owner.to_field(),
            note.npk_m_hash,
            note.revocation_npk_m_hash,
            note.verifier_id as Field, 
            note.max_value.to_integer(),
            note.randomness
        ]
    }
    
}


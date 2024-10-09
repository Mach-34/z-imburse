use dep::aztec::macros::aztec;

mod constants;
mod types;

#[aztec]
contract ZImburseEscrow {
    use dep::aztec::prelude::{AztecAddress, PrivateImmutable, PrivateSet, SharedImmutable, Map};
    use dep::aztec::encrypted_logs::encrypted_note_emission::encode_and_encrypt_note;
    use dep::aztec::macros::{storage::storage, functions::{private, public, view, initializer}};
    use dep::aztec::keys::getters::get_public_keys;
    use dep::address_note::address_note::AddressNote;
    use dep::aztec::note::note_getter_options::NoteGetterOptions;
    use dep::zimburse_verifiers::{
        constants::{MAX_LINODE_EMAIL_BODY_LENGTH, MAX_LINODE_EMAIL_HEADER_LENGTH},
        linode::verify_linode_billing_receipt,
        zkemail::KEY_LIMBS_2048
    };
    
    use crate::types::definition::{Definition, TITLE_LENGTH};
    use crate::types::recurring_entitlement_note::RecurringEntitlementNote;
    // use dep::aztec::macros::{storage::storage, functions::{private, initializer}};
    use dep::token::Token;

    #[storage]
    struct Storage<Context> {
        definition: SharedImmutable<Definition, Context>,
        entitlements: Map<AztecAddress, PrivateSet<RecurringEntitlementNote, Context>, Context>
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
        let definition = Definition::new(registry, context.msg_sender(), usdc_token, title);
        storage.definition.initialize(definition);
    }


    #[private]
    fn give_entitlement(to: AztecAddress, amount: Field) {
        let recipient_keys = get_public_keys(to);
        let admin_keys = get_public_keys(context.msg_sender());
        let mut entitlement: RecurringEntitlementNote = RecurringEntitlementNote::new(
            to,
            recipient_keys.npk_m.hash(),
            U128::from_integer(amount)
        );
        storage.entitlements.at(to).insert(&mut entitlement).emit(
            encode_and_encrypt_note(&mut context, admin_keys.ovpk_m, recipient_keys.ivpk_m, to)
        );
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
        // read note
        // todo: filter for linode entitlement
        let notes = storage.entitlements.at(context.msg_sender()).pop_notes(
            NoteGetterOptions::new().set_limit(1)
        );
        assert(notes.len() == 1, "No entitlements to redeem");
        let note = notes.get_unchecked(0);
        assert(note.owner == context.msg_sender(), "Entitlement does not belong to the sender");

        // verify linode billing receipt and extract amount, date, keyhash
        let linode_receipt_result = verify_linode_billing_receipt(
            body, body_hash_index, body_length, header, header_length, pubkey, pubkey_redc, signature, from_index, subject_index, amount_index, amount_length, date_index, receipt_id_length
        );
        let dkim_key_hash = linode_receipt_result[0];
        let datetime = linode_receipt_result[1];
        // billed amount returns 2 decimals, so multiply billed_amount by 10,000
        let billed_amount = U128::from_integer(linode_receipt_result[2] * 10000);

        // determine the amount to reimburse
        let amount_to_reimburse = if note.max_value >= billed_amount {
            billed_amount
        } else {
            note.max_value
        };

        // release funds from escrow by shielding in public
        // todo: event should notify how much was reimbursed
        let token_address = storage.definition.read_private().usdc;
        Token::at(token_address).shield(context.this_address(), amount_to_reimburse.to_field(), claim_secret_hash, 0).enqueue(&mut context);
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

}


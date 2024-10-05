use dep::aztec::macros::aztec;

mod constants;
mod types;
// mod date_parser;

#[aztec]
contract ZImburse {
    use dep::aztec::prelude::{AztecAddress, PrivateImmutable, PrivateSet, SharedImmutable, Map};
    use dep::aztec::encrypted_logs::encrypted_note_emission::encode_and_encrypt_note;
    use dep::aztec::macros::{storage::storage, functions::{private, public, view, initializer}};
    use dep::aztec::keys::getters::get_public_keys;
    use dep::address_note::address_note::AddressNote;
    use dep::aztec::note::note_getter_options::NoteGetterOptions;
    use dep::zimburse_verifiers::{
        constants::{MAX_EMAIL_BODY_LENGTH, MAX_EMAIL_HEADER_LENGTH},
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
        entitlements: Map<AztecAddress, PrivateSet<RecurringEntitlementNote, Context>, Context>.
        dkim_registry: Map<Field, SharedImmutable<Field, Context>, Context,
        nullified_entitlements: Map<Field, SharedImmutable<bool, Context>, Context>
    }


    /**
     * Initialize the Z-Imburse contract by setting the owner and USDC token.
     *
     * @param usdc_token The address of the USDC token
     */
    #[public]
    #[initializer]
    fn constructor(usdc_token: AztecAddress, title: str<TITLE_LENGTH>) {
        let definition = Definition::new(context.msg_sender(), usdc_token, title);
        storage.definition.initialize(definition);
    }


    #[private]
    fn give_entitlement(to: AztecAddress, amount: Field) {
        let recipient = get_public_keys(to);
        let mut entitlement: RecurringEntitlementNote = RecurringEntitlementNote::new(to, recipient.npk_m.hash(), U128::from_integer(amount));
        storage.entitlements.at(to).insert(&mut entitlement).emit(
            encode_and_encrypt_note(&mut context, context.msg_sender(), to)
        );
    }

    #[private]
    fn redeem_linode_entitlement(
        // email inputs
        body: [u8; MAX_EMAIL_BODY_LENGTH],
        body_hash_index: u32,
        body_length: u32,
        header: [u8; MAX_EMAIL_HEADER_LENGTH],
        header_length: u32,
        pubkey: [Field; KEY_LIMBS_2048],
        pubkey_redc: [Field; KEY_LIMBS_2048],
        signature: [Field; KEY_LIMBS_2048],
        from_index: u32,
        subject_index: u32,
        amount_index: u32,
        amount_length: u32,
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

        // verify linode billing receipt and extract amount
        // todo: return date and nullify for the month
        // todo: return dkim key and check against hash
        let mut billed_amount = U128::from_integer(verify_linode_billing_receipt(
            body, body_hash_index, body_length, header, header_length, pubkey, pubkey_redc, signature, from_index, subject_index, amount_index, amount_length, receipt_id_length
        ));
        // let mut billed_amount = U128::from_integer(2200);

        // billed amount returns 2 decimals, so multiply billed_amount by 10,000
        billed_amount = billed_amount * U128::from_integer(10000);

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

}


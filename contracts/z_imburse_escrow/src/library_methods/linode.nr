use aztec::prelude::{AztecAddress, PrivateContext};
use zimburse_verifiers::{
    linode::constants::LinodeBillingParamsContract,
    united::constants::UnitedBillingParamsContract,
    zkemail::KEY_LIMBS_2048
};
use crate::{
    types::entitlement_note::EntitlementNote,
    contract_interfaces::{check_dkim_key_hash_private, shield_to_claimant},
    verifiers::{verifier_ids, verify_linode},
    ZImburseEscrow::Storage
};

/**
 * Shared logic for claiming Linode entitlement
 * 
 * @param email_receipt_inputs - the inputs from the email verifier, in a contract-serializable format
 * @param claim_secret_hash - the hash of the claim secret used to redeem the reimbursement
 * @param spot - if true, check for spot entitlements. If false, check for recurring entitlements
 * @param context - the contract context
 * @param storage - the contract storage
 * @return - (Entitlement note used to claim reimbursement, admin, amount reimbursed, timestamp)
 */
#[contract_library_method]
fn linode(
    email_receipt_inputs: LinodeBillingParamsContract,
    claim_secret_hash: Field,
    spot: bool,
    context: &mut PrivateContext,
    storage: Storage<&mut PrivateContext>
) -> (EntitlementNote, AztecAddress, Field, Field){
    let sender = context.msg_sender();

    // retrieve a Linode hosting entitlement
    let note_wrapped = storage.entitlements.get_matching_entitlement(
        sender,
        sender,
        verifier_ids::LINODE,
        spot
    );
    assert(note_wrapped.is_some(), "No entitlements to redeem");

    // check the msg sender can use the entitlement
    let entitlement = note_wrapped.unwrap();
    assert(entitlement.recipient == sender, "Entitlement does not belong to the caller");

    // verify linode billing receipt and extract amount, date, keyhash
    let linode_outputs = verify_linode(email_receipt_inputs.marshal());
        
    // read the escrow definition
    let definition = storage.definition.read_private();

    // check the dkim key hash matches the linode verifier id
    let registered_verifier_id = check_dkim_key_hash_private(
        context,
        definition.registry,
        linode_outputs.dkim_key_hash
    );
    assert((registered_verifier_id as u8) == verifier_ids::LINODE, "DKIM key is not registered for Linode");

    // determine the amount to reimburse
    let amount_to_reimburse = entitlement.amount_to_reimburse(linode_outputs.billed_amount);

    // release funds from escrow by shielding in public
    shield_to_claimant(context, definition.usdc, amount_to_reimburse, claim_secret_hash);
        
    // return the amount reimbursed
    (entitlement, definition.admin, amount_to_reimburse, linode_outputs.timestamp)
}


// #[contract_library_method]
// fn deferred_united(
//     email_receipt_inputs: UnitedBillingParamsContract,
// )

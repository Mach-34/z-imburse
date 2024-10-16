use dep::aztec::{
    hash::compute_secret_hash,
    oracle::{random::random, execution::{get_block_number, get_contract_address}},
    note::constants::MAX_NOTES_PER_PAGE, prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment}
};
use std::collections::bounded_vec::BoundedVec;
use dep::z_imburse_escrow::{ZImburseEscrow, types::recurring_entitlement_note::RecurringEntitlementNote};
use dep::zimburse_verifiers::linode::constants::LinodeBillingParams;
use crate::test::utils::token_helpers::add_shielded_note;

/**
 * Send an entitlement for a monthly recurring reimbursement to a user in the escrow
 *
 * @param env The test environment
 * @param escrow_address The address of the deployed escrow contract
 * @param escrow_admin The address of the escrow admin sending the entitlement
 * @param recipient The address of the recipient of the entitlement
 * @param amount The amount of the entitlement
 * @param verifier The verifier to use for the entitlement
 */
unconstrained pub fn give_recurring_entitlement(
    env: &mut TestEnvironment,
    escrow_address: AztecAddress,
    escrow_admin: AztecAddress,
    recipient: AztecAddress,
    amount: Field,
    verifier: u8
) {
    env.impersonate(escrow_admin);
    let escrow = ZImburseEscrow::at(escrow_address);
    let give_recurring_entitlement_call_iface = escrow.give_recurring_entitlement(recipient, amount, verifier);
    env.call_private_void(give_recurring_entitlement_call_iface);
    cheatcodes::advance_blocks_by(1);
}

/**
 * Claim a linode recurring entitlement from the escrow
 *
 * @param env The test environment
 * @param escrow_address The address of the deployed escrow contract
 * @param usdc_address The address of the USDC token contract
 * @param claimant The address of the claimant
 * @param linode_inputs The inputs for the linode claim
 * @return
 *         - the claim secret used to claim the entitlement
 *         - the amount reimbursed
 */
unconstrained pub fn reimburse_linode(
    env: &mut TestEnvironment,
    escrow_address: AztecAddress,
    usdc_address: AztecAddress,
    claimant: AztecAddress,
    linode_inputs: LinodeBillingParams
) -> (Field, Field) {
    env.impersonate(claimant);
    // get claim hash
    let secret = unsafe {
        random()
    };
    let claim_hash = compute_secret_hash(secret);
    let escrow = ZImburseEscrow::at(escrow_address);

    // claim linode entitlement
    let reimburse_linode_call_iface = escrow.reimburse_linode(
        linode_inputs.body,
        linode_inputs.body_hash_index,
        linode_inputs.body_length,
        linode_inputs.header,
        linode_inputs.header_length,
        linode_inputs.pubkey,
        linode_inputs.pubkey_redc,
        linode_inputs.signature,
        linode_inputs.from_index,
        linode_inputs.subject_index,
        linode_inputs.amount_index,
        linode_inputs.amount_length,
        linode_inputs.date_index,
        linode_inputs.receipt_id_length,
        claim_hash
    );
    let amount_reimbursed = env.call_private(reimburse_linode_call_iface);
    cheatcodes::advance_blocks_by(1);

    // add shielded note to the txe
    add_shielded_note(env, usdc_address, amount_reimbursed, claim_hash);

    (secret, amount_reimbursed)
}

unconstrained pub fn get_recurring_entitlements_by_user(
    escrow_address: AztecAddress,
    at: AztecAddress,
    user: AztecAddress,
    offset: u32
) -> (BoundedVec<RecurringEntitlementNote, MAX_NOTES_PER_PAGE>, bool) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(escrow_address);
    let (notes, results_end) = ZImburseEscrow::get_recurring_entitlements_by_user(at, user, offset);
    cheatcodes::set_contract_address(current_contract_address);
    (notes, results_end)
}

unconstrained pub fn get_recurring_entitlements_by_verifier(
    escrow_address: AztecAddress,
    at: AztecAddress,
    verifier: u8,
    offset: u32
) -> (BoundedVec<RecurringEntitlementNote, MAX_NOTES_PER_PAGE>, bool) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(escrow_address);
    let (notes, results_end) = ZImburseEscrow::get_recurring_entitlements_by_verifier(at, verifier, offset);
    cheatcodes::set_contract_address(current_contract_address);
    (notes, results_end)
}

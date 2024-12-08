use aztec::{
    hash::compute_secret_hash,
    oracle::{random::random, execution::{get_block_number, get_contract_address}},
    note::constants::MAX_NOTES_PER_PAGE, prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment}
};
use std::{option::Option, collections::bounded_vec::BoundedVec};
use z_imburse_escrow::{ZImburseEscrow, types::entitlement_note::EntitlementNote};
use zimburse_verifiers::linode::constants::{LinodeBillingParams, LinodeBillingParamsContract};
use crate::test::utils::token_helpers::add_shielded_note;
use date_parser::{parse_date_string, to_unix_month, DATETIME_LENGTH};

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
    let _ = escrow.give_recurring_entitlement(recipient, amount, verifier).call(&mut env.private());
    cheatcodes::advance_blocks_by(1);
}

/**
 * Send an entitlement for a single "spot" reimbursement to a user in the escrow
 *
 * @param env The test environment
 * @param escrow_address The address of the deployed escrow contract
 * @param escrow_admin The address of the escrow admin sending the entitlement
 * @param recipient The address of the recipient of the entitlement
 * @param amount The amount of the entitlement
 * @param verifier The verifier to use for the entitlement
 * @param date_start The start date of when a receipt is valid
 * @param date_end The end date of when a receipt is valid
 * @param destination The destination of the reimbursement (set to [0; 31] if not used)
 */
unconstrained pub fn give_spot_entitlement(
    env: &mut TestEnvironment,
    escrow_address: AztecAddress,
    escrow_admin: AztecAddress,
    recipient: AztecAddress,
    amount: Field,
    verifier: u8,
    date_start: u32,
    date_end: u32,
    destination: str<31>
) {
    env.impersonate(escrow_admin);
    let escrow = ZImburseEscrow::at(escrow_address);
    let _ = escrow.give_spot_entitlement(recipient, amount, verifier, date_start, date_end, destination).call(&mut env.private());
    cheatcodes::advance_blocks_by(1);
}

/**
 * Revoke a recurring entitlement from a user in the escrow
 *
 * @param env The test environment
 * @param escrow_address The address of the deployed escrow contract
 * @param escrow_admin The address of the escrow admin revoking the entitlement
 * @param recipient The address of the recipient of the entitlement
 * @param verifier The verifier to use for the entitlement
 */
unconstrained pub fn revoke_entitlement(
    env: &mut TestEnvironment,
    escrow_address: AztecAddress,
    escrow_admin: AztecAddress,
    recipient: AztecAddress,
    verifier: u8,
    spot: bool
) {
    env.impersonate(escrow_admin);
    let escrow = ZImburseEscrow::at(escrow_address);
    let _ = escrow.revoke_entitlement(recipient, verifier, spot).call(&mut env.private());
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
 * @param spot If true, try to use a spot entitlement. If false, try to use a recurring entitlement
 * @return
 *         - the claim secret used to claim the entitlement
 *         - the amount reimbursed
 */
unconstrained pub fn reimburse_linode(
    env: &mut TestEnvironment,
    escrow_address: AztecAddress,
    usdc_address: AztecAddress,
    claimant: AztecAddress,
    linode_inputs: LinodeBillingParams,
    spot: bool
) -> (Field, Field) {
    env.impersonate(claimant);
    // get claim hash
    let secret = unsafe { random() };
    let claim_hash = compute_secret_hash(secret);
    let escrow = ZImburseEscrow::at(escrow_address);

    // claim linode entitlement
    let marshalled_inputs = LinodeBillingParamsContract::unmarshal(linode_inputs);
    let mut amount_reimbursed = 0;
    if spot {
        amount_reimbursed = escrow.reimburse_linode_spot(marshalled_inputs, claim_hash).call(&mut env.private());
    } else {
        amount_reimbursed = escrow.reimburse_linode_recurring(marshalled_inputs, claim_hash).call(&mut env.private());
    }
    cheatcodes::advance_blocks_by(1);

    // add shielded note to the txe
    add_shielded_note(env, usdc_address, amount_reimbursed, claim_hash);

    (secret, amount_reimbursed)
}

unconstrained pub fn view_entitlements(
    escrow_address: AztecAddress,
    offset: u32,
    scope: AztecAddress,
    recipient: Option<AztecAddress>,
    verifier: Option<u8>,
    spot: Option<bool>
) -> (BoundedVec<EntitlementNote, MAX_NOTES_PER_PAGE>, bool) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(escrow_address);
    let (notes, results_end) = ZImburseEscrow::view_entitlements(offset, scope, recipient, verifier, spot);
    cheatcodes::set_contract_address(current_contract_address);
    (notes, results_end)
}

unconstrained pub fn month_timestamp(date_string: str<DATETIME_LENGTH>) -> u32 {
    let date = parse_date_string(date_string.as_bytes());
    to_unix_month(date)
}

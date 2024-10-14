use dep::aztec::{
    test::helpers::cheatcodes,
    hash::compute_secret_hash
};
use dep::z_imburse_escrow::ZImburseEscrow;
use crate::{
    verifiers,
    test::utils::{
        setup_helpers::setup,
        token_helpers::{mint_public, to_usdc_decimals, redeem_shield, check_public_balance, check_private_balance},
        escrow_helpers::{give_recurring_entitlement, reimburse_linode},
        email_inputs::{LINODE_SEP, LINODE_OCT}
    }
};

#[test]
unconstrained fn give_linode_recurring_entitlement_success() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    mint_public(env, contracts.usdc, accounts.superuser, contracts.escrows[0], to_usdc_decimals(100000));
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        to_usdc_decimals(10),
        verifiers::LINODE
    );
}

#[test]
unconstrained fn claim_linode_reimbursement_success() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount = to_usdc_decimals(10);
    mint_public(env, contracts.usdc, accounts.superuser, contracts.escrows[0], amount);
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifiers::LINODE
    );
    // reimburse linode with the entitlement
    let claim_secret = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP
    );
    // check the balance of the escrow has decremented
    check_public_balance(contracts.usdc, contracts.escrows[0], 0);
    // claim the reimbursement
    redeem_shield(env, contracts.usdc, accounts.alice, amount, claim_secret);
    // check the balance of alice has incremented
    check_private_balance(contracts.usdc, accounts.alice, amount);
}

// unconstrained fn claim_linode_reimbursement_max_value_success() {
    
// }
use aztec::{test::helpers::cheatcodes, hash::compute_secret_hash, oracle::debug_log::{debug_log, debug_log_format}};
use z_imburse_escrow::ZImburseEscrow;
use crate::{
    test::utils::{
        setup_helpers::{setup, ZERO_DESTINATION},
        token_helpers::{mint_public, to_usdc_decimals, redeem_shield, check_public_balance, check_private_balance},
        escrow_helpers::{
            give_recurring_entitlement, give_spot_entitlement, reimburse_linode, view_entitlements,
            revoke_entitlement, month_timestamp
        },
        email_inputs::{LINODE_SEP, LINODE_OCT}
    }
};
use zimburse_verifiers::constants::verifier_ids;
use std::option::Option;

#[test]
unconstrained fn view_entitlements_perspectives() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        10000,
        verifier_ids::LINODE
    );
    // view entitlements as admin
    let (entitlements_admin, continue_admin) = view_entitlements(
        contracts.escrows[0],
        0,
        accounts.escrow_admin,
        Option::none(),
        Option::none(),
        Option::none()
    );
    assert(entitlements_admin.len() == 1);
    let admin_entitlement = entitlements_admin.get_unchecked(0);

    let (entitlements_alice, continue_admin) = view_entitlements(
        contracts.escrows[0],
        0,
        accounts.alice,
        Option::none(),
        Option::none(),
        Option::none()
    );
    assert(entitlements_alice.len() == 1);
    let alice_entitlement = entitlements_alice.get_unchecked(0);
    // check entitlements match
    assert(admin_entitlement.recipient == accounts.alice);
    assert(admin_entitlement.recipient == alice_entitlement.recipient);
    assert(admin_entitlement.verifier_id == verifier_ids::LINODE);
    assert(admin_entitlement.verifier_id == alice_entitlement.verifier_id);
    assert(admin_entitlement.max_value.to_integer() == 10000);
    assert(admin_entitlement.max_value == alice_entitlement.max_value);
    assert(admin_entitlement.spot == false);
    assert(admin_entitlement.spot == alice_entitlement.spot);
    assert(admin_entitlement.randomness == alice_entitlement.randomness);
}

#[test]
unconstrained fn claim_linode_recurring_success() {
    // CLAIM IS > ENTITLEMENT, CHECK GIVES MAX ENTITLEMENT
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount = to_usdc_decimals(10);
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount
    );
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifier_ids::LINODE
    );

    // reimburse linode with the entitlement
    let (claim_secret, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP,
        false
    );
    // check the balance of the escrow has decremented
    // check_public_balance(contracts.usdc, contracts.escrows[0], 0);
    // claim the reimbursement
    redeem_shield(env, contracts.usdc, accounts.alice, amount, claim_secret);
    // // check the balance of alice has incremented
    check_private_balance(contracts.usdc, accounts.alice, amount);
}

#[test]
unconstrained fn claim_linode_recurring_max_value_success() {
    // CLAIM IS <= ENTITLEMENT, CHECK GIVES CLAIM ($22)
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount_entitled = to_usdc_decimals(25);
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount_entitled
    );
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount_entitled,
        verifier_ids::LINODE
    );
    // reimburse linode with the entitlement
    // the actual reimbursement call would contain 
    let (claim_secret, amount_reimbursed) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP,
        false
    );
    // check the balance of the escrow has decremented
    check_public_balance(
        contracts.usdc,
        contracts.escrows[0],
        amount_entitled - amount_reimbursed
    );
    // claim the reimbursement
    redeem_shield(
        env,
        contracts.usdc,
        accounts.alice,
        amount_reimbursed,
        claim_secret
    );
    // check the balance of alice has incremented
    check_private_balance(contracts.usdc, accounts.alice, amount_reimbursed);
}

#[test]
unconstrained fn claim_linode_recurring_multiple_months_success() {
    // CLAIM IS > ENTITLEMENT, CHECK GIVES MAX ENTITLEMENT
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount = to_usdc_decimals(10);
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount * 2
    );
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifier_ids::LINODE
    );
    // reimburse linode for month 1 with the entitlement
    let (claim_secret_sep, amount_reimbursed_sep) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP,
        false
    );

    debug_log_format("\n\n\n\n\n\n\n\namount reimbursed sep: {0}", [amount_reimbursed_sep]);

    // check the balance of the escrow has decremented
    check_public_balance(
        contracts.usdc,
        contracts.escrows[0],
        amount * 2 - amount_reimbursed_sep
    );

    // reimburse linode for month 2 with the entitlement
    let (claim_secret_oct, amount_reimbursed_oct) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_OCT,
        false
    );
    // check the balance of the escrow has decremented
    check_public_balance(
        contracts.usdc,
        contracts.escrows[0],
        amount * 2 - amount_reimbursed_sep - amount_reimbursed_oct
    );
    // claim both reimbursements
    redeem_shield(
        env,
        contracts.usdc,
        accounts.alice,
        amount_reimbursed_sep,
        claim_secret_sep
    );
    redeem_shield(
        env,
        contracts.usdc,
        accounts.alice,
        amount_reimbursed_oct,
        claim_secret_oct
    );
    // check the balance of alice has incremented
    check_private_balance(
        contracts.usdc,
        accounts.alice,
        amount_reimbursed_sep + amount_reimbursed_oct
    );
}

#[test(should_fail_with = "Entitlement has already been claimed for this month")]
unconstrained fn claim_linode_recurring_nullified_month_fail() {
    // CLAIM IS > ENTITLEMENT, CHECK GIVES MAX ENTITLEMENT
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount = to_usdc_decimals(10);
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount * 2
    );
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifier_ids::LINODE
    );
    // reimburse linode with the entitlement
    let (_, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP,
        false
    );
    // try to claim the reimbursement again
    let (_, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP,
        false
    );
}

#[test(should_fail_with = "Entitlement is nullified")]
unconstrained fn claim_linode_recurring_nullified_fail() {
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount = to_usdc_decimals(10);
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount
    );
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifier_ids::LINODE
    );
    // revoke the entitlement
    revoke_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        verifier_ids::LINODE,
        false
    );
    // attempt to claim the reimbursement
    // note: revoke_entitlement emits an event notifying the user to remove the note from their pxe
    // the txe is incapable of handling this logic so it will try to use a note it thinks is valid
    let (_, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP,
        false
    );
}

#[test]
unconstrained fn claim_linode_spot_success() {
    // get start and end date
    let start_date = month_timestamp("1 Aug 2024 00:00:00 +0000 ");
    let end_date = month_timestamp("1 Oct 2024 00:00:00 +0000 ");
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount = to_usdc_decimals(10);
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount
    );
    // give entitlement to reimburse linode receipt to alice
    give_spot_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifier_ids::LINODE,
        start_date,
        end_date,
        ZERO_DESTINATION
    );
    // claim the reimbursement
    let (claim_secret, amount_reimbursed) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP,
        true
    );
    // check the balance of the escrow has decremented
    check_public_balance(
        contracts.usdc,
        contracts.escrows[0],
        amount - amount_reimbursed
    );
    // claim the reimbursement
    redeem_shield(
        env,
        contracts.usdc,
        accounts.alice,
        amount_reimbursed,
        claim_secret
    );
    // check the balance of alice has incremented
    check_private_balance(contracts.usdc, accounts.alice, amount_reimbursed);
}

#[test]
unconstrained fn revoke_linode_spot() {
    // get start and end date
    let start_date = month_timestamp("1 Aug 2024 00:00:00 +0000 ");
    let end_date = month_timestamp("1 Oct 2024 00:00:00 +0000 ");
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount = to_usdc_decimals(10);
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount
    );
    // give entitlement to reimburse linode receipt to alice
    give_spot_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifier_ids::LINODE,
        start_date,
        end_date,
        ZERO_DESTINATION
    );
    // revoke the entitlement
    revoke_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        verifier_ids::LINODE,
        true
    );

    let (entitlements) = view_entitlements(contracts.escrows[0], 0, accounts.escrow_admin, Option::none(), Option::none(), Option::none());
    assert(entitlements.len() == 0);
}

#[test(should_fail_with = "No entitlements to redeem")]
unconstrained fn claim_linode_spot_double_spend_fail() {
    // get start and end date
    let start_date = month_timestamp("1 Aug 2024 00:00:00 +0000 ");
    let end_date = month_timestamp("1 Oct 2024 00:00:00 +0000 ");
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount = to_usdc_decimals(10);
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount
    );
    // give entitlement to reimburse linode receipt to alice
    give_spot_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifier_ids::LINODE,
        start_date,
        end_date,
        ZERO_DESTINATION
    );
    // claim the reimbursement
    let (_, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP,
        true
    );
    debug_log_format("\n\n\nCLAIMED ONE", []);
    // try to claim the reimbursement again
    let (_, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP,
        true
    );
    debug_log_format("\n\n\nCLAIMED TWO", []);
}

#[test(should_fail_with = "Entitlement is nullified")]
unconstrained fn claim_linode_spot_revoked_fail() {
    // get start and end date
    let start_date = month_timestamp("1 Aug 2024 00:00:00 +0000 ");
    let end_date = month_timestamp("1 Oct 2024 00:00:00 +0000 ");
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount = to_usdc_decimals(10);
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount
    );
    // give entitlement to reimburse linode receipt to alice
    give_spot_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifier_ids::LINODE,
        start_date,
        end_date,
        ZERO_DESTINATION
    );
    // revoke the entitlement
    revoke_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        verifier_ids::LINODE,
        true
    );
    // attempt to claim the reimbursement
    let (_, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP,
        true
    );
}

#[test(should_fail_with = "Receipt is out of entitlement date range")]
unconstrained fn claim_linode_spot_outside_date_range_fail() {
    // get start and end date
    let start_date = month_timestamp("1 Aug 2024 00:00:00 +0000 ");
    let end_date = month_timestamp("1 Sep 2024 00:00:00 +0000 ");
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    let amount = to_usdc_decimals(10);
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount
    );
    // give entitlement to reimburse linode receipt to alice
    give_spot_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifier_ids::LINODE,
        start_date,
        end_date,
        ZERO_DESTINATION
    );
    // attempt to claim the reimbursement
    let (_, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_OCT,
        true
    );
}

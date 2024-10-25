use dep::aztec::{test::helpers::cheatcodes, hash::compute_secret_hash, oracle::debug_log::{debug_log, debug_log_format}};
use dep::z_imburse_escrow::ZImburseEscrow;
use crate::{
    verifiers,
    test::utils::{
    setup_helpers::setup,
    token_helpers::{mint_public, to_usdc_decimals, redeem_shield, check_public_balance, check_private_balance},
    escrow_helpers::{
    give_recurring_entitlement, reimburse_linode, get_recurring_entitlements_by_user,
    get_recurring_entitlements_by_verifier
},
    email_inputs::{LINODE_SEP, LINODE_OCT}
}
};

// #[test]
unconstrained fn give_linode_recurring_entitlement_success() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // mint tokens to the escrow
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        to_usdc_decimals(100000)
    );
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        to_usdc_decimals(10),
        verifiers::LINODE
    );
    // check the entitlements exist
    let (entitlements_by_user_admin, _) = get_recurring_entitlements_by_user(contracts.escrows[0], accounts.escrow_admin, accounts.alice, 0);
    let (entitlements_by_user_alice, _) = get_recurring_entitlements_by_user(contracts.escrows[0], accounts.alice, accounts.alice, 0);
    let (entitlements_by_verifier_admin, _) = get_recurring_entitlements_by_verifier(
        contracts.escrows[0],
        accounts.escrow_admin,
        verifiers::LINODE,
        0
    );
    let (entitlements_by_verifier_alice, _) = get_recurring_entitlements_by_verifier(contracts.escrows[0], accounts.alice, verifiers::LINODE, 0);
    debug_log_format(
        "Entitlement length: {0}",
        [entitlements_by_user_admin.len() as Field]
    );
    debug_log_format(
        "Entitlement length: {0}",
        [entitlements_by_user_alice.len() as Field]
    );
    debug_log_format(
        "Entitlement length: {0}",
        [entitlements_by_verifier_admin.len() as Field]
    );
    debug_log_format(
        "Entitlement length: {0}",
        [entitlements_by_verifier_alice.len() as Field]
    );
    debug_log_format(
        "Verifier id: {0}",
        [entitlements_by_user_admin.get(0).verifier_id as Field]
    );
    debug_log_format("Verifier id: {0}", [verifiers::LINODE as Field]);
    // assert(
    //     entitlements_by_user_admin.get(0).eq(entitlements_by_user_alice.get(0))
    //         & entitlements_by_user_admin.get(0).eq(entitlements_by_verifier_admin.get(0))
    //         & entitlements_by_user_admin.get(0).eq(entitlements_by_verifier_alice.get(0)),
    //         "Entitlements do not match"
    // );
    // assert(entitlements_by_user_admin.get(0).is_admin == true, "Admin is not set for admin entitlement receipt");
    // assert(entitlements_by_user_alice.get(0).is_admin == false, "Admin is set for alice entitlement");
    // assert(entitlements_by_user_admin.get(0).max_value.to_integer() == to_usdc_decimals(10), "Entitlement amount is incorrect");
    // assert(entitlements_by_user_admin.get(0).verifier_id == verifiers::LINODE, "Verifier is incorrect");
    // assert(entitlements_by_user_admin.get(0).admin == accounts.escrow_admin, "Entitlement admin address is incorrect");
    // assert(entitlements_by_user_admin.get(0).recipient == accounts.alice, "Entitlement user address is incorrect");
}

// #[test]
unconstrained fn claim_linode_reimbursement_success() {
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
        verifiers::LINODE
    );
    // reimburse linode with the entitlement
    let (claim_secret, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP
    );
    // // check the balance of the escrow has decremented
    // check_public_balance(contracts.usdc, contracts.escrows[0], 0);
    // // claim the reimbursement
    redeem_shield(env, contracts.usdc, accounts.alice, amount, claim_secret);
    // // check the balance of alice has incremented
    check_private_balance(contracts.usdc, accounts.alice, amount);
}

// #[test]
unconstrained fn claim_linode_reimbursement_max_value_success() {
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
        verifiers::LINODE
    );
    // reimburse linode with the entitlement
    // the actual reimbursement call would contain 
    let (claim_secret, amount_reimbursed) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP
    );
    // check the balance of the escrow has decremented
    // check_public_balance(
    //     contracts.usdc,
    //     contracts.escrows[0],
    //     amount_entitled - amount_reimbursed
    // );
    // // claim the reimbursement
    // redeem_shield(
    //     env,
    //     contracts.usdc,
    //     accounts.alice,
    //     amount_reimbursed,
    //     claim_secret
    // );
    // debug_log("Checking amount reimbursed");
    // // check the balance of alice has incremented
    // check_private_balance(contracts.usdc, accounts.alice, amount_reimbursed);
}

// #[test]
unconstrained fn claim_linode_reimbursement_success_multiple_months() {
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
        verifiers::LINODE
    );
    // reimburse linode for month 1 with the entitlement
    let (claim_secret_sep, amount_reimbursed_sep) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP
    );
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
        LINODE_OCT
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
unconstrained fn claim_linode_reimbursement_fail_month_nullified() {
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
        verifiers::LINODE
    );
    // reimburse linode with the entitlement
    let (_, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP
    );
    // try to claim the reimbursement again
    let (_, _) = reimburse_linode(
        env,
        contracts.escrows[0],
        contracts.usdc,
        accounts.alice,
        LINODE_SEP
    );
}

unconstrained fn nullify_entitlement() {
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
        verifiers::LINODE
    );
}

// #[test]
unconstrained fn get_entitlements_by_user() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    let amount = to_usdc_decimals(10);
    // mint tokens to the escrow
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount,
    );
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifiers::LINODE
    );

    // check the entitlement receipt exists for admin
    let (entitlements_admin, _) = get_recurring_entitlements_by_user(contracts.escrows[0], accounts.escrow_admin, accounts.alice, 0);
    assert(entitlements_admin.len() == 1, "Entitlements length is incorrect");
    assert(entitlements_admin.get(0).is_admin == true, "Admin is not set for admin entitlement receipt");
    assert(entitlements_admin.get(0).max_value.to_integer() == amount, "Entitlement amount is incorrect");
    assert(entitlements_admin.get(0).verifier_id == verifiers::LINODE, "Verifier is incorrect");
    assert(entitlements_admin.get(0).admin == accounts.escrow_admin, "Entitlement admin address is incorrect");
    assert(entitlements_admin.get(0).recipient == accounts.alice, "Entitlement user address is incorrect");

    // check the entitlement exists for recipient
    let (entitlements_recipient, _) = get_recurring_entitlements_by_user(contracts.escrows[0], accounts.alice, accounts.alice, 0);
    assert(entitlements_recipient.len() == 1, "Entitlements length is incorrect");
    assert(entitlements_recipient.get(0).is_admin == false, "Admin is set for alice entitlement");
    assert(entitlements_recipient.get(0).max_value.to_integer() == amount, "Entitlement amount is incorrect");
    assert(entitlements_recipient.get(0).verifier_id == verifiers::LINODE, "Verifier is incorrect");
    assert(entitlements_recipient.get(0).admin == accounts.escrow_admin, "Entitlement admin address is incorrect");
    assert(entitlements_recipient.get(0).recipient == accounts.alice, "Entitlement user address is incorrect");
}

// #[test]
unconstrained fn get_entitlements_by_verifier_id() {
    // setup test env
    let (env    , accounts, contracts) = setup::<1>();
    let amount = to_usdc_decimals(10);
    // mint tokens to the escrow
    mint_public(
        env,
        contracts.usdc,
        accounts.superuser,
        contracts.escrows[0],
        amount,
    );
    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        contracts.escrows[0],
        accounts.escrow_admin,
        accounts.alice,
        amount,
        verifiers::LINODE
    );

    // check the entitlement receipt exists for admin
    let (entitlements_admin, _) = get_recurring_entitlements_by_verifier(contracts.escrows[0], accounts.escrow_admin, verifiers::LINODE, 0);
    assert(entitlements_admin.len() == 1, "Entitlements length is incorrect");
    assert(entitlements_admin.get(0).is_admin == true, "Admin is not set for admin entitlement receipt");
    assert(entitlements_admin.get(0).max_value.to_integer() == amount, "Entitlement amount is incorrect");
    assert(entitlements_admin.get(0).verifier_id == verifiers::LINODE, "Verifier is incorrect");
    assert(entitlements_admin.get(0).admin == accounts.escrow_admin, "Entitlement admin address is incorrect");
    assert(entitlements_admin.get(0).recipient == accounts.alice, "Entitlement user address is incorrect");

    // check the entitlement exists for recipient
    let (entitlements_recipient, _) = get_recurring_entitlements_by_verifier(contracts.escrows[0], accounts.alice, verifiers::LINODE, 0);
    assert(entitlements_recipient.len() == 1, "Entitlements length is incorrect");
    assert(entitlements_recipient.get(0).is_admin == false, "Admin is set for alice entitlement");
    assert(entitlements_recipient.get(0).max_value.to_integer() == amount, "Entitlement amount is incorrect");
    assert(entitlements_recipient.get(0).verifier_id == verifiers::LINODE, "Verifier is incorrect");
    assert(entitlements_recipient.get(0).admin == accounts.escrow_admin, "Entitlement admin address is incorrect");
    assert(entitlements_recipient.get(0).recipient == accounts.alice, "Entitlement user address is incorrect");

    // check entitlement nullifiers
    let nullifier_1 = entitlements_admin.get(0).derive_nullifier_secret();
    let nullifier_2 = entitlements_recipient.get(0).derive_nullifier_secret();
    debug_log_format("Nullifier 1: {0}; Nullifier 2: {1}", [nullifier_1, nullifier_2]);
}

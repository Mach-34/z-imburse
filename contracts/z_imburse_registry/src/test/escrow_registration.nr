use dep::aztec::test::helpers::cheatcodes;
use crate::test::utils::{setup_helpers::{setup, deploy_escrow_contract}, registry_helpers};
use crate::ZImburseRegistry;

#[test]
unconstrained fn register_escrow_success() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // regis: &mut TestEnvironmentter the escrow contract
    registry_helpers::register_escrow(
        env,
        contracts.registry,
        contracts.escrows[0],
        accounts.escrow_admin
    );
}

#[test(should_fail_with="Escrow contract has already been registered")]
unconstrained fn fail_register_escrow_already_registered() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // register the escrow contract
    registry_helpers::register_escrow(
        env,
        contracts.registry,
        contracts.escrows[0],
        accounts.escrow_admin
    );
    // try to register the same contract again
    registry_helpers::register_escrow(
        env,
        contracts.registry,
        contracts.escrows[0],
        accounts.escrow_admin
    );
}

#[test(should_fail_with="Escrow contract admin does not match sender of message")]
unconstrained fn fail_register_not_escrow_admin() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // register the escrow contract
    registry_helpers::register_escrow(
        env,
        contracts.registry,
        contracts.escrows[0],
        accounts.alice
    );
}

#[test(should_fail_with="Escrow contract class ID does not match expected class ID")]
unconstrained fn fail_register_contract_not_escrow() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // register the escrow contract
    registry_helpers::register_escrow(
        env,
        contracts.registry,
        contracts.usdc,
        accounts.escrow_admin
    );
}

#[test(should_fail_with="Escrow contract registry does not match this contract")]
unconstrained fn fail_register_escrow_wrong_registry() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // deploy a new escrow with the wrong registry set
    let bad_escrow = deploy_escrow_contract(env, accounts.escrow_admin, contracts.usdc, contracts.usdc);
    // register the escrow contract
    registry_helpers::register_escrow(
        env,
        contracts.registry,
        bad_escrow,
        accounts.escrow_admin
    );
}

#[test(should_fail_with="Escrow contract USDC does not match registry USDC")]
unconstrained fn fail_register_escrow_wrong_usdc() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // deploy a new escrow with the wrong usdc token set
    let bad_escrow = deploy_escrow_contract(env, accounts.escrow_admin, contracts.registry, contracts.registry);
    // register the escrow contract
    registry_helpers::register_escrow(
        env,
        contracts.registry,
        bad_escrow,
        accounts.escrow_admin
    );
}
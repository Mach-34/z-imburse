use dep::aztec::test::helpers::cheatcodes;
use crate::test::utils::{setup_helpers::setup, escrow_registry_helpers};
use crate::ZImburseEscrowRegistry;

#[test]
unconstrained fn register_contract_success() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // regis: &mut TestEnvironmentter the escrow contract
    escrow_registry_helpers::register_escrow(
        env,
        contracts.escrowRegistry,
        contracts.escrowContracts[0],
        accounts.escrowAdmin
    );
}

#[test(should_fail_with="Escrow contract has already been registered")]
unconstrained fn fail_register_contract_already_registered() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // register the escrow contract
    escrow_registry_helpers::register_escrow(
        env,
        contracts.escrowRegistry,
        contracts.escrowContracts[0],
        accounts.escrowAdmin
    );
    // try to register the same contract again
    escrow_registry_helpers::register_escrow(
        env,
        contracts.escrowRegistry,
        contracts.escrowContracts[0],
        accounts.escrowAdmin
    );
}

#[test(should_fail_with="Escrow contract admin does not match sender of message")]
unconstrained fn fail_register_contract_not_admin() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // register the escrow contract
    escrow_registry_helpers::register_escrow(
        env,
        contracts.escrowRegistry,
        contracts.escrowContracts[0],
        accounts.alice
    );
}

#[test(should_fail_with="Escrow contract class ID does not match expected class ID")]
unconstrained fn fail_register_contract_not_escrow() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // register the escrow contract
    escrow_registry_helpers::register_escrow(
        env,
        contracts.escrowRegistry,
        contracts.usdc,
        accounts.alice
    );
}
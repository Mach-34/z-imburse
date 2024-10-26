use dep::aztec::{prelude::AztecAddress, test::helpers::cheatcodes, oracle::debug_log::debug_log_format};
use crate::test::utils::{setup_helpers::{setup, deploy_escrow_contract, ESCROW_NAMES, USERNAMES}, registry_helpers};
use crate::ZImburseRegistry;
use dep::std::collections::bounded_vec::BoundedVec;

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
    registry_helpers::register_escrow(env, contracts.registry, contracts.escrows[0], accounts.alice);
}

#[test(should_fail_with="Escrow contract class ID does not match expected class ID")]
unconstrained fn fail_register_contract_not_escrow() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // register the escrow contract
    registry_helpers::register_escrow(env, contracts.registry, contracts.usdc, accounts.escrow_admin);
}

#[test(should_fail_with="Escrow contract registry does not match this contract")]
unconstrained fn fail_register_escrow_wrong_registry() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // deploy a new escrow with the wrong registry set
    let bad_escrow = deploy_escrow_contract(
        env,
        accounts.escrow_admin,
        contracts.usdc,
        contracts.usdc,
        ESCROW_NAMES[1]
    );
    // register the escrow contract
    registry_helpers::register_escrow(env, contracts.registry, bad_escrow, accounts.escrow_admin);
}

#[test(should_fail_with="Escrow contract USDC does not match registry USDC")]
unconstrained fn fail_register_escrow_wrong_usdc() {
    // setup test env
    let (env, accounts, contracts) = setup::<1>();
    // deploy a new escrow with the wrong usdc token set
    let bad_escrow = deploy_escrow_contract(
        env,
        accounts.escrow_admin,
        contracts.registry,
        contracts.registry,
        ESCROW_NAMES[1]
    );
    // register the escrow contract
    registry_helpers::register_escrow(env, contracts.registry, bad_escrow, accounts.escrow_admin);
}

// unconstrained fn add_dkim_keys() {

// }

// unconstrained fn add_dkim_keys_bulk() {

// }

// unconstrained fn fail_add_dkim_keys_not_admin() {

// }

// unconstrained fn fail_add_dkim_keys_bulk_not_admin() {

// }

// unconstrained fn fail_add_dkim_keys_already_added() {

// }

// unconstrained fn fail_add_dkim_keys_bulk_already_added() {

// }

#[test]
unconstrained fn view_managed_escrows() {
    // setup test env
    let (env, accounts, contracts) = setup::<13>();
    // register the escrow contracts
    for i in 0..13 {
        registry_helpers::register_escrow(
            env,
            contracts.registry,
            contracts.escrows[i],
            accounts.escrow_admin
        );
    }
    // get escrows
    let mut escrows: BoundedVec<AztecAddress, 13> = BoundedVec::new();
    for i in 0..2 {
        let offset: u32 = i * 10;
        let (escrows_page, _) = registry_helpers::get_managed_escrows(contracts.registry, accounts.escrow_admin, offset);
        for j in 0..escrows_page.len() {
            escrows.push(escrows_page.get(i));
        }
    }
    // check the escrows are correct
    for i in 0..13 {
        let returned_escrow = escrows.get_unchecked(i);
        assert(
            contracts.escrows.any(|escrow| escrow == returned_escrow), "Escrow not found in managed escrows"
        );
    }
    assert(escrows.len() == 13, "Incorrect number of escrows returned");
}

unconstrained fn view_participants() {
    // setup test env
    let (env, accounts, contracts) = setup::<2>();
    // register the escrow contract
    registry_helpers::register_escrow(
        env,
        contracts.registry,
        contracts.escrows[0],
        accounts.escrow_admin
    );
    // register escrows
    for i in 0..2 {
        registry_helpers::register_escrow(
            env,
            contracts.registry,
            contracts.escrows[i],
            accounts.escrow_admin
        );
    }
    // check and register the participant
    let mut accounts_participants = [AztecAddress::zero(); 12];
    for i in 0..12 {
        accounts_participants[i] = env.create_account();
        let registered = registry_helpers::check_and_register_participant(
            env,
            contracts.registry,
            contracts.escrows[0],
            accounts.escrow_admin,
            accounts_participants[i],
            USERNAMES[i]
        );
        assert(registered, "Participant not registered");
    }
    for i in 0..7 {
        let registered = registry_helpers::check_and_register_participant(
            env,
            contracts.registry,
            contracts.escrows[2],
            accounts.escrow_admin,
            accounts_participants[i],
            USERNAMES[i]
        );
        assert(registered, "Participant not registered");
    }
    // // view participants in escrows as admin
    // let mut participants_1: BoundedVec<AztecAddress, 12> = BoundedVec::new();
    // for i in 0..2 {
    //     let offset: u32 = i * 10;
    //     let (participants_page, _) = registry_helpers::get_participants(contracts.registry, accounts.escrow_admin, contracts.escrows[0], offset);
    //     for j in 0..participants_page.len() {
    //         participants_1.push(participants_page.get(i));
    //     }
    // }
        
}

// unconstrained fn 

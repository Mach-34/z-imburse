use aztec::{
    prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment}
};
use crate::ZImburseTestNoteContract;

struct TestAccounts {
    superuser: AztecAddress,
    escrow_admin: AztecAddress,
    alice: AztecAddress,
    bob: AztecAddress
}

unconstrained pub fn deploy_test_contract(
    env: &mut TestEnvironment,
    deployer: AztecAddress,
) -> AztecAddress {
    env.impersonate(deployer);
    let escrow_init_call_iface = ZImburseTestNoteContract::interface().constructor();
    let escrow_contract = env
        .deploy("./@z_imburse_note_contract", "ZImburseTestNoteContract")
        .with_public_void_initializer(escrow_init_call_iface);
    cheatcodes::advance_blocks_by(1);
    escrow_contract.to_address()
}


unconstrained pub fn setup<let N: u32>() -> (&mut TestEnvironment, TestAccounts, AztecAddress) {
    let mut env = TestEnvironment::new();

    // create 4 accounts
    let accounts = TestAccounts {
        superuser: env.create_account(),
        escrow_admin: env.create_account(),
        alice: env.create_account(),
        bob: env.create_account()
    };
    
    let escrow: AztecAddress = deploy_test_contract(&mut env, accounts.escrow_admin);

    // return setup params
    (
        &mut env,
        accounts,
        escrow
    )
}
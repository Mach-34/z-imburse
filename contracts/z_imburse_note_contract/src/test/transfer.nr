use aztec::{
    prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment}
};
use crate::{
    test::utils::setup,
    ZImburseTestNoteContract
};

unconstrained pub fn give_recurring_entitlement(
    env: &mut TestEnvironment,
    escrow_address: AztecAddress,
    escrow_admin: AztecAddress,
    recipient: AztecAddress,
    amount: Field,
    verifier: u8
) {
    env.impersonate(escrow_admin);
    let escrow = ZImburseTestNoteContract::at(escrow_address);
    let _ = escrow.give_recurring_entitlement(recipient, amount, verifier).call(&mut env.private());
    cheatcodes::advance_blocks_by(1);
}

#[test]
unconstrained fn test_note_transfer() {

    let (env, accounts, escrow) = setup::<1>();

    // give entitlement to reimburse linode receipt to alice
    give_recurring_entitlement(
        env,
        escrow,
        accounts.escrow_admin,
        accounts.alice,
        10000,
        2
    );
}
use dep::aztec::test::helpers::cheatcodes;
use dep::aztec::hash::compute_secret_hash;
use crate::test::utils;
use crate::ZImburseEscrowRegistry;

#[test]
unconstrained fn register_contract_success() {
    // setup test env
    let (env, accounts, contracts) = utils::setup::<1>();
    // register the escrow contract
    env.impersonate(accounts[1]);
    let register_escrow_call_iface = ZImburseEscrowRegistry::interface().register_escrow(
        contracts[3]
    );
    env.call_private_void(register_escrow_call_iface);
    cheatcodes::advance_blocks_by(1);
}
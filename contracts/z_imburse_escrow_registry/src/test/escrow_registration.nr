use dep::aztec::test::helpers::cheatcodes;
use dep::aztec::hash::compute_secret_hash;
use crate::test::utils;
use crate::ZImburseEscrowRegistry;

#[test]
unconstrained fn register_contract_success() {
    // setup test env
    let (env, accounts, contracts) = utils::setup::<1>();
    dep::aztec::oracle::debug_log::debug_log_format("Token: {0}", [contracts[0].to_field()]);
    dep::aztec::oracle::debug_log::debug_log_format("DKIM Registry: {0}", [contracts[1].to_field()]);
    dep::aztec::oracle::debug_log::debug_log_format("Escrow Registry: {0}", [contracts[2].to_field()]);
    dep::aztec::oracle::debug_log::debug_log_format("Escrow: {0}", [contracts[3].to_field()]);
    // register the escrow contract
    let escrow_registry = ZImburseEscrowRegistry::at(contracts[2]);
    env.impersonate(accounts[1]);
    let register_escrow_call_iface = escrow_registry.register_escrow(
        contracts[3]
    );
    env.call_private_void(register_escrow_call_iface);
    cheatcodes::advance_blocks_by(1);
}
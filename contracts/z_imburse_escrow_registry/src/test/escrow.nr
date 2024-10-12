use dep::aztec::test::helpers::cheatcodes;
use dep::aztec::hash::compute_secret_hash;
use dep::z_imburse_dkim_oracle::receipt_verifier_id;
use crate::test::utils;
use crate::ZImburseEscrowRegistry;

#[test]
unconstrained fn give_entitlement_success() {
    // setup test env
    let (env, accounts, contracts) = utils::setup::<1>();
    let escrow = ZImburseEscrowRegistry::at(contracts[3]);
    utils::mint_public(env, contracts[0], accounts[0], contracts[3], utils::to_usdc_decimals(100000));
    // register the escrow contract
    env.impersonate(accounts[1]);
    let register_escrow_call_iface = escrow.give_recurring_entitlement(
        accounts[2],
        utils::to_usdc_decimals(10),
        receipt_verifier_id::LINODE as Field
    )
    env.call_private_void(register_escrow_call_iface);
    cheatcodes::advance_blocks_by(1);
}
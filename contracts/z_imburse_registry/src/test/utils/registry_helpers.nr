use dep::aztec::prelude::AztecAddress;
use dep::aztec::test::helpers::{cheatcodes, test_environment::TestEnvironment};
use crate::ZImburseRegistry;

/**
 * Register an escrow contract with the escrow registry
 *
 * @param env The test environment
 * @param escrow_registry_address The address of the deployed escrow registry contract
 * @param escrow_contract_address The address of the deployed escrow contract
 * @param escrow_admin The address of the escrow admin registering the escrow
 */
unconstrained pub fn register_escrow(
    env: &mut TestEnvironment,
    escrow_registry_address: AztecAddress,
    escrow_contract_address: AztecAddress,
    escrow_admin: AztecAddress
) {
    let escrow_registry = ZImburseRegistry::at(escrow_registry_address);
    env.impersonate(escrow_admin);
    let register_escrow_call_iface = escrow_registry.register_escrow(
        escrow_contract_address
    );
    env.call_private_void(register_escrow_call_iface);
    cheatcodes::advance_blocks_by(1);
}
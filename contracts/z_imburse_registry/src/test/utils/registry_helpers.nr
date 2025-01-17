use dep::aztec::{
    note::constants::MAX_NOTES_PER_PAGE,
    oracle::{random::random, execution::{get_block_number, get_contract_address}},
    prelude::AztecAddress,
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
};
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


unconstrained pub fn check_and_register_participant(
    env: &mut TestEnvironment,
    registry_address: AztecAddress,
    escrow_address: AztecAddress,
    escrow_admin: AztecAddress,
    participant: AztecAddress,
    username: str<60>
) -> bool {
    let escrow_registry = ZImburseRegistry::at(registry_address);
    env.impersonate(escrow_admin);
    let check_and_register_participant_iface = escrow_registry.check_and_register_participant(
        participant,
        username,
        escrow_address
    );
    let added_participant = env.call_private(check_and_register_participant_iface);
    cheatcodes::advance_blocks_by(1);
    added_participant
}

unconstrained pub fn get_managed_escrows(
    registry_address: AztecAddress,
    admin: AztecAddress,
    offset: u32
) -> (BoundedVec<AztecAddress, MAX_NOTES_PER_PAGE>, bool) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(registry_address);
    let (escrows, results_end) = ZImburseRegistry::get_managed_escrows(offset);
    cheatcodes::set_contract_address(current_contract_address);
    (escrows, results_end)
}

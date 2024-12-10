use dep::aztec::{
    prelude::AztecAddress,
    oracle::{execution::{get_block_number, get_contract_address}, storage::storage_read},
    test::helpers::{cheatcodes, test_environment::TestEnvironment},
    protocol_types::storage::map::derive_storage_slot_in_map
};
use dep::token::Token;
use crate::test::utils::setup_helpers::USDC_DECIMALS;

/**
 * Publicly mint tokens to a recipient (basically to the escrow contract)
 *
 * @param env - The test environment
 * @param token_address - The address of the token contract
 * @param escrow_address - The address of the escrow contract
 * @param amount - The amount of tokens to mint
 */
unconstrained pub fn mint_public(
    env: &mut TestEnvironment,
    token_address: AztecAddress,
    minter: AztecAddress,
    recipient: AztecAddress,
    amount: Field
) {
    env.impersonate(minter);
    let _ = Token::at(token_address).mint_to_public(recipient, amount).call(&mut env.public());
    cheatcodes::advance_blocks_by(1);
}

// is this just kinda unnecessary at this level
unconstrained pub fn to_usdc_decimals(amount: Field) -> Field {
    amount * 10.pow_32(USDC_DECIMALS as Field)
}

// https://github.com/AztecProtocol/aztec-packages/blob/72a2cd9cf66abfc4075a5ae06d73de2259928254/noir-projects/noir-contracts/contracts/token_contract/src/test/utils.nr#L74
unconstrained pub fn check_public_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: Field
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    let block_number = get_block_number();

    let balances_slot = Token::storage_layout().public_balances.slot;
    let address_slot = derive_storage_slot_in_map(balances_slot, address);
    let amount: U128 = storage_read(token_contract_address, address_slot, block_number);
    aztec::oracle::debug_log::debug_log_format("\n\n\nAddress amount: {0}\nAmount: {1}", [
        address_amount,
        amount.to_field()
    ]);
    assert(amount.to_field() == address_amount, "Public balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}

// https://github.com/AztecProtocol/aztec-packages/blob/72a2cd9cf66abfc4075a5ae06d73de2259928254/noir-projects/noir-contracts/contracts/token_contract/src/test/utils.nr#L92
unconstrained pub fn check_private_balance(
    token_contract_address: AztecAddress,
    address: AztecAddress,
    address_amount: Field
) {
    let current_contract_address = get_contract_address();
    cheatcodes::set_contract_address(token_contract_address);
    // Direct call to unconstrained
    let balance_of_private = Token::balance_of_private(address);
    assert(balance_of_private == address_amount, "Private balance is not correct");
    cheatcodes::set_contract_address(current_contract_address);
}

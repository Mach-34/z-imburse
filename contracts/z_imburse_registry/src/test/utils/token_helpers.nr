use dep::aztec::prelude::AztecAddress;
use dep::aztec::test::helpers::{cheatcodes, test_environment::TestEnvironment};
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
    let mint_call_iface = Token::at(token_address).mint_public(recipient, amount);
    env.call_public(mint_call_iface);
    cheatcodes::advance_blocks_by(1);
}

// is this just kinda unnecessary at this level
unconstrained pub fn to_usdc_decimals(amount: Field) -> Field {
    amount * 10.pow_32(USDC_DECIMALS as Field)
}
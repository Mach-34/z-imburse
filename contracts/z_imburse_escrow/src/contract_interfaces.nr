use aztec::{
    prelude::{AztecAddress, PrivateContext},
    protocol_types::abis::function_selector::FunctionSelector
};
use token::Token;

/**
 * Push a private view to the registry contract to return the verifier id set for a given DKIM key hash
 *
 * @param context The private context
 * @param registry_address The address of the Z-Imburse registry contract
 * @param dkim_key_hash The hash of the DKIM key to check
 * @return The verifier id set for the DKIM key hash
 */
pub fn check_dkim_key_hash_private(
    context: &mut PrivateContext,
    registry_address: AztecAddress,
    dkim_key_hash: Field
) -> u8 {
    let function_selector = comptime {
        FunctionSelector::from_signature("check_dkim_key_hash_private(Field)")
    };
    context.static_call_private_function(registry_address, function_selector, [dkim_key_hash]).unpack::<1>()[0] as u8
}

/**
 * Enqueue a public call to shield tokens so the claimant can claim them
 * 
 * @param context - the private execution context
 * @param token_address - the address of the usdc token to shield
 * @param amount - the amount of tokens to shield
 * @param claim_secret_hash - the hash of the claim secret used to privately redeem the tokens
 */
pub fn shield_to_claimant(
    context: &mut PrivateContext,
    token_address: AztecAddress,
    amount: Field,
    claim_secret_hash: Field
) { 
    Token::at(token_address).shield(
        context.this_address(),
        amount,
        claim_secret_hash,
        0
    ).enqueue(context);
}

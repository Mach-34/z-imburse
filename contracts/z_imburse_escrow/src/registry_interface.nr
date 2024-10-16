use dep::aztec::prelude::{AztecAddress, PrivateContext};
use dep::aztec::protocol_types::abis::function_selector::FunctionSelector;

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

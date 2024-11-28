use aztec::prelude::{AztecAddress, PrivateContext};
use zimburse_verifiers::{
    constants::verifier_ids,
    united::constants::UnitedBillingParamsContract,
    zkemail::KEY_LIMBS_2048
};
use crate::{
    types::entitlement_note::EntitlementNote,
    contract_interfaces::{check_dkim_key_hash_private, shield_to_claimant},
    verifiers::verify_united_deferred,
    ZImburseEscrow::Storage, ZImburseEscrow
};
use std::hash::pedersen_hash;

// /**
//  * Handles verification of united email receipt with hashing split into recursive calls
//  *
//  * @param email_inputs - the inputs from the email verifier, in a contract-serializable format
//  * @param amount_to_date_length - the length of the body between the amount and date selection
//  * @param remaining_length - the length of the body after all selections have been made
//  * @param actual_length - the actual length of the entire email body
//  * @param context - the contract context
//  * @return - []
//  */
// #[contract_library_method]
// fn united_deferred(
//     // general email inputs
//     email_inputs: UnitedBillingParamsContract,
//     // body lengths
//     amount_to_date_length: u32,
//     remaining_length: u32,
//     actual_length: u32,
//     context: &mut PrivateContext,
// ) -> [Field; 3] {
//     // verify the email with deferred hashing
//     let deferred_results = verify_united_deferred(email_inputs.marshal());
//     ZImburseEscrow::at(context.this_address())
//         .finish_hashing(
//             deferred_results.hash_state_after_body,
//             email_inputs.partial_body_hash_date,
//             deferred_results.hash_state_after_destination,
//             deferred_results.signed_body_hash,
//             actual_length,
//             amount_to_date_length,
//             remaining_length
//         )
//         .call(context);
//     // return extracted values
//     [ 
//         deferred_results.billed_amount,
//         deferred_results.timestamp,
//         deferred_results.destination_airport
//     ]
// }

/**
 * Claim a spot reimbursement for a United Airlines receipt
 * 
 * @param email_inputs - the inputs from the email verifier in a contract-serializable format
 * @param amount_to_date_length - the length of the body between the amount and date selection
 * @param remaining_length - the length of the body after all selections have been made
 * @param actual_length - the actual length of the entire email body
 * @param claim_secret_hash - the hash of the claim secret used to redeem the reimbursement
 * @param storage - the contract storage
 * @param context - the private execution context from the function circuit being called
 */
// #[contract_library_method]
// fn reimburse_united(
//     email_inputs: UnitedBillingParamsContract,
//     amount_to_date_length: u32,
//     remaining_length: u32,
//     actual_length: u32,
//     claim_secret_hash: Field,
//     storage: Storage<&mut PrivateContext>,
//     context: &mut PrivateContext,
// ) -> Field {
    // // kick verification to a separate function
    // let extracted = ZImburseEscrow::at(context.this_address())
    //     .united_deferred_verification(
    //         email_inputs,
    //         amount_to_date_length,
    //         remaining_length,
    //         actual_length
    //     )
    //     .call(context);
    // // multiply the amount by 10000 to get the actual amount
    // let billed_amount = U128::from_integer(extracted[0] * 10000);
    // let timestamp = extracted[1];
    // let destination_airport = extracted[2];
    // // get united entitlement note
    // let sender = context.msg_sender();
    // let note_wrapped = storage.entitlements.get_matching_entitlement(
    //     sender,
    //     sender,
    //     verifier_ids::UNITED_AIRLINES,
    //     true
    // );
    // assert(note_wrapped.is_some(), "No entitlements to redeem");

    // // check the msg sender can use the entitlement
    // let entitlement = note_wrapped.unwrap();
    // assert(entitlement.recipient == sender, "Entitlement does not belong to the caller");

    // // read the escrow definition
    // let definition = storage.definition.read_private();

    // // check the dkim key hash matches the linode verifier id
    // let dkim_key_hash = pedersen_hash(email_inputs.pubkey_modulus);
    // let registered_verifier_id = check_dkim_key_hash_private(
    //     context,
    //     definition.registry,
    //     dkim_key_hash
    // );
    // assert((registered_verifier_id as u8) == verifier_ids::UNITED_AIRLINES, "DKIM key is not registered for United Airlines");

    // // check date range
    // entitlement.check_date_range(timestamp as u32);

    // // check destination airport
    // // @todo

    // // determine the amount to reimburse
    // let amount_to_reimburse = entitlement.amount_to_reimburse(billed_amount);

    // // release funds from escrow by shielding in public
    // shield_to_claimant(context, definition.usdc, amount_to_reimburse, claim_secret_hash);

    // // emit email nullifier
    // let email_nullifier = pedersen_hash(email_inputs.signature);
    // context.push_nullifier(email_nullifier);

    // // check note nullifier for revocation/ consuption
    // let nullifier = entitlement.check_nullifier(context);

    // // broadcast the note nullifier
    // context.push_nullifier(nullifier);

    // // emit event to notify admin of spot entitlement consumption
    // entitlement.emit_nullified(context, entitlement.recipient, sender);
    
    // // notify admin of reimbursement
    // entitlement.emit_spot_claim(
    //     context,
    //     definition.admin,
    //     amount_to_reimburse,
    // );

    // // return the amount reimbursed
    // amount_to_reimburse
// }
use std::meta::derive;
use aztec::protocol_types::traits::Serialize;
use zimburse_verifiers::{
    linode::{
        constants::LinodeBillingParams,
        main::verify_linode_billing_receipt
    },
    united::{
        constants::UnitedBillingParams,
        main::verify_united_deferred_hash
    },
    zkemail::KEY_LIMBS_2048
};

pub struct LinodeReceiptOutput {
    dkim_key_hash: Field,
    timestamp: Field,
    billed_amount: U128,
}

pub struct UnitedReceiptOutput {
    timestamp: Field,
    billed_amount: Field,
    destination_airport: Field,
    signed_body_hash: [u8; 32],
    hash_state_after_body: [u32; 8],
    hash_state_after_destination: [u32; 8],
}

pub mod verifier_ids {
    pub global AWS: u8 = 1;
    pub global LINODE: u8 = 2;
    pub global HEROKU: u8 = 3;
    pub global FRONTIER_AIRLINES: u8 = 4;
    pub global UNITED_AIRLINES: u8 = 5;
    pub global AMERICAN_AIRLINES: u8 = 6;
    pub global DELTA_AIRLINES: u8 = 7;
    pub global UBER: u8 = 8;
    pub global LYFT: u8 = 9;
}

/** Constrain the verification of a Linode billing receipt email and return formatted outputs */
pub fn verify_linode(inputs: LinodeBillingParams) -> LinodeReceiptOutput {
    // verify the email receipt
    let linode_receipt_result = verify_linode_billing_receipt(
        inputs.header,
        inputs.pubkey,
        inputs.signature,
        inputs.dkim_header_sequence,
        inputs.body,
        inputs.body_hash_index,
        inputs.from_index,
        inputs.subject_index,
        inputs.amount_sequence,
        inputs.date_index,
        inputs.receipt_id_length
    );
    // extract outputs
    let dkim_key_hash = linode_receipt_result[0];
    let timestamp = linode_receipt_result[1];
    let billed_amount = U128::from_integer(linode_receipt_result[2] * 10000);
    LinodeReceiptOutput { dkim_key_hash, timestamp, billed_amount }
}

/** Constrain the verification of a United billing receipt email and return formatted outputs with deferred hashing */
pub fn verify_united_deferred(inputs: UnitedBillingParams) -> UnitedReceiptOutput {
    // verify the email receipt
    let (
        hash_state_after_body,
        hash_state_after_destination,
        signed_body_hash,
        extracted_values
    ) = verify_united_deferred_hash(
        inputs.header,
        inputs.pubkey,
        inputs.signature,
        inputs.dkim_header_sequence,
        inputs.body_hash_index,
        inputs.from_index,
        inputs.subject_index,
        inputs.amount_sequence,
        inputs.date_sequence,
        inputs.airport_sequence,
        inputs.partial_body_hash,
        inputs.body_amount_selection,
        inputs.partial_body_hash_date,
        inputs.body_date_selection
    );

    // extract outputs
    UnitedReceiptOutput {
        billed_amount: extracted_values[0],
        timestamp: extracted_values[1],
        destination_airport: extracted_values[2],
        signed_body_hash,
        hash_state_after_body,
        hash_state_after_destination
    }
}
use dep::aztec::protocol_types::{address::AztecAddress, traits::{Serialize, Deserialize}};
use dep::compressed_string::CompressedString;
use dep::aztec::macros::notes::note;

global DESTINATION_LENGTH: u32 = 90;
global DESTINATION_SERIALIZED_LENGTH: u32 = 3;

// unique ids for each note type
mod ENTITLEMENT_NOTE_TYPE {
    global SPOT: u8 = 1;
    global RECURRING: u8 = 2;
}

// unique ids for each verifier type
mod VERIFIER_TYPE {
    global LINODE: u8 = 1; // supported
    global HEROKU: u8 = 2; // todo: supported
    global AWS: u8 = 3; // todo: supported
    global GCP: u8 = 4; // not supported in mvp
    global AZURE: u8 = 5; // not supported in mvp
    global HETZNER: u8 = 6; // not supported in mvp
    global DIGITAL_OCEAN: u8 = 7; // not supported in mvp
    global UBER: u8 = 8; // todo: supported
    global LYFT: u8 = 9; // todo: supported
    global FRONTIER: u8 = 10; // todo: supported
    global AMERICAN_AIRLINES: u8 = 11; // todo: supported
    global UNITED: u8 = 12; // todo: supported
    // ...
}

#[note]
pub struct EntitlementNote {
    // the user that is allowed to use this entitlement
    owner: AztecAddress,
    // the maximum value that can be withdrawn from the escrow using this entitlement
    max_value: U128,
    // the start date of when this entitlement can be claimed
    start_date: U128,
    // the end date of when this entitlement can be claimed
    end_date: U128,
    // the type of email verifier that should be used for this entitlement
    verifier_type: u8,
    // the destination (airport, address, etc) that the claimant can show travel to
    destination: CompressedString<DESTINATION_SERIALIZED_LENGTH, DESTINATION_LENGTH>,
    // random entropy to make the note private
    entropy: Field,
}
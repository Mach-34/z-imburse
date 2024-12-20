use aztec::macros::aztec;

mod library_methods;
mod test;
mod types;


#[aztec]
contract ZImburseTestNoteContract {

    use aztec::{
        macros::{
            functions::{initializer, private, public},
            storage::storage
        },
        prelude::AztecAddress,
    };
    use crate::{
        library_methods::entitlements::give_entitlement,
        types::{
            entitlement_note::EntitlementNote,
            entitlement_set::EntitlementSet
        }
    };

    global ZERO_DESTINATION: str<31> = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
    
    #[storage]
    struct Storage<Context> {
        entitlements: EntitlementSet<EntitlementNote, Context>,
    }

    #[public]
    #[initializer]
    fn constructor() {}

    #[private]
    pub fn give_recurring_entitlement(recipient: AztecAddress, amount: Field, verifier_id: u8) {
        give_entitlement(
            recipient,
            amount,
            verifier_id,
            0,
            0,
            ZERO_DESTINATION,
            false, // spot
            storage,
            &mut context
        );
    }
}
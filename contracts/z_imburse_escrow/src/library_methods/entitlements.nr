use aztec::{prelude::{AztecAddress, PrivateContext}, oracle::random::random};
use zimburse_verifiers::{
    linode::constants::LinodeBillingParamsContract,
    united::constants::UnitedBillingParamsContract,
    zkemail::KEY_LIMBS_2048
};
use crate::{
    types::entitlement_note::EntitlementNote,
    ZImburseEscrow::Storage
};

#[contract_library_method]
fn give_entitlement(
    recipient: AztecAddress,
    amount: Field,
    verifier_id: u8,
    date_start: u32,
    date_end: u32,
    destination: str<31>,
    spot: bool,
    storage: Storage<&mut PrivateContext>,
    context: &mut PrivateContext
) {
    // check that no receipt exists for this recipient and verifier
    let entitlement_exists = storage.entitlements.get_matching_entitlement(
        context.msg_sender(),
        recipient,
        verifier_id,
        spot
    ).is_some();
    assert(!entitlement_exists, "An entitlement already exists for this recipient and verifier");

    // check is escrow admin
    let sender = context.msg_sender();
    let admin = storage.definition.read_private().admin;
    assert(sender == admin, "Only the escrow admin can give entitlements");

    // create the entitlement note
    let amount = U128::from_integer(amount);
    let blinding_factor = unsafe { random() };
    let mut entitlement_admin = EntitlementNote::new(
        recipient,
        verifier_id,
        amount,
        date_start,
        date_end,
        destination,
        spot,
        blinding_factor
    );
    let mut entitlement_recipient = EntitlementNote::new(
        recipient,
        verifier_id,
        amount,
        date_start,
        1,
        destination,
        spot,
        blinding_factor
    );

    // insert the entitlement note for the recipient and the admin
    storage.entitlements.add_entitlement_with_receipt(
        context,
        sender,
        recipient,
        &mut entitlement_admin,
        &mut entitlement_recipient
    );
}
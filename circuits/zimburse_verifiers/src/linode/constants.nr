use dep::zkemail::{KEY_LIMBS_2048};

global MAX_LINODE_EMAIL_BODY_LENGTH: u32 = 832;
global MAX_LINODE_EMAIL_HEADER_LENGTH: u32 = 640;

// expected sequence for the sender in an email body for Linode billing receipt
// "F/f" is omitted to facilitate case insensitivity
// "rom:billing@linode.com"
global LB_FROM_LEN = 22;
global LINODE_BILLING_FROM: str<LB_FROM_LEN> = "rom:billing@linode.com";

// expected sequence in the subject of an email header for Linode billing receipt
// "S/s" is omitted to facilitate case insensitivity
// "ubject: Linode.com: Payment Receipt"
global LB_SUBJECT_FIXED_START_LEN = 36;
global LB_SUBJECT_FIXED_END_LEN = 3;
global LINODE_BILLING_SUBJECT_FIXED_START: str<LB_SUBJECT_FIXED_START_LEN> = "ubject:Linode.com: Payment Receipt ["; 
global LINODE_BILLING_SUBJECT_FIXED_END: str<LB_SUBJECT_FIXED_END_LEN> = "]\r\n";

// expected sequence preceding the billed amount in a Linode billing receipt email
// NOTE: Hardcoded to accept 'credit card' as only payment method for now although there may be variation
global LB_PAYMENT_TEXT_LEN = 76;
global LINODE_BILLING_PAYMENT_TEXT: str<LB_PAYMENT_TEXT_LEN> = "This is your receipt of payment against your credit card in the \r\namount of ";

// assuming a unlikely max billed amount of "$9,999,999.99"
global MAX_BILLED_AMOUNT = 13;

struct LinodeBillingParams {
    body: [u8; MAX_LINODE_EMAIL_BODY_LENGTH],
    body_hash_index: u32,
    body_length: u32,
    header: [u8; MAX_LINODE_EMAIL_HEADER_LENGTH],
    header_length: u32,
    pubkey: [Field; KEY_LIMBS_2048],
    pubkey_redc: [Field; KEY_LIMBS_2048],
    signature: [Field; KEY_LIMBS_2048],
    from_index: u32,
    subject_index: u32,
    amount_index: u32,
    amount_length: u32,
    date_index: u32,
    receipt_id_length: u32
}
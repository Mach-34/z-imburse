use dep::zkemail::{KEY_LIMBS_2048};


// ##### Max Email Lengths #####
// Linode
global MAX_LINODE_EMAIL_BODY_LENGTH: u32 = 832;
global MAX_LINODE_EMAIL_HEADER_LENGTH: u32 = 640;

// United 
global MAX_UNITED_EMAIL_BODY_LENGTH: u32 = 58560;
global MAX_UNITED_EMAIL_HEADER_LENGTH: u32 = 640;




// expected sequence for the sender in an email body for Linode billing receipt
// "F/f" is omitted to facilitate case insensitivity
// "rom:billing@linode.com"
global LB_FROM_LEN = 22;
global LINODE_BILLING_FROM: str<LB_FROM_LEN> = "rom:billing@linode.com";

// expected sequence for the sender in an email body for United flight receipt
// "F/f" is omitted to facilitate case insensitivity
// "rom:billing@linode.com"
global UR_FROM_LEN = 41;
global UNITED_RECEIPTS_FROM: str<UR_FROM_LEN> = "rom:United Airlines <Receipts@united.com>";

// expected start of "Date" field in an email header
global DATE_HEADER_FIELD_START: [u8; 4] = "ate:".as_bytes();
// max length of a "Date" field in an email header
global DATE_HEADER_FIELD_MAX_LENGTH: u32 = 42;
// if index 11 = " " then length is 41, else 42
global DATE_LENGTH_DETERMINATION_INDEX = 11;

// expected sequence in the subject of an email header for Linode billing receipt
// "S/s" is omitted to facilitate case insensitivity
// "ubject: Linode.com: Payment Receipt"
global LB_SUBJECT_FIXED_START_LEN = 36;
global LB_SUBJECT_FIXED_END_LEN = 3;
global LINODE_BILLING_SUBJECT_FIXED_START: str<LB_SUBJECT_FIXED_START_LEN> = "ubject:Linode.com: Payment Receipt ["; 
global LINODE_BILLING_SUBJECT_FIXED_END: str<LB_SUBJECT_FIXED_END_LEN> = "]\r\n";

// expected sequence in the subject of an email header for United eTicket receipt
// "S/s" is omitted to facilitate case insensitivity
// "ubject: eTicket Itinerary and Receipt for Confirmation"
global UR_SUBJECT_LEN = 53;
global UNITED_FLIGHT_RECEIPT_SUBJECT: str<UR_SUBJECT_LEN> = "ubject:eTicket Itinerary and Receipt for Confirmation"; 

// expected sequence preceding the billed amount in a Linode billing receipt email
// NOTE: Hardcoded to accept 'credit card' as only payment method for now although there may be variation
global LB_PAYMENT_TEXT_LEN = 76;
global LINODE_BILLING_PAYMENT_TEXT: str<LB_PAYMENT_TEXT_LEN> = "This is your receipt of payment against your credit card in the \r\namount of ";

global UNITED_PURCHASE_SUMMARY_INDICE_LEN = 5;

// assuming a unlikely max billed amount of "$9,999,999.99"
global MAX_BILLED_AMOUNT = 13;

// assuming a unlikely max billed amount of "9999999.99"
global MAX_BILLED_AMOUNT_UNITED = 10;

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
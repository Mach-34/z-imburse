// assuming a unlikely max billed amount of "9999999.99"
global MAX_BILLED_AMOUNT = 10;

global MAX_EMAIL_BODY_LENGTH: u32 = 58560;
global MAX_EMAIL_HEADER_LENGTH: u32 = 640;

global PURCHASE_SUMMARY_INDICE_LEN = 5;

// expected sequence for the sender in an email body for United flight receipt
// "F/f" is omitted to facilitate case insensitivity
// "rom:billing@linode.com"
global UR_FROM_LEN = 41;
global UNITED_FLIGHT_RECEIPT_FROM: str<UR_FROM_LEN> = "rom:United Airlines <Receipts@united.com>";

// expected sequence in the subject of an email header for United eTicket receipt
// "S/s" is omitted to facilitate case insensitivity
// "ubject: eTicket Itinerary and Receipt for Confirmation"
global UR_SUBJECT_LEN = 53;
global UNITED_FLIGHT_RECEIPT_SUBJECT: str<UR_SUBJECT_LEN> = "ubject:eTicket Itinerary and Receipt for Confirmation"; 
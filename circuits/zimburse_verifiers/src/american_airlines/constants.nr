// assuming a unlikely max billed amount of "9,999,999.99"
global MAX_BILLED_AMOUNT: u32 = 12;

global MAX_AA_EMAIL_BODY_LENGTH = 81856;
global MAX_AA_EMAIL_HEADER_LENGTH = 1024;

global TOTAL_COST_INDICE_LENGTH = 5;

// expected sequence for the sender in an email body for American Airlines flight confirmation
// "F/f" is omitted to facilitate case insensitivity
// "rom:American Airlines <no-reply@info.email.aa.com>"
global AA_FROM_LEN = 50;
global AA_FLIGHT_RECEIPT_FROM: str<AA_FROM_LEN> = "rom:American Airlines <no-reply@info.email.aa.com>";


// expected sequence in the subject of an email header for American Airlines flight confirmation
// "S/s" is omitted to facilitate case insensitivity
// "ubject: Your trip confirmation"
global AA_SUBJECT_START_LEN = 31;
global AA_SUBJECT_END_LEN = 3;
global AA_FLIGHT_CONFIRMATION_SUBJECT_START: str<AA_SUBJECT_START_LEN> = "ubject:Your trip confirmation (";
global AA_FLIGHT_CONFIRMATION_SUBJECT_END: str<AA_SUBJECT_END_LEN> = ")\r\n";
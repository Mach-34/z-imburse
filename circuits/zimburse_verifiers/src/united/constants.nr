// assuming a unlikely max billed amount of "9999999.99"
global MAX_BILLED_AMOUNT = 10;

// estimate maximum text length of destination airport
global MAX_DEST_AIRPORT_LENGTH = 25;

global DATE_LENGTH = 17;

global MAX_EMAIL_BODY_LENGTH: u32 = 25792;
global MAX_EMAIL_HEADER_LENGTH: u32 = 640;

global PURCHASE_SUMMARY_INDICE_LEN = 5;

// expected sequence for the sender in an email body for United flight receipt
// "from:billing@linode.com"
global UNITED_FLIGHT_RECEIPT_FROM: [u8; 42] = comptime { "from:United Airlines <Receipts@united.com>".as_bytes() };

// expected sequence in the subject of an email header for United eTicket receipt
// "subject: eTicket Itinerary and Receipt for Confirmation"
global UNITED_FLIGHT_RECEIPT_SUBJECT: [u8; 54] = comptime { "subject:eTicket Itinerary and Receipt for Confirmation".as_bytes() };

global TOTAL_BILLED_PREFIX_LENGTH = 184;
global TOTAL_BILLED_POSTFIX_LENGTH = 9;
global TOTAL_BILLED_HTML_PREFIX: [u8; TOTAL_BILLED_PREFIX_LENGTH] = comptime { "Total:</td><td style=3D\"padding-right:10px; padding-top:12px; padding-bottom:10px; text-align: right; font-weight: 600; font-size: 20px; font-family: &#39;Open Sans&#39;, sans-serif;\">".as_bytes() };
global TOTAL_BILLED_HTML_POSTFIX: [u8; TOTAL_BILLED_POSTFIX_LENGTH] = comptime { " USD</td>".as_bytes() };

global ARRIVAL_DATE_PREFIX_LENGTH = 195;
global ARRIVAL_DATE_POSTFIX_LENGTH = 5;
global ARRIVAL_DATE_HTML_PREFIX: [u8; ARRIVAL_DATE_PREFIX_LENGTH] = comptime { "2nd bag weight and dimensions</td></tr><tr><td style=3D\"font-family: &#39;Open Sans&#39;, sans-serif; text-align: left; font-size: 12px; padding-bottom:5px; padding-top: 5px; padding-left:10px;\">".as_bytes() };
global ARRIVAL_DATE_HTML_POSTFIX: [u8; ARRIVAL_DATE_POSTFIX_LENGTH] = comptime { "<br/>".as_bytes() };

global DEST_AIRPORT_PREFIX_LENGTH = 5;
global DEST_AIPORT_POSTFIX_LENGTH = 5;
global DEST_AIRPORT_HTML_PREFIX: [u8; DEST_AIRPORT_PREFIX_LENGTH] = comptime { "<br/>".as_bytes() };
global DEST_AIRPORT_HTML_POSTFIX: [u8; DEST_AIPORT_POSTFIX_LENGTH] = comptime { "</td>".as_bytes() };

global MAX_AMOUNT_SEQUENCE_LENGTH = MAX_BILLED_AMOUNT + TOTAL_BILLED_POSTFIX_LENGTH + TOTAL_BILLED_PREFIX_LENGTH;
global MAX_DATETIME_SEQUENCE_LENGTH = DATE_LENGTH + ARRIVAL_DATE_PREFIX_LENGTH + ARRIVAL_DATE_POSTFIX_LENGTH;
global MAX_DEST_SEQUENCE_LENGTH = MAX_DEST_AIRPORT_LENGTH + DEST_AIPORT_POSTFIX_LENGTH + DEST_AIRPORT_PREFIX_LENGTH;

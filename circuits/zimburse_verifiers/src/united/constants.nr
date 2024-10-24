// assuming a unlikely max billed amount of "9999999.99"
global MAX_BILLED_AMOUNT = 10;

global MAX_EMAIL_BODY_LENGTH: u32 = 58560;
global MAX_EMAIL_HEADER_LENGTH: u32 = 640;

global PURCHASE_SUMMARY_INDICE_LEN = 5;

// expected sequence for the sender in an email body for United flight receipt
// "from:billing@linode.com"
global UNITED_FLIGHT_RECEIPT_FROM: [u8; 42] = comptime { "from:United Airlines <Receipts@united.com>".as_bytes() };

// expected sequence in the subject of an email header for United eTicket receipt
// "subject: eTicket Itinerary and Receipt for Confirmation"
global UNITED_FLIGHT_RECEIPT_SUBJECT: [u8; 54] = comptime { "subject:eTicket Itinerary and Receipt for Confirmation".as_bytes() }; 

global TOTAL_BILLED_HTML_PREFIX: [u8; 184] = comptime { "Total:</td><td style=3D\"padding-right:10px; padding-top:12px; padding-bottom:10px; text-align: right; font-weight: 600; font-size: 20px; font-family: &#39;Open Sans&#39;, sans-serif;\">".as_bytes() };
global TOTAL_BILLED_HTML_POSTFIX: [u8; 5] = comptime { "</td>".as_bytes() };
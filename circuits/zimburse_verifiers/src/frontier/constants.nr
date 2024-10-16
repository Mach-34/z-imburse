// assuming a unlikely max billed amount of "999=2C999=2E99"
global MAX_BILLED_AMOUNT = 14;

global MAX_FRONTIER_EMAIL_BODY_LENGTH = 186560;
global MAX_FRONTIER_EMAIL_HEADER_LENGTH = 1024;

global PURCHASE_TOTAL_INDICE_LEN = 4;

// expected sequence for the sender in an email body for Frontier flights email
// "F/f" is omitted to facilitate case insensitivity
// "rom:Frontier Airlines <flights@emails.flyfrontier.com>"
global FRONTIER_FROM_LEN = 78;
// "Frontier airlines" is MIME encoded
global FRONTIER_FLIGHTS_FROM: str<FRONTIER_FROM_LEN> = "rom:=?ISO-8859-1?B?RnJvbnRpZXIgQWlybGluZXM=?= <flights@emails.flyfrontier.com>";

// expected sequence in the subject of an email header for Frontier flight confirmation
// "S/s" is omitted to facilitate case insensitivity
// "ubject:Your Flight Confirmation Code"
global FRONTIER_SUBJECT_LEN = 36;
global FRONTIER_FLIGHT_CONFIRMATION_SUBJECT: str<FRONTIER_SUBJECT_LEN> = "ubject:Your Flight Confirmation Code"; 
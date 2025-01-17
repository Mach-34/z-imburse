// expected start of "Date" field in an email header
global DATE_HEADER_FIELD_START: [u8; 4] = "ate:".as_bytes();
// max length of a "Date" field in an email header
global DATE_HEADER_FIELD_MAX_LENGTH: u32 = 42;
// if index 11 = " " then length is 41, else 42
global DATE_LENGTH_DETERMINATION_INDEX = 11;
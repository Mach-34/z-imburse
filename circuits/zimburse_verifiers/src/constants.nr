// expected start of "Date" field in an email header
global DATE_HEADER_FIELD_START: [u8; 4] = "ate:".as_bytes();
// max length of a "Date" field in an email header
global DATE_HEADER_FIELD_MAX_LENGTH: u32 = 42;
// if index 11 = " " then length is 41, else 42
global DATE_LENGTH_DETERMINATION_INDEX: u32 = 11;
// USDC has 6 decimals but two decimal places are already handled via value extraction Logic for linode / United
global USDC_DECIMALS: Field = 10000;

// Verifier ids
pub mod verifier_ids {
    pub global AWS: u8 = 1;
    pub global LINODE: u8 = 2;
    pub global HEROKU: u8 = 3;
    pub global FRONTIER_AIRLINES: u8 = 4;
    pub global UNITED_AIRLINES: u8 = 5;
    pub global AMERICAN_AIRLINES: u8 = 6;
    pub global DELTA_AIRLINES: u8 = 7;
    pub global UBER: u8 = 8;
    pub global LYFT: u8 = 9;
}
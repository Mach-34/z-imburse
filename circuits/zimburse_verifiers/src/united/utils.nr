use crate::utils::{
    check_qp_sequence, check_qp_sequence_reverse, is_qp_linebreak_char, field_from_bytes,
    remove_soft_line_break
};
use super::constants::{
    ARRIVAL_DATE_POSTFIX_LENGTH, ARRIVAL_DATE_PREFIX_LENGTH, ARRIVAL_DATE_HTML_PREFIX,
    ARRIVAL_DATE_HTML_POSTFIX, DEST_AIPORT_POSTFIX_LENGTH, DEST_AIRPORT_PREFIX_LENGTH,
    DEST_AIRPORT_HTML_POSTFIX, DEST_AIRPORT_HTML_PREFIX, MAX_AMOUNT_SEQUENCE_LENGTH, MAX_BILLED_AMOUNT,
    MAX_DATETIME_SEQUENCE_LENGTH, MAX_DEST_SEQUENCE_LENGTH, MAX_DEST_AIRPORT_LENGTH,
    MAX_EMAIL_BODY_LENGTH, MAX_UNITED_EMAIL_HEADER_LENGTH, PURCHASE_SUMMARY_INDICE_LEN,
    UNITED_FLIGHT_RECEIPT_FROM, UNITED_FLIGHT_RECEIPT_SUBJECT, TOTAL_BILLED_HTML_PREFIX,
    TOTAL_BILLED_HTML_POSTFIX, TOTAL_BILLED_PREFIX_LENGTH, TOTAL_BILLED_POSTFIX_LENGTH
};
use zkemail::{Sequence, partial_hash::{partial_sha256_var_end, partial_sha256_var_interstitial}};
use date_parser::{Datetime, parse_day, parse_month, parse_year, to_unix};

/**
* Check that email is from United receipts address
*/
pub fn check_from_united_receipts(index: u32, header: BoundedVec<u8, MAX_UNITED_EMAIL_HEADER_LENGTH>) {
    let from_len = UNITED_FLIGHT_RECEIPT_FROM.len() as u32;
    // check that full field is within bounds
    assert(index + from_len <= header.len(), "From index out of bounds");
    // check for hardcoded sender
    for i in 0..from_len {
        assert(
            header.get_unchecked(i + index) == UNITED_FLIGHT_RECEIPT_FROM[i], "Email not from United receipts."
        );
    }
    // check for CRLF at end
    assert(header.get_unchecked(from_len + index) == 0x0D, "Invalid CRLF sequence");
    assert(header.get_unchecked(from_len + index + 1) == 0x0A, "Invalid CRLF sequence");
}

/**
* Check that email subject is United eTicket Itinerary and Receipt
*/
pub fn check_subject_united_flight_receipt(index: u32, header: BoundedVec<u8, MAX_UNITED_EMAIL_HEADER_LENGTH>) {
    let subject_len = UNITED_FLIGHT_RECEIPT_SUBJECT.len() as u32;
    // check that full field is within bounds
    assert(index + subject_len <= header.len() as u32, "Subject index out of bounds");

    // check chars in fixed section start
    for i in 0..subject_len {
        assert(
            header.get_unchecked(i + index) == UNITED_FLIGHT_RECEIPT_SUBJECT[i], "Email subject is not United eTicket receipt"
        );
    }

    // check for CRLF at start
    // TODO: Come back and check why this is here
    // assert(header.get_unchecked(subject_len - 2) == 0x0D, "Invalid CRLF sequence");
    // assert(header.get_unchecked(subject_len - 1) == 0x0A, "Invalid CRLF sequence");

    // United confirmation number always follows and has a length of 6
    // check for CRLF
    assert(header.get_unchecked(subject_len + index + 7) == 0x0D, "Invalid CRLF sequence");
    assert(header.get_unchecked(subject_len + index + 8) == 0x0A, "Invalid CRLF sequence");
}

pub fn extract_billed_amount<let N: u32>(body: BoundedVec<u8, N>, amount_sequence: Sequence) -> Field {
    // check the prefix of the amount sequence
    // todo: collapse into same QP check
    check_qp_sequence::<N, 43, TOTAL_BILLED_PREFIX_LENGTH>(
        body,
        amount_sequence.index,
        TOTAL_BILLED_HTML_PREFIX,
        "Index does not point to total billed prefix"
    );

    // check the postfix of the amount sequence
    check_qp_sequence_reverse::<N, 44, TOTAL_BILLED_POSTFIX_LENGTH>(
        body,
        amount_sequence.index + amount_sequence.length - 1,
        TOTAL_BILLED_HTML_POSTFIX,
        "Index does not point to total billed postfix"
    );
    let crlf_parsed = remove_soft_line_break::<N, MAX_AMOUNT_SEQUENCE_LENGTH>(body, amount_sequence);
    // locate decimal index
    let mut decimal_index = 0;
    for i in 0..(MAX_BILLED_AMOUNT + TOTAL_BILLED_POSTFIX_LENGTH) {
        let index = MAX_AMOUNT_SEQUENCE_LENGTH - i - 1;
        let character = crlf_parsed.get_unchecked(index);
        if character == 0x2E {
            decimal_index = index;
        }
    }
    // check that third to last place is decimal point
    assert(crlf_parsed.get_unchecked(decimal_index) == 0x2E, "Index does not point to decimal");
    let amount_length = decimal_index + 3 - TOTAL_BILLED_PREFIX_LENGTH;

    // parse the amount
    let mut amount: Field = 0;
    let mut pow = 1;
    for i in 0..MAX_BILLED_AMOUNT {
        let byte = crlf_parsed.get_unchecked(decimal_index + 2 - i);
        if (i < amount_length) & (byte != 0x2E) {
            let val = (byte - 0x30) as Field;
            amount = amount + val * pow;
            pow = pow * 10;
        }
    }
    amount
}

pub fn extract_departing_flight_date<let N: u32>(body: BoundedVec<u8, N>, date_sequence: Sequence) -> Field {
    // check the prefix of the date sequence
    check_qp_sequence::<N, 45, ARRIVAL_DATE_PREFIX_LENGTH>(
        body,
        date_sequence.index,
        ARRIVAL_DATE_HTML_PREFIX,
        "Index does not point to departing date prefix"
    );

    // check the postfix of the date sequence
    check_qp_sequence_reverse::<N, 46, ARRIVAL_DATE_POSTFIX_LENGTH>(
        body,
        date_sequence.index + date_sequence.length - 1,
        ARRIVAL_DATE_HTML_POSTFIX,
        "Index does not point to departing date postfix"
    );

    let crlf_parsed = remove_soft_line_break::<N, MAX_DATETIME_SEQUENCE_LENGTH>(body, date_sequence);

    // convert date to timestamp
    let date_index = ARRIVAL_DATE_PREFIX_LENGTH;

    // parse day
    let day = parse_day([crlf_parsed.get_unchecked(date_index + 9), crlf_parsed.get_unchecked(date_index + 10)]);

    let month = parse_month([
        crlf_parsed.get_unchecked(date_index + 5),
        crlf_parsed.get_unchecked(date_index + 6),
        crlf_parsed.get_unchecked(date_index + 7)
    ]);
    assert(month != 0);
    // parse year
    let year = parse_year([
        crlf_parsed.get_unchecked(date_index + 13),
        crlf_parsed.get_unchecked(date_index + 14),
        crlf_parsed.get_unchecked(date_index + 15),
        crlf_parsed.get_unchecked(date_index + 16)
    ]);
    // marshall into datetime
    let datetime = Datetime {
        year: year.0,
        leap_years: year.1,
        add_leap_day: false, // todo this needs to be determined...
        month,
        day,
        time: 0,
        offset: 0,
        subtract: false
    };
    to_unix(datetime) as Field
}

pub fn extract_destination_airport<let N: u32>(
    body: BoundedVec<u8, N>,
    airport_sequence: Sequence
) -> Field {
    // check the prefix of the destination airport sequence
    check_qp_sequence::<N, 50, DEST_AIRPORT_PREFIX_LENGTH>(
        body,
        airport_sequence.index,
        DEST_AIRPORT_HTML_PREFIX,
        "Index does not point to destination airport prefix"
    );

    // check the postfix of the date sequence
    check_qp_sequence_reverse::<N, 51, DEST_AIPORT_POSTFIX_LENGTH>(
        body,
        airport_sequence.index + airport_sequence.length - 1,
        DEST_AIRPORT_HTML_POSTFIX,
        "Index does not point to destination airport postfix"
    );

    // remove crlf characters
    let crlf_parsed = remove_soft_line_break::<N, MAX_DEST_SEQUENCE_LENGTH>(body, airport_sequence);

    let mut opening_parenthesis_index = 0;
    let mut pointer = DEST_AIRPORT_PREFIX_LENGTH;
    for i in 0..MAX_DEST_AIRPORT_LENGTH {
        if crlf_parsed.get_unchecked(pointer + i) == 0x28 {
            opening_parenthesis_index = pointer + i;
        }
    }

    // extract airport code
    let first_char = crlf_parsed.get_unchecked(opening_parenthesis_index + 1);
    let second_char = crlf_parsed.get_unchecked(opening_parenthesis_index + 2);
    let third_char = crlf_parsed.get_unchecked(opening_parenthesis_index + 3);
    let code = [third_char, second_char, first_char];
    field_from_bytes::<3>(code)
}

pub fn client_side_interstitial(
    body: BoundedVec<u8, MAX_EMAIL_BODY_LENGTH>,
    amount_sequence: Sequence,
    date_sequence: Sequence,
    partial_body_hash: [u32; 8],
    partial_body_hash_date: [u32; 8]
) -> ([u32; 8], [u32; 8]) {
    // hash content between total and date / dest
    let mut amount_msg: [u8; 256] = [0; 256];
    for i in 0..MAX_AMOUNT_SEQUENCE_LENGTH {
        amount_msg[i] = body.get_unchecked(amount_sequence.index + i);
    }
    let interstitial_hash_1 = partial_sha256_var_interstitial(partial_body_hash, amount_msg, 256);

    let date_dest_sequence_length = MAX_DATETIME_SEQUENCE_LENGTH + MAX_DEST_AIRPORT_LENGTH - 5;
    let mut date_dest_msg: [u8; 256] = [0; 256];
    for i in 0..date_dest_sequence_length {
        date_dest_msg[i] = body.get_unchecked(date_sequence.index + i);
    }
    let interstitial_hash_3 = partial_sha256_var_interstitial(partial_body_hash_date, date_dest_msg, 256);
    (interstitial_hash_1, interstitial_hash_3)
}

pub fn server_side_interstitial(
    body: BoundedVec<u8, MAX_EMAIL_BODY_LENGTH>,
    interstitial_hash_1: [u32; 8],
    interstitial_hash_3: [u32; 8],
    amount_sequence: Sequence,
    email_body_length: u32
) {
    let mut interstitial_msg_2: [u8; 1984] = [0; 1984]; // hardcode max length to 1984 for now
    let interstitial_2_start_index = amount_sequence.end_index() + 1;
    for i in 0..interstitial_msg_2.len() {
        interstitial_msg_2[i] = body.get_unchecked(interstitial_2_start_index + i);
    }
    let interstitial_hash_2  = partial_sha256_var_interstitial(
        interstitial_hash_1,
        interstitial_msg_2,
        interstitial_msg_2.len()
    );

    let mut body_end: [u8; 19968] = [0; 19968]; // hardcode max length to 19968 for now

    let computed_hash_server = partial_sha256_var_end(
        interstitial_hash_3,
        body_end,
        body_end.len() as u64,
        email_body_length as u64
    );
}

// #[test]
fn test_check_amount() {
    let data: [u8; 256] = [10, 38, 35, 51, 57, 59, 44, 32, 115, 97, 110, 115, 45, 115, 101, 114, 105, 102, 59, 34, 62, 84, 111, 116, 97, 108, 58, 60, 47, 116, 100, 62, 60, 116, 100, 32, 115, 116, 121, 108, 101, 61, 51, 68, 34, 112, 97, 100, 100, 105, 110, 103, 45, 114, 105, 103, 104, 116, 58, 49, 48, 112, 120, 59, 32, 112, 97, 100, 100, 105, 110, 103, 45, 116, 111, 112, 61, 13, 10, 58, 49, 50, 112, 120, 59, 32, 112, 97, 100, 100, 105, 110, 103, 45, 98, 111, 116, 116, 111, 109, 58, 49, 48, 112, 120, 59, 32, 116, 101, 120, 116, 45, 97, 108, 105, 103, 110, 58, 32, 114, 105, 103, 104, 116, 59, 32, 102, 111, 110, 116, 45, 119, 101, 105, 103, 104, 116, 58, 32, 54, 48, 48, 59, 32, 102, 111, 110, 116, 45, 115, 105, 122, 101, 58, 61, 13, 10, 32, 50, 48, 112, 120, 59, 32, 102, 111, 110, 116, 45, 102, 97, 109, 105, 108, 121, 58, 32, 38, 35, 51, 57, 59, 79, 112, 101, 110, 32, 83, 97, 110, 115, 38, 35, 51, 57, 59, 44, 32, 115, 97, 110, 115, 45, 115, 101, 114, 105, 102, 59, 34, 62, 49, 55, 49, 55, 46, 56, 53, 32, 85, 83, 68, 60, 47, 116, 100, 62, 60, 47, 116, 114, 62, 61, 13, 10, 60, 47, 116, 97, 98, 108, 101, 62, 60, 47, 116, 100, 62, 60, 47, 116, 114, 62, 60, 116, 114];
    let vec: BoundedVec<u8, 256> = BoundedVec::from(data);
    let sequence: Sequence = Sequence { index: 21, length: 206};
    let x = extract_billed_amount(vec, sequence);
    // println("Amont: ");
    // println(x);
}

// #[test]
fn test_check_date() {
    let data: [u8; 320] = [101, 102, 116, 58, 49, 48, 61, 13, 10, 112, 120, 59, 34, 62, 50, 110, 100, 32, 98, 97, 103, 32, 119, 101, 105, 103, 104, 116, 32, 97, 110, 100, 32, 100, 105, 109, 101, 110, 115, 105, 111, 110, 115, 60, 47, 116, 100, 62, 60, 47, 116, 114, 62, 60, 116, 114, 62, 60, 116, 100, 32, 115, 116, 121, 108, 101, 61, 51, 68, 34, 102, 111, 110, 116, 45, 102, 97, 109, 105, 108, 121, 58, 32, 38, 61, 13, 10, 35, 51, 57, 59, 79, 112, 101, 110, 32, 83, 97, 110, 115, 38, 35, 51, 57, 59, 44, 32, 115, 97, 110, 115, 45, 115, 101, 114, 105, 102, 59, 32, 116, 101, 120, 116, 45, 97, 108, 105, 103, 110, 58, 32, 108, 101, 102, 116, 59, 32, 102, 111, 110, 116, 45, 115, 105, 122, 101, 58, 32, 49, 50, 112, 120, 59, 32, 112, 97, 100, 100, 105, 110, 103, 45, 61, 13, 10, 98, 111, 116, 116, 111, 109, 58, 53, 112, 120, 59, 32, 112, 97, 100, 100, 105, 110, 103, 45, 116, 111, 112, 58, 32, 53, 112, 120, 59, 32, 112, 97, 100, 100, 105, 110, 103, 45, 108, 101, 102, 116, 58, 49, 48, 112, 120, 59, 34, 62, 83, 97, 116, 44, 32, 65, 112, 114, 32, 50, 50, 44, 32, 50, 48, 50, 51, 60, 98, 114, 47, 62, 68, 101, 110, 61, 13, 10, 118, 101, 114, 44, 32, 67, 79, 44, 32, 85, 83, 32, 40, 68, 69, 78, 41, 60, 98, 114, 47, 62, 116, 111, 32, 84, 97, 105, 112, 101, 105, 32, 40, 84, 80, 69, 32, 45, 32, 84, 97, 111, 121, 117, 97, 110, 41, 60, 47, 116, 100, 62, 60, 116, 100, 32, 115, 116, 121, 108, 101, 61, 51, 68, 34, 102, 111, 110, 116, 45, 102, 97, 109, 105, 108, 61, 13];
    let vec: BoundedVec<u8, 320> = BoundedVec::from(data);
    let sequence: Sequence = Sequence { index: 14, length: 223};
    let date = extract_departing_flight_date(vec, sequence);
    // println("Date: ");
    // println(date);
}


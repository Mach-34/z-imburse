use crate::utils::{check_qp_sequence, check_qp_sequence_reverse, is_qp_linebreak_char, remove_soft_line_break};
use super::constants::{ARRIVAL_DATE_POSTFIX_LENGTH, ARRIVAL_DATE_PREFIX_LENGTH,
    ARRIVAL_DATE_HTML_PREFIX, ARRIVAL_DATE_HTML_POSTFIX, DEST_AIPORT_POSTFIX_LENGTH, DEST_AIRPORT_PREFIX_LENGTH, DEST_AIRPORT_HTML_POSTFIX, DEST_AIRPORT_HTML_PREFIX, MAX_BILLED_AMOUNT, MAX_EMAIL_BODY_LENGTH,
    MAX_EMAIL_HEADER_LENGTH, PURCHASE_SUMMARY_INDICE_LEN, UNITED_FLIGHT_RECEIPT_FROM,
    UNITED_FLIGHT_RECEIPT_SUBJECT, TOTAL_BILLED_HTML_PREFIX, TOTAL_BILLED_HTML_POSTFIX,
    TOTAL_BILLED_PREFIX_LENGTH, TOTAL_BILLED_POSTFIX_LENGTH
};
use zkemail::Sequence;

/**
* Check that email is from United receipts address
*/
pub fn check_from_united_receipts(index: u32, header: BoundedVec<u8, MAX_EMAIL_HEADER_LENGTH>) {
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
pub fn check_subject_united_flight_receipt(index: u32, header: BoundedVec<u8, MAX_EMAIL_HEADER_LENGTH>) {
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

pub fn extract_billed_amount(
    body: BoundedVec<u8, MAX_EMAIL_BODY_LENGTH>,
    amount_sequence: Sequence
) -> Field {
    // check the prefix of the amount sequence
    check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 43, TOTAL_BILLED_PREFIX_LENGTH>(
        body,
        amount_sequence.index,
        TOTAL_BILLED_HTML_PREFIX,
        "Index does not point to total billed prefix"
    );

    // check the postfix of the amount sequence
    check_qp_sequence_reverse::<MAX_EMAIL_BODY_LENGTH, 44, TOTAL_BILLED_POSTFIX_LENGTH>(
        body,
        amount_sequence.index + amount_sequence.length - 1,
        TOTAL_BILLED_HTML_POSTFIX,
        "Index does not point to total billed postfix"
    );

    // TODO: newline chars hardcoded for now
    let amount_length = amount_sequence.length - TOTAL_BILLED_PREFIX_LENGTH - TOTAL_BILLED_POSTFIX_LENGTH - 9;
    let amount_end_index = amount_sequence.index + TOTAL_BILLED_PREFIX_LENGTH + amount_length + 9;

    // parse the amount
    let mut amount: Field = 0;
    let mut pow = 1;
    // add 3 to handle CRLF chars
    for i in 0..(MAX_BILLED_AMOUNT + 3) {
        let byte = body.get_unchecked(amount_end_index - i - 1);
        if (i < amount_length) & (byte != 0x2E) & (is_qp_linebreak_char(byte) == false) {
            let val = (byte - 0x30) as Field;
            amount = amount + val * pow;
            pow = pow * 10;
        }
    }
    amount
}

pub fn extract_departing_flight_date(body: BoundedVec<u8, MAX_EMAIL_BODY_LENGTH>, date_sequence: Sequence) {
    // check the prefix of the date sequence
    check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 45, ARRIVAL_DATE_PREFIX_LENGTH>(
        body,
        date_sequence.index,
        ARRIVAL_DATE_HTML_PREFIX,
        "Index does not point to departing date prefix"
    );

    // check the postfix of the date sequence
    check_qp_sequence_reverse::<MAX_EMAIL_BODY_LENGTH, 46, ARRIVAL_DATE_POSTFIX_LENGTH>(
        body,
        date_sequence.index + date_sequence.length - 1,
        ARRIVAL_DATE_HTML_POSTFIX,
        "Index does not point to departing date postfix"
    );
}

pub fn extract_destination_airport(
    body: BoundedVec<u8, MAX_EMAIL_BODY_LENGTH>,
    dest_airport_sequence: Sequence
) {
        // check the prefix of the destination airport sequence
    check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 50, DEST_AIRPORT_PREFIX_LENGTH>(
        body,
        dest_airport_sequence.index,
        DEST_AIRPORT_HTML_PREFIX,
        "Index does not point to destination airport prefix"
    );

    // check the postfix of the date sequence
    check_qp_sequence_reverse::<MAX_EMAIL_BODY_LENGTH, 51, DEST_AIPORT_POSTFIX_LENGTH>(
        body,
        dest_airport_sequence.index + dest_airport_sequence.length - 1,
        DEST_AIRPORT_HTML_POSTFIX,
        "Index does not point to destination airport postfix"
    );
}

use crate::frontier::constants::{FRONTIER_FLIGHTS_FROM, FRONTIER_FROM_LEN, FRONTIER_FLIGHT_CONFIRMATION_SUBJECT, FRONTIER_SUBJECT_LEN, MAX_BILLED_AMOUNT, MAX_FRONTIER_EMAIL_BODY_LENGTH, MAX_FRONTIER_EMAIL_HEADER_LENGTH, PURCHASE_TOTAL_INDICE_LEN};
use crate::utils::check_qp_sequence;

/**
* Check that email is from Frontier flights address
*/
pub fn check_from_frontier_flights(index: u32, header: [u8; MAX_FRONTIER_EMAIL_HEADER_LENGTH]) {
    // check the first char is "f" or "F"
    assert((header[index] == 0x66) | (header[index] != 0x46), "Email sender not found.");

    // check the remaing chars are the expected Frontier from
    let from_bytes = FRONTIER_FLIGHTS_FROM.as_bytes();
    for i in 0..FRONTIER_FROM_LEN {
        assert(header[i + index + 1] == from_bytes[i], "Email not from Frontier flights.");
    }

    // check for CRLF
    assert(header[FRONTIER_FROM_LEN + index + 1] == 0x0D, "Invalid CRLF sequence");
    assert(header[FRONTIER_FROM_LEN + index + 2] == 0x0A, "Invalid CRLF sequence");
}

/**
* Check that email subject is Your Flight Confirmation Code <confirmation_code>
*/
pub fn check_subject_frontier_confirmation_receipt(index: u32, header: [u8; MAX_FRONTIER_EMAIL_HEADER_LENGTH]) {
    // check the first char is "s" or "S"
    assert((header[index] == 0x73) | (header[index] == 0x53), "Email subject not found");

    let subject_bytes = FRONTIER_FLIGHT_CONFIRMATION_SUBJECT.as_bytes();
    // check chars in fixed section start
    for i in 0..FRONTIER_SUBJECT_LEN {
        assert(header[i + index + 1] == subject_bytes[i], "Email subject is not Frontier flight confirmation");
    }

    // United confirmation number always follows and has a length of 6
    // check for CRLF
    assert(header[FRONTIER_SUBJECT_LEN + index + 8] == 0x0D, "Invalid CRLF sequence");
    assert(header[FRONTIER_SUBJECT_LEN + index + 9] == 0x0A, "Invalid CRLF sequence");
}

pub fn decode_quoted_printable_char(chars: [u8; 2]) -> u8 {
    // TODO
    0
}

/**
* Extract the amount billed by Frontier as a u32. Total is displayed in an html table which requires
* a bit of parsing
*/
pub fn extract_billed_amount(
    body: [u8; MAX_FRONTIER_EMAIL_BODY_LENGTH], 
    purchase_total_indices: [u32; PURCHASE_TOTAL_INDICE_LEN],
) -> u32 {

    let tr_start_bytes = "<tr>\r\n <td".as_bytes(); // \r\n always appear in same location in Frontier email
    let td_label_close_bytes = ">Grand Total</td>\r\n <td".as_bytes();
    let tr_end_bytes = "</td>\r\n </tr>".as_bytes();

    let tr_start_index = purchase_total_indices[0];
    let td_label_length = purchase_total_indices[1];
    let td_amount_length = purchase_total_indices[2];
    let amount_length = purchase_total_indices[3];

    let td_label_end_index = tr_start_index + 7 + td_label_length; // tr start + len of '<tr>\r\n ' + length of entire td
    let td_amount_end_index = td_label_end_index + 20 + td_amount_length; // tr_label_end_index + len of '>Grand Total</td>\r\n '+ td_amount_length'
    let tr_end_index = td_amount_end_index + amount_length + 2; // tr_amount_end_index + 1 whitespaces + amount len

    // assert index represents table row opening
    for i in 0..tr_start_bytes.len() {
        assert(body[tr_start_index + i] == tr_start_bytes[i], "Index does not point to tr start.");
    }

    check_qp_sequence::<MAX_FRONTIER_EMAIL_BODY_LENGTH, 51, 23>(
        body, 
        td_label_end_index, 
        td_label_close_bytes,
         "Index does not point to Frontier Grand Total label."
    );

    // assert td closing tag prior to amount
    assert(body[td_amount_end_index] == 0x3E, "Index does not point to td opening tag closure");

    // assert amount td end tag closure and tr end tag closure
    for i in 0..tr_end_bytes.len() {
        assert(body[tr_end_index + i] == tr_end_bytes[i], "Index does not point to tr end closure.");
    }

    let mut amount: u32 = 0;
    // count commas
    let commas = ((amount_length - 8) / 3) - 1; // substract 6 for '$' and '.', and 2 for digits following '.' 
    let mut power = (amount_length - 7) as Field;

    // extract out amount
    let amount_index = td_amount_end_index + 2;
    let qp_dollar_sign = "=24".as_bytes();
    // check that '$' is at beginning of amount
    for i in 0..3 {
        assert(body[amount_index + i] == qp_dollar_sign[i], "Start character is not '$'.");
    }

    let mut remaining_qp_sequence = 0;

    for i in 3..MAX_BILLED_AMOUNT {
        let byte = body[amount_index + i];   
        // check is byte is '='
        if (byte == 0x3D) | (i >= amount_length)  {
            remaining_qp_sequence = 2;
        } else {
            if remaining_qp_sequence == 0 {
                let val = (byte - 0x30) as u32;
                amount = amount + val * (10 as Field).pow_32(power) as u32;
                power = power - 1;
            } else {
                remaining_qp_sequence = remaining_qp_sequence - 1;
            }
        }
    }

    amount
}
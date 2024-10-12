use crate::american_airlines::constants::{AA_FLIGHT_CONFIRMATION_SUBJECT_START, AA_FLIGHT_CONFIRMATION_SUBJECT_END, AA_FLIGHT_RECEIPT_FROM, AA_FROM_LEN, AA_SUBJECT_START_LEN, AA_SUBJECT_END_LEN, MAX_AA_EMAIL_BODY_LENGTH, MAX_AA_EMAIL_HEADER_LENGTH, MAX_BILLED_AMOUNT, TOTAL_COST_INDICE_LENGTH};

/**
* Check that email is from American Airlines info address
*/
pub fn check_from_aa_info(index: u32, header: [u8; MAX_AA_EMAIL_HEADER_LENGTH]) {
    // check the first char is "f" or "F"
    assert((header[index] == 0x66) | (header[index] != 0x46), "Email sender not found.");

    // check the remaing chars are the expected American Airlines receipt
    let from_bytes = AA_FLIGHT_RECEIPT_FROM.as_bytes();
    for i in 0..AA_FROM_LEN {
        assert(header[i + index + 1] == from_bytes[i], "Email not from American Airlines info.");
    }

    // check for CRLF
    assert(header[AA_FROM_LEN + index + 1] == 0x0D, "Invalid CRLF sequence");
    assert(header[AA_FROM_LEN + index + 2] == 0x0A, "Invalid CRLF sequence");
}

/**
* Check that email subject is Your trip confirmation (<origin_airport> - <destination_airport>)
*/
pub fn check_subject_aa_flight_confirmation(index: u32, header: [u8; MAX_AA_EMAIL_HEADER_LENGTH]) {
    // check the first char is "s" or "S"
    assert((header[index] == 0x73) | (header[index] == 0x53), "Email subject not found");

    let subject_start_bytes = AA_FLIGHT_CONFIRMATION_SUBJECT_START.as_bytes();
    // check chars in fixed section start
    for i in 0..AA_SUBJECT_START_LEN {
        assert(header[i + index + 1] == subject_start_bytes[i], "Email subject is not American Airlines flight confirmation.");
    }

    let hyphen_index = index + AA_SUBJECT_START_LEN + 5;
    // check separator between origin and destination (<origin_airport> - <destination_airport>)
    assert(header[hyphen_index] == 0x2D, "Email subject is not American Airlines flight confirmation.");

    let subject_end_index = hyphen_index + 5;
    let subject_end_bytes = AA_FLIGHT_CONFIRMATION_SUBJECT_END.as_bytes();
    for i in 0..AA_SUBJECT_END_LEN {
        assert(header[subject_end_index + i] == subject_end_bytes[i], "Email subject is not American Airlines flight confirmation.");
    }
}

/**
* Extract the amount billed by American Airlines as a u32. Total is displayed in an html table which requires
* a bit of parsing
*/
pub fn extract_billed_amount(
    body: [u8; MAX_AA_EMAIL_BODY_LENGTH], 
    total_cost_indices: [u32; TOTAL_COST_INDICE_LENGTH] 
) -> u32 {

    let tr_opening_bytes = "<tr>\r\n <td".as_bytes();
    let label_span_opening_bytes = ">\r\n <span".as_bytes();
    let label_bytes = ">Total cost </span>\r\n =20\r\n </td>\r\n =20\r\n <td".as_bytes();
    let tr_closing_bytes = "</td>\r\n </tr>".as_bytes();

    let tr_tag_start_index  = total_cost_indices[0];
    let td_label_length = total_cost_indices[1];
    let span_label_length = total_cost_indices[2];
    let td_cost_length = total_cost_indices[3];
    let amount_length = total_cost_indices[4];

    // assert row start tag exists at provided index
    for i in 0..tr_opening_bytes.len() {
        assert(body[tr_tag_start_index + i] == tr_opening_bytes[i], "Tr opening not found.");
    }

    // assert close of td start and opening of span tag exist at index computed with td tag length
    let label_span_opening_index = tr_tag_start_index + tr_opening_bytes.len() - 3 + td_label_length - 1;
    for i in 0..label_span_opening_bytes.len() {
        assert(body[label_span_opening_index + i] == label_span_opening_bytes[i], "Td close and span opening not found.");
    }

    // assert close of span tag, 'Total cost' label, and opening td of total cost amount
    let label_index = label_span_opening_index + 4 + span_label_length;
    for i in 0..label_bytes.len() {
        assert(body[label_index + i] == label_bytes[i], "Total cost label not found.");
    }

    // assert td closure at calculated index
    let cost_index = label_index + label_bytes.len() - 3 + td_cost_length;
    assert(body[cost_index] == 0x3E, "Td start closure not found.");

    // assert cost row closure
    let td_cost_end_index = cost_index + amount_length + 1;
    for i in 0..tr_closing_bytes.len() {
        assert(body[td_cost_end_index + i] == tr_closing_bytes[i], "Tr closure not found.");
    }

    let mut amount: u32 = 0;
    let mut power: Field = 0;
    // extract out amount

    // assert first character is '$'
    assert(body[cost_index + 1] == 0x24, "Cost must be preceded by '$'");

    for i in 0..MAX_BILLED_AMOUNT {
        let byte = body[cost_index + amount_length - i];
        if (i < amount_length - 1) & (byte != 0x2C) & (byte != 0x2E) {
            let val = (byte - 0x30) as u32;
            amount = amount + val * (10 as Field).pow_32(power) as u32;
            power = power + 1;
        }
    }
    amount
}
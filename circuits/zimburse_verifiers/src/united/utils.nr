use crate::united::constants::{
    MAX_BILLED_AMOUNT, MAX_EMAIL_BODY_LENGTH, MAX_EMAIL_HEADER_LENGTH, PURCHASE_SUMMARY_INDICE_LEN, 
    UNITED_FLIGHT_RECEIPT_FROM, UNITED_FLIGHT_RECEIPT_SUBJECT, UR_FROM_LEN, UR_SUBJECT_LEN
};
use crate::utils::{check_qp_sequence, is_qp_linebreak_char};

/**
* Check that email is from United receipts address
*/
pub fn check_from_united_receipts(index: u32, header: [u8; MAX_EMAIL_HEADER_LENGTH]) {
    // check the first char is "f" or "F"
    assert((header[index] == 0x66) | (header[index] != 0x46), "Email sender not found.");

    // check the remaing chars are the expected United receipts
    let from_bytes = UNITED_FLIGHT_RECEIPT_FROM.as_bytes();
    for i in 0..UR_FROM_LEN {
        assert(header[i + index + 1] == from_bytes[i], "Email not from United receipts.");
    }

    // check for CRLF
    assert(header[UR_FROM_LEN + index + 1] == 0x0D, "Invalid CRLF sequence");
    assert(header[UR_FROM_LEN + index + 2] == 0x0A, "Invalid CRLF sequence");
}

/**
* Check that email subject is United eTicket Itinerary and Receipt
*/
pub fn check_subject_united_flight_receipt(index: u32, header: [u8; MAX_EMAIL_HEADER_LENGTH]) {
    // check the first char is "s" or "S"
    assert((header[index] == 0x73) | (header[index] == 0x53), "Email subject not found");

    let subject_bytes = UNITED_FLIGHT_RECEIPT_SUBJECT.as_bytes();
    // check chars in fixed section start
    for i in 0..UR_SUBJECT_LEN {
        assert(header[i + index + 1] == subject_bytes[i], "Email subject is not United eTicket receipt");
    }

    // United confirmation number always follows and has a length of 6
    // check for CRLF
    assert(header[UR_SUBJECT_LEN + index + 8] == 0x0D, "Invalid CRLF sequence");
    assert(header[UR_SUBJECT_LEN + index + 9] == 0x0A, "Invalid CRLF sequence");
}


/**
* Extract the amount billed by United as a u32. Total is displayed in an html table which requires
* a bit of parsing
*/
pub fn extract_billed_amount(
    body: [u8; MAX_EMAIL_BODY_LENGTH], 
    purchase_summary_indices: [u32; PURCHASE_SUMMARY_INDICE_LEN] 
) -> u32 {
    let total_tr_tag_start_opening_index = purchase_summary_indices[0]; // <tr ...
    let total_tr_tag_start_len = purchase_summary_indices[1];
    let total_label_td_start_len = purchase_summary_indices[2];
    let total_amount_td_start_len = purchase_summary_indices[3];
    let total_amount_len = purchase_summary_indices[4];

    let tr_opening_bytes = "<tr ".as_bytes();
    let td_amt_opening_bytes = "<td ".as_bytes();
    let label_bytes = ">Total:</td><td ".as_bytes();
    let tr_closing_bytes = " USD</td></tr>".as_bytes();

    let total_label_td_start_index = total_tr_tag_start_opening_index + total_tr_tag_start_len + 1; // <=\r\ntd ...
    let total_label_td_end_index = total_label_td_start_index + total_label_td_start_len; // >Total:</td><td 
    let total_amount_td_end_index = total_label_td_end_index + total_amount_td_start_len + label_bytes.len() - 4;
    let total_tr_closure_index = total_amount_td_end_index + total_amount_len + 1; //  USD</td></tr>\r\n

    // assert index represents table row opening
    check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 35, 4>(
        body, 
        total_tr_tag_start_opening_index, 
        tr_opening_bytes,
        "Index does not point to tr opening."
    );

    // check row close at open index + tag length and what proceeds 
    assert(body[total_tr_tag_start_opening_index + total_tr_tag_start_len] == 0x3E, "Index does not point to tr opening tag closure");

    // assert following the close of the row opening tag is a data tag
    check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 35, 4>(
        body, 
        total_label_td_start_index, 
        td_amt_opening_bytes,
         "Index does not point to td opening."
    );

    // assert opening tag is closed and "Total:" is contained withing data tag. Also check that it is followed by another opening "<td"
    check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 51, 16>(
        body, 
        total_label_td_end_index, 
        label_bytes,
        "Td opening tag does not have closure at this index."
    );

    // assert td closing tag prior to amount
    assert(body[total_amount_td_end_index] == 0x3E, "Index does not point to td opening tag closure");

    // assert amount td end tag closure and tr end tag closure
    check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 39, 14>(
        body, 
        total_tr_closure_index, 
        tr_closing_bytes,
        "Index does not point to tr end closure."
    );

    let mut amount: u32 = 0;
    let mut power: Field = 0;
    // extract out amount
    for i in 0..MAX_BILLED_AMOUNT {
        let byte = body[total_amount_td_end_index + total_amount_len - i];
        if (i < total_amount_len) & (is_qp_linebreak_char(byte) == false) & (byte != 0x2E) {
            let val = (byte - 0x30) as u32;
            amount = amount + val * (10 as Field).pow_32(power) as u32;
            power = power + 1;
        }
    }

    amount
}
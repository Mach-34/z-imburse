use crate::united::constants::{
    MAX_BILLED_AMOUNT, MAX_EMAIL_BODY_LENGTH, MAX_EMAIL_HEADER_LENGTH, PURCHASE_SUMMARY_INDICE_LEN,
    UNITED_FLIGHT_RECEIPT_FROM, UNITED_FLIGHT_RECEIPT_SUBJECT, TOTAL_BILLED_HTML_PREFIX
};
use crate::utils::{check_qp_sequence_reverse, is_qp_linebreak_char, remove_soft_line_break};
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
    assert(header.get_unchecked(from_len + index + 1) == 0x0D, "Invalid CRLF sequence");
    assert(header.get_unchecked(from_len + index + 2) == 0x0A, "Invalid CRLF sequence");
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
    assert(header.get_unchecked(subject_len - 2) == 0x0D, "Invalid CRLF sequence");
    assert(header.get_unchecked(subject_len - 1) == 0x0A, "Invalid CRLF sequence");

    // United confirmation number always follows and has a length of 6
    // check for CRLF
    assert(header.get_unchecked(subject_len + index + 7) == 0x0D, "Invalid CRLF sequence");
    assert(header.get_unchecked(subject_len + index + 8) == 0x0A, "Invalid CRLF sequence");
}

pub fn extract_billed_amount(amount_sequence: Sequence, body: BoundedVec<u8, MAX_EMAIL_HEADER_LENGTH>) -> u32 {
    // check the prefix of the amount sequence
    check_qp_sequence_reverse(
        body,
        amount_sequence.index - 1,
        TOTAL_BILLED_HTML_PREFIX,
        "Index does not point to total billed"
    );
    // extract the amount
    let mut amount_utf8 = remove_soft_line_break(body, amount_sequence);
    // check that the 3rd to last char is .
    assert(amount_utf8.get_unchecked(amount_utf8.len() - 3) == 0x2E, "Amount does not have decimal point");
    // parse the amount
    0
}

// /**
// * Extract the amount billed by United as a u32. Total is displayed in an html table which requires
// * a bit of parsing
// */
// pub fn extract_billed_amount(
//     body: [u8; MAX_EMAIL_BODY_LENGTH], 
//     purchase_summary_indices: [u32; PURCHASE_SUMMARY_INDICE_LEN] 
// ) -> u32 {
//     let total_tr_tag_start_opening_index = purchase_summary_indices[0]; // <tr ...
//     let total_tr_tag_start_len = purchase_summary_indices[1];
//     let total_label_td_start_len = purchase_summary_indices[2];
//     let total_amount_td_start_len = purchase_summary_indices[3];
//     let total_amount_len = purchase_summary_indices[4];

//     let tr_opening_bytes = "<tr ".as_bytes();
//     let td_amt_opening_bytes = "<td ".as_bytes();
//     let label_bytes = ">Total:</td><td ".as_bytes();
//     let tr_closing_bytes = " USD</td></tr>".as_bytes();

//     let total_label_td_start_index = total_tr_tag_start_opening_index + total_tr_tag_start_len + 1; // <=\r\ntd ...
//     let total_label_td_end_index = total_label_td_start_index + total_label_td_start_len; // >Total:</td><td 
//     let total_amount_td_end_index = total_label_td_end_index + total_amount_td_start_len + label_bytes.len() - 4;
//     let total_tr_closure_index = total_amount_td_end_index + total_amount_len + 1; //  USD</td></tr>\r\n

//     // assert index represents table row opening
//     check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 35, 4>(
//         body, 
//         total_tr_tag_start_opening_index, 
//         tr_opening_bytes,
//         "Index does not point to tr opening."
//     );

//     // check row close at open index + tag length and what proceeds 
//     assert(body[total_tr_tag_start_opening_index + total_tr_tag_start_len] == 0x3E, "Index does not point to tr opening tag closure");

//     // assert following the close of the row opening tag is a data tag
//     check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 35, 4>(
//         body, 
//         total_label_td_start_index, 
//         td_amt_opening_bytes,
//          "Index does not point to td opening."
//     );

//     // assert opening tag is closed and "Total:" is contained withing data tag. Also check that it is followed by another opening "<td"
//     check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 51, 16>(
//         body, 
//         total_label_td_end_index, 
//         label_bytes,
//         "Td opening tag does not have closure at this index."
//     );

//     // assert td closing tag prior to amount
//     assert(body[total_amount_td_end_index] == 0x3E, "Index does not point to td opening tag closure");

//     // assert amount td end tag closure and tr end tag closure
//     check_qp_sequence::<MAX_EMAIL_BODY_LENGTH, 39, 14>(
//         body, 
//         total_tr_closure_index, 
//         tr_closing_bytes,
//         "Index does not point to tr end closure."
//     );

//     let mut amount: u32 = 0;
//     let mut power: Field = 0;
//     // extract out amount
//     for i in 0..MAX_BILLED_AMOUNT {
//         let byte = body[total_amount_td_end_index + total_amount_len - i];
//         if (i < total_amount_len) & (is_qp_linebreak_char(byte) == false) & (byte != 0x2E) {
//             let val = (byte - 0x30) as u32;
//             amount = amount + val * (10 as Field).pow_32(power) as u32;
//             power = power + 1;
//         }
//     }

//     amount
// }
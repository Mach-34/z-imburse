use crate::constants::{
   LB_FROM_LEN, LB_PAYMENT_TEXT_LEN, LB_SUBJECT_FIXED_END_LEN, LB_SUBJECT_FIXED_START_LEN, LINODE_BILLING_FROM, LINODE_BILLING_PAYMENT_TEXT,
   LINODE_BILLING_SUBJECT_FIXED_END, LINODE_BILLING_SUBJECT_FIXED_START, MAX_BILLED_AMOUNT, MAX_LINODE_EMAIL_BODY_LENGTH,
    MAX_LINODE_EMAIL_HEADER_LENGTH, DATE_HEADER_FIELD_MAX_LENGTH, DATE_LENGTH_DETERMINATION_INDEX, DATE_HEADER_FIELD_START
};
use dep::date_parser::{parse_date_string, to_unix_month, DATETIME_LENGTH};

/**
* Check that email is from linode billing address
*/
pub fn check_from_linode_billing(index: u32, header: [u8; MAX_LINODE_EMAIL_HEADER_LENGTH]) {
    // check the first char is "f" or "F"
    assert((header[index] == 0x66) | (header[index] != 0x46), "Email sender not found.");

    // check the remaing chars are the expected Linode billing
    let from_bytes = LINODE_BILLING_FROM.as_bytes();
    for i in 0..LB_FROM_LEN {
        assert(header[i + index + 1] == from_bytes[i], "Email not from Linode billing.");
    }

    // check for CRLF
    assert(header[LB_FROM_LEN + index + 1] == 0x0D, "Invalid CRLF sequence");
    assert(header[LB_FROM_LEN + index + 2] == 0x0A, "Invalid CRLF sequence");
}

/**
* Check that email subject is linode billing receipt
*/
pub fn check_subject_billing_receipt(index: u32, header: [u8; MAX_LINODE_EMAIL_HEADER_LENGTH], receipt_id_length: u32) {
    // check the first char is "s" or "S"
    assert((header[index] == 0x73) | (header[index] == 0x53), "Email subject not found");

    let fixed_start_bytes = LINODE_BILLING_SUBJECT_FIXED_START.as_bytes();
    // check chars in fixed section start
    for i in 0..LB_SUBJECT_FIXED_START_LEN {
        assert(header[i + index + 1] == fixed_start_bytes[i], "Email subject is not Linode billing receipt");
    }

    let fixed_end_bytes = LINODE_BILLING_SUBJECT_FIXED_END.as_bytes();
    // check chars in fixed section end
    for i in 0..LB_SUBJECT_FIXED_END_LEN {
        let headerIndex = i + index + receipt_id_length + LB_SUBJECT_FIXED_START_LEN;
        assert(header[headerIndex] == fixed_end_bytes[i], "Email subject is not Linode billing receipt");
    }
}

/**
 * Constrains a span to be a full header field
 *
 * @param MAX_HEADER_LENGTH: the maximum possible length of the header
 * @param header: the header of the email
 * @param index: the index that the header field begins at
 * @param length: the length of the header field
 */
pub fn constrain_header_field<let MAX_HEADER_LENGTH: u32>(
    header: [u8; MAX_LINODE_EMAIL_HEADER_LENGTH],
    index: u32,
    length: u32
) {
    // check that the field does not lie outside of the max 
    assert(index + length <= header.len(), "Header field out of bounds");
    // if not the first field in the header, ensure the header field is preceded by a CRLF
    if (index != 0) {
        assert(header[index - 2] == 0x0D, "Missing prefix CR in field constraint");
        assert(header[index - 1] == 0x0A, "Missing prefix LF in field constraint");
    }
    // check that the following two chars are the crlf
    if (index + length < header.len()) {
        assert(header[index + length] == 0x0D, "Missing suffix CR in field constraint");
        assert(header[index + length + 1] == 0x0A, "Missing suffix LF field constraint");
    }
    // check that the field does not contain any CRLF
    for i in 0..MAX_HEADER_LENGTH {
        if (i < length) {
            assert(header[index + i] != 0x0D, "CR in field constraint Field");
        }
    }
}

/**
 * Extracts the datetime from the email header
 *
 * @param header: the header of the email
 * @param index: the index that the date header field begins at
 * @return the parsed unix timestamp
 */
pub fn extract_datetime(header: [u8; MAX_LINODE_EMAIL_HEADER_LENGTH], index: u32) -> u32 {
    // determine the index of the selector that chooses the length of the date field
    let length_decider = index + DATE_LENGTH_DETERMINATION_INDEX;
    let length = if header[length_decider] == 0x20 {
        DATE_HEADER_FIELD_MAX_LENGTH - 1
    } else {
        DATE_HEADER_FIELD_MAX_LENGTH
    };
    // constrain the header field to be a single and full header field
    constrain_header_field::<DATE_HEADER_FIELD_MAX_LENGTH>(header, index, length);
    // check the header field starts with "Date: "
    let first_byte = (header[index] == 0x44) as u1 | (header[index] == 0x64) as u1;
    assert(first_byte as bool, "Invalid date field: [D/d]");
    for i in 0..DATE_HEADER_FIELD_START.len() {
        assert(header[index + i + 1] == DATE_HEADER_FIELD_START[i], "Invalid date field");
    }
    // extract the date string
    let mut datetime_string: [u8; DATETIME_LENGTH] = [0; DATETIME_LENGTH];
    // todo: make const (and also put all this shit in zkemail.nr)
    let start_index = index + 10;
    for i in 0..DATETIME_LENGTH {
        datetime_string[i] = header[start_index + i];
    }
    // parse the datetime into unix
    let parsed = parse_date_string(datetime_string);
    to_unix_month(parsed)
}

pub fn serialize_bytes<let LIMBS: u32, let SEQUENCE_LENGTH: u32>(sequence: [u8; SEQUENCE_LENGTH]) -> [Field; LIMBS] {
    let mut limbs: [Field; LIMBS] = [0; LIMBS];
    for i in 0..LIMBS {
        let mut chunk = 0;
        let mut v = 1;
        for j in 0..31 {
            let index = i * 31 + j;
            if index < SEQUENCE_LENGTH {
                chunk += sequence[index] as Field * v;
                v *= 256;
            }
        }
        limbs[i] = chunk;
    }
    limbs
}

pub fn is_number_constraint(num: u8) {
    assert(num >= 0x30);
    assert(num < 0x3A);
}

/**
* Extract the amount billed by Linode as a u32
*/
pub fn extract_billed_amount(body: [u8; MAX_LINODE_EMAIL_BODY_LENGTH], index: u32, amount_length: u32) -> u32 {

    // ensure billed amount follows valid payment text sequence
    let payment_text_bytes = LINODE_BILLING_PAYMENT_TEXT.as_bytes();
    for i in 0..LB_PAYMENT_TEXT_LEN {
        assert(body[(index - LB_PAYMENT_TEXT_LEN) + i] == payment_text_bytes[i], "Invalid payment text sequence.");
    }

    let mut amount: Field = 0;
    let fixed_values = 4; // '$', '.', and two decimals
    let commas: Field = ((amount_length - fixed_values - 1) / 4) as Field; // account for 
    let mut power: Field = amount_length as Field - commas - 3; // 3 represents '$' and '.' and power is equal to numberic len - 1

    // ensure first character is '$'
    assert(body[index] == 36);

    // if second character is a zero then decrement power
    if body[index + 1] == 48 {
        power = power - 1;
    }

    for i in 1..MAX_BILLED_AMOUNT {
        if i < amount_length {
            let byte = body[index + i];
            // check that byte is not a comma or period
            if (byte != 44) & (byte != 46) {
                amount = amount + ((byte as Field - 48) * (10 as Field).pow_32(power));
                power = power - 1;
            }
        }
    }
    amount as u32
}

// #[test]
// fn value_extraction() {
//     let index = 0;
//     let mut body: [u8; MAX_LINODE_EMAIL_BODY_LENGTH] = [0; MAX_LINODE_EMAIL_BODY_LENGTH];
//     let val = "$4,123.00";
//     let bytes = val.as_bytes();
//     for i in 0..bytes.len() {
//         body[i] = bytes[i];
//     }
//     let extracted = extract_billed_amount(body, index, bytes.len());
//     println(extracted);
// }

// #[test]
// fn test_payment_string_bytes() {
//  let bytes = LINODE_BILLING_PAYMENT_TEXT.as_bytes();
//  println(bytes);
// }
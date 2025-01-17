use crate::linode::{
    constants::{
        LB_FROM_LEN, LB_PAYMENT_TEXT_LEN, LB_SUBJECT_FIXED_END_LEN, LB_SUBJECT_FIXED_START_LEN,
        LINODE_BILLING_FROM, LINODE_BILLING_SUBJECT_FIXED_END, LINODE_BILLING_SUBJECT_FIXED_START,
        LINODE_BILLING_PAYMENT_TEXT, MAX_BILLED_AMOUNT, MAX_LINODE_EMAIL_BODY_LENGTH,
        MAX_LINODE_EMAIL_HEADER_LENGTH
    }
};
use date_parser::{parse_month, from_month_and_year, to_unix_month, MONTH_LONG_OFFSET};
use zkemail::Sequence;

/**
* Check that email is from linode billing address
*/
pub fn check_from_linode_billing(index: u32, header: BoundedVec<u8, MAX_LINODE_EMAIL_HEADER_LENGTH>) {
    // check the first char is "f" or "F"
    assert(
        (header.get_unchecked(index) == 0x66) | (header.get_unchecked(index) != 0x46), "Email sender not found."
    );

    // check the remaing chars are the expected Linode billing
    let from_bytes = LINODE_BILLING_FROM.as_bytes();
    for i in 0..LB_FROM_LEN {
        assert(header.get_unchecked(index + 1 + i) == from_bytes[i], "Email not from Linode billing.");
    }

    // check for CRLF
    assert(header.get_unchecked(LB_FROM_LEN + index + 1) == 0x0D, "Invalid CRLF sequence");
    assert(header.get_unchecked(LB_FROM_LEN + index + 2) == 0x0A, "Invalid CRLF sequence");
}

/**
* Check that email subject is linode billing receipt
*/
pub fn check_subject_linode_billing_receipt(
    index: u32,
    header: BoundedVec<u8, MAX_LINODE_EMAIL_HEADER_LENGTH>,
    receipt_id_length: u32
) {
    // check the first char is "s" or "S"
    assert(
        (header.get_unchecked(index) == 0x73) | (header.get_unchecked(index) == 0x53), "Email subject not found"
    );

    let fixed_start_bytes = LINODE_BILLING_SUBJECT_FIXED_START.as_bytes();
    // check chars in fixed section start
    for i in 0..LB_SUBJECT_FIXED_START_LEN {
        assert(
            header.get_unchecked(i + index + 1) == fixed_start_bytes[i], "Email subject is not Linode billing receipt"
        );
    }

    let fixed_end_bytes = LINODE_BILLING_SUBJECT_FIXED_END.as_bytes();
    // check chars in fixed section end
    for i in 0..LB_SUBJECT_FIXED_END_LEN {
        let header_index = i + index + receipt_id_length + LB_SUBJECT_FIXED_START_LEN;
        assert(
            header.get_unchecked(header_index) == fixed_end_bytes[i], "Email subject is not Linode billing receipt"
        );
    }
}

/**
* Extract the amount billed by Linode as a u32
*/
pub fn extract_billed_amount(
    body: BoundedVec<u8, MAX_LINODE_EMAIL_BODY_LENGTH>,
    amount_index: u32
) -> u32 {
    // ensure billed amount follows valid payment text sequence
    let payment_text_bytes = LINODE_BILLING_PAYMENT_TEXT.as_bytes();
    for i in 0..LB_PAYMENT_TEXT_LEN {
        assert(
            body.get_unchecked(amount_index - LB_PAYMENT_TEXT_LEN + i) == payment_text_bytes[i], "Invalid payment text sequence."
        );
    }

    let mut amount: Field = 0;
    let mut power: Field = 0;

    // ensure first character is '$'
    assert(body.get(amount_index) == 36);

    for i in 1..MAX_BILLED_AMOUNT {
        let byte = body.get(amount_index + MAX_BILLED_AMOUNT - i);
        // check that byte is numeric 
        if (byte >= 0x30) & (byte <= 0x39) {
            amount = amount + ((byte as Field - 0x30) * (10 as Field).pow_32(power));
            power = power + 1;
        }
    }
    amount as u32
}

/**
 * Parses the month and the year from the email body's "Payment Date" field
 *
 * @param body - the signed email body of a linode billing receipt
 * @param date_index - the index of the first character of the "Payment Date" field
 * @return - the unix timestamp of the month/ year
 */
pub fn extract_datetime(
    body: BoundedVec<u8, MAX_LINODE_EMAIL_BODY_LENGTH>,
    date_index: u32
) -> u32 {
    // range check access (TODO)
    // check the prefix to ensure any other dates in email are not used
    let prefix: [u8; 16] = comptime { "\r\nPayment Date: ".as_bytes() };
    for i in 0..16 {
        let prefix_char = body.get_unchecked(date_index - 16 + i);
        assert(prefix_char == prefix[i], "Invalid date prefix");
    }
    
    // determine month
    let extracted_month = [
        body.get_unchecked(date_index),
        body.get_unchecked(date_index + 1),
        body.get_unchecked(date_index + 2)
    ];
    let month_idx = parse_month(extracted_month);
    assert(month_idx != 0, "Invalid month retrieved");
    // determine year
    let offset_to_year = MONTH_LONG_OFFSET[month_idx - 1] + 3 + 5; // (month code), " xx, "
    let extracted_year = [
        body.get_unchecked(date_index + offset_to_year),
        body.get_unchecked(date_index + offset_to_year + 1),
        body.get_unchecked(date_index + offset_to_year + 2),
        body.get_unchecked(date_index + offset_to_year + 3)
    ];
    let datetime = from_month_and_year(month_idx, extracted_year);
    to_unix_month(datetime)
}

// fix check for https://veridise.notion.site/Amount-may-be-increased-up-to-maximum-149105edf1db800fa451d9aea3e877e7
#[test]
fn test_extract_billed_amount_manipulated_length() {
    let value = "$1,000.00.\r\n\r\nThank you.".as_bytes();
    let mut storage: [u8; MAX_LINODE_EMAIL_BODY_LENGTH] = [0; MAX_LINODE_EMAIL_BODY_LENGTH];
    let sequence_length = value.len();
    let text_length = LB_PAYMENT_TEXT_LEN + sequence_length;
    for i in 0..text_length{
        if i < LB_PAYMENT_TEXT_LEN {
            storage[i] = LINODE_BILLING_PAYMENT_TEXT.as_bytes()[i];
        }
        else {
            storage[i] = value[i - LB_PAYMENT_TEXT_LEN];
        }
    }
    let body: BoundedVec<u8, MAX_LINODE_EMAIL_BODY_LENGTH> = BoundedVec {
        storage,
        len: text_length
    };
    let amount_index = LB_PAYMENT_TEXT_LEN;
    let extracted_amount = extract_billed_amount(body, amount_index);
    assert(extracted_amount == 100000);
}

#[test]
fn test_extract_billed_amount_decimal() {
    let value = "$0.67.\r\n\r\nThank you.".as_bytes();
    let mut storage: [u8; MAX_LINODE_EMAIL_BODY_LENGTH] = [0; MAX_LINODE_EMAIL_BODY_LENGTH];
    let sequence_length = value.len();
    let text_length = LB_PAYMENT_TEXT_LEN + sequence_length;
    for i in 0..text_length{
        if i < LB_PAYMENT_TEXT_LEN {
            storage[i] = LINODE_BILLING_PAYMENT_TEXT.as_bytes()[i];
        }
        else {
            storage[i] = value[i - LB_PAYMENT_TEXT_LEN];
        }
    }
    let body: BoundedVec<u8, MAX_LINODE_EMAIL_BODY_LENGTH> = BoundedVec {
        storage,
        len: text_length
    };
    let amount_index = LB_PAYMENT_TEXT_LEN;
    let extracted_amount = extract_billed_amount(body, amount_index);
    assert(extracted_amount == 67);
}

#[test]
fn test_extract_billed_amount_max() {
    let value = "$9,999,999.99.\r\n\r\nThank you.".as_bytes();
    let mut storage: [u8; MAX_LINODE_EMAIL_BODY_LENGTH] = [0; MAX_LINODE_EMAIL_BODY_LENGTH];
    let text_length = LB_PAYMENT_TEXT_LEN + value.len();
    for i in 0..text_length{
        if i < LB_PAYMENT_TEXT_LEN {
            storage[i] = LINODE_BILLING_PAYMENT_TEXT.as_bytes()[i];
        }
        else {
            storage[i] = value[i - LB_PAYMENT_TEXT_LEN];
        }
    }
    let body: BoundedVec<u8, MAX_LINODE_EMAIL_BODY_LENGTH> = BoundedVec {
        storage,
        len: text_length
    };
    let amount_index = LB_PAYMENT_TEXT_LEN;
    let extracted_amount = extract_billed_amount(body, amount_index);
    assert(extracted_amount == 999999999);
}

#[test]
fn test_extract_billed_amount_normal() {
    let body: BoundedVec<u8, MAX_LINODE_EMAIL_BODY_LENGTH> = BoundedVec {
        storage: [13, 10, 67, 111, 109, 112, 97, 110, 121, 32, 78, 97, 109, 101, 58, 32, 13, 10, 80, 97, 121, 109, 101, 110, 116, 32, 78, 117, 109, 98, 101, 114, 58, 32, 49, 55, 52, 49, 49, 57, 48, 52, 13, 10, 80, 97, 121, 109, 101, 110, 116, 32, 68, 97, 116, 101, 58, 32, 83, 101, 112, 116, 101, 109, 98, 101, 114, 32, 48, 49, 44, 32, 50, 48, 50, 52, 13, 10, 80, 97, 121, 109, 101, 110, 116, 32, 67, 97, 114, 100, 58, 32, 48, 48, 51, 52, 13, 10, 13, 10, 84, 104, 105, 115, 32, 105, 115, 32, 121, 111, 117, 114, 32, 114, 101, 99, 101, 105, 112, 116, 32, 111, 102, 32, 112, 97, 121, 109, 101, 110, 116, 32, 97, 103, 97, 105, 110, 115, 116, 32, 121, 111, 117, 114, 32, 99, 114, 101, 100, 105, 116, 32, 99, 97, 114, 100, 32, 105, 110, 32, 116, 104, 101, 32, 13, 10, 97, 109, 111, 117, 110, 116, 32, 111, 102, 32, 36, 50, 50, 46, 48, 48, 46, 13, 10, 13, 10, 84, 104, 97, 110, 107, 32, 121, 111, 117, 46, 13, 10, 13, 10, 80, 108, 101, 97, 115, 101, 32, 110, 111, 116, 101, 32, 116, 104, 97, 116, 32, 99, 104, 97, 114, 103, 101, 115, 32, 119, 105, 108, 108, 32, 97, 112, 112, 101, 97, 114, 32, 97, 115, 32, 34, 76, 105, 110, 111, 100, 101, 42, 65, 107, 97, 109, 97, 105, 34, 32, 111, 110, 32, 121, 111, 117, 114, 13, 10, 99, 114, 101, 100, 105, 116, 32, 99, 97, 114, 100, 39, 115, 32, 115, 116, 97, 116, 101, 109, 101, 110, 116, 46, 13, 10, 13, 10, 70, 111, 114, 32, 97, 99, 99, 111, 117, 110, 116, 32, 105, 110, 102, 111, 114, 109, 97, 116, 105, 111, 110, 32, 97, 110, 100, 32, 99, 117, 114, 114, 101, 110, 116, 32, 98, 97, 108, 97, 110, 99, 101, 44, 32, 112, 108, 101, 97, 115, 101, 32, 118, 105, 115, 105, 116, 32, 116, 104, 101, 13, 10, 76, 105, 110, 111, 100, 101, 32, 77, 97, 110, 97, 103, 101, 114, 32, 97, 116, 32, 104, 116, 116, 112, 115, 58, 47, 47, 99, 108, 111, 117, 100, 46, 108, 105, 110, 111, 100, 101, 46, 99, 111, 109, 47, 13, 10, 13, 10, 73, 102, 32, 121, 111, 117, 32, 104, 97, 118, 101, 32, 97, 110, 121, 32, 113, 117, 101, 115, 116, 105, 111, 110, 115, 32, 111, 114, 32, 99, 111, 110, 99, 101, 114, 110, 115, 44, 32, 112, 108, 101, 97, 115, 101, 32, 111, 112, 101, 110, 32, 97, 32, 115, 117, 112, 112, 111, 114, 116, 32, 116, 105, 99, 107, 101, 116, 46, 32, 13, 10, 13, 10, 83, 105, 110, 99, 101, 114, 101, 108, 121, 44, 13, 10, 13, 10, 84, 104, 101, 32, 76, 105, 110, 111, 100, 101, 32, 84, 101, 97, 109, 13, 10, 13, 10, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 13, 10, 104, 116, 116, 112, 58, 47, 47, 119, 119, 119, 46, 108, 105, 110, 111, 100, 101, 46, 99, 111, 109, 47, 32, 45, 32, 76, 105, 110, 117, 120, 32, 67, 108, 111, 117, 100, 32, 72, 111, 115, 116, 105, 110, 103, 13, 10, 13, 10, 80, 108, 101, 97, 115, 101, 32, 110, 111, 116, 101, 32, 116, 104, 97, 116, 32, 101, 102, 102, 101, 99, 116, 105, 118, 101, 32, 74, 117, 108, 121, 32, 48, 49, 44, 32, 50, 48, 50, 50, 44, 32, 99, 104, 97, 114, 103, 101, 115, 32, 102, 111, 114, 32, 76, 105, 110, 111, 100, 101, 32, 115, 101, 114, 118, 105, 99, 101, 115, 32, 109, 97, 121, 13, 10, 97, 112, 112, 101, 97, 114, 32, 97, 115, 32, 34, 76, 105, 110, 111, 100, 101, 42, 65, 107, 97, 109, 97, 105, 34, 32, 119, 105, 116, 104, 32, 121, 111, 117, 114, 32, 98, 97, 110, 107, 32, 111, 114, 32, 99, 114, 101, 100, 105, 116, 32, 99, 97, 114, 100, 46, 13, 10, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24, 0],
        len: 768
    };
    let amount_index = 176;
    let extracted_amount = extract_billed_amount(body, amount_index);
    assert(extracted_amount == 2200);
}

#[test]
fn test_get_date_str() {
    let mut body: BoundedVec<u8, MAX_LINODE_EMAIL_BODY_LENGTH> = BoundedVec {
		storage: [13, 10, 67, 111, 109, 112, 97, 110, 121, 32, 78, 97, 109, 101, 58, 32, 13, 10, 80, 97, 121, 109, 101, 110, 116, 32, 78, 117, 109, 98, 101, 114, 58, 32, 49, 55, 52, 49, 49, 57, 48, 52, 13, 10, 80, 97, 121, 109, 101, 110, 116, 32, 68, 97, 116, 101, 58, 32, 83, 101, 112, 116, 101, 109, 98, 101, 114, 32, 48, 49, 44, 32, 50, 48, 50, 52, 13, 10, 80, 97, 121, 109, 101, 110, 116, 32, 67, 97, 114, 100, 58, 32, 48, 48, 51, 52, 13, 10, 13, 10, 84, 104, 105, 115, 32, 105, 115, 32, 121, 111, 117, 114, 32, 114, 101, 99, 101, 105, 112, 116, 32, 111, 102, 32, 112, 97, 121, 109, 101, 110, 116, 32, 97, 103, 97, 105, 110, 115, 116, 32, 121, 111, 117, 114, 32, 99, 114, 101, 100, 105, 116, 32, 99, 97, 114, 100, 32, 105, 110, 32, 116, 104, 101, 32, 13, 10, 97, 109, 111, 117, 110, 116, 32, 111, 102, 32, 36, 50, 50, 46, 48, 48, 46, 13, 10, 13, 10, 84, 104, 97, 110, 107, 32, 121, 111, 117, 46, 13, 10, 13, 10, 80, 108, 101, 97, 115, 101, 32, 110, 111, 116, 101, 32, 116, 104, 97, 116, 32, 99, 104, 97, 114, 103, 101, 115, 32, 119, 105, 108, 108, 32, 97, 112, 112, 101, 97, 114, 32, 97, 115, 32, 34, 76, 105, 110, 111, 100, 101, 42, 65, 107, 97, 109, 97, 105, 34, 32, 111, 110, 32, 121, 111, 117, 114, 13, 10, 99, 114, 101, 100, 105, 116, 32, 99, 97, 114, 100, 39, 115, 32, 115, 116, 97, 116, 101, 109, 101, 110, 116, 46, 13, 10, 13, 10, 70, 111, 114, 32, 97, 99, 99, 111, 117, 110, 116, 32, 105, 110, 102, 111, 114, 109, 97, 116, 105, 111, 110, 32, 97, 110, 100, 32, 99, 117, 114, 114, 101, 110, 116, 32, 98, 97, 108, 97, 110, 99, 101, 44, 32, 112, 108, 101, 97, 115, 101, 32, 118, 105, 115, 105, 116, 32, 116, 104, 101, 13, 10, 76, 105, 110, 111, 100, 101, 32, 77, 97, 110, 97, 103, 101, 114, 32, 97, 116, 32, 104, 116, 116, 112, 115, 58, 47, 47, 99, 108, 111, 117, 100, 46, 108, 105, 110, 111, 100, 101, 46, 99, 111, 109, 47, 13, 10, 13, 10, 73, 102, 32, 121, 111, 117, 32, 104, 97, 118, 101, 32, 97, 110, 121, 32, 113, 117, 101, 115, 116, 105, 111, 110, 115, 32, 111, 114, 32, 99, 111, 110, 99, 101, 114, 110, 115, 44, 32, 112, 108, 101, 97, 115, 101, 32, 111, 112, 101, 110, 32, 97, 32, 115, 117, 112, 112, 111, 114, 116, 32, 116, 105, 99, 107, 101, 116, 46, 32, 13, 10, 13, 10, 83, 105, 110, 99, 101, 114, 101, 108, 121, 44, 13, 10, 13, 10, 84, 104, 101, 32, 76, 105, 110, 111, 100, 101, 32, 84, 101, 97, 109, 13, 10, 13, 10, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 45, 13, 10, 104, 116, 116, 112, 58, 47, 47, 119, 119, 119, 46, 108, 105, 110, 111, 100, 101, 46, 99, 111, 109, 47, 32, 45, 32, 76, 105, 110, 117, 120, 32, 67, 108, 111, 117, 100, 32, 72, 111, 115, 116, 105, 110, 103, 13, 10, 13, 10, 80, 108, 101, 97, 115, 101, 32, 110, 111, 116, 101, 32, 116, 104, 97, 116, 32, 101, 102, 102, 101, 99, 116, 105, 118, 101, 32, 74, 117, 108, 121, 32, 48, 49, 44, 32, 50, 48, 50, 50, 44, 32, 99, 104, 97, 114, 103, 101, 115, 32, 102, 111, 114, 32, 76, 105, 110, 111, 100, 101, 32, 115, 101, 114, 118, 105, 99, 101, 115, 32, 109, 97, 121, 13, 10, 97, 112, 112, 101, 97, 114, 32, 97, 115, 32, 34, 76, 105, 110, 111, 100, 101, 42, 65, 107, 97, 109, 97, 105, 34, 32, 119, 105, 116, 104, 32, 121, 111, 117, 114, 32, 98, 97, 110, 107, 32, 111, 114, 32, 99, 114, 101, 100, 105, 116, 32, 99, 97, 114, 100, 46, 13, 10, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24, 0],
		len: 768
	};
    let date_index = 58;
    let extracted_date = extract_datetime(body, date_index);
    let expected = 1725148800; // new Date("2024-09-01T00:00:00.000Z").getTime() / 1000
    assert(extracted_date == expected);
}
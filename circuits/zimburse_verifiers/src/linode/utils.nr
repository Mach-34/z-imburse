use crate::linode::{
    constants::{
    LB_FROM_LEN, LB_PAYMENT_TEXT_LEN, LB_SUBJECT_FIXED_END_LEN, LB_SUBJECT_FIXED_START_LEN,
    LINODE_BILLING_FROM, LINODE_BILLING_SUBJECT_FIXED_END, LINODE_BILLING_SUBJECT_FIXED_START,
    LINODE_BILLING_PAYMENT_TEXT, MAX_BILLED_AMOUNT, MAX_LINODE_EMAIL_BODY_LENGTH,
    MAX_LINODE_EMAIL_HEADER_LENGTH
}
};
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
    amount_sequence: Sequence
) -> u32 {
    // ensure billed amount follows valid payment text sequence
    let payment_text_bytes = LINODE_BILLING_PAYMENT_TEXT.as_bytes();
    for i in 0..LB_PAYMENT_TEXT_LEN {
        assert(
            body.get_unchecked(amount_sequence.index - LB_PAYMENT_TEXT_LEN + i) == payment_text_bytes[i], "Invalid payment text sequence."
        );
    }

    let mut amount: Field = 0;
    let fixed_values = 4; // '$', '.', and two decimals
    let commas: Field = ((amount_sequence.length - fixed_values - 1) / 4) as Field; // account for 
    let mut power: Field = amount_sequence.length as Field - commas - 3; // 3 represents '$' and '.' and power is equal to numberic len - 1

    // ensure first character is '$'
    assert(body.get_unchecked(amount_sequence.index) == 36);

    // if second character is a zero then decrement power
    if body.get_unchecked(amount_sequence.index + 1) == 48 {
        power = power - 1;
    }

    for i in 1..MAX_BILLED_AMOUNT {
        if i < amount_sequence.length {
            let byte = body.get_unchecked(amount_sequence.index + i);
            // check that byte is not a comma or period
            if (byte != 44) & (byte != 46) {
                amount = amount + ((byte as Field - 48) * (10 as Field).pow_32(power));
                power = power - 1;
            }
        }
    }
    amount as u32
}


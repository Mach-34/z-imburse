use crate::constants::{DATE_HEADER_FIELD_MAX_LENGTH, DATE_LENGTH_DETERMINATION_INDEX, DATE_HEADER_FIELD_START};
use crate::linode::constants::MAX_LINODE_EMAIL_HEADER_LENGTH;

use dep::date_parser::{parse_date_string, to_unix_month, DATETIME_LENGTH};
use zkemail::Sequence;

/**
 * Constrains a span to be a full header field
 *
 * @param MAX_HEADER_LENGTH: the maximum possible length of the header
 * @param header: the header of the email
 * @param index: the index that the header field begins at
 * @param length: the length of the header field
 */
pub fn constrain_header_field<let MAX_HEADER_LENGTH: u32>(header: [u8; MAX_LINODE_EMAIL_HEADER_LENGTH], index: u32, length: u32) {
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

pub fn field_from_bytes<let N: u32>(bytes: [u8; N]) -> Field {
    let mut as_field = 0;
    let mut offset = 1;
    for i in 0..N {
        as_field += (bytes[i] as Field) * offset;
        offset *= 256;
    }
    as_field
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
* Check whether or not character is quoted printable linebreak
* - 0x3D "="
* - 0xD "\r"
* - 0xA "\n"
*/
fn is_qp_linebreak_char(byte: u8) -> bool {
    (byte == 0x3D) | (byte == 0xD) | (byte == 0xA)
}

fn is_soft_linebreak(window: [u8; 3]) -> bool {
    window == [0x3D, 0x0D, 0x0A]
}

/**
* Check whether email body using quoted printable encoding contains a certain text sequence. Handles
* 3 character linebreak sequences: "=\r\n"
*/
fn check_qp_sequence<let MAX_LEN: u32, let REVERT_MSG_LEN: u32, let SEQ_LEN: u32>(
    text: BoundedVec<u8, MAX_LEN>,
    start_index: u32,
    sequence: [u8; SEQ_LEN],
    revert_msg: str<REVERT_MSG_LEN>
) {
    let mut index = start_index;
    for i in 0..SEQ_LEN {
        // todo: prevent overflow
        let window = [
            text.get_unchecked(index),
            text.get_unchecked(index + 1),
            text.get_unchecked(index + 2)
        ];
        if is_soft_linebreak(window) {
            index = index + 3;
        }
        assert(sequence[i] == text.get_unchecked(index), revert_msg);
        index = index + 1;
    }
}

fn check_qp_sequence_reverse<let MAX_LEN: u32, let REVERT_MSG_LEN: u32, let SEQ_LEN: u32>(
    text: BoundedVec<u8, MAX_LEN>,
    start_index: u32,
    sequence: [u8; SEQ_LEN],
    revert_msg: str<REVERT_MSG_LEN>
) {
    let mut index = start_index;
    for i in 0..SEQ_LEN {
        let window = [
            text.get_unchecked(index - 2),
            text.get_unchecked(index - 1),
            text.get_unchecked(index)
        ];
        if is_soft_linebreak(window) {
            index = index - 3;
        }
        assert(sequence[SEQ_LEN - i - 1] == text.get_unchecked(index), revert_msg);
        index = index - 1;
    }
}

// MAX_TEXT_LEN must >= MAX_SEQ_LEN + (MAX_SEQ_LEN / 75_ + (MAX_SEQ_LEN % 75 != 0) * 3)
fn remove_soft_line_break<let MAX_TEXT_LEN: u32, let MAX_SEQ_LEN: u32>(
    text: BoundedVec<u8, MAX_TEXT_LEN>,
    sequence: Sequence
) -> BoundedVec<u8, MAX_SEQ_LEN + 1> {
    // let mut decoded = BoundedVec::new();
    let mut decoded: [u8; MAX_SEQ_LEN + 1] = [0; MAX_SEQ_LEN + 1];
    let mut decoded_index = 0;
    let mut cooldown = 0;
    for i in 0..MAX_SEQ_LEN {
        // check if the current index is at a linebreak
        let encoded_cursor = i + sequence.index;
        let current_char = text.get_unchecked(encoded_cursor);
        // if i < 5 {
        //     println("\n\nXXXXXXXXXXXXXXXX");
        //     println(encoded_cursor);
        //     println(current_char);

        // }
        let window = [
            current_char,
            text.get_unchecked(encoded_cursor + 1),
            text.get_unchecked(encoded_cursor + 2)
        ];

        // if the current index is a linebreak, skip 3 chars
        if is_soft_linebreak(window) {
            cooldown = 3;
            println("\n\ntriggering cooldown");
        }
        // if cooldown or end of array insert char at end and save cursor
        let mut decoded_cursor = decoded_index;
        if (cooldown > 0) | decoded_index >= sequence.length {
            decoded_index = decoded_index - 1;
            decoded_cursor = MAX_SEQ_LEN;
        }
        if (cooldown > 0) {
            cooldown = cooldown - 1;
        }
        // insert char at cursor
        decoded[decoded_cursor] = current_char;
        // increment
        decoded_index = decoded_index + 1;
    }
    // zero out the last element
    decoded[MAX_SEQ_LEN] = 0;
    let res: BoundedVec<u8, MAX_SEQ_LEN + 1> = BoundedVec { storage: decoded, len: decoded_index };
    res
}

use zkemail::{KEY_LIMBS_2048, Sequence, dkim::RSAPubkey};
use std::meta::derive;
use aztec::protocol_types::traits::Serialize;

// assuming a unlikely max billed amount of "9999999.99"
global MAX_BILLED_AMOUNT = 10;

// estimate maximum text length of destination airport
global MAX_DEST_AIRPORT_LENGTH = 25;

global DATE_LENGTH = 17;

global MAX_EMAIL_BODY_LENGTH: u32 = 25792;
global MAX_UNITED_EMAIL_HEADER_LENGTH: u32 = 640;

global PURCHASE_SUMMARY_INDICE_LEN = 5;

// expected sequence for the sender in an email body for United flight receipt
// "from:billing@linode.com"
global UNITED_FLIGHT_RECEIPT_FROM: [u8; 42] = comptime { "from:United Airlines <Receipts@united.com>".as_bytes() };

// expected sequence in the subject of an email header for United eTicket receipt
// "subject: eTicket Itinerary and Receipt for Confirmation"
global UNITED_FLIGHT_RECEIPT_SUBJECT: [u8; 54] = comptime { "subject:eTicket Itinerary and Receipt for Confirmation".as_bytes() };

global TOTAL_BILLED_PREFIX_LENGTH = 184;
global TOTAL_BILLED_POSTFIX_LENGTH = 9;
global TOTAL_BILLED_HTML_PREFIX: [u8; TOTAL_BILLED_PREFIX_LENGTH] = comptime { "Total:</td><td style=3D\"padding-right:10px; padding-top:12px; padding-bottom:10px; text-align: right; font-weight: 600; font-size: 20px; font-family: &#39;Open Sans&#39;, sans-serif;\">".as_bytes() };
global TOTAL_BILLED_HTML_POSTFIX: [u8; TOTAL_BILLED_POSTFIX_LENGTH] = comptime { " USD</td>".as_bytes() };

global ARRIVAL_DATE_PREFIX_LENGTH = 195;
global ARRIVAL_DATE_POSTFIX_LENGTH = 5;
global ARRIVAL_DATE_HTML_PREFIX: [u8; ARRIVAL_DATE_PREFIX_LENGTH] = comptime { "2nd bag weight and dimensions</td></tr><tr><td style=3D\"font-family: &#39;Open Sans&#39;, sans-serif; text-align: left; font-size: 12px; padding-bottom:5px; padding-top: 5px; padding-left:10px;\">".as_bytes() };
global ARRIVAL_DATE_HTML_POSTFIX: [u8; ARRIVAL_DATE_POSTFIX_LENGTH] = comptime { "<br/>".as_bytes() };

global DEST_AIRPORT_PREFIX_LENGTH = 5;
global DEST_AIPORT_POSTFIX_LENGTH = 5;
global DEST_AIRPORT_HTML_PREFIX: [u8; DEST_AIRPORT_PREFIX_LENGTH] = comptime { "<br/>".as_bytes() };
global DEST_AIRPORT_HTML_POSTFIX: [u8; DEST_AIPORT_POSTFIX_LENGTH] = comptime { "</td>".as_bytes() };

global MAX_AMOUNT_SEQUENCE_LENGTH = MAX_BILLED_AMOUNT + TOTAL_BILLED_POSTFIX_LENGTH + TOTAL_BILLED_PREFIX_LENGTH;
global MAX_DATETIME_SEQUENCE_LENGTH = DATE_LENGTH + ARRIVAL_DATE_PREFIX_LENGTH + ARRIVAL_DATE_POSTFIX_LENGTH + 1;// todo: where is the +1 from
global MAX_DEST_SEQUENCE_LENGTH = MAX_DEST_AIRPORT_LENGTH + DEST_AIPORT_POSTFIX_LENGTH + DEST_AIRPORT_PREFIX_LENGTH;

global AMOUNT_SELECTION_LENGTH: u32 = 256;
global DATE_AIRPORT_SELECTION_LENGTH: u32 = 320;

struct UnitedBillingParams {
    header: BoundedVec<u8, MAX_UNITED_EMAIL_HEADER_LENGTH>,
    pubkey: RSAPubkey<KEY_LIMBS_2048>,
    signature: [Field; KEY_LIMBS_2048],
    dkim_header_sequence: Sequence,
    body_hash_index: u32,
    from_index: u32,
    subject_index: u32,
    amount_sequence: Sequence,
    date_sequence: Sequence,
    airport_sequence: Sequence,
    // hash state precomputed up to amount selection
    partial_body_hash: [u32; 8],
    body_amount_selection: [u8; AMOUNT_SELECTION_LENGTH],
    // hash state to date/ destination selection
    partial_body_hash_date: [u32; 8],
    body_date_selection: [u8; DATE_AIRPORT_SELECTION_LENGTH]
}

#[derive(Serialize)]
struct UnitedBillingParamsContract {
	header: [u8; MAX_UNITED_EMAIL_HEADER_LENGTH],
	header_length: u32,
	pubkey_modulus: [Field; KEY_LIMBS_2048],
	pubkey_redc: [Field; KEY_LIMBS_2048],
	signature: [Field; KEY_LIMBS_2048],
	dkim_header_sequence: Sequence,
	body_hash_index: u32,
	from_index: u32,
	subject_index: u32,
	amount_sequence: Sequence,
	date_sequence: Sequence,
    airport_sequence: Sequence,
    partial_body_hash: [u32; 8],
    body_amount_selection: [u8; AMOUNT_SELECTION_LENGTH],
    partial_body_hash_date: [u32; 8],
    body_date_selection: [u8; DATE_AIRPORT_SELECTION_LENGTH]
}

/** Contract function params incapable of serializing BoundedVec or RSAPubkey types */
impl UnitedBillingParamsContract {
	fn unmarshal(params: UnitedBillingParams) -> Self {
		Self {
			header: params.header.storage,
			header_length: params.header.len,
			pubkey_modulus: params.pubkey.modulus,
			pubkey_redc: params.pubkey.redc,
			signature: params.signature,
			dkim_header_sequence: params.dkim_header_sequence,
			body_hash_index: params.body_hash_index,
			from_index: params.from_index,
			subject_index: params.subject_index,
			amount_sequence: params.amount_sequence,
            date_sequence: params.date_sequence,
            airport_sequence: params.airport_sequence,
            partial_body_hash: params.partial_body_hash,
            body_amount_selection: params.body_amount_selection,
            partial_body_hash_date: params.partial_body_hash_date,
            body_date_selection: params.body_date_selection
		}
	}

	fn marshal(self) -> UnitedBillingParams {

		// check that header sequence falls within specified length
		for i in 0..MAX_UNITED_EMAIL_HEADER_LENGTH {
			assert((i < self.header_length) | (self.header[i] == 0), "Header exceeds specified length");
		}

		UnitedBillingParams {
			header: BoundedVec { storage: self.header, len: self.header_length },
			pubkey: RSAPubkey { modulus: self.pubkey_modulus, redc: self.pubkey_redc },
			signature: self.signature,
			dkim_header_sequence: self.dkim_header_sequence,
			body_hash_index: self.body_hash_index,
			from_index: self.from_index,
			subject_index: self.subject_index,
			amount_sequence: self.amount_sequence,
            date_sequence: self.date_sequence,
            airport_sequence: self.airport_sequence,
            partial_body_hash: self.partial_body_hash,
            body_amount_selection: self.body_amount_selection,
            partial_body_hash_date: self.partial_body_hash_date,
            body_date_selection: self.body_date_selection
		}
	}
}
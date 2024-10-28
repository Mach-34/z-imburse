use zkemail::{KEY_LIMBS_2048, Sequence, dkim::RSAPubkey};
use std::meta::derive;
use aztec::protocol_types::traits::Serialize;
global MAX_LINODE_EMAIL_BODY_LENGTH: u32 = 832;
global MAX_LINODE_EMAIL_HEADER_LENGTH: u32 = 640;

// expected sequence for the sender in an email body for Linode billing receipt
// "F/f" is omitted to facilitate case insensitivity
// "rom:billing@linode.com"
global LB_FROM_LEN = 22;
global LINODE_BILLING_FROM: str<LB_FROM_LEN> = "rom:billing@linode.com";

// expected sequence in the subject of an email header for Linode billing receipt
// "S/s" is omitted to facilitate case insensitivity
// "ubject: Linode.com: Payment Receipt"
global LB_SUBJECT_FIXED_START_LEN = 36;
global LB_SUBJECT_FIXED_END_LEN = 3;
global LINODE_BILLING_SUBJECT_FIXED_START: str<LB_SUBJECT_FIXED_START_LEN> = "ubject:Linode.com: Payment Receipt ["; 
global LINODE_BILLING_SUBJECT_FIXED_END: str<LB_SUBJECT_FIXED_END_LEN> = "]\r\n";

// expected sequence preceding the billed amount in a Linode billing receipt email
// NOTE: Hardcoded to accept 'credit card' as only payment method for now although there may be variation
global LB_PAYMENT_TEXT_LEN = 76;
global LINODE_BILLING_PAYMENT_TEXT: str<LB_PAYMENT_TEXT_LEN> = "This is your receipt of payment against your credit card in the \r\namount of ";

// assuming a unlikely max billed amount of "$9,999,999.99"
global MAX_BILLED_AMOUNT = 13;

struct LinodeBillingParams {
    header: BoundedVec<u8, MAX_LINODE_EMAIL_HEADER_LENGTH>,
    body: BoundedVec<u8, MAX_LINODE_EMAIL_BODY_LENGTH>,
    pubkey: RSAPubkey<KEY_LIMBS_2048>,
    signature: [Field; KEY_LIMBS_2048],
    dkim_header_sequence: Sequence,
    body_hash_index: u32,
    from_index: u32,
    subject_index: u32,
    amount_sequence: Sequence,
    date_index: u32,
    receipt_id_length: u32
}

#[derive(Serialize)]
struct LinodeBillingParamsContract {
	header: [u8; MAX_LINODE_EMAIL_HEADER_LENGTH],
	header_length: u32,
	pubkey_modulus: [Field; KEY_LIMBS_2048],
	pubkey_redc: [Field; KEY_LIMBS_2048],
	signature: [Field; KEY_LIMBS_2048],
	dkim_header_sequence: Sequence,
	body: [u8; MAX_LINODE_EMAIL_BODY_LENGTH],
	body_length: u32,
	body_hash_index: u32,
	from_index: u32,
	subject_index: u32,
	amount_sequence: Sequence,
	date_index: u32,
	receipt_id_length: u32
}

/** Contract function params incapable of serializing BoundedVec or RSAPubkey types */
impl LinodeBillingParamsContract {
	fn unmarshal(params: LinodeBillingParams) -> Self {
		Self {
			header: params.header.storage,
			header_length: params.header.len,
			pubkey_modulus: params.pubkey.modulus,
			pubkey_redc: params.pubkey.redc,
			signature: params.signature,
			dkim_header_sequence: params.dkim_header_sequence,
			body: params.body.storage,
			body_length: params.body.len,
			body_hash_index: params.body_hash_index,
			from_index: params.from_index,
			subject_index: params.subject_index,
			amount_sequence: params.amount_sequence,
			date_index: params.date_index,
			receipt_id_length: params.receipt_id_length
		}
	}

	fn marshal(self) -> LinodeBillingParams {
		LinodeBillingParams {
			header: BoundedVec { storage: self.header, len: self.header_length },
			pubkey: RSAPubkey { modulus: self.pubkey_modulus, redc: self.pubkey_redc },
			signature: self.signature,
			dkim_header_sequence: self.dkim_header_sequence,
			body: BoundedVec { storage: self.body, len: self.body_length },
			body_hash_index: self.body_hash_index,
			from_index: self.from_index,
			subject_index: self.subject_index,
			amount_sequence: self.amount_sequence,
			date_index: self.date_index,
			receipt_id_length: self.receipt_id_length
		}
	}
}
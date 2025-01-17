import { generateEmailVerifierInputsFromDKIMResult, verifyDKIMSignature } from "@zk-email/zkemail-nr";
import { getSequenceParams } from "./location";
import { Regexes } from "../constants";
import { LinodeInputs, RedeemLinodeInputs } from "../types";
import { base } from "viem/chains";

const LINODE_MAX_HEADER_LENGTH = 640;
const LINODE_MAX_BODY_LENGTH = 832;

/**
 * Calculates the length of the receipt id in the subject
 */
const calculateReceiptIdLength = (subjectSlice: string) => {
  if (!subjectSlice.includes("Linode.com: Payment Receipt")) {
    throw Error("Missing payment receipt subject");
  }

  const openingBracketIdx = subjectSlice.indexOf("[");
  const closingBracketIdx = subjectSlice.indexOf("]");
  return closingBracketIdx - openingBracketIdx;
};

// /**
//  * Transform Linode circuit inputs into format acceptable by aztec
//  * @param inputs - Linode inputs that are witcalc friendly but not readable by contract
//  */
export const formatRedeemLinode = (
  inputs: LinodeInputs
): RedeemLinodeInputs => {
  // body will be present in this email type
  const header = inputs.header.storage.map((byte) => Number(byte));
  const body = inputs.body?.storage.map((byte) => Number(byte));
  const pubkey_modulus = inputs.pubkey.modulus.map((limb) => BigInt(limb));
  const pubkey_redc = inputs.pubkey.redc.map((limb) => BigInt(limb));
  const signature = inputs.signature.map((limb) => BigInt(limb));

  return {
    header: header,
    header_length: Number(inputs.header.len),
    pubkey_modulus,
    pubkey_redc,
    signature,
    dkim_header_sequence: {
      index: Number(inputs.dkim_header_sequence.index),
      length: Number(inputs.dkim_header_sequence.length),
    },
    body: body as number[],
    body_length: Number(inputs.body?.len),
    body_hash_index: Number(inputs.body_hash_index),
    from_index: inputs.from_index,
    subject_index: inputs.subject_index,
    amount_index: inputs.amount_index,
    date_index: inputs.date_index,
    receipt_id_length: inputs.receipt_id_length,
  }
};

/**
 * Given an email, generate the inputs for the Linode billing receipt proof
 * @param email - the email to generate the inputs
 */
export const makeLinodeInputs = async (
  email: Buffer
): Promise<LinodeInputs> => {
  const dkimResult = await verifyDKIMSignature(email);
  const baseInputs = generateEmailVerifierInputsFromDKIMResult(dkimResult, {
    maxHeadersLength: LINODE_MAX_HEADER_LENGTH,
    maxBodyLength: LINODE_MAX_BODY_LENGTH,
  });

  // grab sequence params from the email
  const header = dkimResult.headers.toString();
  const fromParams = getSequenceParams(Regexes.from, header);
  if (fromParams === null) throw new Error("No 'from' field found in email");

  // extract the index and length of the subject field
  const subjectParams = getSequenceParams(Regexes.subject, header);
  if (subjectParams === null)
    throw new Error("No 'subject' field found in email");
  const body = dkimResult.body.toString();

  // match the billed amount in the email body
  const billMatch = body.match(Regexes.linodeBilledAmount);
  if (billMatch === null) {
    throw Error("No 'amount' could be extracted from body");
  }

  // get the index of the date field
  let dateIndex = body.indexOf("Payment Date: ");
  if (dateIndex === -1) {
    throw Error("No 'Payment Date' field found in email body");
  }
  dateIndex = dateIndex + "Payment Date: ".length;

  const { length: subjectLen, index: subjectIndex } = subjectParams;
  const receipt_id_length = calculateReceiptIdLength(
    header.slice(subjectIndex, subjectIndex + subjectLen)
  );

  // todo: fix
  if (baseInputs.body!.storage.length !== LINODE_MAX_BODY_LENGTH) {
    baseInputs.body!.storage = baseInputs.body!.storage.slice(0, LINODE_MAX_BODY_LENGTH);
  }

  const inputs = {
    ...baseInputs,
    header: {
      storage: baseInputs.header.storage.fill('0', Number(baseInputs.header.len)),
      len: baseInputs.header.len
    },
    amount_index: billMatch.index as number,
    from_index: fromParams.index,
    subject_index: subjectParams.index,
    date_index: dateIndex,
    receipt_id_length,
  };
  return inputs;
};

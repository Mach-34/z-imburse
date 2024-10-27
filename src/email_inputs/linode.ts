import { verifyDKIMSignature } from "@zk-email/helpers/dist/dkim";
import { generateEmailVerifierInputsFromDKIMResult } from "@zk-email/zkemail-nr";
import { getSequenceParams } from "./location";
import { Regexes } from "../constants";
import { LinodeInputs } from "../types";

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
// export const formatRedeemLinode = (
//   inputs: LinodeInputs
// ): RedeemLinodeInputs => {
//   // body will be present in this email type
//   const body = inputs.body!.map((byte) => Number(byte));
//   const header = inputs.header.map((byte) => Number(byte));
//   const pubkey = inputs.pubkey.map((limb) => BigInt(limb));
//   const pubkey_redc = inputs.pubkey_redc.map((limb) => BigInt(limb));
//   const signature = inputs.signature.map((limb) => BigInt(limb));
//   return [
//     body,
//     Number(inputs.body_hash_index),
//     Number(inputs.body_length),
//     header,
//     Number(inputs.header_length),
//     pubkey,
//     pubkey_redc,
//     signature,
//     inputs.from_index,
//     inputs.subject_index,
//     inputs.amount_index,
//     inputs.amount_length,
//     inputs.date_index,
//     inputs.receipt_id_length,
//   ];
// };

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

  // extract the index of the date field
  const dateField = Regexes.date.exec(header);
  if (dateField === null) throw new Error("No 'date' field found in email");

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
    amount_sequence: {
      index: billMatch.index as number,
      length: billMatch[0].length
    },
    from_index: fromParams.index,
    subject_index: subjectParams.index,
    date_index: dateField.index,
    receipt_id_length,
  };
  return inputs;
};

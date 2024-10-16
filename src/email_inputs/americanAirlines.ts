import { verifyDKIMSignature } from "@zk-email/helpers/dist/dkim";
import { generateEmailVerifierInputsFromDKIMResult } from "@mach-34/zkemail-nr";
import { getSequenceParams } from "./location";
import { Regexes } from "../constants";
import { AmericanAirlinesInputs } from "../types";

// const AA_MAX_HEADER_LENGTH = 640;
const AA_MAX_BODY_LENGTH = 81856;

/**
 * Calculate the indices related to total cost in an American Airlines email 
 * 
 * @param body 
 */
export const calculateTotalCostIndices = (body: string) => {
    const totalCostIndex = body.indexOf('Total cost');
    const trStartIndex = body.lastIndexOf('<tr>', totalCostIndex);
    const spanLabelStartIndex = body.lastIndexOf('<span', totalCostIndex);
    const tdLabelLength = (spanLabelStartIndex - 3) - (trStartIndex + 7);
    const spanLabelLength = totalCostIndex - 1 - spanLabelStartIndex;
    const tdCostStartIndex = body.indexOf('<td', totalCostIndex);
    const tdCostStartCloseIndex = body.indexOf('>', tdCostStartIndex);
    const tdCostLength = tdCostStartCloseIndex - tdCostStartIndex;
    const tdCostEndIndex = body.indexOf('</td>', tdCostStartCloseIndex);
    const amountLength = tdCostEndIndex - (tdCostStartCloseIndex + 1)

    const start = tdCostStartCloseIndex + 1;
    const end = start + amountLength;

    return { trStartIndex, tdLabelLength, spanLabelLength, tdCostLength, amountLength }
}

/**
 * Given an email, generate the inputs for the American Airlines receipt proof
 * @param email - the Uber ride receipt email to generate the inputs for
 */
export const makeAAInputs = async (
    email: Buffer
): Promise<AmericanAirlinesInputs> => {
    const dkimResult = await verifyDKIMSignature(email);
    const baseInputs = generateEmailVerifierInputsFromDKIMResult(dkimResult, { maxBodyLength: AA_MAX_BODY_LENGTH });

    // grab sequence params from the email
    const header = dkimResult.headers.toString();
    const fromParams = getSequenceParams(Regexes.from, header);
    if (fromParams === null) throw new Error("No 'from' field found in email");

    // extract the index and length of the subject field
    const subjectParams = getSequenceParams(Regexes.subject, header);
    if (subjectParams === null)
        throw new Error("No 'subject' field found in email");

    const totalCostIndices = calculateTotalCostIndices(dkimResult.body.toString());

    // // match the billed amount in the email body
    // const billMatch = body.match(Regexes.linodeBilledAmount);
    // if (billMatch === null) {
    //     throw Error("No 'amount' could be extracted from body");
    // }

    // const { length: subjectLen, index: subjectIndex } = subjectParams;
    // const receipt_id_length = calculateReceiptIdLength(
    //     header.slice(subjectIndex, subjectIndex + subjectLen)
    // );

    // // need to fix in zkemail.nr
    // if (baseInputs.body!.length > LINODE_MAX_BODY_LENGTH) {
    //     baseInputs.body = baseInputs.body!.slice(0, LINODE_MAX_BODY_LENGTH);
    // }

    const inputs = {
        ...baseInputs,
        from_index: fromParams.index,
        subject_index: subjectParams.index,
        total_cost_indices: Object.values(totalCostIndices)
    };
    return inputs
};
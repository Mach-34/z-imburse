import { verifyDKIMSignature } from "@zk-email/helpers/dist/dkim";
import { generateEmailVerifierInputsFromDKIMResult } from '@mach-34/zkemail-nr';
import { getSequenceParams } from "./location";
import { Regexes } from "../constants";

const UNITED_MAX_HEADER_LENGTH = 640;
const UNITED_MAX_BODY_LENGTH = 58560;

/**
 * 
 */
export const calculatePurchaseSummaryIndices = (body: Buffer) => {
    const bodyStr = body.toString();
    // Find start of purchase summary index in table
    const totalIndex = bodyStr.indexOf('Total:');

    // calculate start and index index of table data section containting "Total:"
    const totalLabelDataTagStartClosing = totalIndex - 1;
    const totalLabelDataTagStartOpening = bodyStr.lastIndexOf(`<=\r\ntd`, totalLabelDataTagStartClosing);
    const totalLabelDataTagStartLen = totalLabelDataTagStartClosing - totalLabelDataTagStartOpening;

    // calculate start and end index of "Total" row tag
    const totalRowTagStartClosing = totalLabelDataTagStartOpening - 1;
    const totalRowTagStartOpening = bodyStr.lastIndexOf("<tr", totalRowTagStartClosing);
    const totalRowTagStartLen = totalRowTagStartClosing - totalRowTagStartOpening;

    const totalAmountDataTagStartOpening = totalIndex + "Total:</td>".length;
    const totalAmountDataTagStartClosing = bodyStr.indexOf(">", totalAmountDataTagStartOpening);
    const totalAmountDataTagStartLength = totalAmountDataTagStartClosing - totalAmountDataTagStartOpening;

    const totalAmountStart = totalAmountDataTagStartClosing + 1;
    const totalAmountEnd = bodyStr.indexOf(" ", totalAmountStart);
    const totalAmountLength = totalAmountEnd - totalAmountStart;

    return {
        totalRowTagStartOpening,
        totalRowTagStartLen,
        totalLabelDataTagStartLen,
        totalAmountDataTagStartLength,
        totalAmountLength
    }
}

/**
 * Given an email, generate the inputs for the United receipt proof
 * @param email - the United flight receipt email to generate the inputs for
 */
export const makeUnitedInputs = async (
    email: Buffer
): Promise<any> => {
    const dkimResult = await verifyDKIMSignature(email);
    const baseInputs = generateEmailVerifierInputsFromDKIMResult(dkimResult, { maxBodyLength: UNITED_MAX_BODY_LENGTH, maxHeadersLength: UNITED_MAX_HEADER_LENGTH });
    // grab sequence params from the email
    const header = dkimResult.headers.toString();
    const fromParams = getSequenceParams(Regexes.from, header);
    if (fromParams === null) throw new Error("No 'from' field found in email");

    // extract the index and length of the subject field
    const subjectParams = getSequenceParams(Regexes.subject, header);
    if (subjectParams === null)
        throw new Error("No 'subject' field found in email");

    const purchaseSummaryIndices = calculatePurchaseSummaryIndices(dkimResult.body);

    const inputs = {
        ...baseInputs,
        from_index: fromParams.index,
        subject_index: subjectParams.index,
        purchase_summary_indices: Object.values(purchaseSummaryIndices)
    };
    return inputs;
};
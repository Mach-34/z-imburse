import { verifyDKIMSignature } from "@zk-email/helpers/dist/dkim";
import { generateEmailVerifierInputsFromDKIMResult } from "@mach-34/zkemail-nr";
import { getSequenceParams } from "./location";
import { Regexes } from "../constants";
import { FrontierInputs } from "../types";

// const FRONTIER_MAX_HEADER_LENGTH = 640;
const FRONTIER_MAX_BODY_LENGTH = 186560;

/**
 * Quoted printable linebreaks are not of concern here as they appear non-random
 * 
 * @param body 
 */
export const calculatePurchaseTotalIndices = (body: Buffer) => {
    const bodyStr = body.toString();

    // calculate start and index index of table data section containting "Grand Total"
    const grandTotalIndex = bodyStr.indexOf('Grand Total')
    const tdLabelStartClosingIndex = grandTotalIndex - 1;
    const rowStartIndex = bodyStr.lastIndexOf('<tr>', tdLabelStartClosingIndex);
    const tdLabelStartOpeningIndex = bodyStr.indexOf('<td', rowStartIndex);
    const tdLabelLen = tdLabelStartClosingIndex - tdLabelStartOpeningIndex;

    const tdAmountStartIndex = bodyStr.indexOf('<td', grandTotalIndex);
    const tdAmountEndIndex = bodyStr.indexOf('>', tdAmountStartIndex);
    const tdAmountLen = tdAmountEndIndex - tdAmountStartIndex;
    const tdAmountCloseIndex = bodyStr.indexOf('</td>', tdAmountEndIndex);

    let amountLen = tdAmountCloseIndex - tdAmountEndIndex - 2; // -2 for '>' and whitespace

    return {
        rowStartIndex,
        tdLabelLen,
        tdAmountLen,
        amountLen
    }
}

/**
 * Given an email, generate the inputs for the Frontier receipt proof
 * @param email - the Uber ride receipt email to generate the inputs for
 */
export const makeFrontierInputs = async (
    email: Buffer
): Promise<FrontierInputs> => {
    const dkimResult = await verifyDKIMSignature(email);
    const baseInputs = generateEmailVerifierInputsFromDKIMResult(dkimResult, {
        maxBodyLength: FRONTIER_MAX_BODY_LENGTH,
    });

    // grab sequence params from the email
    const header = dkimResult.headers.toString();
    const fromParams = getSequenceParams(Regexes.from, header);
    if (fromParams === null) throw new Error("No 'from' field found in email");

    // extract the index and length of the subject field
    const subjectParams = getSequenceParams(Regexes.subject, header);
    if (subjectParams === null)
        throw new Error("No 'subject' field found in email");

    const purchaseTotalIndices = calculatePurchaseTotalIndices(dkimResult.body);

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
        purchase_total_indices: Object.values(purchaseTotalIndices)
    };
    return inputs
};
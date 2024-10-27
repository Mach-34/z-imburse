import { verifyDKIMSignature } from "@zk-email/helpers/dist/dkim";
import { generateEmailVerifierInputsFromDKIMResult } from "@zk-email/zkemail-nr";
import { getSequenceParams } from "./location";
import { Regexes } from "../constants";
import { SequenceParams, UnitedInputs } from "../types";
import { decodeQuotedPrintable } from "../utils";

const UNITED_MAX_HEADER_LENGTH = 640;
const UNITED_MAX_BODY_LENGTH = 58560;

const getDateSequence = (emailBody: string) => {
    const dateHtmlPrefix = emailBody.indexOf('2nd bag weight and dimensions');
    const dateHtmlPostfix = emailBody.indexOf('<br/>', dateHtmlPrefix);
    const length = dateHtmlPostfix + 5 - dateHtmlPrefix;
    return { index: dateHtmlPrefix, length } as SequenceParams
}

const getDestinationAirportSequence = (emailBody: string) => {
    const dateHtmlPrefix = emailBody.indexOf('2nd bag weight and dimensions');
    const dateHtmlPostfix = emailBody.indexOf('<br/>', dateHtmlPrefix);
    const destinationPrefix = emailBody.indexOf('<br/>', dateHtmlPostfix);
    const destinationPostfix = emailBody.indexOf('</td>', destinationPrefix);
    const length = destinationPostfix + 5 - destinationPrefix;
    return { index: destinationPrefix, length } as SequenceParams
}

/**
 * Given an email, generate the inputs for the United receipt proof
 * @param email - the United flight receipt email to generate the inputs for
 */
export const makeUnitedInputs = async (
    email: Buffer
): Promise<UnitedInputs> => {
    const dkimResult = await verifyDKIMSignature(email);
    const baseInputs = generateEmailVerifierInputsFromDKIMResult(dkimResult, {
        maxBodyLength: UNITED_MAX_BODY_LENGTH,
        maxHeadersLength: UNITED_MAX_HEADER_LENGTH,
        // shaPrecomputeSelector: 'Total:'
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
    const totalParams = getSequenceParams(Regexes.unitedTotal, body);
    if (totalParams === null) throw new Error("No 'Total' found in email");

    const dateParams = getDateSequence(body);
    const airportParams = getDestinationAirportSequence(body);

    const inputs = {
        ...baseInputs,
        from_index: fromParams.index,
        subject_index: subjectParams.index,
        amount_sequence: totalParams,
        date_sequence: dateParams,
        airport_sequence: airportParams
    };
    return inputs;
};
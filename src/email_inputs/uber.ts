import { verifyDKIMSignature } from "@zk-email/helpers/dist/dkim";
import { generateEmailVerifierInputsFromDKIMResult } from "@mach-34/zkemail-nr";

const UBER_MAX_HEADER_LENGTH = 640;
const UBER_MAX_BODY_LENGTH = 832;


/**
 * Given an email, generate the inputs for the Uber receipt proof
 * @param email - the Uber ride receipt email to generate the inputs for
 */
export const makeUberInputs = async (
    email: Buffer
): Promise<object> => {
    const dkimResult = await verifyDKIMSignature(email);
    console.log('DKIM result: ', dkimResult);
    // const baseInputs = generateEmailVerifierInputsFromDKIMResult(dkimResult, {
    //     // maxHeadersLength: LINODE_MAX_HEADER_LENGTH,
    //     // maxBodyLength: LINODE_MAX_BODY_LENGTH,
    // });

    // // grab sequence params from the email
    // const header = dkimResult.headers.toString();
    // const fromParams = getSequenceParams(Regexes.from, header);
    // if (fromParams === null) throw new Error("No 'from' field found in email");

    // // extract the index of the date field
    // const dateField = Regexes.date.exec(header);
    // if (dateField === null) throw new Error("No 'date' field found in email");

    // // extract the index and length of the subject field
    // const subjectParams = getSequenceParams(Regexes.subject, header);
    // if (subjectParams === null)
    //     throw new Error("No 'subject' field found in email");
    // const body = dkimResult.body.toString();

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

    // const inputs = {
    //     ...baseInputs,
    //     amount_index: billMatch.index as number,
    //     amount_length: billMatch[0].length,
    //     from_index: fromParams.index,
    //     subject_index: subjectParams.index,
    //     date_index: dateField.index,
    //     receipt_id_length,
    // };
    return {};
};
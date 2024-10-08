import {
    verifyDKIMSignature,
} from "@zk-email/helpers/dist/dkim/index.js";
import { generateEmailVerifierInputsFromDKIMResult } from '@mach-34/zkemail-nr';

/**
 * Given an email, generate the inputs for the ownership proof
 * @param email - the email to generate the ownership proof for
 */
export const makeHerokuInputs = async (email: Buffer) => {
    const dkimResult = await verifyDKIMSignature(email);
    const baseInputs = generateEmailVerifierInputsFromDKIMResult(
        dkimResult,
        {
            maxBodyLength: 12224,
            // maxHeadersLength: 960,
        }
    );
    return baseInputs
}

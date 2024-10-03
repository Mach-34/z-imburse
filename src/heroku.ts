import {
    verifyDKIMSignature,
} from "@zk-email/helpers/dist/dkim/index.js";
import { generateEmailVerifierInputsFromDKIMResult, toNoirInputs } from '@mach-34/zkemail-nr';

/**
 * Given an email, generate the inputs for the ownership proof
 * @param email - the email to generate the ownership proof for
 */
export const makeHerokuInputs = async (email: Buffer) => {
    const dkimResult = await verifyDKIMSignature(email);
    const unformattedInputs = generateEmailVerifierInputsFromDKIMResult(
        dkimResult,
        {
            maxBodyLength: 12224,
            // maxHeadersLength: 960,
        }
    );
    const baseInputs = toNoirInputs(unformattedInputs);
    return baseInputs
}

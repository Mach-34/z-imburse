import { generateEmailVerifierInputsFromDKIMResult, verifyDKIMSignature } from "@zk-email/zkemail-nr";

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

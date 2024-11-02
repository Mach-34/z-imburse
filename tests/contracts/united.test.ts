import { describe, expect, jest } from "@jest/globals";
import {
    createAccount,
} from "@aztec/accounts/testing";
import {
    AccountWalletWithSecretKey,
    Fr,
    createPXEClient,
} from "@aztec/aztec.js";
import {

    ZImburseEscrowContract,
} from "../../src/artifacts/contracts/index";
import {
    makeUnitedInputs,
    toContractFriendly
} from "../../src/email_inputs/united";
import { emails } from "../utils/fs";
import { generateEmailVerifierInputs } from "@zk-email/zkemail-nr";


const DEFAULT_PXE_URL = "http://localhost";

jest.setTimeout(1000000);

export function padZeroes(data: number[], maxLength: number): number[] {
    console.log("Length: ", data.length);
    console.log("Max length: ", maxLength);
    if (data.length > maxLength) throw new Error('Data length must be less than maxLength');
    return data.concat(Array(maxLength - data.length).fill(0));
}

const MAX_CHUNK_SIZE = 2048;

/**
 * Breaks u8 array into capsules
 * @param data - the data to break into capsules
 * @returns the capsules in order to insert
 */
export function breakIntoCapsules(data: number[], chunkSize?: number): Fr[][] {
    if (!chunkSize) chunkSize = MAX_CHUNK_SIZE;
    // pad to maxLength
    const chunks: Fr[][] = [];
    for (let i = 0; i < data.length; i += chunkSize) {
        const endIndex = i + chunkSize <= data.length ? i + chunkSize : data.length;
        let chunk = data.slice(i, endIndex);
        if (chunk.length < chunkSize) {
            chunk = chunk.concat(Array(chunkSize - chunk.length).fill(0));
        }
        // chunks.push(data.slice(i, i + MAX_CHUNK_SIZE).map((x) => parseInt(x)));
        chunks.push(chunk.map(x => new Fr(x)));
    }
    return chunks.reverse();
}

describe("Test deposit to zimburse", () => {
    let admin: AccountWalletWithSecretKey;
    let claimant: AccountWalletWithSecretKey;
    let escrow: ZImburseEscrowContract;

    beforeAll(async () => {
        // setup pxe connection
        const sandboxPXE = await createPXEClient(`${DEFAULT_PXE_URL}:8080`);

        // console.log(
        //   `Connected to Sandbox & 4 PXE's at "${DEFAULT_PXE_URL}:[8080-8083]"\n`
        // );

        // deploy test accounts
        admin = await createAccount(sandboxPXE);
        claimant = await createAccount(sandboxPXE);


        // deploy contracts
        escrow = await ZImburseEscrowContract.deploy(
            admin,
            admin.getAddress(),
            admin.getAddress(),
            `Escrow`
        )
            .send()
            .deployed();
    });

    describe("Test Partial Hash", () => {
        it("Try partial hashing stuff", async () => {
            // generate inputs
            const { inputs: unitedInputs, deferred } = await makeUnitedInputs(emails.united);
            const contractInputs = toContractFriendly(unitedInputs);
            const amountToDateLength: number = deferred.amountToDateBody.length;
            const remainingLength: number = deferred.remainingBody.length;


            // add capsules to pxe
            let capsules = breakIntoCapsules(deferred.remainingBody.map((val: string) => parseInt(val)));
            for (const capsule of capsules)
                await claimant.addCapsule(capsule);
            capsules = breakIntoCapsules(deferred.amountToDateBody.map((val: string) => parseInt(val)));
            for (const capsule of capsules)
                await claimant.addCapsule(capsule);

            let start = new Date().getTime();
            await escrow.methods.united_test(
                contractInputs,
                amountToDateLength,
                remainingLength,
                deferred.actualLength
            ).send().wait();
            let end = new Date().getTime();
            console.log("Time taken: ", end - start);
        })
    });
});

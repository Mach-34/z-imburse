import { describe, expect, jest } from "@jest/globals";

import { ZKEmailProver } from "@mach-34/zkemail-nr/dist/prover"
import { readFileSync } from 'fs'
import { BarretenbergSync } from "@aztec/bb.js";
import { join } from 'path';
import { makeLinodeInputs } from '../../src/linode';
import LinodeCircuit from '../../src/circuits/linode_email_verifier.json';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);


const emails = {
    linode: readFileSync(join(__dirname, "test-data/linode.eml")),
};

describe("Linode Billing Receipt Test", () => {
    let prover: ZKEmailProver;
    jest.setTimeout(1000000);
    beforeAll(async () => {
        //@ts-ignore
        prover = new ZKEmailProver(LinodeCircuit, 'all');
    });
    afterAll(async () => {
        await prover.destroy();
    })

    describe("Simulated", () => {
        it("Linode::September2024", async () => {
            const inputs = await makeLinodeInputs(emails.linode);
            let dateField = inputs.header.map((x: string) => parseInt(x));
            console.log("HEader ", JSON.stringify(dateField));
            // const { witness, returnValue } = await prover.simulateWitness({ params: inputs });
            // console.log(returnValue);
        })
    })

    xdescribe("Proving", () => {
        it("Linode::Honk", async () => {
            // make inputs from email
            const inputs = await makeLinodeInputs(emails.linode);
            // generate proof
            const proof = await prover.fullProve(inputs, 'honk');
            // verify proof
            const result = await prover.verify(proof);
            expect(result).toBeTruthy();
            
        });

        it("Linode::Plonk", async () => {
            // make inputs from email
            const inputs = await makeLinodeInputs(emails.linode);
            // generate proof
            const proof = await prover.fullProve(inputs, 'plonk');
            // verify proof
            const result = await prover.verify(proof);
            expect(result).toBeTruthy();
            expect(BigInt(proof.publicInputs[0])).toEqual(2200n);
             // todo: date parser output test
            // todo: match expected key
        });
    })

    // describe("Proving", () => {
    //     it("Linode::Honk", async () => {
    //         // make inputs from email
    //         const inputs = await makeLinodeInputs(emails.linode);
    //         // execute witness
    //         const { witness } = await prover.noir.execute({ params: inputs });
    //         // prove with witness
    //         const proof = await prover.ultraHonk.generateProof(witness);
    //         // verify proof
    //         const result = await prover.ultraHonk.verifyProof(proof);
    //         expect(result).toBeTruthy();

    //         // expect(BigInt(proof.publicInputs[0])).toEqual(2200n)
    //         // todo: date parser output test
    //         // todo: match expected key
    //     });

    //     xit("Linode::Plonk", async () => {
    //         // make inputs from email
    //         const inputs = await makeLinodeInputs(emails.linode);
    //         inputs.body = inputs.body.slice(0, Number(inputs.body_length));
    //         // execute witness
    //         const { witness } = await prover.noir.execute({ params: inputs });
    //         // prove with witness
    //         const proof = await prover.barretenberg.generateProof(witness);
    //         // verify proof
    //         const result = await prover.barretenberg.verifyProof(proof);
    //         expect(result).toBeTruthy();

    //         expect(BigInt(proof.publicInputs[0])).toEqual(2200n)
    //     });
    // })
})
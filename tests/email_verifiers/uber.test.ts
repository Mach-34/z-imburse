import { describe, expect, jest } from "@jest/globals";

import { ZKEmailProver } from "@mach-34/zkemail-nr/dist/prover"
import { readFileSync } from 'fs'
import { join } from 'path';
import { makeUberInputs } from '../../src/uber';
import UberCircuit from '../../src/circuits/uber_email_verifier.json';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const emails = {
    uber: readFileSync(join(__dirname, "test-data/american-airlines.eml")),
};

describe("Uber Receipt Test", () => {
    let prover: ZKEmailProver;
    jest.setTimeout(1000000);
    beforeAll(async () => {
        //@ts-ignore
        prover = new ZKEmailProver(UberCircuit, 'all');
    });
    afterAll(async () => {
        await prover.destroy();
    })

    describe("Proving", () => {
        it("Uber::Honk", async () => {
            // make inputs from email
            const inputs = await makeUberInputs(emails.uber);
            // generate proof
            // const proof = await prover.fullProve({ params: inputs }, 'honk');
            // // verify proof
            // const result = await prover.verify(proof, 'honk');

        });

        // xit("Uber::Plonk", async () => {
        //     // make inputs from email
        //     const inputs = await makeLinodeInputs(emails.uber);
        //     // generate proof
        //     const proof = await prover.fullProve({ params: inputs }, 'plonk');
        //     // verify proof
        //     const result = await prover.verify(proof, 'honk');
        //     expect(result).toBeTruthy();
        // });
    })
})
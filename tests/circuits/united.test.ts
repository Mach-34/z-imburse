import { describe, expect, jest } from "@jest/globals";
import { ZKEmailProver } from "@mach-34/zkemail-nr/dist/prover"
import { makeUnitedInputs } from '../../src/email_inputs/united';
import UnitedCircuit from '../../src/artifacts/circuits/united_email_verifier.json';
import { toBigIntBE } from '../../src/utils';
import { emails } from '../utils/fs';


describe("United Flight Receipt Test", () => {
    let prover: ZKEmailProver;
    jest.setTimeout(1000000);
    beforeAll(async () => {
        //@ts-ignore
        prover = new ZKEmailProver(UnitedCircuit, 'all');
    });
    afterAll(async () => {
        await prover.destroy();
    })

    describe("Simulated", () => {
        it("United", async () => {
            // build inputs
            const inputs = await makeUnitedInputs(emails.united);
            // simulate witness
            const { returnValue, witness } = await prover.simulateWitness(inputs);
            const values = (returnValue as string[]).map(x => toBigIntBE(new Uint8Array(Buffer.from(x.slice(2), 'hex'))));
            // check the returned values
            // expect(values[1]).toEqual(171785n);
            console.log('Values: ', values[1]);
        })
    })

    xdescribe("Proving", () => {
        it("United::Honk", async () => {
            // make inputs from email
            const inputs = await makeUnitedInputs(emails.united);
            console.log('Inputs: ', inputs)
            // generate proof
            const proof = await prover.fullProve({ params: inputs }, 'honk');
            // verify proof
            const result = await prover.verify(proof, 'honk');

        });

        it("United::Plonk", async () => {
            // make inputs from email
            const inputs = await makeUnitedInputs(emails.united);
            // generate proof
            const proof = await prover.fullProve({ params: inputs }, 'plonk');
            // verify proof
            const result = await prover.verify(proof, 'honk');
            expect(result).toBeTruthy();
        });
    })
})
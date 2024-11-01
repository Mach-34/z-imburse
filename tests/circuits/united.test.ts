import { describe, expect, jest } from "@jest/globals";
import { ZKEmailProver } from "@zk-email/zkemail-nr/dist/prover"
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
            // console.log("Body: ", JSON.stringify(inputs.body_date_selection));
            // console.log("Amount sequence: ", JSON.stringify(inputs.date_sequence));
            // console.log("Inputs", Object.keys(inputs));
            // simulate witness
            const { returnValue } = await prover.simulateWitness(inputs);
            // todo: better parsing
            const extractedValues = ((returnValue as any)[3] as string[]);
            console.log('Extracted Values: ', extractedValues);
            const parsedValues = extractedValues.map(x => toBigIntBE(new Uint8Array(Buffer.from(x.slice(2), 'hex'))));
            // // const destination = Buffer.from(values[3].toString(16), 'hex').toString('utf8')
            
            // // console.log('Destination: ', destination);
            // // check the returned values
            expect(parsedValues[0]).toEqual(171785n);

            console.log(`Billed amount: $${Number(parsedValues[1]) / 100}`);
            console.log(`Date of flight: ${(new Date(Number(parsedValues[1]) * 1000)).toUTCString()}`);
        })
    })

    xdescribe("Proving", () => {
        it("United::Honk", async () => {
            // make inputs from email
            const inputs = await makeUnitedInputs(emails.united);
            // generate proof
            const proof = await prover.fullProve(inputs, 'honk');
            // verify proof
            // const result = await prover.verify(proof, 'honk');

        });

        xit("United::Plonk", async () => {
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
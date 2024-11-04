import { describe, expect, jest } from "@jest/globals";
import { ZKEmailProver } from "@zk-email/zkemail-nr/dist/prover"
import { makeUnitedInputs } from '../../src/email_inputs/united';
import UnitedCircuit from '../../src/artifacts/circuits/united_email_verifier.json';
import { toBigIntBE } from '../../src/utils';
import { emails } from '../utils/fs';


xdescribe("United Flight Receipt Test", () => {
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
            const { inputs } = await makeUnitedInputs(emails.united);
            
            // simulate witness
            const { returnValue } = await prover.simulateWitness(inputs);

            // parse extraced values
            const extractedValues = ((returnValue as any)[3] as string[]); // todo: better parsing
            const parsedValues = extractedValues.map(x => toBigIntBE(new Uint8Array(Buffer.from(x.slice(2), 'hex'))));
            const destination = Buffer.from(parsedValues[2].toString(16), 'hex').toString('utf8')
            expect(parsedValues[0]).toEqual(171785n);
            expect(parsedValues[1]).toEqual(1682208000n); // should map to 2023-04-23 UTC+0
            expect(destination).toEqual("TPE");

            const formattedAmount = Math.floor(Number(parsedValues[0]) / 100) + '.' + (Number(parsedValues[0]) % 100); 
            const formattedDate = new Date(Number(parsedValues[1]) * 1000).toUTCString();
            console.log(`Billed amount: $${formattedAmount}`);
            console.log(`Date of flight: ${formattedDate[1]}`);
            console.log(`Destination airport code: "${destination}"`);
        })
    })

    xdescribe("Proving", () => {
        it("United::Honk", async () => {
            // make inputs from email
            const { inputs } = await makeUnitedInputs(emails.united);
            // generate proof
            const proof = await prover.fullProve(inputs, 'honk');
            // verify proof
            // const result = await prover.verify(proof, 'honk');

        });

        xit("United::Plonk", async () => {
            // make inputs from email
            const { inputs } = await makeUnitedInputs(emails.united);
            // generate proof
            const proof = await prover.fullProve({ params: inputs }, 'plonk');
            // verify proof
            const result = await prover.verify(proof, 'honk');
            expect(result).toBeTruthy();
        });
    })
})
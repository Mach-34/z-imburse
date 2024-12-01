import { describe, expect, jest } from "@jest/globals";
import { ZKEmailProver } from "@zk-email/zkemail-nr/dist/prover"
import { makeLinodeInputs } from '../../src/email_inputs/linode';
import LinodeCircuit from '../../src/artifacts/circuits/linode_email_verifier.json';
import { parseStringBytes, toBigIntBE, toBufferBE } from '../../src/utils';
import { emails } from '../utils/fs';

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
            // build inputs
            const inputs = await makeLinodeInputs(emails.linode_sep);
            // simulate witness
            const { returnValue } = await prover.simulateWitness({ params: inputs });
            // check the returned values
            // this linode email has a value of $22.00
            const values = (returnValue as string[]).map(x => toBigIntBE(new Uint8Array(Buffer.from(x.slice(2), 'hex'))));
            expect(values[2]).toEqual(2200n);
            // check expected date matches
            const monthYear = Buffer.from(toBufferBE(values[1], 8)).reverse().toString();
            expect(monthYear).toEqual("Sep 2024");
        })
        it("Linode::October2024", async () => {
            // build inputs
            const inputs = await makeLinodeInputs(emails.linode_oct);
            // simulate witness
            const { returnValue } = await prover.simulateWitness({ params: inputs });
            // check the returned values
            const values = (returnValue as string[]).map(x => toBigIntBE(new Uint8Array(Buffer.from(x.slice(2), 'hex'))));
            expect(values[2]).toEqual(2200n);
            // check expected date matches
            const monthYear = Buffer.from(toBufferBE(values[1], 8)).reverse().toString();
            expect(monthYear).toEqual("Oct 2024");
        })
    })

    xdescribe("Proving", () => {
        it("Linode::Honk", async () => {
            // make inputs from email
            const inputs = await makeLinodeInputs(emails.linode_sep);
            // generate proof
            const proof = await prover.fullProve({ params: inputs }, 'honk');
            // verify proof
            const result = await prover.verify(proof, 'honk');
            expect(result).toBeTruthy();

        });

        it("Linode::Plonk", async () => {
            // make inputs from email
            const inputs = await makeLinodeInputs(emails.linode_oct);
            // generate proof
            const proof = await prover.fullProve({ params: inputs }, 'plonk');
            // verify proof
            const result = await prover.verify(proof, 'honk');
            expect(result).toBeTruthy();
        });
    })
})
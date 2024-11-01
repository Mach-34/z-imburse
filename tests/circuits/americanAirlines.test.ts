// import { describe, expect, jest } from "@jest/globals";
// import { ZKEmailProver } from "@mach-34/zkemail-nr/dist/prover"
// import { makeAAInputs } from '../../src/email_inputs/americanAirlines';
// import AACircuit from '../../src/artifacts/circuits/american_airlines_email_verifier.json';
// import { emails } from '../utils/fs';
// import { toBigIntBE } from "../../src/utils";


// describe("AmericanAirlines Billing Receipt Test", () => {
//     let prover: ZKEmailProver;
//     jest.setTimeout(1000000);
//     beforeAll(async () => {
//         //@ts-ignore
//         prover = new ZKEmailProver(AACircuit, 'all');
//     });
//     afterAll(async () => {
//         await prover.destroy();
//     })

//     describe("Simulated", () => {
//         it("AmericanAirlines", async () => {
//             // build inputs
//             const inputs = await makeAAInputs(emails.americanAirlines);
//             // simulate witness
//             const { returnValue } = await prover.simulateWitness(inputs);
//             // check the returned values
//             const values = (returnValue as string[]).map(x => toBigIntBE(new Uint8Array(Buffer.from(x.slice(2), 'hex'))));
//             expect(values[1]).toEqual(560n);
//         })
//     })

//     xdescribe("Proving", () => {
//         it("AmericanAirlines::Honk", async () => {
//             // make inputs from email
//             const inputs = await makeAAInputs(emails.americanAirlines);
//             // generate proof
//             const proof = await prover.fullProve({ params: inputs }, 'honk');
//             // verify proof
//             const result = await prover.verify(proof, 'honk');
//             expect(result).toBeTruthy();

//         });

//         it("AmericanAirlines::Plonk", async () => {
//             // make inputs from email
//             const inputs = await makeAAInputs(emails.americanAirlines);
//             // generate proof
//             const proof = await prover.fullProve({ params: inputs }, 'plonk');
//             // verify proof
//             const result = await prover.verify(proof, 'honk');
//             expect(result).toBeTruthy();
//         });
//     })
// })
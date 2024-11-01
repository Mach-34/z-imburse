// import { describe, expect, jest } from "@jest/globals";
// import { ZKEmailProver } from "@mach-34/zkemail-nr/dist/prover"
// import { makeFrontierInputs } from '../../src/email_inputs/frontier';
// import FrontierCircuit from '../../src/artifacts/circuits/frontier_email_verifier.json';
// import { emails } from '../utils/fs';
// import { toBigIntBE } from "../../src/utils";


// describe("Frontier Billing Receipt Test", () => {
//     let prover: ZKEmailProver;
//     jest.setTimeout(1000000);
//     beforeAll(async () => {
//         //@ts-ignore
//         prover = new ZKEmailProver(FrontierCircuit, 'all');
//     });
//     afterAll(async () => {
//         await prover.destroy();
//     })

//     describe("Simulated", () => {
//         it("Frontier", async () => {
//             // build inputs
//             const inputs = await makeFrontierInputs(emails.frontier);
//             // simulate witness
//             const { returnValue } = await prover.simulateWitness(inputs);
//             // check the returned values
//             const values = (returnValue as string[]).map(x => toBigIntBE(new Uint8Array(Buffer.from(x.slice(2), 'hex'))));
//             expect(values[1]).toEqual(28396n);
//         })
//     })

//     xdescribe("Proving", () => {
//         it("Frontier::Honk", async () => {
//             // make inputs from email
//             const inputs = await makeFrontierInputs(emails.frontier);
//             // generate proof
//             const proof = await prover.fullProve({ params: inputs }, 'honk');
//             // verify proof
//             const result = await prover.verify(proof, 'honk');
//             expect(result).toBeTruthy();

//         });

//         it("Frontier::Plonk", async () => {
//             // make inputs from email
//             const inputs = await makeFrontierInputs(emails.frontier);
//             // generate proof
//             const proof = await prover.fullProve({ params: inputs }, 'plonk');
//             // verify proof
//             const result = await prover.verify(proof, 'honk');
//             expect(result).toBeTruthy();
//         });
//     })
// })
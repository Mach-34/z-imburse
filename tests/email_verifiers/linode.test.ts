import { describe, expect, jest } from "@jest/globals";

import {
    BarretenbergBackend,
    CompiledCircuit,
    UltraHonkBackend,
} from "@noir-lang/backend_barretenberg";
import { Noir } from "@noir-lang/noir_js";
import { readFileSync } from 'fs'
import { BarretenbergSync } from "@aztec/bb.js";
import { join } from 'path';
import { makeLinodeInputs } from '../../src/linode';
// import { LinodeCircuit } from '../../src/circuits';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);


const emails = {
    linode: readFileSync(join(__dirname, "test-data/linode.eml")),
};


type Prover = {
    noir: Noir;
    barretenberg: BarretenbergBackend;
    ultraHonk: UltraHonkBackend;
};

function makeProver(circuit: CompiledCircuit): Prover {
    return {
        noir: new Noir(circuit),
        barretenberg: new BarretenbergBackend(circuit),
        ultraHonk: new UltraHonkBackend(circuit),
    };
}

describe("Linode Billing Receipt Test", () => {
    let prover: Prover;
    jest.setTimeout(1000000);
    beforeAll(async () => {
        //@ts-ignore
        // prover = makeProver(LinodeCircuit as CompiledCircuit);
        await BarretenbergSync.initSingleton();
    });
    afterAll(async () => {
        // await prover.barretenberg.destroy();
        // await prover.ultraHonk.destroy();
    })
    describe("Proving", () => {
        it("Linode::Honk", async () => {
            // make inputs from email
            const inputs = await makeLinodeInputs(emails.linode);
            let x = "date:Sun, 1 Sep 2024 23:22:12 -0400 (EDT)"
            console.log(x.length)
            // console.log(inputs.body.toString())
            // inputs.body = inputs.body.slice(0, Number(inputs.body_length));
            // // execute witness
            // const { witness } = await prover.noir.execute({ params: inputs });
            // // prove with witness
            // const proof = await prover.ultraHonk.generateProof(witness);
            // // verify proof
            // const result = await prover.ultraHonk.verifyProof(proof);
            // expect(result).toBeTruthy();

            // expect(BigInt(proof.publicInputs[0])).toEqual(2200n)

        });

        xit("Linode::Plonk", async () => {
            // make inputs from email
            const inputs = await makeLinodeInputs(emails.linode);
            inputs.body = inputs.body.slice(0, Number(inputs.body_length));
            // execute witness
            const { witness } = await prover.noir.execute({ params: inputs });
            expect(witness).toBeInstanceOf(Uint8Array)
            // prove with witness
            // const proof = await prover.barretenberg.generateProof(witness);
            // // verify proof
            // const result = await prover.barretenberg.verifyProof(proof);
            // expect(result).toBeTruthy();

            // expect(BigInt(proof.publicInputs[0])).toEqual(2200n)
        });
    })
})
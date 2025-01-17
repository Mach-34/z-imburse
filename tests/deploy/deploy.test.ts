import { describe, expect, jest } from "@jest/globals";
import { createAccount } from "@aztec/accounts/testing";
import { createPXEClient, Fr, Fq } from "@aztec/aztec.js";
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { setup } from "../utils/index";

jest.setTimeout(1000000);

describe("Deploy", () => {
    it("Deploying contracts", async () => {
        const pxe = await createPXEClient("http://localhost:8080");

        const schnorr = getSchnorrAccount(
            pxe,
            Fr.fromString('0x06ef861b5853f12549a8d7e3e67083ae680123dcbb12cedb6d3060075f9d0b3c'),
            Fq.fromString('0x082e6d118b06b9fb3bf5bcaa5328f6f742c86dad8df04d5601c3508c827d3c38'),
            0
        );
        await schnorr.deploy().wait();

        const superuser = await schnorr.getWallet()
        const escrowAdmin = await createAccount(pxe);
        const alice = await createAccount(pxe);
        const bob = await createAccount(pxe);

        const { usdc, registry } = await setup(superuser, [escrowAdmin]);

        console.log('USDC contract: ', usdc.address.toString())
        console.log('Registry contract: ', registry.address.toString())
    })
})
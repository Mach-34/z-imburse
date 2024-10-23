import { createAccount } from "@aztec/accounts/testing";
import {
    AccountManager, createPXEClient, Fq,
    Fr, PXE, waitForPXE
} from "@aztec/aztec.js";
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { describe, expect, jest } from "@jest/globals";
import { setup } from "../utils";
import { TokenContract } from "@aztec/noir-contracts.js";
import { USDC_TOKEN } from "../../src/constants";
import { ZImburseRegistryContract } from "../../src/artifacts/contracts";
import { getEscrowContractClassID } from "../../src/contract_drivers";
import { prepareDKIMKeysForInputs } from "../../src/contract_drivers/dkim";

const DEFAULT_PXE_URL = 'http://localhost:8080';

jest.setTimeout(1000000);

const ACCOUNTS = [
    { "secretKey": "0x02f43365be773641bcb735db9c657a1ba517bd2e21ee300c4b8ba97521c4bf13", "signingKey": "0x0eadd86a6754d9c1cd1f8b0be401055ef1c840a03d095c1d025f42212c7685ec" },
    { "secretKey": "0x148502f56f9baf06191bea5aedc69d2ab5dae27f8e48c09d138be715efadce3a", "signingKey": "0x1e63554818eb3423b0725bd8e8eee5b512f2eec463f54d8c6e012df065f04a69" }
];

const registerAccounts = async (pxe: PXE) => {
    const accounts: AccountManager[] = [];
    for (const { secretKey, signingKey } of ACCOUNTS) {
        // derive account from secret & signing keys. Use salt of 0 to derive same value
        const schnorrAccount = getSchnorrAccount(
            pxe,
            Fr.fromString(secretKey),
            Fq.fromString(signingKey),
            0
        );

        // check if account is already registerd on pxe
        const isRegistered = await pxe.getRegisteredAccount(
            schnorrAccount.getAddress()
        );

        // if account not already registered then deploy to pxe
        if (!isRegistered) {
            await schnorrAccount.deploy().wait();
        }

        accounts.push(schnorrAccount);
    }
    return accounts
}

describe("Deploy script", () => {
    it("Deploy contracts", async () => {
        const pxe = createPXEClient(DEFAULT_PXE_URL);
        await waitForPXE(pxe);
        const accounts = await registerAccounts(pxe);

        const dkimKeys = prepareDKIMKeysForInputs(4);
        const superuser = await accounts[0].getWallet();
        const escrowAdmin = await accounts[1].getWallet();
        const escrowClassId = getEscrowContractClassID();
        let usdc: any = undefined;
        let registry: any = undefined;

        usdc = await TokenContract.deploy(
            superuser,
            superuser.getAddress(),
            USDC_TOKEN.symbol,
            USDC_TOKEN.name,
            USDC_TOKEN.decimals
        )
            .send()
            .deployed();

        registry = await ZImburseRegistryContract.deploy(
            superuser,
            usdc.address,
            escrowClassId,
            dkimKeys[0].map((key) => key.id),
            dkimKeys[0].map((key) => key.keyHash)
        )
            .send()
            .deployed();

        console.log('USDC deployed at: ', usdc.address.toString());
        console.log('Registry deployed at: ', registry.address.toString());
    });
});
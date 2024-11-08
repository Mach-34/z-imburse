import { createPXEClient, Fq, Fr, waitForPXE } from "@aztec/aztec.js";
import { createAccount } from "@aztec/accounts/testing";
import { getSchnorrAccount } from "@aztec/accounts/schnorr";
import { setup } from "../tests/utils/index.js";


const DEFAULT_PXE_URL = "http://localhost:8080";

const deploy = async () => {
    const pxe = await createPXEClient(DEFAULT_PXE_URL);
    await waitForPXE(pxe);

    const schnorr = getSchnorrAccount(
        pxe,
        Fr.fromString('0x06ef861b5853f12549a8d7e3e67083ae680123dcbb12cedb6d3060075f9d0b3c'),
        Fq.fromString('0x082e6d118b06b9fb3bf5bcaa5328f6f742c86dad8df04d5601c3508c827d3c38'),
        0
    );

    // check if account is already registerd on pxe
    const isRegistered = await pxe.getRegisteredAccount(
        schnorr.getAddress()
    );

    // if account not already registered then deploy to pxe
    if (!isRegistered) {
        await schnorr.deploy().wait();
    }

    const superuser = await schnorr.getWallet()
    const escrowAdmin = await createAccount(pxe);
    const alice = await createAccount(pxe);
    const bob = await createAccount(pxe);

    const { usdc, registry } = await setup(superuser, [escrowAdmin]);
}

deploy();
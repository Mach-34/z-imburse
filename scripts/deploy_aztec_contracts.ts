import { createPXEClient, waitForPXE } from "@aztec/aztec.js";
import {
    createAccounts,
} from "@aztec/accounts/testing";
import { TokenContract } from "@aztec/noir-contracts.js";


const DEFAULT_PXE_URL = "http://localhost:8080";

const deploy = async () => {
    const pxe = createPXEClient(DEFAULT_PXE_URL);
    await waitForPXE(pxe);
    const accounts = await createAccounts(pxe, 4);

    // deploy USDC contract
    const usdc = await TokenContract.deploy(
        accounts[0],
        accounts[0].getAddress(),
        "USDC",
        "USD Token",
        6n
    )
        .send()
        .deployed();

    console.log('Account #1: ', accounts[0].getAddress().toString());
    console.log('Account #2: ', accounts[1].getAddress().toString());
    console.log('Account #3: ', accounts[2].getAddress().toString());
    console.log('Account #4: ', accounts[3].getAddress().toString());
    console.log('USDC Contract: ', usdc.address.toString())
}

deploy();
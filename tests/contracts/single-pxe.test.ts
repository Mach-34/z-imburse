import { describe, expect, jest } from "@jest/globals";
import { generateEmailVerifierInputs } from "@zk-email/zkemail-nr";
import {
    getInitialTestAccountsWallets,
    createAccount,
} from "@aztec/accounts/testing";
import {
    AccountWalletWithSecretKey,
    AztecAddress,
    AztecAddressLike,
    EventType,
    ExtendedNote,
    Fr,
    FunctionCall,
    Note,
    PXE,
    TxExecutionRequest,
    TxHash,
    computeSecretHash,
    createDebugLogger,
    createPXEClient,
} from "@aztec/aztec.js";
import { Fr as NoirFr } from "@aztec/bb.js";
import {
    MultiCallEntrypointContract,
    TokenContract,
    ZImburseEscrowContract,
    ZImburseRegistryContract,
} from "../../src/artifacts/contracts/index";
import { toUSDCDecimals, toBigIntBE } from "../../src/utils";
import {
    formatRedeemLinode,
    makeLinodeInputs,
} from "../../src/email_inputs/linode";
import { dkimPubkeyToHash } from "../../src/dkim";
import { setup, mintToEscrow, addContractsToPXE } from "../utils/index";
import { emails } from "../utils/fs";
import { parseStringBytes } from "../../src/utils";
import { addPendingShieldNoteToPXE } from "../../src/contract_drivers/notes";
import { VERIFIER_IDS } from "../../src/contract_drivers/dkim";

const DEFAULT_PXE_URL = "http://localhost";

jest.setTimeout(1000000);

describe("Test deposit to zimburse", () => {
    let superuser: AccountWalletWithSecretKey;
    let escrowAdmin: AccountWalletWithSecretKey;
    let alice: AccountWalletWithSecretKey;
    let bob: AccountWalletWithSecretKey;
    let multicall: MultiCallEntrypointContract;
    let usdc: TokenContract;
    let registry: ZImburseRegistryContract;
    let escrows: ZImburseEscrowContract[] = [];

    beforeAll(async () => {
        // setup pxe connection
        const pxe = await createPXEClient(`${DEFAULT_PXE_URL}:8080`);

        // deploy test accounts
        superuser = await createAccount(pxe);
        escrowAdmin = await createAccount(pxe);
        alice = await createAccount(pxe);
        bob = await createAccount(pxe);

        // register recipients for each PXE
        await pxe.registerRecipient(alice.getCompleteAddress());
        await pxe.registerRecipient(bob.getCompleteAddress());
        await pxe.registerRecipient(escrowAdmin.getCompleteAddress());

        // set multicall
        const nodeInfo = await pxe.getNodeInfo();
        multicall = await MultiCallEntrypointContract.at(
            nodeInfo.protocolContractAddresses.multiCallEntrypoint,
            superuser
        );

        // deploy contracts
        ({ usdc, registry, escrows } = await setup(superuser, [escrowAdmin]));

        // mint usdc to the escrows
        for (const escrow of escrows) {
            await mintToEscrow(
                usdc,
                escrow.address,
                superuser,
                toUSDCDecimals(10000n)
            );
        }
    });

    describe("Registration", () => {
        it("Register Z-Imburse Escrow", async () => {

            const testEscrow = await ZImburseEscrowContract.deploy(
                escrowAdmin,
                registry.address,
                usdc.address,
                `Escrow Test`
            )
                .send()
                .deployed();

            // register the escrow
            await registry
                .withWallet(escrowAdmin)
                .methods.register_escrow(testEscrow.address)
                .send()
                .wait();
            // // check that the escrow is registered
            const isRegistered = await registry.withWallet(escrowAdmin).methods
                .get_escrow_registry_status(testEscrow.address)
                .simulate();
            expect(isRegistered).toBeTruthy();

            const receipt1 = await testEscrow.withWallet(escrowAdmin)
                .methods.give_recurring_entitlement(
                    bob.getAddress(),
                    10,
                    2
                )
                .send()
                .wait();

        });
    });

    describe("Hosting entitlements", () => {
        it.todo("Cannot give entitlement if not admin");
        it.todo("Cannot give entitlement if escrow not registered");
        it.todo("Cannot give entitlement if participant not registered");
        describe("Linode", () => {
            it("Give linode recurring entitlement", async () => {
                // check dkim key
                // give entitlement of 10 usdc
                const amount = toUSDCDecimals(10n);
                await escrows[0]
                    .methods.give_recurring_entitlement(
                        alice.getAddress(),
                        amount,
                        2
                    )
                    .send()
                    .wait();

                const secret = Fr.random();
                const secretHash = computeSecretHash(secret);
                const inputs = await makeLinodeInputs(emails.linode_sep);
                const redeemLinodeInputs = formatRedeemLinode(inputs);
                const receipt = await escrows[0]
                    .withWallet(alice)
                    .methods.reimburse_linode_recurring(redeemLinodeInputs, secretHash)
                    .send()
                    .wait();
                await addPendingShieldNoteToPXE(
                    alice,
                    usdc.address,
                    amount,
                    secretHash,
                    receipt.txHash
                );

                const escrowBalance = await usdc.methods
                    .balance_of_public(escrows[0])
                    .simulate();
                expect(escrowBalance).toBe(toUSDCDecimals(9990n));

                await usdc
                    .withWallet(alice)
                    .methods.redeem_shield(alice.getAddress(), amount, secret)
                    .send()
                    .wait();
                // check that the balance has incremented for the recipient
                const recipientBalance = await usdc
                    .withWallet(alice)
                    .methods.balance_of_private(alice.getAddress())
                    .simulate();
                console.log('Recipient balance: ', recipientBalance)
                expect(recipientBalance).toBe(toUSDCDecimals(10n));
            });
        });
    });
});

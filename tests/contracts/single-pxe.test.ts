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
    UniqueNote,
    computeSecretHash,
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
import { VERIFIER_IDS } from "../../src/contract_drivers/dkim";

const DEFAULT_PXE_URL = "http://localhost";

jest.setTimeout(1000000);

const BLOCK_FETCH_LIMIT = 100000;

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
        describe("Revoke entitlements", () => {
            xit("Give linode recurring entitlement", async () => {
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

                const inputs = await makeLinodeInputs(emails.linode_sep);
                const redeemLinodeInputs = formatRedeemLinode(inputs);
                const receipt = await escrows[0]
                    .withWallet(alice)
                    .methods.reimburse_linode_recurring(redeemLinodeInputs)
                    .send()
                    .wait();
                const escrowBalance = await usdc.methods
                    .balance_of_public(escrows[0])
                    .simulate();
                expect(escrowBalance).toBe(toUSDCDecimals(9990n));

                // check that the balance has incremented for the recipient
                const recipientBalance = await usdc
                    .withWallet(alice)
                    .methods.balance_of_private(alice.getAddress())
                    .simulate();
                console.log('Recipient balance: ', recipientBalance)
                expect(recipientBalance).toBe(toUSDCDecimals(10n));
            });

            it("Test revoke spot entitlement", async () => {
                const amount = toUSDCDecimals(10n);
                // give entitlement
                await escrows[0]
                    .methods
                    .give_spot_entitlement(
                        alice.getAddress(),
                        amount,
                        2,
                        new Date(2024, 7, 30).getTime() / 1000,
                        new Date(2024, 9, 1).getTime() / 1000,
                        "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
                    )
                    .send()
                    .wait();


                // revoke entitlement
                await escrows[0]
                    .withWallet(escrowAdmin)
                    .methods
                    .revoke_entitlement(alice.getAddress(), 2, true)
                    .send()
                    .wait();
                // we will not remove entitlement from alice's PXE and try to use it
                const inputs = await makeLinodeInputs(emails.linode_sep);
                const redeemLinodeInputs = formatRedeemLinode(inputs);
                const failingCall = escrows[0]
                    .withWallet(alice)
                    .methods
                    .reimburse_linode_spot(redeemLinodeInputs)
                    .simulate();
                await expect(failingCall)
                    .rejects
                    .toThrow();
            });

            it("Test revoke recurring entitlement", async () => {

                const amount = toUSDCDecimals(10n);
                // give entitlement
                await escrows[0]
                    .methods
                    .give_recurring_entitlement(
                        alice.getAddress(),
                        amount,
                        2,
                    )
                    .send()
                    .wait();

                // revoke entitlement
                await escrows[0]
                    .withWallet(escrowAdmin)
                    .methods
                    .revoke_entitlement(alice.getAddress(), 2, false)
                    .send()
                    .wait();
                // we will not remove entitlement from alice's PXE and try to use it
                const inputs = await makeLinodeInputs(emails.linode_sep);
                const redeemLinodeInputs = formatRedeemLinode(inputs);
                const failingCall = escrows[0]
                    .withWallet(alice)
                    .methods
                    .reimburse_linode_recurring(redeemLinodeInputs)
                    .simulate();
                await expect(failingCall)
                    .rejects
                    .toThrow();
            })

            it("Test cannot revoke spent Linode spot entitlement", async () => {
                const amount = toUSDCDecimals(10n);
                // give entitlement
                await escrows[0]
                    .methods
                    .give_spot_entitlement(
                        bob.getAddress(),
                        amount,
                        2,
                        new Date(2024, 8, 30).getTime() / 1000,
                        new Date(2024, 10, 1).getTime() / 1000,
                        "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
                    )
                    .send()
                    .wait();

                // claim the spot entitlement
                const inputs = await makeLinodeInputs(emails.linode_oct);
                const redeemLinodeInputs = formatRedeemLinode(inputs);
                await escrows[0]
                    .withWallet(bob)
                    .methods
                    .reimburse_linode_spot(redeemLinodeInputs)
                    .send()
                    .wait();

                // fail to revoke entitlement
                let failingCall = escrows[0]
                    .withWallet(escrowAdmin)
                    .methods
                    .revoke_entitlement(bob.getAddress(), 2, true)
                    .simulate();
                await expect(failingCall)
                    .rejects
                    .toThrow();
            })

        });

        xdescribe("Nullify entitlements", () => {

            it("Test nullify counterpart on claimed spot entitlement", async () => {
                const amount = toUSDCDecimals(20n);
                // give entitlement
                await escrows[0].withWallet(escrowAdmin)
                    .methods
                    .give_spot_entitlement(
                        alice.getAddress(),
                        amount,
                        2,
                        new Date(2024, 7, 30).getTime() / 1000,
                        new Date(2024, 9, 1).getTime() / 1000,
                        "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
                    )
                    .send()
                    .wait();

                const inputs = await makeLinodeInputs(emails.linode_sep);
                const redeemLinodeInputs = formatRedeemLinode(inputs);
                // claim linode entitlement
                await escrows[0]
                    .withWallet(alice)
                    .methods.reimburse_linode_spot(redeemLinodeInputs)
                    .send()
                    .wait();
                const escrowBalance = await usdc.methods
                    .balance_of_public(escrows[0])
                    .simulate();
                expect(escrowBalance).toBe(toUSDCDecimals(9980n));

                const entitlementsAlice = await escrows[0].methods
                    .view_entitlements(
                        0,
                        alice.getAddress(),
                        { _is_some: false, _value: AztecAddress.ZERO },
                        { _is_some: false, _value: 0 },
                        { _is_some: false, _value: false }
                    )
                    .simulate();

                expect(entitlementsAlice[0].len).toEqual(0n);


                const entitlementsEscrowAdmin = await escrows[0].methods
                    .view_entitlements(
                        0,
                        escrowAdmin.getAddress(),
                        { _is_some: false, _value: AztecAddress.ZERO },
                        { _is_some: false, _value: 0 },
                        { _is_some: false, _value: false }
                    )
                    .simulate();

                expect(entitlementsEscrowAdmin[0].len).toEqual(1n);

                // get randomness from NullifiedEntitlement event emitted to Alice
                const nullifyEvents = await escrowAdmin.getEncryptedEvents(ZImburseEscrowContract.events.EntitlementNullified, 1, BLOCK_FETCH_LIMIT);
                const { randomness }: any = nullifyEvents[nullifyEvents.length - 1];

                const entropyValues = new Array(10).fill(0);
                entropyValues[0] = randomness;

                await escrows[0]
                    .withWallet(escrowAdmin)
                    .methods
                    .nullify_entitlements(entropyValues)
                    .send()
                    .wait();

                const entitlementsEscrowAdminAfter = await escrows[0].methods
                    .view_entitlements(
                        0,
                        escrowAdmin.getAddress(),
                        { _is_some: false, _value: AztecAddress.ZERO },
                        { _is_some: false, _value: 0 },
                        { _is_some: false, _value: false }
                    )
                    .simulate();

                expect(entitlementsEscrowAdminAfter[0].len).toEqual(0n);
            });

            it("Test nullify counterpart on revoked recurring entitlement", async () => {
                const amount = toUSDCDecimals(35n);
                // give entitlement
                await escrows[0].withWallet(escrowAdmin)
                    .methods
                    .give_recurring_entitlement(
                        alice.getAddress(),
                        amount,
                        2,
                    )
                    .send()
                    .wait();

                // revoke entitlement
                await escrows[0]
                    .withWallet(escrowAdmin)
                    .methods
                    .revoke_entitlement(alice.getAddress(), 2, false)
                    .send()
                    .wait();

                const entitlementsBefore = await escrows[0].methods
                    .view_entitlements(
                        0,
                        alice.getAddress(),
                        { _is_some: false, _value: AztecAddress.ZERO },
                        { _is_some: false, _value: 0 },
                        { _is_some: false, _value: false }
                    )
                    .simulate();

                expect(entitlementsBefore[0].len).toEqual(1n);

                // get randomness from NullifiedEntitlement event emitted to Alice
                const nullifyEvents = await alice.getEncryptedEvents(ZImburseEscrowContract.events.EntitlementNullified, 1, BLOCK_FETCH_LIMIT);
                const { randomness }: any = nullifyEvents[nullifyEvents.length - 1];

                const entropyValues = new Array(10).fill(0);
                entropyValues[0] = randomness;

                await escrows[0]
                    .withWallet(alice)
                    .methods
                    .nullify_entitlements(entropyValues)
                    .send()
                    .wait();

                const entitlementsAfter = await escrows[0].methods
                    .view_entitlements(
                        0,
                        alice.getAddress(),
                        { _is_some: false, _value: AztecAddress.ZERO },
                        { _is_some: false, _value: 0 },
                        { _is_some: false, _value: false }
                    )
                    .simulate();

                expect(entitlementsAfter[0].len).toEqual(0n);
            });

            it("Test nullify counterpart on revoked spot entitlement", async () => {
                const amount = toUSDCDecimals(10n);
                // give entitlement
                await escrows[0].withWallet(escrowAdmin)
                    .methods
                    .give_spot_entitlement(
                        alice.getAddress(),
                        amount,
                        2,
                        new Date(2024, 7, 30).getTime() / 1000,
                        new Date(2024, 9, 1).getTime() / 1000,
                        "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
                    )
                    .send()
                    .wait();

                // revoke entitlement
                await escrows[0]
                    .withWallet(escrowAdmin)
                    .methods
                    .revoke_entitlement(alice.getAddress(), 2, true)
                    .send()
                    .wait();

                const entitlementsBefore = await escrows[0].methods
                    .view_entitlements(
                        0,
                        alice.getAddress(),
                        { _is_some: false, _value: AztecAddress.ZERO },
                        { _is_some: false, _value: 0 },
                        { _is_some: false, _value: false }
                    )
                    .simulate();

                expect(entitlementsBefore[0].len).toEqual(1n);

                // get randomness from NullifiedEntitlement event emitted to Alice
                const nullifyEvents = await alice.getEncryptedEvents(ZImburseEscrowContract.events.EntitlementNullified, 1, BLOCK_FETCH_LIMIT);
                const { randomness }: any = nullifyEvents[nullifyEvents.length - 1];

                const entropyValues = new Array(10).fill(0);
                entropyValues[0] = randomness;

                await escrows[0]
                    .withWallet(alice)
                    .methods
                    .nullify_entitlements(entropyValues)
                    .send()
                    .wait();

                const entitlementsAfter = await escrows[0].methods
                    .view_entitlements(
                        0,
                        alice.getAddress(),
                        { _is_some: false, _value: AztecAddress.ZERO },
                        { _is_some: false, _value: 0 },
                        { _is_some: false, _value: false }
                    )
                    .simulate();

                expect(entitlementsAfter[0].len).toEqual(0n);
            });

            it("Test nullify 3 note counterparts at once", async () => {
                // give linode spot entitlement
                await escrows[0].withWallet(escrowAdmin)
                    .methods
                    .give_spot_entitlement(
                        alice.getAddress(),
                        1000n,
                        2,
                        new Date(2024, 7, 30).getTime() / 1000,
                        new Date(2024, 9, 1).getTime() / 1000,
                        "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
                    )
                    .send()
                    .wait();

                // give linode recurring entitlement
                await escrows[0].withWallet(escrowAdmin)
                    .methods
                    .give_recurring_entitlement(
                        alice.getAddress(),
                        200n,
                        2,
                    )
                    .send()
                    .wait();

                // give united spot entitlement
                await escrows[0].withWallet(escrowAdmin)
                    .methods
                    .give_spot_entitlement(
                        alice.getAddress(),
                        4200n,
                        5,
                        new Date(2023, 0, 1).getTime() / 1000,
                        new Date(2025, 0, 12).getTime() / 1000,
                        "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"
                    )
                    .send()
                    .wait();

                const entitlements = [{ spot: true, verifier: 2 }, { spot: false, verifier: 2 }, { spot: true, verifier: 5 }];

                // revoke entitlements
                for (const entitlement of entitlements) {
                    await escrows[0]
                        .withWallet(escrowAdmin)
                        .methods
                        .revoke_entitlement(alice.getAddress(), entitlement.verifier, entitlement.spot)
                        .send()
                        .wait();
                }

                const entitlementsBefore = await escrows[0].methods
                    .view_entitlements(
                        0,
                        alice.getAddress(),
                        { _is_some: false, _value: AztecAddress.ZERO },
                        { _is_some: false, _value: 0 },
                        { _is_some: false, _value: false }
                    )
                    .simulate();

                expect(entitlementsBefore[0].len).toEqual(3n);

                // get entropy values from NullifiedEntitlement events emitted to Alice
                const nullifyEvents = await alice.getEncryptedEvents(ZImburseEscrowContract.events.EntitlementNullified, 1, BLOCK_FETCH_LIMIT);
                const randomnessVals = nullifyEvents.map(({ randomness }: any) => randomness);

                const { vals: entropyVals } = (await alice.getIncomingNotes({})).reduce((entropyVals: { len: number, vals: bigint[] }, note: UniqueNote) => {
                    if (note.noteTypeId.value === ZImburseEscrowContract.notes.EntitlementNote.id.value) {
                        const entropy = note.note.items[7].toBigInt();
                        if (randomnessVals.includes(entropy)) {
                            entropyVals.vals[entropyVals.len] = entropy;
                            entropyVals.len += 1;
                        }
                    }
                    return entropyVals;
                }, { len: 0, vals: new Array(10).fill(0) });

                // nullify entitlements
                await escrows[0]
                    .withWallet(alice)
                    .methods
                    .nullify_entitlements(entropyVals)
                    .send()
                    .wait();

                const entitlementsAfter = await escrows[0].methods
                    .view_entitlements(
                        0,
                        alice.getAddress(),
                        { _is_some: false, _value: AztecAddress.ZERO },
                        { _is_some: false, _value: 0 },
                        { _is_some: false, _value: false }
                    )
                    .simulate();

                expect(entitlementsAfter[0].len).toEqual(0n);
            });
        })
    });
});

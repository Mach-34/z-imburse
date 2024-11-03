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
    const sandboxPXE = await createPXEClient(`${DEFAULT_PXE_URL}:8080`);
    const pxe1 = await createPXEClient(`${DEFAULT_PXE_URL}:8081`);
    const pxe2 = await createPXEClient(`${DEFAULT_PXE_URL}:8082`);
    const pxe3 = await createPXEClient(`${DEFAULT_PXE_URL}:8083`);
    console.log(
      `Connected to Sandbox & 4 PXE's at "${DEFAULT_PXE_URL}:[8080-8083]"\n`
    );

    // deploy test accounts
    superuser = await createAccount(sandboxPXE);
    escrowAdmin = await createAccount(pxe1);
    alice = await createAccount(pxe2);
    bob = await createAccount(pxe3);

    // register recipients for each PXE
    await sandboxPXE.registerRecipient(alice.getCompleteAddress());
    await sandboxPXE.registerRecipient(bob.getCompleteAddress());
    await sandboxPXE.registerRecipient(escrowAdmin.getCompleteAddress());
    await pxe1.registerRecipient(superuser.getCompleteAddress());
    await pxe1.registerRecipient(alice.getCompleteAddress());
    await pxe1.registerRecipient(bob.getCompleteAddress());
    await pxe2.registerRecipient(superuser.getCompleteAddress());
    await pxe2.registerRecipient(escrowAdmin.getCompleteAddress());
    await pxe2.registerRecipient(bob.getCompleteAddress());
    await pxe3.registerRecipient(superuser.getCompleteAddress());
    await pxe3.registerRecipient(escrowAdmin.getCompleteAddress());
    await pxe3.registerRecipient(alice.getCompleteAddress());

    // set multicall
    const nodeInfo = await sandboxPXE.getNodeInfo();
    multicall = await MultiCallEntrypointContract.at(
      nodeInfo.protocolContractAddresses.multiCallEntrypoint,
      superuser
    );

    // deploy contracts
    ({ usdc, registry, escrows } = await setup(superuser, [escrowAdmin]));

    // register contracts in other PXE's
    await addContractsToPXE(escrowAdmin, [usdc, registry]);
    await addContractsToPXE(alice, [usdc, registry, ...escrows]);
    await addContractsToPXE(bob, [usdc, registry, ...escrows]);

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

      console.log('Receipt 1: ', receipt1)

      // // todo: FIX
      // // expect(managedEscrows[0][0]).toEqual(escrows[0].address);
      // // check the rest of the fields are zero
      // for (let i = 1; i < 10; i++)
      //   expect(managedEscrows[0][i]).toEqual(AztecAddress.ZERO);
      // // check pagination status = over
      // expect(managedEscrows[1]).toBeTruthy();
    });

    xit("Enroll user within Z-Imburse Escrow", async () => {
      // todo: figure out multicall
      // await registry
      //   .withWallet(superuser)
      //   .methods.check_and_register_participant(
      //     alice.getAddress(),
      //     "Alice\0",
      //     escrows[0].address
      //   )
      //   .send()
      //   .wait();
      // await registry
      //   .withWallet(escrowAdmin)
      //   .methods.check_and_register_participant(
      //     bob.getAddress(),
      //     "Bob\0",
      //     escrows[0].address
      //   )
      //   .send()
      //   .wait();
      // check participants from escrow admin perspective
      // const participants = await registry
      //   .withWallet(escrowAdmin)
      //   .methods.get_participants(escrows[0].address, 0)
      //   .simulate();
      // expect(participants[0][0]).toEqual(alice.getAddress());
      // expect(parseStringBytes(participants[1][0])).toEqual("Alice");
      // expect(participants[0][1]).toEqual(bob.getAddress());
      // expect(parseStringBytes(participants[1][1])).toEqual("Bob");
      // // check the rest of the fields are zero
      // for (let i = 2; i < 10; i++)
      //   expect(participants[0][i]).toEqual(AztecAddress.ZERO);
      // // check pagination status = over
      // expect(participants[2]).toBeTruthy();

      // // check enrolled status from participant perspective as alice
      // const aliceEscrows = await registry
      //   .withWallet(alice)
      //   .methods.get_participant_escrows(alice.getAddress(), 0)
      //   .simulate();
      // expect(aliceEscrows[0][0]).toEqual(escrows[0].address);
      // // check the rest of the fields are zero
      // for (let i = 1; i < 10; i++)
      //   expect(aliceEscrows[0][i]).toEqual(AztecAddress.ZERO);
      // // check pagination status = over
      // expect(aliceEscrows[1]).toBeTruthy();

      // // check enrolled status from participant perspective as bob
      // const bobEscrows = await registry
      //   .withWallet(bob)
      //   .methods.get_participant_escrows(bob.getAddress(), 0)
      //   .simulate();
      // bobEscrows[0][0] = escrows[0].address;
      // // check the rest of the fields are zero
      // for (let i = 1; i < 10; i++)
      //   expect(bobEscrows[0][i]).toEqual(AztecAddress.ZERO);
      // // check pagination status = over
      // expect(bobEscrows[1]).toBeTruthy();
    });

    it.todo("Paginated managed escrow retrieval");
    it.todo("Paginated participant escrow retrieval");
    it.todo("Paginated participant retrieval");

    it.todo("Remove participant from escrow");
    it.todo("Clear out escrows when removed as participant");

    it.todo("Cannot register non-escrow in registry");
    it.todo("Cannot register escrow multiple times");
    it.todo("Cannot register undeployed contract in escrow");
    it.todo("Cannot register escrow when not admin");

    it.todo("Cannot register participant when not admin");
    it.todo("Cannot register participant when not escrow");
    it.todo("Cannot register participant multiple times");
    it.todo(
      "Cannot register participant when escrow is not registered in registry"
    );
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
        const receipt1 = await escrows[0]
          .methods.give_recurring_entitlement(
            alice.getAddress(),
            amount,
            2
          )
          .send()
          .wait();

        console.log('Receipt 1: ', receipt1)

        // const listedEntitlements = await escrows[0].withWallet(escrowAdmin).methods.view_entitlements(
        //   0,
        //   escrowAdmin.getAddress(),
        //   { _is_some: false, _value: AztecAddress.ZERO },
        //   { _is_some: false, _value: 0 },
        //   { _is_some: false, _value: false },
        // ).simulate();

        // console.log('Listed entitlements: ', listedEntitlements)

        // // generate email inputs
        // const inputs = await makeLinodeInputs(emails.linode_sep);
        // transform inputs to contract friendly format
        // const redeemLinodeInputs = formatRedeemLinode(inputs);
        // // redeem entitlement
        const secret = Fr.random();
        const secretHash = computeSecretHash(secret);
        // const receipt = await escrows[0]
        //   .withWallet(alice)
        //   .methods.reimburse_linode(...redeemLinodeInputs, secretHash)
        //   .send()
        //   .wait();
        // await addPendingShieldNoteToPXE(
        //   alice,
        //   usdc.address,
        //   amount,
        //   secretHash,
        //   receipt.txHash
        // );
        // // check that the balance has decremented from zimburse
        // const escrowBalance = await usdc.methods
        //   .balance_of_public(escrows[0])
        //   .simulate();
        // expect(escrowBalance).toBe(toUSDCDecimals(9990n));
        // // redeem the shielded USDC note
        // await usdc
        //   .withWallet(alice)
        //   .methods.redeem_shield(alice.getAddress(), amount, secret)
        //   .send()
        //   .wait();
        // // check that the balance has incremented for the recipient
        // const recipientBalance = await usdc
        //   .withWallet(alice)
        //   .methods.balance_of_private(alice.getAddress())
        //   .simulate();
        // expect(recipientBalance).toBe(toUSDCDecimals(10n));
      });
      // xit("Can't use the same email (same month)", async () => {
      //   // generate email inputs
      //   const inputs = await makeLinodeInputs(emails.linode_sep);
      //   // transform inputs to contract friendly format
      //   const redeemLinodeInputs = formatRedeemLinode(inputs);
      // redeem entitlement
      //   const secret = Fr.random();
      //   const secretHash = computeSecretHash(secret);
      //   await expect(
      //     escrows[0]
      //       .withWallet(alice)
      //       .methods.reimburse_linode(...redeemLinodeInputs, secretHash)
      //       .send()
      //       .wait()
      //   ).rejects.toThrow(
      //     "Entitlement has already been claimed for this month '!recurring_nullifier_exists'"
      //   );
      // });
      // it("Check nullification removes notes", async () => {
      //   // check notes exist
      //   let adminReceipts = await escrows[0]
      //     .withWallet(escrowAdmin)
      //     .methods.get_recurring_entitlements_by_user(
      //       escrowAdmin.getAddress(),
      //       alice.getAddress(),
      //       0
      //     )
      //     .simulate();
      //   console.log("Admin receipts: ", adminReceipts[0]);
      //   expect(adminReceipts[0].len).toBe(1n);
      //   let recipientEntitlements = await escrows[0]
      //     .withWallet(alice)
      //     .methods.get_recurring_entitlements_by_user(
      //       alice.getAddress(),
      //       alice.getAddress(),
      //       0
      //     )
      //     .simulate();
      //   console.log("Recipient entitlements: ", recipientEntitlements[0]);

      //   expect(recipientEntitlements[0].len).toBe(1n);

      //   // nullify entitlement
      //   await escrows[0]
      //     .withWallet(escrowAdmin)
      //     .methods.revoke_recurring_entitlement(
      //       alice.getAddress(),
      //       VERIFIER_IDS.LINODE
      //     )
      //     .send()
      //     .wait();
      //   // update nullified note
      //   const blockNum = await alice.getBlockNumber();
      //   const events = await alice.getEvents(
      //     EventType.Encrypted,
      //     TokenContract.events.Transfer,
      //     blockNum - 5,
      //     blockNum
      //   );
      //   console.log("Events", events);
      //   // check notes removed
      //   adminReceipts = await escrows[0]
      //     .withWallet(escrowAdmin)
      //     .methods.get_recurring_entitlements_by_user(
      //       escrowAdmin.getAddress(),
      //       alice.getAddress(),
      //       0
      //     )
      //     .simulate();
      //   console.log("Admin receipts: ", adminReceipts);

      //   // remove note
      //   let note = (
      //     await alice.getIncomingNotes({
      //       contractAddress: escrows[0].address,
      //       owner: alice.getAddress(),
      //     })
      //   )[0];
      //   await alice.addNullifiedNote(note);
      //   // expect(adminReceipts[0].len).toBe(0n);
      //   recipientEntitlements = await escrows[0]
      //     .withWallet(alice)
      //     .methods.get_recurring_entitlements_by_user(
      //       alice.getAddress(),
      //       alice.getAddress(),
      //       0
      //     )
      //     .simulate();
      //   console.log("Recipient entitlements: ", recipientEntitlements);

      //   // expect(recipientEntitlements[0].len).toBe(0n);
      // });
      // it.todo("Admin can't re-issue an entitlement");
      // it.todo("Admin can nullify the entitlement");
      // it.todo("Admin can reissue an entitlement after nullifying the old one");
    });
  });
});

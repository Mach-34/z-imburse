import { describe, expect, jest } from "@jest/globals";
import { generateEmailVerifierInputs } from "@mach-34/zkemail-nr";
import {
  getInitialTestAccountsWallets,
  createAccount,
} from "@aztec/accounts/testing";
import {
  AccountWalletWithSecretKey,
  AztecAddress,
  AztecAddressLike,
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
  ZImburseDkimRegistryContract,
  ZImburseEscrowRegistryContract
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
  let dkimRegistry: ZImburseDkimRegistryContract;
  let escrowRegistry: ZImburseEscrowRegistryContract;
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
    ({ usdc, dkimRegistry, escrowRegistry, escrows } = await setup(superuser, [
      escrowAdmin,
    ]));

    // register contracts in other PXE's
    await addContractsToPXE(escrowAdmin, [usdc, dkimRegistry, escrowRegistry]);
    await addContractsToPXE(alice, [usdc, dkimRegistry, escrowRegistry, ...escrows]);
    await addContractsToPXE(bob, [usdc, dkimRegistry, escrowRegistry, ...escrows]);

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

  xdescribe("Registration", () => {
    it("Register Z-Imburse Escrow", async () => {
      // register the escrow
      await escrowRegistry
        .withWallet(escrowAdmin)
        .methods.register_escrow(escrows[0].address)
        .send()
        .wait();
      // check that the escrow is registered
      const isRegistered = await escrowRegistry.methods
        .get_contract_registration_status(escrows[0].address)
        .simulate();
      expect(isRegistered).toBeTruthy();

      // check escrow is first return
      const managedEscrows = await escrowRegistry.methods
        .get_managed_escrows(escrowAdmin.getAddress(), 0)
        .simulate();
        console.log(managedEscrows);
      // todo: FIX
      // expect(managedEscrows[0][0]).toEqual(escrows[0].address);
      // check the rest of the fields are zero
      for (let i = 1; i < 10; i++)
        expect(managedEscrows[0][i]).toEqual(AztecAddress.ZERO);
      // check pagination status = over
      expect(managedEscrows[1]).toBeTruthy();
    });

    it("Enroll user within Z-Imburse Escrow", async () => {
      // todo: figure out multicall
      await escrowRegistry
        .withWallet(escrowAdmin)
        .methods.check_and_register_participant(
          alice.getAddress(),
          "Alice\0",
          escrows[0].address
        )
        .send()
        .wait();
      await escrowRegistry
        .withWallet(escrowAdmin)
        .methods.check_and_register_participant(
          bob.getAddress(),
          "Bob\0",
          escrows[0].address
        )
        .send()
        .wait();
      // check participants from escrow admin perspective
      const participants = await escrowRegistry
        .withWallet(escrowAdmin)
        .methods.get_participants(escrows[0].address, 0)
        .simulate();
      expect(participants[0][0]).toEqual(alice.getAddress());
      expect(parseStringBytes(participants[1][0])).toEqual("Alice");
      expect(participants[0][1]).toEqual(bob.getAddress());
      expect(parseStringBytes(participants[1][1])).toEqual("Bob");
      // check the rest of the fields are zero
      for (let i = 2; i < 10; i++)
        expect(participants[0][i]).toEqual(AztecAddress.ZERO);
      // check pagination status = over
      expect(participants[2]).toBeTruthy();

      // check enrolled status from participant perspective as alice
      const aliceEscrows = await escrowRegistry
        .withWallet(alice)
        .methods.get_participant_escrows(alice.getAddress(), 0)
        .simulate();
      expect(aliceEscrows[0][0]).toEqual(escrows[0].address);
      // check the rest of the fields are zero
      for (let i = 1; i < 10; i++)
        expect(aliceEscrows[0][i]).toEqual(AztecAddress.ZERO);
      // check pagination status = over
      expect(aliceEscrows[1]).toBeTruthy();

      // check enrolled status from participant perspective as bob
      const bobEscrows = await escrowRegistry
        .withWallet(bob)
        .methods.get_participant_escrows(bob.getAddress(), 0)
        .simulate();
      bobEscrows[0][0] = escrows[0].address;
      // check the rest of the fields are zero
      for (let i = 1; i < 10; i++)
        expect(bobEscrows[0][i]).toEqual(AztecAddress.ZERO);
      // check pagination status = over
      expect(bobEscrows[1]).toBeTruthy();
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
      it("Check DKIM Key", async () => {
        const inputs = await makeLinodeInputs(emails.linode_sep);
        // transform inputs to contract friendly format
        const keyHash = await dkimPubkeyToHash(inputs.pubkey);
        console.log("Pubkey Hash: ", keyHash);
        // check if dkim key is initialized
        let verifierId = await dkimRegistry
          .withWallet(alice)
          .methods
          .check_dkim_key_hash_private(keyHash)
          .simulate();
        console.log("Verifier ID: ", verifierId);
      })
      it("Give linode recurring entitlement", async () => {
        // check dkim key
        // give entitlement of 10 usdc
        const amount = toUSDCDecimals(10n);
        const receipt1 = await escrows[0]
          .withWallet(escrowAdmin)
          .methods.give_recurring_entitlement(alice.getAddress(), amount, VERIFIER_IDS.LINODE)
          .send()
          .wait({ debug: true });
        console.log("Public Data Writes", receipt1.debugInfo!.publicDataWrites);
        console.log("Outgoing visible notes", receipt1.debugInfo!.visibleOutgoingNotes.map(note => note.note.items));
        console.log("Incoming visible notes", receipt1.debugInfo!.visibleIncomingNotes.map(note => note.note.items));

        // check entitlement
        const entitlement = await escrows[0]
          .withWallet(alice)
          .methods
          .log_note(alice.getAddress())
          .simulate();
        console.log("Owner: ", entitlement[0]);
        console.log("npk_m_hash: ", entitlement[1]);
        console.log("revocation npk_m_hash: ", entitlement[2]);
        console.log("verifier_id: ", entitlement[3]);
        console.log("amount: ", entitlement[4]);
        console.log("randomness: ", entitlement[5]);

        // generate email inputs
        const inputs = await makeLinodeInputs(emails.linode_sep);
        // transform inputs to contract friendly format
        const redeemLinodeInputs = formatRedeemLinode(inputs);
        // redeem entitlement
        const secret = Fr.random();
        const secretHash = computeSecretHash(secret);
        const receipt = await escrows[0]
          .withWallet(alice)
          .methods.redeem_linode_entitlement(...redeemLinodeInputs, secretHash)
          .send()
          .wait();
        await addPendingShieldNoteToPXE(
          alice,
          usdc.address,
          amount,
          secretHash,
          receipt.txHash
        );
        // check that the balance has decremented from zimburse
        const escrowBalance = await usdc.methods
          .balance_of_public(escrows[0])
          .simulate();
        expect(escrowBalance).toBe(toUSDCDecimals(9990n));
        // redeem the shielded USDC note
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
        expect(recipientBalance).toBe(toUSDCDecimals(10n));
      });
      it("Can't use the same email (same month)", async () => {
        // generate email inputs
        const inputs = await makeLinodeInputs(emails.linode_sep);
        // transform inputs to contract friendly format
        const redeemLinodeInputs = formatRedeemLinode(inputs);
        // redeem entitlement
        const secret = Fr.random();
        const secretHash = computeSecretHash(secret);
        expect(escrows[0]
          .withWallet(alice)
          .methods.redeem_linode_entitlement(...redeemLinodeInputs, secretHash)
          .simulate()
        ).rejects.toThrowError(/someerror/);
      });
      it("Can use different month to claim the entitlement again", async () => {
        const amount = toUSDCDecimals(10n);
        // generate email inputs
        const inputs = await makeLinodeInputs(emails.linode_oct);
        // transform inputs to contract friendly format
        const redeemLinodeInputs = formatRedeemLinode(inputs);
        // redeem entitlement
        const secret = Fr.random();
        const secretHash = computeSecretHash(secret);
        const receipt = await escrows[0]
          .withWallet(alice)
          .methods.redeem_linode_entitlement(...redeemLinodeInputs, secretHash)
          .send()
          .wait();
        await addPendingShieldNoteToPXE(
          alice,
          usdc.address,
          amount,
          secretHash,
          receipt.txHash
        );
        // check that the balance has decremented from zimburse
        const escrowBalance = await usdc.methods
          .balance_of_public(escrows[0])
          .simulate();
        expect(escrowBalance).toBe(toUSDCDecimals(9980n));
        // redeem the shielded USDC note
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
        expect(recipientBalance).toBe(toUSDCDecimals(10n));
      });
      it.todo("Admin can't re-issue an entitlement");
      it.todo("Admin can nullify the entitlement");
      it.todo("Admin can reissue an entitlement after nullifying the old one");
    });
  });
});

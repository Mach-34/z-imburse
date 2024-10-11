import { describe, expect, jest } from "@jest/globals";
import {
  getInitialTestAccountsWallets,
  createAccounts,
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
import {
  MultiCallEntrypointContract,
  TokenContract,
  ZImburseEscrowContract,
  ZImburseContractRegistryContract,
} from "../../src/artifacts/contracts/index";
import { toUSDCDecimals, fromUSDCDecimals } from "../../src/utils";
import {
  formatRedeemLinode,
  makeLinodeInputs,
} from "../../src/email_inputs/linode";
import { setup, mintToEscrow, addContractsToPXE } from "../utils/index";
import { emails } from "../utils/fs";
import { parseStringBytes } from "../../src/utils";
import { addPendingShieldNoteToPXE } from "../../src/contract_drivers/notes";

const DEFAULT_PXE_URL = "http://localhost";

jest.setTimeout(1000000);

describe("Test deposit to zimburse", () => {
  let externalDeployer: AccountWalletWithSecretKey;
  let escrowAdmin: AccountWalletWithSecretKey;
  let alice: AccountWalletWithSecretKey;
  let bob: AccountWalletWithSecretKey;
  let multicall: MultiCallEntrypointContract;
  let usdc: TokenContract;
  let registry: ZImburseContractRegistryContract;
  let escrows: ZImburseEscrowContract[] = [];

  beforeAll(async () => {
    // setup pxe connection
    const sandboxPXE = await createPXEClient(`${DEFAULT_PXE_URL}:8080`);
    const pxe1 = await createPXEClient(`${DEFAULT_PXE_URL}:8081`);
    const pxe2 = await createPXEClient(`${DEFAULT_PXE_URL}:8082`);
    console.log(
      `Connected to Sandbox & 3 PXE's at "${DEFAULT_PXE_URL}:[8080-8082]"\n`
    );

    // deploy test accounts
    let accounts = await createAccounts(sandboxPXE, 2);
    externalDeployer = accounts[0];
    escrowAdmin = accounts[1];
    accounts = await createAccounts(pxe1, 1);
    alice = accounts[0];
    accounts = await createAccounts(pxe2, 1);
    bob = accounts[0];

    // register recipients for each PXE
    await sandboxPXE.registerRecipient(alice.getCompleteAddress());
    await sandboxPXE.registerRecipient(bob.getCompleteAddress());
    await pxe1.registerRecipient(externalDeployer.getCompleteAddress());
    await pxe1.registerRecipient(escrowAdmin.getCompleteAddress());
    await pxe1.registerRecipient(bob.getCompleteAddress());
    await pxe2.registerRecipient(externalDeployer.getCompleteAddress());
    await pxe2.registerRecipient(escrowAdmin.getCompleteAddress());
    await pxe2.registerRecipient(alice.getCompleteAddress());

    // set multicall
    const nodeInfo = await sandboxPXE.getNodeInfo();
    multicall = await MultiCallEntrypointContract.at(
      nodeInfo.protocolContractAddresses.multiCallEntrypoint,
      externalDeployer
    );

    // deploy contracts
    ({ usdc, registry, escrows } = await setup(externalDeployer, [
      escrowAdmin,
    ]));

    // register contracts for alice and bob
    await addContractsToPXE(alice, usdc, registry, escrows);
    await addContractsToPXE(bob, usdc, registry, escrows);

    // mint usdc to the escrows
    for (const escrow of escrows) {
      await mintToEscrow(
        usdc,
        escrow.address,
        externalDeployer,
        toUSDCDecimals(10000n)
      );
    }
  });

  describe("Registration", () => {
    it("Register Z-Imburse Escrow", async () => {
      // register the escrow
      await registry
        .withWallet(escrowAdmin)
        .methods.register_escrow(escrows[0].address)
        .send()
        .wait();
      // check that the escrow is registered
      const isRegistered = await registry.methods
        .get_contract_registration_status(escrows[0].address)
        .simulate();
      expect(isRegistered).toBeTruthy();

      // check escrow is first return
      const managedEscrows = await registry.methods
        .get_managed_escrows(escrowAdmin.getAddress(), 0)
        .simulate();
      expect(managedEscrows[0][0]).toEqual(escrows[0].address);
      // check the rest of the fields are zero
      for (let i = 1; i < 10; i++)
        expect(managedEscrows[0][i]).toEqual(AztecAddress.ZERO);
      // check pagination status = over
      expect(managedEscrows[1]).toBeTruthy();
    });

    it("Enroll user within Z-Imburse Escrow", async () => {
      // todo: figure out multicall
      await registry
        .withWallet(escrowAdmin)
        .methods.check_and_register_participant(
          alice.getAddress(),
          "Alice\0",
          escrows[0].address
        )
        .send()
        .wait();
      await registry
        .withWallet(escrowAdmin)
        .methods.check_and_register_participant(
          bob.getAddress(),
          "Bob\0",
          escrows[0].address
        )
        .send()
        .wait();
      // check participants from escrow admin perspective
      const participants = await registry
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
      const aliceEscrows = await registry
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
      const bobEscrows = await registry
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
      it("Give linode recurring entitlement", async () => {
        // give entitlement of 10 usdc
        const amount = toUSDCDecimals(10n);
        await escrows[0]
          .withWallet(escrowAdmin)
          .methods.give_entitlement(alice.getAddress(), amount)
          .send()
          .wait();
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
    });
  });
});

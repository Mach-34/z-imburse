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
import { convertUSDCDecimals } from "../../src/utils";
import {
  formatRedeemLinode,
  makeLinodeInputs,
} from "../../src/email_inputs/linode";
import { setup, mintToEscrow, addContractsToPXE } from "../utils/index";

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
    console.log(`Connected to Sandbox & 3 PXE's at "${DEFAULT_PXE_URL}:[8080-8082]"\n`);

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
        convertUSDCDecimals(10000n)
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
      const managedEscrows = await registry.methods.get_managed_escrows(escrowAdmin.getAddress(), 0).simulate();
      expect(AztecAddress.fromString(managedEscrows[0][0])).toEqual(escrows[0].address);
      const zero = AztecAddress.fromField(Fr.ZERO);
      // check the rest of the fields are zero
      for (let i = 1; i < 10; i++)
        expect(AztecAddress.fromField(managedEscrows[0][i])).toEqual(zero);
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
          escrowAdmin.getAddress(),
          escrows[0].address
        )
        .send()
        .wait();
      await registry
        .withWallet(escrowAdmin)
        .methods.check_and_register_participant(
          bob.getAddress(),
          "Bob\0",
          escrowAdmin.getAddress(),
          escrows[0].address
        )
        .send()
        .wait();
      // check participants from escrow admin perspective
      // todo: paginate until done
      const participants = await registry
        .withWallet(escrowAdmin)
        .methods.get_participants(escrows[0].address, 0)
        .simulate();
      console.log("Participants: ", participants);

      // check enrolled status from participant perspective
      const aliceEnrolled = await registry
        .withWallet(alice)
        .methods.get_participant_escrows(alice.getAddress(), 0)
        .simulate();
      console.log("Alice enrolled: ", aliceEnrolled);

      const bobEnrolled = await registry
        .withWallet(bob)
        .methods.get_participant_escrows(bob.getAddress(), 0)
        .simulate();
      console.log("Bob enrolled: ", bobEnrolled);
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
        //   const amount = 10n * 10n ** 6n;
        //   await zimburse.withWallet(accounts[1]).methods.give_entitlement(accounts[2].getAddress(), amount).send().wait();
        //   // generate email inputs
        //   const inputs = await makeLinodeInputs(emails.linode);
        //   // transform inputs to contract friendly format
        //   const redeemLinodeInputs = formatRedeemLinode(inputs);
        //   // redeem entitlement
        //   const secret = Fr.random();
        //   const secretHash = computeSecretHash(secret);
        //   const receipt = await zimburse.withWallet(accounts[2]).methods.redeem_linode_entitlement(...redeemLinodeInputs, secretHash).send().wait();
        //   await addPendingShieldNoteToPXE(
        //     accounts[2],
        //     usdc.address,
        //     amount,
        //     secretHash,
        //     receipt.txHash
        //   );
        //   // check that the balance has decremented from zimburse
        //   const escrowBalance = await usdc.methods.balance_of_public(zimburse.address).simulate();
        //   expect(escrowBalance).toBe(90n * 10n ** 6n);
        //   // redeem the shielded USDC note
        //   await usdc.withWallet(accounts[2]).methods.redeem_shield(accounts[2].getAddress(), amount, secret).send().wait();
        //   // check that the balance has incremented for the recipient
        //   const recipientBalance = await usdc.withWallet(accounts[2]).methods.balance_of_private(accounts[2].getAddress()).simulate();
        //   expect(recipientBalance).toBe(10n * 10n ** 6n);
      });
    });
  });

  // it("Give entitlement Linode", async () => {
  //   // give entitlement of 10 usdc
  //   const amount = 10n * 10n ** 6n;
  //   await zimburse.withWallet(accounts[1]).methods.give_entitlement(accounts[2].getAddress(), amount).send().wait();

  //   // generate email inputs
  //   const inputs = await makeLinodeInputs(emails.linode);
  //   // transform inputs to contract friendly format
  //   const redeemLinodeInputs = formatRedeemLinode(inputs);
  //   // redeem entitlement
  //   const secret = Fr.random();
  //   const secretHash = computeSecretHash(secret);
  //   const receipt = await zimburse.withWallet(accounts[2]).methods.redeem_linode_entitlement(...redeemLinodeInputs, secretHash).send().wait();
  //   await addPendingShieldNoteToPXE(
  //     accounts[2],
  //     usdc.address,
  //     amount,
  //     secretHash,
  //     receipt.txHash
  //   );
  //   // check that the balance has decremented from zimburse
  //   const escrowBalance = await usdc.methods.balance_of_public(zimburse.address).simulate();
  //   expect(escrowBalance).toBe(90n * 10n ** 6n);
  //   // redeem the shielded USDC note
  //   await usdc.withWallet(accounts[2]).methods.redeem_shield(accounts[2].getAddress(), amount, secret).send().wait();
  //   // check that the balance has incremented for the recipient
  //   const recipientBalance = await usdc.withWallet(accounts[2]).methods.balance_of_private(accounts[2].getAddress()).simulate();
  //   expect(recipientBalance).toBe(10n * 10n ** 6n);
  // })
});

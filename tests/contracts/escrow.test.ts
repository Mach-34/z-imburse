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
import { setup, mintToEscrow } from "../utils/index";

const DEFAULT_PXE_URL = "http://localhost:8080";

jest.setTimeout(1000000);

describe("Test deposit to zimburse", () => {
  let externalDeployer: AccountWalletWithSecretKey;
  let escrowAdmin: AccountWalletWithSecretKey;
  let alice: AccountWalletWithSecretKey;
  let bob: AccountWalletWithSecretKey;
  let pxe: PXE;
  let multicall: MultiCallEntrypointContract;
  let usdc: TokenContract;
  let registry: ZImburseContractRegistryContract;
  let escrows: ZImburseEscrowContract[] = [];

  beforeAll(async () => {
    // setup pxe connection
    pxe = await createPXEClient(DEFAULT_PXE_URL);
    console.log(`Connected to Sandbox PXE at "${DEFAULT_PXE_URL}"\n`);
    // deploy test accounts
    // const testAccounts = await getInitialTestAccountsWallets(pxe);
    const testAccounts = await createAccounts(pxe, 4);
    externalDeployer = testAccounts[0];
    escrowAdmin = testAccounts[1];
    alice = testAccounts[2];
    bob = testAccounts[3];
    // set multicall
    const nodeInfo = await pxe.getNodeInfo();
    multicall = await MultiCallEntrypointContract.at(
      nodeInfo.protocolContractAddresses.multiCallEntrypoint,
      externalDeployer
    );
    // deploy contracts
    ({ usdc } = await setup(externalDeployer, [
      escrowAdmin,
    ]));
    // mint usdc to the escrows
    // for (const escrow of escrows) {
    //   await mintToEscrow(
    //     usdc,
    //     escrow.address,
    //     externalDeployer,
    //     convertUSDCDecimals(10000n)
    //   );
    // }
  });

  describe("Registration", () => {
    // it("Register Z-Imburse Escrow", async () => {
    //   // register the escrow
    //   await registry
    //     .withWallet(escrowAdmin)
    //     .methods.register_escrow(escrows[0].address)
    //     .send()
    //     .wait();
    //   // check that the escrow is registered
    //   const isRegistered = await registry.methods
    //     .get_contract_registration_status(escrows[0].address)
    //     .simulate();
    //   expect(isRegistered).toBeTruthy();
    // });

    // it("Enroll user within Z-Imburse Escrow", async () => {
    //   // todo: figure out multicall
    //   await registry
    //     .withWallet(escrowAdmin)
    //     .methods.register_participant(
    //       alice.getAddress(),
    //       "Alice\0",
    //       escrows[0].address,
    //       escrowAdmin.getAddress()
    //     )
    //     .send()
    //     .wait();
    //   await registry
    //     .withWallet(escrowAdmin)
    //     .methods.register_participant(
    //       bob.getAddress(),
    //       "Bob\0",
    //       escrows[0].address,
    //       escrowAdmin.getAddress()
    //     )
    //     .send()
    //     .wait();
    //   // check participants from escrow admin perspective
    //   // todo: paginate until done
    //   const participants = await registry
    //     .withWallet(escrowAdmin)
    //     .methods.get_participants(escrows[0].address, 0)
    //     .simulate();
    //   console.log("Participants: ", participants);

    //   // check enrolled status from participant perspective
    //   const aliceEnrolled = await registry
    //     .withWallet(alice)
    //     .methods.get_participant_escrows(alice.getAddress(), 0)
    //     .simulate();
    //   console.log("Alice enrolled: ", aliceEnrolled);

    //   const bobEnrolled = await registry
    //     .withWallet(bob)
    //     .methods.get_participant_escrows(bob.getAddress(), 0)
    //     .simulate();
    //   console.log("Bob enrolled: ", bobEnrolled);
    // });

    it("x", async () => {
      console.log("X")
    })

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

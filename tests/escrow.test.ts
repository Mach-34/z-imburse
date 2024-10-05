import { describe, expect, jest } from "@jest/globals";
import {
  createAccounts,
  getInitialTestAccountsWallets,
} from "@aztec/accounts/testing";
import {
  AccountWalletWithSecretKey,
  AztecAddress,
  AztecAddressLike,
  ExtendedNote,
  Fr,
  Note,
  PXE,
  TxHash,
  computeSecretHash,
  createDebugLogger,
  createPXEClient,
} from "@aztec/aztec.js";
import { TokenContract } from "@aztec/noir-contracts.js";
import { ZImburseEscrowContract } from "../src/artifacts/ZImburseEscrow";
import { fileURLToPath } from "url";
import { dirname } from "path";
import { readFileSync } from "fs";
import { formatRedeemLinode, makeLinodeInputs } from "../src/linode";
import { join } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const emails = {
  linode: readFileSync(
    join(__dirname, "./email_verifiers/test-data/linode.eml")
  ),
};

const DEFAULT_PXE_URL = "http://localhost:8080";

async function addPendingShieldNoteToPXE(
  wallet: AccountWalletWithSecretKey,
  usdcAddress: AztecAddress,
  amount: bigint,
  secretHash: Fr,
  txHash: TxHash
) {
  const note = new Note([new Fr(amount), secretHash]);
  const extendedNote = new ExtendedNote(
    note,
    wallet.getAddress(),
    usdcAddress,
    TokenContract.storage.pending_shields.slot,
    TokenContract.notes.TransparentNote.id,
    txHash
  );
  await wallet.addNote(extendedNote);
}
jest.setTimeout(1000000);

describe("Test deposit to zimburse", () => {
  let accounts: AccountWalletWithSecretKey[] = [];
  let pxe: PXE;
  let usdc: TokenContract;
  let zimburse: ZImburseEscrowContract;
  beforeAll(async () => {
    // setup pxe connection
    pxe = await createPXEClient(DEFAULT_PXE_URL);
    console.log(`Connected to Sandbox PXE at "${DEFAULT_PXE_URL}"\n`);
    // deploy test accounts
    accounts = await createAccounts(pxe, 4);
    console.log(`Created ${accounts.length} test accounts:`);
    console.log(`Token Admin: ${accounts[0].getAddress()}`);
    console.log(`Z-Imburse Admin: ${accounts[1].getAddress()}`);
    console.log(`Alice: ${accounts[2].getAddress()}`);
    console.log(`Bob: ${accounts[3].getAddress()}\n`);
    // deploy usdc token
    usdc = await TokenContract.deploy(
      accounts[0],
      accounts[0].getAddress(),
      "USDC",
      "USD Token",
      6n
    )
      .send()
      .deployed();
    console.log(`Deployed USDC token at ${usdc.address}\n`);
    // mint usdc tokens to the z-imburse admin account
    const secret = Fr.random();
    let secretHash = computeSecretHash(secret);
    const amount = 100000n * 10n ** 6n;
    const receipt = await usdc
      .withWallet(accounts[0])
      .methods.mint_private(amount, secretHash)
      .send()
      .wait();
    await addPendingShieldNoteToPXE(
      accounts[1],
      usdc.address,
      amount,
      secretHash,
      receipt.txHash
    );
    console.log(
      `Privately minted ${amount} USDC to the Z-Imburse admin account\n`
    );
    // redeem the tokens to the z-imburse admin account
    await usdc
      .withWallet(accounts[1])
      .methods.redeem_shield(accounts[1].getAddress(), amount, secret)
      .send()
      .wait();
    console.log(`Redeemed ${amount} USDC to the Z-Imburse admin account\n`);
    // deploy Z-Imburse contract
    zimburse = await ZImburseEscrowContract.deploy(
      accounts[1],
      usdc.address,
      "Test Z-Imburse"
    )
      .send()
      .deployed();
    console.log(`Deployed Z-Imburse contract at ${zimburse.address}\n`);
  });

  describe("Escrow", () => {
    it("Deposit", async () => {
      const amount = 100n * 10n ** 6n;
      await usdc
        .withWallet(accounts[1])
        .methods.unshield(accounts[1].getAddress(), zimburse.address, amount, 0)
        .send()
        .wait();
      // get balance
      const balance = await usdc.methods
        .balance_of_public(zimburse.address)
        .simulate();
      console.log("Balance: ", balance);
      expect(balance).toBe(amount);
    });
  });

  it("Give entitlement Linode", async () => {
    // give entitlement of 10 usdc
    const amount = 10n * 10n ** 6n;
    await zimburse.withWallet(accounts[1]).methods.give_entitlement(accounts[2].getAddress(), amount).send().wait();

    // generate email inputs
    const inputs = await makeLinodeInputs(emails.linode);
    // transform inputs to contract friendly format
    const redeemLinodeInputs = formatRedeemLinode(inputs);
    // redeem entitlement
    const secret = Fr.random();
    const secretHash = computeSecretHash(secret);
    const receipt = await zimburse.withWallet(accounts[2]).methods.redeem_linode_entitlement(...redeemLinodeInputs, secretHash).send().wait();
    await addPendingShieldNoteToPXE(
      accounts[2],
      usdc.address,
      amount,
      secretHash,
      receipt.txHash
    );
    // check that the balance has decremented from zimburse
    const escrowBalance = await usdc.methods.balance_of_public(zimburse.address).simulate();
    expect(escrowBalance).toBe(90n * 10n ** 6n);
    // redeem the shielded USDC note
    await usdc.withWallet(accounts[2]).methods.redeem_shield(accounts[2].getAddress(), amount, secret).send().wait();
    // check that the balance has incremented for the recipient
    const recipientBalance = await usdc.withWallet(accounts[2]).methods.balance_of_private(accounts[2].getAddress()).simulate();
    expect(recipientBalance).toBe(10n * 10n ** 6n);
  })
});

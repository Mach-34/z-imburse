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
  makeUnitedInputs,
} from "../../src/email_inputs/united";
import { dkimPubkeyToHash } from "../../src/dkim";
import { setup, mintToEscrow, addContractsToPXE } from "../utils/index";
import { emails } from "../utils/fs";
import { parseStringBytes } from "../../src/utils";
import { addPendingShieldNoteToPXE } from "../../src/contract_drivers/notes";
import { VERIFIER_IDS } from "../../src/contract_drivers/dkim";

const DEFAULT_PXE_URL = "http://localhost";

jest.setTimeout(1000000);

describe("Test deposit to zimburse", () => {
  let admin: AccountWalletWithSecretKey;
  let claimant: AccountWalletWithSecretKey;
  let escrow: ZImburseEscrowContract;

  beforeAll(async () => {
    // setup pxe connection
    const sandboxPXE = await createPXEClient(`${DEFAULT_PXE_URL}:8080`);
    
    // console.log(
    //   `Connected to Sandbox & 4 PXE's at "${DEFAULT_PXE_URL}:[8080-8083]"\n`
    // );

    // deploy test accounts
    admin = await createAccount(sandboxPXE);
    claimant = await createAccount(sandboxPXE);


    // deploy contracts
    escrow = await ZImburseEscrowContract.deploy(
        admin,
        admin.getAddress(),
        admin.getAddress(),
        `Escrow`
      )
        .send()
        .deployed();
  });

  describe("Test Partial Hash", () => {
    it("Try partial hashing stuff", async () => {
        const unitedInputs = await makeUnitedInputs(emails.united);
        // console.log("Amount sequence", unitedInputs.amount_sequence);
        // console.log("Airport sequence", unitedInputs.airport_sequence);
        // console.log("Date sequence", unitedInputs.date_sequence);
    })
  });
});

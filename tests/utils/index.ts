import {
  AccountWalletWithSecretKey,
  AztecAddress,
  ContractBase,
  ContractInstanceWithAddress,
  Fr,
  computeSecretHash,
} from "@aztec/aztec.js";
import { getEscrowContractClassID } from "../../src/contract_drivers";
import { addPendingShieldNoteToPXE } from "../../src/contract_drivers/notes";
import { USDC_TOKEN } from "../../src/constants";
import {
  MultiCallEntrypointContract,
  TokenContract,
  ZImburseEscrowContract,
  ZImburseEscrowRegistryContract,
  ZImburseDkimRegistryContract,
} from "../../src/artifacts/contracts/index";
import { prepareDKIMKeysForInputs } from "../../src/contract_drivers/dkim";

/**
 * Deploys the contracts needed for the tests
 *
 * @param superuser The admin account for usdc, registry contracts
 * @param escrowAdmin The deployer account for escrow contracts
 */
export async function setup(
  superuser: AccountWalletWithSecretKey,
  escrowAdmin: AccountWalletWithSecretKey[],
  numEscrows: number = 1,
  verbose = true
): Promise<{
  usdc: TokenContract;
  dkimRegistry: ZImburseDkimRegistryContract;
  escrowRegistry: ZImburseEscrowRegistryContract;
  escrows: ZImburseEscrowContract[];
}> {
  if (numEscrows != escrowAdmin.length) {
    throw new Error(
      "Number of escrow deployers must match the number of escrows"
    );
  }
  const usdc = await TokenContract.deploy(
    superuser,
    superuser.getAddress(),
    USDC_TOKEN.symbol,
    USDC_TOKEN.name,
    USDC_TOKEN.decimals
  )
    .send()
    .deployed();
  if (verbose) console.log(`Deployed USDC token at ${usdc.address}`);
  // deploy dkim registry
  const dkimKeys = prepareDKIMKeysForInputs();
  const dkimRegistry = await ZImburseDkimRegistryContract.deploy(
    superuser,
    dkimKeys[0].map((key) => key.id),
    dkimKeys[0].map((key) => key.keyHash)
  )
    .send()
    .deployed();
  if (verbose) console.log(`Deployed DKIM Registry at ${dkimRegistry.address}`);
  // add remaining keys to registry
  for (let i = 1; i < dkimKeys.length; i++) {
    // cannot be batched as there is a max of 64 notes per tx
    await dkimRegistry.methods.register_dkim_bulk(
      dkimKeys[i].map((key) => key.id),
      dkimKeys[i].map((key) => key.keyHash)
    );
    console.log(`Added batch ${i} to DKIM Registry`);
  }
  // deploy registry contract
  const escrowClassId = getEscrowContractClassID();
  const escrowRegistry = await ZImburseEscrowRegistryContract.deploy(
    superuser,
    dkimRegistry.address,
    usdc.address,
    escrowClassId
  )
    .send()
    .deployed();
  if (verbose)
    console.log(`Deployed Z-Imburse Registry at ${escrowRegistry.address}`);
  // deploy escrow contracts
  const escrows: ZImburseEscrowContract[] = [];
  for (let i = 0; i < numEscrows; i++) {
    const escrow = await ZImburseEscrowContract.deploy(
      escrowAdmin[i],
      dkimRegistry.address,
      escrowRegistry.address,
      usdc.address,
      `Escrow ${i}`
    )
      .send()
      .deployed();
    escrows.push(escrow);
    if (verbose)
      console.log(`Deployed Z-Imburse Escrow ${i} at ${escrow.address}`);
  }

  return {
    usdc,
    dkimRegistry,
    escrowRegistry,
    escrows,
  };
}

/**
 * Add contracts to a PXE
 *
 * @param account - the account connected to the PXE to add the contracts to
 * @param usdc - the USDC token contract instance
 * @param registry - the Z-Imburse registry contract instance
 * @param escrows - the Z-Imburse escrow contract instance
 */
export async function addContractsToPXE(
  account: AccountWalletWithSecretKey,
  contracts: ContractBase[]
) {
  for (const contract of contracts) {
    await account.registerContract({
      instance: contract.instance,
      artifact: contract.artifact,
    });
  }
}

/**
 * Longer process of minting shielded tokens to admin then unshielding to escrow
 * @dev this isn't used in test anymore because we can save two transactions by
 *      minting directly to escrow, but it is useful to show this process
 *
 * @param usdc - the USDC token contract
 * @param escrow - the Z-Imburse escrow contract
 * @param minter - the account wallet to mint the tokens
 * @param escrowAdmin - the account wallet controlling the escrow contract
 * @param amount - the amount of tokens to mint
 * @param verbose - whether to log the minting process
 **/
export async function mintToAdminThenEscrow(
  usdc: TokenContract,
  escrow: ZImburseEscrowContract,
  minter: AccountWalletWithSecretKey,
  escrowAdmin: AccountWalletWithSecretKey,
  amount: bigint,
  verbose = true
) {
  // mint shielded tokens to the z-imburse escrow admin
  const secret = Fr.random();
  let secretHash = computeSecretHash(secret);
  const receipt = await usdc
    .withWallet(minter)
    .methods.mint_private(amount, secretHash)
    .send()
    .wait();
  // claim the shielded tokens as the z-imburse escrow admin
  await addPendingShieldNoteToPXE(
    escrowAdmin,
    usdc.address,
    amount,
    secretHash,
    receipt.txHash
  );
  if (verbose)
    console.log(
      `Privately minted ${amount} USDC to the Z-Imburse admin account`
    );
  // claim the shielded tokens to the z-imburse escrow admin's private balance
  await usdc
    .withWallet(escrowAdmin)
    .methods.redeem_shield(escrowAdmin.getAddress(), amount, secret)
    .send()
    .wait();
  if (verbose)
    console.log(`Redeemed ${amount} USDC to the Z-Imburse admin account`);
  // unshield the tokens to the z-imburse escrow
  await usdc
    .withWallet(escrowAdmin)
    .methods.unshield(escrowAdmin.getAddress(), escrow.address, amount, 0)
    .send()
    .wait();
  if (verbose) console.log(`Unshielded ${amount} USDC to the Z-Imburse escrow`);
}

/**
 * Mint tokens directly into the escrow contract
 *
 * @param usdc - the USDC token contract
 * @param escrowAddress - the address of the escrow contract
 * @param minter - the account wallet to mint the tokens
 * @param amount - the amount of tokens to mint
 * @param verbose - whether to log the minting process
 */
export async function mintToEscrow(
  usdc: TokenContract,
  escrowAddress: AztecAddress,
  minter: AccountWalletWithSecretKey,
  amount: bigint,
  verbose = true
) {
  // mint tokens publicly to the escrow contract
  await usdc
    .withWallet(minter)
    .methods.mint_public(escrowAddress, amount)
    .send()
    .wait();
  if (verbose) console.log(`Minted ${amount} USDC to the escrow contract`);
}

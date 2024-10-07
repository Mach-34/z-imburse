import {
  AccountWalletWithSecretKey,
  AztecAddress,
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
  ZImburseContractRegistryContract,
} from "../../src/artifacts/contracts/index";

/**
 * Deploys the contracts needed for the tests
 *
 * @param externalDeployer The deployer account for non-user contracts
 * @param escrowDeployer The deployer account for escrow contracts
 */
export async function setup(
  externalDeployer: AccountWalletWithSecretKey,
  escrowDeployer: AccountWalletWithSecretKey[],
  numEscrows: number = 1,
  verbose = true
): Promise<{
  usdc: TokenContract;
  // registry: ZImburseContractRegistryContract;
  // escrows: ZImburseEscrowContract[];
}> {
  if (numEscrows != escrowDeployer.length) {
    throw new Error(
      "Number of escrow deployers must match the number of escrows"
    );
  }
  const usdc = await TokenContract.deploy(
    externalDeployer,
    externalDeployer.getAddress(),
    USDC_TOKEN.symbol,
    USDC_TOKEN.name,
    USDC_TOKEN.decimals
  )
    .send()
    .deployed();
  if (verbose) console.log(`Deployed USDC token at ${usdc.address}`);
  // // deploy registry contract
  // const escrowClassId = getEscrowContractClassID();
  // const registry = await ZImburseContractRegistryContract.deploy(
  //   externalDeployer,
  //   escrowClassId
  // )
  //   .send()
  //   .deployed();
  // if (verbose)
  //   console.log(`Deployed Z-Imburse Registry at ${registry.address}`);
  // // deploy escrow contracts
  // const escrows: ZImburseEscrowContract[] = [];
  // for (let i = 0; i < numEscrows; i++) {
  //   const escrow = await ZImburseEscrowContract.deploy(
  //     escrowDeployer[i],
  //     registry.address,
  //     usdc.address,
  //     `Escrow ${i}`
  //   )
  //     .send()
  //     .deployed();
  //   escrows.push(escrow);
  //   if (verbose)
  //     console.log(`Deployed Z-Imburse Escrow ${i} at ${escrow.address}`);
  // }

  return {
    usdc,
    // registry,
    // escrows,
  };
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

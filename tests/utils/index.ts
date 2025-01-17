import {
  AccountWalletWithSecretKey,
  AztecAddress,
  ContractBase,
  ContractInstanceWithAddress,
  Fr,
  computeSecretHash,
} from "@aztec/aztec.js";
import { getEscrowContractClassID } from "../../src/contract_drivers";
import { USDC_TOKEN } from "../../src/constants";
import {
  MultiCallEntrypointContract,
  TokenContract,
  ZImburseEscrowContract,
  ZImburseRegistryContract,
} from "../../src/artifacts/contracts/index";
import dkimKeys from "../../src/dkim/keyHashes.json";

type KeyInput = {
  id: bigint,
  hash: bigint
}

const getDkimInputs = (): KeyInput[][] => {
  const batches: KeyInput[][] = [];
  for (let i = 0; i < dkimKeys.length; i+=4) {
    const batch: KeyInput[] = [];
    for (let j = i; j < i+4; j++) {
      if (j >= dkimKeys.length) {
        batch.push({
          id: BigInt(0),
          hash: BigInt(0)
        })
      } else {
        batch.push({
          id: BigInt(dkimKeys[j].id),
          hash: BigInt(dkimKeys[j].hash)
        });
      }
    }
    batches.push(batch);
  }
  return batches
}

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
  registry: ZImburseRegistryContract;
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
  // deploy registry contract
  const dkimKeys = getDkimInputs();
  const escrowClassId = getEscrowContractClassID();
  const registry = await ZImburseRegistryContract.deploy(
    superuser,
    usdc.address,
    escrowClassId,
    dkimKeys[0].map((key) => key.id),
    dkimKeys[0].map((key) => key.hash)
  )
    .send()
    .deployed();
  if (verbose)
    console.log(`Deployed Z-Imburse Registry at ${registry.address}`);
  // add remaining keys to registry
  for (let i = 1; i < dkimKeys.length; i++) {
    // cannot be batched as there is a max of 64 notes per tx
    await registry.methods.register_dkim_bulk(
      dkimKeys[i].map((key) => key.id),
      dkimKeys[i].map((key) => key.hash)
    ).send().wait();
    console.log(`Added batch ${i} to DKIM Registry`);
  }
  
  // deploy escrow contracts
  const escrows: ZImburseEscrowContract[] = [];
  for (let i = 0; i < numEscrows; i++) {
    const escrow = await ZImburseEscrowContract.deploy(
      escrowAdmin[i],
      registry.address,
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
    registry,
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
  // mint tokens private to the z-imburse escrow admin
  await usdc
    .withWallet(minter)
    .methods.mint_to_private(minter.getAddress(), escrowAdmin.getAddress(), amount)
    .send()
    .wait();
  if (verbose)
    console.log(
      `Privately minted ${amount} USDC to the Z-Imburse admin account`
    );
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
    .methods.mint_to_public(escrowAddress, amount)
    .send()
    .wait();
  if (verbose) console.log(`Minted ${amount} USDC to the escrow contract`);
}

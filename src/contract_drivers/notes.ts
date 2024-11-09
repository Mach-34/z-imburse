import {
  AccountWalletWithSecretKey,
  AztecAddress,
  ExtendedNote,
  Fr,
  Note,
  TxHash,
  Wallet,
} from "@aztec/aztec.js";
import { TokenContract } from "../artifacts/contracts/index.js";

/**
 * Add a pending shielded (transparent) Token note to an account's PXE
 * 
 * @param wallet - The account wallet to add the note to
 * @param usdcAddress - The address of the USDC token contract
 * @param amount - The amount of USDC in the note
 * @param secretHash - the hash of the claim secret known by the note recipient
 * @param txHash - the transaction hash where the note was minted
 */
export async function addPendingShieldNoteToPXE(
  wallet: Wallet,
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

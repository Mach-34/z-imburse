import { FieldLike } from "@aztec/aztec.js";
import savedDkimHashes from "../dkim/keyHashes.json";

/** IDs of verifiers to specify in contract when setting entitlement */
export const VERIFIER_IDS = {
  AWS: 1,
  LINODE: 2,
  HEROKU: 3,
  FRONTIER: 4,
  UNITED: 5,
  AA: 6,
  DELTA: 7,
  UBER: 8,
  LYFT: 9
}

export type DKIMInput = {
  id: FieldLike;
  keyHash: FieldLike;
};

export function prepareDKIMKeysForInputs(chunkSize: number): DKIMInput[][] {
  const inputs: DKIMInput[] = [];

  // ugly but chatgpt thinkin for me
  function traverseAndExtract(current: { [key: string]: any }): void {
    if (typeof current === "object" && current !== null) {
      for (const key in current) {
        if (current.hasOwnProperty(key)) {
          const value = current[key];
          // Check if the object contains both `id` and `keyHash` properties
          if (typeof value.id === "number" && Array.isArray(value.keyHashes)) {
            // For each entry in keyHash, create a separate object with the same `id`
            value.keyHashes.forEach((hash: string) => {
              inputs.push({
                id: value.id,
                keyHash: BigInt(hash),
              });
            });
          } else {
            // Otherwise, keep traversing deeper into the object
            traverseAndExtract(value);
          }
        }
      }
    }
  }

  // traverseAndExtract(savedDkimHashes);
  // save time for now just add hosting keys
  traverseAndExtract(savedDkimHashes.hosting);
  const chunkedInputs: DKIMInput[][] = [];
  for (let i = 0; i < inputs.length; i += chunkSize) {
    chunkedInputs.push(inputs.slice(i, i + chunkSize));
  }
  // pad the last chunk with empty objects
  const lastChunk = chunkedInputs[chunkedInputs.length - 1];
  const lastChunkLength = lastChunk.length;
  for (let i = lastChunkLength; i < chunkSize; i++) {
    lastChunk.push({
      id: 0n,
      keyHash: 0n,
    });
  }
  return chunkedInputs;
}

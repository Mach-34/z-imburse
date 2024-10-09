import forge from "node-forge";
import { BarretenbergSync, Fr } from "@aztec/bb.js";
import * as NoirBignum from "@mach-34/noir-bignum-paramgen";
import { toBigIntBE } from "../utils";

// domains for which we want to accept DKIM keys
// in this version we will lazily fetch every key and add it
// position in array + 1 = verifier ID
export const domains = [
  "amazon.com",
  "linode.com",
  "heroku.com",
  "flyfrontier.com",
  "united.com",
  "aa.com",
  "delta.com",
  "uber.com",
  "lyftmail.com",
];

// export type DKIMKeys = {
//     amazon: bigint[];
//     linode: bigint[];
//     heroku: bigint[];
//     frontier: bigint[];
//     united: bigint[];
//     aa: bigint[];
//     delta: bigint[];
//     uber: bigint[];
//     lyft: bigint[];
// }

export enum VerifierTypes {
    amazon = 1,
    linode = 2,
    heroku = 3,
    frontier = 4,
    united = 5,
    aa = 6,
    delta = 7,
    uber = 8,
    lyft = 9,
}

export type KeyResponse = {
  domain: string;
  selector: string;
  firstSeenAt: string;
  lastSeenAt: string;
  value: string;
};

export function parseDKIMKey(base64Key: string): bigint | null
 {
  const paddingNeeded = base64Key.length % 4 ? 4 - (base64Key.length % 4) : 0;
  const pem = Buffer.from(
    `-----BEGIN PUBLIC KEY-----\n${(
      base64Key + "=".repeat(paddingNeeded)
    ).replace(/.{64}/g, "$&\n")}\n-----END PUBLIC KEY-----`
  );
  try {
    return BigInt(forge.pki.publicKeyFromPem(pem.toString()).n.toString());
  } catch {
    // weird AA case where its like not even a 512 bit key
    return null;
  }
}

export async function fetchDKIMKeys(domain: string): Promise<Array<bigint>> {
  // fetch entries for a domain from the registry
  let url = `https://archive.prove.email/api/key?domain=${domain}`;
  const response = await fetchRetry(url);
  if (!response.ok) {
    console.log(response);
    throw new Error(`Failed to fetch DKIM keys for ${domain}`);
  }
  // parse out the values
  const keyEntries: KeyResponse[] = await response.json();
  const search = /p=([^;]+);?$/;
  const keys = keyEntries.reduce((keys, entry) => {
    const match = entry.value.match(search);
    if (match) {
        const parsed = parseDKIMKey(match[1]);
        if (parsed) keys.add(parsed);
    }
    return keys;
  }, new Set<bigint>());
  return Array.from(keys);
}

export async function getDKIMHashes(domain: string): Promise<Array<bigint>> {
    // get all dkim keys
    const keys = await fetchDKIMKeys(domain);
    // produce pedersen hashes for each key
    let bb: BarretenbergSync;
    try {
        bb = BarretenbergSync.getSingleton();
    } catch {
        bb = await BarretenbergSync.initSingleton();
    }
    return keys.map(key => {
        const dkimKeyLimbs = NoirBignum.splitInto120BitLimbs(
            key,
            key.toString(2).length
        ).map(limb => new Fr(limb));
        const hash = bb.pedersenHash(dkimKeyLimbs, 0);
        return toBigIntBE(hash.value);
    });
}

function wait(delay: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, delay));
}

// Function to perform a fetch request with retries
function fetchRetry(
    url: string,
    delay: number = 1000,
    tries: number = 3,
    fetchOptions: RequestInit = {}
): Promise<Response> {
    // Helper function to handle errors and retry
    function onError(err: any): Promise<Response> {
        const triesLeft = tries - 1;
        if (!triesLeft) {
            return Promise.reject(err); // If no more tries left, reject the Promise with the error
        }
        return wait(delay).then(() => fetchRetry(url, delay, triesLeft, fetchOptions));
    }

    // Perform the fetch request and catch errors to retry
    return fetch(url, fetchOptions).catch(onError);
}

import { describe, expect } from "@jest/globals";
import { verifyDKIMSignature } from "@zk-email/helpers/dist/dkim";
import { makeLinodeInputs } from "../src/email_inputs/linode";
import { getDKIMHashes, domains, fetchDKIMKeys, dkimPubkeyToHash } from "../src/dkim/index";
import { prepareDKIMKeysForInputs } from "../src/contract_drivers/dkim";
import { emails } from "./utils/fs";

describe("Test deposit to zimburse", () => {
  xit("Test", async () => {
    // get example key
    const { publicKey } = await verifyDKIMSignature(emails.linode_oct);
    // get linode key
    const domain = domains[1];
    const keys = await fetchDKIMKeys(domain);
    expect(keys.some((key) => key === publicKey));
    
  });
  xit("Test", async () => {
    const domain = domains[5];
    // get all keys
    const keyHashes = await getDKIMHashes(domain);
    console.log("Domain: ", domain);
    console.log(keyHashes.map((key) => key.toString()));
  })
  xit("Test", async () => {
    const inputs = prepareDKIMKeysForInputs(4);
    console.log(inputs);
  })
  it("Check dkim key hashes line up", async () => {
    const keyHashes = await getDKIMHashes(domains[1]);
    const linodeInputs = await makeLinodeInputs(emails.linode_sep);
    const { publicKey } = await verifyDKIMSignature(emails.linode_oct);
    // hash public keys
    const linodeKeyHash = await dkimPubkeyToHash(linodeInputs.pubkey);
    const regularKeyHash = await dkimPubkeyToHash(publicKey);
    expect(keyHashes.some((key) => key === linodeKeyHash)).toBeTruthy();
    expect(keyHashes.some((key) => key === regularKeyHash)).toBeTruthy();
  })
});

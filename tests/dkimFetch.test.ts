import { describe, expect } from "@jest/globals";
import { verifyDKIMSignature } from "@zk-email/helpers/dist/dkim";
import { getDKIMHashes, domains, fetchDKIMKeys } from "../src/dkim/index";
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
  it("Test", async () => {
    const inputs = prepareDKIMKeysForInputs();
    console.log(inputs);
  })
});

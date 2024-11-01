import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { writeFileSync } from "fs";
import { emails } from "../utils/fs";
import { makeLinodeInputs } from "../../src/email_inputs/linode";
import { LinodeInputs } from "../types";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const OUTPUT_PATH = join(
  __dirname,
  "../../contracts/z_imburse_registry/src/test/utils/email_inputs.nr"
);

// imports used in the generated code
const IMPORTS =
  "use zimburse_verifiers::zkemail::{KEY_LIMBS_2048, Sequence, dkim::RSAPubkey};\n" +
  "use z_imburse_escrow::verifiers::LinodeBillingParams;\n";

/** Formats "Sequence" type for codegen */
function formatSequence(
  index: string | number,
  length: string | number
): string {
  const parsedIndex = typeof index === "string" ? index : index.toString();
  const parsedLength = typeof length === "string" ? length : length.toString();
  return (
    `Sequence {` +
    `\n\t\tindex: ${parsedIndex},` +
    `\n\t\tlength: ${parsedLength}` +
    `\n\t}`
  );
}

/** Formats "BoundedVec" type for codegen */
function formatBoundedVec(
  storage: string[] | number[],
  len: string | number
): string {
  const parsedStorage = storage.map((byte) =>
    typeof byte === "string" ? byte : byte.toString()
  );
  const parsedLen = typeof len === "string" ? len : len.toString();
  return (
    `BoundedVec {` +
    `\n\t\tstorage: [${parsedStorage.join(", ")}],` +
    `\n\t\tlen: ${parsedLen}` +
    `\n\t}`
  );
}

/** Formats "RSAPubkey" type for codegen */
function formatPubkey(
  modulus: string[] | number[],
  redc: string[] | number[]
): string {
  const parsedModulus = modulus.map((limb) =>
    typeof limb === "string" ? limb : limb.toString()
  );
  const parsedRedc = redc.map((limb) =>
    typeof limb === "string" ? limb : limb.toString()
  );
  return (
    `RSAPubkey {` +
    `\n\t\tmodulus: [${parsedModulus.join(", ")}],` +
    `\n\t\tredc: [${parsedRedc.join(", ")}]` +
    `\n\t}`
  );
}

/**
 * Assign values for the struct - either the definition or actual inputs
 * @param fields - the fields to assign for the struct
 * @returns - the codegen for the struct given the assignments
 */
function buildConstStruct(name: string, inputs: LinodeInputs) {
  return (
    `global ${name} = LinodeBillingParams {\n` +
    `\theader: ${formatBoundedVec(
      inputs.header.storage,
      inputs.header.len
    )},\n` +
    `\tpubkey: ${formatPubkey(inputs.pubkey.modulus, inputs.pubkey.redc)},\n` +
    `\tsignature: [${inputs.signature.join(", ")}],\n` +
    `\tdkim_header_sequence: ${formatSequence(
      inputs.dkim_header_sequence.index,
      inputs.dkim_header_sequence.length
    )},\n` +
    `\tbody: ${formatBoundedVec(inputs.body!.storage, inputs.body!.len)},\n` +
    `\tbody_hash_index: ${inputs.body_hash_index},\n` +
    `\tamount_sequence: ${formatSequence(
      inputs.amount_sequence.index,
      inputs.amount_sequence.length
    )},\n` +
    `\tfrom_index: ${inputs.from_index},\n` +
    `\tsubject_index: ${inputs.subject_index},\n` +
    `\tdate_index: ${inputs.date_index},\n` +
    `\treceipt_id_length: ${inputs.receipt_id_length}\n` +
    `};\n`
  );
}

/** Generate inputs and write to the contract dir in tests */
export async function txeInputCodegen(log = true, save = false) {
  let codegen = "";
  // add the imports
  codegen += IMPORTS + "\n";
  // add linode september and october emails
  const linodeSeptember = await makeLinodeInputs(emails.linode_sep);
  const linodeOctober = await makeLinodeInputs(emails.linode_oct);
  codegen += buildConstStruct("LINODE_SEP", linodeSeptember) + "\n";
  codegen += buildConstStruct("LINODE_OCT", linodeOctober);
  if (log) console.log(codegen);
  if (save) writeFileSync(OUTPUT_PATH, codegen);
}

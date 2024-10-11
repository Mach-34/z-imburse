import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { writeFileSync } from "fs";
import { emails } from "../utils/fs";
import { makeLinodeInputs } from "../../src/email_inputs/linode";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const OUTPUT_PATH = join(__dirname, "../../contracts/z_imburse_escrow/src/test/email_inputs.nr");

// stringified struct assignments
type LinodeStructFields = {
  body: string;
  body_hash_index: string;
  body_length: string;
  header: string;
  header_length: string;
  pubkey: string;
  pubkey_redc: string;
  signature: string;
  from_index: string;
  subject_index: string;
  amount_index: string;
  amount_length: string;
  date_index: string;
  receipt_id_length: string;
};

// imports used in the generated code
const IMPORTS =
  `use dep::zimburse_verifiers::{\n` +
  `    constants::{MAX_LINODE_EMAIL_BODY_LENGTH, MAX_LINODE_EMAIL_HEADER_LENGTH},\n` +
  `   zkemail::KEY_LIMBS_2048\n` +
  `};\n`;

// definition of the LinodeInputs struct
const STRUCT_DEF_INPUTS: LinodeStructFields = {
  body: "u8; MAX_LINODE_EMAIL_BODY_LENGTH",
  body_hash_index: "u32",
  body_length: "u32",
  header: "u8; MAX_LINODE_EMAIL_HEADER_LENGTH",
  header_length: "u32",
  pubkey: "u8; KEY_LIMBS_2048",
  pubkey_redc: "u8; KEY_LIMBS_2048",
  signature: "u8; KEY_LIMBS_2048",
  from_index: "u32",
  subject_index: "u32",
  amount_index: "u32",
  amount_length: "u32",
  date_index: "u32",
  receipt_id_length: "u32",
};

/**
 * Assign values for the struct - either the definition or actual inputs
 * @param fields - the fields to assign for the struct
 * @returns - the codegen for the struct given the assignments
 */
function buildStruct(fields: LinodeStructFields) {
  return (
    `    body: [${fields.body}],\n` +
    `    body_hash_index: ${fields.body_hash_index},\n` +
    `    body_length: ${fields.body_length},\n` +
    `    header: [${fields.header}],\n` +
    `    header_length: ${fields.header_length},\n` +
    `    pubkey: [${fields.pubkey}],\n` +
    `    pubkey_redc: [${fields.pubkey_redc}],\n` +
    `    signature: [${fields.signature}],\n` +
    `    from_index: ${fields.from_index},\n` +
    `    subject_index: ${fields.subject_index},\n` +
    `    amount_index: ${fields.amount_index},\n` +
    `    amount_length: ${fields.amount_length},\n` +
    `    date_index: ${fields.date_index},\n` +
    `    receipt_id_length: ${fields.receipt_id_length},\n`
  );
}

/**
 * Build the struct assignment fields for a given email
 * @param email - the raw email to parse and run input generation for
 * @returns - inputs formatted for TXE test input codegen
 */
async function stringifyEmailInputs(
  email: Buffer
): Promise<LinodeStructFields> {
  // generate inputs
  const inputs = await makeLinodeInputs(email);
  // standard inputs
  // todo: change these to numbers in zkemail.nr
  return {
    body: inputs.body!.join(", "),
    body_hash_index: inputs.body_hash_index!,
    body_length: inputs.body_length!,
    header: inputs.header.join(", "),
    header_length: inputs.header_length,
    pubkey: inputs.pubkey.join(", "),
    pubkey_redc: inputs.pubkey_redc.join(", "),
    signature: inputs.signature.join(", "),
    from_index: inputs.from_index.toString(),
    subject_index: inputs.subject_index.toString(),
    amount_index: inputs.amount_index.toString(),
    amount_length: inputs.amount_length.toString(),
    date_index: inputs.date_index.toString(),
    receipt_id_length: inputs.receipt_id_length.toString(),
  };
}

/** Generate inputs and write to the contract dir in tests */
export async function txeInputCodegen() {
  let codegen = "";
  // add the imports
  codegen += IMPORTS;
  // add the struct definition
  codegen +=
    `pub struct LinodeInputs {\n` + buildStruct(STRUCT_DEF_INPUTS) + `}\n`;
  // add the september email
  const sepInputs = await stringifyEmailInputs(emails.linode_sep);
  codegen +=
    `pub const LINODE_SEP: LinodeInputs = {\n` +
    buildStruct(sepInputs) +
    `};\n`;
  // add the october email
  const octInputs = await stringifyEmailInputs(emails.linode_oct);
  codegen +=
    `pub const LINODE_OCT: LinodeInputs = {\n` +
    buildStruct(octInputs) +
    `};\n`;
    // write the generated code to the output file
    writeFileSync(OUTPUT_PATH, codegen);
}

// main()
//     .then(() => console.log(`Generated email inputs at ${OUTPUT_PATH}`))
//     .catch((err) => console.error(err));

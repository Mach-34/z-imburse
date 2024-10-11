import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { readFileSync } from "fs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export const emails = {
  linode_sep: readFileSync(join(__dirname, "../test-data/linode_sep.eml")),
  linode_oct: readFileSync(join(__dirname, "../test-data/linode_oct.eml")),
};

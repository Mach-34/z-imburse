import { join } from "path";
import { fileURLToPath } from "url";
import { dirname } from "path";
import { readFileSync } from "fs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export const emails = {
  frontier: readFileSync(join(__dirname, "../test-data/frontier.eml")),
  linode_sep: readFileSync(join(__dirname, "../test-data/linode_sep.eml")),
  linode_oct: readFileSync(join(__dirname, "../test-data/linode_oct.eml")),
  united: readFileSync(join(__dirname, "../test-data/united.eml"))
};

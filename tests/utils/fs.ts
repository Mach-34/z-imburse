import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { readFileSync } from "fs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export const emails = {
  // americanAirlines: readFileSync(join(__dirname, "../test-data/american-airlines.eml")),
  // frontier: readFileSync(join(__dirname, "../test-data/frontier.eml")),
  linode_sep: readFileSync(join(__dirname, "../test-data/linode_sep.eml")),
  linode_oct: readFileSync(join(__dirname, "../test-data/linode_oct.eml")),
  united: readFileSync(join(__dirname, "../test-data/united.eml"))
};

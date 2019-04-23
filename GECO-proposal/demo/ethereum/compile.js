const path = require("path");
const solc = require("solc");
const fs = require("fs-extra");

const buildPath = path.resolve(__dirname, "build");
fs.removeSync(buildPath);

const instantDXPath = path.resolve(__dirname, "contracts", "InstantDX.sol");
console.log(`First ${instantDXPath}`);
const source = fs.readFileSync(instantDXPath, "utf8");
console.log(`Second ${source}`);
const output = solc.compile(source, 1);
console.log(solc.compile(source, 1));

fs.ensureDirSync(buildPath);

for (let contract in output) {
  fs.outputJsonSync(
    path.resolve(buildPath, `${contract.replace(":", "")}.json`),
    output[contract]
  );
}
const assert = require("assert");
const ganache = require("ganache-cli");
const Web3 = require("web3");
const provider = ganache.provider();
const web3 = new Web3(provider);

const compiledPoolETH = require("../ethereum/build/PoolETH.json");
const compiledEscrowGNO = require("../ethereum/build/EscrowGNO.json");

const MINIMUM_CONTRIBUTION = '1000000000000000000';
const LAST_ASK_GNO = '96529870000000000';  // GNO/ETH coinmarketcap 14 April
const SEED_FUNDING = '1000000000000000000'

let accounts; // accounts that exist on local Ganache network.
let poolETH; // reference to deployed instance of pool contract.

beforeEach(async () => {
  accounts = await web3.eth.getAccounts();

  // .send() method when creating contracts needs to specify gas limit
  poolETH = await new web3.eth.Contract(JSON.parse(compiledPoolETH.interface))
    .deploy({
        data: compiledPoolETH.bytecode,
        arguments:[MINIMUM_CONTRIBUTION, LAST_ASK_GNO] 
    })
    .send({
        value: SEED_FUNDING,
        from: accounts[0],
        gas: "1000000"
    });
});

describe("InstantDX", () => {
  it("deploys a poolETH", () => {
    assert.ok(poolETH.options.address);
  });

  it("sets pool manager, minimum contribution, lastAskGNO and seeds pool", async () => {
    const manager = await poolETH.methods.manager().call();
    assert.equal(accounts[0], manager);
    console.log("manager marked");

    const minimum = await poolETH.methods.minimumContributionETH().call();
    assert.equal(MINIMUM_CONTRIBUTION, minimum);
    console.log("minimum set");

    const lastAskGNO = await poolETH.methods.lastAskGNO().call();
    assert.equal(LAST_ASK_GNO, lastAskGNO);
    console.log("lastAskGNO set");

    const seed = await poolETH.methods.poolFundsETH().call();
    assert.equal(SEED_FUNDING, seed);
    console.log("seeded");
  });
});

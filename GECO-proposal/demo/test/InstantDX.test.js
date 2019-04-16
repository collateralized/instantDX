const assert = require("assert");
const ganache = require("ganache-cli");
const Web3 = require("web3");
const provider = ganache.provider();
const web3 = new Web3(provider);

const compiledPoolETH = require("../ethereum/build/PoolETH.json");
const compiledEscrowGNO = require("../ethereum/build/EscrowGNO.json");

const MINIMUM_CONTRIBUTION = '1000000000000000000';
const LAST_ASK_GNO = '96529870000000000';  // GNO/ETH coinmarketcap 14 April
const SEED_FUNDING = '1000000000000000000';  // 1 ETH
const CONTRIBUTION = '1000000000000000000';  // 1 ETH
const BELOW_MINIMUM = "900000000000000000";  // 0.9 ETH
const BID_GNO = '1000000000000000000';  // 1 ETH

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
        gas: "2000000"
    });
});

describe("InstantDX", () => {
  it("deploys a poolETH", () => {
    assert.ok(poolETH.options.address);
  });

  it("sets pool manager, minimum contribution, lastAskGNO and seeds pool", async () => {
    const manager = await poolETH.methods.manager().call();
    assert.equal(accounts[0], manager);

    const minimum = await poolETH.methods.minimumContributionETH().call();
    assert.equal(MINIMUM_CONTRIBUTION, minimum);

    const lastAskGNO = await poolETH.methods.lastAskGNO().call();
    assert.equal(LAST_ASK_GNO, lastAskGNO);

    const seed = await poolETH.methods.poolFundsETH().call();
    assert.equal(SEED_FUNDING, seed);
  });

  it("allows people to contribute to the pool and marks them as providers ", async () => {
    await poolETH.methods.contribute().send({
      value: CONTRIBUTION,
      from: accounts[1],
      gas: "1000000"
    });

    // Test if contribution in pool
    const poolFunds = await poolETH.methods.poolFundsETH().call();
    assert.equal(poolFunds, "2000000000000000000");  // seed + contribution

    // Test for provider mark
    const isProvider = await poolETH.methods
      .mappingProvidersBOOL(accounts[1])
      .call(  
    );
    assert(isProvider);
  });

  it("requires a minimum contribution", async () => {
    try {
      await pooclETH.methods.contribute().send({
        value: BELOW_MINIMUM,
        from: accounts[1]
      });
      assert(false);
    } catch (err) {
      assert(err);
    }
  });

  it("allows anyone to create an escrow with a payable amount", async () => {
    await poolETH.methods.createEscrowGNO().send({
      value: BID_GNO,
      from: accounts[2],
      gas: "1000000"
    });
  
    [escrowAddress] = await poolETH.methods.getAliveEscrows().call();
    escrow = await new web3.eth.Contract(
      JSON.parse(compiledEscrowGNO.interface),
      escrowAddress
    );
    escrowed = await escrow.methods.bidGNOinWei().call();
    beneficiary = await escrow.methods.beneficiary().call();

    assert.ok(escrow.options.address);
    assert.equal(BID_GNO, escrowed);
    assert.equal(accounts[2], beneficiary);
  });

  

});

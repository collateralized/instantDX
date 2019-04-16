const assert = require("assert");
const ganache = require("ganache-cli");
const Web3 = require("web3");
const provider = ganache.provider();
const web3 = new Web3(provider);

const compiledPoolETH = require("../ethereum/build/PoolETH.json");
const compiledEscrowGNO = require("../ethereum/build/EscrowGNO.json");

const GAS1 = "1000000";
const GAS2 = "2000000";

const MINIMUM_CONTRIBUTION = '1000000000000000000';
const LAST_ASK_GNO = '96529870000000000';  // GNO/ETH coinmarketcap 14 April
const SEED_FUNDING = '1000000000000000000';  // 1 ETH
const CONTRIBUTION = '1000000000000000000';  // 1 ETH
const BELOW_MINIMUM = "900000000000000000";  // 0.9 ETH
const BID_GNO = '1000000000000000000';  // 1 ETH

let accounts; // accounts that exist on local Ganache network.
let poolETH; // reference to deployed instance of pool contract.
let escrowGNO;  // reference to deployed instance of escrow contract.

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
        gas: GAS2
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

  it("allows to contribute to the pool and registers providers and stake", async () => {
    await poolETH.methods.contribute().send({
      value: CONTRIBUTION,
      from: accounts[1],
      gas: GAS1
    });

    // Test if contribution in pool
    const poolFunds = await poolETH.methods.poolFundsETH().call();
    assert.equal(poolFunds, parseInt(SEED_FUNDING) + parseInt(CONTRIBUTION));

    // Test for provider mark
    const isProvider = await poolETH.methods
      .mappingProvidersBOOL(accounts[1])
      .call(  
    );
    assert(isProvider);

    // Test if correct stake registered
    const registeredStake = await poolETH.methods
      .mappingProvidersETH(accounts[1])
      .call(
    );
    assert.equal(CONTRIBUTION, registeredStake)
  });

  it("requires a minimum contribution", async () => {
    try {
      await poolETH.methods.contribute().send({
        value: BELOW_MINIMUM,
        from: accounts[1]
      });
      assert(false);
    } catch (err) {
      assert(err);
    }
  });

  it(`allows anyone to deploy an escrow with a payable amount
     and processes instant payout 1`, async () => {
    // Pre Sell Order balance
    let balance1 = await web3.eth.getBalance(accounts[2]);
    balance1 = web3.utils.fromWei(balance1, "ether");
    balance1 = parseFloat(balance1)
    console.log("balance ETH prior to sell order: " + balance1);
    
    let sellOrderVolume = BID_GNO;
    sellOrderVolume = web3.utils.fromWei(sellOrderVolume, "ether");
    console.log("Sell Order Volume: " + sellOrderVolume);
    
    // Deploy escrow
    await poolETH.methods.createEscrowGNO().send({
      value: BID_GNO,
      from: accounts[2],
      gas: GAS1
    });
  
    // Check if escrow is deployed
    [escrowAddress] = await poolETH.methods.getAliveEscrows().call();
    escrow = await new web3.eth.Contract(
      JSON.parse(compiledEscrowGNO.interface),
      escrowAddress
    );
    assert.ok(escrow.options.address);
    
    // Check deployed escrows state variable getters
    const escrowed = await escrow.methods.bidGNOinWei().call();
    const beneficiary = await escrow.methods.beneficiary().call();
    assert.equal(BID_GNO, escrowed);
    assert.equal(accounts[2], beneficiary);

    
    // Check if instant payout1 was processed
    let payout1 = await poolETH.methods.DEMO_payable1ToUserETH().call();
    payout1 = web3.utils.fromWei(payout1, "ether");
    payout1 = parseFloat(payout1)
    console.log("Instant payout1 in ETH: " + payout1);
    
    let balance2 = await web3.eth.getBalance(accounts[2]);
    balance2 = web3.utils.fromWei(balance2, "ether");
    balance2 = parseFloat(balance2)
    console.log("Balance ETH after sell order submission and instant payout: " + balance2);
    
    let gasLimit = web3.utils.fromWei(GAS1, "ether");
    gasLimit = parseFloat(gasLimit);

    let expectedBalance2 = balance1 - sellOrderVolume - gasLimit + payout1;
    assert(balance2 + 0.1 > expectedBalance2
           && balance2 - 0.1 < expectedBalance2
    );
  });
  
  

});

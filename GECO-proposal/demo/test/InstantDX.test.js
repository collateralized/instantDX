/* 
To test your package.json needs to have this:
...
"scripts": {
  "test": "mocha"
},
"author": "",
"license": "ISC",
"dependencies": {
  "ganache-cli": "^6.4.3",
  "mocha": "^6.1.3",
  "solc": "^0.4.25",
  "truffle-hdwallet-provider": "^1.0.6",
  "web3": "^1.0.0-beta.35"
}
}

Then:
$ npm run test

*/

const assert = require("assert");
const ganache = require("ganache-cli");
const Web3 = require("web3");
const provider = ganache.provider();
const web3 = new Web3(provider);

const compiledPool = require("../ethereum/build/Pool.json");
const compiledEscrow = require("../ethereum/build/Escrow.json");

// Currency = ETH
const GAS1 = "1000000";
const GAS2 = "2000000";

const BUY_TOKEN = "GNO";
const SELL_TOKEN = "ETH";
const MINIMUM_CONTRIBUTION = '1000000000000000000';  // 1 ETH
const SEED_FUNDING = '2000000000000000000';  // 2 ETH
const CONTRIBUTION = '1000000000000000000';  // 1 ETH
const BELOW_MINIMUM = "900000000000000000";  // 0.9 ETH
const LAST_ASK_NUMERATOR = 99;  // 1 ETH = 0.99 GNO
const LAST_ASK_DENOMINATOR = 1000 // 1 ETH = 0.99 GNO
const NEW_ASK_NUMERATOR = 90;  // 1 ETH = 0.90 GNO
const NEW_ASK_DENOMINATOR = 1000;  // 1 ETH = 0.90 GNO
const LVR_NUMERATOR = 80;  // 0.8 Loan-To-Value ratio
const LVR_DENOMINATOR = 100;  // 0.8 Loan-To-Value ratio
const INTEREST_RATE_NUMERATOR = 5;  // 0.005 interest rate
const INTEREST_RATE_DENOMINATOR = 1000;  // 0.005 interest rate
const INTEREST_PAYOUT_RATE_NUMERATOR = 90;  // 0.9 interest payout rate
const INTEREST_PAYOUT_RATE_DENOMINATOR = 100; // 0.9 interest payout rate
const BID = 1000000000000000000;  // 1 ETH

let accounts; // accounts that exist on local Ganache network.
let pool; // reference to deployed instance of pool contract.
let escrow;  // reference to deployed instance of escrow contract.

beforeEach(async () => {
  accounts = await web3.eth.getAccounts();

  // .send() mod when creating contracts needs to specify gas limit
  pool = await new web3.eth.Contract(JSON.parse(compiledPool.interface))
    .deploy({
        data: compiledPool.bytecode,
        arguments:[MINIMUM_CONTRIBUTION,
                   LAST_ASK_NUMERATOR,
                   LAST_ASK_DENOMINATOR,
                   LVR_NUMERATOR,
                   LVR_DENOMINATOR,
                   INTEREST_RATE_NUMERATOR,
                   INTEREST_RATE_DENOMINATOR,
                   INTEREST_PAYOUT_RATE_NUMERATOR,
                   INTEREST_PAYOUT_RATE_DENOMINATOR
        ] 
    })
    .send({
        value: SEED_FUNDING,
        from: accounts[0],
        gas: GAS2
    });
});

describe("InstantDX", () => {
  it("deploys a pool", () => {
    assert.ok(pool.options.address);
  });

  it("sets pool manager, minimum contribution, lastAskNumerator and seeds pool", async () => {
    const manager = await pool.methods.manager().call();
    assert.equal(accounts[0], manager);

    const minimum = await pool.methods.minimumContribution().call();
    assert.equal(MINIMUM_CONTRIBUTION, minimum);

    const lastAskNumerator = await pool.methods.lastAskNumerator().call();
    assert.equal(LAST_ASK_NUMERATOR, lastAskNumerator);

    const seed = await pool.methods.poolFunds().call();
    assert.equal(SEED_FUNDING, seed);
  });

  it("allows to contribute to the pool and registers providers and stake", async () => {
    await pool.methods.contribute().send({
      value: CONTRIBUTION,
      from: accounts[1],
      gas: GAS1
    });

    // Test if contribution in pool
    const poolFunds = await pool.methods.poolFunds().call();
    assert.equal(poolFunds, parseInt(SEED_FUNDING) + parseInt(CONTRIBUTION));

    // Test for provider mark
    const isProvider = await pool.methods
      .mappingProvidersBOOL(accounts[1])
      .call(  
    );
    assert(isProvider);

    // Test if correct stake registered
    const registeredStake = await pool.methods
      .mappingProvidersStake(accounts[1])
      .call(
    );
    assert.equal(CONTRIBUTION, registeredStake)
  });

  it("requires a minimum contribution", async () => {
    try {
      await pool.methods.contribute().send({
        value: BELOW_MINIMUM,
        from: accounts[1]
      });
      assert(false);
    } catch (err) {
      assert(err);
    }
  });

  it(`allows anyone to deploy an escrow with a payable bid amount,
     it deducts interest and adds it to the interes pot and
     it processes instant payout 1`, async () => {
    // Pool Funds Pre Sell Order and instant payout1
    let funds = await pool.methods.poolFunds().call();
    funds = web3.utils.fromWei(funds, 'ether');
    console.log(`Pool Funds:                                                       ${funds} ${SELL_TOKEN}`);

    // Seller's balance prior to Sell Order 
    let balance1 = await web3.eth.getBalance(accounts[2]);
    balance1 = web3.utils.fromWei(balance1, "ether");
    balance1 = parseFloat(balance1)
    console.log(`Seller's balance ${SELL_TOKEN} prior to sell order:                       ${balance1} ${SELL_TOKEN}`);
    
    // Interest deducted from sell order
    let interest = (BID * INTEREST_RATE_NUMERATOR) / INTEREST_RATE_DENOMINATOR;

    let sellOrderVolume = BID - interest;
    console.log(`Sell Order Volume:                                                ${sellOrderVolume / 10**18} ${SELL_TOKEN}`);
    
    // Last Ask 
    console.log(`Last Ask price ${SELL_TOKEN}/${BUY_TOKEN}:                                           ${await pool.methods.lastAskNumerator().call()}/${await pool.methods.lastAskDenominator().call()}`)
    
    // Check accruedInterest balance before sell order
    let accruedInterest = await pool.methods.accruedInterest().call();
    console.log(`Interest pot balance before sell order:                                  ${accruedInterest / 10**18} ${SELL_TOKEN}`)
    assert.equal(0, accruedInterest);

    // Deploy escrow
    await pool.methods.createEscrow().send({
      value: sellOrderVolume,
      from: accounts[2],
      gas: GAS1
    });
  
    // Check if escrow is deployed
    [escrowAddress] = await pool.methods.getAliveEscrows().call();
    escrow = await new web3.eth.Contract(
      JSON.parse(compiledEscrow.interface),
      escrowAddress
    );
    assert.ok(escrow.options.address);
    
    // Check deployed escrows state variable getters
    const escrowed = await escrow.methods.bid().call();
    // assert.equal(sellOrderVolume, escrowed);

    const beneficiary = await escrow.methods.beneficiary().call();
    assert.equal(accounts[2], beneficiary);

    // Check if interest was retained and added to accruedInterest
    assert.equal(interest, accruedInterest);

    // Check if instant payout1 was processed
    let payout1 = await pool.methods.payable1ToUser().call();
    payout1 = web3.utils.fromWei(payout1Wei, "ether");
    payout1 = parseFloat(payout1);
    console.log(`Instant payout1:                                                  ${payout1} ETH-${BUY_TOKEN}`);
    
    // Pool funds after payout1
    funds = await pool.methods.poolFunds().call();
    funds = web3.utils.fromWei(funds, "ether");
    funds = parseFloat(funds);
    console.log(`Pool Funds after instant payout:                                  ${funds} ${SELL_TOKEN}`);

    let balance2 = await web3.eth.getBalance(accounts[2]);
    balance2 = web3.utils.fromWei(balance2, "ether");
    balance2 = parseFloat(balance2)
    console.log(`Seller's balance after sell order submission and instant payout: ${balance2} ${SELL_TOKEN}
                                                                  ${payout1} ETH-${BUY_TOKEN}`
    );
    
    let gasLimit = web3.utils.fromWei(GAS1, "ether");
    gasLimit = parseFloat(gasLimit);

    let expectedBalance2 = balance1 - sellOrderVolume - gasLimit + payout1;
    assert(balance2 + 0.1 > expectedBalance2
           && balance2 - 0.1 < expectedBalance2
    );
  });
  
  /*it(`allows the escrow sell order to be settled by anyone (DEMO),
      via call to Escrow.settleAndKill() which 1) Transfers the
      auctionReceivables to the Pool, 2) updates Pool.lastAsk,
      3) updates Pool.accruedInterest, 5) deregisters the Escrow
      instance that was settled, 5) pays Pool.payable2ToUser()
      to seller aka beneficiary, 6) kills the settled Escrow instance,
      all in one atomic transaction.`,
      async () => {
    console.log(`Auction Receivable: ${AUCTION_RECEIVABLE} ${BUY_TOKEN}`);
    await escrow.methods.settleAndKill(STRING_AUCTION_RECEIVABLE, NEW_ASK)
      .send({
        value: STRING_AUCTION_RECEIVABLE,
        from: accounts[3],  // Aka the DutchX ;)
        gas: GAS1
    });

    const poolFunds = await web3.eth.getBalance(pool.options.address);
    const payout1 = await pool.methods.payable1ToUser().call();
    
    //assert(poolFunds >= SEED_FUNDING + AUCTION_RECEIVABLE - payout1);
    

  })*/


});

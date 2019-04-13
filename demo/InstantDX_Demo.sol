pragma solidity ^0.4.25;

// InstantDX Payout formula:
    // Payable1ToUser = P0 * Q * LVR
    // AuctionReceivable = P1 * Q  = P0 * Q * LVR
    // Payable2ToUser = AuctionReceivable - Payable1ToUser  - interest
    
    // P0 is price of previous auction 
    // P1 price of upcoming auction, 
    // Q is quantity sold by the seller, 
    // LVR is the loan-to-value ratio,
    // interest is the interest paid to the pool.


// Demo for following use case: Seller wants to trade ETH into GNO
// Demo Version 0 gotcha: all GNO amounts are denominated in wei/ether

// Solidity gotchas:
    // It is always best to let the recipients withdraw their money themselves, instead of using .send()/.transfer()
    // Variables can be declared anywhere, as Solidity uses hoisting at compile-time

// InstantDX style guide:
    
    // functions:
   
    //  function functionName(type arg1, ...)
         // keyword1
         // ....
     // {
         
     // }
     
     // units:
     // always state wei 


contract PoolETH {
    
    // Persisted state variables:
    // gnoPool funds: wei: 100 ether initialised for DEMO
    uint public PoolFundsETH = 100000000000000000000 wei;
    
    // The interest in ETH the PoolETH has accrued
    uint public interestETH;
    
    // TO DO: fixed numbers - solidity floating point clarification
    fixed public InterestRateETH = 0.01;
    
    // For what follows: refer to payout formula stated atop the file
    // lastAuctionPriceGNO == P0;
    // hammerPriceGNO == P1;
    // msg.value == Q;
    // lvrETHGNO: loan-to-value ratio for ETH/GNO trading pair
    
    // LVR = 80% - solidity does not fully support fixed value types yet: 
    // https://solidity.readthedocs.io/en/develop/types.html#fixed-point-numbers
    fixed public lvrETHGNO = 0.8;  
    
    // Normally the last auction price and hammer price that follow  
    //  would be modified by the InstantDX Escrow contract price oracle.
    // For DEMO the prices are hardcoded.

    // P0: Ask price the last Auction settled on in wei: 
    //  For DEMO: 1 GNO == 0.09753840 ETH - coinmarketcap 13 April 17:20 CEST
    uint public lastPriceGNO = 97538400000000000 wei;
    
    // P1: the GNO price upon which the auction settles. 
    //  For DEMO initialised and persisted at 0.1 ETH
    uint public hammerPriceGNO = 100000000000000000 wei;
    
    // Pool contract functionality:
    // 1. Pool verifies that sufficient funds are present to cover the initial instant payout
            //  sidenote: danger here due to blockchain asynchrony 
    // 2. Accepts seller tokens, if sufficient funds are present
    modifier sufficientPoolFunds() {
        require(msg.value < PoolFundsETH - 1000000 wei,  // Leave 1 million wei in pool for gas fees 
                "Denied: InstantDXPool insufficient funds"
        ); 
        _;
    }
    
    // 3. Pool deploys an individual escrow contract: if condition 1 and 2 are met
    // Store all deployed escrowETH instances in mapping
    mapping(address => bool) public aliveEscrows;
    
    function createEthEscrow(uint sellAmountGNO)  // msg.sender == seller
        public
        payable
        sufficientPoolFunds
    {
        address newEscrowGNO = new EscrowGNO(sellAmountGNO, msg.sender);
        aliveEscrows[newEscrowGNO] = true;
        
        // Possible event emittance here: EscrowGNODeployed
        
        // 4. Pool pays out first payout (bridge loan) to the seller
        //  Payable1ToUser = P0 * Q * LVR
        uint payable1toUser = lastPriceGNO * sellAmountGNO * lvrETHGNO;
        msg.sender.transfer(Payable1toUser);
        
        // Possible event emittance here: trasnferredPayable1toUser
    }
    
    // 5. Pool receives tokens after auction settlement from escrow contract.
        // TO DO 
        
    // 6. Pool transfers the second payment to the seller after the auction ends.
    uint auctionReceivableETH;
    uint payable2ToUser;
    
    modifier escrowOnly() {
        require(aliveEscrows[msg.sender]);  // careful: asynchronous updates to mapping
        _;
    }
    
    function update_LastPriceGNO_AuctionReceivable_Payable2ToUser_Interest(uint newPriceGNO, uint sellAmountGNO)
        external
        escrowOnly
    {
        lastPriceGNO = newPriceGNO;
        auctionReceivableETH = newPriceGNO * sellAmountGNO;
        
    }
    
    Payable2To
    
    
}

contract EscrowGNO {
    
    
    constructor(uint sellAmountGNO, address seller)
        public
    {
        
    }
}

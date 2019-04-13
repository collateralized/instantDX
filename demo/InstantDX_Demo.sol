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
     

// Suggestions for Improvment:
    // Variable names:
        // payable1ToUser, payable2ToUser -> payable1ToSeller, payable2ToSeller


contract PoolETH {
    
    // Persisted state variables:
    // gnoPool funds: wei: 100 ether initialised for DEMO
    uint public PoolFundsETH = 100000000000000000000 wei;
    
    // The interest in ETH the PoolETH is accruing
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
    
    // P0: Ask price the last Auction settled on: 
    uint public lastAskGNO;

    // Pool contract functionality:
    // 1. Pool verifies that sufficient funds are present to cover the initial instant payout
            //  sidenote: danger here due to blockchain asynchrony 
    // 2. Accepts seller tokens, if sufficient funds are present
    modifier sufficientPoolFundsETH() {
        require(msg.value < PoolFundsETH - 1000000 wei,  // Leave 1 million wei in pool for gas fees 
                "Denied: InstantDXPool insufficient funds"
        ); 
        _;
    }
    
    // 3. Pool deploys an individual escrow contract: if condition 1 and 2 are met
    // Store all deployed escrowETH instances in mapping
    mapping(address => bool) public aliveEscrows;
    
    function createEscrowGNO(uint sellAmountGNO)  // msg.sender == seller
        public
        payable
        sufficientPoolFundsETH
    {
        address newEscrowGNO = new EscrowGNO(sellAmountGNO, msg.sender);
        aliveEscrows[newEscrowGNO] = true;
        
        // Possible event emittance here: EscrowGNODeployed
        
        // 4. Pool pays out first payout (bridge loan) to the seller
        //  Payable1ToUser = P0 * Q * LVR
        uint payable1ToUserETH = lastAskGNO * sellAmountGNO * lvrETHGNO;
        msg.sender.transfer(payable1ToUserETH);
        
        // Possible event emittance here: trasnferredPayable1toUser
    }
    
    // 5. Pool receives tokens after auction settlement from escrow contract.
        // TO DO 
        
    // 6. Pool transfers the second payment to the seller after the auction ends.
    uint auctionReceivableETH;
    uint payable2ToUserETH;
    
    modifier escrowOnly() {
        require(aliveEscrows[msg.sender]);  // careful: asynchronous updates to mapping
        _;
    }
    
    function update_LastPriceGNO_AuctionReceivable_Interest_transferPayable2(uint newAskGNO, uint sellAmountGNO, address beneficiary)
        external
        escrowOnly
    {
        uint payable1ToUserETH = lastAskGNO * sellAmountGNO * lvrETHGNO;  // duplicate/redundant calc - improvement needed  
        auctionReceivableETH = newAskGNO * sellAmountGNO;
        uint _interestETH = sellAmountGNO * newAskGNO * InterestRateETH;  // local variable
        
        payable2ToUserETH = auctionReceivableETH - payable1ToUserETH - _interestETH;
        
        lastAskGNO = newAskGNO; // state variable update
        interestETH += _interestETH;  // state variable update
        
        beneficiary.transfer(payable2ToUserETH);  // Payout2
        
        // possible event emittance here: payout2Transferred
        
        aliveEscrows[msg.sender] = false;  // state variable update: kill escrow address
        
        // possible event emittance here: escrowDerigestered 
    }
}

contract EscrowGNO {
    
    
    constructor(uint sellAmountGNO, address seller)
        public
    {
        
    }
}

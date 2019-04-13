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
    
    struct Provider {
        address beneficiary;
        uint stakeETH;
    }
    
    Provider[] public providersETH;
    mapping(address => bool) checkProvidersETH;
    
    uint minimumContributionETH;
    uint public poolFundsETH;
    uint public reserveFundsETH;
    
    uint public accruedInterestETH;
    fixed public InterestRateETH = 0.01;  // TO DO: fixed numbers - solidity floating point clarification
    
    // Should only hold max 2 escrows at the same time - ongoingAuctionEscrow and nextAuctionEscrow
    //  hence we need no custom getter function as we only have 2 array indices
    address[2] public aliveEscrows;
    bool aliveEscrowsToggler = false;  // toggle between 0 and 1
    
    constructor(uint _minimumContribution, uint seedFunding)
        public
    {
        minimumContributionETH = _minimumContribution;
        
        // Optional: skin in the game
        poolFundsETH = seedFunding;
        
        // Optional: Provider here is our company account
        Provider memory newProviderETH = Provider({
            beneficiary: msg.sender,
            stakeETH: msg.value
        });
        
        providersETH.push(newProviderETH);
        checkProvidersETH[msg.sender] = true;
    }
    
    // 1. PoolETH allows liquidity providers to contribute 
    function contribute()
        public
        payable
    {
        require(msg.value >= minimumContributionETH,
                "Failed: tx value below minimum contribution threshold"
        );
        
        Provider memory newProviderETH = Provider({
            beneficiary: msg.sender,
            stakeETH: msg.value
        });
        
        providersETH.push(newProviderETH);
        checkProvidersETH[msg.sender] = true;
    }

    // For what follows: refer to payout formula stated atop the file
        // lastAskGNO == P0;
        // msg.value == Q;
        // lvrETHGNO: loan-to-value ratio for ETH/GNO trading pair
    
    // TO DO: solidity does not fully support fixed value types yet: 
    // https://solidity.readthedocs.io/en/develop/types.html#fixed-point-numbers
    fixed public lvrETHGNO = 0.8;
    
    // P0: Ask price the last Auction settled on: 
    uint public lastAskGNO;

    // 2. Pool verifies that sufficient funds are present to cover the initial instant payout
            //  sidenote: danger here due to blockchain asynchrony 
    // 3. Accepts seller tokens, if sufficient funds are present - msg.value == Q. 
    modifier sufficientPoolFundsETH() {
        require(msg.value < poolFundsETH - 1000000 wei,  // Leave 1 million wei in pool for gas fees 
                "Denied: InstantDXPool insufficient funds"
        ); 
        _;
    }
    
    // 4. Pool deploys an individual escrow contract: if condition 1 and 2 are met
    function createEscrowGNO(uint sellAmountGNO)  // msg.sender == seller
        public
        payable
        sufficientPoolFundsETH
    {
        address newEscrowGNO = new EscrowGNO(sellAmountGNO, msg.sender);
        
        // Logic: 2 escrows can be alive at same time and aliveEscrows[2] tracks them
        if (aliveEscrowsToggler) {  
            aliveEscrows[1] = newEscrowGNO;
            aliveEscrowsToggler = false;  // Danger in case of transaction failure
        }
        
        aliveEscrows[0] = newEscrowGNO;
        aliveEscrowsToggler = true;  // Danger in case of transaction failure
        
        // Possible event emission here: EscrowGNODeployed
        
        // 5. Pool pays out first payout (bridge loan) to the seller
        //  Payable1ToUser = P0 * Q * LVR
        uint payable1ToUserETH = lastAskGNO * sellAmountGNO * lvrETHGNO;
        msg.sender.transfer(payable1ToUserETH);
        
        // Possible event emission here: trasnferredPayable1toUser
    }

    modifier escrowOnly() {
        require(aliveEscrows[msg.sender]);  // careful: asynchronous updates to mapping
        _;
    }
    
    function completedAuctionUpdate_transferPayable2(uint newAskGNO, uint sellAmountGNO, address beneficiary)
        external
        payable
        escrowOnly
    {
        
        // 6. Pool receives tokens after auction settlement from escrow contract
        poolFundsETH += msg.value;  // msg.value = funds from auction
        
        // possible event emission: auctionFundsTransferred
        
        // 7. Pool transfers the second payment to the seller after the auction ends.
        uint payable1ToUserETH = lastAskGNO * sellAmountGNO * lvrETHGNO;  // duplicate/redundant calc - improvement needed:
            //Improvement proposal: save first calc in mapping(address => value) payable1ToUserETH and access here 
        uint auctionReceivableETH = newAskGNO * sellAmountGNO;
        uint _interestETH = sellAmountGNO * newAskGNO * InterestRateETH;  // local variable
        
        uint payable2ToUserETH = auctionReceivableETH - payable1ToUserETH - _interestETH;
        
        lastAskGNO = newAskGNO; // state variable update
        interestETH += _interestETH;  // state variable update
        
        beneficiary.transfer(payable2ToUserETH);  // Payout2
        
        // possible event emission here: payout2Transferred
        
        
        // DANGER: state variable update: remove escrow address from aliveEscrows array
        for (uint i = 0; i < 2; i++) {
            aliveEscrows[i] == msg.sender ? aliveEscrows[i] = 0x0 : continue
        }
        // possible event emission here: escrowDeregestered 
    }
    
    // 7. Distributing interest among liquidity providers.
    // TO DO

    

    
    
    
    
    // 
    
}

contract EscrowGNO {
    
    
    constructor(uint sellAmountGNO, address seller)
        public
    {
        
    }
}

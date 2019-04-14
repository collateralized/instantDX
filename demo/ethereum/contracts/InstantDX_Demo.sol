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
    
    // Floating point arithmetic
     // solidity `/` division operator always truncates (round to zero)
     // use currency units for floating point arithmetic - EVM does not support floating points

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
    // Pool manager: whoever deploys the instance of PoolETH
    address public manager;
    
    // Liquidity Provider struct and state variables
    struct Provider {
        address beneficiary;
        uint stakeETH;
    }
    
    Provider[] public providersETH;
    mapping(address => uint) mappingProvidersETH;
    
    modifier providersOnly() {
        require(mappingProvidersETH[msg.sender] > 0);
        _;
    }
    
    // Pool ETH funding and pots
    uint minimumContributionETH;  // DEMO: hardcode it at 1 ether
    uint public poolFundsETH;
    uint public accruedInterestETH;
    uint public reserveFundsETH;

    
    // PoolETH interest rate state variable: DEMO default value 1
    // TO DO: fixed numbers - solidity floating point clarification
    uint public InterestRateETH = 1;  // TO DO: DEMO DEFAULT
    
    // TO DO: solidity does not fully support fixed value types yet: 
    // https://solidity.readthedocs.io/en/develop/types.html#fixed-point-numbers
    // Payout formula: LVR == lvrETHGNO
    uint public lvrETHGNO = 1;  // TO DO: DEMO DEFAULT
    
    // Payout formula P0 == lastAskGNO: Ask price the last Auction settled on: 
    uint public lastAskGNO;  // will be supplied in ether
    
    // Should only hold max 2 escrows at the same time - ongoingAuctionEscrow and nextAuctionEscrow
    //  hence we need no custom getter function as we only have 2 array indices
    address[2] public aliveEscrows;
    mapping(address => bool) public mappingAliveEscrows;
    bool aliveEscrowsToggler = false;  // toggle between 0 and 1
    
    // DEMO _minimumContribution: 1000000000000000000
    // DANGER: lastAsk specified by pool manager introduces weak subjectivity
    constructor(uint _minimumContribution, uint _lastAskGNO, uint seedFunding)  
        public
        payable  // optional 
    {
        // Set Pool Manager
        manager = msg.sender;
        
        minimumContributionETH = _minimumContribution;  
        lastAskGNO = _lastAskGNO;
        
        // Optional: skin in the game: Provider here is Poolo manager account
        poolFundsETH = seedFunding;

        Provider memory newProviderETH = Provider({
            beneficiary: msg.sender,
            stakeETH: msg.value
        });
        
        providersETH.push(newProviderETH);
        mappingProvidersETH[msg.sender] = newProviderETH.stakeETH;
    }
    
    modifier managerOnly() {
        require(msg.sender == manager,
                "Denied: only for Pool Manager"
        );
        _;
    }
    
    // 1 .PoolETH allows manager to adjust lvrETHGNO
    function adjustLVRETHGNO(uint _lvrETHGNO)  // TO DO: DEMO uint: else fixed
        external
        managerOnly
    {
        lvrETHGNO = _lvrETHGNO;
    }
    
    // 2. PoolETH allows manager to adjust interest rate
    function adjustInterestETH(uint _interestRateETH)  // TO DO: DEMO uint: else fixed
        external
        managerOnly
    {
        InterestRateETH = _interestRateETH;
    }
    
    // 3. PoolETH allows liquidity providers to contribute 
    function contribute()
        external
        payable
    {
        require(msg.value >= minimumContributionETH,
                "Denied: tx value below minimum contribution threshold"
        );
        
        Provider memory newProviderETH = Provider({
            beneficiary: msg.sender,
            stakeETH: msg.value
        });
        
        providersETH.push(newProviderETH);
        mappingProvidersETH[msg.sender] = newProviderETH.stakeETH;
    }

    // 4. Pool verifies that sufficient funds are present to cover the initial instant payout
            //  sidenote: danger here due to blockchain asynchrony 
    // 5. Accepts seller tokens, if sufficient funds are present 
    modifier sufficientPoolFundsETH() {
        // msg.value == Q in payout formula. 
        require(msg.value < poolFundsETH,
                "Denied: InstantDXPool insufficient funds"
        ); 
        _;
    }
    
    // 6. Pool deploys an individual escrow contract: if condition 1 and 2 are met
    function createEscrowGNO(uint sellAmountGNO)  // msg.sender == seller
        external
        payable
        sufficientPoolFundsETH
    {
        address newEscrowGNO = new EscrowGNO(sellAmountGNO, msg.sender);
        
        // Logic: 2 escrows can be alive at same time and aliveEscrows[2] tracks them
        // DANGER: state variable update: overwrites/removes finished escrow address from aliveEscrows array
        // DANGER: assumption: the toggler increment/decrement logic is safe - unlikely? due to aborted contract executions
        if (aliveEscrowsToggler) {  
            aliveEscrows[1] = newEscrowGNO;
            aliveEscrowsToggler = false;  // Danger in case of transaction failure
        }
        
        aliveEscrows[0] = newEscrowGNO;
        mappingAliveEscrows[newEscrowGNO] = true;
        aliveEscrowsToggler = true;  // Danger in case of transaction failure

        // Possible event emission here: EscrowGNODeployed
        
        // 7. Pool pays out first payout (bridge loan) to the seller
        // TO DO: DEMO `- 1 ether` hardcoded to simulate floating point arithmetic of lvrETHGNO
        uint payable1ToUserETH  = lastAskGNO * sellAmountGNO * lvrETHGNO;  // Non-DEMO Payable1ToUser = P0 * Q * LVR
        uint DEMO_payable1ToUserETH = payable1ToUserETH - 1 ether;  // DEMO  
        msg.sender.transfer(DEMO_payable1ToUserETH);
        
        // Possible event emission here: trasnferredPayable1toUser
    }

    modifier escrowOnly() {
        require(mappingAliveEscrows[msg.sender]);  // careful: asynchronous updates to mapping
        _;
    }
    
    function completedAuctionUpdate_transferPayable2(uint newAskGNO, uint sellAmountGNO, address beneficiary)
        external
        payable
        escrowOnly
    {
        // 8. Pool receives tokens after auction settlement from escrow contract
        poolFundsETH += msg.value;  // msg.value = funds from auction
        
        // possible event emission: auctionFundsTransferred
        
        // 9. Pool transfers the second payment to the seller after the auction ends.
        //Improvement proposal: save first calc in mapping(address => value) payable1ToUserETH and access here 
        uint payable1ToUserETH  = lastAskGNO * sellAmountGNO * lvrETHGNO;  // duplicate/redundant calc - improvement needed:
        
        // TO DO: DEMO `- 1 ether` hardcoded to simulate floating point arithmetic of lvrETHGNO
        uint DEMO_payable1ToUserETH = payable1ToUserETH - 1 ether;  // DEMO

        uint auctionReceivableETH = newAskGNO * sellAmountGNO;
       
        // non-DEMO: uint _interestETH = sellAmountGNO * newAskGNO * InterestRateETH;  // local variable
        
        // TO DO: DEMO `5 finney` hardcoded to simulate floating point arithmetic of InterestRateETH
        uint DEMO_interestETH = 5 finney;  // DEMO
        
        // non-DEMO: uint payable2ToUserETH = auctionReceivableETH - payable1ToUserETH - _interestETH;
        
        uint DEMO_payable2ToUserETH = auctionReceivableETH - DEMO_payable1ToUserETH - DEMO_interestETH;  // DEMO
        
        lastAskGNO = newAskGNO; // state variable update
        // non-DEMO: accruedInterestETH += _interestETH;  // state variable update
        accruedInterestETH += DEMO_interestETH;  // DEMO

        // non-DEMO: beneficiary.transfer(payable2ToUserETH);
        beneficiary.transfer(DEMO_payable2ToUserETH);  // DEMO Payout2
        
        // possible event emission here: payout2Transferred

        // possible event emission here: escrowDeregestered 
    }
    

    // DANGER: very expensive due to looping over array
    // Should be called on fixed schedule (maybe once a day)
    function interestPayout() 
        external
        // TBD: managerOnly: we could also add this restriction. But centralised.
    {
        // 10. DEMO: Pool disburses interestPayout share among liquidity providers.
        // TO DO: ratio between share in interest among providers and the reserveFundsETH?
        uint payableToProviders = accruedInterestETH / 2;  

        uint length = providersETH.length;
        
        for (uint i = 0; i < length; i++) {
            Provider storage provider = providersETH[i];  // TBD memory?: probably more expensive
            
            // TBD: providerShare float problem
            // Non-DEMO:
            // uint providerShare = (provider.stakeETH / poolFundsETH) * 100;  // TBD: local variable here only for readability 
            // uint providerPayout = payableToProviders / providerShare;  
            
            uint providerPayout = poolFundsETH / length;  // DEMO: no per stake basis 
            
            provider.beneficiary.transfer(providerPayout);
            
            // TBD alternative: accruedInterestETH -= providerPayout; here or outside for-loop?
        }
        
        // 10.1 DEMO: Pool disbures interestPayout share into reserveFundsETH
        uint payableToReserve = payableToProviders;  // TBD: 50:50 ratio only for DEMO purposes
        reserveFundsETH += payableToReserve;
        
        // Need to update accruedInterestETH
        // DANGER!? loop gas exhaustion leads to wrong balance? 
        // no because contract reversts execution state completely?  Maybe no danger after all??
        accruedInterestETH -= payableToProviders - payableToReserve;
    }

    // 11 Funds withdrawal
    function withdrawFromPool(uint withdrawalAmount)
        external
        providersOnly
    {
        uint stakeReceivable = mappingProvidersETH[msg.sender];
        
        require(withdrawalAmount <= stakeReceivable);
        
        msg.sender.transfer(withdrawalAmount);
        
        mappingProvidersETH[msg.sender] = 0;
        poolFundsETH -= withdrawalAmount;
    }
}

contract EscrowGNO {
    
    
    constructor(uint sellAmountGNO, address seller)
        public
    {
        
    }
}
pragma solidity 0.4.25;

// lastAsk GNO: 99907700000000000 wei - 0.09 ether

// Pool Deployed on Rinkeby: 0x32DdbDD6ef19591aF11C5F359418a00Db24432d3

// Contract Pool
contract Pool {
    
    address public manager;

    address[] public providers;
    mapping(address => uint) public mappingProvidersStake;
    mapping(address => bool) public mappingProvidersBOOL;
    
    uint public minimumContribution;  
    uint public poolFunds;
    uint public accruedInterest;
    uint public reserveFunds;
    
    // @Leo - should be 0.005
    uint public interestRateNumerator;
    uint public interestRateDenominator;  

    // @Leo - should be 0.8
    uint public lvrNumerator;
    uint public lvrDenominator;  

    uint public lastAskNumerator;
    uint public lastAskDenominator;

    // Interest vs. Reserve Ratio
    uint public interestPayoutRateNumerator;
    uint public interestPayoutRateDenominator;

    address[2] public aliveEscrows;
    mapping(address => bool) public mappingAliveEscrows;
    bool internal aliveEscrowsToggler = false;  

   // set parameters for last ask here
    constructor(uint _minimumContribution, 
                uint _lastAskNumerator, uint _lastAskDenominator,
                uint _lvrNumerator, uint _lvrDenominator,
                uint _interestRateNumerator, uint _interestRateDenominator,
                uint _interestPayoutRateNumerator, uint _interestPayoutRateDenominator
    )  
        public
        payable  
    {
        manager = msg.sender;
        
        minimumContribution = _minimumContribution; 
        lastAskNumerator = _lastAskNumerator;
        lastAskDenominator = _lastAskDenominator; 
        lvrNumerator= _lvrNumerator;
        lvrDenominator = _lvrDenominator;
        interestRateNumerator = _interestRateNumerator;
        interestRateDenominator = _interestRateDenominator;
        interestPayoutRateNumerator = _interestPayoutRateNumerator;
        interestPayoutRateDenominator = _interestPayoutRateDenominator;
        
        poolFunds = msg.value;
        
        providers.push(msg.sender);
        mappingProvidersStake[msg.sender] = msg.value;
        mappingProvidersBOOL[msg.sender] = true;
    }

    
    // Fallback function: https://www.bitdegree.org/learn/solidity-fallback-functions
    function ()
        public  // escrowOnly??
        payable 
    {
        poolFunds += msg.value;
    }
 
    
    modifier managerOnly() {
        require(msg.sender == manager,
                "Denied: only for Pool Manager"
        );
        _;
    }
    
    function adjustLVR(uint _lvrNumerator, uint _lvrDenominator)  
        external
        managerOnly
    {
        lvrNumerator = _lvrNumerator;
        lvrDenominator = _lvrDenominator;
    }
    
    function adjustInterestRate(uint _interestRateNumerator, uint _interestRateDenominator)  
        external
        managerOnly
    {
        interestRateNumerator = _interestRateNumerator;
        interestRateDenominator = _interestRateDenominator;
    }


    function contribute()
        external
        payable
    {
        require(msg.value >= minimumContribution,
                "Denied: tx value below minimum contribution threshold"
        );
        
        poolFunds += msg.value;
        
        if (mappingProvidersBOOL[msg.sender] == false) { 
            providers.push(msg.sender);
            mappingProvidersStake[msg.sender] = msg.value;
            mappingProvidersBOOL[msg.sender] = true;
        }
        
        else {
            mappingProvidersStake[msg.sender] += msg.value;
        }
    }
    
    function getProviders()
        public 
        view 
        returns (address[])
    {
        return providers;
    }

    
    modifier sufficientPoolFunds() {
        require(msg.value <= poolFunds,
                "Denied: InstantDXPool insufficient funds"
        ); 
        _;
    }

    uint public payable1ToUser;
    
    function createEscrow()  
        external
        payable
        sufficientPoolFunds
    {   
        // Retain Interest in accruedInterest pot
        uint interest = (msg.value * interestRateNumerator) / interestRateDenominator;
        accruedInterest += interest;

        // The sell volume that is placed on DutchX by InstantDX on seller's behalf
        uint bid = msg.value - interest;

        // Deploy sell order escrow instance
        address newEscrow = (new Escrow).value(bid)(address(this), msg.sender);
        
        // To manage aliveEscrows[2] static array size of 2
        if (aliveEscrowsToggler == true) {  
            aliveEscrows[1] = newEscrow;
            aliveEscrowsToggler = false;  
        }
        else {
            aliveEscrows[0] = newEscrow;
            aliveEscrowsToggler = true; 
        }

        mappingAliveEscrows[newEscrow] = true;

        // Calculate: payout1 = P0 * Q * LVR
        // Example: 0.09 ether lastAsk * 1 ether bid * 0.8 lvr
        payable1ToUser = (lastAskNumerator * bid * lvrNumerator) / (lvrDenominator * lastAskDenominator); 

        // Update pool funds to reflect processed payout1
        poolFunds -= payable1ToUser;

        // Send Instant payout (payout1) to seller
        msg.sender.transfer(payable1ToUser); 
    }

    function getAliveEscrows()
        public 
        view 
        returns (address[2])
    {
        return aliveEscrows;
    }
    
    function deregisterEscrow(address aliveEscrow)
        private
    {
        mappingAliveEscrows[aliveEscrow] = false;
    }

    modifier escrowOnly() {
        require(mappingAliveEscrows[msg.sender],
                "Denied: only callable from Escrow address"
        );  
        _;
    }

    uint public payable2ToUser;

    function completedAuctionUpdate_transferPayable2(
        uint newAskNumerator, uint bid, uint _auctionReceivable, address beneficiary
    )
        external
        escrowOnly
    {
        lastAskNumerator = newAskNumerator;
        
        uint _payable1ToUser  = (lastAskNumerator * bid * lvrNumerator) / (lvrDenominator * lastAskDenominator);

        uint auctionReceivable = _auctionReceivable;
        
        payable2ToUser = auctionReceivable - _payable1ToUser;  
        
        deregisterEscrow(msg.sender);
        
        poolFunds -= payable2ToUser;

        beneficiary.transfer(payable2ToUser); 
    }

    uint public providerPayout;
    uint public payableToReserve;

    function interestPayout() 
        external
    {
        // Calculate interest payments payableToProviders in accordance with interestPayoutRate
        uint payableToProviders = (accruedInterest * interestPayoutRateNumerator) / interestPayoutRateDenominator;  
        
        // Calculate interest payments payableToReserve in accordance with interestPayoutRate
        payableToReserve = accruedInterest - payableToProviders; 

        // Update reserveFunds pot balance
        reserveFunds += payableToReserve;

        // Update accruedInterest pot balance
        accruedInterest -= payableToProviders + payableToReserve;

        uint length = providers.length;
        
        for (uint i = 0; i < length; i++) {
            address provider = providers[i];  
            
            // @Leo: help needed: calculate share of providerStake in poolFunds
            // uint providerShare = mappingProvidersStake[provider] / poolFunds;
            // providerPayout = payableToProviders * providerShare;  
            
            // DEMO version: needs rationalNumbers fixing
            // Solidity division truncates towards 0
            if (accruedInterest % length != 0) {
                providerPayout = (accruedInterest / length) + 1;
            }
            else {
                providerPayout = accruedInterest / length;
            } 

            provider.transfer(providerPayout);
        }
    }

    modifier providersOnly() {
        require(mappingProvidersBOOL[msg.sender] == true);
        _;
    }
    
    function withdrawFromPool(uint withdrawalAmount)
        external
        providersOnly
    {
        // Checks-Effects-Interactions pattern: re-entrancy protection
        uint stakeReceivable = mappingProvidersStake[msg.sender];  // Check1
        
        require(withdrawalAmount <= stakeReceivable);  // Check2
        
        mappingProvidersStake[msg.sender] -= withdrawalAmount;  // Effect1
        
        poolFunds -= withdrawalAmount;  // Effect2
        
        msg.sender.transfer(withdrawalAmount);  // Interaction
        
        // Alternative but not good because duplication in providers array
        // if (withdrawalAmount == mappingProvidersStake[msg.sender]) {
            //mappingProvidersBOOL[msg.sender] = false;
        //}
        
        // Problem: looping in interestPayout will also loop over ex-providers
        // TO DO: find way to remove mappingProvidersStake[provider] == 0 entries from providers array
    }
}


// DEMO: no interface with DutchX and DutchX oracle

contract Escrow {
    address public beneficiary;
    address public addressPool;
    uint public bid;

    constructor(address _addressPool, address _beneficiary)
        public
        payable  
    {
        addressPool = _addressPool;
        beneficiary = _beneficiary;
        bid = msg.value;
    }

    function kill()
        private
    {
        selfdestruct(address(this));
    }

    modifier receivablesTransfer(bool condition) {
        require(condition, "must settle all auctionReceivable");
        _;
    }

    function settleAndKill(uint auctionReceivable, uint newAsk)
        external
        payable
        receivablesTransfer(msg.value == auctionReceivable)
    {
        addressPool.call.value(msg.value).gas(3000)();
        Pool(addressPool).completedAuctionUpdate_transferPayable2(
            newAsk, bid, auctionReceivable, beneficiary
        );
        
        kill();
    }
}


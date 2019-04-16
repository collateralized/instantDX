pragma solidity ^0.4.25;

// lastAsk: 99907700000000000 wei


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
    
    uint public InterestRate = 1;  

    uint public lvr = 1;  

    uint public lastAsk;  
    
    address[2] public aliveEscrows;
    mapping(address => bool) public mappingAliveEscrows;
    bool internal aliveEscrowsToggler = false;  

   
    constructor(uint _minimumContribution, uint _lastAsk)  
        public
        payable  
    {
        manager = msg.sender;
        
        minimumContribution = _minimumContribution;  
        lastAsk = _lastAsk;
        
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
    
    function adjustlvr(uint _lvr)  
        external
        managerOnly
    {
        lvr = _lvr;
    }
    
    function adjustInterestRate(uint _InterestRate)  
        external
        managerOnly
    {
        InterestRate = _InterestRate;
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
    
    function getproviders()
        public 
        view 
        returns (address[])
    {
        return providers;
    }

    
    modifier sufficientpoolFunds() {
        require(msg.value <= poolFunds,
                "Denied: InstantDXPool insufficient funds"
        ); 
        _;
    }

    function createEscrow()  
        external
        payable
        sufficientpoolFunds
    {
        uint bid = msg.value;
        address newEscrow = (new Escrow).value(bid)(address(this), msg.sender);
        
        if (aliveEscrowsToggler == true) {  
            aliveEscrows[1] = newEscrow;
            aliveEscrowsToggler = false;  
        }
        else {
            aliveEscrows[0] = newEscrow;
            aliveEscrowsToggler = true; 
        }

        mappingAliveEscrows[newEscrow] = true;

        payable1ToUser  = bid - (lastAsk * (bid / (10**18)) * lvr); 
        DEMO_payable1ToUser = payable1ToUser - 220 finney;

        poolFunds -= DEMO_payable1ToUser;

        msg.sender.transfer(DEMO_payable1ToUser);
    }
    
    uint public payable1ToUser;
    uint public DEMO_payable1ToUser;

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

    
    function completedAuctionUpdate_transferPayable2(
        uint newAsk, uint bid, uint _auctionReceivable, address beneficiary
    )
        external
        escrowOnly
    {
        lastAsk = newAsk; 
        
        uint _payable1ToUser  = bid - (lastAsk * (bid / (10**18)) * lvr);  
    
        uint _DEMO_payable1ToUser = _payable1ToUser - 220 finney;  

        uint auctionReceivable = _auctionReceivable; 
        
        uint DEMO_interest = 50 finney;  
        
        DEMO_payable2ToUser = auctionReceivable - _DEMO_payable1ToUser - DEMO_interest;  
        
        accruedInterest += DEMO_interest; 
        
        deregisterEscrow(msg.sender);
        
        poolFunds -= DEMO_payable2ToUser + DEMO_interest;

        beneficiary.transfer(DEMO_payable2ToUser);  
    }
    
    uint public DEMO_payable2ToUser;



    function interestPayout() 
        external
    {
        uint payableToProviders = accruedInterest / 2;  

        uint length = providers.length;
        
        for (uint i = 0; i < length; i++) {
            address provider = providers[i];  
            
            providerPayout = payableToProviders / length;  
            
            provider.transfer(providerPayout);
        }
        
        payableToReserve = payableToProviders;  
        reserveFunds += payableToReserve;

        accruedInterest -= payableToProviders + payableToReserve;
    }
    uint public providerPayout;
    uint public payableToReserve;


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
    // Type Pool contract (solidity contracts are like classes)
    Pool pool;

    address public beneficiary;
    address public addressPool;
    uint public bid;

    constructor(address _addressPool, address _beneficiary)
        public
        payable  
    {
        pool = Pool(_addressPool);
        require(pool.poolFunds() >= msg.value,
                "Denied: Insufficient funds in pool"
        );
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
        pool.completedAuctionUpdate_transferPayable2(
            newAsk, bid, auctionReceivable, beneficiary
        );
        
        kill();
    }
}




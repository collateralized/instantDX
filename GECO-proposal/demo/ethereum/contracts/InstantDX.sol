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
    uint public interestRate = 1;  

    // @Leo - should be 0.8
    uint public lvrNumerator = 80;
    uint public lvrDenominator = 100;  

    uint public lastAskNumerator = 99;
    uint public lastAskDenominator = 1000;

    address[2] public aliveEscrows;
    mapping(address => bool) public mappingAliveEscrows;
    bool internal aliveEscrowsToggler = false;  

   // set parameters for last ask here
    constructor(uint _minimumContribution)  
        public
        payable  
    {
        manager = msg.sender;
        
        minimumContribution = _minimumContribution;  
        
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
    
    /*function adjustLVR(uint _lvr)  
        external
        managerOnly
    {
        //lvr = _lvr;
    }*/
    
    function adjustInterestRate(uint _interestRate)  
        external
        managerOnly
    {
        interestRate = _interestRate;
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

    function createEscrow()  
        external
        payable
        sufficientPoolFunds
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

        // Leo's help needed
        // example: 0.09 ether lastAsk * 1 ether bid * 0.8 lvr
        payable1ToUser = (lastAskNumerator * bid * lvrNumerator) / (lvrDenominator * lastAskDenominator); 
        DEMO_payable1ToUser = payable1ToUser;

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

    
    /*function completedAuctionUpdate_transferPayable2(
        uint newAsk, uint bid, uint _auctionReceivable, address beneficiary
    )
        external
        escrowOnly
    {
        lastAskNumerator = newAsk; 
        
        uint _payable1ToUser  = bid - (lastAskNumerator * (bid / (10**18)) * lvr);  
    
        //uint _DEMO_payable1ToUser = _payable1ToUser - 220 finney;  

        uint auctionReceivable = _auctionReceivable; 
        
        uint DEMO_interest = 50 finney;  
        
        DEMO_payable2ToUser = auctionReceivable - _DEMO_payable1ToUser - DEMO_interest;  
        
        accruedInterest += DEMO_interest; 
        
        deregisterEscrow(msg.sender);
        
        poolFunds -= DEMO_payable2ToUser + DEMO_interest;

        beneficiary.transfer(DEMO_payable2ToUser); 
    }*/
    
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

    /*function settleAndKill(uint auctionReceivable, uint newAsk)
        external
        payable
        receivablesTransfer(msg.value == auctionReceivable)
    {
        addressPool.call.value(msg.value).gas(3000)();
        Pool(addressPool).completedAuctionUpdate_transferPayable2(
            newAsk, bid, auctionReceivable, beneficiary
        );
        
        kill();
    }*/
}


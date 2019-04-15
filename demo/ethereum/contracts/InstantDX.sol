pragma solidity ^0.4.25;

// lastAskGNO: 96529870000000000 wei


// Contract PoolETH
contract PoolETH {
    
    address public manager;

    address[] public providersETH;
    mapping(address => uint) public mappingProvidersETH;
    mapping(address => bool) public mappingProvidersBOOL;
     
    modifier providersOnly() {
        require(mappingProvidersBOOL[msg.sender] == true);
        _;
    }
    
    uint public minimumContributionETH;  
    uint public poolFundsETH;
    uint public accruedInterestETH;
    uint public reserveFundsETH;
    
    uint public InterestRateETH = 1;  

    uint public lvrETHGNO = 1;  

    uint public lastAskGNO;  
    
    address[2] public aliveEscrows;
    mapping(address => bool) public mappingAliveEscrows;
    bool internal aliveEscrowsToggler = false;  
    
    constructor(uint _minimumContribution, uint _lastAskGNO)  
        public
        payable  
    {
        manager = msg.sender;
        
        minimumContributionETH = _minimumContribution;  
        lastAskGNO = _lastAskGNO;
        
        poolFundsETH = msg.value;
        
        providersETH.push(msg.sender);
        mappingProvidersETH[msg.sender] = msg.value;
        mappingProvidersBOOL[msg.sender] = true;
    }
    
    // Fallback function: https://www.bitdegree.org/learn/solidity-fallback-functions
    function ()
        public  // escrowOnly??
        payable 
    {
        poolFundsETH += msg.value;
        
    }
    
    modifier managerOnly() {
        require(msg.sender == manager,
                "Denied: only for Pool Manager"
        );
        _;
    }
    
    function adjustLVRETHGNO(uint _lvrETHGNO)  
        external
        managerOnly
    {
        lvrETHGNO = _lvrETHGNO;
    }
    
    function adjustInterestRateETH(uint _interestRateETH)  
        external
        managerOnly
    {
        InterestRateETH = _interestRateETH;
    }

    function contribute()
        external
        payable
    {
        require(msg.value >= minimumContributionETH,
                "Denied: tx value below minimum contribution threshold"
        );
        
        poolFundsETH += msg.value;
        
        if (mappingProvidersBOOL[msg.sender] == false) { 
            providersETH.push(msg.sender);
            mappingProvidersETH[msg.sender] = msg.value;
            mappingProvidersBOOL[msg.sender] = true;
        }
        
        else {
            mappingProvidersETH[msg.sender] += msg.value;
        }
    }
    
    function getProvidersETH()
        public 
        view 
        returns (address[])
    {
        return providersETH;
    }

    modifier sufficientPoolFundsETH() {
        require(msg.value < poolFundsETH,
                "Denied: InstantDXPool insufficient funds"
        ); 
        _;
    }
    
    function createEscrowGNO()  
        external
        payable
        sufficientPoolFundsETH
    {
        address newEscrowGNO = new EscrowGNO(msg.sender);
        
        if (aliveEscrowsToggler) {  
            aliveEscrows[1] = newEscrowGNO;
            aliveEscrowsToggler = false;  
        }
        
        aliveEscrows[0] = newEscrowGNO;
        mappingAliveEscrows[newEscrowGNO] = true;
        aliveEscrowsToggler = true;  

        uint payable1ToUserETH  = lastAskGNO * msg.value * lvrETHGNO;  
        uint DEMO_payable1ToUserETH = payable1ToUserETH - 1 ether;  
        msg.sender.transfer(DEMO_payable1ToUserETH);
    }

    function getAliveEscrows()
        public 
        view 
        returns (address[2])
    {
        return aliveEscrows;
    }

    modifier escrowOnly() {
        require(mappingAliveEscrows[msg.sender],
                "Denied: only callable from EscrowGNO address"
        );  
        _;
    }
    
    function completedAuctionUpdate_transferPayable2(
        uint newAskGNO, uint bidGNO, uint _auctionReceivableETH //, address beneficiary
    )
        external
        // payable
        // escrowOnly
    {
        lastAskGNO = newAskGNO; 
        
        uint payable1ToUserETH  = lastAskGNO * (bidGNO / (10**18)) * lvrETHGNO;  
    
        uint DEMO_payable1ToUserETH = payable1ToUserETH - 1 ether;  

        uint auctionReceivableETH = _auctionReceivableETH; 
        
        uint DEMO_interestETH = 5 finney;  
        
        DEMO_payable2ToUserETH = auctionReceivableETH - DEMO_payable1ToUserETH - DEMO_interestETH;  
        
        accruedInterestETH += DEMO_interestETH;  

        // beneficiary.transfer(DEMO_payable2ToUserETH);  
    }
    
    uint public DEMO_payable2ToUserETH;

    function interestPayout() 
        external
    {
        uint payableToProviders = accruedInterestETH / 2;  

        uint length = providersETH.length;
        
        for (uint i = 0; i < length; i++) {
            address provider = providersETH[i];  
            
            uint providerPayout = poolFundsETH / length;  
            
            provider.transfer(providerPayout);
        }
        
        uint payableToReserve = payableToProviders;  
        reserveFundsETH += payableToReserve;

        accruedInterestETH -= payableToProviders + payableToReserve;
    }
    
    function withdrawFromPool(uint withdrawalAmount)
        external
        providersOnly
    {
        // Checks-Effects-Interactions pattern: re-entrancy protection
        uint stakeReceivable = mappingProvidersETH[msg.sender];  // Check1
        
        require(withdrawalAmount <= stakeReceivable);  // Check2
        
        mappingProvidersETH[msg.sender] -= withdrawalAmount;  // Effect1
        
        poolFundsETH -= withdrawalAmount;  // Effect2
        
        msg.sender.transfer(withdrawalAmount);  // Interaction
        
        // Alternative but not good because duplication in providersETH array
        // if (withdrawalAmount == mappingProvidersETH[msg.sender]) {
            //mappingProvidersBOOL[msg.sender] = false;
        //}
        
        // Problem: looping in interestPayout will also loop over ex-providers
        // TO DO: find way to remove mappingProvidersETH[provider] == 0 entries from providersETH array
    }
}

// DEMO: REMIX EDITION Contract EscrowGNO
contract EscrowGNO {
    PoolETH poolETH;

    address public beneficiary;
    address public addressPoolETH;
    uint public sellAmountGNO;
    
    bool public settled = false;

    constructor(address _addressPoolETH)
        public
        payable  
    {
        poolETH = PoolETH(_addressPoolETH);
        require(poolETH.poolFundsETH() >= msg.value,
                "Denied: Insufficient funds in pool"
        );
        addressPoolETH = _addressPoolETH;
        beneficiary = msg.sender;
        sellAmountGNO = msg.value;
    }
    
    modifier receivablesTransfer(bool condition) {
        require(condition, "must settle all auctionReceivableETH");
        _;
    }

    function settle(uint auctionReceivableETH, uint newAskGNO)
        external
        payable
        receivablesTransfer(msg.value == auctionReceivableETH)
    {
        addressPoolETH.call.value(msg.value).gas(3000)();
        settled = true;
        sendUpdates(newAskGNO, auctionReceivableETH);
    }
    
    modifier onlyIfSettled(condition) {
        require(condition, "escrow not settled yet");
        _;
    }

    function sendUpdates(uint newAskGNO, uint auctionReceivableETH)
        internal
        onlyIfSettled(settled == true)
    {
        poolETH.completedAuctionUpdate_transferPayable2(
            newAskGNO, sellAmountGNO, auctionReceivableETH
        );  //, sellAmountGNO) , beneficiary);
    } 
    
    modifier onlyPoolETH() {
        require(msg.sender == addressPoolETH);
        _;
    }
    
    function kill()
        external
        onlyPoolETH
    {
        selfdestruct(address(this));
    }
}


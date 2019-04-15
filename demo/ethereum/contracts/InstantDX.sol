pragma solidity ^0.4.25;

// lastAskGNO: 99907700000000000 wei


// Contract PoolETH
contract PoolETH {
    
    address public manager;

    address[] public providersETH;
    mapping(address => uint) public mappingProvidersETH;
    mapping(address => bool) public mappingProvidersBOOL;
    
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
        require(msg.value <= poolFundsETH,
                "Denied: InstantDXPool insufficient funds"
        ); 
        _;
    }

    function createEscrowGNO()  
        external
        payable
        sufficientPoolFundsETH
    {
        uint bidGNOinWei = msg.value;
        address newEscrowGNO = (new EscrowGNO).value(bidGNOinWei)(address(this), msg.sender);
        
        if (aliveEscrowsToggler == true) {  
            aliveEscrows[1] = newEscrowGNO;
            aliveEscrowsToggler = false;  
        }
        else {
            aliveEscrows[0] = newEscrowGNO;
            aliveEscrowsToggler = true; 
        }

        mappingAliveEscrows[newEscrowGNO] = true;

        payable1ToUserETH  = bidGNOinWei - (lastAskGNO * (bidGNOinWei / (10**18)) * lvrETHGNO); 
        DEMO_payable1ToUserETH = payable1ToUserETH;

        poolFundsETH -= DEMO_payable1ToUserETH;

        msg.sender.transfer(DEMO_payable1ToUserETH);
    }
    
    uint public payable1ToUserETH;
    uint public DEMO_payable1ToUserETH;

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
                "Denied: only callable from EscrowGNO address"
        );  
        _;
    }

    
    function completedAuctionUpdate_transferPayable2(
        uint newAskGNO, uint bidGNOinWei, uint _auctionReceivableETH, address beneficiary
    )
        external
        escrowOnly
    {
        lastAskGNO = newAskGNO; 
        
        uint _payable1ToUserETH  = bidGNOinWei - (lastAskGNO * (bidGNOinWei / (10**18)) * lvrETHGNO);  
    
        uint _DEMO_payable1ToUserETH = _payable1ToUserETH - 500;  

        uint auctionReceivableETH = _auctionReceivableETH; 
        
        uint DEMO_interestETH = 50 finney;  
        
        DEMO_payable2ToUserETH = auctionReceivableETH - _DEMO_payable1ToUserETH - DEMO_interestETH;  
        
        accruedInterestETH += DEMO_interestETH; 
        
        deregisterEscrow(msg.sender);
        
        poolFundsETH -= DEMO_payable2ToUserETH + DEMO_interestETH;

        beneficiary.transfer(DEMO_payable2ToUserETH);  
    }
    
    uint public DEMO_payable2ToUserETH;



    function interestPayout() 
        external
    {
        uint payableToProviders = accruedInterestETH / 2;  

        uint length = providersETH.length;
        
        for (uint i = 0; i < length; i++) {
            address provider = providersETH[i];  
            
            providerPayout = payableToProviders / length;  
            
            provider.transfer(providerPayout);
        }
        
        payableToReserve = payableToProviders;  
        reserveFundsETH += payableToReserve;

        accruedInterestETH -= payableToProviders + payableToReserve;
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


// DEMO: no interface with DutchX and DutchX oracle

contract EscrowGNO {
    // Type PoolETH contract (solidity contracts are like classes)
    PoolETH poolETH;

    address public beneficiary;
    address public addressPoolETH;
    uint public bidGNOinWei;

    constructor(address _addressPoolETH, address _beneficiary)
        public
        payable  
    {
        poolETH = PoolETH(_addressPoolETH);
        require(poolETH.poolFundsETH() >= msg.value,
                "Denied: Insufficient funds in pool"
        );
        addressPoolETH = _addressPoolETH;
        beneficiary = _beneficiary;
        bidGNOinWei = msg.value;
    }

    function kill()
        private
    {
        selfdestruct(address(this));
    }

    modifier receivablesTransfer(bool condition) {
        require(condition, "must settle all auctionReceivableETH");
        _;
    }

    function settleAndKill(uint auctionReceivableETH, uint newAskGNO)
        external
        payable
        receivablesTransfer(msg.value == auctionReceivableETH)
    {
        addressPoolETH.call.value(msg.value).gas(3000)();
        poolETH.completedAuctionUpdate_transferPayable2(
            newAskGNO, bidGNOinWei, auctionReceivableETH, beneficiary
        );
        
        kill();
    }
}




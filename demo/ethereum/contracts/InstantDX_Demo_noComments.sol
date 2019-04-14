pragma solidity ^0.4.25;

// lastAskGNO: 96529870000000000 wei

// Contract PoolETH
contract PoolETH {
    
    address public manager;

    address[] public providersETH;
    mapping(address => uint) public mappingProvidersETH;
    
    modifier providersOnly() {
        require(mappingProvidersETH[msg.sender] > 0);
        _;
    }
    
    uint minimumContributionETH;  
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
        
        if (mappingProvidersETH[msg.sender] == 0) { 
            providersETH.push(msg.sender);
            mappingProvidersETH[msg.sender] = msg.value;
        }
        
        else {
            mappingProvidersETH[msg.sender] += msg.value;    
        }

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

    modifier escrowOnly() {
        require(mappingAliveEscrows[msg.sender]);  
        _;
    }
    
    function completedAuctionUpdate_transferPayable2(
        uint newAskGNO, uint bidGNO, address beneficiary
    )
        external
        payable
        escrowOnly
    {
        
        poolFundsETH += msg.value;  
    
        uint payable1ToUserETH  = lastAskGNO * bidGNO * lvrETHGNO;  
    
        uint DEMO_payable1ToUserETH = payable1ToUserETH - 1 ether;  

        uint auctionReceivableETH = newAskGNO * bidGNO; 
        
        uint DEMO_interestETH = 5 finney;  
        
        uint DEMO_payable2ToUserETH = auctionReceivableETH - DEMO_payable1ToUserETH - DEMO_interestETH;  
        
        lastAskGNO = newAskGNO; 
        
        accruedInterestETH += DEMO_interestETH;  

        beneficiary.transfer(DEMO_payable2ToUserETH);  
    }
    
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

        accruedInterestETH -= payableToProviders - payableToReserve;
    }
    
    function withdrawFromPool(uint withdrawalAmount)
        external
        providersOnly
    {
        uint stakeReceivable = mappingProvidersETH[msg.sender];
        
        require(withdrawalAmount <= stakeReceivable);
        
        msg.sender.transfer(withdrawalAmount);
        
        mappingProvidersETH[msg.sender] -= withdrawalAmount;
        poolFundsETH -= withdrawalAmount;
    }
}

// Contract EscrowGNO
contract EscrowGNO {
    PoolETH poolETH;

    address public beneficiary;

    constructor(address _beneficiary)
        public
        payable  
    {
        poolETH = PoolETH(msg.sender);  
        beneficiary = _beneficiary;
    }

    function settle(uint newAskGNO)
        external
        payable
    {
        poolETH.completedAuctionUpdate_transferPayable2(newAskGNO, msg.value, beneficiary);
                // .value(newAskGNO * msg.value)
                // .gas(800)(); 
    }
}
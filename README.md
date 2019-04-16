# Project Overview

#### Abstract
[Quote](https://blog.gnosis.pm/the-mechanism-design-of-the-gnosis-dutch-exchange-4299a045d523) by Nadja Beneš:
*“The Dutch Auction mechanism is game theoretically known to be an efficient way of determining a fair market price for fungible goods. One drawback of the auction model is that the exchange is not instantaneous (and funds can’t immediately be withdrawn), which makes fast trading impossible.“*

InstantDX is an application built on top of DutchX that will provide an instant payout option to sellers, enabling them to opt out of the various drawbacks associated with having one’s liquidity locked up in long-running DutchX auctions. Instead, they can receive part of their expected payout instantaneously in the form of a bridge loan from the InstantDX liquidity pool. The initial immediate payout is followed by a second payout, after the auction has cleared, to settle the total remaining balance payable to the seller at the actual price that was discovered in the auction.

This will allow users of the DutchX to benefit from all of its benefits, such as fair pricing, gas efficiency, smart-contract enabled trading and the impossibility of front-running, while still being able to perform actions that require an instant exchange of tokens, such as:
- Interacting with dapps
- Paying down large CDPs
- Paying infrastructure fees without the need to hold the network token in large reserves
- Applying certain risk management techniques, to avoid financial losses or make a profit.
- Earning an interest by lending out their liquidity
… and many more.

#### Why did we decide to build InstantDX?
Current decentralized exchanges enable their users to retain true ownership of their assets while trading peer-to-peer in open markets. However, many of the early implementations suffer from flaws concerning their fairness and decentralization in crucial aspects, such as their price discovery mechanism. Gnosis Dutch Exchange offers the first fully decentralized mechanism for finding fair market prices for most crypto assets, especially for those lacking adequate liquidity. In our opinion, being able to always access liquidity at a fair price is essential to create a thriving crypto economy that is not only accessible by the financial and technology savvy, but opens up participation to everyone that wants to be a part of this ecosystem.

However, in order to gain mainstream adoption from both Dapp developers and investors, there needs to be an option to remove the costs of time and illiquidity from the sellers participating in the DutchX mechanism. This is why we think InstantDX can help accelerate the adoption of the DutchX and with it significantly improve the efficiency, fairness and reduce the internal frictions of the Ethereum protocol, in order to fulfil its potential as a global decentralized value transfer protocol.

At the same time, we are very focussed on the possibilities of decentralized lending. Enabling users from all over the world to gain access to cheap capital and move assets from larger investors to smaller ones, allows the creation of wealth to gradually spread more evenly through the ecosystem. Allowing holders of crypto assets to earn an interest on their idle assets is needed to attract more people to switch over to crypto from the old financial institutions, where their dollars in the bank still earn them a ‘risk-free’ interest payment.

We are extremely excited about the improvements the DutchX project and decentralized lending can bring to the current economic systems. We want to contribute to the mainstream adoption of both by providing these synergies to the participants in the ecosystem with continuous liquidity via DutchX-InstantDX. 

--------

### Project description
#### Why DutchX?
Upon learning about DutchX, we felt encouraged to take action and do our part in bringing about the removal or alleviation of some of current problems facing decentralized exchanges, which include 1) lack of full end-to-end decentralization in DEX designs, 2) Ethereum’s gas model and fees, 3) lack of adequate liquidity to determine a fair price and 4) DEXs not facilitating smart contracts buying and selling on them. 

From the stated main problems facing decentralized exchanges today, DutchX sufficiently solves at least the following four of them: 
1. Centralized order books and front-running in current DEX environments
2. Ethereum’s gas fees for cancelled orders.
3. Finding a fair market price for less liquid tokens.
4. Smart-contract enabled trading 

Regarding participation in the DutchX, however, usability constraints undoubtedly emerge for those, who are unwilling to part from liquidity for longer periods of time (~6-12 hours). This concerns any human or smart contract that operates with the need for a continuous flow of liquidity, not just speculators and day-traders. Probably the way people perceive risk in general, and the time-value of money, will urge a significant amount of people to prefer instant order execution over delayed payouts. This hurdle to adoption is exactly what InstantDX aims to remove.

#### A detailed description of the project:
First of all, we would like to make it clear that when we refer to ‘users’, ‘participators’  or ‘sellers’ in what follows, we include both smart contracts and humans in our thinking. Indeed we expect that, sooner or later, a majority of direct traders on the DutchX will likely be smart contracts. 

Gnosis vision is to “build new market mechanisms to enable the distribution of resources—from assets to incentives, and information to ideas”. We share those ideals and want to contribute to the adoption of the mechanisms that will facilitate a fairer distribution of resources across the upcoming global financial crypto economy. 

The goal of InstantDX is to improve the user experience of the DutchX and to greatly accelerate its adoption. To do so, we plan to extend the DutchX suite of features with an option for sellers to bridge the periods of lost liquidity that are an unfortunate byproduct of the workings of this auction mechanism. The time-span of the auctions is forecasted to last 6 hours at a minimum. However, the duration of seller illiquidity could well average on 10 hours, given that sellers cannot submit asks to ongoing auctions, but have to post sell orders beforehand and then wait for the next auction of their trading pair to begin and clear. 

Here, InstantDX adds significant value to the DutchX, by providing sellers with instantaneous liquidity via our liquidity pool and payout formulae. It does so by opening the DutchX to users, who operate and trade with a continuous need for unrestrained liquidity. Examples include: 1) The need to pay for infrastructure fees, 2) apply risk management techniques, 3) interact with  dapps, or 4) the opportunity to earn interest on their tokens.

The application achieves the provision of instant liquidity by lending sellers the tokens they want to trade into. InstantDX smart contracts source the tokens to be paid out from a liquidity pool, which in its infancy will be funded from whitelisted addresses. In later stages of the project we will further open the funding of the pool to be permissionless. Token holders are incentivized to contribute to the InstantDX pool with the opportunity to earn an interest on their stake. Interest payments to liquidity providers are funded by the DutchX-InstantDX users’ interest payments on the instant liquidity they have received. We also intend to source liquidity from lending protocols such as Compound or Maker in future releases.

*Figure 1: InstantDX standard payout mechanism with the following example parameters: previous auction price: 1 ETH = 100 Dai, instant payout rate (‘loan-to-value ratio’) = 67%, auction price: 1 ETH = 100 Dai, interest rate = 0.1%.*
![InstantDX standard payout mechanism](https://github.com/collateralized/instant-dutchx/blob/master/charts/InstantDX-payout-%20mechanism-%20chart.png "InstantDX standard payout mechanism")

In essence, the application offers DutchX users a new choice in their interactions with the exchange. If instant liquidity and time is not of interest to the seller, they can proceed with the normal auction process. However, if liquidity and time is of importance, as will be the case for many humans and automata, they can gain value from InstantDX in the normal scenario like so:

#### Payout Formula: 

_Note: The payout formula is written from the perspective of the InstantDX liquidity pool_

**Payable1ToUser** = P0 * Q * LVR

**AuctionReceivable** = P1 * Q 

**Payable2ToUser** = AuctionReceivable - Payable1ToUser  - interest

--------

**Where:** 

**P0** is price of previous auction 

**P1** price of upcoming auction, 

**Q** is quantity sold by the seller, 

**LVR** is the loan-to-value ratio ,

**interest** is the interest paid to the pool.

*Figure 2: InstantDX vs. regular DutchX payout process*
![InstantDX vs. regular DutchX payout process chart](https://github.com/collateralized/instant-dutchx/blob/master/charts/InstantDX-vs-DX-payouts-chart.png "InstantDX vs. regular DutchX payout process")

1. A seller wants to sell a certain quantity _**(Q)**_ of a token on the DutchX using InstantDX and sends the tokens to our smart contract.
2. The smart contract places the sell order on the DutchX
3. The InstantDX pool immediately transfers a bridge loan _**(Payable1ToUser)**_, meaning _**Q * LVR (e.g. ~67%)**_ of expected tokens, to the seller using the previous auction price _**(P0)**_ as a benchmark. 
4. The auction settles on a price _**(P1)**_ and clears the total sell volume _**(Q)**_. The purchased tokens _**(AuctionReceivable)**_ are transferred from the DutchX to InstantDX’s smart contracts
5. InstantDX smart contracts pay out the outstanding trade balance _**(Payable2ToUser)**_ to the seller.
6. The interest paid by the seller gets distributed among InstantDXs liquidity providers

In order to protect the liquidity providers of the InstantDX pool against possible black swan events, in which the auction settles on a price for the receivable token that is less than the 1 - LVR safety margin, we introduce three safety mechanisms:

1) For every sale through InstantDX, 10% of the pools earned interest is accumulated within the pools buffer. Those funds will be used to compensate potential losses of the overall pool.
2) Similar to other lending protocols, in our early versions we will only include low risk collateral tokens combined with low LVRs. We intend to gradually introduce more token pairings as the volatility of these assets decreases over time. 
Only in an extreme edge case where these two safety mechanisms fail, the pool automatically conducts safety mechanism number three:
3) Haircutting the entire pools liquidity by the incurred losses. 

We are convinced that despite the aforementioned risk, liquidity providers will still be strongly incentivized to contribute funds to the InstantDX pool. They will be compensated for the minor risk they incur, by having significantly more interest accrue to them compared to that of other lending protocols, like Compound, which aim to be the risk-free rate of the market. This is possible because, even though interest paid by individual sellers participating in the DutchX-InstantDX will be very small, these isolated marginal payments are compensated for in the high sell volumes to be expected on the DutchX. In fact, the interest earned by liquidity providers will accumulate every 6 hours on average.


#### Overall goal and future outlook:

#### Overall goal
The overall goal of the project is to build and seamlessly integrate a first version of InstantDX with the DutchX protocol, in order to enable sellers to be able to receive instant payouts on their DutchX sell orders. Our target users are developers, smart contracts and sophisticated end users that want to provide themselves, or their users, with access to the DutchX auction mechanism and its promise of fair pricing, whilst still having access to instant liquidity, thanks to InstantDX’s real-time payout feature.

#### Future Outlook
After enabling the InstantDX application for the first trading pair, other crypto assets can gradually be added to the offering. Beyond that, the system can offer a variety of additional features to the DutchX users, such as:
1. Automated price insurance, which guarantees the seller a minimum ask price for their sell order by automatically placing a buy order in the auction at a minimum ask price they can specify.
2. Automated lending of sellers’ liquidity on lending platforms, to have instant interest accrue to them.
3. Integrations of InstantDX with other applications, like dapps built on top of MakerDAO that manage CDPs, by enabling them to automatically purchase large sums of Dai on the DutchX instantaneously,  in order to avoid liquidation of their CDPs
4. Usage in prediction markets, such as Gnosis, to provide instant liquidity for certain types of bets when the outcome can be predicted with high probability, similar to the “cash out” service of modern sport betting companies.


# Vortex Liquidity Bounty

A decentralized yield farming and liquidity incentivization protocol built on the Base network. The Vortex Bounty engine allows protocols to reward liquidity providers (LPs) with native assets or protocol tokens based on their proportional share of the total staked pool.

## System Mechanics
* **Dynamic Reward Emission:** Rewards are calculated continuously per second based on the globally configured emission rate and the user's specific pool share.
* **Flash-Loan Mitigation:** Implements a strict block-delay between deposit and harvest actions, preventing malicious actors from using flash loans to extract protocol rewards within a single transaction.
* **Automated Compounding Hooks:** Designed with external hooks to allow trusted auto-compounder bots to harvest and reinvest yields on behalf of users, maximizing APY while saving on gas fees.

## Technical Implementation
Compiled with Solidity `0.8.37`. The protocol utilizes high-precision fixed-point math (`1e18`) to prevent precision loss during reward distribution across thousands of concurrent stakers.

# tfusd-flashloan-attack-write-up
Here's a write-up for the bug I found in 
[tfUSD](https://etherscan.io/address/0xa1e72267084192Db7387c8CC1328fadE470e4149).
The contract owned 50M tusd at the time I reported to the team.


This exploit contract could get 15M of profit in one transaction.
Similar attack pattern could be applied for several txs. With the help of flashbot, attacker could have drained all 50M TSUD in the pool. 


Here's some timeline of reporting the bug.
1. (5/27) found the bug and submitted a report to the team. 
2. (5/28) the team responded and fixed it.
3. (7/2) received bug bounty (500USD).


**I wrote this exploit contract in a rush since the fund was in danger. The exploit contract itself might be buggy. Do not use this contract on mainnet.**

I open this repo for building my resume in order to get in to [Secureum Bootcamp](https://hackmd.io/@secureum/bootcamp-epoch0-announcement). Hope I can make it.

## details
The bug located at the old implementation of tfUSD. https://etherscan.io/address/0x27f461c698844ff51b33ecffa5dc2bd9721060b1#code.

There old implementation had an flush function that every can triggers.
```solidity
   function flush(uint256 currencyAmount, uint256 minMintAmount) external {
```
`flush` should be a function that the team called to flush tusd in the pool into crv pools to utilize the funds in the pool.
This `flush` function would end up add liquidity pool into 3crv pool.


The exploit steps are as follow:
1. borrow TUSD and DAI from aave.
2. Deposit DAI into compound to borrow TUSD.
3. Mutate the TUSD price at 3crv prool (`0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51`)
4. trigger `flush` and force the pool add liquidity to 3crv where TUSD price becomes extremely low.
5. **Buy back TUSD at 3crv pool** (Gain profit at this step.)
6. Repay to TUSD to compound
7. Repay DAI, TUSD to aave
8. Get 15M TUSD profit.

### Why we need flash bot to drain all token

The attack pattern is simliar to [yDai incident](https://peckshield.medium.com/the-ydai-incident-analysis-forced-investment-2b8ac6058eb5).

The attack can do following steps:
1. supply token to the pool
2. exploit it. (see above steps)
3. withdraw token
4. repeat 1-3

However, tfUSD has a better design than yDai. The team was aware (I suppose) of this issue and add a protect.

```solidity
 function exit(uint256 amount) external override nonReentrant {
        require(block.number != latestJoinBlock[tx.origin], "TrueFiPool: Cannot join and exit in same block");
 }
```
They restrict user to join and withdraw at the same transaction.

Thus, the attack should be executed in different txs.
Note that: since the attacker got 15m profit at the first tx. supply token and withdrawing token at step 1 and 3 doesn't need a flashloan. Just try to send txs at the same time to minimize the risk. (in case users exit the pool before the attack is completed.)

## How to reproduce
1. npm i
2. npx hardhat test

Here's setting of hardhat
```js
{
  solidity: "0.6.12",
  networks: {
  hardhat: {
    forking: {
      url: "https://eth-mainnet.alchemyapi.io/v2/{}",
      blockNumber: 12517300
    }
  },
  }, 
  mocha: {
    timeout: 1200000,
  }
}
```

## How to find this bug
Since this bug shares a similar pattern with previous classic attack. We could use [](mutator) to find this.

We will publish the paper and opensource the tool this Sepetember.


## Reference

1. [aave/code-examples-protocol](https://github.com/aave/code-examples-protocol)
2. [The yDAI Incident Analysis: Forced Investment](https://peckshield.medium.com/the-ydai-incident-analysis-forced-investment-2b8ac6058eb5)

# tfusd-flashloan-attack-write-up

The vulnerable contract [tfUSD](https://etherscan.io/address/0xa1e72267084192Db7387c8CC1328fadE470e4149) owned 50M tusd at the time the issue was reported.


This exploit contract could get 15M of profit in one transaction.
Similar attack pattern could be applied for several txs. With the help of flashbot, attacker could have drained all 50M TSUD in the pool. 


## Details
The bug located at the old implementation of tfUSD. https://etherscan.io/address/0x27f461c698844ff51b33ecffa5dc2bd9721060b1#code.

There old implementation had an flush function that every can trigger.
```solidity
   function flush(uint256 currencyAmount, uint256 minMintAmount) external {
```
The flush function calls `_curvePool.add_liquidity(amounts, minMintAmount);`. When the contract provides liquidity through `add_liquidity` the curve pool mints 3crv based on the **market price**. When the 3crv pool is imbalanced, the contract suffers huge slippage.  

The exploit steps are as follow:
1. borrow TUSD and DAI from aave.
2. Deposit DAI into compound to borrow TUSD.
3. Mutate the TUSD price at 3crv prool (`0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51`)
4. trigger `flush` and force the pool to add liquidity to 3crv at bad price.
5. **Buy back TUSD at 3crv pool** (Gain profit at this step.)
6. Repay TUSD to compound
7. Repay DAI, TUSD to aave
8. Get 15M TUSD profit.

### Why we need flash bot to drain all token

The attack pattern is simliar to [yDai incident](https://peckshield.medium.com/the-ydai-incident-analysis-forced-investment-2b8ac6058eb5).

The attack can do following steps:
1. supply token to the pool
2. exploit it. (see above steps)
3. withdraw token
4. repeat 1-3

## How to reproduce
1. `npm i`
2. `npx hardhat test`

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

## Reference

1. [aave/code-examples-protocol](https://github.com/aave/code-examples-protocol)
2. [The yDAI Incident Analysis: Forced Investment](https://peckshield.medium.com/the-ydai-incident-analysis-forced-investment-2b8ac6058eb5)

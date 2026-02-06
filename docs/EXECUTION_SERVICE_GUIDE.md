# SLY Execution Service Guide

Run your own execution service and earn fees by triggering automated trades in the SLY ecosystem.

## Overview

SLYWallet supports automated strategies like DCA (Dollar Cost Averaging) and DRIP (price-triggered trades). These strategies need external "executors" to trigger the trades when conditions are met. **Anyone can run an execution service** and earn fees for each trade they execute.

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│                 EXECUTION SERVICE FLOW                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. MONITOR: Query wallets for ready positions          │
│     └─> dcaGetReadyPositions() / sdrGetReadyPositions() │
│                                                         │
│  2. EXECUTE: Call execute function with position IDs    │
│     └─> dcaExecuteTrades([ids]) / sdrExecuteTrades()    │
│                                                         │
│  3. EARN: Receive executor fee directly to your wallet  │
│     └─> 10% of total fee (configurable)                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Fee Structure

When a trade is executed, fees are calculated based on trade volume:

| Volume (USD) | Fee Rate |
|--------------|----------|
| < $5,000 | 0.015% |
| $5,000 - $10,000 | 0.010% |
| > $10,000 | 0.009% |

The fee is then split:
- **Executor (you)**: 10% of total fee
- **Platform (SLY)**: 90% of total fee

**Example:**
- Trade amount: $10,000 USDT
- Fee rate: 0.009% = $0.90 total fee
- Executor receives: $0.09 (in USDT)
- Platform receives: $0.81 (in USDT)

Fees are paid in the **same token** being traded (not ETH).

## Supported Strategies

### DCA (Dollar Cost Averaging)

Executes trades at regular block intervals.

**Ready Conditions:**
- Position is active
- Current block >= next trigger block
- Amount remaining to trade > 0

**Contract Functions:**
```solidity
// Query ready positions
function dcaGetReadyPositions(uint256 startIdx, uint256 count)
    external view returns (uint256[] memory positionIds);

// Execute trades (permissionless)
function dcaExecuteTrades(uint256[] calldata positionIds) external;
```

### DRIP (Price-Triggered)

Executes trades when price conditions are met.

**Ready Conditions:**
- Position is active
- Price deviation threshold met
- Cooldown period passed

**Contract Functions:**
```solidity
// Query ready positions
function sdrGetReadyPositions(uint256 startIdx, uint256 count)
    external view returns (uint256[] memory positionIds);

// Execute trades (permissionless)
function sdrExecuteTrades(uint256[] calldata positionIds) external;
```

## Running an Execution Service

### 1. Basic Setup

```javascript
const { ethers } = require("ethers");

// Connect to BSC
const provider = new ethers.JsonRpcProvider("https://bsc-dataseed.binance.org");
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Contract ABIs (simplified)
const DCA_ABI = [
    "function dcaGetReadyPositions(uint256,uint256) view returns (uint256[])",
    "function dcaExecuteTrades(uint256[])"
];

const DRIP_ABI = [
    "function sdrGetReadyPositions(uint256,uint256) view returns (uint256[])",
    "function sdrExecuteTrades(uint256[])"
];
```

### 2. Monitor for Ready Positions

```javascript
async function monitorDCA(walletAddress) {
    const dcaContract = new ethers.Contract(walletAddress, DCA_ABI, wallet);

    // Check for ready positions (batch of 100)
    const readyPositions = await dcaContract.dcaGetReadyPositions(0, 100);

    if (readyPositions.length > 0) {
        console.log(`Found ${readyPositions.length} ready positions`);
        return readyPositions;
    }

    return [];
}
```

### 3. Execute Trades

```javascript
async function executeDCATrades(walletAddress, positionIds) {
    const dcaContract = new ethers.Contract(walletAddress, DCA_ABI, wallet);

    try {
        const tx = await dcaContract.dcaExecuteTrades(positionIds);
        const receipt = await tx.wait();

        // Parse fee collection events
        for (const log of receipt.logs) {
            // Look for DCAFeesCollected event
            // Your executor fee is in the event data
        }

        console.log(`Executed ${positionIds.length} trades`);
        return receipt;
    } catch (error) {
        console.error("Execution failed:", error);
        return null;
    }
}
```

### 4. Full Service Loop

```javascript
const WALLETS_TO_MONITOR = [
    "0x...", // List of SLYWallet addresses
];

async function runExecutionService() {
    while (true) {
        for (const walletAddress of WALLETS_TO_MONITOR) {
            // Check DCA positions
            const dcaReady = await monitorDCA(walletAddress);
            if (dcaReady.length > 0) {
                await executeDCATrades(walletAddress, dcaReady);
            }

            // Check DRIP positions
            const dripReady = await monitorDRIP(walletAddress);
            if (dripReady.length > 0) {
                await executeDRIPTrades(walletAddress, dripReady);
            }
        }

        // Wait before next check (e.g., every block or every minute)
        await sleep(3000); // 3 seconds
    }
}
```

## Advanced: Multi-Wallet Discovery

To discover all SLYWallets with active strategies:

### Using Events

```javascript
// Listen for DCA position creation events
const factoryContract = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, provider);

// Get all wallets
const wallets = await factoryContract.getAllWallets();

// Filter to those with DCA facet attached
const walletsWithDCA = [];
for (const wallet of wallets) {
    try {
        const dcaContract = new ethers.Contract(wallet, DCA_ABI, provider);
        await dcaContract.dcaGetReadyPositions(0, 1); // Will fail if no DCA facet
        walletsWithDCA.push(wallet);
    } catch {
        // No DCA facet
    }
}
```

### Using Subgraph (Recommended)

Deploy a subgraph to index:
- Wallet creations
- DCA/DRIP position creations
- Position states and next trigger times

Query the subgraph to get ready positions across all wallets.

## Gas Optimization

### Batch Multiple Wallets

Execute positions across multiple wallets in a single transaction using a batch executor contract:

```solidity
contract BatchExecutor {
    function executeDCABatch(
        address[] calldata wallets,
        uint256[][] calldata positionIds
    ) external {
        for (uint i = 0; i < wallets.length; i++) {
            ISLYWalletDCA(wallets[i]).dcaExecuteTrades(positionIds[i]);
        }
    }
}
```

### Profitability Check

Before executing, verify the fee reward exceeds gas cost:

```javascript
async function isProfitable(walletAddress, positionIds) {
    const dcaContract = new ethers.Contract(walletAddress, DCA_ABI, provider);

    // Estimate gas
    const gasEstimate = await dcaContract.dcaExecuteTrades.estimateGas(positionIds);
    const gasPrice = await provider.getFeeData();
    const gasCost = gasEstimate * gasPrice.gasPrice;

    // Estimate fee reward (you need to query position details)
    const expectedFee = await estimateFeeReward(walletAddress, positionIds);

    return expectedFee > gasCost;
}
```

## Events to Monitor

### DCA Fee Collection

```solidity
event DCAFeesCollected(
    uint256 indexed positionId,
    uint256 totalFeeAmount,
    uint256 platformFeeAmount,
    uint256 executorFeeAmount,  // Your earnings
    address fundingToken,
    address executor            // Your address
);
```

### DRIP Fee Collection

```solidity
event SDRFeesCollected(
    uint256 indexed positionId,
    uint256 totalFeeAmount,
    uint256 platformFeeAmount,
    uint256 executorFeeAmount,
    address fundingToken,
    address executor
);
```

## Security Considerations

1. **Reentrancy**: Execute functions are protected with `nonReentrant`
2. **No Access Control**: Anyone can execute - first caller wins
3. **MEV Protection**: Consider using Flashbots or private mempools to avoid frontrunning
4. **Gas Spikes**: Monitor gas prices to maintain profitability

## Contract Addresses (BSC Mainnet)

| Contract | Address |
|----------|---------|
| SLY Diamond Service | `0x9a00520C5E5B403c691C0fc4C2A6214f939fA460` |
| SLYWallet Factory | Check deployment docs |

## Revenue Potential

Your earnings depend on:
- **Volume**: More trades = more fees
- **Number of wallets**: Monitor more wallets = more opportunities
- **Speed**: First executor gets the fee
- **Gas efficiency**: Lower gas = higher profit margin

**Typical scenario:**
- 1000 active DCA positions
- Average $500 trade size
- Daily trades: 200
- Total daily volume: $100,000
- Total daily fees: ~$10
- Executor share (10%): ~$1/day

Scale with more wallets and strategies for higher earnings.

## Support

- [GitHub Issues](https://github.com/singularry/slywallet-contracts/issues)

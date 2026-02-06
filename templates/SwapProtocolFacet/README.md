# SwapProtocolFacet Template

A template for integrating DEX protocols (Uniswap, PancakeSwap, SushiSwap) with SLYWallet.

## Overview

This template provides patterns for:

- **Exact Input Swaps**: Trade exact amount of input token for minimum output
- **Exact Output Swaps**: Trade maximum input for exact amount of output
- **Multi-hop Routing**: Route through multiple pools for better prices
- **Native Token Swaps**: Handle BNB/ETH wrapping automatically
- **Slippage Protection**: Enforce configurable slippage limits
- **Route Configuration**: Pre-configure optimal routes for token pairs

## Key Concepts

### Slippage Protection

Slippage occurs when price moves between transaction submission and execution:
- Set a maximum slippage (e.g., 1%) to prevent excessive losses
- Higher slippage = more likely to execute, but worse price
- Lower slippage = better price, but may fail

```solidity
// Calculate minimum output with 1% slippage
uint256 minOutput = expectedOutput * 99 / 100;
```

### Fee Tiers (V3 Style)

V3-style DEXs have multiple fee tiers per pair:
- **500** (0.05%): Stable pairs (USDT/USDC)
- **3000** (0.3%): Most pairs
- **10000** (1%): Exotic pairs

### Multi-hop Routing

Sometimes a direct swap isn't available or has poor liquidity:
```
USDT → BNB → ETH  (instead of USDT → ETH directly)
```

Route path encoding:
```solidity
path = [USDT, BNB, ETH]
fees = [500, 3000]  // USDT->BNB 0.05%, BNB->ETH 0.3%
```

## Quick Start

### 1. Copy and Rename

```bash
cp -r templates/facets/SwapProtocolFacet contracts/slywallet/facets/PancakeSwap
```

### 2. Implement Protocol Calls

Replace TODO placeholders:

```solidity
// For PancakeSwap V3
function _executeSwap(...) internal returns (uint256) {
    bytes memory path = abi.encodePacked(
        tokenIn, fee0, tokenMid, fee1, tokenOut
    );

    IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
        path: path,
        recipient: address(this),
        amountIn: amountIn,
        amountOutMinimum: minAmountOut
    });

    return IV3SwapRouter(router).exactInput(params);
}
```

### 3. Configure Routes

Set up common routes in `scripts/deploy.js`:

```javascript
routes: [
    {
        tokenA: USDT,
        tokenB: WBNB,
        path: [USDT, WBNB],
        fees: [500],
        isV3: true,
        maxSlippageBps: 100
    }
]
```

## DEX Integration Examples

### PancakeSwap V3 (BSC)

```solidity
// Exact input single hop
IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
    tokenIn: tokenIn,
    tokenOut: tokenOut,
    fee: 500,
    recipient: address(this),
    amountIn: amountIn,
    amountOutMinimum: minAmountOut,
    sqrtPriceLimitX96: 0
});
uint256 amountOut = IV3SwapRouter(router).exactInputSingle(params);
```

### Uniswap V2 Style

```solidity
// Exact input with path
address[] memory path = new address[](2);
path[0] = tokenIn;
path[1] = tokenOut;

uint[] memory amounts = IUniswapV2Router(router).swapExactTokensForTokens(
    amountIn,
    minAmountOut,
    path,
    address(this),
    deadline
);
```

### 1inch Aggregator

```solidity
// Use aggregated swap data from 1inch API
(bool success, bytes memory result) = router.call(swapData);
require(success, "Swap failed");
```

## Configuration

### Initialize Facet

```javascript
await facet.initializeSwapProtocol(
    "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4", // Router
    "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865", // Factory
    "0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997", // Quoter
    "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // WBNB
    100 // 1% default slippage
);
```

### Configure Routes

```javascript
await facet.configureRoute(
    USDT,
    WBNB,
    [USDT, WBNB],
    [500],
    true,
    100
);
```

## Safety Features

1. **Slippage Protection**: All swaps verify minimum output
2. **Deadline Enforcement**: Transactions expire after deadline
3. **Balance Checks**: Verify sufficient balance before swap
4. **Route Validation**: Ensure path/fee arrays match
5. **Max Hops**: Limit multi-hop complexity

## Handling Edge Cases

### Insufficient Liquidity

```solidity
// Get quote first
try IQuoter(quoter).quoteExactInputSingle(...) returns (uint256 quote) {
    if (quote < minAcceptable) revert InsufficientLiquidity();
} catch {
    revert PoolNotFound();
}
```

### Price Impact

```solidity
// Check price impact before large swaps
uint256 spotPrice = getSpotPrice(tokenIn, tokenOut);
uint256 executionPrice = amountOut * 1e18 / amountIn;
uint256 impact = (spotPrice - executionPrice) * 10000 / spotPrice;
if (impact > maxImpactBps) revert ExcessivePriceImpact();
```

### Deadline Management

```solidity
// Add buffer to deadline
uint256 deadline = block.timestamp + 300; // 5 minutes

// For time-sensitive operations
uint256 deadline = block.timestamp + 30; // 30 seconds
```

## File Structure

```
SwapProtocolFacet/
├── contracts/
│   ├── SwapProtocolFacet.sol         # Main implementation
│   ├── SwapProtocolStorage.sol       # Storage with routes
│   └── ISwapProtocolFacet.sol        # Interface
├── test/
│   └── SwapProtocolFacet.test.js
├── scripts/
│   ├── deploy.js                     # Includes DEX addresses
│   └── attach.js                     # Auto-configures routes
└── README.md
```

## Common Patterns

### Quote Before Swap

```solidity
function getExpectedOutput(...) external view returns (uint256) {
    return IQuoter(quoter).quoteExactInputSingle(
        tokenIn, tokenOut, fee, amountIn, 0
    );
}
```

### Swap With Permit (Gas Saving)

```solidity
function swapWithPermit(
    ...swapParams,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) external {
    IERC20Permit(tokenIn).permit(msg.sender, address(this), amountIn, deadline, v, r, s);
    // Execute swap
}
```

### Swap and Transfer

```solidity
// Swap to a different recipient
function swapAndSend(
    address recipient,
    ...swapParams
) external {
    uint256 amountOut = _executeSwap(...);
    IERC20(tokenOut).safeTransfer(recipient, amountOut);
}
```

## Submission Checklist

- [ ] All swap functions implemented for target DEX
- [ ] Slippage protection tested thoroughly
- [ ] Multi-hop routing working correctly
- [ ] Native token handling (wrap/unwrap) implemented
- [ ] Quote functions accurate
- [ ] E2E tests pass on mainnet fork
- [ ] Gas usage reasonable (< 300k for simple swaps)
- [ ] Events emitted for all swaps

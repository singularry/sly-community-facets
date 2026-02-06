# LendingProtocolFacet Template

A template for integrating lending protocols (Aave, Venus, Compound-style) with SLYWallet.

## Overview

This template provides patterns for:

- **Supply/Withdraw Operations**: Deposit and withdraw tokens from lending pools
- **Borrow/Repay Operations**: Borrow against collateral and repay debt
- **Health Factor Monitoring**: Prevent liquidation by enforcing minimum health factor
- **Market Configuration**: Manage multiple lending markets with different parameters
- **Collateral Management**: Enable/disable assets as collateral

## Key Concepts

### Health Factor

The health factor represents the safety of your position:
- `HF >= 1.0`: Position is safe
- `HF < 1.0`: Position can be liquidated

```
Health Factor = (Total Collateral Value * Weighted Collateral Factor) / Total Borrow Value
```

This facet enforces a minimum health factor (default 1.2) before allowing borrows or withdrawals.

### Collateral Factor

Each market has a collateral factor (e.g., 80%) that determines how much you can borrow against it:
- 80% collateral factor = can borrow up to 80% of asset value
- Higher risk assets have lower collateral factors

### Lending Tokens

Protocols issue tokens representing your deposits:
- Aave: aTokens (aUSDT, aWBNB)
- Venus: vTokens (vUSDT, vBNB)
- Compound: cTokens (cUSDT, cETH)

These accrue interest automatically and can be redeemed for the underlying plus yield.

## Quick Start

### 1. Copy and Rename

```bash
cp -r templates/facets/LendingProtocolFacet contracts/slywallet/facets/VenusLending
# Rename files and replace "LendingProtocol" with "VenusLending"
```

### 2. Implement Protocol Calls

Replace the TODO placeholders with actual protocol calls:

```solidity
// Example: Venus supply
function lendingSupply(...) {
    // Approve and mint vTokens
    IERC20(underlying).forceApprove(market.lendingToken, amount);
    IVToken(market.lendingToken).mint(amount);
}
```

### 3. Implement Health Factor Calculation

```solidity
function _calculateHealthFactor() internal view returns (uint256) {
    uint256 totalCollateral;
    uint256 totalBorrow;

    for (uint i = 0; i < markets.length; i++) {
        address market = markets[i];
        uint256 price = IOracle(oracle).getPrice(market);
        uint256 supply = _getSupplyBalance(market);
        uint256 borrow = _getBorrowBalance(market);
        uint256 cf = marketConfigs[market].collateralFactorBps;

        totalCollateral += supply * price * cf / BPS_DENOMINATOR;
        totalBorrow += borrow * price;
    }

    return totalBorrow == 0 ? type(uint256).max
        : totalCollateral * BPS_DENOMINATOR / totalBorrow;
}
```

## Protocol Integration Examples

### Venus Protocol (BSC)

```solidity
// Supply
IVToken(vToken).mint(amount);

// Withdraw
IVToken(vToken).redeemUnderlying(amount);

// Borrow
IVToken(vToken).borrow(amount);

// Repay
IVToken(vToken).repayBorrow(amount);

// Enable as collateral
IComptroller(comptroller).enterMarkets([vToken]);
```

### Aave V3

```solidity
// Supply
IPool(pool).supply(underlying, amount, address(this), 0);

// Withdraw
IPool(pool).withdraw(underlying, amount, address(this));

// Borrow
IPool(pool).borrow(underlying, amount, 2, 0, address(this));

// Repay
IPool(pool).repay(underlying, amount, 2, address(this));
```

## Configuration

### Market Setup

Configure each lending market with its parameters:

```javascript
await facet.configureMarket(
    "0x55d398326f99059fF775485246999027B3197955", // USDT
    "0xfD5840Cd36d94D7229439859C0112a4185BC0255", // vUSDT
    8000,  // 80% collateral factor
    true,  // Can use as collateral
    true   // Can borrow
);
```

### Health Factor Threshold

Set during initialization:

```javascript
await facet.initializeLendingProtocol(
    lendingPool,
    oracle,
    12000  // Min health factor 1.2
);
```

## Safety Features

1. **Health Factor Checks**: All borrows and withdrawals verify health factor stays above minimum
2. **Market Validation**: Only configured markets can be used
3. **Balance Checks**: Verify sufficient balances before operations
4. **Reentrancy Protection**: All external calls protected

## Testing

### Unit Tests
```bash
npx hardhat test test/LendingProtocolFacet.test.js
```

### E2E Fork Tests

Create tests that fork mainnet and interact with real protocols:

```javascript
describe("Venus Integration", function () {
    it("should supply and borrow successfully", async function () {
        // Fork BSC at specific block
        // Supply USDT, verify vUSDT balance
        // Enable as collateral
        // Borrow WBNB
        // Verify health factor
    });
});
```

## File Structure

```
LendingProtocolFacet/
├── contracts/
│   ├── LendingProtocolFacet.sol      # Main implementation
│   ├── LendingProtocolStorage.sol    # Storage with market configs
│   └── ILendingProtocolFacet.sol     # Interface
├── test/
│   └── LendingProtocolFacet.test.js
├── scripts/
│   ├── deploy.js                     # Includes market addresses
│   └── attach.js                     # Auto-configures markets
└── README.md
```

## Common Patterns

### Handling Interest Accrual

Most protocols accrue interest automatically. When querying balances:

```solidity
// Current balance including accrued interest
uint256 balance = IVToken(vToken).balanceOfUnderlying(address(this));
```

### Flash Loan Protection

For protocols supporting flash loans, add checks:

```solidity
require(
    borrowBalance >= previousBorrowBalance,
    "Flash loan detected"
);
```

### Reward Claiming

Many protocols offer rewards (COMP, XVS). Add a claim function:

```solidity
function claimRewards() external {
    IComptroller(comptroller).claimVenus(address(this));
}
```

## Submission Checklist

- [ ] All protocol-specific functions implemented
- [ ] Health factor calculation tested thoroughly
- [ ] Oracle integration working correctly
- [ ] All markets configured with correct parameters
- [ ] E2E tests pass on mainnet fork
- [ ] Gas usage reasonable (< 500k per operation)
- [ ] No hardcoded addresses in contract
- [ ] Events emitted for all state changes

# Developer Fee Sharing System

This document describes how third-party facet developers can earn revenue from their contributions to the SLY ecosystem.

## Current Fee Architecture

### Fee Flow (Existing)

```
User Trade ($10,000)
       │
       ▼
┌─────────────────────┐
│   Fee Calculation   │
│   0.009% = $0.90    │
└─────────────────────┘
       │
       ▼
┌─────────────────────┐
│    Fee Split        │
├─────────────────────┤
│ Executor: 10% ($0.09)│ ──> Bot that triggered trade
│ Platform: 90% ($0.81)│ ──> SLY Treasury
└─────────────────────┘
```

### Fee Configuration

Stored in `AppStorage`:

```solidity
struct AppStorage {
    // Fee rates (in 0.001% units, 100000 = 100%)
    uint256 lowVolumeFee;      // 15 = 0.015%
    uint256 midVolumeFee;      // 10 = 0.010%
    uint256 highVolumeFee;     // 9 = 0.009%

    // Volume thresholds
    uint256 midVolumeThreshold;   // $5,000
    uint256 highVolumeThreshold;  // $10,000

    // Fee split
    uint256 executorFeeSplit;   // 10000 = 10%
    uint256 serviceFeeSpilt;    // 90000 = 90%

    // Where platform fees go
    address payable feeReceiver;
}
```

## Proposed Developer Fee System

### Architecture: 3-Way Split

```
User Trade ($10,000)
       │
       ▼
┌─────────────────────┐
│   Fee Calculation   │
│   0.009% = $0.90    │
└─────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│       Fee Split             │
├─────────────────────────────┤
│ Executor:  10% ($0.09)      │ ──> Bot/Keeper
│ Developer: 30% ($0.27)      │ ──> Facet Developer
│ Platform:  60% ($0.54)      │ ──> SLY Treasury
└─────────────────────────────┘
```

### Implementation Options

#### Option A: Developer Registry Contract

Create a new `SLYDeveloperRegistry` facet to manage developer fee shares.

**Storage:**
```solidity
struct DeveloperInfo {
    address payable wallet;      // Developer's wallet
    uint256 feeShareBps;         // Fee share in basis points (max 5000 = 50%)
    bool active;                 // Whether developer is active
    uint256 totalEarned;         // Lifetime earnings
}

// Mapping: facet address => developer info
mapping(address => DeveloperInfo) public developers;

// Mapping: developer wallet => their facet addresses
mapping(address => address[]) public developerFacets;
```

**Registration (Admin Only):**
```solidity
function registerFacetDeveloper(
    address facetAddress,
    address payable developerWallet,
    uint256 feeShareBps
) external onlyOwner {
    require(feeShareBps <= 5000, "Max 50% developer share");
    require(developerWallet != address(0), "Invalid wallet");

    developers[facetAddress] = DeveloperInfo({
        wallet: developerWallet,
        feeShareBps: feeShareBps,
        active: true,
        totalEarned: 0
    });

    developerFacets[developerWallet].push(facetAddress);

    emit DeveloperRegistered(facetAddress, developerWallet, feeShareBps);
}
```

**Fee Calculation with Developer:**
```solidity
function calculateFeeSplitWithDeveloper(
    address facetAddress,
    address token,
    uint256 amount
) external view returns (
    uint256 totalFee,
    uint256 executorFee,
    uint256 developerFee,
    uint256 platformFee
) {
    // Calculate total fee as normal
    totalFee = _calculateTotalFee(token, amount);

    // Calculate executor share (always 10%)
    executorFee = (totalFee * executorFeeSplit) / 100000;
    uint256 remainingFee = totalFee - executorFee;

    // Check if facet has registered developer
    DeveloperInfo storage dev = developers[facetAddress];
    if (dev.active && dev.feeShareBps > 0) {
        developerFee = (remainingFee * dev.feeShareBps) / 10000;
        platformFee = remainingFee - developerFee;
    } else {
        developerFee = 0;
        platformFee = remainingFee;
    }

    return (totalFee, executorFee, developerFee, platformFee);
}
```

#### Option B: Per-Facet Fee Configuration

Each facet stores its own developer fee configuration.

**In Facet Storage:**
```solidity
library MyProtocolStorage {
    struct Layout {
        bool initialized;
        address protocolAddress;

        // Developer fee config
        address payable developerWallet;
        uint256 developerFeeBps;  // Basis points
    }
}
```

**Fee Distribution in Facet:**
```solidity
function _collectAndDistributeFees(
    address token,
    uint256 amount
) internal returns (uint256 netAmount) {
    MyProtocolStorage.Layout storage s = MyProtocolStorage.layout();

    // Get fee manager
    ISLYFeeManagement feeManager = ISLYFeeManagement(
        SLYWalletStorage.diamondStorage().slyDiamondService
    );

    // Calculate base split
    (uint256 totalFee, uint256 executorFee, uint256 platformFee) =
        feeManager.fmCalculateTokenFeeSplitFor(token, amount);

    // Calculate developer share from platform portion
    uint256 developerFee = 0;
    if (s.developerWallet != address(0) && s.developerFeeBps > 0) {
        developerFee = (platformFee * s.developerFeeBps) / 10000;
        platformFee -= developerFee;
    }

    // Distribute fees
    _transferFee(token, msg.sender, executorFee);        // Executor
    _transferFee(token, s.developerWallet, developerFee); // Developer
    _transferFee(token, feeManager.getFeeReceiver(), platformFee); // Platform

    return amount - totalFee;
}
```

### Recommended Approach

**Use Option A (Developer Registry)** because:
1. Centralized management of developer fees
2. Easy to adjust fee shares without contract upgrades
3. Single source of truth for developer earnings
4. Auditable and transparent
5. Can be used by any facet without modification

### Fee Share Guidelines

| Facet Complexity | Developer Share | Notes |
|------------------|-----------------|-------|
| Simple (< 200 LOC) | 10-20% | Basic protocol wrappers |
| Medium (200-500 LOC) | 20-35% | Multi-function integrations |
| Complex (> 500 LOC) | 35-50% | Novel functionality, strategies |

## Implementation Steps

### Phase 1: Developer Registry

1. Create `SLYDeveloperRegistryFacet.sol`
2. Add storage mapping in `AppStorage.sol`
3. Deploy and attach to SLY Diamond Service
4. Admin registers approved developers

### Phase 2: Fee Distribution Update

1. Modify `LibFees.sol` to support developer split
2. Update `SLYFeeManagementFacet.sol` with new functions
3. Add events for developer fee tracking

### Phase 3: Facet Integration

1. New facets call `calculateFeeSplitWithDeveloper()`
2. Distribute fees to all three recipients
3. Emit events for tracking

## Developer Dashboard Data

Events for off-chain tracking:

```solidity
event DeveloperRegistered(
    address indexed facetAddress,
    address indexed developerWallet,
    uint256 feeShareBps
);

event DeveloperFeeCollected(
    address indexed facetAddress,
    address indexed developerWallet,
    address token,
    uint256 amount,
    uint256 timestamp
);

event DeveloperWalletUpdated(
    address indexed facetAddress,
    address indexed oldWallet,
    address indexed newWallet
);

event DeveloperDeactivated(
    address indexed facetAddress
);
```

## Claiming & Reporting

### For Developers

1. **Real-time payment**: Fees paid directly per transaction
2. **No claiming needed**: Funds go straight to developer wallet
3. **Multi-token**: Receive fees in whatever token was traded

### Reporting Dashboard

Track via events:
- Total lifetime earnings per facet
- Daily/weekly/monthly volumes
- Token breakdown
- User adoption metrics

```javascript
// Query developer earnings from events
const filter = contract.filters.DeveloperFeeCollected(
    facetAddress,
    developerWallet
);
const events = await contract.queryFilter(filter);
const totalEarned = events.reduce((sum, e) => sum + e.args.amount, 0n);
```

## Security Considerations

1. **Admin-only registration**: Only SLY team can register developers
2. **Max fee cap**: 50% maximum to ensure platform sustainability
3. **Immutable facet binding**: Developer wallet tied to specific facet address
4. **Audit requirement**: Only audited facets get fee sharing

## Example: Full Fee Flow

```
User deposits $10,000 via YourProtocolFacet
       │
       ▼
Fee calculated: 0.009% = $0.90
       │
       ▼
Registry lookup: YourProtocolFacet
  └─ Developer: 0xDev... (30% share)
       │
       ▼
Fee distribution:
  ├─ Executor (msg.sender): $0.09 (10%)
  ├─ Developer (0xDev...): $0.243 (30% of remaining $0.81)
  └─ Platform (feeReceiver): $0.567 (remaining)
       │
       ▼
Events emitted:
  ├─ FeeCollected(...)
  └─ DeveloperFeeCollected(facet, dev, token, $0.243)
```

## Next Steps

1. Review and approve this proposal
2. Implement `SLYDeveloperRegistryFacet`
3. Update fee distribution logic
4. Create developer dashboard
5. Document in submission guidelines

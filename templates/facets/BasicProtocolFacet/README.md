# BasicProtocolFacet Template

A starter template for creating SLYWallet facets that integrate with external DeFi protocols.

## Overview

This template demonstrates the core patterns required for a SLYWallet facet:

- **Diamond Storage Pattern**: Isolated storage that won't collide with other facets
- **Role-Based Access Control**: Integration with SLYWallet's permission system
- **Reentrancy Protection**: Cross-facet reentrancy guards
- **Safe Token Operations**: Using OpenZeppelin's SafeERC20

## Quick Start

### 1. Copy the Template

```bash
cp -r templates/facets/BasicProtocolFacet contracts/slywallet/facets/YourProtocol
```

### 2. Rename Files

```bash
cd contracts/slywallet/facets/YourProtocol/contracts
mv BasicProtocolFacet.sol YourProtocolFacet.sol
mv BasicProtocolStorage.sol YourProtocolStorage.sol
mv IBasicProtocolFacet.sol IYourProtocolFacet.sol
```

### 3. Find and Replace

Replace all occurrences of:
- `BasicProtocol` → `YourProtocol`
- `basicprotocol` → `yourprotocol`
- `BASIC_PROTOCOL` → `YOUR_PROTOCOL`

### 4. Update Storage Hash

In `YourProtocolStorage.sol`, update the storage position to be unique:

```solidity
bytes32 constant STORAGE_POSITION = keccak256("com.slywallet.yourprotocol.storage");
```

### 5. Add Protocol Interface

Import your target protocol's interface and implement the actual integration logic.

## File Structure

```
BasicProtocolFacet/
├── contracts/
│   ├── BasicProtocolFacet.sol      # Main facet implementation
│   ├── BasicProtocolStorage.sol    # Diamond storage library
│   └── IBasicProtocolFacet.sol     # Public interface
├── test/
│   └── BasicProtocolFacet.test.js  # Unit tests
├── scripts/
│   ├── deploy.js                   # Deployment script
│   └── attach.js                   # Diamond attachment script
└── README.md                       # This file
```

## Key Patterns

### Storage Pattern

Each facet uses a unique storage slot computed from a keccak256 hash:

```solidity
bytes32 constant STORAGE_POSITION = keccak256("com.slywallet.yourprotocol.storage");

struct Layout {
    bool initialized;
    address protocolAddress;
    // Add your fields here
}

function layout() internal pure returns (Layout storage l) {
    bytes32 position = STORAGE_POSITION;
    assembly { l.slot := position }
}
```

### Access Control

Use the provided modifiers for role-based access:

```solidity
modifier onlyAdmin() {
    require(
        LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Admin) ||
        LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Owner),
        "Not admin or owner"
    );
    _;
}
```

Available roles:
- `Owner` - Full wallet control
- `Admin` - Can execute transactions and manage facets
- `Authenticator` - Can verify signatures (limited use)
- `None` - Default, no permissions

### Reentrancy Protection

Inherit from `SLYWalletReentrancyGuard` and use the `nonReentrant` modifier:

```solidity
contract YourFacet is SLYWalletReentrancyGuard {
    function riskyOperation() external nonReentrant {
        // Safe from reentrancy across all facets
    }
}
```

### Token Handling

Always use SafeERC20 for token operations:

```solidity
using SafeERC20 for IERC20;

// Use forceApprove to handle tokens with approval race conditions
IERC20(token).forceApprove(spender, amount);

// Use safeTransfer instead of transfer
IERC20(token).safeTransfer(recipient, amount);
```

## Testing

### Unit Tests

```bash
npx hardhat test test/BasicProtocolFacet.test.js
```

### E2E Fork Tests

Create `test/BasicProtocolE2E.test.js` for mainnet fork tests:

```javascript
describe("BasicProtocolFacet E2E", function () {
    before(async function () {
        await network.provider.request({
            method: "hardhat_reset",
            params: [{
                forking: {
                    jsonRpcUrl: "https://your-archive-node",
                    blockNumber: 79440000
                }
            }]
        });
    });
    // ... tests
});
```

## Deployment

### 1. Deploy Facet

Update `PROTOCOL_ADDRESSES` in `scripts/deploy.js`, then:

```bash
npx hardhat run scripts/deploy.js --network bsc
```

### 2. Attach to Wallet

Update `CONFIG` in `scripts/attach.js` with the deployed address, then:

```bash
npx hardhat run scripts/attach.js --network bsc
```

## Submission Checklist

Before submitting to the SLY Community Facets repository:

- [ ] Unique storage hash (no collisions with existing facets)
- [ ] All tests pass locally
- [ ] Contract size < 24KB
- [ ] Uses only approved libraries (LibPermissions, SafeERC20, etc.)
- [ ] No hardcoded addresses (configurable via initialization)
- [ ] Proper access control on all state-changing functions
- [ ] Reentrancy protection on external calls
- [ ] Events emitted for all state changes
- [ ] NatSpec documentation on all public functions
- [ ] README with usage examples

## Need Help?

- [Developer Guide](../../../docs/FACET_DEVELOPER_GUIDE.md)
- [Existing Facets](../../../contracts/slywallet/facets/)
- [Submit Issues](https://github.com/singularry/sly-community-facets/issues)

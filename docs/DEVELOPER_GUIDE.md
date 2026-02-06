# SLYWallet Facet Developer Guide

Build and monetize custom facets for the Singularry (SLY) smart wallet ecosystem.

## Table of Contents

1. [Introduction](#1-introduction)
2. [Diamond Architecture Overview](#2-diamond-architecture-overview)
3. [Facet Patterns](#3-facet-patterns)
4. [Protocol Library Access](#4-protocol-library-access)
5. [Fee Integration](#5-fee-integration)
6. [Testing Requirements](#6-testing-requirements)
7. [Submission Process](#7-submission-process)
8. [Audit Requirements](#8-audit-requirements)
9. [Revenue Sharing](#9-revenue-sharing)

---

## 1. Introduction

SLYWallet is a modular smart wallet system built on the [EIP-2535 Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535). This allows unlimited functionality to be added through **facets** — upgradeable modules that handle specific features like DeFi integrations, token swaps, staking, and more.

As a third-party developer, you can:
- Build custom facets for any DeFi protocol
- Submit them for review and audit
- Earn a percentage of SLY fees when users use your facet

### What is a Facet?

A facet is a smart contract whose functions are accessed via the Diamond proxy using `delegatecall`. Multiple facets can be attached to a single Diamond, allowing complex functionality while keeping a single wallet address.

```
┌─────────────────────────────────────────────────┐
│              SLYWallet Diamond                  │
│  (Single address: 0x1234...5678)                │
├─────────────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────────────┐   │
│  │  Base   │ │  Venus  │ │  Your Facet!    │   │
│  │  Facet  │ │  Facet  │ │  (DeFi XYZ)     │   │
│  └─────────┘ └─────────┘ └─────────────────┘   │
└─────────────────────────────────────────────────┘
```

---

## 2. Diamond Architecture Overview

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Diamond** | The main proxy contract (`SLYWalletDiamond.sol`) that delegates calls to facets |
| **Facet** | A contract containing functions that can be added to the Diamond |
| **DiamondCut** | The function used to add, replace, or remove facets |
| **DiamondLoupe** | Functions to inspect which facets and selectors are registered |
| **Diamond Storage** | Pattern for storing state to avoid storage collisions between facets |

### Storage Collision Prevention

Since all facets share the Diamond's storage, you MUST use the **Diamond Storage Pattern** to prevent collisions:

```solidity
library MyFacetStorage {
    // Unique storage position using keccak256 hash
    bytes32 constant STORAGE_POSITION = keccak256("com.slywallet.myfacet.storage");

    struct Layout {
        bool initialized;
        address externalProtocol;
        mapping(address => uint256) userBalances;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}
```

### Core Files Reference

| File | Purpose |
|------|---------|
| `contracts/slywallet/SLYWalletDiamond.sol` | Diamond proxy with fallback routing |
| `contracts/slywallet/SLYWalletStorage.sol` | Base wallet storage (roles, nonces) |
| `contracts/slywallet/libraries/LibSLYDiamond.sol` | Diamond cut implementation |
| `contracts/slywallet/libraries/LibPermissions.sol` | Role-based access control |
| `contracts/slywallet/SLYWalletReentrancyGuard.sol` | Cross-facet reentrancy protection |

---

## 3. Facet Patterns

### 3.1 Basic Structure

Every facet should follow this structure:

```
MyProtocolFacet/
├── contracts/
│   ├── IMyProtocolFacet.sol         # Interface (external functions)
│   ├── MyProtocolFacet.sol          # Implementation
│   └── MyProtocolStorage.sol        # Storage library
├── test/
│   ├── MyProtocolFacet.test.js      # Unit tests
│   └── MyProtocolE2E.test.js        # E2E fork tests
├── scripts/
│   ├── deploy.js                    # Deployment script
│   └── attach.js                    # Diamond attachment script
└── README.md                        # Documentation
```

### 3.2 Interface Pattern

Define a clear interface with events and errors:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMyProtocolFacet {
    // ============ Events ============
    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 shares, uint256 amount);
    event FacetInitialized(address indexed protocol);

    // ============ Errors ============
    error NotInitialized();
    error AlreadyInitialized();
    error InvalidAmount();
    error InsufficientBalance();

    // ============ Functions ============
    function initializeMyProtocol(address _protocolAddress) external;
    function deposit(uint256 amount) external;
    function withdraw(uint256 shares) external;
    function getPosition() external view returns (uint256 deposited, uint256 shares);
    function isInitialized() external view returns (bool);
}
```

### 3.3 Storage Pattern

Always create a dedicated storage library:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MyProtocolStorage {
    // IMPORTANT: Use a unique hash to prevent collisions
    // Format: keccak256("com.slywallet.{your-protocol-name}.storage")
    bytes32 constant STORAGE_POSITION = keccak256("com.slywallet.myprotocol.storage");

    struct Layout {
        bool initialized;
        address protocolAddress;
        uint256 totalDeposited;
        mapping(address => uint256) userShares;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}
```

### 3.4 Implementation Pattern

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IMyProtocolFacet.sol";
import "./MyProtocolStorage.sol";
import "../../libraries/LibPermissions.sol";
import "../../SLYWalletReentrancyGuard.sol";
import "../base/ISLYWalletBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MyProtocolFacet is IMyProtocolFacet, SLYWalletReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Modifiers ============

    modifier onlyAdmin() {
        require(
            LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Admin) ||
            LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Owner),
            "MyProtocolFacet: caller is not admin or owner"
        );
        _;
    }

    modifier onlyInitialized() {
        if (!MyProtocolStorage.layout().initialized) {
            revert NotInitialized();
        }
        _;
    }

    // ============ Initialization ============

    function initializeMyProtocol(address _protocolAddress) external onlyAdmin {
        MyProtocolStorage.Layout storage s = MyProtocolStorage.layout();

        if (s.initialized) revert AlreadyInitialized();
        if (_protocolAddress == address(0)) revert InvalidAmount();

        s.protocolAddress = _protocolAddress;
        s.initialized = true;

        emit FacetInitialized(_protocolAddress);
    }

    // ============ Core Functions ============

    function deposit(uint256 amount) external onlyAdmin onlyInitialized nonReentrant {
        if (amount == 0) revert InvalidAmount();

        MyProtocolStorage.Layout storage s = MyProtocolStorage.layout();

        // Your protocol logic here
        // Example: transfer tokens, call external protocol, track state

        emit Deposited(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) external onlyAdmin onlyInitialized nonReentrant {
        if (shares == 0) revert InvalidAmount();

        MyProtocolStorage.Layout storage s = MyProtocolStorage.layout();

        // Your withdrawal logic here

        emit Withdrawn(msg.sender, shares, amount);
    }

    // ============ View Functions ============

    function getPosition() external view onlyInitialized returns (uint256 deposited, uint256 shares) {
        MyProtocolStorage.Layout storage s = MyProtocolStorage.layout();
        // Return position data
    }

    function isInitialized() external view returns (bool) {
        return MyProtocolStorage.layout().initialized;
    }
}
```

### 3.5 Permission System

SLYWallet uses role-based access control. Available roles:

| Role | Permissions |
|------|-------------|
| **Owner** | All permissions (AddKey, RemoveKey, Execute, ExecuteBatch, ValidateSignature, DiamondCut) |
| **Admin** | All except RemoveKey and DiamondCut |
| **Authenticator** | ValidateSignature, Execute, ExecuteBatch only |
| **None** | No permissions |

Use `LibPermissions` to check roles:

```solidity
import "../../libraries/LibPermissions.sol";
import "../base/ISLYWalletBase.sol";

// Check if caller has Owner or Admin role
modifier onlyAdmin() {
    require(
        LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Admin) ||
        LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Owner),
        "Not admin or owner"
    );
    _;
}
```

### 3.6 Reentrancy Protection

Use the shared reentrancy guard for cross-facet protection:

```solidity
import "../../SLYWalletReentrancyGuard.sol";

contract MyProtocolFacet is SLYWalletReentrancyGuard {
    function riskyFunction() external nonReentrant {
        // Protected from reentrancy across ALL facets
    }
}
```

---

## 4. Protocol Library Access

### 4.1 Available Libraries

You can use these existing libraries in your facet:

| Library | Import Path | Purpose |
|---------|-------------|---------|
| `LibPermissions` | `contracts/slywallet/libraries/LibPermissions.sol` | Role-based access control |
| `SLYWalletReentrancyGuard` | `contracts/slywallet/SLYWalletReentrancyGuard.sol` | Cross-facet reentrancy protection |
| `SLYWalletStorage` | `contracts/slywallet/SLYWalletStorage.sol` | Access to base wallet state |
| `PancakeRouterLib` | `contracts/slywallet/facets/lista/libraries/PancakeRouterLib.sol` | DEX swap execution |

### 4.2 PancakeSwap Integration

For token swaps, use the existing PancakeRouterLib:

```solidity
import "../lista/libraries/PancakeRouterLib.sol";

function swapTokens(
    address router,
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    uint256 minAmountOut
) internal returns (uint256 amountOut) {
    // Exact input single swap
    amountOut = PancakeRouterLib.exactInputSingle(
        router,
        tokenIn,
        tokenOut,
        PancakeRouterLib.FEE_LOW,  // 500 = 0.05%
        amountIn,
        minAmountOut,
        address(this)
    );
}
```

### 4.3 Fee Tier Constants

```solidity
uint24 constant FEE_LOWEST = 100;   // 0.01% - Stablecoins
uint24 constant FEE_LOW = 500;      // 0.05% - Correlated pairs
uint24 constant FEE_MEDIUM = 2500;  // 0.25% - Standard pairs
uint24 constant FEE_HIGH = 10000;   // 1.00% - Volatile pairs
```

---

## 5. Fee Integration

### 5.1 How SLY Fees Work

All SLYWallet facets should collect fees for operations. The fee is split:
- **Executor (10%)**: The caller who triggers the transaction
- **Developer (X%)**: You, the facet developer (configurable, max 50%)
- **Service (90-X%)**: SLY protocol treasury

### 5.2 Integrating Fee Collection

```solidity
import "../../../../sly/interfaces/ISLYFeeManagement.sol";

function _collectFees(
    address token,
    uint256 amount
) internal returns (uint256 netAmount) {
    // Get fee manager from SLY Diamond Service
    ISLYFeeManagement feeManager = ISLYFeeManagement(
        SLYWalletStorage.diamondStorage().slyDiamondService
    );

    // Calculate fee in ETH
    uint256 ethFee = feeManager.calculateEthFeeForERC20(token, amount);

    // Ensure wallet has enough ETH
    require(address(this).balance >= ethFee, "Insufficient ETH for fee");

    // Get fee receiver
    address feeReceiver = feeManager.getFeeReceiver();

    // Send fee
    if (ethFee > 0) {
        (bool success,) = feeReceiver.call{value: ethFee}("");
        require(success, "Fee transfer failed");
    }

    return amount; // Or amount minus token fee if applicable
}
```

### 5.3 Fee Calculation Pattern

```solidity
function deposit(uint256 amount) external payable onlyAdmin onlyInitialized nonReentrant {
    ISLYFeeManagement feeManager = ISLYFeeManagement(
        SLYWalletStorage.diamondStorage().slyDiamondService
    );

    // Calculate required ETH fee
    uint256 ethFee = feeManager.calculateEthFeeForERC20(tokenAddress, amount);

    // Check wallet ETH balance
    require(address(this).balance >= ethFee, "Insufficient ETH for fee");

    // Execute deposit logic
    _executeDeposit(amount);

    // Send fee
    if (ethFee > 0) {
        address feeReceiver = feeManager.getFeeReceiver();
        (bool success,) = feeReceiver.call{value: ethFee}("");
        require(success, "Fee transfer failed");
    }

    emit Deposited(msg.sender, amount, ethFee);
}
```

---

## 6. Testing Requirements

### 6.1 Minimum Test Coverage

All submitted facets must have:
- **80% line coverage minimum**
- **Unit tests** for all public functions
- **E2E tests** on BSC mainnet fork

### 6.2 Unit Test Structure

```javascript
const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("MyProtocolFacet Tests", function () {
    let facet;
    let deployer, admin;

    const FacetCutAction = { Add: 0, Replace: 1, Remove: 2 };

    before(async function () {
        [deployer, admin] = await ethers.getSigners();
        // Deploy diamond with your facet
        // See existing tests for patterns
    });

    describe("Initialization", function () {
        it("should initialize with correct protocol address", async function () {
            await facet.initializeMyProtocol(PROTOCOL_ADDRESS);
            expect(await facet.isInitialized()).to.be.true;
        });

        it("should revert on re-initialization", async function () {
            await expect(
                facet.initializeMyProtocol(PROTOCOL_ADDRESS)
            ).to.be.revertedWithCustomError(facet, "AlreadyInitialized");
        });
    });

    describe("Core Operations", function () {
        it("should deposit successfully", async function () {
            // Test deposit
        });

        it("should withdraw successfully", async function () {
            // Test withdraw
        });

        it("should reject non-admin calls", async function () {
            await expect(
                facet.connect(nonAdmin).deposit(amount)
            ).to.be.revertedWith("MyProtocolFacet: caller is not admin or owner");
        });
    });
});
```

### 6.3 E2E Fork Test Pattern

```javascript
const { ethers, network } = require("hardhat");
const { expect } = require("chai");

describe("MyProtocol E2E Tests (BSC Mainnet Fork)", function () {
    this.timeout(600000); // 10 minutes

    const BSC_RPC = "https://rpc.ankr.com/bsc/{your-api-key}";
    const FORK_BLOCK = 79440000;

    before(async function () {
        // Fork BSC mainnet
        await network.provider.request({
            method: "hardhat_reset",
            params: [{
                forking: {
                    jsonRpcUrl: BSC_RPC,
                    blockNumber: FORK_BLOCK,
                },
            }],
        });

        // Deploy diamond and attach facet
        // Fund wallet with tokens
    });

    it("should execute deposit on real protocol", async function () {
        // Test with real mainnet contracts
    });
});
```

### 6.4 Running Tests

```bash
# Unit tests
npx hardhat test test/MyProtocolFacet.test.js

# E2E tests (requires archive RPC)
BSC_RPC_URL=<your-rpc> npx hardhat test test/MyProtocolE2E.test.js

# Coverage
npx hardhat coverage --testfiles "test/MyProtocol*.js"
```

---

## 7. Submission Process

### 7.1 Repository Structure

Submit your facet to the `sly-community-facets` repository:

```
submissions/pending/my-protocol-facet/
├── contracts/
│   ├── IMyProtocolFacet.sol
│   ├── MyProtocolFacet.sol
│   └── MyProtocolStorage.sol
├── test/
│   ├── MyProtocolFacet.test.js
│   └── MyProtocolE2E.test.js
├── scripts/
│   ├── deploy.js
│   └── attach.js
└── README.md
```

### 7.2 Submission Checklist

Before submitting, verify:

- [ ] Follows facet template structure
- [ ] All tests pass locally
- [ ] Contract size < 24KB (`npx hardhat size-contracts`)
- [ ] Uses approved libraries only (no custom external dependencies)
- [ ] Uses diamond storage pattern with unique hash
- [ ] Implements proper access control (`onlyAdmin`)
- [ ] Uses reentrancy guard (`nonReentrant`)
- [ ] Integrates SLY fee collection
- [ ] README complete with:
  - Facet purpose
  - Target protocol description
  - Function documentation
  - Usage examples
  - Security considerations

### 7.3 PR Requirements

Your pull request must include:

1. **Facet purpose**: What protocol does it integrate?
2. **Test coverage report**: Minimum 80%
3. **Security considerations**: Known risks and mitigations
4. **Fee split request**: Percentage (max 50%)
5. **Developer wallet address**: For revenue sharing

---

## 8. Audit Requirements

### 8.1 Audit Tiers

| Complexity | Lines of Code | Audit Level | Estimated Cost |
|------------|---------------|-------------|----------------|
| Simple | < 200 | Internal review + Slither | Free |
| Medium | 200-500 | External audit (1 auditor) | $3-5K |
| Complex | > 500 | Full audit (2+ auditors) | $10-20K |

### 8.2 Pre-Audit Automated Checks

All submissions automatically run:
- **Compilation check**: Must compile without errors
- **Slither analysis**: Static security analysis
- **Size check**: Contract < 24KB
- **Test execution**: All tests must pass
- **Coverage check**: Minimum 80% line coverage

### 8.3 Security Best Practices

Your facet will be evaluated for:

| Category | Requirements |
|----------|--------------|
| **Access Control** | Proper use of `onlyAdmin` modifier |
| **Reentrancy** | Use of `nonReentrant` for state-changing functions |
| **Storage** | Unique diamond storage hash, no collisions |
| **External Calls** | Use SafeERC20, check return values |
| **Input Validation** | Validate all parameters |
| **No Backdoors** | No owner-only withdrawal, no hidden admin functions |

---

## 9. Revenue Sharing

### 9.1 How It Works

When users use your facet and pay SLY fees:

1. User calls your facet function
2. Fee is calculated based on transaction value
3. Fee is split:
   - 10% to executor (transaction caller)
   - X% to you (developer)
   - (90-X)% to SLY treasury

### 9.2 Developer Registration

After your facet passes audit:

1. Facet is deployed to mainnet
2. You're registered in the Developer Registry with:
   - Facet address
   - Your wallet address
   - Fee split percentage
3. Fees are distributed automatically on each transaction

### 9.3 Tracking Earnings

Events are emitted for tracking:

```solidity
event DeveloperFeeCollected(
    address indexed facetAddress,
    address indexed developerWallet,
    address token,
    uint256 amount,
    uint256 timestamp
);
```

You can track your earnings via:
- On-chain events
- Developer dashboard (coming soon)
- Direct contract queries

### 9.4 Updating Your Wallet

You can update your receiving wallet address by calling:

```solidity
function updateDeveloperWallet(address facetAddress, address payable newWallet) external;
```

Only the current registered developer can update their wallet.

---

## Quick Start Template

Copy this template to start your facet:

```bash
# Clone the template
cp -r templates/facets/BasicProtocolFacet submissions/pending/my-protocol-facet

# Update storage hash
sed -i 's/basicprotocol/myprotocol/g' submissions/pending/my-protocol-facet/contracts/*.sol

# Start developing!
```

---

## Support

- **GitHub Issues**: [sly-community-facets/issues](https://github.com/singularry/sly-community-facets/issues)
- **Documentation**: [docs.singularry.com](https://docs.singularry.com)
- **Discord**: [discord.gg/singularry](https://discord.gg/singularry)

---

## License

All submitted facets must be MIT licensed to be included in the SLY ecosystem.

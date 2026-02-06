// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LendingProtocolStorage
 * @notice Diamond storage for lending protocol facet
 * @dev Specialized storage for DeFi lending integrations (Aave, Venus, Compound-style)
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "LendingProtocol" with your protocol name (e.g., "VenusLending")
 * 2. Update the storage position hash
 * 3. Add protocol-specific configuration fields
 */
library LendingProtocolStorage {
    bytes32 constant STORAGE_POSITION = keccak256("com.slywallet.lendingprotocol.storage");

    /// @notice Market configuration for a lending pool
    struct MarketConfig {
        address underlying;           // Underlying token (e.g., USDT)
        address lendingToken;         // Protocol token (e.g., vUSDT, aUSDT)
        uint256 collateralFactorBps;  // Collateral factor in basis points (8000 = 80%)
        bool isCollateral;            // Can be used as collateral
        bool isBorrowable;            // Can be borrowed
    }

    /// @notice User position tracking
    struct Position {
        uint256 supplied;             // Total supplied (in underlying)
        uint256 borrowed;             // Total borrowed (in underlying)
        uint256 lastUpdated;          // Last position update timestamp
    }

    struct Layout {
        // ============ Core Addresses ============
        bool initialized;
        address lendingPool;          // Main lending pool/comptroller
        address oracle;               // Price oracle for health factor calc
        address interestRateModel;    // Interest rate model (if needed)

        // ============ Configuration ============
        uint256 minHealthFactorBps;   // Minimum health factor (10000 = 1.0)
        uint256 defaultSlippageBps;   // Default slippage for swaps

        // ============ Market Registry ============
        address[] supportedMarkets;   // List of supported underlying tokens
        mapping(address => MarketConfig) marketConfigs; // underlying => config
        mapping(address => bool) isMarketSupported;

        // ============ Position Tracking ============
        // Note: Most lending protocols track positions internally
        // Only add if you need wallet-side tracking
        mapping(address => Position) positions;  // underlying => position
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}

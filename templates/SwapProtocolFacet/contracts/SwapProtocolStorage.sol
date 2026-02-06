// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SwapProtocolStorage
 * @notice Diamond storage for DEX swap integration facet
 * @dev Specialized storage for DEX integrations (Uniswap, PancakeSwap, 1inch-style)
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "SwapProtocol" with your DEX name (e.g., "PancakeSwap")
 * 2. Update the storage position hash
 * 3. Add DEX-specific configuration (fee tiers, quoters, etc.)
 */
library SwapProtocolStorage {
    bytes32 constant STORAGE_POSITION = keccak256("com.slywallet.swapprotocol.storage");

    /// @notice Route configuration for a token pair
    struct RouteConfig {
        address[] path;               // Token path for multi-hop swaps
        uint24[] fees;                // Fee tiers for each hop (V3 style)
        bool isV3;                    // True for V3-style, false for V2-style
        uint256 maxSlippageBps;       // Max allowed slippage for this route
    }

    struct Layout {
        // ============ Core Addresses ============
        bool initialized;
        address router;               // Swap router address
        address factory;              // Factory for pool discovery
        address quoter;               // Quoter for price estimation (V3)
        address weth;                 // Wrapped native token (WBNB, WETH)

        // ============ Configuration ============
        uint256 defaultSlippageBps;   // Default slippage tolerance (100 = 1%)
        uint256 defaultDeadline;      // Default deadline in seconds
        uint256 maxHops;              // Maximum swap hops allowed

        // ============ Route Registry ============
        /// @dev tokenA => tokenB => RouteConfig
        /// Use sorted addresses for consistent key lookup
        mapping(bytes32 => RouteConfig) routes;

        // ============ Approved Tokens ============
        mapping(address => bool) approvedTokens;
        address[] approvedTokenList;
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }

    /// @dev Generate a unique key for a token pair (sorted)
    function getPairKey(address tokenA, address tokenB) internal pure returns (bytes32) {
        return tokenA < tokenB
            ? keccak256(abi.encodePacked(tokenA, tokenB))
            : keccak256(abi.encodePacked(tokenB, tokenA));
    }
}

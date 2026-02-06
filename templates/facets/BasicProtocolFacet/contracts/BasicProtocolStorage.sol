// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BasicProtocolStorage
 * @notice Diamond storage for BasicProtocol facet
 * @dev Uses diamond storage pattern with unique keccak256 hash to prevent collisions
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "BasicProtocol" with your protocol name (e.g., "VenusProtocol")
 * 2. Replace the storage position hash with a unique identifier:
 *    keccak256("com.slywallet.yourprotocolname.storage")
 * 3. Add protocol-specific configuration fields to the Layout struct
 * 4. Consider what state needs to persist between function calls
 */
library BasicProtocolStorage {
    // IMPORTANT: Change this hash to be unique for your facet
    // Format: keccak256("com.slywallet.<yourprotocol>.storage")
    bytes32 constant STORAGE_POSITION = keccak256("com.slywallet.basicprotocol.storage");

    /**
     * @dev Storage layout for this facet
     *
     * Add your protocol-specific fields here. Common patterns:
     * - Protocol contract addresses (routers, vaults, controllers)
     * - Configuration parameters (slippage, fees, limits)
     * - User position tracking (if not handled by external protocol)
     */
    struct Layout {
        /// @notice Whether the facet has been initialized
        bool initialized;

        /// @notice External protocol contract address
        /// @dev Replace with your actual protocol's main contract
        address protocolAddress;

        /// @notice Example: secondary protocol address (router, oracle, etc.)
        address secondaryAddress;

        // Add more protocol-specific fields as needed:
        // uint256 maxAmount;
        // uint256 slippageBps;
        // mapping(address => uint256) userDeposits;
    }

    /**
     * @notice Access the storage layout
     * @dev Uses assembly to access storage at the computed position
     * @return l Storage layout reference
     */
    function layout() internal pure returns (Layout storage l) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            l.slot := position
        }
    }
}

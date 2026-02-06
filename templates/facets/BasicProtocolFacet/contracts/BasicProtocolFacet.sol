// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IBasicProtocolFacet.sol";
import "./BasicProtocolStorage.sol";

// SLYWallet core imports - these paths assume facet is in contracts/slywallet/facets/
// Adjust paths based on your actual location
import "../../../../contracts/slywallet/libraries/LibPermissions.sol";
import "../../../../contracts/slywallet/SLYWalletReentrancyGuard.sol";
import "../../../../contracts/slywallet/facets/base/ISLYWalletBase.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title BasicProtocolFacet
 * @notice Template facet for integrating external protocols with SLYWallet
 * @dev Demonstrates core patterns: storage, permissions, reentrancy protection
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "BasicProtocol" throughout with your protocol name
 * 2. Update import paths based on where your facet is located
 * 3. Replace placeholder functions with actual protocol integration
 * 4. Add protocol-specific interface imports
 * 5. Implement proper error handling for external calls
 *
 * PATTERNS DEMONSTRATED:
 * - Diamond storage pattern for isolated state
 * - Role-based access control (Owner/Admin)
 * - Cross-facet reentrancy protection
 * - Safe token operations with SafeERC20
 * - Initialization guard pattern
 */
contract BasicProtocolFacet is IBasicProtocolFacet, SLYWalletReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Modifiers ============

    /**
     * @dev Restricts function to admin or owner role
     * Use this for configuration and administrative functions
     */
    modifier onlyAdmin() {
        require(
            LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Admin) ||
            LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Owner),
            "BasicProtocolFacet: caller is not admin or owner"
        );
        _;
    }

    /**
     * @dev Ensures facet is initialized before use
     */
    modifier onlyInitialized() {
        if (!BasicProtocolStorage.layout().initialized) {
            revert NotInitialized();
        }
        _;
    }

    // ============ Initialization ============

    /// @inheritdoc IBasicProtocolFacet
    function initializeBasicProtocol(address _protocolAddress) external onlyAdmin {
        BasicProtocolStorage.Layout storage s = BasicProtocolStorage.layout();

        if (s.initialized) revert AlreadyInitialized();
        if (_protocolAddress == address(0)) revert InvalidAddress();

        s.protocolAddress = _protocolAddress;
        s.initialized = true;

        emit BasicProtocolInitialized(_protocolAddress);
    }

    /// @inheritdoc IBasicProtocolFacet
    function setProtocolAddress(address _newAddress) external onlyAdmin onlyInitialized {
        if (_newAddress == address(0)) revert InvalidAddress();

        BasicProtocolStorage.Layout storage s = BasicProtocolStorage.layout();
        address oldAddress = s.protocolAddress;
        s.protocolAddress = _newAddress;

        emit ProtocolAddressUpdated(oldAddress, _newAddress);
    }

    // ============ Core Operations ============

    /// @inheritdoc IBasicProtocolFacet
    function protocolDeposit(
        address token,
        uint256 amount
    ) external onlyAdmin onlyInitialized nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (token == address(0)) revert InvalidAddress();

        BasicProtocolStorage.Layout storage s = BasicProtocolStorage.layout();

        // Check wallet has sufficient balance
        uint256 walletBalance = IERC20(token).balanceOf(address(this));
        if (walletBalance < amount) revert InsufficientBalance();

        // Approve protocol to spend tokens
        IERC20(token).forceApprove(s.protocolAddress, amount);

        // TODO: Replace with actual protocol deposit call
        // Example:
        // IExternalProtocol(s.protocolAddress).deposit(token, amount);
        //
        // For now, this is a placeholder that just transfers to protocol
        IERC20(token).safeTransfer(s.protocolAddress, amount);

        emit Deposited(token, amount);
    }

    /// @inheritdoc IBasicProtocolFacet
    function protocolWithdraw(
        address token,
        uint256 amount
    ) external onlyAdmin onlyInitialized nonReentrant {
        if (amount == 0) revert InvalidAmount();
        if (token == address(0)) revert InvalidAddress();

        // TODO: Replace with actual protocol withdrawal call
        // Example:
        // BasicProtocolStorage.Layout storage s = BasicProtocolStorage.layout();
        // IExternalProtocol(s.protocolAddress).withdraw(token, amount);
        //
        // Most protocols transfer tokens back to msg.sender (this wallet)
        // automatically on withdraw

        emit Withdrawn(token, amount);
    }

    // ============ View Functions ============

    /// @inheritdoc IBasicProtocolFacet
    function getProtocolAddress() external view returns (address) {
        return BasicProtocolStorage.layout().protocolAddress;
    }

    /// @inheritdoc IBasicProtocolFacet
    function isBasicProtocolInitialized() external view returns (bool) {
        return BasicProtocolStorage.layout().initialized;
    }

    /// @inheritdoc IBasicProtocolFacet
    function getProtocolBalance() external view onlyInitialized returns (uint256) {
        // TODO: Replace with actual protocol balance query
        // Example:
        // BasicProtocolStorage.Layout storage s = BasicProtocolStorage.layout();
        // return IExternalProtocol(s.protocolAddress).balanceOf(address(this));

        return 0;
    }

    // ============ Internal Helpers ============

    /**
     * @dev Example internal helper for common operations
     * Add your protocol-specific helpers here
     */
    function _getStorage() internal pure returns (BasicProtocolStorage.Layout storage) {
        return BasicProtocolStorage.layout();
    }
}

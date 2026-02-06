// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBasicProtocolFacet
 * @notice Interface for BasicProtocol facet integration
 * @dev Defines the external API for wallet users to interact with the protocol
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "BasicProtocol" with your protocol name
 * 2. Define events for all state-changing operations (for off-chain tracking)
 * 3. Define custom errors with descriptive names
 * 4. Group functions logically: Initialization, Core Operations, View Functions
 * 5. Document all functions with NatSpec comments
 */
interface IBasicProtocolFacet {
    // ============ Events ============
    // Events are crucial for off-chain tracking and frontend updates

    /// @notice Emitted when the facet is initialized
    event BasicProtocolInitialized(address indexed protocolAddress);

    /// @notice Emitted when protocol address is updated
    event ProtocolAddressUpdated(address indexed oldAddress, address indexed newAddress);

    /// @notice Emitted when a deposit is made
    event Deposited(address indexed token, uint256 amount);

    /// @notice Emitted when a withdrawal is made
    event Withdrawn(address indexed token, uint256 amount);

    // ============ Errors ============
    // Custom errors save gas compared to require strings

    /// @notice Thrown when trying to initialize an already initialized facet
    error AlreadyInitialized();

    /// @notice Thrown when calling a function before initialization
    error NotInitialized();

    /// @notice Thrown when an address parameter is zero
    error InvalidAddress();

    /// @notice Thrown when an amount parameter is zero or invalid
    error InvalidAmount();

    /// @notice Thrown when wallet has insufficient token balance
    error InsufficientBalance();

    /// @notice Thrown when external protocol call fails
    error ProtocolCallFailed();

    // ============ Initialization ============

    /**
     * @notice Initialize the facet with protocol addresses
     * @dev Can only be called once by admin/owner
     * @param _protocolAddress Main protocol contract address
     */
    function initializeBasicProtocol(address _protocolAddress) external;

    /**
     * @notice Update the protocol address (admin only)
     * @param _newAddress New protocol contract address
     */
    function setProtocolAddress(address _newAddress) external;

    // ============ Core Operations ============
    // Replace these with your protocol's actual operations

    /**
     * @notice Deposit tokens into the external protocol
     * @dev Transfers tokens from wallet to protocol
     * @param token Token address to deposit
     * @param amount Amount to deposit
     */
    function protocolDeposit(address token, uint256 amount) external;

    /**
     * @notice Withdraw tokens from the external protocol
     * @dev Transfers tokens from protocol back to wallet
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function protocolWithdraw(address token, uint256 amount) external;

    // ============ View Functions ============

    /**
     * @notice Get the protocol contract address
     * @return Protocol address
     */
    function getProtocolAddress() external view returns (address);

    /**
     * @notice Check if facet is initialized
     * @return Initialization status
     */
    function isBasicProtocolInitialized() external view returns (bool);

    /**
     * @notice Get wallet's position in the protocol
     * @return balance Current deposited balance
     */
    function getProtocolBalance() external view returns (uint256 balance);
}

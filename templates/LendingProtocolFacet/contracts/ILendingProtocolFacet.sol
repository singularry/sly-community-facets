// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ILendingProtocolFacet
 * @notice Interface for lending protocol integration facet
 * @dev Covers common lending operations: supply, borrow, repay, withdraw
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "LendingProtocol" with your protocol name
 * 2. Add protocol-specific functions (e.g., claim rewards, enter markets)
 * 3. Adjust parameters based on protocol requirements
 */
interface ILendingProtocolFacet {
    // ============ Events ============

    event LendingProtocolInitialized(address indexed lendingPool, address indexed oracle);
    event MarketConfigured(address indexed underlying, address indexed lendingToken, uint256 collateralFactorBps);
    event Supplied(address indexed market, uint256 amount, uint256 shares);
    event Withdrawn(address indexed market, uint256 amount, uint256 shares);
    event Borrowed(address indexed market, uint256 amount);
    event Repaid(address indexed market, uint256 amount, uint256 remaining);
    event CollateralEnabled(address indexed market);
    event CollateralDisabled(address indexed market);

    // ============ Errors ============

    error AlreadyInitialized();
    error NotInitialized();
    error InvalidAddress();
    error InvalidAmount();
    error MarketNotSupported();
    error InsufficientBalance();
    error InsufficientCollateral();
    error HealthFactorTooLow();
    error WithdrawWouldLiquidate();
    error BorrowExceedsLimit();
    error RepayExceedsDebt();

    // ============ Initialization ============

    /**
     * @notice Initialize the lending facet
     * @param _lendingPool Main lending pool/comptroller address
     * @param _oracle Price oracle address
     * @param _minHealthFactorBps Minimum health factor (10000 = 1.0, 12000 = 1.2)
     */
    function initializeLendingProtocol(
        address _lendingPool,
        address _oracle,
        uint256 _minHealthFactorBps
    ) external;

    /**
     * @notice Configure a lending market
     * @param underlying Underlying token address
     * @param lendingToken Protocol's lending token (aToken, vToken, cToken)
     * @param collateralFactorBps Collateral factor in basis points
     * @param isCollateral Whether this market can be used as collateral
     * @param isBorrowable Whether this market can be borrowed from
     */
    function configureMarket(
        address underlying,
        address lendingToken,
        uint256 collateralFactorBps,
        bool isCollateral,
        bool isBorrowable
    ) external;

    // ============ Supply Operations ============

    /**
     * @notice Supply tokens to the lending protocol
     * @param underlying Token to supply
     * @param amount Amount to supply
     * @return shares Amount of lending tokens received
     */
    function lendingSupply(address underlying, uint256 amount) external returns (uint256 shares);

    /**
     * @notice Withdraw tokens from the lending protocol
     * @param underlying Token to withdraw
     * @param amount Amount to withdraw (0 for max)
     * @return withdrawn Actual amount withdrawn
     */
    function lendingWithdraw(address underlying, uint256 amount) external returns (uint256 withdrawn);

    // ============ Borrow Operations ============

    /**
     * @notice Borrow tokens from the lending protocol
     * @dev Will revert if health factor would drop below minimum
     * @param underlying Token to borrow
     * @param amount Amount to borrow
     */
    function lendingBorrow(address underlying, uint256 amount) external;

    /**
     * @notice Repay borrowed tokens
     * @param underlying Token to repay
     * @param amount Amount to repay (type(uint256).max for full repay)
     * @return repaid Actual amount repaid
     */
    function lendingRepay(address underlying, uint256 amount) external returns (uint256 repaid);

    // ============ Collateral Management ============

    /**
     * @notice Enable a market as collateral
     * @param underlying Market to enable
     */
    function enableCollateral(address underlying) external;

    /**
     * @notice Disable a market as collateral
     * @dev Will revert if this would cause liquidation
     * @param underlying Market to disable
     */
    function disableCollateral(address underlying) external;

    // ============ View Functions ============

    /**
     * @notice Get the lending pool address
     */
    function getLendingPool() external view returns (address);

    /**
     * @notice Check if facet is initialized
     */
    function isLendingProtocolInitialized() external view returns (bool);

    /**
     * @notice Get wallet's supply balance in a market
     * @param underlying Market underlying token
     * @return Supplied amount in underlying terms
     */
    function getSupplyBalance(address underlying) external view returns (uint256);

    /**
     * @notice Get wallet's borrow balance in a market
     * @param underlying Market underlying token
     * @return Borrowed amount (including accrued interest)
     */
    function getBorrowBalance(address underlying) external view returns (uint256);

    /**
     * @notice Get wallet's current health factor
     * @return Health factor in basis points (10000 = 1.0)
     */
    function getHealthFactor() external view returns (uint256);

    /**
     * @notice Get maximum borrowable amount
     * @param underlying Token to borrow
     * @return Maximum borrow amount while maintaining min health factor
     */
    function getMaxBorrow(address underlying) external view returns (uint256);

    /**
     * @notice Get maximum withdrawable amount
     * @param underlying Token to withdraw
     * @return Maximum withdraw amount while maintaining min health factor
     */
    function getMaxWithdraw(address underlying) external view returns (uint256);

    /**
     * @notice Get market configuration
     * @param underlying Market underlying token
     */
    function getMarketConfig(address underlying) external view returns (
        address lendingToken,
        uint256 collateralFactorBps,
        bool isCollateral,
        bool isBorrowable
    );

    /**
     * @notice Get all supported markets
     */
    function getSupportedMarkets() external view returns (address[] memory);
}

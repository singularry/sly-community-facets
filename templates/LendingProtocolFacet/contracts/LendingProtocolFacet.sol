// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ILendingProtocolFacet.sol";
import "./LendingProtocolStorage.sol";

// SLYWallet core imports
import "../../../../contracts/slywallet/libraries/LibPermissions.sol";
import "../../../../contracts/slywallet/SLYWalletReentrancyGuard.sol";
import "../../../../contracts/slywallet/facets/base/ISLYWalletBase.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LendingProtocolFacet
 * @notice Template facet for integrating lending protocols (Aave, Venus, Compound-style)
 * @dev Implements supply/borrow/repay/withdraw with health factor monitoring
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace placeholder protocol interfaces with actual protocol interfaces
 * 2. Implement actual protocol calls in marked TODO sections
 * 3. Adjust health factor calculation based on protocol specifics
 * 4. Add protocol-specific functions (claim rewards, etc.)
 *
 * PATTERNS DEMONSTRATED:
 * - Health factor checks before risky operations
 * - Market configuration management
 * - Position tracking with lending tokens
 * - Oracle integration for collateral valuation
 */
contract LendingProtocolFacet is ILendingProtocolFacet, SLYWalletReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 constant BPS_DENOMINATOR = 10000;

    // ============ Modifiers ============

    modifier onlyAdmin() {
        require(
            LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Admin) ||
            LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Owner),
            "LendingProtocolFacet: caller is not admin or owner"
        );
        _;
    }

    modifier onlyInitialized() {
        if (!LendingProtocolStorage.layout().initialized) {
            revert NotInitialized();
        }
        _;
    }

    modifier marketSupported(address underlying) {
        if (!LendingProtocolStorage.layout().isMarketSupported[underlying]) {
            revert MarketNotSupported();
        }
        _;
    }

    // ============ Initialization ============

    /// @inheritdoc ILendingProtocolFacet
    function initializeLendingProtocol(
        address _lendingPool,
        address _oracle,
        uint256 _minHealthFactorBps
    ) external onlyAdmin {
        LendingProtocolStorage.Layout storage s = LendingProtocolStorage.layout();

        if (s.initialized) revert AlreadyInitialized();
        if (_lendingPool == address(0)) revert InvalidAddress();
        if (_oracle == address(0)) revert InvalidAddress();

        s.lendingPool = _lendingPool;
        s.oracle = _oracle;
        s.minHealthFactorBps = _minHealthFactorBps;
        s.initialized = true;

        emit LendingProtocolInitialized(_lendingPool, _oracle);
    }

    /// @inheritdoc ILendingProtocolFacet
    function configureMarket(
        address underlying,
        address lendingToken,
        uint256 collateralFactorBps,
        bool isCollateral,
        bool isBorrowable
    ) external onlyAdmin onlyInitialized {
        if (underlying == address(0) || lendingToken == address(0)) revert InvalidAddress();

        LendingProtocolStorage.Layout storage s = LendingProtocolStorage.layout();

        if (!s.isMarketSupported[underlying]) {
            s.supportedMarkets.push(underlying);
            s.isMarketSupported[underlying] = true;
        }

        s.marketConfigs[underlying] = LendingProtocolStorage.MarketConfig({
            underlying: underlying,
            lendingToken: lendingToken,
            collateralFactorBps: collateralFactorBps,
            isCollateral: isCollateral,
            isBorrowable: isBorrowable
        });

        emit MarketConfigured(underlying, lendingToken, collateralFactorBps);
    }

    // ============ Supply Operations ============

    /// @inheritdoc ILendingProtocolFacet
    function lendingSupply(
        address underlying,
        uint256 amount
    ) external onlyAdmin onlyInitialized marketSupported(underlying) nonReentrant returns (uint256 shares) {
        if (amount == 0) revert InvalidAmount();

        LendingProtocolStorage.Layout storage s = LendingProtocolStorage.layout();
        LendingProtocolStorage.MarketConfig storage market = s.marketConfigs[underlying];

        // Check wallet balance
        uint256 balance = IERC20(underlying).balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        // Approve lending pool
        IERC20(underlying).forceApprove(s.lendingPool, amount);

        // TODO: Replace with actual protocol supply call
        // Example for Aave-style:
        // ILendingPool(s.lendingPool).supply(underlying, amount, address(this), 0);
        //
        // Example for Compound-style:
        // ICToken(market.lendingToken).mint(amount);

        // Get shares received (lending tokens)
        shares = IERC20(market.lendingToken).balanceOf(address(this));

        emit Supplied(underlying, amount, shares);
    }

    /// @inheritdoc ILendingProtocolFacet
    function lendingWithdraw(
        address underlying,
        uint256 amount
    ) external onlyAdmin onlyInitialized marketSupported(underlying) nonReentrant returns (uint256 withdrawn) {
        LendingProtocolStorage.Layout storage s = LendingProtocolStorage.layout();

        // Check if withdrawal would drop health factor too low
        if (amount > 0) {
            uint256 maxWithdraw = _calculateMaxWithdraw(underlying);
            if (amount > maxWithdraw) revert WithdrawWouldLiquidate();
        }

        // TODO: Replace with actual protocol withdraw call
        // Example for Aave-style:
        // withdrawn = ILendingPool(s.lendingPool).withdraw(underlying, amount, address(this));
        //
        // Example for Compound-style:
        // ICToken(market.lendingToken).redeemUnderlying(amount);

        withdrawn = amount; // Placeholder

        emit Withdrawn(underlying, withdrawn, 0);
    }

    // ============ Borrow Operations ============

    /// @inheritdoc ILendingProtocolFacet
    function lendingBorrow(
        address underlying,
        uint256 amount
    ) external onlyAdmin onlyInitialized marketSupported(underlying) nonReentrant {
        if (amount == 0) revert InvalidAmount();

        LendingProtocolStorage.Layout storage s = LendingProtocolStorage.layout();
        LendingProtocolStorage.MarketConfig storage market = s.marketConfigs[underlying];

        if (!market.isBorrowable) revert MarketNotSupported();

        // Check borrow capacity
        uint256 maxBorrow = _calculateMaxBorrow(underlying);
        if (amount > maxBorrow) revert BorrowExceedsLimit();

        // TODO: Replace with actual protocol borrow call
        // Example for Aave-style:
        // ILendingPool(s.lendingPool).borrow(underlying, amount, 2, 0, address(this));
        //
        // Example for Compound-style:
        // ICToken(market.lendingToken).borrow(amount);

        // Verify health factor after borrow
        uint256 newHealthFactor = _calculateHealthFactor();
        if (newHealthFactor < s.minHealthFactorBps) revert HealthFactorTooLow();

        emit Borrowed(underlying, amount);
    }

    /// @inheritdoc ILendingProtocolFacet
    function lendingRepay(
        address underlying,
        uint256 amount
    ) external onlyAdmin onlyInitialized marketSupported(underlying) nonReentrant returns (uint256 repaid) {
        LendingProtocolStorage.Layout storage s = LendingProtocolStorage.layout();

        // Get current borrow balance
        uint256 borrowBalance = _getBorrowBalance(underlying);
        if (borrowBalance == 0) revert InvalidAmount();

        // Determine repay amount
        repaid = amount == type(uint256).max ? borrowBalance : amount;
        if (repaid > borrowBalance) {
            repaid = borrowBalance;
        }

        // Check wallet balance
        uint256 walletBalance = IERC20(underlying).balanceOf(address(this));
        if (walletBalance < repaid) revert InsufficientBalance();

        // Approve lending pool
        IERC20(underlying).forceApprove(s.lendingPool, repaid);

        // TODO: Replace with actual protocol repay call
        // Example for Aave-style:
        // ILendingPool(s.lendingPool).repay(underlying, repaid, 2, address(this));
        //
        // Example for Compound-style:
        // ICToken(market.lendingToken).repayBorrow(repaid);

        uint256 remaining = borrowBalance - repaid;
        emit Repaid(underlying, repaid, remaining);
    }

    // ============ Collateral Management ============

    /// @inheritdoc ILendingProtocolFacet
    function enableCollateral(
        address underlying
    ) external onlyAdmin onlyInitialized marketSupported(underlying) {
        LendingProtocolStorage.Layout storage s = LendingProtocolStorage.layout();

        // TODO: Replace with actual protocol call
        // Example for Compound-style:
        // address[] memory markets = new address[](1);
        // markets[0] = s.marketConfigs[underlying].lendingToken;
        // IComptroller(s.lendingPool).enterMarkets(markets);

        emit CollateralEnabled(underlying);
    }

    /// @inheritdoc ILendingProtocolFacet
    function disableCollateral(
        address underlying
    ) external onlyAdmin onlyInitialized marketSupported(underlying) {
        // Check if disabling would cause liquidation
        uint256 newHealthFactor = _calculateHealthFactorWithoutCollateral(underlying);
        if (newHealthFactor < LendingProtocolStorage.layout().minHealthFactorBps) {
            revert WithdrawWouldLiquidate();
        }

        // TODO: Replace with actual protocol call
        // Example for Compound-style:
        // IComptroller(s.lendingPool).exitMarket(s.marketConfigs[underlying].lendingToken);

        emit CollateralDisabled(underlying);
    }

    // ============ View Functions ============

    /// @inheritdoc ILendingProtocolFacet
    function getLendingPool() external view returns (address) {
        return LendingProtocolStorage.layout().lendingPool;
    }

    /// @inheritdoc ILendingProtocolFacet
    function isLendingProtocolInitialized() external view returns (bool) {
        return LendingProtocolStorage.layout().initialized;
    }

    /// @inheritdoc ILendingProtocolFacet
    function getSupplyBalance(address underlying) external view onlyInitialized returns (uint256) {
        return _getSupplyBalance(underlying);
    }

    /// @inheritdoc ILendingProtocolFacet
    function getBorrowBalance(address underlying) external view onlyInitialized returns (uint256) {
        return _getBorrowBalance(underlying);
    }

    /// @inheritdoc ILendingProtocolFacet
    function getHealthFactor() external view onlyInitialized returns (uint256) {
        return _calculateHealthFactor();
    }

    /// @inheritdoc ILendingProtocolFacet
    function getMaxBorrow(address underlying) external view onlyInitialized returns (uint256) {
        return _calculateMaxBorrow(underlying);
    }

    /// @inheritdoc ILendingProtocolFacet
    function getMaxWithdraw(address underlying) external view onlyInitialized returns (uint256) {
        return _calculateMaxWithdraw(underlying);
    }

    /// @inheritdoc ILendingProtocolFacet
    function getMarketConfig(address underlying) external view returns (
        address lendingToken,
        uint256 collateralFactorBps,
        bool isCollateral,
        bool isBorrowable
    ) {
        LendingProtocolStorage.MarketConfig storage config =
            LendingProtocolStorage.layout().marketConfigs[underlying];

        return (
            config.lendingToken,
            config.collateralFactorBps,
            config.isCollateral,
            config.isBorrowable
        );
    }

    /// @inheritdoc ILendingProtocolFacet
    function getSupportedMarkets() external view returns (address[] memory) {
        return LendingProtocolStorage.layout().supportedMarkets;
    }

    // ============ Internal Functions ============

    function _getSupplyBalance(address underlying) internal view returns (uint256) {
        LendingProtocolStorage.Layout storage s = LendingProtocolStorage.layout();
        LendingProtocolStorage.MarketConfig storage market = s.marketConfigs[underlying];

        // TODO: Replace with actual balance calculation
        // Most protocols: lending token balance * exchange rate
        return IERC20(market.lendingToken).balanceOf(address(this));
    }

    function _getBorrowBalance(address underlying) internal view returns (uint256) {
        // TODO: Replace with actual protocol borrow balance query
        // Example: ICToken(lendingToken).borrowBalanceCurrent(address(this))
        return 0;
    }

    function _calculateHealthFactor() internal view returns (uint256) {
        // TODO: Implement actual health factor calculation
        // Health Factor = (Total Collateral Value * Weighted Average CF) / Total Borrow Value
        //
        // Example implementation:
        // uint256 totalCollateralValue = 0;
        // uint256 totalBorrowValue = 0;
        //
        // for each market:
        //   supply = getSupplyBalance(market)
        //   price = oracle.getPrice(market)
        //   collateralFactor = marketConfig.collateralFactorBps
        //   totalCollateralValue += supply * price * collateralFactor / BPS_DENOMINATOR
        //
        //   borrow = getBorrowBalance(market)
        //   totalBorrowValue += borrow * price
        //
        // return totalBorrowValue == 0 ? type(uint256).max : totalCollateralValue * BPS_DENOMINATOR / totalBorrowValue

        return type(uint256).max; // Placeholder: infinite health factor
    }

    function _calculateHealthFactorWithoutCollateral(address /*underlying*/) internal view returns (uint256) {
        // TODO: Calculate health factor excluding specified collateral
        return type(uint256).max;
    }

    function _calculateMaxBorrow(address /*underlying*/) internal view returns (uint256) {
        // TODO: Calculate max borrow while maintaining min health factor
        // maxBorrow = (currentCollateralValue * minHealthFactor - currentBorrowValue) / minHealthFactor
        return 0;
    }

    function _calculateMaxWithdraw(address /*underlying*/) internal view returns (uint256) {
        // TODO: Calculate max withdraw while maintaining min health factor
        return type(uint256).max;
    }
}

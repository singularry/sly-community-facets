// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ISwapProtocolFacet.sol";
import "./SwapProtocolStorage.sol";

// SLYWallet core imports
import "../../../../contracts/slywallet/libraries/LibPermissions.sol";
import "../../../../contracts/slywallet/SLYWalletReentrancyGuard.sol";
import "../../../../contracts/slywallet/facets/base/ISLYWalletBase.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SwapProtocolFacet
 * @notice Template facet for DEX swap integrations
 * @dev Supports both Uniswap V2 and V3 style routers
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace placeholder interfaces with actual DEX interfaces
 * 2. Implement actual swap calls in marked TODO sections
 * 3. Add support for your DEX's specific features
 *
 * PATTERNS DEMONSTRATED:
 * - Slippage protection with min/max amounts
 * - Deadline enforcement
 * - Multi-hop routing
 * - Native token wrapping/unwrapping
 */
contract SwapProtocolFacet is ISwapProtocolFacet, SLYWalletReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 constant BPS_DENOMINATOR = 10000;
    uint256 constant MAX_SLIPPAGE_BPS = 5000; // 50% max

    // ============ Modifiers ============

    modifier onlyAdmin() {
        require(
            LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Admin) ||
            LibPermissions.hasRole(msg.sender, ISLYWalletBase.Role.Owner),
            "SwapProtocolFacet: caller is not admin or owner"
        );
        _;
    }

    modifier onlyInitialized() {
        if (!SwapProtocolStorage.layout().initialized) {
            revert NotInitialized();
        }
        _;
    }

    modifier validDeadline(uint256 deadline) {
        if (block.timestamp > deadline) {
            revert DeadlineExpired();
        }
        _;
    }

    // ============ Initialization ============

    /// @inheritdoc ISwapProtocolFacet
    function initializeSwapProtocol(
        address _router,
        address _factory,
        address _quoter,
        address _weth,
        uint256 _defaultSlippageBps
    ) external onlyAdmin {
        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();

        if (s.initialized) revert AlreadyInitialized();
        if (_router == address(0)) revert InvalidAddress();
        if (_weth == address(0)) revert InvalidAddress();
        if (_defaultSlippageBps > MAX_SLIPPAGE_BPS) revert ExcessiveSlippage();

        s.router = _router;
        s.factory = _factory;
        s.quoter = _quoter;
        s.weth = _weth;
        s.defaultSlippageBps = _defaultSlippageBps;
        s.defaultDeadline = 300; // 5 minutes
        s.maxHops = 4;
        s.initialized = true;

        emit SwapProtocolInitialized(_router, _weth);
    }

    /// @inheritdoc ISwapProtocolFacet
    function configureRoute(
        address tokenA,
        address tokenB,
        address[] calldata path,
        uint24[] calldata fees,
        bool isV3,
        uint256 maxSlippageBps
    ) external onlyAdmin onlyInitialized {
        if (tokenA == address(0) || tokenB == address(0)) revert InvalidAddress();
        if (path.length < 2) revert InvalidPath();
        if (isV3 && fees.length != path.length - 1) revert InvalidPath();
        if (maxSlippageBps > MAX_SLIPPAGE_BPS) revert ExcessiveSlippage();

        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();
        bytes32 key = SwapProtocolStorage.getPairKey(tokenA, tokenB);

        s.routes[key] = SwapProtocolStorage.RouteConfig({
            path: path,
            fees: fees,
            isV3: isV3,
            maxSlippageBps: maxSlippageBps
        });

        emit RouteConfigured(tokenA, tokenB);
    }

    /// @inheritdoc ISwapProtocolFacet
    function setDefaultSlippage(uint256 newSlippageBps) external onlyAdmin onlyInitialized {
        if (newSlippageBps > MAX_SLIPPAGE_BPS) revert ExcessiveSlippage();

        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();
        uint256 oldSlippage = s.defaultSlippageBps;
        s.defaultSlippageBps = newSlippageBps;

        emit SlippageUpdated(oldSlippage, newSlippageBps);
    }

    /// @inheritdoc ISwapProtocolFacet
    function approveToken(address token) external onlyAdmin onlyInitialized {
        if (token == address(0)) revert InvalidAddress();

        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();
        if (!s.approvedTokens[token]) {
            s.approvedTokens[token] = true;
            s.approvedTokenList.push(token);
        }
    }

    // ============ Swap Operations ============

    /// @inheritdoc ISwapProtocolFacet
    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external onlyAdmin onlyInitialized validDeadline(deadline) nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert InvalidAmount();
        if (tokenIn == address(0) || tokenOut == address(0)) revert InvalidAddress();

        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();

        // Check balance
        uint256 balance = IERC20(tokenIn).balanceOf(address(this));
        if (balance < amountIn) revert InsufficientBalance();

        // Approve router
        IERC20(tokenIn).forceApprove(s.router, amountIn);

        // Get route config or use direct path
        bytes32 key = SwapProtocolStorage.getPairKey(tokenIn, tokenOut);
        SwapProtocolStorage.RouteConfig storage route = s.routes[key];

        if (route.path.length > 0) {
            // Use configured route
            amountOut = _executeSwap(route.path, route.fees, route.isV3, amountIn, minAmountOut, deadline);
        } else {
            // Use direct swap
            amountOut = _executeDirectSwap(tokenIn, tokenOut, amountIn, minAmountOut, deadline);
        }

        if (amountOut < minAmountOut) revert InsufficientOutputAmount();

        emit TokenSwapped(tokenIn, tokenOut, amountIn, amountOut, address(this));
    }

    /// @inheritdoc ISwapProtocolFacet
    function swapExactOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        uint256 deadline
    ) external onlyAdmin onlyInitialized validDeadline(deadline) nonReentrant returns (uint256 amountIn) {
        if (amountOut == 0) revert InvalidAmount();
        if (tokenIn == address(0) || tokenOut == address(0)) revert InvalidAddress();

        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();

        // Check balance
        uint256 balance = IERC20(tokenIn).balanceOf(address(this));
        if (balance < maxAmountIn) revert InsufficientBalance();

        // Approve router for max amount
        IERC20(tokenIn).forceApprove(s.router, maxAmountIn);

        // TODO: Implement exact output swap
        // Example for V3:
        // ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
        //     tokenIn: tokenIn,
        //     tokenOut: tokenOut,
        //     fee: defaultFee,
        //     recipient: address(this),
        //     deadline: deadline,
        //     amountOut: amountOut,
        //     amountInMaximum: maxAmountIn,
        //     sqrtPriceLimitX96: 0
        // });
        // amountIn = ISwapRouter(s.router).exactOutputSingle(params);

        amountIn = maxAmountIn; // Placeholder

        emit TokenSwapped(tokenIn, tokenOut, amountIn, amountOut, address(this));
    }

    /// @inheritdoc ISwapProtocolFacet
    function swapExactInputMultihop(
        address[] calldata path,
        uint24[] calldata fees,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external onlyAdmin onlyInitialized validDeadline(deadline) nonReentrant returns (uint256 amountOut) {
        if (path.length < 2) revert InvalidPath();
        if (fees.length != path.length - 1) revert InvalidPath();
        if (amountIn == 0) revert InvalidAmount();

        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();
        if (path.length > s.maxHops + 1) revert InvalidPath();

        // Check balance
        uint256 balance = IERC20(path[0]).balanceOf(address(this));
        if (balance < amountIn) revert InsufficientBalance();

        // Approve router
        IERC20(path[0]).forceApprove(s.router, amountIn);

        amountOut = _executeSwap(path, fees, true, amountIn, minAmountOut, deadline);

        if (amountOut < minAmountOut) revert InsufficientOutputAmount();

        emit TokenSwapped(path[0], path[path.length - 1], amountIn, amountOut, address(this));
    }

    /// @inheritdoc ISwapProtocolFacet
    function swapNativeForToken(
        address tokenOut,
        uint256 minAmountOut,
        uint256 deadline
    ) external payable onlyAdmin onlyInitialized validDeadline(deadline) nonReentrant returns (uint256 amountOut) {
        if (msg.value == 0) revert InvalidAmount();
        if (tokenOut == address(0)) revert InvalidAddress();

        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();

        // TODO: Implement native to token swap
        // Most routers have a dedicated function or accept value directly
        // Example:
        // address[] memory path = new address[](2);
        // path[0] = s.weth;
        // path[1] = tokenOut;
        // uint[] memory amounts = IUniswapV2Router(s.router).swapExactETHForTokens{value: msg.value}(
        //     minAmountOut, path, address(this), deadline
        // );
        // amountOut = amounts[amounts.length - 1];

        amountOut = 0; // Placeholder

        emit TokenSwapped(s.weth, tokenOut, msg.value, amountOut, address(this));
    }

    /// @inheritdoc ISwapProtocolFacet
    function swapTokenForNative(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external onlyAdmin onlyInitialized validDeadline(deadline) nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert InvalidAmount();
        if (tokenIn == address(0)) revert InvalidAddress();

        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();

        // Check balance
        uint256 balance = IERC20(tokenIn).balanceOf(address(this));
        if (balance < amountIn) revert InsufficientBalance();

        // Approve router
        IERC20(tokenIn).forceApprove(s.router, amountIn);

        // TODO: Implement token to native swap
        // Example:
        // address[] memory path = new address[](2);
        // path[0] = tokenIn;
        // path[1] = s.weth;
        // uint[] memory amounts = IUniswapV2Router(s.router).swapExactTokensForETH(
        //     amountIn, minAmountOut, path, address(this), deadline
        // );
        // amountOut = amounts[amounts.length - 1];

        amountOut = 0; // Placeholder

        emit TokenSwapped(tokenIn, s.weth, amountIn, amountOut, address(this));
    }

    // ============ View Functions ============

    /// @inheritdoc ISwapProtocolFacet
    function getRouter() external view returns (address) {
        return SwapProtocolStorage.layout().router;
    }

    /// @inheritdoc ISwapProtocolFacet
    function isSwapProtocolInitialized() external view returns (bool) {
        return SwapProtocolStorage.layout().initialized;
    }

    /// @inheritdoc ISwapProtocolFacet
    function getExpectedOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view onlyInitialized returns (uint256 expectedOut) {
        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();

        // TODO: Implement quote using quoter
        // Example for V3:
        // return IQuoter(s.quoter).quoteExactInputSingle(
        //     tokenIn, tokenOut, defaultFee, amountIn, 0
        // );

        return 0; // Placeholder
    }

    /// @inheritdoc ISwapProtocolFacet
    function getRouteConfig(
        address tokenA,
        address tokenB
    ) external view returns (
        address[] memory path,
        uint24[] memory fees,
        bool isV3,
        uint256 maxSlippageBps
    ) {
        bytes32 key = SwapProtocolStorage.getPairKey(tokenA, tokenB);
        SwapProtocolStorage.RouteConfig storage route = SwapProtocolStorage.layout().routes[key];

        return (route.path, route.fees, route.isV3, route.maxSlippageBps);
    }

    /// @inheritdoc ISwapProtocolFacet
    function getDefaultSlippage() external view returns (uint256) {
        return SwapProtocolStorage.layout().defaultSlippageBps;
    }

    /// @inheritdoc ISwapProtocolFacet
    function isTokenApproved(address token) external view returns (bool) {
        return SwapProtocolStorage.layout().approvedTokens[token];
    }

    // ============ Internal Functions ============

    function _executeSwap(
        address[] memory path,
        uint24[] memory fees,
        bool isV3,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();

        if (isV3) {
            // TODO: Implement V3 multi-hop swap
            // Encode path: token0 + fee0 + token1 + fee1 + token2 ...
            // bytes memory encodedPath = abi.encodePacked(path[0]);
            // for (uint i = 0; i < fees.length; i++) {
            //     encodedPath = abi.encodePacked(encodedPath, fees[i], path[i + 1]);
            // }
            //
            // ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            //     path: encodedPath,
            //     recipient: address(this),
            //     deadline: deadline,
            //     amountIn: amountIn,
            //     amountOutMinimum: minAmountOut
            // });
            // amountOut = ISwapRouter(s.router).exactInput(params);
        } else {
            // TODO: Implement V2 multi-hop swap
            // uint[] memory amounts = IUniswapV2Router(s.router).swapExactTokensForTokens(
            //     amountIn, minAmountOut, path, address(this), deadline
            // );
            // amountOut = amounts[amounts.length - 1];
        }

        return amountIn; // Placeholder
    }

    function _executeDirectSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        SwapProtocolStorage.Layout storage s = SwapProtocolStorage.layout();

        // TODO: Implement single-hop swap with auto-detected fee
        // For V3, try common fee tiers (500, 3000, 10000)
        // For V2, use the single pair

        return amountIn; // Placeholder
    }
}

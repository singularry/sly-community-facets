// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISwapProtocolFacet
 * @notice Interface for DEX swap integration facet
 * @dev Covers common swap operations: exactInput, exactOutput, multi-hop
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "SwapProtocol" with your DEX name
 * 2. Add aggregator-specific functions if needed
 * 3. Adjust for V2 vs V3 style routers
 */
interface ISwapProtocolFacet {
    // ============ Events ============

    event SwapProtocolInitialized(address indexed router, address indexed weth);
    event TokenSwapped(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed recipient
    );
    event RouteConfigured(address indexed tokenA, address indexed tokenB);
    event SlippageUpdated(uint256 oldSlippage, uint256 newSlippage);

    // ============ Errors ============

    error AlreadyInitialized();
    error NotInitialized();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidPath();
    error InsufficientBalance();
    error InsufficientOutputAmount();
    error ExcessiveSlippage();
    error SwapFailed();
    error DeadlineExpired();
    error TokenNotApproved();

    // ============ Initialization ============

    /**
     * @notice Initialize the swap facet
     * @param _router Swap router address
     * @param _factory Pool factory address
     * @param _quoter Quoter address (for V3)
     * @param _weth Wrapped native token address
     * @param _defaultSlippageBps Default slippage in basis points
     */
    function initializeSwapProtocol(
        address _router,
        address _factory,
        address _quoter,
        address _weth,
        uint256 _defaultSlippageBps
    ) external;

    /**
     * @notice Configure a swap route for a token pair
     * @param tokenA First token
     * @param tokenB Second token
     * @param path Token path for multi-hop
     * @param fees Fee tiers for each hop
     * @param isV3 Whether to use V3-style routing
     * @param maxSlippageBps Maximum slippage for this route
     */
    function configureRoute(
        address tokenA,
        address tokenB,
        address[] calldata path,
        uint24[] calldata fees,
        bool isV3,
        uint256 maxSlippageBps
    ) external;

    /**
     * @notice Update default slippage tolerance
     * @param newSlippageBps New slippage in basis points
     */
    function setDefaultSlippage(uint256 newSlippageBps) external;

    /**
     * @notice Approve a token for swapping
     * @param token Token address
     */
    function approveToken(address token) external;

    // ============ Swap Operations ============

    /**
     * @notice Swap exact input for minimum output
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Exact amount to swap
     * @param minAmountOut Minimum acceptable output
     * @param deadline Transaction deadline
     * @return amountOut Actual output amount
     */
    function swapExactInput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /**
     * @notice Swap maximum input for exact output
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountOut Exact output desired
     * @param maxAmountIn Maximum input willing to spend
     * @param deadline Transaction deadline
     * @return amountIn Actual input amount
     */
    function swapExactOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        uint256 deadline
    ) external returns (uint256 amountIn);

    /**
     * @notice Swap with custom path (multi-hop)
     * @param path Token path
     * @param fees Fee tiers for each hop
     * @param amountIn Input amount
     * @param minAmountOut Minimum output
     * @param deadline Transaction deadline
     * @return amountOut Actual output
     */
    function swapExactInputMultihop(
        address[] calldata path,
        uint24[] calldata fees,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /**
     * @notice Swap native token (BNB/ETH) for token
     * @param tokenOut Output token
     * @param minAmountOut Minimum output
     * @param deadline Transaction deadline
     * @return amountOut Actual output
     */
    function swapNativeForToken(
        address tokenOut,
        uint256 minAmountOut,
        uint256 deadline
    ) external payable returns (uint256 amountOut);

    /**
     * @notice Swap token for native token (BNB/ETH)
     * @param tokenIn Input token
     * @param amountIn Input amount
     * @param minAmountOut Minimum output
     * @param deadline Transaction deadline
     * @return amountOut Actual output
     */
    function swapTokenForNative(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external returns (uint256 amountOut);

    // ============ View Functions ============

    /**
     * @notice Get the router address
     */
    function getRouter() external view returns (address);

    /**
     * @notice Check if facet is initialized
     */
    function isSwapProtocolInitialized() external view returns (bool);

    /**
     * @notice Get expected output for a swap
     * @param tokenIn Input token
     * @param tokenOut Output token
     * @param amountIn Input amount
     * @return expectedOut Expected output amount
     */
    function getExpectedOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 expectedOut);

    /**
     * @notice Get route configuration for a pair
     * @param tokenA First token
     * @param tokenB Second token
     */
    function getRouteConfig(
        address tokenA,
        address tokenB
    ) external view returns (
        address[] memory path,
        uint24[] memory fees,
        bool isV3,
        uint256 maxSlippageBps
    );

    /**
     * @notice Get default slippage
     */
    function getDefaultSlippage() external view returns (uint256);

    /**
     * @notice Check if a token is approved
     */
    function isTokenApproved(address token) external view returns (bool);
}

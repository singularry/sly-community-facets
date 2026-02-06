const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * SwapProtocolFacet Unit Tests
 */

describe("SwapProtocolFacet", function () {
    let facet;
    let owner;
    let admin;
    let mockRouter;
    let mockFactory;
    let mockQuoter;
    let mockWeth;
    let mockTokenA;
    let mockTokenB;

    const SWAP_AMOUNT = ethers.parseEther("100");
    const DEFAULT_SLIPPAGE_BPS = 100; // 1%
    const DEFAULT_DEADLINE = Math.floor(Date.now() / 1000) + 3600; // 1 hour

    beforeEach(async function () {
        [owner, admin] = await ethers.getSigners();

        // Deploy mock tokens
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        mockTokenA = await MockERC20.deploy("Token A", "TKA", 18);
        mockTokenB = await MockERC20.deploy("Token B", "TKB", 18);
        mockWeth = await MockERC20.deploy("Wrapped ETH", "WETH", 18);

        // Mock addresses for router/factory/quoter
        mockRouter = await ethers.Wallet.createRandom();
        mockFactory = await ethers.Wallet.createRandom();
        mockQuoter = await ethers.Wallet.createRandom();

        // Deploy facet
        const SwapProtocolFacet = await ethers.getContractFactory("SwapProtocolFacet");
        facet = await SwapProtocolFacet.deploy();
        await facet.waitForDeployment();

        // Fund facet with tokens
        await mockTokenA.mint(await facet.getAddress(), SWAP_AMOUNT * 10n);
    });

    describe("Initialization", function () {
        it("should initialize with valid parameters", async function () {
            await expect(facet.initializeSwapProtocol(
                mockRouter.address,
                mockFactory.address,
                mockQuoter.address,
                await mockWeth.getAddress(),
                DEFAULT_SLIPPAGE_BPS
            ))
                .to.emit(facet, "SwapProtocolInitialized")
                .withArgs(mockRouter.address, await mockWeth.getAddress());

            expect(await facet.isSwapProtocolInitialized()).to.equal(true);
            expect(await facet.getRouter()).to.equal(mockRouter.address);
            expect(await facet.getDefaultSlippage()).to.equal(DEFAULT_SLIPPAGE_BPS);
        });

        it("should revert if already initialized", async function () {
            await facet.initializeSwapProtocol(
                mockRouter.address,
                mockFactory.address,
                mockQuoter.address,
                await mockWeth.getAddress(),
                DEFAULT_SLIPPAGE_BPS
            );

            await expect(facet.initializeSwapProtocol(
                mockRouter.address,
                mockFactory.address,
                mockQuoter.address,
                await mockWeth.getAddress(),
                DEFAULT_SLIPPAGE_BPS
            ))
                .to.be.revertedWithCustomError(facet, "AlreadyInitialized");
        });

        it("should revert with zero router address", async function () {
            await expect(facet.initializeSwapProtocol(
                ethers.ZeroAddress,
                mockFactory.address,
                mockQuoter.address,
                await mockWeth.getAddress(),
                DEFAULT_SLIPPAGE_BPS
            ))
                .to.be.revertedWithCustomError(facet, "InvalidAddress");
        });

        it("should revert with excessive slippage", async function () {
            await expect(facet.initializeSwapProtocol(
                mockRouter.address,
                mockFactory.address,
                mockQuoter.address,
                await mockWeth.getAddress(),
                6000 // 60% - above max
            ))
                .to.be.revertedWithCustomError(facet, "ExcessiveSlippage");
        });
    });

    describe("Route Configuration", function () {
        beforeEach(async function () {
            await facet.initializeSwapProtocol(
                mockRouter.address,
                mockFactory.address,
                mockQuoter.address,
                await mockWeth.getAddress(),
                DEFAULT_SLIPPAGE_BPS
            );
        });

        it("should configure a direct route", async function () {
            const tokenAAddr = await mockTokenA.getAddress();
            const tokenBAddr = await mockTokenB.getAddress();

            await expect(facet.configureRoute(
                tokenAAddr,
                tokenBAddr,
                [tokenAAddr, tokenBAddr],
                [3000], // 0.3% fee
                true,   // V3 style
                200     // 2% max slippage
            ))
                .to.emit(facet, "RouteConfigured")
                .withArgs(tokenAAddr, tokenBAddr);

            const config = await facet.getRouteConfig(tokenAAddr, tokenBAddr);
            expect(config.path.length).to.equal(2);
            expect(config.fees.length).to.equal(1);
            expect(config.isV3).to.equal(true);
            expect(config.maxSlippageBps).to.equal(200);
        });

        it("should configure a multi-hop route", async function () {
            const tokenAAddr = await mockTokenA.getAddress();
            const tokenBAddr = await mockTokenB.getAddress();
            const wethAddr = await mockWeth.getAddress();

            await facet.configureRoute(
                tokenAAddr,
                tokenBAddr,
                [tokenAAddr, wethAddr, tokenBAddr],
                [3000, 500], // A->WETH 0.3%, WETH->B 0.05%
                true,
                300
            );

            const config = await facet.getRouteConfig(tokenAAddr, tokenBAddr);
            expect(config.path.length).to.equal(3);
            expect(config.fees.length).to.equal(2);
        });

        it("should revert with invalid path length", async function () {
            await expect(facet.configureRoute(
                await mockTokenA.getAddress(),
                await mockTokenB.getAddress(),
                [await mockTokenA.getAddress()], // Only 1 token
                [],
                true,
                200
            ))
                .to.be.revertedWithCustomError(facet, "InvalidPath");
        });

        it("should revert with mismatched fees for V3", async function () {
            await expect(facet.configureRoute(
                await mockTokenA.getAddress(),
                await mockTokenB.getAddress(),
                [await mockTokenA.getAddress(), await mockTokenB.getAddress()],
                [3000, 500], // 2 fees for 2-token path (should be 1)
                true,
                200
            ))
                .to.be.revertedWithCustomError(facet, "InvalidPath");
        });
    });

    describe("Slippage Management", function () {
        beforeEach(async function () {
            await facet.initializeSwapProtocol(
                mockRouter.address,
                mockFactory.address,
                mockQuoter.address,
                await mockWeth.getAddress(),
                DEFAULT_SLIPPAGE_BPS
            );
        });

        it("should update default slippage", async function () {
            await expect(facet.setDefaultSlippage(200))
                .to.emit(facet, "SlippageUpdated")
                .withArgs(DEFAULT_SLIPPAGE_BPS, 200);

            expect(await facet.getDefaultSlippage()).to.equal(200);
        });

        it("should revert with excessive slippage", async function () {
            await expect(facet.setDefaultSlippage(5100))
                .to.be.revertedWithCustomError(facet, "ExcessiveSlippage");
        });
    });

    describe("Swap Operations", function () {
        beforeEach(async function () {
            await facet.initializeSwapProtocol(
                mockRouter.address,
                mockFactory.address,
                mockQuoter.address,
                await mockWeth.getAddress(),
                DEFAULT_SLIPPAGE_BPS
            );
        });

        describe("swapExactInput", function () {
            it("should revert with zero amount", async function () {
                await expect(facet.swapExactInput(
                    await mockTokenA.getAddress(),
                    await mockTokenB.getAddress(),
                    0,
                    0,
                    DEFAULT_DEADLINE
                ))
                    .to.be.revertedWithCustomError(facet, "InvalidAmount");
            });

            it("should revert with zero token address", async function () {
                await expect(facet.swapExactInput(
                    ethers.ZeroAddress,
                    await mockTokenB.getAddress(),
                    SWAP_AMOUNT,
                    0,
                    DEFAULT_DEADLINE
                ))
                    .to.be.revertedWithCustomError(facet, "InvalidAddress");
            });

            it("should revert with expired deadline", async function () {
                const expiredDeadline = Math.floor(Date.now() / 1000) - 3600;

                await expect(facet.swapExactInput(
                    await mockTokenA.getAddress(),
                    await mockTokenB.getAddress(),
                    SWAP_AMOUNT,
                    0,
                    expiredDeadline
                ))
                    .to.be.revertedWithCustomError(facet, "DeadlineExpired");
            });

            it("should revert with insufficient balance", async function () {
                await expect(facet.swapExactInput(
                    await mockTokenA.getAddress(),
                    await mockTokenB.getAddress(),
                    SWAP_AMOUNT * 100n, // More than balance
                    0,
                    DEFAULT_DEADLINE
                ))
                    .to.be.revertedWithCustomError(facet, "InsufficientBalance");
            });
        });

        describe("swapExactInputMultihop", function () {
            it("should revert with invalid path", async function () {
                await expect(facet.swapExactInputMultihop(
                    [await mockTokenA.getAddress()], // Only 1 token
                    [],
                    SWAP_AMOUNT,
                    0,
                    DEFAULT_DEADLINE
                ))
                    .to.be.revertedWithCustomError(facet, "InvalidPath");
            });
        });
    });

    describe("Token Approval", function () {
        beforeEach(async function () {
            await facet.initializeSwapProtocol(
                mockRouter.address,
                mockFactory.address,
                mockQuoter.address,
                await mockWeth.getAddress(),
                DEFAULT_SLIPPAGE_BPS
            );
        });

        it("should approve a token", async function () {
            const tokenAddr = await mockTokenA.getAddress();

            expect(await facet.isTokenApproved(tokenAddr)).to.equal(false);
            await facet.approveToken(tokenAddr);
            expect(await facet.isTokenApproved(tokenAddr)).to.equal(true);
        });

        it("should revert with zero address", async function () {
            await expect(facet.approveToken(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(facet, "InvalidAddress");
        });
    });

    describe("Uninitialized Guards", function () {
        it("should revert configureRoute if not initialized", async function () {
            await expect(facet.configureRoute(
                await mockTokenA.getAddress(),
                await mockTokenB.getAddress(),
                [await mockTokenA.getAddress(), await mockTokenB.getAddress()],
                [3000],
                true,
                200
            ))
                .to.be.revertedWithCustomError(facet, "NotInitialized");
        });

        it("should revert swapExactInput if not initialized", async function () {
            await expect(facet.swapExactInput(
                await mockTokenA.getAddress(),
                await mockTokenB.getAddress(),
                SWAP_AMOUNT,
                0,
                DEFAULT_DEADLINE
            ))
                .to.be.revertedWithCustomError(facet, "NotInitialized");
        });
    });
});

/**
 * E2E FORK TEST EXAMPLE
 *
 * describe("SwapProtocolFacet E2E (PancakeSwap)", function () {
 *     const PANCAKE_ROUTER_V3 = "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4";
 *     const PANCAKE_FACTORY = "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865";
 *     const PANCAKE_QUOTER = "0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997";
 *     const WBNB = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
 *     const USDT = "0x55d398326f99059fF775485246999027B3197955";
 *
 *     it("should swap WBNB for USDT", async function () {
 *         // Fork BSC
 *         // Initialize with PancakeSwap addresses
 *         // Execute swap
 *         // Verify output
 *     });
 * });
 */

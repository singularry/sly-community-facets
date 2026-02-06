const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * LendingProtocolFacet Unit Tests
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "LendingProtocol" with your protocol name
 * 2. Mock the lending pool and oracle contracts
 * 3. Add protocol-specific test scenarios
 * 4. Create E2E tests for mainnet fork testing
 */

describe("LendingProtocolFacet", function () {
    let facet;
    let owner;
    let admin;
    let user;
    let mockLendingPool;
    let mockOracle;
    let mockToken;
    let mockLendingToken;

    // Test constants
    const SUPPLY_AMOUNT = ethers.parseEther("1000");
    const BORROW_AMOUNT = ethers.parseEther("500");
    const MIN_HEALTH_FACTOR_BPS = 12000; // 1.2
    const COLLATERAL_FACTOR_BPS = 8000; // 80%

    beforeEach(async function () {
        [owner, admin, user] = await ethers.getSigners();

        // Deploy mock tokens
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        mockToken = await MockERC20.deploy("Mock USDT", "USDT", 18);
        mockLendingToken = await MockERC20.deploy("Mock vUSDT", "vUSDT", 8);
        await mockToken.waitForDeployment();
        await mockLendingToken.waitForDeployment();

        // Mock lending pool and oracle (use random addresses for unit tests)
        mockLendingPool = await ethers.Wallet.createRandom();
        mockOracle = await ethers.Wallet.createRandom();

        // Deploy the facet
        const LendingProtocolFacet = await ethers.getContractFactory("LendingProtocolFacet");
        facet = await LendingProtocolFacet.deploy();
        await facet.waitForDeployment();

        // Fund the facet with tokens
        await mockToken.mint(await facet.getAddress(), SUPPLY_AMOUNT);
    });

    describe("Initialization", function () {
        it("should initialize with valid parameters", async function () {
            await expect(facet.initializeLendingProtocol(
                mockLendingPool.address,
                mockOracle.address,
                MIN_HEALTH_FACTOR_BPS
            ))
                .to.emit(facet, "LendingProtocolInitialized")
                .withArgs(mockLendingPool.address, mockOracle.address);

            expect(await facet.isLendingProtocolInitialized()).to.equal(true);
            expect(await facet.getLendingPool()).to.equal(mockLendingPool.address);
        });

        it("should revert if already initialized", async function () {
            await facet.initializeLendingProtocol(
                mockLendingPool.address,
                mockOracle.address,
                MIN_HEALTH_FACTOR_BPS
            );

            await expect(facet.initializeLendingProtocol(
                mockLendingPool.address,
                mockOracle.address,
                MIN_HEALTH_FACTOR_BPS
            ))
                .to.be.revertedWithCustomError(facet, "AlreadyInitialized");
        });

        it("should revert with zero lending pool address", async function () {
            await expect(facet.initializeLendingProtocol(
                ethers.ZeroAddress,
                mockOracle.address,
                MIN_HEALTH_FACTOR_BPS
            ))
                .to.be.revertedWithCustomError(facet, "InvalidAddress");
        });

        it("should revert with zero oracle address", async function () {
            await expect(facet.initializeLendingProtocol(
                mockLendingPool.address,
                ethers.ZeroAddress,
                MIN_HEALTH_FACTOR_BPS
            ))
                .to.be.revertedWithCustomError(facet, "InvalidAddress");
        });
    });

    describe("Market Configuration", function () {
        beforeEach(async function () {
            await facet.initializeLendingProtocol(
                mockLendingPool.address,
                mockOracle.address,
                MIN_HEALTH_FACTOR_BPS
            );
        });

        it("should configure a market", async function () {
            const underlying = await mockToken.getAddress();
            const lendingToken = await mockLendingToken.getAddress();

            await expect(facet.configureMarket(
                underlying,
                lendingToken,
                COLLATERAL_FACTOR_BPS,
                true,  // isCollateral
                true   // isBorrowable
            ))
                .to.emit(facet, "MarketConfigured")
                .withArgs(underlying, lendingToken, COLLATERAL_FACTOR_BPS);

            const config = await facet.getMarketConfig(underlying);
            expect(config.lendingToken).to.equal(lendingToken);
            expect(config.collateralFactorBps).to.equal(COLLATERAL_FACTOR_BPS);
            expect(config.isCollateral).to.equal(true);
            expect(config.isBorrowable).to.equal(true);
        });

        it("should add market to supported list", async function () {
            await facet.configureMarket(
                await mockToken.getAddress(),
                await mockLendingToken.getAddress(),
                COLLATERAL_FACTOR_BPS,
                true,
                true
            );

            const markets = await facet.getSupportedMarkets();
            expect(markets.length).to.equal(1);
            expect(markets[0]).to.equal(await mockToken.getAddress());
        });

        it("should revert with zero underlying address", async function () {
            await expect(facet.configureMarket(
                ethers.ZeroAddress,
                await mockLendingToken.getAddress(),
                COLLATERAL_FACTOR_BPS,
                true,
                true
            ))
                .to.be.revertedWithCustomError(facet, "InvalidAddress");
        });
    });

    describe("Supply Operations", function () {
        beforeEach(async function () {
            await facet.initializeLendingProtocol(
                mockLendingPool.address,
                mockOracle.address,
                MIN_HEALTH_FACTOR_BPS
            );

            await facet.configureMarket(
                await mockToken.getAddress(),
                await mockLendingToken.getAddress(),
                COLLATERAL_FACTOR_BPS,
                true,
                true
            );
        });

        it("should emit Supplied event", async function () {
            // Note: This test verifies the event is emitted
            // Actual supply would require mocked lending pool
            await expect(facet.lendingSupply(await mockToken.getAddress(), SUPPLY_AMOUNT))
                .to.emit(facet, "Supplied");
        });

        it("should revert with zero amount", async function () {
            await expect(facet.lendingSupply(await mockToken.getAddress(), 0))
                .to.be.revertedWithCustomError(facet, "InvalidAmount");
        });

        it("should revert with unsupported market", async function () {
            const randomToken = await ethers.Wallet.createRandom();

            await expect(facet.lendingSupply(randomToken.address, SUPPLY_AMOUNT))
                .to.be.revertedWithCustomError(facet, "MarketNotSupported");
        });

        it("should revert with insufficient balance", async function () {
            const excessAmount = SUPPLY_AMOUNT * 2n;

            await expect(facet.lendingSupply(await mockToken.getAddress(), excessAmount))
                .to.be.revertedWithCustomError(facet, "InsufficientBalance");
        });
    });

    describe("Borrow Operations", function () {
        beforeEach(async function () {
            await facet.initializeLendingProtocol(
                mockLendingPool.address,
                mockOracle.address,
                MIN_HEALTH_FACTOR_BPS
            );

            await facet.configureMarket(
                await mockToken.getAddress(),
                await mockLendingToken.getAddress(),
                COLLATERAL_FACTOR_BPS,
                true,
                true
            );
        });

        it("should revert with zero amount", async function () {
            await expect(facet.lendingBorrow(await mockToken.getAddress(), 0))
                .to.be.revertedWithCustomError(facet, "InvalidAmount");
        });

        it("should revert if market not borrowable", async function () {
            // Configure a non-borrowable market
            const MockERC20 = await ethers.getContractFactory("MockERC20");
            const nonBorrowable = await MockERC20.deploy("NB", "NB", 18);
            const nbLending = await MockERC20.deploy("vNB", "vNB", 8);

            await facet.configureMarket(
                await nonBorrowable.getAddress(),
                await nbLending.getAddress(),
                COLLATERAL_FACTOR_BPS,
                true,
                false  // Not borrowable
            );

            await expect(facet.lendingBorrow(await nonBorrowable.getAddress(), BORROW_AMOUNT))
                .to.be.revertedWithCustomError(facet, "MarketNotSupported");
        });
    });

    describe("View Functions", function () {
        it("should return false for uninitialized facet", async function () {
            expect(await facet.isLendingProtocolInitialized()).to.equal(false);
        });

        it("should return empty markets for uninitialized facet", async function () {
            await facet.initializeLendingProtocol(
                mockLendingPool.address,
                mockOracle.address,
                MIN_HEALTH_FACTOR_BPS
            );

            const markets = await facet.getSupportedMarkets();
            expect(markets.length).to.equal(0);
        });

        it("should return max health factor when no borrows", async function () {
            await facet.initializeLendingProtocol(
                mockLendingPool.address,
                mockOracle.address,
                MIN_HEALTH_FACTOR_BPS
            );

            const healthFactor = await facet.getHealthFactor();
            expect(healthFactor).to.equal(ethers.MaxUint256);
        });
    });

    describe("Uninitialized Guards", function () {
        it("should revert configureMarket if not initialized", async function () {
            await expect(facet.configureMarket(
                await mockToken.getAddress(),
                await mockLendingToken.getAddress(),
                COLLATERAL_FACTOR_BPS,
                true,
                true
            ))
                .to.be.revertedWithCustomError(facet, "NotInitialized");
        });

        it("should revert lendingSupply if not initialized", async function () {
            await expect(facet.lendingSupply(await mockToken.getAddress(), SUPPLY_AMOUNT))
                .to.be.revertedWithCustomError(facet, "NotInitialized");
        });

        it("should revert getHealthFactor if not initialized", async function () {
            await expect(facet.getHealthFactor())
                .to.be.revertedWithCustomError(facet, "NotInitialized");
        });
    });
});

/**
 * E2E FORK TEST EXAMPLE
 *
 * describe("LendingProtocolFacet E2E (Venus)", function () {
 *     const VENUS_COMPTROLLER = "0xfD36E2c2a6789Db23113685031d7F16329158384";
 *     const VENUS_ORACLE = "0xd8B6dA2bfEC71D684D3E2a2FC9492dDad5C3787F";
 *     const USDT = "0x55d398326f99059fF775485246999027B3197955";
 *     const vUSDT = "0xfD5840Cd36d94D7229439859C0112a4185BC0255";
 *
 *     before(async function () {
 *         await network.provider.request({
 *             method: "hardhat_reset",
 *             params: [{
 *                 forking: {
 *                     jsonRpcUrl: "https://bsc-mainnet.archive.node",
 *                     blockNumber: 79440000
 *                 }
 *             }]
 *         });
 *     });
 *
 *     it("should supply USDT to Venus", async function () {
 *         // Setup wallet, attach facet, initialize
 *         // Supply USDT and verify vUSDT received
 *     });
 *
 *     it("should maintain health factor above minimum", async function () {
 *         // Supply collateral, borrow, verify health factor
 *     });
 * });
 */

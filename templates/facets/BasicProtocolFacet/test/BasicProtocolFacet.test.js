const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * BasicProtocolFacet Unit Tests
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "BasicProtocol" with your protocol name
 * 2. Add protocol-specific test cases
 * 3. Mock external protocol contracts for unit tests
 * 4. Create separate E2E test file for mainnet fork tests
 *
 * TEST STRUCTURE:
 * - Use describe blocks to group related tests
 * - Each test should be independent (use beforeEach for setup)
 * - Test both success and failure cases
 * - Test access control for all admin functions
 */

describe("BasicProtocolFacet", function () {
    let diamond;
    let facet;
    let owner;
    let admin;
    let user;
    let mockProtocol;
    let mockToken;

    // Test constants
    const DEPOSIT_AMOUNT = ethers.parseEther("100");

    beforeEach(async function () {
        [owner, admin, user] = await ethers.getSigners();

        // Deploy mock token for testing
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        mockToken = await MockERC20.deploy("Mock Token", "MOCK", 18);
        await mockToken.waitForDeployment();

        // Deploy mock protocol (replace with your protocol mock)
        // For this template, we'll use a simple address
        mockProtocol = await ethers.Wallet.createRandom();

        // TODO: Deploy your diamond setup
        // This depends on your testing infrastructure
        // Example:
        // const Diamond = await ethers.getContractFactory("SLYWallet");
        // diamond = await Diamond.deploy(owner.address);
        // await diamond.waitForDeployment();

        // Deploy the facet
        const BasicProtocolFacet = await ethers.getContractFactory("BasicProtocolFacet");
        const facetContract = await BasicProtocolFacet.deploy();
        await facetContract.waitForDeployment();

        // TODO: Attach facet to diamond via diamondCut
        // For now, we test the facet directly
        facet = facetContract;

        // Mint test tokens to the facet/wallet
        await mockToken.mint(await facet.getAddress(), DEPOSIT_AMOUNT);
    });

    describe("Initialization", function () {
        it("should initialize with valid protocol address", async function () {
            // TODO: Connect as owner through diamond
            // For direct testing:
            await expect(facet.initializeBasicProtocol(mockProtocol.address))
                .to.emit(facet, "BasicProtocolInitialized")
                .withArgs(mockProtocol.address);

            expect(await facet.isBasicProtocolInitialized()).to.equal(true);
            expect(await facet.getProtocolAddress()).to.equal(mockProtocol.address);
        });

        it("should revert if already initialized", async function () {
            await facet.initializeBasicProtocol(mockProtocol.address);

            await expect(facet.initializeBasicProtocol(mockProtocol.address))
                .to.be.revertedWithCustomError(facet, "AlreadyInitialized");
        });

        it("should revert with zero address", async function () {
            await expect(facet.initializeBasicProtocol(ethers.ZeroAddress))
                .to.be.revertedWithCustomError(facet, "InvalidAddress");
        });
    });

    describe("Access Control", function () {
        beforeEach(async function () {
            await facet.initializeBasicProtocol(mockProtocol.address);
        });

        it("should allow admin to update protocol address", async function () {
            const newAddress = await ethers.Wallet.createRandom();

            await expect(facet.setProtocolAddress(newAddress.address))
                .to.emit(facet, "ProtocolAddressUpdated")
                .withArgs(mockProtocol.address, newAddress.address);
        });

        // TODO: Add tests for non-admin rejection when diamond is integrated
        // it("should reject non-admin calls", async function () {
        //     await expect(facet.connect(user).setProtocolAddress(user.address))
        //         .to.be.revertedWith("caller is not admin or owner");
        // });
    });

    describe("Core Operations", function () {
        beforeEach(async function () {
            await facet.initializeBasicProtocol(mockProtocol.address);
        });

        describe("protocolDeposit", function () {
            it("should deposit tokens successfully", async function () {
                const tokenAddress = await mockToken.getAddress();

                await expect(facet.protocolDeposit(tokenAddress, DEPOSIT_AMOUNT))
                    .to.emit(facet, "Deposited")
                    .withArgs(tokenAddress, DEPOSIT_AMOUNT);

                // Verify token transferred to protocol
                expect(await mockToken.balanceOf(mockProtocol.address))
                    .to.equal(DEPOSIT_AMOUNT);
            });

            it("should revert with zero amount", async function () {
                await expect(facet.protocolDeposit(await mockToken.getAddress(), 0))
                    .to.be.revertedWithCustomError(facet, "InvalidAmount");
            });

            it("should revert with zero token address", async function () {
                await expect(facet.protocolDeposit(ethers.ZeroAddress, DEPOSIT_AMOUNT))
                    .to.be.revertedWithCustomError(facet, "InvalidAddress");
            });

            it("should revert with insufficient balance", async function () {
                const excessAmount = DEPOSIT_AMOUNT * 2n;

                await expect(facet.protocolDeposit(await mockToken.getAddress(), excessAmount))
                    .to.be.revertedWithCustomError(facet, "InsufficientBalance");
            });
        });

        describe("protocolWithdraw", function () {
            it("should emit Withdrawn event", async function () {
                const tokenAddress = await mockToken.getAddress();

                await expect(facet.protocolWithdraw(tokenAddress, DEPOSIT_AMOUNT))
                    .to.emit(facet, "Withdrawn")
                    .withArgs(tokenAddress, DEPOSIT_AMOUNT);
            });

            it("should revert with zero amount", async function () {
                await expect(facet.protocolWithdraw(await mockToken.getAddress(), 0))
                    .to.be.revertedWithCustomError(facet, "InvalidAmount");
            });
        });
    });

    describe("View Functions", function () {
        it("should return false for uninitialized facet", async function () {
            expect(await facet.isBasicProtocolInitialized()).to.equal(false);
        });

        it("should return correct protocol address after init", async function () {
            await facet.initializeBasicProtocol(mockProtocol.address);
            expect(await facet.getProtocolAddress()).to.equal(mockProtocol.address);
        });
    });

    describe("Uninitialized Guards", function () {
        it("should revert setProtocolAddress if not initialized", async function () {
            await expect(facet.setProtocolAddress(mockProtocol.address))
                .to.be.revertedWithCustomError(facet, "NotInitialized");
        });

        it("should revert protocolDeposit if not initialized", async function () {
            await expect(facet.protocolDeposit(await mockToken.getAddress(), DEPOSIT_AMOUNT))
                .to.be.revertedWithCustomError(facet, "NotInitialized");
        });

        it("should revert getProtocolBalance if not initialized", async function () {
            await expect(facet.getProtocolBalance())
                .to.be.revertedWithCustomError(facet, "NotInitialized");
        });
    });
});

/**
 * E2E MAINNET FORK TESTS
 *
 * Create a separate file (BasicProtocolE2E.test.js) for mainnet fork tests.
 * Example structure:
 *
 * describe("BasicProtocolFacet E2E", function () {
 *     before(async function () {
 *         // Fork mainnet at specific block
 *         await network.provider.request({
 *             method: "hardhat_reset",
 *             params: [{
 *                 forking: {
 *                     jsonRpcUrl: "https://bsc-mainnet.archive.node",
 *                     blockNumber: 79440000
 *                 }
 *             }]
 *         });
 *
 *         // Setup real protocol addresses
 *         // Impersonate whale accounts for tokens
 *         // Deploy and attach facet to real wallet
 *     });
 *
 *     it("should integrate with real protocol", async function () {
 *         // Test actual protocol interactions
 *     });
 * });
 */

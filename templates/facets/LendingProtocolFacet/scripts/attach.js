const { ethers } = require("hardhat");
const { PROTOCOL_ADDRESSES } = require("./deploy");

/**
 * Attach LendingProtocolFacet to SLYWallet and Initialize Markets
 */

const CONFIG = {
    FACET_ADDRESS: "0x0000000000000000000000000000000000000000",
    WALLET_ADDRESS: "0x0000000000000000000000000000000000000000",
};

const FacetCutAction = { Add: 0, Replace: 1, Remove: 2 };

async function main() {
    const [signer] = await ethers.getSigners();
    const network = await ethers.provider.getNetwork();
    const networkName = network.name === "unknown" ? "hardhat" : network.name;

    console.log("=".repeat(60));
    console.log("Attaching LendingProtocolFacet to SLYWallet");
    console.log("=".repeat(60));

    // Validate configuration
    if (CONFIG.FACET_ADDRESS === ethers.ZeroAddress) {
        throw new Error("FACET_ADDRESS not configured");
    }

    const addresses = PROTOCOL_ADDRESSES[networkName];
    const facet = await ethers.getContractAt("LendingProtocolFacet", CONFIG.FACET_ADDRESS);

    // Extract selectors
    const selectors = [];
    for (const f of facet.interface.fragments) {
        if (f.type === "function") {
            selectors.push(facet.interface.getFunction(f.name).selector);
        }
    }

    // Encode initialization
    const initData = facet.interface.encodeFunctionData("initializeLendingProtocol", [
        addresses.lendingPool,
        addresses.oracle,
        addresses.minHealthFactorBps
    ]);

    // Execute diamond cut
    const diamondCut = await ethers.getContractAt("IDiamondCut", CONFIG.WALLET_ADDRESS);
    console.log("\nExecuting diamondCut...");

    const tx = await diamondCut.diamondCut(
        [{
            facetAddress: CONFIG.FACET_ADDRESS,
            action: FacetCutAction.Add,
            functionSelectors: selectors
        }],
        CONFIG.FACET_ADDRESS,
        initData
    );

    await tx.wait();
    console.log("Facet attached and initialized!");

    // Configure markets
    const walletFacet = await ethers.getContractAt("ILendingProtocolFacet", CONFIG.WALLET_ADDRESS);

    if (addresses.markets.length > 0) {
        console.log("\nConfiguring markets...");
        for (const market of addresses.markets) {
            console.log(`  - ${market.underlying}`);
            const configTx = await walletFacet.configureMarket(
                market.underlying,
                market.lendingToken,
                market.collateralFactorBps,
                market.isCollateral,
                market.isBorrowable
            );
            await configTx.wait();
        }
        console.log(`Configured ${addresses.markets.length} markets`);
    }

    // Verify
    console.log("\nVerification:");
    console.log(`- Initialized: ${await walletFacet.isLendingProtocolInitialized()}`);
    console.log(`- Lending Pool: ${await walletFacet.getLendingPool()}`);
    console.log(`- Markets: ${(await walletFacet.getSupportedMarkets()).length}`);

    console.log("\n" + "=".repeat(60));
    console.log("SUCCESS: Lending facet ready!");
    console.log("=".repeat(60));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

const { ethers } = require("hardhat");
const { DEX_ADDRESSES } = require("./deploy");

/**
 * Attach SwapProtocolFacet to SLYWallet and Configure Routes
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
    console.log("Attaching SwapProtocolFacet to SLYWallet");
    console.log("=".repeat(60));

    if (CONFIG.FACET_ADDRESS === ethers.ZeroAddress) {
        throw new Error("FACET_ADDRESS not configured");
    }

    const addresses = DEX_ADDRESSES[networkName];
    const facet = await ethers.getContractAt("SwapProtocolFacet", CONFIG.FACET_ADDRESS);

    // Extract selectors
    const selectors = [];
    for (const f of facet.interface.fragments) {
        if (f.type === "function") {
            selectors.push(facet.interface.getFunction(f.name).selector);
        }
    }

    // Encode initialization
    const initData = facet.interface.encodeFunctionData("initializeSwapProtocol", [
        addresses.router,
        addresses.factory,
        addresses.quoter,
        addresses.weth,
        addresses.defaultSlippageBps
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

    // Configure routes
    const walletFacet = await ethers.getContractAt("ISwapProtocolFacet", CONFIG.WALLET_ADDRESS);

    if (addresses.routes.length > 0) {
        console.log("\nConfiguring routes...");
        for (const route of addresses.routes) {
            console.log(`  - ${route.tokenA} <-> ${route.tokenB}`);
            const routeTx = await walletFacet.configureRoute(
                route.tokenA,
                route.tokenB,
                route.path,
                route.fees,
                route.isV3,
                route.maxSlippageBps
            );
            await routeTx.wait();
        }
        console.log(`Configured ${addresses.routes.length} routes`);
    }

    // Verify
    console.log("\nVerification:");
    console.log(`- Initialized: ${await walletFacet.isSwapProtocolInitialized()}`);
    console.log(`- Router: ${await walletFacet.getRouter()}`);
    console.log(`- Default Slippage: ${await walletFacet.getDefaultSlippage()} bps`);

    console.log("\n" + "=".repeat(60));
    console.log("SUCCESS: Swap facet ready!");
    console.log("=".repeat(60));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

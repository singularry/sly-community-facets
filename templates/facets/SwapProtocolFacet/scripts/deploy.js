const { ethers } = require("hardhat");

/**
 * SwapProtocolFacet Deployment Script
 */

const DEX_ADDRESSES = {
    bsc: {
        // PancakeSwap V3
        router: "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4",
        factory: "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865",
        quoter: "0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997",
        weth: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // WBNB
        defaultSlippageBps: 100, // 1%

        // Common routes to pre-configure
        routes: [
            {
                tokenA: "0x55d398326f99059fF775485246999027B3197955", // USDT
                tokenB: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // WBNB
                path: [
                    "0x55d398326f99059fF775485246999027B3197955",
                    "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
                ],
                fees: [500], // 0.05%
                isV3: true,
                maxSlippageBps: 100
            }
        ]
    },
    bscTestnet: {
        router: "0x0000000000000000000000000000000000000000",
        factory: "0x0000000000000000000000000000000000000000",
        quoter: "0x0000000000000000000000000000000000000000",
        weth: "0x0000000000000000000000000000000000000000",
        defaultSlippageBps: 100,
        routes: []
    },
    hardhat: {
        router: "0x0000000000000000000000000000000000000000",
        factory: "0x0000000000000000000000000000000000000000",
        quoter: "0x0000000000000000000000000000000000000000",
        weth: "0x0000000000000000000000000000000000000000",
        defaultSlippageBps: 100,
        routes: []
    }
};

async function main() {
    const [deployer] = await ethers.getSigners();
    const network = await ethers.provider.getNetwork();
    const networkName = network.name === "unknown" ? "hardhat" : network.name;

    console.log("=".repeat(60));
    console.log("SwapProtocolFacet Deployment");
    console.log("=".repeat(60));
    console.log(`Network: ${networkName}`);
    console.log(`Deployer: ${deployer.address}`);
    console.log("");

    const addresses = DEX_ADDRESSES[networkName];
    if (!addresses) {
        throw new Error(`No addresses for network: ${networkName}`);
    }

    // Deploy facet
    console.log("Deploying SwapProtocolFacet...");
    const SwapProtocolFacet = await ethers.getContractFactory("SwapProtocolFacet");
    const facet = await SwapProtocolFacet.deploy();
    await facet.waitForDeployment();

    const facetAddress = await facet.getAddress();
    console.log(`SwapProtocolFacet deployed to: ${facetAddress}`);

    // Get selectors
    const selectors = [];
    for (const f of facet.interface.fragments) {
        if (f.type === "function") {
            selectors.push({
                name: f.name,
                selector: facet.interface.getFunction(f.name).selector
            });
        }
    }

    console.log("\n" + "=".repeat(60));
    console.log("DEPLOYMENT SUMMARY");
    console.log("=".repeat(60));
    console.log(`Facet Address: ${facetAddress}`);
    console.log(`Router: ${addresses.router}`);
    console.log(`Factory: ${addresses.factory}`);
    console.log(`Quoter: ${addresses.quoter}`);
    console.log(`WETH/WBNB: ${addresses.weth}`);
    console.log(`Pre-configured Routes: ${addresses.routes.length}`);
    console.log(`Function Selectors: ${selectors.length}`);
    console.log("=".repeat(60));

    return { facetAddress, selectors, ...addresses };
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

module.exports = { main, DEX_ADDRESSES };

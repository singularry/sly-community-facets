const { ethers } = require("hardhat");

/**
 * LendingProtocolFacet Deployment Script
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "LendingProtocol" with your protocol name
 * 2. Update addresses for your target lending protocol
 * 3. Configure markets after deployment
 */

// Protocol addresses per network
const PROTOCOL_ADDRESSES = {
    bsc: {
        // Example: Venus Protocol on BSC
        lendingPool: "0xfD36E2c2a6789Db23113685031d7F16329158384", // Comptroller
        oracle: "0xd8B6dA2bfEC71D684D3E2a2FC9492dDad5C3787F",     // Venus Oracle
        minHealthFactorBps: 12000, // 1.2

        // Common markets to configure
        markets: [
            {
                underlying: "0x55d398326f99059fF775485246999027B3197955", // USDT
                lendingToken: "0xfD5840Cd36d94D7229439859C0112a4185BC0255", // vUSDT
                collateralFactorBps: 8000,
                isCollateral: true,
                isBorrowable: true
            },
            {
                underlying: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // WBNB
                lendingToken: "0xA07c5b74C9B40447a954e1466938b865b6BBea36", // vBNB
                collateralFactorBps: 6000,
                isCollateral: true,
                isBorrowable: true
            }
        ]
    },
    bscTestnet: {
        lendingPool: "0x0000000000000000000000000000000000000000",
        oracle: "0x0000000000000000000000000000000000000000",
        minHealthFactorBps: 12000,
        markets: []
    },
    hardhat: {
        lendingPool: "0x0000000000000000000000000000000000000000",
        oracle: "0x0000000000000000000000000000000000000000",
        minHealthFactorBps: 12000,
        markets: []
    }
};

async function main() {
    const [deployer] = await ethers.getSigners();
    const network = await ethers.provider.getNetwork();
    const networkName = network.name === "unknown" ? "hardhat" : network.name;

    console.log("=".repeat(60));
    console.log("LendingProtocolFacet Deployment");
    console.log("=".repeat(60));
    console.log(`Network: ${networkName} (chainId: ${network.chainId})`);
    console.log(`Deployer: ${deployer.address}`);
    console.log("");

    const addresses = PROTOCOL_ADDRESSES[networkName];
    if (!addresses) {
        throw new Error(`No addresses configured for network: ${networkName}`);
    }

    // Deploy the facet
    console.log("Deploying LendingProtocolFacet...");
    const LendingProtocolFacet = await ethers.getContractFactory("LendingProtocolFacet");
    const facet = await LendingProtocolFacet.deploy();
    await facet.waitForDeployment();

    const facetAddress = await facet.getAddress();
    console.log(`LendingProtocolFacet deployed to: ${facetAddress}`);

    // Get function selectors
    const selectors = getSelectors(facet);
    console.log(`\nFunction selectors: ${selectors.length} functions`);

    // Output deployment summary
    console.log("\n" + "=".repeat(60));
    console.log("DEPLOYMENT SUMMARY");
    console.log("=".repeat(60));
    console.log(`Facet Address: ${facetAddress}`);
    console.log(`Lending Pool: ${addresses.lendingPool}`);
    console.log(`Oracle: ${addresses.oracle}`);
    console.log(`Min Health Factor: ${addresses.minHealthFactorBps / 10000}`);
    console.log(`Pre-configured Markets: ${addresses.markets.length}`);
    console.log("");
    console.log("Next steps:");
    console.log("1. Verify contract on explorer");
    console.log("2. Run attach.js to add facet to wallet");
    console.log("3. Configure additional markets as needed");
    console.log("=".repeat(60));

    return {
        facetAddress,
        selectors,
        ...addresses
    };
}

function getSelectors(contract) {
    const selectors = [];
    for (const f of contract.interface.fragments) {
        if (f.type === "function") {
            selectors.push({
                name: f.name,
                selector: contract.interface.getFunction(f.name).selector
            });
        }
    }
    return selectors;
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

module.exports = { main, getSelectors, PROTOCOL_ADDRESSES };

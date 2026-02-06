const { ethers } = require("hardhat");

/**
 * BasicProtocolFacet Deployment Script
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "BasicProtocol" with your protocol name
 * 2. Update the protocol address for your target network
 * 3. Add any additional deployment parameters
 *
 * USAGE:
 * npx hardhat run scripts/deploy.js --network bsc
 * npx hardhat run scripts/deploy.js --network bscTestnet
 */

// Protocol addresses per network
const PROTOCOL_ADDRESSES = {
    bsc: {
        // Replace with actual mainnet protocol address
        protocolAddress: "0x0000000000000000000000000000000000000000",
    },
    bscTestnet: {
        // Replace with testnet protocol address
        protocolAddress: "0x0000000000000000000000000000000000000000",
    },
    hardhat: {
        // Local testing - will be overridden by mock
        protocolAddress: "0x0000000000000000000000000000000000000000",
    },
};

async function main() {
    const [deployer] = await ethers.getSigners();
    const network = await ethers.provider.getNetwork();
    const networkName = network.name === "unknown" ? "hardhat" : network.name;

    console.log("=".repeat(60));
    console.log("BasicProtocolFacet Deployment");
    console.log("=".repeat(60));
    console.log(`Network: ${networkName} (chainId: ${network.chainId})`);
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
    console.log("");

    // Get network-specific addresses
    const addresses = PROTOCOL_ADDRESSES[networkName];
    if (!addresses) {
        throw new Error(`No addresses configured for network: ${networkName}`);
    }

    // Deploy the facet
    console.log("Deploying BasicProtocolFacet...");
    const BasicProtocolFacet = await ethers.getContractFactory("BasicProtocolFacet");
    const facet = await BasicProtocolFacet.deploy();
    await facet.waitForDeployment();

    const facetAddress = await facet.getAddress();
    console.log(`BasicProtocolFacet deployed to: ${facetAddress}`);

    // Get function selectors for diamond cut
    const selectors = getSelectors(facet);
    console.log("\nFunction selectors for diamondCut:");
    console.log(JSON.stringify(selectors, null, 2));

    // Output deployment info
    console.log("\n" + "=".repeat(60));
    console.log("DEPLOYMENT SUMMARY");
    console.log("=".repeat(60));
    console.log(`Facet Address: ${facetAddress}`);
    console.log(`Protocol Address: ${addresses.protocolAddress}`);
    console.log(`Selectors Count: ${selectors.length}`);
    console.log("");
    console.log("Next steps:");
    console.log("1. Verify contract on explorer");
    console.log("2. Run attach.js to add facet to wallet diamond");
    console.log("3. Initialize facet with initializeBasicProtocol()");
    console.log("=".repeat(60));

    // Return deployment info for scripting
    return {
        facetAddress,
        selectors,
        protocolAddress: addresses.protocolAddress,
    };
}

/**
 * Get function selectors from a contract
 * @param {Contract} contract Ethers contract instance
 * @returns {string[]} Array of function selectors (4-byte hex)
 */
function getSelectors(contract) {
    const selectors = [];
    const fragment = contract.interface.fragments;

    for (const f of fragment) {
        if (f.type === "function") {
            const selector = contract.interface.getFunction(f.name).selector;
            selectors.push({
                name: f.name,
                selector: selector,
            });
        }
    }

    return selectors;
}

// Execute deployment
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

module.exports = { main, getSelectors };

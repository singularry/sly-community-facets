const { ethers } = require("hardhat");

/**
 * Attach BasicProtocolFacet to SLYWallet Diamond
 *
 * TEMPLATE INSTRUCTIONS:
 * 1. Replace "BasicProtocol" with your protocol name
 * 2. Update wallet addresses and facet address
 * 3. Customize initialization parameters
 *
 * USAGE:
 * npx hardhat run scripts/attach.js --network bsc
 *
 * PREREQUISITES:
 * - Facet must be deployed (run deploy.js first)
 * - Caller must be wallet owner
 * - Have sufficient gas for diamondCut + initialization
 */

// Configuration - Update these values
const CONFIG = {
    // Deployed facet address (from deploy.js output)
    FACET_ADDRESS: "0x0000000000000000000000000000000000000000",

    // Target SLYWallet diamond address
    WALLET_ADDRESS: "0x0000000000000000000000000000000000000000",

    // Protocol address for initialization
    PROTOCOL_ADDRESS: "0x0000000000000000000000000000000000000000",
};

// Diamond cut action types
const FacetCutAction = {
    Add: 0,
    Replace: 1,
    Remove: 2,
};

async function main() {
    const [signer] = await ethers.getSigners();

    console.log("=".repeat(60));
    console.log("Attaching BasicProtocolFacet to SLYWallet");
    console.log("=".repeat(60));
    console.log(`Signer: ${signer.address}`);
    console.log(`Wallet: ${CONFIG.WALLET_ADDRESS}`);
    console.log(`Facet: ${CONFIG.FACET_ADDRESS}`);
    console.log("");

    // Validate configuration
    if (CONFIG.FACET_ADDRESS === ethers.ZeroAddress) {
        throw new Error("FACET_ADDRESS not configured. Run deploy.js first.");
    }
    if (CONFIG.WALLET_ADDRESS === ethers.ZeroAddress) {
        throw new Error("WALLET_ADDRESS not configured.");
    }

    // Get facet contract to extract selectors
    const facet = await ethers.getContractAt("BasicProtocolFacet", CONFIG.FACET_ADDRESS);

    // Extract function selectors
    const selectors = [];
    const fragment = facet.interface.fragments;
    for (const f of fragment) {
        if (f.type === "function") {
            selectors.push(facet.interface.getFunction(f.name).selector);
        }
    }

    console.log(`Found ${selectors.length} function selectors`);

    // Prepare diamond cut
    const facetCut = {
        facetAddress: CONFIG.FACET_ADDRESS,
        action: FacetCutAction.Add,
        functionSelectors: selectors,
    };

    // Encode initialization call
    const initData = facet.interface.encodeFunctionData("initializeBasicProtocol", [
        CONFIG.PROTOCOL_ADDRESS,
    ]);

    // Get diamond cut interface
    const diamondCut = await ethers.getContractAt("IDiamondCut", CONFIG.WALLET_ADDRESS);

    console.log("\nExecuting diamondCut...");
    console.log(`- Action: Add (${FacetCutAction.Add})`);
    console.log(`- Facet: ${CONFIG.FACET_ADDRESS}`);
    console.log(`- Selectors: ${selectors.length}`);
    console.log(`- Init target: ${CONFIG.FACET_ADDRESS}`);

    // Execute diamond cut with initialization
    const tx = await diamondCut.diamondCut(
        [facetCut],
        CONFIG.FACET_ADDRESS, // Init contract (the facet itself)
        initData // Init calldata
    );

    console.log(`\nTransaction submitted: ${tx.hash}`);
    console.log("Waiting for confirmation...");

    const receipt = await tx.wait();
    console.log(`Confirmed in block ${receipt.blockNumber}`);
    console.log(`Gas used: ${receipt.gasUsed.toString()}`);

    // Verify attachment
    console.log("\nVerifying attachment...");
    const walletFacet = await ethers.getContractAt("IBasicProtocolFacet", CONFIG.WALLET_ADDRESS);

    const isInitialized = await walletFacet.isBasicProtocolInitialized();
    const protocolAddress = await walletFacet.getProtocolAddress();

    console.log(`- Initialized: ${isInitialized}`);
    console.log(`- Protocol Address: ${protocolAddress}`);

    if (isInitialized && protocolAddress === CONFIG.PROTOCOL_ADDRESS) {
        console.log("\n" + "=".repeat(60));
        console.log("SUCCESS: Facet attached and initialized!");
        console.log("=".repeat(60));
    } else {
        console.log("\nWARNING: Verification failed. Check configuration.");
    }
}

// Execute
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

module.exports = { main, FacetCutAction };

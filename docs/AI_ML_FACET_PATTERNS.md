# AI/ML-Driven Facet Patterns

This document describes architectural patterns for building facets that leverage AI/ML models for automated decision-making in DeFi strategies.

## Overview

AI/ML-driven facets enable intelligent automation such as:
- **LP Pool Selection**: Choose optimal pools based on yield, risk, and liquidity
- **Rebalancing Triggers**: Determine when to rebalance portfolios
- **Entry/Exit Timing**: Predict favorable market conditions
- **Risk Assessment**: Dynamic collateral ratio adjustments
- **Yield Optimization**: Route deposits to highest-yielding strategies

## Architecture Patterns

### Pattern 1: Off-Chain Model, On-Chain Execution

The most practical pattern: AI/ML models run off-chain, and their decisions are executed on-chain through the permissionless execution system.

```
┌─────────────────────────────────────────────────────────────┐
│                    Off-Chain (Executor Service)              │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │  Data Feed   │───>│  ML Model    │───>│  Decision    │   │
│  │  (prices,    │    │  (predict    │    │  Engine      │   │
│  │   volumes)   │    │   optimal)   │    │  (validate)  │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
│                                                │              │
│                                                ▼              │
│                                    ┌───────────────────┐     │
│                                    │ Execute on-chain  │     │
│                                    └───────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                                                │
                                                ▼
┌─────────────────────────────────────────────────────────────┐
│                    On-Chain (SLYWallet Facet)                │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────┐   │
│  │  AIStrategyFacet                                      │   │
│  │  ├─ validateDecision(params) → bool                  │   │
│  │  ├─ executeStrategy(poolId, amount) → success        │   │
│  │  └─ getUserConstraints() → (minYield, maxRisk, etc)  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Advantages:**
- No gas costs for model inference
- Can use complex models (neural networks, ensemble methods)
- Easy to update models without contract changes
- Scalable to many users

**Implementation:**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../slywallet/SLYWalletReentrancyGuard.sol";

library AIStrategyStorage {
    bytes32 constant STORAGE_SLOT = keccak256("com.slywallet.aistrategy.storage");

    struct PoolConfig {
        address poolAddress;
        address lpToken;
        bool active;
        uint256 minLiquidity;      // Minimum pool liquidity required
        uint256 maxAllocation;     // Max % of portfolio (basis points)
    }

    struct UserConstraints {
        uint256 minExpectedYield;   // Minimum APY in basis points
        uint256 maxRiskScore;       // Maximum risk score (1-100)
        uint256 maxSlippage;        // Max slippage in basis points
        uint256 rebalanceThreshold; // % deviation to trigger rebalance
        address[] allowedPools;     // Whitelist of pools
    }

    struct Layout {
        bool initialized;
        mapping(bytes32 => PoolConfig) pools;          // poolId => config
        mapping(address => UserConstraints) constraints; // user => constraints
        mapping(address => uint256) lastRebalance;     // user => timestamp
        uint256 cooldownPeriod;                        // Min time between rebalances
    }

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

contract AIStrategyFacet is SLYWalletReentrancyGuard {
    using AIStrategyStorage for AIStrategyStorage.Layout;

    event StrategyExecuted(
        address indexed user,
        bytes32 indexed poolId,
        uint256 amount,
        uint256 timestamp
    );

    event ConstraintsUpdated(address indexed user);

    /**
     * @notice Set user constraints for AI-driven decisions
     * @param constraints User's risk and yield preferences
     */
    function setAIConstraints(
        AIStrategyStorage.UserConstraints calldata constraints
    ) external {
        AIStrategyStorage.Layout storage s = AIStrategyStorage.layout();
        s.constraints[msg.sender] = constraints;
        emit ConstraintsUpdated(msg.sender);
    }

    /**
     * @notice Execute AI-recommended strategy (called by executor)
     * @param poolId Target pool identifier
     * @param amount Amount to deploy
     * @param expectedYield Expected APY from model (for validation)
     * @param riskScore Risk score from model (for validation)
     */
    function executeAIStrategy(
        bytes32 poolId,
        uint256 amount,
        uint256 expectedYield,
        uint256 riskScore
    ) external nonReentrant returns (bool) {
        AIStrategyStorage.Layout storage s = AIStrategyStorage.layout();
        address user = address(this); // The SLYWallet

        // Validate cooldown
        require(
            block.timestamp >= s.lastRebalance[user] + s.cooldownPeriod,
            "Cooldown not elapsed"
        );

        // Validate against user constraints
        AIStrategyStorage.UserConstraints storage c = s.constraints[user];
        require(expectedYield >= c.minExpectedYield, "Yield below minimum");
        require(riskScore <= c.maxRiskScore, "Risk above maximum");

        // Validate pool is configured and active
        AIStrategyStorage.PoolConfig storage pool = s.pools[poolId];
        require(pool.active, "Pool not active");

        // Validate pool is in user's whitelist (if set)
        if (c.allowedPools.length > 0) {
            bool allowed = false;
            for (uint i = 0; i < c.allowedPools.length; i++) {
                if (c.allowedPools[i] == pool.poolAddress) {
                    allowed = true;
                    break;
                }
            }
            require(allowed, "Pool not in whitelist");
        }

        // Execute the strategy (deposit into LP)
        _executeDeposit(pool.poolAddress, pool.lpToken, amount, c.maxSlippage);

        s.lastRebalance[user] = block.timestamp;

        emit StrategyExecuted(user, poolId, amount, block.timestamp);
        return true;
    }

    /**
     * @notice Check if rebalance is needed based on current allocation
     * @return needsRebalance Whether rebalance threshold is exceeded
     * @return currentDeviation Current deviation from target in basis points
     */
    function checkRebalanceNeeded() external view returns (
        bool needsRebalance,
        uint256 currentDeviation
    ) {
        AIStrategyStorage.Layout storage s = AIStrategyStorage.layout();
        address user = address(this);

        // Calculate current portfolio deviation
        currentDeviation = _calculateDeviation();

        AIStrategyStorage.UserConstraints storage c = s.constraints[user];
        needsRebalance = currentDeviation >= c.rebalanceThreshold;

        // Also check cooldown
        if (block.timestamp < s.lastRebalance[user] + s.cooldownPeriod) {
            needsRebalance = false;
        }
    }

    /**
     * @notice Get positions ready for AI-driven rebalancing
     * @return users Array of wallet addresses needing rebalance
     * @return deviations Current deviation for each wallet
     */
    function getRebalanceReadyPositions() external view returns (
        address[] memory users,
        uint256[] memory deviations
    ) {
        // Implementation would iterate registered users
        // and return those exceeding rebalance threshold
    }

    // Internal functions
    function _executeDeposit(
        address pool,
        address lpToken,
        uint256 amount,
        uint256 maxSlippage
    ) internal {
        // Implementation depends on pool type (Uniswap V2, V3, Curve, etc.)
    }

    function _calculateDeviation() internal view returns (uint256) {
        // Calculate current vs target allocation deviation
        return 0; // Placeholder
    }
}
```

### Pattern 2: Oracle-Based Model Outputs

For scenarios requiring trustless model outputs, use an oracle pattern where model predictions are published on-chain.

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   ML Model       │────>│   Oracle Node    │────>│   On-Chain       │
│   (off-chain)    │     │   (signs data)   │     │   Oracle         │
└──────────────────┘     └──────────────────┘     └──────────────────┘
                                                          │
                                                          ▼
                                                  ┌──────────────────┐
                                                  │   Facet reads    │
                                                  │   oracle data    │
                                                  └──────────────────┘
```

**Oracle Contract:**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AIModelOracle {
    using ECDSA for bytes32;

    struct Prediction {
        bytes32 poolId;           // Recommended pool
        uint256 expectedYield;    // Predicted APY (basis points)
        uint256 riskScore;        // Risk assessment (1-100)
        uint256 confidence;       // Model confidence (1-100)
        uint256 timestamp;        // When prediction was made
        uint256 validUntil;       // Prediction expiry
    }

    address public trustedSigner;
    mapping(bytes32 => Prediction) public predictions;

    event PredictionUpdated(bytes32 indexed predictionId, bytes32 poolId, uint256 expectedYield);

    /**
     * @notice Submit a signed prediction from the ML model
     * @param prediction The prediction data
     * @param signature Signature from trusted signer
     */
    function submitPrediction(
        Prediction calldata prediction,
        bytes calldata signature
    ) external {
        bytes32 messageHash = keccak256(abi.encode(
            prediction.poolId,
            prediction.expectedYield,
            prediction.riskScore,
            prediction.confidence,
            prediction.timestamp,
            prediction.validUntil
        ));

        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedHash.recover(signature);
        require(signer == trustedSigner, "Invalid signature");

        bytes32 predictionId = keccak256(abi.encode(prediction.poolId, prediction.timestamp));
        predictions[predictionId] = prediction;

        emit PredictionUpdated(predictionId, prediction.poolId, prediction.expectedYield);
    }

    /**
     * @notice Get the latest valid prediction for a pool
     */
    function getLatestPrediction(bytes32 poolId) external view returns (
        Prediction memory prediction,
        bool isValid
    ) {
        // Implementation would return latest non-expired prediction
    }
}
```

**Facet Using Oracle:**

```solidity
contract OracleAIStrategyFacet {
    IAIModelOracle public oracle;

    function executeWithOraclePrediction(
        bytes32 predictionId,
        uint256 amount
    ) external {
        (IAIModelOracle.Prediction memory pred, bool isValid) =
            oracle.getPrediction(predictionId);

        require(isValid, "Prediction expired or invalid");
        require(pred.confidence >= 70, "Confidence too low");
        require(block.timestamp <= pred.validUntil, "Prediction expired");

        // Validate against user constraints
        // Execute strategy based on prediction
    }
}
```

### Pattern 3: Keeper Network Integration

Integrate with decentralized keeper networks (Chainlink Automation, Gelato) for trustless execution.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract AIRebalanceFacet is AutomationCompatibleInterface {

    /**
     * @notice Chainlink Automation check function
     * @dev Called off-chain to determine if upkeep is needed
     */
    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // Check if any positions need rebalancing
        (address[] memory walletsToRebalance, bytes32[] memory targetPools) =
            _getPositionsNeedingRebalance();

        upkeepNeeded = walletsToRebalance.length > 0;
        performData = abi.encode(walletsToRebalance, targetPools);
    }

    /**
     * @notice Chainlink Automation perform function
     * @dev Called on-chain when checkUpkeep returns true
     */
    function performUpkeep(bytes calldata performData) external override {
        (address[] memory wallets, bytes32[] memory pools) =
            abi.decode(performData, (address[], bytes32[]));

        for (uint i = 0; i < wallets.length; i++) {
            _executeRebalance(wallets[i], pools[i]);
        }
    }

    function _getPositionsNeedingRebalance() internal view returns (
        address[] memory,
        bytes32[] memory
    ) {
        // Query registered positions, check thresholds
        // Return those exceeding rebalance threshold
    }

    function _executeRebalance(address wallet, bytes32 targetPool) internal {
        // Execute the rebalance for the wallet
    }
}
```

## Use Case Examples

### Example 1: AI LP Pool Selector

**Scenario:** User wants to deposit stablecoins into the optimal LP pool based on yield and risk.

**Off-Chain Model:**
```python
# Executor service with ML model
import numpy as np
from sklearn.ensemble import RandomForestRegressor

class LPPoolSelector:
    def __init__(self):
        self.model = RandomForestRegressor()
        # Pre-trained on historical pool data

    def get_features(self, pool_address):
        """Fetch on-chain and off-chain features for a pool"""
        return {
            'tvl': self.get_tvl(pool_address),
            'volume_24h': self.get_volume(pool_address),
            'fee_apr': self.get_fee_apr(pool_address),
            'reward_apr': self.get_reward_apr(pool_address),
            'il_risk': self.calculate_il_risk(pool_address),
            'protocol_risk': self.get_protocol_risk_score(pool_address),
            'liquidity_depth': self.get_liquidity_depth(pool_address),
        }

    def predict_optimal_pool(self, candidate_pools, user_constraints):
        """Select optimal pool based on model prediction"""
        best_score = -np.inf
        best_pool = None

        for pool in candidate_pools:
            features = self.get_features(pool)

            # Skip pools not meeting constraints
            if features['il_risk'] > user_constraints['max_risk']:
                continue
            if features['fee_apr'] + features['reward_apr'] < user_constraints['min_yield']:
                continue

            # Predict risk-adjusted return
            prediction = self.model.predict([list(features.values())])[0]

            if prediction > best_score:
                best_score = prediction
                best_pool = pool

        return best_pool, best_score
```

**On-Chain Facet:**
```solidity
contract AILPSelectorFacet {

    struct PoolSelection {
        bytes32 poolId;
        uint256 amount;
        uint256 modelScore;      // Score from ML model
        uint256 timestamp;
    }

    event PoolSelected(
        address indexed user,
        bytes32 indexed poolId,
        uint256 amount,
        uint256 modelScore
    );

    /**
     * @notice Execute deposit into AI-selected pool
     * @dev Called by executor with model output
     */
    function depositToAISelectedPool(
        bytes32 poolId,
        uint256 amount,
        uint256 modelScore,
        uint256 minLPTokens
    ) external returns (uint256 lpReceived) {
        // Validate pool is configured
        PoolConfig storage pool = _getPool(poolId);
        require(pool.active, "Pool not active");

        // Validate against user constraints
        UserConstraints storage c = _getUserConstraints(address(this));
        require(_isPoolAllowed(poolId, c), "Pool not in whitelist");

        // Execute deposit
        lpReceived = _depositToPool(pool, amount, minLPTokens);

        emit PoolSelected(address(this), poolId, amount, modelScore);
        return lpReceived;
    }
}
```

### Example 2: AI Rebalancing Trigger

**Scenario:** Portfolio should rebalance when market conditions or allocation drift warrant it.

**Off-Chain Model:**
```python
class RebalanceTrigger:
    def __init__(self):
        self.volatility_threshold = 0.05  # 5%
        self.drift_threshold = 0.10       # 10%

    def should_rebalance(self, wallet_address):
        """Determine if wallet should rebalance"""
        current_allocation = self.get_current_allocation(wallet_address)
        target_allocation = self.get_target_allocation(wallet_address)

        # Calculate drift
        drift = self.calculate_drift(current_allocation, target_allocation)

        # Get market volatility
        volatility = self.get_market_volatility()

        # ML model predicts optimal timing
        features = {
            'drift': drift,
            'volatility': volatility,
            'gas_price': self.get_gas_price(),
            'time_since_last': self.get_time_since_last_rebalance(wallet_address),
        }

        should_rebalance = self.timing_model.predict([list(features.values())])[0]

        return should_rebalance > 0.7, drift, features
```

### Example 3: AI Yield Optimizer

**Scenario:** Automatically move funds between yield sources based on predicted returns.

```solidity
contract AIYieldOptimizerFacet {

    struct YieldPosition {
        bytes32 strategyId;
        address protocol;
        uint256 amount;
        uint256 entryYield;       // APY when entered
        uint256 entryTimestamp;
    }

    /**
     * @notice Migrate to higher-yielding strategy
     * @param fromStrategy Current strategy
     * @param toStrategy Target strategy (AI-selected)
     * @param amount Amount to migrate
     * @param expectedYieldIncrease Expected APY improvement (for validation)
     */
    function migrateYield(
        bytes32 fromStrategy,
        bytes32 toStrategy,
        uint256 amount,
        uint256 expectedYieldIncrease
    ) external {
        // Validate minimum yield improvement worth gas cost
        require(expectedYieldIncrease >= 50, "Yield increase too small"); // 0.5% minimum

        // Validate strategy is configured
        require(_isStrategyActive(toStrategy), "Strategy not active");

        // Withdraw from current
        uint256 withdrawn = _withdrawFromStrategy(fromStrategy, amount);

        // Deposit to new (with slippage protection)
        uint256 deposited = _depositToStrategy(toStrategy, withdrawn);

        emit YieldMigrated(fromStrategy, toStrategy, deposited, expectedYieldIncrease);
    }
}
```

## Security Considerations

### 1. Constraint Validation

Always validate AI decisions against user-defined constraints:

```solidity
modifier validatesConstraints(
    uint256 expectedYield,
    uint256 riskScore,
    bytes32 poolId
) {
    UserConstraints storage c = constraints[address(this)];

    require(expectedYield >= c.minExpectedYield, "Yield below minimum");
    require(riskScore <= c.maxRiskScore, "Risk above maximum");
    require(_isPoolAllowed(poolId, c.allowedPools), "Pool not whitelisted");
    _;
}
```

### 2. Rate Limiting

Prevent excessive operations from AI-driven decisions:

```solidity
modifier rateLimited() {
    Layout storage s = layout();
    require(
        block.timestamp >= s.lastExecution[address(this)] + s.cooldownPeriod,
        "Rate limited"
    );
    s.lastExecution[address(this)] = block.timestamp;
    _;
}
```

### 3. Maximum Position Sizes

Limit exposure to any single AI-selected pool:

```solidity
function _validatePositionSize(bytes32 poolId, uint256 amount) internal view {
    UserConstraints storage c = constraints[address(this)];

    uint256 totalPortfolio = _getTotalPortfolioValue();
    uint256 currentInPool = _getPositionValue(poolId);
    uint256 newTotal = currentInPool + amount;

    uint256 allocationBps = (newTotal * 10000) / totalPortfolio;
    require(allocationBps <= c.maxAllocationPerPool, "Exceeds max allocation");
}
```

### 4. Emergency Stop

Allow users to pause AI-driven operations:

```solidity
mapping(address => bool) public aiPaused;

function pauseAI() external {
    aiPaused[address(this)] = true;
    emit AIPaused(address(this));
}

function resumeAI() external {
    aiPaused[address(this)] = false;
    emit AIResumed(address(this));
}

modifier whenAIActive() {
    require(!aiPaused[address(this)], "AI operations paused");
    _;
}
```

### 5. Oracle Security

For oracle-based patterns:

```solidity
// Multiple oracle verification
function verifyPrediction(Prediction memory pred) internal view returns (bool) {
    require(pred.timestamp + MAX_STALENESS > block.timestamp, "Stale prediction");
    require(pred.confidence >= MIN_CONFIDENCE, "Low confidence");

    // Optional: Require multiple oracle signatures
    require(pred.signerCount >= REQUIRED_SIGNERS, "Insufficient signers");

    return true;
}
```

## Gas Optimization

### Batch Operations

Process multiple wallets in a single transaction:

```solidity
function batchRebalance(
    address[] calldata wallets,
    bytes32[] calldata targetPools,
    uint256[] calldata amounts
) external {
    require(wallets.length == targetPools.length, "Length mismatch");

    for (uint i = 0; i < wallets.length; i++) {
        _executeRebalance(wallets[i], targetPools[i], amounts[i]);
    }
}
```

### Lazy Evaluation

Only compute when needed:

```solidity
function getRebalanceSignal(address wallet) external view returns (
    bool shouldRebalance,
    bytes32 suggestedPool
) {
    // Quick checks first
    if (block.timestamp < lastRebalance[wallet] + cooldown) {
        return (false, bytes32(0));
    }

    // Only do expensive calculation if cooldown passed
    uint256 drift = _calculateDrift(wallet);
    if (drift < rebalanceThreshold[wallet]) {
        return (false, bytes32(0));
    }

    // Expensive: determine target pool
    suggestedPool = _findOptimalPool(wallet);
    return (true, suggestedPool);
}
```

## Testing AI Facets

### Mock Oracle for Testing

```solidity
contract MockAIOracle {
    mapping(bytes32 => Prediction) public predictions;

    function setPrediction(
        bytes32 predictionId,
        bytes32 poolId,
        uint256 expectedYield,
        uint256 riskScore
    ) external {
        predictions[predictionId] = Prediction({
            poolId: poolId,
            expectedYield: expectedYield,
            riskScore: riskScore,
            confidence: 90,
            timestamp: block.timestamp,
            validUntil: block.timestamp + 1 hours
        });
    }
}
```

### Test Scenarios

```javascript
describe("AIStrategyFacet", function() {
    it("should execute AI strategy within constraints", async function() {
        // Set user constraints
        await facet.setAIConstraints({
            minExpectedYield: 500,  // 5% APY
            maxRiskScore: 50,
            maxSlippage: 100,       // 1%
            rebalanceThreshold: 500, // 5%
            allowedPools: [pool1.address, pool2.address]
        });

        // Execute AI-recommended strategy
        await facet.executeAIStrategy(
            poolId,
            ethers.parseEther("100"),
            800,  // 8% expected yield
            30    // Risk score 30
        );

        // Verify position was opened
        expect(await getPosition(wallet, poolId)).to.be.gt(0);
    });

    it("should reject strategy outside constraints", async function() {
        await expect(
            facet.executeAIStrategy(poolId, amount, 300, 30) // Below min yield
        ).to.be.revertedWith("Yield below minimum");

        await expect(
            facet.executeAIStrategy(poolId, amount, 800, 70) // Above max risk
        ).to.be.revertedWith("Risk above maximum");
    });

    it("should respect cooldown period", async function() {
        await facet.executeAIStrategy(poolId, amount, 800, 30);

        // Immediate second execution should fail
        await expect(
            facet.executeAIStrategy(poolId2, amount, 900, 25)
        ).to.be.revertedWith("Cooldown not elapsed");
    });
});
```

## Summary

AI/ML-driven facets enable intelligent automation while maintaining on-chain security:

| Pattern | Best For | Complexity | Trust Model |
|---------|----------|------------|-------------|
| Off-chain model, on-chain execution | Most use cases | Low | Trust executor |
| Oracle-based predictions | Trustless verification | Medium | Trust oracle signers |
| Keeper network integration | Fully automated | High | Trust keeper network |

**Key Principles:**
1. **Validate everything on-chain** - Never trust model outputs blindly
2. **User constraints are king** - All decisions must respect user preferences
3. **Rate limit operations** - Prevent runaway AI from excessive transactions
4. **Emergency stops** - Users must be able to pause AI anytime
5. **Maximum position limits** - Cap exposure to AI-selected strategies

For questions or support, see the [Facet Developer Guide](./FACET_DEVELOPER_GUIDE.md).

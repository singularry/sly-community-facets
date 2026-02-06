# Facet Submission Guidelines

This document describes how to submit a facet for inclusion in the SLY ecosystem.

## Before You Start

### Requirements

Your facet must:

1. **Provide Value**: Integrate a useful DeFi protocol or add meaningful functionality
2. **Follow Standards**: Use approved patterns from templates
3. **Be Secure**: No vulnerabilities, proper access control
4. **Be Tested**: Comprehensive unit and E2E tests
5. **Be Documented**: NatSpec comments and README

### Prohibited

Submissions will be rejected if they:

- Contain backdoors or admin keys
- Have known security vulnerabilities
- Plagiarize existing work without attribution
- Integrate scam or malicious protocols
- Violate any applicable laws

## Submission Process

### Step 1: Prepare Your Facet

```
submissions/pending/your-facet-name/
├── contracts/
│   ├── IYourProtocolFacet.sol      # Interface
│   ├── YourProtocolFacet.sol       # Implementation
│   └── YourProtocolStorage.sol     # Storage library
├── test/
│   ├── YourProtocolFacet.test.js   # Unit tests
│   └── YourProtocolE2E.test.js     # E2E fork tests
├── scripts/
│   ├── deploy.js                   # Deployment script
│   └── attach.js                   # Diamond attachment
└── README.md                       # Documentation
```

### Step 2: Create Pull Request

Use our PR template and provide:

#### Required Information

```markdown
## Facet Information
- **Name**: YourProtocolFacet
- **Protocol Integration**: Protocol Name (e.g., Venus, Aave)
- **Author(s)**: Your name/handle
- **Developer Wallet**: 0x... (for revenue payments)

## Description
What does this facet do? What problem does it solve for SLY users?

## Revenue Model
- **Requested Fee Split**: X% (max 50%)
- **Expected Usage**: Estimated monthly volume

## Protocol Details
- **Protocol Website**: https://...
- **Protocol Audit Reports**: Links to audits
- **Mainnet Addresses**: List of contract addresses used
```

#### Checklist

Include in your PR:

- [ ] Follows template structure from `templates/`
- [ ] All tests pass locally
- [ ] Contract size < 24KB
- [ ] Uses only approved libraries
- [ ] No external dependencies beyond target protocol
- [ ] No hardcoded addresses (configurable via init)
- [ ] README complete with usage examples
- [ ] NatSpec documentation on all public functions

#### Security Attestation

- [ ] No admin backdoors
- [ ] Proper access control implemented (onlyAdmin/onlyOwner)
- [ ] Reentrancy protection used (SLYWalletReentrancyGuard)
- [ ] All external calls protected
- [ ] No unchecked arithmetic with user input
- [ ] Token approvals properly handled (forceApprove, no infinite)

### Step 3: Automated Checks

When you open a PR, our CI will automatically:

1. **Compile** - Verify contracts compile
2. **Test** - Run your test suite
3. **Security Scan** - Run Slither analysis
4. **Size Check** - Verify contract size < 24KB
5. **Coverage** - Check test coverage (target: >80%)

### Step 4: Review Process

1. **Initial Review** (1-2 weeks)
   - Code quality review
   - Security assessment
   - Value proposition evaluation

2. **Revision Period**
   - Address review feedback
   - Answer questions
   - Make required changes

3. **Approval Decision**
   - Approved → Moves to `under-audit/`
   - Rejected → Moves to `rejected/` with feedback

### Step 5: Audit (if required)

| Complexity | Audit Level | Timeline |
|------------|-------------|----------|
| Simple (< 200 LOC) | Internal review | 1 week |
| Medium (200-500 LOC) | Single auditor | 2-3 weeks |
| Complex (> 500 LOC) | Full audit | 4-6 weeks |

### Step 6: Deployment

After passing audit:
1. Facet deployed to mainnet
2. Added to `registry/facets.json`
3. Moved to `submissions/approved/`
4. Revenue sharing activated

## Revenue Sharing Details

### Fee Structure

When users interact with your facet and pay SLY fees:

```
Total Fee
├── Executor Fee (10%) → Transaction executor
└── Remaining (90%)
    ├── Developer Fee (X%) → Your wallet
    └── SLY Fee (90-X%) → SLY treasury
```

### Payment Schedule

- Revenue calculated on-chain
- Claimable at any time
- No minimum threshold

### Fee Split Guidelines

| Facet Type | Suggested Split |
|------------|-----------------|
| Simple integration | 20-30% |
| Complex lending/yield | 30-40% |
| Novel functionality | 40-50% |

## Common Rejection Reasons

1. **Security Issues**
   - Unchecked external calls
   - Missing reentrancy guards
   - Improper access control

2. **Quality Issues**
   - Insufficient tests
   - Poor documentation
   - Copied code without attribution

3. **Value Issues**
   - Duplicate of existing facet
   - Low-value integration
   - Unreliable target protocol

4. **Technical Issues**
   - Contract too large
   - Incompatible storage pattern
   - Breaks diamond standard

## Tips for Success

1. **Start with a Template**
   - Use `BasicProtocolFacet`, `LendingProtocolFacet`, or `SwapProtocolFacet`
   - Follow existing patterns exactly

2. **Write Comprehensive Tests**
   - Unit tests for every function
   - E2E tests with mainnet fork
   - Test error conditions and edge cases

3. **Document Everything**
   - NatSpec on all public functions
   - README with clear examples
   - Explain why, not just what

4. **Security First**
   - Use SafeERC20 for token operations
   - Always use reentrancy guards
   - Validate all inputs

5. **Engage Early**
   - Get feedback before building
   - Ask questions in #facet-developers

## Questions?

- Email: developers@singularry.com
- Office Hours: Wednesdays 3pm UTC

# Facet Submission

## Facet Information

| Field | Value |
|-------|-------|
| **Facet Name** | |
| **Protocol** | |
| **Author(s)** | |
| **Developer Wallet** | `0x...` |
| **Requested Fee Split** | % |

## Description

<!-- Brief description of what this facet does -->

## Changes

<!-- List the files added/modified -->

### Contracts
- `contracts/I{Name}Facet.sol` - Interface
- `contracts/{Name}Facet.sol` - Implementation
- `contracts/{Name}Storage.sol` - Storage

### Tests
- `test/{Name}Facet.test.js` - Unit tests
- `test/{Name}E2E.test.js` - E2E tests (if applicable)

### Scripts
- `scripts/deploy.js` - Deployment
- `scripts/attach.js` - Diamond attachment

## Test Results

<!-- Paste test output or summary -->

```
Tests: X passing
Coverage: X%
Gas: ~Xk per operation
```

## Checklist

### Required
- [ ] Code compiles without errors
- [ ] All tests pass
- [ ] Contract size < 24KB
- [ ] Located in `submissions/pending/{facet-name}/`

### Code Quality
- [ ] Follows template patterns
- [ ] NatSpec documentation complete
- [ ] Events for all state changes
- [ ] Custom errors used

### Security
- [ ] `SLYWalletReentrancyGuard` used
- [ ] `onlyAdmin` modifier on state-changing functions
- [ ] `SafeERC20` for token operations
- [ ] No hardcoded addresses
- [ ] Input validation on all public functions

### Testing
- [ ] >80% line coverage
- [ ] Error cases tested
- [ ] E2E with mainnet fork (if integrating external protocol)

### Documentation
- [ ] README.md with examples
- [ ] Deployment instructions
- [ ] Function descriptions

## Protocol Integration Details

<!-- If integrating an external protocol -->

| Protocol | Address |
|----------|---------|
| Main Contract | `0x...` |
| Oracle | `0x...` |

**Protocol Audits**: [Link to audit reports]

## Security Considerations

<!-- Describe any security considerations specific to this facet -->

- Risk 1: How it's mitigated
- Risk 2: How it's mitigated

## Deployment Plan

<!-- How should this be deployed and configured? -->

1. Deploy facet to mainnet
2. Call `diamondCut` to attach
3. Initialize with: `initializeXXX(param1, param2)`
4. Configure: [any additional setup]

---

By submitting this PR, I confirm that:
- This is my original work or properly attributed
- I have tested thoroughly
- I understand the review process
- I agree to the terms of contribution

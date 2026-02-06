---
name: Facet Submission
about: Submit a new facet for the SLY ecosystem
title: '[SUBMISSION] '
labels: submission, pending-review
assignees: ''
---

## Facet Information

| Field | Value |
|-------|-------|
| **Facet Name** | |
| **Protocol Integration** | |
| **Author(s)** | |
| **Developer Wallet** | |
| **PR Link** | |

## Description

<!-- What does this facet do? What problem does it solve for SLY users? -->

## Protocol Details

- **Protocol Website**:
- **Protocol Documentation**:
- **Protocol Audit Reports**:
- **Mainnet Contract Addresses**:
  -

## Revenue Model

| Field | Value |
|-------|-------|
| **Requested Fee Split** | % (max 50%) |
| **Expected Monthly Volume** | |
| **Target User Base** | |

## Technical Details

### Functions Implemented

<!-- List the main functions your facet provides -->

- [ ] Function 1: Description
- [ ] Function 2: Description

### Dependencies

<!-- List any external contracts or libraries used -->

- Contract 1: Address
- Library 1: Version

### Storage Layout

<!-- Describe your storage structure briefly -->

```solidity
// Storage hash: keccak256("...")
struct Layout {
    // ...
}
```

## Submission Checklist

### Structure
- [ ] Follows template structure from `templates/`
- [ ] Located in `submissions/pending/{facet-name}/`
- [ ] Contains all required files (contracts, tests, scripts, README)

### Code Quality
- [ ] Clean, readable code
- [ ] NatSpec documentation on all public functions
- [ ] Proper error handling with custom errors
- [ ] Events emitted for state changes

### Security
- [ ] Uses `SLYWalletReentrancyGuard` for external calls
- [ ] Proper access control (`onlyAdmin`/`onlyOwner`)
- [ ] Uses `SafeERC20` for token operations
- [ ] No hardcoded addresses (configurable via init)
- [ ] No admin backdoors or privileged functions

### Testing
- [ ] Unit tests for all functions
- [ ] E2E tests with mainnet fork
- [ ] Edge cases and error conditions tested
- [ ] Test coverage > 80%

### Deployment
- [ ] Deployment script works
- [ ] Attach script works
- [ ] Contract size < 24KB
- [ ] Gas usage reasonable

### Documentation
- [ ] README with usage examples
- [ ] Deployment instructions
- [ ] Configuration options documented

## Additional Context

<!-- Add any other context, screenshots, or information about your facet -->

## Attestation

By submitting this facet, I attest that:

- [ ] This is my original work (or properly attributed)
- [ ] I have not included any malicious code
- [ ] The target protocol is legitimate and audited
- [ ] I understand the review and audit process
- [ ] I agree to the revenue sharing terms

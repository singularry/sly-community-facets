# SLY Community Facets

Community-contributed facets for the SLYWallet ecosystem.

## What is This?

SLYWallet uses the Diamond Standard (EIP-2535) to enable modular functionality through "facets". This repository is where third-party developers can submit facets to be reviewed, audited, and integrated into the SLY ecosystem.

**Earn revenue** from your facets! Approved facets receive a percentage of SLY fees generated from their usage.

## Quick Links

- [Developer Guide](docs/DEVELOPER_GUIDE.md) - How to build facets
- [Submission Guidelines](docs/SUBMISSION_GUIDELINES.md) - How to submit
- [Contributing](docs/CONTRIBUTING.md) - Contribution workflow
- [Templates](templates/) - Starter templates

## Submission Workflow

```
1. Fork this repository
2. Create your facet in submissions/pending/your-facet-name/
3. Open a Pull Request with the required information
4. CI runs automated checks (compilation, tests, security scan)
5. Team reviews code quality and value-add
6. If approved → Moves to submissions/under-audit/
7. External audit (for complex facets)
8. If passed → Moves to submissions/approved/
9. Facet deployed to mainnet and added to registry
```

## Directory Structure

```
sly-community-facets/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   └── facet-submission.md    # Submission template
│   ├── PULL_REQUEST_TEMPLATE.md   # PR checklist
│   └── workflows/
│       ├── ci.yml                 # Compile & test
│       ├── security-scan.yml      # Slither analysis
│       └── size-check.yml         # Contract size check
├── submissions/
│   ├── pending/                   # New submissions
│   ├── under-audit/               # Approved for audit
│   ├── approved/                  # Ready for deployment
│   └── rejected/                  # Rejected with feedback
├── registry/
│   └── facets.json                # Deployed facet registry
├── templates/                     # Facet templates (from main repo)
└── docs/
    ├── DEVELOPER_GUIDE.md
    ├── SUBMISSION_GUIDELINES.md
    └── CONTRIBUTING.md
```

## Revenue Sharing

Developers earn a percentage of SLY fees generated when users interact with their facets:

| Facet Complexity | Revenue Share | Audit Requirement |
|------------------|---------------|-------------------|
| Simple (< 200 LOC) | Up to 30% | Internal review |
| Medium (200-500 LOC) | Up to 40% | Single auditor |
| Complex (> 500 LOC) | Up to 50% | Full audit |

Revenue is paid to your specified wallet address based on actual usage.

## Requirements

Before submitting, ensure your facet:

- [ ] Follows the template structure
- [ ] Has comprehensive tests (>80% coverage)
- [ ] Uses only approved libraries
- [ ] Contract size < 24KB
- [ ] No hardcoded addresses
- [ ] Proper access control
- [ ] Reentrancy protection
- [ ] NatSpec documentation

## Getting Started

### 1. Use a Template

Copy one of our starter templates:
- `BasicProtocolFacet` - Simple protocol integration
- `LendingProtocolFacet` - DeFi lending (Aave/Venus style)
- `SwapProtocolFacet` - DEX integration (Uniswap/PancakeSwap style)

### 2. Develop Your Facet

```bash
# Clone this repo
git clone https://github.com/singularry/sly-community-facets.git
cd sly-community-facets

# Create your facet
mkdir -p submissions/pending/my-protocol-facet
cp -r templates/BasicProtocolFacet/* submissions/pending/my-protocol-facet/

# Develop and test
cd submissions/pending/my-protocol-facet
# ... edit contracts ...
npx hardhat test
```

### 3. Submit via PR

See [SUBMISSION_GUIDELINES.md](docs/SUBMISSION_GUIDELINES.md) for detailed instructions.

## Approved Facets

| Facet | Author | Protocol | Status | Revenue Share |
|-------|--------|----------|--------|---------------|
| *Coming soon* | | | | |

## FAQ

**Q: How long does the review process take?**
A: Initial review typically takes 1-2 weeks. Audit timeline depends on complexity.

**Q: Who pays for audits?**
A: SLY covers audit costs for approved facets that add significant value.

**Q: Can I update my facet after approval?**
A: Yes, updates follow the same review process.

**Q: What if my facet is rejected?**
A: You'll receive detailed feedback. You can address issues and resubmit.

## License

Community facets are licensed under MIT unless otherwise specified.

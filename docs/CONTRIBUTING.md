# Contributing to SLY Community Facets

Thank you for your interest in contributing to the SLY ecosystem! This guide will help you understand how to submit facets and participate in the community.

## Code of Conduct

- Be respectful and constructive
- Focus on technical merit
- Help others learn and improve
- Report security issues responsibly

## Contribution Types

### 1. New Facet Submission

See [SUBMISSION_GUIDELINES.md](SUBMISSION_GUIDELINES.md) for the full process.

Quick steps:
1. Fork this repository
2. Create facet in `submissions/pending/your-facet-name/`
3. Open PR with required information
4. Respond to review feedback

### 2. Template Improvements

Help improve our starter templates:
- Bug fixes
- Documentation improvements
- New patterns

### 3. Documentation

- Fix typos and unclear sections
- Add examples
- Translate to other languages

### 4. Bug Reports

Found a bug in a community facet?
1. Check if it's already reported
2. Open an issue with reproduction steps
3. For security bugs, email security@singularry.com

## Development Setup

```bash
# Clone the repository
git clone https://github.com/singularry/sly-community-facets.git
cd sly-community-facets

# Install dependencies
npm install

# Link to main slywallet-contracts for development
npm link ../slywallet-contracts

# Run tests
npx hardhat test

# Run security scan
slither .
```

## Pull Request Process

### For New Facets

1. **Create Branch**
   ```bash
   git checkout -b submission/my-protocol-facet
   ```

2. **Add Your Facet**
   ```
   submissions/pending/my-protocol-facet/
   ├── contracts/
   ├── test/
   ├── scripts/
   └── README.md
   ```

3. **Open PR**
   - Use the facet submission template
   - Fill out all required fields
   - Ensure CI passes

4. **Address Review Feedback**
   - Respond to comments
   - Push fixes
   - Request re-review when ready

### For Other Contributions

1. Create a descriptive branch name
2. Make focused, atomic commits
3. Write clear commit messages
4. Open PR with description of changes

## Commit Message Format

```
type(scope): short description

Longer description if needed.

Fixes #123
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `test`: Tests
- `refactor`: Code refactoring
- `chore`: Maintenance

## Review Criteria

Facets are evaluated on:

1. **Code Quality**
   - Clean, readable code
   - Follows Solidity best practices
   - Proper error handling

2. **Security**
   - No vulnerabilities
   - Proper access control
   - Reentrancy protection

3. **Testing**
   - Comprehensive test coverage
   - E2E tests with mainnet fork
   - Edge cases handled

4. **Documentation**
   - NatSpec comments
   - README with usage examples
   - Clear deployment instructions

5. **Value-Add**
   - Useful integration
   - Demand from users
   - Quality of target protocol

## Getting Help

- **Discord**: Join #facet-developers channel
- **GitHub Issues**: For specific problems
- **Office Hours**: Weekly Q&A sessions

## License

By contributing, you agree that your contributions will be licensed under MIT.

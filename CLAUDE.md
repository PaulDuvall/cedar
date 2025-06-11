# Project-Specific Instructions for Claude

## Cedar Policy Store Project

This project manages AWS Cedar policies and their deployment via CloudFormation.

### Key Guidelines

1. **CloudFormation Templates**: When working with CloudFormation templates, always follow the rules in `cloudformation-ruleset.md`

2. **Policy Validation**: Before committing any Cedar policy changes, run:
   ```bash
   ./scripts/quick-validate.sh
   ```

3. **MANDATORY Pre-Commit Testing**: Before ANY add/commit/push, ALWAYS run the complete test suite:
   ```bash
   ./scripts/run-all-tests.sh
   ```
   This includes:
   - Cedar policy validation
   - ATDD (Acceptance Test-Driven Development) tests
   - GitHub Actions simulation (Act or mock)
   - Integration tests
   - Performance validation
   - Deployment simulation

4. **Deployment**: The project uses GitHub Actions for CI/CD. Changes to main branch trigger automatic deployment.

5. **File Structure**:
   - `policies/` - Cedar policy files
   - `cf/` - CloudFormation templates
   - `tests/` - Test suites for Cedar policies
   - `scripts/` - Utility scripts

### Development Workflow

**CRITICAL: NEVER skip step 3 - it prevents breaking changes and ensures GitHub Actions will pass**

1. Make changes to policies or CloudFormation templates
2. Quick validation during development: `./scripts/quick-validate.sh`
3. **MANDATORY before commit**: `./scripts/run-all-tests.sh` (includes ATDD, Act simulation, all tests)
4. Only if all tests pass: add, commit with descriptive message  
5. Push to trigger GitHub Actions (will pass because local tests mirror CI exactly)

### Important Notes

- Always validate Cedar policies before committing
- Follow AWS best practices for IAM and security
- Keep CloudFormation stacks focused and single-purpose
- IAM role `gha-oidc-PaulDuvall-cedar` is configured for GitHub Actions OIDC authentication
- Use local testing scripts before pushing to save time

### CRITICAL: Pre-Commit Testing Protocol

**NEVER commit or push without running the complete test suite first**

**MANDATORY before any add/commit/push:**
```bash
./scripts/run-all-tests.sh
```

This comprehensive script includes:
- ✅ Cedar policy validation (`quick-validate.sh`)
- ✅ ATDD tests (`tests/atdd/run_atdd_tests.sh`) 
- ✅ Cedar test runner (`cedar_testrunner.sh`)
- ✅ GitHub Actions simulation (`act` or `mock-gha.sh`)
- ✅ Deployment simulation
- ✅ Integration tests
- ✅ Performance validation
- ✅ Test reporting

**If any test fails, DO NOT commit. Fix the issue first.**

**Pre-commit command sequence:**
```bash
# 1. MANDATORY: Run complete test suite
./scripts/run-all-tests.sh

# 2. Only if ALL tests pass:
git add .
git commit -m "descriptive message"
git push
```

**Emergency quick testing (if run-all-tests.sh fails):**
```bash
./scripts/quick-validate.sh && ./scripts/mock-gha.sh
```

This ensures local development mirrors the exact CI/CD pipeline and prevents failed GitHub Actions runs.
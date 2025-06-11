# Project-Specific Instructions for Claude

## Cedar Policy Store Project

This project manages AWS Cedar policies and their deployment via CloudFormation.

### Key Guidelines

1. **CloudFormation Templates**: When working with CloudFormation templates, always follow the rules in `cloudformation-ruleset.md`

2. **Policy Validation**: Before committing any Cedar policy changes, run:
   ```bash
   ./scripts/validate-policies.sh
   ```

3. **Testing**: After making changes, ensure all tests pass:
   ```bash
   ./scripts/run-all-tests.sh
   ```

4. **Deployment**: The project uses GitHub Actions for CI/CD. Changes to main branch trigger automatic deployment.

5. **File Structure**:
   - `policies/` - Cedar policy files
   - `cf/` - CloudFormation templates
   - `tests/` - Test suites for Cedar policies
   - `scripts/` - Utility scripts

### Development Workflow

1. Make changes to policies or CloudFormation templates
2. Validate policies locally
3. Run tests
4. Commit with descriptive message
5. Push to trigger GitHub Actions

### Important Notes

- Always validate Cedar policies before committing
- Follow AWS best practices for IAM and security
- Keep CloudFormation stacks focused and single-purpose
- IAM role `gha-oidc-PaulDuvall-cedar` is configured for GitHub Actions OIDC authentication
- Use local testing scripts before pushing to save time

### CRITICAL: Pre-Push Testing

**ALWAYS run Act locally before pushing changes**:
```bash
act -j validate
```

If Act is not available, at minimum run:
```bash
./scripts/mock-gha.sh
```

See `.development-rules.md` for complete testing requirements.
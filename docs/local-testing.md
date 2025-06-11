# Local Testing Guide

## Recommended Local Testing (No Docker Required)

**Primary approach** - Use the provided bash scripts for fastest and most reliable testing:

```bash
# 1. Instant validation (< 1 second) - for quick feedback during development
./scripts/quick-validate.sh

# 2. Complete CI/CD simulation (~30 seconds) - comprehensive testing
./scripts/run-all-tests.sh

# 3. GitHub Actions workflow simulation (~10 seconds) - mirrors exact CI steps
./scripts/mock-gha.sh
```

### Why Use Bash Scripts Instead of Act?

- ✅ **No Docker dependency** - works immediately
- ✅ **Faster execution** - no container overhead  
- ✅ **Simpler setup** - no configuration required
- ✅ **Same validation logic** - uses identical Cedar policies and tests
- ✅ **Better error output** - clearer debugging information

## Alternative: Using Act (Docker Required)

*Note: The bash scripts above are generally more convenient and faster.*

[Act](https://github.com/nektos/act) can run GitHub Actions locally if you need exact workflow replication.

### Prerequisites
- Docker installed and running
- Act installed (`brew install act` on macOS)

### Basic Usage

```bash
# Test validation job only (recommended)
act -j validate

# Test with verbose output for debugging
act -j validate -v
```

### Limitations with Act

1. **AWS Credentials**: Act can't access GitHub OIDC
   - Skip deploy job: `act -j validate` 
   - Or use local credentials (not recommended)

2. **Performance**: Docker overhead makes it slower than bash scripts

3. **Caching**: GitHub's cache actions don't work locally

## Quick Local Testing Scripts

For even faster feedback, use the local scripts:

### 1. Quick Validation (< 1 second)
```bash
./scripts/quick-validate.sh
```

### 2. Core Cedar Testing (< 5 seconds)
```bash
./scripts/cedar_testrunner.sh
```

### 3. Test Specific Policy
```bash
cedar validate --schema schema.cedarschema --policies policies/s3-write.cedar
```

## Recommended Testing Workflow

1. **During development**: Run `./scripts/quick-validate.sh` for instant feedback
2. **Before committing**: Run `./scripts/run-all-tests.sh` for comprehensive validation
3. **If needed**: Run `./scripts/mock-gha.sh` to simulate exact GitHub Actions steps
4. **Alternative**: Use `act -j validate` only if you need exact Docker-based workflow testing
5. **Deploy**: Push to GitHub when all local tests pass

This approach reduces the feedback loop from 4 minutes to seconds without requiring Docker!

## Available Scripts Summary

| Script | Purpose | Time | Requirements |
|--------|---------|------|--------------|
| `quick-validate.sh` | Instant policy validation | < 1s | Cedar CLI |
| `cedar_testrunner.sh` | Core testing with test suites | ~5s | Cedar CLI |
| `run-all-tests.sh` | Full CI/CD mirror | ~30s | Cedar CLI, AWS CLI, jq |
| `mock-gha.sh` | Simulate GitHub Actions | ~10s | Cedar CLI |
| `install-cedar-fast.sh` | Install Cedar CLI | 10s-3m | Rust/Cargo |
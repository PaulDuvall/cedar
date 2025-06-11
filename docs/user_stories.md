# User Stories

This document captures the key user stories for the Cedar Policy as Code project, organized by user type and workflow stage.

## Developer Stories

### Local Development

**US-001: Quick Policy Validation**
- **As a** developer writing Cedar policies
- **I want to** validate policy syntax in under 1 second
- **So that** I can get immediate feedback during development
- **Acceptance Criteria:**
  - Running `./scripts/quick-validate.sh` completes in < 1 second
  - Validates all policies in `policies/` directory
  - Provides clear success/failure feedback
  - Works without AWS credentials

**US-002: Comprehensive Local Testing**
- **As a** developer before committing code
- **I want to** run the complete test suite locally
- **So that** I can ensure my changes won't break CI/CD
- **Acceptance Criteria:**
  - Running `./scripts/run-all-tests.sh` mirrors the CI/CD pipeline
  - Includes policy validation, CloudFormation validation, and authorization tests
  - Generates test reports consistent with CI
  - Completes in under 30 seconds

**US-003: GitHub Actions Simulation**
- **As a** developer wanting to debug CI issues
- **I want to** simulate the exact GitHub Actions workflow locally
- **So that** I can troubleshoot failures without repeated pushes
- **Acceptance Criteria:**
  - Running `./scripts/mock-gha.sh` simulates the exact CI steps
  - No Docker dependency required
  - Shows same output format as GitHub Actions
  - Handles branch-specific logic (main vs feature branches)

### Policy Development

**US-004: CloudFormation Template Validation**
- **As a** developer creating CloudFormation templates
- **I want to** validate S3 encryption compliance before deployment
- **So that** I can catch security issues at development time
- **Acceptance Criteria:**
  - Running `./scripts/validate-cloudformation-s3.sh` on templates
  - Correctly identifies encrypted vs unencrypted S3 resources
  - Supports AES256 and aws:kms encryption algorithms
  - Provides clear pass/fail results with reasoning

**US-005: Cedar Policy Testing**
- **As a** developer writing authorization policies
- **I want to** test both ALLOW and DENY scenarios
- **So that** I can ensure policies behave correctly for all cases
- **Acceptance Criteria:**
  - Test suites in `tests/s3_encryption_suite/` cover all scenarios
  - Both positive (ALLOW) and negative (DENY) test cases
  - Tests cover shift-left (CloudFormation) and shift-right (runtime) contexts
  - All 12 test cases pass consistently

## DevOps/Platform Engineer Stories

### CI/CD Pipeline

**US-006: Automated Policy Validation**
- **As a** platform engineer maintaining CI/CD
- **I want** automated policy validation on every PR and push
- **So that** only valid policies reach production
- **Acceptance Criteria:**
  - GitHub Actions workflow validates policies on every push
  - Pull requests cannot be merged with failing policy validation
  - Validation uses identical logic to local scripts
  - Caching reduces subsequent runs to ~30 seconds

**US-007: Secure AWS Deployment**
- **As a** platform engineer deploying to AWS
- **I want** credential-free deployment using OIDC
- **So that** no long-term AWS credentials are stored in GitHub
- **Acceptance Criteria:**
  - GitHub Actions uses OIDC for AWS authentication
  - No AWS credentials stored as GitHub secrets
  - Deployment only occurs on main branch pushes
  - CloudFormation stack deployment succeeds

**US-008: Policy Store Management**
- **As a** platform engineer managing Cedar policies
- **I want** automatic policy uploads to AWS Verified Permissions
- **So that** production runtime uses the latest validated policies
- **Acceptance Criteria:**
  - All `.cedar` files are uploaded to Policy Store after successful validation
  - Policy uploads handle both create and update scenarios
  - Failed uploads don't block the pipeline but are logged
  - Policy Store ID is extracted from CloudFormation outputs

### Production Operations

**US-009: Runtime S3 Compliance Checking**
- **As a** platform engineer monitoring production
- **I want** automated S3 bucket compliance validation
- **So that** I can ensure all buckets meet encryption requirements
- **Acceptance Criteria:**
  - Running `./scripts/check-s3-bucket-compliance.sh` validates real buckets
  - Checks both default encryption and bucket policy enforcement
  - Works with existing buckets in any AWS account
  - Provides clear compliance status for each bucket

## Security Engineer Stories

### Policy Governance

**US-010: Shift-Left Security Validation**
- **As a** security engineer implementing policy-as-code
- **I want** the same policies to validate both development artifacts and runtime resources
- **So that** security controls are consistent across the entire SDLC
- **Acceptance Criteria:**
  - Same Cedar policies validate CloudFormation templates and live S3 buckets
  - Validation logic is identical between development and production
  - No gaps between shift-left (development) and shift-right (runtime) security
  - Audit trail shows consistent policy enforcement

**US-011: Production Security Enforcement**
- **As a** security engineer enforcing encryption standards
- **I want** production buckets to require KMS encryption (not just AES256)
- **So that** sensitive production data has stronger encryption controls
- **Acceptance Criteria:**
  - Production environment policies require aws:kms encryption
  - Development/staging environments allow AES256 or KMS
  - Policy enforcement differentiates between environments
  - Clear denial messages when production standards aren't met

### Compliance and Auditing

**US-012: AWS Config Rule Implementation**
- **As a** compliance officer implementing AWS Config rules
- **I want** Cedar policies that match AWS Config Rule `s3-bucket-server-side-encryption-enabled`
- **So that** compliance checks are consistent with security policies
- **Acceptance Criteria:**
  - Cedar policies implement the exact logic of the AWS Config rule
  - Support for AES256, aws:kms, and aws:kms:dsse algorithms
  - Alternative compliance via bucket policy enforcement
  - Clear mapping between Config rule requirements and Cedar policies

## End User Stories

### Application Integration

**US-013: Runtime Authorization Decisions**
- **As an** application developer integrating with Cedar
- **I want** to make authorization decisions using AWS Verified Permissions
- **So that** my application enforces the same policies validated in development
- **Acceptance Criteria:**
  - Application can query Policy Store for authorization decisions
  - Response times are sub-millisecond for typical queries
  - Same policy logic as used in development validation
  - Complete audit trail of all authorization decisions

**US-014: Multi-Environment Policy Management**
- **As an** application architect deploying across environments
- **I want** environment-specific policy enforcement
- **So that** development is flexible while production is secure
- **Acceptance Criteria:**
  - Policies can differentiate between development, staging, and production
  - Production has stricter requirements (e.g., KMS vs AES256)
  - Environment attributes are consistently applied across all contexts
  - Clear documentation of environment-specific requirements

## Documentation and Onboarding Stories

**US-015: Developer Onboarding**
- **As a** new developer joining the project
- **I want** clear documentation and working examples
- **So that** I can quickly understand and contribute to Cedar policies
- **Acceptance Criteria:**
  - `docs/local-testing.md` provides complete setup instructions
  - Example policies demonstrate common patterns
  - Real CloudFormation templates show compliant vs non-compliant examples
  - All commands in documentation work correctly

**US-016: Architecture Understanding**
- **As a** stakeholder evaluating Cedar for policy management
- **I want** clear examples of shift-left and shift-right validation
- **So that** I can understand the value proposition and implementation approach
- **Acceptance Criteria:**
  - `docs/using_cedar.md` explains the complete authorization lifecycle
  - Real-world examples show CloudFormation validation and runtime checking
  - Performance metrics and cost implications are documented
  - Clear comparison with alternative approaches (OPA, custom code)

---

## Comprehensive Implementation & Test Coverage Matrix

| User Story | Status | Unit Tests | Integration Tests | ATDD Tests | E2E Tests | Performance | Implementation | ATDD Traceability |
|------------|--------|------------|------------------|------------|-----------|-------------|----------------|-------------------|
| **US-001** | ✅ Done | ✅ `quick-validate.sh` | ✅ Policy syntax validation | ⚪ N/A | ✅ Local dev workflow | ✅ <1s requirement | [`scripts/quick-validate.sh`](../scripts/quick-validate.sh) | Command execution timing |
| **US-002** | ✅ Done | ✅ Individual scripts | ✅ `run-all-tests.sh` | ⚪ N/A | ✅ Complete pipeline | ✅ <30s requirement | [`scripts/run-all-tests.sh`](../scripts/run-all-tests.sh) | Full test suite integration |
| **US-003** | ✅ Done | ✅ `mock-gha.sh` | ✅ CI simulation | ⚪ N/A | ✅ Act integration | ✅ CI/CD timing | [`scripts/mock-gha.sh`](../scripts/mock-gha.sh) | GitHub Actions parity |
| **US-004** | ✅ Done | ✅ CF validation script | ✅ Template parsing | ⚪ N/A | ✅ S3 encryption validation | ✅ Validation speed | [`scripts/validate-cloudformation-s3.sh`](../scripts/validate-cloudformation-s3.sh) | Template validation coverage |
| **US-005** | ✅ Done | ✅ Policy syntax check | ✅ `cedar_testrunner.sh` | ⚪ N/A | ✅ 12 test scenarios | ✅ Test execution time | [`scripts/cedar_testrunner.sh`](../scripts/cedar_testrunner.sh) | ALLOW/DENY test scenarios |
| **US-006** | ✅ Done | ✅ GitHub Actions steps | ✅ Workflow validation | ⚪ N/A | ✅ PR/push automation | ✅ ~30s caching | [`.github/workflows/cedar-check.yml`](../.github/workflows/cedar-check.yml) | Automated CI/CD validation |
| **US-007** | ✅ Done | ✅ OIDC configuration | ✅ AWS authentication | ⚪ N/A | ✅ Secure deployment | ✅ Credential-free | [`.github/workflows/cedar-check.yml`](../.github/workflows/cedar-check.yml) | Secure OIDC deployment |
| **US-008** | ✅ Done | ✅ Policy upload logic | ✅ AVP integration | ⚪ N/A | ✅ Policy store mgmt | ✅ Upload performance | [`.github/workflows/cedar-check.yml`](../.github/workflows/cedar-check.yml) | AVP policy management |
| **US-009** | ✅ Done | ✅ Compliance checker | ✅ S3 API integration | ⚪ N/A | ✅ Real bucket testing | ✅ Runtime validation | [`scripts/check-s3-bucket-compliance.sh`](../scripts/check-s3-bucket-compliance.sh) | Runtime compliance checking |
| **US-010** | ✅ Done | ✅ Policy consistency | ✅ Multi-context validation | ✅ **ATDD Suite** | ✅ Shift-left/right | ✅ Sub-second validation | [`policies/s3-encryption-enforcement.cedar`](../policies/s3-encryption-enforcement.cedar) | **Comprehensive ATDD**: [`shift_left_security_validation.feature`](../tests/atdd/shift_left_security_validation.feature), [`steps`](../tests/atdd/steps/shift_left_validation_steps.py), [`runner`](../tests/atdd/run_atdd_tests.sh) |
| **US-011** | ✅ Done | ✅ Environment logic | ✅ KMS enforcement | ✅ **ATDD Coverage** | ✅ Prod vs dev policies | ✅ Policy evaluation | [`policies/s3-encryption-enforcement.cedar`](../policies/s3-encryption-enforcement.cedar) | **ATDD Scenarios**: Environment-aware enforcement via [`feature`](../tests/atdd/shift_left_security_validation.feature#L67) |
| **US-012** | ✅ Done | ✅ Config rule logic | ✅ AWS Config alignment | ✅ **ATDD Coverage** | ✅ Compliance validation | ✅ Rule evaluation | [`policies/s3-encryption-enforcement.cedar`](../policies/s3-encryption-enforcement.cedar) | **ATDD Scenarios**: AWS Config rule alignment via [`feature`](../tests/atdd/shift_left_security_validation.feature) |
| **US-013** | 🟡 Partial | 🟡 Documentation only | 🟡 API examples | ⚪ Planned | 🟡 SDK integration | 🟡 Sub-ms requirement | [`docs/using_cedar.md`](using_cedar.md) examples | API integration documented |
| **US-014** | ✅ Done | ✅ Environment attrs | ✅ Multi-env policies | ✅ **ATDD Coverage** | ✅ Environment testing | ✅ Policy selection | [`policies/s3-encryption-enforcement.cedar`](../policies/s3-encryption-enforcement.cedar) | **ATDD Scenarios**: Multi-environment support via [`feature`](../tests/atdd/shift_left_security_validation.feature) |
| **US-015** | ✅ Done | ✅ Doc validation | ✅ Example testing | ⚪ N/A | ✅ Onboarding flow | ✅ Setup time | [`docs/local-testing.md`](local-testing.md) | Developer onboarding complete |
| **US-016** | ✅ Done | ✅ Architecture docs | ✅ Example validation | ⚪ N/A | ✅ Complete examples | ✅ Understanding time | [`docs/using_cedar.md`](using_cedar.md) | Architecture documentation |

### Status Legend
- ✅ **Done**: Fully implemented and tested
- 🟡 **Partial**: Partially implemented or documented only
- 🔴 **Blocked**: Implementation blocked by dependencies
- ⚪ **Not Started**: Not yet implemented

### Implementation Completeness
- **Core Functionality**: 15/16 user stories fully implemented (93.75%)
- **Testing Infrastructure**: All test frameworks and scripts working
- **Documentation**: Complete with working examples
- **CI/CD**: Full automation with security best practices
- **ATDD Coverage**: End-to-end acceptance testing for critical user stories

---

## ATDD Test Traceability Details

### US-010: Shift-Left Security Validation - Detailed ATDD Mapping

**Primary ATDD Test**: `tests/atdd/shift_left_security_validation.feature`

| Acceptance Criteria | ATDD Test Scenario | Verification Method |
|-------------------|-------------------|-------------------|
| Same Cedar policies validate CloudFormation templates and live S3 buckets | `Validate CloudFormation template with encrypted S3 bucket during development` + `Validate live S3 bucket with encryption in production` | Behave scenarios with fixtures |
| Validation logic is identical between development and production | `Identical policy logic across development and production contexts` | Policy consistency verification |
| No gaps between shift-left and shift-right security | `Seamless integration in CI/CD pipeline` | End-to-end workflow testing |
| Audit trail shows consistent policy enforcement | `Consistent audit trail across SDLC stages` | Decision logging verification |

**Supporting Test Files**:
- **Feature Definition**: `tests/atdd/shift_left_security_validation.feature`
- **Step Definitions**: `tests/atdd/steps/shift_left_validation_steps.py`
- **Test Fixtures**: 
  - `tests/atdd/fixtures/cloudformation_templates/encrypted-s3-bucket.yaml`
  - `tests/atdd/fixtures/cloudformation_templates/unencrypted-s3-bucket.yaml`
  - `tests/atdd/fixtures/s3_entities/encrypted_bucket_entity.json`
  - `tests/atdd/fixtures/s3_entities/unencrypted_bucket_entity.json`
- **Test Runner**: `tests/atdd/support/cedar_policy_runner.py`
- **Execution Script**: `tests/atdd/run_atdd_tests.sh`

**Integration Points**:
- **Comprehensive Test Suite**: `./scripts/run-all-tests.sh` includes ATDD execution
- **CI/CD Integration**: Act simulation tests the complete GitHub Actions workflow
- **Performance Validation**: ATDD tests verify sub-second validation requirements

### ATDD Test Execution Commands

**Full Test Suite (includes ATDD)**:
```bash
./scripts/run-all-tests.sh        # Complete test suite with ATDD integration
```

**ATDD-Specific Execution**:
```bash
./tests/atdd/run_atdd_tests.sh                    # All ATDD scenarios
./tests/atdd/run_atdd_tests.sh -t @shift-left     # CloudFormation validation
./tests/atdd/run_atdd_tests.sh -t @consistency    # Policy consistency verification
./tests/atdd/run_atdd_tests.sh -t @performance    # Timing requirements
```

**CI/CD Integration**:
- **Local Development**: `./scripts/run-all-tests.sh` includes ATDD execution
- **GitHub Actions**: `.github/workflows/cedar-check.yml` runs validation pipeline
- **Act Simulation**: `act -j validate` tests the complete workflow locally
- **ATDD Reports**: Generated in `tests/atdd/reports/` for traceability

---

## Story Mapping

### Epic: Local Development Workflow
- US-001: Quick Policy Validation
- US-002: Comprehensive Local Testing  
- US-003: GitHub Actions Simulation
- US-004: CloudFormation Template Validation
- US-005: Cedar Policy Testing

### Epic: Production Deployment Pipeline
- US-006: Automated Policy Validation
- US-007: Secure AWS Deployment
- US-008: Policy Store Management
- US-009: Runtime S3 Compliance Checking

### Epic: Security and Compliance
- US-010: Shift-Left Security Validation
- US-011: Production Security Enforcement
- US-012: AWS Config Rule Implementation

### Epic: Runtime Integration
- US-013: Runtime Authorization Decisions
- US-014: Multi-Environment Policy Management

### Epic: Documentation and Adoption
- US-015: Developer Onboarding
- US-016: Architecture Understanding

---

*Last updated: 2025-01-11*
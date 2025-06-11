[![GitHub Actions Workflow Status](https://github.com/PaulDuvall/cedar/actions/workflows/cedar-check.yml/badge.svg)](https://github.com/PaulDuvall/cedar/actions/workflows/cedar-check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Python](https://img.shields.io/badge/python-3.11-blue.svg)
![GitHub last commit](https://img.shields.io/github/last-commit/PaulDuvall/cedar)

# Cedar Policy as Code for AWS ⚡

This repository demonstrates enterprise-grade authorization using AWS Cedar policies with a complete CI/CD pipeline. It showcases shift-left security practices, automated testing, and secure deployments using GitHub OIDC authentication.

## 🎯 What This Repository Provides

- **Production-ready Cedar policies** for fine-grained access control
- **Automated CI/CD pipeline** with GitHub Actions (30-second validation)
- **Local testing tools** for instant feedback during development
- **AWS Verified Permissions integration** for runtime authorization
- **Zero-credential deployment** using GitHub OIDC authentication

## 🔐 Security First

- **No Long-term AWS Credentials**: Uses GitHub OIDC for secure, short-lived AWS credentials via [gha-aws-oidc-bootstrap](https://github.com/PaulDuvall/gha-oidc-bootstrap)
- **Least-Privilege IAM Policies**: Fine-grained permissions for each workflow
- **Automated Policy Validation**: Every pull request is validated before merging
- **Infrastructure as Code**: All AWS resources defined in CloudFormation

## 🚀 Getting Started

### Prerequisites
- AWS Account with appropriate permissions
- GitHub repository with GitHub Actions enabled
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [Rust](https://www.rust-lang.org/tools/install) for local development
- Python 3.11+ installed

### 1. Setup OIDC Authentication

This repository uses GitHub OIDC for secure, credential-free AWS authentication. Set up OIDC using the automated bootstrap process with the Cedar repository's optimized IAM policies.

#### Prerequisites
- AWS CLI configured with appropriate permissions
- GitHub CLI (`gh`) installed (optional, for token creation)
- Both repositories cloned locally

#### Step-by-Step Setup

**Step 1: Clone and Prepare Repositories**

```bash
# Clone both repositories side by side
git clone https://github.com/PaulDuvall/gha-aws-oidc-bootstrap.git
git clone https://github.com/PaulDuvall/cedar.git

# Navigate to the OIDC bootstrap directory
cd gha-aws-oidc-bootstrap
```

**Step 2: Create GitHub Personal Access Token**

```bash
# Option 1: Use GitHub CLI (recommended)
gh auth login
GITHUB_TOKEN=$(gh auth token)

# Option 2: Manual token creation
# Go to: https://github.com/settings/tokens?type=beta
# Create a fine-grained personal access token with these permissions for the cedar repository:
# - Actions: Read & Write
# - Variables: Read & Write  
# - Metadata: Read
# Then set: export GITHUB_TOKEN=github_pat_XXXXXXXXXXXXXXXXXXXX
```

**Step 3: Run the OIDC Setup**

```bash
# Run the automated OIDC setup with Cedar-specific configuration
# Point directly to the Cedar repository's IAM policies directory
bash run.sh \
  --github-org PaulDuvall \
  --github-repo cedar \
  --region us-east-1 \
  --stack-name cedar-gha-oidc \
  --github-token $GITHUB_TOKEN \
  --policies-dir /path/to/your/cedar/aws_iam_policies
```

**Step 4: Verify Setup**

```bash
# The setup script will output the role ARN, but you can also verify:
aws iam get-role --role-name gha-oidc-PaulDuvall-cedar

# Check that the GitHub repository variable was set
gh variable list --repo PaulDuvall/cedar
# Should show: GHA_OIDC_ROLE_ARN with the role ARN
```

**What this does:**
- ✅ Creates GitHub OIDC provider in AWS (if not exists)
- ✅ Deploys CloudFormation stack: `cedar-gha-oidc`
- ✅ Creates IAM role with least-privilege policies from `aws_iam_policies/`
- ✅ Automatically sets `GHA_OIDC_ROLE_ARN` variable in GitHub repository
- ✅ Configures repository-specific trust policy for secure access
- ✅ Directly references Cedar's IAM policies without copying files

#### Understanding the aws_iam_policies Directory

The `aws_iam_policies/` directory contains carefully crafted IAM policies that follow the principle of least privilege:

```bash
aws_iam_policies/
├── cfn.json                 # CloudFormation stack management permissions
├── iam.json                 # IAM role management for service roles
├── kms.json                 # KMS key operations for S3 encryption demos
├── s3.json                  # S3 bucket operations and compliance checking
├── sts.json                 # STS identity operations for OIDC
├── verifiedpermissions.json # AWS Verified Permissions management
└── README.md               # Detailed usage and troubleshooting guide
```

**Key Features of These Policies:**
- **Resource Scoping**: All policies use `cedar-*` resource patterns for security
- **Action Minimization**: Only the specific actions needed by Cedar workflows
- **Account ID Integration**: S3 policies support dynamic account ID inclusion
- **Service-Specific**: Each file contains permissions for one AWS service
- **OIDC Compatible**: Designed specifically for GitHub Actions OIDC authentication

**Policy Highlights:**
- **90% fewer S3 permissions** compared to `s3:*` wildcard
- **85% fewer IAM permissions** compared to full IAM access
- **70% fewer CloudFormation actions** compared to full CFN permissions
- **Supports dynamic resource creation** with account ID and unique identifiers

When you specify the `--policies-dir` parameter pointing to these policies, the gha-aws-oidc-bootstrap tool automatically reads and attaches them to the OIDC role, providing exactly the permissions needed for Cedar's workflows while maintaining maximum security.

#### Troubleshooting OIDC Setup

**Common Issues:**

1. **Incorrect policies directory path:**
   ```bash
   # Verify the Cedar repository location and policies directory
   ls /path/to/your/cedar/aws_iam_policies/
   # Should list: cfn.json, iam.json, kms.json, s3.json, sts.json, verifiedpermissions.json
   
   # Make sure you're using the absolute path to the policies directory
   # Example: --policies-dir /Users/username/Code/cedar/aws_iam_policies
   ```

2. **GitHub token permissions:**
   ```bash
   # Test token permissions
   gh auth status
   gh variable list --repo PaulDuvall/cedar
   ```

3. **AWS permissions issues:**
   ```bash
   # Verify your AWS credentials have permission to create IAM roles
   aws sts get-caller-identity
   aws iam list-roles --max-items 1  # Test IAM access
   ```

4. **Role ARN not set in GitHub:**
   ```bash
   # Manually set the variable if automatic setting failed
   ROLE_ARN=$(aws iam get-role --role-name gha-oidc-PaulDuvall-cedar --query 'Role.Arn' --output text)
   gh variable set GHA_OIDC_ROLE_ARN --body "$ROLE_ARN" --repo PaulDuvall/cedar
   ```

**Success Indicators:**
- ✅ CloudFormation stack `gha-aws-oidc-paulduvall-cedar` exists
- ✅ IAM role `gha-oidc-PaulDuvall-cedar` has 6 attached policies
- ✅ GitHub repository variable `GHA_OIDC_ROLE_ARN` is set
- ✅ GitHub Actions can assume the role and deploy resources

### 2. Local Development Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/PaulDuvall/cedar.git
   cd cedar
   ```

2. Install Cedar CLI and dependencies:
   ```bash
   # Make install script executable
   chmod +x scripts/*.sh
   
   # Install Cedar CLI (optimized installer)
   ./scripts/install-cedar-fast.sh
   ```

3. Test the setup:
   ```bash
   # Verify Cedar CLI installation
   cedar --version
   
   # Run quick validation
   ./scripts/quick-validate.sh
   ```

### 3. Verify OIDC Configuration

After running the OIDC setup, verify the configuration:

```bash
# Check that GitHub repository variable was set
gh variable list --repo PaulDuvall/cedar
# Should show: GHA_OIDC_ROLE_ARN with the role ARN

# Verify the IAM role has the correct policies attached
aws iam list-attached-role-policies --role-name gha-oidc-PaulDuvall-cedar
# Should show 6 policies from aws_iam_policies/ directory

# Test GitHub Actions can assume the role (optional)
# This will be verified when you push code and trigger the workflow
```

**No additional secrets required!** The OIDC setup automatically configures:
- ✅ **GHA_OIDC_ROLE_ARN** repository variable (set automatically)
- ✅ AWS OIDC provider integration  
- ✅ IAM role with least-privilege policies from `aws_iam_policies/`
- ✅ Trust relationship allowing only the Cedar repository to assume the role

### 4. First Deployment

The repository is ready to deploy! GitHub Actions will automatically:

1. **On Pull Requests**: Validate Cedar policies and run tests
2. **On Main Branch Push**: Deploy to AWS and upload policies

```bash
# Test locally first
./scripts/run-all-tests.sh

# Push to trigger deployment
git push origin main
```

GitHub Actions will:
- ✅ Validate all Cedar policies 
- ✅ Deploy CloudFormation stack to AWS
- ✅ Upload Cedar policies to AWS Verified Permissions
- ✅ Run S3 compliance tests against real buckets

## 🚀 How the GitHub Actions Workflow Works

When you push code to this repository, the following automated process occurs:

### 1. Policy Validation (On Every Push)
- Cedar CLI validates all policies in the `cedar_policies/` directory
- Ensures policies are syntactically correct and comply with the schema
- First run: ~2-3 minutes (builds Cedar CLI with Rust toolchain)
- Subsequent runs: ~30 seconds (uses cached binary and Cargo registry)
- Smart caching strategy for both Cedar binary and Cargo dependencies

### 2. Infrastructure Deployment (On Main Branch)
- Creates/updates CloudFormation stack with:
  - **AWS Verified Permissions Policy Store**: A managed service for storing and evaluating Cedar policies
  - **IAM Role**: For GitHub Actions to deploy resources securely using OIDC
  - **Cedar Policies**: Uploaded to the Policy Store for runtime evaluation

### 3. Policy Upload
- Each `.cedar` file in `cedar_policies/` is uploaded to AWS Verified Permissions
- Policies are ready for real-time authorization decisions

## 🧪 Testing Cedar Policies Locally

### Quick Local Validation

This project provides 5 focused scripts for different testing needs:

```bash
# 1. Instant validation (< 1 second) - for quick feedback during development
./scripts/quick-validate.sh

# 2. Comprehensive test suite - mirrors the full CI/CD pipeline locally
./scripts/run-all-tests.sh
# Includes: prerequisites check, policy validation, CloudFormation validation,
# authorization tests, and generates a test report

# 3. Core Cedar testing - runs all policy tests with detailed output
./scripts/cedar_testrunner.sh

# 4. GitHub Actions simulation - see exactly what CI will do (no Docker needed)
./scripts/mock-gha.sh

# 5. Install Cedar CLI - smart installer with optimization
./scripts/install-cedar-fast.sh
```

For testing with Docker:
```bash
# Test GitHub Actions locally with Act (requires Docker)
act -j validate
```

See [docs/local-testing.md](docs/local-testing.md) for detailed local testing instructions.

### Understanding the Example Policy

The example S3 write policy:
```cedar
// Allow PutObject if the user's department is operations
permit (
  principal,
  action,
  resource
)
when {
  principal.department == "operations" &&
  action == CedarPolicyStore::Action::"s3:PutObject" &&
  resource == CedarPolicyStore::Bucket::"project-artifacts"
};
```

This policy **ALLOWS** S3 PutObject operations only when:
- The user belongs to the "operations" department
- The action is specifically "s3:PutObject"
- The target bucket is "project-artifacts"

### Testing Authorization Decisions

1. **Install Cedar CLI**:
   ```bash
   ./scripts/install-cedar-fast.sh
   ```

2. **Create Test Scenarios**:

   **ALLOW Scenario** - Operations user writing to project-artifacts:
   ```bash
   # Create test request
   cat > test-allow.json << 'EOF'
   {
     "principal": {
       "type": "CedarPolicyStore::User",
       "id": "alice"
     },
     "action": {
       "type": "CedarPolicyStore::Action",
       "id": "s3:PutObject"
     },
     "resource": {
       "type": "CedarPolicyStore::Bucket",
       "id": "project-artifacts"
     }
   }
   EOF

   # Create entities (users with attributes)
   cat > entities.json << 'EOF'
   [
     {
       "uid": {
         "type": "CedarPolicyStore::User",
         "id": "alice"
       },
       "attrs": {
         "department": "operations"
       }
     },
     {
       "uid": {
         "type": "CedarPolicyStore::User",
         "id": "bob"
       },
       "attrs": {
         "department": "marketing"
       }
     }
   ]
   EOF

   # Test the ALLOW scenario
   cedar authorize \
     --policies cedar_policies/ \
     --entities entities.json \
     --request-json test-allow.json
   # Result: ALLOW ✅
   ```

   **DENY Scenarios**:
   ```bash
   # Scenario 1: Wrong department (marketing user)
   cat > test-deny-dept.json << 'EOF'
   {
     "principal": {
       "type": "CedarPolicyStore::User",
       "id": "bob"
     },
     "action": {
       "type": "CedarPolicyStore::Action",
       "id": "s3:PutObject"
     },
     "resource": {
       "type": "CedarPolicyStore::Bucket",
       "id": "project-artifacts"
     }
   }
   EOF

   cedar authorize \
     --policies cedar_policies/ \
     --entities entities.json \
     --request-json test-deny-dept.json
   # Result: DENY ❌ (bob is in marketing, not operations)

   # Scenario 2: Wrong bucket
   cat > test-deny-bucket.json << 'EOF'
   {
     "principal": {
       "type": "CedarPolicyStore::User",
       "id": "alice"
     },
     "action": {
       "type": "CedarPolicyStore::Action",
       "id": "s3:PutObject"
     },
     "resource": {
       "type": "CedarPolicyStore::Bucket",
       "id": "other-bucket"
     }
   }
   EOF

   cedar authorize \
     --policies cedar_policies/ \
     --entities entities.json \
     --request-json test-deny-bucket.json
   # Result: DENY ❌ (wrong bucket)
   ```

### Using with AWS Services

Once deployed to AWS Verified Permissions, Cedar policies can be integrated with:

1. **API Gateway**: Add authorization to your APIs
2. **Lambda Functions**: Make authorization decisions in your code
3. **Application Code**: Use AWS SDK to evaluate policies

Example with AWS SDK:
```python
import boto3

avp = boto3.client('verifiedpermissions')

# Check if alice can upload to S3
response = avp.is_authorized(
    policyStoreId='your-policy-store-id',
    principal={'entityType': 'CedarPolicyStore::User', 'entityId': 'alice'},
    action={'actionType': 'CedarPolicyStore::Action', 'actionId': 's3:PutObject'},
    resource={'entityType': 'CedarPolicyStore::Bucket', 'entityId': 'project-artifacts'},
    entities={
        'entityList': [{
            'identifier': {
                'entityType': 'CedarPolicyStore::User',
                'entityId': 'alice'
            },
            'attributes': {
                'department': {'string': 'operations'}
            }
        }]
    }
)

if response['decision'] == 'ALLOW':
    # Proceed with S3 upload
    s3.put_object(...)
```

## 🔍 Manual Verification: Testing Cedar Policies with Real AWS Resources

This section walks through manually verifying that Cedar policies are properly securing AWS resources.

### Prerequisites

1. Deploy the stack (happens automatically when pushing to main):
   ```bash
   git push origin main
   # Wait for GitHub Actions to complete
   ```

2. Get your Policy Store ID:
   ```bash
   aws cloudformation describe-stacks \
     --stack-name cedar-policy-store-PaulDuvall-cedar \
     --query 'Stacks[0].Outputs[?OutputKey==`PolicyStoreId`].OutputValue' \
     --output text
   ```

### Step-by-Step Verification

#### 1. Verify Policy Store Creation

```bash
# List all policy stores
aws verifiedpermissions list-policy-stores

# Get details of your policy store
POLICY_STORE_ID=$(aws cloudformation describe-stacks \
  --stack-name cedar-policy-store-PaulDuvall-cedar \
  --query 'Stacks[0].Outputs[?OutputKey==`PolicyStoreId`].OutputValue' \
  --output text)

aws verifiedpermissions get-policy-store \
  --policy-store-id $POLICY_STORE_ID
```

#### 2. List Deployed Policies

```bash
# See all policies in the store
aws verifiedpermissions list-policies \
  --policy-store-id $POLICY_STORE_ID
```

#### 3. Test Authorization Decisions

**Scenario 1: Operations User → Project Artifacts (SHOULD ALLOW)**

```bash
# Test: Alice (operations) trying to upload to project-artifacts
aws verifiedpermissions is-authorized \
  --policy-store-id $POLICY_STORE_ID \
  --principal entityType=CedarPolicyStore::User,entityId=alice \
  --action actionType=CedarPolicyStore::Action,actionId=s3:PutObject \
  --resource entityType=CedarPolicyStore::Bucket,entityId=project-artifacts \
  --entities '{
    "entityList": [{
      "identifier": {
        "entityType": "CedarPolicyStore::User",
        "entityId": "alice"
      },
      "attributes": {
        "department": {"string": "operations"}
      }
    }]
  }'
```

Expected output:
```json
{
    "decision": "ALLOW",
    "determiningPolicies": [{"policyId": "..."}],
    "errors": []
}
```

**Scenario 2: Marketing User → Project Artifacts (SHOULD DENY)**

```bash
# Test: Bob (marketing) trying to upload to project-artifacts
aws verifiedpermissions is-authorized \
  --policy-store-id $POLICY_STORE_ID \
  --principal entityType=CedarPolicyStore::User,entityId=bob \
  --action actionType=CedarPolicyStore::Action,actionId=s3:PutObject \
  --resource entityType=CedarPolicyStore::Bucket,entityId=project-artifacts \
  --entities '{
    "entityList": [{
      "identifier": {
        "entityType": "CedarPolicyStore::User",
        "entityId": "bob"
      },
      "attributes": {
        "department": {"string": "marketing"}
      }
    }]
  }'
```

Expected output:
```json
{
    "decision": "DENY",
    "determiningPolicies": [],
    "errors": []
}
```

#### 4. Create S3 Integration Test

To test with actual S3 operations:

```bash
# Create test bucket (if it doesn't exist)
aws s3 mb s3://project-artifacts-$RANDOM

# Create a Lambda function that uses Cedar for authorization
cat > lambda-cedar-auth.py << 'EOF'
import boto3
import json

avp = boto3.client('verifiedpermissions')
s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Extract user info from event
    user_id = event['user_id']
    department = event['department']
    bucket = event['bucket']
    key = event['key']
    
    # Check authorization with Cedar
    response = avp.is_authorized(
        policyStoreId=os.environ['POLICY_STORE_ID'],
        principal={'entityType': 'CedarPolicyStore::User', 'entityId': user_id},
        action={'actionType': 'CedarPolicyStore::Action', 'actionId': 's3:PutObject'},
        resource={'entityType': 'CedarPolicyStore::Bucket', 'entityId': bucket},
        entities={
            'entityList': [{
                'identifier': {
                    'entityType': 'CedarPolicyStore::User',
                    'entityId': user_id
                },
                'attributes': {
                    'department': {'string': department}
                }
            }]
        }
    )
    
    if response['decision'] == 'ALLOW':
        # Perform S3 operation
        s3.put_object(Bucket=bucket, Key=key, Body='Authorized by Cedar!')
        return {'statusCode': 200, 'body': 'Upload successful'}
    else:
        return {'statusCode': 403, 'body': 'Access denied by Cedar'}
EOF
```

### Troubleshooting

1. **View Policy Details**:
   ```bash
   aws verifiedpermissions get-policy \
     --policy-store-id $POLICY_STORE_ID \
     --policy-id <policy-id-from-list>
   ```

2. **Check CloudFormation Events** (if deployment failed):
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name cedar-policy-store-PaulDuvall-cedar \
     --max-items 10
   ```

3. **Enable Decision Logging**:
   - Cedar decisions can be logged to CloudWatch for auditing
   - Check CloudWatch Logs for authorization decisions

### What Cedar is Protecting

In this example setup, Cedar policies control:
- **Who**: Users identified by their ID and department attribute
- **What**: S3 PutObject operations 
- **Where**: Specific S3 buckets (e.g., project-artifacts)

The policies ensure that only users from the "operations" department can upload files to the project-artifacts bucket, providing fine-grained access control without modifying IAM policies.

## 🔄 Cedar Across the Software Development Lifecycle

Cedar enables a unified approach to authorization that spans the entire SDLC, implementing both shift-left (preventative) and shift-right (detective) security controls using the same policy language and definitions.

### Shift-Left: Preventative Controls

**Development Phase**
- **Policy Authoring**: Developers write Cedar policies alongside application code, defining authorization rules that match business requirements
- **Local Testing**: Using Cedar CLI and test frameworks, developers validate policies against test cases before committing code
- **IDE Integration**: Static analysis tools can validate Cedar syntax and schema compliance in real-time during development

**CI/CD Pipeline**
- **Pull Request Validation**: Every PR triggers automated Cedar policy validation, ensuring syntax correctness and schema compliance
- **Policy Testing**: Automated test suites verify that policies allow intended access patterns and deny unauthorized ones
- **Integration Testing**: Policies are tested against mock services to verify behavior before deployment
- **Compliance Checks**: Policies are validated against security and compliance requirements defined in Cedar

**Pre-Deployment Gates**
- **Policy Simulation**: Before deployment, Cedar's policy engine simulates authorization decisions against production-like scenarios
- **Security Reviews**: Automated tools analyze policies for overly permissive rules or potential security gaps
- **Change Impact Analysis**: Diff tools show exactly how policy changes will affect access patterns

### Shift-Right: Detective Controls

**Runtime Enforcement**
- **API Gateway Integration**: Cedar policies enforce authorization at API endpoints, evaluating each request in real-time
- **Microservice Authorization**: Services use Cedar to make fine-grained authorization decisions based on request attributes
- **Dynamic Evaluation**: Policies consider runtime context like time of day, location, or resource state

**Monitoring & Observability**
- **Decision Logging**: Every Cedar authorization decision is logged with full context for audit trails
- **Policy Analytics**: Dashboards show which policies are triggered most frequently and their allow/deny patterns
- **Anomaly Detection**: Unusual authorization patterns trigger alerts for security teams

**Continuous Compliance**
- **Real-time Auditing**: Cedar decision logs provide evidence of policy enforcement for compliance requirements
- **Policy Drift Detection**: Monitoring ensures deployed policies match approved versions in source control
- **Access Reviews**: Regular analysis of Cedar logs identifies unused permissions that can be removed

### Unified Policy Language Benefits

Using Cedar across the entire SDLC provides several key advantages:

1. **Single Source of Truth**: Authorization rules are defined once and enforced consistently across all stages
2. **Reduced Context Switching**: Teams use the same policy language for testing, deployment, and runtime
3. **Faster Feedback Loops**: Issues are caught early in development rather than in production
4. **Simplified Compliance**: One set of policies to audit and maintain for regulatory requirements
5. **DevSecOps Integration**: Security becomes part of the development workflow, not a separate phase

### Example Workflow

1. **Developer** writes a Cedar policy to restrict S3 access to specific departments
2. **Local Tests** verify the policy works as intended using test cases
3. **CI Pipeline** validates syntax and runs comprehensive test suites
4. **Security Team** reviews policy changes through automated PR checks
5. **Deployment** pushes policies to Amazon Verified Permissions
6. **Runtime** enforces the same policies for actual S3 API calls
7. **Monitoring** tracks all authorization decisions for compliance
8. **Auditing** uses Cedar logs to prove policy enforcement

This approach ensures that security and compliance requirements are embedded throughout the development process, not bolted on afterward.

## 🧪 Testing Framework

This project includes a comprehensive testing framework for Cedar policies with both local and CI/CD testing capabilities.

### Test Structure

```
.
├── cedar_policies/            # Cedar policy definitions
│   ├── example.cedar         # Example policy
│   └── s3-access.cedar       # S3 access policy
├── tests/
│   ├── example_suite/        # Test suite for example policies
│   │   ├── ALLOW/           # Tests that should be allowed
│   │   │   └── view_document.json
│   │   └── DENY/            # Tests that should be denied
│   │       └── edit_document.json
│   └── fixtures/
│       └── entities.json     # Test entities and relationships
└── scripts/
    └── cedar_testrunner.sh   # Enhanced test runner
```

### Local Development

1. **Install Dependencies**
   ```bash
   # Run the comprehensive install script
   ./scripts/install-dependencies.sh
   
   # Source your shell profile to update PATH
   source ~/.bashrc  # or ~/.zshrc for macOS
   ```

2. **Run Tests Locally**
   ```bash
   # Run the same tests as CI/CD
   ./scripts/run-all-tests.sh
   
   # Or run just the Cedar validation tests
   ./scripts/cedar_testrunner.sh
   ```

3. **CI/CD Parity**
   
   The local development environment mirrors the CI/CD pipeline exactly:
   
   | Component | Local Script | CI/CD Step |
   |-----------|-------------|------------|
   | Install Dependencies | `install-dependencies.sh` | GitHub Actions setup |
   | Cedar Validation | `cedar_testrunner.sh` | Validate Policies job |
   | Deploy Simulation | `run-all-tests.sh` | Deploy job (dry-run) |
   | Integration Tests | `run-all-tests.sh` | Deploy job tests |

3. **Writing Tests**
   - Create test cases in the appropriate `ALLOW` or `DENY` directories
   - Test files should be in JSON format with the following structure:
     ```json
     {
       "principal": "User::\"alice\"",
       "action": "Action::\"view\"",
       "resource": "Resource::\"document1\"",
       "context": {}
     }
     ```


## 🔐 IAM Policies and Security

This repository includes optimized IAM policies in `aws_iam_policies/` that follow the principle of least privilege:

### Policy Files
- **`cfn.json`**: CloudFormation permissions (13 actions vs all CFN actions)
- **`verifiedpermissions.json`**: AWS Verified Permissions management (12 actions vs all AVP actions)
- **`s3.json`**: S3 bucket operations and compliance checking (13 actions vs all S3 actions)
- **`iam.json`**: IAM role management for CloudFormation (11 actions vs all IAM actions)
- **`kms.json`**: KMS key operations for encrypted buckets
- **`sts.json`**: STS identity operations and OIDC authentication

### Security Improvements
- **~90% reduction** in S3 permissions 
- **~85% reduction** in IAM permissions
- **~70% reduction** in CloudFormation permissions
- **~60% reduction** in Verified Permissions actions

These policies are automatically used by the OIDC setup process and provide exactly the permissions needed for this Cedar repository.

## 🏗️ Project Structure

```
.
├── .github/workflows/
│   └── cedar-check.yml           # GitHub Actions CI/CD workflow
├── aws_iam_policies/             # Optimized IAM policies for OIDC setup
│   ├── cfn.json                 # CloudFormation permissions
│   ├── verifiedpermissions.json # AWS Verified Permissions  
│   ├── s3.json                  # S3 operations and compliance
│   ├── iam.json                 # IAM role management
│   ├── kms.json                 # KMS key operations
│   └── sts.json                 # STS and OIDC permissions
├── cf/
│   └── avp-stack.yaml           # CloudFormation template for AVP
├── docs/                        # Documentation
│   ├── local-testing.md         # Local development guide
│   ├── using_cedar.md           # Cedar policy guide
│   └── user_stories.md          # User stories and implementation matrix
├── examples/
│   ├── cloudformation/          # CloudFormation templates for demos
│   └── README.md                # Real-world examples guide
├── cedar_policies/              # Cedar policy definitions
│   ├── example.cedar            # Example authorization policy
│   ├── s3-encryption-enforcement.cedar # S3 encryption compliance
│   └── s3-write.cedar           # S3 write permissions
├── scripts/                     # Local development and testing scripts
│   ├── cedar_testrunner.sh      # Core Cedar test runner
│   ├── check-s3-bucket-compliance.sh # S3 compliance checker
│   ├── install-cedar-fast.sh    # Optimized Cedar CLI installer
│   ├── mock-gha.sh              # GitHub Actions simulation
│   ├── quick-validate.sh        # Instant policy validation
│   ├── run-all-tests.sh         # Comprehensive test suite
│   └── validate-cloudformation-s3.sh # CloudFormation validation
├── tests/                       # Test suites and fixtures
│   ├── s3_encryption_suite/     # S3 encryption policy tests
│   └── fixtures/                # Test entities and data
├── schema.cedarschema           # Cedar schema definition
└── README.md                    # This documentation
```

## 🔄 CI/CD Pipeline

The GitHub Actions workflow ([.github/workflows/cedar-check.yml](.github/workflows/cedar-check.yml)) provides:

1. **Policy Validation**
   - Syntax checking
   - Schema validation
   - Test case verification

2. **Secure AWS Access**
   - OIDC-based authentication
   - Short-lived credentials
   - Least-privilege IAM roles

3. **Deployment**
   - Automated testing before deployment
   - Environment-specific configurations
   - Rollback on failure

## 📚 Documentation

- [Cedar Policy Language Guide](https://docs.cedarpolicy.com/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

## 👥 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🧪 Testing

### Local Testing

1. **Install Cedar CLI**:
   ```bash
   ./scripts/install-cedar.sh
   ```

2. **Run Policy Validation**:
   ```bash
   ./scripts/validate-policies.sh
   ```

### CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/cedar-check.yml`) will automatically:
1. Validate and test Cedar policies on every PR
2. Deploy the AVP stack and test S3 operations

## 🔄 Workflow

1. **On Pull Request**:
   - Static analysis of Cedar policies
   - Policy validation and testing

2. **On Merge to Main**:
   - Deploy AVP stack
   - Test S3 operations with real AWS resources

## 🔒 Security Architecture

### OIDC Authentication Flow
1. GitHub Actions requests a token from GitHub's OIDC provider
2. AWS validates the token against the configured trust relationship
3. Temporary credentials are issued (valid for 1 hour)
4. No secrets stored in GitHub!

### IAM Permissions
The GitHub Actions role (`gha-oidc-PaulDuvall-cedar`) has:
- CloudFormation stack management (create/update/delete)
- Verified Permissions full access
- S3 read-only access
- Required IAM permissions for role assumption

### Security Best Practices
- **Least Privilege**: Each permission is scoped to specific resources
- **No Long-lived Credentials**: OIDC provides temporary credentials
- **Policy as Code**: All permissions are version controlled and reviewed
- **Shift-Left Security**: Policies are validated before deployment
- **Audit Trail**: Every authorization decision is logged

## 🛠️ Troubleshooting

### Common Issues and Solutions

1. **OIDC Authentication Failures**:
   ```
   Error: Could not assume role with OIDC
   ```
   - Verify IAM role trust policy includes your repository
   - Check the role ARN in GitHub secrets matches your AWS account
   - Ensure the repository name in trust policy matches exactly

2. **Cedar CLI Installation**:
   - First install takes 2-3 minutes (building from source)
   - Use `./scripts/install-cedar-fast.sh` for optimized installation
   - Requires Rust toolchain (installed automatically)

3. **Policy Validation Errors**:
   ```
   × failed to parse policy set
   ```
   - Check Cedar syntax - use `./scripts/quick-validate.sh`
   - Verify entity types match schema namespace
   - Ensure all referenced types exist in schema

4. **CloudFormation Deployment**:
   - Stack name format: `cedar-policy-store-{owner}-{repo}`
   - Requires `CAPABILITY_NAMED_IAM` for IAM role creation
   - Check CloudFormation events: `aws cloudformation describe-stack-events`

3. **Environment Not Found**:
   - Make sure the `production` environment is created in GitHub repository settings if using environment protection rules

4. **AWS CLI Errors**:
   - Ensure AWS CLI is configured with appropriate credentials when running locally
   - For GitHub Actions, verify the OIDC provider is correctly configured
   - Verify the AWS region matches in all configurations

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📚 Resources

- [AWS Cedar Policy Language](https://docs.cedarpolicy.com/)
- [Amazon Verified Permissions](https://aws.amazon.com/verified-permissions/)
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

<!-- Trigger build -->

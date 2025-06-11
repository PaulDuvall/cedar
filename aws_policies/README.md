# IAM Policy Management for OIDC Role

This directory contains IAM policy JSON files that are automatically attached to the OIDC IAM role for GitHub Actions by the `setup_oidc.sh` script.

**Important:**
- IAM policies in this directory **are tightly scoped to the Cedar repository's specific needs** following the principle of least privilege. Repository access is controlled by the role's trust policy, while these permission policies define the minimal AWS resources and actions needed for Cedar's workflows.

## Policy Files for Cedar Repository

These policies are tightened to the minimum permissions needed for the Cedar Policy as Code repository:

- **cfn.json**: CloudFormation permissions for stack deployment and management
- **verifiedpermissions.json**: AWS Verified Permissions for Cedar policy store management  
- **s3.json**: S3 permissions for bucket compliance checking and demo scenarios
- **iam.json**: IAM permissions for CloudFormation stack deployments with IAM resources
- **kms.json**: KMS permissions for encrypted S3 bucket demos
- **sts.json**: STS permissions for identity operations and OIDC authentication

## Permissions Analysis

These policies provide the minimum permissions required for:

1. **Cedar Policy Deployment**:
   - Deploy CloudFormation stacks for AWS Verified Permissions
   - Upload and manage Cedar policies in policy stores
   - Create and manage IAM roles for GitHub Actions

2. **S3 Compliance Testing**:
   - Check encryption status of existing S3 buckets
   - Create test buckets for encryption demos
   - Manage bucket policies and encryption settings

3. **Demo and Testing Workflows**:
   - Deploy CloudFormation templates for S3 encryption examples
   - Create KMS-encrypted resources for production scenarios
   - Clean up demo resources after testing

## Security Improvements

**Before**: Policies used wildcard resource permissions (e.g., `"Resource": "*"` for all services)
**After**: Policies tightly scoped to Cedar-specific resources and use cases

**Risk Reduction**:
- **S3**: Limited to `cedar-demo-*` and `atdd-test-*` buckets only
- **IAM**: Restricted to `cedar-*`, `gha-oidc-*-cedar`, and `CedarPolicyStore*` roles with service-specific PassRole conditions
- **CloudFormation**: Limited to `cedar-policy-store-*` and `cedar-demo-*` stacks
- **Verified Permissions**: Scoped to policy stores with `ManagedBy=cedar-*` tags
- **KMS**: Restricted to S3 service usage and `cedar-*` aliases only
- **STS**: Unchanged (identity operations appropriately use wildcard resources)

**Principle of Least Privilege**: Each policy now grants only the minimum permissions needed for Cedar's specific workflows.

## Usage

1. **Apply changes:**
   - After updating policy files, re-run `setup_oidc.sh` to attach them to the IAM OIDC role.

2. **Verify permissions:**
   - Test GitHub Actions workflows to ensure all required permissions are available
   - Monitor CloudTrail logs for any permission denied errors

## Important
- **After any policy change, always re-run `setup_oidc.sh` to apply updates.**
- **These policies are specifically tailored for the Cedar Policy as Code repository.**

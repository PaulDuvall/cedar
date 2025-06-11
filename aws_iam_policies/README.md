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

## Resource Naming Convention

All AWS resources created or managed by this Cedar repository follow these naming patterns:

### Primary Pattern: `cedar-*`
Most resources use the `cedar-*` prefix for consistency:
- CloudFormation Stacks: `cedar-policy-store-main`, `cedar-demo-*`
- KMS Aliases: `alias/cedar-s3-encryption`
- Resource Tags: `ManagedBy: cedar-*`

### S3 Bucket Naming (Global Uniqueness)
S3 buckets include AWS Account ID to ensure global uniqueness:
- Pattern: `cedar-{purpose}-{unique-id}-{account-id}`
- Example: `cedar-demo-encrypted-123456789012`

### IAM Role Exceptions
Two patterns are supported for IAM roles:
1. **Cedar-managed roles**: `cedar-*` (e.g., `cedar-deploy-role`)
2. **OIDC roles**: `gha-oidc-*-cedar` (created by external OIDC bootstrap tool)

The OIDC pattern is required for GitHub Actions authentication when using the 
[gha-aws-oidc-bootstrap](https://github.com/PaulDuvall/gha-aws-oidc-bootstrap) tool.

## Security Improvements

**Before**: Policies used wildcard resource permissions (e.g., `"Resource": "*"` for all services)
**After**: Policies tightly scoped to Cedar-specific resources and use cases

**Risk Reduction**:
- **S3**: Limited to `cedar-*` buckets only (with account ID for uniqueness)
- **IAM**: Restricted to `cedar-*` and `gha-oidc-*-cedar` roles with service-specific PassRole conditions
- **CloudFormation**: Limited to `cedar-*` stacks and changesets
- **Verified Permissions**: Scoped to policy stores with `ManagedBy=cedar-*` tags
- **KMS**: Restricted to S3 service usage and `cedar-*` aliases only
- **STS**: Unchanged (identity operations appropriately use wildcard resources)

**Principle of Least Privilege**: Each policy now grants only the minimum permissions needed for Cedar's specific workflows.

## How to Use This Directory

This directory contains IAM policy JSON files that are applied to the GitHub Actions OIDC role to enable secure, automated operations with AWS services.

### Setup and Configuration

1. **Initial Setup:**
   ```bash
   # Copy policies to your OIDC bootstrap directory
   cp aws_iam_policies/*.json /path/to/gha-aws-oidc-bootstrap/policies/
   
   # Run the OIDC setup script
   ./setup_oidc.sh
   ```

2. **Making Changes:**
   - Edit any policy file in `aws_iam_policies/`
   - Re-run the OIDC setup script to apply changes:
     ```bash
     ./setup_oidc.sh
     ```

3. **Verify Changes:**
   - Test GitHub Actions workflows to ensure permissions work
   - Monitor CloudTrail logs for any access denied errors
   - Check AWS Console for updated IAM role policies

### Policy File Structure

Each JSON file represents a separate IAM policy that gets attached to the OIDC role:

```
aws_iam_policies/
├── README.md              # This documentation
├── cfn.json              # CloudFormation deployment permissions
├── iam.json              # IAM role management permissions
├── kms.json              # KMS key and encryption permissions
├── s3.json               # S3 bucket operations permissions
├── sts.json              # Identity and token permissions
└── verifiedpermissions.json  # Cedar policy store permissions
```

### Best Practices

1. **Principle of Least Privilege**: Each policy grants only the minimum permissions needed
2. **Resource Scoping**: All policies use `cedar-*` resource patterns for security
3. **Service Separation**: Permissions are split by AWS service for clarity and maintainability
4. **Regular Review**: Periodically review and tighten permissions as workflows evolve

### Testing Changes

Before pushing policy changes to production:

1. **Local Testing**: Use `act` to test GitHub Actions locally:
   ```bash
   act -j validate
   ```

2. **Mock Testing**: Run the mock GitHub Actions script:
   ```bash
   ./scripts/mock-gha.sh
   ```

3. **Incremental Deployment**: Test policy changes on a branch first

### Troubleshooting

**Common Issues:**

- **Access Denied**: Check if the policy includes the required action and resource
- **Resource Not Found**: Verify resource ARN patterns match your naming convention
- **Role Assumption Failed**: Ensure trust policy allows GitHub Actions OIDC

**Debug Steps:**

1. Check CloudTrail logs for detailed error messages
2. Verify IAM role has all expected policies attached
3. Test individual AWS CLI commands manually
4. Review resource naming patterns for consistency

## Important Notes

- **Always re-run `setup_oidc.sh` after any policy changes**
- **These policies are specifically designed for the Cedar repository**
- **Changes to policies may affect all GitHub Actions workflows**
- **Keep policies in sync with actual resource naming conventions**

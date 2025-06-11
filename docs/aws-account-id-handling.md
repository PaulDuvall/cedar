# AWS Account ID Handling in Cedar

This document explains how AWS Account IDs are handled in the Cedar repository to ensure globally unique S3 bucket names without hardcoding sensitive information.

## Overview

S3 bucket names must be globally unique across all AWS accounts. To achieve this, we include the AWS Account ID in bucket names using the pattern: `cedar-{purpose}-{unique-id}-{account-id}`.

## Implementation Approaches

### 1. CloudFormation (Recommended)

CloudFormation automatically resolves the account ID using the `${AWS::AccountId}` pseudo parameter:

```yaml
Resources:
  S3Bucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub '${BucketPrefix}-${AWS::AccountId}'
```

**Advantages:**
- No additional API calls needed
- Automatically resolved at deployment time
- Works seamlessly with stack parameters

### 2. GitHub Actions with OIDC

When GitHub Actions assumes the OIDC role, it can retrieve the account ID dynamically:

```yaml
- name: Get AWS Account ID
  id: account
  run: |
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "account-id=$ACCOUNT_ID" >> $GITHUB_OUTPUT

- name: Use Account ID
  run: |
    BUCKET_NAME="cedar-demo-${{ github.run_number }}-${{ steps.account.outputs.account-id }}"
```

**Advantages:**
- No secrets or hardcoded values
- Retrieved dynamically from current credentials
- Can be used for non-CloudFormation resources

### 3. Local Development

For local development and testing, developers can retrieve their account ID:

```bash
# Get current account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Use in bucket names
BUCKET_NAME="cedar-test-${AWS_ACCOUNT_ID}"
```

## Security Benefits

1. **No Hardcoded Values**: Account IDs are never stored in code or configuration
2. **Dynamic Resolution**: Values are retrieved at runtime from AWS credentials
3. **OIDC Integration**: Works seamlessly with GitHub Actions OIDC authentication
4. **Least Privilege**: IAM policies can still use wildcards for account IDs while maintaining security

## Best Practices

1. **Use CloudFormation**: When deploying resources via CloudFormation, always use `${AWS::AccountId}`
2. **Cache in Workflows**: In GitHub Actions, retrieve the account ID once and reuse via outputs
3. **Validate Permissions**: Ensure IAM policies allow the necessary actions (e.g., `sts:GetCallerIdentity`)
4. **Consistent Naming**: Always follow the `cedar-*` prefix pattern for all resources

## Example IAM Policy

The S3 policy supports dynamic bucket names with account IDs:

```json
{
  "Effect": "Allow",
  "Action": ["s3:*"],
  "Resource": [
    "arn:aws:s3:::cedar-*",
    "arn:aws:s3:::cedar-*/*"
  ]
}
```

This pattern matches buckets like:
- `cedar-demo-encrypted-123456789012`
- `cedar-test-20240115-987654321098`
- `cedar-prod-kms-555555555555`

## Migration Guide

For existing resources without account IDs:

1. **New Resources**: All new S3 buckets must include the account ID
2. **Existing Resources**: Can be migrated gradually using S3 bucket aliases or by creating new buckets
3. **Policy Updates**: IAM policies already support the `cedar-*` pattern, no changes needed

## Troubleshooting

### Error: "Access denied for sts:GetCallerIdentity"

Ensure the IAM role has permission:
```json
{
  "Effect": "Allow",
  "Action": "sts:GetCallerIdentity",
  "Resource": "*"
}
```

### Error: "Bucket name already exists"

Even with account ID, conflicts can occur. Add additional uniqueness:
- Use timestamps: `cedar-demo-20240115120000-123456789012`
- Use GitHub run number: `cedar-demo-run456-123456789012`
- Use random suffix: `cedar-demo-a1b2c3-123456789012`
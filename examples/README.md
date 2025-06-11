# Real-World S3 Encryption Examples

This directory contains real CloudFormation templates and scripts to demonstrate Cedar policy enforcement for S3 bucket server-side encryption in real AWS environments.

## 📁 CloudFormation Templates

### 1. `cloudformation/s3-encrypted-bucket.yaml`
- **Compliant** S3 bucket with AES256 encryption
- Includes versioning, public access block, and proper tagging
- Passes Cedar validation ✅

### 2. `cloudformation/s3-unencrypted-bucket.yaml`
- **Non-compliant** S3 bucket WITHOUT encryption
- Demonstrates what gets blocked by Cedar policies
- Fails Cedar validation ❌

### 3. `cloudformation/s3-kms-encrypted-bucket.yaml`
- **Production-ready** S3 bucket with KMS encryption
- Creates KMS key if not provided
- Includes lifecycle policies and advanced features
- Passes Cedar validation ✅

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with credentials
- Cedar CLI installed (or run `./scripts/install-cedar-fast.sh`)
- Valid AWS account with S3 permissions

### Option 1: Full Demo (Recommended)
The complete demonstration shows shift-left and shift-right validation:

```bash
./scripts/real-world-s3-demo.sh
```

This will:
1. Validate CloudFormation templates (shift-left)
2. Deploy real S3 buckets to AWS
3. Check runtime compliance (shift-right)
4. Optionally clean up resources

### Option 2: Individual Steps

#### Shift-Left: Validate CloudFormation Templates
```bash
# Validate all templates in the examples directory
./scripts/validate-cloudformation-s3.sh examples/cloudformation/

# Validate a specific template
./scripts/validate-cloudformation-s3.sh examples/cloudformation/s3-encrypted-bucket.yaml
```

#### Deploy S3 Buckets
```bash
# Deploy encrypted bucket (compliant)
aws cloudformation deploy \
  --template-file examples/cloudformation/s3-encrypted-bucket.yaml \
  --stack-name my-encrypted-bucket \
  --parameter-overrides BucketPrefix=my-app

# Deploy KMS-encrypted bucket (production)
aws cloudformation deploy \
  --template-file examples/cloudformation/s3-kms-encrypted-bucket.yaml \
  --stack-name my-kms-bucket \
  --parameter-overrides BucketPrefix=my-prod-app
```

#### Shift-Right: Check Runtime Compliance
```bash
# Check all S3 buckets in your account
./scripts/check-s3-bucket-compliance.sh

# Check a specific bucket
./scripts/check-s3-bucket-compliance.sh my-bucket-name
```

## 🔍 How It Works

### CloudFormation Validation (Shift-Left)
1. Script parses CloudFormation template YAML
2. Extracts S3 bucket encryption configuration
3. Converts to Cedar entities
4. Runs Cedar policy evaluation
5. Reports compliance status

### Runtime Compliance (Shift-Right)
1. Script queries AWS S3 API for bucket encryption settings
2. Checks both default encryption and bucket policies
3. Converts to Cedar entities
4. Runs Cedar policy evaluation
5. Reports compliance status

## 📊 Example Output

### Compliant Bucket
```
🔍 S3 Bucket Encryption Compliance Checker
==========================================

Checking bucket: cedar-demo-encrypted-123456789012
Encryption Status:
  Enabled: true
  Algorithm: AES256
  Policy Enforces: false
  Region: us-east-1
Running Cedar compliance check...
✅ COMPLIANT: Bucket meets encryption requirements
```

### Non-Compliant Bucket
```
Checking bucket: cedar-demo-unencrypted-123456789012
Encryption Status:
  Enabled: false
  Algorithm: none
  Policy Enforces: false
  Region: us-east-1
Running Cedar compliance check...
❌ NON-COMPLIANT: Bucket does not meet encryption requirements
Reason: S3 bucket must have server-side encryption enabled
```

## 🧹 Cleanup

After testing, clean up resources to avoid charges:

```bash
# Delete CloudFormation stacks
aws cloudformation delete-stack --stack-name cedar-demo-encrypted-bucket
aws cloudformation delete-stack --stack-name cedar-demo-unencrypted-bucket
aws cloudformation delete-stack --stack-name cedar-demo-kms-bucket

# Or use the demo script's cleanup option
./scripts/real-world-s3-demo.sh
# Choose 'y' when prompted for cleanup
```

## 💡 Tips

1. **Production Use**: For production, always use KMS encryption instead of AES256
2. **Bucket Policies**: You can achieve compliance via bucket policies that enforce encryption
3. **Cost**: KMS encryption incurs additional charges for key usage
4. **Regions**: Update templates for your preferred AWS region

## 🔐 Security Notes

- These templates create real AWS resources
- S3 buckets are created with unique names to avoid conflicts
- Public access is blocked by default
- Remember to delete resources after testing to avoid charges

## 🤝 Integration

These examples integrate with the unified Cedar policy at:
`policies/s3-encryption-enforcement.cedar`

The same policy validates both:
- CloudFormation templates (development time)
- Live S3 buckets (runtime)

This demonstrates Cedar's power for consistent security enforcement across the entire infrastructure lifecycle!
# Real-World S3 Encryption Testing Guide

This guide demonstrates how to test the unified Cedar policy with real AWS resources, including CloudFormation templates and actual S3 buckets.

## 🚀 Quick Start

### Prerequisites
- Cedar CLI installed (`./scripts/install-cedar-fast.sh`)
- AWS CLI configured with credentials (optional for real bucket testing)

### Simple Demo
Run the simple demo to see everything in action:
```bash
./scripts/simple-s3-demo.sh
```

This will:
1. Check CloudFormation templates for encryption
2. Test Cedar policy validation
3. Check real S3 buckets (if AWS is configured)

## 📝 CloudFormation Templates

### Available Templates

1. **`examples/cloudformation/s3-encrypted-bucket.yaml`**
   - ✅ Compliant: Has AES256 encryption
   - Safe to deploy
   
2. **`examples/cloudformation/s3-kms-encrypted-bucket.yaml`**
   - ✅ Compliant: Has KMS encryption
   - Production-ready with KMS key management
   
3. **`examples/cloudformation/s3-unencrypted-bucket.yaml`**
   - ❌ Non-compliant: NO encryption
   - Demonstrates what gets blocked

### Deploy Real Buckets

```bash
# Deploy encrypted bucket
aws cloudformation deploy \
  --template-file examples/cloudformation/s3-encrypted-bucket.yaml \
  --stack-name my-encrypted-bucket-demo \
  --parameter-overrides BucketPrefix=myapp

# Check the bucket
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name my-encrypted-bucket-demo \
  --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
  --output text)

echo "Created bucket: $BUCKET_NAME"
```

## 🧪 Testing Scenarios

### Scenario 1: CloudFormation Validation (Shift-Left)

```bash
# Create test entity for CloudFormation template
cat > /tmp/cf-test.json << 'EOF'
[
    {
        "uid": {"type": "CloudFormationTemplate", "id": "my-template"},
        "attrs": {
            "template_name": "my-template",
            "stack_name": "test-stack",
            "environment": "development",
            "s3_resources": [{"type": "S3Resource", "id": "my-bucket"}]
        },
        "parents": []
    },
    {
        "uid": {"type": "S3Resource", "id": "my-bucket"},
        "attrs": {
            "name": "my-bucket",
            "encryption_enabled": true,
            "encryption_algorithm": "AES256",
            "environment": "development",
            "resource_type": "template_resource"
        },
        "parents": []
    },
    {
        "uid": {"type": "Human", "id": "developer"},
        "attrs": {
            "role": "Developer",
            "team": "platform",
            "department": "engineering",
            "email": "dev@example.com"
        },
        "parents": []
    }
]
EOF

# Validate template
cedar authorize \
  --policies policies/s3-encryption-enforcement.cedar \
  --schema schema.cedarschema \
  --entities /tmp/cf-test.json \
  --principal 'Human::"developer"' \
  --action 'Action::"cloudformation:ValidateTemplate"' \
  --resource 'CloudFormationTemplate::"my-template"'
```

### Scenario 2: Runtime Bucket Check (Shift-Right)

```bash
# Create test entity for runtime bucket
cat > /tmp/runtime-test.json << 'EOF'
[
    {
        "uid": {"type": "S3Resource", "id": "production-bucket"},
        "attrs": {
            "name": "production-bucket",
            "encryption_enabled": true,
            "encryption_algorithm": "aws:kms",
            "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/abc-123",
            "environment": "production",
            "resource_type": "bucket"
        },
        "parents": []
    },
    {
        "uid": {"type": "ConfigEvaluation", "id": "s3-bucket-server-side-encryption-enabled"},
        "attrs": {
            "rule_name": "s3-bucket-server-side-encryption-enabled",
            "evaluation_type": "shift-right",
            "compliance_status": "EVALUATING"
        },
        "parents": []
    }
]
EOF

# Check compliance
cedar authorize \
  --policies policies/s3-encryption-enforcement.cedar \
  --schema schema.cedarschema \
  --entities /tmp/runtime-test.json \
  --principal 'ConfigEvaluation::"s3-bucket-server-side-encryption-enabled"' \
  --action 'Action::"config:EvaluateCompliance"' \
  --resource 'S3Resource::"production-bucket"'
```

### Scenario 3: Bucket Creation

```bash
# Test creating encrypted vs unencrypted buckets
# This shows how Cedar would block non-compliant bucket creation

# Encrypted bucket (ALLOW)
cedar authorize \
  --policies policies/s3-encryption-enforcement.cedar \
  --schema schema.cedarschema \
  --entities tests/fixtures/entities.json \
  --principal 'Human::"alice"' \
  --action 'Action::"s3:CreateBucket"' \
  --resource 'S3Resource::"new-secure-bucket"'

# Unencrypted bucket (DENY)  
cedar authorize \
  --policies policies/s3-encryption-enforcement.cedar \
  --schema schema.cedarschema \
  --entities tests/fixtures/entities.json \
  --principal 'Human::"alice"' \
  --action 'Action::"s3:CreateBucket"' \
  --resource 'S3Resource::"insecure-bucket"'
```

## 🔍 Real AWS Integration

### Check Your Real S3 Buckets

```bash
# List all buckets and their encryption status
for bucket in $(aws s3api list-buckets --query 'Buckets[].Name' --output text); do
    echo -n "Bucket $bucket: "
    if aws s3api get-bucket-encryption --bucket "$bucket" &>/dev/null; then
        algo=$(aws s3api get-bucket-encryption --bucket "$bucket" | \
               jq -r '.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm')
        echo "✅ Encrypted with $algo"
    else
        echo "❌ No encryption"
    fi
done
```

### Full Workflow Example

```bash
# 1. Validate CloudFormation template
./scripts/simple-s3-demo.sh

# 2. Deploy if validation passes
aws cloudformation deploy \
  --template-file examples/cloudformation/s3-encrypted-bucket.yaml \
  --stack-name cedar-demo-bucket

# 3. Get bucket name
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name cedar-demo-bucket \
  --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
  --output text)

# 4. Check runtime compliance
./scripts/check-s3-bucket-compliance.sh "$BUCKET"

# 5. Cleanup
aws s3 rb "s3://$BUCKET" --force
aws cloudformation delete-stack --stack-name cedar-demo-bucket
```

## 🎯 Key Points

1. **Same Policy, Two Use Cases**: The Cedar policy in `policies/s3-encryption-enforcement.cedar` handles both CloudFormation validation and runtime checks

2. **Real AWS Resources**: The examples create actual S3 buckets in your AWS account

3. **Cost-Effective**: S3 buckets with no data incur minimal charges

4. **Production-Ready**: The KMS-encrypted template is suitable for production use

## 🧹 Cleanup

Always clean up test resources:

```bash
# Delete any test buckets
aws s3 ls | grep cedar-demo | awk '{print $3}' | xargs -I {} aws s3 rb "s3://{}" --force

# Delete CloudFormation stacks
aws cloudformation delete-stack --stack-name cedar-demo-encrypted-bucket
aws cloudformation delete-stack --stack-name cedar-demo-unencrypted-bucket
aws cloudformation delete-stack --stack-name cedar-demo-kms-bucket
```

## 📊 Expected Results

### CloudFormation Templates
- ✅ `s3-encrypted-bucket.yaml` - PASSES validation
- ✅ `s3-kms-encrypted-bucket.yaml` - PASSES validation  
- ❌ `s3-unencrypted-bucket.yaml` - FAILS validation

### Cedar Policy Decisions
- ✅ Encrypted buckets → ALLOW
- ❌ Unencrypted buckets → DENY
- ✅ Buckets with policy enforcement → ALLOW
- ❌ Production buckets with only AES256 → DENY (requires KMS)

This demonstrates how Cedar provides consistent security enforcement across your entire infrastructure lifecycle!
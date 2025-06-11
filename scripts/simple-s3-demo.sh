#!/bin/bash
# Simple S3 encryption demo with real CloudFormation and buckets

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔒 Simple S3 Encryption Demo${NC}"
echo "============================="
echo ""

# Step 1: Check if CloudFormation template has encryption
echo -e "${BLUE}Step 1: Checking CloudFormation templates for encryption...${NC}"
echo ""

for template in examples/cloudformation/*.yaml; do
    name=$(basename "$template")
    echo -n "$name: "
    
    if grep -q "BucketEncryption:" "$template"; then
        algo=$(grep -A5 "BucketEncryption:" "$template" | grep "SSEAlgorithm:" | awk '{print $2}')
        echo -e "${GREEN}✅ Encrypted with $algo${NC}"
    else
        echo -e "${RED}❌ No encryption${NC}"
    fi
done

echo ""
echo -e "${BLUE}Step 2: Testing Cedar policy validation...${NC}"
echo ""

# Create test entities for an encrypted bucket
cat > /tmp/test-encrypted.json << 'EOF'
[
    {
        "uid": {"type": "S3Resource", "id": "test-encrypted-bucket"},
        "attrs": {
            "name": "test-encrypted-bucket",
            "encryption_enabled": true,
            "encryption_algorithm": "AES256",
            "environment": "development",
            "resource_type": "bucket"
        },
        "parents": []
    },
    {
        "uid": {"type": "Human", "id": "alice"},
        "attrs": {
            "role": "Developer",
            "team": "platform",
            "department": "engineering",
            "email": "alice@example.com"
        },
        "parents": []
    }
]
EOF

# Create test entities for an unencrypted bucket
cat > /tmp/test-unencrypted.json << 'EOF'
[
    {
        "uid": {"type": "S3Resource", "id": "test-unencrypted-bucket"},
        "attrs": {
            "name": "test-unencrypted-bucket",
            "encryption_enabled": false,
            "environment": "development",
            "resource_type": "bucket"
        },
        "parents": []
    },
    {
        "uid": {"type": "Human", "id": "alice"},
        "attrs": {
            "role": "Developer",
            "team": "platform",
            "department": "engineering",
            "email": "alice@example.com"
        },
        "parents": []
    }
]
EOF

# Test encrypted bucket creation
echo -n "Creating encrypted bucket: "
if cedar authorize \
    --policies policies/s3-encryption-enforcement.cedar \
    --schema schema.cedarschema \
    --entities /tmp/test-encrypted.json \
    --principal 'Human::"alice"' \
    --action 'Action::"s3:CreateBucket"' \
    --resource 'S3Resource::"test-encrypted-bucket"' 2>/dev/null; then
    echo -e "${GREEN}✅ ALLOWED${NC}"
else
    echo -e "${RED}❌ DENIED${NC}"
fi

# Test unencrypted bucket creation
echo -n "Creating unencrypted bucket: "
if cedar authorize \
    --policies policies/s3-encryption-enforcement.cedar \
    --schema schema.cedarschema \
    --entities /tmp/test-unencrypted.json \
    --principal 'Human::"alice"' \
    --action 'Action::"s3:CreateBucket"' \
    --resource 'S3Resource::"test-unencrypted-bucket"' 2>/dev/null; then
    echo -e "${GREEN}✅ ALLOWED${NC}"
else
    echo -e "${RED}❌ DENIED${NC}"
fi

echo ""
echo -e "${BLUE}Step 3: Checking real S3 buckets (if you have AWS configured)...${NC}"
echo ""

if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null 2>&1; then
    # List first 3 S3 buckets
    buckets=$(aws s3api list-buckets --query 'Buckets[0:3].Name' --output text 2>/dev/null || echo "")
    
    if [[ -n "$buckets" ]]; then
        for bucket in $buckets; do
            echo -n "Bucket $bucket: "
            
            # Check encryption
            if aws s3api get-bucket-encryption --bucket "$bucket" &>/dev/null; then
                algo=$(aws s3api get-bucket-encryption --bucket "$bucket" 2>/dev/null | jq -r '.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm')
                echo -e "${GREEN}✅ Encrypted with $algo${NC}"
            else
                echo -e "${RED}❌ No encryption${NC}"
            fi
        done
    else
        echo "No S3 buckets found in your account"
    fi
else
    echo -e "${YELLOW}AWS CLI not configured. Skipping real bucket checks.${NC}"
    echo "To check real buckets, configure AWS CLI with: aws configure"
fi

# Cleanup
rm -f /tmp/test-encrypted.json /tmp/test-unencrypted.json

echo ""
echo -e "${GREEN}🎉 Demo complete!${NC}"
echo ""
echo "Key takeaways:"
echo "1. CloudFormation templates can be validated for encryption before deployment"
echo "2. Cedar policies enforce encryption requirements consistently"
echo "3. The same policy works for both development-time and runtime validation"
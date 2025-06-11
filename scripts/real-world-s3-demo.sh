#!/bin/bash
# Real-world S3 encryption demo
# Shows both shift-left (CloudFormation) and shift-right (runtime) validation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${MAGENTA}🚀 Real-World S3 Encryption Demo with Cedar${NC}"
echo "============================================"
echo ""
echo -e "${CYAN}This demo shows how Cedar policies enforce S3 encryption${NC}"
echo -e "${CYAN}across the entire infrastructure lifecycle:${NC}"
echo -e "${CYAN}1. Shift-Left: CloudFormation template validation${NC}"
echo -e "${CYAN}2. Deployment: Creating real S3 buckets${NC}"
echo -e "${CYAN}3. Shift-Right: Runtime compliance checking${NC}"
echo ""

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
if ! command -v cedar &> /dev/null; then
    echo -e "${RED}Cedar CLI not found. Installing...${NC}"
    "$PROJECT_ROOT/scripts/install-cedar-fast.sh"
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not found. Please install it.${NC}"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured.${NC}"
    echo "Please run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ Using AWS Account: $ACCOUNT_ID${NC}"
echo ""

# Step 1: Shift-Left - Validate CloudFormation templates
echo -e "${BLUE}=== Step 1: Shift-Left - CloudFormation Template Validation ===${NC}"
echo ""

echo -e "${YELLOW}Validating CloudFormation templates BEFORE deployment...${NC}"
"$PROJECT_ROOT/scripts/validate-cloudformation-s3.sh" "$PROJECT_ROOT/examples/cloudformation"
echo ""

read -p "Press Enter to continue to deployment..."
echo ""

# Step 2: Deploy S3 buckets
echo -e "${BLUE}=== Step 2: Deploying S3 Buckets ===${NC}"
echo ""

# Deploy encrypted bucket
STACK_NAME_ENCRYPTED="cedar-demo-encrypted-bucket"
echo -e "${YELLOW}Deploying encrypted S3 bucket...${NC}"
aws cloudformation deploy \
    --template-file "$PROJECT_ROOT/examples/cloudformation/s3-encrypted-bucket.yaml" \
    --stack-name "$STACK_NAME_ENCRYPTED" \
    --parameter-overrides BucketPrefix="cedar-demo" \
    --no-fail-on-empty-changeset

ENCRYPTED_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME_ENCRYPTED" \
    --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
    --output text)

echo -e "${GREEN}✓ Created encrypted bucket: $ENCRYPTED_BUCKET${NC}"

# Deploy unencrypted bucket
STACK_NAME_UNENCRYPTED="cedar-demo-unencrypted-bucket"
echo -e "${YELLOW}Deploying unencrypted S3 bucket (non-compliant)...${NC}"
aws cloudformation deploy \
    --template-file "$PROJECT_ROOT/examples/cloudformation/s3-unencrypted-bucket.yaml" \
    --stack-name "$STACK_NAME_UNENCRYPTED" \
    --parameter-overrides BucketPrefix="cedar-demo" \
    --no-fail-on-empty-changeset

UNENCRYPTED_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME_UNENCRYPTED" \
    --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
    --output text)

echo -e "${RED}✓ Created unencrypted bucket: $UNENCRYPTED_BUCKET${NC}"
echo ""

read -p "Press Enter to continue to compliance checking..."
echo ""

# Step 3: Shift-Right - Check runtime compliance
echo -e "${BLUE}=== Step 3: Shift-Right - Runtime Compliance Checking ===${NC}"
echo ""

echo -e "${YELLOW}Checking encrypted bucket compliance...${NC}"
"$PROJECT_ROOT/scripts/check-s3-bucket-compliance.sh" "$ENCRYPTED_BUCKET"
echo ""

echo -e "${YELLOW}Checking unencrypted bucket compliance...${NC}"
"$PROJECT_ROOT/scripts/check-s3-bucket-compliance.sh" "$UNENCRYPTED_BUCKET"
echo ""

# Summary
echo -e "${MAGENTA}=== Demo Summary ===${NC}"
echo ""
echo -e "${CYAN}What we demonstrated:${NC}"
echo ""
echo -e "${GREEN}1. Shift-Left Validation:${NC}"
echo "   - CloudFormation templates were validated BEFORE deployment"
echo "   - Templates with encryption passed validation ✅"
echo "   - Templates without encryption failed validation ❌"
echo ""
echo -e "${GREEN}2. Real Deployment:${NC}"
echo "   - Created actual S3 buckets in AWS"
echo "   - Encrypted bucket: $ENCRYPTED_BUCKET"
echo "   - Unencrypted bucket: $UNENCRYPTED_BUCKET"
echo ""
echo -e "${GREEN}3. Shift-Right Compliance:${NC}"
echo "   - Runtime validation of actual S3 buckets"
echo "   - Encrypted bucket is COMPLIANT ✅"
echo "   - Unencrypted bucket is NON-COMPLIANT ❌"
echo ""
echo -e "${CYAN}The same Cedar policy enforced encryption requirements${NC}"
echo -e "${CYAN}at both development time AND runtime! 🔐${NC}"
echo ""

# Cleanup
echo -e "${YELLOW}Would you like to clean up the demo resources? (y/n)${NC}"
read -r cleanup

if [[ "$cleanup" == "y" || "$cleanup" == "Y" ]]; then
    echo -e "${YELLOW}Cleaning up...${NC}"
    
    # Empty and delete buckets
    aws s3 rm "s3://$ENCRYPTED_BUCKET" --recursive 2>/dev/null || true
    aws s3 rb "s3://$ENCRYPTED_BUCKET" --force 2>/dev/null || true
    
    aws s3 rm "s3://$UNENCRYPTED_BUCKET" --recursive 2>/dev/null || true
    aws s3 rb "s3://$UNENCRYPTED_BUCKET" --force 2>/dev/null || true
    
    # Delete CloudFormation stacks
    aws cloudformation delete-stack --stack-name "$STACK_NAME_ENCRYPTED"
    aws cloudformation delete-stack --stack-name "$STACK_NAME_UNENCRYPTED"
    
    echo -e "${GREEN}✓ Cleanup initiated. Stacks will be deleted in a few minutes.${NC}"
else
    echo -e "${YELLOW}Resources retained. Remember to clean them up later:${NC}"
    echo "  aws cloudformation delete-stack --stack-name $STACK_NAME_ENCRYPTED"
    echo "  aws cloudformation delete-stack --stack-name $STACK_NAME_UNENCRYPTED"
fi

echo ""
echo -e "${GREEN}🎉 Demo complete!${NC}"
#!/bin/bash
# Check real S3 bucket encryption compliance using Cedar
# This script demonstrates shift-right validation of actual S3 buckets

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🔍 S3 Bucket Encryption Compliance Checker${NC}"
echo "=========================================="
echo ""

# Function to check S3 bucket encryption
check_bucket_encryption() {
    local bucket_name="$1"
    
    echo -e "${YELLOW}Checking bucket: $bucket_name${NC}"
    
    # Get bucket encryption configuration
    local encryption_config=$(aws s3api get-bucket-encryption \
        --bucket "$bucket_name" 2>/dev/null || echo "none")
    
    local encryption_enabled=false
    local encryption_algorithm="none"
    local kms_key_id=""
    
    if [[ "$encryption_config" != "none" ]]; then
        encryption_enabled=true
        # Extract algorithm
        encryption_algorithm=$(echo "$encryption_config" | jq -r '.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm // "none"')
        
        # Extract KMS key if present
        if [[ "$encryption_algorithm" == "aws:kms" ]]; then
            kms_key_id=$(echo "$encryption_config" | jq -r '.Rules[0].ApplyServerSideEncryptionByDefault.KMSMasterKeyID // ""')
        fi
    fi
    
    # Check bucket policy for encryption enforcement
    local bucket_policy=$(aws s3api get-bucket-policy \
        --bucket "$bucket_name" 2>/dev/null || echo "none")
    
    local policy_enforces_encryption=false
    if [[ "$bucket_policy" != "none" ]]; then
        # Check if policy denies unencrypted uploads
        if echo "$bucket_policy" | grep -q "s3:x-amz-server-side-encryption"; then
            policy_enforces_encryption=true
        fi
    fi
    
    # Get bucket region and account
    local bucket_location=$(aws s3api get-bucket-location \
        --bucket "$bucket_name" 2>/dev/null | jq -r '.LocationConstraint // "us-east-1"')
    
    if [[ "$bucket_location" == "null" || -z "$bucket_location" ]]; then
        bucket_location="us-east-1"
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    
    echo "Encryption Status:"
    echo "  Enabled: $encryption_enabled"
    echo "  Algorithm: $encryption_algorithm"
    if [[ -n "$kms_key_id" ]]; then
        echo "  KMS Key: $kms_key_id"
    fi
    echo "  Policy Enforces: $policy_enforces_encryption"
    echo "  Region: $bucket_location"
    
    # Create Cedar entity file
    local entity_file="/tmp/s3-entity-${bucket_name}.json"
    
    # Build entity JSON
    cat > "$entity_file" << EOF
[
    {
        "uid": {"type": "S3Resource", "id": "$bucket_name"},
        "attrs": {
            "name": "$bucket_name",
            "encryption_enabled": $encryption_enabled,
EOF
    
    if [[ "$encryption_algorithm" != "none" ]]; then
        echo "            \"encryption_algorithm\": \"$encryption_algorithm\"," >> "$entity_file"
    fi
    
    if [[ -n "$kms_key_id" ]]; then
        echo "            \"kms_key_id\": \"$kms_key_id\"," >> "$entity_file"
    fi
    
    if [[ "$policy_enforces_encryption" == "true" ]]; then
        echo "            \"bucket_policy_enforces_encryption\": true," >> "$entity_file"
    fi
    
    cat >> "$entity_file" << EOF
            "environment": "production",
            "resource_type": "bucket"
        }
    },
    {
        "uid": {"type": "ConfigEvaluation", "id": "s3-bucket-server-side-encryption-enabled"},
        "attrs": {
            "rule_name": "s3-bucket-server-side-encryption-enabled",
            "evaluation_type": "shift-right",
            "compliance_status": "EVALUATING"
        }
    }
]
EOF
    
    echo "$entity_file"
}

# Function to validate bucket with Cedar
validate_bucket_with_cedar() {
    local entity_file="$1"
    local bucket_name="$2"
    
    echo -e "${CYAN}Running Cedar compliance check...${NC}"
    
    local result=$(cedar authorize \
        --policies "$PROJECT_ROOT/cedar_policies/s3-encryption-enforcement.cedar" \
        --schema "$PROJECT_ROOT/schema.cedarschema" \
        --entities "$entity_file" \
        --principal 'ConfigEvaluation::"s3-bucket-server-side-encryption-enabled"' \
        --action 'Action::"config:EvaluateCompliance"' \
        --resource "S3Resource::\"$bucket_name\"" 2>&1 || echo "DENY")
    
    if [[ "$result" == *"ALLOW"* ]]; then
        echo -e "${GREEN}✅ COMPLIANT: Bucket meets encryption requirements${NC}"
        return 0
    else
        echo -e "${RED}❌ NON-COMPLIANT: Bucket does not meet encryption requirements${NC}"
        echo -e "${RED}Reason: S3 bucket must have server-side encryption enabled${NC}"
        return 1
    fi
}

# Main logic
main() {
    local bucket_name="${1:-}"
    
    if [[ -z "$bucket_name" ]]; then
        # List all buckets and check each one
        echo -e "${BLUE}Checking all S3 buckets in the account...${NC}"
        echo ""
        
        local buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)
        local compliant=0
        local non_compliant=0
        
        for bucket in $buckets; do
            echo "----------------------------------------"
            local entity_file=$(check_bucket_encryption "$bucket")
            if [[ -f "$entity_file" ]]; then
                if validate_bucket_with_cedar "$entity_file" "$bucket"; then
                    ((compliant++))
                else
                    ((non_compliant++))
                fi
                rm -f "$entity_file"
            fi
            echo ""
        done
        
        echo "========================================"
        echo -e "${BLUE}Summary:${NC}"
        echo -e "${GREEN}Compliant buckets: $compliant${NC}"
        echo -e "${RED}Non-compliant buckets: $non_compliant${NC}"
    else
        # Check specific bucket
        local entity_file=$(check_bucket_encryption "$bucket_name")
        if [[ -f "$entity_file" ]]; then
            validate_bucket_with_cedar "$entity_file" "$bucket_name"
            rm -f "$entity_file"
        fi
    fi
}

# Check dependencies
if ! command -v cedar &> /dev/null; then
    echo -e "${RED}Error: Cedar CLI not found. Please install it first.${NC}"
    echo "Run: ./scripts/install-cedar-fast.sh"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not found. Please install it.${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured.${NC}"
    echo "Run: aws configure"
    exit 1
fi

# Run compliance check
main "$@"
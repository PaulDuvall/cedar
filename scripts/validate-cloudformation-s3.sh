#!/bin/bash
# Validate CloudFormation templates for S3 encryption compliance using Cedar
# This script demonstrates shift-left validation of real CloudFormation templates

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

echo -e "${BLUE}🔍 CloudFormation S3 Encryption Validator${NC}"
echo "=========================================="
echo ""

# Function to extract S3 encryption configuration from CloudFormation template
extract_s3_encryption() {
    local template_file="$1"
    local template_name=$(basename "$template_file" .yaml)
    
    echo -e "${YELLOW}Analyzing: $template_file${NC}" >&2
    
    # Check if template has S3 bucket resources
    if ! grep -q "AWS::S3::Bucket" "$template_file"; then
        echo "No S3 buckets found in template" >&2
        echo "" >&2
        return 0
    fi
    
    # Extract encryption configuration using grep
    local has_encryption="none"
    local encryption_algo="none"
    
    # Check for BucketEncryption in the template
    if grep -q "BucketEncryption:" "$template_file"; then
        has_encryption="found"
        
        # Try to extract the algorithm
        if grep -q "SSEAlgorithm: AES256" "$template_file"; then
            encryption_algo="AES256"
        elif grep -q "SSEAlgorithm: aws:kms" "$template_file"; then
            encryption_algo="aws:kms"
        elif grep -q "SSEAlgorithm: 'aws:kms'" "$template_file"; then
            encryption_algo="aws:kms"
        elif grep -q "SSEAlgorithm: \"aws:kms\"" "$template_file"; then
            encryption_algo="aws:kms"
        fi
    fi
    
    echo "Encryption detected: $has_encryption" >&2
    
    # Create Cedar entity for this CloudFormation template
    local entity_file="/tmp/cf-entity-${template_name}.json"
    
    if [[ "$has_encryption" == "found" ]]; then
        # Template has encryption
        if [[ "$encryption_algo" == "aws:kms" ]]; then
            # KMS encryption - include dummy key ID for validation
            cat > "$entity_file" << EOF
[
    {
        "uid": {"type": "CloudFormationTemplate", "id": "$template_name"},
        "attrs": {
            "template_name": "$template_name",
            "stack_name": "test-stack",
            "environment": "development",
            "s3_resources": [{"type": "S3Resource", "id": "${template_name}-bucket"}]
        },
        "parents": []
    },
    {
        "uid": {"type": "S3Resource", "id": "${template_name}-bucket"},
        "attrs": {
            "name": "${template_name}-bucket",
            "encryption_enabled": true,
            "encryption_algorithm": "$encryption_algo",
            "kms_key_id": "arn:aws:kms:us-east-1:123456789012:key/template-validation",
            "environment": "development",
            "resource_type": "template_resource"
        },
        "parents": []
    },
    {
        "uid": {"type": "Human", "id": "validator"},
        "attrs": {
            "role": "Developer",
            "team": "platform",
            "department": "engineering",
            "email": "validator@example.com"
        },
        "parents": []
    }
]
EOF
        else
            # AES256 encryption
            cat > "$entity_file" << EOF
[
    {
        "uid": {"type": "CloudFormationTemplate", "id": "$template_name"},
        "attrs": {
            "template_name": "$template_name",
            "stack_name": "test-stack",
            "environment": "development",
            "s3_resources": [{"type": "S3Resource", "id": "${template_name}-bucket"}]
        },
        "parents": []
    },
    {
        "uid": {"type": "S3Resource", "id": "${template_name}-bucket"},
        "attrs": {
            "name": "${template_name}-bucket",
            "encryption_enabled": true,
            "encryption_algorithm": "$encryption_algo",
            "environment": "development",
            "resource_type": "template_resource"
        },
        "parents": []
    },
    {
        "uid": {"type": "Human", "id": "validator"},
        "attrs": {
            "role": "Developer",
            "team": "platform",
            "department": "engineering",
            "email": "validator@example.com"
        },
        "parents": []
    }
]
EOF
        fi
    else
        # Template lacks encryption
        cat > "$entity_file" << EOF
[
    {
        "uid": {"type": "CloudFormationTemplate", "id": "$template_name"},
        "attrs": {
            "template_name": "$template_name",
            "stack_name": "test-stack",
            "environment": "development",
            "s3_resources": [{"type": "S3Resource", "id": "${template_name}-bucket"}]
        },
        "parents": []
    },
    {
        "uid": {"type": "S3Resource", "id": "${template_name}-bucket"},
        "attrs": {
            "name": "${template_name}-bucket",
            "encryption_enabled": false,
            "environment": "development",
            "resource_type": "template_resource"
        },
        "parents": []
    },
    {
        "uid": {"type": "Human", "id": "validator"},
        "attrs": {
            "role": "Developer",
            "team": "platform",
            "department": "engineering",
            "email": "validator@example.com"
        },
        "parents": []
    }
]
EOF
    fi
    
    echo "$entity_file"
}

# Function to validate template with Cedar
validate_with_cedar() {
    local entity_file="$1"
    local template_name="$2"
    
    echo -e "${CYAN}Running Cedar validation...${NC}"
    
    # For CloudFormation validation, we just need to check if the template environment is valid
    # The actual encryption check happens at the S3Resource level
    local result=$(cedar authorize \
        --policies "$PROJECT_ROOT/cedar_policies/s3-encryption-enforcement.cedar" \
        --schema "$PROJECT_ROOT/schema.cedarschema" \
        --entities "$entity_file" \
        --principal 'Human::"validator"' \
        --action 'Action::"cloudformation:ValidateTemplate"' \
        --resource "CloudFormationTemplate::\"$template_name\"" 2>&1 || echo "DENY")
    
    # Also check if we can create the S3 bucket
    local bucket_result=$(cedar authorize \
        --policies "$PROJECT_ROOT/cedar_policies/s3-encryption-enforcement.cedar" \
        --schema "$PROJECT_ROOT/schema.cedarschema" \
        --entities "$entity_file" \
        --principal 'Human::"validator"' \
        --action 'Action::"s3:CreateBucket"' \
        --resource "S3Resource::\"${template_name}-bucket\"" 2>&1 || echo "DENY")
    
    if [[ "$bucket_result" == *"ALLOW"* ]]; then
        echo -e "${GREEN}✅ COMPLIANT: S3 bucket has proper encryption${NC}"
        return 0
    else
        echo -e "${RED}❌ NON-COMPLIANT: S3 bucket lacks proper encryption${NC}"
        return 1
    fi
}

# Main validation logic
main() {
    local template_path="${1:-$PROJECT_ROOT/examples/cloudformation}"
    
    if [[ -f "$template_path" ]]; then
        # Single file validation
        local entity_file=$(extract_s3_encryption "$template_path")
        if [[ -f "$entity_file" ]]; then
            validate_with_cedar "$entity_file" "$(basename "$template_path" .yaml)"
            rm -f "$entity_file"
        fi
    elif [[ -d "$template_path" ]]; then
        # Directory validation
        echo -e "${BLUE}Validating all CloudFormation templates in: $template_path${NC}"
        echo ""
        
        local compliant=0
        local non_compliant=0
        
        for template in "$template_path"/*.yaml; do
            if [[ -f "$template" ]]; then
                echo "----------------------------------------"
                local entity_file=$(extract_s3_encryption "$template")
                if [[ -f "$entity_file" ]]; then
                    if validate_with_cedar "$entity_file" "$(basename "$template" .yaml)"; then
                        ((compliant++))
                    else
                        ((non_compliant++))
                    fi
                    rm -f "$entity_file"
                fi
                echo ""
            fi
        done
        
        echo "========================================"
        echo -e "${BLUE}Summary:${NC}"
        echo -e "${GREEN}Compliant templates: $compliant${NC}"
        echo -e "${RED}Non-compliant templates: $non_compliant${NC}"
    else
        echo -e "${RED}Error: $template_path not found${NC}"
        exit 1
    fi
}

# Check dependencies
if ! command -v cedar &> /dev/null; then
    echo -e "${RED}Error: Cedar CLI not found. Please install it first.${NC}"
    echo "Run: ./scripts/install-cedar-fast.sh"
    exit 1
fi

# Run validation
main "$@"
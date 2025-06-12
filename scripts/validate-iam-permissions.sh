#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 IAM Permission Validator${NC}"
echo -e "${BLUE}=========================${NC}"
echo ""

# Function to clean up any existing test stacks
cleanup_old_test_stacks() {
    echo -e "${YELLOW}🧹 Checking for old test stacks...${NC}"
    
    local stacks_to_delete=()
    
    # Find any cedar-test-dryrun stacks in REVIEW_IN_PROGRESS
    while IFS=$'\t' read -r stack_name stack_status; do
        if [[ "$stack_name" == cedar-test-dryrun-* ]]; then
            stacks_to_delete+=("$stack_name")
        fi
    done < <(aws cloudformation list-stacks \
        --stack-status-filter REVIEW_IN_PROGRESS \
        --query "StackSummaries[*].[StackName,StackStatus]" \
        --output text 2>/dev/null)
    
    if [ ${#stacks_to_delete[@]} -gt 0 ]; then
        echo -e "${YELLOW}  Found ${#stacks_to_delete[@]} old test stack(s) to clean up${NC}"
        for stack in "${stacks_to_delete[@]}"; do
            echo -e "  Deleting: $stack"
            aws cloudformation delete-stack --stack-name "$stack" 2>/dev/null || true
        done
        echo -e "${GREEN}  ✅ Old test stacks cleaned up${NC}"
    else
        echo -e "${GREEN}  ✅ No old test stacks found${NC}"
    fi
    echo ""
}

# Function to extract actions from CloudFormation template
extract_cf_actions() {
    local template=$1
    echo -e "${YELLOW}Analyzing CloudFormation template: $template${NC}"
    
    # Extract resource types and map to required IAM actions
    local actions=()
    
    # Check for VerifiedPermissions resources
    if grep -q "AWS::VerifiedPermissions::PolicyStore" "$template" 2>/dev/null; then
        actions+=(
            "verifiedpermissions:CreatePolicyStore"
            "verifiedpermissions:GetPolicyStore"
            "verifiedpermissions:PutSchema"
            "verifiedpermissions:TagResource"
        )
    fi
    
    if grep -q "AWS::VerifiedPermissions::Policy" "$template" 2>/dev/null; then
        actions+=(
            "verifiedpermissions:CreatePolicy"
            "verifiedpermissions:GetPolicy"
        )
    fi
    
    # Check for IAM resources
    if grep -q "AWS::IAM::Role" "$template" 2>/dev/null; then
        actions+=(
            "iam:CreateRole"
            "iam:GetRole"
            "iam:PassRole"
            "iam:AttachRolePolicy"
            "iam:PutRolePolicy"
            "iam:TagRole"
        )
    fi
    
    # Check for S3 resources
    if grep -q "AWS::S3::Bucket" "$template" 2>/dev/null; then
        actions+=(
            "s3:CreateBucket"
            "s3:PutBucketEncryption"
            "s3:PutBucketPolicy"
            "s3:PutBucketTagging"
        )
    fi
    
    # Check for KMS resources
    if grep -q "AWS::KMS::Key" "$template" 2>/dev/null; then
        actions+=(
            "kms:CreateKey"
            "kms:CreateAlias"
            "kms:TagResource"
        )
    fi
    
    # Return unique actions
    printf '%s\n' "${actions[@]}" | sort -u
}

# Function to check if action is allowed in IAM policies
check_action_in_policies() {
    local action=$1
    local policy_dir="aws_iam_policies"
    local found=false
    local found_in=""
    
    # Search through all policy files
    for policy_file in "$policy_dir"/*.json; do
        if grep -q "\"$action\"" "$policy_file" 2>/dev/null; then
            found=true
            found_in=$(basename "$policy_file")
            break
        fi
    done
    
    if [ "$found" = true ]; then
        echo -e "  ✅ $action (found in $found_in)"
    else
        echo -e "  ${RED}❌ $action (MISSING)${NC}"
        return 1
    fi
}

# Function to validate CloudFormation template permissions
validate_cf_template() {
    local template=$1
    local required_actions
    required_actions=$(extract_cf_actions "$template")
    
    local missing_count=0
    
    echo -e "\n${BLUE}Required IAM actions for $template:${NC}"
    while IFS= read -r action; do
        if ! check_action_in_policies "$action"; then
            ((missing_count++))
        fi
    done <<< "$required_actions"
    
    if [ $missing_count -eq 0 ]; then
        echo -e "\n${GREEN}✅ All required permissions found${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Missing $missing_count permissions${NC}"
        return 1
    fi
}

# Function to simulate CloudFormation deployment
simulate_cf_deployment() {
    local template=$1
    echo -e "\n${YELLOW}🔄 Simulating CloudFormation deployment...${NC}"
    
    # Use AWS CLI to validate template
    if aws cloudformation validate-template --template-body "file://$template" >/dev/null 2>&1; then
        echo -e "  ✅ Template syntax valid"
    else
        echo -e "  ${RED}❌ Template syntax invalid${NC}"
        return 1
    fi
    
    # Check if we can create a change set (dry-run)
    local stack_name="cedar-test-dryrun-$(date +%s)"
    local change_set_name="test-changeset-$(date +%s)"
    
    # Setup trap to ensure cleanup on exit
    trap "aws cloudformation delete-stack --stack-name '$stack_name' 2>/dev/null || true" EXIT
    
    echo -e "  🔍 Creating change set for dry-run..."
    
    if aws cloudformation create-change-set \
        --stack-name "$stack_name" \
        --change-set-name "$change_set_name" \
        --template-body "file://$template" \
        --capabilities CAPABILITY_NAMED_IAM \
        --change-set-type CREATE \
        >/dev/null 2>&1; then
        
        echo -e "  ✅ Change set created successfully"
        
        # Clean up - delete the change set first, then the stack
        echo -e "  🧹 Cleaning up test resources..."
        aws cloudformation delete-change-set \
            --stack-name "$stack_name" \
            --change-set-name "$change_set_name" \
            >/dev/null 2>&1
        
        # Delete the stack to prevent REVIEW_IN_PROGRESS accumulation
        aws cloudformation delete-stack \
            --stack-name "$stack_name" \
            >/dev/null 2>&1
        
        echo -e "  ✅ Test stack cleaned up"
        
        # Clear the trap since we've cleaned up
        trap - EXIT
        
        return 0
    else
        echo -e "  ${RED}❌ Failed to create change set (likely permission issue)${NC}"
        return 1
    fi
}

# Main validation flow
main() {
    local exit_code=0
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  No AWS credentials configured. Skipping deployment simulation.${NC}"
        echo -e "${YELLOW}   To enable full validation, configure AWS credentials.${NC}"
    else
        # Clean up any old test stacks before starting
        cleanup_old_test_stacks
    fi
    
    # Validate main CloudFormation template
    echo -e "\n${BLUE}=== Validating Main CloudFormation Template ===${NC}"
    if [ -f "cf/avp-stack.yaml" ]; then
        validate_cf_template "cf/avp-stack.yaml" || exit_code=1
        
        # Only simulate if AWS creds are available
        if aws sts get-caller-identity >/dev/null 2>&1; then
            simulate_cf_deployment "cf/avp-stack.yaml" || exit_code=1
        fi
    fi
    
    # Validate example templates
    echo -e "\n${BLUE}=== Validating Example Templates ===${NC}"
    for template in examples/cloudformation/*.yaml; do
        if [ -f "$template" ]; then
            echo -e "\n${YELLOW}Checking $(basename "$template")...${NC}"
            validate_cf_template "$template" || exit_code=1
        fi
    done
    
    # Check for common missing permissions
    echo -e "\n${BLUE}=== Common Permission Patterns ===${NC}"
    
    # Check for tagging permissions
    echo -e "\n${YELLOW}Tag-related permissions:${NC}"
    for service in verifiedpermissions iam s3 kms; do
        action="${service}:TagResource"
        check_action_in_policies "$action" || true
    done
    
    # Check for describe/get permissions
    echo -e "\n${YELLOW}Read permissions:${NC}"
    for action in \
        "verifiedpermissions:GetPolicyStore" \
        "verifiedpermissions:GetSchema" \
        "iam:GetRole" \
        "s3:GetBucketEncryption" \
        "kms:DescribeKey"; do
        check_action_in_policies "$action" || true
    done
    
    # Summary
    echo -e "\n${BLUE}=== Summary ===${NC}"
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ All IAM permission checks passed!${NC}"
    else
        echo -e "${RED}❌ Some IAM permission issues found.${NC}"
        echo -e "${YELLOW}   Update the policies in aws_iam_policies/ and re-run.${NC}"
    fi
    
    return $exit_code
}

# Run main function
main "$@"
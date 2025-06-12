#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}☁️  CloudFormation Dry-Run Validator${NC}"
echo -e "${BLUE}===================================${NC}"

# Function to perform dry-run validation
dry_run_template() {
    local template=$1
    local stack_name_prefix=${2:-"cedar-dryrun"}
    
    echo -e "\n${YELLOW}🔍 Dry-run validation for: $(basename "$template")${NC}"
    
    # Generate unique names
    local timestamp=$(date +%s)
    local stack_name="${stack_name_prefix}-${timestamp}"
    local change_set_name="dryrun-changeset-${timestamp}"
    
    # Step 1: Validate template syntax
    echo -e "  📝 Validating template syntax..."
    if ! aws cloudformation validate-template --template-body "file://$template" >/dev/null 2>&1; then
        echo -e "  ${RED}❌ Template syntax validation failed${NC}"
        aws cloudformation validate-template --template-body "file://$template" 2>&1 | head -5
        return 1
    fi
    echo -e "  ${GREEN}✅ Template syntax valid${NC}"
    
    # Step 2: Create change set (dry-run)
    echo -e "  🔄 Creating change set for dry-run..."
    
    # Extract parameters from the template
    local params=""
    if [ "$(basename "$template")" = "avp-stack.yaml" ]; then
        params="--parameters ParameterKey=GitHubOrg,ParameterValue=DryRunTest ParameterKey=GitHubRepo,ParameterValue=cedar"
    fi
    
    local create_result
    if create_result=$(aws cloudformation create-change-set \
        --stack-name "$stack_name" \
        --change-set-name "$change_set_name" \
        --template-body "file://$template" \
        --capabilities CAPABILITY_NAMED_IAM \
        --change-set-type CREATE \
        $params \
        --output json 2>&1); then
        
        echo -e "  ${GREEN}✅ Change set created successfully${NC}"
        
        # Wait for change set to be ready
        echo -e "  ⏳ Waiting for change set to be ready..."
        local max_attempts=30
        local attempt=0
        
        while [ $attempt -lt $max_attempts ]; do
            local status
            status=$(aws cloudformation describe-change-set \
                --stack-name "$stack_name" \
                --change-set-name "$change_set_name" \
                --query 'Status' --output text 2>/dev/null || echo "FAILED")
            
            case $status in
                "CREATE_COMPLETE")
                    echo -e "  ${GREEN}✅ Change set ready${NC}"
                    break
                    ;;
                "FAILED")
                    echo -e "  ${RED}❌ Change set creation failed${NC}"
                    # Get failure reason
                    aws cloudformation describe-change-set \
                        --stack-name "$stack_name" \
                        --change-set-name "$change_set_name" \
                        --query 'StatusReason' --output text 2>/dev/null || true
                    return 1
                    ;;
                "CREATE_IN_PROGRESS"|"CREATE_PENDING")
                    echo -e "  ⏳ Still creating... (attempt $((attempt + 1))/$max_attempts)"
                    sleep 2
                    ;;
                *)
                    echo -e "  ${YELLOW}⚠️  Unexpected status: $status${NC}"
                    ;;
            esac
            
            ((attempt++))
        done
        
        if [ $attempt -eq $max_attempts ]; then
            echo -e "  ${RED}❌ Timeout waiting for change set${NC}"
            return 1
        fi
        
        # Step 3: Describe the changes that would be made
        echo -e "  📋 Resources that would be created/modified:"
        aws cloudformation describe-change-set \
            --stack-name "$stack_name" \
            --change-set-name "$change_set_name" \
            --query 'Changes[].{Action:Action,Resource:ResourceChange.LogicalResourceId,Type:ResourceChange.ResourceType}' \
            --output table 2>/dev/null || true
        
    else
        echo -e "  ${RED}❌ Failed to create change set${NC}"
        echo "$create_result" | head -10
        return 1
    fi
    
    # Step 4: Clean up
    echo -e "  🧹 Cleaning up dry-run resources..."
    aws cloudformation delete-change-set \
        --stack-name "$stack_name" \
        --change-set-name "$change_set_name" \
        >/dev/null 2>&1 || true
    
    # Also delete the stack if it was created in REVIEW_IN_PROGRESS state
    aws cloudformation delete-stack \
        --stack-name "$stack_name" \
        >/dev/null 2>&1 || true
    
    echo -e "  ${GREEN}✅ Dry-run completed successfully${NC}"
    return 0
}

# Function to check IAM permissions for CloudFormation operations
check_cf_permissions() {
    echo -e "\n${BLUE}🔐 Checking CloudFormation permissions...${NC}"
    
    # Test basic CloudFormation permissions
    local permissions_ok=true
    
    # Check if we can list stacks
    if aws cloudformation list-stacks --max-items 1 >/dev/null 2>&1; then
        echo -e "  ✅ cloudformation:ListStacks"
    else
        echo -e "  ${RED}❌ cloudformation:ListStacks${NC}"
        permissions_ok=false
    fi
    
    # Check if we can validate templates
    if aws cloudformation validate-template \
        --template-body '{"AWSTemplateFormatVersion":"2010-09-09","Resources":{"DummyParameter":{"Type":"AWS::SSM::Parameter","Properties":{"Name":"dummy","Type":"String","Value":"test"}}}}' \
        >/dev/null 2>&1; then
        echo -e "  ✅ cloudformation:ValidateTemplate"
    else
        echo -e "  ${RED}❌ cloudformation:ValidateTemplate${NC}"
        permissions_ok=false
    fi
    
    if [ "$permissions_ok" = false ]; then
        echo -e "\n${RED}❌ Some CloudFormation permissions are missing${NC}"
        return 1
    fi
    
    echo -e "\n${GREEN}✅ CloudFormation permissions look good${NC}"
    return 0
}

# Main function
main() {
    local exit_code=0
    
    # Check AWS credentials
    echo -e "${BLUE}🔑 Checking AWS credentials...${NC}"
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${RED}❌ No AWS credentials configured${NC}"
        echo -e "${YELLOW}   Configure AWS credentials to run CloudFormation dry-run validation${NC}"
        return 1
    fi
    
    local identity
    identity=$(aws sts get-caller-identity --output text --query 'Arn' 2>/dev/null)
    echo -e "${GREEN}✅ Using AWS identity: $identity${NC}"
    
    # Check CloudFormation permissions
    check_cf_permissions || exit_code=1
    
    # Validate main template
    if [ -f "cf/avp-stack.yaml" ]; then
        dry_run_template "cf/avp-stack.yaml" "cedar-main-dryrun" || exit_code=1
    else
        echo -e "${YELLOW}⚠️  Main template cf/avp-stack.yaml not found${NC}"
    fi
    
    # Validate example templates
    echo -e "\n${BLUE}📁 Validating example templates...${NC}"
    for template in examples/cloudformation/*.yaml; do
        if [ -f "$template" ]; then
            dry_run_template "$template" "cedar-example-dryrun" || exit_code=1
        fi
    done
    
    # Summary
    echo -e "\n${BLUE}=== Summary ===${NC}"
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ All CloudFormation dry-run validations passed!${NC}"
        echo -e "${GREEN}   Your templates should deploy successfully in GitHub Actions${NC}"
    else
        echo -e "${RED}❌ Some CloudFormation validations failed${NC}"
        echo -e "${YELLOW}   Fix the issues above before pushing to GitHub Actions${NC}"
    fi
    
    return $exit_code
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
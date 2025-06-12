#!/bin/bash
# Cleanup script for test CloudFormation stacks
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧹 CloudFormation Test Stack Cleanup${NC}"
echo -e "${BLUE}===================================${NC}"
echo ""

# Function to cleanup stacks by pattern
cleanup_stacks_by_pattern() {
    local pattern=$1
    local status_filter=$2
    local description=$3
    
    echo -e "${YELLOW}Searching for $description...${NC}"
    
    local stacks_to_delete=()
    
    # Find matching stacks
    while IFS=$'\t' read -r stack_name stack_status creation_time; do
        if [[ "$stack_name" =~ $pattern ]]; then
            stacks_to_delete+=("$stack_name")
            echo -e "  Found: $stack_name (Status: $stack_status, Created: $creation_time)"
        fi
    done < <(aws cloudformation list-stacks \
        --stack-status-filter $status_filter \
        --query "StackSummaries[*].[StackName,StackStatus,CreationTime]" \
        --output text 2>/dev/null)
    
    if [ ${#stacks_to_delete[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Found ${#stacks_to_delete[@]} stack(s) to clean up${NC}"
        
        # Confirm deletion
        echo -e "${YELLOW}Do you want to delete these stacks? (y/N)${NC}"
        read -r response
        
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            for stack in "${stacks_to_delete[@]}"; do
                echo -e "  Deleting: $stack"
                if aws cloudformation delete-stack --stack-name "$stack" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} Delete initiated for $stack"
                else
                    echo -e "  ${RED}✗${NC} Failed to delete $stack"
                fi
            done
            echo -e "\n${GREEN}✅ Cleanup initiated for ${#stacks_to_delete[@]} stack(s)${NC}"
        else
            echo -e "${YELLOW}Cleanup cancelled${NC}"
        fi
    else
        echo -e "${GREEN}✅ No stacks found matching pattern: $pattern${NC}"
    fi
    echo ""
}

# Main cleanup
main() {
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${RED}❌ No AWS credentials configured${NC}"
        echo -e "${YELLOW}Please configure AWS credentials and try again${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}AWS Account: $(aws sts get-caller-identity --query Account --output text)${NC}"
    echo -e "${BLUE}Region: ${AWS_REGION:-$(aws configure get region)}${NC}"
    echo ""
    
    # Clean up different types of test stacks
    cleanup_stacks_by_pattern "cedar-test-dryrun-" "REVIEW_IN_PROGRESS" "test stacks in REVIEW_IN_PROGRESS"
    cleanup_stacks_by_pattern "cedar-test-dryrun-" "CREATE_FAILED" "failed test stacks"
    cleanup_stacks_by_pattern "cedar-test-dryrun-" "DELETE_FAILED" "stacks with deletion issues"
    
    # Show current stack status
    echo -e "${BLUE}=== Current Stack Status ===${NC}"
    aws cloudformation list-stacks \
        --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
        --query "StackSummaries[?contains(StackName, 'cedar')].[StackName,StackStatus,LastUpdatedTime]" \
        --output table
    
    echo -e "\n${GREEN}✅ Cleanup process completed${NC}"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
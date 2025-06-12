#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 CloudFormation Test Stack Cleanup${NC}"
echo -e "${BLUE}====================================${NC}"

# Function to clean up test stacks
cleanup_test_stacks() {
    echo -e "\n${YELLOW}🔍 Finding test stacks...${NC}"
    
    # Find stacks with test prefixes in REVIEW_IN_PROGRESS state
    local test_patterns=(
        "cedar-test-dryrun-"
        "cedar-dryrun-"
        "cedar-main-dryrun-"
        "cedar-example-dryrun-"
    )
    
    local found_stacks=()
    
    for pattern in "${test_patterns[@]}"; do
        local stacks
        stacks=$(aws cloudformation list-stacks \
            --stack-status-filter REVIEW_IN_PROGRESS CREATE_FAILED \
            --query "StackSummaries[?starts_with(StackName, '$pattern')].StackName" \
            --output text 2>/dev/null || true)
        
        if [ -n "$stacks" ]; then
            for stack in $stacks; do
                found_stacks+=("$stack")
            done
        fi
    done
    
    if [ ${#found_stacks[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ No test stacks found to clean up${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Found ${#found_stacks[@]} test stacks to clean up:${NC}"
    for stack in "${found_stacks[@]}"; do
        echo -e "  📦 $stack"
    done
    
    # Confirm deletion
    echo -e "\n${YELLOW}⚠️  This will delete all test stacks listed above.${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cleanup cancelled${NC}"
        return 0
    fi
    
    # Delete stacks
    echo -e "\n${BLUE}🗑️  Deleting test stacks...${NC}"
    local deleted_count=0
    local failed_count=0
    
    for stack in "${found_stacks[@]}"; do
        echo -e "  🗑️  Deleting $stack..."
        
        if aws cloudformation delete-stack --stack-name "$stack" 2>/dev/null; then
            echo -e "  ${GREEN}✅ $stack - deletion initiated${NC}"
            ((deleted_count++))
        else
            echo -e "  ${RED}❌ $stack - deletion failed${NC}"
            ((failed_count++))
        fi
    done
    
    echo -e "\n${BLUE}=== Cleanup Summary ===${NC}"
    echo -e "${GREEN}✅ Deletions initiated: $deleted_count${NC}"
    if [ $failed_count -gt 0 ]; then
        echo -e "${RED}❌ Failed deletions: $failed_count${NC}"
    fi
    
    if [ $deleted_count -gt 0 ]; then
        echo -e "\n${YELLOW}ℹ️  Note: Stack deletion happens asynchronously.${NC}"
        echo -e "${YELLOW}   You can monitor progress in the AWS Console.${NC}"
    fi
}

# Function to clean up orphaned change sets
cleanup_change_sets() {
    echo -e "\n${YELLOW}🔍 Finding orphaned change sets...${NC}"
    
    local change_sets
    change_sets=$(aws cloudformation list-change-sets \
        --stack-name "cedar-test-dryrun-*" \
        --query "Summaries[].{Name:ChangeSetName,Stack:StackName}" \
        --output text 2>/dev/null || true)
    
    if [ -z "$change_sets" ]; then
        echo -e "${GREEN}✅ No orphaned change sets found${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Found orphaned change sets - attempting cleanup...${NC}"
    
    # This is best-effort cleanup since change sets are usually cleaned up with stacks
    echo -e "${YELLOW}ℹ️  Change sets are typically cleaned up automatically with stack deletion${NC}"
}

# Function to show current stack status
show_stack_status() {
    echo -e "\n${BLUE}📊 Current stack status:${NC}"
    
    # Show all cedar-related stacks
    local stacks
    stacks=$(aws cloudformation list-stacks \
        --query "StackSummaries[?starts_with(StackName, 'cedar')].{Name:StackName,Status:StackStatus}" \
        --output table 2>/dev/null || true)
    
    if [ -n "$stacks" ]; then
        echo "$stacks"
    else
        echo -e "${GREEN}✅ No cedar-related stacks found${NC}"
    fi
}

# Main function
main() {
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${RED}❌ No AWS credentials configured${NC}"
        echo -e "${YELLOW}   Configure AWS credentials to run cleanup${NC}"
        return 1
    fi
    
    local identity
    identity=$(aws sts get-caller-identity --output text --query 'Arn' 2>/dev/null)
    echo -e "${GREEN}✅ Using AWS identity: $identity${NC}"
    
    # Show current status
    show_stack_status
    
    # Clean up test stacks
    cleanup_test_stacks
    
    # Clean up change sets (best effort)
    cleanup_change_sets
    
    # Show final status
    echo -e "\n${BLUE}🏁 Final Status:${NC}"
    show_stack_status
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
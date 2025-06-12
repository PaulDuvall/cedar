#!/bin/bash
# Mock GitHub Actions runner - simulates all workflows without Docker/Act
set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}🎭 Mock GitHub Actions Runner${NC}"
echo "=============================="
echo ""

# Arrays to track workflow results (using parallel arrays for compatibility)
workflow_names=()
workflow_statuses=()

# Function to add workflow result
add_workflow_result() {
    local name="$1"
    local status="$2"
    workflow_names+=("$name")
    workflow_statuses+=("$status")
}

# Function to simulate a workflow
simulate_workflow() {
    local workflow_file="$1"
    local workflow_name=$(basename "$workflow_file" .yml)
    
    echo -e "${BLUE}Simulating: $workflow_file${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    case "$workflow_name" in
        "cedar-check")
            simulate_cedar_check_workflow
            ;;
        "atdd-validation")
            simulate_atdd_validation_workflow
            ;;
        "security-checks")
            simulate_security_checks_workflow
            ;;
        "s3-encryption-demo-fast"|"s3-encryption-demo-fastest"|"s3-encryption-demo-parallel")
            simulate_s3_encryption_workflow "$workflow_name"
            ;;
        "example-get-account-id")
            simulate_example_workflow "$workflow_name"
            ;;
        *)
            echo -e "${YELLOW}⚠${NC} Unknown workflow: $workflow_name (generic simulation)"
            simulate_generic_workflow "$workflow_file"
            ;;
    esac
    
    echo ""
}

# Cedar check workflow simulation
simulate_cedar_check_workflow() {
    echo -e "${BLUE}Job: validate${NC}"
    echo "─────────────────────────────"
    
    # Step 1: Checkout code
    echo -e "${GREEN}✓${NC} Checkout code (simulated)"
    
    # Step 2: Setup Rust (check if installed)
    echo -n "• Setup Rust and Cargo: "
    if command -v cargo &> /dev/null; then
        echo -e "${GREEN}✓${NC} (already installed)"
    else
        echo -e "${YELLOW}⚠${NC} (not installed - would be installed in CI)"
    fi
    
    # Step 3: Cache simulation
    echo -e "${GREEN}✓${NC} Cache Cargo Registry (simulated)"
    echo -e "${GREEN}✓${NC} Cache Cedar CLI Binary (simulated)"
    
    # Step 4: Cedar CLI
    echo -n "• Cedar CLI: "
    if command -v cedar &> /dev/null; then
        echo -e "${GREEN}✓${NC} $(cedar --version 2>&1)"
    else
        echo -e "${YELLOW}⚠${NC} Not installed (run ./scripts/install-cedar-fast.sh)"
        add_workflow_result "cedar-check" "failed"
        return 1
    fi
    
    # Step 5: Make scripts executable
    chmod +x "$ROOT_DIR"/scripts/*.sh
    echo -e "${GREEN}✓${NC} Make scripts executable"
    
    # Step 6: Run Cedar Tests
    echo "• Run Cedar Tests:"
    echo "────────────────"
    if "$ROOT_DIR/scripts/cedar_testrunner.sh"; then
        add_workflow_result "cedar-check" "passed"
        echo -e "${GREEN}✅ Validation job completed successfully!${NC}"
    else
        add_workflow_result "cedar-check" "failed"
        return 1
    fi
    
    # Check if we're on main branch for deploy job
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" = "main" ]; then
        echo -e "${BLUE}Job: deploy${NC}"
        echo "─────────────────────────────"
        echo -e "${YELLOW}ℹ${NC}  Deploy job would run (on main branch)"
        echo "   - Configure AWS Credentials (OIDC)"
        echo "   - Deploy CloudFormation Stack" 
        echo "   - Upload Cedar Policies to AVP"
    else
        echo -e "${YELLOW}ℹ${NC}  Deploy job skipped (not on main branch)"
    fi
}

# ATDD validation workflow simulation
simulate_atdd_validation_workflow() {
    echo -e "${BLUE}Job: atdd-tests${NC}"
    echo "─────────────────────────────"
    
    echo -e "${GREEN}✓${NC} Checkout code (simulated)"
    echo -e "${GREEN}✓${NC} Setup Python 3.12 (simulated)"
    
    # Check if Python and behave are available
    if command -v python3 &> /dev/null && python3 -c "import behave" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Install dependencies (already installed)"
        
        if [ -d "$ROOT_DIR/tests/atdd" ]; then
            echo "• Running ATDD tests..."
            cd "$ROOT_DIR/tests/atdd"
            if python3 -m behave --format=pretty --no-capture; then
                add_workflow_result "atdd-validation" "passed"
                echo -e "${GREEN}✅ ATDD tests completed successfully!${NC}"
            else
                add_workflow_result "atdd-validation" "failed"
                echo -e "${RED}✗${NC} ATDD tests failed"
            fi
            cd "$ROOT_DIR"
        else
            echo -e "${YELLOW}⚠${NC} ATDD tests directory not found"
            add_workflow_result "atdd-validation" "skipped"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Python/behave not available - tests would be installed and run in CI"
        add_workflow_result "atdd-validation" "skipped"
    fi
}

# Security checks workflow simulation
simulate_security_checks_workflow() {
    echo -e "${BLUE}Job: security-scan${NC}"
    echo "─────────────────────────────"
    
    echo -e "${GREEN}✓${NC} Checkout code (simulated)"
    
    # CodeQL Analysis
    echo -e "${BLUE}• CodeQL Analysis${NC}"
    echo -e "${YELLOW}ℹ${NC}  CodeQL would analyze JavaScript/TypeScript code"
    echo -e "${YELLOW}ℹ${NC}  Results would be uploaded to GitHub Security tab"
    
    # Dependency Review
    echo -e "${BLUE}• Dependency Review${NC}"
    echo -e "${YELLOW}ℹ${NC}  Would check for vulnerable dependencies on PRs"
    
    # TruffleHog Secret Scanning
    echo -e "${BLUE}• TruffleHog Secret Scanning${NC}"
    echo -e "${YELLOW}ℹ${NC}  Would scan for exposed secrets and credentials"
    
    # OSSF Scorecard
    echo -e "${BLUE}• OSSF Scorecard Analysis${NC}"
    echo -e "${YELLOW}ℹ${NC}  Would evaluate security best practices"
    
    add_workflow_result "security-checks" "simulated"
    echo -e "${GREEN}✅ Security checks simulation completed!${NC}"
}

# S3 encryption workflow simulation
simulate_s3_encryption_workflow() {
    local workflow_name="$1"
    echo -e "${BLUE}Job: check-encryption${NC}"
    echo "─────────────────────────────"
    
    echo -e "${GREEN}✓${NC} Checkout code (simulated)"
    echo -e "${YELLOW}ℹ${NC}  AWS credentials would be configured via OIDC"
    echo -e "${YELLOW}ℹ${NC}  Would check S3 buckets for encryption compliance"
    
    add_workflow_result "$workflow_name" "simulated"
}

# Example workflow simulation
simulate_example_workflow() {
    local workflow_name="$1"
    echo -e "${BLUE}Job: get-account-info${NC}"
    echo "─────────────────────────────"
    
    echo -e "${GREEN}✓${NC} Checkout code (simulated)"
    echo -e "${YELLOW}ℹ${NC}  AWS credentials would be configured via OIDC"
    echo -e "${YELLOW}ℹ${NC}  Would retrieve and display AWS account information"
    
    add_workflow_result "$workflow_name" "simulated"
}

# Generic workflow simulation
simulate_generic_workflow() {
    local workflow_file="$1"
    echo -e "${YELLOW}ℹ${NC}  Generic simulation for $workflow_file"
    echo -e "${YELLOW}ℹ${NC}  Would execute all jobs defined in the workflow"
    
    add_workflow_result "$(basename "$workflow_file" .yml)" "simulated"
}

# Main execution
main() {
    # Find all workflow files
    workflow_files=()
    while IFS= read -r file; do
        workflow_files+=("$file")
    done < <(find "$ROOT_DIR/.github/workflows" -name "*.yml" -o -name "*.yaml" | sort)
    
    if [ ${#workflow_files[@]} -eq 0 ]; then
        echo -e "${RED}No workflow files found in .github/workflows${NC}"
        exit 1
    fi
    
    echo "Found ${#workflow_files[@]} workflow(s) to simulate:"
    for file in "${workflow_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo ""
    
    # Simulate each workflow
    for workflow in "${workflow_files[@]}"; do
        simulate_workflow "$workflow"
    done
    
    # Summary
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Summary:${NC}"
    echo "─────────"
    
    local all_passed=true
    local i=0
    while [ $i -lt ${#workflow_names[@]} ]; do
        workflow="${workflow_names[$i]}"
        status="${workflow_statuses[$i]}"
        case "$status" in
            "passed")
                echo -e "  ${GREEN}✓${NC} $workflow: passed"
                ;;
            "failed")
                echo -e "  ${RED}✗${NC} $workflow: failed"
                all_passed=false
                ;;
            "skipped")
                echo -e "  ${YELLOW}⚠${NC} $workflow: skipped (dependencies not available)"
                ;;
            "simulated")
                echo -e "  ${BLUE}ℹ${NC}  $workflow: simulated (requires GitHub Actions environment)"
                ;;
        esac
        i=$((i + 1))
    done
    
    echo ""
    if [ "$all_passed" = true ]; then
        echo -e "${GREEN}✅ All runnable workflows passed!${NC}"
        echo "Use 'git push' to run the actual workflows on GitHub"
        return 0
    else
        echo -e "${RED}❌ Some workflows failed${NC}"
        echo "Fix the issues before pushing to GitHub"
        return 1
    fi
}

# Run main function
main "$@"
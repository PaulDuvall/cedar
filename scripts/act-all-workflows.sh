#!/bin/bash
# Run Act for all GitHub Actions workflows
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

echo -e "${BLUE}🎬 Act GitHub Actions Runner${NC}"
echo "=============================="
echo ""

# Check if Act is installed
if ! command -v act &> /dev/null; then
    echo -e "${RED}Act is not installed${NC}"
    echo "Install with: brew install act (macOS) or see https://github.com/nektos/act"
    echo ""
    echo "Falling back to mock simulation..."
    exec "$SCRIPT_DIR/mock-gha.sh"
fi

echo -e "${GREEN}✓${NC} Act version: $(act --version 2>&1 | head -1)"

# Check if Docker is running
if ! docker info &>/dev/null; then
    echo -e "${RED}Docker is not running${NC}"
    echo "Please start Docker Desktop and try again"
    echo ""
    echo "Falling back to mock simulation..."
    exec "$SCRIPT_DIR/mock-gha.sh"
fi

echo -e "${GREEN}✓${NC} Docker is running"
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

# Function to run a workflow with Act
run_workflow_with_act() {
    local workflow_file="$1"
    local workflow_name=$(basename "$workflow_file" .yml)
    
    echo -e "${BLUE}Running: $workflow_file${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Create a temporary directory for Act artifacts
    local act_dir="/tmp/act-${workflow_name}-$$"
    mkdir -p "$act_dir"
    
    # Determine which jobs to run based on workflow
    local act_args=""
    case "$workflow_name" in
        "cedar-check")
            # Only run validate job, skip deploy
            act_args="-j validate"
            ;;
        "atdd-validation")
            act_args="-j atdd-tests"
            ;;
        "security-checks")
            # Security checks require special handling
            echo -e "${YELLOW}⚠${NC} Security workflow requires GitHub-specific features"
            echo "  - CodeQL analysis"
            echo "  - Dependency review" 
            echo "  - Secret scanning"
            echo "  - OSSF Scorecard"
            echo "These will be simulated locally"
            add_workflow_result "$workflow_name" "simulated"
            echo ""
            return 0
            ;;
        "s3-encryption-demo-"*)
            # S3 workflows require AWS credentials
            echo -e "${YELLOW}⚠${NC} S3 workflow requires AWS credentials (OIDC)"
            echo "This will be simulated locally"
            add_workflow_result "$workflow_name" "simulated"
            echo ""
            return 0
            ;;
        "example-get-account-id")
            # Example workflow requires AWS credentials
            echo -e "${YELLOW}⚠${NC} Example workflow requires AWS credentials (OIDC)"
            echo "This will be simulated locally"
            add_workflow_result "$workflow_name" "simulated"
            echo ""
            return 0
            ;;
    esac
    
    # Run Act with timeout
    echo "Running Act (this may take a few minutes)..."
    if timeout 600 act $act_args \
        --workflows "$workflow_file" \
        --artifact-server-path "$act_dir" \
        --rm \
        2>&1 | tee "/tmp/act-${workflow_name}.log"; then
        add_workflow_result "$workflow_name" "passed"
        echo -e "${GREEN}✅ Workflow completed successfully!${NC}"
    else
        add_workflow_result "$workflow_name" "failed"
        echo -e "${RED}✗ Workflow failed${NC}"
        echo "Check /tmp/act-${workflow_name}.log for details"
    fi
    
    # Cleanup
    rm -rf "$act_dir"
    echo ""
}

# Main execution
main() {
    # Find all workflow files
    workflow_files=()
    while IFS= read -r -d '' file; do
        workflow_files+=("$file")
    done < <(find "$ROOT_DIR/.github/workflows" -name "*.yml" -o -name "*.yaml" | sort | tr '\n' '\0')
    
    if [ ${#workflow_files[@]} -eq 0 ]; then
        echo -e "${RED}No workflow files found in .github/workflows${NC}"
        exit 1
    fi
    
    echo "Found ${#workflow_files[@]} workflow(s) to run:"
    for file in "${workflow_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo ""
    
    # Ask user if they want to run all workflows
    echo -e "${YELLOW}Note:${NC} Running all workflows with Act can take significant time"
    echo "and resources. Some workflows may require specific secrets or"
    echo "GitHub-specific features that cannot be simulated locally."
    echo ""
    read -p "Do you want to continue? (y/N) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Use './scripts/mock-gha.sh' for a faster simulation"
        exit 0
    fi
    
    echo ""
    
    # Run each workflow
    for workflow in "${workflow_files[@]}"; do
        run_workflow_with_act "$workflow"
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
            "simulated")
                echo -e "  ${BLUE}ℹ${NC}  $workflow: simulated (requires GitHub environment)"
                ;;
        esac
        i=$((i + 1))
    done
    
    echo ""
    if [ "$all_passed" = true ]; then
        echo -e "${GREEN}✅ All runnable workflows passed!${NC}"
        echo "Push to GitHub to run the complete workflows"
        return 0
    else
        echo -e "${RED}❌ Some workflows failed${NC}"
        echo "Fix the issues before pushing to GitHub"
        return 1
    fi
}

# Run with specific workflow if provided
if [ $# -eq 1 ]; then
    workflow_file="$1"
    if [ -f "$workflow_file" ]; then
        run_workflow_with_act "$workflow_file"
        exit $?
    else
        echo -e "${RED}Workflow file not found: $workflow_file${NC}"
        exit 1
    fi
fi

# Otherwise run all workflows
main "$@"
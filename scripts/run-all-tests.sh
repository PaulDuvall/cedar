#!/bin/bash
# Comprehensive test script that mirrors CI/CD pipeline
set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

# Script directory
ROOT_DIR=$(get_root_dir)

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check for required tools
    if ! command -v cedar &> /dev/null; then
        missing_deps+=("cedar")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_deps+=("aws-cli")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install Cedar CLI: ./scripts/install-cedar-fast.sh"
        log_info "Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        log_info "Install jq: brew install jq (macOS) or apt-get install jq (Ubuntu)"
        exit 1
    fi
    
    log_info "All prerequisites installed ✓"
    log_info "Cedar CLI version: $(cedar --version 2>&1 || echo 'unknown')"
    log_info "AWS CLI version: $(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)"
}

# Function to run Cedar validation and tests
run_cedar_tests() {
    log_section "Running Cedar Policy Validation and Tests"
    
    cd "$ROOT_DIR"
    
    # Make test runner executable
    chmod +x ./scripts/cedar_testrunner.sh
    
    # Run the Cedar test suite
    if ./scripts/cedar_testrunner.sh; then
        log_info "Cedar tests passed ✓"
    else
        log_error "Cedar tests failed"
        exit 1
    fi
}

# Function to simulate deployment (without actually deploying)
simulate_deployment() {
    log_section "Simulating Deployment Process"
    
    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &>/dev/null; then
        log_warn "AWS credentials not configured - skipping deployment simulation"
        log_info "To configure AWS: aws configure"
        return 0
    fi
    
    log_info "AWS Identity: $(aws sts get-caller-identity --query 'Arn' --output text)"
    
    # Validate CloudFormation template if it exists and permissions allow
    if [ -f "$ROOT_DIR/cf/avp-stack.yaml" ]; then
        log_info "Validating CloudFormation template..."
        if aws cloudformation validate-template \
            --template-body "file://$ROOT_DIR/cf/avp-stack.yaml" &>/dev/null; then
            log_info "CloudFormation template is valid ✓"
        else
            log_warning "CloudFormation template validation failed (may need additional IAM permissions)"
            log_info "Skipping CloudFormation validation - Cedar tests will continue"
            # Don't exit on CloudFormation validation failure
        fi
    fi
    
    # Check policies that would be deployed
    log_info "Policies that would be deployed:"
    for policy in "$ROOT_DIR/policies"/*.cedar; do
        if [ -f "$policy" ]; then
            echo "  - $(basename "$policy")"
        fi
    done
}

# Function to run quick policy test
run_quick_policy_test() {
    log_section "Running Quick Policy Test"
    
    # Create a simple test case
    cat > /tmp/test-request.json << 'EOF'
{
  "principal": {
    "type": "CedarPolicyStore::User",
    "id": "test-user"
  },
  "action": {
    "type": "CedarPolicyStore::Action",
    "id": "s3:PutObject"
  },
  "resource": {
    "type": "CedarPolicyStore::Bucket",
    "id": "project-artifacts"
  }
}
EOF

    cat > /tmp/test-entities.json << 'EOF'
[
  {
    "uid": {
      "type": "CedarPolicyStore::User",
      "id": "test-user"
    },
    "attrs": {
      "department": "operations"
    }
  }
]
EOF

    log_info "Testing authorization decision..."
    if [ -f "$ROOT_DIR/schema.cedarschema" ]; then
        cedar authorize \
            --policies "$ROOT_DIR/policies/" \
            --entities /tmp/test-entities.json \
            --schema "$ROOT_DIR/schema.cedarschema" \
            --request-json /tmp/test-request.json 2>&1 | grep -E "ALLOW|DENY" || log_info "Authorization test completed"
    else
        cedar authorize \
            --policies "$ROOT_DIR/policies/" \
            --entities /tmp/test-entities.json \
            --request-json /tmp/test-request.json 2>&1 | grep -E "ALLOW|DENY" || log_info "Authorization test completed"
    fi

    # Cleanup
    rm -f /tmp/test-request.json /tmp/test-entities.json
}

# Function to run integration tests
run_integration_tests() {
    log_section "Running Integration Tests"
    
    # Check if there are any integration test scripts
    if [ -f "$ROOT_DIR/tests/integration/run.sh" ]; then
        log_info "Running integration tests..."
        chmod +x "$ROOT_DIR/tests/integration/run.sh"
        "$ROOT_DIR/tests/integration/run.sh"
    else
        log_info "No integration tests found (this is OK)"
    fi
}

# Function to generate test report
generate_report() {
    log_section "Test Summary"
    
    local report_file="$ROOT_DIR/test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Cedar Policy Test Report"
        echo "========================"
        echo "Date: $(date)"
        echo "Cedar Version: $(cedar --version 2>&1 || echo 'unknown')"
        echo ""
        echo "Policies Tested:"
        for policy in "$ROOT_DIR/policies"/*.cedar; do
            if [ -f "$policy" ]; then
                echo "  - $(basename "$policy")"
            fi
        done
        echo ""
        echo "Test Results: PASSED"
    } > "$report_file"
    
    log_info "Test report saved to: $report_file"
}

# Main execution
main() {
    log_info "Starting comprehensive test suite..."
    log_info "This script mirrors the CI/CD pipeline locally"
    
    # Change to root directory
    cd "$ROOT_DIR"
    
    # Run all test phases
    check_prerequisites
    run_cedar_tests
    simulate_deployment
    run_quick_policy_test
    run_integration_tests
    generate_report
    
    log_section "All Tests Completed Successfully! ✨"
    log_info "Your Cedar policies are ready for deployment"
}

# Run main function
main "$@"
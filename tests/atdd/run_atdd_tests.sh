#!/bin/bash
# ATDD Test Runner for Cedar Policy Validation
# This script runs the Acceptance Test-Driven Development tests

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    log_section "Checking ATDD Prerequisites"
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required for ATDD tests"
        log_info "Install Python 3: https://python.org/downloads"
        exit 1
    fi
    
    log_info "Python 3 available: $(python3 --version)"
    
    # Check Cedar CLI
    if ! command -v cedar &> /dev/null; then
        log_error "Cedar CLI is required"
        log_info "Install Cedar CLI: $ROOT_DIR/scripts/install-cedar-fast.sh"
        exit 1
    fi
    
    log_info "Cedar CLI available: $(cedar --version)"
    
    # Check if behave is installed
    if ! python3 -c "import behave" 2>/dev/null; then
        log_warn "Behave framework not installed"
        log_info "Installing behave and dependencies..."
        
        if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
            pip3 install -r "$SCRIPT_DIR/requirements.txt"
        else
            pip3 install behave
        fi
    fi
    
    log_info "Behave framework available"
}

# Function to setup test environment
setup_test_environment() {
    log_section "Setting Up Test Environment"
    
    # Create reports directory
    mkdir -p "$SCRIPT_DIR/reports"
    
    # Verify test fixtures exist
    if [ ! -d "$SCRIPT_DIR/fixtures" ]; then
        log_error "Test fixtures directory not found"
        exit 1
    fi
    
    # Verify Cedar policies exist
    if [ ! -d "$ROOT_DIR/policies" ]; then
        log_error "Cedar policies directory not found"
        exit 1
    fi
    
    # Verify Cedar schema exists
    if [ ! -f "$ROOT_DIR/schema.cedarschema" ]; then
        log_error "Cedar schema file not found"
        exit 1
    fi
    
    log_info "Test environment ready"
}

# Function to run ATDD tests
run_atdd_tests() {
    log_section "Running ATDD Tests"
    
    cd "$SCRIPT_DIR"
    
    # Run behave with configuration
    log_info "Executing ATDD test scenarios..."
    
    # Set environment variables for the tests
    export CEDAR_ROOT_DIR="$ROOT_DIR"
    export CEDAR_POLICIES_DIR="$ROOT_DIR/policies"
    export CEDAR_SCHEMA_FILE="$ROOT_DIR/schema.cedarschema"
    
    # Run the tests
    if python3 -m behave \
        --format=pretty \
        --format=json.pretty:reports/atdd-results.json \
        --no-capture \
        --show-timings \
        "$@"; then
        log_info "ATDD tests completed successfully ✓"
        return 0
    else
        log_error "ATDD tests failed"
        return 1
    fi
}

# Function to generate test report
generate_report() {
    log_section "Generating Test Report"
    
    local report_file="$SCRIPT_DIR/reports/atdd-summary-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Cedar ATDD Test Report"
        echo "======================"
        echo "Date: $(date)"
        echo "Cedar Version: $(cedar --version 2>&1 || echo 'unknown')"
        echo "Python Version: $(python3 --version)"
        echo ""
        echo "Test Environment:"
        echo "  Root Directory: $ROOT_DIR"
        echo "  Policies Directory: $ROOT_DIR/policies"
        echo "  Schema File: $ROOT_DIR/schema.cedarschema"
        echo ""
        
        if [ -f "$SCRIPT_DIR/reports/atdd-results.json" ]; then
            echo "Detailed results available in: reports/atdd-results.json"
        fi
        
        echo ""
        echo "Test Status: COMPLETED"
    } > "$report_file"
    
    log_info "ATDD test report saved to: $report_file"
}

# Function to clean up test artifacts
cleanup_test_artifacts() {
    log_section "Cleaning Up Test Artifacts"
    
    # Remove temporary files created during testing
    rm -f /tmp/cedar-atdd-*
    
    # Keep reports but clean up old ones (older than 7 days)
    if [ -d "$SCRIPT_DIR/reports" ]; then
        find "$SCRIPT_DIR/reports" -name "atdd-summary-*.txt" -mtime +7 -delete 2>/dev/null || true
    fi
    
    log_info "Test artifacts cleaned up"
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Run Cedar ATDD (Acceptance Test-Driven Development) tests"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -t, --tags TAGS     Run only tests with specific tags"
    echo "  -f, --format FORMAT Output format (pretty, json, html)"
    echo "  -v, --verbose       Verbose output"
    echo "  --dry-run           Run tests in dry-run mode"
    echo ""
    echo "Examples:"
    echo "  $0                          # Run all ATDD tests"
    echo "  $0 -t @shift-left          # Run only shift-left tests"
    echo "  $0 -t @consistency         # Run only consistency tests"
    echo "  $0 --dry-run               # Validate test scenarios without execution"
}

# Main execution
main() {
    local tags=""
    local format="pretty"
    local verbose=false
    local dry_run=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -t|--tags)
                tags="--tags=$2"
                shift 2
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    log_info "Starting Cedar ATDD Test Suite..."
    
    # Build behave arguments
    local behave_args=()
    if [ -n "$tags" ]; then
        behave_args+=("$tags")
    fi
    if [ "$verbose" = true ]; then
        behave_args+=("--verbose")
    fi
    if [ "$dry_run" = true ]; then
        behave_args+=("--dry-run")
    fi
    
    # Execute test phases
    check_prerequisites
    setup_test_environment
    
    if run_atdd_tests "${behave_args[@]}"; then
        generate_report
        cleanup_test_artifacts
        log_section "ATDD Tests Completed Successfully! ✨"
        log_info "Shift-left security validation verified ✓"
    else
        log_error "ATDD tests failed"
        log_info "Check the test output above for details"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"
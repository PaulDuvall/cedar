#!/bin/bash
# Enhanced Cedar policy test runner
set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

# Directories using common utilities
ROOT_DIR=$(get_root_dir)
POLICIES_DIR="${ROOT_DIR}/cedar_policies"
SCHEMA_FILE="${ROOT_DIR}/schema.cedarschema"
TEST_SUITES_DIR="${ROOT_DIR}/tests"
FIXTURES_DIR="${ROOT_DIR}/tests/fixtures"

# Check if Cedar CLI is installed using common utility
if ! check_command "cedar" "Cedar CLI is not installed. You can install it by running: ./scripts/install-cedar-fast.sh"; then
    exit 1
fi

# Function to check if schema file exists
check_schema() {
    if [ ! -f "$SCHEMA_FILE" ]; then
        echo -e "${YELLOW}Warning: Schema file not found at $SCHEMA_FILE${NC}"
        echo "Validation will proceed without schema validation"
        return 1
    fi
    return 0
}

# Function to validate a single policy file
validate_policy() {
    local policy_file="$1"
    echo -n "Validating $(basename "$policy_file")... "
    
    # Check if schema exists and use appropriate validation
    if check_schema; then
        if cedar validate --schema "$SCHEMA_FILE" --policies "$policy_file" &>/dev/null; then
            echo -e "${GREEN}PASS${NC}"
            return 0
        else
            echo -e "${RED}FAILED${NC}"
            cedar validate --schema "$SCHEMA_FILE" --policies "$policy_file" || true
            return 1
        fi
    else
        # Validate without schema
        if cedar validate --policies "$policy_file" &>/dev/null; then
            echo -e "${GREEN}PASS${NC}"
            return 0
        else
            echo -e "${RED}FAILED${NC}"
            cedar validate --policies "$policy_file" || true
            return 1
        fi
    fi
}

# Function to run a test file
run_test() {
    local test_file="$1"
    local expected_decision="$2"
    local test_name="$(basename "${test_file%.json}")"
    
    echo -n "Test ${test_name} (expect: ${expected_decision})... "
    
    # Check if entities file exists
    if [ ! -f "$FIXTURES_DIR/entities.json" ]; then
        echo -e "${YELLOW}SKIP${NC} (no entities.json)"
        return 0
    fi
    
    # Run the test and capture the output
    local output
    if check_schema; then
        output=$(cedar authorize \
            --policies "$POLICIES_DIR" \
            --entities "$FIXTURES_DIR/entities.json" \
            --schema "$SCHEMA_FILE" \
            --request-json "$test_file" 2>&1)
    else
        output=$(cedar authorize \
            --policies "$POLICIES_DIR" \
            --entities "$FIXTURES_DIR/entities.json" \
            --request-json "$test_file" 2>&1)
    fi
    
    # Check if the output contains the expected decision
    if echo "$output" | grep -q "$expected_decision"; then
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Expected: $expected_decision"
        echo "  Got: $output"
        return 1
    fi
}

# Main execution
echo "🚀 Starting Cedar Policy Test Runner"
echo "================================"

# Validate all policies
echo "🔍 Validating policies..."
POLICY_FILES=("$POLICIES_DIR"/*.cedar)
if [ ${#POLICY_FILES[@]} -eq 0 ]; then
    echo -e "${RED}No policy files found in $POLICIES_DIR${NC}"
    exit 1
fi

for policy in "${POLICY_FILES[@]}"; do
    validate_policy "$policy" || exit 1
done

# Run tests if they exist
if [ -d "$TEST_SUITES_DIR" ]; then
    echo -e "\n🧪 Running test suites..."
    
    # Check for test suites
    shopt -s nullglob
    test_suites=("$TEST_SUITES_DIR"/*/)
    
    if [ ${#test_suites[@]} -eq 0 ]; then
        echo -e "ℹ️  No test suites found in $TEST_SUITES_DIR"
    else
        for suite in "${test_suites[@]}"; do
            suite_name=$(basename "$suite")
            echo -e "\n📂 Test Suite: $suite_name"
            
            # Run ALLOW tests
            if [ -d "${suite}ALLOW" ]; then
                echo "  ALLOW tests:"
                for test_file in "${suite}ALLOW"/*.json; do
                    [ -f "$test_file" ] || continue
                    run_test "$test_file" "ALLOW" || exit 1
                done
            fi
            
            # Run DENY tests
            if [ -d "${suite}DENY" ]; then
                echo "  DENY tests:"
                for test_file in "${suite}DENY"/*.json; do
                    [ -f "$test_file" ] || continue
                    run_test "$test_file" "DENY" || exit 1
                done
            fi
        done
    fi
fi

echo -e "\n✅ All tests completed successfully!"

# Print Cedar CLI version for debugging
echo -e "\nCedar CLI version: $(cedar --version 2>&1 || echo 'unknown')"
exit 0

#!/bin/bash
# Quick validation script for Cedar policies
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🚀 Quick Cedar Validation"
echo "======================="

# Check Cedar installation
if ! command -v cedar &> /dev/null; then
    echo -e "${RED}Error: Cedar CLI not installed${NC}"
    echo "Run: ./scripts/install-cedar-fast.sh"
    exit 1
fi

# Validate each policy individually (matching the test runner behavior)
for policy in policies/*.cedar; do
    if [ -f "$policy" ]; then
        echo -n "Validating $(basename "$policy")... "
        if [ -f "schema.cedarschema" ]; then
            if cedar validate --schema schema.cedarschema --policies "$policy" &>/dev/null; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
                cedar validate --schema schema.cedarschema --policies "$policy"
                exit 1
            fi
        else
            if cedar validate --policies "$policy" &>/dev/null; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
                cedar validate --policies "$policy"
                exit 1
            fi
        fi
    fi
done

echo -e "\n${GREEN}All policies valid!${NC}"
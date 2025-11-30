#!/usr/bin/env bash
# Check if all required tools for integration tests are available

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Checking integration test requirements..."
echo ""

ALL_OK=true

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is not installed"
        ALL_OK=false
        return 1
    fi
}

# Required tools
check_command docker

# Optional but recommended
if check_command aws; then
    echo "  AWS CLI version: $(aws --version 2>&1 | head -n1)"
fi

if check_command jq; then
    echo "  jq version: $(jq --version 2>&1)"
else
    echo -e "  ${YELLOW}Note: jq is optional but recommended for better output${NC}"
fi

# Check Docker daemon
echo ""
if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker daemon is running"
else
    echo -e "${RED}✗${NC} Docker daemon is not running"
    ALL_OK=false
fi

echo ""
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}All required tools are available! Ready to run integration tests.${NC}"
    exit 0
else
    echo -e "${RED}Some required tools are missing. Please install them first.${NC}"
    exit 1
fi

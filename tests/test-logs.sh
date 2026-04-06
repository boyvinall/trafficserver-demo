#!/bin/bash
# Test ATS cluster logs for warnings and errors
# Verifies that ATS nodes are running without issues
#
# Usage:
#   ./test-logs.sh                    # Check logs from running docker compose services
#   ./test-logs.sh <file1> [file2...]  # Check specific log files (useful for CI artifacts)
#
# Examples:
#   ./test-logs.sh                          # Live check of docker services
#   ./test-logs.sh ats-logs.txt             # Check downloaded CI artifact
#   ./test-logs.sh node1.log node2.log      # Check multiple log files

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ATS Logs Test ===${NC}"
echo ""

TMPDIR=$(mktemp -d)
LOGS_FILE="$TMPDIR/ats-logs.txt"

# Check if log files were provided as arguments
if [ $# -gt 0 ]; then
    echo -e "${YELLOW}Checking provided log files: $*${NC}"
    echo ""

    # Concatenate all provided files
    for file in "$@"; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}✗ FAIL: File not found: $file${NC}"
            rm -rf "$TMPDIR"
            exit 1
        fi
        cat "$file" >> "$LOGS_FILE"
    done
else
    # Check if docker-compose is running
    if ! docker compose ps | grep -q "ats-"; then
        echo -e "${RED}✗ FAIL: Docker compose services not running${NC}"
        exit 1
    fi

    # Get logs from all ATS nodes
    echo -e "${YELLOW}Fetching logs from ats-1, ats-2, ats-3...${NC}"
    echo ""

    # Capture logs from all three ATS nodes
    docker compose logs ats-1 ats-2 ats-3 > "$LOGS_FILE" 2>&1
fi

# Count total lines
TOTAL_LINES=$(wc -l < "$LOGS_FILE")
echo "Total log lines: $TOTAL_LINES"
echo ""

# Check for various error patterns
ERRORS=0
WARNINGS=0

# Pattern matching (case-insensitive)
ERROR_PATTERNS=(
    "ERROR"
    "FATAL"
    "CRITICAL"
    "panic"
    "segfault"
    "core dump"
)

WARNING_PATTERNS=(
    "WARNING"
    "WARN"
)

echo -e "${YELLOW}Checking for errors...${NC}"
for pattern in "${ERROR_PATTERNS[@]}"; do
    COUNT=$(grep -i "$pattern" "$LOGS_FILE" | grep -vc "level=info")
    if [ "$COUNT" -gt 0 ]; then
        echo -e "${RED}  Found $COUNT line(s) matching '$pattern'${NC}"
        ERRORS=$((ERRORS + COUNT))
        # Show first few examples
        grep -i "$pattern" "$LOGS_FILE" | grep -v "level=info" | head -3 | sed 's/^/    /'
        if [ "$COUNT" -gt 3 ]; then
            echo "    ... ($((COUNT - 3)) more)"
        fi
    fi
done

echo ""
echo -e "${YELLOW}Checking for warnings...${NC}"
for pattern in "${WARNING_PATTERNS[@]}"; do
    COUNT=$(grep -i "$pattern" "$LOGS_FILE" | grep -vc "level=info")
    if [ "$COUNT" -gt 0 ]; then
        echo -e "${YELLOW}  Found $COUNT line(s) matching '$pattern'${NC}"
        WARNINGS=$((WARNINGS + COUNT))
        # Show first few examples
        grep -i "$pattern" "$LOGS_FILE" | grep -v "level=info" | head -3 | sed 's/^/    /'
        if [ "$COUNT" -gt 3 ]; then
            echo "    ... ($((COUNT - 3)) more)"
        fi
    fi
done

# Cleanup
rm -rf "$TMPDIR"

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All logs clean! No warnings or errors found.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Found $WARNINGS warning(s) but no errors.${NC}"
    exit 0
else
    echo -e "${RED}✗ FAIL: Found $ERRORS error(s) in logs!${NC}"
    exit 1
fi

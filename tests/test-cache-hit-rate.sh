#!/bin/bash
# Test consistent hashing and cache hit rates
# Verifies that the same URL always goes to the same ATS node

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Consistent Hashing Test ===${NC}"
echo ""

# Test that same URL goes to same node
echo -e "${YELLOW}Testing /page1 (should always hit same ATS node)${NC}"
NODES=()
for i in {1..10}; do
    VIA=$(curl -s -I http://localhost/page1 | grep -i "^via:" | awk '{print $3}' || echo "unknown")
    NODES+=("$VIA")
    echo "  Request $i: $VIA"
done

# Check if all requests went to the same node
UNIQUE=$(printf '%s\n' "${NODES[@]}" | sort -u | wc -l)
if [ "$UNIQUE" -eq 1 ]; then
    echo -e "${GREEN}✓ Consistent hashing working! All requests hit ${NODES[0]}${NC}"
else
    echo -e "${RED}✗ Inconsistent! Requests went to $UNIQUE different nodes${NC}"
fi

echo ""
echo -e "${YELLOW}Testing /page2 (should always hit same ATS node, possibly different from page1)${NC}"
NODES2=()
for i in {1..5}; do
    VIA=$(curl -s -I http://localhost/page2 | grep -i "^via:" | awk '{print $3}' || echo "unknown")
    NODES2+=("$VIA")
    echo "  Request $i: $VIA"
done

UNIQUE2=$(printf '%s\n' "${NODES2[@]}" | sort -u | wc -l)
if [ "$UNIQUE2" -eq 1 ]; then
    echo -e "${GREEN}✓ Consistent hashing working! All requests hit ${NODES2[0]}${NC}"
else
    echo -e "${RED}✗ Inconsistent! Requests went to $UNIQUE2 different nodes${NC}"
fi

echo ""
echo -e "${BLUE}=== Cache Hit Rate Test ===${NC}"
echo ""

# First request should be MISS
echo -e "${YELLOW}First request (should be MISS):${NC}"
HEADERS=$(curl -s -I http://localhost/page3)
echo "$HEADERS" | grep -iE "via:|x-cache|age" || echo "No cache headers found"

# Wait a second
sleep 1

# Second request should be HIT
echo ""
echo -e "${YELLOW}Second request (should be HIT):${NC}"
HEADERS=$(curl -s -I http://localhost/page3)
echo "$HEADERS" | grep -iE "via:|x-cache|age" || echo "No cache headers found"

# Check if Age header increased (indicating cached content)
AGE=$(echo "$HEADERS" | grep -i "^age:" | awk '{print $2}' | tr -d '\r' || echo "0")
if [ "$AGE" -gt 0 ]; then
    echo -e "${GREEN}✓ Cache hit! Age: ${AGE}s${NC}"
else
    echo -e "${YELLOW}⚠ Cache miss or Age header not present${NC}"
fi

echo ""
echo -e "${GREEN}Test complete!${NC}"
echo ""
echo "Tips:"
echo "  - Same URL should always route to same ATS node (consistent hashing)"
echo "  - Second+ requests should show Age header (cache hit)"
echo "  - Check Grafana at http://localhost:3000 for detailed metrics"

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

# Function to check ATS cache statistics
check_cache_stats() {
    echo -e "${YELLOW}Checking ATS cache statistics...${NC}"

    STATS=$(docker exec ats-node-1 curl -s http://localhost:8080/_stats 2>/dev/null | grep -E "proxy.process.cache.ram_cache" || echo "")

    if [ -z "$STATS" ]; then
        echo -e "${RED}✗ Could not retrieve cache stats${NC}"
        return 1
    fi

    HITS=$(echo "$STATS" | grep "ram_cache.hits" | awk '{print $2}' | tr -d '",')
    MISSES=$(echo "$STATS" | grep "ram_cache.misses" | awk '{print $2}' | tr -d '",')

    echo "  RAM Cache Hits: ${HITS:-0}"
    echo "  RAM Cache Misses: ${MISSES:-0}"

    if [ "${HITS:-0}" -gt 0 ]; then
        RATIO=$(awk "BEGIN {printf \"%.1f\", (${HITS}/(${HITS}+${MISSES}))*100}")
        echo -e "${GREEN}  Hit Rate: ${RATIO}%${NC}"
    else
        echo -e "${YELLOW}  No cache hits yet${NC}"
    fi
}

echo ""
check_cache_stats
echo ""

echo -e "${BLUE}=== Cache Hit Rate Test ===${NC}"
echo ""

# Purge page3 from cache to ensure first request is a MISS
echo -e "${YELLOW}Purging /page3 from cache...${NC}"
curl -s -X PURGE http://localhost/page3 -o /dev/null
sleep 1

# First request should be MISS
echo -e "${YELLOW}First request (should be MISS):${NC}"
# Use GET request instead of HEAD (-I) since ATS doesn't cache HEAD requests
HEADERS=$(curl -s -o /dev/null -D - http://localhost/page3)
echo "$HEADERS" | grep -iE "via:|x-cache|age" || echo "No cache headers found"

# Verify first request was a MISS (Age should be 0 or not present)
FIRST_AGE=$(echo "$HEADERS" | grep -i "^age:" | awk '{print $2}' | tr -d '\r' || echo "0")
if [ "$FIRST_AGE" -gt 0 ]; then
    echo -e "${RED}✗ First request was cached! Age: ${FIRST_AGE}s (expected: 0)${NC}"
    echo -e "${RED}   This indicates the cache was not properly purged.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Cache miss! Age: ${FIRST_AGE}s${NC}"

# Wait a second
sleep 1

# Second request should be HIT
echo ""
echo -e "${YELLOW}Second request (should be HIT):${NC}"
# Use GET request instead of HEAD (-I) since ATS doesn't cache HEAD requests
HEADERS=$(curl -s -o /dev/null -D - http://localhost/page3)
echo "$HEADERS" | grep -iE "via:|x-cache|age" || echo "No cache headers found"

# Check if Age header increased (indicating cached content)
AGE=$(echo "$HEADERS" | grep -i "^age:" | awk '{print $2}' | tr -d '\r' || echo "0")
if [ "$AGE" -gt 0 ]; then
    echo -e "${GREEN}✓ Cache hit! Age: ${AGE}s${NC}"
else
    echo -e "${RED}✗ Cache miss! Age header not present or Age is 0${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Test complete!${NC}"
echo ""
echo "Tips:"
echo "  - Same URL should always route to same ATS node (consistent hashing)"
echo "  - Second+ requests should show Age header (cache hit)"
echo "  - Check Grafana at http://localhost:3000 for detailed metrics"

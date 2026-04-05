#!/bin/bash
# Load test for ATS cluster
# Generates traffic to observe cache behavior

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ATS Cluster Load Test ===${NC}"
echo ""

# Configuration
REQUESTS=100
CONCURRENCY=10
URLS=(
    "/"
    "/page1"
    "/page2"
    "/page3"
    "/api/users"
    "/api/products"
    "/static/styles.css"
    "/static/app.js"
)

echo -e "${YELLOW}Configuration:${NC}"
echo "  Total requests: $REQUESTS"
echo "  Concurrency: $CONCURRENCY"
echo "  URLs: ${#URLS[@]}"
echo ""

# Check if ab (Apache Bench) is available
if ! command -v ab &> /dev/null; then
    echo -e "${YELLOW}Apache Bench (ab) not found. Using curl instead.${NC}"

    echo -e "${BLUE}Sending requests...${NC}"
    for ((i=1; i<=$REQUESTS; i++)); do
        # Pick a random URL
        URL=${URLS[$RANDOM % ${#URLS[@]}]}

        # Make request in background
        curl -s -o /dev/null http://localhost$URL &

        # Show progress every 10 requests
        if [ $((i % 10)) -eq 0 ]; then
            echo -n "."
        fi

        # Limit concurrency
        if [ $(jobs -r | wc -l) -ge $CONCURRENCY ]; then
            wait -n
        fi
    done

    # Wait for all background jobs
    wait
    echo ""
    echo -e "${GREEN}✓ Completed $REQUESTS requests${NC}"

else
    # Use Apache Bench
    echo -e "${BLUE}Using Apache Bench for load testing...${NC}"

    for URL in "${URLS[@]}"; do
        echo ""
        echo -e "${YELLOW}Testing: http://localhost$URL${NC}"
        ab -n $REQUESTS -c $CONCURRENCY -q "http://localhost$URL" 2>&1 | grep -E "Requests per second|Time per request|Failed requests"
    done
fi

echo ""
echo -e "${BLUE}=== Load Test Complete ===${NC}"
echo ""
echo "Check the results:"
echo "  - Grafana: http://localhost:3000"
echo "  - Prometheus: http://localhost:9090"
echo "  - HAProxy Stats: http://localhost:8404/stats"
echo ""
echo "Expected behavior:"
echo "  - Cache hit rate should increase over time"
echo "  - Same URLs should consistently hit same ATS nodes"
echo "  - All 3 ATS nodes should receive traffic (different URLs)"
echo "  - Response times should decrease as cache warms up"

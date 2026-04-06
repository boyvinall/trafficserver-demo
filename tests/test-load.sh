#!/bin/bash
# Load test for ATS cluster
# Generates traffic to observe cache behavior using Vegeta

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ATS Cluster Load Test ===${NC}"
echo ""

# Configuration
RATE=10              # requests per second
DURATION=10s         # test duration
WORKERS=10           # concurrent workers
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
echo "  Rate: $RATE req/s"
echo "  Duration: $DURATION"
echo "  Workers: $WORKERS"
echo "  URLs: ${#URLS[@]}"
echo ""

# Generate targets file for Vegeta
TARGETS_FILE=$(mktemp)
trap 'rm -f "$TARGETS_FILE"' EXIT

for URL in "${URLS[@]}"; do
    echo "GET http://host.docker.internal$URL" >> "$TARGETS_FILE"
done

echo -e "${BLUE}Running load test with Vegeta...${NC}"
echo ""

# Run Vegeta attack using Docker
docker run --rm -i \
    peterevans/vegeta \
    vegeta attack -rate=$RATE -duration=$DURATION -workers=$WORKERS < "$TARGETS_FILE" \
    | docker run --rm -i peterevans/vegeta vegeta report -type=text

echo ""
echo -e "${GREEN}✓ Load test completed${NC}"

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

#!/bin/bash
# Smoke test for ATS cluster
# Verifies all services are running and responding

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== ATS Cluster Smoke Test ===${NC}"
echo ""

# Function to check if a service is responding
check_service() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}

    echo -n "Checking $name... "

    if response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>&1); then
        if [ "$response" = "$expected_code" ]; then
            echo -e "${GREEN}✓ OK (HTTP $response)${NC}"
            return 0
        else
            echo -e "${RED}✗ FAIL (HTTP $response, expected $expected_code)${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ FAIL (Connection failed)${NC}"
        return 1
    fi
}

# Function to check API endpoint with JSON validation
check_api_json() {
    local name=$1
    local url=$2
    local expected_origin=${3:-origin-api}

    echo -n "Checking $name... "

    # Create temp files for headers and body
    local tmpdir
    tmpdir=$(mktemp -d)
    local headers_file="$tmpdir/headers"
    local body_file="$tmpdir/body"

    # Get response with headers dumped to file
    local http_code
    http_code=$(curl -s -w "%{http_code}" -D "$headers_file" -o "$body_file" "$url")

    # Extract headers
    content_type=$(grep -i "content-type:" "$headers_file" | cut -d' ' -f2- | tr -d '\r')
    origin_server=$(grep -i "x-origin-server:" "$headers_file" | cut -d' ' -f2- | tr -d '\r')

    # Check HTTP status
    if [ "$http_code" != "200" ]; then
        echo -e "${RED}✗ FAIL (HTTP $http_code)${NC}"
        rm -rf "$tmpdir"
        return 1
    fi

    # Check content type
    if [[ ! "$content_type" =~ "application/json" ]]; then
        echo -e "${RED}✗ FAIL (Content-Type: $content_type, expected application/json)${NC}"
        rm -rf "$tmpdir"
        return 1
    fi

    # Check origin server
    if [ "$origin_server" != "$expected_origin" ]; then
        echo -e "${RED}✗ FAIL (Origin: $origin_server, expected $expected_origin)${NC}"
        rm -rf "$tmpdir"
        return 1
    fi

    # Validate JSON
    if ! python3 -m json.tool "$body_file" > /dev/null 2>&1; then
        echo -e "${RED}✗ FAIL (Invalid JSON)${NC}"
        rm -rf "$tmpdir"
        return 1
    fi

    # Cleanup
    rm -rf "$tmpdir"

    echo -e "${GREEN}✓ OK (HTTP 200, JSON, origin: $origin_server)${NC}"
    return 0
}

# Function to test cache behavior
check_cache_behavior() {
    local name=$1
    local url=$2

    echo -n "Checking $name caching... "

    # First request - establish baseline (use GET with headers to stderr)
    HEADERS1=$(curl -s -D /dev/stderr "$url" 2>&1 > /dev/null)
    AGE1=$(echo "$HEADERS1" | grep -i "^age:" | awk '{print $2}' | tr -d '\r' || echo "0")

    # Wait to allow cache to be distinct
    sleep 2

    # Second request - should show cache hit (use GET with headers to stderr)
    HEADERS2=$(curl -s -D /dev/stderr "$url" 2>&1 > /dev/null)
    AGE2=$(echo "$HEADERS2" | grep -i "^age:" | awk '{print $2}' | tr -d '\r' || echo "0")

    # Check if Age header increased (indicating cached content)
    if [ "$AGE2" -gt "$AGE1" ] && [ "$AGE2" -ge 2 ]; then
        echo -e "${GREEN}✓ OK (Age: ${AGE1}s → ${AGE2}s, cache working)${NC}"
        return 0
    else
        echo -e "${RED}✗ FAIL (Age: ${AGE1}s → ${AGE2}s, cache not working)${NC}"
        return 1
    fi
}

# Check all services
FAILED=0

# HAProxy
check_service "HAProxy" "http://localhost:80/" || FAILED=$((FAILED + 1))

# HAProxy Stats (with basic auth)
check_service "HAProxy Stats" "http://admin:admin@localhost:8404/stats" 200 || FAILED=$((FAILED + 1))

# Prometheus
check_service "Prometheus" "http://localhost:9090/-/healthy" || FAILED=$((FAILED + 1))

# Grafana
check_service "Grafana" "http://localhost:3000/api/health" || FAILED=$((FAILED + 1))

# API Endpoints (with JSON validation)
check_api_json "API /users" "http://localhost/api/users" || FAILED=$((FAILED + 1))
check_api_json "API /products" "http://localhost/api/products" || FAILED=$((FAILED + 1))

# Static files
check_service "Static CSS" "http://localhost/static/styles.css" || FAILED=$((FAILED + 1))
check_service "Static JS" "http://localhost/static/app.js" || FAILED=$((FAILED + 1))

# Cache behavior tests
check_cache_behavior "Cache /page1" "http://localhost/page1" || FAILED=$((FAILED + 1))
check_cache_behavior "Cache /api/users" "http://localhost/api/users" || FAILED=$((FAILED + 1))

echo ""
echo -e "${BLUE}=== Docker Container Status ===${NC}"
docker compose ps

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All smoke tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILED test(s) failed!${NC}"
    exit 1
fi

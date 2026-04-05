#!/bin/bash
# Smoke test for ATS cluster
# Verifies all services are running and responding

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
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

# Check all services
FAILED=0

# HAProxy
check_service "HAProxy" "http://localhost:80/" || FAILED=$((FAILED + 1))

# HAProxy Stats
check_service "HAProxy Stats" "http://localhost:8404/stats" 200 || FAILED=$((FAILED + 1))

# Prometheus
check_service "Prometheus" "http://localhost:9090/-/healthy" || FAILED=$((FAILED + 1))

# Grafana
check_service "Grafana" "http://localhost:3000/api/health" || FAILED=$((FAILED + 1))

# API Endpoints
check_service "API /users" "http://localhost/api/users" || FAILED=$((FAILED + 1))
check_service "API /products" "http://localhost/api/products" || FAILED=$((FAILED + 1))

# Static files
check_service "Static CSS" "http://localhost/static/styles.css" || FAILED=$((FAILED + 1))
check_service "Static JS" "http://localhost/static/app.js" || FAILED=$((FAILED + 1))

echo ""
echo -e "${BLUE}=== Docker Container Status ===${NC}"
docker-compose ps

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All smoke tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILED test(s) failed!${NC}"
    exit 1
fi

.PHONY: help up down restart build logs ps stats test clean smoke-test cache-test load-test test-logs lint

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

## help: Show this help message
help:
	@echo "$(BLUE)ATS Cluster Management$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ": "} /^## [a-zA-Z_-]+:/ {gsub(/^## /, ""); printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

## up: Start the cluster
up: build
	@echo "$(BLUE)Starting ATS cluster...$(NC)"
	docker compose up -d
	@echo "$(GREEN)Cluster started!$(NC)"
	@echo "Access points:"
	@echo "  - HTTP: http://localhost"
	@echo "  - Grafana: http://localhost:3000 (admin/admin)"
	@echo "  - Prometheus: http://localhost:9090"
	@echo "  - HAProxy Stats: http://localhost:8404/stats (admin/admin)"

## down: Stop the cluster
down:
	@echo "$(BLUE)Stopping ATS cluster...$(NC)"
	docker compose down -v
	@echo "$(GREEN)Cluster stopped!$(NC)"

## restart: Restart the cluster
restart: down up

## build: Build all images
build:
	@echo "$(BLUE)Building images...$(NC)"
	docker compose build
	@echo "$(GREEN)Build complete!$(NC)"

## logs: Tail logs from all services
logs:
	docker compose logs -f

## logs-ats: Tail logs from ATS nodes only
logs-ats:
	docker compose logs -f ats-1 ats-2 ats-3

## logs-haproxy: Tail logs from HAProxy
logs-haproxy:
	docker compose logs -f haproxy

## ps: Show running containers
ps:
	@docker compose ps

## stats: Show cluster statistics
stats:
	@echo "$(BLUE)Cluster Status:$(NC)"
	@docker compose ps
	@echo ""
	@echo "$(BLUE)HAProxy Backend Stats:$(NC)"
	@curl -s -u admin:admin 'http://localhost:8404/stats;csv' 2>/dev/null | \
		awk -F',' 'BEGIN {printf "%-15s %-10s %-10s %-12s %-15s\n", "Server", "Status", "Sessions", "Bytes Out", "Health Check"} \
		NR>1 && $$1 == "ats_cluster" && $$2 ~ /ats-/ { \
			status = $$18; \
			sessions = $$8; \
			bytes = $$10; \
			check = $$37 " (" $$38 ")"; \
			printf "%-15s %-10s %-10s %-12s %-15s\n", $$2, status, sessions, bytes, check \
		}' || echo "HAProxy not responding"
	@echo ""
	@echo "$(BLUE)Quick Links:$(NC)"
	@echo "  Grafana: http://localhost:3000"
	@echo "  Prometheus: http://localhost:9090"
	@echo "  HAProxy Stats: http://localhost:8404/stats"

## test: Run all tests
test: smoke-test cache-test test-logs
	@echo "$(GREEN)All tests completed!$(NC)"

## smoke-test: Run smoke tests
smoke-test:
	@echo "$(BLUE)Running smoke tests...$(NC)"
	@bash tests/smoke-test.sh

## cache-test: Test consistent hashing
cache-test:
	@echo "$(BLUE)Testing consistent hashing...$(NC)"
	@bash tests/test-cache-hit-rate.sh

## load-test: Run load tests
load-test:
	@echo "$(BLUE)Running load test...$(NC)"
	@bash tests/test-load.sh

## test-logs: Check logs for warnings/errors
test-logs:
	@echo "$(BLUE)Checking logs for warnings/errors...$(NC)"
	@bash tests/test-logs.sh

## lint: Run shellcheck on all bash scripts
lint:
	@echo "$(BLUE)Running shellcheck on bash scripts...$(NC)"
	@shellcheck tests/*.sh
	@echo "$(GREEN)Shellcheck passed!$(NC)"

## clean: Stop cluster and remove all volumes
clean:
	@echo "$(YELLOW)WARNING: This will delete all cache data and metrics!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(BLUE)Cleaning up...$(NC)"; \
		docker compose down -v; \
		echo "$(GREEN)Cleanup complete!$(NC)"; \
	else \
		echo "Cancelled."; \
	fi

## shell-ats: Open shell in ATS node 1
shell-ats:
	@docker exec -it ats-node-1 /bin/bash

## shell-haproxy: Open shell in HAProxy
shell-haproxy:
	@docker exec -it ats-haproxy /bin/sh

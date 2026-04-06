# Apache Traffic Server Cluster Example

A production-ready example of running Apache Traffic Server (ATS) as a 3-node cluster using Docker Compose, with consistent hashing load balancing and full monitoring stack (Prometheus + Grafana).

## Architecture

```
Client Requests
       ↓
   HAProxy :80
       ↓ (consistent hash on URL)
   ┌───┼───┐
   ↓   ↓   ↓
ATS-1 ATS-2 ATS-3
:8080 :8080 :8080
   └───┼───┘
       ↓
  Origin Servers
  ├→ origin-web :9001 (nginx)
  ├→ origin-api :9002 (Flask API)
  └→ origin-static :9003 (nginx static files)

Monitoring:
  ├→ Prometheus :9090 (metrics collection)
  └→ Grafana :3000 (dashboards)
```

### Key Features

- **Consistent Hashing**: Same URL always routes to same ATS node for optimal cache hit rates
- **No Cache Coordination Overhead**: Modern approach without legacy ICP protocol
- **Automatic Failover**: HAProxy redistributes load if a node fails
- **Full Observability**: Prometheus metrics and Grafana dashboards
- **Persistent Caches**: Named volumes preserve cache across restarts
- **Health Checks**: All services monitored with Docker health checks
- **Cache Purging**: PURGE method support with IP-based access control
- **Aggressive Caching**: Caches dynamic URLs, cookies, and ignores client no-cache directives
- **Volume Management**: Dedicated cache volumes with hosting configuration
- **Direct Origin Access**: Origin servers exposed on ports 9001-9003 for testing

## Quick Start

### Prerequisites

- docker
- make
- curl (for testing)

### Start the Cluster

```bash
# Start all services
make up
```

Wait ~30 seconds for all services to become healthy, then access:

- **Website**: http://localhost
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **HAProxy Stats**: http://localhost:8404/stats (admin/admin)

### Verify It's Working

```bash
# Run smoke tests
make smoke-test

# Test consistent hashing
make cache-test

# Run load test
make load-test
```

## Usage

### Make Commands

```bash
make up            # Start the cluster (builds first if needed)
make down          # Stop the cluster and remove volumes
make restart       # Restart the cluster
make build         # Rebuild all images
make logs          # Tail all logs
make logs-ats      # Tail ATS logs only
make logs-haproxy  # Tail HAProxy logs only
make ps            # Show running containers
make stats         # Show cluster statistics with backend health
make test          # Run all tests (smoke, cache, logs)
make smoke-test    # Run smoke tests only
make cache-test    # Test cache hit rate
make load-test     # Run load test with Vegeta
make test-logs     # Check logs for warnings/errors
make lint          # Run shellcheck on all bash scripts
make clean         # Stop and remove all volumes (⚠️  deletes cache data)
```

### Testing Cache Behavior

#### Test #1: Verify Consistent Hashing

Same URL should always hit the same ATS node:

```bash
# Run same URL 10 times
for i in {1..10}; do
  curl -sI http://localhost/page1 | grep x-backend-server
done

# All responses should show the same ATS node (e.g., ats-1)
```

#### Test #2: Verify Cache Hits

Second request should be served from cache:

```bash
# First request (MISS) - use GET not HEAD since ATS caches GET requests
curl -s -o /dev/null -D - http://localhost/page2

# Wait 2 seconds
sleep 2

# Second request (HIT) - should show Age header increasing
curl -s -o /dev/null -D - http://localhost/page2
```

**Note**: Use `GET` requests (without `-I`) for cache testing. ATS doesn't cache `HEAD` requests directly, but rather from a `GET` request.

#### Test #3: Verify Load Distribution

Different URLs should distribute across all nodes:

```bash
curl -sI http://localhost/page1 | grep x-backend-server  # e.g., ats-1
curl -sI http://localhost/page2 | grep x-backend-server  # e.g., ats-2
curl -sI http://localhost/page3 | grep x-backend-server  # e.g., ats-3
```

### API Endpoints

Test the API origin:

```bash
# Get all users
curl http://localhost/api/users

# Get specific user
curl http://localhost/api/users/1

# Get all products
curl http://localhost/api/products

# Get specific product
curl http://localhost/api/products/1
```

### Static Assets

Test static file caching (long TTL):

```bash
# CSS file
curl -I http://localhost/static/styles.css

# JavaScript file
curl -I http://localhost/static/app.js
```

### Cache Purging

Purge cached content using the PURGE method:

```bash
# Purge a specific URL from cache
curl -X PURGE http://localhost/page1

# Purge an API endpoint
curl -X PURGE http://localhost/api/users

# Check cache status after purge (should be MISS on first request)
curl -s -o /dev/null -D - http://localhost/page1 | grep Age
```

**Access Control**: PURGE requests are restricted by IP address. See [ats/ip_allow.yaml](ats/ip_allow.yaml) for configuration.

## Monitoring

### Grafana Dashboards

Access Grafana at http://localhost:3000 (admin/admin)

The pre-loaded dashboard shows:
- ATS node status (up/down)
- Origin server health
- HAProxy status
- Scrape duration metrics
- Service status table

### Prometheus Queries

Access Prometheus at http://localhost:9090

Example queries:
```promql
# Number of ATS nodes up
sum(up{service="trafficserver"})

# Scrape duration by instance
scrape_duration_seconds

# All targets status
up
```

### HAProxy Statistics

Access HAProxy stats at http://localhost:8404/stats (admin/admin)

Shows:
- Backend server status (ats-1, ats-2, ats-3)
- Request rates
- Response times
- Health check status

## Configuration

### ATS Configuration Files

- [ats/records.yaml](ats/records.yaml) - Main ATS configuration (aggressive caching settings)
- [ats/remap.config](ats/remap.config) - URL remapping rules (simplified, order-dependent)
- [ats/storage.config](ats/storage.config) - Cache storage settings
- [ats/volume.config](ats/volume.config) - Cache volume definitions
- [ats/hosting.config](ats/hosting.config) - Volume routing configuration
- [ats/cache.config](ats/cache.config) - Cache rules
- [ats/ip_allow.yaml](ats/ip_allow.yaml) - IP-based access control for PURGE requests
- [ats/plugin.config](ats/plugin.config) - Enabled plugins
- [ats/logging.yaml](ats/logging.yaml) - Logging configuration

### HAProxy Configuration

- [haproxy/haproxy.cfg](haproxy/haproxy.cfg) - Load balancer settings
  - `balance uri` - Hash based on request URI
  - `hash-type consistent` - Consistent hashing algorithm

### Important: Remap Config Order

The [ats/remap.config](ats/remap.config) has been simplified but **order matters**:

1. Most specific rules first (e.g., `/api/`)
2. Then medium specificity (e.g., `/static/`)
3. Catch-all rules last (e.g., `/`)

**Old approach** (redundant): Had separate rules for each port
**New approach** (clean): Single rule per endpoint, ATS listens on port 8080

```
# Correct order:
map http://localhost/api/ http://origin-api:9002/api/      # Specific
map http://localhost/static/ http://origin-static:9003/    # Specific
map http://localhost/ http://origin-web:9001/              # Catch-all (MUST be last)
```

### Customization

Edit [.env](.env) to change:
- Port mappings
- Grafana credentials
- Cache size
- Monitoring intervals

## Understanding Consistent Hashing

### Why It Matters

**Without consistent hashing (round-robin):**
```
Request 1: /page1 → ats-1 (MISS, fetches from origin, caches)
Request 2: /page1 → ats-2 (MISS, fetches from origin, caches)
Request 3: /page1 → ats-3 (MISS, fetches from origin, caches)
Result: 0% cache hit rate, same content cached 3 times
```

**With consistent hashing:**
```
Request 1: /page1 → ats-1 (MISS, fetches from origin, caches)
Request 2: /page1 → ats-1 (HIT, served from cache)
Request 3: /page1 → ats-1 (HIT, served from cache)
Result: 67% cache hit rate, efficient cache usage
```

### How It Works

1. HAProxy computes hash of request URI
2. Hash maps to a position on consistent hash ring
3. Request routes to nearest ATS node on the ring
4. Same URI always produces same hash → same node
5. If a node fails, only its portion of the ring remaps

### Testing It

```bash
# This script verifies consistent hashing
./tests/test-cache-hit-rate.sh

# Manually verify
for i in {1..5}; do curl -I http://localhost/test 2>&1 | grep Via; done
# All 5 requests should show the same ATS node
```

## Troubleshooting

### Services Won't Start

```bash
# Check container status
docker compose ps

# Check logs for errors
docker compose logs

# Rebuild images
make build && make up
```

### Cache Not Working

```bash
# Check ATS is serving requests
curl -I http://localhost/ | grep Via

# Check ATS cache stats directly
docker exec ats-1 curl -s http://localhost:8080/_stats | grep cache

# View ATS RAM cache statistics
docker exec ats-1 curl -s http://localhost:8080/_stats | grep ram_cache

# Verify remap rules (note: configs are in /opt/etc/trafficserver)
docker exec ats-1 cat /opt/etc/trafficserver/remap.config

# Test with GET request (not HEAD) as ATS caches GET by default
curl -s -o /dev/null -D - http://localhost/page1 | grep Age
```

### Consistent Hashing Not Working

```bash
# Verify HAProxy config
docker exec ats-haproxy cat /usr/local/etc/haproxy/haproxy.cfg | grep balance

# Should show:
#   balance uri
#   hash-type consistent

# Check HAProxy stats (requires basic auth)
curl -u admin:admin http://localhost:8404/stats

# View backend server health
make stats
```

### Port Already in Use

Edit [.env](.env) and change conflicting ports:
```bash
HAPROXY_HTTP_PORT=8080
PROMETHEUS_PORT=9091
GRAFANA_PORT=3001
```

Then restart:
```bash
make restart
```

### Monitoring Not Working

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Grafana is running
curl http://localhost:3000/api/health

# Restart monitoring stack
docker compose restart prometheus grafana
```

## Performance Tuning

### Increase Cache Size

Edit [ats/storage.config](ats/storage.config):
```
/cache/trafficserver 500G
```

Change to desired size (e.g., `1T` for 1 terabyte).

### Adjust Cache TTLs

Edit [ats/records.yaml](ats/records.yaml):
```yaml
http:
  cache:
    heuristic_min_lifetime: 300   # 5 minutes
    heuristic_max_lifetime: 86400  # 24 hours
```

### Configure Cache Behavior

The current configuration uses aggressive caching. Edit [ats/records.yaml](ats/records.yaml) to tune:

```yaml
http:
  cache:
    ignore_client_no_cache: 1           # Ignore client Cache-Control: no-cache
    cache_responses_to_cookies: 1       # Cache Set-Cookie responses
    cache_urls_that_look_dynamic: 1     # Cache URLs with query strings
    when_to_revalidate: 0               # Use TTL from Cache-Control
```

To make caching less aggressive, set these to `0`.

### Scale to More Nodes

1. Add `ats-4` to [docker compose.yml](docker compose.yml) (copy `ats-3`)
2. Add `ats-4` to [haproxy/haproxy.cfg](haproxy/haproxy.cfg):
   ```
   server ats4 ats-4:8080 check
   ```
3. Add scrape target to [prometheus/prometheus.yml](prometheus/prometheus.yml)
4. Restart: `make restart`

## Project Structure

```
.
├── README.md                    # This file
├── docker compose.yml           # Main orchestration
├── Makefile                     # Convenience commands
├── .env                         # Configuration
├── ats/                         # ATS configuration
│   ├── Dockerfile
│   ├── records.yaml            # Main config with aggressive caching
│   ├── remap.config            # URL remapping (order matters!)
│   ├── storage.config          # Cache storage
│   ├── volume.config           # Cache volumes
│   ├── hosting.config          # Volume routing
│   ├── cache.config            # Cache rules
│   ├── ip_allow.yaml           # Access control for PURGE
│   ├── plugin.config
│   └── logging.yaml
├── haproxy/                     # Load balancer
│   └── haproxy.cfg
├── origins/                     # Backend servers
│   ├── web/                    # HTML origin (:9001)
│   ├── api/                    # JSON API origin (:9002)
│   └── static/                 # Static files origin (:9003)
├── prometheus/                  # Metrics collection
│   ├── prometheus.yml
│   └── alerts.yml
├── grafana/                     # Dashboards
│   ├── grafana.ini
│   └── provisioning/
└── tests/                       # Test scripts
    ├── smoke-test.sh           # Service health + cache tests
    ├── test-cache-hit-rate.sh  # PURGE + cache verification
    ├── test-load.sh            # Vegeta load testing
    └── test-logs.sh            # Log error/warning checker
```

## Recent Improvements

This project has been enhanced with:

- **Cache Purging**: Implemented PURGE method with IP-based access control via [ats/ip_allow.yaml](ats/ip_allow.yaml)
- **Aggressive Caching**: Configured to cache dynamic URLs, cookies, and ignore client no-cache directives
- **Volume Management**: Added [ats/volume.config](ats/volume.config) and [ats/hosting.config](ats/hosting.config) for better cache organization
- **Improved Testing**: Enhanced test scripts with JSON validation, cache verification, and log checking
- **Better Observability**: Improved Grafana dashboards with more detailed metrics
- **Simplified Config**: Streamlined [ats/remap.config](ats/remap.config) (order-dependent rules)
- **Load Testing**: Integrated Vegeta for realistic load testing
- **Direct Origin Access**: Origins exposed on ports 9001-9003 for direct testing

## Future Enhancements

Ideas for extending this example:

### SSL/TLS Termination
Add HTTPS support with Let's Encrypt or self-signed certificates.

### ESI (Edge Side Includes)
Fragment caching for dynamic pages.

### Rate Limiting
Add rate limiting plugin to protect origins.

### GeoIP Routing
Route based on client location for geo-distributed deployments.

### Distributed Tracing
Add Jaeger for request tracing across all components.

### Alerting
Connect Prometheus alerts to Slack/PagerDuty.

### Blue/Green Deployments
Show how to roll out origin changes without downtime.

### Cache Warming
Scripts to pre-populate caches with common content.

## Contributing

Contributions welcome! Ideas:
- Add more test scenarios
- Improve Grafana dashboards
- Add cache purge examples
- Add SSL/TLS examples
- Document advanced ATS features

## License

MIT License - feel free to use this as a starting point for your own ATS deployments.

## Resources

- [Apache Traffic Server Documentation](https://docs.trafficserver.apache.org/)
- [HAProxy Documentation](http://www.haproxy.org/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## Credits

Built as a reference implementation for running ATS in containerized environments with modern DevOps practices.

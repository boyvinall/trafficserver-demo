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

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- 4GB+ available RAM
- curl (for testing)

### Start the Cluster

```bash
# Start all services
make up

# Or using docker-compose directly
docker-compose up -d
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
make up           # Start the cluster
make down         # Stop the cluster
make restart      # Restart the cluster
make build        # Rebuild all images
make logs         # Tail all logs
make logs-ats     # Tail ATS logs only
make ps           # Show running containers
make stats        # Show cluster statistics
make test         # Run all tests
make clean        # Stop and remove all volumes (⚠️  deletes cache data)
```

### Testing Cache Behavior

#### Test #1: Verify Consistent Hashing

Same URL should always hit the same ATS node:

```bash
# Run same URL 10 times
for i in {1..10}; do
  curl -I http://localhost/page1 | grep Via
done

# All responses should show the same ATS node (e.g., ats-1)
```

#### Test #2: Verify Cache Hits

Second request should be served from cache:

```bash
# First request (MISS)
curl -I http://localhost/page2

# Second request (HIT) - should show Age header
curl -I http://localhost/page2
```

#### Test #3: Verify Load Distribution

Different URLs should distribute across all nodes:

```bash
curl -I http://localhost/page1 | grep Via  # e.g., ats-1
curl -I http://localhost/page2 | grep Via  # e.g., ats-2
curl -I http://localhost/page3 | grep Via  # e.g., ats-3
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

- [ats/records.yaml](ats/records.yaml) - Main ATS configuration
- [ats/remap.config](ats/remap.config) - URL remapping rules
- [ats/storage.config](ats/storage.config) - Cache storage settings
- [ats/plugin.config](ats/plugin.config) - Enabled plugins
- [ats/logging.yaml](ats/logging.yaml) - Logging configuration

### HAProxy Configuration

- [haproxy/haproxy.cfg](haproxy/haproxy.cfg) - Load balancer settings
  - `balance uri` - Hash based on request URI
  - `hash-type consistent` - Consistent hashing algorithm

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
docker-compose ps

# Check logs for errors
docker-compose logs

# Rebuild images
make build && make up
```

### Cache Not Working

```bash
# Check ATS is serving requests
curl -I http://localhost/ | grep Via

# Check ATS stats
curl http://localhost/_stats | less

# Verify remap rules
docker exec ats-node-1 cat /etc/trafficserver/remap.config
```

### Consistent Hashing Not Working

```bash
# Verify HAProxy config
docker exec ats-haproxy cat /usr/local/etc/haproxy/haproxy.cfg | grep balance

# Should show:
#   balance uri
#   hash-type consistent

# Check HAProxy stats
curl http://localhost:8404/stats
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
docker-compose restart prometheus grafana
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

### Scale to More Nodes

1. Add `ats-4` to [docker-compose.yml](docker-compose.yml) (copy `ats-3`)
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
├── docker-compose.yml           # Main orchestration
├── Makefile                     # Convenience commands
├── .env                         # Configuration
├── ats/                         # ATS configuration
│   ├── Dockerfile
│   ├── records.yaml
│   ├── remap.config
│   ├── storage.config
│   ├── plugin.config
│   └── logging.yaml
├── haproxy/                     # Load balancer
│   └── haproxy.cfg
├── origins/                     # Backend servers
│   ├── web/                    # HTML origin
│   ├── api/                    # JSON API origin
│   └── static/                 # Static files origin
├── prometheus/                  # Metrics collection
│   ├── prometheus.yml
│   └── alerts.yml
├── grafana/                     # Dashboards
│   ├── grafana.ini
│   └── provisioning/
└── tests/                       # Test scripts
    ├── smoke-test.sh
    ├── test-cache-hit-rate.sh
    └── test-load.sh
```

## Future Enhancements

Ideas for extending this example:

### SSL/TLS Termination
Add HTTPS support with Let's Encrypt or self-signed certificates.

### Cache Purging
Implement cache invalidation API and webhooks.

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

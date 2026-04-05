FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Apache Traffic Server from Ubuntu repositories
RUN apt-get update && \
    apt-get install -y \
        trafficserver \
        curl \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY records.yaml /etc/trafficserver/records.yaml
COPY remap.config /etc/trafficserver/remap.config
COPY storage.config /etc/trafficserver/storage.config
COPY plugin.config /etc/trafficserver/plugin.config
COPY logging.yaml /etc/trafficserver/logging.yaml

# Create necessary directories with proper permissions
RUN mkdir -p /cache/trafficserver /run/trafficserver /var/log/trafficserver && \
    chown -R trafficserver:trafficserver /cache/trafficserver /run/trafficserver /var/log/trafficserver && \
    chmod 755 /cache/trafficserver /run/trafficserver /var/log/trafficserver && \
    chown trafficserver:trafficserver /etc/trafficserver/*.yaml /etc/trafficserver/*.config

# Expose ATS port (8080)
EXPOSE 8080

# Health check - verify ATS is responding
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=5 \
    CMD curl -f http://localhost:8080/ || exit 1

# Start Traffic Server as root (it will drop privileges)
CMD ["/usr/bin/traffic_server"]

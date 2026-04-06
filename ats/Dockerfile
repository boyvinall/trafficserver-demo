FROM trafficserver/trafficserver:10.1.0

# Install curl for health checks
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy configuration files to correct path for official image
COPY records.yaml /opt/etc/trafficserver/records.yaml
COPY remap.config /opt/etc/trafficserver/remap.config
COPY cache.config /opt/etc/trafficserver/cache.config
COPY storage.config /opt/etc/trafficserver/storage.config
COPY volume.config /opt/etc/trafficserver/volume.config
COPY hosting.config /opt/etc/trafficserver/hosting.config
COPY plugin.config /opt/etc/trafficserver/plugin.config
COPY logging.yaml /opt/etc/trafficserver/logging.yaml
COPY ip_allow.yaml /opt/etc/trafficserver/ip_allow.yaml

# Create cache directory with proper ownership for 'nobody' user
RUN mkdir -p /cache/trafficserver && \
    chown -R nobody:nogroup /cache/trafficserver && \
    chmod 755 /cache/trafficserver

# Expose ATS port
EXPOSE 8080

# Health check - verify ATS is responding
HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=5 \
    CMD curl -f http://localhost:8080/_stats || exit 1

# Start Traffic Server (use default entrypoint from base image)
CMD ["traffic_server"]

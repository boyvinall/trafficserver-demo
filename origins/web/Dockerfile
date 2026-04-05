FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Remove default config to prevent conflicts
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy HTML content
COPY html /usr/share/nginx/html

# Expose web port
EXPOSE 9001

# Health check
HEALTHCHECK --interval=10s --timeout=3s CMD wget --quiet --tries=1 --spider http://localhost:9001/health || exit 1

CMD ["nginx", "-g", "daemon off;"]

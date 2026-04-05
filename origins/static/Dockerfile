FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Remove default config to prevent conflicts
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy static files
COPY files /usr/share/nginx/html

# Expose static files port
EXPOSE 9003

# Health check
HEALTHCHECK --interval=10s --timeout=3s CMD wget --quiet --tries=1 --spider http://localhost:9003/health || exit 1

CMD ["nginx", "-g", "daemon off;"]

FROM python:3.11-slim

WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Expose API port
EXPOSE 9002

# Health check
HEALTHCHECK --interval=10s --timeout=3s CMD curl -f http://localhost:9002/api/health || exit 1

# Run the Flask app
CMD ["python", "app.py"]

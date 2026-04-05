#!/usr/bin/env python3
"""
Simple Flask API for ATS cluster demo
Provides sample JSON endpoints and Prometheus metrics
"""

from flask import Flask, jsonify, make_response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time
import random

app = Flask(__name__)

# Prometheus metrics
request_count = Counter('api_requests_total', 'Total API requests', ['endpoint', 'method'])
request_duration = Histogram('api_request_duration_seconds', 'API request duration', ['endpoint'])

# Sample data
USERS = [
    {"id": 1, "name": "Alice Johnson", "email": "alice@example.com", "role": "admin"},
    {"id": 2, "name": "Bob Smith", "email": "bob@example.com", "role": "user"},
    {"id": 3, "name": "Carol Davis", "email": "carol@example.com", "role": "user"},
    {"id": 4, "name": "David Wilson", "email": "david@example.com", "role": "moderator"},
    {"id": 5, "name": "Eve Brown", "email": "eve@example.com", "role": "user"},
]

PRODUCTS = [
    {"id": 1, "name": "Laptop", "price": 999.99, "category": "Electronics", "in_stock": True},
    {"id": 2, "name": "Mouse", "price": 29.99, "category": "Electronics", "in_stock": True},
    {"id": 3, "name": "Keyboard", "price": 79.99, "category": "Electronics", "in_stock": True},
    {"id": 4, "name": "Monitor", "price": 299.99, "category": "Electronics", "in_stock": False},
    {"id": 5, "name": "Headphones", "price": 149.99, "category": "Audio", "in_stock": True},
]


def add_cache_headers(response):
    """Add cache control and origin identification headers"""
    response.headers['X-Origin-Server'] = 'origin-api'
    response.headers['Cache-Control'] = 'public, max-age=300'  # 5 minutes
    response.headers['Access-Control-Allow-Origin'] = '*'
    return response


@app.route('/api/health', methods=['GET'])
def health():
    """Health check endpoint"""
    request_count.labels(endpoint='/api/health', method='GET').inc()
    response = make_response(jsonify({"status": "healthy", "service": "origin-api"}))
    response.headers['X-Origin-Server'] = 'origin-api'
    return response


@app.route('/api/users', methods=['GET'])
def get_users():
    """Get all users"""
    start_time = time.time()
    request_count.labels(endpoint='/api/users', method='GET').inc()

    # Simulate some processing time
    time.sleep(random.uniform(0.01, 0.05))

    response = make_response(jsonify({
        "users": USERS,
        "count": len(USERS),
        "timestamp": time.time()
    }))

    request_duration.labels(endpoint='/api/users').observe(time.time() - start_time)
    return add_cache_headers(response)


@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Get a specific user by ID"""
    start_time = time.time()
    request_count.labels(endpoint='/api/users/:id', method='GET').inc()

    user = next((u for u in USERS if u['id'] == user_id), None)

    if user:
        response = make_response(jsonify(user))
    else:
        response = make_response(jsonify({"error": "User not found"}), 404)

    request_duration.labels(endpoint='/api/users/:id').observe(time.time() - start_time)
    return add_cache_headers(response)


@app.route('/api/products', methods=['GET'])
def get_products():
    """Get all products"""
    start_time = time.time()
    request_count.labels(endpoint='/api/products', method='GET').inc()

    # Simulate some processing time
    time.sleep(random.uniform(0.01, 0.05))

    response = make_response(jsonify({
        "products": PRODUCTS,
        "count": len(PRODUCTS),
        "timestamp": time.time()
    }))

    request_duration.labels(endpoint='/api/products').observe(time.time() - start_time)
    return add_cache_headers(response)


@app.route('/api/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    """Get a specific product by ID"""
    start_time = time.time()
    request_count.labels(endpoint='/api/products/:id', method='GET').inc()

    product = next((p for p in PRODUCTS if p['id'] == product_id), None)

    if product:
        response = make_response(jsonify(product))
    else:
        response = make_response(jsonify({"error": "Product not found"}), 404)

    request_duration.labels(endpoint='/api/products/:id').observe(time.time() - start_time)
    return add_cache_headers(response)


@app.route('/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


@app.route('/api/', methods=['GET'])
def api_root():
    """API root endpoint with available endpoints"""
    return add_cache_headers(make_response(jsonify({
        "service": "ATS Cluster API",
        "endpoints": {
            "/api/health": "Health check",
            "/api/users": "List all users",
            "/api/users/<id>": "Get specific user",
            "/api/products": "List all products",
            "/api/products/<id>": "Get specific product",
            "/metrics": "Prometheus metrics"
        }
    })))


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9002, debug=False)

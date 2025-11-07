# Ray Head Node Dockerfile for AI Platform
# Multi-stage build for Ray head node with dashboard and cluster management

FROM python:3.11-slim as base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    gcc \
    g++ \
    procps \
    htop \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash rayhead

FROM base as dependencies

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY docker/requirements.txt /tmp/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# Install additional dashboard and monitoring dependencies for head node
RUN pip install --no-cache-dir \
    ray[dashboard]==2.49.0 \
    psutil==5.9.6

FROM dependencies as application

# Copy application code
COPY . /app

# Set ownership and permissions
RUN chown -R rayhead:rayhead /app
USER rayhead

# Configure environment variables
ENV PYTHONPATH=/app
ENV RAY_DISABLE_IMPORT_WARNING=1
ENV RAY_DEDUP_LOGS=0
ENV RAY_HEAD_NODE=1
ENV RAY_DASHBOARD_HOST=0.0.0.0
ENV RAY_DASHBOARD_PORT=8265

# Create directories for Ray
RUN mkdir -p /tmp/ray /home/rayhead/.ray

# Health check for Ray head node
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8265 || exit 1

# Expose Ray head node ports
EXPOSE 6379 8265 10001 8080 52365

# Start Ray head node with dashboard and cluster management
CMD ["ray", "start", \
     "--head", \
     "--block", \
     "--dashboard-host=0.0.0.0", \
     "--dashboard-port=8265", \
     "--port=6379", \
     "--redis-password=", \
     "--num-cpus=2", \
     "--memory=4000000000", \
     "--object-store-memory=2000000000", \
     "--metrics-export-port=8080", \
     "--dashboard-agent-listen-port=52365", \
     "--temp-dir=/tmp/ray", \
     "--include-dashboard=true"]
# Ray Worker Dockerfile for AI Platform
# Multi-stage build for optimized Ray worker containers with AI dependencies

FROM python:3.12.8-slim as base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash rayworker

FROM base as dependencies

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY docker/requirements.txt /tmp/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt



FROM dependencies as application

# Copy application code
COPY . /app

# Set ownership and permissions
RUN chown -R rayworker:rayworker /app
USER rayworker

# Configure environment variables
ENV PYTHONPATH=/app
ENV RAY_DISABLE_IMPORT_WARNING=1
ENV RAY_DEDUP_LOGS=0
ENV RAY_WORKER_NICENESS=0

# Health check for Ray worker
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import ray; ray.init('auto'); print('Ray worker healthy')" || exit 1

# Expose Ray worker ports
EXPOSE 6379 8000 10001

# Start Ray worker with proper configuration
CMD ["ray", "start", \
     "--address=ray-cluster-dev-head-svc:6379", \
     "--block", \
     "--num-cpus=2", \
     "--memory=4000000000", \
     "--object-store-memory=1000000000", \
     "--resources={\"worker_type\":1}", \
     "--temp-dir=/tmp/ray"]
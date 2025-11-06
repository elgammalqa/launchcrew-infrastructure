# Multi-stage build for production Celery worker
FROM python:3.12-slim-bookworm as base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies for AI processing and GKE deployment
RUN apt-get update && apt-get install -y \
    # Build essentials for Python packages
    build-essential \
    gcc \
    g++ \
    # System utilities
    curl \
    wget \
    git \
    # Network tools
    netcat-openbsd \
    # Google Cloud SDK dependencies
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    # Database connectivity
    libpq-dev \
    postgresql-client \
    # Additional dependencies for AI processing
    libffi-dev \
    libssl-dev \
    # Python development headers
    python3-dev \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install Google Cloud SDK for GKE deployment capabilities
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install -y google-cloud-sdk google-cloud-sdk-gke-gcloud-auth-plugin kubectl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash --uid 1000 celery

# Dependencies stage
FROM base as dependencies

# Install uv for faster Python package management
RUN pip install --no-cache-dir uv

# Copy requirements and install Python dependencies using uv
COPY requirements.txt /tmp/requirements.txt
RUN uv pip install --system --no-cache -r /tmp/requirements.txt

# Application stage
FROM dependencies as application

# Set working directory
WORKDIR /app

# Copy application code with proper ownership
COPY --chown=celery:celery . /app/

# Create necessary directories
RUN mkdir -p /app/logs /app/tmp \
    && chown -R celery:celery /app/logs /app/tmp

# Make startup check script executable
RUN chmod +x /app/scripts/worker_startup_check.py

# Switch to non-root user
USER celery

# Configure environment for Celery worker
ENV CELERY_APP=src.core.infrastructure.queue.celery_app:celery_app \
    CELERY_WORKER_CONCURRENCY=2 \
    CELERY_WORKER_LOGLEVEL=info \
    CELERY_WORKER_PREFETCH_MULTIPLIER=1 \
    CELERY_WORKER_MAX_TASKS_PER_CHILD=1000

# Health check to verify Celery worker and database connectivity
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python /app/scripts/worker_startup_check.py && celery -A src.core.infrastructure.queue.celery_app:celery_app inspect ping -d celery@$HOSTNAME || exit 1

# Expose port for monitoring (optional)
EXPOSE 5555

# Default command to start Celery worker with startup checks
CMD ["sh", "-c", "python /app/scripts/worker_startup_check.py && celery -A src.core.infrastructure.queue.celery_app:celery_app worker --loglevel=${CELERY_WORKER_LOGLEVEL} --concurrency=${CELERY_WORKER_CONCURRENCY} --prefetch-multiplier=${CELERY_WORKER_PREFETCH_MULTIPLIER} --max-tasks-per-child=${CELERY_WORKER_MAX_TASKS_PER_CHILD} --hostname=celery@%h"]
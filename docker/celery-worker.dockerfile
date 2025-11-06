# Multi-stage Dockerfile for Celery Workers
# Optimized for production workloads with health checks and monitoring

# Build stage
FROM python:3.11-slim as builder

# Set build arguments
ARG DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    libpq-dev \
    libffi-dev \
    libssl-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements and install Python dependencies
COPY pyproject.toml uv.lock ./
RUN pip install --no-cache-dir uv && \
    uv pip install --no-cache-dir -r uv.lock

# Production stage
FROM python:3.11-slim as production

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:$PATH" \
    CELERY_APP="src.core.infrastructure.queue.celery_app:celery_app"

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpq5 \
    curl \
    procps \
    logrotate \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Create celery user and directories
RUN groupadd -r celery && \
    useradd -r -g celery -d /app -s /bin/bash celery && \
    mkdir -p /app /var/log/celery /var/run/celery && \
    chown -R celery:celery /app /var/log/celery /var/run/celery

# Copy virtual environment from builder stage
COPY --from=builder /opt/venv /opt/venv

# Set working directory
WORKDIR /app

# Copy application code
COPY --chown=celery:celery . .

# Copy worker startup script
COPY --chown=celery:celery scripts/start_celery_worker.sh /usr/local/bin/start_celery_worker.sh
RUN chmod +x /usr/local/bin/start_celery_worker.sh

# Create supervisor configuration for worker management
RUN cat > /etc/supervisor/conf.d/celery-worker.conf << 'EOF'
[program:celery-worker]
command=/usr/local/bin/start_celery_worker.sh
directory=/app
user=celery
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/celery/supervisor.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
environment=PYTHONPATH="/app"

[program:celery-beat]
command=celery -A src.core.infrastructure.queue.celery_app:celery_app beat --loglevel=info --logfile=/var/log/celery/beat.log --pidfile=/var/run/celery/beat.pid
directory=/app
user=celery
autostart=false
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/celery/beat-supervisor.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
environment=PYTHONPATH="/app"

[program:celery-flower]
command=celery -A src.core.infrastructure.queue.celery_app:celery_app flower --port=5555 --basic_auth=admin:admin123
directory=/app
user=celery
autostart=false
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/celery/flower-supervisor.log
stdout_logfile_maxbytes=50MB
stdout_logfile_backups=10
environment=PYTHONPATH="/app"
EOF

# Create health check script
RUN cat > /usr/local/bin/health_check.sh << 'EOF'
#!/bin/bash
set -e

# Check if Celery worker is responding
if ! celery -A src.core.infrastructure.queue.celery_app:celery_app inspect ping --timeout=10 2>/dev/null | grep -q "pong"; then
    echo "Celery worker health check failed"
    exit 1
fi

# Check Redis connectivity
if ! python -c "import redis; r = redis.Redis.from_url('${REDIS_URL:-redis://localhost:6379/0}'); r.ping()" 2>/dev/null; then
    echo "Redis connectivity check failed"
    exit 1
fi

echo "Health check passed"
exit 0
EOF

RUN chmod +x /usr/local/bin/health_check.sh

# Create entrypoint script
RUN cat > /usr/local/bin/docker-entrypoint.sh << 'EOF'
#!/bin/bash
set -e

# Function to handle shutdown
shutdown() {
    echo "Shutting down Celery worker..."
    supervisorctl stop all
    exit 0
}

# Trap signals
trap shutdown SIGTERM SIGINT

# Ensure directories exist and have correct permissions
mkdir -p /var/log/celery /var/run/celery
chown -R celery:celery /var/log/celery /var/run/celery

# Start supervisor based on worker type
case "${WORKER_TYPE:-general}" in
    "general")
        echo "Starting general purpose Celery worker..."
        exec supervisord -c /etc/supervisor/supervisord.conf -n
        ;;
    "workflows")
        echo "Starting workflow-specialized Celery worker..."
        export CELERY_QUEUES="workflows"
        export CELERY_CONCURRENCY="2"
        exec /usr/local/bin/start_celery_worker.sh start-workflows
        ;;
    "agents")
        echo "Starting agent-specialized Celery worker..."
        export CELERY_QUEUES="agents"
        export CELERY_CONCURRENCY="4"
        exec /usr/local/bin/start_celery_worker.sh start-agents
        ;;
    "high-priority")
        echo "Starting high-priority Celery worker..."
        export CELERY_QUEUES="high_priority"
        export CELERY_CONCURRENCY="1"
        exec /usr/local/bin/start_celery_worker.sh start-high-priority
        ;;
    "beat")
        echo "Starting Celery beat scheduler..."
        exec supervisorctl start celery-beat && supervisord -c /etc/supervisor/supervisord.conf -n
        ;;
    "flower")
        echo "Starting Celery flower monitoring..."
        exec supervisorctl start celery-flower && supervisord -c /etc/supervisor/supervisord.conf -n
        ;;
    *)
        echo "Unknown worker type: ${WORKER_TYPE}"
        exit 1
        ;;
esac
EOF

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Switch to celery user
USER celery

# Expose ports
EXPOSE 5555

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/health_check.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command
CMD ["general"]

# Labels for metadata
LABEL maintainer="AI Multi-Agent Platform Team" \
      version="1.0.0" \
      description="Celery worker container for AI Multi-Agent Platform" \
      org.opencontainers.image.title="AI Platform Celery Worker" \
      org.opencontainers.image.description="Production-ready Celery worker with monitoring and health checks" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.vendor="AI Multi-Agent Platform"
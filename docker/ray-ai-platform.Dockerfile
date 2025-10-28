# Ray Dockerfile for AI Multi-Agent Platform
# Base image with NumPy compatibility fix and common dependencies

FROM rayproject/ray:2.47.1-py312

# Set working directory
WORKDIR /app

# Install system dependencies
USER root
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Switch to ray user
USER ray

# Fix NumPy compatibility issue by downgrading to 1.x
# This resolves the "AttributeError: _ARRAY_API not found" error
RUN pip install --no-cache-dir \
    'numpy<2.0' \
    'pandas>=2.0.0' \
    'pyarrow>=14.0.0'

# Install common AI/ML dependencies
RUN pip install --no-cache-dir \
    openai \
    anthropic \
    langchain \
    langchain-openai \
    langchain-anthropic \
    langchain-community \
    psycopg2-binary \
    redis \
    nats-py \
    pika \
    weaviate-client \
    clickhouse-driver \
    influxdb-client \
    pydantic \
    pydantic-settings \
    sqlalchemy \
    alembic \
    asyncpg \
    httpx

# Set Python path to include the app directory
ENV PYTHONPATH=/app:$PYTHONPATH

# Verify installation
RUN python -c "import numpy; print(f'NumPy version: {numpy.__version__}')" && \
    python -c "import pandas; print(f'Pandas version: {pandas.__version__}')" && \
    python -c "import ray; print(f'Ray version: {ray.__version__}')" && \
    python -c "import openai; print('✅ OpenAI SDK installed')" && \
    python -c "import anthropic; print('✅ Anthropic SDK installed')"

# Create directory for Ray logs
RUN mkdir -p /tmp/ray

# Expose Ray ports
EXPOSE 6379 8265 10001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import ray; import numpy; import pandas" || exit 1

# Default command (will be overridden by Ray operator)
CMD ["ray", "start", "--head", "--port=6379", "--dashboard-host=0.0.0.0", "--block"]

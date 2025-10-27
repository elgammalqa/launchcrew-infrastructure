# Custom Ray Image for AI Platform
# Fixes NumPy compatibility issues and includes ai_platform package

FROM rayproject/ray:2.47.1-py312

# Set working directory
WORKDIR /app

# Install system dependencies
USER root
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Switch back to ray user
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
    alembic

# Copy application code (when building from app repo)
# COPY --chown=ray:ray . /app

# Set Python path
ENV PYTHONPATH=/app:$PYTHONPATH

# Verify installation
RUN python -c "import numpy; print(f'NumPy version: {numpy.__version__}')" && \
    python -c "import pandas; print(f'Pandas version: {pandas.__version__}')" && \
    python -c "import ray; print(f'Ray version: {ray.__version__}')"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import ray; import numpy; import pandas" || exit 1

# Default command (will be overridden by Ray)
CMD ["ray", "start", "--head", "--block"]

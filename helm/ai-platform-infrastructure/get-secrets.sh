#!/bin/bash

# Get Secrets Helper Script
# Retrieves connection strings and credentials for all services

set -e

NAMESPACE="ai-platform-infra"

show_help() {
    echo "🔐 Get Secrets Helper"
    echo ""
    echo "Usage: $0 [service|all]"
    echo ""
    echo "Services:"
    echo "  postgresql    Get PostgreSQL connection details"
    echo "  redis         Get Redis connection details"
    echo "  rabbitmq      Get RabbitMQ connection details"
    echo "  clickhouse    Get ClickHouse connection details"
    echo "  influxdb      Get InfluxDB connection details"
    echo "  weaviate      Get Weaviate connection details"
    echo "  registry      Get Docker Registry details"
    echo "  nats          Get NATS connection details"
    echo "  ray           Get Ray cluster details"
    echo "  all           Get all service details"
    echo "  env           Generate .env file format"
    echo ""
    echo "Examples:"
    echo "  $0 postgresql"
    echo "  $0 all"
    echo "  $0 env > .env"
}

get_secret() {
    local secret_name=$1
    local key=$2
    kubectl get secret $secret_name -n $NAMESPACE -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d 2>/dev/null || echo "N/A"
}

show_postgresql() {
    echo "🐘 PostgreSQL:"
    echo "  Database: $(get_secret postgresql-secret POSTGRES_DB)"
    echo "  Username: $(get_secret postgresql-secret POSTGRES_USER)"
    echo "  Password: $(get_secret postgresql-secret POSTGRES_PASSWORD)"
    echo "  URL:      $(get_secret postgresql-secret DATABASE_URL)"
    echo ""
}

show_redis() {
    echo "🔴 Redis:"
    echo "  Password: $(get_secret redis-secret REDIS_PASSWORD)"
    echo "  URL:      $(get_secret redis-secret REDIS_URL)"
    echo ""
}

show_rabbitmq() {
    echo "🐰 RabbitMQ:"
    echo "  Username: $(get_secret rabbitmq-secret RABBITMQ_DEFAULT_USER)"
    echo "  Password: $(get_secret rabbitmq-secret RABBITMQ_DEFAULT_PASS)"
    echo "  URL:      $(get_secret rabbitmq-secret RABBITMQ_URL)"
    echo ""
}

show_clickhouse() {
    echo "🏠 ClickHouse:"
    echo "  Database: $(get_secret clickhouse-secret CLICKHOUSE_DB)"
    echo "  Username: $(get_secret clickhouse-secret CLICKHOUSE_USER)"
    echo "  Password: $(get_secret clickhouse-secret CLICKHOUSE_PASSWORD)"
    echo "  URL:      $(get_secret clickhouse-secret CLICKHOUSE_URL)"
    echo ""
}

show_influxdb() {
    echo "📊 InfluxDB:"
    echo "  Username:     $(get_secret influxdb-secret DOCKER_INFLUXDB_INIT_USERNAME)"
    echo "  Password:     $(get_secret influxdb-secret DOCKER_INFLUXDB_INIT_PASSWORD)"
    echo "  Organization: $(get_secret influxdb-secret DOCKER_INFLUXDB_INIT_ORG)"
    echo "  Bucket:       $(get_secret influxdb-secret DOCKER_INFLUXDB_INIT_BUCKET)"
    echo "  Token:        $(get_secret influxdb-secret DOCKER_INFLUXDB_INIT_ADMIN_TOKEN)"
    echo "  URL:          $(get_secret influxdb-secret INFLUXDB_URL)"
    echo ""
}

show_weaviate() {
    echo "🔍 Weaviate:"
    echo "  API Key: $(get_secret weaviate-secret WEAVIATE_API_KEY)"
    echo "  URL:     $(get_secret weaviate-secret WEAVIATE_URL)"
    echo ""
}

show_registry() {
    echo "🐳 Docker Registry:"
    echo "  HTTP Secret: $(get_secret registry-secret REGISTRY_HTTP_SECRET)"
    echo "  URL:         $(get_secret registry-secret REGISTRY_URL)"
    echo ""
}

show_nats() {
    echo "📡 NATS:"
    echo "  URL: $(get_secret nats-secret NATS_URL)"
    echo ""
}

show_ray() {
    echo "⚡ Ray:"
    echo "  Head Service: $(get_secret ray-secret RAY_HEAD_SERVICE_HOST)"
    echo "  Dashboard:    $(get_secret ray-secret RAY_DASHBOARD_URL)"
    echo ""
}

show_env_format() {
    echo "# AI Platform Infrastructure Environment Variables"
    echo "# Generated on $(date)"
    echo ""
    echo "# PostgreSQL"
    echo "POSTGRES_DB=$(get_secret postgresql-secret POSTGRES_DB)"
    echo "POSTGRES_USER=$(get_secret postgresql-secret POSTGRES_USER)"
    echo "POSTGRES_PASSWORD=$(get_secret postgresql-secret POSTGRES_PASSWORD)"
    echo "DATABASE_URL=$(get_secret postgresql-secret DATABASE_URL)"
    echo ""
    echo "# Redis"
    echo "REDIS_PASSWORD=$(get_secret redis-secret REDIS_PASSWORD)"
    echo "REDIS_URL=$(get_secret redis-secret REDIS_URL)"
    echo ""
    echo "# RabbitMQ"
    echo "RABBITMQ_USER=$(get_secret rabbitmq-secret RABBITMQ_DEFAULT_USER)"
    echo "RABBITMQ_PASSWORD=$(get_secret rabbitmq-secret RABBITMQ_DEFAULT_PASS)"
    echo "RABBITMQ_URL=$(get_secret rabbitmq-secret RABBITMQ_URL)"
    echo ""
    echo "# ClickHouse"
    echo "CLICKHOUSE_DB=$(get_secret clickhouse-secret CLICKHOUSE_DB)"
    echo "CLICKHOUSE_USER=$(get_secret clickhouse-secret CLICKHOUSE_USER)"
    echo "CLICKHOUSE_PASSWORD=$(get_secret clickhouse-secret CLICKHOUSE_PASSWORD)"
    echo "CLICKHOUSE_URL=$(get_secret clickhouse-secret CLICKHOUSE_URL)"
    echo ""
    echo "# InfluxDB"
    echo "INFLUXDB_USERNAME=$(get_secret influxdb-secret DOCKER_INFLUXDB_INIT_USERNAME)"
    echo "INFLUXDB_PASSWORD=$(get_secret influxdb-secret DOCKER_INFLUXDB_INIT_PASSWORD)"
    echo "INFLUXDB_ORG=$(get_secret influxdb-secret DOCKER_INFLUXDB_INIT_ORG)"
    echo "INFLUXDB_BUCKET=$(get_secret influxdb-secret DOCKER_INFLUXDB_INIT_BUCKET)"
    echo "INFLUXDB_TOKEN=$(get_secret influxdb-secret DOCKER_INFLUXDB_INIT_ADMIN_TOKEN)"
    echo "INFLUXDB_URL=$(get_secret influxdb-secret INFLUXDB_URL)"
    echo ""
    echo "# Weaviate"
    echo "WEAVIATE_API_KEY=$(get_secret weaviate-secret WEAVIATE_API_KEY)"
    echo "WEAVIATE_URL=$(get_secret weaviate-secret WEAVIATE_URL)"
    echo ""
    echo "# Docker Registry"
    echo "REGISTRY_HTTP_SECRET=$(get_secret registry-secret REGISTRY_HTTP_SECRET)"
    echo "REGISTRY_URL=$(get_secret registry-secret REGISTRY_URL)"
    echo ""
    echo "# NATS"
    echo "NATS_URL=$(get_secret nats-secret NATS_URL)"
    echo ""
    echo "# Ray"
    echo "RAY_HEAD_SERVICE_HOST=$(get_secret ray-secret RAY_HEAD_SERVICE_HOST)"
    echo "RAY_DASHBOARD_URL=$(get_secret ray-secret RAY_DASHBOARD_URL)"
}

case "${1:-help}" in
    postgresql)
        show_postgresql
        ;;
    redis)
        show_redis
        ;;
    rabbitmq)
        show_rabbitmq
        ;;
    clickhouse)
        show_clickhouse
        ;;
    influxdb)
        show_influxdb
        ;;
    weaviate)
        show_weaviate
        ;;
    registry)
        show_registry
        ;;
    nats)
        show_nats
        ;;
    ray)
        show_ray
        ;;
    all)
        show_postgresql
        show_redis
        show_rabbitmq
        show_clickhouse
        show_influxdb
        show_weaviate
        show_registry
        show_nats
        show_ray
        ;;
    env)
        show_env_format
        ;;
    help|*)
        show_help
        ;;
esac
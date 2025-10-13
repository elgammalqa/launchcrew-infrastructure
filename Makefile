# Infrastructure Makefile
# Deploys shared infrastructure services (PostgreSQL, RabbitMQ, Redis)

.PHONY: help k8s deploy clean status logs

# Default target
help: ## Show this help message
	@echo "Infrastructure Services - Available Commands:"
	@echo "==========================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $1, $2}'

# Deploy infrastructure to Kubernetes
k8s: deploy ## Deploy infrastructure to Kubernetes (alias)

deploy: ## Deploy infrastructure services to Kubernetes
	@echo "🚀 Deploying AI Platform Infrastructure..."
	@echo ""
	@echo "📦 Creating namespace..."
	@kubectl create namespace ai-platform-infra --dry-run=client -o yaml | kubectl apply -f -
	@kubectl label namespace ai-platform-infra name=ai-platform-infra --overwrite
	@echo ""
	@echo "📊 Installing Helm chart..."
	@helm upgrade --install ai-platform-infrastructure ./helm/ai-platform-infrastructure \
		-f ./helm/ai-platform-infrastructure/values-dev.yaml \
		-n ai-platform-infra \
		--create-namespace \
		--wait \
		--timeout 10m
	@echo ""
	@echo "⏳ Waiting for services to be ready..."
	@kubectl wait --for=condition=ready pod -l component=postgresql -n ai-platform-infra --timeout=180s || echo "⚠️  PostgreSQL not ready yet"
	@kubectl wait --for=condition=ready pod -l component=redis -n ai-platform-infra --timeout=180s || echo "⚠️  Redis not ready yet"
	@kubectl wait --for=condition=ready pod -l component=rabbitmq -n ai-platform-infra --timeout=180s || echo "⚠️  RabbitMQ not ready yet"
	@kubectl wait --for=condition=ready pod -l component=nats -n ai-platform-infra --timeout=180s || echo "⚠️  NATS not ready yet"
	@kubectl wait --for=condition=ready pod -l component=clickhouse -n ai-platform-infra --timeout=180s || echo "⚠️  ClickHouse not ready yet"
	@kubectl wait --for=condition=ready pod -l component=weaviate -n ai-platform-infra --timeout=180s || echo "⚠️  Weaviate not ready yet"
	@kubectl wait --for=condition=ready pod -l component=influxdb -n ai-platform-infra --timeout=180s || echo "⚠️  InfluxDB not ready yet"
	@kubectl wait --for=condition=ready pod -l component=registry -n ai-platform-infra --timeout=180s || echo "⚠️  Registry not ready yet"
	@echo ""
	@echo "✅ Infrastructure deployment completed!"
	@echo ""
	@kubectl get pods -n ai-platform-infra
	@echo ""
	@kubectl get svc -n ai-platform-infra
	@echo ""
	@kubectl get ingress -n ai-platform-infra

# There's no build step for infrastructure since we use existing images
build: ## No build needed for infrastructure (uses existing images)
	@echo "ℹ️  Infrastructure uses existing Docker images, no build needed"

# Check status
status: ## Check status of infrastructure services
	@echo "📊 Infrastructure Status:"
	@kubectl get pods -n ai-platform-infra || echo "Infrastructure not deployed"

# Show logs
logs: ## Show logs for infrastructure services
	@echo "📋 Infrastructure Logs:"
	@echo ""
	@echo "=== PostgreSQL Logs ==="
	@kubectl logs -n ai-platform-infra deployment/simple-postgresql --tail=10 || echo "PostgreSQL not available"
	@echo ""
	@echo "=== RabbitMQ Logs ==="
	@kubectl logs -n ai-platform-infra deployment/simple-rabbitmq --tail=10 || echo "RabbitMQ not available"

# Clean up
clean: ## Remove infrastructure deployment
	@echo "🧹 Cleaning up infrastructure..."
	@helm uninstall ai-platform-infrastructure -n ai-platform-infra || true
	@echo "✅ Infrastructure cleanup completed!"

# Port forwarding for development
port-forward: ## Setup port forwards for infrastructure services
	@echo "🔌 Setting up infrastructure port forwards..."
	@echo "PostgreSQL will be available at localhost:5432"
	@kubectl port-forward -n ai-platform-infra svc/simple-postgresql 5432:5432 &
	@echo "RabbitMQ will be available at amqp://localhost:5672"
	@kubectl port-forward -n ai-platform-infra svc/simple-rabbitmq 5672:5672 &
	@echo "RabbitMQ Management will be available at http://localhost:15672"
	@kubectl port-forward -n ai-platform-infra svc/simple-rabbitmq 15672:15672 &
	@echo "✅ Infrastructure port forwards established"

# Health checks
health: ## Check health of infrastructure services
	@echo "🏥 Infrastructure Health Check"
	@echo "=============================="
	@echo ""
	@echo "🗄️  PostgreSQL:"
	@kubectl exec -n ai-platform-infra deployment/ai-postgresql -- pg_isready -U postgres && echo "  ✅ Healthy" || echo "  ❌ Unhealthy"
	@echo ""
	@echo "🔴 Redis:"
	@kubectl exec -n ai-platform-infra deployment/ai-redis -- redis-cli ping && echo "  ✅ Healthy" || echo "  ❌ Unhealthy"
	@echo ""
	@echo "🐰 RabbitMQ:"
	@kubectl exec -n ai-platform-infra deployment/ai-rabbitmq -- rabbitmqctl status > /dev/null 2>&1 && echo "  ✅ Healthy" || echo "  ❌ Unhealthy"
	@echo ""
	@echo "📨 NATS:"
	@kubectl exec -n ai-platform-infra deployment/ai-nats -- nats-server --version > /dev/null 2>&1 && echo "  ✅ Healthy" || echo "  ❌ Unhealthy"
	@echo ""
	@echo "📊 ClickHouse:"
	@kubectl exec -n ai-platform-infra deployment/ai-clickhouse -- clickhouse-client --query "SELECT 1" > /dev/null 2>&1 && echo "  ✅ Healthy" || echo "  ❌ Unhealthy"
	@echo ""
	@echo "🔍 Weaviate:"
	@kubectl exec -n ai-platform-infra deployment/ai-weaviate -- wget -q -O- http://localhost:8080/v1/.well-known/ready > /dev/null 2>&1 && echo "  ✅ Healthy" || echo "  ❌ Unhealthy"
	@echo ""
	@echo "📈 InfluxDB:"
	@kubectl exec -n ai-platform-infra deployment/ai-influxdb -- influx ping > /dev/null 2>&1 && echo "  ✅ Healthy" || echo "  ❌ Unhealthy"
	@echo ""
	@echo "🐳 Registry:"
	@kubectl exec -n ai-platform-infra deployment/ai-registry -- wget -q -O- http://localhost:5000/v2/ > /dev/null 2>&1 && echo "  ✅ Healthy" || echo "  ❌ Unhealthy"
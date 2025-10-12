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
	@echo "🚀 Deploying infrastructure to Kubernetes..."
	@kubectl create namespace ai-platform-infra --dry-run=client -o yaml | kubectl apply -f -
	@helm upgrade --install ai-platform-infrastructure ./helm/ai-platform-infrastructure \
		-f ./helm/ai-platform-infrastructure/values-dev.yaml \
		-n ai-platform-infra
	@echo "⏳ Waiting for rollout..."
	@kubectl rollout status deployment/simple-postgresql -n ai-platform-infra --timeout=300s || true
	@kubectl rollout status deployment/simple-rabbitmq -n ai-platform-infra --timeout=300s || true
	@echo "✅ Infrastructure deployment completed!"
	@kubectl get pods -n ai-platform-infra

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
	@echo "🏥 Checking infrastructure health..."
	@kubectl exec -n ai-platform-infra deployment/simple-postgresql -- pg_isready && echo "✅ PostgreSQL healthy" || echo "❌ PostgreSQL unhealthy"
	@kubectl exec -n ai-platform-infra deployment/simple-rabbitmq -- rabbitmqctl status && echo "✅ RabbitMQ healthy" || echo "❌ RabbitMQ unhealthy"
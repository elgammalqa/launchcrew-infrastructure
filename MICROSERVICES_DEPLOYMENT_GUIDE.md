# Microservices CI/CD Guide

Guide for deploying microservices to GKE using Cloud Build and Helm.

## Prerequisites

1. **Connect GitHub to Cloud Build**: https://console.cloud.google.com/cloud-build/triggers;region=us-central1/connect
2. **Enable triggers**: Set `enable_triggers = true` in `terraform/environments/dev/main.tf` and run `make -C terraform apply-dev`

## Service Structure

```
services/your-service/
├── Dockerfile
├── cloudbuild.yaml
├── helm/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-prod.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       └── scaledobject.yaml
└── src/
```

---

## Required CI/CD Files

### 1. Dockerfile

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER node
EXPOSE 3000
CMD ["node", "src/index.js"]
```

### 2. cloudbuild.yaml

```yaml
steps:
  # Build Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_REGISTRY}/${_SERVICE_NAME}:${SHORT_SHA}'
      - '-t'
      - '${_REGISTRY}/${_SERVICE_NAME}:latest'
      - '.'
    dir: 'services/${_SERVICE_NAME}'

  # Push to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '--all-tags'
      - '${_REGISTRY}/${_SERVICE_NAME}'

  # Get GKE credentials
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'container'
      - 'clusters'
      - 'get-credentials'
      - '${_CLUSTER_NAME}'
      - '--region=${_CLUSTER_REGION}'

  # Deploy with Helm
  - name: 'gcr.io/${PROJECT_ID}/helm'
    args:
      - 'upgrade'
      - '--install'
      - '${_SERVICE_NAME}'
      - './helm'
      - '-f'
      - './helm/values-${_ENVIRONMENT}.yaml'
      - '--set'
      - 'image.tag=${SHORT_SHA}'
      - '--set'
      - 'image.repository=${_REGISTRY}/${_SERVICE_NAME}'
      - '--namespace'
      - '${_ENVIRONMENT}'
      - '--create-namespace'
      - '--wait'
      - '--timeout=5m'
    dir: 'services/${_SERVICE_NAME}'

timeout: 1200s
options:
  machineType: 'E2_HIGHCPU_8'
  logging: CLOUD_LOGGING_ONLY

substitutions:
  _SERVICE_NAME: 'your-service'
  _ENVIRONMENT: 'dev'
  _CLUSTER_NAME: 'dev-gke-cluster'
  _CLUSTER_REGION: 'us-central1'
  _REGISTRY: 'us-central1-docker.pkg.dev/${PROJECT_ID}/dev-docker-repo'

images:
  - '${_REGISTRY}/${_SERVICE_NAME}:${SHORT_SHA}'
  - '${_REGISTRY}/${_SERVICE_NAME}:latest'
```

### 3. Helm Chart Structure

#### helm/Chart.yaml
```yaml
apiVersion: v2
name: your-service
description: Your microservice Helm chart
type: application
version: 1.0.0
appVersion: "1.0.0"
```

#### helm/values.yaml
```yaml
replicaCount: 2

image:
  repository: us-central1-docker.pkg.dev/alien-drake-474816-a2/dev-docker-repo/your-service
  pullPolicy: IfNotPresent
  tag: "latest"

service:
  type: ClusterIP
  port: 80
  targetPort: 3000

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

autoscaling:
  enabled: true
  minReplicas: 0
  maxReplicas: 10

env:
  - name: NODE_ENV
    value: "production"
  - name: DATABASE_HOST
    value: "postgresql.ai-platform-infra.svc.cluster.local"
  - name: REDIS_URL
    value: "redis://redis.ai-platform-infra.svc.cluster.local:6379"
```

#### helm/values-dev.yaml
```yaml
replicaCount: 1

resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"

autoscaling:
  minReplicas: 0
  maxReplicas: 3

env:
  - name: NODE_ENV
    value: "development"
  - name: LOG_LEVEL
    value: "debug"
```

#### helm/templates/deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - containerPort: {{ .Values.service.targetPort }}
        env:
        {{- range .Values.env }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        livenessProbe:
          httpGet:
            path: /health
            port: {{ .Values.service.targetPort }}
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: {{ .Values.service.targetPort }}
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### helm/templates/service.yaml
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    protocol: TCP
  selector:
    app: {{ .Chart.Name }}
```

#### helm/templates/scaledobject.yaml
```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ .Chart.Name }}-scaler
spec:
  scaleTargetRef:
    name: {{ .Chart.Name }}
  minReplicaCount: {{ .Values.autoscaling.minReplicas }}
  maxReplicaCount: {{ .Values.autoscaling.maxReplicas }}
  cooldownPeriod: 300
  triggers:
  - type: cron
    metadata:
      timezone: America/Chicago
      start: 0 7 * * *
      end: 0 21 * * *
      desiredReplicas: "{{ .Values.replicaCount }}"
{{- end }}
```

---

## Infrastructure Services

All services can connect to:

```yaml
# PostgreSQL
DATABASE_HOST: postgresql.ai-platform-infra.svc.cluster.local:5432
DATABASE_NAME: ai_platform_dev

# Redis
REDIS_URL: redis://redis.ai-platform-infra.svc.cluster.local:6379

# RabbitMQ
RABBITMQ_URL: amqp://rabbitmq.ai-platform-infra.svc.cluster.local:5672

# NATS
NATS_URL: nats://nats.ai-platform-infra.svc.cluster.local:4222

# ClickHouse
CLICKHOUSE_HOST: clickhouse.ai-platform-infra.svc.cluster.local:8123

# Weaviate
WEAVIATE_URL: http://weaviate.ai-platform-infra.svc.cluster.local:8080

# InfluxDB
INFLUXDB_URL: http://influxdb.ai-platform-infra.svc.cluster.local:8086
```

---

## Deployment

### Automatic (Recommended)
```bash
git add .
git commit -m "feat: new feature"
git push origin dev  # Triggers Cloud Build automatically
```

### Manual
```bash
# Build and push
docker build -t us-central1-docker.pkg.dev/alien-drake-474816-a2/dev-docker-repo/your-service:v1.0.0 .
docker push us-central1-docker.pkg.dev/alien-drake-474816-a2/dev-docker-repo/your-service:v1.0.0

# Deploy with Helm
helm upgrade --install your-service ./helm \
  -f ./helm/values-dev.yaml \
  --set image.tag=v1.0.0 \
  --namespace dev \
  --create-namespace
```

---

## Resources

- **Artifact Registry**: `us-central1-docker.pkg.dev/alien-drake-474816-a2/dev-docker-repo`
- **GKE Cluster**: `dev-gke-cluster` (us-central1)
- **Infrastructure Namespace**: `ai-platform-infra`
- **Application Namespace**: `dev`

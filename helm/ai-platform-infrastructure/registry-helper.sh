#!/bin/bash

# Docker Registry Helper Script
# Provides easy commands for working with the local Docker registry

set -e

NAMESPACE="ai-platform-infra"
REGISTRY_PORT="5000"

show_help() {
    echo "🐳 Docker Registry Helper"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start-port-forward  Start port forwarding to registry (localhost:5000)"
    echo "  stop-port-forward   Stop port forwarding"
    echo "  list-repos          List all repositories in registry"
    echo "  list-tags <repo>    List tags for a specific repository"
    echo "  push <image>        Tag and push image to registry"
    echo "  pull <image>        Pull image from registry"
    echo "  test                Test registry connectivity"
    echo "  help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start-port-forward"
    echo "  $0 push myapp:latest"
    echo "  $0 list-repos"
    echo "  $0 list-tags myapp"
}

start_port_forward() {
    echo "🚀 Starting port forward to registry..."
    kubectl port-forward -n $NAMESPACE svc/registry $REGISTRY_PORT:$REGISTRY_PORT &
    echo "✅ Registry available at localhost:$REGISTRY_PORT"
    echo "💡 Use 'pkill -f \"port-forward.*registry\"' to stop"
}

stop_port_forward() {
    echo "🛑 Stopping registry port forward..."
    pkill -f "port-forward.*registry" || echo "No port forward found"
    echo "✅ Port forward stopped"
}

list_repos() {
    echo "📋 Listing repositories..."
    curl -s http://localhost:$REGISTRY_PORT/v2/_catalog | jq -r '.repositories[]' 2>/dev/null || {
        curl -s http://localhost:$REGISTRY_PORT/v2/_catalog
    }
}

list_tags() {
    local repo=$1
    if [ -z "$repo" ]; then
        echo "❌ Please specify repository name"
        echo "Usage: $0 list-tags <repository>"
        exit 1
    fi
    
    echo "🏷️  Listing tags for $repo..."
    curl -s http://localhost:$REGISTRY_PORT/v2/$repo/tags/list | jq -r '.tags[]' 2>/dev/null || {
        curl -s http://localhost:$REGISTRY_PORT/v2/$repo/tags/list
    }
}

push_image() {
    local image=$1
    if [ -z "$image" ]; then
        echo "❌ Please specify image name"
        echo "Usage: $0 push <image:tag>"
        exit 1
    fi
    
    local registry_image="localhost:$REGISTRY_PORT/$image"
    
    echo "🏷️  Tagging $image as $registry_image..."
    docker tag "$image" "$registry_image"
    
    echo "📤 Pushing $registry_image..."
    docker push "$registry_image"
    
    echo "✅ Successfully pushed $registry_image"
}

pull_image() {
    local image=$1
    if [ -z "$image" ]; then
        echo "❌ Please specify image name"
        echo "Usage: $0 pull <image:tag>"
        exit 1
    fi
    
    local registry_image="localhost:$REGISTRY_PORT/$image"
    
    echo "📥 Pulling $registry_image..."
    docker pull "$registry_image"
    
    echo "✅ Successfully pulled $registry_image"
}

test_registry() {
    echo "🔍 Testing registry connectivity..."
    
    if curl -s http://localhost:$REGISTRY_PORT/v2/ > /dev/null; then
        echo "✅ Registry is accessible at localhost:$REGISTRY_PORT"
        echo "📋 Available repositories:"
        list_repos
    else
        echo "❌ Registry not accessible. Make sure port forwarding is active:"
        echo "   $0 start-port-forward"
    fi
}

case "${1:-help}" in
    start-port-forward)
        start_port_forward
        ;;
    stop-port-forward)
        stop_port_forward
        ;;
    list-repos)
        list_repos
        ;;
    list-tags)
        list_tags "$2"
        ;;
    push)
        push_image "$2"
        ;;
    pull)
        pull_image "$2"
        ;;
    test)
        test_registry
        ;;
    help|*)
        show_help
        ;;
esac
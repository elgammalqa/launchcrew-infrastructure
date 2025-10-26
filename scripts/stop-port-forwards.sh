#!/bin/bash

# Stop all AI Platform port forwards

set -e

NAMESPACE="ai-platform-infra"
PID_FILE="/tmp/ai-platform-port-forwards.pids"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🛑 Stopping all port forwards...${NC}"

# Kill processes from PID file
if [ -f "$PID_FILE" ]; then
    while read pid; do
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid 2>/dev/null || true
            echo -e "${GREEN}✅ Stopped process $pid${NC}"
        fi
    done < "$PID_FILE"
    rm -f "$PID_FILE"
fi

# Kill any remaining kubectl port-forward processes
pkill -f "kubectl port-forward.*$NAMESPACE" 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ All port forwards stopped${NC}"

#!/bin/bash
# deploy.sh — portable deploy script for camster91/* apps.
#
# Usage:
#   ./deploy.sh <repo-name> [tag] [port]
#
# Defaults: tag=main, port=3000
# Pulls ghcr.io/camster91/<repo>:<tag> and runs it with the right env.
# Works on any host with Docker: Coolify, Hostinger VPS, Render, Fly.io,
# local dev, a Raspberry Pi.
#
# Re-runnable. Idempotent. Stops the old container before starting the new one.

set -euo pipefail

REPO="${1:-}"
TAG="${2:-main}"
PORT="${3:-3000}"
IMAGE="ghcr.io/camster91/${REPO}:${TAG}"

if [ -z "$REPO" ]; then
  echo "Usage: $0 <repo-name> [tag] [port]"
  echo ""
  echo "Examples:"
  echo "  $0 lull main 3000"
  echo "  $0 animal-farts v1.2.0 8080"
  echo "  $0 creative-studio latest"
  exit 1
fi

if ! command -v docker > /dev/null; then
  echo "ERROR: docker not installed. Install: https://docs.docker.com/engine/install/"
  exit 1
fi

echo "→ Pulling $IMAGE"
docker pull "$IMAGE"

echo "→ Stopping existing $REPO container (if any)"
if docker ps -a --format '{{.Names}}' | grep -q "^${REPO}$"; then
  docker stop "$REPO" 2>/dev/null || true
  docker rm "$REPO" 2>/dev/null || true
fi

echo "→ Starting $REPO on port $PORT"
docker run -d \
  --name "$REPO" \
  --restart unless-stopped \
  -p "${PORT}:3000" \
  -e NODE_ENV=production \
  -e PORT=3000 \
  --label "camster91.app=${REPO}" \
  --label "camster91.managed-by=deploy.sh" \
  "$IMAGE"

echo "→ Waiting for healthcheck"
HEALTH_URL="http://127.0.0.1:${PORT}/api/health"
for i in 1 2 3 4 5 6 7 8 9 10; do
  if wget -qO- "$HEALTH_URL" > /dev/null 2>&1; then
    echo "✓ $REPO is up at http://localhost:${PORT}"
    echo "  Health: $HEALTH_URL"
    exit 0
  fi
  if [ "$i" -eq 10 ]; then
    echo "✗ Health check failed after 30s"
    echo "  Last 30 lines of logs:"
    docker logs --tail 30 "$REPO"
    exit 1
  fi
  sleep 3
done

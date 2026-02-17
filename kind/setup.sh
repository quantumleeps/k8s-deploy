#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR="$(dirname "$REPO_DIR")"
CLUSTER_NAME="leeper-ai"

echo "==> Creating kind cluster..."
kind create cluster --name "$CLUSTER_NAME" --config "$SCRIPT_DIR/cluster.yaml"

echo "==> Installing NGINX ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
# Ensure controller schedules on control-plane node (has extraPortMappings)
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector/ingress-ready", "value": "true"}]'
echo "    Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "==> Installing metrics-server (for HPA)..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Patch for kind (no TLS between nodes)
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

echo "==> Building and loading images..."
docker build -t rag-pipeline:latest "$PARENT_DIR/rag-pipeline/"
kind load docker-image rag-pipeline:latest --name "$CLUSTER_NAME"

docker build -t mcp-units:latest "$PARENT_DIR/mcp-units/"
kind load docker-image mcp-units:latest --name "$CLUSTER_NAME"

echo "==> Deploying rag-pipeline..."
helm install rag "$REPO_DIR/charts/rag-pipeline" \
  -f "$REPO_DIR/charts/rag-pipeline/values-local.yaml" \
  --set secrets.VOYAGE_API_KEY="${VOYAGE_API_KEY:-}" \
  --set secrets.ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
  --set secrets.POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"

echo "==> Deploying mcp-units..."
helm install mcp "$REPO_DIR/charts/mcp-units"

echo "==> Waiting for pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=rag-pipeline --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mcp-units --timeout=120s

echo ""
echo "==> Cluster ready!"
echo "    kubectl get pods"
echo "    curl http://localhost/health  (via ingress)"
echo ""
echo "    To tear down: kind delete cluster --name $CLUSTER_NAME"

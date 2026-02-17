# k8s-deploy

Kubernetes deployment for a RAG pipeline and MCP server on EKS, with Helm charts, Terraform infrastructure, HPA autoscaling, and GitHub Actions CI/CD.

## What this does

Deploys two services to Kubernetes:

- **rag-pipeline** — FastAPI service for querying EPA water treatment regulations via RAG (pgvector + LlamaIndex + Voyage AI embeddings). Full Helm chart with HPA, Ingress, ConfigMap/Secret separation, and optional pgvector StatefulSet.
- **mcp-units** — MCP server for unit conversions. Simple Deployment + Service.

Both run locally on kind and in production on EKS — the same Helm charts with different values overrides handle environment promotion. Terraform provisions the AWS infrastructure. GitHub Actions handles CI (lint + kind integration test) and CD (manual deploy to EKS).

## Architecture

```mermaid
graph TB
    subgraph EKS Cluster
        ingress[ALB Ingress] --> rag_svc[rag-pipeline Service]
        ingress --> mcp_svc[mcp-units Service]
        rag_svc --> rag1[rag-pipeline Pod]
        rag_svc --> rag2[rag-pipeline Pod]
        rag_svc --> ragN[rag-pipeline Pod ...]
        mcp_svc --> mcp1[mcp-units Pod]
        hpa[HPA] -.->|scales| rag_svc
    end

    rag1 --> neon[(Neon pgvector)]
    rag1 --> voyage[Voyage AI API]
    rag1 --> anthropic[Anthropic API]
```

## How it works

Helm charts use a values override pattern for environment promotion:

- `values.yaml` — defaults
- `values-local.yaml` — kind: internal pgvector StatefulSet, nginx ingress, smaller resources
- `values-eks.yaml` — EKS: external Neon DB, ALB ingress, production resources

The `database.mode` toggle (`internal` vs `external`) controls whether pgvector runs as a StatefulSet inside the cluster or connects to a managed database outside it.

## Quickstart

### Local (kind)

Requires: Docker, kind, kubectl, helm

```bash
# One-command setup: creates cluster, installs ingress + metrics-server,
# builds images, deploys both charts
export VOYAGE_API_KEY=your-key
export ANTHROPIC_API_KEY=your-key
bash kind/setup.sh

# Verify
kubectl get pods
curl http://localhost/health
```

### AWS (EKS)

Requires: AWS CLI, terraform, kubectl, helm

**Warning: This creates AWS resources that cost money (~$5-7/day). Remember to destroy when done.**

```bash
# Provision infrastructure
cd terraform
cp terraform.tfvars.example terraform.tfvars  # edit as needed
terraform init && terraform apply

# Configure kubectl
$(terraform output -raw configure_kubectl)

# Push images to ECR
ECR=$(terraform output -raw ecr_rag_pipeline_url)
aws ecr get-login-password | docker login --username AWS --password-stdin "${ECR%/*}"
docker push "$ECR:latest"

# Deploy
cd ..
helm install rag charts/rag-pipeline \
  -f charts/rag-pipeline/values-eks.yaml \
  --set image.repository="$ECR" \
  --set database.host="$NEON_HOST" \
  --set secrets.POSTGRES_PASSWORD="$NEON_PASSWORD" \
  --set secrets.VOYAGE_API_KEY="$VOYAGE_API_KEY" \
  --set secrets.ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"

# Tear down when done
cd terraform && terraform destroy
```

## Project structure

```
k8s-deploy/
├── charts/
│   ├── rag-pipeline/       Helm chart (Deployment, Service, Ingress,
│   │   ├── templates/      HPA, ConfigMap, Secret, StatefulSet)
│   │   ├── values.yaml
│   │   ├── values-local.yaml
│   │   └── values-eks.yaml
│   └── mcp-units/          Simple Deployment + Service chart
├── kind/
│   ├── cluster.yaml        3-node cluster config
│   └── setup.sh            One-command local setup
├── terraform/              EKS + VPC + ECR (terraform-aws-modules)
├── load-test/              Locust load tests for HPA measurement
└── .github/workflows/
    ├── ci.yaml             Lint + kind integration test on PR
    └── deploy.yaml         Manual deploy to EKS
```

## Roadmap

- **Service mesh** (Linkerd) — mTLS between services, traffic splitting, per-route observability
- **GitOps** (ArgoCD) — declarative deployments from git, automatic drift detection and reconciliation
- **External secrets operator** — pull API keys from AWS Secrets Manager instead of Helm `--set`
- **Network policies** (Cilium) — restrict pod-to-pod traffic to only what's needed
- **Observability stack** (Prometheus + Grafana) — cluster and application metrics, dashboards, alerting
- **Progressive delivery** (Argo Rollouts) — canary deployments with automated rollback

## License

MIT

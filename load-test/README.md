# Load Testing

Locust load tests for measuring HPA scaling behavior.

## Setup

```bash
pip install -r requirements.txt
```

## Run

Target the rag-pipeline service through ingress (kind cluster must be running):

```bash
# Deploy with MOCK_MODE to avoid API costs
helm upgrade rag ../charts/rag-pipeline \
  -f ../charts/rag-pipeline/values-local.yaml \
  --set env.MOCK_MODE=true

# Run locust (opens web UI at http://localhost:8089)
locust -f locustfile.py --host http://localhost
```

## What to watch

In a separate terminal, observe HPA scaling:

```bash
kubectl get hpa --watch
kubectl top pods
```

The health endpoint runs at 5x the rate of /query. With MOCK_MODE enabled, /query returns instantly without hitting external APIs, so the load test is free.

## Capture results

Locust's web UI exports CSV and HTML reports. Save screenshots of HPA scaling for the README.

#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"
REQUEST_ID="${REQUEST_ID:-demo-run-1}"

echo "==> Submitting job"
RESP=$(curl -s -X POST "${API_URL}/v1/jobs" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: ${REQUEST_ID}" \
  -d '{
    "image":"busybox",
    "command":["sh","-c","echo hello-from-veriflow; sleep 2; echo done"],
    "max_retries": 0
  }')

echo "$RESP"

JOB_ID=$(echo "$RESP" | python3 -c 'import sys, json; print(json.load(sys.stdin)["job"]["job_id"])')

echo ""
echo "==> Waiting for Kubernetes job to appear"
sleep 3

kubectl get jobs
echo ""
kubectl get pods

K8S_JOB_NAME=$(docker compose exec -T postgres psql -U veriflow -d veriflow -t -A -c \
"select k8s_job_name from runs order by created_at desc limit 1;" | tr -d '[:space:]')

echo ""
echo "==> Latest Kubernetes job: ${K8S_JOB_NAME}"

if [[ -z "${K8S_JOB_NAME}" ]]; then
  echo "No k8s job name found in DB"
  exit 1
fi

echo ""
echo "==> Waiting for pod completion"
sleep 5

POD_NAME=$(kubectl get pods -l job-name="${K8S_JOB_NAME}" -o jsonpath='{.items[0].metadata.name}')

echo "Pod: ${POD_NAME}"
echo ""
echo "==> Pod logs"
kubectl logs "${POD_NAME}"

echo ""
echo "==> DB run state"
docker compose exec -T postgres psql -U veriflow -d veriflow -c \
"select state, k8s_job_name, created_at from runs order by created_at desc limit 5;"

echo ""
echo "==> DB event timeline"
docker compose exec -T postgres psql -U veriflow -d veriflow -c \
"select ts, type from events order by ts desc limit 10;"

echo ""
echo "==> Demo complete for job_id=${JOB_ID}"
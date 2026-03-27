# Veriflow — Kubernetes-Based AI Workload Orchestrator


Veriflow is a Kubernetes-based AI workload orchestrator that implements a control-plane + scheduler architecture for running training-style jobs.

It accepts jobs via an HTTP API, persists control-plane state in Postgres, schedules workloads using queue and priority semantics, dispatches execution as Kubernetes Jobs, and reconciles runtime state back into an auditable lifecycle timeline.

The system focuses on the infrastructure layer behind AI workloads — scheduling, reliability, and observability — rather than model logic itself.


## Key features

- Idempotent job submission using Idempotency-Key  
- Concurrency-safe job claiming with FOR UPDATE SKIP LOCKED  
- Priority and queue-based scheduling  
- GPU-aware placement decisions  
- Retry with backoff using next_run_at  
- Timeout handling for long-running jobs  
- Event-sourced lifecycle tracking (jobs, runs, events)  
- Kubernetes-based execution (batch/v1.Job)  

## 🚀 One-Command Demo

Run a full end-to-end demo:

```bash
./scripts/demo.sh
```

This script will:
- submit a job
- show Kubernetes job + pod creation
- print pod logs
- display database run state
- display event lifecycle timeline

See **RUNBOOK.md** for full step-by-step instructions.
---

## Architecture

```text
Client
  │  POST /v1/jobs  (Idempotency-Key)
  ▼
job-api (Go)
  │  writes jobs/spec to Postgres
  ▼
Postgres (jobs, runs, events)
  ▲
  │  claim (FOR UPDATE SKIP LOCKED) + create run attempt
  │  dispatch → create Kubernetes Job
  │  reconcile K8s Job status → RUNNING / SUCCEEDED / FAILED
  ▼
scheduler (Go)  ───────────────► Kubernetes Job / Pod
```

## Job lifecycle

A successful job execution produces the following event sequence:

- JOB_SUBMITTED  
- JOB_SCHEDULED  
- RUN_CREATED  
- PLACEMENT_SELECTED  
- DISPATCH_REQUESTED  
- POD_RUNNING  
- JOB_SUCCEEDED  

These events are persisted in the `events` table and exposed via the API for full lifecycle visibility.

**Key tables**
- `jobs`: desired state, spec, priority, max retries, `next_run_at`
- `runs`: execution attempts (attempt=1,2,3...), lifecycle
- `events`: append-only timeline (`JOB_CREATED`, `RUN_RUNNING`, `RUN_SUCCEEDED`, …)

---

## Requirements

- Go (1.21+ recommended)
- Docker (for Postgres)
- `psql` (Postgres client)
- Kubernetes cluster + `kubectl`
  - On macOS: Colima works well: `brew install colima kubectl && colima start`

---

## Quickstart (5 minutes)

### 1) Start Postgres
```bash
make up
```

### 2) Run API + scheduler (two terminals)
Terminal A:
```bash
make api
```

Terminal B:
```bash
make sched
```

### 3) Submit a test job
```bash
make demo-success
```

### 4) Verify Kubernetes ran it
```bash
kubectl get jobs
kubectl get pods
# Replace JOB_NAME with the printed run-<uuid> job name:
kubectl logs -l job-name=JOB_NAME --tail=200
```

### 5) Verify DB lifecycle + events
```bash
make events
```

---

## API

### Create a job (idempotent)
`Idempotency-Key` ensures the same request won’t create duplicates.

```bash
curl -s -X POST localhost:8080/v1/jobs \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: hello-1" \
  -d '{
    "image":"busybox",
    "command":["sh","-c","echo hello-from-veriflow; sleep 1; echo done"],
    "max_retries": 0,
    "priority": 0,
    "queue": "default"
  }'
```

### Get a job
```bash
curl -s localhost:8080/v1/jobs/<job_id>
```

---


### Minimal API example

Submit a job:

```bash
curl -X POST http://localhost:8080/v1/jobs \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: test-1" \
  -d '{
    "image": "busybox",
    "jobType": "training",
    "gpuCount": 1,
    "datasetUri": "s3://data/sample"
  }'

```

```bash
curl http://localhost:8080/v1/jobs/<job_id>
```

## Retries + backoff

Veriflow stores retry timing in `jobs.next_run_at` and only claims jobs whose `next_run_at <= now()`.

Try a failure demo (max_retries=2 ⇒ up to 3 attempts total):

```bash
make demo-fail
make events
make runs
```

Expected event shape:
- `RUN_FAILED`
- `JOB_RETRY_SCHEDULED` (payload includes delay/next_run_at/attempt)
- then a new `RUN_CREATED` for the next attempt

---

## Make targets

- `make up` / `make down` / `make reset`
- `make api` / `make sched`
- `make demo-success` / `make demo-fail`
- `make events` / `make runs` / `make jobs`

---

## 📘 Operations Guide
See [RUNBOOK.md](RUNBOOK.md) for full operational steps.



## What this project demonstrates

- Control-plane design for distributed systems  
- Safe concurrent scheduling using database primitives  
- Kubernetes-based workload orchestration  
- Fault handling with retries, backoff, and timeouts  
- Event-driven system observability  
- AI infrastructure patterns (training-style job orchestration)  This project demonstrates:



---

## License
MIT

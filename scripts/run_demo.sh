#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$REPO_ROOT/slurm_sandbox/docker-compose.yml"
TRANSCRIPT="$REPO_ROOT/evidence/terminal_transcripts/slurm_demo.txt"
SLURM_CLIENT_CONTAINER="${SLURM_CLIENT_CONTAINER:-c1}"

mkdir -p "$(dirname "$TRANSCRIPT")"
exec > >(tee "$TRANSCRIPT") 2>&1

echo "=== SLURM CPU demo transcript ==="
date -Is
echo "Repo: $REPO_ROOT"
echo "Compose: $COMPOSE_FILE"
echo "Client container: $SLURM_CLIENT_CONTAINER"
echo

docker compose -f "$COMPOSE_FILE" up -d
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
echo

echo "=== SLURM commands available? ==="
docker exec "$SLURM_CLIENT_CONTAINER" bash -lc 'command -v sbatch; command -v squeue; command -v sacct; sinfo'
echo

echo "=== Stage demo into /data/cpu_demo (clean) ==="
docker exec "$SLURM_CLIENT_CONTAINER" bash -lc 'rm -rf /data/cpu_demo && mkdir -p /data/cpu_demo'
docker cp "$REPO_ROOT/demos/cpu_demo/." "$SLURM_CLIENT_CONTAINER":/data/cpu_demo/
docker exec "$SLURM_CLIENT_CONTAINER" bash -lc 'ls -la /data/cpu_demo'
echo

echo "=== Submit job ==="
SUBMIT_OUT="$(docker exec "$SLURM_CLIENT_CONTAINER" bash -lc 'cd /data/cpu_demo && sbatch submit.slurm')"
echo "$SUBMIT_OUT"
JOBID="$(echo "$SUBMIT_OUT" | awk '{print $NF}')"
echo "JOBID=$JOBID"
echo

echo "=== squeue (poll until completion) ==="
for i in $(seq 1 240); do
  docker exec "$SLURM_CLIENT_CONTAINER" bash -lc "squeue -j $JOBID || true"
  if ! docker exec "$SLURM_CLIENT_CONTAINER" bash -lc "squeue -j $JOBID -h | grep -q ."; then
    echo "Job $JOBID no longer in squeue."
    break
  fi
  sleep 2
done

echo
echo "=== sacct ==="
docker exec "$SLURM_CLIENT_CONTAINER" bash -lc \
  "sacct -j $JOBID --format=JobID,JobName%20,Partition,AllocCPUS,Elapsed,State,ExitCode -P"
echo

OUTFILE="/data/cpu_demo/slurm-${JOBID}.out"
echo "=== Job output: $OUTFILE ==="
docker exec "$SLURM_CLIENT_CONTAINER" bash -lc "ls -l $OUTFILE && sed -n '1,220p' $OUTFILE"
echo

echo "=== Metrics artifact ==="
docker exec "$SLURM_CLIENT_CONTAINER" bash -lc "cat /data/cpu_demo/output/metrics.json"
echo

echo "Transcript saved to: $TRANSCRIPT"

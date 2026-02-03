# SLURM basics (user-level)

## Goal

Submit jobs, monitor them, and diagnose common failures using a small set of commands.

## Scope

- User-facing SLURM usage (not cluster admin).
- Commands vary slightly by site (partitions/QoS/accounts), but the workflow is consistent.

---

## Where to run SLURM commands (important)

- **On a real HPC cluster:** run `sbatch`, `squeue`, `sacct` on the **login node** (SLURM client is installed there).
- **In this repo’s local Docker SLURM sandbox:** run SLURM commands **inside the `slurmctld` container**.

### Option A (recommended): run a single command inside the sandbox

```bash
docker compose -f slurm_sandbox/docker-compose.yml exec slurmctld bash -lc \
  'sacct --format=JobID,JobName,State,ExitCode | tail -n 30'
```

### Option B: open a shell inside the sandbox (useful for multiple commands)

```bash
docker compose -f slurm_sandbox/docker-compose.yml exec slurmctld bash
# then run:
sbatch submit.slurm
squeue -u "$(whoami)"
sacct --format=JobID,JobName,State,ExitCode | tail -n 30
```

> Troubleshooting: If you run `sacct` on your WSL host you may see `Command 'sacct' not found` — that just means you’re outside the sandbox (run it via `docker compose exec slurmctld ...`).

---
## Quick command cheat sheet

Submit:

```bash
sbatch submit.slurm
```

Monitor your jobs:

```bash
squeue -u "$USER"
```

Monitor one job + show pending reason:

```bash
squeue -j <jobid> -o "%.18i %.9P %.8T %.10M %.6D %R"
```

Job details (very useful for pending):

```bash
scontrol show job <jobid> | sed -n '1,120p'
```

History / outcome:

```bash
sacct -j <jobid> --format=JobID,State,ExitCode,Elapsed,AllocCPUS,ReqMem,MaxRSS
```

Cancel:

```bash
scancel <jobid>
```

---

## Minimal batch script (CPU example)

Save as `submit.slurm`:

```bash
#!/usr/bin/env bash
#SBATCH --job-name=demo
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --time=00:02:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G

set -euo pipefail
echo "Running on: $(hostname)"
echo "Start: $(date)"
python3 -V
python3 run.py
echo "End: $(date)"
```

Where logs go:

- `--output=slurm-%j.out` → stdout file (with job id)
- `--error=slurm-%j.err` → stderr file

---

## Typical workflow (submit → watch → inspect)

### 1) Submit

```bash
sbatch submit.slurm
```

Expected:

- `Submitted batch job 12345`

Tip (machine-readable job id):

```bash
sbatch --parsable submit.slurm
```

### 2) Watch queue

```bash
squeue -u "$USER"
```

Expected:

- Job appears as `PENDING` then `RUNNING`

If it is pending, include reason:

```bash
squeue -j <jobid> -o "%.18i %.9P %.8T %.10M %.6D %R"
```

### 3) After completion, inspect outcome

```bash
sacct -j <jobid> --format=JobID,State,ExitCode,Elapsed,AllocCPUS,ReqMem,MaxRSS
```

Interpretation:

- `COMPLETED` + `ExitCode 0:0` → success
- `FAILED` → read stderr, check stack traces
- `OUT_OF_MEMORY` → increase memory or reduce workload
- `TIMEOUT` → increase `--time` or checkpoint

If your site has `seff`:

```bash
seff <jobid> || true
```

---

## “My job is pending forever” (decision tree)

1. Confirm pending reason:

```bash
squeue -j <jobid> -o "%.18i %.9P %.8T %.10M %.6D %R"
```

2. View full job request:

```bash
scontrol show job <jobid> | sed -n '1,160p'
```

Common reasons and user actions:

- `Priority`: normal; wait or use an appropriate QoS (if allowed)
- `Resources`: request fewer resources / shorter walltime / different partition
- `QOSMaxWallDurationPerJobLimit`: reduce `#SBATCH --time`
- `AssocGrp*Limit` (group/account limits): reduce request or escalate (policy/accounting)
- `PartitionDown` / `InvalidAccount` / `InvalidQOS`: escalate to support

---

## “My job ran but produced no output”

Checklist:

- Did you set `--output/--error`? If not, default is often `slurm-<jobid>.out` in submit directory.
- Are you writing to a path you can access from compute nodes?

Commands:

```bash
ls -la
tail -n 100 slurm-<jobid>.out || true
tail -n 100 slurm-<jobid>.err || true
```

If still nothing:

```bash
sacct -j <jobid> --format=JobID,State,ExitCode,Elapsed
```

---

## “My job failed” (common patterns)

### Exit code is nonzero (FAILED)

1. Read stderr first:

```bash
tail -n 200 slurm-<jobid>.err
```

2. Confirm job ran where you think:

```bash
scontrol show job <jobid> | sed -n '1,120p'
```

### OUT_OF_MEMORY

Symptoms:

- `sacct` shows `OUT_OF_MEMORY` or `CANCELLED` with OOM
- Application logs show `Killed` without traceback (sometimes)

Actions:

- Increase `#SBATCH --mem=...`
- Reduce dataset/batch size/parallelism
- Log memory usage periodically (app-level)

### TIMEOUT

Actions:

- Increase `#SBATCH --time=...` (within policy)
- Reduce work or add checkpoints
- For iterative ML, save checkpoints every N epochs

---

## Interactive testing (site-dependent)

Some clusters allow interactive allocations:

```bash
srun --pty bash -l
```

Or:

```bash
salloc --time=00:10:00 --cpus-per-task=1 --mem=1G
```

If unsure, ask support for the recommended interactive workflow.

---

## What support needs from you (copy/paste)

- JobID:
- Partition/QoS/account (if used):
- Job script (`submit.slurm`):
- Submit command you ran:
- `squeue -j <jobid> -o "%.18i %.9P %.8T %.10M %.6D %R"` output:
- `sacct -j <jobid> --format=JobID,State,ExitCode,Elapsed,AllocCPUS,ReqMem,MaxRSS` output:
- `slurm-<jobid>.out` and `slurm-<jobid>.err` (attach)

---

## Escalate when

- `InvalidAccount`, `InvalidQOS`, association/group limit messages
- `sacct` is empty or accounting appears broken (usage reporting needed)
- Repeated node failures / suspected hardware issues
- You believe a policy limit is blocking progress (fairshare/QoS/partition rules)

Related repo templates:

- `scripts/slurm_job_template_cpu.sh`
- `scripts/slurm_job_array_template.sh`
- `scripts/slurm_job_template_gpu.sh` (template-only)

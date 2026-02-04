# Support playbook (HPC / AI services) — first-level triage

This document is an **operator runbook** for first-level user support: gather the right facts fast, resolve common issues, and escalate cleanly when the fix is admin/policy/hardware.

**Scope**
- User-facing support (SSH/onboarding, SLURM usage, Python envs, filesystems, “why did my job fail?”).
- Not cluster administration (no daemon config changes, no scheduler reconfiguration).
- Site differences exist (partitions/QoS/accounts/modules), but the triage workflow is consistent.

**Safety / privacy**
- Never request private SSH keys, tokens, API keys, or passwords.
- Ask users to redact sensitive data (paths/usernames sometimes OK; secrets never).

---

## 0) 5-minute “fast triage” (what I do first)

1) **Classify the issue**
   - Access/login/SSH? → go to section 2
   - SLURM job scheduling/execution? → go to section 3
   - Python env/imports? → go to section 4
   - Filesystem/permission/quota? → go to section 5
   - Containers (Apptainer/Singularity)? → go to section 6
   - Performance/slow? → go to section 7

2) **Request minimum evidence** (copy/paste request in section 1)

3) **Get JobID + logs first** for anything SLURM-related  
   - If no JobID, ask them to re-run with `sbatch --parsable` or to paste their submit command output.

4) **Ask for a debug bundle** when the issue is non-trivial  
   - This repo: `bash scripts/collect_debug_bundle.sh` (attach the produced archive)

5) **Decide: user-fix vs escalation**  
   - If it’s account/QoS/partition policy, storage ACLs, node failures, or accounting → escalate (with evidence).

---

## 1) Ticket intake: what I ask the user to provide (copy/paste)

Ask the user to paste the following into the ticket (or fill it in together):

- What are you trying to do (one sentence)?
- Is this **blocking** (deadline) or best-effort?
- Where are you running commands from?
  - local laptop / WSL / login node / inside a container / inside a SLURM job
- Cluster + login hostname (e.g., `login.cluster.example.edu`):
- Username:
- Project/account (if applicable):
- Exact command(s) run:
- Full error output / traceback (text, not screenshot if possible)
- Relevant paths (project dir, data dir, output dir) — **absolute paths**
- If SLURM-related:
  - JobID:
  - Job script (`submit.slurm`):
  - stdout/stderr paths (or attach `slurm-<jobid>.out/.err`)

**If possible, attach a debug bundle**
- This repo: `bash scripts/collect_debug_bundle.sh`

---

## 1.1) Standard diagnostics “bundle” (commands the user can run)

### System + identity
```bash
date
hostname
whoami
id
groups
uname -a
cat /etc/os-release 2>/dev/null || true
```

### Filesystem sanity
```bash
pwd
ls -la
df -h .
du -sh . 2>/dev/null || true
```

### Python env sanity (if relevant)
```bash
which python3 || true
python3 -V || true
python3 -c "import sys; print(sys.executable)" 2>/dev/null || true
python3 -m pip -V 2>/dev/null || true
python3 -m pip list 2>/dev/null | head -n 30 || true
```

### This repo’s checker (if they have the repo)
```bash
python3 tools/check_environment.py
```

### This repo’s debug bundle (preferred for complex cases)
```bash
bash scripts/collect_debug_bundle.sh
```

---

## 2) Access / SSH issues (first-level)

### 2.1 Symptoms
- `Permission denied (publickey)`
- `Connection timed out`
- Host key warning: `REMOTE HOST IDENTIFICATION HAS CHANGED`

### 2.2 What I request
- Exact SSH command used
- `ssh -vvv user@login...` last ~40 lines (redacted as needed)
- Network context: VPN on/off, office/home

### 2.3 Quick user fixes
- Verify key permissions:
  ```bash
  chmod 700 ~/.ssh
  chmod 600 ~/.ssh/id_ed25519
  chmod 644 ~/.ssh/id_ed25519.pub
  ```
- Try explicit key:
  ```bash
  ssh -i ~/.ssh/id_ed25519 user@login.cluster.example.edu
  ```

### 2.4 Escalate when
- Host key changed warnings (treat as security incident until confirmed)
- MFA/SSO provisioning issues
- Account exists but home/project dirs missing (provisioning/ACL)

Reference: `docs/onboarding_linux_and_ssh.md`

---

## 3) SLURM job issues (pending, failed, no output)

> On a real cluster: run SLURM commands on the **login node**.  
> In this repo’s Docker sandbox: run SLURM commands inside the SLURM container context.

### 3.0 Minimum evidence for *any* SLURM ticket
- JobID
- Job script
- `squeue` line (or “job no longer in queue”)
- `sacct` outcome line (state + exitcode)
- stdout/stderr logs

### 3.1 Decision tree: job is **PENDING** “forever”

**Step 1 — get pending reason**
```bash
squeue -j <jobid> -o "%.18i %.9P %.8T %.10M %.6D %R"
```

**Step 2 — inspect job request**
```bash
scontrol show job <jobid> | sed -n '1,200p'
```

**Interpretation → user actions**
- Reason contains **Priority**
  - Normal queueing; suggest waiting or requesting fewer resources (shorter time, fewer CPUs, less mem).
- Reason contains **Resources**
  - Ask them to reduce requested resources or pick an appropriate partition (site policy).
- Reason contains **QOSMaxWallDurationPerJobLimit**
  - Reduce `#SBATCH --time` to comply with QoS/partition limit.
- Reason contains **AssocGrp*Limit / MaxJobs / MaxSubmit**
  - User may have too many running/submitted jobs → reduce submissions or wait.
- Reason contains **InvalidAccount / InvalidQOS / PartitionDown / ReqNodeNotAvail**
  - **Escalate** (include the `squeue` reason + `scontrol show job` output).

**Escalate when**
- Invalid account/QoS/partition
- Partition down / node unavailable for extended time
- Cluster policy needed (fairshare/QoS changes)

---

### 3.2 Decision tree: job **RUNNING** but “no output” / empty logs

**Step 1 — find log paths**
- If script sets `--output/--error`, use those.
- Otherwise default is often `slurm-<jobid>.out` in the submit directory.

**Step 2 — check logs**
```bash
ls -lh slurm-<jobid>.out slurm-<jobid>.err 2>/dev/null || true
tail -n 200 slurm-<jobid>.out 2>/dev/null || true
tail -n 200 slurm-<jobid>.err 2>/dev/null || true
```

**Step 3 — confirm job is actually still running**
```bash
squeue -j <jobid>
```

**Likely causes**
- Writing output somewhere unexpected (relative paths, wrong working dir)
- Application buffering (prints not flushing)
- Job started and ended quickly (check `sacct`)

**Next steps**
- Ask them to add to the job script:
  ```bash
  echo "PWD=$(pwd)"
  echo "HOST=$(hostname)"
  echo "START=$(date)"
  ```
- Ensure they write outputs to a known absolute path.

**Escalate when**
- Node/filesystem issues suspected (I/O errors in stderr, repeated failures across users)

---

### 3.3 Decision tree: job **FAILED** / nonzero exit

**Step 1 — outcome summary**
```bash
sacct -j <jobid> --format=JobID,JobName,State,ExitCode,Elapsed,AllocCPUS,ReqMem,MaxRSS
```

**Step 2 — read stderr first**
```bash
tail -n 200 slurm-<jobid>.err
```

**Step 3 — verify how SLURM launched it**
```bash
scontrol show job <jobid> | sed -n '1,200p'
```

**Common patterns**
- `ExitCode=0:0` + `COMPLETED` → success (issue is likely “expected output not where user thought”)
- `OUT_OF_MEMORY` or killed signal → go to section 3.4
- `TIMEOUT` → go to section 3.5
- `ExitCode=127:*` → command not found (wrong env/module/path)
- Python traceback → go to section 4

**Escalate when**
- Repeated node failures (`NODE_FAIL`, `CANCELLED` due to node issue)
- Accounting/history missing (`sacct` empty when it shouldn’t be)
- Suspected scheduler malfunction

---

### 3.4 Decision tree: job is **OUT_OF_MEMORY**

**Confirm**
```bash
sacct -j <jobid> --format=JobID,State,ExitCode,Elapsed,ReqMem,MaxRSS
```

If `seff` exists on the site:
```bash
seff <jobid> || true
```

**User fixes**
- Increase memory request (`#SBATCH --mem=...` or `--mem-per-cpu=...`)
- Reduce workload memory:
  - smaller batch size / fewer workers
  - stream data instead of loading all
  - avoid creating huge in-memory arrays
- Ensure they are not oversubscribing threads (see section 7)

**Prevention**
- Log memory usage periodically (application-level)
- Start with conservative `--mem` and adjust based on `MaxRSS`

**Escalate when**
- User request is already within policy but job still OOMs due to cluster limit mismatch (policy/account)
- Memory usage reporting seems wrong/inconsistent across jobs

---

### 3.5 Decision tree: job **TIMEOUT**

**Confirm**
```bash
sacct -j <jobid> --format=JobID,State,ExitCode,Elapsed
```

**User fixes**
- Increase `#SBATCH --time=...` (within policy)
- Reduce work, add checkpoints, or run smaller test first
- For iterative ML: save checkpoints every N epochs / iterations

**Escalate when**
- QoS/partition walltime limits block valid research workflows (policy discussion)

Reference: `docs/slurm_basics.md`

---

## 4) Python environment / package issues (wrong interpreter, missing deps)

### 4.0 Minimum evidence
- `which python3`, `python3 -V`
- `python3 -m pip -V`
- Full traceback
- If SLURM: job script section that activates env
- Output of:
  ```bash
  python3 tools/check_environment.py
  ```

### 4.1 Decision tree: `ModuleNotFoundError` in a job

**Step 1 — confirm interpreter identity**
```bash
which python3
python3 -V
python3 -c "import sys; print(sys.executable)"
python3 -m pip -V
```

**Step 2 — verify package in *that* interpreter**
```bash
python3 -m pip show <package> || true
```

**Step 3 — in SLURM scripts: activate env inside the script**
- venv:
  ```bash
  source /path/to/project/.venv/bin/activate
  which python
  python -V
  python -m pip -V
  ```
- conda (site dependent):
  ```bash
  source ~/miniconda3/etc/profile.d/conda.sh
  conda activate myenv
  ```

**Likely causes**
- Package installed for one Python, job uses another
- Env activated on login node but not inside batch script
- Compute nodes have no internet; install step fails silently

**User fixes**
- Always use `python -m pip ...` (not bare `pip`)
- Install on shared filesystem accessible from compute nodes
- If compute nodes have no internet: use wheelhouse workflow (`pip download` elsewhere)

**Escalate when**
- A system module/library is required (CUDA, MPI, site Python build)
- Network restrictions require an approved mirror/proxy workflow

Reference: `docs/env_management_hpc.md`

---

## 5) Filesystem / permission / quota issues

### 5.1 Symptoms
- `Permission denied`
- `Disk quota exceeded`
- `No space left on device`
- Job can’t read input or write outputs

### 5.2 Diagnostics
```bash
id
groups
ls -ld /path/to/project /path/to/project/subdir
namei -l /path/to/project/subdir 2>/dev/null || true
df -h /path/to/project
du -sh /path/to/project 2>/dev/null || true
```

Quota commands (site dependent):
```bash
quota -s 2>/dev/null || true
lfs quota -u "$USER" /path 2>/dev/null || true
```

### 5.3 User fixes
- Use correct paths (prefer absolute paths in scripts)
- Write to a directory they own / have group write to
- Clean up large intermediate files
- Move scratch outputs to long-term storage if required by policy

### 5.4 Escalate when
- ACL/group membership changes needed
- Quota increase request required
- Filesystem outage/performance incident suspected

---

## 6) Containers on HPC (Apptainer/Singularity) — support triage

> This kit documents container workflows; actual availability/flags differ by site policy.

### 6.1 Symptoms
- “Container can’t see my files”
- “Permission denied” inside container
- Wrong working directory inside container

### 6.2 Diagnostics to request
```bash
pwd
ls -la
apptainer --version 2>/dev/null || true
```

### 6.3 Common fix: bind mounts + absolute paths
Typical pattern:
```bash
apptainer exec --bind /path/on/host:/work my.sif bash -lc 'ls -la /work'
```

If the site uses restricted mounts, user may need:
- to bind only allowed paths (home, project, scratch)
- to run from compute nodes only

### 6.4 Escalate when
- Site policy prevents binding required filesystems
- Need a site-provided base image / registry / CVE scanning workflow
- Permission model is controlled by admins (setuid mode / fakeroot policy)

Reference: `docs/containers_on_hpc_apptainer.md`

---

## 7) Performance / “my job is slow”

### 7.1 Minimum evidence
- JobID
- Requested resources (cpus/mem/time)
- Whether it’s CPU-bound, I/O-bound, or waiting

### 7.2 Diagnostics
```bash
sacct -j <jobid> --format=JobID,State,Elapsed,AllocCPUS,ReqMem,MaxRSS
```

If `seff` exists:
```bash
seff <jobid> || true
```

### 7.3 Common user fixes
- Match threads to CPUs:
  ```bash
  export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
  ```
- Avoid requesting far more CPUs than used (wastes allocation, may reduce priority)
- For I/O-heavy jobs: use scratch if available; avoid many small files

### 7.4 Escalate when
- Suspected filesystem incident
- Suspected node/network degradation affecting many users

---

## 8) Escalation rules (when to stop debugging user-side)

Escalate with a short summary + evidence:

**Escalate to scheduler/admins when**
- `InvalidAccount`, `InvalidQOS`, `PartitionDown`, association/group limit blocks
- Accounting/history is missing or inconsistent (`sacct` empty unexpectedly)
- Node failures / drain reasons needed

**Escalate to storage team when**
- ACL changes needed
- Quota increases required
- Filesystem errors or outage suspected

**Escalate to security when**
- Host key changed warnings not explained
- Sensitive data handling questions or suspected exposure

**Escalate to network/SSO when**
- VPN/SSO/MFA problems prevent login despite correct key usage

---

## 9) Close-out checklist (what I record before closing)

- [ ] User goal restated + confirmed achieved
- [ ] Root cause (1–2 sentences)
- [ ] Fix applied (commands/config at user level)
- [ ] Prevention tip (what to do next time)
- [ ] Evidence captured (JobID, `sacct`, key logs)
- [ ] If escalated: who/when/what evidence sent

---

## References (this repo)
- Onboarding: `docs/onboarding_linux_and_ssh.md`
- SLURM basics: `docs/slurm_basics.md`
- Env management: `docs/env_management_hpc.md`
- Apptainer (documented): `docs/containers_on_hpc_apptainer.md`
- Tooling:
  - `scripts/collect_debug_bundle.sh`
  - `tools/check_environment.py`
- Templates:
  - `templates/support_ticket_intake.md`
  - `scripts/slurm_job_template_cpu.sh`
  - `scripts/slurm_job_array_template.sh`
  - `scripts/slurm_job_template_gpu.sh` (template-only)

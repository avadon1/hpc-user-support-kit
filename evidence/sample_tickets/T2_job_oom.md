# T2: job oom

## User message

> Hi,
>
> My training job keeps getting killed after about 40 minutes. There's no error in my Python code — it just stops. The last few lines in `slurm-5523.out` show it was still printing epoch progress, then nothing. `slurm-5523.err` is empty. Job ID is 5523. I requested 8G of memory. The dataset is about 12GB of images loaded into memory for augmentation. What's going on?
>
> — R. Student

## Clarifying questions

- Could you please copy/paste your SLURM job script  (`submit.slurm`)
- **Example output (illustrative)**
```bash
#!/usr/bin/env bash
#SBATCH --job-name=img_train
#SBATCH --partition=normal
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
set -euo pipefail
echo "HOST=$(hostname) START=$(date)"
python -V
python train.py \
  --data /project/myproj/datasets/images/ \
  --batch-size 64 \
  --num-workers 8 \
  --cache-in-ram 1
echo "END=$(date)"
```

- How does your code load the data - stream from disk, or cache/preload in RAM? Which framework/library are you using?
- **Example output (illustrative)**
	- Framework: PyTorch
	- Loader: custom `Dataset` + `torch.utils.data.DataLoader`
	- We cache decoded images in RAM (a Python dict) so augmentation is faster on later epochs
	- Augmentation: random crop/flip/color jitter on the fly

## Diagnostics

### Support Response_1

Please run the following commands and reply with the relevant outputs.
Please (if possible) do not reply with screenshots, but copy the whole outputs directly from the terminal. 

```bash
sacct -j 5523 --format=JobID,State,ExitCode,Elapsed,AllocCPUS,ReqMem%12,MaxRSS%12
seff 5523 || true
```

### User Response_1

- `sacct -j 5523 --format=JobID,State,ExitCode,Elapsed,AllocCPUS,ReqMem%12,MaxRSS%12` output:
- **Example output (illustrative)**
```bash
JobID      State ExitCode    Elapsed AllocCPUS       ReqMem       MaxRSS
------------ ---------- -------- ---------- --------- ------------ ------------
5523         OUT_OF_MEMORY     0:9   00:40:17         4         8Gn      8190Mn
5523.batch   OUT_OF_MEMORY     0:9   00:40:17         4         8Gn      8190Mn
5523.extern  COMPLETED         0:0   00:40:17         4         8Gn        18Mn
```

- `seff 5523 || true` output
- **Example output (illustrative)**
```bash
Job ID: 5523
  Cluster: example
  User/Group: rstudent(students)
  State: OUT_OF_MEMORY (exit code 0:9)
  Nodes: 1
  Cores per node: 4
  CPU Utilized: 00:32:11
  CPU Efficiency: 20.0% of 02:40:08 core-walltime
  Job Wall-clock time: 00:40:17
  Memory Utilized: 7.99 GB
  Memory Efficiency: 99.9% of 8.00 GB
```

## Findings

- Error
	- State: OUT_OF_MEMORY (exit code 0:9)
- Possible root causes
	- `ReqMem=8Gn` and `MaxRSS≈8190Mn`
	- Dataset size is 12gb; user requested 8g of memory; data is cached in RAM
	- Looks less like a memory leak and more like a predictable cache warm-up: `training job keeps getting killed after about 40 minutes`
		- With `--cache-in-ram 1`, RSS increases as samples are progressively stored in the RAM cache
	- PyTorch + `torch.utils.data.DataLoader` - possible multiprocessing + prefetch behavior and duplicate in-memory caches per worker
	- Job requests `--cpus-per-task=4` but the training script uses `DataLoader(num_workers=8)` + PyTorch
		- Might result in multiplication of memory usage because caches and prefetched batches may exist per worker
## Resolution

- Try a re-run with RAM caching disabled and fewer DataLoader workers:
	- Change the following parameters:
	    - `--cache-in-ram 0`
	    - `--num-workers 4`
- If caching must remain enabled for performance
	- Increase the SLURM memory request to match observed usage + headroom:
		- Example change: `#SBATCH --mem=8G` → `#SBATCH --mem=32G`
- If the `normal` partition can’t satisfy high-memory requests, try an appropriate high-mem partition (if permitted) or escalate for guidance.

## Prevention

- With limited memory usage it is advisable to stream the data from disk as opposed to caching it in RAM or to use smaller Dataset 
- After a run, use `sacct/seff` to capture `MaxRSS`, then set `#SBATCH --mem` to MaxRSS + 20–30% headroom
- Log memory usage periodically (application-level)
	- Add periodic RSS logging
- Keep `DataLoader(num_workers)` ≤ `--cpus-per-task`

## Escalate when

- The user needs access to a high-memory partition/QoS or doesn’t know which partition is appropriate (policy/account decision, not a user-side change).
- The job still hits `OUT_OF_MEMORY` even after requesting memory consistent with `MaxRSS` (+20–30% headroom), suggesting a broader issue.

## References

- `docs/slurm_basics.md` (OOM/failed-job section + commands)
- `docs/support_playbook.md` (triage workflow)
- (Any relevant site policy links if applicable)

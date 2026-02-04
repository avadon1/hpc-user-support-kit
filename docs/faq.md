# FAQ

## Getting access / onboarding
- What information do I need to provide to get an HPC account created?
- Why does SSH say `Permission denied (publickey)` and what should I check first?
- What does a host key warning mean, and what should I do if it appears?

## SLURM basics
- How do I choose the right partition/QoS/account for my job?
- Why is my job stuck in `PENDING` with reason `Priority`?
- What does `PENDING` reason `Resources` mean and how can I adjust my request?
- How do I find the stdout/stderr logs for my job?
- What are the most common SLURM job states and what do they mean (`COMPLETED`, `FAILED`, `TIMEOUT`, `OUT_OF_MEMORY`)?
- What should I do if `sacct` shows no history for my job?

## Python environments
- Why does my job fail with `ModuleNotFoundError` even though it works on the login node?
- How can I ensure the same Python interpreter and packages are used inside `sbatch` jobs?
- How do I install Python dependencies when compute nodes have no internet access?

## Storage / permissions
- What should I check when I get `Permission denied` reading or writing a project directory?
- What should I do if I hit `Disk quota exceeded` or `No space left on device`?

## Containers (Apptainer/Singularity)
- Why can’t my container see my project files, and how do bind mounts work on HPC?

## Support process
- What information should I include when opening a support ticket to get help faster?

# T3: Python package missing (pandas) in batch job

## User message

> Hello,
>
> I ran my analysis script on the login node last week and everything worked fine. Today I submitted it as a batch job and it fails immediately with `ModuleNotFoundError: No module named 'pandas'`. But I definitely installed pandas — I can import it right now on the login node no problem. Job ID 6102. What changed?
>
> — M. Analyst

## Clarifying questions

- Does the batch script activate the env inside the script?
T- Yes, I added conda activate
- Did you try using `check_environment.py` located in hpc-user-support-kit/tools?
T- No
- Are you using conda or venv modules?
T- Conda
- What’s the conda env name?
T- `analysis`

## Diagnostics

### Support_response_1

Please run the following commands and paste back the relevant outputs.
Please (if possible) do not reply with screenshots, but copy the whole outputs directly from the terminal. 

1. On the login node:

```bash
conda activate analysis
echo "CONDA_DEFAULT_ENV=$CONDA_DEFAULT_ENV"
which python
python -c "import sys; print(sys.executable)"
python -c "import pandas as pd; print('pandas', pd.__version__)"
```

2. Add the following to your SLURM script (close to the top) and run a simple test job:

```bash
set -euo pipefail
source ~/miniconda3/etc/profile.d/conda.sh
conda activate analysis

echo "CONDA_DEFAULT_ENV=$CONDA_DEFAULT_ENV"
which python
python -c "import sys; print(sys.executable)"
python -c "import pandas as pd; print('pandas', pd.__version__)"
```

3. And lastly please run the following in terminal:

```bash
sacct -j 6102 --format=JobID,State,ExitCode,Elapsed
grep -n "ModuleNotFoundError" slurm-6102.out slurm-6102.err || true
# copy ~20 lines around that line in your ticket
```

### User Response_1 (illustrative)

1) Login node:
- **Example output (illustrative)**
```bash
$ conda activate analysis
$ echo "CONDA_DEFAULT_ENV=$CONDA_DEFAULT_ENV"
CONDA_DEFAULT_ENV=analysis
$ which python
/home/manalyst/miniconda3/envs/analysis/bin/python
$ python -c "import sys; print(sys.executable)"
/home/manalyst/miniconda3/envs/analysis/bin/python
$ python -c "import pandas as pd; print('pandas', pd.__version__)"
pandas 2.2.1
```

2) Job status (for job 6102):

- $ sacct -j 6102 --format=JobID,State,ExitCode,Elapsed
- **Example output (illustrative)**
```bash
   JobID      State ExitCode    Elapsed
------------ ---------- -------- ----------
6102            FAILED      1:0   00:00:02
6102.batch      FAILED      1:0   00:00:02
6102.extern  COMPLETED      0:0   00:00:02
```

- $ grep -n "ModuleNotFoundError" slurm-6102.out slurm-6102.err || true
- **Example output (illustrative)**
`slurm-6102.err:17:ModuleNotFoundError: No module named 'pandas'`

- Excerpt around the error in slurm-6102.err
- **Example output (illustrative)**
```bash
15 Traceback (most recent call last):
16   File "/home/manalyst/project/analyze.py", line 4, in <module>
17     import pandas as pd
18 ModuleNotFoundError: No module named 'pandas'
```

3) After adding the conda activation + debug block and resubmitting (new job 6103):
- **Example output (illustrative)**
```bash
(slurm-6103.out relevant lines)
CONDA_DEFAULT_ENV=analysis
/home/manalyst/miniconda3/envs/analysis/bin/python
/home/manalyst/miniconda3/envs/analysis/bin/python
pandas 2.2.1
```

- $ sacct -j 6103 --format=JobID,State,ExitCode,Elapsed
- **Example output (illustrative)**
```bash
   JobID      State ExitCode    Elapsed
------------ ---------- -------- ----------
6103        COMPLETED      0:0   00:01:12
```

## Findings

- On the login node `sys.executable` points to the desired interpreter where pandas was installed
T- `.../miniconda3/envs/analysis/bin/python`
- The conda env is not active inside the batch job, even though it is active interactively
- Job 6102 most likely failed because it tried running on a different interpreter
T- most likely `/usr/bin/python3`
T- which was not modified by the user
- Job 6103 was successfully executed when conda env was initialized and activated in the SLURM script - confirming the suspected root of the cause

## Resolution

- Ask the user to Initialize and activate conda in the SLURM script by adding the following lines to their SLURM script
T- `source ~/miniconda3/etc/profile.d/conda.sh`
T- `conda activate analysis`
## Prevention

* Make venv/conda env initialization and activation mandatory segment to future SLURM scripts

## Escalate when

* Conda init path differs on the site (module-based conda)
* Current user permissions prevent installs
## References

- `docs/env_management_hpc.md` (`ModuleNotFoundError: No module named ...`)
- `docs/support_playbook.md` (triage workflow)
- (Any relevant site policy links if applicable)

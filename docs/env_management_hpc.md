# Environment management on HPC (Python)

## Goal

Make Python environments reproducible and debuggable on HPC (especially inside SLURM jobs).

## Key principles (print and tape to your monitor)

- **Activate the environment inside the job script** (compute node ≠ login node).
- Use `python -m pip ...` so pip targets the interpreter you expect.
- Don’t mix conda + pip unless you know why (and can reproduce it).
- Avoid “it works on my laptop” by capturing versions (`pip freeze` / `conda env export`).

---

## What support needs from you (copy/paste)

- Where you ran the command (login node? compute job? local machine?):
- `which python3` and `python3 -V`:
- `python3 -m pip -V`:
- `python3 tools/check_environment.py` output (from this repo):
- Error traceback (full):
- If installed packages matter: `python3 -m pip freeze | head -n 50`

If possible, attach a debug bundle:

- `bash scripts/collect_debug_bundle.sh`

---

## Quickstart A: venv + pip (simple, portable)

Create and install:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Lock versions (for reproducibility):

```bash
python -m pip freeze > requirements.lock.txt
```

Sanity check:

```bash
python -c "import sys; print(sys.executable); import sklearn; print('sklearn', sklearn.__version__)"
```

Expected: prints interpreter path and `sklearn x.y.z`

---

## Quickstart B: conda (common on HPC)

Create and install:

```bash
conda create -n myenv python=3.11 -y
conda activate myenv
python -m pip install -r requirements.txt
```

Export environment:

```bash
conda env export --from-history > environment.yml
```

---

## Activate your env inside the SLURM job script (important)

Example for venv:

```bash
# inside submit.slurm
set -euo pipefail
source /path/to/project/.venv/bin/activate
which python
python -V
python run.py
```

Example for conda (site-dependent; conda init might be needed):

```bash
# inside submit.slurm
set -euo pipefail
source ~/miniconda3/etc/profile.d/conda.sh
conda activate myenv
which python
python -V
python run.py
```

Tip: always log the interpreter path/version into the job output.

---

## Reproducibility checklist (fast but effective)

- [ ]  `requirements.txt` (human-maintained)
- [ ]  `requirements.lock.txt` or `environment.yml` (exact versions)
- [ ]  Job script prints: `which python`, `python -V`, key package versions
- [ ]  Your code writes outputs to a known path (not a random working directory)
- [ ]  You can re-create the env from scratch on another machine

---

## Debugging checklist (copy/paste commands)

Interpreter identity:

```bash
which python3
python3 -V
python3 -c "import sys; print(sys.executable); print(sys.path[:3])"
```

pip identity:

```bash
python3 -m pip -V
python3 -m pip list | head
```

Import checks (this repo):

```bash
python3 tools/check_environment.py
```

If things are weird, gather a bundle (this repo):

```bash
bash scripts/collect_debug_bundle.sh
```

---

## Common failures → likely causes → next steps

### `ModuleNotFoundError: No module named ...`

Likely causes:

- Package not installed in the active environment
- You installed into one Python but executed another

Next steps:

```bash
which python3
python3 -m pip -V
python3 -m pip show <package> || true
```

### Wrong Python inside SLURM job

Likely causes:

- Environment not activated in the batch script
- Different default Python on compute nodes

Next steps:

- Add to your job script:
    - `which python; python -V`
    - `python -c "import sys; print(sys.executable)"`

### No internet on compute nodes

Likely causes:

- Site policy blocks outbound network

Next steps:

- Build wheels / download packages elsewhere:
    - `python -m pip download -r requirements.txt -d wheels/`
    - transfer `wheels/` to HPC, then:
    - `python -m pip install --no-index --find-links wheels -r requirements.txt`

Escalate if you need an approved mirror/proxy workflow.

### Binary/ABI issues (numpy/scipy errors, GLIBC errors)

Likely causes:

- Package wheels incompatible with system libs
- Mixing system Python with user wheels

Next steps:

- Prefer site-provided Python/module stack, or conda-forge consistent stack
- Escalate if system libraries/modules are required

---

## Escalate when

- You need a system module installed (CUDA, MPI, site Python builds)
- You hit network restrictions and need an approved install workflow
- You suspect filesystem/quota issues are blocking installs
- Errors point to system-level libraries/driver mismatches (beyond user-space)

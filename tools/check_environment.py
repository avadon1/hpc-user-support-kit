#!/usr/bin/env python3
import importlib
import os
import platform
import sys
from datetime import datetime

REQUIRED = ["numpy", "sklearn"]
OPTIONAL = ["pandas"]  # common, but not required for this kit's CPU demo

def try_import(name: str):
    try:
        mod = importlib.import_module(name)
        ver = getattr(mod, "__version__", "unknown")
        return True, ver, ""
    except Exception as e:
        return False, "", f"{type(e).__name__}: {e}"

def main() -> int:
    print("=== check_environment.py ===")
    print(f"timestamp_utc={datetime.utcnow().isoformat()}Z")
    print(f"cwd={os.getcwd()}")
    print(f"user={os.getenv('USER','')}")
    print(f"hostname={platform.node()}")
    print(f"python_executable={sys.executable}")
    print(f"python_version={platform.python_version()}")
    print(f"platform={platform.platform()}")
    print(f"VIRTUAL_ENV={os.getenv('VIRTUAL_ENV','')}")
    print(f"CONDA_PREFIX={os.getenv('CONDA_PREFIX','')}")
    print(f"SLURM_JOB_ID={os.getenv('SLURM_JOB_ID','')}")
    geteuid = getattr(os, "geteuid", None)
    if callable(geteuid) and os.geteuid() == 0:
        print("warning=running_as_root (typical HPC usage is as a normal user)")

    print("\n=== Import checks ===")
    ok_required = True
    for name in REQUIRED:
        ok, ver, err = try_import(name)
        if ok:
            print(f"OK required: import {name} (version={ver})")
        else:
            print(f"FAIL required: import {name}: {err}")
            ok_required = False

    for name in OPTIONAL:
        ok, ver, err = try_import(name)
        if ok:
            print(f"OK optional: import {name} (version={ver})")
        else:
            print(f"WARN optional: import {name}: {err}")

    ok, ver, err = try_import("torch")
    if ok:
        print(f"OK optional: import torch (version={ver})")
        try:
            import torch  # noqa: F401
            print(f"torch_cuda_available={torch.cuda.is_available()}")
        except Exception as e:
            print(f"WARN optional: torch CUDA check failed: {type(e).__name__}: {e}")
    else:
        print("INFO optional: torch not installed; skipping CUDA check")

    print("\n=== Result ===")
    if ok_required:
        print("RESULT=PASS (required imports available)")
        return 0
    print("RESULT=FAIL (missing required imports)")
    print("hint=activate correct env and/or install requirements")
    return 1

if __name__ == "__main__":
    raise SystemExit(main())

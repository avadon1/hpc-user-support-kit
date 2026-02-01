#!/bin/bash
#SBATCH --job-name=cpu_demo_sklearn
#SBATCH --partition=test
#SBATCH --time=00:05:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --output=/data/cpu_demo/slurm-%j.out

set -euo pipefail

echo "=== Job metadata ==="
date -Is
hostname
echo "SLURM_JOB_ID=${SLURM_JOB_ID:-}"
echo

cd /data/cpu_demo

echo "=== Python ==="
python3 --version
python3 -m pip --version
echo

echo "=== Create/activate venv ==="
rm -rf .venv
python3 -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install -U pip setuptools wheel

echo "=== Install requirements ==="
python -m pip install -r requirements.txt

echo "=== Run demo ==="
python run.py --seed 0 --out output/metrics.json

echo "=== metrics.json ==="
cat output/metrics.json

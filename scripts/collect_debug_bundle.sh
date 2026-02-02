#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
collect_debug_bundle.sh
Creates a timestamped debug bundle at evidence/debug_bundles/.

Usage:
  bash scripts/collect_debug_bundle.sh [--job-output /path/to/slurm-123.out] [--note "text"]

Notes:
- Environment variables are saved with basic redaction of likely secrets.
- Do NOT commit bundles to git; only commit terminal transcripts.
USAGE
}

JOB_OUTPUT=""
NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --job-output) JOB_OUTPUT="${2:-}"; shift 2 ;;
    --note) NOTE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTDIR="${REPO_ROOT}/evidence/debug_bundles"
mkdir -p "${OUTDIR}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
BASENAME="debug_bundle_${TS}"
TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "${TMPDIR}"; }
trap cleanup EXIT

BUNDLEDIR="${TMPDIR}/${BASENAME}"
mkdir -p "${BUNDLEDIR}"

# Metadata
{
  echo "timestamp_utc=${TS}"
  echo "repo_root=${REPO_ROOT}"
  echo "cwd=$(pwd)"
  echo "user=${USER:-}"
  echo "hostname=$(hostname 2>/dev/null || true)"
  echo "note=${NOTE}"
  echo "job_output_arg=${JOB_OUTPUT}"
} > "${BUNDLEDIR}/metadata.txt"

# OS/kernel
uname -a > "${BUNDLEDIR}/uname.txt" 2>&1 || true
if [[ -r /etc/os-release ]]; then
  cat /etc/os-release > "${BUNDLEDIR}/os-release.txt" 2>&1 || true
fi

# Env (redacted)
env | sort | sed -E 's/^([^=]*(TOKEN|SECRET|PASSWORD|PASSWD|PASS|KEY|COOKIE|CREDENTIAL|AUTH|BEARER)[^=]*=).*/\1<redacted>/I' \
  > "${BUNDLEDIR}/env_redacted.txt" 2>&1 || true

# Python/pip
command -v python3 > "${BUNDLEDIR}/which_python3.txt" 2>&1 || true
python3 -V > "${BUNDLEDIR}/python3_version.txt" 2>&1 || true
python3 -c 'import sys; print(sys.executable)' > "${BUNDLEDIR}/python3_executable.txt" 2>&1 || true

if python3 -m pip --version >/dev/null 2>&1; then
  python3 -m pip freeze > "${BUNDLEDIR}/pip_freeze.txt" 2>&1 || true
else
  echo "pip not available for python3" > "${BUNDLEDIR}/pip_freeze.txt"
fi

# Disk usage
df -h > "${BUNDLEDIR}/df_h.txt" 2>&1 || true
du -sh "${REPO_ROOT}" > "${BUNDLEDIR}/du_sh_repo_root.txt" 2>&1 || true

# SLURM env vars (may be empty if not inside a job)
( env | sort | grep -E '^SLURM_' || true ) > "${BUNDLEDIR}/slurm_env.txt"

# Optional: include a job output file
if [[ -n "${JOB_OUTPUT}" ]]; then
  if [[ -f "${JOB_OUTPUT}" ]]; then
    cp -a "${JOB_OUTPUT}" "${BUNDLEDIR}/job_output.log"
  else
    echo "Provided --job-output not found: ${JOB_OUTPUT}" > "${BUNDLEDIR}/job_output.log"
  fi
fi

TARBALL="${OUTDIR}/${BASENAME}.tar.gz"
tar -czf "${TARBALL}" -C "${TMPDIR}" "${BASENAME}"

echo "Wrote debug bundle: ${TARBALL}"
echo "Tip: bundles are ignored by git; commit only the transcript under evidence/terminal_transcripts/"

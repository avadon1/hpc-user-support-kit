# SLURM Sandbox (Docker Compose)

## Upstream / attribution
Source: NL-BioImaging/NL-BIOMERO-Local-Slurm
Commit: 8bfedc3fc1ae4247bc4d19ce4e1fc699c489b816
License: MIT (see `slurm_sandbox/LICENSE`)
Upstream README preserved as `slurm_sandbox/UPSTREAM_README.md`.

## Usage
From repo root:
- docker compose -f slurm_sandbox/docker-compose.yml up -d --build
- docker compose -f slurm_sandbox/docker-compose.yml ps
- docker exec -it slurmctld bash

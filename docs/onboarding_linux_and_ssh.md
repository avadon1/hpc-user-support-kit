# Onboarding: Linux + SSH (HPC user)

## Goal

Get connected to an HPC system safely (SSH), move files reliably, and collect the necessary info when something fails.

## Scope (what this doc is / isn’t)

- This is **user-level onboarding** (not cluster administration).
- Commands are designed to be copy/paste friendly.
- Use placeholders like `cluster.example.edu` and `youruser`.

---

## What support needs from you (copy/paste into a ticket)

- Your OS + terminal (e.g., Windows + WSL2 Ubuntu 22.04, macOS, Linux):
- Network context (home, office, VPN on/off):
- Hostname you are connecting to (e.g., `login.cluster.example.edu`):
- Username:
- Exact command you ran:
- Full error output (no screenshots if possible):
- If SSH fails: run `ssh -vvv ...` and attach the last ~40 lines (redact if needed)

---

## 5-minute quickstart checklist

1) Confirm SSH client exists: `ssh -V`
2) Create a key: `ssh-keygen -t ed25519 -C "you@example.com"`
3) Add the **public key** (`~/.ssh/id_ed25519.pub`) to the HPC portal / admins
4) Test login: `ssh youruser@login.cluster.example.edu`
5) Move a file: `scp ./local.txt youruser@login.cluster.example.edu:~/`

---

## 0) Windows + WSL2 notes (if applicable)
- Prefer running SSH **inside WSL** so paths and permissions are consistent.
- Avoid committing anything under `~/.ssh/` to git. Never paste private keys into tickets.

Useful commands:
```bash
uname -a
cat /etc/os-release
ssh -V
```

Expected:

- You see Ubuntu 22.04 info and an OpenSSH version.

---

## 1) Create an SSH key (recommended)

Create an Ed25519 key:

```bash
ssh-keygen -t ed25519 -C "you@example.com"
```

Suggested prompts:

- File: press Enter for default (`~/.ssh/id_ed25519`)
- Passphrase: recommended (use a password manager)

Show your **public** key (safe to share):

```bash
cat ~/.ssh/id_ed25519.pub
```

Expected output starts with:

- `ssh-ed25519 AAAA... you@example.com`

---

## 2) Fix SSH permissions (common cause of “Permission denied”)

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

Check:

```bash
ls -la ~/.ssh
```

Expected:

- Private key is `-rw-------` (600)

---

## 4) First login “sanity checks”

Once connected, run:

```bash
hostname
whoami
pwd
id
groups
```

Expected:

- `whoami` matches your account
- You land in your home directory (often `/home/youruser`)

Check filesystem space:

```bash
df -h
```

---

## 5) File transfer

### Option A: scp (simple)

Copy local file to remote home:

```bash
scp ./local.txt youruser@login.cluster.example.edu:~/
```

Copy remote file down:

```bash
scp youruser@login.cluster.example.edu:~/remote.txt ./
```

### Option B: rsync (recommended for directories / resumable)

```bash
rsync -avP ./project/ youruser@login.cluster.example.edu:~/project/
```

Using SSH config shortcut:

```bash
rsync -avP ./project/ mycluster:~/project/
```

---

## 6) “Where should I run compute?”

Rule of thumb:

- **Login node**: editing files, git, compiling small things, short sanity tests (seconds)
- **Compute nodes**: real workloads via scheduler (e.g., `sbatch`, `srun`, `salloc`)

If you’re not sure, ask support what “acceptable login node usage” is.

---

## 7) Common SSH failures → what to do

### Permission denied (publickey)

Likely causes:

- Your public key was not installed on the HPC side
- You are using the wrong username/key
- Bad permissions on `~/.ssh/` or key file

Do:

```bash
ssh -i ~/.ssh/id_ed25519 youruser@login.cluster.example.edu
```

### Connection timed out / No route to host

Likely causes:

- Need VPN
- Firewall blocks port 22
- Wrong hostname

Do:

```bash
nslookup login.cluster.example.edu || true
ping -c 2 login.cluster.example.edu || true
```

### Host key verification failed / REMOTE HOST IDENTIFICATION HAS CHANGED

Treat as a **security event** until confirmed.

- Escalate to admins/support with the exact message.
- Do not “just delete” `~/.ssh/known_hosts` unless instructed.

### Debug mode (attach to support)

```bash
ssh -vvv youruser@login.cluster.example.edu
```

Attach the last ~40 lines.

---

## Escalate when

- Host key changed warnings
- You can authenticate but cannot access expected directories (ACL/permissions)
- Multi-factor auth / SSO issues
- You suspect account provisioning problems

# Cluster 5 — Red Team Automation (IRTX)

Automates the four approved attacks from the MBK Red Team Playbook so the output
drops straight into your evidence log. Built for an **authorised, instructor-run
classroom exercise** against the pfSense WAN addresses the teacher handed out.

## ⚠ Rules of engagement — read first
- Attack **only the group(s) your teacher assigned.** `targets.txt` ships with
  every line commented out; un-comment only your assigned targets.
- WAN pfSense addresses only. **Nothing** on `172.27.60.x` infra, no Proxmox
  hosts, no TAFE network, no other cohort's lab.
- Written go-ahead from the teacher + project lead before the first command.
- Non-destructive by design: no DoS, no config changes, no exploits. The
  credential script tries a **tiny fixed list of defaults** (≤4), not a brute
  force — on purpose, so you stay under the lockout threshold and don't get your
  own box banned.

## Expecting zero findings is the normal, passing result
9 times out of 10 you'll find nothing, and that's the point:
these scripts are built to **prove the controls held**, with timestamped
evidence. "Two open ports, no default creds, everything else filtered" is a
complete, markable result — write it up as a clean perimeter, not a failure.

## The two-IP / HA angle
Each group got **two** WAN addresses (primary + HA/CARP secondary pfSense).
Groups that ran out of time on HA (like yours did) may have only one live, or
may have stood up a second node that's **less hardened than the primary**. So:
- Scan **both** addresses per group.
- Compare the recon + exposure output side by side. A secondary that exposes a
  management port the primary doesn't is your most likely real finding.

## Usage (on KaliWAN)
Kali's default shell is zsh — start with `bash`.

```bash
# 1. edit targets.txt → un-comment ONLY your assigned group(s)
nano targets.txt

# 2. run everything (recon + exposure + default-creds) into one evidence folder
bash run-all.sh

# …or run a single stage:
bash 01-recon.sh            # Attack 1  full TCP + UDP + service/script scan
bash 03-exposure-check.sh   # Attack 4  what's reachable from the WAN
bash 02-default-creds.sh    # Attack 2  default-credential check (pfSense GUI + SSH)
bash 04-eicar-test.sh       # Attack 3  benign AV test (run on an authorised host)
```

Everything lands in `./evidence/<timestamp>/` — zip that folder for the report.

## Requirements
`nmap`, `curl`, `sshpass` (for the SSH default-cred check). On Kali:
```bash
sudo apt update && sudo apt install -y nmap curl sshpass
```

## Hosting on GitHub + pulling tomorrow
```bash
# on your machine now
cd redteam-cluster5 && git init && git add . && git commit -m "IRTX red team toolkit"
git branch -M main && git remote add origin git@github.com:<you>/<repo>.git && git push -u origin main

# on KaliWAN tomorrow (raw file URLs)
for f in lib.sh targets.txt 01-recon.sh 02-default-creds.sh 03-exposure-check.sh 04-eicar-test.sh run-all.sh; do
  wget -q "https://raw.githubusercontent.com/<you>/<repo>/main/$f"
done
chmod +x *.sh
```
Tip: keep the repo **private**. The target IPs are classroom-sensitive, and a
public repo of "attack other groups' firewalls" scripts reads badly out of context.

## File map
| File | Playbook attack | Does |
|------|-----------------|------|
| `01-recon.sh` | Attack 1 | full TCP + top UDP + `-sV -sC`, saved `-oA` |
| `02-default-creds.sh` | Attack 2 | default-cred check: pfSense GUI (CSRF-aware) + SSH if password auth is on |
| `03-exposure-check.sh` | Attack 4 | bash `/dev/tcp` OPEN/BLOCKED map of mgmt ports |
| `04-eicar-test.sh` | Attack 3 | writes the benign EICAR test file |
| `run-all.sh` | 1→4→2 | chains the network stages into one evidence folder |
| `lib.sh` | — | shared logging, target loader, ROE guard |

# Notelseit Backup & Restore 2.0 (in development)

Universal Linux backup tools. **Not tied to aaPanel or any control panel.**

> Phase 1 is experimental. Do not install or use for production backups until disaster-recovery tests are complete. Historical scripts remain in this repository for reference, not as recommended production entrypoints.

## Supported in phase 1

- Linux with Bash 4+, GNU tar, `flock`, `sha256sum`, `stat`, `gzip` and GNU coreutils.
- Full snapshots of explicitly configured directories; supports webroots, mail folders and service configuration paths.
- Optional *named* MySQL/MariaDB SQL dumps, via locally protected client defaults file.
- Local checksummed archives, atomic promotion after verification and per-destination locking.
- Manual listing and SHA-256 verification, plus automated smoke test and ShellCheck.
- All panel environments are configured with absolute paths; adapter autodiscovery is **not implemented**.

## Local isolated trial (never target live data)

1. Clone to a test VM or non-production directory.
2. Copy `config/config.example.conf` to a trusted admin-controlled absolute path **outside web roots**, change `BACKUP_DEST` and `BACKUP_SOURCES` to dedicated disposable directories, and run `chmod 600 /path/to/config.conf`.
3. Run:

```bash
bash bin/notelseit-backup backup --config /path/to/config.conf
bash bin/notelseit-backup list --config /path/to/config.conf
bash bin/notelseit-backup verify --config /path/to/config.conf --run run-YYYYMMDDTHHMMSSZ-PID
bash tests/smoke.sh
```

**Security:** configuration files are executed as trusted Bash, not parsed as inert data. Do not load configuration received from untrusted parties. Credentials should not be included in a Git repository. MySQL dumps can contain personal data; protect backups at rest and prevent access over HTTP. Checksums detect accidental modification but **do not authenticate** data against an attacker able to modify both archives and manifests.

**Limitations:** the optional SSH upload supports single completed runs with remote SHA-256 verification, but has no unattended scheduling, encryption at rest, remote retention, or end-to-end remote integration tests. Staging-only restore never overwrites a target or imports SQL automatically. There is no database restore, retention, incremental chain, notification, panel adapter, or complete consistency check for live-changing source contents. No claim of disaster recovery readiness. Do not replace existing backup systems.

## Roadmap

1. Harden full backup tests (including database failure modes, interrupted writes, unusual filenames and permissions).
2. Separate inert configuration parser, inventory and panel adapters (aaPanel/Plesk/cPanel/DirectAdmin/manual Linux).
3. Add remote backend with verification, encryption and retention guaranteeing recoverable backup sets.
4. Add staged, opt-in restores to isolated paths/databases, without implicit production overwrite.
5. Test end-to-end restore, document migration and publish stable release.

## Legacy

Original scripts `backup.sh`, `backup_all.sh`, `backup_site_mysql`, `restore_file_tar` and `restore_sql.sh` are preserved unchanged. **Some contain destructive deletion commands and insecure restore defaults. Do not run them unreviewed.**

## Experimental restore to staging (unprivileged account only)

```bash
bash bin/notelseit-restore --backup-dir /absolute/backups/run-YYYYMMDDTHHMMSSZ-PID --target /new/empty/staging/path
```

The target must **not exist**. This is not a production restore and must not be run against untrusted archives. Inspect staged data before any manual deployment. SQL files are copied, **never imported**.

## Experimental SSH upload (non-root account)

```bash
bash bin/notelseit-push-ssh --backup-dir /absolute/backups/run-YYYYMMDDTHHMMSSZ-PID --ssh-user backupuser --ssh-host backup.example.net --remote-dir /srv/backup-archives
```

Requires `ssh` and `rsync` on both hosts, a dedicated remote account with write access, and **pre-provisioned verified host keys** in known_hosts. Does not use `--delete`. Remote checksum verification protects against accidental transfer corruption but not a compromised destination. Use server-side access controls and encryption at rest. Test with disposable data and destinations only. No automatic retention is provided.

## Phase 2: staged restores and read-only retention proposals

The `bin/notelseit-restore` command uses `bin/safe_extract.py` (Python 3 standard library) to reject tar path traversal, symlinks, hardlinks and device files. It only restores files into a **new** staging directory as an unprivileged user. SQL is copied, not imported. Test archives and failure cases in disposable environments before production use.

A read-only retention planner is available:

```bash
bash bin/notelseit-retention-plan --backup-root /srv/notelseit-backups --keep-latest 7
```

This prints candidates by run timestamp. **It never deletes backup data**; it is not yet a safe automated retention engine. Retention must additionally account for remote copies, verified integrity, and future incremental chains.

Security tests use synthetic tar files to ensure unsafe members are rejected. End-to-end MySQL restore, remote SSH integration, encryption at rest and automatic retention remain unimplemented and require further work. Do not interpret passing tests as a production disaster-recovery guarantee.

## Phase 5 (experimental): recipient-encrypted offline archives

Encrypted export uses the open-source `age` command-line tool and an administrator-managed public recipient key. This workflow is **opt-in** and does not change unencrypted local backup storage. Never publish identity/private-key material in Git or alongside backups. Use a separate machine to escrow the private identity and verify that recovery remains possible.

```bash
age-keygen -o /secure/identity.txt
chmod 600 /secure/identity.txt
age-keygen -y /secure/identity.txt  # prints public recipient age1...
bash bin/notelseit-encrypt --backup-dir /srv/backups/run-YYYYMMDDTHHMMSSZ-PID --recipient age1... --output /srv/offsite/run.tar.age
bash bin/notelseit-decrypt --input /srv/offsite/run.tar.age --identity /secure/identity.txt --output /isolated/newly-decrypted.tar
```

The decrypt command **never extracts or restores** files: an administrator must review the resulting tar in an isolated environment. Never put decrypted archives inside publicly served directories.

Limitations: encrypted export is a standalone artifact and is not yet integrated with `notelseit-push-ssh`, automated schedules or retention. Current backup runs and unencrypted staging remain on disk. For secure remote-only workflows, the transport needs an explicit encrypted-artifact mode, and raw backup transport should be disabled by policy. The package is not production-ready.

## Phase 6: experimental encrypted SSH offsite round-trip

The `bin/notelseit-push-encrypted` transport accepts **only** a pre-encrypted `.tar.age` artifact and matching SHA-256 sidecar. It uses a dedicated non-root SSH account, pre-verified SSH host keys and remote checksum verification before publishing. Unlike `bin/notelseit-push-ssh`, it never uploads the plaintext backup run.

```bash
bash bin/notelseit-encrypt --backup-dir /srv/backups/run-YYYYMMDDTHHMMSSZ-PID --recipient age1... --output /srv/exports/run-YYYYMMDDTHHMMSSZ-PID.tar.age
bash bin/notelseit-push-encrypted --input /srv/exports/run-YYYYMMDDTHHMMSSZ-PID.tar.age --ssh-user backupuser --ssh-host backup.example.net --remote-dir /srv/offsite
```

The SSH CI integration downloads the remote encrypted artifact back, validates its sidecar, decrypts with a separate local private identity and compares recovered synthetic file content. It also checks duplicate upload rejection and changed ciphertext rejection.

**Security limitations:** no end-to-end automated encryption policy (unencrypted local runs still exist), no encryption key escrow or rotation, no fully atomic publication of the pair `artifact + SHA-256 sidecar`, no remote retention, and no production disaster recovery certification. SSH host keys must be provisioned and validated out of band; `ssh-keyscan` in CI is for the disposable local test host only, not production host trust.

## Phase 7: conservative read-only retention audit

The new `bin/notelseit-retention-audit` makes **no deletions and has no apply mode**. It inventories complete local run directories or local age-encrypted artifacts and verifies all listed SHA-256 checksums before producing candidates. Any unexpected, incomplete, corrupt or unrecognized entry blocks the entire plan. Keep at least one verified run, even if the requested retention is smaller; `--keep-latest` accepts only 1 through 100000.

```bash
python3 bin/notelseit-retention-audit --backup-root /srv/notelseit-backups --type local --keep-latest 7
python3 bin/notelseit-retention-audit --backup-root /srv/encrypted-exports --type encrypted --keep-latest 14
```

This tool assumes the root contains only runs and the backup lock file, or only paired `.tar.age` and `.sha256` files. Incomplete transfers and unknown files block evaluation. A `CANDIDATE_ONLY` entry is **not permission to delete**: SHA-256 cannot prove recovery success, key availability, independent offsite copies or authenticity against an attacker who can replace manifests. No GFS grandfather-father-son selection, time-based retention, cross-destination coordination, locking or destructive operations are implemented. Do not automate deletion from this output.

## Phase 8: GFS dry-run retention (daily/weekly/monthly)

The new `bin/notelseit-retention-gfs` selects a union of the newest backup from each available UTC day, ISO week (Monday-starting, ISO week-year) and UTC calendar month. The quotas count **periods containing a valid backup**, not calendar slots with no backup. A backup selected by multiple quotas is kept once, with combined reasons. All artifacts are first verified with the existing fail-closed retention audit logic.

Default policy: **7 daily, 4 weekly, 12 monthly**. Example:

```bash
python3 bin/notelseit-retention-gfs --backup-root /srv/notelseit-backups --type local --daily 7 --weekly 4 --monthly 12
python3 bin/notelseit-retention-gfs --backup-root /srv/encrypted-exports --type encrypted --daily 7 --weekly 4 --monthly 12
```

Output classes: `KEEP` (protected and why) and `CANDIDATE_ONLY` (not selected by this simulation). **NO delete or apply option exists.** Corrupt data, incomplete runs, unknown contents and sidecar failures block the plan; it does not attempt to repair them. This is count-based GFS selection, not a guarantee that backups exist on every required date. Neither SHA-256 nor the GFS simulation proves actual recoverability or the availability of private decryption keys. Never turn candidates into automatic deletion based on this output.

## Phase 9: disaster recovery preflight (read-only)

`python3 bin/notelseit-dr-preflight --backup-dir /absolute/run-YYYYMMDDTHHMMSSZ-PID` validates checksums, manifest coverage and archive structure before any attempted restore. It never extracts, overwrites or deletes data. A successful preflight is **not** an end-to-end disaster recovery certificate: the operator still must test restoring a complete offsite copy to an isolated server, including databases, private-key recovery, service configuration and applications. The archive preflight does not guarantee capacity, live-database consistency or credentials.

Release gates before enabling destructive retention: (1) all CI jobs pass; (2) restore a remote encrypted artifact using a backed-up private identity; (3) import database into an isolated MariaDB/MySQL instance and validate expected data; (4) test failure on corrupted archives and missing keys; (5) ensure two independent verified copies and a tested recovery procedure; (6) document and rehearse rollback. **No unattended deletion or production rollout is enabled by this project.**

## Phase 10: external monitoring hooks (read-only)

`bin/notelseit-healthcheck` emits one JSON status line and exits 0 on success, 2 on missing, stale or corrupt backup inventory. It verifies **every** complete local run or encrypted age archive in the selected directory using the fail-closed retention audit, then enforces freshness for the most recent run. It does not send email, execute webhooks, read private keys or delete files.

```bash
python3 bin/notelseit-healthcheck --backup-root /srv/notelseit-backups --type local --max-age-hours 36
python3 bin/notelseit-healthcheck --backup-root /srv/encrypted-exports --type encrypted --max-age-hours 36
```

Integrate exit codes with an **existing** monitoring service (Zabbix, Prometheus node exporter textfile wrapper, cron monitoring, Icinga, etc.). Avoid sending detailed file paths or data to public alert endpoints. This is a diagnostic signal, not proof that the private key or a restore environment is available. The tool does not schedule backups or notify operators itself. A rollout must configure and test alert routing separately.

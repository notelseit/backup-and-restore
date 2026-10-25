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

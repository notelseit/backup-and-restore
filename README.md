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

**Limitations:** no remote transfer, encryption, automatic restore, database restore, retention, incremental chain, notification, panel adapter, or complete consistency checks for live-changing directory contents yet. No claim of disaster recovery readiness. Do not replace existing backup systems.

## Roadmap

1. Harden full backup tests (including database failure modes, interrupted writes, unusual filenames and permissions).
2. Separate inert configuration parser, inventory and panel adapters (aaPanel/Plesk/cPanel/DirectAdmin/manual Linux).
3. Add remote backend with verification, encryption and retention guaranteeing recoverable backup sets.
4. Add staged, opt-in restores to isolated paths/databases, without implicit production overwrite.
5. Test end-to-end restore, document migration and publish stable release.

## Legacy

Original scripts `backup.sh`, `backup_all.sh`, `backup_site_mysql`, `restore_file_tar` and `restore_sql.sh` are preserved unchanged. **Some contain destructive deletion commands and insecure restore defaults. Do not run them unreviewed.**

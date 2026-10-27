Notelseit Backup & Restore

Linux tools for file and MySQL/MariaDB backups, encrypted exports and staged recovery.
Independent of hosting control panels. Experimental: production recovery validation is still required.

## Features

- File snapshots and optional database dumps with SHA-256 verification.
- Encrypted `age` exports and SSH transfer with verified host keys.
- Restore to a new staging directory as an unprivileged user; SQL import remains manual.
- Read-only retention audit and daily/weekly/monthly GFS plans. No automatic deletion.
- Archive preflight, JSON health checks and opt-in HTTPS notifications.

## Requirements

Linux, Bash 4+, Python 3, GNU tar/coreutils, gzip and flock.
Optional: MySQL/MariaDB client, age, SSH and rsync for the corresponding features.

## Quick start

Use isolated test data. Copy `config/config.example.conf` to a trusted absolute path,
edit the source and destination paths, and protect the configuration:

```bash
chmod 600 /path/to/config.conf
run=$(bash bin/notelseit-backup backup --config /path/to/config.conf)
bash bin/notelseit-backup verify --config /path/to/config.conf --run "$run"
bash bin/notelseit-backup list --config /path/to/config.conf
```

Configuration is executable Bash. Keep database credentials in a separate protected
client defaults file, outside Git and web roots.

## Restore and monitoring

Run restore as a non-root user. The staging target must not already exist:

```bash
bash bin/notelseit-restore --backup-dir /srv/backups/run-YYYYMMDDTHHMMSSZ-PID --target /srv/new-staging
python3 bin/notelseit-dr-preflight --backup-dir /srv/backups/run-YYYYMMDDTHHMMSSZ-PID
python3 bin/notelseit-healthcheck --backup-root /srv/backups --type local --max-age-hours 36
python3 bin/notelseit-retention-gfs --backup-root /srv/backups --type local --daily 7 --weekly 4 --monthly 12
```

Health checks return 0 for healthy backups and 2 for missing, stale or corrupt inventory.
Notifications default to offline preview; sending requires explicit configuration.

## Documentation

- [Recovery rehearsal and release criteria](docs/disaster-recovery-runbook.md)
- [HTTPS notifications and release evidence](docs/notifications-and-release.md)

Passing checks does not prove independent offsite or application recovery.
Legacy scripts at the repository root are historical and may contain destructive commands;
use the `bin/` tools above. No production deployment or backup scheduling is enabled automatically.

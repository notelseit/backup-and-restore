# Controlled disaster-recovery rehearsal (pre-production)

Status: **not a production certification**. Run these steps on disposable hosts with representative test data. Do not execute original legacy scripts; they contain destructive operations.

## Separation of duties

- Source host: produces a backup run and age-encrypted export; private age identity is NOT present here.
- Backup host: dedicated, non-root SSH account, write-restricted filesystem, separately backed-up encrypted artifacts.
- Recovery host: isolated Linux VM (no public traffic), private age identity loaded securely from independent offline key escrow, scratch disk with sufficient space, disposable MariaDB/MySQL instance.

## Recovery evidence to collect

1. Record exact Git commit, OS version, archive IDs, start and end UTC timestamps, database version and operator.
2. On the source/test host: create a completed backup and validate `notelseit-backup verify` plus `notelseit-dr-preflight`.
3. Export with `notelseit-encrypt`; verify local ciphertext sidecar. Upload with `notelseit-push-encrypted`. Use manually verified SSH host keys.
4. From the recovery host: fetch the encrypted artifact and its sidecar from remote backup storage, verify the SHA-256 sidecar locally. Keep private identity off the source and backup hosts.
5. Run `notelseit-decrypt` to a new local tar file, then **inspect before extracting**. The tar contains one completed run directory.
6. Unpack only in a dedicated isolated directory as an unprivileged user, validate the embedded checksums and archive preflight again. Never blindly extract archives onto production paths.
7. Run `notelseit-restore` as a non-root user to a NEW staging directory and inspect restored files.
8. Restore SQL into **new test databases** with a separate disposable database user. Confirm row counts, checksums, encoding, stored procedures and required applications can connect. Do not use production database names.
9. Validate application startup on an isolated VM, permission ownership, virtual-host configuration and any mail data used by that system. Record RPO/RTO observations and failure scenarios.
10. Rehearse loss of the source host and failure of the primary key holder. Validate the separately escrowed key can decrypt an independent encrypted backup. Document owner and replacement key procedures.
11. Test damaged ciphertext, missing sidecar, inaccessible key, unavailable backup host and insufficient disk: each must fail without touching production or existing good copies.
12. Sign off the rehearsal evidence. Only then consider staging a human-approved retention change in a separate Pull Request.

## Release blockers / acceptance criteria

- All GitHub Actions on the proposed release commit pass, including DB, SSH, encrypted round-trip, GFS and DR preflight.
- SSH offsite copies remain encrypted; no remote backup user is root; no unreviewed `--delete` or `rm -rf` in the new workflow.
- At least two independently stored recoverable copies exist, and one independent private-key recovery route is tested.
- Full application recovery has been witnessed on isolated infrastructure; integrity hashes alone are not sufficient.
- Alerting, scheduler, monitoring, account permissions, lifecycle policies and operator manuals reviewed by a designated maintainer.
- Incident and rollback procedures are documented. Incomplete/corrupt backups cannot be silently discarded.
- Automatic deletion and production deployment **remain disabled** until all the above are recorded and approved.

The scripts currently implement a partial universal Linux toolchain, not a certified production backup service. In particular they do not yet coordinate source and remote retention or have transactional end-to-end backups for all live workloads.

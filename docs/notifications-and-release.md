# Notifications and release evidence

Status: candidate only; no production certification or deployment.

## Explicit notification delivery

`python3 bin/notelseit-notify` consumes one healthcheck JSON report on stdin and
prints an offline preview. Only service, status and backup kind are forwarded.
Messages, filenames, backup roots and arbitrary report fields are discarded.
Use `--send` only after configuring `NOTELSEIT_NOTIFY_URL` (HTTPS, no embedded
credentials/query/fragment) and `NOTELSEIT_NOTIFY_TOKEN` via a protected secret
store or a mode-600 environment file. Never put tokens in command arguments,
repository files, scheduler logs or shell tracing. Use a dedicated revocable token.
The endpoint is trusted operator configuration; restrict outbound traffic to it.

Delivery validates TLS certificates, refuses redirects, ignores ambient proxies,
times out after 10 seconds and accepts only HTTP 2xx. It performs one attempt:
no hidden retries, automatic scheduling, suppression or deduplication. Failures
return 2 with a generic diagnostic. Preview success is not delivery evidence.

Preserve the healthcheck exit code separately: an alert successfully delivered
for a critical backup must not turn the backup status green. Example for an
explicitly configured test endpoint, using a private temporary report:

```bash
umask 077
report=$(mktemp)
python3 bin/notelseit-healthcheck --backup-root /isolated/backups --type local > "$report"
health=$?
python3 bin/notelseit-notify --send < "$report"
delivery=$?
# Capture both codes in the scheduler; remove only this owned temporary report.
rm -- "$report"
if [ "$delivery" -ne 0 ]; then exit 3; fi
exit "$health"
```

Do not run this example under `set -e` without handling the healthcheck failure.
Route monitor/scheduler failure through an independent watchdog. A killed process
or a host outage cannot send its own alert. The receiver must accept this minimal
JSON contract; provider-specific payloads require a reviewed adapter.

## Isolated acceptance and merge order

1. Review and pass all checks for PR #9's exact head; merge #9 first.
2. Retarget #10 to master after #9, recheck its exact head and CI trigger coverage.
3. Review this follow-up against #10, including offline notification tests and
   rehashed gzip trailer corruption. Merge only after all checks pass.
4. Run the independent recovery rehearsal in `disaster-recovery-runbook.md` on
   disposable Linux hosts, synthetic data, a separate test database and test SSH
   account. Disable production routes and use test-only keys and identities.
5. Exercise fresh/stale/missing/corrupt health reports against a dedicated test
   receiver. Record receipt, routing and on-call acknowledgement; test HTTP errors,
   timeout, invalid TLS, redirect rejection and lost scheduler/host via watchdog.
6. Complete the evidence record below. Until then release and production rollout
   remain blocked. Automatic retention deletion remains disabled.

## Evidence record (must be completed by the rehearsal operator)

| Gate | Evidence required | Current status |
|---|---|---|
| Exact release commit | SHA and successful Actions URLs | Pending |
| Independent offsite restore | Test hosts, archive hashes, escrow key route | Pending |
| Database and application | Row checks, application startup, permissions | Pending |
| RPO/RTO | UTC start/end, data timestamp, measured duration | Pending |
| Failure scenarios | Corruption, missing key, disk full, offsite outage | Pending |
| Alert route | Test receiver receipt and acknowledgement, watchdog failure | Pending |
| Rollback | Stop test scheduler, revert candidate, retain good backups | Planned |
| Maintainer sign-off | Operator, reviewer, UTC date, evidence location | Pending |

CI and local tests demonstrate only the scenarios they actually execute.
Checksums do not authenticate maliciously replaced artifacts; encrypted inventory
health does not prove decryption, archive recovery or application consistency.

#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/site" "$T/runs" "$T/encrypted"
echo "safe content" > "$T/site/a.txt"
cat > "$T/config.conf" <<EOF
BACKUP_DEST="$T/runs"
BACKUP_SOURCES=("$T/site")
BACKUP_DATABASES=()
EOF
chmod 600 "$T/config.conf"
for i in 1 2 3; do
  bash "$ROOT/bin/notelseit-backup" backup --config "$T/config.conf" >/dev/null
done
plan=$(python3 "$ROOT/bin/notelseit-retention-audit" --backup-root "$T/runs" --type local --keep-latest 2)
[[ $(printf '%s\n' "$plan" | grep -c '^KEEP') -eq 2 ]]
[[ $(printf '%s\n' "$plan" | grep -c '^CANDIDATE_ONLY') -eq 1 ]]
[[ $(find "$T/runs" -maxdepth 1 -type d -name 'run-*' | wc -l) -eq 3 ]]
oldest=$(find "$T/runs" -maxdepth 1 -type d -name 'run-*' | LC_ALL=C sort | head -1)
printf 'modified\n' >> "$oldest/MANIFEST.tsv"
if python3 "$ROOT/bin/notelseit-retention-audit" --backup-root "$T/runs" --type local --keep-latest 2; then
  echo "Corruption was accepted" >&2; exit 1
fi
# Isolate encrypted artifacts to check sidecars and orphan handling.
age-keygen -o "$T/identity" 2>/dev/null
recipient=$(age-keygen -y "$T/identity")
newest=$(find "$T/runs" -maxdepth 1 -type d -name 'run-*' | LC_ALL=C sort | tail -1)
bash "$ROOT/bin/notelseit-encrypt" --backup-dir "$newest" --recipient "$recipient" --output "$T/encrypted/$(basename "$newest").tar.age"
python3 "$ROOT/bin/notelseit-retention-audit" --backup-root "$T/encrypted" --type encrypted --keep-latest 1 | grep -q '^KEEP'
printf 'tamper' >> "$T/encrypted/$(basename "$newest").tar.age"
if python3 "$ROOT/bin/notelseit-retention-audit" --backup-root "$T/encrypted" --type encrypted --keep-latest 1; then
  echo "Tampered encrypted artifact was accepted" >&2; exit 1
fi
echo 'Read-only retention tests passed'

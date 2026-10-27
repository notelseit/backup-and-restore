#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/source" "$T/backup"
printf 'disaster recovery rehearsal\n' > "$T/source/test.txt"
cat > "$T/config.conf" <<EOF
BACKUP_DEST="$T/backup"
BACKUP_SOURCES=("$T/source")
BACKUP_DATABASES=()
EOF
chmod 600 "$T/config.conf"
run=$(bash "$ROOT/bin/notelseit-backup" backup --config "$T/config.conf")
python3 "$ROOT/bin/notelseit-dr-preflight" --backup-dir "$T/backup/$run"
printf 'junk' >> "$T/backup/$run/files-0.tar.gz"
if python3 "$ROOT/bin/notelseit-dr-preflight" --backup-dir "$T/backup/$run"; then
  echo "Corrupted run accepted" >&2; exit 1
fi
echo 'Disaster recovery preflight checks passed'

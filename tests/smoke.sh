#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/site" "$T/out"
printf 'sample data\n' > "$T/site/index.txt"
cat > "$T/config.conf" <<EOF
BACKUP_DEST="$T/out"
BACKUP_SOURCES=("$T/site")
BACKUP_DATABASES=()
EOF
chmod 600 "$T/config.conf"
run=$(bash "$ROOT/bin/notelseit-backup" backup --config "$T/config.conf" | tail -1)
bash "$ROOT/bin/notelseit-backup" verify --config "$T/config.conf" --run "$run"
bash "$ROOT/bin/notelseit-backup" list --config "$T/config.conf" | grep -Fx "$run"
tar -tzf "$T/out/$run/files-0.tar.gz" | grep -q 'index.txt'
printf 'corruption' >> "$T/out/$run/files-0.tar.gz"
if bash "$ROOT/bin/notelseit-backup" verify --config "$T/config.conf" --run "$run"; then
  echo "ERROR: verification accepted corruption" >&2; exit 1
fi
echo "Smoke test passed"

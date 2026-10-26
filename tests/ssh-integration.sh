#!/usr/bin/env bash
# CI only: temporary local SSH server and disposable backup data.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/site" "$T/backups"
printf 'verify SSH contents\n' > "$T/site/hello.txt"
cat > "$T/config.conf" <<EOF
BACKUP_DEST="$T/backups"
BACKUP_SOURCES=("$T/site")
BACKUP_DATABASES=()
EOF
chmod 600 "$T/config.conf"
run=$(bash "$ROOT/bin/notelseit-backup" backup --config "$T/config.conf")
remote=/home/backupci/archive
bash "$ROOT/bin/notelseit-push-ssh" --backup-dir "$T/backups/$run" --ssh-user backupci --ssh-host 127.0.0.1 --remote-dir "$remote"
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes backupci@127.0.0.1 "cd '$remote/$run' && sha256sum --check --status SHA256SUMS"
if bash "$ROOT/bin/notelseit-push-ssh" --backup-dir "$T/backups/$run" --ssh-user backupci --ssh-host 127.0.0.1 --remote-dir "$remote"; then
  echo 'ERROR: refusing duplicate remote run failed' >&2
  exit 1
fi
printf 'tamper' >> "$T/backups/$run/files-0.tar.gz"
if bash "$ROOT/bin/notelseit-push-ssh" --backup-dir "$T/backups/$run" --ssh-user backupci --ssh-host 127.0.0.1 --remote-dir "$remote"; then
  echo 'ERROR: upload accepted corrupted local run' >&2
  exit 1
fi
echo 'SSH integration passed'

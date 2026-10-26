#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/site" "$T/backups" "$T/export"
printf 'Confidential test string\n' > "$T/site/secret.txt"
cat > "$T/config.conf" <<EOF
BACKUP_DEST="$T/backups"
BACKUP_SOURCES=("$T/site")
BACKUP_DATABASES=()
EOF
chmod 600 "$T/config.conf"
age-keygen -o "$T/identity.txt" 2>/dev/null
chmod 600 "$T/identity.txt"
recipient=$(age-keygen -y "$T/identity.txt")
run=$(bash "$ROOT/bin/notelseit-backup" backup --config "$T/config.conf")
bash "$ROOT/bin/notelseit-encrypt" --backup-dir "$T/backups/$run" --recipient "$recipient" --output "$T/export/backup.tar.age"
[[ -s "$T/export/backup.tar.age" && -s "$T/export/backup.tar.age.sha256" ]]
( cd "$T/export"; sha256sum -c --status backup.tar.age.sha256 )
if grep -aq 'Confidential test string' "$T/export/backup.tar.age"; then
  echo "Ciphertext contains plaintext!" >&2; exit 1
fi
bash "$ROOT/bin/notelseit-decrypt" --input "$T/export/backup.tar.age" --identity "$T/identity.txt" --output "$T/export/backup.tar"
tar -xOf "$T/export/backup.tar" "$run/files-0.tar.gz" > "$T/export/files-0.tar.gz"
[[ $(tar -xOf "$T/export/files-0.tar.gz" ./secret.txt) == 'Confidential test string' ]]
if bash "$ROOT/bin/notelseit-encrypt" --backup-dir "$T/backups/$run" --recipient "$recipient" --output "$T/export/backup.tar.age"; then
  echo "Existing encrypted artifact overwritten" >&2; exit 1
fi
age-keygen -o "$T/wrong.txt" 2>/dev/null
chmod 600 "$T/wrong.txt"
if bash "$ROOT/bin/notelseit-decrypt" --input "$T/export/backup.tar.age" --identity "$T/wrong.txt" --output "$T/export/incorrect.tar"; then
  echo "Wrong identity accepted" >&2; exit 1
fi
[[ ! -e "$T/export/incorrect.tar" ]]
echo "Age encryption round-trip and rejection tests passed"

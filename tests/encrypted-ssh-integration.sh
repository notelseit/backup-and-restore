#!/usr/bin/env bash
# Disposable end-to-end: backup -> age -> SSH -> download -> decrypt -> compare.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/site" "$T/backups" "$T/out" "$T/retrieved"
printf 'sensitive synthetic data\n' > "$T/site/test.txt"
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
name="$run.tar.age"
bash "$ROOT/bin/notelseit-encrypt" --backup-dir "$T/backups/$run" --recipient "$recipient" --output "$T/out/$name"
remote=/home/backupci/encrypted-archives
bash "$ROOT/bin/notelseit-push-encrypted" --input "$T/out/$name" --ssh-user backupci --ssh-host 127.0.0.1 --remote-dir "$remote"
scp -q -o BatchMode=yes -o StrictHostKeyChecking=yes "backupci@127.0.0.1:$remote/$name" "$T/retrieved/$name"
scp -q -o BatchMode=yes -o StrictHostKeyChecking=yes "backupci@127.0.0.1:$remote/$name.sha256" "$T/retrieved/$name.sha256"
( cd "$T/retrieved"; sha256sum -c --status "$name.sha256" )
bash "$ROOT/bin/notelseit-decrypt" --input "$T/retrieved/$name" --identity "$T/identity.txt" --output "$T/retrieved/restored.tar"
tar -xOf "$T/retrieved/restored.tar" "$run/files-0.tar.gz" > "$T/retrieved/source.tar.gz"
[[ $(tar -xOf "$T/retrieved/source.tar.gz" ./test.txt) == "sensitive synthetic data" ]]
if bash "$ROOT/bin/notelseit-push-encrypted" --input "$T/out/$name" --ssh-user backupci --ssh-host 127.0.0.1 --remote-dir "$remote"; then
  echo "Duplicated remote upload unexpectedly allowed" >&2; exit 1
fi
printf 'tampered' >> "$T/out/$name"
if bash "$ROOT/bin/notelseit-push-encrypted" --input "$T/out/$name" --ssh-user backupci --ssh-host 127.0.0.1 --remote-dir "$remote"; then
  echo "Corrupted ciphertext unexpectedly accepted" >&2; exit 1
fi
echo "Encrypted SSH retrieval/decryption verified"

#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/backups" "$T/malicious-target" "$T/legit-target"
python3 - "$T" <<'PY'
import io, pathlib, sys, tarfile
root = pathlib.Path(sys.argv[1])
with tarfile.open(root / "bad.tar.gz", "w:gz") as tf:
    item = tarfile.TarInfo("../escaped")
    data = b"do not write this"
    item.size = len(data)
    tf.addfile(item, io.BytesIO(data))
with tarfile.open(root / "link.tar.gz", "w:gz") as tf:
    item = tarfile.TarInfo("sym")
    item.type = tarfile.SYMTYPE
    item.linkname = "/etc/passwd"
    tf.addfile(item)
with tarfile.open(root / "ok.tar.gz", "w:gz") as tf:
    item = tarfile.TarInfo("./valid.txt")
    data = b"valid"
    item.size = len(data)
    tf.addfile(item, io.BytesIO(data))
PY
for archive in bad link; do
  if python3 "$ROOT/bin/safe_extract.py" "$T/$archive.tar.gz" "$T/malicious-target"; then
    echo "Unsafe archive was accepted: $archive" >&2; exit 1
  fi
done
[[ ! -e "$T/escaped" && ! -e "$T/malicious-target/sym" ]]
python3 "$ROOT/bin/safe_extract.py" "$T/ok.tar.gz" "$T/legit-target"
[[ $(cat "$T/legit-target/valid.txt") == valid ]]
for n in 1 2 3; do
  run="run-2026100${n}T000000Z-1"
  mkdir -p "$T/backups/$run"
  : > "$T/backups/$run/SHA256SUMS"
  : > "$T/backups/$run/MANIFEST.tsv"
done
result=$(bash "$ROOT/bin/notelseit-retention-plan" --backup-root "$T/backups" --keep-latest 2)
[[ "$result" == *"run-20261001T000000Z-1"* ]]
[[ -d "$T/backups/run-20261001T000000Z-1" ]] || { echo "Retention deleted data" >&2; exit 1; }
echo "Security tests passed"

#!/usr/bin/env bash
# Integration test: disposable MariaDB service ONLY.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
mkdir -p "$T/site" "$T/backups"
printf 'integration sample\n' > "$T/site/index.html"
cat > "$T/mysql.cnf" <<EOF
[client]
host=127.0.0.1
port=3306
user=root
password=${TEST_MYSQL_PASSWORD:?Set TEST_MYSQL_PASSWORD only in CI}
EOF
chmod 600 "$T/mysql.cnf"
mariadb --defaults-extra-file="$T/mysql.cnf" -e "CREATE DATABASE test_backup_source; CREATE TABLE test_backup_source.records (id INT PRIMARY KEY, value VARCHAR(100)); INSERT INTO test_backup_source.records VALUES (1, 'verified restore');"
cat > "$T/config.conf" <<EOF
BACKUP_DEST="$T/backups"
BACKUP_SOURCES=("$T/site")
BACKUP_DATABASES=("test_backup_source")
MYSQL_DEFAULTS_FILE="$T/mysql.cnf"
EOF
chmod 600 "$T/config.conf"
run=$(bash "$ROOT/bin/notelseit-backup" backup --config "$T/config.conf")
bash "$ROOT/bin/notelseit-backup" verify --config "$T/config.conf" --run "$run"
gzip -t "$T/backups/$run/mysql-test_backup_source.sql.gz"
mariadb --defaults-extra-file="$T/mysql.cnf" -e "CREATE DATABASE test_backup_restored;"
gzip -dc "$T/backups/$run/mysql-test_backup_source.sql.gz" | mariadb --defaults-extra-file="$T/mysql.cnf" test_backup_restored
actual=$(mariadb --defaults-extra-file="$T/mysql.cnf" --skip-column-names --batch -e "SELECT value FROM test_backup_restored.records WHERE id=1")
[[ $actual == "verified restore" ]] || { echo "Database restore contents mismatched" >&2; exit 1; }
# A dump authentication failure must never be promoted to a completed run.
cat > "$T/invalid.cnf" <<EOF
[client]
host=127.0.0.1
port=3306
user=root
password=deliberately_wrong_password
EOF
chmod 600 "$T/invalid.cnf"
sed "s|$T/mysql.cnf|$T/invalid.cnf|" "$T/config.conf" > "$T/invalid-config.conf"
chmod 600 "$T/invalid-config.conf"
if bash "$ROOT/bin/notelseit-backup" backup --config "$T/invalid-config.conf"; then
  echo "Invalid credentials unexpectedly produced a valid backup" >&2; exit 1
fi
[[ $(find "$T/backups" -mindepth 1 -maxdepth 1 -type d -name 'run-*' | wc -l) -eq 1 ]] || {
  echo "Failed database backup published a complete run" >&2; exit 1;
}
echo "MariaDB round-trip and failure detection passed"

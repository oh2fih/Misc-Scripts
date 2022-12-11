#!/bin/bash
# -----------------------------------------------------------
# Backup all MySQL/MariaDB databases; dump & compress.
# Overwrites older backups matching the same date pattern.
# Recommended to be scheduled with a SystemD service & timer.
#
# Default settings can be changed with environment variables:
#  ExcludeDatabases: databases to exclude, separated with '|'
#  DatePattern: +FORMAT; see man date(1)
#  compress: Compress usign Gzip; true/false
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

DefaultExcludeDatabases="information_schema|performance_schema|mysql"
DefaultDatePattern="%d"

# Set defaults if environment variables not set.

if [[ ! -v ExcludeDatabases ]]; then
  ExcludeDatabases="$DefaultExcludeDatabases"
fi

if [[ ! -v DatePattern ]]; then
  DatePattern="$DefaultDatePattern"
fi

# Check for requirements.

if ! command -v mysql > /dev/null 2>&1; then
  echo "*** ERROR! This script requires mysql!"
  exit 1
fi

if ! command -v mysqldump > /dev/null 2>&1; then
  echo "*** ERROR! This script requires mysqldump!"
  exit 1
fi

if ! command -v gzip > /dev/null 2>&1; then
  echo "*** WARNING! Gzip not found; skipping compression."
  compress=false
else
  if [[ ! -v compress ]]; then
    compress=true
  fi
fi

set -e

date=$(date "+${DatePattern}")

# List existing databases not excluded.

databases=$(
  mysql -N -B -e "SHOW DATABASES;" \
    | grep -E -v "$ExcludeDatabases"
)

echo "Working directory: $(pwd)"
echo "Excluding databases: ${ExcludeDatabases}"
echo "Date from pattern (${DatePattern}): ${date}"

# Backup & compress.

for db in $databases; do
  echo "Dumping database: ${db}"
  mysqldump --databases "$db" > "${date}-${db}.sql"
  if [ "$compress" = true ]; then
    echo "Compressing dump: ${date}-${db}.sql"
    gzip -f "${date}-${db}.sql"
  else
    echo "Saved: ${date}-${db}.sql"
  fi
done

echo "All backups successful."

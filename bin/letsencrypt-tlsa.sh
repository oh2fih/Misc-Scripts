#!/bin/bash
# ------------------------------------------------------------------------------
# Create TLSA records from the current & backup Let's Encrypt Intermediate CAs
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------

SOURCE="/certificates/"
BASE_URL="https://letsencrypt.org"

# Check for requirements. Print all unmet requirements at once.

required_command() {
  if ! command -v "$1" &> /dev/null; then
    if [ -z ${2+x} ]; then
      echo -e "\033[0;31mThis script requires ${1}!\033[0m" >&2
    else
      echo -e "\033[0;31mThis script requires ${1} ${2}!\033[0m" >&2
    fi
    ((UNMET=UNMET+1))
  fi
}

UNMET=0

required_command "openssl" "for creating TLSA records"
required_command "curl" "for fetching data"
required_command "grep"
required_command "sed"
required_command "awk"

if [ "$UNMET" -gt 0 ]; then
  exit 1
fi

# Get URLs for the Subordinate (Intermediate) CAs, including backups

INTERMEDIATE_PATHS=$(
  curl --silent "${BASE_URL}${SOURCE}" \
    | sed '/subordinate-intermediate-cas/d' \
    | sed '/.summary.Retired..summary./q' \
    | grep -oE "/certs/[0-9]+/[0-9a-zA-Z]+(-cross)?.pem"
  )

if [ "$INTERMEDIATE_PATHS" = "" ]; then
  echo "Failed to fetch certificate list from ${BASE_URL}${SOURCE}" >&2
  exit 1
fi

# Create TLSA records

while IFS= read -r path ; do
  echo "[${BASE_URL}${path}]" >&2
  PEM=$(curl --silent "${BASE_URL}${path}")
  if [[ "$PEM" =~ ^[-]+BEGIN[[:space:]]CERTIFICATE[-]+ ]]; then
    echo "$PEM" \
      | openssl x509 -outform DER \
      | openssl dgst -sha256 -hex \
      | awk '{print "le-ca TLSA 2 1 1", $NF}'
  fi

done <<< "$INTERMEDIATE_PATHS"

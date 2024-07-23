#!/bin/bash
read -r -d '' USAGE << EOM
# ------------------------------------------------------------------------------
# Create TLSA records from the current & backup Let's Encrypt Intermediate CAs
#
# Usage: letsencrypt-tlsa.sh [-f] [-m N] [-l "label [TTL]"] [-h] [2>/dev/null]
#
#   -f   Full certificate mode (RFC 6698, 2.1.2 The Selector Field 0).
#        Without this option, SubjectPublicKeyInfo (1) is used by default.
#
#   -m   Matching Type (RFC 6698, 2.1.3); defaults to SHA-256
#        0  Exact match on selected content
#        1  SHA-256 hash of selected content [RFC6234]
#        2  SHA-512 hash of selected content [RFC6234]
#
#   -l   Label (domain) part. Defaults to le-ca without FQDN.
#        Can contain TTL after the label; this has no validation!
#        * Example with FQDN, for SMTP:  _25._tcp.example.com.
#        * Example with TTL, for HTTPS:  "_443._tcp.ecample.com. 3600"
#
#   -h   Help. Prints this and exits (ignoring all other options).
#
# Unique TLSA records will be printed to stdout, everything else to stderr.
# To get a clean output you can paste to your zone file, add 2>/dev/null.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------
EOM

SOURCE="/certificates/"
BASE_URL="https://letsencrypt.org"

SELECTOR=1  # SubjectPublicKeyInfo
DIGEST=1    # SHA-256
LABEL="le-ca"

while getopts ":hfm:l:" opt; do
  case ${opt} in
    h)
      echo -e "$USAGE" >&2
      echo "# LE Chains of Trust page: ${BASE_URL}${SOURCE}"
      exit 1
      ;;
    f)
      SELECTOR=0
      ;;
    m)
      case $OPTARG in
        0|1|2)
          DIGEST="$OPTARG"
          ;;
        *)
          echo "Invalid option: -m must be 0, 1 (SHA-256), or 2 (SHA-512)" >&2
          exit 1
          ;;
      esac
      ;;
    l)
      LABEL="$OPTARG"
      ;;
    \?)
      echo "Invalid option: $OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Invalid option: $OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done

# Check for requirements. Print all unmet requirements at once.

required_command() {
  if ! command -v "$1" &> /dev/null; then
    if [ -z ${2+x} ]; then
      echo "This script requires ${1}!" >&2
    else
      echo "This script requires ${1} ${2}!" >&2
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

if (( DIGEST == 0 )); then
  required_command "hexdump" "for -m 0"
fi

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

# Helper functions to handle different options

extract_der() {
  case "$1" in
    0)
      openssl x509 -outform DER
      ;;
    1) 
      openssl x509 -noout -pubkey | openssl pkey -pubin -outform DER
      ;;
  esac
}

digest() {
  case "$1" in
    0)
      hexdump -ve '/1 "%02X"'
      ;;
    1)
      openssl dgst -sha256 -hex
      ;;
    2)
      openssl dgst -sha512 -hex
      ;;
  esac
}

# Create TLSA records

declare -a RECORDS=()
while IFS= read -r path ; do
  PEM=$(curl --silent "${BASE_URL}${path}")
  echo "[${BASE_URL}${path}]" >&2
  if [[ "$PEM" =~ ^[-]+BEGIN[[:space:]]CERTIFICATE[-]+ ]]; then
    TLSA=$(
      echo "$PEM" \
        | extract_der "$SELECTOR" \
        | digest "$DIGEST" \
        | sed -e 's/\(.*\)/\U\1/' \
        | awk '{print "'"$LABEL"' TLSA 2 '"$SELECTOR"' '"$DIGEST"'", $NF}'
      )

    # Do not print duplicate records to stdout
    if [[ ! ${RECORDS[*]} =~ $TLSA ]]; then
      echo "$TLSA"
      RECORDS+=("$TLSA")
    else
      echo "(${TLSA})" >&2
    fi
  else
    echo "(Reply was not a PEM encoded certificate)" >&2
  fi
done <<< "$INTERMEDIATE_PATHS"

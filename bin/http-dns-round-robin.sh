#!/bin/bash
# ------------------------------------------------------------------------------
# Print HTTP headers for every DNS round-robin IP (IPv4 + IPv6)
#
# Usage: http-dns-round-robin.sh URL
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------

URL="$1"

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

required_command "curl" "for HTTP connections"
required_command "dig" "for DNS queries"
required_command "head"
required_command "tail"
required_command "awk"

if [ "$UNMET" -gt 0 ]; then
  exit 1
fi

regex='http(s)?://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
if ! [[ $URL =~ $regex ]]; then
  echo "The first argument was not a valid URL!" >&2
  exit 1
fi

HOSTNAME=$(echo "$URL" | awk -F/ '{print $3}')

while read -r ip
do
  echo "[${ip}]"
  curl --resolve "[${HOSTNAME}]:443:${ip}" --silent --head "$URL"
done <<< "$( \
  dig +short "$HOSTNAME" A | tail -n 1 \
  ; dig +short "$HOSTNAME" AAAA | tail -n 1
)"

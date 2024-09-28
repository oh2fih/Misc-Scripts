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
required_command "grep"

if [ "$UNMET" -gt 0 ]; then
  exit 1
fi

regex='http(s)?://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
if ! [[ $URL =~ $regex ]]; then
  echo "The first argument was not a valid URL!" >&2
  exit 1
fi

IPV4SEG="(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
IPV4ADDR="(${IPV4SEG}\.){3,3}${IPV4SEG}"
IPV6SEG="[0-9a-fA-F]{1,4}"
IPV6ADDR="("
IPV6ADDR+="(${IPV6SEG}:){7,7}${IPV6SEG}|"
IPV6ADDR+="(${IPV6SEG}:){1,7}:|"
IPV6ADDR+="(${IPV6SEG}:){1,6}:${IPV6SEG}|"
IPV6ADDR+="(${IPV6SEG}:){1,5}(:${IPV6SEG}){1,2}|"
IPV6ADDR+="(${IPV6SEG}:){1,4}(:${IPV6SEG}){1,3}|"
IPV6ADDR+="(${IPV6SEG}:){1,3}(:${IPV6SEG}){1,4}|"
IPV6ADDR+="(${IPV6SEG}:){1,2}(:${IPV6SEG}){1,5}|"
IPV6ADDR+="${IPV6SEG}:((:${IPV6SEG}){1,6})|"
IPV6ADDR+=":((:${IPV6SEG}){1,7}|:)|"
IPV6ADDR+="fe80:(:${IPV6SEG}){0,4}%[0-9a-zA-Z]{1,}|"
IPV6ADDR+="::(ffff(:0{1,4}){0,1}:){0,1}${IPV4ADDR}|"
IPV6ADDR+="(${IPV6SEG}:){1,4}:${IPV4ADDR}"
IPV6ADDR+=")"
IPADDR="${IPV4ADDR}|${IPV6ADDR}"

PROTOCOL=$(echo "$URL" | awk -F/ '{print $1}')
HOSTPORT=$(echo "$URL" | awk -F/ '{print $3}')
if [[ $HOSTPORT =~ .*:[0-9]+ ]]; then
  PORT="$(echo "$HOSTPORT" | awk -F: '{print $NF}')"
  HOSTNAME="${HOSTPORT%":${PORT}"}"
else
  HOSTNAME="$HOSTPORT"
  if [[ $PROTOCOL == 'https:' ]]; then
    PORT=443
  else
    PORT=80
  fi
fi

while read -r ip
do
  echo "[${ip}]:${PORT}"
  curl --resolve "${HOSTNAME}:${PORT}:[${ip}]" \
    --no-progress-meter --head "$URL"
done <<< "$(
  dig +short "$HOSTNAME" A | grep -E -o "$IPADDR"
  dig +short "$HOSTNAME" AAAA | grep -E -o "$IPADDR"
)"

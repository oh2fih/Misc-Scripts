#!/bin/bash
# -----------------------------------------------------------
# Unbans the given IPs from all Fail2Ban jails.
#
# Usage: sudo unfail2ban.sh ip [ip ...]
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

IPS=()

for ARG in "$@"; do
  if [[ "$ARG" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    IPS+=("$ARG")
  fi
  if [[ "${ARG,,}" =~ ^([0-9a-f]{1,4}:+){3,7}[0-9a-f]{1,4}$ ]]; then
    IPS+=("${ARG,,}")
  fi
done

if [ ${#IPS[@]} -eq 0 ]; then
  printf "\n%s\n" "Usage: sudo $0 ip [ip ...]" >&2
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  printf "\n%s\n" "This script requires sudo privileges." >&2
  exit 1
fi

if ! command -v fail2ban-client > /dev/null 2>&1; then
  printf "\n%s\n" "This script requires fail2ban-client!" >&2
  exit 1
fi

JAILS=$(
  fail2ban-client status \
    | grep "Jail list" \
    | sed -E 's/^[^:]+:[ \t]+//' \
    | sed 's/,//g'
  )

for JAIL in $JAILS; do
  JAILSTATUS=$(fail2ban-client status "$JAIL" | grep -v File | grep -v "\\s0")
  for IP in "${IPS[@]}"; do
    if [[ "$JAILSTATUS" =~ .*[[:space:]]+"$IP"([[:space:]]|$)+.* ]]; then
      RESULT=$(fail2ban-client set "$JAIL" unbanip "$IP")
      if [ "$RESULT" = "1" ] | [ "$RESULT" = "$IP" ] ; then
        printf "Unbanned %s from jail %s\\n" "$IP" "$JAIL"
      else
        printf "Failed to unban %s from jail %s\\n" "$IP" "$JAIL" >&2
      fi
    fi
  done
done

printf "\\n"

REJECTS=$(
  iptables -L -n | awk '$1=="REJECT" && $4!="0.0.0.0/0"' \
    && ip6tables -L -n | awk '$1=="REJECT"'
  )
for IP in "${IPS[@]}"; do
  echo "$REJECTS" | grep " $IP "
done

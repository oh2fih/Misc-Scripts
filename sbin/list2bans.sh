#!/bin/bash
# -----------------------------------------------------------
# Lists all Fail2Ban jail statuses or jails banning an ip.
#
# Usage: sudo list2bans.sh [ip]
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
  echo "*** ERROR! This script requires sudo privileges."
  exit 1
fi

if [ "$#" -gt 0 ]; then
  if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    IP="$1"
    BANNED=()
  else
    if [[ $1 =~ ^([0-9a-f]{1,4}:+){3,7}[0-9a-f]{1,4}$ ]]; then
      IP="$1"
      BANNED=()
    else
      echo "Usage: sudo $0 [ip]"
      exit 1
    fi
  fi
fi

JAILS=$(
  fail2ban-client status \
    | grep "Jail list" \
    | sed -E 's/^[^:]+:[ \t]+//' \
    | sed 's/,//g'
  )

for JAIL in $JAILS; do
  JAILSTATUS=$(fail2ban-client status "$JAIL" | grep -v File | grep -v "\\s0")
  if [ -z ${IP+x} ]; then
    printf "\\n%s\\n" "$JAILSTATUS"
  else
    if [[ "$JAILSTATUS" =~ .*[[:space:]]+"$IP"([[:space:]]|$)+.* ]]; then
      BANNED+=("$JAIL")
    fi
  fi
done

if [ -z ${IP+x} ]; then
  printf "\\n"
else
  if [ ${#BANNED[@]} -gt 0 ]; then
    printf "\\n%s banned by jails: %s\\n\\n" "$IP" "${BANNED[*]}"
  else
    printf "\\n%s not banned\\n\\n" "$IP"
  fi
fi

iptables -L -n | awk '$1=="REJECT" && $4!="0.0.0.0/0"' | grep " $IP "
ip6tables -L -n | awk '$1=="REJECT"' | grep " $IP "

#!/bin/bash
# -----------------------------------------------------------
# Find duplicate SSH host keys in a CIDR range
#
# Examine your network for shared host keys 
# that could potentially be dangerous.
#
# Usage:   duplicate-ssh-hostkeys.sh CIDR [HostKeyAlgorithms]
# Example: duplicate-ssh-hostkeys.sh 127.0.0.0/24 ecdsa-sha2-nistp256
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

if [ "$#" -lt 1 ]; then
  printf "\n%s\n" "Usage:   $0 CIDR [KexAlgorithms]" >&2
  printf "\n%s\n\n" "Example: $0 127.0.0.0/24 ecdh-sha2-nistp521" >&2
  exit 1
fi

HostKeyAlgorithms=${2:-ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521}

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

required_command "prips" "for expanding cidr ranges"
required_command "parallel" "for running multiple ssh connections at once"
required_command "ssh" "for making the connections"
required_command "mktemp"

if [ "$UNMET" -gt 0 ]; then
  exit 1
fi

if ! ips=$(prips "$1"); then
  echo
  echo "The \"$1\" is not a network starting address in CIDR notation."
  exit 1
fi

echo "Creating temporary directory for connection logs..."
tmpdir=$(mktemp hostkeyscan.XXXXXXXXXX -td)
echo "Created $tmpdir"
echo "HostKeyAlgorithms=$HostKeyAlgorithms"
count=$(echo "$ips" |wc -l)
echo "Scanning hostkeys in $1 ($count hosts)..."

echo "$ips" \
  | parallel -j 32 --timeout 20 --progress \
    "ssh -v \
      -o ConnectTimeout=5 \
      -o BatchMode=yes \
      -o HostKeyAlgorithms=\"$HostKeyAlgorithms\" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o IdentitiesOnly=yes \
      -o IdentityFile=/dev/null \
      -l hostkeyscan {} > \"$tmpdir/ssh-{}.log\" \
      2>&1"

echo "Done with $(find "$tmpdir" | wc -l) attempted connections."
echo "Removing logs for unsuccessful connections..."

grep -L "debug1: Connection established." "$tmpdir"/ssh-*.log \
  | xargs rm 2>/dev/null

echo "$(find "$tmpdir" | wc -l) connections established."
echo
echo "Searching duplicate hostkeys..."
echo

hostkeys=$(grep "debug1: Server host key" "$tmpdir"/ssh-*.log)

duplicatekeys=$(echo "$hostkeys" \
  | awk '{ print $6; }' \
  | sort \
  | uniq -d)

if [ -n "$duplicatekeys" ]; then
  echo "  count key"
  echo "  ----- -------------"

  echo "$hostkeys" \
    | awk '{ print $6; }' \
    | sort \
    | uniq -cd \
    | sort -n

  while IFS= read -r key; do
    echo
    echo "Hosts sharing $key"
    grep "$key" "$tmpdir"/ssh-*.log \
      | sed "s|$tmpdir/ssh-|  |g" \
      | sed "s|.log.*||g" \
      | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n
  done <<< "$duplicatekeys"

else
  echo "No duplicate host keys found."
fi

echo
echo "You can manually examine the connection logs in $tmpdir"

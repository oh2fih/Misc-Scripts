#!/bin/bash
read -r -d '' USAGE << EOM
# -----------------------------------------------------------------------------
# Find duplicate SSH host keys in a CIDR range
#
# Examine your network for shared host keys
# that could potentially be dangerous.
#
# Usage:   duplicate-ssh-hostkeys.sh CIDR [HostKeyAlgorithm ...]
# Example: duplicate-ssh-hostkeys.sh 127.0.0.0/24 ssh-ed25519 ssh-rsa
#
# Rationale for the ssh options used:
#
#   -v                           Verbosity required for collecting host keys.
#   ConnectTimeout=5             Enough for handshakes; speeds up the script.
#   BatchMode=yes                We do not want password prompts in scripts.
#   HostKeyAlgorithms=$algo      A single host key instead of server's default.
#   StrictHostKeyChecking=no     Do not care about the known hosts list.
#   UserKnownHostsFile=/dev/null ...and do not save these hosts to the list.
#   IdentitiesOnly=yes           Do not use the SSH keys from configuration.
#   IdentityFile=/dev/null       ...and make sure no keys are found.
#   -l hostkeyscan               Username that shows in the target system logs.
#        
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------------------------
EOM

if [ "$#" -lt 1 ]; then
  echo -e "\033[0;32m${USAGE}\033[0m" >&2
  exit 1
fi

# Default HostKeyAlgorithms

if [ "$#" -eq 1 ]; then
  declare -a HostKeyAlgorithms=(
    "ecdsa-sha2-nistp256"
    "ecdsa-sha2-nistp384"
    "ecdsa-sha2-nistp521"
    "ssh-ed25519"
    "ssh-rsa"
    "ssh-dss"
  )
else
  declare -a HostKeyAlgorithms=("${@:2}")
fi

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

if ! ips=$(prips "$1" 2>/dev/null); then
  echo -e "\033[0;31m\"$1\" is not a CIDR network starting address.\033[0m" >&2
  exit 1
fi

echo "Creating temporary directory for connection logs..."
tmpdir=$(mktemp hostkeyscan.XXXXXXXXXX -td)
echo "Created $tmpdir"
echo
count=$(echo "$ips" |wc -l)
echo "Collecting hostkeys in $1 ($count hosts)..."

# Data collection

total="${#HostKeyAlgorithms[@]}"
i=1
for algo in "${HostKeyAlgorithms[@]}"; do
  echo
  echo "Testing $algo ($i/$total)"

  echo "$ips" \
    | parallel -j 128 --timeout 20 --progress \
      "ssh -v \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        -o HostKeyAlgorithms=\"$algo\" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o IdentitiesOnly=yes \
        -o IdentityFile=/dev/null \
        -l hostkeyscan {} \
        >> \"$tmpdir/ssh-{}.log\" \
        2>&1"

  ((++i))
done

# Cleanup

echo
echo "Done: $(find "$tmpdir" | wc -l) hosts tested."
echo "Removing logs for unsuccessful connections..."

grep -L "debug1: Connection established." "$tmpdir"/ssh-*.log \
  | xargs rm 2>/dev/null

# Analyze

echo "$(find "$tmpdir" | wc -l) hosts with established connections."
echo
echo "Searching duplicate hostkeys..."
echo

hostkeys=$(grep "debug1: Server host key" "$tmpdir"/ssh-*.log)

duplicatekeys=$(echo "$hostkeys" \
  | awk '{ print $5" "$6; }' \
  | sort \
  | uniq -d)

if [ -n "$duplicatekeys" ]; then
  echo "  count key"
  echo "  ----- -------------"

  echo "$hostkeys" \
    | awk '{ print $5" "$6; }' \
    | sort \
    | uniq -cd \
    | sort -nr

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

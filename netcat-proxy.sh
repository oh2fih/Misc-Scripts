#!/bin/sh
# -----------------------------------------------------------
# Creates a simple persistent proxy with netcat & named pipes.
#
# Usage: netcat-proxy.sh listenport targethost targetport
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

if [ "$#" -lt 3 ]; then
  printf "\n%s\n" "Usage: $0 listenport targethost targetport" >&2
  printf "\n%s\n" "Creates a simple persistent proxy with netcat & named pipes." >&2
  exit 1
fi

if ! command -v nc > /dev/null 2>&1; then
  printf "\n%s\n" "This script requires nc (netcat)!" >&2
  exit 1
fi

# Make temporary named pipes.
srvpipe=$(mktemp -u)
mkfifo -m 600 "$srvpipe" || exit 1
clipipe=$(mktemp -u)
mkfifo -m 600 "$clipipe" || exit 1

# Launch two netcats for client and server connections.
while true; do nc "$2" "$3" > "$srvpipe" < "$clipipe"; done &
TARGET_PID=$!
while true; do nc -l -p "$1" < "$srvpipe" > "$clipipe" ; done &
LISTENER_PID=$!

printf "\n%s\n" "Proxying port $1 to target $2:$3. Stop with Ctrl-C." 

# Cleanup after Ctrl-C.
trap 'kill $TARGET_PID ; kill $LISTENER_PID ; rm "$srvpipe" "$clipipe"' INT HUP ; read -r -d '' _ </dev/tty

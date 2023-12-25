#!/bin/sh
# ------------------------------------------------------------------------------
# Creates a simple persistent TCP proxy with netcat & named pipes.
#
# Usage: netcat-proxy.sh listenport targethost targetport
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------

if [ "$#" -lt 3 ]; then
  printf "\n%s\n" "Usage: $0 listenport targethost targetport" >&2
  printf "\n%s\n" "Creates a persistent proxy with netcat & named pipes." >&2
  exit 1
fi

if ! command -v nc > /dev/null 2>&1; then
  printf "\n%s\n" "This script requires nc (netcat)!" >&2
  exit 1
fi

if ! [ "$1" -ge 0 ] || ! [ "$1" -le 65535 ]; then
  printf "\n%s\n" "listenport not a valid TCP port between 0 and 65535" >&2
  exit 1
fi

if ! [ "$3" -ge 0 ] || ! [ "$3" -le 65535 ]; then
  printf "\n%s\n" "targetport not a valid TCP port between 0 and 65535" >&2
  exit 1                          
fi

# Make temporary named pipes.
srvpipe=$(mktemp -u)
mkfifo -m 600 "$srvpipe" || exit 1
clipipe=$(mktemp -u)
mkfifo -m 600 "$clipipe" || exit 1

# Launch two netcats for client and server connections.
while true; do nc "$2" "$3" > "$srvpipe" < "$clipipe" ; done &
TARGET_PID=$!
while true; do nc -l -p "$1" < "$srvpipe" > "$clipipe" ; done &
LISTENER_PID=$!
printf "\n%s\n" "Proxying port $1 to target $2:$3. Stop with Ctrl-C." 

# Cleanup after Ctrl-C.
trap 'kill $TARGET_PID ; kill $LISTENER_PID ; rm "$srvpipe" "$clipipe" ; exit' INT
trap 'exit' TERM
trap "kill 0" EXIT
while true; do sleep 1; done

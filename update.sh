#!/bin/bash
# -----------------------------------------------------------
# Updates Misc-Scripts already installed.
#
# Usage: [sudo] ./update.sh
#
# Run as root/sudo, copies scripts over the existing files 
# in /usr/local/bin and /usr/local/sbin, otherwise in the
# user's home directory ~/bin and ~/sbin.
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

if [ "$EUID" -eq 0 ]; then
  BIN=/usr/local/bin
  SBIN=/usr/local/sbin
else
  BIN="$HOME/bin"
  SBIN="$HOME/sbin"
fi

GITROOT="$(git rev-parse --show-toplevel)" || exit 1
printf "Updating scripts in directories %s & %s...\n\n" "$BIN" "$SBIN"

cd "$GITROOT/bin" || exit 1
for f in *; do
  if test -f "$BIN/$f"; then
    printf "Updating %s/%s...\n" "$BIN" "$f"
    cp "$GITROOT/bin/$f" "$BIN/$f"
  else
    printf "Skipping bin/%s...\n" "$f"
  fi
done

cd "$GITROOT/sbin" || exit 1
for f in *; do
  if test -f "$BIN/$f"; then
    printf "Updating %s/%s...\n" "$SBIN" "$f"
    cp "$GITROOT/sbin/$f" "$SBIN/$f"
  else
    printf "Skipping sbin/%s...\n" "$f"
  fi
done

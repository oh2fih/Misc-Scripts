#!/bin/bash
# ------------------------------------------------------------------------------
# Interactive installer & updater for Misc-Scripts.
#
# Usage: [sudo] ./install.sh
#
# Run as root/sudo, (un)installs & updates the scripts in /usr/local/bin and 
# /usr/local/sbin, otherwise in the user's home directory ~/bin and ~/sbin.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------

# Configuration.

WIDTH=80

# Checks and initialization.

if ! command -v whiptail &> /dev/null; then
  printf "\n%s\n\n" "This interactive installer requires whiptail!" >&2
  exit 1
fi

if [ "$EUID" -eq 0 ]; then
  BIN=/usr/local/bin
  SBIN=/usr/local/sbin
else
  BIN="$HOME/bin"
  SBIN="$HOME/sbin"
fi

GITROOT="$(git rev-parse --show-toplevel)" || exit 1

# Interactive menus.

MENULIST=()
MENUCOUNT=0

cd "$GITROOT/bin" || exit 1
for f in *; do
  ((MENUCOUNT++))
  if test -f "$BIN/$f"; then
    MENULIST+=("bin/$f" "" "ON")
  else
    MENULIST+=("bin/$f" "" "OFF")
  fi
done

HEIGHT=$((MENUCOUNT + 9))
TOINSTALL=$(
  whiptail --title "Misc-Script to install (1/2)" \
    --checklist --separate-output \
    "Choose the Misc-Scripts to be installed,\nbin => ${BIN}" \
    "$HEIGHT" "$WIDTH" "$MENUCOUNT" \
    "${MENULIST[@]}" 3>&1 1>&2 2>&3
  )
exitstatus=$?
if [ "$exitstatus" -ne 0 ]; then
  printf "Aborting...\n"
  exit "$exitstatus"
fi

TOINSTALL+=$'\n'

MENULIST=()
MENUCOUNT=0

cd "$GITROOT/sbin" || exit 1
for f in *; do
  ((MENUCOUNT++))
  if test -f "$SBIN/$f"; then
    MENULIST+=("sbin/$f" "" "ON")
  else
    MENULIST+=("sbin/$f" "" "OFF")
  fi
done

HEIGHT=$((MENUCOUNT + 9))
TOINSTALL+=$(
  whiptail --title "Misc-Script to install (2/2)" \
    --checklist --separate-output \
    "Choose the Misc-Scripts to be installed,\nsbin => ${SBIN}" \
    "$HEIGHT" "$WIDTH" "$MENUCOUNT" \
    "${MENULIST[@]}" 3>&1 1>&2 2>&3
  )
exitstatus=$?
if [ "$exitstatus" -ne 0 ]; then
  printf "Aborting...\n"
  exit "$exitstatus"
fi

# Install, update & uninstall.

cd "$GITROOT/bin" || exit 1
for f in *; do
  if grep -q -x "bin/$f" <<< "$TOINSTALL"; then
    if [[ ! -e "$BIN" ]]; then
      printf "Creating directory %s...\n" "$BIN"
      mkdir -p "$BIN"
    fi
    if test -f "$BIN/$f"; then
      printf "Updating %s/%s...\n" "$BIN" "$f"
    else
      printf "Installing %s/%s...\n" "$BIN" "$f"
    fi
    cp "$GITROOT/bin/$f" "$BIN/$f"
  else
    if test -f "$BIN/$f"; then
      printf "Removing %s/%s...\n" "$BIN" "$f"
      rm "$BIN/$f"
    fi
  fi
done

cd "$GITROOT/sbin" || exit 1
for f in *; do
  if grep -q -x "sbin/$f" <<< "$TOINSTALL"; then
    if [[ ! -e "$SBIN" ]]; then
      printf "Creating directory %s...\n" "$SBIN"
      mkdir -p "$SBIN"
    fi
    if test -f "$SBIN/$f"; then
      printf "Updating %s/%s...\n" "$SBIN" "$f"
    else
      printf "Installing %s/%s...\n" "$SBIN" "$f"
    fi
    cp "$GITROOT/sbin/$f" "$SBIN/$f"
  else
    if test -f "$SBIN/$f"; then
      printf "Removing %s/%s...\n" "$SBIN" "$f"
      rm "$SBIN/$f"
    fi
  fi
done

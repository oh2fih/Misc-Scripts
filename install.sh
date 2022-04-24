#!/bin/bash
# -----------------------------------------------------------
# Interactive installer & updater for Misc-Scripts.
#
# Usage: [sudo] ./install.sh
#
# Run as root/sudo, (un)installs & updates the scripts in
# /usr/local/bin and /usr/local/sbin, otherwise in the
# user's home directory ~/bin and ~/sbin.
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

WIDTH=80

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

BINMENULIST=()
BINMENUCOUNT=0

cd "$GITROOT/bin" || exit 1
for f in *; do
  ((BINMENUCOUNT++))
  if test -f "$BIN/$f"; then
    BINMENULIST+=("bin/$f" "" "ON")
  else
    BINMENULIST+=("bin/$f" "" "OFF")
  fi
done

HEIGHT=$((BINMENUCOUNT + 9))
TOINSTALL=$(
  whiptail --title "Misc-Script to install (1/2)" --checklist \
    --nocancel --separate-output \
    "Choose the Misc-Scripts to be installed,\nbin => ${BIN}" \
    "$HEIGHT" "$WIDTH" "$BINMENUCOUNT" \
    "${BINMENULIST[@]}" 3>&1 1>&2 2>&3
)

TOINSTALL+=$'\n'

SBINMENULIST=()
SBINMENUCOUNT=0

cd "$GITROOT/sbin" || exit 1
for f in *; do
  ((SBINMENUCOUNT++))
  if test -f "$SBIN/$f"; then
    SBINMENULIST+=("sbin/$f" "" "ON")
  else
    SBINMENULIST+=("sbin/$f" "" "OFF")
  fi
done

HEIGHT=$((SBINMENUCOUNT + 9))
TOINSTALL+=$(
  whiptail --title "Misc-Script to install (2/2)" --checklist \
    --nocancel --separate-output \
    "Choose the Misc-Scripts to be installed,\nsbin => ${SBIN}" \
    "$HEIGHT" "$WIDTH" "$SBINMENUCOUNT" \
    "${SBINMENULIST[@]}" 3>&1 1>&2 2>&3
)

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

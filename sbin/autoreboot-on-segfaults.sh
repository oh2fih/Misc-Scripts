#!/bin/sh
# ------------------------------------------------------------------------------
# Automatically reboots the system if there has been more than MAX_SEGFAULTS 
# segmentation faults on the current boot. This is only intended as a temporary 
# solution; one should really fix the software or the server instead!
#
# It is best to launch this using SystemD service & timer.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------

MAX_SEGFAULTS="${MAX_SEGFAULTS:-10}"
REBOOT_WAITING_TIME="${REBOOT_WAITING_TIME:-5}"

SHUTDOWN_SCHEDULED="/run/systemd/shutdown/scheduled"

### Check for sudo privileges and the requirements.

if ! [ "$(id -u)" = 0 ]; then
  echo "*** ERROR! This script requires sudo privileges."
  exit 126
fi

if ! command -v journalctl > /dev/null 2>&1; then
  echo "*** ERROR! This script requires journalctl!"
  exit 127
fi

if ! command -v shutdown > /dev/null 2>&1; then
  echo "*** ERROR! This script requires shutdown!"
  exit 127
fi

### Skip the checks if reboot is already scheduled.

if test -f "$SHUTDOWN_SCHEDULED"; then
  SHUTDOWN_DATE=$(
    date -d @"$(
      head -n 1 < "$SHUTDOWN_SCHEDULED" \
        | cut -c6-15
      )"
    )
  echo "Reboot/shutdown already scheduled at ${SHUTDOWN_DATE}."
  exit 3
fi

### Count segfaults & schedule a reboot.

SF_COUNT=$(
  journalctl -b -t "kernel" \
    | grep -c "segfault at"
  )

if [ "$SF_COUNT" -gt "$MAX_SEGFAULTS" ]; then
  echo "Detected ${SF_COUNT} segfaults (>${MAX_SEGFAULTS}); scheduling reboot."
  shutdown -r "$REBOOT_WAITING_TIME"
  exit 1
else
  echo "Detected ${SF_COUNT} segfaults (<=${MAX_SEGFAULTS}) on current boot."
fi

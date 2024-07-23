#!/bin/bash
read -r -d '' USAGE << EOM
# ------------------------------------------------------------------------------
# Find inactive (idle) SSH sessions or kill them
#
# Usage: find-inactive-ssh-sessions.sh [-k] [-i seconds] [-s] [-h]
#
#   -k   Kill the sessions; use pkill instead of pgrep.
#   -i   Maximum idle time in seconds; default to 28800 seconds (8 hours).
#   -s   Sessions. List all idle sessions (SSH or not) & PID of sshd process.
#        Format: user tty (age)[: PID]
#   -h   Help. Prints this and exits (ignoring all other options).
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------
EOM

MAX_IDLE=28800
KILL=0
SESSIONS=0

while getopts ":hksi:" opt; do
  case ${opt} in
    h)
      echo -e "$USAGE" >&2
      exit 1
      ;;
    k)
      KILL=1
      ;;
    s)
      SESSIONS=1
      ;;
    i)
      if [ -z "${OPTARG//[0-9]}" ]; then
        MAX_IDLE="$OPTARG"
      else
        echo "Invalid option: -i requires an integer value" >&2
        exit 1
      fi
      ;;
    \?)
      echo "Invalid option: $OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Invalid option: $OPTARG requires an argument" >&2
      exit 1
      ;;
  esac
done

if (( KILL == 1 )); then
  echo "Killing sshd processes idle more than $MAX_IDLE seconds." >&2
else
  if (( SESSIONS == 1 )); then
    echo "All sessions idle more than $MAX_IDLE seconds \
      & their sshd processes:" >&2
  else
    echo "sshd processes from sessions idle more than $MAX_IDLE seconds:" >&2
  fi
fi
echo "" >&2

# Get TTYs with the seconds since the last access time
TTY_AGES=$(
  who -s \
    | awk '{ print $2 }' \
    | grep -ve "^:" \
    | (cd /dev && xargs stat -c '%U %n %X') \
    | awk '{ print $1"\t"$2"\t"'"$(date +%s)"'-$3 }'
  )

# Get sshd processes of the TTYs; print or kill (-k)
while IFS= read -r line ; do
  user=$(echo "$line" | awk '{print $1}')
  tty=$(echo "$line" | awk '{print $2}')
  age=$(echo "$line" | awk '{print $3}')

  if (( age > MAX_IDLE )); then
    if (( SESSIONS == 1 )); then
      sshd=$(pgrep -f "sshd: ${user}@${tty}")
      if [[ "$sshd" != "" ]]; then
        echo "${user} ${tty} (${age}s): $sshd"
        sshd=""
      else
        echo "${user} ${tty} (${age}s)"
      fi
    fi

    if (( KILL == 1 )); then
      pkill -f "sshd: ${user}@${tty}"
    elif (( SESSIONS == 0 )); then
      pgrep -f -a "sshd: ${user}@${tty}"
    fi
  fi
done <<< "$TTY_AGES"

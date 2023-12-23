#!/bin/bash
# -----------------------------------------------------------
# Prepends (to stdin/stdout) strings given in as flags 
# -i, -I, -a, or -A; 
# after possible mbox 'From' & 'Return-Path' header lines.
#
# Procmail's formail mail (re)formatter is still a part of
# most distros and a dependency of, e.g., clamassassin.
# However, it can only append or replace header fields
# whereas such fields are better prepended similarly to the
# trace fields (RFC 5322, 3.6.7).
#
# This is intended as a limited formail replacement that
# ignores the nyanses of the flags and simply prepends the
# headers keeping the other headers as is. Any other flags
# are ignored.
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

# A possible Mbox format's From line MUST come before any added headers
read -r line
if [[ "$line" =~ ^From\ .*  ]]; then
  echo "$line"
  firstLine=""
else
  firstLine="$line"
fi

# Return-Path header conventionally (spamassassin) comes before other headers
read -r line
if [[ "$line" =~ ^Return-Path:\ .*  ]]; then
  echo "$line"
  secondLine=""
else
  secondLine="$line"
fi

# Prepend lines from flags
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -i|-I|-a|-A)
      nextArg="$2"
      while ! [[ "$nextArg" =~ ^-.* ]] && [[ $# -gt 1 ]]; do
        echo "$nextArg"
        if ! [[ "$2" =~ ^-.* ]]; then
          shift
          nextArg="$2"
        else
          shift
          break
        fi
      done
    ;;
  esac
  shift
done

# Rest of the stdin to stdout
if [[ "$firstLine" != "" ]]; then
  echo "$firstLine"
fi
if [[ "$secondLine" != "" ]]; then
  echo "$secondLine"
fi
cat <&0

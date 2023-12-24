#!/bin/bash
# -----------------------------------------------------------
# Prepends (to stdin/stdout) email header strings given in
# as flags -i, -I, -a, or -A;
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
# valid (RFC 5322, 2.2) non-empty headers keeping the other
# headers as is. 
#
# Clamassassin uses 'formail -c -x' to extract the original
# subject. Therefore, '-x' & '-X' are implemented, too.
#
# Any other flags are ignored.
#
# Author : Esa Jokinen (oh2fih)
# -----------------------------------------------------------

# Handling 'formail -x' & '-X'; ignoring '-c' as grep only gives a single line
headerNameRegex=$'^[\x21-\x39\x3B-\x7E]+:'
while getopts ":x:X:" opts; do
  case "${opts}" in
    x) # Extract the contents of this headerfield from the header.
      if [[ "$OPTARG" =~ $headerNameRegex ]]; then
        grep "${OPTARG}" <&0 | head -n 1 | sed "s/${OPTARG}//"
      fi
      exit
      ;;
    X) # Same as -x, but also preserves/includes the field name.
      if [[ "$OPTARG" =~ $headerNameRegex ]]; then
        grep "${OPTARG}" <&0 | head -n 1
      fi
      exit
      ;;
    *) # Ignoring anything else, as -i|-I|-a|-A are handled elsewhere.
      ;;
  esac
done

# A possible Mbox format's From line MUST come before any added headers
read -r line
if [[ "$line" =~ ^From\ .* ]]; then
  echo "$line"
  firstLine=""
else
  firstLine="$line"
fi

# Return-Path header conventionally (spamassassin) comes before other headers
read -r line
if [[ "$line" =~ ^Return-Path:\ .* ]]; then
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
        # Only prepend valid (RFC 5322, 2.2) non-empty email header fields
        headerRegex=$'^[\x21-\x39\x3B-\x7E]+:\ [\x20-\x7E]+'
        if [[ "$nextArg" =~ $headerRegex ]]; then
          echo "$nextArg"
        fi
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

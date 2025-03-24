#!/bin/bash
# ------------------------------------------------------------------------------
# Checks HTML element changes on a web page since last run
#
# Detects the content change by caching the sha512sum of a normalized HTML 
# element on a web page. If the contents were changed since the last run, exits 
# with a non-zero status code and prints out the current contents.
#
# Recommended to be executed as a SystemD service.
#
# Configured using environment variables:
#
#   $URL        URL of the web page to monitor.
#   $SELECTOR   One or more comma-separated selector.
#               Most CSS level 3 selectors are supported.
#   $CACHE      Cache file path (for multiple instances).
#   $USER_AGENT Fake User-Agent for curl; defaults to Google Chrome.
#
# If the element has a constantly changing part it can be found and replaced 
# using extra environment variables:
#
#   $MATCH      Pattern to find in sed extended regex format.
#   $REPLACE    Replacement in sed extended regex format.
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------

# Defaults to monitoring new updates on any of my repositories.

URL="${URL:-https://github.com/oh2fih?tab=repositories}"
SELECTOR="${SELECTOR:-#user-repositories-list}"
CACHE="${CACHE:-.detect-modifier-html-element-sha512sum}"

# Fake user-agent for curl

DEFAULT_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
DEFAULT_UA+="(KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"
UA="${USER_AGENT:-$DEFAULT_UA}"

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

required_command "hxselect" "; Please install html-xml-utils"
required_command "hxnormalize" "; Please install html-xml-utils"
required_command "curl" "for fetching the web page"
required_command "sha512sum" "for calculating the hashes"

if [ -z ${MATCH+x} ]; then
  required_command "sed"
fi

if [ "$UNMET" -gt 0 ]; then
  exit 1
fi

# Normalize the web page and get the monitored element

LASTCHECKSUM=$(cat "$CACHE")
ELEMENT=$(
  curl -A "$UA" -s "$URL" \
    | hxnormalize -x \
    | hxselect -c "$SELECTOR"
  )

# Calculate the checksum and compare it with the cache

if [ -z ${MATCH+x} ]; then
  CURRENTCHECKSUM=$(echo "$ELEMENT" | sha512sum)
else
  ESCAPED_MATCH=$(printf '%s\n' "$MATCH" | sed 's/\//\\\//g')
  ESCAPED_REPLACE=$(printf '%s\n' "$REPLACE" | sed 's/\//\\\//g')
  CURRENTCHECKSUM=$(
    echo "$ELEMENT" \
      | sed -E "s/${ESCAPED_MATCH}/${ESCAPED_REPLACE}/g" \
      | sha512sum
    )
fi

if [ "$CURRENTCHECKSUM" = "$LASTCHECKSUM" ]; then
  echo "No change in HTML element \"${SELECTOR}\" on \"${URL}\""
  exit 0
else
  echo "The HTML element \"${SELECTOR}\" on \"${URL}\" has changed to:"
  echo
  echo "$ELEMENT"

  echo "$CURRENTCHECKSUM" > "$CACHE"
  echo
  cat "$CACHE"
  exit 1
fi

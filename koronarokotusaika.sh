#!/bin/bash
# -----------------------------------------------------------
# Checks from app.koronarokotusaika.fi whether people your
# age (without a risk group) are yet eligible for Covid-19
# vaccination or not. Requires curl and jq.
#
# Usage: koronarokotusaika.sh Municipality YearOfBirth Dose
# -----------------------------------------------------------

# CONFIGURATION
CACHE_FILE=".koronarokotusaika-cache.json"
CACHE_MAX_SECONDS="600"
API_URL="https://api.koronarokotusaika.fi/api/options/municipalities/"

# Test the inputs...
if [ "$#" -ne 3 ]; then
  printf "\n%s\n\n" "Usage: $0 Municipality YearOfBirth Dose" >&2
  exit 1
fi

if [ -n "$2" ] && [ "$2" -eq "$2" ] 2>/dev/null; then
  MUNICIPALITY=$1
  BYEAR=$2
  AGE=$(($(date +"%Y")-BYEAR))
else
  printf "\n%s\n\n" "Year of birth should be a number!" >&2
  exit 1
fi

if [ -n "$3" ] && [ "$3" -eq "$3" ] 2>/dev/null; then
  DOSE=$3
else
  printf "\n%s\n\n" "Dose should be a number!" >&2
  exit 1
fi

if [ $AGE -gt 118 ]; then
  printf "\n%s" "I bet you are not turning $AGE this year! " >&2
  printf "%s\n\n" "That would beat even Kane Tanaka!" >&2
  exit 1
fi

# Tests for the requirements...
if ! command -v jq &> /dev/null; then
  printf "\n%s\n\n" "This script requires jq!" >&2
  exit 1
fi

if ! command -v curl &> /dev/null; then
  printf "\n%s\n\n" "This script requires curl!" >&2
  exit 1
fi

# Caching...
if [ -f "$CACHE_FILE" ]; then
  CACHE_TIME=$(stat --format=%Y "$CACHE_FILE")
else
  CACHE_TIME=0
fi

if [ $CACHE_TIME -le $(( $(date +%s) - CACHE_MAX_SECONDS )) ]; then
  printf "\n%s %s\n" "Downloading fresh data @ " "$(date -Iseconds)"
  curl -s "$API_URL" -o "$CACHE_FILE"
else
  printf "\n%s %s\n" "Using data cached @ " "$(date -Iseconds -d @$CACHE_TIME)"
fi

# Get the data for the municipality...
LABEL=$(jq -c '.[] | select(.label=="'"$MUNICIPALITY"'")' < "$CACHE_FILE")

if [ -z "$LABEL" ]; then
  MUNICIPALITIES=$(jq -c '.[] | .label' < "$CACHE_FILE")
  printf "\n%s\n" "Municipality \"""$MUNICIPALITY""\" not found! Try one of:" >&2
  printf "\n%s\n\n" "$MUNICIPALITIES" >&2
  exit 1
fi

# Check the non-risk groups based on the age...
ELIGIBLE_SINCE=$(
  printf "%s" "$LABEL" \
    | jq -c '.vaccinationGroups[]
      | select(.target[] | contains('$DOSE'))
      | select((.min<='$AGE')
        and (.max>='$AGE' or .max==null)
        and (.conditionTextKey==null)
        and (.startDate!=null))
      | "\(.startDate) (ages \(.min)-\(.max), source \(.source))"'
  )

if [ -z "$ELIGIBLE_SINCE" ]; then
  printf "\n%s" "Sorry, but people from $MUNICIPALITY "
  printf "%s" "born in $BYEAR (turning $AGE this year) "
  printf "%s\n\n" "are not yet eligible for #$DOSE Covid-19 vaccination! :("
  exit 0
else
  printf "\n%s" "Congratulations! People from $MUNICIPALITY "
  printf "%s" "born in $BYEAR (turning $AGE this year) "
  printf "%s" "have been eligible for #$DOSE Covid-19 vaccination since"
  printf "\n%s\n\n" "$ELIGIBLE_SINCE"
  exit 0
fi

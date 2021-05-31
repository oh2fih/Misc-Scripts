#!/bin/bash
# -----------------------------------------------------------
# Checks from app.koronarokotusaika.fi whether people your
# age (without a risk group) are yet eligible for Covid-19
# vaccination or not. Requires curl and jq.
#
# Usage: koronarokotusaika.sh Municipality YearOfBirth
# -----------------------------------------------------------

# CONFIGURATION
CACHE_FILE=".koronarokotusaika-cache.json"
CACHE_MAX_SECONDS="600"
API_URL="https://api.koronarokotusaika.fi/api/options/municipalities/"

# Test the inputs...
if [ "$#" -ne 2 ]; then
  echo -e "\nUsage: $0 Municipality YearOfBirth\n"
  exit 1
fi

if [ -n "$2" ] && [ "$2" -eq "$2" ] 2>/dev/null; then
  MUNICIPALITY=$1
  BYEAR=$2
  AGE=$(($(date +"%Y")-$BYEAR))
else
  echo -e "\nYear of birth should be a number!\n"
  exit 1
fi

# Tests for the requirements...
if ! command -v jq &> /dev/null; then
  echo -e "\nThis script requires jq!\n"
  exit 1
fi

if ! command -v curl &> /dev/null; then
  echo -e "\nThis script requires curl!\n"
  exit 1
fi

# Caching...
if [ -f "$CACHE_FILE" ]; then
  CACHE_TIME=$(stat --format=%Y "$CACHE_FILE")
else
  CACHE_TIME=0
fi

if [ $CACHE_TIME -le $(( `date +%s` - $CACHE_MAX_SECONDS )) ]; then 
  echo -e "\nDownloading fresh data @ "$(date -Iseconds)
  curl -s "$API_URL" -o "$CACHE_FILE"
else
  echo -e "\nUsing data cached @ "$(date -Iseconds -d @$CACHE_TIME)
fi

# Get the data for the municipality...
LABEL=$(cat "$CACHE_FILE" | jq -c '.[] | select(.label=="'"$MUNICIPALITY"'")' )

if [ -z "$LABEL" ]; then
  MUNICIPALITIES=$(cat "$CACHE_FILE"|jq -c '.[] | .label')
  echo -e "\nMunicipality "$MUNICIPALITY" not found! Try one of:\n\n$MUNICIPALITIES\n"
  exit 1
fi

# Check the non-risk groups based on the age...
ELIGIBLE_SINCE=$(echo "$LABEL" | jq -c '.vaccinationGroups[] | select((.min<='$AGE') and (.max>='$AGE' or .max==null) and (.conditionTextKey==null) and (.startDate!=null)) | "\(.startDate) (ages \(.min)-\(.max), source \(.source))"' )

if [ -z "$ELIGIBLE_SINCE" ]; then
  echo -e "\nSorry, but people from $MUNICIPALITY born in $BYEAR (turning $AGE this year) are not yet eligible for Covid-19 vaccination! :(\n"
  exit 0
else
  echo -e "\nCongratulations! People from $MUNICIPALITY born in $BYEAR (turning $AGE this year) have been eligible for Covid-19 vaccination since"
  echo -e "$ELIGIBLE_SINCE\n"
  exit 0
fi

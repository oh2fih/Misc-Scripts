#!/bin/bash
# ------------------------------------------------------------------------------
# Gets the current product price from a www.xxl.fi product page, compares it
# with a maximum price given and exits with error level 0 if the price is lower 
# than the maximum price.
#
# Usage: xxl-product-pricelimiter.sh ProductURL MaxPrice
#
# Author : Esa Jokinen (oh2fih)
# Home   : https://github.com/oh2fih/Misc-Scripts
# ------------------------------------------------------------------------------

# Test the inputs...
if [ "$#" -ne 2 ]; then
  printf "\n\e[33m%s\e[0m\n\n" "Usage: $0 XXL.fi-ProductURL MaxPrice" >&2
  exit 1
fi

if [[ "$2" =~ ^[+-]?[0-9]+[\.,]?[0-9]*$ ]] 2>/dev/null; then
  producturl="$1"
  maxprice=$(printf "%s" "$2"| sed 's/,/./g')
else
  printf "\n\e[31m%s\e[0m\n\n" "Max price should be a (float) number!" >&2
  exit 1
fi

# Validate the URL
regex='(https?)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
if [[ $producturl =~ $regex ]]; then

  # Download the page and get current price.
  productpage=$(curl --silent "$producturl")

  productname=$(
    printf "%s" "$productpage" \
      | grep "data\-product\-name" \
      | head -n 1 \
      | grep -o '".*"' \
      | sed 's/"//g'
    )

  productprice=$(
    printf "%s" "$productpage" \
      | grep "data\-product\-price" \
      | grep -o '".*"' \
      | sed -e 's/[^0-9,\.]*//g' \
      | sed 's/,/./g'
    )

  if [ -z "$productprice" ]; then
    printf "\n\e[31m%s\e[0m\n\n" "Unable to capture product price." >&2
    exit 1
  fi

  lower=$(printf "%s\n%s" "$productprice" "$maxprice" | sort -g | head -1)

  # Compare the prices.
  if [ "$lower" = "$productprice" ]; then
     printf "\n\e[32m%s\e[0m" "Good to buy! The price of "
     printf "\e[32m%s\e[0m\n\n" "\"$productname\" is now $productprice €"
     exit 0
  else
     printf "\n\e[33m%s\e[0m" "Please be patient! The price of " >&2
     printf "\e[33m%s\e[0m\n\n" "\"$productname\" is still $productprice €" >&2
     exit 1
  fi

else

  printf "\n\e[31m%s\e[0m\n\n" "The first argument was not a valid URL." >&2
  exit 1

fi

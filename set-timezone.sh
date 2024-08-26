#!/bin/bash

# List of patterns to search for
patterns=(
  "Africa/*" "America/*" "Antarctica/*" "Arctic/*" "Asia/*" "Atlantic/*"
  "Australia/*" "Brazil/*" "Canada/*" "Chile/*" "Cuba" "Egypt" "Eire"
  "Europe/*" "GB" "GB-Eire" "GMT" "GMT0" "GMT+0" "GMT-0" "Greenwich"
  "HST" "HongKong" "Iceland" "Indian/*" "Iran" "Israel" "Jamaica"
  "Japan" "Kwajalein" "Libya" "Mexico/*" "Navajo" "Pacific/*" "Poland"
  "Portugal" "Singapore" "Turkey" "UCT" "US/*" "UTC" "Zulu"
)

# Function to get a list of timezones
get_timezones() {
  local count=1
  for pattern in "${patterns[@]}"; do
    find /usr/share/zoneinfo -type f -path "/usr/share/zoneinfo/$pattern" | sed 's|/usr/share/zoneinfo/||' | awk -v cnt=$count '{print cnt". "$0; cnt++}'
  done
}

# Get timezones and display options
echo "Select a timezone from the list:"
PS3="Enter the number corresponding to your timezone choice: "
select timezone in $(get_timezones); do
  if [ -n "$timezone" ]; then
    break
  else
    echo "Invalid selection. Please try again."
  fi
done

# Set timezone
echo "Setting timezone to $timezone"
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime

# Verify timezone setting
echo "Timezone has been set to $(readlink -f /etc/localtime)"

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

# Function to list timezones
list_timezones() {
  for pattern in "${patterns[@]}"; do
    echo "Matching timezones for pattern: $pattern"
    find /usr/share/zoneinfo -type f -path "/usr/share/zoneinfo/$pattern" | sed 's|/usr/share/zoneinfo/||'
  done
}

# List timezones
list_timezones

# Prompt user for selection
echo -ne "\nEnter the number corresponding to your timezone choice: "
read -r choice

# Validate user input
timezone=$(find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||' | sed -n "${choice}p")
if [ -z "$timezone" ]; then
  echo "Invalid selection. Exiting."
  exit 1
fi

# Set timezone
echo "Setting timezone to $timezone"
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime

# Verify timezone setting
echo "Timezone has been set to $(readlink -f /etc/localtime)"


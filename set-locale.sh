#!/bin/bash

# Function to get a list of locales from /etc/locale.gen
get_locales() {
  cat /etc/locale.gen | awk '{print NR ". " $1}'
}

# Collect locales into an array
locales=($(get_locales))

# Check if locales were collected
if [ ${#locales[@]} -eq 0 ]; then
  echo "No locales found in /etc/locale.gen. Please add some locales and try again."
  exit 1
fi

# Constants
PAGE_SIZE=20

# Function to display a page of locales in a single line
display_page() {
  local start=$1
  local end=$2
  local line=""

  echo "Locales ($((start + 1)) to $end of ${#locales[@]}):"
  
  for ((i=start; i<end; i++)); do
    line+="${locales[$i]}    "  # Append each locale to the line with some spacing
  done
  
  echo "$line"
}

# Display pages of locales
total_locales=${#locales[@]}
current_page=0

while true; do
  start=$((current_page * PAGE_SIZE))
  end=$((start + PAGE_SIZE))
  if ((end > total_locales)); then
    end=$total_locales
  fi

  display_page $start $end

  # Prompt user for selection or continue
  echo -ne "Enter the number of your locale choice from this page, or press Enter to see more locales: "
  read -r choice

  # Check if user made a choice
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    if [[ "$choice" -ge 1 && "$choice" -le $total_locales ]]; then
      # Extract the selected locale
      selected_locale=$(echo "${locales[$((choice-1))]}" | awk '{print $2}')

      # Check if the selected locale is co

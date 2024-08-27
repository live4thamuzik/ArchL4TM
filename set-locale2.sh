#!/bin/bash

# Function to get a list of locales from /etc/locale.gen
get_locales() {
  cat /etc/locale.gen | awk '{print NR ". " $1 " (" ($1 ~ /^# / ? "commented" : "active") ")"}'
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

# Function to display a page of locales
display_page() {
  local start=$1
  local end=$2
  echo "Locales ($((start + 1)) to $end of ${#locales[@]}):"
  for ((i=start; i<end; i++)); do
    echo "${locales[$i]}"
  done
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

      # Check if the selected locale is commented
      if [[ "$selected_locale" == \#* ]]; then
        # Remove the leading '#' for uncommenting
        uncommented_locale=$(echo "$selected_locale" | sed 's/^# //')
        echo "Uncommenting locale: $uncommented_locale"
        sed -i "/^# $uncommented_locale/s/^# //" /etc/locale.gen
      else
        echo "Selected locale is already active."
      fi

      # Run locale-gen to apply the changes
      locale-gen

      # Set the locale in /etc/locale.conf
      echo "Setting locale to $selected_locale"
      echo "LANG=$selected_locale" > /etc/locale.conf

      # Verify locale setting
      echo "Locale has been set to $(cat /etc/locale.conf)"
      break
    else
      echo "Invalid selection. Please enter a valid number from the displayed list."
    fi
  elif [[ -z "$choice" ]]; then
    # Continue to the next page
    if ((end == total_locales)); then
      echo "No more locales to display."
      break
    fi
    current_page=$((current_page + 1))
  else
    echo "Invalid input. Please enter a number or press Enter to continue."
  fi
done

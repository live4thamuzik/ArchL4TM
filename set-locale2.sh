#!/bin/bash

# Function to get a list of locales from /etc/locale.gen
# Includes both commented and uncommented locales in the display
get_locales() {
  cat /etc/locale.gen | awk '{print NR ". " $1 " (" ($1 ~ /^# / ? "commented" : "active") ")"}'
}

# Collect locales into an array (including commented ones)
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

  # Check if we need to prompt for more locales or exit
  if ((end == total_locales)); then
    echo "No more locales to display."
    break
  fi
  echo -ne "Press Enter to see more locales or type 'exit' to finish: "
  read -r input
  if [[ "$input" == "exit" ]]; then
    echo "Exiting."
    exit 1
  fi

  current_page=$((current_page + 1))
done

# Prompt user for selection
echo -ne "Enter the number corresponding to your locale choice: "
read -r choice

# Validate user input
if [[ "$choice" -lt 1 || "$choice" -gt "$total_locales" ]]; then
  echo "Invalid selection. Exiting."
  exit 1
fi

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

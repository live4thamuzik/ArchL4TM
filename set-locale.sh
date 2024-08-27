#!/bin/bash

# Function to get a list of locales from /etc/locale.gen
get_locales() {
  awk '{print NR ". " $1}' /etc/locale.gen
}

# Collect locales into an array
locales=($(get_locales))

# Check if locales were collected
if [ ${#locales[@]} -eq 0 ]; then
  echo "No locales found in /etc/locale.gen. Please add some locales and try again."
  exit 1
fi

# Constants
PAGE_SIZE=40
COLS=4  # Number of columns to display
NUMBER_WIDTH=4  # Width for number and dot
COLUMN_WIDTH=28  # Width of each column for locales

# Function to display a page of locales in columns
display_page() {
  local start=$1
  local end=$2
  local count=0

  echo "Locales ($((start + 1)) to $end of ${#locales[@]}):"

  for ((i=start; i<end; i++)); do
    # Print locales in columns with minimized gap
    printf "%-${NUMBER_WIDTH}s%-${COLUMN_WIDTH}s" "${locales[$i]}" ""
    count=$((count + 1))
    
    if ((count % COLS == 0)); then
      echo
    fi
  done

  # Add a newline at the end if the last line isn't fully filled
  if ((count % COLS != 0)); then
    echo
  fi
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

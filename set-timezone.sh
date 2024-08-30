#!/bin/bash

# Function to get a list of timezones
get_timezones() {
  local count=1
  find /usr/share/zoneinfo -type f | sed 's|/usr/share/zoneinfo/||' | awk -v cnt=$count '{print cnt". "$0; cnt++}'
}

# Collect timezones into an array
mapfile -t timezones < <(get_timezones)

# Check if timezones were collected
if [ ${#timezones[@]} -eq 0 ]; then
  echo "No timezones found. Please check the timezone directory and try again."
  exit 1
fi

# Constants
PAGE_SIZE=80
COLS=2  # Number of columns to display
NUMBER_WIDTH=4  # Width for number and dot
COLUMN_WIDTH=2  # Width of each column for timezones

# Function to display a page of timezones in columns
display_page() {
  local start=$1
  local end=$2
  local count=0

  echo "Timezones ($((start + 1)) to $end of ${#timezones[@]}):"

  for ((i=start; i<end; i++)); do
    # Print timezones in columns with minimized gap
    printf "%-${NUMBER_WIDTH}s%-${COLUMN_WIDTH}s" "${timezones[$i]}" ""
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

# Display pages of timezones
total_timezones=${#timezones[@]}
current_page=0

while true; do
  start=$((current_page * PAGE_SIZE))
  end=$((start + PAGE_SIZE))
  if ((end > total_timezones)); then
    end=$total_timezones
  fi

  display_page $start $end

  # Prompt user for selection or continue
  echo -ne "Enter the number of your timezone choice from this page, or press Enter to see more timezones: "
  read -r choice

  # Check if user made a choice
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    if [[ "$choice" -ge 1 && "$choice" -le $total_timezones ]]; then
      # Extract the selected timezone
      selected_timezone=$(echo "${timezones[$((choice-1))]}" | awk '{print $2}')

      # Set timezone
      echo "Setting timezone to $selected_timezone"
      ln -sf "/usr/share/zoneinfo/$selected_timezone" /etc/localtime

      # Verify timezone setting
      echo "Timezone has been set to $(readlink -f /etc/localtime)"
      break
    else
      echo "Invalid selection. Please enter a valid number from the displayed list."
    fi
  elif [[ -z "$choice" ]]; then
    # Continue to the next page
    if ((end == total_timezones)); then
      echo "No more timezones to display."
      break
    fi
    current_page=$((current_page + 1))
  else
    echo "Invalid input. Please enter a number or press Enter to continue."
  fi
done


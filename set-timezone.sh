#!/bin/bash

# List of patterns to search for
patterns=(
  "America/*"
)

# Function to get a list of timezones
get_timezones() {
  local count=1
  for pattern in "${patterns[@]}"; do
    find /usr/share/zoneinfo -type f -path "/usr/share/zoneinfo/$pattern" | sed 's|/usr/share/zoneinfo/||' | awk -v cnt=$count '{print cnt". "$0; cnt++}'
  done
}

# Collect timezones into an array
mapfile -t timezones < <(get_timezones)

# Determine the number of columns based on terminal width
columns=$(tput cols)
col_width=30
num_cols=$((columns / col_width))

# Format and display timezones in columns
echo "Select a timezone from the list:"
for ((i=0; i<${#timezones[@]}; i++)); do
  index=$((i % num_cols))
  printf "%-${col_width}s" "${timezones[$i]}"
  if (( (i + 1) % num_cols == 0 )); then
    echo
  fi
done
echo

# Prompt user for selection
echo -ne "Enter the number corresponding to your timezone choice: "
read -r choice

# Validate user input
if [[ "$choice" -lt 1 || "$choice" -gt "${#timezones[@]}" ]]; then
  echo "Invalid selection. Exiting."
  exit 1
fi

# Extract timezone based on user choice
selected_timezone=$(echo "${timezones[$((choice-1))]}" | sed 's/^[0-9]*\. //')

# Set timezone
echo "Setting timezone to $selected_timezone"
ln -sf "/usr/share/zoneinfo/$selected_timezone" /etc/localtime

# Verify timezone setting
echo "Timezone has been set to $(readlink -f /etc/localtime)"

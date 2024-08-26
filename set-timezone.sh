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

# Display timezones with options
echo "Select a timezone from the list:"
for timezone in "${timezones[@]}"; do
  echo "$timezone"
done

# Prompt user for selection
echo -ne "\nEnter the number corresponding to your timezone choice: "
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

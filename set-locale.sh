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

# Determine the number of columns based on terminal width
columns=$(tput cols)
col_width=40
num_cols=$((columns / col_width))

# Format and display locales in columns
echo "Select a locale from the list (only active locales can be selected):"
for ((i=0; i<${#locales[@]}; i++)); do
  printf "%-${col_width}s" "${locales[$i]}"
  if (( (i + 1) % num_cols == 0 )); then
    echo
  fi
done
echo

# Prompt user for selection
echo -ne "Enter the number corresponding to your locale choice: "
read -r choice

# Validate user input
if [[ "$choice" -lt 1 || "$choice" -gt "${#locales[@]}" ]]; then
  echo "Invalid selection. Exiting."
  exit 1
fi

# Extract the selected locale
selected_locale=$(echo "${locales[$((choice-1))]}" | awk '{print $2}')

# Check if the selected locale is commented
if [[ "$selected_locale" == \#* ]]; then
  echo "Selected locale is commented out. Please select an active locale."
  exit 1
fi

# Uncomment the selected locale in /etc/locale.gen
echo "Uncommenting locale: $selected_locale"
sed -i "/^# $selected_locale/s/^# //" /etc/locale.gen

# Run locale-gen to apply the changes
locale-gen

# Set the locale in /etc/locale.conf
echo "Setting locale to $selected_locale"
echo "LANG=$selected_locale" > /etc/locale.conf

# Verify locale setting
echo "Locale has been set to $(cat /etc/locale.conf)"

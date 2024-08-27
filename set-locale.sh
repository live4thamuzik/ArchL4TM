#!/bin/bash

# Function to get a list of available locales from /etc/locale.gen
get_locales() {
  cat /etc/locale.gen | awk '/^[^#]/ {print NR ". " $1}'
}

# Collect locales into an array
mapfile -t locales < <(get_locales)

# Check if locales were collected
if [ ${#locales[@]} -eq 0 ]; then
  echo "No uncommented locales found in /etc/locale.gen. Please uncomment some locales and try again."
  exit 1
fi

# Determine the number of columns based on terminal width
columns=$(tput cols)
col_width=30
num_cols=$((columns / col_width))

# Format and display locales in columns
echo "Select a locale from the list:"
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

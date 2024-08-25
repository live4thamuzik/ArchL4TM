#!/bin/bash

# Display available locales from /etc/locale.gen
echo "Available locales from /etc/locale.gen:"
grep -v '^#' /etc/locale.gen | awk '{print NR ": " $1}'

# Prompt user to select a locale
echo -ne "\nEnter the number corresponding to your locale choice: "
read -r choice

# Validate user input
locale=$(grep -v '^#' /etc/locale.gen | awk '{print $1}' | sed -n "${choice}p")
if [ -z "$locale" ]; then
  echo "Invalid selection. Exiting."
  exit 1
fi

# Uncomment the selected locale in /etc/locale.gen
echo "Uncommenting locale: $locale"
sed -i "/^# $locale/s/^# //" /etc/locale.gen

# Run locale-gen to apply the changes
locale-gen

# Set the locale in /etc/locale.conf
echo "Setting locale to $locale"
echo "LANG=$locale" > /etc/locale.conf

# Verify locale setting
echo "Locale has been set to $(cat /etc/locale.conf)"


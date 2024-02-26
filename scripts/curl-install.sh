#!/bin/bash

# Checking if is running in Repo Folder
if [[ "$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')" =~ ^scripts$ ]]; then
    echo "You are running this in ArchL4TM Folder."
    echo "Please use ./archl4tm.sh instead"
    exit
fi

# Installing git

echo "Installing git."
pacman -Sy --noconfirm --needed git glibc

echo "Cloning the ArchL4TM Project"
git clone https://github.com/live4thamuzik/ArchL4TM

echo "Executing ArchL4TM Script"

cd $HOME/ArchL4TM

exec ./archl4tm.sh
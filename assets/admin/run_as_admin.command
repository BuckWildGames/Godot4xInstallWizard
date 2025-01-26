#!/bin/bash
# Get the path to the installer from the argument
INSTALLER_PATH=$1

# Check if we are running as root (admin on macOS)
if [ "$(id -u)" -eq 0 ]; then
  echo "Already running as admin."
else
  echo "Relaunching as admin..."
  sudo "$INSTALLER_PATH"
fi

#!/bin/env bash

# Stops execution in case of error
set -e

# Load environment variables from variables file on current script directory
source "$(dirname "$0")/variables"

# Create log folder if it doesn't exist
if [ ! -d $LOG_FOLDER ]; then
  mkdir -p $LOG_FOLDER
fi

# Set command to the first argument, or to "help" if no argument is provided
COMMAND=${1:-help}

# Repository key file
KEY_FILE=$(whoami)-$(hostname).key

# If command is init
if [ "$COMMAND" = "init" ]; then
  # Initialize the repository
  echo -n "1. Inicializando repositório..."
  borg init --encryption=repokey $BORG_REPO >> $LOG_FILE 2>&1
  echo " done."

  echo -ne "2. Exportando chave..."
  borg key export $BORG_REPO > $KEY_FILE
  echo " done."

  echo
  echo -e "============================"
  echo 
  echo "Atenção: Salve em local seguro tanto a passphrase quanto o arquivo $KEY_FILE"
  echo
  echo "============================"

  exit 0
fi

# If command is check
if [ "$COMMAND" = "check" ]; then
  # Check the repository
  borg check $BORG_REPO >> $LOG_FILE 2>&1
  exit 0
fi

# If command is prune
if [ "$COMMAND" = "prune" ]; then
  # Prune the repository
  borg prune --list $BORG_PRUNE_OPTIONS $BORG_REPO >> $LOG_FILE 2>&1
  exit 0
fi
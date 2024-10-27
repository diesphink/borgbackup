#!/usr/bin/env bash

# Stops execution in case of error
set -e

# Load environment variables from variables file on current script directory
source "$(dirname "$0")/variables"

# Create log folder if it doesn't exist
if [ ! -d $LOG_FOLDER ]; then
  mkdir -p $LOG_FOLDER
fi

# Run the backup
borg create \
  --filter "AME" \
  --list \
  --stats \
  --verbose \
  --exclude-caches \
  --patterns-from patterns \
  ::$BORG_ARCHIVE_NAME \
  $BORG_SOURCE_PATH 2>&1 | tee -a $LOG_FILE

# Prune the repository
borg prune --list $BORG_PRUNE_OPTIONS $BORG_REPO 2>&1 | tee -a $LOG_FILE
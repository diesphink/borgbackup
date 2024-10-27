#!/bin/sh

# Stops execution in case of error
set -e

# Load environment variables from variables file on current script directory
source "$(dirname "$0")/variables"

# Create mount point if it doesn't exist
if [ ! -d $BORG_MOUNTPOINT ]; then
  mkdir -p $BORG_MOUNTPOINT
fi

# Unmount the repository
function umount() {
  echo -n "2. Desmontando repositório..."
  borg umount $BORG_MOUNTPOINT
  echo " done."
}

# In case of error, or user cancel, unmount the repository
trap umount ERR INT

echo -n "1. Montando repositório..."
borg mount $BORG_REPO $BORG_MOUNTPOINT
echo " done."

xdg-open $BORG_MOUNTPOINT

echo "Os arquivos estão montados em $BORG_MOUNTPOINT"
echo "Quando encerrar, pressione Enter para desmontar o repositório."
echo 
read -r answer
umount


#!/usr/bin/env bash

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
  borg init --encryption=repokey $BORG_REPO 2>&1 | tee -a $LOG_FILE
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
  borg check $BORG_REPO 2>&1 | tee -a $LOG_FILE
  exit 0
fi

# If command is prune
if [ "$COMMAND" = "prune" ]; then
  # Prune the repository
  borg prune --list $BORG_PRUNE_OPTIONS $BORG_REPO 2>&1 | tee -a $LOG_FILE
  exit 0
fi

# If command is install
if [ "$COMMAND" = "install" ]; then
  # Prune the repository
  echo -n "1. Copiando arquivos de serviço..."
  SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
  
  cat > /etc/systemd/system/borg-backup.service <<EOF
[Unit]
Description=Automated Borg Backup (Service)

[Service]
User = $(stat -c '%U' ${SCRIPT_DIR})
ExecStart = ${SCRIPT_DIR}/backup.sh
Type=oneshot
EOF
  
  cat > /etc/systemd/system/borg-backup.timer <<EOF
[Unit]
Description=Automated Borg Backup (Timer)

[Timer]
OnCalendar=02:30
Persistent=true
Unit=borg-backup.service

[Install]
WantedBy=timers.target
EOF

  echo " done."

  echo -n "2. Recarregando serviços..."
  sudo systemctl daemon-reload
  echo " done."

  echo -n "3. Habilitando timer..."
  sudo systemctl enable --now borg-backup.timer
  echo " done."

  exit 0
fi

# If all else, show help
echo "Uso: $0 [init|check|prune|install]"
echo
echo "  init    Inicializa o repositório"
echo "  check   Verifica a integridade do repositório"
echo "  prune   Remove backups antigos"
echo "  install Instala o serviço de backup com timer para 2h30"
echo
echo "Sem argumentos, exibe esta mensagem de ajuda."
echo
echo "Para mais informações, consulte o README.md"
echo


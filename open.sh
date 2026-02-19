#!/bin/bash

function echo_red() {
    tput setaf 1; echo $*; tput sgr0
}

function echo_green() {
    tput setaf 10; echo $*; tput sgr0
}

function echo_ot() {
    tput setaf 4; echo $*; tput sgr0
}


function sucesso() {
    echo_green -e "\u2714"
}

function falha() {
    echo_red "✖ $*"
    echo
}

function confirm() {
    gum confirm "$*" \
    --default=true \
    --affirmative "Sim" \
    --negative "Não"
}

source variables

export USERS=$(ssh -p 22789 192.168.15.2 ls "/volume1/borg/"  2> /dev/null)
export USER=$(gum choose --header "Escolha o usuário" --selected="$USER" $USERS)
if [[ -z $USER ]]; then exit 1; fi

export HOSTS=$(ssh -p 22789 192.168.15.2 ls "/volume1/borg/${USER}" 2> /dev/null)
export HOSTNAME=$(gum choose --header "Escolha o host" --selected="$HOSTNAME" $HOSTS)
if [[ -z $HOSTNAME ]]; then exit 1; fi

export BORG_PASSPHRASE=$(gum input --value "${BORG_PASSPHRASE}" --header "Informe a senha para backups de ${USER}@${HOSTNAME}" --placeholder "Senha")
if [[ -z $BORG_PASSPHRASE ]]; then exit 1; fi

export BORG_REPO="ssh://$(whoami)@192.168.15.2:22789/volume1/borg/${USER}/${HOSTNAME}"

export ARCHIVES=$(borg list --format '{archive}{NL}' 2> /dev/null | sort -r)
export ARCHIVE=$(gum choose --header "Escolha o arquivo" $ARCHIVES)
if [[ -z $ARCHIVE ]]; then exit 1; fi

export BORG_MOUNTPOINT=$(gum input --value "${BORG_MOUNTPOINT}" --header "Informe o diretório para montar o backup" )
if [[ -z $BORG_MOUNTPOINT ]]; then exit 1; fi

if [ ! -d $BORG_MOUNTPOINT ]; then
  mkdir -p $BORG_MOUNTPOINT
fi

function umount() {
  echo -n "  - Desmontando repositório... "
  borg umount $BORG_MOUNTPOINT
  sucesso
}

# In case of error, or user cancel, unmount the repository
trap umount ERR INT

echo $BORG_REPO
echo -n "  - Montando repositório... "
borg mount "${BORG_REPO}::${ARCHIVE}" "$BORG_MOUNTPOINT" 2> /dev/null
sucesso

echo "Os arquivos estão montados em $BORG_MOUNTPOINT"

confirm "Gostaria de abrir o diretório no navegador de arquivos?" \
&& xdg-open "$BORG_MOUNTPOINT"

confirm "Desmontar e encerrar?" && umount


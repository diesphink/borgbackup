#!/bin/bash

MARVIN=192.168.15.2
VARIABLES_FILE=variables

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

function checando() {
    echo -n "  - Checando "
    echo -n $*
    echo -n "... "
}

function confirm() {
    gum confirm "$*" \
    --default=false \
    --affirmative "Sim" \
    --negative "Não"
}

function install_command() {
    if command -v apt *> /dev/null
    then
        echo sudo apt install $*
    else
        echo sudo pacman -S $*
    fi
}

checando dependências do script - gum
if ! command -v gum *>/dev/null
then
    falha gum não encontrado
    echo -n "Instale com "
    echo_green $(install_command gum)
    exit 1
else
    sucesso
fi

checando dependências do script - hostname
if ! command -v hostname *> /dev/null;then
    falha hostname não encontrado
    confirm Instalar inetutils? \
    && $(install_command inetutils) || exit 1
    exit 1
else
    sucesso
fi

checando "acesso ao Marvin via IP local ($MARVIN)"
if ping -c 1 $MARVIN &> /dev/null
then
  sucesso
else
  falha Não é possível continuar sem acesso ao Marvin
  exit 1
fi

checando se é possível acessar o servidor apenas com chaves
if ssh -q -o BatchMode=yes -o ConnectTimeout=5 $MARVIN -p 22789 true
then
    sucesso
else
    falha Não foi possível conectar
    confirm "Deseja copiar certificado via ssh-copy-id?" \
    && ssh-copy-id -p 22789 $MARVIN || exit 1
fi

checando arquivo variables
if [[ -e "variables" ]]; then
    sucesso
else
    falha "Arquivo ausente"
    confirm "deseja copiar de variables.sample?" \
    && cp variables.sample variables || exit 1
fi

echo -n "  - Carregando variáveis... "
source variables
sucesso

REPO=/volume1/borg/${USER}/${HOSTNAME}

checando se já existe ${REPO} no Marvin
if ssh -p 22789 "$MARVIN" "test -d \"${REPO}\"" 2> /dev/null; then
    echo_green Já existe
    INIT=false
else
    echo_red Não existe
    INIT=true
fi

checando variável USER
if [[ "$USER" == "$(whoami)" ]]; then
    sucesso
else
    falha Variável diferente de $(whoami)
    confirm Alterar no arquivo variables para $(whoami)? \
    && sed -i "s/export USER=\".*\"/export USER=\"$(whoami)\"/g" variables
    source variables
fi

checando variável BORG_PASSPHRASE
if [[ "$BORG_PASSPHRASE" == "CHANGE-ME" ]]; then
    falha Não definida
    if [[ "$INIT" == "true" ]]; then
        confirm Gerar uma nova senha aleatória? \
        && export PASSWORD="$(openssl rand -base64 20)" || exit 1
    else
        PASSWORD="$(gum input \
            --placeholder "Senha atual em ${REPO}" \
            --header "Repositório existente, informa a senha utilizada" \
            --password)"
        if [[ -z "$PASSWORD" ]]; then
            exit 1
        fi
    fi
    sed -i "s/CHANGE-ME/${PASSWORD}/g" variables
    source variables
else
    sucesso
fi

function init() {
    KEY_FILE=${USER}-${HOSTNAME}.key
    echo "  - Inicializando repositório..."
    borg init --encryption=repokey $BORG_REPO 2>&1 | tee -a $LOG_FILE

    echo " - Exportando chave..."
    borg key export $BORG_REPO > $KEY_FILE

    cat <<EOF | gum style --border double --margin "1 4" --padding "1 3" --foreground 210
Atenção

Salve am lugar seguro tanto a senha:

${BORG_PASSPHRASE}

...quanto o arquivo chave gerado ($KEY_FILE):

$(cat $KEY_FILE)
EOF

}

if [[ "$INIT" == "true" ]]; then
    confirm Inicializar o repositório ${REPO} via borg init? \
    && init || exit 1
fi

checando se acessa corretamente o repositório com as informações
if borg list > /dev/null 2>/dev/null; then
    sucesso
else
    falha Não foi possível listar o conteúdo do repositório
fi

echo "  - Próximos comandos exigem sudo para execução correta"
sudo echo 

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_USER=$( stat -c '%U' ${SCRIPT_DIR} )

function criar_servico() {
    echo -n "  - Criando o serviço... "
    cat <<EOF | sudo tee /etc/systemd/system/borg-backup.service > /dev/null
[Unit]
Description=Automated Borg Backup (Service)

[Service]
User = ${SCRIPT_USER}
ExecStart = ${SCRIPT_DIR}/backup.sh
Type=oneshot
EOF
    sucesso
    echo -n "  - Recarregando systemctl... "
    sudo systemctl daemon-reload
    sucesso
}

checando serviço borg-backup.service
if [[ -f "/etc/systemd/system/borg-backup.service" ]]; then
    sucesso
else
    falha Não encontrado
    confirm Deseja criar o serviço? \
    && criar_servico
fi

function criar_timer() {
    echo -n "  - Criando o timer... "
    cat <<EOF | sudo tee /etc/systemd/system/borg-backup.timer > /dev/null
[Unit]
Description=Automated Borg Backup (Timer)

[Timer]
OnCalendar=02:30
Persistent=true
Unit=borg-backup.service

[Install]
WantedBy=timers.target
EOF
    sucesso
    echo -n "  - Recarregando systemctl... "
    sudo systemctl daemon-reload
    sucesso
    echo -n "  - Habilitando o timer... "
    sudo systemctl enable borg-backup.timer > /dev/null
    sucesso
}


checando timer borg-backup.timer
if [[ -f "/etc/systemd/system/borg-backup.timer" ]]; then
    sucesso
else
    falha Não encontrado
    confirm Deseja criar o timer? \
    && criar_timer || exit 1 
fi

1. Copie o arquivo `variables.sample` para `variables` e ajuste a variável BORG_PASSPHRASE para uma senha única

2. Potencialmente, ajuste o arquivo `patterns` ou a variável `BORG_SOURCE_PATH` para ajustar do que será feito backup

3. Inicie um repositório com `./admin.sh init`

4. Faça os backups da chave e passphrase no bitwarden

5. Execute um backup (`./backup.sh`), veja se tudo funciona bem

6. Para recuperar seus backups, execute `./mount.sh`, isso irá montar todos os backups em um diretório mount

7. Instale os serviços para realizar o backup 2h30 automaticamente com `./admin.sh install`
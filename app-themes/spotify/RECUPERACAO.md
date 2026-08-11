# Quando o Spotify atualizar (e ele vai)

Escrito em 10/08/2026, no dia em que o Spotify passou a ser tematizado pelo
**spicetify** em vez do patch próprio do MeowSystem.

## O sintoma

Um dia você abre o Spotify e ele está **cinza de fábrica** — ou, no caso feio,
**a janela abre em branco** e nada carrega.

## Por que acontece

O Spotify do Flathub é um pacote `extra-data`: o flatpak baixa o `spotify.snap`
oficial e desempacota o app num diretório com o nome do commit. Quando sai
versão nova, ele escreve um diretório NOVO e reaponta o symlink `active`. Tudo
que o spicetify tinha patchado ficou no diretório velho. O tema não foi
"desfeito" — ele ficou para trás.

Frequência medida no Flathub: cerca de **um bump de payload por mês**
(1.2.89.539 em 22/05/2026, 1.2.92.147 em 15/06/2026).

A **janela em branco** é outra coisa, e é o preço de ter escolhido o spicetify:
ele patcha **JavaScript**, não só CSS. Uma versão nova do Spotify pode ser
incompatível com a versão atual do spicetify, e aí não há conserto local — só
esperar. Se depois de tentar tudo abaixo continuar em branco, a resposta honesta
é: **volte o Spotify ao normal** (seção "A saída limpa") e espere a atualização
do spicetify.

## O que o MeowSystem faz sozinho, e o que ele se recusa a fazer

O `meow doctor` das 05:00 confere o Spotify, e a conferência olha **o disco**
(`Apps/xpui/colors.css`), não só a intenção gravada no `config-xpui.ini` — então
uma atualização que apagou o tema **é acusada**, não passa batido.

Mas o `meow apps aplicar` **para** quando percebe que a versão do backup do
spicetify é diferente da versão do Spotify instalado:

```
!! o Spotify atualizou (1.2.92.147.g5b8f9367 -> 1.2.9X.…) e o backup do spicetify é da versão velha
>> não conserto sozinho: leia app-themes/spotify/RECUPERACAO.md e rode na mão
```

Isso é de propósito. O conserto oficial tem um passo (`restore`) que, rodado com
um backup de outra versão, **copia a interface velha por cima do app novo** — e
o resultado é janela em branco **sem nenhuma mensagem de erro**. Não é o tipo de
coisa que pode acontecer às cinco da manhã sem ninguém olhando.

## O conserto, na ordem

Feche o Spotify antes de qualquer coisa. Confira:

```sh
flatpak ps --columns=application | grep -qx com.spotify.Client && echo ABERTO || echo fechado
```

O binário do spicetify **não está no PATH** (para não sujar o `~/.config/zsh/.zshrc`,
que é um repositório git) — chame pelo caminho completo:

```sh
SP=~/.spicetify/spicetify
```

### 1. O caso comum: o tema sumiu, o app abre normal

```sh
$SP backup apply
```

É o passo 1 do procedimento oficial. Como o app no disco está de fábrica (a
atualização acabou de reescrevê-lo), o `backup` fotografa o de fábrica **da
versão nova** — que é exatamente o que queremos — e o `apply` patcha por cima.

Se ele reclamar que já existe um backup (da versão velha):

```sh
$SP restore     # limpa o backup velho; com o app JÁ de fábrica isto é inofensivo
$SP backup apply
```

Depois, confira sem abrir o app:

```sh
grep -o -- '--spice-text: *#[0-9a-fA-F]*' \
  ~/.local/share/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify/Apps/xpui/colors.css
# esperado: --spice-text: #cba6f7   (mauve do mocha)
meow apps conferir
```

### 2. Se o tema aplicou mas a janela abre em branco

O spicetify está desatualizado para a versão nova do Spotify:

```sh
$SP upgrade          # `upgrade` e `update` são ALIAS do mesmo verbo — conferido
                     #  no `spicetify --help` da v2.44.0, linha 110:
                     #  "upgrade|update  Update spicetify to the latest version".
                     #  Quem faz hot-reload de tema é `refresh` (linha 14).
$SP backup apply
```

Se não houver versão nova do spicetify, **a equipe ainda está trabalhando na
compatibilidade**. Não há conserto local. Vá para a saída limpa.

### 3. A saída limpa — devolver o Spotify ao normal e esperar

```sh
$SP restore
```

Se o `restore` recusar ou o app continuar quebrado, o caminho que **sempre**
funciona:

```sh
flatpak install --user --reinstall flathub com.spotify.Client
```

Baixa uns 130 MB e reescreve `files/extra` de fábrica. **Preserva login e
preferências** (`~/.var/app/com.spotify.Client`) — não use `--delete-data`.
Depois, para voltar ao tema: `meow apps aplicar spotify`.

## Onde está o original de fábrica

O `xpui.spa` **de fábrica** da versão 1.2.92.147 (commit `abf9251b…`) está
guardado em quatro lugares, todos com o mesmo
sha256 `5ec1901f0b1988a7d1188127b5aa76ae25e15acec887dc664f286fb774006dfe`
(11168399 bytes):

| Onde | Quem cuida |
|---|---|
| `~/.local/state/spicetify/Backup/xpui.spa` | o spicetify (é o que o `restore` usa) |
| `~/.local/state/meowsystem/backups/spotify-xpui-fabrica/xpui.spa` | o MeowSystem |
| `~/Backups/spotify-fabrica-abf9251b/` | ninguém — é justamente o ponto |
| `/mnt/Apate/backup-spotify-fabrica-abf9251b/` | ninguém, e em **outro disco** |

Os dois últimos levam também o `login.spa`
(`3aecd287c9fe8bda026e68f861bf3bff98385f6fe1fe2f43963a84c05b3b40e5`), que o
spicetify passa a reescrever por causa do `overwrite_assets 1` e que o módulo
antigo do Meow nunca tocou — portanto nunca guardou.

**Um `.spa` só serve para a versão de onde veio.** Copiar o de 1.2.92 por cima
de uma instalação mais nova dá janela em branco. Depois que o Spotify atualizar,
esses arquivos viram peça de museu: a volta passa a ser reinstalar o flatpak.

Para saber se um `.spa` é de fábrica sem abrir nada:

```sh
python3 app-themes/spotify/xpui.py estado <arquivo.spa> --paleta palette/catppuccin.json
# de fábrica: bloco_sha vazio, verdes_originais=150
```

## A emergência de verdade: o `xpui.spa` sumiu do `Apps/`

Não sumiu. Depois de `spicetify apply` o `Apps/xpui.spa` vira um **diretório**
`Apps/xpui/`, e o `login.spa` vira `Apps/login/`. O Spotify carrega os dois
formatos. Qualquer script (ou pessoa) que procure `Apps/xpui.spa` vai concluir
que o Spotify não está instalado — foi o que aconteceu com a versão antiga
deste módulo, e é por isso que o `meow_app_detectar` de hoje aceita os dois.

Para pôr o `.spa` de volta manualmente, com o Spotify fechado:

```sh
APPS=~/.local/share/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify/Apps
rm -rf "$APPS/xpui" "$APPS/login"
cp -a ~/Backups/spotify-fabrica-abf9251b/xpui.spa  "$APPS/"
cp -a ~/Backups/spotify-fabrica-abf9251b/login.spa "$APPS/"
```

Isto **só vale enquanto o Spotify for a 1.2.92.147**. Confira antes:

```sh
flatpak list --app --columns=application,version | grep spotify
```

## O acento

O acento (`ACCENT` do `meow.conf`) **não** é aplicado pelo dropdown do Spotify
nesta máquina — o `app-themes/spotify/acento.py` escreve o hex nas chaves `text`
e `button-active` do `color.ini` do tema, e o `spicetify apply` leva isso para o
`colors.css` do app. Ou seja: **trocar o acento é `meow tema`, não um clique**.

O dropdown "Catppuccin → Choose an accent color" dentro do Spotify continua
existindo e continua ganhando de nós enquanto ela o usar, porque ele escreve
`style` inline no `<html>`. Se algum dia a interface aparecer com um acento que
não é o do `meow.conf`, é isso: a escolha está no localStorage do Spotify
(`catppuccin-accentColor`). Escolher `none` no dropdown devolve o comando ao
`meow.conf`.

## Se o tema Catppuccin for atualizado

O tema mora em `~/.config/spicetify/Themes/catppuccin` e é uma **cópia** do
`catppuccin/spicetify` no commit anotado em `PROCEDENCIA.txt` (hoje `1ec645c4`).
Se você trocar essa cópia por uma nova, o `color.ini` volta ao acento de fábrica
do tema — e o `meow doctor` vai acusar divergência no ciclo seguinte e
reescrever o acento sozinho. Não há nada a fazer na mão.

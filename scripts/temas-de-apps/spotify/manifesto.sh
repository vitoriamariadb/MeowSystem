#!/usr/bin/env bash
# scripts/temas-de-apps/spotify/manifesto.sh — Catppuccin dentro do Spotify, VIA SPICETIFY.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Sem `exit`, sem `set -e`.
#
# ─────────────────────────────────────────────────────────────────────────────
# 0. A DECISÃO MUDOU EM 10/08/2026 — E POR QUÊ
# ─────────────────────────────────────────────────────────────────────────────
#   Até esta data o módulo patchava o `Apps/xpui.spa` com as próprias mãos
#   (`xpui.py`), e o cabeçalho antigo argumentava, com razão, que instalar o
#   spicetify só poria uma SEGUNDA mão no MESMO arquivo. O argumento continua
#   correto. O que mudou foi a escolha: ela pediu o spicetify.
#
#   Então a regra passa a ser a única que evita a briga de verdade: NÃO EXISTEM
#   DUAS MÃOS. O spicetify é quem escreve no Spotify; o MeowSystem é quem decide
#   o que ele escreve. O `meow.conf` continua sendo a fonte de verdade do gosto
#   dela (FLAVOR, ACCENT); o spicetify é o braço.
#
#   A alternativa — desligar este módulo com uma chave no meow.conf e declarar o
#   Spotify "território do spicetify" — foi recusada por um motivo prático: o
#   `meow doctor` das 05:00 deixaria de conferir o Spotify, e o dia em que uma
#   atualização do app apagasse o tema ninguém avisaria. Delegar mantém o doctor
#   olhando; só troca o que ele mede.
#
#   RESSALVA HONESTA, ACRESCENTADA NO MESMO DIA: a frase "não existem duas mãos"
#   descreve o DESENHO, não o disco. Existe uma terceira mão dormindo desde
#   20/03/2026, no repo do Ritual da Aurora:
#     ~/.config/zsh/functions/spicetify.zsh   (spicetify_status/_reparar/_instalar)
#     ~/.config/zsh/scripts/spicetify-setup.sh
#   Ela estava inerte porque o binário não existia — e INSTALAR O SPICETIFY A
#   LIGOU. Pior: as duas faziam `restore || true` seguido de `clear` e `backup
#   apply`. O `|| true` engolia a falha do restore, e o restore falha justamente
#   depois de o Spotify atualizar, que é quando alguém digita "reparar": o
#   `clear` apagaria o backup de fábrica e o `backup` fotografaria o arquivo já
#   tematizado como vanilla — exatamente o desastre que todo o procedimento do
#   item 5 foi desenhado para evitar.
#   Os dois foram travados em 10/08/2026: agora param no primeiro erro do
#   restore, sem destruir nada, e apontam para o RECUPERACAO.md. Nada automático
#   os chama (conferido: nenhum timer de spicetify, nenhum hook do Aurora), mas
#   "só roda pelo dedo dela" torna o estrago mais provável no pior momento, não
#   menos.
#
# ─────────────────────────────────────────────────────────────────────────────
# 1. O QUE ESTÁ INSTALADO — MEDIDO EM 10/08/2026
# ─────────────────────────────────────────────────────────────────────────────
#   Spotify:   flatpak com.spotify.Client 1.2.92.147.g5b8f9367, instalação de
#              USUÁRIO (`~/.local/share/flatpak`), commit ostree abf9251b…
#   spicetify: v2.44.0, instalado pelo script oficial em `~/.spicetify/spicetify`.
#              O binário fica em ~/.spicetify/spicetify (já no PATH pelo env.zsh).
#   Tema:      catppuccin/spicetify @ 1ec645c4, copiado para
#              `~/.config/spicetify/Themes/catppuccin` (a `PROCEDENCIA.txt` lá
#              dentro guarda o commit).
#
#   O `spicetify config spotify_path` aponta para
#   `…/x86_64/stable/active/files/extra/share/spotify` — o diretório que CONTÉM
#   `Apps/`, como a doc manda, e com caminho ABSOLUTO (o `~` não é expandido
#   dentro do config-xpui.ini). O `prefs_path` é o do flatpak,
#   `~/.var/app/com.spotify.Client/config/spotify/prefs`.
#
#   OS `sudo chmod a+wr` DA DOC NÃO FORAM RODADOS, E NÃO DEVEM SER. O exemplo da
#   doc é a instalação de SISTEMA (`/var/lib/flatpak`), que é do root. A desta
#   máquina é de usuário e já era gravável: `nlink=1 modo=644 dono=<usuário>`.
#   Não havia permissão a conquistar; aqueles dois comandos só afrouxariam
#   permissões sem ganho nenhum.
#
# ─────────────────────────────────────────────────────────────────────────────
# 2. O QUE O SPICETIFY FAZ COM O DISCO — E A PEGADINHA QUE ISSO CRIA
# ─────────────────────────────────────────────────────────────────────────────
#   Depois de `spicetify apply`, O `Apps/xpui.spa` DEIXA DE EXISTIR. O spicetify
#   desempacota o zip e deixa um DIRETÓRIO no lugar:
#
#     antes:  Apps/xpui.spa   (11168399 bytes)   Apps/login.spa
#     depois: Apps/xpui/      (index.html, colors.css, user.css, extensions/…)
#             Apps/login/
#
#   O Spotify carrega os dois formatos, então isso é normal — mas TODA checagem
#   que procurava `Apps/xpui.spa` passa a dizer "Spotify não instalado". Foi
#   exatamente o que aconteceu com o `_spot_onde()` da versão anterior deste
#   arquivo, e é por isso que o `meow_app_detectar` de hoje aceita OS DOIS.
#
#   Com `overwrite_assets 1` (que o tema Catppuccin exige) ele também reescreve
#   os assets crus, incluindo o `login.spa` — que o módulo antigo nunca tocou e
#   portanto nunca guardou. Por isso o backup de fora leva os dois.
#
# ─────────────────────────────────────────────────────────────────────────────
# 3. O ACENTO — O PONTO ONDE ESTE MÓDULO FAZ MAIS DO QUE A DOC OFERECE
# ─────────────────────────────────────────────────────────────────────────────
#   O README do catppuccin/spicetify diz que o acento se escolhe CLICANDO nas
#   configurações do Spotify, e o `theme.js` guarda a escolha no localStorage
#   (`catppuccin-accentColor`). Não há comando de CLI. Aceitar isso significaria
#   que metade do gosto dela — o ACCENT do meow.conf — sairia do alcance do
#   arquivo de configuração e o doctor não teria como conferir.
#
#   Lendo o `theme.js`, o "acento" é só isto:
#       "--spice-text": `var(--spice-<acento>)`
#       "--spice-button-active": `var(--spice-<acento>)`
#   e essas duas variáveis nascem do `color.ini`, que é um ARQUIVO. Então o
#   `acento.py` ao lado escreve o hex do acento nessas duas chaves, na seção do
#   flavor, tirando o número da PRÓPRIA seção (nunca da paleta do Meow — assim
#   `aplicar` e `conferir` falam do mesmo número). Resultado medido:
#       Apps/xpui/colors.css  ->  --spice-text: #cba6f7
#   sem um clique. O dropdown do tema continua lá e continua ganhando enquanto
#   ela o usar (ele escreve `style` inline no `<html>`); o que ele perde é o
#   sentido de "none", que agora cai no nosso acento em vez do cinza-texto.
#
# ─────────────────────────────────────────────────────────────────────────────
# 4. POR QUE O INSTALADOR OFICIAL FOI RODADO TRUNCADO
# ─────────────────────────────────────────────────────────────────────────────
#   O `install.sh` oficial honra `ZDOTDIR` (linhas 105-107) e, nesta máquina,
#   acrescentaria `export PATH=$PATH:$HOME/.spicetify` em
#   `~/.config/zsh/.zshrc` — que é um repositório git do Ritual da Aurora. Sujar
#   o repo dela e brigar com o self-heal por causa de uma linha de PATH não vale.
#   Por isso o instalador foi rodado truncado na linha 88 (o fim da instalação
#   de fato) e este módulo procura o binário nos dois lugares: no PATH e em
#   `~/.spicetify/spicetify`.
#
#   CORREÇÃO DE 10/08/2026, no mesmo dia: este bloco dizia "o binário NÃO está no
#   PATH" e isso é falso. `~/.config/zsh/env.zsh:11` já exporta
#   `PATH="$HOME/.spicetify:..."` desde antes desta sessão, e `command -v
#   spicetify` responde. O que é verdade é o resto: o instalador não escreveu no
#   `.zshrc` (o `git status` do repo dela seguiu limpo). A conclusão tirada dali
#   é que estava errada — e ela importa, porque a versão anterior mandava a
#   Vitória acrescentar à mão uma linha de PATH que já existia.
#   O mesmo corte evitou a última pergunta do script — "Do you want to install
#   spicetify Marketplace? (Y/n)", lida de `/dev/tty` — que sem terminal recebe
#   resposta vazia e INSTALA o Marketplace sem ninguém ter pedido.
#
# ─────────────────────────────────────────────────────────────────────────────
# 5. O CAMINHO DE VOLTA — ONDE ESTÁ O ORIGINAL DE FÁBRICA
# ─────────────────────────────────────────────────────────────────────────────
#   Antes de instalar o spicetify o xpui.spa foi devolvido ao estado de fábrica
#   e conferido: sha256 5ec1901f0b1988a7d1188127b5aa76ae25e15acec887dc664f286fb774006dfe,
#   11168399 bytes, sem a sentinela do Meow, com os 150 verdes originais.
#   Isso importa porque `spicetify backup` FOTOGRAFA O QUE ESTÁ NO DISCO: rodado
#   um minuto antes, teria congelado o Catppuccin do Meow como "vanilla" e o
#   `spicetify restore` nunca mais devolveria o original.
#
#   O de fábrica está em QUATRO lugares hoje (o mesmo sha nos quatro):
#     ~/.local/state/spicetify/Backup/xpui.spa          (o do spicetify)
#     ~/.local/state/meowsystem/backups/spotify-xpui-fabrica/xpui.spa
#     ~/Backups/spotify-fabrica-abf9251b/               (+ login.spa)
#     /mnt/Apate/backup-spotify-fabrica-abf9251b/       (+ login.spa, outro disco)
#   Os dois últimos existem porque nenhuma poda do projeto os alcança.
#
#   O que fazer quando o Spotify atualizar está em `RECUPERACAO.md`, nesta pasta.
#
# ─────────────────────────────────────────────────────────────────────────────
# 6. O QUE ESTE MÓDULO PERDEU AO DELEGAR — DITO EM VOZ ALTA
# ─────────────────────────────────────────────────────────────────────────────
#   O `xpui.py` só mexia em `.css`, e o pior caso de uma receita vencida era o
#   app ficar com a cara de fábrica. O spicetify patcha JAVASCRIPT: o pior caso
#   dele é a janela ABRIR EM BRANCO depois de uma atualização do Spotify, até
#   sair uma versão nova do spicetify. Trocamos "degrada bonito" por "para de
#   abrir", em troca de um tema muito mais completo. É uma troca real, e é dela.
#
#   O `xpui.py` continua na pasta, mas MUDOU DE PAPEL: não patcha mais nada pelo
#   caminho normal: é a perícia (`xpui.py estado <arquivo>` diz se um .spa está
#   de fábrica) e a saída de emergência descrita na RECUPERACAO.md.
#
# ─────────────────────────────────────────────────────────────────────────────
# 7. O SPOTIFY ABERTO NÃO É INTERROMPIDO. NUNCA. (regra herdada, e agora ainda
#    mais séria: o spicetify reescreve a árvore de arquivos inteira do app, não
#    um zip trocado por `mv` atômico.)
# ─────────────────────────────────────────────────────────────────────────────

_SPOT_DIR_MOD="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
_SPOT_ACENTO_PY="$_SPOT_DIR_MOD/acento.py"
# A paleta vem da porta única (lib/comum.sh). Era `assets/paleta/catppuccin.json` cravado até
# 17/09/2026 — e um nome cravado aqui faz este script continuar lendo o
# Catppuccin enquanto o resto do projeto já mudou de paleta, sem dar erro.
_SPOT_PALETA="$(meow_paleta)"

# De onde saem FLAVOR e ACCENT: do AMBIENTE, posto por quem chama (bin/meow,
# install.sh). Ler o meow.conf aqui dentro seria um segundo leitor da mesma conf,
# com precedência própria. A rede contra o valor errado é a checagem no
# `meow_app_detectar`, que também pega erro de digitação.
# Vazio, vale o flavor padrão do pack no ar: o `meow_flavor` (lib/comum.sh).
# Era `${FLAVOR:-mocha}`, o padrão de um pack só — uma das três cópias da regra
# que a P61 não alcançou (P65, 25/09/2026).
_SPOT_FLAVOR="$(meow_flavor)"
_SPOT_ACENTO="${ACCENT:-mauve}"

_SPOT_CONFIG_DIR="$HOME/.config/spicetify"
_SPOT_INI="$_SPOT_CONFIG_DIR/config-xpui.ini"

# O QUE APLICAR VEM DO PACK — 22/09/2026, sprint P18
#   Até esta linha, este arquivo sabia de cor o nome do tema
#   (`Themes/catppuccin`), o nome do esquema de cor, e o endereço do tarball de
#   onde ele desce. Eram 39 citações da palavra `catppuccin` num módulo só, e
#   nenhuma consulta ao pack ativo — o que tornava este arquivo um aplicador de
#   Catppuccin, e não um aplicador do tema da casa.
#
#   O QUE ISSO CUSTOU, MEDIDO NESTA MÁQUINA EM 21/09/2026
#     ~/.config/spicetify/config-xpui.ini    current_theme = Sleek
#                                            color_scheme  = Dracula
#     …/flatpak/…/spotify/Apps/xpui          existe: o app ESTÁ patchado
#     ~/.config/spicetify/Themes/            20 temas, e nenhum "catppuccin"
#
#   O pack ativo era o Dracula, o Spotify já estava vestido de Dracula, e este
#   módulo exigia o tema catppuccin como pré-condição, não achava, e devolvia 3.
#   A camada de cima imprimia «Spotify não instalado (ou não é o flatpak de
#   usuário)» para um Spotify instalado, patchado e tematizado.
#
#   AS TRÊS PERGUNTAS, E ELAS SÃO DO PACK, NÃO DAQUI
#     spicetify_tema       qual pasta de ~/.config/spicetify/Themes usar
#     esquema              qual seção do color.ini daquele tema
#     acento_no_color_ini  se dá para escrever o acento da casa lá dentro
#
#   `MEOW_APP_TEMA_PACK` guarda QUEM respondeu, e é por isso que ele é lido uma
#   vez só, logo depois da primeira pergunta: a herança do formato é POR
#   APLICATIVO, então as três respostas vêm sempre do mesmo pack. Guardá-lo
#   depois de cada chamada daria a impressão de que elas podem divergir.
#
#   A CHAMADA É DIRETA, SEM `$( )` — 22/09/2026, revisão da P18
#     Estas quatro linhas eram `X="$(meow_app_tema_do_pack …)"`. `$( )` é
#     SUBSHELL, e o `MEOW_APP_TEMA_PACK` que a função atribui morria com ele:
#     medido, com PACK=catppuccin, `_SPOT_TEMA_NOME=[catppuccin]` e
#     `_SPOT_TEMA_DE=[]`. O valor chegava, a procedência não — e era ela que
#     fazia o log dizer "do pack ativo" em toda linha desta tela, e o
#     PROCEDENCIA.txt do tema baixado gravar "pedido pelo pack ?". A função
#     hoje responde pelas duas variáveis e não imprime nada.
#
#   RESOLVIDO NO `source`, COMO OS VIZINHOS. `_SPOT_PALETA` logo acima faz o
#   mesmo, e o runner (`scripts/aplicar_apps.sh`) carrega cada manifesto num
#   SUBSHELL, depois de PACK e FLAVOR já estarem no ambiente.
meow_app_tema_do_pack spotify.spicetify_tema
_SPOT_TEMA_NOME="$MEOW_APP_TEMA"
_SPOT_TEMA_DE="$MEOW_APP_TEMA_PACK"
# O NOME VIRA PASTA de Themes/, que leva `rm -rf` antes de o tema entrar (P107).
# Com `..` o alvo era a pasta inteira do spicetify, e com `/` a pasta de outro
# tema. O `validar` recusa o pack, mas o nome chega também pela herança de um
# pack que nunca passou por ele: aqui ele vale como não declarado, com o motivo.
_SPOT_NOME_RECUSADO=""
if [ -n "$_SPOT_TEMA_NOME" ] && ! [[ "$_SPOT_TEMA_NOME" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]; then
  _SPOT_NOME_RECUSADO="$_SPOT_TEMA_NOME"; _SPOT_TEMA_NOME=""
fi
meow_app_tema_do_pack spotify.esquema
_SPOT_ESQUEMA="$MEOW_APP_TEMA"
meow_app_tema_do_pack spotify.acento_no_color_ini
_SPOT_ACENTO_NO_INI="$MEOW_APP_TEMA"

# Vazio quando o pack não declara o Spotify: o `detectar` transforma isso num 3
# com motivo, e NÃO num caminho `Themes/` que nomearia uma pasta chamada nada.
_SPOT_TEMA=""; _SPOT_COLOR_INI=""
if [ -n "$_SPOT_TEMA_NOME" ]; then
  _SPOT_TEMA="$_SPOT_CONFIG_DIR/Themes/$_SPOT_TEMA_NOME"
  _SPOT_COLOR_INI="$_SPOT_TEMA/color.ini"
fi

# O Marketplace é um CustomApp do spicetify — uma PÁGINA dentro do Spotify, de
# onde se instalam extensões, snippets e outros apps. Ele NÃO vem no binário: o
# instalador oficial pergunta "Do you also want to install spicetify
# Marketplace? (Y/n)" no fim, e em 10/08/2026 essa pergunta foi cortada de
# propósito (item 4). Ela pediu em 24/08/2026, e agora quem instala é o
# MeowSystem — não um `curl | sh`, que não é idempotente nem sobrevive ao doctor.
_SPOT_MP_DIR="$_SPOT_CONFIG_DIR/CustomApps/marketplace"
_SPOT_MP_VERSAO="$_SPOT_MP_DIR/.meow-versao"
_SPOT_MP_RELEASES="https://github.com/spicetify/marketplace/releases"
_SPOT_MARKETPLACE="${SPOTIFY_MARKETPLACE:-sim}"

# O binário: PATH primeiro (se ela um dia o puser lá), depois o lugar onde o
# instalador oficial o deixa. Ver item 4.
_spot_cli() {
  if meow_tem spicetify; then command -v spicetify; return 0; fi
  [ -x "$HOME/.spicetify/spicetify" ] && { printf '%s' "$HOME/.spicetify/spicetify"; return 0; }
  return 1
}

# O corpo do Spotify. `current/active` são os symlinks que o flatpak reaponta a
# cada atualização: usá-los é o que faz isto continuar achando o app sem ninguém
# reescrever um hash aqui dentro.
_spot_dir() {
  printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify"
}

# O `Apps/` do Spotify tem xpui.spa OU xpui/ — ver item 2. Testar só o `.spa`
# fazia o módulo anunciar "Spotify não instalado" logo depois de tematizá-lo.
_spot_instalado() {
  local d; d="$(_spot_dir)"
  [ -f "$d/Apps/xpui.spa" ] || [ -d "$d/Apps/xpui" ]
}

# A versão do Spotify em formato COMPARÁVEL com o que o spicetify grava em
# `[Backup] version`. `flatpak info` traz o rótulo traduzido (aqui em pt-BR);
# `--columns` devolve o valor cru, que não depende de idioma.
_spot_versao() {
  flatpak list --app --columns=application,version 2>/dev/null \
    | awk -F'\t' '$1=="com.spotify.Client"{print $2; exit}'
}

# Lê uma chave do config-xpui.ini SEM chamar o binário: `conferir` é leitura
# pura e `spicetify config <chave>` toca o arquivo (chega a gerá-lo do zero).
_spot_ini_ler() {
  [ -f "$_SPOT_INI" ] || return 1
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p" \
    "$_SPOT_INI" | head -1
}

# --- O CARIMBO DE VERSÃO DO BACKUP -----------------------------------------
# MEDIDO em 24/08/2026, e é a razão de as quatro funções abaixo existirem.
#
# O spicetify NÃO lê a versão do Spotify do binário do app: ele lê a chave
# `app.last-launched-version` do `prefs` — o arquivo que o Spotify só reescreve
# QUANDO ABRE. Depois de um `flatpak update`, quem rodar `spicetify backup
# apply` ANTES de ela abrir o Spotify grava no `[Backup] version` a versão
# VELHA, apesar de o backup recém-tirado ser o da versão NOVA.
#
# Foi exatamente o que aconteceu aqui:
#   13/08 22:32  o flatpak desempacotou a 1.2.95.453.g0eeebbed
#   13/08 22:34  `backup apply` rodou — o xpui.spa do backup tem sha 7ce05c00…,
#                que NÃO é o de fábrica da 1.2.92 (5ec1901f…): o backup é NOVO
#   13/08 22:34  o ini foi carimbado com 1.2.92.147.g5b8f9367, a versão velha
#
# O efeito não é um aviso feio, é uma TRANCA: a guarda de versão do `aplicar` e
# do `reverter` passa a recusar para sempre, porque os dois números nunca mais
# se encontram sozinhos. No dia em que uma atualização de verdade apagar o tema,
# o doctor das 05:00 se recusaria a repor — e a mensagem diria "o Spotify
# atualizou", que é falso. A guarda que existia para proteger virou a razão de
# o conserto automático não acontecer.
#
# A PROVA DE QUE O BACKUP É DA VERSÃO CERTA NÃO É O NÚMERO, É A DATA
#   O flatpak desempacota cada versão do Spotify num diretório com o nome do
#   commit e reaponta o symlink `active`. Se o `xpui.spa` do backup é MAIS NOVO
#   que esse diretório, ele só pode ter saído do app que está no disco agora.
#   Isso não depende de nenhum detalhe interno do spicetify, e continua valendo
#   se um dia ele mudar de onde lê a versão.
#
# O CARIMBO NÃO É "IGNORAR A GUARDA"
#   Quando o backup é VELHO de verdade (tirado antes do deploy atual), nada
#   muda: o `aplicar` continua parando e mandando ler o RECUPERACAO.md, porque
#   ali o `restore` realmente copiaria a interface velha por cima do app novo.

# O diretório REAL do deploy. `active` é o symlink que o flatpak reaponta.
_spot_deploy_dir() {
  readlink -f -- "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/app/com.spotify.Client/current/active" 2>/dev/null
}

# Onde o spicetify guarda o backup. Ele respeita o XDG_STATE_HOME.
_spot_backup_spa() {
  printf '%s' "${XDG_STATE_HOME:-$HOME/.local/state}/spicetify/Backup/xpui.spa"
}

# 0 = o backup do spicetify saiu do Spotify que está no disco AGORA.
_spot_backup_fresco() {
  local spa dep tspa tdep
  spa="$(_spot_backup_spa)"
  dep="$(_spot_deploy_dir)"
  [ -f "$spa" ] || return 1
  [ -n "$dep" ] && [ -d "$dep" ] || return 1
  tspa="$(stat -c %Y -- "$spa" 2>/dev/null)" || return 1
  tdep="$(stat -c %Y -- "$dep" 2>/dev/null)" || return 1
  [ "$tspa" -ge "$tdep" ]
}

# Reescreve UMA linha do config-xpui.ini.
#
# NÃO passa pelo `meow_escrever` de propósito, e isto é decisão, não esquecimento:
# o arquivo é do spicetify, não nosso, e entrar no manifesto o poria na fila de
# remoção do `--uninstall` — desinstalar o MeowSystem apagaria a configuração de
# outro programa. A trava de destino (`meow_destino_permitido`) continua valendo,
# e a escrita continua atômica, dentro do diretório de destino.
#
# 0 já estava certo · 1 carimbei · 2 erro
_spot_carimbar_versao() {
  local vi vb texto novo modo tmp
  vi="$(_spot_versao)"
  [ -n "$vi" ] || return "$MEOW_ERRO"
  [ -f "$_SPOT_INI" ] || return "$MEOW_ERRO"
  vb="$(_spot_ini_ler version)"
  [ "$vb" = "$vi" ] && return "$MEOW_OK"

  meow_destino_permitido "$_SPOT_INI" || return "$MEOW_ERRO"
  if meow_seco; then
    meow_muda "carimbaria [Backup] version = $vi no config-xpui.ini (está $vb)"
    return "$MEOW_DIVERGENTE"
  fi

  texto="$(cat -- "$_SPOT_INI")" || return "$MEOW_ERRO"
  # `0,/re/` é "só a PRIMEIRA ocorrência" — o mesmo critério do `_spot_ini_ler`,
  # que lê com `head -1`. Se um dia o ini tiver duas chaves `version`, leitor e
  # escritor continuam falando da mesma linha.
  novo="$(printf '%s\n' "$texto" | sed "0,/^[[:space:]]*version[[:space:]]*=/s|^\([[:space:]]*version[[:space:]]*=[[:space:]]*\).*\$|\1$vi|")"
  [ -n "$novo" ] || return "$MEOW_ERRO"
  # Conferir ANTES de trocar o arquivo: um sed que não casou devolve o texto
  # inteiro sem erro, e sem esta linha o carimbo falharia em silêncio.
  printf '%s\n' "$novo" | grep -qx "[[:space:]]*version[[:space:]]*=[[:space:]]*$vi" || return "$MEOW_ERRO"

  modo="$(stat -c %a -- "$_SPOT_INI" 2>/dev/null)"; modo="${modo:-644}"
  tmp="$(mktemp -p "$(dirname -- "$_SPOT_INI")" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  printf '%s\n' "$novo" > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod "$modo" "$tmp"
  mv -f "$tmp" "$_SPOT_INI" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

# --- O MARKETPLACE ---------------------------------------------------------
# CONFERIDO NOS MESMOS TRÊS NÍVEIS DO TEMA, E PELO MESMO MOTIVO
#   1. a INTENÇÃO   `custom_apps` no config-xpui.ini
#   2. a RECEITA    os arquivos em ~/.config/spicetify/CustomApps/marketplace
#   3. o RESULTADO  `spicetify-routes-marketplace.js` dentro do Apps/xpui
#   Sem o nível 3, um `apply` que nunca aconteceu passaria por instalação
#   bem-sucedida — e ela abriria o Spotify procurando um menu que não está lá.
#
# O DOWNLOAD PODE FALHAR SEM SER ERRO
#   Sem rede, o passo devolve "falta dependência" (3) e tenta no ciclo seguinte.
#   Um erro (2) faria o `install.sh` contar uma falha por causa de Wi-Fi caído.
#
# POR QUE NÃO O `curl | sh` OFICIAL
#   Ele roda `spicetify apply` no fim, sem olhar se o Spotify está aberto, e
#   troca `current_theme` para "marketplace" quando o tema atual tem 3 letras ou
#   menos (linhas 61-70 do install.sh deles). Aqui o tema é "catppuccin" e
#   escaparia — mas depender de um `if` alheio para não perder o tema dela é
#   frágil. Este caminho nunca toca no `current_theme`.
_spot_mp_quer() { [ "$_SPOT_MARKETPLACE" = "sim" ]; }

# `custom_apps` é lista separada por vírgula. As bordas viram vírgula para que
# o primeiro e o último item casem com o mesmo padrão dos do meio.
_spot_mp_registrado() {
  # O `config-xpui.ini` separa as listas com `|` (`custom_apps = a|b|c`); a
  # vírgula continua aceita. Até 24/09/2026 só a vírgula contava: com mais de um
  # CustomApp o Marketplace "não estava registrado" mesmo estando, o
  # `_spot_mp_registrar` mandava o spicetify acrescentá-lo de novo, e a
  # instalação saía com "o spicetify não gravou o custom_apps".
  case "|$(_spot_ini_ler custom_apps | tr -d '[:space:]' | tr ',' '|')|" in
    *"|marketplace|"*) return 0 ;;
  esac
  return 1
}

_spot_mp_baixado() {
  [ -d "$_SPOT_MP_DIR" ] && [ -n "$(ls -A "$_SPOT_MP_DIR" 2>/dev/null)" ]
}

# MEDIDO em 24/08/2026, depois do primeiro `apply`: o spicetify NÃO cria
# `Apps/xpui/marketplace/`. Ele ACHATA o CustomApp na raiz do xpui como
# `spicetify-routes-marketplace.{js,css,json}` (mais `extensions/marketplace`).
# A primeira versão desta função procurava a pasta e teria dito "falta aplicar"
# para sempre num Spotify já correto — o mesmo erro que o item 2 deste cabeçalho
# registra sobre procurar `xpui.spa` depois do apply.
_spot_mp_no_disco() { [ -f "$(_spot_dir)/Apps/xpui/spicetify-routes-marketplace.js" ]; }

# 0 já estava lá · 1 instalei · 2 erro · 3 falta dependência
_spot_mp_instalar() {
  local tag tmp zip
  _spot_mp_baixado && return "$MEOW_OK"

  meow_tem curl  || { meow_pula "sem curl — o Marketplace fica de fora"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem unzip || { meow_pula "sem unzip — o Marketplace fica de fora"; return "$MEOW_SEM_DEPENDENCIA"; }

  if meow_seco; then
    meow_muda "baixaria o Marketplace do spicetify para $_SPOT_MP_DIR"
    return "$MEOW_DIVERGENTE"
  fi

  tag="$(curl -fsSL -H 'Accept: application/json' "$_SPOT_MP_RELEASES/latest" 2>/dev/null \
          | sed -n 's/.*"tag_name":"\([^"]*\)".*/\1/p' | head -1)"
  if [ -z "$tag" ]; then
    meow_aviso "não descobri a versão do Marketplace (sem rede?) — fica para o próximo ciclo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_destino_permitido "$_SPOT_MP_DIR" || return "$MEOW_ERRO"
  tmp="$(mktemp -d)" || return "$MEOW_ERRO"
  zip="$tmp/marketplace.zip"
  if ! curl -fsSL -o "$zip" "$_SPOT_MP_RELEASES/download/$tag/marketplace.zip"; then
    rm -rf "$tmp"
    meow_aviso "o download do Marketplace $tag falhou — fica para o próximo ciclo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! unzip -q -d "$tmp/x" "$zip" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o zip do Marketplace veio corrompido"; return "$MEOW_ERRO"
  fi
  # O zip traz UM diretório, `marketplace-dist`. Conferir isto é o que faz esta
  # função quebrar COM MENSAGEM no dia em que o formato do release mudar, em vez
  # de instalar uma pasta vazia que o `conferir` aprovaria.
  if [ ! -d "$tmp/x/marketplace-dist" ]; then
    rm -rf "$tmp"
    meow_erro "o zip do Marketplace mudou de formato (sem marketplace-dist)"
    return "$MEOW_ERRO"
  fi

  mkdir -p "$(dirname -- "$_SPOT_MP_DIR")" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  rm -rf "$_SPOT_MP_DIR"
  mv "$tmp/x/marketplace-dist" "$_SPOT_MP_DIR" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  printf '%s\n' "$tag" > "$_SPOT_MP_VERSAO"
  rm -rf "$tmp"
  meow_ok "Marketplace do spicetify $tag baixado"
  return "$MEOW_DIVERGENTE"
}

# 0 já estava registrado · 1 registrei · 2 erro
_spot_mp_registrar() {
  local cli
  _spot_mp_registrado && return "$MEOW_OK"
  if meow_seco; then
    meow_muda "acrescentaria 'marketplace' ao custom_apps do spicetify"
    return "$MEOW_DIVERGENTE"
  fi
  cli="$(_spot_cli)" || return "$MEOW_ERRO"
  # `spicetify config <lista> <valor>` ACRESCENTA à lista; quem REMOVE é o
  # sufixo `-` (`marketplace-`). Por isso isto não apaga outro CustomApp dela.
  "$cli" config custom_apps marketplace >/dev/null 2>&1 || {
    meow_erro "não consegui acrescentar 'marketplace' ao custom_apps"
    return "$MEOW_ERRO"
  }
  _spot_mp_registrado || { meow_erro "o spicetify não gravou o custom_apps"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

# TUDO OU NADA — o mesmo desenho do `_cursor_baixar_instalar` (scripts/cursor.sh),
# e pelo mesmo motivo: o tema são dezenas de arquivos, e um download cortado no
# meio deixaria um `color.ini` sem os assets ao lado. O `detectar` daria o tema
# por presente (ele testa o `color.ini`) e o Spotify abriria com metade do
# estilo — o tipo de defeito que ninguém liga ao instalador. Por isso o tarball
# desce inteiro para um temporário, é conferido, e só então entra no lugar com
# um `mv` único.
#
# O DIRETÓRIO NÃO VAI PARA O MANIFESTO, e é a mesma escolha do Marketplace logo
# acima: quem desfaz o Spotify é o `meow_app_reverter` (`spicetify restore`), e
# o que mora em `~/.config/spicetify` é insumo do spicetify, não arquivo nosso
# plantado no sistema dela.
#
# O ENDEREÇO TAMBÉM VEM DO PACK — 22/09/2026, sprint P18
#   O `_SPOT_TEMA_TAR` que morava no topo deste arquivo era
#   `https://github.com/catppuccin/spicetify/archive/<commit>.tar.gz`, cravado.
#   Um módulo que sabe de cor o endereço de UM tema é o aplicador daquele tema —
#   e era essa linha, mais que qualquer outra, que fazia deste arquivo um
#   aplicador de Catppuccin.
#
#   O PINO POR COMMIT NÃO SE PERDEU, MUDOU DE DONO. A disciplina continua a
#   mesma do `scripts/cursor.sh` e o motivo continua medido (22/09/2026:
#   `/repos/catppuccin/spicetify/tags` devolve lista vazia e
#   `/releases/latest` devolve 404 — pinar "por tag" ali seria cair no `main`).
#   O que mudou é que o número agora é DECLARAÇÃO do pack, em
#   `apps.spotify.origem.commit`, onde quem publica o pack o escreve e o
#   `pack.py validar` o lê.
#
#   PACK SEM `origem` NÃO É DEFEITO, É RESPOSTA. O pack Dracula pede o tema
#   `Sleek`, que não é arte deste projeto e não tem tarball que se possa pinar:
#   ele declara o nome e mais nada. Aqui isso vira "não sei de onde baixar", com
#   a frase dizendo qual pack pediu o quê — e nunca um download do tema de OUTRO
#   pack, que é exatamente o defeito que a sprint veio matar.
#
# 0 quando `_SPOT_TEMA` é filha direta de Themes/, depois de resolvidos os
# links; senão 1, com a frase. Vem antes de todo `rm -rf` dele (P107).
_spot_alvo_seguro() {
  local themes alvo
  themes="$(readlink -m -- "$_SPOT_CONFIG_DIR/Themes")"
  alvo="$(readlink -m -- "$_SPOT_TEMA")"
  if [ -n "$_SPOT_TEMA_NOME" ] && [ "$alvo" != "$themes" ] && [ "$(dirname -- "$alvo")" = "$themes" ]; then
    return 0
  fi
  meow_erro "recusado: '$_SPOT_TEMA' não é uma pasta de $_SPOT_CONFIG_DIR/Themes"
  return 1
}

# O tema que o pack traz na pasta dele: só o color.ini, o user.css e a licença,
# arquivos comuns (link não entra). 1 entregou · 2 erro.
_spot_tema_do_pack() {
  local ini="$1" dir tmp f
  dir="$(dirname -- "$ini")"
  if meow_seco; then
    meow_muda "poria o tema '$_SPOT_TEMA_NOME' do spicetify, que vem no pack, em $_SPOT_TEMA"
    return "$MEOW_DIVERGENTE"
  fi
  meow_destino_permitido "$_SPOT_TEMA" || return "$MEOW_ERRO"
  _spot_alvo_seguro || return "$MEOW_ERRO"
  mkdir -p "$(dirname -- "$_SPOT_TEMA")" || return "$MEOW_ERRO"
  tmp="$(mktemp -d -p "$(dirname -- "$_SPOT_TEMA")" ".meow-spot-tema.XXXXXX")" || return "$MEOW_ERRO"
  chmod 755 "$tmp"
  for f in color.ini user.css LICENSE; do
    [ -f "$dir/$f" ] && [ ! -L "$dir/$f" ] || continue
    cp -- "$dir/$f" "$tmp/$f" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  done
  [ -f "$tmp/color.ini" ] || { rm -rf "$tmp"; meow_erro "o tema do pack não tem color.ini"; return "$MEOW_ERRO"; }
  printf 'pack %s: %s\ncopiado pelo MeowSystem em %s\n' "${_SPOT_TEMA_DE:-?}" "$dir" "$(date -Iseconds)" \
    > "$tmp/PROCEDENCIA.txt" 2>/dev/null
  rm -rf "$_SPOT_TEMA"
  mv -f "$tmp" "$_SPOT_TEMA" || { rm -rf "$tmp"; meow_erro "não consegui pôr o tema em $_SPOT_TEMA"; return "$MEOW_ERRO"; }
  meow_ok "tema '$_SPOT_TEMA_NOME' do spicetify posto em $_SPOT_TEMA, do pack ${_SPOT_TEMA_DE:-ativo}"
  return "$MEOW_DIVERGENTE"
}

#   0 já estava lá · 1 baixei · 2 erro · 3 falta dependência (ou rede, ou origem)
_spot_tema_baixar() {
  local tmp origem repo commit pasta tar
  [ -n "$_SPOT_COLOR_INI" ] || return "$MEOW_SEM_DEPENDENCIA"
  [ -f "$_SPOT_COLOR_INI" ] && return "$MEOW_OK"

  # A arte que mora no pack vence a origem: `arquivo` é o color.ini, e o tema é
  # a pasta dele. Sai sem rede, e o `pack.py validar` confere o sha256.
  meow_app_tema_do_pack spotify.arquivo
  if [ -n "$MEOW_APP_TEMA" ]; then
    _spot_tema_do_pack "$MEOW_APP_TEMA"
    return $?
  fi

  # Direto, sem `$( )`: a função responde por `MEOW_APP_TEMA`, e um subshell
  # devolveria string vazia — ver o bloco da identidade, lá em cima.
  meow_app_tema_do_pack spotify.origem.repo;   repo="$MEOW_APP_TEMA"
  meow_app_tema_do_pack spotify.origem.commit; commit="$MEOW_APP_TEMA"
  meow_app_tema_do_pack spotify.origem.pasta;  pasta="$MEOW_APP_TEMA"
  if [ -z "$repo" ] || [ -z "$commit" ] || [ -z "$pasta" ]; then
    meow_pula "o pack pede o tema '$_SPOT_TEMA_NOME' do spicetify e não diz de onde ele desce"
    meow_info "instale-o em $_SPOT_TEMA, ou escolha um pack que traga a origem do tema"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  tar="https://github.com/$repo/archive/$commit.tar.gz"

  meow_tem curl || { meow_pula "sem curl — o tema do spicetify fica de fora"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem tar  || { meow_pula "sem tar — o tema do spicetify fica de fora";  return "$MEOW_SEM_DEPENDENCIA"; }

  if meow_seco; then
    meow_muda "baixaria o tema '$_SPOT_TEMA_NOME' do spicetify para $_SPOT_TEMA"
    return "$MEOW_DIVERGENTE"
  fi

  meow_destino_permitido "$_SPOT_TEMA" || return "$MEOW_ERRO"
  _spot_alvo_seguro || return "$MEOW_ERRO"
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-spot-tema.XXXXXX")" || return "$MEOW_ERRO"

  # `--fail` para que uma página de erro do GitHub (404 com corpo HTML) não vire
  # "tarball corrompido" três linhas abaixo; `--max-time` porque um temporizador
  # é a única coisa que separa "sem rede" de "pendurado para sempre" num módulo
  # que o instalador carrega desatendido. Mesmos números do `_cursor_curl`.
  if ! curl -sSL --fail --connect-timeout 15 --max-time 300 \
         -o "$tmp/tema.tar.gz" "$tar" 2>/dev/null; then
    rm -rf "$tmp"
    meow_aviso "não deu para baixar o tema '$_SPOT_TEMA_NOME' do spicetify (sem rede?) — fica para o próximo ciclo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! tar -xzf "$tmp/tema.tar.gz" -C "$tmp" 2>/dev/null; then
    rm -rf "$tmp"
    meow_erro "o tarball do tema veio corrompido — nada instalado"
    return "$MEOW_ERRO"
  fi

  # O GitHub empacota tudo sob `<nome-do-repo>-<commit>/`, e o tema é a pasta
  # que o pack nomeia em `origem.pasta` lá dentro (o resto do repositório é
  # README e prints). Conferir o caminho é o que faz esta função quebrar COM
  # MENSAGEM no dia em que o upstream reorganizar as pastas, em vez de instalar
  # um diretório que o `detectar` aprovaria sem ter o que aplicar.
  origem="$tmp/${repo##*/}-$commit/$pasta"
  # O commit e a pasta vêm do pack: o que sai de dentro do tarball não vai
  # para Themes/ com `mv` (P107).
  case "$(readlink -m -- "$origem")" in
    "$(readlink -m -- "$tmp")"/*) ;;
    *) rm -rf "$tmp"; meow_erro "recusado: a origem do tema sai de dentro do tarball ($pasta)"; return "$MEOW_ERRO" ;;
  esac
  if [ ! -f "$origem/color.ini" ]; then
    rm -rf "$tmp"
    meow_erro "o tarball do tema mudou de formato (sem $pasta/color.ini)"
    return "$MEOW_ERRO"
  fi

  mkdir -p "$(dirname -- "$_SPOT_TEMA")" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  rm -rf "$_SPOT_TEMA"
  if ! mv -f "$origem" "$_SPOT_TEMA"; then
    rm -rf "$tmp"
    meow_erro "não consegui mover o tema para $_SPOT_TEMA"
    return "$MEOW_ERRO"
  fi
  # A PROCEDÊNCIA FICA AO LADO DO QUE ELA DESCREVE. É o mesmo `PROCEDENCIA.txt`
  # que o item 1 deste cabeçalho já citava, e é o que permite saber, meses
  # depois, de que árvore aquele `color.ini` veio.
  printf '%s @ %s\npedido pelo pack %s\nbaixado pelo MeowSystem em %s\n' \
         "$repo" "$commit" "${_SPOT_TEMA_DE:-?}" "$(date -Iseconds)" \
    > "$_SPOT_TEMA/PROCEDENCIA.txt" 2>/dev/null
  rm -rf "$tmp"
  meow_ok "tema '$_SPOT_TEMA_NOME' do spicetify baixado em $_SPOT_TEMA"
  return "$MEOW_DIVERGENTE"
}

_spot_rodando() {
  if meow_tem flatpak && \
     flatpak ps --columns=application 2>/dev/null | grep -qx 'com.spotify.Client'; then
    return 0
  fi
  pgrep -x spotify >/dev/null 2>&1
}

# O pack pediu o acento da casa dentro do color.ini deste tema? Ver o bloco
# "O ACENTO É OPCIONAL", no `meow_app_detectar`.
_spot_quer_acento() { [ "$_SPOT_ACENTO_NO_INI" = "sim" ]; }

_spot_receita_valida() {
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))["flavors"][sys.argv[2]][sys.argv[3]]' \
    "$_SPOT_PALETA" "$_SPOT_FLAVOR" "$_SPOT_ACENTO" 2>/dev/null
}

# 0 = o programa está nesta máquina · 1 = não está. A regra de "instalado" que
# a tabela do `meow apps` pergunta e o `detectar` abre com ela (24/09/2026, P49;
# ver o quinto verbo no `rodar_modulo` do scripts/aplicar_apps.sh).
# O Spotify de sistema, ou um de usuário sem o `Apps/`, É instalado: só não é o
# que o spicetify alcança, e isso é o motivo da pendência, logo abaixo.
meow_app_instalado() { meow_flatpak_tem com.spotify.Client; }

# CADA SAÍDA-3 DAQUI DECLARA A CAUSA [21/09/2026]
#   As sete linhas abaixo saíam com o mesmo número e nenhuma palavra, e quem
#   recebia o número — o `aplicar` — chutava a primeira causa da lista. O
#   contrato agora é o do `meow_app_sem` (ver lib/comum.sh): a causa viaja junto
#   com o 3. As frases que estavam em `meow_pula` aqui NÃO foram perdidas: elas
#   viraram o motivo, e quem as imprime agora é o `aplicar`. Os `meow_info`
#   ficam, porque são o CONSERTO, não a causa — e conserto se diz uma vez só.
meow_app_detectar() {
  # Motivo velho mente com cara de medida: zerar antes de medir é do contrato.
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "Spotify: não está instalado"; return; }
  _spot_instalado || { meow_app_sem "Spotify: não está instalado como flatpak de usuário"; return; }

  # O PACK PRECISA TER PEDIDO ALGUMA COISA — 22/09/2026, sprint P18
  #   Pack que não declara `apps.spotify` (nem herda de quem declare) não tem
  #   tema para este app, e isto é AUSÊNCIA DECLARADA, não erro: a alternativa
  #   seria escolher um tema em nome dele, que é o defeito que a sprint mediu no
  #   Obsidian — aplicar o tema de outro pack e chamar de sucesso.
  if [ -n "$_SPOT_NOME_RECUSADO" ]; then
    meow_app_sem "Spotify: o pack ${_SPOT_TEMA_DE:-ativo} dá ao tema um nome que não serve de pasta ('$_SPOT_NOME_RECUSADO') — nada é escrito"
    return
  fi
  if [ -z "$_SPOT_TEMA_NOME" ] || [ -z "$_SPOT_ESQUEMA" ]; then
    meow_app_sem "Spotify: o pack ativo não declara tema para este app (apps.spotify no pack.json)"
    return
  fi

  # AS DUAS RECEITAS DE TERMINAL SAIRAM DAQUI — 22/09/2026, sprint P2
  #   Ficavam dois `meow_info` com o conserto pronto: um `curl | sh` para
  #   instalar o spicetify e um `git clone` para baixar o tema. Diagnóstico
  #   certo, conserto conhecido, nenhum botão — é a falha que a P2 persegue.
  #
  #   AS DUAS TERMINAM DIFERENTE, E A DIFERENÇA É REAL:
  #
  #   O BINÁRIO continua sem botão. O instalador oficial do spicetify é um
  #   `curl | sh` que, nesta máquina, escreveria no `~/.config/zsh/.zshrc` do
  #   Ritual da Aurora (item 4 deste cabeçalho); e o script que resolveria
  #   direito — `spicetify-setup.sh`, 277 linhas — mora naquele outro
  #   repositório, que quem clonar ESTE não terá. Pôr um botão nisso seria
  #   repetir a dependência que a mesma sprint está tirando do
  #   `qbittorrent/manifesto.sh`. Então a mensagem diz A DECISÃO, sem receita.
  #
  #   O BINÁRIO GANHOU BOTÃO EM 22/09/2026 — sprint P29
  #     O parágrafo acima descreve o passado, e a frase que o encerra é a
  #     condição que ele mesmo impunha: "o script que resolveria direito mora
  #     naquele outro repositório". Não mora mais. A P29 o trouxe para
  #     `scripts/spicetify_setup.sh`, e os dois motivos da recusa caíram junto:
  #
  #       1. ele NÃO é o `curl | sh` oficial. Baixa o tarball do release
  #          PINADO por versão e o abre em `~/.spicetify` — a mesma disciplina
  #          do tema catppuccin (pinado por commit) e do Marketplace (por tag);
  #       2. ele NÃO escreve em arquivo de shell nenhum. Nem `.zshrc`, nem
  #          `.bashrc`, nem `env.zsh`. O repositório dela segue intocado, e a
  #          TRAVA 1 nem chega a ser consultada porque nada aponta para lá.
  #
  #     A frase na tela deixa de ser "instalá-lo é decisão sua, e o instalador
  #     mexe no seu terminal" — que era verdade sobre o instalador OFICIAL e
  #     deixou de ser sobre o nosso. Continua sendo decisão dela: o que muda é
  #     que agora a decisão cabe num clique, em vez de numa tarde.
  #
  #   O TEMA GANHOU BOTÃO, e era o deliverable nomeado da sprint. Não há nada
  #   de outro projeto aqui: é um repositório público, baixado por uma função
  #   deste arquivo (`_spot_tema_baixar`), pinada por commit, com a mesma
  #   disciplina do `scripts/cursor.sh`. O comando que a pendência publica é
  #   `meow apps aplicar spotify` — o verbo que já existia —, porque é o
  #   `meow_app_aplicar` logo abaixo quem chama a função. Um verbo novo só para
  #   isto seria uma segunda porta para o mesmo passo.
  if ! _spot_cli >/dev/null; then
    meow_pendencia_acionavel spicetify-ausente \
      "O Spotify está instalado, mas falta o spicetify — é ele que pinta o app. Posso baixá-lo (versão pinada) para ~/.spicetify, sem tocar na configuração do seu terminal" \
      "scripts/spicetify_setup.sh instalar"
    meow_app_sem "Spotify: falta o spicetify — é ele que tematiza o app desde 10/08/2026"
    return
  fi
  meow_pendencia_resolvida spicetify-ausente
  if [ ! -f "$_SPOT_COLOR_INI" ]; then
    meow_pendencia_acionavel spicetify-tema-ausente \
      "Falta o tema '$_SPOT_TEMA_NOME' do Spotify, que o pack ${_SPOT_TEMA_DE:-ativo} pede — posso baixá-lo para $_SPOT_TEMA" \
      "meow apps aplicar spotify"
    meow_app_sem "Spotify: falta o tema '$_SPOT_TEMA_NOME' do spicetify em $_SPOT_TEMA"
    return
  fi
  meow_pendencia_resolvida spicetify-tema-ausente
  meow_tem python3 || { meow_app_sem "Spotify: falta python3, que lê a paleta"; return; }
  # O ACENTO É OPCIONAL DESDE 22/09/2026, E QUEM DECIDE É O PACK
  #   Escrever o acento da casa dentro do color.ini só funciona num tema que
  #   nomeie as 26 cores da paleta como CHAVES — o do pack padrão faz isso. O
  #   `Sleek`, que o pack Dracula pede, define a seção [Dracula] com vinte e
  #   duas chaves e nenhuma chamada `mauve`: insistir ali daria erro 2 do
  #   `acento.py` e o módulo inteiro se declararia quebrado por causa de um
  #   passo que aquele tema não suporta. Por isso o pack declara
  #   `acento_no_color_ini`, e sem a declaração o passo simplesmente não existe.
  if _spot_quer_acento; then
    [ -f "$_SPOT_ACENTO_PY" ] || { meow_app_sem "Spotify: falta $_SPOT_ACENTO_PY, que escreve o acento no color.ini"; return; }
  fi
  # O `meow_aviso` que ficava aqui saiu: ele dizia a mesma frase que agora é o
  # motivo, e o `conferir` logo abaixo já repete o aviso por conta própria —
  # ele é quem precisa, porque engole de propósito a saída deste `detectar`.
  if _spot_quer_acento && ! _spot_receita_valida; then
    meow_app_sem "Spotify: flavor/acento inexistentes na paleta ($_SPOT_FLAVOR/$_SPOT_ACENTO) — confira o meow.conf"
    return
  fi
  # O spicetify precisa escrever no corpo do app. Se um dia isto virar
  # somente-leitura, o módulo tem de virar "pendente", não "erro".
  [ -w "$(_spot_dir)/Apps" ] || { meow_app_sem "Spotify: o corpo do app não está gravável em $(_spot_dir)/Apps"; return; }
  return "$MEOW_OK"
}

# LEITURA PURA. Não escreve um byte — não chama o binário do spicetify, que
# escreveria no config-xpui.ini só de ser invocado.
#
# CONFERE AS TRÊS COISAS QUE PODEM DIVERGIR, E É DE PROPÓSITO QUE SÃO TRÊS:
#   1. a INTENÇÃO no config-xpui.ini (tema e flavor)
#   2. o ACENTO no color.ini do tema
#   3. o RESULTADO no disco do Spotify (`Apps/xpui/colors.css`)
# Conferir só (1) e (2) seria conferir o que nós pedimos, não o que o app tem —
# e é justamente o passo (3) que pega a atualização do Spotify que apagou tudo.
meow_app_conferir() {
  meow_app_detectar >/dev/null 2>&1 || {
    if _spot_quer_acento && ! _spot_receita_valida; then
      meow_aviso "flavor/acento inexistentes na paleta: $_SPOT_FLAVOR/$_SPOT_ACENTO — confira o meow.conf"
    fi
    return "$MEOW_SEM_DEPENDENCIA"
  }

  local tema esquema acento_ok hex colors
  tema="$(_spot_ini_ler current_theme)"
  esquema="$(_spot_ini_ler color_scheme)"

  # O QUE O PACK PEDIU, E NÃO UM NOME CRAVADO — 22/09/2026, sprint P18
  #   Estas duas linhas eram `[ "$tema" = "catppuccin" ]` e
  #   `[ "$esquema" = "$_SPOT_FLAVOR" ]`. Elas conferiam a RECEITA DE UM TEMA,
  #   não o tema do pack no ar — e era por elas que um Spotify corretamente
  #   vestido de Dracula aparecia como divergente para sempre.
  [ "$tema" = "$_SPOT_TEMA_NOME" ] || return "$MEOW_DIVERGENTE"
  [ "$esquema" = "$_SPOT_ESQUEMA" ] || return "$MEOW_DIVERGENTE"

  # (2) O ACENTO, SÓ QUANDO O PACK PEDE. Ver "O ACENTO É OPCIONAL", no detectar.
  hex=""
  if _spot_quer_acento; then
    acento_ok="$(python3 "$_SPOT_ACENTO_PY" estado "$_SPOT_COLOR_INI" \
                   --flavor "$_SPOT_ESQUEMA" --acento "$_SPOT_ACENTO" 2>/dev/null)" || {
      meow_erro "não consegui ler o color.ini do tema '$_SPOT_TEMA_NOME'"
      return "$MEOW_ERRO"
    }
    hex="$(printf '%s\n' "$acento_ok" | sed -n 's/^desejado=//p')"
    printf '%s\n' "$acento_ok" | grep -qx 'ok=sim' || return "$MEOW_DIVERGENTE"
  fi

  # (3) O RESULTADO NO DISCO. Sem esta parte o doctor aprovaria uma intenção
  # perfeita num Spotify que voltou ao normal depois de um `flatpak update`.
  colors="$(_spot_dir)/Apps/xpui/colors.css"
  if [ ! -f "$colors" ]; then
    meow_aviso "o Spotify no disco não tem o tema aplicado (o spicetify foi desfeito, ou o app atualizou)"
    return "$MEOW_DIVERGENTE"
  fi
  # SEM ACENTO NOSSO, O QUE PROVA O PASSO 3 É O ARQUIVO EXISTIR
  #   O `--spice-text` é a cor que o `acento.py` escreveu; num tema em que não
  #   escrevemos nada não há o que casar, e inventar outra prova aqui seria
  #   adivinhar o que o tema de terceiro gera. O `colors.css` existir já
  #   distingue "o spicetify aplicou" de "o app atualizou e apagou tudo", que é
  #   a pergunta deste passo.
  if [ -n "$hex" ]; then
    grep -qi -- "--spice-text: *#\?${hex}" "$colors" || return "$MEOW_DIVERGENTE"
  fi

  if _spot_mp_quer; then
    if ! _spot_mp_baixado; then
      meow_muda "o Marketplace do spicetify está pedido e não foi baixado"
      return "$MEOW_DIVERGENTE"
    fi
    if ! _spot_mp_registrado; then
      meow_muda "o Marketplace está baixado e fora do custom_apps do spicetify"
      return "$MEOW_DIVERGENTE"
    fi
    if ! _spot_mp_no_disco; then
      meow_muda "o Marketplace está configurado e ainda não entrou no Spotify (falta um apply)"
      return "$MEOW_DIVERGENTE"
    fi
  fi

  # A versão do backup do spicetify tem de ser a do Spotify instalado. Se
  # divergirem, restaurar produz janela em branco SEM mensagem de erro — é o
  # modo de falhar mais difícil de diagnosticar que existe aqui, e por isso ele
  # é avisado no `conferir` e não só na hora do desastre.
  local vb vi
  vb="$(_spot_ini_ler version)"; vi="$(_spot_versao)"
  if [ -n "$vb" ] && [ -n "$vi" ] && [ "$vb" != "$vi" ]; then
    if _spot_backup_fresco; then
      # Falso alarme, mas com consequência real: enquanto os números divergem, o
      # `aplicar` se recusa a agir. Por isso isto é DIVERGÊNCIA (que o
      # `--consertar` resolve), e não um aviso que fica na tela para sempre.
      meow_muda "o carimbo de versão do spicetify está velho ($vb; o Spotify é a $vi) — o backup, porém, é do app de agora"
      return "$MEOW_DIVERGENTE"
    fi
    meow_aviso "o backup do spicetify é da versão $vb e o Spotify é a $vi — veja scripts/temas-de-apps/spotify/RECUPERACAO.md"
  fi

  meow_ok "Spotify em $_SPOT_TEMA_NOME/$_SPOT_ESQUEMA, do pack ${_SPOT_TEMA_DE:-ativo} (via spicetify)"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  # O TEMA É INSUMO NOSSO, E INSUMO NOSSO SE BAIXA — 22/09/2026, sprint P2
  #   Isto vem ANTES do `detectar`, e a ordem é o ponto: é o `detectar` que
  #   reprova a falta do tema (e registra a pendência), então deixá-lo falar
  #   primeiro faria o `aplicar` desistir do único problema daquela lista que
  #   ele agora sabe resolver sozinho. O botão «Resolver» da Home aponta para
  #   `meow apps aplicar spotify`; é aqui que aquele clique vira arquivo.
  #
  #   Sem spicetify não adianta baixar tema: o binário é quem o lê. Por isso a
  #   guarda tem as três condições, e não só a do arquivo ausente.
  if _spot_instalado && _spot_cli >/dev/null && [ -n "$_SPOT_COLOR_INI" ] && [ ! -f "$_SPOT_COLOR_INI" ]; then
    _spot_tema_baixar
    case $? in
      2) return "$MEOW_ERRO" ;;
      # 3 é "sem rede, sem curl ou sem tar": segue em frente e deixa o
      # `detectar` logo abaixo registrar a pendência de novo, que é a verdade.
    esac
  fi
  # A FRASE QUE ESTAVA AQUI ERA A MENTIRA DE 21/09/2026: ela dizia "Spotify não
  # instalado" para um Spotify instalado, porque era a PRIMEIRA causa de uma
  # lista e o `detectar` só devolvia o número. Agora quem fala é o motivo.
  meow_app_detectar || { meow_app_pendente spotify; return; }
  # O CARIMBO VEM ANTES DE TUDO, E PODE ACONTECER COM O SPOTIFY ABERTO.
  # Ele não toca num byte do app — corrige uma linha do config-xpui.ini. É a
  # única parte deste módulo que a guarda "não mexo no app no meio do uso"
  # não precisa proteger, e adiá-la manteria a tranca de pé por mais um ciclo
  # inteiro do doctor. Só acontece quando o backup PROVADAMENTE é do app atual.
  local mexi=0 vb0 vi0
  vb0="$(_spot_ini_ler version)"; vi0="$(_spot_versao)"
  if [ -n "$vb0" ] && [ -n "$vi0" ] && [ "$vb0" != "$vi0" ] && _spot_backup_fresco; then
    _spot_carimbar_versao
    case $? in
      1) mexi=1
         meow_seco || meow_ok "carimbo de versão do spicetify corrigido: $vb0 -> $vi0 (o backup já era do app de agora)" ;;
      2) meow_erro "não consegui corrigir o [Backup] version do config-xpui.ini"
         return "$MEOW_ERRO" ;;
    esac
  fi

  # O MARKETPLACE TAMBÉM É PREPARADO COM O SPOTIFY ABERTO, PELO MESMO MOTIVO DO
  # CARIMBO: baixar o CustomApp e acrescentá-lo ao `custom_apps` mexe só em
  # ~/.config/spicetify. Quem precisa do app fechado é o `apply` lá embaixo — e
  # é ele que leva o Marketplace para dentro do Spotify.
  if _spot_mp_quer; then
    _spot_mp_instalar
    case $? in
      1) mexi=1 ;;
      2) return "$MEOW_ERRO" ;;
    esac
    if _spot_mp_baixado; then
      _spot_mp_registrar
      case $? in
        1) mexi=1 ;;
        2) return "$MEOW_ERRO" ;;
      esac
    fi
  fi

  meow_app_conferir >/dev/null 2>&1
  case $? in
    0) # A IRMÃ DO CAMINHO FELIZ. Chegar aqui exige `current_theme` igual ao que
       # o pack pede, então a pendência de "tema de terceiro" (se houver uma da
       # passagem anterior) deixou de ser verdade — e pendência que sobrevive ao
       # problema é a caixa de entrada que ninguém lê. O id é o do contrato:
       # `<app>-tema-de-terceiro`, ver `meow_app_tema_no_ar` em lib/comum.sh.
       meow_pendencia_resolvida spotify-tema-de-terceiro
       [ "$mexi" = "1" ] && return "$MEOW_DIVERGENTE"
       meow_ok "Spotify já está em $_SPOT_TEMA_NOME/$_SPOT_ESQUEMA, do pack ${_SPOT_TEMA_DE:-ativo} — nada a fazer"
       return "$MEOW_OK" ;;
    3) meow_pula "Spotify: nada a fazer (veja o aviso do conferir)"
       return "$MEOW_SEM_DEPENDENCIA" ;;
    2) return "$MEOW_ERRO" ;;
  esac

  # --- LER O QUE ESTÁ NO AR ANTES DE ESCREVER — 22/09/2026, sprint P18 -------
  #   Daqui para baixo o módulo escreve. A pergunta que faltava a todos os oito
  #   módulos é ESTA: o que o app está vestindo agora?
  #
  #   O DISCRIMINADOR É O TEMA, E NÃO O PAR TEMA/ESQUEMA, e a diferença é real.
  #   Um `current_theme` que já é o do pack com o esquema errado é NOSSO tema com
  #   o flavor trocado no meow.conf — consertar aquilo é o trabalho deste módulo,
  #   e perguntar "posso?" a cada troca de flavor seria pedir licença para fazer
  #   o que ela acabou de mandar fazer. Já um `current_theme` que o pack não
  #   conhece é trabalho que ELA fez à mão, e aí a pergunta é obrigatória.
  #
  #   Depois do `conferir` de propósito: quando tudo já está certo não há
  #   escrita nenhuma à frente, e anunciar "já está no tema do pack" ali em cima
  #   seria a mesma frase duas vezes na mesma passagem.
  #   O `pergunte` é o 5º argumento, e ele só existe neste caminho: a função
  #   não pergunta nada sem ele. É o que impede a pergunta de aparecer dentro de
  #   um `conferir`, que é leitura e não teria como cumprir o "sim" — ver o
  #   bloco do `meow_app_tema_no_ar` em lib/comum.sh.
  meow_app_tema_no_ar spotify "$(_spot_ini_ler current_theme)" \
                      "$_SPOT_TEMA_NOME" "$_SPOT_TEMA_DE" pergunte
  [ $? = "$MEOW_SEM_DEPENDENCIA" ] && return "$MEOW_SEM_DEPENDENCIA"

  if _spot_rodando; then
    meow_pula "Spotify está ABERTO — não mexo no app no meio do uso; tento no próximo ciclo"
    meow_info "a mudança só valeria no próximo início do Spotify de qualquer forma"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # A DIVERGÊNCIA DE VERSÃO NÃO É CONSERTADA AQUI, E É A DECISÃO MAIS IMPORTANTE
  # DESTE ARQUIVO. Depois de um `flatpak update` o backup do spicetify é da
  # versão velha; o conserto oficial (`restore` → `backup` → `apply`) tem um
  # passo que, feito na ordem errada ou na hora errada, copia a UI velha por
  # cima do app novo e dá janela em branco sem mensagem. Isso não pode acontecer
  # às 05:00 sem ninguém olhando. O doctor avisa e para; o comando fica escrito.
  local vb vi
  vb="$(_spot_ini_ler version)"; vi="$(_spot_versao)"
  if [ -n "$vb" ] && [ -n "$vi" ] && [ "$vb" != "$vi" ]; then
    meow_aviso "o Spotify atualizou ($vb -> $vi) e o backup do spicetify é da versão velha"
    meow_info "o tema do Spotify fica como está até o backup novo; o passo a passo está em scripts/temas-de-apps/spotify/RECUPERACAO.md"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local cli; cli="$(_spot_cli)"

  if meow_seco; then
    meow_muda "mudaria o Spotify para $_SPOT_TEMA_NOME/$_SPOT_ESQUEMA, do pack ${_SPOT_TEMA_DE:-ativo} (spicetify config + apply)"
    return "$MEOW_DIVERGENTE"
  fi

  # O acento é NOSSO e vai antes: o `apply` lê o color.ini já corrigido, então
  # não há um ciclo em que o app fique com o acento velho. Só que ele só é nosso
  # quando o pack pediu — ver "O ACENTO É OPCIONAL", no `meow_app_detectar`.
  if _spot_quer_acento; then
    meow_destino_permitido "$_SPOT_COLOR_INI" || return "$MEOW_ERRO"
    if ! python3 "$_SPOT_ACENTO_PY" aplicar "$_SPOT_COLOR_INI" \
          --flavor "$_SPOT_ESQUEMA" --acento "$_SPOT_ACENTO" >/dev/null; then
      meow_erro "não consegui pôr o acento $_SPOT_ACENTO no color.ini do tema '$_SPOT_TEMA_NOME'"
      return "$MEOW_ERRO"
    fi
  fi

  "$cli" config current_theme "$_SPOT_TEMA_NOME" >/dev/null 2>&1
  "$cli" config color_scheme "$_SPOT_ESQUEMA" >/dev/null 2>&1
  # Os quatro que o README do tema exige. `overwrite_assets` é o que faz o
  # spicetify tocar também o `login.spa` — ver item 2.
  "$cli" config inject_css 1 inject_theme_js 1 replace_colors 1 overwrite_assets 1 >/dev/null 2>&1

  local _saida
  if ! _saida="$("$cli" apply 2>&1)"; then
    meow_erro "o 'spicetify apply' falhou — o Spotify segue com o tema de antes"
    printf '%s\n' "$_saida" | tail -n 4 | sed 's/^/        /' >&2
    return "$MEOW_ERRO"
  fi

  meow_ok "Spotify em $_SPOT_TEMA_NOME/$_SPOT_ESQUEMA, do pack ${_SPOT_TEMA_DE:-ativo} (vale no próximo início do app)"
  return "$MEOW_DIVERGENTE"
}

# DESFAZER É DECISÃO DELA, DIGITADA — nada aqui é chamado pelo doctor das 05:00.
# `meow apps reverter spotify` chega aqui (bin/meow:1063 → aplicar_apps.sh:73).
meow_app_reverter() {
  # Mesma mentira do `aplicar`, mesmo conserto: o motivo vem de quem mediu.
  meow_app_detectar || { meow_app_pendente spotify; return; }
  if _spot_rodando; then
    meow_pula "Spotify está ABERTO — não mexo no app no meio do uso"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if meow_seco; then
    meow_muda "desfaria o tema '$_SPOT_TEMA_NOME' no Spotify (spicetify restore)"
    return "$MEOW_DIVERGENTE"
  fi

  # `restore` = "Remove all Spicetify modifications and restore Spotify to
  # vanilla state" (docs/cli/commands). Ele devolve o backup — e o backup só
  # vale para a versão de onde veio. Com as versões divergentes o resultado é
  # janela em branco, então aqui a recusa é a resposta certa.
  local vb vi
  vb="$(_spot_ini_ler version)"; vi="$(_spot_versao)"
  if [ -n "$vb" ] && [ -n "$vi" ] && [ "$vb" != "$vi" ]; then
    if _spot_backup_fresco; then
      # O backup é do app de agora; o número é que está velho. Carimbar antes de
      # restaurar é o que separa "recusar por precaução" de "recusar por engano".
      _spot_carimbar_versao >/dev/null
      if [ "$(_spot_ini_ler version)" != "$vi" ]; then
        meow_erro "não consegui corrigir o [Backup] version antes de restaurar"
        return "$MEOW_ERRO"
      fi
      meow_info "carimbo de versão corrigido ($vb -> $vi) — o backup é do app de agora, dá para restaurar"
    else
      meow_erro "o backup do spicetify é da versão $vb e o Spotify é a $vi — restaurar daria janela em branco"
      meow_info "a volta limpa é reinstalar o Spotify do flathub; o passo a passo está em scripts/temas-de-apps/spotify/RECUPERACAO.md"
      return "$MEOW_ERRO"
    fi
  fi

  local cli; cli="$(_spot_cli)"
  local _saida
  if ! _saida="$("$cli" restore 2>&1)"; then
    meow_erro "o 'spicetify restore' falhou — o Spotify segue com o tema do MeowSystem"
    printf '%s\n' "$_saida" | tail -n 4 | sed 's/^/        /' >&2
    return "$MEOW_ERRO"
  fi

  meow_ok "Spotify sem o tema do pack (vale no próximo início do app)"
  meow_info "tire 'spotify' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

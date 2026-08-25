#!/usr/bin/env bash
# app-themes/spotify/manifesto.sh — Catppuccin dentro do Spotify, VIA SPICETIFY.
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
#   máquina é de usuário e já era gravável: `nlink=1 modo=644 dono=vitoriamaria`.
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
_SPOT_PALETA="$MEOW_RAIZ/palette/catppuccin.json"

# De onde saem FLAVOR e ACCENT: do AMBIENTE, posto por quem chama (bin/meow,
# install.sh). Ler o meow.conf aqui dentro seria um segundo leitor da mesma conf,
# com precedência própria. A rede contra o valor errado é a checagem no
# `meow_app_detectar`, que também pega erro de digitação.
_SPOT_FLAVOR="${FLAVOR:-mocha}"
_SPOT_ACENTO="${ACCENT:-mauve}"

_SPOT_CONFIG_DIR="$HOME/.config/spicetify"
_SPOT_INI="$_SPOT_CONFIG_DIR/config-xpui.ini"
_SPOT_TEMA="$_SPOT_CONFIG_DIR/Themes/catppuccin"
_SPOT_COLOR_INI="$_SPOT_TEMA/color.ini"

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
  case ",$(_spot_ini_ler custom_apps | tr -d '[:space:]')," in
    *,marketplace,*) return 0 ;;
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

_spot_rodando() {
  if meow_tem flatpak && \
     flatpak ps --columns=application 2>/dev/null | grep -qx 'com.spotify.Client'; then
    return 0
  fi
  pgrep -x spotify >/dev/null 2>&1
}

_spot_receita_valida() {
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))["flavors"][sys.argv[2]][sys.argv[3]]' \
    "$_SPOT_PALETA" "$_SPOT_FLAVOR" "$_SPOT_ACENTO" 2>/dev/null
}

meow_app_detectar() {
  _spot_instalado || return "$MEOW_SEM_DEPENDENCIA"

  if ! _spot_cli >/dev/null; then
    meow_pula "spicetify não encontrado — o Spotify é tematizado por ele desde 10/08/2026"
    meow_info "instale: curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$_SPOT_COLOR_INI" ]; then
    meow_pula "o tema catppuccin não está em $_SPOT_TEMA"
    meow_info "instale: git clone --depth 1 https://github.com/catppuccin/spicetify /tmp/cat-spice && cp -r /tmp/cat-spice/catppuccin $_SPOT_CONFIG_DIR/Themes/"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  meow_tem python3 || return "$MEOW_SEM_DEPENDENCIA"
  [ -f "$_SPOT_ACENTO_PY" ] || return "$MEOW_SEM_DEPENDENCIA"
  if ! _spot_receita_valida; then
    meow_aviso "flavor/acento inexistentes na paleta: $_SPOT_FLAVOR/$_SPOT_ACENTO — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  # O spicetify precisa escrever no corpo do app. Se um dia isto virar
  # somente-leitura, o módulo tem de virar "pendente", não "erro".
  [ -w "$(_spot_dir)/Apps" ] || return "$MEOW_SEM_DEPENDENCIA"
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
    _spot_receita_valida || \
      meow_aviso "flavor/acento inexistentes na paleta: $_SPOT_FLAVOR/$_SPOT_ACENTO — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  local tema esquema acento_ok hex colors
  tema="$(_spot_ini_ler current_theme)"
  esquema="$(_spot_ini_ler color_scheme)"

  [ "$tema" = "catppuccin" ] || return "$MEOW_DIVERGENTE"
  [ "$esquema" = "$_SPOT_FLAVOR" ] || return "$MEOW_DIVERGENTE"

  acento_ok="$(python3 "$_SPOT_ACENTO_PY" estado "$_SPOT_COLOR_INI" \
                 --flavor "$_SPOT_FLAVOR" --acento "$_SPOT_ACENTO" 2>/dev/null)" || {
    meow_erro "não consegui ler o color.ini do tema catppuccin"
    return "$MEOW_ERRO"
  }
  hex="$(printf '%s\n' "$acento_ok" | sed -n 's/^desejado=//p')"
  printf '%s\n' "$acento_ok" | grep -qx 'ok=sim' || return "$MEOW_DIVERGENTE"

  # (3) O RESULTADO NO DISCO. Sem esta parte o doctor aprovaria uma intenção
  # perfeita num Spotify que voltou ao normal depois de um `flatpak update`.
  colors="$(_spot_dir)/Apps/xpui/colors.css"
  if [ ! -f "$colors" ]; then
    meow_aviso "o Spotify no disco não tem o tema aplicado (o spicetify foi desfeito, ou o app atualizou)"
    return "$MEOW_DIVERGENTE"
  fi
  grep -qi -- "--spice-text: *#\?${hex}" "$colors" || return "$MEOW_DIVERGENTE"

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
    meow_aviso "o backup do spicetify é da versão $vb e o Spotify é a $vi — veja app-themes/spotify/RECUPERACAO.md"
  fi

  meow_ok "Spotify em Catppuccin $_SPOT_FLAVOR/$_SPOT_ACENTO (via spicetify)"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  meow_app_detectar || {
    meow_pula "Spotify não instalado (ou não é o flatpak de usuário)"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  # O CARIMBO VEM ANTES DE TUDO, E PODE ACONTECER COM O SPOTIFY ABERTO.
  # Ele não toca num byte do app — corrige uma linha do config-xpui.ini. É a
  # única parte deste módulo que a guarda "não mexo no app dela no meio do uso"
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
    0) [ "$mexi" = "1" ] && return "$MEOW_DIVERGENTE"
       meow_ok "Spotify já está em Catppuccin $_SPOT_FLAVOR/$_SPOT_ACENTO — nada a fazer"
       return "$MEOW_OK" ;;
    3) meow_pula "Spotify: nada a fazer (veja o aviso do conferir)"
       return "$MEOW_SEM_DEPENDENCIA" ;;
    2) return "$MEOW_ERRO" ;;
  esac

  if _spot_rodando; then
    meow_pula "Spotify está ABERTO — não mexo no app dela no meio do uso; tento no próximo ciclo"
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
    meow_info "não conserto sozinho: leia app-themes/spotify/RECUPERACAO.md e rode na mão"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local cli; cli="$(_spot_cli)"

  if meow_seco; then
    meow_muda "mudaria o Spotify para Catppuccin $_SPOT_FLAVOR/$_SPOT_ACENTO (spicetify config + apply)"
    return "$MEOW_DIVERGENTE"
  fi

  # O acento é NOSSO e vai antes: o `apply` lê o color.ini já corrigido, então
  # não há um ciclo em que o app fique com o acento velho.
  meow_destino_permitido "$_SPOT_COLOR_INI" || return "$MEOW_ERRO"
  if ! python3 "$_SPOT_ACENTO_PY" aplicar "$_SPOT_COLOR_INI" \
        --flavor "$_SPOT_FLAVOR" --acento "$_SPOT_ACENTO" >/dev/null; then
    meow_erro "não consegui pôr o acento $_SPOT_ACENTO no color.ini do tema"
    return "$MEOW_ERRO"
  fi

  "$cli" config current_theme catppuccin >/dev/null 2>&1
  "$cli" config color_scheme "$_SPOT_FLAVOR" >/dev/null 2>&1
  # Os quatro que o README do tema exige. `overwrite_assets` é o que faz o
  # spicetify tocar também o `login.spa` — ver item 2.
  "$cli" config inject_css 1 inject_theme_js 1 replace_colors 1 overwrite_assets 1 >/dev/null 2>&1

  if ! "$cli" apply >/dev/null 2>&1; then
    meow_erro "o 'spicetify apply' falhou — rode na mão para ver o motivo: $cli apply"
    return "$MEOW_ERRO"
  fi

  meow_ok "Spotify em Catppuccin $_SPOT_FLAVOR/$_SPOT_ACENTO (vale no próximo início do app)"
  return "$MEOW_DIVERGENTE"
}

# DESFAZER É DECISÃO DELA, DIGITADA — nada aqui é chamado pelo doctor das 05:00.
# `meow apps reverter spotify` chega aqui (bin/meow:1063 → aplicar_apps.sh:73).
meow_app_reverter() {
  meow_app_detectar || {
    meow_pula "Spotify não instalado (ou não é o flatpak de usuário)"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  if _spot_rodando; then
    meow_pula "Spotify está ABERTO — não mexo no app dela no meio do uso"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if meow_seco; then
    meow_muda "desfaria o Catppuccin no Spotify (spicetify restore)"
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
      meow_info "leia app-themes/spotify/RECUPERACAO.md; a volta limpa é 'flatpak install --user --reinstall flathub com.spotify.Client'"
      return "$MEOW_ERRO"
    fi
  fi

  local cli; cli="$(_spot_cli)"
  if ! "$cli" restore >/dev/null 2>&1; then
    meow_erro "o 'spicetify restore' falhou — rode na mão para ver o motivo: $cli restore"
    return "$MEOW_ERRO"
  fi

  meow_ok "Spotify sem o Catppuccin (vale no próximo início do app)"
  meow_info "tire 'spotify' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

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

  # A versão do backup do spicetify tem de ser a do Spotify instalado. Se
  # divergirem, restaurar produz janela em branco SEM mensagem de erro — é o
  # modo de falhar mais difícil de diagnosticar que existe aqui, e por isso ele
  # é avisado no `conferir` e não só na hora do desastre.
  local vb vi
  vb="$(_spot_ini_ler version)"; vi="$(_spot_versao)"
  if [ -n "$vb" ] && [ -n "$vi" ] && [ "$vb" != "$vi" ]; then
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
  meow_app_conferir >/dev/null 2>&1
  case $? in
    0) meow_ok "Spotify já está em Catppuccin $_SPOT_FLAVOR/$_SPOT_ACENTO — nada a fazer"
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
    meow_erro "o backup do spicetify é da versão $vb e o Spotify é a $vi — restaurar daria janela em branco"
    meow_info "leia app-themes/spotify/RECUPERACAO.md; a volta limpa é 'flatpak install --user --reinstall flathub com.spotify.Client'"
    return "$MEOW_ERRO"
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

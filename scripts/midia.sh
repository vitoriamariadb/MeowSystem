#!/usr/bin/env bash
# midia.sh — põe o applet de mídia patchado no lugar do que veio do flatpak.
#
#   ./midia.sh --conferir   não escreve; 1 se algo divergir
#   ./midia.sh              instala a sombra e as chaves
#   ./midia.sh --reverter   tira tudo e devolve o applet do flatpak
#
# O QUE É A "SOMBRA", E POR QUE ELA É O CORAÇÃO DESTA SOLUÇÃO
#   O cosmic-panel acha os applets pelo BASENAME do `.desktop`, varrendo os
#   diretórios do XDG na ordem padrão — e `$XDG_DATA_HOME` (aqui
#   `~/.local/share`) vem ANTES de todo `XDG_DATA_DIRS`, inclusive do
#   `~/.local/share/flatpak/exports/share` de onde sai o applet dela hoje.
#   Escrever um `.desktop` de MESMO NOME em `~/.local/share/applications` faz o
#   painel usar o NOSSO `Exec=` sem que ninguém encoste em `plugins_wings`.
#
#   Isso importa porque `plugins_wings` é território da Aurora (docs/FRONTEIRA.md)
#   e a asa direita da dock tem DOIS applets — o Now Playing e a Status Area.
#   Um script que assumisse "a asa é uma lista de um" apagaria a Status Area dela.
#   Aqui não se escreve nesse arquivo. Nem uma vez.
#
# O FAIL-SAFE, QUE É O PIOR MODO DE FALHA DESTA FAMÍLIA
#   Sombra presente + binário ausente = NENHUM applet na dock. O painel casa
#   pelo basename e CONSOME o slot no primeiro acerto: ele nunca chega a tentar
#   o export do flatpak, e ela fica com um BURACO — não com o applet de fábrica.
#   Acontece de graça: um `rm` errado, um BleachBit, um disco cheio no meio de
#   um build. Por isso a regra: quando o binário some, o `--aplicar` REMOVE a
#   sombra. É um `rm` de arquivo nosso, sem sudo e sem rede — o doctor pode
#   fazer, e o efeito é ela voltar sozinha ao flatpak que funciona.
#
# O PROCESSO EM EXECUÇÃO É AVISO, NUNCA DIVERGÊNCIA
#   Trocar o `.desktop` não troca o processo: o applet novo sobe no PRÓXIMO
#   LOGIN. Entre a instalação e o login, `pgrep` acha o do flatpak. Tratar isso
#   como divergência criaria uma linha amarela que o `--consertar` não consegue
#   apagar — exatamente a tranca que o módulo do Spotify acabou de perder
#   (app-themes/spotify/manifesto.sh, o carimbo de versão). Aviso diz a verdade
#   e não mente sobre poder consertar.
#
# NÃO REINICIAMOS O cosmic-panel PARA ANTECIPAR
#   A issue #13 do upstream (`xdg_popup: tried to grab after being mapped`)
#   derruba topbar e dock juntas e exige `killall -9`. É o painel fantasma que
#   este projeto já perseguiu uma vez. Cinco minutos de antecipação não pagam.
#
# `album-color-enabled` NÃO É NOSSO
#   É a chave que ela liga e desliga pelo popup do próprio applet. Este script
#   MIGRA o valor de dentro do sandbox do flatpak para `~/.config` uma única vez
#   (senão a escolha dela sumiria na troca) e nunca mais encosta. Enforçá-la
#   seria o doctor desfazendo às 05:00 o que ela clicou às 22:00.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta dependência
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

APP_ID="com.github.DiegoMMR.CosmicExtAppletNowPlaying"
BINARIO="$HOME/.local/bin/meow-applet-now-playing"
SOMBRA="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$APP_ID.desktop"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic-ext-applet-now-playing"
SANDBOX="$HOME/.var/app/$APP_ID/config/cosmic-ext-applet-now-playing"
ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/midia"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/cosmic-ext-applet-now-playing"

MIDIA="${MIDIA:-sim}"
LARGURA="${MIDIA_LARGURA:-440}"
COR="${MIDIA_COR_ALBUM:-traco}"
CAPA="${MIDIA_CAPA:-sim}"
FONTE="${MIDIA_FONTE:-auto}"
COR_TITULO="${MIDIA_COR_TITULO:-mauve}"
COR_ARTISTA="${MIDIA_COR_ARTISTA:-green}"
CONTROLES="${MIDIA_CONTROLES:-nao}"
_FLAVOR="${FLAVOR:-mocha}"
PALETA="$RAIZ/palette/catppuccin.json"

CONFERIR=0; REVERTER=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --reverter) REVERTER=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$REVERTER" = 0 ] && CONFERIR=1

# --- o que queremos no disco -------------------------------------------------
# O `.desktop` mantém o BASENAME e o `Icon=` do flatpak: o painel casa pelo
# nome do arquivo, e o ícone continua resolvendo pelo export do flatpak, que
# segue instalado. Só o `Exec=` muda, e vai em caminho ABSOLUTO — o painel não
# herda o PATH do shell dela.
_texto_sombra() {
  cat <<EOF
[Desktop Entry]
Name=Now Playing
Exec=$BINARIO
Terminal=false
Type=Application
StartupNotify=true
Icon=$APP_ID
Categories=AudioVideo;Utility;
Keywords=Music;Media;Now Playing;
NoDisplay=true
X-CosmicApplet=true
X-CosmicHoverPopup=Auto
EOF
}

# Recusa valor inválido em vez de gravá-lo: uma largura de 5000 sairia do
# clamp do applet e voltaria ao padrão sem nada avisar, e a conferência
# gritaria divergência para sempre.
_largura_valida() {
  case "$LARGURA" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$LARGURA" -ge 80 ] && [ "$LARGURA" -le 900 ]
}

_cor_valida() { [ "$COR" = "traco" ] || [ "$COR" = "chapado" ]; }

_capa_valida() { [ "$CAPA" = "sim" ] || [ "$CAPA" = "nao" ]; }
_controles_valido() { [ "$CONTROLES" = "sim" ] || [ "$CONTROLES" = "nao" ]; }

_capa_valor() { [ "$CAPA" = "sim" ] && printf 'true' || printf 'false'; }

# NOME DA PALETA -> HEX. Quem traduz é AQUI, não o applet: a paleta
# (`palette/catppuccin.json`) é do MeowSystem, e embutir uma cópia dela no Rust
# criaria a segunda verdade que discorda no dia em que ela trocar de flavor.
# `auto` viaja como a palavra `auto`, e o applet a rejeita no teste de hex —
# então "auto" quer dizer "não pinte", sem precisar apagar arquivo nenhum.
_cor_hex() {
  local nome="$1"
  [ "$nome" = "auto" ] && { printf 'auto'; return 0; }
  python3 -c '
import json, sys
try:
    p = json.load(open(sys.argv[1]))["flavors"][sys.argv[2]]
except Exception:
    sys.exit(1)
v = p.get(sys.argv[3])
if not isinstance(v, str) or not v.startswith("#"):
    sys.exit(1)
print(v.lower())
' "$PALETA" "$_FLAVOR" "$nome" 2>/dev/null
}

_cor_nome_valido() { [ -n "$(_cor_hex "$1")" ]; }

# `auto` = a escala tipográfica do painel (a mesma do relógio). Número = px.
_fonte_valida() {
  [ "$FONTE" = "auto" ] && return 0
  case "$FONTE" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$FONTE" -ge 6 ] && [ "$FONTE" -le 48 ]
}

# nome-do-arquivo <TAB> conteúdo desejado
_chaves() {
  printf '%s\t%s\n' panel-text-width   "$LARGURA"
  printf '%s\t%s\n' panel-color-style  "$COR"
  printf '%s\t%s\n' album-art-remote   "$(_capa_valor)"
  printf '%s\t%s\n' panel-font-size    "$FONTE"
  printf '%s\t%s\n' panel-title-color  "$(_cor_hex "$COR_TITULO")"
  printf '%s\t%s\n' panel-artist-color "$(_cor_hex "$COR_ARTISTA")"
  printf '%s\t%s\n' panel-controls     "$([ "$CONTROLES" = "sim" ] && printf true || printf false)"
}

_pronto() {
  if ! _largura_valida; then
    meow_aviso "MIDIA_LARGURA=\"$LARGURA\" fora de 80..900 — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _cor_valida; then
    meow_aviso "MIDIA_COR_ALBUM=\"$COR\" não existe (use traco ou chapado) — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  # Sem esta porta, um valor estranho caía no `else` do `_capa_valor` e
  # DESLIGAVA a capa em silêncio — a queixa dela voltaria por um erro de
  # digitação, sem nada na tela dizendo por quê.
  if ! _capa_valida; then
    meow_aviso "MIDIA_CAPA=\"$CAPA\" não existe (use sim ou nao) — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _controles_valido; then
    meow_aviso "MIDIA_CONTROLES=\"$CONTROLES\" não existe (use sim ou nao) — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _fonte_valida; then
    meow_aviso "MIDIA_FONTE=\"$FONTE\" não serve (use auto ou 6..48) — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  local c
  for c in "$COR_TITULO" "$COR_ARTISTA"; do
    if ! _cor_nome_valido "$c"; then
      meow_aviso "a cor \"$c\" não existe na paleta $_FLAVOR — confira o meow.conf"
      meow_info "  nomes válidos: os do palette/catppuccin.json (mauve, green, blue, peach…), ou auto"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
  done
  return "$MEOW_OK"
}

# --- conferência (leitura pura) ---------------------------------------------
_conferir() {
  # (1) O FAIL-SAFE vem primeiro, porque é o estado que deixa a dock vazia.
  if [ -f "$SOMBRA" ] && [ ! -x "$BINARIO" ]; then
    meow_muda "a sombra do applet existe e o binário não — a dock ficaria SEM applet nenhum"
    return "$MEOW_DIVERGENTE"
  fi

  if [ ! -x "$BINARIO" ]; then
    meow_pula "o applet de mídia ainda não foi compilado — nada a instalar ainda"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # (2) A sombra, comparada por CONTEÚDO e não com `cmp`. O `meow_escrever`
  # grava com `printf '%s'` e come o `\n` final: um `cmp` acusaria divergência
  # para sempre num arquivo perfeito. Esse erro já custou a este projeto um
  # `--conferir` gritando 123 divergências num tema correto.
  if [ ! -f "$SOMBRA" ] || [ "$(_texto_sombra)" != "$(cat "$SOMBRA" 2>/dev/null)" ]; then
    meow_muda "a sombra do applet de mídia não está no lugar ($SOMBRA)"
    return "$MEOW_DIVERGENTE"
  fi

  # (3) As chaves.
  local nome valor
  while IFS=$'\t' read -r nome valor; do
    [ -f "$CONFIG/$nome" ] || { meow_muda "falta a chave $nome do applet de mídia"; return "$MEOW_DIVERGENTE"; }
    [ "$(cat "$CONFIG/$nome" 2>/dev/null)" = "$valor" ] || {
      meow_muda "a chave $nome do applet de mídia diz '$(cat "$CONFIG/$nome")' e devia dizer '$valor'"
      return "$MEOW_DIVERGENTE"
    }
  done <<< "$(_chaves)"

  # (4) A escolha dela sobre a cor, migrada uma vez do sandbox do flatpak.
  if [ -f "$SANDBOX/album-color-enabled" ] && [ ! -f "$CONFIG/album-color-enabled" ]; then
    meow_muda "a preferência de cor de álbum dela ainda está dentro do sandbox do flatpak"
    return "$MEOW_DIVERGENTE"
  fi

  # (5) Aviso, nunca divergência — ver o cabeçalho.
  # `-fx`, e NÃO `-x`. MEDIDO em 24/08/2026: `cosmic-ext-applet-now-playing` tem
  # 29 caracteres e o `-x` compara com o `comm`, que o kernel corta em 15 — o
  # pgrep até avisa ("vai resultar em zero correspondências"), mas para stderr,
  # dentro de um `2>/dev/null`. O ramo inteiro era código morto: nunca casava,
  # então nunca avisava. Um aviso que não dispara é pior que aviso nenhum,
  # porque o silêncio dele é lido como "está tudo bem".
  if ! pgrep -f "$BINARIO" >/dev/null 2>&1 \
     && pgrep -fx cosmic-ext-applet-now-playing >/dev/null 2>&1; then
    meow_aviso "quem está rodando ainda é o applet do flatpak — o nosso sobe no próximo login"
  fi

  meow_ok "applet de mídia no lugar (largura $LARGURA, fonte $FONTE, cor $COR, título $COR_TITULO, artista $COR_ARTISTA)"
  return "$MEOW_OK"
}

# --- aplicação ---------------------------------------------------------------
_aplicar() {
  local mudou=0 rc

  # O FAIL-SAFE é a única coisa que roda mesmo sem binário, e ele REMOVE.
  if [ -f "$SOMBRA" ] && [ ! -x "$BINARIO" ]; then
    if meow_seco; then
      meow_muda "removeria a sombra órfã $SOMBRA (o binário sumiu)"
      return "$MEOW_DIVERGENTE"
    fi
    rm -f "$SOMBRA"
    meow_aviso "a sombra estava órfã e foi removida — o applet do flatpak volta no próximo login"
    meow_info "  para ter o nosso de volta: MIDIA_COMPILAR=1 $RAIZ/scripts/midia_build.sh"
    return "$MEOW_DIVERGENTE"
  fi

  if [ ! -x "$BINARIO" ]; then
    meow_pula "o applet de mídia ainda não foi compilado — nada a instalar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # A ORDEM IMPORTA: chaves e migração ANTES da sombra. Se a sombra entrasse
  # primeiro e a escrita das chaves falhasse, o próximo login subiria o applet
  # novo com os padrões de fábrica, e ela veria a mudança errada.
  local nome valor
  while IFS=$'\t' read -r nome valor; do
    meow_escrever "$CONFIG/$nome" "$valor" 644
    rc=$?
    case $rc in
      1) mudou=1 ;;
      2) meow_erro "não consegui escrever $CONFIG/$nome"; return "$MEOW_ERRO" ;;
    esac
  done <<< "$(_chaves)"

  if [ -f "$SANDBOX/album-color-enabled" ] && [ ! -f "$CONFIG/album-color-enabled" ]; then
    meow_escrever "$CONFIG/album-color-enabled" "$(cat "$SANDBOX/album-color-enabled")" 644
    case $? in
      1) mudou=1; meow_seco || meow_info "a preferência de cor de álbum dela veio do sandbox do flatpak" ;;
      2) meow_erro "não consegui migrar album-color-enabled"; return "$MEOW_ERRO" ;;
    esac
  fi

  meow_escrever "$SOMBRA" "$(_texto_sombra)" 644
  rc=$?
  case $rc in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $SOMBRA"; return "$MEOW_ERRO" ;;
  esac

  if meow_seco; then
    [ "$mudou" = 1 ] && return "$MEOW_DIVERGENTE"
    meow_ok "applet de mídia já estava no lugar"
    return "$MEOW_OK"
  fi

  if [ "$mudou" = 0 ]; then
    meow_ok "applet de mídia já estava no lugar (largura $LARGURA, fonte $FONTE, título $COR_TITULO, artista $COR_ARTISTA)"
    return "$MEOW_OK"
  fi
  if [ "$CONTROLES" = "sim" ]; then
    meow_ok "applet de mídia instalado: capa, nome e ⏮⏸⏭ na barra (vale no próximo login)"
  else
    meow_ok "applet de mídia instalado: capa e nome na barra; os ⏮⏸⏭ são os do applet de Som"
  fi
  return "$MEOW_DIVERGENTE"
}

# --- reversão ----------------------------------------------------------------
# A ORDEM É A METADE DO VALOR: a sombra sai PRIMEIRO, para que o flatpak
# reassuma o slot; só depois o binário. O contrário abriria a janela em que a
# dock fica sem applet nenhum — o mesmo buraco que o fail-safe existe para tapar.
_reverter() {
  local mexeu=0
  if meow_seco; then
    [ -f "$SOMBRA" ]  && { meow_muda "removeria a sombra $SOMBRA"; mexeu=1; }
    [ -e "$BINARIO" ] && { meow_muda "removeria o binário $BINARIO"; mexeu=1; }
    [ -d "$ESTADO" ]  && { meow_muda "removeria a árvore de build $ESTADO"; mexeu=1; }
    [ "$mexeu" = 1 ] && return "$MEOW_DIVERGENTE"
    meow_pula "não há applet de mídia nosso para remover"
    return "$MEOW_OK"
  fi

  [ -f "$SOMBRA" ] && { rm -f "$SOMBRA"; mexeu=1; }
  [ -e "$BINARIO" ] && { rm -f "$BINARIO"; mexeu=1; }
  [ -d "$ESTADO" ] && { rm -rf "$ESTADO"; mexeu=1; }
  [ -d "$CACHE" ] && { rm -rf "$CACHE"; mexeu=1; }
  # As chaves ficam: são preferência dela, e o applet do flatpak não as lê.
  # Apagá-las faria uma reinstalação perder a largura e a cor que ela escolheu.

  if [ "$mexeu" = 0 ]; then
    meow_pula "não havia applet de mídia nosso para remover"
    return "$MEOW_OK"
  fi
  meow_ok "applet de mídia removido — o do flatpak volta no próximo login"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$REVERTER" = 1 ] && { _reverter; return $?; }
  if [ "$MIDIA" != "sim" ]; then
    # Desligar tem de DESLIGAR. Deixar de instalar manteria de pé a sombra que
    # uma execução anterior escreveu, e o sintoma seria "desliguei e continua",
    # que é o pior de todos porque não há onde olhar.
    if [ -f "$SOMBRA" ] || [ -x "$BINARIO" ]; then
      meow_muda "MIDIA=\"$MIDIA\" no meow.conf, mas o applet nosso continua instalado"
      [ "$CONFERIR" = 1 ] && return "$MEOW_DIVERGENTE"
      _reverter; return $?
    fi
    meow_pula "MIDIA=\"$MIDIA\" no meow.conf — o applet de mídia fica com o do flatpak"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

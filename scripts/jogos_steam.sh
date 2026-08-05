#!/usr/bin/env bash
# jogos_steam.sh — as capas dos jogos dela de volta, na área de trabalho E no lançador.
#
# ONDE ELAS ESTAVAM, E POR QUE NÃO APARECIAM
#   A Steam cria um `.desktop` por jogo na ÁREA DE TRABALHO quando ela pede
#   "criar atalho" — oito, aqui. Os ícones existem (`steam_icon_<appid>` no
#   hicolor do usuário), os arquivos existem, e mesmo assim a tela estava vazia.
#
#   Duas causas independentes, e as duas precisavam cair:
#
#   1. `~/.local/share/icons/hicolor/index.theme` declarava quatro tamanhos e a
#      pasta tinha treze. Dois jogos só existiam em `32x32` e eram invisíveis
#      para o resolvedor. Isso é do `scripts/hicolor.sh`, e já está resolvido.
#
#   2. `com.system76.CosmicFiles/v1/desktop` tinha `show_content: false` — a área
#      de trabalho do COSMIC não desenhava arquivo NENHUM. Com essa chave
#      desligada, consertar ícone não adianta: não há onde ele aparecer.
#
# POR QUE TAMBÉM NO LANÇADOR
#   A área de trabalho fica coberta por janela quase o tempo todo numa máquina de
#   uma tela só. O lançador é onde ela procura programa. Os `.desktop` da Steam
#   ficam na área de trabalho e por isso NUNCA estiveram no lançador — não é
#   defeito, é onde a Steam os põe. Copiar para `~/.local/share/applications` os
#   coloca nos dois lugares, e a cópia é nossa: se ela apagar o atalho da área de
#   trabalho, o do lançador continua.
#
# O ÍCONE FICA NATURAL, A PEDIDO DELA
#   Nada de tematizar: a capa que a Steam baixou é a arte do jogo, e trocá-la por
#   um desenho na paleta tornaria oito jogos indistinguíveis entre si. Este script
#   não escreve ícone nenhum — só garante que o que já existe seja alcançável.
#
# O NOME DO ARQUIVO É NORMALIZADO, O NOME NA TELA NÃO
#   O destino é `steam-<appid>.desktop`, não "ORPHEUS TO HELL AND BACK.desktop".
#   O appid é estável; o título do atalho ela pode renomear a qualquer momento, e
#   aí a cópia antiga viraria uma segunda entrada no lançador — exatamente a
#   duplicata que o `ocultar_apps.sh` existe para evitar. O `Name=` de dentro do
#   arquivo é copiado como está, então na tela continua o nome do jogo.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

APPS="$HOME/.local/share/applications"
CFG="$HOME/.config/cosmic/com.system76.CosmicFiles/v1/desktop"

# `xdg-user-dir` porque o nome da pasta segue o idioma: aqui é "Área de trabalho",
# noutra máquina é "Desktop". Cravar qualquer um dos dois é escolher em qual
# máquina o script funciona.
if meow_tem xdg-user-dir; then
  MESA="$(xdg-user-dir DESKTOP 2>/dev/null)"
else
  MESA=""
fi
[ -n "$MESA" ] && [ -d "$MESA" ] || MESA="$HOME/Área de trabalho"

mudou=0

# --- 1. a área de trabalho precisa desenhar alguma coisa ---------------------
# Substituição cirúrgica de UMA chave dentro do RON. Reescrever o bloco inteiro
# levaria junto `grid_spacing`, `icon_size` e os dois `show_*` restantes — que são
# escolhas dela, e das quais este script não sabe nada.
if [ -f "$CFG" ]; then
  if grep -q 'show_content: *false' "$CFG"; then
    novo="$(sed 's/show_content: *false/show_content: true/' "$CFG")"
    if meow_seco; then
      meow_muda "ligaria os ícones na área de trabalho (show_content)"
      mudou=1
    else
      meow_escrever "$CFG" "$novo" 644
      case $? in
        1) mudou=1; meow_ok "área de trabalho passa a mostrar os arquivos" ;;
        2) meow_erro "não consegui escrever $CFG"; exit "$MEOW_ERRO" ;;
      esac
    fi
  fi
else
  meow_pula "cosmic-files ainda não tem configuração — área de trabalho não tocada"
fi

# --- 2. os atalhos de jogo, da mesa para o lançador --------------------------
if [ ! -d "$MESA" ]; then
  meow_pula "não achei a área de trabalho ($MESA)"
  [ "$mudou" = "1" ] && exit "$MEOW_DIVERGENTE"
  exit "$MEOW_OK"
fi

copiados=0
achados=0
while IFS= read -r arq; do
  # `steam://rungameid/` é o que distingue um atalho de JOGO de qualquer outro
  # .desktop que ela tenha largado na mesa. Casar por `Icon=steam_icon_` deixaria
  # de fora o jogo cujo ícone a Steam não baixou (aqui, o "Scarlet Deer Inn",
  # que usa o ícone genérico) — e ele é um jogo como os outros.
  id="$(grep -m1 -oP 'steam://rungameid/\K[0-9]+' "$arq" 2>/dev/null)" || continue
  [ -n "$id" ] || continue
  achados=$((achados + 1))

  destino="$APPS/steam-$id.desktop"
  meow_escrever "$destino" "$(cat "$arq")" 644
  case $? in
    1) mudou=1; copiados=$((copiados + 1)) ;;
    2) meow_erro "não consegui instalar $(basename "$arq")"; exit "$MEOW_ERRO" ;;
  esac
done < <(find "$MESA" -maxdepth 1 -type f -name '*.desktop' 2>/dev/null | sort)

if [ "$achados" -eq 0 ]; then
  meow_pula "nenhum atalho de jogo da Steam na área de trabalho"
  [ "$mudou" = "1" ] && exit "$MEOW_DIVERGENTE"
  exit "$MEOW_OK"
fi

if [ "$mudou" = "0" ]; then
  meow_ok "$achados jogo(s) da Steam já no lançador e na área de trabalho"
  exit "$MEOW_OK"
fi

meow_seco && { meow_muda "levaria $achados jogo(s) da Steam para o lançador"; exit "$MEOW_DIVERGENTE"; }

# `update-desktop-database` só vale para o diretório do USUÁRIO aqui — sem sudo,
# sem tocar em /usr/share. Se não existir, o lançador acha do mesmo jeito na
# próxima varredura; a base é um índice de MIME, não a lista de aplicativos.
meow_tem update-desktop-database && update-desktop-database "$APPS" 2>/dev/null || true

[ "$copiados" -gt 0 ] && meow_ok "$copiados jogo(s) da Steam no lançador (ícone natural, como ela pediu)"
meow_info "os da área de trabalho aparecem assim que o cosmic-files reler"
exit "$MEOW_DIVERGENTE"

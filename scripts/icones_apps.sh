#!/usr/bin/env bash
# icones_apps.sh — os ícones do LANÇADOR, em Catppuccin.
#
# POR QUE ESTE SCRIPT NÃO USA O PACK DO catppuccin/vscode-icons
#   Ela pediu, textualmente, que os ícones do lançador virassem os do pack
#   Catppuccin que ela mandou. Medido: aquele pack não tem UM ícone de
#   aplicativo — os 656 glifos são de linguagem e formato de arquivo, e o único
#   nome de programa lá é `figma`, que ela não usa. Trocar o lançador por ele
#   deixaria a tela vazia. Aquele pack foi para `mimetypes/`, onde ele brilha
#   (ver icones_mimetypes.sh); o lançador precisava de outra fonte.
#
# A FONTE QUE SERVE, E POR QUE ELA SÓ FICOU DISPONÍVEL AGORA
#   `Daveedmee/catppuccin-icons` são as formas conhecidas de cada marca
#   recoloridas na paleta — Firefox em pêssego, Discord em azul-céu, Spotify em
#   verde pastel. Uma pesquisa anterior o DESCARTOU por não ter licença, o que
#   impediria redistribuir num repositório GPL-3. Em 05/08/2026 ela decidiu que o
#   projeto não será publicado: sem redistribuição, o impedimento deixa de
#   existir para uso nesta máquina. O que continua valendo está no cabeçalho de
#   icons/apps.map, e vale a pena reler antes de mudar de ideia sobre publicar.
#
# PNG, NÃO SVG — E A ESCOLHA É MEDIDA
#   O acervo entrega `.ico` de 256x256 a 24 bits por pixel, ou seja SEM canal
#   alpha: usados assim, os ícones virariam quadrados sólidos sobre o papel de
#   parede. Os PNG de 512x512 da pasta de preview têm alpha (conferido:
#   `%[channels]` = srgba, canto = rgba(0,0,0,0)) e é isso que se instala. Como
#   são raster, vão para `512x512/apps` e NUNCA para `scalable/` — meter raster
#   dentro de um diretório declarado como escalável é o defeito que o
#   thunderbird.png já cometeu neste tema.
#
# CÓDIGOS DE SAÍDA
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta o acervo
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

FLAVOR_ICONES="${ICONES_FLAVOR:-macchiato}"
# O acervo só tem duas variantes: dark=Macchiato, light=Latte. Frappé e Mocha
# caem no vizinho mais próximo em claridade, e o script DIZ que fez isso.
case "$FLAVOR_ICONES" in
  latte) VARIANTE="latte" ;;
  macchiato) VARIANTE="macchiato" ;;
  frappe|mocha) VARIANTE="macchiato"; APROXIMOU="$FLAVOR_ICONES" ;;
  *) VARIANTE="macchiato"; APROXIMOU="$FLAVOR_ICONES" ;;
esac

ORIGEM="$RAIZ/icons/catppuccin-apps/$VARIANTE"
MAPA="$RAIZ/icons/apps.map"
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
DESTINO="$HOME/.local/share/icons/$TEMA/512x512/apps"

# Pedido expresso dela: estes ficam como estão, venha o que vier.
INTOCAVEIS_PREFIXO=(steam_icon_)
INTOCAVEIS=(fogstripper hefesto-dualsense4unix com.vitoriamaria.HefestoDualsense4Unix)

intocavel() {
  local n="$1" i
  for i in "${INTOCAVEIS[@]}"; do [ "$n" = "$i" ] && return 0; done
  for i in "${INTOCAVEIS_PREFIXO[@]}"; do case "$n" in "$i"*) return 0 ;; esac; done
  return 1
}

declare -A MAPA_LIDO=()
_ler_mapa() {
  local linha nome arq
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"; arq="${linha#*:}"
    [ -n "$nome" ] && [ -n "$arq" ] || continue
    intocavel "$nome" && continue
    MAPA_LIDO["$nome"]="$arq"
  done < "$MAPA"
}

_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "o acervo Catppuccin de aplicativos não está em icons/catppuccin-apps/$VARIANTE"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  [ -f "$MAPA" ] || { meow_pula "sem icons/apps.map — nada a vestir"; return "$MEOW_SEM_DEPENDENCIA"; }
  return "$MEOW_OK"
}

_desejado() {
  local nome arq
  for nome in "${!MAPA_LIDO[@]}"; do
    arq="${MAPA_LIDO[$nome]}"
    [ -f "$ORIGEM/$arq.png" ] && printf '%s\t%s\n' "$nome" "$ORIGEM/$arq.png"
  done
}

# Mesma disciplina do icones_mimetypes.sh: compara como o escritor escreve. Aqui
# o conteúdo é binário, então a comparação é `cmp` — e a escrita é `cp`, não
# `meow_escrever`, justamente para que os dois falem a mesma língua.
_conferir() {
  local nome origem faltam=0 diferem=0 orfaos=0 total=0 arq
  while IFS=$'\t' read -r nome origem; do
    total=$((total + 1))
    if [ ! -f "$DESTINO/$nome.png" ]; then faltam=$((faltam + 1))
    elif ! cmp -s "$origem" "$DESTINO/$nome.png"; then diferem=$((diferem + 1))
    fi
  done < <(_desejado)
  if [ -d "$DESTINO" ]; then
    for arq in "$DESTINO"/*.png; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .png)"
      [ -n "${MAPA_LIDO[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  fi
  if [ "$faltam" = 0 ] && [ "$diferem" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total aplicativos já com ícone Catppuccin ${APROXIMOU:+($APROXIMOU aproximado para $VARIANTE)}"
    return "$MEOW_OK"
  fi
  meow_muda "aplicativos: $faltam a instalar, $diferem a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local nome origem arq mudou=0 postos=0 removidos=0
  while IFS=$'\t' read -r nome origem; do
    if [ -f "$DESTINO/$nome.png" ] && cmp -s "$origem" "$DESTINO/$nome.png"; then continue; fi
    if meow_seco; then meow_muda "mudaria $DESTINO/$nome.png"; mudou=1; postos=$((postos+1)); continue; fi
    meow_destino_permitido "$DESTINO/$nome.png" || return "$MEOW_ERRO"
    mkdir -p "$DESTINO"
    local tmp; tmp="$(mktemp -p "$DESTINO" ".meow.XXXXXX")"
    cp -f "$origem" "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$DESTINO/$nome.png" \
      || { rm -f "$tmp"; meow_erro "não consegui escrever $DESTINO/$nome.png"; return "$MEOW_ERRO"; }
    mudou=1; postos=$((postos + 1))
  done < <(_desejado)

  if [ -d "$DESTINO" ]; then
    for arq in "$DESTINO"/*.png; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .png)"
      if [ -z "${MAPA_LIDO[$nome]:-}" ]; then
        if meow_seco; then meow_muda "removeria $arq (saiu do mapa)"
        else meow_destino_permitido "$arq" || return "$MEOW_ERRO"; rm -f "$arq"; fi
        mudou=1; removidos=$((removidos + 1))
      fi
    done
  fi

  if [ "$mudou" = 0 ]; then
    meow_ok "aplicativos já com ícone Catppuccin ${APROXIMOU:+($APROXIMOU aproximado para $VARIANTE)}"
    return "$MEOW_OK"
  fi
  meow_info "aplicativos: $postos posto(s), $removidos removido(s) — Catppuccin $VARIANTE"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_mapa
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

APROXIMOU="${APROXIMOU:-}"
main "$@"

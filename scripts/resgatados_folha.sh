#!/usr/bin/env bash
# resgatados_folha.sh — monta a folha de ANTES E DEPOIS dos ícones resgatados.
#
# Porque na tela eles aparecem a 48 px, um de cada vez, no meio de outros
# oitenta. A pergunta "o redesenho ficou fiel?" não se responde assim: ela
# precisa do par lado a lado, no mesmo tamanho, no mesmo fundo.
#
# Vários desses caminhos são de pacote (`/usr/share`) ou de app (`/opt`), e
# somem no próximo upgrade ou na próxima reinstalação.
#
# Um ícone com borda escura sobre fundo branco parece ter halo; o mesmo ícone
# sobre o `#282A36` da barra parece correto.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ACERVO="$RAIZ/packs/dracula/icones/apps/resgatados"
MAPA="$RAIZ/packs/dracula/icones/apps-resgatados.map"
SAIDA="${1:-$RAIZ/assets/icones/resgatados-antes-e-depois.png}"

FUNDO="#1E1E2E"      # o `base` do Mocha: a folha
CELA="#282A36"       # o `base` do Dracula: a barra, atrás do ícone
BORDA_PNG="#44475A"  # cinza: o que era
BORDA_SVG="#BD93F9"  # mauve, o accent dela: o que passou a ser
TEXTO="#F8F8F2"
LADO=150

for b in rsvg-convert convert montage; do
  command -v "$b" >/dev/null 2>&1 || {
    meow_erro "falta '$b' — a folha precisa de librsvg2-bin e imagemagick"
    exit "$MEOW_SEM_DEPENDENCIA"
  }
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# O mapa é a fonte: `nome : png-de-origem : autoria`. O `~` do caminho é expandido
# aqui, e não no arquivo, porque um mapa com `/home/<usuário>` cravado seria um
# mapa que só serve nesta máquina.
pares=0; sem_png=0; sem_svg=(); larg=""
faltou=(); pecas=()   # o índice de cada par sem PNG, e os tamanhos das peças de cada par
while IFS=: read -r nome origem autoria; do
  nome="$(printf '%s' "$nome" | tr -d '[:space:]')"
  [ -n "$nome" ] || continue
  origem="$(printf '%s' "$origem" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e "s|^~|$HOME|")"
  autoria="$(printf '%s' "$autoria" | tr -d '[:space:]')"

  svg="$ACERVO/$nome.svg"
  [ -f "$svg" ] || { sem_svg+=("$nome"); continue; }

  # DEPOIS: o SVG resgatado, na moldura mauve.
  rsvg-convert -w "$LADO" -h "$LADO" "$svg" -o "$TMP/b.png" 2>/dev/null || { sem_svg+=("$nome"); continue; }
  convert "$TMP/b.png" -background "$CELA" -alpha remove -alpha off \
          -bordercolor "$BORDA_SVG" -border 2 "$TMP/depois.png" 2>/dev/null

  # ANTES: o PNG de origem, na moldura cinza — ou uma moldura vazia dizendo por quê.
  if [ -f "$origem" ]; then
    convert "$origem" -resize "${LADO}x${LADO}" -background "$CELA" -alpha remove -alpha off \
            -gravity center -extent "${LADO}x${LADO}" \
            -bordercolor "$BORDA_PNG" -border 2 "$TMP/antes.png" 2>/dev/null
  else
    sem_png=$((sem_png+1))
    faltou+=("$pares:$nome")
    convert -size "${LADO}x${LADO}" "xc:$CELA" -gravity center \
            -pointsize 13 -fill "$BORDA_PNG" -annotate 0 'sem o PNG\n(o original\nsumiu do disco)' \
            -bordercolor "$BORDA_PNG" -border 2 "$TMP/antes.png" 2>/dev/null
  fi

  # O rótulo carrega a AUTORIA junto do nome: quem olha a folha precisa saber se
  # está vendo obra dela ou logo de terceiro — são critérios de julgamento
  # diferentes, e o cabeçalho do mapa explica a diferença.
  larg="$(identify -format '%w' "$TMP/antes.png")"
  larg=$(( larg * 2 + 2 ))
  convert -background "$FUNDO" -fill "$TEXTO" -pointsize 15 -gravity center \
          -size "${larg}x" "caption:$nome  [$autoria]" "$TMP/rotulo.png" 2>/dev/null
  convert "$TMP/antes.png" "$TMP/depois.png" +append "$TMP/par.png" 2>/dev/null
  convert "$TMP/rotulo.png" "$TMP/par.png" -background "$FUNDO" -gravity center -append \
          "$TMP/par_$(printf '%03d' "$pares")_$nome.png" 2>/dev/null
  pecas+=("$(identify -format '%wx%h ' "$TMP/rotulo.png" "$TMP/antes.png" "$TMP/depois.png")")
  pares=$((pares+1))
done < <(sed -e 's/#.*//' "$MAPA" | awk -F: 'NF>=3')

[ "$pares" -gt 0 ] || { meow_erro "nenhum par para montar — o acervo está vazio?"; exit "$MEOW_ERRO"; }

# Duas colunas de pares (quatro ícones por linha) é o que cabe legível numa tela
# de notebook sem obrigar a rolar de lado.
montage "$TMP"/par_*.png -tile 2x -geometry +10+10 -background "$FUNDO" "$TMP/folha.png" 2>/dev/null

convert -size "$(identify -format '%w' "$TMP/folha.png")x58" "xc:$FUNDO" -gravity center \
        -pointsize 22 -fill "$TEXTO" -annotate +0-8 'Ícones resgatados do PNG — antes e depois' \
        -pointsize 14 -fill "$BORDA_SVG" -annotate +0+16 "à esquerda o PNG que estava valendo · à direita o vetor redesenhado" \
        "$TMP/cabeca.png" 2>/dev/null
convert "$TMP/cabeca.png" "$TMP/folha.png" -append "$TMP/final.png" 2>/dev/null

# A máscara é o mesmo par, peça a peça, em cores chapadas: o rótulo do par k
# em rgb(k+1,0,1), a célula da esquerda em rgb(k+1,0,2).
nao_costura=(); costurados=0
if [ "${#faltou[@]}" -gt 0 ] && [ -f "$SAIDA" ]; then
  for k in "${!pecas[@]}"; do
    read -r t_rot t_antes t_depois <<< "${pecas[$k]}"
    convert -size "$t_rot" "xc:rgb($((k+1)),0,1)" "$TMP/m_rot.png"
    convert -size "$t_antes" "xc:rgb($((k+1)),0,2)" -size "$t_depois" "xc:rgb(0,0,3)" +append "$TMP/m_par.png"
    convert "$TMP/m_rot.png" "$TMP/m_par.png" -background "$FUNDO" -gravity center -append \
            "$TMP/mascara_$(printf '%03d' "$k").png" 2>/dev/null
  done
  montage "$TMP"/mascara_*.png -tile 2x -geometry +10+10 -background "$FUNDO" "$TMP/m_folha.png" 2>/dev/null
  convert -size "$(identify -format '%w' "$TMP/m_folha.png")x58" "xc:$FUNDO" "$TMP/m_folha.png" -append \
          "$TMP/m_final.png" 2>/dev/null
  mesmo_tamanho=0
  [ "$(identify -format '%wx%h' "$SAIDA" 2>/dev/null)" = "$(identify -format '%wx%h' "$TMP/final.png")" ] \
    && mesmo_tamanho=1
  for f in "${faltou[@]}"; do
    k="${f%%:*}"; nome="${f#*:}"
    lugar_rot="$(convert "$TMP/m_final.png" -fill black +opaque "rgb($((k+1)),0,1)" -format '%@' info: 2>/dev/null)"
    lugar="$(convert "$TMP/m_final.png" -fill black +opaque "rgb($((k+1)),0,2)" -format '%@' info: 2>/dev/null)"
    convert "$SAIDA" -crop "$lugar_rot" +repage "$TMP/r_hoje.png" 2>/dev/null
    convert "$TMP/final.png" -crop "$lugar_rot" +repage "$TMP/r_novo.png" 2>/dev/null
    if [ "$mesmo_tamanho" = "1" ] && [ -n "$lugar" ] \
       && [ "$(compare -metric AE "$TMP/r_hoje.png" "$TMP/r_novo.png" null: 2>&1)" = "0" ]; then
      convert "$SAIDA" -crop "$lugar" +repage "$TMP/celula.png" 2>/dev/null
      convert "$TMP/final.png" "$TMP/celula.png" -geometry "+${lugar#*+}" -composite "$TMP/final.png" 2>/dev/null
      costurados=$((costurados+1))
    else
      nao_costura+=("$nome")
    fi
  done
fi
if [ "${#nao_costura[@]}" -gt 0 ]; then
  meow_aviso "a folha fica a de antes: ${#nao_costura[@]} par(es) sem o PNG de origem não estão no mesmo lugar da folha de hoje (${nao_costura[*]}), e refeita ela perderia a esquerda deles — $SAIDA"
  exit "$MEOW_SEM_DEPENDENCIA"
fi
if [ -f "$SAIDA" ] && [ "$(compare -metric AE "$SAIDA" "$TMP/final.png" null: 2>&1)" = "0" ]; then
  meow_ok "a folha já é esta ($pares pares, pixel a pixel): $SAIDA"
  exit "$MEOW_OK"
fi

mkdir -p "$(dirname "$SAIDA")"
if meow_seco; then
  meow_muda "montaria $SAIDA ($pares pares)"
  exit "$MEOW_DIVERGENTE"
fi
cp -f "$TMP/final.png" "$SAIDA" || { meow_erro "não consegui gravar $SAIDA"; exit "$MEOW_ERRO"; }

meow_ok "$pares pares em $SAIDA"
[ "$costurados" -gt 0 ] \
  && meow_info "  $costurados sem o PNG de origem: a esquerda deles veio da folha de antes (o caminho do mapa não existe mais nesta máquina)"
[ "$sem_png" -gt 0 ] && [ "$costurados" = "0" ] \
  && meow_info "  $sem_png sem o PNG de origem (o caminho do mapa não existe mais nesta máquina)"
[ "${#sem_svg[@]}" -gt 0 ] && meow_aviso "  sem desenho no acervo: ${sem_svg[*]}"
exit "$MEOW_OK"

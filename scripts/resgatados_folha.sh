#!/usr/bin/env bash
# resgatados_folha.sh — monta a folha de ANTES E DEPOIS dos ícones resgatados.
#
# PARA QUE SERVE UMA FOLHA, SE OS ÍCONES JÁ ESTÃO NA TELA
#   Porque na tela eles aparecem a 48 px, um de cada vez, no meio de outros
#   oitenta. A pergunta "o redesenho ficou fiel?" não se responde assim: ela
#   precisa do par lado a lado, no mesmo tamanho, no mesmo fundo. A folha é o
#   único lugar onde o PNG de origem e o SVG novo podem ser comparados de
#   verdade — e é por isso que ela é gerada a partir do MAPA, e não de uma lista
#   à parte: se um ícone entrar ou sair do resgate, a folha acompanha sozinha.
#
# POR QUE O PNG DA ESQUERDA PODE FALTAR, E ISSO NÃO É ERRO
#   A coluna da esquerda é o PNG de ORIGEM, no caminho em que ele foi achado em
#   11/09/2026. Vários desses caminhos são de pacote (`/usr/share`) ou de app
#   (`/opt`), e somem no próximo upgrade ou na próxima reinstalação. Quando o
#   original não está mais lá, a folha desenha a moldura vazia e diz "sem o PNG"
#   — o SVG resgatado continua íntegro, porque ele nunca dependeu do PNG em tempo
#   de execução. Ver o cabeçalho de `assets/icones/apps-resgatados.map`.
#
# A FOLHA DE HOJE NÃO SE PERDE PORQUE O DISCO PERDEU O PNG — 25/09/2026, P68
#   A moldura vazia é o que a folha mostra quando não há outra coisa a mostrar
#   — e havia: a folha que já está em `$SAIDA` tem a célula da esquerda
#   daquele par, do dia em que o PNG ainda existia. Rodado em 25/09, com 12 dos
#   21 PNG fora do disco, este script trocava a folha que a P67 costurou à mão
#   (a de 12/09, com a direita refeita) por uma com doze molduras vazias:
#   181952 pixels diferentes, e o `tests/frases-velhas.sh` diria «refeita».
#   Agora a costura é dele: a célula da esquerda de um par sem PNG sai da
#   folha de hoje, no mesmo lugar — o lugar de cada célula é medido numa
#   MÁSCARA, o mesmo `montage` com cada peça trocada por uma cor chapada, e
#   não calculado —, desde que a folha de hoje tenha o mesmo tamanho e, ali, o
#   mesmo rótulo, pixel a pixel. O que não se costura assim (a folha mudou de
#   forma, o par é outro) faz o script sair 3 sem escrever: a folha fica a de
#   antes, e a frase diz qual par. Sem folha nenhuma em `$SAIDA`, não há o que
#   perder, e a moldura vazia vale como sempre. E a folha que sai igual, pixel
#   a pixel, à que já está não é regravada.
#
# O FUNDO É O DA BARRA DELA, E ISSO NÃO É ENFEITE
#   Um ícone com borda escura sobre fundo branco parece ter halo; o mesmo ícone
#   sobre o `#282A36` da barra parece correto. Comparar arte de dock sobre fundo
#   de folha de papel é comparar com a iluminação errada.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ACERVO="$RAIZ/assets/icones/resgatados"
MAPA="$RAIZ/assets/icones/apps-resgatados.map"
SAIDA="${1:-$RAIZ/assets/icones/resgatados/ANTES-E-DEPOIS.png}"

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
faltou=(); pecas=()   # o índice de cada par sem PNG, e os tamanhos das peças de cada par (P68)
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
  # O RÓTULO É DESENHADO EM CIMA DE UMA FAIXA DA LARGURA DO PAR, e não com
  # `-annotate` sobre o par direto: um nome como `org.andrebfarias.Crononauta`
  # é mais largo que os dois ícones juntos, e o `-gravity north` centraliza o
  # texto pelo MEIO — as duas pontas saíam fora da imagem e a folha ficava com
  # `otocolo-ouroboros` e `.gnome.Nautilus`. Medido na primeira folha, em
  # 11/09/2026: 7 dos 16 rótulos cortados.
  # `-size <largura>x` com `caption:` quebra a linha sozinho dentro da largura
  # dada, então o nome comprido vira duas linhas em vez de virar meio nome.
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

# A COSTURA — P68, ver o cabeçalho. A máscara é o mesmo par, peça a peça, em
# cores chapadas: o rótulo do par k em rgb(k+1,0,1), a célula da esquerda em
# rgb(k+1,0,2). Montada como a folha, o retângulo de cada cor é o lugar exato
# daquela peça na folha de verdade.
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

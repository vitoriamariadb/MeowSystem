#!/usr/bin/env bash
# importar_icones.sh — recebe as escolhas feitas na página de curadoria.
#
# A PÁGINA MANDA A ARTE JUNTO, E É POR ISSO QUE ELA FUNCIONA
#   O navegador não entrega o caminho do arquivo que ela arrastou — por projeto,
#   não por descuido: uma página web não pode ler `/home/vitoriamaria/...`. O que
#   ela entrega é o CONTEÚDO. Então o `.json` exportado carrega cada ícone
#   embutido em base64, e este script é o único lugar que precisa saber onde no
#   disco aquilo mora. Consequência prática: o arquivo exportado continua válido
#   depois que ela mover, renomear ou apagar o original.
#
# POR QUE A ARTE É COPIADA PARA O REPO, E NÃO SÓ PARA ~/.local
#   Instalar direto no tema resolveria HOJE e quebraria na próxima rodada do
#   `install.sh`, que reconstrói o tema a partir de `icons/`. A escolha dela tem
#   que virar fonte, senão vira lixo: a arte vai para `icons/curadoria/` e o
#   apontamento para `icons/curadoria.map`. O `icones_apps.sh` roda ANTES e
#   pinta o lançador inteiro; este script roda DEPOIS e sobrepõe o que ela
#   escolheu à mão. Última palavra é dela, e a ordem é o que garante isso.
#
# SVG VAI PARA scalable/, RASTER NUNCA
#   `docs/COSMIC-THEMING.md` e o cabeçalho do `icones_apps.sh` já registram o
#   defeito que o `thunderbird.png` cometeu neste tema: raster dentro de um
#   diretório declarado como escalável fica borrado, porque o resolvedor confia
#   na declaração e escala o que não é escalável. Aqui o PNG vai para o
#   diretório do tamanho REAL dele, lido do cabeçalho do próprio arquivo.
#
# CÓDIGOS DE SAÍDA
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta dependência.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA"
ACERVO="$RAIZ/icons/curadoria"
MAPA="$RAIZ/icons/curadoria.map"

uso() {
  cat <<FIM
uso: importar_icones.sh <arquivo.json>

Aplica as escolhas exportadas pela página de curadoria de ícones.

  MEOW_DRY_RUN=1   não escreve nada, só diz o que faria
  ICONES_TEMA      tema de destino (padrão: $TEMA)

O arquivo é o \`meow-icones-escolhas.json\` que a página baixa.
FIM
}

case "${1:-}" in
  -h|--help|"") uso; [ -z "${1:-}" ] && exit "$MEOW_ERRO" || exit "$MEOW_OK" ;;
esac

PACOTE="$1"
[ -f "$PACOTE" ] || { meow_erro "não achei '$PACOTE'"; exit "$MEOW_ERRO"; }
meow_tem python3 || { meow_erro "falta python3 — é ele que decodifica o base64"; exit "$MEOW_SEM_DEPENDENCIA"; }

# ─────────────────────────────────────────────────────────────────────────────
# A EXTRAÇÃO ACONTECE EM PYTHON, E EM UM DIRETÓRIO TEMPORÁRIO
# ─────────────────────────────────────────────────────────────────────────────
# Decodificar base64 em shell é possível e é uma péssima ideia: o `base64 -d` de
# uma linha de 300 KB vinda de JSON exige recortar o campo com `sed`, e qualquer
# aspa dentro de um SVG derruba o recorte. O python já tem o parser de JSON e o
# decodificador, e devolve aqui um TSV que o shell lê sem ambiguidade.
#
# O tamanho do PNG sai do cabeçalho IHDR (bytes 16..24), não do ImageMagick:
# é uma dependência a menos para uma leitura de oito bytes. SVG não tem tamanho
# intrínseco que importe aqui — vai para `scalable/` e pronto.
TMP="$(mktemp -d)" || { meow_erro "não consegui criar diretório temporário"; exit "$MEOW_ERRO"; }
trap 'rm -rf "$TMP"' EXIT

LISTA="$TMP/lista.tsv"
if ! python3 - "$PACOTE" "$TMP" > "$LISTA" <<'PY'
import base64, json, os, struct, sys

pacote, destino = sys.argv[1], sys.argv[2]
try:
    with open(pacote, encoding='utf-8') as fh:
        d = json.load(fh)
except (OSError, ValueError) as erro:
    print(f'ERRO\tarquivo ilegível ou não é JSON: {erro}', file=sys.stderr)
    sys.exit(2)

if d.get('versao') != 1:
    print(f'ERRO\tversão {d.get("versao")!r} desconhecida (esperava 1)', file=sys.stderr)
    sys.exit(2)

escolhas = d.get('escolhas') or []
if not escolhas:
    print('ERRO\to arquivo não tem nenhuma escolha', file=sys.stderr)
    sys.exit(2)


def dimensao_png(bruto):
    """Largura do PNG lida do IHDR. None se não for um PNG íntegro."""
    if len(bruto) < 24 or bruto[:8] != b'\x89PNG\r\n\x1a\n' or bruto[12:16] != b'IHDR':
        return None
    largura, altura = struct.unpack('>II', bruto[16:24])
    return max(largura, altura) or None


vistos = set()
for item in escolhas:
    chave = (item.get('icon_key') or '').strip()
    nome = item.get('nome') or chave
    if not chave:
        print(f'PULA\t{nome}\tsem icon_key', file=sys.stderr)
        continue
    # Uma chave repetida significaria dois arquivos disputando o mesmo destino;
    # a última escolha da página é a que vale, mas o aviso tem que aparecer.
    if chave in vistos:
        print(f'PULA\t{nome}\tchave {chave} repetida no arquivo', file=sys.stderr)
        continue
    vistos.add(chave)

    try:
        bruto = base64.b64decode(item.get('dados_base64') or '', validate=True)
    except Exception:
        print(f'PULA\t{nome}\tbase64 inválido', file=sys.stderr)
        continue
    if not bruto:
        print(f'PULA\t{nome}\tconteúdo vazio', file=sys.stderr)
        continue

    cabeca = bruto.lstrip()[:400].lower()
    if b'<svg' in cabeca or bruto.lstrip().startswith(b'<?xml'):
        if b'<svg' not in bruto[:2000].lower():
            print(f'PULA\t{nome}\tdiz ser SVG mas não tem <svg', file=sys.stderr)
            continue
        ext, subdir = 'svg', 'scalable/apps'
    else:
        lado = dimensao_png(bruto)
        if lado is None:
            print(f'PULA\t{nome}\tnão é SVG nem PNG íntegro', file=sys.stderr)
            continue
        ext, subdir = 'png', f'{lado}x{lado}/apps'

    caminho = os.path.join(destino, f'{chave}.{ext}')
    with open(caminho, 'wb') as fh:
        fh.write(bruto)
    print(f'{chave}\t{ext}\t{subdir}\t{caminho}\t{nome}')
PY
then
  meow_erro "não consegui ler as escolhas de '$PACOTE'"
  exit "$MEOW_ERRO"
fi

TOTAL="$(wc -l < "$LISTA" | tr -d ' ')"
[ "$TOTAL" -gt 0 ] || { meow_erro "nenhuma escolha aproveitável no arquivo"; exit "$MEOW_ERRO"; }

meow_passo "Ícones escolhidos à mão ($TOTAL)"

mudou=0
falhou=0
declare -a REGISTRO=()

while IFS=$'\t' read -r chave ext subdir origem nome; do
  [ -n "$chave" ] || continue

  guardado="$ACERVO/$chave.$ext"
  destino="$TEMA_DIR/$subdir/$chave.$ext"

  # A comparação é por conteúdo — a regra 5 do contrato. Reimportar o mesmo
  # arquivo duas vezes tem que dizer "já estava certo", não "atualizei".
  igual_acervo=0
  [ -f "$guardado" ] && cmp -s "$origem" "$guardado" && igual_acervo=1
  igual_destino=0
  [ -f "$destino" ] && cmp -s "$origem" "$destino" && igual_destino=1

  if [ "$igual_acervo" = 1 ] && [ "$igual_destino" = 1 ]; then
    meow_ok "$nome ($chave.$ext)"
    REGISTRO+=("$chave	$ext	$subdir")
    continue
  fi

  if meow_seco; then
    meow_muda "instalaria $chave.$ext em $subdir"
    mudou=1
    REGISTRO+=("$chave	$ext	$subdir")
    continue
  fi

  if ! mkdir -p "$ACERVO" "$(dirname "$destino")"; then
    meow_erro "não consegui criar o destino de $chave"
    falhou=1
    continue
  fi

  # `install -m` em vez de `cp`: o modo fica explícito e não herda o 600 que o
  # mktemp deixou no temporário — um ícone 600 some para todo o resto do sistema.
  if ! install -m 644 "$origem" "$guardado" 2>/dev/null; then
    meow_erro "não consegui guardar $chave.$ext no acervo"
    falhou=1
    continue
  fi
  if ! install -m 644 "$origem" "$destino" 2>/dev/null; then
    meow_erro "não consegui instalar $chave.$ext no tema"
    falhou=1
    continue
  fi

  # Um ícone escolhido pode estar substituindo outro que o `icones_apps.sh`
  # instalou com OUTRA extensão. Se o antigo ficar, o resolvedor pode continuar
  # achando ele primeiro e a troca dela não apareceria — o pior desfecho
  # possível aqui, porque parece que o script funcionou.
  outra="png"; [ "$ext" = "png" ] && outra="svg"
  while IFS= read -r velho; do
    [ -f "$velho" ] || continue
    rm -f "$velho" && meow_debug "removi o $chave.$outra que competia em ${velho#$TEMA_DIR/}"
  done < <(find "$TEMA_DIR" -type f -name "$chave.$outra" 2>/dev/null)

  meow_muda "$nome → $chave.$ext em $subdir"
  mudou=1
  REGISTRO+=("$chave	$ext	$subdir")
done < "$LISTA"

# ─────────────────────────────────────────────────────────────────────────────
# O MAPA É O QUE SOBREVIVE À PRÓXIMA RODADA DO INSTALADOR
# ─────────────────────────────────────────────────────────────────────────────
# Sem ele, `icons/curadoria/` seria um monte de arquivo solto sem dono, e o
# `install.sh` não teria como saber que aquilo tem precedência sobre o acervo
# automático. O formato é o mesmo dos outros mapas do projeto: uma linha por
# entrada, `#` comenta, campos separados por TAB, ordenado para o diff ser legível.
if [ "${#REGISTRO[@]}" -gt 0 ] && ! meow_seco; then
  conteudo="# curadoria.map — ícones que ela escolheu à mão na página de curadoria.
# Têm precedência sobre o que o icones_apps.sh instala: rodam depois.
# chave<TAB>extensão<TAB>subdiretório no tema
$(printf '%s\n' "${REGISTRO[@]}" | sort -u)"
  meow_escrever "$MAPA" "$conteudo" 644
  [ $? = "$MEOW_DIVERGENTE" ] && meow_muda "curadoria.map atualizado (${#REGISTRO[@]} entradas)"
fi

# O cache só é reconstruído quando existe index.theme: sem ele o
# gtk-update-icon-cache falha com uma mensagem que assusta e não significa nada.
if [ "$mudou" = 1 ] && ! meow_seco; then
  if [ -f "$TEMA_DIR/index.theme" ] && meow_tem gtk-update-icon-cache; then
    gtk-update-icon-cache -f -t -q "$TEMA_DIR" 2>/dev/null \
      && meow_debug "cache do tema reconstruído" \
      || meow_aviso "não consegui reconstruir o cache de $TEMA"
  fi
  meow_registrar "importar_icones.sh entradas=$TOTAL mudou=$mudou"
fi

if [ "$falhou" = 1 ]; then exit "$MEOW_ERRO"; fi
if [ "$mudou" = 1 ]; then exit "$MEOW_DIVERGENTE"; fi
exit "$MEOW_OK"

#!/usr/bin/env bash
# construir_pastas.sh — as pastas do Papirus na cor do flavor, sem tocar no Papirus.
#
# O MÉTODO OFICIAL DO CATPPUCCIN NÃO SERVE AQUI
#   O README de `catppuccin/papirus-folders` manda:
#       sudo cp -r src/* /usr/share/icons/Papirus
#   Isto é, escrever por cima de um diretório do apt. Todo `apt upgrade` do
#   `papirus-icon-theme` desfaz — e a especificação deste projeto proíbe, com
#   razão. Aqui o Papirus fica intacto e derivamos um tema por cima.
#
# NEM PRECISAMOS DA FERRAMENTA `papirus-folders`
#   Ela existe para resolver um problema que não temos: trocar a cor DENTRO do
#   Papirus instalado. O que ela faz é criar, para cada `folder-<cor>-X.svg`, um
#   link `folder-X.svg`. Como estamos montando um tema do zero, fazemos isso
#   direto — uma dependência de rede a menos, e sem o SHA de um repositório
#   parado há dois anos no caminho crítico.
#
# A ARMADILHA DOS APELIDOS (mediria mal quem só testasse a pasta genérica)
#   O Papirus define 85 nomes-APELIDO em `places` que são symlinks para
#   `folder-blue-*` e `user-blue-*` — entre eles `user-home`, `folder-download`,
#   `folder-documents` e `inode-directory`, que é o nome genérico de diretório
#   que os aplicativos realmente pedem. Um tema derivado que copie só os SVGs
#   coloridos NÃO cobre esses nomes: a busca cai no Papirus-Dark e metade das
#   pastas fica mauve enquanto a outra metade continua AZUL.
#   Por isso este script reproduz cada apelido apontando para o equivalente
#   colorido, e conta quantos conseguiu — o número aparece no log de propósito.
#
# CÓPIA REAL, NÃO SYMLINK PARA /usr/share
#   Symlinkar os SVGs coloridos para o Papirus economizaria disco, mas amarraria
#   o tema à versão instalada do pacote: um `apt upgrade` que renomeie um arquivo
#   deixaria links quebrados espalhados. São ~2 MB; a cópia é barata e é honesta.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
BASE="${ICONES_BASE:-Papirus-Dark}"
BASE_DIR="/usr/share/icons/$BASE"
COR="${ICONES_PASTAS:-cat-mocha-mauve}"
FONTE="${MEOW_CAT_FOLDERS:-$RAIZ/src/icons/upstream/papirus-folders}"

TAMANHOS=(22x22 24x24 32x32 48x48 64x64)

if [ ! -d "$BASE_DIR" ]; then
  meow_aviso "$BASE não está instalado — pastas coloridas puladas"
  meow_info "instale com: sudo apt install papirus-icon-theme"
  exit "$MEOW_SEM_DEPENDENCIA"
fi
if [ ! -d "$FONTE/src" ]; then
  meow_aviso "falta o upstream em $FONTE"
  meow_info "rode: scripts/baixar_upstream.sh"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

# `folder-cat-mocha-mauve-documents.svg` -> `documents`; a pasta raiz -> vazio.
sufixo_de() {
  local n; n="$(basename "$1" .svg)"
  printf '%s' "${n#folder-$COR}" | sed 's/^-//'
}

copiados=0
apelidos=0
faltaram=0
mudou=0

for tam in "${TAMANHOS[@]}"; do
  origem="$FONTE/src/$tam/places"
  destino="$TEMA_DIR/$tam/places"
  [ -d "$origem" ] || continue
  mkdir -p "$destino" || { meow_erro "não consegui criar $destino"; exit "$MEOW_ERRO"; }

  # 1. os SVGs coloridos, como cópia real
  while IFS= read -r svg; do
    alvo="$destino/$(basename "$svg")"
    if [ ! -f "$alvo" ] || ! cmp -s "$svg" "$alvo"; then
      meow_seco || cp -f "$svg" "$alvo"
      mudou=1
    fi
    copiados=$((copiados+1))
  done < <(find "$origem" -maxdepth 1 -name "folder-$COR*.svg" -o -maxdepth 1 -name "user-$COR*.svg" 2>/dev/null)

  # 2. o nome genérico: folder.svg, user-home.svg e companhia precisam existir
  #    apontando para a versão colorida, senão a busca cai no Papirus e vem azul.
  while IFS= read -r link; do
    nome="$(basename "$link")"
    destino_orig="$(readlink "$link")"
    case "$destino_orig" in
      folder-blue*|user-blue*) ;;
      *) continue ;;
    esac
    # folder-blue-documents.svg -> folder-cat-mocha-mauve-documents.svg
    equivalente="${destino_orig/folder-blue/folder-$COR}"
    equivalente="${equivalente/user-blue/user-$COR}"
    if [ ! -e "$destino/$equivalente" ]; then
      faltaram=$((faltaram+1))
      continue
    fi
    if [ "$(readlink "$destino/$nome" 2>/dev/null)" != "$equivalente" ]; then
      meow_seco || ln -sfn "$equivalente" "$destino/$nome"
      mudou=1
    fi
    apelidos=$((apelidos+1))
  done < <(find "$BASE_DIR/$tam/places" -maxdepth 1 -type l 2>/dev/null)
done

# `Directories=` é a única chave que a crate do COSMIC lê, e o que não estiver
# listado ali não é varrido. Sem acrescentar os `<tam>/places`, tudo acima seria
# invisível — o erro clássico de quem monta tema de ícones à mão.
IND="$TEMA_DIR/index.theme"
if [ -f "$IND" ] && ! grep -q '48x48/places' "$IND"; then
  linha="scalable/apps"
  for tam in "${TAMANHOS[@]}"; do linha="$linha,$tam/places"; done
  if meow_seco; then
    meow_muda "acrescentaria os places ao Directories="
  else
    sed -i "s|^Directories=.*|Directories=$linha|" "$IND"
    for tam in "${TAMANHOS[@]}"; do
      grep -q "^\[$tam/places\]" "$IND" || cat >> "$IND" <<FIM

[$tam/places]
Size=${tam%%x*}
Context=Places
Type=Fixed
FIM
    done
  fi
  mudou=1
fi

if [ "$mudou" = "0" ]; then
  meow_ok "pastas $COR já no lugar ($copiados ícones, $apelidos apelidos)"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

meow_ok "pastas $COR: $copiados ícones, $apelidos apelidos cobertos"
[ "$faltaram" -gt 0 ] && meow_info "$faltaram apelido(s) sem equivalente colorido — herdam do $BASE"
exit "$MEOW_DIVERGENTE"

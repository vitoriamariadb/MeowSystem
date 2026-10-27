#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
_base="$(ICONES_BASE="${ICONES_BASE:-}" NOME_TEMA_ICONES="$TEMA_NOME" \
           python3 "$RAIZ/scripts/pack.py" base-apelidos 2>/dev/null)"
BASE="$(printf '%s\n' "$_base" | sed -n 's/^tema=//p')"
[ -n "$BASE" ] || BASE="Papirus-Dark"
BASE_DIR="$(printf '%s\n' "$_base" | sed -n 's/^dir=//p')"
unset _base
COR="${ICONES_PASTAS:-cat-mocha-mauve}"
FONTE="${MEOW_CAT_FOLDERS:-$MEOW_CACHE/upstream/papirus-folders}"

_cor_de_pasta_existe() { [ -f "$FONTE/src/64x64/places/folder-$1-documents.svg" ]; }

PAPEL_DAS_PASTAS="CDD6F4|313244|11111B|1E1E2E"
SLOTS_DO_PAPEL="text|surface0|crust|base"
DERIVADA=""
ORIGEM_DERIVADA=""
MOTIVO_DERIVACAO=""

_derivar_py() {
  python3 -I - "$@" <<'PY'
import json, os, re, sys
(src, origem, pedida, destino, pal_origem, fl_origem,
 pal_pedida, fl_pedido, acento, papel) = sys.argv[1:11]
HEX = re.compile(r"#([0-9A-Fa-f]{6})(?![0-9A-Fa-f])")


def parar(motivo):
    print(motivo)
    sys.exit(1)


def paleta(arq, de_quem):
    """(flavors, claros) da paleta. O `claros` que não é lista conta como vazio."""
    try:
        with open(arq, encoding="utf-8") as fh:
            dados = json.load(fh)
        flavors, claros = dados.get("flavors") or {}, dados.get("claros")
    except (OSError, ValueError, AttributeError) as e:
        parar("não li a paleta %s (%s)" % (de_quem, type(e).__name__))
    return flavors, (claros if isinstance(claros, list) else [])


def cores(flavors, flavor, de_quem):
    achadas = flavors.get(flavor) if isinstance(flavors, dict) else None
    if not isinstance(achadas, dict):
        parar("a paleta %s não tem o flavor '%s'" % (de_quem, flavor))
    return {s: h.upper() for s, h in achadas.items()
            if isinstance(h, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", h)}


flavors_de, claros_de = paleta(pal_origem, "do pack padrão")
flavors_para, claros_para = paleta(pal_pedida, "do pack no ar")
if fl_pedido in claros_para:
    if not claros_de:
        parar("o %s é claro, e o pack padrão não tem flavor claro de onde derivá-lo"
              % fl_pedido)
    fl_origem = claros_de[0]
    origem = "cat-%s-%s" % (fl_origem, acento)
de = cores(flavors_de, fl_origem, "do pack padrão")
para = cores(flavors_para, fl_pedido, "do pack no ar")
if acento not in de or acento not in para:
    parar("'%s' não é cor do %s e do %s" % (acento, fl_origem, fl_pedido))
slots = {}
for slot, h in de.items():
    slots.setdefault(h, []).append(slot)


def rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def traduzir(h):
    if h in slots:
        alvo = {para.get(s) for s in slots[h]}
        if None in alvo or len(alvo) != 1:
            parar("%s é %s no %s, e o %s não dá uma cor só para isso"
                  % (h, "/".join(slots[h]), fl_origem, fl_pedido))
        return alvo.pop()
    a, s = rgb(de[acento]), rgb(h)
    passo = {x - y for x, y in zip(a, s) if 0 < y < 255}
    d = passo.pop() if len(passo) == 1 else None
    if d is None or [min(max(x - d, 0), 255) for x in a] != s:
        parar("%s não é cor do %s nem o %s dele deslocado por igual, preso em 0 e 255"
              % (h, fl_origem, acento))
    return "#%02X%02X%02X" % tuple(min(max(c - d, 0), 255) for c in rgb(para[acento]))


arquivos = []
for tam in sorted(os.listdir(src)):
    pasta = os.path.join(src, tam, "places")
    if not os.path.isdir(pasta):
        continue
    for nome in sorted(os.listdir(pasta)):
        for prefixo in ("folder-", "user-"):
            cabeca = prefixo + origem
            if nome == cabeca + ".svg" or (nome.startswith(cabeca + "-") and nome.endswith(".svg")):
                arquivos.append((tam, nome, prefixo + pedida + nome[len(cabeca):]))
if not arquivos:
    parar("o papirus-folders não tem '%s'" % origem)
textos, tabela = {}, {}
for tam, nome, _novo in arquivos:
    try:
        with open(os.path.join(src, tam, "places", nome), encoding="utf-8", newline="") as fh:
            textos[(tam, nome)] = fh.read()
    except (OSError, UnicodeDecodeError) as e:
        parar("não li %s/%s (%s)" % (tam, nome, type(e).__name__))
    for m in HEX.finditer(textos[(tam, nome)]):
        h = "#" + m.group(1).upper()
        if h not in tabela:
            tabela[h] = traduzir(h)
if de[acento] not in tabela:
    parar("o %s do %s (%s) não está nos desenhos de '%s': a paleta do pack padrão "
          "não descreve este papirus-folders" % (acento, fl_origem, de[acento], origem))
for tam, nome, novo in arquivos:
    pasta = os.path.join(destino, tam, "places")
    os.makedirs(pasta, exist_ok=True)
    with open(os.path.join(pasta, novo), "w", encoding="utf-8", newline="") as fh:
        fh.write(HEX.sub(lambda m: tabela["#" + m.group(1).upper()], textos[(tam, nome)]))
print(origem, "|".join(para[s][1:] for s in papel.split("|") if s in para))
PY
}

derivar_variante() {
  local pedida="$1" origem="$2" flavor fl_origem saida
  meow_tem python3 || { MOTIVO_DERIVACAO="sem python3, que é quem troca as cores"; return 1; }
  flavor="${pedida#cat-}"; flavor="${flavor%-*}"
  fl_origem="${origem#cat-}"; fl_origem="${fl_origem%-*}"
  DERIVADA="$(mktemp -d "${TMPDIR:-/tmp}/meow-pastas.XXXXXX")" \
    || { MOTIVO_DERIVACAO="não consegui criar o temporário"; DERIVADA=""; return 1; }
  trap 'rm -rf "${DERIVADA:-}"' EXIT
  saida="$(_derivar_py "$FONTE/src" "$origem" "$pedida" "$DERIVADA/src" \
             "$(meow_pack_padrao_dir)/paleta.json" "$fl_origem" \
             "$(meow_paleta)" "$flavor" "${pedida##*-}" "$SLOTS_DO_PAPEL")" || {
    MOTIVO_DERIVACAO="${saida:-o python3 saiu com erro}"
    rm -rf "$DERIVADA"; DERIVADA=""
    return 1
  }
  read -r ORIGEM_DERIVADA PAPEL_DAS_PASTAS <<< "$saida"
  FONTE="$DERIVADA"
}

COR="$(ICONES_PASTAS="$COR"; meow_pastas_do_molde; printf '%s' "$ICONES_PASTAS")"

_fl="$(meow_flavor 2>/dev/null)"
_vestido="$(meow_flavor_vestido 2>/dev/null)"
case "$COR" in
  "cat-$_fl-"?*) [ -n "$_fl" ] && [ -n "$_vestido" ] && [ "$_vestido" != "$_fl" ] \
                   && COR="cat-$_vestido-${COR#"cat-$_fl-"}" ;;
esac
unset _fl _vestido

if [ -d "$FONTE/src/64x64/places" ] && ! _cor_de_pasta_existe "$COR"; then
  _cor_pedida="$COR"
  case "$COR" in
    cat-*-*) _cor_alt="cat-mocha-${COR##*-}" ;;
    *)       _cor_alt="cat-mocha-mauve" ;;
  esac
  _cor_de_pasta_existe "$_cor_alt" || _cor_alt="cat-mocha-mauve"
  if [ "$_cor_alt" = "cat-mocha-${COR##*-}" ] && _cor_de_pasta_existe "$_cor_alt" \
     && derivar_variante "$COR" "$_cor_alt"; then
    meow_info "pastas: '$COR' não existe no papirus-folders — derivada de '$ORIGEM_DERIVADA' com a paleta do pack no ar"
  elif _cor_de_pasta_existe "$_cor_alt"; then
    [ -n "$MOTIVO_DERIVACAO" ] && meow_aviso "pastas: não deu para derivar '$_cor_pedida' — $MOTIVO_DERIVACAO"
    COR="$_cor_alt"
    meow_info "pastas: '$_cor_pedida' não existe no papirus-folders — usando '$COR'"
  else
    meow_aviso "pastas: nem '$_cor_pedida' nem '$_cor_alt' existem no papirus-folders — as pastas ficam com a cor de fábrica"
  fi
  unset _cor_pedida _cor_alt
fi

if [ -z "$DERIVADA" ] && meow_tem python3; then
  _papel="$(python3 -I - "$(meow_pack_padrao_dir)/paleta.json" "${COR#cat-}" "$SLOTS_DO_PAPEL" <<'PY' 2>/dev/null
import json, sys
arq, variante, slots = sys.argv[1:4]
with open(arq, encoding="utf-8") as fh:
    cores = json.load(fh)["flavors"][variante.rsplit("-", 1)[0]]
print("|".join(cores[s][1:].upper() for s in slots.split("|")))
PY
)" && [ -n "$_papel" ] && PAPEL_DAS_PASTAS="$_papel"
  unset _papel
fi

TAMANHOS=(22x22 24x24 32x32 48x48 64x64)

_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
MAPA_PASTAS="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.pastas.mapa 2>/dev/null)" || MAPA_PASTAS=""
[ -n "$MAPA_PASTAS" ] || MAPA_PASTAS="$RAIZ/packs/meowsystem/icones/pastas.map"
unset _pack_ref
PASTEL_DIR="$TEMA_DIR/scalable/places"

declare -A CEDIDOS=()
ler_cedidos() {
  local linha nome
  [ -f "$MAPA_PASTAS" ] || return 0
  while IFS= read -r linha || [ -n "$linha" ]; do
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"
    [ -n "$nome" ] || continue
    [ -f "$PASTEL_DIR/$nome.svg" ] && CEDIDOS["$nome"]=1
  done < "$MAPA_PASTAS"
  return 0
}

cedido() { [ -n "${CEDIDOS[${1%.svg}]:-}" ]; }

ler_cedidos

if [ ! -d "$BASE_DIR" ]; then
  meow_aviso "a base '$BASE' não está em $BASE_DIR — pastas coloridas puladas"
  exit "$MEOW_SEM_DEPENDENCIA"
fi
if [ ! -d "$FONTE/src" ]; then
  meow_aviso "falta o upstream papirus-folders em $FONTE — pastas coloridas puladas"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

sufixo_de() {
  local n; n="$(basename "$1" .svg)"
  printf '%s' "${n#folder-$COR}" | sed 's/^-//'
}

lixeiras=0
copiados=0
apelidos=0
faltaram=0
cedidos=0
azuis=0
mudou=0


recolorir_lixeiras() {
  local tam="$1" origem destino modelo claro escuro alvo tmp
  destino="$TEMA_DIR/$tam/places"
  modelo="$destino/folder-$COR-documents.svg"
  [ -f "$modelo" ] || return 0
  claro="$(grep -oE '#[0-9A-Fa-f]{6}' "$modelo" | sort -u | grep -viE "#($PAPEL_DAS_PASTAS)" | head -1)"
  escuro="$(grep -oE '#[0-9A-Fa-f]{6}' "$modelo" | sort -u | grep -viE "#($PAPEL_DAS_PASTAS|${claro#\#})" | head -1)"
  [ -n "$claro" ] && [ -n "$escuro" ] || return 0

  for alvo in user-trash user-trash-full; do
    origem="$(find -L "$BASE_DIR/$tam/places" -maxdepth 1 -name "$alvo.svg" 2>/dev/null | head -1)"
    [ -n "$origem" ] || continue
    local desejado; desejado="$(sed -e "s/#9f9f9f/$claro/gI" -e "s/#8e8e8e/$escuro/gI" "$origem")"
    if [ -f "$destino/$alvo.svg" ] && [ "$desejado" = "$(cat "$destino/$alvo.svg" 2>/dev/null)" ]; then
      continue
    fi
    if meow_seco; then
      meow_muda "recoloriria $tam/$alvo.svg no accent"; mudou=1; continue
    fi
    meow_destino_permitido "$destino/$alvo.svg" || exit "$MEOW_ERRO"
    tmp="$(mktemp -p "$destino" ".meow.XXXXXX")"
    printf '%s' "$desejado" > "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$destino/$alvo.svg" \
      || { rm -f "$tmp"; meow_erro "não consegui recolorir $alvo"; exit "$MEOW_ERRO"; }
    mudou=1; lixeiras=$((lixeiras + 1))
  done
}

declare -A DE_PARA=()
declare -A VESTIDOS_AZUIS=()

tabela_azul_mauve() {
  local tam="$1" azul mauve i
  local -a de=() para=()
  DE_PARA=()
  azul="$BASE_DIR/$tam/places/folder-blue-documents.svg"
  mauve="$FONTE/src/$tam/places/folder-$COR-documents.svg"
  [ -f "$azul" ] && [ -f "$mauve" ] || return 1
  diff -q <(sed -E 's/#[0-9A-Fa-f]{6}/COR/g' "$azul") \
          <(sed -E 's/#[0-9A-Fa-f]{6}/COR/g' "$mauve") >/dev/null 2>&1 || return 1
  mapfile -t de   < <(grep -oE '#[0-9A-Fa-f]{6}' "$azul")
  mapfile -t para < <(grep -oE '#[0-9A-Fa-f]{6}' "$mauve")
  [ "${#de[@]}" -gt 0 ] && [ "${#de[@]}" = "${#para[@]}" ] || return 1
  for i in "${!de[@]}"; do
    if [ -n "${DE_PARA[${de[$i]}]:-}" ] && [ "${DE_PARA[${de[$i]}]}" != "${para[$i]}" ]; then
      DE_PARA=(); return 1
    fi
    DE_PARA["${de[$i]}"]="${para[$i]}"
  done
  return 0
}

vestir_azuis_orfaos() {
  local tam="$1" destino link nome fim eq origem desejado hex rc
  local -a troca=()
  destino="$TEMA_DIR/$tam/places"
  tabela_azul_mauve "$tam" || return 0
  for hex in "${!DE_PARA[@]}"; do troca+=(-e "s/$hex/${DE_PARA[$hex]}/gI"); done

  while IFS= read -r link; do
    nome="$(basename "$link")"
    cedido "$nome" && continue
    origem="$(readlink -f "$link")"
    [ -f "$origem" ] || continue
    fim="$(basename "$origem")"
    case "$fim" in
      folder-bluegrey*|user-bluegrey*) continue ;;
      folder-blue*|user-blue*) ;;
      *) continue ;;
    esac
    eq="${fim/folder-blue/folder-$COR}"
    eq="${eq/user-blue/user-$COR}"
    [ -f "$FONTE/src/$tam/places/$eq" ] && continue

    desejado="$(sed "${troca[@]}" "$origem")"
    meow_escrever "$destino/$nome" "$desejado" 644
    rc=$?
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; azuis=$((azuis + 1)) ;;
      *) meow_erro "não consegui recolorir $tam/$nome"; exit "$MEOW_ERRO" ;;
    esac
    VESTIDOS_AZUIS["$tam/$nome"]=1
  done < <(find "$BASE_DIR/$tam/places/" -maxdepth 1 -type l 2>/dev/null)
  return 0
}

for tam in "${TAMANHOS[@]}"; do
  origem="$FONTE/src/$tam/places"
  destino="$TEMA_DIR/$tam/places"
  [ -d "$origem" ] || continue
  meow_guardar_pasta "$destino"
  meow_seco || mkdir -p "$destino" || { meow_erro "não consegui criar $destino"; exit "$MEOW_ERRO"; }

  while IFS= read -r svg; do
    alvo="$destino/$(basename "$svg")"
    if [ ! -f "$alvo" ] || ! cmp -s "$svg" "$alvo"; then
      meow_seco || cp -f "$svg" "$alvo"
      mudou=1
    fi
    copiados=$((copiados+1))
  done < <(find "$origem" -maxdepth 1 -name "folder-$COR*.svg" -o -maxdepth 1 -name "user-$COR*.svg" 2>/dev/null)

  recolorir_lixeiras "$tam"

  vestir_azuis_orfaos "$tam"

  apelidos_antes=$apelidos
  faltaram_antes=$faltaram
  cedidos_antes=$cedidos
  passe=""
  for volta in 1 2 3 4 5; do
    criou=0
    apelidos=$apelidos_antes
    faltaram=$faltaram_antes
    cedidos=$cedidos_antes
    for passe in 1 2; do
      while IFS= read -r link; do
        nome="$(basename "$link")"
        destino_orig="$(readlink "$link")"
        equivalente=""

        if cedido "$nome"; then
          if [ -e "$destino/$nome" ] || [ -L "$destino/$nome" ]; then
            if meow_seco; then
              meow_muda "removeria $destino/$nome (cedido ao icones_pastas.sh)"
            else
              meow_destino_permitido "$destino/$nome" || exit "$MEOW_ERRO"
              rm -f "$destino/$nome"
              criou=1
            fi
            mudou=1
          fi
          [ "$passe" = "1" ] && cedidos=$((cedidos+1))
          continue
        fi

        if [ "$passe" = "1" ]; then
          case "$destino_orig" in
            folder-bluegrey*|user-bluegrey*) continue ;;
            folder-blue*|user-blue*) ;;
            *) continue ;;
          esac
          equivalente="${destino_orig/folder-blue/folder-$COR}"
          equivalente="${equivalente/user-blue/user-$COR}"
        else
          [ -e "$destino/$nome" ] && continue
          if [ -e "$destino/$destino_orig" ]; then
            equivalente="$destino_orig"
          else
            final="$(basename "$(readlink -f "$link")")"
            case "$final" in
              folder-bluegrey*|user-bluegrey*) continue ;;
              folder-blue*|user-blue*) ;;
              *) continue ;;
            esac
            equivalente="${final/folder-blue/folder-$COR}"
            equivalente="${equivalente/user-blue/user-$COR}"
          fi
        fi
        if [ ! -e "$destino/$equivalente" ]; then
          if [ "$passe" = "1" ] && [ -z "${VESTIDOS_AZUIS[$tam/$nome]:-}" ]; then
            faltaram=$((faltaram+1))
          fi
          continue
        fi
        if [ "$(readlink "$destino/$nome" 2>/dev/null)" != "$equivalente" ]; then
          meow_seco || ln -sfn "$equivalente" "$destino/$nome"
          mudou=1
          criou=1
        fi
        apelidos=$((apelidos+1))
      done < <(find "$BASE_DIR/$tam/places/" -maxdepth 1 -type l 2>/dev/null)
    done
    [ "$criou" = "0" ] && break
    meow_seco && break
  done
done

IND="$TEMA_DIR/index.theme"
if [ -f "$IND" ] && ! grep -q '48x48/places' "$IND"; then
  linha="scalable/apps"
  for tam in "${TAMANHOS[@]}"; do linha="$linha,$tam/places"; done
  if meow_seco; then
    meow_muda "acrescentaria os places ao Directories="
  else
    meow_guardar_antes "$IND"
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

apelidos=0
for tam in "${TAMANHOS[@]}"; do
  [ -d "$TEMA_DIR/$tam/places" ] || continue
  apelidos=$((apelidos + $(find "$TEMA_DIR/$tam/places/" -maxdepth 1 -type l 2>/dev/null | wc -l)))
done

nota_cedidos=""
[ "$cedidos" -gt 0 ] && nota_cedidos=", $cedidos cedidos"
[ "$lixeiras" -gt 0 ] && nota_cedidos="$nota_cedidos, $lixeiras lixeiras no accent"
[ "$azuis" -gt 0 ] && nota_cedidos="$nota_cedidos, $azuis órfãs azuis no accent"

if [ "$mudou" = "0" ]; then
  meow_ok "pastas $COR já no lugar ($copiados ícones, $apelidos apelidos$nota_cedidos)"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

meow_ok "pastas $COR: $copiados ícones, $apelidos apelidos cobertos"
[ "$azuis" -gt 0 ] && meow_info "$azuis pasta(s) órfã(s) do upstream recolorida(s) do azul do $BASE para o accent"
[ "$faltaram" -gt 0 ] && meow_info "$faltaram apelido(s) sem equivalente colorido — herdam do $BASE"
[ "$cedidos" -gt 0 ] && meow_info "$cedidos nome(s) cedidos ao icones_pastas.sh (o desenho dele, em scalable/places)"
exit "$MEOW_DIVERGENTE"

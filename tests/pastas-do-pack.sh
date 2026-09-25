#!/usr/bin/env bash
# pastas-do-pack.sh — as pastas vestem a paleta do pack no ar (P56, 24/09/2026).
#
# O DEFEITO QUE ESTE ARQUIVO VIGIA
#   Com o Dracula no ar, o `folder.svg` instalado apontava para
#   `folder-cat-mocha-mauve.svg`, e os hex dele eram os do Catppuccin Mocha: o
#   papirus-folders só traz as 56 combinações do Catppuccin, e o
#   `scripts/construir_pastas.sh` caía nelas. Desde a P56 a variante que falta
#   sai da do Catppuccin, trocada cor por cor pela paleta do pack no ar — o
#   bloco "A VARIANTE DO PACK NO AR" do script conta a medição e a regra.
#
# O QUE ELE CONFERE, NUMA CASA DE BRINQUEDO
#   1. Com o Catppuccin no ar nada se deriva: cada `folder-cat-mocha-mauve*`
#      instalado é o do papirus-folders, byte a byte, e o `folder.svg` aponta
#      para ele — os bytes das pastas são os de antes da P56.
#   2. Com o Dracula no ar o `folder.svg` aponta para a variante derivada, e
#      os hex dele são da paleta do Dracula mais a sombra do acento dele (o
#      acento com o mesmo deslocamento que o upstream dá ao dele). Nas pastas
#      instaladas, lixeira e órfãs azuis inclusive, não sobra hex nenhum do
#      Catppuccin — nem slot de paleta, nem sombra do upstream.
#   3. A segunda passagem não escreve nada, e o seco numa casa vazia não cria
#      um arquivo.
#   4. As guardas: um upstream que a paleta do pack padrão não descreve, e um
#      tom fora da paleta que não é o acento deslocado por igual, param a
#      derivação dizendo por quê, e a queda de 15/09 (a variante do Mocha) vale.
#
# POR QUE É DA MÁQUINA
#   O script lê o Papirus-Dark por `/usr/share/icons/<base>` e o papirus-folders
#   que o `scripts/baixar_upstream.sh` baixa (ou o que `MEOW_CAT_FOLDERS`
#   aponta). As guardas (4) usam um upstream de brinquedo e param antes do
#   Papirus; sem os dois de verdade, o resto sai "pulado", com o motivo.
#
# NADA SAI DA CASA DE BRINQUEDO: `env -i` com HOME temporário, e um `sudo` falso
#   na frente do PATH — o script não chama sudo, e o falso existe para que ele
#   nunca passe a chamar calado numa máquina com `NOPASSWD`.
#
#   0 = as pastas vestem o pack no ar · 1 = achados · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3, que é quem deriva a variante\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
printf '#!/bin/sh\nprintf "sudo: recusado pelo tests/pastas-do-pack.sh\\n" >&2\nexit 1\n' > "$FALSO/sudo"
chmod 755 "$FALSO/sudo"
UP="${MEOW_CAT_FOLDERS:-$RAIZ/assets/icones/upstream/papirus-folders}"

# pastas <casa> <PACK> <FLAVOR> <ACCENT> [VAR=valor ...] — a etapa das pastas
# como o `install.sh` a chama, e as variáveis a mais por último, que vencem.
pastas() {
  local casa="$1" pack="$2" flavor="$3" acento="$4"; shift 4
  mkdir -p "$casa"
  env -i PATH="$FALSO:$PATH" HOME="$casa" USER="${USER:-t}" NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" MEOW_CAT_FOLDERS="$UP" PACK="$pack" FLAVOR="$flavor" ACCENT="$acento" \
    ICONES_BASE=Papirus-Dark ICONES_PASTAS="cat-$flavor-$acento" NOME_TEMA_ICONES=MeowSystem-Icons \
    "$@" bash "$RAIZ/scripts/construir_pastas.sh" 2>&1
}

# --- 4. as guardas, com um upstream de brinquedo ---------------------------
#   Um `folder-cat-mocha-mauve` de quatro cores, como o de verdade, e duas
#   versões tortas dele. A base de ícones aponta para um tema que não existe:
#   a derivação roda antes de o script procurá-la, e ele sai 3 logo depois,
#   sem escrever nada — o que se confere aqui é só o que a derivação diz.
brinquedo() {   # $1 = o diretório · $2..$5 = os quatro hex do desenho
  local d="$1/src/64x64/places" n; mkdir -p "$d"
  for n in folder-cat-mocha-mauve folder-cat-mocha-mauve-documents; do
    printf '<svg><path style="fill:%s"/><path style="fill:%s"/><path style="fill:%s"/><path style="fill:%s"/></svg>\n' \
      "$2" "$3" "$4" "$5" > "$d/$n.svg"
  done
}
guarda() {   # $1 = o upstream de brinquedo
  env -i PATH="$FALSO:$PATH" HOME="$T/casa-guarda" USER="${USER:-t}" NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" MEOW_CAT_FOLDERS="$1" PACK=dracula FLAVOR=dracula ACCENT=mauve \
    ICONES_BASE=Tema-Ausente ICONES_PASTAS=cat-dracula-mauve NOME_TEMA_ICONES=MeowSystem-Icons \
    bash "$RAIZ/scripts/construir_pastas.sh" 2>&1
}
brinquedo "$T/up-certo" "#B792E3" "#CBA6F7" "#CDD6F4" "#313244"
brinquedo "$T/up-sem-acento" "#B792E3" "#B792E3" "#CDD6F4" "#313244"
brinquedo "$T/up-torto" "#B792E4" "#CBA6F7" "#CDD6F4" "#313244"
saida="$(guarda "$T/up-certo")"
[[ "$saida" == *"derivada de 'cat-mocha-mauve'"* ]] && [[ "$saida" != *"não deu para derivar"* ]] \
  && ok "um desenho de quatro cores como o do upstream se deriva" \
  || falha "o desenho de brinquedo certo não se derivou" "$saida"
saida="$(guarda "$T/up-sem-acento")"
[[ "$saida" == *"não deu para derivar 'cat-dracula-mauve'"*"#CBA6F7"*"não descreve"* ]] \
  && [[ "$saida" == *"usando 'cat-mocha-mauve'"* ]] \
  && ok "sem o acento de origem nos desenhos a derivação para, diz por quê, e cai no Mocha" \
  || falha "um upstream que a paleta não descreve foi derivado, ou calou" "$saida"
saida="$(guarda "$T/up-torto")"
[[ "$saida" == *"não deu para derivar"*"#B792E4"*"deslocado por igual"* ]] \
  && [[ "$saida" == *"usando 'cat-mocha-mauve'"* ]] \
  && ok "um tom fora da paleta que não é o acento deslocado por igual para a derivação" \
  || falha "um tom que ninguém mediu foi derivado, ou calou" "$saida"
[ ! -e "$T/casa-guarda/.local" ] \
  && ok "as guardas não deixaram nada na casa" \
  || falha "as guardas escreveram na casa de brinquedo" "$(find "$T/casa-guarda" | head)"

# --- o resto pede o Papirus e o papirus-folders de verdade -----------------
if [ ! -d /usr/share/icons/Papirus-Dark ]; then
  printf 'pulado: sem o Papirus-Dark em /usr/share/icons — as pastas partem dele\n'
  exit $(( falhas > 0 ))
fi
if [ ! -f "$UP/src/64x64/places/folder-cat-mocha-mauve-documents.svg" ]; then
  printf 'pulado: sem o papirus-folders em %s — rode scripts/baixar_upstream.sh, ou aponte MEOW_CAT_FOLDERS\n' \
    "${UP/#$HOME/\~}"
  exit $(( falhas > 0 ))
fi

# --- 1. com o Catppuccin no ar, os bytes são os do upstream ----------------
CASA_CAT="$T/casa-catppuccin"
saida="$(pastas "$CASA_CAT" "" mocha mauve)"; rc=$?
TEMA_CAT="$CASA_CAT/.local/share/icons/MeowSystem-Icons"
if [ "$rc" != "1" ] || [[ "$saida" == *"derivada"* ]]; then
  falha "com o Catppuccin no ar a etapa derivou alguma coisa, ou não instalou (rc=$rc)" "$saida"
else
  difere=0; contados=0
  for tam in 22x22 24x24 32x32 48x48 64x64; do
    for arq in "$UP/src/$tam/places/"folder-cat-mocha-mauve*.svg "$UP/src/$tam/places/"user-cat-mocha-mauve*.svg; do
      contados=$((contados + 1))
      cmp -s "$arq" "$TEMA_CAT/$tam/places/$(basename "$arq")" || difere=$((difere + 1))
    done
  done
  alvo="$(readlink "$TEMA_CAT/48x48/places/folder.svg")"
  if [ "$difere" = 0 ] && [ "$contados" -gt 0 ] && [ "$alvo" = "folder-cat-mocha-mauve.svg" ] \
     && [ -z "$(find "$TEMA_CAT" -name '*cat-dracula*' -print -quit)" ]; then
    ok "com o Catppuccin no ar, os $contados desenhos são os do upstream byte a byte, e o folder.svg aponta para eles"
  else
    falha "com o Catppuccin no ar as pastas não são as do upstream ($difere de $contados diferem; folder.svg -> $alvo)"
  fi
fi

# --- 2. com o Dracula no ar, as pastas vestem a paleta dele ----------------
CASA_DRA="$T/casa-dracula"
saida="$(pastas "$CASA_DRA" dracula dracula mauve)"; rc=$?
TEMA_DRA="$CASA_DRA/.local/share/icons/MeowSystem-Icons"
if [ "$rc" != "1" ] || [[ "$saida" != *"derivada de 'cat-mocha-mauve'"* ]]; then
  falha "com o Dracula no ar a variante não foi derivada (rc=$rc)" "$saida"
else
  achado="$(python3 - "$RAIZ" "$UP" "$TEMA_DRA" <<'PY'
import json, os, re, sys
raiz, up, tema = sys.argv[1:4]
HEX = re.compile(r"#[0-9A-Fa-f]{6}")


def hexes(p):
    with open(p, encoding="utf-8") as fh:
        return {h.upper() for h in HEX.findall(fh.read())}


def paleta(pack):
    with open(os.path.join(raiz, "packs", pack, "paleta.json"), encoding="utf-8") as fh:
        return json.load(fh)["flavors"]


cat, dra = paleta("catppuccin"), paleta("dracula")["dracula"]
# Os hex do Catppuccin: os 26 slots dos quatro flavors e as 56 sombras do
# upstream, lidas do disco (o hex de cada combinação que não é slot dela).
proibidos = {h.upper() for f in cat.values() for h in f.values()}
fonte = os.path.join(up, "src", "64x64", "places")
for nome in os.listdir(fonte):
    m = re.fullmatch(r"folder-cat-([a-z]+)-([a-z]+)\.svg", nome)
    if m and m.group(1) in cat:
        proibidos |= hexes(os.path.join(fonte, nome)) - {h.upper() for h in cat[m.group(1)].values()}
# A sombra esperada: o acento do Dracula com o deslocamento da do Mocha.
sombra_up = hexes(os.path.join(fonte, "folder-cat-mocha-mauve.svg")) \
    - {h.upper() for h in cat["mocha"].values()}
if len(sombra_up) != 1:
    print("o folder-cat-mocha-mauve do upstream não tem UMA sombra: %s" % sorted(sombra_up))
    sys.exit(0)
passo = int(cat["mocha"]["mauve"][1:3], 16) - int(next(iter(sombra_up))[1:3], 16)
sombra = "#" + "".join("%02X" % max(0, int(dra["mauve"][i:i + 2], 16) - passo) for i in (1, 3, 5))
da_paleta = {h.upper() for h in dra.values()}
erros = []
for tam in ("22x22", "24x24", "32x32", "48x48", "64x64"):
    d = os.path.join(tema, tam, "places")
    alvo = os.path.realpath(os.path.join(d, "folder.svg"))
    if os.path.basename(alvo) != "folder-cat-dracula-mauve.svg":
        erros.append("%s/folder.svg -> %s" % (tam, os.path.basename(alvo)))
    elif hexes(alvo) - da_paleta - {sombra}:
        erros.append("%s/folder.svg tem hex fora da paleta do Dracula: %s"
                     % (tam, sorted(hexes(alvo) - da_paleta - {sombra})))
    for nome in sorted(os.listdir(d)):
        p = os.path.join(d, nome)
        if os.path.islink(p) or not nome.endswith(".svg"):
            continue
        if hexes(p) & proibidos:
            erros.append("%s/%s tem hex do Catppuccin: %s" % (tam, nome, sorted(hexes(p) & proibidos)))
    for nome in ("user-trash.svg", "folder-docker.svg"):
        if dra["mauve"].upper() not in hexes(os.path.join(d, nome)):
            erros.append("%s/%s não tem o acento do Dracula" % (tam, nome))
if erros:
    print("\n".join(erros[:12]) + ("\n(e mais %d)" % (len(erros) - 12) if len(erros) > 12 else ""))
else:
    print("OK " + " ".join(sorted(hexes(os.path.realpath(os.path.join(tema, "48x48", "places", "folder.svg"))))))
PY
)"
  if [[ "$achado" == OK* ]]; then
    ok "com o Dracula no ar o folder.svg é a variante derivada (${achado#OK }), e nenhuma pasta tem hex do Catppuccin"
  else
    falha "com o Dracula no ar as pastas não vestem a paleta dele" "$achado"
  fi
fi

# --- 3. a segunda passagem não escreve, e o seco não cria nada -------------
saida="$(pastas "$CASA_DRA" dracula dracula mauve)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == *"já no lugar"* ]] \
  && ok "a segunda passagem com o Dracula no ar não escreve nada (rc=0)" \
  || falha "a variante derivada não convergiu na primeira passagem (rc=$rc)" "$saida"
saida="$(pastas "$T/casa-seca" dracula dracula mauve MEOW_DRY_RUN=1)"; rc=$?
criados="$(find "$T/casa-seca" -mindepth 1 | wc -l)"
[ "$rc" = "1" ] && [ "$criados" = "0" ] \
  && ok "o seco numa casa vazia diz que mudaria e não cria nada (rc=1)" \
  || falha "o seco escreveu na casa, ou não acusou a divergência (rc=$rc, $criados entradas)" "$saida"

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "as pastas vestem a paleta do pack no ar, e o Catppuccin continua o de antes"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1

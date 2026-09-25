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
# E O QUE A REVISÃO DA P56 ACHOU, NO MESMO DIA (24/09/2026)
#   5. O claro sai do claro. A primeira versão derivava todo flavor do Mocha, e
#      o Alucard (o claro do Dracula) saía de papel escuro e símbolo claro. Com
#      ele no ar, o `folder.svg` é a variante derivada do latte — cada hex no
#      slot do latte que o upstream usa ali —, e os 56 do Catppuccin, derivados
#      pela mesma regra, saem iguais ao upstream byte a byte (o `peach`, o `sky`
#      e o `red` do latte têm a sombra presa no zero).
#   6. O molde de fábrica com o FLAVOR vazio chega como `cat--mauve`, e veste a
#      variante do tema, e não a do Mocha.
#   7. As sete pastas especiais do Dracula (PASTAS_XDG="sim") chegam ao disco:
#      o `icones_pastas.sh` procurava nelas o nome do glifo do Catppuccin, não
#      achava nenhuma e dizia «já vestidas de Catppuccin macchiato».
#
# E AS DUAS REGRAS QUE A P61 CONSERTOU (25/09/2026)
#   8. A lixeira dos flavors do Catppuccin: o `recolorir_lixeiras` pulava só o
#      papel do Mocha, e com o latte, o frappé e o macchiato tomava o papel ou
#      o símbolo da pasta por tom. A lixeira de cada flavor sai da sombra e do
#      acento dele, e a do Mocha é a de antes, byte a byte.
#   9. O corpo das sete pastas especiais do Dracula, fora da paleta dele
#      (#433F4D e #534B62), passou ao slot mais próximo dela: o `surface0` e o
#      `surface1`. Continuam sem recolorir pelo acento.
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

# --- 9. o corpo das pastas especiais do Dracula é da paleta dele ------------
#   As sete desenham a pasta em dois tons, as costas e a frente — os dois
#   primeiros `<path>` de cada uma, a mesma silhueta nas sete —, e eles eram
#   #433F4D e #534B62, fora da paleta do Dracula. Continuam sem recolorir pelo
#   acento (`icones.pastas.recolorir: false`), e os dois tons passaram ao slot
#   mais próximo, medido no OKLab e escrito no PROCEDENCIA.md do pack: as costas
#   no `surface0`, a frente no `surface1`, lidos aqui da paleta.json. Nenhum dos
#   dois tons de antes sobra em desenho nenhum.
achado="$(python3 - "$RAIZ/packs/dracula" <<'PY'
import glob, json, os, re, sys
pack = sys.argv[1]
with open(os.path.join(pack, "paleta.json"), encoding="utf-8") as fh:
    dra = json.load(fh)["flavors"]["dracula"]
quer = [dra["surface0"].upper(), dra["surface1"].upper()]
erros, vistos = [], 0
for svg in sorted(glob.glob(os.path.join(pack, "icones", "pastas", "*.svg"))):
    vistos += 1
    nome = os.path.basename(svg)
    with open(svg, encoding="utf-8") as fh:
        texto = fh.read()
    # O `fill` dos dois primeiros `<path>`, na ordem do arquivo. Por texto, e
    # não por um parser de XML: é arte versionada deste repositório, e o que
    # se pergunta é o atributo de dois elementos.
    corpo = [f.upper() for f in re.findall(r'<path\b[^>]*?\bfill="([^"]*)"', texto)][:2]
    if corpo != quer:
        erros.append("%s: o corpo é %s, e a paleta pede %s" % (nome, corpo, quer))
    velhos = {h.upper() for h in re.findall(r"#[0-9A-Fa-f]{6}", texto)} & {"#433F4D", "#534B62"}
    if velhos:
        erros.append("%s: ainda tem %s" % (nome, sorted(velhos)))
if vistos != 7:
    erros.append("eram sete desenhos em icones/pastas/, e são %d" % vistos)
print("\n".join(erros) if erros else "OK %s %s" % tuple(quer))
PY
)"
[[ "$achado" == OK* ]] \
  && ok "o corpo das sete pastas especiais do Dracula é o surface0 e o surface1 da paleta dele (${achado#OK })" \
  || falha "o corpo das pastas especiais do Dracula está fora da paleta dele" "$achado"

# --- 7. as sete pastas especiais do Dracula chegam ao disco ----------------
#   O `icones_pastas.sh` não precisa do Papirus: ele copia os desenhos do pack
#   para `scalable/places`. A casa começa como a máquina de 24/09 estava — os
#   sete do Catppuccin macchiato no lugar (aqui, de brinquedo) —, e o `--aplicar`
#   tem de trocá-los pelos do Dracula e dizer de quem eles são.
xdg() {   # $1 = a casa · $2 = PACK · $3 = FLAVOR · $4 = o modo
  env -i PATH="$FALSO:$PATH" HOME="$1" USER="${USER:-t}" NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    PACK="$2" FLAVOR="$3" ACCENT=mauve PASTAS_XDG=sim ICONES_FLAVOR=macchiato \
    ICONES_TEMA=MeowSystem-Icons bash "$RAIZ/scripts/icones_pastas.sh" "$4" 2>&1
}
LUGAR="$T/casa-xdg/.local/share/icons/MeowSystem-Icons/scalable/places"
mkdir -p "$LUGAR"
for n in documents download music pictures publicshare templates videos; do
  printf '<svg><path style="fill:#CAD3F5"/></svg>' > "$LUGAR/folder-$n.svg"
done
aplicou="$(xdg "$T/casa-xdg" dracula dracula --aplicar)"
conferiu="$(xdg "$T/casa-xdg" dracula dracula --conferir)"; rc=$?
postos=0
for d in "$RAIZ/packs/dracula/icones/pastas/"*.svg; do
  [ "$(cat "$d")" = "$(cat "$LUGAR/$(basename "$d")" 2>/dev/null)" ] && postos=$((postos + 1))
done
if [ "$postos" = 7 ] && [ "$rc" = 0 ] && [[ "$aplicou" == *"desenhos do pack Dracula"* ]] \
   && [[ "$conferiu" == *"7 pasta(s) especiais já vestidas com os desenhos do pack Dracula"* ]] \
   && [[ "$aplicou$conferiu" != *Catppuccin* ]]; then
  ok "com PASTAS_XDG=\"sim\" as sete pastas especiais do Dracula chegam ao disco, e a frase diz o pack"
else
  falha "as pastas especiais do Dracula não chegaram ao disco, ou a frase fala de outro pack ($postos de 7, rc=$rc)" \
    "$aplicou
$conferiu"
fi

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

# --- 8. a lixeira de cada flavor do Catppuccin --------------------------------
#   O `recolorir_lixeiras` pinta os dois cinzas da lixeira do Papirus com os
#   dois tons da pasta vizinha que não são o papel dela — e pulava só o papel do
#   Mocha. Medido com o mauve: a lixeira do latte saía `#4C4F69 #7425DB` (o
#   `text` do latte e a sombra), e não `#7425DB #8839EF` (a sombra e o acento),
#   como a do Mocha é `#B792E3 #CBA6F7`; a do frappé, `#414559 #B68AD2`; a do
#   macchiato, `#363A4F #B28CE2`. A régua é a do script, dita daqui: os dois
#   tons são a sombra (o hex da pasta do upstream que não é slot do flavor) e o
#   acento, em ordem de texto — o primeiro no cinza claro, o segundo no escuro.
#   No Mocha isso é a lixeira de antes, byte a byte; a casa dele é a da seção 1.
for fl in latte frappe macchiato; do
  pastas "$T/casa-lixeira-$fl" "" "$fl" mauve >/dev/null
done
achado="$(python3 - "$RAIZ" "$UP" "$T" "$CASA_CAT" <<'PY'
import json, os, re, sys
raiz, up, t, casa_mocha = sys.argv[1:5]
HEX = re.compile(r"#[0-9A-Fa-f]{6}")
with open(os.path.join(raiz, "packs", "catppuccin", "paleta.json"), encoding="utf-8") as fh:
    cat = json.load(fh)["flavors"]
erros, tons = [], {}
for fl in ("latte", "frappe", "macchiato", "mocha"):
    casa = casa_mocha if fl == "mocha" else os.path.join(t, "casa-lixeira-" + fl)
    slots = {h.upper() for h in cat[fl].values()}
    for tam in ("22x22", "24x24", "32x32", "48x48", "64x64"):
        with open(os.path.join(up, "src", tam, "places", "folder-cat-%s-mauve-documents.svg" % fl),
                  encoding="utf-8") as fh:
            sombra = sorted({h for h in HEX.findall(fh.read()) if h.upper() not in slots})
        if len(sombra) != 1:
            erros.append("%s %s: o upstream não tem UMA sombra fora da paleta: %s" % (fl, tam, sombra))
            continue
        claro, escuro = sorted(sombra + [cat[fl]["mauve"].upper()])
        tons[fl] = "%s %s" % (claro, escuro)
        for alvo in ("user-trash", "user-trash-full"):
            with open(os.path.join("/usr/share/icons/Papirus-Dark", tam, "places", alvo + ".svg"),
                      encoding="utf-8") as fh:
                quer = fh.read()
            quer = re.sub("#9f9f9f", claro, quer, flags=re.I)
            quer = re.sub("#8e8e8e", escuro, quer, flags=re.I).rstrip("\n")
            feito = os.path.join(casa, ".local/share/icons/MeowSystem-Icons", tam, "places", alvo + ".svg")
            try:
                with open(feito, encoding="utf-8") as fh:
                    tem = fh.read()
            except OSError:
                tem = None
            if tem != quer:
                achados = sorted({h.upper() for h in HEX.findall(tem or "")})
                erros.append("%s %s/%s.svg: %s, e a régua pede %s %s"
                             % (fl, tam, alvo, achados if tem is not None else "não existe", claro, escuro))
print("\n".join(erros[:8]) + ("\n(e mais %d)" % (len(erros) - 8) if len(erros) > 8 else "") if erros
      else "OK " + "; ".join("%s %s" % (fl, tons[fl]) for fl in ("latte", "frappe", "macchiato", "mocha")))
PY
)"
[[ "$achado" == OK* ]] \
  && ok "a lixeira de cada flavor do Catppuccin é a sombra e o acento dele (${achado#OK }), e a do Mocha, a de antes" \
  || falha "a lixeira de algum flavor do Catppuccin tomou o papel ou o símbolo da pasta por tom" "$achado"

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

# --- 5. o claro sai do claro -------------------------------------------------
#   O Alucard no ar: a variante sai do `cat-latte-mauve`, e cada hex dela é o
#   slot do Alucard que o latte do upstream usa naquela posição — o papel no
#   `surface0`, o símbolo no `text` — e a sombra, o acento dele com o
#   deslocamento que o latte mostra. Derivado do Mocha, o papel saía #4A4F67.
CASA_ALU="$T/casa-alucard"
saida="$(pastas "$CASA_ALU" dracula alucard mauve)"; rc=$?
TEMA_ALU="$CASA_ALU/.local/share/icons/MeowSystem-Icons"
if [ "$rc" != "1" ] || [[ "$saida" != *"derivada de 'cat-latte-mauve'"* ]]; then
  falha "com o Alucard no ar a variante não saiu do latte (rc=$rc)" "$saida"
else
  achado="$(python3 - "$RAIZ" "$UP" "$TEMA_ALU" <<'PY'
import json, os, re, sys
raiz, up, tema = sys.argv[1:4]
HEX = re.compile(r"#[0-9A-Fa-f]{6}")


def paleta(pack):
    with open(os.path.join(raiz, "packs", pack, "paleta.json"), encoding="utf-8") as fh:
        return json.load(fh)["flavors"]


def rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


latte, alu = paleta("catppuccin")["latte"], paleta("dracula")["alucard"]
slot = {v.upper(): s for s, v in latte.items()}
erros = []
for tam in ("22x22", "24x24", "32x32", "48x48", "64x64"):
    for nome in ("folder-cat-latte-mauve.svg", "folder-cat-latte-mauve-documents.svg"):
        with open(os.path.join(up, "src", tam, "places", nome), encoding="utf-8") as fh:
            de = [h.upper() for h in HEX.findall(fh.read())]
        feito = os.path.join(tema, tam, "places", nome.replace("-latte-", "-alucard-"))
        with open(feito, encoding="utf-8") as fh:
            para = [h.upper() for h in HEX.findall(fh.read())]
        esperado = []
        for h in de:
            if h in slot:
                esperado.append(alu[slot[h]].upper())
            else:
                d = rgb(latte["mauve"])[0] - rgb(h)[0]
                esperado.append("#%02X%02X%02X" % tuple(max(c - d, 0) for c in rgb(alu["mauve"])))
        if para != esperado:
            erros.append("%s/%s: %s, e o latte do upstream pede %s"
                         % (tam, os.path.basename(feito), para, esperado))
alvo = os.path.basename(os.path.realpath(os.path.join(tema, "48x48", "places", "folder.svg")))
if alvo != "folder-cat-alucard-mauve.svg":
    erros.append("48x48/folder.svg -> %s" % alvo)
print("\n".join(erros) if erros else
      "OK papel %s, símbolo %s" % (alu["surface0"].upper(), alu["text"].upper()))
PY
)"
  if [[ "$achado" == OK* ]]; then
    ok "com o Alucard no ar a variante sai do latte, slot a slot (${achado#OK })"
  else
    falha "com o Alucard no ar as pastas não seguem o desenho claro do upstream" "$achado"
  fi
fi

#   E a regra inteira, contra o que o upstream já traz: os 56 do Catppuccin,
#   derivados pela função do próprio script (a origem escura entra, e o claro
#   troca sozinho), saem iguais ao upstream byte a byte. Derivando tudo do
#   Mocha, os 14 do latte saíam diferentes nos cinco tamanhos.
sed -n '/^_derivar_py() {/,/^}/p' "$RAIZ/scripts/construir_pastas.sh" > "$T/derivar.sh"
# shellcheck source=/dev/null
. "$T/derivar.sh"
PAL_CAT="$RAIZ/packs/catppuccin/paleta.json"
parados="" origens=""
for fl in latte frappe macchiato mocha; do
  for ac in rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire blue lavender; do
    if saida="$(_derivar_py "$UP/src" "cat-mocha-$ac" "cat-$fl-$ac" "$T/regra/$fl-$ac/src" \
                  "$PAL_CAT" mocha "$PAL_CAT" "$fl" "$ac" "text|surface0|crust|base")"; then
      origens+=" $fl<${saida%% *}"
    else
      parados+=" $fl-$ac ($saida)"
    fi
  done
done
achado="$(python3 - "$UP/src" "$T/regra" <<'PY'
import filecmp, os, sys
up, regra = sys.argv[1:3]
iguais, difs = 0, []
for par in sorted(os.listdir(regra)):
    base = os.path.join(regra, par, "src")
    for tam in sorted(os.listdir(base)):
        for nome in sorted(os.listdir(os.path.join(base, tam, "places"))):
            if filecmp.cmp(os.path.join(base, tam, "places", nome),
                           os.path.join(up, tam, "places", nome), shallow=False):
                iguais += 1
            else:
                difs.append("%s/%s" % (tam, nome))
print(iguais, len(difs), " ".join(difs[:4]))
PY
)"
read -r iguais difs _resto <<< "$achado"
claros_do_latte="$(grep -o ' latte<cat-latte-' <<< "$origens" | wc -l)"
if [ -z "$parados" ] && [ "${difs:-1}" = 0 ] && [ "${iguais:-0}" -gt 0 ] && [ "$claros_do_latte" = 14 ] \
   && [[ "$origens" != *" latte<cat-mocha-"* ]]; then
  ok "os 56 do Catppuccin, derivados pela regra, saem iguais ao upstream ($iguais arquivos; o latte sai do latte)"
else
  falha "a regra da derivação não reproduz o upstream (iguais=$iguais, diferentes=$difs)" \
    "parados:${parados:- nenhum}
${achado}
origens:$origens"
fi

# --- 6. o molde com o FLAVOR vazio veste a variante do tema ----------------
#   `cat-${FLAVOR}-${ACCENT}` expandido com `FLAVOR=""` chega como `cat--mauve`.
#   A base de ícones aponta para um tema que não existe, como nas guardas: o que
#   se confere é a variante que a derivação escolhe, e nada é escrito.
saida="$(env -i PATH="$FALSO:$PATH" HOME="$T/casa-molde" USER="${USER:-t}" NO_COLOR=1 \
  MEOW_RAIZ="$RAIZ" MEOW_CAT_FOLDERS="$UP" PACK=dracula FLAVOR=dracula ACCENT=mauve \
  ICONES_BASE=Tema-Ausente ICONES_PASTAS=cat--mauve NOME_TEMA_ICONES=MeowSystem-Icons \
  bash "$RAIZ/scripts/construir_pastas.sh" 2>&1)"
[[ "$saida" == *"'cat-dracula-mauve' não existe no papirus-folders — derivada de 'cat-mocha-mauve'"* ]] \
  && [[ "$saida" != *"não deu para derivar"* ]] && [ ! -e "$T/casa-molde/.local" ] \
  && ok "o molde com o FLAVOR vazio (cat--mauve) veste a variante do tema, e não a do Mocha" \
  || falha "o molde com o FLAVOR vazio caiu no Mocha, ou escreveu na casa" "$saida"

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "as pastas vestem a paleta do pack no ar, e o Catppuccin continua o de antes"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1

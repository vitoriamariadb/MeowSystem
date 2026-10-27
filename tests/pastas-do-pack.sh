#!/usr/bin/env bash
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
UP="${MEOW_CAT_FOLDERS:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/upstream/papirus-folders}"
if [ -z "${MEOW_CAT_FOLDERS:-}" ] && [ ! -d "$UP/src" ]; then
  env -i PATH="$PATH" HOME="$T" MEOW_CACHE="$T/cache" NO_COLOR=1 bash "$RAIZ/scripts/baixar_upstream.sh" >/dev/null 2>&1
  UP="$T/cache/upstream/papirus-folders"
fi

pastas() {
  local casa="$1" pack="$2" flavor="$3" acento="$4"; shift 4
  mkdir -p "$casa"
  env -i PATH="$FALSO:$PATH" HOME="$casa" USER="${USER:-t}" NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" MEOW_CAT_FOLDERS="$UP" PACK="$pack" FLAVOR="$flavor" ACCENT="$acento" \
    ICONES_BASE=Papirus-Dark ICONES_PASTAS="cat-$flavor-$acento" NOME_TEMA_ICONES=MeowSystem-Icons \
    "$@" bash "$RAIZ/scripts/construir_pastas.sh" 2>&1
}

brinquedo() {
  local d="$1/src/64x64/places" n; mkdir -p "$d"
  for n in folder-cat-mocha-mauve folder-cat-mocha-mauve-documents; do
    printf '<svg><path style="fill:%s"/><path style="fill:%s"/><path style="fill:%s"/><path style="fill:%s"/></svg>\n' \
      "$2" "$3" "$4" "$5" > "$d/$n.svg"
  done
}
guarda() {
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

achado="$(python3 - "$RAIZ/packs/dracula" "$RAIZ/packs/dracula/icones/apps/org.gnome.Nautilus.svg" <<'PY'
import glob, json, os, re, sys
pack, resgate = sys.argv[1], sys.argv[2]
with open(os.path.join(pack, "paleta.json"), encoding="utf-8") as fh:
    dra = json.load(fh)["flavors"]["dracula"]
quer = [dra["surface0"].upper(), dra["surface1"].upper()]
erros, vistos = [], 0
DO_MANUAIS = {"folder.svg", "org.gnome.Nautilus.svg"}
for svg in sorted(glob.glob(os.path.join(pack, "icones", "sistema", "*.svg"))) + [resgate]:
    vistos += 1
    nome = os.path.basename(svg)
    if nome in DO_MANUAIS:
        continue
    with open(svg, encoding="utf-8") as fh:
        texto = fh.read()
    corpo = [f.upper() for f in re.findall(r'<path\b[^>]*?\bfill="([^"]*)"', texto)][:2]
    if corpo != quer:
        erros.append("%s: o corpo é %s, e a paleta pede %s" % (nome, corpo, quer))
    velhos = {h.upper() for h in re.findall(r"#[0-9A-Fa-f]{6}", texto)} & {"#433F4D", "#534B62"}
    if velhos:
        erros.append("%s: ainda tem %s" % (nome, sorted(velhos)))
if vistos != 11:
    erros.append("eram dez desenhos em icones/pastas/ e o resgate, e são %d" % vistos)
with open(os.path.join(pack, "PROCEDENCIA.md"), encoding="utf-8") as fh:
    proc = fh.read()
linha = next((l for l in proc.splitlines() if l.startswith("| `icones/sistema/*.svg`")), "")
if "aberturas do castelo" not in linha:
    erros.append("o PROCEDENCIA.md não conta as aberturas do castelo, que mudaram com a frente: %r" % linha[-160:])
if "resgatados/org.gnome.Nautilus.svg" not in proc:
    erros.append("o PROCEDENCIA.md não diz que o resgate do Nautilus foi junto")
print("\n".join(erros) if erros else "OK %s %s" % tuple(quer))
PY
)"
[[ "$achado" == OK* ]] \
  && ok "o corpo das sete pastas especiais do Dracula e do resgate do Nautilus é o surface0 e o surface1 da paleta dele (${achado#OK }), e o PROCEDENCIA.md conta o que mudou" \
  || falha "o corpo das pastas especiais do Dracula, ou do resgate, está fora da paleta dele, ou a procedência não conta" "$achado"

xdg() {
  env -i PATH="$FALSO:$PATH" HOME="$1" USER="${USER:-t}" NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    PACK="$2" FLAVOR="$3" ACCENT=mauve PASTAS_XDG=sim ICONES_FLAVOR=macchiato \
    ICONES_TEMA=MeowSystem-Icons bash "$RAIZ/scripts/icones_pastas.sh" "$4" 2>&1
}
LUGAR="$T/casa-xdg/.local/share/icons/MeowSystem-Icons/scalable/places"
mkdir -p "$LUGAR"
for n in documents download music pictures publicshare templates videos; do
  printf '<svg><path style="fill:#CAD3F5"/></svg>' > "$LUGAR/folder-$n.svg"
done
N_PASTAS="$(find "$RAIZ/packs/dracula/icones/sistema" -maxdepth 1 -name '*.svg' | wc -l)"
aplicou="$(xdg "$T/casa-xdg" dracula dracula --aplicar)"
conferiu="$(xdg "$T/casa-xdg" dracula dracula --conferir)"; rc=$?
postos=0
for d in "$RAIZ/packs/dracula/icones/sistema/"*.svg; do
  [ "$(cat "$d")" = "$(cat "$LUGAR/$(basename "$d")" 2>/dev/null)" ] && postos=$((postos + 1))
done
if [ "$postos" = "$N_PASTAS" ] && [ "$N_PASTAS" = 10 ] && [ "$rc" = 0 ] && [[ "$aplicou" == *"desenhos do pack Dracula"* ]] \
   && [[ "$conferiu" == *"$N_PASTAS pasta(s) especiais já vestidas com os desenhos do pack Dracula"* ]] \
   && [[ "$aplicou$conferiu" != *Catppuccin* ]]; then
  ok "com PASTAS_XDG=\"sim\" as $N_PASTAS pastas especiais do Dracula chegam ao disco, e a frase diz o pack"
else
  falha "as pastas especiais do Dracula não chegaram ao disco, ou a frase fala de outro pack ($postos de $N_PASTAS, rc=$rc)" \
    "$aplicou
$conferiu"
fi

desligar() {
  local casa="$1"; shift
  env -i PATH="$FALSO:$PATH" HOME="$casa" USER="${USER:-t}" NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    PACK=dracula FLAVOR=dracula ACCENT=mauve PASTAS_XDG=nao ICONES_FLAVOR=macchiato \
    ICONES_TEMA=MeowSystem-Icons "$@" bash "$RAIZ/scripts/icones_pastas.sh" --aplicar 2>&1
}
ensaio="$(desligar "$T/casa-xdg" MEOW_DRY_RUN=1)"; rc=$?
if [ "$(find "$LUGAR" -name '*.svg' 2>/dev/null | wc -l)" = "$N_PASTAS" ] && [ "$rc" = 1 ] \
   && [[ "$ensaio" == *"removeria"* ]] && [[ "$ensaio" == *"pastas especiais: poria 0, removeria $N_PASTAS"* ]] \
   && [[ "$ensaio" == *"devolveria as pastas especiais"* ]] \
   && [[ "$ensaio" != *"posto(s)"* ]] && [[ "$ensaio" != *"removido(s)"* ]] && [[ "$ensaio" != *devolvendo* ]]; then
  ok "o ensaio de desligar as pastas especiais fala no condicional, do começo ao resumo, e não tira nada"
else
  falha "o ensaio de desligar as pastas especiais fala como se tivesse feito, ou tirou (rc=$rc)" "$ensaio"
fi
devolveu="$(desligar "$T/casa-xdg")"
de_novo="$(desligar "$T/casa-xdg")"; rc=$?
if [ -z "$(find "$LUGAR" -name '*.svg' 2>/dev/null)" ] && [ "$rc" = 0 ] \
   && [[ "$devolveu" == *"devolvendo as pastas especiais à cor das outras pastas"* ]] \
   && [[ "$de_novo" == *"elas seguem a cor das outras pastas"* ]] \
   && [[ "$devolveu$de_novo" != *mauve* ]] && [[ "$devolveu$de_novo" != *Catppuccin* ]]; then
  ok "desligadas, as pastas especiais voltam à cor das outras, e a frase não crava a cor de uma casa"
else
  falha "as pastas especiais desligadas não saíram, ou a frase crava uma cor (rc=$rc)" "$devolveu
$de_novo"
fi

achado="$(python3 - "$RAIZ" <<'PY'
import os, re, sys
raiz = sys.argv[1]
velhas = {
    "scripts/icones_pastas.sh": ["continua vindo do `construir_pastas.sh` em mauve",
                                 "sem o pastel no disco ele para de ceder",
                                 "a pasta volta a ser mauve na mesma rodada"],
    "scripts/construir_pastas.sh": ["Ceder um nome cujo pastel ainda não foi instalado",
                                    "este aqui volta a vestir o nome de mauve na mesma passagem"],
    "packs/meowsystem/icones/pastas.map": ["para que o pastel não brigue com o mauve",
                                 "ele só cede o nome cujo pastel já está no disco"],
}
erros = []
for arq, frases in velhas.items():
    with open(os.path.join(raiz, arq), encoding="utf-8") as fh:
        texto = " ".join(re.sub(r"^\s*#\s?", "", l).strip()
                         for l in fh if l.lstrip().startswith("#"))
    texto = re.sub(r"\s+", " ", texto)
    erros += ["%s: «%s»" % (arq, f) for f in frases if f in texto]
print("\n".join(erros))
PY
)"
[ -z "$achado" ] \
  && ok "os comentários das pastas especiais dizem a cor das outras pastas, e não o mauve de uma casa" \
  || falha "há comentário das pastas especiais que ainda diz o mauve, ou o pastel, como regra" "$achado"

if [ ! -d /usr/share/icons/Papirus-Dark ]; then
  printf 'pulado: sem o Papirus-Dark em /usr/share/icons — as pastas partem dele\n'
  exit $(( falhas > 0 ))
fi
if [ ! -f "$UP/src/64x64/places/folder-cat-mocha-mauve-documents.svg" ]; then
  printf 'pulado: sem o papirus-folders em %s — rode scripts/baixar_upstream.sh, ou aponte MEOW_CAT_FOLDERS\n' \
    "${UP/#$HOME/\~}"
  exit $(( falhas > 0 ))
fi

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

for fl in latte frappe macchiato; do
  pastas "$T/casa-lixeira-$fl" "" "$fl" mauve >/dev/null
done
achado="$(python3 - "$RAIZ" "$UP" "$T" "$CASA_CAT" <<'PY'
import json, os, re, sys
raiz, up, t, casa_mocha = sys.argv[1:5]
HEX = re.compile(r"#[0-9A-Fa-f]{6}")
with open(os.path.join(raiz, "packs", "meowsystem", "paleta.json"), encoding="utf-8") as fh:
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


cat, dra = paleta("meowsystem"), paleta("dracula")["dracula"]
proibidos = {h.upper() for f in cat.values() for h in f.values()}
fonte = os.path.join(up, "src", "64x64", "places")
for nome in os.listdir(fonte):
    m = re.fullmatch(r"folder-cat-([a-z]+)-([a-z]+)\.svg", nome)
    if m and m.group(1) in cat:
        proibidos |= hexes(os.path.join(fonte, nome)) - {h.upper() for h in cat[m.group(1)].values()}
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

saida="$(pastas "$CASA_DRA" dracula dracula mauve)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == *"já no lugar"* ]] \
  && ok "a segunda passagem com o Dracula no ar não escreve nada (rc=0)" \
  || falha "a variante derivada não convergiu na primeira passagem (rc=$rc)" "$saida"
saida="$(pastas "$T/casa-seca" dracula dracula mauve MEOW_DRY_RUN=1)"; rc=$?
criados="$(find "$T/casa-seca" -mindepth 1 | wc -l)"
[ "$rc" = "1" ] && [ "$criados" = "0" ] \
  && ok "o seco numa casa vazia diz que mudaria e não cria nada (rc=1)" \
  || falha "o seco escreveu na casa, ou não acusou a divergência (rc=$rc, $criados entradas)" "$saida"

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


latte, alu = paleta("meowsystem")["latte"], paleta("dracula")["alucard"]
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

sed -n '/^_derivar_py() {/,/^}/p' "$RAIZ/scripts/construir_pastas.sh" > "$T/derivar.sh"
# shellcheck source=/dev/null
. "$T/derivar.sh"
PAL_CAT="$RAIZ/packs/meowsystem/paleta.json"
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

saida="$(env -i PATH="$FALSO:$PATH" HOME="$T/casa-molde" USER="${USER:-t}" NO_COLOR=1 \
  MEOW_RAIZ="$RAIZ" MEOW_CAT_FOLDERS="$UP" PACK=dracula FLAVOR=dracula ACCENT=mauve \
  ICONES_BASE=Tema-Ausente ICONES_PASTAS=cat--mauve NOME_TEMA_ICONES=MeowSystem-Icons \
  bash "$RAIZ/scripts/construir_pastas.sh" 2>&1)"
[[ "$saida" == *"'cat-dracula-mauve' não existe no papirus-folders — derivada de 'cat-mocha-mauve'"* ]] \
  && [[ "$saida" != *"não deu para derivar"* ]] && [ ! -e "$T/casa-molde/.local" ] \
  && ok "o molde com o FLAVOR vazio (cat--mauve) veste a variante do tema, e não a do Mocha" \
  || falha "o molde com o FLAVOR vazio caiu no Mocha, ou escreveu na casa" "$saida"

if [ -d /usr/share/icons/Papirus-Dark ] && [ -d "$UP/src" ]; then
  saida="$(pastas "$T/casa-base-do-pack" dracula dracula mauve ICONES_BASE=MeowSystem-Icons-Base)"
  [[ "$saida" != *"não está instalado"* ]] \
    && [ -L "$T/casa-base-do-pack/.local/share/icons/MeowSystem-Icons/48x48/places/folder.svg" ] \
    && ok "ICONES_BASE=MeowSystem-Icons-Base: as pastas coloridas entram (a base do pack cede ao Papirus-Dark)" \
    || falha "com a base do pack escolhida pelo nome as pastas se pularam" "$saida"
  printf '[Icon Theme]\nName=MeowSystem-Icons\nDirectories=scalable/apps\n' \
    > "$T/casa-base-do-pack/.local/share/icons/MeowSystem-Icons/index.theme"
  saida="$(env -i PATH="$FALSO:$PATH" HOME="$T/casa-base-do-pack" USER="${USER:-t}" NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" PACK=dracula FLAVOR=dracula ACCENT=mauve \
    ICONES_BASE=MeowSystem-Icons-Base NOME_TEMA_ICONES=MeowSystem-Icons \
    bash "$RAIZ/scripts/completar_icones.sh" 2>&1)"
  [[ "$saida" != *"não está instalado"* ]] \
    && [ -f "$T/casa-base-do-pack/.local/share/icons/MeowSystem-Icons/scalable/apps/repoman.svg" ] \
    && ok "ICONES_BASE=MeowSystem-Icons-Base: o apelido do repoman entra" \
    || falha "com a base do pack escolhida pelo nome o completar pulou os apelidos" "$saida"
else
  printf 'pulado: sem Papirus-Dark ou sem papirus-folders, a base do pack não tem de onde copiar\n'
fi

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "as pastas vestem a paleta do pack no ar, e o Catppuccin continua o de antes"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

T="$(mktemp -d -p "${TMPDIR:-/tmp}" meow-logo.XXXXXX)" || exit 2
trap 'rm -rf "$T"' EXIT
falhas=0
ok() { printf '  ok  %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

CASA="$T/casa"
CONF="$CASA/.config/meow/meow.conf"
mkdir -p "${CONF%/*}"
conf() { printf 'PACK="meowsystem"\nFLAVOR="mocha"\nACCENT="mauve"\nLOGO_PROGRAMA="%s"\n' "$1" > "$CONF"; }

servidor() {
  env -i PATH="$PATH" HOME="$CASA" LANG=C.UTF-8 MEOW_CONF="$CONF" MEOW_PACK_DIR="$RAIZ/packs/meowsystem" \
    python3 - "$RAIZ" "$@" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[1] + "/app")
import servidor
m = servidor.Manipulador.__new__(servidor.Manipulador)
m._host_confere = m._origem_confere = lambda: True
m._token_confere = lambda consulta: True
saida = []
m._responder = lambda corpo, **_k: saida.append(corpo if isinstance(corpo, bytes) else corpo.encode())
m._recusar = lambda codigo, frase: saida.append(("%d %s" % (codigo, frase)).encode())
if sys.argv[2] == "esquema":
    m.path = "/api/esquema"
    m.do_GET()
    item = next(i for i in json.loads(saida[0])["chaves"] if i["chave"] == "LOGO_PROGRAMA")
    print(json.dumps({"opcoes": item["opcoes"], "previa": item["previa"],
                      "recusa": servidor.validar_valor(item, "naoexiste") or "",
                      "aceita": servidor.validar_valor(item, "dracula") or ""}))
else:
    m.path = "/logo.svg" + sys.argv[2]
    m.do_GET()
    sys.stdout.buffer.write(saida[0] if saida else b"")
PY
}

rotulo() { grep -o 'aria-label="[^"]*"' <<< "$1" | head -n 1; }

conf ""
de_fabrica="$(servidor "")"
[ "$(rotulo "$de_fabrica")" = 'aria-label="MeowSystem"' ] \
  && ok "com a chave vazia, /logo.svg é a marca do pack no ar" \
  || falha "com a chave vazia, /logo.svg veio $(rotulo "$de_fabrica")"

conf "dracula"
escolhida="$(servidor "")"
do_pack="$(env -i PATH="$PATH" HOME="$CASA" ACCENT=mauve python3 "$RAIZ/scripts/pack.py" logo dracula)"
[ -n "$do_pack" ] && [ "$escolhida" = "$do_pack" ] \
  && ok "com LOGO_PROGRAMA=dracula e o meowsystem no ar, /logo.svg é a logo do dracula" \
  || falha "com LOGO_PROGRAMA=dracula, /logo.svg veio $(rotulo "$escolhida")"
[ "$(servidor "?de=pack")" = "$de_fabrica" ] \
  && ok "e /logo.svg?de=pack continua mostrando a do pack no ar" \
  || falha "/logo.svg?de=pack não é a do pack no ar"
[ "$(servidor "?pack=dracula")" = "$do_pack" ] \
  && ok "/logo.svg?pack=dracula é a do dracula" || falha "/logo.svg?pack=dracula não é a do dracula"
case "$(servidor "?pack=..%2Fmeowsystem")" in
  404*) ok "um pack que não existe é recusado" ;;
  *) falha "/logo.svg?pack=../meowsystem não foi recusado" ;;
esac

conf "naoexiste"
[ "$(servidor "")" = "$de_fabrica" ] \
  && ok "um LOGO_PROGRAMA que não é pack cai na do pack no ar" \
  || falha "um LOGO_PROGRAMA que não é pack mudou a logo"

esquema="$(servidor esquema)"
python3 - "$esquema" <<'PY' && ok "o painel oferece vazio e os packs com logo, em grade de logos, e recusa o resto" || falhas=$((falhas + 1))
import json, sys
d = json.loads(sys.argv[1])
erros = []
if d["opcoes"][:1] != [""] or not {"meowsystem", "dracula"} <= set(d["opcoes"]):
    erros.append("opções %r" % d["opcoes"])
if d["previa"] != "logo":
    erros.append("prévia %r" % d["previa"])
if not d["recusa"] or d["aceita"]:
    erros.append("validação recusa=%r aceita=%r" % (d["recusa"], d["aceita"]))
if erros:
    print("  FALHA " + "; ".join(erros))
    sys.exit(1)
PY

ICONES="$CASA/.local/share/icons/MeowSystem-Icons"
mkdir -p "$ICONES/scalable/apps"
printf '[Icon Theme]\nName=MeowSystem-Icons\nDirectories=scalable/apps\n\n[scalable/apps]\nSize=48\nType=Scalable\n' \
  > "$ICONES/index.theme"
FB="$T/falso"
mkdir -p "$FB"
printf '#!/bin/sh\nexit 1\n' > "$FB/sudo"
chmod 755 "$FB/sudo"
lancador() {
  env -i PATH="$FB:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 PACK=meowsystem FLAVOR=mocha ACCENT=mauve \
    LOGO_PROGRAMA="$1" "$RAIZ/scripts/completar_icones.sh" >/dev/null 2>&1
  cat "$ICONES/scalable/apps/com.meowsystem.Painel.svg" 2>/dev/null
}
do_ar="$(env -i PATH="$PATH" HOME="$CASA" python3 "$RAIZ/scripts/pack.py" logo meowsystem mocha mauve)"
[ "$(lancador "")" = "$do_ar" ] \
  && ok "com a chave vazia, o ícone do lançador é a logo do pack no ar" \
  || falha "com a chave vazia, o ícone do lançador não é a logo do pack no ar"
[ "$(lancador dracula)" = "$do_pack" ] \
  && ok "com LOGO_PROGRAMA=dracula, o lançador acompanha" \
  || falha "com LOGO_PROGRAMA=dracula, o ícone do lançador não é a logo do dracula"
[ "$(lancador naoexiste)" = "$do_ar" ] \
  && ok "um LOGO_PROGRAMA que não é pack deixa o lançador com a do pack no ar" \
  || falha "um LOGO_PROGRAMA que não é pack estragou o ícone do lançador"

if [ "$falhas" = 0 ]; then echo "logo-do-programa: tudo verde"; exit 0; fi
echo "logo-do-programa: $falhas falha(s)"; exit 1

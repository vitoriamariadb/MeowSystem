#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
PAINEL=""
trap '[ -n "$PAINEL" ] && kill "$PAINEL" 2>/dev/null; wait 2>/dev/null; rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec pkill curl; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/mesmo-horario.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done
CASA="$T/casa"; CONF="$CASA/.config/meow/meow.conf"
mkdir -p "$(dirname "$CONF")" "$T/estado"
cp "$RAIZ/meow.conf.exemplo" "$CONF"
sed -i -e 's/^NOITE_INICIO="[^"]*"/NOITE_INICIO="19:00"/' -e 's/^NOITE_FIM="[^"]*"/NOITE_FIM="06:00"/' \
       -e 's/^WALLPAPER_NOITE_INICIO="[^"]*"/WALLPAPER_NOITE_INICIO="20:00"/' \
       -e 's/^LEITURA_HORARIO_FIM="[^"]*"/LEITURA_HORARIO_FIM="06:30"/' "$CONF"
valor() { sed -n "s/^$1=\"\\([^\"]*\\)\".*/\\1/p" "$CONF"; }
retrato() { for c in NOITE_INICIO NOITE_FIM MODO_AUTO_CLARO_ATE MODO_AUTO_CLARO_DE WALLPAPER_NOITE_INICIO \
                     WALLPAPER_NOITE_FIM LEITURA_HORARIO_INICIO LEITURA_HORARIO_FIM; do
              printf '%s=%s ' "$c" "$(valor "$c")"; done; }
antes="$(retrato)"

( exec env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 MEOW_RAIZ="$RAIZ" \
    MEOW_ESTADO="$T/estado" MEOW_CONF="$CONF" MEOW_PONTE=/nao/existe \
    "$RAIZ/app/run.sh" --sem-abrir ) > "$T/painel.log" 2>&1 &
PAINEL=$!
url=""
for _ in $(seq 1 60); do
  url="$(grep -o 'http://127\.0\.0\.1:[0-9]*/?t=[A-Za-z0-9_-]*' "$T/painel.log" | head -1)"
  [ -n "$url" ] && break
  sleep 1
done
[ -n "$url" ] || { falha "o painel não subiu com o HOME de brinquedo" "$(tail -5 "$T/painel.log")"; exit 1; }
pedir() {
  python3 - "$url" "$@" <<'PY'
import json, sys, urllib.request
url, rota = sys.argv[1], sys.argv[2]
corpo = sys.argv[3] if len(sys.argv) > 3 else None
base, tok = url.split("/?t=")
req = urllib.request.Request(base + rota, data=corpo.encode() if corpo else None,
                             headers={"X-Meow-Token": tok, "Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=60) as r:
        print(r.read().decode())
except urllib.error.HTTPError as e:
    print(e.read().decode()); sys.exit(1)
PY
}

s="$(pedir /api/esquema)"
if printf '%s' "$s" | python3 -c 'import json,sys; e=json.load(sys.stdin); sys.exit(not (e.get("mesmo_horario") is False and len(e.get("horario_das_areas") or []) == 3))'; then
  ok "o esquema diz que o interruptor está desligado, e as três áreas com horário próprio"
else
  falha "o esquema não traz o interruptor e as áreas" "$(printf '%s' "$s" | head -c 300)"
fi

s="$(pedir /api/mesmo-horario '{"ligar": true}')"; r=$?
esperado="NOITE_INICIO=19:00 NOITE_FIM=06:00 MODO_AUTO_CLARO_ATE=19 MODO_AUTO_CLARO_DE=6 WALLPAPER_NOITE_INICIO=19:00 WALLPAPER_NOITE_FIM=06:00 LEITURA_HORARIO_INICIO=19:00 LEITURA_HORARIO_FIM=06:00 "
if [ "$r" = 0 ] && [ "$(retrato)" = "$esperado" ]; then
  ok "ligado, toda área grava o horário da noite (o claro ou escuro, que é de hora cheia, na hora)"
else
  falha "ligar não gravou o mesmo horário em todas as áreas (rc=$r)" "$(retrato)
$s"
fi

s="$(pedir /api/definir '{"chave": "NOITE_INICIO", "valor": "21:30"}')"
if [ "$(valor WALLPAPER_NOITE_INICIO)" = "21:30" ] && [ "$(valor LEITURA_HORARIO_INICIO)" = "21:30" ] \
   && [ "$(valor MODO_AUTO_CLARO_ATE)" = "21" ] && [ "$(valor WALLPAPER_NOITE_FIM)" = "06:00" ]; then
  ok "ligado, mudar a noite leva as áreas junto"
else
  falha "a noite mudou e as áreas ficaram" "$(retrato)
$s"
fi

s="$(pedir /api/mesmo-horario '{"ligar": false}')"; r=$?
depois="$(retrato)"
if [ "$r" = 0 ] && [ "${depois#*NOITE_FIM=06:00 }" = "${antes#*NOITE_FIM=06:00 }" ] \
   && [ "$(valor NOITE_INICIO)" = "21:30" ]; then
  ok "desligado, cada área volta ao horário que tinha, e a noite fica a que ela escolheu"
else
  falha "desligar não devolveu o horário de cada área (rc=$r)" "antes:  $antes
depois: $depois
$s"
fi
s="$(pedir /api/esquema)"
printf '%s' "$s" | python3 -c 'import json,sys; sys.exit(json.load(sys.stdin).get("mesmo_horario") is not False)' \
  && ok "e o esquema volta a dizer desligado" || falha "o esquema não voltou a desligado"

[ "$falhas" = 0 ] || { printf '%d falha(s)\n' "$falhas" >&2; exit 1; }
printf 'mesmo-horario: tudo ok\n'

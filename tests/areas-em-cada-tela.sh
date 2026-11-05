#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

mkdir -p "$T/sistema/com.system76.CosmicComp/v1" "$T/bin" "$T/home"
C="$T/home/.config/cosmic/com.system76.CosmicComp/v1"; mkdir -p "$C"
PW="$C/pinned_workspaces"
printf '#!/bin/sh\nprintf "HDMI-A-1 (enabled)\\n  Make: LG\\neDP-1 (enabled)\\n  Make: BOE\\nDP-9 (disabled)\\n"\n' > "$T/bin/cosmic-randr"
chmod 755 "$T/bin/cosmic-randr"
cat > "$PW" <<'RON'
[
    (
        output: (
            name: "HDMI-A-1",
            edid: Some((
                manufacturer: ('G', 'S', 'M'),
                product: 23410,
                serial: Some(16843009),
                manufacture_week: 1,
                manufacture_year: 2018,
                model_year: None,
            )),
        ),
        tiling_enabled: true,
        id: Some("0bccce"),
        name: Some("Pop"),
    ),
    (
        output: (
            name: "HDMI-A-1",
            edid: None,
        ),
        tiling_enabled: false,
        id: Some("f7b12d"),
        name: Some("OS"),
    ),
]
RON

areas() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/home" NO_COLOR=1 LANG=C.UTF-8 MEOW_RAIZ="$RAIZ" \
    MEOW_COSMIC_SISTEMA="$T/sistema" MEOW_ESTADO="$T/estado" MEOW_DRY_RUN="${SECO:-0}" \
    MEOW_SIM="${SIM:-0}" AREAS_NOMES="${NOMES:-Pop, OS}" AREAS_FOLGA="" AREAS_ENCAIXE="" \
    "$RAIZ/scripts/areas.sh" "$@" 2>&1
}
da_tela() { python3 -I - "$PW" "$1" <<'PY'
import re, sys
texto = open(sys.argv[1], encoding="utf-8").read()
for bloco in re.findall(r'\(\n\s+output: \(\n\s+name: "([^"]+)".*?name: Some\("([^"]*)"\),\n\s+\)', texto, re.S):
    if bloco[0] == sys.argv[2]:
        print(bloco[1].strip())
PY
}
ids_repetidos() { grep -o 'id: Some("[^"]*")' "$PW" | sort | uniq -d | wc -l; }

printf '\na tela sem área é vista pelo doctor, e o ensaio não escreve\n'
saida="$(areas alfinetes)"; rc=$?
confere "alfinetes acusa a tela que falta" '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q "eDP-1"' "rc=$rc $saida"
antes="$(md5sum < "$PW")"
SECO=1 areas refazer-alfinetes >/dev/null
confere "o ensaio não grava" '[ "$antes" = "$(md5sum < "$PW")" ]'

printf '\no conserto põe as mesmas áreas em cada tela ligada\n'
areas refazer-alfinetes >/dev/null
confere "a tela do notebook ganha Pop e OS, nessa ordem" '[ "$(da_tela eDP-1 | paste -sd,)" = "Pop,OS" ]' "$(cat "$PW")"
confere "a tela de antes segue igual" '[ "$(da_tela HDMI-A-1 | paste -sd,)" = "Pop,OS" ]'
confere "a tela desligada fica de fora" '! grep -q "DP-9" "$PW"'
confere "nenhum id repete" '[ "$(ids_repetidos)" = 0 ]'
confere "o encaixe acompanha a área" '[ "$(grep -c "tiling_enabled: true" "$PW")" = 2 ] && [ "$(grep -c "tiling_enabled: false" "$PW")" = 2 ]'

printf '\na segunda passada não escreve nada\n'
saida="$(areas alfinetes)"; rc=$?
confere "alfinetes fica verde" '[ "$rc" = 0 ]' "rc=$rc $saida"
saida="$(areas conferir)"; rc=$?
confere "conferir fica verde" '[ "$rc" = 0 ]' "rc=$rc $saida"
antes="$(md5sum < "$PW")"
areas aplicar >/dev/null; areas refazer-alfinetes >/dev/null
confere "aplicar e refazer não mudam um byte" '[ "$antes" = "$(md5sum < "$PW")" ]'

printf '\nrenomear e acrescentar valem em todas as telas\n'
NOMES="Casa, OS" areas aplicar >/dev/null
confere "o nome novo chega às duas" '[ "$(da_tela eDP-1 | paste -sd,)" = "Casa,OS" ] && [ "$(da_tela HDMI-A-1 | paste -sd,)" = "Casa,OS" ]' "$(cat "$PW")"
NOMES="Casa, OS, Som" areas aplicar >/dev/null
confere "a área nova nasce nas duas" '[ "$(da_tela eDP-1 | paste -sd,)" = "Casa,OS,Som" ] && [ "$(da_tela HDMI-A-1 | paste -sd,)" = "Casa,OS,Som" ]' "$(cat "$PW")"
confere "e os ids seguem únicos" '[ "$(ids_repetidos)" = 0 ]'
saida="$(NOMES="Casa, OS" areas aplicar)"; rc=$?
confere "faltar um nome segue recusado" '[ "$rc" = 2 ] || printf "%s" "$saida" | grep -q "TIRARIA"' "rc=$rc $saida"

printf '\ntirar uma área tira de todas as telas\n'
NOMES="Casa, OS, Som" SIM=1 areas desalfinetar Som >/dev/null
confere "Som sai das duas" '[ "$(da_tela eDP-1 | paste -sd,)" = "Casa,OS" ] && [ "$(da_tela HDMI-A-1 | paste -sd,)" = "Casa,OS" ]' "$(cat "$PW")"

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'areas-em-cada-tela: tudo verde\n'; exit 0; fi
printf 'areas-em-cada-tela: %s falha(s)\n' "$falhas"; exit 1

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
WM="$C/workspaces"
printf '#!/bin/sh\nprintf "HDMI-A-1 (enabled)\\n  Make: LG\\neDP-1 (enabled)\\n  Make: BOE\\nDP-9 (disabled)\\n"\n' > "$T/bin/cosmic-randr"
chmod 755 "$T/bin/cosmic-randr"
semear() {
rm -f "$WM"
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
}
semear

areas() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/home" NO_COLOR=1 LANG=C.UTF-8 MEOW_RAIZ="$RAIZ" \
    MEOW_COSMIC_SISTEMA="$T/sistema" MEOW_ESTADO="$T/estado" MEOW_DRY_RUN="${SECO:-0}" \
    MEOW_SIM="${SIM:-0}" AREAS_MODO="${MODO:-independentes}" AREAS_NOMES="${NOMES:-Pop, OS}" AREAS_FOLGA="" AREAS_ENCAIXE="" \
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
da_conf() { env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/home" NO_COLOR=1 LANG=C.UTF-8 MEOW_RAIZ="$RAIZ" \
    MEOW_COSMIC_SISTEMA="$T/sistema" MEOW_ESTADO="$T/estado" MEOW_DRY_RUN="${SECO:-0}" MEOW_SIM="${SIM:-0}" AREAS_NOMES="${NOMES-Pop, OS}" \
    AREAS_FOLGA="" AREAS_ENCAIXE="" ${MODO_PADRAO:-} "$RAIZ/scripts/areas.sh" "$@" 2>&1; }
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

printf '\nindependentes grava o modo de fábrica sem criar arquivo à toa\n'
confere "OutputBound com o arquivo ausente não escreve o workspaces" '[ ! -e "$WM" ]'

printf '\njuntas é o padrão: uma lista só e o modo Global\n'
semear
areas refazer-alfinetes >/dev/null
MODO=independentes areas refazer-alfinetes >/dev/null
confere "partida de quatro entradas, duas por tela" '[ "$(grep -c "output:" "$PW")" = 4 ]'
saida="$(da_conf alfinetes)"; rc=$?
confere "sem AREAS_MODO o padrão é juntas e o doctor acusa a repetida e o modo" '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q "repetidas na tela: eDP-1" && printf "%s" "$saida" | grep -q "workspace_mode está OutputBound"' "rc=$rc $saida"
antes="$(md5sum < "$PW")"
SECO=1 da_conf refazer-alfinetes >/dev/null
confere "o ensaio não grava nem a lista nem o modo" '[ "$antes" = "$(md5sum < "$PW")" ] && [ ! -e "$WM" ]'
da_conf refazer-alfinetes >/dev/null
confere "o modo vira Global" 'grep -q "workspace_mode: Global" "$WM"' "$(cat "$WM" 2>&1)"
confere "o arquivo do modo nasce completo" 'grep -q "workspace_layout: Vertical" "$WM" && grep -q "workspace_wraparound: true" "$WM"' "$(cat "$WM" 2>&1)"
confere "a lista fica só com as áreas de uma tela" '[ "$(grep -c "output:" "$PW")" = 2 ] && [ "$(da_tela HDMI-A-1 | paste -sd,)" = "Pop,OS" ] && [ -z "$(da_tela eDP-1)" ]' "$(cat "$PW")"
confere "nenhum id repete" '[ "$(ids_repetidos)" = 0 ]'
confere "o encaixe da lista segue" '[ "$(grep -c "tiling_enabled: true" "$PW")" = 1 ] && [ "$(grep -c "tiling_enabled: false" "$PW")" = 1 ]'

printf '\na segunda passada de juntas não escreve nada\n'
saida="$(da_conf alfinetes)"; rc=$?
confere "alfinetes fica verde" '[ "$rc" = 0 ]' "rc=$rc $saida"
saida="$(da_conf conferir)"; rc=$?
confere "conferir fica verde" '[ "$rc" = 0 ]' "rc=$rc $saida"
antes="$(md5sum < "$PW")$(md5sum < "$WM")"
da_conf aplicar >/dev/null; da_conf refazer-alfinetes >/dev/null
confere "aplicar e refazer não mudam um byte" '[ "$antes" = "$(md5sum < "$PW")$(md5sum < "$WM")" ]'

printf '\nrenomear e acrescentar em juntas valem na lista única\n'
NOMES="Casa, OS" da_conf aplicar >/dev/null
confere "o nome novo entra uma vez" '[ "$(da_tela HDMI-A-1 | paste -sd,)" = "Casa,OS" ] && [ -z "$(da_tela eDP-1)" ]' "$(cat "$PW")"
NOMES="Casa, OS, Som" da_conf aplicar >/dev/null
confere "a área nova nasce uma vez" '[ "$(da_tela HDMI-A-1 | paste -sd,)" = "Casa,OS,Som" ] && [ "$(grep -c "output:" "$PW")" = 3 ]' "$(cat "$PW")"
confere "e os ids seguem únicos" '[ "$(ids_repetidos)" = 0 ]'
NOMES="Casa, OS, Som" SIM=1 da_conf desalfinetar Som >/dev/null
confere "tirar uma área tira da lista" '[ "$(da_tela HDMI-A-1 | paste -sd,)" = "Casa,OS" ]'

printf '\no modo troca sem perder o resto da chave\n'
printf '(workspace_mode: Global, workspace_layout: Horizontal, action_on_typing: OpenLauncher, workspace_wraparound: false)' > "$WM"
NOMES="Casa, OS" MODO_PADRAO="AREAS_MODO=independentes" da_conf refazer-alfinetes >/dev/null
confere "só o modo muda; layout, digitação e volta ficam" 'grep -q "workspace_mode: OutputBound" "$WM" && grep -q "workspace_layout: Horizontal" "$WM" && grep -q "action_on_typing: OpenLauncher" "$WM" && grep -q "workspace_wraparound: false" "$WM"' "$(cat "$WM")"
confere "voltar a independentes devolve a lista a cada tela" '[ "$(da_tela eDP-1 | paste -sd,)" = "Casa,OS" ] && [ "$(da_tela HDMI-A-1 | paste -sd,)" = "Casa,OS" ]' "$(cat "$PW")"
NOMES="Casa, OS" MODO_PADRAO="AREAS_MODO=juntas" da_conf refazer-alfinetes >/dev/null
confere "e juntas de novo tira as repetidas e liga o Global" 'grep -q "workspace_mode: Global" "$WM" && grep -q "workspace_layout: Horizontal" "$WM" && [ "$(grep -c "output:" "$PW")" = 2 ]' "$(cat "$WM") $(cat "$PW")"

printf '\no que não é do doctor fica quieto\n'
semear
saida="$(NOMES="" da_conf refazer-alfinetes)"; rc=$?
confere "sem nomes as áreas são dela e o modo não é tocado" '[ "$rc" = 0 ] && [ ! -e "$WM" ]' "rc=$rc $saida"
saida="$(MODO_PADRAO="AREAS_MODO=em-pares" da_conf aplicar)"; rc=$?
confere "um modo que não existe é recusado sem escrever" '[ "$rc" = 2 ] && [ ! -e "$WM" ]' "rc=$rc $saida"

printf '\no painel conhece o modo e lê o que está no disco\n'
semear
leitura_do_painel() { env -i PATH=/usr/bin:/bin HOME="$T/home" MEOW_RAIZ="$RAIZ" python3 -I - "$RAIZ/app" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import servidor
i = next(x for x in servidor.ler_esquema() if x["chave"] == "AREAS_MODO")
print(",".join(i["opcoes"]), i["padrao"], i["secao"], i["aceita_vazio"], servidor._valendo_agora("AREAS_MODO"))
PY
}
confere "as duas palavras, juntas de fábrica, na seção das áreas, sem vazio" '[ "$(leitura_do_painel | sed "s/ [^ ]*$//")" = "juntas,independentes juntas Áreas de trabalho False" ]' "$(leitura_do_painel 2>&1)"
confere "sem arquivo do modo o painel não afirma nada" '[ "$(leitura_do_painel | awk "{print \$NF}")" = None ]' "$(leitura_do_painel 2>&1)"
printf '(workspace_mode: Global, workspace_layout: Vertical, action_on_typing: None, workspace_wraparound: true)' > "$WM"
confere "com Global no disco o painel diz juntas" '[ "$(leitura_do_painel | awk "{print \$NF}")" = juntas ]' "$(leitura_do_painel 2>&1)"
printf '(workspace_mode: OutputBound, workspace_layout: Vertical, action_on_typing: None, workspace_wraparound: true)' > "$WM"
confere "com OutputBound no disco o painel diz independentes" '[ "$(leitura_do_painel | awk "{print \$NF}")" = independentes ]' "$(leitura_do_painel 2>&1)"

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'areas-em-cada-tela: tudo verde\n'; exit 0; fi
printf 'areas-em-cada-tela: %s falha(s)\n' "$falhas"; exit 1

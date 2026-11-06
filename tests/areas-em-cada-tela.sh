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
confere "sem AREAS_MODO o padrão é juntas e o doctor acusa a repetida e o modo" '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q "repetidas na tela: HDMI-A-1" && printf "%s" "$saida" | grep -q "workspace_mode está OutputBound"' "rc=$rc $saida"
antes="$(md5sum < "$PW")"
SECO=1 da_conf refazer-alfinetes >/dev/null
confere "o ensaio não grava nem a lista nem o modo" '[ "$antes" = "$(md5sum < "$PW")" ] && [ ! -e "$WM" ]'
da_conf refazer-alfinetes >/dev/null
confere "o modo vira Global" 'grep -q "workspace_mode: Global" "$WM"' "$(cat "$WM" 2>&1)"
confere "o arquivo do modo nasce completo" 'grep -q "workspace_layout: Vertical" "$WM" && grep -q "workspace_wraparound: true" "$WM"' "$(cat "$WM" 2>&1)"
confere "a lista fica só com as áreas de uma tela" '[ "$(grep -c "output:" "$PW")" = 2 ] && [ "$(da_tela eDP-1 | paste -sd,)" = "Pop,OS" ] && [ -z "$(da_tela HDMI-A-1)" ]' "$(cat "$PW")"
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
confere "o nome novo entra uma vez" '[ "$(da_tela eDP-1 | paste -sd,)" = "Casa,OS" ] && [ -z "$(da_tela HDMI-A-1)" ]' "$(cat "$PW")"
NOMES="Casa, OS, Som" da_conf aplicar >/dev/null
confere "a área nova nasce uma vez" '[ "$(da_tela eDP-1 | paste -sd,)" = "Casa,OS,Som" ] && [ "$(grep -c "output:" "$PW")" = 3 ]' "$(cat "$PW")"
confere "e os ids seguem únicos" '[ "$(ids_repetidos)" = 0 ]'
NOMES="Casa, OS, Som" SIM=1 da_conf desalfinetar Som >/dev/null
confere "tirar uma área tira da lista" '[ "$(da_tela eDP-1 | paste -sd,)" = "Casa,OS" ]'

printf '\no modo troca sem perder o resto da chave\n'
printf '(workspace_mode: Global, workspace_layout: Horizontal, action_on_typing: OpenLauncher, workspace_wraparound: false)' > "$WM"
NOMES="Casa, OS" MODO_PADRAO="AREAS_MODO=independentes" da_conf refazer-alfinetes >/dev/null
confere "só o modo muda; layout, digitação e volta ficam" 'grep -q "workspace_mode: OutputBound" "$WM" && grep -q "workspace_layout: Horizontal" "$WM" && grep -q "action_on_typing: OpenLauncher" "$WM" && grep -q "workspace_wraparound: false" "$WM"' "$(cat "$WM")"
confere "voltar a independentes devolve a lista a cada tela" '[ "$(da_tela eDP-1 | paste -sd,)" = "Casa,OS" ] && [ "$(da_tela HDMI-A-1 | paste -sd,)" = "Casa,OS" ]' "$(cat "$PW")"
NOMES="Casa, OS" MODO_PADRAO="AREAS_MODO=juntas" da_conf refazer-alfinetes >/dev/null
confere "e juntas de novo tira as repetidas e liga o Global" 'grep -q "workspace_mode: Global" "$WM" && grep -q "workspace_layout: Horizontal" "$WM" && [ "$(grep -c "output:" "$PW")" = 2 ]' "$(cat "$WM") $(cat "$PW")"

printf '\no instalador sai das quatro entradas direto para a lista única\n'
semear
areas refazer-alfinetes >/dev/null
confere "partida do instalador com quatro entradas" '[ "$(grep -c "output:" "$PW")" = 4 ]'
da_conf aplicar >/dev/null
confere "aplicar reduz a lista e liga o Global" '[ "$(grep -c "output:" "$PW")" = 2 ] && grep -q "workspace_mode: Global" "$WM"' "$(cat "$PW")"
marca() { stat -c '%i %Y' "$PW" "$WM" | md5sum; }
antes="$(marca)"
saida="$(da_conf aplicar)"; rc=$?
confere "a segunda passada do instalador não troca nem o inode" '[ "$rc" = 0 ] && [ "$antes" = "$(marca)" ]' "rc=$rc $saida"

printf '\nem juntas só sai o que é repetido\n'
semear
areas refazer-alfinetes >/dev/null
rm -f "$WM"
python3 -I - "$PW" <<'PY'
import sys
c = sys.argv[1]
t = open(c, encoding="utf-8").read()
fim = t.rindex("]")
t = t[:fim] + """    (
        output: (
            name: "eDP-1",
            edid: None,
        ),
        tiling_enabled: false,
        id: Some("cafe01"),
        name: Some("Estudo"),
    ),
""" + t[fim:]
open(c, "w", encoding="utf-8").write(t)
PY
da_conf refazer-alfinetes >/dev/null
confere "a área só da outra tela fica" '[ "$(da_tela HDMI-A-1 | paste -sd,)" = "Pop,OS" ] && [ "$(da_tela eDP-1 | paste -sd,)" = "Estudo" ]' "$(cat "$PW")"
saida="$(da_conf alfinetes)"; rc=$?
confere "e o doctor a deixa quieta" '[ "$rc" = 0 ]' "rc=$rc $saida"
antes="$(md5sum < "$PW")"
da_conf aplicar >/dev/null; da_conf refazer-alfinetes >/dev/null
confere "as passadas seguintes não a tiram" '[ "$antes" = "$(md5sum < "$PW")" ]'

printf '\nrenomear no mesmo gesto da virada para juntas não deixa o nome velho na outra tela\n'
semear
areas refazer-alfinetes >/dev/null
NOMES="Casa, OS" da_conf aplicar >/dev/null
confere "só a lista nova fica" '[ "$(da_tela eDP-1 | paste -sd,)" = "Casa,OS" ] && [ -z "$(da_tela HDMI-A-1)" ]' "$(cat "$PW")"

printf '\nem juntas a lista mora no monitor interno\n'
semear
ids_antes="$(grep -o 'id: Some("[^"]*")' "$PW" | paste -sd,)"
saida="$(da_conf alfinetes)"; rc=$?
confere "o doctor acusa a lista presa ao monitor de fora" '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q "lista das áreas fora da tela de casa: HDMI-A-1"' "rc=$rc $saida"
antes="$(md5sum < "$PW")"
SECO=1 da_conf refazer-alfinetes >/dev/null
confere "o ensaio não grava" '[ "$antes" = "$(md5sum < "$PW")" ]'
da_conf aplicar >/dev/null
confere "a lista passa ao eDP-1 e a HDMI-A-1 fica sem área" '[ "$(da_tela eDP-1 | paste -sd,)" = "Pop,OS" ] && [ -z "$(da_tela HDMI-A-1)" ] && [ "$(grep -c "output:" "$PW")" = 2 ]' "$(cat "$PW")"
confere "os ids e o encaixe seguem os mesmos" '[ "$(grep -o "id: Some(\"[^\"]*\")" "$PW" | paste -sd,)" = "$ids_antes" ] && [ "$(grep -c "tiling_enabled: true" "$PW")" = 1 ]' "$(cat "$PW")"
saida="$(da_conf alfinetes)"; rc=$?
confere "alfinetes fica verde" '[ "$rc" = 0 ]' "rc=$rc $saida"
saida="$(da_conf conferir)"; rc=$?
confere "conferir fica verde" '[ "$rc" = 0 ]' "rc=$rc $saida"
antes="$(marca)"
da_conf aplicar >/dev/null; da_conf refazer-alfinetes >/dev/null
confere "a segunda passada não troca nem o inode" '[ "$antes" = "$(marca)" ]'
semear
da_conf refazer-alfinetes >/dev/null
confere "refazer-alfinetes também leva a lista ao eDP-1" '[ "$(da_tela eDP-1 | paste -sd,)" = "Pop,OS" ] && [ -z "$(da_tela HDMI-A-1)" ]' "$(cat "$PW")"

printf '\nsem monitor interno a lista segue a ordem do arquivo\n'
printf '#!/bin/sh\nprintf "HDMI-A-1 (enabled)\\n  Make: LG\\nDP-2 (enabled)\\n  Make: Dell\\n"\n' > "$T/bin/cosmic-randr"
semear
printf '(workspace_mode: Global, workspace_layout: Vertical, action_on_typing: None, workspace_wraparound: true)' > "$WM"
antes="$(md5sum < "$PW")$(md5sum < "$WM")"
saida="$(da_conf alfinetes)"; rc=$?
confere "o doctor fica quieto" '[ "$rc" = 0 ]' "rc=$rc $saida"
da_conf aplicar >/dev/null; da_conf refazer-alfinetes >/dev/null
confere "aplicar e refazer não mudam um byte" '[ "$antes" = "$(md5sum < "$PW")$(md5sum < "$WM")" ]' "$(cat "$PW")"
confere "a lista segue no HDMI-A-1" '[ "$(da_tela HDMI-A-1 | paste -sd,)" = "Pop,OS" ]'

printf '\nLVDS e DSI também são monitor interno\n'
for interno in LVDS-1 DSI-1; do
  printf '#!/bin/sh\nprintf "HDMI-A-1 (enabled)\\n  Make: LG\\n%s (enabled)\\n  Make: X\\n"\n' "$interno" > "$T/bin/cosmic-randr"
  semear
  da_conf aplicar >/dev/null
  confere "$interno recebe a lista" '[ "$(da_tela "$interno" | paste -sd,)" = "Pop,OS" ] && [ -z "$(da_tela HDMI-A-1)" ]' "$(cat "$PW")"
done
printf '#!/bin/sh\nprintf "HDMI-A-1 (enabled)\\n  Make: LG\\neDP-1 (enabled)\\n  Make: BOE\\nDP-9 (disabled)\\n"\n' > "$T/bin/cosmic-randr"

printf '\nsem nomes, o modo vale e os nomes não são tocados\n'
semear
antes_dos_pinos="$(md5sum < "$PW")"
saida="$(NOMES="" da_conf alfinetes)"; rc=$?
confere "o doctor vê o modo divergente mesmo sem nomes" '[ "$rc" = 1 ] && [ ! -e "$WM" ]' "rc=$rc $saida"
saida="$(NOMES="" da_conf refazer-alfinetes)"; rc=$?
confere "o conserto grava o Global sem nomes" '[ "$rc" = 1 ] && grep -q "workspace_mode: Global" "$WM"' "rc=$rc $saida"
saida="$(NOMES="" da_conf refazer-alfinetes)"; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ]' "rc=$rc $saida"
confere "e a lista de áreas fica como estava" '[ "$(md5sum < "$PW")" = "$antes_dos_pinos" ]' "$(cat "$PW")"
semear
NOMES="" da_conf aplicar >/dev/null
confere "o install também aplica o modo sem nomes" 'grep -q "workspace_mode: Global" "$WM"' "$(cat "$WM" 2>&1)"
semear
NOMES="" MODO_PADRAO="AREAS_ENCAIXE=sim" da_conf aplicar >/dev/null
confere "só o encaixe, sem nomes, também aplica o modo" 'grep -q "workspace_mode: Global" "$WM"' "$(cat "$WM" 2>&1)"
semear
saida="$(NOMES="" MODO_PADRAO="AREAS_ENCAIXE=sim" da_conf conferir)"
confere "e a conferência cobra o modo" 'printf "%s" "$saida" | grep -q workspace_mode' "$saida"
saida="$(MODO_PADRAO="AREAS_MODO=em-pares" da_conf aplicar)"; rc=$?
confere "um modo que não existe é recusado sem escrever" '[ "$rc" = 2 ] && [ ! -e "$WM" ]' "rc=$rc $saida"

printf '\no estado diz o modo do disco, não o do conf\n'
semear
saida="$(da_conf estado)"
confere "sem o arquivo do modo o estado diz independentes" 'printf "%s" "$saida" | grep -q "áreas independentes"' "$saida"
printf '(workspace_mode: Global, workspace_layout: Vertical, action_on_typing: None, workspace_wraparound: true)' > "$WM"
saida="$(MODO_PADRAO="AREAS_MODO=independentes" da_conf estado)"
confere "com Global no disco diz juntas, mesmo com o conf pedindo a outra" 'printf "%s" "$saida" | grep -q "áreas juntas"' "$saida"

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

printf '\nsem nomes o controle do painel continua valendo\n'
mkdir -p "$T/home/.config/meow"
apagado() { env -i PATH=/usr/bin:/bin HOME="$T/home" MEOW_RAIZ="$RAIZ" python3 -I - "$RAIZ/app" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import servidor
d = servidor._dominada_por("AREAS_MODO")
print(d["chave"] if d else "livre")
PY
}
printf 'AREAS_NOMES=""\n' > "$T/home/.config/meow/meow.conf"
confere "AREAS_NOMES vazio deixa o controle livre" '[ "$(apagado)" = livre ]' "$(apagado 2>&1)"
printf 'AREAS_NOMES="Pop, OS"\n' > "$T/home/.config/meow/meow.conf"
confere "com nomes o controle vale" '[ "$(apagado)" = livre ]' "$(apagado 2>&1)"

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'areas-em-cada-tela: tudo verde\n'; exit 0; fi
printf 'areas-em-cada-tela: %s falha(s)\n' "$falhas"; exit 1

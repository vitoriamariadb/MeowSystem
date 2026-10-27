#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/packs" "$T/xdg" "$T/home"

amb() { env MEOW_PACKS="$T/packs" XDG_DATA_HOME="$T/xdg" HOME="$T/home" MEOW_RAIZ="$RAIZ" "$@"; }
pack_py() { amb python3 "$RAIZ/scripts/pack.py" "$@"; }

pack_de_brinquedo() {
  local id="$1" d="$T/packs/$1"
  mkdir -p "$d/icones/apps"
  cp "$RAIZ/packs/dracula/paleta.json" "$d/paleta.json"
  printf '{"formato": 1, "id": "%s", "nome": "%s", "paleta": {"arquivo": "paleta.json"}, "icones": {"apps": {"mapa": "icones/apps.map"}}, "vitrine": {"capa": "logo.svg"}}\n' \
    "$id" "$id" > "$d/pack.json"
  : > "$d/icones/apps.map"
  amb python3 "$RAIZ/scripts/pack.py" logo-gerado "$d" > "$d/logo.svg" || return 2
  printf '%s' "$d"
}

for d in "$RAIZ"/packs/*/; do
  id="$(basename "$d")"
  saida="$(pack_py validar "$id" 2>&1)"; rc=$?
  [ "$rc" = "0" ] \
    && ok "pack $id valida, com as linhas do mapa de aplicativos conferidas" \
    || falha "pack $id não valida (rc=$rc)" "$saida"
done

for d in "$RAIZ"/packs/*/; do
  id="$(basename "$d")"
  linhas="$(pack_py fontes "$id" 2>"$T/erro")"
  [ -s "$T/erro" ] && falha "pack $id: o 'fontes' recusou linhas de mapa" "$(cat "$T/erro")"
  dup="$(printf '%s\n' "$linhas" | cut -f1 | grep . | sort | uniq -d)"
  [ -z "$dup" ] \
    && ok "pack $id: nenhum nome de scalable/apps com duas fontes ($(printf '%s\n' "$linhas" | grep -c .) nomes)" \
    || falha "pack $id: nome com mais de uma fonte — um nome, uma fonte:" "$dup"
  sem=""
  while IFS=$'\t' read -r nome fonte _; do
    [ -n "$nome" ] || continue
    case "$fonte" in /*) f="$fonte" ;; *) f="$RAIZ/$fonte" ;; esac
    [ -f "$f" ] || sem="$sem$nome -> $fonte
"
  done <<< "$linhas"
  [ -z "$sem" ] \
    && ok "pack $id: toda fonte nomeada existe no repositório" \
    || falha "pack $id: nome no mapa sem desenho no disco:" "$sem"
done

for nome in guvcview setup-mozc; do
  saida="$(ICONES_DRACULA=sim pack_py fonte "$nome" dracula 2>"$T/erro")"; rc=$?
  [ "$rc" = "0" ] && [ "$(printf '%s\n' "$saida" | grep -c .)" = "1" ] \
    && printf '%s' "$saida" | grep -q "	pack:dracula\$" && grep -q 'fica atrás' "$T/erro" \
    && ok "$nome com o Dracula no ar e a camada ligada: uma fonte, a do pack, e o resgate dito como atrás" \
    || falha "$nome com o Dracula no ar não tem o pack como fonte única (rc=$rc)" "$saida$(cat "$T/erro")"
  saida="$(ICONES_DRACULA=nao pack_py fonte "$nome" dracula 2>"$T/erro")"; rc=$?
  [ "$rc" = "0" ] && [ "$saida" = "$nome	packs/dracula/icones/apps/$nome.svg	resgatados" ] \
    && grep -q '(pack:dracula) fica atrás' "$T/erro" && grep -qF 'ICONES_DRACULA="nao"' "$T/erro" \
    && ok "$nome com o Dracula no ar e a camada desligada: a fonte é o resgate, e o pack dito como atrás" \
    || falha "$nome com a camada desligada não tem o resgate como fonte única (rc=$rc)" "$saida$(cat "$T/erro")"
  saida="$(pack_py fonte "$nome" catppuccin 2>/dev/null)"; rc=$?
  [ "$rc" = "1" ] && [ -z "$saida" ] \
    && ok "$nome com o Catppuccin no ar: o resgate do Dracula não veste o Catppuccin" \
    || falha "$nome com o Catppuccin no ar ainda tem fonte (rc=$rc)" "$saida"
done

saida="$(pack_py fonte net.waterfox.waterfox dracula 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ "$saida" = "net.waterfox.waterfox	packs/dracula/icones/apps/firefox.svg	pack:dracula" ] \
  && ok "o Waterfox tem uma fonte só, e ela é packs/dracula/icones/apps/firefox.svg" \
  || falha "a fonte do Waterfox não é a do pack (rc=$rc)" "$saida"

if sed -e 's/#.*//' "$RAIZ/packs/dracula/icones/apps-resgatados.map" | grep -q '^[[:space:]]*net\.waterfox\.waterfox[[:space:]]*:'; then
  falha "o apps-resgatados.map voltou a nomear o Waterfox — duas fontes para um nome"
else
  ok "o apps-resgatados.map não nomeia mais o Waterfox"
fi

grep -q '^| `icones/apps/firefox.svg` |' "$RAIZ/packs/dracula/PROCEDENCIA.md" \
  && ok "o Waterfox copiado tem linha de procedência no pack" \
  || falha "packs/dracula/PROCEDENCIA.md não tem a linha do Waterfox — arte copiada sem origem"

fora=""
for mapa in "$RAIZ"/assets/icones/*.map "$RAIZ"/packs/*/icones/*.map; do
  while IFS= read -r linha; do
    case "$mapa" in
      */packs/dracula/icones/apps-resgatados.map)
        nome="$(printf '%s' "$linha" | cut -d: -f1 | tr -d '[:space:]')"
        [ -f "$RAIZ/packs/dracula/icones/apps/$nome.svg" ] || fora="$fora${mapa#"$RAIZ"/}: $linha
" ;;
      *) fora="$fora${mapa#"$RAIZ"/}: $linha
" ;;
    esac
  done < <(sed -e 's/#.*//' "$mapa" | grep -E '~/\.local|/home/' || true)
done
[ -z "$fora" ] \
  && ok "nenhum mapa tem alvo na máquina; o que resta de '~/' é a procedência do resgate" \
  || falha "linha útil de mapa com caminho da máquina:" "$fora"

d="$(pack_de_brinquedo maquina)"
cp "$RAIZ/packs/dracula/icones/apps/steam.svg" "$d/icones/apps/steam.svg"
for alvo in '~/.local/share/icons/Dracula-Icones/scalable/apps/steam.png' \
            '/usr/share/icons/hicolor/scalable/apps/steam.svg' \
            'motor:/etc/passwd' 'pack:/etc:x.svg' 'pack:nao-existe:apps/x.svg'; do
  printf 'steam : %s\n' "$alvo" > "$d/icones/apps.map"
  saida="$(pack_py validar maquina 2>&1)"; rc=$?
  [ "$rc" = "1" ] \
    && ok "o validar recusa o alvo '$alvo'" \
    || falha "o validar aceitou um alvo fora das três casas: '$alvo' (rc=$rc)" "$saida"
done
printf 'steam : ~/x.svg\n' > "$d/icones/apps.map"
saida="$(pack_py validar maquina 2>&1)"
printf '%s' "$saida" | grep -q 'endereço desta máquina' \
  && ok "a recusa do '~/' diz que é endereço da máquina, e não 'desenho ausente'" \
  || falha "a recusa do '~/' não nomeia a causa" "$saida"

printf 'steam : pack:catppuccin:autorais/fogstripper-mocha.svg\n' > "$d/icones/apps.map"
saida="$(pack_py validar maquina 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "'pack:<id>:<caminho>' resolve dentro de <aquele pack>/icones/" \
  || falha "o prefixo pack: não resolveu um arquivo que existe (rc=$rc)" "$saida"
saida="$(printf 'pack:catppuccin:../../dracula/paleta.json\n' | pack_py alvo "$d/icones" 2>/dev/null)"
[ -z "$saida" ] \
  && ok "'pack:' que sai do outro pack é recusado, e a linha volta vazia" \
  || falha "o prefixo pack: deixou um alvo escapar" "$saida"

printf 'steam : apps/steam.svg\nsteam : apps/steam.svg\n' > "$d/icones/apps.map"
saida="$(pack_py validar maquina 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$saida" | grep -q 'já está na linha 1' \
  && ok "o mesmo nome duas vezes no mapa é recusa, e ela diz a linha" \
  || falha "o validar aceitou um nome repetido no mapa (rc=$rc)" "$saida"

saida="$(pack_py fonte steam maquina 2>/dev/null)"; rc=$?
[ "$rc" = "1" ] && [ "$(printf '%s\n' "$saida" | grep -c '^steam	')" = "2" ] \
  && ok "o 'fonte' mostra as duas fontes de um empate e sai 1" \
  || falha "o 'fonte' escondeu um empate dentro do mesmo mapa (rc=$rc)" "$saida"

d="$(pack_de_brinquedo herdeira)"
python3 - "$d/pack.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1])); p["heranca"] = "dracula"
json.dump(p, open(sys.argv[1], "w"))
PY
cp "$RAIZ/packs/dracula/icones/apps/luna.svg" "$d/icones/apps/luna.svg"
printf 'luna : apps/luna.svg\n' > "$d/icones/apps.map"
saida="$(ICONES_DRACULA=sim pack_py fonte luna herdeira 2>"$T/erro")"; rc=$?
[ "$rc" = "0" ] && [ "$saida" = "luna	$d/icones/apps/luna.svg	pack:herdeira" ] \
  && grep -q 'packs/dracula/icones/apps/luna.svg (resgatados) fica atrás' "$T/erro" \
  && ok "pack x resgate: o pack no ar vence, e o 'fonte' diz o resgate que ficou atrás" \
  || falha "o 'fonte' não aplicou a precedência pack x motor (rc=$rc)" "$saida$(cat "$T/erro")"

sh_pares="$(MAPA="$RAIZ/packs/dracula/icones/apps.map" ICONES_BASE_MAPA="$RAIZ/packs/dracula/icones" RAIZ="$RAIZ" \
  amb bash -c 'set -uo pipefail
  eval "$(sed -n "/^_dracula_pares_do_mapa() {\$/,/^}\$/p" "$RAIZ/scripts/icones_apps_dracula.sh")"
  _dracula_pares_do_mapa' 2>/dev/null | sort)"
py_pares="$(ICONES_DRACULA=sim pack_py fontes dracula 2>/dev/null | awk -F'\t' -v r="$RAIZ" '$3 ~ /^pack:/ {print $1 "\t" r "/" $2}' | sort)"
[ -n "$sh_pares" ] && [ "$sh_pares" = "$py_pares" ] \
  && ok "o parser do shell e o do pack.py leem o mapa do Dracula igual ($(printf '%s\n' "$py_pares" | grep -c .) linhas)" \
  || falha "os dois parsers do mapa discordam" "$(diff <(printf '%s\n' "$sh_pares") <(printf '%s\n' "$py_pares"))"

tema="$T/home/tema"
plano="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; . "$MEOW_RAIZ/lib/icones.sh"
  meow_icones_derivados "$1" net.waterfox.waterfox "$2"' _ "$RAIZ/packs/dracula/icones/apps/firefox.svg" "$tema")"
[ "$plano" = "scalable	$tema/scalable/apps/net.waterfox.waterfox.svg" ] \
  && ok "uma fonte SVG deriva o vetor em scalable/apps" \
  || falha "o plano de derivados não é o esperado" "$plano"
amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; . "$MEOW_RAIZ/lib/icones.sh"
  meow_icones_derivados "$1" x "$2"' _ "$RAIZ/assets/icones/resgatados-antes-e-depois.png" "$tema" >/dev/null 2>&1
[ "$?" = "2" ] \
  && ok "raster não é fonte: um PNG é recusado com 2" \
  || falha "o derivar aceitou um PNG como fonte"
r1="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; . "$MEOW_RAIZ/lib/icones.sh"
  meow_icones_derivar "$1" net.waterfox.waterfox "$2"; printf %s $?' _ "$RAIZ/packs/dracula/icones/apps/firefox.svg" "$tema" 2>/dev/null | tail -c1)"
r2="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; . "$MEOW_RAIZ/lib/icones.sh"
  meow_icones_derivar "$1" net.waterfox.waterfox "$2"; printf %s $?' _ "$RAIZ/packs/dracula/icones/apps/firefox.svg" "$tema" 2>/dev/null | tail -c1)"
[ "$r1" = "1" ] && [ "$r2" = "0" ] && [ -f "$tema/scalable/apps/net.waterfox.waterfox.svg" ] \
  && ok "o derivar escreve na primeira vez e não reescreve na segunda (1, depois 0)" \
  || falha "o derivar não é idempotente (primeira=$r1 segunda=$r2)"

printf 'FLAVOR="dracula"\nACCENT="mauve"\nICONES_DRACULA="sim"\n' > "$T/meow.conf"
saida="$(amb env MEOW_CONF="$T/meow.conf" "$RAIZ/bin/meow" icones fonte net.waterfox.waterfox 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && [ "$(printf '%s\n' "$saida" | sed -n 1p)" = "fonte: packs/dracula/icones/apps/firefox.svg" ] \
  && [ "$(printf '%s\n' "$saida" | sed -n 2p)" = "deriva: scalable" ] \
  && ok "meow icones fonte diz a fonte do Waterfox e o que deriva dela" \
  || falha "meow icones fonte não respondeu como a P28 pede (rc=$rc)" "$saida"

d="$(pack_de_brinquedo copia)"
origem="$T/origem/steam.svg"; mkdir -p "$T/origem"
cp "$RAIZ/packs/dracula/icones/apps/steam.svg" "$origem"
cp "$origem" "$d/icones/apps/steam.svg"
sha_reg="$(sha256sum "$origem" | cut -d' ' -f1)"
procedencia() {
  printf '# teste\n\n| arquivo | lido de | licença | copiado em | sha256 |\n|---|---|---|---|---|\n'
  printf '| `icones/apps/steam.svg` | `%s` | GPL-3.0 | 2026-09-23 | `%s` |\n' "$1" "$sha_reg"
}
procedencia "$origem" > "$d/PROCEDENCIA.md"

saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
[ "$rc" = "0" ] && printf '%s' "$saida" | grep -q '1 de 1 em dia' \
  && ok "cópia e origem iguais ao registro: em dia, 0" \
  || falha "sincronizar não reconheceu uma cópia em dia (rc=$rc)" "$saida"

printf '<!-- o upstream andou -->\n' >> "$origem"
antes="$(sha256sum "$d/icones/apps/steam.svg" | cut -d' ' -f1)"
saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
depois="$(sha256sum "$d/icones/apps/steam.svg" | cut -d' ' -f1)"
[ "$rc" = "1" ] && printf '%s' "$saida" | grep -q 'ORIGEM andou' && [ "$antes" = "$depois" ] \
  && ok "a origem andou: diz que andou, sai 1, e a cópia do pack fica intacta" \
  || falha "sincronizar com a origem nova (rc=$rc, cópia mudou? $([ "$antes" = "$depois" ] && echo não || echo SIM))" "$saida"
printf '%s' "$saida" | grep -q "cp '" \
  && ok "o gesto é impresso para quem decide, e não executado" \
  || falha "sincronizar não mostrou o comando do gesto" "$saida"

cp "$RAIZ/packs/dracula/icones/apps/steam.svg" "$origem"
printf '<!-- retoque daqui -->\n' >> "$d/icones/apps/steam.svg"
o_antes="$(sha256sum "$origem" | cut -d' ' -f1)"
saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$saida" | grep -q 'RETOCADA' \
  && [ "$(sha256sum "$origem" | cut -d' ' -f1)" = "$o_antes" ] \
  && grep -q 'retoque daqui' "$d/icones/apps/steam.svg" \
  && ok "retoque daqui: é dito como retoque, e nenhum dos dois lados é tocado" \
  || falha "sincronizar tratou mal uma cópia retocada (rc=$rc)" "$saida"

cp "$origem" "$d/icones/apps/steam.svg"; rm -f "$origem"
saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
[ "$rc" = "0" ] && printf '%s' "$saida" | grep -q 'não está nesta máquina' \
  && ok "origem fora desta máquina não é divergência: diz, e sai 0" \
  || falha "sincronizar tratou a origem ausente como divergência (rc=$rc)" "$saida"

printf '# teste\n\n| arquivo | lido de | licença | copiado em | sha256 |\n|---|---|---|---|---|\n| `icones/apps/steam.svg` |  | GPL-3.0 | 2026-09-24 | `%s` |\n' \
  "$sha_reg" > "$d/PROCEDENCIA.md"
saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
[ "$rc" = "0" ] && printf '%s' "$saida" | grep -q '1 só registro' \
  && ok "linha sem 'lido de' é só registro: nada a comparar, e sai 0" \
  || falha "sincronizar tratou a linha sem 'lido de' como divergência (rc=$rc)" "$saida"

procedencia "$T/home/.bashrc" > "$d/PROCEDENCIA.md"; : > "$T/home/.bashrc"
saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$saida" | grep -q 'não é o mesmo tipo de arquivo' \
  && ok "a coluna 'lido de' não abre arquivo de outro tipo (um pack de terceiro escreve o dado dele)" \
  || falha "sincronizar abriu uma origem de extensão diferente (rc=$rc)" "$saida"

icones_em() {
  local casa="$1" script="$2" verbo="$3"; shift 3
  env HOME="$casa" XDG_DATA_HOME="$T/xdg" MEOW_PACKS="$T/packs" MEOW_RAIZ="$RAIZ" \
      NOME_TEMA_ICONES="MeowSystem-Icons" ICONES_RESGATADOS="sim" "$@" \
      "$RAIZ/scripts/$script" "$verbo" >/dev/null 2>&1
}
veste() {
  local f="$1/.local/share/icons/MeowSystem-Icons/scalable/apps/$2.svg"
  [ -f "$f" ] && [ "$(cat "$f")" = "$(cat "$RAIZ/$3")" ]
}
DRACULA=(PACK=dracula FLAVOR=dracula ICONES_DRACULA=sim)
CATPPUCCIN=(PACK=meowsystem FLAVOR=mocha ICONES_DRACULA=sim)
DESLIGADO=(PACK=dracula FLAVOR=dracula ICONES_DRACULA=nao)
DO_PACK_G="packs/dracula/icones/apps/guvcview.svg"
DO_PACK_M="packs/dracula/icones/apps/setup-mozc.svg"
RESG_G="packs/dracula/icones/apps/guvcview.svg"
RESG_M="packs/dracula/icones/apps/setup-mozc.svg"

casa_a="$T/casa-dracula"; mkdir -p "$casa_a"
icones_em "$casa_a" icones_resgatados.sh --aplicar "${DRACULA[@]}"
icones_em "$casa_a" icones_apps_dracula.sh --aplicar "${DRACULA[@]}"
veste "$casa_a" guvcview "$DO_PACK_G" && veste "$casa_a" setup-mozc "$DO_PACK_M" \
  && ok "Dracula no ar: guvcview e setup-mozc vestem o desenho do Dracula" \
  || falha "Dracula no ar: o tema não tem o desenho do Dracula nos dois nomes"
icones_em "$casa_a" icones_resgatados.sh --conferir "${DRACULA[@]}"; r1=$?
icones_em "$casa_a" icones_apps_dracula.sh --conferir "${DRACULA[@]}"; r2=$?
[ "$r1" = "0" ] && [ "$r2" = "0" ] \
  && ok "Dracula no ar: os dois --conferir saem 0 — o doctor não troca um pelo outro" \
  || falha "Dracula no ar: um instalador acusa o arquivo do outro (resgate=$r1, dracula=$r2)"

casa_b="$T/casa-ao-contrario"; mkdir -p "$casa_b"
icones_em "$casa_b" icones_apps_dracula.sh --aplicar "${DRACULA[@]}"
icones_em "$casa_b" icones_resgatados.sh --aplicar "${DRACULA[@]}"
veste "$casa_b" guvcview "$DO_PACK_G" && veste "$casa_b" setup-mozc "$DO_PACK_M" \
  && ok "Dracula no ar, na ordem inversa: o mesmo desenho — não vence quem roda por último" \
  || falha "Dracula no ar: a ordem dos instaladores mudou o desenho"

icones_em "$casa_a" icones_resgatados.sh --aplicar "${DRACULA[@]}" ICONES_RESGATADOS=nao
veste "$casa_a" guvcview "$DO_PACK_G" && veste "$casa_a" setup-mozc "$DO_PACK_M" \
  && ok "ICONES_RESGATADOS=nao com o Dracula no ar não apaga o desenho do pack" \
  || falha "o remover do resgate apagou o desenho que é do pack"

icones_em "$casa_a" icones_resgatados.sh --aplicar "${DRACULA[@]}"
icones_em "$casa_a" icones_resgatados.sh --aplicar "${CATPPUCCIN[@]}"
icones_em "$casa_a" icones_apps_dracula.sh --aplicar "${CATPPUCCIN[@]}"
tema_a="$casa_a/.local/share/icons/MeowSystem-Icons/scalable/apps"
[ ! -e "$tema_a/guvcview.svg" ] && [ ! -e "$tema_a/setup-mozc.svg" ] && [ ! -e "$tema_a/luna.svg" ] \
  && ok "Catppuccin no ar (depois do Dracula): nem o desenho do Dracula nem o resgate ficam no tema" \
  || falha "Catppuccin no ar: sobrou desenho do Dracula no tema" "$(ls "$tema_a" 2>&1 | head)"
icones_em "$casa_a" icones_resgatados.sh --conferir "${CATPPUCCIN[@]}"; r1=$?
icones_em "$casa_a" icones_apps_dracula.sh --conferir "${CATPPUCCIN[@]}"; r2=$?
[ "$r1" = "0" ] && [ "$r2" = "0" ] \
  && ok "Catppuccin no ar: os dois --conferir saem 0" \
  || falha "Catppuccin no ar: divergência depois da troca (resgate=$r1, dracula=$r2)"

casa_c="$T/casa-desligada"; mkdir -p "$casa_c"
icones_em "$casa_c" icones_resgatados.sh --aplicar "${DESLIGADO[@]}"
icones_em "$casa_c" icones_apps_dracula.sh --aplicar "${DESLIGADO[@]}"
icones_em "$casa_c" icones_resgatados.sh --conferir "${DESLIGADO[@]}"; r1=$?
veste "$casa_c" guvcview "$RESG_G" && veste "$casa_c" setup-mozc "$RESG_M" && [ "$r1" = "0" ] \
  && ok "Dracula com ICONES_DRACULA=nao: o resgate veste os dois, e o --conferir sai 0" \
  || falha "Dracula desligado: o resgate não é a escolha (conferir=$r1)"
veste "$casa_c" uad-ng "packs/dracula/icones/apps/uad-ng.svg" \
  && ok "Dracula desligado: o uad-ng, que os dois mapas dão com os mesmos bytes, fica no tema" \
  || falha "Dracula desligado: o remover tirou o uad-ng, que é do resgate"

icones_em "$casa_b" icones_resgatados.sh --aplicar "${DESLIGADO[@]}"
icones_em "$casa_b" icones_apps_dracula.sh --aplicar "${DESLIGADO[@]}"
icones_em "$casa_b" icones_resgatados.sh --conferir "${DESLIGADO[@]}"; r1=$?
icones_em "$casa_b" icones_apps_dracula.sh --conferir "${DESLIGADO[@]}"; r2=$?
veste "$casa_b" guvcview "$RESG_G" && veste "$casa_b" setup-mozc "$RESG_M" \
  && [ "$r1" = "0" ] && [ "$r2" = "0" ] \
  && ok "a camada desligada depois de ligada: o resgate volta aos dois, e os dois --conferir saem 0" \
  || falha "a camada desligada depois de ligada não devolveu o resgate (resgate=$r1, dracula=$r2)"

amb env MEOW_PACK_DIR="$RAIZ/packs/dracula" PACK=dracula FLAVOR=dracula \
  python3 "$RAIZ/scripts/pack.py" novo derivado >/dev/null 2>&1
if python3 -c 'import json, sys; p = json.load(open(sys.argv[1]))
sys.exit(0 if p.get("heranca") == "dracula" and "icones" not in p else 1)' \
     "$T/packs/derivado/pack.json" 2>/dev/null; then
  DERIVADO=(PACK=derivado FLAVOR=dracula ICONES_DRACULA=sim)
  casa_d="$T/casa-derivada"; mkdir -p "$casa_d"
  icones_em "$casa_d" icones_resgatados.sh --aplicar "${DERIVADO[@]}"
  icones_em "$casa_d" icones_apps_dracula.sh --aplicar "${DERIVADO[@]}"
  icones_em "$casa_d" icones_resgatados.sh --conferir "${DERIVADO[@]}"; r1=$?
  icones_em "$casa_d" icones_apps_dracula.sh --conferir "${DERIVADO[@]}"; r2=$?
  veste "$casa_d" guvcview "$DO_PACK_G" && veste "$casa_d" setup-mozc "$DO_PACK_M" \
    && [ "$r1" = "0" ] && [ "$r2" = "0" ] \
    && ok "pack que herda o Dracula: o desenho do Dracula nos dois nomes, e os dois --conferir saem 0" \
    || falha "pack que herda o Dracula: o tema não tem o desenho do Dracula nos dois nomes (resgate=$r1, dracula=$r2)"
else
  falha "o 'pack.py novo' com o Dracula no ar não escreveu um pack que herda o Dracula sem declarar ícones" \
    "$(cat "$T/packs/derivado/pack.json" 2>&1)"
fi

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "um nome, uma fonte — e a fonte mora no repositório"
  exit 0
fi
printf 'FALHOU: %s conferência(s)\n' "$falhas" >&2
exit 1

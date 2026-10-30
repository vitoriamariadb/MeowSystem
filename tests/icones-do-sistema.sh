#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for c in sudo pkexec su; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/icones-do-sistema.sh\\n" >&2\nexit 1\n' "$c" > "$FALSO/$c"
  chmod 755 "$FALSO/$c"
done
CONTRATO="$RAIZ/assets/contratos/nomes-de-sistema.tsv"

amb() {
  local casa="$1" pack="$2" flavor="$3"; shift 3
  env -i PATH="$FALSO:$PATH" HOME="$casa" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" PACK="$pack" FLAVOR="$flavor" "$@"
}

n_contrato="$(grep -vc '^#' "$CONTRATO")"
[ "$n_contrato" -ge 168 ] \
  && ok "o contrato tem $n_contrato nomes de sistema" \
  || falha "o contrato encolheu" "$n_contrato"
python3 "$RAIZ/scripts/inventario_do_sistema.py" conferir >"$T/conferir" 2>&1 \
  && ok "o que os programas do COSMIC pedem cabe no contrato: $(tail -1 "$T/conferir")" \
  || falha "o COSMIC pede nome que o contrato não tem" "$(cat "$T/conferir")"

for par in meowsystem:mocha dracula:dracula; do
  pack="${par%%:*}"; flavor="${par#*:}"
  casa="$T/casa-$pack"; tema="$casa/.local/share/icons/MeowSystem-Icons"
  mkdir -p "$tema"
  printf '[Icon Theme]\nName=MeowSystem-Icons\nInherits=Papirus-Dark,breeze-dark,Cosmic,Adwaita,hicolor\nDirectories=scalable/apps\n' \
    > "$tema/index.theme"
  amb "$casa" "$pack" "$flavor" "$RAIZ/scripts/icones_sistema.sh" --aplicar >"$T/aplicar-$pack" 2>&1
  amb "$casa" "$pack" "$flavor" "$RAIZ/scripts/construir_icones.sh" indice >"$T/indice-$pack" 2>&1
  dirs="$(sed -n 's/^Directories=//p' "$tema/index.theme")"

  faltam=""; achados=0
  while IFS=$'\t' read -r nome ctx _resto; do
    case "$nome" in ''|'#'*) continue ;; esac
    if [ -f "$tema/scalable/$ctx/$nome.svg" ] && [ -f "$tema/22x22/$ctx/$nome.svg" ] \
       && [[ ",$dirs," == *",scalable/$ctx,"* ]] && [[ ",$dirs," == *",22x22/$ctx,"* ]]; then
      achados=$((achados + 1))
    else
      faltam="$faltam  $ctx/$nome
"
    fi
  done < "$CONTRATO"
  [ -z "$faltam" ] \
    && ok "$pack: os $achados nomes do contrato estão dentro do tema instalado (status, actions e devices, no índice), sem passar pela herança" \
    || falha "$pack: $achados de $n_contrato no tema; faltam:" "$faltam"

  if [ "$pack" = dracula ]; then
    grep -l currentColor "$tema"/*/{status,actions,devices}/*.svg >/dev/null 2>&1 \
      && falha "dracula: ficou currentColor sem pintar" \
      || ok "dracula: todo glifo saiu pintado com o text do flavor"
    grep -l 'stroke-width="4"\|stroke-width="2.5"' "$tema"/*/{status,actions,devices}/*.svg >/dev/null 2>&1 \
      && falha "dracula: o traço do MeowSystem foi injetado no preenchido do Dracula" \
      || ok "dracula: o preenchido do Dracula não recebe a espessura do traço"
  else
    grep -q 'stroke-width="4"' "$tema/22x22/status/network-wireless-signal-weak-symbolic.svg" \
      && grep -q 'stroke-width="2.5"' "$tema/scalable/status/network-wireless-signal-weak-symbolic.svg" \
      && ok "meowsystem: o traço sai com 4 em 22 px e 2,5 no escalável" \
      || falha "meowsystem: a espessura do traço não foi injetada"
  fi

  amb "$casa" "$pack" "$flavor" "$RAIZ/scripts/icones_sistema.sh" --conferir >/dev/null 2>&1
  [ $? = 0 ] && ok "$pack: a conferência depois de aplicar diz que está tudo no lugar" \
    || falha "$pack: a conferência diverge logo depois de aplicar"
  amb "$casa" "$pack" "$flavor" "$RAIZ/scripts/icones_sistema.sh" --aplicar >/dev/null 2>&1
  [ $? = 0 ] && ok "$pack: a segunda passada não escreve nada" \
    || falha "$pack: a segunda passada escreveu"
done

casa="$T/casa-meowsystem"; tema="$casa/.local/share/icons/MeowSystem-Icons"
mkdir -p "$tema/scalable/status"
cp "$tema/scalable/devices/display-symbolic.svg" "$tema/scalable/status/display-symbolic.svg"
amb "$casa" meowsystem mocha "$RAIZ/scripts/icones_sistema.sh" --aplicar >/dev/null 2>&1
[ ! -e "$tema/scalable/status/display-symbolic.svg" ] && [ -f "$tema/scalable/devices/display-symbolic.svg" ] \
  && ok "um nome que mudou de pasta sai da antiga (display: de status para devices)" \
  || falha "o display ficou também em status"

antes="$falhas"
for familia in network-wireless-signal- audio-volume- microphone-sensitivity- cosmic-applet-battery-level- \
               cosmic-applet-battery-display-brightness- cosmic-applet-bluetooth- cosmic-applet-notification system-; do
  for pack in meowsystem dracula; do
    mapa="$RAIZ/packs/$pack/icones/sistema.map"
    pede="$(grep -P "^\Q$familia" "$CONTRATO" | cut -f1 | sort)"
    tem="$(grep -v '^#' "$mapa" | cut -d: -f1 | grep -P "^\Q$familia" | sort)"
    [ "$pede" = "$tem" ] && [ -n "$pede" ] \
      || falha "$pack: a família $familia não está inteira no mapa" "$(comm -3 <(printf '%s\n' "$pede") <(printf '%s\n' "$tem"))"
  done
done
[ "$falhas" = "$antes" ] && ok "cada família de estado está inteira no mapa dos dois packs"

sem_nome="$(cd "$RAIZ/scripts" && python3 - <<'PY'
import sys
sys.argv = ["pack.py"]
import pack
rotulos = pack._rotulos_dos_tipos()
for pid in ("meowsystem", "dracula"):
    glifos = {g for _n, g, _c in pack._glifos_do_bloco(pack.achar(pid), "mimetypes")}
    if len(glifos) < 60:
        print(f"{pid}: só {len(glifos)} glifos de tipo de arquivo")
    for g in sorted(glifos - set(rotulos)):
        print(f"{pid}: {g}")
PY
)"
[ -z "$sem_nome" ] && ok "todo tipo de arquivo que a aba Sistema mostra nos dois packs tem nome em português no contrato" \
  || falha "glifo de tipo de arquivo sem nome em assets/contratos/tipos-de-arquivo.tsv" "$sem_nome"

if [ "$falhas" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
exit 0

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PALCO="$RAIZ/scripts/palco.sh"
T="$(mktemp -d)"
CURTO="$(mktemp -d /tmp/palco-teste.XXXXXX)"
export PALCO_DIR="$CURTO/p"
trap '"$PALCO" descer >/dev/null 2>&1; rm -rf "$T" "$CURTO"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }

for c in Xvfb dbus-run-session import compare identify zenity python3 busctl; do
  command -v "$c" >/dev/null || { echo "pulado: falta $c nesta máquina"; exit 0; }
done
[ -x /usr/bin/cosmic-comp ] || { echo "pulado: falta o cosmic-comp nesta máquina"; exit 0; }

UID_="$(id -u)"
RT_DELA="${XDG_RUNTIME_DIR:-/run/user/$UID_}"
WL_DELA=""
if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "$RT_DELA/$WAYLAND_DISPLAY" ]; then
  WL_DELA="$WAYLAND_DISPLAY"
else
  WL_DELA="$(find "$RT_DELA" -maxdepth 1 -type s -name 'wayland-[0-9]*' -printf '%f\n' 2>/dev/null | sort | head -n1)"
fi
sonda_dela() {
  env -i PATH="$PATH" HOME="$T/casa" XDG_RUNTIME_DIR="$RT_DELA" WAYLAND_DISPLAY="$WL_DELA" \
    python3 "$RAIZ/scripts/appid_sonda.py" --janelas 2>/dev/null
}

FALSO="$T/falso"; LOG="$T/falsos.log"; : > "$LOG"
mkdir -p "$FALSO" "$T/casa"
for c in sudo pkexec su pkill killall xdg-open notify-send systemd-run loginctl; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" "$(basename "$0")" "$*" >> "%s"\nexit 1\n' "$LOG" > "$FALSO/$c"
  chmod 755 "$FALSO/$c"
done
export HOME="$T/casa" PATH="$FALSO:$PATH"
unset DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR

echo "== o palco sobe sozinho, sem a sessão dela"
[ -n "$WL_DELA" ] && antes="$(sonda_dela)" || antes=""
saida="$("$PALCO" subir 2>&1)"; rc=$?
[ "$rc" = 0 ] && grep -q '^palco: tela=:' <<< "$saida" && ok "subir: $saida" || { falha "subir não subiu (rc=$rc): $saida"; exit 1; }
g1="$(sed -n 2p "$PALCO_DIR/grupos")"
"$PALCO" subir >/dev/null 2>&1; g2="$(sed -n 2p "$PALCO_DIR/grupos")"
[ -n "$g1" ] && [ "$g1" = "$g2" ] && ok "subir de novo reaproveita o mesmo compositor" || falha "subir de novo trocou o compositor ($g1 -> $g2)"
BUS="$(cat "$PALCO_DIR/barramento")"
case "$BUS" in */run/user/*|'') falha "o barramento do palco é o da sessão: $BUS" ;; *) ok "barramento próprio: ${BUS%%,*}" ;; esac
locks=""
for l in /tmp/.X[0-9]*-lock; do
  p="$(tr -dc '0-9' 2>/dev/null < "$l")"
  [ -n "$p" ] && tr '\0' '\n' 2>/dev/null < "/proc/$p/environ" | grep -qxF "MEOW_PALCO=$PALCO_DIR" && locks="$locks $l"
done

echo "== um app GTK roda no palco e só nele"
"$PALCO" foto "$T/vazio.png" || falha "a foto do palco vazio falhou"
TITULO="palco-prova-$$-$RANDOM"
pid="$("$PALCO" rodar zenity --info --title="$TITULO" --text=palco)"
achou=""
for _ in $(seq 80); do
  achou="$("$PALCO" janelas 2>/dev/null | grep -F "$TITULO")" && break
  sleep 0.25
done
[ "$achou" = "zenity	$TITULO" ] && ok "a sonda do palco lista a janela com o app_id zenity" || falha "a janela não apareceu no palco: «$achou»"
amb="$(tr '\0' '\n' 2>/dev/null < "/proc/$pid/environ")"
grep -qxF "XDG_RUNTIME_DIR=$PALCO_DIR/rt" <<< "$amb" && grep -qxF "DBUS_SESSION_BUS_ADDRESS=$BUS" <<< "$amb" \
  && grep -qxF "HOME=$PALCO_DIR/casa" <<< "$amb" && ! grep -q '=/run/user/' <<< "$amb" \
  && ok "o app vê só a tela, o barramento e a casa do palco" || falha "o ambiente do app vaza a sessão: $(grep -E 'XDG_RUNTIME_DIR|DBUS|HOME|WAYLAND' <<< "$amb" | tr '\n' ' ')"
busctl --address="${BUS%%,*}" list --no-legend 2>/dev/null | awk '{print $2}' | grep -qx "$pid" \
  && ok "o app falou com o barramento do palco" || falha "o app não aparece no barramento do palco"
if [ -n "$WL_DELA" ]; then
  depois="$(sonda_dela)"
  if grep -qF "$TITULO" <<< "$depois"; then
    falha "a janela de prova apareceu na sessão dela"
  else
    ok "a sessão dela não ganhou a janela de prova ($(grep -c . <<< "$antes") janela(s) antes, $(grep -c . <<< "$depois") depois)"
  fi
else
  ok "nenhuma sessão gráfica nesta máquina para comparar; o app só tem o ambiente do palco"
fi
"$PALCO" foto "$T/com.png" || falha "a foto com o app falhou"
tam="$(identify -format '%wx%h' "$T/com.png" 2>/dev/null)"
dif="$(compare -metric AE "$T/vazio.png" "$T/com.png" null: 2>&1)"
[ "$tam" = "${PALCO_TELA:-1280x800}" ] && [ "${dif%% *}" != 0 ] \
  && ok "a foto do palco tem ${tam} e mostra a janela ($dif pixels mudaram)" || falha "foto errada: tamanho $tam, diferença $dif"
"$PALCO" foto "$T/recorte.png" 200x100+0+0 && [ "$(identify -format '%wx%h' "$T/recorte.png" 2>/dev/null)" = 200x100 ] \
  && ok "a foto recorta" || falha "o recorte da foto falhou"

echo "== a trava recusa o barramento dela"
cp "$PALCO_DIR/barramento" "$T/barramento"
printf 'unix:path=/run/user/%s/bus\n' "$UID_" > "$PALCO_DIR/barramento"
msg="$("$PALCO" rodar true 2>&1)"; rc=$?
[ "$rc" != 0 ] && grep -q recuso <<< "$msg" && ok "rodar recusa: $msg" || falha "rodar aceitou o barramento dela (rc=$rc)"
cp "$T/barramento" "$PALCO_DIR/barramento"

echo "== descer mata só o que o palco subiu"
"$PALCO" descer; rc=$?
[ "$rc" = 0 ] && ok "descer saiu limpo" || falha "descer falhou (rc=$rc)"
sobra=""
for p in /proc/[0-9]*; do
  tr '\0' '\n' 2>/dev/null < "$p/environ" | grep -qxF "MEOW_PALCO=$PALCO_DIR" && sobra="$sobra ${p#/proc/}"
done
[ -z "$sobra" ] && ok "nenhum processo do palco sobrou" || falha "sobrou processo do palco:$sobra"
[ ! -e "$PALCO_DIR" ] && ok "a pasta do palco sumiu" || falha "a pasta do palco ficou"
fic=""; for l in $locks; do [ -e "$l" ] && fic="$fic $l"; done
[ -n "$locks" ] && [ -z "$fic" ] && ok "as telas X do palco foram soltas:$locks" || falha "telas X do palco presas: ${fic:-nenhuma achada antes}"
"$PALCO" descer && ok "descer sem palco não é erro" || falha "descer sem palco deu erro"
[ ! -s "$LOG" ] && ok "nenhum sudo, pkill nem killall" || falha "o palco chamou: $(sort -u "$LOG" | tr '\n' ' ')"

if [ "$falhas" = 0 ]; then echo "palco: tudo certo"; exit 0; fi
echo "palco: $falhas falha(s)"; exit 1

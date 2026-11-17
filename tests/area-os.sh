#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PALCO="$RAIZ/scripts/palco.sh"
PATCH="$RAIZ/patches/cosmic-comp-area-do-cliente.patch"
BASE=AURORA-AREA-DO-CLIENTE
MARCA=$BASE-1
T="$(mktemp -d)"
CURTO="$(mktemp -d /tmp/area-os-teste.XXXXXX)"
export PALCO_DIR="$CURTO/p"
trap '"$PALCO" descer >/dev/null 2>&1; rm -rf "$T" "$CURTO"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
pula()  { printf 'pulado: %s\n' "$*"; }

echo "== a série"
grep -qE "^req[[:space:]]+cosmic-comp-area-do-cliente\.patch[[:space:]]+$BASE\$" "$RAIZ/patches/series" \
  && ok "o patch é req, com marcador próprio" || falha "o patch não está na série como req"
grep -qF "\"$MARCA\"" "$PATCH" && grep -q '^+#\[used\]' "$PATCH" \
  && ok "o marcador sobrevive ao linker" || falha "falta o marcador com #[used]"

echo "== o patch"
grep -qF 'variavel_do_ambiente(&ambiente, "MEOW_AREA")?' "$PATCH" && grep -qF 'variavel_do_ambiente(&ambiente, "MEOW_TELA")' "$PATCH" \
  && grep -qF 'format!("/proc/{pid}/environ")' "$PATCH" \
  && ok "lê MEOW_AREA e MEOW_TELA do ambiente do processo do cliente" || falha "o patch não lê o ambiente do cliente"
grep -qF '.get_client_credentials(cliente.id())' "$PATCH" && grep -qF 'window.x11_surface()?.pid()?' "$PATCH" \
  && ok "o pid vem das credenciais do soquete, e do _NET_WM_PID no X11" || falha "o pid do cliente não vem das credenciais"
grep -A3 '^+        let area_marcada = parent_placement$' "$PATCH" | grep -q 'is_none()' \
  && ok "janela filha segue a mãe: só a de primeiro nível lê a área" || falha "a janela filha também lê a área"
grep -A1 '^+        let was_activated = !marcada$' "$PATCH" | grep -q 'workspace_handle.is_some()' \
  && ok "a marcada não marca urgente" || falha "a marcada ainda pode marcar urgente"
sed -n '/^+        } else if marcada {$/,/^+            None$/p' "$PATCH" > "$T/ramo"
grep -q 'append_focus_stack' "$T/ramo" && ! grep -qE 'add_workspace_state|KeyboardFocusTarget|set_active|activate' "$T/ramo" \
  && ok "a marcada entra na pilha da área dela sem foco, sem urgente e sem trocar a área visível" || falha "o ramo da marcada mexe no foco ou na área"
grep -A8 '^+        let area_marcada = parent_placement$' "$PATCH" | grep -q 'active_space(saida)' \
  && ok "a área que já está na tela ativa fica na fábrica, com o foco" || falha "a marcada nasce sem foco na área que está na tela"
grep -A12 '^+++ b/src/xwayland.rs$' "$PATCH" | grep -qF '.area_do_cliente(&CosmicSurface::from(window.clone()), &output)' \
  && ok "o _NET_ACTIVE_WINDOW da marcada fora da área visível é ignorado" || falha "o pedido de ativação X11 da marcada troca a área"
grep -q '"MEOW_AREA sem área com esse nome: a janela nasce na área ativa"' "$PATCH" \
  && ok "nome que não existe: fábrica e uma linha no log" || falha "nome que não existe some calado"
sed '/^+#\[cfg(test)\]$/,$d' "$PATCH" | grep -E '^\+' | grep -qiE 'zenity|chrome|firefox|"OS"|"Pop"' \
  && falha "o código do patch cita um app ou uma área" || ok "o código do patch não cita app nem área"

echo "== a escolha, compilada do próprio patch"
export RUSTUP_HOME="${RUSTUP_HOME:-${SUITE_CASA_REAL:-$HOME}/.rustup}"
if ! rustc --version >/dev/null 2>&1; then
  pula "sem rustc nesta máquina: a escolha não foi compilada"
else
  sed -n '/^+fn variavel_do_ambiente/,/^+}$/p;/^+fn area_escolhida/,/^+}$/p;/^+#\[cfg(test)\]$/,/^+}$/p' "$PATCH" \
    | sed 's/^+//' > "$T/area.rs"
  if rustc --edition 2021 --test -o "$T/area" "$T/area.rs" > "$T/rustc" 2>&1 && "$T/area" > "$T/saida" 2>&1; then
    grep -q 'test result: ok. 7 passed' "$T/saida" && ok "$(grep 'test result' "$T/saida")" \
      || falha "os testes do patch não são os 7: $(grep 'test result' "$T/saida")"
  else
    falha "a escolha não passou: $(cat "$T/rustc" "$T/saida" 2>/dev/null)"
  fi
fi

echo "== rodar --area recusa sem saber onde"
msg="$(env -u WAYLAND_DISPLAY "$PALCO" rodar --area OS true 2>&1)"; rc=$?
[ "$rc" != 0 ] && grep -q 'recuso' <<< "$msg" && ok "sem sessão: $msg" || falha "rodar --area sem sessão (rc=$rc): $msg"
for args in "--area" "--area OS" "--area OS --tela" "--area --tela X true"; do
  msg="$(WAYLAND_DISPLAY=x XDG_RUNTIME_DIR="$T" "$PALCO" rodar $args 2>&1)"; rc=$?
  [ "$rc" != 0 ] && grep -q 'uso: palco.sh rodar --area' <<< "$msg" && ok "«rodar $args» pede o uso" || falha "«rodar $args» (rc=$rc): $msg"
done

for c in Xvfb dbus-run-session zenity python3 ss import compare; do
  command -v "$c" >/dev/null || { pula "falta $c: o palco não sobe"; c=""; break; }
done
[ -n "${c:-}" ] || { [ "$falhas" = 0 ] && { echo "area-os: tudo certo, sem o palco"; exit 0; }; echo "area-os: $falhas falha(s)"; exit 1; }

ORIGEM_DELA="${SUITE_CASA_REAL:-$HOME}"
COMP="${AREA_OS_COMPOSITOR:-}"
if [ -z "$COMP" ]; then
  COMP="$(command -v cosmic-comp 2>/dev/null)" || COMP=/usr/bin/cosmic-comp
  grep -qs 'MEOW-COSMIC-COMP-SHIM' "$COMP" && COMP="$(HOME="$ORIGEM_DELA" MEOW_SHIM_SO_DIZER=1 "$COMP")"
fi
[ -x "$COMP" ] || { pula "falta o compositor ($COMP)"; COMP=""; }

FALSO="$T/falso"; LOG="$T/falsos.log"; : > "$LOG"
mkdir -p "$FALSO"
for c in sudo pkexec su pkill killall xdg-open notify-send systemd-run loginctl; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" "$(basename "$0")" "$*" >> "%s"\nexit 1\n' "$LOG" > "$FALSO/$c"
  chmod 755 "$FALSO/$c"
done
export PATH="$FALSO:$PATH"
unset DBUS_SESSION_BUS_ADDRESS WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR

ORIGEM="$T/origem"
PIN="$ORIGEM/.config/cosmic/com.system76.CosmicComp/v1"
mkdir -p "$PIN"
area() {
  printf '    (\n        output: (\n            name: "WINIT-0",\n            edid: None,\n        ),\n'
  printf '        tiling_enabled: true,\n        id: Some("%s"),\n        name: Some(" %s "),\n    ),\n' "$1" "$2"
}
{ echo '['; area a0e001 Pop; area a0e002 OS; echo ']'; } > "$PIN/pinned_workspaces"
printf '(workspace_mode: Global, workspace_layout: Vertical, action_on_typing: None, workspace_wraparound: true)\n' > "$PIN/workspaces"
export PALCO_ORIGEM="$ORIGEM" PALCO_COMPOSITOR="$COMP"

areas() { "$PALCO" areas 2>/dev/null; }
esperar() {
  local _
  for _ in $(seq 80); do
    areas | awk -F'\t' -v t="$1" '$1 == "janela" && $3 == t && $4 != "-"' | grep . && return 0
    sleep 0.25
  done
  return 1
}
sessao_do_palco() {
  env -i PATH="$PATH" HOME="$PALCO_DIR/casa" PALCO_DIR="$PALCO_DIR" MEOW_PALCO="$PALCO_DIR" \
    XDG_RUNTIME_DIR="$PALCO_DIR/rt" WAYLAND_DISPLAY="$(cat "$PALCO_DIR/wayland")" \
    DBUS_SESSION_BUS_ADDRESS="$(cat "$PALCO_DIR/barramento")" "$@"
}

if [ -n "$COMP" ] && ! grep -qaF "$BASE" "$COMP"; then
  echo "== o compositor sem o patch: rodar --area recusa"
  "$PALCO" subir >/dev/null 2>&1 || falha "o palco não subiu com $COMP"
  msg="$(sessao_do_palco "$PALCO" rodar --area OS zenity --info --title="area-os-recusa-$$" 2>&1)"; rc=$?
  [ "$rc" != 0 ] && grep -q 'não faz a janela nascer na área' <<< "$msg" && ! areas | grep -qF "area-os-recusa-$$" \
    && ok "recusa e não abre nada: $msg" || falha "rodar --area aceitou um compositor sem o patch (rc=$rc): $msg"
  "$PALCO" descer
  pula "o build do compositor ($COMP) ainda não traz o $BASE: a prova da área fica para o build com o patch (AREA_OS_COMPOSITOR=<binário> para apontar outro)"
  COMP=""
fi

if [ -n "$COMP" ]; then
  echo "== no palco headless, com o $BASE ($COMP)"
  "$PALCO" subir >/dev/null 2>&1 || { falha "o palco não subiu com $COMP"; exit 1; }
  a="$(areas)"
  grep -qxF "area	Pop	ativa" <<< "$a" && grep -qxF "area	OS	-" <<< "$a" \
    && ok "duas áreas com nome, a ativa é Pop" || falha "as áreas do palco não são Pop e OS: $(tr '\n' ' ' <<< "$a")"

  "$PALCO" rodar zenity --info --title="area-pop-$$" --text=pop >/dev/null
  j="$(esperar "area-pop-$$")"
  [ "$j" = "janela	zenity	area-pop-$$	Pop	foco" ] && ok "sem variável, nada muda: nasce em Pop e ganha o foco" || falha "a janela sem variável: «$j»"
  sleep 1
  "$PALCO" foto "$T/antes.png"

  pid="$(sessao_do_palco "$PALCO" rodar --area OS zenity --info --title="area-os-$$" --text=os)"; rc=$?
  [ "$rc" = 0 ] && [ -n "$pid" ] && ok "rodar --area OS aceitou o compositor com o patch" || falha "rodar --area OS recusou (rc=$rc): $pid"
  j="$(esperar "area-os-$$")"
  [ "$j" = "janela	zenity	area-os-$$	OS	-" ] && ok "a marcada nasce em OS, sem o foco" || falha "a marcada: «$j»"
  tr '\0' '\n' 2>/dev/null < "/proc/$pid/environ" | grep -qxF 'MEOW_AREA=OS' \
    && ok "o app leva MEOW_AREA=OS no ambiente" || falha "o app não leva MEOW_AREA=OS"
  a="$(areas)"
  grep -qxF "area	Pop	ativa" <<< "$a" && grep -qxF "area	OS	-" <<< "$a" \
    && ok "a área visível segue Pop, e OS não fica urgente" || falha "as áreas mudaram: $(grep '^area' <<< "$a" | tr '\n' ' ')"
  grep -qxF "janela	zenity	area-pop-$$	Pop	foco" <<< "$a" \
    && ok "o foco segue na janela que o tinha" || falha "o foco saiu de area-pop: $(grep '^janela' <<< "$a" | tr '\n' ' ')"
  sleep 1
  "$PALCO" foto "$T/depois.png"
  dif="$(compare -metric AE "$T/antes.png" "$T/depois.png" null: 2>&1)"
  [ "${dif%% *}" = 0 ] && ok "a tela de Pop não mudou um pixel" || falha "a tela de Pop mudou ($dif pixels)"

  "$PALCO" rodar env GDK_BACKEND=x11 MEOW_AREA=OS zenity --info --title="area-x11-$$" --text=x11 >/dev/null
  j="$(esperar "area-x11-$$")"
  [ "$j" = "janela	zenity	area-x11-$$	OS	-" ] && areas | grep -qxF "janela	zenity	area-pop-$$	Pop	foco" \
    && ok "no X11, pelo _NET_WM_PID, também nasce em OS e o foco fica" || falha "a marcada no X11: «$j»"
  if command -v xdotool >/dev/null; then
    "$PALCO" rodar xdotool search --name "area-x11-$$" windowactivate >/dev/null
    sleep 1
    a="$(areas)"
    grep -qxF "area	Pop	ativa" <<< "$a" && grep -qxF "janela	zenity	area-x11-$$	OS	-" <<< "$a" \
      && ok "o _NET_ACTIVE_WINDOW da marcada não leva a tela para OS" || falha "a ativação X11 trocou a área: $(tr '\n' ' ' <<< "$a")"
  else
    pula "falta xdotool: a ativação X11 da marcada não foi provada"
  fi

  msg="$(sessao_do_palco "$PALCO" rodar --area Pop true 2>&1)"; rc=$?
  [ "$rc" != 0 ] && grep -q 'é a que está na tela' <<< "$msg" && ok "a área visível é recusada: $msg" || falha "rodar --area aceitou a área visível (rc=$rc): $msg"
  msg="$(sessao_do_palco "$PALCO" rodar --area Jogos true 2>&1)"; rc=$?
  [ "$rc" != 0 ] && grep -q 'não tem área «Jogos»' <<< "$msg" && ok "área que não existe é recusada: $msg" || falha "rodar --area aceitou área que não existe (rc=$rc): $msg"

  "$PALCO" rodar env MEOW_AREA=OS MEOW_TELA=WINIT-0 zenity --info --title="area-tela-$$" --text=tela >/dev/null
  j="$(esperar "area-tela-$$")"
  [ "$j" = "janela	zenity	area-tela-$$	OS	-" ] && ok "MEOW_TELA com a tela certa: nasce em OS" || falha "com MEOW_TELA: «$j»"
  "$PALCO" rodar env MEOW_AREA=OS MEOW_TELA=DP-9 zenity --info --title="area-sem-tela-$$" --text=x >/dev/null
  j="$(esperar "area-sem-tela-$$")"
  [ "$j" = "janela	zenity	area-sem-tela-$$	Pop	foco" ] && ok "tela que não existe: comportamento de fábrica" || falha "tela que não existe: «$j»"
  "$PALCO" rodar env MEOW_AREA=Jogos zenity --info --title="area-jogos-$$" --text=x >/dev/null
  j="$(esperar "area-jogos-$$")"
  [ "$j" = "janela	zenity	area-jogos-$$	Pop	foco" ] && ok "nome que não existe: comportamento de fábrica" || falha "nome que não existe: «$j»"
  [ "$(grep -c 'MEOW_AREA sem área com esse nome' "$PALCO_DIR/compositor.log")" = 2 ] \
    && ok "e uma linha no log para cada uma" || falha "o log do compositor não diz: $(grep -c 'MEOW_AREA' "$PALCO_DIR/compositor.log")"
  "$PALCO" rodar env MEOW_AREA=Pop zenity --info --title="area-visivel-$$" --text=x >/dev/null
  j="$(esperar "area-visivel-$$")"
  [ "$j" = "janela	zenity	area-visivel-$$	Pop	foco" ] && ok "a área que está na tela: comportamento de fábrica, com o foco" || falha "a área que está na tela: «$j»"

  "$PALCO" ativar OS || falha "o palco não trocou para OS"
  sleep 1
  a="$(areas)"
  grep -qxF "area	OS	ativa" <<< "$a" && grep -qxF "janela	zenity	area-tela-$$	OS	foco" <<< "$a" \
    && ok "ao ir até OS, a última marcada tem o foco" || falha "em OS: $(tr '\n' ' ' <<< "$a")"
  "$PALCO" foto "$T/os.png"
  dif="$(compare -metric AE "$T/antes.png" "$T/os.png" null: 2>&1)"
  [ "${dif%% *}" != 0 ] && ok "a tela de OS mostra as marcadas ($dif pixels de diferença)" || falha "a tela de OS é a de Pop"
  "$PALCO" rodar env MEOW_AREA=OS zenity --info --title="area-os-visivel-$$" --text=x >/dev/null
  j="$(esperar "area-os-visivel-$$")"
  [ "$j" = "janela	zenity	area-os-visivel-$$	OS	foco" ] && ok "com OS na tela, a janela nova do app marcado ganha o foco" || falha "com OS na tela: «$j»"
  [ -n "${AREA_OS_FOTOS:-}" ] && mkdir -p "$AREA_OS_FOTOS" && cp "$T/depois.png" "$AREA_OS_FOTOS/pop.png" && cp "$T/os.png" "$AREA_OS_FOTOS/os.png"
  "$PALCO" descer
fi

[ ! -s "$LOG" ] && ok "nenhum sudo, pkill nem killall" || falha "o teste chamou: $(sort -u "$LOG" | tr '\n' ' ')"

if [ "$falhas" = 0 ]; then echo "area-os: tudo certo"; exit 0; fi
echo "area-os: $falhas falha(s)"; exit 1

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

for c in Xvfb dbus-run-session import compare identify convert zenity xmessage python3 busctl; do
  command -v "$c" >/dev/null || { echo "pulado: falta $c nesta máquina"; exit 0; }
done
[ -x /usr/bin/cosmic-comp ] || { echo "pulado: falta o cosmic-comp nesta máquina"; exit 0; }

UID_="$(id -u)"
RT_DELA="${XDG_RUNTIME_DIR:-/run/user/$UID_}"
BUS_DELA="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$RT_DELA/bus}"
ORIGEM_DELA="${SUITE_CASA_REAL:-$HOME}"
COMP="$(command -v cosmic-comp 2>/dev/null)" || COMP=/usr/bin/cosmic-comp
grep -qs 'MEOW-COSMIC-COMP-SHIM' "$COMP" && COMP="$(HOME="$ORIGEM_DELA" MEOW_SHIM_SO_DIZER=1 "$COMP")"
export PALCO_COMPOSITOR="$COMP"
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
nomes_no_barramento_dela() {
  busctl --address="${BUS_DELA%%,*}" list --no-legend --no-pager 2>/dev/null | awk '$2 ~ /^[0-9]+$/ { print $2 }' | sort -u
}
conferir_sessao_dela() {
  local depois novos
  if [ -z "$WL_DELA" ]; then
    ok "nenhuma sessão gráfica nesta máquina para comparar; o app só tem o ambiente do palco"
    return
  fi
  depois="$(sonda_dela)"
  novos="$(comm -13 <(cut -f1 <<< "$antes" | sort -u) <(cut -f1 <<< "$depois" | sort -u) | grep -ixE 'zenity|xmessage')"
  [ -n "$depois" ] && ! grep -qF -e "$TITULO" -e "palco-ssd-$$" <<< "$depois" && [ -z "$novos" ] \
    && ok "a sessão dela não ganhou toplevel do palco, com $1 aberto(s) ($(grep -c . <<< "$antes") janela(s) antes, $(grep -c . <<< "$depois") depois)" \
    || falha "a sessão dela ganhou toplevel do palco: $(grep -F -e "$TITULO" -e "palco-ssd-$$" <<< "$depois") $novos"
}
esperar_janela() {
  local _
  for _ in $(seq 80); do
    "$PALCO" janelas 2>/dev/null | grep -F "$1" && return 0
    sleep 0.25
  done
  return 1
}
caixa_da_janela() {
  convert "$1" "$2" -compose difference -composite -colorspace gray -threshold 8% -format '%@' info: 2>/dev/null
}
recorte() {
  local caixa="$2" w h x y
  w="${caixa%%x*}"; h="${caixa#*x}"; h="${h%%+*}"; x="${caixa#*+}"; x="${x%%+*}"; y="${caixa##*+}"
  [ "$3" = direita ] && x=$((x + w - 160))
  convert "$1" -crop "160x56+$x+$y" +repage "$4"
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
antes=""; bus_antes=""
if [ -n "$WL_DELA" ]; then
  antes="$(sonda_dela)" && [ -n "$antes" ] && ok "a sonda lê a sessão dela ($(grep -c . <<< "$antes") janela(s))" \
    || { falha "a sonda não leu a sessão dela ($WL_DELA): a prova de vazamento seria vazia"; exit 1; }
  bus_antes="$(nomes_no_barramento_dela)"
  [ -n "$bus_antes" ] && ok "o barramento dela responde à leitura" || { falha "não li o barramento dela (${BUS_DELA%%,*})"; exit 1; }
fi
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
achou="$(esperar_janela "$TITULO")"
[ "$achou" = "zenity	$TITULO" ] && ok "a sonda do palco lista a janela com o app_id zenity" || falha "a janela não apareceu no palco: «$achou»"
amb="$(tr '\0' '\n' 2>/dev/null < "/proc/$pid/environ")"
grep -qxF "XDG_RUNTIME_DIR=$PALCO_DIR/rt" <<< "$amb" && grep -qxF "DBUS_SESSION_BUS_ADDRESS=$BUS" <<< "$amb" \
  && grep -qxF "HOME=$PALCO_DIR/casa" <<< "$amb" && ! grep -q '=/run/user/' <<< "$amb" \
  && ok "o app vê só a tela, o barramento e a casa do palco" || falha "o ambiente do app vaza a sessão: $(grep -E 'XDG_RUNTIME_DIR|DBUS|HOME|WAYLAND' <<< "$amb" | tr '\n' ' ')"
busctl --address="${BUS%%,*}" list --no-legend 2>/dev/null | awk '{print $2}' | grep -qx "$pid" \
  && ok "o app falou com o barramento do palco" || falha "o app não aparece no barramento do palco"
if [ -n "$WL_DELA" ]; then
  nossos=""
  for b in $(nomes_no_barramento_dela); do
    grep -qx "$b" <<< "$bus_antes" && continue
    tr '\0' '\n' 2>/dev/null < "/proc/$b/environ" | grep -q '^MEOW_PALCO=' && nossos="$nossos $b"
  done
  [ -z "$nossos" ] && ! nomes_no_barramento_dela | grep -qx "$pid" \
    && ok "o barramento dela não viu o app nem nada do palco" || falha "o palco falou com o barramento dela:$nossos"
fi
"$PALCO" foto "$T/com.png" || falha "a foto com o app falhou"
tam="$(identify -format '%wx%h' "$T/com.png" 2>/dev/null)"
dif="$(compare -metric AE "$T/vazio.png" "$T/com.png" null: 2>&1)"
[ "$tam" = "${PALCO_TELA:-1280x800}" ] && [ "${dif%% *}" != 0 ] \
  && ok "a foto do palco tem ${tam} e mostra a janela ($dif pixels mudaram)" || falha "foto errada: tamanho $tam, diferença $dif"
"$PALCO" foto "$T/recorte.png" 200x100+0+0 && [ "$(identify -format '%wx%h' "$T/recorte.png" 2>/dev/null)" = 200x100 ] \
  && ok "a foto recorta" || falha "o recorte da foto falhou"

echo "== a foto sai com a arte do pack no SSD do COSMIC"
P1="$PALCO_DIR"
if [ -s "$ORIGEM_DELA/.config/meow/meow.conf" ] && [ -d "$ORIGEM_DELA/.config/cosmic" ]; then
  CRU="$T/origem-cru"
  for rel in .config/gtk-3.0 .config/gtk-4.0 .config/cosmic .config/dconf .config/meow/meow.conf; do
    [ -e "$ORIGEM_DELA/$rel" ] && mkdir -p "$CRU/$(dirname "$rel")" && cp -rL "$ORIGEM_DELA/$rel" "$CRU/$(dirname "$rel")/" 2>/dev/null
  done
  for lado in cru pack; do
    export PALCO_DIR="$CURTO/$lado"
    [ "$lado" = cru ] && export PALCO_ORIGEM="$CRU" || export PALCO_ORIGEM="$ORIGEM_DELA"
    "$PALCO" subir >/dev/null 2>&1 || falha "o palco $lado não subiu"
    "$PALCO" foto "$T/$lado-vazio.png"
    "$PALCO" rodar xmessage -geometry 520x200+60+60 -title "palco-ssd-$$" "SSD do COSMIC" >/dev/null
    esperar_janela "palco-ssd-$$" >/dev/null || falha "o xmessage não abriu no palco $lado"
    for _ in $(seq 20); do
      sleep 0.25
      "$PALCO" foto "$T/$lado.png"
      caixa="$(caixa_da_janela "$T/$lado-vazio.png" "$T/$lado.png")"
      [ -n "$caixa" ] && [ "${caixa%%x*}" -gt 300 ] && break
    done
    printf '%s\n' "$caixa" > "$T/$lado.caixa"
    recorte "$T/$lado.png" "$caixa" direita "$T/$lado-botoes.png"
    recorte "$T/$lado.png" "$caixa" esquerda "$T/$lado-canto.png"
  done
  conferir_sessao_dela "zenity e dois xmessage"
  botoes="$(compare -metric AE -fuzz 6% "$T/cru-botoes.png" "$T/pack-botoes.png" null: 2>&1)"
  canto="$(compare -metric AE -fuzz 6% "$T/cru-canto.png" "$T/pack-canto.png" null: 2>&1)"
  [ "$(cat "$T/cru.caixa")" = "$(cat "$T/pack.caixa")" ] && [ "${botoes%% *}" -gt 150 ] && [ "${canto%% *}" -lt 20 ] \
    && ok "só os botões mudam com o pack: $botoes pixels nos botões, $canto no canto da barra (janela $(cat "$T/pack.caixa"))" \
    || falha "a arte do pack não chegou ao SSD: caixas $(cat "$T/cru.caixa") e $(cat "$T/pack.caixa"), botões $botoes, canto $canto"

  echo "== descer um palco não toca no outro nem no que o palco não subiu"
  setsid sleep 300 </dev/null >/dev/null 2>&1 & alheio=$!
  setsid env MEOW_PALCO="$CURTO/outro" sleep 300 </dev/null >/dev/null 2>&1 & vizinho=$!
  PALCO_DIR="$CURTO/pack" "$PALCO" descer
  [ ! -e "$CURTO/pack" ] && PALCO_DIR="$CURTO/cru" "$PALCO" janelas 2>/dev/null | grep -qF "palco-ssd-$$" \
    && ok "descer o palco pack deixou o palco cru de pé, com a janela" || falha "descer o palco pack derrubou o palco cru"
  kill -0 "$alheio" 2>/dev/null && kill -0 "$vizinho" 2>/dev/null \
    && ok "um processo alheio e um marcado para outro palco sobrevivem" || falha "descer matou processo que não subiu"
  kill "$alheio" "$vizinho" 2>/dev/null
  PALCO_DIR="$CURTO/cru" "$PALCO" descer
  unset PALCO_ORIGEM
else
  conferir_sessao_dela zenity
  echo "pulado: a arte do pack precisa da instalação dela ($ORIGEM_DELA/.config/meow/meow.conf)"
fi
export PALCO_DIR="$P1"

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
mkdir -p "$CURTO/alheia"; printf 'guardado\n' > "$CURTO/alheia/dela.txt"
msg="$(PALCO_DIR="$CURTO/alheia" "$PALCO" subir 2>&1)"; rc=$?
PALCO_DIR="$CURTO/alheia" "$PALCO" descer
[ "$rc" != 0 ] && grep -q recuso <<< "$msg" && [ -f "$CURTO/alheia/dela.txt" ] \
  && ok "pasta que não é palco: subir recusa e descer não apaga" || falha "o palco tomou ou apagou uma pasta alheia (rc=$rc): $msg"
[ ! -s "$LOG" ] && ok "nenhum sudo, pkill nem killall" || falha "o palco chamou: $(sort -u "$LOG" | tr '\n' ' ')"

if [ "$falhas" = 0 ]; then echo "palco: tudo certo"; exit 0; fi
echo "palco: $falhas falha(s)"; exit 1

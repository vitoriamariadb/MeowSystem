#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0
command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT
MIGRAR="$RAIZ/scripts/migrar_conf.py"
EXEMPLO="$RAIZ/meow.conf.exemplo"
FALSO="$TMP/falso"; mkdir -p "$FALSO"
for c in sudo pkexec su pkill killall notify-send systemd-run loginctl apt apt-get xdg-open gsettings dconf busctl gdbus; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$c"; chmod 755 "$FALSO/$c"
done

conf_com() {
  local arq="$1"; shift
  cp "$EXEMPLO" "$arq"
  python3 - "$arq" "$@" <<'PY'
import re, sys
arq, pares = sys.argv[1], sys.argv[2:]
texto = open(arq, encoding="utf-8").read()
for par in pares:
    chave, valor = par.split("=", 1)
    texto, n = re.subn(r"(?m)^%s=.*$" % re.escape(chave), lambda m: "%s=%s" % (chave, valor), texto)
    if not n:
        texto += "\n%s=%s\n" % (chave, valor)
open(arq, "w", encoding="utf-8").write(texto)
PY
}
linha_de() { grep -E "^$2=" "$1" | tail -n1; }
migrar() { env -i PATH="$PATH" HOME="$TMP/casa0" python3 "$MIGRAR" "$@"; }

printf '\n--- 1. o migrar devolve ao pack o que é vestígio, e deixa o que foi fixado ---\n'
conf_com "$TMP/c1" 'PACK="dracula"' 'FLAVOR="dracula"' 'ICONES_FLAVOR="macchiato"' 'ICONES_PASTAS="cat-dracula-${ACCENT}"'
migrar "$TMP/c1" "$EXEMPLO" --conferir > "$TMP/s1" 2>&1; rc_c=$?
migrar "$TMP/c1" "$EXEMPLO" > "$TMP/s1b" 2>&1; rc=$?
migrar "$TMP/c1" "$EXEMPLO" --conferir > /dev/null 2>&1; rc_d=$?
if [ "$rc_c" = 1 ] && grep -q 'ICONES_FLAVOR' "$TMP/s1" && ! grep -q 'ICONES_PASTAS' "$TMP/s1" \
   && [ "$rc" = 0 ] && [ "$rc_d" = 0 ] \
   && [ "$(linha_de "$TMP/c1" ICONES_FLAVOR)" = 'ICONES_FLAVOR="$FLAVOR"' ] \
   && [ "$(linha_de "$TMP/c1" ICONES_PASTAS | sed 's/ *#.*//')" = 'ICONES_PASTAS="cat-dracula-${ACCENT}"' ]; then
  ok "com o Dracula no ar, o macchiato volta a \$FLAVOR, e a variante Drácula das pastas fica"
else
  falha "o migrar não devolveu os vestígios (conferir=$rc_c, migrar=$rc, depois=$rc_d)" \
    "$(cat "$TMP/s1" "$TMP/s1b"; linha_de "$TMP/c1" ICONES_FLAVOR; linha_de "$TMP/c1" ICONES_PASTAS)"
fi
conf_com "$TMP/c1c" 'PACK="meowsystem"' 'FLAVOR="mocha"' 'ICONES_PASTAS="cat-dracula-${ACCENT}"'
migrar "$TMP/c1c" "$EXEMPLO" > "$TMP/s1c" 2>&1; rc=$?
if [ "$rc" = 0 ] && [ "$(linha_de "$TMP/c1c" ICONES_PASTAS | sed 's/ *#.*//')" = 'ICONES_PASTAS="cat-${FLAVOR}-${ACCENT}"' ]; then
  ok "com o Catppuccin no ar, as pastas cat-dracula voltam a seguir o pack"
else
  falha "o migrar deixou as pastas do Dracula com o Catppuccin no ar (rc=$rc)" "$(cat "$TMP/s1c"; linha_de "$TMP/c1c" ICONES_PASTAS)"
fi
conf_com "$TMP/c2" 'PACK="meowsystem"' 'FLAVOR="mocha"' 'ICONES_FLAVOR="macchiato"' 'ICONES_PASTAS="cat-frappe-blue"'
cp "$TMP/c2" "$TMP/c2.antes"
migrar "$TMP/c2" "$EXEMPLO" --conferir > "$TMP/s2" 2>&1; rc_c=$?
migrar "$TMP/c2" "$EXEMPLO" > /dev/null 2>&1
if [ "$rc_c" = 0 ] && cmp -s "$TMP/c2" "$TMP/c2.antes"; then
  ok "o macchiato com a interface em mocha (o mesmo pack) e a pasta frappe-blue são escolhas, e ficam"
else
  falha "o migrar mexeu no que quem usa fixou (conferir=$rc_c)" "$(cat "$TMP/s2"; diff "$TMP/c2.antes" "$TMP/c2")"
fi

printf '\n--- 2. o doctor acusa e o --consertar corrige ---\n'
CASA="$TMP/casa"; mkdir -p "$CASA/.config/meow"
conf_com "$CASA/.config/meow/meow.conf" 'PACK="dracula"' 'FLAVOR="dracula"' 'ICONES_FLAVOR="macchiato"' 'ICONES_PASTAS="cat-dracula-${ACCENT}"'
doctor() {
  local casa="$1" vs="$2"; shift 2
  env -i PATH="$FALSO:$PATH" HOME="$casa" MEOW_RAIZ="$RAIZ" NO_COLOR=1 VS="$vs" \
    XDG_CONFIG_HOME="$casa/.config" XDG_STATE_HOME="$casa/.local/state" \
    bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow"); read -ra VERIFICAVEIS <<< "$VS"; cmd_doctor "$@"' _ "$@" 2>&1
}
antes="$(doctor "$CASA" conf)"; rc_a=$?
doctor "$CASA" conf --consertar > "$TMP/s3" 2>&1; rc_c=$?
depois="$(doctor "$CASA" conf)"; rc_d=$?
if [ "$rc_a" = 1 ] && grep -qE '^ *~~ +conf .*ICONES_FLAVOR' <<< "$antes" \
   && [ "$rc_c" = 1 ] && [ "$rc_d" = 0 ] \
   && [ "$(linha_de "$CASA/.config/meow/meow.conf" ICONES_FLAVOR)" = 'ICONES_FLAVOR="$FLAVOR"' ]; then
  ok "o doctor acusa ICONES_FLAVOR no conf, e o --consertar o corrige"
else
  falha "o doctor não corrigiu os vestígios (antes=$rc_a, consertar=$rc_c, depois=$rc_d)" "$antes
---
$(cat "$TMP/s3")"
fi

printf '\n--- 3. a troca de pack leva o ponteiro e as pastas do pack de antes ---\n'
troca() {
  local casa="$1" alvo="$2"; shift 2
  env -i PATH="$FALSO:$PATH" HOME="$casa" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
    XDG_CONFIG_HOME="$casa/.config" XDG_STATE_HOME="$casa/.local/state" "$@" \
    "$RAIZ/bin/meow" pack usar "$alvo" --sem-aplicar 2>&1
}
CASA3="$TMP/casa3"; mkdir -p "$CASA3/.config/meow"
conf_com "$CASA3/.config/meow/meow.conf" 'PACK="dracula"' 'FLAVOR="dracula"' 'CURSOR="Dracula-Cursor"' 'ICONES_PASTAS="cat-dracula-${ACCENT}"'
ensaio="$(troca "$CASA3" catppuccin MEOW_DRY_RUN=1)"; rc_e=$?
saida="$(troca "$CASA3" catppuccin)"; rc=$?
C3="$CASA3/.config/meow/meow.conf"
if ! grep -qE 'continuam valendo.*(CURSOR|ICONES_PASTAS)' <<< "$ensaio" \
   && grep -q 'CURSOR' <<< "$ensaio" \
   && [ "$rc" = 0 ] && [ "$(linha_de "$C3" CURSOR)" = 'CURSOR="catppuccin-mocha-light"' ] \
   && [ "$(linha_de "$C3" ICONES_PASTAS | sed 's/ *#.*//')" = 'ICONES_PASTAS="cat-${FLAVOR}-${ACCENT}"' ] \
   && [ "$(linha_de "$C3" PACK)" = 'PACK="meowsystem"' ]; then
  ok "Dracula -> Catppuccin: o ensaio diz o que vai junto, e a troca leva o ponteiro e as pastas"
else
  falha "a troca deixou o ponteiro ou as pastas do Dracula (ensaio=$rc_e, troca=$rc)" "$ensaio
---
$saida
---
$(linha_de "$C3" CURSOR) $(linha_de "$C3" ICONES_PASTAS)"
fi
saida="$(troca "$CASA3" dracula)"; rc=$?
if [ "$rc" = 0 ] && [ "$(linha_de "$C3" CURSOR)" = 'CURSOR="Dracula-Cursor"' ]; then
  ok "e de volta ao Dracula, o ponteiro volta a ser o dele"
else
  falha "a volta ao Dracula não levou o ponteiro (rc=$rc)" "$saida
$(linha_de "$C3" CURSOR)"
fi
conf_com "$C3" 'PACK="dracula"' 'FLAVOR="dracula"' 'CURSOR="Bibata-Modern-Ice"'
saida="$(troca "$CASA3" catppuccin)"; rc=$?
if [ "$rc" = 0 ] && [ "$(linha_de "$C3" CURSOR)" = 'CURSOR="Bibata-Modern-Ice"' ]; then
  ok "o ponteiro que quem usa fixou fica na troca"
else
  falha "a troca levou o ponteiro que quem usa fixou (rc=$rc)" "$(linha_de "$C3" CURSOR)"
fi
padrao_do_ponteiro() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA3" MEOW_RAIZ="$RAIZ" MEOW_CONF="$1" python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
item = next(i for i in servidor.ler_esquema() if i["chave"] == "CURSOR")
print("pack=%s" % (item.get("padrao_do_pack") or ""))
PY
}
conf_com "$TMP/p-dr" 'PACK="dracula"' 'FLAVOR="dracula"'
conf_com "$TMP/p-cat" 'PACK="meowsystem"' 'FLAVOR="mocha"'
s_dr="$(padrao_do_ponteiro "$TMP/p-dr")"; s_cat="$(padrao_do_ponteiro "$TMP/p-cat")"
if grep -qx 'pack=Dracula-Cursor' <<< "$s_dr" && grep -qx 'pack=' <<< "$s_cat"; then
  ok "o de fábrica do ponteiro no painel é o do pack no ar (Dracula-Cursor), e sem ponteiro no pack é o do exemplo"
else
  falha "o painel não manda o ponteiro do pack como o de fábrica" "$s_dr / $s_cat"
fi

printf '\n--- 3b. a troca parada no meio não deixa pasta para trás ---\n'
SOBRA="$TMP/tmpdir"; mkdir -p "$SOBRA"
CASA3B="$TMP/casa3b"; mkdir -p "$CASA3B/.config/meow"
conf_com "$CASA3B/.config/meow/meow.conf" 'PACK="dracula"' 'FLAVOR="dracula"'
for espera in 0.3 1 2; do
  setsid env -i PATH="$FALSO:$PATH" HOME="$CASA3B" MEOW_RAIZ="$RAIZ" NO_COLOR=1 TMPDIR="$SOBRA" \
    MEOW_DRY_RUN=1 "$RAIZ/bin/meow" pack usar meowsystem > /dev/null 2>&1 &
  pid=$!
  sleep "$espera"
  kill -TERM -- "-$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
done
sleep 1
restos="$(find "$SOBRA" -mindepth 1 -maxdepth 1 -name 'tmp.*' 2>/dev/null)"
if [ -z "$restos" ]; then
  ok "a troca parada aos 0,3, 1 e 2 s não deixa a cópia do conf no TMPDIR"
else
  falha "a troca parada deixou pasta no TMPDIR" "$restos"
fi

printf '\n--- 4. o CosmicBackground numa pasta que não é o carrossel ---\n'
CASA4="$TMP/casa4"; B="$CASA4/.local/share/backgrounds/meowsystem"
BG="$CASA4/.config/cosmic/com.system76.CosmicBackground/v1"
mkdir -p "$CASA4/.config/meow" "$B/ativos" "$BG" "$TMP/fora/imagens"
conf_com "$CASA4/.config/meow/meow.conf" 'WALLPAPER_NOITE="nao"'
for i in 1 2 3; do printf 'P3\n1 1\n255\n%d 0 0\n' "$((i * 60))" > "$B/ativos/p$i.ppm"; done
fundo() {
  printf '(\n    output: "all",\n    source: Path("%s"),\n    filter_by_theme: false,\n    rotation_frequency: 300,\n    filter_method: Lanczos,\n    scaling_mode: Zoom,\n    sampling_method: Random,\n)' "$1" > "$BG/all"
}
for pasta in "$TMP/fora/imagens" "$B/ativos-noite"; do
  fundo "$pasta"
  antes="$(doctor "$CASA4" wallpaper)"; rc_a=$?
  doctor "$CASA4" wallpaper --consertar > "$TMP/s4" 2>&1; rc_c=$?
  if [ "$rc_a" = 1 ] && grep -qE "^ *~~ +wallpaper" <<< "$antes" && grep -q "mudaria $BG/all" <<< "$antes" \
     && grep -q "source: Path(\"$B/ativos\")" "$BG/all"; then
    ok "apontando para ${pasta#"$TMP"/}: o doctor acusa, e o --consertar devolve ao carrossel"
  else
    falha "o CosmicBackground em ${pasta#"$TMP"/} não foi acusado e corrigido (antes=$rc_a, consertar=$rc_c)" "$antes
---
$(cat "$TMP/s4")
---
$(cat "$BG/all")"
  fi
done


printf '\n--- 5. instalar com PACK=dracula já no conf leva o ponteiro (decisão 12) ---\n'
RZ="$TMP/raiz-conf"; mkdir -p "$RZ"
for i in "$RAIZ"/*; do [ "$(basename "$i")" = install.sh ] || ln -s "$i" "$RZ/"; done
awk '/local etapas=\(/ && !t { print "  local etapas=(etapa_conf)"; t=1; p=1 }
     p { if ($0 ~ /\)[ \t]*$/) p=0; next } { print }' "$RAIZ/install.sh" > "$RZ/install.sh"
chmod +x "$RZ/install.sh"
inst() {
  local casa="$1"; shift
  env -i PATH="$FALSO:$PATH" HOME="$casa" USER="${USER:-t}" MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 \
    MEOW_PONTE=/nao/existe "$@" bash "$RZ/install.sh" --uma-passagem 2>&1
}
CASA5="$TMP/casa5"; mkdir -p "$CASA5/.config/meow"; C5="$CASA5/.config/meow/meow.conf"
conf_com "$C5" 'PACK="dracula"' 'FLAVOR="dracula"'
ensaio="$(inst "$CASA5" MEOW_DRY_RUN=1)"
[ "$(linha_de "$C5" CURSOR)" = 'CURSOR="catppuccin-mocha-light"' ] && grep -q 'CURSOR' <<< "$ensaio" \
  && ok "o ensaio diz que o ponteiro do Catppuccin iria embora, sem escrever" \
  || falha "o ensaio do install não viu o ponteiro do Catppuccin, ou escreveu" "$ensaio"
saida="$(inst "$CASA5")"
[ "$(linha_de "$C5" CURSOR)" = 'CURSOR="Dracula-Cursor"' ] \
  && [ "$(cat "$CASA5/.local/state/meowsystem/pack-do-install")" = "$(printf 'dracula\tdracula')" ] \
  && ok "o install com PACK=dracula no conf troca o ponteiro de fábrica pelo do Dracula" \
  || falha "o install deixou o ponteiro do Catppuccin com o Dracula no ar" "$saida
$(linha_de "$C5" CURSOR)"
conf_com "$C5" 'PACK="dracula"' 'FLAVOR="dracula"' 'CURSOR="catppuccin-mocha-light"'
inst "$CASA5" >/dev/null
[ "$(linha_de "$C5" CURSOR)" = 'CURSOR="catppuccin-mocha-light"' ] \
  && ok "o ponteiro que quem usa escolhe depois, com o mesmo pack, fica" \
  || falha "o install trocou o ponteiro escolhido com o pack de sempre" "$(linha_de "$C5" CURSOR)"
CASA6="$TMP/casa6"; mkdir -p "$CASA6/.config/meow"; C6="$CASA6/.config/meow/meow.conf"
cp "$EXEMPLO" "$C6"
inst "$CASA6" >/dev/null
cmp -s "$C6" "$EXEMPLO" && ok "com o pack padrão, o conf de fábrica fica byte a byte" \
  || falha "o install mexeu no conf de fábrica" "$(diff "$EXEMPLO" "$C6" | head -5)"
printf '\n'
if [ "$ACHADOS" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2
  exit 1
fi
printf 'passou: a casa fica coerente com o pack no ar\n'
exit 0

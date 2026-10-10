#!/usr/bin/env bash
# casa-real.sh — a casa fica coerente com o pack no ar. P79, item 4, 10/10/2026.
#
# O QUE ABRIU ISTO — o QA de uso real da P77, na casa de quem usa
#   1. `ICONES_FLAVOR="macchiato"` com o Dracula no ar: herança do Dracula de
#      antes da P74, quando ele vestia os ícones de arquivo do Catppuccin no
#      macchiato. Desde a P74 o Dracula traz os dele, e o valor velho seguia
#      vestindo a máquina com o acervo do outro pack («123 tipos de arquivo já
#      vestidos de Catppuccin macchiato»).
#   2. O ensaio de trocar o Dracula pelo Catppuccin avisava que `CURSOR` e
#      `ICONES_PASTAS` continuavam citando o Dracula: a troca de pack saía pela
#      metade numa casa que tinha o ponteiro e as pastas que o pack escolhe.
#   3. O `CosmicBackground` apontando para uma pasta que não é o carrossel.
#
# O QUE ESTE TESTE COBRA
#   1. O `migrar_conf.py` (a migração do doctor e do install.sh) devolve ao de
#      fábrica o `ICONES_FLAVOR` que nomeia um flavor que o pack no ar não tem,
#      e escreve na forma que acompanha o pack (`cat-${FLAVOR}-${ACCENT}`) o
#      `ICONES_PASTAS` que é a escolha do pack escrita por extenso. O que quem
#      usa fixou (um flavor do próprio pack, uma cor de pasta que o pack não
#      escolhe) fica.
#   2. O doctor acusa os dois no `conf` e o `--consertar` corrige.
#   3. O `meow pack usar` leva junto o `CURSOR` que é o ponteiro do pack de
#      antes (vira o do pack novo) e as pastas; o `CURSOR` que quem usa fixou
#      fica. O ensaio da troca já não lista os dois como vestígio.
#   4. O `CosmicBackground` numa pasta que não é o carrossel (fora do acervo,
#      ou a pasta do grupo errado) é acusado pelo doctor e corrigido pelo
#      `--consertar`.
#
# PORTÁTIL: HOME, COSMIC e packs de brinquedo; sudo, pkill e afins falsos.
#   0 = passou · 1 = falhou · 2 = erro deste teste
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

# Um conf de fábrica com as chaves trocadas (a última atribuição vence, como no `.`).
conf_com() {  # <arquivo> CHAVE=valor...
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
if [ "$rc_c" = 1 ] && grep -q 'ICONES_FLAVOR' "$TMP/s1" && grep -q 'ICONES_PASTAS' "$TMP/s1" \
   && [ "$rc" = 0 ] && [ "$rc_d" = 0 ] \
   && [ "$(linha_de "$TMP/c1" ICONES_FLAVOR)" = 'ICONES_FLAVOR="$FLAVOR"' ] \
   && [ "$(linha_de "$TMP/c1" ICONES_PASTAS | sed 's/ *#.*//')" = 'ICONES_PASTAS="cat-${FLAVOR}-${ACCENT}"' ]; then
  ok "com o Dracula no ar, o macchiato volta a \$FLAVOR e as pastas voltam a seguir o pack"
else
  falha "o migrar não devolveu os vestígios (conferir=$rc_c, migrar=$rc, depois=$rc_d)" \
    "$(cat "$TMP/s1" "$TMP/s1b"; linha_de "$TMP/c1" ICONES_FLAVOR; linha_de "$TMP/c1" ICONES_PASTAS)"
fi
conf_com "$TMP/c2" 'PACK="catppuccin"' 'FLAVOR="mocha"' 'ICONES_FLAVOR="macchiato"' 'ICONES_PASTAS="cat-frappe-blue"'
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
doctor() {  # <casa> <verificadores> [--consertar]
  local casa="$1" vs="$2"; shift 2
  env -i PATH="$FALSO:$PATH" HOME="$casa" MEOW_RAIZ="$RAIZ" NO_COLOR=1 VS="$vs" \
    XDG_CONFIG_HOME="$casa/.config" XDG_STATE_HOME="$casa/.local/state" \
    bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow"); read -ra VERIFICAVEIS <<< "$VS"; cmd_doctor "$@"' _ "$@" 2>&1
}
antes="$(doctor "$CASA" conf)"; rc_a=$?
doctor "$CASA" conf --consertar > "$TMP/s3" 2>&1; rc_c=$?
depois="$(doctor "$CASA" conf)"; rc_d=$?
if [ "$rc_a" = 1 ] && grep -qE '^ *~~ +conf .*ICONES_FLAVOR' <<< "$antes" && grep -q 'ICONES_PASTAS' <<< "$antes" \
   && [ "$rc_c" = 1 ] && [ "$rc_d" = 0 ] \
   && [ "$(linha_de "$CASA/.config/meow/meow.conf" ICONES_FLAVOR)" = 'ICONES_FLAVOR="$FLAVOR"' ]; then
  ok "o doctor acusa ICONES_FLAVOR e ICONES_PASTAS no conf, e o --consertar os corrige"
else
  falha "o doctor não corrigiu os vestígios (antes=$rc_a, consertar=$rc_c, depois=$rc_d)" "$antes
---
$(cat "$TMP/s3")"
fi

printf '\n--- 3. a troca de pack leva o ponteiro e as pastas do pack de antes ---\n'
troca() {  # <casa> <pack> [VAR=valor ...]
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
   && [ "$(linha_de "$C3" PACK)" = 'PACK="catppuccin"' ]; then
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

printf '\n--- 4. o CosmicBackground numa pasta que não é o carrossel ---\n'
CASA4="$TMP/casa4"; B="$CASA4/.local/share/backgrounds/meowsystem"
BG="$CASA4/.config/cosmic/com.system76.CosmicBackground/v1"
mkdir -p "$CASA4/.config/meow" "$B/ativos" "$BG" "$TMP/fora/imagens"
conf_com "$CASA4/.config/meow/meow.conf" 'WALLPAPER_NOITE="nao"'
for i in 1 2 3; do printf 'P3\n1 1\n255\n%d 0 0\n' "$((i * 60))" > "$B/ativos/p$i.ppm"; done
fundo() {  # <pasta>
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

printf '\n'
if [ "$ACHADOS" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2
  exit 1
fi
printf 'passou: a casa fica coerente com o pack no ar\n'
exit 0

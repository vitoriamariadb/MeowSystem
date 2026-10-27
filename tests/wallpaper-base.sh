#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ACHADOS=0
ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/falso"
for c in sudo pkexec su pkill killall notify-send systemd-run loginctl apt apt-get xdg-open gsettings dconf; do
  printf '#!/bin/sh\nexit 1\n' > "$T/falso/$c"; chmod 755 "$T/falso/$c"
done

monta() {
  local nome="$1"
  C="$T/$nome"; R="$C/repo"; CASA="$C/casa"
  mkdir -p "$R" "$CASA/.config/meow" "$C/cosmic/com.system76.CosmicBackground/v1"
  git -C "$RAIZ" ls-files -z --cached --others --exclude-standard \
    | (cd "$RAIZ" && tar --null -T - -cf - 2>/dev/null) | tar -xf - -C "$R" || exit 2
  ANT="$R/assets/papeis-de-parede"; NOVO="$CASA/.local/share/backgrounds/meowsystem"
  mkdir -p "$ANT/ativos" "$ANT/ativos-dia" "$ANT/ativos-noite" "$ANT/banidos"
  local i
  for i in 1 2 3 4; do
    printf 'P3\n1 1\n255\n%d 20 30\n' "$i" > "$ANT/ativos/foto$i.png"
    printf 'P3\n1 1\n255\n%d 90 30\n' "$i" > "$ANT/ativos-dia/dia$i.png"
    printf 'P3\n1 1\n255\n%d 20 99\n' "$i" > "$ANT/ativos-noite/noite$i.png"
  done
  printf 'P3\n1 1\n255\n7 7 7\n' > "$ANT/banidos/ruim.png"
  cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf"
  python3 - "$CASA/.config/meow/meow.conf" "$ANT" <<'PY'
import re, sys
arq, base = sys.argv[1:]
t = open(arq, encoding="utf-8").read()
t = re.sub(r'(?m)^WALLPAPER_BASE=.*$', 'WALLPAPER_BASE="%s"' % base, t)
open(arq, "w", encoding="utf-8").write(t)
PY
  BG="$C/cosmic/com.system76.CosmicBackground/v1"
  local cfg
  for cfg in all output.DP-1 output.HDMI-A-1; do
    printf '(\n    output: "%s",\n    source: Path("%s/ativos-dia"),\n    filter_by_theme: false,\n    rotation_frequency: 300,\n)' \
      "${cfg#output.}" "$ANT" > "$BG/$cfg"
  done
  mkdir -p "$CASA/.local/share/backgrounds"
  ln -s "$ANT" "$NOVO"
}

amb() {
  env -i PATH="$T/falso:$PATH" HOME="$CASA" MEOW_RAIZ="$R" MEOW_CONF="$CASA/.config/meow/meow.conf" \
      MEOW_COSMIC_DIR="$C/cosmic" NO_COLOR=1 "$@"
}

wp() { amb WALLPAPER_BASE="${BASE_ENV:-$ANT}" "$R/scripts/wallpaper.sh" "$@" 2>&1; }

doctor_fn() {
  local fn="$1"
  amb WALLPAPER_BASE="${BASE_ENV:-$ANT}" bash -c '
    source <(sed "/^despachar \"\$@\"\$/d" "$MEOW_RAIZ/bin/meow")
    "$1"; exit $?' _ "$fn" 2>&1
}

instantaneo() {
  (cd "$1" && find . \( -type f -o -type l \) -not -path "${2:-./nada}" -printf '%p %s %T@ %l\n' | LC_ALL=C sort | sha256sum)
}
conteudo_das_imagens() {
  (cd "$1" && find . -type f -name '*.png' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum)
}

printf '\n--- 1. a base dentro do repo é conferida sem escrever, e movida sem perder imagem ---\n'
monta um
ANTES_IMG="$(conteudo_das_imagens "$ANT")"
N_ANTES="$(find "$ANT" -type f | wc -l)"
CASA_ANTES="$(instantaneo "$C")"
saida="$(wp base --conferir)"; rc=$?
[ "$rc" = 1 ] && [ "$(instantaneo "$C")" = "$CASA_ANTES" ] \
  && grep -q "dentro do repositório" <<< "$saida" \
  && ok "conferir diz que mora no repo (rc=1) e não escreve nada" \
  || falha "o conferir escreveu ou não avisou (rc=$rc)" "$saida"
doctor_fn chk_basefundo >/dev/null; rc_chk=$?
[ "$rc_chk" = 1 ] && ok "a conferência do doctor diverge (rc=1)" || falha "chk_basefundo não divergiu (rc=$rc_chk)"

doctor_fn fix_basefundo > "$T/fix1.log"; rc=$?
WP_CONF="$(sed -n 's/^WALLPAPER_BASE="\(.*\)"/\1/p' "$CASA/.config/meow/meow.conf" | tail -n1)"
if [ "$rc" = 1 ] && [ ! -e "$ANT" ] && [ -d "$NOVO" ] && [ ! -L "$NOVO" ] \
   && [ "$WP_CONF" = "$NOVO" ]; then
  ok "a pasta saiu do repo, o destino é diretório de verdade e o WALLPAPER_BASE aponta para ele"
else
  falha "a base não foi movida como devia (rc=$rc, conf=$WP_CONF)" "$(cat "$T/fix1.log")"
fi
N_DEPOIS="$(find "$NOVO" -type f | wc -l)"
[ "$N_ANTES" = "$N_DEPOIS" ] && [ "$ANTES_IMG" = "$(conteudo_das_imagens "$NOVO")" ] \
  && ok "as $N_ANTES imagens chegaram, byte a byte iguais" \
  || falha "a contagem ou o conteúdo mudou ($N_ANTES antes, $N_DEPOIS depois)"
bons=0
for cfg in all output.DP-1 output.HDMI-A-1; do
  grep -qF "source: Path(\"$NOVO/ativos-dia\")" "$BG/$cfg" && ! grep -qF "$ANT" "$BG/$cfg" && bons=$((bons + 1))
done
[ "$bons" = 3 ] && ok "as três configs do CosmicBackground apontam para $NOVO/ativos-dia" \
  || falha "só $bons das 3 configs do fundo foram reescritas" "$(cat "$BG"/all)"

printf '\n--- 2. a segunda passada não escreve ---\n'
BASE_ENV="$NOVO"
CASA_ANTES="$(instantaneo "$C")"
doctor_fn chk_basefundo >/dev/null; rc_chk=$?
doctor_fn fix_basefundo > "$T/fix2.log"; rc_fix=$?
wp base >/dev/null; rc_wp=$?
if [ "$rc_chk" = 0 ] && [ "$rc_wp" = 0 ] && [ "$(instantaneo "$C")" = "$CASA_ANTES" ]; then
  ok "depois de movida, a conferência passa (rc=0) e nenhum arquivo muda de conteúdo, tamanho ou hora"
else
  falha "a segunda passada escreveu ou divergiu (chk=$rc_chk fix=$rc_fix wp=$rc_wp)" "$(cat "$T/fix2.log")"
fi
unset BASE_ENV

printf '\n--- 3. conflito no destino: erro e a origem fica intacta ---\n'
monta tres
mkdir -p "$C/casa/.local/share/backgrounds"; rm -f "$NOVO"; mkdir -p "$NOVO/ativos"
printf 'P3\n1 1\n255\n99 99 99\n' > "$NOVO/ativos/foto1.png"
ANTES_IMG="$(conteudo_das_imagens "$ANT")"
doctor_fn fix_basefundo > "$T/fix3.log"; rc=$?
WP_CONF="$(sed -n 's/^WALLPAPER_BASE="\(.*\)"/\1/p' "$CASA/.config/meow/meow.conf" | tail -n1)"
if [ "$rc" = 2 ] && [ "$ANTES_IMG" = "$(conteudo_das_imagens "$ANT")" ] && [ "$WP_CONF" = "$ANT" ] \
   && grep -qF "source: Path(\"$ANT/ativos-dia\")" "$BG/all"; then
  ok "foto1.png diferente no destino: nada foi apagado, o conf e o fundo continuam onde estavam (rc=2)"
else
  falha "o conflito não foi tratado com segurança (rc=$rc)" "$(cat "$T/fix3.log")"
fi

printf '\n--- 4. destino já com parte das imagens: junta sem duplicar, e a origem sai ---\n'
monta quatro
rm -f "$NOVO"; mkdir -p "$NOVO/ativos"
cp -a "$ANT/ativos/foto1.png" "$NOVO/ativos/"
printf 'P3\n1 1\n255\n5 5 5\n' > "$NOVO/ativos/so-no-destino.png"
N_UNIAO="$(( $(find "$ANT" -type f | wc -l) + 1 ))"
doctor_fn fix_basefundo > "$T/fix4.log"; rc=$?
if [ "$rc" = 1 ] && [ ! -e "$ANT" ] && [ "$(find "$NOVO" -type f | wc -l)" = "$N_UNIAO" ] \
   && [ -f "$NOVO/ativos/so-no-destino.png" ] && [ -f "$NOVO/banidos/ruim.png" ]; then
  ok "as imagens dos dois lados estão em $NOVO ($N_UNIAO) e a origem saiu do repo"
else
  falha "a junção falhou (rc=$rc, $(find "$NOVO" -type f | wc -l) de $N_UNIAO)" "$(cat "$T/fix4.log")"
fi

printf '\n--- 5. a base padrão como atalho para dentro do repo vira pasta de verdade ---\n'
monta cinco
sed -i '/^WALLPAPER_BASE=/d' "$CASA/.config/meow/meow.conf"
BASE_ENV=""
doctor_fn chk_basefundo >/dev/null; rc_chk=$?
doctor_fn fix_basefundo > "$T/fix5.log"; rc=$?
if [ "$rc_chk" = 1 ] && [ "$rc" = 1 ] && [ -d "$NOVO" ] && [ ! -L "$NOVO" ] && [ ! -e "$ANT" ] \
   && ! grep -q '^WALLPAPER_BASE=' "$CASA/.config/meow/meow.conf" && [ -f "$NOVO/ativos-dia/dia1.png" ]; then
  ok "sem WALLPAPER_BASE no conf, o atalho do padrão sai e a pasta mora ali; o conf não ganha chave"
else
  falha "o atalho do padrão não foi resolvido (chk=$rc_chk fix=$rc)" "$(cat "$T/fix5.log")"
fi
unset BASE_ENV

printf '\n--- 6. o estado antigo (midia, leitura) sai pelo doctor, e só ele ---\n'
monta seis
ST="$CASA/.local/state/meowsystem"
mkdir -p "$ST/midia/target" "$ST/leitura/target" "$ST/extensoes/meowsystem-leitura" "$ST/backups"
printf 'x' > "$ST/midia/target/a.o"; printf 'x' > "$ST/leitura/target/b.o"
printf 'v' > "$ST/extensoes/meowsystem-leitura/carimbo"
printf 'log' > "$ST/leitura.log"
BASE_ENV="$NOVO"
saida="$(doctor_fn chk_estadovelho)"; rc_chk=$?
inst="$(instantaneo "$ST")"
saida_f="$(doctor_fn fix_estadovelho)"; rc=$?
if [ "$rc_chk" = 1 ] && [ "$rc" = 1 ] && [ ! -e "$ST/midia" ] && [ ! -e "$ST/leitura" ] \
   && [ -f "$ST/extensoes/meowsystem-leitura/carimbo" ] && [ -f "$ST/leitura.log" ]; then
  ok "midia/ e leitura/ saíram; extensoes/, o leitura.log e os backups ficaram"
else
  falha "o estado antigo não saiu como devia (chk=$rc_chk fix=$rc)" "$saida
$saida_f"
fi
inst2="$(instantaneo "$ST")"
doctor_fn chk_estadovelho >/dev/null; rc_chk=$?
[ "$rc_chk" = 0 ] && [ "$inst2" = "$(instantaneo "$ST")" ] \
  && ok "a segunda conferência passa e não escreve" || falha "a segunda conferência divergiu (rc=$rc_chk)"
unset BASE_ENV

printf '\n--- 7. o doctor inteiro: acusa, conserta numa passada, e a segunda não escreve ---\n'
monta sete
mkdir -p "$CASA/.local/state/meowsystem/midia/target"
doctor_todo() {
  amb XDG_CONFIG_HOME="$CASA/.config" XDG_STATE_HOME="$CASA/.local/state" VS="basefundo estadovelho" \
    bash -c 'source <(sed "/^despachar \"\$@\"\$/d" "$MEOW_RAIZ/bin/meow"); read -ra VERIFICAVEIS <<< "$VS"; cmd_doctor "$@"' _ "$@" 2>&1
}
saida="$(doctor_todo)"; rc_a=$?
saida_c="$(doctor_todo --consertar)"; rc_c=$?
saida_d="$(doctor_todo)"; rc_d=$?
CASA_ANTES="$(instantaneo "$C" './casa/.local/state/*')"
doctor_todo --consertar >/dev/null; rc_e=$?
if [ "$rc_a" = 1 ] && [ "$rc_c" = 1 ] && [ "$rc_d" = 0 ] && [ "$rc_e" = 0 ] \
   && [ ! -e "$ANT" ] && [ -d "$NOVO" ] && [ ! -e "$CASA/.local/state/meowsystem/midia" ] \
   && [ "$(instantaneo "$C" './casa/.local/state/*')" = "$CASA_ANTES" ]; then
  ok "doctor acusa (1), --consertar acerta e confere de novo (1), depois tudo no lugar (0) e a segunda passada não escreve"
else
  falha "o doctor não fechou o ciclo (acusa=$rc_a consertar=$rc_c depois=$rc_d de-novo=$rc_e)" "$saida
---
$saida_c
---
$saida_d"
fi

printf '\n--- 8. o caminho chega por um atalho de fora do repo (o atalho de disco dela) ---\n'
monta oito
ATALHO="$T/apate-oito"; ln -s "$C" "$ATALHO"
VIA="$ATALHO/repo/assets/papeis-de-parede"
sed -i "s#^WALLPAPER_BASE=.*#WALLPAPER_BASE=\"$VIA\"#" "$CASA/.config/meow/meow.conf"
for cfg in all output.DP-1 output.HDMI-A-1; do sed -i "s#$ANT#$VIA#" "$BG/$cfg"; done
rm -f "$NOVO"; ln -s "$VIA" "$NOVO"
N_ANTES="$(find "$ANT" -type f | wc -l)"
BASE_ENV="$VIA"
doctor_fn chk_basefundo >/dev/null; rc_chk=$?
doctor_fn fix_basefundo > "$T/fix8.log"; rc=$?
WP_CONF="$(sed -n 's/^WALLPAPER_BASE="\(.*\)"/\1/p' "$CASA/.config/meow/meow.conf" | tail -n1)"
bons=0
for cfg in all output.DP-1 output.HDMI-A-1; do
  grep -qF "source: Path(\"$NOVO/ativos-dia\")" "$BG/$cfg" && ! grep -qF "apate-oito" "$BG/$cfg" && bons=$((bons + 1))
done
BASE_ENV="$NOVO"
doctor_fn chk_basefundo >/dev/null; rc_de_novo=$?
if [ "$rc_chk" = 1 ] && [ "$rc" = 1 ] && [ ! -e "$ANT" ] && [ -d "$NOVO" ] && [ ! -L "$NOVO" ] \
   && [ "$WP_CONF" = "$NOVO" ] && [ "$bons" = 3 ] && [ "$(find "$NOVO" -type f | wc -l)" = "$N_ANTES" ] \
   && [ "$rc_de_novo" = 0 ]; then
  ok "base, atalho do padrão e as três configs pelo caminho de fora: tudo volta para $NOVO, com as $N_ANTES imagens"
else
  falha "o caminho pelo atalho de fora não foi resolvido (chk=$rc_chk fix=$rc configs=$bons conf=$WP_CONF de-novo=$rc_de_novo)" "$(cat "$T/fix8.log")"
fi
unset BASE_ENV

printf '\n'
if [ "$ACHADOS" = 0 ]; then
  printf 'ok: a base do papel de parede e o estado antigo saem do repo e do estado, sem perder imagem\n'
  exit 0
fi
printf 'NÃO: %d verificação(ões) falharam\n' "$ACHADOS" >&2
exit 1

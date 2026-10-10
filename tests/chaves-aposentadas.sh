#!/usr/bin/env bash
# chaves-aposentadas.sh — a chave que saiu do meow.conf não volta.
#
# POR QUE ESTE ARQUIVO NASCEU EM 09/10/2026 (P75)
#   Em 24/09 a decisão foi «Tirar a linha do conf» para a `ICONES_BASE`. Virou
#   um comentário no meow.conf, e a chave continuou no exemplo. O
#   `migrar_conf.py` devolve toda chave do exemplo que o arquivo não tem — e
#   linha comentada conta como ausente —, então a linha voltou no install.sh
#   seguinte, o painel regravou o valor, e as pastas coloridas sumiram por
#   sete auto-reparos (docs/sprints/2026-10-09-uso-real/01-regressoes.md, I1).
#
# O QUE ESTE TESTE COBRA
#   1. Com a chave COMENTADA no conf e um exemplo VELHO que ainda a traz, o
#      `migrar_conf.py` não a devolve.
#   2. Com a linha ATIVA no conf, ele a tira, e só ela: o comentário em volta
#      e as outras chaves ficam.
#   3. A chave não está mais no `meow.conf.exemplo` de hoje.
#   4. O `meow doctor --consertar` faz a mesma migração numa casa de
#      brinquedo: o conf com a linha ativa sai dele sem ela, e o doctor seguinte
#      não acusa mais o `conf`.
#
#   0 = passou · 1 = falhou · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0
command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT
MIGRAR="$RAIZ/scripts/migrar_conf.py"

# O exemplo velho: o de hoje com a chave de volta, como ele era até a P75.
cp "$RAIZ/meow.conf.exemplo" "$TMP/exemplo-velho"
printf '\n# @ Tema de onde herdar\nICONES_BASE="Papirus-Dark"        # tema herdado como fallback\n' >> "$TMP/exemplo-velho"

printf '\n--- 1. comentada, não volta ---\n'
cp "$RAIZ/meow.conf.exemplo" "$TMP/conf1"
printf '\n# ICONES_BASE saiu em 24/09 (P41): a base agora vem do pack Dracula, pinada.\n' >> "$TMP/conf1"
python3 "$MIGRAR" "$TMP/conf1" "$TMP/exemplo-velho" > "$TMP/saida1" 2>&1; rc=$?
if [ "$rc" = "0" ] && ! grep -qE '^[[:space:]]*ICONES_BASE=' "$TMP/conf1"; then
  ok "com a linha comentada, o migrar não devolve a ICONES_BASE (nem com o exemplo velho)"
else
  falha "a ICONES_BASE voltou (rc=$rc)"; cat "$TMP/saida1" >&2
fi

printf '\n--- 2. ativa, sai ---\n'
cp "$RAIZ/meow.conf.exemplo" "$TMP/conf2"
printf '\n# um comentário meu\nICONES_BASE="MeowSystem-Icons-Base"        # tema herdado como fallback\nMINHA_CHAVE="fica"\n' >> "$TMP/conf2"
python3 "$MIGRAR" "$TMP/conf2" "$RAIZ/meow.conf.exemplo" --conferir > "$TMP/saida2" 2>&1; rc_c=$?
python3 "$MIGRAR" "$TMP/conf2" "$RAIZ/meow.conf.exemplo" > "$TMP/saida2b" 2>&1; rc=$?
python3 "$MIGRAR" "$TMP/conf2" "$RAIZ/meow.conf.exemplo" --conferir > /dev/null 2>&1; rc_d=$?
if [ "$rc_c" = "1" ] && grep -q 'aposentada' "$TMP/saida2" && [ "$rc" = "0" ] && [ "$rc_d" = "0" ] \
   && ! grep -qE '^[[:space:]]*ICONES_BASE=' "$TMP/conf2" \
   && grep -qx '# um comentário meu' "$TMP/conf2" && grep -qx 'MINHA_CHAVE="fica"' "$TMP/conf2"; then
  ok "a linha ativa sai (o --conferir acusa antes e cala depois); o comentário e a outra chave ficam"
else
  falha "a linha ativa não saiu direito (conferir=$rc_c, migrar=$rc, depois=$rc_d)"
  cat "$TMP/saida2" "$TMP/saida2b" >&2; tail -4 "$TMP/conf2" >&2
fi

printf '\n--- 3. o exemplo de hoje ---\n'
if grep -qE '^[[:space:]]*ICONES_BASE=' "$RAIZ/meow.conf.exemplo"; then
  falha "a ICONES_BASE ainda está no meow.conf.exemplo"
else
  ok "a ICONES_BASE não está no meow.conf.exemplo"
fi

printf '\n--- 4. o doctor migra ---\n'
FALSO="$TMP/falso"; mkdir -p "$FALSO"
for c in sudo pkill killall notify-send systemd-run pkexec; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$c"; chmod 755 "$FALSO/$c"
done
CASA="$TMP/casa"; mkdir -p "$CASA/.config/meow"
cp "$TMP/conf2" "$CASA/.config/meow/meow.conf"
printf 'ICONES_BASE="MeowSystem-Icons-Base"\n' >> "$CASA/.config/meow/meow.conf"
roda() {
  env PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
    XDG_CONFIG_HOME="$CASA/.config" XDG_STATE_HOME="$CASA/.local/state" \
    bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow"); VERIFICAVEIS=(conf); cmd_doctor "$@"' _ "$@" 2>&1
}
antes="$(roda)"; rc_a=$?
depois_c="$(roda --consertar)"; rc_c=$?
depois="$(roda)"; rc_d=$?
if [ "$rc_a" = "1" ] && grep -qE '^ *~~ +conf +aposentada' <<< "$antes" \
   && [ "$rc_c" = "1" ] && [ "$rc_d" = "0" ] \
   && ! grep -qE '^[[:space:]]*ICONES_BASE=' "$CASA/.config/meow/meow.conf"; then
  ok "o doctor acusa a aposentada, o --consertar a tira, e a passada seguinte é verde"
else
  falha "o doctor não migrou (antes=$rc_a, consertar=$rc_c, depois=$rc_d)"
  printf '%s\n---\n%s\n' "$antes" "$depois_c" | sed 's/^/       /' >&2
fi

printf '\n--- 5. a passada que migra já não lê a aposentada ---\n'
# Conferência da P75 (09/10/2026): o `fix_conf` roda num subshell, e a chave
# que ele tirou do arquivo seguia no ambiente do doctor — a 1ª passada montava
# `completar` e `pastas` pela `ICONES_BASE` velha e terminava vermelha. Aqui
# um verificador de mentira só fica verde quando a aposentada saiu do
# ambiente; ele não tem conserto que mude nada, então quem o põe no lugar é a
# releitura do conf, na mesma passada.
cp "$TMP/conf2" "$CASA/.config/meow/meow.conf"
printf 'ICONES_BASE="MeowSystem-Icons-Base"\n' >> "$CASA/.config/meow/meow.conf"
roda_x() {
  env PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
    XDG_CONFIG_HOME="$CASA/.config" XDG_STATE_HOME="$CASA/.local/state" \
    bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow")
             VERIFICAVEIS=(conf leitor)
             chk_leitor() { [ -z "${ICONES_BASE+x}" ] && { echo "sem a aposentada"; return 0; }; echo "lê ICONES_BASE=$ICONES_BASE"; return 1; }
             fix_leitor() { return 1; }
             cmd_doctor "$@"' _ "$@" 2>&1
}
saida="$(roda_x --consertar)"; rc=$?
if [ "$rc" = "1" ] && grep -q 'consertado' <<< "$saida"; then
  ok "na mesma passada que tira a linha, quem vem depois do conf já não lê a ICONES_BASE (rc=1)"
else
  falha "a aposentada seguiu no ambiente depois da migração (rc=$rc)"; printf '%s\n' "$saida" | sed 's/^/       /' >&2
fi

printf '\n'
if [ "$ACHADOS" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2
  exit 1
fi
printf 'passou: a chave aposentada não volta\n'
exit 0

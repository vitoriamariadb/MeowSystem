#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0
command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT
MIGRAR="$RAIZ/scripts/migrar_conf.py"

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

printf '\n--- 6. o bloco órfão da aposentada sai (P82, item 33) ---\n'
cp "$RAIZ/meow.conf.exemplo" "$TMP/conf6"
bloco="$(git -C "$RAIZ" show 18c1d88^:meow.conf.exemplo 2>/dev/null | sed -n '478,498p')"
if [ "$(head -1 <<< "$bloco")" != "# @ Tema de onde herdar" ]; then
  falha "não achei o bloco antigo no histórico (18c1d88^:meow.conf.exemplo)"
else
  {
    printf '\n'; head -13 <<< "$bloco"
    printf '# ICONES_BASE saiu em 24/09 (P41): a base agora vem do pack Dracula, pinada.\n'
    printf '# A linha antiga era: ICONES_BASE="Dracula-Icones"\n\n'
    printf '# --- Acrescentado pelo install.sh -----------------------------------------\n'
    printf '%s\n\n' "$bloco"
  } >> "$TMP/conf6"
  python3 "$MIGRAR" "$TMP/conf6" "$RAIZ/meow.conf.exemplo" --conferir > "$TMP/saida6" 2>&1; rc_c=$?
  python3 "$MIGRAR" "$TMP/conf6" "$RAIZ/meow.conf.exemplo" > "$TMP/saida6b" 2>&1; rc=$?
  soma="$(sha256sum < "$TMP/conf6")"
  python3 "$MIGRAR" "$TMP/conf6" "$RAIZ/meow.conf.exemplo" > /dev/null 2>&1; rc2=$?
  python3 "$MIGRAR" "$TMP/conf6" "$RAIZ/meow.conf.exemplo" --conferir > /dev/null 2>&1; rc_d=$?
  if [ "$rc_c" = "1" ] && [ "$rc" = "0" ] && [ "$rc2" = "0" ] && [ "$rc_d" = "0" ] \
     && ! grep -q 'Tema de onde herdar' "$TMP/conf6" \
     && ! grep -q 'O PACK PODE TRAZER A BASE' "$TMP/conf6" \
     && grep -qx '# ICONES_BASE saiu em 24/09 (P41): a base agora vem do pack Dracula, pinada.' "$TMP/conf6" \
     && grep -qx '# A linha antiga era: ICONES_BASE="Dracula-Icones"' "$TMP/conf6" \
     && [ "$(sha256sum < "$TMP/conf6")" = "$soma" ]; then
    ok "os dois blocos órfãos saem, a nota escrita à mão fica, e a segunda passada não escreve"
  else
    falha "o bloco órfão não saiu direito (conferir=$rc_c, migrar=$rc, 2ª=$rc2, depois=$rc_d)"
    cat "$TMP/saida6" "$TMP/saida6b" >&2; grep -n 'Tema de onde herdar\|ICONES_BASE' "$TMP/conf6" >&2
  fi
fi

printf '\n'
if [ "$ACHADOS" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2
  exit 1
fi
printf 'passou: a chave aposentada não volta\n'
exit 0

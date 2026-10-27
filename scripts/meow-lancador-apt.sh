#!/bin/sh

ACERVO="@ACERVO@"
USUARIA="@USUARIA@"
LAR="@LAR@"

ALVO="$ACERVO/scripts/ocultar_apps.sh"
ALVO_NOMES="$ACERVO/scripts/nomes_apps.sh"
ESTADO="$LAR/.local/state/meowsystem"
LOG="$ESTADO/apt-lancador.log"

if [ "$(id -u)" = 0 ]; then
  [ -n "$USUARIA" ] && [ "$USUARIA" != root ] || exit 0
  cd / && runuser -u "$USUARIA" -- "$0"
  exit 0
fi

registrar() {
  [ -d "$ESTADO" ] || return 0
  printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG" 2>/dev/null
  if [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null || echo 0)" -gt 262144 ]; then
    tail -n 400 "$LOG" > "$LOG.novo" 2>/dev/null &&
      mv -f "$LOG.novo" "$LOG" 2>/dev/null
  fi
  chown "$USUARIA:$USUARIA" "$LOG" 2>/dev/null
  return 0
}

if [ ! -x "$ALVO" ]; then
  registrar "pulado — $ALVO não está executável (o Ápate está montado?)"
  exit 0
fi

HOME="$LAR"
MEOW_ESTADO="$ESTADO"
export HOME MEOW_ESTADO

saida="$("$ALVO" 2>&1)"
rc=$?

if [ -x "$ALVO_NOMES" ]; then
  saida_nomes="$("$ALVO_NOMES" --so-sistema 2>&1)"
  rc_nomes=$?
  saida="$saida${saida_nomes:+ | $saida_nomes}"
  case "$rc_nomes" in
    2) rc=2 ;;
    1) [ "$rc" = 2 ] || rc=1 ;;
    3) ;;
    0) ;;
    *) rc=2 ;;
  esac
fi

case "$rc" in
  0) ;;
  1)
    chown -R "$USUARIA:$USUARIA" "$ESTADO" 2>/dev/null
    registrar "reaplicado após apt — $(printf '%s' "$saida" | tr '\n' ' ')"
    ;;
  *)
    registrar "FALHOU (rc=$rc) — $(printf '%s' "$saida" | tr '\n' ' ')"
    ;;
esac

exit 0

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

TMP="$(mktemp -d)"
trap 'parar_servidores; rm -rf "$TMP"' EXIT

parar_servidores() {
  local f pid
  for f in "$TMP"/casa-*/.local/state/meowsystem/paineis/*.pid; do
    [ -f "$f" ] || continue
    pid="$(basename "$f" .pid)"
    tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | grep -qxF "$RAIZ/app/servidor.py" &&
      kill -TERM "$pid" 2>/dev/null
  done
  return 0
}

mkdir -p "$TMP/falso"
cat > "$TMP/falso/systemd-run" <<'FIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MEOW_TESTE_REGISTRO"
[ "${MEOW_TESTE_ESCOPO:-1}" = "1" ] || exit 1
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
  [ "$1" = "true" ] && exit 0
  shift
done
shift
exec "$@"
FIM
cat > "$TMP/falso/navegador" <<'FIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MEOW_TESTE_ABERTO"
FIM
chmod +x "$TMP/falso/systemd-run" "$TMP/falso/navegador"

lancar() {
  local nome="$1" escopo="$2" casa="$TMP/casa-$1"
  mkdir -p "$casa"
  : > "$TMP/$nome.registro"; : > "$TMP/$nome.aberto"
  env -u XDG_STATE_HOME -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME \
    -u MEOW_ESTADO -u MEOW_CONF -u MEOW_FD \
    HOME="$casa" PATH="$TMP/falso:$PATH" BROWSER="$TMP/falso/navegador" \
    MEOW_APP_ESPERA=20 MEOW_TESTE_ESCOPO="$escopo" \
    MEOW_TESTE_REGISTRO="$TMP/$nome.registro" MEOW_TESTE_ABERTO="$TMP/$nome.aberto" \
    "$RAIZ/app/run.sh" < /dev/null > "$TMP/$nome.saida" 2>&1
}

printf '\no painel aberto pelo .desktop sai do serviço do lançador antes de ele terminar\n'
lancar com 1
if grep -qxF -- "--user --scope --quiet --collect -- python3 $RAIZ/app/servidor.py" "$TMP/com.registro"; then
  ok "o servidor nasce num escopo próprio"
else
  falha "o servidor ficou no serviço do lançador: $(tr '\n' '|' < "$TMP/com.registro")"
fi
if grep -qE -- "^--user --scope --quiet --collect -- $TMP/falso/navegador http://127\.0\.0\.1:[0-9]+/" "$TMP/com.registro"; then
  ok "o navegador nasce num escopo próprio"
else
  falha "o navegador ficou no serviço do lançador: $(tr '\n' '|' < "$TMP/com.registro")"
fi
if grep -qE '^http://127\.0\.0\.1:[0-9]+/' "$TMP/com.aberto"; then
  ok "a página chegou ao navegador"
else
  falha "o navegador não recebeu a página: $(cat "$TMP/com.saida")"
fi

printf '\nsem systemd por perto, o painel abre do jeito de antes\n'
lancar sem 0
if [ "$(grep -c -- '--scope' "$TMP/sem.registro")" = "1" ] && grep -qF -- '--scope --quiet --collect true' "$TMP/sem.registro"; then
  ok "só a sondagem tocou o systemd-run"
else
  falha "o systemd-run recusado ainda embrulhou algo: $(tr '\n' '|' < "$TMP/sem.registro")"
fi
if grep -qE '^http://127\.0\.0\.1:[0-9]+/' "$TMP/sem.aberto"; then
  ok "a página chegou ao navegador sem escopo"
else
  falha "sem escopo o navegador não abriu: $(cat "$TMP/sem.saida")"
fi

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'painel-sobrevive-ao-lancador: tudo verde\n'; exit 0; fi
printf 'painel-sobrevive-ao-lancador: %s falha(s)\n' "$falhas"; exit 1

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falhas=0

LOCK='./.local/state/meowsystem/lock'

_rodar_seco() {
  env -i PATH="${MEOW_TESTE_PATH:-$PATH}" HOME="$1" USER="${USER:-t}" \
    MEOW_DRY_RUN=1 MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 \
    bash "$RAIZ/install.sh" > "${2:-/dev/null}" 2>&1
}

_v_do_pacote() {
  local n; n="$(ls -1 "/usr/share/cosmic/$1" 2>/dev/null | sed -n 's/^v\([0-9][0-9]*\)$/\1/p' | sort -n | tail -1)"
  printf 'v%s' "${n:-1}"
}
_plantar_unidades() {
  local u nome destino="$1/.config/systemd/user"
  mkdir -p "$destino"
  for u in "$RAIZ"/systemd/*; do
    nome="$(basename "$u")"
    if [ "$nome" = "meow-assets.path" ]; then
      HOME="$1" bash "$RAIZ/scripts/vigia_assets.sh" --unidade "$nome" > "$destino/$nome"
      chmod 644 "$destino/$nome"; continue
    fi
    sed -e "s|@ATIVOS@|$1/.local/share/backgrounds/meowsystem/ativos|g" \
        -e "s|@V_PANEL@|$(_v_do_pacote com.system76.CosmicPanel.Panel)|g" \
        -e "s|@V_DOCK@|$(_v_do_pacote com.system76.CosmicPanel.Dock)|g" "$u" > "$destino/$nome"
    chmod 644 "$destino/$nome"
  done
}

_retrato() {
  (cd "$1" && find . -type f ! -path "$LOCK" -print0 | sort -z |
     xargs -0 -r sha256sum)
}

H="$(mktemp -d)"; trap 'rm -rf "$H" "${H2:-}"' EXIT
_rodar_seco "$H"

sobra="$(cd "$H" && find . -type f ! -path "$LOCK")"
if [ -n "$sobra" ]; then
  printf 'FALHOU: MEOW_DRY_RUN=1 escreveu num HOME cru:\n%s\n' "$sobra" >&2
  falhas=$((falhas + 1))
else
  printf 'ok: o seco não escreveu nada num HOME cru\n'
fi

H2="$(mktemp -d)"
UNIDADES="$H2/.config/systemd/user"
ESTADO="$H2/.local/state/meowsystem"
mkdir -p "$UNIDADES" "$ESTADO"

_plantar_unidades "$H2"

MANIFESTO="$ESTADO/manifesto.tsv"
printf '%s\t%s\t%s\n' "$H2/.config/meow/meow.conf" "2026-09-22T00:00:00-03:00" \
  "0000000000000000000000000000000000000000000000000000000000000000" > "$MANIFESTO"

antes_manifesto="$(sha256sum "$MANIFESTO" | cut -d' ' -f1)"
antes="$(_retrato "$H2")"
_rodar_seco "$H2"
depois="$(_retrato "$H2")"
depois_manifesto="$(sha256sum "$MANIFESTO" 2>/dev/null | cut -d' ' -f1)"

if [ "$antes_manifesto" != "$depois_manifesto" ]; then
  printf 'FALHOU: o manifesto.tsv mudou no seco (%s -> %s)\n' \
    "${antes_manifesto:0:12}" "${depois_manifesto:-ausente}" >&2
  printf '  alguma etapa escreveu de verdade: a meow_escrever registra ali.\n' >&2
  falhas=$((falhas + 1))
else
  printf 'ok: o manifesto.tsv tem o mesmo sha256 antes e depois do ensaio\n'
fi

if [ "$antes" != "$depois" ]; then
  printf 'FALHOU: o seco mexeu num HOME já instalado:\n' >&2
  diff <(printf '%s\n' "$antes") <(printf '%s\n' "$depois") >&2
  falhas=$((falhas + 1))
else
  printf 'ok: o seco não mexeu em nada num HOME já instalado\n'
fi

H3="$(mktemp -d)"; trap 'rm -rf "$H" "${H2:-}" "${H3:-}" "${STUB3:-}"' EXIT
STUB3="$(mktemp -d)"
cat > "$STUB3/systemctl" <<'FIM'
#!/usr/bin/env bash
case "$*" in
  *is-enabled*) echo disabled; exit 1 ;;
  *is-active*)  echo inactive; exit 3 ;;
  *is-failed*)  echo inactive; exit 1 ;;
  *enable*|*disable*|*start*|*stop*|*reset-failed*)
     echo "MEOW-TESTE-ESCREVERIA: systemctl $*" >&2; exit 0 ;;
esac
exit 0
FIM
chmod +x "$STUB3/systemctl"
_plantar_unidades "$H3"
mkdir -p "$H3/.local/state/meowsystem"

SAIDA3="$H3.saida"
MEOW_TESTE_PATH="$STUB3:$PATH" _rodar_seco "$H3" "$SAIDA3"

faltou3=""
for u in meow-gato.timer meow-wallpaper.timer meow-fundo.path meow-ativos.path; do
  grep -q "$u" "$SAIDA3" || faltou3="$faltou3 $u"
done
if [ -n "$faltou3" ]; then
  printf 'FALHOU: o ensaio calou sobre unidade(s) que a execução real vai armar:%s\n' \
    "$faltou3" >&2
  printf '  ver o ramo `meow_seco` das etapas.\n' >&2
  falhas=$((falhas + 1))
else
  printf 'ok: o ensaio nomeia as quatro unidades que o real armaria\n'
fi

if grep -q 'MEOW-TESTE-ESCREVERIA' "$SAIDA3"; then
  printf 'FALHOU: o seco chamou o systemctl para ESCREVER:\n' >&2
  grep 'MEOW-TESTE-ESCREVERIA' "$SAIDA3" >&2
  falhas=$((falhas + 1))
else
  printf 'ok: o seco só PERGUNTOU ao systemd — nenhuma unidade foi armada\n'
fi
rm -f "$SAIDA3"

exit "$([ "$falhas" = 0 ] && echo 0 || echo 1)"

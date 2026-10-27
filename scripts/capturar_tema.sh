#!/usr/bin/env bash
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COSMIC="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"

ARVORES=(
  com.system76.CosmicTheme.Dark
  com.system76.CosmicTheme.Dark.Builder
  com.system76.CosmicTheme.Light
  com.system76.CosmicTheme.Light.Builder
  com.system76.CosmicTheme.Mode
)

uso() {
  cat <<'FIM'
uso: capturar_tema.sh <nome>

Fotografa as árvores de tema do COSMIC para packs/<pack ativo>/temas/capturados/<nome>/.

  <nome>   como a captura se chama. Ex.: original, mocha-mauve, latte-mauve.

Variáveis:
  MEOW_COSMIC_DIR   de onde ler (padrão: ~/.config/cosmic). Útil para testar.
FIM
}

[ $# -eq 1 ] || { uso >&2; exit 2; }
NOME="$1"
case "$NOME" in
  ''|*/*|.*) echo "ERRO: nome inválido: '$NOME'" >&2; exit 2 ;;
esac

if [ "$NOME" = "original" ] && [ "${MEOW_RECAPTURAR_ORIGINAL:-0}" != "1" ]; then
  echo "ERRO: 'original' é o reset de fábrica e não se recaptura." >&2
  echo "      É o que 'meow desfazer' restaura e o molde do gerar_tema_v1.py." >&2
  echo "      Se é mesmo isso que você quer:" >&2
  echo "        MEOW_RECAPTURAR_ORIGINAL=1 $0 original" >&2
  exit 2
fi

DESTINO="$(python3 "$RAIZ/scripts/pack.py" captura-destino "$NOME" 2>/dev/null)" || DESTINO=""
if [ -z "$DESTINO" ]; then
  echo "ERRO: não sei onde gravar a captura '$NOME' — o pack ativo não resolve." >&2
  echo "      confira com: meow pack listar" >&2
  exit 3
fi

if [ ! -d "$COSMIC" ]; then
  echo "ERRO: $COSMIC não existe — isto é um COSMIC?" >&2
  exit 3
fi

TMP="$DESTINO.parcial.$$"
rm -rf "$TMP"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

total=0
ausentes=()
for arvore in "${ARVORES[@]}"; do
  origem="$COSMIC/$arvore"
  if [ ! -d "$origem" ]; then
    ausentes+=("$arvore")
    continue
  fi
  cp -a "$origem" "$TMP/"
  n=$(find "$origem" -type f | wc -l)
  total=$((total + n))
  printf '  %-44s %3d arquivos\n' "$arvore" "$n"
done

if [ "$total" -eq 0 ]; then
  echo "ERRO: nenhuma árvore de tema encontrada em $COSMIC" >&2
  exit 3
fi

( cd "$TMP" && find . -type f ! -name manifesto.sha256 -print0 \
    | sort -z | xargs -0 sha256sum > manifesto.sha256 )

origem_da_maquina() { printf 'máquina %s' "$(printf '%s' "$1" | sha256sum | cut -c1-16)"; }
ORIGEM="$COSMIC"
[ "$NOME" = "original" ] && ORIGEM="$(origem_da_maquina "$COSMIC")"
if [ "$NOME" != "original" ] && [ -n "${HOME:-}" ]; then
  # shellcheck disable=SC2088
  case "$COSMIC" in "$HOME"/*) ORIGEM="~/${COSMIC#"$HOME"/}" ;; esac
fi

{
  echo "captura: $NOME"
  echo "quando: $(date -Iseconds)"
  echo "origem: $ORIGEM"
  echo "arquivos: $total"
  [ ${#ausentes[@]} -gt 0 ] && echo "ausentes: ${ausentes[*]}"
} > "$TMP/captura.txt"

if [ -d "$DESTINO" ]; then
  BK="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/$(date +%Y-%m-%dT%H-%M-%S)-captura-$NOME"
  if mkdir -p "$BK" && cp -a "$DESTINO/." "$BK/"; then
    printf '%s\n' "$DESTINO" >> "$BK/origens.txt"
    echo "  a captura anterior de '$NOME' ficou em $BK"
  else
    echo "ERRO: não consegui guardar a captura anterior em $BK — nada foi apagado" >&2
    exit 2
  fi
fi

rm -rf "$DESTINO"
mkdir -p "$(dirname "$DESTINO")"
mv "$TMP" "$DESTINO"
trap - EXIT

echo
echo "capturado: ${DESTINO#"$RAIZ"/}/  ($total arquivos)"
[ ${#ausentes[@]} -gt 0 ] && echo "aviso: árvores ausentes nesta máquina: ${ausentes[*]}"
exit 0

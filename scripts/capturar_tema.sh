#!/usr/bin/env bash
# capturar_tema.sh — fotografa as árvores de tema do COSMIC para dentro do pack ativo.
#
# O COSMIC não tem CLI de tema: a derivação que transforma o que a GUI edita
# (`*.Builder/v1`) no que o sistema lê (`*/v1` e `*/v2`) mora dentro do app
# gráfico.
#
# A saída é fotografar.
#
# As quatro árvores (Dark, Dark.Builder, Light, Light.Builder) mais o Mode.
#
# Sem sha256 não há como saber, meses depois, se a captura ainda descreve o que
# está no disco — e é exatamente isso que o `meow doctor` precisa perguntar para
# decidir se conserta ou fica quieto.
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

# `original` é o tema de fábrica, e recapturá-lo é via de mão única: daí em diante o
# `desfazer` restauraria o tema que estava na tela, sem erro nenhum.
# É o que `meow desfazer` restaura (bin/meow, `cmd_desfazer`) e o molde de que o
# `gerar_tema_v1.py` deriva a v1 — e AQUELE script já recusa escrever nela, pelo
# mesmo motivo (`MOLDE = "original"`).
if [ "$NOME" = "original" ] && [ "${MEOW_RECAPTURAR_ORIGINAL:-0}" != "1" ]; then
  echo "ERRO: 'original' é o reset de fábrica e não se recaptura." >&2
  echo "      É o que 'meow desfazer' restaura e o molde do gerar_tema_v1.py." >&2
  echo "      Se é mesmo isso que você quer:" >&2
  echo "        MEOW_RECAPTURAR_ORIGINAL=1 $0 original" >&2
  exit 2
fi

# O `pack.py captura` acha o `mocha-mauve` do Catppuccin mesmo com o Dracula no
# ar, porque o Dracula herda dele.
#
# Com o `set -euo pipefail` da linha 25, uma atribuição por substituição de
# comando que FALHA aborta o script ali mesmo.
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

# Recapturar por cima poderia deixar sobra da captura anterior (um arquivo que o
# tema novo não tem continuaria lá e seria restaurado junto). Monta-se ao lado e
# troca-se no fim — o destino nunca fica pela metade.
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

# Manifesto com caminhos RELATIVOS: a captura precisa ser comparável em outra
# máquina, onde o $HOME tem outro nome.
( cd "$TMP" && find . -type f ! -name manifesto.sha256 -print0 \
    | sort -z | xargs -0 sha256sum > manifesto.sha256 )

# Esta linha gravava o `$COSMIC` expandido, e com ele o nome de usuário de quem
# capturou.
#
# Na `original` a origem é a identidade da máquina, que a `guarda_original` do
# bin/meow confere: um resumo do caminho do COSMIC, sem o caminho no arquivo.
origem_da_maquina() { printf 'máquina %s' "$(printf '%s' "$1" | sha256sum | cut -c1-16)"; }
ORIGEM="$COSMIC"
[ "$NOME" = "original" ] && ORIGEM="$(origem_da_maquina "$COSMIC")"
if [ "$NOME" != "original" ] && [ -n "${HOME:-}" ]; then
  # shellcheck disable=SC2088  # o "~" é o DADO que se grava, não caminho a expandir
  case "$COSMIC" in "$HOME"/*) ORIGEM="~/${COSMIC#"$HOME"/}" ;; esac
fi

{
  echo "captura: $NOME"
  echo "quando: $(date -Iseconds)"
  echo "origem: $ORIGEM"
  echo "arquivos: $total"
  [ ${#ausentes[@]} -gt 0 ] && echo "ausentes: ${ausentes[*]}"
} > "$TMP/captura.txt"

# Guarda antes de destruir: este era o único `rm -rf` sem rede embaixo. O sufixo
# `-captura-` fica fora da poda do `aplicar_tema.sh`, que só colhe `-tema-`.
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

#!/usr/bin/env bash
# capturar_tema.sh — fotografa as árvores de tema do COSMIC para state/tema/<nome>/.
#
# POR QUE ISTO EXISTE
#   O COSMIC não tem CLI de tema: a derivação que transforma o que a GUI edita
#   (`*.Builder/v1`) no que o sistema lê (`*/v1` e `*/v2`) mora dentro do app
#   gráfico. Não dá para reproduzir de fora, e escrever chave por chave à mão
#   produz um tema híbrido que "quase" funciona.
#
#   A saída é fotografar. A Vitória importa o tema UMA vez pela GUI, este script
#   captura o resultado inteiro, e a partir daí aplicar é copiar de volta —
#   sem GUI, sem flag e replicável numa máquina recém-formatada.
#
# O QUE SE CAPTURA, E POR QUE TUDO
#   As quatro árvores (Dark, Dark.Builder, Light, Light.Builder) mais o Mode.
#   Capturar só a que "parece" relevante é o erro clássico: as árvores derivadas
#   já discordam entre si nesta máquina (Dark/v1 tem 30 chaves, Dark/v2 tem 17,
#   e o `window_hint` de uma é `Some(...)` enquanto o da outra é `None`).
#   Metade da foto reproduz meio tema.
#
# O MANIFESTO NÃO É BUROCRACIA
#   Sem sha256 não há como saber, meses depois, se a captura ainda descreve o
#   que está no disco — e é exatamente isso que o `meow doctor` precisa perguntar
#   para decidir se conserta ou fica quieto.
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

Fotografa as árvores de tema do COSMIC para state/tema/<nome>/.

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

DESTINO="$RAIZ/state/tema/$NOME"

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

{
  echo "captura: $NOME"
  echo "quando: $(date -Iseconds)"
  echo "origem: $COSMIC"
  echo "arquivos: $total"
  [ ${#ausentes[@]} -gt 0 ] && echo "ausentes: ${ausentes[*]}"
} > "$TMP/captura.txt"

rm -rf "$DESTINO"
mkdir -p "$(dirname "$DESTINO")"
mv "$TMP" "$DESTINO"
trap - EXIT

echo
echo "capturado: state/tema/$NOME/  ($total arquivos)"
[ ${#ausentes[@]} -gt 0 ] && echo "aviso: árvores ausentes nesta máquina: ${ausentes[*]}"
exit 0

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v python3 >/dev/null || { printf 'pulado: sem python3\n'; exit 3; }
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas + 1)); }
CORTA() { python3 "$RAIZ/scripts/comentarios.py" "$@"; }

printf '# cabeçalho\n#!cor-por-categoria\na : x.svg   # rótulo\n\n# meio\n# app: Nome\nb:c:d\n' > "$T/com-dado.map"
printf '# só comentário\n# nenhuma linha de dado\n' > "$T/sem-dado.map"
printf 'a\t#não é comentário\n# header\tcol\nb\tc\n' > "$T/dados.tsv"

[ "$(CORTA zerar "$T/com-dado.map")" = "mudou  $T/com-dado.map" ] \
  && ok "o mapa com dado perde a linha inteira de comentário" || falha "o mapa com dado não foi cortado"
[ "$(cat "$T/com-dado.map")" = "$(printf '#!cor-por-categoria\na : x.svg   # rótulo\n\n# app: Nome\nb:c:d')" ] \
  && ok "ficam a diretiva #!, o rótulo # app:, o dado e o rótulo depois do dado" || falha "o corte mexeu no que era dado: $(cat "$T/com-dado.map")"
[ -z "$(CORTA zerar "$T/com-dado.map")" ] \
  && ok "a segunda passada não escreve nada" || falha "a segunda passada ainda escreveu"
[ -z "$(CORTA zerar "$T/sem-dado.map")" ] && [ "$(wc -l < "$T/sem-dado.map")" = 2 ] \
  && ok "o arquivo sem nenhuma linha de dado fica como está" || falha "o arquivo só de comentário foi cortado"
CORTA zerar "$T/dados.tsv" >/dev/null
[ "$(cat "$T/dados.tsv")" = "$(printf 'a\t#não é comentário\nb\tc')" ] \
  && ok "o # no meio da coluna é dado, só a linha que começa por # sai" || falha "o tsv ficou errado: $(cat "$T/dados.tsv")"

r="$(cd "$RAIZ" && git ls-files -z -- '*.map' '*.tsv' '*.conf' '*.exemplo' | xargs -0 python3 scripts/comentarios.py conferir 2>&1)" \
  && ok "nenhum mapa, tsv, conf ou exemplo versionado tem linha de comentário" \
  || falha "arquivo de dado com comentário: $(head -n3 <<< "$r" | tr '\n' ' ')"

[ "$falhas" = 0 ]

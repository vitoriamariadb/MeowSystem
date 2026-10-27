#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TSV="$RAIZ/assets/contratos/chave-etapa.tsv"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT
falhas=0
falhou() { printf 'FALHOU: %s\n' "$*" >&2; falhas=$((falhas+1)); }

chaves="$(grep -oE '^[A-Z][A-Z_0-9]*=' "$RAIZ/meow.conf.exemplo" | tr -d '=' | sort -u)"
da_tabela="$(cut -f1 "$TSV" | sort)"
sem_linha="$(comm -23 <(printf '%s\n' "$chaves") <(printf '%s\n' "$da_tabela"))"
sobrando="$(comm -13 <(printf '%s\n' "$chaves") <(printf '%s\n' "$da_tabela"))"
[ -z "$sem_linha" ] || falhou "chave do meow.conf.exemplo sem linha na tabela: $(printf '%s' "$sem_linha" | tr '\n' ' ')"
[ -z "$sobrando" ] || falhou "linha da tabela sem chave no exemplo: $(printf '%s' "$sobrando" | tr '\n' ' ')"
[ "$(cut -f1 "$TSV" | sort | uniq -d | wc -l)" = 0 ] || falhou "chave repetida na tabela"
[ "$(grep -vcE $'^[A-Z][A-Z_0-9]*\t[^\t]+\t(sim|nao)$' "$TSV")" = 0 ] || falhou "linha mal formada na tabela"

existentes="$(grep -oE 'etapa_[a-z0-9_]+' "$RAIZ/install.sh" | sed 's/^etapa_//' | sort -u)"
nomes="$(cut -f2 "$TSV" | tr ',' '\n' | grep -vE '^(\*|-)$' | sort -u)"
for n in $nomes; do
  printf '%s\n' "$existentes" | grep -qx "$n" || falhou "a tabela cita a etapa $n e ela não existe no install.sh"
done

saida="$(env -i PATH="$PATH" HOME="$H" USER=t MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 MEOW_PONTE=/nao/existe \
  bash "$RAIZ/install.sh" --dry-run --etapa forma 2>&1)"
printf '%s\n' "$saida" | grep -q 'Pronto. 1 passagem, 1 etapa' \
  || falhou "--etapa forma devia rodar uma etapa só: $(printf '%s' "$saida" | tail -3)"
env -i PATH="$PATH" HOME="$H" USER=t NO_COLOR=1 bash "$RAIZ/install.sh" --dry-run --etapa nao_existe >/dev/null 2>&1
[ $? = 2 ] || falhou "--etapa com nome que não existe devia sair 2"

planos="$(MEOW_RAIZ="$RAIZ" python3 -I - "$RAIZ/app" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import servidor
f = servidor.plano_de_aplicacao
erros = []
p = f(["FORMA_DOCK_SOLTO"])
if p["completo"] or p["etapas"] != ["forma"] or p["root"]:
    erros.append("FORMA_DOCK_SOLTO %r" % p)
p = f(["FORMA_DOCK_SOLTO", "VIDRO_OPACIDADE_DOCK"])
if p["etapas"] != ["forma", "vidro"]:
    erros.append("forma+vidro %r" % p)
if not f(["FLAVOR"])["completo"]:
    erros.append("FLAVOR devia aplicar tudo")
if not f(["LOG_NIVEL"])["nada"]:
    erros.append("LOG_NIVEL não aplica nada")
if not f(["PONTE_ROOT"])["root"]:
    erros.append("PONTE_ROOT pede a ponte")
if not f(["CHAVE_QUE_NAO_EXISTE"])["completo"]:
    erros.append("chave desconhecida devia cair no instalador inteiro")
print("\n".join(erros))
PY
)"
[ -z "$planos" ] || falhou "plano de aplicação: $planos"

[ "$falhas" = 0 ] && printf 'ok: toda chave do exemplo tem etapa na tabela, as etapas existem, --etapa roda só o pedido\n'
exit $((falhas > 0))

#!/usr/bin/env bash
# arvore.sh — a fronteira entre o que o MeowSystem É e o que ele VESTE.
#
# A pergunta é "isto está VERSIONADO?", e só o `git ls-files` responde. Aqui a
# ferramenta é a que sabe a resposta.
#
# 0 = passou · 1 = falhou · 2 = erro deste teste.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v git >/dev/null 2>&1 || { printf 'pulado: sem git\n'; exit 0; }
git -C "$RAIZ" rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'pulado: %s não é um clone git\n' "$RAIZ"; exit 0; }

versionados() { git -C "$RAIZ" ls-files -- "$@"; }

# Mostra no máximo cinco caminhos e diz quantos sobraram. Uma falha que despeja
# trezentas linhas é uma falha que ninguém lê até o fim.
amostra() {
  local n=0 linha
  while IFS= read -r linha; do
    [ -n "$linha" ] || continue
    n=$((n + 1))
    [ "$n" -le 5 ] && printf '         %s\n' "$linha" >&2
  done
  [ "$n" -gt 5 ] && printf '         ... e mais %d\n' "$((n - 5))" >&2
  return 0
}

printf 'a fronteira: assets/ é o motor, packs/ é o tema\n\n'

# --- 1. NADA DE TEMA EM assets/temas/, MENOS A `original` -------------------
#
# Ela não é tema de pack nenhum: é o MOLDE do esquema v1 que o COSMIC de
# 04/2026 escrevia — o `scripts/gerar_tema_v1.py` deriva dela chave por chave —
# e é o reset de fábrica DESTA máquina.
#
# ENTÃO ESTE TESTE NÃO COBRA "assets/temas VAZIO".
fora=$(versionados assets/temas | grep -v '^assets/temas/capturados/original/' || true)
if [ -z "$fora" ]; then
  ok "assets/temas/ só tem a captura 'original' ($(versionados assets/temas | wc -l) arquivos, o molde do v1)"
else
  falha "há tema versionado em assets/temas/ que não é a 'original' — ele pertence a um pack"
  printf '%s\n' "$fora" | amostra
fi

# --- 2. NENHUM .ron VERSIONADO EM assets/ OU packs/ -------------------------
#
# O `.ron` é PRODUTO: entra a paleta do pack mais o `cosmic-map.json`, sai o
# arquivo.
#
# `docs/` FICA DE FORA DA REGRA, E DE PROPÓSITO: o
# `docs/historico/estilo-escuro-original.ron` é o `cosmic-dark` de fábrica,
# guardado como REGISTRO do que havia antes deste projeto.
rons=$(versionados 'assets/*.ron' 'packs/*.ron' || true)
if [ -z "$rons" ]; then
  ok "nenhum .ron versionado em assets/ nem em packs/ — produto gerado mora em \$MEOW_ESTADO/temas/"
else
  falha "há .ron versionado: ele é saída de scripts/gerar_temas.py, não fonte"
  printf '%s\n' "$rons" | amostra
fi

# --- 3. assets/icones/upstream/ SEM NADA NO GIT -----------------------------
#
# Não havia o que tirar.
n_up=$(versionados assets/icones/upstream | wc -l)
if [ "$n_up" = "0" ]; then
  ok "assets/icones/upstream/ tem 0 arquivos versionados — é acervo baixado, e o que se versiona é o script que baixa"
else
  falha "assets/icones/upstream/ tem $n_up arquivo(s) no git — é acervo de terceiro, baixado por scripts/baixar_upstream.sh"
  versionados assets/icones/upstream | amostra
fi

# --- 4. TODA CAPTURA DE PACK ESTÁ ONDE O RESOLVEDOR A PROCURA ---------------
#
# O `docs/PACKS.md` publica o caminho
# `packs/<id>/temas/capturados/<flavor>-<accent>/`, e é ele que o
# `scripts/pack.py captura` procura.
achadas=0
while IFS= read -r par; do
  [ -n "$par" ] || continue
  id_pack="${par%%/*}"; nome="${par##*/}"
  esperado="$RAIZ/packs/$id_pack/temas/capturados/$nome"
  resolvido="$(MEOW_PACK_DIR="$RAIZ/packs/$id_pack" \
    python3 "$RAIZ/scripts/pack.py" captura "$nome" 2>/dev/null)"
  if [ "$resolvido" = "$esperado" ]; then
    achadas=$((achadas + 1))
  else
    falha "a captura '$nome' do pack '$id_pack' não é a que o resolvedor acha"
    printf '         no disco:    %s\n' "$esperado" >&2
    printf '         resolvedor:  %s\n' "${resolvido:-<nada>}" >&2
  fi
done < <(versionados 'packs/*/temas/capturados/*' \
         | awk -F/ 'NF>=5 {print $2"/"$5}' | sort -u)
[ "$achadas" -gt 0 ] \
  && ok "as $achadas capturas dos packs são exatamente as que o pack.py resolve" \
  || falha "nenhum pack traz captura — o docs/PACKS.md promete que eles podem"

# --- 5. NENHUM ARQUIVO DE TEMA SOLTO EM assets/, POR NOME DE FLAVOR ---------
#
# A LISTA DE FLAVORS VEM DO DISCO, e não escrita aqui.
flavors=$(python3 - "$RAIZ" <<'PY'
import glob, json, os, sys
raiz = sys.argv[1]
nomes = set()
for p in glob.glob(os.path.join(raiz, "packs", "*", "paleta.json")):
    try:
        with open(p, encoding="utf-8") as fh:
            d = json.load(fh)
    except (OSError, json.JSONDecodeError):
        continue
    fl = d.get("flavors")
    nomes.update(fl.keys() if isinstance(fl, dict) else (fl or []))
    nomes.update(d.get("claros") or [])
print("|".join(sorted(n for n in nomes if n)))
PY
)
if [ -z "$flavors" ]; then
  falha "não consegui ler nenhum flavor de packs/*/paleta.json — sem isso esta conferência não mede nada"
else
  ISENTOS=()
  soltos=$(versionados assets | grep -Ei "($flavors)" || true)
  restantes="$soltos"
  for isento in ${ISENTOS[@]+"${ISENTOS[@]}"}; do
    n=$(printf '%s\n' "$restantes" | grep -c "^$isento" || true)
    if [ "$n" = "0" ]; then
      falha "a isenção '$isento' não cobre mais nada — apague-a deste teste"
    fi
    restantes=$(printf '%s\n' "$restantes" | grep -v "^$isento" || true)
  done
  if [ -z "$restantes" ]; then
    ok "nenhum arquivo de tema solto em assets/ (os temas de aplicativo moram nos packs)"
  else
    falha "há arquivo com nome de flavor em assets/, fora das isenções — ele veste alguém, logo é de um pack"
    printf '%s\n' "$restantes" | amostra
  fi
fi

# --- 6. O QUE O CREDITOS.md, O PACKS.md E O PROCEDENCIA.md APONTAM EXISTE ----
#
# A coluna «onde» do CREDITOS.md e a saída medida do `captura-destino` no
# PACKS.md ficaram nas pastas de antes da P96 (`packs/catppuccin/`, as
# subpastas `arcticons/` e `convertidos/`). Um caminho entre crases que começa
# em `packs/` ou `assets/` ali é do git de hoje.
sumidos=""
while IFS= read -r c; do
  [ -n "$(versionados "$c")" ] || sumidos+="docs/CREDITOS.md: $c"$'\n'
done < <(grep -oE '`(packs|assets)/[^`<>*{} :]+`' "$RAIZ/docs/CREDITOS.md" | tr -d '`' | sort -u)
# A coluna «onde» da tabela de acervos do PROCEDENCIA.md do pack-base, idem.
while IFS= read -r c; do
  [ -n "$(versionados "$c")" ] || sumidos+="packs/meowsystem/PROCEDENCIA.md: $c"$'\n'
done < <(awk -F'|' '/^\| acervo \| onde /{t=1; next} t && !/^\|/{t=0} t{print $3}' \
           "$RAIZ/packs/meowsystem/PROCEDENCIA.md" | grep -oE '`(packs|assets)/[^`<>*{} :]+`' | tr -d '`' | sort -u)
while IFS= read -r id; do
  [ -d "$RAIZ/packs/$id" ] || sumidos+="docs/PACKS.md: <clone>/packs/$id/"$'\n'
done < <(grep -oE '<clone>/packs/[a-z0-9-]+/' "$RAIZ/docs/PACKS.md" | sed 's#<clone>/packs/##; s#/$##' | sort -u)
if [ -z "$sumidos" ]; then
  ok "o CREDITOS.md, o PACKS.md e o PROCEDENCIA.md do pack-base só apontam para o que está no git"
else
  falha "caminho que não existe mais no CREDITOS.md, no PACKS.md ou no PROCEDENCIA.md do pack-base"
  printf '%s' "$sumidos" | amostra
fi

printf '\n'
if [ "$ACHADOS" = "0" ]; then
  printf 'ok: a fronteira está de pé — o motor em assets/, o tema em packs/\n'
  exit 0
fi
printf 'NÃO: %d conferência(s) da fronteira falharam\n' "$ACHADOS" >&2
exit 1

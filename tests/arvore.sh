#!/usr/bin/env bash
# arvore.sh — a fronteira entre o que o MeowSystem É e o que ele VESTE.
#
# POR QUE ESTE ARQUIVO NASCEU EM 22/09/2026
#   A queixa era uma frase: *"aqui deveria ter tudo do theme dracula"*. O que
#   ela apontava não era peso nem desorganização — era DONO. `assets/` guardava
#   três coisas de naturezas diferentes no mesmo nível: o traço do projeto (os
#   ícones autorais, os gatos, o molde do tema), o acervo de um tema de terceiro
#   (3.281 SVG do Catppuccin) e a saída gerada (sete `.ron`). Sem uma linha
#   escrita entre elas, cada sprint punha a coisa nova onde desse.
#
#   A LINHA É UMA FRASE, e é a que este teste cobra:
#       `assets/`  é o que o MeowSystem É — o motor.
#       `packs/`   é o que ele VESTE — o tema.
#       `$MEOW_ESTADO/` é o que a máquina gerou, e não volta para o git.
#
# O QUE ELE PERGUNTA AO GIT, E NÃO AO DISCO
#   A pergunta é "isto está VERSIONADO?", e só o `git ls-files` responde. Medir
#   o disco foi exatamente o erro que custou a primeira versão da sprint P14: o
#   `du` disse que `assets/icones/catppuccin/` tinha 13 MB (são 413 KB — o bloco
#   de 4 KB mentindo sobre milhares de SVG minúsculos) e que
#   `assets/icones/upstream/` tinha 96 MB versionados, quando ele tem ZERO
#   arquivos no git desde sempre. Um passo inteiro da sprint foi apagado por
#   causa disso. Aqui a ferramenta é a que sabe a resposta.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = passou · 1 = falhou · 2 = erro deste teste.
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
# A `original` FICA, E O MOTIVO NÃO É SAUDOSISMO
#   Ela não é tema de pack nenhum: é o MOLDE do esquema v1 que o COSMIC de
#   04/2026 escrevia — o `scripts/gerar_tema_v1.py` deriva dela chave por chave
#   — e é o reset de fábrica DESTA máquina. O `capturar_tema.sh` recusa
#   recapturá-la, então fora do git ela é irrecuperável. Quem vai mexer no
#   destino dela é a P24, que já a chama de `referencia/`.
#
#   ENTÃO ESTE TESTE NÃO COBRA "assets/temas VAZIO". Ele cobra que tudo o que
#   sobrou ali seja a `original` — que é a diferença entre uma fronteira e uma
#   faxina.
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
# arquivo. Versionar produto é o que permite que o disco e a receita divirjam, e
# o `docs/SPRINTS.md` já tinha nome para o defeito — *"o doctor enxerga receita
# diferente de produto"*. Desde 22/09/2026 eles nascem em `$MEOW_ESTADO/temas/`.
#
# `docs/` FICA DE FORA DA REGRA, E DE PROPÓSITO: o
# `docs/historico/estilo-escuro-original.ron` é o `cosmic-dark` de fábrica,
# guardado como REGISTRO do que havia antes deste projeto. Ele não é saída de
# script nenhum, e ninguém o regenera — apagá-lo seria perder a única cópia.
rons=$(versionados 'assets/*.ron' 'packs/*.ron' || true)
if [ -z "$rons" ]; then
  ok "nenhum .ron versionado em assets/ nem em packs/ — produto gerado mora em \$MEOW_ESTADO/temas/"
else
  falha "há .ron versionado: ele é saída de scripts/gerar_temas.py, não fonte"
  printf '%s\n' "$rons" | amostra
fi

# --- 3. assets/icones/upstream/ SEM NADA NO GIT -----------------------------
#
# Ele já estava ignorado (`.gitignore:3`) desde muito antes desta sprint, e a
# primeira versão da P14 mandava tirá-lo do repositório com base numa medição de
# DISCO. Não havia o que tirar. Esta conferência existe para que a próxima
# pessoa não pague de novo pela mesma dúvida: a resposta fica escrita e medida.
n_up=$(versionados assets/icones/upstream | wc -l)
if [ "$n_up" = "0" ]; then
  ok "assets/icones/upstream/ tem 0 arquivos versionados — é acervo baixado, e o que se versiona é o script que baixa"
else
  falha "assets/icones/upstream/ tem $n_up arquivo(s) no git — é acervo de terceiro, baixado por scripts/baixar_upstream.sh"
  versionados assets/icones/upstream | amostra
fi

# --- 4. TODA CAPTURA DE PACK ESTÁ ONDE O RESOLVEDOR A PROCURA ---------------
#
# NÃO BASTA ELA ESTAR "DENTRO DO PACK". O `docs/PACKS.md` publica o caminho
# `packs/<id>/temas/capturados/<flavor>-<accent>/`, e é ele que o
# `scripts/pack.py captura` procura. Uma captura um nível acima ou com o
# diretório no plural errado ficaria no disco, no git, dentro do pack — e
# invisível para todo mundo que a fosse usar. É o defeito de `state/tema/`, que
# fez o `meow tema` listar o vazio por semanas sem errar uma linha.
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
# A LISTA DE FLAVORS VEM DO DISCO, e não escrita aqui. Um pack novo traz nomes
# novos, e uma lista cravada neste arquivo seria a armadilha nº 3 do projeto —
# toda lista fixa é uma lista que alguém vai esquecer de atualizar.
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
  # AS DUAS ISENÇÕES, COM O MOTIVO E O NÚMERO MEDIDO
  #
  #   assets/temas-de-apps/  — NÃO É DÍVIDA, É CONTRATO PRÓPRIO. São os temas que
  #     os OUTROS aplicativos publicam (o `dracula.css` do Heroic, o
  #     `catppuccin-mocha.theme` do btop), baixados do upstream deles e
  #     conferidos por SHA256. O nome do flavor está no arquivo do terceiro, não
  #     no nosso. A árvore-alvo da P14 diz, com todas as letras, "contrato
  #     próprio, fica".
  #
  #   assets/icones/autorais/ — MORREU EM 22/09/2026, e do jeito que este
  #     comentário prometia. Era dívida com dono e data: os ícones desenhados
  #     aqui em cinco sabores (`cosmic-edit-mocha.svg`, `cosmic-edit-dracula.svg`
  #     …), que vestem alguém e por isso pertencem ao pack. A P27 os moveu — 44
  #     para packs/catppuccin/icones/autorais/ e 11 para o Dracula, mais os 11
  #     do alucard que ela gerou — e no mesmo dia esta isenção parou de casar
  #     e foi apagada, que é a regra escrita logo abaixo.
  #
  # A ISENÇÃO MORRE SOZINHA quando o diretório esvaziar: este laço exige que
  # cada uma ainda CASE alguma coisa. Uma isenção que não protege mais nada é um
  # comentário que mente, e o dia de apagá-la é o dia em que ela para de casar.
  ISENTOS=(
    "assets/temas-de-apps/"
  )
  soltos=$(versionados assets | grep -Ei "($flavors)" || true)
  restantes="$soltos"
  for isento in "${ISENTOS[@]}"; do
    n=$(printf '%s\n' "$restantes" | grep -c "^$isento" || true)
    if [ "$n" = "0" ]; then
      falha "a isenção '$isento' não cobre mais nada — apague-a deste teste"
    fi
    restantes=$(printf '%s\n' "$restantes" | grep -v "^$isento" || true)
  done
  if [ -z "$restantes" ]; then
    ok "nenhum arquivo de tema solto em assets/ (1 isenção: os temas de aplicativo)"
  else
    falha "há arquivo com nome de flavor em assets/, fora das isenções — ele veste alguém, logo é de um pack"
    printf '%s\n' "$restantes" | amostra
  fi
fi

printf '\n'
if [ "$ACHADOS" = "0" ]; then
  printf 'ok: a fronteira está de pé — o motor em assets/, o tema em packs/\n'
  exit 0
fi
printf 'NÃO: %d conferência(s) da fronteira falharam\n' "$ACHADOS" >&2
exit 1

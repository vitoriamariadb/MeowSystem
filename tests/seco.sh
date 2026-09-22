#!/usr/bin/env bash
# O seco não escreve NADA fora do próprio lock.
#
# JÁ FALHOU UMA VEZ, E EM SILÊNCIO: a fase de DETECÇÃO chamava
# `code --list-extensions` e `flatpak info`, e cada um deixava rastro no HOME —
# oito arquivos, medidos em 10/08/2026 num HOME criado do zero. Nenhum deles é
# configuração, então nenhuma trava pegava: o que quebrava era a única promessa
# que o README faz sobre auditoria.
#
# `MEOW_IGNORA_DESKTOP=1` porque o pré-voo recusa máquina sem COSMIC, e este
# teste tem de rodar em qualquer lugar — inclusive num CI sem sessão gráfica.
#
# ---------------------------------------------------------------------------
# A SEGUNDA RODADA — 22/09/2026, sprint P8
# ---------------------------------------------------------------------------
# UM HOME CRU NÃO TESTA A PARTE QUE MENTE. Medido hoje, antes de escrever este
# bloco: num HOME criado do zero, toda etapa acha o disco vazio, toda escrita é
# nova, e cada ramo `meow_seco` sai pelo "mudaria" na primeira pergunta. O
# caminho em que o instalador acha o arquivo JÁ NO LUGAR — e é lá que ele
# resolve o que fazer com a unidade do systemd — nunca era percorrido por este
# teste. A rodada 1 vigia o que o seco ESCREVE; ela não alcança o que ele DIZ.
#
# Então vem a rodada 2, com um HOME que já tem as unidades no disco e um
# `manifesto.tsv` dentro. Ela é a conferência que a sprint P8 escreveu:
#
#     sha256sum ~/.local/state/meowsystem/manifesto.tsv > /tmp/antes
#     MEOW_DRY_RUN=1 ./install.sh …
#     sha256sum -c /tmp/antes    # espera: OK
#
# O manifesto é o alvo certo para essa frase porque ele é o ÚNICO arquivo que
# cresce a cada escrita de configuração, sem exceção: quem o alimenta é a
# `meow_escrever`, no único ponto por onde toda escrita passa
# (`meow_manifesto_registrar`, lib/comum.sh). Um seco que escondesse uma escrita
# em qualquer das etapas deixaria a linha dela ali. Por isso ele é conferido
# pelo nome, além de entrar no retrato geral — a frase da sprint tem de poder
# ser lida neste arquivo.
#
# E POR QUE NÃO `--uma-passagem`, QUE A SPRINT CITA: desde 21/09/2026 (sprint
# P1) o ensaio JÁ É de uma passagem por definição, e o `install.sh` crava o teto
# em 1 quando `meow_seco` — no seco nada é escrito, então a etapa que diverge
# hoje divergiria igual na passagem seguinte, e o laço bateria no teto SEMPRE.
# Chamar com a flag testaria o caminho de depuração e deixaria de vigiar
# justamente essa regra: se alguém a remover, este teste passa a rodar cinco
# passagens e o tempo dele denuncia.
#
# CÓDIGOS DE SAÍDA: 0 = passou · 1 = o seco escreveu ou mexeu em algo.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falhas=0

# O lock é a única escrita legítima do seco: ele é tomado ANTES de a primeira
# etapa rodar, e é o que impede duas execuções simultâneas — inclusive duas
# execuções em ensaio, que leriam a mesma máquina e disputariam o mesmo
# terminal. Ele fica de fora das duas rodadas, pelo caminho exato.
LOCK='./.local/state/meowsystem/lock'

_rodar_seco() {   # $1 = o HOME de brinquedo
  env -i PATH="$PATH" HOME="$1" USER="${USER:-t}" \
    MEOW_DRY_RUN=1 MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 \
    bash "$RAIZ/install.sh" >/dev/null 2>&1
}

# O retrato é CAMINHO + sha256 de cada arquivo, e não só a lista de nomes: um
# seco que reescrevesse um arquivo com outro conteúdo não mudaria nome nenhum,
# e uma comparação de listas diria que está tudo bem. `-print0`/`sort -z`
# porque caminho pode ter espaço, e a ordem do `find` não é estável.
_retrato() {      # $1 = o HOME de brinquedo
  (cd "$1" && find . -type f ! -path "$LOCK" -print0 | sort -z |
     xargs -0 -r sha256sum)
}

# ---------------------------------------------------------------------------
# Rodada 1 — HOME cru: o seco não deixa UM arquivo para trás
# ---------------------------------------------------------------------------
H="$(mktemp -d)"; trap 'rm -rf "$H" "${H2:-}"' EXIT
_rodar_seco "$H"

sobra="$(cd "$H" && find . -type f ! -path "$LOCK")"
if [ -n "$sobra" ]; then
  printf 'FALHOU: MEOW_DRY_RUN=1 escreveu num HOME cru:\n%s\n' "$sobra" >&2
  falhas=$((falhas + 1))
else
  printf 'ok: o seco não escreveu nada num HOME cru\n'
fi

# ---------------------------------------------------------------------------
# Rodada 2 — HOME já instalado: nem um byte se move, e o manifesto é o mesmo
# ---------------------------------------------------------------------------
H2="$(mktemp -d)"
UNIDADES="$H2/.config/systemd/user"
ESTADO="$H2/.local/state/meowsystem"
mkdir -p "$UNIDADES" "$ESTADO"

# As unidades vão para o disco com o MESMO texto que o instalador gravaria — é
# isso que faz o `meow_escrever` concluir "já está certo" e o ramo `meow_seco`
# seguir para a pergunta seguinte, que é o pedaço que a rodada 1 não alcança.
# Os dois `@…@` são substituídos aqui pela mesma razão que o `install.sh` e o
# `vigia_assets.sh` os substituem lá: eles guardam um caminho que depende do
# HOME e do clone, e deixá-los crus faria o texto divergir por um motivo que
# não tem nada a ver com o que se está medindo.
for u in "$RAIZ"/systemd/*; do
  nome="$(basename "$u")"
  sed -e "s|@ATIVOS@|$H2/.local/share/backgrounds/meowsystem/ativos|g" \
      -e "s|@ACERVO@|$RAIZ/assets/gatos|g" "$u" > "$UNIDADES/$nome"
  chmod 644 "$UNIDADES/$nome"
done

# O manifesto com uma linha plausível: caminho, carimbo de tempo e sha256, que é
# a forma que a `meow_manifesto_registrar` escreve. O conteúdo não importa — o
# que importa é ele EXISTIR, porque um arquivo ausente não pode ser conferido e
# a conferência passaria por vácuo.
MANIFESTO="$ESTADO/manifesto.tsv"
printf '%s\t%s\t%s\n' "$H2/.config/meow/meow.conf" "2026-09-22T00:00:00-03:00" \
  "0000000000000000000000000000000000000000000000000000000000000000" > "$MANIFESTO"

antes_manifesto="$(sha256sum "$MANIFESTO" | cut -d' ' -f1)"
antes="$(_retrato "$H2")"
_rodar_seco "$H2"
depois="$(_retrato "$H2")"
depois_manifesto="$(sha256sum "$MANIFESTO" 2>/dev/null | cut -d' ' -f1)"

# A frase da sprint, conferida pelo nome antes do retrato geral: quem vier ler
# este teste procurando por ela tem de achá-la escrita, e não deduzi-la de uma
# comparação de listas.
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

exit "$([ "$falhas" = 0 ] && echo 0 || echo 1)"

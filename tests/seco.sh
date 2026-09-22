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

_rodar_seco() {   # $1 = o HOME de brinquedo · $2 = onde despejar a saída (opcional)
  env -i PATH="${MEOW_TESTE_PATH:-$PATH}" HOME="$1" USER="${USER:-t}" \
    MEOW_DRY_RUN=1 MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 \
    bash "$RAIZ/install.sh" > "${2:-/dev/null}" 2>&1
}

# As unidades do repositório no disco do HOME de brinquedo, com os dois `@…@`
# resolvidos — é isso que faz o `meow_escrever` concluir "já está certo" e o ramo
# `meow_seco` seguir para a pergunta seguinte. Usada pelas rodadas 2 e 3.
_plantar_unidades() {   # $1 = o HOME de brinquedo
  local u nome destino="$1/.config/systemd/user"
  mkdir -p "$destino"
  for u in "$RAIZ"/systemd/*; do
    nome="$(basename "$u")"
    sed -e "s|@ATIVOS@|$1/.local/share/backgrounds/meowsystem/ativos|g" \
        -e "s|@ACERVO@|$RAIZ/assets/gatos|g" "$u" > "$destino/$nome"
    chmod 644 "$destino/$nome"
  done
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
# Os dois `@…@` são substituídos pela mesma razão que o `install.sh` e o
# `vigia_assets.sh` os substituem lá: eles guardam um caminho que depende do
# HOME e do clone, e deixá-los crus faria o texto divergir por um motivo que
# não tem nada a ver com o que se está medindo.
_plantar_unidades "$H2"

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

# ---------------------------------------------------------------------------
# Rodada 3 — o seco não pode CALAR sobre a unidade que o real vai armar
# ---------------------------------------------------------------------------
# ENSAIO QUE OMITE É ENSAIO QUE MENTE, e as duas rodadas acima não o pegam: elas
# vigiam byte escrito, e aqui ninguém escreve — o ramo `meow_seco` simplesmente
# voltava calado. Era a dívida 6 do `docs/SPRINTS.md`, aberta em 31/08 como
# "HIPÓTESE, não medida", e medida em 22/09/2026 com exatamente este arranjo:
# com as unidades JÁ idênticas no disco (`mudou=0`), o `_logo_relogio` e o
# `etapa_wallpaper` devolviam 0 sem perguntar `is-enabled`/`is-active`, e a
# passagem real logo em seguida armava `meow-gato.timer`,
# `meow-wallpaper.timer`, `meow-fundo.path` e `meow-ativos.path`. Ela aprovava
# um ensaio que não falava das quatro.
#
# O `systemctl` É DE MENTIRA, E É ELE QUE TORNA ESTE TESTE POSSÍVEL
#   Sem ele a resposta dependeria da máquina de quem roda: numa que já tenha as
#   unidades armadas não haveria frase nenhuma para procurar, e o teste ficaria
#   verde por acaso. O stub responde `disabled`/`inactive` sempre — e GRITA se
#   alguém tentar `enable`, `start` ou `disable`, que é a rede contra um conserto
#   que "ensine" o seco a armar de verdade para poder anunciar. Nada aqui toca o
#   systemd de quem roda o teste.
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

# As quatro unidades que as duas etapas cegas armavam sem avisar. A frase é
# procurada pelo NOME DA UNIDADE, e não pelo texto humano em volta: o texto pode
# ser reescrito amanhã sem que a promessa mude, e o nome não.
faltou3=""
for u in meow-gato.timer meow-wallpaper.timer meow-fundo.path meow-ativos.path; do
  grep -q "$u" "$SAIDA3" || faltou3="$faltou3 $u"
done
if [ -n "$faltou3" ]; then
  printf 'FALHOU: o ensaio calou sobre unidade(s) que a execução real vai armar:%s\n' \
    "$faltou3" >&2
  printf '  é a dívida 6 do docs/SPRINTS.md voltando: ver o ramo `meow_seco` das etapas.\n' >&2
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

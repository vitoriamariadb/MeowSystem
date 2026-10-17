#!/usr/bin/env bash
# O seco não escreve NADA fora do próprio lock.
#
# JÁ FALHOU UMA VEZ, E EM SILÊNCIO: a fase de DETECÇÃO chamava `code
# --list-extensions` e `flatpak info`, e cada um deixava rastro no HOME — oito
# arquivos, medidos num HOME criado do zero.
#
# `MEOW_IGNORA_DESKTOP=1` porque o pré-voo recusa máquina sem COSMIC, e este
# teste tem de rodar em qualquer lugar — inclusive num CI sem sessão gráfica.
#
#     sha256sum ~/.local/state/meowsystem/manifesto.tsv > /tmp/antes
#     MEOW_DRY_RUN=1 ./install.sh …
#     sha256sum -c /tmp/antes    # espera: OK
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falhas=0

# O lock é a única escrita legítima do seco: ele é tomado ANTES de a primeira
# etapa rodar, e é o que impede duas execuções simultâneas — inclusive duas
# execuções em ensaio, que leriam a mesma máquina e disputariam o mesmo
# terminal.
LOCK='./.local/state/meowsystem/lock'

_rodar_seco() {   # $1 = o HOME de brinquedo · $2 = onde despejar a saída (opcional)
  env -i PATH="${MEOW_TESTE_PATH:-$PATH}" HOME="$1" USER="${USER:-t}" \
    MEOW_DRY_RUN=1 MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 \
    bash "$RAIZ/install.sh" > "${2:-/dev/null}" 2>&1
}

# As unidades do repositório no disco do HOME de brinquedo, com os dois `@…@`
# resolvidos — é isso que faz o `meow_escrever` concluir "já está certo" e o ramo
# `meow_seco` seguir para a pergunta seguinte. Usada pelas rodadas 2 e 3.
_v_do_pacote() {
  local n; n="$(ls -1 "/usr/share/cosmic/$1" 2>/dev/null | sed -n 's/^v\([0-9][0-9]*\)$/\1/p' | sort -n | tail -1)"
  printf 'v%s' "${n:-1}"
}
_plantar_unidades() {   # $1 = o HOME de brinquedo
  local u nome destino="$1/.config/systemd/user"
  mkdir -p "$destino"
  for u in "$RAIZ"/systemd/*; do
    nome="$(basename "$u")"
    # O `@V_PANEL@`/`@V_DOCK@` é o esquema que o pacote traz, como o
    # `meow_cosmic_v` do lib/comum.sh o lê: o maior `v<n>`, ou `v1`.
    sed -e "s|@ATIVOS@|$1/.local/share/backgrounds/meowsystem/ativos|g" \
        -e "s|@ACERVO@|$RAIZ/assets/gatos|g" \
        -e "s|@V_PANEL@|$(_v_do_pacote com.system76.CosmicPanel.Panel)|g" \
        -e "s|@V_DOCK@|$(_v_do_pacote com.system76.CosmicPanel.Dock)|g" "$u" > "$destino/$nome"
    chmod 644 "$destino/$nome"
  done
}

# O retrato é CAMINHO + sha256 de cada arquivo, e não só a lista de nomes: um
# seco que reescrevesse um arquivo com outro conteúdo não mudaria nome nenhum,
# e uma comparação de listas diria que está tudo bem.
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
_plantar_unidades "$H2"

# O manifesto com uma linha plausível: caminho, carimbo de tempo e sha256, que é
# a forma que a `meow_manifesto_registrar` escreve.
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

# Rodada 3 — o seco não pode CALAR sobre a unidade que o real vai armar
#
# ENSAIO QUE OMITE É ENSAIO QUE MENTE, e as duas rodadas acima não o pegam: elas
# vigiam byte escrito, e aqui ninguém escreve — o ramo `meow_seco` simplesmente
# voltava calado.
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

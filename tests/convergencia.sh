#!/usr/bin/env bash
# A promessa do README: a instalação CONVERGE — chega uma passagem em que nada
# mais é escrito. E o parágrafo 4 diz quantas: numa máquina nova são TRÊS, não
# duas, porque o `index.theme` descreve os diretórios que já EXISTEM e as pastas
# coloridas nascem na etapa seguinte.
#
# O QUE ESTE TESTE PEGA
#   Etapa que devolve 0 depois de escrever. `etapa_conf` e `etapa_modo` faziam
#   isso (10/08/2026): o resumo as listava em `confere:` na mesma rodada em que
#   elas imprimiram `~~` na tela, e a única prova do contrário era contar linhas.
#   Uma etapa não-idempotente aparece aqui como `mexeu:` que nunca some.
#
# POR QUE ELE OLHA `mexeu:` E NÃO A FRASE FINAL
#   Medido: num HOME de brinquedo sem barramento de sessão, `systemctl --user`
#   falha, o instalador sai 2 e a frase "nenhuma etapa precisou escrever nada"
#   nem chega a ser impressa. Isso é o ambiente, não o defeito que caçamos. O
#   `mexeu:` some do mesmo jeito, e é o que importa.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT

PASSAGENS="${PASSAGENS:-3}"

correr() {
  env -i PATH="$PATH" HOME="$H" USER="${USER:-t}" \
    MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 \
    bash "$RAIZ/install.sh" 2>&1
}

saida=""
for i in $(seq 1 "$PASSAGENS"); do
  saida="$(correr)"
  printf 'passagem %s: %s\n' "$i" \
    "$(printf '%s' "$saida" | grep 'mexeu:' || printf 'nada mudou')"
done

if printf '%s' "$saida" | grep -q 'mexeu:'; then
  printf 'FALHOU: ainda mexia na passagem %s — alguma etapa não é idempotente\n' \
    "$PASSAGENS" >&2
  exit 1
fi
printf 'ok: convergiu em %s passagens\n' "$PASSAGENS"

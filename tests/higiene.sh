#!/usr/bin/env bash
# higiene.sh — o gancho do repositório num clone de brinquedo: o comentário de
# registro sai, o número errado volta ao certo, a frase velha barra o commit.
#
# O clone é --shared num diretório temporário, com HOME próprio e sem a
# configuração global do git: o gancho global de quem roda não entra.
# 0 = passou · 1 = falhou · 3 = falta dependência.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas + 1)); }

for c in git python3; do
  command -v "$c" >/dev/null 2>&1 || { printf 'pulado: sem %s\n' "$c"; exit 3; }
done

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/casa"
export HOME="$T/casa" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

R="$T/repo"
git clone -q --shared --no-checkout "$RAIZ" "$R" 2>/dev/null
git -C "$R" checkout -q "$(git -C "$RAIZ" rev-parse HEAD)" 2>/dev/null
# O que está sendo testado vem da árvore de trabalho, e não só do último commit.
COPIA=(scripts/higiene.sh scripts/comentarios.py tests/numeros.sh tests/frases-velhas.sh
       tests/portabilidade.sh tests/higiene.sh README.md README.en.md)
for f in "${COPIA[@]}"; do cp "$RAIZ/$f" "$R/$f"; done
g() { git -C "$R" -c user.name=teste -c user.email=teste@exemplo.invalid "$@"; }
g add -- "${COPIA[@]}" >/dev/null
g commit -qm base >/dev/null 2>&1
# Sem configuração global, o clone usa o próprio .git/hooks: o gancho entra depois da base.
printf '#!/bin/sh\nexec bash scripts/higiene.sh\n' > "$R/.git/hooks/pre-commit"
chmod +x "$R/.git/hooks/pre-commit"
com_gancho() { g commit -qm "$1" >"$T/saida" 2>&1; }

# 1. o comentário de registro sai e o porquê fica
cat > "$R/scripts/brinquedo.sh" <<'SH'
#!/usr/bin/env bash
# P99 — 15/10/2026: o laço para no primeiro erro porque o resto depende dele.
for x in a b; do printf '%s\n' "$x" || break; done
SH
g add scripts/brinquedo.sh
if com_gancho "brinquedo"; then
  linha="$(g show HEAD:scripts/brinquedo.sh | sed -n 2p)"
  [ "$linha" = "# o laço para no primeiro erro porque o resto depende dele." ] \
    && ok "o comentário perdeu o id e a data e ficou com o porquê" \
    || falha "o comentário saiu assim: $linha"
  g show HEAD:scripts/brinquedo.sh | grep -q "for x in a b" \
    && ok "o código do arquivo entrou inteiro" || falha "o código mudou no commit"
else
  falha "o commit do comentário foi barrado"
fi

# 2. o número errado no README volta ao que o código conta
certo="$(grep -oE 'São [0-9]+ etapas' "$R/README.md" | head -n1)"
sed -i 's/São [0-9]\+ etapas/São 999 etapas/' "$R/README.md"
g add README.md
if com_gancho "número"; then
  depois="$(g show HEAD:README.md | grep -oE 'São [0-9]+ etapas' | head -n1)"
  [ "$depois" = "$certo" ] && ok "o README voltou a «$certo» no commit" \
    || falha "o README entrou com «$depois»; o certo é «$certo»"
else
  falha "o commit com número errado foi barrado em vez de corrigido"
fi

# 3. a frase velha barra o commit
antes="$(g rev-parse HEAD)"
# a frase montada em pedaços, para este arquivo não ser ele mesmo uma frase velha
printf '\nUse o botão %s ao ícone de fábrica.\n' Voltar >> "$R/README.md"
g add README.md
if com_gancho "frase velha"; then
  falha "o commit com frase velha passou"
else
  [ "$(g rev-parse HEAD)" = "$antes" ] && ok "a frase velha barrou o commit" \
    || falha "o commit mudou o HEAD mesmo barrado"
fi

[ "$falhas" -eq 0 ] || { cat "$T/saida" >&2; exit 1; }
exit 0

#!/usr/bin/env bash
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
git clone -q --shared --no-checkout --template= "$RAIZ" "$R" 2>/dev/null
git -C "$R" checkout -q "$(git -C "$RAIZ" rev-parse HEAD)" 2>/dev/null
COPIA=(scripts/higiene.sh scripts/comentarios.py tests/numeros.sh tests/frases-velhas.sh
       tests/portabilidade.sh tests/higiene.sh README.md README.en.md)
for f in "${COPIA[@]}"; do cp "$RAIZ/$f" "$R/$f"; done
g() { git -C "$R" -c user.name=teste -c user.email=teste@exemplo.invalid "$@"; }
g add -- "${COPIA[@]}" >/dev/null
g commit -qm base >/dev/null 2>&1
mkdir -p "$R/.git/hooks"
printf '#!/bin/sh\nexec bash scripts/higiene.sh\n' > "$R/.git/hooks/pre-commit"
chmod +x "$R/.git/hooks/pre-commit"
com_gancho() { g commit -qm "$1" >"$T/saida" 2>&1; }

cat > "$R/scripts/brinquedo.sh" <<'SH'
#!/usr/bin/env bash
# o laço para no primeiro erro porque o resto depende dele

x="a#b"; n="${#x}"   # o tamanho
for y in a b; do printf '%s %s\n' "$y" "$n" || break; done
SH
cat > "$R/scripts/brinquedo.py" <<'PY'
#!/usr/bin/env python3
"""brinquedo.py A: a ajuda que o --help mostra."""
import sys


def f():
    """some no commit"""
    return "# fica"  # sai


print(__doc__ if sys.argv[1:] else f())
PY
impressoes() { python3 "$R/scripts/comentarios.py" impressao "$R/scripts/brinquedo.sh" "$R/scripts/brinquedo.py" | cut -d' ' -f1; }
antes_imp="$(impressoes)"
g add scripts/brinquedo.sh scripts/brinquedo.py
if com_gancho "brinquedo"; then
  esperado_sh='#!/usr/bin/env bash

x="a#b"; n="${#x}"
for y in a b; do printf '"'"'%s %s\n'"'"' "$y" "$n" || break; done'
  [ "$(g show HEAD:scripts/brinquedo.sh)" = "$esperado_sh" ] \
    && ok "o .sh entrou sem comentário, com o # da string e o \${#x} intactos" \
    || falha "o .sh entrou assim: $(g show HEAD:scripts/brinquedo.sh)"
  g show HEAD:scripts/brinquedo.py | grep -q '"""brinquedo.py A' \
    && ok "a docstring que o __doc__ lê ficou" || falha "a docstring usada saiu"
  ! g show HEAD:scripts/brinquedo.py | grep -qE 'some no commit|# sai' \
    && g show HEAD:scripts/brinquedo.py | grep -q 'return "# fica"' \
    && ok "o comentário e a docstring morta saíram; a string com # ficou" \
    || falha "o .py entrou assim: $(g show HEAD:scripts/brinquedo.py)"
  [ "$(impressoes)" = "$antes_imp" ] && ok "a impressão dos dois é a mesma de antes do commit" \
    || falha "a impressão mudou no commit"
  git -C "$R" diff --quiet && ok "a árvore de trabalho ficou igual ao commit" \
    || falha "sobrou diferença fora do índice"
else
  falha "o commit do comentário foi barrado"
fi

printf '#!/usr/bin/env bash\n# antigo\necho a\n' > "$R/scripts/velho.sh"
g add scripts/velho.sh
g commit -qm velho --no-verify >/dev/null 2>&1
printf 'echo b  # novo\n' >> "$R/scripts/velho.sh"
g add scripts/velho.sh
if com_gancho "linha nova"; then
  [ "$(g show HEAD:scripts/velho.sh)" = "$(printf '#!/usr/bin/env bash\n# antigo\necho a\necho b')" ] \
    && ok "só a linha nova perdeu o comentário" \
    || falha "o velho.sh entrou assim: $(g show HEAD:scripts/velho.sh)"
else
  falha "o commit da linha nova foi barrado"
fi

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

antes="$(g rev-parse HEAD)"
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

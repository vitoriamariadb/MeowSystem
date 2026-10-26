#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v git >/dev/null 2>&1 || { printf 'pulado: sem git\n'; exit 0; }
while IFS= read -r v; do unset "$v"; done < <(compgen -e | grep '^GIT_')
unset MEOWSYSTEM_GANCHO_RODANDO MEOW_SEM_README

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
LOG="$T/chamadas.log"
: > "$LOG"
g() { git -c user.name=teste -c user.email=teste@exemplo.invalid -c init.defaultBranch=dev "$@"; }

for n in pre-push post-merge; do
  [ -x "$RAIZ/scripts/gancho-$n.sh" ] && ok "scripts/gancho-$n.sh existe e é executável" \
    || falha "scripts/gancho-$n.sh falta ou não é executável"
done

GLOBAL="$T/global"
mkdir -p "$GLOBAL"
cat > "$GLOBAL/pre-commit" <<EOF
#!/usr/bin/env bash
printf 'global-pre-commit\n' >> "$LOG"
LOCAL_HOOK="\$(git rev-parse --path-format=absolute --git-common-dir)/hooks/pre-commit"
if [ -x "\$LOCAL_HOOK" ] && ! cmp -s "\$LOCAL_HOOK" "\$0"; then
  "\$LOCAL_HOOK" "\$@" || exit 1
fi
exit 0
EOF
cat > "$GLOBAL/pre-push" <<EOF
#!/usr/bin/env bash
ENTRADA="\$(cat)"
printf 'global-pre-push %s\n' "\$ENTRADA" >> "$LOG"
X="\$(git config --get ganchos.pre-push)"
if [ -n "\$X" ]; then
  TOPO="\$(git rev-parse --show-toplevel)"
  [ -f "\$TOPO/\$X" ] || exit 1
  printf '%s\n' "\$ENTRADA" | "\$TOPO/\$X" "\$@" || exit 1
fi
exit 0
EOF
cat > "$GLOBAL/post-merge" <<EOF
#!/usr/bin/env bash
X="\$(git config --get ganchos.post-merge)"
[ -n "\$X" ] || exit 0
TOPO="\$(git rev-parse --show-toplevel)"
[ -f "\$TOPO/\$X" ] || exit 0
"\$TOPO/\$X" "\$@"
EOF
chmod 755 "$GLOBAL"/*

R="$T/repo"
g init -q "$R"
g -C "$R" config core.hooksPath "$GLOBAL"
mkdir -p "$R/scripts"
cp "$RAIZ/scripts/ganchos.sh" "$RAIZ/scripts/gancho-pre-push.sh" "$RAIZ/scripts/gancho-post-merge.sh" "$R/scripts/"
printf '#!/usr/bin/env bash\nprintf "higiene\\n" >> "%s"\n' "$LOG" > "$R/scripts/higiene.sh"
cat > "$R/scripts/readme.sh" <<EOF
#!/usr/bin/env bash
printf 'readme %s\n' "\$*" >> "$LOG"
exit "\$(cat "$T/rc" 2>/dev/null || echo 0)"
EOF
printf 'x\n' > "$R/a"
g -C "$R" add -A
g -C "$R" commit -q -m base --no-verify

H="$(cd "$R/.git/hooks" && pwd -P)"
rm -f "$H"/*.sample
printf '#!/bin/sh\nprintf "pre-commit-antigo\\n" >> "%s"\n' "$LOG" > "$H/pre-commit"
printf '#!/bin/sh\necho alheio\n' > "$H/pre-push"
printf '#!/usr/bin/env bash\nMEOWSYSTEM_GANCHO=1\nexit 0\n' > "$H/post-merge"
chmod 755 "$H/pre-commit" "$H/pre-push" "$H/post-merge"
antigo_md5="$(md5sum < "$H/pre-commit")"
alheio_md5="$(md5sum < "$H/pre-push")"

saida="$(cd "$R" && bash scripts/ganchos.sh instalar 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "instalar sai 0" || falha "instalar saiu $rc" "$saida"
[ -x "$H/pre-commit" ] && grep -qxF MEOWSYSTEM_GANCHO=1 "$H/pre-commit" \
  && ok "pre-commit instalado na pasta comum" || falha "pre-commit não ficou instalado"
[ -x "$H/pre-commit.antes-meowsystem" ] && [ "$(md5sum < "$H/pre-commit.antes-meowsystem")" = "$antigo_md5" ] \
  && ok "o pre-commit de antes foi guardado intacto" || falha "o pre-commit de antes se perdeu"
[ "$(md5sum < "$H/pre-push")" = "$alheio_md5" ] && [ ! -e "$H/pre-push.antes-meowsystem" ] \
  && ok "o pre-push da pasta comum, que não é nosso, ficou intocado" || falha "instalar mexeu no pre-push da pasta comum"
[ ! -e "$H/post-merge" ] && ok "o post-merge antigo nosso saiu da pasta comum" \
  || falha "sobrou o post-merge nosso na pasta comum"
[ "$(g -C "$R" config --get ganchos.pre-push)" = scripts/gancho-pre-push.sh ] \
  && [ "$(g -C "$R" config --get ganchos.post-merge)" = scripts/gancho-post-merge.sh ] \
  && ok "as chaves ganchos.pre-push e ganchos.post-merge apontam para os scripts da árvore" \
  || falha "as chaves não ficaram certas" "$(g -C "$R" config --get-regexp '^ganchos\.')"

antes="$(md5sum "$H"/pre-commit; g -C "$R" config --get-regexp '^ganchos\.')"
saida="$(cd "$R" && bash scripts/ganchos.sh instalar 2>&1)"
depois="$(md5sum "$H"/pre-commit; g -C "$R" config --get-regexp '^ganchos\.')"
if [ "$antes" = "$depois" ] && [ "$(grep -c '^já estava' <<<"$saida")" -eq 3 ]; then
  ok "a segunda instalação não muda nada"
else
  falha "a segunda instalação mexeu nos ganchos" "$saida"
fi
saida="$(cd "$R" && bash scripts/ganchos.sh conferir 2>&1)" && [ "$(grep -c '^ok:' <<<"$saida")" -eq 3 ] \
  && ok "conferir dá 0 e mostra o pre-commit e as duas chaves" || falha "conferir não reconheceu os ganchos" "$saida"

: > "$LOG"
printf 'y\n' >> "$R/a"
g -C "$R" commit -q -am dois >/dev/null 2>&1
if [ "$(cat "$LOG")" = "$(printf 'global-pre-commit\npre-commit-antigo\nhigiene')" ]; then
  ok "no commit o global chama o da pasta comum: o antigo, depois a higiene, e o README não"
else
  falha "o pre-commit chamou outra coisa" "$(cat "$LOG")"
fi

g -C "$R" branch -q lado
g -C "$R" checkout -q -b outro
printf 'z\n' > "$R/b"; g -C "$R" add b; g -C "$R" commit -q -m tres --no-verify
g -C "$R" checkout -q lado
: > "$LOG"
g -C "$R" merge -q --no-edit outro >/dev/null 2>&1
grep -q '^readme' "$LOG" && falha "o post-merge regerou o README fora do dev" || ok "post-merge fora do dev não toca no README"
g -C "$R" checkout -q dev
: > "$LOG"
g -C "$R" merge -q --no-edit outro >/dev/null 2>&1
grep -qx 'readme --commit' "$LOG" && ok "post-merge no dev, pela chave, chama o readme.sh --commit" \
  || falha "o post-merge no dev não chamou o readme" "$(cat "$LOG")"
: > "$LOG"
g -C "$R" checkout -q -b mais
printf 'w\n' > "$R/c"; g -C "$R" add c; g -C "$R" commit -q -m quatro --no-verify
g -C "$R" checkout -q dev
MEOW_SEM_README=1 g -C "$R" merge -q --no-edit mais >/dev/null 2>&1
grep -q '^readme' "$LOG" && falha "MEOW_SEM_README=1 não calou o post-merge" || ok "MEOW_SEM_README=1 cala o post-merge"

g init -q --bare "$T/remoto.git"
g -C "$R" remote add origem "$T/remoto.git"
: > "$LOG"
printf '1\n' > "$T/rc"
if g -C "$R" push -q origem dev >/dev/null 2>&1; then
  falha "o push passou com o README regerado no gancho"
else
  ok "o push para quando o gancho regera o README"
fi
grep -q '^global-pre-push refs/heads/dev ' "$LOG" && grep -qx 'readme --commit' "$LOG" \
  && ok "o pre-push global recebe a entrada e chama o da árvore" || falha "o pre-push não encadeou" "$(cat "$LOG")"
printf '0\n' > "$T/rc"
g -C "$R" push -q origem dev >/dev/null 2>&1 && ok "o push passa com o README em dia" || falha "o push foi barrado com o README em dia"
[ "$(g -C "$T/remoto.git" rev-parse dev 2>/dev/null)" = "$(g -C "$R" rev-parse dev)" ] \
  && ok "o remoto recebeu o dev" || falha "o remoto não recebeu o dev"

g -C "$R" worktree add -q "$T/velha" -b velha >/dev/null 2>&1
rm -f "$T/velha/scripts/higiene.sh"
printf 'v\n' > "$T/velha/v"
g -C "$T/velha" add v
if g -C "$T/velha" commit -q -m velha >/dev/null 2>&1; then
  ok "worktree sem scripts/higiene.sh ainda faz commit"
else
  falha "o gancho travou uma worktree sem scripts/higiene.sh"
fi

saida="$(cd "$R" && bash scripts/ganchos.sh remover 2>&1)"
[ "$(md5sum < "$H/pre-commit")" = "$antigo_md5" ] && ok "remover devolve o pre-commit de antes" \
  || falha "remover não devolveu o pre-commit" "$saida"
[ -z "$(g -C "$R" config --get-regexp '^ganchos\.')" ] && ok "remover apaga as chaves" \
  || falha "as chaves ficaram" "$(g -C "$R" config --get-regexp '^ganchos\.')"
[ "$(md5sum < "$H/pre-push")" = "$alheio_md5" ] && ok "remover não toca no pre-push alheio" \
  || falha "remover mexeu no pre-push alheio"
[ ! -e "$H/pre-commit.antes-meowsystem" ] && ok "nada .antes-meowsystem sobrou" || falha "sobrou arquivo .antes-meowsystem"

cp "$GLOBAL/pre-commit" "$H/pre-commit"
(cd "$R" && bash scripts/ganchos.sh instalar >/dev/null 2>&1)
: > "$LOG"
printf 'u\n' >> "$R/a"
if timeout 20 git -C "$R" -c user.name=teste -c user.email=teste@exemplo.invalid commit -q -am cinco >/dev/null 2>&1; then
  [ "$(grep -c '^higiene$' "$LOG")" -eq 1 ] && ok "um gancho antigo igual ao global não faz laço; a higiene roda uma vez" \
    || falha "a higiene rodou outra quantidade de vezes" "$(cat "$LOG")"
else
  falha "o commit travou ou falhou com o gancho antigo igual ao global" "$(head -20 "$LOG")"
fi
(cd "$R" && bash scripts/ganchos.sh remover >/dev/null 2>&1)

printf 'qualquer\n' > "$H/pre-commit.antes-meowsystem"
printf '#!/bin/sh\n' > "$H/pre-commit"; chmod 755 "$H/pre-commit"
(cd "$R" && bash scripts/ganchos.sh instalar >/dev/null 2>&1); rc=$?
if [ "$rc" -ne 0 ] && [ "$(cat "$H/pre-commit")" = '#!/bin/sh' ]; then
  ok "instalar recusa quando o lugar do gancho antigo já está ocupado"
else
  falha "instalar sobrescreveu um gancho que não podia guardar"
fi

if [ "$falhas" -gt 0 ]; then
  printf '\n%d falha(s) nos ganchos.\n' "$falhas" >&2
  exit 1
fi
printf '\no pre-commit encadeia na pasta comum; pre-push e post-merge são chaves para a árvore, e só regeram o README no dev e no push.\n'

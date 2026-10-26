#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v git >/dev/null 2>&1 || { printf 'pulado: sem git\n'; exit 0; }
while IFS= read -r v; do unset "$v"; done < <(compgen -e | grep '^GIT_')

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
LOG="$T/chamadas.log"
: > "$LOG"
g() { git -c user.name=teste -c user.email=teste@exemplo.invalid -c init.defaultBranch=dev "$@"; }

R="$T/repo"
g init -q "$R"
mkdir -p "$R/scripts"
cp "$RAIZ/scripts/ganchos.sh" "$R/scripts/ganchos.sh"
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
printf '#!/bin/sh\nprintf "pre-push-antigo %%s\\n" "$(cat)" >> "%s"\n' "$LOG" > "$H/pre-push"
chmod 755 "$H/pre-commit" "$H/pre-push"
antigo_md5="$(md5sum < "$H/pre-commit")"

saida="$(cd "$R" && bash scripts/ganchos.sh instalar 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "instalar sai 0" || falha "instalar saiu $rc" "$saida"
for n in pre-commit post-merge pre-push; do
  [ -x "$H/$n" ] && grep -qxF MEOWSYSTEM_GANCHO=1 "$H/$n" \
    && ok "$n instalado na pasta comum" || falha "$n não ficou instalado"
done
[ -x "$H/pre-commit.antes-meowsystem" ] && [ "$(md5sum < "$H/pre-commit.antes-meowsystem")" = "$antigo_md5" ] \
  && ok "o pre-commit de antes foi guardado intacto" || falha "o pre-commit de antes se perdeu"
[ -x "$H/pre-push.antes-meowsystem" ] && ok "o pre-push de antes foi guardado" || falha "o pre-push de antes se perdeu"

antes="$(md5sum "$H"/pre-commit "$H"/post-merge "$H"/pre-push)"
saida="$(cd "$R" && bash scripts/ganchos.sh instalar 2>&1)"
depois="$(md5sum "$H"/pre-commit "$H"/post-merge "$H"/pre-push)"
if [ "$antes" = "$depois" ] && [ "$(grep -c '^já estava' <<<"$saida")" -eq 3 ]; then
  ok "a segunda instalação não muda nada"
else
  falha "a segunda instalação mexeu nos ganchos" "$saida"
fi
(cd "$R" && bash scripts/ganchos.sh conferir >/dev/null) && ok "conferir dá 0 com os ganchos no lugar" \
  || falha "conferir não reconheceu os ganchos"

: > "$LOG"
printf 'y\n' >> "$R/a"
g -C "$R" commit -q -am dois >/dev/null 2>&1
if [ "$(cat "$LOG")" = "$(printf 'pre-commit-antigo\nhigiene')" ]; then
  ok "no commit roda o gancho antigo e depois a higiene, e o README não"
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
grep -qx 'readme --commit' "$LOG" && ok "post-merge no dev chama o readme.sh --commit" \
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
grep -q '^pre-push-antigo refs/heads/dev ' "$LOG" && ok "o pre-push antigo recebe a entrada do git" \
  || falha "o pre-push antigo não recebeu a entrada" "$(cat "$LOG")"
printf '0\n' > "$T/rc"
g -C "$R" push -q origem dev >/dev/null 2>&1 && ok "o push passa com o README em dia" || falha "o push foi barrado com o README em dia"
[ "$(g -C "$T/remoto.git" rev-parse dev 2>/dev/null)" = "$(g -C "$R" rev-parse dev)" ] \
  && ok "o remoto recebeu o dev" || falha "o remoto não recebeu o dev"

g -C "$R" worktree add -q "$T/velha" -b velha >/dev/null 2>&1
rm -f "$T/velha/scripts/ganchos.sh"
printf 'v\n' > "$T/velha/v"
g -C "$T/velha" add v
if g -C "$T/velha" commit -q -m velha >/dev/null 2>&1; then
  ok "worktree sem scripts/ganchos.sh ainda faz commit"
else
  falha "o gancho travou uma worktree sem scripts/ganchos.sh"
fi

saida="$(cd "$R" && bash scripts/ganchos.sh remover 2>&1)"
[ "$(md5sum < "$H/pre-commit")" = "$antigo_md5" ] && ok "remover devolve o pre-commit de antes" \
  || falha "remover não devolveu o pre-commit" "$saida"
[ ! -e "$H/post-merge" ] && ok "remover tira o post-merge, que era só nosso" || falha "o post-merge ficou"
[ ! -e "$H/pre-commit.antes-meowsystem" ] && [ ! -e "$H/pre-push.antes-meowsystem" ] \
  && ok "nada .antes-meowsystem sobrou" || falha "sobrou arquivo .antes-meowsystem"

printf 'qualquer\n' > "$H/post-merge.antes-meowsystem"
printf '#!/bin/sh\n' > "$H/post-merge"; chmod 755 "$H/post-merge"
(cd "$R" && bash scripts/ganchos.sh instalar >/dev/null 2>&1); rc=$?
if [ "$rc" -ne 0 ] && [ "$(cat "$H/post-merge")" = '#!/bin/sh' ]; then
  ok "instalar recusa quando o lugar do gancho antigo já está ocupado"
else
  falha "instalar sobrescreveu um gancho que não podia guardar"
fi

if [ "$falhas" -gt 0 ]; then
  printf '\n%d falha(s) nos ganchos.\n' "$falhas" >&2
  exit 1
fi
printf '\nos ganchos encadeiam, não apagam, e só regeram o README no dev e no push.\n'

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
g() { git -c user.name=teste -c user.email=teste@exemplo.invalid -c init.defaultBranch=master "$@"; }

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

mkdir -p "$T/bin"
cat > "$T/bin/gpg" <<FIM
#!/bin/sh
case " \$* " in
  *" --verify "*) cat > /dev/null
     printf '[GNUPG:] NEWSIG\n[GNUPG:] GOODSIG 0123456789ABCDEF falso\n[GNUPG:] VALIDSIG 0123456789ABCDEF0123456789ABCDEF01234567 2026-11-19 1795000000 0 4 0 22 10 00 0123456789ABCDEF0123456789ABCDEF01234567\n[GNUPG:] TRUST_ULTIMATE 0 pgp\n' ;;
  *) cat > /dev/null
     printf -- '-----BEGIN PGP SIGNATURE-----\n\nZmFsc28=\n-----END PGP SIGNATURE-----\n'
     printf '[GNUPG:] BEGIN_SIGNING H10\n[GNUPG:] SIG_CREATED D 22 10 00 1795000000 0123456789ABCDEF0123456789ABCDEF01234567\n' >&2 ;;
esac
FIM
chmod 755 "$T/bin/gpg"

R="$T/repo"
g init -q "$R"
g -C "$R" config gpg.program "$T/bin/gpg"
g -C "$R" config user.signingkey falso
g -C "$R" config core.hooksPath "$GLOBAL"
mkdir -p "$R/scripts"
cp "$RAIZ/scripts/ganchos.sh" "$RAIZ/scripts/gancho-pre-push.sh" "$RAIZ/scripts/gancho-post-merge.sh" "$R/scripts/"
printf '#!/usr/bin/env bash\nprintf "higiene\\n" >> "%s"\n' "$LOG" > "$R/scripts/higiene.sh"
cat > "$R/scripts/readme.sh" <<EOF
#!/usr/bin/env bash
printf 'readme %s\n' "\$*" >> "$LOG"
if [ -f "$T/captura" ] && [ "\$*" = "--commit" ]; then
  date +%s%N > captura.png && git add captura.png \
    && git -c user.name=teste -c user.email=teste@exemplo.invalid commit -q -m "docs(readme): regerado do código" && exit 1
fi
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
grep -q '^readme' "$LOG" && falha "o post-merge regerou o README fora do master" || ok "post-merge fora do master não toca no README"
g -C "$R" checkout -q master
: > "$LOG"
g -C "$R" merge -q --no-edit outro >/dev/null 2>&1
grep -qx 'readme --commit' "$LOG" && ok "post-merge no master, pela chave, chama o readme.sh --commit" \
  || falha "o post-merge no master não chamou o readme" "$(cat "$LOG")"
: > "$LOG"
g -C "$R" checkout -q -b mais
printf 'w\n' > "$R/c"; g -C "$R" add c; g -C "$R" commit -q -m quatro --no-verify
g -C "$R" checkout -q master
MEOW_SEM_README=1 g -C "$R" merge -q --no-edit mais >/dev/null 2>&1
grep -q '^readme' "$LOG" && falha "MEOW_SEM_README=1 não calou o post-merge" || ok "MEOW_SEM_README=1 cala o post-merge"

g init -q --bare "$T/remoto.git"
g -C "$R" remote add origem "$T/remoto.git"
g -C "$R" commit -q --amend -S --no-edit --no-verify >/dev/null 2>&1
: > "$LOG"
printf '1\n' > "$T/rc"
if g -C "$R" push -q origem master >/dev/null 2>&1; then
  falha "o push passou com o README regerado no gancho"
else
  ok "o push para quando o gancho regera o README"
fi
grep -q '^global-pre-push refs/heads/master ' "$LOG" && grep -qx 'readme --commit' "$LOG" \
  && ok "o pre-push global recebe a entrada e chama o da árvore" || falha "o pre-push não encadeou" "$(cat "$LOG")"
printf '0\n' > "$T/rc"
g -C "$R" push -q origem master >/dev/null 2>&1 && ok "o push passa com o README em dia" || falha "o push foi barrado com o README em dia"
[ "$(g -C "$T/remoto.git" rev-parse master 2>/dev/null)" = "$(g -C "$R" rev-parse master)" ] \
  && ok "o remoto recebeu o master" || falha "o remoto não recebeu o master"

printf 'n\n' > "$R/n"; g -C "$R" add n; g -C "$R" commit -q -m sem-assinatura --no-verify >/dev/null 2>&1
: > "$LOG"
saida="$(g -C "$R" push origem master 2>&1)" && falha "o push de ponta sem assinatura para o master passou" \
  || { grep -q 'assinatura' <<<"$saida" && ok "o push de ponta sem assinatura para o master é recusado, dizendo o que falta" \
    || falha "a recusa não disse que falta assinatura" "$saida"; }
[ "$(g -C "$T/remoto.git" rev-parse master)" != "$(g -C "$R" rev-parse master)" ] \
  && ok "o remoto não recebeu a ponta sem assinatura" || falha "o remoto recebeu a ponta sem assinatura"
g -C "$R" push -q origem master:lateral >/dev/null 2>&1 && ok "a ponta sem assinatura passa por outra branch" \
  || falha "outra branch foi barrada pela assinatura"
g -C "$R" push -q origem master:refs/heads/mestre >/dev/null 2>&1 && ok "o nome mestre não é o master" \
  || falha "o nome mestre foi barrado"
g -C "$R" push -q origem :lateral >/dev/null 2>&1 && ok "apagar uma branch não pede assinatura" || falha "apagar branch foi barrado"
g -C "$R" commit -q --amend -S --no-edit --no-verify >/dev/null 2>&1
g -C "$R" push -q origem master >/dev/null 2>&1 && ok "o push de ponta assinada para o master passa" \
  || falha "o push de ponta assinada foi barrado"
if command -v ssh-keygen >/dev/null 2>&1; then
  mkdir -p "$T/casa/.config/meow"
  ssh-keygen -q -t ed25519 -N '' -C casa -f "$T/chave-casa" && ssh-keygen -q -t ed25519 -N '' -C estranha -f "$T/chave-estranha"
  printf 'casa namespaces="git" %s\n' "$(cut -d' ' -f1,2 "$T/chave-casa.pub")" > "$T/casa/.config/meow/assinantes"
  printf 'p\n' > "$R/p"; g -C "$R" add p
  g -C "$R" -c gpg.format=ssh -c user.signingkey="$T/chave-estranha" commit -q -S -m ssh-estranha --no-verify >/dev/null 2>&1
  HOME="$T/casa" g -C "$R" -c gpg.format=ssh push -q origem master >/dev/null 2>&1 \
    && falha "o push passou com ponta assinada por chave fora da lista dos assinantes" \
    || ok "ponta SSH de chave fora da lista dos assinantes é recusada"
  g -C "$R" -c gpg.format=ssh -c user.signingkey="$T/chave-casa" commit -q --amend -S --no-edit --no-verify >/dev/null 2>&1
  HOME="$T/casa" g -C "$R" -c gpg.format=ssh push -q origem master >/dev/null 2>&1 \
    && ok "ponta SSH de chave da lista dos assinantes passa, sem allowedSignersFile no git" \
    || falha "ponta SSH de chave da lista dos assinantes foi barrada"
else
  falha "o teste da assinatura SSH precisa do ssh-keygen"
fi
g -C "$R" config gpg.program "$T/nao-existe"
printf 'm\n' > "$R/m"; g -C "$R" add m; g -C "$R" commit -q -m assina-quebrada --no-verify >/dev/null 2>&1
g -C "$R" push -q origem master >/dev/null 2>&1 && falha "o push passou com o gpg quebrado" || ok "sem gpg que verifique, o push para o master é recusado"
g -C "$R" config gpg.program "$T/bin/gpg"
g -C "$R" commit -q --amend -S --no-edit --no-verify >/dev/null 2>&1
g -C "$R" push -q origem master >/dev/null 2>&1 || falha "o push com o gpg de volta foi barrado"

g clone -q "$T/remoto.git" "$T/segue" >/dev/null 2>&1
g -C "$T/segue" config core.hooksPath "$GLOBAL"
(cd "$T/segue" && bash scripts/ganchos.sh instalar >/dev/null 2>&1)
printf 's\n' > "$R/s"; g -C "$R" add s; g -C "$R" commit -q -S -m seis >/dev/null 2>&1
g -C "$R" push -q origem master >/dev/null 2>&1
: > "$LOG"; : > "$T/captura"
g -C "$T/segue" pull -q --ff-only >/dev/null 2>&1
[ "$(g -C "$T/segue" rev-parse HEAD)" = "$(g -C "$T/segue" rev-parse origin/master)" ] && ! grep -q '^readme' "$LOG" \
  && ok "o pull que só alcança o tronco não regera o README nem deixa commit de captura (P250)" \
  || falha "o pull que só alcança o tronco deixou o master à frente do origin/master" "$(cat "$LOG"; g -C "$T/segue" log --oneline -3)"
g -C "$T/segue" checkout -q -b junta
printf 'j\n' > "$T/segue/j"; g -C "$T/segue" add j; g -C "$T/segue" commit -q -m junta >/dev/null 2>&1
g -C "$T/segue" checkout -q master
: > "$LOG"
g -C "$T/segue" merge -q --no-ff --no-edit junta >/dev/null 2>&1
grep -qx 'readme --commit' "$LOG" && ok "o merge que traz trabalho ao master, na árvore de integração, regera o README" \
  || falha "o merge de integração no master não chamou o readme" "$(cat "$LOG")"
rm -f "$T/captura"

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

R2="$T/clone-do-meow"
g init -q "$R2"
mkdir -p "$R2/scripts"
cp -R "$RAIZ/scripts/lib" "$R2/scripts/lib"
cp "$RAIZ/scripts/meow" "$RAIZ/scripts/ganchos.sh" "$RAIZ/scripts/gancho-pre-push.sh" "$RAIZ/scripts/gancho-post-merge.sh" "$R2/scripts/"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R2/install.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R2/scripts/higiene.sh"
chmod 755 "$R2/scripts/meow" "$R2/install.sh"
g -C "$R2" add -A
g -C "$R2" commit -q -m base --no-verify
H2="$(cd "$R2/.git/hooks" && pwd -P)"
CASA2="$T/casa2"
mkdir -p "$CASA2"
meow() { (cd "$T" && HOME="$CASA2" MEOW_RAIZ="$R2" bash "$R2/scripts/meow" "$@" 2>&1); }

saida="$(meow ganchos instalar)"; rc=$?
[ "$rc" -eq 0 ] && [ -x "$H2/pre-commit" ] \
  && [ "$(g -C "$R2" config --get ganchos.pre-push)" = scripts/gancho-pre-push.sh ] \
  && ok "meow ganchos instalar instala no clone do meow, estando em outra pasta" \
  || falha "meow ganchos instalar não instalou" "$saida"
antes="$(md5sum "$H2"/pre-commit; g -C "$R2" config --get-regexp '^ganchos\.')"
saida="$(meow ganchos instalar)"; rc=$?
depois="$(md5sum "$H2"/pre-commit; g -C "$R2" config --get-regexp '^ganchos\.')"
[ "$rc" -eq 0 ] && [ "$antes" = "$depois" ] && [ "$(grep -c '^já estava' <<<"$saida")" -eq 3 ] \
  && ok "meow ganchos instalar, de novo, não muda nada" || falha "a segunda instalação pelo meow mexeu" "$saida"
saida="$(meow ganchos conferir)"; rc=$?
[ "$rc" -eq 0 ] && [ "$(grep -c '^ok:' <<<"$saida")" -eq 3 ] \
  && ok "meow ganchos conferir dá 0 com os três em dia" || falha "meow ganchos conferir não reconheceu" "$saida"
saida="$(meow ganchos)"; rc=$?
[ "$rc" -eq 0 ] && [ "$(grep -c '^ok:' <<<"$saida")" -eq 3 ] \
  && ok "meow ganchos sem verbo é o conferir" || falha "meow ganchos sem verbo não conferiu" "$saida"
saida="$(meow ganchos remover)"; rc=$?
[ "$rc" -eq 0 ] && [ ! -e "$H2/pre-commit" ] && [ -z "$(g -C "$R2" config --get-regexp '^ganchos\.')" ] \
  && ok "meow ganchos remover tira o pre-commit e as chaves" || falha "meow ganchos remover não removeu" "$saida"
saida="$(meow ganchos conferir)"; rc=$?
[ "$rc" -eq 1 ] && grep -q '^falta: pre-commit' <<<"$saida" \
  && ok "meow ganchos conferir sem gancho sai 1 e diz o que falta" || falha "conferir sem gancho não saiu 1" "$saida"
saida="$(meow ganchos inventado)"; rc=$?
[ "$rc" -eq 2 ] && grep -q 'verbo desconhecido' <<<"$saida" \
  && ok "meow ganchos com verbo que não existe sai 2" || falha "verbo desconhecido não saiu 2" "$saida"
saida="$(meow ganchos --help)"
for v in instalar conferir remover; do
  grep -q "meow ganchos $v" <<<"$saida" && ok "meow ganchos --help lista $v" || falha "meow ganchos --help não lista $v" "$saida"
  grep -q "meow ganchos $v" <<<"$(meow --help)" && ok "meow --help lista meow ganchos $v" || falha "meow --help não lista meow ganchos $v"
done
grep -q "'ganchos:" "$RAIZ/dados/zsh/_meow" && ok "a completion oferece ganchos" || falha "a completion não oferece ganchos"
for v in instalar conferir remover; do
  awk '/^        ganchos\)/ { d = 1 } d && /^        [a-z-]+\)/ && !/ganchos/ { exit } d' "$RAIZ/dados/zsh/_meow" | grep -q "'$v:" \
    && ok "a completion de ganchos oferece $v" || falha "a completion de ganchos não oferece $v"
done

if [ "$falhas" -gt 0 ]; then
  printf '\n%d falha(s) nos ganchos.\n' "$falhas" >&2
  exit 1
fi
printf '\no pre-commit encadeia na pasta comum; pre-push e post-merge são chaves para a árvore, e só regeram o README no master e no push.\n'

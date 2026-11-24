#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

H="$T/casa"; E="$H/.local/state/meowsystem"; ORIGEM="$T/dona/MeowSystem"; CLONE="$H/MeowSystem"
mkdir -p "$T/bin" "$T/ci" "$E" "$H/.config/meow" "$ORIGEM"
: > "$E/lock"

g() {
  env -i PATH=/usr/bin:/bin HOME="$H" GIT_CONFIG_NOSYSTEM=1 \
    git -c user.name=teste -c user.email=teste@exemplo.invalid -c core.hooksPath=/dev/null \
        -c init.defaultBranch=master "$@"
}

for c in sudo pkexec su systemctl systemd-run pkill apt apt-get; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/proibido.log"\nexit 1\n' "$c" "$T" > "$T/bin/$c"
done
cat > "$T/bin/notify-send" <<FIM
#!/bin/sh
echo "\$*" >> "$T/notas.log"
FIM
cat > "$T/bin/curl" <<FIM
#!/bin/sh
echo "curl \$*" >> "$T/curl.log"
sha="\$(printf '%s' "\$*" | sed -n 's/.*head_sha=\([0-9a-f]*\).*/\1/p')"
estado="\$(cat "$T/ci/\$sha" 2>/dev/null)"
[ "\$(cat "$T/rede" 2>/dev/null)" = fora ] && exit 7
case "\$estado" in
  verde)    printf '{"workflow_runs":[{"id":2,"name":"testes","status":"completed","conclusion":"success"},{"id":3,"name":"anonymity-check","status":"completed","conclusion":"failure"}]}' ;;
  vermelho) printf '{"workflow_runs":[{"id":1,"name":"testes","status":"completed","conclusion":"success"},{"id":4,"name":"testes","status":"completed","conclusion":"failure"}]}' ;;
  curso)    printf '{"workflow_runs":[{"id":5,"name":"testes","status":"in_progress","conclusion":null}]}' ;;
  *)        printf '{"workflow_runs":[]}' ;;
esac
FIM
cat > "$T/bin/gpg" <<FIM
#!/bin/sh
echo "gpg \$*" >> "$T/gpg.log"
case " \$* " in
  *" --verify "*) cat > /dev/null
     printf '[GNUPG:] NEWSIG\n[GNUPG:] GOODSIG 0123456789ABCDEF falso\n[GNUPG:] VALIDSIG 0123456789ABCDEF0123456789ABCDEF01234567 2026-11-19 1795000000 0 4 0 22 10 00 0123456789ABCDEF0123456789ABCDEF01234567\n[GNUPG:] TRUST_ULTIMATE 0 pgp\n' ;;
  *) cat > /dev/null
     printf -- '-----BEGIN PGP SIGNATURE-----\n\nZmFsc28=\n-----END PGP SIGNATURE-----\n'
     printf '[GNUPG:] BEGIN_SIGNING H10\n[GNUPG:] SIG_CREATED D 22 10 00 1795000000 0123456789ABCDEF0123456789ABCDEF01234567\n' >&2 ;;
esac
FIM
printf '#!/bin/sh\nexit 0\n' > "$T/askpass"
chmod 755 "$T/bin"/* "$T/askpass"
ssh-keygen -q -t ed25519 -N '' -C casa -f "$T/chave-casa" && ssh-keygen -q -t ed25519 -N '' -C estranha -f "$T/chave-estranha" \
  || { echo "erro: o teste precisa do ssh-keygen"; exit 2; }
ASSINANTES="$H/.config/meow/assinantes"
printf 'casa namespaces="git" %s\n' "$(cut -d' ' -f1,2 "$T/chave-casa.pub")" > "$ASSINANTES"

mkdir -p "$ORIGEM/scripts" "$ORIGEM/dados/systemd"
cp -r "$RAIZ/scripts/lib" "$ORIGEM/scripts/lib"
cp "$RAIZ/scripts/atualiza.sh" "$ORIGEM/scripts/"
cp "$RAIZ/scripts/meow" "$ORIGEM/meow"
cat > "$ORIGEM/install.sh" <<FIM
#!/bin/sh
if [ -e "$T/recusa-uma" ]; then rm -f "$T/recusa-uma"; echo "install recusado pela trava" >> "$T/install.log"; echo "outro meow está rodando (derivados) — saindo"; exit 2; fi
flock -n "$E/lock" true || { echo "install recusado pela trava" >> "$T/install.log"; exit 2; }
echo "install \$(git rev-parse --short HEAD) askpass=\${SUDO_ASKPASS:-} tty=\$([ -t 0 ] && echo sim || echo nao)" >> "$T/install.log"
exit "\$(cat "$T/install.rc" 2>/dev/null || echo 0)"
FIM
chmod 755 "$ORIGEM/install.sh"
g -C "$ORIGEM" init -q
g -C "$ORIGEM" add -A
g -C "$ORIGEM" commit -qm base
g clone -q "$ORIGEM" "$CLONE"
printf '#!/bin/sh\necho "README=${MEOW_SEM_README:-}" >> "%s/gancho.log"\n' "$T" > "$CLONE/.git/hooks/post-merge"
chmod 755 "$CLONE/.git/hooks/post-merge"

commit_novo() {
  local quem="${2:-casa}"
  printf '%s\n' "$1" >> "$ORIGEM/novo.txt"
  g -C "$ORIGEM" add novo.txt
  case "$quem" in
    ninguem) g -C "$ORIGEM" commit -qm "$1" ;;
    pgp)     g -c gpg.program="$T/bin/gpg" -c user.signingkey=falso -C "$ORIGEM" commit -qS -m "$1" ;;
    *)       g -c gpg.format=ssh -c user.signingkey="$T/chave-$quem" -C "$ORIGEM" commit -qS -m "$1" ;;
  esac
  g -C "$ORIGEM" rev-parse HEAD
}
head_do_clone() { g -C "$CLONE" rev-parse HEAD; }
linhas() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
marcar() { sleep 1; touch "$T/marco"; }
escritos() { find "$H" -newer "$T/marco" -type f ! -path "$CLONE/*" ! -name atualiza.log | sort; }
ultima() { tail -n 1 "$E/atualiza.log" 2>/dev/null; }
desfecho() { [[ "$(ultima)" == *"$2"* ]] && ok "$1" || falha "$1 (última linha: '$(ultima)')"; }

atualizar() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$H" LANG=C.UTF-8 NO_COLOR=1 GIT_CONFIG_NOSYSTEM=1 \
    MEOW_PONTE=/nao/existe AT_SUDO_CONF="$T/sudo.conf" AT_PAUSA_DA_VEZ=1 \
    bash "$CLONE/scripts/atualiza.sh" rodar > "$T/saida" 2>&1
}

printf '\n1. o tronco igual não faz nada\n'
marcar
atualizar; rc=$?
igual "sai 0" "$rc" 0
igual "e calado" "$(cat "$T/saida")" ""
igual "não chama o install" "$(linhas "$T/install.log")" 0
igual "não pergunta ao GitHub" "$(linhas "$T/curl.log")" 0
igual "e não escreve nada no HOME fora o log" "$(escritos)" ""
desfecho "mas deixa no log que não havia nada novo" "nada novo no master"
l0="$(linhas "$E/atualiza.log")"
atualizar
igual "a segunda volta sem novidade deixa mais uma linha, e só uma" "$(linhas "$E/atualiza.log")" "$((l0 + 1))"
desfecho "dizendo de novo que não havia nada novo" "nada novo no master"

printf '\n2. um commit novo com o run verde avança e instala uma vez\n'
c1="$(commit_novo um)"; echo verde > "$T/ci/$c1"
printf 'Path askpass %s\n' "$T/askpass" > "$T/sudo.conf"
atualizar; rc=$?
igual "sai 0" "$rc" 0
igual "o clone está no commit novo" "$(head_do_clone)" "$c1"
igual "o install rodou uma vez" "$(linhas "$T/install.log")" 1
grep -q "askpass=$T/askpass tty=nao" "$T/install.log" && ok "com o askpass do sudo.conf e sem terminal" || falha "o install não recebeu o askpass: $(cat "$T/install.log")"
grep -q "repos/dona/MeowSystem/actions/runs?head_sha=$c1" "$T/curl.log" && ok "pergunta pelo run do commit, com dono e nome do origin" || falha "o curl não perguntou pelo commit: $(cat "$T/curl.log")"
grep -q -- '--max-time' "$T/curl.log" && ok "o curl vai com tempo máximo" || falha "o curl vai sem --max-time"
igual "o pós-merge não regera o README" "$(cat "$T/gancho.log" 2>/dev/null)" "README=1"
grep -q 'MeowSystem atualizado 1 mudança nova' "$T/notas.log" && ok "a notificação diz o que entrou" || falha "notificação: $(cat "$T/notas.log" 2>/dev/null)"
grep -q 'avançou do' "$E/atualiza.log" && ok "o atualiza.log registra o avanço" || falha "o atualiza.log não tem o avanço"
igual "nada de sudo, systemctl ou apt" "$(cat "$T/proibido.log" 2>/dev/null)" ""
marcar
atualizar
igual "a segunda passada não instala de novo" "$(linhas "$T/install.log")" 1
igual "e não escreve nada" "$(escritos)" ""

printf '\n3. run em curso ou vermelho não avança\n'
c2="$(commit_novo dois)"; echo curso > "$T/ci/$c2"
n0="$(linhas "$T/notas.log")"
atualizar
igual "em curso: o clone fica" "$(head_do_clone)" "$c1"
desfecho "e o log diz que espera um commit verde e assinado" "esperando um commit verde e assinado"
igual "e não avisa (tenta na próxima volta)" "$(linhas "$T/notas.log")" "$n0"
rm -f "$T/ci/$c2"
atualizar
igual "sem run ainda: o clone fica" "$(head_do_clone)" "$c1"
echo vermelho > "$T/ci/$c2"
l0="$(linhas "$E/atualiza.log")"
atualizar
igual "vermelho: o clone fica" "$(head_do_clone)" "$c1"
igual "e a volta deixa uma linha só" "$(linhas "$E/atualiza.log")" "$((l0 + 1))"
desfecho "que é o aviso do vermelho" "falhou nos testes"
igual "e avisa" "$(linhas "$T/notas.log")" "$((n0 + 1))"
grep -q 'falhou nos testes' "$T/notas.log" && ok "dizendo que o commit falhou nos testes" || falha "o aviso do vermelho: $(tail -1 "$T/notas.log")"
marcar
atualizar
igual "o mesmo vermelho não avisa de novo" "$(linhas "$T/notas.log")" "$((n0 + 1))"
igual "nem escreve" "$(escritos)" ""
desfecho "e o log diz que espera um commit verde e assinado" "esperando um commit verde e assinado"
c3="$(commit_novo tres)"; echo verde > "$T/ci/$c3"
c4="$(commit_novo quatro)"; echo curso > "$T/ci/$c4"
atualizar
igual "o verde mais novo vence o em curso acima dele" "$(head_do_clone)" "$c3"
igual "e instala" "$(linhas "$T/install.log")" 2
echo verde > "$T/ci/$c4"
atualizar
igual "quando o de cima fecha verde, avança até ele" "$(head_do_clone)" "$c4"

printf '\n4. o clone sujo ou à frente não é tocado, e avisa uma vez\n'
c5="$(commit_novo cinco)"; echo verde > "$T/ci/$c5"
printf 'mexido\n' >> "$CLONE/install.sh"
n0="$(linhas "$T/notas.log")"; i0="$(linhas "$T/install.log")"; l0="$(linhas "$E/atualiza.log")"
atualizar
igual "sujo: o clone fica" "$(head_do_clone)" "$c4"
igual "e a volta deixa uma linha só" "$(linhas "$E/atualiza.log")" "$((l0 + 1))"
desfecho "que é o aviso das mudanças locais" "mudanças locais"
igual "e avisa" "$(linhas "$T/notas.log")" "$((n0 + 1))"
grep -q 'mudanças locais' "$T/notas.log" && ok "dizendo que há mudanças locais" || falha "o aviso do sujo: $(tail -1 "$T/notas.log")"
marcar
atualizar
igual "a segunda volta não avisa de novo" "$(linhas "$T/notas.log")" "$((n0 + 1))"
igual "nem escreve" "$(escritos)" ""
desfecho "e o log diz que o clone está fora do tronco" "clone fora do tronco (sujo)"
igual "a mudança local ficou" "$(tail -1 "$CLONE/install.sh")" "mexido"
g -C "$CLONE" checkout -q -- install.sh
printf 'meu\n' > "$CLONE/meu.txt"; g -C "$CLONE" add meu.txt; g -C "$CLONE" commit -qm meu
meu="$(head_do_clone)"; l0="$(linhas "$E/atualiza.log")"
atualizar
igual "à frente: o clone fica" "$(head_do_clone)" "$meu"
igual "e a volta deixa uma linha só" "$(linhas "$E/atualiza.log")" "$((l0 + 1))"
desfecho "que é o aviso do commit próprio" "commits que o GitHub não tem"
atualizar
desfecho "e na volta seguinte o log diz que o clone está fora do tronco" "clone fora do tronco (frente)"
grep -q 'commits que o GitHub não tem' "$T/notas.log" && ok "e avisa que há commit próprio" || falha "o aviso do à frente: $(tail -1 "$T/notas.log")"
g -C "$CLONE" reset -q --hard "$c4"
g -C "$CLONE" checkout -q -b outra
l0="$(linhas "$E/atualiza.log")"
atualizar
igual "noutra branch: o clone fica" "$(head_do_clone)" "$c4"
igual "e a volta deixa uma linha só" "$(linhas "$E/atualiza.log")" "$((l0 + 1))"
desfecho "que é o aviso da branch" "está em outra, não no master"
atualizar
desfecho "e na volta seguinte o log diz que o clone está fora do tronco" "clone fora do tronco (ramo)"
grep -q 'está em outra, não no master' "$T/notas.log" && ok "e avisa a branch" || falha "o aviso da branch: $(tail -1 "$T/notas.log")"
g -C "$CLONE" checkout -q master
igual "nada disso instalou" "$(linhas "$T/install.log")" "$i0"

printf '\n5. ATUALIZA="nao" não faz nada\n'
printf 'ATUALIZA="nao"\n' > "$H/.config/meow/meow.conf"
c0="$(linhas "$T/curl.log")"
atualizar
igual "o clone fica" "$(head_do_clone)" "$c4"
igual "e nem pergunta ao GitHub" "$(linhas "$T/curl.log")" "$c0"
desfecho "e o log diz que está desligada" "desligada"
rm -f "$H/.config/meow/meow.conf"

printf '\n6. outro meow na trava: sai\n'
( exec 9>>"$E/lock"; flock 9; exec sleep 30 ) & dono=$!
for _ in $(seq 50); do flock -n "$E/lock" true || break; sleep 0.1; done
atualizar; rc=$?
kill "$dono" 2>/dev/null; wait "$dono" 2>/dev/null
igual "sai 0" "$rc" 0
igual "o clone fica" "$(head_do_clone)" "$c4"
igual "e não pergunta ao GitHub" "$(linhas "$T/curl.log")" "$c0"
desfecho "e o log diz que a trava estava ocupada" "trava ocupada"
rm -f "$E/lock"; mkdir "$E/lock"
atualizar; rc=$?
rmdir "$E/lock"; : > "$E/lock"
igual "trava que não abre: sai 0" "$rc" 0
desfecho "e o log diz que não abriu a trava" "não consegui abrir a trava"

printf '\n7. sem rede: sai calado\n'
mv "$ORIGEM" "$T/longe"
marcar
atualizar; rc=$?
igual "sem o origin: sai 0" "$rc" 0
igual "calado" "$(cat "$T/saida")" ""
igual "sem escrever fora o log" "$(escritos)" ""
desfecho "e o log diz que não houve rede" "sem rede"
mv "$T/longe" "$ORIGEM"
echo fora > "$T/rede"
n0="$(linhas "$T/notas.log")"
atualizar; rc=$?
igual "sem a API: sai 0" "$rc" 0
igual "o clone fica" "$(head_do_clone)" "$c4"
igual "e não avisa" "$(linhas "$T/notas.log")" "$n0"
desfecho "e o log diz que a consulta ao CI ficou sem rede" "sem rede"
rm -f "$T/rede"

printf '\n   o install que falha fica para a próxima volta\n'
echo 2 > "$T/install.rc"
i0="$(linhas "$T/install.log")"
atualizar
igual "o clone avança mesmo assim" "$(head_do_clone)" "$c5"
grep -q 'a instalação falhou' "$T/notas.log" && ok "e a notificação diz que a instalação falhou" || falha "sem aviso do install que falhou"
grep -q 'o install.sh saiu 2' "$E/atualiza.log" && ok "o log guarda o erro" || falha "o log não tem o erro"
rm -f "$T/install.rc"
atualizar
igual "a volta seguinte instala de novo" "$(linhas "$T/install.log")" "$((i0 + 2))"
atualizar
igual "e, instalado, a outra não instala mais" "$(linhas "$T/install.log")" "$((i0 + 2))"

printf '\n   quem pega a trava logo depois do pull não derruba o install\n'
cp "$CLONE/.git/hooks/post-merge" "$T/gancho-de-antes"
printf '#!/bin/bash\n( for n in {10..30}; do eval "exec $n>&-"; done; exec 9>>"%s/lock"; flock 9; sleep 3 ) > /dev/null 2>&1 &\n' "$E" > "$CLONE/.git/hooks/post-merge"
cv="$(commit_novo vez)"; echo verde > "$T/ci/$cv"
i0="$(linhas "$T/install.log")"
atualizar
cp "$T/gancho-de-antes" "$CLONE/.git/hooks/post-merge"
igual "o clone avança" "$(head_do_clone)" "$cv"
igual "o install roda uma vez" "$(linhas "$T/install.log")" "$((i0 + 1))"
tail -1 "$T/install.log" | grep -q '^install ' && ok "depois de esperar a vez, sem ser recusado pela trava" || falha "o install foi recusado: $(tail -1 "$T/install.log")"
tail -1 "$T/notas.log" | grep -q 'a instalação falhou' && falha "avisou falha de instalação" || ok "e sem aviso de falha"

printf '\n   quem pega a trava depois da espera também não derruba o install\n'
cr="$(commit_novo corrida)"; echo verde > "$T/ci/$cr"
i0="$(linhas "$T/install.log")"
: > "$T/recusa-uma"
atualizar
igual "o clone avança" "$(head_do_clone)" "$cr"
igual "o install é recusado uma vez e roda na segunda" "$(linhas "$T/install.log")" "$((i0 + 2))"
tail -1 "$T/install.log" | grep -q '^install ' && ok "a última tentativa instalou" || falha "a última tentativa: $(tail -1 "$T/install.log")"
tail -1 "$T/notas.log" | grep -q 'a instalação falhou' && falha "avisou falha de instalação" || ok "e sem aviso de falha"
grep -q 'tentativa 1 de 3' "$E/atualiza.log" && ok "o log conta a tentativa" || falha "o log não conta a tentativa"

printf '\n   só avança para commit assinado por chave da lista, que mora fora do repositório\n'
base="$(head_do_clone)"; n0="$(linhas "$T/notas.log")"; i0="$(linhas "$T/install.log")"
s1="$(commit_novo sem-assinatura ninguem)"; echo verde > "$T/ci/$s1"
atualizar
igual "verde sem assinatura: o clone fica" "$(head_do_clone)" "$base"
igual "e avisa" "$(linhas "$T/notas.log")" "$((n0 + 1))"
tail -1 "$T/notas.log" | grep -q 'não está assinado por quem a casa conhece' && ok "dizendo que falta a assinatura" || falha "o aviso da assinatura: $(tail -1 "$T/notas.log")"
marcar
atualizar
igual "o mesmo commit não avisa de novo" "$(linhas "$T/notas.log")" "$((n0 + 1))"
igual "nem escreve" "$(escritos)" ""
s2="$(commit_novo de-fora estranha)"; echo verde > "$T/ci/$s2"
atualizar
igual "assinado por chave fora da lista: o clone fica" "$(head_do_clone)" "$base"
mkdir -p "$ORIGEM/dados"
printf 'estranha namespaces="git" %s\n' "$(cut -d' ' -f1,2 "$T/chave-estranha.pub")" > "$ORIGEM/dados/assinantes"
g -C "$ORIGEM" add dados/assinantes
s3="$(commit_novo lista-no-repositorio estranha)"; echo verde > "$T/ci/$s3"
atualizar
igual "a chave que o commit põe na lista do repositório não vale: o clone fica" "$(head_do_clone)" "$base"
s4="$(commit_novo pgp pgp)"; echo verde > "$T/ci/$s4"
env -i PATH="$T/bin:/usr/bin:/bin" HOME="$H" GIT_CONFIG_NOSYSTEM=1 git -C "$ORIGEM" verify-commit "$s4" > /dev/null 2>&1 \
  && ok "o gpg desta máquina aprova a assinatura PGP do commit" || falha "o gpg de mentira não aprova o commit"
atualizar
igual "e mesmo assim o clone fica: só vale a lista" "$(head_do_clone)" "$base"
n1="$(linhas "$T/notas.log")"
s5="$(commit_novo da-casa)"; echo curso > "$T/ci/$s5"
atualizar
igual "ponta assinada em curso: não desce para o verde sem assinatura abaixo dela" "$(head_do_clone)" "$base"
igual "e não avisa, que a ponta está assinada" "$(linhas "$T/notas.log")" "$n1"
igual "nada disso instalou" "$(linhas "$T/install.log")" "$i0"
echo verde > "$T/ci/$s5"
atualizar
igual "assinado por chave da lista: avança, por cima dos sem assinatura" "$(head_do_clone)" "$s5"
igual "e instala uma vez" "$(linhas "$T/install.log")" "$((i0 + 1))"
mv "$ASSINANTES" "$T/lista-guardada"
s6="$(commit_novo sem-lista)"; echo verde > "$T/ci/$s6"
atualizar
igual "sem a lista nada avança" "$(head_do_clone)" "$s5"
mv "$T/lista-guardada" "$ASSINANTES"
atualizar
igual "com a lista de volta, avança" "$(head_do_clone)" "$s6"

printf '\n   o verbo do meow chama o mesmo script\n'
c6="$(commit_novo seis)"; echo verde > "$T/ci/$c6"
env -i PATH="$T/bin:/usr/bin:/bin" HOME="$H" LANG=C.UTF-8 NO_COLOR=1 GIT_CONFIG_NOSYSTEM=1 \
  MEOW_PONTE=/nao/existe AT_SUDO_CONF="$T/sudo.conf" MEOW_RAIZ="$CLONE" \
  bash "$CLONE/meow" atualizar > "$T/saida" 2>&1
igual "meow atualizar avança" "$(head_do_clone)" "$c6"

printf '\n8. a unidade e a fiação\n'
grep -qx 'OnActiveSec=3min' "$RAIZ/dados/systemd/meow-atualiza.timer" && ok "o timer tem OnActiveSec=3min" || falha "o timer sem OnActiveSec=3min"
grep -q 'OnBootSec' "$RAIZ/dados/systemd/meow-atualiza.timer" && falha "o timer ainda conta do boot" || ok "e não conta mais do boot"
grep -qx 'WantedBy=graphical-session.target' "$RAIZ/dados/systemd/meow-atualiza.timer" && grep -qx 'PartOf=graphical-session.target' "$RAIZ/dados/systemd/meow-atualiza.timer" \
  && ! grep -q 'timers.target' "$RAIZ/dados/systemd/meow-atualiza.timer" \
  && ok "o timer nasce com a sessão gráfica" || falha "o timer não está preso à graphical-session.target"
grep -qx 'ConditionEnvironment=WAYLAND_DISPLAY' "$RAIZ/dados/systemd/meow-atualiza.service" && ok "e o serviço só roda com WAYLAND_DISPLAY" || falha "o serviço sem ConditionEnvironment=WAYLAND_DISPLAY"
grep -qx 'OnUnitActiveSec=1d' "$RAIZ/dados/systemd/meow-atualiza.timer" && ok "e OnUnitActiveSec=1d" || falha "o timer sem OnUnitActiveSec=1d"
grep -q 'meow atualizar' "$RAIZ/dados/systemd/meow-atualiza.service" && ok "o serviço chama meow atualizar" || falha "o serviço não chama o verbo"
grep -q 'etapa_autoreparo etapa_atualiza)' "$RAIZ/install.sh" && ok "o install.sh tem a etapa" || falha "a etapa atualiza fora do install.sh"
grep -q 'meow-atualiza.timer meow-atualiza.service' "$RAIZ/scripts/lib/desinstalar.sh" && ok "o desinstalar tira as duas" || falha "o desinstalar esquece o meow-atualiza"
grep -qx 'ATUALIZA="sim" .*' "$RAIZ/meow.conf.exemplo" && ok "ATUALIZA=\"sim\" de fábrica" || falha "o exemplo sem ATUALIZA=\"sim\""
grep -q 'c: "ATUALIZA"' "$RAIZ/scripts/app/pagina/lugares.js" && ok "e a chave aparece no painel" || falha "a chave fora do painel"

printf '\n   aplicar e conferir as unidades\n'
U="$T/u"; mkdir -p "$U/bin" "$U/casa"
cat > "$U/bin/systemctl" <<FIM
#!/bin/sh
echo "systemctl \$*" >> "$U/systemctl.log"
case "\$*" in
  *"is-active graphical-session.target"*) [ -f "$U/sessao" ] && echo active || echo inactive ;;
  *is-enabled*) [ -f "$U/armado" ] && echo enabled || echo disabled ;;
  *is-active*)  [ -f "$U/ativo" ] && echo active || echo inactive ;;
  *"enable --now"*) touch "$U/armado" "$U/ativo" ;;
  *" enable "*) touch "$U/armado" ;;
  *"disable --now"*) rm -f "$U/armado" "$U/ativo" ;;
esac
exit 0
FIM
chmod 755 "$U/bin/systemctl"
unidades() {
  env -i PATH="$U/bin:/usr/bin:/bin" HOME="$U/casa" LANG=C.UTF-8 NO_COLOR=1 MEOW_PONTE=/nao/existe "$@" \
    bash "$RAIZ/scripts/atualiza.sh" "${UNIDADE_VERBO:-aplicar}" > "$U/saida" 2>&1
}
SEMENTE="$RAIZ/dados/assinantes"; SEMEADA="$U/semeia/.config/meow/assinantes"
unidades HOME="$U/semeia"
[ -s "$SEMEADA" ] && [ "$(cat "$SEMEADA")" = "$(cat "$SEMENTE")" ] && ok "o aplicar semeia a lista de quem assina quando ela falta" || falha "a lista não foi semeada: $(cat "$U/saida")"
grep -vE '^[a-z0-9-]+ namespaces="git" ssh-ed25519 [A-Za-z0-9+/=]+$' "$SEMENTE" | grep -q . && falha "a semente tem linha que não é «nome namespaces=\"git\" chave»" || ok "a semente só tem nome de máquina e chave pública"
printf 'minha ssh-ed25519 AAAA\n' > "$SEMEADA"
unidades HOME="$U/semeia"
igual "e não troca a lista que já existe" "$(cat "$SEMEADA")" "minha ssh-ed25519 AAAA"
rm -f "$SEMEADA"
UNIDADE_VERBO=conferir unidades HOME="$U/semeia"
igual "sem a lista o doctor diverge: sai 1" "$?" 1
grep -q 'lista de quem assina' "$U/saida" && ok "dizendo que falta a lista" || falha "o conferir sem a lista: $(cat "$U/saida")"
unidades HOME="$U/semeia" MEOW_DRY_RUN=1
[ ! -e "$SEMEADA" ] && ok "o aplicar em seco não semeia" || falha "o seco semeou a lista"
rm -f "$U/armado" "$U/ativo"; : > "$U/systemctl.log"; : > "$U/sessao"
mkdir -p "$U/casa/.config/meow"; cp "$SEMENTE" "$U/casa/.config/meow/assinantes"
if [ -d "/run/user/$(id -u)/systemd" ]; then
  unidades; rc=$?
  igual "aplicar instala e arma: sai 1" "$rc" 1
  [ "$(cat "$U/casa/.config/systemd/user/meow-atualiza.timer" 2>/dev/null)" = "$(cat "$RAIZ/dados/systemd/meow-atualiza.timer")" ] \
    && ok "o timer instalado é o do repositório" || falha "o timer não foi instalado"
  UNIDADE_VERBO=conferir unidades; igual "o doctor confere: sai 0" "$?" 0
  mkdir -p "$U/casa/.config/systemd/user/timers.target.wants"
  ln -s ../meow-atualiza.timer "$U/casa/.config/systemd/user/timers.target.wants/meow-atualiza.timer"
  UNIDADE_VERBO=conferir unidades; rc=$?
  igual "com o vínculo antigo em timers.target.wants o doctor diverge: sai 1" "$rc" 1
  grep -q 'timers.target' "$U/saida" && ok "e aponta o timer preso ao boot" || falha "o conferir não apontou o vínculo: $(cat "$U/saida")"
  unidades; rc=$?
  igual "o aplicar solta o vínculo antigo: sai 1" "$rc" 1
  [ ! -L "$U/casa/.config/systemd/user/timers.target.wants/meow-atualiza.timer" ] && ok "e ele sumiu" || falha "o vínculo antigo ficou"
  UNIDADE_VERBO=conferir unidades; igual "o doctor confere de novo: sai 0" "$?" 0
  : > "$U/systemctl.log"; sleep 1; touch "$U/marco"
  unidades; rc=$?
  igual "a segunda passada sai 0" "$rc" 0
  igual "e não escreve nada" "$(find "$U/casa" -newer "$U/marco" -type f)" ""
  grep -q 'enable --now' "$U/systemctl.log" && falha "a segunda passada armou de novo" || ok "e não arma de novo"
  rm -f "$U/sessao" "$U/ativo"
  UNIDADE_VERBO=conferir unidades; igual "sem sessão gráfica (ssh), o timer habilitado e parado por PartOf não diverge: sai 0" "$?" 0
  rm -f "$U/armado"; : > "$U/systemctl.log"
  unidades; rc=$?
  igual "sem sessão gráfica, o aplicar habilita o timer: sai 1" "$rc" 1
  [ -f "$U/armado" ] && [ ! -f "$U/ativo" ] && ! grep -q 'enable --now' "$U/systemctl.log" \
    && ok "e não dá partida nele fora da sessão" || falha "fora da sessão o aplicar deu partida no timer: $(cat "$U/systemctl.log")"
  UNIDADE_VERBO=conferir unidades; igual "e o doctor confere em ordem: sai 0" "$?" 0
  : > "$U/sessao"; touch "$U/ativo"
  unidades ATUALIZA=nao; rc=$?
  igual "ATUALIZA=\"nao\" tira as unidades: sai 1" "$rc" 1
  [ ! -e "$U/casa/.config/systemd/user/meow-atualiza.timer" ] && [ ! -e "$U/armado" ] && ok "e desarma o timer" || falha "o timer ficou"
  UNIDADE_VERBO=conferir unidades ATUALIZA=nao; igual "o doctor diz escolha sua: sai 3" "$?" 3
else
  unidades; rc=$?
  igual "sem systemd --user: aplicar sai 3" "$rc" 3
  grep -q 'não há systemd --user' "$U/saida" && ok "e diz que fica de fora" || falha "aplicar sem systemd: $(cat "$U/saida")"
fi

printf '\n'
if [ "$falhas" = 0 ]; then echo "atualiza: tudo certo"; exit 0; fi
echo "atualiza: $falhas falha(s)"; exit 1

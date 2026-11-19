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
printf '#!/bin/sh\nexit 0\n' > "$T/askpass"
chmod 755 "$T/bin"/* "$T/askpass"

cp -r "$RAIZ/lib" "$ORIGEM/lib"
mkdir -p "$ORIGEM/scripts" "$ORIGEM/systemd"
cp "$RAIZ/scripts/atualiza.sh" "$ORIGEM/scripts/"
cp "$RAIZ/bin/meow" "$ORIGEM/meow"
cat > "$ORIGEM/install.sh" <<FIM
#!/bin/sh
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
  printf '%s\n' "$1" >> "$ORIGEM/novo.txt"
  g -C "$ORIGEM" add novo.txt
  g -C "$ORIGEM" commit -qm "$1"
  g -C "$ORIGEM" rev-parse HEAD
}
head_do_clone() { g -C "$CLONE" rev-parse HEAD; }
linhas() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
marcar() { sleep 1; touch "$T/marco"; }
escritos() { find "$H" -newer "$T/marco" -type f ! -path "$CLONE/*" | sort; }

atualizar() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$H" LANG=C.UTF-8 NO_COLOR=1 GIT_CONFIG_NOSYSTEM=1 \
    MEOW_PONTE=/nao/existe AT_SUDO_CONF="$T/sudo.conf" \
    bash "$CLONE/scripts/atualiza.sh" rodar > "$T/saida" 2>&1
}

printf '\n1. o tronco igual não faz nada\n'
marcar
atualizar; rc=$?
igual "sai 0" "$rc" 0
igual "e calado" "$(cat "$T/saida")" ""
igual "não chama o install" "$(linhas "$T/install.log")" 0
igual "não pergunta ao GitHub" "$(linhas "$T/curl.log")" 0
igual "e não escreve nada no HOME" "$(escritos)" ""

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
igual "e não avisa (tenta na próxima volta)" "$(linhas "$T/notas.log")" "$n0"
rm -f "$T/ci/$c2"
atualizar
igual "sem run ainda: o clone fica" "$(head_do_clone)" "$c1"
echo vermelho > "$T/ci/$c2"
atualizar
igual "vermelho: o clone fica" "$(head_do_clone)" "$c1"
igual "e avisa" "$(linhas "$T/notas.log")" "$((n0 + 1))"
grep -q 'falhou nos testes' "$T/notas.log" && ok "dizendo que o commit falhou nos testes" || falha "o aviso do vermelho: $(tail -1 "$T/notas.log")"
marcar
atualizar
igual "o mesmo vermelho não avisa de novo" "$(linhas "$T/notas.log")" "$((n0 + 1))"
igual "nem escreve" "$(escritos)" ""
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
n0="$(linhas "$T/notas.log")"; i0="$(linhas "$T/install.log")"
atualizar
igual "sujo: o clone fica" "$(head_do_clone)" "$c4"
igual "e avisa" "$(linhas "$T/notas.log")" "$((n0 + 1))"
grep -q 'mudanças locais' "$T/notas.log" && ok "dizendo que há mudanças locais" || falha "o aviso do sujo: $(tail -1 "$T/notas.log")"
marcar
atualizar
igual "a segunda volta não avisa de novo" "$(linhas "$T/notas.log")" "$((n0 + 1))"
igual "nem escreve" "$(escritos)" ""
igual "a mudança local ficou" "$(tail -1 "$CLONE/install.sh")" "mexido"
g -C "$CLONE" checkout -q -- install.sh
printf 'meu\n' > "$CLONE/meu.txt"; g -C "$CLONE" add meu.txt; g -C "$CLONE" commit -qm meu
meu="$(head_do_clone)"
atualizar
igual "à frente: o clone fica" "$(head_do_clone)" "$meu"
grep -q 'commits que o GitHub não tem' "$T/notas.log" && ok "e avisa que há commit próprio" || falha "o aviso do à frente: $(tail -1 "$T/notas.log")"
g -C "$CLONE" reset -q --hard "$c4"
g -C "$CLONE" checkout -q -b outra
atualizar
igual "noutra branch: o clone fica" "$(head_do_clone)" "$c4"
grep -q 'está em outra, não no master' "$T/notas.log" && ok "e avisa a branch" || falha "o aviso da branch: $(tail -1 "$T/notas.log")"
g -C "$CLONE" checkout -q master
igual "nada disso instalou" "$(linhas "$T/install.log")" "$i0"

printf '\n5. ATUALIZA="nao" não faz nada\n'
printf 'ATUALIZA="nao"\n' > "$H/.config/meow/meow.conf"
c0="$(linhas "$T/curl.log")"
atualizar
igual "o clone fica" "$(head_do_clone)" "$c4"
igual "e nem pergunta ao GitHub" "$(linhas "$T/curl.log")" "$c0"
rm -f "$H/.config/meow/meow.conf"

printf '\n6. outro meow na trava: sai\n'
( exec 9>>"$E/lock"; flock 9; exec sleep 30 ) & dono=$!
for _ in $(seq 50); do flock -n "$E/lock" true || break; sleep 0.1; done
atualizar; rc=$?
kill "$dono" 2>/dev/null; wait "$dono" 2>/dev/null
igual "sai 0" "$rc" 0
igual "o clone fica" "$(head_do_clone)" "$c4"
igual "e não pergunta ao GitHub" "$(linhas "$T/curl.log")" "$c0"

printf '\n7. sem rede: sai calado\n'
mv "$ORIGEM" "$T/longe"
marcar
atualizar; rc=$?
igual "sem o origin: sai 0" "$rc" 0
igual "calado" "$(cat "$T/saida")" ""
igual "sem escrever" "$(escritos)" ""
mv "$T/longe" "$ORIGEM"
echo fora > "$T/rede"
n0="$(linhas "$T/notas.log")"
atualizar; rc=$?
igual "sem a API: sai 0" "$rc" 0
igual "o clone fica" "$(head_do_clone)" "$c4"
igual "e não avisa" "$(linhas "$T/notas.log")" "$n0"
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

printf '\n   o verbo do meow chama o mesmo script\n'
c6="$(commit_novo seis)"; echo verde > "$T/ci/$c6"
env -i PATH="$T/bin:/usr/bin:/bin" HOME="$H" LANG=C.UTF-8 NO_COLOR=1 GIT_CONFIG_NOSYSTEM=1 \
  MEOW_PONTE=/nao/existe AT_SUDO_CONF="$T/sudo.conf" MEOW_RAIZ="$CLONE" \
  bash "$CLONE/meow" atualizar > "$T/saida" 2>&1
igual "meow atualizar avança" "$(head_do_clone)" "$c6"

printf '\n8. a unidade e a fiação\n'
grep -qx 'OnBootSec=3min' "$RAIZ/systemd/meow-atualiza.timer" && ok "o timer tem OnBootSec=3min" || falha "o timer sem OnBootSec=3min"
grep -qx 'OnUnitActiveSec=1d' "$RAIZ/systemd/meow-atualiza.timer" && ok "e OnUnitActiveSec=1d" || falha "o timer sem OnUnitActiveSec=1d"
grep -q 'meow atualizar' "$RAIZ/systemd/meow-atualiza.service" && ok "o serviço chama meow atualizar" || falha "o serviço não chama o verbo"
grep -q 'etapa_autoreparo etapa_atualiza)' "$RAIZ/install.sh" && ok "o install.sh tem a etapa" || falha "a etapa atualiza fora do install.sh"
grep -q 'meow-atualiza.timer meow-atualiza.service' "$RAIZ/lib/desinstalar.sh" && ok "o desinstalar tira as duas" || falha "o desinstalar esquece o meow-atualiza"
grep -qx 'ATUALIZA="sim" .*' "$RAIZ/meow.conf.exemplo" && ok "ATUALIZA=\"sim\" de fábrica" || falha "o exemplo sem ATUALIZA=\"sim\""
grep -q 'c: "ATUALIZA"' "$RAIZ/app/pagina/lugares.js" && ok "e a chave aparece no painel" || falha "a chave fora do painel"

printf '\n   aplicar e conferir as unidades\n'
U="$T/u"; mkdir -p "$U/bin" "$U/casa"
cat > "$U/bin/systemctl" <<FIM
#!/bin/sh
echo "systemctl \$*" >> "$U/systemctl.log"
case "\$*" in
  *is-enabled*) [ -f "$U/armado" ] && echo enabled || echo disabled ;;
  *is-active*)  [ -f "$U/armado" ] && echo active || echo inactive ;;
  *"enable --now"*) touch "$U/armado" ;;
  *"disable --now"*) rm -f "$U/armado" ;;
esac
exit 0
FIM
chmod 755 "$U/bin/systemctl"
unidades() {
  env -i PATH="$U/bin:/usr/bin:/bin" HOME="$U/casa" LANG=C.UTF-8 NO_COLOR=1 MEOW_PONTE=/nao/existe "$@" \
    bash "$RAIZ/scripts/atualiza.sh" "${UNIDADE_VERBO:-aplicar}" > "$U/saida" 2>&1
}
if [ -d "/run/user/$(id -u)/systemd" ]; then
  unidades; rc=$?
  igual "aplicar instala e arma: sai 1" "$rc" 1
  [ "$(cat "$U/casa/.config/systemd/user/meow-atualiza.timer" 2>/dev/null)" = "$(cat "$RAIZ/systemd/meow-atualiza.timer")" ] \
    && ok "o timer instalado é o do repositório" || falha "o timer não foi instalado"
  UNIDADE_VERBO=conferir unidades; igual "o doctor confere: sai 0" "$?" 0
  : > "$U/systemctl.log"; sleep 1; touch "$U/marco"
  unidades; rc=$?
  igual "a segunda passada sai 0" "$rc" 0
  igual "e não escreve nada" "$(find "$U/casa" -newer "$U/marco" -type f)" ""
  grep -q 'enable --now' "$U/systemctl.log" && falha "a segunda passada armou de novo" || ok "e não arma de novo"
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

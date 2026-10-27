#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

mkdir -p "$T/bin" "$T/home/.local/bin" "$T/home/.config/meow" "$T/patches"
echo 'req t.patch MEOW-T' > "$T/patches/series"
for c in sudo pkexec apt apt-get systemctl systemd-run pkill killall notify-send cargo make; do
  printf '#!/bin/sh\necho "recusado: %s $*" >> "%s/recusados"\nexit 1\n' "$c" "$T" > "$T/bin/$c"
  chmod 755 "$T/bin/$c"
done
cat > "$T/bin/dpkg-query" <<FIM
#!/bin/sh
fmt=""; pacotes=""
for a in "\$@"; do
  case "\$a" in -W) ;; -f=*) fmt="\${a#-f=}" ;; *) pacotes="\$pacotes \$a" ;; esac
done
for p in \$pacotes; do
  linha=\$(awk -F'\t' -v p="\$p" '\$1==p' "$T/dpkg.tsv")
  [ -n "\$linha" ] || continue
  case "\$fmt" in
    *Package*) printf '%s\n' "\$linha" ;;
    *) printf '%s' "\$(printf '%s' "\$linha" | cut -f2)" ;;
  esac
done
FIM
chmod 755 "$T/bin/dpkg-query"
versoes() {
  : > "$T/dpkg.tsv"; local x
  for x in "$@"; do printf '%s\t%s\tinstalled\n' "${x%%=*}" "${x#*=}" >> "$T/dpkg.tsv"; done
}
CASA="$T/home/.local/libexec/meow/cosmic-comp"
ESTADO="$T/home/.local/state/meowsystem"
cat > "$T/compositor" <<FIM
#!/bin/sh
echo "compositor \$*" >> "$T/log"
[ "\$1" = compilar ] || exit 0
[ -n "\${DEVAGAR:-}" ] && sleep "\$DEVAGAR"
v=\$(awk -F'\t' '\$1=="cosmic-comp"{print \$2}' "$T/dpkg.tsv")
if [ -f "$T/comp-req-falha" ]; then
  mkdir -p "$ESTADO/cosmic-comp"
  printf '%s\t2026-10-15\tcosmic-comp-sem-workspace-vazio.patch:4\n' "\$v" >> "$ESTADO/cosmic-comp/matriz.tsv"
  exit 2
fi
[ -f "$T/comp-falha" ] && exit 2
mkdir -p "$CASA/\$v"
printf '#!/bin/sh\n' > "$CASA/\$v/cosmic-comp"; chmod 755 "$CASA/\$v/cosmic-comp"
echo "req MEOW-T-1 t.patch presente" > "$CASA/\$v/estado"
exit 1
FIM
cat > "$T/files" <<FIM
#!/bin/sh
echo "files \$*" >> "$T/log"
[ "\$1" = build ] || exit 0
[ -f "$T/files-falha" ] && exit 2
v=\$(awk -F'\t' '\$1=="cosmic-files"{print \$2}' "$T/dpkg.tsv")
mkdir -p "$ESTADO/cosmic-files/\$v"
for b in cosmic-files cosmic-files-applet; do
  echo MEOW-FILES-WALLPAPER-PATCH-1 > "$ESTADO/cosmic-files/\$v/\$b"
done
exit 1
FIM
chmod 755 "$T/compositor" "$T/files"

rodar() {
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY \
    HOME="$T/home" PATH="$T/bin:$PATH" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
    MEOW_ESTADO="$ESTADO" MEOW_CONF="$T/home/.config/meow/meow.conf" \
    GB_COMPOSITOR="$T/compositor" GB_FILES="$T/files" \
    CP_REPO="$T/patches" CP_SERIE="$T/patches/series" \
    "$RAIZ/scripts/garantir_builds.sh" "$@" > "$T/saida" 2>&1
}
linhas() { grep -c "$1" "$T/log" 2>/dev/null || true; }
foto() { (cd "$T/home" && find . -printf '%p %s %T@\n' | sort; find . -type f -exec sha256sum {} + | sort) | sha256sum; }

echo "== 1. a função"
[ -x "$RAIZ/scripts/garantir_builds.sh" ] || { falha "scripts/garantir_builds.sh não existe"; echo "garantir-builds: $falhas falha(s)"; exit 1; }

echo "-- primeira passagem, nada construído, shim DESLIGADO"
versoes cosmic-comp=0.1~a cosmic-files=1.10~a cosmic-panel=1.10~a
: > "$T/log"; rodar; igual "rc 0 (pronto)" "$?" 0
igual "um build do compositor, mesmo sem o shim" "$(linhas '^compositor compilar')" 1
igual "um build do menu" "$(linhas '^files build')" 1
[ -x "$CASA/0.1~a/cosmic-comp" ] && ok "o build do compositor ficou na casa da versão" || falha "o build do compositor não ficou na casa"

echo "-- segunda passagem: zero, e nenhum byte"
antes="$(foto)"
: > "$T/log"; rodar; igual "rc 0" "$?" 0
igual "nenhum build" "$(grep -c . "$T/log")" 0
igual "o HOME não mudou (nem o lock)" "$(foto)" "$antes"

echo "-- versão nova do compositor: só ele"
versoes cosmic-comp=0.1~b cosmic-files=1.10~a
: > "$T/log"; rodar
igual "um build do compositor" "$(linhas '^compositor compilar')" 1
igual "nenhum build do menu" "$(linhas '^files build')" 0

echo "-- o build posto de lado (ruim) não se refaz"
versoes cosmic-comp=0.1~c cosmic-files=1.10~a
mkdir -p "$CASA/0.1~c"; date -Is > "$CASA/0.1~c/ruim"
: > "$T/log"; rodar; igual "rc 0" "$?" 0
igual "nenhum build do compositor" "$(linhas '^compositor compilar')" 0

echo "-- FILES_MENU=\"nao\": o menu não se compila"
printf 'FILES_MENU="nao"\n' > "$T/home/.config/meow/meow.conf"
versoes cosmic-comp=0.1~c cosmic-files=1.10~b
: > "$T/log"; rodar
igual "nenhum build do menu" "$(linhas '^files build')" 0
rm -f "$T/home/.config/meow/meow.conf"

echo "-- o obrigatório que não entra (degrau 4): regra, não falha"
versoes cosmic-comp=0.1~d cosmic-files=1.10~b
touch "$T/comp-req-falha"
: > "$T/log"; rodar; igual "rc 0" "$?" 0
[ -e "$CASA/0.1~d/cosmic-comp" ] && falha "apareceu build do compositor" || ok "nada foi trocado: o shim segue no de fábrica"
antes="$(foto)"
: > "$T/log"; rodar; igual "2ª passagem no degrau 4: rc 0" "$?" 0
igual "2ª passagem no degrau 4: nenhuma tentativa" "$(linhas '^compositor compilar')" 0
igual "2ª passagem no degrau 4: nenhum byte" "$(foto)" "$antes"
grep -q 'degrau 4' "$T/saida" && ok "e diz o estado (degrau 4)" || falha "a 2ª passagem no degrau 4 não disse o estado"
rm -f "$T/comp-req-falha"
sleep 0.05; touch "$T/patches/series"
: > "$T/log"; rodar; igual "a série mudou: rc 0" "$?" 0
igual "a série mudou: a mesma versão tenta de novo" "$(linhas '^compositor compilar')" 1
[ -x "$CASA/0.1~d/cosmic-comp" ] && ok "e o build do rebase fica na casa" || falha "o rebase não deixou build"

echo "-- a falha de verdade sai 2, e o próximo gatilho tenta de novo"
versoes cosmic-comp=0.1~d2 cosmic-files=1.10~b
touch "$T/comp-falha"
: > "$T/log"; rodar; igual "rc 2" "$?" 2
rm -f "$T/comp-falha"
: > "$T/log"; rodar; igual "rc 0 na seguinte" "$?" 0
igual "e ela compila" "$(linhas '^compositor compilar')" 1

echo "-- o seco não compila"
versoes cosmic-comp=0.1~e cosmic-files=1.10~b
: > "$T/log"; MEOW_DRY_RUN=1 rodar --seco; igual "rc 1 (compilaria)" "$?" 1
igual "nenhum build" "$(grep -c . "$T/log")" 0
grep -q 'cosmic-comp 0.1~e' "$T/saida" && ok "e diz qual" || falha "o seco não disse o que compilaria"

echo "-- duas passagens juntas: um build só (flock)"
versoes cosmic-comp=0.1~f cosmic-files=1.10~b
: > "$T/log"
DEVAGAR=1 rodar & p1=$!
DEVAGAR=1 rodar & p2=$!
wait "$p1" "$p2"
igual "um build do compositor" "$(linhas '^compositor compilar')" 1

echo "-- estado: o que a página Extensões lê, sem compilar nem escrever"
versoes cosmic-comp=0.1~z cosmic-files=1.10~z
antes="$(foto)"; : > "$T/log"
rodar estado
depois="$(foto)"
igual "o compositor sem build: pendente" "$(sed -n 's/^compositor_estado=//p' "$T/saida")" pendente
igual "o menu sem build: pendente" "$(sed -n 's/^menu_estado=//p' "$T/saida")" pendente
igual "a versão do compositor" "$(sed -n 's/^compositor_versao=//p' "$T/saida")" "0.1~z"
igual "um remendo na série" "$(sed -n 's/^remendos=//p' "$T/saida")" 1
mkdir -p "$CASA/0.1~z"; date -Is > "$CASA/0.1~z/ruim"
rodar estado
igual "o build posto de lado: falhou" "$(sed -n 's/^compositor_estado=//p' "$T/saida")" falhou
rm -rf "$CASA/0.1~z"
igual "estado não compilou nada" "$(grep -c . "$T/log")" 0
igual "e não escreveu nada" "$depois" "$antes"

echo "-- o build pronto com o shim desligado: desligado, e não «Em dia»"
versoes cosmic-comp=0.1~a cosmic-files=1.10~a
rm -f "$T/home/.local/bin/cosmic-comp"
rodar estado
igual "build pronto, shim ausente: desligado" "$(sed -n 's/^compositor_estado=//p' "$T/saida")" desligado
cp "$RAIZ/scripts/compositor_shim.sh" "$T/home/.local/bin/cosmic-comp"
rodar estado
igual "build pronto, shim ligado: ok" "$(sed -n 's/^compositor_estado=//p' "$T/saida")" ok
rm -f "$T/home/.local/bin/cosmic-comp"

echo "-- o pino do compositor: instalar liga o shim, remover o tira (HOME de brinquedo)"
gesto() {
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY \
    HOME="$T/home" PATH="$T/bin:$PATH" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
    MEOW_ESTADO="$ESTADO" MEOW_CONF="$T/home/.config/meow/meow.conf" \
    GB_COMPOSITOR="$T/compositor" GB_FILES="$T/files" \
    CP_REPO="$T/patches" CP_SERIE="$T/patches/series" \
    "$RAIZ/scripts/extensoes_gesto.sh" "$@" > "$T/saida" 2>&1
}
: > "$T/log"; gesto instalar compositor; rc=$?
igual "instalar compositor com o build pronto devolve 1" "$rc" 1
grep -qs 'MEOW-COSMIC-COMP-SHIM-1' "$T/home/.local/bin/cosmic-comp" \
  && ok "o shim está em ~/.local/bin/cosmic-comp" || { falha "instalar não criou o shim"; sed 's/^/        /' "$T/saida"; }
igual "e não compilou nada" "$(linhas '^compositor compilar')" 0
igual "o meow.conf diz COMPOSITOR=sim" "$(sed -n 's/^COMPOSITOR="\(.*\)".*/\1/p' "$T/home/.config/meow/meow.conf" | tail -1)" sim
antes="$(foto)"
gesto instalar compositor; rc=$?
igual "a segunda passada devolve 0" "$rc" 0
igual "e não escreve nada" "$(foto)" "$antes"
gesto remover compositor; rc=$?
igual "remover compositor devolve 1" "$rc" 1
[ -e "$T/home/.local/bin/cosmic-comp" ] && falha "remover deixou o shim" || ok "o shim saiu"
[ -x "$CASA/0.1~a/cosmic-comp" ] && ok "e o build fica guardado" || falha "remover apagou o build"
igual "o meow.conf diz COMPOSITOR=nao" "$(sed -n 's/^COMPOSITOR="\(.*\)".*/\1/p' "$T/home/.config/meow/meow.conf" | tail -1)" nao
rm -f "$T/home/.config/meow/meow.conf"

echo
echo "== 2. os três gatilhos chamam a mesma função"
U="$RAIZ/systemd/meow-builds-login.service"
if [ -f "$U" ] && grep -q '^WantedBy=graphical-session.target$' "$U" && grep -q '^Nice=19$' "$U" \
   && grep -q '^IOSchedulingClass=idle$' "$U" && grep -q 'scripts/garantir_builds.sh' "$U"; then
  ok "o login: meow-builds-login.service, no alvo gráfico, Nice 19 e IO ocioso, roda a função"
else
  falha "falta o meow-builds-login.service (no alvo gráfico, Nice 19, IO ocioso, rodando a função)"
fi
grep -q 'PA_BUILDS:-$MEOW_RAIZ/scripts/garantir_builds.sh' "$RAIZ/scripts/cosmic_pos_apt.sh" \
  && ok "o pós-apt: chama a função" || falha "o pós-apt não chama a função"
grep -qE '^fix_patches\(\) *\{ *"\$RAIZ/scripts/garantir_builds.sh" --fundo' "$RAIZ/bin/meow" \
  && ok "o doctor: o fix_patches dispara a função" || falha "o doctor não tem o fix_patches da função"
etapa="$(sed -n '/^etapa_vigia_apt()/,/^}/p' "$RAIZ/install.sh")"
if grep -q 'meow-builds-login.service' <<< "$etapa" && grep -q 'systemctl --user enable "$u"' <<< "$etapa"; then
  ok "o instalador põe e habilita o login, sem --now"
else
  falha "o instalador não habilita o meow-builds-login.service"
fi
grep -q 'meow-builds-login.service' "$RAIZ/lib/desinstalar.sh" \
  && ok "o desinstalador o desliga" || falha "o desinstalador não desliga o meow-builds-login.service"

echo "-- as três unidades, com o PATH que o systemd dá, acham o just e o cargo do ~/.cargo/bin"
U2="$T/unid"; mkdir -p "$U2/.cargo/bin" "$U2/.local/bin" "$U2/.local/state/meowsystem" "$U2/raiz/scripts"
for c in just cargo; do printf '#!/bin/sh\n' > "$U2/.cargo/bin/$c"; chmod 755 "$U2/.cargo/bin/$c"; done
for sonda in "$U2/raiz/scripts/cosmic_pos_apt.sh" "$U2/raiz/scripts/garantir_builds.sh" "$U2/.local/bin/meow"; do
  printf '#!/bin/sh\ncommand -v just; command -v cargo\n' > "$sonda"; chmod 755 "$sonda"
done
printf '%s\n' "$U2/raiz" > "$U2/.local/state/meowsystem/raiz"
for u in meow-pos-apt.service meow-builds-login.service meow-doctor.service; do
  linha="$(sed -n 's/^ExecStart=//p' "$RAIZ/systemd/$u" | sed "s|%h|$U2|g")"
  achou="$(env -i HOME="$U2" PATH="$U2/.local/bin:/usr/local/bin:/usr/bin:/bin" bash -c "$linha" 2>&1 | tr '\n' ' ')"
  igual "$u acha o just e o cargo" "$achou" "$U2/.cargo/bin/just $U2/.cargo/bin/cargo "
done

echo "-- o doctor --consertar compila o compositor que falta (shim ligado, HOME de brinquedo)"
D="$T/doc"; mkdir -p "$D/.config/meow" "$D/.local/bin"
cp "$RAIZ/meow.conf.exemplo" "$D/.config/meow/meow.conf"
cp "$RAIZ/scripts/compositor_shim.sh" "$D/.local/bin/cosmic-comp"
DCASA="$D/.local/libexec/meow/cosmic-comp"
cat > "$T/compositor-doc" <<FIM
#!/bin/sh
[ "\$1" = compilar ] || exit 0
echo "compositor \$*" >> "$T/log"
v=\$(awk -F'\t' '\$1=="cosmic-comp"{print \$2}' "$T/dpkg.tsv")
mkdir -p "$DCASA/\$v"
printf '#!/bin/sh\n# MEOW-T-PATCH-1\n' > "$DCASA/\$v/cosmic-comp"; chmod 755 "$DCASA/\$v/cosmic-comp"
printf 'versao=%s\nreq MEOW-T-PATCH-1 t.patch presente\n' "\$v" > "$DCASA/\$v/estado"
exit 1
FIM
chmod 755 "$T/compositor-doc"
printf 'VERIFICAVEIS=(patches)\n' > "$T/so-patches"
doctor() {
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY \
    PATH="$T/bin:$PATH" HOME="$D" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
    XDG_CONFIG_HOME="$D/.config" XDG_STATE_HOME="$D/.local/state" \
    GB_COMPOSITOR="$T/compositor-doc" GB_FILES="$T/files" GB_FILES_GUARDA="$ESTADO/cosmic-files" \
    bash -c '
      source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow")
      source "$1"; shift
      cmd_doctor "$@"' _ "$T/so-patches" "$@" > "$T/doc.saida" 2>&1
}
versoes cosmic-comp=0.1~g cosmic-files=1.10~b
: > "$T/log"; doctor; rc=$?
igual "sem build, a linha patches diverge (rc 1)" "$rc" 1
grep -q 'ainda não tem build' "$T/doc.saida" && ok "e diz o estado" || { falha "a linha patches não disse o estado"; sed 's/^/        /' "$T/doc.saida"; }
: > "$T/log"; doctor --consertar; rc=$?
igual "o --consertar sai 1 (consertado)" "$rc" 1
igual "um build do compositor, pelo conserto" "$(linhas '^compositor compilar')" 1
grep -q 'continua fora' "$T/doc.saida" && { falha "a linha patches ficou fora depois do conserto"; sed 's/^/        /' "$T/doc.saida"; }
: > "$T/log"; doctor; rc=$?
igual "o doctor seguinte não diverge (rc 0)" "$rc" 0
if grep -qE 'patches +(build pronto, vale no próximo login|1 marcador de pé)' "$T/doc.saida"; then
  ok "a linha patches diz o estado: $(grep -oE 'build pronto, vale no próximo login|1 marcador de pé[^;]*' "$T/doc.saida" | head -1)"
else
  falha "a linha patches não diz o estado do build"; sed 's/^/        /' "$T/doc.saida"
fi
igual "e não compila de novo" "$(grep -c . "$T/log")" 0

echo "-- o shim desligado (meow compositor desativar) com o .estado antigo de /var/lib"
rm -f "$D/.local/bin/cosmic-comp"
printf '#!/bin/sh\n' > "$T/fabrica"; chmod 755 "$T/fabrica"
printf 'versao=0.1~velha\ngravado=2026-09-24T04:07:05-03:00\nreq AURORA-X t.patch presente\n' > "$T/estado-velho"
versoes cosmic-comp=0.1~h cosmic-files=1.10~b
: > "$T/log"; CP_ESTADO="$T/estado-velho" CP_BIN="$T/fabrica" doctor; rc=$?
igual "sem shim e com o .estado velho: a linha patches é escolha, o doctor não diverge (rc 0)" "$rc" 0
grep -q 'o conserto recompila' "$T/doc.saida" && falha "a linha patches promete um conserto que não converge"
: > "$T/log"; CP_ESTADO="$T/estado-velho" CP_BIN="$T/fabrica" doctor --consertar; rc=$?
igual "e o --consertar não compila nada" "$(grep -c . "$T/log")" 0
grep -q 'continua fora' "$T/doc.saida" && { falha "a linha patches ficou fora depois do conserto"; sed 's/^/        /' "$T/doc.saida"; }

echo
echo "== 3. o caminho de volta do docs/MANUTENCAO.md"
V="$T/volta"; mkdir -p "$V/.local/bin"; echo nosso > "$V/.local/bin/cosmic-files"
volta() { env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY \
  HOME="$V" PATH="$T/bin:$PATH" NO_COLOR=1 FILES_MENU=nao "$RAIZ/scripts/files_menu.sh" "$@" >/dev/null 2>&1; }
volta --conferir; igual "FILES_MENU=nao com o nosso no lugar: a conferência diverge" "$?" 1
volta aplicar
[ -e "$V/.local/bin/cosmic-files" ] && falha "o conserto não tirou o nosso" || ok "o conserto tira o nosso"
volta --conferir; igual "e a conferência seguinte fica em 0" "$?" 0

grep -v "^recusado: sudo -n -l$" "$T/recusados" 2>/dev/null | grep -q . && { falha "algo chamou um comando recusado:"; sed "s/^/        /" "$T/recusados"; }

echo
if [ "$falhas" = 0 ]; then echo "garantir-builds: tudo certo"; exit 0; fi
echo "garantir-builds: $falhas falha(s)"; exit 1

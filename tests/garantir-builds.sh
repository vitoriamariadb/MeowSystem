#!/usr/bin/env bash
# garantir-builds.sh — o compositor e o menu do cosmic-files têm build para a
# versão instalada, sempre, e a segunda passagem não escreve nada? (P81)
#
# POR QUE ESTE ARQUIVO NASCEU EM 15/10/2026
#   O apt das 20:14 trouxe o COSMIC 1.10. O pós-apt das 20:15 recompilou o
#   menu do cosmic-files e PULOU o compositor («o shim do compositor está
#   desligado — sem build»), e gravou a versão como vista: nenhum gatilho
#   voltaria a ela. A P81 tirou a decisão de cada gatilho e a pôs numa função
#   só, que olha o artefato: `scripts/garantir_builds.sh`.
#
# O QUE ESTE TESTE COBRA
#   1. a função: compila o que falta, e só isso; o shim desligado não impede;
#      o `ruim` não se refaz; FILES_MENU="nao" não compila o menu; o `req` que
#      não entra (degrau 4) é regra e sai 0, a falha de verdade sai 2; o seco
#      não compila; duas passagens juntas compilam uma vez (flock); e a
#      segunda passagem não escreve um byte.
#
# HOME, estado e casa de brinquedo; os dois builds são registros de uma linha
# que deixam o artefato que o de verdade deixaria. Nada de apt, cargo, sudo,
# systemd nem rede: os falsos do PATH recusam.
#   0 = passou · 1 = falhou
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

mkdir -p "$T/bin" "$T/home/.local/bin" "$T/home/.config/meow"
for c in sudo pkexec apt apt-get systemctl systemd-run pkill killall notify-send cargo make; do
  printf '#!/bin/sh\necho "recusado: %s $*" >> "%s/recusados"\nexit 1\n' "$c" "$T" > "$T/bin/$c"
  chmod 755 "$T/bin/$c"
done
# O dpkg-query falso responde às duas perguntas do projeto: a lista com
# `${Package}` (pacote, versão, status) e a versão nua de um pacote.
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
versoes() { # pares pacote=versão
  : > "$T/dpkg.tsv"; local x
  for x in "$@"; do printf '%s\t%s\tinstalled\n' "${x%%=*}" "${x#*=}" >> "$T/dpkg.tsv"; done
}
CASA="$T/home/.local/libexec/meow/cosmic-comp"
ESTADO="$T/home/.local/state/meowsystem"
# O compositor falso: deixa o binário e o `estado` com o `req` presente, como
# o `compilar` de verdade. `comp-req-falha` simula o degrau 4 (grava a matriz
# e sai 2); `comp-falha`, um erro de verdade.
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
rm -f "$T/comp-req-falha"

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

[ -s "$T/recusados" ] && { falha "algo chamou um comando recusado:"; sed 's/^/        /' "$T/recusados"; }

echo
if [ "$falhas" = 0 ]; then echo "garantir-builds: tudo certo"; exit 0; fi
echo "garantir-builds: $falhas falha(s)"; exit 1

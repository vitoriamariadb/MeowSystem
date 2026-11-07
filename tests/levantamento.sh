#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

CASA="$T/casa"; F="$T/falso"; ESTADO="$CASA/.local/state/meowsystem"; PINOS="$T/pinos"
mkdir -p "$CASA/.cache/meowsystem" "$ESTADO/extensoes/soneca" "$F" "$PINOS" "$T/mundo"
printf 'NOME="Soneca"\n' > "$PINOS/soneca.pino"
VER_FILES="1.11.0~1~24.04~aaaaaaa"; VER_PORTAL="1.11.0~2~24.04~bbbbbbb"

cat > "$F/df" <<FIM
#!/bin/sh
printf 'Sist.\tTam\tUsado\tDisp\tUso\tMont\n/dev/x 100 1 %s 1%% /\n' "\$(cat "$T/mundo/livre")"
FIM
cat > "$F/getent" <<FIM
#!/bin/sh
grep -qxF "\$2" "$T/mundo/sem-nome" 2>/dev/null && exit 2
echo "1.2.3.4 \$2"
FIM
cat > "$F/sudo" <<FIM
#!/bin/sh
[ -f "$T/mundo/ponte-pede-senha" ] && exit 1
[ "\$1" = -n ] && shift && exec "\$@"
exit 1
FIM
printf '#!/bin/sh\nexit 0\n' > "$T/ponte"
cat > "$F/dpkg-query" <<FIM
#!/bin/sh
for a in "\$@"; do p="\$a"; done
case "\$p" in
  cosmic-files) printf '%s' "$VER_FILES" ;;
  xdg-desktop-portal-cosmic) printf '%s' "$VER_PORTAL+0~hefesto1" ;;
  *) exit 1 ;;
esac
FIM
cat > "$F/apt-cache" <<FIM
#!/bin/sh
[ "\$1" = showsrc ] || exit 1
case "\$2" in
  cosmic-files) [ -f "$T/mundo/files-saiu" ] && printf 'Package: cosmic-files\nVersion: 1.11.0~9~24.04~ccccccc\n' || printf 'Package: cosmic-files\nVersion: $VER_FILES\n' ;;
  xdg-desktop-portal-cosmic) printf 'Package: xdg-desktop-portal-cosmic\nVersion: $VER_PORTAL\n' ;;
esac
FIM
cat > "$F/apt" <<FIM
#!/bin/sh
echo "Listing..."
[ -f "$T/mundo/fila" ] && printf 'cosmic-files/noble 2 amd64 [upgradable from: 1]\ncosmic-term/noble 2 amd64 [upgradable from: 1]\n'
exit 0
FIM
cat > "$T/garantir" <<FIM
#!/bin/sh
m=ok; [ -f "$T/mundo/menu-pendente" ] && m=pendente
printf 'compositor_versao=0.1\ncompositor_estado=ok\nmenu_versao=$VER_FILES\nmenu_estado=%s\ngraficos_versao=x\ngraficos_estado=ok\nconstruindo=nao\n' "\$m"
FIM
cat > "$T/doctor" <<FIM
#!/bin/sh
echo "  ok   tema        em dia"
[ -f "$T/mundo/doctor-diverge" ] && echo "  !!   forma       a margem passa do limite"
exit 0
FIM
chmod 755 "$F"/* "$T/ponte" "$T/garantir" "$T/doctor"

levantar() {
  env -i PATH="$F:/usr/bin:/bin" HOME="$CASA" NO_COLOR=1 LC_ALL=C.UTF-8 MEOW_RAIZ="$RAIZ" \
    MEOW_ESTADO="$ESTADO" MEOW_CACHE="$CASA/.cache/meowsystem" MEOW_PONTE="$T/ponte" \
    LV_GARANTIR="$T/garantir" LV_DOCTOR="$T/doctor" LV_PINOS="$PINOS" LV_GIT=0 LV_ESPACO_KB=1000 \
    bash "$RAIZ/scripts/levantamento.sh" > "$T/saida" 2>&1
}
foto() { (cd "$CASA" && find . -printf '%p %s %T@ %i\n' | sort; find . -type f -exec sha256sum {} + | sort) | sha256sum; }

printf '\n1. a máquina limpa\n'
echo 5000 > "$T/mundo/livre"
levantar; rc=$?
confere "sai 0 e diz que não há nada a resolver" '[ "$rc" = 0 ] && grep -q "nada a resolver" "$T/saida" && ! grep -q "!!" "$T/saida"' "$(cat "$T/saida")"
confere "a versão do rebuild local é lida pela de base" 'grep -q "xdg-desktop-portal-cosmic $VER_PORTAL no repositório" "$T/saida"' "$(cat "$T/saida")"

printf '\n2. um problema em cada item: todos na lista, sem parar no primeiro\n'
echo 10 > "$T/mundo/livre"
echo static.crates.io > "$T/mundo/sem-nome"
: > "$T/mundo/ponte-pede-senha"; : > "$T/mundo/files-saiu"; : > "$T/mundo/fila"
: > "$T/mundo/menu-pendente"; : > "$T/mundo/doctor-diverge"
: > "$ESTADO/extensoes/soneca/falhou"
printf 'error: failed to download from https://static.crates.io/x\n' > "$ESTADO/extensoes/soneca/compilar.log"
f0="$(foto)"; sleep 1
levantar; rc=$?
f1="$(foto)"
confere "sai 1" '[ "$rc" = 1 ]' "$(cat "$T/saida")"
confere "o disco curto" 'grep -q "disco: .* e o build do compositor pede" "$T/saida"' "$(cat "$T/saida")"
confere "o nome que não responde" 'grep -q "rede: sem resposta de static.crates.io" "$T/saida"' "$(cat "$T/saida")"
confere "a ponte que pede senha" 'grep -q "ponte root: instalada, e o sudo dela pede senha" "$T/saida"' "$(cat "$T/saida")"
confere "o fonte que saiu do repositório" 'grep -q "já não serve o fonte do cosmic-files $VER_FILES" "$T/saida"' "$(cat "$T/saida")"
confere "a fila do apt do COSMIC" 'grep -q "apt: 2 pacote(s) do COSMIC" "$T/saida"' "$(cat "$T/saida")"
confere "o build pendente" 'grep -q "builds: o menu do Arquivos está pendente" "$T/saida"' "$(cat "$T/saida")"
confere "o applet preso, pelo nome e com o motivo" 'grep -q "applets: Soneca não compilou com o pino atual — faltou rede" "$T/saida"' "$(cat "$T/saida")"
confere "a linha do doctor" 'grep -q "doctor: forma: a margem passa do limite" "$T/saida"' "$(cat "$T/saida")"
confere "a conta fecha: 8 achados" 'grep -q "8 achado(s)" "$T/saida"' "$(cat "$T/saida")"

printf '\n3. só lê\n'
confere "o HOME ficou idêntico (nome, tamanho, hora, inode e conteúdo)" '[ "$f1" = "$f0" ]'
confere "nenhuma linha manda digitar" '! grep -qiE "rode |digite|execute|sudo -|meow [a-z]+ --" "$T/saida"' "$(cat "$T/saida")"

printf '\n4. o comando está no meow, na ajuda e no zsh\n'
confere "o meow despacha o levantamento" 'grep -q "levantamento)" "$RAIZ/bin/meow" && grep -q "meow levantamento" "$RAIZ/bin/meow"'
confere "e o zsh completa" 'grep -q "levantamento:" "$RAIZ/assets/zsh/_meow"'

[ "$falhas" = 0 ] && printf '\nok: o levantamento lista tudo de uma vez e não escreve nada\n' && exit 0
printf '\n%s falha(s)\n' "$falhas"; exit 1

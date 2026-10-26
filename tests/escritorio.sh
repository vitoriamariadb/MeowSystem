#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ES="$RAIZ/scripts/escritorio.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1"; fi; }

CASA="$T/casa"; ESTADO="$CASA/.local/state/meowsystem"; FLATPAK="$CASA/.local/share/flatpak"
PONTE_DIR="$T/ponte"; DPKG="$T/dpkg"; APT_LOG="$T/apt.log"; FLATPAK_LOG="$T/flatpak.log"; SUDO_LOG="$T/sudo.log"
OO="$FLATPAK/app/org.onlyoffice.desktopeditors"
mkdir -p "$T/bin" "$CASA" "$ESTADO" "$PONTE_DIR" "$T/etc-flatpak" "$T/sistema-flatpak"
: > "$APT_LOG"; : > "$FLATPAK_LOG"; : > "$SUDO_LOG"
printf '%s\n' 'ii  libreoffice-core' 'ii  libreoffice-writer' 'rc  libreoffice-calc' 'un  libreoffice-velho' 'ii  python3-uno' 'ii  vim' > "$DPKG"
cp "$DPKG" "$T/dpkg-original"
ATALHO="$CASA/.local/share/applications/libreoffice-startcenter.desktop"
mkdir -p "${ATALHO%/*}"; printf '[Desktop Entry]\nName=LibreOffice\nNoDisplay=true\n' > "$ATALHO"
cp "$ATALHO" "$T/atalho-original"

cat > "$T/bin/dpkg-query" <<'FIM'
#!/bin/sh
# dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'libreoffice*'
while read -r st nome; do
  case "$nome" in libreoffice*) printf '%s  %s\n' "$st" "$nome" ;; esac
done < "$DPKG_FALSO"
FIM
cat > "$T/bin/apt-get" <<'FIM'
#!/bin/sh
echo "apt-get $*" >> "$APT_LOG"
# No purge o apt simula com `Purg`, e leva junto quem depende do libreoffice-core.
if [ "$1" = "-s" ]; then
  shift 2
  for p in "$@"; do [ "$p" = "${APT_SEM:-}" ] || echo "${APT_VERBO:-Purg} $p [1:24.2]"; done
  case " $* " in *" libreoffice-core "*) grep -q "^ii  python3-uno$" "$DPKG_FALSO" && echo "Purg python3-uno [1:24.2]" ;; esac
  [ -f "$APT_DEPENDENTE" ] && echo "Purg unoconv [0.9]"
  exit 0
fi
acao="$1"; shift; [ "$acao" = install ] && while [ "${1#-}" != "$1" ]; do shift; done
[ "$acao" = purge ] && while [ "${1#-}" != "$1" ]; do shift; done
[ "$acao" = purge ] && case " $* " in *" libreoffice-core "*) set -- "$@" python3-uno ;; esac
for p in "$@"; do
  grep -v " $p\$" "$DPKG_FALSO" > "$DPKG_FALSO.n"; mv "$DPKG_FALSO.n" "$DPKG_FALSO"
  [ "$acao" = install ] && echo "ii  $p" >> "$DPKG_FALSO"
done
exit 0
FIM
cat > "$T/bin/flatpak" <<'FIM'
#!/bin/sh
echo "$*" >> "$FLATPAK_LOG"
case "$1" in
  install) [ -f "$FLATPAK_FALHA" ] && exit 1
           for a in "$@"; do id="$a"; done
           mkdir -p "$FLATPAK_USER_DIR/app/$id/x86_64/stable/abc/files" && ln -s abc "$FLATPAK_USER_DIR/app/$id/x86_64/stable/active" ;;
esac
exit 0
FIM
cat > "$T/bin/sudo" <<FIM
#!/bin/sh
if [ "\$1" = "-n" ] && [ "\$2" = "$PONTE_DIR/ponte_root.sh" ] && [ -f "$T/ponte-ligada" ]; then shift; exec "\$@"; fi
echo "sudo \$*" >> "$SUDO_LOG"; exit 1
FIM
chmod 755 "$T/bin/"*
sed -e 's#^export PATH=.*#:#' -e 's#-o root -g root##' -e 's#^anotar() {#anotar() { return 0#' \
    -e "s#^PERFIL=.*#PERFIL=\"$PONTE_DIR/perfil\"#" -e "s#^LIBRE_REMOVIDOS=.*#LIBRE_REMOVIDOS=\"$PONTE_DIR/var/removidos\"#" \
    "$RAIZ/scripts/ponte_root.sh" > "$PONTE_DIR/ponte_root.sh"
chmod 755 "$PONTE_DIR/ponte_root.sh"
printf 'lar=%s\n' "$CASA" > "$PONTE_DIR/perfil"

rodar() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
      FLATPAK_USER_DIR="$FLATPAK" FLATPAK_SYSTEM_DIR="$T/sistema-flatpak" FLATPAK_CONFIG_DIR="$T/etc-flatpak" \
      FLATPAK_LOG="$FLATPAK_LOG" FLATPAK_FALHA="$T/flatpak-falha" DPKG_FALSO="$DPKG" APT_LOG="$APT_LOG" \
      APT_DEPENDENTE="$T/dependente" MEOW_PONTE="$PONTE_DIR/ponte_root.sh" bash "$ES" "$@"
}
ponte() {
  env -i PATH="$T/bin:/usr/bin:/bin" DPKG_FALSO="$DPKG" APT_LOG="$APT_LOG" APT_DEPENDENTE="$T/dependente" \
      APT_SEM="${APT_SEM:-}" APT_VERBO="${APT_VERBO:-}" \
      bash "$PONTE_DIR/ponte_root.sh" "$1"
}
libre() { sed -n 's/^[a-z][ic]  \(libreoffice.*\)$/\1/p' "$DPKG" | tr '\n' ' '; }
foto() { find "$CASA" "$T/dpkg" -type f -printf '%p %s %T@\n' 2>/dev/null | sort; md5sum < "$DPKG"; }
chamadas_apt() { grep -c '' "$APT_LOG"; }
chamadas_fp() { grep -c '' "$FLATPAK_LOG"; }

printf '\n1. o doctor vê e não escreve\n'
antes="$(foto)"
saida="$(rodar conferir onlyoffice)"; rc=$?
confere "o OnlyOffice que falta: sai 1, diz de onde viria e não chama o flatpak" '[ "$rc" = 1 ] && grep -q Flathub <<< "$saida" && [ "$(chamadas_fp)" = 0 ]'
saida="$(rodar conferir libreoffice)"; rc=$?
confere "o LibreOffice instalado: sai 1, com a conta de pacotes, e não chama o apt" '[ "$rc" = 1 ] && grep -q "3 pacotes" <<< "$saida" && [ "$(chamadas_apt)" = 0 ]'
rodar conferir >/dev/null
confere "nada foi escrito" '[ "$antes" = "$(foto)" ]'

printf '\n2. o LibreOffice só sai com o OnlyOffice no lugar\n'
saida="$(rodar aplicar libreoffice)"; rc=$?
confere "sem OnlyOffice o aplicar sai 3 e o LibreOffice fica" '[ "$rc" = 3 ] && cmp -s "$DPKG" "$T/dpkg-original" && [ "$(chamadas_apt)" = 0 ]'
touch "$T/flatpak-falha"
saida="$(rodar aplicar)"; rc=$?
confere "o flatpak sem rede: erro 2, e o LibreOffice fica" '[ "$rc" = 2 ] && cmp -s "$DPKG" "$T/dpkg-original" && [ ! -e "$OO" ]'
confere "a frase não manda digitar" '! grep -qiE "digite|rode " <<< "$saida"'
rm -f "$T/flatpak-falha"; : > "$FLATPAK_LOG"

printf '\n3. o OnlyOffice vem do Flathub, no usuário\n'
saida="$(rodar aplicar onlyoffice)"; rc=$?
confere "aplicar sai 1 e instala pelo --user, sem senha" \
  '[ "$rc" = 1 ] && grep -q "^remote-add --user --if-not-exists flathub " "$FLATPAK_LOG" && grep -q "^install --user -y --noninteractive flathub org.onlyoffice.desktopeditors$" "$FLATPAK_LOG" && [ ! -s "$SUDO_LOG" ]'
n="$(chamadas_fp)"
rodar aplicar onlyoffice >/dev/null; rc=$?
confere "a segunda passada não escreve nem chama o flatpak" '[ "$rc" = 0 ] && [ "$(chamadas_fp)" = "$n" ]'

printf '\n4. sem a ponte, o LibreOffice fica e vira botão\n'
saida="$(rodar aplicar libreoffice)"; rc=$?
confere "sai 3, sem pedir senha, e nada sai do dpkg" '[ "$rc" = 3 ] && cmp -s "$DPKG" "$T/dpkg-original" && [ "$(chamadas_apt)" = 0 ] && grep -q "^sudo -n .*estado" "$SUDO_LOG"'
confere "vira a pendência libreoffice-sistema, sem mandar digitar" \
  'grep -q "^libreoffice-sistema	" "$ESTADO/pendencias.tsv" && ! grep -qiE "digite|rode " <<< "$saida"'

printf '\n5. com a ponte, o apt tira só o LibreOffice\n'
: > "$T/ponte-ligada"
saida="$(rodar aplicar libreoffice)"; rc=$?
confere "aplicar sai 1" '[ "$rc" = 1 ]'
confere "saem os três pacotes (o de configuração sobrada também), a ponte UNO vai junto e o vizinho fica" \
  '[ -z "$(libre)" ] && ! grep -q "python3-uno" "$DPKG" && grep -q "^ii  vim$" "$DPKG" && grep -q "^apt-get purge -y libreoffice-core libreoffice-writer libreoffice-calc$" "$APT_LOG"'
confere "os nomes ficam guardados para a volta, com o que o apt levou junto" \
  '[ "$(cat "$ESTADO/libreoffice-antes.tsv")" = "$(printf "libreoffice-calc\nlibreoffice-core\nlibreoffice-writer\npython3-uno")" ]'
confere "a ponte grava, do lado dela, a mesma lista para a volta" \
  '[ "$(cat "$PONTE_DIR/var/removidos")" = "$(printf "libreoffice-calc\nlibreoffice-core\nlibreoffice-writer\npython3-uno")" ]'
confere "o atalho da casa sai da lista de ocultos, com cópia" \
  '[ ! -e "$ATALHO" ] && cmp -s "$ESTADO/libreoffice-atalhos/libreoffice-startcenter.desktop" "$T/atalho-original"'
confere "a pendência sai" '! grep -q "^libreoffice-sistema	" "$ESTADO/pendencias.tsv"'
cp "$DPKG" "$T/dpkg-limpo"; n="$(chamadas_apt)"; m="$(md5sum < "$ESTADO/libreoffice-antes.tsv")"
rodar aplicar >/dev/null; rc=$?
confere "a segunda passada, dos dois, não escreve: sai 0, sem apt e sem guarda nova" \
  '[ "$rc" = 0 ] && [ "$(chamadas_apt)" = "$n" ] && cmp -s "$DPKG" "$T/dpkg-limpo" && [ "$m" = "$(md5sum < "$ESTADO/libreoffice-antes.tsv")" ]'
confere "conferido, o doctor fica verde" 'rodar conferir >/dev/null'

printf '\n6. a ponte recusa o que não é dela\n'
cp "$T/dpkg-original" "$DPKG"; : > "$APT_LOG"; touch "$T/dependente"
ponte libreoffice-remover >/dev/null 2>&1; rc=$?
confere "se o apt levasse outro pacote junto (a linha Purg da simulação), recusa inteiro e não purga" '[ "$rc" != 0 ] && ! grep -q "^apt-get purge" "$APT_LOG" && cmp -s "$DPKG" "$T/dpkg-original"'
rm -f "$T/dependente"
saida="$(ponte libreoffice-remover 2>/dev/null)"; rc=$?
confere "o stdout da ponte é só a lista do que saiu" \
  '[ "$rc" = 0 ] && [ "$saida" = "$(printf "libreoffice-calc\nlibreoffice-core\nlibreoffice-writer\npython3-uno")" ]'
cp "$T/dpkg-original" "$DPKG"; : > "$APT_LOG"
APT_VERBO=Remv ponte libreoffice-remover >/dev/null 2>&1; rc=$?
confere "a simulação que diz Remv (e não Purg) também vale" '[ "$rc" = 0 ] && grep -q "^apt-get purge -y" "$APT_LOG"'
cp "$T/dpkg-original" "$DPKG"; : > "$APT_LOG"
APT_SEM=libreoffice-writer ponte libreoffice-remover >/dev/null 2>&1; rc=$?
confere "se o plano do apt não tira um pacote pedido, recusa inteiro e não purga" \
  '[ "$rc" != 0 ] && ! grep -q "^apt-get purge" "$APT_LOG" && cmp -s "$DPKG" "$T/dpkg-original"'
cp "$T/dpkg-limpo" "$DPKG"; : > "$APT_LOG"; cp "$PONTE_DIR/var/removidos" "$T/removidos-bom"
printf 'vim\n' | ponte libreoffice-devolver >/dev/null 2>&1; rc=$?
confere "devolver não lê nome de quem chama: o vim pedido no stdin não entra" \
  '[ "$rc" = 0 ] && ! grep -q "vim" "$APT_LOG" && grep -q "^apt-get install -y --no-install-recommends libreoffice-calc libreoffice-core libreoffice-writer python3-uno$" "$APT_LOG"'
confere "a lista da ponte sai depois da volta" '[ ! -e "$PONTE_DIR/var/removidos" ]'
cp "$T/dpkg-limpo" "$DPKG"; : > "$APT_LOG"
printf 'libreoffice-core\n' | ponte libreoffice-devolver >/dev/null 2>&1; rc=$?
confere "devolver sem a lista da ponte recusa, mesmo com nome bom no stdin" '[ "$rc" != 0 ] && [ "$(chamadas_apt)" = 0 ]'
printf 'libreoffice-core\nvim\n' > "$PONTE_DIR/var/removidos"
ponte libreoffice-devolver </dev/null >/dev/null 2>&1; rc=$?
confere "devolver recusa a lista com pacote que não é do LibreOffice" '[ "$rc" != 0 ] && ! grep -q "^apt-get install" "$APT_LOG"'
printf 'libreoffice-core\nlibreoffice;x\n' > "$PONTE_DIR/var/removidos"
ponte libreoffice-devolver </dev/null >/dev/null 2>&1; rc=$?
confere "devolver recusa nome com caractere de shell, antes de qualquer apt" '[ "$rc" != 0 ] && ! grep -q "^apt-get install" "$APT_LOG"'
: > "$PONTE_DIR/var/removidos"
ponte libreoffice-devolver </dev/null >/dev/null 2>&1; rc=$?
confere "devolver com a lista vazia recusa" '[ "$rc" != 0 ] && ! grep -q "^apt-get install" "$APT_LOG"'
cp "$T/removidos-bom" "$PONTE_DIR/var/removidos"
confere "a regra de sudo nomeia os dois verbos, sem curinga" \
  'r="$(SUDO_USER=alguem bash "$RAIZ/scripts/ponte_root.sh" regra-sudo)"; grep -q "ponte_root.sh libreoffice-remover, " <<< "$r" && grep -q "ponte_root.sh libreoffice-devolver, " <<< "$r" && ! grep -q "libreoffice-[a-z]* \*" <<< "$r"'
confere "a ponte não aceita argumento" '! bash "$PONTE_DIR/ponte_root.sh" libreoffice-remover x >/dev/null 2>&1'

printf '\n7. o desinstalador devolve o LibreOffice\n'
cp "$T/dpkg-limpo" "$DPKG"; : > "$APT_LOG"; rm -f "$T/ponte-ligada"
saida="$(rodar reverter 2>&1)"; rc=$?
confere "sem ponte: sai 0, avisa onde a lista ficou e não pede senha" '[ "$rc" = 0 ] && [ -f "$ESTADO/libreoffice-antes.tsv" ] && grep -q libreoffice-antes <<< "$saida" && [ "$(chamadas_apt)" = 0 ]'
confere "o atalho da casa volta byte a byte, mesmo sem ponte" 'cmp -s "$ATALHO" "$T/atalho-original" && [ ! -e "$ESTADO/libreoffice-atalhos" ]'
: > "$T/ponte-ligada"
saida="$(rodar reverter)"; rc=$?
confere "com a ponte: os três e a ponte UNO voltam, a guarda sai" \
  '[ "$rc" = 0 ] && [ "$(libre)" = "libreoffice-calc libreoffice-core libreoffice-writer " ] && grep -q "^ii  python3-uno$" "$DPKG" && [ ! -e "$ESTADO/libreoffice-antes.tsv" ]'
n="$(chamadas_apt)"
rodar reverter >/dev/null; rc=$?
confere "reverter de novo não faz nada" '[ "$rc" = 0 ] && [ "$(chamadas_apt)" = "$n" ]'
confere "o lib/desinstalar.sh chama o reverter antes de tirar a ponte" \
  'a="$(grep -n "escritorio.sh\" reverter" "$RAIZ/lib/desinstalar.sh" | head -n1 | cut -d: -f1)"; b="$(grep -n "sudo rm -f \"\$regra_ponte\"" "$RAIZ/lib/desinstalar.sh" | head -n1 | cut -d: -f1)"; [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]'

printf '\n8. sem flatpak, nada a trazer e nada a tirar\n'
cp "$T/dpkg-original" "$DPKG"; rm -rf "$FLATPAK/app"; : > "$APT_LOG"
mkdir -p "$T/sem-flatpak"
for b in /usr/bin/*; do case "${b##*/}" in flatpak|dpkg-query|apt-get|sudo) ;; *) ln -s "$b" "$T/sem-flatpak/${b##*/}" 2>/dev/null ;; esac; done
saida="$(env -i PATH="$T/sem-flatpak" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 FLATPAK_USER_DIR="$FLATPAK" FLATPAK_SYSTEM_DIR="$T/sistema-flatpak" FLATPAK_CONFIG_DIR="$T/etc-flatpak" bash "$ES" aplicar)"; rc=$?
confere "sem flatpak no PATH sai 3 e não escreve" '[ "$rc" = 3 ] && [ ! -e "$FLATPAK/app" ]'

printf '\n9. a fiação: etapa, doctor e ponte\n'
confere "a etapa está na lista do instalador, antes da dos apps" \
  'l="$(sed -n "/local etapas=(/,/)/p" "$RAIZ/install.sh" | tr -s " \n" "\n\n")"; a="$(grep -n "^etapa_escritorio$" <<< "$l" | cut -d: -f1)"; b="$(grep -n "^etapa_apps$" <<< "$l" | cut -d: -f1)"; [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]'
confere "o doctor tem o par chk_/fix_ dos dois itens, e o OnlyOffice vem antes dos apps" \
  'for n in onlyoffice libreoffice; do grep -q "^chk_$n()" "$RAIZ/bin/meow" && grep -q "^fix_$n()" "$RAIZ/bin/meow" && grep -q "^VERIFICAVEIS=.* $n .*apps " "$RAIZ/bin/meow" || exit 1; done'
confere "sem ponte, o doctor não promete tirar o LibreOffice" 'grep -q "SEM_CONSERTO=\".* libreoffice \"" "$RAIZ/bin/meow" && grep -q "^  \[libreoffice\]=" "$RAIZ/bin/meow"'
confere "a pendência tem botão no painel" 'grep -q "\"libreoffice-sistema\": \"instalar\"" "$RAIZ/app/servidor.py"'

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'escritorio: tudo verde\n'; exit 0; fi
printf 'escritorio: %s falha(s)\n' "$falhas"; exit 1

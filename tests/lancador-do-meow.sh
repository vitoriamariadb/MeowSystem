#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1"; fi; }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

CASA="$T/casa"; APPS="$CASA/.local/share/applications"; ESTADO="$CASA/.local/state/meowsystem"
FLAT="$T/flatpak/exports/share"; LOCAL="$T/local/share"; SIS="$T/sistema/applications"
mkdir -p "$T/bin" "$APPS" "$ESTADO" "$FLAT/applications" "$LOCAL/applications" "$SIS" "$T/vazio"
for c in sudo pkexec; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/recusas.log"\nexit 1\n' "$c" "$T" > "$T/bin/$c"; chmod 755 "$T/bin/$c"
done
printf '#!/bin/sh\n[ "$1" = list ] && printf "org.example.Vivo\\n"\nexit 0\n' > "$T/bin/flatpak"
printf '#!/bin/sh\nfor d; do :; done; printf "[MIME Cache]\\n" > "$d/mimeinfo.cache"; echo "$d" >> "%s/udd.log"\n' "$T" \
  > "$T/bin/update-desktop-database"
chmod 755 "$T/bin/flatpak" "$T/bin/update-desktop-database"

rodar() {
  local s="$1"; shift
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
      XDG_DATA_DIRS="$FLAT:$LOCAL:$T/sistema" MEOW_APLICATIVOS_SISTEMA="$SIS" \
      MEOW_APLICATIVOS_FLATPAK="$T/vazio" bash "$RAIZ/scripts/$s" "$@"
}
foto() { (cd "$T" && find casa flatpak local sistema -printf '%p %s %T@\n' | sort); }
desktop() {
  local a="$1"; shift
  { printf '[Desktop Entry]\n'; printf '%s\n' "$@"; } > "$a"
}

printf '\n1. a janela que a dock não casa (pontes de app_id)\n'
desktop "$FLAT/applications/com.boxy_svg.BoxySVG.desktop" 'Type=Application' 'Name=Boxy SVG' \
  'Exec=/usr/bin/flatpak run --command=boxy-svg com.boxy_svg.BoxySVG @@ %f @@' 'Icon=com.boxy_svg.BoxySVG' \
  'StartupWMClass=Boxy SVG' 'X-Flatpak=com.boxy_svg.BoxySVG'
antes="$(foto)"
saida="$(rodar appid_dock.sh --conferir 2>&1)"; rc=$?
confere "o conferir vê as duas pontes do Boxy e não escreve" \
  '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q "2 a criar" && [ "$antes" = "$(foto)" ]'
rodar appid_dock.sh --aplicar >/dev/null 2>&1; rc=$?
p1="$APPS/meow-janela-boxy-svg-boxy-svg-linux.desktop"; p2="$APPS/meow-janela-boxy-svg-boxy-svg.desktop"
confere "o aplicar escreve as duas pontes, escondidas e com o app_id medido" \
  '[ "$rc" = 1 ] && grep -qx "StartupWMClass=boxy-svg-boxy-svg-linux" "$p1" && grep -qx "StartupWMClass=boxy-svg-boxy-svg" "$p2" && grep -qx "NoDisplay=true" "$p2"'
antes="$(foto)"
rodar appid_dock.sh --aplicar >/dev/null 2>&1; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ] && [ "$antes" = "$(foto)" ]'
rodar appid_dock.sh --reverter >/dev/null 2>&1
confere "o reverter tira as pontes" '[ ! -e "$p1" ] && [ ! -e "$p2" ]'
confere "um mapa só: o wmclass.map saiu" '[ ! -e "$RAIZ/assets/apps/wmclass.map" ]'
rm -f "$FLAT/applications/com.boxy_svg.BoxySVG.desktop"

printf '\n2. o lançador órfão e o mimeinfo.cache velho\n'
desktop "$APPS/morto.desktop" 'Type=Application' 'Name=Morto' 'Exec=/nao/existe/morto %U'
desktop "$APPS/flatpak-morto.desktop" 'Type=Application' 'Name=Flatpak Morto' 'Exec=/usr/bin/flatpak run --branch=stable org.example.Morto @@u %u @@'
desktop "$APPS/flatpak-vivo.desktop" 'Type=Application' 'Name=Flatpak Vivo' 'Exec=/usr/bin/flatpak run org.example.Vivo'
desktop "$APPS/embrulhado.desktop" 'Type=Application' 'Name=Embrulhado' 'Exec=env FOO=1 /nao/existe/outro'
desktop "$APPS/vivo.desktop" 'Type=Application' 'Name=Vivo' 'Exec=sh -c "cd /nao/existe && ./x"'
desktop "$APPS/nosso.desktop" 'Type=Application' 'Name=Nosso' 'Exec=/nao/existe/jogo' 'X-MeowSystem=jogo-steam'
mkdir -p "$T/meu app"; printf '#!/bin/sh\n' > "$T/meu app/run"; chmod 755 "$T/meu app/run"
desktop "$APPS/espaco.desktop" 'Type=Application' 'Name=Com Espaço' "Exec=\"$T/meu app/run\" %U"
cp -a "$APPS/morto.desktop" "$T/morto-original.desktop"
printf '[MIME Cache]\n' > "$APPS/mimeinfo.cache"; touch -d '2 days ago' "$APPS/mimeinfo.cache"
antes="$(foto)"
saida="$(rodar lancador.sh --conferir 2>&1)"; rc=$?
confere "o conferir vê os três órfãos, na cabeça da saída, e não escreve" \
  '[ "$rc" = 1 ] && printf "%s\n" "$saida" | head -1 | grep -q "3 lançador" && [ "$antes" = "$(foto)" ]'
confere "o vivo, o embrulho de shell, o caminho com espaço entre aspas e o que é do MeowSystem não são órfãos" \
  '! printf "%s" "$saida" | grep -qE "Flatpak Vivo|  Vivo|Nosso|Com Espaço"'
rodar lancador.sh --aplicar >/dev/null 2>&1; rc=$?
Q="$ESTADO/lancador-quarentena"
confere "o aplicar leva os três para a quarentena, fora de applications/" \
  '[ "$rc" = 1 ] && [ ! -e "$APPS/morto.desktop" ] && [ ! -e "$APPS/flatpak-morto.desktop" ] && [ ! -e "$APPS/embrulhado.desktop" ] && [ -f "$Q/morto.desktop" ] && [ -f "$Q/embrulhado.desktop" ]'
confere "e refaz o mimeinfo.cache do home" '[ "$(grep -c . "$T/udd.log")" = 1 ] && [ -z "$(find "$APPS" -maxdepth 1 -name "*.desktop" -newer "$APPS/mimeinfo.cache")" ]'
antes="$(foto)"
rodar lancador.sh --aplicar >/dev/null 2>&1; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ] && [ "$antes" = "$(foto)" ]'
sleep 1; touch "$APPS/vivo.desktop"
rodar lancador.sh --conferir >/dev/null 2>&1; rc=$?
confere "um lançador mais novo que a cache faz o conferir acusar" '[ "$rc" = 1 ]'
rodar lancador.sh --aplicar >/dev/null 2>&1
rodar lancador.sh --reverter >/dev/null 2>&1; rc=$?
confere "o reverter devolve os três byte a byte" \
  '[ "$rc" = 1 ] && cmp -s "$APPS/morto.desktop" "$T/morto-original.desktop" && [ -f "$APPS/flatpak-morto.desktop" ] && [ -f "$APPS/embrulhado.desktop" ] && [ ! -e "$Q/morto.desktop" ]'
rm -f "$APPS"/*.desktop "$APPS/mimeinfo.cache"; rm -rf "$Q"

printf '\n2b. sem update-desktop-database, a cache que ninguém refaz não vira «mexeu» a cada passada\n'
mkdir -p "$T/semudd"
for f in /usr/bin/* /bin/*; do
  [ "${f##*/}" = update-desktop-database ] || ln -sf "$f" "$T/semudd/${f##*/}" 2>/dev/null
done
for f in sudo pkexec flatpak; do ln -sf "$T/bin/$f" "$T/semudd/$f"; done
desktop "$APPS/vivo.desktop" 'Type=Application' 'Name=Vivo' 'Exec=true'
antes="$(foto)"
rc1="$(env -i PATH="$T/semudd" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 XDG_DATA_DIRS="$FLAT:$LOCAL:$T/sistema" \
  MEOW_APLICATIVOS_SISTEMA="$SIS" MEOW_APLICATIVOS_FLATPAK="$T/vazio" bash "$RAIZ/scripts/lancador.sh" --aplicar >/dev/null 2>&1; echo $?)"
confere "sem quem refaça a cache e sem órfão, o aplicar não diz que mexeu nem escreve" \
  '[ "$rc1" != 1 ] && [ "$antes" = "$(foto)" ]'
rm -f "$APPS/vivo.desktop"

printf '\n2c. sem LANCADOR_SISTEMA="sim", o doctor não oculta nada do sistema (o opt-in do install)\n'
ALVO="$(env -i PATH="/usr/bin:/bin" HOME="$CASA" bash "$RAIZ/scripts/ocultar_apps.sh" --lista 2>/dev/null | head -1)"
desktop "$SIS/$ALVO.desktop" 'Type=Application' "Name=$ALVO" 'Exec=true'
cp -a "$SIS/$ALVO.desktop" "$T/alvo-original.desktop"
FUNCS="$(sed -n -e '/^_lancador_do_sistema()/,/^}/p' -e '/^chk_ocultar()/,/^}/p' -e '/^chk_absolutos()/,/^}/p' \
  -e '/^fix_ocultar()/,/; }$/p' -e '/^fix_absolutos()/,/; }$/p' "$RAIZ/bin/meow")"
doc_oc="$(env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 RAIZ="$RAIZ" \
  MEOW_APLICATIVOS_SISTEMA="$SIS" FUNCS="$FUNCS" bash -c '. "$RAIZ/lib/comum.sh"; eval "$FUNCS"
  chk_ocultar; echo "chk=$?"; fix_ocultar; echo "fix=$?"' 2>&1)"
confere "o chk_ocultar e o fix_ocultar pulam, e o .desktop do sistema fica igual" \
  'printf "%s" "$doc_oc" | grep -q "chk=3" && printf "%s" "$doc_oc" | grep -q "fix=3" && cmp -s "$SIS/$ALVO.desktop" "$T/alvo-original.desktop"'
rm -f "$SIS/$ALVO.desktop"

printf '\n3. o ocultar alcança flatpak, /usr/local e o home\n'
desktop "$SIS/do-apt.desktop" 'Type=Application' 'Name=Do Apt' 'Exec=true'
desktop "$FLAT/applications/org.example.Flat.desktop" 'Type=Application' 'Name=Flat' 'Name[pt_BR]=Chato' \
  'Exec=/usr/bin/flatpak run org.example.Flat %U' 'Icon=org.example.Flat' 'MimeType=text/x-flat;' \
  'Categories=Utility;' 'Actions=nova;'
printf '\n[Desktop Action nova]\nName=Nova\nExec=flat --nova\n' >> "$FLAT/applications/org.example.Flat.desktop"
desktop "$LOCAL/applications/local-app.desktop" 'Type=Application' 'Name=Local' 'Exec=true'
desktop "$APPS/do-home.desktop" 'Type=Application' 'Name=Do Home' 'Exec=true'
desktop "$APPS/ja-escondido.desktop" 'Type=Application' 'Name=Já' 'NoDisplay=true' 'Exec=true'
cp -a "$APPS/do-home.desktop" "$T/do-home-original.desktop"
LISTA="do-apt,org.example.Flat,local-app,do-home,ja-escondido,nao-instalado"
_oc() { local m="$1"; shift
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
      XDG_DATA_DIRS="$FLAT:$LOCAL:$T/sistema" MEOW_APLICATIVOS_SISTEMA="$SIS" MEOW_APLICATIVOS_FLATPAK="$T/vazio" \
      LANCADOR_SISTEMA="${OC_LIGADO:-sim}" LANCADOR_OCULTAR="$LISTA" "$@" bash "$RAIZ/scripts/ocultar_casa.sh" "$m"; }
FORA="$(env -i PATH="/usr/bin:/bin" HOME="$CASA" bash "$RAIZ/scripts/ocultar_apps.sh" --lista 2>/dev/null | sed 's/^/-/' | paste -sd, -)"
LISTA="$LISTA${FORA:+,$FORA}"
antes="$(foto)"
saida="$(_oc --conferir 2>&1)"; rc=$?
confere "o conferir vê o flatpak, o /usr/local e o do home, e não escreve" \
  '[ "$rc" = 1 ] && [ "$(printf "%s\n" "$saida" | grep -c "esconderia")" = 3 ] && [ "$antes" = "$(foto)" ]'
confere "o que mora em /usr/share fica com o ocultar_apps.sh" '! printf "%s" "$saida" | grep -q "do-apt"'
_oc --aplicar >/dev/null 2>&1; rc=$?
S="$APPS/org.example.Flat.desktop"
confere "a sombra do flatpak: mesmo basename, NoDisplay e a marca" \
  '[ "$rc" = 1 ] && grep -qx "NoDisplay=true" "$S" && grep -qx "X-MeowSystem=ocultar" "$S" && grep -qx "Exec=/usr/bin/flatpak run org.example.Flat %U" "$S" && grep -qx "MimeType=text/x-flat;" "$S"'
confere "e só o necessário: sem ação, sem categoria, sem tradução" \
  '! grep -qE "^(Actions|Categories|Name\[)|Desktop Action" "$S"'
confere "o de /usr/local também ganha sombra" 'grep -qx "X-MeowSystem=ocultar" "$APPS/local-app.desktop"'
confere "o do home é marcado no lugar" 'grep -qx "NoDisplay=true" "$APPS/do-home.desktop" && grep -qx "X-MeowSystem=ocultar-no-lugar" "$APPS/do-home.desktop"'
confere "o que já estava escondido e o do apt não são tocados" \
  '! grep -q "X-MeowSystem" "$APPS/ja-escondido.desktop" && [ ! -e "$APPS/do-apt.desktop" ] && [ ! -s "$T/recusas.log" ]'
antes="$(foto)"
_oc --aplicar >/dev/null 2>&1; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ] && [ "$antes" = "$(foto)" ]'
sed -i 's|^Exec=/usr/bin/flatpak run org.example.Flat %U|Exec=/usr/bin/flatpak run org.example.Flat --novo %U|' "$FLAT/applications/org.example.Flat.desktop"
saida="$(_oc --conferir 2>&1)"; rc=$?
confere "o original mudou: o conferir pede a sombra refeita" '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q "refaria a sombra de org.example.Flat"'
_oc --aplicar >/dev/null 2>&1
confere "e o aplicar a refaz" 'grep -qx "Exec=/usr/bin/flatpak run org.example.Flat --novo %U" "$S"'
LISTA="${LISTA/local-app,/}"
_oc --aplicar >/dev/null 2>&1
confere "saiu da lista: a sombra sai" '[ ! -e "$APPS/local-app.desktop" ]'
rm -f "$FLAT/applications/org.example.Flat.desktop"
_oc --aplicar >/dev/null 2>&1
confere "o aplicativo saiu: a sombra sai junto" '[ ! -e "$S" ]'
desktop "$FLAT/applications/org.example.Flat.desktop" 'Type=Application' 'Name=Flat' 'Exec=flat'
_oc --aplicar >/dev/null 2>&1
saida="$(OC_LIGADO=nao _oc --conferir 2>&1)"; rc=$?
confere "com LANCADOR_SISTEMA=nao, o que é nosso aparece para sair" '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q "devolveria"'
antes="$(foto)"
saida="$(_oc --reverter MEOW_DRY_RUN=1 2>&1)"; rc=$?
confere "o reverter em ensaio (o --uninstall seco) diz o que tiraria e não escreve" \
  '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q "devolveria" && [ "$antes" = "$(foto)" ]'
_oc --reverter >/dev/null 2>&1; rc=$?
confere "o reverter tira a sombra e devolve o do home byte a byte" \
  '[ "$rc" = 1 ] && [ ! -e "$S" ] && cmp -s "$APPS/do-home.desktop" "$T/do-home-original.desktop"'
saida="$(OC_LIGADO=nao _oc --conferir 2>&1)"; rc=$?
confere "desligado e sem nada nosso, pula" '[ "$rc" = 3 ]'

printf '\n4. o doctor e o instalador chamam os três\n'
V="$(sed -n 's/^VERIFICAVEIS=(\(.*\))$/\1/p' "$RAIZ/bin/meow")"
for n in janeladock ocultarcasa lancador; do
  confere "o doctor confere e conserta $n" \
    'printf " %s " "$V" | grep -q " $n " && grep -q "^chk_$n()" "$RAIZ/bin/meow" && grep -q "^fix_$n()" "$RAIZ/bin/meow"'
done
E="$(sed -n '/local etapas=(/,/)/p' "$RAIZ/install.sh")"
for n in etapa_janela_dock etapa_ocultar_casa etapa_lancador; do
  confere "o install.sh roda $n" 'printf "%s\n" "$E" | grep -qw "$n"'
done
confere "o lancador vem depois de toda etapa que escreve no home" \
  'printf "%s\n" "$E" | tr -s " \n" "\n\n" | grep -n . | awk -F: "/etapa_lancador\$/ { l = \$1 } /etapa_(atalho|midia|leitura_applet|ocultar_casa|janela_dock)\$/ { if (\$1 > m) m = \$1 } END { exit !(l > m) }"'

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'lançador do meow: tudo verde\n'; exit 0; fi
printf 'lançador do meow: %s falha(s)\n' "$falhas"; exit 1

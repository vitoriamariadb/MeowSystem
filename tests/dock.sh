#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

command -v git >/dev/null 2>&1 && command -v patch >/dev/null 2>&1 || { printf 'FALHA: o teste precisa de git e patch\n'; exit 1; }

CASA="$T/casa"; FALSO="$T/falso"; ESTADO="$CASA/.local/state/meowsystem"
LIBEXEC="$CASA/.local/libexec/meow/dock"; SHIM="$CASA/.local/bin/cosmic-app-list"; CACHE="$CASA/.cache/meowsystem/dock"
mkdir -p "$CASA/.config/meow" "$ESTADO" "$FALSO" "$T/patches" "$T/up" "$T/fabrica"
: > "$CASA/.config/meow/meow.conf"

printf '\n0. a série, o commit fixado e o patch\n'
SERIE="$RAIZ/patches/dock.series"; PATCH_REAL="$RAIZ/patches/cosmic-app-list-casamento-por-padrao.patch"
confere "a série tem uma entrada: o patch do casamento e o marcador MEOW-DOCK-PATCH-<n>" \
  '[ "$(grep -c . "$SERIE")" = 1 ] && grep -qE "^cosmic-app-list-casamento-por-padrao\.patch MEOW-DOCK-PATCH-[0-9]+$" "$SERIE"' "$(cat "$SERIE")"
confere "o marcador da série está dentro do patch, num static" \
  'm="$(awk "{print \$2}" "$SERIE")"; grep -F "\"$m\"" "$PATCH_REAL" | grep -q "^+static MEOW_DOCK_PATCH"'
confere "a versão instalada nesta leva está fixada no commit 6f89bfa inteiro" \
  'grep -qxE "1\.11\.0~1793636322~24\.04~6f89bfa 6f89bfa[0-9a-f]{33}" "$RAIZ/patches/dock.versao"'
confere "o patch só toca o cosmic-app-list" '[ "$(grep -c "^+++ " "$PATCH_REAL")" = 1 ] && grep -qx "+++ b/cosmic-app-list/src/app.rs" "$PATCH_REAL"'
confere "o patch traz os testes de unidade do casamento" 'grep -q "^+#\[cfg(test)\]" "$PATCH_REAL" && [ "$(grep -c "^+    #\[test\]" "$PATCH_REAL")" -ge 10 ]'
confere "a segunda tentativa só roda depois de o casamento exato falhar" \
  'grep -B3 "^+            } else if let Some(entry) = find_app_by_pattern" "$PATCH_REAL" | grep -q "^             if let Some(entry) = fde::find_app_by_id(&self.desktop_entries, unicase_appid)"'
confere "as três regras, em ordem: maiúscula, sufixo de papel, prefixo de domínio" \
  'grep -A3 "^+    by_id(app_id)" "$PATCH_REAL" | tr -d "\n" | grep -q "by_id(app_id)+        .or_else(|| strip_role_suffix(app_id).and_then(by_id))+        .or_else(|| find_app_by_reverse_domain_prefix(desktop_entries, app_id))"'
confere "os seis sufixos de papel, nem um a mais" \
  'grep -qF "+const ROLE_SUFFIXES: [&str; 6] = [\"Prompter\", \"Prompt\", \"Dialog\", \"Portal\", \"Helper\", \"Agent\"];" "$PATCH_REAL"'
confere "nenhum comentário novo no patch" '! grep -E "^\+[[:space:]]*//" "$PATCH_REAL"'
confere "o shim é o do portal com os nomes da dock" \
  'diff <(sed -e "s/DOCK-SHIM/PORTAL-SHIM/; s#/usr/bin/cosmic-app-list#/usr/libexec/xdg-desktop-portal-cosmic#; s#meow/dock#meow/graficos#; s/cosmic-applets 2/xdg-desktop-portal-cosmic 2/; s#/cosmic-app-list\"#/xdg-desktop-portal-cosmic\"#" "$RAIZ/scripts/dock_shim.sh") "$RAIZ/scripts/portal_shim.sh" >/dev/null'

printf '\n1. o upstream sintético: um repositório git local no lugar do github\n'
(
  cd "$T/up" && git init -q -b main . && git config user.email t@t && git config user.name t
  mkdir -p cosmic-app-list/src
  printf '[workspace]\nmembers = ["cosmic-app-list"]\n' > Cargo.toml
  printf 'um\ndois\ntres\nquatro\ncinco\n' > cosmic-app-list/src/app.rs
  git add -A && git -c core.hooksPath=/dev/null commit -q -m um
  printf 'um\ndois\ntres\nQUATRO\ncinco\n' > cosmic-app-list/src/app.rs
  git -c core.hooksPath=/dev/null commit -q -am dois
)
C1="$(git -C "$T/up" rev-parse HEAD~1)"; C2="$(git -C "$T/up" rev-parse HEAD)"
VER1="1.11.0~1793636322~24.04~${C1:0:7}"; VER2="1.12.0~1794000000~24.04~${C2:0:7}"
mkdir -p "$T/fix/a/cosmic-app-list/src" "$T/fix/b/cosmic-app-list/src"
printf 'um\ndois\ntres\nquatro\ncinco\n' > "$T/fix/a/cosmic-app-list/src/app.rs"
printf 'um\ndois\nMEOW-DOCK-PATCH-1\ntres\nquatro\ncinco\n' > "$T/fix/b/cosmic-app-list/src/app.rs"
( cd "$T/fix" && diff -u --label a/cosmic-app-list/src/app.rs --label b/cosmic-app-list/src/app.rs a/cosmic-app-list/src/app.rs b/cosmic-app-list/src/app.rs > "$T/patches/p-dock.patch" )
printf 'p-dock.patch MEOW-DOCK-PATCH-1\n' > "$T/patches/dock.series"
printf '%s %s\n' "$VER1" "$C1" > "$T/patches/dock.versao"
confere "o patch sintético entra com -F0 no commit fixado" \
  '(cd "$T/fix/a" && patch -p1 -F0 --dry-run < "$T/patches/p-dock.patch") >/dev/null'

printf '\n2. os falsos: nada escreve no sistema da pessoa\n'
cat > "$FALSO/dpkg-query" <<FIM
#!/bin/sh
fmt=""; pacotes=""
for a in "\$@"; do
  case "\$a" in -W) ;; -f=*) fmt="\${a#-f=}" ;; *) pacotes="\$pacotes \$a" ;; esac
done
for p in \$pacotes; do
  linha=\$(awk -F'\t' -v p="\$p" '\$1==p' "$T/dpkg.tsv")
  [ -n "\$linha" ] || continue
  v=\$(printf '%s' "\$linha" | cut -f2); st=\$(printf '%s' "\$linha" | cut -f3)
  saida=\$(printf '%s' "\$fmt" | sed -e "s/\\\${Package}/\$p/" -e "s/\\\${Version}/\$v/" -e "s/\\\${db:Status-Status}/\$st/")
  printf '%b' "\$saida"
done
FIM
cat > "$FALSO/cargo" <<FIM
#!/bin/sh
echo "cargo \$* alvo=\$CARGO_TARGET_DIR" >> "$T/cargo.log"
[ -f "$T/cargo-falha" ] && { echo "error: could not compile"; exit 101; }
mkdir -p "\$CARGO_TARGET_DIR/release"
{ printf '#!/bin/sh\necho build "\$@"\n'; grep -h MEOW- cosmic-app-list/src/app.rs | sed 's/^/# /'; } > "\$CARGO_TARGET_DIR/release/cosmic-app-list"
[ -f "$T/sem-marcador" ] && sed -i '/MEOW-/d' "\$CARGO_TARGET_DIR/release/cosmic-app-list"
chmod 755 "\$CARGO_TARGET_DIR/release/cosmic-app-list"
FIM
for c in sudo pkexec su apt apt-get systemctl systemd-run pkill killall just make notify-send; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/recusados"\nexit 1\n' "$c" "$T" > "$FALSO/$c"
done
printf '#!/bin/sh\necho fabrica "$@"\n' > "$T/fabrica/cosmic-app-list"
chmod 755 "$FALSO"/* "$T/fabrica/cosmic-app-list"

versoes() {
  : > "$T/dpkg.tsv"; local x
  for x in "$@"; do printf '%s\t%s\tinstalled\n' "${x%%=*}" "${x#*=}" >> "$T/dpkg.tsv"; done
}
dk() {
  local verbo="$1"; shift
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY -u XDG_CACHE_HOME -u XDG_CONFIG_HOME -u CARGO_HOME \
    HOME="$CASA" PATH="$FALSO:/usr/bin:/bin" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LC_ALL=C \
    MEOW_ESTADO="$ESTADO" MEOW_CONF="$CASA/.config/meow/meow.conf" \
    DK_URL="$T/up" DK_REPO="$T/patches" DK_SERIE="$T/patches/dock.series" DK_VERSOES="$T/patches/dock.versao" \
    DK_FABRICA="$T/fabrica/cosmic-app-list" DK_ESPACO_KB=1 DOCK="${DOCK_T:-sim}" "$@" \
    "$RAIZ/scripts/dock.sh" "$verbo" > "$T/saida" 2>&1
}
shim() {
  env HOME="$CASA" PATH="$FALSO:/usr/bin:/bin" MEOW_SHIM_FABRICA="$T/fabrica/cosmic-app-list" MEOW_SHIM_JANELA=1 "$@"
}
foto() { (cd "$T" && find casa -printf '%p %s %T@ %i\n' 2>/dev/null | sort; find casa -type f -exec sha256sum {} + 2>/dev/null | sort) | sha256sum; }
valor() { sed -n "s/^$1=//p" "$T/saida" | head -1; }

printf '\n3. sem o pacote, nada a fazer\n'
versoes
dk aplicar; rc=$?
confere "sem cosmic-applets o aplicar sai 3 e não escreve" '[ "$rc" = 3 ] && [ ! -e "$SHIM" ] && [ ! -e "$LIBEXEC" ]' "$(cat "$T/saida")"

printf '\n4. conferir não escreve nada\n'
versoes "cosmic-applets=$VER1"
dk estado
confere "estado: pendente, sem build, sem shim, commit fixado" \
  '[ "$(valor estado)" = pendente ] && [ "$(valor build)" = nao ] && [ "$(valor shim)" = nao ] && [ "$(valor commit)" = "$C1" ]' "$(cat "$T/saida")"
dk pendente
confere "pendente diz a versão" '[ "$(cat "$T/saida")" = "$VER1" ]'
f0="$(foto)"
dk conferir; rc=$?
confere "antes de aplicar o conferir diverge (1) e não escreve um byte" '[ "$rc" = 1 ] && [ "$(foto)" = "$f0" ]' "$(cat "$T/saida")"
confere "e não baixou nem compilou" '[ ! -s "$T/cargo.log" ] && [ ! -e "$CACHE" ]'

printf '\n5. compilar: baixa o commit da versão, aplica a série, guarda o binário\n'
dk compilar; rc=$?
confere "compila e guarda o binário da versão" '[ "$rc" = 0 ] && [ -x "$LIBEXEC/$VER1/cosmic-app-list" ]' "$(cat "$T/saida")"
confere "o fonte é o do commit fixado, com o patch" 'grep -q MEOW-DOCK-PATCH-1 "$LIBEXEC/$VER1/cosmic-app-list" && [ "$(cat "$LIBEXEC/$VER1/commit")" = "$C1" ]'
confere "o cargo compila só o cosmic-app-list, travado pelo Cargo.lock, com o alvo fora do fonte" \
  'grep -q -- "build --release --locked -p cosmic-app-list --bin cosmic-app-list alvo=$CACHE/alvo" "$T/cargo.log"' "$(cat "$T/cargo.log")"
confere "o marcador e a digital ficam ao lado do binário" '[ "$(cat "$LIBEXEC/$VER1/marcadores")" = MEOW-DOCK-PATCH-1 ] && [ -s "$LIBEXEC/$VER1/digital" ]'
confere "o fonte e a compilação saem do cache" '[ ! -e "$CACHE/fonte" ] && [ ! -e "$CACHE/alvo" ]'
dk estado
confere "estado: ok, com build" '[ "$(valor estado)" = ok ] && [ "$(valor build)" = sim ]' "$(cat "$T/saida")"
n_cargo="$(wc -l < "$T/cargo.log")"
dk compilar; rc=$?
confere "a segunda compilação não compila" '[ "$rc" = 0 ] && [ "$(wc -l < "$T/cargo.log")" = "$n_cargo" ]' "$(cat "$T/saida")"

printf '\n6. aplicar liga o shim, e a segunda passada não escreve\n'
dk aplicar env DK_COMPILAR=nao; rc=$?
confere "o shim entra em ~/.local/bin/cosmic-app-list, igual ao do repositório" '[ "$rc" = 1 ] && cmp -s "$RAIZ/scripts/dock_shim.sh" "$SHIM" && [ -x "$SHIM" ]' "$(cat "$T/saida")"
f1="$(foto)"
dk aplicar env DK_COMPILAR=nao; rc=$?
confere "a segunda passada sai 0 e não escreve" '[ "$rc" = 0 ] && [ "$(foto)" = "$f1" ]' "$(cat "$T/saida")"
dk conferir; rc=$?
confere "o conferir fica verde" '[ "$rc" = 0 ]' "$(cat "$T/saida")"

printf '\n7. o shim escolhe o build e cai na fábrica quando o build some\n'
versoes "cosmic-applets=$VER1"
confere "com o build bom, o shim diz o build" '[ "$(shim MEOW_SHIM_SO_DIZER=1 bash "$SHIM")" = "$LIBEXEC/$VER1/cosmic-app-list" ]'
confere "e o roda com os argumentos" '[ "$(shim bash "$SHIM" -x y)" = "build -x y" ]'
rm -f "$LIBEXEC/$VER1/quedas"
mv "$LIBEXEC/$VER1/cosmic-app-list" "$T/guardado"
confere "sem o build, o shim roda a dock do pacote" '[ "$(shim bash "$SHIM" a)" = "fabrica a" ]'
mv "$T/guardado" "$LIBEXEC/$VER1/cosmic-app-list"
versoes "cosmic-applets=$VER2"
confere "com o pacote noutra versão, a dock do pacote" '[ "$(shim MEOW_SHIM_SO_DIZER=1 bash "$SHIM")" = "$T/fabrica/cosmic-app-list" ]'
versoes "cosmic-applets=$VER1"
cp "$LIBEXEC/$VER1/marcadores" "$T/m"; echo MEOW-OUTRO >> "$LIBEXEC/$VER1/marcadores"
confere "com um marcador que o binário não tem, a dock do pacote" '[ "$(shim MEOW_SHIM_SO_DIZER=1 bash "$SHIM")" = "$T/fabrica/cosmic-app-list" ]'
cp "$T/m" "$LIBEXEC/$VER1/marcadores"
rm -f "$LIBEXEC/$VER1/quedas"
shim bash "$SHIM" >/dev/null; shim bash "$SHIM" >/dev/null
confere "duas subidas que não passam da janela: a terceira cai na fábrica e marca o build" \
  '[ "$(shim bash "$SHIM")" = fabrica ] && [ -e "$LIBEXEC/$VER1/ruim" ]'
dk estado
confere "estado: falhou, ruim=sim" '[ "$(valor estado)" = falhou ] && [ "$(valor ruim)" = sim ]' "$(cat "$T/saida")"

printf '\n8. cuidar: devolve uma vez, e na segunda queda põe de lado\n'
dk cuidar; rc=$?
confere "o build passa na fumaça e volta, com o perdão anotado" '[ "$rc" = 1 ] && [ ! -e "$LIBEXEC/$VER1/ruim" ] && [ -e "$LIBEXEC/$VER1/perdoado" ]' "$(cat "$T/saida")"
date -Is > "$LIBEXEC/$VER1/ruim"
dk cuidar; rc=$?
confere "caiu de novo: fica de lado de vez" '[ "$rc" = 1 ] && [ "$(head -c 4 "$LIBEXEC/$VER1/ruim")" = caiu ]' "$(cat "$T/saida")"
dk cuidar; rc=$?
confere "e o cuidar seguinte não mexe" '[ "$rc" = 0 ]' "$(cat "$T/saida")"
confere "o shim respeita o caiu" '[ "$(shim MEOW_SHIM_SO_DIZER=1 bash "$SHIM")" = "$T/fabrica/cosmic-app-list" ]'
rm -f "$LIBEXEC/$VER1/ruim" "$LIBEXEC/$VER1/perdoado"

printf '\n9. DOCK=nao e reverter tiram o shim; arquivo de outro não se toca\n'
DOCK_T=nao dk aplicar; rc=$?
confere "DOCK=nao tira o shim e guarda o build" '[ "$rc" = 1 ] && [ ! -e "$SHIM" ] && [ -x "$LIBEXEC/$VER1/cosmic-app-list" ]' "$(cat "$T/saida")"
DOCK_T=nao dk aplicar; rc=$?
confere "a segunda passada com DOCK=nao sai 0" '[ "$rc" = 0 ]' "$(cat "$T/saida")"
DOCK_T=nao dk estado
confere "estado: desligado" '[ "$(valor estado)" = desligado ]'
printf '#!/bin/sh\necho outro\n' > "$SHIM"; chmod 755 "$SHIM"
dk aplicar env DK_COMPILAR=nao; rc=$?
confere "um cosmic-app-list de outro em ~/.local/bin não é trocado (erro)" '[ "$rc" = 2 ] && grep -q outro "$SHIM"' "$(cat "$T/saida")"
dk reverter; rc=$?
confere "nem apagado no reverter" '[ "$rc" = 0 ] && grep -q outro "$SHIM"' "$(cat "$T/saida")"
rm -f "$SHIM"
dk aplicar env DK_COMPILAR=nao
dk reverter; rc=$?
confere "reverter tira o shim nosso" '[ "$rc" = 1 ] && [ ! -e "$SHIM" ]' "$(cat "$T/saida")"

printf '\n10. a série que não entra: recusa gravada, a dock do pacote segue\n'
versoes "cosmic-applets=$VER2"
dk compilar; rc=$?
confere "na versão nova o patch não entra (-F0) e nada é guardado" '[ "$rc" = 2 ] && [ ! -e "$LIBEXEC/$VER2" ] && grep -q "não entra no fonte da dock" "$T/saida"' "$(cat "$T/saida")"
confere "a versão nova sem linha no dock.versao usa o commit que a própria versão diz" 'grep -q "$C2" <(git -C "$CACHE/fonte" rev-parse HEAD)'
dk estado
confere "estado: nao-encaixa, e não pende" '[ "$(valor estado)" = nao-encaixa ]' "$(cat "$T/saida")"
dk pendente
confere "o pendente fica calado" '[ ! -s "$T/saida" ]'
confere "o build antigo da outra versão segue guardado até um build novo" '[ -x "$LIBEXEC/$VER1/cosmic-app-list" ]'

printf '\n11. o commit fixado tem de ser o que a versão diz\n'
rm -rf "$ESTADO/dock" "$CACHE"
printf '%s %s\n' "$VER1" "$C2" > "$T/patches/dock.versao"
versoes "cosmic-applets=$VER1"
dk validar; rc=$?
confere "commit fixado diferente do sufixo da versão é recusado" '[ "$rc" = 2 ] && grep -q "não é o ${C1:0:7}" "$T/saida"' "$(cat "$T/saida")"
printf '%s %s\n' "$VER1" "$C1" > "$T/patches/dock.versao"
rm -rf "$ESTADO/dock" "$CACHE"
versoes "cosmic-applets=1.11.0~1793636322~24.04"
dk validar; rc=$?
confere "versão sem commit no fim é recusada, sem baixar" '[ "$rc" = 2 ] && [ ! -e "$CACHE/fonte" ]' "$(cat "$T/saida")"
rm -rf "$ESTADO/dock"
versoes "cosmic-applets=$VER1"
dk validar; rc=$?
confere "o validar roda o dry-run e não guarda nada" '[ "$rc" = 0 ] && [ ! -e "$CACHE/fonte" ] && grep -q "a série entra na dock" "$T/saida"' "$(cat "$T/saida")"

printf '\n12. a compilação que falha: espera antes de tentar de novo\n'
rm -rf "$LIBEXEC" "$ESTADO/dock"
touch "$T/cargo-falha"
dk compilar; rc=$?
confere "cargo falhou: nada guardado" '[ "$rc" = 2 ] && [ ! -e "$LIBEXEC/$VER1" ]' "$(cat "$T/saida")"
dk estado
confere "estado: falhou" '[ "$(valor estado)" = falhou ]'
dk pendente
confere "e não pende de novo logo em seguida (espera)" '[ ! -s "$T/saida" ]'
rm -f "$T/cargo-falha"; rm -rf "$ESTADO/dock"
touch "$T/sem-marcador"
dk compilar; rc=$?
confere "binário sem o marcador não é guardado" '[ "$rc" = 2 ] && [ ! -e "$LIBEXEC/$VER1/cosmic-app-list" ] && grep -q "NÃO no binário" "$T/saida"' "$(cat "$T/saida")"
rm -f "$T/sem-marcador"; rm -rf "$ESTADO/dock"

printf '\n13. o garantir_builds pende, compila e liga a dock\n'
gb() {
  local verbo="$1"; shift
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY -u XDG_CACHE_HOME -u XDG_CONFIG_HOME -u CARGO_HOME \
    HOME="$CASA" PATH="$FALSO:/usr/bin:/bin" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LC_ALL=C \
    MEOW_ESTADO="$ESTADO" MEOW_CONF="$CASA/.config/meow/meow.conf" \
    DK_URL="$T/up" DK_REPO="$T/patches" DK_SERIE="$T/patches/dock.series" DK_VERSOES="$T/patches/dock.versao" \
    DK_FABRICA="$T/fabrica/cosmic-app-list" DK_ESPACO_KB=1 "$@" \
    "$RAIZ/scripts/garantir_builds.sh" "$verbo" > "$T/saida" 2>&1
}
gb estado
confere "o estado dos builds diz a dock pendente" 'grep -qx "dock_versao=$VER1" "$T/saida" && grep -qx dock_estado=pendente "$T/saida"' "$(cat "$T/saida")"
gb rodar; rc=$?
confere "rodar compila a dock e liga o shim" '[ "$rc" = 0 ] && [ -x "$LIBEXEC/$VER1/cosmic-app-list" ] && cmp -s "$RAIZ/scripts/dock_shim.sh" "$SHIM"' "$(cat "$T/saida")"
gb estado
confere "e o estado fica ok" 'grep -qx dock_estado=ok "$T/saida"' "$(cat "$T/saida")"
DOCK=nao gb estado
confere "com DOCK=nao a dock não pende" 'grep -qx dock_estado=desligado "$T/saida"' "$(cat "$T/saida")"

printf '\n14. a fiação: install, doctor, verbo, desinstalar, contratos\n'
confere "o install tem a etapa da dock, depois da do portal" 'grep -q "^etapa_dock()" "$RAIZ/install.sh" && grep -q "etapa_graficos etapa_dock " "$RAIZ/install.sh"'
confere "o doctor confere a dock logo depois do portal" 'grep -q "areas patches graficos dock relogio" "$RAIZ/bin/meow" && grep -q "^chk_dock()" "$RAIZ/bin/meow" && grep -q "^fix_dock()" "$RAIZ/bin/meow"'
confere "o meow tem o verbo dock" 'grep -qE "^    dock\) shift" "$RAIZ/bin/meow"'
confere "o desinstalar reverte a dock" 'grep -q "dock.sh\" reverter" "$RAIZ/lib/desinstalar.sh"'
confere "a chave DOCK está no meow.conf.exemplo e leva à etapa" 'grep -qx "DOCK=\"sim\" *# sim | nao" "$RAIZ/meow.conf.exemplo" && grep -qxF "DOCK	dock	nao" "$RAIZ/assets/contratos/chave-etapa.tsv"'
confere "o espaço tem dono para o build, o cache, o estado e o shim" \
  'for i in dock-builds dock-cache dock-estado; do grep -q "^$i	" "$RAIZ/assets/contratos/espaco.tsv" || exit 1; done; grep -q "local/bin/cosmic-app-list	" "$RAIZ/assets/contratos/espaco.tsv"'
confere "o grupo dock entra nos pacotes de compilar quando o cosmic-applets está instalado" \
  'env HOME="$CASA" PATH="$FALSO:$PATH" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" MEOW_CONF="$CASA/.config/meow/meow.conf" EXTENSOES=- COMPOSITOR=nao FILES_MENU=nao GRAFICOS=nao bash -c ". \"$RAIZ/lib/comum.sh\"; meow_grupos_de_compilar" | grep -qx dock'
confere "DOCK=nao tira o grupo" \
  '! env HOME="$CASA" PATH="$FALSO:$PATH" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" MEOW_CONF="$CASA/.config/meow/meow.conf" EXTENSOES=- COMPOSITOR=nao FILES_MENU=nao GRAFICOS=nao DOCK=nao bash -c ". \"$RAIZ/lib/comum.sh\"; meow_grupos_de_compilar" | grep -qx dock'
confere "nada pediu sudo, apt, systemctl nem pkill" '[ ! -s "$T/recusados" ]' "$(cat "$T/recusados" 2>/dev/null)"

[ "$falhas" = 0 ] && printf '\nok: a dock compila do commit fixado, o shim cai no pacote quando o build some, e a segunda passada não escreve\n'
exit $((falhas > 0))

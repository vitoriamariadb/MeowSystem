#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

CASA="$T/casa"; FALSO="$T/falso"; ETC="$T/etc"; PROC="$T/proc"
ESTADO="$CASA/.local/state/meowsystem"; LIBEXEC="$CASA/.local/libexec/meow/graficos"
DROPIN="$CASA/.config/systemd/user/org.freedesktop.impl.portal.desktop.cosmic.service.d/meow-graficos.conf"
POLICY="$ETC/opt/chrome/policies/managed/compartilhar-tela.json"
PONTE="$T/ponte/ponte_root.sh"; VELHA="$T/ponte-velha/ponte_root.sh"
VER1="1.11.0~1792525517~24.04~f448ddf"; VER2="1.12.0~1793000000~24.04~aaaaaaa"
mkdir -p "$CASA/.config/meow" "$ESTADO" "$FALSO" "$T/ponte" "$T/ponte-velha" "$PROC" "$T/fix"

printf '\n0. a série, a versão e os patches\n'
SERIE="$RAIZ/patches/graficos.series"
confere "a série tem três entradas: dois do portal e um do toolkit" \
  '[ "$(awk "NF >= 3" "$SERIE" | wc -l)" = 3 ] && [ "$(awk "\$1 == \"portal\"" "$SERIE" | wc -l)" = 2 ] && [ "$(awk "\$1 == \"toolkit\"" "$SERIE" | wc -l)" = 1 ]' "$(cat "$SERIE")"
confere "cada arquivo da série existe em patches/" \
  'while read -r a f m; do [ -f "$RAIZ/patches/$f" ] || exit 1; done < "$SERIE"'
confere "o marcador de cada entrada está dentro do patch dela" \
  'while read -r a f m; do [ "$m" = - ] || grep -qF "+static MEOW_" <(grep -F "\"$m\"" "$RAIZ/patches/$f") || exit 1; done < "$SERIE"'
confere "o marcador do portal é MEOW-PORTAL-PATCH-<n>" 'grep -qE "^portal .* MEOW-PORTAL-PATCH-[0-9]+$" "$SERIE"'
confere "a versão própria declara o portal 1.11.0 (f448ddf)" 'grep -qxF "$VER1" "$RAIZ/patches/graficos.versao"'
confere "nenhum patch acrescenta comentário" '! grep -E "^\+[[:space:]]*//" "$RAIZ"/patches/xdg-desktop-portal-cosmic-*.patch "$RAIZ"/patches/cosmic-protocols-*.patch'
confere "o [patch] do Cargo.toml usa caminho relativo ao fonte, nunca /home" \
  'grep -q "path = \"meow-toolkit\"" "$RAIZ/patches/xdg-desktop-portal-cosmic-toolkit-local.patch" && ! grep -q "/home/" "$RAIZ"/patches/xdg-desktop-portal-cosmic-*.patch "$RAIZ"/patches/cosmic-protocols-*.patch'
confere "o patch do portal não força o SHM (a cura de máquina fica fora)" '! grep -qE "let _ = \(dmabuf, fixated\)" "$RAIZ"/patches/xdg-desktop-portal-cosmic-*.patch'

printf '\n1. a fonte sintética: três patches que o dry-run -F0 aceita\n'
mkdir -p "$T/fix/a/src" "$T/fix/b/src" "$T/fix/a-tk/client-toolkit/src" "$T/fix/b-tk/client-toolkit/src" "$T/patches"
printf 'um\ndois\ntres\nquatro\ncinco\n' > "$T/fix/a/src/a.rs"
printf '[package]\nname = "portal"\n' > "$T/fix/a/Cargo.toml"
printf 'um\ndois\nMEOW-PORTAL-PATCH-1\ntres\nquatro\ncinco\n' > "$T/fix/b/src/a.rs"
printf '[package]\nname = "portal"\n[patch]\nmeow = 1\n' > "$T/fix/b/Cargo.toml"
printf 'x\ny\nz\n' > "$T/fix/a-tk/client-toolkit/src/b.rs"
printf 'x\nMEOW-TOOLKIT-PATCH-1\ny\nz\n' > "$T/fix/b-tk/client-toolkit/src/b.rs"
( cd "$T/fix" && diff -u --label a/src/a.rs --label b/src/a.rs a/src/a.rs b/src/a.rs > "$T/patches/p-portal.patch"
  diff -u --label a/Cargo.toml --label b/Cargo.toml a/Cargo.toml b/Cargo.toml > "$T/patches/p-wiring.patch"
  diff -u --label a/client-toolkit/src/b.rs --label b/client-toolkit/src/b.rs a-tk/client-toolkit/src/b.rs b-tk/client-toolkit/src/b.rs > "$T/patches/p-toolkit.patch" )
printf 'portal p-portal.patch MEOW-PORTAL-PATCH-1\nportal p-wiring.patch -\ntoolkit p-toolkit.patch MEOW-TOOLKIT-PATCH-1\n' > "$T/patches/graficos.series"
printf '%s\n' "$VER1" > "$T/patches/graficos.versao"
mkdir -p "$T/fix/vend/vendor/cosmic-protocols/src" "$T/fix/vend/vendor/cosmic-client-toolkit/src"
printf '[package]\nname = "cosmic-protocols"\n' > "$T/fix/vend/vendor/cosmic-protocols/Cargo.toml"
printf '[package]\nname = "cosmic-client-toolkit"\n' > "$T/fix/vend/vendor/cosmic-client-toolkit/Cargo.toml"
cp "$T/fix/a-tk/client-toolkit/src/b.rs" "$T/fix/vend/vendor/cosmic-client-toolkit/src/b.rs"
( cd "$T/fix/vend" && tar cf "$T/fix/vendor.tar" vendor )
confere "os três patches sintéticos entram com -F0" \
  '(cd "$T/fix/a" && patch -p1 -F0 --dry-run < "$T/patches/p-portal.patch" && patch -p1 -F0 --dry-run < "$T/patches/p-wiring.patch") >/dev/null && (cd "$T/fix/a-tk" && patch -p1 -F0 --dry-run < "$T/patches/p-toolkit.patch") >/dev/null'

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
cat > "$FALSO/sudo" <<FIM
#!/bin/sh
echo "sudo \$*" >> "$T/sudo.log"
if [ "\$1" = "-n" ] && { [ "\$2" = "$PONTE" ] || [ "\$2" = "$VELHA" ]; } && [ ! -f "$T/sem-ponte" ]; then shift; exec "\$@"; fi
exit 1
FIM
cat > "$FALSO/systemctl" <<FIM
#!/bin/sh
echo "systemctl \$*" >> "$T/systemctl.log"
case "\$*" in
  *"show -p MainPID"*) cat "$T/mainpid" 2>/dev/null || echo 0; exit 0 ;;
  *"show -p ExecStart"*)
    if [ -f "$T/outro-dropin" ]; then p=\$(cat "$T/outro-dropin")
    elif [ -f "$DROPIN" ]; then p=\$(sed -n 's/^ExecStart=\\(.\\)/\\1/p' "$DROPIN" | tail -1)
    else p=/usr/libexec/xdg-desktop-portal-cosmic; fi
    printf '{ path=%s ; argv[]=%s ; ignore_errors=no ; start_time=[n/a] }\n' "\$p" "\$p"; exit 0 ;;
  *restart*) touch "$T/reiniciou"; exit 0 ;;
  *daemon-reload*) exit 0 ;;
esac
exit 1
FIM
cat > "$FALSO/pw-dump" <<FIM
#!/bin/sh
cat "$T/pw.json" 2>/dev/null || echo '[]'
FIM
cat > "$FALSO/journalctl" <<FIM
#!/bin/sh
echo "journalctl \$*" >> "$T/journalctl.log"
cat "$T/journal.jsonl" 2>/dev/null
exit 0
FIM
cat > "$FALSO/apt-get" <<FIM
#!/bin/sh
echo "apt-get \$*" >> "$T/apt-get.log"
[ -f "$T/sem-fonte" ] && { echo "E: Falha ao buscar http://x/y.tar.xz 404 Not Found"; exit 1; }
[ -f "$T/sem-deb-src" ] && { echo "E: You must put some 'deb-src' URIs in your sources.list"; exit 1; }
pacote="\${3%%=*}"; versao="\${3#*=}"
[ "\$1" = source ] || exit 1
: > "\${pacote}_\${versao#*:}.dsc"
: > "\${pacote}_\${versao#*:}.tar.xz"
exit 0
FIM
cat > "$FALSO/dpkg-source" <<FIM
#!/bin/sh
echo "dpkg-source \$*" >> "$T/dpkg-source.log"
[ "\$1" = -x ] || exit 1
mkdir -p "\$3" && cp -a "$T/fix/\${FONTE_FIXA:-a}/." "\$3/" && cp "$T/fix/vendor.tar" "\$3/vendor.tar"
FIM
cat > "$FALSO/cargo" <<FIM
#!/bin/sh
echo "cargo \$*" >> "$T/cargo.log"
[ -f "$T/cargo-falha" ] && { echo "error: could not compile"; exit 101; }
mkdir -p target/release
{ printf '#!/bin/sh\n'; grep -h MEOW- src/a.rs meow-toolkit/client-toolkit/src/b.rs | sed 's/^/# /'; } > target/release/xdg-desktop-portal-cosmic
chmod 755 target/release/xdg-desktop-portal-cosmic
FIM
chmod 755 "$FALSO"/*

sed -e "s#^export PATH=.*#export PATH=\"$FALSO:/usr/bin:/bin\"#" -e 's/ -o root -g root//g' \
    -e "s#^CHROME_POLICY_DIR=.*#CHROME_POLICY_DIR=$ETC/opt/chrome/policies/managed#" -e 's#^anotar() {#anotar() { return 0#' \
    "$RAIZ/scripts/ponte_root.sh" > "$PONTE"
chmod 755 "$PONTE"
sed -e '/^chrome-policy)/,/^  ;;$/d' -e '/^chrome-policy-tirar)/,/^  ;;$/d' "$PONTE" > "$VELHA"
chmod 755 "$VELHA"

versoes() {
  : > "$T/dpkg.tsv"; local x
  for x in "$@"; do printf '%s\t%s\tinstalled\n' "${x%%=*}" "${x#*=}" >> "$T/dpkg.tsv"; done
}
ponte() { env -i PATH=/usr/bin:/bin bash "$PONTE" "$@" > "$T/saida" 2>&1; }
graf() {
  local verbo="$1"; shift
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY \
    HOME="$CASA" PATH="$FALSO:$PATH" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LC_ALL=C \
    MEOW_ESTADO="$ESTADO" MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE="$PONTE" \
    GR_REPO="$T/patches" GR_SERIE="$T/patches/graficos.series" GR_VERSOES="${GR_VERSOES_T:-$T/patches/graficos.versao}" \
    GR_POLICY="$POLICY" GR_PROC="$PROC" GR_ESPACO_KB=1 GRAFICOS="${GRAFICOS_T:-sim}" "$@" \
    "$RAIZ/scripts/graficos.sh" "$verbo" > "$T/saida" 2>&1
}
ext() {
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR HOME="$CASA" PATH="$FALSO:$PATH" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LC_ALL=C MEOW_ESTADO="$ESTADO" \
    MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE="$PONTE" GR_REPO="$T/patches" GR_SERIE="$T/patches/graficos.series" GR_VERSOES="$T/patches/graficos.versao" \
    GR_POLICY="$POLICY" GR_PROC="$PROC" GR_ESPACO_KB=1 CP_REPO="$T/patches" CP_SERIE="$T/patches/graficos.series" "$@" > "$T/saida" 2>&1
}
foto() { (cd "$T" && find casa etc -printf '%p %s %T@ %i\n' 2>/dev/null | grep -v '/\.cache/' | sort; find casa etc -type f ! -path '*/.cache/*' -exec sha256sum {} + 2>/dev/null | sort) | sha256sum; }
linhas() { local n; n="$(grep -c "$1" "$2" 2>/dev/null)" || n=0; printf '%s' "$n"; }
chrome() { printf 'google-chrome-stable\t146.0\tinstalled\n' >> "$T/dpkg.tsv"; }
sem_chrome() { sed -i '/^google-chrome-stable/d' "$T/dpkg.tsv"; }
portal_vivo() { printf '4242\n' > "$T/mainpid"; mkdir -p "$PROC/4242"; ln -sfn "$1" "$PROC/4242/exe"; }
portal_parado() { rm -f "$T/mainpid"; }
stream() { printf '[{"type":"PipeWire:Interface:Node","info":{"state":"running","props":{"node.name":"cosmic-screencast"}}}]\n' > "$T/pw.json"; }
sem_stream() { printf '[{"type":"PipeWire:Interface:Node","info":{"state":"suspended","props":{"node.name":"alsa_output"}}}]\n' > "$T/pw.json"; }

printf '\n3. a ponte root: o verbo da policy do Chrome\n'
versoes "xdg-desktop-portal-cosmic=$VER1"
ponte chrome-policy; rc=$?
confere "sem o pacote do Chrome a ponte sai 0, calada, e não cria /etc/opt/chrome" '[ "$rc" = 0 ] && [ ! -s "$T/saida" ] && [ ! -e "$ETC/opt" ]' "$(cat "$T/saida")"
chrome
ponte chrome-policy; rc=$?
confere "com o Chrome cria a pasta e o arquivo, e diz que mudou" '[ "$rc" = 0 ] && grep -qx mudou "$T/saida" && [ -f "$POLICY" ]' "$(cat "$T/saida")"
confere "o conteúdo são os três valores, nada a mais" '[ "$(tr -d " \n" < "$POLICY")" = "{\"ScreenCaptureAllowed\":true,\"VideoCaptureAllowed\":true,\"AudioCaptureAllowed\":true}" ]' "$(cat "$POLICY")"
confere "o texto da ponte é o mesmo do graficos.sh" \
  '[ "$(sed -n "/^GR_POLICY_TEXTO=/,/^}'"'"'$/p" "$RAIZ/scripts/graficos.sh" | sed "1s/^GR_POLICY_TEXTO=//" | tr -d "\n ")" = "$(sed -n "/^CHROME_POLICY_TEXTO=/,/^}'"'"'$/p" "$RAIZ/scripts/ponte_root.sh" | sed "1s/^CHROME_POLICY_TEXTO=//" | tr -d "\n ")" ]'
m="$(stat -c '%i %Y %s' "$POLICY")"; sleep 1
ponte chrome-policy; rc=$?
confere "a segunda passada não escreve: mesmo inode, mesma hora, nada impresso" '[ "$rc" = 0 ] && [ "$(stat -c "%i %Y %s" "$POLICY")" = "$m" ] && [ ! -s "$T/saida" ]' "$(cat "$T/saida")"
ponte chrome-policy-tirar; rc=$?
confere "o -tirar apaga o arquivo e deixa a pasta" '[ "$rc" = 0 ] && [ ! -e "$POLICY" ] && [ -d "${POLICY%/*}" ]'
ponte chrome-policy-tirar; rc=$?
confere "o -tirar repetido sai 0 sem imprimir" '[ "$rc" = 0 ] && [ ! -s "$T/saida" ]'
mkdir -p "${POLICY%/*}"; ln -s /nao/existe "$POLICY"
ponte chrome-policy; rc=$?
confere "link simbólico no destino é recusado" '[ "$rc" != 0 ] && grep -q "link simbólico" "$T/saida"' "$(cat "$T/saida")"
rm -f "$POLICY"; sem_chrome
confere "a regra do sudo lista os dois verbos novos" \
  'SUDO_USER=alguem bash "$RAIZ/scripts/ponte_root.sh" regra-sudo | grep -q "ponte_root.sh chrome-policy, " && SUDO_USER=alguem bash "$RAIZ/scripts/ponte_root.sh" regra-sudo | grep -q "ponte_root.sh chrome-policy-tirar, "'
confere "nenhum verbo novo aceita argumento (a ponte recusa)" 'bash "$PONTE" chrome-policy extra >/dev/null 2>&1; [ $? != 0 ]'
confere "a lista de pacotes da ponte inclui o que o portal compila" \
  'for p in libclang-dev clang libpipewire-0.3-dev libegl-dev; do grep -qE "PERMITIDOS=.* $p " "$RAIZ/scripts/ponte_root.sh" || exit 1; done; for p in libclang-dev clang libpipewire-0.3-dev; do grep -qxF "graficos	$p" "$RAIZ/assets/pacotes/compilar.tsv" || exit 1; done'

printf '\n4. conferir não escreve nada\n'
versoes "xdg-desktop-portal-cosmic=$VER1"; chrome; portal_parado; sem_stream
f0="$(foto)"
graf conferir; rc=$?
confere "antes de aplicar o conferir diverge (1)" '[ "$rc" = 1 ]' "$(cat "$T/saida")"
confere "e não escreveu um byte" '[ "$(foto)" = "$f0" ] && [ ! -e "$LIBEXEC" ] && [ ! -e "$DROPIN" ] && [ ! -e "$POLICY" ]'
confere "a saída diz o que falta, sem mandar digitar" 'grep -q "ainda não tem build" "$T/saida" && ! grep -qiE "digite|rode |execute|sudo " "$T/saida"' "$(cat "$T/saida")"
confere "nada foi baixado nem compilado" '[ ! -s "$T/apt-get.log" ] && [ ! -s "$T/cargo.log" ]'

printf '\n5. aplicar: compila, guarda, liga o shim, o drop-in e a policy\n'
: > "$T/sudo.log"
graf aplicar; rc=$?
confere "a primeira passada sai 1 (mudou)" '[ "$rc" = 1 ]' "$(cat "$T/saida")"
confere "o fonte veio do apt e a árvore foi aberta" '[ "$(linhas "^apt-get source --download-only xdg-desktop-portal-cosmic=$VER1" "$T/apt-get.log")" = 1 ] && [ "$(linhas "^dpkg-source -x" "$T/dpkg-source.log")" = 1 ]'
confere "compilou uma vez, congelado e sem rede" '[ "$(linhas "^cargo build --release --frozen --offline --bin xdg-desktop-portal-cosmic" "$T/cargo.log")" = 1 ]' "$(cat "$T/cargo.log")"
confere "o build ficou na casa da versão, com os marcadores e a digital" \
  '[ -x "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic" ] && grep -qx MEOW-PORTAL-PATCH-1 "$LIBEXEC/$VER1/marcadores" && grep -qx MEOW-TOOLKIT-PATCH-1 "$LIBEXEC/$VER1/marcadores" && [ -s "$LIBEXEC/$VER1/digital" ]'
confere "os dois marcadores estão dentro do binário" 'grep -a -q MEOW-PORTAL-PATCH-1 "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic" && grep -a -q MEOW-TOOLKIT-PATCH-1 "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic"'
confere "o shim existe e é o do repositório" 'cmp -s "$RAIZ/scripts/portal_shim.sh" "$LIBEXEC/portal-shim" && [ -x "$LIBEXEC/portal-shim" ]'
confere "o drop-in zera o ExecStart e aponta para o shim" '[ "$(grep -c "^ExecStart=" "$DROPIN")" = 2 ] && grep -qx "ExecStart=$LIBEXEC/portal-shim" "$DROPIN" && grep -q MEOW-PORTAL-DROPIN "$DROPIN"' "$(cat "$DROPIN" 2>&1)"
confere "o drop-in não toca no drop-in de ninguém (outro nome de arquivo)" '[ "$(ls "${DROPIN%/*}" | wc -l)" = 1 ]'
confere "o systemd recarregou uma vez, e o portal parado não reiniciou" '[ "$(linhas "daemon-reload" "$T/systemctl.log")" = 1 ] && [ "$(linhas "restart" "$T/systemctl.log")" = 0 ]' "$(cat "$T/systemctl.log")"
confere "a policy entrou pela ponte, com o Chrome instalado" '[ -f "$POLICY" ] && grep -qx "sudo -n $PONTE chrome-policy" "$T/sudo.log"' "$(cat "$T/sudo.log")"
confere "a pasta do build não guarda fonte nem alvo" '[ -z "$(find "$LIBEXEC" -name "*.rs" -o -name target -o -name "*.tar" | head -1)" ] && [ ! -d "$CASA/.cache/meowsystem/graficos/fonte" ]'

printf '\n6. a segunda passada não compila, não escreve e não reinicia\n'
f1="$(foto)"; n_sudo="$(wc -l < "$T/sudo.log")"; n_cargo="$(wc -l < "$T/cargo.log")"; n_apt="$(wc -l < "$T/apt-get.log")"; n_sc="$(grep -c 'restart\|daemon-reload' "$T/systemctl.log")"
sleep 1
graf aplicar; rc=$?
confere "sai 0, ok" '[ "$rc" = 0 ] && grep -q "em dia" "$T/saida"' "$(cat "$T/saida")"
confere "nenhum arquivo mudou (inode, hora, tamanho, conteúdo)" '[ "$(foto)" = "$f1" ]'
confere "não compilou, não baixou e não reiniciou nem recarregou" \
  '[ "$(wc -l < "$T/cargo.log")" = "$n_cargo" ] && [ "$(wc -l < "$T/apt-get.log")" = "$n_apt" ] && [ "$(grep -c "restart\|daemon-reload" "$T/systemctl.log")" = "$n_sc" ]'
confere "a ponte não foi chamada para escrever (só o estado que o viva pergunta)" '[ "$(grep -c "chrome-policy" "$T/sudo.log")" = 1 ]' "$(cat "$T/sudo.log")"
graf conferir; rc=$?
confere "o conferir também diz ok" '[ "$rc" = 0 ]' "$(cat "$T/saida")"
graf estado
confere "o estado diz ok, com build, shim, drop-in e policy" 'grep -qx estado=ok "$T/saida" && grep -qx build=sim "$T/saida" && grep -qx shim=sim "$T/saida" && grep -qx dropin=sim "$T/saida" && grep -qx policy=sim "$T/saida"' "$(cat "$T/saida")"

printf '\n7. o portal vivo só reinicia se a versão mudou, e nunca com stream no ar\n'
portal_vivo /usr/libexec/xdg-desktop-portal-cosmic; stream; : > "$T/systemctl.log"; rm -f "$T/reiniciou"
graf aplicar; rc=$?
confere "rodando o do pacote, com compartilhamento no ar: não reinicia e não conta como escrita" '[ "$rc" = 0 ] && [ ! -e "$T/reiniciou" ] && grep -q "espera" "$T/saida"' "$(cat "$T/saida")"
graf conferir; rc=$?
confere "o conferir segue divergindo, para o doctor tentar quando o compartilhamento acabar" '[ "$rc" = 1 ]' "$(cat "$T/saida")"
sem_stream
graf aplicar; rc=$?
confere "sem stream: reinicia uma vez" '[ "$rc" = 1 ] && [ -e "$T/reiniciou" ] && [ "$(linhas "restart" "$T/systemctl.log")" = 1 ]' "$(cat "$T/saida")"
portal_vivo /usr/libexec/xdg-desktop-portal-cosmic; rm -f "$T/reiniciou"
printf '[{"type":"PipeWire:Interface:Node","info":{"state":"suspended","props":{"node.name":"cosmic-screencast"}}}]\n' > "$T/pw.json"
graf aplicar; rc=$?
confere "compartilhamento pausado (o nó existe, suspenso) conta como no ar: não reinicia" '[ "$rc" = 0 ] && [ ! -e "$T/reiniciou" ] && grep -q "espera" "$T/saida"' "$(cat "$T/saida")"
printf '{"inesperado":1}\n' > "$T/pw.json"
graf aplicar; rc=$?
confere "pw-dump com JSON de outra forma não libera o reinício" '[ ! -e "$T/reiniciou" ] && grep -q "próxima subida" "$T/saida"' "$(cat "$T/saida")"
sem_stream
portal_vivo "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic"; rm -f "$T/reiniciou"
graf aplicar; rc=$?
confere "já rodando o build: sai 0 e não reinicia" '[ "$rc" = 0 ] && [ ! -e "$T/reiniciou" ]' "$(cat "$T/saida")"
portal_vivo "/usr/libexec/xdg-desktop-portal-cosmic (deleted)"; printf '' > "$T/pw.json"; rm -f "$FALSO/pw-dump.bak"; mv "$FALSO/pw-dump" "$FALSO/pw-dump.bak"
graf aplicar; rc=$?
confere "sem pw-dump a troca espera a próxima subida, sem reiniciar e sem amarelo" '[ "$rc" = 0 ] && [ ! -e "$T/reiniciou" ] && grep -q "próxima subida" "$T/saida"' "$(cat "$T/saida")"
mv "$FALSO/pw-dump.bak" "$FALSO/pw-dump"; portal_parado
printf '%s\n' "/opt/da-maquina/libexec/xdg-desktop-portal-cosmic" > "$T/outro-dropin"; portal_vivo "/opt/da-maquina/libexec/xdg-desktop-portal-cosmic"; rm -f "$T/reiniciou"
graf aplicar; rc=$?
confere "ExecStart de outro drop-in manda: o meow não reinicia, sai 3 e diz de quem é" '[ "$rc" = 3 ] && [ ! -e "$T/reiniciou" ] && grep -q "outro drop-in" "$T/saida"' "$(cat "$T/saida")"
confere "e a segunda passada ainda não reinicia nada" '(graf aplicar; [ ! -e "$T/reiniciou" ])'
rm -f "$T/outro-dropin"; portal_parado

printf '\n8. sem Chrome a policy some em silêncio; com o Chrome depois, o garantir_builds a põe\n'
rm -f "$POLICY"; rm -rf "$ETC/opt"; sem_chrome; : > "$T/sudo.log"
graf aplicar; rc=$?
confere "sem Chrome: sai 0, não cria /etc/opt, não usa a ponte e não fala de policy" '[ "$rc" = 0 ] && [ ! -e "$ETC/opt" ] && ! grep -q "chrome-policy" "$T/sudo.log" && ! grep -qi "policy" "$T/saida"' "$(cat "$T/saida")"
graf estado
confere "o estado diz sem-chrome" 'grep -qx policy=sem-chrome "$T/saida"'
chrome
ext "$RAIZ/scripts/garantir_builds.sh"; rc=$?
confere "o gatilho pós-apt (garantir_builds) aplica a policy sem compilar de novo" '[ -f "$POLICY" ] && [ "$(wc -l < "$T/cargo.log")" = "$n_cargo" ]' "$(cat "$T/saida")"
env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR HOME="$CASA" PATH="$FALSO:$PATH" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LC_ALL=C MEOW_ESTADO="$ESTADO" \
  MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE="$PONTE" GR_REPO="$T/patches" GR_SERIE="$T/patches/graficos.series" GR_VERSOES="$T/patches/graficos.versao" \
  GR_POLICY="$POLICY" GR_PROC="$PROC" GR_ESPACO_KB=1 CP_REPO="$T/patches" CP_SERIE="$T/patches/graficos.series" \
  "$RAIZ/scripts/garantir_builds.sh" estado > "$T/saida" 2>&1
confere "o estado do garantir_builds traz a versão e a situação do portal" 'grep -qx "graficos_versao=$VER1" "$T/saida" && grep -qx graficos_estado=ok "$T/saida"' "$(cat "$T/saida")"

printf '\n9. sem a ponte root: diz o que falta, sem mandar digitar, e o resto fica feito\n'
rm -f "$POLICY"; : > "$T/sem-ponte"
graf aplicar; rc=$?
confere "sai 3, a policy não entrou, e o texto não manda digitar" '[ "$rc" = 3 ] && [ ! -e "$POLICY" ] && grep -q "ponte root" "$T/saida" && ! grep -qiE "digite|rode |execute|sudo " "$T/saida"' "$(cat "$T/saida")"
rm -f "$T/sem-ponte"
cp "$PONTE" "$T/ponte-guardada"; cp "$VELHA" "$PONTE"; : > "$T/sudo.log"
graf aplicar; rc=$?
confere "ponte de antes do verbo: sai 3, diz que o «Instalar tudo» a renova e não manda digitar" '[ "$rc" = 3 ] && grep -q "de antes" "$T/saida" && grep -q "renova" "$T/saida" && ! grep -qiE "digite|rode |execute|sudo " "$T/saida"' "$(cat "$T/saida")"
cp "$T/ponte-guardada" "$PONTE"
graf aplicar
confere "com a ponte de volta a policy entra" '[ -f "$POLICY" ]'

printf '\n9b. a build do portal não depende do compositor\n'
rm -f "$POLICY"; mkdir -p "$T/mz"
printf 'cosmic-comp\t0.1~t\tinstalled\n' >> "$T/dpkg.tsv"
printf '0.1~t\tx\tp.patch:4\t\n' > "$T/mz/matriz.tsv"
ext env GB_MATRIZ="$T/mz/matriz.tsv" COMPOSITOR=sim "$RAIZ/scripts/garantir_builds.sh"; rc=$?
confere "compositor em degrau 4: o garantir_builds ainda liga o portal e a policy" '[ "$rc" = 0 ] && grep -q "degrau 4" "$T/saida" && [ -f "$POLICY" ]' "$(cat "$T/saida")"
sed -i '/^cosmic-comp/d' "$T/dpkg.tsv"

printf '\n10. versão nova: sem compilar vira pendente; o garantir_builds compila e poda a velha\n'
versoes "xdg-desktop-portal-cosmic=$VER2" "google-chrome-stable=146.0"
printf '%s\n%s\n' "$VER1" "$VER2" > "$T/patches/graficos.versao"
graf estado
confere "o estado vira pendente" 'grep -qx estado=pendente "$T/saida"' "$(cat "$T/saida")"
n_cargo="$(wc -l < "$T/cargo.log")"
GR_COMPILAR=nao graf aplicar; rc=$?
confere "aplicar sem compilar diz que falta o build, não compila e não conta como escrita" '[ "$rc" = 0 ] && grep -q "ainda não tem build" "$T/saida" && [ "$(wc -l < "$T/cargo.log")" = "$n_cargo" ]' "$(cat "$T/saida")"
confere "o shim cai no pacote enquanto não há build" '[ "$(MEOW_SHIM_SO_DIZER=1 MEOW_SHIM_CASA="$LIBEXEC" PATH="$FALSO:$PATH" bash "$LIBEXEC/portal-shim")" = /usr/libexec/xdg-desktop-portal-cosmic ]'
ext "$RAIZ/scripts/garantir_builds.sh"; rc=$?
confere "o garantir_builds compilou a versão nova, e o build velho foi podado" '[ "$(wc -l < "$T/cargo.log")" = "$((n_cargo + 1))" ] && [ -x "$LIBEXEC/$VER2/xdg-desktop-portal-cosmic" ] && [ ! -e "$LIBEXEC/$VER1" ]' "$(cat "$T/saida")"
confere "e o shim passa a escolher o build novo" '[ "$(MEOW_SHIM_SO_DIZER=1 MEOW_SHIM_CASA="$LIBEXEC" PATH="$FALSO:$PATH" bash "$LIBEXEC/portal-shim")" = "$LIBEXEC/$VER2/xdg-desktop-portal-cosmic" ]'
n_cargo="$(wc -l < "$T/cargo.log")"
env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR HOME="$CASA" PATH="$FALSO:$PATH" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LC_ALL=C MEOW_ESTADO="$ESTADO" \
  MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE="$PONTE" GR_REPO="$T/patches" GR_SERIE="$T/patches/graficos.series" GR_VERSOES="$T/patches/graficos.versao" \
  GR_POLICY="$POLICY" GR_PROC="$PROC" GR_ESPACO_KB=1 CP_REPO="$T/patches" CP_SERIE="$T/patches/graficos.series" \
  "$RAIZ/scripts/garantir_builds.sh" > "$T/saida" 2>&1
confere "a segunda passada do garantir_builds não compila" '[ "$(wc -l < "$T/cargo.log")" = "$n_cargo" ]'

printf '\n11. o patch que não entra recusa a versão, avisa e deixa o pacote valendo\n'
versoes "xdg-desktop-portal-cosmic=1.13.0~1~24.04~bbbbbbb" "google-chrome-stable=146.0"
printf 'um\nMUDOU\ntres\nquatro\ncinco\nseis\n' > "$T/fix/a/src/a.rs"
n_cargo="$(wc -l < "$T/cargo.log")"
graf aplicar; rc=$?
confere "aplicar não compila, sai 0 e diz que o patch não entra" '[ "$rc" = 0 ] && grep -q "não entra" "$T/saida" && ! grep -qiE "command not found|comando não encontrado" "$T/saida" && [ "$(wc -l < "$T/cargo.log")" = "$n_cargo" ]' "$(cat "$T/saida")"
graf estado
confere "o estado vira nao-encaixa" 'grep -qx estado=nao-encaixa "$T/saida"' "$(cat "$T/saida")"
confere "a recusa vai para o log, sem tela e sem receita" 'grep -q "o patch do portal não entra" "$ESTADO/meow.log" && ! grep -qiE "digite|rode |execute" "$ESTADO/meow.log" && [ ! -e "$ESTADO/precisa-de-gente.tsv" ] && ! grep -q "^graficos-" "$ESTADO/pendencias.tsv" 2>/dev/null' "$(cat "$ESTADO/meow.log" 2>&1)"
graf conferir
confere "a primeira linha do conferir, a que o doctor mostra, diz que o patch não entra" 'head -1 "$T/saida" | grep -q "o patch não entra"' "$(cat "$T/saida")"
confere "o shim fica no pacote" '[ "$(MEOW_SHIM_SO_DIZER=1 MEOW_SHIM_CASA="$LIBEXEC" PATH="$FALSO:$PATH" bash "$LIBEXEC/portal-shim")" = /usr/libexec/xdg-desktop-portal-cosmic ]'
ext env EXTENSOES_FUNDO=1 EXTENSOES_COMPILAR=1 "$RAIZ/scripts/extensoes_build.sh" graficos --aplicar; rc=$?
confere "com a recusa, a etapa do install não conta como escrita (o laço não acusa idempotência)" '[ "$rc" = 0 ]' "$(cat "$T/saida")"
graf pendente
confere "a recusa não volta a ser pendente (o garantir_builds não repete)" '[ ! -s "$T/saida" ]' "$(cat "$T/saida")"
confere "a segunda passada não registra a recusa de novo" '[ "$(linhas "o patch do portal não entra" "$ESTADO/meow.log")" = 1 ]' "$(cat "$ESTADO/meow.log")"
printf 'um\ndois\ntres\nquatro\ncinco\n' > "$T/fix/a/src/a.rs"
ext "$RAIZ/scripts/garantir_builds.sh"; rc=$?
confere "a recusa já gravada não é falha do garantir_builds" '[ "$rc" = 0 ]' "$(cat "$T/saida")"
f4="$(foto)"; graf conferir; rc=$?
confere "o conferir com a recusa gravada não escreve nada" '[ "$(foto)" = "$f4" ]'
printf 'portal p-portal.patch MEOW-PORTAL-PATCH-1\nportal p-wiring.patch -\ntoolkit p-toolkit.patch MEOW-TOOLKIT-PATCH-1\n\n' > "$T/patches/graficos.series"
sed -i 's/^um$/ZZ/' "$T/fix/a/src/a.rs"
ext "$RAIZ/scripts/garantir_builds.sh"; rc=$?
confere "a recusa na hora do garantir_builds sai 0, sem prometer outra tentativa" '[ "$rc" = 0 ] && grep -q "não entra" "$T/saida" && ! grep -q "tenta de novo" "$T/saida"' "$(cat "$T/saida")"
sed -i 's/^ZZ$/um/' "$T/fix/a/src/a.rs"
printf 'portal p-portal.patch MEOW-PORTAL-PATCH-1\nportal p-wiring.patch -\ntoolkit p-toolkit.patch MEOW-TOOLKIT-PATCH-1\n\n\n' > "$T/patches/graficos.series"
graf pendente
confere "mexer na série devolve a versão à fila" '[ "$(cat "$T/saida")" = "1.13.0~1~24.04~bbbbbbb" ]' "$(cat "$T/saida")"
printf 'um\nMUDOU\ntres\nquatro\ncinco\nseis\n' > "$T/fix/a/src/a.rs"
: > "$ESTADO/meow.log"
graf validar; rc=$?
confere "a recusa vista pelo validar também vai para o log" '[ "$rc" = 2 ] && grep -q "o patch do portal não entra" "$ESTADO/meow.log"' "$(cat "$T/saida" "$ESTADO/meow.log")"
printf 'um\ndois\ntres\nquatro\ncinco\n' > "$T/fix/a/src/a.rs"
printf 'portal p-portal.patch MEOW-PORTAL-PATCH-1\nportal p-wiring.patch -\ntoolkit p-toolkit.patch MEOW-TOOLKIT-PATCH-1\n\n\n\n' > "$T/patches/graficos.series"
printf '#!/bin/sh\ncase " $* " in *" --dry-run "*) exec %s "$@" ;; esac\nexit 1\n' "$(command -v patch)" > "$FALSO/patch"; chmod +x "$FALSO/patch"
: > "$ESTADO/meow.log"
graf compilar; rc=$?
rm -f "$FALSO/patch"
confere "o patch que passa no dry-run e não entra na hora também vai para o log" '[ "$rc" = 2 ] && grep -q "não entrou na hora de aplicar" "$T/saida" && grep -q "o patch do portal não entra" "$ESTADO/meow.log"' "$(cat "$T/saida" "$ESTADO/meow.log")"

printf '\n12. o patch que compila mas some do binário não instala\n'
versoes "xdg-desktop-portal-cosmic=1.14.0~1~24.04~ccccccc" "google-chrome-stable=146.0"
printf 'um\ndois\ntres\nquatro\ncinco\n' > "$T/fix/a/src/a.rs"
sed -i 's/^MEOW-PORTAL-PATCH-1$/sem-marca/' "$T/fix/b/src/a.rs"
cp "$FALSO/cargo" "$T/cargo-bom"
sed -i 's#grep -h MEOW- src/a.rs meow-toolkit/client-toolkit/src/b.rs#grep -h MEOW-TOOLKIT meow-toolkit/client-toolkit/src/b.rs#' "$FALSO/cargo"
GR_COMPILAR=sim graf compilar; rc=$?
confere "marcador ausente no binário: erro, e nada vai para a casa" '[ "$rc" = 2 ] && grep -q "NÃO no binário" "$T/saida" && [ ! -e "$LIBEXEC/1.14.0~1~24.04~ccccccc" ]' "$(cat "$T/saida")"
cp "$T/cargo-bom" "$FALSO/cargo"

printf '\n12b. o build que não sai não é "em dia"\n'
: > "$T/cargo-falha"
graf aplicar; rc=$?
confere "cargo que falha no aplicar: diverge (1) e não diz em dia" '[ "$rc" = 1 ] && ! grep -q "em dia" "$T/saida"' "$(cat "$T/saida")"
rm -f "$T/cargo-falha" "$ESTADO/graficos/falhas.tsv"

printf '\n13. cargo que falha: nada é instalado e a espera cresce\n'
: > "$T/cargo-falha"
graf compilar; rc=$?
confere "sai 2, avisa, e não instala" '[ "$rc" = 2 ] && grep -q "compilação do portal falhou" "$T/saida" && [ ! -e "$LIBEXEC/1.14.0~1~24.04~ccccccc" ]' "$(cat "$T/saida")"
graf pendente
confere "a falha de compilação espera (não é pendente de imediato)" '[ ! -s "$T/saida" ]' "$(cat "$T/saida")"
rm -f "$T/cargo-falha"

printf '\n13b. o fonte que o apt não serve: a espera cresce, e o portal entra nela\n'
for sem in sem-deb-src sem-fonte; do
  rm -rf "$CASA/.cache/meowsystem/graficos/baixado" "$ESTADO/graficos/falhas.tsv"
  : > "$T/$sem"
  graf compilar; rc=$?
  confere "$sem: sai 2, sem compilar e sem instalar" '[ "$rc" = 2 ] && [ ! -e "$LIBEXEC/1.14.0~1~24.04~ccccccc" ]' "$(cat "$T/saida")"
  graf pendente
  confere "$sem: o portal espera, não é pendente de imediato" '[ ! -s "$T/saida" ]' "$(cat "$T/saida")"
  confere "$sem: a falha gravada é a do download" '[ "$(cut -f3 "$ESTADO/graficos/falhas.tsv")" = baixar ] && [ "$(cut -f4 "$ESTADO/graficos/falhas.tsv")" = 1 ]' "$(cat "$ESTADO/graficos/falhas.tsv" 2>&1)"
  graf compilar
  confere "$sem: a segunda tentativa soma, e a espera dobra" '[ "$(cut -f4 "$ESTADO/graficos/falhas.tsv")" = 2 ]' "$(cat "$ESTADO/graficos/falhas.tsv" 2>&1)"
  rm -f "$T/$sem"
done
rm -f "$ESTADO/graficos/falhas.tsv"

printf '\n13c. o rebuild local (+0~nome1) baixa o fonte da versão de base\n'
LOCAL="$VER1+0~hefesto1"
rm -rf "$CASA/.cache/meowsystem/graficos/baixado" "$ESTADO/graficos/falhas.tsv"; : > "$T/apt-get.log"
versoes "xdg-desktop-portal-cosmic=$LOCAL" "google-chrome-stable=146.0"
graf compilar; rc=$?
confere "o apt recebe a versão de base, nunca a do rebuild local" \
  'grep -qx "apt-get source --download-only xdg-desktop-portal-cosmic=$VER1" "$T/apt-get.log" && ! grep -q hefesto "$T/apt-get.log"' "$(cat "$T/apt-get.log" "$T/saida")"
confere "o build fica na casa da versão instalada, com os marcadores" \
  '[ -x "$LIBEXEC/$LOCAL/xdg-desktop-portal-cosmic" ] && grep -qx MEOW-TOOLKIT-PATCH-1 "$LIBEXEC/$LOCAL/marcadores"' "$(cat "$T/saida")"
confere "a versão de base validada vale para o rebuild local" \
  'MEOW_RAIZ="$RAIZ" GR_VERSOES="$T/patches/graficos.versao" bash -c ". \"$RAIZ/lib/comum.sh\"; eval \"\$(sed -n \"/^_gr_versao_do_fonte()/,/^}/p; /^_gr_validada()/p\" \"$RAIZ/scripts/graficos.sh\")\"; _gr_validada \"$LOCAL\""'
rm -f "$ESTADO/graficos/falhas.tsv"

printf '\n14. o shim: a regra do ruim, a conferência do marcador e o pacote de fábrica\n'
SH="$T/shim"; mkdir -p "$SH/casa/9.9" "$SH/bin"
printf '#!/bin/sh\necho fabrica "$@"\n' > "$SH/fabrica"; chmod 755 "$SH/fabrica"
printf '#!/bin/sh\n# MEOW-PORTAL-PATCH-1\necho build "$@"\n' > "$SH/casa/9.9/xdg-desktop-portal-cosmic"; chmod 755 "$SH/casa/9.9/xdg-desktop-portal-cosmic"
printf 'MEOW-PORTAL-PATCH-1\n' > "$SH/casa/9.9/marcadores"
printf '#!/bin/sh\nprintf "9.9"\n' > "$SH/bin/dpkg-query"; chmod 755 "$SH/bin/dpkg-query"
shim() { MEOW_SHIM_FABRICA="$SH/fabrica" MEOW_SHIM_CASA="$SH/casa" MEOW_SHIM_JANELA=1 PATH="$SH/bin:$PATH" bash "$RAIZ/scripts/portal_shim.sh" "$@"; }
confere "build válido: o shim roda o build" '[ "$(shim a)" = "build a" ]' "$(shim a)"
rm -f "$SH/casa/9.9/quedas"
confere "build sem o marcador no binário: o shim roda o pacote" '(printf "#!/bin/sh\necho build\n" > "$SH/casa/9.9/xdg-desktop-portal-cosmic"; [ "$(shim a)" = "fabrica a" ])'
printf '#!/bin/sh\n# MEOW-PORTAL-PATCH-1\necho build "$@"\n' > "$SH/casa/9.9/xdg-desktop-portal-cosmic"
confere "sem o arquivo de marcadores: o pacote" '(mv "$SH/casa/9.9/marcadores" "$SH/m"; r="$(shim a)"; mv "$SH/m" "$SH/casa/9.9/marcadores"; [ "$r" = "fabrica a" ])'
rm -f "$SH/casa/9.9/quedas"; shim x >/dev/null; shim x >/dev/null
confere "duas subidas seguidas contam duas quedas" '[ "$(cat "$SH/casa/9.9/quedas")" = 2 ] || [ ! -e "$SH/casa/9.9/quedas" ]'
printf '2\n' > "$SH/casa/9.9/quedas"
confere "a terceira subida dentro da janela põe o build como ruim e roda o pacote" '[ "$(shim a)" = "fabrica a" ] && [ -s "$SH/casa/9.9/ruim" ]'
confere "com o ruim marcado o shim segue no pacote" '[ "$(shim b)" = "fabrica b" ]'
rm -f "$SH/casa/9.9/ruim" "$SH/casa/9.9/quedas"
confere "build que vive mais que a janela zera a conta" '(printf "#!/bin/sh\n# MEOW-PORTAL-PATCH-1\nsleep 3\n" > "$SH/casa/9.9/xdg-desktop-portal-cosmic"; shim >/dev/null; sleep 2; [ ! -e "$SH/casa/9.9/quedas" ])'
confere "o shim existe sempre: sem o dpkg o pacote de fábrica roda" '(r="$(MEOW_SHIM_FABRICA="$SH/fabrica" MEOW_SHIM_CASA="$T/nao-existe" PATH="/usr/bin:/bin" bash "$RAIZ/scripts/portal_shim.sh" a)"; [ "$r" = "fabrica a" ])'

printf '\n15. cuidar: a queda com a assinatura põe o build de lado; o ruim do shim se perdoa uma vez\n'
versoes "xdg-desktop-portal-cosmic=$VER1" "google-chrome-stable=146.0"
printf '%s\n' "$VER1" > "$T/patches/graficos.versao"
printf 'um\ndois\ntres\nquatro\ncinco\n' > "$T/fix/a/src/a.rs"; printf 'um\ndois\nMEOW-PORTAL-PATCH-1\ntres\nquatro\ncinco\n' > "$T/fix/b/src/a.rs"
printf 'portal p-portal.patch MEOW-PORTAL-PATCH-1\nportal p-wiring.patch -\ntoolkit p-toolkit.patch MEOW-TOOLKIT-PATCH-1\n' > "$T/patches/graficos.series"
rm -rf "$LIBEXEC" "$ESTADO/graficos" "$DROPIN"
graf aplicar
confere "build novo guardado de novo" '[ -x "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic" ]' "$(cat "$T/saida")"
agora="$(date +%s)"
printf '{"MESSAGE":"thread panicked at src/screencast_thread.rs:456","_EXE":"/usr/libexec/xdg-desktop-portal-cosmic","__REALTIME_TIMESTAMP":"%s"}\n' "$((agora * 1000000))" > "$T/journal.jsonl"
graf cuidar; rc=$?
confere "queda do portal do pacote não põe o build de lado" '[ "$rc" = 0 ] && [ ! -e "$LIBEXEC/$VER1/ruim" ]' "$(cat "$T/saida")"
for i in 1 2 3; do printf '{"MESSAGE":"create_frame sent before the previous frame was destroyed","_EXE":"%s","__REALTIME_TIMESTAMP":"%s"}\n' "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic" "$(( (agora + 5) * 1000000 + i ))"; done > "$T/journal.jsonl"
sleep 1; touch -d "@$((agora - 60))" "$LIBEXEC/$VER1/digital"
graf cuidar; rc=$?
confere "mil linhas do mesmo episódio contam uma queda, e uma queda só não põe o build de lado" '[ "$rc" = 0 ] && [ ! -e "$LIBEXEC/$VER1/ruim" ]' "$(cat "$T/saida")"
graf conferir; rc=$?
confere "o conferir diz a queda do portal da vez, sem divergir por ela" '[ "$rc" = 0 ] && grep -q "caiu 1 vez" "$T/saida"' "$(cat "$T/saida")"
printf '{"MESSAGE":"create_frame sent before the previous frame was destroyed","_EXE":"%s","__REALTIME_TIMESTAMP":"%s"}\n' "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic" "$(( (agora + 30) * 1000000 ))" >> "$T/journal.jsonl"
graf conferir; rc=$?
confere "cair de novo faz o conferir divergir, sem escrever" '[ "$rc" = 1 ] && [ ! -e "$LIBEXEC/$VER1/ruim" ] && grep -q "poria de lado" "$T/saida"' "$(cat "$T/saida")"
graf cuidar; rc=$?
confere "cair repetido põe o build de lado (caiu)" '[ "$rc" = 1 ] && [ "$(head -c 4 "$LIBEXEC/$VER1/ruim")" = caiu ] && grep -q "caiu 2 vez" "$T/saida"' "$(cat "$T/saida")"
confere "a queda vai para o log, sem tela e sem pendência" 'grep -q "pôs de lado o portal $VER1" "$ESTADO/meow.log" && [ ! -e "$ESTADO/precisa-de-gente.tsv" ] && ! grep -q "^graficos-" "$ESTADO/pendencias.tsv" 2>/dev/null' "$(cat "$ESTADO/meow.log" 2>&1)"
confere "a saída da queda não tropeça em função que não existe" '! grep -qiE "command not found|comando não encontrado" "$T/saida"' "$(cat "$T/saida")"
confere "o shim volta ao pacote" '[ "$(MEOW_SHIM_SO_DIZER=1 MEOW_SHIM_CASA="$LIBEXEC" PATH="$FALSO:$PATH" bash "$LIBEXEC/portal-shim")" = /usr/libexec/xdg-desktop-portal-cosmic ]'
graf cuidar; rc=$?
confere "o caiu não se perdoa" '[ "$rc" = 0 ] && [ -e "$LIBEXEC/$VER1/ruim" ]' "$(cat "$T/saida")"
rm -f "$LIBEXEC/$VER1/ruim" "$T/journal.jsonl"; date -Is > "$LIBEXEC/$VER1/ruim"
graf cuidar; rc=$?
confere "o ruim do shim, sem queda no registro, se perdoa uma vez" '[ "$rc" = 1 ] && [ ! -e "$LIBEXEC/$VER1/ruim" ] && [ -e "$LIBEXEC/$VER1/perdoado" ]' "$(cat "$T/saida")"
date -Is > "$LIBEXEC/$VER1/ruim"
graf conferir; rc=$?
confere "o ruim do shim faz o conferir divergir, para o doctor cuidar dele" '[ "$rc" = 1 ] && grep -qx "ruim=sim" <(graf estado; cat "$T/saida")' "$(cat "$T/saida")"
graf cuidar; rc=$?
confere "voltando a cair depois de perdoado, vai de lado de vez (caiu)" '[ "$rc" = 1 ] && [ "$(head -c 4 "$LIBEXEC/$VER1/ruim")" = caiu ]' "$(cat "$T/saida")"
n_cargo="$(wc -l < "$T/cargo.log")"
GR_COMPILAR=nao graf aplicar; rc=$?
confere "com o build de lado, o aplicar avisa que o pacote vale, não compila e não diz em dia" '[ "$(wc -l < "$T/cargo.log")" = "$n_cargo" ] && grep -q "de lado" "$T/saida" && ! grep -q "em dia" "$T/saida"' "$(cat "$T/saida")"
rm -f "$LIBEXEC/$VER1/ruim" "$LIBEXEC/$VER1/perdoado"

printf '\n16. sair do trilho sozinho quando o pacote traz a correção\n'
printf '%s\nfim %s\n' "$VER1" "$VER1" > "$T/patches/graficos.versao"
graf estado
confere "com o fim na versão instalada o estado é oficial" 'grep -qx estado=oficial "$T/saida"' "$(cat "$T/saida")"
n_cargo="$(wc -l < "$T/cargo.log")"
graf aplicar; rc=$?
confere "aplicar tira o drop-in e o shim, não compila e mantém a policy" '[ "$rc" = 1 ] && [ ! -e "$DROPIN" ] && [ ! -e "$LIBEXEC/portal-shim" ] && [ "$(wc -l < "$T/cargo.log")" = "$n_cargo" ] && [ -f "$POLICY" ]' "$(cat "$T/saida")"
graf aplicar; rc=$?
confere "a segunda passada sai 0" '[ "$rc" = 0 ]' "$(cat "$T/saida")"
ext "$RAIZ/scripts/extensoes_build.sh" graficos --estado
confere "no cartão a correção oficial conta como ativa" 'grep -qx instalada=sim "$T/saida" && grep -qx ativa=sim "$T/saida"' "$(cat "$T/saida")"
printf '%s\n' "$VER1" > "$T/patches/graficos.versao"
graf aplicar

printf '\n17. reverter devolve o portal e a policy ao pacote\n'
portal_vivo "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic"; sem_stream; rm -f "$T/reiniciou"
graf aplicar
graf reverter; rc=$?
confere "reverter sai 1, tira drop-in, shim e policy" '[ "$rc" = 1 ] && [ ! -e "$DROPIN" ] && [ ! -e "$LIBEXEC/portal-shim" ] && [ ! -e "$POLICY" ]' "$(cat "$T/saida")"
confere "o portal que rodava o build reiniciou para voltar ao do pacote" '[ -e "$T/reiniciou" ]'
confere "o build fica guardado" '[ -x "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic" ]'
portal_vivo /usr/libexec/xdg-desktop-portal-cosmic
f2="$(foto)"; n_sc="$(grep -c 'restart\|daemon-reload' "$T/systemctl.log")"; sleep 1
graf reverter; rc=$?
confere "o segundo reverter sai 0, sem escrever nem reiniciar" '[ "$rc" = 0 ] && [ "$(foto)" = "$f2" ] && [ "$(grep -c "restart\|daemon-reload" "$T/systemctl.log")" = "$n_sc" ]' "$(cat "$T/saida")"
portal_parado
graf aplicar
portal_vivo "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic"; stream; rm -f "$T/reiniciou"
graf reverter; rc=$?
confere "reverter com compartilhamento no ar não reinicia, e diz que espera" '[ "$rc" = 1 ] && [ ! -e "$T/reiniciou" ] && grep -q "espera" "$T/saida" && [ ! -e "$DROPIN" ]' "$(cat "$T/saida")"
sem_stream
graf reverter; rc=$?
confere "acabado o compartilhamento, o reverter seguinte devolve o portal" '[ "$rc" = 1 ] && [ -e "$T/reiniciou" ]' "$(cat "$T/saida")"
portal_parado
graf aplicar; : > "$T/sem-ponte"
graf reverter; rc=$?
confere "reverter sem a ponte: sai 3, não diz que voltou e a policy fica" '[ "$rc" = 3 ] && [ -f "$POLICY" ] && ! grep -q "voltaram" "$T/saida"' "$(cat "$T/saida")"
GRAFICOS_T=nao graf aplicar; rc=$?
confere "GRAFICOS=nao sem a ponte: sai 3, sem dizer que ficou de fábrica" '[ "$rc" = 3 ] && ! grep -q "ficam de fábrica" "$T/saida"' "$(cat "$T/saida")"
rm -f "$T/sem-ponte"; graf reverter; rm -f "$POLICY"; ln -s /nao/existe "$POLICY"
graf reverter; rc=$?
confere "reverter tira também o link quebrado no lugar da policy" '[ ! -e "$POLICY" ] && [ ! -L "$POLICY" ]' "$(cat "$T/saida")"

printf '\n18. GRAFICOS="nao" tira o que o meow pôs e fica quieto\n'
graf aplicar
GRAFICOS_T=nao graf aplicar; rc=$?
confere "com nao: sai 1 e tira drop-in, shim e policy" '[ "$rc" = 1 ] && [ ! -e "$DROPIN" ] && [ ! -e "$POLICY" ]' "$(cat "$T/saida")"
GRAFICOS_T=nao graf aplicar; rc=$?
confere "a segunda passada com nao sai 0" '[ "$rc" = 0 ]' "$(cat "$T/saida")"
GRAFICOS_T=nao graf estado
confere "o estado diz desligado" 'grep -qx estado=desligado "$T/saida"'
GRAFICOS_T=nao graf pendente
confere "desligado não entra na fila de build" '[ ! -s "$T/saida" ]'

printf '\n18b. o meow graficos grava a escolha, para o doctor das 5h não desfazer\n'
meow_g() { env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR HOME="$CASA" PATH="$FALSO:$PATH" NO_COLOR=1 LC_ALL=C MEOW_ESTADO="$ESTADO" \
    MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE="$PONTE" GR_REPO="$T/patches" GR_SERIE="$T/patches/graficos.series" GR_VERSOES="$T/patches/graficos.versao" \
    GR_POLICY="$POLICY" GR_PROC="$PROC" GR_ESPACO_KB=1 "$RAIZ/bin/meow" graficos "$@" > "$T/saida" 2>&1; }
printf 'GRAFICOS="sim"\n' > "$CASA/.config/meow/meow.conf"
meow_g aplicar; rc=$?
confere "aplicar pela CLI liga tudo e mantém sim" '[ -e "$DROPIN" ] && [ -f "$POLICY" ] && grep -qx "GRAFICOS=\"sim\"" "$CASA/.config/meow/meow.conf"' "$(cat "$T/saida")"
meow_g reverter; rc=$?
confere "reverter pela CLI tira tudo e grava nao" '[ ! -e "$DROPIN" ] && [ ! -e "$POLICY" ] && grep -qx "GRAFICOS=\"nao\"" "$CASA/.config/meow/meow.conf"' "$(cat "$T/saida")"
meow_g conferir; rc=$?
confere "depois do reverter o conferir fica calmo (o doctor não reaplica)" '[ "$rc" = 0 ] && [ ! -e "$DROPIN" ]' "$(cat "$T/saida")"
meow_g aplicar; rc=$?
confere "aplicar pela CLI volta a sim e liga de novo" '[ -e "$DROPIN" ] && [ -f "$POLICY" ] && grep -qx "GRAFICOS=\"sim\"" "$CASA/.config/meow/meow.conf"' "$(cat "$T/saida")"
meow_g compilar; rc=$?
confere "a CLI não compila fora da trava dos builds" '[ "$rc" = 2 ]' "$(cat "$T/saida")"
meow_g reverter; rm -f "$CASA/.config/meow/meow.conf"

printf '\n19. sem o pacote do portal: nada a fazer, sem escrever\n'
versoes "google-chrome-stable=146.0"
rm -f "$DROPIN"; rm -rf "$ETC/opt"
f3="$(foto)"
graf aplicar; rc=$?
confere "aplicar sai 3 e não escreve" '[ "$rc" = 3 ] && [ "$(foto)" = "$f3" ]' "$(cat "$T/saida")"
graf conferir; rc=$?
confere "conferir sai 3" '[ "$rc" = 3 ]'

printf '\n20. o resto da instalação enxerga o portal\n'
confere "o install tem a etapa, depois da gpu" 'grep -q "etapa_compositor etapa_gpu etapa_graficos etapa_extensoes_tema" "$RAIZ/install.sh" && sed -n "/^etapa_graficos()/,/^}/p" "$RAIZ/install.sh" | grep -q "EXTENSOES_FUNDO=1 .*extensoes_gesto.sh\" instalar graficos"'
confere "a chave GRAFICOS está no exemplo e na tabela chave-etapa" 'grep -q "^GRAFICOS=\"sim\"" "$RAIZ/meow.conf.exemplo" && grep -qP "^GRAFICOS\tgraficos\tnao$" "$RAIZ/assets/contratos/chave-etapa.tsv"'
confere "o doctor confere o portal logo depois do compositor" 'grep -q "areas patches graficos relogio" "$RAIZ/bin/meow" && grep -q "^chk_graficos()" "$RAIZ/bin/meow" && grep -q "^fix_graficos()" "$RAIZ/bin/meow"'
confere "o grupo graficos entra nos pacotes de compilar quando o portal está instalado" \
  'versoes "xdg-desktop-portal-cosmic=$VER1"; env HOME="$CASA" PATH="$FALSO:$PATH" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" MEOW_CONF="$CASA/.config/meow/meow.conf" EXTENSOES=- COMPOSITOR=nao FILES_MENU=nao bash -c ". \"$RAIZ/lib/comum.sh\"; meow_grupos_de_compilar" | grep -qx graficos'
confere "GRAFICOS=nao tira o grupo" '! env HOME="$CASA" PATH="$FALSO:$PATH" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" MEOW_CONF="$CASA/.config/meow/meow.conf" EXTENSOES=- COMPOSITOR=nao FILES_MENU=nao GRAFICOS=nao bash -c ". \"$RAIZ/lib/comum.sh\"; meow_grupos_de_compilar" | grep -qx graficos'
confere "o desinstalar reverte o portal" 'grep -q "graficos.sh\" reverter" "$RAIZ/lib/desinstalar.sh"'
confere "o pino da casa é de tipo graficos, com a chave GRAFICOS e ícone" 'grep -qx "TIPO=\"graficos\"" "$RAIZ/assets/extensoes/graficos.pino" && grep -qx "CHAVE_DO_CONF=\"GRAFICOS\"" "$RAIZ/assets/extensoes/graficos.pino" && [ -s "$RAIZ/assets/extensoes/icones/graficos.svg" ]'

printf '\n21. a página Extensões: o construtor entende o tipo graficos\n'
versoes "xdg-desktop-portal-cosmic=$VER1" "google-chrome-stable=146.0"
rm -rf "$LIBEXEC" "$ESTADO/graficos"
for i in 1 2; do ext env EXTENSOES_FUNDO=1 EXTENSOES_COMPILAR=1 "$RAIZ/scripts/extensoes_build.sh" graficos --aplicar; eval "rc$i=$?"; done
confere "a etapa do install com o build ainda por fazer converge: a segunda passada não escreve" '[ "$rc2" = 0 ] && [ ! -e "$LIBEXEC/$VER1" ]' "rc1=$rc1 rc2=$rc2; $(cat "$T/saida")"
ext "$RAIZ/scripts/extensoes_build.sh" graficos --reverter
ext "$RAIZ/scripts/extensoes_build.sh" graficos --estado
confere "estado: tipo graficos, não instalada, situação pendente" 'grep -qx tipo=graficos "$T/saida" && grep -qx instalada=nao "$T/saida" && grep -qx situacao=pendente "$T/saida"' "$(cat "$T/saida")"
ext env EXTENSOES_COMPILAR=1 EXTENSOES_FUNDO=0 "$RAIZ/scripts/extensoes_build.sh" graficos --aplicar; rc=$?
confere "aplicar com compilação: o portal fica pronto e ligado" '[ -x "$LIBEXEC/$VER1/xdg-desktop-portal-cosmic" ] && [ -e "$DROPIN" ] && [ -f "$POLICY" ]' "$(cat "$T/saida")"
ext "$RAIZ/scripts/extensoes_build.sh" graficos --estado
confere "estado: instalada, ativa e em dia" 'grep -qx instalada=sim "$T/saida" && grep -qx ativa=sim "$T/saida" && grep -qx situacao=ok "$T/saida"' "$(cat "$T/saida")"
n_cargo="$(wc -l < "$T/cargo.log")"
ext env EXTENSOES_COMPILAR=1 "$RAIZ/scripts/extensoes_build.sh" graficos --aplicar; rc=$?
confere "a segunda passada do construtor sai 0 e não compila" '[ "$rc" = 0 ] && [ "$(wc -l < "$T/cargo.log")" = "$n_cargo" ]' "$(cat "$T/saida")"
ext env EXTENSOES_REFAZER=1 EXTENSOES_COMPILAR=1 "$RAIZ/scripts/extensoes_build.sh" graficos --aplicar
confere "o «Refazer» compila de novo mesmo com build pronto" '[ "$(wc -l < "$T/cargo.log")" = "$((n_cargo + 1))" ]' "$(cat "$T/saida")"
ext "$RAIZ/scripts/extensoes_build.sh" graficos --reverter; rc=$?
confere "reverter pelo construtor tira drop-in e policy" '[ ! -e "$DROPIN" ] && [ ! -e "$POLICY" ]' "$(cat "$T/saida")"
confere "o servidor lê o tipo graficos como build" 'grep -q "EXT_TIPOS_DE_BUILD = (\"compositor\", \"menu\", \"graficos\")" "$RAIZ/app/servidor.py" && grep -q "graficos: \"portal\"" "$RAIZ/app/pagina/extensoes.js"'

[ "$falhas" = 0 ] && printf '\nok: o portal e a policy entram idempotentes, o shim existe sempre e a série recusa quando não entra\n'
exit $((falhas > 0))

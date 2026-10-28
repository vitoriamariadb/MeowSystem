#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

SYS="$T/sys/bus/pci/devices"; ENVF="$T/etc/environment"; ORIG="$T/var/environment.original"
CASA="$T/casa"; FALSO="$T/falso"; PONTE="$T/ponte/ponte_root.sh"
mkdir -p "$SYS" "$T/etc" "$T/var" "$CASA/.local/state/meowsystem" "$FALSO" "$T/ponte"

placa() {
  local end="$1" classe="$2" vendor="$3" device="$4" boot="$5" render="${6:-sim}" d="$SYS/$1"
  mkdir -p "$d"
  printf '%s\n' "$classe" > "$d/class"; printf '%s\n' "$vendor" > "$d/vendor"; printf '%s\n' "$device" > "$d/device"
  [ "$boot" = - ] || printf '%s\n' "$boot" > "$d/boot_vga"
  [ "$render" = sim ] && mkdir -p "$d/drm/renderD128" "$d/drm/card0"
  return 0
}
limpa_sys() { rm -rf "$SYS"; mkdir -p "$SYS"; }
hibrida() {
  limpa_sys
  placa 0000:00:02.0 0x030000 0x8086 0xa720 1
  placa 0000:01:00.0 0x030000 0x10de 0x28a0 0
  placa 0000:00:1f.3 0x040300 0x8086 0x51ca - nao
  placa 0000:02:00.0 0x020000 0x10ec 0x8168 -
}

sed -e "s#^export PATH=.*#export PATH=\"$FALSO:/usr/bin:/bin\"#" -e 's/ -o root -g root//g' \
    -e "s#^SYS_PCI=.*#SYS_PCI=$SYS#" -e "s#^ENV_SISTEMA=.*#ENV_SISTEMA=$ENVF#" \
    -e "s#^ENV_ORIGINAL=.*#ENV_ORIGINAL=$ORIG#" -e 's#^anotar() {#anotar() { return 0#' \
    "$RAIZ/scripts/ponte_root.sh" > "$PONTE"
chmod 755 "$PONTE"
cat > "$FALSO/sudo" <<FIM
#!/bin/sh
if [ "\$1" = "-n" ] && [ "\$2" = "$PONTE" ] && [ ! -f "$T/sem-ponte" ]; then shift; exec "\$@"; fi
exit 1
FIM
chmod 755 "$FALSO/sudo"

ponte() { env -i PATH=/usr/bin:/bin bash "$PONTE" "$@" > "$T/saida" 2>&1; }
script() {
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR HOME="$CASA" PATH="$FALSO:$PATH" MEOW_ESTADO="$CASA/.local/state/meowsystem" \
      MEOW_CONF="$T/nao-existe.conf" MEOW_PONTE="$PONTE" MEOW_GPU_PCI="$SYS" MEOW_GPU_ENV="$ENVF" MEOW_GPU_ORIGINAL="$ORIG" \
      "$@" bash "$RAIZ/scripts/gpu_compositor.sh" ${ACAO_GPU:-conferir} > "$T/saida" 2>&1
}
detecta_no_script() { ACAO_GPU=detectar script GPU_COMPOSITOR=dedicada; cat "$T/saida"; }
valor_gravado() { sed -n 's/^COSMIC_RENDER_DEVICE="\(.*\)"$/\1/p' "$ENVF"; }
marca() { stat -c '%i %Y %s' "$ENVF" 2>/dev/null; }
antes_do_install() { printf '# env do sistema\nPATH="/usr/local/sbin:/usr/bin"\nLANG=pt_BR.UTF-8\n' > "$ENVF"; rm -f "$ORIG"; }

printf '\n1. híbrida Intel+NVIDIA: grava a NVIDIA no formato do cosmic-comp\n'
hibrida; antes_do_install
ponte gpu-compositor; rc=$?
confere "sai 0 e avisa que mudou" '[ "$rc" = 0 ] && grep -qx mudou "$T/saida"' "$(cat "$T/saida")"
confere "a linha é COSMIC_RENDER_DEVICE=\"0x10de:0x28a0\"" 'grep -qxF "COSMIC_RENDER_DEVICE=\"0x10de:0x28a0\"" "$ENVF"' "$(cat "$ENVF")"
confere "as outras linhas seguem como estavam" 'grep -qxF "LANG=pt_BR.UTF-8" "$ENVF" && grep -qxF "PATH=\"/usr/local/sbin:/usr/bin\"" "$ENVF" && [ "$(grep -c . "$ENVF")" = 4 ]'
confere "o /etc/environment de antes ficou guardado, byte a byte" '[ "$(cat "$ORIG")" = "$(printf "# env do sistema\nPATH=\"/usr/local/sbin:/usr/bin\"\nLANG=pt_BR.UTF-8")" ]'
script GPU_COMPOSITOR=dedicada; rc=$?
confere "o conferir do doctor diz ok" '[ "$rc" = 0 ] && grep -q "0x10de:0x28a0" "$T/saida"' "$(cat "$T/saida")"
confere "a detecção do script bate com a da ponte" '[ "$(detecta_no_script)" = "$(valor_gravado)" ] && [ -n "$(detecta_no_script)" ]' "$(detecta_no_script) / $(valor_gravado)"

printf '\n2. uma GPU só: não grava\n'
limpa_sys; placa 0000:00:02.0 0x030000 0x8086 0xa720 1; antes_do_install
cp "$ENVF" "$T/env-igual"; m="$(marca)"
ponte gpu-compositor; rc=$?
confere "sai 0, sem escrever e sem guardar cópia" '[ "$rc" = 0 ] && [ "$(marca)" = "$m" ] && cmp -s "$ENVF" "$T/env-igual" && [ ! -e "$ORIG" ] && ! grep -qx mudou "$T/saida"' "$(cat "$T/saida")"
script GPU_COMPOSITOR=dedicada; rc=$?
confere "o doctor dá ok e diz que há uma GPU só" '[ "$rc" = 0 ] && grep -q "uma GPU" "$T/saida"' "$(cat "$T/saida")"
limpa_sys; placa 0000:00:02.0 0x030000 0x8086 0xa720 1; placa 0000:01:00.0 0x030000 0x10de 0x28a0 0 nao
ponte gpu-compositor; rc=$?
confere "a segunda placa sem render node não conta como GPU" '[ "$rc" = 0 ] && ! grep -q COSMIC_RENDER_DEVICE "$ENVF"'

printf '\n3. a segunda passada não escreve\n'
hibrida; antes_do_install; ponte gpu-compositor
m="$(marca)"; sleep 1
ponte gpu-compositor; rc=$?
confere "mesmo inode, mesma hora, mesmo tamanho, nada impresso" '[ "$rc" = 0 ] && [ "$(marca)" = "$m" ] && [ ! -s "$T/saida" ]' "$(cat "$T/saida")"
ponte gpu-compositor-tirar; ponte gpu-compositor-tirar; m="$(marca)"; sleep 1
ponte gpu-compositor-tirar; rc=$?
confere "o -tirar repetido também não escreve" '[ "$rc" = 0 ] && [ "$(marca)" = "$m" ] && [ ! -s "$T/saida" ]'

printf '\n4. trocar a placa troca a linha, sem mexer nas outras\n'
hibrida; antes_do_install; ponte gpu-compositor
printf 'EDITOR=nano\n' >> "$ENVF"
limpa_sys
placa 0000:00:02.0 0x030000 0x1002 0x164e 1
placa 0000:03:00.0 0x030000 0x10de 0x2684 0
placa 0000:04:00.0 0x030000 0x1002 0x73bf 0
ponte gpu-compositor; rc=$?
confere "vira a NVIDIA nova" '[ "$rc" = 0 ] && grep -qxF "COSMIC_RENDER_DEVICE=\"0x10de:0x2684\"" "$ENVF" && [ "$(grep -c COSMIC_RENDER_DEVICE "$ENVF")" = 1 ]' "$(cat "$ENVF")"
confere "e o script detecta a mesma" '[ "$(detecta_no_script)" = "$(valor_gravado)" ]' "$(detecta_no_script) / $(valor_gravado)"
confere "a linha ficou no mesmo lugar e o resto igual" '[ "$(grep -v COSMIC_RENDER_DEVICE "$ENVF")" = "$(printf "# env do sistema\nPATH=\"/usr/local/sbin:/usr/bin\"\nLANG=pt_BR.UTF-8\nEDITOR=nano")" ] && [ "$(sed -n 4p "$ENVF")" = "COSMIC_RENDER_DEVICE=\"0x10de:0x2684\"" ]' "$(cat "$ENVF")"
confere "o de antes continua o primeiro, não o intermediário" '! grep -q COSMIC_RENDER_DEVICE "$ORIG"'
limpa_sys
placa 0000:00:02.0 0x030000 0x10de 0x28a0 1
placa 0000:03:00.0 0x030000 0x1002 0x73bf 0
placa 0000:04:00.0 0x030000 0x1002 0x73ff 0
ponte gpu-compositor
confere "sem NVIDIA, vence a primeira de boot_vga 0 (nunca a da tela de boot)" 'grep -qxF "COSMIC_RENDER_DEVICE=\"0x1002:0x73bf\"" "$ENVF"' "$(cat "$ENVF")"
confere "e o script detecta o mesmo" '[ "$(detecta_no_script)" = "$(valor_gravado)" ]' "$(detecta_no_script) / $(valor_gravado)"

printf '\n5. -tirar devolve o arquivo byte a byte\n'
hibrida; antes_do_install; cp "$ENVF" "$T/env-original"; ponte gpu-compositor
ponte gpu-compositor-tirar; rc=$?
confere "o arquivo é idêntico ao de antes e a cópia some" '[ "$rc" = 0 ] && cmp -s "$ENVF" "$T/env-original" && [ ! -e "$ORIG" ]' "$(cat "$ENVF")"
printf 'PATH="/usr/bin"\nLANG=pt_BR.UTF-8' > "$ENVF"; rm -f "$ORIG"; cp "$ENVF" "$T/env-sem-quebra"
ponte gpu-compositor; ponte gpu-compositor-tirar
confere "mesmo sem a quebra de linha final" 'cmp -s "$ENVF" "$T/env-sem-quebra"' "$(od -c "$ENVF" | tail -3)"
printf 'PATH="/usr/bin"\nCOSMIC_RENDER_DEVICE="0x8086:0xa720"\nLANG=pt_BR.UTF-8\n' > "$ENVF"; rm -f "$ORIG"; cp "$ENVF" "$T/env-com-linha-dela"
ponte gpu-compositor
confere "uma linha que já era dela é trocada" 'grep -qxF "COSMIC_RENDER_DEVICE=\"0x10de:0x28a0\"" "$ENVF"'
ponte gpu-compositor-tirar
confere "e o -tirar devolve a linha dela" 'cmp -s "$ENVF" "$T/env-com-linha-dela"' "$(cat "$ENVF")"
antes_do_install
ponte gpu-compositor-tirar; rc=$?
confere "sem cópia guardada o -tirar não toca no arquivo" '[ "$rc" = 0 ] && ! grep -q COSMIC_RENDER_DEVICE "$ENVF"'
printf 'COSMIC_RENDER_DEVICE="0x10de:0x25a2"\n' >> "$ENVF"; cp "$ENVF" "$T/env-aurora"; rm -f "$ORIG"
ponte gpu-compositor-tirar
confere "linha que não é do MeowSystem (sem cópia guardada) fica" 'cmp -s "$ENVF" "$T/env-aurora"'

printf '\n6. GPU_COMPOSITOR=padrao tira a linha que o MeowSystem gravou\n'
hibrida; antes_do_install; cp "$ENVF" "$T/env-original"
ACAO_GPU=aplicar script GPU_COMPOSITOR=dedicada; rc=$?
confere "aplicar dedicada grava pela ponte e sai 1 (mudou)" '[ "$rc" = 1 ] && grep -qxF "COSMIC_RENDER_DEVICE=\"0x10de:0x28a0\"" "$ENVF"' "$(cat "$T/saida")"
ACAO_GPU=aplicar script GPU_COMPOSITOR=dedicada; rc=$?
confere "a segunda passada sai 0" '[ "$rc" = 0 ]' "$(cat "$T/saida")"
ACAO_GPU=conferir script GPU_COMPOSITOR=padrao; rc=$?
confere "padrao com a linha nossa: o doctor diverge" '[ "$rc" = 1 ]' "$(cat "$T/saida")"
confere "e a conferência não escreveu" 'grep -qxF "COSMIC_RENDER_DEVICE=\"0x10de:0x28a0\"" "$ENVF"'
ACAO_GPU=aplicar script GPU_COMPOSITOR=padrao; rc=$?
confere "aplicar padrao tira a linha e devolve o arquivo" '[ "$rc" = 1 ] && cmp -s "$ENVF" "$T/env-original"' "$(cat "$T/saida")"
ACAO_GPU=aplicar script GPU_COMPOSITOR=padrao; rc=$?
confere "a segunda passada sai 0" '[ "$rc" = 0 ]' "$(cat "$T/saida")"
ACAO_GPU=reverter script GPU_COMPOSITOR=dedicada; rc=$?
confere "reverter sem nada nosso sai 0" '[ "$rc" = 0 ]' "$(cat "$T/saida")"
ACAO_GPU=aplicar script GPU_COMPOSITOR=dedicada
ACAO_GPU=reverter script GPU_COMPOSITOR=dedicada; rc=$?
confere "reverter (o desinstalar) tira a linha" '[ "$rc" = 1 ] && cmp -s "$ENVF" "$T/env-original"' "$(cat "$T/saida")"

printf '\n7. o que não fecha diz o porquê, sem mandar digitar\n'
hibrida; antes_do_install; : > "$T/sem-ponte"
ACAO_GPU=aplicar script GPU_COMPOSITOR=dedicada; rc=$?
confere "sem a ponte: sai 3, não escreve e não manda digitar" '[ "$rc" = 3 ] && ! grep -q COSMIC_RENDER_DEVICE "$ENVF" && ! grep -qiE "digite|rode |sudo" "$T/saida"' "$(cat "$T/saida")"
rm -f "$T/sem-ponte"
ACAO_GPU=conferir script GPU_COMPOSITOR=dedicada; rc=$?
confere "o conferir diverge (1), diz as duas placas e que vale no próximo login" '[ "$rc" = 1 ] && grep -q "ausente" "$T/saida" && grep -q "0x10de:0x28a0" "$T/saida" && grep -q "próximo login" "$T/saida"' "$(cat "$T/saida")"
confere "e não escreveu" '! grep -q COSMIC_RENDER_DEVICE "$ENVF"'
ponte gpu-compositor algo; rc=$?
confere "argumento é recusado" '[ "$rc" = 2 ] && ! grep -q COSMIC_RENDER_DEVICE "$ENVF"'

printf '\n8. a regra do sudo libera os dois verbos, sem curinga\n'
env -i PATH=/usr/bin:/bin USER=teste bash "$PONTE" regra-sudo > "$T/regra" 2>&1
confere "gpu-compositor e gpu-compositor-tirar estão na regra" 'grep -qE "ponte_root.sh gpu-compositor, \\\\$" "$T/regra" && grep -qE "ponte_root.sh gpu-compositor-tirar, \\\\$" "$T/regra"'
confere "a regra segue sem curinga" '! grep -q "\*" <(grep -v "^#" "$T/regra")'
env -i PATH=/usr/bin:/bin bash "$PONTE" ajuda > "$T/ajuda" 2>&1
confere "o ajuda lista os dois" 'grep -q "gpu-compositor ·" "$T/ajuda" && grep -q "gpu-compositor-tirar" "$T/ajuda"'

printf '\n9. o doctor e o instalador conhecem a GPU\n'
confere "chk_gpu e fix_gpu existem e gpu está no VERIFICAVEIS" 'grep -q "^chk_gpu()" "$RAIZ/bin/meow" && grep -q "^fix_gpu()" "$RAIZ/bin/meow" && grep -q "^VERIFICAVEIS=.* gpu " "$RAIZ/bin/meow"'
confere "sem a ponte o doctor não promete consertar a gpu" 'grep -q "SEM_CONSERTO=\".* gpu .*\"" "$RAIZ/bin/meow"'
confere "etapa_gpu está na lista do install, depois do compositor" 'grep -q "etapa_compositor etapa_gpu " "$RAIZ/install.sh"'
confere "o meow.conf.exemplo tem a chave, de fábrica dedicada" 'grep -qE "^GPU_COMPOSITOR=\"dedicada\" +# dedicada \| padrao" "$RAIZ/meow.conf.exemplo"'
confere "o desinstalar reverte" 'grep -q "gpu_compositor.sh\" reverter" "$RAIZ/lib/desinstalar.sh"'

[ "$falhas" = 0 ] && printf '\nok: a GPU do compositor é detectada em cada máquina\n'
exit $((falhas > 0))

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

mkdir -p "$T/bin"
for c in sudo pkexec su systemctl systemd-run pkill apt apt-get; do
  printf '#!/bin/sh\nexit 1\n' > "$T/bin/$c"
done
for c in update-desktop-database gtk-update-icon-cache fc-cache; do
  printf '#!/bin/sh\nexit 0\n' > "$T/bin/$c"
done
cat > "$T/bin/gsettings" <<FIM
#!/bin/sh
case "\$1" in
  get) f="$T/v.\$3"; [ -f "\$f" ] || exit 1; printf "'%s'\\n" "\$(cat "\$f")" ;;
  set) printf '%s' "\$4" > "$T/v.\$3"; echo "set \$3" >> "$T/gsettings.log" ;;
  reset) rm -f "$T/v.\$3"; echo "reset \$3" >> "$T/gsettings.log" ;;
  *) exit 1 ;;
esac
FIM
chmod 755 "$T/bin"/*

CASA="$T/casa"; E="$T/estado"; CLONE="$T/clone"
valor() { cat "$T/v.$1" 2>/dev/null || printf 'AUSENTE'; }
copia() { cat "$E"/backups/*-valores-PRIMEIRO-pre-instalacao/"$1" 2>/dev/null || printf 'AUSENTE'; }
passo() {
  local script="$1"; shift
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
    BOTOES_LADO=esquerda CURSOR=x "$@" "$RAIZ/scripts/$script.sh" aplicar > "$T/saida" 2>&1
}
zerar() {
  rm -rf "$CASA" "$E" "$T"/v.* "$T/gsettings.log"
  mkdir -p "$CASA/.local/share/icons/x-cursors/cursors" "$CASA/.config/gtk-3.0" "$CASA/.config/gtk-4.0" "$E"
  printf '%s' "$1" > "$T/v.button-layout"
  printf '%s' "$2" > "$T/v.cursor-theme"
}
marcar() { sleep 1; touch "$T/marco"; }
escritos() { find "$E/backups" -newer "$T/marco" -type f 2>/dev/null | sort; }
desinstalar() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" NO_COLOR=1 USER=t MEOW_ESTADO="$E" MEOW_CACHE="$T/cache" MEOW_RAIZ="$CLONE" \
    MEOW_CONF="$CASA/.config/meow/meow.conf" XDG_DATA_HOME="$CASA/.local/share" XDG_CONFIG_HOME="$CASA/.config" "$@" \
    bash -c '. "$MEOW_RAIZ/scripts/lib/comum.sh"; . "$MEOW_RAIZ/scripts/lib/desinstalar.sh"; meow_desinstalar' > "$T/saida" 2>&1
}
mkdir -p "$CLONE/scripts"; cp -a "$RAIZ/scripts/lib" "$CLONE/scripts/"

echo "== 0. o ensaio do install não guarda nada"
zerar 'menu:close' 'Adwaita'
passo botoes_lado MEOW_DRY_RUN=1; passo cursor MEOW_DRY_RUN=1
igual "o ensaio não cria cópia em backups/" "$(find "$E" -path '*backups*' 2>/dev/null | wc -l)" 0
igual "o ensaio não escreve no gsettings" "$(cat "$T/gsettings.log" 2>/dev/null)" ""
zerar ':minimize,maximize,close' 'x-cursors'
passo botoes_lado MEOW_DRY_RUN=1 BOTOES_LADO=direita; passo cursor MEOW_DRY_RUN=1
igual "o ensaio também não cria a cópia vazia" "$(find "$E" -path '*backups*' 2>/dev/null | wc -l)" 0

echo "== 1. a primeira escrita guarda o valor de antes"
zerar 'menu:close' 'Adwaita'
passo botoes_lado; passo cursor
igual "button-layout foi escrito pelo Meow" "$(valor button-layout)" 'menu,close:'
igual "cursor-theme foi escrito pelo Meow" "$(valor cursor-theme)" 'x-cursors'
igual "a cópia guarda o button-layout de antes" "$(copia button-layout)" 'menu:close'
igual "a cópia guarda o cursor-theme de antes" "$(copia cursor-theme)" 'Adwaita'
igual "as duas cópias moram numa pasta só, no molde do PRIMEIRO" \
  "$(find "$E/backups" -maxdepth 1 -name '*-valores-PRIMEIRO-pre-instalacao' -type d | wc -l)" 1

echo "== 2. a segunda passada não regrava a cópia"
marcar
passo botoes_lado; passo cursor
igual "nada novo escrito em backups/" "$(escritos)" ""
igual "o gsettings não recebeu escrita nova" "$(grep -c . "$T/gsettings.log")" 2

echo "== 3. uma troca depois não troca o valor de antes"
passo botoes_lado BOTOES_LADO=direita
igual "o lado mudou" "$(valor button-layout)" ':close,menu'
igual "a cópia segue com o de antes" "$(copia button-layout)" 'menu:close'

echo "== 4. o desinstalar devolve os dois valores"
desinstalar MEOW_DRY_RUN=1
igual "o ensaio não mexe no button-layout" "$(valor button-layout)" ':close,menu'
igual "o ensaio não mexe no cursor-theme" "$(valor cursor-theme)" 'x-cursors'
desinstalar
igual "button-layout voltou ao de antes" "$(valor button-layout)" 'menu:close'
igual "cursor-theme voltou ao de antes" "$(valor cursor-theme)" 'Adwaita'

echo "== 5. máquina que já era do Meow não inventa um valor de antes"
zerar ':minimize,maximize,close' 'x-cursors'
passo botoes_lado BOTOES_LADO=direita
passo cursor
igual "button-layout já era nosso: a cópia fica vazia" "$(copia button-layout)" ''
igual "cursor-theme já era nosso: a cópia fica vazia" "$(copia cursor-theme)" ''
passo botoes_lado BOTOES_LADO=esquerda
igual "uma troca de lado depois não grava o nosso como de antes" "$(copia button-layout)" ''
desinstalar
igual "sem valor de antes, o desinstalar devolve o padrão do sistema (button-layout)" "$(valor button-layout)" 'AUSENTE'
igual "sem valor de antes, o desinstalar devolve o padrão do sistema (cursor-theme)" "$(valor cursor-theme)" 'AUSENTE'

if [ "$falhas" -gt 0 ]; then
  printf '\n%d falha(s) nos valores de antes.\n' "$falhas" >&2
  exit 1
fi
printf '\nbutton-layout e cursor-theme guardam o valor de antes na primeira escrita, e o desinstalar o devolve.\n'

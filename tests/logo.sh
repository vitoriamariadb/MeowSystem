#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d -p "${TMPDIR:-/tmp}" meow-logo.XXXXXX)" || exit 2
trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

FALSO="$T/falso"; CASA="$T/casa"
TEMA="$CASA/.local/share/icons/MeowSystem-Icons"; CACHE="$TEMA/icon-theme.cache"
BOTAO="$TEMA/scalable/apps/com.system76.CosmicPanelAppButton.svg"
mkdir -p "$FALSO" "$CASA/.config/meow" "$TEMA/scalable/apps"
for b in sudo pkexec su pkill systemctl; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/proibido.log"\nexit 1\n' "$b" "$T" > "$FALSO/$b"
done
cat > "$FALSO/gtk-update-icon-cache" <<FIM
#!/bin/sh
echo "\$*" >> "$T/reindexa.log"
for a in "\$@"; do [ -d "\$a" ] && : > "\$a/icon-theme.cache"; done
exit 0
FIM
chmod 755 "$FALSO"/*
printf '[Icon Theme]\nName=MeowSystem-Icons\nDirectories=scalable/apps\n' > "$TEMA/index.theme"

logo() {
  env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    LOGO_MODO=fixo LOGO_RECICLAR=nao "$@" bash "$RAIZ/scripts/logo.sh" > "$T/saida" 2>&1
}
linhas() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
mais_novos() { find "$TEMA" -newer "$CACHE" | sort; }

mapfile -t NOMES < <(env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
  bash "$RAIZ/scripts/logo.sh" listar 2>/dev/null | awk '$1 == ">>" {print $2}' | head -2)
[ "${#NOMES[@]}" = 2 ] || { echo "erro: o acervo de fábrica não tem dois mascotes: ${NOMES[*]:-}"; exit 2; }

printf '\n1. o mascote da dock entra no tema e a cache acompanha\n'
: > "$CACHE"; sleep 0.1
logo LOGO="${NOMES[0]}"; rc=$?
igual "aplicar sai 1" "$rc" 1
[ -s "$BOTAO" ] && ok "o botão da dock está no tema" || falha "o botão não foi escrito: $(cat "$T/saida")"
igual "nada no tema é mais novo que a cache" "$(mais_novos)" ""
igual "reindexou uma vez, o tema inteiro" "$(cat "$T/reindexa.log" 2>/dev/null)" "-q -f $TEMA"

printf '\n2. a segunda passada não escreve nem reindexa\n'
sleep 0.1; touch "$T/marco"
logo LOGO="${NOMES[0]}"; rc=$?
igual "sai 0" "$rc" 0
igual "sem reindexar de novo" "$(linhas "$T/reindexa.log")" 1
igual "e sem escrever no tema" "$(find "$TEMA" -newer "$T/marco")" ""

printf '\n3. a troca de mascote (a de fase, de dia para noite) também\n'
antes="$(md5sum < "$BOTAO")"
logo LOGO="${NOMES[1]}"; rc=$?
igual "sai 1" "$rc" 1
[ "$(md5sum < "$BOTAO")" != "$antes" ] && ok "o botão trocou de desenho" || falha "o botão não trocou"
igual "nada no tema é mais novo que a cache" "$(mais_novos)" ""
igual "reindexou de novo" "$(linhas "$T/reindexa.log")" 2

printf '\n4. tema sem cache segue sem cache\n'
rm -f "$CACHE"
logo LOGO="${NOMES[0]}"; rc=$?
igual "sai 1" "$rc" 1
[ ! -e "$CACHE" ] && ok "a troca não cria a cache" || falha "a troca criou a cache"
igual "nem chama o reindexador" "$(linhas "$T/reindexa.log")" 2

printf '\n5. o conferir não reindexa\n'
: > "$CACHE"
logo LOGO="${NOMES[1]}" MEOW_DRY_RUN=1; rc=$?
igual "seco sai 1" "$rc" 1
igual "sem chamar o reindexador" "$(linhas "$T/reindexa.log")" 2
igual "nada de sudo, pkill ou systemctl" "$(cat "$T/proibido.log" 2>/dev/null)" ""

printf '\n'
if [ "$falhas" = 0 ]; then echo "logo: tudo certo"; exit 0; fi
echo "logo: $falhas falha(s)"; exit 1

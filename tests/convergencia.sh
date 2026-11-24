#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; FALSO="$(mktemp -d)"; trap 'rm -rf "$H" "$FALSO"' EXIT

cat > "$FALSO/sudo" <<'FIM'
#!/bin/sh
printf 'sudo: recusado pelo tests/convergencia.sh\n' >&2
exit 1
FIM
chmod 755 "$FALSO/sudo"

cat > "$FALSO/systemctl" <<FIM
#!/bin/bash
case " \$* " in
  *" is-active "*|*" is-enabled "*|*" is-failed "*|*" show "*|*" status "*|*" cat "*\
  |*" list-units "*|*" list-unit-files "*|*" list-timers "*|*" show-environment "*\
  |*" get-default "*|*" --version "*)
    IFS=: read -ra _dirs <<< "\$PATH"
    for _d in "\${_dirs[@]}"; do
      [ "\$_d" = "$FALSO" ] && continue
      [ -x "\$_d/systemctl" ] && exec "\$_d/systemctl" "\$@"
    done
    exit 1 ;;
esac
printf 'systemctl: recusado pelo tests/convergencia.sh (%s)\n' "\$*" >&2
exit 1
FIM
chmod 755 "$FALSO/systemctl"

PASSAGENS="${PASSAGENS:-3}"

JOGO=1715980
mkdir -p "$H/.steam/steam/steamapps" "$H/.steam/steam/appcache/librarycache/$JOGO"
printf '"AppState"\n{\n\t"appid"\t\t"%s"\n\t"name"\t\t"Jogo Falso"\n}\n' "$JOGO" \
  > "$H/.steam/steam/steamapps/appmanifest_$JOGO.acf"
convert -size 600x900 xc:'#7f3fbf' "$H/.steam/steam/appcache/librarycache/$JOGO/library_capsule.jpg" 2>/dev/null \
  || { printf 'FALHOU: sem convert para fabricar a capa do jogo falso\n' >&2; exit 1; }

datas_do_hicolor() {
  find "$H/.local/share/icons/hicolor" -type d -printf '%p %T@\n' 2>/dev/null | sort
}

correr() {
  env -i PATH="$FALSO:$PATH" HOME="$H" USER="${USER:-t}" \
    MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 MEOW_PONTE=/nao/existe \
    bash "$RAIZ/install.sh" 2>&1
}

saida=""
for i in $(seq 1 "$PASSAGENS"); do
  [ "$i" = "$PASSAGENS" ] && antes_da_ultima="$(datas_do_hicolor)"
  saida="$(correr)"
  printf 'passagem %s: %s\n' "$i" \
    "$(printf '%s' "$saida" | grep 'mexeu:' || printf 'nada mudou')"
done

if printf '%s' "$saida" | grep -q 'mexeu:'; then
  printf 'FALHOU: ainda mexia na passagem %s — alguma etapa não é idempotente\n' \
    "$PASSAGENS" >&2
  exit 1
fi
if ! find "$H/.local/share/icons/hicolor" -name "meow-steam-$JOGO.png" 2>/dev/null | grep -q .; then
  printf 'FALHOU: o jogo falso da Steam não ganhou ícone; a prova não cobre o plantio\n' >&2
  exit 1
fi
if [ "$antes_da_ultima" != "$(datas_do_hicolor)" ]; then
  printf 'FALHOU: a última passagem mexeu nas pastas do hicolor\n' >&2
  exit 1
fi
printf 'ok: convergiu em %s passagens\n' "$PASSAGENS"

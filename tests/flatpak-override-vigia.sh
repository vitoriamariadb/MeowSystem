#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"; ESTADO="$CASA/.local/state/meowsystem"
OVERRIDE="$CASA/.local/share/flatpak/overrides/global"
mkdir -p "$T/bin" "$ESTADO" "$CASA/.config/meow" "$(dirname "$OVERRIDE")"
printf '%s' "$RAIZ" > "$ESTADO/raiz"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/flatpak"
chmod 755 "$T/bin/flatpak"
: > "$CASA/.config/meow/meow.conf"

P="$RAIZ/dados/systemd/meow-flatpak-override.path"
S="$RAIZ/dados/systemd/meow-flatpak-override.service"
grep -qx 'PathChanged=%h/.local/share/flatpak/overrides/global' "$P" \
  && grep -qx 'Unit=meow-flatpak-override.service' "$P" && grep -qx 'WantedBy=default.target' "$P" \
  && ok "o vigia olha só o overrides/global do usuário e chama o serviço dele" \
  || falha "o meow-flatpak-override.path não vigia o overrides/global"
grep -q 'flatpak_tema.sh" aplicar libadwaita' "$S" \
  && ok "e o serviço chama a conferência do libadwaita do flatpak_tema.sh" \
  || falha "o meow-flatpak-override.service não chama o flatpak_tema.sh aplicar libadwaita"
grep -qx 'SuccessExitStatus=1 3' "$S" \
  && ok "mexeu (1) e sem dependência (3) são sucesso; o erro (2) continua falha no journal" \
  || falha "o SuccessExitStatus do meow-flatpak-override.service não é «1 3»"
grep -q 'meow-flatpak-override.path meow-flatpak-override.service' "$RAIZ/scripts/lib/desinstalar.sh" \
  && ok "e o desinstalar tira o par" || falha "o desinstalar esquece o meow-flatpak-override"

linha() { sed -n "s/^$1=//p" "$S" | head -n 1 | sed "s|%h|$CASA|g"; }
amb() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" LANG=C.UTF-8 NO_COLOR=1 sh -c "$1" 2>&1
}
servico() {
  amb "$(linha ExecCondition | sed "s|^/bin/sh -c '||; s|'\$||")" >/dev/null || return 9
  amb "$(linha ExecStart)"
}

printf '[Context]\nshared=ipc;\nfilesystems=!home;xdg-config/gtk-3.0:ro;xdg-config/gtk-4.0:ro;xdg-data/color-schemes:ro;\n\n[Environment]\nICON_THEME=MeowSystem-Icons\n' > "$OVERRIDE"
saida="$(servico)"; rc=$?
if [ "$rc" = "1" ] && ! grep -q 'xdg-config/gtk-4.0' "$OVERRIDE" \
   && grep -q 'xdg-config/gtk-3.0:ro' "$OVERRIDE" && grep -q 'ICON_THEME=MeowSystem-Icons' "$OVERRIDE"; then
  ok "o override com xdg-config/gtk-4.0:ro é limpo pelo serviço, e o resto dele fica"
else
  falha "o serviço não limpou o gtk-4.0:ro (rc=$rc)" "$saida"
fi

marco="$(stat -c '%Y.%y' "$OVERRIDE")"; antes="$(cat "$OVERRIDE")"; sleep 1.1
saida="$(servico)"; rc=$?
[ "$rc" = "0" ] && [ "$marco" = "$(stat -c '%Y.%y' "$OVERRIDE")" ] && [ "$antes" = "$(cat "$OVERRIDE")" ] \
  && ok "a segunda volta não acha o que escrever e não escreve" \
  || falha "a segunda volta escreveu no override (rc=$rc)" "$saida"

printf '[Context]\nfilesystems=!home;xdg-config/gtk-3.0:ro;\n\n[Environment]\nICON_THEME=MeowSystem-Icons\n' > "$OVERRIDE"
marco="$(stat -c '%Y.%y' "$OVERRIDE")"; sleep 1.1
saida="$(servico)"; rc=$?
[ "$rc" = "0" ] && [ "$marco" = "$(stat -c '%Y.%y' "$OVERRIDE")" ] \
  && ok "override sem a linha não é tocado" \
  || falha "o serviço mexeu num override sem a linha (rc=$rc)" "$saida"

printf '[Context]\nfilesystems=xdg-config/gtk-4.0:ro;\n' > "$OVERRIDE"
printf 'FLATPAK_VIGIA="nao"\n' > "$CASA/.config/meow/meow.conf"
servico >/dev/null; rc=$?
[ "$rc" = "9" ] && grep -q 'gtk-4.0:ro' "$OVERRIDE" \
  && ok "com FLATPAK_VIGIA=\"nao\" o serviço nem roda" \
  || falha "o serviço rodou com FLATPAK_VIGIA=nao (rc=$rc)"

V="$T/vigia"; mkdir -p "$V/bin" "$V/run/systemd" "$V/casa/.local/state/meowsystem"
cat > "$V/bin/systemctl" <<FIM
#!/bin/sh
echo "systemctl \$*" >> "$V/systemctl.log"
case "\$*" in
  *is-enabled*|*is-active*) u="\$(echo "\$*" | awk '{print \$NF}')"
    grep -q "enable --now.* \$u" "$V/systemctl.log" 2>/dev/null || exit 1
    case "\$*" in *is-enabled*) echo enabled ;; *) echo active ;; esac ;;
  *is-failed*) echo active; exit 1 ;;
esac
exit 0
FIM
cat > "$V/bin/id" <<FIM
#!/bin/sh
[ "\$1" = "-u" ] && { echo "../..$V/run"; exit 0; }
exec /usr/bin/id "\$@"
FIM
cp "$T/bin/flatpak" "$V/bin/flatpak"
chmod 755 "$V/bin"/*
vigia() {
  env -i PATH="$V/bin:/usr/bin:/bin" HOME="$V/casa" NO_COLOR=1 LANG=C.UTF-8 MEOW_RAIZ="$RAIZ" \
    MEOW_ESTADO="$V/casa/.local/state/meowsystem" bash "$RAIZ/scripts/vigia_flatpak.sh" "$@" 2>&1
}
VU="$V/casa/.config/systemd/user"
saida="$(vigia --aplicar)"; rc=$?
if [ "$rc" = "1" ] && [ "$(cat "$P")" = "$(cat "$VU/meow-flatpak-override.path")" ] && [ "$(cat "$S")" = "$(cat "$VU/meow-flatpak-override.service")" ] \
   && grep -q 'enable --now meow-flatpak.path meow-flatpak-override.path' "$V/systemctl.log"; then
  ok "o vigia do flatpak instala o par novo e arma os dois gatilhos"
else
  falha "o vigia_flatpak.sh não instalou ou armou o par do override (rc=$rc)" "$saida"
fi
antes="$(cd "$VU" && find . -type f -printf '%p %T@\n' | sort)"
saida="$(vigia --aplicar)"; rc=$?
[ "$rc" = "0" ] && [ "$antes" = "$(cd "$VU" && find . -type f -printf '%p %T@\n' | sort)" ] \
  && ok "a segunda passada não escreve" || falha "a segunda passada escreveu (rc=$rc)" "$saida"
saida="$(vigia --conferir)"; rc=$?
[ "$rc" = "0" ] && ok "e o doctor confere em ordem" || falha "o conferir diverge (rc=$rc)" "$saida"
rm "$VU/meow-flatpak-override.path"
saida="$(vigia --conferir)"; rc=$?
[ "$rc" = "1" ] && ok "sem o par novo instalado o doctor diverge" || falha "o conferir não viu a falta do par (rc=$rc)" "$saida"

[ "$falhas" = 0 ] && { echo "flatpak-override-vigia: tudo certo"; exit 0; }
echo "flatpak-override-vigia: $falhas falha(s)"; exit 1

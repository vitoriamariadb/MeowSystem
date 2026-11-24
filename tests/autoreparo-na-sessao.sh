#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
V="$T/v"
mkdir -p "$V/bin" "$V/run/systemd"

cat > "$V/bin/systemctl" <<FIM
#!/bin/sh
echo "systemctl \$*" >> "$V/systemctl.log"
d="\$HOME/.config/systemd/user"
case "\$*" in
  *is-enabled*) u="\$(echo "\$*" | awk '{print \$NF}')"
    for w in "\$d"/*.wants/"\$u"; do [ -L "\$w" ] && { echo enabled; exit 0; }; done
    echo disabled; exit 1 ;;
  *"is-active graphical-session.target"*) [ -f "$V/sessao" ] && { echo active; exit 0; }; echo inactive; exit 3 ;;
  *is-active*) u="\$(echo "\$*" | awk '{print \$NF}')"
    [ -f "$V/ativos/\$u" ] && { echo active; exit 0; }
    [ -L "\$d/timers.target.wants/\$u" ] && { echo active; exit 0; }
    [ -f "$V/sessao" ] && [ -L "\$d/graphical-session.target.wants/\$u" ] && { echo active; exit 0; }
    echo inactive; exit 3 ;;
  *"enable --now"*|*" enable "*) u="\$(echo "\$*" | awk '{print \$NF}')"
    alvo="\$(sed -n 's/^WantedBy=//p' "\$d/\$u" | head -n1)"
    mkdir -p "\$d/\$alvo.wants"; [ -L "\$d/\$alvo.wants/\$u" ] || ln -s "\$d/\$u" "\$d/\$alvo.wants/\$u"
    case "\$*" in *"enable --now"*) mkdir -p "$V/ativos"; : > "$V/ativos/\$u" ;; esac ;;
esac
exit 0
FIM
cat > "$V/bin/id" <<FIM
#!/bin/sh
[ "\$1" = "-u" ] && { echo "../..$V/run"; exit 0; }
exec /usr/bin/id "\$@"
FIM
chmod 755 "$V/bin/systemctl" "$V/bin/id"

nova_casa() {
  VC="$V/casa$1"; VU="$VC/.config/systemd/user"
  mkdir -p "$VU" "$VC/.config/meow" "$VC/.local/state/meowsystem"
  : > "$V/systemctl.log"; rm -rf "$V/ativos"; : > "$V/sessao"
}
preso_ao_boot() {
  mkdir -p "$VU/timers.target.wants"
  ln -sf "$VU/meow-doctor.timer" "$VU/timers.target.wants/meow-doctor.timer"
}
{ sed -n '/^etapa_autoreparo() {$/,/^}$/p' "$RAIZ/install.sh"; } > "$V/etapa.sh"
etapa_install() {
  env -i PATH="$V/bin:/usr/bin:/bin" HOME="$VC" NO_COLOR=1 MEOW_DRY_RUN="${SECO:-0}" MEOW_RAIZ="$RAIZ" LANG=C.UTF-8 \
    MEOW_ESTADO="$VC/.local/state/meowsystem" AUTO_REPARO=sim VIDRO_AO_MAXIMIZAR=nao \
    bash -c 'source "$MEOW_RAIZ/scripts/lib/comum.sh"; passo() { :; }; source "$0"; etapa_autoreparo' "$V/etapa.sh" 2>&1
}
doutor() {
  env -i PATH="$V/bin:/usr/bin:/bin" HOME="$VC" NO_COLOR=1 MEOW_RAIZ="$RAIZ" LANG=C.UTF-8 \
    MEOW_ESTADO="$VC/.local/state/meowsystem" AUTO_REPARO=sim VIDRO_AO_MAXIMIZAR=nao \
    bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/scripts/meow"); "$@"' _ "$@" 2>&1
}
retrato() { (cd "$VC" && find . \( -type f -o -type l \) -printf '%p %T@\n' | sort); }
preso() { [ -L "$VU/timers.target.wants/meow-doctor.timer" ]; }
na_sessao() { [ -L "$VU/graphical-session.target.wants/meow-doctor.timer" ]; }

U="$RAIZ/dados/systemd/meow-doctor.timer"
grep -qx 'WantedBy=graphical-session.target' "$U" && grep -qx 'PartOf=graphical-session.target' "$U" \
  && ! grep -q 'timers.target' "$U" \
  && ok "o timer do doctor nasce com a sessão gráfica, e não com o systemd --user" \
  || falha "o meow-doctor.timer não está preso à graphical-session.target"
grep -qx 'ConditionEnvironment=WAYLAND_DISPLAY' "$RAIZ/dados/systemd/meow-doctor.service" \
  && ok "e a condição do serviço fica" || falha "o serviço do doctor perdeu o ConditionEnvironment"

nova_casa 1
saida="$(etapa_install)"; rc=$?
if [ "$rc" = "1" ] && na_sessao && ! preso && [ -f "$VU/meow-doctor.timer" ]; then
  ok "o install numa casa nova arma o timer na graphical-session.target e não deixa vínculo em timers.target"
else
  falha "o install numa casa nova (rc=$rc, na_sessao=$(na_sessao && echo s || echo n), preso=$(preso && echo s || echo n))" "$saida"
fi
antes="$(retrato)"
saida="$(etapa_install)"; rc=$?
[ "$rc" = "0" ] && [ "$antes" = "$(retrato)" ] && ok "a segunda passada do install não escreve" \
  || falha "a segunda passada do install escreveu (rc=$rc)" "$saida"

nova_casa 2
cp "$U" "$VU/meow-doctor.timer"
cp "$RAIZ/dados/systemd/meow-doctor.service" "$VU/meow-doctor.service"
preso_ao_boot
saida="$(etapa_install)"; rc=$?
if [ "$rc" = "1" ] && ! preso && na_sessao && [ ! -e "$VU/timers.target.wants/meow-doctor.timer" ]; then
  ok "o install tira o vínculo antigo de timers.target.wants mesmo com as unidades já em dia, e arma na sessão"
else
  falha "o vínculo antigo ficou (rc=$rc, preso=$(preso && echo s || echo n))" "$saida"
fi
antes="$(retrato)"
saida="$(etapa_install)"; rc=$?
[ "$rc" = "0" ] && [ "$antes" = "$(retrato)" ] && ok "e a passada seguinte não escreve" \
  || falha "a passada seguinte escreveu (rc=$rc)" "$saida"

nova_casa 3
cp "$U" "$VU/meow-doctor.timer"
cp "$RAIZ/dados/systemd/meow-doctor.service" "$VU/meow-doctor.service"
preso_ao_boot
saida="$(SECO=1 etapa_install)"; rc=$?
[ "$rc" = "1" ] && preso && ok "em seco o install aponta o vínculo antigo e não o tira" \
  || falha "o seco mexeu no vínculo ou calou (rc=$rc)" "$saida"

nova_casa 4
cp "$U" "$VU/meow-doctor.timer"
cp "$RAIZ/dados/systemd/meow-doctor.service" "$VU/meow-doctor.service"
preso_ao_boot
saida="$(doutor chk_autoreparo)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"timers.target"* ]] && ok "o doctor aponta o timer preso ao boot" \
  || falha "o chk_autoreparo não viu o vínculo antigo (rc=$rc)" "$saida"
saida="$(doutor fix_autoreparo)"; rc=$?
[ "$rc" = "1" ] && ! preso && na_sessao && ok "o conserto do doctor tira o vínculo e arma na sessão" \
  || falha "o fix_autoreparo não consertou (rc=$rc)" "$saida"
saida="$(doutor chk_autoreparo)"; rc=$?
[ "$rc" = "0" ] && ok "e o doctor confere em ordem depois" || falha "o chk_autoreparo diverge depois do conserto (rc=$rc)" "$saida"
antes="$(retrato)"
doutor fix_autoreparo >/dev/null
[ "$antes" = "$(retrato)" ] && ok "o segundo conserto não escreve" || falha "o segundo conserto reescreveu"

nova_casa 5
rm -f "$V/sessao"
cp "$U" "$VU/meow-doctor.timer"
cp "$RAIZ/dados/systemd/meow-doctor.service" "$VU/meow-doctor.service"
mkdir -p "$VU/graphical-session.target.wants"
ln -s "$VU/meow-doctor.timer" "$VU/graphical-session.target.wants/meow-doctor.timer"
saida="$(doutor chk_autoreparo)"; rc=$?
[ "$rc" = "0" ] && ok "sem sessão gráfica (ssh), o doctor aceita o timer habilitado na sessão e parado" \
  || falha "sem sessão gráfica o doctor diverge do timer que só está parado por PartOf (rc=$rc)" "$saida"
saida="$(SECO=1 etapa_install)"; rc=$?
[ "$rc" = "0" ] && ok "e o install em seco concorda" || falha "o install em seco diverge sem sessão gráfica (rc=$rc)" "$saida"

nova_casa 6
rm -f "$V/sessao"
cp "$U" "$VU/meow-doctor.timer"
cp "$RAIZ/dados/systemd/meow-doctor.service" "$VU/meow-doctor.service"
saida="$(doutor fix_autoreparo)"; rc=$?
if [ "$rc" = "1" ] && na_sessao && [ ! -e "$V/ativos/meow-doctor.timer" ] && ! grep -q 'enable --now meow-doctor.timer' "$V/systemctl.log"; then
  ok "sem sessão gráfica, o conserto habilita o timer na sessão sem dar partida (a partida pularia o disparo do dia)"
else
  falha "sem sessão gráfica o conserto deu partida no timer ou não o habilitou (rc=$rc)" "$saida$(printf '\n'; cat "$V/systemctl.log")"
fi
saida="$(doutor chk_autoreparo)"; rc=$?
[ "$rc" = "0" ] && ok "e o doctor confere em ordem depois" || falha "sem sessão o chk_autoreparo diverge depois do conserto (rc=$rc)" "$saida"

[ "$falhas" = 0 ] && { echo "autoreparo-na-sessao: tudo certo"; exit 0; }
echo "autoreparo-na-sessao: $falhas falha(s)"; exit 1

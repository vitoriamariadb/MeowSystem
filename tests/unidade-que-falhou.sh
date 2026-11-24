#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
V="$T/v"; F="$T/raiz"
mkdir -p "$V/bin" "$V/run/systemd" "$V/hab" "$V/ativos" "$V/falhas" "$V/limite" "$F/scripts"
ln -s "$RAIZ/scripts/lib" "$F/scripts/lib"
ln -s "$RAIZ/dados" "$F/dados"
ln -s "$RAIZ/install.sh" "$F/install.sh"
ln -s "$RAIZ/scripts/meow" "$F/scripts/meow"
printf '#!/bin/sh\nexit 0\n' > "$F/scripts/painel.sh"; chmod 755 "$F/scripts/painel.sh"

cat > "$V/bin/systemctl" <<FIM
#!/bin/sh
echo "systemctl \$*" >> "$V/systemctl.log"
u="\$(echo "\$*" | awk '{print \$NF}')"
case "\$*" in
  *"is-active graphical-session.target"*) echo inactive; exit 3 ;;
  *is-enabled*) [ -f "$V/hab/\$u" ] && { echo enabled; exit 0; }; echo disabled; exit 1 ;;
  *is-active*) [ -f "$V/ativos/\$u" ] && { echo active; exit 0; }
    [ -f "$V/falhas/\$u" ] && { echo failed; exit 3; }; echo inactive; exit 3 ;;
  *is-failed*) [ -f "$V/falhas/\$u" ] && { echo failed; exit 0; }
    [ -f "$V/ativos/\$u" ] && { echo active; exit 1; }; echo inactive; exit 1 ;;
  *reset-failed*) shift 2; for a in "\$@"; do rm -f "$V/falhas/\$a" "$V/limite/\$a"; done ;;
  *"enable --now"*|*" start "*)
    case "\$*" in *enable*) : > "$V/hab/\$u" ;; esac
    [ -f "$V/limite/\$u" ] && exit 1
    rm -f "$V/falhas/\$u"; : > "$V/ativos/\$u" ;;
  *" enable "*) : > "$V/hab/\$u" ;;
esac
exit 0
FIM
cat > "$V/bin/id" <<FIM
#!/bin/sh
[ "\$1" = "-u" ] && { echo "../..$V/run"; exit 0; }
exec /usr/bin/id "\$@"
FIM
chmod 755 "$V/bin/systemctl" "$V/bin/id"

CASA="$T/casa"
mkdir -p "$CASA/.config/meow" "$CASA/.local/state/meowsystem"
sed -n '/^etapa_painel() {$/,/^}$/p' "$RAIZ/install.sh" > "$V/etapa.sh"
install_painel() {
  env -i PATH="$V/bin:/usr/bin:/bin" HOME="$CASA" NO_COLOR=1 MEOW_DRY_RUN="${SECO:-0}" MEOW_RAIZ="$F" LANG=C.UTF-8 \
    MEOW_ESTADO="$CASA/.local/state/meowsystem" AUTO_REPARO=sim MEOW_COSMIC_SISTEMA="$T/sem-cosmic" \
    bash -c 'source "$MEOW_RAIZ/scripts/lib/comum.sh"; passo() { :; }; source "$0"; etapa_painel' "$V/etapa.sh" 2>&1
}
doutor() {
  env -i PATH="$V/bin:/usr/bin:/bin" HOME="$CASA" NO_COLOR=1 MEOW_RAIZ="$F" LANG=C.UTF-8 \
    MEOW_ESTADO="$CASA/.local/state/meowsystem" AUTO_REPARO=sim \
    bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/scripts/meow"); "$@"' _ "$@" 2>&1
}
estourou() { rm -f "$V/ativos/$1"; : > "$V/falhas/$1"; : > "$V/limite/$1"; }
chamadas() { grep -E -- "$1" "$V/systemctl.log" || true; }

saida="$(install_painel)"; rc=$?
if [ -f "$V/ativos/meow-painel.service" ] && [ -f "$V/ativos/meow-painel-raio.path" ] && [ -z "$(chamadas reset-failed)" ]; then
  ok "casa nova: o install arma as duas unidades sem limpar estado nenhum"
else
  falha "casa nova (rc=$rc)" "$saida$(printf '\n'; cat "$V/systemctl.log")"
fi

estourou meow-painel.service
: > "$V/systemctl.log"
saida="$(SECO=1 install_painel)"; rc=$?
if [ -z "$(chamadas '--user (reset-failed|enable|start) ')" ] && [ -f "$V/falhas/meow-painel.service" ]; then
  ok "ensaio com o supervisor estourado: nenhum reset-failed, nenhuma partida"
else
  falha "o ensaio mexeu no estado da unidade (rc=$rc)" "$(cat "$V/systemctl.log")"
fi

: > "$V/systemctl.log"
saida="$(install_painel)"; rc=$?
ordem="$(chamadas 'reset-failed|enable --now' | sed 's/^systemctl --user //')"
esperada="$(printf 'reset-failed meow-painel.service\nenable --now meow-painel.service')"
if [ "$ordem" = "$esperada" ] && [ -f "$V/ativos/meow-painel.service" ] && [[ "$saida" != *"não consegui armar"* ]]; then
  ok "supervisor que estourou o limite de partidas: o install limpa o estado só dele e depois o arma"
else
  falha "o install não rearmou o supervisor estourado (rc=$rc)" "$saida$(printf '\n--- chamadas:\n%s' "$ordem")"
fi

: > "$V/systemctl.log"
saida="$(install_painel)"; rc=$?
if [ -z "$(chamadas '--user (reset-failed|is-failed|enable|start) ')" ]; then
  ok "segunda passada, unidades sãs: nenhuma chamada a mais"
else
  falha "a segunda passada chamou o systemctl para armar ou limpar (rc=$rc)" "$(cat "$V/systemctl.log")"
fi

estourou meow-painel-raio.path
: > "$V/systemctl.log"
saida="$(install_painel)"; rc=$?
ordem="$(chamadas 'reset-failed|enable --now' | sed 's/^systemctl --user //')"
esperada="$(printf 'reset-failed meow-painel-raio.path\nenable --now meow-painel-raio.path')"
if [ "$ordem" = "$esperada" ] && [ -f "$V/ativos/meow-painel-raio.path" ]; then
  ok "o vigia do raio estourado: limpa só ele, e não o supervisor são"
else
  falha "o vigia do raio estourado não voltou só com o reset dele (rc=$rc)" "$saida$(printf '\n--- chamadas:\n%s' "$ordem")"
fi

estourou meow-painel.service
: > "$V/systemctl.log"
saida="$(doutor fix_painel)"; rc=$?
ordem="$(chamadas 'reset-failed|start' | sed 's/^systemctl --user //')"
esperada="$(printf 'reset-failed meow-painel.service\nstart meow-painel.service')"
if [ "$ordem" = "$esperada" ] && [ -f "$V/ativos/meow-painel.service" ]; then
  ok "o conserto do doctor limpa o estado do supervisor estourado antes de dar partida"
else
  falha "o conserto do doctor não deu partida no supervisor estourado (rc=$rc)" "$saida$(printf '\n--- chamadas:\n%s' "$ordem")"
fi

if ! grep -qE 'reset-failed .*(\*|meow-\*)' "$RAIZ/install.sh" "$RAIZ/scripts/meow" "$RAIZ/scripts/lib/comum.sh"; then
  ok "ninguém limpa meow-* inteiro"
else
  falha "há reset-failed por padrão de nome" "$(grep -nE 'reset-failed .*(\*|meow-\*)' "$RAIZ/install.sh" "$RAIZ/scripts/meow" "$RAIZ/scripts/lib/comum.sh")"
fi

[ "$falhas" = 0 ] && { echo "unidade-que-falhou: tudo certo"; exit 0; }
echo "unidade-que-falhou: $falhas falha(s)"; exit 1

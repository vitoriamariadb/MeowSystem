#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FALHAS=0
falhou() { printf 'FALHOU: %s\n' "$*" >&2; FALHAS=$((FALHAS + 1)); }
passou() { printf 'ok: %s\n' "$*"; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/casa" "$T/falso" "$T/sd"
for c in sudo pkexec su pkill killall notify-send; do
  printf '#!/bin/sh\nexit 1\n' > "$T/falso/$c"; chmod 755 "$T/falso/$c"
done
cat > "$T/falso/systemctl" <<'SH'
#!/bin/sh
[ "$1" = "--user" ] && shift
acao="$1"; shift
[ "${1:-}" = "--" ] && shift
case "$acao" in
  show) echo "Version=255" ;;
  is-enabled) if [ -f "$FALSO_SD/$1.masked" ]; then echo masked; exit 1; fi; echo enabled ;;
  mask) : > "$FALSO_SD/$1.masked"; echo "mask $1" >> "$FALSO_SD/log" ;;
  unmask) rm -f "$FALSO_SD/$1.masked"; echo "unmask $1" >> "$FALSO_SD/log" ;;
  *) exit 1 ;;
esac
SH
printf '#!/bin/sh\n[ "$1" = "--" ] && shift\nprintf "%%s\\n" "$1"\n' > "$T/falso/systemd-escape"
chmod 755 "$T/falso/systemctl" "$T/falso/systemd-escape"

auto() {
  local lista="$1"; shift
  env -i PATH="$T/falso:/usr/bin:/bin" HOME="$T/casa" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" FALSO_SD="$T/sd" AUTOSTART_BLOQUEADOS="$lista" \
    bash "$RAIZ/scripts/autostart.sh" "$@" 2>&1
}
mascarado() { [ -f "$T/sd/app-$1@autostart.service.masked" ]; }
linhas_do_log() { grep -c . "$T/sd/log" 2>/dev/null || printf '0'; }

: > "$T/sd/app-gama@autostart.service.masked"
saida="$(auto "alfa,beta,gama" aplicar)"; rc=$?
if [ "$rc" = 1 ] && mascarado alfa && mascarado beta && mascarado gama; then
  passou "a lista alfa,beta,gama mascara os três (gama já vinha mascarado por fora)"
else
  falhou "a primeira passada não mascarou a lista (rc $rc): $saida"
fi

saida="$(auto "alfa" conferir)"; rc=$?
if [ "$rc" = 1 ] && printf '%s' "$saida" | grep -q 'beta'; then
  passou "o conferir diverge enquanto o beta, que saiu da lista, segue mascarado por nós"
else
  falhou "o conferir não viu o beta que saiu da lista (rc $rc): $saida"
fi

saida="$(auto "alfa" aplicar)"; rc=$?
if [ "$rc" = 1 ] && mascarado alfa && ! mascarado beta && mascarado gama \
   && grep -qx 'unmask app-beta@autostart.service' "$T/sd/log"; then
  passou "tirar o beta da lista o desmascara, e o gama, mascarado por fora, fica como estava"
else
  falhou "tirar o beta da lista não o desmascarou (rc $rc): $saida"
fi
if printf '%s' "$saida" | grep -q 'não desfaz a máscara'; then
  falhou "a saída ainda diz que tirar o nome não desfaz a máscara: $saida"
fi

saida="$(auto "alfa" conferir)"; rc=$?
[ "$rc" = 0 ] && passou "depois disso o conferir fecha (rc 0)" || falhou "o conferir segue divergindo (rc $rc): $saida"

saida="$(auto "" aplicar)"; rc=$?
if [ "$rc" = 1 ] && ! mascarado alfa && mascarado gama; then
  passou "esvaziar a lista desmascara o que o MeowSystem mascarou, e só isso"
else
  falhou "a lista vazia não devolveu o alfa (rc $rc): $saida"
fi

mkdir -p "$T/casa2" "$T/sd2" "$T/lento"
printf '#!/bin/sh\n/usr/bin/tr "$@" | { IFS= read -r l; printf "%%s\\n" "$l"; sleep 0.3; cat; }\n' > "$T/lento/tr"
chmod 755 "$T/lento/tr"
auto2() {
  local caminho="$1"; shift
  env -i PATH="$caminho" HOME="$T/casa2" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" FALSO_SD="$T/sd2" AUTOSTART_BLOQUEADOS="um,dois,tres" \
    bash "$RAIZ/scripts/autostart.sh" aplicar 2>&1
}
auto2 "$T/falso:/usr/bin:/bin" >/dev/null
saida="$(auto2 "$T/lento:$T/falso:/usr/bin:/bin")"; rc=$?
if [ "$rc" = 0 ] && [ -f "$T/sd2/app-um@autostart.service.masked" ] && [ -f "$T/sd2/app-dois@autostart.service.masked" ] \
   && [ -f "$T/sd2/app-tres@autostart.service.masked" ] && ! grep -q '^unmask ' "$T/sd2/log"; then
  passou "com a lista saindo devagar, quem segue na lista não é tomado por quem saiu dela"
else
  falhou "a segunda passada desmascarou quem segue na lista (rc $rc): $saida"
fi

antes="$(linhas_do_log)"
saida="$(auto "" aplicar)"; rc=$?
if [ "$rc" = 0 ] && [ "$(linhas_do_log)" = "$antes" ] && mascarado gama; then
  passou "a segunda passada com a lista vazia não mexe em nada"
else
  falhou "a segunda passada com a lista vazia mexeu (rc $rc): $saida"
fi

[ "$FALHAS" -eq 0 ] || exit 1
printf 'o autostart desfaz o que saiu da lista\n'
exit 0

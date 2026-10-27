#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falhou=0

if ! grep -qE 'aplicar_apps\.sh" reverter' "$RAIZ/lib/desinstalar.sh"; then
  printf 'FALHOU: lib/desinstalar.sh não chama "aplicar_apps.sh reverter"\n' >&2
  printf '        os temas por aplicativo ficariam na máquina depois do --uninstall\n' >&2
  falhou=1
fi

for mod in "$RAIZ"/scripts/temas-de-apps/*/manifesto.sh; do
  nome="$(basename "$(dirname "$mod")")"
  if ! (
        set +u
        MEOW_IGNORA_DESKTOP=1 NO_COLOR=1
        # shellcheck source=../lib/comum.sh
        . "$RAIZ/lib/comum.sh" >/dev/null 2>&1
        # shellcheck disable=SC1090
        . "$mod" >/dev/null 2>&1
        declare -F meow_app_reverter >/dev/null
      ); then
    printf 'FALHOU: o módulo %s não define meow_app_reverter\n' "$nome" >&2
    printf '        ele ficaria aplicado na máquina depois de ./install.sh --uninstall\n' >&2
    falhou=1
  fi
done

nomeadas="$(sed -n '/systemctl --user disable --now/,/2>\/dev\/null/p' \
              "$RAIZ/lib/desinstalar.sh" \
            | grep -oE 'meow-[a-z-]+\.(path|service|timer)' | sort -u)"
if [ -z "$nomeadas" ]; then
  printf 'FALHOU: não achei o "systemctl --user disable --now" em lib/desinstalar.sh\n' >&2
  printf '        (o comando mudou de forma? esta afirmação precisa ser reescrita)\n' >&2
  falhou=1
else
  for u in "$RAIZ"/systemd/meow-*.path "$RAIZ"/systemd/meow-*.service "$RAIZ"/systemd/meow-*.timer; do
    [ -e "$u" ] || continue
    nome="$(basename "$u")"
    printf '%s\n' "$nomeadas" | grep -qx "$nome" && continue
    printf 'FALHOU: %s existe em systemd/ e NÃO está no "disable --now" do desinstalador\n' "$nome" >&2
    printf '        o --uninstall apagaria o arquivo dela com a unidade ainda ativa\n' >&2
    falhou=1
  done
fi

migrados=0
for mod in "$RAIZ"/scripts/temas-de-apps/*/manifesto.sh; do
  nome="$(basename "$(dirname "$mod")")"
  grep -q 'meow_app_sem' "$mod" || continue
  migrados=$((migrados + 1))

  corpo="$(sed -n '/^meow_app_detectar() {/,/^}/p' "$mod")"
  if [ -z "$corpo" ]; then
    printf 'FALHOU: não achei o meow_app_detectar de %s para conferir\n' "$nome" >&2
    printf '        (a função mudou de forma? esta afirmação precisa ser reescrita)\n' >&2
    falhou=1
    continue
  fi
  if printf '%s\n' "$corpo" | grep -q 'MEOW_SEM_DEPENDENCIA'; then
    printf 'FALHOU: o meow_app_detectar de %s sai com 3 por fora do meow_app_sem\n' "$nome" >&2
    printf '        essa saída não guarda motivo, e o aplicar imprimiria a causa errada\n' >&2
    falhou=1
  fi
  if ! printf '%s\n' "$corpo" | grep -q 'MEOW_APP_MOTIVO=""'; then
    printf 'FALHOU: o meow_app_detectar de %s não zera o MEOW_APP_MOTIVO ao começar\n' "$nome" >&2
    printf '        um motivo velho de outra chamada seria impresso como se fosse medido agora\n' >&2
    falhou=1
  fi

  medida="$(
    set +u
    MEOW_ESTADO="$(mktemp -d -p "${TMPDIR:-/tmp}" .meow-reversao.XXXXXX)"
    trap 'rm -rf "$MEOW_ESTADO"' EXIT
    MEOW_IGNORA_DESKTOP=1 NO_COLOR=1
    # shellcheck source=../lib/comum.sh
    . "$RAIZ/lib/comum.sh" >/dev/null 2>&1
    # shellcheck disable=SC1090
    . "$mod" >/dev/null 2>&1
    meow_app_detectar >/dev/null 2>&1
    printf '%s\t%s' "$?" "${MEOW_APP_MOTIVO:-}"
  )"
  rc_det="${medida%%$'\t'*}"
  motivo="${medida#*$'\t'}"
  if [ "$rc_det" = "3" ] && [ -z "$motivo" ]; then
    printf 'FALHOU: o meow_app_detectar de %s devolveu 3 sem declarar motivo\n' "$nome" >&2
    printf '        nesta máquina, agora — é o caso exato do Spotify de 21/09/2026\n' >&2
    falhou=1
  fi
done

instalados=0
for mod in "$RAIZ"/scripts/temas-de-apps/*/manifesto.sh; do
  nome="$(basename "$(dirname "$mod")")"
  usos="$(grep -v '^[[:space:]]*#' "$mod" | grep -c 'meow_app_instalado')"
  if [ "$usos" -lt 2 ]; then
    printf 'FALHOU: o módulo %s não define e chama meow_app_instalado (%s uso)\n' "$nome" "$usos" >&2
    printf '        a coluna «instalado» e a frase do módulo voltariam a ser duas regras\n' >&2
    falhou=1
    continue
  fi
  medida="$(
    set +u
    MEOW_ESTADO="$(mktemp -d -p "${TMPDIR:-/tmp}" .meow-reversao.XXXXXX)"
    trap 'rm -rf "$MEOW_ESTADO"' EXIT
    MEOW_IGNORA_DESKTOP=1 NO_COLOR=1
    # shellcheck source=../lib/comum.sh
    . "$RAIZ/lib/comum.sh" >/dev/null 2>&1
    # shellcheck disable=SC1090
    . "$mod" >/dev/null 2>&1
    declare -F meow_app_instalado >/dev/null || { printf 'sem'; exit 0; }
    meow_app_instalado >/dev/null 2>&1; inst=$?
    meow_app_detectar >/dev/null 2>&1; det=$?
    printf '%s %s' "$inst" "$det"
  )"
  if [ "$medida" = "sem" ]; then
    printf 'FALHOU: o módulo %s não define meow_app_instalado depois do source\n' "$nome" >&2
    falhou=1
  elif [ "${medida#* }" = "0" ] && [ "${medida% *}" != "0" ]; then
    printf 'FALHOU: em %s o detectar diz que dá para trabalhar e o instalado diz que não está (%s)\n' "$nome" "$medida" >&2
    falhou=1
  else
    instalados=$((instalados + 1))
  fi
done

guarda="$(
  set +u
  NO_COLOR=1
  # shellcheck source=../lib/comum.sh
  . "$RAIZ/lib/comum.sh" >/dev/null 2>&1
  MEOW_APP_MOTIVO=""
  meow_app_pendente modulo-de-mentira 2>&1
)"
case "$guarda" in
  *"sem motivo declarado"*"modulo-de-mentira"*) : ;;
  *) printf 'FALHOU: meow_app_pendente com motivo vazio não acusou o defeito do módulo\n' >&2
     printf '        saiu: %s\n' "$guarda" >&2
     falhou=1 ;;
esac

[ "$falhou" = "0" ] || exit 1
printf 'ok: o --uninstall desfaz os %s módulos de aplicativo\n' \
  "$(find "$RAIZ/scripts/temas-de-apps" -mindepth 1 -maxdepth 1 -type d | wc -l)"
printf 'ok: os %s módulos migrados declaram o motivo em toda saída de pendência\n' "$migrados"
printf 'ok: os %s módulos dizem se o programa está instalado pela mesma regra que o detectar chama\n' "$instalados"
printf 'ok: as %s unidades de systemd/ estão nas duas listas do desinstalador\n' \
  "$(find "$RAIZ/systemd" -maxdepth 1 -name 'meow-*' -type f | wc -l)"

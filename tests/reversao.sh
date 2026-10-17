#!/usr/bin/env bash
# O `--uninstall` desfaz TODO módulo de aplicativo, e não só os que alguém
# lembrou de cobrir.
#
# POR QUE `declare -F` NUM SUBSHELL, E NÃO UM `grep` `grep -q meow_app_reverter`
# passaria com a palavra dentro de um comentário — e este projeto tem cabeçalhos
# que citam os nomes das funções o tempo todo.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falhou=0

# --- 1. o desinstalador chama o runner --------------------------------------
if ! grep -qE 'aplicar_apps\.sh" reverter' "$RAIZ/lib/desinstalar.sh"; then
  printf 'FALHOU: lib/desinstalar.sh não chama "aplicar_apps.sh reverter"\n' >&2
  printf '        os temas por aplicativo ficariam na máquina depois do --uninstall\n' >&2
  falhou=1
fi

# --- 2. todo módulo sabe desfazer -------------------------------------------
# `MEOW_IGNORA_DESKTOP=1` e o `lib/comum.sh` antes: os módulos são escritos para
# serem `source` DEPOIS dele (usam meow_ok, MEOW_OK, meow_seco).
for mod in "$RAIZ"/assets/temas-de-apps/*/manifesto.sh; do
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

# --- 3. toda unidade está nas DUAS listas do desinstalador -------------------
# A lista NOMEADA é a do `systemctl --user disable --now`, e é a que apodrece:
# o `find -name 'meow-*' -delete` pega qualquer unidade nova de graça, então
# esquecer a outra metade não dá erro nenhum — dá processo órfão.
#
# Comparo contra `systemd/`, que é a fonte: é de lá que o `install.sh` copia
# para `~/.config/systemd/user`. Uma unidade que exista no repositório e não
# esteja na lista é o defeito; o contrário (nome na lista sem arquivo) é
# inofensivo, porque `disable` de unidade inexistente é justamente o estado que
# se quer, e o `|| true` de lá já conta isso.
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

# --- 4. o motivo da pendência viaja junto com o código 3 --------------------
#
# Este arquivo já é o teste do CONTRATO dos módulos de aplicativo — do verbo que
# um módulo novo esquece de escrever.
#
# A ESTÁTICA pega o caminho que esta máquina não percorre hoje: num módulo
# migrado, NENHUMA saída-3 do `detectar` pode escapar do `meow_app_sem` — é ele
# que guarda o motivo, e sair por outra porta é sair mudo.
migrados=0
for mod in "$RAIZ"/assets/temas-de-apps/*/manifesto.sh; do
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

  # Este comentário dizia que `detectar` é leitura pura e que rodá-lo "não
  # escreve um byte na máquina de ninguém".
  #
  # Só o efeito colateral se desvia.
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

# --- 5. "instalado" é uma regra só, e o `detectar` a chama -----------------
instalados=0
for mod in "$RAIZ"/assets/temas-de-apps/*/manifesto.sh; do
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

# E A GUARDA MORDE.
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
  "$(find "$RAIZ/assets/temas-de-apps" -mindepth 1 -maxdepth 1 -type d | wc -l)"
printf 'ok: os %s módulos migrados declaram o motivo em toda saída de pendência\n' "$migrados"
printf 'ok: os %s módulos dizem se o programa está instalado pela mesma regra que o detectar chama\n' "$instalados"
printf 'ok: as %s unidades de systemd/ estão nas duas listas do desinstalador\n' \
  "$(find "$RAIZ/systemd" -maxdepth 1 -name 'meow-*' -type f | wc -l)"

#!/usr/bin/env bash
# applet_pino.sh — os applets do meow seguem o libcosmic do PAINEL instalado.
#
#   ./applet_pino.sh painel                     a revisão do libcosmic do cosmic-panel instalado
#   ./applet_pino.sh alvo <nome> <rev-do-pino>  a revisão contra a qual o applet deve compilar
#   ./applet_pino.sh falhou <nome> <rev>        registra que o applet não compilou nela
#   ./applet_pino.sh conferir                   os dois applets: pino, painel e alvo
#
# Também é lido com `.` pelo `leitura_build.sh` e pelo `midia_build.sh`, que
# usam as funções `ap_*` sem rodar o `case` do fim.
#
# POR QUE ISTO EXISTE (P76, `docs/pesquisas/2026-10-09-cosmic-vivo.md` §4.6)
#   Os dois applets compilam contra o libcosmic 1f6dc99, pinado em agosto. O
#   painel que os carrega é compilado pelo Pop contra outro (em 09/10/2026: o
#   cosmic-panel 1.9 instalado pina o 23f5d63). O applet fala com o painel pelo
#   protocolo do libcosmic, e um pino que não anda é um applet que um dia não
#   sobe — e ninguém sabe por quê.
#
# A REGRA DO ALVO — o applet anda QUANDO O PAINEL ANDA
#   Cada applet guarda a base do último build (`applet-pino-base.tsv`): o
#   libcosmic do painel naquela hora e o libcosmic contra o qual compilou.
#   1. painel igual ao da base: o alvo é o da base — nada a recompilar;
#   2. painel diferente do da base (o apt trouxe outro): o alvo é o do painel,
#      se o applet ainda não falhou nele;
#   3. sem base (o primeiro contato, numa máquina que já tinha o applet): a
#      base nasce com o painel de agora e o pino. O applet que funcionava não
#      se recompila só porque esta regra chegou; ele anda no próximo apt.
#   Um build que falha na revisão do painel não tenta de novo a cada doctor:
#   fica registrado (`falhou`), e o applet volta ao pino até o painel mudar.
#
# A REDE SÓ É TOCADA QUANDO O PAINEL MUDA DE VERSÃO
#   A revisão do painel vem do `Cargo.lock` no GitHub (o `meow_libcosmic_de`),
#   e fica guardada por versão do pacote em `painel-libcosmic.tsv`. O doctor
#   das 5h, que roda sem rede às vezes, lê a guarda; sem guarda e sem rede, o
#   alvo é o pino.
set -uo pipefail

if [ -z "${MEOW_RAIZ:-}" ]; then
  MEOW_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../lib/comum.sh
declare -F meow_ok >/dev/null 2>&1 || . "$MEOW_RAIZ/lib/comum.sh"

AP_GUARDA="${AP_GUARDA:-$MEOW_ESTADO/painel-libcosmic.tsv}"
AP_FALHAS="${AP_FALHAS:-$MEOW_ESTADO/applet-pino-falhas.tsv}"
AP_BASE="${AP_BASE:-$MEOW_ESTADO/applet-pino-base.tsv}"
# O `Cargo.lock` do painel, para o teste trocar a rede por um arquivo.
AP_LOCK_PAINEL="${AP_LOCK_PAINEL:-}"
# CONFERIR NÃO ESCREVE: o `--conferir` dos dois builds (a linha do doctor)
# põe 1 aqui, e a guarda da revisão e a base só se gravam numa passagem que
# aplica. Medido em 09/10/2026: sem isto, o `--conferir` gravava as duas no
# estado de verdade — leitura que escreve é o defeito que o `tests/doctor-so-le.sh`
# existe para pegar.
AP_SO_LER="${AP_SO_LER:-0}"
_ap_pode_gravar() { ! meow_seco && [ "$AP_SO_LER" != "1" ]; }

# A revisão do libcosmic num `Cargo.lock` (o SHA do `source` do pacote libcosmic).
ap_rev_do_lock() {
  awk '/^name = "libcosmic"$/{f=1} f && /^source = /{sub(/.*#/,""); sub(/"$/,""); print; exit}' "$1" 2>/dev/null
}

ap_rev_painel() {
  local v rev
  if [ -n "$AP_LOCK_PAINEL" ]; then
    rev="$(ap_rev_do_lock "$AP_LOCK_PAINEL")"; [ -n "$rev" ] && { printf '%s' "$rev"; return 0; }
    return 1
  fi
  v="$(dpkg-query -W -f='${Version}' cosmic-panel 2>/dev/null)" || return 1
  [ -n "$v" ] || return 1
  rev="$(awk -F'\t' -v v="$v" '$1==v {print $2; exit}' "$AP_GUARDA" 2>/dev/null)"
  if [ -z "$rev" ]; then
    rev="$(meow_libcosmic_de cosmic-panel "$v")" || return 1
    _ap_pode_gravar && { mkdir -p "${AP_GUARDA%/*}" && printf '%s\t%s\n' "$v" "$rev" >> "$AP_GUARDA"; }
  fi
  printf '%s' "$rev"
}

# 0 = o applet <nome> já falhou ao compilar na revisão <rev>.
ap_ja_falhou() { awk -F'\t' -v n="$1" -v r="$2" '$1==n && $2==r {achou=1} END {exit !achou}' "$AP_FALHAS" 2>/dev/null; }

# A base de um applet: "<painel><TAB><alvo>", ou vazio.
_ap_base() { awk -F'\t' -v n="$1" '$1==n {b=$2"\t"$3} END {if (b!="") print b}' "$AP_BASE" 2>/dev/null; }

# Grava a base de um applet (troca a linha dele). Chamado depois de um build que
# deu certo, e na adoção da regra 3.
ap_registrar() { # $1 nome $2 painel $3 alvo
  local tmp
  _ap_pode_gravar || return 0
  mkdir -p "${AP_BASE%/*}" || return 1
  tmp="$(mktemp -p "${AP_BASE%/*}" .base.XXXXXX)" || return 1
  { awk -F'\t' -v n="$1" '$1!=n' "$AP_BASE" 2>/dev/null; printf '%s\t%s\t%s\n' "$1" "$2" "$3"; } > "$tmp" && mv -f "$tmp" "$AP_BASE"
}

ap_alvo() { # $1 nome $2 rev do pino
  local painel base b_painel b_alvo
  painel="$(ap_rev_painel)" || { printf '%s' "$2"; return 0; }
  base="$(_ap_base "$1")"
  if [ -z "$base" ]; then
    ap_registrar "$1" "$painel" "$2"
    printf '%s' "$2"; return 0
  fi
  b_painel="${base%%$'\t'*}"; b_alvo="${base#*$'\t'}"
  if [ "$painel" = "$b_painel" ]; then
    printf '%s' "$b_alvo"
  elif [ "$painel" = "$2" ] || ap_ja_falhou "$1" "$painel"; then
    printf '%s' "$2"
  else
    printf '%s' "$painel"
  fi
}

# Depois de um build que deu certo contra <alvo>: a base passa a ser o painel
# de agora. Sem painel conhecido, nada a gravar.
ap_compilou() { # $1 nome $2 alvo
  local painel
  painel="$(ap_rev_painel)" || return 0
  ap_registrar "$1" "$painel" "$2"
}

ap_falhou() { # $1 nome $2 rev
  _ap_pode_gravar || return 0
  ap_ja_falhou "$1" "$2" && return 0
  mkdir -p "${AP_FALHAS%/*}" && printf '%s\t%s\t%s\n' "$1" "$2" "$(date -Is)" >> "$AP_FALHAS"
}

_ap_conferir() {
  local painel nome pino alvo
  painel="$(ap_rev_painel)" || painel=""
  meow_info "libcosmic do cosmic-panel instalado: ${painel:-<não medido>}"
  while IFS='|' read -r nome pino; do
    [ -n "$pino" ] || continue
    alvo="$(ap_alvo "$nome" "$pino")"
    if [ "$alvo" = "$painel" ] && [ "$alvo" = "$pino" ]; then
      meow_ok "$nome: pinado no libcosmic do painel (${pino:0:7})"
    elif [ "$alvo" = "$painel" ]; then
      meow_info "$nome: o pino é ${pino:0:7} e o painel ${painel:0:7} — o próximo build segue o painel"
    else
      meow_aviso "$nome: segue o pino ${pino:0:7}$( [ -n "$painel" ] && ap_ja_falhou "$nome" "$painel" && printf ' (não compilou no %s do painel)' "${painel:0:7}")"
    fi
  done <<EOF
leitura|$(ap_rev_do_lock "$MEOW_RAIZ/src/applets/leitura/Cargo.lock")
midia|$(sed -n 's/^LIBCOSMIC="\(.*\)"/\1/p' "$MEOW_RAIZ/src/applets/now-playing/PINO" 2>/dev/null)
EOF
  return "$MEOW_OK"
}

# Lido com `.`: só as funções.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0

case "${1:-conferir}" in
  painel)   ap_rev_painel && printf '\n' ;;
  alvo)     [ $# -eq 3 ] || { meow_erro "uso: applet_pino.sh alvo <nome> <rev-do-pino>"; exit "$MEOW_ERRO"; }
            ap_alvo "$2" "$3"; printf '\n' ;;
  falhou)   [ $# -eq 3 ] || { meow_erro "uso: applet_pino.sh falhou <nome> <rev>"; exit "$MEOW_ERRO"; }
            ap_falhou "$2" "$3" ;;
  conferir) AP_SO_LER=1; _ap_conferir ;;
  *) meow_erro "uso: applet_pino.sh {painel|alvo <nome> <rev>|falhou <nome> <rev>|conferir}"; exit "$MEOW_ERRO" ;;
esac

#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

CONFERIR=0
for _a in "$@"; do
  case "$_a" in
    --conferir) CONFERIR=1 ;;
    -h|--help)
      printf 'uso: escala.sh [--conferir]\n\n  Aplica ESCALA_TELA em todas as saídas ligadas.\n  Vazio = não mexe (a escala é da GUI).\n\n  --conferir  só mostra o que está ligado e em que escala.\n'
      exit 0 ;;
    *) meow_erro "opção desconhecida: '$_a' — só existe --conferir"; exit 2 ;;
  esac
done
unset _a

ESCALA_TELA="${ESCALA_TELA:-}"

if ! meow_tem cosmic-randr; then
  meow_pula "cosmic-randr não está instalado — sem como falar com o compositor"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

saidas() {
  cosmic-randr list --kdl 2>/dev/null \
    | LC_ALL=C awk '
        /^output "/ {
          nome = $2; gsub(/"/, "", nome)
          ligada = (index($0, "enabled=#true") > 0)
          escala = ""
          next
        }
        /^  scale / { escala = $2 + 0; next }
        ligada && /^    mode / && /current=#true/ {
          printf "%s\t%s\t%s\t%s\t%.3f\n", nome, escala, $2, $3, $4 / 1000
          ligada = 0   # uma linha por saída: só o modo corrente interessa
        }
      ' \
    | LC_ALL=C sort -f -t "$(printf '\t')" -k1,1
}

mesma_escala() {
  LC_ALL=C awk -v a="$1" -v b="$2" 'BEGIN{ exit !(a+0 == b+0) }'
}

if [ "$CONFERIR" = "1" ]; then
  lista="$(saidas)"
  resumo="$(printf '%s\n' "$lista" | awk -F'\t' 'NF { printf "%s%s na escala %s", (n++ ? ", " : ""), $1, $2 }')"
  if [ -z "$ESCALA_TELA" ]; then
    meow_info "${resumo:-nenhuma saída ligada} — a escala é da GUI (Ajustes → Telas → Escala)"
  else
    meow_info "${resumo:-nenhuma saída ligada} — ESCALA_TELA pede $ESCALA_TELA em todas"
  fi
  while IFS=$'\t' read -r nome escala larg alt hz; do
    [ -n "$nome" ] || continue
    printf '    %-10s escala=%s  modo=%sx%s @ %s Hz\n' "$nome" "$escala" "$larg" "$alt" "$hz"
  done <<< "$lista"
  exit "$MEOW_OK"
fi

_escala_fracionaria() {
  case "$1" in
    1|1.0|1.00|2|2.0|2.00|3|3.0) return 1 ;;
    *) return 0 ;;
  esac
}

if [ -z "$ESCALA_TELA" ]; then
  meow_pula "ESCALA_TELA vazia — a escala fica com a GUI"
  if [ "${ESCALA_AVISAR:-sim}" = "sim" ]; then
    while IFS=$'\t' read -r nome escala larg alt hz; do
      [ -n "$nome" ] && [ -n "$escala" ] || continue
      if _escala_fracionaria "$escala"; then
        meow_aviso "$nome está em escala $escala (fracionária) — o traço fino dos ícones serrilha"
        meow_info "  o app desenha em 1x e o compositor reamostra: 1 px de traço vira ${escala} px"
        meow_info "  isso não tem conserto do lado do arquivo — o vetor já é rasterizado no tamanho certo"
        onde="$(meow_onde_no_painel ESCALA_TELA)"
        [ -z "$onde" ] || meow_info "  nitidez no lugar do tamanho: escala 1.0 em $onde"
      fi
    done < <(saidas)
  fi
  exit "$MEOW_OK"
fi

if [ "$ESCALA_TELA" = "nitida" ] || [ "$ESCALA_TELA" = "auto" ]; then
  ESCALA_AUTO=1
else
  ESCALA_AUTO=0
  case "$ESCALA_TELA" in
    [0-9]*.[0-9]*|[0-9]) : ;;
    *) meow_erro "ESCALA_TELA='$ESCALA_TELA' — esperado um número (1.0, 1.25) ou \"nitida\""
       exit "$MEOW_ERRO" ;;
  esac
fi

mudou=0
vistas=0
while IFS=$'\t' read -r nome escala larg alt hz; do
  [ -n "$nome" ] && [ -n "$larg" ] || continue
  vistas=$((vistas + 1))

  ALVO="$ESCALA_TELA"
  if [ "$ESCALA_AUTO" = "1" ]; then
    ALVO="$(LC_ALL=C awk -v e="$escala" 'BEGIN { n = int(e + 0.5); if (n < 1) n = 1; printf "%.1f", n }')"
  fi

  if mesma_escala "$escala" "$ALVO"; then
    [ "$ESCALA_AUTO" = "1" ] && meow_ok "$nome já está em escala inteira ($escala) — nada a reamostrar" \
                             || meow_ok "$nome já está em $ALVO"
    continue
  fi

  if meow_seco; then
    meow_muda "mudaria $nome de $escala para $ALVO"
    mudou=1
    continue
  fi

  if cosmic-randr mode "$nome" "$larg" "$alt" --refresh "$hz" --scale "$ALVO" 2>/dev/null; then
    meow_ok "$nome: escala $escala -> $ALVO (o traço fino para de ser reamostrado)"
    mudou=1
  else
    meow_erro "cosmic-randr recusou a escala $ALVO em $nome"
    exit "$MEOW_ERRO"
  fi
done < <(saidas)

if [ "$vistas" -eq 0 ]; then
  meow_pula "nenhuma saída ligada — nada a ajustar"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

[ "$mudou" = "0" ] && exit "$MEOW_OK"
meow_seco && exit "$MEOW_DIVERGENTE"

meow_info "apps Xwayland já abertos só assumem o tamanho novo ao reabrir"
exit "$MEOW_DIVERGENTE"

#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

CONFERIR=0
for _a in "$@"; do
  case "$_a" in
    --conferir) CONFERIR=1 ;;
    -h|--help) printf 'uso: vidro.sh [--conferir]\n\n  --conferir  não escreve nada: mostra o que está no disco e a\n              faixa real de alpha derivada do alpha_map de agora.\n'; exit 0 ;;
    *) meow_erro "opção desconhecida: '$_a' — só existe --conferir"; exit 2 ;;
  esac
done
unset _a

VIDRO_AO_MAXIMIZAR="${VIDRO_AO_MAXIMIZAR:-sim}"

VIDRO_OPACIDADE_PAINEL="${VIDRO_OPACIDADE_PAINEL:-${VIDRO_OPACIDADE:-}}"
VIDRO_OPACIDADE_DOCK="${VIDRO_OPACIDADE_DOCK:-${VIDRO_OPACIDADE:-}}"

case "$VIDRO_AO_MAXIMIZAR" in
  sim|true|1)  desejado="true" ;;
  nao|não|false|0) desejado="false" ;;
  *) meow_erro "VIDRO_AO_MAXIMIZAR='$VIDRO_AO_MAXIMIZAR' — esperado sim|nao"
     exit "$MEOW_ERRO" ;;
esac

normalizar_opacidade() {
  case "$2" in
    "")                  printf '' ;;
    [0-9]*.[0-9]*|[0-9]) printf '%s' "$2" ;;
    .[0-9]*)             printf '0%s' "$2" ;;
    *) meow_erro "$1='$2' — esperado um número entre 0 e 1 (ou vazio, para deixar com a GUI)"; return 1 ;;
  esac
}

op_painel="$(normalizar_opacidade VIDRO_OPACIDADE_PAINEL "$VIDRO_OPACIDADE_PAINEL")" \
  || exit "$MEOW_ERRO"
op_dock="$(normalizar_opacidade VIDRO_OPACIDADE_DOCK "$VIDRO_OPACIDADE_DOCK")" \
  || exit "$MEOW_ERRO"

descrever_opacidade() {
  case "$1" in
    "") printf 'da GUI' ;;
    *)  printf '%s' "$1" ;;
  esac
}

BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"
BARRAS=(Panel Dock)

_frosted_para_chave() {
  printf '%s' "$1" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g; s/([A-Za-z])([0-9])/\1_\2/g' \
    | tr 'A-Z' 'a-z'
}

faixa_alpha() {
  local am="$BASE/com.system76.CosmicTheme.Dark/v2/alpha_map"
  [ -r "$am" ] || { meow_pula "alpha_map ausente — sem faixa a mostrar"; return 0; }
  local lo hi frosted fator chave o fp
  lo="$(sed -nE 's/.*[^a-z_]extremely_high_2: *([0-9.]+).*/\1/p' "$am" | head -1)"
  hi="$(sed -nE 's/.*[^a-z_]extremely_low: *([0-9.]+).*/\1/p' "$am" | head -1)"
  [ -n "$lo" ] && [ -n "$hi" ] || { meow_pula "não consegui ler as pontas do alpha_map"; return 0; }

  fp="$(cat "$BASE/com.system76.CosmicTheme.Dark/v2/frosted_panel" 2>/dev/null)"
  [ -n "$fp" ] || fp="true"

  if [ "$fp" != "true" ]; then
    meow_info "frosted_panel=false — a caixa \"Painéis\" está DESMARCADA, então o"
    printf '    slider é 1:1: opacity 0,19 desenha 19%%, 1,00 desenha 100%%.\n'
    printf '    (o alpha_map não entra na conta enquanto ela estiver assim)\n'
    return 0
  fi

  meow_info "quanto da COR da barra é desenhada, com o alpha_map de agora:"
  printf '    %-9s %s\n' "opacity" "mais fosco  ->  menos fosco"
  for o in 0.10 0.19 0.24 0.26 0.50 1.00; do
    awk -v o="$o" -v lo="$lo" -v hi="$hi" \
      'BEGIN{printf "    %-9s %5.1f%%       ->  %5.1f%%\n", o, o*lo*100, o*hi*100}'
  done
  printf '    (a faixa vem do alpha_map vivo: %s a %s)\n' "$lo" "$hi"

  frosted="$(cat "$BASE/com.system76.CosmicTheme.Dark/v2/frosted" 2>/dev/null)" || return 0
  [ -n "$frosted" ] || return 0
  chave="$(_frosted_para_chave "$frosted")"
  fator="$(sed -nE "s/.*[^a-z_]${chave}: *([0-9.]+).*/\1/p" "$am" | head -1)"
  [ -n "$fator" ] || return 0
  local disco_p disco_d
  disco_p="$(cat "$BASE/com.system76.CosmicPanel.Panel/$(meow_cosmic_v com.system76.CosmicPanel.Panel)/opacity" 2>/dev/null)"
  disco_d="$(cat "$BASE/com.system76.CosmicPanel.Dock/$(meow_cosmic_v com.system76.CosmicPanel.Dock)/opacity" 2>/dev/null)"
  [ -n "$disco_p" ] && [ -n "$disco_d" ] || return 0
  awk -v f="$fator" -v p="$disco_p" -v d="$disco_d" -v n="$frosted" \
    'BEGIN{printf "    hoje, com frosted=%s (%.5f) e o que está no disco: painel %.1f%%, dock %.1f%%\n", n, f, p*f*100, d*f*100}'

  awk -v f="$fator" -v n="$frosted" -v hi="$hi" \
    'BEGIN{printf "    o TETO com frosted=%s é %.0f%% (mesmo com opacity=1,00). Para subir o teto\n", n, f*100;
           printf "    é \"Espessura do efeito fosco\" em Aparência: no outro extremo o teto vira %.0f%%.\n", hi*100}'
  printf '    E o que você VÊ depende do que está atrás: a cor da barra (#313244) some\n'
  printf '    contra uma janela escura e salta contra o papel de parede — medido em 23/08.\n'
}

avisar_slider_morto() {
  local barra dir v algum=0
  for barra in "${BARRAS[@]}"; do
    dir="$BASE/com.system76.CosmicPanel.$barra/$(meow_cosmic_v "com.system76.CosmicPanel.$barra")"
    [ -d "$dir" ] || continue
    v="$(cat "$dir/keep_style_on_maximize" 2>/dev/null)"
    [ "$v" = "false" ] || continue
    algum=1
    meow_aviso "$barra: keep_style_on_maximize=false — com janela maximizada a barra fica"
    meow_aviso "  chapada e a \"Opacidade do fundo\" que você escolher é ignorada (medido 23/08)"
  done
  [ "$algum" = "0" ]
}

if [ "$CONFERIR" = "1" ]; then
  meow_info "no disco agora:"
  for barra in "${BARRAS[@]}"; do
    dir="$BASE/com.system76.CosmicPanel.$barra/$(meow_cosmic_v "com.system76.CosmicPanel.$barra")"
    [ -d "$dir" ] || { meow_pula "com.system76.CosmicPanel.$barra não está configurado aqui"; continue; }
    printf '    %-6s opacity=%s  keep_style_on_maximize=%s\n' "$barra" \
      "$(cat "$dir/opacity" 2>/dev/null || echo '?')" \
      "$(cat "$dir/keep_style_on_maximize" 2>/dev/null || echo '?')"
  done
  for dir_tema in "$BASE"/com.system76.CosmicTheme.*/v*; do
    [ -d "$dir_tema" ] || continue
    [ -f "$dir_tema/frosted_maximized_apps" ] || continue
    printf '    %-6s frosted_maximized_apps=%s  (%s)\n' "janela" \
      "$(cat "$dir_tema/frosted_maximized_apps" 2>/dev/null || echo '?')" \
      "$(basename "$(dirname "$dir_tema")" | sed 's/com.system76.CosmicTheme.//')"
    janela_vista=1
  done
  if [ -z "${janela_vista:-}" ]; then
    meow_pula "este COSMIC não tem a chave nativa da janela — quem cuida dela é scripts/vidro_janela.py"
    [ -f "$RAIZ/scripts/vidro_janela.py" ] && python3 "$RAIZ/scripts/vidro_janela.py" --conferir || true
  fi
  meow_info "o que este script quer: painel $(descrever_opacidade "$op_painel"), dock $(descrever_opacidade "$op_dock"), ao maximizar $desejado"
  faixa_alpha
  avisar_slider_morto || true
  exit "$MEOW_OK"
fi

mudou=0
escritos=0
for barra in "${BARRAS[@]}"; do
  dir="$BASE/com.system76.CosmicPanel.$barra/$(meow_cosmic_v "com.system76.CosmicPanel.$barra")"
  [ -d "$dir" ] || { meow_pula "com.system76.CosmicPanel.$barra não está configurado aqui"; continue; }

  escritos=$((escritos + 1))
  case "$barra" in Panel) opacidade="$op_painel" ;; *) opacidade="$op_dock" ;; esac

  meow_escrever "$dir/keep_style_on_maximize" "$desejado" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $dir/keep_style_on_maximize"; exit "$MEOW_ERRO" ;;
  esac
  if [ -n "$opacidade" ]; then
    meow_escrever "$dir/opacity" "$opacidade" 644
    case $? in
      1) mudou=1 ;;
      2) meow_erro "não consegui escrever $dir/opacity"; exit "$MEOW_ERRO" ;;
    esac
  fi
done

janela_nativa=0
for dir_tema in "$BASE"/com.system76.CosmicTheme.*/v*; do
  [ -d "$dir_tema" ] || continue
  [ -f "$dir_tema/frosted_maximized_apps" ] || continue
  janela_nativa=1
  escritos=$((escritos + 1))
  meow_escrever "$dir_tema/frosted_maximized_apps" "$desejado" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $dir_tema/frosted_maximized_apps"; exit "$MEOW_ERRO" ;;
  esac
done

if [ "$janela_nativa" -eq 0 ] && [ -f "$RAIZ/scripts/vidro_janela.py" ]; then
  args_janela=()
  [ "$desejado" = "true" ] || args_janela=(--restaurar)
  if meow_seco; then
    python3 "$RAIZ/scripts/vidro_janela.py" --conferir "${args_janela[@]}" || mudou=1
  else
    python3 "$RAIZ/scripts/vidro_janela.py" "${args_janela[@]}" || true
  fi
fi

if [ "$escritos" -eq 0 ]; then
  meow_pula "não há painel nem dock configurados — nada a ajustar"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

conferir_receita() {
  local b="$BASE/com.system76.CosmicTheme.Dark.Builder/v2"
  local d="$BASE/com.system76.CosmicTheme.Dark/v2"
  [ -f "$b/frosted" ] && [ -f "$b/alpha_map" ] && [ -f "$d/transparent_background" ] || return 0

  local nome chave fator esperado gravado
  nome="$(cat "$b/frosted")"
  chave="$(_frosted_para_chave "$nome")"
  fator="$(sed -nE "s/.*[^a-z_]${chave}: *([0-9.]+).*/\1/p" "$b/alpha_map" | head -1)"
  [ -n "$fator" ] || return 0

  esperado="$(python3 -I -c "print(f'{round($fator*255):02X}')" 2>/dev/null)" || return 0
  gravado="$(grep -oE '#[0-9A-Fa-f]{8}' "$d/transparent_background" | head -1)"
  gravado="${gravado: -2}"
  [ -n "$gravado" ] || return 0

  if [ "$esperado" != "$gravado" ]; then
    meow_aviso "o vidro na tela não é o que você escolheu: '$nome' pede alpha $esperado, está gravado $gravado"
    local de_quem
    de_quem="$(python3 -I - "$b/alpha_map" "$gravado" <<'FIM' 2>/dev/null
import re, sys
alvo = int(sys.argv[2], 16)
texto = open(sys.argv[1], encoding="utf-8", errors="replace").read()
for chave, valor in re.findall(r"([a-z_0-9]+):\s*([0-9.]+)", texto):
    if round(float(valor) * 255) == alvo:
        print(chave); break
FIM
)"
    [ -n "$de_quem" ] && meow_info "o alpha $gravado é o do nível '$de_quem' — a cor foi derivada com OUTRA escolha de vidro"
    local par="" cap="" alfa_cap=""
    if [ -n "${FLAVOR:-}" ] && [ -n "${ACCENT:-}" ]; then
      par="$FLAVOR-$ACCENT"
      cap="$(meow_captura "$par")"
    fi
    [ -n "$cap" ] && alfa_cap="$(MEOW_COSMIC_DIR="$BASE" \
      python3 "$RAIZ/scripts/derivar_vidro.py" "$cap" --alfa 2>/dev/null)"
    if [ -n "$alfa_cap" ] && [ "$alfa_cap" = "$esperado" ]; then
      meow_info "a captura '$par', aplicada aqui, grava o alpha $esperado deste nível:  meow tema $par"
    else
      [ -n "$alfa_cap" ] \
        && meow_info "reaplicar a captura '$par' não resolve: aplicada aqui, ela grava alpha $alfa_cap"
      meow_info "abra Aparência e mova o slider de opacidade uma vez — só a GUI deriva a cor corretamente"
    fi
    return 1
  fi
  return 0
}

op_msg="painel $(descrever_opacidade "$op_painel"), dock $(descrever_opacidade "$op_dock")"

if [ "$mudou" = "0" ]; then
  saida_receita="$(conferir_receita 2>&1)"; rc_receita=$?
  if [ "$rc_receita" != "0" ]; then
    printf '%s\n' "$saida_receita" | head -1
    if [ "$desejado" = "true" ]; then
      meow_info "o que o MeowSystem grava confere: $op_msg, mantido ao maximizar"
    else
      meow_info "o que o MeowSystem grava confere: $op_msg; sai ao maximizar (padrão do COSMIC)"
      meow_aviso "com isso a \"Opacidade do fundo\" da GUI é ignorada enquanto houver janela"
      meow_aviso "  maximizada — a barra fica chapada na cor do tema (medido em 23/08/2026)"
    fi
    printf '%s\n' "$saida_receita" | tail -n +2
    exit 4
  fi
  if [ "$desejado" = "true" ]; then
    meow_ok "vidro já conforme: $op_msg, mantido ao maximizar"
  else
    meow_ok "vidro já conforme: $op_msg; sai ao maximizar (padrão do COSMIC)"
    meow_aviso "com isso a \"Opacidade do fundo\" da GUI é ignorada enquanto houver janela"
    meow_aviso "  maximizada — a barra fica chapada na cor do tema (medido em 23/08/2026)"
  fi
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

if [ "$desejado" = "true" ]; then
  meow_ok "$op_msg, vidro mantido ao maximizar — já valendo"
else
  meow_ok "$op_msg; o vidro sai ao maximizar — já valendo"
  meow_aviso "com isso a \"Opacidade do fundo\" da GUI é ignorada enquanto houver janela"
  meow_aviso "  maximizada — a barra fica chapada na cor do tema (medido em 23/08/2026)"
fi
exit "$MEOW_DIVERGENTE"

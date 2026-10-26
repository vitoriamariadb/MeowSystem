#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/noite.sh
. "$RAIZ/lib/noite.sh"

ACERVO="$(meow_mascote_dir)/"
COSMIC="$(meow_cosmic_dir)"
LOGOS_DIR="$COSMIC/logos"

_applet_de_logo() {
  local dir arq
  for dir in "${XDG_DATA_HOME:-$HOME/.local/share}" \
             $(printf '%s' "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' ' '); do
    for arq in "$dir"/applications/*LogoMenu.desktop; do
      grep -qsx 'X-CosmicApplet=true' "$arq" && { basename "$arq" .desktop; return 0; }
    done
  done
  return 1
}
APPLET_ID="$(_applet_de_logo)"
APPLET="$COSMIC/${APPLET_ID:-sem-applet-de-logo}/v1"
ESTADO="$MEOW_ESTADO/logo-atual"

FLAVOR="$(meow_flavor)"
LOGO="${LOGO:-$FLAVOR}"

if [ -n "${LOGO_MODO:-}" ]; then
  :
elif [ "${LOGO_ROTACAO:-nao}" = "sim" ]; then
  LOGO_MODO="rotacao"
else
  LOGO_MODO="hora"
fi

LOGO_DIA="${LOGO_DIA:-mimir}"
LOGO_NOITE="${LOGO_NOITE:-coquinha}"
LOGO_RECICLAR="${LOGO_RECICLAR:-sim}"

CONFERIR=0
ACAO="aplicar"
case "${1:-}" in
  --conferir)    CONFERIR=1; MEOW_SECO=1; MEOW_DRY_RUN=1; export MEOW_DRY_RUN ;;
  girar)         ACAO="girar" ;;
  girar-vencido) ACAO="girar-vencido" ;;
  listar)        ACAO="listar" ;;
  modo)          printf '%s\n' "$LOGO_MODO"; exit "$MEOW_OK" ;;
  no-dock)       ACAO="no-dock" ;;
  applet)
    [ -n "$APPLET_ID" ] && [ -f "$APPLET/custom_logo_path" ] || exit "$MEOW_DIVERGENTE"
    printf '%s\n' "$(cat "$APPLET/custom_logo_path")"; exit "$MEOW_OK" ;;
  aplicar|"") ;;
  *) meow_erro "uso: logo.sh [aplicar|girar|girar-vencido|listar|no-dock|modo|applet|--conferir]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

CARIMBO_GIRO="$MEOW_ESTADO/logo-girado-em"

_segundos_de() {
  local v="${1:-1d}" n="${1:-1d}"; n="${n%[smhd]}"
  case "$n" in ''|*[!0-9]*) printf '86400'; return ;; esac
  case "$v" in
    *s) printf '%s' "$n" ;;
    *m) printf '%s' "$((n * 60))" ;;
    *h) printf '%s' "$((n * 3600))" ;;
    *d) printf '%s' "$((n * 86400))" ;;
    *)  printf '%s' "$n" ;;
  esac
}

_giro_venceu() {
  local ultimo agora intervalo
  ultimo="$(cat "$CARIMBO_GIRO" 2>/dev/null)"
  case "$ultimo" in ''|*[!0-9]*) return 0 ;; esac
  agora="$(date +%s)"
  intervalo="$(_segundos_de "${LOGO_INTERVALO:-1d}")"
  [ "$((agora - ultimo))" -ge "$intervalo" ]
}

if [ "$ACAO" = "girar" ] || [ "$ACAO" = "girar-vencido" ]; then
  if [ "$LOGO_MODO" != "rotacao" ]; then
    meow_pula "o modo é \`$LOGO_MODO\` — o mascote não gira, ele segue o relógio"
    meow_info "  para girar: LOGO_MODO=\"rotacao\" no ~/.config/meow/meow.conf"
    exit "$MEOW_OK"
  fi
fi

if [ "$ACAO" = "girar-vencido" ]; then
  if _giro_venceu; then
    ACAO="girar"
  else
    meow_info "o mascote ainda não venceu (${LOGO_INTERVALO:-1d}) — nada a girar"
    exit "$MEOW_OK"
  fi
fi

if [ "$ACAO" != "no-dock" ] && [ -d "$ACERVO" ] && meow_tem python3 \
   && [ -f "$RAIZ/scripts/normalizar_svg.py" ]; then
  if meow_seco; then
    python3 "$RAIZ/scripts/normalizar_svg.py" --conferir "$ACERVO" || true
  else
    _svg_saida="$(python3 "$RAIZ/scripts/normalizar_svg.py" "$ACERVO" 2>&1)"
    if [ -n "$_svg_saida" ]; then
      printf '%s\n' "$_svg_saida"
      case "$_svg_saida" in
        *"não vai aparecer"*|*"não sei"*)
          meow_notificar "MeowSystem" \
            "Um mascote do acervo tem desenho que o painel não sabe mostrar — meow doctor conta qual." 2>/dev/null || true ;;
      esac
    fi
    unset _svg_saida
  fi
fi

declare -a POOL=() NOMES=()
if [ -d "$ACERVO" ]; then
  while IFS= read -r svg; do
    case "$(basename "$svg")" in *-symbolic.svg) continue ;; esac
    POOL+=("$svg"); NOMES+=("$(basename "${svg%.svg}")")
  done < <(find "$ACERVO" -maxdepth 1 -name '*.svg' | sort)
fi

if [ "${#POOL[@]}" -eq 0 ]; then
  meow_pula "não há mascote nenhum em $ACERVO — solte um .svg lá e ele entra"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

destino_de() { printf '%s/meow-%s.svg' "$LOGOS_DIR" "$1"; }

_tema="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
_no_dock="$HOME/.local/share/icons/$_tema/scalable/apps/com.system76.CosmicPanelAppButton.svg"

_esta_no_dock() {
  local instalado
  instalado="$(destino_de "${NOMES[$1]}")"
  [ -f "$instalado" ] || instalado="${POOL[$1]}"
  [ -f "$_no_dock" ] && cmp -s "$instalado" "$_no_dock"
}

if [ "$ACAO" = "no-dock" ]; then
  for i in "${!NOMES[@]}"; do
    _esta_no_dock "$i" && { printf '%s\n' "${NOMES[$i]}"; exit "$MEOW_OK"; }
  done
  exit "$MEOW_DIVERGENTE"
fi

if [ "$ACAO" = "listar" ]; then
  atual="$(cat "$APPLET/custom_logo_path" 2>/dev/null | tr -d '"')"
  meow_titulo "Gatos do painel (${#POOL[@]})"
  for i in "${!NOMES[@]}"; do
    _marca=""
    [ "$(destino_de "${NOMES[$i]}")" = "$atual" ] && _marca="  <- na chave do applet"
    if _esta_no_dock "$i"; then
      _marca="$_marca  <- NO DOCK (é o que você vê)"
    fi
    if [ -n "$_marca" ]; then meow_ok "${NOMES[$i]}$_marca"; else meow_info "${NOMES[$i]}"; fi
  done

  _j="$(meow_noite_janela)"
  _ini="${_j%% *}"; _fim="${_j#* }"; _fim="${_fim%% *}"
  printf '\n  modo    : %s' "$LOGO_MODO"
  case "$LOGO_MODO" in
    hora)    printf '  (dia=%s · noite=%s)\n' "$LOGO_DIA" "$LOGO_NOITE" ;;
    rotacao) printf '  (gira a cada %s, no encerramento da sessão)\n' "${LOGO_INTERVALO:-1d}" ;;
    *)       printf '  (LOGO="%s" vence sempre)\n' "$LOGO" ;;
  esac
  printf '  noite   : %s–%s  (fonte: %s)\n' \
    "$(meow_hora_de_minutos "$_ini")" "$(meow_hora_de_minutos "$_fim")" "${_j##* }"
  printf '  agora   : %s, portanto é %s\n' "$(date +%H:%M)" "$(meow_fase_da_hora "$_ini" "$_fim")"
  printf '  acervo  : %s\n  solte um .svg ali e ele entra.\n\n' "$ACERVO"
  exit "$MEOW_OK"
fi

TEM_APPLET=1
if [ -z "$APPLET_ID" ]; then
  TEM_APPLET=0
  meow_pula "nenhum applet de logo do painel instalado — o mascote do dock e o do terminal seguem"
fi

applet_montado() {
  local barras="$COSMIC/com.system76.CosmicPanel" vp vd
  vp="$(meow_cosmic_v com.system76.CosmicPanel.Panel)"; vd="$(meow_cosmic_v com.system76.CosmicPanel.Dock)"
  grep -qs 'LogoMenu' "$barras.Panel/$vp/plugins_wings" "$barras.Panel/$vp/plugins_center" \
                      "$barras.Dock/$vd/plugins_wings"  "$barras.Dock/$vd/plugins_center"
}

if [ "${LOGO_ROTACAO:-nao}" = "sim" ] && ! applet_montado; then
  meow_aviso "o applet da logo não está em nenhuma das barras — girar não muda nada na tela"
  meow_info "  para usá-lo: Ajustes → Área de trabalho → Painel → Applets, e acrescente"
  meow_info "  \"Logo Menu\". A ordem dos applets é sua; este script não mexe nisso."
fi

mudou=0

for i in "${!POOL[@]}"; do
  meow_escrever "$(destino_de "${NOMES[$i]}")" "$(cat "${POOL[$i]}")" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "não consegui instalar ${NOMES[$i]}"; exit "$MEOW_ERRO" ;;
  esac
done

if [ -d "$LOGOS_DIR" ]; then
  for velho in "$LOGOS_DIR"/meow-*.svg; do
    [ -f "$velho" ] || continue
    conhecido=0
    for n in "${NOMES[@]}"; do
      [ "$velho" = "$(destino_de "$n")" ] && { conhecido=1; break; }
    done
    [ "$conhecido" = "1" ] && continue
    if meow_seco; then
      meow_muda "removeria $(basename "$velho") (saiu do acervo)"
      mudou=1
    else
      rm -f "$velho" && mudou=1
    fi
  done
fi

atual="$(cat "$APPLET/custom_logo_path" 2>/dev/null | tr -d '"')"
indice=-1
for i in "${!NOMES[@]}"; do
  [ "$(destino_de "${NOMES[$i]}")" = "$atual" ] && { indice=$i; break; }
done
if [ "$indice" -lt 0 ]; then
  for i in "${!NOMES[@]}"; do
    _esta_no_dock "$i" && { indice=$i; break; }
  done
fi

_indice_de() {
  local alvo="$1" i
  for i in "${!NOMES[@]}"; do
    [ "${NOMES[$i]}" = "$alvo" ] && { printf '%s' "$i"; return 0; }
  done
  printf '%s' "-1"
}

FASE=""; FONTE_JANELA=""
if [ "$ACAO" = "girar" ]; then
  proximo=$(( (indice + 1) % ${#NOMES[@]} ))
  [ "$indice" -lt 0 ] && proximo=0
elif [ "$LOGO_MODO" = "hora" ]; then
  _j="$(meow_noite_janela)"
  _ini="${_j%% *}"; _fim="${_j#* }"; _fim="${_fim%% *}"; FONTE_JANELA="${_j##* }"
  if meow_e_noite "$_ini" "$_fim"; then FASE="noite"; _quer="$LOGO_NOITE"
  else                                  FASE="dia";   _quer="$LOGO_DIA"; fi

  proximo="$(_indice_de "$_quer")"
  if [ "$proximo" -lt 0 ]; then
    _padrao="$(python3 "$RAIZ/scripts/pack.py" mascote-padrao "$(meow_pack_dir)" "$FASE" 2>/dev/null)"
    proximo="$(_indice_de "${_padrao:-}")"
    unset _padrao
  fi
  if [ "$proximo" -lt 0 ]; then
    meow_aviso "LOGO_${FASE^^}=\"$_quer\" não está em $ACERVO — caindo em \"$LOGO\""
    proximo="$(_indice_de "$LOGO")"
    [ "$proximo" -lt 0 ] && proximo=0
  fi
  unset _j _ini _fim _quer
elif [ "$LOGO_MODO" = "fixo" ]; then
  proximo="$(_indice_de "$LOGO")"
  if [ "$proximo" -lt 0 ]; then
    if [ "$indice" -ge 0 ]; then
      proximo="$indice"
      meow_aviso "LOGO=\"$LOGO\" não está em $ACERVO — fica o mascote que está no ar, ${NOMES[$proximo]}"
    else
      proximo=0
      meow_aviso "LOGO=\"$LOGO\" não está em $ACERVO, e nenhum mascote do acervo está no ar — vai o primeiro, ${NOMES[0]}"
    fi
  fi
else
  if [ "$indice" -ge 0 ]; then
    proximo="$indice"
  else
    proximo=0
    for i in "${!NOMES[@]}"; do
      [ "${NOMES[$i]}" = "$LOGO" ] && { proximo=$i; break; }
    done
  fi
fi

alvo="$(destino_de "${NOMES[$proximo]}")"
if [ "$alvo" != "$atual" ]; then
  if [ "$TEM_APPLET" = "1" ]; then
    meow_escrever "$APPLET/custom_logo_path" "\"$alvo\"" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "não consegui apontar a logo"; exit "$MEOW_ERRO" ;; esac
  fi
  meow_seco || meow_escrever "$ESTADO" "${NOMES[$proximo]}" 644 >/dev/null || true
fi

if [ "$ACAO" = "girar" ] && ! meow_seco; then
  meow_escrever "$CARIMBO_GIRO" "$(date +%s)" 644 >/dev/null || true
fi

if [ "$TEM_APPLET" = "1" ]; then
  meow_escrever "$APPLET/custom_logo_active" "true" 644
  case $? in 1) mudou=1 ;; esac
fi

TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
BOTOES_DOCK=(com.system76.CosmicPanelAppButton com.system76.CosmicAppLibrary)
DIR_BOTOES="$HOME/.local/share/icons/$TEMA_ICONES/scalable/apps"

dock_mudou=0
if [ -f "$alvo" ]; then
  for _b in "${BOTOES_DOCK[@]}"; do
    meow_escrever "$DIR_BOTOES/$_b.svg" "$(cat "$alvo")" 644
    case $? in
      1) mudou=1; dock_mudou=1 ;;
      2) meow_erro "não consegui vestir o botão do dock com $_b"; exit "$MEOW_ERRO" ;;
    esac
  done
fi

if [ "$dock_mudou" = "1" ] && ! meow_seco; then
  if [ "$LOGO_RECICLAR" != "sim" ]; then
    meow_info "mascote do dock trocado; LOGO_RECICLAR=\"$LOGO_RECICLAR\" — vale no próximo login"
  elif [ -x "$RAIZ/scripts/painel.sh" ]; then
    meow_info "mascote do dock trocado — reciclando o painel para ele aparecer"
    meow_tela_reler || true
  fi
fi

if ! meow_seco && [ -x "$RAIZ/scripts/fastfetch_logo.sh" ]; then
  FFL_FUNDO=1 LOG_NIVEL=silencioso "$RAIZ/scripts/fastfetch_logo.sh" aplicar >/dev/null 2>&1 || true
fi

PORQUE=""
if [ -n "$FASE" ]; then
  _j="$(meow_noite_janela)"; _i="${_j%% *}"; _f="${_j#* }"; _f="${_f%% *}"
  PORQUE=" — $FASE, janela $(meow_hora_de_minutos "$_i")–$(meow_hora_de_minutos "$_f") ($FONTE_JANELA)"
  unset _j _i _f
fi

if [ "$mudou" = "0" ]; then
  meow_ok "logo já no lugar: ${NOMES[$proximo]}$PORQUE"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"
if [ "$ACAO" = "girar" ]; then
  meow_ok "o mascote do painel agora é ${NOMES[$proximo]} — já valendo, sem reiniciar"
else
  meow_ok "acervo de ${#POOL[@]} mascote(s) instalado; no ar: ${NOMES[$proximo]}$PORQUE"
fi
exit "$MEOW_DIVERGENTE"

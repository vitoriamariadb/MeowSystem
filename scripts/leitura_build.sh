#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

RECEITA="$RAIZ/src/applets/leitura"
FONTE="$RECEITA/src/main.rs"
MANIFESTO="$RECEITA/Cargo.toml"
TRAVA="$RECEITA/Cargo.lock"

ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/leitura"
ALVO="$ESTADO/target"
CARIMBO="$ESTADO/carimbo"

APP_ID="com.meowsystem.AppletLeitura"
BINARIO="$HOME/.local/bin/meow-applet-leitura"
SOMBRA="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$APP_ID.desktop"
ASA="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/$(meow_cosmic_v com.system76.CosmicPanel.Panel)/plugins_wings"
MEIO="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/$(meow_cosmic_v com.system76.CosmicPanel.Panel)/plugins_center"

LEITURA_APPLET="${LEITURA_APPLET:-sim}"
COMPILAR="${LEITURA_COMPILAR:-0}"

. "$RAIZ/scripts/applet_pino.sh"
PINO_REV="$(ap_rev_do_lock "$TRAVA")"
_alvo_rev() { ap_alvo leitura "$PINO_REV"; }

CONFERIR=0; REVERTER=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --reverter) REVERTER=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$REVERTER" = 0 ] && CONFERIR=1
[ "$CONFERIR" = 1 ] && AP_SO_LER=1

_sha() { sha256sum -- "$1" 2>/dev/null | cut -d' ' -f1; }

_rustc_versao() {
  meow_seco && return 0
  meow_tem rustc || return 0
  rustc -V 2>/dev/null
}

_texto_sombra() {
  cat <<EOF
[Desktop Entry]
Name=Modo de leitura
Comment=Temperatura de cor e textura de papel, do MeowSystem
Exec=$BINARIO
Terminal=false
Type=Application
StartupNotify=true
Icon=night-light-symbolic
Categories=COSMIC;Utility;
Keywords=COSMIC;Applet;Leitura;Temperatura;Noite;
NoDisplay=true
X-CosmicApplet=true
X-CosmicShrinkable=true
EOF
}

ARTE=(
  "$RAIZ/packs/meowsystem/icones/sistema/leitura-r2.svg"
  "$RAIZ/packs/meowsystem/icones/sistema/leitura-s3.svg"
  "$RAIZ/packs/meowsystem/icones/sistema/leitura-r1.svg"
  "$RAIZ/packs/meowsystem/icones/sistema/leitura-r6.svg"
)

_sha_arte() {
  local f saida=""
  for f in "${ARTE[@]}"; do saida="$saida$(_sha "$f")"; done
  printf '%s' "$saida" | sha256sum | cut -d' ' -f1
}

_carimbo_vivo() {
  local alvo; alvo="$(_alvo_rev)"
  printf 'fonte %s\nreceita %s\ntrava %s\narte %s\nbinario %s\nrustc %s\n' \
    "$(_sha "$FONTE")" "$(_sha "$MANIFESTO")" "$(_sha "$TRAVA")" \
    "$(_sha_arte)" "$(_sha "$BINARIO")" "$(_rustc_versao)"
  [ "$alvo" = "$PINO_REV" ] || printf 'libcosmic %s\n' "$alvo"
}

_carimbo_bate() {
  [ -f "$CARIMBO" ] || return 1
  local campo vivo gravado
  while read -r campo vivo; do
    [ -z "$vivo" ] && continue
    gravado="$(sed -n "s/^$campo //p" "$CARIMBO" | head -1)"
    [ "$gravado" = "$vivo" ] || return 1
  done <<< "$(_carimbo_vivo)"
  return 0
}

_pronto() {
  local f
  for f in "$FONTE" "$MANIFESTO" "$TRAVA" "${ARTE[@]}"; do
    if [ ! -f "$f" ]; then
      meow_erro "falta $f — repositório incompleto"
      return "$MEOW_ERRO"
    fi
  done
  return "$MEOW_OK"
}

_asa_cita() { grep -qs "\"$APP_ID\"" "$ASA" "$MEIO"; }

_orfa() { [ -f "$SOMBRA" ] && [ ! -x "$BINARIO" ]; }

_conferir() {
  if [ ! -x "$BINARIO" ]; then
    meow_muda "o applet do modo de leitura ainda não foi compilado ($BINARIO)"
    return "$MEOW_DIVERGENTE"
  fi

  if ! _carimbo_bate; then
    meow_muda "o applet de leitura instalado não é o desta receita (fonte, Cargo.toml, Cargo.lock, os SVGs ou o rustc mudaram)"
    return "$MEOW_DIVERGENTE"
  fi

  if [ ! -f "$SOMBRA" ] || [ "$(_texto_sombra)" != "$(cat "$SOMBRA" 2>/dev/null)" ]; then
    meow_muda "a sombra do applet de leitura não está no lugar ($SOMBRA)"
    return "$MEOW_DIVERGENTE"
  fi

  if ! _asa_cita; then
    meow_info "o applet está instalado, e a topbar não o cita (a ordem dos applets é de quem usa)"
  fi

  meow_ok "applet do modo de leitura $(_sha "$BINARIO" | cut -c1-8) já é o do repositório"
  return "$MEOW_OK"
}

_sem_cargo() {
  local pronto="$ALVO/release/meow-applet-leitura" gravado r

  meow_seco && return 1

  if [ ! -x "$BINARIO" ]; then
    [ -x "$pronto" ] || return 1
    _carimbo_bate || return 1
    gravado="$(sed -n 's/^binario //p' "$CARIMBO" | head -1)"
    [ -n "$gravado" ] || return 1
    [ "$gravado" = "$(_sha "$pronto")" ] || return 1

    meow_destino_permitido "$BINARIO" || return 1
    install -Dm0755 "$pronto" "$BINARIO" || return 1
    meow_manifesto_registrar "$BINARIO"
    meow_muda "o binário sumiu e a árvore de build ainda tinha o dele — reposto sem compilar"
  else
    _carimbo_bate || return 1
  fi

  meow_escrever "$SOMBRA" "$(_texto_sombra)" 644; r=$?
  [ "$r" = 2 ] && { meow_erro "não consegui escrever $SOMBRA"; return 1; }
  return 0
}

_aplicar() {
  _conferir >/dev/null 2>&1 && { meow_pendencia_resolvida leitura-applet; _conferir; return $?; }

  if _sem_cargo; then
    _conferir
    meow_registrar "leitura_build.sh reconciliou sem compilar"
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$COMPILAR" != "1" ]; then
    meow_pendencia_acionavel leitura-applet \
      "O applet do modo de leitura precisa ser compilado" "meow doctor --consertar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_garantir_cargo; then
    meow_pula "sem cargo, e o rust não pôde ser instalado agora — o applet do modo de leitura fica de fora"
    meow_pendencia_acionavel leitura-applet \
      "O applet do modo de leitura precisa do rust, e a instalação dele não respondeu" \
      "meow doctor --consertar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_destino_permitido "$BINARIO" || return "$MEOW_ERRO"
  mkdir -p "$ESTADO" || { meow_erro "não consegui criar $ESTADO"; return "$MEOW_ERRO"; }

  meow_info "compilando o applet do modo de leitura (build frio de libcosmic: dezenas de minutos)"
  local alvo_rev compilou=0
  alvo_rev="$(_alvo_rev)"
  if [ "$alvo_rev" != "$PINO_REV" ]; then
    local copia="$ESTADO/receita-painel"
    rm -rf "$copia" && mkdir -p "$copia" && cp -a "$RECEITA"/. "$copia"/ \
      && sed -i "s/$PINO_REV/$alvo_rev/" "$copia/Cargo.toml"
    meow_info "compilando contra o libcosmic do painel instalado (${alvo_rev:0:7})"
    if CARGO_TARGET_DIR="$ALVO" cargo build --release \
         --manifest-path "$copia/Cargo.toml" >/dev/null 2>&1; then
      compilou=1
    else
      ap_falhou leitura "$alvo_rev"
      meow_aviso "o applet não compila no libcosmic ${alvo_rev:0:7} do painel — volta ao pino ${PINO_REV:0:7}"
    fi
  fi
  if [ "$compilou" = 0 ] && ! CARGO_TARGET_DIR="$ALVO" cargo build --release --locked \
        --manifest-path "$MANIFESTO" >"$ESTADO/compilar.log" 2>&1; then
    meow_erro "o cargo falhou — $(meow_motivo_do_cargo "$ESTADO/compilar.log")"
    meow_info "  o registro está em $ESTADO/compilar.log"
    meow_info "  o binário anterior, se houver, segue instalado e funcionando; nada foi trocado"
    return "$MEOW_ERRO"
  fi

  local recem="$ALVO/release/meow-applet-leitura"
  [ -x "$recem" ] || { meow_erro "o cargo terminou e não deixou binário em $recem"; return "$MEOW_ERRO"; }

  install -Dm0755 "$recem" "$BINARIO" || { meow_erro "não consegui instalar $BINARIO"; return "$MEOW_ERRO"; }

  meow_manifesto_registrar "$BINARIO"

  meow_escrever "$SOMBRA" "$(_texto_sombra)" 644
  case $? in
    2) meow_erro "não consegui escrever $SOMBRA"; return "$MEOW_ERRO" ;;
  esac

  if [ "$compilou" = 1 ]; then ap_compilou leitura "$alvo_rev"; else ap_compilou leitura "$PINO_REV"; fi
  _carimbo_vivo > "$CARIMBO" || { meow_erro "não consegui gravar o carimbo"; return "$MEOW_ERRO"; }

  meow_ok "applet do modo de leitura compilado e instalado ($(_sha "$BINARIO" | cut -c1-8))"
  meow_pendencia_resolvida leitura-applet
  if ! _asa_cita; then
    meow_info "a topbar não cita o applet ainda (a ordem dos applets é de quem usa)"
  else
    meow_info "a topbar já cita o applet — ele sobe junto com o painel"
  fi
  meow_registrar "leitura_build.sh instalou $(_sha "$BINARIO" | cut -c1-8)"
  return "$MEOW_DIVERGENTE"
}

_reverter() {
  local mexeu=0
  if meow_seco; then
    [ -f "$SOMBRA" ]  && { meow_muda "removeria a sombra $SOMBRA"; mexeu=1; }
    [ -e "$BINARIO" ] && { meow_muda "removeria o binário $BINARIO"; mexeu=1; }
    [ -d "$ESTADO" ]  && { meow_muda "removeria a árvore de build $ESTADO"; mexeu=1; }
    [ "$mexeu" = 1 ] && return "$MEOW_DIVERGENTE"
    meow_pula "não há applet de leitura nosso para remover"
    return "$MEOW_OK"
  fi

  [ -f "$SOMBRA" ]  && { rm -f "$SOMBRA";  mexeu=1; }
  [ -e "$BINARIO" ] && { rm -f "$BINARIO"; mexeu=1; }
  [ -d "$ESTADO" ]  && { rm -rf "$ESTADO"; mexeu=1; }

  if [ "$mexeu" = 0 ]; then
    meow_pula "não havia applet de leitura nosso para remover"
    return "$MEOW_OK"
  fi
  if _asa_cita; then
    meow_info "a topbar ainda cita \"$APP_ID\", e sem a sombra o painel ignora o nome"
  fi
  meow_ok "applet do modo de leitura removido — a topbar volta sem ele no próximo login"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$REVERTER" = 1 ] && { _reverter; return $?; }
  if [ "$LEITURA_APPLET" != "sim" ]; then
    if [ -f "$SOMBRA" ] || [ -x "$BINARIO" ]; then
      meow_muda "LEITURA_APPLET=\"$LEITURA_APPLET\" no meow.conf, mas o applet continua instalado"
      [ "$CONFERIR" = 1 ] && return "$MEOW_DIVERGENTE"
      meow_pendencia_resolvida leitura-applet
      _reverter; return $?
    fi
    [ "$CONFERIR" = 1 ] || meow_pendencia_resolvida leitura-applet
    meow_pula "LEITURA_APPLET=\"$LEITURA_APPLET\" no meow.conf — sem applet do modo de leitura"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if _orfa; then
    if [ "$CONFERIR" = 1 ] || meow_seco; then
      meow_muda "a sombra do applet de leitura existe e o binário não — a topbar fica com um slot vazio"
      return "$MEOW_DIVERGENTE"
    fi
    rm -f "$SOMBRA"
    meow_aviso "a sombra estava órfã e foi removida — a topbar volta sem o applet, em vez de com um buraco"
    meow_pendencia_acionavel leitura-applet \
      "O applet do modo de leitura saiu da topbar porque o binário faltava, e precisa ser compilado" \
      "meow doctor --consertar"
    return "$MEOW_DIVERGENTE"
  fi

  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

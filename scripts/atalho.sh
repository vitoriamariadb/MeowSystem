#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

APP_ID="com.meowsystem.Painel"
APLICATIVOS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP="$APLICATIVOS/$APP_ID.desktop"
JANELA_ID="chrome-127.0.0.1__-Default"
JANELA="$APLICATIVOS/$JANELA_ID.desktop"
LANCADOR="$HOME/.local/bin/meow-painel"

CONFERIR=0; REVERTER=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --reverter) REVERTER=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$REVERTER" = 0 ] && CONFERIR=1

_texto_lancador() {
  cat <<'FIM'
#!/usr/bin/env bash
# meow-painel — abre o painel de configuração do MeowSystem.
# GERADO por scripts/atalho.sh. Não edite: a próxima passagem do instalador
# reescreve este arquivo. O que ele faz de verdade mora em app/run.sh.
set -uo pipefail
ponteiro="${XDG_STATE_HOME:-$HOME/.local/state}/meowsystem/raiz"
raiz="${MEOW_RAIZ:-}"
[ -n "$raiz" ] || raiz="$(head -n1 "$ponteiro" 2>/dev/null || true)"

if [ -z "$raiz" ] || [ ! -x "$raiz/app/run.sh" ]; then
  onde="${raiz:-(o ponteiro $ponteiro está vazio ou não existe)}"
  # SEM TERMINAL, O AVISO TEM DE IR ATÉ ELA. O `.desktop` é `Terminal=false`
  # desde 02/09/2026, então escrever no stderr aqui seria falar com ninguém —
  # exatamente o "clique que não faz nada" que este lançador existe para evitar.
  # A notificação é a tela; o log é o registro; o stderr fica para quem rodou
  # `meow-painel` na mão.
  msg="Não achei o repositório do MeowSystem em $onde. Se o disco do clone não estiver montado, é isso."
  printf 'meow-painel: %s\n' "$msg" >&2
  printf '  Para apontar à mão:  MEOW_RAIZ=/caminho/do/clone meow-painel\n' >&2
  estado="${XDG_STATE_HOME:-$HOME/.local/state}/meowsystem"
  mkdir -p "$estado" 2>/dev/null &&
    printf '%s meow-painel: %s\n' "$(date -Is)" "$msg" >> "$estado/painel.log" 2>/dev/null
  command -v notify-send >/dev/null 2>&1 &&
    notify-send -a MeowSystem -i preferences-desktop-theme "MeowSystem" "$msg"
  exit 3
fi
exec "$raiz/app/run.sh" "$@"
FIM
}

_texto_desktop() {
  cat <<FIM
[Desktop Entry]
Type=Application
Name=MeowSystem
GenericName=Configuração do tema
Comment=Configurar o tema, os ícones, o papel de parede e os gatos — numa página só
Exec=$LANCADOR
Icon=$APP_ID
Terminal=false
StartupNotify=true
StartupWMClass=$APP_ID
Categories=Settings;DesktopSettings;
Keywords=meow;meowsystem;tema;theme;catppuccin;icones;ícones;gato;papel de parede;wallpaper;cosmic;aparência;
FIM
}

_texto_janela() {
  cat <<FIM
[Desktop Entry]
Type=Application
Name=MeowSystem
Comment=A janela do painel de configuração
Exec=$LANCADOR
Icon=$APP_ID
Terminal=false
NoDisplay=true
StartupWMClass=$JANELA_ID
FIM
}

_confere_arquivo() {
  local alvo="$1" esperado="$2"
  [ -f "$alvo" ] || return 1
  [ "$esperado" = "$(cat "$alvo" 2>/dev/null)" ]
}

_conferir() {
  local faltando=()
  _confere_arquivo "$DESKTOP" "$(_texto_desktop)"   || faltando+=("$APP_ID.desktop")
  _confere_arquivo "$JANELA" "$(_texto_janela)"     || faltando+=("$JANELA_ID.desktop")
  _confere_arquivo "$LANCADOR" "$(_texto_lancador)" || faltando+=("meow-painel")
  if [ -f "$LANCADOR" ] && [ ! -x "$LANCADOR" ]; then faltando+=("meow-painel sem +x"); fi
  if [ ! -f "$RAIZ/app/pagina/index.html" ] || [ ! -f "$RAIZ/app/servidor.py" ]; then
    meow_erro "o atalho existe mas app/ está incompleto neste clone"
    return "$MEOW_ERRO"
  fi

  if [ "${#faltando[@]}" -gt 0 ]; then
    meow_muda "atalho do painel a instalar: ${faltando[*]}"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "atalho \"MeowSystem\" no lançador, abrindo app/run.sh"
  return "$MEOW_OK"
}

_aplicar() {
  local mudou=0 rc

  meow_escrever "$LANCADOR" "$(_texto_lancador)" 755; rc=$?
  case "$rc" in
    0) ;;
    1) mudou=1 ;;
    *) meow_erro "não consegui escrever $LANCADOR"; return "$MEOW_ERRO" ;;
  esac
  if [ -f "$LANCADOR" ] && [ ! -x "$LANCADOR" ]; then chmod 755 "$LANCADOR"; mudou=1; fi

  meow_escrever "$DESKTOP" "$(_texto_desktop)" 644; rc=$?
  case "$rc" in
    0) ;;
    1) mudou=1 ;;
    *) meow_erro "não consegui escrever $DESKTOP"; return "$MEOW_ERRO" ;;
  esac

  meow_escrever "$JANELA" "$(_texto_janela)" 644; rc=$?
  case "$rc" in
    0) ;;
    1) mudou=1 ;;
    *) meow_erro "não consegui escrever $JANELA"; return "$MEOW_ERRO" ;;
  esac

  if [ "$mudou" = 0 ]; then
    meow_ok "atalho \"MeowSystem\" já está no lançador"
    return "$MEOW_OK"
  fi

  meow_lancador_reler

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) meow_aviso "~/.local/bin não está no \$PATH — o atalho funciona, mas 'meow-painel' na mão não" ;;
  esac

  meow_ok "atalho \"MeowSystem\" instalado no lançador"
  meow_info "  abre em: $LANCADOR  ->  $RAIZ/app/run.sh"
  return "$MEOW_DIVERGENTE"
}

_reverter() {
  local n=0
  for arq in "$DESKTOP" "$JANELA" "$LANCADOR"; do
    [ -e "$arq" ] || continue
    if meow_seco; then meow_muda "removeria $arq"; else rm -f "$arq"; fi
    n=$((n+1))
  done
  if [ "$n" = 0 ]; then
    meow_pula "o atalho do painel não estava instalado"
    return "$MEOW_OK"
  fi
  meow_seco || meow_lancador_reler
  meow_seco || meow_ok "atalho do painel removido ($n arquivo(s))"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$REVERTER" = 1 ] && { _reverter; return $?; }
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ABRIR=1
SO_URL=0
SEM_JANELA=0
SERVIDOR="$RAIZ/app/servidor.py"

PAINEIS="$MEOW_ESTADO/paineis"
e_deste_clone() {
  [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null &&
    tr '\0' '\n' < "/proc/$1/cmdline" 2>/dev/null | grep -qxF "$SERVIDOR"
}
paineis_deste_clone() {
  local f pid
  for f in "$PAINEIS"/*.pid "$MEOW_ESTADO/app.pid"; do
    [ -f "$f" ] || continue
    case "$f" in */app.pid) pid="$(cat "$f" 2>/dev/null)" ;; *) pid="$(basename "$f" .pid)" ;; esac
    if e_deste_clone "$pid"; then
      printf '%s %s\n' "$pid" "$f"
    elif ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$f"
    fi
  done
}

_qa_na_casa_real() {
  local dono casa v
  dono="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)"
  [ -n "$dono" ] || return 1
  dono="$(realpath -m -- "$dono")"
  [ -n "${HOME:-}" ] || return 0
  casa="$(realpath -m -- "$HOME")"
  [ "$casa" = "$dono" ] && return 0
  for v in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME \
           MEOW_CONF MEOW_ESTADO MEOW_ICONES_ESCOLHAS MEOW_COSMIC_DIR; do
    [ -n "${!v:-}" ] || continue
    case "$(realpath -m -- "${!v}")/" in
      "$casa"/*) ;;
      "$dono"/*) return 0 ;;
    esac
  done
  return 1
}

case "${1:-}" in
  --sem-abrir)
    if _qa_na_casa_real && [ "${MEOW_QA_HOME_REAL:-0}" != "1" ]; then
      meow_erro "recusado: --sem-abrir com o HOME real ($HOME) — o QA do painel é numa casa de brinquedo"
      meow_info "  suba com HOME=<diretório temporário>; para a casa real de propósito: MEOW_QA_HOME_REAL=1"
      exit 2
    fi
    ABRIR=0; SEM_JANELA=1 ;;
  --porta-so|--porta-só) ABRIR=0; SO_URL=1 ;;
  --parar)
    parados=()
    while read -r pid arq; do
      kill -TERM "$pid" 2>/dev/null && parados+=("$pid")
      rm -f "$arq"
    done < <(paineis_deste_clone)
    if [ "${#parados[@]}" -gt 0 ]; then
      meow_ok "painel encerrado (pid ${parados[*]})"
    else
      meow_pula "não há painel deste clone de pé"
    fi
    exit 0 ;;
  --estado)
    vivos="$(paineis_deste_clone | cut -d' ' -f1 | paste -sd' ' -)"
    if [ -n "$vivos" ]; then
      meow_ok "painel de pé (pid $vivos)"
    else
      meow_pula "painel parado"
    fi
    exit 0 ;;
  ''|--abrir) ;;
  -h|--help)
    cat <<'FIM'

app/run.sh — o painel de configuração visual do MeowSystem

  ./app/run.sh              sobe o backend, abre o navegador e DEVOLVE o terminal
  ./app/run.sh --parar      encerra o painel que ficou de pé
  ./app/run.sh --estado     diz se há painel de pé
  ./app/run.sh --sem-abrir  sobe e imprime a URL, preso ao terminal (para testes)
  ./app/run.sh --porta-so   sobe, imprime a URL e sai (só para conferir)

O backend escuta em 127.0.0.1, numa porta que o kernel escolhe, com um token de
sessão sorteado a cada execução. Nunca é exposto à rede.

No uso normal ele fica SOLTO: o terminal volta para você, e o painel segue de pé
enquanto a janela do navegador estiver aberta — fechou a janela, o servidor sai
sozinho. Com `--sem-abrir` ele fica preso ao terminal e morre com ele: é assim
que os testes o sobem e derrubam.

FIM
    exit 0 ;;
  *) meow_erro "opção desconhecida: $1"; meow_info "veja: ./app/run.sh --help"; exit 2 ;;
esac

if [ "$(id -u)" = "0" ]; then
  meow_erro "com sudo, não: os arquivos de ~/.config ficariam de dono root — nada foi feito."
  meow_info "  o painel roda como o seu usuário, na sua sessão"
  exit 2
fi

meow_tem python3 || {
  meow_erro "o painel precisa do python3, e ele não está aqui"
  meow_info "  sudo apt install python3"
  exit "$MEOW_SEM_DEPENDENCIA"
}

[ -f "$SERVIDOR" ] || { meow_erro "não achei $SERVIDOR"; exit "$MEOW_ERRO"; }

meow_ponte_python || exit "$MEOW_ERRO"

PAINEL_LOG="$MEOW_ESTADO/painel.log"
if [ "$ABRIR" = "1" ] && [ ! -t 1 ]; then
  if [ -f "$PAINEL_LOG" ] && [ "$(stat -c%s "$PAINEL_LOG" 2>/dev/null || echo 0)" -gt 1048576 ]; then
    tail -c 524288 "$PAINEL_LOG" > "$PAINEL_LOG.tmp" 2>/dev/null &&
      mv -f "$PAINEL_LOG.tmp" "$PAINEL_LOG"
  fi
  exec >>"$PAINEL_LOG" 2>&1
  printf '\n===== %s — painel aberto sem terminal =====\n' "$(date -Is)"
fi

TUBO="$(mktemp -u -t meow-app-XXXXXX)"
mkfifo -m 600 "$TUBO" || { meow_erro "não consegui criar o cano em $TUBO"; exit "$MEOW_ERRO"; }

MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$MEOW_ESTADO" MEOW_APP_VIGIA="$ABRIR" \
  MEOW_APP_SEM_JANELA="$SEM_JANELA" python3 "$SERVIDOR" > "$TUBO" &
PID=$!

limpar() {
  local rc=$?
  trap - EXIT INT TERM HUP
  if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
    kill -TERM "$PID" 2>/dev/null
    for _ in 1 2 3 4 5; do
      kill -0 "$PID" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "$PID" 2>/dev/null
  fi
  rm -f "$TUBO"
  exit "$rc"
}
trap limpar EXIT INT TERM HUP

URL=""
if ! read -r -t 15 URL < "$TUBO"; then
  meow_erro "o backend não respondeu em 15 s"
  meow_info "  o erro do servidor saiu logo acima (sem terminal, em $PAINEL_LOG)"
  exit "$MEOW_ERRO"
fi
[ -n "$URL" ] || { meow_erro "o backend subiu sem dizer a URL"; exit "$MEOW_ERRO"; }

meow_titulo "MeowSystem — painel de configuração"
meow_ok "no ar em ${URL%%\?*}"
meow_info "a URL completa carrega o token da sessão; ela vale só enquanto isto estiver de pé"

if [ "$SO_URL" = "1" ]; then
  printf '%s\n' "$URL"
  exit 0
fi

if [ "$ABRIR" = "0" ]; then
  printf '\n    %s\n\n' "$URL"
fi

APP_ID="com.meowsystem.Painel"

_soltar() {
  if [ -n "${MEOW_FD:-}" ]; then
    eval '"$@" >/dev/null 2>&1 {MEOW_FD}>&- &'
  else
    "$@" >/dev/null 2>&1 &
  fi
  disown 2>/dev/null || true
}

_exec_do_desktop() {
  local id="$1" d
  for d in "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
           /usr/local/share/applications /usr/share/applications \
           "$HOME/.local/share/flatpak/exports/share/applications" \
           /var/lib/flatpak/exports/share/applications; do
    [ -f "$d/$id" ] || continue
    grep -m1 '^Exec=' "$d/$id" | cut -d= -f2- | sed 's/ *%[a-zA-Z]//g'
    return 0
  done
  return 1
}

_exec_padrao() {
  local id
  meow_tem xdg-settings || return 1
  id="$(xdg-settings get default-web-browser 2>/dev/null || true)"
  [ -n "$id" ] || return 1
  _exec_do_desktop "$id"
}

_binario_da_linha() {
  local p
  for p in $1; do
    case "$p" in
      env|/usr/bin/env|/bin/env) continue ;;
      *=*) continue ;;
      -*) break ;;
      *) printf '%s\n' "$p"; return 0 ;;
    esac
  done
  return 1
}

_e_chromium() {
  case "${1##*/}" in
    *chrome*|*chromium*|*brave*|*edge*|*vivaldi*|*thorium*) return 0 ;;
  esac
  return 1
}

if [ "$ABRIR" = "1" ]; then
  LINHA=""
  if [ -n "${BROWSER:-}" ] && meow_tem "${BROWSER%% *}"; then
    LINHA="$BROWSER"
  else
    LINHA="$(_exec_padrao || true)"
  fi
  BIN=""
  [ -n "$LINHA" ] && BIN="$(_binario_da_linha "$LINHA" || true)"

  if [ -n "$BIN" ] && meow_tem "$BIN"; then
    eval "CMD=($LINHA)"
    if _e_chromium "$BIN"; then
      _soltar "${CMD[@]}" \
        --user-data-dir="$MEOW_ESTADO/navegador" \
        --no-first-run --no-default-browser-check \
        --app="$URL" --class="$APP_ID"
    else
      _soltar "${CMD[@]}" "$URL"
    fi
  elif meow_tem xdg-open; then
    _soltar xdg-open "$URL"
  else
    meow_aviso "não achei \$BROWSER nem xdg-open — abra você mesma:"
    printf '\n    %s\n\n' "$URL"
  fi
fi

if [ "$ABRIR" = "0" ]; then
  meow_info "Ctrl+C encerra o painel (e qualquer trabalho que estiver correndo)."
  printf '\n'
  wait "$PID"
  exit $?
fi

trap - EXIT INT TERM HUP
rm -f "$TUBO"
disown "$PID" 2>/dev/null || true
mkdir -p "$PAINEIS" 2>/dev/null && printf '%s\n' "$SERVIDOR" > "$PAINEIS/$PID.pid" 2>/dev/null || true

meow_ok "o painel ficou de pé sozinho (pid $PID) — o terminal é seu de novo"
meow_info "fechar a janela do navegador encerra o painel; à mão:  meow abrir --parar"
printf '\n'

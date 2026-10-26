#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA="${ICONES_TEMA:-${NOME_TEMA_ICONES:-MeowSystem-Icons}}"

DIRS=(
  "$HOME/.local/share/applications"
  "$HOME/.local/share/flatpak/exports/share/applications"
  "/var/lib/flatpak/exports/share/applications"
  "${MEOW_APLICATIVOS_SISTEMA:-/usr/share/applications}"
  "/usr/local/share/applications"
)

TROCAR=(
  "input-remapper-gtk:input-remapper"
)

PY_SISTEMA=""
for c in /usr/bin/python3.12 /usr/bin/python3; do
  if [ -x "$c" ] && "$c" -c 'import gi' 2>/dev/null; then PY_SISTEMA="$c"; break; fi
done

_resolve() {
  local nome="$1"
  [ -n "$PY_SISTEMA" ] || return 0
  "$PY_SISTEMA" - "$nome" "$TEMA" <<'PY' 2>/dev/null
import sys, gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gdk
Gtk.init()
disp = Gdk.Display.get_default()
t = Gtk.IconTheme.get_for_display(disp) if disp else Gtk.IconTheme.new()
if disp is None:
    t.set_theme_name(sys.argv[2])
sys.exit(0 if t.has_icon(sys.argv[1]) else 1)
PY
}

_icone_atual() {
  awk '
    /^\[/ { sec = $0 }
    sec == "[Desktop Entry]" && /^Icon=/ { sub(/^Icon=/, ""); print; exit }
  ' "$1"
}

_reescrito() {
  local arq="$1" novo="$2"
  awk -v novo="$novo" '
    /^\[/ { sec = $0 }
    sec == "[Desktop Entry]" && /^Icon=/ { print "Icon=" novo; next }
    { print }
  ' "$arq"
}

_classe() {
  case "$1" in
    "$HOME"/.local/share/flatpak/exports/share/applications) printf 'flatpak' ;;
    "$HOME"/*)                                               printf 'home' ;;
    *)                                                       printf 'sistema' ;;
  esac
}

CONFERIR=0
SEM_SUDO=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --sem-sudo) SEM_SUDO=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--sem-sudo]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

mudou=0
pendente_sudo=0
ausentes=0
falhou=0
sem_icone=0
declare -A DIRS_TOCADOS=()

for linha in "${TROCAR[@]}"; do
  id="${linha%%:*}"
  nome="${linha#*:}"
  [ -n "$id" ] && [ -n "$nome" ] || continue

  achou=0
  for dir in "${DIRS[@]}"; do
    arq="$dir/$id.desktop"
    [ -e "$arq" ] || continue
    achou=1

    atual="$(_icone_atual "$arq")"

    case "$atual" in
      /*) ;;
      *)  continue ;;
    esac

    if ! _resolve "$nome"; then
      meow_aviso "'$nome' ainda não resolve no tema $TEMA — '$id' fica com o caminho absoluto"
      meow_info "  o traço dele entra antes, pela linha de packs/meowsystem/icones/apps-arcticons.map; a próxima passada troca"
      sem_icone=$((sem_icone + 1))
      continue
    fi

    desejado="$(_reescrito "$arq" "$nome")"

    if [ "$CONFERIR" = 1 ]; then
      meow_muda "trocaria o Icon= de $id: '$atual' -> '$nome'"
      mudou=1
      continue
    fi

    case "$(_classe "$dir")" in
      home|flatpak)
        meow_escrever "$arq" "$desejado" 644
        case $? in
          1) mudou=1; DIRS_TOCADOS["$dir"]=1 ;;
          2) meow_erro "não consegui escrever $arq"; falhou=1 ;;
        esac
        ;;
      sistema)
        if [ "$SEM_SUDO" = 1 ]; then
          pendente_sudo=$((pendente_sudo + 1))
          continue
        fi
        if ! meow_desktop_pode "$arq"; then
          pendente_sudo=$((pendente_sudo + 1))
          continue
        fi
        if ! meow_backup_sistema "$arq"; then
          meow_aviso "não consegui guardar cópia de $arq — não vou reescrevê-lo"
          falhou=1; continue
        fi
        tmp="$(mktemp)" || { falhou=1; continue; }
        printf '%s\n' "$desejado" > "$tmp"
        if meow_desktop_escrever "$arq" "$tmp"; then
          mudou=1; DIRS_TOCADOS["$dir"]=1
        else
          pendente_sudo=$((pendente_sudo + 1))
        fi
        rm -f "$tmp"
        ;;
    esac
  done
  [ "$achou" = 0 ] && ausentes=$((ausentes + 1))
done

if [ "$falhou" = 1 ]; then
  meow_erro "algum Icon= não pôde ser reescrito"
  exit "$MEOW_ERRO"
fi

if [ "$pendente_sudo" -gt 0 ]; then
  meow_pula "$pendente_sudo Icon= em /usr/share espera root: entra no próximo «Instalar tudo»"
fi

if [ "$mudou" = 0 ] && [ "$pendente_sudo" = 0 ]; then
  meow_ok "nenhum Icon= de caminho absoluto (${#TROCAR[@]} na lista, $ausentes não instalados, $sem_icone sem ícone no tema)"
  exit "$MEOW_OK"
fi

if [ "$CONFERIR" = 1 ]; then
  exit "$MEOW_DIVERGENTE"
fi

if [ "$mudou" = 1 ]; then
  if meow_tem update-desktop-database; then
    for dir in "${!DIRS_TOCADOS[@]}"; do
      if [ -w "$dir" ]; then
        update-desktop-database "$dir" 2>/dev/null || true
      else
        meow_desktop_banco "$dir"
      fi
    done
  fi
  meow_ok "Icon= de caminho absoluto trocado por nome"
  meow_info "vale no próximo início do lançador"
fi

exit "$MEOW_DIVERGENTE"

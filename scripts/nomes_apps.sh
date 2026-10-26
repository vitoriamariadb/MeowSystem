#!/usr/bin/env bash
set -uo pipefail

MEOW_NOMES_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$MEOW_NOMES_RAIZ/lib/comum.sh"

MEOW_NOMES_MAPA="${MEOW_NOMES_MAPA:-$MEOW_NOMES_RAIZ/assets/apps/apps-nomes.map}"

MEOW_NOMES_DIRS=(
  "$HOME/.local/share/applications"
  "$HOME/.local/share/flatpak/exports/share/applications"
  "/var/lib/flatpak/exports/share/applications"
  "${MEOW_APLICATIVOS_SISTEMA:-/usr/share/applications}"
  "/usr/local/share/applications"
)

meow_nome_do_mapa() {
  local id="$1"
  [ -f "$MEOW_NOMES_MAPA" ] || return 1
  awk -F: -v id="$id" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $1 == id { sub(/^[^:]*:/, ""); print; achou=1; exit }
    END { exit !achou }
  ' "$MEOW_NOMES_MAPA"
}

meow_nome_curto() {
  local id="$1" arq="$2" novo
  [ -f "$arq" ] || return 1
  novo="$(meow_nome_do_mapa "$id")" || { cat "$arq"; return 0; }
  [ -n "$novo" ] || { cat "$arq"; return 0; }

  awk -v novo="$novo" '
    /^\[/ { sec = $0 }
    sec == "[Desktop Entry]" && match($0, /^Name(\[pt(_BR)?\])?=/) {
      print substr($0, RSTART, RLENGTH) novo; next
    }
    { print }
  ' "$arq"
}

# shellcheck disable=SC2317
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  return 0
fi

CONFERIR=0
SEM_SUDO=0
SO_CLASSE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --conferir)   CONFERIR=1 ;;
    --sem-sudo)   SEM_SUDO=1 ;;
    --so-flatpak) SO_CLASSE=flatpak ;;
    --so-sistema) SO_CLASSE=sistema ;;
    ''|--aplicar) ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--sem-sudo|--so-flatpak|--so-sistema]"
       exit "$MEOW_ERRO" ;;
  esac
  shift
done
meow_seco && CONFERIR=1

if [ ! -f "$MEOW_NOMES_MAPA" ]; then
  meow_erro "não achei o mapa de nomes ($MEOW_NOMES_MAPA)"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

_classe() {
  case "$1" in
    "$HOME"/.local/share/flatpak/exports/share/applications) printf 'flatpak' ;;
    "$HOME"/*)                                               printf 'home' ;;
    *)                                                       printf 'sistema' ;;
  esac
}

_guardado_de() {
  local arq="$1"
  printf '%s/.%s.meow-original' "$(dirname "$arq")" "$(basename "$arq")"
}

_fonte_de() {
  local arq="$1" guardado; guardado="$(_guardado_de "$arq")"
  if [ -L "$arq" ]; then printf '%s' "$arq"; return; fi
  if [ -f "$guardado" ]; then printf '%s' "$guardado"; else printf '%s' "$arq"; fi
}

mudou=0
pendente_sudo=0
ausentes=0
falhou=0
declare -A DIRS_TOCADOS=()

PERM_DIR="$HOME/.local/share/applications"
perm_n=0
perm_falhou=0
if [ "$SO_CLASSE" != "sistema" ] && [ -d "$PERM_DIR" ]; then
  while IFS= read -r -d '' arq; do
    modo="$(stat -c %a -- "$arq" 2>/dev/null)"
    if [ "$CONFERIR" = 1 ]; then
      meow_muda "$(basename "$arq") está com permissão $modo — o certo é 644"
      perm_n=$((perm_n + 1))
      continue
    fi
    if chmod 644 -- "$arq" 2>/dev/null; then
      meow_info "$(basename "$arq"): permissão $modo -> 644"
      perm_n=$((perm_n + 1))
    else
      meow_erro "não consegui dar 644 a $arq (permissão $modo)"
      perm_falhou=1
    fi
  done < <(find "$PERM_DIR" -maxdepth 1 -type f -name '*.desktop' ! -perm 644 -print0 2>/dev/null)
fi

LINHAS=()
while IFS= read -r linha; do LINHAS+=("$linha"); done < "$MEOW_NOMES_MAPA"

for linha in "${LINHAS[@]}"; do
  case "$linha" in ''|\#*) continue ;; esac
  id="${linha%%:*}"
  curto="${linha#*:}"
  if [ -z "$id" ] || [ -z "$curto" ]; then continue; fi

  achou=0
  for dir in "${MEOW_NOMES_DIRS[@]}"; do
    arq="$dir/$id.desktop"
    [ -e "$arq" ] || continue
    achou=1

    grep -qE '^NoDisplay=true' "$arq" 2>/dev/null && continue

    classe="$(_classe "$dir")"
    [ -n "$SO_CLASSE" ] && [ "$classe" != "$SO_CLASSE" ] && continue
    fonte="$arq"
    [ "$classe" = "flatpak" ] && fonte="$(_fonte_de "$arq")"

    desejado="$(meow_nome_curto "$id" "$fonte")" || { falhou=1; continue; }

    if [ -f "$arq" ] && [ ! -L "$arq" ] && [ "$desejado" = "$(cat "$arq" 2>/dev/null)" ]; then
      continue
    fi

    if [ "$CONFERIR" = 1 ]; then
      meow_muda "encurtaria $id -> '$curto'"
      mudou=1
      continue
    fi

    case "$classe" in
      home|flatpak)
        if [ "$classe" = "flatpak" ] && [ -L "$arq" ]; then
          guardado="$(_guardado_de "$arq")"
          [ -f "$guardado" ] || cp -L "$arq" "$guardado" 2>/dev/null || true
        fi
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

total="$(grep -cvE '^[[:space:]]*(#|$)' "$MEOW_NOMES_MAPA" 2>/dev/null)"
total="${total:-0}"

if [ "$falhou" = 1 ]; then
  meow_erro "algum nome não pôde ser reescrito"
  exit "$MEOW_ERRO"
fi

if [ "$pendente_sudo" -gt 0 ]; then
  meow_pula "$pendente_sudo nome(s) em /usr/share esperam root: entram no próximo «Instalar tudo»"
fi

if [ "$mudou" = 0 ] && [ "$pendente_sudo" = 0 ] && [ "$perm_n" = 0 ] && [ "$perm_falhou" = 0 ]; then
  meow_ok "nomes do lançador já curtos ($total no mapa, $ausentes não instalados)"
  exit "$MEOW_OK"
fi

if [ "$CONFERIR" = 1 ]; then
  exit "$MEOW_DIVERGENTE"
fi

[ "$perm_n" -gt 0 ] && meow_ok "$perm_n .desktop do home voltaram a 644"

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
  meow_ok "nomes do lançador encurtados"
  meow_lancador_reler
fi

if [ "$perm_falhou" = 1 ]; then
  meow_erro "algum .desktop do home não pôde voltar a 644"
  exit "$MEOW_ERRO"
fi

exit "$MEOW_DIVERGENTE"

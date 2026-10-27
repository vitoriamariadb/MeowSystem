#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

FT_SISTEMA="${FLATPAK_TEMA_SISTEMA:-/usr/share}"
FT_RAIZES_ICONES=("$HOME/.local/share/icons" "$HOME/.icons" "$FT_SISTEMA/icons")
FT_RAIZES_TEMAS=("$HOME/.local/share/themes" "$HOME/.themes" "$FT_SISTEMA/themes")
FT_USUARIO="${FLATPAK_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/flatpak}/overrides/global"
FT_GLOBAL="${FLATPAK_SYSTEM_DIR:-/var/lib/flatpak}/overrides/global"
FT_ANTES="$MEOW_ESTADO/flatpak-tema-antes.tsv"
FT_CHAVES=(ICON_THEME XCURSOR_THEME GTK_THEME)

ACAO="${1:-aplicar}"
ALVO="${2:-tudo}"
case "$ACAO" in
  aplicar|conferir|reverter) ;;
  --conferir) ACAO="conferir" ;;
  -h|--help)
    printf 'uso: %s [aplicar|conferir] [usuario|global] | reverter\n\n' "$(basename "$0")"
    printf '  aplicar   o override do Flatpak do usuário usa o tema do pack no ar\n'
    printf '  conferir  não escreve nada (0 igual · 1 divergente · 3 falta a ponte root)\n'
    printf '  reverter  devolve o override de antes\n\n'
    printf 'conf: CURSOR, NOME_TEMA_ICONES\n'
    exit 0 ;;
  *) meow_erro "uso: flatpak_tema.sh [aplicar|conferir] [usuario|global] | reverter"; exit "$MEOW_ERRO" ;;
esac
case "$ALVO" in tudo|usuario|global) ;; *) meow_erro "alvo desconhecido: $ALVO"; exit "$MEOW_ERRO" ;; esac
# shellcheck disable=SC2034
[ "$ACAO" = "conferir" ] && MEOW_SECO=1

_ft_env() {
  [ -f "$1" ] || return 0
  awk -v k="$2" '/^\[/ { g = $0; next }
                 g == "[Environment]" && index($0, k "=") == 1 { print substr($0, length(k) + 2); exit }' "$1"
}
_ft_fs() {
  [ -f "$1" ] || return 0
  awk '/^\[/ { g = $0; next }
       g == "[Context]" && index($0, "filesystems=") == 1 { print substr($0, 13); exit }' "$1" | tr ';' '\n' | sed '/^$/d'
}
_ft_fs_tem() {
  local base="${2%:ro}"
  _ft_fs "$1" | grep -qxF -e "$2" -e "$base" -e "$base:rw"
}

_ft_raiz_de() {
  local nome="$1" r; shift
  for r in "$@"; do [ -d "$r/$nome" ] && { printf '%s' "$r"; return 0; }; done
  return 1
}
_ft_entrada_fs() {
  case "$1" in
    "$HOME/.local/share/icons")  printf 'xdg-data/icons:ro' ;;
    "$HOME/.local/share/themes") printf 'xdg-data/themes:ro' ;;
    "$HOME"/*)                   printf '~/%s:ro' "${1#"$HOME"/}" ;;
    *)                           printf '%s:ro' "$1" ;;
  esac
}
_ft_gsettings() {
  meow_tem gsettings || return 1
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then DCONF_PROFILE=/dev/null gsettings "$@"; else gsettings "$@"; fi
}

declare -A DESEJO=()
DESEJO_FS=()
_ft_somar_fs() {
  local entrada; entrada="$(_ft_entrada_fs "$1")"
  case " ${DESEJO_FS[*]:-} " in *" $entrada "*) ;; *) DESEJO_FS+=("$entrada") ;; esac
}
_ft_querer() {
  local nome raiz
  DESEJO=(); DESEJO_FS=()
  nome="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
  if raiz="$(_ft_raiz_de "$nome" "${FT_RAIZES_ICONES[@]}")"; then
    DESEJO[ICON_THEME]="$nome"; _ft_somar_fs "$raiz"
  fi
  if [ -n "${CURSOR:-}" ]; then
    nome="$CURSOR"
    _ft_raiz_de "$nome" "${FT_RAIZES_ICONES[@]}" >/dev/null || nome="$CURSOR-cursors"
    for raiz in "${FT_RAIZES_ICONES[@]}"; do
      [ -d "$raiz/$nome/cursors" ] || continue
      DESEJO[XCURSOR_THEME]="$nome"; _ft_somar_fs "$raiz"; break
    done
  fi
  nome="$(_ft_gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")"
  if [ -n "$nome" ]; then
    for raiz in "${FT_RAIZES_TEMAS[@]}"; do
      [ -d "$raiz/$nome/gtk-3.0" ] || continue
      DESEJO[GTK_THEME]="$nome"; _ft_somar_fs "$raiz"; break
    done
  fi
}

FALTA_ENV=(); FALTA_FS=()
_ft_o_que_falta() {
  local k e
  FALTA_ENV=(); FALTA_FS=()
  for k in "${FT_CHAVES[@]}"; do
    [ -n "${DESEJO[$k]:-}" ] || continue
    [ "$(_ft_env "$FT_USUARIO" "$k")" = "${DESEJO[$k]}" ] || FALTA_ENV+=("$k=${DESEJO[$k]}")
  done
  for e in ${DESEJO_FS[@]+"${DESEJO_FS[@]}"}; do
    _ft_fs_tem "$FT_USUARIO" "$e" || FALTA_FS+=("$e")
  done
}

_ft_guardar_antes() {
  local texto="" k par e antes
  [ -f "$FT_ANTES" ] && texto="$(cat "$FT_ANTES")"
  for par in ${FALTA_ENV[@]+"${FALTA_ENV[@]}"}; do
    k="${par%%=*}"
    awk -F'\t' -v k="$k" '$1 == "env" && $2 == k { f = 1 } END { exit !f }' <<< "$texto" && continue
    antes="$(_ft_env "$FT_USUARIO" "$k")"
    texto+="${texto:+$'\n'}env"$'\t'"$k"$'\t'"${antes:--}"
  done
  for e in ${FALTA_FS[@]+"${FALTA_FS[@]}"}; do
    awk -F'\t' -v e="$e" '$1 == "fs" && $2 == e { f = 1 } END { exit !f }' <<< "$texto" && continue
    texto+="${texto:+$'\n'}fs"$'\t'"$e"
  done
  meow_escrever "$FT_ANTES" "$texto" 644 >/dev/null
}

cmd_usuario() {
  local modo="$1" par args=() e vestido=""
  meow_tem flatpak || { meow_pula "sem flatpak — nenhum app a aplicar"; return "$MEOW_OK"; }
  _ft_querer
  if [ "${#DESEJO[@]}" -eq 0 ]; then
    meow_pula "nenhum tema do MeowSystem no disco ainda — o override do Flatpak fica como está"
    return "$MEOW_OK"
  fi
  _ft_o_que_falta
  if [ "${#FALTA_ENV[@]}" -eq 0 ] && [ "${#FALTA_FS[@]}" -eq 0 ]; then
    for par in "${FT_CHAVES[@]}"; do [ -n "${DESEJO[$par]:-}" ] && vestido+="${vestido:+, }${DESEJO[$par]}"; done
    meow_ok "apps Flatpak usam $vestido"
    return "$MEOW_OK"
  fi
  if [ "$modo" = "conferir" ] || meow_seco; then
    meow_muda "o override do Flatpak do usuário mudaria: ${FALTA_ENV[*]} ${FALTA_FS[*]}"
    return "$MEOW_DIVERGENTE"
  fi
  _ft_guardar_antes
  meow_guardar_antes "$FT_USUARIO"
  for par in ${FALTA_ENV[@]+"${FALTA_ENV[@]}"}; do args+=("--env=$par"); done
  for e in ${FALTA_FS[@]+"${FALTA_FS[@]}"}; do args+=("--filesystem=$e"); done
  if ! flatpak override --user "${args[@]}" >/dev/null 2>&1; then
    meow_erro "o flatpak recusou o override do usuário"
    return "$MEOW_ERRO"
  fi
  _ft_o_que_falta
  if [ "${#FALTA_ENV[@]}" -gt 0 ] || [ "${#FALTA_FS[@]}" -gt 0 ]; then
    meow_erro "o override do Flatpak foi gravado e não confere: ${FALTA_ENV[*]} ${FALTA_FS[*]}"
    return "$MEOW_ERRO"
  fi
  meow_muda "apps Flatpak usam o tema do pack: ${args[*]#--}"
  meow_registrar "flatpak_tema.sh override do usuário ${args[*]}"
  return "$MEOW_DIVERGENTE"
}

_ft_global_velhos() {
  local k v
  [ -f "$FT_GLOBAL" ] || return 0
  for k in "${FT_CHAVES[@]}"; do
    v="$(_ft_env "$FT_GLOBAL" "$k")"
    [ -n "$v" ] || continue
    if [ "$k" = "GTK_THEME" ]; then
      _ft_raiz_de "$v" "${FT_RAIZES_TEMAS[@]}" >/dev/null || printf '%s=%s\n' "$k" "$v"
    else
      _ft_raiz_de "$v" "${FT_RAIZES_ICONES[@]}" >/dev/null || printf '%s=%s\n' "$k" "$v"
    fi
  done
}

cmd_global() {
  local modo="$1" velhos
  meow_tem flatpak || { meow_pula "sem flatpak — nenhum app a aplicar"; return "$MEOW_OK"; }
  velhos="$(_ft_global_velhos)"
  if [ -z "$velhos" ]; then
    meow_pendencia_resolvida flatpak-global-sistema
    meow_ok "o override global do Flatpak não aponta para tema que falta"
    return "$MEOW_OK"
  fi
  velhos="$(printf '%s' "$velhos" | tr '\n' ' ' | sed 's/ $//')"
  if [ "$modo" = "conferir" ] || meow_seco; then
    meow_muda "o override global do Flatpak aponta para tema que não existe: $velhos"
    return "$MEOW_DIVERGENTE"
  fi
  if ! meow_ponte_viva; then
    meow_pendencia_acionavel flatpak-global-sistema \
      "O override global do Flatpak aponta para tema que não existe ($velhos) e só a ponte root o limpa" "./install.sh"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _ft_global_velhos | meow_ponte flatpak-global-limpar >/dev/null 2>&1; then
    meow_erro "a ponte root não limpou o override global do Flatpak"
    return "$MEOW_ERRO"
  fi
  meow_pendencia_resolvida flatpak-global-sistema
  meow_muda "override global do Flatpak limpo de: $velhos"
  meow_registrar "flatpak_tema.sh override global limpo: $velhos"
  return "$MEOW_DIVERGENTE"
}

cmd_tudo() {
  local modo="$1" ru=0 rg=0
  case "$ALVO" in usuario|tudo) cmd_usuario "$modo"; ru=$? ;; esac
  case "$ALVO" in global|tudo)  cmd_global "$modo";  rg=$? ;; esac
  [ "$ru" -ge 2 ] && [ "$ru" -ne 3 ] && return "$ru"
  [ "$rg" -ge 2 ] && [ "$rg" -ne 3 ] && return "$rg"
  [ "$ru" = "1" ] || [ "$rg" = "1" ] && return "$MEOW_DIVERGENTE"
  [ "$rg" = "3" ] && return "$MEOW_SEM_DEPENDENCIA"
  return "$ru"
}

cmd_reverter() {
  local mudou
  if [ ! -f "$FT_ANTES" ]; then
    meow_pula "o MeowSystem não mexeu no override do Flatpak — nada a devolver"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "devolveria o override do Flatpak do usuário ao estado de antes"
    return "$MEOW_DIVERGENTE"
  fi
  meow_guardar_antes "$FT_USUARIO"
  mudou="$(python3 -I - "$FT_USUARIO" "$FT_ANTES" <<'PY'
import os, sys
arq, antes = sys.argv[1:3]
chaves, pastas = {}, []
for linha in open(antes, encoding="utf-8").read().splitlines():
    p = linha.split("\t")
    if p[0] == "env" and len(p) >= 3:
        chaves[p[1]] = p[2]
    elif p[0] == "fs" and len(p) >= 2:
        pastas.append(p[1])
if not os.path.exists(arq):
    print("nada"); sys.exit(0)
grupos, atual = [], None
for linha in open(arq, encoding="utf-8").read().splitlines():
    if linha.startswith("["):
        atual = [linha, []]; grupos.append(atual)
    elif atual is not None and linha.strip():
        atual[1].append(linha)
for nome, corpo in grupos:
    novo = []
    for linha in corpo:
        k, _, v = linha.partition("=")
        if nome == "[Environment]" and k in chaves:
            if chaves[k] != "-":
                novo.append("%s=%s" % (k, chaves[k]))
        elif nome == "[Context]" and k == "filesystems":
            itens = [i for i in v.split(";") if i and i not in pastas]
            if itens:
                novo.append("filesystems=%s;" % ";".join(itens))
        else:
            novo.append(linha)
    corpo[:] = novo
grupos = [g for g in grupos if g[1]]
if not grupos:
    os.remove(arq)
else:
    tmp = arq + ".meow"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(g[0] + "\n" + "\n".join(g[1]) + "\n" for g in grupos))
    os.replace(tmp, arq)
print("devolvido")
PY
)" || { meow_erro "não consegui devolver o override do Flatpak"; return "$MEOW_ERRO"; }
  meow_guardar_antes "$FT_ANTES"
  rm -f "$FT_ANTES"
  meow_ok "override do Flatpak do usuário devolvido ao de antes ($mudou)"
  return "$MEOW_OK"
}

case "$ACAO" in
  aplicar)  cmd_tudo aplicar;  exit $? ;;
  conferir) cmd_tudo conferir; exit $? ;;
  reverter) cmd_reverter;      exit $? ;;
esac

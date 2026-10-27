#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

FT_SISTEMA="${FLATPAK_TEMA_SISTEMA:-/usr/share}"
FT_RAIZES_ICONES=("$HOME/.local/share/icons" "$HOME/.icons" "$FT_SISTEMA/icons")
FT_RAIZES_TEMAS=("$HOME/.local/share/themes" "$HOME/.themes" "$FT_SISTEMA/themes")
FT_APPS_LOCAIS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
FT_DBUS_LOCAL="${XDG_DATA_HOME:-$HOME/.local/share}/dbus-1/services"
FT_RUNTIMES="$MEOW_RAIZ/assets/flatpak/runtimes-gnome.tsv"
FT_MARCA_SERVICO="# corrigir-flatpaks-libadwaita"
FT_TENTOU="$MEOW_ESTADO/flatpak-gtk3-tentou.tsv"
FT_USUARIO="${FLATPAK_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/flatpak}/overrides/global"
FT_GLOBAL="${FLATPAK_SYSTEM_DIR:-/var/lib/flatpak}/overrides/global"
FT_ANTES="$MEOW_ESTADO/flatpak-tema-antes.tsv"
FT_CHAVES=(ICON_THEME XCURSOR_THEME)

ACAO="${1:-aplicar}"
ALVO="${2:-tudo}"
case "$ACAO" in
  aplicar|conferir|reverter) ;;
  --conferir) ACAO="conferir" ;;
  -h|--help)
    printf 'uso: %s [aplicar|conferir] [usuario|libadwaita|icones|runtime|global] | reverter\n\n' "$(basename "$0")"
    printf '  aplicar   o override do Flatpak do usuário usa o tema do pack no ar, sem o que quebra app libadwaita\n'
    printf '  conferir  não escreve nada (0 igual · 1 divergente · 3 falta a ponte root)\n'
    printf '  reverter  devolve o override de antes\n\n'
    printf '  usuario     ícone e cursor do pack, e a extensão do tema GTK3\n'
    printf '  libadwaita  tira GTK_THEME, xdg-config/gtk-4.0 e /usr/share/themes do override\n'
    printf '  icones      tira xdg-data/icons do override, que o Flatpak já monta\n'
    printf '  runtime     app em runtime GNOME antigo abre no runtime validado\n'
    printf '  global      o override do sistema, pela ponte root\n\n'
    printf 'conf: CURSOR, NOME_TEMA_ICONES\n'
    exit 0 ;;
  *) meow_erro "uso: flatpak_tema.sh [aplicar|conferir] [usuario|libadwaita|icones|runtime|global] | reverter"; exit "$MEOW_ERRO" ;;
esac
case "$ALVO" in tudo|usuario|libadwaita|icones|runtime|global) ;; *) meow_erro "alvo desconhecido: $ALVO"; exit "$MEOW_ERRO" ;; esac
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
    "$HOME/.local/share/icons"|"$HOME/.local/share/themes"|"$FT_SISTEMA"/*) ;;
    "$HOME"/*) printf '~/%s:ro' "${1#"$HOME"/}" ;;
    *)         printf '%s:ro' "$1" ;;
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
  [ -n "$entrada" ] || return 0
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
}

FT_APPS_DIR="$(dirname "$FT_USUARIO")"

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

_ft_antes_tem() {
  awk -F'\t' -v t="$1" -v k="$2" '
    function base(x) { sub(/:.*/, "", x); return x }
    t == "env" && $1 == "env" && $2 == k { f = 1 }
    t != "env" && ($1 == "fs" || $1 == "fsx") && base($2) == base(k) { f = 1 }
    END { exit !f }' <<< "$3"
}

_ft_antes_gravar() {
  local texto="" linha t k
  [ -f "$FT_ANTES" ] && texto="$(cat "$FT_ANTES")"
  while IFS= read -r linha; do
    [ -n "$linha" ] || continue
    t="${linha%%$'\t'*}"; k="${linha#*$'\t'}"; k="${k%%$'\t'*}"
    _ft_antes_tem "$t" "$k" "$texto" && continue
    texto+="${texto:+$'\n'}$linha"
  done
  meow_escrever "$FT_ANTES" "$texto" 644 >/dev/null
}

_ft_guardar_antes() {
  local par k e antes
  {
    for par in ${FALTA_ENV[@]+"${FALTA_ENV[@]}"}; do
      k="${par%%=*}"; antes="$(_ft_env "$FT_USUARIO" "$k")"
      printf 'env\t%s\t%s\n' "$k" "${antes:--}"
    done
    for e in ${FALTA_FS[@]+"${FALTA_FS[@]}"}; do printf 'fs\t%s\n' "$e"; done
  } | _ft_antes_gravar
}

_ft_juntar() {
  local rc pior=0 sem=0
  for rc in "$@"; do
    case "$rc" in
      0) ;;
      3) sem=1 ;;
      1) [ "$pior" -ge 2 ] || pior=1 ;;
      *) pior="$rc" ;;
    esac
  done
  [ "$pior" -ne 0 ] && return "$pior"
  [ "$sem" = 1 ] && return "$MEOW_SEM_DEPENDENCIA"
  return "$MEOW_OK"
}

_ft_override_usuario() {
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

_ft_tentou() {
  [ -f "$FT_TENTOU" ] || return 1
  awk -F'\t' -v r="$1" -v d="$(date +%F)" '$1 == r && $2 == d { f = 1 } END { exit !f }' "$FT_TENTOU"
}

cmd_extensao() {
  local modo="$1" tema ref
  meow_tem flatpak || { meow_pula "sem flatpak — nenhuma extensão de tema a conferir"; return "$MEOW_OK"; }
  tema="$(_ft_gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")"
  case "$tema" in
    ''|*[!A-Za-z0-9._-]*) meow_pula "nenhum tema GTK no gsettings — sem extensão de tema a conferir"; return "$MEOW_OK" ;;
  esac
  ref="org.gtk.Gtk3theme.$tema"
  if meow_flatpak_ler info "$ref" >/dev/null 2>&1; then
    meow_ok "apps GTK3 do Flatpak têm a extensão $ref"
    return "$MEOW_OK"
  fi
  if _ft_tentou "$ref"; then
    meow_pula "a extensão $ref não veio do Flathub hoje — tento de novo amanhã"
    return "$MEOW_OK"
  fi
  if [ "$modo" = "conferir" ] || meow_seco; then
    meow_muda "falta a extensão $ref para os apps GTK3 do Flatpak"
    return "$MEOW_DIVERGENTE"
  fi
  if flatpak install --user -y --noninteractive flathub "$ref" >/dev/null 2>&1; then
    meow_muda "extensão $ref instalada para os apps GTK3 do Flatpak"
    meow_registrar "flatpak_tema.sh extensão $ref"
    return "$MEOW_DIVERGENTE"
  fi
  meow_escrever "$FT_TENTOU" "$ref"$'\t'"$(date +%F)" 644 >/dev/null
  meow_pula "a extensão $ref não veio do Flathub — os apps GTK3 ficam com o tema padrão"
  return "$MEOW_OK"
}

cmd_usuario() {
  local ru re
  _ft_override_usuario "$1"; ru=$?
  cmd_extensao "$1"; re=$?
  _ft_juntar "$ru" "$re"
}

_ft_bases_de() {
  case "$1" in
    libadwaita) printf '%s\n' xdg-config/gtk-4.0 /usr/share/themes ;;
    icones)     printf '%s\n' xdg-data/icons ;;
  esac
}

_ft_legado() {
  local classe="$1" v e
  if [ "$classe" = libadwaita ]; then
    v="$(_ft_env "$FT_USUARIO" GTK_THEME)"
    [ -n "$v" ] && printf 'env\tGTK_THEME\t%s\n' "$v"
  fi
  while IFS= read -r e; do
    case "$e" in '!'*) continue ;; esac
    { _ft_bases_de "$classe"; if [ "$classe" = libadwaita ]; then printf '%s\n' "$FT_SISTEMA/themes"; fi; } \
      | grep -qxF -- "${e%%:*}" && printf 'fs\t%s\n' "$e"
  done < <(_ft_fs "$FT_USUARIO")
  return 0
}

_ft_eh_contorno() {
  awk '
    /^[[:space:]]*$/ { next }
    /^\[(Context|Environment)\]$/ { g = $0; next }
    g == "[Environment]" && $0 == "GTK_THEME=" { n++; next }
    g == "[Context]" && index($0, "filesystems=") == 1 {
      m = split(substr($0, 13), it, ";")
      for (i = 1; i <= m; i++)
        if (it[i] != "" && it[i] != "!xdg-config/gtk-4.0" && it[i] != "!xdg-data/icons") ruim = 1
      n++; next
    }
    { ruim = 1 }
    END { exit !(n > 0 && !ruim) }' "$1"
}

_ft_contornos() {
  local arq
  for arq in "$FT_APPS_DIR"/*; do
    [ -f "$arq" ] || continue
    [ "$(basename "$arq")" = global ] && continue
    _ft_eh_contorno "$arq" && printf '%s\n' "$arq"
  done
  return 0
}

_ft_sem() {
  local arq="$1"; shift
  python3 -I - "$arq" "$@" <<'PY'
import sys
arq, *tirar = sys.argv[1:]
chaves = {t[4:] for t in tirar if t.startswith("env:")}
bases = {t[3:] for t in tirar if t.startswith("fs:")}
grupos, atual = [], None
for linha in open(arq, encoding="utf-8").read().splitlines():
    if linha.startswith("["):
        atual = [linha, []]; grupos.append(atual)
    elif atual is not None and linha.strip():
        atual[1].append(linha)
saida = []
for nome, corpo in grupos:
    novo = []
    for linha in corpo:
        k, _, v = linha.partition("=")
        if nome == "[Environment]" and k in chaves:
            continue
        if nome == "[Context]" and k == "filesystems":
            itens = [i for i in v.split(";") if i and i.split(":")[0] not in bases]
            if itens:
                novo.append("filesystems=%s;" % ";".join(itens))
            continue
        novo.append(linha)
    if novo:
        saida.append(nome + "\n" + "\n".join(novo) + "\n")
sys.stdout.write("\n".join(saida))
PY
}

_ft_descrever_legado() {
  local itens="$1" contornos="$2" t k v lista="" arq
  while IFS=$'\t' read -r t k v; do
    [ -n "$t" ] || continue
    if [ "$t" = env ]; then lista+="${lista:+, }$k=$v"; else lista+="${lista:+, }$k"; fi
  done <<< "$itens"
  while IFS= read -r arq; do
    [ -n "$arq" ] || continue
    lista+="${lista:+, }override à parte de $(basename "$arq")"
  done <<< "$contornos"
  printf '%s' "$lista"
}

cmd_legado() {
  local modo="$1" classe="$2" itens contornos lista apps="" args=() t k v arq novo
  meow_tem flatpak || { meow_pula "sem flatpak — nenhum app a consertar"; return "$MEOW_OK"; }
  itens="$(_ft_legado "$classe")"
  contornos=""
  [ "$classe" = libadwaita ] && contornos="$(_ft_contornos)"
  if [ -z "$itens" ] && [ -z "$contornos" ]; then
    case "$classe" in
      libadwaita) meow_ok "o override do Flatpak não tira o estilo dos apps libadwaita" ;;
      icones)     meow_ok "o override do Flatpak não expõe os ícones em dobro" ;;
    esac
    return "$MEOW_OK"
  fi
  lista="$(_ft_descrever_legado "$itens" "$contornos")"
  if [ "$classe" = libadwaita ]; then
    apps="$(meow_flatpak_apps_libadwaita | tr '\n' ' ' | sed 's/ $//; s/ /, /g')"
    apps=" (${apps:-nenhum app libadwaita instalado agora})"
  fi
  if [ "$modo" = "conferir" ] || meow_seco; then
    case "$classe" in
      libadwaita) meow_muda "o override do Flatpak tem $lista e quebra o app libadwaita$apps" ;;
      icones)     meow_muda "o override do Flatpak expõe os ícones em dobro ($lista) e o GTK 4.20 derruba o app" ;;
    esac
    return "$MEOW_DIVERGENTE"
  fi
  if [ -n "$itens" ]; then
    printf '%s\n' "$itens" | awk -F'\t' '$1 == "env" { print } $1 == "fs" { print "fsx\t" $2 }' | _ft_antes_gravar
    while IFS=$'\t' read -r t k v; do
      [ -n "$t" ] || continue
      if [ "$t" = env ]; then args+=("env:$k"); else args+=("fs:${k%%:*}"); fi
    done <<< "$itens"
    novo="$(_ft_sem "$FT_USUARIO" "${args[@]}")" || { meow_erro "não consegui reescrever o override do Flatpak do usuário"; return "$MEOW_ERRO"; }
    if [ -z "$novo" ]; then
      meow_guardar_antes "$FT_USUARIO"
      rm -f -- "$FT_USUARIO" || return "$MEOW_ERRO"
    else
      meow_escrever "$FT_USUARIO" "$novo" 644 >/dev/null
      [ $? = "$MEOW_ERRO" ] && { meow_erro "não consegui gravar o override do Flatpak do usuário"; return "$MEOW_ERRO"; }
    fi
  fi
  while IFS= read -r arq; do
    [ -n "$arq" ] || continue
    meow_guardar_antes "$arq"
    rm -f -- "$arq" || return "$MEOW_ERRO"
  done <<< "$contornos"
  if [ -n "$(_ft_legado "$classe")" ] || { [ "$classe" = libadwaita ] && [ -n "$(_ft_contornos)" ]; }; then
    meow_erro "o override do Flatpak foi reescrito e ainda tem o que quebra o app"
    return "$MEOW_ERRO"
  fi
  meow_muda "override do Flatpak limpo de: $lista"
  meow_registrar "flatpak_tema.sh override do usuário limpo de $lista"
  return "$MEOW_DIVERGENTE"
}

_ft_runtimes_de() {
  [ -f "$FT_RUNTIMES" ] || return 0
  awk -F'\t' -v e="$1" 'NR > 1 && $2 == e { print $1 }' "$FT_RUNTIMES" | sort -n
}

_ft_runtime_minimo() {
  [ -f "$FT_RUNTIMES" ] || return 0
  awk -F'\t' 'NR > 1 && ($2 == "livre" || $2 == "valido") { print $1 }' "$FT_RUNTIMES" | sort -n | head -n 1
}

_ft_runtime_destino() {
  local v
  for v in $(_ft_runtimes_de valido); do
    meow_flatpak_ler info "org.gnome.Platform//$v" >/dev/null 2>&1 && { printf '%s' "$v"; return 0; }
  done
  return 1
}

_ft_flag_runtime() { printf ' --runtime=org.gnome.Platform//[0-9]+'; }

_ft_runtime_soltar() {
  local id="$1" pasta desktop servico expdesk limpo mudou=0
  pasta="$(meow_flatpak_pasta "$id")"
  desktop="$FT_APPS_LOCAIS/$id.desktop"
  servico="$FT_DBUS_LOCAL/$id.service"
  expdesk="$pasta/export/share/applications/$id.desktop"
  if [ -f "$desktop" ] && grep -q -- '--runtime=org.gnome.Platform//' "$desktop"; then
    limpo="$(sed -E "s|$(_ft_flag_runtime)||g" "$desktop")"
    if meow_seco; then
      meow_muda "$id: tiraria o runtime forçado de $desktop"
      mudou=1
    elif [ -f "$expdesk" ] && [ "$limpo" = "$(cat "$expdesk")" ]; then
      meow_guardar_antes "$desktop"
      rm -f -- "$desktop" || return "$MEOW_ERRO"
      mudou=1
    else
      meow_escrever "$desktop" "$limpo" 644 >/dev/null
      [ $? = "$MEOW_ERRO" ] && return "$MEOW_ERRO"
      mudou=1
    fi
  fi
  if [ -f "$servico" ] && grep -qxF "$FT_MARCA_SERVICO" "$servico"; then
    if meow_seco; then
      meow_muda "$id: tiraria o serviço D-Bus $servico"
    else
      meow_guardar_antes "$servico"
      rm -f -- "$servico" || return "$MEOW_ERRO"
    fi
    mudou=1
  fi
  [ "$mudou" = 1 ] || return "$MEOW_OK"
  meow_seco || { meow_muda "$id: o app saiu do runtime antigo, contorno tirado"; _ft_recarregar; }
  return "$MEOW_DIVERGENTE"
}

_ft_recarregar() {
  meow_seco && return 0
  meow_tem update-desktop-database && update-desktop-database "$FT_APPS_LOCAIS" >/dev/null 2>&1
  meow_tem busctl && busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null 2>&1
  return 0
}

_ft_runtime_forcar() {
  local id="$1" alvo="$2" pasta desktop servico expdesk expserv fonte desejado rc mudou=0
  pasta="$(meow_flatpak_pasta "$id")"
  desktop="$FT_APPS_LOCAIS/$id.desktop"
  servico="$FT_DBUS_LOCAL/$id.service"
  expdesk="$pasta/export/share/applications/$id.desktop"
  expserv="$pasta/export/share/dbus-1/services/$id.service"
  fonte="$expdesk"
  [ -f "$desktop" ] && fonte="$desktop"
  if [ -f "$fonte" ]; then
    desejado="$(sed -E "s|$(_ft_flag_runtime)||g" "$fonte" | sed "s|flatpak run |flatpak run --runtime=org.gnome.Platform//$alvo |")"
    meow_escrever "$desktop" "$desejado" 644; rc=$?
    case $rc in 1) mudou=1 ;; 2) meow_erro "$id: não consegui gravar $desktop"; return "$MEOW_ERRO" ;; esac
  fi
  if [ -f "$expserv" ]; then
    if [ -f "$servico" ] && ! grep -qxF "$FT_MARCA_SERVICO" "$servico"; then
      meow_pula "$id: o serviço D-Bus $servico não é do MeowSystem — deixei como está"
    else
      desejado="$(printf '%s\n' "$FT_MARCA_SERVICO"; sed "s|flatpak run |flatpak run --runtime=org.gnome.Platform//$alvo |" "$expserv")"
      meow_escrever "$servico" "$desejado" 644; rc=$?
      case $rc in 1) mudou=1 ;; 2) meow_erro "$id: não consegui gravar $servico"; return "$MEOW_ERRO" ;; esac
    fi
  fi
  [ "$mudou" = 1 ] || return "$MEOW_OK"
  meow_seco && return "$MEOW_DIVERGENTE"
  _ft_recarregar
  meow_muda "$id: abre no runtime GNOME $alvo"
  meow_registrar "flatpak_tema.sh runtime $alvo para $id"
  return "$MEOW_DIVERGENTE"
}

cmd_runtime() {
  local modo="$1" minimo id versao alvo="" destino_instalado="" rc rcs=() antigos=() ref
  meow_tem flatpak || { meow_pula "sem flatpak — nenhum app a conferir"; return "$MEOW_OK"; }
  minimo="$(_ft_runtime_minimo)"
  [ -n "$minimo" ] || { meow_pula "sem a tabela de runtimes GNOME — nada a conferir"; return "$MEOW_OK"; }
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    versao="$(meow_flatpak_runtime_gnome "$id")"
    if [ -n "$versao" ] && [ "$versao" -lt "$minimo" ] && meow_flatpak_usa_libadwaita "$id"; then
      antigos+=("$id:$versao")
    else
      _ft_runtime_soltar "$id"; rcs+=($?)
    fi
  done < <(meow_flatpak_apps)
  if [ "${#antigos[@]}" -eq 0 ]; then
    _ft_juntar ${rcs[@]+"${rcs[@]}"}; rc=$?
    [ "$rc" = 0 ] && meow_ok "nenhum app Flatpak em runtime GNOME antigo"
    return "$rc"
  fi
  alvo="$(_ft_runtime_destino)"
  if [ -z "$alvo" ]; then
    ref="org.gnome.Platform//$(_ft_runtimes_de valido | head -n 1)"
    if [ "$modo" = "conferir" ] || meow_seco; then
      meow_muda "falta o runtime $ref para abrir ${antigos[*]%%:*}"
      return "$MEOW_DIVERGENTE"
    fi
    if ! flatpak install --user -y --noninteractive flathub "$ref" >/dev/null 2>&1; then
      meow_pula "não consegui instalar $ref — ${antigos[*]%%:*} segue sem abrir no COSMIC"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
    meow_muda "runtime $ref instalado"
    rcs+=("$MEOW_DIVERGENTE")
    alvo="$(_ft_runtime_destino)"
    [ -n "$alvo" ] || { meow_erro "instalei $ref e o flatpak não o enxerga"; return "$MEOW_ERRO"; }
  fi
  for id in "${antigos[@]}"; do
    _ft_runtime_forcar "${id%%:*}" "$alvo"; rc=$?
    rcs+=("$rc")
  done
  _ft_juntar "${rcs[@]}"; rc=$?
  [ "$rc" = 0 ] && meow_ok "app Flatpak em runtime GNOME antigo abre no GNOME $alvo: ${antigos[*]%%:*}"
  return "$rc"
}
_ft_global_velhos() {
  local k v e
  [ -f "$FT_GLOBAL" ] || return 0
  for k in "${FT_CHAVES[@]}"; do
    v="$(_ft_env "$FT_GLOBAL" "$k")"
    [ -n "$v" ] || continue
    _ft_raiz_de "$v" "${FT_RAIZES_ICONES[@]}" >/dev/null || printf '%s=%s\n' "$k" "$v"
  done
  v="$(_ft_env "$FT_GLOBAL" GTK_THEME)"
  [ -n "$v" ] && printf 'GTK_THEME=%s\n' "$v"
  while IFS= read -r e; do
    case "$e" in '!'*) continue ;; esac
    { _ft_bases_de libadwaita; _ft_bases_de icones; } | grep -qxF -- "${e%%:*}" && printf 'filesystems=%s\n' "${e%%:*}"
  done < <(_ft_fs "$FT_GLOBAL")
  return 0
}

cmd_global() {
  local modo="$1" velhos
  meow_tem flatpak || { meow_pula "sem flatpak — nenhum app a aplicar"; return "$MEOW_OK"; }
  velhos="$(_ft_global_velhos)"
  if [ -z "$velhos" ]; then
    meow_pendencia_resolvida flatpak-global-sistema
    meow_ok "o override global do Flatpak não aponta para tema que falta nem tira o estilo do libadwaita"
    return "$MEOW_OK"
  fi
  velhos="$(printf '%s' "$velhos" | tr '\n' ' ' | sed 's/ $//')"
  if [ "$modo" = "conferir" ] || meow_seco; then
    meow_muda "o override global do Flatpak tem o que quebra app: $velhos"
    return "$MEOW_DIVERGENTE"
  fi
  if ! meow_ponte_viva; then
    meow_pendencia_acionavel flatpak-global-sistema \
      "O override global do Flatpak tem o que quebra app ($velhos) e só a ponte root o limpa" "./install.sh"
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
  local modo="$1" rcs=()
  case "$ALVO" in usuario|tudo)    cmd_usuario "$modo";             rcs+=($?) ;; esac
  case "$ALVO" in libadwaita|tudo) cmd_legado "$modo" libadwaita;   rcs+=($?) ;; esac
  case "$ALVO" in icones|tudo)     cmd_legado "$modo" icones;       rcs+=($?) ;; esac
  case "$ALVO" in runtime|tudo)    cmd_runtime "$modo";             rcs+=($?) ;; esac
  case "$ALVO" in global|tudo)     cmd_global "$modo";              rcs+=($?) ;; esac
  _ft_juntar "${rcs[@]}"
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
chaves, pastas, voltam = {}, [], []
for linha in open(antes, encoding="utf-8").read().splitlines():
    p = linha.split("\t")
    if p[0] == "env" and len(p) >= 3:
        chaves[p[1]] = p[2]
    elif p[0] == "fs" and len(p) >= 2:
        pastas.append(p[1])
    elif p[0] == "fsx" and len(p) >= 2:
        voltam.append(p[1])
grupos, atual = [], None
if os.path.exists(arq):
    for linha in open(arq, encoding="utf-8").read().splitlines():
        if linha.startswith("["):
            atual = [linha, []]; grupos.append(atual)
        elif atual is not None and linha.strip():
            atual[1].append(linha)


def grupo(nome):
    for g in grupos:
        if g[0] == nome:
            return g
    g = [nome, []]; grupos.append(g)
    return g


vistos = set()
for nome, corpo in grupos:
    novo = []
    for linha in corpo:
        k, _, v = linha.partition("=")
        if nome == "[Environment]" and k in chaves:
            vistos.add(k)
            if chaves[k] != "-":
                novo.append("%s=%s" % (k, chaves[k]))
        elif nome == "[Context]" and k == "filesystems":
            itens = [i for i in v.split(";") if i and i not in pastas]
            for i in voltam:
                if i.split(":")[0] not in [x.split(":")[0] for x in itens]:
                    itens.append(i)
            voltam = []
            if itens:
                novo.append("filesystems=%s;" % ";".join(itens))
        else:
            novo.append(linha)
    corpo[:] = novo
for k, v in chaves.items():
    if k not in vistos and v != "-":
        grupo("[Environment]")[1].append("%s=%s" % (k, v))
if voltam:
    grupo("[Context]")[1].append("filesystems=%s;" % ";".join(voltam))
grupos = [g for g in grupos if g[1]]
if not grupos:
    if os.path.exists(arq):
        os.remove(arq)
else:
    os.makedirs(os.path.dirname(arq), exist_ok=True)
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

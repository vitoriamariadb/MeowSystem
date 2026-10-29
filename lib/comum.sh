#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MEOW_SECO="${MEOW_DRY_RUN:-0}"

MEOW_OK=0; MEOW_DIVERGENTE=1; MEOW_ERRO=2; MEOW_SEM_DEPENDENCIA=3

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  C_MAUVE=$'\033[38;2;203;166;247m'; C_ROSA=$'\033[38;2;245;194;231m'
  C_VERDE=$'\033[38;2;166;227;161m'; C_AMARELO=$'\033[38;2;249;226;175m'
  C_VERM=$'\033[38;2;243;139;168m';  C_AZUL=$'\033[38;2;137;180;250m'
  C_DIM=$'\033[38;2;127;132;156m';   C_FORTE=$'\033[1m'; C_ZERO=$'\033[0m'
else
  C_MAUVE=""; C_ROSA=""; C_VERDE=""; C_AMARELO=""; C_VERM=""; C_AZUL=""
  C_DIM=""; C_FORTE=""; C_ZERO=""
fi

MEOW_LOG_NIVEL="${LOG_NIVEL:-info}"
meow_quieto() { [ "$MEOW_LOG_NIVEL" = "silencioso" ]; }
meow_debug()  { [ "$MEOW_LOG_NIVEL" = "debug" ] && printf '  %s..%s   %s\n' "$C_DIM" "$C_ZERO" "$*"; return 0; }

meow_titulo() { meow_quieto && return 0
                printf '\n%s%s%s\n' "$C_MAUVE$C_FORTE" "$*" "$C_ZERO"; }
meow_passo()  { meow_quieto && return 0
                printf '\n  %s%s%s\n  %s%s%s\n' "$C_MAUVE$C_FORTE" "$*" "$C_ZERO" \
                       "$C_DIM" "$(printf '%.0s─' {1..52})" "$C_ZERO"; }
meow_info()   { meow_quieto && return 0
                printf '  %s>>%s %s\n' "$C_AZUL" "$C_ZERO" "$*"; }
meow_ok()     { meow_quieto && return 0
                printf '  %sok%s   %s\n' "$C_VERDE" "$C_ZERO" "$*"; }
meow_muda()   { printf '  %s~~%s   %s\n' "$C_AMARELO" "$C_ZERO" "$*"; }
meow_pula()   { printf '  %s--%s   %s\n' "$C_DIM" "$C_ZERO" "$*"; }
meow_aviso()  { printf '  %s!!%s   %s\n' "$C_AMARELO" "$C_ZERO" "$*" >&2; }
meow_erro()   { printf '  %serro%s %s\n' "$C_VERM" "$C_ZERO" "$*" >&2; }
meow_seco()   { [ "$MEOW_SECO" = "1" ]; }

MEOW_APP_MOTIVO=""

meow_app_sem() { MEOW_APP_MOTIVO="$*"; return "$MEOW_SEM_DEPENDENCIA"; }

meow_app_pendente() {
  local modulo="${1:-sem nome}"
  if [ -n "$MEOW_APP_MOTIVO" ]; then
    meow_pula "$MEOW_APP_MOTIVO"
  else
    meow_erro "sem motivo declarado — defeito no módulo $modulo"
  fi
  return "$MEOW_SEM_DEPENDENCIA"
}

MEOW_APP_TEMA=""
MEOW_APP_TEMA_PACK=""

meow_app_tema_adicionado() {
  local casa nome
  casa="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/temas-de-apps/$1"
  [ -f "$casa/padrao" ] || return 1
  IFS= read -r nome < "$casa/padrao" || [ -n "$nome" ] || return 1
  case "$nome" in ''|.*|*/*|padrao) return 1 ;; esac
  [ -f "$casa/$nome" ] || return 1
  printf '%s/%s\n' "$casa" "$nome"
}

meow_app_tema_do_pack() {
  local trilha="$1" saida="" achou=0 adicionado
  MEOW_APP_TEMA=""
  MEOW_APP_TEMA_PACK=""
  meow_tem python3 || return 1
  saida="$(FLAVOR="${FLAVOR:-}" python3 "$MEOW_RAIZ/scripts/pack.py" \
             app "$(meow_pack_dir)" "apps.$trilha" 2>/dev/null)" && achou=1
  MEOW_APP_TEMA_PACK="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  MEOW_APP_TEMA="$(printf '%s\n' "$saida" | sed -n 's/^valor=//p')"
  case "$trilha" in
    *.arquivo|*.sha256)
      adicionado="$(meow_app_tema_adicionado "${trilha%%.*}")" || return $((1 - achou))
      [ -n "$MEOW_APP_TEMA_PACK" ] || MEOW_APP_TEMA_PACK="meowsystem"
      if [ "${trilha##*.}" = "arquivo" ]; then
        MEOW_APP_TEMA="$adicionado"
      else
        MEOW_APP_TEMA="$(sha256sum < "$adicionado" | cut -d' ' -f1)"
      fi
      return 0 ;;
  esac
  return $((1 - achou))
}

_meow_temas_mantidos() { printf '%s/temas-mantidos.tsv' "$MEOW_ESTADO"; }

_meow_tema_mantido() {
  local arq no_ar="${2//$'\t'/ }"; arq="$(_meow_temas_mantidos)"
  no_ar="${no_ar//$'\n'/ }"
  [ -f "$arq" ] || return 1
  awk -F'\t' -v a="$1" -v t="$no_ar" '$1 == a && $2 == t { achou = 1 } END { exit !achou }' "$arq"
}

_meow_tema_esquecer() {
  local arq; arq="$(_meow_temas_mantidos)"
  [ -f "$arq" ] || return 0
  awk -F'\t' -v a="$1" '$1 != a' "$arq" > "$arq.tmp" 2>/dev/null && mv -f "$arq.tmp" "$arq" 2>/dev/null
  rm -f "$arq.tmp" 2>/dev/null
  return 0
}

_meow_tema_manter() {
  local app="$1" no_ar="${2//$'\t'/ }"
  no_ar="${no_ar//$'\n'/ }"
  mkdir -p "$MEOW_ESTADO" || return 1
  _meow_tema_mantido "$app" "$no_ar" && return 0
  printf '%s\t%s\n' "$app" "$no_ar" >> "$(_meow_temas_mantidos)"
}

meow_app_tema_no_ar() {
  local app="$1" no_ar="$2" do_pack="$3" de_quem="${4:-$MEOW_APP_TEMA_PACK}" resp=""
  local pode_perguntar="${5:-}"
  local id="$app-tema-de-terceiro" fonte=""
  [ -n "$de_quem" ] && fonte=" (do pack $de_quem)"

  if [ -z "$no_ar" ]; then
    meow_pendencia_resolvida "$id"
    meow_info "$app: está sem tema — aplico o do pack$fonte"
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$no_ar" = "$do_pack" ]; then
    meow_pendencia_resolvida "$id"
    meow_ok "$app: já está no tema do pack$fonte — $no_ar"
    return "$MEOW_OK"
  fi

  local do_painel=""
  [ "$pode_perguntar" = "pergunte" ] && do_painel="${MEOW_TEMA_DE_TERCEIRO:-}"
  if [ -z "$do_painel" ] && _meow_tema_mantido "$app" "$no_ar" \
     && ! { [ "$pode_perguntar" = "pergunte" ] && [ -t 0 ] && [ -t 1 ] && ! meow_seco; }; then
    meow_pendencia_resolvida "$id"
    meow_ok "$app: fica no '$no_ar', como você escolheu («Manter»)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_aviso "$app: está em '$no_ar', que não veio daqui"
  meow_info  "o pack$fonte traz '$do_pack'"

  case "$do_painel" in
    trocar)
      if meow_seco; then
        meow_muda "$app: trocaria pelo tema do pack — é a resposta do painel"
      else
        _meow_tema_esquecer "$app"
        meow_pendencia_resolvida "$id"
        meow_muda "$app: trocando pelo tema do pack — é a resposta do painel"
      fi
      return "$MEOW_DIVERGENTE" ;;
    manter)
      if meow_seco; then
        meow_pula "$app: gravaria que o '$no_ar' fica, e não perguntaria de novo"
      else
        _meow_tema_manter "$app" "$no_ar" || return "$MEOW_ERRO"
        meow_pendencia_resolvida "$id"
        meow_ok "$app: fica no '$no_ar' — não pergunto de novo enquanto ele for o tema"
      fi
      return "$MEOW_SEM_DEPENDENCIA" ;;
  esac

  if meow_seco; then
    meow_pula "perguntaria se troco pelo tema do pack (e não trocaria sozinho)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if [ "$pode_perguntar" = "pergunte" ] && [ -t 0 ] && [ -t 1 ]; then
    printf '  %s??%s   trocar pelo tema do pack? [s/N] ' "$C_AMARELO" "$C_ZERO"
    IFS= read -r -t 30 resp || resp=""
    printf '\n'
    case "$resp" in
      [sS]|[sS][iI][mM])
        meow_pendencia_resolvida "$id"
        meow_muda "$app: trocando pelo tema do pack a seu pedido"
        return "$MEOW_DIVERGENTE" ;;
    esac
  fi

  meow_pendencia_acionavel "$id" \
    "O $app está no tema '$no_ar', que não veio do MeowSystem — deixei como está. Trocar pelo tema do pack ou manter o seu é decisão sua" \
    "meow apps aplicar $app"
  return "$MEOW_SEM_DEPENDENCIA"
}

meow_paleta() {
  if [ -n "${MEOW_PALETA:-}" ] && [ "$MEOW_PALETA" != "${MEOW_PALETA_DA_PONTE:-}" ]; then
    printf '%s' "$MEOW_PALETA"
    return 0
  fi
  local _pack_dir
  _pack_dir="$(meow_pack_dir)"
  if [ -n "$_pack_dir" ] && [ -f "$_pack_dir/paleta.json" ]; then
    printf '%s' "$_pack_dir/paleta.json"
    return 0
  fi
  if [ -n "${PALETA_ARQUIVO:-}" ]; then
    printf '%s' "$MEOW_RAIZ/assets/paleta/$PALETA_ARQUIVO"
    return 0
  fi
  printf '%s' "$(meow_pack_padrao_dir)/paleta.json"
}

meow_pack_raizes() {
  if [ -z "${MEOW_PACK_RAIZES:-}" ]; then
    MEOW_PACK_RAIZES="$(python3 "$MEOW_RAIZ/scripts/pack.py" raizes 2>/dev/null)"
    export MEOW_PACK_RAIZES
  fi
  if [ -z "$MEOW_PACK_RAIZES" ]; then
    [ "${MEOW_PACK_RAIZES_AVISADO:-0}" = "1" ] || {
      MEOW_PACK_RAIZES_AVISADO=1
      meow_aviso "scripts/pack.py não respondeu as raízes — nenhum pack será enxergado"
    }
    return 1
  fi
  printf '%s\n' "$MEOW_PACK_RAIZES"
}

meow_pack_padrao_dir() {
  if [ -z "${MEOW_PACK_PADRAO_DIR:-}" ]; then
    MEOW_PACK_PADRAO_DIR="$(python3 "$MEOW_RAIZ/scripts/pack.py" padrao 2>/dev/null)"
    export MEOW_PACK_PADRAO_DIR
  fi
  if [ -z "$MEOW_PACK_PADRAO_DIR" ]; then
    [ "${MEOW_PACK_PADRAO_AVISADO:-0}" = "1" ] || {
      MEOW_PACK_PADRAO_AVISADO=1
      meow_aviso "scripts/pack.py não disse qual é o pack padrão — a paleta não resolve"
    }
    return 1
  fi
  printf '%s' "$MEOW_PACK_PADRAO_DIR"
}

meow_icones_de_status() {
  local bloco="$1" ref flavor
  ref="$(meow_pack_dir)"
  [ -n "$ref" ] || ref="$(meow_pack_padrao_dir || true)"
  flavor="$(python3 "$MEOW_RAIZ/scripts/pack.py" flavor-icones "$ref" 2>/dev/null)" || flavor=""
  python3 "$MEOW_RAIZ/scripts/pack.py" icones-de-status "$ref" "$bloco" "$flavor" 2>/dev/null
}

meow_pack_dir() {
  local PACK="${PACK:-}" FLAVOR="${FLAVOR:-}" saida recusado
  [ -n "$PACK$FLAVOR" ] || return 0
  saida="$(python3 "$MEOW_RAIZ/scripts/pack.py" adocao "$PACK" "$FLAVOR" 2>/dev/null)" || {
    meow_aviso "scripts/pack.py não disse qual pack adotar (PACK='$PACK', FLAVOR='$FLAVOR') — usando o padrão"
    return 0
  }
  recusado="$(printf '%s\n' "$saida" | sed -n 's/^recusado=//p')"
  [ -n "$recusado" ] && meow_aviso "pack '$recusado' não resolve — usando o padrão"
  printf '%s' "$(printf '%s\n' "$saida" | sed -n 's/^dir=//p')"
  return 0
}

meow_flavor() {
  local padrao
  padrao="$(python3 -I - "$MEOW_RAIZ/scripts" "${PACK:-}" "${FLAVOR:-}" <<'PYFIM' 2>/dev/null
import sys
sys.path.insert(0, sys.argv[1])
import json, os, pack
v = pack.vocabulario(pack.adocao(sys.argv[2], sys.argv[3])[0])
pal = os.environ.get("MEOW_PALETA", "")
if pal == os.environ.get("MEOW_PALETA_DA_PONTE", ""):
    pal = ""
nomes = list(json.load(open(pal, encoding="utf-8"))["flavors"]) if pal else [f["id"] for f in v["flavors"]]
print(sys.argv[3] if sys.argv[3] in nomes else v["flavor_padrao"])
PYFIM
)"
  if [ -z "$padrao" ] && [ -n "${FLAVOR:-}" ]; then
    printf '%s' "$FLAVOR"
    return 0
  fi
  if [ -z "$padrao" ]; then
    meow_aviso "scripts/pack.py não respondeu qual é o flavor padrão do pack no ar (PACK='${PACK:-}') — o FLAVOR fica vazio"
    return 1
  fi
  printf '%s' "$padrao"
}

meow_flavor_vestido() {
  local fl
  fl="$(meow_flavor)" || return 1
  case "${MODO:-}" in
    claro|escuro) ;;
    *) printf '%s' "$fl"; return 0 ;;
  esac
  python3 -I - "$MEOW_RAIZ/scripts" "$fl" "$MODO" "$(meow_paleta)" <<'PYFIM' 2>/dev/null || printf '%s' "$fl"
import json, sys
sys.path.insert(0, sys.argv[1])
import derivar_flavor
fl, modo = sys.argv[2], sys.argv[3]
with open(sys.argv[4], encoding="utf-8") as fh:
    paleta = json.load(fh)
claros = [c for c in (paleta.get("claros") or []) if c in (paleta.get("flavors") or {})]
par = derivar_flavor.par_do_outro_lado(fl, paleta) if (modo == "claro") != (fl in claros) else fl
import re
print(par if isinstance(par, str) and re.fullmatch(r"[a-z0-9_]+", par) else fl)
PYFIM
}

meow_pastas_do_molde() {
  case "${ICONES_PASTAS:-}" in cat--?*) ICONES_PASTAS="cat-${FLAVOR:-}-${ICONES_PASTAS#cat--}" ;; esac
}

meow_packs_validos() {
  python3 -I - "$MEOW_RAIZ/scripts" <<'PYFIM' 2>/dev/null
import os, sys
sys.path.insert(0, sys.argv[1])
import pack

vistos, validos = set(), set()
for base in pack.raizes():
    try:
        nomes_da_raiz = os.listdir(base)
    except OSError:
        continue
    for n in nomes_da_raiz:
        if n in vistos or not pack.RE_ID.fullmatch(n) \
           or not os.path.isfile(os.path.join(base, n, "pack.json")):
            continue
        vistos.add(n)
        try:
            pack.validar(n, silencioso=True)
        except Exception:
            continue
        validos.add(n)
for antes, hoje in getattr(pack, "APELIDOS", {}).items():
    if hoje in validos:
        validos.add(antes)
for n in sorted(validos):
    print(n)
PYFIM
}

meow_motivo_do_cargo() {
  local log="$1" lib
  if grep -q 'linker `cc` not found' "$log" 2>/dev/null; then
    printf 'falta o compilador C (pacote build-essential)'
  elif lib="$(grep -o 'The system library `[^`]*`' "$log" 2>/dev/null | head -n1)" && [ -n "$lib" ]; then
    lib="${lib#*\`}"
    printf 'falta a biblioteca %s do sistema (o pacote -dev dela)' "${lib%\`}"
  elif grep -q 'Could not run `"pkg-config"\|pkg-config: not found\|failed to run.*pkg-config' "$log" 2>/dev/null; then
    printf 'falta o pkg-config'
  else
    printf 'o cargo não compilou'
  fi
}

MEOW_DEPS_DOS_APPLETS="/usr/bin/cc|build-essential
/usr/bin/pkg-config|pkg-config
/usr/include/xkbcommon/xkbcommon.h|libxkbcommon-dev
/usr/include/wayland-client.h|libwayland-dev
/usr/include/dbus-1.0/dbus/dbus.h|libdbus-1-dev"

meow_mascote_dir() {
  python3 "$MEOW_RAIZ/scripts/pack.py" mascote "$(meow_pack_dir)" 2>/dev/null \
    || printf '%s' "$MEOW_RAIZ/packs/meowsystem/mascote"
}

meow_pack_arquivo() {
  local no_pack="$1" no_nucleo="${2:-}" dir real
  dir="$(meow_pack_dir)"
  if [ -n "$dir" ] && [ -e "$dir/$no_pack" ] && real="$(meow_dentro "$dir" "$no_pack")"; then
    printf '%s' "$real"
    return 0
  fi
  [ -n "$no_nucleo" ] && [ -e "$MEOW_RAIZ/$no_nucleo" ] && printf '%s' "$MEOW_RAIZ/$no_nucleo"
  return 0
}

meow_dentro() {
  local raiz cheio real
  raiz="$(realpath -e -- "$1" 2>/dev/null)" || return 1
  case "$2" in /*) cheio="$2" ;; *) cheio="$1/$2" ;; esac
  real="$(realpath -e -- "$cheio" 2>/dev/null)" || return 1
  case "$real" in "$raiz"/*) printf '%s' "$real"; return 0 ;; esac
  return 1
}

meow_nome_seguro() {
  case "$1" in ''|.|*..*|*[!A-Za-z0-9._+-]*) return 1 ;; esac
  return 0
}

meow_texto_seguro() {
  python3 -I -c 'import re, sys
t = sys.argv[1].encode("utf-8", "surrogateescape").decode("utf-8", "replace")
sys.stdout.write(re.sub("[\x00-\x1f\x7f-\x9f\ufffd]", "?", t))' "$*"
}

meow_captura() {
  MEOW_PACK_DIR="${MEOW_PACK_DIR:-$(meow_pack_dir)}" \
    python3 "$MEOW_RAIZ/scripts/pack.py" captura "$1" 2>/dev/null
}

meow_capturas() {
  MEOW_PACK_DIR="${MEOW_PACK_DIR:-$(meow_pack_dir)}" \
    python3 "$MEOW_RAIZ/scripts/pack.py" capturas 2>/dev/null
}

meow_paleta_nome() {
  local p; p="$(meow_paleta)"
  printf '%s' "${p#"$MEOW_RAIZ"/}"
}

meow_ponte_python() {
  local paleta pack_dir da_pessoa=0
  local PACK="${PACK:-$(meow_conf_valor PACK || true)}"
  local FLAVOR="${FLAVOR:-$(meow_conf_valor FLAVOR || true)}"
  [ -n "${MEOW_PALETA:-}" ] && [ "$MEOW_PALETA" != "${MEOW_PALETA_DA_PONTE:-}" ] && da_pessoa=1
  meow_pack_raizes >/dev/null || true
  paleta="$(meow_paleta)"
  if [ ! -f "$paleta" ]; then
    meow_erro "a paleta apontada não existe: $paleta"
    if [ "$da_pessoa" = "1" ]; then
      meow_info "  ela veio de MEOW_PALETA — aponte para um arquivo que exista, ou tire a variável."
    else
      meow_info "  ela veio do pack ativo (PACK/FLAVOR do meow.conf) ou do pack padrão."
    fi
    meow_info "  sem ela nenhum gerador em Python tem cor para trabalhar, e parar aqui é"
    meow_info "  mais barato do que descobrir isso etapa por etapa."
    return "$MEOW_ERRO"
  fi
  pack_dir="$(meow_pack_dir)"
  MEOW_PALETA="$paleta"
  MEOW_PACK_DIR="$pack_dir"
  if [ "$da_pessoa" = "1" ]; then MEOW_PALETA_DA_PONTE=""; else MEOW_PALETA_DA_PONTE="$paleta"; fi
  export MEOW_PALETA MEOW_PACK_DIR MEOW_PALETA_DA_PONTE
  return 0
}

meow_cosmic_dir() {
  printf '%s' "${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"
}

meow_cosmic_v() {
  local n
  n="$(ls -1 "${MEOW_COSMIC_SISTEMA:-/usr/share/cosmic}/$1" 2>/dev/null | sed -n 's/^v\([0-9][0-9]*\)$/\1/p' | sort -n | tail -1)"
  printf 'v%s' "${n:-1}"
}

meow_libcosmic_de() {
  local sha="${2##*~}" rev
  [ "${MEOW_SEM_REDE:-0}" = "1" ] && return 1
  rev="$(curl -sfL --max-time 20 "https://raw.githubusercontent.com/pop-os/$1/$sha/Cargo.lock" 2>/dev/null |
    awk '/^name = "libcosmic"$/{f=1} f && /^source = /{sub(/.*#/,""); sub(/"$/,""); print; exit}')"
  [ -n "$rev" ] || return 1
  printf '%s' "$rev"
}

meow_cosmic_comp_disco() {
  local shim="$HOME/.local/bin/cosmic-comp"
  if grep -qs -- MEOW-COSMIC-COMP-SHIM "$shim"; then
    MEOW_SHIM_SO_DIZER=1 bash "$shim" 2>/dev/null && return 0
  fi
  printf '%s\n' /usr/bin/cosmic-comp
}

MEOW_PROIBIDOS_SISTEMA=(/usr/share /usr/local/share /usr/bin /usr/lib)
MEOW_PROIBIDOS_LOCAIS=()
MEOW_EXCECOES_LOCAIS=()
MEOW_VIZINHOS="${MEOW_VIZINHOS:-$HOME/.config/meow/vizinhos.conf}"
if [ -f "$MEOW_VIZINHOS" ]; then
  while IFS= read -r _l || [ -n "$_l" ]; do
    _l="${_l%%#*}"
    _l="${_l%"${_l##*[![:space:]]}"}"
    [ -z "$_l" ] && continue
    case "$_l" in
      '!'*) _l="${_l#!}"; _l="${_l//\$HOME/$HOME}"
            case "$_l" in /*) MEOW_EXCECOES_LOCAIS+=("$(readlink -m -- "$_l")") ;; esac ;;
      *)    MEOW_PROIBIDOS_LOCAIS+=("${_l//\$HOME/$HOME}") ;;
    esac
  done < "$MEOW_VIZINHOS"
  unset _l
fi

meow_destino_permitido() {
  local alvo="$1" real p
  real="$(readlink -m -- "$alvo")"
  for p in "${MEOW_PROIBIDOS_SISTEMA[@]}"; do
    case "$real" in "$p"/*)
      meow_erro "recusado: '$alvo' é território do sistema e do gerenciador de pacotes"
      return 1 ;;
    esac
  done
  for p in ${MEOW_EXCECOES_LOCAIS[@]+"${MEOW_EXCECOES_LOCAIS[@]}"}; do
    [ "$real" = "$p" ] && return 0
  done
  for p in ${MEOW_PROIBIDOS_LOCAIS[@]+"${MEOW_PROIBIDOS_LOCAIS[@]}"}; do
    case "$real" in "$p"|"$p"/*)
      meow_erro "recusado: '$alvo' pertence a outro projeto nesta máquina ($p)"
      return 1 ;;
    esac
  done
  return 0
}

meow_mesmo_conteudo() {
  [ -f "$1" ] && [ -f "$2" ] && [ "$(cat "$1" 2>/dev/null)" = "$(cat "$2" 2>/dev/null)" ]
}

# shellcheck source=restauro.sh
. "$(dirname "${BASH_SOURCE[0]}")/restauro.sh"
# shellcheck source=flatpak.sh
. "$(dirname "${BASH_SOURCE[0]}")/flatpak.sh"

meow_escrever() {
  local destino="$1" conteudo="$2" modo="${3:-644}" tmp dir
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  dir="$(dirname "$destino")"

  if [ -f "$destino" ] && [ "$conteudo" = "$(cat "$destino" 2>/dev/null)" ]; then
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "mudaria $destino"
    return "$MEOW_DIVERGENTE"
  fi
  meow_guardar_antes "$destino"
  mkdir -p "$dir" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$dir" ".atomicwrite.meow.XXXXXX")" || return "$MEOW_ERRO"
  printf '%s' "$conteudo" > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod "$modo" "$tmp"
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  meow_manifesto_registrar "$destino"
  return "$MEOW_DIVERGENTE"
}

MEOW_CONF_ARQUIVO="${MEOW_CONF:-$HOME/.config/meow/meow.conf}"
MEOW_CONF_PADRAO="${MEOW_CONF_PADRAO:-$MEOW_RAIZ/meow.conf.exemplo}"

meow_conf_texto_definir() {
  local texto="$1" chave="$2" valor="$3" novo="" linha resto antes espacos comentario achou=0
  while IFS= read -r linha; do
    if [ "${linha#"$chave"=}" != "$linha" ]; then
      achou=1
      resto="${linha#"$chave"=}"
      if [ "${resto#*#}" != "$resto" ]; then
        antes="${resto%%#*}"
        comentario="#${resto#*#}"
        espacos="${antes##*[![:space:]]}"
        linha="$chave=\"$valor\"$espacos$comentario"
      else
        linha="$chave=\"$valor\""
      fi
    fi
    novo="$novo$linha"$'\n'
  done <<< "$texto"
  novo="${novo%$'\n'}"
  [ "$achou" = "1" ] || novo="$novo"$'\n'"$chave=\"$valor\""
  printf '%s' "$novo"
}

meow_conf_valor() {
  local chave="$1" linha
  [ -f "$MEOW_CONF_ARQUIVO" ] || return 1
  linha="$(sed -n "s/^[[:space:]]*$chave=//p" "$MEOW_CONF_ARQUIVO" | tail -1)"
  [ -n "$linha" ] || return 1
  linha="${linha%%#*}"
  linha="$(printf '%s' "$linha" | tr -d '"'"'"' \t\r')"
  printf '%s' "$linha"
}

meow_conf_diz() {
  local chave="$1" quer="$2" linha
  linha="$(meow_conf_valor "$chave")" || return 1
  [ "$linha" = "$quer" ]
}

meow_conf_definir() {
  local chave="$1" valor="$2" texto novo fim="" nl=$'\n'
  if [ -f "$MEOW_CONF_ARQUIVO" ]; then
    texto="$(cat "$MEOW_CONF_ARQUIVO"; printf x)"
    texto="${texto%x}"
    fim="${texto##*[!$nl]}"
    texto="${texto%"$fim"}"
  else
    texto="$(cat "$MEOW_CONF_PADRAO" 2>/dev/null)" || return "$MEOW_ERRO"
    fim="$nl"
  fi
  novo="$(meow_conf_texto_definir "$texto" "$chave" "$valor")"
  if [ -f "$MEOW_CONF_ARQUIVO" ] && [ "$novo" = "$texto" ]; then
    return "$MEOW_OK"
  fi
  meow_escrever "$MEOW_CONF_ARQUIVO" "$novo$fim" 644
}

MEOW_ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"
MEOW_CACHE="${MEOW_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem}"

meow_estado_com_padrao() {
  local pasta="$1" arquivo="$2" origem="$MEOW_RAIZ/assets/$1" dir="$MEOW_ESTADO/$1"
  [ "$pasta" = "papeis-de-parede" ] && origem="$MEOW_RAIZ/packs/meowsystem/wallpapers"
  local padrao semente
  if [ "${MEOW_ESTADO_SO_LE:-0}" = "1" ] && [ ! -f "$dir/$arquivo" ]; then
    if [ -f "$origem/$arquivo" ]; then printf '%s' "$origem/$arquivo"
    elif [ -f "$origem/$arquivo.padrao" ]; then printf '%s' "$origem/$arquivo.padrao"
    else printf '%s' "$dir/$arquivo"; fi
    return 0
  fi
  if [ ! -d "$dir" ] && ! meow_seco; then
    if mkdir -p "$dir" 2>/dev/null; then
      for padrao in "$origem"/*.padrao; do
        [ -f "$padrao" ] || continue
        semente="${padrao%.padrao}"
        [ -f "$semente" ] || semente="$padrao"
        cp -p -- "$semente" "$dir/$(basename "${padrao%.padrao}")" 2>/dev/null
      done
    fi
  fi
  printf '%s' "$dir/$arquivo"
}

export MEOW_CARIMBO="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
meow_travar() {
  mkdir -p "$MEOW_ESTADO"
  local lock="$MEOW_ESTADO/lock"
  exec {MEOW_FD}>"$lock" || return "$MEOW_ERRO"
  flock -n "$MEOW_FD" && return 0

  local donos="" nomes=""
  if meow_tem fuser; then
    donos="$(fuser "$lock" 2>/dev/null | tr -s ' ')"
    for p in $donos; do
      [ "$p" = "$$" ] && continue
      [ -r "/proc/$p/comm" ] && nomes="$nomes $(cat "/proc/$p/comm" 2>/dev/null)($p)"
    done
  fi

  if [ -z "$nomes" ]; then
    meow_aviso "outro meow está rodando (lock em $lock) — saindo"
    return "$MEOW_ERRO"
  fi

  case "$nomes" in
    *meow*|*install.sh*|*bash*|*aplicar_*|*construir_*|*icones_*)
      meow_aviso "outro meow está rodando ($nomes) — saindo"
      return "$MEOW_ERRO" ;;
  esac

  meow_erro "o cadeado está preso em:$nomes"
  meow_aviso "isso não é outro meow — é descritor vazado. Um módulo lançou esse"
  meow_aviso "app enquanto a trava estava de pé, e ele levou o cadeado junto."
  meow_aviso "saídas: feche o app acima, ou solte à força com"
  meow_aviso "  flock -u \"$lock\" true  &&  rm -f \"$lock\""
  return "$MEOW_ERRO"
}

meow_backup_sistema() {
  local arq="$1"
  local dir="$MEOW_ESTADO/backups/$MEOW_CARIMBO-sistema"
  local dest="$dir${arq}"
  [ -f "$arq" ] || return 0
  [ -f "$dest" ] && return 0
  mkdir -p "$(dirname "$dest")" 2>/dev/null || return "$MEOW_ERRO"
  cp -a "$arq" "$dest" 2>/dev/null || return "$MEOW_ERRO"
  return 0
}

MEOW_MANIFESTO="$MEOW_ESTADO/manifesto.tsv"
meow_manifesto_registrar() {
  local alvo="$1" sha
  meow_seco && return 0
  [ -f "$alvo" ] || return 0
  sha="$(sha256sum -- "$alvo" 2>/dev/null | cut -d' ' -f1)"
  mkdir -p "$MEOW_ESTADO" || return 0
  if [ -f "$MEOW_MANIFESTO" ]; then
    awk -F'\t' -v a="$alvo" '$1 != a' "$MEOW_MANIFESTO" > "$MEOW_MANIFESTO.tmp" 2>/dev/null \
      && mv -f "$MEOW_MANIFESTO.tmp" "$MEOW_MANIFESTO" 2>/dev/null
    rm -f "$MEOW_MANIFESTO.tmp" 2>/dev/null
  fi
  printf '%s\t%s\t%s\n' "$alvo" "$(date -Iseconds)" "${sha:--}" >> "$MEOW_MANIFESTO"
  return 0
}

meow_registrar() {
  meow_seco && return 0
  mkdir -p "$MEOW_ESTADO"
  printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$MEOW_ESTADO/meow.log"
}

MEOW_PENDENCIAS="$MEOW_ESTADO/pendencias.tsv"

_meow_pendencias_arquivo() { printf '%s/pendencias.tsv' "$MEOW_ESTADO"; }

_meow_pendencia_tirar() {
  local id="$1" arq
  arq="$(_meow_pendencias_arquivo)"
  [ -f "$arq" ] || return 0
  awk -F'\t' -v a="$id" '$1 == a { achou = 1 } END { exit !achou }' "$arq" 2>/dev/null || return 0
  awk -F'\t' -v a="$id" '$1 != a' "$arq" > "$arq.tmp" 2>/dev/null \
    && mv -f "$arq.tmp" "$arq" 2>/dev/null
  rm -f "$arq.tmp" 2>/dev/null
  return 0
}

meow_onde_no_painel() {
  local servidor="$MEOW_RAIZ/app/servidor.py"
  [ -f "$servidor" ] && command -v python3 >/dev/null 2>&1 || return 1
  MEOW_RAIZ="$MEOW_RAIZ" python3 "$servidor" --onde "$1" 2>/dev/null
}

meow_pendencia_acionavel() {
  local id="$1" frase="$2" comando="${3:-}"
  local etapa; etapa="$(basename "${BASH_SOURCE[1]:-desconhecida}")"

  if [ "${MEOW_PENDENCIA_ROTINA:-}" = "1" ]; then meow_pula "$frase"; else meow_aviso "$frase"; fi
  if [ -n "$comando" ]; then
    local onde; onde="$(meow_onde_no_painel "$id")"
    [ -n "$onde" ] && meow_info "resolve: no painel, $onde"
  fi

  meow_seco && return 0
  mkdir -p "$MEOW_ESTADO" || return 0
  frase="${frase//$'\t'/ }"; frase="${frase//$'\n'/ }"
  comando="${comando//$'\t'/ }"; comando="${comando//$'\n'/ }"
  awk -F'\t' -v a="$id" -v e="$etapa" -v f="$frase" -v c="$comando" \
    '$1 == a && $2 == e && $3 == f && $4 == c { achou = 1 } END { exit !achou }' \
    "$(_meow_pendencias_arquivo)" 2>/dev/null && return 0
  _meow_pendencia_tirar "$id"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$id" "$etapa" "$frase" "$comando" "$(date -Iseconds)" >> "$(_meow_pendencias_arquivo)"
  meow_registrar "ficou para depois: $frase"
  return 0
}

meow_pendencia_resolvida() {
  meow_seco && return 0
  _meow_pendencia_tirar "$1"
}

_meow_gente_arquivo() { printf '%s/precisa-de-gente.tsv' "$MEOW_ESTADO"; }

meow_precisa_de_gente() {
  local id="$1" nome="$2" porque="$3" arq desde igual
  meow_seco && return 0
  nome="${nome//$'\t'/ }"; nome="${nome//$'\n'/ }"
  porque="${porque//$'\t'/ }"; porque="${porque//$'\n'/ }"
  arq="$(_meow_gente_arquivo)"
  mkdir -p "$MEOW_ESTADO" || return 0
  desde="$(awk -F'\t' -v a="$id" '$1 == a {print $3; exit}' "$arq" 2>/dev/null)"
  igual="$(awk -F'\t' -v a="$id" -v n="$nome" -v p="$porque" '$1 == a && $2 == n && $4 == p {print "s"; exit}' "$arq" 2>/dev/null)"
  [ "$igual" = "s" ] && return 0
  [ -n "$desde" ] || desde="$(date -Iseconds)"
  { awk -F'\t' -v a="$id" '$1 != a' "$arq" 2>/dev/null
    printf '%s\t%s\t%s\t%s\n' "$id" "$nome" "$desde" "$porque"; } > "$arq.tmp" \
    && mv -f "$arq.tmp" "$arq"
  rm -f "$arq.tmp" 2>/dev/null
  meow_registrar "precisa de gente: $nome ($porque)"
  return 0
}

meow_precisa_de_gente_resolvida() {
  local arq; arq="$(_meow_gente_arquivo)"
  meow_seco && return 0
  [ -f "$arq" ] || return 0
  awk -F'\t' -v a="$1" '$1 == a {achou = 1} END {exit !achou}' "$arq" || return 0
  awk -F'\t' -v a="$1" '$1 != a' "$arq" > "$arq.tmp" && mv -f "$arq.tmp" "$arq"
  rm -f "$arq.tmp" 2>/dev/null
  return 0
}

meow_tem() { command -v "$1" >/dev/null 2>&1; }

meow_garantir_cargo() {
  meow_tem cargo && return 0
  if [ -x "$HOME/.cargo/bin/cargo" ]; then PATH="$HOME/.cargo/bin:$PATH"; return 0; fi
  meow_seco && { meow_muda "instalaria o rust pelo rustup, em ~/.cargo (baixa da internet)"; return 1; }
  meow_tem curl || return 1
  local instalador
  instalador="$(mktemp)" || return 1
  meow_info "instalando o rust pelo rustup, em ~/.cargo (baixa da internet)"
  if curl --proto '=https' --tlsv1.2 -sSf --max-time 120 https://sh.rustup.rs -o "$instalador" \
     && sh "$instalador" -y --profile minimal --no-modify-path >/dev/null 2>&1; then
    rm -f "$instalador"
    PATH="$HOME/.cargo/bin:$PATH"
    meow_tem cargo
    return $?
  fi
  rm -f "$instalador"
  return 1
}

meow_flatpak_tem() {
  local id="$1" base ativo conf
  local -a bases=("${FLATPAK_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/flatpak}"
                  "${FLATPAK_SYSTEM_DIR:-/var/lib/flatpak}")
  for conf in "${FLATPAK_CONFIG_DIR:-/etc/flatpak}"/installations.d/*.conf; do
    [ -f "$conf" ] || continue
    while IFS= read -r base; do
      [ -n "$base" ] && bases+=("$base")
    done < <(sed -n 's/^[[:space:]]*Path[[:space:]]*=[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' "$conf" 2>/dev/null)
  done
  for base in "${bases[@]}"; do
    for ativo in "$base/app/$id"/*/*/active; do
      [ -d "$ativo" ] && return 0
    done
  done
  meow_debug "flatpak '$id' sem implantação em nenhuma instalação (${bases[*]})"
  return 1
}

meow_lancador_reler() {
  meow_seco && return 0
  local matou=0
  local p casa eu="${HOME%/}"
  for alvo in cosmic-launcher cosmic-app-library; do
    for p in $(pgrep -u "$(id -u)" -f "$alvo" 2>/dev/null); do
      casa="$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | sed -n 's/^HOME=//p' | head -n1)"
      [ -n "$casa" ] && [ "${casa%/}" = "$eu" ] || continue
      kill "$p" 2>/dev/null && matou=1
    done
  done
  [ "$matou" = "1" ] && meow_debug "lançador chacoalhado — o cosmic-session repõe em segundos"
  return 0
}

meow_tela_reler() {
  meow_seco && return 0
  local lar rc=0 quem="${MEOW_QUEM_RECICLA:-$(basename "$0")}"
  if [ -n "${MEOW_RELER_NO_FIM:-}" ] && printf '%s\n' "$quem" >> "$MEOW_RELER_NO_FIM" 2>/dev/null; then
    meow_debug "a tela relê uma vez, no fim da passada (pedido de $quem)"
    return 4
  fi
  lar="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)"
  if [ -z "$lar" ] || ! [ "$HOME" -ef "$lar" ]; then
    meow_debug "HOME ($HOME) não é o da conta — a tela não é desta sessão, nada a reler"
    return 3
  fi
  if [ -x "$MEOW_RAIZ/scripts/painel.sh" ] && pgrep -x cosmic-panel >/dev/null 2>&1; then
    if ! MEOW_QUEM_RECICLA="$quem" "$MEOW_RAIZ/scripts/painel.sh" reciclar; then
      meow_aviso "o painel recusou reciclar agora — na dock, o desenho novo aparece no próximo login"
      rc=1
    fi
  fi
  meow_lancador_reler
  return "$rc"
}

meow_tela_reler_no_fim() {
  local marca="${MEOW_RELER_NO_FIM:-}" quem rc=0
  [ -n "$marca" ] || return 0
  unset MEOW_RELER_NO_FIM
  if [ -s "$marca" ]; then
    quem="$(sort -u "$marca" | paste -sd, -)"
    MEOW_QUEM_RECICLA="fim da passada ($quem)" meow_tela_reler; rc=$?
    case "$rc" in
      0) meow_ok "a dock e o menu releram o que mudou ($quem)" ;;
      3) meow_info "fora da sessão gráfica: o que mudou aparece na dock e no menu no próximo login" ;;
    esac
  fi
  rm -f "$marca"
  return "$rc"
}

meow_notificar() {
  meow_seco && return 0
  meow_tem notify-send || return 0
  notify-send -a MeowSystem -i preferences-desktop-theme "$1" "${2:-}" 2>/dev/null || true
}

MEOW_PONTE="${MEOW_PONTE:-/usr/local/lib/meowsystem/ponte_root.sh}"

meow_ponte_viva() {
  [ -x "$MEOW_PONTE" ] || return 1
  local lar
  lar="$(sed -n 's/^lar=//p' "${MEOW_PONTE%/*}/perfil" 2>/dev/null)"
  if [ -n "$lar" ] && [ "$lar" != "${HOME:-}" ]; then
    meow_debug "ponte: \$HOME é '$HOME' e o perfil diz '$lar' — não uso a ponte daqui"
    return 1
  fi
  sudo -n "$MEOW_PONTE" estado >/dev/null 2>&1
}

meow_ponte() {
  meow_ponte_viva || return 127
  sudo -n "$MEOW_PONTE" "$1"
}

meow_desktop_pode() {
  [ -w "$1" ] && return 0
  meow_ponte_viva
}

meow_desktop_escrever() {
  local alvo="$1" fonte="$2" nome
  nome="${alvo##*/}"
  if [ -w "$alvo" ]; then
    install -m 644 "$fonte" "$alvo" 2>/dev/null && return 0
  fi
  if meow_ponte_viva; then
    { printf '%s\n' "$nome"; cat "$fonte"; } | meow_ponte desktop 2>/dev/null && return 0
  fi
  return 127
}

meow_desktop_banco() {
  local dir="${1:-/usr/share/applications}"
  meow_tem update-desktop-database || return 0
  if [ -w "$dir" ]; then
    update-desktop-database "$dir" 2>/dev/null || true
    return 0
  fi
  if [ "$dir" = "/usr/share/applications" ] && meow_ponte_viva; then
    meow_ponte desktop-banco 2>/dev/null && return 0
  fi
  return 0
}

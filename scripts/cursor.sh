#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

CURSOR="${CURSOR:-}"
CURSOR_VERSAO="${CURSOR_VERSAO:-v2.0.0}"

CURSOR_ICONES="$HOME/.local/share/icons"
CURSOR_DEFAULT_DIR="$HOME/.icons/default"
CURSOR_DEFAULT="$CURSOR_DEFAULT_DIR/index.theme"
CURSOR_CHAVE="org.gnome.desktop.interface"

CURSOR_RAIZES=("$CURSOR_ICONES" "$HOME/.icons" "/usr/share/icons")

CURSOR_ADICIONADO=""

_cursor_dir_exato() {
  local raiz
  for raiz in "${CURSOR_RAIZES[@]}"; do
    [ -d "$raiz/$1" ] && { printf '%s/%s' "$raiz" "$1"; return 0; }
  done
  return 1
}
_cursor_dir_tema() {
  local exato; exato="$(_cursor_dir_exato "$1")" && { printf '%s' "$exato"; return; }
  printf '%s/%s-cursors' "$CURSOR_ICONES" "$1"
}
_cursor_nome_tema() {
  _cursor_dir_exato "$1" >/dev/null && { printf '%s' "$1"; return; }
  printf '%s-cursors' "$1"
}
_cursor_url() {
  printf 'https://github.com/catppuccin/cursors/releases/download/%s/%s-cursors.zip' \
         "$CURSOR_VERSAO" "$1"
}

CURSOR_PACK_LIDO=0
CURSOR_PACK_ID=""
CURSOR_PACK_DIR=""
CURSOR_PACK_VALOR=""
CURSOR_PACK_URL=""
CURSOR_PACK_SHA=""
CURSOR_PACK_PASTA=""

_cursor_ler_pack() {
  [ "$CURSOR_PACK_LIDO" = "1" ] && return 0
  CURSOR_PACK_LIDO=1
  meow_tem python3 || return 0
  local saida
  saida="$(python3 "$MEOW_RAIZ/scripts/pack.py" ponteiro "$(meow_pack_dir)")" || return 0
  CURSOR_PACK_ID="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  CURSOR_PACK_DIR="$(printf '%s\n' "$saida" | sed -n 's/^dir=//p')"
  CURSOR_PACK_VALOR="$(printf '%s\n' "$saida" | sed -n 's/^valor=//p')"
  CURSOR_PACK_URL="$(printf '%s\n' "$saida" | sed -n 's/^url=//p')"
  CURSOR_PACK_SHA="$(printf '%s\n' "$saida" | sed -n 's/^sha256=//p')"
  CURSOR_PACK_PASTA="$(printf '%s\n' "$saida" | sed -n 's/^pasta=//p')"
}

_cursor_do_pack() {
  _cursor_ler_pack
  [ -n "$CURSOR_PACK_VALOR" ] && [ -n "$CURSOR_PACK_DIR" ] && [ -d "$CURSOR_PACK_DIR/cursors" ] || return 1
  [ "$1" = "$CURSOR_PACK_VALOR" ] || return 1
  [ "$(_cursor_nome_tema "$1")" = "$1-cursors" ]
}

_cursor_baixavel_do_pack() {
  _cursor_ler_pack
  [ -n "$CURSOR_PACK_URL" ] && [ "$1" = "$CURSOR_PACK_VALOR" ] || return 1
  [ "$(_cursor_nome_tema "$1")" = "$1-cursors" ]
}

_cursor_baixar_do_pack() {
  local valor="$1" tmp alvo real fora obtido f
  for f in curl tar sha256sum realpath; do
    meow_tem "$f" || { meow_erro "falta $f"; return "$MEOW_SEM_DEPENDENCIA"; }
  done
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-cursor-pack.XXXXXX")" || return "$MEOW_ERRO"
  meow_info "baixando o ponteiro '$valor' do pack $CURSOR_PACK_ID…"
  if ! _cursor_curl "$CURSOR_PACK_URL" "$tmp/.pacote"; then
    rm -rf "$tmp"
    meow_erro "não deu para baixar o ponteiro do pack $CURSOR_PACK_ID (sem rede?)"
    meow_aviso "nada foi instalado — o cursor continua exatamente como estava."
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! echo "$CURSOR_PACK_SHA  $tmp/.pacote" | sha256sum --status -c - 2>/dev/null; then
    obtido="$(sha256sum "$tmp/.pacote" | cut -d' ' -f1)"
    rm -rf "$tmp"
    meow_erro "sha256 do ponteiro não bate com o que o pack $CURSOR_PACK_ID pinou"
    meow_info "  esperado $CURSOR_PACK_SHA"
    meow_info "  obtido   $obtido"
    return "$MEOW_ERRO"
  fi
  mkdir "$tmp/.aberto" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  if ! tar -xf "$tmp/.pacote" -C "$tmp/.aberto" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o pacote do ponteiro veio corrompido — nada instalado"; return "$MEOW_ERRO"
  fi
  alvo="$tmp/.aberto/$CURSOR_PACK_PASTA"
  if [ ! -d "$alvo/cursors" ]; then
    rm -rf "$tmp"
    meow_erro "o pacote não tem '$CURSOR_PACK_PASTA/cursors' — o pack $CURSOR_PACK_ID declara a pasta errada?"
    return "$MEOW_ERRO"
  fi
  real="$(realpath -m -- "$alvo")"
  fora="$(find "$real" -type l -print0 | xargs -0 -r realpath -m -- 2>/dev/null \
            | grep -v -e "^$real/" -e "^$real\$" || true)"
  if [ -n "$fora" ]; then
    rm -rf "$tmp"
    meow_erro "o ponteiro do pack $CURSOR_PACK_ID tem link apontando para fora do tema — nada instalado"
    return "$MEOW_ERRO"
  fi
  mv -- "$alvo" "$tmp/$valor" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  _cursor_instalar_pasta "$tmp/$valor"; local rc=$?
  rm -rf "$tmp"
  return "$rc"
}

_cursor_default_texto() {
  printf '[Icon Theme]\nName=Default\nComment=escrito pelo MeowSystem (scripts/cursor.sh)\nInherits=%s\n' \
         "$(_cursor_nome_tema "$1")"
}

_cursor_default_e_nosso() {
  [ -f "$CURSOR_DEFAULT" ] && grep -q 'MeowSystem' "$CURSOR_DEFAULT" 2>/dev/null
}

_cursor_gsettings_ler() {
  if meow_seco && [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    DCONF_PROFILE=/dev/null gsettings "$@"
  else
    gsettings "$@"
  fi
}

_cursor_gsettings_valor() {
  meow_tem gsettings || return 1
  _cursor_gsettings_ler get "$CURSOR_CHAVE" cursor-theme 2>/dev/null | tr -d "'"
}

_cursor_tamanho() {
  meow_tem gsettings || { printf '24'; return; }
  _cursor_gsettings_ler get "$CURSOR_CHAVE" cursor-size 2>/dev/null || printf '24'
}

_cursor_instalado() {
  local nome raiz; nome="$(_cursor_nome_tema "$1")"
  for raiz in "${CURSOR_RAIZES[@]}"; do
    [ -d "$raiz/$nome/cursors" ] && return 0
  done
  return 1
}

_cursor_temas_instalados() (
  local raiz d nome
  shopt -s dotglob
  for raiz in "${CURSOR_RAIZES[@]}"; do
    [ -d "$raiz" ] || continue
    for d in "$raiz"/*; do
      [ -d "$d/cursors" ] || continue
      nome="$(basename -- "$d")"
      _cursor_instalado "${nome%-cursors}" && printf '%s\n' "${nome%-cursors}"
    done
  done | LC_ALL=C sort -u
)

_cursor_curl() {
  curl -sSL --fail --connect-timeout 15 --max-time 300 -o "$2" "$1" 2>/dev/null
}

_cursor_baixar_instalar() {
  local valor="$1" url tmp zip extraido origem destino
  url="$(_cursor_url "$valor")"
  destino="$(_cursor_dir_tema "$valor")"

  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  meow_tem curl  || { meow_erro "falta curl";  return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem unzip || { meow_erro "falta unzip"; return "$MEOW_SEM_DEPENDENCIA"; }

  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-cursor.XXXXXX")" || return "$MEOW_ERRO"
  zip="$tmp/tema.zip"

  if ! _cursor_curl "$url" "$zip"; then
    rm -rf "$tmp"
    meow_erro "não deu para baixar o tema de cursor (sem rede, ou release mudou)"
    meow_aviso "nada foi instalado — o cursor continua exatamente como estava."
    meow_aviso "para fazer à mão, quando houver rede:"
    meow_aviso "  curl -sSL -o /tmp/cursor.zip '$url'"
    meow_aviso "  mkdir -p '$CURSOR_ICONES' && unzip -q /tmp/cursor.zip -d '$CURSOR_ICONES'"
    meow_aviso "  $0 aplicar   # para apontar as chaves depois"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  extraido="$tmp/x"
  if ! unzip -q "$zip" -d "$extraido" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o zip do tema veio corrompido — nada instalado"
    return "$MEOW_ERRO"
  fi

  origem="$extraido/$(_cursor_nome_tema "$valor")"
  if [ ! -d "$origem/cursors" ]; then
    rm -rf "$tmp"
    meow_erro "o pacote não tem '$(_cursor_nome_tema "$valor")/cursors' — nome de tema errado?"
    return "$MEOW_ERRO"
  fi

  mkdir -p "$CURSOR_ICONES" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  rm -rf "$destino"
  if ! mv -f "$origem" "$destino"; then
    rm -rf "$tmp"; meow_erro "falha ao mover o tema para $destino"; return "$MEOW_ERRO"
  fi
  rm -rf "$tmp"

  meow_manifesto_registrar "$destino/index.theme"
  return "$MEOW_OK"
}

_cursor_nome_seguro() {
  local n="$1"
  n="${n//[^A-Za-z0-9._-]/-}"
  n="${n#"${n%%[!.-]*}"}"
  printf '%s' "${n:0:80}"
}

_cursor_nome_do_argumento() {
  local base="$1"
  base="${base%%\?*}"; base="${base%%#*}"
  base="$(basename -- "$base")"
  case "$base" in *.zip|*.ZIP) base="${base%.*}" ;; esac
  base="$(_cursor_nome_seguro "$base")"
  case "$base" in *-cursors) printf '%s' "${base%-cursors}" ;; *) printf '%s' "$base" ;; esac
}

_cursor_instalar_pasta() {
  local origem="$1" nome destino
  nome="$(_cursor_nome_seguro "$(basename -- "$origem")")"
  [ -n "$nome" ] || { meow_erro "nome de tema vazio dentro do pacote"; return "$MEOW_ERRO"; }
  case "$nome" in *-cursors) : ;; *) nome="$nome-cursors" ;; esac
  destino="$CURSOR_ICONES/$nome"

  meow_destino_permitido "$destino" || return "$MEOW_ERRO"

  if [ -d "$destino" ]; then
    if meow_tem diff; then
      if diff -rq --no-dereference -- "$origem" "$destino" >/dev/null 2>&1; then
        meow_ok "'$nome' já está instalado e idêntico"
        CURSOR_ADICIONADO="${nome%-cursors}"
        return "$MEOW_OK"
      fi
      meow_info "'$nome' está no disco e difere do pacote — substituindo"
    else
      meow_ok "'$nome' já está instalado (sem 'diff' para comparar o conteúdo)"
      CURSOR_ADICIONADO="${nome%-cursors}"
      return "$MEOW_OK"
    fi
  fi

  if meow_seco; then
    meow_muda "instalaria o ponteiro '$nome' em $CURSOR_ICONES"
    CURSOR_ADICIONADO="${nome%-cursors}"
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$CURSOR_ICONES" || { meow_erro "não consegui criar $CURSOR_ICONES"; return "$MEOW_ERRO"; }
  local palco
  palco="$(mktemp -d -p "$CURSOR_ICONES" ".meow-cursor.XXXXXX")" || return "$MEOW_ERRO"
  if ! cp -a -- "$origem/." "$palco/"; then
    rm -rf "$palco"; meow_erro "não consegui copiar o tema '$nome'"; return "$MEOW_ERRO"
  fi
  chmod 755 "$palco"
  rm -rf "$destino"
  if ! mv -f "$palco" "$destino"; then
    rm -rf "$palco"; meow_erro "falha ao mover o tema para $destino"; return "$MEOW_ERRO"
  fi

  if [ -f "$destino/index.theme" ]; then
    meow_manifesto_registrar "$destino/index.theme"
  else
    meow_manifesto_registrar "$destino/cursors"
  fi
  meow_muda "ponteiro '$nome' instalado em $destino"
  CURSOR_ADICIONADO="${nome%-cursors}"
  return "$MEOW_DIVERGENTE"
}

_cursor_colher_temas() {
  find "$1" -maxdepth 3 -type d -name cursors -print0 2>/dev/null
}

cmd_adicionar() {
  local alvo="${1:-}"
  if [ -z "$alvo" ]; then
    meow_erro "uso: cursor.sh adicionar <url-ou-zip-ou-pasta>"
    return "$MEOW_ERRO"
  fi

  CURSOR_ADICIONADO=""
  local rc="$MEOW_OK" achou=0

  if [ -d "$alvo" ]; then
    if [ -d "$alvo/cursors" ]; then
      _cursor_instalar_pasta "$alvo"; rc=$?
      [ "$rc" -le 1 ] && achou=1
    else
      local d
      while IFS= read -r -d '' d; do
        _cursor_instalar_pasta "$(dirname -- "$d")"; local e=$?
        [ "$e" -ge 2 ] && return "$e"
        [ "$e" = "1" ] && rc="$MEOW_DIVERGENTE"
        achou=1
      done < <(_cursor_colher_temas "$alvo")
    fi
    [ "$achou" = "1" ] || { meow_erro "não achei nenhum 'cursors/' dentro de '$alvo'"; return "$MEOW_ERRO"; }
    meow_registrar "cursor.sh adicionar '$alvo' -> ${CURSOR_ADICIONADO:-?}"
    _cursor_dizer_como_usar
    return "$rc"
  fi

  if meow_seco; then
    local palpite; palpite="$(_cursor_nome_do_argumento "$alvo")"
    if [ -n "$palpite" ] && _cursor_instalado "$palpite"; then
      meow_ok "'$(_cursor_nome_tema "$palpite")' já está instalado"
      return "$MEOW_OK"
    fi
    meow_muda "instalaria um ponteiro de '$alvo' em $CURSOR_ICONES"
    meow_info "  no seco o nome é palpite pelo arquivo; quem decide é o conteúdo do pacote"
    return "$MEOW_DIVERGENTE"
  fi

  meow_tem unzip || { meow_erro "falta unzip"; return "$MEOW_SEM_DEPENDENCIA"; }

  local tmp zip
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-cursor-add.XXXXXX")" || return "$MEOW_ERRO"
  zip="$tmp/pacote.zip"

  case "$alvo" in
    http://*|https://*)
      meow_tem curl || { rm -rf "$tmp"; meow_erro "falta curl"; return "$MEOW_SEM_DEPENDENCIA"; }
      meow_info "baixando $alvo…"
      if ! _cursor_curl "$alvo" "$zip"; then
        rm -rf "$tmp"
        meow_erro "não deu para baixar '$alvo' (sem rede, endereço errado, ou 404)"
        meow_aviso "nada foi instalado — o cursor continua exatamente como estava."
        return "$MEOW_SEM_DEPENDENCIA"
      fi
      ;;
    *)
      if [ ! -f "$alvo" ]; then
        rm -rf "$tmp"; meow_erro "não achei '$alvo'"; return "$MEOW_ERRO"
      fi
      case "$alvo" in
        *.zip|*.ZIP) : ;;
        *) rm -rf "$tmp"
           meow_erro "só sei abrir .zip aqui (ou uma pasta de tema já aberta)"
           meow_info "  '$alvo' não é nenhum dos dois"
           return "$MEOW_ERRO" ;;
      esac
      cp -- "$alvo" "$zip" || { rm -rf "$tmp"; meow_erro "não consegui ler '$alvo'"; return "$MEOW_ERRO"; }
      ;;
  esac

  local extraido="$tmp/x"
  if ! unzip -q -o "$zip" -d "$extraido" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o zip veio corrompido — nada instalado"; return "$MEOW_ERRO"
  fi

  local d
  while IFS= read -r -d '' d; do
    _cursor_instalar_pasta "$(dirname -- "$d")"; local e=$?
    if [ "$e" -ge 2 ]; then rm -rf "$tmp"; return "$e"; fi
    [ "$e" = "1" ] && rc="$MEOW_DIVERGENTE"
    achou=1
  done < <(_cursor_colher_temas "$extraido")
  rm -rf "$tmp"

  if [ "$achou" = "0" ]; then
    meow_erro "o pacote não tem nenhuma pasta 'cursors/' dentro — não é tema de ponteiro"
    return "$MEOW_ERRO"
  fi

  meow_registrar "cursor.sh adicionar '$alvo' -> ${CURSOR_ADICIONADO:-?}"
  _cursor_dizer_como_usar
  return "$rc"
}

_cursor_dizer_como_usar() {
  [ -n "$CURSOR_ADICIONADO" ] || return 0
  [ "$CURSOR_ADICIONADO" = "$CURSOR" ] && return 0
  meow_info "para usá-lo: CURSOR=\"$CURSOR_ADICIONADO\" no meow.conf, e depois 'meow aplicar'"
}

cmd_aplicar() {
  if [ -z "$CURSOR" ]; then
    meow_pula "CURSOR vazio — o tema de cursor não é tocado"
    return "$MEOW_OK"
  fi
  meow_tem gsettings || { meow_erro "falta gsettings (libglib2.0-bin)"; return "$MEOW_SEM_DEPENDENCIA"; }

  local nome rc=0 mudou=0
  nome="$(_cursor_nome_tema "$CURSOR")"

  if _cursor_do_pack "$CURSOR"; then
    meow_info "o ponteiro '$CURSOR' vem do pack $CURSOR_PACK_ID — sem rede"
    _cursor_instalar_pasta "$CURSOR_PACK_DIR"; rc=$?
    [ "$rc" -ge 2 ] && return "$rc"
    [ "$rc" = "1" ] && mudou=1
    rc=0
  elif _cursor_instalado "$CURSOR"; then
    meow_ok "tema de cursor '$nome' já está instalado"
  elif _cursor_baixavel_do_pack "$CURSOR"; then
    if meow_seco; then
      meow_muda "baixaria o ponteiro '$CURSOR' do pack $CURSOR_PACK_ID (sha256 pinado) e o instalaria em $CURSOR_ICONES"
      mudou=1
    else
      _cursor_baixar_do_pack "$CURSOR"; rc=$?
      [ "$rc" -le 1 ] || return "$rc"
      [ "$rc" = "1" ] && mudou=1
      rc=0
    fi
  else
    if meow_seco; then
      meow_muda "baixaria e instalaria '$nome' em $CURSOR_ICONES"
      mudou=1
    else
      meow_info "baixando '$nome' ($CURSOR_VERSAO)…"
      _cursor_baixar_instalar "$CURSOR"; rc=$?
      [ "$rc" -eq 0 ] || return "$rc"
      meow_muda "tema de cursor instalado em $(_cursor_dir_tema "$CURSOR")"
      mudou=1
    fi
  fi

  local atual; atual="$(_cursor_gsettings_valor)"
  if [ "$atual" = "$nome" ]; then
    meow_ok "gsettings cursor-theme já é '$nome'"
  elif meow_seco; then
    meow_muda "gsettings cursor-theme: '$atual' -> '$nome'"; mudou=1
  else
    if ! gsettings set "$CURSOR_CHAVE" cursor-theme "$nome" 2>/dev/null; then
      meow_erro "gsettings recusou escrever cursor-theme"; return "$MEOW_ERRO"
    fi
    if [ "$(_cursor_gsettings_valor)" = "$nome" ]; then
      meow_muda "gsettings cursor-theme: '$atual' -> '$nome' (apps GTK, já vale)"
      mudou=1
    else
      meow_pula "o gsettings aceitou cursor-theme e não guardou (sem barramento de sessão)"
      meow_info "  o cursor do compositor abaixo não depende disto e continua valendo"
    fi
  fi

  local texto divergente=0; texto="$(_cursor_default_texto "$CURSOR")"
  if [ -f "$CURSOR_DEFAULT" ] && ! _cursor_default_e_nosso; then
    meow_aviso "$CURSOR_DEFAULT existe e NÃO é nosso — não vou sobrescrever."
    meow_aviso "o cursor do desktop continuará o que esse arquivo mandar."
    divergente=1
  else
    meow_escrever "$CURSOR_DEFAULT" "$texto" 644; local e=$?
    case "$e" in
      0) meow_ok "$CURSOR_DEFAULT já apontava para '$nome'" ;;
      1) meow_muda "$CURSOR_DEFAULT -> Inherits=$nome (compositor, no próximo login)"
         mudou=1 ;;
      *) meow_erro "falha ao escrever $CURSOR_DEFAULT"; return "$MEOW_ERRO" ;;
    esac
  fi

  meow_info "tamanho em vigor: $(_cursor_tamanho) (não é imposto por este script)"
  [ "$mudou" = "1" ] && ! meow_seco && \
    meow_info "o cursor do DESKTOP só troca no próximo login; o das janelas GTK já trocou"

  meow_registrar "cursor.sh aplicar tema=$nome mudou=$mudou"
  { [ "$mudou" = "1" ] || [ "$divergente" = "1" ]; } && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

cmd_conferir() {
  [ -z "$CURSOR" ] && { meow_pula "CURSOR vazio — nada a conferir"; return "$MEOW_OK"; }
  meow_tem gsettings || { meow_erro "falta gsettings"; return "$MEOW_SEM_DEPENDENCIA"; }

  local nome rc="$MEOW_OK"
  nome="$(_cursor_nome_tema "$CURSOR")"

  if ! _cursor_instalado "$CURSOR"; then
    meow_muda "tema de cursor '$nome' não está instalado"; rc="$MEOW_DIVERGENTE"
  elif _cursor_do_pack "$CURSOR" && meow_tem diff \
       && ! diff -rq --no-dereference -- "$CURSOR_PACK_DIR" "$CURSOR_ICONES/$nome" >/dev/null 2>&1; then
    meow_muda "tema '$nome' instalado difere do que o pack $CURSOR_PACK_ID traz"
    rc="$MEOW_DIVERGENTE"
  else
    meow_ok "tema '$nome' instalado"
  fi

  local atual; atual="$(_cursor_gsettings_valor)"
  if [ "$atual" = "$nome" ]; then
    meow_ok "gsettings cursor-theme = '$nome'"
  else
    meow_muda "gsettings cursor-theme = '$atual' (esperado '$nome')"; rc="$MEOW_DIVERGENTE"
  fi

  if [ -f "$CURSOR_DEFAULT" ] && grep -q "Inherits=$nome\$" "$CURSOR_DEFAULT" 2>/dev/null; then
    meow_ok "$CURSOR_DEFAULT aponta para '$nome'"
  else
    meow_muda "$CURSOR_DEFAULT não aponta para '$nome' (cursor do desktop divergente)"
    rc="$MEOW_DIVERGENTE"
  fi

  return "$rc"
}

cmd_estado() {
  local gtk desktop=""
  gtk="$(_cursor_gsettings_valor)"
  meow_info "janelas GTK  : '$gtk'   (via gsettings $CURSOR_CHAVE cursor-theme)"

  if [ -f "$CURSOR_DEFAULT" ]; then
    desktop="$(sed -n 's/^Inherits=//p' "$CURSOR_DEFAULT" | head -1)"
    meow_info "desktop      : '$desktop'   (via $CURSOR_DEFAULT)"
    _cursor_default_e_nosso && meow_ok "esse index.theme é do MeowSystem" \
                            || meow_aviso "esse index.theme NÃO é nosso"
  elif [ -f /usr/share/icons/default/index.theme ]; then
    desktop="$(sed -n 's/^Inherits=//p' /usr/share/icons/default/index.theme | head -1)"
    meow_info "desktop      : '$desktop'   (via /usr/share/icons/default/index.theme — o de fábrica)"
    meow_aviso "não há ~/.icons/default: o cursor do desktop é o do sistema, e o"
    meow_aviso "'$gtk' do gsettings NÃO o alcança."
  fi

  [ -n "$gtk" ] && [ -n "$desktop" ] && [ "$gtk" != "$desktop" ] && \
    meow_aviso "as duas metades da tela estão com cursores DIFERENTES"

  meow_info "tamanho: $(_cursor_tamanho)"
  meow_info "XCURSOR_THEME='${XCURSOR_THEME:-}' XCURSOR_SIZE='${XCURSOR_SIZE:-}' (vazio = o compositor usa 'default'/24)"
  return "$MEOW_OK"
}

cmd_listar() {
  { _cursor_temas_instalados
    _cursor_ler_pack
    _cursor_do_pack "$CURSOR_PACK_VALOR" && printf '%s\n' "$CURSOR_PACK_VALOR"
  } | LC_ALL=C sort -u
  return "$MEOW_OK"
}

cmd_remover() {
  if [ -n "${1:-}" ]; then
    _cursor_remover_tema "$1"
    return $?
  fi
  local mudou=0 nome=""
  [ -n "$CURSOR" ] && nome="$(_cursor_nome_tema "$CURSOR")"

  if meow_tem gsettings; then
    local atual; atual="$(_cursor_gsettings_valor)"
    if [ -n "$nome" ] && [ "$atual" != "$nome" ]; then
      meow_pula "gsettings cursor-theme já não é nosso ('$atual')"
    elif meow_seco; then
      meow_muda "faria gsettings reset cursor-theme (voltaria a '$(gsettings get "$CURSOR_CHAVE" cursor-theme 2>/dev/null)')"
      mudou=1
    else
      gsettings reset "$CURSOR_CHAVE" cursor-theme 2>/dev/null
      meow_muda "gsettings cursor-theme devolvido ao padrão ('$(_cursor_gsettings_valor)')"
      mudou=1
    fi
  fi

  if [ -f "$CURSOR_DEFAULT" ]; then
    if _cursor_default_e_nosso; then
      if meow_seco; then
        meow_muda "removeria $CURSOR_DEFAULT"; mudou=1
      else
        rm -f "$CURSOR_DEFAULT"
        rmdir "$CURSOR_DEFAULT_DIR" 2>/dev/null
        meow_muda "$CURSOR_DEFAULT removido (o desktop volta ao de fábrica no próximo login)"
        mudou=1
      fi
    else
      meow_pula "$CURSOR_DEFAULT não é nosso — preservado"
    fi
  fi

  if [ -n "$CURSOR" ]; then
    local dir; dir="$(_cursor_dir_tema "$CURSOR")"
    if [ -d "$dir" ]; then
      if meow_seco; then
        meow_muda "removeria $dir"; mudou=1
      else
        meow_destino_permitido "$dir" && { rm -rf "$dir"; meow_muda "tema removido: $dir"; mudou=1; }
      fi
    fi
  fi

  [ "$mudou" = "0" ] && { meow_pula "nada a remover"; return "$MEOW_OK"; }
  meow_registrar "cursor.sh remover"
  return "$MEOW_DIVERGENTE"
}

_cursor_remover_tema() {
  local valor nome dir
  valor="$(_cursor_nome_seguro "${1%-cursors}")"
  [ -n "$valor" ] || { meow_erro "uso: cursor.sh remover <valor>"; return "$MEOW_ERRO"; }
  nome="$(_cursor_nome_tema "$valor")"
  dir="$CURSOR_ICONES/$nome"

  if [ ! -d "$dir" ]; then
    meow_pula "'$nome' não está em $CURSOR_ICONES — nada a remover"
    return "$MEOW_OK"
  fi
  meow_destino_permitido "$dir" || return "$MEOW_ERRO"

  if meow_seco; then
    meow_muda "removeria $dir"
    return "$MEOW_DIVERGENTE"
  fi
  rm -rf "$dir" || { meow_erro "não consegui remover $dir"; return "$MEOW_ERRO"; }
  meow_muda "ponteiro '$nome' removido de $CURSOR_ICONES"
  [ "$valor" = "$CURSOR" ] && \
    meow_aviso "esse era o tema do CURSOR — o desktop volta ao de fábrica no próximo login"
  meow_registrar "cursor.sh remover $nome"
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)   cmd_aplicar ;;
  conferir)  cmd_conferir ;;
  estado)    cmd_estado ;;
  listar)    cmd_listar ;;
  adicionar) cmd_adicionar "${2:-}" ;;
  remover)   cmd_remover "${2:-}" ;;
  *) meow_erro "uso: cursor.sh {aplicar|conferir|estado|listar|adicionar <url-ou-zip-ou-pasta>|remover [valor]}"
     exit "$MEOW_ERRO" ;;
esac

#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

DOCK="${DOCK:-}"
DK_COMPILAR="${DK_COMPILAR:-sim}"
DK_PACOTE=cosmic-applets
DK_BIN=cosmic-app-list
DK_URL="${DK_URL:-https://github.com/pop-os/cosmic-applets.git}"
DK_REPO="${DK_REPO:-$MEOW_RAIZ/patches}"
DK_SERIE="${DK_SERIE:-$DK_REPO/dock.series}"
DK_VERSOES="${DK_VERSOES:-$DK_REPO/dock.versao}"
DK_CASA="${DK_CASA:-$HOME/.local/libexec/meow/dock}"
DK_SHIM="${DK_SHIM:-$HOME/.local/bin/cosmic-app-list}"
DK_SHIM_FONTE="$MEOW_RAIZ/scripts/dock_shim.sh"
DK_SHIM_MARCA="MEOW-DOCK-SHIM"
DK_FABRICA="${DK_FABRICA:-/usr/bin/cosmic-app-list}"
DK_CACHE="${DK_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/dock}"
DK_FALHAS="${DK_FALHAS:-$MEOW_ESTADO/dock/falhas.tsv}"
DK_TRAVA="${DK_TRAVA:-$MEOW_ESTADO/builds.lock}"
DK_ESPACO_KB="${DK_ESPACO_KB:-6000000}"

DK_CARGO_BIN="${CARGO_HOME:-$HOME/.cargo}/bin"
case ":$PATH:" in
  *":$DK_CARGO_BIN:"*) ;;
  *) [ -d "$DK_CARGO_BIN" ] && PATH="$DK_CARGO_BIN:$PATH" && export PATH ;;
esac

_dk_quer() {
  local q="${DOCK:-}"
  [ -n "$q" ] || q="$(meow_conf_valor DOCK 2>/dev/null)" || q=sim
  [ "${q:-sim}" != nao ]
}

_dk_versao() {
  dpkg-query -W -f='${Package}\t${Version}\t${db:Status-Status}\n' "$DK_PACOTE" 2>/dev/null |
    awk -F'\t' -v p="$DK_PACOTE" '$1 == p && $3 == "installed" && $2 != "" {print $2; exit}'
}

_dk_curto() {
  local c="${1##*~}"
  [[ "$c" =~ ^[0-9a-f]{7,40}$ ]] || return 1
  printf '%s' "$c"
}

_dk_commit() {
  local fixado
  fixado="$(awk -v v="$1" '$1 == v && $2 ~ /^[0-9a-f]+$/ {print $2; exit}' "$DK_VERSOES" 2>/dev/null)"
  [ -n "$fixado" ] && { printf '%s' "$fixado"; return 0; }
  _dk_curto "$1"
}

_dk_validada() { awk -v v="$1" '$1 == v {x = 1} END {exit !x}' "$DK_VERSOES" 2>/dev/null; }

_dk_entradas() {
  local arquivo marca
  [ -f "$DK_SERIE" ] || return 1
  while read -r arquivo marca _; do
    case "$arquivo" in ''|'#'*) continue ;; esac
    [ -n "$marca" ] || continue
    printf '%s\t%s\n' "$arquivo" "$marca"
  done < "$DK_SERIE"
}

_dk_marcadores() { _dk_entradas | cut -f2; }

_dk_digital() {
  local arquivo _m
  {
    cat "$DK_SERIE" 2>/dev/null
    while IFS=$'\t' read -r arquivo _m; do cat "$DK_REPO/$arquivo" 2>/dev/null; done < <(_dk_entradas)
  } | md5sum | cut -c1-32
}

_dk_binario() { printf '%s/%s/%s' "$DK_CASA" "$1" "$DK_BIN"; }

_dk_valido() {
  local bin m
  bin="$(_dk_binario "$1")"
  [ -x "$bin" ] || return 1
  [ -n "$(_dk_marcadores)" ] || return 1
  while IFS= read -r m; do
    [ -n "$m" ] && { grep -a -q -- "$m" "$bin" 2>/dev/null || return 1; }
  done < <(_dk_marcadores)
  [ "$(cat "$DK_CASA/$1/digital" 2>/dev/null)" = "$(_dk_digital)" ]
}

_dk_ruim() { [ -e "$DK_CASA/$1/ruim" ]; }

_dk_caiu() { [ "$(head -c 4 "$DK_CASA/$1/ruim" 2>/dev/null)" = caiu ]; }

_dk_fumaca() { [ -x "$1" ] && ! ldd "$1" 2>/dev/null | grep -q 'not found'; }

_dk_falha() {
  awk -F'\t' -v v="$1" -v d="$(_dk_digital)" '$1 == v && $2 == d {l = $3 "\t" $4 "\t" $5} END {if (l != "") print l}' "$DK_FALHAS" 2>/dev/null
}

_dk_gravar_falha() {
  local ver="$1" tipo="$2" atual n=1 digital
  digital="$(_dk_digital)"
  atual="$(_dk_falha "$ver")"
  [ -z "$atual" ] || n=$(( $(printf '%s' "$atual" | cut -f2) + 1 ))
  meow_seco && return 0
  mkdir -p "${DK_FALHAS%/*}" || return 0
  { awk -F'\t' -v v="$ver" -v d="$digital" '!($1 == v && $2 == d)' "$DK_FALHAS" 2>/dev/null
    printf '%s\t%s\t%s\t%s\t%s\n' "$ver" "$digital" "$tipo" "$n" "$(date +%s)"; } > "$DK_FALHAS.novo" \
    && mv -f "$DK_FALHAS.novo" "$DK_FALHAS"
  [ "$tipo" = recusa ] && meow_registrar "dock.sh: o patch da dock não entra no $ver, e a dock do pacote segue valendo"
  return 0
}

_dk_limpar_falha() {
  meow_seco && return 0
  [ -f "$DK_FALHAS" ] || return 0
  awk -F'\t' -v v="$1" '$1 != v' "$DK_FALHAS" > "$DK_FALHAS.novo" 2>/dev/null && mv -f "$DK_FALHAS.novo" "$DK_FALHAS"
  return 0
}

_dk_espera() {
  local f tipo n quando s
  f="$(_dk_falha "$1")"
  [ -n "$f" ] || return 1
  tipo="$(printf '%s' "$f" | cut -f1)"; n="$(printf '%s' "$f" | cut -f2)"; quando="$(printf '%s' "$f" | cut -f3)"
  [ "$tipo" = recusa ] && return 0
  case "$n$quando" in ''|*[!0-9]*) return 1 ;; esac
  [ "$n" -gt 9 ] && n=9
  s=$(( 3600 << (n - 1) )); [ "$s" -gt 604800 ] && s=604800
  [ "$(date +%s)" -lt $(( quando + s )) ]
}

_dk_situacao() {
  local ver f
  ver="$(_dk_versao)"
  [ -n "$ver" ] || { printf ausente; return; }
  _dk_quer || { printf desligado; return; }
  if _dk_valido "$ver"; then
    if _dk_ruim "$ver"; then printf falhou; else printf ok; fi
    return
  fi
  f="$(_dk_falha "$ver")"
  if [ -n "$f" ]; then
    if [ "$(printf '%s' "$f" | cut -f1)" = recusa ]; then printf nao-encaixa; else printf falhou; fi
    return
  fi
  printf pendente
}

_dk_pendente() {
  local ver
  ver="$(_dk_versao)"
  [ -n "$ver" ] || return 1
  case "$(_dk_situacao)" in
    pendente) ;;
    falhou) _dk_valido "$ver" && return 1; _dk_espera "$ver" && return 1 ;;
    *) return 1 ;;
  esac
  printf '%s\n' "$ver"
}

_dk_shim_nosso() { grep -qs -- "$DK_SHIM_MARCA" "$1"; }

_dk_esperado() {
  MEOW_SHIM_SO_DIZER=1 MEOW_SHIM_CASA="$DK_CASA" MEOW_SHIM_FABRICA="$DK_FABRICA" bash "$DK_SHIM" 2>/dev/null
}

_dk_ligar() {
  local tmp
  cmp -s "$DK_SHIM_FONTE" "$DK_SHIM" 2>/dev/null && return 0
  [ ! -e "$DK_SHIM" ] || _dk_shim_nosso "$DK_SHIM" || { meow_erro "$DK_SHIM existe e não é o shim da dock do meow — não o troco"; return 2; }
  meow_muda "o shim da dock não está em $DK_SHIM"
  meow_seco && return 1
  meow_guardar_antes "$DK_SHIM"
  mkdir -p "${DK_SHIM%/*}" || return 2
  tmp="$(mktemp -p "${DK_SHIM%/*}" .meow-shim.XXXXXX)" || return 2
  cp -f "$DK_SHIM_FONTE" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$DK_SHIM" \
    || { rm -f "$tmp"; meow_erro "não consegui instalar $DK_SHIM"; return 2; }
  meow_manifesto_registrar "$DK_SHIM"
  meow_registrar "dock.sh shim da dock"
  meow_info "a dock troca de binário quando o painel a abre de novo (no próximo login)"
  return 1
}

_dk_tirar() {
  [ -e "$DK_SHIM" ] || return 0
  if ! _dk_shim_nosso "$DK_SHIM"; then
    meow_pula "$DK_SHIM não é do meow — fica"
    return 0
  fi
  meow_muda "o shim da dock sairia ($DK_SHIM)"
  meow_seco && return 1
  meow_guardar_antes "$DK_SHIM"
  rm -f "$DK_SHIM"
  meow_registrar "dock.sh tirou o shim da dock"
  meow_info "a dock volta à do pacote quando o painel a abre de novo (no próximo login)"
  return 1
}

_dk_marcar_caiu() {
  local ver="$1" porque="$2"
  if meow_seco; then meow_muda "poria de lado o build da dock $ver: $porque"; return 1; fi
  printf 'caiu %s\n' "$(date -Is)" > "$DK_CASA/$ver/ruim" || { meow_erro "não consegui marcar $DK_CASA/$ver/ruim"; return 2; }
  rm -f "$DK_CASA/$ver/quedas"
  meow_registrar "dock.sh pôs de lado a dock $ver: $porque"
  meow_muda "o build da dock $ver foi posto de lado ($porque) — a dock sobe do pacote"
  return 1
}

cmd_cuidar() {
  local ver dir
  ver="$(_dk_versao)" || return 0
  [ -n "$ver" ] || return 0
  dir="$DK_CASA/$ver"
  [ -x "$(_dk_binario "$ver")" ] || return 0
  [ -e "$dir/ruim" ] || return 0
  _dk_caiu "$ver" && return 0
  if [ -e "$dir/perdoado" ]; then
    _dk_marcar_caiu "$ver" "o build voltou a cair na subida depois de devolvido uma vez"
    return $?
  fi
  if ! _dk_fumaca "$(_dk_binario "$ver")"; then
    _dk_marcar_caiu "$ver" "o build não passa no teste de fumaça"
    return $?
  fi
  if meow_seco; then meow_muda "devolveria o build da dock $ver à sessão"; return 1; fi
  rm -f "$dir/ruim" "$dir/quedas"
  date -Is > "$dir/perdoado"
  meow_muda "o build da dock $ver volta à sessão: passou no teste de fumaça"
  return 1
}

_dk_baixar() {
  local ver="$1" fonte="$2" log="$3" commit curto
  commit="$(_dk_commit "$ver")" || commit=""
  curto="$(_dk_curto "$ver")" || curto=""
  if [ -z "$commit" ] || [ -z "$curto" ]; then
    meow_erro "a versão $ver da dock não diz de qual commit veio: a dock do pacote segue valendo"
    _dk_gravar_falha "$ver" recusa
    return 4
  fi
  if [ "$(git -C "$fonte" remote get-url origin 2>/dev/null)" != "$DK_URL" ]; then
    rm -rf "$fonte"
    meow_info "BAIXA DA INTERNET: o histórico do cosmic-applets (~3 MB, sem os arquivos), para $fonte"
    if ! git clone -q --filter=blob:none --no-checkout "$DK_URL" "$fonte" >>"$log" 2>&1; then
      rm -rf "$fonte"
      meow_erro "não consegui baixar o fonte da dock (sem rede?): a próxima passada tenta de novo"
      return 2
    fi
  fi
  if ! git -C "$fonte" checkout -q -f --detach "$commit" >>"$log" 2>&1; then
    git -C "$fonte" fetch -q origin >>"$log" 2>&1
    if ! git -C "$fonte" checkout -q -f --detach "$commit" >>"$log" 2>&1; then
      meow_erro "o commit $commit da dock $ver não está em $DK_URL (ou faltou rede): a dock do pacote segue valendo"
      _dk_gravar_falha "$ver" baixar
      return 2
    fi
  fi
  case "$(git -C "$fonte" rev-parse HEAD 2>/dev/null)" in
    "$curto"*) ;;
    *) meow_erro "o commit fixado para a dock $ver não é o $curto que a versão diz — confira patches/dock.versao"
       _dk_gravar_falha "$ver" recusa
       return 4 ;;
  esac
  git -C "$fonte" clean -fdxq >>"$log" 2>&1
  [ -f "$fonte/Cargo.toml" ] || { meow_erro "o fonte da dock $ver veio sem Cargo.toml"; return 2; }
  return 0
}

_dk_dry_run() {
  ( cd "$1" && patch -p1 -F0 --forward --dry-run < "$DK_REPO/$2" ) >/dev/null 2>&1
}

_dk_preparar() {
  local ver="$1" fonte="$2" log="$3" arquivo marca recusou=0 rc
  _dk_baixar "$ver" "$fonte" "$log"; rc=$?
  [ "$rc" = 0 ] || return "$rc"
  [ -n "$(_dk_marcadores)" ] || { meow_erro "a série da dock está vazia ($DK_SERIE)"; return 2; }
  while IFS=$'\t' read -r arquivo marca; do
    if _dk_dry_run "$fonte" "$arquivo"; then
      meow_ok "$arquivo entra no fonte da dock $ver sem folga (-F0)"
    else
      meow_erro "$arquivo não entra no fonte da dock $ver (-F0): o upstream mexeu onde o patch toca"
      recusou=1
    fi
  done < <(_dk_entradas)
  if [ "$recusou" = 1 ]; then
    _dk_gravar_falha "$ver" recusa
    return 4
  fi
  return 0
}

_dk_falta_ferramenta() {
  local i modo="$1" falta=()
  meow_rust_no_path
  for i in git patch; do meow_tem "$i" || falta+=("$i"); done
  [ "$modo" = validar ] || meow_tem cargo || falta+=(cargo)
  [ "${#falta[@]}" = 0 ] && return 1
  meow_pula "falta para compilar a dock: ${falta[*]} — o install traz o que é do sistema, e o rust vem pelo rustup que ele e o doctor baixam"
  return 0
}

cmd_validar() {
  local ver fonte log rc
  ver="$(_dk_versao)" || ver=""
  [ -n "$ver" ] || { meow_pula "a dock não está instalada por pacote — nada a validar"; return "$MEOW_SEM_DEPENDENCIA"; }
  _dk_falta_ferramenta validar && return "$MEOW_SEM_DEPENDENCIA"
  if meow_seco; then
    meow_muda "baixaria o fonte da dock $ver no commit $(_dk_commit "$ver" || echo '?') e rodaria o dry-run da série nele"
    return "$MEOW_DIVERGENTE"
  fi
  mkdir -p "$DK_CACHE" || return "$MEOW_ERRO"
  fonte="$DK_CACHE/fonte"; log="$DK_CACHE/validar-$ver.log"; : > "$log"
  _dk_preparar "$ver" "$fonte" "$log"; rc=$?
  rm -rf "$fonte"
  [ "$rc" = 0 ] && { meow_ok "a série entra na dock $ver"; return "$MEOW_OK"; }
  return "$MEOW_ERRO"
}

cmd_compilar() {
  local ver fonte alvo log bin livre destino arquivo marca tmp m d
  ver="$(_dk_versao)" || ver=""
  [ -n "$ver" ] || { meow_pula "a dock não está instalada por pacote — nada a compilar"; return "$MEOW_SEM_DEPENDENCIA"; }
  _dk_falta_ferramenta compilar && return "$MEOW_SEM_DEPENDENCIA"
  if [ "${DK_REFAZER:-0}" != 1 ] && _dk_valido "$ver"; then
    meow_ok "já existe build da dock para $ver — nada a compilar"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    _dk_validada "$ver" && meow_info "esta versão já passou pela série (patches/dock.versao)" \
      || meow_info "versão nova para a série: o dry-run decide e grava a recusa"
    meow_muda "baixaria o fonte da dock $ver no commit $(_dk_commit "$ver" || echo '?'), aplicaria a série (-F0, dry-run de todos antes) e compilaria o $DK_BIN"
    meow_muda "conferiria os marcadores no binário e o guardaria em $DK_CASA/$ver — sem sudo"
    return "$MEOW_DIVERGENTE"
  fi
  mkdir -p "$DK_CACHE" || { meow_erro "não consegui criar $DK_CACHE"; return "$MEOW_ERRO"; }
  livre="$(df -Pk "$DK_CACHE" 2>/dev/null | awk 'NR == 2 {print $4}')"
  if [ -n "$livre" ] && [ "$livre" -lt "$DK_ESPACO_KB" ]; then
    meow_pula "sem espaço para compilar a dock $ver: $((livre / 1024)) MB livres em $DK_CACHE, e o build pede ~$((DK_ESPACO_KB / 1024)) MB — a dock do pacote segue valendo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  fonte="$DK_CACHE/fonte"; alvo="$DK_CACHE/alvo"; log="$DK_CACHE/compilar-$ver.log"; : > "$log"
  _dk_preparar "$ver" "$fonte" "$log" || return "$MEOW_ERRO"
  while IFS=$'\t' read -r arquivo marca; do
    if ! ( cd "$fonte" && patch -p1 -F0 --forward --no-backup-if-mismatch < "$DK_REPO/$arquivo" ) >>"$log" 2>&1; then
      meow_erro "$arquivo não entrou na hora de aplicar"
      _dk_gravar_falha "$ver" recusa
      return "$MEOW_ERRO"
    fi
  done < <(_dk_entradas)

  meow_info "BAIXA DA INTERNET: as dependências da dock, e compila o $DK_BIN $ver, Nice 19"
  meow_info "  o registro vai para $log"
  if ! ( cd "$fonte" && CARGO_TARGET_DIR="$alvo" nice -n 19 cargo build --release --locked -p "$DK_BIN" --bin "$DK_BIN" ) >>"$log" 2>&1; then
    meow_erro "a compilação da dock falhou ($(meow_motivo_do_cargo "$log")) — nada foi instalado, a dock de agora continua"
    tail -n 12 "$log" 2>/dev/null | sed 's/^/        /' >&2
    _dk_gravar_falha "$ver" compilacao
    return "$MEOW_ERRO"
  fi
  bin="$alvo/release/$DK_BIN"
  [ -f "$bin" ] || { meow_erro "o cargo terminou e o binário não apareceu em $bin"; _dk_gravar_falha "$ver" compilacao; return "$MEOW_ERRO"; }
  while IFS= read -r m; do
    if grep -a -q -- "$m" "$bin" 2>/dev/null; then
      meow_ok "marcador no binário: $m"
    else
      meow_erro "$m está no fonte e NÃO no binário — o linker o comeu"
      _dk_gravar_falha "$ver" compilacao
      return "$MEOW_ERRO"
    fi
  done < <(_dk_marcadores)
  if ! _dk_fumaca "$bin"; then
    meow_erro "o binário compilado não passa no teste de fumaça (as bibliotecas dele) — nada foi instalado"
    _dk_gravar_falha "$ver" compilacao
    return "$MEOW_ERRO"
  fi

  destino="$DK_CASA/$ver"
  mkdir -p "$destino" || { meow_erro "não consegui criar $destino"; return "$MEOW_ERRO"; }
  tmp="$(mktemp -p "$destino" .dock.XXXXXX)" || return "$MEOW_ERRO"
  if ! { cp -f "$bin" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$destino/$DK_BIN"; }; then
    rm -f "$tmp"
    meow_erro "não consegui guardar o build em $destino"
    return "$MEOW_ERRO"
  fi
  _dk_marcadores > "$destino/marcadores"
  _dk_digital > "$destino/digital"
  git -C "$fonte" rev-parse HEAD > "$destino/commit" 2>/dev/null
  rm -f "$destino/ruim" "$destino/quedas" "$destino/perdoado"
  rm -rf "$fonte" "$alvo"
  _dk_limpar_falha "$ver"
  for d in "$DK_CASA"/*/; do
    [ -d "$d" ] || continue
    [ "${d%/}" = "$destino" ] && continue
    rm -rf -- "$d" && meow_info "podei o build antigo: $(basename "$d")"
  done
  meow_muda "dock patchada guardada em $destino (versão $ver), marcadores conferidos no binário"
  meow_registrar "dock.sh compilar $ver"
  meow_limpar_fim_de_build
  return "$MEOW_OK"
}

_dk_compilar_travado() {
  mkdir -p "${DK_TRAVA%/*}" || return "$MEOW_ERRO"
  (
    exec 9>>"$DK_TRAVA" || exit "$MEOW_ERRO"
    flock 9
    cmd_compilar
  )
}

cmd_aplicar() {
  local ver s mudou=0 bloqueado=0 rc
  ver="$(_dk_versao)" || ver=""
  if [ -z "$ver" ]; then
    meow_pula "a dock do COSMIC não está instalada por pacote — nada a aplicar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _dk_quer; then
    _dk_tirar; rc=$?
    [ "$rc" = 1 ] && return "$MEOW_DIVERGENTE"
    meow_pula "DOCK=\"nao\" — a dock fica de fábrica"
    return "$MEOW_OK"
  fi

  cmd_cuidar; rc=$?
  case "$rc" in 1) mudou=1 ;; 2) return "$MEOW_ERRO" ;; esac
  s="$(_dk_situacao)"
  if [ "$s" = nao-encaixa ]; then
    meow_pula "dock $ver: o patch não entra nesta versão — a dock do pacote segue valendo"
  elif _dk_valido "$ver" && _dk_ruim "$ver"; then
    meow_pula "o build da dock $ver está de lado (caiu) — a dock do pacote segue valendo"
  fi
  if ! _dk_valido "$ver" && [ "$s" != nao-encaixa ]; then
    if meow_seco; then
      meow_muda "a dock $ver ainda não tem build da casa"
      mudou=1
    elif [ "$DK_COMPILAR" = sim ]; then
      _dk_compilar_travado; rc=$?
      [ "$rc" = 0 ] && mudou=1
      if ! _dk_valido "$ver"; then
        meow_aviso "o build da dock $ver não ficou pronto — a dock do pacote segue valendo"
        if [ "$rc" = "$MEOW_SEM_DEPENDENCIA" ]; then
          bloqueado=1
        elif [ "$(_dk_situacao)" != nao-encaixa ]; then
          mudou=1
        fi
      fi
    else
      meow_info "a dock $ver ainda não tem build da casa — a do pacote segue valendo"
    fi
  fi

  _dk_ligar; rc=$?
  case "$rc" in 1) mudou=1 ;; 2) return "$MEOW_ERRO" ;; esac

  [ "$mudou" = 1 ] && return "$MEOW_DIVERGENTE"
  [ "$bloqueado" = 1 ] && return "$MEOW_SEM_DEPENDENCIA"
  _dk_valido "$ver" && ! _dk_ruim "$ver" || return "$MEOW_OK"
  meow_ok "dock em dia: build $ver e o shim, que escolhe $(_dk_esperado)"
  return "$MEOW_OK"
}

cmd_reverter() {
  local rc
  _dk_tirar; rc=$?
  if [ "$rc" = 1 ]; then
    meow_seco || meow_muda "a dock voltou ao binário do pacote"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "a dock já está como o pacote deixa"
  return "$MEOW_OK"
}

cmd_estado() {
  local ver
  ver="$(_dk_versao)"
  printf 'versao=%s\nestado=%s\nbuild=%s\nshim=%s\nruim=%s\ncommit=%s\n' \
    "$ver" "$(_dk_situacao)" \
    "$([ -n "$ver" ] && _dk_valido "$ver" && echo sim || echo nao)" \
    "$([ -e "$DK_SHIM" ] && _dk_shim_nosso "$DK_SHIM" && echo sim || echo nao)" \
    "$([ -n "$ver" ] && _dk_ruim "$ver" && echo sim || echo nao)" \
    "$([ -n "$ver" ] && _dk_commit "$ver")"
  return "$MEOW_OK"
}

case "${1:-aplicar}" in
  aplicar)             cmd_aplicar ;;
  --conferir|conferir) MEOW_SECO=1; cmd_aplicar ;;
  reverter)            cmd_reverter ;;
  compilar)            cmd_compilar ;;
  validar)             cmd_validar ;;
  cuidar)              cmd_cuidar ;;
  pendente)            _dk_quer && _dk_pendente; exit 0 ;;
  estado)              cmd_estado ;;
  *) meow_erro "uso: dock.sh [aplicar|conferir|reverter|compilar|validar|cuidar|pendente|estado]"; exit "$MEOW_ERRO" ;;
esac

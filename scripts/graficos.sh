#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

GRAFICOS="${GRAFICOS:-}"
GR_COMPILAR="${GR_COMPILAR:-sim}"
GR_PACOTE=xdg-desktop-portal-cosmic
GR_CHROME=google-chrome-stable
GR_UNIDADE=org.freedesktop.impl.portal.desktop.cosmic.service
GR_REPO="${GR_REPO:-$MEOW_RAIZ/patches}"
GR_SERIE="${GR_SERIE:-$GR_REPO/graficos.series}"
GR_VERSOES="${GR_VERSOES:-$GR_REPO/graficos.versao}"
GR_CASA="${GR_CASA:-$HOME/.local/libexec/meow/graficos}"
GR_SHIM="${GR_SHIM:-$GR_CASA/portal-shim}"
GR_SHIM_FONTE="$MEOW_RAIZ/scripts/portal_shim.sh"
GR_SHIM_MARCA="MEOW-PORTAL-SHIM"
GR_DROPIN_DIR="${GR_DROPIN_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$GR_UNIDADE.d}"
GR_DROPIN="$GR_DROPIN_DIR/meow-graficos.conf"
GR_DROPIN_MARCA="MEOW-PORTAL-DROPIN"
GR_FABRICA="${GR_FABRICA:-/usr/libexec/xdg-desktop-portal-cosmic}"
GR_CACHE="${GR_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/graficos}"
GR_FALHAS="${GR_FALHAS:-$MEOW_ESTADO/graficos/falhas.tsv}"
GR_TRAVA="${GR_TRAVA:-$MEOW_ESTADO/builds.lock}"
GR_POLICY="${GR_POLICY:-/etc/opt/chrome/policies/managed/compartilhar-tela.json}"
GR_PROC="${GR_PROC:-/proc}"
GR_PW_DUMP="${GR_PW_DUMP:-pw-dump}"
GR_JOURNALCTL="${GR_JOURNALCTL:-journalctl}"
GR_ESPACO_KB="${GR_ESPACO_KB:-6500000}"
GR_JANELA_QUEDAS="${GR_JANELA_QUEDAS:-86400}"
GR_QUEDAS_RUIM="${GR_QUEDAS_RUIM:-2}"
GR_ASSINATURA='screencast_thread\.rs|create_frame sent before'

GR_POLICY_TEXTO='{
  "ScreenCaptureAllowed": true,
  "VideoCaptureAllowed": true,
  "AudioCaptureAllowed": true
}'

GR_CARGO_BIN="${CARGO_HOME:-$HOME/.cargo}/bin"
case ":$PATH:" in
  *":$GR_CARGO_BIN:"*) ;;
  *) [ -d "$GR_CARGO_BIN" ] && PATH="$GR_CARGO_BIN:$PATH" && export PATH ;;
esac

_gr_quer() {
  local q="${GRAFICOS:-}"
  [ -n "$q" ] || q="$(meow_conf_valor GRAFICOS 2>/dev/null)" || q=sim
  [ "${q:-sim}" != nao ]
}

_gr_instalado() {
  dpkg-query -W -f='${Package}\t${Version}\t${db:Status-Status}\n' "$1" 2>/dev/null |
    awk -F'\t' -v p="$1" '$1 == p && $3 == "installed" && $2 != "" {print $2; exit}'
}

_gr_versao() { _gr_instalado "$GR_PACOTE"; }

_gr_chrome_instalado() { [ -n "$(_gr_instalado "$GR_CHROME")" ]; }

_gr_fim() { awk '$1 == "fim" && $2 != "" {print $2; exit}' "$GR_VERSOES" 2>/dev/null; }

_gr_oficial() {
  local fim
  fim="$(_gr_fim)"
  [ -n "$fim" ] && dpkg --compare-versions "$1" ge "$fim" 2>/dev/null
}

_gr_validada() { grep -qxF -- "$(_gr_versao_do_fonte "$1")" "$GR_VERSOES" 2>/dev/null; }

_gr_entradas() {
  local alvo arquivo marca
  [ -f "$GR_SERIE" ] || return 1
  while read -r alvo arquivo marca _; do
    case "$alvo" in portal|toolkit) ;; *) continue ;; esac
    [ -n "$arquivo" ] && [ -n "$marca" ] || continue
    printf '%s\t%s\t%s\n' "$alvo" "$arquivo" "$marca"
  done < "$GR_SERIE"
}

_gr_marcadores() { _gr_entradas | awk -F'\t' '$3 != "-" {print $3}'; }

_gr_digital() {
  local alvo arquivo _m
  {
    cat "$GR_SERIE" 2>/dev/null
    while IFS=$'\t' read -r alvo arquivo _m; do cat "$GR_REPO/$arquivo" 2>/dev/null; done < <(_gr_entradas)
  } | md5sum | cut -c1-32
}

_gr_binario() { printf '%s/%s/%s' "$GR_CASA" "$1" "$GR_PACOTE"; }

_gr_valido() {
  local bin dir m
  dir="$GR_CASA/$1"; bin="$(_gr_binario "$1")"
  [ -x "$bin" ] || return 1
  while IFS= read -r m; do
    [ -n "$m" ] && { grep -a -q -- "$m" "$bin" 2>/dev/null || return 1; }
  done < <(_gr_marcadores)
  [ "$(cat "$dir/digital" 2>/dev/null)" = "$(_gr_digital)" ]
}

_gr_ruim() { [ -e "$GR_CASA/$1/ruim" ]; }

_gr_caiu() { [ "$(head -c 4 "$GR_CASA/$1/ruim" 2>/dev/null)" = caiu ]; }

_gr_fumaca() { [ -x "$1" ] && ! ldd "$1" 2>/dev/null | grep -q 'not found'; }

_gr_falha() {
  awk -F'\t' -v v="$1" -v d="$(_gr_digital)" '$1 == v && $2 == d {l = $3 "\t" $4 "\t" $5} END {if (l != "") print l}' "$GR_FALHAS" 2>/dev/null
}

_gr_gravar_falha() {
  local ver="$1" tipo="$2" atual n=1 digital
  digital="$(_gr_digital)"
  atual="$(_gr_falha "$ver")"
  [ -z "$atual" ] || n=$(( $(printf '%s' "$atual" | cut -f2) + 1 ))
  meow_seco && return 0
  mkdir -p "${GR_FALHAS%/*}" || return 0
  { awk -F'\t' -v v="$ver" -v d="$digital" '!($1 == v && $2 == d)' "$GR_FALHAS" 2>/dev/null
    printf '%s\t%s\t%s\t%s\t%s\n' "$ver" "$digital" "$tipo" "$n" "$(date +%s)"; } > "$GR_FALHAS.novo" \
    && mv -f "$GR_FALHAS.novo" "$GR_FALHAS"
  [ "$tipo" = recusa ] && meow_registrar "graficos.sh: o patch do portal não entra no $ver, e o portal do pacote segue valendo"
  return 0
}

_gr_limpar_falha() {
  meow_seco && return 0
  [ -f "$GR_FALHAS" ] || return 0
  awk -F'\t' -v v="$1" '$1 != v' "$GR_FALHAS" > "$GR_FALHAS.novo" 2>/dev/null && mv -f "$GR_FALHAS.novo" "$GR_FALHAS"
  return 0
}

_gr_espera() {
  local f tipo n quando s
  f="$(_gr_falha "$1")"
  [ -n "$f" ] || return 1
  tipo="$(printf '%s' "$f" | cut -f1)"; n="$(printf '%s' "$f" | cut -f2)"; quando="$(printf '%s' "$f" | cut -f3)"
  [ "$tipo" = recusa ] && return 0
  case "$n$quando" in ''|*[!0-9]*) return 1 ;; esac
  [ "$n" -gt 9 ] && n=9
  s=$(( 3600 << (n - 1) )); [ "$s" -gt 604800 ] && s=604800
  [ "$(date +%s)" -lt $(( quando + s )) ]
}

_gr_situacao() {
  local ver f tipo
  ver="$(_gr_versao)"
  [ -n "$ver" ] || { printf ausente; return; }
  _gr_quer || { printf desligado; return; }
  _gr_oficial "$ver" && { printf oficial; return; }
  if _gr_valido "$ver"; then
    if _gr_ruim "$ver"; then printf falhou; else printf ok; fi
    return
  fi
  f="$(_gr_falha "$ver")"
  if [ -n "$f" ]; then
    tipo="$(printf '%s' "$f" | cut -f1)"
    if [ "$tipo" = recusa ]; then printf nao-encaixa; else printf falhou; fi
    return
  fi
  printf pendente
}

_gr_pendente() {
  local ver s
  ver="$(_gr_versao)"
  [ -n "$ver" ] || return 1
  s="$(_gr_situacao)"
  case "$s" in
    pendente) ;;
    falhou) _gr_valido "$ver" && return 1; _gr_espera "$ver" && return 1 ;;
    *) return 1 ;;
  esac
  printf '%s\n' "$ver"
}

_gr_pedir_a_ponte() {
  local verbo="$1" frase="$2"
  if ! meow_ponte_viva; then
    meow_pula "$frase: a ponte root não está de pé, o «Instalar tudo» a levanta"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! grep -qx "$verbo)" "$MEOW_PONTE" 2>/dev/null; then
    meow_pula "$frase: a ponte root instalada é de antes deste conserto, o «Instalar tudo» a renova"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_ponte "$verbo" </dev/null >/dev/null 2>&1; then
    meow_erro "a ponte root não aceitou $verbo: o «Instalar tudo» a atualiza"
    return "$MEOW_ERRO"
  fi
  return "$MEOW_OK"
}

_gr_policy_igual() { [ -f "$GR_POLICY" ] && cmp -s <(printf '%s\n' "$GR_POLICY_TEXTO") "$GR_POLICY"; }

_gr_policy_pedir() {
  local verbo="$1" frase="$2" rc
  _gr_pedir_a_ponte "$verbo" "$frase"; rc=$?
  return "$rc"
}

_gr_policy_aplicar() {
  local rc
  _gr_chrome_instalado || return 0
  if _gr_policy_igual; then
    meow_ok "a policy de compartilhar tela do Chrome já está no lugar"
    return 0
  fi
  meow_muda "a policy de compartilhar tela do Chrome não está no lugar ($GR_POLICY)"
  meow_seco && return 1
  _gr_policy_pedir chrome-policy "pôr a policy de compartilhar tela do Chrome"; rc=$?
  [ "$rc" = 0 ] || return "$rc"
  _gr_policy_igual || { meow_erro "a policy do Chrome não ficou como devia ($GR_POLICY)"; return 2; }
  meow_registrar "graficos.sh policy do Chrome"
  return 1
}

_gr_policy_tirar() {
  local rc
  [ -e "$GR_POLICY" ] || [ -L "$GR_POLICY" ] || return 0
  meow_muda "a policy de compartilhar tela do Chrome sairia ($GR_POLICY)"
  meow_seco && return 1
  _gr_policy_pedir chrome-policy-tirar "tirar a policy de compartilhar tela do Chrome"; rc=$?
  [ "$rc" = 0 ] || return "$rc"
  [ ! -e "$GR_POLICY" ] && [ ! -L "$GR_POLICY" ] || { meow_erro "a policy do Chrome continua em $GR_POLICY"; return 2; }
  return 1
}

_gr_texto_dropin() {
  printf '# %s-1\n[Service]\nExecStart=\nExecStart=%s' "$GR_DROPIN_MARCA" "$GR_SHIM"
}

_gr_shim_nosso() { grep -qs -- "$GR_SHIM_MARCA" "$1"; }

_gr_dropin_nosso() { grep -qs -- "$GR_DROPIN_MARCA" "$GR_DROPIN"; }

_gr_recarregar() {
  meow_seco && return 0
  meow_tem systemctl || return 0
  systemctl --user daemon-reload >/dev/null 2>&1 || true
}

_gr_execstart() {
  meow_tem systemctl || return 1
  systemctl --user show -p ExecStart --value "$GR_UNIDADE" 2>/dev/null | sed -n 's/^{ path=\([^ ]*\) ;.*/\1/p' | head -1
}

_gr_exe_vivo() {
  local pid
  meow_tem systemctl || return 1
  pid="$(systemctl --user show -p MainPID --value "$GR_UNIDADE" 2>/dev/null)"
  case "$pid" in ''|0|*[!0-9]*) return 1 ;; esac
  readlink "$GR_PROC/$pid/exe" 2>/dev/null
}

_gr_stream() {
  local saida veredito
  meow_tem "$GR_PW_DUMP" || return 2
  saida="$("$GR_PW_DUMP" 2>/dev/null)" || return 2
  veredito="$(printf '%s' "$saida" | python3 -I -c '
import json, sys
nos = json.load(sys.stdin)
print("no-ar" if any(
    o.get("type") == "PipeWire:Interface:Node"
    and ((o.get("info") or {}).get("props") or {}).get("node.name") == "cosmic-screencast"
    for o in nos) else "livre")' 2>/dev/null)"
  case "$veredito" in
    no-ar) return 0 ;;
    livre) return 1 ;;
  esac
  return 2
}

_gr_esperado() {
  MEOW_SHIM_SO_DIZER=1 MEOW_SHIM_CASA="$GR_CASA" MEOW_SHIM_FABRICA="$GR_FABRICA" bash "$GR_SHIM" 2>/dev/null
}

_gr_reiniciar() {
  local frase="$1" rc
  _gr_stream; rc=$?
  case "$rc" in
    0) meow_info "$frase: há compartilhamento no ar, e a troca espera ele acabar"; return 0 ;;
    2) meow_info "$frase: não consegui ver o PipeWire, e a troca vale na próxima subida do portal"; return 0 ;;
  esac
  if ! systemctl --user restart "$GR_UNIDADE" >/dev/null 2>&1; then
    meow_info "$frase: o portal não reiniciou agora, e a troca vale na próxima subida dele"
    return 0
  fi
  meow_muda "$frase: o portal reiniciou"
  return 1
}

_gr_ligar_portal() {
  local mudou=0 esperado vivo efetivo
  if ! cmp -s "$GR_SHIM_FONTE" "$GR_SHIM" 2>/dev/null; then
    [ ! -e "$GR_SHIM" ] || _gr_shim_nosso "$GR_SHIM" || { meow_erro "$GR_SHIM existe e não é o shim do portal do meow — não o troco"; return 2; }
    meow_muda "o shim do portal não está em $GR_SHIM"
    if ! meow_seco; then
      meow_guardar_antes "$GR_SHIM"
      mkdir -p "${GR_SHIM%/*}" || return 2
      local tmp; tmp="$(mktemp -p "${GR_SHIM%/*}" .meow-shim.XXXXXX)" || return 2
      cp -f "$GR_SHIM_FONTE" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$GR_SHIM" \
        || { rm -f "$tmp"; meow_erro "não consegui instalar $GR_SHIM"; return 2; }
      meow_manifesto_registrar "$GR_SHIM"
    fi
    mudou=1
  fi
  if [ -e "$GR_DROPIN" ] && ! _gr_dropin_nosso; then
    meow_erro "$GR_DROPIN existe e não é do meow — não o troco"
    return 2
  fi
  if [ "$(cat "$GR_DROPIN" 2>/dev/null)" != "$(_gr_texto_dropin)" ]; then
    meow_muda "o drop-in do portal não está no lugar ($GR_DROPIN)"
    if ! meow_seco; then
      meow_escrever "$GR_DROPIN" "$(_gr_texto_dropin)" 644 >/dev/null
      [ "$?" = 2 ] && { meow_erro "não consegui escrever $GR_DROPIN"; return 2; }
    fi
    mudou=1
  fi
  if [ "$mudou" = 1 ]; then
    meow_seco && return 1
    _gr_recarregar
    meow_registrar "graficos.sh shim e drop-in do portal"
  fi

  efetivo="$(_gr_execstart)" || efetivo=""
  if [ -z "$efetivo" ]; then
    [ "$mudou" = 1 ] && return 1
    return 0
  fi
  if [ "$efetivo" != "$GR_SHIM" ]; then
    meow_pula "o ExecStart do portal é de outro drop-in ($efetivo): o do meow espera"
    return 3
  fi
  vivo="$(_gr_exe_vivo)" || vivo=""
  esperado="$(_gr_esperado)"
  if [ -n "$vivo" ] && [ -n "$esperado" ] && [ "$vivo" != "$esperado" ]; then
    meow_muda "o portal roda $vivo e devia rodar $esperado"
    meow_seco && return 1
    _gr_reiniciar "o portal da casa"; return $(( $? | mudou ))
  fi
  return "$mudou"
}

_gr_tirar_portal() {
  local mudou=0 vivo
  if [ -e "$GR_DROPIN" ]; then
    if _gr_dropin_nosso; then
      meow_muda "o drop-in do portal sairia ($GR_DROPIN)"
      meow_seco || { meow_guardar_antes "$GR_DROPIN"; rm -f "$GR_DROPIN"; }
      mudou=1
    else
      meow_pula "$GR_DROPIN não é do meow — fica"
    fi
  fi
  if [ -e "$GR_SHIM" ] && _gr_shim_nosso "$GR_SHIM"; then
    meow_muda "o shim do portal sairia ($GR_SHIM)"
    meow_seco || { meow_guardar_antes "$GR_SHIM"; rm -f "$GR_SHIM"; }
    mudou=1
  fi
  if [ "$mudou" = 1 ] && ! meow_seco; then
    _gr_recarregar
    meow_registrar "graficos.sh tirou o shim e o drop-in do portal"
  fi
  vivo="$(_gr_exe_vivo)" || vivo=""
  case "$vivo" in
    "$GR_CASA"/*)
      if meow_seco; then
        meow_muda "o portal roda o build da casa e voltaria ao do pacote"
        return 1
      fi
      _gr_reiniciar "o portal volta ao do pacote"
      return $(( $? | mudou ))
      ;;
  esac
  return "$mudou"
}

_gr_quedas() {
  local desde="$1"
  meow_tem "$GR_JOURNALCTL" && meow_tem python3 || return 1
  "$GR_JOURNALCTL" --user -q --no-pager --since="@$desde" -o json -g "$GR_ASSINATURA" "_SYSTEMD_USER_UNIT=$GR_UNIDADE" 2>/dev/null \
    | python3 -I -c '
import json, sys
assinaturas = ("screencast_thread.rs", "create_frame sent before")
contagem, ultimo = {}, {}
for linha in sys.stdin:
    try:
        e = json.loads(linha)
    except ValueError:
        continue
    m = e.get("MESSAGE") or ""
    if isinstance(m, list):
        m = bytes(m).decode("utf-8", "replace")
    if not any(a in m for a in assinaturas):
        continue
    exe = e.get("_EXE") or "-"
    t = int(e.get("__REALTIME_TIMESTAMP") or 0)
    if exe not in ultimo or t - ultimo[exe] > 10000000:
        contagem[exe] = contagem.get(exe, 0) + 1
    ultimo[exe] = t
for exe in sorted(contagem):
    print("%s\t%d" % (exe, contagem[exe]))'
}

_gr_quedas_do() {
  local desde="$2" saida
  saida="$(_gr_quedas "$desde")" || return 1
  printf '%s\n' "$saida" | awk -F'\t' -v e="$1" '$1 == e {n += $2} END {print n + 0}'
}

_gr_instalado_em() { stat -c %Y "$GR_CASA/$1/digital" 2>/dev/null || echo 0; }

_gr_desde_do_build() {
  local agora minimo inst
  agora="$(date +%s)"; minimo=$(( agora - GR_JANELA_QUEDAS )); inst="$(_gr_instalado_em "$1")"
  [ "$inst" -gt "$minimo" ] && printf '%s' "$inst" || printf '%s' "$minimo"
}

_gr_marcar_caiu() {
  local ver="$1" porque="$2"
  if meow_seco; then meow_muda "poria de lado o build do portal $ver: $porque"; return 1; fi
  printf 'caiu %s\n' "$(date -Is)" > "$GR_CASA/$ver/ruim" || { meow_erro "não consegui marcar $GR_CASA/$ver/ruim"; return 2; }
  rm -f "$GR_CASA/$ver/quedas"
  meow_registrar "graficos.sh pôs de lado o portal $ver: $porque"
  meow_muda "o build do portal $ver foi posto de lado ($porque) — o portal sobe do pacote"
  return 1
}

cmd_cuidar() {
  local ver dir q
  ver="$(_gr_versao)" || return 0
  [ -n "$ver" ] || return 0
  dir="$GR_CASA/$ver"
  [ -x "$(_gr_binario "$ver")" ] || return 0
  if [ ! -e "$dir/ruim" ] && q="$(_gr_quedas_do "$(_gr_binario "$ver")" "$(_gr_desde_do_build "$ver")")" && [ "${q:-0}" -ge "$GR_QUEDAS_RUIM" ]; then
    _gr_marcar_caiu "$ver" "o build caiu $q vez(es) com a assinatura medida"
    return $?
  fi
  [ -e "$dir/ruim" ] || return 0
  _gr_caiu "$ver" && return 0
  if [ -e "$dir/perdoado" ]; then
    _gr_marcar_caiu "$ver" "o build voltou a ser posto de lado depois de devolvido uma vez"
    return $?
  fi
  if ! _gr_fumaca "$(_gr_binario "$ver")"; then
    _gr_marcar_caiu "$ver" "o build não passa no teste de fumaça"
    return $?
  fi
  if meow_seco; then meow_muda "devolveria o build do portal $ver ao compartilhamento"; return 1; fi
  rm -f "$dir/ruim" "$dir/quedas"
  date -Is > "$dir/perdoado"
  meow_muda "o build do portal $ver volta à sessão: passou no teste de fumaça, e o registro não tem queda dele"
  return 1
}

_gr_versao_do_fonte() {
  if [[ "$1" =~ ^(.+)\+[0-9]+~[a-z][a-z0-9]*[0-9]+$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    printf '%s' "$1"
  fi
}

_gr_dsc() { printf '%s/baixado/%s_%s.dsc' "$GR_CACHE" "$GR_PACOTE" "$(_gr_versao_do_fonte "${1#*:}")"; }

_gr_baixar() {
  local ver="$1" baixado dsc log fonte_ver
  baixado="$GR_CACHE/baixado"
  fonte_ver="$(_gr_versao_do_fonte "$ver")"
  dsc="$(_gr_dsc "$ver")"
  [ -f "$dsc" ] && return 0
  mkdir -p "$baixado" || { meow_erro "não consegui criar $baixado"; return 2; }
  log="$GR_CACHE/baixar-$ver.log"
  meow_info "BAIXA DA INTERNET: o fonte do portal $fonte_ver (~155 MB), para $baixado"
  if ! ( cd "$baixado" && apt-get source --download-only "$GR_PACOTE=$fonte_ver" ) >"$log" 2>&1; then
    if grep -q ' 404 ' "$log" 2>/dev/null; then
      meow_erro "o repositório já não serve o fonte do portal $ver (404): o portal do pacote segue valendo"
      _gr_gravar_falha "$ver" baixar
    elif grep -qiE "deb-src|'source'" "$log" 2>/dev/null; then
      meow_erro "as fontes do apt desta máquina não servem código-fonte (sem deb-src): o portal do pacote segue valendo"
      _gr_gravar_falha "$ver" baixar
    elif meow_apt_fonte_saiu_do_repositorio "$log"; then
      meow_erro "o repositório já não serve o fonte do portal $fonte_ver: o portal do pacote segue valendo, e o próximo apt traz a versão nova"
      _gr_gravar_falha "$ver" baixar
    else
      meow_erro "o apt-get source do portal $ver falhou (sem rede?): a próxima passada tenta de novo"
    fi
    return 2
  fi
  [ -f "$dsc" ] || { meow_erro "o fonte do portal $ver baixou sem o .dsc esperado"; return 2; }
}

_gr_dry_run() {
  ( cd "$1" && patch -p1 -F0 --forward --dry-run < "$GR_REPO/$2" ) >/dev/null 2>&1
}

_gr_aplicar_patch() {
  local arvore="$1" arquivo="$2"
  ( cd "$arvore" && patch -p1 -F0 --forward --no-backup-if-mismatch < "$GR_REPO/$arquivo" ) >/dev/null 2>&1
}

_gr_montar_toolkit() {
  local fonte="$1" tmp d
  tmp="$(mktemp -d -p "$GR_CACHE" toolkit.XXXXXX)" || return 1
  tar xf "$fonte/vendor.tar" -C "$tmp" vendor/cosmic-protocols vendor/cosmic-client-toolkit 2>/dev/null \
    || { rm -rf "$tmp"; return 1; }
  [ -f "$tmp/vendor/cosmic-protocols/Cargo.toml" ] && [ -f "$tmp/vendor/cosmic-client-toolkit/Cargo.toml" ] \
    || { rm -rf "$tmp"; return 1; }
  d="$fonte/meow-toolkit"
  rm -rf "$d"
  mkdir -p "$d" && cp -a "$tmp/vendor/cosmic-protocols/." "$d/" \
    && mkdir -p "$d/client-toolkit" && cp -a "$tmp/vendor/cosmic-client-toolkit/." "$d/client-toolkit/" \
    && rm -f "$d/.cargo-checksum.json" "$d/client-toolkit/.cargo-checksum.json"
  local rc=$?
  rm -rf "$tmp"
  return "$rc"
}

_gr_preparar() {
  local ver="$1" fonte="$2" log="$3" alvo arquivo marca arvore recusou=0
  _gr_baixar "$ver" || return 2
  rm -rf "$fonte"
  if ! dpkg-source -x "$(_gr_dsc "$ver")" "$fonte" >>"$log" 2>&1 || [ ! -f "$fonte/Cargo.toml" ]; then
    meow_erro "o fonte do portal não se extraiu em $fonte (registro: $log)"
    return 2
  fi
  if ! _gr_montar_toolkit "$fonte"; then
    meow_erro "o fonte do portal $ver não traz o toolkit do COSMIC como esperado — o upstream mudou a forma"
    _gr_gravar_falha "$ver" recusa
    return 4
  fi
  while IFS=$'\t' read -r alvo arquivo marca; do
    case "$alvo" in portal) arvore="$fonte" ;; toolkit) arvore="$fonte/meow-toolkit" ;; esac
    if _gr_dry_run "$arvore" "$arquivo"; then
      meow_ok "$arquivo entra no fonte do portal $ver sem folga (-F0)"
    else
      meow_erro "$arquivo não entra no fonte do portal $ver (-F0): o upstream mexeu onde o patch toca"
      recusou=1
    fi
  done < <(_gr_entradas)
  if [ "$recusou" = 1 ]; then
    _gr_gravar_falha "$ver" recusa
    return 4
  fi
  return 0
}

cmd_validar() {
  local ver fonte log
  ver="$(_gr_versao)" || ver=""
  [ -n "$ver" ] || { meow_pula "o portal não está instalado por pacote — nada a validar"; return "$MEOW_SEM_DEPENDENCIA"; }
  _gr_falta_ferramenta validar && return "$MEOW_SEM_DEPENDENCIA"
  if meow_seco; then
    meow_muda "baixaria o fonte do portal $ver (~155 MB) e rodaria o dry-run da série nele, sem escrever na árvore"
    return "$MEOW_DIVERGENTE"
  fi
  mkdir -p "$GR_CACHE" || return "$MEOW_ERRO"
  fonte="$GR_CACHE/fonte-validar"; log="$GR_CACHE/validar-$ver.log"; : > "$log"
  _gr_preparar "$ver" "$fonte" "$log"; local rc=$?
  rm -rf "$fonte"
  [ "$rc" = 0 ] && { meow_ok "a série entra no portal $ver"; return "$MEOW_OK"; }
  return "$MEOW_ERRO"
}

_gr_falta_ferramenta() {
  local i modo="$1" falta=()
  meow_rust_no_path
  for i in patch tar dpkg-source apt-get; do meow_tem "$i" || falta+=("$i"); done
  [ "$modo" = validar ] || meow_tem cargo || falta+=(cargo)
  [ "${#falta[@]}" = 0 ] && return 1
  meow_pula "falta para compilar o portal: ${falta[*]} — o install traz o que é do sistema, e o rust vem pelo rustup que ele e o doctor baixam"
  return 0
}

cmd_compilar() {
  local ver fonte log bin livre destino alvo arquivo marca arvore tmp m d
  ver="$(_gr_versao)" || ver=""
  [ -n "$ver" ] || { meow_pula "o portal não está instalado por pacote — nada a compilar"; return "$MEOW_SEM_DEPENDENCIA"; }
  if _gr_oficial "$ver"; then
    meow_ok "o pacote do portal $ver já traz a correção oficial — não há o que compilar"
    return "$MEOW_OK"
  fi
  _gr_falta_ferramenta compilar && return "$MEOW_SEM_DEPENDENCIA"
  if [ "${GR_REFAZER:-0}" != 1 ] && _gr_valido "$ver"; then
    meow_ok "já existe build do portal para $ver — nada a compilar"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    _gr_validada "$ver" && meow_info "esta versão já passou pela série (patches/graficos.versao)" \
      || meow_info "versão nova para a série: o dry-run decide e grava a recusa"
    meow_muda "baixaria o fonte do portal $ver (~155 MB), aplicaria a série (-F0, dry-run de todos antes) e compilaria (~4 min, ~5 GB)"
    meow_muda "conferiria os marcadores no binário e o guardaria em $GR_CASA/$ver — sem sudo"
    return "$MEOW_DIVERGENTE"
  fi
  mkdir -p "$GR_CACHE" || { meow_erro "não consegui criar $GR_CACHE"; return "$MEOW_ERRO"; }
  livre="$(df -Pk "$GR_CACHE" 2>/dev/null | awk 'NR == 2 {print $4}')"
  if [ -n "$livre" ] && [ "$livre" -lt "$GR_ESPACO_KB" ]; then
    meow_pula "sem espaço para compilar o portal $ver: $((livre / 1024)) MB livres em $GR_CACHE, e o build pede ~$((GR_ESPACO_KB / 1024)) MB — o portal do pacote segue valendo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  fonte="$GR_CACHE/fonte"; log="$GR_CACHE/compilar-$ver.log"; : > "$log"
  if ! _gr_preparar "$ver" "$fonte" "$log"; then
    rm -rf "$fonte"
    return "$MEOW_ERRO"
  fi
  while IFS=$'\t' read -r alvo arquivo marca; do
    case "$alvo" in portal) arvore="$fonte" ;; toolkit) arvore="$fonte/meow-toolkit" ;; esac
    _gr_aplicar_patch "$arvore" "$arquivo" || { meow_erro "$arquivo não entrou na hora de aplicar"; rm -rf "$fonte"; _gr_gravar_falha "$ver" recusa; return "$MEOW_ERRO"; }
  done < <(_gr_entradas)

  meow_info "compilando o portal $ver, Nice 19 (~4 min)"
  meow_info "  o registro vai para $log"
  if ! ( cd "$fonte" && tar pxf vendor.tar && nice -n 19 cargo build --release --frozen --offline --bin "$GR_PACOTE" ) >>"$log" 2>&1; then
    meow_erro "a compilação do portal falhou — nada foi instalado, o portal de agora continua"
    tail -n 12 "$log" 2>/dev/null | sed 's/^/        /' >&2
    rm -rf "$fonte"
    _gr_gravar_falha "$ver" compilacao
    return "$MEOW_ERRO"
  fi
  bin="$fonte/target/release/$GR_PACOTE"
  [ -f "$bin" ] || { meow_erro "o cargo terminou e o binário não apareceu em $bin"; rm -rf "$fonte"; _gr_gravar_falha "$ver" compilacao; return "$MEOW_ERRO"; }
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    if grep -a -q -- "$m" "$bin" 2>/dev/null; then
      meow_ok "marcador no binário: $m"
    else
      meow_erro "$m está no fonte e NÃO no binário — o linker o comeu (falta o #[used])"
      rm -rf "$fonte"; _gr_gravar_falha "$ver" compilacao
      return "$MEOW_ERRO"
    fi
  done < <(_gr_marcadores)
  if ! _gr_fumaca "$bin"; then
    meow_erro "o binário compilado não passa no teste de fumaça (as bibliotecas dele) — nada foi instalado"
    rm -rf "$fonte"; _gr_gravar_falha "$ver" compilacao
    return "$MEOW_ERRO"
  fi

  destino="$GR_CASA/$ver"
  mkdir -p "$destino" || { meow_erro "não consegui criar $destino"; rm -rf "$fonte"; return "$MEOW_ERRO"; }
  tmp="$(mktemp -p "$destino" .portal.XXXXXX)" || { rm -rf "$fonte"; return "$MEOW_ERRO"; }
  if ! { cp -f "$bin" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$destino/$GR_PACOTE"; }; then
    rm -f "$tmp"; rm -rf "$fonte"
    meow_erro "não consegui guardar o build em $destino"
    return "$MEOW_ERRO"
  fi
  _gr_marcadores > "$destino/marcadores"
  _gr_digital > "$destino/digital"
  rm -f "$destino/ruim" "$destino/quedas" "$destino/perdoado"
  rm -rf "$fonte" "$GR_CACHE/baixado"
  _gr_limpar_falha "$ver"
  for d in "$GR_CASA"/*/; do
    [ -d "$d" ] || continue
    [ "${d%/}" = "$destino" ] && continue
    rm -rf -- "$d" && meow_info "podei o build antigo: $(basename "$d")"
  done
  meow_muda "portal patchado guardado em $destino (versão $ver), marcadores conferidos no binário"
  meow_registrar "graficos.sh compilar $ver"
  return "$MEOW_OK"
}

_gr_compilar_travado() {
  mkdir -p "${GR_TRAVA%/*}" || return "$MEOW_ERRO"
  (
    exec 9>>"$GR_TRAVA" || exit "$MEOW_ERRO"
    flock 9
    cmd_compilar
  )
}

cmd_aplicar() {
  local ver s mudou=0 bloqueado=0 rc
  ver="$(_gr_versao)" || ver=""
  if [ -z "$ver" ]; then
    meow_pula "o portal do COSMIC não está instalado por pacote — nada a aplicar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _gr_quer; then
    _gr_tirar_portal; rc=$?; [ "$rc" = 1 ] && mudou=1
    _gr_policy_tirar; rc=$?
    case "$rc" in 1) mudou=1 ;; 2) return "$MEOW_ERRO" ;; 3) bloqueado=1 ;; esac
    [ "$mudou" = 1 ] && return "$MEOW_DIVERGENTE"
    [ "$bloqueado" = 1 ] && return "$MEOW_SEM_DEPENDENCIA"
    meow_pula "GRAFICOS=\"nao\" — o portal e a policy ficam de fábrica"
    return "$MEOW_OK"
  fi
  if _gr_oficial "$ver"; then
    _gr_tirar_portal; rc=$?; [ "$rc" = 1 ] && mudou=1
    _gr_policy_aplicar; rc=$?
    case "$rc" in 1) mudou=1 ;; 2) return "$MEOW_ERRO" ;; 3) bloqueado=1 ;; esac
    meow_ok "o pacote do portal $ver já traz a correção oficial"
    [ "$mudou" = 1 ] && return "$MEOW_DIVERGENTE"
    [ "$bloqueado" = 1 ] && return "$MEOW_SEM_DEPENDENCIA"
    return "$MEOW_OK"
  fi

  cmd_cuidar; [ "$?" = 1 ] && mudou=1
  s="$(_gr_situacao)"
  if [ "$s" = nao-encaixa ]; then
    meow_pula "portal $ver: o patch não entra nesta versão — o portal do pacote segue valendo"
  elif _gr_valido "$ver"; then
    _gr_ruim "$ver" && meow_pula "o build do portal $ver está de lado (caiu) — o portal do pacote segue valendo"
  fi
  if ! _gr_valido "$ver" && [ "$s" != nao-encaixa ]; then
    if meow_seco; then
      meow_muda "o portal $ver ainda não tem build da casa"
      mudou=1
    elif [ "$GR_COMPILAR" = sim ]; then
      _gr_compilar_travado; rc=$?
      [ "$rc" = 0 ] && mudou=1
      if ! _gr_valido "$ver"; then
        meow_aviso "o build do portal $ver não ficou pronto — o portal do pacote segue valendo"
        if [ "$rc" = "$MEOW_SEM_DEPENDENCIA" ]; then
          bloqueado=1
        elif [ "$(_gr_situacao)" != nao-encaixa ]; then
          mudou=1
        fi
      fi
    else
      meow_info "o portal $ver ainda não tem build da casa — o do pacote segue valendo"
    fi
  fi

  _gr_ligar_portal; rc=$?
  case "$rc" in 1) mudou=1 ;; 2) return "$MEOW_ERRO" ;; 3) bloqueado=1 ;; esac
  _gr_policy_aplicar; rc=$?
  case "$rc" in 1) mudou=1 ;; 2) return "$MEOW_ERRO" ;; 3) bloqueado=1 ;; esac

  local q esperado
  esperado="$(_gr_esperado)"
  if [ -n "$esperado" ] && q="$(_gr_quedas_do "$esperado" "$(( $(date +%s) - GR_JANELA_QUEDAS ))")" && [ "${q:-0}" -gt 0 ]; then
    meow_info "$esperado caiu $q vez(es) nas últimas 24 h com a assinatura medida"
  fi

  if [ "$mudou" = 1 ]; then
    return "$MEOW_DIVERGENTE"
  fi
  if [ "$bloqueado" = 1 ]; then
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  _gr_valido "$ver" && ! _gr_ruim "$ver" || return "$MEOW_OK"
  if _gr_chrome_instalado; then
    meow_ok "aprimoramentos gráficos em dia: portal $ver, shim, drop-in e policy"
  else
    meow_ok "aprimoramentos gráficos em dia: portal $ver, shim e drop-in"
  fi
  return "$MEOW_OK"
}

cmd_reverter() {
  local mudou=0 rc
  _gr_tirar_portal; rc=$?; [ "$rc" = 1 ] && mudou=1
  _gr_policy_tirar; rc=$?
  case "$rc" in 1) mudou=1 ;; 2) return "$MEOW_ERRO" ;; 3) return "$MEOW_SEM_DEPENDENCIA" ;; esac
  if [ "$mudou" = 1 ]; then
    meow_seco || meow_muda "o portal e a policy voltaram ao estado do pacote"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "o portal e a policy já estão como o pacote deixa"
  return "$MEOW_OK"
}

cmd_estado() {
  local ver policy=nao
  ver="$(_gr_versao)"
  if _gr_chrome_instalado; then
    _gr_policy_igual && policy=sim
  else
    policy=sem-chrome
  fi
  printf 'versao=%s\nestado=%s\nbuild=%s\nshim=%s\ndropin=%s\npolicy=%s\nruim=%s\n' \
    "$ver" "$(_gr_situacao)" \
    "$([ -n "$ver" ] && _gr_valido "$ver" && echo sim || echo nao)" \
    "$([ -e "$GR_SHIM" ] && _gr_shim_nosso "$GR_SHIM" && echo sim || echo nao)" \
    "$([ -e "$GR_DROPIN" ] && _gr_dropin_nosso && echo sim || echo nao)" \
    "$policy" \
    "$([ -n "$ver" ] && _gr_ruim "$ver" && echo sim || echo nao)"
  return "$MEOW_OK"
}

case "${1:-aplicar}" in
  aplicar)             cmd_aplicar ;;
  --conferir|conferir) MEOW_SECO=1; cmd_aplicar ;;
  reverter)            cmd_reverter ;;
  compilar)            cmd_compilar ;;
  validar)             cmd_validar ;;
  cuidar)              cmd_cuidar ;;
  pendente)            _gr_quer && _gr_pendente; exit 0 ;;
  estado)              cmd_estado ;;
  *) meow_erro "uso: graficos.sh [aplicar|conferir|reverter|compilar|validar|cuidar|pendente|estado]"; exit "$MEOW_ERRO" ;;
esac

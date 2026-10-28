#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
COSMIC="$(meow_cosmic_dir)"
LOGOS_DIR="$COSMIC/logos"
TK="$COSMIC/com.system76.CosmicTk/$(meow_cosmic_v com.system76.CosmicTk)"

BOTOES=(com.system76.CosmicPanelAppButton com.system76.CosmicAppLibrary)

FLAVOR="$(meow_flavor)"
LOGO="${LOGO:-$FLAVOR}"
ICONES_BASE="${ICONES_BASE:-Papirus-Dark}"
TEMA_BASE="$TEMA_NOME-Base"
BASE_DIR="$HOME/.local/share/icons/$TEMA_BASE"
HERDA="$ICONES_BASE"
HERDA_ATRAS=""
COMENTARIO_TEMA="$(python3 "$RAIZ/scripts/pack.py" tema-icones "$(meow_pack_dir)" "$FLAVOR" 2>/dev/null \
                     | sed -n 's/^comentario=//p')"
[ -n "$COMENTARIO_TEMA" ] || COMENTARIO_TEMA="MeowSystem $FLAVOR para o COSMIC"

_ci_nome_seguro() {
  local n="$1"
  n="${n//[^A-Za-z0-9._-]/-}"
  n="${n#"${n%%[!.-]*}"}"
  printf '%s' "${n:0:80}"
}

_ci_nome_recusado() {
  case "$1" in
    "$TEMA_NOME") meow_erro "'$1' é o tema que este script constrói — recusado"; return 0 ;;
    "$TEMA_BASE"|"$TEMA_BASE"-[0-9]*) meow_erro "'$1' é a base que o pack traz, e quem a põe e a tira é o 'construir_icones.sh base' — recusado"; return 0 ;;
    hicolor)      meow_erro "'hicolor' é a hierarquia de reserva do sistema, não um tema — recusado"; return 0 ;;
    default)      meow_erro "'default' é o tema de ponteiro do compositor — recusado"; return 0 ;;
  esac
  return 1
}

_ci_e_tema_de_icones() {
  [ -f "$1/index.theme" ] && grep -qiE '^[[:space:]]*Directories[[:space:]]*=[[:space:]]*[^[:space:]]' "$1/index.theme"
}

_ci_instalar_tema() {
  local origem="$1" nome destino palco
  nome="$(_ci_nome_seguro "$(basename -- "$origem")")"
  [ -n "$nome" ] || { meow_erro "nome de tema vazio dentro do pacote"; return "$MEOW_ERRO"; }
  _ci_nome_recusado "$nome" && return "$MEOW_ERRO"
  destino="$HOME/.local/share/icons/$nome"
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"

  if [ -d "$destino" ]; then
    if meow_tem diff; then
      if diff -rq -- "$origem" "$destino" >/dev/null 2>&1; then
        meow_ok "o tema de ícones '$nome' já está instalado e idêntico"
        return "$MEOW_OK"
      fi
      meow_info "'$nome' está no disco e difere do pacote — substituindo"
    else
      meow_ok "o tema de ícones '$nome' já está instalado (sem 'diff' para comparar)"
      return "$MEOW_OK"
    fi
  fi

  if meow_seco; then
    meow_muda "instalaria o tema de ícones '$nome' em $HOME/.local/share/icons"
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$HOME/.local/share/icons" || return "$MEOW_ERRO"
  palco="$(mktemp -d -p "$HOME/.local/share/icons" ".meow-tema.XXXXXX")" || return "$MEOW_ERRO"
  if ! cp -a -- "$origem/." "$palco/"; then
    rm -rf "$palco"; meow_erro "não consegui copiar o tema '$nome'"; return "$MEOW_ERRO"
  fi
  chmod 755 "$palco"
  meow_guardar_pasta "$destino"
  rm -rf "$destino"
  if ! mv -f "$palco" "$destino"; then
    rm -rf "$palco"; meow_erro "falha ao mover o tema para $destino"; return "$MEOW_ERRO"
  fi
  meow_manifesto_registrar "$destino/index.theme"
  meow_muda "tema de ícones '$nome' instalado em $destino"
  return "$MEOW_DIVERGENTE"
}

_ci_colher_temas() {
  find "$1" -maxdepth 3 -type f -name index.theme -print0 2>/dev/null
}

_ci_adicionar() {
  local alvo="${1:-}" rc="$MEOW_OK" achou=0 e d
  if [ -z "$alvo" ]; then
    meow_erro "uso: construir_icones.sh adicionar <pasta-ou-zip>"
    return "$MEOW_ERRO"
  fi

  if [ -d "$alvo" ]; then
    if _ci_e_tema_de_icones "$alvo"; then
      _ci_instalar_tema "$alvo"; return $?
    fi
    while IFS= read -r -d '' d; do
      d="$(dirname -- "$d")"
      _ci_e_tema_de_icones "$d" || continue
      _ci_instalar_tema "$d"; e=$?
      [ "$e" -ge 2 ] && return "$e"
      [ "$e" = "1" ] && rc="$MEOW_DIVERGENTE"
      achou=1
    done < <(_ci_colher_temas "$alvo")
    [ "$achou" = "1" ] || {
      meow_erro "'$alvo' não tem um index.theme com 'Directories=' — não é tema de ícones"
      meow_info "  um ícone avulso entra pelo «Adicionar ícone» da ficha de ícone"
      return "$MEOW_ERRO"; }
    meow_registrar "construir_icones.sh adicionar '$alvo'"
    return "$rc"
  fi

  [ -f "$alvo" ] || { meow_erro "não achei '$alvo'"; return "$MEOW_ERRO"; }
  case "$alvo" in
    *.zip|*.ZIP) : ;;
    *) meow_erro "só sei abrir .zip aqui (ou uma pasta de tema já aberta)"
       return "$MEOW_ERRO" ;;
  esac

  if meow_seco; then
    local palpite; palpite="$(_ci_nome_seguro "$(basename -- "${alvo%.*}")")"
    if [ -n "$palpite" ] && [ -d "$HOME/.local/share/icons/$palpite" ]; then
      meow_ok "o tema de ícones '$palpite' já está instalado"
      return "$MEOW_OK"
    fi
    meow_muda "instalaria um tema de ícones de '$alvo' em $HOME/.local/share/icons"
    meow_info "  no seco o nome é palpite pelo arquivo; quem decide é o conteúdo do pacote"
    return "$MEOW_DIVERGENTE"
  fi

  meow_tem unzip || { meow_erro "falta unzip"; return "$MEOW_SEM_DEPENDENCIA"; }
  local tmp
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-tema-add.XXXXXX")" || return "$MEOW_ERRO"
  if ! unzip -q -o -- "$alvo" -d "$tmp/x" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o zip veio corrompido — nada instalado"; return "$MEOW_ERRO"
  fi
  while IFS= read -r -d '' d; do
    d="$(dirname -- "$d")"
    _ci_e_tema_de_icones "$d" || continue
    _ci_instalar_tema "$d"; e=$?
    if [ "$e" -ge 2 ]; then rm -rf "$tmp"; return "$e"; fi
    [ "$e" = "1" ] && rc="$MEOW_DIVERGENTE"
    achou=1
  done < <(_ci_colher_temas "$tmp/x")
  rm -rf "$tmp"

  if [ "$achou" = "0" ]; then
    meow_erro "o pacote não tem um index.theme com 'Directories=' — não é tema de ícones"
    meow_info "  um ícone avulso entra pelo «Adicionar ícone» da ficha de ícone"
    return "$MEOW_ERRO"
  fi
  meow_registrar "construir_icones.sh adicionar '$alvo'"
  return "$rc"
}

_ci_remover() {
  local nome; nome="$(_ci_nome_seguro "${1:-}")"
  [ -n "$nome" ] || { meow_erro "uso: construir_icones.sh remover <nome>"; return "$MEOW_ERRO"; }
  _ci_nome_recusado "$nome" && return "$MEOW_ERRO"
  local dir="$HOME/.local/share/icons/$nome"
  if [ ! -d "$dir" ]; then
    meow_pula "'$nome' não está em $HOME/.local/share/icons — nada a remover"
    return "$MEOW_OK"
  fi
  meow_destino_permitido "$dir" || return "$MEOW_ERRO"
  if meow_seco; then
    meow_muda "removeria $dir"; return "$MEOW_DIVERGENTE"
  fi
  rm -rf "$dir" || { meow_erro "não consegui remover $dir"; return "$MEOW_ERRO"; }
  meow_muda "tema de ícones '$nome' removido de $HOME/.local/share/icons"
  [ "$nome" = "$ICONES_BASE" ] && \
    meow_aviso "esse era o ICONES_BASE — troque a chave antes do próximo 'meow aplicar'"
  meow_registrar "construir_icones.sh remover $nome"
  return "$MEOW_DIVERGENTE"
}

_ci_links_fora() {
  local dir; dir="$(realpath -m -- "$1")"
  find "$dir" -type l -print0 2>/dev/null | xargs -0 -r realpath -m -- 2>/dev/null \
    | grep -v -e "^$dir/" -e "^$dir\$" || true
}

_ci_base_esconder() {
  if awk '/^\[/{sec=$0} sec=="[Icon Theme]" && $0=="Hidden=true"{achou=1} END{exit !achou}' \
       "$BASE_DIR/index.theme" 2>/dev/null; then
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "esconderia dos seletores a base em $BASE_DIR (Hidden=true)"
    return "$MEOW_DIVERGENTE"
  fi
  meow_tema_base_escondida "$BASE_DIR"
  case $? in
    0) return "$MEOW_OK" ;;
    1) meow_muda "a base em $BASE_DIR saiu dos seletores de tema (Hidden=true)"
       return "$MEOW_DIVERGENTE" ;;
    *) meow_erro "não consegui esconder a base em $BASE_DIR"; return "$MEOW_ERRO" ;;
  esac
}

_ci_base_confere() {
  local links
  [ -f "$BASE_DIR/.meow-origem" ] && grep -qx "sha256=$1" "$BASE_DIR/.meow-origem" || return 1
  links="$(sed -n 's/^links=//p' "$BASE_DIR/.meow-origem")"
  [ "$(find "$BASE_DIR" -type l 2>/dev/null | wc -l)" = "${links:-x}" ] || return 1
  ( cd "$BASE_DIR" && sha256sum --status -c .meow-somas.sha256 ) 2>/dev/null
}

_ci_base_tirar() {
  [ -d "$BASE_DIR" ] || return "$MEOW_OK"
  if [ ! -f "$BASE_DIR/.meow-origem" ]; then
    meow_aviso "$BASE_DIR existe e não foi este script que o pôs lá — fica como está"
    return "$MEOW_OK"
  fi
  meow_destino_permitido "$BASE_DIR" || return "$MEOW_ERRO"
  if meow_seco; then
    meow_muda "removeria $BASE_DIR ($1)"
    return "$MEOW_DIVERGENTE"
  fi
  rm -rf "$BASE_DIR" || { meow_erro "não consegui remover $BASE_DIR"; return "$MEOW_ERRO"; }
  meow_muda "a base de ícones saiu de $BASE_DIR ($1)"
  return "$MEOW_DIVERGENTE"
}

_ci_base_baixar() {
  local url="$1" sha="$2" pasta="$3" pack="$4" palco src obtido fora f
  meow_destino_permitido "$BASE_DIR" || return "$MEOW_ERRO"
  if [ -d "$BASE_DIR" ] && [ ! -f "$BASE_DIR/.meow-origem" ]; then
    meow_aviso "$BASE_DIR existe e não foi este script que o pôs lá — não escrevo por cima"
    meow_info "  tire-o ou renomeie-o, e a base do pack $pack desce na passagem seguinte"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  for f in curl tar sha256sum realpath; do
    meow_tem "$f" || {
      meow_aviso "falta '$f' — a base de ícones do pack $pack fica para o próximo ciclo"
      return "$MEOW_SEM_DEPENDENCIA"; }
  done
  mkdir -p "$HOME/.local/share/icons" || return "$MEOW_ERRO"
  palco="$(mktemp -d -p "$HOME/.local/share/icons" ".meow-base.XXXXXX")" || return "$MEOW_ERRO"
  meow_info "baixando a base de ícones do pack $pack…"
  if ! curl -sSfL --proto '=https' --proto-redir '=https' --connect-timeout 15 \
       --max-time 600 --retry 3 --retry-delay 2 -o "$palco/pacote" "$url" 2>/dev/null; then
    rm -rf "$palco"
    meow_aviso "não consegui baixar a base de ícones do pack $pack (sem rede?) — fica para o próximo ciclo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! echo "$sha  $palco/pacote" | sha256sum --status -c - 2>/dev/null; then
    obtido="$(sha256sum "$palco/pacote" | cut -d' ' -f1)"
    rm -rf "$palco"
    meow_erro "sha256 da base de ícones não bate com o que o pack $pack pinou"
    meow_info "  esperado $sha"
    meow_info "  obtido   $obtido"
    return "$MEOW_ERRO"
  fi
  mkdir "$palco/x" || { rm -rf "$palco"; return "$MEOW_ERRO"; }
  if ! tar -xf "$palco/pacote" -C "$palco/x" 2>/dev/null; then
    rm -rf "$palco"; meow_erro "o pacote da base de ícones veio corrompido — nada instalado"
    return "$MEOW_ERRO"
  fi
  src="$palco/x/$pasta"
  local dentro resolvido parcial comp
  dentro="$(realpath -e -- "$palco/x")"
  resolvido="$(realpath -e -- "$src" 2>/dev/null)" || resolvido=""
  parcial="$palco/x"
  for comp in ${pasta//\// }; do
    parcial="$parcial/$comp"
    if [ -L "$parcial" ]; then resolvido=""; break; fi
  done
  case "$resolvido" in
    "$dentro"/*) : ;;
    *) rm -rf "$palco"
       meow_erro "a pasta '$pasta' do pacote da base do pack $pack é link, ou sai do pacote — nada instalado"
       return "$MEOW_ERRO" ;;
  esac
  if ! _ci_e_tema_de_icones "$src"; then
    rm -rf "$palco"
    meow_erro "o pacote não tem '$pasta' com um index.theme de tema de ícones — nada instalado"
    meow_info "  é o 'icones.base.origem.pasta' do pack $pack que diz onde o tema está"
    return "$MEOW_ERRO"
  fi
  fora="$(_ci_links_fora "$src")"
  if [ -n "$fora" ]; then
    rm -rf "$palco"
    meow_erro "a base do pack $pack tem link apontando para fora do tema — nada instalado"
    meow_info "  $(printf '%s\n' "$fora" | head -1)"
    return "$MEOW_ERRO"
  fi
  meow_tema_base_escondida "$src" >/dev/null
  [ "$?" -le 1 ] || { rm -rf "$palco"; meow_erro "não consegui esconder a base de ícones"; return "$MEOW_ERRO"; }
  if ! ( cd "$src" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum ) > "$palco/somas"; then
    rm -rf "$palco"; meow_erro "não consegui medir a base de ícones"; return "$MEOW_ERRO"
  fi
  mv -f "$palco/somas" "$src/.meow-somas.sha256" || { rm -rf "$palco"; return "$MEOW_ERRO"; }
  printf 'sha256=%s\nurl=%s\nlinks=%s\n' "$sha" "$url" "$(find "$src" -type l | wc -l)" > "$src/.meow-origem" \
    || { rm -rf "$palco"; return "$MEOW_ERRO"; }
  chmod 755 "$src"
  if [ -e "$BASE_DIR" ] || [ -L "$BASE_DIR" ]; then
    mv -f "$BASE_DIR" "$palco/antes" || {
      rm -rf "$palco"; meow_erro "não consegui tirar do lugar a base de antes, em $BASE_DIR"
      return "$MEOW_ERRO"; }
  fi
  if ! mv -f "$src" "$BASE_DIR"; then
    if [ -e "$palco/antes" ] || [ -L "$palco/antes" ]; then mv -f "$palco/antes" "$BASE_DIR"; fi
    rm -rf "$palco"; meow_erro "falha ao mover a base de ícones para $BASE_DIR"; return "$MEOW_ERRO"
  fi
  rm -rf "$palco"
  meow_manifesto_registrar "$BASE_DIR/index.theme"
  meow_muda "base de ícones do pack $pack instalada em $BASE_DIR"
  return "$MEOW_DIVERGENTE"
}

_ci_base_tirar_atras() {
  local desde="$1" porque="$2" d n rc pior="$MEOW_OK" BASE_DIR
  for d in "$HOME/.local/share/icons/$TEMA_BASE"-[0-9]*; do
    [ -d "$d" ] || continue
    n="${d##*-}"
    case "$n" in ''|*[!0-9]*) continue ;; esac
    [ "$n" -ge "$desde" ] || continue
    BASE_DIR="$d"
    _ci_base_tirar "$porque"; rc=$?
    [ "$rc" -gt "$pior" ] && pior="$rc"
  done
  return "$pior"
}

_ci_base_camadas() {
  local linhas="$1" pack="$2" url sha pasta n=1 rc pior="$MEOW_OK" BASE_DIR
  HERDA_ATRAS=""
  while IFS=$'\t' read -r url sha pasta; do
    [ -n "$url" ] || continue
    n=$((n + 1))
    BASE_DIR="$HOME/.local/share/icons/$TEMA_BASE-$n"
    if _ci_base_confere "$sha"; then
      HERDA_ATRAS="$HERDA_ATRAS,$TEMA_BASE-$n"
      _ci_base_esconder; rc=$?
      [ "$rc" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"
      [ "$rc" -gt "$pior" ] && pior="$rc"
      continue
    fi
    if meow_seco; then
      meow_muda "baixaria a camada $n da base de ícones do pack $pack e a instalaria em $BASE_DIR"
      HERDA_ATRAS="$HERDA_ATRAS,$TEMA_BASE-$n"; pior="$MEOW_DIVERGENTE"
      continue
    fi
    _ci_base_baixar "$url" "$sha" "$pasta" "$pack"; rc=$?
    case "$rc" in
      1) HERDA_ATRAS="$HERDA_ATRAS,$TEMA_BASE-$n"; pior="$MEOW_DIVERGENTE" ;;
      3)
         if [ -f "$BASE_DIR/.meow-origem" ] && _ci_e_tema_de_icones "$BASE_DIR"; then
           HERDA_ATRAS="$HERDA_ATRAS,$TEMA_BASE-$n"
         fi ;;
      *) return "$MEOW_ERRO" ;;
    esac
  done < <(printf '%s\n' "$linhas" | sed -n 's/^atras=//p')
  _ci_base_tirar_atras "$((n + 1))" "o pack $pack traz $((n - 1)) camada(s) por trás"; rc=$?
  [ "$rc" -gt "$pior" ] && pior="$rc"
  return "$pior"
}

_ci_base() {
  local saida quem tema pack url sha pasta rc rc_atras
  HERDA="$ICONES_BASE"
  HERDA_ATRAS=""
  meow_tem python3 || return "$MEOW_OK"
  if ! saida="$(ICONES_BASE="$ICONES_BASE" NOME_TEMA_ICONES="$TEMA_NOME" \
                python3 "$RAIZ/scripts/pack.py" base-icones "$(meow_pack_dir)")"; then
    meow_aviso "não deu para ler a base de ícones do pack — o '$TEMA_NOME' herda de '$ICONES_BASE', como antes"
    return "$MEOW_OK"
  fi
  quem="$(printf '%s\n' "$saida" | sed -n 's/^quem=//p')"
  tema="$(printf '%s\n' "$saida" | sed -n 's/^tema=//p')"
  pack="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  url="$(printf '%s\n' "$saida" | sed -n 's/^url=//p')"
  sha="$(printf '%s\n' "$saida" | sed -n 's/^sha256=//p')"
  pasta="$(printf '%s\n' "$saida" | sed -n 's/^pasta=//p')"

  if [ "$quem" != "pack" ]; then
    HERDA="${tema:-$ICONES_BASE}"
    [ "$quem" = "conf" ] && [ -n "$pack" ] && \
      meow_info "o pack $pack traz uma base de ícones; vale o ICONES_BASE=\"$tema\" do meow.conf"
    _ci_base_tirar "o '$TEMA_NOME' herda de '$HERDA'"; rc=$?
    _ci_base_tirar_atras 2 "o '$TEMA_NOME' herda de '$HERDA'"; rc_atras=$?
    [ "$rc_atras" -gt "$rc" ] && rc="$rc_atras"
    return "$rc"
  fi

  _ci_base_camadas "$saida" "$pack"; rc_atras=$?
  [ "$rc_atras" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"

  if _ci_base_confere "$sha"; then
    meow_ok "a base de ícones do pack $pack está em $BASE_DIR e confere"
    HERDA="$TEMA_BASE"
    _ci_base_esconder; rc=$?
    [ "$rc" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"
    [ "$rc" -gt "$rc_atras" ] && rc_atras="$rc"
    return "$rc_atras"
  fi
  if meow_seco; then
    meow_muda "baixaria a base de ícones do pack $pack e a instalaria em $BASE_DIR"
    HERDA="$TEMA_BASE"
    return "$MEOW_DIVERGENTE"
  fi
  _ci_base_baixar "$url" "$sha" "$pasta" "$pack"; rc=$?
  case "$rc" in
    1) HERDA="$TEMA_BASE"; return "$MEOW_DIVERGENTE" ;;
    3)
       if [ -f "$BASE_DIR/.meow-origem" ] && _ci_e_tema_de_icones "$BASE_DIR"; then
         HERDA="$TEMA_BASE"
         meow_info "  fica a base que já estava em $BASE_DIR"
       else
         meow_info "  até lá o '$TEMA_NOME' herda de '$ICONES_BASE'"
       fi
       return "$rc_atras" ;;
    *) return "$MEOW_ERRO" ;;
  esac
}

_ci_base_cmd() {
  local rc
  _ci_base; rc=$?
  meow_info "o '$TEMA_NOME' herda de '$HERDA$HERDA_ATRAS'"
  return "$rc"
}

CAUDA_HERANCA="breeze-dark,Cosmic,Adwaita,hicolor"

_ci_indice_cmd() {
  local rc=0 cache="$TEMA_DIR/icon-theme.cache" herda
  if [ ! -f "$TEMA_DIR/index.theme" ]; then
    meow_pula "o tema '$TEMA_NOME' ainda não tem índice — quem o escreve primeiro é a construção"
    return "$MEOW_OK"
  fi
  herda="$(sed -n 's/^Inherits=//p' "$TEMA_DIR/index.theme" | head -1)"
  HERDA="${herda%",$CAUDA_HERANCA"}"; HERDA_ATRAS=""
  [ -n "$HERDA" ] || HERDA="$ICONES_BASE"
  meow_escrever "$TEMA_DIR/index.theme" "$(indice)" 644
  case $? in
    1) rc="$MEOW_DIVERGENTE" ;;
    2) meow_erro "não consegui escrever o index.theme"; return "$MEOW_ERRO" ;;
  esac
  if [ -f "$cache" ] && [ -n "$(find "$TEMA_DIR" -newer "$cache" -print -quit 2>/dev/null)" ]; then
    if meow_seco; then
      meow_muda "reindexaria a cache do tema (ela é mais velha que algum arquivo dele)"
      rc="$MEOW_DIVERGENTE"
    elif meow_tem gtk-update-icon-cache && gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null; then
      rc="$MEOW_DIVERGENTE"
    else
      meow_aviso "não consegui reindexar $cache — apague-a se algum ícone não aparecer"
    fi
  fi
  [ "$rc" = "$MEOW_OK" ] && meow_ok "índice do '$TEMA_NOME' descreve o disco"
  [ "$rc" = "$MEOW_DIVERGENTE" ] && ! meow_seco && meow_muda "índice do '$TEMA_NOME' refeito do disco"
  return "$rc"
}

case "${1:-}" in
  "")        : ;;
  adicionar) _ci_adicionar "${2:-}"; exit $? ;;
  remover)   _ci_remover   "${2:-}"; exit $? ;;
  base)      _ci_base_cmd;           exit $? ;;
  indice)    : ;;
  *)
    meow_erro "argumento desconhecido: $1"
    meow_info "  uso: construir_icones.sh [adicionar <pasta-ou-zip> | remover <nome> | base | indice]"
    meow_info "  sem argumento, ele constrói o tema '$TEMA_NOME'"
    exit "$MEOW_ERRO" ;;
esac

places_no_disco() {
  local d tam
  for d in "$TEMA_DIR"/*/places; do
    [ -d "$d" ] || continue
    tam="$(basename "${d%/places}")"
    case "$tam" in
      [0-9]*x[0-9]*|scalable) printf '%s\n' "$tam" ;;
    esac
  done
}

tem_mimetypes() { [ -d "$TEMA_DIR/scalable/mimetypes" ]; }

tem_apps_png() { [ -d "$TEMA_DIR/512x512/apps" ]; }

apps_no_disco() {
  local d tam
  for d in "$TEMA_DIR"/*/apps; do
    [ -d "$d" ] || continue
    tam="$(basename "${d%/apps}")"
    case "$tam" in
      512x512|scalable) continue ;;
      [0-9]*x[0-9]*) printf '%s\n' "$tam" ;;
    esac
  done | sort -t x -k1,1n
}

tem_apps_traco() { [ -d "$TEMA_DIR/48x48/apps" ]; }

contexto_no_disco() {
  local ctx="$1" d tam
  for d in "$TEMA_DIR"/*/"$ctx"; do
    [ -d "$d" ] || continue
    tam="$(basename "${d%/"$ctx"}")"
    case "$tam" in
      [0-9]*x[0-9]*|scalable) printf '%s\n' "$tam" ;;
    esac
  done
}

indice() {
  local dirs="" tam ctx contexto
  while IFS= read -r tam; do [ -n "$tam" ] && dirs="$dirs$tam/apps,"; done < <(apps_no_disco)
  tem_apps_png && dirs="${dirs}512x512/apps,"
  dirs="${dirs}scalable/apps"
  tem_mimetypes && dirs="$dirs,scalable/mimetypes"
  for ctx in status actions devices; do
    while IFS= read -r tam; do dirs="$dirs,$tam/$ctx"; done < <(contexto_no_disco "$ctx")
  done
  while IFS= read -r tam; do dirs="$dirs,$tam/places"; done < <(places_no_disco)

  cat <<FIM
[Icon Theme]
Name=$TEMA_NOME
Comment=$COMENTARIO_TEMA
Inherits=$HERDA$HERDA_ATRAS,$CAUDA_HERANCA
Directories=$dirs

[scalable/apps]
Size=128
Context=Applications
Type=Scalable
MinSize=8
MaxSize=512
FIM

  while IFS= read -r tam; do
    [ -n "$tam" ] || continue
    cat <<FIM

[$tam/apps]
Size=${tam%%x*}
Context=Applications
Type=Fixed
FIM
  done < <(apps_no_disco)

  if tem_apps_png; then
    cat <<'FIM'

[512x512/apps]
Size=512
Context=Applications
Type=Fixed
FIM
  fi

  if tem_mimetypes; then
    cat <<'FIM'

[scalable/mimetypes]
Size=64
Context=MimeTypes
Type=Scalable
MinSize=8
MaxSize=512
FIM
  fi

  for ctx in status actions devices; do
    contexto="${ctx^}"
    while IFS= read -r tam; do
      if [ "$tam" = scalable ]; then
        cat <<FIM

[scalable/$ctx]
Size=48
Context=$contexto
Type=Scalable
MinSize=8
MaxSize=512
FIM
      else
        cat <<FIM

[$tam/$ctx]
Size=${tam%%x*}
Context=$contexto
Type=Fixed
FIM
      fi
    done < <(contexto_no_disco "$ctx")
  done

  while IFS= read -r tam; do
    if [ "$tam" = scalable ]; then
      cat <<FIM

[scalable/places]
Size=48
Context=Places
Type=Scalable
MinSize=8
MaxSize=512
FIM
    else
      cat <<FIM

[$tam/places]
Size=${tam%%x*}
Context=Places
Type=Fixed
FIM
    fi
  done < <(places_no_disco)
}

if [ "${1:-}" = "indice" ]; then
  _ci_indice_cmd
  exit $?
fi

mudou=0

_ci_base
case $? in
  1) mudou=1 ;;
  2) meow_erro "a base de ícones do pack não entrou — o tema '$TEMA_NOME' fica como estava"
     exit "$MEOW_ERRO" ;;
esac

meow_escrever "$TEMA_DIR/index.theme" "$(indice)" 644
case $? in 1) mudou=1 ;; 2) meow_erro "não consegui escrever o index.theme"; exit "$MEOW_ERRO" ;; esac

GATO_PISO=""
if [ -d "$(meow_mascote_dir)/" ]; then
  GATO_PISO="$(find "$(meow_mascote_dir)/" -maxdepth 1 -name '*.svg' \
                 ! -name '*-symbolic.svg' | sort | head -n1)"
fi
if [ -n "$GATO_PISO" ]; then
  for nome in "${BOTOES[@]}"; do
    [ -f "$TEMA_DIR/scalable/apps/$nome.svg" ] && continue
    meow_escrever "$TEMA_DIR/scalable/apps/$nome.svg" "$(cat "$GATO_PISO")" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao instalar $nome"; exit "$MEOW_ERRO" ;; esac
  done
fi

tema_mudou_de_nome=0
[ "$(cat "$TK/icon_theme" 2>/dev/null)" = "\"$TEMA_NOME\"" ] || tema_mudou_de_nome=1
meow_escrever "$TK/icon_theme" "\"$TEMA_NOME\"" 644
case $? in 1) mudou=1 ;; esac

if [ "$mudou" = "0" ]; then
  meow_ok "ícones e logo já no lugar"
  exit "$MEOW_OK"
fi

if meow_seco; then
  exit "$MEOW_DIVERGENTE"
fi

precisa_reiniciar=0
[ "$tema_mudou_de_nome" = "1" ] && precisa_reiniciar=1

_ci_home_e_da_sessao() {
  local dono
  dono="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)"
  [ -n "$dono" ] && [ "$HOME" = "$dono" ]
}
_ci_espera_do_supervisor() {
  journalctl --user -b -t cosmic-session --no-pager 2>/dev/null \
    | grep -oE 'sleeping for [0-9]+ms before restarting process cosmic-panel' \
    | tail -1 | grep -oE '[0-9]+'
}

if [ "$precisa_reiniciar" = "1" ] && ! _ci_home_e_da_sessao; then
  meow_aviso "HOME de teste ($HOME): não reinicio o painel da sessão real"
  meow_info  "  o pkill não conhece HOME — mataria a barra de quem está usando a máquina"
  precisa_reiniciar=0
fi

if [ "$precisa_reiniciar" = "1" ]; then
  _ci_espera="$(_ci_espera_do_supervisor)"
  case "$_ci_espera" in
    ''|*[!0-9]*) : ;;
    *)
      if [ "$_ci_espera" -gt 5000 ]; then
        meow_aviso "não vou reiniciar o painel: o cosmic-session dormiria $(( _ci_espera / 60000 ))min antes de trazê-lo de volta"
        meow_info  "  os ícones novos aparecem no próximo login, que é quando o contador zera"
        meow_info  "  (o backoff é 2^restarts x sorteio(0..9) ms, sem teto e sem zerar por sucesso)"
        precisa_reiniciar=0
      fi
      ;;
  esac
fi

if [ "$precisa_reiniciar" = "0" ]; then
  meow_ok "tema '$TEMA_NOME' atualizado (os ícones novos aparecem no próximo login)"
  exit "$MEOW_DIVERGENTE"
fi

_ci_reler=0
meow_tela_reler || _ci_reler=$?
if [ "$_ci_reler" = 1 ]; then
  meow_erro "não consegui reciclar o painel — os ícones novos aparecem no próximo login"
  exit "$MEOW_ERRO"
fi

meow_ok "tema '$TEMA_NOME' instalado e ativo"
exit "$MEOW_DIVERGENTE"

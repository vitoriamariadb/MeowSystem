#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

PINOS_CASA="${EXTENSOES_PINOS:-$RAIZ/assets/extensoes}"
BASE="$MEOW_ESTADO/extensoes"
PINOS_USUARIO="$BASE/usuario"
COMPILAR="${EXTENSOES_COMPILAR:-0}"

BINDIR="$HOME/.local/bin"
DADOS="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS="$DADOS/applications"
HICOLOR="$DADOS/icons/hicolor"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
ESTADO_COSMIC="$HOME/.local/state/cosmic"

. "$RAIZ/scripts/applet_pino.sh"

PINO_CHAVES=" ORDEM NOME DESCRICAO URL COMMIT VERSAO LIBCOSMIC APP_ID BIN DESKTOP ICONES SUBSTITUI LEGADO MIGRA_ESTADO TEMA UPSTREAM "

ID=""; CASA=0
ESTADO=""; ARVORE=""; ALVO=""; CARIMBO=""; BINARIO=""; SOMBRA=""

_sha() { sha256sum -- "$1" 2>/dev/null | cut -d' ' -f1; }

_rustc_versao() {
  meow_seco && return 0
  meow_tem rustc || return 0
  rustc -V 2>/dev/null
}

_pino_ler() {
  local arquivo="$1" linha chave valor
  for chave in $PINO_CHAVES; do printf -v "P_$chave" '%s' ''; done
  [ -f "$arquivo" ] || return 1
  while IFS= read -r linha || [ -n "$linha" ]; do
    case "$linha" in ''|'#'*) continue ;; esac
    chave="${linha%%=*}"; valor="${linha#*=}"
    case "$PINO_CHAVES" in *" $chave "*) ;; *) continue ;; esac
    valor="${valor#\"}"; valor="${valor%\"}"
    printf -v "P_$chave" '%s' "$valor"
  done < "$arquivo"
  _pino_valido
}

_pino_valido() {
  local alvo restante par
  [[ "$P_COMMIT" =~ ^[0-9a-f]{7,40}$ ]] || return 1
  [[ "$P_APP_ID" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  [[ "$P_BIN" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  if [ "${EXTENSOES_PERMITE_LOCAL:-0}" = 1 ]; then
    [[ "$P_URL" =~ ^(https://|/)[A-Za-z0-9._~/%:@+-]+$ ]] || return 1
  else
    [[ "$P_URL" =~ ^https://[A-Za-z0-9._~/%:@+-]+$ ]] || return 1
  fi
  [ -z "$P_LIBCOSMIC" ] || [[ "$P_LIBCOSMIC" =~ ^[0-9a-f]{7,40}$ ]] || return 1
  for restante in "$P_DESKTOP" $P_ICONES; do
    alvo="${restante%%:*}"
    [[ "$alvo" =~ ^[A-Za-z0-9._@-][A-Za-z0-9._@/-]*$ ]] || return 1
    case "/$alvo/" in */../*) return 1 ;; esac
  done
  for par in $P_ICONES; do
    case "$par" in *:*) ;; *) return 1 ;; esac
    alvo="${par#*:}"
    [[ "$alvo" =~ ^[A-Za-z0-9._-][A-Za-z0-9._/-]*$ ]] || return 1
    case "/$alvo/" in */../*) return 1 ;; esac
  done
  for par in $P_SUBSTITUI; do [[ "$par" =~ ^[A-Za-z0-9._-]+$ ]] || return 1; done
  for par in $P_LEGADO; do [[ "$par" =~ ^[A-Za-z0-9._-]+:[A-Za-z0-9._-]+$ ]] || return 1; done
  [ -z "$P_MIGRA_ESTADO" ] || [[ "$P_MIGRA_ESTADO" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  [ -z "$P_TEMA" ] || [[ "$P_TEMA" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  return 0
}

_ids_da_casa() {
  local f
  for f in "$PINOS_CASA"/*.pino; do
    [ -f "$f" ] || continue
    _pino_ler "$f" || continue
    printf '%s\t%s\n' "${P_ORDEM:-99}" "$(basename "$f" .pino)"
  done | sort -n | cut -f2
}

_carregar() {
  local id="$1"
  [[ "$id" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { meow_erro "nome de extensão inválido: $id"; return "$MEOW_ERRO"; }
  if [ -f "$PINOS_CASA/$id.pino" ]; then
    CASA=1; _pino_ler "$PINOS_CASA/$id.pino" || { meow_erro "o pino de $id está malformado"; return "$MEOW_ERRO"; }
  elif [ -f "$PINOS_USUARIO/$id.pino" ]; then
    CASA=0; _pino_ler "$PINOS_USUARIO/$id.pino" || { meow_erro "o pino de $id está malformado"; return "$MEOW_ERRO"; }
  else
    meow_erro "não conheço a extensão $id"
    return "$MEOW_ERRO"
  fi
  ID="$id"
  ESTADO="$BASE/$id"
  ARVORE="$ESTADO/src"
  ALVO="$ESTADO/target"
  CARIMBO="$ESTADO/carimbo"
  BINARIO="$BINDIR/$P_BIN"
  SOMBRA="$APPS/$P_APP_ID.desktop"
  return "$MEOW_OK"
}

_nome() { printf '%s' "${P_NOME:-$ID}"; }

_alvo_rev() { [ -n "$P_LIBCOSMIC" ] && ap_alvo "$ID" "$P_LIBCOSMIC"; }

_painel_dir() { printf '%s/cosmic/com.system76.CosmicPanel.Panel/%s' "$CONFIG" "$(meow_cosmic_v com.system76.CosmicPanel.Panel)"; }

_painel_cita() {
  local dir arq
  for dir in "$CONFIG"/cosmic/com.system76.CosmicPanel.Panel "$CONFIG"/cosmic/com.system76.CosmicPanel.Dock; do
    for arq in "$dir"/v*/plugins_wings "$dir"/v*/plugins_center; do
      [ -f "$arq" ] && grep -qs "\"$1\"" "$arq" && return 0
    done
  done
  return 1
}

_quer() {
  local lista="${EXTENSOES:-}" id="$1"
  lista="${lista//,/ }"
  if [ -z "$lista" ]; then
    case "$id" in
      now-playing) [ "${MIDIA:-sim}" = sim ] ;;
      leitura)     [ "${LEITURA_APPLET:-sim}" = sim ] ;;
      *) return 1 ;;
    esac
    return
  fi
  case " $lista " in *" $id "*) return 0 ;; esac
  return 1
}

_texto_sombra() {
  local origem="$ARVORE/$P_DESKTOP"
  [ -f "$origem" ] || return 1
  sed -e "s|@bindir@|$BINDIR|g" -e "s|^Exec=\([^/ ][^ ]*\)|Exec=$BINDIR/\1|" "$origem"
}

_icones_pares() {
  local par origem destino f
  for par in $P_ICONES; do
    origem="${par%%:*}"; destino="${par#*:}"
    if [ -d "$ARVORE/$origem" ]; then
      while IFS= read -r f; do
        f="${f#"$ARVORE/$origem/"}"
        if [ "$destino" = . ]; then printf '%s\t%s\n' "$origem/$f" "$HICOLOR/$f"
        else printf '%s\t%s\n' "$origem/$f" "$HICOLOR/$destino/$f"; fi
      done < <(find "$ARVORE/$origem" -type f \( -name '*.svg' -o -name '*.png' \) | sort)
    elif [ -f "$ARVORE/$origem" ]; then
      printf '%s\t%s\n' "$origem" "$HICOLOR/$destino/$(basename "$origem")"
    fi
  done
}

_sha_icones() {
  local f saida=""
  [ -f "$ESTADO/icones.lista" ] || { printf -- '-'; return; }
  while IFS= read -r f; do saida="$saida$(_sha "$f")"; done < "$ESTADO/icones.lista"
  printf '%s' "$saida" | sha256sum | cut -d' ' -f1
}

_carimbo_vivo() {
  local alvo
  printf 'commit %s\nicones %s\nbinario %s\nrustc %s\n' \
    "$P_COMMIT" "$(_sha_icones)" "$(_sha "$BINARIO")" "$(_rustc_versao)"
  if alvo="$(_alvo_rev)" && [ -n "$alvo" ] && [ "$alvo" != "$P_LIBCOSMIC" ]; then
    printf 'libcosmic %s\n' "$alvo"
  fi
}

_carimbo_bate() {
  [ -f "$CARIMBO" ] || return 1
  local campo vivo gravado
  while read -r campo vivo; do
    [ -z "$vivo" ] && continue
    gravado="$(sed -n "s/^$campo //p" "$CARIMBO" | head -1)"
    [ "$gravado" = "$vivo" ] || return 1
  done <<< "$(_carimbo_vivo)"
  return 0
}

_legado_sobra() {
  local par id bin
  for par in $P_LEGADO; do
    id="${par%%:*}"; bin="${par#*:}"
    [ -f "$APPS/$id.desktop" ] || [ -e "$BINDIR/$bin" ] || continue
    _painel_cita "$id" && continue
    grep -qs "^Exec=$BINDIR/$bin" "$APPS/$id.desktop" 2>/dev/null || [ ! -f "$APPS/$id.desktop" ] || continue
    return 0
  done
  return 1
}

_legado_limpar() {
  local par id bin mexeu=1
  for par in $P_LEGADO; do
    id="${par%%:*}"; bin="${par#*:}"
    [ -f "$APPS/$id.desktop" ] || [ -e "$BINDIR/$bin" ] || continue
    if _painel_cita "$id"; then
      meow_info "a barra ainda cita $id — o antigo fica até a troca (a ordem dos applets é de quem usa)"
      continue
    fi
    if [ -f "$APPS/$id.desktop" ] && ! grep -qs "^Exec=$BINDIR/$bin" "$APPS/$id.desktop"; then
      continue
    fi
    rm -f "$APPS/$id.desktop" "$BINDIR/$bin" && mexeu=0
    meow_muda "o applet antigo ($id) saiu: a barra já não o cita"
  done
  return "$mexeu"
}

_nucleo() {
  local esperada
  if [ ! -x "$BINARIO" ]; then
    NUCLEO_MOTIVO="$(_nome) ainda não foi compilado ($BINARIO)"
    return 1
  fi
  if ! _carimbo_bate; then
    NUCLEO_MOTIVO="$(_nome) instalado não é o do pino (commit, ícones ou rustc mudaram)"
    return 1
  fi
  esperada="$(cat "$ESTADO/sombra.esperada" 2>/dev/null)"
  if [ -z "$esperada" ] || [ ! -f "$SOMBRA" ] || [ "$esperada" != "$(cat "$SOMBRA" 2>/dev/null)" ]; then
    NUCLEO_MOTIVO="a sombra de $(_nome) não está no lugar ($SOMBRA)"
    return 1
  fi
  return 0
}

_conferir() {
  if ! _nucleo; then
    meow_muda "$NUCLEO_MOTIVO"
    return "$MEOW_DIVERGENTE"
  fi
  if _legado_sobra; then
    meow_muda "o applet antigo de $(_nome) sobrou, e a barra já não o cita"
    return "$MEOW_DIVERGENTE"
  fi
  if ! _painel_cita "$P_APP_ID"; then
    meow_info "$(_nome) está instalado, e a barra não o cita (a ordem dos applets é de quem usa)"
  fi
  meow_ok "$(_nome) $(_sha "$BINARIO" | cut -c1-8) já é o do pino"
  return "$MEOW_OK"
}

_arvore_no_pino() {
  local origem
  if [ -d "$ARVORE/.git" ]; then
    origem="$(git -C "$ARVORE" remote get-url origin 2>/dev/null)"
    [ "$origem" = "$P_URL" ] || rm -rf "$ARVORE"
  fi
  if [ ! -d "$ARVORE/.git" ]; then
    rm -rf "$ARVORE"
    mkdir -p "$(dirname "$ARVORE")" || return "$MEOW_ERRO"
    git clone -q "$P_URL" "$ARVORE" 2>"$ESTADO/clone.log" || {
      meow_aviso "não consegui clonar $P_URL (sem rede?) — fica para o próximo ciclo"
      return "$MEOW_SEM_DEPENDENCIA"
    }
  fi
  git -C "$ARVORE" checkout -q -- . 2>/dev/null
  if ! git -C "$ARVORE" checkout -q --detach "$P_COMMIT" 2>/dev/null; then
    git -C "$ARVORE" fetch -q origin 2>/dev/null
    git -C "$ARVORE" checkout -q --detach "$P_COMMIT" 2>/dev/null || {
      meow_erro "o commit $P_COMMIT não existe em $P_URL — confira o pino"
      return "$MEOW_ERRO"
    }
  fi
  return "$MEOW_OK"
}

_copiar() {
  local origem="$1" destino="$2" tmp
  meow_destino_permitido "$destino" || return 1
  cmp -s "$origem" "$destino" && return 0
  meow_guardar_antes "$destino"
  mkdir -p "$(dirname "$destino")" || return 1
  tmp="$(mktemp -p "$(dirname "$destino")" ".atomicwrite.meow.XXXXXX")" || return 1
  cp -- "$origem" "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$destino" || { rm -f "$tmp"; return 1; }
  meow_manifesto_registrar "$destino"
}

_instalar_arquivos() {
  local origem destino texto lista="" r
  texto="$(_texto_sombra)" || { meow_erro "o repositório não tem $P_DESKTOP"; return 1; }
  while IFS=$'\t' read -r origem destino; do
    [ -n "$destino" ] || continue
    _copiar "$ARVORE/$origem" "$destino" || { meow_erro "não consegui instalar $destino"; return 1; }
    lista="$lista$destino"$'\n'
  done < <(_icones_pares)
  printf '%s' "$lista" > "$ESTADO/icones.lista"
  meow_escrever "$SOMBRA" "$texto" 644; r=$?
  [ "$r" = 2 ] && { meow_erro "não consegui escrever $SOMBRA"; return 1; }
  printf '%s' "$texto" > "$ESTADO/sombra.esperada"
  return 0
}

_migrar_estado() {
  local de="$ESTADO_COSMIC/$P_MIGRA_ESTADO/v1" para="$ESTADO_COSMIC/$P_APP_ID/v1"
  [ -n "$P_MIGRA_ESTADO" ] && [ -d "$de" ] && [ ! -e "$para" ] || return 0
  mkdir -p "$ESTADO_COSMIC/$P_APP_ID" && cp -a "$de" "$para" \
    && meow_muda "o estado de $(_nome) veio de $P_MIGRA_ESTADO"
  return 0
}

_sem_cargo() {
  local pronto="$ALVO/release/$P_BIN" gravado
  meow_seco && return 1
  [ -f "$CARIMBO" ] && [ -d "$ARVORE/.git" ] || return 1
  gravado="$(sed -n 's/^commit //p' "$CARIMBO" | head -1)"
  [ "$gravado" = "$P_COMMIT" ] || return 1
  _carimbo_bate || return 1
  if [ ! -x "$BINARIO" ]; then
    [ -x "$pronto" ] || return 1
    [ "$(sed -n 's/^binario //p' "$CARIMBO" | head -1)" = "$(_sha "$pronto")" ] || return 1
    meow_destino_permitido "$BINARIO" || return 1
    _instalar_binario "$pronto" || return 1
    meow_muda "o binário de $(_nome) sumiu e a árvore de build ainda tinha o dele — reposto sem compilar"
  fi
  _instalar_arquivos || return 1
  _carimbo_vivo > "$CARIMBO.novo" && mv -f "$CARIMBO.novo" "$CARIMBO" || return 1
  _conferir >/dev/null 2>&1
}

_instalar_binario() {
  local recem="$1" tmp
  mkdir -p "$BINDIR" || return 1
  tmp="$(mktemp -p "$BINDIR" ".atomicwrite.meow.XXXXXX")" || return 1
  cp -- "$recem" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$BINARIO" || { rm -f "$tmp"; return 1; }
  strip "$BINARIO" 2>/dev/null
  meow_manifesto_registrar "$BINARIO"
}

_sombra_orfa() {
  [ -f "$SOMBRA" ] && [ ! -x "$BINARIO" ] || return 1
  if meow_seco; then
    meow_muda "removeria a sombra órfã de $(_nome) ($SOMBRA): a barra ficaria com um applet que não abre"
    return 0
  fi
  rm -f "$SOMBRA"
  meow_muda "a sombra de $(_nome) estava sem binário e saiu — a barra não fica com um applet que não abre"
  return 0
}

_aplicar() {
  local id_pend="extensao-$ID"
  if _nucleo; then
    if _legado_sobra; then
      _legado_limpar
      return "$MEOW_DIVERGENTE"
    fi
    meow_pendencia_resolvida "$id_pend"
    _conferir
    return $?
  fi

  if _sem_cargo; then
    meow_registrar "extensoes_build.sh $ID reconciliou sem compilar"
    _legado_limpar
    return "$MEOW_DIVERGENTE"
  fi

  _sombra_orfa

  if [ "$COMPILAR" != 1 ]; then
    meow_pendencia_acionavel "$id_pend" \
      "$(_nome) precisa ser compilado" "meow doctor --consertar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_garantir_cargo; then
    meow_pula "sem cargo, e o rust não pôde ser instalado agora — $(_nome) fica de fora"
    meow_pendencia_acionavel "$id_pend" \
      "$(_nome) precisa do rust, e a instalação dele não respondeu" "meow doctor --consertar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_destino_permitido "$BINARIO" || return "$MEOW_ERRO"
  mkdir -p "$ESTADO" || { meow_erro "não consegui criar $ESTADO"; return "$MEOW_ERRO"; }
  rm -f "$ESTADO/falhou"

  _arvore_no_pino
  case $? in
    2) : > "$ESTADO/falhou"; return "$MEOW_ERRO" ;;
    3) return "$MEOW_SEM_DEPENDENCIA" ;;
  esac

  meow_info "compilando $(_nome) (a primeira vez leva alguns minutos)"
  local alvo_rev="" compilou=0 log="$ESTADO/compilar.log"
  : > "$log"
  alvo_rev="$(_alvo_rev)"
  if [ -n "$alvo_rev" ] && [ "$alvo_rev" != "$P_LIBCOSMIC" ]; then
    meow_info "  contra o libcosmic do painel instalado (${alvo_rev:0:7})"
    sed -i "s/$P_LIBCOSMIC/$alvo_rev/g" "$ARVORE/Cargo.toml" 2>/dev/null
    if cargo update -q --manifest-path "$ARVORE/Cargo.toml" -p libcosmic --precise "$alvo_rev" >>"$log" 2>&1 \
       && CARGO_TARGET_DIR="$ALVO" cargo build --release \
            --manifest-path "$ARVORE/Cargo.toml" >>"$log" 2>&1; then
      compilou=1
    else
      ap_falhou "$ID" "$alvo_rev"
      git -C "$ARVORE" checkout -q -- . 2>/dev/null
      meow_aviso "$(_nome) não compila no libcosmic ${alvo_rev:0:7} do painel — volta ao pino ${P_LIBCOSMIC:0:7}"
    fi
  fi
  if [ "$compilou" = 0 ]; then
    : > "$log"
    if ! CARGO_TARGET_DIR="$ALVO" cargo build --release --locked \
          --manifest-path "$ARVORE/Cargo.toml" >>"$log" 2>&1; then
      : > "$ESTADO/falhou"
      meow_erro "o cargo falhou — $(meow_motivo_do_cargo "$log")"
      meow_info "  o registro está em $log"
      meow_info "  o binário anterior, se houver, segue instalado e funcionando; nada foi trocado"
      return "$MEOW_ERRO"
    fi
  fi

  local recem="$ALVO/release/$P_BIN"
  [ -x "$recem" ] || { : > "$ESTADO/falhou"; meow_erro "o cargo terminou e não deixou binário em $recem"; return "$MEOW_ERRO"; }

  _instalar_binario "$recem" || { meow_erro "não consegui instalar $BINARIO"; return "$MEOW_ERRO"; }
  _instalar_arquivos || return "$MEOW_ERRO"
  _migrar_estado

  if [ -n "$P_LIBCOSMIC" ]; then
    if [ "$compilou" = 1 ]; then ap_compilou "$ID" "$alvo_rev"; else ap_compilou "$ID" "$P_LIBCOSMIC"; fi
  fi
  _carimbo_vivo > "$CARIMBO" || { meow_erro "não consegui gravar o carimbo"; return "$MEOW_ERRO"; }
  git -C "$ARVORE" checkout -q -- . 2>/dev/null

  meow_ok "$(_nome) compilado e instalado ($(_sha "$BINARIO" | cut -c1-8))"
  meow_pendencia_resolvida "$id_pend"
  _legado_limpar
  if _painel_cita "$P_APP_ID"; then
    meow_info "a barra já cita $(_nome) — ele sobe junto com o painel"
  else
    meow_info "a barra não cita $(_nome) ainda (a ordem dos applets é de quem usa)"
  fi
  meow_registrar "extensoes_build.sh $ID instalou $(_sha "$BINARIO" | cut -c1-8)"
  return "$MEOW_DIVERGENTE"
}

_reverter() {
  local mexeu=0 f
  if meow_seco; then
    [ -f "$SOMBRA" ]  && { meow_muda "removeria a sombra $SOMBRA"; mexeu=1; }
    [ -e "$BINARIO" ] && { meow_muda "removeria o binário $BINARIO"; mexeu=1; }
    [ -d "$ESTADO" ]  && { meow_muda "removeria a árvore de build $ESTADO"; mexeu=1; }
    [ "$mexeu" = 1 ] && return "$MEOW_DIVERGENTE"
    meow_pula "não há $(_nome) nosso para remover"
    return "$MEOW_OK"
  fi

  if [ -f "$ESTADO/icones.lista" ]; then
    while IFS= read -r f; do [ -n "$f" ] && rm -f -- "$f"; done < "$ESTADO/icones.lista"
  fi
  [ -f "$SOMBRA" ]  && { rm -f "$SOMBRA";  mexeu=1; }
  [ -e "$BINARIO" ] && { rm -f "$BINARIO"; mexeu=1; }
  [ -d "$ESTADO" ]  && { rm -rf "$ESTADO"; mexeu=1; }
  meow_pendencia_resolvida "extensao-$ID"
  _legado_limpar >/dev/null 2>&1

  if [ "$mexeu" = 0 ]; then
    meow_pula "não havia $(_nome) nosso para remover"
    return "$MEOW_OK"
  fi
  if _painel_cita "$P_APP_ID"; then
    meow_info "a barra ainda cita \"$P_APP_ID\", e sem a sombra o painel ignora o nome"
  fi
  meow_ok "$(_nome) removido — a configuração dele fica"
  return "$MEOW_DIVERGENTE"
}

_estado() {
  local instalada=nao em_dia=nao na_barra=nao troca="" atualizacao=nao falhou=nao gravado="" id
  [ -x "$BINARIO" ] && [ -f "$SOMBRA" ] && instalada=sim
  [ -f "$CARIMBO" ] && gravado="$(sed -n 's/^commit //p' "$CARIMBO" | head -1)"
  if [ "$instalada" = sim ]; then
    _carimbo_bate && em_dia=sim
    [ "$gravado" != "$P_COMMIT" ] && atualizacao=sim
  fi
  _painel_cita "$P_APP_ID" && na_barra=sim
  if [ "$instalada" = sim ]; then
    for id in $P_SUBSTITUI; do
      _painel_cita "$id" && { troca="$id"; break; }
    done
  fi
  [ -f "$ESTADO/falhou" ] && falhou=sim
  printf 'id=%s\ncasa=%s\ninstalada=%s\nem_dia=%s\natualizacao=%s\nna_barra=%s\ntroca=%s\nfalhou=%s\ncommit_instalado=%s\n' \
    "$ID" "$CASA" "$instalada" "$em_dia" "$atualizacao" "$na_barra" "$troca" "$falhou" "$gravado"
  return "$MEOW_OK"
}

_atualizar() {
  local novo
  [ "$CASA" = 0 ] || { meow_erro "$(_nome) é da casa: o pino anda com o MeowSystem"; return "$MEOW_ERRO"; }
  novo="$(git ls-remote "$P_URL" HEAD 2>/dev/null | cut -f1 | head -1)"
  [[ "$novo" =~ ^[0-9a-f]{40}$ ]] || { meow_aviso "não consegui ler $P_URL (sem rede?)"; return "$MEOW_SEM_DEPENDENCIA"; }
  if [ "$novo" != "$P_COMMIT" ]; then
    sed -i "s/^COMMIT=.*/COMMIT=\"$novo\"/" "$PINOS_USUARIO/$ID.pino" || return "$MEOW_ERRO"
    P_COMMIT="$novo"
  fi
  _aplicar
}

_um() {
  local modo="$1"
  case "$modo" in
    estado)   _estado ;;
    reverter) _reverter ;;
    atualizar) _atualizar ;;
    conferir) _conferir ;;
    aplicar)  _aplicar ;;
  esac
}

_pior() {
  local atual="$1" novo="$2"
  [ "$novo" = "$MEOW_ERRO" ] && { printf '%s' "$MEOW_ERRO"; return; }
  [ "$atual" = "$MEOW_ERRO" ] && { printf '%s' "$MEOW_ERRO"; return; }
  [ "$novo" = "$MEOW_DIVERGENTE" ] && { printf '%s' "$MEOW_DIVERGENTE"; return; }
  [ "$atual" = "$MEOW_DIVERGENTE" ] && { printf '%s' "$MEOW_DIVERGENTE"; return; }
  [ "$novo" = "$MEOW_SEM_DEPENDENCIA" ] && { printf '%s' "$MEOW_SEM_DEPENDENCIA"; return; }
  printf '%s' "$atual"
}

_todas_reverter() {
  local id f rc geral="$MEOW_OK"
  for id in $(_ids_da_casa) $(for f in "$PINOS_USUARIO"/*.pino; do [ -f "$f" ] && basename "$f" .pino; done); do
    _carregar "$id" || continue
    _reverter; rc=$?
    geral="$(_pior "$geral" "$rc")"
  done
  return "$geral"
}

_todas() {
  local modo="$1" id rc geral="$MEOW_OK" querido=0
  [ "$modo" = reverter ] && { _todas_reverter; return $?; }
  for id in $(_ids_da_casa); do
    _carregar "$id" || { geral="$(_pior "$geral" "$MEOW_ERRO")"; continue; }
    if _quer "$id"; then
      querido=1
      _um "$modo"; rc=$?
    elif [ -x "$BINARIO" ] || [ -f "$SOMBRA" ]; then
      if [ "$modo" = conferir ]; then
        meow_muda "$(_nome) continua instalado, e a lista EXTENSOES do meow.conf não o cita"
        rc="$MEOW_DIVERGENTE"
      else
        _reverter; rc=$?
      fi
    else
      meow_seco || [ "$modo" = conferir ] || meow_pendencia_resolvida "extensao-$ID"
      continue
    fi
    geral="$(_pior "$geral" "$rc")"
  done
  if [ "$querido" = 0 ] && [ "$geral" = "$MEOW_OK" ]; then
    meow_pula "nenhuma extensão pedida no meow.conf (EXTENSOES)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$geral"
}

uso() { meow_erro "uso: $(basename "$0") <id> [--conferir|--aplicar|--reverter|--estado|--atualizar]  |  --todas [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO"; }

main() {
  local alvo="${1:-}" modo="aplicar" flag
  [ -n "$alvo" ] || uso
  if [ "$alvo" = --todas ]; then
    flag="${2:---aplicar}"
    case "$flag" in --conferir) modo=conferir ;; --aplicar) modo=aplicar ;; --reverter) modo=reverter ;; *) uso ;; esac
    meow_seco && [ "$modo" != reverter ] && modo=conferir
    [ "$modo" = conferir ] && AP_SO_LER=1
    _todas "$modo"
    return $?
  fi
  flag="${2:---aplicar}"
  case "$flag" in
    --conferir) modo=conferir ;;
    --aplicar) modo=aplicar ;;
    --reverter) modo=reverter ;;
    --estado) modo=estado ;;
    --atualizar) modo=atualizar ;;
    *) uso ;;
  esac
  meow_seco && [ "$modo" != reverter ] && [ "$modo" != estado ] && modo=conferir
  { [ "$modo" = conferir ] || [ "$modo" = estado ]; } && AP_SO_LER=1
  _carregar "$alvo" || return $?
  _um "$modo"
}

main "$@"

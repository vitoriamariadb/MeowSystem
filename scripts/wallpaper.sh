#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

BASE="${WALLPAPER_BASE:-$HOME/.local/share/backgrounds/meowsystem}"
ATIVOS="$BASE/ativos"
NOITE_DIR="$BASE/ativos-noite"
DIA_DIR="$BASE/ativos-dia"
PACK_ATIVOS="$BASE/ativos-pack"
BG="$(meow_cosmic_dir)/com.system76.CosmicBackground/$(meow_cosmic_v com.system76.CosmicBackground)"
ORDEM="${WALLPAPER_ORDEM:-aleatoria}"
INTERVALO="${WALLPAPER_INTERVALO:-5m}"

ROTACAO="$ATIVOS"
GRUPO=""
NOITE_N=0
DIA_N=0

conf_bruto() {
  local chave="$1" linha resto
  [ -f "$MEOW_CONF_ARQUIVO" ] || return 0
  linha="$(grep -E -- "^[[:space:]]*(export[[:space:]]+)?${chave}=" \
             "$MEOW_CONF_ARQUIVO" 2>/dev/null | tail -n1)"
  [ -n "$linha" ] || return 0
  resto="${linha#*=}"
  case "$resto" in
    '"'*) resto="${resto#\"}"; printf '%s' "${resto%%\"*}" ;;
    "'"*) resto="${resto#\'}"; printf '%s' "${resto%%\'*}" ;;
    *)    printf '%s' "${resto%%[[:space:]#]*}" ;;
  esac
}

valor_da_chave() {
  local chave="$1" padrao="$2" v
  v="${!chave-}"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  v="$(conf_bruto "$chave")"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  printf '%s' "$padrao"
}

sim_ou_nao() {
  local v="$1" chave="$2" padrao="$3"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  v="${v//ã/a}"; v="${v//Ã/a}"
  case "${v,,}" in
    sim|s|1|true|yes)     printf 'sim'; return 0 ;;
    nao|n|0|false|no)     printf 'nao'; return 0 ;;
  esac
  meow_aviso "$chave=\"$1\" não existe; usando $padrao (sim | nao)"
  printf '%s' "$padrao"
}

NOITE="$(sim_ou_nao "$(valor_da_chave WALLPAPER_NOITE sim)" WALLPAPER_NOITE sim)"
NOITE_INICIO="$(valor_da_chave WALLPAPER_NOITE_INICIO 18:00)"
NOITE_FIM="$(valor_da_chave WALLPAPER_NOITE_FIM 07:00)"
LIMIAR_LUZ="$(valor_da_chave WALLPAPER_LIMIAR_LUZ 0.37)"

LUZ_TSV="$MEOW_ESTADO/wallpaper-luz.tsv"

AJUSTE="${WALLPAPER_AJUSTE:-preencher}"

modo_de_ajuste() {
  case "$1" in
    preencher|zoom)   printf 'Zoom' ;;
    esticar|stretch)  printf 'Stretch' ;;
    caber|fit)        printf 'Fit((0.0, 0.0, 0.0))' ;;
    *)
      meow_aviso "WALLPAPER_AJUSTE=\"$1\" não existe; usando preencher"
      printf 'Zoom' ;;
  esac
}

FONTES_PERMITIDAS="${WALLPAPER_FONTES_PERMITIDAS-${WALLPAPER_FONTES_DELA:-}}"

fonte_autorizada() {
  local fonte="$1" texto="${2-$FONTES_PERMITIDAS}" p
  [ -n "$fonte" ] && [ -n "$texto" ] || return 1
  local -a lista=()
  IFS=: read -r -a lista <<< "$texto"
  for p in ${lista[@]+"${lista[@]}"}; do
    [ -n "$p" ] || continue
    case "$fonte" in "$p"|"$p"/*) return 0 ;; esac
  done
  return 1
}

segundos_de() {
  local v="$1" n u
  n="${v%[smh]}"; u="${v#$n}"
  case "$n" in ''|*[!0-9]*) echo 300; return ;; esac
  case "$u" in
    s) echo "$n" ;;
    m) echo $((n * 60)) ;;
    h) echo $((n * 3600)) ;;
    *) echo "$n" ;;
  esac
}

metodo_de() {
  case "${1:-aleatoria}" in
    alfabetica|alphanumeric) echo Alphanumeric ;;
    *) echo Random ;;
  esac
}

config_desejada() {
  local freq metodo ajuste
  freq="$(segundos_de "$INTERVALO")"
  metodo="$(metodo_de "$ORDEM")"
  ajuste="$(modo_de_ajuste "$AJUSTE")"
  cat <<FIM
(
    output: "all",
    source: Path("$ROTACAO"),
    filter_by_theme: false,
    rotation_frequency: $freq,
    filter_method: Lanczos,
    scaling_mode: $ajuste,
    sampling_method: $metodo,
)
FIM
}

forcar_releitura() {
  local alvos=() alvo conteudo
  mapfile -t alvos < <(ls -1 "$BG" 2>/dev/null | grep -E '^(all|output\.)' )
  [ "${#alvos[@]}" -gt 0 ] || return 0

  if meow_seco; then
    meow_muda "forçaria o cosmic-bg a reler a pasta (a rotação recomeça)"
    return 0
  fi

  for alvo in "${alvos[@]}"; do
    [ -f "$BG/$alvo" ] || continue
    conteudo="$(cat "$BG/$alvo")"
    printf '%s' "${conteudo/rotation_frequency: /rotation_frequency: 1, x_meow_reler: }" > "$BG/$alvo"
    printf '%s' "$conteudo" > "$BG/$alvo"
  done
  meow_info "cosmic-bg avisado — a rotação recomeça pela primeira imagem"
  return 0
}

criar_pastas() {
  local p
  for p in ativos favoritos banidos originais; do
    [ -d "$BASE/$p" ] && continue
    meow_seco && { meow_muda "criaria $BASE/$p"; continue; }
    mkdir -p "$BASE/$p" || return "$MEOW_ERRO"
  done
  return 0
}

semear_das_dela() {
  local origem="$HOME/Imagens/Parede_papel"
  [ -d "$origem" ] || return 0
  [ "$(quantas)" -eq 0 ] || return 0
  local n=0
  while IFS= read -r img; do
    local nome_dela; nome_dela="$(basename "$img")"
    local destino="$ATIVOS/$nome_dela"
    [ -e "$destino" ] && continue
    esta_banida "$nome_dela" && continue
    meow_seco || { meow_guardar_antes "$destino"; cp -n "$img" "$destino" 2>/dev/null; } || continue
    n=$((n + 1))
  done < <(find "$origem" -maxdepth 1 -type f \
             \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null)
  if [ "$n" -gt 0 ]; then
    if meow_seco; then
      meow_muda "copiaria $n imagem(ns) de ~/Imagens/Parede_papel"
    else
      meow_info "$n imagem(ns) copiadas de ~/Imagens/Parede_papel"
    fi
  fi
  return 0
}

quantas() { find "$ATIVOS" -maxdepth 1 -type f 2>/dev/null | wc -l; }
quantas_em() { find "$1" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | wc -l; }

IM=""
tem_imagemagick() {
  [ -n "$IM" ] && return 0
  if   meow_tem magick;  then IM=magick
  elif meow_tem convert; then IM=convert
  else return 1
  fi
  return 0
}

luz_de() {
  local arq="$1" v
  v="$("$IM" -quiet -define jpeg:size=256x256 "${arq}[0]" -resize 128x128 \
        -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null)" || return 1
  case "$v" in ''|*[!0-9.eE+-]*) return 1 ;; esac
  printf '%s' "$v"
}

milesimos_de() {
  local v="$1" i f
  case "$v" in *e*|*E*) v="$(printf '%.6f' "$v" 2>/dev/null)" || v=0 ;; esac
  case "$v" in
    *.*) i="${v%%.*}"; f="${v#*.}" ;;
    *)   i="$v";       f="0" ;;
  esac
  f="${f}0000"; f="${f:0:4}"
  case "$i" in ''|*[!0-9]*) i=0 ;; esac
  case "$f" in *[!0-9]*) f=0000 ;; esac
  echo $(( 10#$i * 10000 + 10#$f ))
}

declare -A LUZ=()

medir_acervo() {
  LUZ=()
  local TAB=$'\t' NL=$'\n'
  local -A guardado=() carimbos=()
  local nome tam mt luz

  if [ -f "$LUZ_TSV" ]; then
    while IFS="$TAB" read -r nome tam mt luz; do
      case "$nome" in ''|'#'*) continue ;; esac
      [ -n "$luz" ] || continue
      guardado["$nome"]="$tam$TAB$mt$TAB$luz"
    done < "$LUZ_TSV"
  fi

  local arq base carimbo antes novos=0 falhas=0
  for arq in "$ATIVOS"/*; do
    [ -f "$arq" ] || continue
    base="${arq##*/}"
    case "$base" in
      *"$TAB"*|*"$NL"*)
        meow_aviso "'$base' tem tab ou quebra de linha no nome — fica fora da separação claro/escuro"
        continue ;;
    esac
    carimbo="$(stat -c $'%s\t%Y' -- "$arq" 2>/dev/null)" || continue
    carimbos["$base"]="$carimbo"
    antes="${guardado[$base]:-}"
    if [ -n "$antes" ] && [ "${antes%"$TAB"*}" = "$carimbo" ]; then
      LUZ["$base"]="${antes##*"$TAB"}"
      continue
    fi
    tem_imagemagick || { falhas=$((falhas + 1)); continue; }
    luz="$(luz_de "$arq")" || { falhas=$((falhas + 1)); continue; }
    LUZ["$base"]="$luz"
    novos=$((novos + 1))
  done

  [ "$novos" -gt 0 ] && meow_debug "medi $novos papel(is) de parede novo(s) ou trocado(s)"
  if [ "$falhas" -gt 0 ]; then
    if tem_imagemagick; then
      meow_aviso "$falhas imagem(ns) não puderam ser medidas — ficam fora da separação claro/escuro"
    else
      meow_aviso "sem ImageMagick não dá para separar claro de escuro ($falhas imagem(ns))"
    fi
  fi

  meow_seco && return 0
  [ "${#LUZ[@]}" -gt 0 ] || return 0

  local conteudo linhas=""
  conteudo="# wallpaper-luz.tsv — a luminância perceptual (Rec.709) de cada papel de ativos/.$NL"
  conteudo="$conteudo# nome<TAB>tamanho<TAB>mtime<TAB>luminância. É CACHE: apagar só custa remedir.$NL"
  while IFS= read -r base; do
    linhas="$linhas$base$TAB${carimbos[$base]}$TAB${LUZ[$base]}$NL"
  done < <(printf '%s\n' "${!LUZ[@]}" | LC_ALL=C sort)
  conteudo="$conteudo$linhas"

  [ "$conteudo" = "$(cat "$LUZ_TSV" 2>/dev/null)$NL" ] && return 0
  local dir tmp; dir="$(dirname "$LUZ_TSV")"
  mkdir -p "$dir" 2>/dev/null || return 0
  tmp="$(mktemp -p "$dir" ".meow.XXXXXX" 2>/dev/null)" || return 0
  printf '%s' "$conteudo" > "$tmp" 2>/dev/null \
    && chmod 644 "$tmp" 2>/dev/null \
    && meow_guardar_antes "$LUZ_TSV" \
    && mv -f "$tmp" "$LUZ_TSV" 2>/dev/null \
    || rm -f "$tmp"
  return 0
}

minutos_de_hora() {
  local v="$1" h m
  case "$v" in
    [0-9][0-9]:[0-9][0-9]|[0-9]:[0-9][0-9]) ;;
    *) return 1 ;;
  esac
  h="${v%%:*}"; m="${v##*:}"
  [ "$((10#$h))" -le 23 ] && [ "$((10#$m))" -le 59 ] || return 1
  echo $(( 10#$h * 60 + 10#$m ))
}

e_noite() {
  local ini fim agora
  ini="$(minutos_de_hora "$NOITE_INICIO")" || {
    meow_aviso "WALLPAPER_NOITE_INICIO=\"$NOITE_INICIO\" não é HH:MM; usando 18:00"
    ini=1080; }
  fim="$(minutos_de_hora "$NOITE_FIM")" || {
    meow_aviso "WALLPAPER_NOITE_FIM=\"$NOITE_FIM\" não é HH:MM; usando 07:00"
    fim=420; }
  agora="$(minutos_de_hora "$(date +%H:%M)")" || return 0
  [ "$ini" = "$fim" ] && return 0
  if [ "$ini" -gt "$fim" ]; then
    [ "$agora" -ge "$ini" ] || [ "$agora" -lt "$fim" ]
  else
    [ "$agora" -ge "$ini" ] && [ "$agora" -lt "$fim" ]
  fi
}

montar_derivada() {
  local dir="$1"; shift
  local -A quer=()
  local base arq
  for base in "$@"; do quer["$base"]=1; done

  mkdir -p "$dir" || { meow_erro "não consegui criar $dir"; return 1; }

  for arq in "$dir"/* "$dir"/.[!.]*; do
    [ -e "$arq" ] || [ -L "$arq" ] || continue
    base="${arq##*/}"
    [ -n "${quer[$base]:-}" ] && [ "$arq" -ef "$ATIVOS/$base" ] && continue
    meow_guardar_antes "$arq"
    rm -f -- "$arq"
  done

  for base in "$@"; do
    [ -e "$dir/$base" ] && continue
    meow_guardar_antes "$dir/$base"
    ln -f -- "$ATIVOS/$base" "$dir/$base" 2>/dev/null && continue
    ln -sfn -- "$ATIVOS/$base" "$dir/$base" 2>/dev/null || return 1
  done
  return 0
}

soltar_derivadas() {
  local dir vistas=0
  for dir in "$NOITE_DIR" "$DIA_DIR"; do
    [ -d "$dir" ] || continue
    vistas=1
    if meow_seco; then meow_muda "removeria $dir/"; continue; fi
    find "$dir" -maxdepth 1 \( -type f -o -type l \) -delete 2>/dev/null
    rmdir "$dir" 2>/dev/null || meow_aviso "$dir/ não ficou vazio — deixei como estava"
  done
  [ "$vistas" = "1" ] || return 1
  meow_seco || meow_info "a noite está desligada: as pastas derivadas saíram e a rotação é ativos/"
  return 0
}

declare -A ALHEIA_NOME=()
ALHEIOS_PREFIXOS=()
_ALHEIAS_LIDAS=0
_colecoes_alheias() {
  [ "$_ALHEIAS_LIDAS" = 1 ] && return 0
  _ALHEIAS_LIDAS=1
  local tipo valor
  while IFS=$'\t' read -r tipo valor; do
    [ -n "$valor" ] || continue
    case "$tipo" in
      prefixo) ALHEIOS_PREFIXOS+=("$valor") ;;
      nome)    ALHEIA_NOME["$valor"]=1 ;;
    esac
  done < <(python3 "$RAIZ/scripts/pack.py" colecoes-alheias "$_PACK_NO_AR" 2>/dev/null)
}

e_alheia() {
  local p
  [ -n "${ALHEIA_NOME[$1]:-}" ] && return 0
  for p in ${ALHEIOS_PREFIXOS[@]+"${ALHEIOS_PREFIXOS[@]}"}; do
    case "$1" in "$p"-*) return 0 ;; esac
  done
  return 1
}

ROTACAO_BASE="$ATIVOS"
COLECAO=()
PACK_MUDOU=0
base_da_rotacao() {
  local arq base alheias=0 antes
  COLECAO=(); ROTACAO_BASE="$ATIVOS"
  _colecoes_alheias
  for arq in "$ATIVOS"/*; do
    [ -f "$arq" ] || continue
    base="${arq##*/}"
    if e_alheia "$base"; then alheias=$((alheias + 1)); else COLECAO+=("$base"); fi
  done
  if [ "$alheias" = 0 ] || [ "${#COLECAO[@]}" -lt 2 ]; then
    [ "$alheias" = 0 ] || meow_aviso "a coleção do pack no ar tem ${#COLECAO[@]} imagem(ns) — gira ativos/ inteira"
    COLECAO=()
    if [ -d "$PACK_ATIVOS" ]; then
      if meow_seco; then meow_muda "removeria $PACK_ATIVOS/"
      else find "$PACK_ATIVOS" -maxdepth 1 \( -type f -o -type l \) -delete 2>/dev/null; rmdir "$PACK_ATIVOS" 2>/dev/null; fi
    fi
    return 0
  fi
  antes="$(ls -1A "$PACK_ATIVOS" 2>/dev/null | LC_ALL=C sort)"
  if [ -d "$PACK_ATIVOS" ] && [ "$antes" != "$(printf '%s\n' "${COLECAO[@]}" | LC_ALL=C sort)" ]; then
    PACK_MUDOU=1
  fi
  if meow_seco; then
    [ -d "$PACK_ATIVOS" ] || meow_muda "criaria $PACK_ATIVOS/ com ${#COLECAO[@]} link(s) duro(s) para ativos/"
    [ "$PACK_MUDOU" = 1 ] && meow_muda "refaria $PACK_ATIVOS/ com a coleção do pack no ar"
    ROTACAO_BASE="$PACK_ATIVOS"
    return 0
  fi
  if montar_derivada "$PACK_ATIVOS" "${COLECAO[@]}"; then
    ROTACAO_BASE="$PACK_ATIVOS"
  else
    COLECAO=()
    meow_aviso "não consegui montar $PACK_ATIVOS/ — gira ativos/ inteira"
  fi
  return 0
}

case "${1:-aplicar}" in estado) MEOW_ESTADO_SO_LE=1 ;; esac
LADO_TSV="${WALLPAPER_LADO:-$(meow_estado_com_padrao papeis-de-parede lado.tsv)}"

declare -A LADO=()

ler_lado() {
  LADO=()
  [ -f "$LADO_TSV" ] || return 0
  local TAB=$'\t' nome escolha estranhas=0
  while IFS="$TAB" read -r nome escolha || [ -n "$nome" ]; do
    case "$nome" in ''|'#'*) continue ;; esac
    case "$escolha" in
      dia|noite) LADO["$nome"]="$escolha" ;;
      *)         estranhas=$((estranhas + 1)) ;;
    esac
  done < "$LADO_TSV"
  [ "$estranhas" -gt 0 ] && \
    meow_aviso "$(basename "$LADO_TSV"): $estranhas linha(s) sem 'dia' nem 'noite' — ignoradas"
  return 0
}

gravar_lado() {
  local TAB=$'\t' NL=$'\n' dir tmp conteudo base

  if [ "${#LADO[@]}" -eq 0 ]; then
    [ -f "$LADO_TSV" ] || return 0
    meow_guardar_antes "$LADO_TSV"
    rm -f -- "$LADO_TSV" 2>/dev/null || return 1
    return 0
  fi

  dir="$(dirname "$LADO_TSV")"
  mkdir -p "$dir" 2>/dev/null || return 1
  conteudo="# lado.tsv — de que lado cada papel de parede fica POR ESCOLHA DELA.$NL"
  conteudo="$conteudo# nome-do-arquivo<TAB>dia|noite. Quem não está aqui é separado pela luminância.$NL"
  while IFS= read -r base; do
    conteudo="$conteudo$base$TAB${LADO[$base]}$NL"
  done < <(printf '%s\n' "${!LADO[@]}" | LC_ALL=C sort)

  tmp="$(mktemp -p "$dir" ".atomicwrite.meow.XXXXXX" 2>/dev/null)" || return 1
  if printf '%s' "$conteudo" > "$tmp" 2>/dev/null \
     && chmod 644 "$tmp" 2>/dev/null \
     && mv -f "$tmp" "$LADO_TSV" 2>/dev/null; then
    return 0
  fi
  rm -f "$tmp"
  return 1
}

_lado_esquecer() {
  local alvo="$1" base
  local -A resto=()
  for base in "${!LADO[@]}"; do
    [ "$base" = "$alvo" ] && continue
    resto["$base"]="${LADO[$base]}"
  done
  LADO=()
  [ "${#resto[@]}" -gt 0 ] || return 0
  for base in "${!resto[@]}"; do LADO["$base"]="${resto[$base]}"; done
  return 0
}

podar_lado() {
  ler_lado
  [ "${#LADO[@]}" -gt 0 ] || return 0

  local -a mortas=()
  local -A vivas=()
  local base
  for base in "${!LADO[@]}"; do
    if [ -f "$ATIVOS/$base" ]; then
      vivas["$base"]="${LADO[$base]}"
    else
      mortas+=("$base")
    fi
  done
  [ "${#mortas[@]}" = "0" ] && return 0

  if meow_seco; then
    meow_muda "tiraria ${#mortas[@]} linha(s) de $(basename "$LADO_TSV") — não estão mais em ativos/"
    return 1
  fi

  LADO=()
  if [ "${#vivas[@]}" -gt 0 ]; then
    for base in "${!vivas[@]}"; do LADO["$base"]="${vivas[$base]}"; done
  fi
  gravar_lado || { meow_aviso "não consegui podar $LADO_TSV"; return 0; }
  meow_info "${#mortas[@]} escolha(s) de lado saíram de $(basename "$LADO_TSV"): ${mortas[*]}"
  return 1
}

resolver_rotacao() {
  _resolver_grupo || return $?
  local fixo

  if [ "${CUROU:-0}" = "1" ] && [ -f "$FIXADO" ]; then
    if meow_seco; then
      meow_muda "soltaria a fixação — você acabou de banir papel de parede"
    else
      soltar_fixo
      meow_info "curadoria nova: soltei a fixação para o carrossel responder na hora"
    fi
  fi

  if fixo="$(fixo_valido)"; then
    ROTACAO="$fixo"; GRUPO="fixado"
  elif [ -f "$FIXADO" ]; then
    if meow_seco; then
      meow_muda "soltaria a fixação vencida — o carrossel volta"
    else
      soltar_fixo
      meow_info "fixação vencida ($FIXO_TTL) — o carrossel voltou"
    fi
  fi
  return 0
}

_resolver_grupo() {
  base_da_rotacao
  ROTACAO="$ROTACAO_BASE"; GRUPO=""; NOITE_N=0; DIA_N=0

  [ "$NOITE" = "sim" ] || return 0

  local lim; lim="$(milesimos_de "$LIMIAR_LUZ")"
  if [ "$lim" -le 0 ] || [ "$lim" -ge 10000 ]; then
    meow_aviso "WALLPAPER_LIMIAR_LUZ=\"$LIMIAR_LUZ\" fora de 0-1; usando 0.37"
    LIMIAR_LUZ="0.37"; lim=3700
  fi

  medir_acervo
  if [ "${#LUZ[@]}" -eq 0 ]; then
    meow_aviso "nenhum papel de parede medido — a rotação fica em ativos/"
    return 0
  fi

  ler_lado

  local -a escuros=() claros=()
  local base por_escolha=0

  local -A universo=() da_colecao=()
  for base in ${COLECAO[@]+"${COLECAO[@]}"}; do da_colecao["$base"]=1; done
  for base in "${!LUZ[@]}"; do
    [ "${#COLECAO[@]}" -gt 0 ] && [ -z "${da_colecao[$base]:-}" ] && continue
    universo["$base"]=1
  done
  if [ "${#LADO[@]}" -gt 0 ]; then
    for base in "${!LADO[@]}"; do
      [ -n "${universo[$base]:-}" ] && continue
      [ "${#COLECAO[@]}" -gt 0 ] && [ -z "${da_colecao[$base]:-}" ] && continue
      [ -f "$ATIVOS/$base" ] || continue
      universo["$base"]=1
    done
  fi

  for base in "${!universo[@]}"; do
    case "${LADO[$base]:-}" in
      noite) escuros+=("$base"); por_escolha=$((por_escolha + 1)); continue ;;
      dia)   claros+=("$base");  por_escolha=$((por_escolha + 1)); continue ;;
    esac
    if [ "$(milesimos_de "${LUZ[$base]:-}")" -lt "$lim" ]
      then escuros+=("$base")
      else claros+=("$base")
    fi
  done
  [ "$por_escolha" -gt 0 ] && \
    meow_debug "$por_escolha papel(is) de parede foram para o grupo por escolha escrita, não pela medição"
  NOITE_N="${#escuros[@]}"; DIA_N="${#claros[@]}"

  local dir
  local -a lista=()
  if e_noite; then
    GRUPO="noite"; dir="$NOITE_DIR"; lista=(${escuros[@]+"${escuros[@]}"})
  else
    GRUPO="dia";   dir="$DIA_DIR";   lista=(${claros[@]+"${claros[@]}"})
  fi

  if [ "${#lista[@]}" -lt 2 ]; then
    meow_aviso "o grupo de $GRUPO ficou com ${#lista[@]} imagem(ns) (limiar $LIMIAR_LUZ) — a rotação fica em ativos/"
    GRUPO=""
    return 0
  fi

  if meow_seco; then
    [ -d "$NOITE_DIR" ] || meow_muda "criaria $NOITE_DIR/ com $NOITE_N link(s) duro(s) para ativos/"
    [ -d "$DIA_DIR" ]   || meow_muda "criaria $DIA_DIR/ com $DIA_N link(s) duro(s) para ativos/"
    ROTACAO="$dir"
    return 0
  fi

  if montar_derivada "$NOITE_DIR" ${escuros[@]+"${escuros[@]}"} \
     && montar_derivada "$DIA_DIR" ${claros[@]+"${claros[@]}"}; then
    ROTACAO="$dir"
  else
    meow_aviso "não consegui montar as pastas de dia/noite — a rotação fica em ativos/"
    GRUPO=""
  fi
  return 0
}

fonte_nossa() {
  case "$1" in
    "$ATIVOS"|"$ATIVOS"/*|"$NOITE_DIR"|"$NOITE_DIR"/*|"$DIA_DIR"|"$DIA_DIR"/*|"$PACK_ATIVOS"|"$PACK_ATIVOS"/*) return 0 ;;
  esac
  return 1
}

FIXO_TTL="${WALLPAPER_FIXO_TTL:-30m}"
FIXADO="$MEOW_ESTADO/wallpaper-fixado"
CUROU=0

gravar_fixo() { printf '%s\t%s\n' "$1" "$(date +%s)" > "$FIXADO" 2>/dev/null; }
soltar_fixo() { rm -f "$FIXADO" 2>/dev/null; return 0; }

fixo_valido() {
  local linha caminho quando ttl agora
  [ -f "$FIXADO" ] || return 1
  linha="$(cat "$FIXADO" 2>/dev/null)" || return 1
  caminho="${linha%%	*}"; quando="${linha##*	}"
  [ -n "$caminho" ] && [ -f "$caminho" ] || return 1
  case "$quando" in ''|*[!0-9]*) return 1 ;; esac
  ttl="$(segundos_de "$FIXO_TTL")"
  if [ "$ttl" -gt 0 ]; then
    agora="$(date +%s)"
    [ "$((agora - quando))" -lt "$ttl" ] || return 1
  fi
  printf '%s' "$caminho"
}

imagem_atual() {
  local estado
  estado="$HOME/.local/state/cosmic/com.system76.CosmicBackground/$(meow_cosmic_v com.system76.CosmicBackground)/wallpapers"
  local p
  [ -f "$estado" ] || return 1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    fonte_nossa "$p" && [ -f "$p" ] && { printf '%s' "$p"; return 0; }
  done < <(grep -oP 'Path\("\K[^"]+' "$estado" 2>/dev/null)
  return 1
}

lista_do_grupo() {
  local dir="$1"
  find "$dir" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | LC_ALL=C sort
}

ESTADO_BG="$HOME/.local/state/cosmic/com.system76.CosmicBackground/$(meow_cosmic_v com.system76.CosmicBackground)/wallpapers"

limpar_estado_morto() {
  [ -f "$ESTADO_BG" ] || return 1

  if pgrep -x cosmic-bg >/dev/null 2>&1; then
    meow_debug "cosmic-bg de pé — a limpeza do estado fica para uma sessão em que ele não esteja"
    return 1
  fi

  local novo mortas saida
  saida="$(python3 -I - "$ESTADO_BG" <<'FIM' 2>/dev/null
import os, re, sys
texto = open(sys.argv[1], encoding="utf-8").read()
padrao = re.compile(r'^\s*\(\s*"[^"]*"\s*,\s*Path\("([^"]*)"\)\s*\)\s*,?\s*$')
guardar, mortas = [], 0
for linha in texto.splitlines():
    m = padrao.match(linha)
    if m and not os.path.exists(m.group(1)):
        mortas += 1
        continue
    guardar.append(linha)
if not mortas:
    sys.exit(1)
print(mortas)
print("\n".join(guardar))
FIM
)" || return 1
  mortas="${saida%%$'\n'*}"
  case "$saida" in
    *$'\n'*) novo="${saida#*$'\n'}" ;;
    *)       novo="" ;;
  esac
  if meow_seco; then
    meow_muda "removeria $mortas caminho(s) fantasma do estado do papel de parede"
    return 0
  fi
  meow_escrever "$ESTADO_BG" "$novo" 644
  case $? in
    1) meow_info "$mortas caminho(s) fantasma removidos do estado (o greeter reclamava deles)"
       return 0 ;;
    *) return 1 ;;
  esac
}

VISTAS="$MEOW_ESTADO/wallpaper-vistas.txt"

reconciliar_sumicos() {
  local -a agora=() sumidas=()
  local nome n_antes n_agora

  mapfile -t agora < <(find "$ATIVOS" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | LC_ALL=C sort)
  n_agora="${#agora[@]}"

  if [ ! -f "$VISTAS" ]; then
    meow_seco || printf '%s\n' ${agora[@]+"${agora[@]}"} > "$VISTAS" 2>/dev/null
    return 0
  fi
  n_antes="$(grep -c . "$VISTAS" 2>/dev/null)"; n_antes="${n_antes:-0}"

  if [ "$n_agora" = "0" ] && [ "$n_antes" -gt 0 ]; then
    meow_aviso "ativos/ está VAZIO e tinha $n_antes imagem(ns) — não vou banir nada"
    meow_info  "  isso é disco desmontado ou home ainda não montado, não curadoria"
    return 0
  fi

  mapfile -t sumidas < <(LC_ALL=C comm -23 <(LC_ALL=C sort -u "$VISTAS") \
                                           <(printf '%s\n' ${agora[@]+"${agora[@]}"} | LC_ALL=C sort -u))
  [ "${#sumidas[@]}" = "0" ] && { meow_seco || printf '%s\n' ${agora[@]+"${agora[@]}"} > "$VISTAS" 2>/dev/null; return 0; }

  if [ "$n_antes" -gt 4 ] && [ "${#sumidas[@]}" -gt $(( n_antes / 2 )) ]; then
    meow_aviso "${#sumidas[@]} de $n_antes imagens sumiram de ativos/ de uma vez — não vou banir nada"
    meow_info  "  se foi você, bana uma a uma: meow wallpaper banir <nome>"
    return 0
  fi

  local -a novas=()
  for nome in "${sumidas[@]}"; do
    [ -f "$BANIDOS_TXT" ] && grep -qxF -- "$nome" "$BANIDOS_TXT" && continue
    novas+=("$nome")
  done
  [ "${#novas[@]}" = "0" ] && { meow_seco || printf '%s\n' ${agora[@]+"${agora[@]}"} > "$VISTAS" 2>/dev/null; return 0; }

  if meow_seco; then
    meow_muda "baniria ${#novas[@]} imagem(ns) apagada(s) à mão: ${novas[*]}"
    return 1
  fi

  mkdir -p "$(dirname "$BANIDOS_TXT")" 2>/dev/null
  [ -f "$BANIDOS_TXT" ] || printf '%s\n' \
    "# BANIDOS.txt — os papéis de parede que você recusou, por nome de arquivo." \
    "# O 'semear' não repõe nada que esteja aqui." > "$BANIDOS_TXT"
  for nome in "${novas[@]}"; do
    grep -qxF -- "$nome" "$BANIDOS_TXT" || printf '%s\n' "$nome" >> "$BANIDOS_TXT"
  done
  meow_ok "${#novas[@]} imagem(ns) apagada(s) à mão entraram no BANIDOS.txt — o semear não as repõe"
  meow_info "  ${novas[*]}"
  meow_registrar "wallpaper.sh auto-banir: ${novas[*]}"
  printf '%s\n' ${agora[@]+"${agora[@]}"} > "$VISTAS" 2>/dev/null
  CUROU=1
  return 1
}

reconciliar_banidos_pasta() {
  [ -d "$BASE/banidos" ] || return 0
  local -a novas=()
  local nome
  while IFS= read -r nome; do
    [ -n "$nome" ] || continue
    [ -f "$BANIDOS_TXT" ] && grep -qxF -- "$nome" "$BANIDOS_TXT" && continue
    [ -e "$ATIVOS/$nome" ] && continue
    if printf '%s' "$nome" | grep -qP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}]' 2>/dev/null; then
      meow_debug "banidos: '$nome' tem emoji no nome e nao entra no BANIDOS.txt (ADR-011)"
      continue
    fi
    novas+=("$nome")
  done < <(find "$BASE/banidos" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | LC_ALL=C sort)

  [ "${#novas[@]}" = "0" ] && return 0

  if meow_seco; then
    meow_muda "registraria ${#novas[@]} imagem(ns) que estão em banidos/ e não no BANIDOS.txt"
    return 1
  fi

  mkdir -p "$(dirname "$BANIDOS_TXT")" 2>/dev/null
  [ -f "$BANIDOS_TXT" ] || printf '%s\n' \
    "# BANIDOS.txt — os papéis de parede que você recusou, por nome de arquivo." \
    "# O 'semear' não repõe nada que esteja aqui." > "$BANIDOS_TXT"
  for nome in "${novas[@]}"; do
    printf '%s\n' "$nome" >> "$BANIDOS_TXT"
  done
  meow_ok "${#novas[@]} imagem(ns) de banidos/ entraram no BANIDOS.txt — a recusa agora sobrevive a uma reinstalação"
  meow_registrar "wallpaper.sh registrar-banidos: ${#novas[@]}"
  CUROU=1
  return 1
}

cmd_aplicar() {
  criar_pastas || { meow_erro "não consegui criar as pastas"; return "$MEOW_ERRO"; }
  reconciliar_sumicos
  reconciliar_banidos_pasta
  semear_das_dela

  local n; n="$(quantas)"
  if [ "$n" -lt 2 ]; then
    meow_pula "só $n imagem(ns) em $ATIVOS — o carrossel precisa de 2 ou mais"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local mudou=0

  podar_lado || mudou=1

  resolver_rotacao

  local desejada; desejada="$(config_desejada)"

  local -a alvos=(all)
  local f
  for f in "$BG"/output.*; do
    [ -f "$f" ] || continue
    alvos+=("$(basename "$f")")
  done
  if [ -f "$BG/backgrounds" ]; then
    while IFS= read -r saida; do
      [ -n "$saida" ] || continue
      case " ${alvos[*]} " in *" output.$saida "*) continue ;; esac
      alvos+=("output.$saida")
    done < <(grep -oP '^\s*"\K[^"]+' "$BG/backgrounds" 2>/dev/null)
  fi

  local FABRICA="/usr/share/backgrounds"
  local alvo escolha_dela=0 fonte_atual
  for alvo in "${alvos[@]}"; do
    local conteudo="$desejada"
    [ "$alvo" = "all" ] || conteudo="${desejada/output: \"all\"/output: \"${alvo#output.}\"}"

    if [ -f "$BG/$alvo" ]; then
      fonte_atual="$(grep -oP 'source: Path\("\K[^"]+' "$BG/$alvo" 2>/dev/null)"
      case "$fonte_atual" in
        "$ATIVOS"|"$ATIVOS"/*|"$NOITE_DIR"|"$NOITE_DIR"/*|"$DIA_DIR"|"$DIA_DIR"/*|"$PACK_ATIVOS"|"$PACK_ATIVOS"/*|"") ;;
        "$FABRICA"|"$FABRICA"/*) ;;
        *)
          if fonte_autorizada "$fonte_atual"; then
            meow_pula "$alvo aponta para $fonte_atual — está na WALLPAPER_FONTES_PERMITIDAS, não mexo"
            escolha_dela=1
            continue
          fi
          meow_pendencia_acionavel wallpaper-fonte-revertida \
            "$alvo apontava para $fonte_atual — isso não é o carrossel; devolvendo" \
            "meow wallpaper permitir $fonte_atual"
          ;;
      esac
    fi

    meow_escrever "$BG/$alvo" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao escrever $alvo"; return "$MEOW_ERRO" ;; esac
  done

  [ "$NOITE" = "sim" ] || { soltar_derivadas && mudou=1; }
  if [ "$PACK_MUDOU" = 1 ]; then mudou=1; forcar_releitura; fi

  limpar_estado_morto || true

  [ "${#COLECAO[@]}" -gt 0 ] && n="${#COLECAO[@]}"
  local resumo="$n imagens"
  if [ -n "$GRUPO" ]; then
    local n_grupo="$DIA_N"
    [ "$GRUPO" = "noite" ] && n_grupo="$NOITE_N"
    resumo="$n_grupo de $n imagens (grupo de $GRUPO)"
  fi

  if [ "$mudou" = "0" ]; then
    if [ "$escolha_dela" = "1" ]; then
      meow_info "o carrossel está no lugar; a saída acima é escolha sua"
      return 4
    fi
    meow_ok "carrossel já configurado ($resumo, a cada $INTERVALO, $ORDEM)"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "carrossel ligado: $resumo, troca a cada $INTERVALO ($ORDEM)"
  return "$MEOW_DIVERGENTE"
}

cmd_estado() {
  local n; n="$(quantas)"
  local alvo="$ATIVOS"
  echo "pasta:     $ATIVOS"
  echo "imagens:   $n"
  echo "intervalo: $INTERVALO ($(segundos_de "$INTERVALO")s)"
  echo "ordem:     $ORDEM ($(metodo_de "$ORDEM"))"

  case "$NOITE" in
    sim)
      local agora escuras claras
      escuras="$(quantas_em "$NOITE_DIR")"; claras="$(quantas_em "$DIA_DIR")"
      if e_noite 2>/dev/null; then agora="NOITE"; alvo="$NOITE_DIR"
      else                         agora="DIA";   alvo="$DIA_DIR"; fi
      echo "noite:     ligada, das $NOITE_INICIO às $NOITE_FIM — agora é $agora"

      ler_lado
      local esc_dia=0 esc_noite=0 nome_l por_medicao
      if [ "${#LADO[@]}" -gt 0 ]; then
        for nome_l in "${!LADO[@]}"; do
          [ -f "$ATIVOS/$nome_l" ] || continue
          case "${LADO[$nome_l]}" in
            dia)   esc_dia=$((esc_dia + 1)) ;;
            noite) esc_noite=$((esc_noite + 1)) ;;
          esac
        done
      fi
      por_medicao=$(( escuras + claras - esc_dia - esc_noite ))
      [ "$por_medicao" -lt 0 ] && por_medicao=0
      echo "limiar:    $LIMIAR_LUZ de luminância ($escuras escuras | $claras claras, contadas no disco; escolha sua: $esc_noite noite | $esc_dia dia · medição: $por_medicao)"
      if [ -d "$alvo" ]; then
        echo "rotação:   $alvo"
      else
        echo "rotação:   $ATIVOS (as pastas derivadas nascem na próxima passada do carrossel)"
        alvo="$ATIVOS"
      fi
      ;;
    *)
      echo "noite:     desligada (WALLPAPER_NOITE=\"$NOITE\") — a rotação é o acervo inteiro" ;;
  esac
  local mesma; mesma="$(cat "$BG/same-on-all" 2>/dev/null)"
  local -a mandam=()
  if [ "$mesma" = "false" ]; then
    local f
    for f in "$BG"/output.*; do [ -f "$f" ] && mandam+=("$f"); done
  fi
  [ "${#mandam[@]}" -gt 0 ] || mandam=("$BG/all")

  local fora=0 fonte arq
  for arq in "${mandam[@]}"; do
    [ -f "$arq" ] || continue
    fonte="$(grep -oP 'source: Path\("\K[^"]+' "$arq" 2>/dev/null)"
    [ "$fonte" = "$alvo" ] && continue
    echo "estado:    $(basename "$arq") aponta para outro lugar ($fonte)"
    fora=1
  done
  [ "$fora" = "0" ] && echo "estado:    carrossel ATIVO"
  echo "atual:     (o cosmic-bg não expõe qual imagem está em exibição)"
}

fontes_no_conf() {
  if grep -qE -- "^[[:space:]]*(export[[:space:]]+)?WALLPAPER_FONTES_PERMITIDAS=" \
       "$MEOW_CONF_ARQUIVO" 2>/dev/null; then
    conf_bruto WALLPAPER_FONTES_PERMITIDAS
  else
    conf_bruto WALLPAPER_FONTES_DELA
  fi
}

cmd_dispensar() {
  if meow_seco; then
    meow_muda "tiraria da Início o aviso do papel de parede devolvido (o meow.conf fica como está)"
    return "$MEOW_DIVERGENTE"
  fi
  meow_pendencia_resolvida wallpaper-fonte-revertida
  meow_ok "a imagem devolvida fica como está — o aviso saiu da Início"
  return "$MEOW_OK"
}

cmd_permitir() {
  local caminho="${1:-}"
  [ -n "$caminho" ] || {
    meow_erro "uso: wallpaper.sh permitir <caminho>"
    meow_info "o caminho é o que aparece no aviso \"apontava para …\""
    return "$MEOW_ERRO"; }

  caminho="$(readlink -m -- "$caminho")"

  if [ "${caminho//[\"\$\`\\#]/}" != "$caminho" ]; then
    meow_erro "não gravo caminho com \" \$ \` \\ ou # — o meow.conf é lido pelo shell"
    return "$MEOW_ERRO"
  fi

  local bruto expandido
  bruto="$(fontes_no_conf)"
  expandido="${bruto//\$\{HOME\}/$HOME}"; expandido="${expandido//\$HOME/$HOME}"
  if fonte_autorizada "$caminho" "$expandido"; then
    meow_seco || meow_pendencia_resolvida wallpaper-fonte-revertida
    meow_ok "$caminho já está autorizado em WALLPAPER_FONTES_PERMITIDAS"
    return "$MEOW_OK"
  fi

  [ -e "$caminho" ] || meow_aviso "$caminho não existe hoje — autorizando assim mesmo"

  local novo="$caminho"
  [ -n "$bruto" ] && novo="$bruto:$caminho"

  meow_conf_definir WALLPAPER_FONTES_PERMITIDAS "$novo"
  case $? in
    0) meow_ok "$MEOW_CONF_ARQUIVO já estava assim — nada foi escrito"
       return "$MEOW_OK" ;;
    1) if meow_seco; then
         meow_muda "gravaria WALLPAPER_FONTES_PERMITIDAS=\"$novo\""
         return "$MEOW_DIVERGENTE"
       fi
       meow_ok "autorizado: $caminho"
       meow_info "o carrossel não mexe mais em saída que aponte para lá"
       meow_registrar "wallpaper permitir: $caminho"
       meow_pendencia_resolvida wallpaper-fonte-revertida
       return "$MEOW_DIVERGENTE" ;;
    *) meow_erro "não consegui gravar $MEOW_CONF_ARQUIVO"
       return "$MEOW_ERRO" ;;
  esac
}

cmd_banir() {
  local img="$1"
  [ -f "$img" ] || { meow_erro "não achei $img"; return "$MEOW_ERRO"; }
  local nome; nome="$(basename "$img")"
  if meow_seco; then
    meow_muda "baniria $nome (iria para banidos/ e entraria em $(basename "$BANIDOS_TXT"))"
    return "$MEOW_DIVERGENTE"
  fi
  criar_pastas
  meow_guardar_antes "$img"; meow_guardar_antes "$BASE/banidos/$nome"
  if [ -e "$BASE/banidos/$nome" ] && cmp -s "$img" "$BASE/banidos/$nome"; then
    rm -f "$img"
  else
    mv -f "$img" "$BASE/banidos/" || return "$MEOW_ERRO"
  fi
  local pasta_lista; pasta_lista="$(dirname "$BANIDOS_TXT")"
  if [ -d "$pasta_lista" ]; then
    [ -f "$BANIDOS_TXT" ] || printf '%s\n' \
      "# BANIDOS.txt — os papéis de parede que você recusou, por nome de arquivo." \
      "# O 'meow wallpaper banir' acrescenta aqui; o 'semear' não repõe o que está listado." \
      > "$BANIDOS_TXT"
    grep -qxF -- "$nome" "$BANIDOS_TXT" || printf '%s\n' "$nome" >> "$BANIDOS_TXT"
  else
    meow_aviso "não achei $pasta_lista — o banimento de $nome vale só nesta máquina"
  fi
  meow_ok "banida: $nome — está em banidos/, não foi apagada"
  cmd_aplicar >/dev/null
  forcar_releitura
  return "$MEOW_DIVERGENTE"
}

_adicionar_uma() {
  local img="$1"
  if meow_seco; then
    [ -e "$ATIVOS/$(basename "$img")" ] && return 1
    meow_muda "copiaria $(basename "$img") para ativos/"
    return 0
  fi
  [ -e "$ATIVOS/$(basename "$img")" ] && return 1
  meow_guardar_antes "$ATIVOS/$(basename "$img")"
  cp -n "$img" "$ATIVOS/" 2>/dev/null || return 1
  return 0
}

cmd_desbanir() {
  local nome; nome="$(basename "${1:-}")"
  [ -n "$nome" ] || { meow_erro "uso: wallpaper.sh desbanir <nome-do-arquivo>"; return "$MEOW_ERRO"; }
  local origem="$BASE/banidos/$nome"
  if [ ! -f "$origem" ] && [ ! -e "$ATIVOS/$nome" ]; then
    meow_erro "não achei $nome em banidos/"
    meow_info "  o nome é o do ARQUIVO, sem caminho — veja: ls \"$BASE/banidos\""
    return "$MEOW_ERRO"
  fi

  local na_lista=0
  [ -f "$BANIDOS_TXT" ] && grep -qxF -- "$nome" "$BANIDOS_TXT" && na_lista=1
  local em_ativos=0
  [ -e "$ATIVOS/$nome" ] && em_ativos=1

  if [ "$em_ativos" = "1" ] && [ "$na_lista" = "0" ]; then
    meow_ok "$nome já está em ativos/ e fora da lista — nada a fazer"
    return "$MEOW_OK"
  fi

  if meow_seco; then
    [ "$em_ativos" = "0" ] && meow_muda "devolveria $nome para ativos/"
    [ "$na_lista" = "1" ]  && meow_muda "tiraria $nome de $(basename "$BANIDOS_TXT")"
    return "$MEOW_DIVERGENTE"
  fi

  criar_pastas
  if [ "$em_ativos" = "0" ]; then
    cp -n "$origem" "$ATIVOS/" 2>/dev/null || { meow_erro "não consegui copiar $nome"; return "$MEOW_ERRO"; }
  fi

  if [ "$na_lista" = "1" ]; then
    local tmp; tmp="$(mktemp -p "$(dirname "$BANIDOS_TXT")" ".atomicwrite.meow.XXXXXX")" || return "$MEOW_ERRO"
    grep -vxF -- "$nome" "$BANIDOS_TXT" > "$tmp" 2>/dev/null
    meow_guardar_antes "$BANIDOS_TXT"
    mv -f "$tmp" "$BANIDOS_TXT" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  fi

  meow_ok "devolvida: $nome — está em ativos/ e saiu da lista de recusadas"
  cmd_aplicar >/dev/null
  forcar_releitura
  return "$MEOW_DIVERGENTE"
}

cmd_lado() {
  local ref="${1:-}" escolha="${2:-}"
  if [ -z "$ref" ] || [ -z "$escolha" ]; then
    meow_erro "uso: wallpaper.sh lado <arquivo|nome> dia|noite|auto"
    meow_info "  dia    a imagem fica no grupo do dia, custe o que custar a medição"
    meow_info "  noite  a imagem fica no grupo da noite"
    meow_info "  auto   devolve a decisão para a luminância (apaga a linha)"
    return "$MEOW_ERRO"
  fi
  case "$escolha" in
    dia|noite|auto) ;;
    *) meow_erro "não conheço o lado \"$escolha\" — é dia, noite ou auto"
       return "$MEOW_ERRO" ;;
  esac

  local nome TAB=$'\t' NL=$'\n'
  nome="$(basename -- "$ref")"
  case "$nome" in
    ''|.|..) meow_erro "\"$ref\" não é nome de imagem"; return "$MEOW_ERRO" ;;
    *"$TAB"*|*"$NL"*)
      meow_erro "o nome tem tab ou quebra de linha — não dá para registrar o lado dele"
      return "$MEOW_ERRO" ;;
  esac

  if [ ! -f "$ATIVOS/$nome" ]; then
    meow_erro "não achei $nome em ativos/"
    if [ -f "$BASE/banidos/$nome" ]; then
      meow_info "  ela está em banidos/ — devolva antes: meow wallpaper desbanir \"$nome\""
    else
      meow_info "  o lado se escolhe para imagem do acervo — veja: ls \"$ATIVOS\""
    fi
    return "$MEOW_ERRO"
  fi

  ler_lado
  local antes="${LADO[$nome]:-auto}"
  if [ "$antes" = "$escolha" ]; then
    if [ "$escolha" = "auto" ]; then
      meow_ok "$nome já é decidida pela medição — nada a fazer"
    else
      meow_ok "$nome já está escrita como $escolha — nada a fazer"
    fi
    return "$MEOW_OK"
  fi

  if meow_seco; then
    if [ "$escolha" = "auto" ]; then
      meow_muda "tiraria $nome de $(basename "$LADO_TSV") — a medição voltaria a decidir"
    else
      meow_muda "gravaria $nome como $escolha em $(basename "$LADO_TSV")"
    fi
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$escolha" = "auto" ]; then
    _lado_esquecer "$nome"
  else
    LADO["$nome"]="$escolha"
  fi
  gravar_lado || { meow_erro "não consegui gravar $LADO_TSV"; return "$MEOW_ERRO"; }

  if [ "$escolha" = "auto" ]; then
    meow_ok "$nome volta para a medição (limiar $LIMIAR_LUZ decide de novo)"
  else
    meow_ok "$nome fica no grupo de $escolha — escolha sua, a medição não decide mais por ela"
  fi

  [ "$NOITE" = "sim" ] || \
    meow_aviso "a noite está desligada (WALLPAPER_NOITE=\"$NOITE\") — a escolha fica guardada e só separa alguma coisa quando você religar"

  cmd_aplicar >/dev/null || true
  forcar_releitura
  return "$MEOW_DIVERGENTE"
}

cmd_adicionar() {
  local alvo="$1"
  criar_pastas
  local n=0
  if [ -d "$alvo" ]; then
    while IFS= read -r img; do
      _adicionar_uma "$img" && n=$((n + 1))
    done < <(find "$alvo" -maxdepth 1 -type f \
               \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \))
  elif [ -f "$alvo" ]; then
    _adicionar_uma "$alvo" && n=1
  else
    meow_erro "não achei $alvo"; return "$MEOW_ERRO"
  fi
  if [ "$n" = "0" ]; then
    meow_pula "nenhuma imagem nova (as que você passou já estavam em ativos/)"
    return "$MEOW_OK"
  fi
  meow_ok "$n imagem(ns) adicionada(s)"
  cmd_aplicar >/dev/null
  forcar_releitura
  return "$MEOW_DIVERGENTE"
}

_semente_do_flavor() {
  local linhas chave valor repo="" commit="" desenhos="" prefixo="" ignorar="" curadoria="" fotos=""
  local repo_conf="" commit_conf=""
  _PACK_NO_AR="$(meow_pack_dir)"
  linhas="$(python3 "$RAIZ/scripts/pack.py" wallpapers "$_PACK_NO_AR" 2>/dev/null)" || linhas=""
  while IFS='=' read -r chave valor; do
    case "$chave" in
      repo) repo="$valor" ;; commit) commit="$valor" ;; desenhos) desenhos="$valor" ;;
      prefixo) prefixo="$valor" ;; ignorar) ignorar="$valor" ;; curadoria) curadoria="$valor" ;;
      fotos) fotos="$valor" ;;
      repo_do_conf)   [[ "$valor" =~ ^WALLPAPER_[A-Z0-9_]*_REPO$ ]] && repo_conf="${!valor:-}" ;;
      commit_do_conf) [[ "$valor" =~ ^WALLPAPER_[A-Z0-9_]*_COMMIT$ ]] && commit_conf="${!valor:-}" ;;
    esac
  done <<< "$linhas"
  SEMENTE_PREFIXO_PADRAO="${prefixo:-cat}"
  SEMENTE_IGNORAR_PADRAO=""
  SEMENTE_CURADORIA_PADRAO="$curadoria"
  if [ -n "$fotos" ]; then
    local real pai
    real="$(realpath -e -- "$fotos" 2>/dev/null)" || real=""
    pai="$(realpath -e -- "${fotos%/*}" 2>/dev/null)" || pai=""
    if [ -z "$real" ] || [ "$real" != "$pai/wallpapers" ] || [ ! -f "$pai/pack.json" ]; then
      meow_aviso "as fotos do pack não estão na pasta wallpapers/ dele — ignoradas"
      fotos=""
    fi
  fi
  SEMENTE_FOTOS_PADRAO="$fotos"
  if [ -n "$repo_conf" ]; then
    SEMENTE_REPO_PADRAO="$repo_conf"
    SEMENTE_COMMIT_PADRAO="$commit_conf"
    SEMENTE_IGNORAR_PADRAO="$ignorar"
    if [ -z "$SEMENTE_COMMIT_PADRAO" ] && ! _semente_e_pasta "$SEMENTE_REPO_PADRAO"; then
      meow_aviso "o repositório de papel de parede do conf está sem commit — sem pino não há receita"
    fi
  elif [ -n "$desenhos" ] && [ -d "$desenhos" ]; then
    SEMENTE_REPO_PADRAO="${desenhos%/}"
    SEMENTE_COMMIT_PADRAO=""
  else
    SEMENTE_REPO_PADRAO="$repo"
    SEMENTE_COMMIT_PADRAO="$commit"
  fi
}

_semente_e_pasta() {
  case "$1" in
    /*|'~'/*|./*|../*) return 0 ;;
    *) return 1 ;;
  esac
}
_semente_do_flavor

SEMENTE_REPO="${WALLPAPER_SEMENTE_REPO:-$SEMENTE_REPO_PADRAO}"
SEMENTE_COMMIT="${WALLPAPER_SEMENTE_COMMIT:-$SEMENTE_COMMIT_PADRAO}"
SEMENTE_IGNORAR="${WALLPAPER_SEMENTE_IGNORAR:-$SEMENTE_IGNORAR_PADRAO}"
SEMENTE_FOTOS="$SEMENTE_FOTOS_PADRAO"
[ -n "${WALLPAPER_SEMENTE_REPO:-}" ] && SEMENTE_FOTOS=""
SEMENTE_PREFIXO="${WALLPAPER_SEMENTE_PREFIXO:-$SEMENTE_PREFIXO_PADRAO}"
SEMENTE_QUANTAS="${WALLPAPER_SEMENTE_QUANTAS:-0}"

BANIDOS_TXT="${WALLPAPER_BANIDOS:-$(meow_estado_com_padrao papeis-de-parede BANIDOS.txt)}"

esta_banida() {
  local nome="$1"
  [ -e "$BASE/banidos/$nome" ] && return 0
  [ -f "$BANIDOS_TXT" ] && grep -qxF -- "$nome" "$BANIDOS_TXT" && return 0
  return 1
}

FONTES_TSV="${WALLPAPER_FONTES:-$SEMENTE_CURADORIA_PADRAO}"
CURADORIA_N=0

semear_da_curadoria() {
  CURADORIA_N=0
  [ -f "$FONTES_TSV" ] || return 0
  local validas descartadas
  validas="$(awk -F'\t' '$1 !~ /^#/ && $1 != "arquivo" && $1 != "" && NF >= 3 && $3 ~ /^https:\/\// && $1 ~ /^[A-Za-z0-9][A-Za-z0-9._+-]*$/ && $1 !~ /\.\./ {print $1 "\037" $3}' "$FONTES_TSV")"
  descartadas="$(awk -F'\t' '$1 !~ /^#/ && $1 != "arquivo" && $1 != "" && !(NF >= 3 && $3 ~ /^https:\/\// && $1 ~ /^[A-Za-z0-9][A-Za-z0-9._+-]*$/ && $1 !~ /\.\./) {n++} END {print n+0}' "$FONTES_TSV")"
  if [ "$descartadas" -gt 0 ]; then
    meow_aviso "$descartadas linha(s) de $(basename "$FONTES_TSV") com nome ou URL fora da regra — ignoradas"
  fi
  [ -n "$validas" ] || return 0

  local falhas=0 nome url
  while IFS=$'\037' read -r nome url; do
    [ -n "$nome" ] && [[ $url == https://* ]] || continue
    local destino="$ATIVOS/$nome"
    [ "$(realpath -m -- "$destino")" = "$(realpath -m -- "$ATIVOS")/$nome" ] || continue
    [ -e "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then
      meow_muda "baixaria $nome (curadoria)"; CURADORIA_N=$((CURADORIA_N + 1)); continue
    fi
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if curl -sSL --max-time 90 --proto '=https' --proto-redir '=https' -o "$tmp" -- "$url" 2>/dev/null && [ -s "$tmp" ]; then
      meow_guardar_antes "$destino"; mv -f "$tmp" "$destino"; CURADORIA_N=$((CURADORIA_N + 1))
    else
      rm -f "$tmp"; falhas=$((falhas + 1))
    fi
  done <<< "$validas"
  [ "$falhas" -gt 0 ] && meow_aviso "$falhas imagem(ns) da curadoria não baixaram — a próxima passada tenta de novo"
  return 0
}

_semear_de_pasta() {
  local origem="${1/#\~/$HOME}"
  if [ ! -d "$origem" ]; then
    meow_erro "semente '$origem' não é um diretório"
    return "$MEOW_ERRO"
  fi

  local n=0 ignorados=0 svg_sem=0 arq rel nome destino vetor
  while IFS= read -r arq; do
    [ -n "$arq" ] || continue
    rel="${arq#"$origem"/}"
    vetor=0
    case "${rel##*.}" in
      png|PNG|jpg|JPG|jpeg|JPEG|webp|WEBP|avif|AVIF|gif|GIF|tif|tiff|TIF|TIFF) ;;
      svg|SVG) if meow_tem rsvg-convert; then vetor=1; else svg_sem=$((svg_sem + 1)); continue; fi ;;
      LICENSE|md|txt) continue ;;
      *) ignorados=$((ignorados + 1)); continue ;;
    esac
    nome="${SEMENTE_PREFIXO}-${rel//\//-}"
    [ "$vetor" = 1 ] && nome="${nome%.*}.png"
    destino="$ATIVOS/$nome"
    [ -e "$destino" ] && [ ! "$arq" -nt "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then
      if [ "$vetor" = 1 ]; then meow_muda "rasterizaria $nome em 4K"; else meow_muda "copiaria $nome"; fi
      n=$((n + 1)); continue
    fi
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if [ "$vetor" = 1 ]; then
      if rsvg-convert -w 3840 -h 2160 -f png -o "$tmp" -- "$arq" 2>/dev/null && [ -s "$tmp" ]; then
        meow_guardar_antes "$destino"; mv -f "$tmp" "$destino"; n=$((n + 1))
      else
        rm -f "$tmp"
        meow_aviso "não consegui rasterizar $rel"
      fi
      continue
    fi
    if cp -- "$arq" "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      meow_guardar_antes "$destino"; mv -f "$tmp" "$destino"; n=$((n + 1))
    else
      rm -f "$tmp"
      meow_aviso "não consegui copiar $rel"
    fi
  done < <(find "$origem" -type f 2>/dev/null | LC_ALL=C sort)

  if [ "$ignorados" -gt 0 ]; then
    meow_info "$ignorados arquivo(s) de formato que o cosmic-bg não lê foram ignorados"
  fi
  if [ "$svg_sem" -gt 0 ]; then
    meow_aviso "$svg_sem SVG ficaram de fora: sem o rsvg-convert não há como rasterizá-los"
  fi

  semear_da_curadoria
  if [ "$CURADORIA_N" -gt 0 ]; then
    if meow_seco; then
      meow_muda "reproduziria $CURADORIA_N imagem(ns) da curadoria (packs/meowsystem/wallpapers/FONTES.tsv)"
    else
      meow_ok "$CURADORIA_N imagem(ns) da curadoria reproduzidas (packs/meowsystem/wallpapers/FONTES.tsv)"
    fi
    n=$((n + CURADORIA_N))
  fi

  if [ "$n" -eq 0 ]; then
    meow_ok "pasta-semente já semeada ($origem)"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "copiaria $n imagem(ns) da pasta $origem"
  else
    meow_ok "$n imagem(ns) copiadas da pasta $origem"
  fi
  return "$MEOW_OK"
}

cmd_semear_se_faltar() {
  local n marca="$MEOW_ESTADO/wallpaper-semeado" rc origem="${SEMENTE_FOTOS:-$SEMENTE_REPO}"
  [ -n "$origem" ] || return "$MEOW_OK"
  compgen -G "$ATIVOS/${SEMENTE_PREFIXO}-*" >/dev/null && return "$MEOW_OK"
  n="$(quantas 2>/dev/null)"; n="${n:-0}"
  [ "$n" -lt 2 ] || [ "$(cat "$marca" 2>/dev/null)" != "$origem" ] || return "$MEOW_OK"
  if meow_seco; then
    if [ -n "$SEMENTE_FOTOS" ]; then
      meow_muda "semearia as fotos do pack no ar"
    else
      meow_muda "semearia os papéis de parede do pack no ar (precisa de rede)"
    fi
    return "$MEOW_DIVERGENTE"
  fi
  cmd_semear; rc=$?
  mkdir -p "$MEOW_ESTADO" && printf '%s\n' "$origem" > "$marca"
  return "$rc"
}

_semear_fotos() {
  local origem="$1" n=0 arq nome destino tmp
  while IFS= read -r -d '' arq; do
    nome="${arq##*/}"
    [[ "$nome" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || continue
    case "${nome##*.}" in png|PNG|jpg|JPG|jpeg|JPEG|webp|WEBP) ;; *) continue ;; esac
    destino="$ATIVOS/$nome"
    [ -e "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then meow_muda "copiaria $nome (foto do pack)"; n=$((n + 1)); continue; fi
    tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")" || return "$MEOW_ERRO"
    if cp -- "$arq" "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      meow_guardar_antes "$destino"; mv -f "$tmp" "$destino"; n=$((n + 1))
    else
      rm -f "$tmp"; meow_aviso "não consegui copiar $nome"
    fi
  done < <(find "$origem" -maxdepth 1 -type f -print0 2>/dev/null | LC_ALL=C sort -z)
  if [ "$n" -eq 0 ]; then
    meow_ok "coleção do pack já semeada ($origem)"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "copiaria $n foto(s) do pack ($origem)"
  else
    meow_ok "$n foto(s) do pack copiadas ($origem)"
  fi
  return "$MEOW_DIVERGENTE"
}

cmd_semear() {
  meow_tem python3 || { meow_erro "python3 não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  criar_pastas

  if [ -n "$SEMENTE_FOTOS" ]; then
    _semear_fotos "$SEMENTE_FOTOS"
    return $?
  fi

  if [ -z "$SEMENTE_REPO" ]; then
    meow_pula "o pack no ar não declara de onde descem os papéis de parede"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if _semente_e_pasta "$SEMENTE_REPO"; then
    _semear_de_pasta "$SEMENTE_REPO"
    return $?
  fi

  meow_tem curl || { meow_erro "curl não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }

  local api="https://api.github.com/repos/$SEMENTE_REPO/git/trees/$SEMENTE_COMMIT?recursive=1"
  local lista; lista="$(curl -sS --max-time 30 "$api" 2>/dev/null)" || {
    meow_aviso "não consegui falar com o GitHub — semeadura pulada"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  local escolhidas
  escolhidas="$(printf '%s' "$lista" | python3 -I -c "
import json, sys
from urllib.parse import quote
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if 'tree' not in d:
    sys.exit(1)
ignorar = set('$SEMENTE_IGNORAR'.split())
imgs = [t['path'] for t in d['tree']
        if t.get('type') == 'blob' and t['path'].lower().endswith(('.png', '.jpg', '.jpeg'))
        and t['path'].split('/')[0] not in ignorar]
por_pasta = {}
for p in imgs:
    por_pasta.setdefault(p.split('/')[0], []).append(p)
# rodízio entre as pastas: uma de cada, depois a segunda de cada, e assim por diante
limite = $SEMENTE_QUANTAS or len(imgs)
saida, i = [], 0
while len(saida) < limite:
    houve = False
    for pasta in sorted(por_pasta):
        if i < len(por_pasta[pasta]):
            saida.append(por_pasta[pasta][i]); houve = True
            if len(saida) >= limite: break
    if not houve: break
    i += 1
print('\n'.join(p + '\t' + quote(p, safe='/') for p in saida))
")" || { meow_aviso "resposta do GitHub inesperada — semeadura pulada"; return "$MEOW_SEM_DEPENDENCIA"; }

  [ -n "$escolhidas" ] || { meow_aviso "nenhuma imagem encontrada"; return "$MEOW_SEM_DEPENDENCIA"; }

  local n=0 falhas=0 base="https://raw.githubusercontent.com/$SEMENTE_REPO/$SEMENTE_COMMIT"
  while IFS=$'\t' read -r caminho caminho_url; do
    [ -n "$caminho" ] || continue
    local nome="${SEMENTE_PREFIXO}-${caminho//\//-}"
    local destino="$ATIVOS/$nome"
    [ -e "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then
      meow_muda "baixaria $nome"; n=$((n+1)); continue
    fi
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if curl -sSL --max-time 60 -o "$tmp" "$base/$caminho_url" 2>/dev/null && [ -s "$tmp" ]; then
      meow_guardar_antes "$destino"; mv -f "$tmp" "$destino"; n=$((n+1))
    else
      rm -f "$tmp"; falhas=$((falhas + 1))
    fi
  done <<< "$escolhidas"

  [ "$falhas" -gt 0 ] && meow_aviso "$falhas imagem(ns) não baixaram — a próxima passada tenta de novo"

  semear_da_curadoria
  if [ "$CURADORIA_N" -gt 0 ]; then
    if meow_seco; then
      meow_muda "reproduziria $CURADORIA_N imagem(ns) da curadoria (packs/meowsystem/wallpapers/FONTES.tsv)"
    else
      meow_ok "$CURADORIA_N imagem(ns) da curadoria reproduzidas (packs/meowsystem/wallpapers/FONTES.tsv)"
    fi
    n=$((n + CURADORIA_N))
  fi

  if [ "$n" -eq 0 ]; then
    meow_ok "coleção da semente já semeada (${SEMENTE_REPO})"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "baixaria $n imagem(ns) da semente (${SEMENTE_REPO}@${SEMENTE_COMMIT:0:8})"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "$n imagem(ns) da semente baixadas (${SEMENTE_REPO}@${SEMENTE_COMMIT:0:8})"
  meow_seco || cmd_aplicar >/dev/null
  return "$MEOW_DIVERGENTE"
}

cmd_passo() {
  local delta="$1" dir lista n atual i alvo
  criar_pastas || { meow_erro "não consegui criar as pastas"; return "$MEOW_ERRO"; }
  resolver_rotacao

  if   [ -d "$NOITE_DIR" ] && [ "$GRUPO" != "dia" ] && e_noite; then dir="$NOITE_DIR"
  elif [ -d "$DIA_DIR" ]   && ! e_noite;                        then dir="$DIA_DIR"
  else dir="$ROTACAO_BASE"; fi
  [ -d "$dir" ] || dir="$ATIVOS"

  mapfile -t lista < <(lista_do_grupo "$dir")
  n="${#lista[@]}"
  if [ "$n" -lt 2 ]; then
    meow_aviso "só $n imagem(ns) em $(basename "$dir") — não há para onde avançar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  atual="$(imagem_atual || true)"
  i=-1
  if [ -n "$atual" ]; then
    local j
    for j in "${!lista[@]}"; do
      [ "$(basename "${lista[$j]}")" = "$(basename "$atual")" ] && { i="$j"; break; }
    done
  fi
  if [ "$i" -lt 0 ]; then
    [ "$delta" -gt 0 ] && i=-1 || i=0
  fi

  alvo=$(( ( (i + delta) % n + n ) % n ))

  if meow_seco; then
    meow_muda "fixaria $(basename "${lista[$alvo]}") (${alvo_1:-$((alvo + 1))} de $n, grupo $(basename "$dir"))"
    return "$MEOW_DIVERGENTE"
  fi

  gravar_fixo "${lista[$alvo]}"
  cmd_aplicar >/dev/null || true
  meow_ok "papel de parede: $(basename "${lista[$alvo]}")  [$((alvo + 1))/$n · grupo $(basename "$dir")]"
  if [ "$(segundos_de "$FIXO_TTL")" -gt 0 ]; then
    meow_info "  o carrossel volta em $FIXO_TTL, ou antes, no «Voltar a girar»"
  else
    meow_info "  fixado até você soltar, no «Voltar a girar»"
  fi
  return "$MEOW_DIVERGENTE"
}

cmd_usar() {
  local img="$1"
  [ -f "$img" ] || { meow_erro "não achei $img"; return "$MEOW_ERRO"; }
  if meow_seco; then
    meow_muda "fixaria $(basename "$img") como o papel de parede de agora"
    return "$MEOW_DIVERGENTE"
  fi
  criar_pastas || { meow_erro "não consegui criar as pastas"; return "$MEOW_ERRO"; }
  gravar_fixo "$img"
  cmd_aplicar >/dev/null || true
  meow_ok "papel de parede: $(basename "$img")"
  if [ "$(segundos_de "$FIXO_TTL")" -gt 0 ]; then
    meow_info "  o carrossel volta em $FIXO_TTL, ou antes, no «Voltar a girar»"
  else
    meow_info "  fixado até você soltar, no «Voltar a girar»"
  fi
  return "$MEOW_DIVERGENTE"
}

cmd_carrossel() {
  if [ ! -f "$FIXADO" ]; then
    meow_ok "o carrossel já está girando — nada fixado"
    return "$MEOW_OK"
  fi
  if meow_seco; then meow_muda "soltaria a fixação e devolveria o carrossel"; return "$MEOW_DIVERGENTE"; fi
  soltar_fixo
  cmd_aplicar >/dev/null || true
  meow_ok "carrossel de volta"
  return "$MEOW_DIVERGENTE"
}

cmd_favoritar() {
  local img="${1:-}" nome
  [ -f "$img" ] || { meow_erro "não achei ${img:-a imagem}"; return "$MEOW_ERRO"; }
  nome="$(basename "$img")"
  if [ -f "$BASE/favoritos/$nome" ] && cmp -s "$img" "$BASE/favoritos/$nome"; then
    meow_ok "$nome já está nas favoritas"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "guardaria uma cópia de $nome nas favoritas"
    return "$MEOW_DIVERGENTE"
  fi
  criar_pastas || return "$MEOW_ERRO"
  meow_guardar_antes "$BASE/favoritos/$nome"
  cp -f -- "$img" "$BASE/favoritos/$nome" || return "$MEOW_ERRO"
  meow_ok "favorita: $nome — a cópia está em favoritos/, e ela segue girando"
  return "$MEOW_DIVERGENTE"
}

cmd_desfavoritar() {
  local nome="${1:-}"
  case "$nome" in
    ''|*/*|.|..) meow_erro "o nome é o do arquivo, sem caminho"; return "$MEOW_ERRO" ;;
  esac
  if [ ! -f "$BASE/favoritos/$nome" ]; then
    meow_ok "$nome não está nas favoritas — nada a fazer"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "tiraria $nome das favoritas (a imagem de ativos/ fica)"
    return "$MEOW_DIVERGENTE"
  fi
  meow_guardar_antes "$BASE/favoritos/$nome"
  rm -f -- "$BASE/favoritos/$nome" || return "$MEOW_ERRO"
  meow_ok "$nome saiu das favoritas; a imagem de ativos/ fica"
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)   cmd_aplicar ;;
  proximo|próximo|avançar|avancar)  cmd_passo 1 ;;
  anterior|voltar)                  cmd_passo -1 ;;
  carrossel|soltar)                 cmd_carrossel ;;
  --conferir|conferir) MEOW_SECO=1; cmd_aplicar ;;
  estado)    cmd_estado ;;
  semear)    cmd_semear ;;
  semear-se-faltar) cmd_semear_se_faltar ;;
  banir)     shift; cmd_banir "${1:-}" ;;
  desbanir)  shift; cmd_desbanir "${1:-}" ;;
  adicionar) shift; cmd_adicionar "${1:-}" ;;
  permitir)  shift; cmd_permitir "${1:-}" ;;
  dispensar) cmd_dispensar ;;
  lado)      shift; cmd_lado "${1:-}" "${2:-}" ;;
  usar)      shift; cmd_usar "${1:-}" ;;
  favoritar)    shift; cmd_favoritar "${1:-}" ;;
  desfavoritar) shift; cmd_desfavoritar "${1:-}" ;;
  *) echo "uso: wallpaper.sh [aplicar|proximo|anterior|usar <img>|carrossel|--conferir|estado|semear|adicionar <alvo>|banir <img>|desbanir <nome>|favoritar <img>|desfavoritar <nome>|permitir <caminho>|lado <img> dia|noite|auto]" >&2; exit 2 ;;
esac

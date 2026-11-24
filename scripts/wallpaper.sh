#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/comum.sh
. "$RAIZ/scripts/lib/comum.sh"
. "$RAIZ/scripts/lib/noite.sh"

BASE="${WALLPAPER_BASE:-$HOME/.local/share/backgrounds/meowsystem}"
MINHAS="$BASE/Minhas"
GIRANDO="$BASE/.girando"
PASTA_PACK=""
PASTAS_QUE_GIRAM=("$MINHAS")
PASTAS_DE_ANTES=(ativos ativos-dia ativos-noite ativos-pack)
BG="$(meow_cosmic_dir)/com.system76.CosmicBackground/$(meow_cosmic_v com.system76.CosmicBackground)"
ORDEM="${WALLPAPER_ORDEM:-aleatoria}"
INTERVALO="${WALLPAPER_INTERVALO:-5m}"

ROTACAO="$GIRANDO"
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

JANELA_DO_MASCOTE="$(meow_noite_janela)"
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
  for p in "${PASTAS_QUE_GIRAM[@]}"; do
    [ -d "$p" ] && continue
    meow_seco && { meow_muda "criaria $p"; continue; }
    mkdir -p "$p" || return "$MEOW_ERRO"
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
    local destino="$MINHAS/$nome_dela"
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

quantas() { find "${PASTAS_QUE_GIRAM[@]}" -maxdepth 1 -type f 2>/dev/null | wc -l; }

declare -A CAMINHO=()
COLECAO=()
ler_colecao() {
  CAMINHO=(); COLECAO=()
  local d arq base
  for d in "${PASTAS_QUE_GIRAM[@]}"; do
    for arq in "$d"/*; do
      [ -f "$arq" ] || continue
      base="${arq##*/}"
      [ -n "${CAMINHO[$base]:-}" ] && continue
      CAMINHO["$base"]="$arq"; COLECAO+=("$base")
    done
  done
}

pasta_do_acervo() {
  case "$1" in
    ''|.*|*/*) return 1 ;;
    Minhas) return 0 ;;
    ativos|ativos-dia|ativos-noite|ativos-pack|originais|banidos|favoritos) return 1 ;;
  esac
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

papeis_da_base() {
  local d arq
  for d in "$BASE"/*/; do
    d="${d%/}"
    pasta_do_acervo "${d##*/}" || continue
    for arq in "$d"/*; do
      [ -f "$arq" ] || continue
      case "${arq##*/}" in .meow.*) continue ;; esac
      printf '%s\n' "${d##*/}/${arq##*/}"
    done
  done | LC_ALL=C sort
}

no_acervo() {
  local f
  for f in "$BASE"/*/"$1"; do
    [ -f "$f" ] || continue
    f="${f%/*}"
    pasta_do_acervo "${f##*/}" && return 0
  done
  return 1
}

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
  for base in ${COLECAO[@]+"${COLECAO[@]}"}; do
    arq="${CAMINHO[$base]}"
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
  conteudo="# wallpaper-luz.tsv — a luminância perceptual (Rec.709) de cada papel que gira.$NL"
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

montar_girando() {
  local -A quer=()
  local base arq
  for base in "$@"; do quer["$base"]=1; done

  mkdir -p "$GIRANDO" || { meow_erro "não consegui criar $GIRANDO"; return 1; }

  for arq in "$GIRANDO"/* "$GIRANDO"/.[!.]*; do
    [ -e "$arq" ] || [ -L "$arq" ] || continue
    base="${arq##*/}"
    [ -n "${quer[$base]:-}" ] && [ "$arq" -ef "${CAMINHO[$base]}" ] && continue
    meow_guardar_antes "$arq"
    rm -f -- "$arq"
  done

  for base in "$@"; do
    [ -e "$GIRANDO/$base" ] && continue
    meow_guardar_antes "$GIRANDO/$base"
    ln -f -- "${CAMINHO[$base]}" "$GIRANDO/$base" 2>/dev/null && continue
    ln -sfn -- "${CAMINHO[$base]}" "$GIRANDO/$base" 2>/dev/null || return 1
  done
  return 0
}

girando_agora() {
  local arq
  for arq in "$GIRANDO"/*; do
    [ -e "$arq" ] || [ -L "$arq" ] || continue
    printf '%s\t%s\n' "${arq##*/}" "$(stat -L -c '%d:%i' -- "$arq" 2>/dev/null)"
  done | LC_ALL=C sort
}

girando_quer() {
  local base
  for base in "$@"; do
    printf '%s\t%s\n' "$base" "$(stat -L -c '%d:%i' -- "${CAMINHO[$base]}" 2>/dev/null)"
  done | LC_ALL=C sort
}

case "${1:-aplicar}" in estado|base) MEOW_ESTADO_SO_LE=1 ;; esac
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
    if no_acervo "$base"; then
      vivas["$base"]="${LADO[$base]}"
    else
      mortas+=("$base")
    fi
  done
  [ "${#mortas[@]}" = "0" ] && return 0

  if meow_seco; then
    meow_muda "tiraria ${#mortas[@]} linha(s) de $(basename "$LADO_TSV") — não estão mais no acervo"
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

declare -A PAR=() LADO_DO_PAR=()

nome_do_papel() {
  local nome="${1//\//-}"
  case "${nome##*.}" in svg|SVG) nome="${nome%.*}.png" ;; esac
  printf '%s' "$nome"
}

ler_pares() {
  PAR=(); LADO_DO_PAR=()
  local _cena dia noite
  while IFS=$'\t' read -r _cena dia noite; do
    [ -n "$dia" ] && [ -n "$noite" ] || continue
    dia="$(nome_do_papel "$dia")"; noite="$(nome_do_papel "$noite")"
    [ -n "${CAMINHO[$dia]:-}" ] && [ -n "${CAMINHO[$noite]:-}" ] || continue
    PAR["$dia"]="$noite"; PAR["$noite"]="$dia"
    LADO_DO_PAR["$dia"]=dia; LADO_DO_PAR["$noite"]=noite
  done < <(python3 "$RAIZ/scripts/pack.py" pares "$_PACK_NO_AR" 2>/dev/null)
  return 0
}

trocar_pelo_par() {
  [ "${#PAR[@]}" -gt 0 ] || return 0
  local fase atual base par quando ttl intervalo agora ini fim _fonte
  read -r ini fim _fonte <<< "$JANELA_DO_MASCOTE"
  fase="$(meow_fase_da_hora "$ini" "$fim")"
  agora="$(date +%s)"
  if atual="$(fixo_valido)"; then
    quando="$(cut -f2 "$FIXADO" 2>/dev/null)"
  elif atual="$(imagem_atual)"; then
    ttl="$(segundos_de "$FIXO_TTL")"; intervalo="$(segundos_de "$INTERVALO")"
    [ "$ttl" -gt 0 ] || return 0
    quando=$(( agora - (ttl > intervalo ? ttl - intervalo : 0) ))
  else
    return 0
  fi
  base="${atual##*/}"; par="${PAR[$base]:-}"
  [ -n "$par" ] && [ "${LADO_DO_PAR[$base]}" != "$fase" ] || return 0
  if meow_seco; then
    meow_muda "trocaria $base pelo par de $fase, $par"
    return 0
  fi
  printf '%s\t%s\n' "${CAMINHO[$par]}" "$quando" > "$FIXADO" 2>/dev/null || return 0
  meow_info "$fase: $base deu lugar ao par, $par"
  return 0
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

  trocar_pelo_par

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

GIRANDO_MUDOU=0
GRUPOS_TSV="$MEOW_ESTADO/wallpaper-grupos.tsv"

gravar_grupos() {
  local conteudo tmp
  conteudo="$([ "$#" -gt 0 ] && printf '%s\n' "$@" | LC_ALL=C sort)"
  if [ -z "$conteudo" ]; then
    [ -f "$GRUPOS_TSV" ] && rm -f -- "$GRUPOS_TSV"
    return 0
  fi
  [ -f "$GRUPOS_TSV" ] && [ "$conteudo" = "$(cat "$GRUPOS_TSV" 2>/dev/null)" ] && return 0
  mkdir -p "$(dirname "$GRUPOS_TSV")" 2>/dev/null || return 0
  tmp="$(mktemp -p "$(dirname "$GRUPOS_TSV")" ".meow.XXXXXX" 2>/dev/null)" || return 0
  printf '%s\n' "$conteudo" > "$tmp" && mv -f "$tmp" "$GRUPOS_TSV" 2>/dev/null || rm -f "$tmp"
  return 0
}

_resolver_grupo() {
  ler_colecao
  ROTACAO="$GIRANDO"; GRUPO=""; NOITE_N=0; DIA_N=0
  local -a lista=() escuros=() claros=()
  local base

  if [ "$NOITE" = "sim" ]; then
    ler_pares
    local lim; lim="$(milesimos_de "$LIMIAR_LUZ")"
    if [ "$lim" -le 0 ] || [ "$lim" -ge 10000 ]; then
      meow_aviso "WALLPAPER_LIMIAR_LUZ=\"$LIMIAR_LUZ\" fora de 0-1; usando 0.37"
      LIMIAR_LUZ="0.37"; lim=3700
    fi

    medir_acervo
    ler_lado
    local por_escolha=0
    for base in "${!LADO_DO_PAR[@]}"; do
      [ -n "${LADO[$base]:-}" ] || LADO["$base"]="${LADO_DO_PAR[$base]}"
    done

    for base in ${COLECAO[@]+"${COLECAO[@]}"}; do
      case "${LADO[$base]:-}" in
        noite) escuros+=("$base"); por_escolha=$((por_escolha + 1)); continue ;;
        dia)   claros+=("$base");  por_escolha=$((por_escolha + 1)); continue ;;
      esac
      [ -n "${LUZ[$base]:-}" ] || continue
      if [ "$(milesimos_de "${LUZ[$base]}")" -lt "$lim" ]
        then escuros+=("$base")
        else claros+=("$base")
      fi
    done
    [ "$por_escolha" -gt 0 ] && \
      meow_debug "$por_escolha papel(is) de parede foram para o grupo por escolha escrita, não pela medição"
    NOITE_N="${#escuros[@]}"; DIA_N="${#claros[@]}"

    if [ $((NOITE_N + DIA_N)) -eq 0 ]; then
      meow_aviso "nenhum papel de parede medido — giram todos"
    else
      if e_noite; then GRUPO="noite"; lista=(${escuros[@]+"${escuros[@]}"})
      else             GRUPO="dia";   lista=(${claros[@]+"${claros[@]}"}); fi
      if [ "${#lista[@]}" -lt 2 ]; then
        meow_aviso "o grupo de $GRUPO ficou com ${#lista[@]} imagem(ns) (limiar $LIMIAR_LUZ) — giram todos"
        GRUPO=""; lista=()
      fi
    fi
    meow_seco || {
      local -a linhas=()
      for base in ${escuros[@]+"${escuros[@]}"}; do linhas+=("$base"$'\t'noite); done
      for base in ${claros[@]+"${claros[@]}"}; do linhas+=("$base"$'\t'dia); done
      gravar_grupos ${linhas[@]+"${linhas[@]}"}
    }
  else
    meow_seco || gravar_grupos
  fi
  [ "${#lista[@]}" -gt 0 ] || lista=(${COLECAO[@]+"${COLECAO[@]}"})

  [ "$(girando_agora)" = "$(girando_quer ${lista[@]+"${lista[@]}"})" ] && return 0
  GIRANDO_MUDOU=1
  if meow_seco; then
    meow_muda "poria ${#lista[@]} imagem(ns) para girar em $GIRANDO/"
    return 0
  fi
  montar_girando ${lista[@]+"${lista[@]}"} \
    || meow_aviso "não consegui montar $GIRANDO/ — o carrossel fica com o que já estava lá"
  return 0
}

fonte_nossa() {
  case "$1" in
    "$BASE"|"$BASE"/*) return 0 ;;
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

_gravar_vistas() {
  printf '%s\n' "$@" | cmp -s - "$VISTAS" 2>/dev/null && return 0
  printf '%s\n' "$@" > "$VISTAS" 2>/dev/null
}

reconciliar_sumicos() {
  local -a agora=() sumidas=()
  local nome n_antes n_agora

  mapfile -t agora < <(papeis_da_base)
  n_agora="${#agora[@]}"

  if [ ! -f "$VISTAS" ]; then
    meow_seco || _gravar_vistas ${agora[@]+"${agora[@]}"}
    return 0
  fi
  n_antes="$(grep -c . "$VISTAS" 2>/dev/null)"; n_antes="${n_antes:-0}"

  if [ "$n_agora" = "0" ] && [ "$n_antes" -gt 0 ]; then
    meow_aviso "a pasta do papel de parede está VAZIA e tinha $n_antes imagem(ns) — não vou banir nada"
    meow_info  "  isso é disco desmontado ou home ainda não montado, não curadoria"
    return 0
  fi

  mapfile -t sumidas < <(LC_ALL=C comm -23 <(grep -v '^\.meow\.' "$VISTAS" | LC_ALL=C sort -u) \
                                           <(printf '%s\n' ${agora[@]+"${agora[@]}"} | LC_ALL=C sort -u))
  [ "${#sumidas[@]}" = "0" ] && { meow_seco || _gravar_vistas ${agora[@]+"${agora[@]}"}; return 0; }

  if [ "$n_antes" -gt 4 ] && [ "${#sumidas[@]}" -gt $(( n_antes / 2 )) ]; then
    meow_aviso "${#sumidas[@]} de $n_antes imagens sumiram da pasta do papel de parede de uma vez — não vou banir nada"
    meow_info  "  se foi você, apague uma a uma pelo «Apagar», em Personalizar › Papel de parede"
    return 0
  fi

  local -a novas=()
  for nome in "${sumidas[@]}"; do
    nome="${nome#*/}"
    [ -f "$BANIDOS_TXT" ] && LC_ALL=C grep -qxF -- "$nome" "$BANIDOS_TXT" && continue
    no_acervo "$nome" && continue
    novas+=("$nome")
  done
  [ "${#novas[@]}" = "0" ] && { meow_seco || _gravar_vistas ${agora[@]+"${agora[@]}"}; return 0; }

  if meow_seco; then
    meow_muda "baniria ${#novas[@]} imagem(ns) apagada(s) à mão: ${novas[*]}"
    return 1
  fi

  mkdir -p "$(dirname "$BANIDOS_TXT")" 2>/dev/null
  [ -f "$BANIDOS_TXT" ] || printf '%s\n' \
    "# BANIDOS.txt — os papéis de parede que você recusou, por nome de arquivo." \
    "# O 'semear' não repõe nada que esteja aqui." > "$BANIDOS_TXT"
  for nome in "${novas[@]}"; do
    LC_ALL=C grep -qxF -- "$nome" "$BANIDOS_TXT" || printf '%s\n' "$nome" >> "$BANIDOS_TXT"
  done
  meow_ok "${#novas[@]} imagem(ns) apagada(s) à mão entraram no BANIDOS.txt — o semear não as repõe"
  meow_info "  ${novas[*]}"
  meow_registrar "wallpaper.sh auto-banir: ${novas[*]}"
  _gravar_vistas ${agora[@]+"${agora[@]}"}
  CUROU=1
  return 1
}

reconciliar_banidos_pasta() {
  [ -d "$BASE/banidos" ] || return 0
  local -a novas=()
  local nome
  while IFS= read -r nome; do
    [ -n "$nome" ] || continue
    [ -f "$BANIDOS_TXT" ] && LC_ALL=C grep -qxF -- "$nome" "$BANIDOS_TXT" && continue
    no_acervo "$nome" && continue
    novas+=("$nome")
  done < <(find "$BASE/banidos" -maxdepth 1 \( -type f -o -type l \) -printf '%f\n' 2>/dev/null | LC_ALL=C sort)

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

limpar_banidos() {
  local -a apagar=() sair=()
  local nome p
  if [ -d "$BASE/banidos" ]; then
    while IFS= read -r nome; do
      [ -n "$nome" ] || continue
      if no_acervo "$nome" || LC_ALL=C grep -qxF -- "$nome" "$BANIDOS_TXT" 2>/dev/null; then apagar+=("$nome"); fi
    done < <(find "$BASE/banidos" -maxdepth 1 \( -type f -o -type l \) -printf '%f\n' 2>/dev/null | LC_ALL=C sort)
  fi
  [ -d "$BASE/favoritos" ] && [ -z "$(ls -A "$BASE/favoritos" 2>/dev/null)" ] && sair+=("$BASE/favoritos")
  [ -d "$BASE/banidos" ] && [ "$(find "$BASE/banidos" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)" = "${#apagar[@]}" ] \
    && sair+=("$BASE/banidos")
  [ "${#apagar[@]}" = "0" ] && [ "${#sair[@]}" = "0" ] && return 0
  if meow_seco; then
    [ "${#apagar[@]}" -gt 0 ] && meow_muda "apagaria ${#apagar[@]} imagem(ns) recusada(s) de banidos/"
    for p in "${sair[@]}"; do meow_muda "tiraria a pasta vazia ${p##*/}/"; done
    return 1
  fi
  for nome in "${apagar[@]}"; do rm -f -- "$BASE/banidos/$nome"; done
  for p in "${sair[@]}"; do rmdir -- "$p" 2>/dev/null; done
  [ "${#apagar[@]}" -gt 0 ] && meow_ok "${#apagar[@]} imagem(ns) recusada(s) apagada(s) de banidos/"
  meow_registrar "wallpaper.sh limpar-banidos: ${#apagar[@]}"
  return 1
}

cmd_aplicar() {
  criar_pastas || { meow_erro "não consegui criar as pastas"; return "$MEOW_ERRO"; }
  reconciliar_sumicos
  reconciliar_banidos_pasta
  local limpou=0
  limpar_banidos || limpou=1
  semear_das_dela

  local n; n="$(quantas)"
  if [ "$n" -lt 2 ]; then
    meow_pula "só $n imagem(ns) para girar em $BASE — o carrossel precisa de 2 ou mais"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local mudou="$limpou"

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
        "$BASE"|"$BASE"/*|"") ;;
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

  if [ "$GIRANDO_MUDOU" = 1 ]; then mudou=1; forcar_releitura; fi

  limpar_estado_morto || true

  n="${#COLECAO[@]}"
  local resumo="$n imagens"
  if [ -n "$GRUPO" ]; then
    local n_grupo="$DIA_N"
    [ "$GRUPO" = "noite" ] && n_grupo="$NOITE_N"
    resumo="$n_grupo de $n imagens do grupo de $GRUPO"
  fi

  if [ "$mudou" = "0" ]; then
    if [ "$escolha_dela" = "1" ]; then
      meow_info "o carrossel está no lugar; a saída acima é escolha sua"
      return 4
    fi
    meow_ok "carrossel já configurado: $resumo, a cada $INTERVALO, $ORDEM"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "carrossel ligado: $resumo, troca a cada $INTERVALO ($ORDEM)"
  return "$MEOW_DIVERGENTE"
}

duracao_dita() {
  local s="$1"
  if [ $((s % 3600)) -eq 0 ]; then
    [ "$((s / 3600))" -eq 1 ] && echo "1 hora" || echo "$((s / 3600)) horas"
  elif [ $((s % 60)) -eq 0 ]; then
    [ "$((s / 60))" -eq 1 ] && echo "1 minuto" || echo "$((s / 60)) minutos"
  else
    echo "$s segundos"
  fi
}

cmd_estado() {
  local n; n="$(quantas)"
  local alvo="$GIRANDO"
  local ordem_dita="aleatória"
  [ "$(metodo_de "$ORDEM")" = "Alphanumeric" ] && ordem_dita="alfabética"
  [ "$n" -eq 1 ] && meow_frase "O carrossel tem 1 imagem, em ordem $ordem_dita, e troca a cada $(duracao_dita "$(segundos_de "$INTERVALO")")." \
    || meow_frase "O carrossel tem $n imagens, em ordem $ordem_dita, e troca a cada $(duracao_dita "$(segundos_de "$INTERVALO")")."
  echo "pasta:     ${PASTA_PACK:-$MINHAS}"
  echo "suas:      $MINHAS"
  echo "imagens:   $n"
  echo "intervalo: $INTERVALO ($(segundos_de "$INTERVALO")s)"
  echo "ordem:     $ORDEM ($(metodo_de "$ORDEM"))"

  case "$NOITE" in
    sim)
      local agora escuras claras
      escuras="$(grep -c $'\tnoite$' "$GRUPOS_TSV" 2>/dev/null)"; claras="$(grep -c $'\tdia$' "$GRUPOS_TSV" 2>/dev/null)"
      escuras="${escuras:-0}"; claras="${claras:-0}"
      if e_noite 2>/dev/null; then agora="NOITE"
      else                         agora="DIA"; fi
      echo "noite:     ligada, das $NOITE_INICIO às $NOITE_FIM — agora é $agora"
      meow_frase "O carrossel usa as imagens escuras à noite, das $NOITE_INICIO às $NOITE_FIM, e as claras de dia; agora é $([ "$agora" = "NOITE" ] && echo noite || echo dia)."

      ler_lado
      local esc_dia=0 esc_noite=0 nome_l por_medicao
      if [ "${#LADO[@]}" -gt 0 ]; then
        for nome_l in "${!LADO[@]}"; do
          no_acervo "$nome_l" || continue
          case "${LADO[$nome_l]}" in
            dia)   esc_dia=$((esc_dia + 1)) ;;
            noite) esc_noite=$((esc_noite + 1)) ;;
          esac
        done
      fi
      por_medicao=$(( escuras + claras - esc_dia - esc_noite ))
      [ "$por_medicao" -lt 0 ] && por_medicao=0
      [ $((escuras + claras)) -gt 0 ] && meow_frase "Pelo brilho, $escuras são escuras e $claras são claras."
      echo "limiar:    $LIMIAR_LUZ de luminância ($escuras escuras | $claras claras, na última medida; escolha sua: $esc_noite noite | $esc_dia dia · medição: $por_medicao)"
      echo "rotação:   $alvo"
      ;;
    *)
      meow_frase "O carrossel não separa dia e noite: usa todas as imagens o tempo todo."
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
  if [ "$fora" = "0" ]; then
    meow_frase "O carrossel está ativo."
    echo "estado:    carrossel ATIVO"
  else
    meow_frase "O carrossel não está apontando para as imagens certas; o botão Girar refaz a ligação."
  fi
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
    meow_muda "tiraria o aviso do papel de parede devolvido (o meow.conf fica como está)"
    return "$MEOW_DIVERGENTE"
  fi
  meow_pendencia_resolvida wallpaper-fonte-revertida
  meow_ok "a imagem devolvida fica como está — o aviso saiu"
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
  local acervo; acervo="$(readlink -m -- "$BASE")"
  case "$(readlink -m -- "$(dirname -- "$img")")/" in
    "$acervo"/*) ;;
    *) meow_erro "$img não mora no acervo do papel de parede ($BASE)"; return "$MEOW_ERRO" ;;
  esac
  local -a onde=()
  local d alvo ja real=""
  ler_colecao
  [ -n "${CAMINHO[$nome]:-}" ] && [ "${CAMINHO[$nome]}" -ef "$img" ] && real="${CAMINHO[$nome]}"
  for alvo in "$img" "$real" "$GIRANDO/$nome" "$BASE/banidos/$nome"; do
    [ -e "$alvo" ] || [ -L "$alvo" ] || continue
    [ "$alvo" = "$GIRANDO/$nome" ] && ! [ "$alvo" -ef "$img" ] && continue
    alvo="$(readlink -m -- "$(dirname -- "$alvo")")/$nome"
    case "$alvo" in "$acervo"/*) ;; *) continue ;; esac
    ja=0
    for d in ${onde[@]+"${onde[@]}"}; do [ "$d" = "$alvo" ] && ja=1; done
    [ "$ja" = 0 ] && onde+=("$alvo")
  done
  local fontes="$RAIZ/packs/meowsystem/wallpapers/FONTES.tsv"
  local padrao="$RAIZ/packs/meowsystem/wallpapers/BANIDOS.txt.padrao"
  local checkout=0
  [ -e "$RAIZ/.git" ] && checkout=1
  local na_fonte=0
  if [ "$checkout" = 1 ] && [ -f "$fontes" ] && N="$nome" awk -F'\t' '$1 == ENVIRON["N"] {a = 1} END {exit !a}' "$fontes"; then
    na_fonte=1
  fi
  if meow_seco; then
    meow_muda "apagaria $nome (${#onde[@]} arquivo(s)) e o poria em $(basename "$BANIDOS_TXT")"
    [ "$na_fonte" = 1 ] && meow_muda "tiraria $nome do FONTES.tsv e o poria no BANIDOS.txt.padrao do repositório"
    return "$MEOW_DIVERGENTE"
  fi
  for alvo in "${onde[@]}"; do rm -f -- "$alvo" || return "$MEOW_ERRO"; done
  local pasta_lista; pasta_lista="$(dirname "$BANIDOS_TXT")"
  if [ -d "$pasta_lista" ]; then
    [ -f "$BANIDOS_TXT" ] || printf '%s\n' \
      "# BANIDOS.txt — os papéis de parede que você recusou, por nome de arquivo." \
      "# O 'meow wallpaper banir' acrescenta aqui; o 'semear' não repõe o que está listado." \
      > "$BANIDOS_TXT"
    LC_ALL=C grep -qxF -- "$nome" "$BANIDOS_TXT" || printf '%s\n' "$nome" >> "$BANIDOS_TXT"
  else
    meow_aviso "não achei $pasta_lista — a recusa de $nome vale só nesta máquina"
  fi
  if [ "$checkout" = 1 ]; then
    if [ "$na_fonte" = 1 ]; then
      local tmp; tmp="$(mktemp -p "$(dirname "$fontes")" ".atomicwrite.meow.XXXXXX")" || return "$MEOW_ERRO"
      N="$nome" awk -F'\t' '$1 != ENVIRON["N"]' "$fontes" > "$tmp" && mv -f "$tmp" "$fontes" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
    fi
    if [ "$na_fonte" = 1 ] && [ -f "$padrao" ] && ! LC_ALL=C grep -qxF -- "$nome" "$padrao"; then
      [ -n "$(tail -c1 "$padrao")" ] && printf '\n' >> "$padrao"
      printf '%s\n' "$nome" >> "$padrao"
    fi
    [ "$na_fonte" = 1 ] && meow_info "  no repositório: fora do FONTES.tsv e no BANIDOS.txt.padrao, sem commit"
  fi
  meow_ok "apagada: $nome"
  meow_registrar "wallpaper.sh banir: $nome"
  cmd_aplicar >/dev/null
  forcar_releitura
  return "$MEOW_DIVERGENTE"
}

_adicionar_uma() {
  local img="$1"
  if meow_seco; then
    [ -e "$MINHAS/$(basename "$img")" ] && return 1
    meow_muda "copiaria $(basename "$img") para $MINHAS/"
    return 0
  fi
  [ -e "$MINHAS/$(basename "$img")" ] && return 1
  meow_guardar_antes "$MINHAS/$(basename "$img")"
  cp -n "$img" "$MINHAS/" 2>/dev/null || return 1
  return 0
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

  if ! no_acervo "$nome"; then
    meow_erro "não achei $nome no acervo do papel de parede"
    if [ -f "$BASE/banidos/$nome" ]; then
      meow_info "  ela foi recusada e saiu do acervo; a cópia em banidos/ o doctor apaga"
    else
      meow_info "  o lado vale só para imagem do acervo"
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
    meow_pula "nenhuma imagem nova (as que você passou já estavam em $MINHAS/)"
    return "$MEOW_OK"
  fi
  meow_ok "$n imagem(ns) adicionada(s)"
  cmd_aplicar >/dev/null
  forcar_releitura
  return "$MEOW_DIVERGENTE"
}

_semente_do_flavor() {
  local linhas chave valor repo="" commit="" desenhos="" ignorar="" curadoria="" fotos="" dono=""
  local repo_conf="" commit_conf=""
  _PACK_NO_AR="$(meow_pack_dir)"
  linhas="$(python3 "$RAIZ/scripts/pack.py" wallpapers "$_PACK_NO_AR" 2>/dev/null)" || linhas=""
  while IFS='=' read -r chave valor; do
    case "$chave" in
      repo) repo="$valor" ;; commit) commit="$valor" ;; desenhos) desenhos="$valor" ;;
      ignorar) ignorar="$valor" ;; curadoria) curadoria="$valor" ;;
      fotos) fotos="$valor" ;; pack) dono="${valor##*/}" ;;
      repo_do_conf)   [[ "$valor" =~ ^WALLPAPER_[A-Z0-9_]*_REPO$ ]] && repo_conf="${!valor:-}" ;;
      commit_do_conf) [[ "$valor" =~ ^WALLPAPER_[A-Z0-9_]*_COMMIT$ ]] && commit_conf="${!valor:-}" ;;
    esac
  done <<< "$linhas"
  if pasta_do_acervo "$dono" && [ "$dono" != Minhas ]; then
    PASTA_PACK="$BASE/$dono"
    PASTAS_QUE_GIRAM=("$PASTA_PACK" "$MINHAS")
  fi
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
  elif [ -n "$repo" ]; then
    SEMENTE_REPO_PADRAO="$repo"
    SEMENTE_COMMIT_PADRAO="$commit"
    SEMENTE_IGNORAR_PADRAO="$ignorar"
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
SEMENTE_QUANTAS="${WALLPAPER_SEMENTE_QUANTAS:-0}"
SEMEIA="${PASTA_PACK:-$MINHAS}"

BANIDOS_TXT="${WALLPAPER_BANIDOS:-$(meow_estado_com_padrao papeis-de-parede BANIDOS.txt)}"

esta_banida() {
  local nome="$1"
  [ -e "$BASE/banidos/$nome" ] && return 0
  [ -f "$BANIDOS_TXT" ] && LC_ALL=C grep -qxF -- "$nome" "$BANIDOS_TXT" && return 0
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
    local destino="$SEMEIA/$nome"
    [ "$(realpath -m -- "$destino")" = "$(realpath -m -- "$SEMEIA")/$nome" ] || continue
    [ -e "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then
      meow_muda "baixaria $nome (curadoria)"; CURADORIA_N=$((CURADORIA_N + 1)); continue
    fi
    local tmp; tmp="$(mktemp -p "$SEMEIA" ".meow.XXXXXX")"
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
      LICENSE|md|txt|tsv) continue ;;
      *) ignorados=$((ignorados + 1)); continue ;;
    esac
    nome="$(nome_do_papel "$rel")"
    destino="$SEMEIA/$nome"
    [ -e "$destino" ] && [ ! "$arq" -nt "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then
      if [ "$vetor" = 1 ]; then meow_muda "rasterizaria $nome em 4K"; else meow_muda "copiaria $nome"; fi
      n=$((n + 1)); continue
    fi
    local tmp; tmp="$(mktemp -p "$SEMEIA" ".meow.XXXXXX")"
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

_semear_papeis_do_pack() {
  [ -z "${WALLPAPER_SEMENTE_REPO:-}" ] || return "$MEOW_OK"
  local linhas; linhas="$(python3 "$RAIZ/scripts/pack.py" papeis-do-pack "$_PACK_NO_AR" 2>/dev/null)" || linhas=""
  [ -n "$linhas" ] || return "$MEOW_OK"
  criar_pastas || return "$MEOW_ERRO"
  local n=0 svg_sem=0 rel arq nome destino tmp vetor
  while IFS=$'\t' read -r rel arq; do
    [ -n "$rel" ] && [ -f "$arq" ] || continue
    vetor=0
    case "${rel##*.}" in
      svg|SVG) if meow_tem rsvg-convert; then vetor=1; else svg_sem=$((svg_sem + 1)); continue; fi ;;
    esac
    nome="$(nome_do_papel "$rel")"
    destino="$SEMEIA/$nome"
    [ -e "$destino" ] && [ ! "$arq" -nt "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then meow_muda "semearia $nome (papel do pack)"; n=$((n + 1)); continue; fi
    tmp="$(mktemp -p "$SEMEIA" ".meow.XXXXXX")" || return "$MEOW_ERRO"
    if [ "$vetor" = 1 ]; then
      rsvg-convert -w 3840 -h 2160 -f png -o "$tmp" -- "$arq" 2>/dev/null
    else
      cp -- "$arq" "$tmp" 2>/dev/null
    fi
    if [ -s "$tmp" ]; then
      meow_guardar_antes "$destino"; mv -f "$tmp" "$destino"; n=$((n + 1))
    else
      rm -f "$tmp"; meow_aviso "não consegui semear $rel"
    fi
  done <<< "$linhas"
  [ "$svg_sem" -gt 0 ] && meow_aviso "$svg_sem papel(éis) do pack ficaram de fora: sem o rsvg-convert não há como rasterizá-los"
  [ "$n" -gt 0 ] || return "$MEOW_OK"
  meow_seco || meow_ok "$n papel(éis) do pack semeados"
  return "$MEOW_DIVERGENTE"
}

_com_os_papeis_do_pack() {
  local rc="$1" rc_p=0
  _semear_papeis_do_pack || rc_p=$?
  [ "$rc" = "$MEOW_OK" ] && [ "$rc_p" != "$MEOW_OK" ] && rc="$rc_p"
  return "$rc"
}

cmd_semear_se_faltar() {
  local rc=0
  _semear_origem_se_faltar || rc=$?
  _com_os_papeis_do_pack "$rc"
}

_nomes_dos_papeis_do_pack() {
  local rel arq nome
  while IFS=$'\t' read -r rel arq; do
    [ -n "$rel" ] || continue
    nome_do_papel "$rel"; printf '\n'
  done < <(python3 "$RAIZ/scripts/pack.py" papeis-do-pack "$_PACK_NO_AR" 2>/dev/null)
}

_semear_origem_se_faltar() {
  local n marca="$MEOW_ESTADO/wallpaper-semeado" rc origem="${SEMENTE_FOTOS:-$SEMENTE_REPO}"
  local proprios arq do_pack=0
  [ -n "$origem" ] || return "$MEOW_OK"
  proprios="$(_nomes_dos_papeis_do_pack)"
  for arq in "$SEMEIA"/*; do
    [ -e "$arq" ] || continue
    if grep -qxF -- "${arq##*/}" <<< "$proprios"; then do_pack=$((do_pack + 1)); else return "$MEOW_OK"; fi
  done
  n="$(quantas 2>/dev/null)"; n="$(( ${n:-0} - do_pack ))"
  [ "$n" -lt 2 ] || [ "$(cat "$marca" 2>/dev/null)" != "$origem" ] || return "$MEOW_OK"
  if meow_seco; then
    if [ -n "$SEMENTE_FOTOS" ]; then
      meow_muda "semearia as fotos do pack no ar"
    else
      meow_muda "semearia os papéis de parede do pack no ar (precisa de rede)"
    fi
    return "$MEOW_DIVERGENTE"
  fi
  _semear_origem; rc=$?
  [ "$(cat "$marca" 2>/dev/null)" = "$origem" ] || { mkdir -p "$MEOW_ESTADO" && printf '%s\n' "$origem" > "$marca"; }
  return "$rc"
}

_semear_fotos() {
  local origem="$1" n=0 arq nome destino tmp
  while IFS= read -r -d '' arq; do
    nome="${arq##*/}"
    [[ "$nome" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || continue
    case "${nome##*.}" in png|PNG|jpg|JPG|jpeg|JPEG|webp|WEBP) ;; *) continue ;; esac
    destino="$SEMEIA/$nome"
    [ -e "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then meow_muda "copiaria $nome (foto do pack)"; n=$((n + 1)); continue; fi
    tmp="$(mktemp -p "$SEMEIA" ".meow.XXXXXX")" || return "$MEOW_ERRO"
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
  local rc=0
  _semear_origem || rc=$?
  _com_os_papeis_do_pack "$rc"
}

_semear_origem() {
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
ignorar = set(sys.argv[1].split())
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
" "$SEMENTE_IGNORAR")" || { meow_aviso "resposta do GitHub inesperada — semeadura pulada"; return "$MEOW_SEM_DEPENDENCIA"; }

  [ -n "$escolhidas" ] || { meow_aviso "nenhuma imagem encontrada"; return "$MEOW_SEM_DEPENDENCIA"; }

  local n=0 falhas=0 base="https://raw.githubusercontent.com/$SEMENTE_REPO/$SEMENTE_COMMIT"
  while IFS=$'\t' read -r caminho caminho_url; do
    [ -n "$caminho" ] || continue
    local nome="${caminho//\//-}"
    local destino="$SEMEIA/$nome"
    [ -e "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then
      meow_muda "baixaria $nome"; n=$((n+1)); continue
    fi
    local tmp; tmp="$(mktemp -p "$SEMEIA" ".meow.XXXXXX")"
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

  dir="$GIRANDO"
  local rotulo="todas"
  case "$GRUPO" in dia|noite) rotulo="$GRUPO" ;; esac

  mapfile -t lista < <(lista_do_grupo "$dir")
  n="${#lista[@]}"
  if [ "$n" -lt 2 ]; then
    meow_aviso "só $n imagem(ns) girando — não há para onde avançar"
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
    meow_muda "fixaria $(basename "${lista[$alvo]}") ($((alvo + 1)) de $n, grupo $rotulo)"
    return "$MEOW_DIVERGENTE"
  fi

  local escolhido="${lista[$alvo]##*/}"
  gravar_fixo "${CAMINHO[$escolhido]:-${lista[$alvo]}}"
  cmd_aplicar >/dev/null || true
  meow_ok "papel de parede: $(basename "${lista[$alvo]}")  [$((alvo + 1))/$n · grupo $rotulo]"
  if [ "$(segundos_de "$FIXO_TTL")" -gt 0 ]; then
    meow_info "  o carrossel volta em $FIXO_TTL, ou antes, no «Girar»"
  else
    meow_info "  fixado até você soltar, no «Girar»"
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
    meow_info "  o carrossel volta em $FIXO_TTL, ou antes, no «Girar»"
  else
    meow_info "  fixado até você soltar, no «Girar»"
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

BASE_FORA_DO_REPO="$HOME/.local/share/backgrounds/meowsystem"

dentro_de() {
  local pai_id dir
  pai_id="$(stat -c '%d:%i' -- "$2" 2>/dev/null)" || return 1
  dir="$(readlink -m -- "$1")"
  while [ -n "$dir" ] && [ "$dir" != "/" ]; do
    [ -e "$dir" ] && [ "$(stat -c '%d:%i' -- "$dir")" = "$pai_id" ] && return 0
    dir="$(dirname -- "$dir")"
  done
  return 1
}

arquivos_da_base() {
  find "$1" \( -type f -o -type l \) -printf '%P\n' 2>/dev/null | LC_ALL=C sort
}

primeiro_que_nao_chegou() {
  local origem="$1" destino="$2" rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if [ -L "$origem/$rel" ]; then
      [ "$(readlink -- "$origem/$rel")" = "$(readlink -- "$destino/$rel" 2>/dev/null)" ] && continue
    else
      cmp -s -- "$origem/$rel" "$destino/$rel" && continue
    fi
    printf '%s' "$rel"; return 0
  done < <(arquivos_da_base "$origem")
  return 1
}

apontar_fundo_para() {
  local novo="$1"; shift
  local arq texto antes o
  for arq in "$BG"/all "$BG"/output.*; do
    [ -f "$arq" ] || continue
    texto="$(cat "$arq")"; antes="$texto"
    for o in "$@"; do
      texto="${texto//"Path(\"$o\")"/"Path(\"$novo\")"}"
      texto="${texto//"Path(\"$o/"/"Path(\"$novo/"}"
    done
    [ "$texto" = "$antes" ] && continue
    meow_escrever "$arq" "$texto" 644
    case $? in 2) meow_erro "falhou ao reescrever $(basename "$arq")"; return "$MEOW_ERRO" ;; esac
  done
  return 0
}

cmd_base() {
  local velho_real novo="$BASE_FORA_DO_REPO" n_antes faltou rel
  if ! dentro_de "$BASE" "$RAIZ"; then
    meow_ok "a base do papel de parede ($BASE) mora fora do repositório"
    return "$MEOW_OK"
  fi
  velho_real="$(readlink -m -- "$BASE")"
  if [ -d "$velho_real" ]; then
    rel="${velho_real#"$(readlink -m -- "$RAIZ")"/}"
    if [ "$rel" != "$velho_real" ] && [ -n "$(git -C "$RAIZ" ls-files -- "$rel" 2>/dev/null | head -n1)" ]; then
      meow_erro "há arquivo versionado em $rel — o doctor não move o que o git guarda"
      return "$MEOW_ERRO"
    fi
  fi
  n_antes=0
  [ -d "$velho_real" ] && n_antes="$(arquivos_da_base "$velho_real" | grep -c .)"
  if meow_seco; then
    meow_muda "a base do papel de parede ($BASE) mora dentro do repositório — moveria as $n_antes imagens para $novo e apontaria o WALLPAPER_BASE e o fundo para lá"
    return "$MEOW_DIVERGENTE"
  fi

  if [ -L "$novo" ] && dentro_de "$novo" "$RAIZ"; then
    rm -f -- "$novo" || return "$MEOW_ERRO"
  fi
  mkdir -p -- "$(dirname -- "$novo")" || return "$MEOW_ERRO"
  if [ -d "$velho_real" ]; then
    if [ ! -e "$novo" ]; then
      mv -- "$velho_real" "$novo" || { meow_erro "não consegui mover $velho_real para $novo"; return "$MEOW_ERRO"; }
    else
      cp -a --no-clobber -- "$velho_real"/. "$novo"/ || { meow_erro "não consegui copiar $velho_real para $novo"; return "$MEOW_ERRO"; }
      faltou="$(primeiro_que_nao_chegou "$velho_real" "$novo")"
      if [ -n "$faltou" ]; then
        meow_erro "$faltou não chegou igual em $novo — a origem fica intacta"
        return "$MEOW_ERRO"
      fi
      rm -rf -- "$velho_real" || return "$MEOW_ERRO"
    fi
  else
    mkdir -p -- "$novo" || return "$MEOW_ERRO"
  fi

  if [ -n "$(conf_bruto WALLPAPER_BASE)" ]; then
    meow_conf_definir WALLPAPER_BASE "$novo"
    case $? in 2) meow_erro "não consegui gravar o WALLPAPER_BASE"; return "$MEOW_ERRO" ;; esac
  fi
  apontar_fundo_para "$novo" "$BASE" "$velho_real" "$RAIZ/assets/papeis-de-parede" || return "$MEOW_ERRO"
  meow_ok "as $n_antes imagens moraram em $novo; o WALLPAPER_BASE e o fundo apontam para lá"
  return "$MEOW_DIVERGENTE"
}

_traduzir_estado_de_antes() {
  python3 -I - "$BASE" "$@" <<'FIM'
import os, sys, tempfile
base, mapa_arq = sys.argv[1], sys.argv[2]
alvos = dict(zip(sys.argv[3::2], sys.argv[4::2]))
mapa = {}
with open(mapa_arq, encoding="utf-8", errors="surrogateescape") as fh:
    for linha in fh:
        partes = linha.rstrip("\n").split("\t")
        if len(partes) == 3:
            mapa[partes[0]] = (partes[1], partes[2])
antigas = tuple(os.path.join(base, d) + os.sep for d in ("ativos", "ativos-dia", "ativos-noite", "ativos-pack"))

def ler(arq):
    with open(arq, encoding="utf-8", errors="surrogateescape") as fh:
        return fh.read().split("\n")

def gravar(arq, linhas):
    fd, tmp = tempfile.mkstemp(prefix=".meow.", dir=os.path.dirname(arq) or ".")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", errors="surrogateescape") as fh:
            fh.write("\n".join(linhas))
        os.replace(tmp, arq)
    except BaseException:
        os.unlink(tmp)
        raise

try:
    for tipo, arq in alvos.items():
        if not os.path.isfile(arq):
            continue
        antes = arq + ".antes-pastas"
        linhas, novas, vistas = ler(antes if os.path.isfile(antes) else arq), [], set()
        for linha in linhas:
            if not linha or linha.startswith("#"):
                novas.append(linha)
                continue
            campos = linha.split("\t")
            if tipo == "fixado":
                cam = campos[0]
                if cam.startswith(antigas) and os.path.basename(cam) in mapa:
                    pasta, novo = mapa[os.path.basename(cam)]
                    campos[0] = os.path.join(base, pasta, novo)
            elif "/" not in campos[0] and campos[0] in mapa:
                pasta, novo = mapa[campos[0]]
                campos[0] = f"{pasta}/{novo}" if tipo == "vistas" else novo
            nova = "\t".join(campos)
            if tipo in ("banidos", "vistas") and nova in vistas:
                continue
            vistas.add(nova)
            novas.append(nova)
        if novas != ler(arq):
            gravar(arq, novas)
except OSError as e:
    print(f"{e.strerror}: {e.filename}", file=sys.stderr)
    sys.exit(1)
FIM
}

_entrada_de_antes() {
  [ -L "$1" ] || [ -f "$1" ] || return 1
  case "${1##*/}" in .meow.*) return 1 ;; esac
}

base_antiga_pendente() {
  local d arq
  for d in "${PASTAS_DE_ANTES[@]}" originais; do
    [ -d "$BASE/$d" ] || continue
    if [ "$d" != originais ]; then
      for arq in "$BASE/$d"/* "$BASE/$d"/.[!.]*; do _entrada_de_antes "$arq" && return 0; done
    fi
    [ ! -L "$BASE/$d" ] && [ -z "$(find "$BASE/$d" -mindepth 1 ! -name '.meow.*' -print -quit 2>/dev/null)" ] && return 0
  done
  return 1
}

nome_livre() {
  local pasta="$1" nome="$2" raiz ext="" i=2 cand
  raiz="${nome%.*}"
  [ "$raiz" != "$nome" ] && [ -n "$raiz" ] && ext=".${nome##*.}" || raiz="$nome"
  while :; do
    cand="$raiz-$i$ext"
    if ! no_acervo "$cand" && [ ! -e "$pasta/$cand" ] && [ ! -L "$pasta/$cand" ]; then printf '%s' "$cand"; return 0; fi
    i=$((i + 1))
  done
}

MIGROU=0
MIGROU_FALHAS=0
declare -A MIGROU_POR=()
mover_de_antes() {
  local origem="$1" pasta="$2" novo="$3" destino
  destino="$BASE/$pasta/$novo"
  if [ -e "$destino" ] && [ ! -L "$origem" ] && cmp -s -- "$origem" "$destino"; then
    rm -f -- "$origem" || MIGROU_FALHAS=$((MIGROU_FALHAS + 1))
    return 0
  fi
  if [ -e "$destino" ] || [ -L "$destino" ] || { [ "$pasta" = Minhas ] && no_acervo "$novo"; }; then
    novo="$(nome_livre "$BASE/$pasta" "$novo")"
    meow_aviso "${origem#"$BASE"/} foi para $pasta/$novo: o nome de antes já era de outra imagem"
    destino="$BASE/$pasta/$novo"
  fi
  if [ ! -d "$BASE/$pasta" ] && ! mkdir -p -- "$BASE/$pasta" 2>/dev/null; then
    MIGROU_FALHAS=$((MIGROU_FALHAS + 1)); return 0
  fi
  if mv -n -- "$origem" "$destino" 2>/dev/null && { [ -e "$destino" ] || [ -L "$destino" ]; } \
     && ! { [ -e "$origem" ] || [ -L "$origem" ]; }; then
    MIGROU=$((MIGROU + 1)); MIGROU_POR["$pasta"]=$(( ${MIGROU_POR[$pasta]:-0} + 1 ))
  else
    MIGROU_FALHAS=$((MIGROU_FALHAS + 1))
  fi
  return 0
}

migrar_base_antiga() {
  base_antiga_pendente || return 0

  if [ -d "$BASE/ativos" ] && [ "$(stat -L -c %d -- "$BASE/ativos")" != "$(stat -L -c %d -- "$BASE")" ]; then
    meow_erro "$BASE/ativos mora em outro disco que $BASE — não levo imagem de um disco para outro; a base antiga fica como está e o carrossel segue nela"
    return "$MEOW_ERRO"
  fi

  local -a soltas=()
  local d arq s
  for d in "${PASTAS_DE_ANTES[@]}"; do
    for arq in "$BASE/$d"/* "$BASE/$d"/.[!.]*; do
      _entrada_de_antes "$arq" && soltas+=("$d/${arq##*/}")
    done
  done

  local tmpd mapa erro
  tmpd="$(mktemp -d)" || { meow_erro "não consegui criar a pasta temporária da migração — nada foi movido"; return "$MEOW_ERRO"; }
  mapa="$tmpd/mapa"
  if ! {
    for s in ${soltas[@]+"${soltas[@]}"}; do printf '%s\n' "${s#*/}"; done
    grep -v '^#' "$BANIDOS_TXT" 2>/dev/null
    grep -v '^#' "$LADO_TSV" 2>/dev/null | cut -f1
    cat "$VISTAS" 2>/dev/null
    grep -v '^#' "$LUZ_TSV" 2>/dev/null | cut -f1
    cut -f1 "$FIXADO" 2>/dev/null | sed 's#.*/##'
    :
  } | LC_ALL=C sort -u | python3 "$RAIZ/scripts/pack.py" papeis-de-antes > "$mapa" 2> "$tmpd/erro"; then
    erro="$(sed -n 's/^  erro pack recusado: //p' "$tmpd/erro" | tail -n1)"
    rm -rf -- "$tmpd"
    meow_erro "não consegui ler os packs para dar nome novo às imagens de $BASE/ativos/${erro:+ ($erro)} — nada foi movido"
    return "$MEOW_ERRO"
  fi
  local -A PASTA_DE=() NOVO_DE=()
  local nome pasta novo
  while IFS=$'\t' read -r nome pasta novo; do
    [ -n "$nome" ] && pasta_do_acervo "$pasta" && [ -n "$novo" ] || continue
    case "$novo" in .*|*/*) continue ;; esac
    PASTA_DE["$nome"]="$pasta"; NOVO_DE["$nome"]="$novo"
  done < "$mapa"
  for s in ${soltas[@]+"${soltas[@]}"}; do
    nome="${s#*/}"
    [ -n "${PASTA_DE[$nome]:-}" ] && continue
    PASTA_DE["$nome"]=Minhas; NOVO_DE["$nome"]="$nome"
  done

  local n_ativos=0
  for s in ${soltas[@]+"${soltas[@]}"}; do case "$s" in ativos/*) n_ativos=$((n_ativos + 1)) ;; esac; done
  if meow_seco; then
    meow_muda "moveria as $n_ativos imagem(ns) de $BASE/ativos/ para uma pasta por pack e tiraria as pastas de antes"
    rm -rf -- "$tmpd"
    return 1
  fi

  local guia; guia="$(dirname "$BANIDOS_TXT")/base.antes-pastas.tsv"
  if [ ! -e "$guia" ]; then
    if ! mkdir -p -- "$(dirname "$guia")" 2>/dev/null; then
      rm -rf -- "$tmpd"; meow_erro "não consegui criar $(dirname "$guia") — nada foi movido"; return "$MEOW_ERRO"
    fi
    local par alvo
    for par in "banidos:$BANIDOS_TXT" "lado:$LADO_TSV" "vistas:$VISTAS" "luz:$LUZ_TSV" "fixado:$FIXADO"; do
      alvo="${par#*:}"
      [ -f "$alvo" ] && [ ! -e "$alvo.antes-pastas" ] || continue
      if ! cp -p -- "$alvo" "$alvo.antes-pastas" 2>/dev/null; then
        rm -rf -- "$tmpd"; meow_erro "não consegui guardar a cópia de antes de $alvo — nada foi movido"; return "$MEOW_ERRO"
      fi
    done
    if ! erro="$(_traduzir_estado_de_antes "$mapa" banidos "$BANIDOS_TXT" lado "$LADO_TSV" vistas "$VISTAS" \
                 luz "$LUZ_TSV" fixado "$FIXADO" 2>&1)"; then
      rm -rf -- "$tmpd"
      erro="${erro##*$'\n'}"
      meow_erro "não consegui pôr o nome novo no BANIDOS.txt e no estado do papel de parede${erro:+ ($erro)} — nada foi movido"
      return "$MEOW_ERRO"
    fi
    local parcial=""
    if ! { parcial="$(mktemp -p "$(dirname "$guia")" ".meow.XXXXXX")" \
           && for s in ${soltas[@]+"${soltas[@]}"}; do
                nome="${s#*/}"
                printf '%s\t%s\n' "$BASE/$s" "$BASE/${PASTA_DE[$nome]}/${NOVO_DE[$nome]}"
              done > "$parcial" && mv -f -- "$parcial" "$guia"; } 2>/dev/null; then
      rm -rf -- "$tmpd"; [ -n "$parcial" ] && rm -f -- "$parcial"
      meow_erro "não consegui gravar $guia — nada foi movido"
      return "$MEOW_ERRO"
    fi
  fi

  MIGROU=0; MIGROU_FALHAS=0; MIGROU_POR=()
  local vez
  for vez in pack Minhas; do
    for s in ${soltas[@]+"${soltas[@]}"}; do
      case "$s" in ativos/*) ;; *) continue ;; esac
      nome="${s#*/}"
      [ "$vez" = Minhas ] && [ "${PASTA_DE[$nome]}" != Minhas ] && continue
      [ "$vez" = pack ] && [ "${PASTA_DE[$nome]}" = Minhas ] && continue
      mover_de_antes "$BASE/$s" "${PASTA_DE[$nome]}" "${NOVO_DE[$nome]}"
    done
  done

  for s in ${soltas[@]+"${soltas[@]}"}; do
    case "$s" in ativos/*) continue ;; esac
    _entrada_de_antes "$BASE/$s" || continue
    nome="${s#*/}"
    if [ -L "$BASE/$s" ] || [ -n "$(find "$BASE" -samefile "$BASE/$s" ! -path "$BASE/$s" -print -quit 2>/dev/null)" ]; then
      rm -f -- "$BASE/$s" || MIGROU_FALHAS=$((MIGROU_FALHAS + 1))
    else
      mover_de_antes "$BASE/$s" "${PASTA_DE[$nome]}" "${NOVO_DE[$nome]}"
    fi
  done
  rm -rf -- "$tmpd"

  for d in "${PASTAS_DE_ANTES[@]}" originais; do
    [ -d "$BASE/$d" ] && [ ! -L "$BASE/$d" ] || continue
    find "$BASE/$d" -maxdepth 1 -name '.meow.*' -type f -delete 2>/dev/null
    rmdir -- "$BASE/$d" 2>/dev/null
  done

  local conta="" p
  for p in $(printf '%s\n' "${!MIGROU_POR[@]}" | LC_ALL=C sort); do conta="$conta${conta:+, }$p ${MIGROU_POR[$p]}"; done
  meow_registrar "wallpaper.sh migrar-base: $MIGROU${conta:+ ($conta)}, $MIGROU_FALHAS falha(s)"
  if [ "$MIGROU_FALHAS" -gt 0 ]; then
    meow_erro "$MIGROU_FALHAS imagem(ns) não saíram das pastas de antes em $BASE (sem permissão de escrita?); $MIGROU já moram numa pasta por pack"
    return "$MEOW_ERRO"
  fi
  meow_ok "a base do papel de parede virou uma pasta por pack: $MIGROU imagem(ns)${conta:+ ($conta)}"
  return 1
}

case "${1:-aplicar}" in
  estado|base|permitir|dispensar) ;;
  *)
    case "${1:-aplicar}" in --conferir|conferir) MEOW_SECO=1 ;; esac
    migrar_base_antiga
    case $? in
      2) exit "$MEOW_ERRO" ;;
      1) meow_seco && exit "$MEOW_DIVERGENTE" ;;
    esac ;;
esac

case "${1:-aplicar}" in
  aplicar)   cmd_aplicar ;;
  proximo|próximo|avançar|avancar)  cmd_passo 1 ;;
  anterior|voltar)                  cmd_passo -1 ;;
  carrossel|soltar)                 cmd_carrossel ;;
  --conferir|conferir) MEOW_SECO=1; cmd_aplicar ;;
  estado)    cmd_estado ;;
  semear)    cmd_semear ;;
  semear-se-faltar) cmd_semear_se_faltar ;;
  base)      [ "${2:-}" = "--conferir" ] && MEOW_SECO=1; cmd_base ;;
  banir)     shift; cmd_banir "${1:-}" ;;
  adicionar) shift; cmd_adicionar "${1:-}" ;;
  permitir)  shift; cmd_permitir "${1:-}" ;;
  dispensar) cmd_dispensar ;;
  lado)      shift; cmd_lado "${1:-}" "${2:-}" ;;
  usar)      shift; cmd_usar "${1:-}" ;;
  *) echo "uso: wallpaper.sh [aplicar|proximo|anterior|usar <img>|carrossel|--conferir|estado|semear|base [--conferir]|adicionar <alvo>|banir <img>|permitir <caminho>|lado <img> dia|noite|auto]" >&2; exit 2 ;;
esac

#!/usr/bin/env bash
set -uo pipefail

# shellcheck disable=SC2034
case " $* " in *" --json "*) NO_COLOR=1 ;; esac

_meow_dir="${BASH_SOURCE[0]}"
case "$_meow_dir" in */*) _meow_dir="${_meow_dir%/*}" ;; *) _meow_dir="." ;; esac
RAIZ="$(cd "$_meow_dir/.." && pwd)"
# shellcheck source=../lib/comum.sh
if ! . "$RAIZ/lib/comum.sh" 2>/dev/null; then
  printf '  erro não encontrei lib/comum.sh a partir de %s\n' "$RAIZ" >&2
  exit 3
fi
unset _meow_dir

JSON=0; LISTA=0; OCULTOS=0; TEMA_FORCADO=""

_ajuda() {
  cat <<FIM
auditar_icones.sh — a lista de ícones está toda baixada e pareada?

  --lista        mostra app por app, com o tema que entregou o ícone
  --ocultos      inclui os .desktop com NoDisplay/Hidden/OnlyShowIn
  --tema NOME    audita contra outro tema de ícones, sem selecioná-lo
  --json         saída legível por máquina
  -h, --ajuda    isto aqui

saída: 0 = todos pareados · 1 = algum sem ícone · 2 = erro · 3 = falta dependência
FIM
}

while [ $# -gt 0 ]; do
  case "$1" in
    --json)    JSON=1 ;;
    --lista)   LISTA=1 ;;
    --ocultos) OCULTOS=1 ;;
    --tema)    TEMA_FORCADO="${2:-}"
               case "$TEMA_FORCADO" in
                 ""|-*) meow_erro "--tema exige um nome de tema"; exit "$MEOW_ERRO" ;;
               esac
               shift ;;
    --tema=*)  TEMA_FORCADO="${1#--tema=}" ;;
    -h|--ajuda|--help) _ajuda; exit 0 ;;
    *) meow_erro "argumento desconhecido: $1"; _ajuda >&2; exit "$MEOW_ERRO" ;;
  esac
  shift
done

for dep in find awk; do
  meow_tem "$dep" || { meow_erro "falta '$dep' no PATH"; exit "$MEOW_SEM_DEPENDENCIA"; }
done

TMP="$(mktemp -d -t meow-auditoria.XXXXXX)" || { meow_erro "sem /tmp?"; exit "$MEOW_ERRO"; }
trap 'rm -rf "$TMP"' EXIT

DADOS_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DADOS_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
AMBIENTE="${XDG_CURRENT_DESKTOP:-COSMIC}"

TK="$(meow_cosmic_dir)/com.system76.CosmicTk/$(meow_cosmic_v com.system76.CosmicTk)/icon_theme"
if [ -n "$TEMA_FORCADO" ]; then
  TEMA="$TEMA_FORCADO"; FONTE_TEMA="--tema (simulação)"
elif [ -r "$TK" ]; then
  TEMA="$(tr -d '"\n' < "$TK")"; FONTE_TEMA="$TK"
else
  TEMA="Cosmic"; FONTE_TEMA="(chave ausente — padrão do COSMIC)"
fi
[ -n "$TEMA" ] || { meow_erro "o tema de ícones selecionado está vazio em $TK"; exit "$MEOW_ERRO"; }

BASES=()
IFS=':' read -r -a _dd <<<"$DADOS_DIRS"
for d in "${_dd[@]}"; do [ -n "$d" ] && BASES+=("$d/icons" "$d/pixmaps"); done
BASES+=("$DADOS_HOME/icons" "$DADOS_HOME/pixmaps" "$HOME/.icons")

_curto_caminho() {
  local p="${1/#$HOME/\~}" pai
  if [ "${#p}" -gt 20 ]; then pai="${p%/*}"; printf '…/%s/%s' "${pai##*/}" "${p##*/}"
  else printf '%s' "$p"; fi
}

_rotulo_base() {
  # shellcheck disable=SC2088
  case "$1" in
    "$DADOS_HOME/icons")     printf 'usuário' ;;
    "$DADOS_HOME/pixmaps")   printf 'pixmaps do usuário' ;;
    "$HOME/.icons")          printf '~/.icons' ;;
    "$DADOS_HOME"/flatpak/*) printf 'flatpak' ;;
    /var/lib/flatpak/*)      printf 'flatpak sistema' ;;
    /usr/share/icons)        printf 'sistema' ;;
    /usr/share/pixmaps)      printf 'pixmaps' ;;
    *)                       _curto_caminho "$1" ;;
  esac
}

_indice_de() {
  local tema="$1" b
  for b in "${BASES[@]}"; do
    [ -f "$b/$tema/index.theme" ] && { printf '%s' "$b/$tema/index.theme"; return 0; }
  done
  return 1
}

_herda() {
  local idx="$1"
  awk -F= '
    /^\[Icon Theme\]/ { g=1; next }
    /^\[/            { if (g) exit }
    g && /^Inherits=/ {
      n = split(substr($0, 10), p, ",")
      for (i = 1; i <= n; i++) { gsub(/^[ \t]+|[ \t\r]+$/, "", p[i]); if (p[i] != "") print p[i] }
      exit
    }' "$idx"
}

declare -A JA_NA_CADEIA=()
CADEIA=()
_por_na_cadeia() {
  local tema="$1"
  [ -n "${JA_NA_CADEIA[$tema]:-}" ] && return 0
  _indice_de "$tema" >/dev/null || return 0
  JA_NA_CADEIA[$tema]=1
  CADEIA+=("$tema")
}

RAIZ_TEMA="$TEMA"
_indice_de "$TEMA" >/dev/null || RAIZ_TEMA="hicolor"
_por_na_cadeia "$RAIZ_TEMA"

for b in "${BASES[@]}"; do
  [ -f "$b/$RAIZ_TEMA/index.theme" ] || continue
  while IFS= read -r pai; do
    [ "$pai" = "hicolor" ] && continue
    _por_na_cadeia "$pai"
  done < <(_herda "$b/$RAIZ_TEMA/index.theme")
done

for t in Cosmic hicolor gnome Yaru; do _por_na_cadeia "$t"; done

if [ "$RAIZ_TEMA" != "$TEMA" ]; then
  meow_aviso "o tema '$TEMA' não está instalado em nenhuma base de ícones"
  meow_info "a busca cai direto no hicolor — é por isso que os ícones somem" >&2
fi

PARES=()
for tema in "${CADEIA[@]}"; do
  for b in "${BASES[@]}"; do
    [ -f "$b/$tema/index.theme" ] || continue
    rb="$(_rotulo_base "$b")"
    PARES+=("$tema"$'\t'"$b"$'\t'"$tema ($rb)"$'\t'"$b/$tema/index.theme")
  done
done
[ ${#PARES[@]} -gt 0 ] || { meow_erro "nenhum tema de ícones instalado (nem '$TEMA' nem hicolor)"; exit "$MEOW_SEM_DEPENDENCIA"; }

_secoes_com_size() {
  awk '
    /^[ \t]*\[/ {
      if (sec != "" && sec != "Icon Theme") { if (!tem) exit; print sec }
      linha = $0
      sub(/^[ \t]*\[/, "", linha); sub(/\][ \t\r]*$/, "", linha)
      sec = linha; tem = 0
      next
    }
    /^[ \t]*Size[ \t]*=/ { tem = 1 }
    END { if (sec != "" && sec != "Icon Theme" && tem) print sec }' "$1"
}

ORIGENS=("$DADOS_HOME/applications")
for d in "${_dd[@]}"; do [ -n "$d" ] && ORIGENS+=("$d/applications"); done

_rotulo_origem() {
  case "$1" in
    "$DADOS_HOME/applications")    printf 'usuário' ;;
    "$DADOS_HOME"/flatpak/*)       printf 'flatpak' ;;
    /var/lib/flatpak/*)            printf 'flatpak sistema' ;;
    /usr/share/applications)       printf 'sistema' ;;
    /usr/local/share/applications) printf 'local' ;;
    *)                             _curto_caminho "$1" ;;
  esac
}

_ler_desktop() {
  awk -v amb="$AMBIENTE" '
    BEGIN { FS = "\n" }
    /^\[/ { if (g) exit; if ($0 ~ /^\[Desktop Entry\]/) g = 1; next }
    !g { next }
    { sub(/\r$/, "") }
    /^Type=/        && tipo  == "" { tipo  = substr($0, 6) }
    /^Icon=/        && icone == "" { icone = substr($0, 6) }
    /^Name=/        && nome  == "" { nome  = substr($0, 6) }
    /^Name\[pt_BR\]=/ && nomebr == "" { nomebr = substr($0, 13) }   # "Name[pt_BR]=" tem 12 caracteres
    /^NoDisplay=/   && nod   == "" { nod   = substr($0, 11) }
    /^Hidden=/      && hid   == "" { hid   = substr($0, 8) }
    /^OnlyShowIn=/  && so    == "" { so    = substr($0, 12) }
    /^NotShowIn=/   && ns    == "" { ns    = substr($0, 11) }
    END {
      oculto = 0
      if (tolower(nod) == "true" || tolower(hid) == "true") oculto = 1
      if (so != "" && index(";" so ";", ";" amb ";") == 0) oculto = 1
      if (ns != "" && index(";" ns ";", ";" amb ";") >  0) oculto = 1
      if (tipo != "" && tipo != "Application") oculto = 1
      printf "%s\t%s\t%s\n", oculto, (nomebr != "" ? nomebr : nome), icone
    }' "$1"
}

declare -A JA_VISTO=()
TOTAL=0; VISIVEIS=0
: > "$TMP/apps"
for dir in "${ORIGENS[@]}"; do
  [ -d "$dir" ] || continue
  rot="$(_rotulo_origem "$dir")"
  while IFS= read -r arq; do
    id="${arq##*/}"; id="${id%.desktop}"
    [ -n "${JA_VISTO[$id]:-}" ] && continue
    JA_VISTO[$id]=1
    TOTAL=$((TOTAL+1))
    IFS=$'\t' read -r oculto nome icone < <(_ler_desktop "$arq")
    [ "$oculto" = "1" ] && [ "$OCULTOS" = "0" ] && continue
    VISIVEIS=$((VISIVEIS+1))
    printf '%s\t%s\t%s\t%s\n' "$id" "$rot" "${nome:-$id}" "${icone:-}" >> "$TMP/apps"
  done < <(find "$dir" -maxdepth 1 -name '*.desktop' 2>/dev/null | sort)
done
OCULTADOS=$((TOTAL - VISIVEIS))

if [ "$VISIVEIS" -eq 0 ]; then
  meow_aviso "nenhum .desktop visível encontrado — nada a auditar"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

awk -F'\t' '{ i = $4
              if (i == "" || substr(i,1,1) == "/" || index(i,"/") > 0) next
              sub(/\.(png|svg|xpm)$/, "", i)
              print i }' "$TMP/apps" | sort -u > "$TMP/desejados"

_stream() {
  local i=0 par tema base rotulo idx sub b j nb
  for par in "${PARES[@]}"; do
    IFS=$'\t' read -r tema base rotulo idx <<<"$par"
    local -a alvos=()
    while IFS= read -r sub; do
      [ -d "$base/$tema/$sub" ] && alvos+=("$base/$tema/$sub")
    done < <(_secoes_com_size "$idx")
    if [ ${#alvos[@]} -gt 0 ]; then
      find -H "${alvos[@]}" -maxdepth 1 \( -type f -o -type l \) -printf '%f\t%p\n' 2>/dev/null \
        | awk -F'\t' -v br="$((i * 10))" -v rot="$rotulo" 'BEGIN { OFS = "\t" }
            {
              n = $1
              if      (n ~ /\.svg$/) { r = 0 }
              else if (n ~ /\.png$/) { r = 1 }
              else if (n ~ /\.xpm$/) { r = 2 }
              else next
              print br + r, substr(n, 1, length(n) - 4), rot, $2
            }'
    fi
    i=$((i + 1))
  done
  j=0; nb=${#BASES[@]}
  for b in "${BASES[@]}"; do
    if [ -d "$b" ]; then
      find -H "$b" -maxdepth 1 \( -type f -o -type l \) -printf '%f\t%p\n' 2>/dev/null \
        | awk -F'\t' -v br="$(( ${#PARES[@]} * 10 ))" -v nb="$nb" -v j="$j" \
              -v rot="solto em $(_rotulo_base "$b")" 'BEGIN { OFS = "\t" }
            {
              n = $1
              if      (n ~ /\.svg$/) { r = 0 }
              else if (n ~ /\.png$/) { r = 1 }
              else if (n ~ /\.xpm$/) { r = 2 }
              else next
              print br + r * nb + j, substr(n, 1, length(n) - 4), rot, $2
            }'
    fi
    j=$((j + 1))
  done
}

_stream | awk -F'\t' -v quero="$TMP/desejados" 'BEGIN {
    OFS = "\t"
    while ((getline linha < quero) > 0) if (linha != "") q[linha] = 1
  }
  ($2 in q) && (!($2 in melhor) || $1 + 0 < melhor[$2]) { melhor[$2] = $1 + 0; tema[$2] = $3; cam[$2] = $4 }
  END { for (n in melhor) print n, tema[n], cam[n] }' > "$TMP/resolvidos"

declare -A DE_TEMA=() DE_CAMINHO=()
while IFS=$'\t' read -r n t c; do DE_TEMA[$n]="$t"; DE_CAMINHO[$n]="$c"; done < "$TMP/resolvidos"

declare -A CONTA=()
ORDEM_TEMAS=()
COM=0; SEM=0
: > "$TMP/faltantes"
: > "$TMP/pareados"
while IFS=$'\t' read -r id origem nome icone; do
  tema=""; caminho=""
  if [ -z "$icone" ]; then
    tema=""
  elif [ "${icone:0:1}" = "/" ] || [ "${icone#*/}" != "$icone" ]; then
    if [ -f "$icone" ]; then tema="caminho absoluto"; caminho="$icone"; fi
  else
    chave="${icone%.png}"; chave="${chave%.svg}"; chave="${chave%.xpm}"
    tema="${DE_TEMA[$chave]:-}"; caminho="${DE_CAMINHO[$chave]:-}"
  fi

  if [ -n "$tema" ]; then
    COM=$((COM+1))
    [ -z "${CONTA[$tema]:-}" ] && ORDEM_TEMAS+=("$tema")
    CONTA[$tema]=$(( ${CONTA[$tema]:-0} + 1 ))
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$nome" "$icone" "$origem" "$tema" "$caminho" >> "$TMP/pareados"
  else
    SEM=$((SEM+1))
    printf '%s\t%s\t%s\t%s\n' "$id" "$nome" "${icone:-(sem Icon=)}" "$origem" >> "$TMP/faltantes"
  fi
done < "$TMP/apps"

declare -A MOTIVO=()
if [ "$SEM" -gt 0 ]; then
  cut -f3 "$TMP/faltantes" \
    | awk '{ i = $0; if (i == "(sem Icon=)" || index(i, "/") > 0) next
             sub(/\.(png|svg|xpm)$/, "", i); print i }' | sort -u > "$TMP/faltam_nomes"

  RAIZES=()
  for b in "${BASES[@]}"; do [ -d "$b" ] && RAIZES+=("$b"); done
  if [ -s "$TMP/faltam_nomes" ] && [ ${#RAIZES[@]} -gt 0 ]; then
    find -L "${RAIZES[@]}" -mindepth 3 \( -type f -o -type l \) \
         \( -name '*.svg' -o -name '*.png' -o -name '*.xpm' \) -printf '%p\n' 2>/dev/null \
      | awk -v quero="$TMP/faltam_nomes" '
          BEGIN { while ((getline l < quero) > 0) if (l != "") q[l] = 1 }
          { n = $0; sub(/.*\//, "", n); sub(/\.[^.]+$/, "", n)
            if ((n in q) && !(n in visto)) { visto[n] = 1; print n "\t" $0 } }' > "$TMP/faltam_onde"
  else
    : > "$TMP/faltam_onde"
  fi

  while IFS=$'\t' read -r nome caminho; do
    achou_base=""
    for b in "${BASES[@]}"; do
      case "$caminho" in "$b"/*) achou_base="$b"; break ;; esac
    done
    resto="${caminho#$achou_base/}"; tema_ach="${resto%%/*}"
    sub="${resto#*/}"; sub="${sub%/*}"
    if [ -n "${JA_NA_CADEIA[$tema_ach]:-}" ]; then
      MOTIVO[$nome]="existe em $tema_ach/$sub, mas o index.theme daquele tema não tem uma seção [$sub] com Size= — o COSMIC ignora"
    else
      MOTIVO[$nome]="existe no tema '$tema_ach', que não está na cadeia de herança — acrescente-o ao Inherits="
    fi
  done < "$TMP/faltam_onde"
fi

_motivo_de() {
  local icone="$1" chave
  case "$icone" in
    "(sem Icon=)") printf 'o .desktop não declara Icon= — não há o que parear'; return ;;
    */*)           printf 'o Icon= é um caminho, e o arquivo não existe: %s' "$icone"; return ;;
  esac
  chave="${icone%.png}"; chave="${chave%.svg}"; chave="${chave%.xpm}"
  printf '%s' "${MOTIVO[$chave]:-não existe em nenhum tema instalado — falta baixar}"
}

_esc() { local s="${1//\\/\\\\}"; printf '%s' "${s//\"/\\\"}"; }

if [ "$JSON" = "1" ]; then
  printf '{\n'
  printf '  "versao": 1,\n'   # noqa: acentuacao
  printf '  "data": "%s",\n' "$(date -Iseconds)"
  printf '  "tema_selecionado": "%s",\n' "$(_esc "$TEMA")"
  printf '  "fonte_do_tema": "%s",\n' "$(_esc "$FONTE_TEMA")"
  printf '  "cadeia": ['
  sep=""
  for t in "${CADEIA[@]}"; do printf '%s"%s"' "$sep" "$(_esc "$t")"; sep=", "; done
  printf '],\n'
  printf '  "desktop_total": %s,\n  "auditados": %s,\n  "ignorados_por_visibilidade": %s,\n' \
         "$TOTAL" "$VISIVEIS" "$OCULTADOS"
  printf '  "com_icone": %s,\n  "sem_icone": %s,\n' "$COM" "$SEM"
  printf '  "por_tema": {'
  sep=""
  for t in "${ORDEM_TEMAS[@]}"; do printf '%s"%s": %s' "$sep" "$(_esc "$t")" "${CONTA[$t]}"; sep=", "; done
  printf '},\n'
  printf '  "faltantes": ['
  sep=""
  while IFS=$'\t' read -r id nome icone origem; do
    printf '%s\n    {"id": "%s", "nome": "%s", "icone": "%s", "origem": "%s", "motivo": "%s"}' \
      "$sep" "$(_esc "$id")" "$(_esc "$nome")" "$(_esc "$icone")" "$(_esc "$origem")" \
      "$(_esc "$(_motivo_de "$icone")")"
    sep=","
  done < "$TMP/faltantes"
  [ -n "$sep" ] && printf '\n  '
  printf '],\n'
  printf '  "aplicativos": ['
  sep=""
  while IFS=$'\t' read -r id nome icone origem tema caminho; do
    printf '%s\n    {"id": "%s", "nome": "%s", "icone": "%s", "origem": "%s", "tema": "%s", "caminho": "%s"}' \
      "$sep" "$(_esc "$id")" "$(_esc "$nome")" "$(_esc "$icone")" "$(_esc "$origem")" \
      "$(_esc "$tema")" "$(_esc "$caminho")"
    sep=","
  done < "$TMP/pareados"
  [ -n "$sep" ] && printf '\n  '
  printf ']\n}\n'
  [ "$SEM" -gt 0 ] && exit "$MEOW_DIVERGENTE"
  exit "$MEOW_OK"
fi

LARGURA_BLOCO=52
_repetir() {
  local n="$1" c="$2" s
  [ "$n" -le 0 ] && return 0
  printf -v s '%*s' "$n" ''
  printf '%s' "${s// /$c}"
}
_regua() { printf '  %s%s%s\n' "$C_DIM" "$(_repetir "$LARGURA_BLOCO" '─')" "$C_ZERO"; }

_encurtar() {
  local t="$1" m="$2"
  if [ "${#t}" -le "$m" ]; then printf '%s' "$t"; else printf '%s…' "${t:0:$((m - 1))}"; fi
}
_sobra() { local n=$(( $1 - ${#2} )); [ "$n" -lt 0 ] && n=0; printf '%s' "$n"; }

meow_titulo "Auditoria de ícones — MeowSystem"

printf '  %stema selecionado%s  %s%s%s\n' "$C_DIM" "$C_ZERO" "$C_MAUVE$C_FORTE" "$TEMA" "$C_ZERO"
printf '  %scadeia de busca%s   ' "$C_DIM" "$C_ZERO"
sep=""
for t in "${CADEIA[@]}"; do
  if [ "$t" = "$TEMA" ]; then printf '%s%s%s%s' "$sep" "$C_MAUVE" "$t" "$C_ZERO"
  else printf '%s%s%s%s' "$sep" "$C_DIM" "$t" "$C_ZERO"; fi
  sep="$C_DIM > $C_ZERO"
done
printf '\n'
if [ "$OCULTOS" = "1" ]; then
  printf '  %saplicativos%s       %s auditados   %s(--ocultos: inclui NoDisplay/Hidden/OnlyShowIn)%s\n' \
         "$C_DIM" "$C_ZERO" "$VISIVEIS" "$C_DIM" "$C_ZERO"
else
  printf '  %saplicativos%s       %s visíveis   %s(de %s .desktop; %s ficaram fora por NoDisplay/OnlyShowIn)%s\n' \
         "$C_DIM" "$C_ZERO" "$VISIVEIS" "$C_DIM" "$TOTAL" "$OCULTADOS" "$C_ZERO"
fi

meow_passo "De onde veio cada ícone"
MAIOR=1
for t in "${ORDEM_TEMAS[@]}"; do [ "${CONTA[$t]}" -gt "$MAIOR" ] && MAIOR="${CONTA[$t]}"; done
LARG=8
for t in "${ORDEM_TEMAS[@]}"; do [ "${#t}" -gt "$LARG" ] && LARG="${#t}"; done
[ "$LARG" -gt 30 ] && LARG=30
BARRA_MAX=$(( LARGURA_BLOCO - LARG - 8 )); [ "$BARRA_MAX" -lt 6 ] && BARRA_MAX=6
while IFS=$'\t' read -r n t; do
  barra=$(( n * BARRA_MAX / MAIOR )); [ "$barra" -lt 1 ] && barra=1
  case "$t" in
    "$TEMA"*)              cor="$C_MAUVE" ;;
    hicolor*|solto*)       cor="$C_AMARELO" ;;
    *)                     cor="$C_AZUL" ;;
  esac
  rot="$(_encurtar "$t" "$LARG")"
  printf '  %s%s%s%*s  %s%4s%s  %s%s%s\n' "$cor" "$rot" "$C_ZERO" "$(_sobra "$LARG" "$rot")" '' \
         "$C_FORTE" "$n" "$C_ZERO" "$cor" "$(_repetir "$barra" '█')" "$C_ZERO"
done < <(for t in "${ORDEM_TEMAS[@]}"; do printf '%s\t%s\n' "${CONTA[$t]}" "$t"; done | sort -rn -k1,1)

_regua
PCT=$(( COM * 100 / VISIVEIS ))
if [ "$SEM" -eq 0 ]; then COR_TOTAL="$C_VERDE$C_FORTE"; else COR_TOTAL="$C_AMARELO$C_FORTE"; fi
printf '  %s%s%s%*s  %s%4s%s  %sde %s   (%s%%)%s\n' \
  "$COR_TOTAL" "pareados" "$C_ZERO" "$(_sobra "$LARG" pareados)" '' \
  "$COR_TOTAL" "$COM" "$C_ZERO" "$C_DIM" "$VISIVEIS" "$PCT" "$C_ZERO"

if [ "$LISTA" = "1" ]; then
  meow_passo "Aplicativo por aplicativo"
  while IFS=$'\t' read -r id nome icone origem tema caminho; do
    case "$tema" in
      "$TEMA"*)          cor="$C_MAUVE" ;;
      hicolor*|solto*)   cor="$C_AMARELO" ;;
      *)                 cor="$C_AZUL" ;;
    esac
    cn="$(_encurtar "$nome" 28)"; ci="$(_encurtar "$icone" 24)"; co="$(_encurtar "$origem" 15)"
    printf '  %s%*s %s%s%s%*s %s%s%s%*s %s%s%s\n' \
      "$cn" "$(_sobra 28 "$cn")" '' \
      "$C_DIM" "$ci" "$C_ZERO" "$(_sobra 24 "$ci")" '' \
      "$C_DIM" "$co" "$C_ZERO" "$(_sobra 15 "$co")" '' \
      "$cor" "$tema" "$C_ZERO"
  done < <(sort -t$'\t' -k5,5 -k2,2 "$TMP/pareados")
fi

printf '\n'
if [ "$SEM" -eq 0 ]; then
  printf '  %sTudo pareado.%s Nenhum app visível ficou sem ícone — nada a fazer.\n\n' \
         "$C_VERDE$C_FORTE" "$C_ZERO"
  meow_registrar "auditar_icones tema=$TEMA visiveis=$VISIVEIS pareados=$COM sem=0"
  exit "$MEOW_OK"
fi

meow_passo "Sem ícone ($SEM) — só estes exigem ação"
[ "$OCULTOS" = "1" ] && printf '  %scom --ocultos, "sem Icon=" costuma ser um .desktop que só serve para esconder um app%s\n\n' \
  "$C_DIM" "$C_ZERO"
while IFS=$'\t' read -r id nome icone origem; do
  printf '  %s%s%s  %s%s%s\n' "$C_VERM$C_FORTE" "$nome" "$C_ZERO" "$C_DIM" "($origem)" "$C_ZERO"
  printf '    %sIcon=%s%s\n' "$C_DIM" "$C_ZERO" "$icone"
  printf '    %s%s%s\n' "$C_AMARELO" "$(_motivo_de "$icone")" "$C_ZERO"
done < "$TMP/faltantes"
printf '\n'
meow_registrar "auditar_icones tema=$TEMA visiveis=$VISIVEIS pareados=$COM sem=$SEM"
exit "$MEOW_DIVERGENTE"

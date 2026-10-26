#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ACAO=""
ARQUIVO_NOVO=""
case "${1:-}" in
  "") : ;;
  --conferir)
    # shellcheck disable=SC2034
    MEOW_SECO=1 ;;
  adicionar)
    ACAO="adicionar"; ARQUIVO_NOVO="${2:-}" ;;
  *)
    meow_erro "argumento desconhecido: $1"
    meow_info "  uso: instalar_fontes.sh [--conferir | adicionar <arquivo>]"
    meow_info "  para simular sem escrever: MEOW_DRY_RUN=1 instalar_fontes.sh"
    exit "$MEOW_ERRO" ;;
esac

NERD_TAG="v3.5.0"
NERD_ATIVO="JetBrainsMono.tar.xz"
NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_TAG/$NERD_ATIVO"
NERD_TAR_SHA256="0227b220360a6f819b9ead92343e8112b34733054782561af50cfba1e8afab63"
NERD_TAR_BYTES=6371912

VARIANTE="JetBrainsMonoNerdFontMono"
FAMILIA_MONO="JetBrainsMono Nerd Font Mono"
FAMILIA_UI="Fira Sans"

SOMAS=(
"065befdc92f7ceb456ea76c76d95af5ef8e4bfd6beffa379bed11c41c4c74c2f  JetBrainsMonoNerdFontMono-Bold.ttf"
"9764226f879560f8abc825e0b85d607e44da5093faf2029ff9b8cee6a081dbb6  JetBrainsMonoNerdFontMono-BoldItalic.ttf"
"b6b7f94cd56e8fb3a92b78df2932280d9f60521fca484b232ac66c4b49a4ff14  JetBrainsMonoNerdFontMono-ExtraBold.ttf"
"66b0494852c588848dc32e3dd28fb5f3f6e867e6cc773beb18ffb1d217ea96c5  JetBrainsMonoNerdFontMono-ExtraBoldItalic.ttf"
"fc6dd72b4c8652e8b9e7276142550c41ad11ddce2b00b0b32500469ecc89d725  JetBrainsMonoNerdFontMono-ExtraLight.ttf"
"f812332145b1d822681fcdf982cefcfba189543b8f503b5fca6108a04d78b525  JetBrainsMonoNerdFontMono-ExtraLightItalic.ttf"
"8588a1ac8f29c2e2607a58886d473d99af7974a3866bfcdb2c710b457e804113  JetBrainsMonoNerdFontMono-Light.ttf"
"3c80e1a76fb2db3ac2907890ae72b3ee956adefaab4ea30077798418893e7065  JetBrainsMonoNerdFontMono-LightItalic.ttf"
"46cada139aa74b987af467221123db6b91858f23c32b6c728ccfce826d519e74  JetBrainsMonoNerdFontMono-Medium.ttf"
"09245248fe5c7edc7d012b001da93664e5cf36ea69352b786d0715b27cbd5252  JetBrainsMonoNerdFontMono-MediumItalic.ttf"
"474634cb9b0697a3a10b3da589e896794e1128b0c7c9b49678ec2e03194ce45a  JetBrainsMonoNerdFontMono-Regular.ttf"
"79c5d4cb24560c5920fcdf1f2f0eca4d7b549df9e9def70959b57e54b1f0216a  JetBrainsMonoNerdFontMono-Italic.ttf"
"da0f5f8adfa4e8357441d5d01df0de0a9df69512fc25708ee0e3d38d11cd9f9d  JetBrainsMonoNerdFontMono-SemiBold.ttf"
"c1a72010e7c5d917d8d4c0ad793d59aedf044942bf05e701b16ba28191b20b14  JetBrainsMonoNerdFontMono-SemiBoldItalic.ttf"
"18f66e4a3105f31b9f1132e4ff0b879bae3faa0545c42108f7812b948f4ce2d9  JetBrainsMonoNerdFontMono-Thin.ttf"
"2d0ebea8655d90546434441d09ed98843d98296aff76dcadb8936b7abc318e2c  JetBrainsMonoNerdFontMono-ThinItalic.ttf"
)

CACHE="$MEOW_CACHE/fontes"
TAR="$CACHE/$NERD_ATIVO"

FONTES_BASE="$HOME/.local/share/fonts"
DESTINO="$FONTES_BASE/MeowSystem"

ACERVO_LOCAL="$RAIZ/assets/fontes/locais"
DESTINO_LOCAL="$DESTINO/locais"

COSMIC="$(meow_cosmic_dir)"
TK="$COSMIC/com.system76.CosmicTk/$(meow_cosmic_v com.system76.CosmicTk)"
TERM_DIR="$COSMIC/com.system76.CosmicTerm/$(meow_cosmic_v com.system76.CosmicTerm)"

_fonte_nome_seguro() {
  local n; n="$(basename -- "$1" | tr -d '[:cntrl:]')"
  n="${n#"${n%%[!.-]*}"}"
  printf '%s' "$n"
}

_fonte_instalar_face() {
  local origem="$1" nome alvo_acervo alvo_destino tmp
  nome="$(_fonte_nome_seguro "$origem")"
  [ -n "$nome" ] || { meow_erro "nome de arquivo vazio"; return "$MEOW_ERRO"; }
  alvo_acervo="$ACERVO_LOCAL/$nome"
  alvo_destino="$DESTINO_LOCAL/$nome"

  if [ -f "$alvo_acervo" ] && cmp -s -- "$origem" "$alvo_acervo" \
     && [ -f "$alvo_destino" ] && cmp -s -- "$origem" "$alvo_destino"; then
    meow_ok "'$nome' já está instalada"
    return "$MEOW_OK"
  fi

  if meow_seco; then
    meow_muda "instalaria '$nome' em $ACERVO_LOCAL e em $DESTINO_LOCAL"
    return "$MEOW_DIVERGENTE"
  fi

  meow_destino_permitido "$DESTINO_LOCAL" || return "$MEOW_ERRO"
  mkdir -p "$ACERVO_LOCAL" "$DESTINO_LOCAL" || {
    meow_erro "não consegui criar o acervo ou o destino"; return "$MEOW_ERRO"; }

  local d
  for d in "$ACERVO_LOCAL" "$DESTINO_LOCAL"; do
    tmp="$(mktemp -p "$d" ".meow-fonte.XXXXXX")" || return "$MEOW_ERRO"
    if ! cp -- "$origem" "$tmp"; then
      rm -f "$tmp"; meow_erro "não consegui copiar '$nome'"; return "$MEOW_ERRO"
    fi
    chmod 644 "$tmp"
    if ! mv -f "$tmp" "$d/$nome"; then
      rm -f "$tmp"; meow_erro "falhou instalar '$nome' em $d"; return "$MEOW_ERRO"
    fi
  done
  meow_muda "'$nome' instalada"
  return "$MEOW_DIVERGENTE"
}

_fontes_pela_ponte() {
  local pedir=() p
  for p in "$@"; do
    case "$p" in curl|xz-utils|unzip|pop-fonts) pedir+=("$p") ;; esac
  done
  [ "${#pedir[@]}" -gt 0 ] || return 1
  meow_seco && return 1
  printf '%s\n' "${pedir[@]}" | meow_ponte pacotes >/dev/null 2>&1 || return 1
  hash -r
  meow_ok "instalados pela ponte root: ${pedir[*]}"
}

cmd_adicionar() {
  local origem="${1:-}"
  if [ -z "$origem" ]; then
    meow_erro "uso: instalar_fontes.sh adicionar <arquivo.zip|.ttf|.otf>"
    return "$MEOW_ERRO"
  fi
  [ -f "$origem" ] || { meow_erro "não achei '$origem'"; return "$MEOW_ERRO"; }

  local faltam_add=()
  meow_tem cmp      || faltam_add+=("cmp")
  meow_tem fc-cache || faltam_add+=("fc-cache")
  case "$origem" in *.zip|*.ZIP) meow_tem unzip || faltam_add+=("unzip") ;; esac
  if [ ${#faltam_add[@]} -gt 0 ] && _fontes_pela_ponte "${faltam_add[@]}"; then
    faltam_add=()
    meow_tem cmp      || faltam_add+=("cmp")
    meow_tem fc-cache || faltam_add+=("fc-cache")
    case "$origem" in *.zip|*.ZIP) meow_tem unzip || faltam_add+=("unzip") ;; esac
  fi
  if [ ${#faltam_add[@]} -gt 0 ]; then
    meow_erro "faltam ferramentas: ${faltam_add[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local rc="$MEOW_OK" postas=0 achadas=0 e
  case "$origem" in
    *.ttf|*.TTF|*.otf|*.OTF)
      achadas=1
      _fonte_instalar_face "$origem"; e=$?
      [ "$e" -ge 2 ] && return "$e"
      [ "$e" = "1" ] && { rc="$MEOW_DIVERGENTE"; postas=1; }
      ;;
    *.zip|*.ZIP)
      if meow_seco; then
        meow_muda "abriria '$origem' e instalaria as fontes dele em $DESTINO_LOCAL"
        return "$MEOW_DIVERGENTE"
      fi
      local tmp
      tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-fonte-zip.XXXXXX")" || return "$MEOW_ERRO"
      if ! unzip -q -o -- "$origem" -d "$tmp" 2>/dev/null; then
        rm -rf "$tmp"; meow_erro "o zip veio corrompido — nada instalado"; return "$MEOW_ERRO"
      fi
      local arq
      while IFS= read -r -d '' arq; do
        achadas=$((achadas + 1))
        _fonte_instalar_face "$arq"; e=$?
        if [ "$e" -ge 2 ]; then rm -rf "$tmp"; return "$e"; fi
        [ "$e" = "1" ] && { rc="$MEOW_DIVERGENTE"; postas=$((postas + 1)); }
      done < <(find "$tmp" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0 2>/dev/null)
      rm -rf "$tmp"
      ;;
    *)
      meow_erro "só sei instalar .zip, .ttf ou .otf — '$origem' não é nenhum deles"
      return "$MEOW_ERRO" ;;
  esac

  if [ "$achadas" = "0" ]; then
    meow_erro "não achei nenhum .ttf/.otf dentro de '$origem'"
    return "$MEOW_ERRO"
  fi

  [ "$rc" = "$MEOW_OK" ] && return "$MEOW_OK"

  if meow_seco; then
    return "$MEOW_DIVERGENTE"
  fi
  if ! fc-cache -f >/dev/null 2>&1; then
    meow_aviso "o fc-cache reclamou — a fonte está no lugar, mas confira 'fc-list'"
  fi
  meow_registrar "instalar_fontes.sh adicionar '$origem' ($postas face(s))"
  meow_info "$postas face(s) instalada(s) — o acervo é $ACERVO_LOCAL"
  return "$MEOW_DIVERGENTE"
}

if [ "$ACAO" = "adicionar" ]; then
  cmd_adicionar "$ARQUIVO_NOVO"
  exit $?
fi

mudou=0

_fontes_faltam() {
  faltam=()
  for c in curl tar sha256sum cmp fc-cache fc-list fc-match; do
    meow_tem "$c" || faltam+=("$c")
  done
  meow_tem xz || meow_tem unxz || faltam+=("xz-utils")
}
_fontes_faltam
[ ${#faltam[@]} -gt 0 ] && _fontes_pela_ponte "${faltam[@]}" && _fontes_faltam
if [ ${#faltam[@]} -gt 0 ]; then
  meow_erro "faltam ferramentas: ${faltam[*]}"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

meow_destino_permitido "$DESTINO" || exit "$MEOW_ERRO"

arquivos_da_familia() {
  fc-list -f '%{file}\t%{family}\n' 2>/dev/null | awk -F'\t' -v alvo="$1" '
    { n = split($2, fam, ","); for (i = 1; i <= n; i++) if (fam[i] == alvo) { print $1; next } }'
}

meow_passo "Fonte da interface"
ui_arquivo="$(arquivos_da_familia "$FAMILIA_UI" | sort | head -1)"
if [ -z "$ui_arquivo" ] && _fontes_pela_ponte pop-fonts; then
  fc-cache -f >/dev/null 2>&1 || true
  ui_arquivo="$(arquivos_da_familia "$FAMILIA_UI" | sort | head -1)"
fi
if [ -n "$ui_arquivo" ]; then
  meow_ok "'$FAMILIA_UI' já instalada — $(dirname "$ui_arquivo")"
  meow_pula "nada a baixar (vem do pacote do sistema)"
else
  meow_aviso "'$FAMILIA_UI' NÃO está instalada — ela vem do pacote pop-fonts do sistema"
fi

meow_passo "Fonte monoespaçada — $FAMILIA_MONO ($NERD_TAG)"

externo="$(arquivos_da_familia "$FAMILIA_MONO" | grep -v "^$DESTINO/" | head -1)"

instalados_ok() {
  [ -d "$DESTINO" ] || return 1
  ( cd "$DESTINO" && printf '%s\n' "${SOMAS[@]}" | sha256sum --status -c - ) 2>/dev/null
}

faces_ok=0
refazer_cache=0

if [ -n "$externo" ]; then
  meow_aviso "'$FAMILIA_MONO' já vem de fora — não duplico"
  meow_info "  $externo"
  meow_info "  as ${#SOMAS[@]} faces pinadas ($NERD_TAG) não foram instaladas em $DESTINO"
  faces_ok=1
elif instalados_ok; then
  meow_ok "as ${#SOMAS[@]} faces já estão em $DESTINO e conferem no sha256"
  faces_ok=1
elif meow_seco; then
  meow_muda "baixaria $NERD_ATIVO ($NERD_TAG) e instalaria ${#SOMAS[@]} faces em $DESTINO"
  mudou=1
else
  if [ -f "$TAR" ] && echo "$NERD_TAR_SHA256  $TAR" | sha256sum --status -c - 2>/dev/null; then
    meow_ok "$NERD_ATIVO já no cache e confere ($NERD_TAG)"
  else
    [ -f "$TAR" ] && meow_aviso "o $NERD_ATIVO do cache não confere no sha256 — baixando de novo"
    mkdir -p "$CACHE" || { meow_erro "não consegui criar $CACHE"; exit "$MEOW_ERRO"; }
    meow_info "baixando $NERD_URL"
    tmp_tar="$(mktemp -p "$CACHE" ".baixando.XXXXXX")" || exit "$MEOW_ERRO"
    if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp_tar" "$NERD_URL"; then
      rm -f "$tmp_tar"
      meow_aviso "não consegui baixar $NERD_URL (sem rede?) — fica para o próximo ciclo"
      meow_info "  nada foi instalado — o terminal continua com a fonte que já tinha"
      exit "$MEOW_SEM_DEPENDENCIA"
    fi
    baixado="$(stat -c%s "$tmp_tar")"
    if [ "$baixado" != "$NERD_TAR_BYTES" ]; then
      meow_aviso "o download tem $baixado bytes, esperava $NERD_TAR_BYTES ($NERD_TAG)"
      meow_info "  quase sempre é portal de rede ou proxy respondendo no lugar do GitHub"
      meow_info "  nada foi instalado — o terminal continua com a fonte que já tinha"
      rm -f "$tmp_tar"
      exit "$MEOW_SEM_DEPENDENCIA"
    fi
    if ! echo "$NERD_TAR_SHA256  $tmp_tar" | sha256sum --status -c - 2>/dev/null; then
      meow_erro "sha256 do $NERD_ATIVO não bate com o pinado ($NERD_TAG)"
      meow_info "  esperado $NERD_TAR_SHA256"
      meow_info "  obtido   $(sha256sum "$tmp_tar" | cut -d' ' -f1)"
      rm -f "$tmp_tar"
      exit "$MEOW_ERRO"
    fi
    chmod 644 "$tmp_tar"
    mv -f "$tmp_tar" "$TAR" || { rm -f "$tmp_tar"; exit "$MEOW_ERRO"; }
    meow_ok "$NERD_ATIVO baixado e verificado ($(stat -c%s "$TAR") bytes)"
  fi

  mkdir -p "$DESTINO" || { meow_erro "não consegui criar $DESTINO"; exit "$MEOW_ERRO"; }
  stage="$(mktemp -d -p "$FONTES_BASE" ".meow-fontes.XXXXXX")" || exit "$MEOW_ERRO"
  # shellcheck disable=SC2064
  trap "rm -rf '$stage'" EXIT

  if ! tar -xJf "$TAR" -C "$stage" --wildcards "${VARIANTE}-*.ttf" 2>/dev/null; then
    meow_erro "falhou ao extrair ${VARIANTE}-*.ttf de $TAR"
    exit "$MEOW_ERRO"
  fi

  if ! ( cd "$stage" && printf '%s\n' "${SOMAS[@]}" | sha256sum --status -c - ) 2>/dev/null; then
    meow_erro "o conteúdo extraído não confere com os sha256 pinados"
    exit "$MEOW_ERRO"
  fi

  novos=0
  while read -r _soma nome; do
    if [ -f "$DESTINO/$nome" ] && cmp -s "$stage/$nome" "$DESTINO/$nome"; then
      continue
    fi
    chmod 644 "$stage/$nome"
    mv -f "$stage/$nome" "$DESTINO/$nome" || { meow_erro "falhou instalar $nome"; exit "$MEOW_ERRO"; }
    novos=$((novos+1))
  done < <(printf '%s\n' "${SOMAS[@]}")

  rm -rf "$stage"; trap - EXIT
  meow_ok "instaladas $novos de ${#SOMAS[@]} faces em $DESTINO"
  mudou=1
  faces_ok=1
  refazer_cache=1
fi

if [ -d "$DESTINO" ]; then
  esperadas=" $(printf '%s\n' "${SOMAS[@]}" | awk '{print $2}' | tr '\n' ' ')"
  sobrando=()
  for f in "$DESTINO"/JetBrainsMono*.ttf; do
    [ -e "$f" ] || continue
    nome_f="$(basename "$f")"
    case "$esperadas" in *" $nome_f "*) continue ;; esac
    sobrando+=("$nome_f")
  done
  if [ ${#sobrando[@]} -gt 0 ]; then
    if meow_seco; then
      meow_muda "removeria ${#sobrando[@]} face(s) de outra versão: ${sobrando[*]}"
      mudou=1
    else
      for nome_f in "${sobrando[@]}"; do rm -f "$DESTINO/$nome_f"; done
      meow_muda "removidas ${#sobrando[@]} face(s) de outra versão: ${sobrando[*]}"
      mudou=1
      refazer_cache=1
    fi
  fi
fi

if [ -d "$ACERVO_LOCAL" ]; then
  meow_destino_permitido "$DESTINO_LOCAL" || exit "$MEOW_ERRO"
  locais_postas=0; locais_tiradas=0
  desejadas_locais=""

  while IFS= read -r -d '' arq; do
    nome_l="$(basename "$arq")"
    desejadas_locais="$desejadas_locais$nome_l
"
    alvo_l="$DESTINO_LOCAL/$nome_l"
    if [ -f "$alvo_l" ] && cmp -s "$arq" "$alvo_l"; then
      continue
    fi
    if meow_seco; then
      meow_muda "instalaria a fonte local $nome_l em $DESTINO_LOCAL"
      mudou=1; locais_postas=$((locais_postas + 1)); continue
    fi
    mkdir -p "$DESTINO_LOCAL" || { meow_erro "não consegui criar $DESTINO_LOCAL"; exit "$MEOW_ERRO"; }
    tmp_l="$(mktemp -p "$DESTINO_LOCAL" ".meow.XXXXXX")" || exit "$MEOW_ERRO"
    cp -- "$arq" "$tmp_l" || { rm -f "$tmp_l"; meow_erro "não consegui copiar $nome_l"; exit "$MEOW_ERRO"; }
    chmod 644 "$tmp_l"
    mv -f "$tmp_l" "$alvo_l" || { rm -f "$tmp_l"; meow_erro "falhou instalar $nome_l"; exit "$MEOW_ERRO"; }
    mudou=1; refazer_cache=1; locais_postas=$((locais_postas + 1))
  done < <(find "$ACERVO_LOCAL" -maxdepth 1 -type f \( -iname '*.otf' -o -iname '*.ttf' \) -print0 2>/dev/null)

  if [ -d "$DESTINO_LOCAL" ]; then
    while IFS= read -r -d '' arq; do
      nome_l="$(basename "$arq")"
      printf '%s' "$desejadas_locais" | grep -qxF "$nome_l" && continue
      if meow_seco; then
        meow_muda "removeria $nome_l (saiu de assets/fontes/locais/)"
      else
        rm -f "$arq"; refazer_cache=1
      fi
      mudou=1; locais_tiradas=$((locais_tiradas + 1))
    done < <(find "$DESTINO_LOCAL" -maxdepth 1 -type f \( -iname '*.otf' -o -iname '*.ttf' \) -print0 2>/dev/null)
  fi

  if [ "$locais_postas" = 0 ] && [ "$locais_tiradas" = 0 ]; then
    n_l="$(printf '%s' "$desejadas_locais" | grep -c . || true)"
    [ "${n_l:-0}" -gt 0 ] && meow_ok "$n_l fonte(s) do acervo local já em $DESTINO_LOCAL"
  else
    meow_info "acervo local: $locais_postas instalada(s), $locais_tiradas removida(s)"
  fi
fi

DESTINO_PACK="$DESTINO/pack"
lista_pack=""; rc_pack=0
if meow_tem python3; then
  lista_pack="$(python3 "$RAIZ/scripts/pack.py" tipografia "$(meow_pack_dir)")"; rc_pack=$?
else
  rc_pack="$MEOW_SEM_DEPENDENCIA"
fi

if [ "$rc_pack" != "0" ]; then
  meow_aviso "não deu para ler as fontes do pack — as que ele já trouxe ficam como estão"
else
  meow_destino_permitido "$DESTINO_PACK" || exit "$MEOW_ERRO"
  pack_postas=0; pack_tiradas=0; desejadas_pack=""; quem_pack=""
  while IFS=$'\t' read -r quem_f nome_f origem_f soma_f; do
    [ -n "$nome_f" ] || continue
    quem_pack="$quem_f"
    desejadas_pack="$desejadas_pack$nome_f
"
    alvo_f="$DESTINO_PACK/$nome_f"
    case "$origem_f" in
      https://*)
        if [ -f "$alvo_f" ] && echo "$soma_f  $alvo_f" | sha256sum --status -c - 2>/dev/null; then
          continue
        fi
        if meow_seco; then
          meow_muda "baixaria a fonte $nome_f do pack $quem_f em $DESTINO_PACK"
          mudou=1; pack_postas=$((pack_postas + 1)); continue
        fi
        mkdir -p "$DESTINO_PACK" || { meow_erro "não consegui criar $DESTINO_PACK"; exit "$MEOW_ERRO"; }
        tmp_f="$(mktemp -p "$DESTINO_PACK" ".meow.XXXXXX")" || exit "$MEOW_ERRO"
        if ! curl -sSfL --proto '=https' --proto-redir '=https' --connect-timeout 15 \
             --max-time 300 --retry 3 --retry-delay 2 -o "$tmp_f" "$origem_f" 2>/dev/null; then
          rm -f "$tmp_f"
          meow_aviso "não consegui baixar a fonte $nome_f do pack $quem_f (sem rede?) — fica para o próximo ciclo"
          continue
        fi
        if ! echo "$soma_f  $tmp_f" | sha256sum --status -c - 2>/dev/null; then
          meow_erro "sha256 da fonte $nome_f não bate com o que o pack $quem_f pinou"
          meow_info "  esperado $soma_f"
          meow_info "  obtido   $(sha256sum "$tmp_f" | cut -d' ' -f1)"
          rm -f "$tmp_f"
          exit "$MEOW_ERRO"
        fi
        ;;
      *)
        if [ -f "$alvo_f" ] && cmp -s -- "$origem_f" "$alvo_f"; then
          continue
        fi
        if meow_seco; then
          meow_muda "instalaria a fonte $nome_f do pack $quem_f em $DESTINO_PACK"
          mudou=1; pack_postas=$((pack_postas + 1)); continue
        fi
        mkdir -p "$DESTINO_PACK" || { meow_erro "não consegui criar $DESTINO_PACK"; exit "$MEOW_ERRO"; }
        tmp_f="$(mktemp -p "$DESTINO_PACK" ".meow.XXXXXX")" || exit "$MEOW_ERRO"
        cp -- "$origem_f" "$tmp_f" || { rm -f "$tmp_f"; meow_erro "não consegui copiar $nome_f"; exit "$MEOW_ERRO"; }
        ;;
    esac
    chmod 644 "$tmp_f"
    mv -f "$tmp_f" "$alvo_f" || { rm -f "$tmp_f"; meow_erro "falhou instalar $nome_f"; exit "$MEOW_ERRO"; }
    mudou=1; refazer_cache=1; pack_postas=$((pack_postas + 1))
  done <<< "$lista_pack"

  if [ -d "$DESTINO_PACK" ]; then
    while IFS= read -r -d '' arq; do
      nome_l="$(basename "$arq")"
      printf '%s' "$desejadas_pack" | grep -qxF "$nome_l" && continue
      if meow_seco; then
        meow_muda "removeria $nome_l (o pack ativo não a traz)"
      else
        rm -f "$arq"; refazer_cache=1
      fi
      mudou=1; pack_tiradas=$((pack_tiradas + 1))
    done < <(find "$DESTINO_PACK" -maxdepth 1 -type f \( -iname '*.otf' -o -iname '*.ttf' \) -print0 2>/dev/null)
  fi

  if [ "$pack_postas" = 0 ] && [ "$pack_tiradas" = 0 ]; then
    n_p="$(printf '%s' "$desejadas_pack" | grep -c . || true)"
    [ "${n_p:-0}" -gt 0 ] && meow_ok "$n_p fonte(s) do pack $quem_pack já em $DESTINO_PACK"
  else
    meow_info "fontes do pack${quem_pack:+ $quem_pack}: $pack_postas instalada(s), $pack_tiradas removida(s)"
  fi
fi

if [ "$refazer_cache" = "1" ] && ! fc-cache -f >/dev/null 2>&1; then
  meow_aviso "o fc-cache reclamou — as fontes estão no lugar, mas confira 'fc-list'"
fi

meow_passo "Configuração do COSMIC"

ron_com_familia() {
  local familia="$1" atual="$2"
  if printf '%s' "$atual" | grep -qE '^[[:space:]]*family:'; then
    printf '%s' "$atual" | sed -E "s|^([[:space:]]*family:[[:space:]]*).*\$|\\1\"$familia\",|"
  else
    printf '(\n    family: "%s",\n    weight: Normal,\n    stretch: Normal,\n    style: Normal,\n)' "$familia"
  fi
}

atual_mono=""
[ -f "$TK/monospace_font" ] && atual_mono="$(cat "$TK/monospace_font")"
meow_escrever "$TK/monospace_font" "$(ron_com_familia "$FAMILIA_MONO" "$atual_mono")" 644
case $? in
  0) meow_ok "monospace_font já aponta para '$FAMILIA_MONO'" ;;
  1) meow_muda "monospace_font -> '$FAMILIA_MONO'"; mudou=1 ;;
  *) meow_erro "não consegui escrever $TK/monospace_font"; exit "$MEOW_ERRO" ;;
esac

if [ -d "$TERM_DIR" ]; then
  meow_escrever "$TERM_DIR/font_name" "\"$FAMILIA_MONO\"" 644
  case $? in
    0) meow_ok "CosmicTerm/font_name já aponta para '$FAMILIA_MONO'" ;;
    1) meow_muda "CosmicTerm/font_name -> '$FAMILIA_MONO'"; mudou=1 ;;
    *) meow_erro "não consegui escrever $TERM_DIR/font_name"; exit "$MEOW_ERRO" ;;
  esac
else
  meow_pula "$TERM_DIR não existe — cosmic-term nunca rodou aqui"
fi

resolve_familia() {
  local casou
  casou="$(fc-match -f '%{family}|%{file}' "$FAMILIA_MONO" 2>/dev/null)"
  FC_FAM="${casou%%|*}"; FC_ARQ="${casou#*|}"
  case "$FC_FAM" in *"$FAMILIA_MONO"*) return 0 ;; esac
  return 1
}

if [ "$faces_ok" = "1" ]; then
  meow_passo "Conferência"
  if ! resolve_familia && ! meow_seco; then
    meow_aviso "a família não resolveu — refazendo o cache do fontconfig"
    fc-cache -f >/dev/null 2>&1
    mudou=1
  fi
  if resolve_familia; then
    meow_ok "fc-match '$FAMILIA_MONO' -> $FC_ARQ"
    registradas="$(arquivos_da_familia "$FAMILIA_MONO" | wc -l)"
    if [ -d "$DESTINO" ]; then
      meow_info "$registradas faces registradas, $(du -sh "$DESTINO" 2>/dev/null | cut -f1) em $DESTINO"
    else
      meow_info "$registradas faces registradas (fora de $DESTINO)"
    fi
  elif meow_seco; then
    meow_aviso "fc-match caiu em '$FC_FAM' ($FC_ARQ) — a família não resolveu"
    meow_info "  uma execução de verdade refaz o cache do fontconfig"
    mudou=1
  else
    meow_erro "fc-match caiu em '$FC_FAM' ($FC_ARQ) — a família não resolveu"
    meow_info "  as faces estão em $DESTINO, mas o fontconfig não as enxerga"
    exit "$MEOW_ERRO"
  fi
fi

if [ "$mudou" = "1" ]; then
  meow_seco || meow_info "terminais já abertos podem precisar de uma aba nova"
  meow_seco && meow_muda "fontes a instalar ou a apontar no COSMIC"
  exit "$MEOW_DIVERGENTE"
fi
meow_ok "fontes já no lugar"
exit "$MEOW_OK"

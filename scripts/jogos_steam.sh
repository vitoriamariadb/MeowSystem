#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"
. "$RAIZ/scripts/nomes_apps.sh"

APPS="$HOME/.local/share/applications"
HICOLOR="$HOME/.local/share/icons/hicolor"
MEOW_JOGOS_FORA="${MEOW_JOGOS_FORA:-$RAIZ/assets/apps/jogos-fora.map}"
STEAM="$HOME/.steam/steam"
CACHE="$STEAM/appcache/librarycache"
LIBVDF="$STEAM/steamapps/libraryfolders.vdf"

STEAM_BIN="$(command -v steam 2>/dev/null || true)"
[ -n "$STEAM_BIN" ] || STEAM_BIN="/usr/games/steam"

case "${1:-}" in
  --conferir) MEOW_SECO=1; MEOW_DRY_RUN=1; export MEOW_DRY_RUN ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac

meow_tem awk || { meow_pula "sem awk — não dá para ler os manifestos da Steam"; exit "$MEOW_SEM_DEPENDENCIA"; }

if [ ! -d "$STEAM/steamapps" ]; then
  meow_pula "Steam não instalada — nada a fazer"
  exit "$MEOW_OK"
fi

bibliotecas() {
  { printf '%s\n' "$STEAM"
    [ -r "$LIBVDF" ] && awk -F'"' '/^[[:space:]]*"path"/ {print $4}' "$LIBVDF"
  } | while IFS= read -r p; do
        [ -n "$p" ] || continue
        readlink -f -- "$p" 2>/dev/null || printf '%s\n' "$p"
      done | sort -u
  return 0
}

arte_do_jogo() {
  local c="$CACHE/$1" f nome
  [ -d "$c" ] || return 1
  for nome in library_capsule.jpg library_600x900.jpg library_header.jpg header.jpg logo.png; do
    f="$(find "$c" -type f -name "$nome" -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -1 | cut -f2-)"
    [ -n "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}

resumo_jogo() {
  [ "${MEOW_JOGOS_RESUMO:-}" = "1" ] || return 0
  printf '@@jogo %s %s %s\n' "$1" "$2" "${3:-appid $2}"
}

jogo_fora() {
  [ -f "$MEOW_JOGOS_FORA" ] || return 1
  awk -F: -v id="$1" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $1 == id { achou = 1; exit }
    END { exit !achou }
  ' "$MEOW_JOGOS_FORA"
}

jogo_fora_acao() {
  [ -f "$MEOW_JOGOS_FORA" ] || { printf 'esconder'; return 1; }
  awk -F: -v id="$1" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $1 == id {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      print ($2 == "apagar" ? "apagar" : "esconder"); achou = 1; exit
    }
    END { if (!achou) print "esconder" }
  ' "$MEOW_JOGOS_FORA"
}

jogo_fora_motivo() {
  [ -f "$MEOW_JOGOS_FORA" ] || return 1
  awk -F: -v id="$1" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $1 == id {
      campo = 2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      if ($2 == "apagar" || $2 == "esconder") campo = 3
      linha = $campo
      for (i = campo + 1; i <= NF; i++) linha = linha ":" $i
      gsub(/^[[:space:]]+/, "", linha)
      print linha; exit
    }
  ' "$MEOW_JOGOS_FORA"
}

jogos_para_apagar() {
  [ -f "$MEOW_JOGOS_FORA" ] || return 0
  awk -F: '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      if ($2 == "apagar" && $1 ~ /^[0-9]+$/) print $1
    }
  ' "$MEOW_JOGOS_FORA"
}

MEOW_JOGOS_APAGADOS="${MEOW_JOGOS_APAGADOS:-$MEOW_ESTADO/jogos-apagados}"

ja_apagado() {
  [ -f "$MEOW_JOGOS_APAGADOS" ] || return 1
  awk -v id="$1" '$1 == id { achou = 1; exit } END { exit !achou }' "$MEOW_JOGOS_APAGADOS"
}

marcar_apagado() {
  meow_seco && return 0
  ja_apagado "$1" && return 0
  mkdir -p "$(dirname "$MEOW_JOGOS_APAGADOS")" 2>/dev/null || return 1
  printf '%s %s %s\n' "$1" "$(date -I)" "${2:-}" >> "$MEOW_JOGOS_APAGADOS"
}

steam_rodando() { pgrep -x steam >/dev/null 2>&1; }

capa_vertical() {
  find "$CACHE/$1" -type f \( -name library_capsule.jpg -o -name library_600x900.jpg \) 2>/dev/null | grep -q .
}

icone_bom_da_steam() {
  local t
  for t in 256x256 128x128; do
    [ -f "$HICOLOR/$t/apps/steam_icon_$1.png" ] && return 0
  done
  return 1
}

algum_icone_da_steam() {
  find "$HICOLOR" -name "steam_icon_$1.png" 2>/dev/null | grep -q .
}

plantar_icone() {
  local id="$1" fonte destino dir tmp pouso px lado mudou_algum=0
  meow_tem convert || return 1
  fonte="$(arte_do_jogo "$id")" || return 1

  while read -r px; do
    [ -n "$px" ] || continue
    destino="$HICOLOR/${px}x${px}/apps/meow-steam-$id.png"
    meow_destino_permitido "$destino" || return 1
    dir="$(dirname "$destino")"
    lado=$(( px * 96 / 100 ))
    [ "$lado" -lt 1 ] && lado=1
    tmp="$(mktemp "${TMPDIR:-/tmp}/meow-icone.XXXXXX.png")" || return 1
    if ! convert "$fonte" -resize "${lado}x${lado}" -background none -gravity center \
          -extent "${px}x${px}" \
          -strip -define png:exclude-chunk=tIME,tEXt,zTXt "$tmp" 2>/dev/null; then
      rm -f "$tmp"; return 1
    fi
    if [ -f "$destino" ] && cmp -s "$tmp" "$destino"; then
      rm -f "$tmp"; continue
    fi
    if meow_seco; then rm -f "$tmp"; mudou_algum=1; continue; fi
    mkdir -p "$dir" || { rm -f "$tmp"; return 1; }
    pouso="$(mktemp -p "$dir" ".meow.XXXXXX.png")" || { rm -f "$tmp"; return 1; }
    install -m644 "$tmp" "$pouso" || { rm -f "$tmp" "$pouso"; return 1; }
    rm -f "$tmp"
    mv -f "$pouso" "$destino" || { rm -f "$pouso"; return 1; }
    mudou_algum=1
  done <<EOF_ESCADA
$(meow_icones_escada)
EOF_ESCADA

  [ "$mudou_algum" = 1 ] && return 2
  return 0
}

mudou=0; jogos=0; ferramentas=0; ausentes=0; escritos=0; fora=0; fora_notas=""
voltou=0; voltou_notas=""
fora_apagar="$(jogos_para_apagar | tr "\n" " ")"
vivos=""

while IFS= read -r lib; do
  [ -n "$lib" ] || continue
  if [ ! -d "$lib/steamapps" ]; then
    meow_aviso "biblioteca da Steam não montada ($lib) — os jogos dela ficam de fora e a limpeza é adiada"
    ausentes=$((ausentes + 1))
    continue
  fi

  for m in "$lib"/steamapps/appmanifest_*.acf; do
    [ -e "$m" ] || continue
    id="$(awk -F'"' '/"appid"/{print $4; exit}' "$m")"
    nome="$(awk -F'"' '/"name"/{print $4; exit}' "$m")"
    [ -n "$id" ] && [ -n "$nome" ] || continue
    case "$id" in ''|*[!0-9]*) continue ;; esac

    if jogo_fora "$id" && [ "$(jogo_fora_acao "$id")" = "apagar" ] && ja_apagado "$id"; then
      voltou_notas="$voltou_notas${voltou_notas:+$'\n'}$nome (appid $id)"
      voltou=$((voltou + 1))
    elif jogo_fora "$id"; then
      fora=$((fora + 1))
      fora_notas="$fora_notas${fora_notas:+$'\n'}$nome (appid $id) — $(jogo_fora_motivo "$id")"
      continue
    fi

    if ! capa_vertical "$id" && ! algum_icone_da_steam "$id"; then
      ferramentas=$((ferramentas + 1))
      continue
    fi

    jogos=$((jogos + 1))
    vivos="$vivos$id"$'\n'

    curto="$(meow_nome_do_mapa "steam-$id" 2>/dev/null)" || curto=""
    [ -n "$curto" ] && nome="$curto"

    if icone_bom_da_steam "$id"; then
      icone="steam_icon_$id"
    else
      plantar_icone "$id"
      case $? in
        0) icone="meow-steam-$id" ;;
        2) icone="meow-steam-$id"; mudou=1 ;;
        *) if algum_icone_da_steam "$id"; then icone="steam_icon_$id"; else icone="steam"; fi ;;
      esac
    fi

    corpo="$(printf '%s\n' \
      '[Desktop Entry]' \
      '# Gerado por MeowSystem/scripts/jogos_steam.sh a partir do appmanifest da Steam.' \
      '# Edições feitas aqui são desfeitas na próxima rodada — mude o script.' \
      'Type=Application' \
      'Version=1.0' \
      "Name=$nome" \
      "Comment=Jogo da Steam (appid $id)" \
      "Exec=$STEAM_BIN steam://rungameid/$id" \
      "Icon=$icone" \
      'Terminal=false' \
      'Categories=Game;' \
      'Keywords=steam;jogo;game;' \
      'StartupNotify=true' \
      "StartupWMClass=steam_app_$id" \
      'X-MeowSystem=jogo-steam' \
      "X-SteamAppId=$id")"

    novo=1; [ -f "$APPS/meow-steam-$id.desktop" ] && novo=0
    meow_escrever "$APPS/meow-steam-$id.desktop" "$corpo" 644
    case $? in
      1) mudou=1; escritos=$((escritos + 1))
         [ "$novo" = 1 ] && resumo_jogo entra "$id" "$nome" ;;
      2) meow_erro "não consegui instalar o atalho do appid $id"; exit "$MEOW_ERRO" ;;
    esac
  done
done < <(bibliotecas)

removidos=0; duplicatas=0; degraus_removidos=0
if [ "$ausentes" -gt 0 ]; then
  meow_info "biblioteca desmontada nesta rodada — limpeza de órfãos adiada de propósito"
else

  for f in "$APPS"/meow-steam-*.desktop; do
    [ -e "$f" ] || continue
    grep -q '^X-MeowSystem=jogo-steam$' "$f" || continue
    orfao="$(basename "$f" .desktop)"; orfao="${orfao#meow-steam-}"
    printf '%s' "$vivos" | grep -qx "$orfao" && continue
    resumo_jogo sai "$orfao" "$(awk -F= '$1 == "Name" { sub(/^Name=/, ""); print; exit }' "$f")"
    if meow_seco; then
      if jogo_fora "$orfao"; then
        meow_muda "tiraria do lançador o atalho do appid $orfao (está no jogos-fora.map)"
      else
        meow_muda "removeria o atalho de um jogo desinstalado (appid $orfao)"
      fi
    else
      rm -f "$f" "$HICOLOR"/*/apps/meow-steam-"$orfao".png
    fi
    mudou=1; removidos=$((removidos + 1))
  done

  escada_viva="$(meow_icones_escada)"
  for f in "$HICOLOR"/*/apps/meow-steam-*.png; do
    [ -e "$f" ] || continue
    degrau="$(basename "$(dirname "$(dirname "$f")")")"
    degrau="${degrau%%x*}"
    case "$degrau" in ''|*[!0-9]*) continue ;; esac
    printf '%s' "$escada_viva" | grep -qx "$degrau" && continue
    if meow_seco; then
      meow_muda "removeria $f (degrau $degrau fora da escada desta tela)"
    else
      meow_destino_permitido "$f" || continue
      rm -f "$f"
    fi
    mudou=1; degraus_removidos=$((degraus_removidos + 1))
  done

  bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-duplicatas"
  ja_tratados=""
  for f in "$APPS"/*.desktop; do
    [ -e "$f" ] || continue
    grep -q '^X-MeowSystem=jogo-steam$' "$f" && continue
    ids="$(grep -E '^Exec=' "$f" 2>/dev/null \
           | grep -oE 'steam://rungameid/[0-9]+|-applaunch[[:space:]]+[0-9]+' \
           | grep -oE '[0-9]+$' | sort -u)"
    [ -n "$ids" ] || continue
    [ "$(printf '%s\n' "$ids" | wc -l)" = "1" ] || continue
    id="$ids"
    printf '%s' "$vivos" | grep -qx "$id" || continue
    [ "$f" = "$APPS/meow-steam-$id.desktop" ] && continue
    resumo_jogo repete "$id" "$(awk -F= '$1 == "Name" { sub(/^Name=/, ""); print; exit }' "$f")"
    if meow_seco; then
      meow_muda "removeria o cartão duplicado do appid $id: $(basename "$f") (aponta para o jogo e não é nosso)"
    else
      mkdir -p "$bkp" 2>/dev/null && cp -a "$f" "$bkp/" 2>/dev/null || {
        meow_aviso "sem backup para $(basename "$f") — não removo o que não consigo guardar"
        continue
      }
      rm -f -- "$f"
      meow_muda "cartão duplicado do appid $id removido: $(basename "$f") (cópia em $bkp)"
    fi
    ja_tratados="$ja_tratados$f"$'\n'
    mudou=1; duplicatas=$((duplicatas + 1))
  done

  for f in "$APPS"/steam-jogo-*.desktop "$APPS"/steam-[0-9]*.desktop; do
    [ -e "$f" ] || continue
    printf '%s' "$ja_tratados" | grep -qxF "$f" && continue
    grep -q 'steam://rungameid/' "$f" || continue
    id="$(basename "$f" .desktop)"; id="${id##*-}"
    resumo_jogo repete "$id" "$(awk -F= '$1 == "Name" { sub(/^Name=/, ""); print; exit }' "$f")"
    if meow_seco; then
      meow_muda "removeria atalho do gerador antigo: $(basename "$f")"
    else
      rm -f "$f"
    fi
    mudou=1; removidos=$((removidos + 1))
  done

  while IFS= read -r id; do
    [ -n "$id" ] || continue
    f="$APPS/steam_app_$id.desktop"
    [ -e "$f" ] || continue
    printf '%s' "$ja_tratados" | grep -qxF "$f" && continue
    grep -qE "steam://rungameid/$id([[:space:]]|\$)" "$f" || continue
    resumo_jogo repete "$id" "$(awk -F= '$1 == "Name" { sub(/^Name=/, ""); print; exit }' "$f")"
    if meow_seco; then
      meow_muda "removeria o cartão duplicado do appid $id (molde da Steam, $(basename "$f"))"
    else
      mkdir -p "$bkp" 2>/dev/null && cp -a "$f" "$bkp/" 2>/dev/null || {
        meow_aviso "sem backup para $(basename "$f") — não removo o que não consigo guardar"
        continue
      }
      rm -f "$f"
      meow_muda "cartão duplicado do appid $id removido (cópia em $bkp)"
    fi
    mudou=1; duplicatas=$((duplicatas + 1))
  done <<< "$vivos"
  if [ "$duplicatas" -gt 0 ]; then
    if meow_seco; then
      meow_info "$duplicatas jogo(s) aparecem DUAS vezes no lançador"
    else
      meow_info "$duplicatas jogo(s) apareciam DUAS vezes no lançador — agora aparecem uma"
    fi
  fi

  velho="$HOME/.local/share/icons/steam-jogos"
  if [ -d "$velho" ] && ! grep -rqls 'assets/icones/steam-jogos' "$APPS" 2>/dev/null; then
    if meow_seco; then
      meow_muda "removeria o cache de ícones órfão do gerador antigo ($velho)"
    else
      rm -rf "$velho"
    fi
    mudou=1
  fi
fi

apagados=0
if [ -z "$fora_apagar" ]; then
  :
elif [ "$ausentes" -gt 0 ]; then
  meow_info "biblioteca desmontada nesta rodada — limpeza de arquivos de jogo adiada de propósito"
elif steam_rodando; then
  meow_info "Steam aberta — a limpeza dos arquivos de jogo fica para a próxima passagem"
else
  for id in $fora_apagar; do
    ja_apagado "$id" && continue

    alvo_m=""; alvo_pasta=""; alvo_nome=""
    while IFS= read -r lib; do
      [ -n "$lib" ] || continue
      m="$lib/steamapps/appmanifest_$id.acf"
      [ -f "$m" ] || continue
      alvo_m="$m"
      alvo_nome="$(awk -F\" '/"name"/{print $4; exit}' "$m")"
      instal="$(awk -F\" '/"installdir"/{print $4; exit}' "$m")"
      case "$instal" in
        ''|.|..|*/*) : ;;
        *) [ -d "$lib/steamapps/common/$instal" ] && alvo_pasta="$lib/steamapps/common/$instal" ;;
      esac
      break
    done < <(bibliotecas)

    if meow_seco; then
      if [ -n "$alvo_pasta" ] || [ -n "$alvo_m" ]; then
        resumo_jogo apaga "$id" "$alvo_nome"
        [ -n "$alvo_pasta" ] && meow_muda "apagaria $alvo_pasta ($(du -sh "$alvo_pasta" 2>/dev/null | cut -f1))"
        [ -n "$alvo_m" ] && meow_muda "apagaria $alvo_m"
        mudou=1
      else
        meow_muda "marcaria o appid $id como já apagado (nada dele no disco)"
        mudou=1
      fi
      continue
    fi

    falhou_algo=0
    if [ -n "$alvo_pasta" ]; then
      tam="$(du -sh "$alvo_pasta" 2>/dev/null | cut -f1)"
      if rm -rf -- "$alvo_pasta"; then
        meow_ok "apagados os arquivos de ${alvo_nome:-appid $id} (${tam:-?})"
        apagados=$((apagados + 1)); mudou=1
      else
        meow_aviso "não consegui apagar $alvo_pasta — o manifesto fica, para a próxima passagem terminar"
        falhou_algo=1
      fi
    fi

    if [ "$falhou_algo" = 0 ] && [ -n "$alvo_m" ]; then
      if rm -f -- "$alvo_m"; then
        [ -n "$alvo_pasta" ] || meow_ok "apagado o manifesto órfão do appid $id (a pasta já não existia)"
        mudou=1
      else
        meow_aviso "não consegui apagar $alvo_m"
        falhou_algo=1
      fi
    fi

    [ "$falhou_algo" = 0 ] && marcar_apagado "$id" "$alvo_nome"
  done
fi

sem_licenca=""
for _log in "$STEAM/logs/console_log.txt" "$STEAM/logs/console_log.previous.txt"; do
  [ -r "$_log" ] || continue
  while IFS= read -r _id; do
    case "$_id" in ''|*[!0-9]*) continue ;; esac
    jogo_fora "$_id" && continue
    printf '%s' "$vivos" | grep -qx "$_id" || continue
    case " $sem_licenca " in *" $_id "*) continue ;; esac
    sem_licenca="${sem_licenca:+$sem_licenca }$_id"
  done < <(grep -h 'AppError_5' "$_log" 2>/dev/null | grep -oE 'AppID [0-9]+' | awk '{print $2}' | sort -u)
done

_notas_finais() {
  [ "$ferramentas" -gt 0 ] &&
    meow_info "$ferramentas ferramenta(s) da Steam (Proton, runtimes) fora do lançador, de propósito"
  if [ "$fora" -gt 0 ]; then
    meow_info "$fora jogo(s) fora do lançador pelo assets/apps/jogos-fora.map:"
    printf '%s\n' "$fora_notas" | while IFS= read -r n; do
      [ -n "$n" ] && meow_info "  $n"
    done
  fi
  if [ "$voltou" -gt 0 ]; then
    meow_info "$voltou jogo(s) reinstalados depois de terem sido apagados — o cartão voltou, e nada foi tocado no disco:"
    printf '%s\n' "$voltou_notas" | while IFS= read -r n; do
      [ -n "$n" ] && meow_info "  $n"
    done
    meow_info "  a linha deles no assets/apps/jogos-fora.map está gasta e pode sair — deixá-la também não faz mal"
  fi
  if [ -n "$sem_licenca" ]; then
    meow_aviso "a Steam recusou licença (AppError_5) para: $sem_licenca"
    meow_info "  o cartão continua na tela porque o manifesto diz 'instalado' — pode ser só sessão caída ou modo offline"
    meow_info "  se for definitivo (demo retirada da loja), ponha no assets/apps/jogos-fora.map:"
    meow_info "    <appid>:apagar:<o motivo, com a data>   — tira da tela E limpa o disco"
  fi
  return 0
}
{ [ "$ferramentas" -gt 0 ] || [ "$fora" -gt 0 ] || [ "$voltou" -gt 0 ] || [ -n "$sem_licenca" ]; } && trap _notas_finais EXIT

if [ "$jogos" -eq 0 ]; then
  meow_pula "a Steam está instalada, e nenhum jogo dela vai para o lançador — nada a criar"
  [ "$mudou" = "1" ] && exit "$MEOW_DIVERGENTE"
  exit "$MEOW_OK"
fi

if [ "$mudou" = "0" ]; then
  meow_ok "$jogos jogo(s) da Steam no lançador, com a capa que a Steam baixou"
  exit "$MEOW_OK"
fi

if meow_seco; then
  meow_muda "$jogos jogo(s) da Steam: $escritos atalho(s) a escrever, $removidos a remover, $duplicatas cartão(ões) duplicado(s) a tirar do lançador"
  exit "$MEOW_DIVERGENTE"
fi

meow_tem update-desktop-database && update-desktop-database "$APPS" 2>/dev/null || true

meow_hicolor_reindexar

meow_lancador_reler

[ "$escritos" -gt 0 ] && meow_ok "$escritos jogo(s) da Steam no lançador (ícone natural, o do próprio jogo)"
[ "$removidos" -gt 0 ] && meow_ok "$removidos atalho(s) de jogo desinstalado removidos"
[ "${degraus_removidos:-0}" -gt 0 ] && meow_ok "$degraus_removidos ícone(s) em degrau fora da escada removidos (a escada desta tela é: $(meow_icones_escada_dita))"
[ "$duplicatas" -gt 0 ] && meow_ok "$duplicatas jogo(s) deixaram de aparecer duas vezes no lançador"
meow_info "para juntá-los num grupo: lançador → Novo grupo → nome 'Jogos' → categoria Game"
exit "$MEOW_DIVERGENTE"

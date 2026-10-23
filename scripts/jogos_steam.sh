#!/usr/bin/env bash
# jogos_steam.sh — um .desktop por jogo INSTALADO da Steam, no lançador dela.
#
# A FONTE DE VERDADE É O appmanifest, NÃO A ÁREA DE TRABALHO A versão copiava os
# `.desktop` que a Steam tivesse deixado na área de trabalho.
#
# DUAS BIBLIOTECAS, NÃO UMA `libraryfolders.vdf` declara `~/.steam/steam` E
# `/mnt/Mnemosyne/SteamLibrary`.
#
# Dos 30 manifestos, 9 são runtime (Proton, Steam Linux Runtime, Steamworks).
#
# Nada de tematizar: 21 capas repintadas na paleta viram 21 ícones iguais.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"
# `meow_nome_do_mapa`: o encurtamento do rótulo mora no `nomes_apps.sh`, com a
# lista em `assets/icones/apps-nomes.map`.
. "$RAIZ/scripts/nomes_apps.sh"

APPS="$HOME/.local/share/applications"
HICOLOR="$HOME/.local/share/icons/hicolor"
# A lista de appids que ficam fora do lançador mesmo tendo manifesto. O porquê
# de ela existir — e por que não dá para deduzir o caso dela — está no cabeçalho
# do próprio mapa.
MEOW_JOGOS_FORA="${MEOW_JOGOS_FORA:-$RAIZ/assets/icones/jogos-fora.map}"
STEAM="$HOME/.steam/steam"
CACHE="$STEAM/appcache/librarycache"
LIBVDF="$STEAM/steamapps/libraryfolders.vdf"

# A Steam aqui é NATIVA (deb): `which steam` -> /usr/games/steam, e
# /usr/share/applications/steam.desktop usa exatamente isso.
STEAM_BIN="$(command -v steam 2>/dev/null || true)"
[ -n "$STEAM_BIN" ] || STEAM_BIN="/usr/games/steam"

# --- O VERBO, QUE FALTAVA ---------------------------------------
# Todo script de `scripts/` aceita `--conferir` e `--aplicar`; este só entendia
# `MEOW_DRY_RUN=1` no ambiente.
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

# --- consultas ---------------------------------------------------------------

# `~/.steam/steam` é um symlink para `~/.steam/debian-installation`, que é
# EXATAMENTE o caminho que o `libraryfolders.vdf` grava. O `.steam/steam` fica
# como fallback para a máquina onde o vdf não existe.
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

# --- O RESUMO PARA A CAIXA DO PAINEL --------------
resumo_jogo() {
  [ "${MEOW_JOGOS_RESUMO:-}" = "1" ] || return 0
  printf '@@jogo %s %s %s\n' "$1" "$2" "${3:-appid $2}"
}

# 0 = está na lista de fora. O mapa é relido a cada consulta, e não carregado num
# array: são poucas linhas, e é a mesma disciplina do `meow_nome_do_mapa` — lista
# em memória global envelhece sem avisar.
jogo_fora() {
  [ -f "$MEOW_JOGOS_FORA" ] || return 1
  awk -F: -v id="$1" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $1 == id { achou = 1; exit }
    END { exit !achou }
  ' "$MEOW_JOGOS_FORA"
}

# O segundo campo é OPCIONAL, e é assim de propósito. Uma linha de duas partes —
# `<appid>:<motivo>` — continua valendo e continua significando a coisa mais
# fraca: tirar da tela e não encostar no disco.
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

# O motivo, para a linha de log dizer POR QUE aquele jogo não está na tela.
# Pula o campo da ação quando ele existe — senão o aviso sairia com um "apagar:"
# grudado na frente da frase.
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

# Os appids com ação `apagar`, um por linha — é sobre esta lista que a seção 2b
# corre, e não sobre os manifestos. O porquê está lá.
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

# --- O REGISTRO QUE FAZ O `apagar` SER DE UMA VEZ SÓ -------------------------
# Uma linha por appid: `<appid> <data ISO>`.
MEOW_JOGOS_APAGADOS="${MEOW_JOGOS_APAGADOS:-$MEOW_ESTADO/jogos-apagados}"

ja_apagado() {
  [ -f "$MEOW_JOGOS_APAGADOS" ] || return 1
  awk -v id="$1" '$1 == id { achou = 1; exit } END { exit !achou }' "$MEOW_JOGOS_APAGADOS"
}

# O NOME VAI JUNTO, e não é enfeite: depois que o manifesto some, ele é a ÚNICA
# coisa no disco que ainda liga aquele número a um jogo.
marcar_apagado() {
  meow_seco && return 0
  ja_apagado "$1" && return 0
  mkdir -p "$(dirname "$MEOW_JOGOS_APAGADOS")" 2>/dev/null || return 1
  printf '%s %s %s\n' "$1" "$(date -I)" "${2:-}" >> "$MEOW_JOGOS_APAGADOS"
}

# A Steam ABERTA reescreve manifesto e reabre arquivos do jogo a qualquer
# momento — inclusive baixando de novo o que acabamos de apagar.
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

# 0 = já está certo · 1 = não deu (sem convert, sem arte) · 2 = mudou / mudaria.
#
# Os degraus vêm de `meow_icones_escada` (lib/icones.sh), que os DERIVA da
# escala da tela em vez de cravá-los.
#
# A PROPORÇÃO 246/256 (96%) É MANTIDA EM TODO DEGRAU, e não é enfeite: era o
# respiro que a arte já tinha na caixa de 256.
plantar_icone() {
  local id="$1" fonte destino dir tmp px lado mudou_algum=0
  meow_tem convert || return 1
  fonte="$(arte_do_jogo "$id")" || return 1

  while read -r px; do
    [ -n "$px" ] || continue
    destino="$HICOLOR/${px}x${px}/apps/meow-steam-$id.png"
    meow_destino_permitido "$destino" || return 1
    dir="$(dirname "$destino")"
    mkdir -p "$dir" || return 1
    # 96% da caixa, como o 246/256 original.
    lado=$(( px * 96 / 100 ))
    [ "$lado" -lt 1 ] && lado=1
    # O temporário nasce DENTRO do diretório de destino: `mv` entre sistemas de
    # arquivos diferentes não é atômico (trava 2 do lib/comum.sh).
    tmp="$(mktemp -p "$dir" ".meow.XXXXXX.png")" || return 1
    if ! convert "$fonte" -resize "${lado}x${lado}" -background none -gravity center \
          -extent "${px}x${px}" \
          -strip -define png:exclude-chunk=tIME,tEXt,zTXt "$tmp" 2>/dev/null; then
      rm -f "$tmp"; return 1
    fi
    if [ -f "$destino" ] && cmp -s "$tmp" "$destino"; then
      rm -f "$tmp"; continue
    fi
    if meow_seco; then rm -f "$tmp"; mudou_algum=1; continue; fi
    chmod 644 "$tmp"
    mv -f "$tmp" "$destino" || { rm -f "$tmp"; return 1; }
    mudou_algum=1
  done <<EOF_ESCADA
$(meow_icones_escada)
EOF_ESCADA

  [ "$mudou_algum" = 1 ] && return 2
  return 0
}

# --- 1. os jogos, dos manifestos para o lançador ------------------------------

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

    # A LISTA DE FORA VEM ANTES DE TUDO — e não entra em `vivos` de propósito.
    # Não somar o appid ali é o que faz a limpeza da seção 2 APAGAR o cartão que
    # já existia, em vez de apenas parar de criá-lo.
    if jogo_fora "$id" && [ "$(jogo_fora_acao "$id")" = "apagar" ] && ja_apagado "$id"; then
      voltou_notas="$voltou_notas${voltou_notas:+$'\n'}$nome (appid $id)"
      voltou=$((voltou + 1))
    elif jogo_fora "$id"; then
      fora=$((fora + 1))
      # O `meow doctor` mostra só a PRIMEIRA linha de cada verificador. Por isso
      # a frase é guardada e entregue pelo `trap ... EXIT`, depois do veredito.
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

# --- 2. limpeza: o que existe no destino e não deveria mais existir -----------
# Só apaga com PROVA DE AUTORIA — e a prova que manda é o CONTEÚDO: para qual
# appid o cartão aponta, e se ele traz a nossa assinatura.

removidos=0; duplicatas=0; degraus_removidos=0
if [ "$ausentes" -gt 0 ]; then
  meow_info "biblioteca desmontada nesta rodada — limpeza de órfãos adiada de propósito"
else

  for f in "$APPS"/meow-steam-*.desktop; do
    [ -e "$f" ] || continue
    grep -q '^X-MeowSystem=jogo-steam$' "$f" || continue
    orfao="$(basename "$f" .desktop)"; orfao="${orfao#meow-steam-}"
    printf '%s' "$vivos" | grep -qx "$orfao" && continue
    # O nome é o do próprio cartão que sai: o manifesto pode já não existir.
    resumo_jogo sai "$orfao" "$(awk -F= '$1 == "Name" { sub(/^Name=/, ""); print; exit }' "$f")"
    if meow_seco; then
      # A limpeza é a mesma; o porquê, não.
      if jogo_fora "$orfao"; then
        meow_muda "tiraria do lançador o atalho do appid $orfao (está no jogos-fora.map)"
      else
        meow_muda "removeria o atalho de um jogo desinstalado (appid $orfao)"
      fi
    else
      # Remove de TODO degrau — inclusive dos que saíram da escada quando a
      # escala da tela mudou; por isso o glob e não a lista.
      rm -f "$f" "$HICOLOR"/*/apps/meow-steam-"$orfao".png
    fi
    mudou=1; removidos=$((removidos + 1))
  done

  # DEGRAU ÓRFÃO — o outro eixo da limpeza, e ele é NOVO A varredura acima
  # remove o ícone de um JOGO que saiu da biblioteca.
  #
  # O critério é a escada VIVA, não uma lista: `meow_icones_escada` responde o
  # que vale agora, e todo `<tam>x<tam>/apps/meow-steam-*.png` fora dela sai.
  escada_viva="$(meow_icones_escada)"
  for f in "$HICOLOR"/*/apps/meow-steam-*.png; do
    [ -e "$f" ] || continue
    degrau="$(basename "$(dirname "$(dirname "$f")")")"   # "256x256"
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

  # --- O RIVAL RECONHECIDO PELO CONTEÚDO -------------------------
  #
  # Ela instalou Future Knight e viu DOIS cartões.
  #
  # Enquanto o reconhecimento for por nome de arquivo, sempre haverá um quinto.
  #
  # Um `.desktop` que ELA escreveu à mão para um jogo que ESTÁ instalado é
  # indistinguível do atalho da Steam: mesmo `rungameid`, sem a nossa marca,
  # nome de arquivo livre.
  bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-duplicatas"
  # Os caminhos que esta regra já resolveu, para os moldes por nome não contarem
  # o mesmo arquivo duas vezes. No modo seco nada sai do disco, então o `[ -e ]`
  # dos laços de baixo não bastaria para evitar a contagem dupla.
  ja_tratados=""
  for f in "$APPS"/*.desktop; do
    [ -e "$f" ] || continue
    # (b) primeiro, porque é a peneira mais barata: nesta máquina 23 dos 24
    # `.desktop` com `rungameid` são nossos e saem daqui na primeira linha.
    grep -q '^X-MeowSystem=jogo-steam$' "$f" && continue
    # (a) SÓ a linha do `Exec=`.
    ids="$(grep -E '^Exec=' "$f" 2>/dev/null \
           | grep -oE 'steam://rungameid/[0-9]+|-applaunch[[:space:]]+[0-9]+' \
           | grep -oE '[0-9]+$' | sort -u)"
    [ -n "$ids" ] || continue
    # Dois appids distintos no mesmo `Exec=` não é atalho de UM jogo — é um
    # script dela que abre mais de um. Não temos substituto para "os dois".
    [ "$(printf '%s\n' "$ids" | wc -l)" = "1" ] || continue
    id="$ids"
    # (c) o substituto existe...
    printf '%s' "$vivos" | grep -qx "$id" || continue
    # ...e o substituto NUNCA pode ser a vítima da própria regra. Sem esta
    # linha, um `meow-steam-<id>.desktop` que tivesse perdido a marca (arquivo
    # truncado, edição à mão) seria removido por apontar para si mesmo.
    [ "$f" = "$APPS/meow-steam-$id.desktop" ] && continue
    # A caixa dos jogos conta também os cartões que saem sem ser nossos:
    # sem esta linha ela dizia «nenhum atalho sai» com um duplicado saindo,
    # e só o «Ver sem mudar» o mostrava.
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

  # Hoje não existe nenhum dos dois no disco — isto é trava preventiva contra a
  # duplicata, não limpeza pendente.
  #
  # Estes dois nomes são PROVA DE AUTORIA NOSSA: quem os escreveu foi um gerador
  # deste projeto (ou do Ritual da Aurora), então podem sair mesmo quando o
  # appid NÃO está em `vivos` — cartão órfão de jogo desinstalado, exatamente
  # onde a regra por conteúdo se cala por não ter substituto a oferecer.
  for f in "$APPS"/steam-jogo-*.desktop "$APPS"/steam-[0-9]*.desktop; do
    [ -e "$f" ] || continue
    printf '%s' "$ja_tratados" | grep -qxF "$f" && continue
    grep -q 'steam://rungameid/' "$f" || continue
    # O appid é o fim do nome nos dois moldes (`steam-jogo-<id>`, `steam-<id>`).
    id="$(basename "$f" .desktop)"; id="${id##*-}"
    resumo_jogo repete "$id" "$(awk -F= '$1 == "Name" { sub(/^Name=/, ""); print; exit }' "$f")"
    if meow_seco; then
      meow_muda "removeria atalho do gerador antigo: $(basename "$f")"
    else
      rm -f "$f"
    fi
    mudou=1; removidos=$((removidos + 1))
  done

  # O TERCEIRO DONO: `steam_app_<appid>.desktop`, escrito com o MOLDE DA STEAM.
  #
  # A causa não foi a Steam: o fato medido continua de pé — a Steam não escreve
  # `.desktop` de jogo em `~/.local/share/applications`, ela escreve na ÁREA DE
  # TRABALHO, com o NOME DO JOGO no arquivo, e só quando a pessoa pede um por um
  # (os três que sobraram lá provam o formato).
  #
  # A promessa deste script é "um dono só".
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    f="$APPS/steam_app_$id.desktop"
    [ -e "$f" ] || continue
    printf '%s' "$ja_tratados" | grep -qxF "$f" && continue
    # `([[:space:]]|$)` e não `$` solto: o molde da Steam termina a linha no
    # appid, mas um `%U` ou uma opção depois dele continua sendo o mesmo jogo —
    # e sem a âncora, `rungameid/316790` casaria com `rungameid/3167900`.
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
  # A frase muda com o modo: em 15/08 o seco dizia "agora aparecem uma" sem ter
  # tirado nada do disco. Modo de auditoria que fala no passado é o mesmo
  # "aplicado" mentiroso que o `meow_notificar` já teve de tapar.
  if [ "$duplicatas" -gt 0 ]; then
    if meow_seco; then
      meow_info "$duplicatas jogo(s) aparecem DUAS vezes no lançador"
    else
      meow_info "$duplicatas jogo(s) apareciam DUAS vezes no lançador — agora aparecem uma"
    fi
  fi

  # Cache de ícones do gerador do Aurora, órfão desde 29/07 (17 PNGs, um deles de
  # um jogo que ela nem tem mais). Só sai quando nenhum `.desktop` o referencia.
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

# --- 2b. os arquivos em disco dos appids marcados `apagar` --------------------
#
# O `apagar` DISPARA UMA VEZ SÓ — E ESSA É A CORREÇÃO DE 02/09/2026
#   A primeira versão deste bloco era PERMANENTE: enquanto a linha existisse,
#   toda passagem garantia que os arquivos não estavam no disco. O aviso dizia
#   "se um dia você reinstalar, tire a linha ANTES". Ela recusou, e com razão:
#   *"aí não. tem que ser automatico pq é fogo assim."* Uma regra que só não
#   destrói porque alguém lembrou de um bilhete de meses atrás não é conserto —
#   é uma armadilha com documentação.
#
#   O que separa "sobra de licença revogada" de "reinstalação deliberada" está no
#   próprio comportamento da Steam: ela só escreve `appmanifest_<appid>.acf`
#   quando a pessoa manda instalar. Então um manifesto que aparece DEPOIS de já
#   termos apagado aquele appid é ela reinstalando, e nada mais.
#
#   Por isso o disparo é registrado em
#   `~/.local/state/meowsystem/jogos-apagados`, e a linha do mapa fica GASTA: o
#   bloco não apaga de novo, o cartão volta ao lançador como o de qualquer jogo,
#   e o script AVISA que a linha pode sair do mapa. Ela não precisa lembrar de
#   nada; no pior caso lê um aviso.
#
# POR QUE O LAÇO É SOBRE O MAPA, E NÃO SOBRE OS MANIFESTOS
#   Se fosse sobre os manifestos, uma linha `apagar` cujo jogo JÁ não está no
#   disco nunca seria vista — e nunca seria marcada como gasta. A reinstalação
#   seguinte cairia como primeira vez, e o download novo seria apagado. É
#   exatamente o caso do 4046520, cujos arquivos saíram antes deste registro
#   existir: percorrendo o mapa, a próxima passagem o marca sem apagar nada.
#
# POR QUE ISTO É SEGURO SENDO UM `rm -rf`
#   A pasta NUNCA é montada a partir do mapa. Ela sai do `"installdir"` do
#   próprio `appmanifest_<appid>.acf`, colada em `<biblioteca>/steamapps/common/`.
#   Um appid errado na lista não acha manifesto e não apaga nada; um `installdir`
#   com barra, `.` ou `..` é recusado antes de virar caminho. O mapa escolhe QUAL
#   jogo; quem diz ONDE ele mora é a Steam.
#
# A ORDEM É PASTA E DEPOIS MANIFESTO, E ISSO NÃO É DETALHE
#   O manifesto é a ÚNICA coisa que sabe o nome da pasta. Apagado primeiro, uma
#   queda de energia no meio deixaria 2,4 G num diretório que ninguém mais sabe
#   associar a nada. Na ordem certa, o pior caso é um manifesto sobrando — que a
#   passagem seguinte encontra e termina.
apagados=0
if [ -z "$fora_apagar" ]; then
  :
elif [ "$ausentes" -gt 0 ]; then
  meow_info "biblioteca desmontada nesta rodada — limpeza de arquivos de jogo adiada de propósito"
elif steam_rodando; then
  meow_info "Steam aberta — a limpeza dos arquivos de jogo fica para a próxima passagem"
else
  for id in $fora_apagar; do
    ja_apagado "$id" && continue          # linha gasta: a seção 1 já tratou

    # Achar o manifesto, em qualquer das bibliotecas.
    alvo_m=""; alvo_pasta=""; alvo_nome=""
    while IFS= read -r lib; do
      [ -n "$lib" ] || continue
      m="$lib/steamapps/appmanifest_$id.acf"
      [ -f "$m" ] || continue
      alvo_m="$m"
      alvo_nome="$(awk -F\" '/"name"/{print $4; exit}' "$m")"
      instal="$(awk -F\" '/"installdir"/{print $4; exit}' "$m")"
      case "$instal" in
        ''|.|..|*/*) : ;;   # nome de pasta que não é nome de pasta: não vira caminho
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

    # O REGISTRO SÓ SAI COM A LIMPEZA INTEIRA FEITA. Marcar depois de uma remoção
    # pela metade gastaria a linha deixando lixo — e a passagem seguinte, vendo a
    # linha gasta, nunca voltaria para terminar o serviço.
    [ "$falhou_algo" = 0 ] && marcar_apagado "$id" "$alvo_nome"
  done
fi

# --- 2c. o PRÓXIMO caso: avisar, e nunca apagar por conta própria -------------
#
# A Steam não guarda em arquivo nenhum "esta conta perdeu a licença deste app" —
# medido em 02/09/2026: manifesto, libraryfolders.vdf e localconfig.vdf continuam
# todos dizendo "instalado". O único lugar onde aquilo aparece é o log do
# cliente, na forma `RequestingLicense` -> `AppError_5`.
#
# POR QUE ISSO SÓ AVISA
#   A MESMA linha sai com a Steam em modo offline, com a sessão caída e com
#   licença de família em uso por outra pessoa. Apagar cartão — ou pior, 2,4 G —
#   a partir dela seria o script punindo uma queda de rede. Então ele aponta, diz
#   a data, e a decisão continua sendo dela, numa linha do mapa.
sem_licenca=""
for _log in "$STEAM/logs/console_log.txt" "$STEAM/logs/console_log.previous.txt"; do
  [ -r "$_log" ] || continue
  while IFS= read -r _id; do
    case "$_id" in ''|*[!0-9]*) continue ;; esac
    jogo_fora "$_id" && continue                     # ela já decidiu sobre este
    printf '%s' "$vivos" | grep -qx "$_id" || continue  # não tem cartão: nada a dizer
    case " $sem_licenca " in *" $_id "*) continue ;; esac
    sem_licenca="${sem_licenca:+$sem_licenca }$_id"
  done < <(grep -h 'AppError_5' "$_log" 2>/dev/null | grep -oE 'AppID [0-9]+' | awk '{print $2}' | sort -u)
done

# --- 3. o veredito ------------------------------------------------------------

# A NOTA DAS FERRAMENTAS SAI POR ÚLTIMO, E É POR CAUSA DA TABELA DO `meow doctor`
#   O `bin/meow` mostra na coluna só a PRIMEIRA linha de cada verificador
#   (`primeira_linha`, seção 6). Impressa aqui, antes do veredito, esta nota
#   virava a linha da tabela: em 10/08/2026 o `meow doctor` dizia "9
#   ferramenta(s) da Steam (Proton, runtimes) fora do lançador" na linha `jogos`
#   — número certo, coisa errada, e nenhum sinal dos 21 jogos. O `trap ... EXIT`
#   entrega a mesma frase depois de qualquer um dos quatro vereditos, sem
#   repeti-la nos quatro nem mexer nos `exit` que carregam o código de retorno.
#   UM TRAP SÓ, DUAS NOTAS. `trap ... EXIT` chamado duas vezes SUBSTITUI o
#   anterior — dois `trap` aqui fariam a segunda nota apagar a primeira em
#   silêncio, que é pior do que não ter nota nenhuma.
_notas_finais() {
  [ "$ferramentas" -gt 0 ] &&
    meow_info "$ferramentas ferramenta(s) da Steam (Proton, runtimes) fora do lançador, de propósito"
  if [ "$fora" -gt 0 ]; then
    meow_info "$fora jogo(s) fora do lançador pelo assets/icones/jogos-fora.map:"
    printf '%s\n' "$fora_notas" | while IFS= read -r n; do
      [ -n "$n" ] && meow_info "  $n"
    done
  fi
  if [ "$voltou" -gt 0 ]; then
    meow_info "$voltou jogo(s) reinstalados depois de terem sido apagados — o cartão voltou, e nada foi tocado no disco:"
    printf '%s\n' "$voltou_notas" | while IFS= read -r n; do
      [ -n "$n" ] && meow_info "  $n"
    done
    meow_info "  a linha deles no assets/icones/jogos-fora.map está gasta e pode sair — deixá-la também não faz mal"
  fi
  if [ -n "$sem_licenca" ]; then
    meow_aviso "a Steam recusou licença (AppError_5) para: $sem_licenca"
    meow_info "  o cartão continua na tela porque o manifesto diz 'instalado' — pode ser só sessão caída ou modo offline"
    meow_info "  se for definitivo (demo retirada da loja), ponha no assets/icones/jogos-fora.map:"
    meow_info "    <appid>:apagar:<o motivo, com a data>   — tira da tela E limpa o disco"
  fi
  return 0
}
{ [ "$ferramentas" -gt 0 ] || [ "$fora" -gt 0 ] || [ "$voltou" -gt 0 ] || [ -n "$sem_licenca" ]; } && trap _notas_finais EXIT

# «NENHUM JOGO INSTALADO TEM MANIFESTO» NÃO ERA O CASO — P54 (achado 43). Medido
# no painel de verdade: cinco manifestos no disco, todos de ferramenta (Proton,
# runtimes), e a frase dizia que faltava manifesto. `jogos` é 0 quando nenhum
# manifesto é de jogo que vá para o lançador; o porquê de cada um sai nas notas
# do fim (as ferramentas e os que estão fora pelo mapa).
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

# `update-desktop-database` é índice de MIME, não a lista do lançador — se faltar,
# o lançador acha do mesmo jeito na varredura seguinte. Só o diretório do USUÁRIO.
meow_tem update-desktop-database && update-desktop-database "$APPS" 2>/dev/null || true

# A MESMA CACHE VELHA DO IRMÃO DO HEROIC — 10/09/2026
#   Este script planta `meow-steam-<appid>.png` no hicolor desde 10/08 e nunca
#   reindexou. Na tela dela não aparecia porque o COSMIC varre o disco; some no
#   GTK, e some no PAINEL, que resolve ícone por PyGObject — um jogo novo entrava
#   na aba de ícones como órfão. A medição está no cabeçalho de
#   `meow_hicolor_reindexar` (lib/icones.sh).
meow_hicolor_reindexar

# E O LANÇADOR TEM DE SER AVISADO — 02/09/2026
#   A frase acima ("o lançador acha do mesmo jeito na varredura seguinte") vale
#   para o índice de MIME e é FALSA para o COSMIC: o `cosmic-app-library` e o
#   `cosmic-launcher` resolvem os `.desktop` no arranque e guardam. Sem
#   chacoalhá-los, o arquivo saiu do disco e o cartão continua na tela — que é
#   exatamente a queixa dela de hoje, "tem jogo da steam que tá desinstalado mas
#   ainda tem o .desktop".
#
#   O `atalho.sh` já fazia isso desde que nasceu; este script, que mexe em vinte
#   e poucos cartões de uma vez, não fazia. Estava do lado errado da mesma
#   medição — a que o cabeçalho de `meow_lancador_reler` registra.
#
#   SÓ AQUI, DEPOIS DO `meow_seco`: a função fecha a grade de aplicativos se ela
#   estiver aberta, e este ponto do script é o único onde já se sabe que algo
#   mudou de verdade.
meow_lancador_reler

[ "$escritos" -gt 0 ] && meow_ok "$escritos jogo(s) da Steam no lançador (ícone natural, o do próprio jogo)"
[ "$removidos" -gt 0 ] && meow_ok "$removidos atalho(s) de jogo desinstalado removidos"
# A MENSAGEM NÃO PODE MENTIR: degrau órfão não é jogo desinstalado. Os dois
# contadores existem separados porque a primeira versão somava tudo em
# `removidos` e anunciou "7 atalhos de jogo desinstalado" quando o que saíra
# foram sete arquivos `256x256` de jogos que continuam instalados.
[ "${degraus_removidos:-0}" -gt 0 ] && meow_ok "$degraus_removidos ícone(s) em degrau fora da escada removidos (a escada desta tela é: $(meow_icones_escada_dita))"
[ "$duplicatas" -gt 0 ] && meow_ok "$duplicatas jogo(s) deixaram de aparecer duas vezes no lançador"
meow_info "para juntá-los num grupo: lançador → Novo grupo → nome 'Jogos' → categoria Game"
exit "$MEOW_DIVERGENTE"

#!/usr/bin/env bash
# jogos_steam.sh — um .desktop por jogo INSTALADO da Steam, no lançador dela.
#
# A FONTE DE VERDADE É O appmanifest, NÃO A ÁREA DE TRABALHO
#   A versão de 05/08 copiava os `.desktop` que a Steam tivesse deixado na área
#   de trabalho. Ela apagou aqueles oito arquivos, a mesa ficou vazia, e o
#   script virou um no-op que saía 0 — o `meow doctor` pintava "jogos" de verde
#   todo dia enquanto NENHUM jogo existia no lançador. A Steam só escreve
#   `.desktop` de jogo quando a pessoa pede "criar atalho", um por um; esperar
#   por isso é esperar por nada. Aqui a fonte passa a ser
#   `appmanifest_*.acf`, que a Steam mantém sozinha para cada jogo instalado.
#
# DUAS BIBLIOTECAS, NÃO UMA
#   `libraryfolders.vdf` declara `~/.steam/steam` E `/mnt/Mnemosyne/SteamLibrary`.
#   Quem lê só a primeira perde o Black Myth: Wukong — o jogo mais pesado do
#   disco — em silêncio. E quando /mnt/Mnemosyne não está montado, a ausência do
#   manifesto é FALSA: por isso a limpeza de órfãos é adiada nessa rodada, em vez
#   de apagar o atalho e recriá-lo na boot seguinte, o script brigando consigo.
#
# JOGO x FERRAMENTA, POR ESTRUTURA E NÃO POR NOME
#   Dos 30 manifestos, 9 são runtime (Proton, Steam Linux Runtime, Steamworks).
#   Casar `Proton*` no nome quebra no dia em que a Valve mudar o rótulo, ou
#   quando um jogo de verdade se chamar "Protocol". O critério aqui é a capa
#   vertical no `librarycache`: medido nesta máquina, 21 de 21 jogos têm uma, e
#   0 de 9 ferramentas tem. O segundo critério (ícone `steam_icon_<appid>` no
#   hicolor) cobre o jogo recém-instalado cuja arte ainda não baixou — e também
#   nenhuma das 9 ferramentas o tem.
#
# O ÍCONE FICA NATURAL, A PEDIDO DELA
#   Nada de tematizar: 21 capas repintadas na paleta viram 21 ícones iguais. A
#   capa é a identidade do jogo. E o `Icon=` guarda um NOME, nunca um caminho
#   dentro de `~/.steam` — aquilo é cache do cliente, e a subpasta muda de nome
#   a cada atualização de arte.
#
# UM CARTÃO POR JOGO — E ISSO INCLUI O CARTÃO QUE OUTRO ESCREVEU
#   Escrever o nosso não basta: o lançador mostra TUDO que houver em
#   `~/.local/share/applications`, e um segundo `.desktop` com o mesmo `Name=`
#   é um segundo cartão. Aconteceu em 15/08/2026 com 17 jogos — quinze deles com
#   o nome idêntico, e foi esse quinze que ela contou na tela (ver a seção 2).
#   Por isso a limpeza tem três donos rivais, e não dois.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"
# `meow_nome_do_mapa`: o encurtamento do rótulo mora no `nomes_apps.sh`, com a
# lista em `assets/icones/apps-nomes.map`. As chaves de lá são `steam-<appid>` (o Sackboy
# e o ORPHEUS estouravam a célula do lançador) — a chave NÃO muda junto com o
# prefixo do arquivo, senão o mapa deixaria de casar em silêncio.
. "$RAIZ/scripts/nomes_apps.sh"

APPS="$HOME/.local/share/applications"
HICOLOR="$HOME/.local/share/icons/hicolor"
STEAM="$HOME/.steam/steam"
CACHE="$STEAM/appcache/librarycache"
LIBVDF="$STEAM/steamapps/libraryfolders.vdf"

# A Steam aqui é NATIVA (deb): `which steam` -> /usr/games/steam, e
# /usr/share/applications/steam.desktop usa exatamente isso. Nada de flatpak, e
# nada de /usr/local/bin/steam-resiliente.sh: aquele wrapper é do Ritual da
# Aurora e o self-heal pode removê-lo — um Exec quebrado é um jogo que não abre.
STEAM_BIN="$(command -v steam 2>/dev/null || true)"
[ -n "$STEAM_BIN" ] || STEAM_BIN="/usr/games/steam"

meow_tem awk || { meow_pula "sem awk — não dá para ler os manifestos da Steam"; exit "$MEOW_SEM_DEPENDENCIA"; }

if [ ! -d "$STEAM/steamapps" ]; then
  meow_pula "Steam não instalada — nada a fazer"
  exit "$MEOW_OK"
fi

# --- consultas ---------------------------------------------------------------

# CANONICALIZAR ANTES DO `sort -u` NÃO É ZELO, É O QUE FAZ A DEDUPLICAÇÃO EXISTIR.
# `~/.steam/steam` é um symlink para `~/.steam/debian-installation`, que é
# EXATAMENTE o caminho que o `libraryfolders.vdf` grava. São duas strings
# diferentes para o mesmo diretório: sem o `readlink -f`, o `sort -u` deixa as
# duas passarem e cada jogo é processado DUAS vezes (medido: 41 jogos e 18
# ferramentas onde há 21 e 9). O `.steam/steam` fica como fallback para a
# máquina onde o vdf não existe.
bibliotecas() {
  { printf '%s\n' "$STEAM"
    [ -r "$LIBVDF" ] && awk -F'"' '/^[[:space:]]*"path"/ {print $4}' "$LIBVDF"
  } | while IFS= read -r p; do
        [ -n "$p" ] || continue
        readlink -f -- "$p" 2>/dev/null || printf '%s\n' "$p"
      done | sort -u
  return 0
}

# A arte por BUSCA, não por caminho fixo: a Steam renomeou `library_600x900.jpg`
# para `library_capsule.jpg` e passou a enterrar cada arte numa subpasta cujo
# nome é o hash do conteúdo. `-type f` sem `-maxdepth` cobre os dois layouts;
# `sort -rn` pelo TAMANHO desempata quando sobra uma versão antiga ao lado da
# nova. O jpg de nome-hash (32x32) fica FORA da lista de propósito: ampliá-lo
# 8x planta um borrão, e um borrão é pior que o ícone genérico da Steam.
arte_do_jogo() {
  local c="$CACHE/$1" f nome
  [ -d "$c" ] || return 1
  for nome in library_capsule.jpg library_600x900.jpg library_header.jpg header.jpg logo.png; do
    f="$(find "$c" -type f -name "$nome" -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -1 | cut -f2-)"
    [ -n "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}

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
# O `-strip` + `exclude-chunk=tIME` é o que torna a saída BYTE-IDÊNTICA para a
# mesma entrada: sem ele o timestamp embutido no PNG faz o arquivo mudar toda
# rodada e o doctor acusa divergência eterna. Medido: dois `convert` separados
# por um segundo dão o mesmo sha256.
# A ESCADA INTEIRA, E NÃO UM TAMANHO SÓ — 27/08/2026
#   Este script plantava em `256x256` e mais nada. Medido no resolvedor real,
#   com a dock desenhando aplicativo a 41 px de dispositivo: os sete
#   `meow-steam-*` devolviam pixbuf 256x256 para TODO pedido, ou seja uma
#   redução de 6,2x em tempo de desenho. É o mesmo defeito que o
#   `icones_apps.sh` curou em 08/08/2026 para o acervo Catppuccin — e a lição
#   nunca tinha chegado aqui. Foi o que ela viu: "tem mt icon quebrados".
#
#   Os degraus vêm de `meow_icones_escada` (lib/icones.sh), que os DERIVA da
#   escala da tela em vez de cravá-los. Nesta tela, a 114%, sai
#   `16 22 24 32 48 56 64 72 80 96`.
#
#   A PROPORÇÃO 246/256 (96%) É MANTIDA EM TODO DEGRAU, e não é enfeite: era o
#   respiro que a arte já tinha na caixa de 256. Cravar 246 nos outros tamanhos
#   colaria a arte na borda dos pequenos e deixaria os grandes com folga demais.
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

mudou=0; jogos=0; ferramentas=0; ausentes=0; escritos=0
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

    meow_escrever "$APPS/meow-steam-$id.desktop" "$corpo" 644
    case $? in
      1) mudou=1; escritos=$((escritos + 1)) ;;
      2) meow_erro "não consegui instalar o atalho do appid $id"; exit "$MEOW_ERRO" ;;
    esac
  done
done < <(bibliotecas)

# --- 2. limpeza: o que existe no destino e não deveria mais existir -----------
# Só apaga com PROVA DE AUTORIA (a marca X-MeowSystem, o `rungameid` dos dois
# geradores antigos, ou o par nome-de-arquivo + appid do molde da Steam). Nunca
# por prefixo de nome sozinho: um `.desktop` que ela escreveu à mão não é órfão
# de ninguém.

removidos=0; duplicatas=0; degraus_removidos=0
if [ "$ausentes" -gt 0 ]; then
  meow_info "biblioteca desmontada nesta rodada — limpeza de órfãos adiada de propósito"
else

  for f in "$APPS"/meow-steam-*.desktop; do
    [ -e "$f" ] || continue
    grep -q '^X-MeowSystem=jogo-steam$' "$f" || continue
    orfao="$(basename "$f" .desktop)"; orfao="${orfao#meow-steam-}"
    printf '%s' "$vivos" | grep -qx "$orfao" && continue
    if meow_seco; then
      meow_muda "removeria o atalho de um jogo desinstalado (appid $orfao)"
    else
      # Remove de TODO degrau — inclusive dos que saíram da escada quando a
      # escala da tela mudou; por isso o glob e não a lista.
      rm -f "$f" "$HICOLOR"/*/apps/meow-steam-"$orfao".png
    fi
    mudou=1; removidos=$((removidos + 1))
  done

  # DEGRAU ÓRFÃO — o outro eixo da limpeza, e ele é NOVO (27/08/2026)
  #   A varredura acima remove o ícone de um JOGO que saiu da biblioteca. Falta
  #   o caso simétrico: o jogo continua, mas o DEGRAU saiu da escada — foi o que
  #   aconteceu ao ligar a escada derivada, com os `256x256` antigos sobrando
  #   fora dela. Sem isto, cada mudança de escala da tela deixaria uma camada de
  #   arquivos mortos, e o resolvedor poderia escolher justamente um deles.
  #
  #   O critério é a escada VIVA, não uma lista: `meow_icones_escada` responde o
  #   que vale agora, e todo `<tam>x<tam>/apps/meow-steam-*.png` fora dela sai.
  #   Por isso a escada tem de ser a mesma função que PLANTA — duas listas aqui
  #   seriam o defeito de dois donos com outra roupa.
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

  # Os dois donos antigos: `steam-jogo-<appid>.desktop` (steam-gera-atalhos.sh do
  # Ritual da Aurora) e `steam-<appid>.desktop` (a versão anterior deste script).
  # Hoje não existe nenhum dos dois no disco — isto é trava preventiva contra a
  # duplicata, não limpeza pendente.
  for f in "$APPS"/steam-jogo-*.desktop "$APPS"/steam-[0-9]*.desktop; do
    [ -e "$f" ] || continue
    grep -q 'steam://rungameid/' "$f" || continue
    if meow_seco; then
      meow_muda "removeria atalho do gerador antigo: $(basename "$f")"
    else
      rm -f "$f"
    fi
    mudou=1; removidos=$((removidos + 1))
  done

  # O TERCEIRO DONO: `steam_app_<appid>.desktop`, escrito com o MOLDE DA STEAM.
  #
  #   Em 15/08/2026 ela viu QUINZE jogos duas vezes no lançador. A causa não foi
  #   a Steam: o fato medido em 10/08 continua de pé — a Steam não escreve
  #   `.desktop` de jogo em `~/.local/share/applications`, ela escreve na ÁREA DE
  #   TRABALHO, com o NOME DO JOGO no arquivo, e só quando a pessoa pede um por
  #   um (os três que sobraram lá provam o formato). Os 17 `steam_app_<id>` de
  #   14/08 03:02 nasceram do RESGATE do estrago do BleachBit daquela noite:
  #   recriados a partir dos ícones que sobreviveram, usando aquele molde. Duas
  #   horas depois este script rodou e escreveu os dele. Dois cartões por jogo.
  #
  #   A promessa deste script é "um dono só". Ela falhou porque a lista de
  #   rivais foi escrita em 10/08 e não previa o nome que o molde da Steam
  #   produz. Então o rival entra na lista — e não como contorno: enquanto
  #   houver um `.desktop` por jogo que este script não escreveu, o lançador
  #   mostra dois cartões, e o próximo resgate refaz a duplicata.
  #
  # AS QUATRO CONDIÇÕES, E POR QUE CADA UMA
  #   1. a biblioteca está montada (estamos dentro do `else`) — senão o rival
  #      pode ser o ÚNICO cartão de um jogo cujo manifesto não enxergamos hoje;
  #   2. o appid está em `vivos`, isto é, ACABAMOS de escrever o cartão dele —
  #      nunca removemos um rival sem deixar um substituto no lugar;
  #   3. o nome do arquivo é exatamente `steam_app_<appid>.desktop`;
  #   4. o corpo aponta para `steam://rungameid/<appid>`, o MESMO appid.
  #   Nada disso é prefixo solto: um `.desktop` que ela escreveu à mão com outro
  #   nome continua intocado, como em 10/08.
  #
  # BACKUP ANTES, PORQUE ESTE ARQUIVO NÃO É NOSSO
  #   Os órfãos acima carregam a marca `X-MeowSystem` — são nossos, e apagar o
  #   que escrevemos é reversível por definição. Este não: guardamos a cópia em
  #   `$MEOW_ESTADO/backups/<carimbo>-duplicatas/` antes de remover, e a remoção
  #   é ANUNCIADA na saída, nunca silenciosa.
  bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-duplicatas"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    f="$APPS/steam_app_$id.desktop"
    [ -e "$f" ] || continue
    # `([[:space:]]|$)` e não `$` solto: o molde da Steam termina a linha no
    # appid, mas um `%U` ou uma opção depois dele continua sendo o mesmo jogo —
    # e sem a âncora, `rungameid/316790` casaria com `rungameid/3167900`.
    grep -qE "steam://rungameid/$id([[:space:]]|\$)" "$f" || continue
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

# --- 3. o veredito ------------------------------------------------------------

# A NOTA DAS FERRAMENTAS SAI POR ÚLTIMO, E É POR CAUSA DA TABELA DO `meow doctor`
#   O `bin/meow` mostra na coluna só a PRIMEIRA linha de cada verificador
#   (`primeira_linha`, seção 6). Impressa aqui, antes do veredito, esta nota
#   virava a linha da tabela: em 10/08/2026 o `meow doctor` dizia "9
#   ferramenta(s) da Steam (Proton, runtimes) fora do lançador" na linha `jogos`
#   — número certo, coisa errada, e nenhum sinal dos 21 jogos. O `trap ... EXIT`
#   entrega a mesma frase depois de qualquer um dos quatro vereditos, sem
#   repeti-la nos quatro nem mexer nos `exit` que carregam o código de retorno.
[ "$ferramentas" -gt 0 ] && trap 'meow_info "$ferramentas ferramenta(s) da Steam (Proton, runtimes) fora do lançador, de propósito"' EXIT

if [ "$jogos" -eq 0 ]; then
  meow_pula "a Steam está instalada mas nenhum jogo instalado tem manifesto — nada a criar"
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

[ "$escritos" -gt 0 ] && meow_ok "$escritos jogo(s) da Steam no lançador (ícone natural, como ela pediu)"
[ "$removidos" -gt 0 ] && meow_ok "$removidos atalho(s) de jogo desinstalado removidos"
# A MENSAGEM NÃO PODE MENTIR: degrau órfão não é jogo desinstalado. Os dois
# contadores existem separados porque a primeira versão somava tudo em
# `removidos` e anunciou "7 atalhos de jogo desinstalado" quando o que saíra
# foram sete arquivos `256x256` de jogos que continuam instalados.
[ "${degraus_removidos:-0}" -gt 0 ] && meow_ok "$degraus_removidos ícone(s) em degrau fora da escada removidos (a escada desta tela é: $(meow_icones_escada_dita))"
[ "$duplicatas" -gt 0 ] && meow_ok "$duplicatas jogo(s) deixaram de aparecer duas vezes no lançador"
meow_info "para juntá-los num grupo: lançador → Novo grupo → nome 'Jogos' → categoria Game"
exit "$MEOW_DIVERGENTE"

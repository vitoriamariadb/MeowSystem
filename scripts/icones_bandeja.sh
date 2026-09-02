#!/usr/bin/env bash
# icones_bandeja.sh — o Arcticons vestindo os ícones da BANDEJA da barra
#                     (o `CosmicAppletStatusArea`).
#
# POR QUE ESTE SCRIPT EXISTE
#   A conclusão antiga do projeto era que a bandeja é um beco sem saída — que o
#   applet "desenha bitmap cru" e nenhum tema alcança. Isso vale para o ZapZap e
#   para o qBittorrent, que mandam `IconPixmap`, e está ERRADO COMO REGRA GERAL.
#   Um item da bandeja publica no D-Bus (`org.kde.StatusNotifierItem`) TRÊS
#   coisas que decidem quem desenha:
#
#     IconPixmap      raster embutido na mensagem. Se vier, o tema não entra.
#     IconThemePath   um diretório que o applet põe ANTES do tema. Se vier
#                     preenchido, o arquivo de lá vence o nosso. E ele pode
#                     simplesmente NÃO EXISTIR — ver a remedição de 23/08 abaixo.
#     IconName        o nome. Com `IconPixmap` ausente e `IconThemePath` VAZIO,
#                     quem resolve é o tema de ícones — e aí nós alcançamos.
#
# ─────────────────────────────────────────────────────────────────────────────
# REMEDIDO NO D-BUS AO VIVO EM 23/08/2026 — A AFIRMAÇÃO SOBRE O ZAPZAP RESISTIU
# ─────────────────────────────────────────────────────────────────────────────
#   Ela reclamou que o ícone da bandeja do ZapZap volta ao original a cada
#   `flatpak update`, e a pergunta que veio junto foi se a premissa deste
#   cabeçalho ainda valia — o ZapZap podia ter mudado de comportamento entre
#   versões. Foi posta à prova contra o ZapZap 7.4.2, rodando o código de bandeja
#   REAL do app (`TrayIcon.getIcon()`, importado de dentro do sandbox dele) e
#   lendo as propriedades do item registrado:
#
#     Id             'meow_probe_tray.py'      Category  'ApplicationStatus'
#     IconName       ''                        <- VAZIO
#     IconThemePath  GDBus.Error:…UnknownProperty: a propriedade NEM EXISTE
#     IconPixmap     2 quadros: 22×22 e 64×64, 109.955 bytes de raster
#
#   CONFIRMADA — e a única coisa que este cabeçalho dizia com imprecisão era o
#   `IconThemePath`. Estava escrito "se vier preenchido"; no ZapZap ele não vem
#   vazio, ele NÃO É EXPORTADO. O `QDBusTrayIcon` do Qt só publica essa
#   propriedade quando há um tema de ícones envolvido, e aqui não há: o ícone é
#   construído de um `QPixmap`. Para efeito prático dá no mesmo (o tema não
#   alcança), mas a linha acima passou a dizer as duas possibilidades.
#
#   CONTRAPROVA COLHIDA NA MESMA SESSÃO, no item que estava vivo na barra dela:
#     qBittorrent    IconName=''  IconThemePath=''  IconPixmap=[(22,22,…)]
#   Os dois apps que o `assets/icones/bandeja.map` já listava como beco sem saída
#   continuam sendo exatamente esses dois, pelas razões que ele já dava.
#
#   COMO SE MEDIU SEM ABRIR O WHATSAPP DELA: `flatpak run --command=python3`
#   importando o módulo real e pendurando um `QSystemTrayIcon`. Duas tentativas,
#   e a primeira ensina algo — `QT_QPA_PLATFORM=offscreen` devolve
#   `isSystemTrayAvailable() = False` e NÃO registra; com `xcb` sob Xvfb,
#   registra. A ideia de prendê-lo num barramento privado NÃO FUNCIONA: o
#   `flatpak run` monta um `xdg-dbus-proxy` e reescreve o
#   `DBUS_SESSION_BUS_ADDRESS` dentro do sandbox, então o `--env=` é ignorado e o
#   item aparece na barra dela por alguns segundos. Fica o aviso para quem
#   repetir.
#
#   O QUE SE FAZ COM UM ÍCONE QUE O TEMA NÃO ALCANÇA está em
#   `scripts/icones_tray_zapzap.sh`: troca-se o desenho na FONTE do app, que é
#   uma string de Python dentro do flatpak. E o que repõe isso depois de cada
#   `flatpak update` — o gatilho que faltava — é o par
#   `systemd/meow-flatpak.path` + `systemd/meow-flatpak.service`.
#
# A VIA ESTÁ PROVADA, E ESTA É A PROVA (08/08/2026)
#   Plantado um SVG marcado em `MeowSystem-Icons/22x22/status/` e em
#   `scalable/status/` com o nome que o Hefesto publica, e consultado o
#   resolvedor real (`Gtk.IconTheme.lookup_icon`, com o tema selecionado):
#
#     hefesto-dualsense4unix-symbolic  20px -> .../MeowSystem-Icons/scalable/status/…
#     hefesto-dualsense4unix-symbolic  22px -> .../MeowSystem-Icons/22x22/status/…
#     (removidos os dois, volta para .../hicolor/symbolic/apps/…)
#
#   Antes ele vinha do `hicolor` do USUÁRIO, que é o ÚLTIMO elo da cadeia de
#   herança (docs/COSMIC-THEMING.md §2). O laço externo da busca é o NOME DO
#   TEMA, então um arquivo nosso ganha com folga. Não é inferência: é o antes e
#   o depois, medidos, com a limpeza conferida no fim.
#
# O TAMANHO REAL DA BANDEJA É 20 px, NÃO 22 — E ISSO REDESENHOU O DESTINO
#   Medido na captura de hoje, caixa de tinta de cada item da barra dela:
#     Steam    x 1614..1629   16 × 17 px   (raster próprio, ver abaixo)
#     Hefesto  x 1654..1672   19 × 20 px
#     wifi     x 1837..1855   19 × 18 px
#   Bate com o que o `cosmic-panel` faz: `get_applet_icon_size(symbolic=true)`
#   devolve 20 no tamanho de painel `S`, que é o dela.
#
#   E a 20 px o resolvedor NÃO escolhe `22x22/status`: na prova acima ele foi
#   para `scalable/status`. `Type=Fixed Size=22` não casa com 20; `Type=Scalable`
#   com `MinSize=8 MaxSize=512` casa. Ou seja: um ícone de bandeja copiado com a
#   receita do `icones_sistema.sh` sairia com o traço FINO daquele diretório
#   (`stroke-width` 1, que a 20 px é 0,42 px de tela) e desapareceria.
#
# POR QUE O DESTINO É `20x20/status`, E POR QUE ELE É NOVO
#   Não é simetria: é a única forma de ter DONO ÚNICO. O `icones_sistema.sh`
#   declara-se dono de `22x22/status` E de `scalable/status`, e REMOVE ÓRFÃO nos
#   dois — qualquer arquivo cujo nome não esteja no `assets/icones/sistema.map` ele apaga.
#   Se este script escrevesse lá, os dois ficariam apagando o trabalho um do
#   outro a cada passagem: o laço eterno de dois donos, que este projeto já pagou
#   uma vez (o comentário está no `construir_icones.sh`).
#
#   `20x20/status` nasce aqui, é o tamanho medido da bandeja, e mais ninguém
#   escreve nele — então remover órfão é seguro. Quem DECLARA o diretório no
#   `index.theme` continua sendo o `construir_icones.sh`, que o monta a partir do
#   que existe no disco: o `status_no_disco()` dele varre `*/status` e casa
#   `[0-9]*x[0-9]*`, então `[20x20/status] Size=20 Context=Status Type=Fixed` sai
#   sozinho na passagem seguinte. Um diretório só basta porque o consumidor é um
#   só, num tamanho só — e porque o SVG é escalável: pedido em outro tamanho, o
#   mesmo arquivo serve sem perda.
#
# A DECLARAÇÃO NÃO É BUROCRACIA: SEM ELA O ARQUIVO É INVISÍVEL
#   Medido em 08/08/2026 num tema ISOLADO (cópia do `MeowSystem-Icons` numa pasta
#   temporária, `Gtk.IconTheme.new()` + `set_search_path`), com o MESMO arquivo em
#   `20x20/status` nos dois casos:
#
#     index.theme SEM `[20x20/status]`   ->  has_icon = False   (invisível)
#     index.theme COM `[20x20/status]`   ->  has_icon = True    -> 20x20/status/…
#
#   Ou seja: entre pôr o arquivo e o ícone existir há UMA passagem do
#   `construir_icones.sh`. No `install.sh` isso significa que a etapa deste script
#   tem de vir ANTES da que constrói o índice, ou o ícone só aparece na execução
#   seguinte. É a mesma dependência que o `icones_sistema.sh` tem, e ela nunca foi
#   escrita — este parágrafo é para não se descobrir de novo.
#
# O PONTO CEGO DO GTK, QUE É DO INSTRUMENTO E NÃO DA REGRA
#   O GTK — que aqui é só o aparelho de medir — acha ALGUNS diretórios não
#   declarados e outros não. Medido no mesmo tema isolado, o mesmo arquivo em
#   `<tam>/status`, nenhum deles no `Directories=` (menos o 22x22, que já está):
#
#     16x16 True · 18x18 False · 19x19 False · 20x20 False · 21x21 False
#     22x22 True (declarado) · 23x23 False · 24x24 True · 32x32 True
#     36x36 True · 72x72 True
#
#   Não achei a regra por trás disso, e a hipótese óbvia (só valeriam os tamanhos
#   que o tema já declara em `<tam>/apps`) foi TESTADA E CAIU: `36x36` não aparece
#   em lugar nenhum do índice e foi achado; `20x20` também não aparece e não foi.
#   Fica registrado como fato sem explicação — e sem uso: quem desenha a bandeja é
#   a crate do COSMIC, que lê só as seções declarando `Size=`
#   (`parse.rs::get_all_directories`, ver o cabeçalho do `auditar_icones.sh`).
#   Escolher `24x24/status` para pegar carona na leniência do GTK seria projetar
#   contra o resolvedor errado, e mentir 4 px sobre o tamanho medido da bandeja.
#
# NÃO PINTAMOS NADA, E ISSO FOI REMEDIDO NA BANDEJA
#   §4g mediu o descarte de cor nos applets. Repetido hoje no caminho da
#   bandeja: o symbolic do Hefesto tem `fill="#bebebe"` (4×) em disco e sai
#   `#FFFFFF` (99 px) na tela dela. A cor do arquivo é jogada fora; o único eixo
#   que sobrevive é o DESENHO. Contraprova no mesmo recorte: o raster da Steam
#   sai `#DEDEDE`, a cor exata do arquivo — o toolkit repinta symbolic e não
#   repinta raster.
#
# OS INTOCÁVEIS SÃO A PARTE MAIS IMPORTANTE DESTE ARQUIVO
#   O `hefesto-dualsense4unix-symbolic` que está na barra dela é DESENHO DELA —
#   o aro aberto da logo com o martelo, DECISÃO 14 de 07/08/2026, com teste
#   próprio no repositório do Hefesto. A logo já estava nos INTOCÁVEIS do
#   `icones_apps.sh`; o `-symbolic` é a mesma logo na grade de 16, e ficou de
#   fora daquela lista só porque o sufixo é outro. Aqui ele entra explicitamente,
#   para que uma sessão futura que escreva a linha no mapa não apague o desenho
#   dela sem perceber.
#
# NÃO REINICIAMOS NADA — E AQUI A ESPERA É MAIOR QUE NO PAINEL
#   O item da bandeja nasce quando O APLICATIVO abre: ele se registra no
#   `StatusNotifierWatcher` no start e publica o `IconName` ali. Então um ícone
#   novo só aparece quando o APP reabrir, não no próximo login do COSMIC.
#   Derrubar o `cosmic-panel` para encurtar a espera já deixou ela sem painel e
#   sem dock duas vezes, numa máquina de uma tela só.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta o pack
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="${MEOW_BANDEJA_ORIGEM:-$RAIZ/assets/icones/arcticons}"
MAPA="${MEOW_BANDEJA_MAPA:-$RAIZ/assets/icones/bandeja.map}"
TEMA="${ICONES_TEMA:-${NOME_TEMA_ICONES:-MeowSystem-Icons}}"
BASE="$HOME/.local/share/icons/$TEMA"

# O diretório de destino e a espessura do traço dele. Array de uma entrada por
# ora, e array de propósito: acrescentar um segundo tamanho (se um dia ela puser
# o painel em `M` ou `L`, onde o simbólico deixa de ser 20 px) é uma linha.
#
# O 4 É O NÚMERO DELA, E A CONTA DELE ESTÁ AQUI PARA NÃO SE PERDER
#   Ela escolheu 4 olhando a folha da Sprint A, a 22 px, contra os ícones cheios
#   do Papirus que dividem a mesma barra ("2 ainda ficava fino demais"). O
#   `stroke-width` é em unidades do `viewBox`, que no Arcticons é 48 — então 4 é
#   8,33% da caixa, em qualquer tamanho de tela. A 22 px isso dava 1,83 px; aqui,
#   a 20 px, dá 1,67 px. É o MESMO peso relativo que ela aprovou, 9% mais fino em
#   pixel porque o ícone é 9% menor.
#   Se ela quiser o 1,83 px exato de novo, é 4,4. Se quiser igualar o peso dos
#   applets do COSMIC medido no repositório do Hefesto (2,0 unidades de uma grade
#   de 16 = 12,5% da caixa = 2,5 px a 20 px), é 6,0. Um número, nesta linha.
declare -A TRACO=( ["20x20/status"]=4 )

# Desenho DELA, autoral: não se toca, venha o que vier no mapa. Mesma disciplina
# das listas do `icones_apps.sh` e do `icones_apps_arcticons.sh` — a guarda mora
# no script, e não na memória de quem escreveu o mapa.
#
#   hefesto-dualsense4unix-symbolic         o aro aberto da logo com o martelo,
#                                           DECISÃO 14 dela de 07/08/2026
#   com.vitoriamaria.HefestoDualsense4Unix-symbolic
#                                           o mesmo arquivo, com o id de flatpak
#                                           (é o nome que o pacote .deb instala)
INTOCAVEIS=(
  hefesto-dualsense4unix-symbolic
  com.vitoriamaria.HefestoDualsense4Unix-symbolic
)

intocavel() {
  local n="$1" i
  for i in "${INTOCAVEIS[@]}"; do [ "$n" = "$i" ] && return 0; done
  return 1
}

declare -A MAPA_LIDO=()   # IconName do app -> glifo Arcticons
declare -A ALIAS_OK=()    # glifo -> 1, quando a repetição é deliberada

# --- o mapa, lido uma vez ----------------------------------------------------
# Três campos, separados por ':'. Nenhum nome de ícone tem ':', então é seguro.
# O terceiro campo, quando é `alias`, autoriza a repetição de glifo.
_ler_mapa() {
  local linha nome glifo marca
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    IFS=':' read -r nome glifo marca <<<"$linha"
    [ -n "$nome" ] && [ -n "$glifo" ] || continue
    if intocavel "$nome"; then
      meow_aviso "'$nome' está nos INTOCÁVEIS: é desenho dela — a linha do mapa foi ignorada"
      continue
    fi
    MAPA_LIDO["$nome"]="$glifo"
    if [ "${marca:-}" = "alias" ]; then ALIAS_OK["$glifo"]=1; fi
  done < "$MAPA"
  # `return 0` NÃO É DECORAÇÃO: um `while` devolve o status do último comando do
  # corpo, e a última linha do mapa não é um alias — o teste devolveria 1 e, com
  # `set -e`, o script morreria aqui, calado e com código 1. Foi exatamente o que
  # aconteceu na primeira execução do `icones_sistema.sh`.
  return 0
}

# --- a asserção que ESTOURA em vez de deixar passar --------------------------
# Dois itens da bandeja com o mesmo desenho é pior aqui que no lançador: eles
# ficam LADO A LADO, sempre, na mesma barra de 20 px de altura. Sem `:alias`, o
# script para (código 2) em vez de deixar dois nascerem gêmeos em silêncio.
_conferir_gemeos() {
  local nome glifo erro=0
  declare -A visto=()
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    if [ -n "${visto[$glifo]:-}" ] && [ -z "${ALIAS_OK[$glifo]:-}" ]; then
      meow_erro "dois ícones da bandeja receberiam o mesmo desenho '$glifo': '$nome' e '${visto[$glifo]}'"
      meow_erro "  decida: troque um dos dois, ou marque a repetição com ':alias' no mapa"
      erro=1
    fi
    visto["$glifo"]="$nome"
  done
  [ "$erro" = 0 ] || return "$MEOW_ERRO"
  return "$MEOW_OK"
}

# --- dependências ------------------------------------------------------------
_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "o acervo Arcticons não está em assets/icones/arcticons — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem assets/icones/bandeja.map — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- a transformação ---------------------------------------------------------
# Insere `stroke-width` em cada elemento de desenho. UM atributo por elemento:
# duplicar invalida o XML e o rasterizador recusa o SVG inteiro, calado.
# O `if` não é defensivo à toa: os 37 SVG do acervo de 05/08 NÃO declaram
# `stroke-width`, mas a API do Iconify entrega alguns COM ele — conferido em
# 08/08 nos candidatos baixados. Quem chegar depois pode não ser como os de hoje.
_com_traco() {
  local arq="$1" largura="$2"
  if grep -q 'stroke-width' "$arq"; then
    sed -E 's/stroke-width="[^"]*"/stroke-width="'"$largura"'"/g' "$arq"
  else
    sed -E 's/<(circle|rect|line|polyline|polygon|path|ellipse) /<\1 stroke-width="'"$largura"'" /g' "$arq"
  fi
}

# --- o que deveria estar no disco --------------------------------------------
# "dir<TAB>nome<TAB>glifo", só dos glifos que existem de fato. Um glifo faltando
# é aviso, não erro: aquele ícone continua vindo de onde vinha.
_desejado() {
  local nome glifo dir
  for dir in "${!TRACO[@]}"; do
    for nome in "${!MAPA_LIDO[@]}"; do
      glifo="${MAPA_LIDO[$nome]}"
      [ -f "$ORIGEM/$glifo.svg" ] && printf '%s\t%s\t%s\n' "$dir" "$nome" "$glifo"
    done
  done
}

_avisar_faltantes() {
  local nome glifo
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    [ -f "$ORIGEM/$glifo.svg" ] && continue
    meow_aviso "o glifo '$glifo' não está em assets/icones/arcticons — '$nome' fica como está"
    meow_info "  baixe com: curl -s https://api.iconify.design/arcticons/$glifo.svg -o assets/icones/arcticons/$glifo.svg"
  done
  return 0
}

# "NADA A FAZER" TEM TRÊS CAUSAS, E DIZER A ERRADA MANDA PROCURAR NO LUGAR ERRADO
#   mapa sem linha        a decisão está no `assets/icones/bandeja.map`
#   linha sem glifo       o `_avisar_faltantes` já disse qual baixar
#   tudo no lugar         é o caso feliz
_frase_nada_a_fazer() {
  local total="$1"
  if [ "${#MAPA_LIDO[@]}" = 0 ]; then
    printf 'a bandeja não tem alvo hoje (0 linha ativa no mapa) — ver assets/icones/bandeja.map'
  elif [ "$total" = 0 ]; then
    printf '%s linha(s) no mapa e nenhum glifo em assets/icones/arcticons — nada a vestir' "${#MAPA_LIDO[@]}"
  else
    printf '%s ícone(s) da bandeja já vestidos de Arcticons' "$total"
  fi
}

# O CRITÉRIO DO CONFERIR TEM DE SER O DO ESCRITOR
#   `meow_escrever` grava com `printf '%s'`, que come o `\n` final. Um `cmp` byte
#   a byte acusaria divergência eterna num arquivo perfeito — já custou um
#   `--conferir` gritando 123 divergências num tema correto. Compara-se com
#   `$(...)` porque é assim que se escreve.
_conferir() {
  local dir nome glifo divergentes=0 ausentes=0 orfaos=0 total=0 arq alvo
  while IFS=$'\t' read -r dir nome glifo; do
    total=$((total + 1))
    alvo="$BASE/$dir/$nome.svg"
    if [ ! -f "$alvo" ]; then
      ausentes=$((ausentes + 1))
    elif [ "$(_com_traco "$ORIGEM/$glifo.svg" "${TRACO[$dir]}")" != "$(cat "$alvo")" ]; then
      divergentes=$((divergentes + 1))
    fi
  done < <(_desejado)

  for dir in "${!TRACO[@]}"; do
    [ -d "$BASE/$dir" ] || continue
    for arq in "$BASE/$dir"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      [ -n "${MAPA_LIDO[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  done

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$(_frase_nada_a_fazer "$total")"
    return "$MEOW_OK"
  fi
  meow_muda "ícones da bandeja: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local dir nome glifo arq mudou=0 postos=0 removidos=0 total=0 rc

  while IFS=$'\t' read -r dir nome glifo; do
    total=$((total + 1))
    set +e
    meow_escrever "$BASE/$dir/$nome.svg" "$(_com_traco "$ORIGEM/$glifo.svg" "${TRACO[$dir]}")" 644
    rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; postos=$((postos + 1)) ;;
      *) meow_erro "não consegui escrever $BASE/$dir/$nome.svg"; return "$MEOW_ERRO" ;;
    esac
  done < <(_desejado)

  # Órfão: estava no mapa ontem, não está hoje. Removível porque o dono é único —
  # `20x20/status` nasce aqui e nenhum outro script do projeto escreve nele (o
  # `icones_sistema.sh` é dono de `22x22/status` e `scalable/status`).
  for dir in "${!TRACO[@]}"; do
    [ -d "$BASE/$dir" ] || continue
    for arq in "$BASE/$dir"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      if [ -z "${MAPA_LIDO[$nome]:-}" ]; then
        if meow_seco; then
          meow_muda "removeria $arq (saiu do mapa)"
        else
          meow_destino_permitido "$arq" || return "$MEOW_ERRO"
          rm -f "$arq"
        fi
        mudou=1; removidos=$((removidos + 1))
      fi
    done
  done

  if [ "$mudou" = 0 ]; then
    meow_ok "$(_frase_nada_a_fazer "$total")"
    return "$MEOW_OK"
  fi
  meow_info "ícones da bandeja: $postos posto(s), $removidos removido(s)"
  # A espera aqui é OUTRA, e dizer "próximo login" seria mentira: o item da
  # bandeja nasce no start do aplicativo, não no start do COSMIC.
  meow_info "o ícone novo aparece quando O APLICATIVO reabrir (o item nasce no start dele)"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_mapa
  _conferir_gemeos || return $?
  _avisar_faltantes
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

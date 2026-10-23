#!/usr/bin/env bash
# icones_apps_arcticons.sh — os aplicativos do LANÇADOR vestidos em TRAÇO de
# linha, recolorido na paleta. DOIS acervos entram aqui, e um instalador só sai.
#
#   `packs/meowsystem/icones/apps/arcticons/`    glifos do pack Arcticons, desenhados à mão por
#                              terceiros. Mapa: `packs/meowsystem/icones/apps-arcticons.map`.
#   `packs/meowsystem/icones/apps/convertidos/`  a arte do PRÓPRIO aplicativo, convertida de
#                              chapado para traço por nós. Mapa:
#                              `packs/meowsystem/icones/apps-convertidos.map`. Quem gera é o
#                              `scripts/construir_convertidos.sh`; aqui ela
#                              chega pronta e commitada.
# Dono único de `48x48/apps`: em `scalable/apps` escrevem três, e remover órfão lá
# apagaria arquivo dos outros. O Arcticons é apoio, não o tema (decisão dela), e
# `stroke-width` duplicado é XML que o rasterizador recusa calado.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="$RAIZ/packs/meowsystem/icones/apps/arcticons"
MAPA="$RAIZ/packs/meowsystem/icones/apps-arcticons.map"
# O «Usar este ícone» com um glifo de traço gravava a linha no mapa acima,
# dentro do clone, e copiava o glifo para `arcticons-apps/`: usar o programa
# sujava o repositório.
MAPA_USUARIO="${MEOW_ICONES_TRACO:-$(dirname "$MEOW_CONF_ARQUIVO")/icones-traco.map}"
ORIGEM_CONV="$RAIZ/packs/meowsystem/icones/apps/convertidos"
MAPA_CONV="$RAIZ/packs/meowsystem/icones/apps-convertidos.map"
# O «Usar» da oficina do painel grava a linha no `icones-convertidos.map` ao
# lado do meow.conf (o formato deste mapa) e o construído na casa.
MAPA_CONV_USUARIO="${MEOW_ICONES_CONVERTIDOS:-$(dirname "$MEOW_CONF_ARQUIVO")/icones-convertidos.map}"
ORIGEM_CONV_USUARIO="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/convertidos-apps"
MAPA_MARCA="$RAIZ/packs/meowsystem/icones/apps-marca.map"
MAPA_PNG="$RAIZ/packs/meowsystem/icones/apps.map"
# A paleta vem da porta única (lib/comum.sh). Era
# `assets/paleta/catppuccin.json` cravado — e um nome cravado aqui faz este
# script continuar lendo o Catppuccin enquanto o resto do projeto já mudou de
# paleta, sem dar erro.
PALETA="$(meow_paleta)"
TEMA="${ICONES_TEMA:-${NOME_TEMA_ICONES:-MeowSystem-Icons}}"
BASE="$HOME/.local/share/icons/$TEMA"

# O FLAVOR AQUI É O DE VERDADE, E ESSA É A VANTAGEM DO SVG
FLAVOR="$(meow_flavor_vestido)" || {
  meow_erro "aplicativos em traço: sem o flavor não há cor para o traço — nada foi tocado"
  exit "$MEOW_ERRO"
}

# A consequência é aritmética: 1,75 num viewBox de 48 desenhado a 41 px vale
# 1,50 px de tela.
#
# 2,25 é escolha dela na folha, com o mesmo ícone em 1,75 / 2,0 / 2,25 / 2,5
# rasterizado a 41 px.
#
# O número exportado foi 1,25, e ele está aqui porque foi decidido, não porque
# foi medido melhor.
declare -A TRACO=( ["48x48/apps"]=1.25 )

# Pedido expresso dela: estes ficam como estão, venha o que vier. Mesma lista do
# `icones_apps.sh` — se um nome intocável entrar no mapa, ele é ignorado aqui
# também, em vez de depender de quem escreveu o mapa ter lembrado.
INTOCAVEIS_PREFIXO=(steam_icon_)
INTOCAVEIS=(fogstripper hefesto-dualsense4unix com.vitoriamaria.HefestoDualsense4Unix)

intocavel() {
  local n="$1" i
  for i in "${INTOCAVEIS[@]}"; do [ "$n" = "$i" ] && return 0; done
  for i in "${INTOCAVEIS_PREFIXO[@]}"; do case "$n" in "$i"*) return 0 ;; esac; done
  return 1
}

# Um nome que está lá não pode continuar sendo vestido aqui: a arte dela vai
# para `scalable/apps`, a minha fica em `48x48/apps`, e a de 48 vence a 48 px —
# a escolha dela ficaria no disco sem nunca aparecer na tela, que é o pior
# desfecho possível, porque parece que funcionou.
#
# O arquivo só existe depois da primeira importação; ausência não é defeito.
declare -A CURADO=()
_ler_curadoria() {
  local chave ext subdir
  [ -f "$RAIZ/assets/icones/curadoria.map" ] || return 0
  while IFS=$'\t' read -r chave ext subdir; do
    case "$chave" in ''|'#'*) continue ;; esac
    [ -n "$ext" ] && [ -n "$subdir" ] || continue
    CURADO["$chave"]=1
  done < "$RAIZ/assets/icones/curadoria.map"
  return 0
}

declare -A GLIFO=()      # nome do .desktop -> glifo Arcticons (só esse acervo)
declare -A ARTE=()       # nome do .desktop -> caminho do SVG a vestir (os DOIS)
declare -A ACERVO=()     # nome do .desktop -> "Arcticons" | "convertido"
declare -A DUPLO=()      # nome que apareceu nos DOIS mapas de traço
declare -A COR=()        # nome do .desktop -> chave da paleta
declare -A ALIAS_OK=()   # glifo ou cor -> 1, quando a repetição é deliberada
declare -A HEX=()        # chave da paleta -> hex do flavor em uso

# Ela existia para um mapa de TRÊS linhas, onde duas cores iguais só podiam ser
# descuido.
#
# Desligar isso linha a linha com `:alias` seria mentir duas vezes.
#
#     #!cor-por-categoria
COR_POR_CATEGORIA=0

# --- o mapa, lido uma vez ----------------------------------------------------
# Quatro campos, separados por ':'. Nenhum nome de ícone, glifo ou cor tem ':'.
_ler_mapa() {
  local linha nome glifo cor marca
  while IFS= read -r linha; do
    case "$linha" in
      '#!cor-por-categoria') COR_POR_CATEGORIA=1; continue ;;
      ''|'#'*) continue ;;
    esac
    IFS=':' read -r nome glifo cor marca <<<"$linha"
    [ -n "$nome" ] && [ -n "$glifo" ] && [ -n "$cor" ] || continue
    # O caminho (só o do mapa de quem usa) fica dentro da raiz: `..` não sobe.
    case "$glifo" in */*) case "/$glifo/" in */../*) continue ;; esac ;; esac
    intocavel "$nome" && continue
    if [ -n "${CURADO[$nome]:-}" ]; then
      meow_debug "$nome: arte escolhida na curadoria — o Arcticons sai de cima"
      continue
    fi
    GLIFO["$nome"]="$glifo"
    ARTE["$nome"]="$ORIGEM/$glifo.svg"
    # O caminho gravado antes das três pastas (P88) é lido no endereço de hoje.
    case "$glifo" in
      */*) [ -e "$RAIZ/$glifo" ] || glifo="$(python3 "$RAIZ/scripts/pack.py" hoje "$glifo" 2>/dev/null || printf '%s' "$glifo")"
           ARTE["$nome"]="$RAIZ/$glifo" ;;
    esac
    ACERVO["$nome"]="Arcticons"
    COR["$nome"]="$cor"
    if [ "${marca:-}" = "alias" ]; then ALIAS_OK["$glifo"]=1; ALIAS_OK["cor:$cor"]=1; fi
  # O `echo` entre os dois é a quebra que um arquivo sem `\n` no fim não tem:
  # sem ela, a última linha de um colaria na primeira do outro.
  done < <(cat "$MAPA"; echo; [ -f "$MAPA_USUARIO" ] && cat "$MAPA_USUARIO"; echo)
  # `return 0` NÃO É DECORAÇÃO: um `while` devolve o status do último comando do
  # corpo, e a última linha do mapa não é um alias — o teste devolveria 1 e, com
  # `set -e`, o script morreria aqui, calado e com código 1. Aconteceu no irmão.
  return 0
}

# --- o SEGUNDO mapa: o acervo convertido -------------------------------------
# `nome : origem-chapada : cor [ : parametros ]`. Daqui saem só os campos 1 e 3:
# a origem e os parâmetros são do `construir_convertidos.sh`, que é quem GERA a
# arte. Aqui ela já chega pronta, com o nome do próprio aplicativo — não há
# indireção por glifo, e é por isso que não existe campo `glifo` naquele mapa.
#
# AUSÊNCIA DO MAPA NÃO É DEFEITO: quem só tem o Arcticons continua funcionando
# igual, e é o mesmo critério do `assets/icones/curadoria.map`.
_ler_mapa_convertidos() {
  local linha nome origem cor
  [ -f "$MAPA_CONV" ] || return 0
  while IFS= read -r linha; do
    case "$linha" in
      '#!cor-por-categoria') COR_POR_CATEGORIA=1; continue ;;
      ''|'#'*) continue ;;
    esac
    IFS=':' read -r nome origem cor _ <<<"$linha"
    [ -n "$nome" ] && [ -n "$origem" ] && [ -n "$cor" ] || continue
    # O DESENHO À MÃO VENCE A LISTA DE INTOCÁVEIS — 08/09/2026
    #   A lista existe por pedido dela ("estes ficam como estão, venha o que
    #   vier"), e o `steam_icon_` está lá para que NENHUMA regra nossa varra os
    #   ícones dos jogos dela de uma vez. Isso continua valendo.
    #
    #   Uma linha `mao` é outra coisa: ela só existe porque ela desenhou aquele
    #   ícone na oficina do painel, olhou o resultado a 48 px e clicou em "Usar
    #   este desenho". É decisão escrita, uma por vez, e decisão escrita vence
    #   heurística — a mesma regra que já governa o `lado.tsv` dos papéis de
    #   parede e o `jogos-fora.map`.
    #
    #   Pedido dela em 08/09/2026: *"podemos usar ela via interface pra criarmos
    #   variações das capas de qualquer app, incluindo os da steam?"* Sem esta
    #   linha a resposta seria "não" — o desenho seria gravado no repositório e
    #   descartado calado na hora de instalar.
    if [ "$origem" != "mao" ] && intocavel "$nome"; then continue; fi
    if [ -n "${CURADO[$nome]:-}" ]; then
      meow_debug "$nome: arte escolhida na curadoria — o convertido sai de cima"
      continue
    fi
    # Nome nos DOIS mapas de traço: não sobrescreve nem escolhe um vencedor em
    # silêncio — anota e deixa o `_conferir_gemeos` ESTOURAR com o nome na tela.
    if [ -n "${ACERVO[$nome]:-}" ]; then
      DUPLO["$nome"]=1
      continue
    fi
    ARTE["$nome"]="$ORIGEM_CONV/$nome.svg"
    ACERVO["$nome"]="convertido"
    COR["$nome"]="$cor"
  done < "$MAPA_CONV"
  # [P82: o de quem usa por último, e ele troca o que houver antes.]
  [ -f "$MAPA_CONV_USUARIO" ] || return 0
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    IFS=':' read -r nome origem cor _ <<<"$linha"
    [ -n "$nome" ] && [ -n "$origem" ] && [ -n "$cor" ] || continue
    if [ "$origem" != "mao" ] && intocavel "$nome"; then continue; fi
    if [ -n "${CURADO[$nome]:-}" ]; then continue; fi
    unset 'GLIFO[$nome]' 'DUPLO[$nome]'
    ARTE["$nome"]="$ORIGEM_CONV_USUARIO/$nome.svg"
    ACERVO["$nome"]="convertido"
    COR["$nome"]="$cor"
  done < "$MAPA_CONV_USUARIO"
  return 0
}

# --- o desenho do pack vence o traço em todo tamanho ---------------------------
# P88, decisão 16 (7). Medido em 15/10: 17 desenhos do pack Dracula (Discord,
#   Spotify, Obsidian, Telegram, Steam…) ficavam encobertos a 48 px pelo traço
#   deste diretório, porque um tema acha o `48x48/apps` antes do `scalable`
#   naquele tamanho. O nome que o `pack.py fontes` põe em `scalable/apps` (o
#   desenho do pack, o resgate, a escolha do painel) sai daqui, e o `.svg` de
#   48 px dele vira órfão e é varrido. Fica o traço que quem usa escolheu: a
#   linha dele no `icones-traco.map` ou no `icones-convertidos.map`.
declare -A CEDIDO=()     # nome que o desenho do pack veste — o traço cede
_ceder_ao_pack() {
  local nome m
  declare -A do_usuario=()
  for m in "$MAPA_USUARIO" "$MAPA_CONV_USUARIO"; do
    [ -f "$m" ] || continue
    while IFS=':' read -r nome _; do
      case "$nome" in ''|'#'*) continue ;; esac
      do_usuario["$nome"]=1
    done < "$m"
  done
  while IFS=$'\t' read -r nome fonte camada; do
    [ -n "$nome" ] && [ -n "${ARTE[$nome]:-}" ] && [ -z "${do_usuario[$nome]:-}" ] || continue
    # Só cede a quem de fato veste: o desenho existe, e a camada dele está
    # ligada (`ICONES_DRACULA`, `ICONES_RESGATADOS`). Senão o nome ficaria
    # sem o desenho e sem o traço.
    case "$fonte" in /*) ;; *) fonte="$RAIZ/$fonte" ;; esac
    [ -f "$fonte" ] || continue
    case "$camada" in
      pack:*)     [ "${ICONES_DRACULA:-sim}" != "nao" ] || continue ;;
      resgatados) [ "${ICONES_RESGATADOS:-sim}" = "sim" ] || continue ;;
    esac
    meow_debug "$nome: o desenho do pack vence o traço, também a 48 px"
    unset 'ARTE[$nome]' 'GLIFO[$nome]' 'ACERVO[$nome]' 'COR[$nome]' 'DUPLO[$nome]'
    CEDIDO["$nome"]=1
  done < <(MEOW_PACK_DIR="$(meow_pack_dir)" python3 "$RAIZ/scripts/pack.py" fontes 2>/dev/null || true)
  return 0
}

# --- o TERCEIRO mapa: a cor puxada da MARCA, e ele nasce DESLIGADO ------------
#
# `ICONES_COR_MARCA="sim"` no `meow.conf` liga; qualquer outra coisa (inclusive
# a ausência da chave) deixa desligado, e desligado é o padrão do projeto.
#
# POR QUE ISTO É UMA CHAVE E NÃO UM COMMIT
#   Em 23/08/2026 ela disse: *"a cor de alguns svgs tão diferentes das logos
#   originais. tipo a do wpp ou steam, chrome"*. O pedido é legítimo e é só de
#   COR — o traço continua traço, a paleta continua sendo a nossa.
#
#   Só que ele DERRUBA uma escolha que foi dela: em 10/08/2026, entre "uma cor
#   só", "por categoria" e "uma a uma", ela escolheu POR CATEGORIA. Cor por
#   marca é a terceira opção com outro nome, e as duas não podem valer juntas —
#   com marca, a categoria "rede" perde as quatro cores dela de uma vez.
#
#   `docs/SPRINTS.md` diz que a folha visual vem antes do código e que escolha
#   estética não chega na tela dela sem ela ter visto. Então o código existe,
#   está testado, e espera — é ela quem vira a chave.
#
# É UM OVERRIDE DE UM CAMPO SÓ
#   Ele não traz arte nem nome novo: só troca `COR[nome]` de quem já veio de um
#   dos dois acervos. Nome que não esteja num deles é AVISO e é ignorado — não
#   existe "vestir pelo mapa de marca", e por isso este mapa não pode criar o
#   defeito de dois donos que o `_conferir_gemeos` persegue.
#
# DESLIGAR DESLIGA DE VERDADE, e é de graça por construção: este script é dono
# único de `48x48/apps` e o `_aplicar` reescreve todo arquivo cujo CONTEÚDO
# divergir do desejado. Com a chave em "nao" o desejado volta a ser a cor de
# categoria, os arquivos divergem, e a passagem seguinte os reescreve. Não há
# estado a limpar — nada foi guardado em lugar nenhum.
COR_MARCA_LIGADA=0
_ler_mapa_marca() {
  # O terceiro campo é a JUSTIFICATIVA, e ela é para quem lê o mapa, não para o
  # script — daí o `_`, como no `_ler_mapa_convertidos`.
  local linha nome cor
  [ "${ICONES_COR_MARCA:-nao}" = "sim" ] || return 0
  if [ ! -f "$MAPA_MARCA" ]; then
    meow_aviso "ICONES_COR_MARCA=sim mas packs/meowsystem/icones/apps-marca.map não existe — a cor segue por categoria"
    return 0
  fi
  COR_MARCA_LIGADA=1
  while IFS= read -r linha; do
    case "$linha" in
      '#!cor-por-categoria') COR_POR_CATEGORIA=1; continue ;;
      ''|'#'*) continue ;;
    esac
    IFS=':' read -r nome cor _ <<<"$linha"
    [ -n "$nome" ] && [ -n "$cor" ] || continue
    intocavel "$nome" && continue
    # Sem arte é sem efeito: este mapa só REPINTA o que já vem de um acervo.
    [ -n "${CEDIDO[$nome]:-}" ] && continue
    if [ -z "${COR[$nome]:-}" ]; then
      meow_aviso "apps-marca.map: '$nome' não está em nenhum acervo de traço — linha ignorada"
      continue
    fi
    COR["$nome"]="$cor"
  done < "$MAPA_MARCA"
  return 0
}

# --- a paleta é a fonte única de cor -----------------------------------------
# Nenhum hex vive dentro de script neste projeto. O mapa grava a CHAVE
# (`sapphire`), e o hex do flavor em uso sai daqui.
_ler_paleta() {
  local nome saida
  for nome in "${COR[@]}"; do
    [ -n "${HEX[$nome]:-}" ] && continue
    saida="$(python3 -I - "$PALETA" "$FLAVOR" "$nome" <<'PY'
import json, sys
paleta, flavor, chave = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(paleta))["flavors"]
if flavor not in d:
    sys.exit(1)
print(d[flavor].get(chave, ""))
PY
)" || { meow_erro "não consegui ler a paleta para o flavor '$FLAVOR'"; return "$MEOW_ERRO"; }
    if [ -z "$saida" ]; then
      meow_erro "a cor '$nome' não existe em $(meow_paleta_nome) (flavor $FLAVOR)"
      return "$MEOW_ERRO"
    fi
    HEX["$nome"]="$saida"
  done
  return "$MEOW_OK"
}

# --- as asserções que ESTOURAM em vez de deixar passar ------------------------
# São TRÊS, e cada uma cobre um modo de falha já medido neste projeto:
#
#   glifo repetido — dois aplicativos com o mesmo desenho. É o caso que o
#     `icones_sistema.sh` já cobre.
#
#   cor repetida — o SPRINTS.md pede esta explicitamente, e ela não é hipótese:
#     rodando o método de cor nos 13 órfãos de 08/08/2026 saíram TRÊS grupos em
#     colisão (peach: Flatseal/Apostrophe/BoxySVG · green: ProtonUp-Qt/
#     Calculadora/File Roller · sapphire: ONLYOFFICE/Syncthing). Dois ícones
#     vizinhos na mesma cor não é erro de sintaxe — é uma decisão, e decisão
#     tomada em silêncio é a que este projeto persegue.
#
#   nome nos DOIS mapas — o mesmo aplicativo listado aqui e em `packs/meowsystem/icones/apps.map`.
#     Não daria erro nenhum na tela: o SVG simplesmente venceria o PNG, porque
#     dentro de um tema a EXTENSÃO é o laço externo da busca (§2 do
#     docs/COSMIC-THEMING.md) — todos os `.svg`, em todos os tamanhos, antes de
#     qualquer `.png`. Duas listas da mesma verdade, e a que ganha é a que
#     ninguém escolheu.
#
#   nome nos DOIS mapas de TRAÇO — desde 11/08/2026 há dois acervos, e o mesmo
#     aplicativo listado nos dois é a mesma doença de novo: `_desejado` veria as
#     duas artes disputando `48x48/apps/<nome>.svg`, e quem ganharia seria a
#     ordem de leitura, que ninguém escolheu.
_conferir_gemeos() {
  local nome chave erro=0 linha outro
  declare -A visto_glifo=() visto_cor=()

  for nome in "${!DUPLO[@]}"; do
    meow_erro "'$nome' está nos DOIS mapas de traço (apps-arcticons.map e apps-convertidos.map)"
    meow_erro "  a arte que venceria seria a ordem de leitura, não uma escolha — tire de um dos dois"
    erro=1
  done

  # O laço é sobre `COR`, que tem os nomes dos DOIS acervos. A asserção de GLIFO
  # só se aplica a quem TEM glifo (o convertido não tem: a arte se chama pelo
  # nome do aplicativo, 1 para 1); a de COR vale para os dois.
  for nome in "${!COR[@]}"; do
    if [ -n "${GLIFO[$nome]:-}" ]; then
      chave="${GLIFO[$nome]}"
      if [ -n "${visto_glifo[$chave]:-}" ] && [ -z "${ALIAS_OK[$chave]:-}" ]; then
        meow_erro "dois aplicativos receberiam o mesmo desenho '$chave': '$nome' e '${visto_glifo[$chave]}'"
        meow_erro "  decida: troque um dos dois, ou marque a repetição com ':alias' no fim da linha"
        erro=1
      fi
      visto_glifo["$chave"]="$nome"
    fi

    chave="${COR[$nome]}"
    if [ "$COR_POR_CATEGORIA" = 1 ]; then
      :   # a política do mapa diz que repetir cor é o desenho; ver o comentário
          # em COR_POR_CATEGORIA. A asserção de GLIFO, acima, continua de pé.
    elif [ -n "${visto_cor[$chave]:-}" ] && [ -z "${ALIAS_OK[cor:$chave]:-}" ]; then
      meow_erro "dois aplicativos receberiam a mesma cor '$chave': '$nome' e '${visto_cor[$chave]}'"
      meow_erro "  decida: troque um dos dois, ou marque a repetição com ':alias' no fim da linha"
      erro=1
    fi
    visto_cor["$chave"]="$nome"
  done

  if [ -f "$MAPA_PNG" ]; then
    while IFS= read -r linha; do
      case "$linha" in ''|'#'*) continue ;; esac
      outro="${linha%%:*}"
      if [ -n "${COR[$outro]:-}" ]; then
        meow_erro "'$outro' está nos DOIS mapas (apps.map e o mapa de traço do acervo ${ACERVO[$outro]})"
        meow_erro "  o .svg venceria o .png sem ninguém ter decidido — tire de um dos dois"
        erro=1
      fi
    done < "$MAPA_PNG"
  fi

  [ "$erro" = 0 ] || return "$MEOW_ERRO"
  return "$MEOW_OK"
}

# --- dependências ------------------------------------------------------------
_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "o acervo Arcticons de aplicativo não está em packs/meowsystem/icones/apps/arcticons"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem packs/meowsystem/icones/apps-arcticons.map — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$PALETA" ]; then
    meow_pula "sem $(meow_paleta_nome) — sem fonte de cor, nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_tem python3; then
    meow_pula "sem python3 — é ele que lê a paleta (nenhum hex mora em script)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- a transformação ---------------------------------------------------------
# Duas coisas, e as duas num `sed` só por elemento:
#   1. `stroke-width`, UM por elemento (duplicar invalida o XML e o rasterizador
#      recusa o arquivo inteiro, calado);
#   2. `currentColor` -> o hex da paleta. O pack entrega `stroke="currentColor"`
#      e `fill="none"`; trocar o literal acerta stroke e fill sem tocar no
#      `fill="none"`, que precisa continuar sendo "none".
_vestido() {
  local arq="$1" largura="$2" hex="$3"
  if grep -q 'stroke-width' "$arq"; then
    sed -E 's/stroke-width="[^"]*"/stroke-width="'"$largura"'"/g' "$arq" \
      | sed "s/currentColor/$hex/g"
  else
    sed -E 's/<(circle|rect|line|polyline|polygon|path|ellipse) /<\1 stroke-width="'"$largura"'" /g' "$arq" \
      | sed "s/currentColor/$hex/g"
  fi
}

# --- o que deveria estar no disco --------------------------------------------
# "dir<TAB>nome<TAB>caminho-da-arte", só das artes que existem de fato. Arte
# faltando é aviso, não erro: aquele aplicativo continua vindo do Papirus, como
# sempre. O terceiro campo é o CAMINHO, e não o glifo, justamente porque os dois
# acervos moram em diretórios diferentes e o resto do script não precisa saber
# de qual deles cada arte veio — ela sai no mesmo dialeto.
_desejado() {
  local nome dir
  for dir in "${!TRACO[@]}"; do
    for nome in "${!ARTE[@]}"; do
      [ -f "${ARTE[$nome]}" ] && printf '%s\t%s\t%s\n' "$dir" "$nome" "${ARTE[$nome]}"
    done
  done
}

_avisar_faltantes() {
  local nome glifo
  for nome in "${!ARTE[@]}"; do
    [ -f "${ARTE[$nome]}" ] && continue
    if [ "${ACERVO[$nome]}" = "convertido" ]; then
      meow_aviso "'$nome' está no apps-convertidos.map mas a arte não está no acervo"
      meow_info "  gere o acervo com: ./scripts/construir_convertidos.sh"
      continue
    fi
    glifo="${GLIFO[$nome]}"
    meow_aviso "o glifo '$glifo' não está em packs/meowsystem/icones/apps/arcticons — '$nome' fica no Papirus"
    meow_info "  baixe com: curl -s https://api.iconify.design/arcticons/$glifo.svg -o packs/meowsystem/icones/apps/arcticons/$glifo.svg"
  done
  return 0
}

# O CRITÉRIO DO CONFERIR TEM DE SER O DO ESCRITOR
#   `meow_escrever` grava com `printf '%s'`, que come o `\n` final. Um `cmp` byte
#   a byte acusaria divergência eterna num arquivo perfeito — já custou um
#   `--conferir` gritando 123 divergências num tema correto. Compara-se com
#   `$(...)` porque é assim que se escreve.
_conferir() {
  local dir nome arte divergentes=0 ausentes=0 orfaos=0 total=0 arq alvo
  while IFS=$'\t' read -r dir nome arte; do
    total=$((total + 1))
    alvo="$BASE/$dir/$nome.svg"
    if [ ! -f "$alvo" ]; then
      ausentes=$((ausentes + 1))
    elif [ "$(_vestido "$arte" "${TRACO[$dir]}" "${HEX[${COR[$nome]}]}")" != "$(cat "$alvo")" ]; then
      divergentes=$((divergentes + 1))
    fi
  done < <(_desejado)

  for dir in "${!TRACO[@]}"; do
    [ -d "$BASE/$dir" ] || continue
    for arq in "$BASE/$dir"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      [ -n "${ARTE[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  done

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total aplicativo(s) já vestidos em traço ($FLAVOR)"
    return "$MEOW_OK"
  fi
  meow_muda "aplicativos em traço: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local dir nome arte arq mudou=0 postos=0 removidos=0 rc

  while IFS=$'\t' read -r dir nome arte; do
    set +e
    meow_escrever "$BASE/$dir/$nome.svg" \
      "$(_vestido "$arte" "${TRACO[$dir]}" "${HEX[${COR[$nome]}]}")" 644
    rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; postos=$((postos + 1)) ;;
      *) meow_erro "não consegui escrever $BASE/$dir/$nome.svg"; return "$MEOW_ERRO" ;;
    esac
  done < <(_desejado)

  # Órfão: estava no mapa ontem, não está hoje. Removível porque o dono é único —
  # `48x48/apps` nasce aqui e nenhum outro script do projeto escreve nele.
  for dir in "${!TRACO[@]}"; do
    [ -d "$BASE/$dir" ] || continue
    for arq in "$BASE/$dir"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      if [ -z "${ARTE[$nome]:-}" ]; then
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
    meow_ok "aplicativos já vestidos em traço ($FLAVOR)"
    return "$MEOW_OK"
  fi
  meow_info "aplicativos em traço: $postos posto(s), $removidos removido(s) — $FLAVOR"
  # O DESENHO VAI PARA A TELA, E NÃO PARA O PRÓXIMO LOGIN — 13/09/2026
  #   A frase aqui era "os ícones novos aparecem no próximo login (o painel não
  #   relê o tema)", e descrevia a tela certa: o arquivo no disco e a dock com o
  #   desenho velho. Ela salvou ícones pela interface e não viu nenhum — "nada tá
  #   aplicando de verdade". O painel e o menu relêem cada um pela porta dele.
  # O `|| rc=$?` é o que segura o `set -e` deste script (conferência da P80):
  #   solto, um reler que não devolve 0 — 4 quando o install.sh o adia para o
  #   fim da passada, 3 fora da sessão — derrubava o script com esse código, e
  #   o `concluir` do install.sh contava como PULADO o passo que pôs os desenhos.
  rc=0
  meow_tela_reler || rc=$?
  case $rc in
    0) meow_seco || meow_ok "os ícones novos já estão na dock e no menu" ;;
    3) meow_info "fora da sessão gráfica: os ícones novos aparecem no próximo login" ;;
  esac
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  # a curadoria ANTES do mapa: é `_ler_mapa` quem tira daqui o que ela escolheu
  # à mão, e para isso a lista dela já tem de estar lida.
  _ler_curadoria
  _ler_mapa
  # O convertido entra DEPOIS, e a ordem importa por um motivo só: é ele quem
  # detecta o nome repetido nos dois mapas. Trocar a ordem trocaria só a
  # mensagem, mas a mensagem é a metade útil de uma asserção.
  _ler_mapa_convertidos
  _ceder_ao_pack
  # A marca entra por ÚLTIMO entre os leitores, e tem de ser assim: ela repinta
  # o que os dois acervos já trouxeram, então precisa deles lidos. Vem ANTES do
  # `_conferir_gemeos` para que a asserção veja a cor FINAL, e não a que seria.
  _ler_mapa_marca
  _conferir_gemeos || return $?
  _ler_paleta || return $?
  # `if` e não `[ ] && ...`: com `set -e`, um teste falso no início de uma lista
  # `&&` derruba o script inteiro, calado e com código 1. É o mesmo defeito que
  # o `return 0` do `_ler_mapa` documenta — já aconteceu neste projeto.
  if [ "$COR_MARCA_LIGADA" = 1 ]; then
    meow_info "cor por MARCA ligada (ICONES_COR_MARCA=sim) — a cor de categoria está sobreposta"
  fi
  _avisar_faltantes
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

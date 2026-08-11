#!/usr/bin/env bash
# icones_apps_arcticons.sh — os aplicativos do LANÇADOR vestidos em TRAÇO de
# linha, recolorido na paleta. DOIS acervos entram aqui, e um instalador só sai.
#
# DOIS ACERVOS, DESDE 11/08/2026
#   `icons/arcticons-apps/`    glifos do pack Arcticons, desenhados à mão por
#                              terceiros. Mapa: `icons/apps-arcticons.map`.
#   `icons/convertidos-apps/`  a arte do PRÓPRIO aplicativo, convertida de
#                              chapado para traço por nós. Mapa:
#                              `icons/apps-convertidos.map`. Quem gera é o
#                              `scripts/construir_convertidos.sh`; aqui ela
#                              chega pronta e commitada.
#
#   A junção é ADITIVA e `_vestido()` NÃO MUDOU uma linha: a conversão sai no
#   mesmo dialeto do pack (sem `stroke-width`, `stroke="currentColor"`), de
#   propósito. Conferido: 39 de 39 Arcticons e 25 de 25 convertidos casam com o
#   regex de injeção abaixo.
#
#   E continua havendo UM dono de `48x48/apps`. Um segundo script instalador
#   seria o laço eterno: cada um veria a arte do outro como órfã, apagaria, e o
#   `meow fix` alternaria entre os dois estados sem nunca convergir.
#
# POR QUE EXISTE UM SEGUNDO SCRIPT DE APLICATIVO
#   O `icones_apps.sh` só sabe ler `icons/catppuccin-apps/$VARIANTE/*.png` e só
#   sabe escrever em `512x512/apps`. O Arcticons é outra coisa em tudo: é SVG, é
#   traço monocromático, e a cor é atribuída por nós a partir da paleta. Enfiar
#   os dois no mesmo script obrigaria a um `if` por linha do mapa; separar custa
#   um arquivo e mantém cada caminho dizendo uma coisa só.
#
#   O que NÃO se duplicou foi a verdade: são dois mapas porque são dois acervos,
#   e um nome que aparecesse nos DOIS faz este script ESTOURAR (ver `_conferir_
#   gemeos`). Duas listas do mesmo aplicativo é o defeito de "dois donos" com
#   outra roupa.
#
# O ARCTICONS É APOIO, NÃO O TEMA PRINCIPAL
#   Decisão dela, textual, em 08/08/2026: "o arcticons ele vem pra apoiar o outro
#   tema principal não vem pra ser o tema principal." Ou seja: ele preenche
#   lacuna. Onde não houver match honesto o ícone FICA no Papirus, e isso é
#   resultado, não fracasso.
#
# O QUE FOI MEDIDO ANTES DE ESCREVER UMA LINHA
#
#   1. O DESTINO PRECISA DE DONO ÚNICO, E `scalable/apps` NÃO TEM. Ali escrevem
#      TRÊS: `completar_icones.sh` (apelidos e desenho autoral), `logo.sh` (os
#      botões do dock) e o bootstrap do `construir_icones.sh`. Remover órfão lá
#      apagaria arquivo dos outros. Por isso este script é dono de `48x48/apps`,
#      diretório que nasce aqui e onde mais ninguém escreve — a mesma disciplina
#      do `icones_sistema.sh` com `22x22/status` e `scalable/status`.
#
#   2. O TAMANHO DO DESTINO NÃO É CHUTE: A DOCK DESENHA A 48 px. Medido em
#      08/08/2026 na tela dela, sem abrir janela nenhuma — captura de tela e
#      caixa delimitadora dos ícones da dock por saturação:
#          x 1063..1109  largura 47   (Chrome)
#          x  978..1025  largura 48
#      A dock está em `size L` e é o ÚNICO lugar onde ícone de aplicativo
#      aparece pequeno: o `plugins_center` do painel de cima não tem
#      `CosmicAppList`, só applets (que são `status`, e já são da Sprint A).
#      Papirus usa a mesma convenção — `48x48/apps/*.svg`, `Type=Fixed`.
#
#   3. O TRAÇO É **1,75** DESDE 11/08/2026, E O NÚMERO FOI MEDIDO.
#      O pack desenha num `viewBox="0 0 48 48"` e NÃO declara `stroke-width`; o
#      padrão SVG é 1, e era isso que estava no ar. Em 11/08/2026 ela olhou o
#      lançador e pediu: "só engrossaria mais a linha".
#
#      Quanto engrossar não foi votado. A régua é a CONTRA-FORMA QUE SOBREVIVE —
#      quantos dos buracos fechados do desenho original ainda existem depois de
#      engrossar (o empastamento deixou de servir: traço de 2 px tem miolo
#      próprio, e todo pixel do miolo tem 8 vizinhos com tinta). Em 75 ícones ×
#      7 pesos, a 48 px:
#
#         peso | contra-formas vivas    | tinta na caixa
#              | Arcticons | conversão  | Arcticons | conversão
#         1,0  |   100%    |   100%     |   13,0%   |   18,8%
#         1,5  |    97%    |    80%     |   19,1%   |   24,6%
#         1,75 |    97%    |    76%     |   21,2%   |   27,8%   <- escolhido
#         2,0  |    97%    |    74%     |   23,0%   |   30,0%
#         2,5  |    96%    |    66%     |   26,8%   |   35,2%
#
#      Quem limita NÃO é o Arcticons (97% de 1,5 a 2,25): é a conversão, densa
#      por construção. 1,75 é o maior peso em que a Spotify ainda tem três ondas
#      e o Wilber ainda tem olho — a 2,0 as duas ondas de cima soldam. E entrega
#      o que ela pediu: +63% de tinta na caixa contra o 1,0.
#
#      O NÚMERO É UM SÓ PARA OS DOIS ACERVOS, e isso é o ponto: se só o
#      convertido engrossasse, quebrava-se a coerência que é a razão de tudo
#      isto. Por isso nenhum arquivo dos dois acervos grava `stroke-width` —
#      quem manda é o array `TRACO` abaixo, e engrossar continua sendo UM número.
#      Cuidado ao inserir: `stroke-width` DUPLICADO é XML inválido e o
#      rasterizador recusa o SVG inteiro, calado.
#
#   4. A COR ENTRA AQUI, AO CONTRÁRIO DO `icones_sistema.sh`. Lá o toolkit
#      descarta a cor do arquivo e repinta tudo numa cor só (§4g) — pintar seria
#      trabalho apagado. Isso vale para ícone `symbolic` de sistema; ícone de
#      APLICATIVO não passa por esse caminho, e a cor sobrevive. Conferido
#      rasterizando o arquivo instalado.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta dependência
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="$RAIZ/icons/arcticons-apps"
MAPA="$RAIZ/icons/apps-arcticons.map"
ORIGEM_CONV="$RAIZ/icons/convertidos-apps"
MAPA_CONV="$RAIZ/icons/apps-convertidos.map"
MAPA_PNG="$RAIZ/icons/apps.map"
PALETA="$RAIZ/palette/catppuccin.json"
TEMA="${ICONES_TEMA:-${NOME_TEMA_ICONES:-MeowSystem-Icons}}"
BASE="$HOME/.local/share/icons/$TEMA"

# O FLAVOR AQUI É O DE VERDADE, E ESSA É A VANTAGEM DO SVG
#   O `icones_apps.sh` usa `ICONES_FLAVOR` porque o acervo PNG dele só existe em
#   macchiato e latte, e ele APROXIMA mocha e frappé para o vizinho. Aqui a cor
#   sai da paleta, que tem os quatro — então mocha é mocha.
FLAVOR="${FLAVOR:-mocha}"

# O diretório de destino e a espessura do traço dele. Array para que acrescentar
# um segundo tamanho (um `22x22/apps` com traço grosso, se um dia a barra passar
# a mostrar aplicativo) seja uma linha. Quem DECLARA o diretório no `index.theme`
# não é este script — é o `construir_icones.sh`, que o monta a partir do que
# existe no disco. Ter dois donos daquela linha já custou um laço eterno.
declare -A TRACO=( ["48x48/apps"]=1.75 )

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

# A ESCOLHA DELA NA PÁGINA DE CURADORIA TIRA O NOME DAQUI
#   `icons/curadoria.map` é escrito pelo `importar_icones.sh` com a arte que ELA
#   escolheu à mão. Um nome que está lá não pode continuar sendo vestido aqui:
#   a arte dela vai para `scalable/apps`, a minha fica em `48x48/apps`, e a de
#   48 vence a 48 px — a escolha dela ficaria no disco sem nunca aparecer na
#   tela, que é o pior desfecho possível, porque parece que funcionou.
#
#   Tirar o nome do mapa lido basta, e é por causa do dono único: sem o nome, o
#   `.svg` que sobrou em `48x48/apps` vira órfão e a varredura o remove sozinha
#   na mesma passagem. Não é preciso proteger caminho nenhum aqui, ao contrário
#   do `icones_apps.sh`: aquele escreve `.png` em ONZE diretórios de tamanho, e
#   este escreve `.svg` em UM, que nasce aqui e onde mais ninguém escreve.
#
#   O arquivo só existe depois da primeira importação; ausência não é defeito.
declare -A CURADO=()
_ler_curadoria() {
  local chave ext subdir
  [ -f "$RAIZ/icons/curadoria.map" ] || return 0
  while IFS=$'\t' read -r chave ext subdir; do
    case "$chave" in ''|'#'*) continue ;; esac
    [ -n "$ext" ] && [ -n "$subdir" ] || continue
    CURADO["$chave"]=1
  done < "$RAIZ/icons/curadoria.map"
  return 0
}

declare -A GLIFO=()      # nome do .desktop -> glifo Arcticons (só esse acervo)
declare -A ARTE=()       # nome do .desktop -> caminho do SVG a vestir (os DOIS)
declare -A ACERVO=()     # nome do .desktop -> "Arcticons" | "convertido"
declare -A DUPLO=()      # nome que apareceu nos DOIS mapas de traço
declare -A COR=()        # nome do .desktop -> chave da paleta
declare -A ALIAS_OK=()   # glifo ou cor -> 1, quando a repetição é deliberada
declare -A HEX=()        # chave da paleta -> hex do flavor em uso

# A ASSERÇÃO DE COR REPETIDA DEIXOU DE VALER QUANDO A POLÍTICA MUDOU (10/08/2026)
#   Ela existia para um mapa de TRÊS linhas, onde duas cores iguais só podiam ser
#   descuido. Em 10/08/2026 ela decidiu unificar os 35 aplicativos do lançador no
#   Arcticons e pediu a cor **por categoria** — seis cores para trinta e cinco
#   nomes. Repetir passou a ser o DESENHO, não o acidente: os três navegadores
#   são azuis porque são navegadores.
#
#   Desligar isso linha a linha com `:alias` seria mentir duas vezes. Primeiro
#   porque `:alias` marca glifo E cor de uma vez (a linha abaixo), e a asserção
#   de GLIFO repetido continua valendo — dois aplicativos com o mesmo desenho
#   continua sendo decisão que ninguém deve tomar em silêncio. Segundo porque
#   trinta e cinco `:alias` não declaram uma política: declaram trinta e cinco
#   exceções, e uma regra com exceção em toda linha não é regra.
#
#   Então a política é declarada UMA vez, no topo do mapa, e o script obedece:
#
#     #!cor-por-categoria
#
#   Com ela, cor repetida é esperada e cala; sem ela, o comportamento antigo
#   volta inteiro. O `:alias` continua existindo e continua marcando os dois —
#   é o que a linha do Monitor usa para dizer que dividir o `osmonitor` com o
#   btop foi escolha dela, feita depois de eu avisar.
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
    intocavel "$nome" && continue
    if [ -n "${CURADO[$nome]:-}" ]; then
      meow_debug "$nome: arte escolhida na curadoria — o Arcticons sai de cima"
      continue
    fi
    GLIFO["$nome"]="$glifo"
    ARTE["$nome"]="$ORIGEM/$glifo.svg"
    ACERVO["$nome"]="Arcticons"
    COR["$nome"]="$cor"
    if [ "${marca:-}" = "alias" ]; then ALIAS_OK["$glifo"]=1; ALIAS_OK["cor:$cor"]=1; fi
  done < "$MAPA"
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
# igual, e é o mesmo critério do `icons/curadoria.map`.
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
    intocavel "$nome" && continue
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
  return 0
}

# --- a paleta é a fonte única de cor -----------------------------------------
# Nenhum hex vive dentro de script neste projeto. O mapa grava a CHAVE
# (`sapphire`), e o hex do flavor em uso sai daqui.
_ler_paleta() {
  local nome saida
  for nome in "${COR[@]}"; do
    [ -n "${HEX[$nome]:-}" ] && continue
    saida="$(python3 - "$PALETA" "$FLAVOR" "$nome" <<'PY'
import json, sys
paleta, flavor, chave = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(paleta))["flavors"]
if flavor not in d:
    sys.exit(1)
print(d[flavor].get(chave, ""))
PY
)" || { meow_erro "não consegui ler a paleta para o flavor '$FLAVOR'"; return "$MEOW_ERRO"; }
    if [ -z "$saida" ]; then
      meow_erro "a cor '$nome' não existe em palette/catppuccin.json (flavor $FLAVOR)"
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
#   nome nos DOIS mapas — o mesmo aplicativo listado aqui e em `icons/apps.map`.
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
    meow_pula "o acervo Arcticons de aplicativo não está em icons/arcticons-apps"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem icons/apps-arcticons.map — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$PALETA" ]; then
    meow_pula "sem palette/catppuccin.json — sem fonte de cor, nada a vestir"
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
    meow_aviso "o glifo '$glifo' não está em icons/arcticons-apps — '$nome' fica no Papirus"
    meow_info "  baixe com: curl -s https://api.iconify.design/arcticons/$glifo.svg -o icons/arcticons-apps/$glifo.svg"
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
  meow_info "os ícones novos aparecem no próximo login (o painel não relê o tema)"
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
  _conferir_gemeos || return $?
  _ler_paleta || return $?
  _avisar_faltantes
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

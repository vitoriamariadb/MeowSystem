#!/usr/bin/env bash
# icones_apps.sh — os ícones do LANÇADOR, em Catppuccin.
#
# POR QUE ESTE SCRIPT NÃO USA O PACK DO catppuccin/vscode-icons
#   Ela pediu, textualmente, que os ícones do lançador virassem os do pack
#   Catppuccin que ela mandou. Medido: aquele pack não tem UM ícone de
#   aplicativo — os 656 glifos são de linguagem e formato de arquivo, e o único
#   nome de programa lá é `figma`, que ela não usa. Trocar o lançador por ele
#   deixaria a tela vazia. Aquele pack foi para `mimetypes/`, onde ele brilha
#   (ver icones_mimetypes.sh); o lançador precisava de outra fonte.
#
# A FONTE QUE SERVE, E POR QUE ELA SÓ FICOU DISPONÍVEL AGORA
#   `Daveedmee/catppuccin-icons` são as formas conhecidas de cada marca
#   recoloridas na paleta — Firefox em pêssego, Discord em azul-céu, Spotify em
#   verde pastel. Uma pesquisa anterior o DESCARTOU por não ter licença, o que
#   impediria redistribuir num repositório GPL-3. Em 05/08/2026 ela decidiu que o
#   projeto não será publicado: sem redistribuição, o impedimento deixa de
#   existir para uso nesta máquina. O que continua valendo está no cabeçalho de
#   assets/icones/apps.map, e vale a pena reler antes de mudar de ideia sobre publicar.
#
# PNG, NÃO SVG — E A ESCOLHA É MEDIDA
#   O acervo entrega `.ico` de 256x256 a 24 bits por pixel, ou seja SEM canal
#   alpha: usados assim, os ícones virariam quadrados sólidos sobre o papel de
#   parede. Os PNG de 512x512 da pasta de preview têm alpha (conferido:
#   `%[channels]` = srgba, canto = rgba(0,0,0,0)) e é isso que se instala. Como
#   são raster, vão para `512x512/apps` e NUNCA para `scalable/` — meter raster
#   dentro de um diretório declarado como escalável é o defeito que o
#   thunderbird.png já cometeu neste tema (consertado em 10/08/2026: hoje ele vai
#   para `128x128/apps`, o tamanho real dele — ver `assets/icones/apps-hicolor.map`).
#
# CÓDIGOS DE SAÍDA
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta o acervo
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"

# `ICONES_FLAVOR` TEM DOIS CONSUMIDORES, E O `meow.conf` SÓ DOCUMENTA UM
#   O comentário da chave, no `meow.conf`, a descreve como sendo dos ícones de
#   TIPO DE ARQUIVO (`icones_pastas.sh`, o pack `catppuccin/vscode-icons`). Ela
#   governa TAMBÉM o acervo de aplicativo, que é este arquivo — um interruptor,
#   dois acervos. Registrado aqui em 10/08/2026 porque é assim que se descobre
#   tarde que uma mudança mexeu no que não devia.
#
# E OS ÍCONES DO LANÇADOR ESTAREM EM MACCHIATO NUMA INTERFACE MOCHA É PEDIDO DELA
#   Está escrito no próprio `meow.conf`: "é uma chave PRÓPRIA, e não `$FLAVOR`,
#   porque ela PEDIU os ícones em frappé ou macchiato com a interface em mocha".
#   Medido (10/08/2026): `google-chrome.png` traz o red `#ED8796`, que é o
#   macchiato; o mocha seria `#F38BA8`. Não é dívida técnica e não se "conserta"
#   recolorindo — recolorir desfaria uma decisão dela em silêncio, e ainda por
#   cima num acervo de terceiro cuja licença o `assets/icones/PROCEDENCIA.md` registra
#   como não declarada. Se um dia ela pedir mocha no lançador, a saída limpa é
#   SEPARAR a chave (`APPS_FLAVOR`), e o acervo só publica latte e macchiato.
FLAVOR_ICONES="${ICONES_FLAVOR:-macchiato}"
# O acervo só tem duas variantes: dark=Macchiato, light=Latte. Frappé e Mocha
# caem no vizinho mais próximo em claridade, e o script DIZ que fez isso.
case "$FLAVOR_ICONES" in
  latte) VARIANTE="latte" ;;
  macchiato) VARIANTE="macchiato" ;;
  frappe|mocha) VARIANTE="macchiato"; APROXIMOU="$FLAVOR_ICONES" ;;
  *) VARIANTE="macchiato"; APROXIMOU="$FLAVOR_ICONES" ;;
esac

ORIGEM="$RAIZ/assets/icones/catppuccin-apps/$VARIANTE"
MAPA="$RAIZ/assets/icones/apps.map"
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
BASE_TEMA="$HOME/.local/share/icons/$TEMA"
DESTINO="$BASE_TEMA/512x512/apps"

# ─────────────────────────────────────────────────────────────────────────────
# O SERRILHADO, E POR QUE UM ÚNICO TAMANHO DE 512 O CAUSAVA
# ─────────────────────────────────────────────────────────────────────────────
# Ela olhou o lançador em 08/08/2026 e disse que os ícones do acervo estavam
# bonitos numa folha renderizada e **serrilhados na tela**: *"estavam muito bons
# (olhando a folha 4, mas cheio de serrilhados) se elles ficassem igual da folha 4
# seria perfeito"*.
#
# A CAUSA, MEDIDA: até hoje este script instalava SÓ em `512x512/apps`. A dock
# desenha ícone de aplicativo a **48 px** (medido por captura). Ou seja, o
# toolkit recebia um PNG de 512 e o reduzia **10,7×** em tempo de desenho, com o
# filtro dele — e é esse downscale que serrilha. Na folha o mesmo arquivo saiu
# liso porque foi reduzido com Lanczos antes.
#
# O projeto JÁ SABIA disso, e a lição estava aplicada no lugar errado: o
# `docs/COSMIC-THEMING.md` §4d registra, sobre o `hicolor.sh`, que "com 512x512
# na frente, um ícone de 16px pediria o arquivo de 512 e o downscale ficaria
# borrado na barra". A regra valia para o `hicolor` do usuário e nunca foi
# aplicada ao nosso próprio tema.
#
# O QUE DECIDE NÃO É A ORDEM DE `Directories=`, É O TAMANHO — e isto foi testado
# num tema de mentira com o mesmo nome nos dois diretórios, invertendo a ordem:
#
#     Directories=512x512/apps,48x48/apps  ->  pede 48px, abre 48x48/apps
#     Directories=48x48/apps,512x512/apps  ->  pede 48px, abre 48x48/apps
#
# Nas duas ordens o resolvedor escolheu o tamanho mais próximo. Logo o conserto
# não é reordenar nada: é **existir arquivo no tamanho que o consumidor pede**.
# (Confere com o achado da Sprint C, medido por strace no `cosmic-files`.)
#
# POR QUE NÃO "CONVERTER PARA SVG", que foi a pergunta dela
#   Não existe conversão PNG→SVG que resolva. Embutir o PNG dentro de um `<image>`
#   deixa o arquivo com extensão `.svg` e conteúdo raster — é exatamente o defeito
#   que o `thunderbird.png` já cometeu aqui e que o cabeçalho acima proíbe.
#   Vetorizar por contorno (`potrace` e afins) joga fora o desenho: estes ícones
#   têm degradê e sombra, e o traço saído daí não é a marca. O acervo
#   `Daveedmee/catppuccin-icons` publica **146 PNG e zero SVG** — é limitação da
#   fonte, não escolha nossa. Os outros 935 ícones do tema JÁ SÃO vetor.
#
# A ESCADA É DENSA DE PROPÓSITO, E O PORQUÊ FOI MEDIDO DUAS VEZES
#   Primeira tentativa: 48, 64, 128, 256. Consertou a dock (48 px exatos) e ela
#   voltou dizendo que **o lançador continuava serrilhado**. A medição na captura
#   dela: o círculo do Spotify tem **76 px** de largura, e ele ocupa 100% da caixa
#   do PNG — logo o lançador desenha ícone a 76 px, não a 48 nem a 64.
#
#   E aí entra a diferença entre os dois resolvedores desta máquina, que a Sprint C
#   já tinha registrado: o **GTK** entrega o `128x128` para um pedido de 76 px, mas
#   o COSMIC não usa o GTK — usa a crate `cosmic-freedesktop-icons`, cuja
#   `directory_size_distance` devolve |tamanho − pedido| para `Type=Fixed`. Para
#   76: |76−64| = 12 contra |76−128| = 52. **Ela escolhe o 64 e AMPLIA 1,19×.**
#
#   Ou seja, a escada esparsa só trocou o defeito de lado: antes reduzia 512 em
#   6,7× (serrilha), depois ampliava 64 em 1,19× (borra e serrilha). Medir "a dock
#   ficou perfeita" e parar ali foi o erro — o lançador é outro consumidor, com
#   outro tamanho, e eu não o medi antes de dizer que estava resolvido.
#
#   A saída não é adivinhar o número exato (ele muda com a densidade da interface,
#   e há mais consumidores que ninguém enumerou): é a escada ter passo pequeno o
#   suficiente para que QUALQUER pedido caia a poucos pixels de um arquivo real.
#   Com os degraus abaixo, o pior caso entre 24 e 256 px é 8 px de distância —
#   escala de no máximo 1,17×, contra os 6,7× do começo.
#
#   Custo medido: os dez derivados de um ícone somam ~40 KB, contra os 770 KB do
#   512 que já estava instalado. A escada inteira dos 13 é menos de 1 MB.
# A ESCADA DEIXOU DE SER CRAVADA EM 27/08/2026, E O MOTIVO NÃO É ELEGÂNCIA
#   Estes dez números foram medidos em 08/08/2026 numa tela a 100%, e a
#   justificativa inteira (acima) fala em "a dock desenha a 48 px" e "o lançador
#   a 76 px" — pixels de DISPOSITIVO daquele dia. A tela dela está a 114% desde
#   então: a dock desenha a ~41 e o lançador a ~87, e ninguém releu nada, porque
#   não havia o que ler. Um número medido em captura de tela envelhece no dia em
#   que a tela muda, e envelhece CALADO.
#
#   `meow_icones_escada` (lib/icones.sh) devolve a mesma escada quando a tela é
#   a de 08/08 e OUTRA quando ela muda — a faixa é derivada da escala. A conta,
#   as duas pontas medidas e a garantia de idempotência estão lá.
#
#   E havia DUAS escadas neste projeto: esta, e nenhuma no `jogos_steam.sh`, que
#   plantava só `256x256` e por isso reduzia 6,2x na dock. Agora há uma função
#   só, e os dois scripts a chamam.
mapfile -t TAMANHOS_DERIVADOS < <(meow_icones_escada)
# O `\n` NÃO É ENFEITE — sem ele a varredura de órfão nunca saía do 512
#   Esta função é usada dentro de `$(for px in ...; do dir_de "$px"; done)`, e um
#   `printf` sem quebra de linha faz os dez caminhos virarem UMA palavra colada:
#       [/h/.../24x24/apps/h/.../32x32/apps]
#   O `for d in` recebia então um diretório inexistente, o `[ -d ]` falhava e o
#   laço fazia `continue` — calado. Medido em 10/08/2026 com `bash -x`: dos onze
#   diretórios que este script escreve, a remoção de órfão visitava UM
#   (`512x512/apps`). Consequência prática: um aplicativo tirado do `apps.map`
#   deixava dez PNG para trás, e o `--conferir` dizia que estava tudo certo.
dir_de() { printf '%s/.local/share/icons/%s/%sx%s/apps\n' "$HOME" "$TEMA" "$1" "$1"; }

# Pedido expresso dela: estes ficam como estão, venha o que vier.
INTOCAVEIS_PREFIXO=(steam_icon_)
INTOCAVEIS=(fogstripper hefesto-dualsense4unix com.vitoriamaria.HefestoDualsense4Unix)

intocavel() {
  local n="$1" i
  for i in "${INTOCAVEIS[@]}"; do [ "$n" = "$i" ] && return 0; done
  for i in "${INTOCAVEIS_PREFIXO[@]}"; do case "$n" in "$i"*) return 0 ;; esac; done
  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# O QUE ESTÁ NOS MEUS DIRETÓRIOS E NÃO É MEU
# ─────────────────────────────────────────────────────────────────────────────
# A remoção de órfão daqui apaga `.png` cujo nome não está no `apps.map`. Isso
# era certo enquanto TODO `.png` de `<tam>/apps` fosse meu — e não é mais:
#
#   `assets/icones/apps-hicolor.map`  o `completar_icones.sh` copia a marca de fábrica do
#                             `hicolor` do sistema para o diretório do tamanho
#                             REAL dela (`thunderbird` -> `128x128/apps`), que é
#                             um dos meus;
#   `assets/icones/curadoria.map`     o `importar_icones.sh` instala a arte que ELA
#                             escolheu na página de curadoria, e um PNG escolhido
#                             vai para `<lado>x<lado>/apps` pelo mesmo motivo.
#
# Sem esta leitura o desfecho está medido e é o pior tipo: o `install.sh` roda
# `completar_icones` -> `icones_apps` na mesma passagem, e o auto-reparo das 5h
# repete o par todo dia. A escolha dela apareceria e sumiria sozinha, sem
# ninguém ter decidido nada — e o `--conferir` acusaria "1 a remover" para
# sempre. Um dono declara em arquivo; o vizinho lê. Ninguém duplica lista.
#
# Ler, e não confiar na extensão: aqui os dois lados são `.png`. Contra o
# Arcticons a extensão basta (ele é `.svg` em `48x48/apps`) e está documentado
# na varredura lá embaixo.
#
# A PROTEÇÃO É POR CAMINHO, NÃO POR NOME — E A DIFERENÇA DECIDE QUEM APARECE
#   Ela escolhe UM arquivo, que vai para UM diretório (o do tamanho real dele).
#   Eu escrevo ONZE, um por degrau da escada. Se eu protegesse o NOME, os meus
#   dez sobreviveriam junto com o dela — e o resolvedor pegaria o do tamanho
#   pedido, que quase nunca é o dela. A escolha dela ficaria no disco sem nunca
#   aparecer na tela, que é o pior desfecho possível: parece que funcionou.
#   Então: o nome sai do meu mapa (não instalo mais nada dele, e os meus onze
#   viram órfãos e saem), e o ARQUIVO dela é protegido pelo caminho exato.
declare -A ALHEIO_ARQ=()   # "128x128/apps/thunderbird.png" -> 1
declare -A CURADO=()       # nome escolhido por ela na página -> 1
_ler_alheios() {
  local linha chave caminho ext subdir lado
  # `nome:caminho-no-sistema` — a marca de fábrica. O diretório de destino sai
  # do caminho da fonte, exatamente como o `completar_icones.sh` o deriva.
  if [ -f "$RAIZ/assets/icones/apps-hicolor.map" ]; then
    while IFS= read -r linha; do
      case "$linha" in ''|'#'*) continue ;; esac
      chave="${linha%%:*}"; caminho="${linha#*:}"
      [ -n "$chave" ] && [ -n "$caminho" ] || continue
      lado="$(basename "$(dirname "$(dirname "$caminho")")")"
      case "$lado" in
        [0-9]*x[0-9]*) ALHEIO_ARQ["$lado/apps/$chave.png"]=1 ;;
      esac
    done < "$RAIZ/assets/icones/apps-hicolor.map"
  fi
  # `chave<TAB>extensão<TAB>subdiretório` — escrito pelo `importar_icones.sh`.
  # Ele só existe depois da primeira importação; ausência não é defeito.
  if [ -f "$RAIZ/assets/icones/curadoria.map" ]; then
    while IFS=$'\t' read -r chave ext subdir; do
      case "$chave" in ''|'#'*) continue ;; esac
      [ -n "$ext" ] && [ -n "$subdir" ] || continue
      CURADO["$chave"]=1
      ALHEIO_ARQ["$subdir/$chave.$ext"]=1
    done < "$RAIZ/assets/icones/curadoria.map"
  fi
  return 0
}

# Um arquivo que eu não posso apagar: ou é de outro dono declarado (caminho
# exato), ou o nome é intocável por pedido dela. Os intocáveis entram aqui
# porque o `_ler_mapa` os TIRA do `MAPA_LIDO` — sem este teste, um
# `steam_icon_*` que caísse num destes diretórios seria varrido como órfão, que
# é o contrário do que ela pediu.
_nao_e_meu() {
  local arq="$1" nome="$2"
  [ -n "${ALHEIO_ARQ[${arq#"$BASE_TEMA/"}]:-}" ] && return 0
  intocavel "$nome"
}

declare -A MAPA_LIDO=()
_ler_mapa() {
  local linha nome arq
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"; arq="${linha#*:}"
    [ -n "$nome" ] && [ -n "$arq" ] || continue
    intocavel "$nome" && continue
    # Escolha dela na página de curadoria vence o acervo, e vence CALANDO este
    # script: o nome sai daqui, meus onze arquivos viram órfãos na varredura e
    # saem, e o que sobra é o dela. `importar_icones.sh` roda depois, mas a
    # ordem não bastaria — na rodada seguinte eu reescreveria por cima.
    if [ -n "${CURADO[$nome]:-}" ]; then
      meow_debug "$nome: arte escolhida na curadoria — não é mais deste acervo"
      continue
    fi
    MAPA_LIDO["$nome"]="$arq"
  done < "$MAPA"
  # `return 0` NÃO É DECORAÇÃO: um `while` devolve o status do último comando do
  # corpo. Se a última linha do mapa cair num teste que falha (`intocavel`), o
  # laço devolve 1 e, com `set -e`, o script morre aqui — calado e com código 1.
  # Aconteceu no `icones_apps_arcticons.sh`, e o cabeçalho de lá conta.
  return 0
}

_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "o acervo Catppuccin de aplicativos não está em assets/icones/catppuccin-apps/$VARIANTE"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  [ -f "$MAPA" ] || { meow_pula "sem assets/icones/apps.map — nada a vestir"; return "$MEOW_SEM_DEPENDENCIA"; }
  return "$MEOW_OK"
}

_desejado() {
  local nome arq
  for nome in "${!MAPA_LIDO[@]}"; do
    arq="${MAPA_LIDO[$nome]}"
    [ -f "$ORIGEM/$arq.png" ] && printf '%s\t%s\n' "$nome" "$ORIGEM/$arq.png"
  done
}

# Mesma disciplina do icones_mimetypes.sh: compara como o escritor escreve. Aqui
# o conteúdo é binário, então a comparação é `cmp` — e a escrita é `cp`, não
# `meow_escrever`, justamente para que os dois falem a mesma língua.
# O DERIVADO NÃO É CONFERIDO POR CONTEÚDO, E ISSO É DE PROPÓSITO
#   O 512 é cópia, então `cmp` byte a byte é o critério certo para ele. Os
#   derivados nascem de um `convert -filter Lanczos`, e comparar o BYTE deles
#   seria fazer o projeto depender da versão do ImageMagick: um `apt upgrade` que
#   mudasse um arredondamento faria os 13 ícones divergirem "para sempre", e o
#   auto-reparo os reescreveria toda madrugada anunciando conserto. É o laço
#   eterno que o `construir_icones.sh` §1 documenta, com outra roupa.
#
#   O critério é: existe · tem a dimensão certa · e não é mais antigo que a
#   origem. O mtime é o mesmo teste que o `completar_icones.sh` já usa para a
#   cache do GTK (`themes.bin` não pode ser mais velho que o `.tmTheme`) — se o
#   acervo mudar, o derivado é refeito; se não mudou, ninguém escreve nada.
_derivado_ok() {
  local arq="$1" origem="$2" px="$3" dim
  [ -f "$arq" ] || return 1
  [ "$arq" -nt "$origem" ] || [ "$arq" -ef "$origem" ] || return 1
  dim="$(identify -format '%wx%h' "$arq" 2>/dev/null)" || return 1
  [ "$dim" = "${px}x${px}" ]
}

_conferir() {
  local nome origem faltam=0 diferem=0 orfaos=0 total=0 arq px
  while IFS=$'\t' read -r nome origem; do
    total=$((total + 1))
    if [ ! -f "$DESTINO/$nome.png" ]; then faltam=$((faltam + 1))
    elif ! cmp -s "$origem" "$DESTINO/$nome.png"; then diferem=$((diferem + 1))
    fi
    for px in "${TAMANHOS_DERIVADOS[@]}"; do
      _derivado_ok "$(dir_de "$px")/$nome.png" "$origem" "$px" || faltam=$((faltam + 1))
    done
  done < <(_desejado)
  # ÓRFÃO EM TODOS OS DIRETÓRIOS, E SÓ `.png` — a extensão é o que separa os dois
  # acervos de aplicativo. O Arcticons vive em `48x48/apps` com `.svg`, e este
  # script agora escreve `.png` no mesmo diretório. Varrer `*.png` mantém cada um
  # dono do que escreveu, sem precisar que um leia o mapa do outro — e a asserção
  # do `icones_apps_arcticons.sh` já garante que nenhum nome está nos dois mapas.
  local d
  for d in "$DESTINO" $(for px in "${TAMANHOS_DERIVADOS[@]}"; do dir_de "$px"; done); do
    [ -d "$d" ] || continue
    for arq in "$d"/*.png; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .png)"
      _nao_e_meu "$arq" "$nome" && continue
      [ -n "${MAPA_LIDO[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  done
  if [ "$faltam" = 0 ] && [ "$diferem" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total aplicativos já com ícone Catppuccin ${APROXIMOU:+($APROXIMOU aproximado para $VARIANTE)}"
    return "$MEOW_OK"
  fi
  meow_muda "aplicativos: $faltam a instalar, $diferem a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local nome origem arq mudou=0 postos=0 removidos=0
  while IFS=$'\t' read -r nome origem; do
    if [ -f "$DESTINO/$nome.png" ] && cmp -s "$origem" "$DESTINO/$nome.png"; then continue; fi
    if meow_seco; then meow_muda "mudaria $DESTINO/$nome.png"; mudou=1; postos=$((postos+1)); continue; fi
    meow_destino_permitido "$DESTINO/$nome.png" || return "$MEOW_ERRO"
    mkdir -p "$DESTINO"
    local tmp; tmp="$(mktemp -p "$DESTINO" ".meow.XXXXXX")"
    cp -f "$origem" "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$DESTINO/$nome.png" \
      || { rm -f "$tmp"; meow_erro "não consegui escrever $DESTINO/$nome.png"; return "$MEOW_ERRO"; }
    mudou=1; postos=$((postos + 1))
  done < <(_desejado)

  # Os derivados: um arquivo por tamanho que o COSMIC de fato pede, para que ele
  # nunca precise reduzir 512 px em tempo de desenho. É isto que tira o
  # serrilhado — ver o cabeçalho.
  local px dir
  while IFS=$'\t' read -r nome origem; do
    for px in "${TAMANHOS_DERIVADOS[@]}"; do
      dir="$(dir_de "$px")"
      _derivado_ok "$dir/$nome.png" "$origem" "$px" && continue
      if meow_seco; then
        meow_muda "geraria ${px}x${px} de $nome"; mudou=1; postos=$((postos+1)); continue
      fi
      meow_destino_permitido "$dir/$nome.png" || return "$MEOW_ERRO"
      mkdir -p "$dir"
      local tmp2; tmp2="$(mktemp -p "$dir" ".meow.XXXXXX")"
      # `-filter Lanczos` é o ponto do exercício: é o filtro que a folha usou e
      # que ela viu liso. `-background none` porque estes PNG têm alpha, e sem
      # isso o `convert` acha um fundo branco.
      if convert "$origem" -background none -filter Lanczos -resize "${px}x${px}" \
                 -strip PNG32:"$tmp2" 2>/dev/null; then
        chmod 644 "$tmp2"
        mv -f "$tmp2" "$dir/$nome.png" \
          || { rm -f "$tmp2"; meow_erro "não consegui escrever $dir/$nome.png"; return "$MEOW_ERRO"; }
        mudou=1; postos=$((postos + 1))
      else
        rm -f "$tmp2"
        # Sem `convert` não há derivado, e o ícone continua vindo do 512 —
        # serrilhado, mas presente. Aviso, não erro: o instalador não pode
        # parar por causa da nitidez de um ícone.
        meow_aviso "não consegui gerar ${px}x${px} de $nome (falta imagemagick?)"
      fi
    done
  done < <(_desejado)

  for dir in "$DESTINO" $(for px in "${TAMANHOS_DERIVADOS[@]}"; do dir_de "$px"; done); do
    [ -d "$dir" ] || continue
    for arq in "$dir"/*.png; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .png)"
      _nao_e_meu "$arq" "$nome" && continue
      if [ -z "${MAPA_LIDO[$nome]:-}" ]; then
        if meow_seco; then meow_muda "removeria $arq (saiu do mapa)"
        else meow_destino_permitido "$arq" || return "$MEOW_ERRO"; rm -f "$arq"; fi
        mudou=1; removidos=$((removidos + 1))
      fi
    done
  done

  if [ "$mudou" = 0 ]; then
    # O NÚMERO ENTRA AQUI PORQUE ELE FALTAVA — e a falta era visível na tela: o
    # `--conferir` dizia "16 aplicativos já com ícone Catppuccin" e o `--aplicar`,
    # no mesmo estado, dizia "aplicativos já com ícone Catppuccin", sem contagem.
    # Duas frases para o mesmo fato, uma delas incompleta.
    local quantos; quantos="$(_desejado | wc -l)"
    meow_ok "$quantos aplicativos já com ícone Catppuccin ${APROXIMOU:+($APROXIMOU aproximado para $VARIANTE)}"
    return "$MEOW_OK"
  fi
  meow_info "aplicativos: $postos posto(s), $removidos removido(s) — Catppuccin $VARIANTE"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  # os alheios ANTES do mapa: é `_ler_mapa` quem tira do acervo o que ela
  # escolheu à mão, e para isso a lista dela já tem de estar lida.
  _ler_alheios
  _ler_mapa
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

APROXIMOU="${APROXIMOU:-}"
main "$@"

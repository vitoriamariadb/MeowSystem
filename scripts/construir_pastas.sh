#!/usr/bin/env bash
# construir_pastas.sh — as pastas do Papirus na cor do flavor, sem tocar no Papirus.
#
# O MÉTODO OFICIAL DO CATPPUCCIN NÃO SERVE AQUI
#   O README de `catppuccin/papirus-folders` manda:
#       sudo cp -r src/* /usr/share/icons/Papirus
#   Isto é, escrever por cima de um diretório do apt. Todo `apt upgrade` do
#   `papirus-icon-theme` desfaz — e a especificação deste projeto proíbe, com
#   razão. Aqui o Papirus fica intacto e derivamos um tema por cima.
#
# NEM PRECISAMOS DA FERRAMENTA `papirus-folders`
#   Ela existe para resolver um problema que não temos: trocar a cor DENTRO do
#   Papirus instalado. O que ela faz é criar, para cada `folder-<cor>-X.svg`, um
#   link `folder-X.svg`. Como estamos montando um tema do zero, fazemos isso
#   direto — uma dependência de rede a menos, e sem o SHA de um repositório
#   parado há dois anos no caminho crítico.
#
# A ARMADILHA DOS APELIDOS (mediria mal quem só testasse a pasta genérica)
#   O Papirus define 85 nomes-APELIDO em `places` que são symlinks para
#   `folder-blue-*` e `user-blue-*` — entre eles `user-home`, `folder-download`,
#   `folder-documents` e `inode-directory`, que é o nome genérico de diretório
#   que os aplicativos realmente pedem. Um tema derivado que copie só os SVGs
#   coloridos NÃO cobre esses nomes: a busca cai no Papirus-Dark e metade das
#   pastas fica mauve enquanto a outra metade continua AZUL.
#   Por isso este script reproduz cada apelido apontando para o equivalente
#   colorido, e conta quantos conseguiu — o número aparece no log de propósito.
#
# CÓPIA REAL, NÃO SYMLINK PARA /usr/share
#   Symlinkar os SVGs coloridos para o Papirus economizaria disco, mas amarraria
#   o tema à versão instalada do pacote: um `apt upgrade` que renomeie um arquivo
#   deixaria links quebrados espalhados. São ~2 MB; a cópia é barata e é honesta.
#
# ESTE SCRIPT CEDE ALGUNS NOMES — E A CESSÃO É CONDICIONAL, DE PROPÓSITO
#   Desde 08/08/2026 as pastas ESPECIAIS que o `cosmic-files` pede pelo nome XDG
#   (`folder-pictures`, `folder-music`, ...) são vestidas pelo pack Catppuccin,
#   em `scalable/places`, pelo `scripts/icones_pastas.sh`. Se este script
#   continuasse criando o apelido mauve no mesmo nome, haveria DOIS arquivos para
#   o mesmo ícone — e medido, os dois resolvedores discordam: a crate do COSMIC
#   abre o `scalable`, o GTK abre o tamanho exato. A mesma pasta apareceria
#   pastel a 16px e mauve a 48px dentro de um mesmo aplicativo GTK.
#
#   A cessão é a saída, no padrão do `INTOCAVEIS` do `icones_apps.sh`: a lista
#   vem de `icons/pastas.map`, que é a mesma que o outro script instala — uma
#   fonte de verdade só.
#
#   MAS SÓ SE CEDE O QUE JÁ ESTÁ NO DISCO. Ceder um nome cujo pastel ainda não
#   foi instalado deixaria aquela pasta AZUL (herdada do Papirus) até a rodada
#   seguinte — pior que a cor errada, porque quebra o conjunto. Por isso o teste
#   é `[ -f scalable/places/<nome>.svg ]`, e não a mera presença no mapa: se o
#   outro script falhar, sumir ou perder o pack, este aqui volta a vestir o nome
#   de mauve na mesma passagem, sozinho.
#
# CEDER UM NOME QUEBRA OS APELIDOS QUE PASSAM POR ELE — MEDIDO, SÃO 11
#   O `SPRINTS.md` avisava de UMA cadeia (`folder-videos -> folder-video`) e
#   errava o lado: cedemos `folder-videos`, que é o topo, então `folder-video`
#   nem é tocado. O problema real é o inverso e é maior. Medido no Papirus-Dark,
#   fecho transitivo dos 7 nomes cedidos, idêntico nos 5 tamanhos:
#
#       folder-documents  <- folder_man folder-text folder-txt folder_wordprocessing
#       folder-download   <- folder-downloads
#       folder-music      <- folder-sound library-music
#       folder-pictures   <- folder-images <- folder-image ; folder-picture
#       folder-publicshare<- folder-public
#
#   São 11 nomes × 5 tamanhos = 55 apelidos que o passe 2 abandonaria (ele exige
#   `[ -e "$destino/$alvo" ]`), e que cairiam AZUIS sem ninguém acusar. O conserto
#   está no passe 2: quando o alvo foi cedido, desce a cadeia inteira do Papirus
#   com `readlink -f` e aponta direto para a cor. Eles continuam mauve.
#
# 22x22 E 24x24 FICARAM SEM APELIDO NENHUM ATÉ 08/08/2026 — E NÃO ERA COR
#   `Papirus-Dark/22x22/places` e `.../24x24/places` são SYMLINK para a árvore
#   `Papirus` (clara); só 32/48/64 são diretório de verdade. O `find` do laço dos
#   apelidos não tinha barra no fim, e sem barra ele não desce em diretório
#   linkado: achava 1 entrada (o próprio link) em vez de 223. Resultado no disco:
#   118 apelidos em cada um dos três tamanhos grandes e ZERO nos dois pequenos.
#
#   E A CONTA "116 NOMES FICAM AZUIS" ESTAVA ERRADA — MEDIDO NOS DOIS RESOLVEDORES
#   O laço externo da busca é o TEMA, não o tamanho: o GTK e a
#   `cosmic-freedesktop-icons` varrem TODOS os diretórios do tema selecionado,
#   ordenados por distância de tamanho, antes de tocar no `Inherits=`. Com o nome
#   presente em 32/48/64, um pedido de 16 px era servido pelo NOSSO 32x32 — mauve,
#   só com a arte do tamanho errado. O Papirus nunca entrou. Provado com
#   `Gtk.IconTheme.lookup_icon` a 16/22/24/32/48 px e com `directories.rs`
#   (`directory_size_distance`) + `theme/mod.rs` (`closest_match_size`) do commit
#   `ab4c57b8` que os binários do COSMIC fixam.
#
#   O QUE O CONSERTO GANHA, ENTÃO: a arte do tamanho certo. Medido em pixels de
#   borda parcial (anti-aliasing) da pasta genérica:
#       pedido 22 px:  arte nativa 6,0%  contra  14,9% da arte de 32 reduzida
#       pedido 24 px:  arte nativa 5,0%  contra  14,1%
#       pedido 16 px:  arte de 22    21,5%  contra   9,8% da arte de 32
#   Ou seja 22 e 24 px melhoram muito, e 16 px fica um pouco MAIS macio, porque
#   32→16 é uma divisão exata por 2 e 22→16 não é. É o preço honesto, e é o que a
#   especificação freedesktop manda de todo jeito (usar o tamanho mais próximo).
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
BASE="${ICONES_BASE:-Papirus-Dark}"
BASE_DIR="/usr/share/icons/$BASE"
COR="${ICONES_PASTAS:-cat-mocha-mauve}"
FONTE="${MEOW_CAT_FOLDERS:-$RAIZ/src/icons/upstream/papirus-folders}"

TAMANHOS=(22x22 24x24 32x32 48x48 64x64)

# --- os nomes que este script CEDE (ver o cabeçalho) -------------------------
MAPA_PASTAS="$RAIZ/icons/pastas.map"
PASTEL_DIR="$TEMA_DIR/scalable/places"

declare -A CEDIDOS=()
ler_cedidos() {
  local linha nome
  [ -f "$MAPA_PASTAS" ] || return 0
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"
    [ -n "$nome" ] || continue
    # A CONDIÇÃO É O DISCO, NÃO O MAPA — ver o cabeçalho. Sem o pastel instalado
    # não se cede, e a pasta continua mauve em vez de ficar azul.
    [ -f "$PASTEL_DIR/$nome.svg" ] && CEDIDOS["$nome"]=1
  done < "$MAPA_PASTAS"
  return 0
}

# Aceita com ou sem `.svg`, porque o laço dos apelidos tem as duas formas na mão.
cedido() { [ -n "${CEDIDOS[${1%.svg}]:-}" ]; }

ler_cedidos

if [ ! -d "$BASE_DIR" ]; then
  meow_aviso "$BASE não está instalado — pastas coloridas puladas"
  meow_info "instale com: sudo apt install papirus-icon-theme"
  exit "$MEOW_SEM_DEPENDENCIA"
fi
if [ ! -d "$FONTE/src" ]; then
  meow_aviso "falta o upstream em $FONTE"
  meow_info "rode: scripts/baixar_upstream.sh"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

# `folder-cat-mocha-mauve-documents.svg` -> `documents`; a pasta raiz -> vazio.
sufixo_de() {
  local n; n="$(basename "$1" .svg)"
  printf '%s' "${n#folder-$COR}" | sed 's/^-//'
}

lixeiras=0
copiados=0
apelidos=0
faltaram=0
cedidos=0
azuis=0
mudou=0


# ─────────────────────────────────────────────────────────────────────────────
# AS DUAS LIXEIRAS, QUE ERAM O ÚNICO BURACO NO ACCENT DELA
# ─────────────────────────────────────────────────────────────────────────────
# Medido em 08/08/2026: dos 12 nomes de pasta que o `cosmic-files` pede, **10**
# resolvem em mauve e **2 não** — `user-trash` e `user-trash-full`. O
# `papirus-folders` simplesmente não os tem, então eles caem no Papirus base e
# saem CINZA (`#8e8e8e`, `#9f9f9f`, os únicos fill dos cinco tamanhos).
#
# CORRIGE UM FATO ERRADO NO REPO: o `icons/pastas.map` diz que essas duas
# "continuam azuis". Não são azuis, são cinza — conferido nos 5 tamanhos.
#
# OS TONS SAEM DAS PASTAS DELA, NÃO DE UM HEX CRAVADO AQUI
#   A regra do projeto é que nenhum hex vive dentro de script. Mas o tom escuro
#   que o `papirus-folders` usa na sombra (`#B792E3` no mauve do mocha) **não é
#   uma cor da paleta** — é um derivado que o upstream calculou. Cravá-lo aqui
#   seria inventar cor; recalculá-lo seria adivinhar a conta do upstream.
#   Então a fonte é o disco: lemos os dois tons do arquivo de pasta que o passe 1
#   acabou de instalar. A lixeira passa a usar EXATAMENTE os tons das pastas
#   vizinhas, e segue o accent sozinha no dia em que ela trocar de cor.
# RODA DENTRO DO LAÇO, POR TAMANHO — e a ordem foi um defeito real, medido
#   A primeira versão desta função rodava DEPOIS do laço dos tamanhos. Efeito
#   numa instalação limpa: `user-trash.svg` só existia na rodada seguinte, e por
#   isso os apelidos que dependem dele (`trashcan_empty`, `trashcan_full`) só
#   nasciam na TERCEIRA. O script convergia, mas o `doctor` acusava divergência
#   uma vez sem motivo aparente. Chamada entre o passe 1 (que instala o modelo de
#   onde saem os tons) e o passe 2 (que cria os apelidos), converge em uma.
#   AS DUAS GUARDAS SAÍAM COM `continue` DENTRO DE UM `{ }`, QUE NÃO É LAÇO
#   Medido no bash 5.2.21 desta máquina: `continue` fora de laço não interrompe
#   nada — imprime "continue: significativo apenas em um loop" no stderr e a
#   execução SEGUE para a linha de baixo. As duas guardas, portanto, não
#   guardavam. Com o modelo ausente, `claro` e `escuro` saíam vazios e o `sed`
#   virava `s/#9f9f9f//`, gravando uma lixeira SEM cor — e gravando de verdade,
#   porque a guarda seguinte também não barrava.
#   Não disparava hoje só por sorte: o modelo existe nos cinco tamanhos. A
#   correção é `return 0`, que é o que as guardas sempre quiseram dizer — a
#   função trata UM tamanho por chamada, então não há laço para continuar.
recolorir_lixeiras() {
  local tam="$1" origem destino modelo claro escuro alvo tmp
  destino="$TEMA_DIR/$tam/places"
  # O modelo é uma pasta mauve já instalada; sem ela não há de onde tirar tom.
  modelo="$destino/folder-$COR-documents.svg"
  [ -f "$modelo" ] || return 0
  claro="$(grep -oE '#[0-9A-Fa-f]{6}' "$modelo" | sort -u | grep -viE '#(CDD6F4|313244|11111B|1E1E2E)' | head -1)"
  escuro="$(grep -oE '#[0-9A-Fa-f]{6}' "$modelo" | sort -u | grep -viE "#(CDD6F4|313244|11111B|1E1E2E|${claro#\#})" | head -1)"
  [ -n "$claro" ] && [ -n "$escuro" ] || return 0

  for alvo in user-trash user-trash-full; do
    origem="$(find -L "$BASE_DIR/$tam/places" -maxdepth 1 -name "$alvo.svg" 2>/dev/null | head -1)"
    [ -n "$origem" ] || continue
    # `sed` sobre o cinza do Papirus, do mais claro para o mais escuro. É o
    # mesmo mecanismo do `icones_sistema.sh` com o Arcticons.
    local desejado; desejado="$(sed -e "s/#9f9f9f/$claro/gI" -e "s/#8e8e8e/$escuro/gI" "$origem")"
    if [ -f "$destino/$alvo.svg" ] && [ "$desejado" = "$(cat "$destino/$alvo.svg" 2>/dev/null)" ]; then
      continue
    fi
    if meow_seco; then
      meow_muda "recoloriria $tam/$alvo.svg no accent"; mudou=1; continue
    fi
    meow_destino_permitido "$destino/$alvo.svg" || exit "$MEOW_ERRO"
    tmp="$(mktemp -p "$destino" ".meow.XXXXXX")"
    printf '%s' "$desejado" > "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$destino/$alvo.svg" \
      || { rm -f "$tmp"; meow_erro "não consegui recolorir $alvo"; exit "$MEOW_ERRO"; }
    mudou=1; lixeiras=$((lixeiras + 1))
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# AS QUATRO PASTAS QUE FICARAM AZUIS PORQUE O UPSTREAM PAROU ANTES DO PAPIRUS
# ─────────────────────────────────────────────────────────────────────────────
# Medido em 10/08/2026, nos cinco tamanhos, casando cada APELIDO de
# `Papirus-Dark/<tam>/places` com o `folder-$COR-*` que deveria vesti-lo:
#
#     folder-docker · folder-notes · folder-obsidian · folder-systemd
#
# São quatro nomes que o `papirus-icon-theme` instalado tem e que o
# `catppuccin/papirus-folders` — parado há dois anos, como o cabeçalho já diz —
# nunca gerou. Sem o `folder-$COR-<sufixo>` no disco, o passe 1 não cria apelido
# nenhum (ele exige `[ -e "$destino/$equivalente" ]`), o nome sai INTEIRO do
# nosso tema e o resolvedor desce para o `Inherits=`:
#
#     Gtk.IconTheme(MeowSystem-Icons).lookup_icon("folder-docker", 48)
#       -> /usr/share/icons/Papirus-Dark/48x48/places/folder-docker.svg
#     $ grep -o 'fill:#[0-9a-f]*' nesse arquivo   ->  fill:#5294e2
#
# Quatro pastas AZUIS no meio de um conjunto mauve — e as quatro TÊM símbolo
# interno (a baleia, o bloco de notas, o cristal, a engrenagem), que é
# exatamente o que ela pediu em 10/08: "símbolo por tipo, em mauve". É o mesmo
# buraco das lixeiras cinzas de 08/08, e o conserto é o mesmo mecanismo: `sed`
# sobre a arte do Papirus. O que muda é de onde sai a tabela de cores.
#
# A TABELA SAI DO DISCO, NÃO DE HEX CRAVADO AQUI
#   `folder-blue-documents.svg` (Papirus) e `folder-$COR-documents.svg`
#   (papirus-folders) são o MESMO desenho: conferido nos cinco tamanhos, o `diff`
#   com todo hex mascarado dá zero. Logo os hexes, na ordem do documento,
#   correspondem-se um a um — e a correspondência medida é:
#
#       #4877b1 -> #B792E3   a sombra de trás
#       #e4e4e4 -> #CDD6F4   o papel
#       #5294e2 -> #CBA6F7   a frente
#       #ffffff -> #CDD6F4   o brilho
#       #1d344f -> #313244   o SÍMBOLO interno
#
#   E os quatro órfãos usam exatamente esses cinco, nos cinco tamanhos. Ler o par
#   do disco em vez de cravar é o que faz trocar `ACCENT`/`FLAVOR` no `meow.conf`
#   acertar isto sozinho — a mesma disciplina que o `recolorir_lixeiras` acima já
#   segue por outro caminho.
#
#   SE O PAR DEIXAR DE SER O MESMO DESENHO, ESTA FUNÇÃO PARA. Um `apt upgrade`
#   que redesenhe o `folder-blue-documents` quebra a correspondência posicional,
#   e pintar por posição errada é pior do que não pintar: sairia o símbolo com a
#   cor da sombra. O `diff` mascarado é a trava, e o silêncio é de propósito —
#   sem a tabela, as quatro voltam a herdar do Papirus, azuis, como eram antes.
#
# `bluegrey` FICA DE FORA, E ISSO TAMBÉM CONSERTA UMA CONTA
#   `folder-bluegrey-*` casa com o padrão `folder-blue*` — quatro apelidos de uma
#   PALETA diferente do Papirus (não é o azul padrão) entravam no laço abaixo,
#   viravam `folder-cat-mocha-mauvegrey-video.svg`, não achavam nada e engordavam
#   o contador `faltaram`. Quem pede `bluegrey` quer bluegrey; herdar do Papirus
#   ali é o certo. Só a CONTA estava errada.
declare -A DE_PARA=()
declare -A VESTIDOS_AZUIS=()

tabela_azul_mauve() {
  local tam="$1" azul mauve i
  local -a de=() para=()
  DE_PARA=()
  azul="$BASE_DIR/$tam/places/folder-blue-documents.svg"
  mauve="$FONTE/src/$tam/places/folder-$COR-documents.svg"
  [ -f "$azul" ] && [ -f "$mauve" ] || return 1
  diff -q <(sed -E 's/#[0-9A-Fa-f]{6}/COR/g' "$azul") \
          <(sed -E 's/#[0-9A-Fa-f]{6}/COR/g' "$mauve") >/dev/null 2>&1 || return 1
  mapfile -t de   < <(grep -oE '#[0-9A-Fa-f]{6}' "$azul")
  mapfile -t para < <(grep -oE '#[0-9A-Fa-f]{6}' "$mauve")
  [ "${#de[@]}" -gt 0 ] && [ "${#de[@]}" = "${#para[@]}" ] || return 1
  for i in "${!de[@]}"; do
    # Um hex azul querendo duas cores mauve diferentes é sinal de que o par
    # deixou de ser o mesmo desenho. Melhor parar do que pintar torto.
    if [ -n "${DE_PARA[${de[$i]}]:-}" ] && [ "${DE_PARA[${de[$i]}]}" != "${para[$i]}" ]; then
      DE_PARA=(); return 1
    fi
    DE_PARA["${de[$i]}"]="${para[$i]}"
  done
  return 0
}

vestir_azuis_orfaos() {
  local tam="$1" destino link nome fim eq origem desejado hex rc
  local -a troca=()
  destino="$TEMA_DIR/$tam/places"
  tabela_azul_mauve "$tam" || return 0
  for hex in "${!DE_PARA[@]}"; do troca+=(-e "s/$hex/${DE_PARA[$hex]}/gI"); done

  while IFS= read -r link; do
    nome="$(basename "$link")"
    # Nome cedido ao icones_pastas.sh não se veste aqui — a cessão vale primeiro,
    # senão voltaríamos a ter dois desenhos para o mesmo ícone.
    cedido "$nome" && continue
    origem="$(readlink -f "$link")"
    [ -f "$origem" ] || continue
    fim="$(basename "$origem")"
    case "$fim" in
      folder-bluegrey*|user-bluegrey*) continue ;;
      folder-blue*|user-blue*) ;;
      *) continue ;;
    esac
    eq="${fim/folder-blue/folder-$COR}"
    eq="${eq/user-blue/user-$COR}"
    # Tem twin mauve: o laço dos apelidos resolve, e resolve melhor (symlink).
    [ -f "$FONTE/src/$tam/places/$eq" ] && continue

    desejado="$(sed "${troca[@]}" "$origem")"
    meow_escrever "$destino/$nome" "$desejado" 644
    rc=$?
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; azuis=$((azuis + 1)) ;;
      *) meow_erro "não consegui recolorir $tam/$nome"; exit "$MEOW_ERRO" ;;
    esac
    VESTIDOS_AZUIS["$tam/$nome"]=1
  done < <(find "$BASE_DIR/$tam/places/" -maxdepth 1 -type l 2>/dev/null)
  return 0
}

for tam in "${TAMANHOS[@]}"; do
  origem="$FONTE/src/$tam/places"
  destino="$TEMA_DIR/$tam/places"
  [ -d "$origem" ] || continue
  # O `meow_seco ||` NÃO É ENFEITE, e a falta dele era um defeito real: o
  # `meow doctor` roda este script com `MEOW_DRY_RUN=1` todo dia às 5h, e um
  # `mkdir -p` sem guarda CRIAVA diretório numa conferência que promete não
  # escrever nada. Padrão do projeto, igual ao `completar_icones.sh:213`.
  meow_seco || mkdir -p "$destino" || { meow_erro "não consegui criar $destino"; exit "$MEOW_ERRO"; }

  # 1. os SVGs coloridos, como cópia real
  while IFS= read -r svg; do
    alvo="$destino/$(basename "$svg")"
    if [ ! -f "$alvo" ] || ! cmp -s "$svg" "$alvo"; then
      meow_seco || cp -f "$svg" "$alvo"
      mudou=1
    fi
    copiados=$((copiados+1))
  done < <(find "$origem" -maxdepth 1 -name "folder-$COR*.svg" -o -maxdepth 1 -name "user-$COR*.svg" 2>/dev/null)

  # As lixeiras ANTES do passe 2: ele cria os apelidos que apontam para elas
  # (`trashcan_empty`, `trashcan_full`), e um apelido para arquivo que ainda não
  # existe é apelido que não nasce.
  recolorir_lixeiras "$tam"

  # E as azuis órfãs também ANTES do passe 2, pelo mesmo motivo das lixeiras: o
  # passe 2 só pula um nome que já EXISTE no disco (`[ -e ]`), então vestir
  # depois deixaria o apelido e o arquivo disputando o mesmo nome por uma rodada.
  vestir_azuis_orfaos "$tam"

  # 2. os APELIDOS. `folder.svg`, `user-home.svg` e companhia precisam existir
  #    apontando para a versão colorida, senão a busca cai no Papirus e vem azul.
  #
  #    DOIS PASSES, porque o Papirus encadeia symlinks: `inode-directory.svg`
  #    aponta para `folder.svg`, que aponta para `folder-blue.svg`. Tratar só o
  #    primeiro nível deixaria de fora justamente o `inode-directory` — o nome
  #    genérico de diretório que os aplicativos mais pedem. Descoberto ao conferir
  #    o resultado arquivo a arquivo, não em teste superficial.
  #
  #    E O PAR DE PASSES REPETE ATÉ PARAR DE CRIAR LINK — MEDIDO EM 2026-08-04
  #    Com exatamente dois passes, a SEGUNDA execução do script ainda escrevia:
  #    seis apelidos (`folder-image` e `folder-public`, nos tamanhos 32, 48 e 64)
  #    só apareciam na TERCEIRA. A culpa é da ordem do `find`, que é a ordem do
  #    diretório e não a alfabética — no passe 2 um apelido pode depender de outro
  #    apelido que o próprio passe 2 ainda vai criar mais adiante, e nesse caso ele
  #    é pulado e fica para a próxima execução. Repetir enquanto nascer link novo
  #    faz UMA execução bastar, que é o que o auto-reparo diário precisa para não
  #    "consertar" a mesma coisa toda madrugada e avisar por nada.
  #    O teto de cinco voltas é a rede de segurança: no seco nenhum link é criado
  #    de verdade, e sem teto a pergunta "nasceu link novo?" nunca ficaria falsa.
  # (sem `local`: este laço roda no corpo do script, não dentro de função)
  apelidos_antes=$apelidos
  faltaram_antes=$faltaram
  cedidos_antes=$cedidos
  passe=""
  for volta in 1 2 3 4 5; do
    criou=0
    # Recontar do zero a cada volta: sem isto o mesmo apelido entraria na conta
    # uma vez por volta e o número impresso no fim seria ficção.
    apelidos=$apelidos_antes
    faltaram=$faltaram_antes
    cedidos=$cedidos_antes
    for passe in 1 2; do
      while IFS= read -r link; do
        nome="$(basename "$link")"
        destino_orig="$(readlink "$link")"
        equivalente=""

        # A CESSÃO, ANTES DE QUALQUER OUTRA COISA (ver o cabeçalho).
        #   Não basta não criar: o apelido mauve das rodadas anteriores JÁ ESTÁ
        #   no disco, e enquanto ele existir o GTK abre ele em vez do pastel nos
        #   tamanhos exatos. Remover é o que faz a cessão valer de fato — e é
        #   seguro porque este nome é criado por este script e por mais ninguém.
        if cedido "$nome"; then
          if [ -e "$destino/$nome" ] || [ -L "$destino/$nome" ]; then
            if meow_seco; then
              meow_muda "removeria $destino/$nome (cedido ao icones_pastas.sh)"
            else
              meow_destino_permitido "$destino/$nome" || exit "$MEOW_ERRO"
              rm -f "$destino/$nome"
              criou=1
            fi
            mudou=1
          fi
          [ "$passe" = "1" ] && cedidos=$((cedidos+1))
          continue
        fi

        if [ "$passe" = "1" ]; then
          # Nível 1: aponta direto para uma cor. folder-blue-x -> folder-<COR>-x
          # `bluegrey` casa com `folder-blue*` e NÃO é o azul padrão: ver a nota
          # no `vestir_azuis_orfaos`. Sai antes para não virar
          # `folder-cat-mocha-mauvegrey-*`, que não existe e só engordava a conta.
          case "$destino_orig" in
            folder-bluegrey*|user-bluegrey*) continue ;;
            folder-blue*|user-blue*) ;;
            *) continue ;;
          esac
          equivalente="${destino_orig/folder-blue/folder-$COR}"
          equivalente="${equivalente/user-blue/user-$COR}"
        else
          # Nível 2: aponta para um nome que o passe 1 já criou aqui. Mantém o
          # mesmo alvo — a cadeia se resolve dentro do nosso tema.
          #
          # `[ -e ]` SEGUE O LINK, e é isso que salva a cessão: um apelido que
          # apontava para um nome cedido virou link pendurado, `-e` devolve falso
          # e ele cai no conserto abaixo em vez de ficar quebrado para sempre.
          #
          [ -e "$destino/$nome" ] && continue
          if [ -e "$destino/$destino_orig" ]; then
            equivalente="$destino_orig"
          else
            # O ALVO DA CADEIA FOI CEDIDO (ou nunca existiu). Sem este ramo, os
            # 11 apelidos medidos no cabeçalho seriam abandonados aqui e cairiam
            # AZUIS, herdados do Papirus, sem ninguém acusar. `readlink -f` desce
            # a cadeia inteira lá na origem e nos dá o `folder-blue-*` do fim.
            final="$(basename "$(readlink -f "$link")")"
            case "$final" in
              folder-bluegrey*|user-bluegrey*) continue ;;
              folder-blue*|user-blue*) ;;
              *) continue ;;
            esac
            equivalente="${final/folder-blue/folder-$COR}"
            equivalente="${equivalente/user-blue/user-$COR}"
          fi
        fi
        if [ ! -e "$destino/$equivalente" ]; then
          # `faltaram` significa "herda do Papirus, provavelmente azul". Um nome
          # que o `vestir_azuis_orfaos` já recoloriu NÃO herda mais nada — contá-lo
          # aqui faria o log prometer um defeito que acabou de ser consertado.
          if [ "$passe" = "1" ] && [ -z "${VESTIDOS_AZUIS[$tam/$nome]:-}" ]; then
            faltaram=$((faltaram+1))
          fi
          continue
        fi
        if [ "$(readlink "$destino/$nome" 2>/dev/null)" != "$equivalente" ]; then
          meow_seco || ln -sfn "$equivalente" "$destino/$nome"
          mudou=1
          criou=1
        fi
        apelidos=$((apelidos+1))
      #    A BARRA NO FIM NÃO É ESTILO — SEM ELA ESTE LAÇO NÃO RODAVA EM 22 E 24
      #    `Papirus-Dark/22x22/places` e `.../24x24/places` são eles próprios
      #    SYMLINK (`-> ../../Papirus/<tam>/places`; só os 32/48/64 são diretório
      #    de verdade). E o `find`, sem `-L` e sem barra no fim, NÃO desce em
      #    diretório linkado: ele acha o link e para ali. Medido em 08/08/2026:
      #
      #      find .../22x22/places  -maxdepth 1 -type l  ->   1  (o próprio link)
      #      find .../22x22/places/ -maxdepth 1 -type l  -> 223
      #
      #    O efeito era 118 apelidos a menos em CADA um dos dois tamanhos
      #    pequenos, calados (22x22 e 24x24 tinham 0 links; 32/48/64, 118).
      #    Não era pasta azul: os dois resolvedores desta máquina varrem o tema
      #    INTEIRO antes de ir ao Papirus, então o nome ausente a 22 px era
      #    servido pelo nosso 32x32 — mauve, só com a arte do tamanho errado.
      #
      #    E NÃO SERVE TROCAR A BARRA POR `-L`: com `-L` o `find` dereferencia
      #    tudo, e aí `-type l` só casa com link PENDURADO — a busca voltaria
      #    vazia pelo motivo oposto. A barra faz o `find` dereferenciar apenas o
      #    ponto de partida, que é exatamente o que falta aqui.
      done < <(find "$BASE_DIR/$tam/places/" -maxdepth 1 -type l 2>/dev/null)
    done
    [ "$criou" = "0" ] && break
    meow_seco && break
  done
done

# `Directories=` é a única chave que a crate do COSMIC lê, e o que não estiver
# listado ali não é varrido. Sem acrescentar os `<tam>/places`, tudo acima seria
# invisível — o erro clássico de quem monta tema de ícones à mão.
#
# ISTO AQUI É SÓ O ARRANQUE — O DONO DO ÍNDICE É O `construir_icones.sh`
#   Até 2026-08-04 os dois escreviam esta linha, um com a lista fixa e outro com
#   os places, e ficavam se desfazendo para sempre (a história está comentada no
#   `construir_icones.sh`). Agora o índice é DERIVADO dos diretórios existentes,
#   lá. Este bloco só corre na primeira instalação, quando o índice foi escrito
#   antes de estes diretórios existirem: sem ele, as pastas coloridas ficariam
#   instaladas mas invisíveis até a segunda rodada. Depois disso o `grep` abaixo
#   sempre encontra os places e nada aqui volta a tocar no arquivo.
IND="$TEMA_DIR/index.theme"
if [ -f "$IND" ] && ! grep -q '48x48/places' "$IND"; then
  linha="scalable/apps"
  for tam in "${TAMANHOS[@]}"; do linha="$linha,$tam/places"; done
  if meow_seco; then
    meow_muda "acrescentaria os places ao Directories="
  else
    sed -i "s|^Directories=.*|Directories=$linha|" "$IND"
    for tam in "${TAMANHOS[@]}"; do
      grep -q "^\[$tam/places\]" "$IND" || cat >> "$IND" <<FIM

[$tam/places]
Size=${tam%%x*}
Context=Places
Type=Fixed
FIM
    done
  fi
  mudou=1
fi

# O NÚMERO DE APELIDOS É CONTADO NO DISCO, NÃO ACUMULADO NO LAÇO
#   O contador incremental mentia de dois jeitos opostos, e os dois foram medidos
#   em 08/08/2026. Somando só onde o link era criado, ele dizia **385** para um
#   disco com **590** (os de nível 2, que já existiam numa rodada convergida,
#   nunca passavam pelo incremento). Somando também no `continue`, passou a dizer
#   **975** — porque o par de passes REPETE até parar de criar link, e o mesmo
#   apelido era contado a cada volta.
#
#   Um número acumulado dentro de um laço que repete não tem como estar certo. A
#   verdade está no disco: conta-se o que ficou lá. É a mesma disciplina que o
#   `construir_icones.sh` já usa para derivar o `Directories=` — perguntar ao
#   disco, em vez de acreditar num contador.
apelidos=0
for tam in "${TAMANHOS[@]}"; do
  [ -d "$TEMA_DIR/$tam/places" ] || continue
  apelidos=$((apelidos + $(find "$TEMA_DIR/$tam/places/" -maxdepth 1 -type l 2>/dev/null | wc -l)))
done

nota_cedidos=""
[ "$cedidos" -gt 0 ] && nota_cedidos=", $cedidos cedidos"
[ "$lixeiras" -gt 0 ] && nota_cedidos="$nota_cedidos, $lixeiras lixeiras no accent"
[ "$azuis" -gt 0 ] && nota_cedidos="$nota_cedidos, $azuis órfãs azuis no accent"

if [ "$mudou" = "0" ]; then
  meow_ok "pastas $COR já no lugar ($copiados ícones, $apelidos apelidos$nota_cedidos)"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

meow_ok "pastas $COR: $copiados ícones, $apelidos apelidos cobertos"
[ "$azuis" -gt 0 ] && meow_info "$azuis pasta(s) órfã(s) do upstream recolorida(s) do azul do $BASE para o accent"
[ "$faltaram" -gt 0 ] && meow_info "$faltaram apelido(s) sem equivalente colorido — herdam do $BASE"
[ "$cedidos" -gt 0 ] && meow_info "$cedidos nome(s) cedidos ao icones_pastas.sh (pastel em scalable/places)"
exit "$MEOW_DIVERGENTE"

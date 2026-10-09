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
#   pastas fica na cor pedida enquanto a outra metade continua AZUL.
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
#   (`folder-pictures`, `folder-music`, ...) são vestidas pelo desenho do pack
#   no ar (o do Catppuccin, ou o próprio do pack que tem um), em
#   `scalable/places`, pelo `scripts/icones_pastas.sh`. Se este script
#   continuasse criando o apelido colorido no mesmo nome, haveria DOIS arquivos
#   para o mesmo ícone — e medido, os dois resolvedores discordam: a crate do COSMIC
#   abre o `scalable`, o GTK abre o tamanho exato. A mesma pasta apareceria
#   pastel a 16px e mauve a 48px dentro de um mesmo aplicativo GTK.
#
#   A cessão é a saída, no padrão do `INTOCAVEIS` do `icones_apps.sh`: a lista
#   vem de `assets/icones/pastas.map`, que é a mesma que o outro script instala — uma
#   fonte de verdade só.
#
#   MAS SÓ SE CEDE O QUE JÁ ESTÁ NO DISCO. Ceder um nome cujo desenho ainda não
#   foi instalado deixaria aquela pasta AZUL (herdada do Papirus) até a rodada
#   seguinte — pior que a cor errada, porque quebra o conjunto. Por isso o teste
#   é `[ -f scalable/places/<nome>.svg ]`, e não a mera presença no mapa: se o
#   outro script falhar, sumir ou perder o pack, este aqui volta a vestir o nome
#   na cor das outras pastas na mesma passagem, sozinho. [Dizia «cujo pastel» e
#   «de mauve» até a P65 (25/09/2026): o desenho do Catppuccin e o acento de uma
#   casa, a classe que a P62 tirou da tela.]
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
#   com `readlink -f` e aponta direto para a cor. Eles continuam na cor das
#   outras pastas.
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
# A ÁRVORE DE ONDE AS PASTAS COPIAM DESENHO É PERGUNTA AO `pack.py` — P74 item 1
#   Era `/usr/share/icons/$ICONES_BASE`, a chave crua: com o conf dizendo
#   `ICONES_BASE="MeowSystem-Icons-Base"` (a base do pack, em ~/.local/share)
#   a etapa de pastas se pulava por sete passadas do doctor (I1/I2 do 01-regressoes.md). A
#   regra de quem vence mora no `_base_escolhida`, e o `base-apelidos` diz o
#   tema (o escolhido à mão, ou o Papirus-Dark) e onde ele está no disco.
_base="$(ICONES_BASE="${ICONES_BASE:-}" NOME_TEMA_ICONES="$TEMA_NOME" \
           python3 "$RAIZ/scripts/pack.py" base-apelidos 2>/dev/null)"
BASE="$(printf '%s\n' "$_base" | sed -n 's/^tema=//p')"
[ -n "$BASE" ] || BASE="Papirus-Dark"
BASE_DIR="$(printf '%s\n' "$_base" | sed -n 's/^dir=//p')"
unset _base
COR="${ICONES_PASTAS:-cat-mocha-mauve}"
FONTE="${MEOW_CAT_FOLDERS:-$RAIZ/assets/icones/upstream/papirus-folders}"

# UM FLAVOR SEM COR NO PAPIRUS-FOLDERS CAI NO VIZINHO, E DIZ QUE CAIU — 15/09/2026
#   O valor padrão de `ICONES_PASTAS` é `cat-${FLAVOR}-${ACCENT}`, e o
#   papirus-folders traz só as 56 combinações do Catppuccin (4 flavors × 14
#   accents). Desde que o `dracula` entrou como variante, `FLAVOR="dracula"` pede
#   `cat-dracula-mauve` — que não existe.
#
#   O que acontecia: `montar_de_para` testa `[ -f "$mauve" ]` e devolve 1 quando
#   o arquivo não está lá. A função falha, o passe não pinta, e as pastas ficam
#   com a cor de fábrica SEM UMA LINHA DE AVISO. É o modo de falhar que este
#   repositório não aceita — o mesmo da leva das ferramentas que falhavam caladas.
#
#   A queda preserva o ACCENT, que é escolha à parte: quem pediu `pink` continua
#   com pink. Só o flavor troca, e para o `mocha` — o mais escuro do Catppuccin,
#   que é onde o Dracula mora. Trocar o `ICONES_PASTAS` à mão continua valendo e
#   passa direto por aqui, porque a condição é o arquivo existir, não o nome.
_cor_de_pasta_existe() { [ -f "$FONTE/src/64x64/places/folder-$1-documents.svg" ]; }

# A VARIANTE DO PACK NO AR SAI DA DO CATPPUCCIN, COR POR COR — 24/09/2026, P56
#   A queda acima deixava as pastas no Catppuccin com qualquer outro pack no ar.
#   Medido nesta máquina, com o Dracula: o `folder.svg` instalado apontava para
#   `folder-cat-mocha-mauve.svg`, de hex #CBA6F7 e #CDD6F4 (o mauve e o text do
#   Mocha) e #B792E3. A tela inteira trocava de pack, e as pastas não.
#
#   O QUE O PAPIRUS-FOLDERS PINTA, MEDIDO NAS 56 COMBINAÇÕES
#     Cada uma usa QUATRO hex, os mesmos nos cinco tamanhos. Três são slots do
#     flavor dela: o acento (a frente), o `text` e o `surface0`. Nos 42 dos três
#     escuros o papel é o `text` e o símbolo, o `surface0`; nos 14 do latte é o
#     contrário — papel #CCD0DA (o `surface0`), símbolo #4C4F69 (o `text`). O
#     quarto, a sombra de trás, NÃO é cor de paleta nenhuma: é o acento com 0x14
#     a menos em cada canal, preso em zero (o `red` do latte, #D20F39, dá
#     #BE0025). Nas 56, sem exceção.
#     [Corrigido na revisão, 24/09/2026: a primeira versão deste bloco dizia "o
#     `text` (o papel)" para as 56, e derivava todo flavor do Mocha — ver "O
#     CLARO SAI DO CLARO", logo abaixo.]
#
#   ENTÃO A TROCA É SLOT A SLOT, E A SOMBRA SEGUE O ACENTO
#     O hex que é slot do flavor de origem vira o MESMO slot do flavor pedido,
#     na paleta do pack no ar; a sombra vira o acento pedido com o mesmo
#     deslocamento que a origem mostra — lido do disco a cada passagem, e não o
#     0x14 cravado aqui. É a ideia do `scripts/derivar_acento.py` (P48): o que
#     não existe pronto sai do que existe, pela regra que a origem obedece, e
#     não de mais uma lista de variantes.
#
#   O CLARO SAI DO CLARO — 24/09/2026, na revisão da P56
#     Slot a slot só vale entre dois flavors do MESMO LADO, porque o papel de um
#     escuro é o `text` e o de um claro é o `surface0`. A primeira versão partia
#     sempre do `cat-mocha-<acento>`, e o `alucard` (o claro do Dracula) saía
#     `fill:#7126DE #4A4F67 #853AF2 #4A4F67`, papel escuro e símbolo claro, onde
#     o latte do upstream é `#7425DB #CCD0DA #8839EF #CCD0DA`. Medido com o
#     próprio `_derivar_py`, derivando do Mocha o que o upstream já traz:
#     frappe, macchiato e mocha iguais nos 5.460 arquivos de cada um; o latte,
#     diferente nos 5.460 — papel e símbolo trocados.
#     Então a origem fica do lado do pedido: o flavor que o pack no ar lista em
#     `claros` sai do primeiro `claros` do pack padrão (o latte); o escuro, do
#     Mocha da queda de 15/09. É a pergunta da P48 para escolher a árvore Light
#     ou Dark (`plano`, no `scripts/derivar_acento.py`), feita às duas paletas.
#     Derivados assim, os 56 do Catppuccin saem iguais ao upstream, byte a byte.
#
#   E PARA, EM VEZ DE PINTAR TORTO. As guardas são três:
#     · o acento de origem tem de estar nos desenhos — senão a paleta não
#       descreve este papirus-folders, e cada troca seria um chute;
#     · um hex que é dois slots na origem e duas cores no pedido não tem
#       tradução — o mesmo motivo do `DE_PARA` do `tabela_azul_mauve`, abaixo;
#     · um tom fora da paleta que não é o acento deslocado por igual é tom que
#       ninguém mediu, e derivá-lo seria inventar cor. "Por igual" vale nos
#       canais que não bateram em 0 ou 255; nos que bateram, o prendedor tem de
#       explicar o valor. Com a origem clara isso conta: o `peach`, o `sky` e o
#       `red` do latte têm um canal abaixo de 0x14, e as sombras deles ficam a
#       (20,20,11), (4,20,20) e (20,15,20) do acento.
#     Parada, a variante cai na queda de 15/09, com o motivo no log.
#
#   COM O CATPPUCCIN NO AR ISTO NÃO RODA: as 56 existem, a condição do bloco é o
#   arquivo NÃO existir, e os bytes das pastas são os de antes. O
#   `tests/pastas-do-pack.sh` confere, arquivo a arquivo, contra o upstream.
#
#   ONDE A VARIANTE MORA: num temporário apagado na saída, com o `FONTE`
#   apontando para ele. Ela é produto da passagem — sai igual byte a byte da
#   mesma origem e da mesma paleta —, e assim o passe 1, as lixeiras e as
#   órfãs azuis leem a MESMA variante, pelo caminho de sempre. No seco o
#   temporário também nasce e morre: ele não é a casa de ninguém.
#
#   AS DUAS PALETAS: a do pedido é a do pack no ar (`meow_paleta`, a porta de
#   todo consumidor); a de origem, a do pack padrão, que é o Catppuccin que o
#   papirus-folders pinta — a primeira guarda confere que é mesmo.
#
# O PAPEL E O SÍMBOLO DAS PASTAS, QUE A LIXEIRA NÃO PODE TOMAR POR ACENTO
#   São o `text`, o `surface0`, o `crust` e o `base` do Mocha, que o
#   `recolorir_lixeiras` pula ao ler os tons da pasta vizinha. Numa variante
#   derivada são os MESMOS QUATRO SLOTS, lidos no flavor pedido: sem isso a
#   lixeira do Dracula tomava o `surface0` dele (#383A4C, que o `sort` põe antes
#   do acento) por tom, e saía cinza-escura no meio das pastas roxas. Pelo nome
#   do slot, e não pelos hex do Mocha traduzidos (a primeira versão): com a
#   origem clara os hex do Mocha nem estão nos desenhos, e traduzi-los pararia a
#   derivação do `alucard` inteira.
PAPEL_DAS_PASTAS="CDD6F4|313244|11111B|1E1E2E"
SLOTS_DO_PAPEL="text|surface0|crust|base"
DERIVADA=""
ORIGEM_DERIVADA=""
MOTIVO_DERIVACAO=""

_derivar_py() {
  python3 - "$@" <<'PY'
import json, os, re, sys
(src, origem, pedida, destino, pal_origem, fl_origem,
 pal_pedida, fl_pedido, acento, papel) = sys.argv[1:11]
HEX = re.compile(r"#([0-9A-Fa-f]{6})(?![0-9A-Fa-f])")


def parar(motivo):
    print(motivo)
    sys.exit(1)


def paleta(arq, de_quem):
    """(flavors, claros) da paleta. O `claros` que não é lista conta como vazio."""
    try:
        with open(arq, encoding="utf-8") as fh:
            dados = json.load(fh)
        flavors, claros = dados.get("flavors") or {}, dados.get("claros")
    except (OSError, ValueError, AttributeError) as e:
        parar("não li a paleta %s (%s)" % (de_quem, type(e).__name__))
    return flavors, (claros if isinstance(claros, list) else [])


def cores(flavors, flavor, de_quem):
    achadas = flavors.get(flavor) if isinstance(flavors, dict) else None
    if not isinstance(achadas, dict):
        parar("a paleta %s não tem o flavor '%s'" % (de_quem, flavor))
    return {s: h.upper() for s, h in achadas.items()
            if isinstance(h, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", h)}


flavors_de, claros_de = paleta(pal_origem, "do pack padrão")
flavors_para, claros_para = paleta(pal_pedida, "do pack no ar")
# O CLARO SAI DO CLARO (o bloco lá em cima): a origem que chega é a escura.
if fl_pedido in claros_para:
    if not claros_de:
        parar("o %s é claro, e o pack padrão não tem flavor claro de onde derivá-lo"
              % fl_pedido)
    fl_origem = claros_de[0]
    origem = "cat-%s-%s" % (fl_origem, acento)
de = cores(flavors_de, fl_origem, "do pack padrão")
para = cores(flavors_para, fl_pedido, "do pack no ar")
if acento not in de or acento not in para:
    parar("'%s' não é cor do %s e do %s" % (acento, fl_origem, fl_pedido))
slots = {}
for slot, h in de.items():
    slots.setdefault(h, []).append(slot)


def rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def traduzir(h):
    if h in slots:
        alvo = {para.get(s) for s in slots[h]}
        if None in alvo or len(alvo) != 1:
            parar("%s é %s no %s, e o %s não dá uma cor só para isso"
                  % (h, "/".join(slots[h]), fl_origem, fl_pedido))
        return alvo.pop()
    # O passo sai dos canais que não bateram em 0 ou 255, e o prendedor tem de
    # explicar os que bateram (a terceira guarda, lá em cima).
    a, s = rgb(de[acento]), rgb(h)
    passo = {x - y for x, y in zip(a, s) if 0 < y < 255}
    d = passo.pop() if len(passo) == 1 else None
    if d is None or [min(max(x - d, 0), 255) for x in a] != s:
        parar("%s não é cor do %s nem o %s dele deslocado por igual, preso em 0 e 255"
              % (h, fl_origem, acento))
    return "#%02X%02X%02X" % tuple(min(max(c - d, 0), 255) for c in rgb(para[acento]))


arquivos = []
for tam in sorted(os.listdir(src)):
    pasta = os.path.join(src, tam, "places")
    if not os.path.isdir(pasta):
        continue
    for nome in sorted(os.listdir(pasta)):
        for prefixo in ("folder-", "user-"):
            cabeca = prefixo + origem
            if nome == cabeca + ".svg" or (nome.startswith(cabeca + "-") and nome.endswith(".svg")):
                arquivos.append((tam, nome, prefixo + pedida + nome[len(cabeca):]))
if not arquivos:
    parar("o papirus-folders não tem '%s'" % origem)
textos, tabela = {}, {}
for tam, nome, _novo in arquivos:
    try:
        with open(os.path.join(src, tam, "places", nome), encoding="utf-8", newline="") as fh:
            textos[(tam, nome)] = fh.read()
    except (OSError, UnicodeDecodeError) as e:
        parar("não li %s/%s (%s)" % (tam, nome, type(e).__name__))
    for m in HEX.finditer(textos[(tam, nome)]):
        h = "#" + m.group(1).upper()
        if h not in tabela:
            tabela[h] = traduzir(h)
if de[acento] not in tabela:
    parar("o %s do %s (%s) não está nos desenhos de '%s': a paleta do pack padrão "
          "não descreve este papirus-folders" % (acento, fl_origem, de[acento], origem))
for tam, nome, novo in arquivos:
    pasta = os.path.join(destino, tam, "places")
    os.makedirs(pasta, exist_ok=True)
    with open(os.path.join(pasta, novo), "w", encoding="utf-8", newline="") as fh:
        fh.write(HEX.sub(lambda m: tabela["#" + m.group(1).upper()], textos[(tam, nome)]))
# De onde saiu, e o papel no flavor pedido — `papel` são os nomes dos slots.
print(origem, "|".join(para[s][1:] for s in papel.split("|") if s in para))
PY
}

# $1 = a variante pedida · $2 = a escura do papirus-folders, de onde sai o pedido
# escuro; o claro troca de origem sozinho (ver "O CLARO SAI DO CLARO").
derivar_variante() {
  local pedida="$1" origem="$2" flavor fl_origem saida
  meow_tem python3 || { MOTIVO_DERIVACAO="sem python3, que é quem troca as cores"; return 1; }
  flavor="${pedida#cat-}"; flavor="${flavor%-*}"
  fl_origem="${origem#cat-}"; fl_origem="${fl_origem%-*}"
  DERIVADA="$(mktemp -d "${TMPDIR:-/tmp}/meow-pastas.XXXXXX")" \
    || { MOTIVO_DERIVACAO="não consegui criar o temporário"; DERIVADA=""; return 1; }
  trap 'rm -rf "${DERIVADA:-}"' EXIT
  saida="$(_derivar_py "$FONTE/src" "$origem" "$pedida" "$DERIVADA/src" \
             "$(meow_pack_padrao_dir)/paleta.json" "$fl_origem" \
             "$(meow_paleta)" "$flavor" "${pedida##*-}" "$SLOTS_DO_PAPEL")" || {
    MOTIVO_DERIVACAO="${saida:-o python3 saiu com erro}"
    rm -rf "$DERIVADA"; DERIVADA=""
    return 1
  }
  read -r ORIGEM_DERIVADA PAPEL_DAS_PASTAS <<< "$saida"
  FONTE="$DERIVADA"
}

# O MOLDE COM A VARIANTE VAZIA É O DO TEMA — 24/09/2026, na revisão da P56
#   O `ICONES_PASTAS="cat-${FLAVOR}-${ACCENT}"` de fábrica se expande quando o
#   meow.conf é lido, ANTES de o `carregar_conf` dar ao FLAVOR vazio o padrão do
#   pack. Com `FLAVOR=""` escrito à mão ele chegava aqui como `cat--mauve`, o
#   bloco de baixo procurava o flavor '' na paleta e caía no Mocha — medido com o
#   Dracula no ar, `folder.svg -> folder-cat-mocha-mauve.svg`. A variante que
#   falta é a do tema, o «Acompanha o tema» da página: o FLAVOR que chegou.
#   [P68, 25/09/2026: a regra é o `meow_pastas_do_molde` do lib/comum.sh, a
#   mesma do `carregar_conf` e do painel — esta linha era a terceira cópia dela.
#   Ele age no `ICONES_PASTAS`, e por isso roda num subshell com o `$COR`: o
#   ambiente dos filhos deste script fica como estava. Quem pergunta se o valor
#   é o molde é ele; com o FLAVOR vazio ele devolve o molde como veio, que é o
#   que a guarda daqui fazia.]
COR="$(ICONES_PASTAS="$COR"; meow_pastas_do_molde; printf '%s' "$ICONES_PASTAS")"

# A COR QUE ACOMPANHA O TEMA ACOMPANHA O LADO VESTIDO — 09/10/2026, P74 item 10
#   Com `MODO="claro"` a tela veste o claro do pack, e as pastas que «acompanham
#   o tema» (`cat-<FLAVOR>-<acento>`, o molde de fábrica) saíam na variante do
#   escuro. Só a cor que é a do FLAVOR troca para o flavor do lado vestido (o
#   `meow_flavor_vestido` do lib/comum.sh); uma escolhida à mão fica.
_fl="$(meow_flavor 2>/dev/null)"
_vestido="$(meow_flavor_vestido 2>/dev/null)"
case "$COR" in
  "cat-$_fl-"?*) [ -n "$_fl" ] && [ -n "$_vestido" ] && [ "$_vestido" != "$_fl" ] \
                   && COR="cat-$_vestido-${COR#"cat-$_fl-"}" ;;
esac
unset _fl _vestido

if [ -d "$FONTE/src/64x64/places" ] && ! _cor_de_pasta_existe "$COR"; then
  _cor_pedida="$COR"
  case "$COR" in
    cat-*-*) _cor_alt="cat-mocha-${COR##*-}" ;;
    *)       _cor_alt="cat-mocha-mauve" ;;
  esac
  _cor_de_pasta_existe "$_cor_alt" || _cor_alt="cat-mocha-mauve"
  # Só se deriva do MESMO acento: `cat-dracula-text` cai no `cat-mocha-mauve`
  # acima, e pintar o text do Dracula por cima do desenho mauve seria outra cor
  # com o nome da pedida.
  if [ "$_cor_alt" = "cat-mocha-${COR##*-}" ] && _cor_de_pasta_existe "$_cor_alt" \
     && derivar_variante "$COR" "$_cor_alt"; then
    meow_info "pastas: '$COR' não existe no papirus-folders — derivada de '$ORIGEM_DERIVADA' com a paleta do pack no ar"
  elif _cor_de_pasta_existe "$_cor_alt"; then
    [ -n "$MOTIVO_DERIVACAO" ] && meow_aviso "pastas: não deu para derivar '$_cor_pedida' — $MOTIVO_DERIVACAO"
    COR="$_cor_alt"
    meow_info "pastas: '$_cor_pedida' não existe no papirus-folders — usando '$COR'"
  else
    meow_aviso "pastas: nem '$_cor_pedida' nem '$_cor_alt' existem no papirus-folders — as pastas ficam com a cor de fábrica"
  fi
  unset _cor_pedida _cor_alt
fi

# O PAPEL QUE A LIXEIRA PULA É O DO FLAVOR DAS PASTAS — 25/09/2026, sprint P61
#   O `PAPEL_DAS_PASTAS` lá de cima é o do Mocha, e só a variante derivada o
#   trocava pelo do flavor dela. As outras 42 do papirus-folders — o latte, o
#   frappé e o macchiato — seguiam com o do Mocha, e o `recolorir_lixeiras`
#   tomava o papel ou o símbolo delas por tom. Medido com o mauve: a lixeira do
#   latte saía `#4C4F69 #7425DB` (o `text` e a sombra), e não `#7425DB #8839EF`
#   (a sombra e o acento), como a do Mocha é `#B792E3 #CBA6F7`; a do frappé,
#   `#414559 #B68AD2`; a do macchiato, `#363A4F #B28CE2`. Agora os quatro slots
#   saem do flavor da variante, pelo nome, na paleta do pack padrão — o
#   Catppuccin que o papirus-folders pinta, a de origem da derivação. No Mocha
#   são os quatro hex de sempre, e a lixeira dele não muda um byte. Sem python3,
#   ou com um flavor que a paleta não tem, fica o do Mocha, como era.
if [ -z "$DERIVADA" ] && meow_tem python3; then
  _papel="$(python3 - "$(meow_pack_padrao_dir)/paleta.json" "${COR#cat-}" "$SLOTS_DO_PAPEL" <<'PY' 2>/dev/null
import json, sys
arq, variante, slots = sys.argv[1:4]
with open(arq, encoding="utf-8") as fh:
    cores = json.load(fh)["flavors"][variante.rsplit("-", 1)[0]]
print("|".join(cores[s][1:].upper() for s in slots.split("|")))
PY
)" && [ -n "$_papel" ] && PAPEL_DAS_PASTAS="$_papel"
  unset _papel
fi

TAMANHOS=(22x22 24x24 32x32 48x48 64x64)

# --- os nomes que este script CEDE (ver o cabeçalho) -------------------------
# O MAPA É O MESMO DO `icones_pastas.sh`, pela mesma porta — P74 item 6 (I7).
#   Era o `assets/icones/pastas.map` cravado. Quando o Dracula passou a trazer o
#   mapa dele (com `folder`, `user-home` e `user-desktop`), o `icones_pastas.sh`
#   punha os três em `scalable/places` e este script, lendo o mapa do motor,
#   continuava criando os três apelidos nos tamanhos fixos — que vencem o
#   `scalable` no tamanho exato, e o desenho do pack nunca aparecia. Quem cede
#   tem de ler o mapa de quem veste.
_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
MAPA_PASTAS="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.pastas.mapa 2>/dev/null)" || MAPA_PASTAS=""
[ -n "$MAPA_PASTAS" ] || MAPA_PASTAS="$RAIZ/assets/icones/pastas.map"
unset _pack_ref
PASTEL_DIR="$TEMA_DIR/scalable/places"

declare -A CEDIDOS=()
ler_cedidos() {
  local linha nome
  [ -f "$MAPA_PASTAS" ] || return 0
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"
    [ -n "$nome" ] || continue
    # A CONDIÇÃO É O DISCO, NÃO O MAPA — ver o cabeçalho. Sem o desenho instalado
    # não se cede, e a pasta continua na cor das outras em vez de ficar azul.
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
# CORRIGE UM FATO ERRADO NO REPO: o `assets/icones/pastas.map` diz que essas duas
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
  # O modelo é uma pasta da cor pedida já instalada; sem ela não há de onde
  # tirar tom.
  modelo="$destino/folder-$COR-documents.svg"
  [ -f "$modelo" ] || return 0
  # O que se pula é o `PAPEL_DAS_PASTAS`, e não mais os quatro hex do Mocha
  # escritos aqui: numa variante derivada são os mesmos quatro slots, lidos no
  # flavor pedido (P56, lá em cima). [Até 25/09/2026, P62, dizia que eles "saem
  # traduzidos": era a primeira versão da P56, que a revisão trocou pelo slot.]
  claro="$(grep -oE '#[0-9A-Fa-f]{6}' "$modelo" | sort -u | grep -viE "#($PAPEL_DAS_PASTAS)" | head -1)"
  escuro="$(grep -oE '#[0-9A-Fa-f]{6}' "$modelo" | sort -u | grep -viE "#($PAPEL_DAS_PASTAS|${claro#\#})" | head -1)"
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
    # Um hex azul querendo duas cores diferentes na pasta pedida é sinal de que
    # o par deixou de ser o mesmo desenho. Melhor parar do que pintar torto.
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
    # Tem gêmeo na cor pedida: o laço dos apelidos resolve, e resolve melhor
    # (symlink).
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
        #   Não basta não criar: o apelido colorido das rodadas anteriores JÁ
        #   ESTÁ no disco, e enquanto ele existir o GTK abre ele em vez do
        #   desenho cedido nos tamanhos exatos. Remover é o que faz a cessão
        #   valer de fato — e é seguro porque este nome é criado por este script
        #   e por mais ninguém.
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
# O DESENHO CEDIDO É O DO PACK NO AR — 25/09/2026, sprint P62. A linha dizia
# «pastel», que é o Catppuccin; com o Dracula no ar, o que está lá são os
# desenhos dele. De quem é, diz a linha do `icones_pastas.sh`.
[ "$cedidos" -gt 0 ] && meow_info "$cedidos nome(s) cedidos ao icones_pastas.sh (o desenho dele, em scalable/places)"
exit "$MEOW_DIVERGENTE"

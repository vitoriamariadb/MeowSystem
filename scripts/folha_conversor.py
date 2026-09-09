#!/usr/bin/env python3
# folha_conversor.py — o mesmo ícone traçado de vários jeitos, lado a lado.
#
# POR QUE ESTE ARQUIVO EXISTE
#   Em 09/09/2026 ela olhou a lupa da oficina e chamou o traço de "pixelado". A
#   causa estava medida: o conversor emitia SÓ polilinha, e a escada da grade de
#   256 chegava inteira na tela. A Sprint Q trocou a gramática de saída por
#   curvas de Bézier.
#
#   Trocar a gramática muda o desenho de 24 ícones do lançador dela. A regra da
#   casa, dita em 08/08/2026 e paga caro quando foi ignorada, é que A FOLHA
#   VISUAL VEM ANTES DO CÓDIGO QUE MUDA A TELA. Então nada é instalado: esta
#   folha põe as versões na mesma linha, nos quatro fundos medidos e na lupa de
#   200 px, e ELA decide.
#
#   Este script NÃO INSTALA NADA, não escreve no repositório e não regenera o
#   acervo. Ele só lê e desenha.
#
# SÃO DUAS FOLHAS, E A SEGUNDA NÃO APAGA A PRIMEIRA — 09/09/2026, Sprint T
#   A folha original (`--escada`) responde "polilinha ou curva?", e a resposta
#   já entrou: curva é o padrão desde a Sprint Q. Ela continua aqui porque
#   `~/Documentos/meow-conversor-folha.html` ainda espera o olhar dela, e uma
#   folha que não se regenera é uma folha que envelhece sem poder ser conferida.
#
#   A folha PADRÃO agora é a da FIDELIDADE, e a pergunta dela é outra: *"sinto
#   que não tá fidedigno e a ideia é termos linhas das bordas nas nossas cores e
#   o fundo transparente"*. A segunda metade da frase já é verdade hoje (o
#   acervo sai `fill="none"`, `stroke="currentColor"`, sem fundo nenhum), então
#   o que sobra é a primeira: o desenho que sai não é o desenho que entrou.
#   Quatro colunas: o original · o traço de hoje · o traço com o peso de
#   fronteira ligado · e o glifo Arcticons DESENHADO À MÃO quando ele existe,
#   que é a terceira saída e a mais barata.
#
# POR QUE HTML STANDALONE, COM TUDO EM BASE64
#   Regra dela, de 10/08/2026: a folha é um arquivo no disco, que abre com duplo
#   clique, sem rede e sem conta. Cada figura vai embutida, então a folha
#   continua valendo depois que o acervo for reconstruído por cima — que é
#   justamente quando ela vai querer comparar o antes com o depois.
#
# POR QUE 48 E 200 PX, E POR QUE QUATRO FUNDOS
#   48 px é a caixa medida da dock (cabeçalho do `icones_apps_arcticons.sh`).
#   200 px é a lupa da oficina, que é ONDE A QUEIXA NASCEU — a 48 px a escada lê
#   como tremida, e só na lupa ela lê como serra. Os quatro fundos são os do
#   `folha_icones.py`: mocha, latte e os dois tons do vidro da dock. Um traço
#   que sobrevive no mocha e some no vidro claro não está resolvido.
#
# A COLUNA DO POTRACE FICOU DE FORA, E ISSO É MEDIÇÃO, NÃO ESQUECIMENTO
#   A Sprint Q previa uma quarta coluna com o `potrace` para responder com
#   número se valeria a pena uma dependência nova. Ele não está instalado nesta
#   máquina e o `apt` pede senha interativa (o `sudo -n -l` só libera os verbos
#   fixos da ponte do MeowSystem e do Hefesto — nenhum instala pacote). A folha
#   sai com três colunas em vez de travar a passagem por causa de 100 KB; se um
#   dia o potrace entrar, esta coluna volta.
#
# E AGORA SÃO TRÊS — 09/09/2026, a varredura da válvula
#   A terceira folha (`--valvula`) responde a uma pergunta que as duas
#   primeiras não faziam: *e se cada ícone tivesse o SEU jogo de botões?* O
#   `apps-convertidos.map` sempre teve um quarto campo para isso e ele nunca
#   foi usado — 0 de 33 linhas. A tabela `VALVULA` abaixo é o resultado de
#   girar a válvula pela primeira vez, e o cabeçalho dela conta a varredura.
#
#   As duas primeiras folhas continuam aqui porque respondem a outras
#   perguntas, e uma folha que não se regenera é uma folha que envelhece sem
#   poder ser conferida.
#
#   uso: scripts/folha_conversor.py [saida.html] [--escada|--valvula]
#        padrão:    ~/Documentos/meow-conversor-fidelidade.html  (quatro colunas)
#        --escada:  ~/Documentos/meow-conversor-folha.html       (a de 09/09)
#        --valvula: ~/Documentos/meow-valvula-33.html            (a da válvula)

import base64
import html
import json
import os
import subprocess
import sys
import tempfile

HOME = os.path.expanduser("~")
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONV = os.path.join(RAIZ, "scripts", "converter_icone.py")
MAPA = os.path.join(RAIZ, "assets", "icones", "apps-convertidos.map")
RETOQUES = os.path.join(RAIZ, "assets", "icones", "convertidos-apps", "retoques")
ARCTICONS = os.path.join(RAIZ, "assets", "icones", "arcticons-apps")
# O ACERVO É O QUE ESTÁ NA TELA DELA, E NÃO É A MESMA COISA QUE A CONVERSÃO.
#   Medido em 09/09/2026: NOVE das 24 linhas com origem chapada têm
#   `retoques/<nome>.svg`, e o `_desejado_de()` do `construir_convertidos.sh`
#   copia o retoque e NEM CHAMA o conversor. Para essas nove, a coluna "o traço
#   de hoje" desenhada a partir da origem mostra arte que ela nunca viu — o
#   Chrome do acervo tem UM subcaminho desenhado à mão, e a conversão tem oito.
#   Por isso a coluna lê o acervo primeiro e só converte quando não há arquivo.
ACERVO = os.path.join(RAIZ, "assets", "icones", "convertidos-apps")

with open(os.path.join(RAIZ, "assets", "paleta", "catppuccin.json"), encoding="utf-8") as fh:
    PALETA = json.load(fh)["flavors"]["mocha"]

# Os mesmos quatro do `folha_icones.py`, e pelo mesmo motivo.
FUNDOS = [("mocha", "#1e1e2e"), ("latte", "#eff1f5"),
          ("vidro médio", "#3C3B50"), ("vidro claro", "#826E92")]

# A espessura da dock desde 27/08/2026. Aqui ela é GRAVADA no arquivo (`--lw`)
# porque a folha precisa dos pesos na tela; no acervo ela nunca é gravada, e
# quem manda é o `TRACO` do `icones_apps_arcticons.sh`.
TRACO = "2.25"

# Os cinco que foram à folha de 11/08/2026 e PERDERAM. Entram aqui de novo
# porque a gramática mudou, e a pergunta "a curva salva algum deles?" só se
# responde olhando. A cor é `mauve` só para eles aparecerem; nenhum está no mapa.
RECUSADOS = [("firefox", "raposa orgânica — a informação está no preenchimento"),
             ("org.kde.krita", "camaleão orgânico"),
             ("thunderbird", "passarinho orgânico"),
             ("com.boxy_svg.BoxySVG", "a flor do meio virava bolha a 48 px"),
             ("btop", "fiel, e o original é o B na placa opaca de que ela reclamou")]

# Os TRÊS que a medição da Sprint T marcou, e que a folha existe para decidir.
# O texto é o veredito medido a 150 px ao lado do original, em 09/09/2026.
DESTAQUE = {
    "com.brave.Browser": "FALHA hoje: o leão vira um emaranhado. É o caso que o "
                         "peso de fronteira foi escrito para resolver — a fronteira "
                         "entre o vermelho e o vermelho escuro do escudo vale 57,9 "
                         "de contraste e custa 7 dos 10 traços.",
    "google-chrome": "FALHA hoje: as três pás viram linhas soltas que não fecham. "
                     "O peso de fronteira NÃO o alcança, e isso é medido: a "
                     "fronteira mais fraca do Chrome vale 133,4, contra 78,4 da mais "
                     "fraca do Telegram, que sai fiel. O limiar que pegasse o Chrome "
                     "apagaria as linhas de texto do Editor.",
    "com.discordapp.Discord": "ACEITÁVEL hoje: o Clyde perde o recorte do capacete, "
                              "mas se reconhece. Com o peso de fronteira sai de 9 "
                              "traços para 4, fundindo uma fronteira de 61,6.",
}

# O GLIFO ARCTICONS DE CADA UM — E ISTO NÃO É UM MAPA, É UMA LEGENDA DE FOLHA
#   O `apps-convertidos.map` de propósito NÃO tem campo `glifo`: lá a arte se
#   chama pelo nome do aplicativo, 1 para 1, e inventar o campo obrigaria os dois
#   leitores de verdade a ignorá-lo. Esta tabela vive AQUI porque é só da folha —
#   ela responde "existe um desenhado à mão para comparar?" e some quando a folha
#   some.
#
#   QUEM ESTÁ DE FORA ESTÁ DE FORA POR DECISÃO REGISTRADA, não por esquecimento;
#   o `assets/icones/PROCEDENCIA.md` (10/08/2026) mediu o índice de 15.300 nomes
#   do Arcticons e a regra dela é a de 10/08: genérico honesto pode, MARCA ALHEIA
#   não. Então:
#     · BleachBit  — `ccleaner` é outro programa; o `cleaner` do acervo não foi
#       escolhido para ele, e escolher aqui seria decidir por ela;
#     · ProtonUp-Qt — `proton` é a Proton AG (e-mail e VPN), mentiria;
#     · qBittorrent — `libretorrent` é um app específico, não um genérico;
#     · Warehouse, Apostrophe, Gradia — zero no índice;
#     · GIMP — medido em 09/09/2026: o acervo remoto não tem `gimp` (404). Para
#       ele NÃO EXISTE saída pelo desenho à mão, e é por isso que a boca do
#       Wilber é a única pergunta do conversor que não tem plano B.
GLIFO = {
    "com.brave.Browser": "brave",
    "google-chrome": "google-chrome",
    "com.discordapp.Discord": "discord",
    "org.telegram.desktop": "telegram",
    "meow-whatsapp": "whatsapp",
    "org.videolan.VLC": "vlc",
    "com.spotify.Client": "spotify",
    "steam": "steam",
    "io.github.shiftey.Desktop": "github",
    "md.obsidian.Obsidian": "obsidian",
    "org.onlyoffice.desktopeditors": "onlyoffice-documents",
    "com.obsproject.Studio": "screen-recorder",     # genérico honesto
    "vscode": "code-editor",                        # genérico honesto
    "org.gnome.Calculator": "calculator",           # genérico honesto (PROCEDENCIA)
    "org.gnome.Snapshot": "camera",                 # genérico honesto (PROCEDENCIA)
    "org.gnome.FileRoller": "zip",                  # genérico honesto (PROCEDENCIA)
    "com.github.johnfactotum.Foliate": "books",     # genérico honesto (PROCEDENCIA)
    "com.github.tchx84.Flatseal": "shield",         # genérico honesto (PROCEDENCIA)
    "firefox": "firefox",
    "org.kde.krita": "krita",
    "thunderbird": "thunderbird",
    "btop": "osmonitor",                            # a troca que ela já aprovou
    "com.boxy_svg.BoxySVG": "vector",
    "com.system76.CosmicEdit": "editor",
    "com.system76.CosmicPlayer": "player",
}

# ============================================================================
# A VÁLVULA — o quarto campo do mapa, varrido pela primeira vez em 09/09/2026
# ============================================================================
#
# O `apps-convertidos.map` sempre teve quatro campos, e o quarto — `parametros`
# — nunca foi usado: 0 de 33 linhas. O cabeçalho do `construir_convertidos.sh`
# o descreve como "a válvula para o caso raro em que um ícone pede `--k 8`".
# Esta tabela é o resultado de girar a válvula.
#
# A VARREDURA, E O QUE ELA CUSTOU
#   Grade: `--k` ∈ {4, 6, 8, 10, 12} × `--funde` ∈ {12, 25, 35, 46, 60} ×
#   `--peso-fronteira` ∈ {desligado, 70} = 50 jogos por ícone, sobre as 24
#   origens do mapa mais os 5 recusados de 11/08. 1.450 conversões, 2 min 54 s
#   de relógio em quatro processos. Uma conversão custa 0,28 s — a grade larga
#   saiu mais barata do que decidir qual estreitar.
#
# COMO OS CANDIDATOS FORAM ESCOLHIDOS, E A ARMADILHA QUE ISSO EVITA
#   As réguas (subcaminhos, tinta, sobreposição) NÃO separam "fiel" de "falha"
#   entre ícones diferentes, e isso já está medido no cabeçalho do conversor: a
#   Calculadora é fiel com 10 traços e o Brave falha com 10. Aqui elas fazem
#   OUTRA pergunta, que é legítima: *entre os 50 jogos da MESMA arte de origem,
#   qual preserva mais fronteira interna com menos traço em cima de traço?*
#   Nenhum número desta tabela compara um ícone com outro.
#
#   Peneira, na ordem: (1) não inventar linha — a precisão do traço contra as
#   fronteiras da própria origem não pode cair; (2) não perder estrutura — a
#   fração de fronteira interna coberta não pode cair; (3) ganhar alguma coisa
#   — mais estrutura, ou menos sobreposição. Quem não passa de (3) não entra, e
#   "o padrão ganha" é o resultado de 15 dos 29.
#
# E O ÚLTIMO PASSO NÃO É NÚMERO: É OLHAR A 48 PX
#   O Thunderbird provou por que. Em pixel, `--k 8` PIORA a revocação global
#   (76,8% → 89,1% só depois de contar por fronteira; contando por área ele
#   parecia pior). Olhadas as duas a 48 px, é o `--k 8` que traz de volta a aba
#   do envelope, e o padrão devolve um círculo liso. Feição pequena que carrega
#   identidade não aparece numa conta de área — o mesmo motivo pelo qual o
#   `quantizar()` do conversor prefere histograma a k-means.
#     No Foliate o olho INVERTEU a ordem da medição: `--k 8 --funde 12` cobre
#   99,8% das fronteiras internas contra 85,8% do outro, e mesmo assim a 48 px
#   ele empasta — as nervuras da folha viram hachura. O primeiro candidato é o
#   que lê na caixa da dock, não o que ganha na planilha.
#
# `hoje` é a medição do PADRÃO (nenhum parâmetro), sempre.
VALVULA = {
    # ---- os que a medição e o olho concordam em propor -------------------
    "com.github.johnfactotum.Foliate": {
        "hoje": "11 traços · 375 de comprimento · 37,1% de tinta · 5,7% sobreposto "
                "· 25,1% das fronteiras internas · precisão 60,0%",
        "cands": [
            (["--k", "8", "--funde", "35", "--peso-fronteira", "70"],
             "11 traços · 521 de comprimento · 52,7% de tinta · 0,0% sobreposto "
             "· 85,8% das fronteiras internas · precisão 100,0%",
             "as linhas de texto das duas páginas voltam, e a folha vira um "
             "contorno limpo. É o que lê melhor na caixa de 48 px."),
            (["--k", "8", "--funde", "12"],
             "14 traços · 641 de comprimento · 58,5% de tinta · 5,0% sobreposto "
             "· 99,8% das fronteiras internas · precisão 100,0%",
             "cobre quase toda fronteira da origem — inclusive as nervuras da "
             "folha —, e a 48 px elas empastam. Ganha na conta, perde no olho."),
        ],
        "veredito": "o maior achado da varredura: o traço de hoje cobre só 25% "
                    "das fronteiras internas do desenho e inventa linha (precisão "
                    "60%). É o pior número de fidelidade dos 29 medidos.",
    },
    # A CHAVE JÁ EXISTIA, E A VÁLVULA É O QUE A TORNA USÁVEL — 09/09/2026
    #   Medido: `--peso-fronteira` SOZINHO muda exatamente QUATRO das 15 linhas
    #   que a válvula alcança (OnlyOffice, Brave, Discord, BleachBit) e deixa as
    #   outras onze byte a byte iguais. Nessas quatro ele chega a menos de 1
    #   ponto do melhor jogo de dois parâmetros que a grade de 50 achou.
    #   Então o candidato 1 delas é a chave que a Sprint T já escreveu e que o
    #   `tests/conversor.sh` já guarda — não um jogo novo. O que a válvula
    #   acrescenta não é o botão: é poder LIGÁ-LO EM QUATRO ÍCONES sem ligá-lo
    #   nos outros, que é justamente por que ele nasceu desligado.
    #   `--peso-fronteira` sem número usa o vale medido (LIMIAR_FRACA = 70) —
    #   conferido: a saída é byte a byte a de `--peso-fronteira 70`.
    "com.brave.Browser": {
        "hoje": "10 traços · 366 de comprimento · 29,5% de tinta · 17,5% sobreposto "
                "· 99,0% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--peso-fronteira"],
             "3 traços · 314 de comprimento · 28,9% de tinta · 5,1% sobreposto "
             "· 99,8% das fronteiras internas · precisão 100,0%",
             "o focinho sai do emaranhado: a linha dupla que corria dentro da "
             "cara vira uma só, e a juba continua inteira. É a chave que já "
             "está escrita e testada — aqui ela é ligada só neste ícone."),
            (["--funde", "60"],
             "3 traços · 315 de comprimento · 29,0% de tinta · 4,4% sobreposto "
             "· 100,0% das fronteiras internas · precisão 100,0%",
             "o mesmo desenho por outro caminho, com 0,7 ponto menos de "
             "sobreposição. Está aqui para mostrar que o resultado não depende "
             "de uma chave só."),
        ],
        "veredito": "o Brave estava dado como falha estrutural, e a varredura "
                    "discorda em parte: 17,5% de sobreposição (o pior das 29 "
                    "conversões, acima do pior desenho à mão) caem para 5,1%.",
    },
    "com.discordapp.Discord": {
        "hoje": "9 traços · 287 de comprimento · 25,2% de tinta · 8,7% sobreposto "
                "· 99,2% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--peso-fronteira"],
             "4 traços · 257 de comprimento · 24,3% de tinta · 0,4% sobreposto "
             "· 99,3% das fronteiras internas · precisão 100,0%",
             "a linha dupla no alto da cabeça do Clyde vira uma só; o desenho é "
             "o mesmo com menos da metade dos subcaminhos."),
            (["--k", "8", "--funde", "12", "--peso-fronteira", "70"],
             "4 traços · 257 de comprimento · 24,5% de tinta · 0,3% sobreposto "
             "· 99,5% das fronteiras internas · precisão 100,0%",
             "o melhor da grade de 50, e é indistinguível do candidato 1 a "
             "48 px: 0,1 ponto de diferença."),
        ],
        "veredito": "o Discord era 'aceitável' hoje; os dois candidatos tiram o "
                    "traço empilhado sem tirar desenho nenhum.",
    },
    "org.bleachbit.BleachBit": {
        "hoje": "7 traços · 195 de comprimento · 15,0% de tinta · 23,5% sobreposto "
                "· 100,0% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--peso-fronteira"],
             "2 traços · 146 de comprimento · 13,8% de tinta · 4,0% sobreposto "
             "· 100,0% das fronteiras internas · precisão 100,0%",
             "mesmo desenho, sem a linha da virola desenhada duas vezes e sem o "
             "cisco na base das cerdas."),
            (["--k", "8", "--peso-fronteira", "70"],
             "2 traços · 146 de comprimento · 13,7% de tinta · 3,5% sobreposto "
             "· 100,0% das fronteiras internas · precisão 100,0%",
             "meio ponto a menos de sobreposição, e nada mais."),
        ],
        "veredito": "a vassoura tem a MAIOR sobreposição do acervo depois do "
                    "Brave (23,5%) e nenhuma fronteira a perder — é o caso mais "
                    "limpo de 'mesma arte, menos tinta empilhada'.",
    },
    "md.obsidian.Obsidian": {
        "hoje": "2 traços · 149 de comprimento · 14,3% de tinta · 0,0% sobreposto "
                "· 70,1% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--k", "4", "--funde", "12"],
             "3 traços · 180 de comprimento · 15,8% de tinta · 10,6% sobreposto "
             "· 82,4% das fronteiras internas · precisão 100,0%",
             "a aresta central da pedra aparece, e a forma passa a ler como "
             "gema lapidada em vez de seixo. Custa 10,6% de sobreposição."),
        ],
        "veredito": "o único caso da leva em que ganhar estrutura CUSTA "
                    "sobreposição — os outros ganham as duas coisas juntas.",
    },
    "vscode": {
        "hoje": "4 traços · 230 de comprimento · 22,9% de tinta · 0,0% sobreposto "
                "· 84,0% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--k", "10", "--funde", "35", "--peso-fronteira", "70"],
             "5 traços · 234 de comprimento · 22,8% de tinta · 0,6% sobreposto "
             "· 88,0% das fronteiras internas · precisão 100,0%",
             "a dobra diagonal da fita volta; hoje sai uma barra vertical no "
             "lugar dela."),
            (["--k", "10", "--funde", "35"],
             "5 traços · 245 de comprimento · 23,1% de tinta · 4,0% sobreposto "
             "· 88,0% das fronteiras internas · precisão 100,0%",
             "o mesmo desenho sem o peso de fronteira, e com mais traço em "
             "cima de traço."),
        ],
        "veredito": "ganho pequeno e verdadeiro: a fita do VS Code é uma dobra, "
                    "e hoje ela não está desenhada.",
    },
    # ---- mesma arte na tela, só menos tinta empilhada --------------------
    "net.davidotek.pupgui2": {
        "hoje": "4 traços · 308 de comprimento · 29,2% de tinta · 12,7% sobreposto "
                "· 99,5% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--funde", "12", "--peso-fronteira", "70"],
             "4 traços · 309 de comprimento · 29,2% de tinta · 3,2% sobreposto "
             "· 99,8% das fronteiras internas · precisão 100,0%",
             "a 48 px é indistinguível do de hoje — o ganho é margem para o "
             "traço engrossar sem borrar, não desenho novo."),
        ],
        "veredito": "o desenho não muda; só a sobreposição.",
    },
    "org.onlyoffice.desktopeditors": {
        "hoje": "5 traços · 271 de comprimento · 22,4% de tinta · 16,2% sobreposto "
                "· 100,0% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--peso-fronteira"],
             "3 traços · 217 de comprimento · 20,5% de tinta · 3,1% sobreposto "
             "· 98,8% das fronteiras internas · precisão 100,0%",
             "as três folhas empilhadas param de ter a borda desenhada duas "
             "vezes. O 1,2 ponto de fronteira que a conta diz que sumiu não "
             "aparece a 48 px — foram as bordas coincidentes que viraram uma."),
            (["--k", "8", "--funde", "12", "--peso-fronteira", "70"],
             "6 traços · 270 de comprimento · 22,8% de tinta · 14,2% sobreposto "
             "· 100,0% das fronteiras internas · precisão 100,0%",
             "guarda os 100% de fronteira e quase toda a sobreposição junto: "
             "é o candidato conservador."),
        ],
        "veredito": "o único caso da leva em que a peneira automática errou "
                    "por pouco — ela cortou o candidato 1 por 1,2 ponto de "
                    "fronteira, e a 48 px não há nada perdido para ver.",
    },
    "org.qbittorrent.qBittorrent": {
        "hoje": "5 traços · 323 de comprimento · 32,8% de tinta · 7,8% sobreposto "
                "· 98,8% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--k", "4", "--funde", "12"],
             "12 traços · 315 de comprimento · 32,8% de tinta · 6,1% sobreposto "
             "· 99,3% das fronteiras internas · precisão 100,0%",
             "o mesmo desenho partido em doze subcaminhos em vez de cinco."),
        ],
        "veredito": "o padrão ganha — mais que o dobro de subcaminhos pelo "
                    "mesmo desenho.",
    },
    # ---- o retoque à mão vence, e a válvula não chega lá -----------------
    "com.obsproject.Studio": {
        "hoje": "4 traços · 404 de comprimento · 35,0% de tinta · 11,7% sobreposto "
                "· 99,7% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--k", "4", "--funde", "12"],
             "4 traços · 404 de comprimento · 35,3% de tinta · 10,3% sobreposto "
             "· 99,7% das fronteiras internas · precisão 100,0%",
             "1,4 ponto de sobreposição a menos, e nada mais."),
        ],
        "veredito": "o padrão ganha, e além disso a válvula seria INERTE aqui: "
                    "existe `retoques/com.obsproject.Studio.svg`.",
    },
    "steam": {
        "hoje": "5 traços · 319 de comprimento · 29,5% de tinta · 6,0% sobreposto "
                "· 99,6% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--k", "4", "--funde", "35", "--peso-fronteira", "70"],
             "5 traços · 318 de comprimento · 29,3% de tinta · 4,7% sobreposto "
             "· 99,8% das fronteiras internas · precisão 100,0%",
             "indistinguível a 48 px."),
        ],
        "veredito": "o padrão ganha, e a válvula é INERTE: existe "
                    "`retoques/steam.svg`.",
    },
    "org.telegram.desktop": {
        "hoje": "4 traços · 260 de comprimento · 22,6% de tinta · 11,4% sobreposto "
                "· 100,0% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--k", "8", "--peso-fronteira", "70"],
             "2 traços · 225 de comprimento · 21,7% de tinta · 0,8% sobreposto "
             "· 99,7% das fronteiras internas · precisão 100,0%",
             "a dobra da asa do aviãozinho deixa de ser desenhada duas vezes."),
        ],
        "veredito": "o Telegram é uma das TRÊS TRAVAS da Sprint T e tem retoque "
                    "à mão: a válvula é inerte aqui, e a linha não se mexe.",
    },
    "com.spotify.Client": {
        "hoje": "9 traços · 430 de comprimento · 33,0% de tinta · 22,3% sobreposto "
                "· 100,0% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--funde", "12", "--peso-fronteira", "70"],
             "4 traços · 296 de comprimento · 29,1% de tinta · 0,0% sobreposto "
             "· 99,9% das fronteiras internas · precisão 100,0%",
             "as três ondas viram três traços em vez de três contornos "
             "fechados — zero sobreposição."),
        ],
        "veredito": "o ganho é grande e a válvula é INERTE: existe "
                    "`retoques/com.spotify.Client.svg`, e é ele que está na "
                    "sua tela.",
    },
    "io.github.flattool.Warehouse": {
        "hoje": "11 traços · 478 de comprimento · 47,1% de tinta · 4,7% sobreposto "
                "· 90,4% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--k", "10", "--funde", "35"],
             "13 traços · 510 de comprimento · 50,6% de tinta · 1,5% sobreposto "
             "· 97,6% das fronteiras internas · precisão 100,0%",
             "as abas das caixas aparecem — e a 48 px a prateleira fica cheia."),
        ],
        "veredito": "válvula INERTE: existe `retoques/io.github.flattool."
                    "Warehouse.svg`.",
    },
    "google-chrome": {
        "hoje": "8 traços · 278 de comprimento · 24,5% de tinta · 7,1% sobreposto "
                "· 73,2% das fronteiras internas · precisão 91,0%",
        "cands": [
            (["--k", "4", "--funde", "12"],
             "4 traços · 274 de comprimento · 26,4% de tinta · 0,3% sobreposto "
             "· 91,2% das fronteiras internas · precisão 100,0%",
             "o miolo azul deixa de sair serrilhado — e as três pás continuam "
             "sem fechar. O ícone não passa a ler como Chrome."),
            (["--k", "12", "--funde", "12"],
             "9 traços · 288 de comprimento · 25,0% de tinta · 8,8% sobreposto "
             "· 76,3% das fronteiras internas · precisão 92,0%",
             "praticamente o de hoje."),
        ],
        "veredito": "os 50 jogos MUDAM o desenho do Chrome (o que estava "
                    "escrito é que não mudavam), e mesmo assim nenhum o faz "
                    "ler. Ele já tem retoque à mão, e a válvula é inerte.",
    },
    # ---- o padrão ganha, sem candidato ----------------------------------
    "meow-whatsapp": {
        "hoje": "2 traços · 207 de comprimento · 20,6% de tinta · 0,1% sobreposto "
                "· 99,4% das fronteiras internas · precisão 100,0%",
        "cands": [], "veredito": "o padrão ganha: 99,4% de fronteira coberta e "
                                 "0,1% de sobreposição não deixam o que melhorar.",
    },
    "org.videolan.VLC": {
        "hoje": "5 traços · 232 de comprimento · 21,7% de tinta · 3,2% sobreposto "
                "· 100,0% das fronteiras internas · precisão 100,0%",
        "cands": [], "veredito": "TRAVA da Sprint T, e o padrão ganha: cobertura "
                                 "de fronteira em 100%. Nenhum dos 49 jogos passou.",
    },
    "org.gnome.Calculator": {
        "hoje": "10 traços · 360 de comprimento · 33,8% de tinta · 0,0% sobreposto "
                "· 98,7% das fronteiras internas · precisão 100,0%",
        "cands": [], "veredito": "TRAVA da Sprint T, e o padrão ganha: a mais "
                                 "carregada de todas é a que menos sobrepõe.",
    },
    "io.github.shiftey.Desktop": {
        "hoje": "2 traços · 247 de comprimento · 23,2% de tinta · 0,0% sobreposto "
                "· 98,6% das fronteiras internas · precisão 100,0%",
        "cands": [], "veredito": "o padrão ganha.",
    },
    "org.gimp.GIMP": {
        "hoje": "6 traços · 255 de comprimento · 23,4% de tinta · 3,1% sobreposto "
                "· 85,4% das fronteiras internas · precisão 100,0%",
        "cands": [], "veredito": "o padrão ganha entre os 50, e os 14,6% de "
                                 "fronteira que faltam são a BOCA — o LEIA-ME do "
                                 "retoque já provou que nenhum parâmetro a traz.",
    },
    "org.gnome.gitlab.somas.Apostrophe": {
        "hoje": "13 traços · 433 de comprimento · 44,1% de tinta · 0,0% sobreposto "
                "· 78,8% das fronteiras internas · precisão 100,0%",
        "cands": [], "veredito": "o padrão ganha. Falta a tecla laranja, e "
                                 "nenhum dos 49 jogos a devolve sem quebrar o "
                                 "resto do teclado.",
    },
    "org.gnome.Snapshot": {
        "hoje": "6 traços · 442 de comprimento · 42,7% de tinta · 0,0% sobreposto "
                "· 80,0% das fronteiras internas · precisão 100,0%",
        "cands": [], "veredito": "o padrão ganha, e a válvula seria inerte "
                                 "(existe retoque à mão).",
    },
    "com.github.tchx84.Flatseal": {
        "hoje": "5 traços · 320 de comprimento · 29,5% de tinta · 3,0% sobreposto "
                "· 97,3% das fronteiras internas · precisão 100,0%",
        "cands": [], "veredito": "o padrão ganha, e a válvula seria inerte "
                                 "(existe retoque à mão).",
    },
    "org.gnome.FileRoller": {
        "hoje": "7 traços · 294 de comprimento · 24,4% de tinta · 8,0% sobreposto "
                "· 85,4% das fronteiras internas · precisão 100,0%",
        "cands": [], "veredito": "o padrão ganha.",
    },
    # ---- os cinco recusados de 11/08, fora do mapa -----------------------
    "thunderbird": {
        "hoje": "7 traços · 332 de comprimento · 27,9% de tinta · 11,4% sobreposto "
                "· 76,8% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--k", "8"],
             "9 traços · 405 de comprimento · 31,3% de tinta · 19,5% sobreposto "
             "· 89,1% das fronteiras internas · precisão 100,0%",
             "a ABA do envelope (o ∨) volta. O padrão devolve um círculo liso "
             "no meio do passarinho."),
        ],
        "veredito": "o caso que motivou a varredura — e `--k 8` SOZINHO basta, "
                    "sem mexer no `--funde`. Está fora do mapa desde 11/08 "
                    "porque o Arcticons tem `thunderbird` desenhado à mão.",
    },
    "firefox": {
        "hoje": "5 traços · 338 de comprimento · 30,3% de tinta · 7,7% sobreposto "
                "· 86,4% das fronteiras internas · precisão 87,8%",
        "cands": [
            (["--k", "10", "--funde", "12", "--peso-fronteira", "70"],
             "5 traços · 355 de comprimento · 31,5% de tinta · 9,5% sobreposto "
             "· 96,7% das fronteiras internas · precisão 100,0%",
             "para de inventar linha (precisão 87,8% → 100%), e continua sem "
             "ler como raposa."),
        ],
        "veredito": "fora do mapa. A varredura melhora o número e não resolve o "
                    "caso: a informação está no preenchimento.",
    },
    "btop": {
        "hoje": "4 traços · 296 de comprimento · 27,9% de tinta · 0,0% sobreposto "
                "· 90,3% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--k", "4", "--funde", "12"],
             "10 traços · 317 de comprimento · 28,7% de tinta · 2,3% sobreposto "
             "· 98,1% das fronteiras internas · precisão 100,0%",
             "a barra do meio do B aparece."),
        ],
        "veredito": "fora do mapa por decisão sua: o Arcticons `osmonitor` já "
                    "tinha ganhado do B na placa opaca.",
    },
    "com.boxy_svg.BoxySVG": {
        "hoje": "7 traços · 420 de comprimento · 37,6% de tinta · 11,1% sobreposto "
                "· 96,1% das fronteiras internas · precisão 100,0%",
        "cands": [
            (["--k", "8", "--funde", "12"],
             "8 traços · 406 de comprimento · 37,7% de tinta · 7,5% sobreposto "
             "· 98,4% das fronteiras internas · precisão 100,0%",
             "menos traço empilhado; a flor do meio continua virando bolha."),
        ],
        "veredito": "fora do mapa.",
    },
    "org.kde.krita": {
        "hoje": "8 traços · 329 de comprimento · 29,4% de tinta · 8,3% sobreposto "
                "· 99,6% das fronteiras internas · precisão 100,0%",
        "cands": [], "veredito": "fora do mapa, e o padrão ganha entre os 50.",
    },
}

# AS COLUNAS SÃO DADO, NÃO CÓDIGO REPETIDO — e é o que deixa as três folhas
# saírem do mesmo laço. Cada coluna é (título, receita), e a receita é:
#   "origem"     -> o arquivo de entrada, como está;
#   "acervo"     -> o que está NA TELA dela hoje (o retoque, se houver);
#   "arcticons"  -> o glifo desenhado à mão, quando existe;
#   "cand1"/"cand2" -> o candidato N da `VALVULA` daquele ícone;
#   [chaves]     -> roda o conversor com essas chaves.
COLUNAS = {
    "fidelidade": [
        ("original", "origem"),
        ("o traço de hoje", []),
        ("com peso de fronteira", ["--peso-fronteira"]),
        ("o desenhado à mão", "arcticons"),
    ],
    "escada": [
        ("original", "origem"),
        ("polilinha (hoje)", ["--polilinha"]),
        ("curvas (proposta)", []),
    ],
    "valvula": [
        ("original", "origem"),
        ("o traço de hoje", "acervo"),
        ("candidato 1", "cand1"),
        ("candidato 2", "cand2"),
        ("o desenhado à mão", "arcticons"),
    ],
}


def ler_mapa():
    """(nome, origem, cor, extra) por linha viva do mapa. `mao` sai à parte."""
    com_origem, na_mao = [], []
    with open(MAPA, encoding="utf-8") as fh:
        for linha in fh:
            linha = linha.strip()
            if not linha or linha.startswith("#"):
                continue
            partes = linha.split(":")
            if len(partes) < 3:
                continue
            nome, origem, cor = partes[0], partes[1], partes[2]
            extra = partes[3] if len(partes) > 3 else ""
            if origem == "mao":
                na_mao.append((nome, cor))
                continue
            if not origem.startswith("/"):
                origem = os.path.join(RAIZ, origem)
            com_origem.append((nome, origem, cor, extra))
    return com_origem, na_mao


def converter(origem, cor, *chaves):
    """Roda o conversor e devolve (svg_colorido, metricas, frase_do_stderr).

    O `currentColor` vira hex AQUI e só aqui: a folha é um `.html` fora do
    repositório, então cor literal é permitida — a mesma licença que a
    `folha_icones.py` já usa. O que sai do conversor continua sem cor nenhuma.
    """
    with tempfile.NamedTemporaryFile(suffix=".svg", delete=False) as f:
        saida = f.name
    try:
        r = subprocess.run(
            [sys.executable, CONV, origem, saida, "--lw", TRACO, "--json", *chaves],
            capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            return None, None, (r.stderr or "").strip()[:160]
        with open(saida, encoding="utf-8") as fh:
            svg = fh.read()
        m = json.loads(r.stdout) if r.stdout.strip() else {}
        frase = (r.stderr or "").strip().split(": ", 1)[-1]
        return svg.replace("currentColor", PALETA.get(cor, "#cdd6f4")), m, frase
    except (OSError, subprocess.SubprocessError, ValueError) as e:
        return None, None, str(e)[:160]
    finally:
        if os.path.exists(saida):
            os.unlink(saida)


def embute_texto(texto):
    return "data:image/svg+xml;base64," + base64.b64encode(texto.encode()).decode()


def embute_arquivo(caminho):
    ext = os.path.splitext(caminho)[1].lower()
    tipo = {".svg": "image/svg+xml", ".png": "image/png"}.get(ext, "image/jpeg")
    with open(caminho, "rb") as fh:
        return "data:%s;base64," % tipo + base64.b64encode(fh.read()).decode()


def celula(uri, nota="", params=None, medida=""):
    """Uma coluna: os quatro fundos a 48 px, a lupa de 200 px, e o rodapé.

    O RODAPÉ TEM TRÊS LINHAS DE PROPÓSITO, e a ordem importa: os PARÂMETROS
    EXATOS primeiro (é o que ela vai me mandar aplicar), a MEDIÇÃO depois (é o
    que sustenta a proposta) e a prosa por último. Sem os parâmetros escritos
    embaixo da figura, a folha vira "gostei do terceiro" e ninguém sabe qual
    linha do mapa escrever.
    """
    if uri is None:
        return '<td class="vazia">%s</td>' % html.escape(nota or "não saiu")
    fundos = "".join(
        '<span style="background:%s" title="%s"><img src="%s" width="48" height="48"></span>'
        % (hexa, html.escape(nome), uri) for nome, hexa in FUNDOS)
    rodape = ""
    if params is not None:
        rodape += '<code class="param">%s</code>' % html.escape(
            params or "(padrão — nenhum parâmetro)")
    if medida:
        rodape += '<div class="medida">%s</div>' % html.escape(medida)
    if nota:
        rodape += '<div class="nota">%s</div>' % html.escape(nota)
    return ('<td><div class="quatro">%s</div>'
            '<img class="lupa" src="%s" width="200" height="200">%s</td>'
            % (fundos, uri, rodape))


CSS = """
body { margin:0; padding:24px; background:#181825; color:#cdd6f4;
       font:14px/1.55 -apple-system,Segoe UI,Cantarell,sans-serif; }
h1 { font-size:22px; margin:0 0 6px; color:#f5c2e7; font-weight:600; }
h2 { font-size:17px; margin:34px 0 10px; color:#89b4fa; font-weight:600; }
p.intro { max-width:74ch; color:#a6adc8; margin:0 0 4px; }
table { border-collapse:collapse; margin-top:14px; }
th { text-align:left; font-size:12px; text-transform:uppercase; letter-spacing:.06em;
     color:#9399b2; font-weight:600; padding:8px 12px; border-bottom:1px solid #313244; }
td { vertical-align:top; padding:14px 12px; border-bottom:1px solid #313244; }
td.nome { min-width:190px; }
td.nome b { color:#cdd6f4; font-weight:600; }
td.nome code { display:block; font-size:11px; color:#7f849c; margin-top:5px;
               word-break:break-all; line-height:1.4; }
td.vazia { color:#f38ba8; font-size:12px; }
/* OS QUATRO FUNDOS TÊM DE FICAR NUMA LINHA SÓ. Com `inline-block` eles cabiam
   em 260 px e a célula media 224 (a lupa manda na largura), então o quarto
   fundo — o vidro claro, justamente o que mais derruba traço fino — caía numa
   segunda linha e lia como um quinto ícone solto. `flex` não quebra. */
.quatro { display:flex; gap:4px; }
.quatro span { display:inline-block; padding:5px; border-radius:8px; }
.lupa { display:block; margin-top:9px; background:#1e1e2e; border-radius:12px; }
.nota { font-size:11px; color:#7f849c; margin-top:6px; max-width:216px; }
code.param { display:block; max-width:216px; margin-top:8px; padding:4px 7px;
             border-radius:5px; background:#11111b; color:#a6e3a1; font-size:11px;
             line-height:1.45; word-break:break-word; }
.medida { font-size:11px; color:#9399b2; margin-top:5px; max-width:216px;
          line-height:1.45; }
.veredito { font-size:11px; color:#f9e2af; margin-top:8px; line-height:1.45; }
.pastilha { display:inline-block; padding:1px 8px; border-radius:999px; font-size:11px;
            background:#313244; color:#bac2de; margin-top:5px; }
.aviso { background:#313244; border-left:3px solid #f9e2af; padding:10px 14px;
         border-radius:6px; max-width:74ch; margin:16px 0; color:#bac2de; font-size:13px; }
"""


def glifo_de(nome):
    """O SVG do glifo Arcticons desenhado à mão, já vestido, ou None.

    A espessura é INJETADA aqui pelo mesmo motivo que no resto da folha: os 39
    Arcticons não gravam `stroke-width` (é o dialeto), e sem o atributo o
    navegador desenha a 1,0 — o glifo apareceria fino ao lado das conversões e a
    comparação mentiria sobre a única coisa que ela está olhando, que é o traço.
    """
    g = GLIFO.get(nome)
    if not g:
        return None
    arq = os.path.join(ARCTICONS, g + ".svg")
    if not os.path.exists(arq):
        return None
    with open(arq, encoding="utf-8") as fh:
        texto = fh.read()
    if "stroke-width" not in texto:
        texto = texto.replace("<path ", '<path stroke-width="%s" ' % TRACO)
        for f in ("circle", "rect", "line", "polyline", "polygon", "ellipse"):
            texto = texto.replace("<%s " % f, '<%s stroke-width="%s" ' % (f, TRACO))
    return texto, g


def linha_de(nome, origem, cor, extra, colunas, motivo=""):
    """Uma linha da tabela, uma célula por coluna de `colunas`.

    A NOTA DA COLUNA DO PESO DE FRONTEIRA DIZ "IDÊNTICO" QUANDO É IDÊNTICO, e
    essa é a informação que ela mais usa: em 26 dos 34 ícones medidos a chave
    não muda um byte, e ler "idêntico ao de hoje" poupa comparar duas figuras
    iguais com a lupa. Onde muda, a nota traz os contrastes que sumiram.
    """
    chaves_extra = extra.split() if extra else []
    dados = VALVULA.get(nome, {})
    ident = ('<td class="nome"><b>%s</b><span class="pastilha">%s</span>'
             '<code>%s</code>%s%s</td>'
             % (html.escape(nome), html.escape(cor), html.escape(origem),
                ('<code>%s</code>' % html.escape(motivo)) if motivo else "",
                ('<div class="veredito">%s</div>' % html.escape(dados["veredito"]))
                if dados.get("veredito") else ""))
    celulas, base = [], None
    for titulo, receita in colunas:
        if receita == "origem":
            try:
                celulas.append(celula(embute_arquivo(origem), "a arte de fábrica, como está"))
            except OSError as e:
                celulas.append('<td class="vazia">%s</td>' % html.escape(str(e)[:80]))
            continue
        # O QUE ESTÁ NA TELA DELA, E NÃO O QUE O CONVERSOR DEVOLVERIA HOJE.
        #   Para nove dos 24, `convertidos-apps/<nome>.svg` é a CÓPIA de um
        #   retoque à mão, não a conversão — o `_desejado_de()` copia o retoque
        #   e nem chama o conversor. Desenhar a conversão nesta coluna e chamar
        #   de "hoje" mostraria a ela arte que ela nunca viu.
        if receita == "acervo":
            arq = os.path.join(ACERVO, nome + ".svg")
            hoje = dados.get("hoje", "")
            if not os.path.exists(arq):
                svg, m, frase = converter(origem, cor, *chaves_extra)
                celulas.append(celula(embute_texto(svg) if svg else None,
                                      "não há arquivo no acervo",
                                      params="(padrão — nenhum parâmetro)",
                                      medida=hoje))
                continue
            with open(arq, encoding="utf-8") as fh:
                texto = fh.read()
            if os.path.exists(os.path.join(RETOQUES, nome + ".svg")):
                # A FIGURA É O RETOQUE E OS NÚMEROS SÃO DA CONVERSÃO — dizer
                # isso é obrigatório. Pôr a medição da conversão embaixo de um
                # desenho feito à mão faria a folha mentir sobre a única coisa
                # que ela existe para mostrar.
                params = "(desenho à mão — o conversor nem chega a ser chamado)"
                medida = "%d subcaminho(s), desenhados à mão" % texto.count("<path")
                marca = ("convertidos-apps/%s.svg é um RETOQUE À MÃO. As duas "
                         "colunas ao lado mostram o que a CONVERSÃO faria se "
                         "ele não existisse; hoje ela daria %s" % (nome, hoje))
            else:
                # O ACERVO É PRÉ-SPRINT-Q, E ISSO PRECISA ESTAR ESCRITO.
                #   Medido em 09/09/2026 nos 15: a 48 px o arquivo do acervo e
                #   a conversão de hoje são IDÊNTICOS pixel a pixel (0 de
                #   2.304); a 200 px diferem de 141 a 508 de 40.000. A
                #   diferença é a escada que a Sprint Q tirou e que o acervo
                #   ainda não recebeu — `chk_convertidos` acusa os 15 como
                #   "desatualizados" de propósito, esperando o sim dela. Sem
                #   esta frase, ela olharia a lupa e daria à VÁLVULA um ganho
                #   que é da troca de gramática.
                params = "(padrão — nenhum parâmetro)"
                medida = hoje
                marca = ("convertidos-apps/%s.svg — a 48 px é idêntico, pixel "
                         "a pixel, ao que o conversor daria hoje. Só na lupa "
                         "de 200 px aparece a escada anterior à troca por "
                         "curvas: o acervo ainda não foi regerado." % nome)
            if "stroke-width" not in texto:
                texto = texto.replace("<path ", '<path stroke-width="%s" ' % TRACO)
            celulas.append(celula(
                embute_texto(texto.replace("currentColor", PALETA.get(cor, "#cdd6f4"))),
                marca, params=params, medida=medida))
            continue
        if receita in ("cand1", "cand2"):
            i = 0 if receita == "cand1" else 1
            cands = dados.get("cands", [])
            if i >= len(cands):
                celulas.append('<td class="vazia">%s</td>' % html.escape(
                    "nenhum segundo candidato" if i else
                    "nenhum jogo de parâmetro passou do critério — o padrão ganha"))
                continue
            chaves, medida, porque = cands[i]
            svg, m, frase = converter(origem, cor, *chaves)
            celulas.append(celula(embute_texto(svg) if svg else None, porque,
                                  params=" ".join(chaves), medida=medida))
            continue
        if receita == "arcticons":
            g = glifo_de(nome)
            if g is None:
                celulas.append('<td class="vazia">não há glifo desenhado à mão '
                               'para este — ver a legenda no topo</td>')
            else:
                texto, gn = g
                celulas.append(celula(
                    embute_texto(texto.replace("currentColor", PALETA.get(cor, "#cdd6f4"))),
                    "arcticons-apps/%s.svg — desenhado à mão" % gn))
            continue
        svg, m, frase = converter(origem, cor, *(receita + chaves_extra))
        if svg and base is None and not receita:
            base = svg                       # a coluna "hoje" é a régua da nota
        nota = frase
        if svg and base is not None and receita and svg == base:
            nota = "idêntico ao de hoje — a chave não achou fronteira fraca aqui"
        elif svg and m and m.get("fundidas"):
            nota = "%s · fundiu %s" % (frase, ", ".join(
                "%.0f" % f["contraste"] for f in m["fracas"]))
        celulas.append(celula(embute_texto(svg) if svg else None, nota))
    return "<tr>" + ident + "".join(celulas) + "</tr>"


def cabecalho(colunas, extra_th=0):
    linha = "".join("<th>%s</th>" % html.escape(t) for t, _ in colunas)
    return ("<table><tr><th>aplicativo</th>" + linha
            + "<th></th>" * extra_th + "</tr>")


# ============================================================================
# A FOLHA DA VÁLVULA
# ============================================================================
#
# A ORDEM DAS SEÇÕES É A ORDEM DA DECISÃO DELA, e não a do mapa: primeiro os
# seis em que a válvula MUDA o que se vê, porque são os únicos que pedem
# escolha; depois os que mudam só a quantidade de tinta empilhada; depois os
# que a válvula NÃO ALCANÇA, que é a coisa mais importante que a varredura
# achou e que nenhuma folha anterior dizia.
GRUPOS = [
    ("Volta desenho que hoje não está lá — é aqui que a escolha é sua",
     "Três ícones em que um jogo de parâmetro devolve feição que a conversão "
     "de hoje apaga: as linhas de texto do livro, a dobra da fita do VS Code, "
     "a aresta da pedra do Obsidian. A coluna «o traço de hoje» é o arquivo "
     "que está na sua tela agora; as duas do meio são propostas, e nenhuma "
     "foi instalada.",
     ["com.github.johnfactotum.Foliate", "vscode", "md.obsidian.Obsidian"]),
    ("Sai o traço em cima de traço — e a chave já existia",
     "Nestes quatro o desenho não muda: o que sai é a linha desenhada duas "
     "vezes. E o candidato 1 não é um jogo novo — é o «peso de fronteira» que "
     "a passagem anterior já escreveu e que os testes já guardam. Ele nasceu "
     "desligado porque ligá-lo em TODOS mudaria arte que você aprovou; medido "
     "hoje, ele muda exatamente estes quatro dos quinze e deixa os outros onze "
     "byte a byte iguais. A válvula é o que permite ligá-lo só aqui.",
     ["com.brave.Browser", "com.discordapp.Discord", "org.bleachbit.BleachBit",
      "org.onlyoffice.desktopeditors"]),
    ("Mesma arte, ganho só na medida",
     "Aqui nem o desenho nem a leitura a 48 px mudam; o que cai é a "
     "sobreposição. Não é firula — sobreposição alta é o que borra o ícone "
     "quando a espessura sobe, e o TRACO da dock já subiu uma vez (1,75 → "
     "2,25). Mas trocar por isto é opcional, e o padrão continua honesto.",
     ["net.davidotek.pupgui2", "org.qbittorrent.qBittorrent"]),
    ("O padrão ganha — e isso é resultado, não desistência",
     "Nenhum dos 49 outros jogos passou do critério: não perder fronteira, não "
     "inventar linha, e ganhar alguma coisa. Estão aqui para você ver que "
     "foram olhados.",
     ["meow-whatsapp", "org.videolan.VLC", "org.gnome.Calculator",
      "io.github.shiftey.Desktop", "org.gnome.gitlab.somas.Apostrophe",
      "org.gnome.FileRoller"]),
    ("A válvula NÃO chega nestes — o retoque à mão vence antes",
     "Nove linhas do mapa têm um desenho à mão em «convertidos-apps/retoques/», "
     "e o construtor copia o retoque sem nem chamar o conversor. Escrever "
     "parâmetro nessas linhas não mudaria um pixel. A coluna «o traço de hoje» "
     "mostra o retoque, que é o que está na sua tela — e as propostas mostram o "
     "que a conversão faria SE o retoque não existisse.",
     ["google-chrome", "org.telegram.desktop", "com.spotify.Client",
      "io.github.flattool.Warehouse", "com.obsproject.Studio", "steam",
      "org.gnome.Snapshot", "com.github.tchx84.Flatseal", "org.gimp.GIMP"]),
]

RECUSADOS_ORDEM = ["thunderbird", "btop", "com.boxy_svg.BoxySVG",
                   "firefox", "org.kde.krita"]


def folha_valvula(colunas, com_origem, na_mao):
    """As seções da folha da válvula, na ordem da decisão dela."""
    por_nome = {t[0]: t for t in com_origem}
    partes = [
        "<style>%s</style>" % CSS,
        "<h1>A válvula do mapa: um jogo de botões por ícone</h1>",
        '<p class="intro">Você pediu, no começo desta leva, <i>"melhorarmos a '
        'qualidade dos svgs gerados automaticamente também"</i>. O mapa dos '
        'convertidos sempre teve um quarto campo para isso — um jogo de botões '
        'do conversor por ícone — e ele nunca foi usado: <b>zero de 33 linhas</b>. '
        'Esta folha é a primeira vez que ele foi girado.</p>',
        '<p class="intro">Foram <b>1.450 conversões</b>: cinco valores de '
        '<code>--k</code> (quantas cores o conversor enxerga) × cinco de '
        '<code>--funde</code> (quanto ele funde cores parecidas) × ligar ou não '
        'o peso de fronteira, em cada uma das 29 artes de origem. Custou 2 min '
        '54 s de máquina.</p>',
        '<div class="aviso"><b>Nada foi instalado, e nada no mapa foi escrito.</b> '
        'Nenhum ícone da sua tela mudou. As colunas «candidato» são arquivos '
        'gerados só para esta folha; o acervo continua exatamente como estava.</div>',
        '<div class="aviso"><b>A válvula só alcança 15 das 33 linhas, e isso '
        'ninguém tinha medido.</b> Nove linhas nascem à mão (<code>mao</code>) e '
        'nunca passam pelo conversor; outras nove têm retoque à mão, que o '
        'construtor copia antes de chamar o conversor. Nessas dezoito, escrever '
        'parâmetro é escrever num campo que ninguém lê.</div>',
        '<div class="aviso"><b>Duas coisas mudam ao mesmo tempo na lupa, e só '
        'uma delas é a válvula.</b> O acervo que está na sua tela foi gerado '
        '<i>antes</i> da troca do traçado por curvas, e ainda não foi regerado '
        '— está esperando o seu sim. A 48 px isso não aparece: medido hoje nos '
        '15, o arquivo do acervo e a conversão de agora são <b>idênticos pixel '
        'a pixel</b>. Mas a 200 px a coluna «o traço de hoje» mostra a escada '
        'antiga, e as colunas «candidato» já saem em curva. <b>Julgue pela '
        'caixa de 48 px</b>, que é o tamanho da dock; na lupa, parte da '
        'diferença não é do parâmetro.</div>',
        '<div class="aviso"><b>O que estes números NÃO dizem.</b> Contagem de '
        'traços, tinta na caixa e sobreposição <i>não</i> separam ícone fiel de '
        'ícone falho — já está medido que a Calculadora é fiel com 10 traços e o '
        'Brave falha com 10. Aqui eles respondem outra pergunta, e só ela: '
        '<i>entre os 50 jogos da MESMA arte de origem, qual preserva mais '
        'fronteira interna com menos traço em cima de traço?</i> Nenhuma linha '
        'desta folha compara um ícone com outro.</div>',
        '<p class="intro">Cada célula está a 48 px sobre os quatro fundos '
        '(mocha, latte e os dois tons do vidro da dock) e a 200 px sobre o '
        'mocha, que é a lupa da oficina. Embaixo de cada figura estão os '
        '<b>parâmetros exatos</b> e a medição.</p>',
    ]
    for titulo, prosa, nomes in GRUPOS:
        partes.append("<h2>%s</h2>" % html.escape(titulo))
        partes.append('<p class="intro">%s</p>' % prosa)
        partes.append(cabecalho(colunas))
        for nome in nomes:
            if nome not in por_nome:
                continue
            _, origem, cor, extra = por_nome[nome]
            partes.append(linha_de(nome, origem, cor, extra, colunas))
            print("  %s" % nome, file=sys.stderr)
        partes.append("</table>")

    partes.append("<h2>Os cinco que perderam em 11/08 — a válvula salva algum?</h2>")
    partes.append('<p class="intro">Foram convertidos, foram à folha e perderam '
                  'para o glifo Arcticons desenhado à mão. Continuam fora do '
                  'mapa. O Thunderbird é o que motivou esta varredura: '
                  '<code>--k 8</code> traz de volta a aba do envelope, que o '
                  'padrão apaga. Se você quiser algum deles de volta, é uma '
                  'linha nova no mapa — e a decisão é sua.</p>')
    partes.append(cabecalho(colunas))
    for nome in RECUSADOS_ORDEM:
        origem = "/usr/share/icons/Papirus/64x64/apps/%s.svg" % nome
        if not os.path.exists(origem):
            continue
        motivo = dict(RECUSADOS).get(nome, "")
        partes.append(linha_de(nome, origem, "mauve", "", colunas, motivo))
        print("  %s (recusado)" % nome, file=sys.stderr)
    partes.append("</table>")

    partes.append("<h2>Os %d desenhados à mão — a válvula não os toca</h2>" % len(na_mao))
    partes.append('<p class="intro">Estes não passam pelo conversor: a linha diz '
                  '<code>mao</code> e o desenho vem de '
                  '<code>convertidos-apps/retoques/</code>. Estão aqui para você '
                  'conferir que continuam iguais.</p>')
    partes.append("<table><tr><th>aplicativo</th><th>o desenho à mão</th>"
                  + "<th></th>" * (len(colunas) - 1) + "</tr>")
    for nome, cor in na_mao:
        arq = os.path.join(RETOQUES, nome + ".svg")
        ident = ('<td class="nome"><b>%s</b><span class="pastilha">%s</span></td>'
                 % (html.escape(nome), html.escape(cor)))
        if os.path.exists(arq):
            with open(arq, encoding="utf-8") as fh:
                texto = fh.read().replace("currentColor", PALETA.get(cor, "#cdd6f4"))
            if "stroke-width" not in texto:
                texto = texto.replace("<path ", '<path stroke-width="%s" ' % TRACO)
            cel = celula(embute_texto(texto), "desenho à mão, intocado")
        else:
            cel = '<td class="vazia">falta retoques/%s.svg</td>' % html.escape(nome)
        partes.append("<tr>" + ident + cel + "<td></td>" * (len(colunas) - 1) + "</tr>")
    partes.append("</table>")
    return partes


def escrever(saida, titulo, partes):
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, "w", encoding="utf-8") as fh:
        fh.write("<!doctype html><meta charset='utf-8'><title>"
                 + html.escape(titulo) + "</title>" + "".join(partes))
    print("folha em %s (%.1f KB)" % (saida, os.path.getsize(saida) / 1024.0),
          file=sys.stderr)


def main():
    escada = "--escada" in sys.argv[1:]
    valvula = "--valvula" in sys.argv[1:]
    argumentos = [a for a in sys.argv[1:] if not a.startswith("--")]
    modo = "escada" if escada else ("valvula" if valvula else "fidelidade")
    colunas = COLUNAS[modo]
    padrao = {"escada": "meow-conversor-folha.html",
              "valvula": "meow-valvula-33.html",
              "fidelidade": "meow-conversor-fidelidade.html"}[modo]
    saida = argumentos[0] if argumentos else os.path.join(HOME, "Documentos", padrao)
    com_origem, na_mao = ler_mapa()
    titulo = {"escada": "O conversor: escada ou curva",
              "valvula": "A válvula do mapa: um jogo de botões por ícone",
              "fidelidade": "O conversor: o traço é fiel ao desenho?"}[modo]

    if valvula:
        partes = folha_valvula(colunas, com_origem, na_mao)
        escrever(saida, titulo, partes)
        return

    if escada:
        partes = [
            "<style>%s</style>" % CSS,
            "<h1>%s</h1>" % titulo,
            '<p class="intro">Cada linha é o mesmo ícone traçado de dois jeitos. '
            '<b>Polilinha</b> é o traçado anterior a 09/09: a fronteira sai em '
            'degraus de pixel e, na lupa, lê como serra. <b>Curvas</b> é o que '
            'entrou: os cantos são achados antes de alisar, as retas continuam '
            'retas e o resto vira Bézier. A forma é a mesma nos dois — só a '
            'linha que a desenha muda.</p>',
        ]
    else:
        partes = [
            "<style>%s</style>" % CSS,
            "<h1>%s</h1>" % titulo,
            '<p class="intro">Você disse: <i>"sinto que não tá fidedigno e a '
            'ideia é termos linhas das bordas nas nossas cores e o fundo '
            'transparente"</i>. A segunda metade já é assim hoje — o acervo sai '
            'sem preenchimento e sem fundo, e a cor entra da paleta. Esta folha '
            'é sobre a primeira: <b>o desenho que sai não é o desenho que '
            'entrou</b>.</p>',
            '<p class="intro"><b>O traço de hoje</b> é o que está na sua tela. '
            '<b>Com peso de fronteira</b> é a proposta: quando duas cores '
            'vizinhas se encontram, essa linha quase não diz nada e mesmo assim '
            'custa um traço — então ela deixa de ser desenhada. <b>O desenhado à '
            'mão</b> é o glifo do Arcticons, que já está no repositório e é a '
            'saída mais barata quando a conversão não resolve.</p>',
            '<div class="aviso"><b>A chave nasce desligada.</b> Dos 34 ícones '
            'medidos, 26 saem <b>byte a byte iguais</b> aos de hoje com ela '
            'ligada — inclusive a Calculadora, o Telegram e o VLC, que já saem '
            'fiéis e por isso foram usados como trava. Mudam 8, e a coluna do '
            'meio diz quais.</div>',
            '<div class="aviso"><b>O que a medição derrubou.</b> A explicação '
            'antiga era "desenho geométrico converte, orgânico não". É falsa: a '
            'Calculadora é a mais carregada de todas (10 traços, 34,6% de tinta '
            'na caixa) e é a mais fiel; o Brave tem só quatro cores e falha. '
            'Também não existe um <i>teto</i> de traços — contando os 39 '
            'Arcticons desenhados à mão, a mediana é 4 subcaminhos e o máximo é '
            '18, e as conversões cabem nessa faixa mesmo quando falham. A medida '
            'que mais se aproxima é a <b>sobreposição</b> (quanto do traço cai '
            'em cima de outro traço a 2,25): nos desenhados à mão a mediana é '
            '1,2% e o pior é 17,3%; o Brave hoje está em 18,2%, sozinho acima de '
            'todos eles, e com o peso de fronteira cai para 6,3%.</div>',
        ]
    partes += [
        '<p class="intro">Cada célula está a 48 px sobre os quatro fundos '
        '(mocha, latte e os dois tons do vidro da dock) e a 200 px sobre o '
        'mocha, que é o tamanho da lupa da oficina.</p>',
        '<div class="aviso">Nada foi instalado. Nenhum ícone da sua tela mudou. '
        'A regeneração do acervo só acontece depois do seu sim.</div>',
    ]

    if not escada:
        partes.append("<h2>Os três em destaque — é aqui que a decisão pesa</h2>")
        partes.append('<p class="intro">São os que a medição de 09/09 marcou: o '
                      'Brave e o Chrome <b>falham</b> hoje, o Discord é '
                      '<b>aceitável</b>. Os três já têm glifo desenhado à mão '
                      'baixado no repositório e fora do mapa — trocar custa uma '
                      'linha em cada um.</p>')
        partes.append(cabecalho(colunas))
        for nome in ("com.brave.Browser", "google-chrome", "com.discordapp.Discord"):
            achado = [t for t in com_origem if t[0] == nome]
            if not achado:
                continue
            _, origem, cor, extra = achado[0]
            partes.append(linha_de(nome, origem, cor, extra, colunas,
                                   DESTAQUE.get(nome, "")))
            print("  %s (destaque)" % nome, file=sys.stderr)
        partes.append("</table>")

    partes.append("<h2>Os %d do lançador que têm origem chapada</h2>" % len(com_origem))
    partes.append(cabecalho(colunas))
    for nome, origem, cor, extra in com_origem:
        partes.append(linha_de(nome, origem, cor, extra, colunas))
        print("  %s" % nome, file=sys.stderr)
    partes.append("</table>")

    partes.append("<h2>Os cinco que perderam em 11/08 — algo salva algum?</h2>")
    partes.append('<p class="intro">Foram convertidos, foram à folha e perderam '
                  'para o glifo Arcticons desenhado à mão. Continuam fora do '
                  'acervo; estão aqui porque a pergunta mudou.</p>')
    partes.append(cabecalho(colunas))
    for nome, motivo in RECUSADOS:
        origem = "/usr/share/icons/Papirus/64x64/apps/%s.svg" % nome
        if not os.path.exists(origem):
            continue
        partes.append(linha_de(nome, origem, "mauve", "", colunas, motivo))
        print("  %s (recusado)" % nome, file=sys.stderr)
    partes.append("</table>")

    partes.append("<h2>Os %d desenhados à mão — nada aqui muda</h2>" % len(na_mao))
    partes.append('<p class="intro">Estes não passam pelo conversor: o retoque '
                  'em <code>convertidos-apps/retoques/</code> vence sempre e '
                  'nunca é sobrescrito, porque é decisão sua registrada. Estão '
                  'na folha só para você lembrar que existem — e para conferir '
                  'que continuam iguais depois da troca.</p>')
    partes.append("<table><tr><th>aplicativo</th><th>o desenho à mão</th>"
                  + "<th></th>" * (len(colunas) - 1) + "</tr>")
    for nome, cor in na_mao:
        arq = os.path.join(RETOQUES, nome + ".svg")
        ident = ('<td class="nome"><b>%s</b><span class="pastilha">%s</span></td>'
                 % (html.escape(nome), html.escape(cor)))
        if os.path.exists(arq):
            with open(arq, encoding="utf-8") as fh:
                texto = fh.read().replace("currentColor", PALETA.get(cor, "#cdd6f4"))
            if "stroke-width" not in texto:
                texto = texto.replace("<path ", '<path stroke-width="%s" ' % TRACO)
            cel = celula(embute_texto(texto), "desenho à mão, intocado")
        else:
            cel = '<td class="vazia">falta retoques/%s.svg</td>' % html.escape(nome)
        partes.append("<tr>" + ident + cel + "<td></td>" * (len(colunas) - 1) + "</tr>")
    partes.append("</table>")

    if not escada:
        # A BOCA DO WILBER FICA ESCRITA NA FOLHA, e não só no relato: é a única
        # pergunta do conversor que não tem plano B, e ela é dela.
        partes.append("<h2>A boca do Wilber — e por que o peso de fronteira não a traz</h2>")
        partes.append('<p class="intro">Você pediu a boca do GIMP em 11/08, e ela '
                      'está lá como <b>retoque à mão</b>: uma curva desenhada por '
                      'cima da conversão. O peso de fronteira não a produz, e o '
                      'motivo é aritmético — no desenho do Papirus a boca não é '
                      'uma cor, é uma <b>sombra da mesma cor</b>, a 45,0 de '
                      'distância do focinho. O limiar medido é 70. Se a boca '
                      'virasse uma classe própria, a chave nova a apagaria na '
                      'hora, porque 45,0 é justamente uma fronteira fraca. Ela é '
                      'o contraexemplo da regra: fronteira fraca que <b>é</b> o '
                      'desenho. O retoque continua sendo a resposta certa.</p>')

    escrever(saida, titulo, partes)


if __name__ == "__main__":
    main()

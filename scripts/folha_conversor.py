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
#   uso: scripts/folha_conversor.py [saida.html] [--escada]
#        padrão:    ~/Documentos/meow-conversor-fidelidade.html  (quatro colunas)
#        --escada:  ~/Documentos/meow-conversor-folha.html       (a de 09/09)

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

# AS COLUNAS SÃO DADO, NÃO CÓDIGO REPETIDO — e é o que deixa as duas folhas
# saírem do mesmo laço. Cada coluna é (título, receita), e a receita é:
#   "origem"     -> o arquivo de entrada, como está;
#   "arcticons"  -> o glifo desenhado à mão, quando existe;
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


def celula(uri, nota=""):
    if uri is None:
        return '<td class="vazia">%s</td>' % html.escape(nota or "não saiu")
    fundos = "".join(
        '<span style="background:%s" title="%s"><img src="%s" width="48" height="48"></span>'
        % (hexa, html.escape(nome), uri) for nome, hexa in FUNDOS)
    return ('<td><div class="quatro">%s</div>'
            '<img class="lupa" src="%s" width="200" height="200">'
            '<div class="nota">%s</div></td>' % (fundos, uri, html.escape(nota)))


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
.quatro span { display:inline-block; padding:6px; border-radius:8px; margin-right:5px; }
.lupa { display:block; margin-top:9px; background:#1e1e2e; border-radius:12px; }
.nota { font-size:11px; color:#7f849c; margin-top:6px; max-width:216px; }
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
    ident = ('<td class="nome"><b>%s</b><span class="pastilha">%s</span>'
             '<code>%s</code>%s</td>'
             % (html.escape(nome), html.escape(cor), html.escape(origem),
                ('<code>%s</code>' % html.escape(motivo)) if motivo else ""))
    celulas, base = [], None
    for titulo, receita in colunas:
        if receita == "origem":
            try:
                celulas.append(celula(embute_arquivo(origem), "a arte de fábrica, como está"))
            except OSError as e:
                celulas.append('<td class="vazia">%s</td>' % html.escape(str(e)[:80]))
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


def main():
    escada = "--escada" in sys.argv[1:]
    argumentos = [a for a in sys.argv[1:] if not a.startswith("--")]
    modo = "escada" if escada else "fidelidade"
    colunas = COLUNAS[modo]
    padrao = ("meow-conversor-folha.html" if escada
              else "meow-conversor-fidelidade.html")
    saida = argumentos[0] if argumentos else os.path.join(HOME, "Documentos", padrao)
    com_origem, na_mao = ler_mapa()
    titulo = ("O conversor: escada ou curva" if escada
              else "O conversor: o traço é fiel ao desenho?")

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

    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, "w", encoding="utf-8") as fh:
        fh.write("<!doctype html><meta charset='utf-8'><title>"
                 + html.escape(titulo) + "</title>" + "".join(partes))
    print("folha em %s (%.1f KB)" % (saida, os.path.getsize(saida) / 1024.0),
          file=sys.stderr)


if __name__ == "__main__":
    main()

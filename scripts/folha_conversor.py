#!/usr/bin/env python3
# folha_conversor.py — três jeitos de traçar o mesmo ícone, lado a lado.
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
#   folha põe o original, a polilinha de hoje e as curvas novas na mesma linha,
#   nos quatro fundos medidos e na lupa de 200 px, e ELA decide.
#
#   Este script NÃO INSTALA NADA, não escreve no repositório e não regenera o
#   acervo. Ele só lê e desenha.
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
#   uso: scripts/folha_conversor.py [saida.html]
#        (padrão: ~/Documentos/meow-conversor-folha.html)

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


def linha_de(nome, origem, cor, extra, motivo=""):
    """Uma linha da tabela: nome, original, polilinha, curvas."""
    chaves = extra.split() if extra else []
    poli, mp, fp = converter(origem, cor, "--polilinha", *chaves)
    curv, mc, fc = converter(origem, cor, *chaves)
    ident = ('<td class="nome"><b>%s</b><span class="pastilha">%s</span>'
             '<code>%s</code>%s</td>'
             % (html.escape(nome), html.escape(cor), html.escape(origem),
                ('<code>%s</code>' % html.escape(motivo)) if motivo else ""))
    try:
        orig = celula(embute_arquivo(origem), "a arte de fábrica, como está")
    except OSError as e:
        orig = '<td class="vazia">%s</td>' % html.escape(str(e)[:80])
    return ("<tr>" + ident
            + orig
            + celula(embute_texto(poli) if poli else None, fp)
            + celula(embute_texto(curv) if curv else None, fc)
            + "</tr>")


def main():
    saida = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        HOME, "Documentos", "meow-conversor-folha.html")
    com_origem, na_mao = ler_mapa()

    partes = [
        "<style>%s</style>" % CSS,
        "<h1>O conversor: escada ou curva</h1>",
        '<p class="intro">Cada linha é o mesmo ícone traçado de dois jeitos. '
        '<b>Polilinha</b> é o que está na sua tela hoje: a fronteira sai em '
        'degraus de pixel e, na lupa, lê como serra. <b>Curvas</b> é a proposta: '
        'os cantos são achados antes de alisar, as retas continuam retas e o '
        'resto vira Bézier. A forma é a mesma nos dois — só a linha que a '
        'desenha muda.</p>',
        '<p class="intro">Cada célula está a 48 px sobre os quatro fundos '
        '(mocha, latte e os dois tons do vidro da dock) e a 200 px sobre o '
        'mocha, que é o tamanho da lupa da oficina.</p>',
        '<div class="aviso">Nada foi instalado. Nenhum ícone da sua tela mudou. '
        'A regeneração do acervo só acontece depois do seu sim.</div>',
        '<div class="aviso">A quarta coluna prevista, o <b>potrace</b>, não '
        'entrou: ele não está nesta máquina e instalá-lo pede senha. A folha sai '
        'com três colunas em vez de travar por causa disso.</div>',
        "<h2>Os %d do lançador que têm origem chapada</h2>" % len(com_origem),
        "<table><tr><th>aplicativo</th><th>original</th>"
        "<th>polilinha (hoje)</th><th>curvas (proposta)</th></tr>",
    ]
    for nome, origem, cor, extra in com_origem:
        partes.append(linha_de(nome, origem, cor, extra))
        print("  %s" % nome, file=sys.stderr)
    partes.append("</table>")

    partes.append("<h2>Os cinco que perderam em 11/08 — a curva salva algum?</h2>")
    partes.append('<p class="intro">Foram convertidos, foram à folha e perderam '
                  'para o glifo Arcticons desenhado à mão. Continuam fora do '
                  'acervo; estão aqui só porque a gramática mudou.</p>')
    partes.append("<table><tr><th>aplicativo</th><th>original</th>"
                  "<th>polilinha</th><th>curvas</th></tr>")
    for nome, motivo in RECUSADOS:
        origem = "/usr/share/icons/Papirus/64x64/apps/%s.svg" % nome
        if not os.path.exists(origem):
            continue
        partes.append(linha_de(nome, origem, "mauve", "", motivo))
        print("  %s (recusado)" % nome, file=sys.stderr)
    partes.append("</table>")

    partes.append("<h2>Os %d desenhados à mão — nada aqui muda</h2>" % len(na_mao))
    partes.append('<p class="intro">Estes não passam pelo conversor: o retoque '
                  'em <code>convertidos-apps/retoques/</code> vence sempre e '
                  'nunca é sobrescrito, porque é decisão sua registrada. Estão '
                  'na folha só para você lembrar que existem — e para conferir '
                  'que continuam iguais depois da troca.</p>')
    partes.append("<table><tr><th>aplicativo</th><th>o desenho à mão</th>"
                  "<th></th><th></th></tr>")
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
        partes.append("<tr>" + ident + cel + "<td></td><td></td></tr>")
    partes.append("</table>")

    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, "w", encoding="utf-8") as fh:
        fh.write("<!doctype html><meta charset='utf-8'>"
                 "<title>O conversor: escada ou curva</title>" + "".join(partes))
    print("folha em %s (%.1f KB)" % (saida, os.path.getsize(saida) / 1024.0),
          file=sys.stderr)


if __name__ == "__main__":
    main()

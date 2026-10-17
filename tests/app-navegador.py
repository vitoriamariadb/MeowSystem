#!/usr/bin/env python3
"""app-navegador.py — a pagina do app usada como ELA usaria, num navegador de verdade.

    tests/app-navegador.py            roda tudo
    tests/app-navegador.py --fotos    roda e guarda as capturas em /tmp

POR QUE ESTE ARQUIVO EXISTE, NAS PALAVRAS DELA (01/09/2026)
  "alem disso eu realmente nao sei se ele funciona de fato. Eu preciso que
   corrija isso e teste como user no navegador cada feature."

  O `tests/app.sh` que ja existia responde outra pergunta: se o SERVIDOR le as
  mesmas chaves que o `bin/meow`, se o CSS nao tem cor solta, se nao ha
  `shell=True`. Nada disso diz que um clique no trilho troca a secao, que o
  botao grava no `meow.conf`, ou que a galeria mostra as 46 miniaturas. Isso so
  se sabe clicando.

O QUE ELE FAZ, E O QUE NAO FAZ
  Sobe o `app/run.sh --sem-abrir` numa porta efemera, abre a pagina no Chromium
  do Playwright (headless — NUNCA numa janela na tela dela) e exerce cada
  recurso. Escreve de verdade em UMA chave, a mais inofensiva do arquivo
  (`LOG_NIVEL`), e devolve o valor no fim — comparando o md5 do `meow.conf`
  antes e depois para provar que devolveu.

  As acoes destrutivas nao sao clicadas. `Desinstalar`, `banir` e `Instalar`
  ficam de fora de proposito: um teste que apaga o tema dela para provar que o
  botao funciona e um teste que nao pode rodar duas vezes.

A AUDITORIA DE 01/09/2026, E O BURACO QUE ELA ABRIU NESTE ARQUIVO
  A pagina foi percorrida inteira num navegador de verdade, aba a aba, e a
  varredura voltou com 120 achados. Quarenta deles estavam em recursos que
  ESTE arquivo dava por bons: ele passava com 34 verificacoes no verde
  enquanto clicar num flavor deixava a marcacao no flavor antigo, tirar uma
  ficha de app nao tirava nada da tela e 46 botoes da galeria chamavam uma
  acao que o servidor nao tem.

  A causa e uma so, e vale para todo teste de tela: ele conferia que a pagina
  RESPONDE, e nao que ela responde CERTO. "A barra do Salvar apareceu" e uma
  resposta; "o botao que eu cliquei ficou marcado" e a resposta certa. As
  verificacoes que entraram em 02/09/2026 sao, todas, dessa segunda especie:

    2.  Toda chave que o servidor le tem cartao em alguma aba — uma chave sem
        cartao e uma chave que ela nao consegue configurar sozinha.
    6.  A marcacao segue o clique — um representante de CADA forma de controle
        de escolha (amostra de flavor, bolinha de cor, imagem, botao de opcao),
        escolhido pelo que o esquema declara, e nao por uma lista de chaves.
    7.  As fichas de lista desenham o que a escolha diz — acrescentar aparece,
        acrescentar de novo NAO apaga o anterior, e o × tira da tela.
    8.  O desenho ao vivo segue o controle — o veu de Kelvin e a barra
        desenhada mudam quando o controle muda, que e a unica razao de existirem.
    11. O ensaio saiu da página — não ha interruptor, e o Salvar fica.
    15. Toda acao que a pagina oferece num botao existe no servidor.
    16. O controle casa com o que o esquema declara — chave de opcoes fechadas
        nao pode virar campo de texto livre, faixa numerica tem de virar
        deslizante, lista tem de virar fichas, e dois cartoes da mesma aba nao
        podem levar o mesmo titulo.

  As de 6, 7, 8, 15 e 16 sao REGRAS sobre o esquema e sobre o que a pagina
  desenhou, nunca listas de chaves: uma chave nova nasce coberta, e uma chave
  que mudar de forma continua conferida. O censo do passo 2 — um retrato de
  cada cartao desenhado, colhido durante a varredura que ja existia — e o que
  torna isso barato: a pagina e visitada uma vez, e as regras rodam em cima da
  medicao.

DEPENDENCIA, E A DEGRADACAO QUANDO ELA FALTA
  Playwright nao vem com o sistema. Se nao estiver no venv de testes, este
  arquivo SAI 3 (pulado) com a receita na tela, em vez de falhar — a mesma
  disciplina do resto do projeto, onde falta de dependencia e etapa pulada, nao
  erro. Instalar:

      python3 -m venv ~/.local/share/meowsystem/venv-testes
      ~/.local/share/meowsystem/venv-testes/bin/pip install playwright
      ~/.local/share/meowsystem/venv-testes/bin/playwright install chromium
"""
import hashlib
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import zlib

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOTOS = "--fotos" in sys.argv
DESTINO_FOTOS = "/tmp/meow-app-testes"

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("pulado: playwright nao esta instalado neste interpretador.")
    print("  " + sys.executable)
    print("  receita no cabecalho de tests/app-navegador.py")
    sys.exit(3)

# A regra do projeto e' que nada da interface e' aplicado em sandbox, tudo e'
# aplicado na maquina da pessoa; por isso quem vai para a sandbox e' o TESTE.
#
# O servidor recebe um ambiente limpo, o `env -i` do `tests/convergencia.sh`:
# HOME e `MEOW_CONF` num diretorio temporario, `MEOW_PONTE` para o vazio e um
# `sudo` falso na frente do PATH — numa maquina com `NOPASSWD: ALL` o `sudo -n`
# de verdade PASSA, e um teste cujo alcance depende disso e' roleta.
BRINQUEDO = tempfile.mkdtemp(prefix="meow-navegador-")
CASA = os.path.join(BRINQUEDO, "casa")
CONF = os.path.join(CASA, ".config", "meow", "meow.conf")
# Quantas imagens a galeria do brinquedo recebe. O passo 4 cobra MAIS de 20
# miniaturas (a casa dela tem 46); 24 passa o piso com folga e ainda cabe numa
# pagina da galeria, que desenha 60 de cada vez.
PAREDES = 24

falhas = []
passos = []


def checa(condicao, texto):
    passos.append((bool(condicao), texto))
    print(("  ok " if condicao else "  XX ") + texto)
    if not condicao:
        falhas.append(texto)



def descartar_tudo(pag):
    """Clica em Descartar e responde a pergunta que nasce com 2+ escolhas.

    A pergunta e' de 07/09/2026: o Descartar mora a 8 px do Salvar e jogava
    fora a sessao inteira sem confirmar. Com UMA escolha ele continua direto;
    com duas ou mais, o <dialog> pergunta — e quem usa responde, entao a
    suíte tambem."""
    pag.locator("#botao-descartar").click()
    pag.wait_for_timeout(250)
    dlg = pag.locator("#confirmar[open]")
    if dlg.count():
        dlg.locator("#confirmar-ok").click()
        pag.wait_for_timeout(250)


def md5_conf():
    with open(CONF, "rb") as fh:
        return hashlib.md5(fh.read()).hexdigest()


def md5_de(caminho):
    if not os.path.isfile(caminho):
        return None
    with open(caminho, "rb") as fh:
        return hashlib.md5(fh.read()).hexdigest()


def foto(alvo, nome):
    """Captura de um locator (ou da pagina inteira) num PNG; devolve o caminho.

    Com `--fotos` a captura vai para a MESMA pasta das outras, e nao para o
    /tmp: as fotos de comparacao (antes/depois de um clique) sao justamente o
    que se olha quando uma conferencia de pixel falha, e procura-las em dois
    lugares e' o comeco de nao olhar."""
    pasta = DESTINO_FOTOS if FOTOS else tempfile.gettempdir()
    caminho = os.path.join(pasta, f"meow-nav-{nome}.png")
    alvo.screenshot(path=caminho)
    return caminho


def valor_de(chave):
    for linha in open(CONF, encoding="utf-8"):
        if linha.startswith(chave + "="):
            return linha.split("=", 1)[1].split("#")[0].strip().strip('"')
    return None


# Ele responde, para cada chave, QUE FORMA a pagina deu a ela — campo de texto,
# deslizante, fichas, grupo de botoes — e o `tipo` do grupo sai da propria
# arvore (a classe do elemento que segura os botoes), em vez de uma lista de
# nomes de classe escrita aqui.
CENSO_JS = """
() => [...document.querySelectorAll('#conteudo article.cartao')].map((a) => {
  const grupo = [...a.querySelectorAll('button[data-valor]')];
  const pai = grupo.length ? grupo[0].parentElement : null;
  return {
    chave: a.dataset.chave || (a.querySelector('code') || {}).textContent || '',
    titulo: (a.querySelector('h3') || {}).textContent || '',
    tipo: pai ? (pai.className || pai.tagName.toLowerCase()) : '',
    botoes: grupo.length,
    texto: !!a.querySelector('input[type=text], textarea'),
    faixa: !!a.querySelector('input[type=range]'),
    fichas: !!a.querySelector('.fichas'),
  };
})
"""

# O esquema inteiro tem os comentarios do `meow.conf.exemplo` dentro e passa de
# um megabyte; o que as regras precisam sao estes sete campos por chave.
ESQUEMA_JS = """
() => ESQUEMA.chaves.map((k) => ({
  chave: k.chave,
  opcoes: k.opcoes || [],
  faixa: !!k.faixa,
  hora_cheia: !!k.hora_cheia,
  previa: k.previa || '',
  lista: !!k.lista,
  pathsep: !!k.lista_pathsep,
  vazio: !!k.aceita_vazio,
  sem_programa: !!k.sem_programa,
}))
"""

# Duas procedencias, as duas varridas por regra: o atributo `data-acao*` de
# qualquer elemento (e assim o atalho do cabecalho entra) e, no `app.js`, o
# primeiro argumento literal de qualquer funcao cujo nome comece com `rodar`.
ACOES_NO_DOM_JS = """
() => [...document.querySelectorAll('*')].flatMap(
  (el) => [...el.attributes].filter((a) => a.name.startsWith('data-acao'))
                            .map((a) => a.value)).filter(Boolean)
"""
ACOES_NO_FONTE = re.compile(r"""rodar[A-Za-z]*\(\s*["']([a-z0-9_]+)["']""")


def cartao_da_chave(pag, chave):
    """Traz o cartao de UMA chave a tela pela busca, e devolve o locator dele.

    A busca e o caminho mais curto e o mais parecido com o gesto dela: nao
    depende de saber em que aba a chave mora hoje, e sobrevive a uma chave que
    mude de secao amanha."""
    pag.fill("#busca", chave)
    pag.wait_for_timeout(300)
    por_dado = pag.locator(f'#conteudo article[data-chave="{chave}"]')
    if por_dado.count():
        return por_dado.first
    # `data-chave` e recente. Enquanto ele podia nao existir, o nome da chave
    # no `<code>` do topo continua sendo o unico identificador visivel do
    # cartao.
    return pag.locator(f'#conteudo article.cartao:has(code:text-is("{chave}"))').first


def opcoes_na_tela(pag, chave, paciencia):
    """Abre o cartao da chave e espera as opcoes clicaveis aparecerem.

    A opcao-desenho (gato, ponteiro) so vira botao quando a previa chega pela
    rede; antes disso o mesmo cartao cai no controle de texto, e medir o clique
    ali seria medir outra coisa."""
    cartao = cartao_da_chave(pag, chave)
    botoes = cartao.locator("button[data-valor]")
    for _ in range(paciencia):
        if botoes.count() >= 2:
            break
        pag.wait_for_timeout(500)
    return cartao, botoes


def pixels_diferentes(a, b):
    """% de pixels que diferem entre dois PNG, com 3% de tolerancia de cor.

    NAO E' IGUALDADE BYTE A BYTE, E ISSO FOI MEDIDO: dois SVG IDENTICOS no DOM
    (mesmo `innerHTML`, mesma caixa) dao PNGs de 8088 e 8042 bytes, porque estao
    em posicoes fracionarias diferentes na pagina e o antialiasing muda. Byte a
    byte nunca dispara, e uma trava que nunca dispara nao e' trava."""
    p = subprocess.run(["compare", "-metric", "AE", "-fuzz", "3%", a, b, "null:"],
                       capture_output=True)
    bruto = (p.stderr or b"").decode("utf-8", "replace").strip().split()
    if not bruto:
        return None
    try:
        n = float(bruto[0])
    except ValueError:
        return None
    g = subprocess.run(["identify", "-format", "%w %h", a], capture_output=True)
    try:
        w, h = (int(x) for x in g.stdout.decode().split())
    except ValueError:
        return None
    return 100.0 * n / max(1, w * h)


def alvo_clicavel(botoes):
    """O primeiro botao que ainda NAO esta marcado e tem valor de verdade.

    O `não mexer` de fim de fileira tem `data-valor=""` e e uma escolha legitima
    dela, mas nao serve de alvo aqui: clicar no vazio prova menos do que clicar
    num valor, e em chave de uma opcao so ele seria o unico alvo possivel."""
    for i in range(botoes.count()):
        b = botoes.nth(i)
        if b.get_attribute("aria-pressed") != "true" and (b.get_attribute("data-valor") or ""):
            return b
    return None


def marcado_em(cartao):
    """Que valor esta com o `aria-pressed=true` neste cartao — ou 'nenhum'."""
    m = cartao.locator("button[data-valor][aria-pressed=true]")
    if not m.count():
        return "nenhum"
    return "·".join(m.nth(i).get_attribute("data-valor") or "(vazio)"
                    for i in range(m.count()))


def descartar(pag):
    """Devolve a pagina ao que esta no disco, se houver escolha pendente.

    Roda entre um grupo de verificacoes e o proximo: uma escolha esquecida faz
    o passo seguinte contar 2 escolhas onde a frase dele diz 1.

    Quem diz que ha' escolha pendente e' o Descartar: desde 13/09/2026 a barra
    do Salvar fica sempre na tela, e so' as pecas de dentro acendem."""
    if pag.locator("#botao-descartar").is_visible():
        descartar_tudo(pag)
        pag.wait_for_timeout(400)


def png_liso(caminho, rgb, larg=64, alt=40):
    """Um PNG de uma cor so', escrito a mao para nao depender de biblioteca.
    E' o mesmo do `tests/app-acessibilidade.py`, copiado e nao importado: a
    P33 libera os dois testes, e nao um terceiro arquivo que os dois leiam."""
    def pedaco(tipo, corpo):
        return (struct.pack(">I", len(corpo)) + tipo + corpo
                + struct.pack(">I", zlib.crc32(tipo + corpo) & 0xFFFFFFFF))
    linhas = (b"\x00" + bytes(rgb) * larg) * alt
    with open(caminho, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n"
                 + pedaco(b"IHDR", struct.pack(">IIBBBBB", larg, alt, 8, 2, 0, 0, 0))
                 + pedaco(b"IDAT", zlib.compress(linhas))
                 + pedaco(b"IEND", b""))


def xcursor_liso(caminho, lado=24, argb=0xFFCDD6F4):
    """Um XCursor de uma imagem so' — um triangulo — no formato que o
    `_cursor_para_rgba` do servidor decodifica: `Xcur`, o cabecalho de 16
    bytes, UMA entrada de imagem (tipo 0xfffd0002, subtipo = tamanho) e o bloco
    de 36 bytes seguido dos pixels em ARGB little-endian. Um arquivo que ele
    nao decodificasse viraria botao sem desenho, e nao previa."""
    pixels = b"".join(struct.pack("<I", argb if x <= y else 0)
                      for y in range(lado) for x in range(lado))
    with open(caminho, "wb") as fh:
        fh.write(b"Xcur" + struct.pack("<III", 16, 0x10000, 1)
                 + struct.pack("<III", 0xFFFD0002, lado, 28)
                 + struct.pack("<9I", 36, 0xFFFD0002, lado, 1, lado, lado, 0, 0, 0)
                 + pixels)


def montar_casa():
    """Semeia o HOME de brinquedo e devolve o ambiente do servidor.

    O que se planta e' o que o passo 4 mede numa casa instalada, e cada lugar
    sai do `meow.conf` do brinquedo (`valor_de`), nunca de um nome escrito
    aqui: o exemplo mudar de tema, de ponteiro ou de pasta muda a semeadura
    junto. O porque de cada um esta' no bloco "E A CASA NAO FICA VAZIA"."""
    os.makedirs(os.path.dirname(CONF))
    shutil.copyfile(os.path.join(RAIZ, "meow.conf.exemplo"), CONF)

    icones = os.path.join(CASA, ".local", "share", "icons")
    # O ponteiro de fabrica, pelo nome EXATO do valor: e' a primeira regra do
    # `_cursor_pastas_do_valor` (e do `_cursor_nome_tema` do `cursor.sh`), e
    # nao depende da convencao do sufixo.
    ponteiro = os.path.join(icones, valor_de("CURSOR"), "cursors")
    os.makedirs(ponteiro)
    xcursor_liso(os.path.join(ponteiro, "left_ptr"))
    # O tema de icones instalado, com os glifos versionados que o construtor
    # veste nos aplicativos. `scalable/apps` e' uma das tres pastas que o
    # `_prev_icones` le.
    tema = os.path.join(icones, valor_de("NOME_TEMA_ICONES"), "scalable", "apps")
    os.makedirs(tema)
    glifos = os.path.join(RAIZ, "packs", "meowsystem", "icones", "apps", "arcticons")
    for nome in sorted(os.listdir(glifos)):
        if nome.endswith(".svg"):
            shutil.copyfile(os.path.join(glifos, nome), os.path.join(tema, nome))
    # A galeria: `ativos/` e' a pasta do carrossel, a aba que a pagina abre.
    # Uma cor por imagem, para nenhuma ser copia byte a byte de outra.
    ativos = os.path.join(valor_de("WALLPAPER_BASE").replace("$HOME", CASA), "ativos")
    os.makedirs(ativos)
    for i in range(PAREDES):
        png_liso(os.path.join(ativos, f"brinquedo-{i:02d}.png"),
                 (10 * i, 0x2A, 0xFF - 10 * i))

    falso = os.path.join(BRINQUEDO, "falso")
    os.makedirs(falso)
    with open(os.path.join(falso, "sudo"), "w", encoding="utf-8") as fh:
        fh.write("#!/bin/sh\n"
                 "printf 'sudo: recusado pelo tests/app-navegador.py\\n' >&2\n"
                 "exit 1\n")
    os.chmod(os.path.join(falso, "sudo"), 0o755)
    return {"PATH": falso + os.pathsep + os.environ.get("PATH", ""),
            "HOME": CASA, "USER": os.environ.get("USER", "meow"),
            "LANG": os.environ.get("LANG", "C.UTF-8"),
            "MEOW_CONF": CONF, "MEOW_PONTE": "/nao/existe"}


def sobe_servidor(ambiente):
    """Sobe o painel e devolve (processo, url). A URL sai na PRIMEIRA linha do
    `--sem-abrir` — e e a unica forma de saber a porta, que o kernel escolhe.
    `ambiente` e' o do HOME de brinquedo (`montar_casa`), e SO' ele: nada do
    ambiente de quem chamou chega ao servidor."""
    proc = subprocess.Popen(
        [os.path.join(RAIZ, "app", "run.sh"), "--sem-abrir"],
        cwd=RAIZ, env=ambiente,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    url = None
    inicio = time.time()
    while time.time() - inicio < 40:
        linha = proc.stdout.readline()
        if not linha:
            break
        m = re.search(r"http://127\.0\.0\.1:\d+/\?t=[A-Za-z0-9_-]+", linha)
        if m:
            url = m.group(0)
            break
    return proc, url


def main():
    # O "pulado: nao ha ~/.config/meow/meow.conf" saiu daqui junto com a casa
    # dela: o `meow.conf` agora e' o do brinquedo, e ele sempre existe.
    ambiente = montar_casa()
    if FOTOS:
        os.makedirs(DESTINO_FOTOS, exist_ok=True)

    md5_inicial = md5_conf()
    log_nivel_inicial = valor_de("LOG_NIVEL")
    proc, url = sobe_servidor(ambiente)
    if not url:
        print("XX o app/run.sh nao imprimiu a URL — nada a testar")
        proc.terminate()
        return 2

    erros_de_console = []
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1500, "height": 1000})
            # O `console` do navegador tambem registra falha de REDE — e um 409
            # e o servidor fazendo o certo: recusar um segundo trabalho
            # enquanto o primeiro corre.
            pag.on("console", lambda m: (
                m.type == "error"
                and "Failed to load resource" not in m.text
                # `Failed to fetch` no fim é a página pedindo algo enquanto o
                # teste já derrubou o servidor — teardown, não defeito.
                and "Failed to fetch" not in m.text
                and erros_de_console.append(m.text)))
            pag.on("pageerror", lambda e: erros_de_console.append(str(e)))
            # O `#trilho button` e' a prova certa de "pronta": o `iniciar()` so'
            # o desenha depois de o esquema chegar, e na mesma volta em que
            # pinta o `#resumo` que o passo 1 le logo abaixo.
            pag.goto(url, wait_until="domcontentloaded")
            pag.wait_for_selector("#trilho button")

            print("\n1. A PAGINA ABRE")
            checa(pag.title() == "MeowSystem", "o titulo e MeowSystem")
            resumo = pag.locator("#resumo").inner_text()
            # Ele era "95 chaves" cravado, e envelheceu em silêncio: cada chave
            # nova no `meow.conf.exemplo` quebrava este teste sem que nada
            # estivesse errado no painel.
            m_resumo = re.search(r"(\d+) ajustes", resumo)
            checa(bool(m_resumo), f"o resumo conta os ajustes: {resumo[:44]}…")
            with open(os.path.join(RAIZ, "meow.conf.exemplo"), encoding="utf-8") as fh:
                chaves_no_exemplo = len(re.findall(r"^[A-Z_]+=", fh.read(), re.M))
            checa(m_resumo and int(m_resumo.group(1)) == chaves_no_exemplo,
                  f"o resumo conta {m_resumo.group(1) if m_resumo else '?'} ajustes"
                  f" e o meow.conf.exemplo cataloga {chaves_no_exemplo}")
            # Sao 12 assuntos mais o Inicio, num nivel so'.
            n_trilho = pag.locator("#trilho button").count()
            checa(10 <= n_trilho <= 16, f"o trilho tem {n_trilho} paginas")

            print("\n2. CADA SECAO RENDERIZA (uma a uma, medindo o que apareceu)")
            nomes = pag.locator("#trilho button").all_text_contents()
            vazias = []
            # Abrir as 23 secoes ja custa cinco segundos; colher o retrato de
            # cada cartao enquanto ele esta na tela custa um `evaluate` por
            # secao e paga as regras dos passos 6, 7 e 15 sem uma segunda volta
            # pela pagina inteira.
            censo = {}
            for i in range(len(nomes)):
                pag.locator("#trilho button").nth(i).click()
                pag.wait_for_timeout(220)
                if pag.locator("#conteudo").inner_text().strip() == "":
                    vazias.append(nomes[i][:28])
                # O nome do botao do trilho traz a contagem colada no fim
                # ("A forma do painel e do dock12"); no relatorio isso vira um
                # numero sem dono, entao ele sai aqui.
                nome_da_aba = re.sub(r"\s*\d+$", "", nomes[i].strip())
                for c in pag.evaluate(CENSO_JS):
                    censo.setdefault(c["chave"], dict(c, secao=nome_da_aba))
            checa(not vazias, f"as {len(nomes)} secoes desenham conteudo"
                              + (f" — VAZIAS: {vazias}" if vazias else ""))

            chaves = pag.evaluate(ESQUEMA_JS)
            # O resumo do topo conta as chaves do catálogo; isto confere que
            # todas chegaram a ALGUMA aba.
            por_modo = pag.evaluate(
                "() => DECISOES.filter((d) => d.modo).map((d) => ({modo: d.modo.chave,"
                " chaves: Object.values(d.modo.por).flat()}))")
            reveladas = {c for d in por_modo for c in d["chaves"]}
            modos_sem_cartao = sorted(d["modo"] for d in por_modo if d["modo"] not in censo)
            checa(not modos_sem_cartao,
                  "o modo de cada seletor tem cartão"
                  + (f" — {modos_sem_cartao}" if modos_sem_cartao else ""))
            sem_cartao = sorted(k["chave"] for k in chaves
                                if k["chave"] not in censo and not k["sem_programa"]
                                and k["chave"] not in reveladas)
            com_cartao_sem_programa = sorted(k["chave"] for k in chaves
                                             if k["sem_programa"] and k["chave"] in censo)
            checa(not com_cartao_sem_programa,
                  "a chave de programa ausente nao ganha cartao"
                  + (f" — {com_cartao_sem_programa}" if com_cartao_sem_programa else ""))
            checa(not sem_cartao,
                  f"as {len(chaves)} chaves do esquema têm cartão em alguma aba"
                  + (f" — SEM CARTÃO: {sem_cartao[:6]}" if sem_cartao else ""))

            print("\n3. A BUSCA")
            def busca(texto):
                pag.fill("#busca", texto)
                pag.wait_for_timeout(320)
                return pag.locator("#conteudo .cartao, #conteudo .acao").count()
            checa(busca("cursor") > 0, "buscar 'cursor' devolve cartao")
            checa(busca("maquina") > 0, "buscar sem acento acha 'máquina'")
            checa(busca("zzzznaoexiste") == 0, "busca sem resultado nao inventa cartao")
            busca("")

            print("\n4. AS PREVIAS (o motivo de a pagina existir)")

            def secao(parte):
                """Abre uma secao pelo texto, na ordem que evita o vizinho errado.

                O menu tem dois niveis desde 01/09/2026, e "Icones" existe DUAS
                vezes: como rotulo de secao (com o subtopico `Geral` embaixo) e
                dentro de "Icones e gato", na lista de acoes. Procurar por
                prefixo achava o segundo e o teste media a tela errada — foi o
                que fez a grade de icones aparecer como zero. A ordem certa e:
                botao exato, depois rotulo de secao, e so entao prefixo.
                """
                exato = pag.locator("#trilho button", has_text=re.compile(
                    r"^\s*" + re.escape(parte) + r"\s*\d*\s*$"))
                if exato.count():
                    exato.first.click()
                    pag.wait_for_timeout(600)
                    return
                achou = pag.evaluate(
                    """(nome) => {
                      const r = [...document.querySelectorAll('.secao-menu')]
                        .find(x => x.textContent.trim() === nome);
                      let e = r && r.nextElementSibling;
                      while (e && e.tagName !== 'BUTTON') e = e.nextElementSibling;
                      if (e) { e.click(); return true; }
                      return false;
                    }""", parte)
                if not achou:
                    pag.locator("#trilho button", has_text=re.compile(
                        r"^\s*" + re.escape(parte))).first.click()
                pag.wait_for_timeout(600)

            # "Aparencia" era o bloco de arquivo; agora a pagina e o assunto, e
            # as paletas moram em "Cor e tela".
            secao("Cor e tela")
            checa(pag.locator("#conteudo .tira").count() >= 4, "FLAVOR mostra as paletas")
            checa(pag.locator("#conteudo .cores-grade button, #conteudo .amostras button").count() > 8,
                  "ACCENT mostra as cores da paleta")

            # `_temas_de_cursor` diz o que a chave CURSOR aceita, e e' dela que
            # saem os BOTOES; `_prev_cursores` diz o que vira DESENHO.
            n_opcoes, n_previas = pag.evaluate("""async () => {
              const esq = await (await fetch('/api/esquema')).json();
              const prev = await (await fetch('/api/previas?tipo=cursor')).json();
              const k = (esq.chaves || []).find((c) => c.chave === 'CURSOR');
              return [((k && k.opcoes) || []).length, (prev.itens || []).length];
            }""")
            #   So' a igualdade passa em VERDE com `0 == 0`, e ha' dois jeitos
            #   baratos de chegar la': a chave CURSOR sumir do esquema (`k` vem
            #   undefined e o `|| []` devolve zero) ou `/api/previas` responder
            #   `{erro: ...}` (o `prev.itens || []` tambem devolve zero). Nos
            #   dois casos a pagina nao oferece ponteiro NENHUM, que e' pior do
            #   que a divergencia que este passo veio pegar — e ele aprovaria.
            checa(n_opcoes > 0 and n_opcoes == n_previas,
                  f"o ponteiro tem uma prévia por opção ({n_previas} de {n_opcoes})")
            # O MESMO MOTIVO DA GRADE DE ICONES LOGO ABAIXO, e que aqui faltava:
            # os gatos chegam por `/previa`, uma requisicao por desenho.
            secao("Logo do sistema")
            n_gatos = 0
            for _ in range(10):
                n_gatos = pag.locator("#conteudo img").count()
                if n_gatos >= 2:
                    break
                pag.wait_for_timeout(400)
            checa(n_gatos >= 2, f"LOGO mostra os {n_gatos} gatos desenhados")
            secao("Ícones")
            # As miniaturas chegam por `/previa`, uma requisicao por icone: contar
            # no instante do clique media a rede, nao a pagina.
            n_icones = 0
            for _ in range(12):
                pag.wait_for_timeout(400)
                n_icones = pag.locator("#conteudo img").count()
                if n_icones > 20:
                    break
            checa(n_icones > 20, f"a grade de icones mostra {n_icones} icones do tema instalado")
            secao("Papel de parede")
            pag.wait_for_timeout(1500)
            n_fotos = pag.locator("#conteudo figure").count()
            leva = pag.evaluate("() => PRIMEIRA_LEVA_GALERIA")
            checa(n_fotos >= min(leva, 20), f"a galeria mostra {n_fotos} papeis de parede")
            mais = pag.locator("#conteudo button", has_text="Mostrar mais")
            if mais.count():
                mais.first.click()
                pag.wait_for_timeout(900)
                depois = pag.locator("#conteudo figure").count()
                checa(depois > n_fotos, f"«Mostrar mais» traz mais fotos ({n_fotos} -> {depois})")
                n_fotos = depois
            if FOTOS:
                pag.screenshot(path=f"{DESTINO_FOTOS}/galeria.png")

            print("\n5. AS ABAS DA GALERIA")
            for aba in ("Noite", "Dia", "Recusadas", "No carrossel"):
                pag.locator("#conteudo .abas button", has_text=aba).first.click()
                pag.wait_for_timeout(900)
                checa(pag.locator("#conteudo figure, #conteudo .sem-previa").count() > 0,
                      f"a aba '{aba}' responde")

            print("\n6. A MARCACAO SEGUE O CLIQUE")
            # "Cliquei na tira `latte`. Prova-se o contrario: depois do clique,
            # o botao clicado e o unico marcado.
            formas = (
                ("amostra de flavor", lambda k: k["previa"] == "flavor"),
                ("bolinha de cor", lambda k: k["previa"] == "cor"),
                ("imagem", lambda k: k["previa"] in ("gato", "cursor")),
                ("botão de opção", lambda k: k["opcoes"] and not k["previa"]
                                             and k["chave"] != "PACK"),
            )
            for rotulo, condicao in formas:
                # O REPRESENTANTE E O PRIMEIRO QUE DA PARA CLICAR, e nao o
                # primeiro da lista: uma chave pode ter uma opcao so (o `CURSOR`
                # ficou assim quando os apelidos duplicados sairam) e ali nao ha
                # gesto a medir.
                candidatos = [k for k in chaves if condicao(k)]
                if not candidatos:
                    continue
                escolhido = None
                for j, k in enumerate(candidatos):
                    cartao, botoes = opcoes_na_tela(pag, k["chave"], 12 if j == 0 else 2)
                    alvo = alvo_clicavel(botoes)
                    if alvo is not None:
                        escolhido = (k, cartao, alvo)
                        break
                if escolhido is None:
                    checa(False, f"{rotulo}: nenhuma das {len(candidatos)} chaves"
                                 " desenhou opção para clicar")
                    continue
                k, cartao, alvo = escolhido
                antes = marcado_em(cartao)
                valor = alvo.get_attribute("data-valor")
                tipo = cartao.evaluate(
                    """(a) => { const b = a.querySelector('button[data-valor]');
                                return b ? (b.parentElement.className || '') : ''; }""")
                alvo.click()
                pag.wait_for_timeout(400)
                agora = marcado_em(cartao)
                checa(agora == valor,
                      f"{k['chave']} ({tipo or rotulo}): clicar em '{valor}' move a marcação"
                      f" — antes '{antes}', agora '{agora}'")
                checa(cartao.evaluate("(a) => a.classList.contains('nao-salvo')"),
                      f"{k['chave']}: e o cartão fica marcado como não salvo")
            descartar(pag)

            print("\n7. AS FICHAS DE LISTA DESENHAM O QUE A ESCOLHA DIZ")
            # As duas metades do gesto sao conferidas aqui, nas duas familias
            # de lista que o esquema declara (virgula e dois-pontos) — e o que
            # entra e sai e SEMPRE ficha inventada pelo teste, nunca uma das
            # dela.
            postica = ("zzz-teste-navegador-a", "zzz-teste-navegador-b")
            for rotulo, condicao in (("vírgula", lambda k: k["lista"]),
                                     ("dois-pontos", lambda k: k["pathsep"])):
                candidatos = [k for k in chaves if condicao(k)]
                if not candidatos:
                    continue
                k, cartao = None, None
                for c in candidatos:
                    k, cartao = c, cartao_da_chave(pag, c["chave"])
                    if cartao.locator(".fichas").count():
                        break
                if not cartao.locator(".fichas").count():
                    checa(False, f"{rotulo}: nenhuma das {len(candidatos)} listas"
                                 " virou fichas na tela")
                    continue
                n0 = cartao.locator(".ficha").count()
                for nome in postica:
                    cartao.locator("input.nova").fill(nome)
                    cartao.locator("input.nova").press("Enter")
                    pag.wait_for_timeout(400)
                n2 = cartao.locator(".ficha").count()
                checa(n2 == n0 + 2,
                      f"{k['chave']} ({rotulo}): dois Enter desenham DUAS fichas"
                      f" — {n0} → {n2}")
                texto = cartao.locator(".fichas").inner_text()
                checa(all(nome in texto for nome in postica),
                      f"{k['chave']}: a segunda ficha não apagou a primeira")
                for nome in postica:
                    tirar = cartao.locator(f'.ficha button[aria-label="Tirar {nome}"]')
                    if tirar.count():
                        tirar.first.click()
                        pag.wait_for_timeout(400)
                n3 = cartao.locator(".ficha").count()
                checa(n3 == n0, f"{k['chave']}: o × tira a ficha da tela na hora"
                                f" — {n2} → {n3}")
            checa(not pag.locator("#salvar-conta").is_visible(),
                  "e desfazer o gesto à mão devolve a lista ao disco: a contagem some sozinha")
            descartar(pag)

            print("\n8. O DESENHO AO VIVO SEGUE O CONTROLE")
            # Uma previa que nao acompanha o controle e pior que previa nenhuma:
            # ela mostra, com confianca, o estado errado.
            #
            # A regra: toda previa que ACOMPANHA o controle tem de reagir a ele.
            ESTILOS_JS = """
              () => [...document.querySelectorAll('#conteudo [style]')]
                .filter((e) => !['INPUT', 'BUTTON', 'OUTPUT', 'SELECT', 'TEXTAREA']
                                 .includes(e.tagName))
                .map((e) => e.tagName + ':' + e.getAttribute('style')).join('|')
                + '|' + [...document.querySelectorAll('#conteudo canvas')]
                  .map((c) => { try { return c.toDataURL(); } catch (e) { return ''; } }).join('|')
            """

            def desenho_parado(pag):
                """O retrato dos desenhos, depois de a tela parar de se mexer.

                As miniaturas chegam pela rede e mudam o `style` de quem estava
                esperando por elas; comparar antes disso acusaria movimento que
                nao veio do controle. Duas leituras iguais = tela parada."""
                anterior = pag.evaluate(ESTILOS_JS)
                for _ in range(6):
                    pag.wait_for_timeout(500)
                    agora = pag.evaluate(ESTILOS_JS)
                    if agora == anterior:
                        return agora
                    anterior = agora
                return anterior

            # Com texto na busca, `render` mostra os RESULTADOS e nao a aba — e
            # o `secao()` abaixo clica no trilho sem efeito visivel.
            def mexer_no_controle(cartao):
                """Move o controle do cartao e diz o gesto feito, ou None."""
                faixa = cartao.locator("input[type=range]")
                if faixa.count() and faixa.first.is_disabled():
                    # DESLIZANTE DESABILITADO E' O ESTADO "Deixar como esta".
                    # `FORMA_RAIO_PAINEL=""` no conf dela desenha o deslizante
                    # cinza, e nenhuma tecla o move — corretamente.
                    return None
                if faixa.count():
                    # `End` (ou `Home`, quando ja esta no fim) e um gesto de
                    # teclado de verdade: o proprio navegador dispara `input` e
                    # `change`, como o dedo dela soltando o deslizante.
                    faixa.first.focus()
                    no_fim = faixa.first.input_value() == (faixa.first.get_attribute("max") or "")
                    pag.keyboard.press("Home" if no_fim else "End")
                    return "deslizante ao " + ("mínimo" if no_fim else "máximo")
                botao = alvo_clicavel(cartao.locator("button[data-valor]"))
                if botao is not None:
                    valor = botao.get_attribute("data-valor")
                    botao.click()
                    return f"botão '{valor}'"
                campo = cartao.locator("input[type=text], textarea")
                if campo.count():
                    campo.first.fill("13")
                    campo.first.press("Enter")
                    return "campo com 13"
                return None

            pag.fill("#busca", "")
            pag.wait_for_timeout(300)
            por_previa = {}
            for k in chaves:
                # O CAMPO `previa` NOMEIA DUAS COISAS DIFERENTES, e so' uma
                # delas cabe aqui.
                #
                # A LISTA E' DE NAO-DESENHOS, e nao de desenhos, de proposito:
                # assim uma previa de desenho NOVA entra coberta sozinha, e uma
                # previa de controle nova reprova aqui na primeira rodada — que
                # e' barulhento, e e' o lado certo para errar.
                if k["previa"] in ("", "flavor", "cor", "gato", "cursor", "areas"):
                    continue
                if k["chave"] in censo:
                    por_previa.setdefault(k["previa"], []).append(k)

            for previa, candidatos in por_previa.items():
                # TENTA ATE TRES CHAVES DA MESMA PREVIA, e cobra que UMA mova o
                # desenho.
                LIDAS = ("RAIO", "MARGEM", "ESPACO", "RECHEIO", "OPACIDADE",
                         "TEMPERATURA", "TEXTURA")
                candidatos = sorted(
                    candidatos,
                    key=lambda k: 0 if any(p in k["chave"] for p in LIDAS) else 1)
                moveu, tentadas = None, []
                for k in candidatos[:4]:
                    # PELA SECAO, E NAO PELA BUSCA: o desenho da barra e um so
                    # para o grupo inteiro e o `render` so o monta sem busca.
                    secao(censo[k["chave"]]["secao"])
                    cartao = pag.locator(f'#conteudo article[data-chave="{k["chave"]}"]')
                    if not cartao.count():
                        tentadas.append(f"{k['chave']} (sem cartão na aba)")
                        continue
                    antes = desenho_parado(pag)
                    gesto = mexer_no_controle(cartao)
                    if gesto is None:
                        tentadas.append(f"{k['chave']} (sem controle)")
                        continue
                    pag.wait_for_timeout(600)
                    tentadas.append(f"{k['chave']} ({gesto})")
                    if pag.evaluate(ESTILOS_JS) != antes:
                        moveu = tentadas[-1]
                        break
                checa(moveu is not None,
                      f"a prévia '{previa}' é redesenhada quando o controle muda"
                      + (f" — {moveu}" if moveu else f" — NADA MUDOU em: {tentadas}"))
            descartar(pag)

            print("\n9. AS ESCOLHAS ESPERAM O SALVAR")
            pag.fill("#busca", "LOG_NIVEL")
            pag.wait_for_timeout(400)
            # O valor no arquivo continua `debug`/`info`; o que a tela escreve
            # passou pelo `ROTULO_DE_VALOR`, e agora e
            # "Detalhado"/"Informacao".
            alvo = "Detalhado" if log_nivel_inicial != "debug" else "Informação"
            pag.locator("#conteudo .cartao button", has_text=re.compile(f"^{alvo}$")).first.click()
            pag.wait_for_timeout(500)
            checa(valor_de("LOG_NIVEL") == log_nivel_inicial,
                  "escolher NAO grava no meow.conf — o disco so muda no Salvar")
            checa(pag.locator("#salvar-conta").is_visible(), "a contagem do Salvar aparece")
            checa("1 escolha" in pag.locator("#salvar-conta").inner_text(),
                  "a barra conta a escolha")

            print("\n   ... e sobrevivem a troca de aba")
            pag.fill("#busca", "")
            secao("Instalação")
            # O teste ia para "Terminal" e cobrava um cartao marcado — mas
            # `LOG_NIVEL` nunca esteve la, e mora em "Manutencao".
            secao("Manutenção")
            checa(pag.locator("#salvar-conta").is_visible(),
                  "depois de duas trocas de aba, a escolha continua la")
            checa(pag.locator('#conteudo article[data-chave="LOG_NIVEL"].nao-salvo').count() >= 1,
                  "o cartao continua marcado como nao salvo")

            print("\n   ... e o Descartar devolve tudo")
            descartar_tudo(pag)
            pag.wait_for_timeout(500)
            checa(not pag.locator("#salvar-conta").is_visible()
                  and not pag.locator("#botao-descartar").is_visible(),
                  "Descartar limpa a contagem e sai da barra")
            checa(valor_de("LOG_NIVEL") == log_nivel_inicial, "e o disco nunca foi tocado")

            print("\n   ... e o Salvar continua na barra")
            # Ela sumia sem escolha pendente, e ela leu isso como o botão
            # removido: "removeu o botão Salvar, que salva e aplica".
            checa(pag.locator("#botao-salvar").is_visible(),
                  "sem escolha pendente, o Salvar continua na tela")
            checa("Aplica" in (pag.locator("#botao-salvar").get_attribute("data-balao") or ""),
                  "e diz que aplica o que ja' esta' salvo")

            print("\n10. UMA ACAO, COM SAIDA AO VIVO")
            # O «O que está no ar agora» só lê; desde a P90 a Instalação não o
            # mostra em cartão, e quem o roda é o mesmo `rodar()` dos cartões.
            secao("Instalação")
            pag.evaluate("() => rodar(ESQUEMA.acoes.find((a) => a.id === 'status'), '')")
            saida = ""
            # PACIÊNCIA DE 25 s, e não de 10: o `meow status` consulta systemd,
            # cosmic-randr e o tema inteiro.
            for _ in range(50):
                pag.wait_for_timeout(500)
                saida = pag.locator("#resultado #saida").inner_text()
                if len(saida) > 200:
                    break
            checa(len(saida) > 200, f"'Estado da maquina' devolveu {len(saida)} caracteres")
            checa("meow" in saida.lower() or "flavor" in saida.lower(),
                  "a saida e a do comando de verdade")

            print("\n10b. A JANELA DE RESULTADO: SOBRE O FUNDO, E O LOG NÃO SE PERDE")
            jan = pag.evaluate("""() => {
              const d = document.getElementById('resultado');
              const r = d.getBoundingClientRect();
              const s = document.getElementById('saida').getBoundingClientRect();
              return { aberta: d.open, modal: d.matches(':modal'),
                       dentro: r.left >= 0 && r.right <= innerWidth && r.top >= 0 && r.bottom <= innerHeight,
                       saida: Math.round(s.height), janela: innerHeight,
                       gaveta: !!document.getElementById('gaveta') };
            }""")
            checa(jan["aberta"] and jan["modal"], "a ação abre a janela de resultado, modal, sobre o fundo")
            checa(jan["dentro"], "e a janela cabe inteira na tela")
            checa(jan["saida"] >= 120, f"o log tem altura para ler ({jan['saida']} px)")
            checa(not jan["gaveta"], "e a gaveta de baixo não existe mais")
            rolavel = pag.evaluate("""() => {
              const s = document.getElementById('saida');
              s.scrollTop = 0;
              s.dispatchEvent(new Event('scroll'));
              return s.scrollHeight > s.clientHeight + 4;
            }""")
            pag.wait_for_timeout(250)
            if rolavel:
                aviso = pag.locator("#mais-abaixo")
                visivel = aviso.count() == 1 and aviso.is_visible()
                checa(visivel, "com a saída rolada para cima, a pastilha «mais N "
                               "linhas abaixo» aparece")
                texto_aviso = aviso.inner_text() if aviso.count() else ""
                checa(bool(re.fullmatch(r"mais \d+ linhas? abaixo", texto_aviso)),
                      f"e ela conta as linhas: «{texto_aviso}»")
                if visivel:
                    aviso.click()
                    pag.wait_for_timeout(300)
                    checa(not aviso.is_visible(),
                          "e clicar nela devolve o fim da saída — a pastilha some")
                # Fechada a janela, a conta não roda (sem caixa, ela daria a
                # saída inteira); reaberta, é a mesma.
                fechada = pag.evaluate("""() => {
                  const d = document.getElementById('resultado');
                  const s = document.getElementById('saida');
                  s.scrollTop = 0;
                  s.dispatchEvent(new Event('scroll'));
                  const a = document.getElementById('mais-abaixo');
                  const antes = a ? a.textContent : '';
                  d.close();
                  s.dispatchEvent(new Event('scroll'));
                  d.showModal();
                  const b = document.getElementById('mais-abaixo');
                  return { antes, depois: b ? b.textContent : '',
                           linhas: s.childElementCount };
                }""")
                checa(fechada["antes"] == fechada["depois"],
                      f"fechar e reabrir não mexe na contagem: «{fechada['antes']}» "
                      f"-> «{fechada['depois']}»")
                abaixo = re.search(r"\d+", fechada["depois"])
                checa(bool(abaixo) and int(abaixo.group()) < fechada["linhas"],
                      f"e ela não conta a saída inteira: {abaixo.group() if abaixo else '?'} "
                      f"de {fechada['linhas']} linhas")
            else:
                print("  -- a saída coube inteira na janela; nada a indicar abaixo")
            pag.wait_for_function("() => TRABALHO === null", timeout=60000)
            pag.locator("#resultado-ok").click()
            checa(not pag.evaluate("() => document.getElementById('resultado').open"),
                  "o OK fecha a janela")

            print("\n11. O ENSAIO SAIU DA PÁGINA")
            # O interruptor não pode voltar por engano, e a página não pode
            # guardar quem pergunte por ele.
            checa(pag.locator("#seco").count() == 0,
                  "não ha interruptor de ensaio na barra")
            checa(pag.evaluate("() => typeof ensaiando") == "undefined",
                  "e a página não tem mais quem pergunte se esta' ensaiando")

            print("\n12. CONFERIR NÃO ESCREVE")
            secao("Instalação")
            md5_antes = md5_conf()
            # O doctor que só confere não tem cartão desde a P90 (a Instalação
            # tem «Conferir e consertar»); ele continua sendo uma ação.
            pag.evaluate("() => rodar(ESQUEMA.acoes.find((a) => a.id === 'doctor'), '')")
            pag.wait_for_function("() => TRABALHO === null", timeout=120000)
            checa(md5_conf() == md5_antes, "o doctor so' le: o meow.conf não mudou")
            if pag.evaluate("() => document.getElementById('resultado').open"):
                pag.locator("#resultado-ok").click()

            print("\n13. TELA ESTREITA (a pagina nao pode rolar de lado)")
            for larg in (320, 375, 414, 768):
                pag.set_viewport_size({"width": larg, "height": 800})
                pag.wait_for_timeout(400)
                excesso = pag.evaluate(
                    "document.documentElement.scrollWidth - document.documentElement.clientWidth")
                checa(excesso <= 1, f"em {larg}px nao rola de lado (excesso {excesso}px)")
                if FOTOS and larg == 375:
                    pag.screenshot(path=f"{DESTINO_FOTOS}/375.png", full_page=True)
            pag.set_viewport_size({"width": 1500, "height": 1000})

            print("\n14. TECLADO E FOCO")
            pag.locator("#conteudo").click(position={"x": 5, "y": 5})
            pag.keyboard.press("/")
            pag.wait_for_timeout(200)
            checa(pag.evaluate("document.activeElement.id") == "busca",
                  "a tecla '/' leva o foco para a busca")
            pag.keyboard.press("Escape")

            print("\n15. TODA ACAO QUE A PAGINA OFERECE TEM DONO NO SERVIDOR")
            # "Banir" e "Devolver", um por imagem da galeria, chamavam
            # `wallpaper_banir` e `wallpaper_desbanir`; o `ACOES` do servidor
            # nao tem nenhum dos dois, e `rodarNaGaleria` desiste em silencio
            # quando o `find` volta `undefined`.
            #
            # O que a pagina PEDE nao da para ler do DOM: o id mora dentro do
            # `onclick`.
            ids_do_servidor = set(pag.evaluate("() => (ESQUEMA.acoes || []).map((a) => a.id)"))
            with open(os.path.join(RAIZ, "app", "pagina", "app.js"), encoding="utf-8") as fh:
                fonte_js = fh.read()
            pedidas = set(pag.evaluate(ACOES_NO_DOM_JS)) | set(ACOES_NO_FONTE.findall(fonte_js))
            checa(len(pedidas) >= 2,
                  f"a varredura achou {len(pedidas)} ações pedidas pelo nome na página")
            orfas = sorted(pedidas - ids_do_servidor)
            checa(not orfas,
                  f"as {len(pedidas)} ações pedidas existem no servidor"
                  + (f" — SEM DONO: {orfas}" if orfas else ""))

            print("\n16. O CONTROLE CASA COM O QUE O ESQUEMA DECLARA")
            # "Digitei 'gigante' no ESCALA_TELA e sai do campo: aceito em
            # silencio." Um campo de texto para uma chave que so aceita quatro
            # valores obriga a decorar os quatro e ainda deixa passar o quinto.
            por_chave = {k["chave"]: k for k in chaves}
            fechadas = [c for c in censo.values()
                        if por_chave.get(c["chave"], {}).get("opcoes")]
            texto_livre = sorted(c["chave"] for c in fechadas if c["texto"])
            checa(not texto_livre,
                  f"nenhuma das {len(fechadas)} chaves de opções fechadas virou campo de texto"
                  + (f" — TEXTO LIVRE: {texto_livre}" if texto_livre else ""))

            com_faixa = [c for c in censo.values() if por_chave.get(c["chave"], {}).get("faixa")
                         and not por_chave.get(c["chave"], {}).get("hora_cheia")]
            sem_deslizante = sorted(c["chave"] for c in com_faixa if not c["faixa"])
            checa(not sem_deslizante,
                  f"as {len(com_faixa)} chaves de faixa numérica viraram deslizante"
                  + (f" — SEM DESLIZANTE: {sem_deslizante}" if sem_deslizante else ""))

            listas = [c for c in censo.values()
                      if por_chave.get(c["chave"], {}).get("lista")
                      or por_chave.get(c["chave"], {}).get("pathsep")]
            sem_fichas = sorted(c["chave"] for c in listas if not c["fichas"])
            checa(not sem_fichas,
                  f"as {len(listas)} chaves de lista viraram fichas"
                  + (f" — SEM FICHAS: {sem_fichas}" if sem_fichas else ""))

            # "Os TRES mostram o mesmo bloco: 'O nome do tema de icones que este
            # projeto constroi…'" — o titulo do vizinho vira o titulo desta
            # chave quando a ajuda e herdada de um bloco que cobre varias.
            repetidos = {}
            por_aba = {}
            for c in censo.values():
                if c["titulo"]:
                    por_aba.setdefault(c["secao"], {}).setdefault(
                        c["titulo"].strip(), []).append(c["chave"])
            for aba, titulos in por_aba.items():
                for t, ks in titulos.items():
                    if len(ks) > 1:
                        repetidos[f"{aba} ▸ {t}"] = ks
            quantos = sum(len(t) for t in por_aba.values())
            checa(not repetidos,
                  f"cada cartão tem título próprio na aba dele ({quantos} títulos)"
                  + (f" — {len(repetidos)} REPETIDOS, ex.: "
                     + "; ".join(f"{t[:40]}… = {ks}" for t, ks in list(repetidos.items())[:2])
                     if repetidos else ""))

            print("\n17. O DESENHO ACOMPANHA O DEDO, E NAO GRAVA NADA")
            # Ate' entao o deslizante so' mexia no NUMERO enquanto ela
            # arrastava; o desenho so' mudava ao SOLTAR, pelo caminho comprido
            # do `aplica()` + `render()`.
            #
            # Duas coisas sao medidas aqui, e a segunda importa tanto quanto a
            # primeira: o desenho muda, E a barra do Salvar NAO aparece.
            if pag.locator("#botao-descartar").is_visible():
                descartar_tudo(pag)
                pag.wait_for_timeout(700)
            vivas = paradas = 0
            for aba in ("Cor e tela", "Logo do sistema", "Painel e dock",
                        "Dia e noite", "Modo de leitura"):
                secao(aba)
                pag.wait_for_timeout(700)
                desenhos = pag.locator(".previa-bloco, #conteudo .grade-barras")
                puxadores = pag.locator("#conteudo input[type=range]:not([disabled])")
                if not desenhos.count() or not puxadores.count():
                    continue
                antes = [desenhos.nth(i).inner_html() for i in range(desenhos.count())]
                # As duas pontas nunca sao as duas o valor da maquina.
                mudou = False
                for ponta in ("min", "max"):
                    puxadores.first.evaluate("""(el, ponta) => {
                      el.value = ponta === 'min' ? el.min : el.max;
                      el.dispatchEvent(new Event('input', {bubbles: true}));
                    }""", ponta)
                    pag.wait_for_timeout(500)
                    agora = pag.locator(".previa-bloco, #conteudo .grade-barras")
                    depois = [agora.nth(i).inner_html() for i in range(agora.count())]
                    if any(a != b for a, b in zip(antes, depois)):
                        mudou = True
                        break
                gravou = pag.locator("#salvar-conta:visible").count() > 0
                if mudou and not gravou:
                    vivas += 1
                else:
                    paradas += 1
                    print(f"   XX {aba}: desenho mudou={mudou} gravou={gravou}")
            checa(vivas > 0 and paradas == 0,
                  f"as {vivas} abas com deslizante repintam o desenho durante o arrasto")
            checa(not pag.locator("#salvar-conta:visible").count(),
                  "e arrastar nao acendeu a barra do Salvar — nada foi escolhido")
            # As outras idas e voltas deste arquivo esperam o mesmo seletor.
            pag.reload()
            pag.wait_for_selector("#trilho button")
            pag.wait_for_timeout(1500)

            print("\n17b. O DESLIZANTE NASCE LIVRE, E OS DOIS BOTOES")
            # Um deslizante livre marcando 24 e um que ESCOLHEU 24 sao coisas
            # diferentes — o COSMIC se comporta diferente nos dois — e a unica
            # coisa que os separa agora e' o desenho.
            if pag.locator("#botao-descartar").is_visible():
                descartar_tudo(pag)
                pag.wait_for_timeout(700)
            travados = usar_numero = deixar = restaurar = 0
            comoesta = {"classe": 0, "valuetext": 0, "palavra": 0}
            nomes_abas = pag.locator("#trilho button").all_text_contents()
            for i in range(len(nomes_abas)):
                pag.locator("#trilho button").nth(i).click()
                pag.wait_for_timeout(240)
                conta = pag.evaluate(r"""() => {
                  const faixas = [...document.querySelectorAll('#principal input[type=range]')];
                  const btn = [...document.querySelectorAll('#principal button')];
                  const texto = (b) => b.textContent.trim().replace(/\s+/g, ' ');
                  const livres = faixas.filter(s => s.classList.contains('faixa-comoesta'));
                  return {
                    travados: faixas.filter(s => s.disabled).length,
                    usar: btn.filter(b => /Usar n.mero/.test(texto(b))).length,
                    deixar: btn.filter(b => /Deixar como est/.test(texto(b))).length,
                    restaurar: btn.filter(b => /^Restaurar ao padr/.test(texto(b))).length,
                    classe: livres.length,
                    valuetext: livres.filter(s => (s.getAttribute('aria-valuetext') || '')
                                                    .length > 0).length,
                    palavra: livres.filter(s => !/^\s*-?[\d.,]+\s*$/.test(
                      (s.parentNode.querySelector('output') || {}).textContent || '')).length,
                  };
                }""")
                travados += conta["travados"]
                usar_numero += conta["usar"]
                deixar += conta["deixar"]
                restaurar += conta["restaurar"]
                for k in comoesta:
                    comoesta[k] += conta[k]
            checa(travados == 0,
                  f"nenhum deslizante nasce travado nas {len(nomes_abas)} abas"
                  f" ({travados}; antes de 21/09/2026 eram 17)")
            checa(usar_numero == 0,
                  f"nao ha botao «Usar numero» na pagina ({usar_numero}; antes 17)")
            checa(deixar == 0 and restaurar == 0,
                  f"nem «Deixar como esta» nem «Restaurar ao padrao» sobre o valor"
                  f" de fabrica ({deixar} e {restaurar})")
            # O TERCEIRO ESTADO CONTINUA NA TELA, E OS TRES SINAIS ANDAM JUNTOS.
            checa(comoesta["classe"] > 0
                  and comoesta["valuetext"] == comoesta["classe"]
                  and comoesta["palavra"] == comoesta["classe"],
                  f"os {comoesta['classe']} deslizantes em «como esta» trazem os tres"
                  f" sinais: trilha em traco, aria-valuetext ({comoesta['valuetext']})"
                  f" e numero que nunca aparece sozinho ({comoesta['palavra']})")

            # A aba e' a que ele citou, e o cartao acende com o «Aplicar» que
            # fecha aquela escolha ali mesmo.
            secao("Painel e dock")
            pag.wait_for_timeout(600)
            livre = pag.locator("#principal input[type=range].faixa-comoesta")
            if livre.count():
                antes_marcados = pag.locator("#principal .cartao.nao-salvo").count()
                # UM PUNHO, E NAO UM SELETOR — o seletor tem `.faixa-comoesta`
                # dentro, e a primeira coisa que o arrasto faz e' TIRAR essa
                # classe: reavaliar o locator depois disso acharia o deslizante
                # SEGUINTE, e o teste mediria um elemento que nao foi tocado.
                punho = livre.first.element_handle()
                punho.evaluate("""(el) => {
                  el.value = el.max;
                  el.dispatchEvent(new Event('input', {bubbles: true}));
                }""")
                pag.wait_for_timeout(200)
                sinais = punho.evaluate("""(el) => ({
                  classe: el.classList.contains('faixa-comoesta'),
                  valuetext: el.hasAttribute('aria-valuetext'),
                  valor: el.value,
                  saida: el.parentNode.querySelector('output').textContent,
                })""")
                checa(not sinais["classe"] and not sinais["valuetext"]
                      and sinais["saida"] == sinais["valor"],
                      f"o primeiro pixel de arrasto tira os sinais de «como esta»"
                      f" e o numero passa a ser a escolha ({sinais['saida']})")
                punho.dispatch_event("change")
                pag.wait_for_timeout(500)
                marcados = pag.locator("#principal .cartao.nao-salvo").count()
                aplicar = pag.locator("#principal .cartao.nao-salvo .btn-aplicar")
                checa(marcados == antes_marcados + 1,
                      f"soltar a alca acende o cartao ({antes_marcados} -> {marcados})")
                checa(aplicar.count() == marcados and aplicar.count() > 0,
                      f"e todo cartao aceso ganha um «Aplicar» ({aplicar.count()})")
                checa(pag.locator("#principal .cartao:not(.nao-salvo)"
                                  " .btn-aplicar").count() == 0,
                      "nenhum cartao sem pendencia mostra «Aplicar»")
                descartar_tudo(pag)
                pag.wait_for_timeout(500)
                checa(pag.locator("#principal .btn-aplicar").count() == 0,
                      "e o «Aplicar» some junto com a pendencia")
            else:
                checa(False, "nenhum deslizante em «como esta» na aba Painel e dock")

            print("\n18. O SALVAR RECUSA ANTES DE ESCREVER")
            # Ela grava as escolhas e comeca o instalador na mesma chamada, e a
            # unica coisa entre ela e um meow.conf pela metade e' a peneira que
            # vem ANTES.
            antes_conf = md5_conf()
            r = pag.evaluate("""async () => {
              const res = await fetch('/api/salvar', {
                method: 'POST',
                headers: { 'X-Meow-Token': TOKEN, 'Content-Type': 'application/json' },
                body: JSON.stringify({ mudancas: { LOG_NIVEL: 'banana', FLAVOR: 'mocha' } }) });
              return { status: res.status, corpo: await res.json() };
            }""")
            recusadas = [x.get("chave") for x in (r["corpo"].get("recusadas") or [])]
            checa(r["status"] == 400 and recusadas == ["LOG_NIVEL"]
                  and not r["corpo"].get("trabalho"),
                  f"um valor recusado barra o Salvar inteiro ({r['status']}, {recusadas})")
            checa(md5_conf() == antes_conf, "e o meow.conf não foi tocado")

            print("\n19. OS DOIS LADOS DE CADA PAR SAO FIGURAS DIFERENTES")
            PISO_DE_DIFERENCA = 2.0
            fotos_dir = tempfile.mkdtemp(prefix="meow-par-")
            pares, parecidos, menor = 0, [], None
            try:
                # AS ABAS SAEM DO PROPRIO MENU, e nao de uma lista escrita
                # aqui: uma aba nova nasce coberta, e uma renomeada nao vira um
                # `secao()` que nao acha nada e passa calado.
                abas = pag.eval_on_selector_all(
                    "#trilho button[data-grupo]",
                    "l => l.map(b => b.getAttribute('data-grupo'))")
                for aba in abas:
                    secao(aba)
                    pag.evaluate("() => document.querySelectorAll("
                                 "'#conteudo details.ajustes-tecnicos').forEach((d) => { d.open = true; })")
                    cartoes = pag.locator(
                        '#conteudo article[data-chave]:has(.par-botoes)')
                    for i in range(cartoes.count()):
                        c = cartoes.nth(i)
                        chave = c.get_attribute("data-chave")
                        lados = c.locator(".par-botoes .desenho-botao")
                        if lados.count() != 2:
                            continue
                        pares += 1
                        # A SELECAO SAI DA FOTO: o `.desenho-botao` e'
                        # transparente, e o fundo de acento do botao escolhido
                        # vazaria para a imagem — duas fotos de um desenho
                        # IDENTICO sairiam diferentes so' por causa disso.
                        c.evaluate("""(a) => a.querySelectorAll('.lado-botao').forEach(
                            b => b.setAttribute('data-pressed-salvo',
                                                b.getAttribute('aria-pressed')))""")
                        c.evaluate("""(a) => a.querySelectorAll('.lado-botao').forEach(
                            b => b.setAttribute('aria-pressed', 'false'))""")
                        arq = []
                        for j in range(2):
                            lados.nth(j).scroll_into_view_if_needed()
                            cam = os.path.join(fotos_dir, f"{chave}-{j}.png")
                            lados.nth(j).screenshot(path=cam)
                            arq.append(cam)
                        c.evaluate("""(a) => a.querySelectorAll('.lado-botao').forEach(
                            b => b.setAttribute('aria-pressed',
                                                b.getAttribute('data-pressed-salvo') or 'false'))"""
                                   .replace(" or ", " || "))
                        pct = pixels_diferentes(arq[0], arq[1])
                        if pct is None:
                            continue
                        if menor is None or pct < menor[0]:
                            menor = (pct, chave)
                        if pct < PISO_DE_DIFERENCA:
                            parecidos.append(f"{chave} ({pct:.2f}%)")
            finally:
                shutil.rmtree(fotos_dir, ignore_errors=True)
            checa(pares > 0, f"{pares} pares de desenho apareceram na pagina")
            checa(not parecidos,
                  "nenhum par tem os dois lados iguais"
                  + (f" — {', '.join(parecidos)}" if parecidos
                     else f" (o mais parecido: {menor[1]} com {menor[0]:.2f}%)"
                          if menor else ""))

            # ---------------------------------------------------------------
            print("\n20. O QUE A CONFERENCIA DE USO PEGOU, CLICANDO")
            # Cinco defeitos medidos percorrendo a pagina botao a botao.

            # Ele cai em `top: 100%`, ou seja, em cima dos controles.
            pag.goto(url); pag.wait_for_selector("#trilho button"); pag.wait_for_timeout(1800)
            pag.locator('#trilho button[data-grupo="Cor e tela"]').first.click()
            pag.wait_for_timeout(700)
            gatilho = pag.locator('#conteudo .cartao[data-chave="FLAVOR"] button.porque').first
            tapados = 0
            if gatilho.count():
                gatilho.hover()
                pag.wait_for_timeout(350)
                tapados = pag.evaluate("""() => {
                  const c = document.querySelector('#conteudo .cartao[data-chave="FLAVOR"]');
                  if (!c) return 0;
                  let n = 0;
                  for (const b of c.querySelectorAll('.amostras button, .segmentos button')) {
                    const r = b.getBoundingClientRect();
                    const q = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
                    if (q && !b.contains(q) && q !== b) n++;
                  }
                  return n;
                }""")
            checa(tapados == 0,
                  "o balao do '?' aberto nao tapa nenhuma opcao do proprio cartao"
                  + (f" — {tapados} tapadas" if tapados else ""))

            # regra de autor sai em Arial, `border: 2px outset white` e o cinza
            # de sistema — no meio de uma pagina em Inter e Catppuccin.
            crus = []
            for aba_ in ("Cor e tela", "Painel e dock", "Modo de leitura", "Manutencao"):
                alvo_ = pag.locator(f'#trilho button[data-grupo^="{aba_[:6]}"]').first
                if not alvo_.count():
                    continue
                alvo_.click(); pag.wait_for_timeout(700)
                # SO CONTA BOTAO COM TEXTO.
                crus += pag.evaluate("""() => {
                  const fora = [];
                  for (const b of document.querySelectorAll('#conteudo button')) {
                    const txt = (b.textContent || '').trim();
                    if (!txt) continue;
                    const s = getComputedStyle(b);
                    if (/^(Arial|Times|sans-serif|serif)$/.test(s.fontFamily.split(',')[0].trim())
                        || s.borderStyle === 'outset') {
                      fora.push(txt.slice(0, 24) + ' [' + s.fontFamily.split(',')[0] + ']');
                    }
                  }
                  return fora;
                }""")
            checa(not crus,
                  "nenhum botao da pagina caiu na folha do navegador"
                  + (f" — {crus[:3]}" if crus else ""))

            # `align-items: start` na grade cada cartao tinha a propria altura e
            # os botoes saiam em escadinha de ate 20px. Um pixel de folga e
            # arredondamento de sub-pixel; vinte e defeito.
            escadas = []
            for aba_ in ("Atualização", "Instalação", "Papel de parede", "Logo do sistema"):
                bt = pag.locator(f'#trilho button[data-grupo="{aba_}"]').first
                if not bt.count():
                    continue
                bt.click(); pag.wait_for_timeout(900)
                for tops in pag.evaluate("""() => {
                  const fil = {};
                  for (const b of document.querySelectorAll('#conteudo .grade > .acao .rodape .btn:not(.ver-comando)')) {
                    const c = b.closest('.acao').getBoundingClientRect();
                    (fil[Math.round(c.top / 20)] ||= []).push(Math.round(b.getBoundingClientRect().top));
                  }
                  return Object.values(fil).filter(v => v.length > 1);
                }"""):
                    if max(tops) - min(tops) > 2:
                        escadas.append(f"{aba_}: {tops}")
            checa(not escadas,
                  "os 'Executar' de cada fileira ficam na mesma linha"
                  + (f" — {escadas[:2]}" if escadas else ""))

            faixa_ruim = []
            for aba_ in ("Cor e tela", "Logo do sistema", "Papel de parede"):
                pag.locator(f'#trilho button[data-grupo="{aba_}"]').first.click()
                pag.wait_for_timeout(1100)
                pag.evaluate("""() => { const p = document.getElementById('principal');
                  const b = document.querySelector('#conteudo .previa-bloco');
                  p.scrollTop = b ? p.scrollTop + b.getBoundingClientRect().top
                                    - p.getBoundingClientRect().top + 300 : 600; }""")
                pag.wait_for_timeout(600)
                d = pag.evaluate("""() => {
                  const b = document.querySelector('#conteudo .previa-bloco');
                  if (!b) return null;
                  const r = b.getBoundingClientRect();
                  let tapados = 0;
                  for (const t of document.querySelectorAll('#conteudo .cartao > .titulo-cartao')) {
                    const q = t.getBoundingClientRect();
                    if (q.top < r.bottom && q.bottom > r.top) tapados++;
                  }
                  return { presa: b.classList.contains('presa'), h: Math.round(r.height), tapados };
                }""")
                if d and (not d["presa"] or d["h"] > 140):
                    faixa_ruim.append(f"{aba_}: {d}")
            checa(not faixa_ruim,
                  "rolando, a faixa do desenho gruda e encolhe para menos de 140px"
                  + (f" — {faixa_ruim[:2]}" if faixa_ruim else ""))

            # (e) O NUMERO DO MENU NAO MUDA SOZINHO. As listas grandes chegam
            #     por rede depois da primeira pintura; enquanto elas somavam ao
            #     contador, o "8" ao lado de "Icones" virava "48" sem que ela
            #     tivesse feito nada.
            pag.goto(url); pag.wait_for_selector("#trilho button"); pag.wait_for_timeout(1200)
            antes_conta = pag.evaluate("""() => Object.fromEntries(
              [...document.querySelectorAll('#trilho button[data-grupo]')]
                .map(b => [b.dataset.grupo, (b.querySelector('.conta') || {}).textContent || '']))""")
            for aba_ in ("Ícones", "Lançadores e jogos", "Papel de parede"):
                bt = pag.locator(f'#trilho button[data-grupo="{aba_}"]').first
                if bt.count():
                    bt.click(); pag.wait_for_timeout(2600)
            depois_conta = pag.evaluate("""() => Object.fromEntries(
              [...document.querySelectorAll('#trilho button[data-grupo]')]
                .map(b => [b.dataset.grupo, (b.querySelector('.conta') || {}).textContent || '']))""")
            mexeu = [k for k, v in antes_conta.items() if depois_conta.get(k) != v]
            checa(not mexeu,
                  "o numero ao lado de cada aba nao muda depois que as listas chegam"
                  + (f" — {mexeu}" if mexeu else ""))

            # ---------------------------------------------------------------
            print("\n20c. O QUE A CONFERENCIA DE PRODUTO PEGOU")
            # Seis lentes de uso; estas linhas cobram os consertos.

            # (a) A BANDEJA SOBREVIVE AO F5. Antes: 14 escolhas pendentes, um
            #     recarregar, e MUDANCAS.size === 0 sem uma palavra. O espelho
            #     mora no sessionStorage e volta filtrado pelo esquema.
            pag.goto(url); pag.wait_for_selector("#trilho button"); pag.wait_for_timeout(1800)
            pag.locator('#trilho button[data-grupo="Cor e tela"]').first.click()
            pag.wait_for_timeout(700)
            alvo = pag.locator('#conteudo .cartao[data-chave="FLAVOR"] .amostras button:not([aria-pressed=true])').first
            alvo.click(); pag.wait_for_timeout(500)
            antes_n = pag.evaluate("() => MUDANCAS.size")
            pag.reload(); pag.wait_for_selector("#trilho button"); pag.wait_for_timeout(2200)
            depois_n = pag.evaluate("() => MUDANCAS.size")
            checa(antes_n == 1 and depois_n == 1,
                  f"a escolha pendente sobrevive ao F5 (antes={antes_n}, depois={depois_n})")

            # (b) O CONTADOR ABRE A LISTA, com o nome humano do cartao e a aba.
            pag.locator("#salvar-conta").click(); pag.wait_for_timeout(400)
            lista = pag.evaluate("""() => {
              const l = document.getElementById('lista-pendentes');
              if (!l) return null;
              const linha = l.querySelector('.linha-pendente');
              return { linhas: l.querySelectorAll('.linha-pendente').length,
                       nome: linha ? linha.querySelector('.p-nome').textContent : '',
                       cru: linha ? /^[A-Z_]+$/.test(linha.querySelector('.p-nome').textContent) : true };
            }""")
            checa(bool(lista) and lista["linhas"] == 1 and not lista["cru"],
                  "o contador abre a lista com o nome do cartao, nao a chave crua"
                  + (f" — {lista}" if not lista or lista.get("cru") else ""))
            pag.keyboard.press("Escape"); pag.wait_for_timeout(200)
            descartar_tudo(pag)
            pag.wait_for_timeout(500)

            # (c) SEM ESCOLHA, O SALVAR FICA E NÃO SE DESTACA. O
            #     acento e' de quando ha' o que gravar; sem nada pendente o
            #     botão continua ali, neutro, e o Descartar sai.
            est = pag.evaluate("""() => ({
              visivel: !!document.getElementById('botao-salvar').offsetParent,
              acento: document.getElementById('botao-salvar').classList.contains('btn-accent'),
              descartar: document.getElementById('botao-descartar').hidden,
            })""")
            checa(est["visivel"] and not est["acento"] and est["descartar"],
                  f"sem escolha, o Salvar fica neutro e o Descartar sai ({est})")

            # (d) A FAIXA SO ENCOLHE QUEM SAIU POR CIMA. Antes, um bloco ainda
            #     ABAIXO da tela nascia comprimido e inflava ao entrar — medido
            #     100 -> 147 px na frente do olho. No topo da pagina, nenhum
            #     bloco pode estar 'presa'.
            pag.locator('#trilho button[data-grupo="Painel e dock"]').first.click()
            pag.wait_for_timeout(1400)
            pag.evaluate("() => { document.getElementById('principal').scrollTop = 0; }")
            pag.wait_for_timeout(600)
            presas_no_topo = pag.evaluate(
                "() => document.querySelectorAll('#conteudo .previa-bloco.presa').length")
            checa(presas_no_topo == 0,
                  f"no topo da pagina nenhuma faixa esta comprimida ({presas_no_topo} presa(s))")

            # (e) A MESMA FRASE NAO EMPILHA: duas torradas identicas viram uma.
            n_torradas = pag.evaluate("""() => {
              torrada('mesma frase de teste', 'igual');
              torrada('mesma frase de teste', 'igual');
              return document.querySelectorAll('#torradas .torrada').length;
            }""")
            checa(n_torradas == 1, f"a mesma frase nao empilha torradas ({n_torradas} na tela)")

            tag_importar = pag.evaluate(
                "() => document.getElementById('rotulo-importar').tagName")
            checa(tag_importar == "BUTTON",
                  f"o Importar e' um <button> na fila do Tab ({tag_importar})")

            # (g) AS HORAS DO TEMA EXISTEM E SAO REGUA. As duas chaves eram
            #     fantasmas (bin/meow as lia, nenhum arquivo as declarava) e,
            #     declaradas, quase nasceram como campo de horario por causa da
            #     sigla do formato escrita no proprio comentario.
            reguas = pag.evaluate("""() => ['MODO_AUTO_CLARO_DE','MODO_AUTO_CLARO_ATE']
              .every(c => { const k = (ESQUEMA.chaves||[]).find(x => x.chave === c);
                            return k && k.faixa && !k.horario; })""")
            checa(reguas, "MODO_AUTO_CLARO_DE/ATE existem no esquema como faixa, nao horario")

            # (h) O VERBO «USAR» DA GALERIA EXISTE DE PONTA A PONTA: a acao no
            #     servidor (o chip da ficha chama por id, e id inexistente e'
            #     exatamente o defeito que o rodarNaGaleria ja pegou uma vez).
            tem_usar = pag.evaluate(
                "() => (ESQUEMA.acoes||[]).some(a => a.id === 'wallpaper_usar')")
            checa(tem_usar, "a acao wallpaper_usar existe no esquema do servidor")

            # Trinta chaves herdam o comentario da irma de cima, e o balao abria
            # o bloco cru: o de "Imagem escura ate as" comeca por uma captura de
            # 23:57 e a luminancia do acervo — verdade sobre a chave dona,
            # estranho sobre esta.
            pag.locator('#trilho button[data-grupo="Dia e noite"]').first.click()
            pag.wait_for_timeout(350)
            de_quem = pag.evaluate("""() => {
              const k = ESQUEMA.chaves.find(k => k.chave === 'WALLPAPER_NOITE_FIM');
              const d = document.getElementById('dica-WALLPAPER_NOITE_FIM');
              const p = d && d.querySelector('.de-quem');
              return { dona: k && k.ajuda_de, texto: p ? p.textContent : '' };
            }""")
            checa(de_quem["dona"] == "WALLPAPER_NOITE"
                  and "Separar imagens de dia e de noite" in de_quem["texto"],
                  f"o balao herdado nomeia o bloco dono ({de_quem['dona']})")

            # (i2) UM RELOGIO PARA A NOITE. A pagina abre com a
            #     moldura do relogio, os tres aneis e as seis horas; os dois
            #     campos da noite do gato, vazios na casa de brinquedo, mostram a
            #     hora que vale (a da imagem escura), e nao `--:--`.
            noite = pag.evaluate("""() => {
              const m = document.querySelector('.decisao-relogio');
              const hora = (k) => {
                const i = document.querySelector(`article.cartao[data-chave="${k}"] input[type=time]`);
                return i ? [i.value, i.classList.contains('hora-herdada')] : null;
              };
              return { moldura: !!m, aneis: m ? m.querySelectorAll('.anel').length : 0,
                       cartoes: m ? m.querySelectorAll('article.cartao').length : 0,
                       ini: hora('NOITE_INICIO'), fim: hora('NOITE_FIM'),
                       parede: hora('WALLPAPER_NOITE_INICIO'),
                       topo: !!document.querySelector('.previa-bloco') };
            }""")
            checa(noite["moldura"] and noite["aneis"] == 3 and noite["cartoes"] == 6
                  and not noite["topo"],
                  f"Dia e noite abre com um relogio de tres aneis e seis horas ({noite})")
            checa(noite["ini"] and noite["parede"] and noite["ini"][1] and noite["fim"][1]
                  and noite["ini"][0] == noite["parede"][0],
                  f"a noite vazia mostra a hora herdada, a traco, e nao --:-- ({noite['ini']}, {noite['fim']})")

            # comeco, com as duas vazias, acendia o ⊘ «So vale com A noite
            # termina as preenchida» e o relogio nao andava.
            campo = pag.locator('article.cartao[data-chave="NOITE_INICIO"] input[type=time]')
            campo.fill("20:00")
            campo.dispatch_event("change")
            pag.wait_for_timeout(350)
            par = pag.evaluate("""() => ({
              fim: MUDANCAS.get('NOITE_FIM') || '',
              anulado: !!document.querySelector('article.cartao[data-chave="NOITE_INICIO"] [data-selo="anulado"]'),
            })""")
            checa(par["fim"] == noite["fim"][0] and not par["anulado"],
                  f"mudar o comeco da noite leva o fim herdado junto, sem o ⊘ ({par}, herdado {noite['fim'][0]})")
            descartar_tudo(pag)

            # (i4) A NOITE DO DESENHO E' A DO GATO. O desenho de
            #     «Dia e noite» tinha a terceira copia da regra: com o comeco
            #     escrito e o fim vazio, ele juntava o comeco desta linha com o
            #     fim da imagem escura — uma noite que o `meow_noite_janela`
            #     nunca segue (ele pula a linha com uma ponta so, e vem o
            #     controle do modo de leitura, aqui das 21:00 as 06:00).
            legenda = pag.evaluate("""() => {
              const salvo = ESQUEMA.noite_do_applet;
              ESQUEMA.noite_do_applet = { ini: '21:00', fim: '06:00' };
              try {
                const r = window.MEOW_PREVIAS['Dia e noite']({
                  NOITE_INICIO: '19:00', NOITE_FIM: '',
                  WALLPAPER_NOITE_INICIO: '20:00', WALLPAPER_NOITE_FIM: '05:00' }, {});
                const l = r && (r.legenda || (r.antes && r.antes.legenda));
                return typeof l === 'string' ? l : (l && l.textContent) || JSON.stringify(Object.keys(r || {}));
              } finally { ESQUEMA.noite_do_applet = salvo; }
            }""")
            checa("21:00" in legenda and "06:00" in legenda and "19:00" not in legenda,
                  f"o desenho da noite segue a regra do gato, e nao cada ponta sozinha ({legenda[:90]})")

            # O DESENHO DO TOPO saiu de «Dia e noite» (o relogio e o desenho dela);
            # as duas medidas abaixo, que sao de qualquer desenho de faixa, vao
            # para «Lançadores e jogos», que continua com o dela.
            pag.locator('#trilho button[data-grupo="Lançadores e jogos"]').first.click()
            pag.wait_for_timeout(450)

            # Aqui a folga tem de ser a do recheio, nao um vao.
            folga = pag.evaluate("""() => {
              const svg = document.querySelector('.previa-bloco .par-previa svg');
              if (!svg) return null;
              const c = svg.getBoundingClientRect();
              const bb = svg.getBBox(), m = svg.getScreenCTM();
              const par = svg.closest('.par-previa').getBoundingClientRect();
              return { caixa: Math.round(c.width),
                       pintado: Math.round(Math.min(bb.width, svg.viewBox.baseVal.width) * m.a),
                       recuo: Math.round(c.left - par.left) };
            }""")
            checa(folga and folga["caixa"] - folga["pintado"] <= 30 and folga["recuo"] <= 25,
                  f"a caixa do desenho cola no desenho (caixa {folga['caixa']}px, "
                  f"desenho {folga['pintado']}px, recuo {folga['recuo']}px)")

            corte = pag.evaluate("""() => {
              const svg = document.querySelector('.previa-bloco .par-previa svg');
              return svg ? getComputedStyle(svg).overflow : '';
            }""")
            checa(corte == "visible",
                  f"o desenho que sangra fora do viewBox nao e' recortado ({corte})")

            samba = []
            for aba_ in ("Ícones", "Cor e tela", "Painel e dock"):
                pag.locator(f'#trilho button[data-grupo="{aba_}"]').first.click()
                pag.wait_for_timeout(420)
                pag.evaluate("() => { document.getElementById('principal').scrollTop = 0; }")
                pag.wait_for_timeout(150)
                d = pag.evaluate("""() => new Promise(resolve => {
                  const c = document.getElementById('principal');
                  const b = document.querySelector('#conteudo .previa-bloco');
                  if (!b) return resolve(null);
                  let esperado = c.scrollTop, saltos = 0, trocas = 0, antes = null, n = 0;
                  (function tick() {
                    const real = c.scrollTop;
                    if (Math.abs(real - esperado) > 0.5) saltos++;
                    const p = b.classList.contains('presa');
                    if (antes !== null && p !== antes) trocas++;
                    antes = p;
                    c.scrollTop = real + 14;
                    esperado = c.scrollTop;
                    if (++n < 120) requestAnimationFrame(tick);
                    else resolve({ trocas, saltos });
                  })();
                })""")
                if d and (d["trocas"] > 1 or d["saltos"] > 0):
                    samba.append(f"{aba_}: {d}")
            checa(not samba,
                  "rolando, a faixa gruda uma vez so e o navegador nao mexe na rolagem"
                  + (f" — {samba}" if samba else ""))

            # (m) A ABA CURTA CHEGA AO FIM E FICA LA. O defeito que esta regra
            #     guarda, medido numa janela de 830px: "Atualizacao"
            #     tinha 106px de folga e a faixa encolhe 174. Rolar ate o fim
            #     prendia a faixa, a pagina encolhia ate ficar do tamanho exato
            #     da tela e o navegador grampeava o scrollTop em zero — a barra
            #     nao descia NUNCA. Ela: "pagina de atualizacao e outras seguem
            #     com aquele problema de impedir de descer a barra de navegacao".
            grupos = pag.evaluate(
                "() => [...document.querySelectorAll('#trilho button[data-grupo]')]"
                ".map(b => b.dataset.grupo)")
            grampeadas = []
            for aba_ in grupos:
                pag.locator(f'#trilho button[data-grupo="{aba_}"]').first.click()
                pag.wait_for_timeout(380)
                d = pag.evaluate("""() => {
                  const m = document.getElementById('principal');
                  const folga = m.scrollHeight - m.clientHeight;
                  if (folga <= 0) return null;
                  m.scrollTop = 9999;
                  return { folga, foi: m.scrollTop };
                }""")
                if not d:
                    continue
                pag.wait_for_timeout(450)
                ficou = pag.evaluate("() => document.getElementById('principal').scrollTop")
                if abs(ficou - d["foi"]) > 1:
                    grampeadas.append(f"{aba_}: desceu {d['foi']} e voltou para {ficou}")
            checa(not grampeadas,
                  f"as {len(grupos)} abas descem ate o fim e ficam la"
                  + (f" — {grampeadas}" if grampeadas else ""))

            print("\n22. A OFICINA: VARIACOES, O ORIGINAL AO LADO, CLIQUE PARA TIRAR")
            secao("Ícones")
            pag.wait_for_selector(".grade-apps button.app", timeout=15000)
            # Um aplicativo com arte de fabrica: o primeiro dos doze primeiros
            # cuja oficina responde com pelo menos cinco cartoes.
            #
            # Entao a pergunta vai antes, e por outro caminho: o SVG do «Limpo»
            # e o que a ROTA devolve com `SUAVE` sao desenhados pelo mesmo
            # `desenhar()` da lupa, em duas caixas `.oficina-lupa` da largura
            # dela, e medidos com o mesmo `pixels_diferentes` e o mesmo piso.
            SUAVE = "9"
            desenha_limpo_e_suave = """async (valor) => {
              const c = (OFICINA.variacoes || []).find((v) => v.id === 'limpo');
              if (!c || !c.svg) return false;
              const r = await fetch('/api/app-desenho', {
                method: 'POST',
                headers: { 'X-Meow-Token': TOKEN, 'Content-Type': 'application/json' },
                body: JSON.stringify({ app: OFICINA.app, acao: 'vetorizar',
                                       fonte: c.fonte || 'icone', detalhe: c.detalhe,
                                       suavidade: Number(valor), cheia: !!c.cheia,
                                       fracas: c.fracas || 0, minimo: c.minimo || 0 }),
              }).then((x) => x.json());
              if (!r.svg || r.svg === c.svg) return false;
              const nos = [c.svg, r.svg].map((t) => desenhar(t, 200, OFICINA.cor));
              if (nos.some((n) => !n)) return false;
              const larg = document.querySelector('.oficina-lupa').getBoundingClientRect().width;
              const par = document.createElement('div');
              par.id = 'teste-suavidade';
              par.style.cssText = 'position:fixed;left:0;top:0;z-index:99999;display:flex';
              for (const n of nos) {
                const caixa = document.createElement('div');
                caixa.className = 'oficina-lupa';
                caixa.style.width = larg + 'px';
                caixa.append(n);
                par.append(caixa);
              }
              document.body.append(par);
              return true;
            }"""

            def suavidade_se_ve():
                if not pag.evaluate(desenha_limpo_e_suave, SUAVE):
                    return False
                caixas = pag.locator("#teste-suavidade > .oficina-lupa")
                dif_ = pixels_diferentes(foto(caixas.nth(0), "22-porta-limpo"),
                                         foto(caixas.nth(1), "22-porta-suave"))
                pag.evaluate("() => document.getElementById('teste-suavidade').remove()")
                return dif_ is not None and dif_ > 0.3

            achou = None
            for botao in pag.locator(".grade-apps button.app").all()[:12]:
                botao.click()
                pag.wait_for_timeout(250)
                det = pag.locator("details.oficina")
                if not det.count():
                    botao.click()
                    continue
                # `> summary`, e nao `summary`: a oficina tem um SEGUNDO details
                # dentro dela ("Editar o SVG"), e o seletor solto casa os dois —
                # o Playwright recusa em modo estrito.
                if det.first.get_attribute("open") is None:
                    det.first.locator("> summary").click()
                try:
                    pag.wait_for_selector(".oficina-folha button.oficina-cartao", timeout=20000)
                except Exception:
                    botao.click()
                    continue
                if (pag.locator(".oficina-folha button.oficina-cartao").count() >= 5
                        and suavidade_se_ve()):
                    achou = botao
                    break
                botao.click()
            checa(achou is not None, "achei uma ficha cuja oficina desenha pelo menos cinco"
                                     " variacoes e cuja Suavidade muda o traco a vista")
            if achou is not None:
                # O id do `.desktop` que a oficina abriu.
                OFICINA_APP = pag.evaluate("() => OFICINA.app")
                folha = pag.locator(".oficina-folha")
                checa(folha.locator("figure.oficina-original img").count() == 2,
                      "o original esta na folha, a 48 e a 96, ao lado das variacoes")
                # CONTAR AS <img> NAO PROVA QUE ELAS DESENHAM, e foi a foto que
                # pegou: a arte de fabrica de metade dos aplicativos desta
                # maquina e' um link simbolico do flatpak, o `/previa` resolvia
                # o link e caia fora das raizes permitidas, e o cartao
                # «Original» — que e' a metade da tela que responde "nao e tao
                # bonito quanto o original" — aparecia como icone quebrado.
                pag.wait_for_timeout(400)
                largas = pag.eval_on_selector_all(
                    "figure.oficina-original img", "es => es.map(e => e.naturalWidth)")
                checa(all(w > 0 for w in largas),
                      f"e o original DESENHA, nao e' um icone quebrado (naturalWidth={largas})")
                lupa = pag.locator(".oficina-lupa")
                pag.evaluate("document.querySelector('.oficina-lupa').scrollIntoView({block:'center'})")
                pag.wait_for_timeout(300)
                antes = foto(lupa, "22-lupa-antes")
                alvo = folha.locator("button.oficina-cartao[data-id='limpo']")
                alvo.click()
                pag.wait_for_timeout(250)
                checa(alvo.get_attribute("aria-pressed") == "true", "o cartao clicado fica marcado")
                checa(folha.locator("button.oficina-cartao[aria-pressed='true']").count() == 1,
                      "e so um cartao fica marcado")
                dif = pixels_diferentes(antes, foto(lupa, "22-lupa-depois"))
                checa(dif is not None and dif > 1.0,
                      f"a lupa muda quando o cartao muda ({dif:.1f}% dos pixels)")
                checa(pag.locator(".oficina-dock svg").count() == 3,
                      "a tira do dock tem os dois vizinhos e a escolhida")

                # O CLIQUE TEM DE CHEGAR NO TRACO, e esta e a primeira coisa que
                # se mede nesta tela: com `fill:none`, a area "dentro" de um
                # path NAO E' DO PATH, e sem `pointer-events: stroke` o clique
                # atravessa e cai no <div> atras.
                caminhos = lupa.locator("svg path")
                n = caminhos.count()
                pe = caminhos.first.evaluate("p => getComputedStyle(p).pointerEvents")
                checa(pe == "stroke", f"o traco recebe o clique pelo stroke (pointer-events={pe})")
                ponto = pag.evaluate("""() => {
                  const p = document.querySelector('.oficina-lupa svg path');
                  const s = p.ownerSVGElement, r = s.getBoundingClientRect(), v = s.viewBox.baseVal;
                  const pt = p.getPointAtLength(p.getTotalLength() * 0.25);
                  const x = r.left + (pt.x - v.x) * r.width / v.width;
                  const y = r.top + (pt.y - v.y) * r.height / v.height;
                  return { x, y, quem: (document.elementFromPoint(x, y) || {}).tagName };
                }""")
                checa(ponto["quem"] == "path",
                      f"um ponto sobre a linha pertence ao traco, e nao ao fundo ({ponto['quem']})")
                pag.mouse.click(ponto["x"], ponto["y"])
                pag.wait_for_timeout(200)
                checa(lupa.locator("svg path").count() == n - 1,
                      f"clicar num traco tira o traco ({n} -> {n - 1})")
                pag.get_by_role("button", name="Desfazer").click()
                pag.wait_for_timeout(200)
                checa(lupa.locator("svg path").count() == n, "Desfazer devolve o traco")

                # A REGUA RE-VETORIZA A ESCOLHIDA, e uma so vez: o `input` de uma
                # regua dispara a cada pixel do arrasto, e os 250 ms de espera do
                # cliente sao o que impede dez processos para ela ver um desenho.
                regua = pag.locator(".oficina-regua input[name='suavidade']")
                antes = foto(lupa, "22-lupa-regua-antes")
                pedidos = []
                pag.on("request", lambda r: pedidos.append(r.url) if "/api/app-desenho" in r.url else None)
                with pag.expect_response(lambda r: "/api/app-desenho" in r.url, timeout=25000):
                    regua.fill(SUAVE)
                    regua.dispatch_event("input")
                pag.wait_for_timeout(600)
                checa(len(pedidos) == 1, f"mover a regua dispara UMA chamada, nao uma por pixel ({len(pedidos)})")
                dif = pixels_diferentes(antes, foto(lupa, "22-lupa-regua-depois"))
                checa(dif is not None and dif > 0.3, f"mover a Suavidade redesenha a lupa ({dif:.1f}%)")
                checa(folha.locator("button.oficina-cartao[aria-pressed='true']").count() == 0,
                      "depois da regua nenhum cartao fica marcado — o desenho ja nao e o dele")

                # Ela: "falta setar cores e os outros dois slicers".
                reguas = pag.eval_on_selector_all(
                    ".oficina-regua input", "es => es.map(e => [e.name, e.value])")
                nomes = [n for n, _v in reguas]
                checa(nomes == ["detalhe", "suavidade", "fracas", "minimo"],
                      f"a oficina tem as QUATRO reguas, nesta ordem ({nomes})")
                checa(dict(reguas).get("fracas") == "0" and dict(reguas).get("minimo") == "0",
                      "e as duas novas nascem em 0 — desligadas")

                mesmo = pag.evaluate("""async (app) => {
                  const post = (c) => fetch('/api/app-desenho', {
                    method: 'POST',
                    headers: { 'X-Meow-Token': TOKEN, 'Content-Type': 'application/json' },
                    body: JSON.stringify(Object.assign({ app, acao: 'vetorizar',
                                                         detalhe: 6, suavidade: 2 }, c)),
                  }).then(r => r.json());
                  const a = await post({});                          // como era ontem
                  const b = await post({ fracas: 0, minimo: 0 });     // com as duas novas em 0
                  return { igual: a.svg === b.svg, pa: a.parametros, pb: b.parametros,
                           n: (a.svg || '').length };
                }""", OFICINA_APP)
                checa(mesmo["igual"] and mesmo["pa"] == mesmo["pb"] and mesmo["n"] > 0,
                      "as reguas novas em 0 devolvem o desenho de ontem, texto por texto "
                      f"({mesmo['pa']!r} == {mesmo['pb']!r}, {mesmo['n']} caracteres)")

                # A afirmacao e' a STRING CANONICA e nao a foto: quantos tracos
                # o `--min-traco` tira depende do icone que esta grade ofereceu
                # hoje, e um teste que depende disso falha na maquina de outra
                # pessoa.
                reguaMin = pag.locator(".oficina-regua input[name='minimo']")
                with pag.expect_response(lambda r: "/api/app-desenho" in r.url, timeout=25000):
                    reguaMin.fill("10")
                    reguaMin.dispatch_event("input")
                pag.wait_for_timeout(700)
                param = pag.evaluate("() => OFICINA.parametros")
                checa(param.endswith("--min-traco 11.2"),
                      f"mover «Traco minimo» acrescenta a bandeira ao parametro ({param!r})")
                reguaMin.fill("0")
                with pag.expect_response(lambda r: "/api/app-desenho" in r.url, timeout=25000):
                    reguaMin.dispatch_event("input")
                pag.wait_for_timeout(700)
                param = pag.evaluate("() => OFICINA.parametros")
                checa("--min-traco" not in param,
                      f"e voltar a 0 a tira de novo ({param!r})")

                # Ela: "FALTA UM CAMPO PRA SELECIONAR As cores".
                amostras = pag.locator(".oficina-lado .cores-grade button")
                checa(amostras.count() >= 14,
                      f"a oficina tem a fileira de cores da paleta ({amostras.count()} amostras)")
                mapa_c = os.path.join(CASA, ".config", "meow", "icones-convertidos.map")
                mapa_a = os.path.join(CASA, ".config", "meow", "icones-traco.map")
                antes_mapas = (md5_de(mapa_c), md5_de(mapa_a))
                cor_antes = pag.evaluate("() => OFICINA.cor")
                outra = None
                for i in range(amostras.count()):
                    b = amostras.nth(i)
                    if b.get_attribute("data-cor") != cor_antes:
                        outra = b
                        break
                antes = foto(lupa, "22-lupa-cor-antes")
                outra.click()
                pag.wait_for_timeout(300)
                cor_nova = pag.evaluate("() => OFICINA.cor")
                checa(cor_nova and cor_nova != cor_antes,
                      f"clicar numa amostra troca a cor da oficina ({cor_antes} -> {cor_nova})")
                checa(outra.get_attribute("aria-pressed") == "true"
                      and pag.locator(".oficina-lado .cores-grade button[aria-pressed='true']").count() == 1,
                      "e so a amostra clicada fica marcada")
                dif = pixels_diferentes(antes, foto(lupa, "22-lupa-cor-depois"))
                checa(dif is not None and dif > 1.0,
                      f"a lupa REPINTA na cor escolhida ({dif:.1f}% dos pixels)")
                checa(pag.locator(".oficina-dock-eu svg").count() == 1
                      and pag.locator(".oficina-folha button.oficina-cartao svg").count() > 0,
                      "e a folha e a tira do dock continuam desenhadas")
                checa((md5_de(mapa_c), md5_de(mapa_a)) == antes_mapas,
                      "e escolher a cor NAO escreveu em mapa nenhum — quem grava e' o Usar")

                # Ela: "o botao svg deveria abrir o svg no app que eu tiver se
                # eu editar la".
                #
                # Clicar em «Abrir no...» faria NASCER UMA JANELA na tela de
                # quem esta rodando o teste.
                #
                # O `<details>` «Editar o SVG»
                edicao = pag.locator("details.oficina-edicao").first
                if edicao.get_attribute("open") is None:
                    edicao.locator("> summary").click()
                    pag.wait_for_timeout(250)
                fileira = pag.locator(".oficina-editor button")
                tem_editor = pag.evaluate("() => !!(OFICINA.editor && OFICINA.editor.tem)")
                if not tem_editor:
                    checa(fileira.count() == 0,
                          "sem handler de SVG nesta maquina, o botao nao aparece — ele nao mente")
                else:
                    rotulos = [fileira.nth(i).inner_text().strip() for i in range(fileira.count())]
                    checa(len(rotulos) == 2 and rotulos[0].startswith("Abrir no ")
                          and rotulos[1] == "Reler",
                          f"«Editar o SVG» oferece o editor da maquina e o Reler ({rotulos})")
                    ida = pag.evaluate("""async (app) => {
                      const r = await fetch('/api/app-desenho', {
                        method: 'POST',
                        headers: { 'X-Meow-Token': TOKEN, 'Content-Type': 'application/json' },
                        body: JSON.stringify({ app, acao: 'editor', svg: OFICINA.svg }),
                      }).then(r => r.json());
                      return r;
                    }""", OFICINA_APP)
                    rascunho = ida.get("caminho") or ""
                    checa(ida.get("sem_janela") is True and os.path.isfile(rascunho),
                          f"a ida grava o rascunho FORA do repositorio ({rascunho})")
                    checa(RAIZ not in rascunho and "/.local/state/meowsystem/oficina/" in rascunho,
                          "e o caminho e' do servidor, no estado — nao do cliente e nao no projeto")
                    try:
                        with open(rascunho, "r", encoding="utf-8") as fh:
                            rascunho_texto = fh.read()
                        n_antes = lupa.locator("svg path").count()
                        # "Ela salvou no Boxy SVG": um traco a mais, por fora.
                        time.sleep(0.05)
                        with open(rascunho, "w", encoding="utf-8") as fh:
                            fh.write(rascunho_texto.replace(
                                "</svg>", '<path d="M 6 6 L 42 42"/></svg>'))
                        fileira.nth(1).click()          # «Reler»
                        pag.wait_for_timeout(900)
                        depois_n = lupa.locator("svg path").count()
                        checa(depois_n == n_antes + 1,
                              f"o «Reler» traz de volta o que o editor gravou "
                              f"({n_antes} -> {depois_n} tracos)")
                        checa(pag.evaluate("() => OFICINA.escolhida") == "editado",
                              "e o desenho passa a ser dela, nao do cartao")
                    finally:
                        # O rascunho e' de fora do repositorio, mas e' arquivo
                        # que este teste criou — quem cria, tira.
                        if os.path.isfile(rascunho):
                            os.unlink(rascunho)

                # Ate' hoje ele era apertado com o ensaio ligado, e so' torrava.
                # Sem o ensaio, o clique grava o desenho E roda `icones_traco`
                # na maquina de quem testa.
                checa(pag.locator("details.oficina > summary button").count() == 1,
                      "o «Usar» mora no resumo da oficina")

                #   Este e' o UNICO ponto desta secao que escreve de verdade, e
                #   ele devolve tudo no `finally`. A pergunta que so uma escrita
                #   responde: a cor escolhida na oficina cai no TERCEIRO campo
                #   da linha do mapa que passa a ser dono do aplicativo?
                #
                # A linha do `apps-convertidos.map` e'
                # `nome:origem:cor[:params]` — a cor e' o campo 3.
                nome_icone = pag.evaluate("() => OFICINA.nome") or OFICINA_APP
                conv_dir = os.path.join(CASA, ".local", "share", "meowsystem", "convertidos-apps")
                guardados = {}
                for c in (mapa_c, mapa_a,
                          os.path.join(conv_dir, nome_icone + ".svg"),
                          os.path.join(CASA, ".local", "share", "meowsystem", "retoques",
                                       nome_icone + ".svg")):
                    guardados[c] = open(c, "rb").read() if os.path.isfile(c) else None
                try:
                    cor_alvo = pag.evaluate("() => OFICINA.cor")
                    r = pag.evaluate("""async (app) => {
                      return await fetch('/api/app-desenho', {
                        method: 'POST',
                        headers: { 'X-Meow-Token': TOKEN, 'Content-Type': 'application/json' },
                        body: JSON.stringify({ app, acao: 'salvar', svg: OFICINA.svg,
                                               cor: OFICINA.cor, fonte: OFICINA.fonte,
                                               parametros: OFICINA.parametros }),
                      }).then(r => r.json());
                    }""", OFICINA_APP)
                    checa(not r.get("erro") and r.get("cor") == cor_alvo,
                          f"o salvar aceita a cor escolhida na oficina ({r.get('erro') or r.get('cor')})")
                    campos = []
                    with open(mapa_c, encoding="utf-8") if os.path.isfile(mapa_c) else open(os.devnull) as fh:
                        for linha in fh:
                            corte = linha.strip()
                            if corte and not corte.startswith("#") \
                               and corte.split(":")[0].strip() == nome_icone:
                                campos = [c.strip() for c in corte.split(":")]
                    checa(len(campos) >= 3 and campos[2] == cor_alvo,
                          f"e ela esta no CAMPO 3 da linha de {nome_icone} no "
                          f"icones-convertidos.map de quem usa ({':'.join(campos) or 'linha nao achada'})")
                    fora = []
                    with open(mapa_a, encoding="utf-8") if os.path.isfile(mapa_a) else open(os.devnull) as fh:
                        for linha in fh:
                            corte = linha.strip()
                            if corte and not corte.startswith("#") \
                               and corte.split(":")[0].strip() == nome_icone:
                                fora.append(corte)
                    checa(not fora,
                          "e o nome NAO ficou nos dois mapas — dois donos e' o defeito "
                          "que o _conferir_gemeos estoura")
                finally:
                    # A DEVOLUCAO NAO E' OPCIONAL: este teste roda no repositorio
                    # de verdade, e um mapa alterado por um teste e' uma linha
                    # que ninguem escreveu aparecendo num `git diff`.
                    for c, bruto in guardados.items():
                        if bruto is None:
                            if os.path.isfile(c):
                                os.unlink(c)
                        else:
                            with open(c, "wb") as fh:
                                fh.write(bruto)
                checa((md5_de(mapa_c), md5_de(mapa_a)) == antes_mapas,
                      "e os dois mapas voltaram byte a byte ao que eram antes do teste")
                if FOTOS:
                    # ROLAR E' `#principal`, NAO A JANELA — a pagina inteira nao
                    # rola, quem rola e' a coluna.
                    pag.wait_for_timeout(2800)      # a torrada sai da frente
                    topo = pag.evaluate("""() => {
                      const m = document.getElementById('principal');
                      const d = document.querySelector('details.oficina');
                      m.scrollTop += d.getBoundingClientRect().top - 170;   // a faixa grudada come 155px
                      return m.scrollTop;
                    }""")
                    pag.wait_for_timeout(400)
                    foto(pag, "22-oficina")
                    pag.evaluate(f"document.getElementById('principal').scrollTop = {topo} + 420")
                    pag.wait_for_timeout(400)
                    foto(pag, "22-oficina-rolada")

            print("\n23. DUAS LEITURAS DA JANELA NO AR")
            # Derrubou uma rodada do gate em «Ouvir o som»: a leitura que
            # voltava depois do fim escrevia num `TRABALHO` que já era `null`.
            corrida = pag.evaluate("""async () => {
              const original = window.fetch;
              const fila = [];
              window.fetch = (rota, opcoes) => String(rota).startsWith('/api/trabalho')
                ? new Promise((pronto) => fila.push({ rota: String(rota), pronto }))
                : original(rota, opcoes);
              // O servidor de mentira: `linhas` é tudo o que o trabalho já
              // escreveu, e a resposta é a fatia pedida no `desde`, como a de
              // verdade.
              const responde = (i, linhas, vivo) => {
                const desde = Number(new URL(fila[i].rota, location.href).searchParams.get('desde'));
                fila[i].pronto(new Response(JSON.stringify({
                  linhas: linhas.slice(desde), proximo: linhas.length, vivo,
                  rc: vivo ? null : 0, segundos: 1 }),
                  { status: 200, headers: { 'Content-Type': 'application/json' } }));
              };
              const tique = () => new Promise((r) => setTimeout(r, 80));
              const saida = () => [...document.querySelectorAll('#saida span')]
                .map((s) => s.textContent.trim());
              const trabalho = (id) => ({ id, rotulo: 'Leitura dupla',
                                          escreve: false, fim: { '0': ['ok', 'pronto'] } });
              const erros = [];
              const ouvir = (e) => erros.push(String((e.reason && e.reason.message) || e.reason));
              window.addEventListener('unhandledrejection', ouvir);
              const fora = {};
              try {
                abrirResultado(trabalho('a'));          // leitura 0, desde 0
                clearInterval(TRABALHO.timer);
                puxar();                             // leitura 1, desde 0
                await tique();
                responde(0, ['um'], true);
                await tique();
                responde(1, ['um', 'dois'], true);   // a velha, chegando por último
                await tique();
                puxar();                             // leitura 2
                await tique();
                responde(2, ['um', 'dois'], false);
                await tique();
                fora.mesmo = saida();

                abrirResultado(trabalho('b'));          // leitura 3
                clearInterval(TRABALHO.timer);
                puxar();                             // leitura 4
                await tique();
                responde(3, ['três'], false);
                await tique();
                responde(4, ['três'], false);        // depois do fim
                await tique();

                abrirResultado(trabalho('c'));          // leitura 5
                clearInterval(TRABALHO.timer);
                puxar();                             // leitura 6
                await tique();
                responde(5, ['quatro'], false);
                await tique();
                abrirResultado(trabalho('d'));          // leitura 7
                clearInterval(TRABALHO.timer);
                await tique();
                responde(6, ['quatro'], false);      // a do trabalho c, no d
                await tique();
                fora.seguinte = { vivo: !!TRABALHO && TRABALHO.id === 'd', saida: saida() };
                responde(7, ['cinco'], false);
                await tique();
                fora.seguinte.depois = saida();
              } finally {
                window.fetch = original;
                window.removeEventListener('unhandledrejection', ouvir);
                document.getElementById('resultado').close();
              }
              fora.erros = erros;
              return fora;
            }""")
            checa(corrida["mesmo"] == ["um", "dois"],
                  "com duas leituras do mesmo trabalho no ar, a que volta atrasada não "
                  f"repete a saída: {corrida['mesmo']}")
            checa(not corrida["erros"],
                  "a leitura que volta depois do fim do trabalho não quebra a página"
                  + (f" — {corrida['erros'][:1]}" if corrida["erros"] else ""))
            seguinte = corrida["seguinte"]
            checa(seguinte["vivo"] and seguinte["saida"] == [] and seguinte["depois"] == ["cinco"],
                  "a leitura de um trabalho que acabou não escreve na janela do seguinte nem o "
                  f"dá por terminado: vivo={seguinte['vivo']}, saída {seguinte['saida']} e depois "
                  f"{seguinte['depois']}")

            print("\n24. A GRADE DE APLICATIVOS NÃO SOME NO FIM DE UM TRABALHO")
            # Um vigia no `#conteudo` anota toda pintura sem cartão, ou com o
            # «Lendo», do clique até depois das três releituras do fim — e não
            # pode anotar nenhuma.
            secao("Ícones")
            pag.wait_for_selector("#conteudo .grade-apps .app", timeout=30000)
            grade = pag.evaluate("""async () => {
              const sumiu = [];
              const vigia = new MutationObserver(() => {
                const cartoes = document.querySelectorAll('#conteudo .grade-apps .app').length;
                const lendo = [...document.querySelectorAll('#conteudo .sem-previa')]
                  .some((e) => e.textContent.includes('Lendo os aplicativos'));
                if (!cartoes || lendo) sumiu.push({ cartoes, lendo });
              });
              vigia.observe(document.getElementById('conteudo'), { childList: true, subtree: true });
              const original = window.fetch;
              let pedidas = 0;
              window.fetch = (rota, ...resto) => {
                if (String(rota).startsWith('/api/apps')) pedidas += 1;
                return original(rota, ...resto);
              };
              try {
                await rodarAcao('wallpaper_proximo');
                const inicio = performance.now();
                while (TRABALHO && performance.now() - inicio < 60000) {
                  await new Promise((r) => setTimeout(r, 50));
                }
                await new Promise((r) => setTimeout(r, 3000));
              } finally {
                window.fetch = original;
              }
              vigia.disconnect();
              return { sumiu, terminou: !TRABALHO, pedidas,
                       cartoes: document.querySelectorAll('#conteudo .grade-apps .app').length };
            }""")
            checa(grade["terminou"] and grade["cartoes"] and not grade["sumiu"],
                  "a grade de Ícones passa da lista de antes para a de depois sem sumir: "
                  f"{len(grade['sumiu'])} pintura(s) sem cartão ou com «Lendo…», "
                  f"{grade['cartoes']} cartões no fim")
            checa(grade["pedidas"] == 1,
                  f"e a lista de aplicativos é pedida uma vez no fim do trabalho: {grade['pedidas']}")
            print("\n20b. O CONSOLE FICOU LIMPO?")
            checa(not erros_de_console,
                  f"nenhum erro de JavaScript em toda a visita"
                  + (f" — {erros_de_console[:2]}" if erros_de_console else ""))

            nav.close()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=8)
        except subprocess.TimeoutExpired:
            proc.kill()

    print("\n21. O meow.conf FICOU COMO ESTAVA")
    checa(md5_conf() == md5_inicial, "o meow.conf esta byte a byte como antes do teste")

    bons = sum(1 for ok, _ in passos if ok)
    print(f"\n{bons}/{len(passos)} verificacoes passaram.")
    if falhas:
        print("FALHOU:")
        for f in falhas:
            print("  - " + f)
        return 1
    print("ok: a pagina do app responde a cada recurso, clicando.")
    return 0


if __name__ == "__main__":
    # O brinquedo sai sempre, inclusive quando o teste morre no meio: ele e'
    # uma casa inteira em /tmp, com um `sudo` falso dentro.
    try:
        sys.exit(main())
    finally:
        shutil.rmtree(BRINQUEDO, ignore_errors=True)

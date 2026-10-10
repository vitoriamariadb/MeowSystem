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

# O PAINEL SOBE NUM HOME DE BRINQUEDO, E NUNCA CONTRA O `meow.conf` DELA —
# 23/09/2026, sprint P33
#   Ate' hoje este arquivo subia o `app/run.sh` com o ambiente de quem o
#   chamava: o `meow.conf` de verdade, o estado de verdade e o `sudo` da
#   maquina — e rodava acoes de verdade nesse painel (o `meow status`, o
#   `doctor`, o rascunho da oficina gravado no estado dela). A regra do
#   projeto e' que nada da interface e' aplicado em sandbox, tudo e' aplicado
#   na maquina da pessoa; por isso quem vai para a sandbox e' o TESTE. E a P33
#   tornou isto urgente: o `tests/todos.sh` passou a achar o python com
#   Playwright, e este arquivo, que saia "pulado" nos terminais sem o pyenv,
#   agora roda de fato a cada `./tests/todos.sh`.
#
#   O servidor recebe um ambiente limpo, o `env -i` do `tests/convergencia.sh`:
#   HOME e `MEOW_CONF` num diretorio temporario, `MEOW_PONTE` para o vazio e um
#   `sudo` falso na frente do PATH — numa maquina com `NOPASSWD: ALL` o
#   `sudo -n` de verdade PASSA, e um teste cujo alcance depende disso e' roleta.
#   O `meow.conf` do brinquedo e' uma copia do `meow.conf.exemplo`, o arquivo
#   de uma instalacao nova — e e' ele que o passo 21 confere byte a byte.
#
#   E A CASA NAO FICA VAZIA — corrigido no mesmo dia, na revisao da P33
#   A primeira corrida inteira no brinquedo reprovou em quatro conferencias,
#   e a primeira versao deste bloco as deu por "decisao de outra sprint". Nao
#   eram: tres liam o que esta' INSTALADO numa casa e olhavam uma vazia, e a
#   quarta escolhia mal o que medir. Defeito DESTE arquivo, e vermelho em
#   qualquer maquina. As tres ganharam o que mediam na casa dela, derivado do
#   `meow.conf` do brinquedo e nunca de um nome escrito aqui (`montar_casa`):
#     · a grade de icones do tema, zero: o `NOME_TEMA_ICONES` nao existia em
#       ~/.local/share/icons. Recebe os glifos versionados em
#       `assets/icones/arcticons-apps/`, que sao o que o construtor veste;
#     · a galeria, zero: `ativos/` vazio. Recebe PAREDES imagens lisas;
#     · o ponteiro, "3 de 0": o `CURSOR` de fabrica nao estava instalado, a
#       lista do disco nao virava cerca e a chave ficava sem opcoes, enquanto
#       as 3 previas saiam de /usr/share/icons. Recebe um XCursor de verdade
#       com o nome do valor de fabrica.
#   A quarta, a Suavidade da oficina em 0,0%, NAO nasceu do brinquedo. O
#   primeiro aplicativo da grade e' o «Arquivos» do COSMIC nas duas casas
#   (medido lendo os `.desktop` com um HOME e com o outro), e a arte de
#   fabrica dele e' a mesma, a do hicolor do sistema — tao simples que a rota
#   devolve o MESMO SVG com a suavidade em 2 e em 9. Na casa dela o teste
#   morria antes, no `networkidle`, e nunca chegava ate' la'. Nao se planta:
#   a oficina passa a escolher um aplicativo em que a mudanca da Suavidade
#   aparece na lupa (ver o passo 22).
#   A reprovação que sobrava NÃO era do brinquedo: o `FLAVOR` não ganhava
#   amostras em casa nenhuma, porque as cinco opções do exemplo não cabem na
#   paleta de nenhum dos dois packs (4 no catppuccin, 2 no dracula). Ela
#   reprovava o "FLAVOR mostra as paletas" do passo 4 e derrubava o passo 20c.
#   O conserto era do `servidor.py`, fora do que a P33 liberava, e veio na P40
#   (24/09/2026): a prévia se pergunta de novo sobre os flavors do pack no ar.
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


# O ENSAIO SAIU DA PÁGINA — 13/09/2026.
#   Pedido dela: "eu tinha pedido pra tirar o app do modo sandbox". As duas
#   funções que ligavam e conferiam o «Ensaiar sem gravar» (`seco`,
#   `seco_ligado`) sairam junto com o botão. O que este arquivo usava o ensaio
#   para evitar — escrever no disco de quem testa — agora e' evitado em cada
#   passo: o Salvar so' e' chamado com escolha que a peneira recusa antes de
#   gravar, e o editor de fora não abre porque o painel sobe com `--sem-abrir`.


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


# O CENSO: UM RETRATO DE CADA CARTAO DESENHADO.
#   Ele responde, para cada chave, QUE FORMA a pagina deu a ela — campo de
#   texto, deslizante, fichas, grupo de botoes — e o `tipo` do grupo sai da
#   propria arvore (a classe do elemento que segura os botoes), em vez de uma
#   lista de nomes de classe escrita aqui. Se amanha nascer uma quinta forma de
#   escolha, ela aparece no censo sozinha.
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
  previa: k.previa || '',
  lista: !!k.lista,
  pathsep: !!k.lista_pathsep,
  vazio: !!k.aceita_vazio,
  sem_programa: !!k.sem_programa,
}))
"""

# AS ACOES QUE A PAGINA PEDE PELO NOME.
#   Duas procedencias, as duas varridas por regra: o atributo `data-acao*` de
#   qualquer elemento (e assim o atalho do cabecalho entra) e, no `app.js`, o
#   primeiro argumento literal de qualquer funcao cujo nome comece com `rodar`.
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
    # `data-chave` e recente (02/09/2026, a ancora do foco). Enquanto ele podia
    # nao existir, o nome da chave no `<code>` do topo continua sendo o unico
    # identificador visivel do cartao.
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
    glifos = os.path.join(RAIZ, "assets", "icones", "arcticons-apps")
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
            # SO EXCECOES DE JAVASCRIPT CONTAM AQUI.
            #   O `console` do navegador tambem registra falha de REDE — e um
            #   409 e o servidor fazendo o certo: recusar um segundo trabalho
            #   enquanto o primeiro corre. Contar isso como defeito da pagina
            #   fazia o teste reprovar justamente a protecao que ele deveria
            #   confirmar. O que a pagina precisa e DIZER o 409 na tela, e isso
            #   ela passou a fazer no mesmo dia.
            pag.on("console", lambda m: (
                m.type == "error"
                and "Failed to load resource" not in m.text
                # `Failed to fetch` no fim é a página pedindo algo enquanto o
                # teste já derrubou o servidor — teardown, não defeito.
                and "Failed to fetch" not in m.text
                and erros_de_console.append(m.text)))
            pag.on("pageerror", lambda e: erros_de_console.append(str(e)))
            # A PAGINA PRONTA E' O TRILHO DESENHADO, NAO O SILENCIO DA REDE —
            # 23/09/2026, sprint P33
            #   Era `wait_until="networkidle"`, que espera 500 ms sem conexao
            #   nenhuma, e o `page.goto` estourava os 30 s em toda corrida — em
            #   `dev` tambem. Medido antes de trocar a espera: com a pagina
            #   aberta, aos 2, 8 e 20 s o UNICO pedido aberto e' o
            #   `GET /api/pulso`, tipo `eventsource`, e nenhum pedido novo nasce
            #   depois dos 3 s — nao ha intervalo vazando. E o pulso nao e'
            #   vazamento: e' o interruptor do servidor (o bloco "O PAINEL MORRE
            #   COM A JANELA QUE O ABRIU", em `servidor.py`), aberto de proposito
            #   enquanto a pagina existir — entao a rede desta pagina NUNCA
            #   silencia.
            #
            #   O `#trilho button` e' a prova certa de "pronta": o `iniciar()`
            #   so' o desenha depois de o esquema chegar, e na mesma volta em
            #   que pinta o `#resumo` que o passo 1 le logo abaixo.
            pag.goto(url, wait_until="domcontentloaded")
            pag.wait_for_selector("#trilho button")

            print("\n1. A PAGINA ABRE")
            checa(pag.title() == "MeowSystem", "o titulo e MeowSystem")
            resumo = pag.locator("#resumo").inner_text()
            # O NÚMERO NÃO SE ESCREVE AQUI.
            #   Ele era "95 chaves" cravado, e envelheceu em silêncio: cada
            #   chave nova no `meow.conf.exemplo` quebrava este teste sem que
            #   nada estivesse errado no painel. O catálogo é derivado dos
            #   comentários do exemplo — então o número certo é o que o exemplo
            #   diz hoje, e é com ele que se compara.
            # "chaves" virou "ajustes" na tela em 06/09/2026: quem le a tela
            # nunca precisa saber o nome da variavel, e "chave" era o nome dela.
            m_resumo = re.search(r"(\d+) ajustes", resumo)
            checa(bool(m_resumo), f"o resumo conta os ajustes: {resumo[:44]}…")
            with open(os.path.join(RAIZ, "meow.conf.exemplo"), encoding="utf-8") as fh:
                chaves_no_exemplo = len(re.findall(r"^[A-Z_]+=", fh.read(), re.M))
            checa(m_resumo and int(m_resumo.group(1)) == chaves_no_exemplo,
                  f"o resumo conta {m_resumo.group(1) if m_resumo else '?'} ajustes"
                  f" e o meow.conf.exemplo cataloga {chaves_no_exemplo}")
            # O MENU ENCOLHEU DE PROPOSITO — 06/09/2026, pedido dela: "temos
            #   duas guias de papeis de parede… essas repetidas deveriam serem
            #   unidas cada qual em uma unica pagina". Sao 12 assuntos mais o
            #   Inicio, num nivel so'. O piso de 20 media o menu antigo; agora
            #   ele cobraria de volta o que ela pediu para tirar.
            n_trilho = pag.locator("#trilho button").count()
            checa(10 <= n_trilho <= 16, f"o trilho tem {n_trilho} paginas")

            print("\n2. CADA SECAO RENDERIZA (uma a uma, medindo o que apareceu)")
            nomes = pag.locator("#trilho button").all_text_contents()
            vazias = []
            # A MESMA VARREDURA COLHE O CENSO.
            #   Abrir as 23 secoes ja custa cinco segundos; colher o retrato de
            #   cada cartao enquanto ele esta na tela custa um `evaluate` por
            #   secao e paga as regras dos passos 6, 7 e 15 sem uma segunda
            #   volta pela pagina inteira.
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
            # UMA CHAVE SEM CARTAO E UMA CHAVE QUE ELA NAO PODE CONFIGURAR.
            #   O resumo do topo conta as chaves do catálogo; isto confere que todas
            #   chegaram a ALGUMA aba. Uma chave que o servidor le e a pagina
            #   nao desenha e a definicao de "depender de ajuda sempre".
            # [P77, achado 12: a chave de um programa que a casa nao tem
            # (`sem_programa`, da marca `[so-com-app ...]`) fica sem cartao DE
            # PROPOSITO — nao ha o que trocar. Ela sai da conta, e o contrario
            # e cobrado: uma chave assim que ganhasse cartao seria o defeito.]
            # [P77, achado 17: num seletor com modo (o gato do dock e o do
            # terminal, `DECISOES[].modo` no app.js), a chave que o modo em
            # vigor nao usa fica fora da tela ate o modo dela ser escolhido. Ela
            # sai da conta, e o que se cobra e que a chave do MODO tenha cartao
            # — e por ele que as outras aparecem.]
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

            # O MENU VIROU UM NIVEL SO, UMA PAGINA POR ASSUNTO — 06/09/2026.
            #   "Aparencia" era o bloco de arquivo; agora a pagina e o assunto,
            #   e as paletas moram em "Cor e tela". Os gatos, que vinham na
            #   mesma aba por serem vizinhos no meow.conf.exemplo, foram para a
            #   pagina "Logo do sistema" — que e onde alguem os procuraria.
            secao("Cor e tela")
            checa(pag.locator("#conteudo .tira").count() >= 4, "FLAVOR mostra as paletas")
            checa(pag.locator("#conteudo .cores-grade button, #conteudo .amostras button").count() > 8,
                  "ACCENT mostra as cores da paleta")

            # AS DUAS LISTAS DO PONTEIRO TEM DE TER O MESMO TAMANHO — 21/09/2026
            #   `_temas_de_cursor` diz o que a chave CURSOR aceita, e e' dela
            #   que saem os BOTOES; `_prev_cursores` diz o que vira DESENHO. Em
            #   15/09 a primeira passou a aceitar nome exato — foi assim que o
            #   `Dracula-Cursor` entrou — e a segunda continuou montando
            #   `<valor>-cursors` sempre. Medido em 21/09: quatro opcoes, UMA
            #   previa, tres botoes com um retangulo vazio no lugar do ponteiro.
            #   Divergencia entre as duas listas e', por definicao, defeito — e
            #   esta e' a unica conferencia que teria pegado aquilo no dia.
            #   Ela pergunta as duas fontes pela rede, e nao conta pixels: vale
            #   com a pagina em qualquer aba. Fica aqui, e nao entre os gatos,
            #   porque o `CURSOR` mora na "Cor e tela" (meow.conf.exemplo:242) —
            #   um relatorio que le em ordem nao pode dizer a secao errada.
            n_opcoes, n_previas = pag.evaluate("""async () => {
              const esq = await (await fetch('/api/esquema')).json();
              const prev = await (await fetch('/api/previas?tipo=cursor')).json();
              const k = (esq.chaves || []).find((c) => c.chave === 'CURSOR');
              return [((k && k.opcoes) || []).length, (prev.itens || []).length];
            }""")
            # O `> 0` NAO E' CINTO E SUSPENSORIO — 21/09/2026
            #   So' a igualdade passa em VERDE com `0 == 0`, e ha' dois jeitos
            #   baratos de chegar la': a chave CURSOR sumir do esquema (`k` vem
            #   undefined e o `|| []` devolve zero) ou `/api/previas` responder
            #   `{erro: ...}` (o `prev.itens || []` tambem devolve zero). Nos
            #   dois casos a pagina nao oferece ponteiro NENHUM, que e' pior do
            #   que a divergencia que este passo veio pegar — e ele aprovaria.
            checa(n_opcoes > 0 and n_opcoes == n_previas,
                  f"o ponteiro tem uma prévia por opção ({n_previas} de {n_opcoes})")
            # O MESMO MOTIVO DA GRADE DE ICONES LOGO ABAIXO, e que aqui faltava:
            # os gatos chegam por `/previa`, uma requisicao por desenho. Medir no
            # instante do clique reprovou a pagina numa das rodadas de 02/09/2026
            # com os gatos inteiros no lugar — era a rede, nao o cartao.
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
            # [P77, achado 15: a coleção abre a página com a primeira leva
            # (`PRIMEIRA_LEVA_GALERIA`, três fileiras); o resto vem pelo
            # «Mostrar mais», que também se cobra aqui.]
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
            # O DEFEITO Nº 1 DA AUDITORIA, E O QUE NENHUM TESTE VIA.
            #   "Cliquei na tira `latte`. O banner passou a '1 escolha' e o
            #   cartao ganhou a borda de nao-salvo, mas o aria-pressed continuou
            #   `mocha=true`." A pagina registrava a escolha certa e mostrava a
            #   errada — e o teste antigo so olhava para o banner, que estava
            #   certo. Prova-se o contrario: depois do clique, o botao clicado e
            #   o unico marcado.
            #
            #   O representante de cada forma sai do ESQUEMA, nunca de uma lista
            #   de chaves: `previa` diz se a escolha e uma tira de flavor, uma
            #   bolinha de cor ou um desenho, e `opcoes` sem previa e o botao de
            #   texto. Chave nova entra na regra sozinha.
            formas = (
                ("amostra de flavor", lambda k: k["previa"] == "flavor"),
                ("bolinha de cor", lambda k: k["previa"] == "cor"),
                ("imagem", lambda k: k["previa"] in ("gato", "cursor")),
                ("botão de opção", lambda k: k["opcoes"] and not k["previa"]),
            )
            for rotulo, condicao in formas:
                # O REPRESENTANTE E O PRIMEIRO QUE DA PARA CLICAR, e nao o
                # primeiro da lista: uma chave pode ter uma opcao so (o `CURSOR`
                # ficou assim quando os apelidos duplicados sairam) e ali nao ha
                # gesto a medir. A paciencia de 6 s vale para o primeiro
                # candidato, que e quem espera a previa; os seguintes ja pegam o
                # acervo carregado.
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
            # "Cliquei no × da ficha 'steam': o cabecalho passou a '1 escolha',
            #  mas as 23 fichas continuaram as mesmas." E, do outro lado, "o
            #  segundo caminho acrescentado APAGA o primeiro". As duas metades
            #  do gesto sao conferidas aqui, nas duas familias de lista que o
            #  esquema declara (virgula e dois-pontos) — e o que entra e sai e
            #  SEMPRE ficha inventada pelo teste, nunca uma das dela.
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
            # "O DESENHO AO VIVO NAO E AO VIVO: nenhuma mudanca de controle mexe
            #  nele." A auditoria mediu isso duas vezes — no veu de Kelvin do
            #  modo de leitura ("o <output> foi para 1315 e a div .veu continuou
            #  com a cor de 3500K") e na barra desenhada das secoes de FORMA
            #  ("nas cinco medicoes o HTML do mock ficou byte a byte igual").
            #  Uma previa que nao acompanha o controle e pior que previa nenhuma:
            #  ela mostra, com confianca, o estado errado.
            #
            #  A regra: toda previa que ACOMPANHA o controle tem de reagir a ele.
            #  Quais sao elas sai do esquema por exclusao — as previas que SAO o
            #  controle (a tira do flavor, a bolinha, o desenho do gato) nao
            #  entram aqui, porque nelas o clique ja foi medido no passo 6.
            ESTILOS_JS = """
              () => [...document.querySelectorAll('#conteudo [style]')]
                .filter((e) => !['INPUT', 'BUTTON', 'OUTPUT', 'SELECT', 'TEXTAREA']
                                 .includes(e.tagName))
                .map((e) => e.tagName + ':' + e.getAttribute('style')).join('|')
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

            # A BUSCA DO PASSO ANTERIOR TEM DE SAIR ANTES.
            #   Com texto na busca, `render` mostra os RESULTADOS e nao a aba —
            #   e o `secao()` abaixo clica no trilho sem efeito visivel. Foi o
            #   que fez as tres primeiras rodadas dizerem "o cartão não apareceu
            #   na aba dele" para cartoes que estavam inteiros, uma busca atras.
            def mexer_no_controle(cartao):
                """Move o controle do cartao e diz o gesto feito, ou None."""
                faixa = cartao.locator("input[type=range]")
                if faixa.count() and faixa.first.is_disabled():
                    # DESLIZANTE DESABILITADO E' O ESTADO "Deixar como esta".
                    #   `FORMA_RAIO_PAINEL=""` no conf dela desenha o deslizante
                    #   cinza, e nenhuma tecla o move — corretamente. Tratar isso
                    #   como "o controle nao reage" acusaria a pagina de um
                    #   defeito que e' a chave estando vazia.
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
                # O CAMPO `previa` NOMEIA DUAS COISAS DIFERENTES, e so' uma delas
                # cabe aqui.
                #   Umas dizem QUAL DESENHO a secao ganha (`barra`, `kelvin`,
                #   `textura`) — sao essas que este passo cobra, porque e' delas
                #   que se espera repintar quando o controle mexe.
                #   Outras dizem QUAL CONTROLE substitui o campo de texto
                #   (`flavor`, `cor`, `gato`, `cursor`, `areas`): elas nao tem
                #   desenho proprio, ja foram medidas no passo do clique, e
                #   cobrar repintura delas e' cobrar de um controle uma coisa que
                #   ele nunca prometeu.
                #
                #   A LISTA E' DE NAO-DESENHOS, e nao de desenhos, de proposito:
                #   assim uma previa de desenho NOVA entra coberta sozinha, e uma
                #   previa de controle nova reprova aqui na primeira rodada — que
                #   e' barulhento, e e' o lado certo para errar. Foi o que
                #   aconteceu com `areas` em 07/09/2026.
                if k["previa"] in ("", "flavor", "cor", "gato", "cursor", "areas"):
                    continue
                if k["chave"] in censo:
                    por_previa.setdefault(k["previa"], []).append(k)

            for previa, candidatos in por_previa.items():
                # TENTA ATE TRES CHAVES DA MESMA PREVIA, e cobra que UMA mova o
                # desenho. Cobrar de todas seria injusto com o desenho honesto: a
                # barra nao tem como mostrar `VIDRO_AO_MAXIMIZAR`, que fala do que
                # acontece quando uma janela cobre o painel. O que o defeito da
                # auditoria dizia — "nas cinco medicoes o HTML ficou byte a byte
                # igual" — e uma previa que nao reage a NADA, e e isso que cai
                # aqui.
                # AS CANDIDATAS SAO AS QUE O DESENHO LE, E NAO AS TRES PRIMEIRAS.
                #   A prevía `barra` cobre 21 chaves, e o desenho so' consulta
                #   cinco pares — raio, margem, espaco, recheio e opacidade.
                #   `FORMA_PAINEL_SOLTO`, `FORMA_DOCK_SOLTO` e `FORMA_PAINEL_ILHA`
                #   sao as tres primeiras da lista e nenhuma delas entra no
                #   desenho: o teste cobrava do mock uma coisa que ele nunca
                #   prometeu, e reprovava a pagina por isso. Aqui as que o
                #   desenho de fato le vem na frente.
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
            # OS ROTULOS DOS VALORES MUDARAM — 06/09/2026. O valor no arquivo
            #   continua `debug`/`info`; o que a tela escreve passou pelo
            #   `ROTULO_DE_VALOR`, e agora e "Detalhado"/"Informacao". O teste
            #   clica no que a pessoa ve, entao e o rotulo que ele procura.
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
            # A VOLTA TEM DE SER A' PAGINA ONDE A CHAVE MORA.
            #   O teste ia para "Terminal" e cobrava um cartao marcado — mas
            #   `LOG_NIVEL` nunca esteve la, e desde 06/09/2026 mora em
            #   "Manutencao". Cobrar a marca numa pagina que nao tem o cartao e'
            #   cobrar da pagina uma coisa que a pessoa nao pediu.
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
            # A BARRA NÃO SOME MAIS — 13/09/2026. Ela sumia sem escolha
            # pendente, e ela leu isso como o botão removido: "removeu o botão
            # Salvar, que salva e aplica". Sem escolha, ele aplica o que ja'
            # esta' salvo — e por isso este teste NÃO o aperta: seria rodar o
            # instalador inteiro na maquina de quem testa.
            checa(pag.locator("#botao-salvar").is_visible(),
                  "sem escolha pendente, o Salvar continua na tela")
            # O BALAO E' `data-balao` DESDE A P6 (21/09/2026): o `porBalao` tira
            # o `title` nativo de todo elemento. Lendo o `title`, esta
            # conferencia reprovava um Salvar que diz exatamente o que ela pede
            # — medido na primeira corrida depois do `networkidle`, 23/09/2026.
            checa("Aplica" in (pag.locator("#botao-salvar").get_attribute("data-balao") or ""),
                  "e diz que aplica o que ja' esta' salvo")

            print("\n10. UMA ACAO, COM SAIDA AO VIVO")
            # `status` mudou duas vezes em 06/09/2026: de "Estado da maquina" no
            # "Ciclo de vida" para "O que esta' no ar agora" em "Ver o estado",
            # e dai para "Instalação" — pedido dela: *"unificar o
            # Instalar e Conferir com o Ver o Estado"*. Conferir a maquina e ver
            # o que esta' no ar sao a mesma pergunta feita de dois jeitos.
            secao("Instalação")
            # O «EXECUTAR» PELO NOME, E NAO O PRIMEIRO BOTAO — 23/09/2026
            #   Desde 22/09 (P7) o «ver comando» nasce ANTES do «Executar» no
            #   rodape do cartao, e o `.first` passou a abrir a lista de
            #   comandos em vez de rodar a acao: a gaveta nunca abria, e este
            #   passo e o 10b mediam uma gaveta de 0 px. Medido na primeira
            #   corrida depois do `networkidle`, com captura da aba.
            pag.locator("#conteudo .acao, #conteudo .cartao",
                        has_text="O que está no ar agora").get_by_role(
                            "button", name="Executar", exact=True).click()
            saida = ""
            # PACIÊNCIA DE 25 s, e não de 10: o `meow status` consulta systemd,
            # cosmic-randr e o tema inteiro. Numa máquina ocupada — foi o caso
            # em 01/09/2026, durante a auditoria da pagina — ele
            # passa de dez segundos, e o teste reprovava uma ação que estava
            # certa.
            for _ in range(50):
                pag.wait_for_timeout(500)
                saida = pag.locator(".gaveta, .saida, pre").first.inner_text()
                if len(saida) > 200:
                    break
            checa(len(saida) > 200, f"'Estado da maquina' devolveu {len(saida)} caracteres")
            checa("meow" in saida.lower() or "flavor" in saida.lower(),
                  "a saida e a do comando de verdade")

            print("\n10b. A GAVETA CABE EM 25% E NÃO ENCOSTA NO MENU")
            # Queixa dela, 21/09/2026: *"a tela do terminal, quando clicamos em
            # aplicar ou salvar, toma até a tela do menu e cresce mais
            # verticalmente — ocupa quase metade verticalmente da tela, ao invés
            # de ser no máximo 25% (não afetando o menu lateral)"*.
            #
            # Medido antes da correção, em janela de 900 px: 414 px de gaveta
            # (46% da tela) e o trilho caindo de 841 px para 427. A gaveta era
            # IRMÃ do `.corpo`, e uma irmã que cresce rouba altura de quem está
            # ao lado.
            #
            # A CONTA É DE RAZÃO, E NÃO DE PIXEL CRAVADO: este arquivo roda em
            # 1500x1000 hoje e numa janela qualquer amanhã. 25% é a regra.
            #
            # E O «MENU INTEIRO» NÃO É `trilho == corpo`: antes da correção os
            # dois já mediam o mesmo (427 px), porque quem encolhia era o
            # `.corpo` INTEIRO, com o trilho dentro. O que separa o antes do
            # depois é o `.corpo` chegar à beira de baixo da janela — tudo o que
            # não é cabeçalho é dele.
            #
            # O `fundo` É O DA GAVETA, E NÃO O DO `.corpo` — 21/09/2026
            # Aferir o `.corpo` chegando à beira de baixo confere o que o
            # LAYOUT faz com a coluna, e isso o `trilho == corpo` logo abaixo já
            # conta. O que a pessoa vê é a GAVETA: com o `.corpo` colado no
            # rodapé, ela ainda podia flutuar acima dele — foi o que a revisão
            # mediu, 958 de 1000 no "Terminal" e 924 em "Atualização", uma tira
            # de `--base` debaixo de um painel `--crust`. Quem responde pela
            # queixa é a beira de baixo da gaveta, então é ela que se mede.
            gav = pag.evaluate("""() => {
              const el = document.getElementById('gaveta');
              const g = el.getBoundingClientRect();
              const t = document.getElementById('trilho').getBoundingClientRect();
              const c = document.querySelector('.corpo').getBoundingClientRect();
              return { pct: Math.round(g.height / innerHeight * 100),
                       trilho: Math.round(t.height), corpo: Math.round(c.height),
                       fundo: Math.round(g.bottom), janela: innerHeight,
                       pai: el.parentElement.id,
                       presa: getComputedStyle(el).position };
            }""")
            checa(gav["pct"] <= 25,
                  f"a gaveta ocupa {gav['pct']}% da altura da tela (o teto é 25%)")
            checa(gav["fundo"] >= gav["janela"] - 1,
                  f"e ela mesma desce até o rodapé da janela: "
                  f"{gav['fundo']} px de {gav['janela']}")
            checa(gav["trilho"] == gav["corpo"],
                  f"e o menu ocupa a coluna dele inteira: {gav['trilho']} px de "
                  f"trilho para {gav['corpo']} px de corpo")
            # A CAUSA, E NÃO SÓ O SINTOMA. Um `max-height` menor consertaria o
            # número e deixaria a gaveta irmã do `.corpo` — no dia em que ela
            # voltasse a crescer, o menu encolheria de novo. Quem garante o
            # trilho é o PAI, e é o pai que este passo confere.
            checa(gav["pai"] == "principal",
                  f"e ela é filha do #principal, não irmã do .corpo (pai: "
                  f"{gav['pai'] or '<sem id>'})")
            checa(gav["presa"] == "sticky",
                  f"e está presa no rodapé da coluna ({gav['presa']}) — sem isso "
                  "o conteúdo passa por baixo dela")
            # ... E EM TODA ABA, E NÃO SÓ NUMA LONGA — 21/09/2026
            # Este passo media a aba "Instalação", que é comprida, e ali o
            # `sticky` tem o que fazer: a coluna rola, e ele segura a gaveta na
            # beira de baixo. Numa aba CURTA (`scrollHeight == clientHeight`)
            # não há o que rolar, o `sticky` não gruda em nada e a gaveta fica no
            # fluxo logo depois do conteúdo — 42 px acima do rodapé no
            # "Terminal", 76 px em "Atualização", medido em 1500x1000. A regra é
            # sobre TODA aba; uma aba que encurtar amanhã nasce coberta.
            grupos = pag.evaluate(
                "() => [...document.querySelectorAll('#trilho button[data-grupo]')]"
                ".map(b => b.dataset.grupo)")
            flutuando = []
            for aba_ in grupos:
                pag.locator(f'#trilho button[data-grupo="{aba_}"]').first.click()
                pag.wait_for_timeout(380)
                d = pag.evaluate("""() => {
                  const g = document.getElementById('gaveta').getBoundingClientRect();
                  return { fundo: Math.round(g.bottom), janela: innerHeight };
                }""")
                if d["janela"] - d["fundo"] > 1:
                    flutuando.append(f"{aba_}: {d['fundo']} de {d['janela']}")
            checa(not flutuando,
                  f"e isso vale nas {len(grupos)} abas, curtas e longas"
                  + (f" — {flutuando}" if flutuando else ""))
            # A ALÇA É A BORDA DE CIMA, QUE É A QUE A SPRINT NOMEIA.
            # O item 3 pede que a pessoa cresça a gaveta *"arrastando a borda de
            # cima"*. O `resize: vertical` que estava aqui desenhava a alça no
            # canto INFERIOR DIREITO — com a gaveta presa no rodapé, o último
            # canto da janela — e a borda de cima ficava inerte: medido, puxá-la
            # 150 px deixava a altura em 250, a mesma de antes.
            antes_h, alvo = pag.evaluate("""() => {
              const g = document.getElementById('gaveta').getBoundingClientRect();
              return [Math.round(g.height), [g.left + g.width / 2, g.top + 4]];
            }""")
            pag.mouse.move(alvo[0], alvo[1])
            pag.mouse.down()
            pag.mouse.move(alvo[0], alvo[1] - 150, steps=12)
            pag.mouse.up()
            pag.wait_for_timeout(250)
            depois_h = pag.evaluate(
                "() => Math.round(document.getElementById('gaveta')"
                ".getBoundingClientRect().height)")
            checa(depois_h >= antes_h + 140,
                  f"arrastar a borda de cima 150 px cresce a gaveta: {antes_h} px "
                  f"-> {depois_h} px")
            checa(depois_h <= round(0.6 * gav["janela"]) + 1,
                  f"e o teto de 60vh segura: {depois_h} px de "
                  f"{round(0.6 * gav['janela'])} px")
            # O QUE O ARRASTO ESTICOU VOLTA, pela mesma porta que o `abrirGaveta`
            # usa na abertura seguinte — esticar é para o momento. Sem desfazer,
            # os passos daqui para baixo mediriam uma gaveta de 400 px que
            # ninguém mais pediu.
            pag.evaluate("""() => {
              const g = document.getElementById('gaveta');
              g.style.removeProperty('height');
              g.removeAttribute('data-esticada');
            }""")
            pag.wait_for_timeout(200)
            # O INDICADOR DE «ABAIXO». Com 25% de teto, quem sobe para reler um
            # erro perde o fio do que continua chegando. A pastilha só tem o que
            # dizer quando a saída não coube — então o passo só cobra quando ela
            # de fato não coube.
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
                # E ELA NÃO MENTE DE PORTAS FECHADAS — 21/09/2026
                # Fechar com trabalho vivo deixa o `puxar` de pé (o fluxo de
                # 07/09/2026), e o `puxar` remede a pastilha. Com a gaveta
                # `hidden` ela é `display: none`: `offsetTop` e `clientHeight`
                # valem 0 lá dentro, o limite da busca binária vira 0 e a conta
                # devolve TODAS as linhas. Medido antes da correção: «mais 26
                # linhas abaixo» virava «mais 36», sobre 36 linhas — e a mentira
                # ficava colada, porque depois da última medição o timer morre e
                # mais nada recalcula.
                #
                # O caminho é o do `puxar`, e não um atalho: quem remede é o
                # mesmo ouvinte de rolagem do `#saida`. Reabrir é na mão porque
                # a pastilha que reabre morre junto com o trabalho, e este já
                # terminou; o que se confere é o que ficou ESCRITO enquanto a
                # gaveta estava fechada.
                fechada = pag.evaluate("""() => {
                  const g = document.getElementById('gaveta');
                  const s = document.getElementById('saida');
                  s.scrollTop = 0;
                  s.dispatchEvent(new Event('scroll'));
                  const a = document.getElementById('mais-abaixo');
                  const antes = a ? a.textContent : '';
                  g.hidden = true;
                  s.dispatchEvent(new Event('scroll'));
                  g.hidden = false;
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
                print("  -- a saída coube inteira na gaveta; nada a indicar abaixo")

            print("\n11. O ENSAIO SAIU DA PÁGINA")
            # Pedido dela em 13/09/2026: "eu tinha pedido pra tirar o app do
            # modo sandbox". O interruptor não pode voltar por engano, e a
            # página não pode guardar quem pergunte por ele.
            checa(pag.locator("#seco").count() == 0,
                  "não ha interruptor de ensaio na barra")
            checa(pag.evaluate("() => typeof ensaiando") == "undefined",
                  "e a página não tem mais quem pergunte se esta' ensaiando")

            print("\n12. CONFERIR NÃO ESCREVE")
            # A ABA E DITA AQUI, E NAO HERDADA DO PASSO ANTERIOR.
            #   Este bloco procurava o cartao "Conferir" na aba que sobrou da
            #   verificacao anterior — e quando o passo 10 entrou no meio, com
            #   duas trocas de aba de proposito, o cartao deixou de estar na
            #   tela e o teste morreu num timeout de 30 s. Um passo que depende
            #   de onde o passo anterior parou nao pode ser reordenado; este
            #   agora diz onde quer estar.
            secao("Instalação")
            # A acao anterior precisa TERMINAR: o servidor recusa dois trabalhos
            # ao mesmo tempo (409), e recusar e o comportamento certo dele.
            for _ in range(20):
                pag.wait_for_timeout(500)
                if not pag.locator(".gaveta .rodando, .gaveta [data-rodando]").count():
                    break
            pag.wait_for_timeout(1500)
            md5_antes = md5_conf()
            # "Conferir a maquina" e' o `doctor`, e o `has_text` casa por
            # substring: "Conferir" sozinho pegaria tambem "Conferir e consertar
            # todo dia" se um dia essa acao existir. O rotulo inteiro nao tem
            # esse risco.
            secao("Instalação")
            # O «Executar» pelo nome, pelo mesmo motivo do passo 10: com o
            # `.first` este passo clicava no «ver comando» e o `doctor` nem
            # rodava — a conferencia de que ele so' le passava sem ter lido.
            pag.locator("#conteudo .acao, #conteudo .cartao",
                        has_text="Conferir a máquina").get_by_role(
                            "button", name="Executar", exact=True).click()
            pag.wait_for_timeout(6000)
            checa(md5_conf() == md5_antes, "o doctor so' le: o meow.conf não mudou")

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
            # 46 BOTOES CHAMANDO UMA ACAO QUE NAO EXISTE.
            #   "Banir" e "Devolver", um por imagem da galeria, chamavam
            #   `wallpaper_banir` e `wallpaper_desbanir`; o `ACOES` do servidor
            #   nao tem nenhum dos dois, e `rodarNaGaleria` desiste em silencio
            #   quando o `find` volta `undefined`. O clique nao fazia nada, nao
            #   dizia nada, e nenhum erro chegava ao console — por isso o teste
            #   antigo passava com a galeria inteira morta.
            #
            #   O que a pagina PEDE nao da para ler do DOM: o id mora dentro do
            #   `onclick`. Entao a varredura e nas duas procedencias possiveis,
            #   as duas por regra: o atributo `data-acao*` de qualquer elemento
            #   e o primeiro argumento literal de qualquer `rodar…()` do
            #   `app.js`.
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
            # ONDE HA VALORES FECHADOS, BOTOES.
            #   "Digitei 'gigante' no ESCALA_TELA e sai do campo: aceito em
            #   silencio." Um campo de texto para uma chave que so aceita quatro
            #   valores obriga a decorar os quatro e ainda deixa passar o quinto.
            #   A regra nao lista chave nenhuma: pergunta ao esquema quem declara
            #   `opcoes` e cobra que o cartao daquela chave NAO seja texto livre.
            #   Enquanto o servidor nao reconhecer as opcoes de uma chave, ela
            #   nao entra aqui — e passa a entrar no dia em que reconhecer.
            por_chave = {k["chave"]: k for k in chaves}
            fechadas = [c for c in censo.values()
                        if por_chave.get(c["chave"], {}).get("opcoes")]
            texto_livre = sorted(c["chave"] for c in fechadas if c["texto"])
            checa(not texto_livre,
                  f"nenhuma das {len(fechadas)} chaves de opções fechadas virou campo de texto"
                  + (f" — TEXTO LIVRE: {texto_livre}" if texto_livre else ""))

            com_faixa = [c for c in censo.values() if por_chave.get(c["chave"], {}).get("faixa")]
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

            # DOIS CARTOES NA MESMA TELA NAO PODEM DIZER A MESMA FRASE.
            #   "Os TRES mostram o mesmo bloco: 'O nome do tema de icones que
            #   este projeto constroi…'" — o titulo do vizinho vira o titulo
            #   desta chave quando a ajuda e herdada de um bloco que cobre
            #   varias. Um cartao com o titulo de outra chave nao explica a
            #   chave dele: engana sobre ela.
            #
            #   A comparacao e POR ABA, e nao pela pagina inteira, porque o que
            #   ela ve de uma vez e uma aba: dois "Fim" em secoes diferentes sao
            #   duas coisas com o mesmo nome curto, e cada uma se explica pela
            #   companhia; oito "Dock" na mesma tela sao oito cartoes que ela
            #   nao tem como distinguir sem ler o nome da chave em cima.
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
            # Pedido dela em 06/09/2026: "os slides mostrando os ajustes ... real
            # time quando for algo nesse sentido". Ate' entao o deslizante so'
            # mexia no NUMERO enquanto ela arrastava; o desenho so' mudava ao
            # SOLTAR, pelo caminho comprido do `aplica()` + `render()`.
            #
            # Duas coisas sao medidas aqui, e a segunda importa tanto quanto a
            # primeira: o desenho muda, E a barra do Salvar NAO aparece. Um
            # arrasto que gravasse quebraria a regra da casa — "gravar nao e'
            # aplicar" — sem ninguem perceber, porque a tela ficaria igual.
            #
            # O VALOR TEM DE SOBREVIVER AO PASSO. Na primeira versao deste teste
            # eu escrevia max*0.82; com max 24 e passo 1 isso volta para 20, que
            # era o valor original, e o teste acusava "nao mudou" num desenho que
            # mudava certo. Ir para a ponta oposta e' o unico valor que o passo
            # nao pode arredondar de volta.
            # A BARRA TEM DE COMECAR APAGADA, senao a segunda medicao mente.
            #   As seções anteriores deixam escolhas pendentes, e "a contagem
            #   esta' visivel" passaria a ser verdade ANTES do arrasto — o teste
            #   acusaria gravacao em todas as abas, e a acusacao seria falsa.
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
                # AS DUAS PONTAS, E NÃO SO' UMA — 13/09/2026. Desde que o "como
                # esta'" do desenho passou a ser a MAQUINA (`valendo_agora`), a
                # ponta escolhida pode ser justamente o valor que a maquina tem:
                # o modo de leitura dela guarda 1000 K, o piso da regua, e
                # arrastar ate' la não muda a tela — o desenho, certo, fica
                # igual. As duas pontas nunca sao as duas o valor da maquina.
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
            # O RELOAD ESPERA O TRILHO, PELO MESMO MOTIVO DO `goto` DO PASSO 1 —
            # 23/09/2026, sprint P33
            #   O `reload` volta no `load`, e o `iniciar()` so' desenha o trilho
            #   quando o esquema chega. Medido no brinquedo: 1,8 s entre um e
            #   outro, e com os 1500 ms fixos daqui o passo 17b contava as abas
            #   de uma pagina que ainda nao tinha nenhuma — "nenhum deslizante
            #   nas 0 abas", e duas reprovacoes que nao eram da pagina. As
            #   outras idas e voltas deste arquivo esperam o mesmo seletor.
            pag.reload()
            pag.wait_for_selector("#trilho button")
            pag.wait_for_timeout(1500)

            print("\n17b. O DESLIZANTE NASCE LIVRE, E OS DOIS BOTOES")
            # Queixa dela em 21/09/2026: "em qualquer canto que eu precise
            # apertar em «usar numero» pra poder usar o slicer, ta errado. ele
            # tem que ta liberado por default." E: "deixar como esta induz ao
            # erro. vc muda o slicer e quer que fique como esta. clica e ele
            # reseta."
            #
            # MEDIDO ANTES DA MUDANCA, aba a aba: 25 deslizantes na pagina, 17
            # nascendo `disabled` (11 so' na aba Painel e dock), 17 botoes «Usar
            # numero» cuja unica funcao era destravar o vizinho, e 31 botoes
            # «Deixar como esta».
            #
            # SAO QUATRO COBRANCAS, E A TERCEIRA E' A QUE IMPORTA MAIS.
            #   Tirar a trava e' facil; tirar a trava SEM perder o terceiro
            #   estado e' a sprint. Um deslizante livre marcando 24 e um que
            #   ESCOLHEU 24 sao coisas diferentes — o COSMIC se comporta
            #   diferente nos dois — e a unica coisa que os separa agora e' o
            #   desenho. Entao o teste cobra os tres sinais por nome: a classe
            #   da trilha em traco, o `aria-valuetext` (que e' o unico dos tres
            #   que chega a quem nao ve) e o NUMERO NUNCA APARECENDO SOZINHO.
            #   Este ultimo e' cobrado pela negativa de proposito: sao duas
            #   redacoes legitimas — "como esta: 24" quando a chave esta' vazia
            #   e "Automatico" quando ela guarda a palavra especial
            #   (`MIDIA_FONTE="auto"`) — e o que as duas tem em comum, e o que
            #   importa, e' que nenhuma delas se le como um valor escolhido.
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
            checa(deixar == 0 and restaurar > 0,
                  f"«Deixar como esta» virou «Restaurar ao padrao»"
                  f" ({deixar} contra {restaurar})")
            # O TERCEIRO ESTADO CONTINUA NA TELA, E OS TRES SINAIS ANDAM JUNTOS.
            #   Um deles faltando e' o defeito que a sprint chama de "o problema
            #   so' mudou de lugar": a trava saiu e nada ocupou o lugar dela.
            checa(comoesta["classe"] > 0
                  and comoesta["valuetext"] == comoesta["classe"]
                  and comoesta["palavra"] == comoesta["classe"],
                  f"os {comoesta['classe']} deslizantes em «como esta» trazem os tres"
                  f" sinais: trilha em traco, aria-valuetext ({comoesta['valuetext']})"
                  f" e numero que nunca aparece sozinho ({comoesta['palavra']})")

            # E O GESTO: arrastar escolhe, sem pedir licenca antes. A aba e' a
            # que ele citou, e o cartao acende com o «Aplicar» que fecha aquela
            # escolha ali mesmo. O botao NAO e' clicado aqui, e de proposito:
            # clicar roda o instalador na maquina de quem testa, que e' a
            # mesma razao de `Instalar` e `Desinstalar` ficarem de fora.
            secao("Painel e dock")
            pag.wait_for_timeout(600)
            livre = pag.locator("#principal input[type=range].faixa-comoesta")
            if livre.count():
                antes_marcados = pag.locator("#principal .cartao.nao-salvo").count()
                # UM PUNHO, E NAO UM SELETOR — o seletor tem `.faixa-comoesta`
                # dentro, e a primeira coisa que o arrasto faz e' TIRAR essa
                # classe: reavaliar o locator depois disso acharia o deslizante
                # SEGUINTE, e o teste mediria um elemento que nao foi tocado.
                # (Perdido uma vez aqui, em 21/09/2026.)
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
            # A ROTA NOVA DO SALVAR — 13/09/2026. Ela grava as escolhas e
            # comeca o instalador na mesma chamada, e a unica coisa entre ela e
            # um meow.conf pela metade e' a peneira que vem ANTES. O teste bate
            # na rota direto com um valor que o esquema recusa junto de um que
            # ele aceitaria: nada pode ser gravado, e nenhum trabalho pode
            # comecar. (A seção que morava aqui conferia que as rotas recusavam
            # em ensaio; o ensaio saiu, e com ele o `seco` de todas elas.)
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
            # A TRAVA QUE FALTOU NAS DUAS TENTATIVAS ANTERIORES.
            #   A ideia do par-como-controle ja' caiu duas vezes aqui, sempre
            #   pelo mesmo defeito: dois botoes com borda, lado a lado, e a
            #   MESMA figura nos dois. Escolher entre duas imagens iguais e'
            #   pior do que escolher entre as palavras «Sim» e «Não».
            #
            #   A pagina decide quem ganha par por uma conta sobre o DOM
            #   (`areaQueMuda`, em `app.js`). Essa conta pode errar — errou
            #   quatro vezes enquanto era escrita, e foi esta secao que acusou
            #   as quatro. Entao ela nao tem a ultima palavra: aqui os dois
            #   lados sao FOTOGRAFADOS e comparados pixel a pixel, o que nao
            #   depende de nenhuma heuristica.
            #
            #   O PISO SAI DO VAO MEDIDO, e ele mudou de lugar em 07/09/2026.
            #   Ate' entao o que a pagina aceitava comecava em 0,53% — tecnica-
            #   mente diferente e visualmente identico, que foi a queixa da
            #   conferencia de uso ("o Sim e o Nao desenham a mesma figura").
            #   Onze desenhos foram refeitos e o corte da pagina subiu de 100
            #   para 2000 de tinta, recusando os dois pares que nao tinham
            #   desenho honesto (WALLPAPER_ORDEM e STEAM_VIGIA, que voltaram
            #   para «Sim» e «Nao»). Medidos os 31 que sobraram, o mais parecido
            #   e' LEITURA_AGENDA com 4,08%.
            #
            #   2% e' metade disso, e e' onde o piso fica: alto o bastante para
            #   pegar uma regressao de verdade, e com folga para o serrilhado
            #   nao derrubar a conferencia por meio ponto.
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
                    # [P77: os ajustes técnicos moram num «⋯» fechado; abertos
                    # aqui, os pares de dentro também são medidos.]
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
            # Cinco defeitos medidos em 07/09/2026 percorrendo a pagina botao a
            # botao. Os cinco eram invisiveis para quem le o codigo e obvios
            # para quem usa: e por isso que eles viram conferencia.

            # (a) O BALAO DO "?" NAO PODE ROUBAR O CLIQUE DO PROPRIO CARTAO.
            #     Ele cai em `top: 100%`, ou seja, em cima dos controles. Com o
            #     `.dica:hover` sustentando-o, o caminho do "?" ate a opcao
            #     atravessava o balao e 22 dos 50 botoes de "Cor e tela" ficavam
            #     inalcancaveis. Mede-se pelo ponteiro: quem esta sob o centro
            #     do botao tem de ser o botao.
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

            # (b) NENHUM BOTAO CAI NA FOLHA DO NAVEGADOR. Um `<button>` sem
            #     regra de autor sai em Arial, `border: 2px outset white` e o
            #     cinza de sistema — no meio de uma pagina em Inter e Catppuccin.
            #     Aconteceu com o "Deixar como esta" do par, em tres abas.
            crus = []
            for aba_ in ("Cor e tela", "Painel e dock", "Modo de leitura", "Manutencao"):
                alvo_ = pag.locator(f'#trilho button[data-grupo^="{aba_[:6]}"]').first
                if not alvo_.count():
                    continue
                alvo_.click(); pag.wait_for_timeout(700)
                # SO CONTA BOTAO COM TEXTO. As amostras de cor sao <button>
                # de 28px sem conteudo nenhum, pintadas por `style` — nelas a
                # familia da fonte nao desenha coisa alguma, e a primeira
                # versao desta conferencia as acusou por isso.
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

            # (c) OS "EXECUTAR" DA MESMA FILEIRA FICAM NA MESMA LINHA. Com
            #     `align-items: start` na grade cada cartao tinha a propria
            #     altura e os botoes saiam em escadinha de ate 20px. Um pixel de
            #     folga e arredondamento de sub-pixel; vinte e defeito.
            #     O `:not(.ver-comando)` e' de 23/09/2026: desde a P7 o rodape
            #     tem DOIS botoes, e o «ver comando» quebra linha junto das
            #     pastilhas quando elas sao muitas — contado aqui, ele virava
            #     uma escada de 42 px que o «Executar» nao tem.
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

            # (d) A FAIXA GRUDADA ENCOLHE QUANDO GRUDA. Medida em 213px o
            #     tempo todo — um quinto da altura util — ela escondia a fileira
            #     de titulos que passava por baixo: sobravam botoes sem nome.
            #
            #     O QUE ESTA CONFERENCIA NAO COBRA: "nao tapa nada". Uma faixa
            #     `sticky` opaca tapa por definicao o que rola sob ela, e um
            #     alvo de zero so passaria por sorte da posicao de rolagem — foi
            #     o que aconteceu na primeira versao desta linha, que passou uma
            #     vez e reprovou na seguinte sem que nada tivesse mudado. O que
            #     se pode exigir, e o que resolve a queixa, e ela ser PEQUENA:
            #     100px contra 213, e a legenda saindo de cena enquanto e tira.
            faixa_ruim = []
            for aba_ in ("Cor e tela", "Logo do sistema", "Papel de parede"):
                pag.locator(f'#trilho button[data-grupo="{aba_}"]').first.click()
                pag.wait_for_timeout(1100)
                # [P77: a rolagem é medida a partir da FAIXA, e não do topo da
                # página — em «Papel de parede» a coleção passou a abrir a
                # página, e 600 px ainda não chegavam ao desenho.]
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
            # Seis lentes de uso em 07/09/2026; estas linhas cobram os consertos.

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

            # (c) SEM ESCOLHA, O SALVAR FICA E NÃO SE DESTACA — 13/09/2026. O
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

            # (f) O IMPORTAR É BOTÃO — uma <label> não entra na fila do Tab, e
            #     a conferência de teclado mediu ZERO paradas: quem usa só
            #     teclado não importava um .conf de jeito nenhum.
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

            # (i) O BALAO DO «?» DIZ DE QUEM E' O TEXTO QUANDO ELE E' EMPRESTADO.
            #     Trinta chaves herdam o comentario da irma de cima, e o balao
            #     abria o bloco cru: o de "Imagem escura ate as" comeca por uma
            #     captura de 23:57 e a luminancia do acervo — verdade sobre a
            #     chave dona, estranho sobre esta. A cadeia importa: o _FIM herda
            #     de WALLPAPER_NOITE, nao da vizinha _INICIO.
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

            # (j) A CAIXA DO DESENHO MEDE O QUE O DESENHO MEDE. Com `max-height`
            #     e `width: 100%` a caixa ficava com a largura da coluna e o
            #     desenho se centralizava dentro dela: medido, 459px de caixa
            #     para 249px de desenho, comecando 115px a direita da margem do
            #     texto. Aqui a folga tem de ser a do recheio, nao um vao.
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

            # (k) E O QUE SANGRA DE PROPOSITO CONTINUA INTEIRO. A caixa colada
            #     passou a recortar o que os desenhos pintam FORA do viewBox — o
            #     relogio da faixa virou "8:00", com o 1 comido. Dois desenhos
            #     sangram de proposito; o `overflow: visible` os devolve.
            corte = pag.evaluate("""() => {
              const svg = document.querySelector('.previa-bloco .par-previa svg');
              return svg ? getComputedStyle(svg).overflow : '';
            }""")
            checa(corte == "visible",
                  f"o desenho que sangra fora do viewBox nao e' recortado ({corte})")

            # (l) A FAIXA NAO SAMBA ENQUANTO ELA ROLA. Queixa dela: "os icones
            #     que ficam congelados ficam sambando na tela tipo travando, em
            #     todas as paginas". Medido quadro a quadro: o `presa` trocava
            #     de estado 32 a 62 vezes numa rolagem so, porque a ancoragem de
            #     rolagem do Chrome compensava o encolhimento da faixa mexendo
            #     no scrollTop (-103px em "Icones"), o que devolvia a sentinela
            #     para a tela e desgrudava a faixa — as duas correcoes se
            #     anulando em ciclo. Uma troca (solta -> grudada) e' o certo;
            #     duas ou mais e' o samba de volta, e nenhum salto de rolagem
            #     pode partir do navegador.
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
            #     guarda, medido em 08/09/2026 numa janela de 830px: "Atualizacao"
            #     tinha 106px de folga e a faixa encolhe 174. Rolar ate o fim
            #     prendia a faixa, a pagina encolhia ate ficar do tamanho exato
            #     da tela e o navegador grampeava o scrollTop em zero — a barra
            #     nao descia NUNCA. Ela: "pagina de atualizacao e outras seguem
            #     com aquele problema de impedir de descer a barra de navegacao".
            #
            #     A regra e sobre TODA aba, e nao sobre uma lista: a aba curta e'
            #     descoberta medindo (folga menor que o encolhimento da faixa), e
            #     uma aba que encurtar amanha nasce coberta.
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
            # ELA VEM ANTES DA 20b DE PROPOSITO, e o contrato da sprint pedia
            # depois: a 20b confere que o console ficou limpo "em toda a visita",
            # e uma secao depois dela seria a unica da suite cujos erros de
            # JavaScript ninguem le. Em 07/09 a suite passou 84/84 com defeito
            # visivel a olho nu — nao se acrescenta um ponto cego de proposito.
            secao("Ícones")
            pag.wait_for_selector(".grade-apps button.app", timeout=15000)
            # Um aplicativo com arte de fabrica: o primeiro dos doze primeiros
            # cuja oficina responde com pelo menos cinco cartoes. Nao se fixa um
            # nome porque a grade e' a maquina dela; se nenhum servir, pula.
            #
            # E EM QUE A SUAVIDADE MUDA O TRACO A VISTA — 23/09/2026, revisao
            # da P33
            #   A regua, mais abaixo, sai do cartao «Limpo» e vai a `SUAVE`, e
            #   a conferencia cobra que a lupa mude mais de 0,3% dos pixels.
            #   Cinco cartoes nao garantem que haja o que mudar, e foi medido
            #   no brinquedo com a regua indo a 9: o primeiro da grade (o
            #   «Arquivos» do COSMIC, arte do hicolor) volta da rota com o MESMO
            #   SVG, 0,0%; o seguinte, o BleachBit, volta com outro texto e o
            #   mesmo numero de nos, 0,1% — abaixo do piso que separa desenho
            #   novo do antialiasing. Nos dois a pagina redesenhou exatamente o
            #   que recebeu, e a conferencia reprovava a arte, nao a pagina.
            #
            #   Entao a pergunta vai antes, e por outro caminho: o SVG do
            #   «Limpo» e o que a ROTA devolve com `SUAVE` sao desenhados pelo
            #   mesmo `desenhar()` da lupa, em duas caixas `.oficina-lupa` da
            #   largura dela, e medidos com o mesmo `pixels_diferentes` e o
            #   mesmo piso. So' serve o aplicativo em que a diferenca aparece.
            #   Isto nao e' a conferencia de novo: ela passa pela regua, pelo
            #   `reguar()` e pela repintura da lupa, e e' ali que um defeito da
            #   pagina apareceria — com a arte ja' provada capaz de mudar.
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
                # `> summary`, e nao `summary`: desde 09/09 a oficina tem um
                # SEGUNDO details dentro dela ("Editar o SVG"), e o seletor solto
                # casa os dois — o Playwright recusa em modo estrito.
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
                # O id do `.desktop` que a oficina abriu. Ele nao e' fixo: a
                # grade e' a maquina de quem roda, e as chamadas de porta feitas
                # daqui para baixo precisam falar do MESMO aplicativo que esta
                # na tela — pergunta-se ao estado, nunca se adivinha.
                OFICINA_APP = pag.evaluate("() => OFICINA.app")
                folha = pag.locator(".oficina-folha")
                checa(folha.locator("figure.oficina-original img").count() == 2,
                      "o original esta na folha, a 48 e a 96, ao lado das variacoes")
                # CONTAR AS <img> NAO PROVA QUE ELAS DESENHAM, e foi a foto que
                # pegou: a arte de fabrica de metade dos aplicativos desta
                # maquina e' um link simbolico do flatpak, o `/previa` resolvia o
                # link e caia fora das raizes permitidas, e o cartao «Original» —
                # que e' a metade da tela que responde "nao e tao bonito quanto o
                # original" — aparecia como icone quebrado. `naturalWidth` e' a
                # unica pergunta que o navegador responde com a verdade.
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
                # se mede nesta tela: com `fill:none`, a area "dentro" de um path
                # NAO E' DO PATH, e sem `pointer-events: stroke` o clique
                # atravessa e cai no <div> atras. Nao basta ler o estilo — o que
                # prova e' mirar um ponto SOBRE a linha (`getPointAtLength`, o
                # mesmo ponto que o mouse dela acertaria) e perguntar ao
                # navegador quem esta la. Um `.click()` de locator mira o CENTRO
                # da caixa do path, que num contorno e' o vazio do meio.
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

                # ------------------------------------------------------------
                # AS DUAS REGUAS NOVAS — 09/09/2026
                #   Ela: "falta setar cores e os outros dois slicers". Sao
                #   `Linhas fracas` (--peso-fronteira) e `Traco minimo`
                #   (--min-traco), e a regra que as governa e' uma so: em 0 elas
                #   nao existem. A afirmacao abaixo e' essa regra, medida pela
                #   PORTA — dois `vetorizar` iguais em tudo menos pelas duas
                #   chaves, e o SVG que volta tem de ser o mesmo texto.
                # ------------------------------------------------------------
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

                # E LIGADAS, ELAS CHEGAM AO CONVERSOR. A afirmacao e' a STRING
                # CANONICA e nao a foto: quantos tracos o `--min-traco` tira
                # depende do icone que esta grade ofereceu hoje, e um teste que
                # depende disso falha na maquina de outra pessoa. A string e' o
                # contrato — e' ela que vai para o campo 4 do mapa.
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

                # ------------------------------------------------------------
                # O CAMPO DE COR — 09/09/2026
                #   Ela: "FALTA UM CAMPO PRA SELECIONAR As cores". A cor ja
                #   estava viva na tela (a oficina desenha na cor do mapa) e era
                #   justamente isso que fazia faltar: nao havia como troca-la
                #   sem fechar a oficina. Duas coisas se afirmam aqui, e a
                #   segunda e' a regra da casa: escolher NAO grava.
                # ------------------------------------------------------------
                amostras = pag.locator(".oficina-lado .cores-grade button")
                checa(amostras.count() >= 14,
                      f"a oficina tem a fileira de cores da paleta ({amostras.count()} amostras)")
                mapa_c = os.path.join(RAIZ, "assets", "icones", "apps-convertidos.map")
                mapa_a = os.path.join(RAIZ, "assets", "icones", "apps-arcticons.map")
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

                # ------------------------------------------------------------
                # O EDITOR DE FORA, E A VOLTA — 09/09/2026
                #   Ela: "o botao svg deveria abrir o svg no app que eu tiver se
                #   eu editar la". O que este teste exercita e' a VOLTA, que e' a
                #   metade que decide se o recurso funciona: sem ela, ela salva
                #   no Boxy SVG e o painel continua mostrando o desenho de antes.
                #
                #   A IDA NAO E' CLICADA, E ISSO E' DE PROPOSITO. Clicar em
                #   «Abrir no ...» faria NASCER UMA JANELA na tela de quem esta
                #   rodando o teste. Quem segura a janela e' o servidor: o painel
                #   subiu com `--sem-abrir`, que liga `MEOW_APP_SEM_JANELA=1`, e
                #   a rota para antes do `Popen` (ate' 13/09/2026 era um `seco:
                #   true` no corpo, que saiu junto com o ensaio). Nenhum caminho
                #   deste arquivo abre um programa.
                # ------------------------------------------------------------
                # O `<details>` «Editar o SVG» ABRE PRIMEIRO, e nao e' detalhe de
                # teste: dentro de um `details` fechado o botao existe no DOM e
                # nao existe para quem olha — `inner_text()` volta vazio e um
                # clique estoura por elemento invisivel. Abrir e' o que ela faz.
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

                # O «USAR» NÃO E' CLICADO — 13/09/2026. Ate' hoje ele era
                # apertado com o ensaio ligado, e so' torrava. Sem o ensaio, o
                # clique grava o desenho E roda `icones_traco` na maquina de quem
                # testa. A escrita e' conferida logo abaixo, pela porta, e
                # devolvida no `finally`; aqui fica so' a prova de que o botão
                # mora no resumo, onde ela o procura.
                checa(pag.locator("details.oficina > summary button").count() == 1,
                      "o «Usar» mora no resumo da oficina")

                # ------------------------------------------------------------
                # E O SALVAR GRAVA A COR NO CAMPO CERTO — 09/09/2026
                #   Este e' o UNICO ponto desta secao que escreve de verdade, e
                #   ele devolve tudo no `finally`. A pergunta que so uma escrita
                #   responde: a cor escolhida na oficina cai no TERCEIRO campo
                #   da linha do mapa que passa a ser dono do aplicativo?
                #
                #   NAO SE CLICA NO «USAR», e nao e' descuido: aquele botao faz
                #   duas coisas, e a segunda e' `icones_traco` — reconstruir o
                #   tema de icones da maquina inteira. O que se testa aqui e' a
                #   ESCRITA, entao chama-se a porta que escreve, e so ela.
                #
                #   A linha do `apps-convertidos.map` e' `nome:origem:cor[:params]`
                #   — a cor e' o campo 3. Salvar um desenho sempre passa a posse
                #   para este mapa (o `_tirar_do_mapa_arcticons` tira o nome do
                #   outro, porque um nome nos dois mapas faz o `_conferir_gemeos`
                #   estourar), e por isso ele e' o mapa "dono" depois do Usar.
                nome_icone = pag.evaluate("() => OFICINA.nome") or OFICINA_APP
                conv_dir = os.path.join(RAIZ, "assets", "icones", "convertidos-apps")
                guardados = {}
                for c in (mapa_c, mapa_a,
                          os.path.join(conv_dir, nome_icone + ".svg"),
                          os.path.join(conv_dir, "retoques", nome_icone + ".svg")):
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
                    with open(mapa_c, encoding="utf-8") as fh:
                        for linha in fh:
                            corte = linha.strip()
                            if corte and not corte.startswith("#") \
                               and corte.split(":")[0].strip() == nome_icone:
                                campos = [c.strip() for c in corte.split(":")]
                    checa(len(campos) >= 3 and campos[2] == cor_alvo,
                          f"e ela esta no CAMPO 3 da linha de {nome_icone} no "
                          f"apps-convertidos.map ({':'.join(campos) or 'linha nao achada'})")
                    fora = []
                    with open(mapa_a, encoding="utf-8") as fh:
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
                    # rola, quem rola e' a coluna. E o alvo e' a OFICINA: um
                    # scrollTop fixo enquadrava o topo da aba e a folha ficava
                    # fora da foto, que e' o mesmo que nao tirar foto.
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

            print("\n23. DUAS LEITURAS DA GAVETA NO AR")
            # A CORRIDA DO `puxar` — 24/09/2026, sprint P57 (item 2)
            #   O `puxar` lê o `TRABALHO` antes do `await` e escreve nele depois,
            #   e o intervalo de 400 ms dispara uma leitura nova com a anterior
            #   ainda no ar sempre que o servidor demora — com a máquina
            #   carregada, é a regra. Derrubou uma rodada do gate em «Ouvir o
            #   som»: a leitura que voltava depois do fim escrevia num
            #   `TRABALHO` que já era `null`. As três corridas abaixo são as que
            #   o intervalo produz, com o `/api/trabalho` de mentira respondendo
            #   na ordem que o teste escolhe: a leitura velha do MESMO trabalho
            #   que chega por último (a saída repetia), a que chega depois do
            #   fim (a exceção) e a de um trabalho que acabou chegando no
            #   trabalho SEGUINTE (escrevia na gaveta dele e o dava por
            #   terminado, com ele ainda rodando no servidor).
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
              const trabalho = (id) => ({ id, rotulo: 'Leitura dupla', comando: 'meow teste',
                                          escreve: false, fim: { '0': ['ok', 'pronto'] } });
              const erros = [];
              const ouvir = (e) => erros.push(String((e.reason && e.reason.message) || e.reason));
              window.addEventListener('unhandledrejection', ouvir);
              const fora = {};
              try {
                abrirGaveta(trabalho('a'));          // leitura 0, desde 0
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

                abrirGaveta(trabalho('b'));          // leitura 3
                clearInterval(TRABALHO.timer);
                puxar();                             // leitura 4
                await tique();
                responde(3, ['três'], false);
                await tique();
                responde(4, ['três'], false);        // depois do fim
                await tique();

                abrirGaveta(trabalho('c'));          // leitura 5
                clearInterval(TRABALHO.timer);
                puxar();                             // leitura 6
                await tique();
                responde(5, ['quatro'], false);
                await tique();
                abrirGaveta(trabalho('d'));          // leitura 7
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
                  "a leitura de um trabalho que acabou não escreve na gaveta do seguinte nem o "
                  f"dá por terminado: vivo={seguinte['vivo']}, saída {seguinte['saida']} e depois "
                  f"{seguinte['depois']}")

            print("\n24. A GRADE DE APLICATIVOS NÃO SOME NO FIM DE UM TRABALHO")
            # A RELEITURA DA GRADE — 24/09/2026, sprint P57 (item 6)
            #   Um trabalho que escreve esquece a lista de aplicativos (P46), e a
            #   grade de Ícones era trocada por «Lendo os aplicativos…» até a
            #   primeira pintura seguinte pedir a lista de novo: medido numa casa
            #   de brinquedo, 110 ms sem cartão nenhum, 240 ms com a máquina
            #   carregada, e o gate tropeçava nisso. Um vigia no `#conteudo`
            #   anota toda pintura sem cartão, ou com o «Lendo», do clique até
            #   depois das três releituras do fim — e não pode anotar nenhuma. A
            #   ação é a «Próxima imagem»: escreve, é rápida, e não toca no
            #   meow.conf que o passo 21 confere.
            #   E A LISTA É PEDIDA UMA VEZ SÓ (revisão da P57): o `.then` do
            #   esquema a pedia de novo, já relida.
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

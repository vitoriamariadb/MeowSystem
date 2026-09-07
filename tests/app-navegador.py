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
    11. O modo seco atravessa a navegacao.
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
import subprocess
import sys
import tempfile
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONF = os.path.expanduser("~/.config/meow/meow.conf")
FOTOS = "--fotos" in sys.argv
DESTINO_FOTOS = "/tmp/meow-app-testes"

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("pulado: playwright nao esta instalado neste interpretador.")
    print("  " + sys.executable)
    print("  receita no cabecalho de tests/app-navegador.py")
    sys.exit(3)

falhas = []
passos = []


def checa(condicao, texto):
    passos.append((bool(condicao), texto))
    print(("  ok " if condicao else "  XX ") + texto)
    if not condicao:
        falhas.append(texto)


# O MODO SECO VIROU BOTAO, E BOTAO NAO E' CAIXA DE MARCAR.
#   Ate' 06/09/2026 o interruptor era <input type=checkbox>, e este arquivo
#   falava com ele por .check() / .uncheck() / .is_checked(). Ela pediu botao
#   que fica aceso ("ele ta' como box mas poderia ser um botao que fica ativo,
#   cor amarela fraca"), e o Playwright RECUSA os tres num <button>: "Not a
#   checkbox or radio button". Nao e' falha de teste, e' contrato de elemento.
#   O estado agora mora no aria-pressed, que e' o mesmo atributo que o leitor de
#   tela le' — uma verdade so', para a maquina e para quem enxerga.
#
#   As duas funcoes sao IDEMPOTENTES de proposito: elas conferem antes de
#   clicar. Um .click() cego alternaria, e um teste que alterna um estado que
#   ja' estava certo desliga a rede de seguranca no meio do proprio teste.
def seco_ligado(pag):
    return pag.locator("#seco").get_attribute("aria-pressed") == "true"


def seco(pag, ligado):
    if seco_ligado(pag) != ligado:
        pag.locator("#seco").click()
        pag.wait_for_timeout(200)
    return seco_ligado(pag) == ligado


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
    o passo seguinte contar 2 escolhas onde a frase dele diz 1."""
    if pag.locator("#barra-salvar").is_visible():
        descartar_tudo(pag)
        pag.wait_for_timeout(400)


def sobe_servidor():
    """Sobe o painel e devolve (processo, url). A URL sai na PRIMEIRA linha do
    `--sem-abrir` — e e a unica forma de saber a porta, que o kernel escolhe."""
    proc = subprocess.Popen(
        [os.path.join(RAIZ, "app", "run.sh"), "--sem-abrir"],
        cwd=RAIZ, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
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
    if not os.path.exists(CONF):
        print("pulado: nao ha ~/.config/meow/meow.conf — rode o ./install.sh antes.")
        return 3
    if FOTOS:
        os.makedirs(DESTINO_FOTOS, exist_ok=True)

    md5_inicial = md5_conf()
    log_nivel_inicial = valor_de("LOG_NIVEL")
    proc, url = sobe_servidor()
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
            pag.goto(url, wait_until="networkidle")

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
            sem_cartao = sorted(k["chave"] for k in chaves if k["chave"] not in censo)
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
            checa(n_fotos > 20, f"a galeria mostra {n_fotos} papeis de parede")
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
            checa(not pag.locator("#barra-salvar").is_visible(),
                  "e desfazer o gesto à mão devolve a lista ao disco: a barra some sozinha")
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
            checa(pag.locator("#barra-salvar").is_visible(), "a barra do Salvar aparece")
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
            checa(pag.locator("#barra-salvar").is_visible(),
                  "depois de duas trocas de aba, a escolha continua la")
            checa(pag.locator('#conteudo article[data-chave="LOG_NIVEL"].nao-salvo').count() >= 1,
                  "o cartao continua marcado como nao salvo")

            print("\n   ... e o Descartar devolve tudo")
            descartar_tudo(pag)
            pag.wait_for_timeout(500)
            checa(not pag.locator("#barra-salvar").is_visible(), "Descartar limpa a barra")
            checa(valor_de("LOG_NIVEL") == log_nivel_inicial, "e o disco nunca foi tocado")

            print("\n   ... e o Salvar em modo seco nao escreve")
            md5_antes_seco = md5_conf()
            seco(pag, True)
            # O cartao esta' na pagina em que o teste acabou de entrar; a busca
            # o traz de volta sem depender de qual pagina e'.
            pag.fill("#busca", "LOG_NIVEL")
            pag.wait_for_timeout(400)
            pag.locator("#conteudo .cartao button", has_text=re.compile(f"^{alvo}$")).first.click()
            pag.wait_for_timeout(400)
            pag.locator("#botao-salvar").click()
            pag.wait_for_timeout(2500)
            checa(md5_conf() == md5_antes_seco, "Salvar em modo seco: o meow.conf nao mudou")
            seco(pag, False)

            print("\n10. UMA ACAO, COM SAIDA AO VIVO")
            # `status` mudou duas vezes em 06/09/2026: de "Estado da maquina" no
            # "Ciclo de vida" para "O que esta' no ar agora" em "Ver o estado",
            # e dai para "Instalação" — pedido dela: *"unificar o
            # Instalar e Conferir com o Ver o Estado"*. Conferir a maquina e ver
            # o que esta' no ar sao a mesma pergunta feita de dois jeitos.
            secao("Instalação")
            pag.locator("#conteudo .acao, #conteudo .cartao",
                        has_text="O que está no ar agora").locator("button").first.click()
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

            print("\n11. O MODO SECO ATRAVESSA A NAVEGACAO")
            # O modo seco e a rede de seguranca da pagina inteira: com ele
            # ligado, Salvar e Rodar preveem em vez de escrever. Uma rede que se
            # desliga sozinha ao trocar de aba e pior que rede nenhuma, porque
            # ela continua desenhada na tela. (A auditoria mediu o outro lado
            # disso: ele nasce DESLIGADO a cada carga da pagina.)
            seco(pag, True)
            secao("Instalação")
            secao("Terminal")
            pag.fill("#busca", "wallpaper")
            pag.wait_for_timeout(300)
            pag.fill("#busca", "")
            pag.wait_for_timeout(300)
            checa(seco_ligado(pag),
                  "ligado o Modo seco, ele continua ligado depois de duas abas e uma busca")

            print("\n12. O MODO SECO NAO ESCREVE")
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
            seco(pag, True)
            pag.wait_for_timeout(300)
            # "Conferir a maquina" e' o `doctor`, e o `has_text` casa por
            # substring: "Conferir" sozinho pegaria tambem "Conferir e consertar
            # todo dia" se um dia essa acao existir. O rotulo inteiro nao tem
            # esse risco.
            secao("Instalação")
            pag.locator("#conteudo .acao, #conteudo .cartao",
                        has_text="Conferir a máquina").locator("button").first.click()
            pag.wait_for_timeout(6000)
            checa(md5_conf() == md5_antes, "com o modo seco ligado, o meow.conf nao mudou")
            seco(pag, False)

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
            #   As secoes anteriores deixam escolhas pendentes, e "a barra esta'
            #   visivel" passaria a ser verdade ANTES do arrasto — o teste
            #   acusaria gravacao em todas as abas, e a acusacao seria falsa.
            if pag.locator("#barra-salvar").is_visible():
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
                puxadores.first.evaluate("""el => {
                  const mn = Number(el.min), mx = Number(el.max), atual = Number(el.value);
                  el.value = String(atual === mn ? mx : mn);
                  el.dispatchEvent(new Event('input', {bubbles: true}));
                }""")
                pag.wait_for_timeout(500)
                agora = pag.locator(".previa-bloco, #conteudo .grade-barras")
                depois = [agora.nth(i).inner_html() for i in range(agora.count())]
                mudou = any(a != b for a, b in zip(antes, depois))
                gravou = pag.locator("#barra-salvar:visible").count() > 0
                if mudou and not gravou:
                    vivas += 1
                else:
                    paradas += 1
                    print(f"   XX {aba}: desenho mudou={mudou} gravou={gravou}")
            checa(vivas > 0 and paradas == 0,
                  f"as {vivas} abas com deslizante repintam o desenho durante o arrasto")
            checa(not pag.locator("#barra-salvar:visible").count(),
                  "e arrastar nao acendeu a barra do Salvar — nada foi escolhido")
            pag.reload()
            pag.wait_for_timeout(1500)

            print("\n18. TODA PORTA QUE ESCREVE RECUSA EM ENSAIO")
            # ACHADO EM 07/09/2026, NUMA VARREDURA DE INTERACAO COM O ENSAIO
            # LIGADO: um clique em "Usar este icone" gravou
            # `thunderbird:thunderbird:sky:alias` no `apps-arcticons.map` do
            # REPOSITORIO. O `git status` acusou um arquivo que ninguem tinha
            # mandado mudar.
            #
            # E' a terceira vez que este buraco aparece, por tres caminhos
            # diferentes — o "Adicionar gato" em 06/09, o mapa de icones e o mapa
            # de jogos. A licao que virou regra: a guarda mora onde a ESCRITA
            # mora, no servidor, e nao no botao. Protecao so' no cliente vale ate'
            # alguem escrever um botao novo.
            #
            # O teste bate nas rotas DIRETO, sem passar por botao nenhum: e'
            # exatamente o caso que a protecao de cliente nao cobre.
            import json as _json, hashlib as _hl
            vigiados = [os.path.join(RAIZ, "assets", "icones", "apps-arcticons.map"),
                        os.path.join(RAIZ, "assets", "icones", "jogos-fora.map"), CONF]
            def _md5s():
                return {a: (_hl.md5(open(a, "rb").read()).hexdigest()
                            if os.path.exists(a) else None) for a in vigiados}
            antes_portas = _md5s()
            # Um SVG minimo em base64 — o acervo recusa o que nao comeca por "<svg".
            svg64 = "PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciLz4="
            portas = [
                ("/api/app-icone", {"app": "thunderbird", "glifo": "vector", "cor": "pink"}),
                ("/api/jogo-fora", {"appid": "316790", "acao": "esconder", "motivo": "prova"}),
                ("/api/acervo", {"tipo": "gato", "nome": "prova-do-seco.svg", "conteudo": svg64}),
            ]
            recusaram = 0
            for rota, corpo in portas:
                corpo = dict(corpo, seco=True)
                r = pag.evaluate("""async ([rota, corpo]) => {
                  const res = await fetch(rota + location.search, {
                    method: 'POST', headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify(corpo) });
                  return await res.json();
                }""", [rota, corpo])
                if r.get("seco") is True:
                    recusaram += 1
                else:
                    print(f"   XX {rota} nao recusou: {str(r)[:90]}")
            checa(recusaram == len(portas),
                  f"as {len(portas)} rotas que escrevem recusam quando o ensaio esta ligado")
            mexidos = [os.path.basename(a) for a in vigiados if antes_portas[a] != _md5s()[a]]
            checa(not mexidos,
                  "e nenhum arquivo mudou no disco" + (f" — MEXERAM: {mexidos}" if mexidos else ""))

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
            pag.goto(url); pag.wait_for_timeout(1800)
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
            escadas = []
            for aba_ in ("Atualização", "Instalação", "Papel de parede", "Logo do sistema"):
                bt = pag.locator(f'#trilho button[data-grupo="{aba_}"]').first
                if not bt.count():
                    continue
                bt.click(); pag.wait_for_timeout(900)
                for tops in pag.evaluate("""() => {
                  const fil = {};
                  for (const b of document.querySelectorAll('#conteudo .grade > .acao .rodape .btn')) {
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
                pag.evaluate("() => { document.getElementById('principal').scrollTop = 600; }")
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
            pag.goto(url); pag.wait_for_timeout(1200)
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
            pag.goto(url); pag.wait_for_timeout(1800)
            pag.locator('#trilho button[data-grupo="Cor e tela"]').first.click()
            pag.wait_for_timeout(700)
            alvo = pag.locator('#conteudo .cartao[data-chave="FLAVOR"] .amostras button:not([aria-pressed=true])').first
            alvo.click(); pag.wait_for_timeout(500)
            antes_n = pag.evaluate("() => MUDANCAS.size")
            pag.reload(); pag.wait_for_timeout(2200)
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

            # (c) O ENSAIO SE ANUNCIA: ligado, o botao diz o estado e o Salvar
            #     veste o amarelo.
            pag.locator("#seco").click(); pag.wait_for_timeout(300)
            ens = pag.evaluate("""() => ({
              rotulo: document.getElementById('seco').textContent,
              salvar: document.getElementById('botao-salvar').classList.contains('em-ensaio'),
            })""")
            checa("Ensaiando" in ens["rotulo"] and ens["salvar"],
                  f"o ensaio ligado se anuncia no rotulo e no Salvar ({ens['rotulo']!r})")
            pag.locator("#seco").click(); pag.wait_for_timeout(300)

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

    print("\n21. O ARQUIVO DELA FICOU COMO ESTAVA")
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
    sys.exit(main())

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
import subprocess
import sys
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
        pag.locator("#botao-descartar").click()
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
            #   e as paletas moram em "Cor e tema". Os gatos, que vinham na
            #   mesma aba por serem vizinhos no meow.conf.exemplo, foram para a
            #   pagina "O gato" — que e onde alguem os procuraria.
            secao("Cor e tema")
            checa(pag.locator("#conteudo .tira").count() >= 4, "FLAVOR mostra as paletas")
            checa(pag.locator("#conteudo .cores-grade button, #conteudo .amostras button").count() > 8,
                  "ACCENT mostra as cores da paleta")
            # O MESMO MOTIVO DA GRADE DE ICONES LOGO ABAIXO, e que aqui faltava:
            # os gatos chegam por `/previa`, uma requisicao por desenho. Medir no
            # instante do clique reprovou a pagina numa das rodadas de 02/09/2026
            # com os gatos inteiros no lugar — era a rede, nao o cartao.
            secao("O gato")
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
                # As previas que substituem o controle ja foram medidas no clique.
                if k["previa"] in ("", "flavor", "cor", "gato", "cursor"):
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
            secao("Instalar e conferir")
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
            pag.locator("#botao-descartar").click()
            pag.wait_for_timeout(500)
            checa(not pag.locator("#barra-salvar").is_visible(), "Descartar limpa a barra")
            checa(valor_de("LOG_NIVEL") == log_nivel_inicial, "e o disco nunca foi tocado")

            print("\n   ... e o Salvar em modo seco nao escreve")
            md5_antes_seco = md5_conf()
            pag.locator("#seco").check()
            # O cartao esta' na pagina em que o teste acabou de entrar; a busca
            # o traz de volta sem depender de qual pagina e'.
            pag.fill("#busca", "LOG_NIVEL")
            pag.wait_for_timeout(400)
            pag.locator("#conteudo .cartao button", has_text=re.compile(f"^{alvo}$")).first.click()
            pag.wait_for_timeout(400)
            pag.locator("#botao-salvar").click()
            pag.wait_for_timeout(2500)
            checa(md5_conf() == md5_antes_seco, "Salvar em modo seco: o meow.conf nao mudou")
            pag.locator("#seco").uncheck()

            print("\n10. UMA ACAO, COM SAIDA AO VIVO")
            # `status` mudou duas vezes em 06/09/2026: de "Estado da maquina" no
            # "Ciclo de vida" para "O que esta' no ar agora" em "Ver o estado",
            # e dai para "Instalar e conferir" — pedido dela: *"unificar o
            # Instalar e Conferir com o Ver o Estado"*. Conferir a maquina e ver
            # o que esta' no ar sao a mesma pergunta feita de dois jeitos.
            secao("Instalar e conferir")
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
            pag.locator("#seco").check()
            secao("Instalar e conferir")
            secao("Terminal")
            pag.fill("#busca", "wallpaper")
            pag.wait_for_timeout(300)
            pag.fill("#busca", "")
            pag.wait_for_timeout(300)
            checa(pag.locator("#seco").is_checked(),
                  "ligado o Modo seco, ele continua ligado depois de duas abas e uma busca")

            print("\n12. O MODO SECO NAO ESCREVE")
            # A ABA E DITA AQUI, E NAO HERDADA DO PASSO ANTERIOR.
            #   Este bloco procurava o cartao "Conferir" na aba que sobrou da
            #   verificacao anterior — e quando o passo 10 entrou no meio, com
            #   duas trocas de aba de proposito, o cartao deixou de estar na
            #   tela e o teste morreu num timeout de 30 s. Um passo que depende
            #   de onde o passo anterior parou nao pode ser reordenado; este
            #   agora diz onde quer estar.
            secao("Instalar e conferir")
            # A acao anterior precisa TERMINAR: o servidor recusa dois trabalhos
            # ao mesmo tempo (409), e recusar e o comportamento certo dele.
            for _ in range(20):
                pag.wait_for_timeout(500)
                if not pag.locator(".gaveta .rodando, .gaveta [data-rodando]").count():
                    break
            pag.wait_for_timeout(1500)
            md5_antes = md5_conf()
            pag.locator(".seco input[type=checkbox]").check()
            pag.wait_for_timeout(300)
            # "Conferir a maquina" e' o `doctor`, e o `has_text` casa por
            # substring: "Conferir" sozinho pegaria tambem "Conferir e consertar
            # todo dia" se um dia essa acao existir. O rotulo inteiro nao tem
            # esse risco.
            secao("Instalar e conferir")
            pag.locator("#conteudo .acao, #conteudo .cartao",
                        has_text="Conferir a máquina").locator("button").first.click()
            pag.wait_for_timeout(6000)
            checa(md5_conf() == md5_antes, "com o modo seco ligado, o meow.conf nao mudou")
            pag.locator(".seco input[type=checkbox]").uncheck()

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

            print("\n17. O CONSOLE FICOU LIMPO?")
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

    print("\n18. O ARQUIVO DELA FICOU COMO ESTAVA")
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

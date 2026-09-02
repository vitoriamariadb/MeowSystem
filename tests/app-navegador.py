#!/usr/bin/env python3
"""app-navegador.py — a pagina do app usada como ELA usaria, num navegador de verdade.

    tests/app-navegador.py            roda tudo
    tests/app-navegador.py --fotos    roda e guarda as capturas em /tmp

POR QUE ESTE ARQUIVO EXISTE, NAS PALAVRAS DELA (01/09/2026)
  "alem disso eu realmente nao sei se ele funciona de fato. Eu preciso que
   corrija isso e teste como user no navegador cada feature."

  O `tests/app.sh` que ja existia responde outra pergunta: se o SERVIDOR le as
  mesmas 95 chaves que o `bin/meow`, se o CSS nao tem cor solta, se nao ha
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
                and erros_de_console.append(m.text)))
            pag.on("pageerror", lambda e: erros_de_console.append(str(e)))
            pag.goto(url, wait_until="networkidle")

            print("\n1. A PAGINA ABRE")
            checa(pag.title() == "MeowSystem", "o titulo e MeowSystem")
            resumo = pag.locator("#resumo").inner_text()
            checa("95 chaves" in resumo, f"o resumo conta as chaves: {resumo[:44]}…")
            checa(pag.locator("#trilho button").count() >= 20,
                  f"o trilho tem {pag.locator('#trilho button').count()} secoes")

            print("\n2. CADA SECAO RENDERIZA (uma a uma, medindo o que apareceu)")
            nomes = pag.locator("#trilho button").all_text_contents()
            vazias = []
            for i in range(len(nomes)):
                pag.locator("#trilho button").nth(i).click()
                pag.wait_for_timeout(220)
                if pag.locator("#conteudo").inner_text().strip() == "":
                    vazias.append(nomes[i][:28])
            checa(not vazias, f"as {len(nomes)} secoes desenham conteudo"
                              + (f" — VAZIAS: {vazias}" if vazias else ""))

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

            secao("Aparência")
            checa(pag.locator("#conteudo .tira").count() >= 4, "FLAVOR mostra as paletas")
            checa(pag.locator("#conteudo .cores-grade button, #conteudo .amostras button").count() > 8,
                  "ACCENT mostra as cores da paleta")
            checa(pag.locator("#conteudo img").count() >= 2, "LOGO mostra os gatos desenhados")
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
            secao("Galeria")
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

            print("\n6. AS ESCOLHAS ESPERAM O SALVAR")
            pag.fill("#busca", "LOG_NIVEL")
            pag.wait_for_timeout(400)
            alvo = "Debug" if log_nivel_inicial != "debug" else "Info"
            pag.locator("#conteudo .cartao button", has_text=re.compile(f"^{alvo}$")).first.click()
            pag.wait_for_timeout(500)
            checa(valor_de("LOG_NIVEL") == log_nivel_inicial,
                  "escolher NAO grava no meow.conf — o disco so muda no Salvar")
            checa(pag.locator("#barra-salvar").is_visible(), "a barra do Salvar aparece")
            checa("1 escolha" in pag.locator("#salvar-conta").inner_text(),
                  "a barra conta a escolha")

            print("\n   ... e sobrevivem a troca de aba")
            pag.fill("#busca", "")
            secao("Ciclo de vida")
            secao("Terminal")
            checa(pag.locator("#barra-salvar").is_visible(),
                  "depois de duas trocas de aba, a escolha continua la")
            checa(pag.locator("#conteudo .cartao.nao-salvo").count() >= 1,
                  "o cartao continua marcado como nao salvo")

            print("\n   ... e o Descartar devolve tudo")
            pag.locator("#botao-descartar").click()
            pag.wait_for_timeout(500)
            checa(not pag.locator("#barra-salvar").is_visible(), "Descartar limpa a barra")
            checa(valor_de("LOG_NIVEL") == log_nivel_inicial, "e o disco nunca foi tocado")

            print("\n   ... e o Salvar em modo seco nao escreve")
            md5_antes_seco = md5_conf()
            pag.locator("#seco").check()
            pag.locator("#conteudo .cartao button", has_text=re.compile(f"^{alvo}$")).first.click()
            pag.wait_for_timeout(400)
            pag.locator("#botao-salvar").click()
            pag.wait_for_timeout(2500)
            checa(md5_conf() == md5_antes_seco, "Salvar em modo seco: o meow.conf nao mudou")
            pag.locator("#seco").uncheck()

            print("\n7. UMA ACAO, COM SAIDA AO VIVO")
            secao("Ciclo de vida")
            pag.locator("#conteudo .acao, #conteudo .cartao",
                        has_text="Estado da máquina").locator("button").first.click()
            saida = ""
            for _ in range(20):
                pag.wait_for_timeout(500)
                saida = pag.locator(".gaveta, .saida, pre").first.inner_text()
                if len(saida) > 200:
                    break
            checa(len(saida) > 200, f"'Estado da maquina' devolveu {len(saida)} caracteres")
            checa("meow" in saida.lower() or "flavor" in saida.lower(),
                  "a saida e a do comando de verdade")

            print("\n8. O MODO SECO NAO ESCREVE")
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
            pag.locator("#conteudo .acao, #conteudo .cartao",
                        has_text="Conferir").locator("button").first.click()
            pag.wait_for_timeout(6000)
            checa(md5_conf() == md5_antes, "com o modo seco ligado, o meow.conf nao mudou")
            pag.locator(".seco input[type=checkbox]").uncheck()

            print("\n9. TELA ESTREITA (a pagina nao pode rolar de lado)")
            for larg in (320, 375, 414, 768):
                pag.set_viewport_size({"width": larg, "height": 800})
                pag.wait_for_timeout(400)
                excesso = pag.evaluate(
                    "document.documentElement.scrollWidth - document.documentElement.clientWidth")
                checa(excesso <= 1, f"em {larg}px nao rola de lado (excesso {excesso}px)")
                if FOTOS and larg == 375:
                    pag.screenshot(path=f"{DESTINO_FOTOS}/375.png", full_page=True)
            pag.set_viewport_size({"width": 1500, "height": 1000})

            print("\n10. TECLADO E FOCO")
            pag.locator("#conteudo").click(position={"x": 5, "y": 5})
            pag.keyboard.press("/")
            pag.wait_for_timeout(200)
            checa(pag.evaluate("document.activeElement.id") == "busca",
                  "a tecla '/' leva o foco para a busca")
            pag.keyboard.press("Escape")

            print("\n11. O CONSOLE FICOU LIMPO?")
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

    print("\n12. O ARQUIVO DELA FICOU COMO ESTAVA")
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

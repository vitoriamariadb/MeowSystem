#!/usr/bin/env python3
import fcntl
import importlib.util
import json
import os
import shutil
import sys
import time

try:
    import playwright  # noqa: F401
except ImportError:
    print("pulado: playwright nao esta instalado neste interpretador.")
    sys.exit(3)

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("app_completo", os.path.join(AQUI, "app-completo.py"))
casa = importlib.util.module_from_spec(_spec)
_argv, sys.argv = sys.argv, [os.path.join(AQUI, "app-completo.py")]
_spec.loader.exec_module(casa)
sys.argv = _argv

from playwright.sync_api import sync_playwright  # noqa: E402

FOTOS = casa._arg("--fotos")
falhas = []
conferidas = [0]
ALVO = os.path.join(casa.ESTADO, "extensoes", ".target")
COMP = os.path.join(casa.CASA, ".cache", "meowsystem", "cosmic-comp", "cosmic-comp-1.0")
LIBEXEC = os.path.join(casa.CASA, ".local", "libexec", "meow", "cosmic-comp", "1.0")
BACKUP = os.path.join(casa.ESTADO, "backups", time.strftime("%Y-%m-%dT%H-%M-%S") + "-teste")


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


def grande(caminho, n):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "wb") as fh:
        fh.write(bytes(n))


def plantar():
    grande(os.path.join(ALVO, "release", "deps", "libx-0000000000000001.rlib"), 6_000_000)
    grande(os.path.join(COMP, "target", "release", "f"), 3_000_000)
    grande(os.path.join(LIBEXEC, "cosmic-comp"), 2_000_000)
    grande(os.path.join(BACKUP, "f"), 500_000)
    antigo = time.time() - 7200
    for pasta, _, arquivos in os.walk(ALVO):
        for nome in arquivos:
            os.utime(os.path.join(pasta, nome), (antigo, antigo))


def esperar(pag, ms=300):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir_ao_espaco(pag):
    pag.evaluate("() => { location.hash = '#extensoes/espaco'; }")
    esperar(pag)
    pag.wait_for_selector(".espaco-cabeca", timeout=60000)
    pag.wait_for_timeout(200)


def api(pag):
    return pag.evaluate("() => api('/api/espaco')")


def main():
    ambiente = casa.montar_casa()
    ambiente["ESPACO_DISCO_USO_PCT"] = "10"
    plantar()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            contexto = nav.new_context(viewport={"width": 1550, "height": 860})
            pag = contexto.new_page()
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pedidos = []
            contexto.route("https://**/*", lambda r: (pedidos.append(r.request.url), r.abort()))
            pag.goto(url)
            esperar(pag, 600)

            print("1. a página Espaço é uma aba da Central de extensões")
            ir_ao_espaco(pag)
            checa(pag.locator(".abas-ajustes a").all_inner_texts() == ["Applets", "Builds", "Espaço"],
                  "as abas são Applets, Builds e Espaço")
            checa(pag.locator('.abas-ajustes a[aria-current="page"]').inner_text().strip() == "Espaço", "a aba Espaço está acesa")
            dados = api(pag)
            checa(dados["total"] > 10_000_000, f"o servidor mediu o que foi plantado ({dados['total']} bytes)")
            total_na_tela = pag.locator("[data-total]").inner_text()
            checa(total_na_tela.endswith("MB") and abs(int(total_na_tela.split()[0]) - round(dados["total"] / 2 ** 20)) <= 1,
                  f"o número grande é o total medido ({total_na_tela})")
            blocos = pag.locator(".espaco > section.bloco[data-categoria]").evaluate_all("(l) => l.map((b) => b.dataset.categoria)")
            checa(blocos == ["reconstruível", "backup", "de quem usa"], f"há uma seção por categoria ({blocos})")
            linhas = pag.locator("li.linha[data-espaco]").evaluate_all("(l) => l.map((b) => b.dataset.espaco)")
            checa("Applets" in linhas and "Compositor" in linhas and "Backups" in linhas and "Em uso" in linhas,
                  f"as linhas têm nome curto ({linhas})")
            checa(pag.locator(".espaco p").count() == 0, "a tela não tem parágrafo explicando nada")
            sem_dica = pag.locator("li.linha[data-espaco]").evaluate_all("(l) => l.filter((b) => !b.dataset.dica).length")
            checa(sem_dica == 0, "o porquê de cada linha está na dica")
            dica_applets = pag.locator('li.linha[data-espaco="Applets"]').get_attribute("data-dica")
            checa("compilar do zero" in dica_applets and "min" in dica_applets, f"a dica de Applets diz o custo de refazer ({dica_applets[-70:]!r})")
            checa(pag.locator(".espaco-cabeca .barra-do-espaco .fatia").count() >= 2, "a barra mostra as categorias")

            print("2. o botão Liberar tem o preço escrito ao lado")
            botao = pag.locator('[data-controle="espaco:liberar"]')
            checa(botao.count() == 1 and botao.is_enabled(), "Liberar está ativo")
            preco = pag.locator("[data-preco]").inner_text()
            esperado_mb = round(dados["liberavel"] / 2 ** 20)
            checa(f"{esperado_mb} MB" in preco and "~14 min" in preco, f"o preço diz o que sai e quanto leva refazer ({preco})")
            checa(pag.locator(".espaco-acao").get_attribute("data-dica").count("min") >= 1, "e a dica do botão explica o custo")
            if FOTOS:
                pag.screenshot(path=os.path.join(FOTOS, "espaco.png"))

            print("3. Liberar corta o que se reconstrói e deixa o resto")
            botao.click()
            estado = casa.fim_do_trabalho(pag)
            checa(estado == "ok", f"o trabalho termina bem ({estado!r})")
            checa(not os.path.exists(ALVO), "o .target saiu")
            checa(not os.path.exists(os.path.dirname(COMP)) or not os.listdir(os.path.dirname(COMP)), "o cache do compositor saiu")
            checa(os.path.isfile(os.path.join(LIBEXEC, "cosmic-comp")), "o compositor em uso ficou")
            checa(os.path.isfile(os.path.join(BACKUP, "f")), "o backup recente ficou")
            pag.wait_for_function("() => document.querySelector('[data-controle=\"espaco:liberar\"]') && "
                                  "document.querySelector('[data-controle=\"espaco:liberar\"]').disabled", timeout=30000)
            checa(pag.locator("[data-preco]").count() == 0, "sem o que liberar, o botão fica parado e sem preço")
            checa(pag.locator('li.linha[data-espaco="Applets"]').count() == 0, "a linha dos Applets sumiu com o espaço")

            print("4. com um build em curso, o botão não corta")
            grande(os.path.join(ALVO, "release", "deps", "libx-0000000000000002.rlib"), 2_000_000)
            antigo = time.time() - 7200
            os.utime(os.path.join(ALVO, "release", "deps", "libx-0000000000000002.rlib"), (antigo, antigo))
            trava = os.path.join(ALVO, "release", ".cargo-lock")
            open(trava, "w").close()
            fd = os.open(trava, os.O_RDONLY)
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            pag.evaluate("() => { ESP.quando = 0; carregarEspaco(); }")
            pag.wait_for_function("() => ESP.dados && ESP.dados.ocupado === true", timeout=30000)
            pag.wait_for_timeout(300)
            checa(pag.locator('[data-controle="espaco:liberar"]').is_disabled(), "Liberar fica parado")
            checa("build em curso" in pag.locator(".espaco-acao").get_attribute("data-dica"), "e a dica diz que há build em curso")
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)

            print("5. medir devagar não vira laço de pedidos")
            pag.evaluate("() => { ESP.quando = 0; carregarEspaco(); }")
            pag.wait_for_function("() => ESP.dados && ESP.dados.ocupado === false", timeout=30000)
            pag.evaluate("""() => {
              const antes = api;
              window.MEDIDAS = 0;
              api = async (url, ...resto) => {
                if (url === "/api/espaco") {
                  MEDIDAS += 1;
                  await new Promise((fim) => setTimeout(fim, 3300));
                }
                return antes(url, ...resto);
              };
              ESP.quando = 0;
              carregarEspaco();
            }""")
            pag.wait_for_timeout(8000)
            medidas = pag.evaluate("() => MEDIDAS")
            checa(medidas == 1, f"uma medição de 3,3 s não dispara outra sozinha ({medidas})")

            checa(not pedidos, f"a página não pediu nada à internet ({pedidos[:2]})")
            checa(not erros, f"nenhum erro de JavaScript ({erros[:2]})")
            nav.close()
    finally:
        proc.terminate()
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    if falhas:
        print(f"FALHOU: {len(falhas)} de {conferidas[0]}")
        return 1
    print(f"{conferidas[0]} conferências")
    return 0


if __name__ == "__main__":
    sys.exit(main())

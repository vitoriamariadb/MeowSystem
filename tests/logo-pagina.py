#!/usr/bin/env python3
import importlib.util
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

CABECALHO_JS = """
async () => {
  const img = document.querySelector('#topo .marca img');
  const aba = document.querySelector('link[rel=icon]');
  const ler = async (u) => (await (await fetch(u)).text()).match(/aria-label="([^"]*)"/)?.[1] || '';
  return { img: await ler(img.src), aba: await ler(aba.href), carregou: img.complete && img.naturalWidth > 0,
           largura: img.naturalWidth };
}
"""


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


def eventual(fn, seg=20):
    fim = time.time() + seg
    while time.time() < fim:
        try:
            if fn():
                return True
        except Exception:
            pass
        time.sleep(0.3)
    return False


def esperar(pag, ms=400):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            contexto = nav.new_context(viewport={"width": 1920, "height": 1080})
            pag = contexto.new_page()
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pedidos = []
            contexto.route("https://**/*", lambda r: (pedidos.append(r.request.url), r.abort()))
            pag.goto(url)
            esperar(pag, 800)

            print("1. a grade de logos mora na página do mascote")
            pag.evaluate("() => { location.hash = '#ajustes/mascote'; }")
            esperar(pag)
            botoes = pag.locator('[data-controle^="chave:LOGO_PROGRAMA="]')
            nomes = botoes.evaluate_all("(l) => l.map((b) => b.dataset.controle.split('=')[1])")
            checa(nomes[:1] == [""] and {"meowsystem", "dracula"} <= set(nomes),
                  f"vazio primeiro e um botão por pack com logo ({nomes})")
            checa(pag.locator('[data-controle="chave:LOGO_PROGRAMA="]').get_attribute("aria-pressed") == "true",
                  "de fábrica, o do pack no ar está marcado")
            pag.wait_for_timeout(500)
            carregadas = botoes.evaluate_all("(l) => l.map((b) => { const i = b.querySelector('img');"
                                             " return !!i && i.complete && i.naturalWidth > 0; })")
            checa(all(carregadas), f"cada botão mostra a logo ({carregadas})")
            antes = pag.evaluate(CABECALHO_JS)
            checa(antes["img"] == "MeowSystem" and antes["carregou"], f"o cabeçalho começa com a marca do pack no ar ({antes})")
            if FOTOS:
                pag.locator('[data-controle="chave:LOGO_PROGRAMA=dracula"]').scroll_into_view_if_needed()
                pag.screenshot(path=os.path.join(FOTOS, "p138-logo-1920.png"))

            print("2. escolher a do dracula troca o cabeçalho e o ícone da aba")
            pag.locator('[data-controle="chave:LOGO_PROGRAMA=dracula"]').click()
            checa(eventual(lambda: casa.valor_de("LOGO_PROGRAMA") == "dracula"),
                  f"grava LOGO_PROGRAMA=dracula ({casa.valor_de('LOGO_PROGRAMA')!r})")
            checa(eventual(lambda: pag.evaluate(CABECALHO_JS)["img"] == "Dracula"),
                  f"o cabeçalho mostra a logo do dracula ({pag.evaluate(CABECALHO_JS)})")
            depois = pag.evaluate(CABECALHO_JS)
            checa(depois["aba"] == "Dracula" and depois["carregou"], f"e o ícone da aba também ({depois})")
            checa(eventual(lambda: pag.evaluate(CABECALHO_JS)["largura"] == 128),
                  f"e a imagem na tela é a nova, não a de antes da gravação ({pag.evaluate(CABECALHO_JS)})")
            checa(pag.locator('[data-controle="chave:LOGO_PROGRAMA=dracula"]').get_attribute("aria-pressed") == "true",
                  "o botão escolhido fica marcado")
            if FOTOS:
                pag.wait_for_function("() => { const i = document.querySelector('#topo .marca img');"
                                      " return i.complete && i.naturalWidth > 0; }")
                pag.wait_for_timeout(300)
                pag.locator('[data-controle="chave:LOGO_PROGRAMA=dracula"]').scroll_into_view_if_needed()
                pag.screenshot(path=os.path.join(FOTOS, "p138-logo-escolhida-1920.png"))
                pag.locator("#topo").screenshot(path=os.path.join(FOTOS, "p138-cabecalho.png"))
                pag.set_viewport_size({"width": 800, "height": 1000})
                esperar(pag)
                pag.locator('[data-controle="chave:LOGO_PROGRAMA=dracula"]').scroll_into_view_if_needed()
                pag.screenshot(path=os.path.join(FOTOS, "p138-logo-800.png"))
                pag.set_viewport_size({"width": 1920, "height": 1080})
                esperar(pag)

            print("3. voltar ao do pack no ar")
            pag.locator('[data-controle="chave:LOGO_PROGRAMA="]').click()
            checa(eventual(lambda: (casa.valor_de("LOGO_PROGRAMA") or "") == ""),
                  f"grava LOGO_PROGRAMA vazio ({casa.valor_de('LOGO_PROGRAMA')!r})")
            checa(eventual(lambda: pag.evaluate(CABECALHO_JS)["img"] == "MeowSystem"),
                  f"o cabeçalho volta à marca do pack no ar ({pag.evaluate(CABECALHO_JS)})")
            checa(eventual(lambda: pag.evaluate(CABECALHO_JS)["largura"] == antes["largura"]),
                  f"e a imagem na tela volta a ser a de antes ({pag.evaluate(CABECALHO_JS)})")

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

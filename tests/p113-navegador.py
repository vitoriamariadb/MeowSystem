#!/usr/bin/env python3
import importlib.util
import os
import shutil
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("app_completo", os.path.join(AQUI, "app-completo.py"))
casa = importlib.util.module_from_spec(_spec)
_argv, sys.argv = sys.argv, [os.path.join(AQUI, "app-completo.py")]
_spec.loader.exec_module(casa)
sys.argv = _argv

from playwright.sync_api import sync_playwright  # noqa: E402

FOTOS = casa._arg("--fotos")
FALHAS = []


def prova(ok, texto):
    print(("ok: " if ok else "FALHOU: ") + texto)
    if not ok:
        FALHAS.append(texto)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(600)


def foto(pag, nome):
    if FOTOS:
        os.makedirs(FOTOS, exist_ok=True)
        pag.screenshot(path=os.path.join(FOTOS, nome), full_page=True)


def sons(pag, url):
    ir(pag, "criar/sons")
    pag.wait_for_selector(".sons li[data-som]", timeout=20000)
    foto(pag, "sons.png")
    nomes = pag.eval_on_selector_all(".sons li[data-som] .som-nome b", "(xs) => xs.map((x) => x.textContent)")
    quando = pag.eval_on_selector_all(".sons li[data-som] .som-nome small", "(xs) => xs.map((x) => x.textContent)")
    prova(len(nomes) >= 25 and "Na tomada" in nomes and "Bateria fraca" in nomes,
          "a página Sons lista os sons do sistema por nome legível (%d)" % len(nomes))
    prova(all(quando) and "O carregador entra" in quando, "cada som diz quando toca")
    prova(pag.locator("h2", has_text="Toca no COSMIC").count() == 1
          and pag.locator("h2", has_text="Toca nos apps").count() == 1, "dois blocos: COSMIC e apps")
    prova(pag.locator(".sons li[data-som] [data-origem]").count() == len(nomes), "cada som mostra de onde vem")
    prova(pag.locator(".sons li[data-som='power-plug'] [data-controle='som:trocar']").count() == 1, "cada som tem o Trocar")
    pag.evaluate("() => { ESQUEMA.ponte = false; render(); }")
    pag.wait_for_timeout(300)
    prova(pag.locator("[data-controle='som:ponte']").count() == 1
          and pag.locator(".sons li.sem-ponte").count() == 7, "sem ponte: aviso com «Consertar a ponte» e os 7 sons de carregador e bateria marcados")
    foto(pag, "sons-sem-ponte.png")
    pag.evaluate("() => { ESQUEMA.ponte = true; render(); }")

    import time
    tempo = time.time()
    pag.fill("[data-chave='SOM_FUNDAMENTAL'] input[type=range], [data-linha='SOM_FUNDAMENTAL'] input", "1000")
    pag.wait_for_timeout(300)
    q = pag.evaluate("() => urlDoSino()")
    corpo_previa = bytes(pag.evaluate("async (q) => Array.from(new Uint8Array(await (await fetch(q)).arrayBuffer()))", q))
    prova(corpo_previa[:4] == b"RIFF", "a prévia do sino vem do gerador do som.sh (WAV)")
    pag.click("[data-controle='acao:som_aplicar']")
    destino = os.path.join(casa.CASA, ".local", "share", "sounds", "freedesktop", "stereo", "audio-volume-change.oga")
    for _ in range(60):
        if os.path.isfile(destino) and os.path.getmtime(destino) > tempo:
            break
        pag.wait_for_timeout(500)
    gravado = open(destino, "rb").read() if os.path.isfile(destino) else b""
    prova(gravado == corpo_previa, "o «Regravar» grava os mesmos bytes que a prévia tocou (%d bytes)" % len(gravado))
    pag.reload()
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA", timeout=60000)
    ir(pag, "criar/sons")
    q2 = pag.evaluate("() => urlDoSino()")
    depois = bytes(pag.evaluate("async (q) => Array.from(new Uint8Array(await (await fetch(q)).arrayBuffer()))", q2))
    prova(depois == gravado and "SOM_FUNDAMENTAL=1000" in q2, "depois de recarregar, o controle, a prévia e o instalado seguem iguais")
    return q, corpo_previa


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1829, "height": 1029})
            pag.goto(url)
            sons(pag, url)
            nav.close()
    finally:
        proc.terminate()
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    return 1 if FALHAS else 0


if __name__ == "__main__":
    sys.exit(main())

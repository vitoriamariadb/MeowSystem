#!/usr/bin/env python3
import importlib.util
import os
import shutil
import sys

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


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


GALERIA = """
() => ({
  abas: [...document.querySelectorAll('[data-controle^="galeria:"]')].filter((b) => b.dataset.controle !== 'galeria:mais').map((b) => b.textContent.trim()),
  figuras: document.querySelectorAll('.galeria figure').length,
  levar: document.querySelectorAll('[data-controle="levar:foto"]').length,
  estrela: document.querySelectorAll('.galeria .estrela, [data-controle="papel:wallpaper_favoritar"], [data-controle="papel:wallpaper_desfavoritar"]').length,
  lixos: document.querySelectorAll('.galeria [data-controle="papel:wallpaper_banir"]').length,
})
"""


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    ativos = os.path.join(casa.valor_de("WALLPAPER_BASE").replace("$HOME", casa.CASA), "ativos")
    lista = os.path.join(casa.ESTADO, "papeis-de-parede", "BANIDOS.txt")
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            erros = []
            pag = nav.new_context(viewport={"width": 1550, "height": 900}).new_page()
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pag.goto(url)
            pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                                  " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
            pag.evaluate("() => { location.hash = '#criar/papel'; }")
            pag.wait_for_function("() => document.querySelectorAll('.galeria figure img').length > 0", timeout=60000)
            pag.wait_for_timeout(500)
            g = pag.evaluate(GALERIA)
            checa(g["abas"] == ["No carrossel", "Noite", "Dia"], f"só três abas: {g['abas']}")
            checa(g["levar"] == 0, f"nenhum «Levar para o tema» na galeria ({g['levar']})")
            checa(g["estrela"] == 0, f"nenhuma estrela de favorita ({g['estrela']})")
            checa(g["figuras"] == casa.PAREDES and g["lixos"] == casa.PAREDES, f"um lixo por imagem ({g})")
            if FOTOS:
                os.makedirs(FOTOS, exist_ok=True)
                pag.screenshot(path=os.path.join(FOTOS, "galeria-do-papel.png"), full_page=True)
            alvo = pag.evaluate("() => document.querySelector('.galeria figure').dataset.papel")
            pag.locator('.galeria figure').first.locator('[data-controle="papel:wallpaper_banir"]').click()
            pag.wait_for_selector("#pergunta[open]", timeout=10000)
            titulo = pag.evaluate("() => document.getElementById('pergunta-titulo').textContent")
            checa(titulo == f"Apagar {alvo}?", f"o lixo pergunta uma vez: {titulo!r}")
            if FOTOS:
                pag.screenshot(path=os.path.join(FOTOS, "galeria-do-papel-pergunta.png"))
            pag.click('[data-controle="pergunta:nao"]')
            pag.wait_for_timeout(600)
            checa(os.path.isfile(os.path.join(ativos, alvo)), "o «não» deixa a imagem no disco")
            pag.locator('.galeria figure').first.locator('[data-controle="papel:wallpaper_banir"]').click()
            pag.wait_for_selector("#pergunta[open]", timeout=10000)
            pag.click('[data-controle="pergunta:sim"]')
            pag.wait_for_selector("#resultado[open]", timeout=30000)
            pag.wait_for_function("() => { const e = document.getElementById('resultado-estado').dataset.estado;"
                                  " return e && e !== 'correndo'; }", timeout=120000)
            pag.wait_for_timeout(500)
            saida = pag.evaluate("() => document.getElementById('saida').textContent")
            try:
                with open(lista, encoding="utf-8") as fh:
                    anotada = alvo in [l.strip() for l in fh]
            except OSError:
                anotada = False
                print(saida[-800:])
            base = os.path.dirname(ativos)
            checa(not os.path.exists(os.path.join(ativos, alvo)) and anotada and not os.path.isdir(os.path.join(base, "banidos")),
                  f"o «Apagar» tira {alvo} do disco, sem banidos/, e o nome vai para o BANIDOS.txt")
            sem_previa = []
            pag.on("response", lambda r: sem_previa.append(r.url) if r.status == 404 and "/previa" in r.url else None)
            outra = os.path.join(casa.BRINQUEDO, "sem-papel")
            pag.evaluate("(base) => gravarAgora({ WALLPAPER_BASE: base })", outra)
            pag.wait_for_function("() => !EM_VOO", timeout=60000)
            for _vez in range(3):
                pag.evaluate("() => render()")
                pag.wait_for_timeout(400)
            checa(pag.evaluate("() => document.querySelectorAll('.galeria figure').length") == 0,
                  "mudar a pasta dos papéis refaz a galeria, e a pasta vazia não deixa imagem velha")
            velhas = pag.evaluate("""async () => { const l = previasDe('parede', 'ativos');
                const urls = ((l && l.itens) || []).map((i) => i.url);
                return Promise.all(urls.map((u) => fetch(u).then((r) => r.status))); }""")
            checa(404 not in velhas and not sem_previa,
                  f"nenhuma prévia da pasta antiga fica pedindo 404 (lista: {velhas}; respostas: {len(sem_previa)})")
            pag.evaluate("() => desfazerTudo()")
            pag.wait_for_function("(n) => document.querySelectorAll('.galeria figure img').length === n",
                                  arg=casa.PAREDES - 1, timeout=60000)
            pag.wait_for_timeout(600)
            checa(not sem_previa, f"o Desfazer traz a pasta de volta sem 404 ({len(sem_previa)} respostas)")
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
    print(f"ok: {conferidas[0]} conferências da galeria do papel de parede")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
import importlib.util
import os
import shutil
import sys
import urllib.parse

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("app_completo", os.path.join(AQUI, "app-completo.py"))
casa = importlib.util.module_from_spec(_spec)
_argv, sys.argv = sys.argv, [os.path.join(AQUI, "app-completo.py")]
_spec.loader.exec_module(casa)
sys.argv = _argv

from playwright.sync_api import sync_playwright  # noqa: E402

FOTOS = casa._arg("--fotos")
LARGURAS = ((1920, 1080), (1550, 860), (1500, 900), (1280, 800))
falhas = []


def confere(cond, frase):
    print(("ok: " if cond else "FALHOU: ") + frase)
    if not cond:
        falhas.append(frase)


def esperar(pag, ms=600):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    esperar(pag)


def partir_de(pag, pack):
    pag.evaluate("(p) => { const r = rascunho(); const f = (PACKS.find((x) => x.id === p).flavors || [])[0];"
                 " r.base = { pack: p, flavor: f.id }; r.cores = {}; r.pack = ''; guardarRascunho(); render(); }", pack)
    pag.wait_for_timeout(500)


def aba(pag, nome):
    pag.locator(f'[data-controle="icones:aba={nome}"]').click()
    pag.wait_for_function("() => !document.querySelector('[aria-busy=\"true\"]')", timeout=30000)
    pag.wait_for_timeout(500)


def fontes_do_acervo(pag, pasta):
    return pag.evaluate("(p) => [...document.querySelectorAll(`.grade-apps.pastas[data-acervo='${p}'] .app`)]"
                        ".map((a) => ({ nome: a.querySelector('.nome').textContent, src: a.querySelector('img').src }))", pasta)


def decodificado(src):
    if src.startswith("data:"):
        return urllib.parse.unquote(src.split(",", 1)[1])
    return src


def abrir_um_app(pag):
    aba(pag, "apps")
    if pag.locator(".desenho").count():
        pag.locator('[data-controle="desenho:volta"]').click()
        pag.wait_for_timeout(400)
        pag.evaluate("() => { OFICINA.carregou = false; OFICINA.ocupada = false; }")
    botao = pag.locator("button.app[data-app]").first
    app = botao.get_attribute("data-app")
    botao.click()
    pag.wait_for_selector(".desenho .oficina-cartao", timeout=60000)
    pag.wait_for_function("() => !document.querySelector('.desenho-olho .bt[data-estado=\"carregando\"]')", timeout=60000)
    pag.wait_for_timeout(800)
    confere(pag.locator(".grade-apps").count() == 0, "a ficha do ícone abre no lugar da grade")
    return app


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o app/run.sh não imprimiu a URL")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1920, "height": 1080})
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pag.goto(url, wait_until="commit")
            esperar(pag, 800)
            ir(pag, "criar/icones")

            partir_de(pag, "meowsystem")
            aba(pag, "sistema")
            sis = fontes_do_acervo(pag, "sistema")
            nomes = {a["nome"] for a in sis}
            confere({"Documentos", "Downloads"} <= nomes, f"Sistema (MeowSystem): pastas com nome legível ({sorted(nomes)[:6]})")
            pastas_mew = [a for a in sis if a["nome"] == "Documentos"]
            confere(bool(pastas_mew) and pastas_mew[0]["src"].startswith("data:"), "Sistema (MeowSystem): a pasta vem pintada na cor do tema")
            aba(pag, "biblioteca")
            bib_mew = fontes_do_acervo(pag, "biblioteca")
            confere(len(bib_mew) > 0 and all("dracula" not in a["src"] for a in bib_mew), f"Biblioteca (MeowSystem): só o acervo do pack ({len(bib_mew)})")
            confere(pag.locator('[data-controle^="levar:"]').count() == 0, "as abas Sistema e Biblioteca só mostram: sem botão de levar")

            partir_de(pag, "dracula")
            aba(pag, "sistema")
            sis_dra = fontes_do_acervo(pag, "sistema")
            confere(len(sis_dra) > 0 and all("%2Fdracula%2F" in a["src"] or "/dracula/" in decodificado(a["src"]) for a in sis_dra),
                    f"Sistema (Dracula): só as pastas do pack Dracula ({len(sis_dra)})")
            aba(pag, "biblioteca")
            bib_dra = fontes_do_acervo(pag, "biblioteca")
            confere(len(bib_dra) > 0 and all("dracula" in decodificado(a["src"]) for a in bib_dra),
                    f"Biblioteca (Dracula): só o acervo do pack Dracula ({len(bib_dra)})")
            confere({a["src"] for a in bib_dra}.isdisjoint({a["src"] for a in bib_mew}), "a Biblioteca do Dracula não mistura a do MeowSystem")

            partir_de(pag, "dracula")
            app = abrir_um_app(pag)
            confere(pag.locator('.desenho [data-gerador="circle"] .oficina-cartao').count() >= 3, "Dracula: o gerador mostra cartões de disco e glifo")
            srcs = pag.evaluate("() => [...document.querySelectorAll('.desenho [data-gerador=\"circle\"] .oficina-cartao img')].map((i) => i.src)")
            svgs = [decodificado(s) for s in srcs]
            confere(bool(svgs) and all("<circle" in s or "solto" in s or "<path" in s for s in svgs) and all("stroke" not in s for s in svgs),
                    "Dracula: os cartões são círculo com glifo cheio, sem traço")
            confere(any("<circle" in s for s in svgs), "Dracula: há cartão com disco (circle)")
            confere(pag.locator('.desenho .so-meowsystem [data-controle="oficina:detalhe"]').count() == 0, "Dracula: o ajuste do traço não aparece")
            confere(pag.locator("#r-glifo").count() == 1, "Dracula: o ajuste do tamanho do glifo aparece")

            if FOTOS:
                os.makedirs(FOTOS, exist_ok=True)
                maq = nav.new_page()
                for larg, alt in LARGURAS:
                    pag.set_viewport_size({"width": larg, "height": alt})
                    pag.wait_for_timeout(400)
                    pag.screenshot(path=os.path.join(FOTOS, f"painel-dracula-{larg}x{alt}.png"))
                    maq.set_viewport_size({"width": larg, "height": alt})
                    maq.goto("file://" + os.path.join(casa.RAIZ, "docs", "sprints", "2026-10-26-qa-final", "maquete", "b",
                                                      "personalizar.html") + "?sabor=dracula&sub=apps&app=spotify#icones")
                    maq.wait_for_timeout(500)
                    maq.screenshot(path=os.path.join(FOTOS, f"maquete-dracula-{larg}x{alt}.png"))
                maq.close()

            pag.set_viewport_size({"width": 1920, "height": 1080})
            partir_de(pag, "meowsystem")
            abrir_um_app(pag)
            confere(pag.locator('.desenho [data-gerador="traco"] .oficina-cartao svg').count() >= 2, "MeowSystem: o gerador mostra cartões de traço")
            traco = pag.evaluate("() => [...document.querySelectorAll('.desenho [data-gerador=\"traco\"] .oficina-cartao svg')]"
                                 ".every((s) => s.outerHTML.includes('stroke'))")
            confere(traco, "MeowSystem: os cartões são o traço do Arcticons (stroke)")
            confere(pag.locator('.desenho [data-controle="oficina:detalhe"]').count() == 1, "MeowSystem: o ajuste de detalhe aparece")

            if FOTOS:
                maq = nav.new_page()
                for larg, alt in LARGURAS:
                    pag.set_viewport_size({"width": larg, "height": alt})
                    pag.wait_for_timeout(400)
                    pag.screenshot(path=os.path.join(FOTOS, f"painel-meowsystem-{larg}x{alt}.png"))
                    maq.set_viewport_size({"width": larg, "height": alt})
                    maq.goto("file://" + os.path.join(casa.RAIZ, "docs", "sprints", "2026-10-26-qa-final", "maquete", "b",
                                                      "personalizar.html") + "?sabor=mocha&sub=apps&app=spotify#icones")
                    maq.wait_for_timeout(500)
                    maq.screenshot(path=os.path.join(FOTOS, f"maquete-meowsystem-{larg}x{alt}.png"))
                maq.close()
                pag.set_viewport_size({"width": 1920, "height": 1080})

            partir_de(pag, "dracula")
            app = abrir_um_app(pag)
            pag.locator('[data-controle="oficina:usar"]').click()
            pag.wait_for_selector("#d-salvo:not([hidden])", timeout=60000)
            guardado = pag.evaluate("() => rascunho().pack")
            confere(bool(guardado), f"«Usar» guardou o tema sozinho ({guardado})")
            pasta = os.path.join(casa.CASA, ".local", "share", "meowsystem", "packs", guardado or "?", "icones", "apps")
            arqs = sorted(os.listdir(pasta)) if os.path.isdir(pasta) else []
            confere(f"{app}.svg" in arqs, f"«Usar» gravou o desenho em icones/apps/ do pack ({app}.svg)")
            confere(pag.locator("#d-salvo").is_visible(), "a tela diz «Guardado no pack»")
            pag.locator("#d-desfazer").click()
            pag.wait_for_function("() => document.getElementById('d-salvo').hidden", timeout=30000)
            arqs2 = sorted(os.listdir(pasta)) if os.path.isdir(pasta) else []
            confere(f"{app}.svg" not in arqs2, "«Desfazer» tira o desenho do pack")
            confere(not erros, f"sem erro de script na página ({erros[:1]})")
            nav.close()
    finally:
        proc.terminate()
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    if falhas:
        print(f"FALHOU: {len(falhas)} conferência(s)")
        return 1
    print("ok: ícones por pack: abas, gerador de cada pack e «Usar» dentro do pack")
    return 0


if __name__ == "__main__":
    sys.exit(main())

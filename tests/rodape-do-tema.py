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

MEDIDAS = """
(n) => {
  const base = window.__packs || (window.__packs = PACKS.slice());
  const lista = [];
  for (let i = 0; i < n; i++) lista.push(Object.assign({}, base[i % base.length], { id: base[i % base.length].id + (i < base.length ? '' : '-' + i), no_ar: i === 0 }));
  PACKS = lista;
  render();
  const r = (e) => { const b = e.getBoundingClientRect(); return { top: Math.round(b.top), bottom: Math.round(b.bottom), left: Math.round(b.left), h: Math.round(b.height) }; };
  const q = (s) => document.querySelector(s);
  const cartoes = [...document.querySelectorAll('#conteudo .grade-tema > .pack')].map(r);
  const tres = ['[data-linha="ACCENT"]', '[data-linha="MODO"]', '.criar-meu'].map((s) => q('#conteudo ' + s));
  return { cartoes, tres: tres.map((e) => e && r(e)),
           pais: tres.map((e) => e && e.parentElement.className) };
}
"""


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            erros = []
            for (w, h) in [(1920, 1080), (1550, 900), (1280, 800), (800, 1000)]:
                contexto = nav.new_context(viewport={"width": w, "height": h})
                pag = contexto.new_page()
                pag.on("pageerror", lambda e: erros.append(str(e)))
                pag.goto(url)
                pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                                      " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
                pag.wait_for_timeout(600)
                for n in (1, 2, 5):
                    m = pag.evaluate(MEDIDAS, n)
                    pag.wait_for_timeout(150)
                    tres, cartoes = m["tres"], m["cartoes"]
                    rotulo = f"{w}x{h}, {n} pack(s)"
                    if not checa(all(tres) and len(cartoes) == n, f"{rotulo}: os três e os {n} cartões estão na página ({m})"):
                        continue
                    checa(set(m["pais"]) == {"rodape-tema"}, f"{rotulo}: os três moram na fileira própria ({m['pais']})")
                    fundo = max(c["bottom"] for c in cartoes)
                    checa(min(t["top"] for t in tres) > fundo, f"{rotulo}: a fileira começa abaixo do último cartão ({fundo} < {[t['top'] for t in tres]})")
                    if w > 860:
                        checa(len({t["top"] for t in tres}) == 1, f"{rotulo}: os três no mesmo topo ({[t['top'] for t in tres]})")
                        checa(len({t["h"] for t in tres}) == 1, f"{rotulo}: os três da mesma altura ({[t['h'] for t in tres]})")
                        checa(tres[0]["left"] < tres[1]["left"] < tres[2]["left"], f"{rotulo}: destaque, claro ou escuro, criar, nesta ordem")
                    else:
                        checa(tres[0]["bottom"] <= tres[1]["top"] and tres[1]["bottom"] <= tres[2]["top"]
                              and len({t["left"] for t in tres}) == 1, f"{rotulo}: em tela estreita os três empilham ({tres})")
                    if FOTOS:
                        os.makedirs(FOTOS, exist_ok=True)
                        pag.screenshot(path=os.path.join(FOTOS, f"rodape-{w}x{h}-{n}packs.png"), full_page=True)
                contexto.close()
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
    print(f"ok: {conferidas[0]} conferências do rodapé do Tema")
    return 0


if __name__ == "__main__":
    sys.exit(main())

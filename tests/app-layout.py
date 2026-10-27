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
LARGURAS = [(1920, 1080), (1550, 860), (1280, 800), (1500, 900)]
SECOES = ["painel", "janelas", "papel", "mascote", "dia-e-noite", "terminal", "programas"]
PORTAS = ["tema", "criar", "cuidar"]
falhas = []
conferidas = [0]

TRANSBORDOS = """
() => {
  const ruins = [];
  const raiz = document.documentElement;
  if (raiz.scrollWidth !== innerWidth) ruins.push(["documento", raiz.scrollWidth, innerWidth]);
  const dentro = (el) => {
    for (let p = el.parentElement; p; p = p.parentElement) {
      const s = getComputedStyle(p);
      if (/(auto|scroll|hidden|clip)/.test(s.overflowX) && p !== document.body && p !== raiz) return true;
    }
    return false;
  };
  for (const el of document.querySelectorAll('body *')) {
    if (el.closest('svg') && el.tagName !== 'svg') continue;
    if (el.classList.contains('sr') || el.closest('.sr')) continue;
    const r = el.getBoundingClientRect();
    if (!r.width || !r.height) continue;
    const dlg = el.closest('dialog');
    if (dlg && !dlg.open) continue;
    if (el.scrollWidth > el.clientWidth + 1 && el.clientWidth > 0) {
      const s = getComputedStyle(el);
      if (/(auto|scroll)/.test(s.overflowX)) continue;
      if (s.display === 'inline') continue;
      if (s.textOverflow === 'ellipsis' && s.overflowX === 'hidden') continue;
      if (/^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName)) continue;
      ruins.push(['conteudo', (el.parentElement.className + ' > ' + (el.className || el.tagName)), el.textContent.slice(0, 30), el.scrollWidth, el.clientWidth]);
    }
    const pai = el.parentElement;
    if (pai && pai !== document.body && !dentro(el)) {
      const pr = pai.getBoundingClientRect();
      const sp = getComputedStyle(pai);
      if (pr.width && getComputedStyle(el).position !== 'absolute' && getComputedStyle(el).position !== 'fixed'
          && sp.display !== 'contents' && r.right > pr.right + 2 && !/(auto|scroll)/.test(sp.overflowX)) {
        ruins.push(['filho', el.className || el.tagName, Math.round(r.right - pr.right)]);
      }
    }
  }
  return ruins.slice(0, 8);
}
"""

POSICOES = """
() => {
  const r = (s) => { const e = document.querySelector(s); if (!e || e.hidden) return null; const b = e.getBoundingClientRect(); return { top: b.top, bottom: b.bottom, w: b.width, h: b.height }; };
  return { topo: r('#topo'), abas: r('#abas'), palco: r('.oficina .palco'), previa: r('.oficina .palco .previa') };
}
"""


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


def esperar(pag, ms=500):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    esperar(pag)


def foto(pag, nome):
    if FOTOS:
        os.makedirs(FOTOS, exist_ok=True)
        pag.screenshot(path=os.path.join(FOTOS, nome + ".png"))


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
            for (w, h) in LARGURAS:
                print(f"== {w}x{h}")
                contexto = nav.new_context(viewport={"width": w, "height": h})
                pag = contexto.new_page()
                pag.on("pageerror", lambda e: erros.append(str(e)))
                pag.goto(url)
                esperar(pag, 800)
                rotas = [("ajustes/" + s) for s in SECOES] + PORTAS
                for rota in rotas:
                    ir(pag, rota)
                    nome = rota.replace("/", "-")
                    ruins = pag.evaluate(TRANSBORDOS)
                    checa(not ruins, f"{rota}: nada estoura o pai ({ruins[:3]})")
                    foto(pag, f"{w}x{h}-{nome}-topo")
                    pag.evaluate("() => scrollTo(0, document.documentElement.scrollHeight)")
                    pag.wait_for_timeout(250)
                    pos = pag.evaluate(POSICOES)
                    checa(pos["topo"] and pos["topo"]["top"] == 0, f"{rota}: o cabeçalho fica em 0 depois de rolar")
                    if rota.startswith("ajustes/"):
                        checa(pos["abas"] and pos["abas"]["top"] == 64, f"{rota}: as abas ficam em 64 ({pos['abas']})")
                        if rota != "ajustes/programas":
                            pal = pos["palco"]
                            checa(pal and pal["top"] >= 116 and pal["bottom"] <= h,
                                  f"{rota}: o palco fica inteiro na tela ({pal})")
                        else:
                            checa(pos["palco"] is None, "programas: sem prévia")
                    foto(pag, f"{w}x{h}-{nome}-fim")
                    pag.evaluate("() => scrollTo(0, 0)")
                if w == 1920:
                    ir(pag, "ajustes/painel")
                    larg = pag.evaluate(POSICOES)["previa"]["w"]
                    checa(larg >= 900, f"em 1920 a prévia tem {larg:.0f} px (>= 900)")
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
    print(f"ok: {conferidas[0]} conferências de layout")
    return 0


if __name__ == "__main__":
    sys.exit(main())

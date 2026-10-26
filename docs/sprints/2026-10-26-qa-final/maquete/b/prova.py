import json, os, sys
from playwright.sync_api import sync_playwright

B = os.path.dirname(os.path.abspath(__file__))
CAP = f"{B}/capturas"
os.makedirs(CAP, exist_ok=True)
LARGURAS = [(1920, 1080), (1550, 860), (1500, 900), (1280, 800)]
TELAS = [
    ("personalizar.html", "", "cores", "p-cores"),
    ("personalizar.html", "?sabor=dracula", "cores", "p-cores-dracula"),
    ("personalizar.html", "", "papel", "p-papel"),
    ("personalizar.html", "?estado=vazio", "papel", "p-papel-vazio"),
    ("personalizar.html", "", "icones", "p-icones"),
    ("personalizar.html", "?app=spotify", "icones", "p-oficina-ms"),
    ("personalizar.html", "?sabor=dracula&app=spotify", "icones", "p-oficina-dracula"),
    ("personalizar.html", "?app=spotify&fonte=acervo", "icones", "p-oficina-acervo"),
    ("personalizar.html", "?app=spotify&estado=erro", "icones", "p-oficina-erro"),
    ("personalizar.html", "?estado=carregando", "icones", "p-icones-carregando"),
    ("personalizar.html", "?sub=sistema", "icones", "p-sistema"),
    ("personalizar.html", "?sabor=dracula&sub=biblioteca", "icones", "p-biblioteca-dracula"),
    ("personalizar.html", "", "sons", "p-sons"),
    ("personalizar.html", "?sabor=dracula", "sons", "p-sons-dracula"),
    ("personalizar.html", "?estado=sem-ponte", "sons", "p-sons-sem-ponte"),
    ("personalizar.html", "", "mandar", "p-mandar"),
    ("personalizar.html", "?estado=erro", "mandar", "p-mandar-erro"),
    ("extensoes.html", "", "applets", "e-applets"),
    ("extensoes.html", "?estado=erro", "applets", "e-applets-erro"),
    ("extensoes.html", "?estado=atualizacao", "applets", "e-applets-atualizacao"),
    ("extensoes.html", "?estado=vazio", "applets", "e-applets-vazio"),
    ("extensoes.html", "", "builds", "e-builds"),
    ("extensoes.html", "?estado=carregando", "builds", "e-builds-compilando"),
    ("extensoes.html", "?passo=ficha", "applets", "e-adicionar-ficha"),
    ("extensoes.html", "?passo=erro", "applets", "e-adicionar-erro"),
    ("personalizar.html", "?creditos=1", "cores", "p-creditos"),
]

JS_TRANSBORDA = r"""() => {
  const ruins = [];
  const vis = (el) => { const s = getComputedStyle(el); return s.display !== 'none' && s.visibility !== 'hidden' && el.getClientRects().length; };
  for (const el of document.querySelectorAll('body *')) {
    if (!(el instanceof HTMLElement) || !vis(el)) continue;
    const pai = el.parentElement;
    if (!pai || !(pai instanceof HTMLElement)) continue;
    if (el.closest('.previa')) continue;
    const fechado = el.closest('details:not([open])'); if (fechado && !el.closest('summary')) continue;
    const ps = getComputedStyle(pai);
    if (el.scrollWidth > pai.clientWidth + 1 && pai.clientWidth > 0 && !['auto','scroll'].includes(ps.overflowX)) {
      ruins.push(`${el.tagName.toLowerCase()}.${[...el.classList].join('.')} sw=${el.scrollWidth} pai=${pai.tagName.toLowerCase()}.${[...pai.classList].join('.')} cw=${pai.clientWidth} "${(el.textContent||'').trim().slice(0,30)}"`);
    }
  }
  if (document.documentElement.scrollWidth > innerWidth) ruins.push(`pagina sw=${document.documentElement.scrollWidth} > ${innerWidth}`);
  return ruins;
}"""

JS_FIXOS = r"""() => {
  const r = (s) => { const e = document.querySelector(s); if (!e) return null; const b = e.getBoundingClientRect(); return {top: b.top, bottom: b.bottom, w: b.width, h: b.height}; };
  return {topo: r('#topo'), abas: r('#abas'), palco: r('.palco'), previa: r('.previa'), h: innerHeight, y: scrollY, max: document.documentElement.scrollHeight - innerHeight};
}"""

resultado = {}
with sync_playwright() as p:
    nav = p.chromium.launch(headless=True)
    for w, h in LARGURAS:
        pag = nav.new_page(viewport={"width": w, "height": h})
        erros = []
        pag.on("pageerror", lambda ex: erros.append(str(ex)))
        falhas = []
        for arq, qs, aba, nome in TELAS:
            pag.goto(f"file://{B}/{arq}{qs}#{aba}")
            pag.wait_for_timeout(250)
            t = pag.evaluate(JS_TRANSBORDA)
            if t:
                falhas.append((nome, t[:6]))
            pag.screenshot(path=f"{CAP}/{nome}-{w}.png")
            if "passo" in qs or "creditos" in qs:
                continue
            pag.evaluate("scrollTo(0, document.documentElement.scrollHeight)")
            pag.wait_for_timeout(120)
            f = pag.evaluate(JS_FIXOS)
            ok = f["topo"]["top"] == 0 and abs(f["abas"]["top"] - 64) < 1 and f["previa"]["top"] >= 116 and f["previa"]["bottom"] <= h + 1
            if not ok:
                falhas.append((nome + " rolado", [json.dumps(f)]))
            if nome in ("p-cores", "e-applets") and w == 1920:
                if f["previa"]["w"] < 900:
                    falhas.append((nome, [f"previa {f['previa']['w']:.0f} < 900"]))
                resultado.setdefault("previa1920", {})[nome] = round(f["previa"]["w"])
            if nome.endswith("sons") or nome == "p-oficina-ms":
                pag.screenshot(path=f"{CAP}/{nome}-{w}-rolado.png")
        resultado[f"{w}x{h}"] = {"falhas": falhas, "erros_js": erros}
        pag.close()
    nav.close()
print(json.dumps(resultado, indent=1, ensure_ascii=False))

"""Prova da maquete A: sem transbordo, moldura fixa, prévia viva. Só headless.

Uso: python3 prova.py  (Python com Playwright; capturas em ./capturas, fora do git)
"""
import pathlib
import sys

from playwright.sync_api import sync_playwright

AQUI = pathlib.Path(__file__).resolve().parent
CAP = AQUI / "capturas"
LARGURAS = [(1920, 1080), (1550, 860), (1500, 900), (1280, 800)]
SECOES = ["painel", "janelas", "papel", "mascote", "noite", "terminal", "programas"]
PAGINAS = ["tema.html", "manter.html", "extensoes.html"] + [f"definir.html#{s}" for s in SECOES]
ESTADOS = ["vazio", "carregando", "erro", "sem-ponte"]

TRANSBORDO = """() => {
  const fora = [];
  const rola = (e) => { for (let a = e; a; a = a.parentElement) { const o = getComputedStyle(a).overflowX; if (o === 'auto' || o === 'scroll') return true; } return false; };
  for (const el of document.querySelectorAll('body *')) {
    const p = el.parentElement;
    if (!p || el.closest('svg, dialog:not([open]), [hidden]') || el.tagName === 'OPTION') continue;
    const r = el.getBoundingClientRect();
    if (!r.width || !r.height) continue;
    if (el.scrollWidth > el.clientWidth + 1 && getComputedStyle(el).overflowX === 'visible' && !rola(el)) fora.push('dentro de ' + nome(el));
    const fluxo = !['absolute', 'fixed'].includes(getComputedStyle(el).position);
    if (fluxo && p.clientWidth && el.offsetWidth > p.clientWidth + 1 && getComputedStyle(p).display !== 'contents' && !rola(p)) fora.push(nome(el) + ' > pai ' + nome(p));
  }
  function nome(e) { return e.tagName.toLowerCase() + (e.id ? '#' + e.id : '') + (e.className && typeof e.className === 'string' ? '.' + e.className.trim().split(/\\s+/).join('.') : ''); }
  return { fora: [...new Set(fora)].slice(0, 6), doc: document.documentElement.scrollWidth, janela: innerWidth };
}"""

FIXOS = """() => {
  scrollTo(0, document.documentElement.scrollHeight);
  const t = (s) => { const e = document.querySelector(s); if (!e || !e.offsetParent && getComputedStyle(e).position !== 'fixed') return null; const r = e.getBoundingClientRect(); return { top: Math.round(r.top), bottom: Math.round(r.bottom), width: Math.round(r.width) }; };
  const secao = [...document.querySelectorAll('.secao')].find((s) => !s.hidden);
  const palco = secao ? secao.querySelector('.palco') : null;
  const rp = palco ? palco.getBoundingClientRect() : null;
  const previa = palco ? palco.querySelector('.previa').getBoundingClientRect() : null;
  return { rolou: Math.round(scrollY), topo: t('.topo'), abas: t('.abas-ajustes'),
           palco: rp && { top: Math.round(rp.top), bottom: Math.round(rp.bottom) }, previa: previa && Math.round(previa.width) };
}"""

ASSINATURA = """() => {
  const p = [...document.querySelectorAll('.secao:not([hidden]) .previa')][0];
  const cs = (s, ps) => { const e = p.querySelector(s); if (!e) return ''; const c = getComputedStyle(e); return ps.map((k) => c[k]).join('|'); };
  const geo = (s) => { const e = p.querySelector(s); if (!e) return ''; const r = e.getBoundingClientRect(); return [r.left, r.top, r.width, r.height].map(Math.round).join(','); };
  const att = (s, a) => { const e = p.querySelector(s); return e ? e.getAttribute(a) : ''; };
  return [cs('.p-barra', ['borderRadius', 'backgroundColor', 'paddingLeft', 'columnGap']), geo('.p-barra'),
          cs('.p-dock', ['borderRadius', 'backgroundColor', 'paddingLeft', 'columnGap']), geo('.p-dock'),
          geo('.p-dock .ala-ini'), geo('.p-dock .centro'), geo('.p-dock .ala-fim'), geo('.p-dock .centro img'),
          geo('.p-barra .ws'), geo('.p-barra .meio'), geo('.p-barra .bandeja'), geo('.musica'), geo('.musica i'), geo('.musica .controles'), geo('.seg-relogio'),
          cs('.musica b', ['backgroundColor', 'height']), cs('.musica s', ['backgroundColor']), cs('.musica i', ['backgroundColor']),
          geo('.p-arq'), geo('.p-term'), cs('.p-ponteiro', ['color', 'fill']), cs('.cursor', ['backgroundColor']),
          att('.p-dock .gato', 'src'), att('.parede', 'src'), att('.parede', 'class'), att('.gato-ff img', 'src'), geo('.gato-ff'),
          cs('.quente', ['opacity']), cs('.papel', ['opacity']), cs('.p-term .tira i', ['backgroundColor', 'filter']), geo('.p-term .pr'), cs('.p-term .pr b', ['backgroundColor', 'width'])].join(' ;; ');
}"""

MEXER = """([tipo, k]) => {
  const ev = (e) => { e.dispatchEvent(new Event('input', { bubbles: true })); e.dispatchEvent(new Event('change', { bubbles: true })); };
  const sel = `.secao:not([hidden]) [data-chave="${k}"]`;
  const e = document.querySelector(sel);
  if (!e && tipo !== 'galeria') return 'sem controle';
  if (tipo === 'chave') e.click();
  else if (tipo === 'faixa') { const mn = +e.min, mx = +e.max; e.value = String(+e.value > (mn + mx) / 2 ? mn + (mx - mn) * 0.15 : mn + (mx - mn) * 0.85); ev(e); }
  else if (tipo === 'seg') { const b = [...e.querySelectorAll('button')].filter((x) => x.getAttribute('aria-pressed') !== 'true'); b[b.length - 1].click(); }
  else if (tipo === 'escolha') { const b = [...e.querySelectorAll('button[data-valor]')].filter((x) => x.getAttribute('aria-pressed') !== 'true'); b[0].click(); }
  else if (tipo === 'galeria') { const f = [...document.querySelectorAll('.secao:not([hidden]) .galeria figure')].filter((x) => x.getAttribute('aria-pressed') !== 'true'); f[0].click(); }
  else if (tipo === 'select') { e.selectedIndex = (e.selectedIndex + 1) % e.options.length; ev(e); }
  return 'ok';
}"""

TABELA = [
    ("painel", "faixa", "FORMA_MARGEM_PAINEL"), ("painel", "chave", "FORMA_DOCK_SOLTO"),
    ("painel", "faixa", "FORMA_MARGEM_DOCK"), ("painel", "chave", "FORMA_PAINEL_SOLTO"),
    ("painel", "chave", "FORMA_PAINEL_ILHA"), ("painel", "chave", "FORMA_DOCK_ILHA"),
    ("painel", "faixa", "FORMA_RAIO_PAINEL"), ("painel", "faixa", "FORMA_RAIO_DOCK"),
    ("painel", "faixa", "FORMA_ESPACO_PAINEL"), ("painel", "faixa", "FORMA_ESPACO_DOCK"),
    ("painel", "faixa", "VIDRO_OPACIDADE_PAINEL"), ("painel", "faixa", "VIDRO_OPACIDADE_DOCK"),
    ("painel", "faixa", "FORMA_RECHEIO_PAINEL"), ("painel", "faixa", "FORMA_RECHEIO_DOCK"),
    ("painel", "seg", "FORMA_ALA_INICIAL_PAINEL"), ("painel", "seg", "FORMA_CENTRO_PAINEL"), ("painel", "seg", "FORMA_ALA_FINAL_PAINEL"),
    ("painel", "seg", "FORMA_ALA_INICIAL_DOCK"), ("painel", "seg", "FORMA_CENTRO_DOCK"), ("painel", "seg", "FORMA_ALA_FINAL_DOCK"),
    ("painel", "chave", "RELOGIO_SEGUNDOS"), ("painel", "chave", "MIDIA_CAPA"), ("painel", "chave", "MIDIA_CONTROLES"),
    ("painel", "faixa", "MIDIA_LARGURA"), ("painel", "faixa", "MIDIA_FONTE"),
    ("painel", "escolha", "MIDIA_COR_TITULO"), ("painel", "escolha", "MIDIA_COR_ARTISTA"), ("painel", "escolha", "MIDIA_COR_ALBUM"),
    ("painel", "chave", "MIDIA"),
    ("janelas", "chave", "JANELAS_TILING"), ("janelas", "escolha", "CURSOR"),
    ("papel", "galeria", "WALLPAPER"), ("papel", "seg", "WALLPAPER_AJUSTE"),
    ("mascote", "escolha", "LOGO"), ("mascote", "chave", "FASTFETCH_LOGO"),
    ("noite", "faixa", "LEITURA_TEMPERATURA"), ("noite", "faixa", "LEITURA_TEXTURA"),
    ("terminal", "chave", "TERMINAL_ESQUEMA"), ("terminal", "seg", "TERMINAL_CURSOR"), ("terminal", "chave", "PROMPT_STARSHIP"),
]


def abrir(b, w, h, alvo):
    pg = b.new_page(viewport={"width": w, "height": h})
    erros = []
    pg.on("pageerror", lambda e: erros.append(str(e)))
    pg.on("console", lambda m: m.type == "error" and erros.append(m.text))
    pg.goto((AQUI / alvo.split("#")[0]).as_uri() + ("#" + alvo.split("#")[1] if "#" in alvo else ""))
    pg.wait_for_timeout(250)
    return pg, erros


def main():
    CAP.mkdir(exist_ok=True)
    falhas = []
    with sync_playwright() as p:
        b = p.chromium.launch(headless=True, executable_path="/usr/bin/google-chrome")
        for w, h in LARGURAS:
            ok = 0
            for alvo in PAGINAS:
                pg, erros = abrir(b, w, h, alvo)
                t = pg.evaluate(TRANSBORDO)
                nome = alvo.replace(".html", "").replace("#", "-")
                pg.screenshot(path=str(CAP / f"{nome}-{w}.png"))
                f = pg.evaluate(FIXOS)
                pg.wait_for_timeout(60)
                f = pg.evaluate(FIXOS)
                pg.screenshot(path=str(CAP / f"{nome}-{w}-fim.png"))
                prob = []
                if erros: prob.append(f"erros {erros}")
                if t["fora"]: prob.append(f"transborda {t['fora']}")
                if t["doc"] != t["janela"]: prob.append(f"documento {t['doc']} != {t['janela']}")
                if not f["topo"] or f["topo"]["top"] != 0: prob.append(f"topo {f['topo']}")
                if alvo.startswith("definir"):
                    if not f["abas"] or f["abas"]["top"] != 64: prob.append(f"abas {f['abas']}")
                    if not alvo.endswith("programas"):
                        if not f["palco"] or f["palco"]["top"] < 116 or f["palco"]["bottom"] > h: prob.append(f"palco {f['palco']}")
                        if w == 1920 and (f["previa"] or 0) < 900: prob.append(f"prévia {f['previa']}px")
                if prob: falhas.append(f"{w} {alvo}: " + "; ".join(prob))
                else: ok += 1
                pg.close()
            for alvo in ["tema.html", "manter.html", "extensoes.html", "definir.html#painel", "definir.html#papel", "definir.html#programas"]:
                for est in ESTADOS:
                    u = alvo + ("&" if "#" in alvo else "#") + "estado=" + est
                    pg, erros = abrir(b, w, h, u)
                    t = pg.evaluate(TRANSBORDO)
                    if erros or t["fora"] or t["doc"] != t["janela"]: falhas.append(f"{w} {u}: {erros} {t}")
                    else: ok += 1
                    if w == 1500: pg.screenshot(path=str(CAP / (u.replace(".html", "").replace("#", "-").replace("&", "-").replace("=", "-") + ".png")))
                    pg.close()
            print(f"{w}x{h}: {ok} verdes")

        pg, erros = abrir(b, 1500, 900, "definir.html#painel")
        mudou = 0
        for secao, tipo, k in TABELA:
            pg.evaluate(f"location.hash = '{secao}'")
            pg.wait_for_timeout(40)
            antes = pg.evaluate(ASSINATURA)
            try: r = pg.evaluate(MEXER, [tipo, k])
            except Exception as e: r = str(e).splitlines()[0]
            pg.wait_for_timeout(260)
            depois = pg.evaluate(ASSINATURA)
            if r != "ok" or antes == depois: falhas.append(f"prévia não reagiu: {secao} {k} ({r})")
            else: mudou += 1
        print(f"controle → prévia: {mudou} de {len(TABELA)}")
        if erros: falhas.append(f"erros na tabela: {erros}")
        pg.close()

        for w, h in [(1920, 1080), (1280, 800)]:
            pg, erros = abrir(b, w, h, "manter.html")
            pg.click("[data-controle='instalar-tudo']")
            pg.wait_for_timeout(3600)
            pg.click("#registro > summary") if not pg.evaluate("document.querySelector('#registro').open") else None
            d = pg.evaluate("""() => { const d = document.querySelector('#resultado'); const r = d.getBoundingClientRect();
              const bs = [...d.querySelectorAll('button')].filter((b) => !b.hidden && b.offsetParent).map((b) => { const q = b.getBoundingClientRect(); return q.left >= r.left && q.right <= r.right && q.bottom <= innerHeight && q.top >= 0; });
              return { aberto: d.open, cabe: d.scrollWidth <= d.clientWidth + 1, botoes: bs.length, visiveis: bs.every(Boolean), fim: document.querySelector('#resultado-estado').textContent }; }""")
            pg.screenshot(path=str(CAP / f"modal-instalar-{w}.png"))
            if not (d["aberto"] and d["cabe"] and d["visiveis"] and d["botoes"]): falhas.append(f"modal {w}: {d}")
            else: print(f"modal Instalar tudo {w}: {d['botoes']} botões visíveis, {d['fim']}")
            pg.close()

        pg, erros = abrir(b, 1500, 900, "manter.html#estado=sem-ponte")
        pg.click("[data-controle='instalar-tudo']")
        pg.wait_for_timeout(200)
        t = pg.evaluate("document.querySelector('#pergunta').open && document.querySelector('#pergunta-titulo').textContent")
        if t != "Falta a ponte": falhas.append(f"sem ponte: {t}")
        else: print("sem-ponte: ação de root abre «Falta a ponte»")
        pg.close()
        pg, erros = abrir(b, 1500, 900, "definir.html#painel&estado=erro")
        g = pg.evaluate("[document.querySelector('#gravando').dataset.estado, document.querySelector('#torradas').textContent]")
        if g != ["erro", "Sem servidor"]: falhas.append(f"estado erro: {g}")
        else: print("erro: gravando em erro e «Sem servidor»")
        pg.close()
        b.close()
    for f in falhas: print("FALHA", f)
    print("verde" if not falhas else f"{len(falhas)} falhas")
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())

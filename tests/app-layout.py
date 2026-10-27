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


ASSINATURA = """
() => { const p = document.querySelector('.oficina .palco .previa'); if (!p) return null;
  return { attrs: Object.entries(p.dataset).sort().map(([k, v]) => k + '=' + v).join(';'), estilo: p.getAttribute('style') || '',
           html: p.innerHTML.length, quente: (p.querySelector('.quente') || {style: {}}).style.opacity || '',
           papel: (p.querySelector('.papel') || {style: {}}).style.opacity || '',
           gato: (p.querySelector('.p-dock .gato') || {}).src || '', parede: (p.querySelector('.parede') || {}).className || '',
           ff: (p.querySelector('.gato-ff img') || {}).src || '' }; }
"""

TABELA = [
    ("painel", "FORMA_DOCK_SOLTO", "alternar", "attrs"),
    ("painel", "FORMA_PAINEL_SOLTO", "alternar", "attrs"),
    ("painel", "FORMA_PAINEL_ILHA", "alternar", "attrs"),
    ("painel", "FORMA_DOCK_ILHA", "alternar", "attrs"),
    ("painel", "RELOGIO_SEGUNDOS", "alternar", "attrs"),
    ("painel", "MIDIA", "alternar", "attrs"),
    ("painel", "MIDIA_CAPA", "alternar", "attrs"),
    ("painel", "MIDIA_CONTROLES", "alternar", "attrs"),
    ("painel", "FORMA_MARGEM_PAINEL", "faixa", "estilo"),
    ("painel", "FORMA_RAIO_PAINEL", "faixa", "estilo"),
    ("painel", "FORMA_RAIO_DOCK", "faixa", "estilo"),
    ("painel", "FORMA_ESPACO_PAINEL", "faixa", "estilo"),
    ("painel", "FORMA_ESPACO_DOCK", "faixa", "estilo"),
    ("painel", "VIDRO_OPACIDADE_PAINEL", "faixa", "estilo"),
    ("painel", "VIDRO_OPACIDADE_DOCK", "faixa", "estilo"),
    ("painel", "FORMA_CENTRO_DOCK", "seg", "estilo"),
    ("painel", "FORMA_ALA_INICIAL_DOCK", "seg", "estilo"),
    ("painel", "FORMA_ALA_FINAL_DOCK", "seg", "estilo"),
    ("painel", "FORMA_CENTRO_PAINEL", "seg", "estilo"),
    ("painel", "MIDIA_COR_TITULO", "cor", "estilo"),
    ("painel", "MIDIA_COR_ARTISTA", "cor", "estilo"),
    ("janelas", "JANELAS_TILING", "alternar", "attrs"),
    ("janelas", "CURSOR", "escolha", "estilo"),
    ("mascote", "LOGO", "escolha", "gato"),
    ("mascote", "FASTFETCH_LOGO", "alternar", "attrs"),
    ("dia-e-noite", "LEITURA_TEMPERATURA", "faixa", "quente"),
    ("dia-e-noite", "LEITURA_TEXTURA", "faixa", "papel"),
    ("terminal", "TERMINAL_ESQUEMA", "alternar", "attrs"),
    ("terminal", "PROMPT_STARSHIP", "alternar", "attrs"),
]

GESTO = """
([chave, tipo]) => {
  const q = (s) => document.querySelector(s);
  if (tipo === 'alternar') { const b = q(`[data-controle="chave:${chave}"]`); if (!b) return 'sem controle'; b.click(); return 'ok'; }
  if (tipo === 'faixa') {
    const r = q(`input[data-controle="chave:${chave}"]`); if (!r) return 'sem controle';
    const alvo = Number(r.value) === Number(r.max) ? Number(r.min) : Number(r.max);
    r.value = String(alvo); r.dispatchEvent(new Event('input', { bubbles: true })); r.dispatchEvent(new Event('change', { bubbles: true })); return 'ok';
  }
  const bs = [...document.querySelectorAll(`[data-controle^="chave:${chave}="]`)];
  if (!bs.length) return 'sem controle';
  const outro = bs.find((b) => b.getAttribute('aria-pressed') !== 'true' && !b.classList.contains('trazer'));
  if (!outro) return 'sem outra opcao'; outro.click(); return 'ok';
}
"""


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
            contexto = nav.new_context(viewport={"width": 1920, "height": 1080})
            pag = contexto.new_page()
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pag.goto(url)
            esperar(pag, 800)
            print("== a tabela controle -> prévia")
            for secao, chave, tipo, campo in TABELA:
                ir(pag, "ajustes/" + secao)
                pag.evaluate("() => { for (const d of document.querySelectorAll('details.mais')) d.open = true; }")
                antes = pag.evaluate(ASSINATURA)
                r = pag.evaluate(GESTO, [chave, tipo])
                pag.wait_for_timeout(250)
                depois = pag.evaluate(ASSINATURA)
                checa(r == "ok" and antes and depois and antes[campo] != depois[campo],
                      f"{secao} / {chave} ({tipo}) muda a prévia: {r} [{campo}: {(antes or {}).get(campo)!r} -> {(depois or {}).get(campo)!r}]"[:240])
                pag.evaluate("() => document.getElementById('desfazer') && document.getElementById('desfazer').click()")
                pag.wait_for_timeout(150)

            print("== um ↶ por coluna, a margem desligada e o deslizante vazio")
            ir(pag, "ajustes/painel")
            pag.evaluate(GESTO, ["FORMA_DOCK_SOLTO", "alternar"])
            pag.wait_for_timeout(250)
            info = pag.evaluate("""() => {
              const q = (s) => document.querySelector(s);
              const p = q('[data-controle="padrao:FORMA_DOCK_SOLTO"]');
              const m = q('input[data-controle="chave:FORMA_MARGEM_DOCK"]');
              const mp = q('input[data-controle="chave:FORMA_MARGEM_PAINEL"]');
              return { padrao: !!(p && p.closest('.ctl')), coluna: p && p.closest('.ctl').dataset.coluna,
                       noRotulo: !!document.querySelector('.linha.dupla .rot .padrao'),
                       margemDock: m && m.disabled, margemPainel: mp && mp.disabled,
                       vazio: !!document.querySelector('.faixa[data-vazio]'),
                       segSemDica: [...document.querySelectorAll('.seg button')].filter((b) => !b.dataset.dica).length };
            }""")
            checa(info["padrao"] and info["coluna"] == "Dock" and not info["noRotulo"], f"o ↶ mora na célula da coluna ({info})")
            checa(info["margemDock"] is True and info["margemPainel"] is False, f"com a dock colada, só a distância dela se desliga ({info})")
            checa(info["vazio"], "o deslizante sem valor mostra o trilho tracejado")
            checa(info["segSemDica"] == 0, "todo botão XS…XL tem dica")
            print("== Manter: cartões com o desenho ao lado")
            for (w, h) in [(1920, 1080), (1280, 800)]:
                pag.set_viewport_size({"width": w, "height": h})
                ir(pag, "cuidar")
                cartoes = pag.evaluate("""() => [...document.querySelectorAll('.cartao-acao')].map((c) => {
                  const r = (e) => e && e.getBoundingClientRect();
                  const cr = r(c), ic = r(c.querySelector('.icone, svg')), t = r(c.querySelector('h2')), f = r(c.querySelector('.fila'));
                  return { n: c.querySelector('h2') && c.querySelector('h2').textContent, ladoAlado: !!(ic && t && ic.right <= t.left + 1),
                           dentro: !!(f && f.right <= cr.right + 1 && f.left >= cr.left - 1 && t.right <= cr.right + 1) };
                })""")
                checa(len(cartoes) >= 3 and all(c["ladoAlado"] and c["dentro"] for c in cartoes), f"{w}: três cartões, desenho à esquerda e botões dentro ({cartoes})")
                pag.evaluate("() => document.querySelector('.cartao-acao').scrollIntoView({ block: 'center' })")
                pag.wait_for_timeout(200)
                foto(pag, f"{w}x{h}-cartoes")

            print("== a ficha do ícone, uma caixa e um «Usar»")
            for (w, h) in LARGURAS:
                pag.set_viewport_size({"width": w, "height": h})
                ir(pag, "criar/icones")
                pag.wait_for_function("() => document.querySelector('[data-controle=\"app\"]')", timeout=30000)
                pag.evaluate("() => { APP_ABERTO = null; DESENHO_FONTE = 'gerar'; render(); }")
                pag.wait_for_timeout(500)
                pag.locator('[data-controle="app"]').nth(2).click()
                pag.wait_for_selector(".escolha-icone", timeout=15000)
                for fonte in ["gerar", "acervo"]:
                    pag.evaluate(f"() => document.querySelector('[data-fonte=\"{fonte}\"]').click()")
                    pag.wait_for_timeout(1500)
                    for rolagem in ["topo", "fim"]:
                        pag.evaluate("() => window.scrollTo(0, 0)" if rolagem == "topo" else "() => window.scrollTo(0, document.documentElement.scrollHeight)")
                        pag.wait_for_timeout(300)
                        info = pag.evaluate("""() => {
                          const f = document.querySelector('.escolha-icone'); const r = f.getBoundingClientRect();
                          const vis = (e) => { const b = e.getBoundingClientRect(); return b.width > 0 && b.height > 0; };
                          const usar = [...document.querySelectorAll('[data-controle$="usar"]')].filter(vis);
                          const pe = usar.length === 1 ? usar[0].closest('.desenho-pe') : null;
                          const b = pe ? pe.getBoundingClientRect() : null;
                          const meio = [...f.querySelectorAll('.desenho-corpo, .desenho-olho, .desenho-mao, .desenho-mao > section, .desenho-gerar')];
                          return { usar: usar.length,
                                   dentroDaGrade: document.querySelectorAll('.grade-apps .desenho, .grade-apps .escolha-icone').length,
                                   gradeAVista: document.querySelectorAll('.grade-apps').length,
                                   altura: Math.round(r.height), janela: innerHeight, largura: document.documentElement.scrollWidth,
                                   caixas: meio.filter((e) => getComputedStyle(e).borderTopWidth !== '0px' || getComputedStyle(e).borderLeftWidth !== '0px').length,
                                   rodape: !!pe && pe.parentElement === f || !!pe && pe.parentElement.parentElement === f,
                                   rodapeNaJanela: !!b && b.top >= 0 && b.bottom <= innerHeight };
                        }""")
                        checa(info["usar"] == 1 and info["dentroDaGrade"] == 0 and info["gradeAVista"] == 0
                              and info["altura"] <= info["janela"] and info["largura"] == w and info["caixas"] == 0
                              and info["rodape"] and info["rodapeNaJanela"],
                              f"{w}x{h} {fonte} {rolagem}: um só «Usar» no rodapé da ficha e na janela, ficha no lugar da grade ({info})")
                    foto(pag, f"{w}x{h}-ficha-icone-{fonte}")
                pag.evaluate("() => { APP_ABERTO = null; DESENHO_FONTE = 'gerar'; render(); }")

            print("== o diálogo do Instalar tudo")
            for (w, h) in LARGURAS:
                pag.set_viewport_size({"width": w, "height": h})
                ir(pag, "cuidar")
                info = pag.evaluate("""() => {
                  const d = document.getElementById('resultado');
                  document.getElementById('resultado-titulo').textContent = 'Instalar tudo';
                  document.getElementById('saida').textContent = ('x'.repeat(400) + '\\n' + 'linha curta\\n').repeat(40);
                  document.getElementById('registro').open = true;
                  if (!d.open) d.showModal();
                  const r = d.getBoundingClientRect();
                  const ok = document.getElementById('resultado-ok').getBoundingClientRect();
                  const pr = document.getElementById('parar').getBoundingClientRect();
                  const out = { l: r.left, r: r.right, t: r.top, b: r.bottom, okb: ok.bottom, okr: ok.right, okvis: ok.width > 0,
                                parar: pr.width > 0, doc: document.documentElement.scrollWidth, pre: document.getElementById('saida').scrollWidth > document.getElementById('saida').clientWidth + 1 };
                  return out;
                }""")
                cabe = info["l"] >= 0 and info["r"] <= w and info["t"] >= 0 and info["b"] <= h and info["okb"] <= h and info["okr"] <= w
                checa(cabe and info["okvis"] and info["parar"] and info["doc"] == w and not info["pre"], f"{w}x{h}: o diálogo cabe, com os botões à vista e sem barra para o lado ({info})")
                foto(pag, f"{w}x{h}-dialogo")
                pag.evaluate("() => document.getElementById('resultado').close()")
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

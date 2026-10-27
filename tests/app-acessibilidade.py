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

DETALHE = "--detalhe" in sys.argv

MEDIR_JS = r"""
() => {
  const defeitos = [];
  const visivel = (el) => el.checkVisibility && el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true });
  const SEL = 'button, a[href], input:not([type=file]), select, textarea, summary, [role=switch]';
  for (const el of document.querySelectorAll('#conteudo ' + SEL.split(', ').join(', #conteudo ')
                                             + ', #topo ' + SEL.split(', ').join(', #topo '))) {
    if (!visivel(el) || el.type === 'hidden') continue;
    const r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) continue;
    const nome = el.dataset.controle || el.tagName;
    if (el.type !== 'color' && (r.width < 23.5 || r.height < 23.5))
      defeitos.push(['alvo', `«${nome}» tem ${Math.round(r.width)}x${Math.round(r.height)}`]);
    const rotulo = (el.getAttribute('aria-label') || el.textContent || el.placeholder || '').trim()
      || (el.labels && el.labels[0] && el.labels[0].textContent.trim()) || '';
    if (!rotulo) defeitos.push(['nome', `«${nome}» sem nome acessível`]);
    if (el.classList.contains('chave') && (el.getAttribute('role') !== 'switch' || !el.hasAttribute('aria-checked')))
      defeitos.push(['interruptor', `«${nome}» sem role=switch e aria-checked`]);
  }
  for (const el of document.querySelectorAll('[data-dica]')) {
    const d = el.dataset.dica;
    if (d.length > 120) defeitos.push(['dica longa', `${d.length} caracteres: «${d.slice(0, 60)}…»`]);
    if (/(^|\s)meow\s+[a-z]|\/home\/|\.sh\b/.test(d)) defeitos.push(['dica receita', `«${d.slice(0, 80)}»`]);
  }
  return defeitos;
}
"""


def esperar(pag, ms=700):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    reprovas = []
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1829, "height": 1029})
            pag.goto(url)
            esperar(pag)
            for rota in casa.ROTAS:
                pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
                esperar(pag)
                pag.wait_for_timeout(300)
                for tipo, frase in pag.evaluate(MEDIR_JS):
                    reprovas.append((rota, tipo, frase))

            pag.evaluate("() => { location.hash = '#tema'; }")
            esperar(pag)
            pag.mouse.click(5, 900)
            pag.keyboard.press("Home")
            pag.evaluate("() => document.activeElement && document.activeElement.blur()")
            portas = set()
            anel = True
            for _ in range(12):
                pag.keyboard.press("Tab")
                foco = pag.evaluate("""() => { const a = document.activeElement;
                  return { nome: a && a.dataset ? a.dataset.controle || '' : '',
                           anel: a ? getComputedStyle(a).outlineStyle !== 'none' : false }; }""")
                if foco["nome"].startswith("porta:"):
                    portas.add(foco["nome"])
                    anel = anel and foco["anel"]
            if len(portas) != 4:
                reprovas.append(("teclado", "tab", f"o Tab não chega às quatro portas ({sorted(portas)})"))
            if not anel:
                reprovas.append(("teclado", "foco", "a porta focada pelo teclado não desenha o anel"))
            pag.mouse.click(5, 900)
            pag.keyboard.press("/")
            if pag.evaluate("() => document.activeElement.id") != "busca":
                reprovas.append(("teclado", "busca", "a tecla / não leva à busca"))
            pag.keyboard.press("Escape")
            pag.evaluate("() => { location.hash = '#cuidar'; }")
            esperar(pag)
            pag.locator('[data-controle="acao:desinstalar"]').click()
            pag.wait_for_timeout(300)
            pag.keyboard.press("Escape")
            pag.wait_for_timeout(300)
            if pag.evaluate("() => document.getElementById('pergunta').open"):
                reprovas.append(("teclado", "esc", "o Esc não fecha a pergunta"))
            pag.keyboard.press("Tab")
            pag.evaluate("() => document.querySelector('.pular').focus()")
            pag.keyboard.press("Enter")
            pag.wait_for_timeout(200)
            if pag.evaluate("() => document.activeElement.id") != "principal":
                reprovas.append(("teclado", "pular", "o «Pular para o conteúdo» não leva ao conteúdo"))
            nav.close()
    finally:
        proc.terminate()
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    por_tipo = {}
    for rota, tipo, frase in reprovas:
        por_tipo.setdefault(tipo, []).append((rota, frase))
    for tipo, lista in por_tipo.items():
        print(f"  XX {tipo}: {len(lista)}")
        for rota, frase in (lista if DETALHE else lista[:5]):
            print(f"       [{rota}] {frase}")
    if reprovas:
        print(f"FALHOU: {len(reprovas)} reprova(s) de acessibilidade")
        return 1
    print("ok: alvos de 24 px, nomes, dicas curtas e o teclado, nas 14 páginas")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
import importlib.util
import json
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
ROTULO = casa._arg("--rotulo") or "medida"
SAIDA_JSON = casa._arg("--json")

MEDIR_JS = r"""
() => {
  const raiz = document.querySelector('#conteudo');
  const fora = (el) => !!el.closest('.dica, [role="tooltip"], pre, .previa');
  const desenhado = (el) => el.checkVisibility
    ? el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }) : true;
  let caracteres = 0, comando = 0, frases = 0;
  const anda = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT);
  while (anda.nextNode()) {
    const no = anda.currentNode, pai = no.parentElement;
    const t = (no.textContent || '').replace(/\s+/g, ' ').trim();
    if (!t || !pai || fora(pai) || !desenhado(pai)) continue;
    caracteres += t.length;
    if (t.length >= 48) frases += 1;
    if (pai.closest('code')) comando += t.length;
  }
  return { caracteres, frases, comando };
}
"""


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    medidas = {}
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1829, "height": 1029})
            pag.goto(url)
            for rota in casa.ROTAS:
                pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
                pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                                      " && !document.getElementById('conteudo').hasAttribute('aria-busy')",
                                      timeout=60000)
                pag.wait_for_timeout(800)
                medidas[rota] = pag.evaluate(MEDIR_JS)
                if FOTOS:
                    os.makedirs(FOTOS, exist_ok=True)
                    pag.screenshot(path=os.path.join(FOTOS, f"{ROTULO}-{rota.replace('/', '-')}.png"), full_page=True)
            nav.close()
    finally:
        proc.terminate()
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    print(f"{'página':<22} {'caracteres':>10} {'frases':>7} {'comando':>8}")
    for rota, m in medidas.items():
        print(f"{rota:<22} {m['caracteres']:>10} {m['frases']:>7} {m['comando']:>8}")
    total = sum(m["caracteres"] for m in medidas.values())
    print(f"{'total':<22} {total:>10} {sum(m['frases'] for m in medidas.values()):>7}")
    if SAIDA_JSON:
        with open(SAIDA_JSON, "w", encoding="utf-8") as fh:
            json.dump({"rotulo": ROTULO, "paginas": medidas}, fh, ensure_ascii=False, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())

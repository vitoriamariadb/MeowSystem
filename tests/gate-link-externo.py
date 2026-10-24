#!/usr/bin/env python3
"""gate-link-externo.py — o «Créditos» do gate não depende da sorte. P79, 10/10/2026.

O QUE ABRIU ISTO
  A conferência da P77 anotou: o clique no «Créditos» do menu (`menu · link
  externo`) estourou o tempo uma vez no gate completo e passou na corrida
  seguinte. A causa: a marca `data-inventario` que o censo põe mora no
  elemento, e uma repintura do menu entre o censo e o clique (a página relê o
  que chega pela rede) a apaga — o `click` esperava um elemento que não existe
  mais até o teto. O `clicar_nome` do gate já sabia disso e tentava de novo; o
  `h_link_externo`, não.

COMO SE MEDE
  Uma página mínima com o menu (`#menu-corpo`, o do painel novo da P98) e o
  link `menu:creditos`, que REPINTA o menu no primeiro `pointerover` do link — a
  repintura chega exatamente entre achar o link e o clique. Roda o `h_link_externo` do próprio `tests/app-completo.py` contra
  ela. Com o código de antes: «Locator.click: Timeout 30000ms exceeded».

  0 = passou · 1 = falhou · 3 = pulado (sem Playwright)
"""
import importlib.util
import os
import sys

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("pulado: playwright nao esta instalado neste interpretador.")
    sys.exit(3)

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("gate", os.path.join(AQUI, "app-completo.py"))
_argv, sys.argv = sys.argv, [os.path.join(AQUI, "app-completo.py")]
gate = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gate)
sys.argv = _argv
# Só de carregar o `app-completo.py` nasce o `meow-completo-*` dele em /tmp (o
# `mkdtemp` mora no topo do módulo), e quem apaga é o `finally` do `__main__`
# de lá, que aqui não roda: cada rodada da suíte deixava uma pasta vazia.
import atexit  # noqa: E402
import shutil  # noqa: E402
atexit.register(shutil.rmtree, gate.BRINQUEDO, True)

PAGINA = """<div id="menu-corpo"><a href="https://exemplo.invalid/creditos" target="_blank"
 rel="noopener" data-controle="menu:creditos">Créditos</a></div><main id="principal"></main>
<script>
let vez = 0;
document.addEventListener('pointerover', (ev) => {
  const a = ev.target.closest && ev.target.closest('#menu-corpo a');
  if (a && vez++ === 0)
    document.getElementById('menu-corpo').replaceChildren(a.cloneNode(true));
}, true);
</script>"""

with sync_playwright() as pw:
    navegador = pw.chromium.launch()
    contexto = navegador.new_context()

    def rota(r):
        gate.PEDIDOS_DE_FORA.append(r.request.url)
        r.abort()

    contexto.route("https://**/*", rota)
    pag = contexto.new_page()
    pag.set_content(PAGINA)
    p = gate.Percurso(pag)
    try:
        p.h_link_externo("menu:creditos")
        erro = None
    except Exception as e:  # noqa: BLE001 — o defeito era justamente a exceção
        erro = "%s: %s" % (type(e).__name__, str(e).splitlines()[0])
    navegador.close()

if erro or p.falhas:
    print("FALHOU: o link externo do gate não aguenta a repintura entre o censo e o clique")
    print("  " + (erro or "; ".join(p.falhas)))
    sys.exit(1)
print("ok: com o menu repintado entre o censo e o clique, o «Créditos» abre a aba nova")
sys.exit(0)

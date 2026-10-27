#!/usr/bin/env python3
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
    except Exception as e:  # noqa: BLE001
        erro = "%s: %s" % (type(e).__name__, str(e).splitlines()[0])
    navegador.close()

if erro or p.falhas:
    print("FALHOU: o link externo do gate não aguenta a repintura entre o censo e o clique")
    print("  " + (erro or "; ".join(p.falhas)))
    sys.exit(1)
print("ok: com o menu repintado entre o censo e o clique, o «Créditos» abre a aba nova")
sys.exit(0)

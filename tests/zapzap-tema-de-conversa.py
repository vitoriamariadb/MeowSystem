#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("pulado: playwright nao esta instalado neste interpretador.")
    sys.exit(3)

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELO = os.path.join(RAIZ, "scripts/temas-de-apps/zapzap/zapzap.modelo.css")
PACK, FLAVOR = "meowsystem", "mocha"
PALETA = os.path.join(RAIZ, "packs", PACK, "paleta.json")

css = subprocess.run(
    [sys.executable, os.path.join(RAIZ, "scripts/temas-de-apps/modelo.py"), MODELO, PALETA, FLAVOR, PACK],
    capture_output=True, text=True, check=True).stdout
cores = json.load(open(PALETA))["flavors"][FLAVOR]

WHATSAPP = """
.xfundo.xfundo,.xfundo.xfundo:root{
  --WDS-systems-chat-background-wallpaper:#ff0000;
  --WDS-systems-chat-background-wallpaper-RGB:255,0,0;
  --WDS-systems-chat-foreground-wallpaper:#ff0001;
  --WDS-accent:#ff0002;
}
.xbolha.xbolha,.xbolha.xbolha:root{
  --WDS-systems-bubble-surface-incoming:#00ff00;
  --WDS-systems-bubble-surface-outgoing:#00ff01;
}
.xgrupo{--WDS-systems-bubble-surface-incoming:var(--WDS-systems-chat-foreground-wallpaper)}
"""
DOM = """
<div class="app-wrapper-web">
  <div id="main" class="xfundo" data-testid="conversation-panel-wrapper">
    <div><div class="xbolha"><div class="xgrupo"><span id="bolha"></span></div></div></div>
  </div>
</div>
"""

falhas = []


def checa(cond, frase, detalhe=""):
    if cond:
        print("ok:", frase)
    else:
        print("FALHOU:", frase, detalhe)
        falhas.append(frase)


def ler(pagina, folha):
    pagina.set_content("<!doctype html><html class='dark'><head><style>%s</style><style>%s</style></head>"
                       "<body>%s</body></html>" % (WHATSAPP, folha, DOM))
    return pagina.evaluate("""() => {
      const v = (sel, nome) => getComputedStyle(document.querySelector(sel)).getPropertyValue(nome).trim();
      return {
        fundo: v('#main', '--WDS-systems-chat-background-wallpaper'),
        frente: v('#main', '--WDS-systems-chat-foreground-wallpaper'),
        acento: v('#bolha', '--WDS-accent'),
        entra: v('#bolha', '--WDS-systems-bubble-surface-incoming'),
        sai: v('#bolha', '--WDS-systems-bubble-surface-outgoing'),
      };
    }""")


def sem_main(folha):
    folha = folha.replace(",\n#main {", " {")
    return re.sub(r"\n#main \* \{[^}]*\}\n", "\n", folha)


with sync_playwright() as p:
    nav = p.chromium.launch(headless=True)
    pagina = nav.new_page()
    antes = ler(pagina, sem_main(css))
    checa(antes["fundo"].lower() == "#ff0000" and antes["entra"].lower() != cores["base"].lower(),
          "controle: sem o #main na folha, o tema de conversa do WhatsApp vence o :root do pack", antes)
    agora = ler(pagina, css)
    checa(agora["fundo"].lower() == cores["crust"].lower(),
          "com um tema de conversa escolhido, o fundo da conversa fica no crust do pack", agora)
    checa(agora["frente"].lower() == cores["mantle"].lower(),
          "e a camada da frente do fundo, no mantle do pack", agora)
    checa(agora["entra"].lower() == cores["base"].lower(),
          "a bolha recebida, mesmo com a classe do tema de conversa nela, fica no base do pack", agora)
    checa(agora["sai"].startswith("color-mix"),
          "a bolha enviada fica na mistura do verde do pack", agora)
    checa(agora["acento"].lower() == cores["green"].lower(),
          "o acento dentro da conversa fica no verde do pack", agora)
    nav.close()

if falhas:
    print("\n%d falha(s)" % len(falhas))
    sys.exit(1)
print("\ntudo certo")

#!/usr/bin/env python3
import importlib.util
import os
import shutil
import sys

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("pulado: playwright nao esta instalado neste interpretador.")
    sys.exit(3)

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("app_completo", os.path.join(AQUI, "app-completo.py"))
casa = importlib.util.module_from_spec(_spec)
_argv, sys.argv = sys.argv, [os.path.join(AQUI, "app-completo.py")]
_spec.loader.exec_module(casa)
sys.argv = _argv

PLANTADAS = [
    ("tema-sem-captura", "install.sh", "O tema do COSMIC ficou sem captura", "./install.sh --so tema"),
    ("qbittorrent-tema-de-terceiro", "manifesto.sh", "O qBittorrent está com um tema de fora",
     "meow apps aplicar qbittorrent"),
    ("spicetify-tema-ausente", "spotify.sh", "O Spotify ficou sem o tema", "meow apps aplicar"),
]

TELA_JS = r"""
() => {
  const raiz = document.querySelector('#conteudo');
  const texto = (raiz.innerText || '').replace(/\s+/g, ' ');
  return {
    linhas: raiz.querySelectorAll('[data-linha^="pendencia:"], [data-linha^="gente:"], .pendencias').length,
    titulos: [...raiz.querySelectorAll('h1, h2, h3')].map((h) => h.textContent.trim()),
    conta: (texto.match(/\d+\s+pend[êe]ncias?/i) || [""])[0],
    script: (texto.match(/install\.sh|manifesto\.sh|spotify\.sh/i) || [""])[0],
    pilula: [...document.querySelectorAll('.estado-pilula')].map((p) => p.textContent.trim()),
  };
}
"""


def main():
    ambiente = casa.montar_casa()
    os.makedirs(casa.ESTADO, exist_ok=True)
    with open(os.path.join(casa.ESTADO, "pendencias.tsv"), "a", encoding="utf-8") as fh:
        for ident, etapa, frase, comando in PLANTADAS:
            fh.write(f"{ident}\t{etapa}\t{frase}\t{comando}\t2026-10-28T18:06:00-03:00\n")
    with open(os.path.join(casa.ESTADO, "precisa-de-gente.tsv"), "w", encoding="utf-8") as fh:
        fh.write("sentinela-cosmic\tO COSMIC da fila não entra\t2026-10-28T18:06:00-03:00\tserie: brinquedo\n")
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    falhas, vistas = [], {}
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1829, "height": 1029})
            pag.goto(url)
            for rota in ("cuidar", "tema"):
                pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
                pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                                      " && !document.getElementById('conteudo').hasAttribute('aria-busy')",
                                      timeout=60000)
                pag.wait_for_timeout(800)
                vistas[rota] = pag.evaluate(TELA_JS)
            no_disco = pag.evaluate("async () => ((await api('/api/pendencias')).pendencias || []).map((p) => p.id)")
            if not all(ident in no_disco for ident, *_ in PLANTADAS):
                falhas.append("as pendências plantadas não chegaram ao servidor: %r" % no_disco)
            nav.close()
    finally:
        proc.terminate()
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    manter = vistas.get("cuidar") or {}
    if not manter.get("titulos"):
        falhas.append("o Manter não desenhou nada: %r" % manter)
    if manter.get("linhas"):
        falhas.append("o Manter ainda tem %d linha(s) de pendência" % manter["linhas"])
    if any("Pendência" in t for t in manter.get("titulos", [])):
        falhas.append("o Manter ainda tem o cartão «Pendências»: %r" % manter["titulos"])
    for rota, v in vistas.items():
        if v.get("conta"):
            falhas.append("%s mostra «%s»" % (rota, v["conta"]))
        if v.get("script"):
            falhas.append("%s mostra o nome de script «%s»" % (rota, v["script"]))
        if any("pendência" in t.lower() for t in v.get("pilula", [])):
            falhas.append("%s tem a pílula de pendências: %r" % (rota, v["pilula"]))
    for f in falhas:
        print("FALHOU: " + f)
    if falhas:
        return 1
    print("ok: com %d pendências e 1 «precisa de gente» no disco, o Manter (%d blocos) e o Tema não mostram "
          "cartão, conta nem nome de script" % (len(PLANTADAS), len(manter["titulos"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())

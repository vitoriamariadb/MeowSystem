#!/usr/bin/env python3
import importlib.util
import os
import re
import shutil
import sys

try:
    import playwright  # noqa: F401
except ImportError:
    print("pulado: playwright nao esta instalado neste interpretador.")
    sys.exit(3)

AQUI = os.path.dirname(os.path.abspath(__file__))


def carregar(nome, arquivo):
    spec = importlib.util.spec_from_file_location(nome, os.path.join(AQUI, arquivo))
    mod = importlib.util.module_from_spec(spec)
    antigo, sys.argv = sys.argv, [os.path.join(AQUI, arquivo)]
    spec.loader.exec_module(mod)
    sys.argv = antigo
    return mod


casa = carregar("app_completo", "app-completo.py")
vizinho = carregar("icones_por_pack", "icones-por-pack.py")

from playwright.sync_api import sync_playwright  # noqa: E402

INGLES = {"Zip", "Image", "Text", "Video", "Font", "Key", "Log", "Database", "Certificate", "Changelog",
          "Readme", "Symlink", "Exe", "Header", "Diff", "Audio"}
falhas = []


def confere(cond, frase):
    print(("ok: " if cond else "FALHOU: ") + frase)
    if not cond:
        falhas.append(frase)


def partir_do_flavor(pag, pack, flavor):
    achou = pag.evaluate("""([p, f]) => { const flavors = (PACKS.find((x) => x.id === p).flavors || []);
        const alvo = flavors.find((x) => x.id === f); if (!alvo) return false;
        const r = rascunho(); r.base = { pack: p, flavor: alvo.id }; r.cores = {}; r.pack = '';
        guardarRascunho(); render(); return true; }""", [pack, flavor])
    pag.wait_for_timeout(500)
    return achou


MEDIR = """async () => {
  const lum = (h) => { const x = parseInt(h.slice(1), 16);
    const c = [(x >> 16) & 255, (x >> 8) & 255, x & 255].map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]; };
  const hex = (rgb) => '#' + rgb.match(/\\d+/g).slice(0, 3).map((n) => Number(n).toString(16).padStart(2, '0')).join('');
  const razao = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
  const tinta = vinteSeis().text.toLowerCase();
  const ruins = []; let total = 0, coloridos = 0;
  for (const card of document.querySelectorAll('.grade-apps.pastas .app')) {
    const fundo = hex(getComputedStyle(card).backgroundColor);
    const texto = await (await fetch(card.querySelector('img').src)).text();
    const cores = [...texto.matchAll(/(?:stroke|fill)="(#[0-9a-fA-F]{6})"/g)].map((m) => m[1]);
    if (!cores.length) continue;
    const melhor = Math.max(...cores.map((c) => razao(c, fundo)));
    if (!cores.some((c) => c.toLowerCase() === tinta)) { if (melhor < 3) coloridos++; continue; }
    total++;
    if (melhor < 3) ruins.push(card.dataset.nome + ' ' + melhor.toFixed(2));
  }
  return { total, ruins, coloridos };
}"""

ROTULOS = """() => [...document.querySelectorAll('.grade-apps.pastas .app .nome')].map((n) => ({
  texto: n.textContent, cortado: n.scrollWidth > n.clientWidth + 1 || n.scrollHeight > n.clientHeight + 1,
  reticencias: getComputedStyle(n).textOverflow === 'ellipsis' && n.scrollWidth > n.clientWidth }))"""


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1280, "height": 800})
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pag.goto(url, wait_until="commit")
            vizinho.esperar(pag, 800)
            vizinho.ir(pag, "criar/icones")

            confere(partir_do_flavor(pag, "meowsystem", "latte"), "o rascunho parte do Latte, o flavor claro")
            for aba in ("sistema", "biblioteca"):
                vizinho.aba(pag, aba)
                pag.wait_for_timeout(800)
                r = pag.evaluate(MEDIR)
                confere(r["total"] > 20 and not r["ruins"],
                        f"Latte, {aba}: nenhum desenho no traço do texto abaixo de 3:1 no cartão ({r['total']} medidos, ruins: {len(r['ruins'])}: {r['ruins'][:6]}; {r['coloridos']} de cor própria fora da conta)")

            for pack, flavor, nome in (("meowsystem", "mocha", "Mocha"), ("dracula", "dracula", "Dracula")):
                confere(partir_do_flavor(pag, pack, flavor), f"o rascunho parte do {nome}")
                for aba in ("sistema", "biblioteca"):
                    vizinho.aba(pag, aba)
                    pag.wait_for_timeout(800)
                    r = pag.evaluate(MEDIR)
                    confere(r["total"] > 20 and not r["ruins"],
                            f"{nome}, {aba}: nenhum desenho no traço do texto abaixo de 3:1 no cartão ({r['total']} medidos, ruins: {len(r['ruins'])}: {r['ruins'][:6]}; {r['coloridos']} de cor própria fora da conta)")

            for larg in (390, 1280):
                pag.set_viewport_size({"width": larg, "height": 800})
                vizinho.aba(pag, "sistema")
                pag.wait_for_timeout(600)
                rot = pag.evaluate(ROTULOS)
                baterias = [x for x in rot if x["texto"].startswith("Bateria")]
                confere(len(baterias) >= 30 and not any(x["cortado"] or x["reticencias"] for x in baterias),
                        f"{larg}px: os {len(baterias)} rótulos de bateria aparecem inteiros")
                confere(not any(x["cortado"] or x["reticencias"] for x in rot),
                        f"{larg}px: nenhum rótulo da aba Sistema some atrás de reticências")
                ingles = sorted({x["texto"] for x in rot} & INGLES)
                confere(not ingles, f"{larg}px: nenhum tipo de arquivo em inglês na aba Sistema ({ingles})")
                tipos = {x["texto"] for x in rot}
                confere({"Imagem", "Arquivo zip", "Vídeo"} <= tipos, f"{larg}px: os tipos de arquivo têm nome em português")

            confere(not erros, f"sem erro de script na página ({erros[:1]})")
            nav.close()
    finally:
        proc.terminate()
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
        shutil.rmtree(vizinho.casa.BRINQUEDO, ignore_errors=True)
    if falhas:
        print(f"FALHOU: {len(falhas)} conferência(s)")
        return 1
    print("ok: o Latte no Sistema e na Biblioteca, os rótulos inteiros e os tipos em português")
    return 0


if __name__ == "__main__":
    sys.exit(main())

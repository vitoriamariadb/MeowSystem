#!/usr/bin/env python3
import base64
import importlib.util
import os
import re
import shutil
import struct
import subprocess
import sys
import time
import zlib

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
falhas = []
conferidas = [0]
ID = "meu-tema"

TEXTO_DO_ARTE_JS = """
async (id) => {
  const img = document.querySelector(`article.pack[data-pack="${id}"] img.logo`);
  return { texto: await (await fetch(img.src)).text(), carregou: img.complete && img.naturalWidth > 0 };
}
"""
CABECALHO_JS = """
async () => {
  const img = document.querySelector('#topo .marca img');
  return { texto: await (await fetch(img.src)).text(), carregou: img.complete && img.naturalWidth > 0 };
}
"""


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


def eventual(fn, seg=20):
    fim = time.time() + seg
    while time.time() < fim:
        try:
            if fn():
                return True
        except Exception:
            pass
        time.sleep(0.3)
    return False


def esperar(pag, ms=400):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def pack_pessoal(ambiente):
    csv = os.path.join(casa.BRINQUEDO, ID + ".csv")
    with open(os.path.join(casa.RAIZ, "packs", "dracula", "paleta.json"), encoding="utf-8") as fh:
        import json
        p = json.load(fh)
    ordem = p.get("ordem_canonica") or list(next(iter(p["flavors"].values())))
    cores = p["flavors"]["dracula"]
    with open(csv, "w", encoding="utf-8") as fh:
        fh.write("slot,flavor,hex\n" + "".join(f"{n},meutema,{cores[n]}\n" for n in ordem))
    ambiente_pack = {k: v for k, v in ambiente.items() if k in ("PATH", "HOME", "LANG")}
    r = subprocess.run([sys.executable, os.path.join(casa.RAIZ_B, "scripts", "pack.py"), "importar", csv],
                       env=ambiente_pack, capture_output=True, text=True)
    return r.returncode == 0, r.stdout + r.stderr


def png_de_teste(caminho):
    def bloco(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    linhas = b"".join(b"\x00" + (b"\xff\x00\x80\xff" if 4 <= y < 12 else b"\x00\x00\x00\x00") * 16 for y in range(16))
    with open(caminho, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", 16, 16, 8, 6, 0, 0, 0))
                 + bloco(b"IDAT", zlib.compress(linhas)) + bloco(b"IEND", b""))


def main():
    ambiente = casa.montar_casa()
    pack_dir = os.path.join(casa.CASA, ".local", "share", "meowsystem", "packs", ID)
    ok, saida = pack_pessoal(ambiente)
    if not ok:
        print("ERRO: o pack pessoal não nasceu\n" + saida)
        return 2
    with open(casa.CONF, encoding="utf-8") as fh:
        conf = fh.read()
    conf = re.sub(r'^PACK=.*$', f'PACK="{ID}"', conf, flags=re.M)
    conf = re.sub(r'^FLAVOR=.*$', 'FLAVOR="meutema"', conf, flags=re.M)
    with open(casa.CONF, "w", encoding="utf-8") as fh:
        fh.write(conf)
    logo_arq = os.path.join(pack_dir, "logo.svg")
    with open(logo_arq, encoding="utf-8") as fh:
        inicial = fh.read()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            contexto = nav.new_context(viewport={"width": 1920, "height": 1080})
            pag = contexto.new_page()
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pedidos = []
            contexto.route("https://**/*", lambda r: (pedidos.append(r.request.url), r.abort()))
            pag.goto(url)
            esperar(pag, 800)

            print("1. só o cartão do pack pessoal tem o botão da logo")
            cartoes = pag.evaluate("() => [...document.querySelectorAll('article.pack')].map((a) => ({ id: a.dataset.pack,"
                                   " botao: !!a.querySelector('.logo-trocar') }))")
            por_id = {c["id"]: c["botao"] for c in cartoes}
            checa(por_id.get(ID) is True, f"o cartão {ID} tem o botão ({por_id})")
            checa(por_id.get("dracula") is False and por_id.get("meowsystem") is False,
                  "dracula e meowsystem não têm")
            antes = pag.evaluate(TEXTO_DO_ARTE_JS, ID)
            checa(antes["carregou"] and "traco-tinta" in antes["texto"], "o cartão começa com o M gerado")
            if FOTOS:
                pag.locator(f'article.pack[data-pack="{ID}"]').screenshot(path=os.path.join(FOTOS, "p145-cartao-1920.png"))

            print("2. a grade abre com as logos dos packs e os desenhos do mascote")
            pag.locator(f'[data-controle="pack:{ID}:logo"]').click()
            pag.wait_for_selector("#logo-do-pack[open] .escolha")
            pag.wait_for_timeout(500)
            chaves = pag.evaluate("() => [...document.querySelectorAll('#logo-do-pack-grade [data-controle]')]"
                                  ".map((b) => b.dataset.controle.replace('logo-do-pack:', ''))")
            checa({"gerada:", "pack:dracula", "pack:meowsystem", "gato:coquinha", "arquivo"} <= set(chaves),
                  f"gerada, packs, mascote e arquivo ({chaves})")
            carregadas = pag.evaluate("() => [...document.querySelectorAll('#logo-do-pack-grade img')]"
                                      ".map((i) => i.complete && i.naturalWidth > 0)")
            checa(all(carregadas) and len(carregadas) >= 4, f"cada opção mostra a logo ({carregadas})")
            checa(pag.locator('[data-controle="logo-do-pack:gerada:"]').get_attribute("aria-pressed") == "true",
                  "a logo de agora vem marcada")
            if FOTOS:
                pag.screenshot(path=os.path.join(FOTOS, "p145-grade-1920.png"))

            print("3. escolher o gato troca o cartão e o cabeçalho")
            cab_antes = pag.evaluate(CABECALHO_JS)
            pag.locator('[data-controle="logo-do-pack:gato:coquinha"]').click()
            checa(eventual(lambda: not pag.evaluate("() => document.getElementById('logo-do-pack').open")),
                  "a janela fecha")
            with open(logo_arq, encoding="utf-8") as fh:
                depois_arq = fh.read()
            checa(depois_arq != inicial and "traco-tinta" not in depois_arq, "a logo.svg do pack pessoal mudou")
            checa(eventual(lambda: "traco-tinta" not in pag.evaluate(TEXTO_DO_ARTE_JS, ID)["texto"]),
                  "o cartão mostra o gato")
            checa(pag.evaluate(TEXTO_DO_ARTE_JS, ID)["carregou"], "e a imagem do cartão carregou")
            cab = pag.evaluate(CABECALHO_JS)
            checa(cab["carregou"] and cab["texto"] == pag.evaluate(TEXTO_DO_ARTE_JS, ID)["texto"],
                  "o cabeçalho mostra o mesmo gato (pack pessoal no ar, logo do programa vazia)")
            checa(cab_antes["texto"] != cab["texto"], "e mudou em relação ao de antes")
            if FOTOS:
                pag.locator(f'article.pack[data-pack="{ID}"]').screenshot(path=os.path.join(FOTOS, "p145-cartao-gato-1920.png"))
                pag.locator("#topo").screenshot(path=os.path.join(FOTOS, "p145-cabecalho.png"))

            print("4. um PNG vira a logo; arquivo ruim recusa e deixa a anterior")
            png = os.path.join(casa.BRINQUEDO, "logo.png")
            png_de_teste(png)
            pag.locator(f'[data-controle="pack:{ID}:logo"]').click()
            pag.wait_for_selector("#logo-do-pack[open] .escolha")
            checa(pag.locator('[data-controle="logo-do-pack:gato:coquinha"]').get_attribute("aria-pressed") == "true",
                  "agora o gato vem marcado")
            pag.set_input_files(f'[data-logo-arquivo="{ID}"]', png)
            checa(eventual(lambda: not pag.evaluate("() => document.getElementById('logo-do-pack').open")),
                  "o PNG fecha a janela")
            checa(eventual(lambda: 'fill="#FF0080"' in open(logo_arq, encoding="utf-8").read()), "a logo.svg guarda o PNG como vetor")
            guardada = open(logo_arq, encoding="utf-8").read()
            ruim = os.path.join(casa.BRINQUEDO, "ruim.svg")
            with open(ruim, "w", encoding="utf-8") as fh:
                fh.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8"><script>1</script></svg>')
            pag.locator(f'[data-controle="pack:{ID}:logo"]').click()
            pag.wait_for_selector("#logo-do-pack[open] .escolha")
            pag.set_input_files(f'[data-logo-arquivo="{ID}"]', ruim)
            checa(eventual(lambda: pag.locator("#logo-do-pack-queixa").inner_text().strip() != ""), "a queixa aparece na janela")
            checa(pag.evaluate("() => document.getElementById('logo-do-pack').open"), "a janela segue aberta")
            checa(open(logo_arq, encoding="utf-8").read() == guardada, "e a logo anterior fica")
            if FOTOS:
                pag.screenshot(path=os.path.join(FOTOS, "p145-recusa-1920.png"))
                pag.set_viewport_size({"width": 800, "height": 1000})
                pag.wait_for_timeout(300)
                pag.screenshot(path=os.path.join(FOTOS, "p145-recusa-800.png"))
                pag.set_viewport_size({"width": 1920, "height": 1080})
            pag.keyboard.press("Escape")

            checa(not pedidos, f"a página não pediu nada à internet ({pedidos[:2]})")
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
    print(f"{conferidas[0]} conferências")
    return 0


if __name__ == "__main__":
    sys.exit(main())

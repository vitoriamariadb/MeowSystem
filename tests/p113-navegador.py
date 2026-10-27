#!/usr/bin/env python3
import importlib.util
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
FALHAS = []


def prova(ok, texto):
    print(("ok: " if ok else "FALHOU: ") + texto)
    if not ok:
        FALHAS.append(texto)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(600)


def foto(pag, nome):
    if FOTOS:
        os.makedirs(FOTOS, exist_ok=True)
        pag.screenshot(path=os.path.join(FOTOS, nome), full_page=True)


def sons(pag, url):
    ir(pag, "criar/sons")
    pag.wait_for_selector(".sons li[data-som]", timeout=20000)
    foto(pag, "sons.png")
    nomes = pag.eval_on_selector_all(".sons li[data-som] .som-nome b", "(xs) => xs.map((x) => x.textContent)")
    quando = pag.eval_on_selector_all(".sons li[data-som] .som-nome small", "(xs) => xs.map((x) => x.textContent)")
    prova(len(nomes) >= 25 and "Na tomada" in nomes and "Bateria fraca" in nomes,
          "a página Sons lista os sons do sistema por nome legível (%d)" % len(nomes))
    prova(all(quando) and "O carregador entra" in quando, "cada som diz quando toca")
    prova(pag.locator("h2", has_text="Toca no COSMIC").count() == 1
          and pag.locator("h2", has_text="Toca nos apps").count() == 1, "dois blocos: COSMIC e apps")
    prova(pag.locator(".sons li[data-som] [data-origem]").count() == len(nomes), "cada som mostra de onde vem")
    prova(pag.locator(".sons li[data-som='power-plug'] [data-controle='som:trocar']").count() == 1, "cada som tem o Trocar")
    pag.evaluate("() => { ESQUEMA.ponte = false; render(); }")
    pag.wait_for_timeout(300)
    prova(pag.locator("[data-controle='som:ponte']").count() == 1
          and pag.locator(".sons li.sem-ponte").count() == 7, "sem ponte: aviso com «Consertar a ponte» e os 7 sons de carregador e bateria marcados")
    foto(pag, "sons-sem-ponte.png")
    pag.evaluate("() => { ESQUEMA.ponte = true; render(); }")

    import time
    tempo = time.time()
    pag.fill("[data-chave='SOM_FUNDAMENTAL'] input[type=range], [data-linha='SOM_FUNDAMENTAL'] input", "1000")
    pag.wait_for_timeout(300)
    q = pag.evaluate("() => urlDoSino()")
    corpo_previa = bytes(pag.evaluate("async (q) => Array.from(new Uint8Array(await (await fetch(q)).arrayBuffer()))", q))
    prova(corpo_previa[:4] == b"RIFF", "a prévia do sino vem do gerador do som.sh (WAV)")
    pag.click("[data-controle='acao:som_aplicar']")
    destino = os.path.join(casa.CASA, ".local", "share", "sounds", "freedesktop", "stereo", "audio-volume-change.oga")
    for _ in range(60):
        if os.path.isfile(destino) and os.path.getmtime(destino) > tempo:
            break
        pag.wait_for_timeout(500)
    gravado = open(destino, "rb").read() if os.path.isfile(destino) else b""
    prova(gravado == corpo_previa, "o «Regravar» grava os mesmos bytes que a prévia tocou (%d bytes)" % len(gravado))
    pag.reload()
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA", timeout=60000)
    ir(pag, "criar/sons")
    q2 = pag.evaluate("() => urlDoSino()")
    depois = bytes(pag.evaluate("async (q) => Array.from(new Uint8Array(await (await fetch(q)).arrayBuffer()))", q2))
    prova(depois == gravado and "SOM_FUNDAMENTAL=1000" in q2, "depois de recarregar, o controle, a prévia e o instalado seguem iguais")
    return q, corpo_previa


def lancador(pag):
    ir(pag, "ajustes/programas")
    campo = pag.locator("[data-controle='chave:LANCADOR_OCULTAR:nova']")
    campo.scroll_into_view_if_needed()
    prova(campo.get_attribute("list") == "apps-LANCADOR_OCULTAR", "o campo de «Escondidos» ganha a lista de programas")
    pag.wait_for_function("() => document.querySelectorAll('#apps-LANCADOR_OCULTAR option').length > 0", timeout=60000)
    ids = pag.eval_on_selector_all("#apps-LANCADOR_OCULTAR option", "(xs) => xs.map((x) => x.value)")
    prova(len(ids) > 0, "a lista sugere os programas de /api/apps (%d)" % len(ids))
    foto(pag, "lancador-escondidos.png")
    antes = pag.eval_on_selector_all("[data-linha='LANCADOR_OCULTAR'] .ficha", "(xs) => xs.length")
    campo.fill("programa-que-nao-existe")
    campo.press("Enter")
    pag.wait_for_timeout(800)
    depois = pag.eval_on_selector_all("[data-linha='LANCADOR_OCULTAR'] .ficha", "(xs) => xs.length")
    prova(antes == depois and not pag.evaluate("() => MUDANCAS.has('LANCADOR_OCULTAR')"), "um programa que não existe é recusado")
    novo = next((i for i in ids if i not in pag.evaluate("() => vale('LANCADOR_OCULTAR')").split(",")), None)
    if novo:
        pag.locator("[data-controle='chave:LANCADOR_OCULTAR:nova']").fill(novo)
        pag.locator("[data-controle='chave:LANCADOR_OCULTAR:nova']").press("Enter")
        pag.wait_for_timeout(800)
        prova(novo in pag.evaluate("() => vale('LANCADOR_OCULTAR')").split(","), "um programa que existe entra na lista (%s)" % novo)
    foto(pag, "lancador-depois.png")


def mandar_e_rascunho(pag, nav, url):
    ir(pag, "criar/cores")
    pag.fill("input.nome-tema", "Meu Gato")
    pag.press("input.nome-tema", "Enter")
    pag.wait_for_timeout(600)
    pag.evaluate("() => { rascunho().cores = { base: '#101820' }; guardarRascunho(); }")
    ir(pag, "criar/mandar")
    foto(pag, "mandar.png")
    linhas = pag.eval_on_selector_all("[data-resumo]", "(xs) => xs.map((x) => x.dataset.resumo)")
    prova(linhas[:3] == ["Cores", "Ícones", "Pastas"] and len(linhas) == 7, "Mandar mostra o resumo do tema sem ele ter sido guardado: %s" % linhas)
    prova(pag.evaluate("() => !rascunho().pack"), "o tema ainda não foi guardado")
    prova(pag.locator("[data-controle='criar:baixar']").is_enabled() and pag.locator("[data-controle='criar:vestir']").is_enabled(),
          "as saídas (Baixar o tema, Vestir agora) já valem")
    with pag.expect_response(lambda r: "/api/rascunho" in r.url and r.request.method == "POST"):
        pag.evaluate("() => guardarRascunho()")
    pag.click("[data-controle='criar:baixar']")
    pag.wait_for_function("() => !!rascunho().pack", timeout=60000)
    pag.wait_for_timeout(1500)
    prova(pag.evaluate("() => PACKS.some((p) => p.id === rascunho().pack)"), "«Baixar o tema» guardou o tema sozinho, sem o botão Guardar")
    pag.keyboard.press("Escape")
    pag.wait_for_timeout(500)
    pag.evaluate("() => enviarRascunho()")
    pag.wait_for_timeout(800)
    ctx = nav.new_context(viewport={"width": 1829, "height": 1029})
    outra = ctx.new_page()
    outra.goto(url)
    ir(outra, "criar/cores")
    nome = outra.evaluate("() => rascunho().nome")
    cores = outra.evaluate("() => rascunho().cores")
    prova(nome == "Meu Gato" and cores.get("base") == "#101820",
          "numa janela nova, sem o localStorage da outra, o rascunho volta do servidor (%s %s)" % (nome, cores))
    foto(outra, "rascunho-outra-janela.png")
    ctx.close()


def sem_baixar(pag):
    import re
    achados = []
    for rota in casa.ROTAS:
        ir(pag, rota)
        for rotulo in pag.eval_on_selector_all(
                "#conteudo button, #conteudo a.bt",
                "(xs) => xs.filter((x) => !['acao:instalar', 'acao:vscode_instalar_extensao'].includes(x.dataset.controle))"
                ".map((x) => x.textContent.trim())"):
            if re.match(r"^(Baixar|Instalar|Construir)\b", rotulo) and rotulo != "Baixar o tema":
                achados.append((rota, rotulo))
    prova(not achados, "nenhum botão de baixar, instalar ou construir fora o do tema (%s)" % achados)


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1829, "height": 1029})
            pag.goto(url)
            sons(pag, url)
            lancador(pag)
            mandar_e_rascunho(pag, nav, url)
            sem_baixar(pag)
            nav.close()
    finally:
        proc.terminate()
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    return 1 if FALHAS else 0


if __name__ == "__main__":
    sys.exit(main())

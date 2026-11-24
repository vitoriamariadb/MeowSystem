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
_spec = importlib.util.spec_from_file_location("app_completo", os.path.join(AQUI, "app-completo.py"))
casa = importlib.util.module_from_spec(_spec)
_argv, sys.argv = sys.argv, [os.path.join(AQUI, "app-completo.py")]
_spec.loader.exec_module(casa)
sys.argv = _argv

from playwright.sync_api import sync_playwright  # noqa: E402

falhas = []
DESLIGADOS = ("#conteudo button[disabled], #conteudo .ctl.desligado, #conteudo .linha.dominada, "
              "#conteudo [aria-disabled=true], #conteudo input[disabled], #conteudo select[disabled]")


def confere(cond, frase, detalhe=""):
    print(("ok: " if cond else "FALHOU: ") + frase + ((" — " + str(detalhe)) if detalhe and not cond else ""))
    if not cond:
        falhas.append(frase)


def esperar(pag, ms=600):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    esperar(pag, 1200)


def conf_com(**chaves):
    with open(casa.CONF, encoding="utf-8") as fh:
        texto = fh.read()
    for chave, valor in chaves.items():
        linha = f'{chave}="{valor}"'
        if re.search(rf"^{chave}=.*$", texto, flags=re.M):
            texto = re.sub(rf"^{chave}=.*$", linha, texto, flags=re.M)
        else:
            texto += "\n" + linha + "\n"
    with open(casa.CONF, "w", encoding="utf-8") as fh:
        fh.write(texto)


def esperar_conf(chave, quer, teto=20):
    import time
    fim = time.time() + teto
    while time.time() < fim:
        if casa.valor_de(chave) == quer:
            return True
        time.sleep(0.3)
    return False


MOTIVOS = ("Vale com", "Sem efeito agora", "Nada para", "Segue o horário", "Guarde o tema", "Pouco contraste",
           "Escolha um desenho", "Dê um nome", "build em curso", "não traz este som", "só vale com")


def nada_desligado(pag, onde):
    achados = pag.evaluate("(s) => [...document.querySelectorAll(s)].map((e) => e.getAttribute('data-controle') || e.className)", DESLIGADOS)
    confere(not achados, f"{onde}: nenhum controle desligado nem cinza", achados)
    dicas = pag.evaluate("(m) => [...document.querySelectorAll('#conteudo [data-dica]')].map((e) => e.dataset.dica)"
                         ".filter((d) => m.some((x) => d.includes(x)))", list(MOTIVOS))
    confere(not dicas, f"{onde}: nenhuma dica diz o porquê de um bloqueio", dicas)


def destrava(pag):
    app_id = "hefesto-dualsense4unix"
    ir(pag, "criar/icones")
    pag.wait_for_function("() => typeof APPS !== 'undefined' && APPS && !APPS.carregando", timeout=60000)
    trava = pag.evaluate("(id) => { const a = (APPS.apps || []).find((x) => x.id === id); return a ? (a.trava || a.trava_pack || '') : null; }", app_id)
    confere(bool(trava), "o Hefesto chega com trava de intocável", trava)
    pag.locator(f'button.app[data-app="{app_id}"]').click()
    pag.wait_for_selector(".desenho", timeout=60000)
    pag.locator('[data-controle="desenho:fonte=acervo"]').click()
    pag.wait_for_function("() => GLIFOS.app && !GLIFOS.carregando && GLIFOS.itens.length", timeout=60000)
    pag.wait_for_timeout(600)
    nada_desligado(pag, "Ficha de um app travado")
    desenhos = pag.locator('[data-controle="icone:desenho"]')
    confere(desenhos.count() > 0 and pag.locator('[data-controle="icone:travado"]').count() == 0,
            "o acervo do app travado aparece inteiro, como desenho normal", desenhos.count())
    desenhos.first.click()
    pag.wait_for_timeout(400)
    pag.locator('[data-controle="icone:usar"]').click()
    lista = os.path.join(os.path.dirname(casa.CONF), "icones-destravados.list")
    import time
    fim = time.time() + 30
    while time.time() < fim and not (os.path.isfile(lista) and app_id in open(lista, encoding="utf-8").read()):
        time.sleep(0.3)
    confere(os.path.isfile(lista) and app_id in open(lista, encoding="utf-8").read(),
            "o clique destrava: o app entra em icones-destravados.list")
    mapas = [os.path.join(os.path.dirname(casa.CONF), m) for m in ("icones-traco.map", "icones-escolhidos.map")]
    fim = time.time() + 30
    gravou = lambda: any(os.path.isfile(m) and app_id in open(m, encoding="utf-8").read() for m in mapas)
    while time.time() < fim and not gravou():
        time.sleep(0.3)
    confere(gravou(), "e a escolha vai para o mapa no mesmo gesto")
    pag.wait_for_function("() => !TRABALHO || !TRABALHO.timer", timeout=120000)
    pag.evaluate("() => { APPS = null; render(); }")
    pag.wait_for_function("() => APPS && !APPS.carregando", timeout=60000)
    depois = pag.evaluate("(id) => { const a = (APPS.apps || []).find((x) => x.id === id); return a ? (a.trava || a.trava_pack || '') : null; }", app_id)
    confere(not depois, "relido, o app não traz mais trava", depois)


def todas_as_paginas(pag):
    for rota in casa.ROTAS + ["novo/icones", "novo/sons", "extensoes", "extensoes/builds", "extensoes/espaco"]:
        ir(pag, rota)
        nada_desligado(pag, rota)


def mascote(pag):
    conf_com(LOGO_MODO="fixo", FASTFETCH_LOGO_MODO="espelho")
    pag.reload(wait_until="commit")
    esperar(pag, 800)
    ir(pag, "ajustes/mascote")
    nada_desligado(pag, "Mascote com «Fixo» em «O outro» e o mascote parado")
    girar = pag.locator('[data-controle="acao:logo_girar"]')
    confere(girar.count() == 1 and girar.is_enabled(), "«Girar» com o mascote fixo está acesa")
    confere(not (girar.get_attribute("data-dica") or "").startswith("Vale com"), "e a dica de «Girar» não é o motivo")
    girar.click()
    confere(esperar_conf("LOGO_MODO", "rotacao"), "clicar em «Girar» liga o modo girando", casa.valor_de("LOGO_MODO"))
    pag.locator('[data-controle="chave:FASTFETCH_LOGO_GATO=mimir"]').click()
    confere(esperar_conf("FASTFETCH_LOGO_MODO", "fixo"),
            "escolher em «Fixo» grava «Sempre o mesmo» em «Qual mascote»", casa.valor_de("FASTFETCH_LOGO_MODO"))
    conf_com(FASTFETCH_LOGO_MODO="espelho", FASTFETCH_LOGO_GATO="mimir")
    pag.reload(wait_until="commit")
    esperar(pag, 800)
    ir(pag, "ajustes/mascote")
    pag.locator('[data-controle="chave:FASTFETCH_LOGO_GATO=mimir"]').click()
    confere(esperar_conf("FASTFETCH_LOGO_MODO", "fixo"),
            "clicar de novo no mascote que já está em «Fixo» também liga «Sempre o mesmo»", casa.valor_de("FASTFETCH_LOGO_MODO"))


def areas(pag):
    ir(pag, "ajustes/janelas")
    nada_desligado(pag, "Janelas e tela")
    fixar = pag.locator('[data-controle="acao:areas_alfinetar_primeira"]')
    confere(fixar.count() == 0, "com área fixada, a linha «Fixar» some, sem ficar apagada")


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o scripts/app/run.sh não imprimiu a URL")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1574, "height": 1032})
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pag.on("dialog", lambda d: (erros.append("diálogo nativo: " + d.message), d.dismiss()))
            pag.goto(url, wait_until="commit")
            esperar(pag, 800)
            mascote(pag)
            areas(pag)
            destrava(pag)
            todas_as_paginas(pag)
            confere(not erros, "nenhum erro de página nem diálogo nativo", erros)
            nav.close()
    finally:
        proc.terminate()
        casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    if falhas:
        print(f"\n{len(falhas)} FALHOU")
        return 1
    print("\nsoberana-pagina: tudo certo")
    return 0


if __name__ == "__main__":
    sys.exit(main())

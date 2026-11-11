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

FOTOS = casa._arg("--fotos")
falhas = []
SVG_DELA = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
            '<circle cx="24" cy="24" r="20" fill="#ff0000"/></svg>')


def confere(cond, frase, detalhe=""):
    print(("ok: " if cond else "FALHOU: ") + frase + ((" — " + str(detalhe)) if detalhe and not cond else ""))
    if not cond:
        falhas.append(frase)


def foto(pag, nome):
    if FOTOS:
        os.makedirs(FOTOS, exist_ok=True)
        pag.screenshot(path=os.path.join(FOTOS, nome))


def esperar(pag, ms=600):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    esperar(pag, 1200)


def pack_dracula_no_ar():
    with open(casa.CONF, encoding="utf-8") as fh:
        texto = fh.read()
    with open(casa.CONF, "w", encoding="utf-8") as fh:
        fh.write(re.sub(r"^PACK=.*$", 'PACK="dracula"', texto, flags=re.M))


def acervo_do_arquivos(pag):
    pag.locator('button.app[data-app="com.system76.CosmicFiles"]').click()
    pag.wait_for_selector(".desenho", timeout=60000)
    pag.locator('[data-controle="desenho:fonte=acervo"]').click()
    pag.wait_for_function("() => GLIFOS.app && !GLIFOS.carregando && GLIFOS.itens.length", timeout=60000)
    pag.wait_for_timeout(800)


def p185(pag):
    ir(pag, "criar/icones")
    acervo_do_arquivos(pag)
    livres = pag.locator('[data-controle="icone:desenho"]').count()
    travados = pag.locator('[data-controle="icone:travado"]').count()
    confere(livres > 100 and travados <= 2, f"Arquivos › Do acervo: os desenhos do pack se escolhem ({livres} livres, {travados} travados)")
    abas = [t.split(" (")[0] for t in pag.locator('[data-controle^="acervo:aba="]').all_inner_texts()]
    confere(abas == ["Apps", "Sistema", "Biblioteca"], f"o acervo se divide nas três pastas do tema, como as abas ({abas})")
    confere(pag.locator(".desenho summary").count() == 0, "sem pasta com nome de acervo por cima delas")
    pag.locator('[data-controle="acervo:aba=sistema"]').click()
    pag.wait_for_timeout(600)
    confere(pag.locator('[data-acervo="sistema"] [data-controle="icone:desenho"]').count() > 50,
            "a aba Sistema do acervo mostra os ícones do sistema do tema")
    pag.locator('[data-controle="acervo:aba=apps"]').click()
    pag.wait_for_timeout(600)
    usar = pag.locator('[data-controle="icone:usar"]')
    confere(usar.count() == 1 and usar.is_visible(), "o «Usar» está sempre no cartão")
    confere(usar.get_attribute("aria-disabled") == "true", "e fica desabilitado enquanto nada foi escolhido")
    alvo = pag.locator('[data-controle="icone:desenho"]').nth(3)
    nome = alvo.get_attribute("data-dica") or alvo.inner_text()
    alvo.click()
    pag.wait_for_timeout(600)
    confere(usar.get_attribute("aria-disabled") is None, "o clique no quadro escolhe: o «Usar» habilita")
    confere(pag.locator('[data-controle="icone:desenho"]').nth(3).get_attribute("aria-pressed") == "true",
            "e o quadro escolhido fica marcado")
    foto(pag, "p185-escolhido.png")
    usar.click()
    estado = casa.fim_do_trabalho(pag)
    confere(estado == "ok", f"«Usar» termina o trabalho sem erro ({estado})")
    mapa = os.path.join(os.path.dirname(casa.CONF), "icones-escolhidos.map")
    texto = open(mapa, encoding="utf-8").read() if os.path.exists(mapa) else ""
    confere(re.search(r"^com\.system76\.CosmicFiles : .*escolhido no painel", texto, re.M) is not None,
            "o icones-escolhidos.map ganha a linha do Arquivos", texto[-200:])
    instalado = os.path.join(casa.CASA, ".local", "share", "icons", "MeowSystem-Icons", "scalable", "apps",
                             "com.system76.CosmicFiles.svg")
    confere(os.path.isfile(instalado) and "<svg" in open(instalado, encoding="utf-8").read(),
            f"e o ícone do Arquivos fica instalado no tema ({nome})")


def abrir_aba(pag, aba):
    pag.locator(f'[data-controle="icones:aba={aba}"]').click()
    pag.wait_for_function("() => ACERVO && !ACERVO.carregando && document.querySelector('[data-controle=\"trocar:desenho\"]')",
                          timeout=60000)
    pag.wait_for_timeout(600)


def abrir_ficha(pag, nome):
    pag.locator(f'[data-controle="trocar:desenho"][data-nome="{nome}"]').first.click()
    pag.wait_for_selector(f'[data-trocar="{nome}"]', timeout=30000)


def esperar_trocado(pag):
    pag.wait_for_function("() => [...document.querySelectorAll('#torradas .torrada')].some((t) => t.textContent.includes('trocado'))"
                          " && !document.querySelector('[data-trocar]') && ACERVO && !ACERVO.carregando", timeout=30000)
    pag.evaluate("() => { for (const t of document.querySelectorAll('#torradas .torrada')) t.remove(); }")
    pag.wait_for_timeout(600)


def p186(pag, svg):
    ir(pag, "criar/icones")
    dracula = os.path.join(casa.RAIZ_B, "packs", "dracula", "icones")
    for aba, alvo, origem, arquivo in (
            ("sistema", "connection-secure-symbolic", "airplane-mode-symbolic", "channel-secure-symbolic.svg"),
            ("biblioteca", None, None, None)):
        abrir_aba(pag, aba)
        cartoes = pag.locator('[data-controle="trocar:desenho"]:not([disabled])')
        confere(cartoes.count() > 0, f"{aba}: cada cartão livre é um botão que troca o ícone ({cartoes.count()})")
        if alvo is None:
            alvo = cartoes.nth(0).get_attribute("data-nome")
            origem = cartoes.nth(5).get_attribute("data-nome")
            arquivo = alvo + ".svg"
        de_origem = open(os.path.join(dracula, aba, origem + ".svg"), encoding="utf-8").read()
        antes = open(os.path.join(dracula, aba, arquivo), encoding="utf-8").read()
        cartao = f'[data-controle="trocar:desenho"][data-nome="{alvo}"] img'
        src_antes = pag.locator(cartao).first.get_attribute("src")
        abrir_ficha(pag, alvo)
        usar = pag.locator('[data-controle="trocar:usar"]')
        confere(usar.get_attribute("aria-disabled") == "true", f"{aba}: a ficha abre com o «Usar» à vista, desabilitado")
        pag.locator(f'[data-controle="trocar:opcao"][data-nome="{origem}"]').first.click()
        confere(usar.get_attribute("aria-disabled") is None
                and pag.locator(f'[data-controle="trocar:opcao"][data-nome="{origem}"]').first.get_attribute("aria-pressed") == "true",
                f"{aba}: um clique num desenho do acervo escolhe e habilita o «Usar»")
        confere(pag.locator(f'[data-controle="trocar:aba={aba}"]').get_attribute("aria-pressed") == "true",
                f"{aba}: escolher um desenho não apaga a aba marcada da ficha")
        foto(pag, f"p186-{aba}-acervo.png")
        usar.click()
        esperar_trocado(pag)
        depois = open(os.path.join(dracula, aba, arquivo), encoding="utf-8").read()
        confere(depois == de_origem and depois != antes,
                f"{aba}: o desenho {origem} do acervo vira o {arquivo} que o tema usa para {alvo}")
        abrir_ficha(pag, alvo)
        with pag.expect_file_chooser() as escolha:
            pag.locator('[data-controle="trocar:svg"]').click()
        escolha.value.set_files(svg)
        esperar_trocado(pag)
        confere("#ff0000" in open(os.path.join(dracula, aba, arquivo), encoding="utf-8").read(),
                f"{aba}: o «Trazer .svg» da ficha grava o SVG dela no mesmo {arquivo}")
        confere(pag.locator(cartao).first.get_attribute("src") != src_antes, f"{aba}: o cartão passa a mostrar o desenho novo")
        foto(pag, f"p186-{aba}.png")
    abrir_aba(pag, "sistema")
    alvo, arquivo = "connection-secure-symbolic", "channel-secure-symbolic.svg"
    abrir_ficha(pag, alvo)
    rolagens = pag.evaluate("() => [...document.querySelectorAll('#desenho .tira-glifos, #desenho .grade-glifos')]"
                            ".filter((e) => ['auto', 'scroll'].includes(getComputedStyle(e).overflowY)).length")
    confere(rolagens == 0, "a ficha tem uma rolagem só: a lista de desenhos não rola dentro de outra rolagem", str(rolagens))
    da_biblioteca = pag.locator('[data-controle="trocar:aba=biblioteca"]')
    confere(da_biblioteca.count() == 1, "a ficha de um ícone do Sistema oferece os desenhos da Biblioteca")
    confere(pag.locator("#desenho summary").count() == 0, "sem pasta que abre e fecha: as duas abas mostram tudo")
    da_biblioteca.click()
    pag.wait_for_timeout(600)
    opcao = pag.locator('[data-controle="trocar:opcao"][data-pasta="biblioteca"]').first
    origem = opcao.get_attribute("data-nome")
    de_origem = open(os.path.join(dracula, "biblioteca", origem + ".svg"), encoding="utf-8").read()
    opcao.click()
    pag.locator('[data-controle="trocar:usar"]').click()
    esperar_trocado(pag)
    confere(open(os.path.join(dracula, "sistema", arquivo), encoding="utf-8").read() == de_origem,
            f"um desenho da Biblioteca ({origem}) vira o ícone do Sistema {alvo}")
    foto(pag, "sistema-da-biblioteca.png")
    herdado = pag.locator('[data-controle="trocar:desenho"][data-nome="application-certificate"]').first
    confere(herdado.is_disabled() and "MeowSystem" in (herdado.get_attribute("data-dica") or ""),
            "um ícone que o tema herda de outro não finge: fica desabilitado e a dica diz de quem é",
            herdado.get_attribute("data-dica"))
    ir(pag, "novo/icones")
    pag.locator('[data-controle="icones:aba=sistema"]').click()
    pag.wait_for_timeout(1500)
    sem = pag.locator('[data-controle="trocar:desenho"]').first
    confere(sem.get_attribute("aria-disabled") == "true" and sem.is_disabled(),
            "num tema ainda não guardado, o cartão não finge: fica desabilitado com o motivo na dica")


def p187(pag):
    ir(pag, "criar/sons")
    confere(pag.locator('[data-controle="acao:som_ouvir"]').count() == 0 and "Ouvir o instalado" not in pag.inner_text("#conteudo"),
            "a linha «Ouvir o instalado» saiu da tela")
    tipos = pag.evaluate("""async () => {
      const saida = {};
      for (const s of SONS.eventos.filter((x) => x.origem === 'pack')) {
        const r = await fetch(`/som?pack=${SONS.pack}&evento=${s.evento}`);
        saida[s.evento] = [r.status, r.headers.get('content-type'), (await r.arrayBuffer()).byteLength];
      }
      return saida;
    }""")
    ruins = {e: v for e, v in tipos.items() if v[0] != 200 or v[1] != "audio/ogg" or v[2] < 100}
    confere(len(tipos) >= 10 and not ruins, f"o /som devolve audio/ogg para cada um dos {len(tipos)} eventos do pack", ruins)
    pag.evaluate("""() => { window.__audio = []; const O = window.Audio;
      window.Audio = function (u) { const a = new O(u);
        for (const ev of ['playing', 'ended', 'error']) a.addEventListener(ev, () => window.__audio.push(ev));
        return a; }; }""")
    botao = pag.locator('[data-controle="som:ouvir"]:not([disabled])').first
    botao.click()
    pag.wait_for_timeout(300)
    confere(botao.get_attribute("data-tocando") is not None, "enquanto toca, o botão do evento mostra o estado «tocando»")
    pag.wait_for_function("() => window.__audio.includes('ended')", timeout=20000)
    confere("error" not in pag.evaluate("() => window.__audio") and botao.get_attribute("data-tocando") is None,
            "o som termina com ended e o botão volta ao parado")
    confere(not pag.evaluate("() => !!document.querySelector('dialog[open]')"),
            "tocar não abre diálogo")
    pag.evaluate("() => { const O = window.Audio; window.Audio = function (u) { return new O('/som?pack=dracula&evento=nao-existe'); }; }")
    pag.locator('[data-controle="som:ouvir"]:not([disabled])').nth(1).click()
    pag.wait_for_selector("#torradas .torrada.erro", timeout=10000)
    confere(True, "som que falha vira aviso curto, sem ficar mudo")


def p188(pag):
    ir(pag, "criar/sons")
    nomes_do_grupo = pag.evaluate("() => [...document.querySelectorAll('#conteudo h2')].map((h) => h.textContent.trim())")
    confere("Nativo do COSMIC" in nomes_do_grupo and not any("Toca no" in n for n in nomes_do_grupo),
            f"o grupo se chama «Nativo do COSMIC» e «Toca no» não aparece ({nomes_do_grupo})")
    confere(pag.locator('[data-controle="acao:som_aplicar"]').count() == 0, "a linha «Regravar o som» saiu")
    destino = pag.locator('[data-controle="sino:evento"]')
    confere(destino.input_value() == "audio-volume-change", "o destino padrão do sino é o volume")
    gravar = pag.locator('[data-controle="sino:gravar"]')
    confere(gravar.get_attribute("aria-disabled") == "true", "sem nome, «Gerar Sons» fica desabilitado")
    pag.locator('[data-controle="sino:nome"]').fill("Sino da Vitória")
    confere(gravar.get_attribute("aria-disabled") == "false", "com nome, «Gerar Sons» habilita")
    destino.select_option("message-new-instant")
    arq = os.path.join(casa.RAIZ_B, "packs", "dracula", "sons", "stereo", "notification", "message-new-instant.oga")
    antes = open(arq, "rb").read()
    gravar.click()
    pag.wait_for_selector("#torradas .torrada.ok", timeout=60000)
    pag.wait_for_timeout(1500)
    depois = open(arq, "rb").read()
    confere(depois.startswith(b"OggS") and depois != antes, "o sino vira sons/stereo/notification/message-new-instant.oga, em Ogg")
    nomes = os.path.join(casa.RAIZ_B, "packs", "dracula", "sons", "nomes.json")
    confere(os.path.isfile(nomes) and "Sino da Vitória" in open(nomes, encoding="utf-8").read(), "e o nome escolhido fica no pack")
    linha = pag.locator('li[data-som="message-new-instant"]')
    confere("Sino da Vitória" in linha.inner_text() and "Do pack" in linha.inner_text(),
            "a linha do evento mostra o nome e «Do pack»", linha.inner_text())
    foto(pag, "p188-sino.png")
    estado = casa.fim_do_trabalho(pag)
    temas = os.path.join(casa.CASA, ".local", "share", "sounds", "MeowSystem-Sons", "stereo")
    na_maquina = os.path.join(temas, "notification", "message-new-instant.oga")
    confere(estado == "ok" and os.path.isfile(na_maquina) and open(na_maquina, "rb").read() == depois,
            f"no Personalizar, o som gravado já entra na máquina, sem outro gesto ({estado})")
    alvo = os.path.join(casa.RAIZ_B, "packs", "dracula", "sons", "stereo", "notification", "complete.oga")
    novo = os.path.join(casa.BRINQUEDO, "meu-aviso.oga")
    with open(novo, "wb") as fh:
        fh.write(depois)
    with pag.expect_file_chooser() as escolha:
        pag.locator('li[data-som="complete"] [data-controle="som:trocar"]').click()
    escolha.value.set_files(novo)
    pag.wait_for_function("() => [...document.querySelectorAll('#torradas .torrada')].some((t) => t.textContent.includes('trocado'))", timeout=30000)
    estado = casa.fim_do_trabalho(pag)
    na_maquina = os.path.join(temas, "notification", "complete.oga")
    confere(estado == "ok" and open(alvo, "rb").read() == depois and os.path.isfile(na_maquina)
            and open(na_maquina, "rb").read() == depois,
            f"e o «Trocar» de um som também: o pack e a máquina ficam com o som novo ({estado})")


def main():
    ambiente = casa.montar_casa()
    pack_dracula_no_ar()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o app/run.sh não imprimiu a URL")
        return 2
    svg = os.path.join(casa.BRINQUEDO, "dela.svg")
    with open(svg, "w", encoding="utf-8") as fh:
        fh.write(SVG_DELA)
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1574, "height": 1032})
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pag.on("dialog", lambda d: (erros.append("diálogo nativo: " + d.message), d.dismiss()))
            pag.goto(url, wait_until="commit")
            esperar(pag, 800)
            p185(pag)
            p186(pag, svg)
            p187(pag)
            p188(pag)
            confere(not erros, "nenhum erro de página nem diálogo nativo", erros)
            nav.close()
    finally:
        proc.terminate()
        casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    if falhas:
        print(f"\n{len(falhas)} FALHOU")
        return 1
    print("\npersonalizar-pagina: tudo certo")
    return 0


if __name__ == "__main__":
    sys.exit(main())

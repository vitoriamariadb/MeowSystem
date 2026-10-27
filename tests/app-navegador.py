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
conferidas = [0]


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


def esperar(pag, ms=600):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    esperar(pag)


def foto(pag, nome):
    if FOTOS:
        os.makedirs(FOTOS, exist_ok=True)
        pag.screenshot(path=os.path.join(FOTOS, nome + ".png"))


def janela(pag, teto=60000):
    try:
        pag.wait_for_function("() => document.getElementById('resultado').open", timeout=teto)
        return True
    except Exception:
        return False


def parar_e_fechar(pag):
    if pag.evaluate("() => document.getElementById('resultado').open"):
        if pag.locator("#parar").is_visible():
            pag.locator("#parar").click()
        pag.wait_for_function("() => document.getElementById('parar').hidden", timeout=120000)
        pag.locator("#resultado-ok").click()
        pag.wait_for_timeout(300)


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            contexto = nav.new_context(viewport={"width": 1829, "height": 1029}, accept_downloads=True)
            pag = contexto.new_page()
            posts = []
            pag.on("request", lambda r: posts.append((r.url.rsplit("/", 1)[-1], r.post_data or ""))
                   if r.method == "POST" else None)
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pag.goto(url)
            esperar(pag, 1000)

            print("1. a variante do tema no ar veste na hora")
            no_ar = pag.evaluate("() => (PACKS.find((p) => p.no_ar) || {}).id")
            outra = pag.evaluate("() => { const p = PACKS.find((x) => x.no_ar);"
                                 " return (p.flavors.find((f) => f.id !== flavorEmVigor()) || {}).id; }")
            n0 = len(posts)
            pag.locator(f'[data-controle="pack:{no_ar}:variante={outra}"]').click()
            pag.wait_for_function("() => EM_VOO === 0 && !ACOMPANHANDO", timeout=240000)
            checa(not pag.evaluate("() => document.getElementById('pergunta').open"), "sem pergunta nenhuma")
            definir = [c for u, c in posts[n0:] if u == "definir"]
            checa(definir and f'"valor": "{outra}"' in definir[0].replace('":"', '": "') and "FLAVOR" in definir[0],
                  f"o /api/definir leva FLAVOR={outra} ({definir[:1]})")
            checa(not pag.evaluate("() => document.getElementById('resultado').open"), "e nenhuma janela de trabalho abre")
            foto(pag, "1-vestir")
            checa(casa.valor_de("FLAVOR") == outra, f"o meow.conf diz FLAVOR={outra}")
            checa(pag.evaluate("() => HISTORICO.length") == 1, "e a variante entra na barra para desfazer")

            print("2. o outro tema, sem a ponte")
            outro_pack = pag.evaluate("() => (PACKS.find((p) => !p.no_ar) || {}).id")
            pag.locator(f'[data-controle="pack:{outro_pack}:vestir"]').click()
            pag.wait_for_timeout(500)
            titulo = pag.evaluate("() => document.getElementById('pergunta').open && document.getElementById('pergunta-titulo').textContent")
            checa(titulo == "Falta a ponte", f"vestir o {outro_pack} sem a ponte mostra «Falta a ponte» ({titulo!r})")
            checa(pag.locator("#pergunta-sim").inner_text() == "Consertar a ponte", "com o «Consertar a ponte»")
            checa(pag.locator("input[type=password]").count() == 0, "e nenhum campo de senha")
            foto(pag, "2-ponte")
            pag.locator("#pergunta-nao").click()

            print("3. um ajuste que grava ao soltar, a barra e o padrão")
            ir(pag, "ajustes/painel")
            antes = casa.valor_de("FORMA_DOCK_SOLTO")
            n_antes = pag.evaluate("() => HISTORICO.length")
            pag.locator('[data-controle="chave:FORMA_DOCK_SOLTO"]').click()
            pag.wait_for_function("() => EM_VOO === 0 && !ACOMPANHANDO", timeout=240000)
            depois = casa.valor_de("FORMA_DOCK_SOLTO")
            checa(depois != antes and depois in ("sim", "nao"), f"o clique grava a chave sem Aplicar ({antes} -> {depois})")
            checa(pag.locator("#conta").inner_text() == f"{n_antes + 1} mudanças", f"a conta diz «{n_antes + 1} mudanças» ({pag.locator('#conta').inner_text()!r})")
            checa(pag.locator("#bt-aplicar").count() == 0 and pag.locator("#botao-ensaiar").count() == 0, "a barra não tem Aplicar nem Ver sem mudar")
            checa(pag.locator('.linha.mudou[data-linha~="FORMA_DOCK_SOLTO"]').count() == 1, "a linha se marca")
            checa(pag.locator("#conteudo .previa .p-dock.mudou-aqui").count() == 1, "e a dock da prévia ganha o tracejado")
            foto(pag, "3-mudanca")
            padrao = pag.locator('[data-controle="padrao:FORMA_DOCK_SOLTO"]')
            if checa(padrao.count() == 1, "fora do padrão, nasce o «Voltar ao padrão»"):
                padrao.click()
                pag.wait_for_function("() => EM_VOO === 0 && !ACOMPANHANDO", timeout=240000)
                checa(pag.locator('[data-controle="padrao:FORMA_DOCK_SOLTO"]').count() == 0,
                      "e ele some quando a escolha volta ao de fábrica")
                pag.locator("#desfazer").click()

            print("4. nenhuma dobra: o que era «Mais ajustes» aparece direto")
            for rota in ("tema", "criar/cores", "criar/icones", "criar/papel", "criar/sons", "criar/mandar",
                         "ajustes/painel", "ajustes/janelas", "ajustes/papel", "ajustes/mascote",
                         "ajustes/dia-e-noite", "ajustes/terminal", "ajustes/programas", "cuidar"):
                ir(pag, rota)
                checa(pag.evaluate("() => document.querySelectorAll('details.mais').length") == 0
                      and pag.evaluate("() => !/Mais ajustes/.test(document.getElementById('conteudo').innerText)"),
                      f"sem dobra em {rota}")

            print("5. a busca")
            pag.keyboard.press("/")
            pag.keyboard.type("ponteiro")
            pag.wait_for_timeout(300)
            achado = pag.locator("#achados button").first
            checa(achado.count() == 1 and "Ponteiro" in achado.inner_text(), "a busca acha «Ponteiro»")
            achado.click()
            pag.wait_for_timeout(600)
            checa(pag.evaluate("() => location.hash") == "#ajustes/janelas", "e leva a Janelas e tela")
            checa(pag.locator('#conteudo .chegou[data-linha~="CURSOR"]').count() == 1, "acendendo a linha do ponteiro")

            print("6. Personalizar")
            ir(pag, "criar/cores")
            antes = pag.locator("#conteudo .poco code").first.inner_text()
            alvo = pag.locator('[data-controle^="criar:comeca="][aria-pressed="false"]').first
            alvo.click()
            pag.wait_for_timeout(300)
            checa(pag.locator("#conteudo .poco code").first.inner_text() != antes, "começar de outro flavor troca o fundo")
            nome = pag.locator('[data-controle="criar:nome"]')
            nome.fill("Navegador de Brinquedo")
            nome.press("Tab")
            pag.wait_for_timeout(200)
            pag.locator('[data-controle="criar:guardar"]').click()
            pag.wait_for_timeout(4000)
            pasta = os.path.join(casa.CASA, ".local", "share", "meowsystem", "packs", "navegador-de-brinquedo")
            dirs = sorted(os.listdir(os.path.join(pasta, "icones"))) if os.path.isdir(os.path.join(pasta, "icones")) else []
            checa(dirs == ["apps", "biblioteca", "sistema"], f"«Guardar» grava o pack de três pastas ({dirs})")
            ir(pag, "criar/mandar")
            foto(pag, "6-mandar")
            with pag.expect_download(timeout=60000) as baixa:
                pag.locator('[data-controle="criar:baixar"]').click()
                pag.wait_for_timeout(500)
                if pag.evaluate("() => document.getElementById('pergunta').open"):
                    pag.locator("#pergunta-sim").click()
            checa(baixa.value.suggested_filename.endswith(".meowpack"), f"«Baixar o tema» baixa {baixa.value.suggested_filename}")

            print("7. Manter: levar e trazer os ajustes")
            ir(pag, "cuidar")
            with pag.expect_download(timeout=30000) as baixa:
                pag.locator('[data-controle="cuidar:exportar"]').click()
            texto = open(baixa.value.path(), encoding="utf-8").read()
            checa("RELOGIO_SEGUNDOS=" in texto, "«Guardar ajustes» baixa o .conf com as chaves")
            caminho = os.path.join(casa.BRINQUEDO, "trazer.conf")
            with open(caminho, "w", encoding="utf-8") as fh:
                fh.write('LOG_NIVEL="debug"\n')
            with pag.expect_file_chooser() as escolha:
                pag.locator('[data-controle="cuidar:importar"]').click()
            escolha.value.set_files(caminho)
            pag.wait_for_timeout(800)
            pag.wait_for_function("() => EM_VOO === 0 && !ACOMPANHANDO", timeout=240000)
            checa(casa.valor_de("LOG_NIVEL") == "debug", "«Trazer ajustes» grava na hora")
            pag.locator("#desfazer").click()
            pag.wait_for_timeout(800)
            pag.wait_for_function("() => EM_VOO === 0 && !ACOMPANHANDO", timeout=240000)

            print("8. a dica")
            ir(pag, "cuidar")
            alvo = pag.locator('#conteudo .linha .rot span[data-dica]').first
            alvo.scroll_into_view_if_needed()
            pag.wait_for_timeout(300)
            alvo.hover()
            pag.wait_for_timeout(300)
            checa(pag.evaluate("() => document.getElementById('dica').hidden"), "a dica espera o mouse parar")
            pag.wait_for_timeout(900)
            dica = pag.evaluate("() => document.getElementById('dica').textContent")
            checa(not pag.evaluate("() => document.getElementById('dica').hidden") and dica[:1].isupper(),
                  f"e aparece, com maiúscula ({dica[:50]!r})")
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
    print(f"ok: {conferidas[0]} conferências do painel usado como quem usa")
    return 0


if __name__ == "__main__":
    sys.exit(main())

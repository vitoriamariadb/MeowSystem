#!/usr/bin/env python3
import importlib.util
import json
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
PACKS_DELA = os.path.join(casa.CASA, ".local", "share", "meowsystem", "packs")


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


def foto(pag, nome):
    if FOTOS:
        os.makedirs(FOTOS, exist_ok=True)
        pag.screenshot(path=os.path.join(FOTOS, nome + ".png"), full_page=True)


def esperar(pag, ms=600):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    esperar(pag)


def esperar_que(pag, cond, teto=60000):
    passos = teto // 250
    for _ in range(passos):
        if cond():
            return True
        pag.wait_for_timeout(250)
    return cond()


def packs_dela():
    return sorted(os.listdir(PACKS_DELA)) if os.path.isdir(PACKS_DELA) else []


def tom(arq, flavor, papel):
    try:
        with open(arq, encoding="utf-8") as fh:
            return json.load(fh)["flavors"][flavor][papel].upper()
    except (OSError, ValueError, KeyError):
        return None


def trocar_cor(pag, papel, valor):
    pag.evaluate("""([p, v]) => { const e = document.querySelector(`[data-controle="criar:cor=${p}"]`);
      e.value = v; e.dispatchEvent(new Event('change', { bubbles: true })); }""", [papel, valor])
    pag.wait_for_timeout(400)


def definir_pack(ident):
    with open(casa.CONF, encoding="utf-8") as fh:
        texto = fh.read()
    with open(casa.CONF, "w", encoding="utf-8") as fh:
        fh.write(re.sub(r'^PACK="[^"]*"', 'PACK="%s"' % ident, texto, count=1, flags=re.M))


def abrir(nav, url):
    pag = nav.new_context(viewport={"width": 1550, "height": 900}, accept_downloads=True).new_page()
    erros = []
    pag.on("pageerror", lambda e: erros.append(str(e)))
    pag.goto(url)
    esperar(pag, 800)
    return pag, erros


def com_checkout(nav, url):
    pag, erros = abrir(nav, url)

    print("== Tema novo: guarda um tema novo, com as fotos dele, e baixa o .meowpack")
    ir(pag, "novo/cores")
    titulo = pag.evaluate("() => document.querySelector('#conteudo h1').textContent")
    checa(titulo == "Tema novo", f"o título diz o que sai da página ({titulo!r})")
    pag.fill('[data-controle="criar:nome"]', "Gato Novo")
    pag.press('[data-controle="criar:nome"]', "Tab")
    pag.wait_for_timeout(400)
    pag.click('[data-controle="criar:guardar"]')
    novo = os.path.join(PACKS_DELA, "gato-novo")
    checa(esperar_que(pag, lambda: os.path.isfile(os.path.join(novo, "paleta.json"))),
          "«Guardar» do Tema novo grava um tema novo em ~/.local/share/meowsystem/packs/gato-novo")
    foto(pag, "novo-cores")
    ir(pag, "novo/papel")
    pag.wait_for_selector('[data-controle="acervo:parede"]:not([disabled])', timeout=30000)
    imagem = os.path.join(casa.BRINQUEDO, "foto-do-designer.png")
    casa.png_liso(imagem, (0x40, 0x20, 0x60))
    with pag.expect_file_chooser(timeout=15000) as escolha:
        pag.click('[data-controle="acervo:parede"]')
    escolha.value.set_files(imagem)
    fotos = os.path.join(novo, "wallpapers")
    checa(esperar_que(pag, lambda: os.path.isdir(fotos) and len(os.listdir(fotos)) == 1),
          f"«Trazer imagens» grava a foto no tema novo ({os.listdir(fotos) if os.path.isdir(fotos) else []})")
    pag.wait_for_function("() => document.querySelectorAll('.galeria figure').length === 1", timeout=30000)
    g = pag.evaluate("() => ({ n: document.querySelectorAll('.galeria figure').length,"
                     " abas: document.querySelectorAll('[data-controle^=\"galeria:\"]').length })")
    checa(g == {"n": 1, "abas": 0}, f"a galeria mostra só a foto do tema novo, sem o carrossel dela ({g})")
    foto(pag, "novo-papel")
    ir(pag, "novo/mandar")
    with pag.expect_download(timeout=60000) as baixa:
        pag.click('[data-controle="criar:baixar"]')
        pag.wait_for_timeout(600)
        if pag.evaluate("() => document.getElementById('pergunta').open"):
            pag.click("#pergunta-sim")
    caminho = baixa.value.path()
    with open(caminho, "rb") as fh:
        cabeca = fh.read(4)
    checa(baixa.value.suggested_filename.endswith(".meowpack") and cabeca == bytes([0x28, 0xB5, 0x2F, 0xFD]),
          f"«Baixar o tema» devolve um .meowpack ({baixa.value.suggested_filename})")
    foto(pag, "novo-mandar")
    rascunho_novo = pag.evaluate("() => JSON.parse(JSON.stringify(rascunho()))")

    print("== Personalizar: aprimora o tema de fábrica no ar, gravando no checkout")
    ir(pag, "criar/cores")
    no_ar = pag.evaluate("() => ({ id: packNoAr().id, nome: packNoAr().nome, flavor: rascunho().base.flavor })")
    titulo = pag.evaluate("() => document.querySelector('#conteudo h1').textContent")
    checa(titulo == "Editar " + no_ar["nome"], f"o título diz o que sai da página ({titulo!r})")
    r = pag.evaluate("() => rascunho()")
    checa(r["pack"] == no_ar["id"] and r["nome"] == no_ar["nome"], f"o Personalizar abre com o tema no ar ({r['pack']})")
    paleta = os.path.join(casa.RAIZ_B, "packs", no_ar["id"], "paleta.json")
    antes = packs_dela()
    trocar_cor(pag, "mauve", "#123456")
    pag.click('[data-controle="criar:guardar"]')
    checa(esperar_que(pag, lambda: tom(paleta, no_ar["flavor"], "mauve") == "#123456"),
          f"«Guardar» grava a cor em packs/{no_ar['id']}/paleta.json do checkout")
    checa(packs_dela() == antes, f"nenhum tema novo aparece ({packs_dela()})")
    ultima = pag.evaluate("() => document.querySelector('[data-controle=\"passo:mandar\"]').textContent")
    checa(ultima.endswith("Salvar no tema"), f"o último passo é «Salvar no tema» ({ultima!r})")
    foto(pag, "aprimorar-cores")

    print("== os dois rascunhos não se misturam")
    trocar_cor(pag, "green", "#11AA22")
    ir(pag, "novo/cores")
    r_novo = pag.evaluate("() => JSON.parse(JSON.stringify(rascunho()))")
    checa(r_novo == rascunho_novo, f"o rascunho do Tema novo seguiu igual ({r_novo.get('nome')}, {r_novo.get('pack')}, {r_novo.get('cores')})")
    guardados = pag.evaluate("() => [localStorage.getItem('meow-criar'), localStorage.getItem('meow-aprimorar')].map((x) => JSON.parse(x || 'null'))")
    checa(guardados[0]["pack"] == "gato-novo" and guardados[1]["pack"] == no_ar["id"]
          and guardados[1]["cores"].get("green") == "#11AA22" and "green" not in (guardados[0]["cores"] or {}),
          "cada um tem a sua guarda no navegador")
    pag.evaluate("() => Promise.all([enviarRascunho('novo'), enviarRascunho('aprimorar')])")
    pag.wait_for_timeout(500)
    with open(os.path.join(casa.ESTADO, "rascunho-do-tema.json"), encoding="utf-8") as fh:
        s_novo = json.load(fh)
    with open(os.path.join(casa.ESTADO, "rascunho-do-aprimorar.json"), encoding="utf-8") as fh:
        s_apr = json.load(fh)
    checa(s_novo["pack"] == "gato-novo" and s_apr["pack"] == no_ar["id"],
          "e a sua no servidor (rascunho-do-tema.json e rascunho-do-aprimorar.json)")

    print("== Personalizar num tema seu: grava nele mesmo")
    definir_pack("gato-novo")
    pag.goto(pag.url.split("#")[0])
    esperar(pag, 800)
    ir(pag, "criar/cores")
    meu = pag.evaluate("() => ({ id: rascunho().pack, flavor: rascunho().base.flavor, h1: document.querySelector('#conteudo h1').textContent })")
    checa(meu["id"] == "gato-novo" and meu["h1"] == "Editar Gato Novo", f"abre com o tema dela no ar ({meu})")
    antes = packs_dela()
    trocar_cor(pag, "mauve", "#654321")
    pag.click('[data-controle="criar:guardar"]')
    checa(esperar_que(pag, lambda: tom(os.path.join(novo, "paleta.json"), meu["flavor"], "mauve") == "#654321"),
          "«Guardar» grava a cor no próprio tema dela")
    checa(packs_dela() == antes, f"nenhum tema novo aparece ({packs_dela()})")
    fabrica = os.path.join(casa.RAIZ_B, "packs", no_ar["id"], "paleta.json")
    tom_fabrica = tom(fabrica, no_ar["flavor"], "mauve")
    papeis_fabrica = os.path.join(casa.RAIZ_B, "packs", no_ar["id"], "wallpapers")
    papeis_antes = sorted(os.listdir(papeis_fabrica)) if os.path.isdir(papeis_fabrica) else []
    resp = pag.evaluate("([id, f]) => api('/api/pack-cores', { method: 'POST', body: JSON.stringify({ id, flavor: f, cores: { mauve: '#0D0E0F' } }) })",
                        [no_ar["id"], no_ar["flavor"]])
    foto_fora = pag.evaluate("(id) => api('/api/criar', { method: 'POST', body: JSON.stringify({ id, tipo: 'foto', nome: 'x.png', levar: true,"
                             " aprimorar: true, arquivo: 'x.png', conteudo: 'iVBORw0KGgo=' }) })", no_ar["id"])
    checa(resp.get("erro") and foto_fora.get("erro") and tom(fabrica, no_ar["flavor"], "mauve") == tom_fabrica
          and (sorted(os.listdir(papeis_fabrica)) if os.path.isdir(papeis_fabrica) else []) == papeis_antes,
          f"com outro tema no ar, o servidor não grava em {no_ar['id']} ({resp}, {foto_fora})")
    definir_pack("")
    checa(not erros, f"nenhum erro de JavaScript ({erros[:2]})")


def sem_checkout(nav, url):
    pag, erros = abrir(nav, url)
    print("== sem .git na raiz, o tema de fábrica não se aprimora, e o botão diz o porquê")
    ir(pag, "criar/cores")
    no_ar = pag.evaluate("() => ({ id: packNoAr().id, flavor: rascunho().base.flavor })")
    paleta = os.path.join(casa.RAIZ_B, "packs", no_ar["id"], "paleta.json")
    tom_antes = tom(paleta, no_ar["flavor"], "mauve")
    trocar_cor(pag, "mauve", "#0A0B0C")
    b = pag.locator('[data-controle="criar:guardar"]')
    checa(b.get_attribute("aria-disabled") == "true" and "checkout" in (b.get_attribute("data-dica") or ""),
          f"«Guardar» apagado, com o porquê na dica ({b.get_attribute('data-dica')!r})")
    foto(pag, "aprimorar-sem-checkout")
    ir(pag, "criar/mandar")
    a = pag.locator('[data-controle="criar:aprimorar"]')
    checa(a.get_attribute("aria-disabled") == "true" and "checkout" in (a.get_attribute("data-dica") or ""),
          f"«Salvar no tema» apagado, com o porquê na dica ({a.get_attribute('data-dica')!r})")
    resp = pag.evaluate("([id, f]) => api('/api/pack-cores', { method: 'POST', body: JSON.stringify({ id, flavor: f, cores: { mauve: '#0A0B0C' } }) })",
                        [no_ar["id"], no_ar["flavor"]])
    checa("checkout" in (resp.get("erro") or "") and tom(paleta, no_ar["flavor"], "mauve") == tom_antes,
          f"o servidor recusa com o porquê e a paleta fica ({resp})")
    checa(not erros, f"nenhum erro de JavaScript ({erros[:2]})")


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            com_checkout(nav, url)
            proc.terminate()
            casa.encerrar_a_casa()
            os.rename(os.path.join(casa.RAIZ_B, ".git"), os.path.join(casa.BRINQUEDO, "git-de-lado"))
            proc, url = casa.sobe_servidor(ambiente)
            if checa(bool(url), "o painel sobe de uma raiz sem .git"):
                sem_checkout(nav, url)
            nav.close()
    finally:
        proc.terminate()
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    if falhas:
        print(f"FALHOU: {len(falhas)} de {conferidas[0]}")
        return 1
    print(f"ok: {conferidas[0]} conferências do Tema novo e do Personalizar")
    return 0


if __name__ == "__main__":
    sys.exit(main())

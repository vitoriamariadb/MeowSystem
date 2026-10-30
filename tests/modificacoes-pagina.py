#!/usr/bin/env python3
import importlib.util
import os
import shutil
import sys
import time

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
ENFEITE = os.path.join(casa.CASA, ".config", "enfeite", "tema.conf")
TEMAS = os.path.join(casa.CASA, ".local", "share", "meowsystem", "temas-de-apps", "enfeite")
MODULO_ENFEITE = """#!/usr/bin/env bash
_en_arq() { printf '%s/enfeite/tema.conf' "${XDG_CONFIG_HOME:-$HOME/.config}"; }
meow_app_instalado() { return 0; }
meow_app_detectar() {
  meow_app_tema_do_pack enfeite.arquivo || true
  if [ -n "$MEOW_APP_TEMA" ] && [ -f "$MEOW_APP_TEMA" ]; then _EN_QUERO="$(cat "$MEOW_APP_TEMA")"; else _EN_QUERO="cor=do-pack"; fi
}
meow_app_conferir() { meow_app_detectar; [ "$(cat "$(_en_arq)" 2>/dev/null)" = "$_EN_QUERO" ]; }
meow_app_aplicar() {
  meow_app_conferir && return 0
  local a; a="$(_en_arq)"; mkdir -p "${a%/*}"
  if [ -e "$a" ] && [ ! -e "$a.antes" ]; then cp "$a" "$a.antes"; fi
  printf '%s\\n' "$_EN_QUERO" > "$a"; return 1
}
meow_app_reverter() {
  local a; a="$(_en_arq)"
  if [ -e "$a.antes" ]; then mv "$a.antes" "$a"; return 1; fi
  [ -e "$a" ] || return 0
  rm -f "$a"; return 1
}
"""


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


def eventual(fn, seg=30):
    fim = time.time() + seg
    while time.time() < fim:
        try:
            if fn():
                return True
        except Exception:
            pass
        time.sleep(0.3)
    return False


def ler(cam):
    try:
        with open(cam, encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return None


def ativos():
    return [s.strip() for s in (casa.valor_de("APPS_ATIVOS") or "").split(",") if s.strip()]


def montar():
    ambiente = casa.montar_casa()
    pasta = os.path.join(casa.RAIZ_B, "scripts", "temas-de-apps", "enfeite")
    os.makedirs(pasta)
    casa.escrever_exec(os.path.join(pasta, "manifesto.sh"), MODULO_ENFEITE)
    with open(os.path.join(casa.RAIZ_B, "assets", "contratos", "modificacoes.tsv"), "a", encoding="utf-8") as fh:
        fh.write("enfeite\taceita\t.conf\n")
    os.makedirs(os.path.dirname(ENFEITE))
    with open(ENFEITE, "w", encoding="utf-8") as fh:
        fh.write("cor=minha\n")
    return ambiente


def esperar(pag, ms=400):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def quieto(pag):
    pag.wait_for_function("() => !EM_VOO && !ACOMPANHANDO && (!TRABALHO || !TRABALHO.timer) && !MOD.pedindo",
                          timeout=180000)
    pag.wait_for_timeout(400)
    if pag.evaluate("() => document.getElementById('resultado').open"):
        estado = pag.evaluate("() => document.getElementById('resultado-estado').dataset.estado")
        if estado == "erro":
            print("      registro: " + pag.locator("#saida").text_content().strip().replace("\n", "\n      "))
        pag.locator("#resultado-ok").click()
        pag.wait_for_function("() => !document.getElementById('resultado').open")
    pag.wait_for_function("() => !MOD.pedindo", timeout=30000)
    pag.wait_for_timeout(300)


def ir(pag):
    pag.evaluate("() => { location.hash = '#modificacoes'; }")
    esperar(pag)
    pag.wait_for_selector("article.cartao-mod", timeout=60000)
    quieto(pag)


def cartao(pag, ident):
    return pag.locator(f'article.cartao-mod[data-cartao="{ident}"]')


def pilula(pag, ident):
    return cartao(pag, ident).locator(".nome-mod .estado-pilula").inner_text().strip()


def abrir_menu(pag, ident):
    pag.locator(f'[data-controle="modificacao:menu:{ident}"]').click()
    pag.wait_for_function(f"() => document.querySelector('article[data-cartao=\"{ident}\"] details.menu-mod').open")


MOLDE_JS = """
() => [...document.querySelectorAll('article.cartao-mod')].map((a) => ({
  id: a.dataset.cartao,
  chaves: a.querySelectorAll('.cabeca-cartao > [role=switch]').length,
  menus: a.querySelectorAll('.cabeca-cartao > [data-controle^="modificacao:menu:"],'
    + ' .cabeca-cartao > details.menu-mod > summary[data-controle^="modificacao:menu:"]').length,
  titulo: (a.querySelector('.nome-mod h3') || {}).textContent || '',
  pilula: (a.querySelector('.nome-mod .estado-pilula') || {}).textContent || '',
  marca: a.querySelectorAll('.cabeca-cartao > .marca-app').length,
  ordem: [...a.querySelector('.cabeca-cartao').children].map((f) => f.matches('.marca-app') ? 'marca'
    : f.matches('.nome-mod') ? 'nome' : f.matches('[role=switch]') ? 'chave'
    : f.matches('details.menu-mod, [data-controle^="modificacao:menu:"]') ? 'menu' : f.className).join('|'),
}))
"""


def main():
    ambiente = montar()
    ambiente["PATH"] = os.pathsep.join(d for d in ambiente.get("PATH", "").split(os.pathsep)
                                       if not os.path.exists(os.path.join(d, "spicetify")))
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
            foto = lambda nome: pag.screenshot(path=os.path.join(FOTOS, nome + ".png")) if FOTOS else None  # noqa: E731

            print("1. um molde só: ícone, nome, situação, interruptor e «⋮» em todo cartão")
            ir(pag)
            molde = pag.evaluate(MOLDE_JS)
            checa(len(molde) >= 5, f"a página tem os cartões ({len(molde)})")
            for c in molde:
                checa(c["chaves"] == 1 and c["menus"] == 1 and c["marca"] == 1 and c["titulo"].strip() and c["pilula"].strip(),
                      f"o cartão {c['id']} tem ícone, nome, situação, um interruptor e um «⋮» ({c['pilula'].strip()!r})")
            checa(len({c["ordem"] for c in molde}) == 1, f"todos na mesma ordem ({sorted({c['ordem'] for c in molde})})")
            checa(any(c["id"] == "enfeite" for c in molde), "o módulo novo vira cartão sem ninguém o listar")
            foto("p134-modificacoes-1920")

            print("2. ligar um app: o tema do pack entra, o arquivo de antes fica guardado")
            checa(pilula(pag, "enfeite") == "Desligado", f"o enfeite começa desligado ({pilula(pag, 'enfeite')!r})")
            pag.locator('[data-controle="chave:APPS_ATIVOS:enfeite"]').click()
            quieto(pag)
            checa(eventual(lambda: "enfeite" in ativos()), f"ligar grava o enfeite no APPS_ATIVOS ({ativos()})")
            checa(eventual(lambda: ler(ENFEITE) == "cor=do-pack"), f"e o tema do pack entra ({ler(ENFEITE)!r})")
            checa(pag.locator('[data-controle="chave:APPS_ATIVOS:enfeite"]').get_attribute("aria-checked") == "true",
                  "o interruptor fica ligado")

            print("3. «Adicionar tema»: o arquivo vira o padrão do app, acima do do pack")
            abrir_menu(pag, "enfeite")
            itens = cartao(pag, "enfeite").locator(".menu-corpo [role^=menuitem]").all_inner_texts()
            checa(itens == ["Adicionar tema"], f"o menu tem «Adicionar tema» e nada de voltar ao pack ainda ({itens})")
            foto("p134-menu")
            pag.locator('[data-controle="modificacao:adicionar:enfeite"]').click()
            pag.wait_for_function("() => document.getElementById('adicionar-tema').open")
            checa(pag.locator("#tema-app").input_value() == "enfeite", "o diálogo abre já no app do cartão")
            pag.locator('[data-controle="adicionar-tema:adicionar"]').click()
            checa(pag.locator("#adicionar-tema-queixa").inner_text().strip() != "", "sem arquivo nem endereço, o diálogo se queixa")
            pag.fill("#tema-url", "http://exemplo.test/tema.conf")
            checa(pag.locator("#tema-selo").is_visible(), "um endereço mostra o selo de que baixa da internet")
            pag.locator('[data-controle="adicionar-tema:adicionar"]').click()
            pag.wait_for_function("() => document.getElementById('adicionar-tema').dataset.passo === 'escolha'"
                                  " && document.getElementById('adicionar-tema-queixa').textContent.trim() !== ''")
            checa("https" in pag.locator("#adicionar-tema-queixa").inner_text(), "http é recusado")
            pag.fill("#tema-url", "")
            pag.set_input_files("#tema-arquivo", files=[{"name": "Meu tema.conf", "mimeType": "text/plain", "buffer": b"cor=rosa\n"}])
            foto("p134-adicionar-tema")
            pag.locator('[data-controle="adicionar-tema:adicionar"]').click()
            pag.wait_for_function("() => !document.getElementById('adicionar-tema').open", timeout=30000)
            quieto(pag)
            checa(ler(os.path.join(TEMAS, "padrao")) == "Meu tema.conf", "o tema adicionado virou o padrão do enfeite")
            checa(eventual(lambda: ler(ENFEITE) == "cor=rosa"), f"e já está no lugar ({ler(ENFEITE)!r})")
            checa(eventual(lambda: pilula(pag, "enfeite") == "Meu tema.conf"), f"a situação mostra o tema no ar ({pilula(pag, 'enfeite')!r})")
            abrir_menu(pag, "enfeite")
            radio = pag.locator('[data-controle="modificacao:tema:enfeite:Meu tema.conf"]')
            checa(radio.count() == 1 and radio.get_attribute("aria-checked") == "true", "o menu marca o tema adicionado")

            print("4. «Voltar ao do pack» desfaz")
            pag.locator('[data-controle="modificacao:pack:enfeite"]').click()
            quieto(pag)
            checa(not os.path.exists(os.path.join(TEMAS, "padrao")), "o padrão adicionado saiu")
            checa(eventual(lambda: ler(ENFEITE) == "cor=do-pack"), f"e o tema do pack voltou ao lugar ({ler(ENFEITE)!r})")
            checa(eventual(lambda: pilula(pag, "enfeite") != "Meu tema.conf"), f"a situação deixa de mostrar o adicionado ({pilula(pag, 'enfeite')!r})")
            abrir_menu(pag, "enfeite")
            checa(pag.locator('[data-controle="modificacao:pack:enfeite"]').count() == 0, "sem padrão, o «Voltar ao do pack» some")
            checa(pag.locator('[data-controle="modificacao:tema:enfeite:Meu tema.conf"]').get_attribute("aria-checked") == "false",
                  "o tema adicionado fica na lista, desmarcado")
            pag.keyboard.press("Escape")

            print("5. desligar o app devolve o de antes")
            pag.locator('[data-controle="chave:APPS_ATIVOS:enfeite"]').click()
            quieto(pag)
            checa(eventual(lambda: "enfeite" not in ativos()), f"desligar tira o enfeite do APPS_ATIVOS ({ativos()})")
            checa(eventual(lambda: ler(ENFEITE) == "cor=minha"), f"e o arquivo de antes volta ({ler(ENFEITE)!r})")
            checa(eventual(lambda: pilula(pag, "enfeite") == "Desligado"), f"a situação diz Desligado ({pilula(pag, 'enfeite')!r})")

            print("6. correções no mesmo molde: o interruptor do Flatpak grava FLATPAK_CORRECOES")
            chave = pag.locator('[data-controle="modificacao:ligar:flatpak"]')
            checa(chave.count() == 1 and chave.get_attribute("role") == "switch", "o cartão do Flatpak tem o interruptor")
            antes = casa.valor_de("FLATPAK_CORRECOES")
            ligado = chave.get_attribute("aria-checked") == "true"
            chave.click()
            quieto(pag)
            checa(eventual(lambda: casa.valor_de("FLATPAK_CORRECOES") == ("nao" if ligado else "sim")),
                  f"um clique grava FLATPAK_CORRECOES={'nao' if ligado else 'sim'} ({antes!r} → {casa.valor_de('FLATPAK_CORRECOES')!r})")
            pag.locator('[data-controle="modificacao:ligar:flatpak"]').click()
            quieto(pag)
            checa(eventual(lambda: casa.valor_de("FLATPAK_CORRECOES") == ("sim" if ligado else "nao")), "e o segundo devolve")
            abrir_menu(pag, "flatpak")
            linhas = cartao(pag, "flatpak").locator(".itens-mod li").count()
            checa(linhas == 3, f"o «⋮» do Flatpak lista as três correções ({linhas})")
            checa(cartao(pag, "flatpak").locator('[data-controle^="modificacao:adicionar"]').count() == 0,
                  "e não tem «Adicionar tema»")
            pag.keyboard.press("Escape")
            if cartao(pag, "spotify").count():
                abrir_menu(pag, "spotify")
                checa(cartao(pag, "spotify").locator('[data-linha~="SPOTIFY_MARKETPLACE"]').is_visible(),
                      "a chave da loja mora no «⋮» do cartão")
                falta = pag.evaluate("() => !!((MOD.dados.cartoes || []).find((c) => c.id === 'spotify') || {})"
                                     ".falta_spicetify")
                checa(falta, "sem o spicetify na casa, o cartão do Spotify sabe que ele falta")
                checa(cartao(pag, "spotify").locator('[data-controle="acao:spicetify_instalar"]').is_visible(),
                      "e o «⋮» do Spotify tem o «Baixar o spicetify»")
                pag.keyboard.press("Escape")

            if FOTOS:
                pag.set_viewport_size({"width": 800, "height": 1000})
                ir(pag)
                foto("p134-modificacoes-800")
                abrir_menu(pag, "flatpak")
                foto("p134-menu-800")
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

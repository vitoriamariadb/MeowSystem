#!/usr/bin/env python3
import importlib.util
import os
import re
import shutil
import subprocess
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
TESTE = os.path.join(casa.BRINQUEDO, "extensoes")
ORIGENS = os.path.join(TESTE, "origens")
GIT = ["git", "-c", "core.hooksPath=/dev/null", "-c", "user.email=t@t", "-c", "user.name=t"]
PAINEL = os.path.join(casa.CASA, ".config", "cosmic", "com.system76.CosmicPanel.Panel", "v1")
DOCK = os.path.join(casa.CASA, ".config", "cosmic", "com.system76.CosmicPanel.Dock", "v1")
SHIM = os.path.join(casa.CASA, ".local", "bin", "cosmic-comp")
APPLETS = {
    "casa-um": ("Casa Um", "io.github.teste.CasaUm", ""),
    "casa-dois": ("Casa Dois", "io.github.teste.CasaDois", "io.velho.Antigo"),
    "casa-tres": ("Casa Três", "io.github.teste.CasaTres", "io.outro.Velho"),
}


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


def git(*args, cwd=None):
    return subprocess.run(GIT + list(args), cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def fazer_origem(nome, bin_, app_id, versao="0.1.0"):
    pasta = os.path.join(ORIGENS, nome)
    os.makedirs(os.path.join(pasta, "data"))
    git("init", "-q", "-b", "main", ".", cwd=pasta)
    with open(os.path.join(pasta, "Cargo.toml"), "w", encoding="utf-8") as fh:
        fh.write(f'[package]\nname = "{bin_}"\nversion = "{versao}"\n')
    with open(os.path.join(pasta, "data", app_id + ".desktop.in"), "w", encoding="utf-8") as fh:
        fh.write(f"[Desktop Entry]\nName={nome}\nExec=@bindir@/{bin_}\nIcon={app_id}\nX-CosmicApplet=true\n")
    with open(os.path.join(pasta, "data", app_id + ".svg"), "w", encoding="utf-8") as fh:
        fh.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8"><rect width="8" height="8"/></svg>\n')
    git("add", "-A", cwd=pasta)
    git("commit", "-q", "-m", "um", cwd=pasta)
    return pasta, git("rev-parse", "HEAD", cwd=pasta)


def escrever_pino(ident, commit, versao="0.1.0"):
    nome, app_id, substitui = APPLETS[ident]
    corpo = (f'ORDEM={list(APPLETS).index(ident) + 1}\nNOME="{nome}"\nDESCRICAO="Applet de teste"\n'
             f'URL="https://exemplo.test/casa/{ident}"\nCOMMIT="{commit}"\nVERSAO="{versao}"\n'
             f'APP_ID="{app_id}"\nBIN="meowsystem-{ident}"\nDESKTOP="data/{app_id}.desktop.in"\n'
             f'ICONES="data/{app_id}.svg:scalable/apps"\nSUBSTITUI="{substitui}"\n'
             f'UPSTREAM="https://github.com/dona/cosmic-ext-applet-{ident}"\n')
    with open(os.path.join(casa.RAIZ_B, "assets", "extensoes", ident + ".pino"), "w", encoding="utf-8") as fh:
        fh.write(corpo)


def montar():
    ambiente = casa.montar_casa()
    os.makedirs(ORIGENS)
    pinos = os.path.join(casa.RAIZ_B, "assets", "extensoes")
    for arquivo in os.listdir(pinos):
        if arquivo.endswith(".pino"):
            os.remove(os.path.join(pinos, arquivo))
    shutil.copyfile(os.path.join(pinos, "icones", "now-playing.svg"), os.path.join(pinos, "icones", "casa-um.svg"))
    commits = {}
    gitconfig = os.path.join(TESTE, "gitconfig")
    with open(gitconfig, "w", encoding="utf-8") as fh:
        for ident, (_nome, app_id, _sub) in APPLETS.items():
            pasta, commits[ident] = fazer_origem(ident, f"meowsystem-{ident}", app_id)
            fh.write(f'[url "file://{pasta}"]\n\tinsteadOf = https://exemplo.test/casa/{ident}\n')
        pasta, commits["novo"] = fazer_origem("cosmic-ext-applet-novo", "meowsystem-novo", "io.github.teste.Novo", "0.2.0")
        fh.write(f'[url "file://{pasta}"]\n\tinsteadOf = https://exemplo.test/dona/cosmic-ext-applet-novo\n')
        vazio = os.path.join(ORIGENS, "vazio")
        os.makedirs(vazio)
        git("init", "-q", "-b", "main", ".", cwd=vazio)
        with open(os.path.join(vazio, "Cargo.toml"), "w", encoding="utf-8") as g:
            g.write('[package]\nname = "nada"\nversion = "1.0.0"\n')
        git("add", "-A", cwd=vazio)
        git("commit", "-q", "-m", "um", cwd=vazio)
        fh.write(f'[url "file://{vazio}"]\n\tinsteadOf = https://exemplo.test/dona/vazio\n')
    for ident in APPLETS:
        escrever_pino(ident, commits[ident])
    for ident in ("compositor", "menu-arquivos"):
        shutil.copyfile(os.path.join(casa.RAIZ, "assets", "extensoes", ident + ".pino"), os.path.join(pinos, ident + ".pino"))
    garantir = os.path.join(TESTE, "garantir")
    casa.escrever_exec(garantir,
        '#!/bin/sh\n[ "$1" = estado ] || exit 0\n'
        'if [ -f "$MEOW_TESTE_COMP" ]; then\n'
        '  if grep -qs MEOW-COSMIC-COMP-SHIM "$HOME/.local/bin/cosmic-comp"; then e=ok; else e=desligado; fi\n'
        'else e=pendente; fi\n'
        'printf \'compositor_versao=0.1~t\\ncompositor_estado=%s\\nmenu_versao=1.0~t\\n'
        'menu_estado=pendente\\nconstruindo=nao\\n\' "$e"\n')
    compositor = os.path.join(TESTE, "compositor")
    casa.escrever_exec(compositor,
        '#!/bin/sh\necho "compositor $*" >> "$MEOW_TESTE_CARGO"\n'
        'case "$1" in\n'
        '  compilar) : > "$MEOW_TESTE_COMP"; exit 1 ;;\n'
        '  ativar) grep -qs MEOW-COSMIC-COMP-SHIM "$HOME/.local/bin/cosmic-comp" && exit 0\n'
        '    mkdir -p "$HOME/.local/bin"; printf \'#!/bin/sh\\nMEOW-COSMIC-COMP-SHIM-1\\n\' > "$HOME/.local/bin/cosmic-comp"; exit 1 ;;\n'
        '  desativar) [ -e "$HOME/.local/bin/cosmic-comp" ] || exit 0; rm -f "$HOME/.local/bin/cosmic-comp"; exit 1 ;;\n'
        'esac\nexit 0\n')
    open(os.path.join(TESTE, "comp-pronto"), "w").close()
    falso = casa.FALSO
    os.remove(os.path.join(falso, "git"))
    cargo = os.path.join(falso, "cargo")
    with open(cargo, "w", encoding="utf-8") as fh:
        fh.write('#!/bin/sh\necho "cargo $*" >> "$MEOW_TESTE_CARGO"\n[ "$1" = build ] || exit 0\n'
                 '[ -f "$MEOW_TESTE_FALHA" ] && { echo "error: linker \\`cc\\` not found" >&2; exit 101; }\n'
                 'while [ $# -gt 0 ]; do [ "$1" = --manifest-path ] && { manifesto="$2"; break; }; shift; done\n'
                 'nome="$(sed -n \'s/^name = "\\(.*\\)"/\\1/p\' "$manifesto" | head -1)"\n'
                 'mkdir -p "$CARGO_TARGET_DIR/release"\n'
                 'printf \'#!/bin/sh\\n\' > "$CARGO_TARGET_DIR/release/$nome"\nchmod 755 "$CARGO_TARGET_DIR/release/$nome"\n')
    os.chmod(cargo, 0o755)
    os.makedirs(PAINEL)
    with open(os.path.join(PAINEL, "plugins_wings"), "w", encoding="utf-8") as fh:
        fh.write('Some(([\n    "com.system76.CosmicAppletWorkspaces",\n], [\n    "io.velho.Antigo",\n'
                 '    "outro.Applet",\n]))')
    os.makedirs(DOCK)
    with open(os.path.join(DOCK, "plugins_wings"), "w", encoding="utf-8") as fh:
        fh.write('Some(([\n    "com.system76.CosmicAppList",\n], [\n    "io.outro.Velho",\n'
                 '    "com.system76.CosmicAppletMinimize",\n]))')
    ambiente.update({"GIT_CONFIG_GLOBAL": gitconfig, "MEOW_TESTE_CARGO": os.path.join(TESTE, "cargo.log"),
                     "MEOW_TESTE_FALHA": os.path.join(TESTE, "falha"),
                     "MEOW_TESTE_COMP": os.path.join(TESTE, "comp-pronto"),
                     "EXTENSOES_GARANTIR": garantir, "EXTENSOES_COMPOSITOR": compositor})
    return ambiente, commits


def esperar(pag, ms=400):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    esperar(pag)
    pag.wait_for_selector(".abas-ajustes", timeout=20000)
    pag.wait_for_function("() => !document.querySelector('#conteudo .esqueleto') && !EXT.pedindo", timeout=30000)
    pag.wait_for_timeout(200)


def fim_do_trabalho(pag, fechar=True):
    pag.wait_for_function("() => document.getElementById('resultado').open", timeout=30000)
    pag.wait_for_function("() => !TRABALHO || !TRABALHO.timer", timeout=180000)
    pag.wait_for_timeout(300)
    estado = pag.evaluate("() => document.getElementById('resultado-estado').dataset.estado")
    if estado != "ok":
        print("      registro: " + pag.locator("#saida").text_content().strip().replace("\n", "\n      "))
    if fechar:
        pag.locator("#resultado-ok").click()
        pag.wait_for_function("() => !document.getElementById('resultado').open")
        pag.wait_for_function("() => !EXT.pedindo", timeout=30000)
        pag.wait_for_timeout(500)
    return estado


def confirmar(pag):
    pag.wait_for_function("() => document.getElementById('pergunta').open", timeout=10000)
    pag.locator("#pergunta-sim").click()


def cartao(pag, ident):
    return pag.locator(f'article[data-applet="{ident}"]')


def pilula(pag, ident):
    return cartao(pag, ident).locator("[data-pilula]").inner_text().strip()


def botoes(pag, ident):
    return cartao(pag, ident).locator("button").evaluate_all(
        "(l) => l.map((b) => b.textContent.trim() || b.getAttribute('aria-label') || '')")


def eventual(fn, seg=20):
    import time
    fim = time.time() + seg
    while time.time() < fim:
        try:
            if fn():
                return True
        except Exception:
            pass
        time.sleep(0.3)
    return False


def conf(chave):
    return casa.valor_de(chave)


def asas(pasta=PAINEL):
    with open(os.path.join(pasta, "plugins_wings"), encoding="utf-8") as fh:
        return re.findall(r'"([^"]*)"', fh.read())


def cartao_de_build(pag, ident):
    return pag.locator(f'article[data-build="{ident}"]')


def pilula_de_build(pag, ident):
    return cartao_de_build(pag, ident).locator("[data-pilula]").inner_text().strip()


def botoes_de_build(pag, ident):
    return cartao_de_build(pag, ident).locator("button").evaluate_all(
        "(l) => l.map((b) => (b.textContent.trim() || b.getAttribute('aria-label') || '') + (b.disabled ? ' (parado)' : ''))")


def main():
    ambiente, commits = montar()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            contexto = nav.new_context(viewport={"width": 1550, "height": 860})
            pag = contexto.new_page()
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pedidos = []
            contexto.route("https://**/*", lambda r: (pedidos.append(r.request.url), r.abort()))
            pag.goto(url)
            esperar(pag, 800)
            foto = lambda nome: pag.screenshot(path=os.path.join(FOTOS, nome + ".png")) if FOTOS else None  # noqa: E731

            print("1. a porta Extensões: um cartão por applet, com a versão e a origem")
            ir(pag, "extensoes")
            checa(pag.locator(".portas a", has_text="Extensões").count() == 1, "a porta Extensões está no cabeçalho")
            checa(pag.locator(".abas-ajustes a").all_inner_texts() == ["Applets", "Builds"], "as abas são Applets e Builds")
            checa(pag.locator("article[data-applet]").count() == 3, "há um cartão por applet do catálogo, e o compositor e o menu ficam nos Builds")
            checa(eventual(lambda: pilula(pag, "casa-um") == "Não instalada"), f"o applet de fora aparece «{pilula(pag, 'casa-um')}»")
            checa(botoes(pag, "casa-um") == ["Instalar"], f"e só oferece Instalar ({botoes(pag, 'casa-um')})")
            versao = cartao(pag, "casa-um").locator(".versao").text_content()
            checa(f"0.1.0 · {commits['casa-um'][:7]}" in versao, f"a versão leva o commit curto ({versao.splitlines()[0]!r})")
            balao = cartao(pag, "casa-um").locator(".dica-repo").text_content()
            checa("https://exemplo.test/casa/casa-um" in balao and commits["casa-um"][:7] in balao,
                  "e o balão traz o repositório e o commit")
            checa(cartao(pag, "casa-um").locator("img").first.evaluate("(i) => i.complete && i.naturalWidth > 0"),
                  "o ícone do applet carrega pelo servidor")
            checa(pag.locator(".cartao-novo").count() == 1 and pag.locator(".abas-ajustes [data-controle='extensao:abrir-adicionar']").count() == 1,
                  "e há dois caminhos para «Adicionar repositório»")
            forma = pag.evaluate("""() => [...document.querySelectorAll('article[data-applet]')].map((c) => {
              const h = c.querySelector('h3');
              return [getComputedStyle(c).gridTemplateColumns.split(' ').length, h.getBoundingClientRect().height <= parseFloat(getComputedStyle(h).lineHeight) * 1.5];
            })""")
            checa(forma and all(colunas == 1 and uma_linha for colunas, uma_linha in forma),
                  f"cada cartão é uma coluna e o nome cabe numa linha ({forma})")
            checa(pag.locator(".abas-ajustes").count() == 1 and pag.locator("#conteudo .abas-ajustes").count() == 0,
                  "as abas moram na barra de cima, uma só")
            ir(pag, "ajustes/painel")
            checa(pag.locator(".abas-ajustes [data-controle^='ajuste:']").count() >= 7 and pag.locator(".abas-ajustes [data-aba]").count() == 0,
                  "e Definir volta com as suas abas")
            ir(pag, "extensoes")
            checa(pag.locator("#conteudo .previa").count() == 1 and pag.locator(".barra-perto").count() == 1,
                  "a prévia e a barra de cima estão ao lado")
            foto("extensoes-normal")

            print("2. instalar um applet da casa: compila, instala e grava a lista")
            cartao(pag, "casa-um").get_by_role("button", name="Instalar").click()
            estado = fim_do_trabalho(pag)
            checa(estado == "ok", f"o trabalho termina em ok ({estado})")
            checa(os.path.isfile(os.path.join(casa.CASA, ".local", "bin", "meowsystem-casa-um")), "o binário está na casa")
            checa("casa-um" in (conf("EXTENSOES") or "").split(","), f"o EXTENSOES ganha o id ({conf('EXTENSOES')!r})")
            checa(eventual(lambda: pilula(pag, "casa-um") == "Instalada, fora da barra"), f"o cartão diz «{pilula(pag, 'casa-um')}»")
            checa(eventual(lambda: botoes(pag, "casa-um") == ["Pôr no painel", "Remover Casa Um"]), f"e oferece pôr e remover ({botoes(pag, 'casa-um')})")

            print("3. pôr no painel acrescenta no fim, sem mexer na ordem do resto")
            antes = asas()
            cartao(pag, "casa-um").get_by_role("button", name="Pôr no painel").click()
            fim_do_trabalho(pag)
            depois = asas()
            checa(depois == antes + ["io.github.teste.CasaUm"], f"o applet entra no fim da ala direita ({depois})")
            checa(eventual(lambda: pilula(pag, "casa-um") == "Na barra"), f"o cartão diz «{pilula(pag, 'casa-um')}»")
            checa(pag.locator(".barra-perto .applet-na-barra.nosso").count() == 1 and pag.locator(".p-barra .applets-mini img").count() == 1,
                  "a barra e a prévia mostram o applet")
            foto("extensoes-na-barra")

            print("4. a troca pendente: só com o sim, na mesma posição; «Manter» a dispensa")
            checa(pag.locator("#pendencia").count() == 0, "enquanto o novo não está instalado, não há troca para oferecer")
            cartao(pag, "casa-dois").get_by_role("button", name="Instalar").click()
            fim_do_trabalho(pag)
            cartao(pag, "casa-tres").get_by_role("button", name="Instalar").click()
            fim_do_trabalho(pag)
            checa(asas() == antes + ["io.github.teste.CasaUm"], "instalar não mexeu na barra")
            eventual(lambda: pag.locator("#pendencia [data-troca]").count() == 2)
            linhas = pag.locator("#pendencia [data-troca]").all_inner_texts()
            checa(len(linhas) == 2 and "Casa Dois" in linhas[0] and "Antigo" in linhas[0], f"a pendência diz quem entra no lugar de quem ({linhas[:1]})")
            foto("extensoes-troca")
            pag.locator('#pendencia [data-troca="casa-tres"] button', has_text="Manter").click()
            pag.wait_for_function("() => document.querySelectorAll('#pendencia [data-troca]').length === 1", timeout=10000)
            checa(asas() == antes + ["io.github.teste.CasaUm"], "«Manter» não mexe na barra")
            pag.reload()
            esperar(pag, 800)
            ir(pag, "extensoes")
            checa(pag.locator("#pendencia [data-troca]").count() == 1, "e a dispensa vale depois de recarregar")
            pag.locator('#pendencia [data-troca="casa-dois"] button', has_text="Trocar").click()
            fim_do_trabalho(pag)
            esperado = [a if a != "io.velho.Antigo" else "io.github.teste.CasaDois" for a in antes] + ["io.github.teste.CasaUm"]
            checa(asas() == esperado, f"«Trocar» põe o novo na posição do antigo ({asas()})")
            checa(eventual(lambda: pag.locator("#pendencia [data-troca]").count() == 0), "e a pendência some")

            print("5. atualização: o pino novo vira o botão «Atualizar»")
            pasta = os.path.join(ORIGENS, "casa-um")
            with open(os.path.join(pasta, "data", "mais"), "w", encoding="utf-8") as fh:
                fh.write("x")
            git("add", "-A", cwd=pasta)
            git("commit", "-q", "-m", "dois", cwd=pasta)
            escrever_pino("casa-um", git("rev-parse", "HEAD", cwd=pasta), "0.2.0")
            pag.reload()
            esperar(pag, 800)
            ir(pag, "extensoes")
            checa(eventual(lambda: pilula(pag, "casa-um") == "Atualização"), f"o cartão diz «{pilula(pag, 'casa-um')}»")
            checa(eventual(lambda: "Atualizar" in botoes(pag, "casa-um")), f"e oferece Atualizar ({botoes(pag, 'casa-um')})")
            cartao(pag, "casa-um").get_by_role("button", name="Atualizar").click()
            fim_do_trabalho(pag)
            checa(eventual(lambda: pilula(pag, "casa-um") == "Na barra"), f"depois de atualizar volta a «{pilula(pag, 'casa-um')}»")

            print("6. falha de compilação: o cartão mostra o registro e oferece tentar de novo")
            cartao(pag, "casa-tres").get_by_role("button", name="Remover Casa Três").click()
            confirmar(pag)
            fim_do_trabalho(pag)
            checa(eventual(lambda: pilula(pag, "casa-tres") == "Não instalada"), "remover devolve o cartão a «Não instalada»")
            checa(not os.path.exists(os.path.join(casa.CASA, ".local", "bin", "meowsystem-casa-tres")), "e tira o binário")
            open(os.path.join(TESTE, "falha"), "w").close()
            cartao(pag, "casa-tres").get_by_role("button", name="Instalar").click()
            estado = fim_do_trabalho(pag)
            checa(estado == "erro", f"o trabalho termina em erro ({estado})")
            checa(eventual(lambda: pilula(pag, "casa-tres") == "Falhou"), f"o cartão diz «{pilula(pag, 'casa-tres')}»")
            checa("linker" in cartao(pag, "casa-tres").locator(".registro").inner_text() or
                  "linker" in cartao(pag, "casa-tres").locator(".registro").text_content(), "e o registro guarda o erro do cargo")
            checa(eventual(lambda: "Tentar de novo" in botoes(pag, "casa-tres")), f"e oferece tentar de novo ({botoes(pag, 'casa-tres')})")
            foto("extensoes-falhou")
            os.remove(os.path.join(TESTE, "falha"))
            cartao(pag, "casa-tres").get_by_role("button", name="Tentar de novo").click()
            estado = fim_do_trabalho(pag)
            checa(estado == "ok" and eventual(lambda: pilula(pag, "casa-tres") != "Falhou"), f"tentar de novo compila ({estado}, {pilula(pag, 'casa-tres')})")

            print("6b. Trocar na Dock: o antigo mora na Dock, o novo entra lá; e «Reiniciar o painel» aparece")
            os.remove(os.path.join(casa.ESTADO, "extensoes", "mantem"))
            painel_antes, dock_antes = asas(), asas(DOCK)
            pag.reload()
            esperar(pag, 800)
            ir(pag, "extensoes")
            checa(eventual(lambda: pag.locator('#pendencia [data-troca="casa-tres"]').count() == 1),
                  "o applet velho só na Dock vira pendência de troca")
            checa(pag.locator("#pendencia [data-controle='extensao:reiniciar-painel']").count() == 1,
                  "o aviso do «Trocar» traz «Reiniciar o painel»")
            pag.locator('#pendencia [data-troca="casa-tres"] button', has_text="Trocar").click()
            fim_do_trabalho(pag)
            esperado = [a if a != "io.outro.Velho" else "io.github.teste.CasaTres" for a in dock_antes]
            checa(asas(DOCK) == esperado, f"«Trocar» põe o novo no lugar do antigo, na Dock ({asas(DOCK)})")
            checa(asas() == painel_antes, "e o Panel fica como estava")
            checa(eventual(lambda: pag.locator('#pendencia [data-troca]').count() == 0
                           and pag.locator("#pendencia [data-controle='extensao:reiniciar-painel']").count() == 1),
                  "a troca some e «Reiniciar o painel» fica, sem reiniciar sozinho")
            foto("extensoes-reiniciar")
            pag.locator("#pendencia [data-controle='extensao:reiniciar-painel']").click()
            estado = fim_do_trabalho(pag)
            checa(estado == "ok", f"«Reiniciar o painel» termina em ok ({estado})")
            checa(eventual(lambda: pag.locator("#pendencia").count() == 0), "e o aviso some")

            print("7. Builds: compositor e menu no mesmo cartão, e cada applet, com Refazer")
            ir(pag, "extensoes/builds")
            checa(cartao_de_build(pag, "compositor").count() == 1 and cartao_de_build(pag, "menu-arquivos").count() == 1,
                  "o compositor e o menu do Arquivos têm cartão")
            checa(eventual(lambda: pilula_de_build(pag, "compositor") == "Pronto, desligado"),
                  f"build pronto com o shim desligado: «{pilula_de_build(pag, 'compositor')}»")
            checa(botoes_de_build(pag, "compositor") == ["Instalar", "Atualizar (parado)", "Refazer", "Remover Compositor (parado)"],
                  f"o cartão do compositor tem os quatro botões ({botoes_de_build(pag, 'compositor')})")
            checa("cosmic-comp 0.1~t" in cartao_de_build(pag, "compositor").inner_text()
                  and re.search(r"\b\d+ remendos", cartao_de_build(pag, "compositor").inner_text()), "e diz a versão e os remendos")
            checa(eventual(lambda: pilula_de_build(pag, "menu-arquivos") == "Não instalada"),
                  f"o menu sem build: «{pilula_de_build(pag, 'menu-arquivos')}»")
            foto("extensoes-builds-desligado")
            cartao_de_build(pag, "compositor").get_by_role("button", name="Instalar").click()
            estado = fim_do_trabalho(pag)
            checa(estado == "ok" and os.path.isfile(SHIM), f"«Instalar» liga o shim ({estado})")
            checa(eventual(lambda: pilula_de_build(pag, "compositor") == "Em dia"), f"e o cartão diz «{pilula_de_build(pag, 'compositor')}»")
            checa(conf("COMPOSITOR") == "sim", f"o meow.conf diz COMPOSITOR=sim ({conf('COMPOSITOR')!r})")
            cartao_de_build(pag, "compositor").get_by_role("button", name="Remover Compositor").click()
            confirmar(pag)
            estado = fim_do_trabalho(pag)
            checa(estado == "ok" and not os.path.exists(SHIM), f"«Remover» desliga o shim ({estado})")
            checa(eventual(lambda: pilula_de_build(pag, "compositor") == "Pronto, desligado"),
                  f"e o build fica: «{pilula_de_build(pag, 'compositor')}»")
            rotulos = pag.locator("[data-aba-corpo='builds'] .linha .rot b").all_inner_texts()
            checa(rotulos == ["Casa Um", "Casa Dois", "Casa Três"], f"as linhas dos applets ({rotulos})")
            checa(pag.locator("[data-controle='build:tudo']").count() == 1, "«Refazer tudo» existe")
            antes_cargo = open(os.path.join(TESTE, "cargo.log"), encoding="utf-8").read().count("build")
            pag.locator("[data-controle='build:extensao:casa-um']").click()
            fim_do_trabalho(pag)
            depois_cargo = open(os.path.join(TESTE, "cargo.log"), encoding="utf-8").read().count("build")
            checa(depois_cargo > antes_cargo, "«Refazer» do applet roda o cargo de novo")
            chave = pag.locator("[data-controle='build:ao-entrar']")
            checa(chave.get_attribute("aria-checked") == "true" and (conf("BUILDS_AO_ENTRAR") or "sim") == "sim",
                  "«Refazer ao entrar na sessão» vem ligado")
            chave.click()
            pag.wait_for_function("() => document.querySelector('[data-controle=\"build:ao-entrar\"]').getAttribute('aria-checked') === 'false'")
            pag.wait_for_timeout(300)
            checa(conf("BUILDS_AO_ENTRAR") == "nao", f"desligar grava BUILDS_AO_ENTRAR=nao ({conf('BUILDS_AO_ENTRAR')!r})")
            chave.click()
            pag.wait_for_function("() => document.querySelector('[data-controle=\"build:ao-entrar\"]').getAttribute('aria-checked') === 'true'")
            pag.wait_for_timeout(300)
            checa(conf("BUILDS_AO_ENTRAR") == "sim", "e ligar de novo grava sim")
            foto("extensoes-builds")

            print("8. Adicionar repositório: URL, ficha, compilando, pronto")
            ir(pag, "extensoes")
            pag.locator(".abas-ajustes [data-controle='extensao:abrir-adicionar']").click()
            pag.wait_for_function("() => document.getElementById('adicionar').open")
            checa(pag.evaluate("() => document.getElementById('adicionar').dataset.passo") == "url", "o diálogo abre no passo do endereço")
            pag.fill("#repo-url", "http://exemplo.test/dona/cosmic-ext-applet-novo")
            pag.locator("#adicionar-ler").click()
            pag.wait_for_function("() => document.getElementById('adicionar').dataset.passo === 'erro-url'")
            checa("https" in pag.locator("#adicionar-queixa").inner_text(), "http é recusado com a queixa «Só endereço https»")
            pag.fill("#repo-url", "https://exemplo.test/dona/vazio")
            pag.locator("#adicionar-ler").click()
            pag.wait_for_function("() => document.getElementById('adicionar').dataset.passo === 'erro-url'", timeout=60000)
            checa(pag.locator("#adicionar-queixa").inner_text().strip() != "", f"repositório sem applet é recusado ({pag.locator('#adicionar-queixa').inner_text()!r})")
            pag.fill("#repo-url", "https://exemplo.test/dona/cosmic-ext-applet-novo")
            pag.locator("#adicionar-ler").click()
            pag.wait_for_function("() => document.getElementById('adicionar').dataset.passo === 'ficha'", timeout=60000)
            ficha = pag.locator("#adicionar .ficha-repo").inner_text()
            checa("dona/cosmic-ext-applet-novo" in ficha and commits["novo"][:7] in ficha, f"a ficha traz repositório e commit ({ficha.splitlines()[:1]})")
            checa(pag.locator(".selo").is_visible() and "baixa e compila" in pag.locator(".selo").inner_text(), "e o selo «baixa e compila»")
            checa(not os.path.exists(os.path.join(casa.CASA, ".local", "bin", "meowsystem-novo")), "ler não instalou nada")
            foto("extensoes-ficha")
            ext_antes = conf("EXTENSOES")
            pag.locator("#adicionar-instalar").click()
            pag.wait_for_function("() => ['pronto', 'erro'].includes(document.getElementById('adicionar').dataset.passo)", timeout=180000)
            checa(pag.evaluate("() => document.getElementById('adicionar').dataset.passo") == "pronto", "compilou e chegou ao passo pronto")
            checa(os.path.isfile(os.path.join(casa.CASA, ".local", "bin", "meowsystem-novo")), "o binário do repositório está na casa")
            checa(conf("EXTENSOES") == ext_antes, "o EXTENSOES não mudou: repositório de usuário só entra por gesto")
            pag.locator("#adicionar-ok").click()
            pag.wait_for_timeout(800)
            checa(eventual(lambda: cartao(pag, "novo").count() == 1 and pilula(pag, "novo") == "Instalada, fora da barra"),
                  f"o cartão novo aparece na grade ({pilula(pag, 'novo') if cartao(pag, 'novo').count() else '-'})")

            print("9. o repositório do usuário: remover pede o sim")
            cartao(pag, "novo").get_by_role("button", name="Remover cosmic-ext-applet-novo").click()
            pag.wait_for_function("() => document.getElementById('pergunta').open")
            pag.locator("#pergunta-nao").click()
            checa(os.path.isfile(os.path.join(casa.CASA, ".local", "bin", "meowsystem-novo")), "recusar a pergunta não remove")

            print("10. Créditos: o diálogo do painel, com as duas autorias")
            pag.locator("#menu summary").click()
            checa(pag.locator("#menu-corpo [data-controle='menu:creditos']").evaluate("(e) => e.tagName") == "BUTTON", "«Créditos» é um botão do menu")
            pag.locator("#menu-corpo [data-controle='menu:creditos']").click()
            pag.wait_for_function("() => document.getElementById('creditos').open")
            pag.wait_for_function("() => document.querySelectorAll('#creditos-upstreams li').length > 0", timeout=10000)
            texto = pag.locator("#creditos").inner_text()
            checa("Vitória Maria" in texto and "autora" in texto and "André Farias" in texto and "coautor" in texto,
                  "o diálogo traz Vitória Maria (autora) e André Farias (coautor)")
            href = pag.locator("#creditos [data-controle='creditos:repositorio']").get_attribute("href")
            rel = pag.locator("#creditos [data-controle='creditos:repositorio']").get_attribute("rel")
            checa(href == "https://github.com/vitoriamariadb/MeowSystem" and "noopener" in (rel or ""), f"o link da casa é {href}")
            checa("dona/cosmic-ext-applet-casa-um" in texto, "e cada applet da casa aponta para o upstream")
            foto("extensoes-creditos")
            pag.locator("[data-controle='creditos:ok']").click()
            pag.wait_for_function("() => !document.getElementById('creditos').open")

            if FOTOS:
                maquete = os.path.join(AQUI, "..", "docs", "sprints", "2026-10-26-qa-final", "maquete", "b", "extensoes.html")
                for larg, alt in ((1920, 1080), (1550, 860), (1500, 900), (1280, 800)):
                    pag.set_viewport_size({"width": larg, "height": alt})
                    ir(pag, "extensoes")
                    pag.screenshot(path=os.path.join(FOTOS, f"extensoes-{larg}x{alt}.png"))
                    ir(pag, "extensoes/builds")
                    pag.screenshot(path=os.path.join(FOTOS, f"extensoes-builds-{larg}x{alt}.png"))
                    mq = contexto.new_page()
                    mq.set_viewport_size({"width": larg, "height": alt})
                    mq.goto("file://" + os.path.abspath(maquete))
                    mq.wait_for_timeout(400)
                    mq.screenshot(path=os.path.join(FOTOS, f"maquete-{larg}x{alt}.png"))
                    mq.close()
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

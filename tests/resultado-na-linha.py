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

ROTAS = ["ajustes/painel", "ajustes/janelas", "ajustes/papel", "ajustes/mascote", "ajustes/dia-e-noite",
         "ajustes/programas", "cuidar", "modificacoes"]

LEITURAS = """
() => [...document.querySelectorAll('#conteudo [data-controle^="acao:"]')]
  .map((b) => b.dataset.controle.slice(5))
  .filter((id) => ACAO.has(id) && !ACAO.get(id).escreve && !ACAO.get(id).arg && !ACAO.get(id).indisponivel
    && !document.querySelector('#conteudo [data-controle="acao:' + id + '"]').disabled)
"""

RESULTADO = """
(id) => {
  const r = document.querySelector('[data-resultado="' + id + '"]');
  if (!r) return null;
  return { texto: r.innerText.trim(), pre: r.querySelectorAll('pre, details').length,
           dentro: !!r.closest('#conteudo'), estado: r.dataset.estado,
           consertar: !!r.querySelector('[data-controle="resultado:consertar"]'),
           linhas: r.querySelectorAll('li').length };
}
"""


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


PAGINA = []


def eventual(fn, seg=60):
    fim = time.time() + seg
    while time.time() < fim:
        try:
            if fn():
                return True
        except Exception:
            pass
        PAGINA[0].wait_for_timeout(300)
    return False


def esperar(pag, ms=400):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir(pag, rota):
    pag.evaluate("(r) => { location.hash = '#' + r; }", rota)
    esperar(pag)


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            contexto = nav.new_context(viewport={"width": 1829, "height": 1029})
            pag = contexto.new_page()
            PAGINA.append(pag)
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            posts = []
            pag.on("request", lambda r: r.method == "POST" and r.url.endswith("/api/rodar")
                   and posts.append(r.post_data_json.get("acao")))
            pag.goto(url)
            esperar(pag, 800)

            print("1. cada ação que só lê mostra o resultado na própria linha")
            vistas = []
            for rota in ROTAS:
                ir(pag, rota)
                for acao in pag.evaluate(LEITURAS):
                    if acao in vistas or acao == "som_ouvir":
                        continue
                    vistas.append(acao)
                    pag.locator(f'#conteudo [data-controle="acao:{acao}"]').first.click()
                    achou = eventual(lambda a=acao: pag.evaluate(RESULTADO, a) is not None)
                    r = pag.evaluate(RESULTADO, acao) if achou else None
                    checa(bool(r) and r["texto"] != "", f"«{acao}» ({rota}) mostra um resultado com texto ({(r or {}).get('texto', '')[:60]!r})")
                    if r:
                        checa(r["dentro"] and r["pre"] == 0, f"«{acao}»: na tela, sem pre nem registro")
                        checa(r["linhas"] <= 7, f"«{acao}»: sem rolagem infinita ({r['linhas']} linhas)")
                        checa("/home/" not in r["texto"] and "/tmp/" not in r["texto"], f"«{acao}»: sem caminho de arquivo cru")
                    eventual(lambda: not pag.evaluate("() => !!TRABALHO && !!TRABALHO.timer"))
            checa(len(vistas) >= 8, f"o gate achou as ações que só leem ({len(vistas)}: {vistas})")
            checa(pag.locator("#resultado").count() == 0, "e não existe janela de resultado")

            print("2. rodar de novo troca o resultado; sair da tela o tira")
            ir(pag, "cuidar")
            pag.locator('#conteudo [data-controle="acao:doctor"]').first.click()
            eventual(lambda: pag.evaluate(RESULTADO, "doctor") is not None)
            checa(pag.locator('[data-resultado="doctor"]').count() == 1, "um resultado só da verificação")
            pag.locator('#conteudo [data-controle="acao:doctor"]').first.click()
            checa(eventual(lambda: pag.locator('[data-resultado="doctor"]').count() == 0), "ao rodar de novo o anterior some")
            checa(eventual(lambda: pag.evaluate(RESULTADO, "doctor") is not None), "e o novo chega")
            ir(pag, "ajustes/painel")
            ir(pag, "cuidar")
            checa(pag.locator('[data-resultado="doctor"]').count() == 0, "sair da tela e voltar não traz o resultado velho")

            print("3. Verificar o sistema: com divergência mostra quantas e oferece Consertar")
            pag.locator('#conteudo [data-controle="acao:doctor"]').first.click()
            achou = eventual(lambda: (pag.evaluate(RESULTADO, "doctor") or {}).get("consertar"))
            r = pag.evaluate(RESULTADO, "doctor") or {}
            checa(r.get("estado") == "divergente", f"o retorno 1 vira divergência, não some calado ({r.get('estado')})")
            checa(achou and "diverg" in r.get("texto", ""), f"diz quantas coisas divergem ({r.get('texto', '')[:80]!r})")
            checa(r.get("linhas", 0) >= 1, "e quais, uma por linha")
            if FOTOS:
                pag.screenshot(path=os.path.join(FOTOS, "p200-verificar-depois.png"))
            antes = len(posts)
            pag.locator('[data-controle="resultado:consertar"]').click()
            checa(eventual(lambda: "doctor_consertar" in posts[antes:]), f"o Consertar roda doctor_consertar ({posts[antes:]})")
            parar = pag.locator('[data-controle="progresso:parar"]')
            if eventual(lambda: parar.is_visible(), 20):
                parar.click()
            checa(eventual(lambda: "doctor" in posts[antes:], 120), "e depois confere de novo")
            if eventual(lambda: parar.is_visible(), 20):
                parar.click()
            eventual(lambda: not pag.evaluate("() => !!TRABALHO && !!TRABALHO.timer"), 60)

            print("4. Conferir de Modificações relê os cartões e ganha o resultado")
            ir(pag, "modificacoes")
            cartoes = pag.locator("[data-cartao]").count()
            antes = len(posts)
            pag.locator('#conteudo [data-controle="acao:apps"]').first.click()
            checa(eventual(lambda: pag.evaluate(RESULTADO, "apps") is not None), "o Conferir mostra o resultado")
            checa(eventual(lambda: pag.locator("[data-cartao]").count() == cartoes and cartoes > 0), "e os cartões continuam lá")

            print("5. Mascote sem nome de linha; Papel de parede com «Girar»")
            ir(pag, "ajustes/mascote")
            linha = pag.locator('[data-linha="logo_trocar"]')
            checa(linha.count() == 1 and linha.locator(".rot").inner_text().strip() == "", "a linha do logo_trocar não tem nome")
            checa(linha.locator("button").inner_text().strip() == "Aplicar", "só o botão «Aplicar»")
            ir(pag, "ajustes/papel")
            linha = pag.locator('[data-linha="wallpaper_carrossel"]')
            checa(linha.locator(".rot").inner_text().strip() == "Girar" and linha.locator("button").inner_text().strip() == "Girar",
                  "a linha e o botão se chamam «Girar»")
            checa(pag.locator('[data-controle="acao:wallpaper_proximo"]').inner_text().strip() == "Próxima imagem", "«Próxima imagem» fica")

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

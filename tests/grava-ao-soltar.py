#!/usr/bin/env python3
import importlib.util
import json
import os
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
ESPERA = "() => EM_VOO === 0 && !ACOMPANHANDO"


def checa(cond, frase):
    conferidas[0] += 1
    print(("  ok  " if cond else "  XX  ") + frase)
    if not cond:
        falhas.append(frase)
    return cond


def esperar(pag, ms=500):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    esperar(pag)


def assentar(pag):
    pag.wait_for_function(ESPERA, timeout=300000)
    pag.wait_for_timeout(300)


def get(pag, rota):
    return pag.evaluate("async (r) => await api(r)", rota)


def post(pag, rota, corpo):
    return pag.evaluate("async ([r, c]) => await api(r, { method: 'POST', body: JSON.stringify(c) })", [rota, corpo])


def ultimo_trabalho(pag):
    achado = None
    for n in range(1, 60):
        r = get(pag, f"/api/trabalho?id={n}")
        if r.get("erro"):
            break
        achado = r
    return achado


def etapas_do_ultimo(pag):
    t = ultimo_trabalho(pag)
    if not t:
        return None, ""
    return t, "\n".join(t.get("linhas", []))


def oposto(pag, chave):
    return pag.evaluate("""(c) => { const i = CHAVE.get(c); const o = (i.opcoes || []).filter((x) => x && x !== i.valor);
        return o[0] || ''; }""", chave)


def main():
    ambiente = casa.montar_casa()
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
            pag.goto(url)
            esperar(pag, 1000)

            print("1. Q2-05: sem mudança não há Aplicar, e salvar vazio não abre trabalho")
            ir(pag, "ajustes/painel")
            checa(pag.locator("#bt-aplicar").count() == 0 and pag.locator("#botao-ensaiar").count() == 0,
                  "a barra não tem Aplicar nem Ver sem mudar")
            checa(not pag.locator("#conta").is_visible(), "com 0 mudanças a conta some")
            antes = ultimo_trabalho(pag)
            r = post(pag, "/api/salvar", {"mudancas": {}})
            checa(r.get("gravadas") == [] and "trabalho" not in r, f"/api/salvar vazio responde sem trabalho ({r})")
            depois = ultimo_trabalho(pag)
            checa((antes or {}).get("id") == (depois or {}).get("id"), "e nenhum trabalho novo nasceu")
            foto = lambda nome: pag.screenshot(path=os.path.join(FOTOS, nome + ".png")) if FOTOS else None  # noqa: E731

            print("2. Q2-04: soltar uma chave aplica só a etapa dela")
            chave = "FORMA_DOCK_SOLTO"
            valor0 = casa.valor_de(chave)
            pag.locator(f'[data-controle="chave:{chave}"]').click()
            assentar(pag)
            checa(casa.valor_de(chave) != valor0, f"o meow.conf mudou sem Aplicar ({valor0} -> {casa.valor_de(chave)})")
            t, texto = etapas_do_ultimo(pag)
            checa(t is not None and t.get("rotulo", "").lower().startswith("aplicar"), f"o trabalho é o da aplicação ({(t or {}).get('rotulo')!r})")
            checa("1 etapa" in texto, "e rodou uma etapa só")
            checa("forma" in texto.lower() and "icones" not in texto.lower(), "a etapa é a forma")
            checa(pag.locator("#gravando").get_attribute("data-estado") == "ok", "o indicador volta a «ok»")
            checa(pag.locator("#conta").inner_text() == "1 mudança", "a barra diz «1 mudança»")

            print("3. Q2-21: duas colunas, dois rótulos")
            pag.locator('[data-controle="chave:FORMA_PAINEL_SOLTO"]').click()
            assentar(pag)
            pag.locator("#conta").click()
            rotulos = pag.locator("#ultimas .ultima b").all_inner_texts()
            checa(rotulos == ["Solta da borda (barra de cima)", "Solta da borda (dock)"], f"a lista diz a coluna ({rotulos})")
            detalhes = pag.locator("#ultimas .ultima small").all_inner_texts()
            checa(all("→" in d for d in detalhes), f"e o antes e o depois ({detalhes})")
            foto("barra-aberta")
            valor_painel = casa.valor_de("FORMA_PAINEL_SOLTO")
            pag.locator("#ultimas .ultima").first.locator("button").click()
            assentar(pag)
            checa(casa.valor_de("FORMA_PAINEL_SOLTO") != valor_painel, "o Desfazer de um item devolve só aquele no meow.conf")
            checa(pag.evaluate("() => HISTORICO.length") == 1, "e sobra o outro na lista")
            pag.locator("#desfazer").click()
            assentar(pag)
            checa(casa.valor_de(chave) == valor0, "o Desfazer da barra devolve o resto")
            checa(pag.evaluate("() => HISTORICO.length") == 0, "e esvazia a lista")

            print("4. a última passada: um valor que o servidor recusa volta ao que era")
            antes_sec = casa.valor_de("RELOGIO_SEGUNDOS")
            pag.evaluate("() => escolher('RELOGIO_SEGUNDOS', 'talvez')")
            assentar(pag)
            checa(casa.valor_de("RELOGIO_SEGUNDOS") == antes_sec, "o meow.conf não mudou")
            checa(pag.locator("#gravando").get_attribute("data-estado") == "erro", "o indicador mostra o erro")
            checa(pag.evaluate("() => MUDANCAS.size") == 0 and pag.evaluate("() => HISTORICO.length") == 0,
                  "e nada ficou pendente nem na lista")
            foto("erro")

            print("5. a lista guarda as últimas 20")
            pag.evaluate("""async () => { for (let i = 0; i < 22; i++) {
                await escolher('LOG_NIVEL', i % 2 ? 'info' : 'debug'); await FILA_DE_GRAVACAO; } }""")
            assentar(pag)
            checa(pag.evaluate("() => HISTORICO.length") == 20, "20 entradas")
            checa(pag.locator("#conta").inner_text() == "20 mudanças", "a barra diz «20 mudanças»")
            pag.locator("#desfazer").click()
            assentar(pag)

            print("6. Q3-07: chave que precisa da ponte, sem a ponte, vira pendência")
            plano = pag.evaluate("() => 0")
            alvo = "LANCADOR_OCULTAR"
            novo = (casa.valor_de(alvo) or "") + ",teste-de-ponte"
            r = post(pag, "/api/definir", {"chave": alvo, "valor": novo})
            checa(r.get("sem_ponte") is True and r.get("aplicando") is False, f"o servidor recusa aplicar sem a ponte ({r})")
            ids = [x["id"] for x in get(pag, "/api/pendencias").get("pendencias", [])]
            checa("aplicar-ajuste" in ids, f"e deixa a pendência ({ids})")
            post(pag, "/api/definir", {"chave": alvo, "valor": casa.valor_de(alvo).replace(",teste-de-ponte", "")})

            print("7. Q1-14: o Personalizar grava ao soltar")
            ir(pag, "criar/sons")
            ctl = pag.locator('[data-controle="chave:SOM_FUNDAMENTAL"]')
            if checa(ctl.count() == 1, "o controle «Primeira nota» existe"):
                tipo = ctl.get_attribute("type")
                v0 = casa.valor_de("SOM_FUNDAMENTAL")
                if tipo == "range":
                    ctl.evaluate("""(el) => { el.value = String(Number(el.max) - 1); el.dispatchEvent(new Event('input', {bubbles: true}));
                        el.dispatchEvent(new Event('change', {bubbles: true})); }""")
                else:
                    ctl.fill("700")
                    ctl.press("Tab")
                assentar(pag)
                checa(casa.valor_de("SOM_FUNDAMENTAL") != v0, f"o meow.conf mudou sem Aplicar ({v0!r} -> {casa.valor_de('SOM_FUNDAMENTAL')!r})")
                checa(pag.evaluate("() => HISTORICO.length") == 1, "e a barra tem a mudança para desfazer")
                pag.locator("#desfazer").click()
                assentar(pag)
                checa(casa.valor_de("SOM_FUNDAMENTAL") == v0, "o Desfazer devolve o valor")
            print("8. P143: o lote velho que volta depois do novo não apaga o valor novo")
            chave8 = "LOG_NIVEL"
            valor8 = casa.valor_de(chave8)
            opcoes8 = pag.evaluate("(c) => (CHAVE.get(c).opcoes || []).filter((x) => x)", chave8)
            va, vb = [o for o in opcoes8 if o != valor8][:2]
            seguradas = []
            pag.route("**/api/definir", lambda rota: seguradas.append(rota))
            pag.evaluate("([c, a, b]) => { gravarAgora({[c]: a}); gravarAgora({[c]: b}); }", [chave8, va, vb])
            pag.wait_for_function("() => EM_VOO === 2", timeout=10000)
            for _ in range(100):
                if seguradas:
                    break
                pag.wait_for_timeout(50)
            checa(len(seguradas) == 1, "o primeiro lote está na rede e o segundo espera na fila")
            seguradas.pop(0).continue_()
            pag.wait_for_function("() => EM_VOO === 1", timeout=10000)
            checa(pag.evaluate("(c) => MUDANCAS.get(c)", chave8) == vb,
                  "com o primeiro respondido, a mudança mais nova continua pendente")
            checa(pag.evaluate("(c) => valorEmVigor(CHAVE.get(c))", chave8) == vb,
                  "e a tela fica no valor do segundo, sem voltar ao do primeiro")
            for _ in range(100):
                if seguradas:
                    break
                pag.wait_for_timeout(50)
            seguradas.pop(0).continue_()
            pag.unroute("**/api/definir")
            assentar(pag)
            checa(casa.valor_de(chave8) == vb and pag.evaluate("(c) => CHAVE.get(c).valor", chave8) == vb
                  and pag.evaluate("() => MUDANCAS.size") == 0,
                  "no fim o conf, a tela e a lista ficam com o valor do segundo")
            pag.locator("#desfazer").click()
            assentar(pag)

            print("9. P143: o lote de duas chaves que cai na rede não leva a mudança mais nova de uma delas")
            outra9 = pag.evaluate("""(c) => [...CHAVE.values()].find((i) => i.chave !== c
                && (i.opcoes || []).filter((x) => x && x !== String(i.valor ?? '')).length)?.chave""", chave8)
            v_outra = pag.evaluate("(c) => String(CHAVE.get(c).valor ?? '')", outra9)
            x_outra = pag.evaluate("(c) => CHAVE.get(c).opcoes.filter((x) => x && x !== String(CHAVE.get(c).valor ?? ''))[0]", outra9)
            caidas, seguradas = [], []
            pag.route("**/api/salvar", lambda rota: caidas.append(rota))
            pag.route("**/api/definir", lambda rota: seguradas.append(rota))
            pag.evaluate("([c, a, o, x, b]) => { gravarAgora({[c]: a, [o]: x}); gravarAgora({[c]: b}); }",
                         [chave8, va, outra9, x_outra, vb])
            for _ in range(100):
                if caidas:
                    break
                pag.wait_for_timeout(50)
            checa(len(caidas) == 1 and not seguradas, f"o lote de {chave8} e {outra9} está na rede e o novo espera")
            caidas.pop(0).abort()
            pag.unroute("**/api/salvar")
            pag.wait_for_function("() => EM_VOO === 1", timeout=10000)
            checa(pag.evaluate("(c) => MUDANCAS.get(c)", chave8) == vb and not pag.evaluate("(o) => MUDANCAS.has(o)", outra9),
                  "com o lote caído, a mudança mais nova continua pendente e a da outra chave sai")
            checa(pag.evaluate("(c) => valorEmVigor(CHAVE.get(c))", chave8) == vb
                  and pag.evaluate("(o) => valorEmVigor(CHAVE.get(o))", outra9) == v_outra,
                  "a tela fica no valor novo de uma e no de antes da outra")
            for _ in range(100):
                if seguradas:
                    break
                pag.wait_for_timeout(50)
            seguradas.pop(0).continue_()
            pag.unroute("**/api/definir")
            assentar(pag)
            checa(casa.valor_de(chave8) == vb and pag.evaluate("(c) => valorEmVigor(CHAVE.get(c))", chave8) == vb,
                  "a chave que o lote novo repetiu fica com o valor dele, no conf e na tela")
            checa(casa.valor_de(outra9) == v_outra and pag.evaluate("(c) => valorEmVigor(CHAVE.get(c))", outra9) == v_outra
                  and pag.evaluate("() => MUDANCAS.size") == 0,
                  "a outra chave volta ao valor de antes e nada fica pendente")
            pag.locator("#desfazer").click()
            assentar(pag)

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

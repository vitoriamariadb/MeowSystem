#!/usr/bin/env python3
import importlib.util
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

falhas = []
conferidas = [0]
ESPERA = "() => EM_VOO === 0 && !ACOMPANHANDO"
FABRICA = {"Panel": {"margin": "2", "border_radius": "0", "spacing": "3", "padding": "1", "opacity": "1.0",
                     "anchor_gap": "false", "expand_to_edges": "true", "size": "XS"},
           "Dock": {"margin": "4", "border_radius": "160", "spacing": "0", "padding": "4", "opacity": "1.0",
                    "anchor_gap": "true", "expand_to_edges": "false", "size": "L"}}
NA_MAQUINA = {"margin": "7", "spacing": "9", "padding": "6"}
CHAVES = {"FORMA_MARGEM_PAINEL": ("Panel", "margin"), "FORMA_ESPACO_PAINEL": ("Panel", "spacing"),
          "FORMA_RECHEIO_PAINEL": ("Panel", "padding")}


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
    pag.wait_for_timeout(500)


def arquivo(barra, nome):
    return os.path.join(casa.CASA, ".config", "cosmic", f"com.system76.CosmicPanel.{barra}", "v1", nome)


def ler(barra, nome):
    try:
        with open(arquivo(barra, nome), encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return None


def plantar(pasta_base, barra, valores):
    pasta = os.path.join(pasta_base, f"com.system76.CosmicPanel.{barra}", "v1")
    os.makedirs(pasta, exist_ok=True)
    for nome, valor in valores.items():
        with open(os.path.join(pasta, nome), "w", encoding="utf-8") as fh:
            fh.write(valor)


def numero_da_faixa(pag, chave):
    return pag.evaluate("(c) => document.querySelector('[data-controle=\"chave:' + c + '\"]').value", chave)


def saida_da_faixa(pag, chave):
    return pag.evaluate("(c) => document.querySelector('[data-controle=\"chave:' + c + '\"]').closest('.faixa').querySelector('output').textContent", chave)


def main():
    ambiente = casa.montar_casa()
    sistema = os.path.join(casa.BRINQUEDO, "cosmic-de-fabrica")
    for barra, valores in FABRICA.items():
        plantar(sistema, barra, valores)
        plantar(os.path.join(casa.CASA, ".config", "cosmic"), barra, dict(FABRICA[barra], **(NA_MAQUINA if barra == "Panel" else {})))
    ambiente["MEOW_COSMIC_SISTEMA"] = sistema
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o painel não subiu")
        return 2
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_context(viewport={"width": 1550, "height": 860}).new_page()
            erros = []
            pag.on("pageerror", lambda e: erros.append(str(e)))
            pag.goto(url)
            esperar(pag, 1000)
            ir(pag, "ajustes/painel")

            for chave, (barra, nome) in CHAVES.items():
                fabrica = FABRICA[barra][nome]
                print(f"1. {chave}: arrastar, ↶, e a faixa e o arquivo do COSMIC ficam em {fabrica}")
                checa(saida_da_faixa(pag, chave) == NA_MAQUINA[nome], f"a faixa abre no número da máquina ({saida_da_faixa(pag, chave)})")
                checa(pag.locator(f'[data-controle="padrao:{chave}"]').count() == 1, "e o ↶ já aparece, porque a máquina não está de fábrica")
                pag.evaluate("""(c) => { const s = document.querySelector('[data-controle="chave:' + c + '"]');
                    s.value = '5'; s.dispatchEvent(new Event('input', { bubbles: true }));
                    s.dispatchEvent(new Event('change', { bubbles: true })); }""", chave)
                assentar(pag)
                checa(ler(barra, nome) == "5", f"arrastar escreve 5 no arquivo do COSMIC ({ler(barra, nome)})")
                pag.locator(f'[data-controle="padrao:{chave}"]').click()
                assentar(pag)
                checa(ler(barra, nome) == fabrica, f"o ↶ escreve o de fábrica no arquivo do COSMIC ({ler(barra, nome)})")
                checa(casa.valor_de(chave) == "", "e esvazia a chave no meow.conf")
                checa(saida_da_faixa(pag, chave) == fabrica and numero_da_faixa(pag, chave) == fabrica,
                      f"e a faixa pula para o número de fábrica ({saida_da_faixa(pag, chave)})")
                checa(pag.locator(f'[data-controle="padrao:{chave}"]').count() == 0, "e o ↶ some")

            print("2. a segunda passada não escreve nada")
            antes = os.stat(arquivo("Panel", "spacing")).st_mtime_ns
            r = pag.evaluate("""async () => await api('/api/definir', { method: 'POST',
                body: JSON.stringify({ chave: 'FORMA_ESPACO_PAINEL', valor: '', fabrica: true }) })""")
            assentar(pag)
            checa(r.get("rc") == 0, f"o servidor aceita o gesto ({r.get('rc')})")
            checa(os.stat(arquivo("Panel", "spacing")).st_mtime_ns == antes, "o arquivo do COSMIC não foi reescrito")

            print("3. sem o arquivo do COSMIC na máquina, a faixa abre no de fábrica, e não no mínimo")
            os.remove(arquivo("Panel", "spacing"))
            pag.evaluate("async () => { await recarregarEsquema(); render(); }")
            esperar(pag)
            checa(saida_da_faixa(pag, "FORMA_ESPACO_PAINEL") == FABRICA["Panel"]["spacing"],
                  f"a faixa mostra {FABRICA['Panel']['spacing']} e não 0 ({saida_da_faixa(pag, 'FORMA_ESPACO_PAINEL')})")
            print("4. o canto da dock de fábrica passa do fim da escala, e a faixa diz o número real")
            topo = pag.evaluate("() => document.querySelector('[data-controle=\"chave:FORMA_RAIO_DOCK\"]').max")
            checa(saida_da_faixa(pag, "FORMA_RAIO_DOCK") == FABRICA["Dock"]["border_radius"],
                  f"a faixa diz {FABRICA['Dock']['border_radius']} ({saida_da_faixa(pag, 'FORMA_RAIO_DOCK')}), e não o fim da escala ({topo})")
            checa(numero_da_faixa(pag, "FORMA_RAIO_DOCK") == topo, f"e o botão da faixa fica no fim dela ({numero_da_faixa(pag, 'FORMA_RAIO_DOCK')})")
            checa(pag.locator('[data-controle="padrao:FORMA_RAIO_DOCK"]').count() == 0, "e sem ↶, porque já está de fábrica")
            print("5. sem o patch do compositor, o teto de segurança é o mais perto da fábrica que dá, e o ↶ some")
            def sem_patch(agora):
                pag.evaluate("""(v) => { const i = CHAVE.get('FORMA_RAIO_DOCK');
                    i.teto = { valor: 0, trava: true, estado: 'sem' }; i.valendo_agora = v; render(); }""", agora)
                return pag.locator('[data-controle="padrao:FORMA_RAIO_DOCK"]').count()
            checa(sem_patch("0") == 0, "no teto (0), sem ↶")
            checa(sem_patch("5") == 1, "acima do teto (5), o ↶ volta")
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

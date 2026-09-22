#!/usr/bin/env python3
"""app-acessibilidade.py — os tres numeros da P6, medidos na pagina em pe.

    tests/app-acessibilidade.py             roda a conferencia
    tests/app-acessibilidade.py --detalhe   lista quem reprovou, um por linha

POR QUE ESTE ARQUIVO EXISTE, NAS PALAVRAS DELA (21/09/2026)
  "aqui outra falha: botao impossivel de clicar devido a largura da imagem."

  O que cobre o botao nao e' a imagem: e' o balao do botao vizinho. Medido com
  o painel no ar, as 14 abas percorridas uma a uma, ANTES da P6 — e sao estes
  os numeros que este arquivo devolveu rodando contra o codigo de 20/09:

      alvos abaixo de 24 px ................... 200 de 1105
                                                (176 botoes, 119 numa aba so';
                                                 o resto e' deslizante e ficha)
      baloes acima de 80 caracteres ........... 243 de 1005
                                                (301 passavam de 60; o maior
                                                 tinha 154 caracteres)
      baloes com um comando `meow` cru dentro . 159
                                                (119 deles entre parenteses, na
                                                 ficha de imagem; os outros 40
                                                 eram o comando inteiro)

  A sprint P6 trocou o `title` nativo por um balao proprio, poe um piso de
  24 px em todo alvo de clique e manda o comando para um botao "ver comando".
  Este arquivo e' o que impede os tres numeros de voltarem.

O QUE ELE MEDE, E POR QUE ASSIM
  1. ALVO DE CLIQUE ABAIXO DE 24 PX (WCAG 2.2, criterio 2.5.8). Conta todo
     elemento que recebe clique ou foco e tem caixa na tela. O botao escondido
     por `display:none` nao conta — ele nao e' alvo de nada; o botao da ficha
     de imagem, que so' aparece no hover, CONTA: ele e' alcancavel pelo teclado
     e pelo rato, e era ele a queixa.
  2. BALAO ACIMA DE 80 CARACTERES. Balao e' legenda de botao, nao documentacao
     dele. O censo olha o `data-balao` (o balao nosso) E o `title` (o nativo)
     pelo mesmo nome de propósito: se alguem reintroduzir um `title`, ele cai
     nesta mesma conta em vez de escapar por baixo dela.
  3. BALAO COM COMANDO `meow` DENTRO. O comando tem lugar — o "ver comando" do
     cartao, com um Copiar — e nao e' o balao.

  E UM QUARTO, QUE NAO E' NUMERO E IMPORTA TANTO QUANTO: o balao tem de
  aparecer no FOCO. O `title` nativo, por pior que seja, aparecia; um
  substituto que so' responda ao rato piora a acessibilidade em vez de
  melhorar. O passo 4 exercita o Tab e confere que o balao nasce, que ele fica
  FORA da fileira de botoes, e que o Escape o fecha.

O QUE ELE NAO FAZ
  Nao clica em nada que escreva: nenhuma acao e' executada, nenhuma chave e'
  gravada, nem o Salvar e' apertado. A conferencia e' de medida, e medir a
  pagina nao muda a maquina de quem mede.

DEPENDENCIA, E A DEGRADACAO QUANDO ELA FALTA
  A mesma disciplina do `tests/app-navegador.py`: sem Playwright no
  interpretador, SAI 3 (pulado) com a receita na tela, em vez de falhar.

      python3 -m venv ~/.local/share/meowsystem/venv-testes
      ~/.local/share/meowsystem/venv-testes/bin/pip install playwright
      ~/.local/share/meowsystem/venv-testes/bin/playwright install chromium
"""
import os
import re
import subprocess
import sys
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DETALHE = "--detalhe" in sys.argv
PISO_PX = 24
TETO_BALAO = 80

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("pulado: playwright nao esta instalado neste interpretador.")
    print("  " + sys.executable)
    print("  receita no cabecalho de tests/app-acessibilidade.py")
    sys.exit(3)


# O CENSO DE UMA ABA, COLHIDO DE UMA VEZ.
#   Abrir as 14 abas ja' custa alguns segundos; medir cada alvo e cada balao
#   enquanto a aba esta' na tela custa um `evaluate` por aba, e nao uma segunda
#   volta pela pagina inteira.
CENSO_JS = """
() => {
  const SELETOR_ALVO = 'button, a[href], input:not([type=hidden]), select,'
                     + ' textarea, summary, [role=button],'
                     + ' [tabindex]:not([tabindex="-1"])';
  const visivel = (el, r) => {
    if (r.width === 0 && r.height === 0) return false;   // sem caixa na tela
    const cs = getComputedStyle(el);
    return cs.display !== 'none' && cs.visibility !== 'hidden';
  };
  const alvos = [];
  let medidos = 0;
  for (const el of document.querySelectorAll(SELETOR_ALVO)) {
    const r = el.getBoundingClientRect();
    if (!visivel(el, r)) continue;
    medidos++;
    if (r.width >= 24 && r.height >= 24) continue;
    alvos.push({
      tag: el.tagName.toLowerCase(),
      classe: (el.className || '').toString().slice(0, 40),
      rotulo: (el.textContent || el.getAttribute('aria-label') || '').trim().slice(0, 28),
      w: Math.round(r.width), h: Math.round(r.height),
    });
  }
  /* O `title` entra no MESMO censo do `data-balao`, e nao num censo ao lado:
     um `title` que volte e' um balao nativo de volta, e tem de reprovar aqui
     em vez de sumir da conta. */
  const baloes = [...document.querySelectorAll('[data-balao], [title]')].map((el) => ({
    texto: el.getAttribute('data-balao') || el.getAttribute('title') || '',
    nativo: el.hasAttribute('title'),
    tag: el.tagName.toLowerCase(),
    classe: (el.className || '').toString().slice(0, 40),
  }));
  return { alvos, medidos, baloes };
}
"""

# O COMANDO CRU DENTRO DO BALAO.
#   `meow` seguido de um verbo, com ou sem parenteses a' volta — que era a
#   forma dos 119 —, e tambem o caminho absoluto do `bin/meow` ou de um script
#   do projeto, que e' a mesma coisa escrita por extenso. `meow.conf` NAO casa:
#   e' o nome de um arquivo, e falar dele em portugues e' legitimo.
COMANDO_NO_BALAO = re.compile(r"(?:^|[(\s/])meow\s+[a-z]|\S+\.sh\s")


def sobe_servidor():
    """Sobe o painel e devolve (processo, url). A URL sai na PRIMEIRA linha do
    `--sem-abrir` — e e' a unica forma de saber a porta, que o kernel escolhe."""
    proc = subprocess.Popen(
        [os.path.join(RAIZ, "app", "run.sh"), "--sem-abrir"],
        cwd=RAIZ, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    url = None
    inicio = time.time()
    while time.time() - inicio < 40:
        linha = proc.stdout.readline()
        if not linha:
            break
        m = re.search(r"http://127\.0\.0\.1:\d+/\?t=[A-Za-z0-9_-]+", linha)
        if m:
            url = m.group(0)
            break
    return proc, url


def percorrer(pag):
    """Abre as abas uma a uma e devolve (pequenos, medidos, baloes) da pagina.

    `pequenos` sao os alvos que reprovaram; `medidos` e' quantos foram olhados,
    e ele e' o denominador — sem ele um "0 reprovado" tambem e' o que um
    seletor quebrado devolve."""
    pequenos, medidos, baloes = [], 0, []
    nomes = pag.locator("#trilho button").all_text_contents()
    for i in range(len(nomes)):
        pag.locator("#trilho button").nth(i).click()
        pag.wait_for_timeout(700)
        # O nome do botao do trilho traz a contagem colada no fim ("Painel e
        # dock12"); no relatorio isso vira um numero sem dono, entao ele sai.
        aba = re.sub(r"\s*\d+$", "", nomes[i].strip())
        d = pag.evaluate(CENSO_JS)
        for x in d["alvos"]:
            x["aba"] = aba
        for x in d["baloes"]:
            x["aba"] = aba
        pequenos += d["alvos"]
        medidos += d["medidos"]
        baloes += d["baloes"]
        print(f"  {aba[:34]:36s} alvos={d['medidos']:4d}"
              f"  abaixo de {PISO_PX} px={len(d['alvos']):4d}"
              f"  baloes={len(d['baloes']):4d}")
    return pequenos, medidos, baloes


# O BALAO NO TECLADO — o risco declarado da sprint.
#   `:focus-visible` so' casa quando o foco veio do teclado. Um `Tab` de
#   verdade antes do `focus()` e' o que poe o navegador nessa modalidade; sem
#   ele o teste mediria o clique, que e' justamente onde o balao NAO deve
#   nascer.
FOCO_JS = """
(sel) => {
  const alvo = document.querySelector(sel);
  if (!alvo) return { erro: 'nao achei ' + sel };
  alvo.focus();
  const b = document.getElementById('balao');
  const visto = !!b && !b.hidden;
  const rb = visto ? b.getBoundingClientRect() : null;
  /* O balao nao pode cobrir os IRMAOS do botao — era exatamente isso que o
     nativo fazia, e e' a queixa inteira desta sprint. */
  let cobre = [];
  if (rb) {
    for (const irmao of alvo.parentElement.children) {
      if (irmao === alvo) continue;
      const r = irmao.getBoundingClientRect();
      if (r.width === 0 && r.height === 0) continue;
      const cruza = rb.left < r.right && rb.right > r.left
                 && rb.top < r.bottom && rb.bottom > r.top;
      if (cruza) cobre.push((irmao.textContent || '').trim().slice(0, 20));
    }
  }
  return {
    visto,
    texto: visto ? b.textContent : '',
    descrito: alvo.getAttribute('aria-describedby') || '',
    cobre,
  };
}
"""


def main():
    proc, url = sobe_servidor()
    if not url:
        print("XX o app/run.sh nao imprimiu a URL — nada a medir")
        proc.terminate()
        return 2

    falhas = []
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1600, "height": 900})
            # `networkidle` nunca chega: o painel mantem o `EventSource` do
            # pulso aberto de proposito, e ele conta como rede viva.
            pag.goto(url, wait_until="domcontentloaded")
            pag.wait_for_timeout(3000)

            print("\n1. AS ABAS, UMA A UMA")
            pequenos, medidos, baloes = percorrer(pag)

            print("\n2. O BALAO NO TECLADO (o risco declarado da sprint)")
            # A ficha de imagem e' onde a queixa nasceu: quatro botoes lado a
            # lado, e o balao de um cobria os outros tres.
            pag.locator('#trilho button:has-text("Papel de parede")').first.click()
            pag.wait_for_timeout(1200)
            pag.keyboard.press("Tab")
            pag.wait_for_timeout(120)
            r = pag.evaluate(FOCO_JS, ".galeria .acoes .btn[data-balao]")
            if r.get("erro"):
                falhas.append(f"o foco nao pode ser medido: {r['erro']}")
                print("  XX " + r["erro"])
            else:
                for cond, frase in [
                    (r["visto"], "o balao aparece no foco do teclado"),
                    (r["descrito"] == "balao",
                     "o botao focado aponta para o balao por aria-describedby"),
                    (not r["cobre"],
                     "o balao nao cobre nenhum botao irmao"
                     + (f" (cobre {r['cobre']})" if r["cobre"] else "")),
                    (len(r["texto"]) <= TETO_BALAO,
                     f"o balao do foco tem {len(r['texto'])} caracteres"),
                ]:
                    print(("  ok " if cond else "  XX ") + frase)
                    if not cond:
                        falhas.append(frase)
                pag.keyboard.press("Escape")
                pag.wait_for_timeout(150)
                fechou = pag.evaluate(
                    "() => { const b = document.getElementById('balao');"
                    " return !b || b.hidden; }")
                print(("  ok " if fechou else "  XX ") + "o Escape fecha o balao")
                if not fechou:
                    falhas.append("o Escape fecha o balao")
            nav.close()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()

    compridos = [b for b in baloes if len(b["texto"]) > TETO_BALAO]
    com_comando = [b for b in baloes if COMANDO_NO_BALAO.search(b["texto"])]
    nativos = [b for b in baloes if b["nativo"]]

    print("\n3. OS TRES NUMEROS")
    print(f"alvos com menos de {PISO_PX} px ................. "
          f"{len(pequenos)}   (antes da P6: 200)")
    print(f"baloes com mais de {TETO_BALAO} caracteres ......... "
          f"{len(compridos)}   (antes da P6: 243)")
    print(f"baloes com comando meow dentro ........... "
          f"{len(com_comando)}   (antes da P6: 159)")
    print(f"\n({medidos} alvos e {len(baloes)} baloes medidos nas 14 abas; "
          f"{len(nativos)} baloes ainda sao `title` nativo)")

    if DETALHE:
        print("\n--- quem reprovou -------------------------------------------")
        for a in pequenos:
            print(f"  alvo  {a['w']:4d}x{a['h']:<4d} [{a['aba'][:16]:16s}]"
                  f" {a['tag']}.{a['classe'][:26]} {a['rotulo']!r}")
        for b in compridos:
            print(f"  balao {len(b['texto']):4d} car [{b['aba'][:16]:16s}]"
                  f" {b['texto'][:90]!r}")
        for b in com_comando:
            print(f"  cmd        [{b['aba'][:16]:16s}] {b['texto'][:90]!r}")

    if pequenos:
        falhas.append(f"{len(pequenos)} alvos abaixo de {PISO_PX} px")
    if compridos:
        falhas.append(f"{len(compridos)} baloes acima de {TETO_BALAO} caracteres")
    if com_comando:
        falhas.append(f"{len(com_comando)} baloes com comando meow dentro")
    if nativos:
        falhas.append(f"{len(nativos)} baloes ainda sao `title` nativo")

    print()
    if falhas:
        for f in falhas:
            print("XX " + f)
        print(f"\n{len(falhas)} reprovacoes.")
        return 1
    print("ok  os tres numeros estao em zero, e o balao responde ao teclado.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

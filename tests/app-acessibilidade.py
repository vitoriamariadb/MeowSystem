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
  melhorar. O passo 3 exercita o Tab e confere que o balao nasce, que ele fica
  FORA da fileira de botoes, e que o Escape o fecha.

  E O TETO DE 80 E' MEDIDO DUAS VEZES — 21/09/2026
    Porque medi-lo uma so' vez, na tela, nao o media. O `partirAjuda` apara
    antes de escrever o atributo, entao o `data-balao` devolve 80 mesmo para
    uma frase de 200 na fonte; e o elemento de um botao que so' nasce em certo
    estado nunca e' pintado para ser medido. As duas metades estao fechadas: o
    passo 1 le' a FONTE (e nao depende de pintar nada) e o passo 4 conta a
    PEGADA da apara (`data-balao-aparado`), que cobre a frase montada com dado
    de fora. O porque' de cada um esta' junto do codigo de cada um.

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
  const baloes = [...document.querySelectorAll(
    '[data-balao], [title], [data-balao-aparado]')].map((el) => ({
    texto: el.getAttribute('data-balao') || el.getAttribute('title') || '',
    nativo: el.hasAttribute('title'),
    /* O COMPRIMENTO QUE A FRASE TINHA NA FONTE, quando a rede do `partirAjuda`
       teve de apara-la. Medir so' o `data-balao` mede DEPOIS da apara, e ai'
       uma frase de 200 caracteres devolve 80 e passa — a rede apagando a
       propria pegada. Aqui ele vem junto, e o passo 4 exige zero. */
    aparado: Number(el.getAttribute('data-balao-aparado') || 0),
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
#
#   O `.sh` NO FIM DO BALAO TAMBEM CONTA — corrigido em 21/09/2026
#     A primeira versao pedia `\S+\.sh\s`, com espaco OBRIGATORIO depois, e com
#     isso um balao que TERMINASSE no nome do script escapava da conta inteira:
#     "roda o ~/bin/meow-pack.sh" passava. Buraco numa rede e' pior que rede
#     nenhuma, porque ela declara cobrir o que nao cobre. Agora o fim da frase
#     fecha o casamento como um espaco fecharia.
#
#   E O LADO FALSO-POSITIVO FICA COMO ESTA, de proposito: `meow\s+[a-z]` pega
#   tambem uma frase legitima que comece com "meow " mais minuscula ("o meow le
#   o arquivo"). Distinguir exigiria a lista dos verbos do `meow`, que e' a
#   armadilha nº 3 do projeto — lista fixa que alguem vai esquecer de crescer. E
#   o erro cai para o lado seguro: um falso positivo REPROVA e alguem le a
#   frase; um falso negativo passa calado, que e' o que esta rede veio matar.
COMANDO_NO_BALAO = re.compile(r"(?:^|[(\s/])meow\s+[a-z]|\S+\.sh(?:\s|$)")


# O TETO DE 80 MEDIDO NA FONTE, E NAO SO' NA TELA — 21/09/2026
#   A sprint pede "limite duro de 80 caracteres — o teste falha acima disso", e
#   a primeira versao deste arquivo nao cumpria isso por dois motivos somados:
#   o `partirAjuda` APARA antes de escrever o `data-balao`, e a varredura das 14
#   abas so' ve' o que a pagina pinta. O caso que escapou tinha as duas coisas:
#   a frase de 83 caracteres do «Desfazer N escolhas» saia mutilada na tela
#   ("O meow.conf nao e'…", que diz o oposto do que a frase existe para dizer) e
#   o botao so' nasce quando ha escolha pendente no bloco — estado que a
#   varredura nunca alcanca. Verde por duas ausencias.
#
#   A apara agora deixa marca (`data-balao-aparado`, contada no passo 4). Esta
#   leitura da FONTE cobre a outra metade: a frase escrita a mao acima do teto
#   aparece mesmo que o elemento dela nunca seja pintado. Rodada contra o
#   commit que a introduziu, ela devolve exatamente aquela linha.
#
# POR QUE SO' `app.js` E `index.html`
#   E' onde o balao e' AUTORADO. As ajudas do `servidor.py` sao, na quase
#   totalidade, prosa VISIVEL do cartao de acao — medi-las por este teto
#   reprovaria vinte frases que nunca viram balao. As quatro que viram (os
#   botoes do cabecalho da Inicio) passam pelo `porBalao` na aba Inicio, que a
#   varredura percorre, e caem na marca da apara se estourarem.
#
# O QUE FICA DE FORA, DITO EM VOZ ALTA
#   Frase MONTADA (`${…}`) nao entra: o comprimento dela depende do dado, e e'
#   exatamente para ela que a rede do `partirAjuda` existe — quem cuida desse
#   caso e' a marca da apara. E o denominador ("N frases fixas medidas") sai na
#   tela de proposito: um "0 reprovado" tambem e' o que uma expressao quebrada
#   devolve, e sem o denominador os dois se parecem.
LITERAL = r'"(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\'|`(?:[^`\\]|\\.)*`'
_VALOR = r'((?:' + LITERAL + r')(?:\s*\+\s*(?:' + LITERAL + r'))*)'
# A ANCORA DE POSICAO NAO E' ZELO: sem exigir inicio de linha, `{` ou `,` antes
# da chave, o `title` CITADO num comentario casa, e o literal de crase que vem
# depois dele engole o comentario inteiro — um achado de 1195 caracteres que
# nao existe na tela. A chave tem de estar em posicao de propriedade.
AJUDA_NA_FONTE = {
    "app/pagina/app.js": re.compile(
        r'(?:^[ \t]*|[{,][ \t]*)(?:title|titulo):\s*' + _VALOR, re.M),
    "app/pagina/index.html": re.compile(r'\stitle=\s*' + _VALOR),
}


def frases_fixas():
    """Devolve (quantas foram medidas, as que passam do teto na FONTE)."""
    medidas, compridas = 0, []
    for rel, padrao in AJUDA_NA_FONTE.items():
        with open(os.path.join(RAIZ, rel), encoding="utf-8") as f:
            src = f.read()
        for m in padrao.finditer(src):
            pecas = re.findall(LITERAL, m.group(1))
            txt = "".join(p[1:-1] for p in pecas)
            if "${" in txt:
                continue
            txt = txt.replace('\\"', '"').replace("\\'", "'")
            medidas += 1
            if len(txt) > TETO_BALAO:
                compridas.append((rel, src.count("\n", 0, m.start()) + 1,
                                  len(txt), txt))
    return medidas, compridas


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
    falhas = []

    # Este passo nao precisa de navegador nem de painel no ar, e vem primeiro
    # por isso: se a frase esta comprida na fonte, nao ha o que medir na tela.
    print("1. O TETO DE 80 NA FONTE (antes da apara, e mesmo sem pintar)")
    medidas, compridas = frases_fixas()
    for rel, linha, tam, txt in compridas:
        print(f"  XX {rel}:{linha}  {tam} caracteres  {txt[:70]!r}")
    print(f"  {len(compridas)} acima de {TETO_BALAO}, "
          f"de {medidas} frases fixas medidas")
    if compridas:
        falhas.append(f"{len(compridas)} frases fixas acima de "
                      f"{TETO_BALAO} caracteres na fonte")
    if not medidas:
        falhas.append("nenhuma frase fixa foi encontrada na fonte — "
                      "a leitura quebrou, e um zero assim nao e' verde")

    proc, url = sobe_servidor()
    if not url:
        print("XX o app/run.sh nao imprimiu a URL — nada a medir")
        proc.terminate()
        return 2

    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1600, "height": 900})
            # `networkidle` nunca chega: o painel mantem o `EventSource` do
            # pulso aberto de proposito, e ele conta como rede viva.
            pag.goto(url, wait_until="domcontentloaded")
            pag.wait_for_timeout(3000)

            print("\n2. AS ABAS, UMA A UMA")
            pequenos, medidos, baloes = percorrer(pag)

            print("\n3. O BALAO NO TECLADO (o risco declarado da sprint)")
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
    aparados = [b for b in baloes if b["aparado"]]

    print("\n4. OS TRES NUMEROS, E A PEGADA DA REDE")
    print(f"alvos com menos de {PISO_PX} px ................. "
          f"{len(pequenos)}   (antes da P6: 200)")
    print(f"baloes com mais de {TETO_BALAO} caracteres ......... "
          f"{len(compridos)}   (antes da P6: 243)")
    print(f"baloes com comando meow dentro ........... "
          f"{len(com_comando)}   (antes da P6: 159)")
    # A REDE EXISTE PARA NAO PEGAR NINGUEM, e por isso ela aparece no placar:
    # um balao aparado e' uma frase que estourou o teto na fonte e chegou a' tela
    # mutilada. Zero e' o unico numero aceito aqui.
    print(f"baloes que a rede teve de aparar ......... "
          f"{len(aparados)}   (o teto nao e' para chegar aqui)")
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
        for b in aparados:
            print(f"  aparado {b['aparado']:4d} car na fonte "
                  f"[{b['aba'][:16]:16s}] {b['texto'][:70]!r}")

    if pequenos:
        falhas.append(f"{len(pequenos)} alvos abaixo de {PISO_PX} px")
    if compridos:
        falhas.append(f"{len(compridos)} baloes acima de {TETO_BALAO} caracteres")
    if com_comando:
        falhas.append(f"{len(com_comando)} baloes com comando meow dentro")
    if aparados:
        falhas.append(f"{len(aparados)} baloes que a rede teve de aparar "
                      f"(o maior tinha {max(b['aparado'] for b in aparados)} "
                      f"caracteres na fonte)")
    if nativos:
        falhas.append(f"{len(nativos)} baloes ainda sao `title` nativo")

    print()
    if falhas:
        for f in falhas:
            print("XX " + f)
        print(f"\n{len(falhas)} reprovacoes.")
        return 1
    print("ok  os tres numeros estao em zero, o teto de 80 se sustenta na fonte")
    print("    e na tela, e o balao responde ao teclado.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

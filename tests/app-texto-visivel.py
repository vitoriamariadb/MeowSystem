#!/usr/bin/env python3
"""tests/app-texto-visivel.py — quanto texto cada página do painel põe na tela.

NÃO É GATE, É A RÉGUA DA P77 — 09/10/2026
  Quem usa pediu «sem texto na interface; no máximo vira dica». Para a prova da
  P77 dizer que o texto caiu, a medida tem de ser a mesma antes e depois, na
  mesma casa, com o mesmo critério. Este arquivo é essa medida, e só ela:
  percorre as páginas do menu como quem clica, e conta o texto que o olho vê.

O QUE CONTA COMO «VISÍVEL»
  Cada nó de texto dentro de `#conteudo` cujo elemento pai está desenhado
  (`checkVisibility`, com opacidade e `visibility`) e que NÃO mora numa dica:
  `.dica`, `[role=tooltip]` e o `#balao`. Espaços colapsados. O menu lateral e o
  cabeçalho do topo ficam fora: são os mesmos em toda página, e o que a P77 muda
  é o conteúdo. Saem três números por página:
    · `caracteres`: o total;
    · `frases`: blocos de texto com 60 caracteres ou mais (o parágrafo que a
      quem usa pediu para sumir);
    · `comando`: caracteres dentro de `<code>` visível (o comando cru que só
      deveria aparecer no «ver comando»).

A CASA É A DO `tests/app-completo.py`
  O painel escreve na máquina, e a decisão 8 de 02-decisoes.md manda o painel
  de QA subir SÓ com HOME temporário. Em vez de copiar a casa de brinquedo, este
  arquivo a importa de lá: a mesma cópia da árvore de trabalho, os mesmos
  falsos no PATH (sudo, pkexec, systemctl de escrita, rede), o mesmo
  `meow.conf.exemplo` como conf. Nenhum clique escreve: só se trocam páginas.

USO
  ~/.pyenv/versions/3.12.1/bin/python3 tests/app-texto-visivel.py \\
      [--fotos <pasta>] [--rotulo antes|depois] [--json <arquivo>]
"""
import importlib.util
import json
import os
import shutil
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "app_completo", os.path.join(AQUI, "app-completo.py"))
casa = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(casa)

from playwright.sync_api import sync_playwright  # noqa: E402  (o app-completo já conferiu)

FOTOS = casa._arg("--fotos")
ROTULO = casa._arg("--rotulo") or "medida"
SAIDA_JSON = casa._arg("--json")

# A contagem roda na página: é ela quem sabe o que está desenhado.
MEDIR_JS = r"""
() => {
  const raiz = document.querySelector('#conteudo');
  if (!raiz) return null;
  const naDica = (el) => !!el.closest('.dica, [role="tooltip"], #balao');
  const desenhado = (el) => el.checkVisibility
    ? el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true })
    : !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
  let caracteres = 0, comando = 0;
  const andar = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT);
  for (let n = andar.nextNode(); n; n = andar.nextNode()) {
    const pai = n.parentElement;
    if (!pai || naDica(pai) || !desenhado(pai)) continue;
    if (pai.closest('script, style, svg')) continue;
    const t = n.textContent.replace(/\s+/g, ' ').trim();
    if (!t) continue;
    caracteres += t.length;
    if (pai.closest('code')) comando += t.length;
  }
  /* Uma FRASE é um bloco de texto corrido: o elemento que tem texto próprio e
   * não é controle. Botão, rótulo de opção e título não são frase. */
  let frases = 0;
  const longas = [];
  for (const el of raiz.querySelectorAll('p, li, figcaption, dd, span, div')) {
    if (naDica(el) || !desenhado(el)) continue;
    if (el.closest('button, label, h1, h2, h3, h4, code, select, option')) continue;
    const proprio = [...el.childNodes].filter((c) => c.nodeType === 3)
      .map((c) => c.textContent).join(' ').replace(/\s+/g, ' ').trim();
    if (proprio.length >= 60) { frases++; if (longas.length < 3) longas.push(proprio.slice(0, 90)); }
  }
  return { caracteres, frases, comando, exemplos: longas };
}
"""


def assentar(pag, teto=40):
    """Espera o conteúdo parar de mudar. `networkidle` não serve: o painel tem
    um pulso que nunca deixa a rede quieta. Duas leituras iguais seguidas, com
    meio segundo entre elas, contam como página assentada."""
    anterior = None
    for _ in range(teto):
        pag.wait_for_timeout(500)
        agora = pag.evaluate("() => (document.querySelector('#conteudo') || {}).innerHTML || ''")
        if agora and agora == anterior:
            return
        anterior = agora


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("FALHOU: o app/run.sh não imprimiu a URL")
        return 1
    resultado = []
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1440, "height": 900})
            pag.goto(url, wait_until="domcontentloaded")
            pag.wait_for_selector("#trilho button")
            assentar(pag)
            grupos = pag.evaluate(
                "() => [...document.querySelectorAll('#trilho button[data-grupo]')]"
                ".map((b) => b.dataset.grupo)")
            for grupo in grupos:
                pag.locator(f'#trilho button[data-grupo="{grupo}"]').click()
                assentar(pag)
                m = pag.evaluate(MEDIR_JS) or {}
                m["pagina"] = grupo
                resultado.append(m)
                if FOTOS:
                    os.makedirs(FOTOS, exist_ok=True)
                    nome = casa.idDeAba(grupo) if hasattr(casa, "idDeAba") else None
                    nome = nome or "".join(c if c.isalnum() else "-" for c in grupo.lower())
                    pag.screenshot(path=os.path.join(FOTOS, f"{ROTULO}-{nome}.png"),
                                   full_page=True)
            nav.close()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except Exception:
            proc.kill()

    total = {"caracteres": 0, "frases": 0, "comando": 0}
    print(f"| página | caracteres | frases ≥60 | em <code> |")
    print("|---|---:|---:|---:|")
    for m in resultado:
        print(f"| {m['pagina']} | {m.get('caracteres', 0)} | {m.get('frases', 0)} "
              f"| {m.get('comando', 0)} |")
        for k in total:
            total[k] += m.get(k, 0)
    print(f"| **total** | **{total['caracteres']}** | **{total['frases']}** "
          f"| **{total['comando']}** |")
    if SAIDA_JSON:
        with open(SAIDA_JSON, "w", encoding="utf-8") as fh:
            json.dump({"rotulo": ROTULO, "paginas": resultado, "total": total},
                      fh, ensure_ascii=False, indent=2)
    return 0


if __name__ == "__main__":
    import signal
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    try:
        sys.exit(main())
    finally:
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)

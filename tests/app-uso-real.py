#!/usr/bin/env python3
import importlib.util
import os
import re
import shutil
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("app_completo", os.path.join(AQUI, "app-completo.py"))
casa = importlib.util.module_from_spec(_spec)
_argv, sys.argv = sys.argv, [os.path.join(AQUI, "app-completo.py")]
_spec.loader.exec_module(casa)
sys.argv = _argv

from playwright.sync_api import sync_playwright  # noqa: E402

FOTOS = casa._arg("--fotos")
TETO_PARAGRAFO = 140
TETO_FRASE = 48
VOLTAS = (("meowsystem", "mocha", ""), ("dracula", "dracula", "-dracula"))

OLHAR_JS = r"""
([tetoFrase, tetoParagrafo, minusculos]) => {
  const defeitos = [];
  const limpo = (t) => (t || '').replace(/\s+/g, ' ').trim();
  const visivel = (el) => el.checkVisibility && el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true });
  const fora = (el) => !!el.closest('pre, .dica, [role=tooltip], .previa, script, style, option');
  const dado = (el) => !!el.closest('.grade-apps, .grade-glifos, .galeria, .grade-jogos, .fichas, .faixa-estado span, code');
  const comeca = (t) => {
    const s = limpo(t);
    if (!s) return true;
    const c = s[0];
    if (!/\p{Ll}/u.test(c)) return true;
    return minusculos.some((m) => s.startsWith(m));
  };
  const lugares = [document.getElementById('topo'), document.getElementById('conteudo'),
                   ...[...document.querySelectorAll('dialog')].filter((d) => d.open),
                   document.getElementById('torradas')].filter(Boolean);
  for (const raiz of lugares) {
    const anda = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT);
    while (anda.nextNode()) {
      const no = anda.currentNode, pai = no.parentElement;
      const t = limpo(no.textContent);
      if (!t || !pai || fora(pai) || !visivel(pai)) continue;
      if (!comeca(t)) defeitos.push(['maiúscula', `«${t.slice(0, 50)}»`]);
      if (t.length > tetoParagrafo) defeitos.push(['parágrafo', `texto corrido com ${t.length} caracteres: «${t.slice(0, 60)}…»`]);
      else if (t.length > tetoFrase && !dado(pai)) defeitos.push(['frase', `${t.length} caracteres: «${t.slice(0, 60)}…»`]);
    }
  }
  for (const el of document.querySelectorAll('[data-dica]')) {
    if (!comeca(el.dataset.dica)) defeitos.push(['maiúscula na dica', `«${el.dataset.dica.slice(0, 50)}»`]);
  }
  for (const s of document.querySelectorAll('#conteudo select, dialog[open] select')) {
    if (!visivel(s)) continue;
    const o = s.options[s.selectedIndex];
    if (o && !comeca(o.textContent)) defeitos.push(['maiúscula', `opção «${limpo(o.textContent).slice(0, 40)}»`]);
  }
  for (const i of document.querySelectorAll('#conteudo input[placeholder], #topo input[placeholder]')) {
    if (visivel(i) && !comeca(i.placeholder)) defeitos.push(['maiúscula', `campo «${i.placeholder}»`]);
  }
  // o nome de uma opção, de um bloco ou de um botão cabe em três palavras; o
  // texto que vem do servidor numa pendência é dado, e fica de fora
  for (const el of document.querySelectorAll('#conteudo h1, #conteudo h2, #conteudo .rot > span, #conteudo .bt, dialog[open] .bt')) {
    if (!visivel(el) || dado(el) || el.closest('[data-linha^="pendencia:"], [data-linha^="gente:"]')) continue;
    const t = limpo(el.textContent);
    if (t.split(' ').length > 3) defeitos.push(['nome longo', `«${t}» passa de três palavras`]);
  }
  for (const p of document.querySelectorAll('#conteudo p')) {
    if (visivel(p)) defeitos.push(['parágrafo', `<p> na tela: «${limpo(p.textContent).slice(0, 60)}»`]);
  }
  const tudo = limpo(document.body.innerText);
  for (const proibido of [/git clone/i, /GPL/, /licen[çc]a/i, /feito pela/i, /Estados da tela/, /O que veio de onde/,
                          /pode baixar/i, /pede senha/i]) {
    if (proibido.test(tudo)) defeitos.push(['se descreve', `«${proibido.source}» na tela`]);
  }
  for (const el of document.querySelectorAll('#conteudo *')) {
    if (visivel(el) && el.children.length === 0 && /^Créditos$/.test(limpo(el.textContent)))
      defeitos.push(['se descreve', '«Créditos» fora do menu']);
  }
  // 5. a grade
  const linhasDaGrade = (g) => {
    const cs = getComputedStyle(g);
    const cols = cs.gridTemplateColumns.split(' ').map(parseFloat).filter((n) => !isNaN(n));
    const gap = parseFloat(cs.columnGap) || 0;
    const r = g.getBoundingClientRect();
    const xs = [r.left + parseFloat(cs.paddingLeft || 0)];
    for (const c of cols) { const ult = xs[xs.length - 1]; xs.push(ult + c, ult + c + gap); }
    return xs;
  };
  for (const g of document.querySelectorAll('#conteudo .grade-tema, #conteudo .grade-cuidar, #conteudo .oficina')) {
    if (!visivel(g)) continue;
    const xs = linhasDaGrade(g);
    for (const f of g.children) {
      if (!visivel(f)) continue;
      const r = f.getBoundingClientRect();
      const bate = (x) => xs.some((l) => Math.abs(l - x) <= 1.5);
      if (!bate(r.left) || !bate(r.right))
        defeitos.push(['grade', `${f.className || f.tagName} fora das linhas da grade (${Math.round(r.left)}–${Math.round(r.right)})`]);
    }
  }
  const filas = new Map();
  for (const b of document.querySelectorAll('#conteudo .bt, dialog[open] .bt')) {
    if (!visivel(b)) continue;
    const r = b.getBoundingClientRect();
    const chave = [b.parentElement, Math.round(r.top + r.height / 2)];
    const k = [...filas.keys()].find((x) => x[0] === chave[0] && Math.abs(x[1] - chave[1]) <= 3) || chave;
    if (!filas.has(k)) filas.set(k, []);
    filas.get(k).push(b);
  }
  for (const [k, bs] of filas) {
    if (bs.length < 2) continue;
    const alturas = new Set(bs.map((b) => Math.round(b.getBoundingClientRect().height)));
    const familia = (b) => b.classList.contains('principal') ? 'cheio' : b.classList.contains('leve') ? 'texto' : 'contornado';
    const familias = new Set(bs.map(familia));
    const nomes = bs.map((b) => limpo(b.textContent) || b.getAttribute('aria-label')).join(' | ');
    if (alturas.size > 1) defeitos.push(['fila', `botões de alturas diferentes na mesma fila: ${nomes}`]);
    if (bs.filter((b) => familia(b) === 'cheio').length > 1) defeitos.push(['fila', `dois principais na mesma fila: ${nomes}`]);
    if (familias.size === 3) defeitos.push(['fila', `cheio, contornado e só texto na mesma fila: ${nomes}`]);
  }
  // 6. coberto e rolagem lateral
  for (const el of document.querySelectorAll('#conteudo [data-controle]')) {
    if (!visivel(el)) continue;
    const r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) continue;
    const x = r.left + r.width / 2, y = r.top + r.height / 2;
    if (y < 120 || y > innerHeight - 4) continue;
    const topo = document.elementFromPoint(x, y);
    if (topo && topo !== el && !el.contains(topo) && !topo.closest('label')?.contains(el))
      defeitos.push(['coberto', `«${el.dataset.controle}» está coberto por ${topo.className || topo.tagName}`]);
  }
  if (document.documentElement.scrollWidth > innerWidth + 1)
    defeitos.push(['rolagem', `a página rola de lado (${document.documentElement.scrollWidth} > ${innerWidth})`]);
  // 7. prévia
  for (const p of document.querySelectorAll('#conteudo .previa')) {
    if (visivel(p) && p.children.length < 3) defeitos.push(['prévia', 'uma prévia sem desenho']);
  }
  return defeitos;
}
"""

ROTAS = casa.ROTAS


def minusculos(pag):
    return pag.evaluate("() => MINUSCULOS_DE_FATO")


def olhar(pag, rota, reprovas, rotulo=""):
    for tipo, frase in pag.evaluate(OLHAR_JS, [TETO_FRASE, TETO_PARAGRAFO, minusculos(pag)]):
        reprovas.append((f"{rota}{rotulo}", f"{tipo}: {frase}"))


def esperar(pag, ms=600):
    pag.wait_for_function("() => typeof ESQUEMA !== 'undefined' && ESQUEMA"
                          " && !document.getElementById('conteudo').hasAttribute('aria-busy')", timeout=60000)
    pag.wait_for_timeout(ms)


def ir(pag, rota):
    pag.evaluate(f"() => {{ location.hash = '#{rota}'; }}")
    esperar(pag)
    pag.wait_for_timeout(300)


def trocar_pack(pack, flavor):
    with open(casa.CONF, encoding="utf-8") as fh:
        texto = fh.read()
    for chave, valor in (("PACK", pack), ("FLAVOR", flavor)):
        texto, n = re.subn(r'(?m)^%s=.*$' % chave, '%s="%s"' % (chave, valor), texto)
        if not n:
            texto += '\n%s="%s"\n' % (chave, valor)
    with open(casa.CONF, "w", encoding="utf-8") as fh:
        fh.write(texto)


def main():
    sem_pack = [p for p, _f, _s in VOLTAS if not os.path.isfile(os.path.join(casa.RAIZ, "packs", p, "pack.json"))]
    if sem_pack:
        print("ERRO: volta com nome de pack que não existe: " + ", ".join(sem_pack))
        return 2
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o app/run.sh não imprimiu a URL")
        return 2
    reprovas, console = [], []
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1829, "height": 1029})
            onde = {"rota": "carga"}
            pag.on("console", lambda m: console.append((onde["rota"], m.text))
                   if m.type == "error" and "Failed to load resource" not in m.text else None)
            pag.on("pageerror", lambda e: console.append((onde["rota"], str(e))))

            print("1. a primeira carga")
            pag.goto(url, wait_until="commit")
            pag.wait_for_load_state("domcontentloaded")
            forma = pag.evaluate("() => [...document.querySelectorAll('#conteudo > *, #topo > *')]"
                                 ".filter((e) => e.getBoundingClientRect().height > 0).length")
            if forma < 3:
                reprovas.append(("carga", "tela vazia na primeira carga"))
            esperar(pag, 800)

            for pack, flavor, sufixo in VOLTAS:
                if sufixo:
                    trocar_pack(pack, flavor)
                    pag.reload()
                    esperar(pag, 800)
                print(f"2 a 8. as páginas, com o {pack}")
                for rota in ROTAS:
                    onde["rota"] = rota
                    ir(pag, rota)
                    olhar(pag, rota, reprovas, f" ({pack})")
                    if FOTOS:
                        nome = rota.replace("/", "-") + sufixo + ".png"
                        os.makedirs(os.path.join(FOTOS, "inteiras"), exist_ok=True)
                        pag.screenshot(path=os.path.join(FOTOS, nome))
                        pag.screenshot(path=os.path.join(FOTOS, "inteiras", nome), full_page=True)
            print("dicas: passar o mouse e focar")
            ir(pag, "ajustes/painel")
            alvo = pag.locator("#conteudo .linha .rot span[data-dica]").first
            alvo.hover()
            pag.wait_for_timeout(1100)
            dica = pag.evaluate("() => { const d = document.getElementById('dica'); return d.hidden ? '' : d.textContent; }")
            if not dica or not dica[0].isupper():
                reprovas.append(("dica", f"passar o mouse não mostra a dica com maiúscula ({dica!r})"))
            pag.mouse.move(5, 500)
            controle = pag.locator("#conteudo .chave[data-dica]").first
            controle.focus()
            pag.keyboard.press("Shift+Tab")
            pag.keyboard.press("Tab")
            pag.wait_for_timeout(100)
            dica = pag.evaluate("() => { const d = document.getElementById('dica'); return d.hidden ? '' : d.textContent; }")
            if not dica:
                reprovas.append(("dica", "focar pelo teclado não mostra a dica"))

            print("6. a 375 px nada rola de lado")
            pag.set_viewport_size({"width": 375, "height": 800})
            for rota in ROTAS:
                ir(pag, rota)
                largo = pag.evaluate("() => document.documentElement.scrollWidth")
                if largo > 376:
                    reprovas.append((rota + " (375 px)", f"a página rola de lado ({largo} px)"))
            nav.close()
    finally:
        proc.terminate()
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)
    for rota, texto in console:
        reprovas.append((rota, f"erro no console: {texto[:160]}"))
    vistos = set()
    for rota, frase in reprovas:
        if (rota.split(" (")[0], frase) in vistos:
            continue
        vistos.add((rota.split(" (")[0], frase))
        print(f"  XX [{rota}] {frase}")
    if reprovas:
        print(f"FALHOU: {len(vistos)} defeito(s) do que a pessoa vê")
        return 1
    print("ok: as 14 páginas, nos dois packs: sem texto explicativo, com maiúscula, numa grade só")
    return 0


if __name__ == "__main__":
    sys.exit(main())

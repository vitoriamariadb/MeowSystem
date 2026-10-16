#!/usr/bin/env python3
"""tests/app-uso-real.py — o gate de uso real: as 14 páginas, como quem usa.

ESCRITO POR CAUSA DESTE PEDIDO (24/09/2026, repetido em 25/09 e 09/10)
  «abrir cada aba como user… e colocar como gate»; «faça como user… tira prints
  antes e depois». O `tests/app-completo.py` já aperta todo controle da tela e
  confere que cada um FAZ alguma coisa. Mesmo assim, o uso real de 09/10/2026
  (docs/sprints/2026-10-09-uso-real/00-achados-como-usuario.md) achou trinta
  defeitos que ele não pega, porque não são de função: são do que a pessoa VÊ.
  Um parágrafo de quatro linhas embaixo de cada desenho, um balão em cima do
  item vizinho do menu, uma prévia que desenha só o contorno, a mesma tela
  dizendo duas coisas contrárias. Este arquivo é esse olhar, escrito.

O QUE REPROVA (e de onde cada regra vem)
  1. TELA VAZIA NA PRIMEIRA CARGA (achado 22): no `DOMContentLoaded` o menu e
     o conteúdo já têm forma — o esqueleto do `index.html` ou a página.
  2. PARÁGRAFO NA TELA (achado 28, U1, P77-direcao.md §1): texto corrido com
     mais de 140 caracteres fora de dica, balão ou `?`. É o dobro do teto de
     60 da direção: a régua é a de «isto é um parágrafo», não a de estilo.
  3. CONTROLE COBERTO (achado 6, U3): todo controle visível, centrado na
     janela, tem de ser o que está por cima no próprio centro. Um desenho
     grudado, um `?` ou um balão em cima dele é um botão que não se clica.
     E a página inteira não rola por fora do `#principal` (a barra dupla do
     QA de uso real da P80).
  4. BALÃO DO MENU EM CIMA DO VIZINHO (U3): o balão de cada item do menu
     lateral não pode encostar em outro item.
  5. PRÉVIA VAZIA (achado 18, direção §2.4): todo desenho da página (SVG de
     figura, `<canvas>`) tem traço de verdade — mais que uma moldura, e o
     `<canvas>` com mais de uma cor.
  6. CONTRADIÇÃO CONHECIDA, uma por achado da lista:
       · «Desenho, não é a sua tela» na tela (28);
       · comando cru visível fora do «ver comando» (30);
       · «Restaurar ao padrão» com a chave já no padrão (14);
       · «Deixar como está» (U2);
       · descolado da borda com distância 0 e nenhum selo (13);
       · a Steam contada como jogo, ou «nenhum jogo» ao lado de «N jogos têm
         atalho» (19, L1);
       · duração com unidade escrita num campo de texto (`30m`, achado 16);
       · campo de hora vazio (`--:--`) quando a hora herdada é conhecida (25);
       · hash de 40 caracteres ou caminho do PC de quem fez na tela (10, S2);
       · «dela» falando de quem usa (U4).
  7. ERRO NO CONSOLE, em qualquer página.
  8. O ACABAMENTO DA P80 (10/10/2026), um caso por defeito do uso real final
     (prints em `.playwright-mcp/ux-final/`), cada um com o gesto de quem usa:
       · a ficha de ícone mostra o nome amigável, e o nome técnico só na dica;
       · a paleta «Cor» da ficha só aparece com um traço marcado;
       · a pasta travada (a dos PNG feitos à mão) leva o selo de trava da
         página, com o porquê na dica;
       · as três linhas de Dia e noite usam o seletor de hora, na ordem
         começa | termina;
       · a fileira «Fundo» mora só em Cor e tela;
       · o «Usar este» de um pack mostra o selo «baixa da internet» (decisão 12).

A CASA É A DO `tests/app-completo.py`, e A ÁRVORE PODE SER OUTRA
  A decisão 8 de 02-decisoes.md manda o painel de QA subir SÓ com HOME
  temporário. A casa de brinquedo (HOME, falsos no PATH, cópia da árvore) vem
  de lá, importada. Com `--raiz <pasta>`, a cópia é feita de OUTRA árvore de
  trabalho — é assim que se prova que o gate reprova o `dev` de hoje sem
  tocar nele: ele só é LIDO, copiado para o brinquedo, e o painel sobe da
  cópia. Nenhum clique escreve: só se trocam páginas e se passa o rato.

USO
  ~/.pyenv/versions/3.12.1/bin/python3 tests/app-uso-real.py [--raiz <árvore>] [--fotos <pasta>]
                                                             [--so-acabamento]

  `--so-acabamento` roda só o 8 (e o console): é o laço curto de quem conserta
  um caso dele, e o gate de verdade é a corrida inteira.

  0 = passou · 1 = reprovou · 2 = erro deste teste
"""
import importlib.util
import os
import shutil
import sys
import time

AQUI = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "app_completo", os.path.join(AQUI, "app-completo.py"))
casa = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(casa)

from playwright.sync_api import sync_playwright  # noqa: E402  (o app-completo já conferiu)

RAIZ_OUTRA = casa._arg("--raiz")
FOTOS = casa._arg("--fotos")
SO_ACABAMENTO = "--so-acabamento" in sys.argv
if RAIZ_OUTRA:
    # A cópia da árvore (`copiar_raiz`) e as leituras do `montar_casa` usam o
    # `RAIZ` do módulo: trocá-lo aqui faz o brinquedo nascer da outra árvore.
    casa.RAIZ = os.path.abspath(RAIZ_OUTRA)

# Mais que isto, na tela e fora de dica, é parágrafo.
TETO_PARAGRAFO = 140

# ---------------------------------------------------------------------------
# O OLHAR, rodado dentro da página: devolve a lista de defeitos da página aberta
# ---------------------------------------------------------------------------
OLHAR_JS = r"""
(teto) => {
  const defeitos = [];
  const raiz = document.querySelector('#conteudo');
  const naDica = (el) => !!el.closest('.dica, [role="tooltip"], #balao');
  const visivel = (el) => el.checkVisibility
    && el.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true });
  const limpo = (t) => (t || '').replace(/\s+/g, ' ').trim();
  const proprio = (el) => limpo([...el.childNodes].filter((c) => c.nodeType === 3)
    .map((c) => c.textContent).join(' '));
  const nome = (el) => {
    const cartao = el.closest('[data-chave]');
    if (cartao) return 'cartão ' + cartao.dataset.chave;
    const t = el.closest('article, .acao, figure, section');
    const h = t && t.querySelector('h2, h3, h4, strong');
    return h ? '«' + limpo(h.textContent).slice(0, 40) + '»' : el.tagName.toLowerCase();
  };

  /* 2. PARÁGRAFO NA TELA */
  for (const el of document.querySelectorAll('#conteudo *, #trilho *, header.topo *')) {
    if (el.closest('script, style, svg, code, pre') || naDica(el) || !visivel(el)) continue;
    const t = proprio(el);
    if (t.length > teto) defeitos.push(`parágrafo de ${t.length} caracteres em ${nome(el)}: «${t.slice(0, 70)}…»`);
  }

  /* 3. CONTROLE COBERTO */
  const SEL = 'button, a[href], input:not([type=hidden]), select, textarea, summary, [role=button]';
  const recortado = (el, x, y) => {
    for (let a = el.parentElement; a && a !== document.body; a = a.parentElement) {
      const cs = getComputedStyle(a);
      if (cs.overflowX === 'visible' && cs.overflowY === 'visible') continue;
      const r = a.getBoundingClientRect();
      if (x < r.left || x > r.right || y < r.top || y > r.bottom) return true;
    }
    return false;
  };
  const principal = document.querySelector('#principal');
  const rolagem = principal ? principal.scrollTop : 0;
  for (const el of raiz.querySelectorAll(SEL)) {
    if (!visivel(el) || el.closest('.so-leitor')) continue;
    if (el.type === 'file') continue;
    const r0 = el.getBoundingClientRect();
    if (r0.width < 6 || r0.height < 6) continue;
    el.scrollIntoView({ block: 'center', inline: 'nearest' });
    const r = el.getBoundingClientRect();
    const x = r.left + r.width / 2, y = r.top + r.height / 2;
    if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) continue;
    if (recortado(el, x, y)) continue;
    const topo = document.elementFromPoint(x, y);
    if (!topo || topo === el || el.contains(topo) || topo.contains(el)) continue;
    /* O rótulo que embrulha o campo responde pelo campo. */
    if (topo.closest('label') && topo.closest('label').contains(el)) continue;
    const quem = topo.closest('[class]');
    defeitos.push(`controle coberto em ${nome(el)}: «${limpo(el.textContent || el.getAttribute('aria-label') || el.value || el.tagName).slice(0, 30)}» está sob ${quem ? quem.tagName.toLowerCase() + '.' + [...quem.classList].join('.') : topo.tagName.toLowerCase()}`);
  }
  if (principal) principal.scrollTop = rolagem;

  /* 3b. A PÁGINA ROLA POR FORA DO `#principal` (QA de uso real da P80): quem
   * rola é o `#principal`; a página inteira rolando junto é a barra dupla na
   * borda direita, e no celular são 15 px a menos de largura. */
  const doc = document.documentElement;
  if (doc.scrollHeight > doc.clientHeight + 1 || doc.scrollWidth > doc.clientWidth + 1)
    defeitos.push(`a página inteira rola por fora do #principal (${doc.scrollWidth}×${doc.scrollHeight} numa janela de ${doc.clientWidth}×${doc.clientHeight}): barra dupla`);

  /* 5. PRÉVIA VAZIA */
  const TRACO = 'path, rect, circle, ellipse, line, polyline, polygon, text, image, use';
  for (const svg of raiz.querySelectorAll('svg')) {
    if (!visivel(svg)) continue;
    const r = svg.getBoundingClientRect();
    if (r.width < 60 || r.height < 30) continue;     /* glifo, selo, ícone */
    const tracos = [...svg.querySelectorAll(TRACO)].filter((t) => {
      const b = t.getBoundingClientRect();
      return b.width > 0 || b.height > 0;
    });
    if (tracos.length < 4) defeitos.push(`prévia vazia em ${nome(svg)}: o desenho tem ${tracos.length} traço(s)`);
  }
  for (const cv of raiz.querySelectorAll('canvas')) {
    if (!visivel(cv) || cv.width < 20 || cv.height < 20) continue;
    let cores = new Set();
    try {
      const d = cv.getContext('2d').getImageData(0, 0, cv.width, cv.height).data;
      const passo = Math.max(4, Math.floor(d.length / 4 / 4000) * 4);
      for (let i = 0; i < d.length && cores.size < 3; i += passo) cores.add(d[i] + ',' + d[i + 1] + ',' + d[i + 2] + ',' + d[i + 3]);
    } catch (e) { cores = new Set(['?', '??']); }
    if (cores.size < 2) defeitos.push(`prévia vazia em ${nome(cv)}: o canvas tem uma cor só`);
  }

  /* 6. CONTRADIÇÕES CONHECIDAS */
  const textoVisivel = [];
  const anda = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT);
  for (let n = anda.nextNode(); n; n = anda.nextNode()) {
    const p = n.parentElement;
    if (!p || naDica(p) || !visivel(p) || p.closest('script, style')) continue;
    const t = limpo(n.textContent);
    if (t) textoVisivel.push([p, t]);
  }
  const tudo = textoVisivel.map(([, t]) => t).join(' \n ');
  if (/Desenho, não é a sua tela/i.test(tudo)) defeitos.push('«Desenho, não é a sua tela» na tela (achado 28)');
  if (/deixar como está/i.test(tudo)) defeitos.push('«Deixar como está» na tela (U2)');
  if (/\b(decisão|tela|pedido|máquina|casa|gosto) dela\b/i.test(tudo)) defeitos.push('«dela» falando de quem usa (U4)');
  for (const [p, t] of textoVisivel) {
    if (p.closest('code') && !p.closest('.comandos') && /(^|\s)(\.\/|meow\s|scripts\/|sudo\s)/.test(t))
      defeitos.push(`comando cru na tela em ${nome(p)}: «${t.slice(0, 50)}» (achado 30)`);
    if (/\b[0-9a-f]{40}\b/.test(t)) defeitos.push(`hash de 40 caracteres na tela em ${nome(p)} (achado 10)`);
    if (/\/mnt\/|\/home\/|Desenvolvimento\//.test(t)) defeitos.push(`caminho do PC de quem fez em ${nome(p)}: «${t.slice(0, 60)}» (S2)`);
  }
  for (const campo of raiz.querySelectorAll('input')) {
    if (!visivel(campo)) continue;
    const v = campo.value || '';
    if (/\b[0-9a-f]{40}\b/.test(v)) defeitos.push(`hash de 40 caracteres num campo em ${nome(campo)} (achado 10)`);
    if (/\/mnt\/|\/home\/|Desenvolvimento\//.test(v)) defeitos.push(`caminho do PC de quem fez num campo em ${nome(campo)} (S2)`);
    if (campo.type === 'text' && /^\d+\s*[smh]$/.test(v.trim())) defeitos.push(`duração «${v}» num campo de texto em ${nome(campo)} (achado 16)`);
    if (campo.type === 'time' && !v) defeitos.push(`campo de hora vazio (--:--) em ${nome(campo)} (achado 25)`);
  }
  /* «Restaurar ao padrão» com a chave já no padrão, e sem escolha esperando. */
  if (typeof ESQUEMA !== 'undefined' && ESQUEMA && ESQUEMA.chaves) {
    const pend = (typeof MUDANCAS !== 'undefined' && MUDANCAS) ? MUDANCAS : new Map();
    for (const cartao of raiz.querySelectorAll('[data-chave]')) {
      const item = ESQUEMA.chaves.find((i) => i.chave === cartao.dataset.chave);
      /* Vazio é o padrão de quem aceita vazio; e o valor de fábrica escrito
       * no meow.conf.exemplo (`JANELAS_TILING="sim"`) também é — QA da P77. */
      if (!item) continue;
      const v = item.valor ?? '';
      if (pend.has(item.chave) || (v !== '' && v !== (item.padrao ?? ''))) continue;
      const b = [...cartao.querySelectorAll('button')].find((x) => visivel(x) && /^Restaurar ao padrão/.test(limpo(x.textContent)));
      if (b) defeitos.push(`«${limpo(b.textContent)}» com ${item.chave} já no padrão (achado 14)`);
    }
    /* Descolado da borda com distância 0, sem selo na distância. */
    const val = (k) => {
      const i = ESQUEMA.chaves.find((x) => x.chave === k);
      if (!i) return null;
      const v = pend.has(k) ? pend.get(k) : (i.valor ?? '');
      /* Vazio é «não toca»: vale o que a máquina tem, quando se sabe; sem
       * isso, não há número para conferir (e não é zero). */
      if (v !== '') return String(v);
      return i.valendo_agora != null && i.valendo_agora !== '' ? String(i.valendo_agora) : null;
    };
    for (const lado of ['PAINEL', 'DOCK']) {
      const margem = raiz.querySelector(`[data-chave="FORMA_MARGEM_${lado}"]`);
      if (!margem || !visivel(margem)) continue;
      const distancia = val(`FORMA_MARGEM_${lado}`);
      if (val(`FORMA_${lado}_SOLTO`) === 'sim' && distancia !== null && Number(distancia) === 0
          && !margem.querySelector('.selo'))
        defeitos.push(`${lado.toLowerCase()} descolado da borda com distância 0 e nada dizendo que brigam (achado 13)`);
    }
  }
  /* A Steam não é jogo; «nenhum jogo» não convive com «N jogos têm atalho». */
  const jogos = [...raiz.querySelectorAll('.grade-jogos *, [data-molde="jogo"] *, .jogo *')]
    .filter((e) => visivel(e)).map((e) => proprio(e));
  if (jogos.some((t) => /^Steam$/.test(t))) defeitos.push('a Steam aparece como jogo (achado 19)');
  if (/nenhum jogo/i.test(tudo) && /\d+ jogos? têm atalho/i.test(tudo)) defeitos.push('«nenhum jogo» e «N jogos têm atalho» na mesma tela (achado 19)');
  return defeitos;
}
"""


def assentar(pag, teto=40):
    """Duas leituras iguais do `#conteudo`, com meio segundo entre elas: o
    painel tem um pulso que nunca deixa a rede quieta, e `networkidle` não
    chegaria nunca (a mesma régua do `tests/app-texto-visivel.py`)."""
    anterior = None
    for _ in range(teto):
        pag.wait_for_timeout(500)
        agora = pag.evaluate("() => (document.querySelector('#conteudo') || {}).innerHTML || ''")
        if agora and agora == anterior:
            return
        anterior = agora


def balao_do_menu(pag):
    """O balão de cada item do menu, conferido contra os outros itens."""
    defeitos = []
    itens = pag.locator("#trilho button[data-grupo], #trilho a.item-externo")
    for i in range(itens.count()):
        item = itens.nth(i)
        item.hover()
        pag.wait_for_timeout(1100)
        r = pag.evaluate("""(i) => {
          const itens = [...document.querySelectorAll('#trilho button[data-grupo], #trilho a.item-externo')];
          const b = document.querySelector('#balao');
          if (!b || b.hidden) return null;
          const rb = b.getBoundingClientRect();
          const toca = itens.filter((x, j) => j !== i).filter((x) => {
            const r = x.getBoundingClientRect();
            return r.left < rb.right && r.right > rb.left && r.top < rb.bottom && r.bottom > rb.top;
          }).map((x) => (x.textContent || '').replace(/\\s+/g, ' ').replace(/\\d+$/, '').trim());
          return { dono: (itens[i].textContent || '').replace(/\\s+/g, ' ').replace(/\\d+$/, '').trim(), toca };
        }""", i)
        if r and r["toca"]:
            defeitos.append(f"o balão de «{r['dono']}» cobre {', '.join('«%s»' % t for t in r['toca'])} (U3)")
        pag.mouse.move(900, 5)
        pag.wait_for_timeout(150)
    return defeitos


def gesto_do_descolado(pag):
    """O ACHADO 13 COMO QUEM USA: «descolado» em Sim e a distância arrastada
    até 0. A casa nasce com a distância vazia (o COSMIC decide), e a
    contradição só existe depois do gesto — então o gesto é feito, a página é
    olhada, e a escolha é descartada (nada é salvo: o meow.conf não muda)."""
    cartao = '[data-chave="FORMA_MARGEM_PAINEL"]'
    deslizante = pag.locator(f"{cartao} input[type=range]")
    sim = pag.locator('[data-chave="FORMA_PAINEL_SOLTO"] button[data-valor="sim"]')
    if not deslizante.count() or not sim.count():
        return ["o gesto do achado 13 não achou o descolar e a distância do painel"]
    if sim.first.get_attribute("aria-pressed") != "true":
        sim.first.click()
        pag.wait_for_timeout(300)
    pag.locator(f"{cartao} input[type=range]").first.fill("0")
    assentar(pag)
    defeitos = [d for d in pag.evaluate(OLHAR_JS, TETO_PARAGRAFO) if "achado 13" in d]
    pag.locator("#botao-descartar").click()
    if pag.locator("#confirmar[open]").count():
        pag.locator("#confirmar-ok").click()
    assentar(pag)
    return defeitos


# ---------------------------------------------------------------------------
# 8. O ACABAMENTO DA P80 — um caso por defeito do uso real final (10/10/2026)
# ---------------------------------------------------------------------------
VISIVEL_JS = "(el) => !!el && el.checkVisibility && el.checkVisibility({ checkOpacity: true })"


def abrir_pagina(pag, grupo):
    pag.locator(f'#trilho button[data-grupo="{grupo}"]').click()
    pag.mouse.move(900, 5)
    assentar(pag)


def abrir_ficha(pag, busca):
    """A ficha de ícone do programa de brinquedo da casa (o `PROGRAMA` do
    app-completo, que nenhuma trava alcança), com `busca` no campo dela; volta
    quando a resposta da busca está pintada."""
    abrir_pagina(pag, "Ícones")
    pag.locator(".busca-apps").fill(casa.PROGRAMA[1])
    assentar(pag)
    pag.locator(".grade-apps button.app").first.click()
    pag.wait_for_selector(".escolha-icone input[type=search]", timeout=20000)
    pag.locator(".escolha-icone input[type=search]").fill(busca)
    pag.wait_for_function(
        "(t) => typeof GLIFOS !== 'undefined' && GLIFOS.termo === t && !GLIFOS.carregando",
        arg=busca, timeout=20000)
    assentar(pag)


# 8.1 — O RÓTULO DA FICHA (prints 05 e 06): `net.waterfo…`, `org.gnome.…`,
#   `005-potion` cortados embaixo de cada desenho. O rótulo é o nome amigável,
#   e o nome inteiro (com a pasta) vai para a dica.
ROTULOS_JS = r"""
() => {
  const vis = (el) => !!el && el.checkVisibility && el.checkVisibility({ checkOpacity: true });
  const TECNICO = /^\d{2,}[-_]|^[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9.-]+$/;
  const defeitos = [];
  const botoes = [...document.querySelectorAll('.escolha-icone .tira-glifos button[data-glifo]')].filter(vis);
  if (!botoes.length) return ['a ficha não mostrou desenho nenhum para «firefox»'];
  for (const b of botoes) {
    const rotulo = ((b.querySelector('span') || {}).textContent || '').trim();
    if (!rotulo || TECNICO.test(rotulo)) defeitos.push(`rótulo técnico na ficha: «${rotulo}»`);
    /* O desenho travado diz na dica o porquê (P80, item 3); o que vale diz o
     * nome inteiro e de onde vem. */
    if (b.getAttribute('aria-disabled') === 'true') {
      if (!(b.dataset.balao || b.title)) defeitos.push(`«${rotulo}» travado sem o porquê na dica`);
    } else if (!(b.dataset.balao || b.title || '').includes(b.dataset.glifo))
      defeitos.push(`a dica de «${rotulo}» não traz o nome inteiro (${b.dataset.glifo}): «${b.dataset.balao || b.title || ''}»`);
  }
  const wf = botoes.find((b) => b.dataset.glifo === 'net.waterfox.waterfox');
  const dele = wf ? wf.querySelector('span').textContent.trim() : null;
  if (dele !== 'Waterfox') defeitos.push(`o desenho do Waterfox diz «${dele}», e não «Waterfox»`);
  return defeitos;
}
"""


# 8.2 — A PALETA «COR» SÓ COM TRAÇO (print 05): a fileira de cores aparecia
#   sempre, e só vale para o desenho de traço. Ela nasce quando um traço está
#   marcado, e some quando o marcado é um desenho que entra com as cores dele.
PALETA_JS = r"""
(passo) => {
  const vis = (el) => !!el && el.checkVisibility && el.checkVisibility({ checkOpacity: true });
  const ficha = document.querySelector('.escolha-icone');
  const cores = ficha && ficha.querySelector(':scope > .cores-grade');
  const rotulo = cores && cores.previousElementSibling;
  const botoes = [...ficha.querySelectorAll('.tira-glifos button[data-escolha]')].filter(vis);
  const traco = botoes.find((b) => !b.classList.contains('do-pack'));
  const desenho = botoes.find((b) => b.classList.contains('do-pack'));
  if (passo === 'traco') { if (!traco) return 'nenhum traço livre na ficha para marcar'; traco.click(); }
  if (passo === 'desenho') { if (!desenho) return 'nenhum desenho livre na ficha para marcar'; desenho.click(); }
  const marcado = ficha.querySelector('.tira-glifos button[aria-pressed="true"]');
  const deTraco = !!marcado && !marcado.classList.contains('do-pack');
  const aparece = vis(cores) || (vis(rotulo) && /cor/i.test(rotulo.textContent));
  if (deTraco && !aparece) return `com o traço «${marcado.dataset.glifo}» marcado, a paleta «Cor» não aparece`;
  if (!deTraco && aparece)
    return marcado ? `com o desenho «${marcado.dataset.glifo}» marcado, a paleta «Cor» aparece`
                   : 'sem nada marcado, a paleta «Cor» aparece';
  return '';
}
"""


# 8.3 — O PNG FEITO À MÃO E A TRAVA (print 06): o PNG aparecia apagado, com um
#   selo que ninguém lia (um retângulo desenhado em CSS). A pasta travada leva
#   o selo de trava de toda a página, com o porquê inteiro na dica — o mesmo
#   em toda pasta —, e o desenho travado diz o porquê na dica dele.
TRAVA_JS = r"""
() => {
  const vis = (el) => !!el && el.checkVisibility && el.checkVisibility({ checkOpacity: true });
  const defeitos = [];
  const ficha = document.querySelector('.escolha-icone');
  for (const c of ficha.querySelectorAll('.pasta-acervo .cadeado'))
    if (vis(c)) defeitos.push('a pasta travada usa o cadeado desenhado em CSS, e não o selo de trava');
  const png = [...ficha.querySelectorAll('.pasta-acervo')].find((d) => /:feitos-a-mao$/.test(d.dataset.grupo || ''));
  if (!png) return ['a busca «firefox» não abriu a pasta dos feitos à mão'];
  const selo = png.querySelector('summary .selo[data-selo="trava"]');
  if (!vis(selo)) defeitos.push('a pasta dos feitos à mão, travada, não leva o selo de trava');
  else if (!selo.dataset.balao || selo.dataset.balaoAparado)
    defeitos.push(`o selo de trava sem o porquê inteiro na dica: «${selo.dataset.balao || ''}»`);
  for (const b of png.querySelectorAll('button[data-glifo]')) {
    const travado = b.getAttribute('aria-disabled') === 'true';
    if (travado && (!b.dataset.balao || b.dataset.balaoAparado))
      defeitos.push(`o PNG «${b.dataset.glifo}» travado sem o porquê inteiro na dica`);
    if (!travado && b.classList.contains('travado')) defeitos.push(`o PNG «${b.dataset.glifo}» vale e aparece apagado`);
  }
  return defeitos;
}
"""


# 8.4 — DIA E NOITE (print 07): a linha do tema claro usava um deslizante
#   pontilhado («como está: 18») ao lado de duas linhas com seletor de hora, e
#   lia ao contrário (termina à esquerda). As três linhas: o mesmo seletor de
#   hora, a mesma ordem — começa | termina.
NOITE_JS = r"""
() => {
  const defeitos = [];
  const m = document.querySelector('.decisao-relogio');
  if (!m) return ['a página Dia e noite não desenhou a moldura do relógio'];
  for (const r of m.querySelectorAll('input[type=range]'))
    defeitos.push(`deslizante na moldura da noite, em ${(r.closest('[data-chave]') || {}).dataset?.chave}`);
  for (const l of LINHAS_DA_NOITE) {
    const cartoes = l.chaves.map((c) => m.querySelector(`[data-chave="${c}"]`));
    if (cartoes.some((c) => !c)) { defeitos.push(`a linha «${l.nome}» não tem os dois cartões`); continue; }
    const titulos = cartoes.map((c) => ((c.querySelector('.titulo-cartao') || {}).textContent || '').trim());
    if (!/começa|a partir/i.test(titulos[0]) || !/termina|até/i.test(titulos[1]))
      defeitos.push(`a linha «${l.nome}» não lê começa | termina: «${titulos.join(' | ')}»`);
    for (const [i, c] of cartoes.entries()) {
      const hora = c.querySelector('input[type=time]');
      if (!hora) defeitos.push(`«${titulos[i]}» sem o seletor de hora`);
      else if (!hora.value) defeitos.push(`«${titulos[i]}» com o seletor de hora vazio`);
    }
  }
  return defeitos;
}
"""


# 8.5 — A FILEIRA «FUNDO», UMA REGRA SÓ: ela aparecia em Ícones, Cor e tela,
#   Logo e Papel de parede, e sumia nas outras. Mora numa página só, a de Cor
#   e tela; o fundo escolhido lá vale para a página inteira.
PAGINA_DO_FUNDO = "Cor e tela"


def fundo_em_toda_pagina(pag):
    defeitos = []
    grupos = pag.evaluate("() => [...document.querySelectorAll('#trilho button[data-grupo]')]"
                          ".map((b) => b.dataset.grupo)")
    for grupo in grupos:
        abrir_pagina(pag, grupo)
        tem = pag.evaluate("() => [...document.querySelectorAll('#conteudo .fundos')]"
                           ".some((e) => e.checkVisibility && e.checkVisibility())")
        if tem and grupo != PAGINA_DO_FUNDO:
            defeitos.append(f"a fileira «Fundo» aparece em {grupo}, fora de {PAGINA_DO_FUNDO}")
        if not tem and grupo == PAGINA_DO_FUNDO:
            defeitos.append(f"a fileira «Fundo» não aparece em {PAGINA_DO_FUNDO}")
    return defeitos


# 8.10 — TROCAR DE PACK BAIXA, E DIZ (decisão 12): a troca leva o ponteiro do
#   pack, e o do Dracula desce da rede. O «Usar este» de cada pack mostra o
#   selo «baixa da internet» logo depois dele, como toda porta de ação que baixa.
PACK_REDE_JS = r"""
() => {
  const vis = (el) => !!el && el.checkVisibility && el.checkVisibility({ checkOpacity: true });
  const usar = [...document.querySelectorAll('#conteudo button')]
    .filter((b) => vis(b) && b.textContent.trim() === 'Usar este');
  if (!usar.length) return ['a Início não mostrou nenhum «Usar este» de pack'];
  return usar.filter((b) => {
    const s = b.nextElementSibling;
    return !(s && s.matches('.selo[data-selo="rede"]') && vis(s) && /internet/i.test(s.dataset.balao || ''));
  }).map((b) => `o «Usar este» de «${(b.closest('article, .pack') || {}).dataset?.pack || 'um pack'}» não mostra o selo «baixa da internet»`);
}
"""


# 8.6 — O QA DE USO REAL DA P80 (10/10/2026), com a casa copiada da pessoa:
#   · o rótulo da ficha partia a palavra no meio («Configuraçõe» numa linha,
#     «s» na outra): a palavra inteira cabe na largura do desenho;
#   · o `obsidian.png` do pack é um SVG com nome de PNG (veio assim do
#     Dracula_OS-Theme), e a ficha o mostrava como imagem quebrada;
#   · o rótulo de reserva (o nome do arquivo limpo) mostrava o identificador de
#     32 letras dos atalhos do Chrome: «Chrome ieicmdpib… Default».
PALAVRA_PARTIDA_JS = r"""
() => {
  const defeitos = [];
  const ficha = document.querySelector('.escolha-icone');
  for (const d of ficha.querySelectorAll('.pasta-acervo')) d.open = true;
  for (const span of ficha.querySelectorAll('.tira-glifos button[data-glifo] > span')) {
    const t = span.firstChild;
    if (!t || t.nodeType !== 3) continue;
    for (const m of t.textContent.matchAll(/[^\s-]+/g)) {
      const r = document.createRange();
      r.setStart(t, m.index);
      r.setEnd(t, m.index + m[0].length);
      const linhas = new Set([...r.getClientRects()].filter((x) => x.width > 0).map((x) => Math.round(x.top)));
      if (linhas.size > 1) { defeitos.push(`o rótulo «${t.textContent}» parte a palavra «${m[0]}» em duas linhas`); break; }
    }
  }
  return defeitos;
}
"""
IMAGEM_QUEBRADA_JS = r"""
async () => {
  const ficha = document.querySelector('.escolha-icone');
  for (const d of ficha.querySelectorAll('.pasta-acervo')) d.open = true;
  const imgs = [...ficha.querySelectorAll('.tira-glifos button[data-glifo] img')];
  if (!imgs.length) return ['a busca «obsidian» não mostrou desenho nenhum'];
  for (const i of imgs) i.loading = 'eager';
  await Promise.all(imgs.map((i) => i.decode().catch(() => null)));
  return imgs.filter((i) => !i.naturalWidth)
    .map((i) => `imagem quebrada na ficha: «${i.closest('button').dataset.glifo}»`);
}
"""
IDENTIFICADOR_JS = r"""
() => [...document.querySelectorAll('.escolha-icone .tira-glifos button[data-glifo] > span')]
  .map((s) => s.textContent.trim())
  .filter((t) => /\b[a-z0-9]{20,}\b/i.test(t))
  .map((t) => `rótulo com identificador na ficha: «${t}»`)
"""


# 8.7 — UM NOME POR APP, E NÃO O ÚLTIMO PEDAÇO DO ID (P82, item 8): o
#   `com.obsproject.Studio` e o `io.github.shiftey.Desktop` viravam «Studio» e
#   «Desktop» embaixo do desenho. O nome vem da linha `# app:` do mapa.
NOME_DO_APP_JS = r"""
([glifo, nome]) => {
  const deles = [...document.querySelectorAll('.escolha-icone .tira-glifos button[data-glifo]')]
    .filter((b) => b.dataset.glifo === glifo);
  if (!deles.length) return [`a busca não mostrou o desenho ${glifo}`];
  return deles.map((b) => ((b.querySelector('span') || {}).textContent || '').trim())
    .filter((t) => t !== nome)
    .map((t) => `o desenho ${glifo} diz «${t}», e não «${nome}»`);
}
"""


# 5 — A 375 PX (P82, item 21): o que a integração da P80 viu numa tela de
#   celular. Cada caso é o efeito, medido na página: a aba aberta por endereço
#   aparece no menu horizontal; a prévia grudada não cobre o conteúdo que rola;
#   e o «?» de uma prévia não fica por cima do desenho dela.
ABA_NO_MENU_JS = r"""
() => {
  const t = document.getElementById('trilho').getBoundingClientRect();
  const a = document.querySelector('#trilho button[aria-current="true"]');
  if (!a) return ['nenhuma aba marcada no menu'];
  const b = a.getBoundingClientRect();
  return (b.left >= t.left - 1 && b.right <= t.right + 1) ? []
    : [`a aba aberta (${a.dataset.grupo}) está fora do menu horizontal: ${Math.round(b.left)}..${Math.round(b.right)} num trilho de ${Math.round(t.left)}..${Math.round(t.right)}`];
}
"""
PREVIA_COBRE_JS = r"""
() => {
  const m = document.getElementById('principal');
  if (!document.querySelector('#conteudo .previa-bloco')) return ['a página não tem prévia para conferir'];
  m.scrollTop += 700;
  const r = m.getBoundingClientRect();
  const el = document.elementFromPoint(r.left + r.width / 2, r.top + 60);
  return (el && el.closest('.previa-bloco'))
    ? ['a prévia grudada cobre o conteúdo que rola, no alto da página'] : [];
}
"""
DICA_SOBRE_DESENHO_JS = r"""
() => {
  const vis = (el) => el && el.checkVisibility && el.checkVisibility();
  const defeitos = [];
  for (const b of document.querySelectorAll('#conteudo .par-previa > .com-dica > button.porque')) {
    const svg = b.parentElement.querySelector('svg');
    if (!vis(b) || !svg || !svg.getBBox || !svg.getScreenCTM()) continue;
    const c = svg.getBBox(), m = svg.getScreenCTM();
    const d = { l: m.a * c.x + m.e, r: m.a * (c.x + c.width) + m.e,
                t: m.d * c.y + m.f, b: m.d * (c.y + c.height) + m.f };
    const q = b.getBoundingClientRect();
    if (q.left < d.r && q.right > d.l && q.top < d.b && q.bottom > d.t)
      defeitos.push(`o «?» da prévia fica por cima do desenho (${b.getAttribute('aria-label') || ''})`);
  }
  return defeitos;
}
"""


# 8.8 — O GATO DE VERDADE NA PONTA DA DOCK DESENHADA (P82, item 25; o desenho é
#   da QA da P77, `pintarGatosNoDock`): a ponta da dock da prévia é a miniatura
#   do gato escolhido, e não o gato de traço de reserva.
GATO_NA_DOCK_JS = r"""
() => {
  const grupos = [...document.querySelectorAll('#conteudo g.gato-no-dock')];
  if (!grupos.length) return ['a prévia de «Logo do sistema» não desenhou a dock com o gato'];
  return grupos.filter((g) => g.dataset.pintado !== g.dataset.gato || !g.querySelector('image'))
    .map((g) => `a ponta da dock desenhada mostra o gato de traço, e não o «${g.dataset.gato}» do acervo`);
}
"""


# 6 — A GRADE SEM BURACO (P82, item 26): um cartão alto numa linha deixava o
#   vão embaixo dos baixos; a régua é o fim do CONTEÚDO de cada cartão (o
#   cartão estica até a linha) contra o começo do de baixo, na mesma coluna. E
#   a figura de uma página só de ações não toma a linha sozinha: ela mora na
#   grade, ao lado dos cartões.
BURACO_JS = r"""
(teto) => {
  const vis = (el) => el && el.checkVisibility && el.checkVisibility();
  const defeitos = [];
  for (const g of document.querySelectorAll('#conteudo .grade')) {
    if (!vis(g) || getComputedStyle(g).gridTemplateColumns.split(' ').length < 2) continue;
    const filhos = [...g.children].filter(vis).map((c) => {
      const r = c.getBoundingClientRect();
      const fim = Math.max(r.top, ...[...c.children].filter(vis).map((x) => x.getBoundingClientRect().bottom));
      return { c, r, fim };
    });
    for (const a of filhos) {
      const abaixo = filhos.filter((b) => b !== a && b.r.top >= a.r.bottom - 1
                                   && b.r.left < a.r.right - 5 && b.r.right > a.r.left + 5);
      if (!abaixo.length) continue;
      const vao = Math.min(...abaixo.map((b) => b.r.top)) - a.fim;
      if (vao > teto) {
        const nome = (a.c.querySelector('h3, .titulo-cartao, .titulo') || a.c).textContent.trim().slice(0, 40);
        defeitos.push(`vão de ${Math.round(vao)} px embaixo de «${nome}»`);
      }
    }
  }
  for (const f of document.querySelectorAll('#conteudo > .previa-bloco'))
    if (vis(f) && !document.querySelector('#conteudo article.cartao'))
      defeitos.push('a figura da página só de ações toma a linha sozinha, fora da grade');
  return defeitos;
}
"""


def grade_sem_buraco(pag):
    """Os casos da P82 (item 26), a 1440 px. Devolve [(onde, defeito)]."""
    reprovas = []
    for grupo in ("Papel de parede", "Instalação", "Atualização", "Manutenção"):
        pag.locator(f'#trilho button[data-grupo="{grupo}"]').click()
        pag.mouse.move(5, 890)
        assentar(pag)
        reprovas += [(f"grade · {grupo}", d) for d in pag.evaluate(BURACO_JS, 64)]
        if FOTOS:
            nome = "".join(c if c.isalnum() else "-" for c in grupo.lower())
            pag.screenshot(path=os.path.join(FOTOS, f"p82-grade-{nome}.png"), full_page=True)
    return reprovas


AREAS_SEM_NOME_JS = r"""
() => {
  const defeitos = [];
  const nomes = ESQUEMA.chaves.find((k) => k.chave === 'AREAS_NOMES');
  if (!nomes || String(valorEmVigor(nomes)).trim()) return ['a casa de brinquedo tem áreas com nome'];
  for (const chave of ['AREAS_FOLGA', 'AREAS_ENCAIXE']) {
    const c = document.querySelector(`#conteudo article.cartao[data-chave="${chave}"]`);
    if (!c) { defeitos.push(`o cartão ${chave} não está na página`); continue; }
    if (!c.querySelector('[data-selo="anulado"]')) defeitos.push(`${chave} sem áreas nasce sem o ⊘`);
    const dica = document.getElementById(`dica-${chave}`);
    if (!dica || !/área/.test(dica.textContent) || !dica.querySelector('.frase.dominada'))
      defeitos.push(`${chave} sem áreas não diz o porquê na dica`);
  }
  const folga = document.querySelector('#conteudo article.cartao[data-chave="AREAS_FOLGA"]');
  if (folga && folga.querySelector('input[type=text], input:not([type]), textarea'))
    defeitos.push('AREAS_FOLGA sem áreas virou campo de texto livre');
  return defeitos;
}
"""


# Item 29: o `<select>` das listas longas que aceitam o vazio. Nenhuma chave da
# casa de brinquedo cai nele (a lista longa que ela tem é a de cores), então o
# controle é montado aqui, com uma chave de verdade e seis opções.
SELETOR_VAZIO_JS = r"""
() => {
  const base = ESQUEMA.chaves.find((k) => k.chave === 'LOG_NIVEL');
  const item = { ...base, opcoes: ['a', 'b', 'c', 'd', 'e', 'f'], rotulos: null,
                 aceita_vazio: true, previa: null, lista: false };
  const cartao = document.createElement('article');
  const c = montarControle(item, cartao);
  const vazio = c && c.querySelector('select option[value=""]');
  return vazio ? vazio.textContent : '(sem opção vazia)';
}
"""


def casos_da_p82(pag):
    """Os casos de interface da P82 (itens 28 em diante). Devolve [(onde, defeito)]."""
    reprovas = []
    # Item 28: folga e encaixe numa casa sem áreas com nome.
    pag.locator('#trilho button[data-grupo="Áreas de trabalho"]').click()
    assentar(pag)
    reprovas += [("áreas sem nome", d) for d in pag.evaluate(AREAS_SEM_NOME_JS)]
    # Item 29: um nome por valor — o vazio do `<select>` é o «Não tocar».
    vazio = pag.evaluate(SELETOR_VAZIO_JS)
    if vazio != "— não tocar —":
        reprovas.append(("seletor", f"o vazio do <select> se chama «{vazio}», e o botão ao lado, «Não tocar»"))
    return reprovas


def a_375(pag, url):
    """Os casos da P82 (item 21) numa janela de celular. Devolve [(onde, defeito)]."""
    reprovas = []
    pag.set_viewport_size({"width": 375, "height": 812})
    # A aba aberta pelo ENDEREÇO (e não por um clique, que o Playwright traz
    # para a vista sozinho): a última do menu, a que mais longe fica.
    ultima = pag.evaluate("() => idDeAba([...document.querySelectorAll('#trilho button[data-grupo]')].pop().dataset.grupo)")
    pag.goto(url.split("#")[0] + "#" + ultima, wait_until="commit")
    pag.wait_for_selector("#trilho button", timeout=60000)
    assentar(pag)
    reprovas += [("375 px · menu", d) for d in pag.evaluate(ABA_NO_MENU_JS)]
    for grupo, olhar in (("Painel e dock", PREVIA_COBRE_JS), ("Manutenção", DICA_SOBRE_DESENHO_JS),
                         ("Cor e tela", DICA_SOBRE_DESENHO_JS)):
        pag.locator(f'#trilho button[data-grupo="{grupo}"]').click()
        pag.mouse.move(5, 800)
        assentar(pag)
        reprovas += [(f"375 px · {grupo}", d) for d in pag.evaluate(olhar)]
        if FOTOS:
            nome = "".join(c if c.isalnum() else "-" for c in grupo.lower())
            pag.screenshot(path=os.path.join(FOTOS, f"p82-375-{nome}.png"))
    pag.set_viewport_size({"width": 1440, "height": 900})
    return reprovas


def acabamento(pag):
    """Os casos da P80, cada um com o gesto de quem usa. Devolve [(onde, defeito)]."""
    reprovas = []
    abrir_ficha(pag, "firefox")
    reprovas += [("ficha de ícone", d) for d in pag.evaluate(ROTULOS_JS)]
    if FOTOS:
        pag.locator(".escolha-icone .tira-glifos").evaluate("(e) => e.scrollIntoView({ block: 'start' })")
        pag.screenshot(path=os.path.join(FOTOS, "p80-ficha-firefox.png"))
    reprovas += [("ficha de ícone", d) for d in pag.evaluate(TRAVA_JS)]
    for passo in ("abrir", "traco", "desenho"):
        d = pag.evaluate(PALETA_JS, passo)
        pag.wait_for_timeout(200)
        if d:
            reprovas.append(("ficha de ícone", d))
        if FOTOS and passo != "abrir":
            pag.screenshot(path=os.path.join(FOTOS, f"p80-paleta-{passo}.png"))
    # 8.6 — o QA de uso real da P80, na mesma ficha.
    for busca, olhar in (("", PALAVRA_PARTIDA_JS), ("obsidian", IMAGEM_QUEBRADA_JS),
                         ("chrome", IDENTIFICADOR_JS)):
        pag.locator(".escolha-icone input[type=search]").fill(busca)
        pag.wait_for_function(
            "(t) => typeof GLIFOS !== 'undefined' && GLIFOS.termo === t && !GLIFOS.carregando",
            arg=busca, timeout=20000)
        assentar(pag)
        reprovas += [("ficha de ícone", d) for d in pag.evaluate(olhar)]
    for busca, glifo, nome in (("obs", "com.obsproject.Studio", "OBS Studio"),
                               ("github", "io.github.shiftey.Desktop", "GitHub Desktop")):
        pag.locator(".escolha-icone input[type=search]").fill(busca)
        pag.wait_for_function(
            "(t) => typeof GLIFOS !== 'undefined' && GLIFOS.termo === t && !GLIFOS.carregando",
            arg=busca, timeout=20000)
        assentar(pag)
        reprovas += [("ficha de ícone", d) for d in pag.evaluate(NOME_DO_APP_JS, [glifo, nome])]
    abrir_pagina(pag, "Logo do sistema")
    pag.wait_for_timeout(800)
    reprovas += [("Logo do sistema", d) for d in pag.evaluate(GATO_NA_DOCK_JS)]
    abrir_pagina(pag, "Dia e noite")
    reprovas += [("Dia e noite", d) for d in pag.evaluate(NOITE_JS)]
    if FOTOS:
        pag.screenshot(path=os.path.join(FOTOS, "p80-dia-e-noite.png"))
    reprovas += [("cabeçalho", d) for d in fundo_em_toda_pagina(pag)]
    abrir_pagina(pag, "Início")
    reprovas += [("Início", d) for d in pag.evaluate(PACK_REDE_JS)]
    if FOTOS:
        pag.locator("#conteudo button", has_text="Usar este").first.evaluate(
            "(e) => e.scrollIntoView({ block: 'center' })")
        pag.screenshot(path=os.path.join(FOTOS, "p80-usar-pack.png"))
    return reprovas


def main():
    ambiente = casa.montar_casa()
    proc, url = casa.sobe_servidor(ambiente)
    if not url:
        print("ERRO: o app/run.sh não imprimiu a URL")
        return 2
    reprovas = []
    console = []
    try:
        with sync_playwright() as p:
            nav = p.chromium.launch()
            pag = nav.new_page(viewport={"width": 1440, "height": 900})
            pagina_atual = {"nome": "carga"}
            pag.on("console", lambda m: console.append((pagina_atual["nome"], m.text))
                   if m.type == "error" else None)
            pag.on("pageerror", lambda e: console.append((pagina_atual["nome"], str(e))))

            # 1. A PRIMEIRA CARGA
            print("\n1. A PRIMEIRA CARGA")
            pag.goto(url, wait_until="commit")
            pag.wait_for_load_state("domcontentloaded")
            forma = pag.evaluate("""() => {
              const vis = (sel) => [...document.querySelectorAll(sel)].filter((e) => {
                const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0; }).length;
              return { trilho: vis('#trilho > *'), conteudo: vis('#conteudo > *') };
            }""")
            if not forma["trilho"] or not forma["conteudo"]:
                reprovas.append(("carga", f"tela vazia no primeiro quadro: {forma['trilho']} peça(s) no menu e "
                                          f"{forma['conteudo']} no conteúdo (achado 22)"))
            else:
                print(f"  ok o primeiro quadro já tem forma ({forma['trilho']} no menu, {forma['conteudo']} no conteúdo)")
            inicio = time.time()
            pag.wait_for_selector("#trilho button", timeout=60000)
            print(f"  -- a página ficou pronta em {time.time() - inicio:.1f} s depois do primeiro quadro")
            assentar(pag)

            grupos = []
            if not SO_ACABAMENTO:
                # 2. O BALÃO DO MENU
                print("\n2. O BALÃO DE CADA ITEM DO MENU")
                for d in balao_do_menu(pag):
                    reprovas.append(("menu", d))
                if not any(n == "menu" for n, _ in reprovas):
                    print("  ok nenhum balão do menu encosta em outro item")

                # 3. AS PÁGINAS
                print("\n3. AS PÁGINAS, UMA A UMA")
                grupos = pag.evaluate("() => [...document.querySelectorAll('#trilho button[data-grupo]')]"
                                      ".map((b) => b.dataset.grupo)")
                for grupo in grupos:
                    pagina_atual["nome"] = grupo
                    pag.locator(f'#trilho button[data-grupo="{grupo}"]').click()
                    pag.mouse.move(900, 5)
                    assentar(pag)
                    defeitos = pag.evaluate(OLHAR_JS, TETO_PARAGRAFO)
                    vistos = []
                    for d in defeitos:
                        if d not in vistos:
                            vistos.append(d)
                    vistos += gesto_do_descolado(pag) if grupo == "Painel e dock" else []
                    for d in vistos:
                        reprovas.append((grupo, d))
                    print(f"  {'ok' if not vistos else 'XX'} {grupo}: {len(vistos)} defeito(s)")
                    if FOTOS:
                        os.makedirs(FOTOS, exist_ok=True)
                        nome = "".join(c if c.isalnum() else "-" for c in grupo.lower())
                        pag.screenshot(path=os.path.join(FOTOS, f"uso-real-{nome}.png"))

            # 4. O ACABAMENTO DA P80
            print("\n4. O ACABAMENTO DA P80, UM CASO POR DEFEITO")
            pagina_atual["nome"] = "acabamento"
            if FOTOS:
                os.makedirs(FOTOS, exist_ok=True)
            achados = acabamento(pag)
            reprovas += achados
            print(f"  {'ok' if not achados else 'XX'} acabamento: {len(achados)} defeito(s)")

            # 6. A GRADE SEM BURACO (P82, item 26) — antes dos 375 px, a 1440
            print("\n6. A GRADE SEM BURACO")
            pagina_atual["nome"] = "grade"
            achados = grade_sem_buraco(pag)
            reprovas += achados
            print(f"  {'ok' if not achados else 'XX'} grade: {len(achados)} defeito(s)")

            # 7. OS CASOS DA P82 (itens 28 em diante)
            print("\n7. OS CASOS DA P82")
            pagina_atual["nome"] = "casos da P82"
            achados = casos_da_p82(pag)
            reprovas += achados
            print(f"  {'ok' if not achados else 'XX'} casos da P82: {len(achados)} defeito(s)")

            # 5. A 375 PX (P82, item 21)
            print("\n5. A 375 PX")
            pagina_atual["nome"] = "375 px"
            achados = a_375(pag, url)
            reprovas += achados
            print(f"  {'ok' if not achados else 'XX'} 375 px: {len(achados)} defeito(s)")
            nav.close()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except Exception:
            proc.kill()

    for onde, texto in console:
        reprovas.append((onde, f"erro no console: {texto[:160]}"))

    arvore = casa.RAIZ
    if reprovas:
        print(f"\nREPROVOU ({arvore}): {len(reprovas)} defeito(s) de uso real")
        for onde, texto in reprovas:
            print(f"  - [{onde}] {texto}")
        return 1
    if SO_ACABAMENTO:
        print(f"\nok ({arvore}): os casos do acabamento da P80 passam, console limpo.")
        return 0
    print(f"\nok ({arvore}): as {len(grupos)} páginas passam no olhar de quem usa — sem parágrafo,"
          " sem controle coberto, sem prévia vazia, sem contradição conhecida, console limpo —"
          " e os casos do acabamento da P80 passam.")
    return 0


if __name__ == "__main__":
    import signal
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as e:  # noqa: BLE001 — o gate diz que quebrou, e não que reprovou
        print(f"ERRO deste teste: {e}")
        sys.exit(2)
    finally:
        if os.path.isdir(casa.CASA):
            casa.encerrar_a_casa()
        shutil.rmtree(casa.BRINQUEDO, ignore_errors=True)

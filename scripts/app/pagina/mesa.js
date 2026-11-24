"use strict";

window.MESA = (function () {
  const DOCK = ["files", "firefox", "telegram", "discord", "spotify", "terminal"];
  const NS = "http://www.w3.org/2000/svg";
  const FORMAS = { g: [], path: ["d"], circle: ["cx", "cy", "r"], ellipse: ["cx", "cy", "rx", "ry"],
    rect: ["x", "y", "width", "height", "rx", "ry"], line: ["x1", "y1", "x2", "y2"],
    polyline: ["points"], polygon: ["points"] };
  const DO_PACK = new Map();
  const TIRA = ["red", "peach", "yellow", "green", "teal", "sky", "blue", "mauve", "pink"];
  const DA_PREVIA = { base: "--p-base", mantle: "--p-mantle", crust: "--p-crust", text: "--p-text",
    subtext0: "--p-sub", surface0: "--p-s0", surface1: "--p-s1", blue: "--p-blue", red: "--p-red",
    peach: "--p-peach", yellow: "--p-yellow", green: "--p-green", teal: "--p-teal", sky: "--p-sky",
    pink: "--p-pink" };

  function no(tag, classe, filhos) {
    const el = document.createElement(tag);
    if (classe) el.className = classe;
    for (const f of filhos || []) if (f) el.append(f);
    return el;
  }
  function copiarFormas(de, para) {
    for (const f of de.children) {
      const nomes = FORMAS[f.localName];
      if (!nomes) continue;
      const novo = document.createElementNS(NS, f.localName);
      for (const n of nomes) if (f.hasAttribute(n)) novo.setAttribute(n, f.getAttribute(n));
      copiarFormas(f, novo);
      para.append(novo);
    }
  }
  function svg(nome, classe) {
    const el = document.createElementNS(NS, "svg");
    el.setAttribute("aria-hidden", "true");
    if (classe) el.setAttribute("class", classe);
    if (!DO_PACK.has(nome)) {
      DO_PACK.set(nome, fetch("/desenho-da-mesa?nome=" + encodeURIComponent(nome))
        .then((r) => (r.ok ? r.text() : "")).catch(() => ""));
    }
    DO_PACK.get(nome).then((texto) => {
      const raiz = new DOMParser().parseFromString(texto, "image/svg+xml").documentElement;
      const caixa = raiz.getAttribute("viewBox") || "";
      if (raiz.localName !== "svg" || !/^[\d.\s-]+$/.test(caixa)) return;
      el.setAttribute("viewBox", caixa);
      copiarFormas(raiz, el);
    });
    return el;
  }
  function desenho(url, classe) {
    const img = document.createElement("img");
    img.className = classe;
    img.alt = "";
    img.src = url;
    return img;
  }
  function dockDaPrevia(previa) {
    const doPack = previa && Array.isArray(previa.dock) ? previa.dock : [];
    const feitos = new Map(doPack.map((d) => [d.app, d.url]));
    return DOCK.map((nome) =>
      no("span", "app", [feitos.has(nome) ? desenho(feitos.get(nome), "arte-pack") : svg(nome, "neutro")]));
  }
  const varias = (n, classe) => Array.from({ length: n }, () => no("i", classe));

  function estiloDeCores(cores, ordem, acento) {
    const s = {};
    if (!cores) return s;
    const mapa = Array.isArray(cores)
      ? Object.fromEntries(ordem.map((n, i) => [n, cores[i]])) : cores;
    for (const [nome, v] of Object.entries(DA_PREVIA)) if (mapa[nome]) s[v] = mapa[nome];
    for (const c of TIRA) if (mapa[c]) s["--c-" + c] = mapa[c];
    s["--p-acc"] = mapa[acento || "mauve"] || mapa.mauve;
    return s;
  }

  const px = (v, padrao) => {
    const n = Number(v);
    return Number.isFinite(n) && String(v).trim() !== "" ? n : padrao;
  };

  const TAMANHO = { XS: 2.6, S: 3.05, M: 3.5, L: 3.95, XL: 4.4 };
  const PX = 0.12;
  const CORES = ["rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender", "text", "crust"];
  const PONTEIRO = { light: "var(--text)", dark: "var(--crust)", mauve: "var(--mauve)", pink: "var(--pink)" };
  const DADOS = [
    ["FORMA_PAINEL_SOLTO", "soltoPainel", "sim"], ["FORMA_DOCK_SOLTO", "soltoDock", "sim"],
    ["FORMA_PAINEL_ILHA", "ilhaPainel", "nao"], ["FORMA_DOCK_ILHA", "ilhaDock", "nao"],
    ["RELOGIO_SEGUNDOS", "segundos", "nao"], ["MIDIA", "musica", "sim"], ["MIDIA_CAPA", "capa", "sim"],
    ["MIDIA_CONTROLES", "tocar", "sim"], ["JANELAS_TILING", "tiling", "nao"],
    ["TERMINAL_ESQUEMA", "esquema", "sim"], ["PROMPT_STARSHIP", "prompt", "sim"],
  ];
  const PX_VAR = [
    ["FORMA_MARGEM_PAINEL", "--p-margem-painel"], ["FORMA_MARGEM_DOCK", "--p-margem-dock"],
    ["FORMA_RAIO_PAINEL", "--p-raio-painel"], ["FORMA_RAIO_DOCK", "--p-raio-dock"],
    ["FORMA_ESPACO_PAINEL", "--p-espaco-painel"], ["FORMA_ESPACO_DOCK", "--p-espaco-dock"],
    ["FORMA_RECHEIO_PAINEL", "--p-recheio-painel"], ["FORMA_RECHEIO_DOCK", "--p-recheio-dock"],
  ];
  const TAM_VAR = [
    ["FORMA_ALA_INICIAL_PAINEL", "--p-b-ini"], ["FORMA_CENTRO_PAINEL", "--p-b-centro"], ["FORMA_ALA_FINAL_PAINEL", "--p-b-fim"],
    ["FORMA_ALA_INICIAL_DOCK", "--p-ala-ini"], ["FORMA_CENTRO_DOCK", "--p-centro"], ["FORMA_ALA_FINAL_DOCK", "--p-ala-fim"],
  ];
  const cor = (v) => (CORES.includes(String(v || "")) ? `var(--${v})` : "");

  function aplicarControles(raiz, val) {
    for (const [chave, dado, padrao] of DADOS) {
      const v = String(val(chave) || "").toLowerCase();
      raiz.dataset[dado] = v === "" ? padrao : (["sim", "1", "true"].includes(v) ? "sim" : "nao");
    }
    for (const [chave, nome] of PX_VAR) {
      const v = String(val(chave) || "").trim();
      if (v !== "" && Number.isFinite(Number(v))) raiz.style.setProperty(nome, Number(v) * PX + "cqi");
    }
    for (const [chave, nome] of TAM_VAR) {
      const t = TAMANHO[String(val(chave) || "").toUpperCase()];
      if (t) raiz.style.setProperty(nome, t + "cqi");
    }
    for (const lado of ["PAINEL", "DOCK"]) {
      const v = String(val("VIDRO_OPACIDADE_" + lado) || "").trim();
      if (v !== "" && Number.isFinite(Number(v))) {
        raiz.style.setProperty("--p-vidro-" + lado.toLowerCase(), Math.round(Number(v) * 100) + "%");
      }
    }
    const largura = Number(val("MIDIA_LARGURA"));
    if (String(val("MIDIA_LARGURA") || "").trim() !== "" && Number.isFinite(largura)) raiz.style.setProperty("--p-musica-largura", largura / 19.2 + "cqi");
    const letra = Number(val("MIDIA_FONTE"));
    if (String(val("MIDIA_FONTE") || "").trim() !== "" && Number.isFinite(letra)) raiz.style.setProperty("--p-musica-letra", letra / 19.2 * 0.7 + "cqi");
    const titulo = cor(val("MIDIA_COR_TITULO")), artista = cor(val("MIDIA_COR_ARTISTA")), capa = cor(val("MIDIA_COR_ALBUM"));
    if (titulo) raiz.style.setProperty("--p-musica-titulo", titulo);
    if (artista) raiz.style.setProperty("--p-musica-artista", artista);
    if (capa) raiz.style.setProperty("--p-musica-capa", capa);
    if (val("TERMINAL_CURSOR") === "port") raiz.style.setProperty("--p-cursor", "var(--p-text)");
    const ponteiro = PONTEIRO[String(val("CURSOR") || "").split("-").pop()];
    if (ponteiro) raiz.style.setProperty("--p-ponteiro", ponteiro);
  }

  function mesa(o = {}) {
    const val = o.val || (() => "");
    const marca = o.marca || new Set();
    const sem = o.sem || new Set();
    const m = (k) => (marca.has(k) ? " mudou-aqui" : "");
    const raiz = no("figure", "previa");
    raiz.setAttribute("role", "img");
    raiz.setAttribute("aria-label", o.rotulo || "Prévia");
    for (const [k, v] of Object.entries(o.cores || {})) raiz.style.setProperty(k, v);
    if (o.val) aplicarControles(raiz, val);
    if (sem.has("musica")) raiz.dataset.musica = "nao";
    if (o.ff) raiz.dataset.ff = "sim";
    else if (o.ffPagina) raiz.dataset.ff = "nao";
    if (o.solo === "term") raiz.dataset.soTerm = "sim";

    if (o.parede) {
      const img = no("img", "parede " + (o.ajuste === "caber" || o.ajuste === "esticar" ? o.ajuste : ""));
      img.alt = "";
      img.src = o.parede;
      raiz.append(img);
    }
    raiz.append(no("div", "p-barra" + m("painel"), [
      no("div", "ws", varias(3)),
      no("div", "meio", [no("div", "musica", [no("i"), no("b"), no("s"),
        no("span", "controles", [no("u"), no("u"), no("u")])])]),
      no("div", "bandeja", [no("i"), no("i"), (() => {
        const r = no("span", "relogio");
        r.append("14:32", no("span", "seg-relogio"));
        r.lastChild.textContent = ":07";
        return r;
      })()]),
    ]));

    if (!sem.has("arq")) {
      const pasta = o.previa && o.previa.pasta;
      const pastas = Array.from({ length: 8 }, () => no("figure", "", [
        pasta ? desenho(pasta, "pasta-pack") : svg("pasta", "pasta-neutra"), no("i")]));
      raiz.append(no("div", "p-jan p-arq" + m("arq"), [
        no("header", "", [no("b"), no("i")]),
        no("div", "corpo", [no("nav", "", varias(4)), no("div", "pastas", pastas)]),
      ]));
    }
    if (!sem.has("term")) {
      const largura = (el, p) => { el.style.width = p; return el; };
      const linhas = [];
      if (o.ff) {
        const g = no("img"); g.alt = ""; g.src = o.ff;
        linhas.push(no("div", "gato-ff", [g, no("div", "", ["60%", "80%", "50%", "70%"].map((p) => largura(no("i"), p)))]));
      }
      linhas.push(
        no("div", "pr", [no("b"), no("b"), no("b")]),
        no("div", "ln", [no("i", "ok"), largura(no("i"), "40%")]),
        no("div", "ln", [largura(no("i"), "55%")]),
      );
      const tira = no("div", "tira");
      for (const c of ["red", "peach", "yellow", "green", "teal", "sky", "blue", "acc", "pink"]) {
        const i = no("i"); i.style.background = `var(--p-${c})`; tira.append(i);
      }
      linhas.push(tira, no("div", "ln", [no("span", "pr", [no("b"), no("b"), no("b")]), no("span", "cursor")]));
      raiz.append(no("div", "p-jan p-term" + m("term"), [no("header", "", [no("b"), no("i")]), no("div", "corpo", linhas)]));
    }
    if (!sem.has("dock")) {
      const g = o.gato ? no("img", "gato") : null;
      if (g) { g.alt = ""; g.src = o.gato; }
      raiz.append(no("div", "p-dock" + m("dock"), [
        no("div", "ala-ini", [g]),
        no("div", "centro", dockDaPrevia(o.previa)),
        no("div", "ala-fim", [no("i"), no("i")]),
      ]));
    }
    if (o.ponteiro) {
      raiz.append(svg("ponteiro", "p-ponteiro"));
    }
    if (o.textura !== undefined && o.textura !== null && o.textura !== "") {
      const t = no("div", "papel");
      t.style.opacity = String(Math.max(0, Math.min(1, Number(o.textura) || 0)));
      raiz.append(t);
    }
    const kelvin = px(o.quente, 0);
    if (kelvin > 0) {
      const q = no("div", "quente");
      q.style.opacity = String(Math.max(0, Math.min(0.45, (6500 - kelvin) / 6500 * 0.6)).toFixed(3));
      raiz.append(q);
    }
    return raiz;
  }

  return { mesa, estiloDeCores };
})();

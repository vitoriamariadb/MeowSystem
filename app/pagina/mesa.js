"use strict";

window.MESA = (function () {
  const ICONES = {
    files: '<path d="M41.68 13H24.77c-2-.1-5.93-4.23-8.19-4.23h-9.9A2.18 2.18 0 0 0 4.5 11h0v7.29h39v-3.42A1.83 1.83 0 0 0 41.68 13Z"/><path d="M43.5 18.28h-39V37a2.18 2.18 0 0 0 2.17 2.2h34.65A2.18 2.18 0 0 0 43.5 37h0Z"/>',
    firefox: '<path d="M24 46.28c-5.36 0-21.5-3.66-21.5-22.3A17.77 17.77 0 0 1 10.67 9a14.3 14.3 0 0 0 .72 5.46h.07a17.6 17.6 0 0 1 5.12-4a13 13 0 0 0-.26 2.51a11.2 11.2 0 0 0 .32 2.64a3.4 3.4 0 0 1 .49.43a11.2 11.2 0 0 0 2.63 2.26c2.48 1.36 4.24 2.18 4.24 2.18s-1.19 2.39-2.64 2.39c-5.9 0-7.08 3.84-7.08 3.84s1.19 7.93 9.55 7.93c3.08 0 9.18-1.7 9.18-8.83a8.83 8.83 0 0 0-4.63-7.88A7.4 7.4 0 0 1 34 19.56a11.42 11.42 0 0 0-10-5.9h-.7a15.82 15.82 0 0 1 7.42-11.94a24.3 24.3 0 0 0 3.74 5.71c2.61 3 6 6.51 7.36 10.17a24.3 24.3 0 0 0-2.07-6.36s5.75 3.37 5.75 13.67A21.69 21.69 0 0 1 24 46.28"/>',
    telegram: '<path d="M40.83 8.48c1.14 0 2 1 1.54 2.86l-5.58 26.3c-.39 1.87-1.52 2.32-3.08 1.45L20.4 29.26a.4.4 0 0 1 0-.65l15.37-13.88c.7-.62-.15-.92-1.07-.36L15.41 26.54a.46.46 0 0 1-.4.05L6.82 24C5 23.47 5 22.22 7.23 21.33L40 8.69a2.2 2.2 0 0 1 .83-.21"/>',
    discord: '<path d="M17.59 34.173A49 49 0 0 1 14.68 38C7.3 37.79 4.5 33 4.5 33a44.8 44.8 0 0 1 4.81-19.52A16.47 16.47 0 0 1 18.69 10l1 2.31A33 33 0 0 1 24 12a33 33 0 0 1 4.33.3l1-2.31a16.47 16.47 0 0 1 9.38 3.51A44.8 44.8 0 0 1 43.5 33s-2.8 4.79-10.18 5a47 47 0 0 1-2.86-3.81m6.46-2.9c-3.84 1.945-7.555 3.89-12.92 3.89s-9.08-1.945-12.92-3.89"/><circle cx="17.847" cy="26.23" r="3.35"/><circle cx="30.153" cy="26.23" r="3.35"/>',
    spotify: '<circle cx="24" cy="24" r="21.5"/><path d="M12.333 30.67c8.19-1.872 15.215-1.066 20.882 2.397m-21.648-8.786c7.808-2.37 17.515-1.222 24.152 2.856M10.35 17.32c7.595-2.305 20.22-1.86 28.198 2.876"/>',
    terminal: '<path d="m10.559 22.908l12.586 7.269l-12.586 7.268m27.329 0H24.445"/><path d="M38.5 5.5h-29a4 4 0 0 0-4 4v29a4 4 0 0 0 4 4h29a4 4 0 0 0 4-4v-29a4 4 0 0 0-4-4"/>',
  };
  const PASTA = '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>';
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
  function svg(viewBox, corpo, classe) {
    const el = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    el.setAttribute("viewBox", viewBox);
    el.setAttribute("aria-hidden", "true");
    if (classe) el.setAttribute("class", classe);
    el.innerHTML = corpo;
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
    return Object.keys(ICONES).map((nome) =>
      no("span", "app", [feitos.has(nome) ? desenho(feitos.get(nome), "arte-pack") : svg("0 0 48 48", ICONES[nome], "neutro")]));
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
    ["MIDIA_CONTROLES", "tocar", "nao"], ["JANELAS_TILING", "tiling", "nao"],
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
        pasta ? desenho(pasta, "pasta-pack") : svg("0 0 24 24", PASTA, "pasta-neutra"), no("i")]));
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
      raiz.append(svg("0 0 24 24", '<path d="M5 3l14 8-6 2-2 6Z"/>', "p-ponteiro"));
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

  return { mesa, estiloDeCores, ICONES, PASTA };
})();

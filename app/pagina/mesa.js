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
  const sim = (v) => ["sim", "1", "true"].includes(String(v || "").toLowerCase());

  function mesa(o = {}) {
    const val = o.val || (() => "");
    const marca = o.marca || new Set();
    const sem = o.sem || new Set();
    const m = (k) => (marca.has(k) ? " mudou-aqui" : "");
    const raiz = no("div", "previa");
    raiz.setAttribute("role", "img");
    raiz.setAttribute("aria-label", o.rotulo || "Prévia");
    for (const [k, v] of Object.entries(o.cores || {})) raiz.style.setProperty(k, v);

    const forma = (lado, chave, padrao, escala) => {
      const v = px(val(chave), padrao);
      return v * escala;
    };
    const solto = (lado) => sim(val("FORMA_" + lado + "_SOLTO"));
    if (o.val) {
      raiz.style.setProperty("--p-margem-painel", solto("PAINEL") ? forma("PAINEL", "FORMA_MARGEM_PAINEL", 8, 0.12) + "cqi" : "0cqi");
      raiz.style.setProperty("--p-margem-dock", solto("DOCK") ? forma("DOCK", "FORMA_MARGEM_DOCK", 8, 0.12) + 0.4 + "cqi" : "0cqi");
      raiz.style.setProperty("--p-raio-painel", forma("PAINEL", "FORMA_RAIO_PAINEL", 12, 0.12) + "cqi");
      raiz.style.setProperty("--p-raio-dock", forma("DOCK", "FORMA_RAIO_DOCK", 16, 0.12) + "cqi");
      raiz.style.setProperty("--p-espaco-dock", forma("DOCK", "FORMA_ESPACO_DOCK", 8, 0.12) + "cqi");
      raiz.style.setProperty("--p-vidro-painel", Math.round(px(val("VIDRO_OPACIDADE_PAINEL"), 0.88) * 100) + "%");
      raiz.style.setProperty("--p-vidro-dock", Math.round(px(val("VIDRO_OPACIDADE_DOCK"), 0.88) * 100) + "%");
      const corDe = (nome) => (nome ? `var(--${String(nome).replace(/[^a-z0-9]/g, "")})` : "");
      if (val("MIDIA_COR_TITULO")) raiz.style.setProperty("--p-musica-titulo", corDe(val("MIDIA_COR_TITULO")));
      if (val("MIDIA_COR_ARTISTA")) raiz.style.setProperty("--p-musica-artista", corDe(val("MIDIA_COR_ARTISTA")));
      if (val("TERMINAL_CURSOR") === "port") raiz.style.setProperty("--p-cursor", "var(--p-text)");
      if (val("TERMINAL_ESQUEMA") === "nao") raiz.dataset.esquema = "nao";
      if (val("PROMPT_STARSHIP") === "nao") raiz.dataset.prompt = "nao";
    }

    if (o.parede) {
      const img = no("img", "parede " + (o.ajuste || ""));
      img.alt = "";
      img.src = o.parede;
      raiz.append(img);
    }
    const musica = !sem.has("musica") && (!o.val || sim(val("MIDIA") || "sim"));
    const barra = no("div", "p-barra" + m("painel"), [
      no("span", "ws", varias(4)),
      musica ? no("span", "musica", [no("i"), no("b"), no("s")]) : no("span"),
      no("span", "bandeja", [...varias(3), no("b")]),
    ]);
    if (o.val && sim(val("FORMA_PAINEL_ILHA"))) { barra.style.left = "26%"; barra.style.right = "26%"; }
    raiz.append(barra);

    if (!sem.has("arq")) {
      const pastas = Array.from({ length: 8 }, () =>
        no("figure", "", [svg("0 0 24 24", PASTA), no("i")]));
      raiz.append(no("div", "p-jan p-arq" + m("arq"), [
        no("header", "", [no("b"), no("i")]),
        no("div", "corpo", [no("nav", "", varias(5)), no("div", "pastas", pastas)]),
      ]));
    }
    if (!sem.has("term")) {
      const linhas = [
        no("div", "pr", [no("b"), no("b"), no("b")]),
        (() => { const l = no("div", "ln", [no("i", "ok"), no("i")]); l.lastChild.style.width = "16cqi"; return l; })(),
        no("div", "ln", [no("i", "cursor")]),
      ];
      if (o.ff) {
        const g = no("img"); g.alt = ""; g.src = o.ff;
        linhas.push(no("div", "gato-ff", [g, no("div", "", varias(3))]));
        raiz.dataset.ff = "1";
      }
      const tira = no("div", "tira");
      for (const c of TIRA) { const i = no("i"); i.style.background = `var(--c-${c}, var(--${c}))`; tira.append(i); }
      linhas.push(tira);
      raiz.append(no("div", "p-jan p-term" + m("term"), [no("header", "", [no("b"), no("i")]), no("div", "corpo", linhas)]));
    }
    if (!sem.has("dock")) {
      const dock = no("div", "p-dock" + m("dock"));
      if (o.gato) { const g = no("img", "gato"); g.alt = ""; g.src = o.gato; dock.append(g, no("span", "sep")); }
      for (const nome of Object.keys(ICONES)) dock.append(no("span", "app", [svg("0 0 48 48", ICONES[nome])]));
      raiz.append(dock);
    }
    const kelvin = px(o.quente, 0);
    if (kelvin > 0) {
      const q = no("div", "quente");
      q.style.opacity = String(Math.max(0, Math.min(0.45, (6500 - kelvin) / 6500 * 0.6)));
      raiz.append(q);
    }
    const textura = px(o.papel, 0);
    if (textura > 0) {
      const t = no("div", "papel");
      t.style.opacity = String(Math.max(0, Math.min(1, textura)));
      raiz.append(t);
    }
    return raiz;
  }

  return { mesa, estiloDeCores, ICONES, PASTA };
})();

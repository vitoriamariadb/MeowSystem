"use strict";

let APPS = null;
let APPS_BUSCA = "";
let DESENHO_FONTE = "gerar";
let APP_ABERTO = null;
let GLIFOS = { termo: null, itens: [], carregando: false };
const PASTAS_ABERTAS = new Map();

async function carregarApps() {
  APPS = { carregando: true, apps: [] };
  const r = await api("/api/apps");
  APPS = r.erro ? { apps: [], total: 0 } : r;
  render();
}
async function carregarGlifos(termo, app) {
  GLIFOS = { termo, app, itens: [], carregando: true };
  const r = await api(`/api/glifos?busca=${encodeURIComponent(termo || "")}&app=${encodeURIComponent(app || "")}&pack=${encodeURIComponent(packEmEdicao())}`);
  if (GLIFOS.termo !== termo || GLIFOS.app !== app) return;
  GLIFOS = { termo, app, itens: r.glifos || [], grupos: r.grupos || [], carregando: false,
             aviso: r.aviso || "", escolha: r.escolha || null, minha: r.minha || null, veste: r.veste || null };
  render();
}
function origemDoApp(a) {
  if (a.escolhido) return ["escolha", "Escolhido por você"];
  if (a.dracula) return ["pack", "Desenho do pack"];
  if (a.mapa || a.traco) return ["traco", "Traço do MeowSystem"];
  if (a.nosso) return ["nosso", "Desenho do MeowSystem"];
  return ["fabrica", "De fábrica"];
}
function montarApps() {
  if (!APPS) { carregarApps(); return elemento("div", { class: "grade-apps", "aria-busy": "true" }); }
  if (APPS.carregando) return elemento("div", { class: "grade-apps", "aria-busy": "true" });
  const filtro = elemento("input", { type: "search", class: "campo largo", value: APPS_BUSCA,
    placeholder: "Filtrar", "aria-label": "Filtrar aplicativos", controle: "apps:filtro" });
  filtro.addEventListener("input", () => { APPS_BUSCA = filtro.value; render(); });
  const termo = semAcento(APPS_BUSCA.trim());
  const grade = elemento("div", { class: "grade-apps" });
  for (const a of APPS.apps || []) {
    if (termo && !semAcento(a.nome).includes(termo) && !semAcento(a.id).includes(termo)) continue;
    const [origem, dica] = origemDoApp(a);
    grade.append(elemento("button", {
      type: "button", class: "app", "data-app": a.id, controle: "app", "aria-expanded": String(APP_ABERTO === a.id),
      dica, onclick: () => {
        APP_ABERTO = APP_ABERTO === a.id ? null : a.id;
        if (APP_ABERTO) carregarGlifos("", a.id);
        render();
      },
    }, [
      a.url ? elemento("img", { src: a.url, alt: "", loading: "lazy" }) : elemento("span", { class: "lugar" }),
      elemento("span", { class: "nome", texto: maiuscula(a.nome) }),
      elemento("span", { class: "marca-origem", "data-origem": origem, "aria-hidden": "true" }),
    ]));
  }
  return elemento("div", { class: "pilha", style: "gap:16px" }, [filtro, grade]);
}

async function depoisDoIcone(app, acao, recarregar) {
  await rodarAcao(acao);
  APP_ABERTO = null;
  await fimDoTrabalho();
  await recarregar();
}

function escolhaDeIcone(app, recarregar) {
  const painel = elemento("div", { class: "escolha-icone desenho", id: "desenho", "data-escolha-icone": app.id, "data-app": app.id });
  let cor = (app.traco && app.traco.cor) || (app.mapa && app.mapa.cor) || "mauve";
  const chaveDe = (g) => `${g.grupo}|${g.glifo}`;
  const travaDe = (g) => g.trava || (g.tipo === "traco" ? app.trava : app.trava_pack) || "";
  const itens = GLIFOS.app === app.id ? GLIFOS.itens : [];
  if (GLIFOS.escolhido === undefined && GLIFOS.app === app.id && !GLIFOS.carregando) {
    const minha = GLIFOS.minha && itens.find((g) => g.arquivo === GLIFOS.minha.arquivo && !travaDe(g));
    const vestido = app.mapa && itens.find((g) => g.tipo === "traco" && g.glifo === app.mapa.glifo);
    GLIFOS.escolhido = minha ? chaveDe(minha) : vestido ? chaveDe(vestido) : null;
  }
  const escolhido = () => itens.find((g) => chaveDe(g) === GLIFOS.escolhido) || null;

  const busca = elemento("input", { type: "search", class: "campo largo", value: GLIFOS.termo || "",
    placeholder: "Procurar desenho", "aria-label": "Procurar desenho", controle: "icone:busca" });
  busca.addEventListener("change", () => carregarGlifos(busca.value.trim().toLowerCase(), app.id));

  const tira = elemento("div", { class: "tira-glifos" });
  const botaoDe = (g) => elemento("button", {
    type: "button", class: travaDe(g) ? "travado" : null, controle: travaDe(g) ? "icone:travado" : "icone:desenho",
    "aria-pressed": String(chaveDe(g) === GLIFOS.escolhido), "aria-disabled": travaDe(g) ? "true" : null,
    dica: travaDe(g) ? maiuscula(travaDe(g)) : maiuscula(g.glifo),
    onclick: () => { if (travaDe(g)) return; GLIFOS.escolhido = chaveDe(g); render(); },
  }, [elemento("img", { src: g.url + "&tinta=texto", alt: "", loading: "lazy" }), elemento("span", { texto: maiuscula(g.rotulo || g.glifo) })]);
  const sugeridos = itens.filter((g) => g.sugerido);
  const pasta = (id, nome, filhos, aberta) => {
    const d = elemento("details", { class: "pasta-acervo" }, [
      elemento("summary", { controle: "icone:pasta" }, [elemento("span", { texto: maiuscula(nome) })]),
      elemento("div", { class: "grade-glifos" }, filhos),
    ]);
    d.open = PASTAS_ABERTAS.has(id) ? PASTAS_ABERTAS.get(id) : aberta;
    d.addEventListener("toggle", () => PASTAS_ABERTAS.set(id, d.open));
    return d;
  };
  if (sugeridos.length) tira.append(pasta("sugeridos", "Sugeridos", sugeridos.map(botaoDe), true));
  for (const gr of GLIFOS.grupos || []) {
    const deles = itens.filter((g) => g.grupo === gr.id);
    if (deles.length) tira.append(pasta(gr.id, `${gr.acervo} · ${gr.nome}`, deles.map(botaoDe), !!GLIFOS.termo || (!sugeridos.length && gr.no_ar)));
  }

  const g = escolhido();
  let repintar = () => {};
  const cores = elemento("div", { class: "cores pequenas", role: "group", "aria-label": "Cor do traço" });
  const flav = (ESQUEMA.paleta.flavors || {})[flavorEmVigor()] || {};
  for (const nome of ESQUEMA.paleta.ordem || []) {
    if (!flav[nome]) continue;
    const b = elemento("button", { type: "button", "aria-pressed": String(nome === cor), "aria-label": nomeDaCor(nome),
      controle: "icone:cor", dica: nomeDaCor(nome),
      onclick: () => { cor = nome; for (const x of cores.children) x.setAttribute("aria-pressed", String(x === b)); repintar(); } });
    b.style.setProperty("--c", flav[nome]);
    cores.append(b);
  }
  cores.hidden = !(g && g.tipo === "traco");

  const botoes = [];
  let usar = null;
  if (itens.some((x) => !travaDe(x))) {
    usar = botao("Usar", { class: "bt principal", controle: "icone:usar", onclick: async () => {
      const x = escolhido();
      if (!x) { torrada("Escolha um desenho", "erro"); return; }
      const corpo = x.tipo !== "traco" ? { app: app.id, arquivo: x.arquivo }
        : { app: app.id, glifo: x.glifo, arquivo: x.arquivo, cor };
      const r = await api("/api/app-icone", { method: "POST", body: JSON.stringify(corpo) });
      if (r.erro) { torrada(r.erro, "erro"); return; }
      torrada(`${maiuscula(app.nome)}: ${x.glifo}`, "ok");
      if (x.tipo === "traco" && r.tirou_escolha) { await rodarAcao("icones_traco"); await fimDoTrabalho(); }
      await depoisDoIcone(app, x.tipo === "traco" ? "icones_traco" : "icones_pack", recarregar);
    } });
  }
  const minha = GLIFOS.app === app.id ? GLIFOS.minha : null;
  if (app.mapa && app.mapa.meu) {
    botoes.push(botao("Desfazer", { class: "bt pequeno", controle: "icone:desfazer-traco", dica: "Volta ao traço de antes",
      onclick: async () => {
        const r = await api("/api/app-icone", { method: "POST", body: JSON.stringify({ app: app.id, remover: true }) });
        if (r.erro) { torrada(r.erro, "erro"); return; }
        await depoisDoIcone(app, "icones_traco", recarregar);
      } }));
  }
  if (minha) {
    botoes.push(botao("Desfazer", { class: "bt pequeno", controle: "icone:desfazer-minha", dica: "Volta ao de antes",
      onclick: async () => {
        const r = await api("/api/app-icone", { method: "POST", body: JSON.stringify({ app: app.id, escolha: true, remover: true }) });
        if (r.erro) { torrada(r.erro, "erro"); return; }
        await depoisDoIcone(app, "icones_pack", recarregar);
      } }));
    if (minha.pack && minha.desenho) {
      botoes.push(botao("Levar para o tema", { class: "bt pequeno", controle: "icone:levar",
        disabled: !!GLIFOS.aviso, dica: GLIFOS.aviso ? maiuscula(GLIFOS.aviso) : "Vale em toda máquina com este tema",
        onclick: async () => {
          const r = await api("/api/app-icone", { method: "POST", body: JSON.stringify({ app: app.id, pack: minha.pack, desenho: minha.desenho }) });
          if (r.erro) { torrada(r.erro, "erro"); return; }
          await depoisDoIcone(app, "icones_pack", recarregar);
        } }));
    }
  }
  const noPack = GLIFOS.app === app.id ? GLIFOS.escolha : null;
  if (noPack) {
    botoes.push(botao("Tirar do tema", { class: "bt pequeno", controle: "icone:tirar-do-pack",
      onclick: async () => {
        const r = await api("/api/app-icone", { method: "POST", body: JSON.stringify({ app: app.id, pack: noPack.pack, remover: true }) });
        if (r.erro) { torrada(r.erro, "erro"); return; }
        await depoisDoIcone(app, "icones_pack", recarregar);
      } }));
  }
  const cabecalho = elemento("header", {}, [
    botao("Apps", { class: "bt leve pequeno", controle: "desenho:volta", icone: "voltar", onclick: () => { APP_ABERTO = null; render(); } }),
    app.url ? elemento("img", { src: app.url, alt: "" }) : null,
    elemento("h2", { texto: maiuscula(app.nome) }),
    elemento("div", { class: "seg mini", role: "group", "aria-label": "De onde vem" }, [["gerar", "Gerar"], ["acervo", "Do acervo"]].map(([id, nome]) =>
      elemento("button", { type: "button", "aria-pressed": String(DESENHO_FONTE === id), "data-fonte": id, controle: "desenho:fonte=" + id,
        onclick: () => { DESENHO_FONTE = id; render(); } }, [nome]))),
  ]);
  if (DESENHO_FONTE === "acervo") {
    const visto = g ? g.url : app.url;
    const lupa = elemento("div", { class: "oficina-lupa" });
    const dock = elemento("div", { class: "oficina-dock", role: "img", "aria-label": "Na dock" });
    const pintarVisto = (fazer) => {
      lupa.replaceChildren(fazer(200));
      dock.replaceChildren(...[48, 32, 22].map(fazer));
    };
    if (visto) pintarVisto((px) => elemento("img", { src: visto, alt: "", width: String(px), height: String(px) }));
    if (g && g.tipo === "traco") {
      const texto = fetch(g.url).then((r) => (r.ok ? r.text() : "")).catch(() => "");
      repintar = () => texto.then((t) => { if (t && desenhar(t, 22, cor)) pintarVisto((px) => desenhar(t, px, cor)); });
      repintar();
    }
    const olho = elemento("div", { class: "desenho-olho" }, [lupa, dock]);
    painel.append(cabecalho,
      elemento("div", { class: "desenho-corpo" }, [olho, elemento("div", { class: "desenho-mao", "data-fonte-corpo": "acervo" }, [
        elemento("div", { class: "fila", style: "justify-content:flex-end" }, [busca]), tira, cores])]),
      elemento("footer", { class: "desenho-pe" }, [...botoes, usar]));
  } else {
    painel.append(cabecalho, oficinaDeDesenho(app, recarregar));
  }
  return painel;
}

function oficinaZerada(id, packBase = "") {
  return { app: id, pack_base: packBase, aberta: false, carregou: false, ocupada: false, erro: "", cor: "",
    original: "", variacoes: [], vizinhos: [], salvo: null, pack: [], arte: false,
    escolhida: null, escolhidaAntes: null, base: "", svg: "", parametros: "", fonte: "icone",
    detalhe: 6, suavidade: 2, cheia: false, fracas: 0, minimo: 0, historico: [], refazer: [], temporizador: null,
    editor: null, editorMtime: 0, editorRelogio: null, gerador: "traco", noPack: null, dopack: false,
    circulo: null, erroPe: "" };
}
let OFICINA = oficinaZerada(null);
let redesenharOficina = () => {};

function desenhar(texto, px, cor, opcoes = {}) {
  let doc;
  try { doc = new DOMParser().parseFromString(String(texto || "").trim(), "image/svg+xml"); } catch (e) { return null; }
  const raizSvg = doc.documentElement;
  if (!raizSvg || raizSvg.nodeName === "parsererror" || doc.querySelector("parsererror")) return null;
  const no = document.importNode(raizSvg, true);
  for (const s of no.querySelectorAll("script, foreignObject")) s.remove();
  no.setAttribute("width", String(px));
  no.setAttribute("height", String(px));
  no.setAttribute("stroke-width", "2.25");
  if (cor) no.style.color = `var(--${cor})`;
  if (opcoes.clicavel) {
    no.querySelectorAll("path").forEach((p, i) => p.addEventListener("click", (e) => { e.preventDefault(); tirarTraco(i); }));
  }
  return no;
}
function desenharArte(texto, px) {
  const t = String(texto || "").trim();
  if (!t.includes("<svg")) return null;
  return elemento("img", { src: "data:image/svg+xml;charset=utf-8," + encodeURIComponent(t), alt: "", width: String(px), height: String(px) });
}
function novoPasso() {
  const atual = OFICINA.svg;
  if (atual && OFICINA.historico[OFICINA.historico.length - 1] !== atual) OFICINA.historico.push(atual);
  if (OFICINA.historico.length > 60) OFICINA.historico.shift();
  OFICINA.refazer = [];
}
function tirarTraco(i) {
  const doc = new DOMParser().parseFromString(OFICINA.svg, "image/svg+xml");
  const caminhos = doc.querySelectorAll("path");
  if (!caminhos[i]) return;
  novoPasso();
  caminhos[i].remove();
  OFICINA.svg = new XMLSerializer().serializeToString(doc);
  OFICINA.escolhida = "editado";
  redesenharOficina();
}
function pararVigiaEditor() {
  if (OFICINA.editorRelogio) clearInterval(OFICINA.editorRelogio);
  OFICINA.editorRelogio = null;
}
async function espiarEditor(pedido) {
  const r = await api("/api/app-desenho", { method: "POST",
    body: JSON.stringify({ app: OFICINA.app, acao: "editor-ler", mtime: OFICINA.editorMtime }) });
  if (r.erro) { pararVigiaEditor(); if (pedido) torrada(r.erro, "erro"); return; }
  if (!r.tem || !r.mudou) { if (pedido) torrada("Nada novo no editor"); return; }
  novoPasso();
  OFICINA.editorMtime = r.mtime;
  OFICINA.svg = r.svg || "";
  OFICINA.arte = false;
  OFICINA.escolhida = "editado";
  redesenharOficina();
  torrada("Voltou do editor", "ok");
}

function oficinaDeDesenho(app, relerLista) {
  const packBase = ROTA.porta === "criar" ? (rascunho().base || {}).pack || "" : "";
  if (OFICINA.app !== app.id || OFICINA.pack_base !== packBase) {
    pararVigiaEditor();
    OFICINA = oficinaZerada(app.id, packBase);
  }
  if (!OFICINA.cor) OFICINA.cor = (app.traco && app.traco.cor) || (app.mapa && app.mapa.cor) || "mauve";
  const raiz = elemento("div", { class: "desenho-gerar" });
  const usar = botao("Usar", { class: "bt principal", id: "d-usar", controle: "oficina:usar" });
  const desfazerPack = botao("Desfazer", { class: "bt leve", id: "d-desfazer", controle: "oficina:desfazer-pack", icone: "voltar" });
  const guardado = elemento("span", { class: "estado-pilula", "data-estado": "ok", id: "d-salvo", texto: "Guardado no pack" });
  const erroPe = elemento("span", { class: "oficina-erro" });
  const pe = elemento("footer", { class: "desenho-pe" }, [erroPe, guardado, desfazerPack, usar]);
  const folha = elemento("div", { class: "oficina-folha", role: "group", "aria-label": "Variações" });
  const dock = elemento("div", { class: "oficina-dock", "aria-label": "Na dock", role: "img" });
  const lupa = elemento("div", { class: "oficina-lupa" });
  const area = elemento("textarea", { class: "campo", rows: "8", spellcheck: "false", "aria-label": "SVG", controle: "oficina:svg" });
  area.value = OFICINA.svg;
  area.addEventListener("input", () => { novoPasso(); OFICINA.svg = area.value; OFICINA.escolhida = "editado"; pintarLupa(); pintarDock(); });
  const secaoVariacoes = elemento("section", { "data-gerador": "" });
  const secaoPartida = elemento("section", {}, [elemento("h3", { texto: "Partida" })]);
  const partida = elemento("div", { class: "oficina-folha" });
  secaoPartida.append(partida);
  const ajuste = elemento("section", {});
  const regua = (nome, rotulo, min = 0, max = 10, formato = (v) => String(v)) => {
    const r = elemento("input", { type: "range", min: String(min), max: String(max), step: "1", value: String(OFICINA[nome]),
      "aria-label": rotulo, controle: "oficina:" + nome, id: "r-" + nome });
    const saida = elemento("output", { texto: formato(OFICINA[nome]) });
    ligarPreenchimento(r);
    r.addEventListener("input", () => { OFICINA[nome] = Number(r.value); saida.textContent = formato(OFICINA[nome]); reguar(); });
    return elemento("label", { class: "oficina-regua" }, [elemento("span", { texto: rotulo }), r, saida]);
  };
  const paleta = (rotulo, chave, atual, aoEscolher, roles = null) => {
    const grupo = elemento("div", { class: "cores pequenas", role: "group", "aria-label": rotulo });
    const flav = (ESQUEMA.paleta.flavors || {})[flavorEmVigor()] || {};
    for (const nome of roles || ESQUEMA.paleta.ordem || []) {
      if (!flav[nome]) continue;
      const hex = String(flav[nome]).toUpperCase();
      const b = elemento("button", { type: "button", "aria-pressed": String(atual === nome || atual === hex), "aria-label": nomeDaCor(nome),
        controle: "oficina:" + chave, dica: nomeDaCor(nome),
        onclick: () => { aoEscolher(nome, hex); for (const x of grupo.children) x.setAttribute("aria-pressed", String(x === b)); } });
      b.style.setProperty("--c", flav[nome]);
      grupo.append(b);
    }
    return elemento("div", { class: "oficina-regua" }, [elemento("span", { texto: rotulo }), grupo]);
  };
  const desfazer = botao("Desfazer edição", { class: "bt leve pequeno", controle: "oficina:desfazer", onclick: () => {
    if (!OFICINA.historico.length) return;
    OFICINA.refazer.push(OFICINA.svg);
    OFICINA.svg = OFICINA.historico.pop();
    pintarTudo();
  } });
  const refazer = botao("Refazer", { class: "bt leve pequeno", controle: "oficina:refazer", onclick: () => {
    if (!OFICINA.refazer.length) return;
    OFICINA.historico.push(OFICINA.svg);
    OFICINA.svg = OFICINA.refazer.pop();
    pintarTudo();
  } });
  const editor = elemento("div", { class: "fila" });
  const edicao = elemento("section", {}, [elemento("h3", { texto: "SVG" }), editor, elemento("div", { class: "fila" }, [desfazer, refazer]), area]);
  const mao = elemento("div", { class: "desenho-mao", "data-fonte-corpo": "gerar" }, [secaoPartida, secaoVariacoes, ajuste, edicao]);
  const olho = elemento("div", { class: "desenho-olho" }, [lupa, dock]);
  raiz.append(elemento("div", { class: "desenho-corpo" }, [olho, mao]), pe);

  function pintarAjuste() {
    ajuste.replaceChildren();
    if (OFICINA.gerador === "circle") {
      ajuste.className = "so-dracula";
      const c = OFICINA.circulo || {};
      const chave = elemento("button", { class: "chave", type: "button", role: "switch", "aria-checked": String(!!c.aro),
        "aria-label": "Aro", controle: "oficina:aro", onclick: () => {
          OFICINA.circulo = { ...OFICINA.circulo, aro: !(OFICINA.circulo && OFICINA.circulo.aro) };
          chave.setAttribute("aria-checked", String(OFICINA.circulo.aro));
          regerar();
        } });
      const tamanho = elemento("input", { type: "range", min: "50", max: "100", step: "1", id: "r-glifo",
        value: String(c.tamanho || 62), "aria-label": "Tamanho do glifo", controle: "oficina:glifo" });
      const saida = elemento("output", { texto: `${c.tamanho || 62} %` });
      ligarPreenchimento(tamanho);
      tamanho.addEventListener("input", () => {
        OFICINA.circulo = { ...OFICINA.circulo, tamanho: Number(tamanho.value) };
        saida.textContent = `${tamanho.value} %`;
        regerar();
      });
      ajuste.append(elemento("h3", { texto: "Ajuste" }),
        paleta("Disco", "disco", String(c.disco || "").toUpperCase(), (_n, hex) => { OFICINA.circulo = { ...OFICINA.circulo, disco: hex }; regerar(); },
          ["surface0", "surface1", "surface2", "base", "mantle", "crust", "mauve", "pink"]),
        elemento("div", { class: "oficina-regua" }, [elemento("span", { texto: "Aro" }), chave]),
        paleta("Glifo", "tinta", String(c.tinta || "").toUpperCase(), (_n, hex) => { OFICINA.circulo = { ...OFICINA.circulo, tinta: hex }; regerar(); },
          ["green", "yellow", "pink", "teal", "sky", "mauve", "peach", "text"]),
        elemento("label", { class: "oficina-regua" }, [elemento("span", { texto: "Tamanho do glifo" }), tamanho, saida]));
      return;
    }
    ajuste.className = "so-meowsystem";
    ajuste.append(elemento("h3", { texto: "Ajuste" }), regua("detalhe", "Detalhe"), regua("suavidade", "Suavidade"),
      regua("fracas", "Linhas fracas"), regua("minimo", "Traço mínimo"),
      paleta("Cor do traço", "cor", OFICINA.cor, (nome) => { OFICINA.cor = nome; pintarTudo(); }));
  }
  function cartaoDe(v, fig, aoClicar) {
    return elemento("button", { type: "button", class: "oficina-cartao", controle: "oficina:variacao", "data-src": v.id,
      "data-salvo": v.id === "guardado" || v.id === "salvo" ? "" : null,
      "aria-pressed": String(OFICINA.escolhida === v.id), disabled: !!v.erro, dica: v.erro ? maiuscula(v.erro) : null,
      onclick: aoClicar }, [fig || elemento("span", { class: "oficina-lugar" }), elemento("span", { texto: maiuscula(v.rotulo) })]);
  }
  function pintarFolha() {
    partida.replaceChildren();
    secaoVariacoes.replaceChildren();
    if (OFICINA.original) {
      partida.append(elemento("button", { type: "button", class: "oficina-cartao", controle: "oficina:original", "data-src": "original",
        "aria-pressed": "false", onclick: () => { if (!OFICINA.ocupada) { OFICINA.fonte = "icone"; reguar(); } } }, [
        elemento("img", { src: OFICINA.original, alt: "", width: "56", height: "56" }), elemento("span", { texto: "Original" })]));
    }
    const nossos = [
      ...(OFICINA.noPack && OFICINA.noPack.tem ? [{ id: "guardado", rotulo: "Guardado", svg: OFICINA.noPack.svg, arte: true }] : []),
      ...OFICINA.pack.map((p) => ({ id: "pack:" + p.pack, rotulo: "Do pack", svg: p.svg, arte: true, dopack: true })),
      ...(OFICINA.salvo && OFICINA.salvo.tem ? [{ id: "salvo", rotulo: "Salvo", svg: OFICINA.salvo.svg }] : []),
    ];
    for (const v of nossos) {
      const fig = v.arte ? desenharArte(v.svg, 56) : desenhar(v.svg, 56, OFICINA.cor);
      partida.append(cartaoDe(v, fig, () => escolherCartao(v)));
    }
    const circulo = OFICINA.gerador === "circle";
    secaoVariacoes.className = circulo ? "so-dracula" : "so-meowsystem";
    secaoVariacoes.dataset.gerador = OFICINA.gerador;
    const titulo = elemento("h3", { texto: circulo ? "Disco e glifo" : "Traço" });
    const grade = elemento("div", { class: "oficina-folha" });
    if (!OFICINA.variacoes.length && OFICINA.ocupada) {
      for (let i = 0; i < 4; i++) grade.append(elemento("span", { class: "oficina-cartao" }, [elemento("span", { class: "oficina-lugar" })]));
    }
    for (const v of OFICINA.variacoes) {
      const fig = v.erro ? null : circulo ? desenharArte(v.svg, 56) : desenhar(v.svg, 56, OFICINA.cor);
      grade.append(cartaoDe(v, fig, () => escolherCartao(v)));
    }
    secaoVariacoes.append(titulo, grade);
  }
  function pintarDock() {
    dock.replaceChildren();
    const eu = OFICINA.arte ? desenharArte(OFICINA.svg, 48) : desenhar(OFICINA.svg, 48, OFICINA.cor);
    if (!eu) return;
    const [a, b] = OFICINA.vizinhos;
    if (a) dock.append(desenhar(a.svg, 48, a.cor) || "");
    dock.append(eu);
    if (b) dock.append(desenhar(b.svg, 48, b.cor) || "");
  }
  function pintarLupa() {
    lupa.replaceChildren();
    if (OFICINA.erro) { lupa.append(elemento("span", { class: "oficina-erro", role: "img", "aria-label": maiuscula(OFICINA.erro), dica: maiuscula(OFICINA.erro) }, [icone("alerta")])); return; }
    if (OFICINA.ocupada) { lupa.append(elemento("span", { class: "bt pequeno", "data-estado": "carregando", "aria-label": "Desenhando" })); return; }
    const no = OFICINA.arte ? desenharArte(OFICINA.svg, 200) : desenhar(OFICINA.svg, 200, OFICINA.cor, { clicavel: true });
    if (no) lupa.append(no);
    lupa.dataset.dica = OFICINA.arte ? "" : "Clique num traço para tirar";
  }
  function pintarEditor() {
    editor.replaceChildren();
    if (!OFICINA.editor || !OFICINA.editor.tem) return;
    editor.append(
      botao(OFICINA.editor.nome ? `Abrir no ${OFICINA.editor.nome}` : "Abrir no editor", { class: "bt leve pequeno",
        controle: "oficina:editor", disabled: !String(OFICINA.svg || "").trim() || OFICINA.dopack, onclick: abrirNoEditor }),
      botao("Reler", { class: "bt leve pequeno", controle: "oficina:reler", icone: "girar", onclick: () => espiarEditor(true) }));
  }
  function pintarPe() {
    const tem = !!(OFICINA.noPack && OFICINA.noPack.tem);
    guardado.hidden = !tem;
    desfazerPack.hidden = !tem;
    erroPe.textContent = OFICINA.erroPe || "";
  }
  function pintarTudo() {
    pintarFolha(); pintarAjuste(); pintarDock(); pintarLupa(); pintarEditor(); pintarPe();
    usar.disabled = !String(OFICINA.svg || "").trim() || OFICINA.ocupada || OFICINA.dopack;
    desfazer.disabled = !OFICINA.historico.length;
    refazer.disabled = !OFICINA.refazer.length;
    if (area.value !== OFICINA.svg) area.value = OFICINA.svg;
  }
  redesenharOficina = pintarTudo;

  function escolherCartao(c) {
    if (!c || c.erro) return;
    novoPasso();
    OFICINA.escolhida = c.id;
    OFICINA.arte = !!c.arte || c.gerador === "circle";
    OFICINA.dopack = !!c.dopack;
    OFICINA.base = OFICINA.svg = c.svg || "";
    OFICINA.parametros = c.parametros || "";
    OFICINA.fonte = c.fonte || "icone";
    if (c.gerador === "circle") OFICINA.circulo = { preset: c.id, disco: c.disco, aro: !!c.aro, tinta: c.tinta, tamanho: c.tamanho };
    for (const k of ["detalhe", "suavidade"]) if (c[k] != null) OFICINA[k] = c[k];
    OFICINA.fracas = c.fracas || 0;
    OFICINA.minimo = c.minimo || 0;
    OFICINA.cheia = !!c.cheia;
    OFICINA.erroPe = "";
    redesenharOficina();
  }
  async function carregar() {
    OFICINA.ocupada = true; redesenharOficina();
    const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({ app: OFICINA.app, acao: "variacoes",
      pack: packEmEdicao() }) });
    OFICINA.ocupada = false;
    OFICINA.carregou = true;
    if (r.erro) { OFICINA.erro = r.erro; redesenharOficina(); return; }
    Object.assign(OFICINA, { original: r.original || "", variacoes: r.variacoes || [], vizinhos: r.vizinhos || [],
      salvo: r.salvo || null, pack: r.pack || [], editor: r.editor || null, gerador: r.gerador || "traco",
      noPack: r.no_pack || null });
    const inicial = OFICINA.noPack && OFICINA.noPack.tem ? { id: "guardado", svg: OFICINA.noPack.svg, arte: true }
      : OFICINA.salvo && OFICINA.salvo.tem ? { id: "salvo", svg: OFICINA.salvo.svg }
      : OFICINA.pack.length ? { id: "pack:" + OFICINA.pack[0].pack, svg: OFICINA.pack[0].svg, arte: true, dopack: true }
      : OFICINA.variacoes.find((v) => !v.erro);
    if (inicial) escolherCartao(inicial); else redesenharOficina();
  }
  function regerar() {
    clearTimeout(OFICINA.temporizador);
    OFICINA.temporizador = setTimeout(async () => {
      const c = OFICINA.circulo || {};
      const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({ app: OFICINA.app, acao: "gerar",
        preset: c.preset || "disco", disco: c.disco, aro: !!c.aro, tinta: c.tinta, tamanho: c.tamanho }) });
      if (r.erro) { OFICINA.erro = r.erro; redesenharOficina(); return; }
      OFICINA.erro = "";
      novoPasso();
      Object.assign(OFICINA, { base: r.svg, svg: r.svg, arte: true, dopack: false, escolhida: "editado" });
      redesenharOficina();
    }, 200);
  }
  function reguar() {
    clearTimeout(OFICINA.temporizador);
    OFICINA.temporizador = setTimeout(async () => {
      OFICINA.ocupada = true; redesenharOficina();
      const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({
        app: OFICINA.app, acao: "vetorizar", fonte: OFICINA.fonte, detalhe: OFICINA.detalhe,
        suavidade: OFICINA.suavidade, cheia: OFICINA.cheia, fracas: OFICINA.fracas, minimo: OFICINA.minimo }) });
      OFICINA.ocupada = false;
      if (r.erro) { OFICINA.erro = r.erro; redesenharOficina(); return; }
      novoPasso();
      Object.assign(OFICINA, { base: r.svg || "", svg: r.svg || "", arte: false, dopack: false, parametros: r.parametros || "",
        escolhida: "editado" });
      redesenharOficina();
    }, 250);
  }
  async function abrirNoEditor() {
    const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({ app: OFICINA.app, acao: "editor", svg: OFICINA.svg }) });
    if (r.erro) { torrada(r.erro, "erro"); return; }
    OFICINA.editorMtime = r.mtime || 0;
    if (r.sem_janela) { torrada(r.aviso || "Sem editor"); return; }
    pararVigiaEditor();
    let espiadas = 0;
    OFICINA.editorRelogio = setInterval(() => {
      if (!document.querySelector(".desenho-gerar") || ++espiadas > 450) { pararVigiaEditor(); return; }
      espiarEditor(false);
    }, 2000);
  }
  usar.addEventListener("click", async (e) => {
    e.preventDefault(); e.stopPropagation();
    OFICINA.erroPe = "";
    let destino = rascunho().pack;
    if (!destino) { await guardarTema(); destino = rascunho().pack; }
    if (!destino) { OFICINA.erroPe = "Não guardou o tema"; pintarPe(); return; }
    const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({
      app: OFICINA.app, acao: "salvar", svg: OFICINA.svg, cor: OFICINA.cor, fonte: OFICINA.fonte,
      parametros: OFICINA.parametros, pack: destino, rotulo: app.nome }) });
    if (r.erro) { OFICINA.erro = ""; OFICINA.erroPe = "Não gravou no pack"; torrada(r.erro, "erro"); pintarPe(); return; }
    OFICINA.noPack = { tem: true, svg: OFICINA.svg, pack: destino };
    OFICINA.escolhida = "guardado";
    redesenharOficina();
    torrada(`${maiuscula(app.nome)}: guardado no pack`, "ok");
    if (r.no_ar) { await rodarAcao("icones_pack"); await fimDoTrabalho(); }
    OFICINA.carregou = false;
  });
  desfazerPack.addEventListener("click", async () => {
    const destino = rascunho().pack;
    const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({ app: OFICINA.app, acao: "desfazer-no-pack", pack: destino }) });
    if (r.erro) { torrada(r.erro, "erro"); return; }
    OFICINA.noPack = { tem: false, svg: "", pack: destino };
    OFICINA.escolhida = null;
    redesenharOficina();
    torrada(`${maiuscula(app.nome)}: tirado do pack`, "ok");
    if (destino === ((packNoAr() || {}).id)) { await rodarAcao("icones_pack"); await fimDoTrabalho(); }
    OFICINA.carregou = false;
  });
  redesenharOficina();
  if (!OFICINA.carregou && !OFICINA.ocupada) carregar();
  return raiz;
}

let AUTORAL = { carregou: false, ocupada: false, erro: "", nomePack: "", desenhos: [], cores: [],
                nome: null, papeis: null, herdadoDe: "", previas: [], temporizador: null };
async function carregarAutoral() {
  AUTORAL.ocupada = true;
  const r = await api("/api/autorais", { method: "POST", body: JSON.stringify({ acao: "listar" }) });
  AUTORAL.ocupada = false;
  AUTORAL.carregou = true;
  AUTORAL.erro = r.erro || "";
  if (!r.erro) Object.assign(AUTORAL, { nomePack: r.nome_pack || "", desenhos: r.desenhos || [], cores: r.cores || [] });
  render();
}
function previaAutoral() {
  clearTimeout(AUTORAL.temporizador);
  AUTORAL.temporizador = setTimeout(async () => {
    const r = await api("/api/autorais", { method: "POST", body: JSON.stringify({ acao: "previa", nome: AUTORAL.nome, papeis: AUTORAL.papeis }) });
    AUTORAL.erro = r.erro || "";
    AUTORAL.previas = r.erro ? [] : (r.previas || []);
    render();
  }, 200);
}
function oficinaAutoral() {
  if (!AUTORAL.carregou) { if (!AUTORAL.ocupada) carregarAutoral(); return null; }
  if (!AUTORAL.desenhos.length) return null;
  const caixa = elemento("section", { class: "autoral", "data-linha": "autorais" });
  caixa.append(elemento("h3", { texto: "Desenhos do tema" }));
  const escolha = elemento("div", { class: "fila", role: "group", "aria-label": "Desenho" });
  for (const d of AUTORAL.desenhos) {
    escolha.append(botao(maiuscula(d.nome), { class: "bt pequeno", controle: "autoral:desenho",
      "aria-pressed": String(AUTORAL.nome === d.nome), disabled: !!d.erro,
      dica: d.herdado ? `Herdado do ${d.nome_origem || d.pack}` : null,
      onclick: () => {
        AUTORAL.nome = d.nome;
        AUTORAL.herdadoDe = d.herdado ? (d.nome_origem || d.pack) : "";
        AUTORAL.papeis = JSON.parse(JSON.stringify(d.papeis || {}));
        AUTORAL.previas = [];
        previaAutoral();
        render();
      } }));
  }
  caixa.append(escolha);
  if (AUTORAL.nome && AUTORAL.papeis) {
    const papeis = elemento("div", { class: "autoral-papeis", role: "group", "aria-label": "Papéis" }, [
      elemento("span"), elemento("span", { texto: "Escuro" }), elemento("span", { texto: "Claro" })]);
    for (const [papel, par] of Object.entries(AUTORAL.papeis)) {
      papeis.append(elemento("span", { texto: maiuscula(papel) }));
      for (const lado of ["escuro", "claro"]) {
        const sel = elemento("select", { class: "campo", "aria-label": `${maiuscula(papel)}, ${lado}`, controle: "autoral:cor" });
        for (const cor of AUTORAL.cores) sel.append(elemento("option", { value: cor, texto: cor === "<accent>" ? "Destaque" : maiuscula(cor), selected: cor === par[lado] }));
        sel.addEventListener("change", () => { par[lado] = sel.value; previaAutoral(); });
        papeis.append(sel);
      }
    }
    caixa.append(papeis);
    const previas = elemento("div", { class: "autoral-previas" });
    for (const p of AUTORAL.previas) {
      const fila = elemento("div", { class: "fila" }, [elemento("span", { texto: maiuscula(p.flavor), style: "min-width:6rem" })]);
      for (const f of p.fundos || []) {
        const s = elemento("span", { dica: maiuscula(f.nome) }, [desenharArte(p.svg, 48)]);
        s.style.setProperty("--f", f.cor);
        fila.append(s);
      }
      previas.append(fila);
    }
    caixa.append(previas);
  }
  if (AUTORAL.erro) caixa.append(elemento("span", { class: "oficina-erro", role: "img", "aria-label": maiuscula(AUTORAL.erro), dica: maiuscula(AUTORAL.erro) }, [icone("alerta")]));
  caixa.append(elemento("div", { class: "fila" }, [botao("Salvar no tema", { class: "bt pequeno principal", controle: "autoral:salvar",
    disabled: !AUTORAL.nome || AUTORAL.ocupada, onclick: async () => {
      AUTORAL.ocupada = true;
      const r = await api("/api/autorais", { method: "POST", body: JSON.stringify({ acao: "salvar", nome: AUTORAL.nome, papeis: AUTORAL.papeis }) });
      AUTORAL.ocupada = false;
      if (r.erro) { AUTORAL.erro = r.erro; torrada(r.erro, "erro"); render(); return; }
      torrada(`${maiuscula(AUTORAL.nome)}: salvo no ${r.nome_pack}`, "ok");
      AUTORAL.carregou = false;
      render();
    } })]));
  return caixa;
}

const GRUPOS_PAREDE = [
  { id: "ativos", rotulo: "No carrossel" }, { id: "noite", rotulo: "Noite" }, { id: "dia", rotulo: "Dia" },
  { id: "favoritos", rotulo: "Favoritas" }, { id: "banidos", rotulo: "Fora" },
];
let ABA_GALERIA = "ativos";
let LIMITE_GALERIA = 24;
async function rodarNaGaleria(id, argumento) {
  const a = ACAO.get(id);
  if (!a) return;
  const r = await api("/api/rodar", { method: "POST", body: JSON.stringify({ acao: id, argumento, confirmado: true }) });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirResultado(r);
}
function montarGaleria(leva = null) {
  const abas = elemento("div", { class: "seg", role: "group", "aria-label": "Grupo" });
  for (const g of GRUPOS_PAREDE) {
    abas.append(elemento("button", { type: "button", "aria-pressed": String(g.id === ABA_GALERIA), controle: "galeria:" + g.id,
      onclick: () => { ABA_GALERIA = g.id; LIMITE_GALERIA = 24; render(); } }, [g.rotulo]));
  }
  const listaParede = previasDe("parede", ABA_GALERIA);
  const grade = elemento("div", { class: "galeria", "aria-busy": listaParede ? null : "true" });
  if (listaParede) {
    for (const i of listaParede.itens.slice(0, LIMITE_GALERIA)) {
      const botoes = [];
      const mini = (icn, rot, id, arg, extra = {}) => botao("", { class: "bt pequeno so-icone", icone: icn, "aria-label": rot,
        dica: rot, controle: "papel:" + id, onclick: () => rodarNaGaleria(id, arg), ...extra });
      if (ABA_GALERIA === "banidos") {
        botoes.push(mini("desfazer", "Devolver", "wallpaper_desbanir", i.rotulo));
      } else if (i.banir) {
        const alvo = i.banir || i.origem;
        botoes.push(mini("certo", "Usar agora", "wallpaper_usar", alvo));
        botoes.push(i.favorito ? mini("estrela", "Tirar das favoritas", "wallpaper_desfavoritar", i.rotulo, { class: "bt pequeno so-icone estrela", "aria-pressed": "true" })
          : mini("estrela", "Favorita", "wallpaper_favoritar", alvo, { class: "bt pequeno so-icone estrela", "aria-pressed": "false" }));
        botoes.push(mini("sol", "De dia", "wallpaper_dia", alvo));
        botoes.push(mini("lua", "De noite", "wallpaper_noite", alvo));
        if (i.lado) botoes.push(mini("girar", "Medir a luz", "wallpaper_lado_auto", alvo));
        botoes.push(mini("lixo", "Tirar do carrossel", "wallpaper_banir", alvo));
        if (leva) {
          const no = !leva.sem && leva.no(i.rotulo);
          botoes.push(botao("", { class: "bt pequeno so-icone levar", icone: "criar", controle: "levar:foto",
            "aria-label": "Levar para o tema", "aria-pressed": String(no), disabled: !!leva.sem,
            "aria-disabled": leva.sem ? "true" : null,
            dica: leva.sem || (no ? "Tirar do tema" : "Levar para o tema"),
            onclick: () => leva.levar(i.rotulo, !no) }));
        }
      }
      grade.append(elemento("figure", { "data-papel": i.rotulo }, [
        i.pronta ? elemento("img", { src: i.url, alt: maiuscula(i.rotulo), loading: "lazy" }) : elemento("div", { class: "lugar" }),
        elemento("div", { class: "fila" }, botoes),
      ]));
    }
  }
  const filhos = [abas, grade];
  if (listaParede && listaParede.itens.length > LIMITE_GALERIA) {
    filhos.push(botao("Mais imagens", { class: "bt", controle: "galeria:mais", onclick: () => { LIMITE_GALERIA += 48; render(); } }));
  }
  return elemento("div", { class: "pilha", style: "gap:16px" }, filhos);
}

let JOGOS = null;
let JOGO_ABERTO = null;
async function carregarJogos() {
  JOGOS = { carregando: true, jogos: [], heroic: [], apps: [] };
  const r = await api("/api/jogos");
  JOGOS = r.erro ? { jogos: [], heroic: [], apps: [] } : r;
  render();
}
async function definirJogo(appid, acao, motivo, remover) {
  const r = await api("/api/jogo-fora", { method: "POST", body: JSON.stringify({ appid, acao, motivo, remover: !!remover }) });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  JOGO_ABERTO = null;
  const t = await api("/api/rodar", { method: "POST", body: JSON.stringify({ acao: "jogos_aplicar", argumento: "", confirmado: true }) });
  if (t.erro) torrada(t.erro, "erro"); else abrirResultado(t);
  JOGOS = null;
}
async function trocarNoLancador(j, ligar) {
  if (j.heroic) { rodar(ACAO.get(ligar ? "jogos_heroic_por" : "jogos_heroic_tirar"), j.id, { semPerguntar: true }); return; }
  const ok = await perguntar({ titulo: ligar ? `Pôr ${j.nome} no lançador?` : `Tirar ${j.nome} do lançador?`,
    ok: ligar ? "Pôr" : "Tirar" });
  if (ok) definirJogo(j.appid, ligar ? "" : "esconder", "", ligar);
}
function montarJogos() {
  if (!JOGOS) { carregarJogos(); return elemento("div", { class: "grade-jogos", "aria-busy": "true" }); }
  const capas = [
    ...(JOGOS.jogos || []).map((j) => ({ ...j, chave: "steam-" + j.appid, ligado: !j.sem_manifesto && !j.acao && !j.gasto })),
    ...(JOGOS.heroic || []).map((j) => ({ ...j, heroic: true, chave: j.id, ligado: j.no_lancador })),
  ].sort((a, b) => String(a.nome).localeCompare(String(b.nome), "pt-BR"));
  const grade = elemento("div", { class: "grade-jogos" });
  for (const j of capas) {
    const icone = (JOGOS.apps || []).find((a) => a.id === (j.heroic ? j.id : `steam_app_${j.appid}`) || a.id === `meow-steam-${j.appid}`);
    grade.append(elemento("div", { class: "jogo" + (j.ligado ? "" : " fora"), "data-jogo": j.chave }, [
      elemento("button", { type: "button", class: "capa", "aria-label": maiuscula(j.nome), controle: "jogo:abrir",
        "aria-expanded": String(JOGO_ABERTO === j.chave),
        onclick: () => { JOGO_ABERTO = JOGO_ABERTO === j.chave ? null : j.chave; render(); } },
        [j.url ? elemento("img", { src: j.url, alt: "", loading: "lazy" }) : elemento("span", { class: "lugar" })]),
      elemento("div", { class: "fila" }, [
        elemento("span", { texto: maiuscula(j.nome), dica: maiuscula(j.motivo || "") || null }),
        elemento("button", { type: "button", class: "chave", role: "switch", "aria-checked": String(!!j.ligado),
          "aria-label": `${maiuscula(j.nome)} no lançador`, controle: "jogo:lancador", onclick: () => trocarNoLancador(j, !j.ligado) }),
      ]),
    ]));
    if (JOGO_ABERTO === j.chave) {
      const painel = elemento("div", { class: "escolha-jogo pilha" });
      if (!j.heroic && !j.gasto && j.no_disco) {
        painel.append(elemento("div", { class: "fila" }, [botao("Apagar os arquivos", { class: "bt pequeno perigo", controle: "jogo:apagar",
          onclick: async () => { if (await perguntar({ titulo: `Apagar os arquivos de ${j.nome}?`, ok: "Apagar", perigo: true })) definirJogo(j.appid, "apagar", ""); } })]));
      }
      if (icone) painel.append(escolhaDeIcone(icone, carregarJogos));
      grade.append(painel);
    }
  }
  return grade;
}

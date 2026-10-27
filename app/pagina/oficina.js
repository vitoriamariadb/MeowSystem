"use strict";

let APPS = null;
let APPS_BUSCA = "";
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
  const r = await api(`/api/glifos?busca=${encodeURIComponent(termo || "")}&app=${encodeURIComponent(app || "")}`);
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
    if (APP_ABERTO === a.id) grade.append(escolhaDeIcone(a, carregarApps));
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
  const painel = elemento("div", { class: "escolha-icone", "data-escolha-icone": app.id });
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
  }, [elemento("img", { src: g.url, alt: "", loading: "lazy" }), elemento("span", { texto: maiuscula(g.rotulo || g.glifo) })]);
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
  const cores = elemento("div", { class: "cores pequenas", role: "group", "aria-label": "Cor do traço" });
  const flav = (ESQUEMA.paleta.flavors || {})[flavorEmVigor()] || {};
  for (const nome of ESQUEMA.paleta.ordem || []) {
    if (!flav[nome]) continue;
    const b = elemento("button", { type: "button", "aria-pressed": String(nome === cor), "aria-label": nomeDaCor(nome),
      controle: "icone:cor", dica: nomeDaCor(nome),
      onclick: () => { cor = nome; for (const x of cores.children) x.setAttribute("aria-pressed", String(x === b)); } });
    b.style.setProperty("--c", flav[nome]);
    cores.append(b);
  }
  cores.hidden = !(g && g.tipo === "traco");

  const botoes = [];
  if (itens.some((x) => !travaDe(x))) {
    botoes.push(botao("Usar", { class: "bt pequeno principal", controle: "icone:usar", onclick: async () => {
      const x = escolhido();
      if (!x) { torrada("Escolha um desenho", "erro"); return; }
      const corpo = x.tipo !== "traco" ? { app: app.id, arquivo: x.arquivo }
        : { app: app.id, glifo: x.glifo, arquivo: x.arquivo, cor };
      const r = await api("/api/app-icone", { method: "POST", body: JSON.stringify(corpo) });
      if (r.erro) { torrada(r.erro, "erro"); return; }
      torrada(`${maiuscula(app.nome)}: ${x.glifo}`, "ok");
      if (x.tipo === "traco" && r.tirou_escolha) { await rodarAcao("icones_traco"); await fimDoTrabalho(); }
      await depoisDoIcone(app, x.tipo === "traco" ? "icones_traco" : "icones_pack", recarregar);
    } }));
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
  painel.append(
    elemento("div", { class: "fila", style: "justify-content:space-between" }, [elemento("h3", { texto: maiuscula(app.nome) }), busca]),
    tira, cores, elemento("div", { class: "fila" }, botoes), oficinaDeDesenho(app, recarregar));
  return painel;
}

function oficinaZerada(id) {
  return { app: id, aberta: false, carregou: false, ocupada: false, erro: "", cor: "",
    original: "", variacoes: [], vizinhos: [], salvo: null, pack: [], arte: false,
    escolhida: null, escolhidaAntes: null, base: "", svg: "", parametros: "", fonte: "icone",
    detalhe: 6, suavidade: 2, cheia: false, fracas: 0, minimo: 0, historico: [], temporizador: null,
    editor: null, editorMtime: 0, editorRelogio: null };
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
function tirarTraco(i) {
  const doc = new DOMParser().parseFromString(OFICINA.svg, "image/svg+xml");
  const caminhos = doc.querySelectorAll("path");
  if (!caminhos[i]) return;
  OFICINA.historico.push(OFICINA.svg);
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
  OFICINA.historico.push(OFICINA.svg);
  OFICINA.editorMtime = r.mtime;
  OFICINA.svg = r.svg || "";
  OFICINA.arte = false;
  OFICINA.escolhida = "editado";
  redesenharOficina();
  torrada("Voltou do editor", "ok");
}

function oficinaDeDesenho(app, relerLista) {
  if (OFICINA.app !== app.id) { pararVigiaEditor(); OFICINA = oficinaZerada(app.id); }
  if (!OFICINA.cor) OFICINA.cor = (app.traco && app.traco.cor) || (app.mapa && app.mapa.cor) || "mauve";
  const caixa = elemento("details", { class: "oficina-desenho" });
  caixa.open = OFICINA.aberta;
  const usar = botao("Usar", { class: "bt pequeno principal", controle: "oficina:usar" });
  caixa.append(elemento("summary", { controle: "oficina:abrir" }, [elemento("span", { texto: "Gerar ícone" }), usar]));
  const folha = elemento("div", { class: "oficina-folha", role: "group", "aria-label": "Variações" });
  const dock = elemento("div", { class: "oficina-dock", "aria-label": "Na dock", role: "img" });
  const lupa = elemento("div", { class: "oficina-lupa" });
  const area = elemento("textarea", { class: "campo", rows: "8", spellcheck: "false", "aria-label": "SVG", controle: "oficina:svg" });
  area.value = OFICINA.svg;
  area.addEventListener("input", () => { OFICINA.historico.push(OFICINA.svg); OFICINA.svg = area.value; OFICINA.escolhida = "editado"; pintarLupa(); pintarDock(); });
  const regua = (nome, rotulo) => {
    const r = elemento("input", { type: "range", min: "0", max: "10", step: "1", value: String(OFICINA[nome]),
      "aria-label": rotulo, controle: "oficina:" + nome });
    r.addEventListener("input", () => { OFICINA[nome] = Number(r.value); reguar(); });
    return elemento("label", { class: "oficina-regua" }, [elemento("span", { texto: rotulo }), r]);
  };
  const cores = elemento("div", { class: "cores pequenas", role: "group", "aria-label": "Cor" });
  const flav = (ESQUEMA.paleta.flavors || {})[flavorEmVigor()] || {};
  for (const nome of ESQUEMA.paleta.ordem || []) {
    if (!flav[nome]) continue;
    const b = elemento("button", { type: "button", "aria-pressed": String(nome === OFICINA.cor), "aria-label": nomeDaCor(nome),
      controle: "oficina:cor", dica: nomeDaCor(nome),
      onclick: () => { OFICINA.cor = nome; for (const x of cores.children) x.setAttribute("aria-pressed", String(x === b)); pintarTudo(); } });
    b.style.setProperty("--c", flav[nome]);
    cores.append(b);
  }
  const desfazer = botao("Desfazer", { class: "bt pequeno", controle: "oficina:desfazer", onclick: () => {
    if (!OFICINA.historico.length) return;
    OFICINA.svg = OFICINA.historico.pop();
    pintarTudo();
  } });
  const editor = elemento("div", { class: "fila" });
  const lado = elemento("div", { class: "oficina-lado" }, [regua("detalhe", "Detalhe"), regua("suavidade", "Suavidade"),
    regua("fracas", "Linhas fracas"), regua("minimo", "Traço mínimo"), cores, elemento("div", { class: "fila" }, [desfazer])]);
  const edicao = elemento("details", {}, [elemento("summary", { texto: "Editar o SVG", controle: "oficina:editar" }), editor, area]);
  caixa.append(elemento("div", { class: "dentro-oficina" }, [folha, dock, elemento("div", { class: "oficina-par" }, [lupa, lado]), edicao]));

  function pintarFolha() {
    folha.replaceChildren();
    if (OFICINA.original) {
      folha.append(elemento("figure", { class: "oficina-cartao", style: "margin:0" }, [
        elemento("img", { src: OFICINA.original, alt: "", width: "72", height: "72" }), elemento("figcaption", { texto: "Original" })]));
    }
    const cartoes = [
      ...OFICINA.pack.map((p) => ({ id: "pack:" + p.pack, rotulo: "Do tema", svg: p.svg, arte: true })),
      ...(OFICINA.salvo && OFICINA.salvo.tem ? [{ id: "salvo", rotulo: "Salvo", svg: OFICINA.salvo.svg }] : []),
      ...OFICINA.variacoes,
    ];
    if (!cartoes.length && OFICINA.ocupada) {
      for (let i = 0; i < 4; i++) folha.append(elemento("span", { class: "oficina-cartao" }, [elemento("span", { class: "oficina-lugar" })]));
    }
    for (const v of cartoes) {
      const fig = v.erro ? null : v.arte ? desenharArte(v.svg, 72) : desenhar(v.svg, 72, OFICINA.cor);
      folha.append(elemento("button", { type: "button", class: "oficina-cartao", controle: "oficina:variacao",
        "aria-pressed": String(OFICINA.escolhida === v.id), disabled: !!v.erro, dica: v.erro ? maiuscula(v.erro) : null,
        onclick: () => escolherCartao(v) }, [fig || elemento("span", { class: "oficina-lugar" }), elemento("span", { texto: maiuscula(v.rotulo) })]));
    }
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
      botao(OFICINA.editor.nome ? `Abrir no ${OFICINA.editor.nome}` : "Abrir no editor", { class: "bt pequeno",
        controle: "oficina:editor", disabled: !String(OFICINA.svg || "").trim() || OFICINA.arte, onclick: abrirNoEditor }),
      botao("Reler", { class: "bt pequeno", controle: "oficina:reler", onclick: () => espiarEditor(true) }));
  }
  function pintarTudo() {
    pintarFolha(); pintarDock(); pintarLupa(); pintarEditor();
    usar.disabled = !String(OFICINA.svg || "").trim() || OFICINA.ocupada || OFICINA.arte;
    desfazer.disabled = !OFICINA.historico.length;
    if (area.value !== OFICINA.svg) area.value = OFICINA.svg;
  }
  redesenharOficina = pintarTudo;

  function escolherCartao(c) {
    if (!c || c.erro) return;
    OFICINA.escolhida = c.id;
    OFICINA.arte = !!c.arte;
    OFICINA.base = OFICINA.svg = c.svg || "";
    OFICINA.parametros = c.parametros || "";
    OFICINA.fonte = c.fonte || "icone";
    for (const k of ["detalhe", "suavidade"]) if (c[k] != null) OFICINA[k] = c[k];
    OFICINA.fracas = c.fracas || 0;
    OFICINA.minimo = c.minimo || 0;
    OFICINA.cheia = !!c.cheia;
    OFICINA.historico = [];
    pintarTudo();
  }
  async function carregar() {
    OFICINA.ocupada = true; pintarTudo();
    const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({ app: OFICINA.app, acao: "variacoes" }) });
    OFICINA.ocupada = false;
    OFICINA.carregou = true;
    if (r.erro) { OFICINA.erro = r.erro; pintarTudo(); return; }
    Object.assign(OFICINA, { original: r.original || "", variacoes: r.variacoes || [], vizinhos: r.vizinhos || [],
      salvo: r.salvo || null, pack: r.pack || [], editor: r.editor || null });
    const inicial = OFICINA.pack.length ? { id: "pack:" + OFICINA.pack[0].pack, svg: OFICINA.pack[0].svg, arte: true }
      : OFICINA.salvo && OFICINA.salvo.tem ? { id: "salvo", svg: OFICINA.salvo.svg }
      : OFICINA.variacoes.find((v) => !v.erro);
    if (inicial) escolherCartao(inicial); else pintarTudo();
  }
  function reguar() {
    clearTimeout(OFICINA.temporizador);
    OFICINA.temporizador = setTimeout(async () => {
      OFICINA.ocupada = true; pintarLupa();
      const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({
        app: OFICINA.app, acao: "vetorizar", fonte: OFICINA.fonte, detalhe: OFICINA.detalhe,
        suavidade: OFICINA.suavidade, cheia: OFICINA.cheia, fracas: OFICINA.fracas, minimo: OFICINA.minimo }) });
      OFICINA.ocupada = false;
      if (r.erro) { OFICINA.erro = r.erro; pintarTudo(); return; }
      Object.assign(OFICINA, { base: r.svg || "", svg: r.svg || "", arte: false, parametros: r.parametros || "",
        historico: [], escolhida: "editado" });
      pintarTudo();
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
      if (!document.querySelector(".oficina-desenho") || ++espiadas > 450) { pararVigiaEditor(); return; }
      espiarEditor(false);
    }, 2000);
  }
  usar.addEventListener("click", async (e) => {
    e.preventDefault(); e.stopPropagation();
    const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({
      app: OFICINA.app, acao: "salvar", svg: OFICINA.svg, cor: OFICINA.cor, fonte: OFICINA.fonte, parametros: OFICINA.parametros }) });
    if (r.erro) { OFICINA.erro = r.erro; torrada(r.erro, "erro"); pintarLupa(); return; }
    torrada(`${maiuscula(app.nome)}: desenho salvo`, "ok");
    await rodarAcao("icones_traco");
    OFICINA.carregou = false;
    await fimDoTrabalho();
    await relerLista();
  });
  caixa.addEventListener("toggle", () => {
    OFICINA.aberta = caixa.open;
    if (caixa.open && !OFICINA.carregou && !OFICINA.ocupada) carregar();
    if (!caixa.open) pararVigiaEditor();
  });
  pintarTudo();
  if (OFICINA.aberta && !OFICINA.carregou && !OFICINA.ocupada) carregar();
  return caixa;
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

"use strict";

const MOD = { dados: null, quando: 0, pedindo: false, mudou: 0, menu: "" };
const PILULA_DO_CARTAO = {
  fora: ["alerta", "Fora do lugar"], erro: ["erro", "Falhou"], desligado: ["neutro", "Desligado"],
  nao_aplica: ["neutro", "Não aplica"], nao_instalado: ["neutro", "Não instalado"],
};
const PILULA_DO_ITEM = { 0: ["ok", "No lugar"], 1: ["alerta", "Fora do lugar"], 2: ["erro", "Falhou"], 3: ["neutro", "Não aplica"] };

async function carregarModificacoes() {
  if (MOD.pedindo) return;
  MOD.pedindo = true;
  MOD.quando = Date.now();
  const marca = MOD.mudou;
  const r = await api("/api/modificacoes");
  MOD.pedindo = false;
  if (marca !== MOD.mudou) { MOD.quando = 0; return carregarModificacoes(); }
  MOD.dados = r.erro ? { erro: r.erro, cartoes: [] } : r;
  if (ROTA.porta === "modificacoes") render();
}

function releModificacoes() {
  MOD.mudou += 1;
  MOD.quando = 0;
  carregarModificacoes();
}

async function depoisDeAplicar() {
  for (let n = 0; n < 4800 && (EM_VOO || ACOMPANHANDO); n++) await new Promise((ok) => setTimeout(ok, 250));
  releModificacoes();
}

function appsAtivos() {
  return String(vale("APPS_ATIVOS") || "").split(",").map((s) => s.trim()).filter(Boolean);
}

function temaLigado(t) {
  const ativos = appsAtivos();
  return t.slugs.some((s) => ativos.includes(s));
}

function chaveLigada(k) {
  return String(vale(k) || "") !== "nao";
}

function cartaoLigado(c) {
  return c.temas.some(temaLigado) || (c.chaves || []).some(chaveLigada);
}

function soUmTema(c) {
  return c.temas.length === 1 && !c.correcoes.length;
}

function reverterEDepois(temas, fim) {
  if (!temas.length) return fim();
  return rodar(ACAO.get("modificacao_reverter"), temas[0].pasta, {
    semPerguntar: true, depois: () => reverterEDepois(temas.slice(1), fim) });
}

function alternarCartao(c) {
  const ligar = !cartaoLigado(c);
  const ativos = appsAtivos();
  const lote = {};
  for (const k of c.chaves || []) lote[k] = ligar ? "sim" : "nao";
  if (c.temas.length) {
    const slugs = c.temas.flatMap((t) => t.slugs);
    lote.APPS_ATIVOS = ligar ? [...ativos, ...c.temas.filter((t) => !temaLigado(t)).map((t) => t.pasta)].join(",")
      : ativos.filter((s) => !slugs.includes(s)).join(",");
  }
  const gravar = () => gravarAgora(lote).then(depoisDeAplicar);
  if (ligar) return gravar();
  return reverterEDepois(c.temas.filter(temaLigado), gravar);
}

function nomeDoCartao(c) {
  return c.nome || nomeDePrograma(c.id);
}

function pilula([estado, texto], dica) {
  return elemento("span", { class: "estado-pilula", "data-estado": estado, texto, dica: dica || "" });
}

function situacaoDoCartao(c) {
  if (c.estado === "ok") {
    const t = c.temas.find((x) => x.ligado && x.rc === 0);
    return pilula(["ok", t ? t.no_ar || "No lugar" : "No lugar"]);
  }
  const motivo = c.estado === "nao_aplica" || c.estado === "nao_instalado"
    ? (c.temas.find((t) => t.motivo) || {}).motivo : "";
  return pilula(PILULA_DO_CARTAO[c.estado] || PILULA_DO_CARTAO.nao_aplica, motivo);
}

function interruptorDoCartao(c) {
  const liga = cartaoLigado(c);
  const t = soUmTema(c) ? c.temas[0] : null;
  return elemento("button", { type: "button", class: "chave", role: "switch", "aria-checked": String(liga),
    "aria-label": nomeDoCartao(c), "data-linha": [...(t ? ["APPS_ATIVOS"] : []), ...(c.chaves || [])].join(" ") || null,
    controle: t ? "chave:APPS_ATIVOS:" + t.pasta : "modificacao:ligar:" + c.id,
    onclick: () => alternarCartao(c) });
}

function fecharMenus() {
  MOD.menu = "";
  for (const d of document.querySelectorAll("details.menu-mod[open]")) d.open = false;
}

function itemDoMenu(texto, props) {
  return elemento("button", { type: "button", role: "menuitem", ...props, texto });
}

function escolherTema(t, nome) {
  fecharMenus();
  api("/api/modificacao-tema-padrao", { method: "POST", body: JSON.stringify({ app: t.pasta, nome }) }).then((r) => {
    if (r.erro) { torrada(r.erro, "erro"); return; }
    if (temaLigado(t)) rodar(ACAO.get("modificacao_aplicar"), t.pasta, { semPerguntar: true, depois: releModificacoes });
    else releModificacoes();
  });
}

function itensDeTema(t, sozinho) {
  const itens = [];
  const nome = sozinho ? "" : " · " + nomeDePrograma(t.pasta);
  for (const n of t.adicionados || []) {
    itens.push(elemento("button", { type: "button", role: "menuitemradio", "aria-checked": String(t.padrao === n),
      controle: "modificacao:tema:" + t.pasta + ":" + n, onclick: () => escolherTema(t, n) },
    [icone("certo"), elemento("span", { texto: n })]));
  }
  if ((t.aceita || []).length) {
    itens.push(itemDoMenu("Adicionar tema" + nome, { controle: "modificacao:adicionar:" + t.pasta,
      onclick: () => { fecharMenus(); abrirAdicionarTema(t.pasta); } }));
  }
  if (t.padrao) {
    itens.push(itemDoMenu("Voltar ao do pack" + nome, { controle: "modificacao:pack:" + t.pasta,
      onclick: () => escolherTema(t, "") }));
  }
  if (t.instalado && temaLigado(t) && (t.rc === 1 || t.rc === 2) && ACAO.get("modificacao_aplicar")) {
    itens.push(itemDoMenu("Pôr no lugar" + nome, { controle: "acao:modificacao_aplicar:" + t.pasta,
      onclick: () => { fecharMenus(); rodar(ACAO.get("modificacao_aplicar"), t.pasta, { semPerguntar: true, depois: releModificacoes }); } }));
  }
  return itens;
}

function linhaDeCorrecao(c) {
  const acao = ACAO.get("modificacao_corrigir");
  const fora = c.ligado && (c.rc === 1 || c.rc === 2);
  return elemento("li", { class: "item-mod", "data-linha": "correcao:" + c.nome }, [
    elemento("span", { class: "rot-mod" }, [elemento("span", { texto: c.rotulo || c.nome })]),
    elemento("span", { class: "ctl-mod" }, [
      fora && acao ? botao("Pôr no lugar", { class: "bt pequeno", controle: "acao:modificacao_corrigir:" + c.nome,
        dica: PILULA_DO_ITEM[c.rc][1],
        onclick: () => { fecharMenus(); rodar(acao, c.nome, { semPerguntar: true, depois: releModificacoes }); } })
        : pilula(c.ligado ? PILULA_DO_ITEM[c.rc] || PILULA_DO_ITEM[3] : ["neutro", "Desligado"]),
    ]),
  ]);
}

function linhaDeExtensao(e) {
  const acao = ACAO.get("vscode_instalar_extensao");
  return elemento("li", { class: "item-mod", "data-linha": "extensao:" + e }, [
    elemento("span", { class: "rot-mod" }, [elemento("span", { texto: e })]),
    elemento("span", { class: "ctl-mod" }, [acao ? botao("Instalar", { class: "bt pequeno",
      controle: "acao:vscode_instalar_extensao:" + e, dica: acao.rotulo,
      onclick: () => rodar(acao, e, { depois: releModificacoes }) }) : null]),
  ]);
}

function menuDoCartao(c) {
  const detalhe = LUGAR_MODIFICACOES.detalhes.find((d) => d.id === c.id);
  const chaves = LUGAR_MODIFICACOES.chaves.filter((l) => l.cartao === c.id && CHAVE.has(l.c));
  const temas = c.temas.flatMap((t) => itensDeTema(t, c.temas.length === 1));
  const corpo = [
    ...temas,
    c.correcoes.length ? elemento("ul", { class: "itens-mod" }, c.correcoes.map(linhaDeCorrecao)) : null,
    (c.extensoes || []).length ? elemento("ul", { class: "itens-mod" }, c.extensoes.map(linhaDeExtensao)) : null,
    chaves.length ? lista(chaves) : null,
    detalhe ? elemento("a", { href: "#modificacoes/" + detalhe.id, role: "menuitem", controle: "modificacao:" + detalhe.id,
      onclick: fecharMenus }, [elemento("span", { texto: "Abrir" }), icone("seta")]) : null,
  ].filter(Boolean);
  const pontos = [icone("pontos")];
  const rotulo = "Opções de " + nomeDoCartao(c);
  if (!corpo.length) {
    return elemento("button", { type: "button", class: "bt leve pequeno so-icone", disabled: true, "aria-label": rotulo,
      controle: "modificacao:menu:" + c.id }, pontos);
  }
  const d = elemento("details", { class: "menu menu-mod", open: MOD.menu === c.id }, [
    elemento("summary", { class: "bt leve pequeno so-icone", "aria-label": rotulo, controle: "modificacao:menu:" + c.id,
      dica: "Opções" }, pontos),
    elemento("div", { class: "menu-corpo", role: "menu" }, corpo),
  ]);
  d.addEventListener("toggle", () => {
    if (d.open) {
      MOD.menu = c.id;
      for (const outro of document.querySelectorAll("details.menu-mod[open]")) if (outro !== d) outro.open = false;
    } else if (MOD.menu === c.id) MOD.menu = "";
  });
  return d;
}

function cartaoDeModificacao(c) {
  return elemento("article", { class: "bloco cartao-mod", "data-cartao": c.id, "data-estado": c.estado }, [
    elemento("div", { class: "cabeca-cartao" }, [
      elemento("span", { class: "marca-app" }, [c.icone && IC[c.icone] ? icone(c.icone)
        : elemento("b", { texto: nomeDoCartao(c).charAt(0).toLocaleUpperCase("pt-BR") })]),
      elemento("div", { class: "nome-mod" }, [elemento("h3", { texto: nomeDoCartao(c) }), situacaoDoCartao(c)]),
      interruptorDoCartao(c),
      menuDoCartao(c),
    ]),
  ]);
}

function temasQueAceitam() {
  return ((MOD.dados && MOD.dados.cartoes) || []).flatMap((c) => c.temas).filter((t) => (t.aceita || []).length);
}

let ADICIONAR_TEMA = { arquivo: null };

function dialogoAdicionarTema() {
  let d = document.getElementById("adicionar-tema");
  if (d) return d;
  const app = elemento("select", { class: "campo", id: "tema-app", controle: "adicionar-tema:app" });
  const escolha = elemento("input", { type: "file", hidden: true, id: "tema-arquivo" });
  const botaoArquivo = botao("Escolher arquivo", { class: "bt", icone: "pasta", id: "tema-arquivo-bt", controle: "adicionar-tema:arquivo",
    onclick: () => escolha.click() });
  const url = elemento("input", { class: "campo", id: "tema-url", type: "url", spellcheck: "false", autocomplete: "off",
    placeholder: "https://…", controle: "adicionar-tema:url" });
  const selo = elemento("span", { class: "selo", id: "tema-selo", texto: "baixa da internet", hidden: true });
  d = elemento("dialog", { id: "adicionar-tema", "aria-labelledby": "adicionar-tema-t", "data-passo": "escolha" }, [
    elemento("div", { class: "dentro" }, [
      elemento("h2", { id: "adicionar-tema-t", texto: "Adicionar tema" }),
      elemento("label", { class: "pilha-campo" }, [elemento("span", { texto: "Programa" }), app]),
      elemento("div", { class: "pilha-campo" }, [elemento("span", { texto: "Arquivo" }), botaoArquivo, escolha]),
      elemento("label", { class: "pilha-campo" }, [elemento("span", { texto: "Endereço" }), url]),
      selo,
      elemento("p", { class: "oficina-erro", id: "adicionar-tema-queixa", role: "alert" }),
      elemento("span", { class: "estado-pilula p-gravando", "data-estado": "correndo", texto: "Guardando" }),
      elemento("div", { class: "acoes" }, [
        elemento("button", { class: "bt leve", type: "button", controle: "adicionar-tema:cancelar", texto: "Cancelar",
          onclick: () => d.close() }),
        botao("Adicionar", { class: "bt principal", id: "adicionar-tema-ok", icone: "mais", controle: "adicionar-tema:adicionar",
          onclick: enviarTema }),
      ]),
    ]),
  ]);
  const limpar = () => { $("#adicionar-tema-queixa").textContent = ""; };
  app.addEventListener("change", () => { prepararAceita(); limpar(); });
  escolha.addEventListener("change", () => {
    ADICIONAR_TEMA.arquivo = escolha.files[0] || null;
    if (ADICIONAR_TEMA.arquivo) url.value = "";
    selo.hidden = !url.value.trim();
    botaoArquivo.querySelector("span").textContent = ADICIONAR_TEMA.arquivo ? ADICIONAR_TEMA.arquivo.name : "Escolher arquivo";
    limpar();
  });
  url.addEventListener("input", () => { selo.hidden = !url.value.trim(); limpar(); });
  url.addEventListener("keydown", (ev) => { if (ev.key === "Enter") { ev.preventDefault(); enviarTema(); } });
  d.addEventListener("cancel", (ev) => { if (d.dataset.passo === "gravando") ev.preventDefault(); });
  document.body.append(d);
  return d;
}

function prepararAceita() {
  const t = temasQueAceitam().find((x) => x.pasta === $("#tema-app").value);
  $("#tema-arquivo").accept = t ? t.aceita.join(",") : "";
}

function abrirAdicionarTema(pasta) {
  const d = dialogoAdicionarTema();
  const temas = temasQueAceitam();
  if (!temas.length) return;
  $("#tema-app").replaceChildren(...temas.map((t) => elemento("option", { value: t.pasta, texto: nomeDePrograma(t.pasta) })));
  $("#tema-app").value = temas.some((t) => t.pasta === pasta) ? pasta : temas[0].pasta;
  ADICIONAR_TEMA = { arquivo: null };
  $("#tema-arquivo").value = "";
  $("#tema-arquivo-bt span").textContent = "Escolher arquivo";
  $("#tema-url").value = "";
  $("#tema-selo").hidden = true;
  $("#adicionar-tema-queixa").textContent = "";
  d.dataset.passo = "escolha";
  prepararAceita();
  d.showModal();
  $("#tema-app").focus();
}

async function enviarTema() {
  const d = dialogoAdicionarTema();
  if (d.dataset.passo === "gravando") return;
  const pasta = $("#tema-app").value;
  const url = $("#tema-url").value.trim();
  const arquivo = ADICIONAR_TEMA.arquivo;
  const queixa = $("#adicionar-tema-queixa");
  if (!url && !arquivo) { queixa.textContent = "Escolha um arquivo ou dê o endereço"; return; }
  d.dataset.passo = "gravando";
  let corpo;
  try {
    corpo = url ? { app: pasta, url } : { app: pasta, nome: arquivo.name, conteudo: await lerComoBase64(arquivo) };
  } catch (e) {
    d.dataset.passo = "escolha";
    queixa.textContent = e.message;
    return;
  }
  const r = await api("/api/modificacao-tema", { method: "POST", body: JSON.stringify(corpo) });
  d.dataset.passo = "escolha";
  if (r.erro) { queixa.textContent = maiuscula(r.erro); return; }
  d.close();
  const t = temasQueAceitam().find((x) => x.pasta === pasta);
  if (t && temaLigado(t)) rodar(ACAO.get("modificacao_aplicar"), pasta, { semPerguntar: true, depois: releModificacoes });
  else releModificacoes();
}

function cabecaDeModificacoes() {
  const botoes = LUGAR_MODIFICACOES.cabeca.map((l) => {
    const a = ACAO.get(l.a);
    if (!a) return null;
    return botao(l.b, { class: "bt pequeno" + (a.escreve ? " principal" : ""), controle: "acao:" + a.id,
      dica: l.r !== l.b ? l.r : "", onclick: () => rodar(a, "", { depois: releModificacoes }) });
  }).filter(Boolean);
  if (temasQueAceitam().length) {
    botoes.unshift(botao("Adicionar tema", { class: "bt pequeno", icone: "mais", controle: "modificacao:adicionar",
      onclick: () => abrirAdicionarTema("") }));
  }
  return elemento("div", { class: "cabeca-mod" }, [
    elemento("h1", { texto: "Modificações" }),
    elemento("div", { class: "fila" }, botoes),
  ]);
}

function paginaDetalheDeModificacao(d) {
  const sobra = (l) => l.e || (l.g && !l.g.startsWith("acervo:")) || l.g === "acervo:gato" || l.g === "acervo:cursor";
  return [
    elemento("h1", { class: "sr", texto: d.nome }),
    elemento("a", { class: "bt leve pequeno voltar-mod", href: "#modificacoes", controle: "modificacao:voltar" },
      [icone("voltar"), elemento("span", { texto: "Modificações" })]),
    elemento("div", { class: "oficina" }, [
      elemento("div", { class: "palco" }, [mesaDaPagina(d.id)]),
      elemento("div", { class: "pilha" }, d.blocos.map((b) => bloco(b.titulo, [lista(b.linhas, sobra)]))),
    ]),
  ];
}

document.addEventListener("click", (e) => {
  if (MOD.menu && !e.target.closest("details.menu-mod")) fecharMenus();
});
document.addEventListener("keydown", (e) => {
  if (e.key !== "Escape" || !MOD.menu) return;
  const aberto = document.querySelector("details.menu-mod[open] summary");
  fecharMenus();
  if (aberto) aberto.focus();
});

function paginaModificacoes(sub) {
  const d = LUGAR_MODIFICACOES.detalhes.find((x) => x.id === sub);
  if (d) return paginaDetalheDeModificacao(d);
  if (!MOD.pedindo && (!MOD.quando || Date.now() - MOD.quando > 60000)) carregarModificacoes();
  const dados = MOD.dados;
  if (!dados) {
    return [cabecaDeModificacoes(), elemento("div", { class: "grade-mod", "aria-busy": "true" },
      [1, 2, 3, 4, 5, 6].map(() => elemento("span", { class: "esqueleto", style: "height: 88px" })))];
  }
  if (dados.erro) {
    return [cabecaDeModificacoes(), elemento("div", { class: "vazio" }, [icone("alerta"), elemento("p", { texto: dados.erro })])];
  }
  const vistos = new Set(dados.cartoes.map((c) => c.id));
  const fixos = LUGAR_MODIFICACOES.detalhes.filter((x) => !vistos.has(x.id))
    .map((x) => ({ id: x.id, nome: x.nome, icone: x.icone, temas: [], correcoes: [], chaves: [], estado: "nao_aplica" }));
  const cartoes = [...dados.cartoes, ...fixos].sort((a, b) => nomeDoCartao(a).localeCompare(nomeDoCartao(b), "pt-BR"));
  return [
    cabecaDeModificacoes(),
    cartoes.length ? elemento("div", { class: "grade-mod" }, cartoes.map(cartaoDeModificacao))
      : elemento("div", { class: "vazio" }, [icone("pincel"), elemento("p", { texto: "Nenhum programa com tema" })]),
  ];
}

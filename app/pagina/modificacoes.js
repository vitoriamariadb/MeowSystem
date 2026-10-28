"use strict";

const MOD = { dados: null, quando: 0, pedindo: false, mudou: 0 };
const PILULA_DO_CARTAO = {
  ok: ["ok", "Aplicado"], fora: ["alerta", "Fora do lugar"], erro: ["erro", "Falhou"],
  desligado: ["neutro", "Desligado"], nao_aplica: ["neutro", "Não aplica"],
};
const PILULA_DO_ITEM = { 0: ["ok", "No lugar"], 1: ["alerta", "Fora do lugar"], 2: ["erro", "Falhou"] };

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

function alternarTema(t) {
  const ativos = appsAtivos();
  if (!temaLigado(t)) {
    gravarAgora({ APPS_ATIVOS: [...ativos, t.pasta].join(",") }).then(depoisDeAplicar);
    return;
  }
  rodar(ACAO.get("modificacao_reverter"), t.pasta, {
    semPerguntar: true,
    depois: () => gravarAgora({ APPS_ATIVOS: ativos.filter((s) => !t.slugs.includes(s)).join(",") }).then(depoisDeAplicar),
  });
}

function nomeDoCartao(c) {
  return c.nome || nomeDePrograma(c.id);
}

function pilula([estado, texto]) {
  return elemento("span", { class: "estado-pilula", "data-estado": estado, texto });
}

function botaoPorNoLugar(acaoId, arg, rotulo) {
  const acao = ACAO.get(acaoId);
  if (!acao) return null;
  return botao("Pôr no lugar", { class: "bt pequeno", controle: "acao:" + acaoId + ":" + arg,
    dica: rotulo, onclick: () => rodar(acao, arg, { semPerguntar: true, depois: releModificacoes }) });
}

function linhaDeTema(t, sozinho) {
  const liga = temaLigado(t);
  const rotulo = sozinho ? "Tema" : nomeDePrograma(t.pasta);
  const fora = t.ligado && (t.rc === 1 || t.rc === 2);
  return elemento("li", { class: "item-mod", "data-linha": "APPS_ATIVOS" }, [
    elemento("span", { class: "rot-mod" }, [elemento("span", { texto: rotulo }),
      t.ligado && t.rc === 3 && t.motivo ? elemento("small", { texto: t.motivo }) : null]),
    elemento("span", { class: "ctl-mod" }, [
      fora ? botaoPorNoLugar("modificacao_aplicar", t.pasta, "Aplicar o tema de novo") : null,
      elemento("button", { type: "button", class: "chave", role: "switch", "aria-checked": String(liga),
        "aria-label": "Tema de " + nomeDePrograma(t.pasta), controle: "chave:APPS_ATIVOS:" + t.pasta,
        onclick: () => alternarTema(t) }),
    ]),
  ]);
}

function linhaDeCorrecao(c) {
  return elemento("li", { class: "item-mod", "data-linha": "correcao:" + c.nome }, [
    elemento("span", { class: "rot-mod" }, [elemento("span", { texto: c.rotulo || c.nome })]),
    elemento("span", { class: "ctl-mod" }, [
      c.rc === 0 ? pilula(PILULA_DO_ITEM[0])
        : botaoPorNoLugar("modificacao_corrigir", c.nome, PILULA_DO_ITEM[c.rc] ? PILULA_DO_ITEM[c.rc][1] : ""),
    ]),
  ]);
}

function cartaoDeModificacao(c) {
  const detalhe = LUGAR_MODIFICACOES.detalhes.find((d) => d.id === c.id);
  const chaves = LUGAR_MODIFICACOES.chaves.filter((l) => l.cartao === c.id && CHAVE.has(l.c));
  const itens = [
    ...c.temas.map((t) => linhaDeTema(t, c.temas.length === 1 && t.pasta === c.id)),
    ...c.correcoes.map(linhaDeCorrecao),
  ];
  return elemento("article", { class: "bloco cartao-mod", "data-cartao": c.id }, [
    elemento("div", { class: "cabeca-cartao" }, [
      elemento("span", { class: "marca-app" }, [c.icone && IC[c.icone] ? icone(c.icone)
        : elemento("b", { texto: nomeDoCartao(c).charAt(0).toLocaleUpperCase("pt-BR") })]),
      elemento("h3", { texto: nomeDoCartao(c) }),
      pilula(PILULA_DO_CARTAO[c.estado] || PILULA_DO_CARTAO.nao_aplica),
    ]),
    itens.length ? elemento("ul", { class: "itens-mod" }, itens) : null,
    chaves.length ? lista(chaves) : null,
    detalhe ? elemento("a", { class: "bt leve pequeno abrir-mod", href: "#modificacoes/" + detalhe.id,
      controle: "modificacao:" + detalhe.id }, [elemento("span", { texto: "Abrir" }), icone("seta")]) : null,
  ]);
}

function cabecaDeModificacoes() {
  const botoes = LUGAR_MODIFICACOES.cabeca.map((l) => {
    const a = ACAO.get(l.a);
    if (!a) return null;
    return botao(l.b, { class: "bt pequeno" + (a.escreve ? " principal" : ""), controle: "acao:" + a.id,
      dica: l.r !== l.b ? l.r : "", onclick: () => rodar(a, "", { depois: releModificacoes }) });
  }).filter(Boolean);
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

function paginaModificacoes(sub) {
  const d = LUGAR_MODIFICACOES.detalhes.find((x) => x.id === sub);
  if (d) return paginaDetalheDeModificacao(d);
  if (!MOD.pedindo && (!MOD.quando || Date.now() - MOD.quando > 60000)) carregarModificacoes();
  const dados = MOD.dados;
  if (!dados) {
    return [cabecaDeModificacoes(), elemento("div", { class: "grade-mod", "aria-busy": "true" },
      [1, 2, 3, 4, 5, 6].map(() => elemento("span", { class: "esqueleto", style: "height: 168px" })))];
  }
  if (dados.erro) {
    return [cabecaDeModificacoes(), elemento("div", { class: "vazio" }, [icone("alerta"), elemento("p", { texto: dados.erro })])];
  }
  const vistos = new Set(dados.cartoes.map((c) => c.id));
  const fixos = LUGAR_MODIFICACOES.detalhes.filter((x) => !vistos.has(x.id))
    .map((x) => ({ id: x.id, nome: x.nome, icone: x.icone, temas: [], correcoes: [], estado: "nao_aplica" }));
  const cartoes = [...dados.cartoes, ...fixos].sort((a, b) => nomeDoCartao(a).localeCompare(nomeDoCartao(b), "pt-BR"));
  return [
    cabecaDeModificacoes(),
    cartoes.length ? elemento("div", { class: "grade-mod" }, cartoes.map(cartaoDeModificacao))
      : elemento("div", { class: "vazio" }, [icone("pincel"), elemento("p", { texto: "Nenhum programa com tema instalado" })]),
  ];
}

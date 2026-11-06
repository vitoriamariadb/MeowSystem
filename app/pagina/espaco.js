"use strict";

const ESP = { dados: null, quando: 0, pedindo: false, religar: null };
const CATEGORIA_ESPACO = {
  "reconstruível": { nome: "Reconstruível", cor: "accent" },
  backup: { nome: "Backups", cor: "alerta" },
  "de quem usa": { nome: "Seus dados", cor: "mudo" },
};

function tamanhoEmTexto(n) {
  if (n >= 2 ** 30) return (n / 2 ** 30).toFixed(1).replace(".", ",") + " GB";
  if (n >= 2 ** 20) return Math.round(n / 2 ** 20) + " MB";
  if (n >= 2 ** 10) return Math.round(n / 2 ** 10) + " KB";
  return n + " B";
}

async function carregarEspaco() {
  if (ESP.pedindo) return;
  ESP.pedindo = true;
  ESP.quando = Date.now();
  const r = await api("/api/espaco");
  ESP.pedindo = false;
  ESP.dados = r;
  clearTimeout(ESP.religar);
  if (r && r.ocupado) ESP.religar = setTimeout(() => { ESP.quando = 0; if (emEspaco()) render(); }, 2500);
  if (emEspaco()) render();
}

function emEspaco() {
  return ROTA.porta === "extensoes" && ROTA.sub === "espaco";
}

function barraDoEspaco(d) {
  const partes = d.categorias.filter((c) => c.bytes > 0).map((c) => elemento("i", {
    class: "fatia " + CATEGORIA_ESPACO[c.categoria].cor, "data-categoria": c.categoria,
    style: "flex-grow: " + c.bytes,
    dica: CATEGORIA_ESPACO[c.categoria].nome + " · " + tamanhoEmTexto(c.bytes),
  }));
  return elemento("span", { class: "barra-do-espaco", role: "img", "aria-label": "Espaço por categoria" }, partes);
}

function cabecaDoEspaco(d) {
  const nada = d.liberavel <= 0;
  const parado = nada || d.ocupado;
  const preco = nada ? null : elemento("span", { class: "preco", "data-preco": true,
    texto: tamanhoEmTexto(d.liberavel) + (d.refazer ? " · ~" + d.refazer + " min" : "") });
  const liberar = botao("Liberar", { class: "bt principal", icone: "lixo", disabled: parado,
    controle: "espaco:liberar", onclick: () => rodar(ACAO.get("espaco_liberar"), "", { verbo: "Liberar",
      depois: () => { ESP.quando = 0; carregarEspaco(); } }) }, [preco]);
  const dica = d.ocupado ? "Há um build em curso" : nada ? "Nada para liberar"
    : "Tira o que o MeowSystem reconstrói sozinho. O próximo build compila de novo, e leva ~" + d.refazer + " min.";
  return elemento("section", { class: "bloco espaco-cabeca", "data-bloco": "Espaço" }, [
    elemento("div", { class: "espaco-total" }, [
      elemento("b", { "data-total": true, texto: tamanhoEmTexto(d.total) }),
      barraDoEspaco(d),
    ]),
    elemento("span", { class: "espaco-acao", dica }, [liberar]),
  ]);
}

function linhaDoEspaco(g, total) {
  const cor = CATEGORIA_ESPACO[g.categoria].cor;
  const parte = total > 0 ? Math.max(1, Math.round(100 * g.bytes / total)) : 0;
  const dica = g.dica + (g.liberavel ? " Dá para liberar " + tamanhoEmTexto(g.liberavel)
    + (g.refazer ? ", e refazer leva ~" + g.refazer + " min." : ".") : "");
  return elemento("li", { class: "linha", "data-espaco": g.nome, tabindex: "0", dica }, [
    elemento("span", { class: "rot" }, [elemento("b", { texto: g.nome })]),
    elemento("span", { class: "ctl" }, [
      elemento("span", { class: "barrinha " + cor }, [elemento("i", { style: "width: " + parte + "%" })]),
      elemento("span", { class: "numero", texto: tamanhoEmTexto(g.bytes) }),
    ]),
  ]);
}

function blocoDeCategoria(c, d) {
  const grupos = d.grupos.filter((g) => g.categoria === c.categoria).sort((a, b) => b.bytes - a.bytes);
  if (!grupos.length) return null;
  return elemento("section", { class: "bloco", "data-categoria": c.categoria }, [
    elemento("header", {}, [elemento("h2", { texto: CATEGORIA_ESPACO[c.categoria].nome }),
      elemento("span", { class: "numero", texto: tamanhoEmTexto(c.bytes) })]),
    elemento("ul", { class: "linhas" }, grupos.map((g) => linhaDoEspaco(g, d.total))),
  ]);
}

function paginaEspaco() {
  if (!ESP.pedindo && Date.now() - ESP.quando > 3000) carregarEspaco();
  const d = ESP.dados;
  const abas = abasDeExtensoes("espaco");
  if (!d) {
    return [abas, elemento("h1", { class: "sr", texto: "Espaço" }),
      elemento("div", { class: "espaco" }, [1, 2].map(() => elemento("span", { class: "esqueleto", style: "height: 120px" })))];
  }
  if (d.erro) {
    return [abas, elemento("div", { class: "vazio" }, [icone("alerta"), elemento("p", { texto: d.erro })])];
  }
  return [abas, elemento("h1", { class: "sr", texto: "Espaço" }),
    elemento("div", { class: "espaco" }, [cabecaDoEspaco(d),
      ...d.categorias.map((c) => blocoDeCategoria(c, d))].filter(Boolean))];
}

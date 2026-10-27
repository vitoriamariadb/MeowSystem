(function () {
  "use strict";

  const cofre = document.getElementById("meow-dados");
  if (!cofre) return;
  const D = JSON.parse(cofre.textContent);
  const IMG = D.imagens || {};

  const VAZADO =
    "data:image/svg+xml;charset=utf-8," +
    encodeURIComponent(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">' +
        '<rect x="1" y="1" width="46" height="46" rx="6" fill="none" ' +
        'stroke="currentColor" stroke-opacity=".3" stroke-dasharray="4 3"/></svg>');

  const SEM_SERVIDOR = {
    erro: "Esta é a página exportada: não há servidor por trás dela. " +
          "Nada aqui grava, roda ou apaga nada — os valores são uma fotografia.",
    standalone: true,
  };

  const resposta = (corpo, status) =>
    Promise.resolve(new Response(JSON.stringify(corpo), {
      status: status || 200,
      headers: { "Content-Type": "application/json; charset=utf-8" },
    }));

  window.fetch = function (rota, opcoes) {
    const alvo = String(rota && rota.url ? rota.url : rota);
    const [caminho, busca] = alvo.split("?");
    const q = new URLSearchParams(busca || "");

    if (caminho === "/api/esquema") return resposta(D.esquema);
    if (caminho === "/api/apps") return resposta(D.apps);
    if (caminho === "/api/jogos") return resposta(D.jogos);
    if (caminho === "/api/glifos")
      return resposta({ termo: q.get("termo") || "", itens: [], congelado: true });
    if (caminho === "/api/previas") {
      const tipo = q.get("tipo") || "";
      const grupo = q.get("grupo") || "";
      const p = D.previas[grupo ? tipo + "/" + grupo : tipo];
      return resposta(p || { tipo, itens: [], faltam: 0, contagens: {}, total: 0 });
    }
    return resposta(SEM_SERVIDOR, 409);
  };

  window.EventSource = function () {
    return { close() {}, addEventListener() {}, onerror: null, onmessage: null };
  };

  const original = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function (nome, valor) {
    if (nome === "src" && typeof valor === "string" && valor[0] === "/") {
      valor = IMG[valor] || VAZADO;
    }
    return original.call(this, nome, valor);
  };
  document.querySelectorAll('img[src^="/"]').forEach((img) => {
    img.setAttribute("src", img.getAttribute("src"));
  });

  function montarBarra() {
    const barra = document.createElement("div");
    barra.className = "aviso-standalone";
    barra.dataset.mw = "aviso-standalone";
    barra.innerHTML =
      '<strong>Página exportada do MeowSystem</strong>' +
      '<span>Fotografia de ' + D.exportado_em + ". " +
      "Nada aqui grava, roda ou apaga nada. " + D.amostra.imagens +
      " imagens são amostra do acervo; o resto aparece como quadro vazado. " +
      "Para redesenhar: mexa no <code>&lt;style id=\"folha-do-painel\"&gt;</code> " +
      "e preserve os nomes de classe.</span>";

    const botao = document.createElement("button");
    botao.type = "button";
    botao.className = "btn btn-accent";
    botao.dataset.mw = "botao-empilhar";
    botao.textContent = "Ver todas as abas";
    let empilhado = false;
    botao.addEventListener("click", async () => {
      empilhado = !empilhado;
      botao.textContent = empilhado ? "Ver uma aba por vez" : "Ver todas as abas";
      document.body.classList.toggle("empilhado", empilhado);
      if (empilhado) await empilhar();
    });
    barra.append(botao);
    document.body.insertBefore(barra, document.body.firstChild);
  }

  async function empilhar() {
    const pilha = document.getElementById("pilha") || document.createElement("div");
    pilha.id = "pilha";
    pilha.dataset.mw = "pilha";
    pilha.replaceChildren();
    const antes = location.hash;
    const rotas = [["#tema", "Tema"],
      ...PASSOS.map((p) => ["#criar/" + p.id, "Personalizar · " + p.nome]),
      ...AJUSTES.map((p) => ["#ajustes/" + p.id, "Ajustes · " + p.nome]),
      ["#cuidar", "Cuidar"]];
    for (const [hash, nome] of rotas) {
      location.hash = hash;
      await new Promise((r) => setTimeout(r, 60));
      const secao = document.createElement("section");
      secao.className = "pilha-aba";
      secao.dataset.mw = "pilha-aba";
      const titulo = document.createElement("h2");
      titulo.textContent = nome;
      titulo.dataset.mw = "pilha-aba-titulo";
      const copia = document.getElementById("conteudo").cloneNode(true);
      copia.removeAttribute("id");
      copia.dataset.mw = "conteudo-copiado";
      secao.append(titulo, copia);
      pilha.append(secao);
    }
    document.getElementById("principal").append(pilha);
    location.hash = antes || "#tema";
  }

  const espia = new MutationObserver(() => {
    if (document.querySelector("#portas a")) {
      espia.disconnect();
      montarBarra();
    }
  });
  espia.observe(document.documentElement, { childList: true, subtree: true });
})();

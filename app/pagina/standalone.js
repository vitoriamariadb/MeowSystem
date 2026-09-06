/* app/pagina/standalone.js — o que faz a página exportada funcionar sem servidor.
 *
 * ESTE ARQUIVO SÓ EXISTE DENTRO DO HTML EXPORTADO. Ele nunca é servido ao
 * painel de verdade: o `servidor.py` o costura entre o `<script id="meow-dados">`
 * e o `app.js`, e é lido pelo `_exportar_pagina`.
 *
 * A IDEIA INTEIRA EM UMA FRASE
 *   O `app.js` que roda aqui é o MESMO arquivo do painel, sem uma linha
 *   diferente. Quem mente para ele são as trinta linhas abaixo: o `fetch` passa
 *   a ler o JSON embutido, o `src` das imagens passa a apontar para os `data:`
 *   da amostra, e o `EventSource` do pulso vira um objeto que não faz nada.
 *
 *   A alternativa seria escrever uma segunda versão da página só para exportar.
 *   Seria a terceira cópia da mesma tela neste projeto (a primeira foi a lista
 *   de chaves escrita à mão que o cabeçalho do `servidor.py` conta), e ela
 *   envelheceria na primeira semana: um cartão novo no painel não apareceria
 *   aqui, e ninguém notaria até alguém redesenhar a tela errada.
 *
 * O QUE ELE RECUSA A FINGIR
 *   Sem servidor não há o que gravar, rodar ou apagar. Toda rota que escreve
 *   devolve um erro com todas as letras em vez de responder "ok" — uma página
 *   de demonstração que finge ter salvo é pior que uma que diz que não salva.
 */
(function () {
  "use strict";

  const cofre = document.getElementById("meow-dados");
  if (!cofre) return;
  const D = JSON.parse(cofre.textContent);
  const IMG = D.imagens || {};

  /* O quadro vazado que aparece onde a imagem não coube na amostra. Ele usa
   * `currentColor`, então acompanha o tema da página em vez de cravar um cinza
   * — a regra do "nenhum hex vive dentro de script" vale aqui também. */
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

  /* --- o fetch que lê de dentro do arquivo ---------------------------------
   * O `api()` do `app.js` (linha 38) faz `fetch(rota)` e lê `resposta.text()`.
   * Devolver um `Response` de verdade — e não um objeto parecido — é o que faz
   * o `resposta.status`, o `resposta.ok` e o `await resposta.text()` de lá
   * continuarem valendo sem uma linha de exceção para o modo exportado. */
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
    /* Os glifos são a busca por desenho de ícone: ela pede ao servidor a cada
     * letra digitada, e congelar isso seria congelar um acervo de milhares. A
     * lista vazia é a resposta honesta, e a tela de escolha sabe desenhá-la. */
    if (caminho === "/api/glifos")
      return resposta({ termo: q.get("termo") || "", itens: [], congelado: true });
    if (caminho === "/api/previas") {
      const tipo = q.get("tipo") || "";
      const grupo = q.get("grupo") || "";
      const p = D.previas[grupo ? tipo + "/" + grupo : tipo];
      return resposta(p || { tipo, itens: [], faltam: 0, contagens: {}, total: 0 });
    }
    /* 409, e não 200 com erro: é o mesmo código que o servidor usa para "não
     * vou fazer isso agora", e o `api()` do painel já sabe traduzi-lo. */
    return resposta(SEM_SERVIDOR, 409);
  };

  /* O pulso é a conexão que diz "a janela está aberta". Sem servidor ele não
   * tem com quem falar, e um `EventSource` para um endereço morto enche o
   * console de vermelho a cada reconexão. */
  window.EventSource = function () {
    return { close() {}, addEventListener() {}, onerror: null, onmessage: null };
  };

  /* --- as imagens ----------------------------------------------------------
   * O `elemento()` do `app.js` (linha 268) põe o `src` por `setAttribute`, e é
   * por isso que interceptar aqui cobre TODAS as imagens da página — as da
   * galeria, as dos ícones, as das capas e o gato do cabeçalho — sem que o
   * `app.js` precise saber que está exportado. */
  const original = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function (nome, valor) {
    if (nome === "src" && typeof valor === "string" && valor[0] === "/") {
      valor = IMG[valor] || VAZADO;
    }
    return original.call(this, nome, valor);
  };
  /* O `<img class="gato">` do cabeçalho nasce no HTML, antes deste script — o
   * interceptador acima não o alcança. */
  document.querySelectorAll('img[src^="/"]').forEach((img) => {
    img.setAttribute("src", img.getAttribute("src"));
  });

  /* --- a barra de instruções, e o modo "todas as abas" ---------------------
   * Quem abre este arquivo não abriu o painel: abriu um anexo. A barra diz o
   * que ele é, quando foi tirado, e oferece a única coisa que o painel de
   * verdade não tem — ver as vinte e quatro abas empilhadas, que é como se
   * julga um layout inteiro sem clicar vinte e quatro vezes. */
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

  /* EMPILHAR É CLICAR NO MENU, e não chamar o `render()` por dentro.
   *   O `render()` é função de módulo do `app.js`; alcançá-la daqui prenderia
   *   este arquivo ao nome dela. Clicar no botão do trilho é a mesma coisa
   *   pela porta da frente: o `onclick` de lá troca a aba, redesenha e ainda
   *   limpa a busca. O que se copia depois é o resultado. */
  async function empilhar() {
    const pilha = document.getElementById("pilha") || document.createElement("div");
    pilha.id = "pilha";
    pilha.dataset.mw = "pilha";
    pilha.replaceChildren();
    const antes = document.querySelector('#trilho [aria-current="true"]');
    for (const b of document.querySelectorAll("#trilho button")) {
      b.click();
      await new Promise((r) => setTimeout(r, 40));
      const secao = document.createElement("section");
      secao.className = "pilha-aba";
      secao.dataset.mw = "pilha-aba";
      const titulo = document.createElement("h2");
      titulo.textContent = b.querySelector("span").textContent;
      titulo.dataset.mw = "pilha-aba-titulo";
      /* O `id` SAI DO CLONE, e isto não é limpeza — é o defeito que a primeira
       * versão teve. `cloneNode` copia o `id="conteudo"`, e a regra que esconde
       * o conteúdo no modo empilhado (`body.empilhado #conteudo`) passava a
       * valer para os vinte e quatro clones também: a pilha montava certo, com
       * os 96 cartões dentro, e aparecia vazia na tela. */
      const copia = document.getElementById("conteudo").cloneNode(true);
      copia.removeAttribute("id");
      copia.dataset.mw = "conteudo-copiado";
      secao.append(titulo, copia);
      pilha.append(secao);
    }
    document.getElementById("principal").append(pilha);
    if (antes) antes.click();
  }

  /* O `iniciar()` do `app.js` é assíncrono e monta o trilho só depois de
   * "buscar" o esquema. Esperar o primeiro botão nascer é mais barato — e mais
   * honesto — que adivinhar um tempo. */
  const espia = new MutationObserver(() => {
    if (document.querySelector("#trilho button")) {
      espia.disconnect();
      montarBarra();
    }
  });
  espia.observe(document.documentElement, { childList: true, subtree: true });
})();

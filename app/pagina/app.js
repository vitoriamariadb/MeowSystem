/* app/pagina/app.js — monta a página a partir do que o servidor derivou.
 *
 * NÃO HÁ UM NOME DE CHAVE NESTE ARQUIVO, e isso é o ponto inteiro. O `servidor.py`
 * lê o `meow.conf.exemplo` e devolve, para cada chave, o que ela é (opções,
 * faixa, horário, lista), o que o exemplo traz de fábrica, o que o meow.conf
 * dela diz hoje e o comentário que explica a decisão. Aqui só se decide qual
 * CONTROLE cada forma dessas merece. Chave nova no exemplo aparece sozinha.
 *
 * O QUE ACONTECE QUANDO ELA MEXE NUM CONTROLE
 *   A escrita é imediata — vai para o `meow.conf` pelo `meow_conf_definir`, e a
 *   página diz qual dos três aconteceu: "gravado", "já estava assim" (o código 0
 *   do projeto, que é uma resposta e não um silêncio) ou o erro.
 *
 *   Ela NÃO aplica na tela. Escrever a chave e aplicar o tema são coisas
 *   diferentes neste projeto desde sempre (é o que `meow configurar` faz, e o que
 *   o `meow.conf` diz na primeira linha: "Editou uma linha? Rode: meow aplicar").
 *   Fingir que um clique no `FLAVOR` repinta o COSMIC seria mentir — a etapa de
 *   tema copia árvore de arquivo e o painel precisa reciclar. Então a página
 *   acende um aviso contando quantas chaves esperam, com o botão que as aplica.
 */
"use strict";

/* --- o token, e o primeiro cuidado com ele -------------------------------- */
const TOKEN = document.body.dataset.token;
/* Fora da barra de endereço no primeiro instante: um token no histórico do
 * navegador sobrevive à sessão que o criou, e este não deve. */
if (location.search) {
  /* `+ location.hash` NÃO é detalhe: sem ele, esta linha — que roda antes de
   * tudo — levava o hash junto com o token, e abrir a página numa seção
   * específica nunca funcionava. O sintoma era mudo: a URL com `#galeria…`
   * abria em "Aparência" como se o hash não existisse. Pego ao testar a rota
   * por hash em 01/09/2026, na primeira captura. */
  history.replaceState(null, "", location.pathname + location.hash);
}

const $ = (sel, raiz = document) => raiz.querySelector(sel);

async function api(rota, opcoes = {}) {
  const resposta = await fetch(rota, {
    ...opcoes,
    headers: { "X-Meow-Token": TOKEN, "Content-Type": "application/json", ...(opcoes.headers || {}) },
  });
  const texto = await resposta.text();
  let dados;
  try { dados = JSON.parse(texto); } catch { dados = { erro: texto }; }
  /* O 409 TEM NOME, e ele importa mais que o número: o servidor recusa um
   * segundo trabalho enquanto o primeiro corre (um `install.sh` e um `doctor`
   * ao mesmo tempo brigariam pelo mesmo lock). Sem esta tradução, clicar em
   * "Conferir" com uma ação rodando deixava só um "Failed to load resource:
   * 409" no console e NADA na tela — visto no teste de navegador de
   * 01/09/2026. Agora a página diz o que aconteceu, na língua dela. */
  if (resposta.status === 409 && !dados.erro) {
    dados.erro = "Já há um trabalho rodando. Espere ele terminar (ou pare-o na gaveta).";
  }
  if (!resposta.ok && !dados.erro) dados.erro = "HTTP " + resposta.status;
  return dados;
}

/* --- estado --------------------------------------------------------------- */
let ESQUEMA = null;          // o que veio de /api/esquema
let GRUPOS = [];             // [{nome, chaves:[...]}] + as abas de ação e folhas
let ABA = null;              // qual grupo está aberto

/* --- A ABA MORA NA URL ------------------------------------------------------
 * Sem isto, `F5` devolvia ela para a primeira aba, e não havia como mandar a si
 * mesma (ou a mim) o endereço de uma seção — numa página de 95 chaves em
 * dezoito grupos, "abre a galeria" virava instrução de três passos.
 *
 * O identificador é o nome do grupo achatado (sem acento, sem espaço), e não um
 * índice: índice muda quando um grupo nasce no meio, e o link guardado
 * apontaria para outra coisa sem avisar.
 *
 * O `?t=` da URL continua saindo da barra de endereço no primeiro instante — o
 * hash é acrescentado DEPOIS disso, com `replaceState`, então o token nunca
 * volta para lá. */
function idDeAba(nome) {
  return semAcento(String(nome)).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

function abaDoHash() {
  const id = decodeURIComponent(location.hash.replace(/^#/, ""));
  if (!id) return null;
  const g = GRUPOS.find((x) => idDeAba(x.nome) === id);
  return g ? g.nome : null;
}

function gravarHash() {
  if (!ABA) return;
  const novo = "#" + idDeAba(ABA);
  if (location.hash !== novo) history.replaceState(null, "", novo);
}
let PENDENTES = new Set();   // chaves gravadas desde o último "aplicar"
/* Os grupos que têm ao menos uma chave com prévia. É o que decide onde vale
 * dizer "esta não tem prévia" — derivado do esquema, nunca uma lista escrita. */
let GRUPOS_VISUAIS = new Set();
/* O grupo onde mora a grade de ícones do tema instalado: é o que contém a chave
 * do NOME do tema. Derivado também — se aquela chave mudar de seção, a grade a
 * acompanha sem ninguém vir aqui. */
let GRUPO_ICONES = null;
let TRABALHO = null;         // {id, proximo, timer}

/* --- utilidades de texto -------------------------------------------------- */
/* "A NOITE DA MÁQUINA, EM UM LUGAR SÓ" -> "A noite da máquina, em um lugar só".
 * O meow.conf.exemplo grita os títulos de bloco, e isso é certo num arquivo de
 * texto lido no editor. Numa lista de navegação, quinze itens em caixa alta são
 * quinze itens que a vista não distingue — e caixa alta ainda é o que leitor de
 * tela soletra letra a letra em alguns modos. O texto original vira o `title`. */
/* ===========================================================================
 * COMO A PÁGINA ESCREVE — 01/09/2026
 * ===========================================================================
 * Duas regras dela, no mesmo dia:
 *   "acentuação e primeira letra sempre maiúscula"
 *   "temos que ter menos palavras na interface como um todo"
 *
 * O conflito aparente entre as duas se resolve assim: o que a página ESCREVE
 * por conta própria é curto e bem escrito; o que ela MOSTRA do meow.conf é
 * literal, porque é o valor que vai para o arquivo. `sim` continua sendo `sim`
 * no disco — a tela é que diz "Sim".
 */
const ROTULO_DE_VALOR = {
  sim: "Sim", nao: "Não", auto: "Auto", escuro: "Escuro", claro: "Claro",
  aleatoria: "Aleatória", alfabetica: "Alfabética", silencioso: "Silencioso",
  info: "Info", debug: "Debug", traco: "Traço", chapado: "Chapado",
  espelho: "Espelho", hora: "Hora", rotacao: "Rotação", fixo: "Fixo",
  nitida: "Nítida", preencher: "Preencher", caber: "Caber", esticar: "Esticar",
  mocha: "Mocha", macchiato: "Macchiato", frappe: "Frappé", latte: "Latte",
  coquinha: "Coquinha", mimir: "Mimir",
};

/** O rótulo VISÍVEL de um valor do conf. O valor gravado nunca muda. */
function rotuloDeValor(v) {
  if (v === "" || v == null) return "vazio";
  return ROTULO_DE_VALOR[v] || v;
}

/** Primeira letra maiúscula, o resto intacto (nomes próprios sobrevivem). */
function maiuscula(txt) {
  if (!txt) return txt;
  return txt.charAt(0).toLocaleUpperCase("pt-BR") + txt.slice(1);
}

/** O título curto de um cartão: a primeira oração da explicação, sem ponto.
 *  Não inventa texto — só corta o que já está escrito no meow.conf.exemplo. */
function tituloDoCartao(item) {
  const frase = (item.frase || "").trim();
  if (!frase) return null;
  /* Primeira oração, e dentro dela o primeiro aparte. "O auto-reparo é UM timer
   * do systemd --user, diário, e mais nada" vira "O auto-reparo é um timer do
   * systemd" — o resto está a um clique no "Por quê". */
  let corte = frase.split(/(?<=[.!?])\s/)[0].replace(/[.]$/, "");
  if (corte.length > 52) corte = corte.split(/\s*[,;—]/)[0];
  if (corte.length > 64) {
    const palavras = corte.split(/\s+/).slice(0, 9);
    corte = palavras.join(" ").replace(
      /\s+(de|do|da|dos|das|e|o|a|os|as|em|no|na|por|com|que|para)$/i, "");
  }
  return maiuscula(destacarSemGritar(corte));
}

/* O `meow.conf.exemplo` usa CAIXA ALTA como ênfase — funciona num arquivo de
 * texto e vira grito numa tela cheia de cartões ("O gato solto em assets/gatos/
 * entra NA HORA"). Aqui a ênfase volta ao normal, mas SÓ em palavras de quatro
 * letras ou mais: `SVG`, `RON`, `GUI`, `USB` e `UM` são siglas ou palavras
 * curtas onde a caixa é a grafia, não o tom de voz. */
const FUNCIONAIS_GRITADAS = new Set([
  "UM", "UMA", "NA", "NO", "NAS", "NOS", "EM", "DE", "DO", "DA", "DOS", "DAS",
  "E", "OU", "SE", "JÁ", "SÓ", "AO", "AOS", "À", "ÀS", "COM", "SEM", "POR",
  "QUE", "NÃO", "SIM", "TEM", "É", "SER", "VAI", "ELA", "ELE", "ISSO", "ESTE",
]);

function destacarSemGritar(txt) {
  /* Duas regras, e a segunda existe porque a primeira sozinha produziu
   * "entra NA Hora" — feio de um jeito novo:
   *   · palavra de quatro letras ou mais em caixa alta é ênfase -> minúscula;
   *   · palavra funcional curta em caixa alta (UM, NA, DE…) também é ênfase.
   * O que sobra em caixa alta é o que de fato é sigla: SVG, RON, GUI, USB. */
  return txt.replace(/\b[\p{Lu}ÁÉÍÓÚÂÊÔÃÕÇ]{1,}\b/gu, (p) => {
    const letras = p.replace(/[^\p{L}]/gu, "");
    if (letras.length >= 4 || FUNCIONAIS_GRITADAS.has(p))
      return p.toLocaleLowerCase("pt-BR");
    return p;
  });
}

/* MENOS PALAVRAS NO MENU E NOS TÍTULOS — 01/09/2026.
 * "tem muita mas muita palavra que ta poluindo desde menu ao titulo de secoes"
 *
 * Os títulos dos blocos do `meow.conf.exemplo` foram escritos para um ARQUIVO,
 * onde uma frase inteira ajuda: "A NOITE DA MÁQUINA, EM UM LUGAR SÓ", "O MODO
 * DE LEITURA, E O RELÓGIO QUE O LIGA SOZINHO". Num menu de vinte linhas, cada
 * uma dessas é uma frase que ela tem de LER para descobrir que não é a que
 * procura — e a metade que importa está sempre no começo.
 *
 * Então o rótulo curto é o começo da frase, cortado no primeiro sinal que
 * introduz um aparte (vírgula, dois-pontos, travessão, parêntese). Nada é
 * inventado e nada é traduzido: o nome inteiro continua no `title` e na busca.
 * Se mesmo assim passar de seis palavras, corta em seis. */
function encurtar(txt) {
  if (!txt) return txt;
  let curto = humanizar(txt).split(/\s*[,:—(]/)[0].trim();
  const palavras = curto.split(/\s+/);
  if (palavras.length > 7) curto = palavras.slice(0, 7).join(" ");
  /* Cortar por contagem deixava rótulo terminando em preposição — "A forma do
   * painel e do", visto na primeira tentativa. Uma palavra de ligação no fim é
   * pior que o texto longo: parece defeito, não resumo. */
  curto = curto.replace(/\s+(de|do|da|dos|das|e|o|a|os|as|em|no|na|por|com|que|para)$/i, "");
  return curto;
}

function humanizar(txt) {
  if (!txt) return txt;
  /* O parêntese sai antes da conta, pelo mesmo motivo que no `servidor.py`: em
   * `AS JANELAS LADO A LADO (o "fibonacci")` o aparte minúsculo derruba a
   * proporção para 0,65 e o título escapava da conversão. Visto na tela em
   * 01/09/2026 — era o único item do trilho ainda gritando. O parêntese neste
   * arquivo é sempre um aparte em voz baixa. */
  const limpo = txt.replace(/\([^)]*\)/g, "");
  const letras = [...limpo].filter((c) => /\p{L}/u.test(c));
  const gritado = letras.length && letras.filter((c) => c === c.toUpperCase()).length / letras.length > 0.7;
  if (!gritado) return txt;
  const baixo = txt.toLocaleLowerCase("pt-BR");
  return baixo.charAt(0).toLocaleUpperCase("pt-BR") + baixo.slice(1);
}

function elemento(tag, props = {}, filhos = []) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (k === "class") el.className = v;
    else if (k === "texto") el.textContent = v;
    else if (k === "html") el.innerHTML = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (v === true) el.setAttribute(k, "");
    else if (v !== false && v != null) el.setAttribute(k, v);
  }
  for (const f of [].concat(filhos)) if (f) el.append(f);
  return el;
}

function torrada(texto, classe = "") {
  const el = elemento("div", { class: "torrada " + classe, texto });
  $("#torradas").append(el);
  setTimeout(() => el.remove(), classe === "erro" ? 7000 : 2600);
}

/* ===========================================================================
 * AS ESCOLHAS FICAM NA MÃO DELA ATÉ ELA SALVAR — 01/09/2026
 * ===========================================================================
 * Pedido dela, e é uma mudança de modelo, não um botão a mais: "mesmo mudando
 * aba a aba ele precisa se lembrar das escolhas e apertar em salvar já faz o
 * trabalho de instalar e lembrar das escolhas".
 *
 * A primeira versão gravava no `meow.conf` A CADA CLIQUE. Três problemas, e o
 * terceiro é o que ela sentiu:
 *   1. escolher é experimentar — clicar em `latte` para ver a paleta não
 *      deveria reescrever o arquivo dela;
 *   2. o arquivo ficava num meio-termo que a tela não mostrava, porque gravar
 *      não é aplicar (é o `install.sh` que aplica);
 *   3. não havia UM momento em que ela dissesse "é isto" — e sem esse momento,
 *      não há nada para lembrar.
 *
 * Agora: clicar guarda em `MUDANCAS`, que vive fora do render e por isso
 * atravessa a troca de aba, a busca e o recarregamento da grade. O cartão fica
 * marcado como não-salvo, o cabeçalho conta quantas esperam. `Salvar` grava
 * todas de uma vez e, em seguida, RODA O INSTALADOR — que é o que faz a
 * escolha virar pixel na tela. `Descartar` devolve tudo ao que está no disco.
 *
 * O modo seco continua valendo: com ele ligado, `Salvar` mostra o que faria
 * sem escrever nada. */
const MUDANCAS = new Map();   // chave -> valor escolhido e ainda não salvo

function valorEmVigor(item) {
  return MUDANCAS.has(item.chave) ? MUDANCAS.get(item.chave) : (item.valor ?? "");
}

function escolher(chave, valor, cartao) {
  const item = ESQUEMA.chaves.find((i) => i.chave === chave);
  if (!item) return;
  const noDisco = item.valor ?? "";
  if (valor === noDisco) MUDANCAS.delete(chave);
  else MUDANCAS.set(chave, valor);
  if (cartao) {
    cartao.classList.toggle("nao-salvo", MUDANCAS.has(chave));
    cartao.classList.toggle("mexeu", valor !== item.padrao);
  }
  atualizarBarraSalvar();
  render();
}

function atualizarBarraSalvar() {
  const barra = $("#barra-salvar");
  const n = MUDANCAS.size;
  barra.hidden = n === 0;
  if (!n) return;
  $("#salvar-conta").textContent =
    n === 1 ? "1 escolha esperando" : `${n} escolhas esperando`;
  $("#salvar-lista").textContent = [...MUDANCAS.keys()].join(" · ");
}

async function descartarEscolhas() {
  MUDANCAS.clear();
  atualizarBarraSalvar();
  render();
  torrada("Escolhas descartadas — o meow.conf não foi tocado", "igual");
}

/* SALVAR = GRAVAR + APLICAR, nessa ordem e sem meio-termo.
 * Se uma gravação falhar, o instalador NÃO roda: aplicar metade das escolhas
 * dela seria pior que não aplicar nenhuma, e o erro fica na tela dizendo qual
 * chave recusou. */
async function salvarEscolhas() {
  if (!MUDANCAS.size) return;
  const seco = $("#seco").checked;
  const botao = $("#botao-salvar");
  botao.disabled = true;
  const anterior = botao.textContent;
  botao.textContent = "Salvando…";

  const falhou = [];
  for (const [chave, valor] of MUDANCAS) {
    const ok = await gravar(chave, valor, null);
    if (!ok) falhou.push(chave);
  }
  botao.disabled = false;
  botao.textContent = anterior;

  if (falhou.length) {
    torrada(`Não consegui gravar: ${falhou.join(", ")} — o instalador não rodou`, "erro");
    return;
  }
  if (seco) {
    MUDANCAS.clear();
    atualizarBarraSalvar();
    render();
    torrada("Modo seco: nada foi escrito e o instalador não rodou", "igual");
    return;
  }
  MUDANCAS.clear();
  atualizarBarraSalvar();
  render();
  torrada("Escolhas gravadas no meow.conf. Aplicando…", "ok");
  await rodarAcao("instalar");
}

/* Roda uma acao pelo id — o `Salvar` precisa disparar o instalador sem que
 * exista um cartao clicado para ele. */
async function rodarAcao(id, argumento) {
  const acao = (ESQUEMA.acoes || []).find((a) => a.id === id);
  if (!acao) { torrada(`Ação desconhecida: ${id}`, "erro"); return; }
  return rodar(acao, argumento);
}

/* --- escrita de chave ------------------------------------------------------ */
async function gravar(chave, valor, cartao) {
  const seco = $("#seco").checked;
  const r = await api("/api/definir", {
    method: "POST",
    body: JSON.stringify({ chave, valor, seco }),
  });
  if (r.erro || r.rc === 2) {
    torrada(`${chave}: ${r.erro || r.saida || "não consegui gravar"}`, "erro");
    return false;
  }
  /* Os três códigos do projeto, ditos com as palavras do projeto. O `0` não é
   * "nada aconteceu": é "já estava certo", que é a resposta que a idempotência
   * deste repositório existe para poder dar. */
  if (seco) {
    torrada(`${chave}: em seco — nada foi escrito`, "igual");
  } else if (r.rc === 0) {
    torrada(`${chave} já estava assim`, "igual");
  } else {
    torrada(`${chave} = ${valor || "(vazio)"}`, "ok");
    PENDENTES.add(chave);
    atualizarAviso();
  }
  const item = ESQUEMA.chaves.find((i) => i.chave === chave);
  if (item && !seco) {
    item.valor = valor;
    if (cartao) cartao.classList.toggle("mexeu", valor !== item.padrao);
  }
  return true;
}

function atualizarAviso() {
  const aviso = $("#aviso-aplicar");
  const n = PENDENTES.size;
  if (!n) { aviso.hidden = true; return; }
  aviso.hidden = false;
  $("#aviso-texto").textContent =
    n === 1
      ? "1 chave foi gravada no meow.conf e ainda não valeu na tela."
      : `${n} chaves foram gravadas no meow.conf e ainda não valeram na tela.`;
}

/* --- os controles, um por forma de chave ---------------------------------- */
/* A ordem dos testes é a ordem da especificidade, e ela importa: uma chave de
 * horário TAMBÉM é texto, e uma de lista TAMBÉM tem opções às vezes. */
function montarControle(item, cartao) {
  /* `valorEmVigor` e nao `item.valor`: o que o controle mostra e a escolha dela
   * ainda nao salva, quando existe. Sem isso, trocar de aba e voltar apagaria
   * da tela o que ela acabou de escolher. */
  const valor = valorEmVigor(item);
  const aplica = (v) => escolher(item.chave, v, cartao);

  /* 0. A PRÉVIA VEM PRIMEIRO, quando existe — porque quando a opção PODE ser
   *    uma imagem, ela deve ser a imagem, e não um botão com o nome dela ao
   *    lado de uma imagem. Um botão escrito "coquinha" obriga a lembrar qual é
   *    a coquinha; um botão que MOSTRA a coquinha, não. Quem decidiu que esta
   *    chave merece prévia foi o servidor, olhando o conteúdo dela. */
  if (item.previa === "gato" || item.previa === "cursor") {
    const c = controleImagem(item, item.previa, aplica);
    if (c) return c;
  }
  if (item.previa === "flavor") return controleFlavor(item, aplica);
  if (item.previa === "cor") return controleCor(item, aplica);

  /* 1. lista separada por vírgula -> fichas */
  if (item.lista || item.lista_pathsep) {
    const sep = item.lista_pathsep ? ":" : ",";
    const caixa = elemento("div", { class: "fichas" });
    const desenhar = () => {
      caixa.replaceChildren();
      const itens = (item.valor || "").split(sep).map((s) => s.trim()).filter(Boolean);
      for (const nome of itens) {
        caixa.append(elemento("span", { class: "ficha" }, [
          elemento("span", { texto: nome }),
          elemento("button", {
            type: "button", "aria-label": `Tirar ${nome}`, texto: "×",
            onclick: async () => {
              const novos = itens.filter((x) => x !== nome);
              if (await aplica(novos.join(sep))) { item.valor = novos.join(sep); desenhar(); }
            },
          }),
        ]));
      }
      const entrada = elemento("input", {
        type: "text", class: "nova", placeholder: "+ acrescentar",
        "aria-label": `Acrescentar item a ${item.chave}`,
      });
      entrada.addEventListener("keydown", async (ev) => {
        if (ev.key !== "Enter" || !entrada.value.trim()) return;
        ev.preventDefault();
        const novo = entrada.value.trim();
        if (itens.includes(novo)) { torrada(`${novo} já está na lista`, "igual"); return; }
        const novos = [...itens, novo];
        if (await aplica(novos.join(sep))) { item.valor = novos.join(sep); desenhar(); }
      });
      caixa.append(entrada);
    };
    desenhar();
    return caixa;
  }

  /* 2. horário -> <input type="time">, que já traz o teclado e a validação */
  if (item.horario) {
    const caixa = elemento("div", { class: "controle" });
    const campo = elemento("input", {
      type: "time", value: valor, "aria-label": item.chave,
    });
    campo.addEventListener("change", () => aplica(campo.value));
    caixa.append(campo);
    if (item.aceita_vazio) caixa.append(botaoVazio(item, () => { campo.value = ""; }, aplica));
    return caixa;
  }

  /* 3. faixa numérica -> deslizante + número, os dois amarrados */
  if (item.faixa) {
    const [lo, hi, passo] = item.faixa;
    const caixa = elemento("div", { class: "faixa" });
    const slider = elemento("input", {
      type: "range", min: lo, max: hi, step: passo, value: valor || lo,
      "aria-label": item.chave,
    });
    const saida = elemento("output", { texto: String(valor || lo) });
    slider.addEventListener("input", () => { saida.textContent = slider.value; });
    slider.addEventListener("change", () => aplica(slider.value));
    caixa.append(slider, saida);
    return caixa;
  }

  /* 4. opções -> segmentos até 5, <select> acima disso */
  if (item.opcoes.length) {
    if (item.opcoes.length <= 5) {
      const caixa = elemento("div", { class: "segmentos" });
      const pintar = (v) => {
        for (const b of caixa.querySelectorAll("button")) {
          b.setAttribute("aria-pressed", String(b.dataset.valor === v));
        }
      };
      for (const opcao of item.opcoes) {
        caixa.append(elemento("button", {
          type: "button", "data-valor": opcao, texto: rotuloDeValor(opcao), "aria-pressed": "false",
          onclick: async () => { if (await aplica(opcao)) pintar(opcao); },
        }));
      }
      if (item.aceita_vazio) {
        caixa.append(elemento("button", {
          type: "button", class: "vazio", "data-valor": "", texto: "não mexer",
          "aria-pressed": "false",
          title: "Vazio no meow.conf = o MeowSystem não toca nesta chave; quem manda é você (ou a GUI do COSMIC).",
          onclick: async () => { if (await aplica("")) pintar(""); },
        }));
      }
      pintar(valor);
      return caixa;
    }
    const caixa = elemento("div", { class: "controle" });
    const sel = elemento("select", { "aria-label": item.chave });
    if (item.aceita_vazio) sel.append(elemento("option", { value: "", texto: "— não mexer —" }));
    for (const opcao of item.opcoes) sel.append(elemento("option", { value: opcao, texto: rotuloDeValor(opcao) }));
    sel.value = valor;
    sel.addEventListener("change", () => aplica(sel.value));
    caixa.append(sel);
    return caixa;
  }

  /* 5. o resto -> texto. Caminho longo ganha uma <textarea> para caber. */
  const caixa = elemento("div", { class: "controle" });
  const longo = valor.length > 46;
  const campo = elemento(longo ? "textarea" : "input", {
    type: longo ? false : "text",
    "aria-label": item.chave,
    placeholder: item.aceita_vazio ? "(vazio = não toca)" : item.padrao,
  });
  campo.value = valor;
  /* `change` e não `input`: gravar a cada tecla seriam dez escritas no meow.conf
   * para digitar "macchiato", e cada uma passa por `meow_escrever` com o arquivo
   * inteiro. O commit acontece ao sair do campo ou no Enter. */
  campo.addEventListener("change", () => aplica(campo.value));
  campo.addEventListener("keydown", (ev) => {
    if (ev.key === "Enter" && !longo) { ev.preventDefault(); campo.blur(); }
  });
  caixa.append(campo);
  return caixa;
}

function botaoVazio(item, limpar, aplica) {
  return elemento("button", {
    type: "button", class: "btn", texto: "não mexer",
    title: "Esvazia a chave: o MeowSystem deixa de tocar nela.",
    onclick: async () => { if (await aplica("")) limpar(); },
  });
}


/* ===========================================================================
 * AS PRÉVIAS
 *
 * O pedido dela, em 01/09/2026: "precisamos ter imagens disponíveis pra cada
 * feature. pra facilitar a escolha. afinal é um app de modificação visual. Sem
 * as imagens fica difícil."
 *
 * QUEM DECIDE QUE PRÉVIA CADA CHAVE GANHA É O SERVIDOR, e ele decide olhando o
 * CONTEÚDO da chave, não o nome (ver `_tipo_de_previa`, em servidor.py). Aqui só
 * se desenha o que aquele campo mandou. Foi assim que `MIDIA_COR_TITULO` ganhou
 * bolinhas de cor sem ninguém escrever o nome dela em lugar nenhum.
 * ======================================================================== */

/* O fundo de teste vale para a página inteira e é lembrado — é o mesmo gesto
 * das folhas visuais, onde quatro pílulas repintam todos os cartões de uma vez.
 * Os quatro são os fundos REAIS sobre os quais um ícone aparece nesta máquina;
 * quem os define é `/paleta.css`, a partir da paleta. */
const FUNDOS = [
  { id: "mocha", rotulo: "Mocha", varr: "--fundo-mocha" },
  { id: "vidro-escuro", rotulo: "Vidro escuro", varr: "--fundo-vidro-escuro" },
  { id: "vidro-claro", rotulo: "Vidro claro", varr: "--fundo-vidro-claro" },
  { id: "latte", rotulo: "Latte", varr: "--fundo-latte" },
];
let FUNDO = FUNDOS[0];

function aplicarFundo() {
  document.documentElement.style.setProperty("--fundo-teste", `var(${FUNDO.varr})`);
}

function barraDeFundos() {
  const caixa = elemento("div", { class: "fundos" }, [elemento("b", { texto: "Fundo" })]);
  for (const f of FUNDOS) {
    caixa.append(elemento("button", {
      type: "button", "aria-pressed": String(f.id === FUNDO.id),
      title: `Ver sobre ${f.rotulo}`,
      onclick: () => { FUNDO = f; aplicarFundo(); render(); },
    }, [
      elemento("i", { style: `background: var(${f.varr})` }),
      elemento("span", { texto: f.rotulo }),
    ]));
  }
  return caixa;
}

/* --- o cache de listas de prévia ------------------------------------------ */
/* Uma chamada por tipo, guardada aqui. Enquanto houver miniatura faltando, a
 * página volta a perguntar — é assim que o lugar-marcado vira imagem sem a tela
 * ter travado esperando o `convert`. */
const PREVIAS = new Map();
let RELOGIO_PREVIA = null;

async function carregarPrevias(tipo, grupo) {
  const chave = tipo + "/" + (grupo || "");
  const r = await api(`/api/previas?tipo=${encodeURIComponent(tipo)}`
                    + (grupo ? `&grupo=${encodeURIComponent(grupo)}` : ""));
  if (r.erro) return null;
  PREVIAS.set(chave, r);
  if (r.faltam > 0) agendarRecarga(tipo, grupo);
  return r;
}

function agendarRecarga(tipo, grupo) {
  if (RELOGIO_PREVIA) return;
  RELOGIO_PREVIA = setTimeout(async () => {
    RELOGIO_PREVIA = null;
    const antes = PREVIAS.get(tipo + "/" + (grupo || ""));
    const depois = await carregarPrevias(tipo, grupo);
    /* Só redesenha se algo de fato ficou pronto. Redesenhar a cada volta faria
     * a página piscar e perderia o foco de quem está no teclado. */
    if (depois && antes && depois.faltam !== antes.faltam) render();
  }, 900);
}

function previasDe(tipo, grupo) {
  const chave = tipo + "/" + (grupo || "");
  if (!PREVIAS.has(chave)) {
    PREVIAS.set(chave, null);
    carregarPrevias(tipo, grupo).then((r) => { if (r) render(); });
  }
  return PREVIAS.get(chave);
}

/* --- controles com imagem ------------------------------------------------- */
/* Gatos e cursores: a opção É o desenho. Um botão que diz "coquinha" obriga a
 * lembrar qual é a coquinha; um botão que mostra a coquinha, não. */
function controleImagem(item, tipo, aplica) {
  const lista = previasDe(tipo);
  if (!lista) return null;
  const porId = new Map(lista.itens.map((i) => [i.id, i]));
  const caixa = elemento("div", { class: "opcoes-imagem" });
  const opcoes = item.opcoes.length ? item.opcoes : lista.itens.map((i) => i.id);
  const pintar = (v) => {
    for (const b of caixa.querySelectorAll("button")) {
      b.setAttribute("aria-pressed", String(b.dataset.valor === v));
    }
  };
  for (const opcao of opcoes) {
    const p = porId.get(opcao);
    const botao = elemento("button", {
      type: "button", "data-valor": opcao, "aria-pressed": "false",
      title: p ? p.origem : opcao,
      onclick: async () => { if (await aplica(opcao)) pintar(opcao); },
    });
    if (p && p.pronta) {
      botao.append(elemento("img", { src: p.url, alt: "", loading: "lazy" }));
    } else {
      botao.append(elemento("div", { class: "lugar", style: "width:48px;height:48px;border-radius:6px" }));
    }
    botao.append(elemento("span", { texto: rotuloDeValor(opcao) }));
    caixa.append(botao);
  }
  pintar(item.valor ?? "");
  return caixa;
}

/* --- amostras de flavor --------------------------------------------------- */
/* A tira mostra o flavor pelo que ele é: fundo, superfície, texto e os quatro
 * acentos. "macchiato" não diz nada; a tira diz. */
const CORES_DA_TIRA = ["base", "surface0", "surface2", "text", "mauve", "blue", "green", "peach"];

function controleFlavor(item, aplica) {
  const flavors = ESQUEMA.paleta.flavors || {};
  const caixa = elemento("div", { class: "amostras" });
  const pintar = (v) => {
    for (const b of caixa.querySelectorAll("button")) {
      b.setAttribute("aria-pressed", String(b.dataset.valor === v));
    }
  };
  for (const nome of item.opcoes) {
    const cores = flavors[nome];
    if (!cores) continue;
    const tira = elemento("div", { class: "tira" });
    for (const c of CORES_DA_TIRA) {
      if (cores[c]) tira.append(elemento("span", { style: `background:${cores[c]}` }));
    }
    caixa.append(elemento("button", {
      type: "button", "data-valor": nome, "aria-pressed": "false",
      onclick: async () => { if (await aplica(nome)) pintar(nome); },
    }, [elemento("span", { class: "nome", texto: nome }), tira]));
  }
  pintar(item.valor ?? "");
  return caixa;
}

/* --- bolinhas de cor ------------------------------------------------------ */
function controleCor(item, aplica) {
  const flavor = (ESQUEMA.chaves.find((k) => k.chave === "FLAVOR") || {}).valor || "mocha";
  const cores = (ESQUEMA.paleta.flavors || {})[flavor] || {};
  /* As opções, quando a chave as declara; senão a paleta inteira na ordem
   * canônica — que é o caso das duas cores do applet de mídia, cujo comentário
   * diz "vale qualquer nome da paleta" sem listar. */
  const nomes = item.opcoes.length ? item.opcoes : (ESQUEMA.paleta.ordem || []);
  const caixa = elemento("div", { class: "cores-grade" });
  const pintar = (v) => {
    for (const b of caixa.querySelectorAll("button")) {
      b.setAttribute("aria-pressed", String(b.dataset.valor === v));
    }
  };
  for (const nome of nomes) {
    if (!cores[nome]) continue;
    caixa.append(elemento("button", {
      type: "button", "data-valor": nome, "aria-pressed": "false",
      style: `background:${cores[nome]}`,
      title: `${nome} — ${cores[nome]}`,
      "aria-label": nome,
      onclick: async () => { if (await aplica(nome)) pintar(nome); },
    }));
  }
  pintar(item.valor ?? "");
  return caixa;
}

/* --- a barra desenhada ao vivo -------------------------------------------- */
/* As dezoito chaves `FORMA_*`/`VIDRO_*` não têm imagem para mostrar: elas
 * descrevem a GEOMETRIA da barra. O que existe é desenhá-la aqui, nos valores
 * escolhidos — e isso é mais honesto que um print, porque acompanha o controle
 * no mesmo quadro em vez de mostrar como era no dia em que alguém fotografou. */
function mockDaBarra(item) {
  const val = (chave, padrao) => {
    const k = ESQUEMA.chaves.find((x) => x.chave === chave);
    const v = k && (k.valor ?? "");
    return v === "" || v == null ? padrao : v;
  };
  const dock = item.chave.includes("DOCK");
  const raio = val(dock ? "FORMA_RAIO_DOCK" : "FORMA_RAIO_PAINEL", dock ? 16 : 8);
  const margem = val(dock ? "FORMA_MARGEM_DOCK" : "FORMA_MARGEM_PAINEL", dock ? 8 : 6);
  const espaco = val(dock ? "FORMA_ESPACO_DOCK" : "FORMA_ESPACO_PAINEL", dock ? 8 : 4);
  const recheio = val(dock ? "FORMA_RECHEIO_DOCK" : "FORMA_RECHEIO_PAINEL", dock ? 6 : 5);
  const opac = val(dock ? "VIDRO_OPACIDADE_DOCK" : "VIDRO_OPACIDADE_PAINEL", 0.8);

  const barra = elemento("div", { class: "barra" });
  for (let i = 0; i < 5; i++) barra.append(elemento("span"));
  const mock = elemento("div", {
    class: "mock",
    style: `--raio:${raio}px; --margem:${margem}px; --espaco:${espaco}px;`
         + `--recheio:${recheio}px; --op:${Math.max(0.15, Number(opac) || 0.8)}`,
  }, [barra, elemento("div", { class: "rodape" })]);

  return elemento("div", { style: "width:100%" }, [
    mock,
    elemento("p", {
      class: "sem-previa",
      texto: `desenho, não captura: ${dock ? "a dock" : "o painel"} com raio ${raio}, `
           + `margem ${margem}, espaço ${espaco} e recheio ${recheio}. `
           + "Vazio no meow.conf significa que o COSMIC decide, e aqui aparece o padrão dele.",
    }),
  ]);
}

/* --- a simulação do modo de leitura --------------------------------------- */
/* Aproximação de corpo negro para a cor de uma temperatura em Kelvin (a forma
 * usual de Tanner Helland). É SIMULAÇÃO e a legenda diz isso: quem pinta de
 * verdade é o cosmic-comp recompilado, e o que ele faz com os mesmos dois
 * números não é exatamente um multiply em cima de uma imagem. Mas a direção e a
 * intensidade batem, e é isso que responde "3500 é demais?". */
function corDeKelvin(k) {
  const t = Math.max(1000, Math.min(6500, Number(k) || 6500)) / 100;
  const lim = (x) => Math.max(0, Math.min(255, x));
  const r = t <= 66 ? 255 : lim(329.7 * Math.pow(t - 60, -0.1332));
  const g = t <= 66 ? lim(99.47 * Math.log(t) - 161.1) : lim(288.1 * Math.pow(t - 60, -0.0755));
  const b = t >= 66 ? 255 : (t <= 19 ? 0 : lim(138.5 * Math.log(t - 10) - 305.0));
  return `rgb(${Math.round(r)} ${Math.round(g)} ${Math.round(b)})`;
}

function simulacaoLeitura(item) {
  const temp = item.chave.includes("TEMPERATURA")
    ? (item.valor || 6500)
    : ((ESQUEMA.chaves.find((k) => k.chave === "LEITURA_TEMPERATURA") || {}).valor || 6500);
  const textura = item.chave.includes("TEXTURA")
    ? (item.valor || 0)
    : ((ESQUEMA.chaves.find((k) => k.chave === "LEITURA_TEXTURA") || {}).valor || 0);

  /* A imagem de exemplo é um papel de parede DELA — o efeito sobre a foto que
   * ela de fato usa diz mais do que sobre um degradê inventado. */
  const paredes = previasDe("parede", "ativos");
  const amostra = paredes && paredes.itens.find((i) => i.pronta);
  const caixa = elemento("div", { class: "simul" });
  if (amostra) caixa.append(elemento("img", { src: amostra.url, alt: "", loading: "lazy" }));
  else caixa.append(elemento("div", { class: "lugar", style: "height:108px" }));
  caixa.append(elemento("div", { class: "veu", style: `background:${corDeKelvin(temp)}` }));
  const t = Math.max(0, Math.min(1, Number(String(textura).replace(",", ".")) || 0));
  if (t > 0) {
    caixa.append(elemento("div", {
      class: "papel",
      style: `background: color-mix(in srgb, var(--rosewater) ${Math.round(t * 22)}%, transparent);`
           + `backdrop-filter: saturate(${Math.round(100 - t * 30)}%) contrast(${Math.round(100 - t * 8)}%)`,
    }));
  }
  caixa.append(elemento("div", {
    class: "legenda",
    texto: `simulação — ${temp}K, textura ${t}. Quem pinta de verdade é o cosmic-comp patchado.`,
  }));
  return caixa;
}

/* --- a grade de ícones do tema INSTALADO ---------------------------------- */
function gradeDeIcones(limite = 24) {
  const lista = previasDe("icone");
  if (!lista) return elemento("p", { class: "sem-previa", texto: "lendo o tema instalado…" });
  if (!lista.itens.length) {
    return elemento("p", {
      class: "sem-previa",
      texto: "o tema de ícones ainda não está no disco — rode “Reconstruir o tema de ícones”.",
    });
  }
  const grade = elemento("div", { class: "previa-grade" });
  for (const i of lista.itens.slice(0, limite)) {
    const caixa = elemento("div", { class: "caixa" });
    if (i.pronta) caixa.append(elemento("img", { src: i.url, alt: "", loading: "lazy", title: i.origem }));
    else caixa.append(elemento("div", { class: "lugar", style: "width:48px;height:48px;border-radius:6px" }));
    grade.append(elemento("figure", {}, [caixa, elemento("figcaption", { texto: i.rotulo })]));
  }
  return grade;
}


/* --- a galeria de papéis de parede ---------------------------------------- */
/* É O CASO DE USO MAIS VISUAL DO PROJETO, e era o que ela fazia à mão: abrir a
 * pasta no gerenciador de arquivos e apagar o que não gostava (o
 * `meow-ativos.path` percebe o sumiço em ~4 s e grava o nome no BANIDOS.txt).
 * Funciona, e é de mão única — desfazer exigia mexer num arquivo de texto.
 *
 * Por isso o `scripts/wallpaper.sh` ganhou hoje o verbo `desbanir`, que faz a
 * coisa INTEIRA: devolve a imagem de `banidos/` para `ativos/` E tira o nome da
 * lista de recusadas. Sem a segunda metade o estado se contradiz — a foto
 * girando no carrossel e o repositório dizendo que ela foi recusada.
 *
 * São 255 imagens em `banidos/` nesta máquina, e nenhuma foi apagada: o `banir`
 * move, nunca remove. É isso que faz desbanir ser possível de verdade. */
let ABA_GALERIA = "ativos";
let LIMITE_GALERIA = 60;

const GRUPOS_PAREDE = [
  { id: "ativos", rotulo: "No carrossel" },
  { id: "noite", rotulo: "Noite" },
  { id: "dia", rotulo: "Dia" },
  { id: "favoritos", rotulo: "Favoritos" },
  { id: "banidos", rotulo: "Recusadas" },
];

function montarGaleria() {
  const caixa = elemento("div");
  const abas = elemento("div", { class: "abas" });
  for (const g of GRUPOS_PAREDE) {
    const lista = PREVIAS.get("parede/" + g.id);
    abas.append(elemento("button", {
      type: "button", "aria-pressed": String(g.id === ABA_GALERIA),
      onclick: () => { ABA_GALERIA = g.id; LIMITE_GALERIA = 60; render(); },
    }, [
      elemento("span", { texto: g.rotulo }),
      elemento("span", { class: "conta", texto: lista ? ` ${lista.itens.length}` : "" }),
    ]));
  }
  caixa.append(abas);

  const lista = previasDe("parede", ABA_GALERIA);
  if (!lista) {
    caixa.append(elemento("p", { class: "sem-previa", texto: "lendo o acervo…" }));
    return caixa;
  }
  if (!lista.itens.length) {
    caixa.append(elemento("p", {
      class: "sem-previa",
      texto: ABA_GALERIA === "favoritos"
        ? "nenhum favorito ainda — a pasta favoritos/ está vazia."
        : "nada aqui.",
    }));
    return caixa;
  }

  if (lista.faltam) {
    caixa.append(elemento("p", {
      class: "sem-previa",
      texto: `${lista.faltam} miniatura(s) sendo geradas — as imagens aparecem sozinhas.`,
    }));
  }

  const banidos = ABA_GALERIA === "banidos";
  const grade = elemento("div", { class: "galeria" });
  for (const i of lista.itens.slice(0, LIMITE_GALERIA)) {
    const fig = elemento("figure");
    if (i.pronta) {
      fig.append(elemento("img", { src: i.url, alt: i.rotulo, loading: "lazy", title: i.origem }));
    } else {
      fig.append(elemento("div", { class: "lugar" }));
    }
    const acoes = elemento("div", { class: "acoes" });
    /* O botão é o comando da CLI, não uma operação de arquivo inventada aqui: a
     * página nunca move nem apaga nada por conta própria. */
    if (banidos) {
      acoes.append(elemento("button", {
        type: "button", class: "btn",
        texto: "Devolver",
        title: `meow wallpaper desbanir ${i.rotulo}`,
        onclick: () => rodarNaGaleria("wallpaper_desbanir", i.rotulo),
      }));
    } else if (ABA_GALERIA === "ativos") {
      acoes.append(elemento("button", {
        type: "button", class: "btn btn-perigo",
        texto: "Banir",
        title: `meow wallpaper banir ${i.rotulo} — vai para banidos/, nunca é apagada`,
        onclick: () => rodarNaGaleria("wallpaper_banir", i.origem),
      }));
    }
    fig.append(elemento("figcaption", {}, [
      elemento("span", { class: "nome", texto: i.rotulo }),
      acoes.children.length ? acoes : null,
    ]));
    grade.append(fig);
  }
  caixa.append(grade);

  /* 255 recusadas de uma vez seriam 255 conversões e uma página de rolagem
   * infinita. Vem de sessenta em sessenta, e quem quiser mais pede. */
  if (lista.itens.length > LIMITE_GALERIA) {
    caixa.append(elemento("button", {
      class: "btn",
      style: "margin-top:.8rem",
      texto: `Mostrar mais ${Math.min(60, lista.itens.length - LIMITE_GALERIA)} `
           + `(de ${lista.itens.length})`,
      onclick: () => { LIMITE_GALERIA += 60; render(); },
    }));
  }
  return caixa;
}

async function rodarNaGaleria(acaoId, argumento) {
  const acao = ESQUEMA.acoes.find((a) => a.id === acaoId);
  if (!acao) return;
  const r = await api("/api/rodar", {
    method: "POST",
    body: JSON.stringify({ acao: acaoId, argumento, seco: $("#seco").checked }),
  });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirGaveta(r);
  /* A lista muda por baixo: a imagem sai de `ativos/` e entra em `banidos/`.
   * Esperar o trabalho terminar e recarregar as duas é o que evita a galeria
   * mostrar por um minuto um estado que não existe mais. */
  const esperar = setInterval(async () => {
    if (TRABALHO) return;
    clearInterval(esperar);
    PREVIAS.delete("parede/ativos");
    PREVIAS.delete("parede/banidos");
    PREVIAS.delete("parede/noite");
    PREVIAS.delete("parede/dia");
    render();
  }, 700);
}

/* --- os cartões ----------------------------------------------------------- */
function montarCartao(item) {
  const emVigor = valorEmVigor(item);
  const mexeu = emVigor !== item.padrao;
  const naoSalvo = MUDANCAS.has(item.chave);
  const cartao = elemento("article", {
    class: "cartao" + (mexeu ? " mexeu" : "") + (naoSalvo ? " nao-salvo" : ""),
  });

  /* MENOS PALAVRAS NO TOPO DO CARTÃO.
   *   Antes: NOME_DA_CHAVE · essencial · "padrão: mocha" — três informações
   *   competindo, e a do meio explicada por extenso em todo cartão.
   *   Agora: o nome, um ponto para o essencial (com o texto no `title`), e o
   *   padrão SÓ quando a escolha dela difere dele — que é quando saber o padrão
   *   muda alguma coisa. Um cartão no padrão não precisa dizer que está no
   *   padrão: o controle já mostra o valor. */
  const topo = elemento("div", { class: "cartao-topo" }, [
    elemento("code", { texto: item.chave }),
    item.essencial
      ? elemento("span", { class: "marca-essencial", title: "Chave essencial", texto: "•" })
      : null,
    mexeu
      ? elemento("span", {
          class: "padrao",
          texto: item.padrao === "" ? "padrão vazio" : `padrão ${item.padrao}`,
          title: "O que o meow.conf.exemplo traz de fábrica.",
        })
      : null,
  ]);
  cartao.append(topo);
  /* O TÍTULO DO CARTÃO É UMA FRASE, não o identificador.
   * `LOGO_ROTACAO` diz o que a chave se chama; "O gato do painel troca sozinho"
   * diz o que ela FAZ — e é isso que ela precisa ler para escolher. O
   * identificador continua no topo, pequeno, porque é como a chave se chama no
   * arquivo e ela procura por ele. */
  const titulo = tituloDoCartao(item);
  if (titulo) cartao.append(elemento("h3", { class: "titulo-cartao", texto: titulo }));
  cartao.append(montarControle(item, cartao));

  if (item.frase && !titulo) {
    cartao.append(elemento("p", {
      /* `herdada` = o comentário veio de um bloco que descreve várias chaves.
       * Era itálico, e itálico em três linhas de texto corrido cansa a leitura
       * — vira uma mancha cinza inclinada repetida pela grade inteira. Agora é
       * um traço à esquerda, que informa a mesma coisa sem gritar. */
      class: "frase" + (item.ajuda_herdada ? " herdada" : ""),
      texto: item.frase,
      title: item.ajuda_herdada
        ? "Esta explicação é do bloco que cobre esta chave e as irmãs dela."
        : "",
    }));
  }

  /* O valor EFETIVO só aparece quando difere do cru — é o caso das chaves que
   * usam `$HOME` ou `${FLAVOR}`, onde o que está escrito e o que vale são
   * textos diferentes, e esconder um dos dois confunde. */
  if (item.efetivo && item.efetivo !== (item.valor ?? "")) {
    cartao.append(elemento("p", {
      class: "frase",
      texto: `vale como: ${item.efetivo}`,
      title: "O valor depois de o shell expandir as variáveis.",
    }));
  }

  /* A prévia que acompanha o controle em vez de substituí-lo: o degrau do modo
   * de leitura e a geometria das barras continuam sendo número, e o que a
   * imagem faz é dizer o que aquele número PARECE. */
  if (item.previa === "kelvin" || item.previa === "textura") {
    cartao.append(simulacaoLeitura(item));
  } else if (item.previa === "barra") {
    /* A BARRA NÃO SE REPETE POR CARTÃO — visto na primeira captura da seção:
     * seis desenhos idênticos da mesma barra, um por chave, empurrando o
     * controle para baixo e dizendo a mesma frase seis vezes. Uma prévia que
     * aparece seis vezes não informa seis vezes mais; ela vira ruído e esconde
     * o que mudou. O desenho subiu para o TOPO da seção (ver `render`), onde é
     * um só e reage a todas as chaves ao mesmo tempo — que é o comportamento
     * que a pessoa espera de "mexi no raio, olha a barra". */
  } else if (!item.previa && GRUPOS_VISUAIS.has(item.subsecao || item.secao)) {
    /* NEM TODA CHAVE VISUAL TEM PRÉVIA HONESTA, e onde não tem a página DIZ —
     * mas UMA VEZ POR SEÇÃO, não uma vez por cartão.
     *
     * A primeira versão punha a frase inteira dentro de cada cartão. Numa seção
     * de catorze chaves, a mesma linha aparecia catorze vezes: metade do texto
     * da tela era um aviso repetido, e ele empurrava a explicação de verdade
     * para fora do corte. Visto na captura da seção Automação, 01/09/2026 —
     * nove repetições numa tela só.
     *
     * Fica a marca discreta no cartão (o `data-sem-previa`, que o CSS usa para
     * um traço lateral) e a frase completa no cabeçalho da seção. */
    cartao.dataset.semPrevia = "1";
  }

  if (item.ajuda) {
    cartao.append(elemento("details", { class: "porque" }, [
      elemento("summary", { texto: "Por quê" }),
      elemento("pre", { texto: item.ajuda.replace(/^# ?/gm, "").trim() }),
    ]));
  }
  return cartao;
}

/* --- as ações ------------------------------------------------------------- */
function montarAcao(acao) {
  const bloco = elemento("article", { class: "acao" });
  bloco.append(elemento("h3", { texto: acao.rotulo }));
  bloco.append(elemento("p", { texto: acao.ajuda }));

  let escolha = null;
  if (acao.opcoes && acao.opcoes.length) {
    const sel = elemento("select", { "aria-label": `Valor para ${acao.rotulo}` });
    for (const o of acao.opcoes) sel.append(elemento("option", { value: o, texto: o }));
    bloco.append(sel);
    escolha = sel;
  }

  const rodape = elemento("div", { class: "rodape" });
  if (acao.sudo) rodape.append(elemento("span", { class: "pastilha p-sudo", texto: "pode usar sudo" }));
  if (acao.destrutivo) rodape.append(elemento("span", { class: "pastilha p-perigo", texto: "desfaz coisas" }));
  /* `rede` é DECLARADA pela ação, nunca adivinhada do texto dela. A primeira
   * versão fazia `/rede|baixa/i.test(acao.ajuda)` e o resultado apareceu na
   * tela em 01/09/2026: o cartão "Conferir (doctor)" — cuja ajuda diz, com
   * todas as letras, que ele "nunca usa sudo e nunca baixa nada" — ganhou uma
   * pastilha "usa rede". Um marcador que lê a prosa acaba dizendo o contrário
   * dela; quem sabe se a ação toca a rede é quem a escreveu. */
  if (acao.rede) rodape.append(elemento("span", { class: "pastilha p-rede", texto: "usa rede" }));
  if (acao.seco) rodape.append(elemento("span", { class: "pastilha p-seco", texto: "aceita seco" }));

  rodape.append(elemento("button", {
    type: "button",
    class: "btn " + (acao.destrutivo ? "btn-perigo" : "btn-accent"),
    texto: "Rodar",
    onclick: () => rodar(acao, escolha ? escolha.value : ""),
  }));
  bloco.append(rodape);
  bloco.append(elemento("code", { class: "cmd", texto: acao.argv, title: acao.argv }));
  return bloco;
}

async function rodar(acao, argumento) {
  const seco = $("#seco").checked && acao.seco;
  if (acao.confirma || acao.sudo || acao.destrutivo) {
    const ok = await confirmar(acao, argumento, seco);
    if (!ok) return;
  }
  const r = await api("/api/rodar", {
    method: "POST",
    body: JSON.stringify({ acao: acao.id, argumento, seco }),
  });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirGaveta(r);
}

function confirmar(acao, argumento, seco) {
  const dlg = $("#confirmar");
  $("#confirmar-titulo").textContent = acao.rotulo;
  $("#confirmar-texto").textContent = acao.ajuda;
  $("#confirmar-sudo").hidden = !acao.sudo;
  $("#confirmar-comando").textContent =
    (seco ? "MEOW_DRY_RUN=1 " : "") + acao.argv.replace("@ARG@", argumento);
  $("#confirmar-ok").textContent = seco ? "Rodar em seco" : "Rodar de verdade";
  $("#confirmar-ok").className = "btn " + (seco ? "btn" : acao.destrutivo ? "btn-perigo" : "btn-accent");
  dlg.showModal();
  return new Promise((resolve) => {
    dlg.addEventListener("close", () => resolve(dlg.returnValue === "sim"), { once: true });
  });
}

/* --- a gaveta de saída ---------------------------------------------------- */
function classeDaLinha(linha) {
  const t = linha.trimStart();
  if (t.startsWith("ok ")) return "l-ok";
  if (t.startsWith("~~")) return "l-muda";
  if (t.startsWith("--")) return "l-pula";
  if (t.startsWith("!!") || t.startsWith("erro")) return "l-erro";
  if (t.startsWith(">>")) return "l-info";
  /* Um título do projeto é uma linha sem recuo, sem glifo e não vazia — é o que
   * o `meow_titulo`/`meow_passo` imprimem em mauve no terminal. */
  if (linha && linha === t && !/^\s/.test(linha) && linha.length < 70) return "l-tit";
  return "";
}

function abrirGaveta(trabalho) {
  if (TRABALHO?.timer) clearInterval(TRABALHO.timer);
  TRABALHO = { id: trabalho.id, proximo: 0, timer: null, escreve: trabalho.escreve };
  $("#gaveta").hidden = false;
  $("#gaveta-titulo").textContent = trabalho.rotulo + (trabalho.seco ? "  (em seco)" : "");
  $("#gaveta-comando").textContent = trabalho.comando;
  $("#saida").replaceChildren();
  $("#parar").disabled = false;
  marcarEstado("correndo", "correndo…");
  TRABALHO.timer = setInterval(puxar, 400);
  puxar();
}

function marcarEstado(classe, texto) {
  const el = $("#gaveta-estado");
  el.className = "pastilha p-" + classe;
  el.textContent = texto;
}

async function puxar() {
  if (!TRABALHO) return;
  const r = await api(`/api/trabalho?id=${TRABALHO.id}&desde=${TRABALHO.proximo}`);
  if (r.erro) { clearInterval(TRABALHO.timer); return; }
  TRABALHO.proximo = r.proximo;

  const saida = $("#saida");
  /* Só rola sozinho se ela já estava no fim. Rolar por cima de quem subiu para
   * ler uma linha de erro é a coisa mais irritante que um console faz. */
  const noFim = saida.scrollTop + saida.clientHeight >= saida.scrollHeight - 24;
  for (const linha of r.linhas) {
    saida.append(elemento("span", { class: classeDaLinha(linha), texto: linha + "\n" }));
  }
  if (noFim) saida.scrollTop = saida.scrollHeight;

  if (!r.vivo) {
    clearInterval(TRABALHO.timer);
    $("#parar").disabled = true;
    const escreveu = TRABALHO.escreve;
    /* Os códigos de saída do projeto, traduzidos com as palavras dele: 0 já
     * estava certo, 3 falta dependência, o resto é erro. Um "exit 1" cru
     * pareceria falha, e aqui ele é a boa notícia.
     *
     * O 1 DEPENDE DE QUEM RODOU, e ignorar isso era uma mentira na tela: um
     * `meow status`, que só olha, terminava com a pastilha "mexeu e consertou".
     * Visto em 01/09/2026. Para quem ESCREVE, 1 é "divergia e consertei"; para
     * quem só LÊ, o mesmo 1 é "achei divergência" — e ninguém consertou nada. */
    const rc = r.rc;
    if (rc === 0) marcarEstado("ok", `já estava certo · ${r.segundos}s`);
    else if (rc === 1) marcarEstado(escreveu ? "ok" : "correndo",
      `${escreveu ? "mexeu e consertou" : "há divergências"} · ${r.segundos}s`);
    else if (rc === 3 || rc === 4) marcarEstado("pula", `pulado · ${r.segundos}s`);
    else marcarEstado("erro", `saiu ${rc} · ${r.segundos}s`);
    /* Um doctor --consertar ou um install que passou zera a lista de pendentes:
     * o que estava escrito no conf acabou de valer na tela. Só quem ESCREVE
     * zera — um `meow status` bem-sucedido não aplicou chave nenhuma, e apagar
     * o aviso ali faria a página esquecer o que ainda está esperando. */
    if (escreveu && (rc === 0 || rc === 1)) { PENDENTES.clear(); atualizarAviso(); }
    TRABALHO = null;
  }
}

/* --- navegação ------------------------------------------------------------ */
function montarTrilho() {
  const trilho = $("#trilho");
  /* O FOCO SOBREVIVE À RECONSTRUÇÃO — e não sobrevivia (visto em 01/09/2026)
   *   Trocar de seção chama `render()`, que chama isto, que apaga e refaz os 20
   *   botões. O botão que estava com o foco deixa de existir, e o navegador
   *   devolve o foco para o `<body>`: o Tab seguinte recomeça do topo da página.
   *
   *   Descobri navegando só de teclado — apertei Enter numa seção do trilho e o
   *   próximo Tab, que devia entrar no conteúdo, voltou para o começo. Para quem
   *   usa o mouse isso é invisível; para quem não usa, é a página perdendo o
   *   lugar a cada clique. Guardar o nome e devolver o foco ao botão equivalente
   *   custa estas três linhas. */
  const focado = document.activeElement?.dataset?.grupo;
  trilho.replaceChildren();

  /* MENU EM DOIS NÍVEIS — pedido dela em 01/09/2026 ("um menu com subtopicos é
   * importante"). A seção é o nível de cima; o subtítulo do bloco no
   * meow.conf.exemplo é o subtópico. Quando uma seção tem um subtópico só, ela
   * aparece como item simples — um pai com um filho só é um degrau que não
   * ajuda ninguém a achar nada. */
  const porSecao = new Map();
  for (const g of GRUPOS.filter((x) => x.tipo === "chaves")) {
    if (!porSecao.has(g.secaoPai)) porSecao.set(g.secaoPai, []);
    porSecao.get(g.secaoPai).push(g);
  }

  trilho.append(elemento("div", { class: "rotulo-grupo", texto: "Configuração" }));
  for (const [secao, grupos] of porSecao) {
    if (grupos.length === 1 && grupos[0].nome === secao) {
      trilho.append(botaoTrilho(grupos[0]));
      continue;
    }
    const aberta = grupos.some((g) => g.nome === ABA);
    trilho.append(elemento("div", {
      class: "secao-menu" + (aberta ? " aberta" : ""),
      texto: encurtar(secao),
      title: secao,
    }));
    for (const g of grupos) {
      /* Um subtópico com o mesmo nome da seção lia "Aparência / Aparência" —
       * o pai já disse. Aqui ele é o bloco sem subtítulo do arquivo, ou seja: o
       * geral daquela seção. */
      /* O aparte entre parênteses sai do MENU (fica no `title`): "O gato segue
       * o relógio (novo em 01/09/2026)" cabe em meia linha sem a data, e a
       * data não ajuda ninguém a achar a seção. */
      const rotulo = g.nome === secao ? "Geral" : encurtar(g.nome);
      trilho.append(botaoTrilho(g, true, rotulo));
    }
  }

  trilho.append(elemento("hr"));
  trilho.append(elemento("div", { class: "rotulo-grupo", texto: "Fazer" }));
  for (const g of GRUPOS.filter((x) => x.tipo !== "chaves")) {
    trilho.append(botaoTrilho(g));
  }
  if (focado) {
    const volta = trilho.querySelector(`[data-grupo="${CSS.escape(focado)}"]`);
    if (volta) volta.focus();
  }
}

function botaoTrilho(g, filho, rotulo) {
  return elemento("button", {
    type: "button",
    class: filho ? "filho" : "",
    "data-grupo": g.nome,
    "aria-current": String(g.nome === ABA),
    title: g.original || g.nome,
    onclick: () => { ABA = g.nome; gravarHash(); render(); },
  }, [
    elemento("span", { texto: rotulo || encurtar(g.nome) }),
    elemento("span", { class: "conta", texto: contaDoGrupo(g) }),
  ]);
}

/* O NÚMERO AO LADO DO NOME TEM DE CONTAR O QUE A SEÇÃO MOSTRA.
 *   A galeria aparecia como "Galeria de papéis de parede  0" — porque o
 *   contador lia `itens.length`, e a galeria não é feita de chaves do
 *   meow.conf: os itens dela são as imagens, que chegam depois, do
 *   `/api/previas`. Um zero ao lado de 46 fotos é pior que nenhum número: diz à
 *   pessoa que não há nada ali, justamente na seção mais visual da página. */
function contaDoGrupo(g) {
  if (g.tipo !== "galeria") return String(g.itens.length);
  const lista = PREVIAS.get("parede/" + ABA_GALERIA);
  return lista ? String(lista.itens.length) : "";
}

function render() {
  montarTrilho();
  const alvo = $("#conteudo");
  alvo.replaceChildren();
  const busca = semAcento($("#busca").value.trim());

  /* A busca atravessa TODOS os grupos, e é assim que uma página de 95 chaves
   * deixa de exigir que ela lembre em qual aba a chave mora. Sem busca, mostra
   * só a aba escolhida. */
  const grupos = busca
    ? GRUPOS.map((g) => ({ ...g, itens: g.itens.filter((i) => casa(i, busca)) })).filter((g) => g.itens.length)
    : GRUPOS.filter((g) => g.nome === ABA);

  if (!grupos.length) {
    alvo.append(elemento("p", { class: "vazio-msg", texto: `Nada casa com “${$("#busca").value}”.` }));
    return;
  }

  /* As quatro pílulas de fundo só aparecem onde há imagem para pôr sobre elas —
   * numa aba de texto puro seriam quatro botões que não fazem nada visível. */
  const temImagem = grupos.some((g) => g.tipo === "galeria" || g.nome === GRUPO_ICONES
    || (g.itens || []).some((i) => i.previa === "gato" || i.previa === "cursor"));
  if (temImagem) alvo.append(barraDeFundos());

  for (const g of grupos) {
    if (busca || g.tipo !== "chaves") {
      alvo.append(elemento("h2", { class: "secao-titulo", title: g.nome,
                                   texto: encurtar(g.nome) }));
    }
    if (g.tipo === "folhas") { alvo.append(montarFolhas(g.itens)); continue; }
    if (g.tipo === "galeria") { alvo.append(montarGaleria()); continue; }
    /* A grade de ícones abre a seção de ícones: uma grade para o grupo inteiro,
     * e não uma miniatura repetida dentro de cada cartão. O que ela mostra é o
     * tema que está INSTALADO — "está no disco?" e "está na tela dela?" são
     * perguntas diferentes, e é a segunda que importa aqui. */
    /* A nota que explicava o traço lateral saiu daqui — pedido dela no mesmo
     * dia: "temos que ter menos palavras na interface como um todo. a página
     * fala por si". Uma frase de vinte e duas palavras para explicar um traço
     * de dois pixels é a interface pedindo desculpa por si mesma. O traço fica;
     * quem quiser o texto abre o "Por quê" do cartão. */

    /* O par painel + dock, uma vez, antes dos controles da seção. Os dois
     * juntos porque as chaves vêm em par (`FORMA_RAIO_PAINEL` e
     * `FORMA_RAIO_DOCK` moram na mesma seção) e comparar é metade da escolha. */
    if (!busca && (g.itens || []).some((i) => i.previa === "barra")) {
      const par = elemento("div", { class: "grade-barras" });
      par.append(mockDaBarra({ chave: "FORMA_RAIO_PAINEL" }));
      par.append(mockDaBarra({ chave: "FORMA_RAIO_DOCK" }));
      alvo.append(par);
    }
    if (!busca && g.nome === GRUPO_ICONES) {
      alvo.append(elemento("p", {
        class: "frase",
        texto: "O tema de ícones como ele está no disco agora. Trocar uma chave abaixo "
             + "só muda isto depois de “Reconstruir o tema de ícones”.",
      }));
      alvo.append(gradeDeIcones());
    }
    const grade = elemento("div", { class: "grade" });
    for (const item of g.itens) {
      grade.append(g.tipo === "acoes" ? montarAcao(item) : montarCartao(item));
    }
    alvo.append(grade);
  }
}

/* A BUSCA IGNORA ACENTO, E ISSO NÃO É LUXO NUMA INTERFACE EM PORTUGUÊS
 *   Visto ao usar, em 01/09/2026: digitei "estado da maquina" e a página
 *   respondeu "nada casa" — a ação se chama "Estado da máquina", com o `á`. Toda
 *   a interface é em português e metade dos nomes tem acento (`Aparência`,
 *   `Ícones`, `Automação`, `A noite da máquina`); exigir o acento certo para
 *   ACHAR uma coisa é pedir que ela digite com mais cuidado do que digitaria
 *   numa busca qualquer.
 *
 *   `NFD` separa a letra do sinal, e a faixa `U+0300–U+036F` são exatamente os
 *   sinais separados — tirá-los deixa "máquina" e "maquina" iguais dos dois
 *   lados da comparação. O `ç` vira `c` de brinde, pela mesma decomposição.
 */
function semAcento(texto) {
  return String(texto)
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLocaleLowerCase("pt-BR");
}

function casa(item, busca) {
  const campos = item.chave
    ? [item.chave, item.frase, item.valor, item.secao, item.subsecao]
    : [item.rotulo, item.ajuda, item.id];
  return campos.filter(Boolean).some((c) => semAcento(c).includes(busca));
}

function montarFolhas(folhas) {
  const caixa = elemento("div");
  caixa.append(elemento("p", {
    class: "frase",
    texto: "As folhas visuais que decidiram este tema, versionadas em docs/folhas/. "
         + "Elas são arquivos locais: abra pelo caminho abaixo, ou pelo gerenciador de arquivos.",
  }));
  for (const f of folhas) {
    caixa.append(elemento("div", { class: "folha" }, [
      elemento("b", { texto: f.arquivo }),
      elemento("span", { class: "oque", texto: f.caminho }),
    ]));
  }
  return caixa;
}

/* --- teclado -------------------------------------------------------------- */
document.addEventListener("keydown", (ev) => {
  const digitando = /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement.tagName);
  if (ev.key === "/" && !digitando) { ev.preventDefault(); $("#busca").focus(); return; }
  if (ev.key === "Escape" && document.activeElement === $("#busca")) {
    $("#busca").value = ""; render(); return;
  }
  /* Setas percorrem o trilho quando o foco está nele — é o que um menu de
   * navegação deve fazer, e o Tab continua servindo para sair dele. */
  if ((ev.key === "ArrowDown" || ev.key === "ArrowUp") && document.activeElement.dataset?.grupo) {
    ev.preventDefault();
    const botoes = [...$("#trilho").querySelectorAll("button")];
    const i = botoes.indexOf(document.activeElement);
    const proximo = botoes[i + (ev.key === "ArrowDown" ? 1 : -1)];
    if (proximo) { proximo.focus(); proximo.click(); }
  }
});

$("#busca").addEventListener("input", render);
$("#fechar-gaveta").addEventListener("click", () => {
  $("#gaveta").hidden = true;
  if (TRABALHO?.timer) clearInterval(TRABALHO.timer);
});
$("#parar").addEventListener("click", async () => {
  if (!TRABALHO) return;
  await api("/api/parar", { method: "POST", body: JSON.stringify({ id: TRABALHO.id }) });
  torrada("pedido de parada enviado", "igual");
});
document.addEventListener("click", (ev) => {
  const id = ev.target.dataset?.acaoRapida;
  if (id) rodar(ESQUEMA.acoes.find((a) => a.id === id), "");
});

/* --- arranque ------------------------------------------------------------- */
async function iniciar() {
  ESQUEMA = await api("/api/esquema");
  if (ESQUEMA.erro) {
    $("#conteudo").append(elemento("p", { class: "vazio-msg", texto: ESQUEMA.erro }));
    return;
  }

  /* O grupo de uma chave é o SUBTÍTULO do bloco quando existe, e o título da
   * seção quando não. O porquê está no `servidor.py`: os marcadores de seção do
   * meow.conf.exemplo saíram de ordem com o tempo (o `# --- Wallpaper` ficou
   * órfão acima do bloco da forma), e o subtítulo é o que de fato descreve o
   * assunto da chave. `Aparência` e `Ícones` continuam vindo da seção, porque
   * ali não há subtítulo nenhum. */
  const porGrupo = new Map();
  for (const item of ESQUEMA.chaves) {
    const nome = item.subsecao || item.secao || "Outras";
    if (!porGrupo.has(nome)) porGrupo.set(nome, []);
    porGrupo.get(nome).push(item);
  }
  /* O grupo guarda a SEÇÃO de onde veio: é ela que vira o nível de cima do
   * menu. Um trilho de vinte itens planos obriga a ler os vinte para achar um;
   * com dois níveis, ela lê cinco. */
  GRUPOS = [...porGrupo].map(([nome, itens]) => ({
    tipo: "chaves", nome, itens, secaoPai: itens[0]?.secao || "Outras",
  }));

  /* As ações vêm agrupadas pelo `grupo` que o servidor declara — uma aba por
   * assunto, na ordem em que o dicionário as define. */
  const porAcao = new Map();
  for (const acao of ESQUEMA.acoes) {
    if (!porAcao.has(acao.grupo)) porAcao.set(acao.grupo, []);
    porAcao.get(acao.grupo).push(acao);
  }
  for (const [nome, itens] of porAcao) GRUPOS.push({ tipo: "acoes", nome, itens });
  if (ESQUEMA.folhas.length) {
    GRUPOS.push({ tipo: "folhas", nome: "Folhas visuais", itens: ESQUEMA.folhas });
  }

  /* A galeria é um grupo do trilho como os outros — ela não é uma chave do
   * meow.conf, é o acervo em si, que neste projeto É a configuração ("soltou o
   * arquivo, entrou; apagou, saiu"). */
  GRUPOS.push({ tipo: "galeria", nome: "Galeria de papéis de parede", itens: [] });

  GRUPOS_VISUAIS = new Set(
    GRUPOS.filter((g) => g.tipo === "chaves" && g.itens.some((i) => i.previa))
          .map((g) => g.nome));
  const chaveTema = ESQUEMA.chaves.find((k) => k.chave === "NOME_TEMA_ICONES");
  GRUPO_ICONES = chaveTema ? (chaveTema.subsecao || chaveTema.secao) : null;
  if (GRUPO_ICONES) GRUPOS_VISUAIS.add(GRUPO_ICONES);
  aplicarFundo();

  $("#botao-salvar").addEventListener("click", salvarEscolhas);
  $("#botao-descartar").addEventListener("click", descartarEscolhas);

  ABA = abaDoHash() || GRUPOS[0].nome;
  gravarHash();
  /* O botão voltar do navegador é o desfazer que a pessoa já tem no dedo. */
  addEventListener("hashchange", () => {
    const nova = abaDoHash();
    if (nova && nova !== ABA) { ABA = nova; render(); }
  });

  const mexidas = ESQUEMA.chaves.filter((i) => (i.valor ?? "") !== i.padrao).length;
  $("#resumo").textContent =
    /* O caminho do meow.conf saiu da linha e foi para o `title`: ele tem 44
     * caracteres, aparece em toda tela e nunca muda. Fica o que muda. */
    `${ESQUEMA.chaves.length} chaves · ${mexidas} fora do padrão`
    + (ESQUEMA.conf_existe ? "" : " · o arquivo ainda não existe");
  $("#resumo").title = ESQUEMA.conf;

  render();
}

iniciar();

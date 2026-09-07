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

/* ===========================================================================
 * O ENSAIO É UM BOTÃO ACESO, E NÃO UMA CAIXA DE MARCAR — 06/09/2026
 * ===========================================================================
 * Palavras dela: *"ele tá como box mas poderia ser um botão que fica ativo (cor
 * amarela fraca) algo assim"*. A REGRA não mudou, e é a que ela mesma escreveu:
 * *"uma box pra marcar se quero ensaiar sem gravar. Se ela tiver marcada, cada
 * executar faz isso. Caso contrário ele executa de fato."* — só o controle
 * mudou de forma.
 *
 * POR QUE ISTO É UMA FUNÇÃO, E NÃO UM `.checked` TROCADO EM SEIS LUGARES
 *   A conferência mediu NOVE pontos neste arquivo, não seis: seis leituras, uma
 *   ESCRITA (`$("#seco").checked = true`, que restaurava do `sessionStorage`) e
 *   um `addEventListener("change", …)` com uma leitura dentro. E num `<button>`
 *   as três últimas são veneno silencioso: `.checked` é propriedade morta
 *   (escrever nela não pinta nada, ler devolve `undefined`) e `change` NUNCA
 *   dispara. Trocar só as seis leituras deixaria o botão acendendo na tela e
 *   matando, sem uma linha de erro, o "o seco sobrevive ao F5" — que dois
 *   validadores independentes já pegaram quebrado uma vez.
 *
 * `aria-pressed` é o atributo que diz "ligado" num botão de dois estados, é o
 * que o leitor de tela anuncia, e é por onde o `estilo.css` acende o amarelo em
 * `.btn-ensaio[aria-pressed="true"]`. Uma verdade só, lida por três leitores. */
function ensaiando() {
  const botao = $("#seco");
  return !!botao && botao.getAttribute("aria-pressed") === "true";
}

async function api(rota, opcoes = {}) {
  /* O SERVIDOR PODE TER MORRIDO — e a página tem de dizer isso.
   *   A validação mediu: "com o servidor fora do ar, todo botão Rodar vira
   *   botão morto: zero torrada, zero gaveta, zero erro". O `fetch` rejeita, a
   *   exceção sobe até o `onclick` e some — e ela fica clicando num botão que
   *   não responde, sem saber que o problema não é o clique.
   *   Acontece de verdade: o painel morre junto com o terminal que o subiu. */
  let resposta;
  try {
    resposta = await fetch(rota, {
      ...opcoes,
      headers: { "X-Meow-Token": TOKEN, "Content-Type": "application/json", ...(opcoes.headers || {}) },
    });
  } catch (e) {
    return {
      erro: "O painel perdeu o servidor. Feche esta aba e rode ./app/run.sh de novo.",
      sem_servidor: true,
    };
  }
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
 * mesma (ou a mim) o endereço de uma seção — numa página de cem chaves em
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

/* A ABA PASSOU A SER IDENTIFICADA POR BLOCO + NOME — 02/09/2026
 *   Enquanto "Fazer" era o único bloco de ações, o NOME bastava: nenhuma seção
 *   de chave se chamava igual a um grupo de ação. A reorganização quebrou isso
 *   no mesmo movimento em que consertou o resto — traduzir "Wallpaper" para
 *   "Papel de parede" e "Apps" para "Aplicativos" criou duas colisões com os
 *   grupos de ação de mesmo nome. Dois botões, o mesmo `ABA`, e clicar num
 *   abriria o outro.
 *   Em 06/09/2026 ela desfez o motivo: "temos duas guias de papéis de parede,
 *   temos várias páginas pra ícones — essas repetidas deveriam ser unidas cada
 *   qual em uma única página". Com uma página por ASSUNTO, o nome do assunto
 *   volta a ser único, e é ele a chave da aba: a galeria, os ajustes e as ações
 *   do papel de parede respondem todos por "Papel de parede", e é isso que faz
 *   os três caírem na mesma página sem uma linha de layout nova. */
function chaveDeAba(g) {
  return assuntoDe(g);
}

function abaDoHash() {
  const id = decodeURIComponent(location.hash.replace(/^#/, ""));
  if (!id) return null;
  const g = GRUPOS.find((x) => idDeAba(chaveDeAba(x)) === id);
  return g ? chaveDeAba(g) : null;
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
  traco: "Traço", chapado: "Chapado",
  espelho: "Espelho", hora: "Hora", rotacao: "Rotação", fixo: "Fixo",
  nitida: "Nítida", preencher: "Preencher", caber: "Caber", esticar: "Esticar",
  /* Os valores que a tela mostrava crus, como o arquivo os escreve.
   * `auto`, `info` e `debug` apareciam DUAS VEZES neste objeto — a primeira
   * definição com o rótulo velho, logo acima, e esta com o novo. Em JavaScript
   * a última vence em silêncio, então a tela estava certa e o mapa mentia:
   * quem lesse a linha de cima concluiria que o rótulo é "Debug". As três
   * primeiras saíram. */
  auto: "Automático", info: "Informação", debug: "Detalhado",
  global: "Todas as áreas", workspace: "Só a atual",
  tabular: "Em coluna", contorno: "Contornando",
  quadrante: "Médio", sextante: "Alto",
  accent: "Cor de destaque", port: "Do port oficial",
  true: "Sim", false: "Não",
  "30s": "30 s", "5m": "5 min", "2h": "2 h", "6h": "6 h", "12h": "12 h",
  "1d": "1 dia", "7d": "7 dias",
  /* Pedaços de NOME de chave que viram título quando a ajuda é herdada — ver
   * `tituloDoCartao`. "inicio" sem acento é o nome da chave; "Início" é o que
   * ela lê. */
  dia: "Dia", noite: "Noite", inicio: "Início", fim: "Fim", painel: "Painel",
  dock: "Dock", titulo: "Título", artista: "Artista", album: "Álbum",
  largura: "Largura", fonte: "Fonte", capa: "Capa", controles: "Controles",
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
  /* CHAVE QUE HERDA O COMENTÁRIO DO VIZINHO NÃO PODE HERDAR O TÍTULO DELE.
   *   `LOGO_DIA` e `LOGO_NOITE` dividem o mesmo bloco de comentário, então os
   *   dois cartões apareciam lado a lado com o título idêntico ("Os dois
   *   rostos…") — o teste novo contou dezesseis repetições assim. Quando a
   *   ajuda é herdada, o título vem da parte do NOME que distingue a chave das
   *   irmãs: `LOGO_DIA` -> "Dia", `NOITE_INICIO` -> "Início". Curto, e é
   *   exatamente a diferença entre as duas.
   *   A explicação inteira continua no "Por quê" — nada se perde. */
  /* TÍTULO ESCRITO À MÃO GANHA DE TÍTULO DERIVADO.
   *   Derivar o título da primeira oração do comentário produziu "Reparo
   *   notificar", "Vírgula-separado", "Base" e "Na virada". Um rótulo não é
   *   uma coisa derivável: ele é a menor frase que diz o que o controle faz, e
   *   isso alguém escreve. Continua vindo do `meow.conf.exemplo` (uma linha
   *   `# @ ` no bloco de cada chave), então a fonte única não se rompe. */
  if (item.titulo) return item.titulo;
  if (item.titulo_irmas) return item.titulo_irmas;
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

/* O valor sob o dedo, enquanto o dedo está no controle. Declarado aqui, e não
 * junto do `repintarPrevia` que o usa, porque `valorEmVigor` o consulta e roda
 * muito antes — um `let` mais abaixo cairia na zona morta e derrubaria a página
 * na primeira pintura. */
let PROVISORIO = null;

function valorEmVigor(item) {
  /* A ORDEM É: o dedo, a escolha pendente, o disco.
   *   `PROVISORIO` é o valor que está sob o dedo dela AGORA, enquanto arrasta um
   *   deslizante — ele ainda não é escolha (não entrou em `MUDANCAS`, não acende
   *   a barra do Salvar) e mesmo assim é o que ela está vendo. Pôr a consulta
   *   aqui, e não em cada desenho, é o que faz TODO leitor acompanhar o arrasto
   *   sem saber que ele existe: foi assim que o desenho da FORMA — que não passa
   *   pelo `MEOW_PREVIAS` — ganhou tempo real sem uma linha própria. */
  if (PROVISORIO && PROVISORIO.chave === item.chave) return PROVISORIO.valor;
  return MUDANCAS.has(item.chave) ? MUDANCAS.get(item.chave) : (item.valor ?? "");
}

/** O flavor que vale agora — a escolha pendente dela, ou o que está no disco. */
function flavorEmVigor() {
  const item = ESQUEMA.chaves.find((k) => k.chave === "FLAVOR");
  return (item ? valorEmVigor(item) : "") || "mocha";
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
  /* DEVOLVE `true`, E ISSO NÃO É DETALHE.
   *   Os controles foram escritos contra o `gravar()` de antes, que devolvia se
   *   a escrita deu certo: `onclick: async () => { if (await aplica(v)) pintar(v) }`.
   *   Quando `escolher()` tomou o lugar dele e não devolvia nada, o `if` ficou
   *   sempre falso — clicar num flavor ou numa cor registrava a escolha e NÃO
   *   movia a marcação. A auditoria de 01/09/2026 pegou os dois: "mocha
   *   continua sendo o único botão marcado, qualquer que seja o clicado". */
  return true;
}

function atualizarBarraSalvar() {
  const barra = $("#barra-salvar");
  const n = MUDANCAS.size;
  barra.hidden = n === 0;
  if (!n) return;
  /* A lista de chaves virou `title`: no banner não há largura para ela, e o
   * cartão de cada chave já está marcado na página. */
  const conta = $("#salvar-conta");
  conta.textContent = n === 1 ? "1 escolha" : `${n} escolhas`;
  conta.title = [...MUDANCAS.keys()].join(" · ");
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
  const seco = ensaiando();
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
    /* AS ESCOLHAS FICAM — em seco, nada foi escrito, então não há o que
     * confirmar. Limpá-las jogava fora o trabalho dela: a validação mediu
     * "Salvar e aplicar com o modo seco ligado joga fora as escolhas
     * pendentes". Ensaiar não pode custar o que se ensaiou. */
    torrada("Modo seco: nada foi escrito, e as escolhas continuam esperando", "igual");
    return;
  }
  MUDANCAS.clear();
  atualizarBarraSalvar();
  render();
  torrada("Escolhas gravadas no meow.conf. Aplicando…", "ok");
  await rodarAcao("instalar");
}

/* ===========================================================================
 * TRAZER DE VOLTA — 06/09/2026
 * ===========================================================================
 * O `Importar` NÃO GRAVA. Ele lê o arquivo, manda o texto para o servidor
 * conferir chave a chave, e o que passa vira ESCOLHA PENDENTE — igual a um
 * clique, com o cartão marcado e o banner contando. Quem escreve continua
 * sendo o `Salvar e aplicar`, que é o único caminho de escrita da página.
 *
 * POR QUE ASSIM, E NÃO GRAVANDO DIRETO
 *   Medido: cada gravação leva 0,45 s (sobe um bash, carrega o `lib/comum.sh`
 *   e reescreve os 55 KB do conf). Importar 96 chaves gravando seriam 43
 *   segundos de página parada — para uma operação que ela dispara ao escolher
 *   o arquivo errado por engano.
 *
 *   E encenando ela GANHA o que a página já dá: vê o que veio antes de aceitar,
 *   o modo seco continua valendo no `Salvar`, o `Descartar` desfaz tudo com um
 *   clique, e o instalador roda em seguida como em qualquer outra mudança.
 */
async function importarArquivo(arquivo) {
  if (!arquivo) return;
  /* Um meow.conf inteiro tem 55 KB. Meio megabyte é folga com sobra, e o teto
   * existe para o caso do arquivo errado — um vídeo arrastado por engano
   * viraria meio giga de string antes de o servidor dizer não. */
  if (arquivo.size > 512 * 1024) {
    torrada("Arquivo grande demais para ser um meow.conf", "erro");
    return;
  }
  let texto;
  try { texto = await arquivo.text(); }
  catch { torrada("Não consegui ler o arquivo", "erro"); return; }

  const r = await api("/api/importar", { method: "POST", body: JSON.stringify({ texto }) });
  if (r.erro) { torrada(r.erro, "erro"); return; }

  /* UM `render()` SÓ, NO FIM. O `escolher()` redesenha a página a cada chamada,
   * e chamá-lo noventa e seis vezes seria noventa e seis reconstruções da
   * árvore inteira. Aqui o miolo dele é repetido sem o redesenho, e a tela é
   * refeita uma vez quando tudo já está no lugar. */
  for (const m of r.mudam) MUDANCAS.set(m.chave, m.valor);
  atualizarBarraSalvar();
  render();

  const partes = [];
  if (r.mudam.length) partes.push(`${r.mudam.length} esperando o Salvar`);
  if (r.iguais.length) partes.push(`${r.iguais.length} já estavam assim`);
  if (r.recusadas.length) partes.push(`${r.recusadas.length} recusadas`);
  if (r.desconhecidas.length) partes.push(`${r.desconhecidas.length} fora do catálogo`);
  torrada(partes.join(" · ") || "O arquivo não trazia chave nenhuma",
          r.mudam.length ? "ok" : "igual");

  /* As recusas não cabem numa torrada e não podem sumir com ela: cada uma diz
   * qual chave e por quê, e é o que ela precisa para consertar o arquivo. */
  if (r.recusadas.length) {
    for (const rec of r.recusadas.slice(0, 4)) {
      torrada(`${rec.chave}: ${rec.erro}`, "erro");
    }
    if (r.recusadas.length > 4) {
      torrada(`…e mais ${r.recusadas.length - 4} recusadas`, "erro");
    }
  }
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
  const seco = ensaiando();
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
  if (item.previa === "areas") return controlePorArea(item, aplica);

  /* 1. lista separada por vírgula -> fichas */
  if (item.lista || item.lista_pathsep) {
    const sep = item.lista_pathsep ? ":" : ",";
    const caixa = elemento("div", { class: "fichas" });
    const desenhar = () => {
      caixa.replaceChildren();
      const itens = (valorEmVigor(item) || "").split(sep).map((s) => s.trim()).filter(Boolean);
      for (const nome of itens) {
        caixa.append(elemento("span", { class: "ficha" }, [
          elemento("span", { texto: nome }),
          elemento("button", {
            type: "button", "aria-label": `Tirar ${nome}`, texto: "×",
            onclick: async () => {
              const novos = itens.filter((x) => x !== nome);
              if (await aplica(novos.join(sep))) desenhar();
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
        /* NÃO se escreve em `item.valor` aqui: aquilo é o que está NO DISCO, e a
         * escolha ainda não foi salva. Escrever ali fazia a ficha sumir da
         * tela e o cartão perder a marca de "não salvo" — a auditoria pegou as
         * duas listas (APPS_ATIVOS e AUTOSTART_BLOQUEADOS) assim. */
        if (await aplica(novos.join(sep))) desenhar();
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
    /* O TERCEIRO ESTADO DO DESLIZANTE — 02/09/2026.
     *   A validação mediu: "os oito deslizantes de FORMA_* não têm o estado
     *   vazio: mostram 0 onde o arquivo está VAZIO". E vazio, neste projeto,
     *   não é zero — é "não toca", o gesto de devolver a decisão ao COSMIC. Um
     *   deslizante em 0 diz "raio zero, canto reto", que é uma escolha
     *   diferente e visível na tela dela.
     *   O mesmo botão serve à palavra especial (`MIDIA_FONTE="auto"`), que é o
     *   mesmo caso: um valor que não mora na régua.
     *   Quem declara isso é o esquema (`aceita_vazio`, `opcoes`), não uma lista
     *   de chaves aqui. */
    /* A palavra especial vem das opções OU do próprio padrão: `MIDIA_FONTE`
     * nasce `auto` e não declara lista nenhuma — a palavra está no valor de
     * fábrica, que é onde o arquivo a diz. */
    const naoNumero = (v) => v && !/^[\d.,]+$/.test(v);
    const especial = (item.opcoes || []).find(naoNumero)
      || (naoNumero(item.padrao) ? item.padrao : null);
    const forcado = especial && valor === especial;
    const vazio = valor === "";
    const naRegua = !vazio && !forcado;
    const slider = elemento("input", {
      type: "range", min: lo, max: hi, step: passo,
      value: naRegua ? valor : lo,
      "aria-label": item.chave,
      disabled: !naRegua,
    });
    const saida = elemento("output", {
      texto: vazio ? "como está" : (forcado ? rotuloDeValor(valor) : String(valor || lo)),
    });
    slider.addEventListener("input", () => {
      saida.textContent = slider.value;
      /* Repintar aqui, e não no `change`: o `change` só dispara ao SOLTAR, e o
       * gesto inteiro de procurar um valor acontece antes disso. */
      repintarPrevia(item.chave, slider.value);
    });
    slider.addEventListener("change", () => aplica(slider.value));
    caixa.append(slider, saida);

    const alternativas = elemento("div", { class: "faixa-estados" });
    if (item.aceita_vazio) {
      alternativas.append(elemento("button", {
        type: "button", class: "btn btn-mini",
        "aria-pressed": String(vazio),
        texto: "Deixar como está",
        title: "Quem decide passa a ser o COSMIC — é o que o vazio significa aqui",
        onclick: () => aplica(""),
      }));
    }
    if (especial) {
      alternativas.append(elemento("button", {
        type: "button", class: "btn btn-mini",
        "aria-pressed": String(forcado),
        texto: rotuloDeValor(especial),
        onclick: () => aplica(especial),
      }));
    }
    if (!naRegua) {
      alternativas.append(elemento("button", {
        type: "button", class: "btn btn-mini",
        texto: "Escolher número",
        onclick: () => aplica(String(item.padrao || lo)),
      }));
    }
    if (alternativas.childNodes.length) caixa.append(alternativas);
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
          type: "button", class: "vazio", "data-valor": "", texto: "Deixar como está",
          "aria-pressed": "false",
          title: "Quem decide passa a ser o COSMIC, ou você pelos Ajustes dele.",
          onclick: async () => { if (await aplica("")) pintar(""); },
        }));
      }
      pintar(valor);
      return caixa;
    }
    const caixa = elemento("div", { class: "controle" });
    const sel = elemento("select", { "aria-label": item.chave });
    if (item.aceita_vazio) sel.append(elemento("option", { value: "", texto: "— deixar como está —" }));
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
    placeholder: item.aceita_vazio ? "deixar como está" : item.padrao,
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
    type: "button", class: "btn", texto: "Deixar como está",
    title: "Quem decide passa a ser o COSMIC.",
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

/** Relê o catálogo do servidor sem perder as escolhas ainda não salvas. */
async function recarregarEsquema() {
  const novo = await api("/api/esquema");
  if (novo && !novo.erro && novo.chaves) {
    ESQUEMA = novo;
    montarGrupos();
  }
}

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
/* Quais acervos já ganharam o botão de acrescentar NESTA pintura da página. É
 * limpo no começo do `render()`, como o `barraDesenhada` do par painel+dock —
 * e pelo mesmo motivo: o que vale para a página inteira aparece uma vez. */
const ACERVO_DESENHADO = new Set();

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
  pintar(valorEmVigor(item));
  /* UM BOTÃO POR PÁGINA, E NÃO UM POR CARTÃO — 06/09/2026.
   *   MEDIDO no navegador, com a aba "Logo do sistema" aberta: SEIS botões
   *   "Adicionar logo" na mesma tela, um sob cada chave que oferece a escolha
   *   de uma logo (`LOGO`, `LOGO_DIA`, `LOGO_NOITE`, `FASTFETCH_LOGO_GATO`…).
   *   Os seis fazem exatamente a mesma coisa: o acervo é um só, e um arquivo
   *   solto ali aparece nas seis listas ao mesmo tempo.
   *
   *   É o mesmo defeito que o par painel+dock teve e que o selo "pode ensaiar"
   *   teve — uma coisa que vale para a página inteira repetida uma vez por
   *   cartão. Seis botões idênticos não oferecem seis caminhos; eles fazem
   *   duvidar de que sejam o mesmo caminho.
   *
   *   O `ACERVO_DESENHADO` é limpo no começo de cada `render()`, então a
   *   contagem é por PINTURA da página, e não global — trocar de aba devolve o
   *   botão à aba nova. */
  /* O BOTÃO DE ACRESCENTAR VALE PARA OS DOIS TIPOS DE IMAGEM — 06/09/2026.
   *   Era só o gato. O ponteiro tinha a mesma fileira de miniaturas e nenhuma
   *   porta de entrada: "Temas do Ponteiro só aparece um" parecia defeito da
   *   lista e não era. Medido: existe UM só instalado que a chave `CURSOR`
   *   alcança (`catppuccin-mocha-light-cursors`) — `Adwaita` e `Pop` têm
   *   `cursors/` dentro mas não terminam em `-cursors`, e a regra que o painel
   *   aplica exige o sufixo. Não faltava lista: faltava o botão.
   *
   *   Depois de enviar, o esquema TAMBÉM é relido: as opções de `LOGO`,
   *   `LOGO_DIA` e `LOGO_NOITE` são a pasta `assets/gatos/` (o servidor as lê do
   *   disco), e sem reler o esquema a logo nova aparecia na prévia e continuava
   *   fora dos botões de escolha até um F5. A auditoria reproduziu o passo e
   *   mediu: as prévias iam a três, os botões continuavam dois. O mesmo vale
   *   para o ponteiro, cuja lista vem do `cursor.sh listar`. */
  const cabe = (tipo === "gato" || tipo === "cursor") && !ACERVO_DESENHADO.has(tipo);
  if (cabe) ACERVO_DESENHADO.add(tipo);
  const add = cabe
    ? botaoAcervo(tipo, async () => {
        await recarregarEsquema();
        await carregarPrevias(tipo);
        render();
      })
    : null;
  return add ? elemento("div", { class: "com-acervo" }, [caixa, add]) : caixa;
}

/* ===========================================================================
 * ACRESCENTAR AO ACERVO — o mesmo botão para tudo o que entra de fora
 * ===========================================================================
 * "ela tem que integrar e atuar diretamente no repo local do user", e depois:
 * "é esse tipo de solução pra toda aba viu?".
 *
 * Um só componente, SEIS destinos. Ele não escolhe pasta nenhuma: manda o TIPO,
 * e o servidor resolve o destino — a página nunca soube, e não deve saber, onde
 * ficam as pastas do repositório nem onde um tema de ponteiro se instala.
 *
 * O SVG que entra por aqui passa pelo `normalizar_svg.py` do lado de lá, que é
 * o mesmo conserto que o `logo.sh` faz: um desenho salvo no Boxy com
 * `transform-origin` entra e simplesmente não aparece na tela.
 *
 * OS SEIS SÃO DE DUAS NATUREZAS, E É POR ISSO QUE HÁ UM `naMaquina`
 *   · ACERVO (logo, papel de parede, ícone): o arquivo vira arte do projeto,
 *     versionada em `assets/`. É de onde o instalador o leva para a máquina, e
 *     é o que sobrevive a uma reinstalação.
 *   · MÁQUINA (tema do ponteiro, fonte, tema de ícones): não é arte nossa — são
 *     pacotes de terceiros, com licença própria, que ela quer TER INSTALADOS.
 *     Guardá-los em `assets/` engordaria o repositório com coisa que não é
 *     dele. O servidor manda o arquivo para um temporário e quem instala é o
 *     COMANDO DA CLI, o mesmo que ela rodaria no terminal.
 *
 * E a diferença muda duas coisas na tela, as duas medidas do lado do servidor:
 *   1. o `seco` VIAJA no corpo do pedido. Nos três de repositório a página
 *      recusa o envio antes de sair (ver abaixo); nos três de máquina o
 *      servidor conhece o ensaio e responde "não instalei", o que é melhor —
 *      ela vê a resposta do lado que de fato instalaria;
 *   2. eles devolvem `rc` e `log`. E `rc: 0` NÃO É ERRO: é o contrato de
 *      idempotência deste projeto — "já estava assim" — que é exatamente a
 *      resposta certa para quem enviou o mesmo `.zip` duas vezes. Mostrar isso
 *      como falha ensinaria a desconfiar de uma resposta correta. */
const ACERVO_ACEITA = {
  /* "Adicionar logo", e não "Adicionar gato" — 06/09/2026. A aba passou a falar
   * de LOGO do sistema; a Coquinha e o Mimir continuam sendo o que vem de
   * fábrica, e não o assunto. Quem chega sem gato nenhum ainda pode pôr a
   * própria marca no menu de lançamento, na dock e no terminal. */
  gato: { aceita: ".svg,image/svg+xml", rotulo: "Adicionar logo" },
  parede: { aceita: "image/jpeg,image/png,image/webp", rotulo: "Adicionar imagem" },
  icone: { aceita: ".svg,image/svg+xml", rotulo: "Adicionar ícone" },
  cursor: { aceita: ".zip", rotulo: "Adicionar tema", naMaquina: true },
  /* As três extensões são as do `instalar_fontes.sh adicionar`: um `.zip` de
   * Nerd Font, ou o arquivo de uma família solta. */
  fonte: { aceita: ".zip,.ttf,.otf", rotulo: "Instalar fonte", naMaquina: true },
  "tema-icones": { aceita: ".zip", rotulo: "Adicionar tema de ícones", naMaquina: true },
};

function botaoAcervo(tipo, aoEntrar) {
  const conf = ACERVO_ACEITA[tipo];
  if (!conf) return null;
  const campo = elemento("input", {
    type: "file", accept: conf.aceita, hidden: true,
    onchange: async () => {
      const arq = campo.files && campo.files[0];
      campo.value = "";
      if (!arq) return;
      const seco = ensaiando();
      /* O MODO SECO COBRE ISTO TAMBÉM — 02/09/2026.
       *   A validação pegou: "o Modo seco NÃO cobre o botão Adicionar gato —
       *   ele escreve no repositório mesmo com o seco ligado". O seco é a rede
       *   de segurança desta página; uma escrita que passa por baixo dela é
       *   pior que não ter rede, porque ela confia.
       *
       *   A RECUSA É AQUI SÓ PARA OS TRÊS DE REPOSITÓRIO. Nos três que
       *   instalam na máquina o `seco` vai no corpo e o servidor responde por
       *   si — ele conhece o ensaio e diz o que faria. Recusar dos dois lados
       *   seria a página respondendo por um comando que ela não roda. */
      if (seco && !conf.naMaquina) {
        torrada(`Modo seco: ${arq.name} não foi enviado (desligue o seco para valer)`, "igual");
        return;
      }
      botao.disabled = true;
      const antes = botao.textContent;
      botao.textContent = "Enviando…";
      try {
        const b64 = await new Promise((ok, falha) => {
          const leitor = new FileReader();
          leitor.onerror = () => falha(new Error("não consegui ler o arquivo"));
          leitor.onload = () => ok(String(leitor.result).split(",")[1] || "");
          leitor.readAsDataURL(arq);
        });
        const r = await api("/api/acervo", {
          method: "POST",
          body: JSON.stringify({ tipo, nome: arq.name, conteudo: b64, seco }),
        });
        if (r.erro) { torrada(r.erro, "erro"); return; }
        if (conf.naMaquina) {
          /* O `depois` do servidor já diz o que aconteceu na língua do projeto:
           * "em ensaio: X não foi instalado", "X já estava instalado", ou o que
           * fazer agora que entrou. A torrada é ele, e não uma frase nossa que
           * teria de adivinhar qual dos três casos foi. */
          torrada(r.depois || `${r.nome} instalado`, r.rc === 1 ? "ok" : "igual");
          /* A SAÍDA DO COMANDO VAI PARA A TELA, e não para o console: é a mesma
           * saída que ela leria no terminal, e é onde está o nome do tema que
           * acabou de entrar. Ela sai numa torrada própria porque a primeira já
           * carrega a conclusão — e as duas juntas seriam um parágrafo. */
          if (r.log) torrada(r.log.split("\n").slice(-3).join(" · "), "igual");
          if (aoEntrar) await aoEntrar();
          return;
        }
        /* O LADO DA IMAGEM VAI NA TORRADA — 06/09/2026. Antes ela soltava o
         * arquivo e não sabia se ele entrava no grupo de dia ou no de noite:
         * quem separa é a luminância, e só na próxima vez que o carrossel
         * reaplica. O servidor agora mede na hora e diz. */
        const lado = r.grupo
          ? ` — imagem de ${r.grupo.lado} (luz ${r.grupo.luz}, corte ${r.grupo.corte})`
          : "";
        torrada(
          `${r.nome} entrou no acervo${r.substituiu ? " (substituiu o anterior)" : ""}`
          + lado
          + (r.normalizado ? " — e foi normalizado para o painel desenhar" : ""),
          "ok");
        if (aoEntrar) await aoEntrar();
      } catch (e) {
        torrada(String(e.message || e), "erro");
      } finally {
        botao.disabled = false;
        botao.textContent = antes;
      }
    },
  });
  const botao = elemento("button", {
    type: "button", class: "btn btn-acervo",
    texto: conf.rotulo,
    onclick: () => campo.click(),
  });
  return elemento("div", { class: "acervo-add" }, [botao, campo]);
}

/* --- amostras de flavor --------------------------------------------------- */
/* A tira mostra o flavor pelo que ele é: fundo, superfície, texto e os quatro
 * acentos. "macchiato" não diz nada; a tira diz. */
const CORES_DA_TIRA = ["base", "surface0", "surface2", "text", "mauve", "blue", "green", "peach"];

/* NEM TODA COMBINAÇÃO DE FLAVOR E ACCENT EXISTE — 02/09/2026.
 *   A validação mediu: "FLAVOR × ACCENT oferecem 48 combinações; só 3 existem
 *   de verdade, e a tela não conta isso em lugar nenhum". O `install.sh` recusa
 *   a combinação sem captura (o pré-voo avisa), mas só DEPOIS — ela escolhe,
 *   salva, roda o instalador e leva o não.
 *   A lista de capturas vem do disco, pela ação `tema_estado`; aqui o que
 *   importa é o par escolhido estar entre elas. */
function combinacaoTemCaptura() {
  const capturas = (ESQUEMA.capturas || []).map((c) => String(c).toLowerCase());
  if (!capturas.length) return null;
  const f = flavorEmVigor();
  const item = ESQUEMA.chaves.find((k) => k.chave === "ACCENT");
  const a = item ? valorEmVigor(item) : "";
  if (!f || !a) return null;
  return { par: `${f}-${a}`, existe: capturas.includes(`${f}-${a}`), capturas };
}

function avisoDeCombinacao() {
  const c = combinacaoTemCaptura();
  if (!c || c.existe) return null;
  return elemento("p", { class: "frase dominada" }, [
    elemento("b", { texto: `Não há captura para ${c.par}. ` }),
    elemento("span", {
      texto: `O instalador recusa a combinação sem captura. Existem: ${c.capturas.join(", ")}.`,
    }),
  ]);
}

/* UM SIM/NÃO POR ÁREA — 07/09/2026
 *   `AREAS_FOLGA` guarda os NOMES das áreas que ganham o espaço-figura, e como
 *   campo de texto pedia que ela digitasse o nome de novo, igualzinho ao que já
 *   está na chave de cima. Errar uma letra era gravar uma linha que o
 *   `areas.sh` não casa com área nenhuma — e ele não reclama, porque do ponto
 *   de vista dele a lista pode nomear uma área que ainda vai existir. O único
 *   aviso era o desenho não mudar.
 *
 *   AS ÁREAS SAEM DO `valorEmVigor` DA CHAVE DE CIMA, e não do disco: se ela
 *   acabou de renomear "OS" para "Trabalho" e ainda não salvou, é "Trabalho"
 *   que tem de aparecer aqui. As duas chaves são gravadas juntas, então mostrar
 *   o nome velho seria mostrar um botão que grava um nome que vai deixar de
 *   existir no mesmo "Salvar".
 *
 *   O QUE ELE GRAVA continua sendo o formato do arquivo: os nomes marcados,
 *   separados por vírgula, na ordem em que aparecem em `AREAS_NOMES`. Nenhuma
 *   chave nova, nenhum formato novo — só a forma de dizer a mesma coisa. */
function controlePorArea(item, aplica) {
  const nomesItem = ESQUEMA.chaves.find((k) => k.chave === "AREAS_NOMES");
  const nomes = String(nomesItem ? valorEmVigor(nomesItem) : "")
    .split(",").map((x) => x.trim()).filter(Boolean);
  /* Sem áreas nomeadas não há o que ligar, e um controle vazio seria pior que o
   * campo de texto: ele diria "não há escolha" quando o que há é uma chave de
   * cima em branco. Cai no campo comum, que ao menos deixa escrever. */
  if (!nomes.length) return null;

  const marcadas = new Set(String(valorEmVigor(item))
    .split(",").map((x) => x.trim()).filter(Boolean));
  const caixa = elemento("div", { class: "por-area" });
  for (const nome of nomes) {
    const ligada = marcadas.has(nome);
    const linha = elemento("div", { class: "linha-area" });
    linha.append(elemento("span", { class: "nome-area", texto: nome }));
    const par = elemento("div", { class: "estados" });
    for (const [rotulo, quer] of [["Sim", true], ["Não", false]]) {
      /* A ORDEM É A DE `AREAS_NOMES`, sempre — remontar a lista a partir dela,
       * em vez de acrescentar no fim, faz o valor gravado ser o mesmo
       * independentemente da ordem dos cliques. Dois caminhos que levam ao mesmo
       * estado têm de gravar o mesmo texto, senão o "14 mudados por você" do
       * topo conta uma mudança que não existe. */
      const novas = new Set(marcadas);
      if (quer) novas.add(nome); else novas.delete(nome);
      const daria = nomes.filter((n) => novas.has(n)).join(", ");
      par.append(elemento("button", {
        type: "button",
        class: "btn btn-mini" + (ligada === quer ? " escolhido" : ""),
        "aria-pressed": String(ligada === quer),
        /* O QUE ESTE BOTÃO GRAVARIA, escrito no próprio botão. Nenhum código
         * desta página o lê: é o contrato com `tests/app-navegador.py`, que
         * varre a interface sem saber o que cada cartão é e precisa de uma
         * forma única de perguntar "qual valor você põe?". Sem ele o teste não
         * enxergava este controle, e ficava dizendo "sem controle" sobre um
         * cartão que tem quatro botões. */
        "data-valor": daria,
        texto: rotulo,
        onclick: () => aplica(daria),
      }));
    }
    linha.append(par);
    caixa.append(linha);
  }
  return caixa;
}

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
  /* `valorEmVigor` e não `item.valor`: o disco não sabe da escolha que ela
   * acabou de fazer, e era o disco que estava pintando. */
  pintar(valorEmVigor(item));
  return caixa;
}

/* --- bolinhas de cor ------------------------------------------------------ */
function controleCor(item, aplica) {
  /* AS CORES OFERECIDAS SÃO AS DO FLAVOR ESCOLHIDO, e não as do gravado.
   * Achado da auditoria: escolher `latte` e olhar as bolinhas do ACCENT — elas
   * continuavam nos hexes do Mocha. A cor que ela vê tem de ser a cor que ela
   * vai receber. */
  const flavor = flavorEmVigor();
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
  /* `valorEmVigor` e não `item.valor`: o disco não sabe da escolha que ela
   * acabou de fazer, e era o disco que estava pintando. */
  pintar(valorEmVigor(item));
  return caixa;
}

/* --- a barra desenhada ao vivo -------------------------------------------- */
/* As dezoito chaves `FORMA_*`/`VIDRO_*` não têm imagem para mostrar: elas
 * descrevem a GEOMETRIA da barra. O que existe é desenhá-la aqui, nos valores
 * escolhidos — e isso é mais honesto que um print, porque acompanha o controle
 * no mesmo quadro em vez de mostrar como era no dia em que alguém fotografou. */
/* Exatamente as chaves que o `mockDaBarra` lê — as cinco do painel e as cinco
 * da dock. Escrita aqui, e não deduzida do nome, porque `VIDRO_OPACIDADE_*` não
 * começa por `FORMA_` e ficaria de fora de qualquer regra de prefixo. */
const CHAVES_DO_MOCK = [
  "FORMA_RAIO_PAINEL", "FORMA_MARGEM_PAINEL", "FORMA_ESPACO_PAINEL",
  "FORMA_RECHEIO_PAINEL", "VIDRO_OPACIDADE_PAINEL",
  "FORMA_RAIO_DOCK", "FORMA_MARGEM_DOCK", "FORMA_ESPACO_DOCK",
  "FORMA_RECHEIO_DOCK", "VIDRO_OPACIDADE_DOCK",
  /* AS DEZ QUE FALTAVAM — 07/09/2026
   *   Queixa dela, com a aba aberta e quatro escolhas na bandeja: *"eu interajo
   *   com os botões e os svgs não modificam"*. Medido: o bloco FORMA tem 18
   *   chaves e o desenho ouvia 8 delas. As dez abaixo não mexiam um pixel — e
   *   são justamente as que mais mudam a tela: a barra virar pastilha, colar na
   *   borda, e o tamanho de cada segmento.
   *
   *   Elas não entraram antes porque não são NÚMERO DE GEOMETRIA: as quatro
   *   primeiras são sim/não e as seis últimas são degraus (XS..XL). Um número
   *   vira `--variavel` no `style` e pronto; estas pediam vocabulário novo no
   *   desenho, e é o que `mockDaBarra` ganhou junto com esta lista. */
  "FORMA_PAINEL_SOLTO", "FORMA_PAINEL_ILHA",
  "FORMA_CENTRO_PAINEL", "FORMA_ALA_INICIAL_PAINEL", "FORMA_ALA_FINAL_PAINEL",
  "FORMA_DOCK_SOLTO", "FORMA_DOCK_ILHA",
  "FORMA_CENTRO_DOCK", "FORMA_ALA_INICIAL_DOCK", "FORMA_ALA_FINAL_DOCK",
];

/* O APPLET MEDE ISTO, EM UNIDADES LÓGICAS — está no comentário do bloco no
 * `meow.conf.exemplo`, medido no `lib/painel.sh`: a altura da barra é
 * `2*recheio + o MAIOR applet que ela hospeda`. O desenho usa os mesmos cinco
 * números para que subir um segmento engorde a barra aqui como engorda lá — é
 * a consequência que o arquivo avisa e que nenhum controle mostrava. */
const TAMANHO_APPLET = { XS: 32, S: 40, M: 56, L: 64, XL: 80 };
/* Um quarto: com `M` (56) o quadrado sai com 14 px, que era a medida fixa do
 * desenho antigo. O antigo vira o caso médio do novo, e nada encolhe de
 * surpresa na tela dela. */
const ESCALA_APPLET = 0.25;
/* Vazio herda o tamanho GERAL da barra, que não é chave do meow.conf: mora no
 * `size` do cosmic-panel. Lidos do disco em 26/08/2026 e escritos no
 * `scripts/forma.sh:205`: o painel é S e a dock é M. */
const TAMANHO_GERAL = { painel: "S", dock: "M" };

function mockDaBarra(item) {
  /* AO VIVO QUER DIZER LENDO A ESCOLHA, e não o disco. O desenho prometia
   * acompanhar o controle e não acompanhava: a auditoria mediu — "nenhuma
   * mudança de controle mexe nele". Lia `k.valor`, que é o que está gravado;
   * agora lê `valorEmVigor`, que é o que ela acabou de escolher. */
  const val = (chave, padrao) => {
    const k = ESQUEMA.chaves.find((x) => x.chave === chave);
    const v = k ? valorEmVigor(k) : "";
    return v === "" || v == null ? padrao : v;
  };
  const dock = item.chave.includes("DOCK");
  const suf = dock ? "DOCK" : "PAINEL";
  const raio = val("FORMA_RAIO_" + suf, dock ? 16 : 8);
  const margem = val("FORMA_MARGEM_" + suf, dock ? 8 : 6);
  const espaco = val("FORMA_ESPACO_" + suf, dock ? 8 : 4);
  const recheio = val("FORMA_RECHEIO_" + suf, dock ? 6 : 5);
  const opac = val("VIDRO_OPACIDADE_" + suf, 0.8);

  const sim = (x) => String(x).trim().toLowerCase() === "sim";
  const solto = sim(val("FORMA_" + suf + "_SOLTO", "sim"));
  const ilha = sim(val("FORMA_" + suf + "_ILHA", "nao"));

  /* O DEGRAU DE CADA SEGMENTO, e o que "vazio" quer dizer. Vazio não é zero nem
   * é erro: é "herda o tamanho geral da barra", e o desenho tem de mostrar o
   * tamanho herdado — senão o cartão vazio pareceria não ter tamanho nenhum. */
  const geral = TAMANHO_GERAL[dock ? "dock" : "painel"];
  const degrau = (chave) => {
    const bruto = String(val(chave, "")).trim().toUpperCase();
    const proprio = Object.prototype.hasOwnProperty.call(TAMANHO_APPLET, bruto);
    const nome = proprio ? bruto : geral;
    return { nome: nome, proprio: proprio, px: TAMANHO_APPLET[nome] * ESCALA_APPLET };
  };
  const segs = [
    { id: "inicial", chave: "FORMA_ALA_INICIAL_" + suf, quantos: 1 },
    { id: "centro", chave: "FORMA_CENTRO_" + suf, quantos: 3 },
    { id: "final", chave: "FORMA_ALA_FINAL_" + suf, quantos: 2 },
  ].map((seg) => Object.assign(seg, degrau(seg.chave)));

  /* A ALTURA SAI DO MAIOR APPLET, como na máquina: `2*recheio + o maior`. Sem
   * isto, subir a ala inicial para L não mostraria o preço — e o preço é a
   * barra inteira ficar mais alta, que é o que o arquivo avisa. */
  const maior = Math.max.apply(null, segs.map((s2) => s2.px));
  const altura = 2 * (Number(recheio) || 0) + maior;

  const barra = elemento("div", {
    class: "barra" + (ilha ? " ilha" : ""),
    style: `--altura:${Math.round(altura)}px`,
  });
  for (const seg of segs) {
    const caixa = elemento("div", { class: "seg", style: `--sq:${seg.px}px` });
    for (let i = 0; i < seg.quantos; i++) caixa.append(elemento("span"));
    barra.append(caixa);
  }

  /* A MARGEM SÓ EXISTE SE A BARRA ESTIVER DESCOLADA — e este é o ponto em que o
   * desenho antigo MENTIA, não apenas omitia. Medido no `scripts/forma.sh:25`:
   * gravar `margin: 8` com `anchor_gap: false` é gravar um número que o
   * compositor descarta calado, e a barra continua encostada na borda. O
   * desenho pintava o vão assim mesmo — ou seja, mostrava uma tela que a
   * máquina não ia produzir. */
  const margemVale = solto ? margem : 0;
  const mock = elemento("div", {
    class: "mock",
    style: `--raio:${raio}px; --margem:${margemVale}px; --espaco:${espaco}px;`
         + `--recheio:${recheio}px; --op:${Math.max(0.15, Number(opac) || 0.8)}`,
  }, [barra, elemento("div", { class: "rodape" })]);

  const nomeSeg = (id) => (id === "inicial" ? "ponta esquerda"
                          : id === "final" ? "ponta direita" : "meio");
  const tamanhos = segs.map((s2) => `${nomeSeg(s2.id)} ${s2.nome}`
    + (s2.proprio ? "" : " (herdado)")).join(", ");
  const notas = [
    `raio ${raio}, espaço ${espaco} e recheio ${recheio}`,
    solto ? `margem ${margem}` : `colada na borda — a margem ${margem} é gravada e o compositor a descarta`,
    ilha ? "em pastilha: encolhe até o conteúdo, e os três segmentos se juntam no meio"
         : "atravessando a tela, com os três segmentos separados",
    tamanhos,
    `altura ${Math.round(altura / ESCALA_APPLET / 4) * 4} = 2×recheio + o maior segmento`,
  ];

  return elemento("div", { style: "width:100%" }, [
    mock,
    elemento("p", {
      class: "sem-previa",
      texto: `desenho, não captura: ${dock ? "a dock" : "o painel"} `
           + notas.join("; ")
           + ". Vazio no meow.conf significa que o COSMIC decide, e aqui aparece o padrão dele.",
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
    ? (valorEmVigor(item) || 6500)
    : ((ESQUEMA.chaves.find((k) => k.chave === "LEITURA_TEMPERATURA") || {}).valor || 6500);
  const textura = item.chave.includes("TEXTURA")
    ? (valorEmVigor(item) || 0)
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


/* ===========================================================================
 * OS APLICATIVOS E SEUS ÍCONES — a aba que ela cobrou
 * ===========================================================================
 * "naquela página de icones, cara, uma das telas antigas permitia
 *  escolher o icon pra substituir tal programa. Aqui não temos isso. Ali tá
 *  travadasso. Todo e qualquer programa com .desktop tinha que tá ali."
 * E o princípio, que vale para esta aba e para as próximas:
 * "permitir facilidade do user. pra não depender de ajuda sempre."
 *
 * Cada aplicativo da máquina, com o ícone que está NA TELA agora. Trocar é
 * escolher um desenho e uma cor; a escolha é gravada no
 * `assets/icones/apps-arcticons.map` DO REPOSITÓRIO — é o que faz ela
 * sobreviver a uma reinstalação, e é o que "atuar no repo local" quer dizer.
 * O desenho escolhido, se ainda não estava no repositório, vem junto do acervo
 * Arcticons (21 mil) para `assets/icones/arcticons-apps/`. */
let APPS = null;
let APPS_BUSCA = "";
let APP_ABERTO = null;
let GLIFOS = { termo: null, itens: [], carregando: false };

async function carregarApps() {
  const r = await api("/api/apps");
  APPS = r.erro ? { apps: [], total: 0 } : r;
  render();
}

async function carregarGlifos(termo) {
  if (GLIFOS.termo === termo && !GLIFOS.carregando) return;
  GLIFOS = { termo, itens: [], carregando: true };
  const r = await api(`/api/glifos?busca=${encodeURIComponent(termo || "")}`);
  GLIFOS = { termo, itens: r.glifos || [], carregando: false, limitado: r.limitado };
  render();
}

function montarApps() {
  const caixa = elemento("div");
  if (!APPS) {
    carregarApps();
    caixa.append(elemento("p", { class: "sem-previa", texto: "Lendo os aplicativos…" }));
    return caixa;
  }

  const filtro = elemento("input", {
    type: "search", class: "busca-apps", value: APPS_BUSCA, "data-foco": "apps",
    placeholder: "Filtrar aplicativo…", "aria-label": "Filtrar aplicativo",
    oninput: (e) => { APPS_BUSCA = e.target.value; render(); },
  });
  caixa.append(elemento("div", { class: "linha-filtro" }, [
    filtro,
    elemento("span", { class: "frase nota-secao",
      texto: `${APPS.total} aplicativos com .desktop nesta máquina.` }),
  ]));

  /* PARA ONDE OS JOGOS FORAM — 06/09/2026.
   *   Pedido dela: *"na parte de ícones, os ícones que forem de jogos, coloca
   *   pra serem selecionados na aba Lançadores e Jogos"*. O servidor passou a
   *   separá-los (`_e_jogo`, pelo `Categories=Game` e pelo nome `meow-steam-*`)
   *   e a mandar aqui só a CONTAGEM do que saiu.
   *
   *   Esta linha existe porque vinte e quatro cartões sumirem de uma aba sem
   *   uma palavra é a página mentindo por omissão: quem estava procurando o
   *   ícone de um jogo concluiria que ele não tem `.desktop`. Uma linha, e ela
   *   diz para onde ir. */
  if (APPS.jogos) {
    caixa.append(elemento("p", { class: "nota-secao",
      texto: `${APPS.jogos} ${APPS.jogos === 1 ? "jogo tem" : "jogos têm"} `
           + "o ícone escolhido em «Lançadores e jogos», ao lado das capas." }));
  }

  caixa.append(gradeDeApps(APPS.apps || [], APPS_BUSCA, carregarApps));
  return caixa;
}

/* A GRADE DE APLICATIVOS SERVE ÀS DUAS ABAS — 06/09/2026.
 *   Ela era o corpo do `montarApps` e virou função porque a aba "Lançadores e
 *   jogos" passou a mostrar a mesma coisa sobre os jogos: o servidor devolve os
 *   ícones deles em `apps`, no MESMO formato de `_dados_apps`, justamente para
 *   que o painel de escolha de ícone seja reaproveitado sem saber que está numa
 *   página diferente. Copiar as trinta linhas para lá seria a segunda grade que
 *   deixa de acompanhar a primeira na próxima mudança.
 *
 *   `recarregar` é o que muda entre as duas: a aba de ícones relê `/api/apps`, a
 *   de jogos relê `/api/jogos` — e reler a errada deixaria a grade mostrando o
 *   ícone velho depois de trocá-lo. */
function gradeDeApps(apps, filtro, recarregar) {
  const termo = semAcento(String(filtro || "").trim());
  const lista = apps.filter((a) =>
    !termo || semAcento(a.nome).includes(termo) || semAcento(a.id).includes(termo));

  const grade = elemento("div", { class: "grade-apps" });
  for (const a of lista) {
    const fig = elemento("button", {
      type: "button",
      class: "app" + (APP_ABERTO === a.id ? " aberto" : ""),
      title: `${a.id}  ·  ${a.origem}`,
      onclick: () => {
        APP_ABERTO = APP_ABERTO === a.id ? null : a.id;
        /* A busca começa pelo nome do aplicativo — é o palpite certo na maioria
         * das vezes ("Telegram" acha `telegram`). Quando não acha nada, o
         * `montarEscolhaDeIcone` cai para o acervo do repositório, para a
         * fileira nunca abrir vazia. */
        if (APP_ABERTO) carregarGlifos(a.nome.split(/\s+/)[0].toLowerCase());
        render();
      },
    }, [
      a.url
        ? elemento("img", { src: a.url, alt: "", loading: "lazy" })
        : elemento("div", { class: "lugar", style: "width:40px;height:40px;border-radius:8px" }),
      elemento("span", { class: "app-nome", texto: a.nome }),
      /* A etiqueta diz o ESTADO, em uma palavra: a cor quando o app já está no
       * nosso mapa, "de fábrica" quando o ícone que aparece é o que veio com
       * ele. Sem isso, os dois casos são visualmente iguais e ela não sabe
       * onde ainda há trabalho. */
      a.mapa
        ? elemento("span", { class: "app-marca", texto: a.mapa.cor })
        : elemento("span", { class: "app-marca app-fabrica",
                             texto: a.nosso ? "nosso" : "de fábrica" }),
    ]);
    grade.append(fig);
    if (APP_ABERTO === a.id) grade.append(montarEscolhaDeIcone(a, recarregar));
  }
  return grade;
}

function montarEscolhaDeIcone(app, recarregar) {
  /* Quem mandou desenhar diz o que reler depois da escolha; sem ninguém dizer,
   * é a lista de aplicativos, que é de onde esta tela nasceu. */
  const relerLista = recarregar || carregarApps;
  const painel = elemento("div", { class: "escolha-icone" });
  painel.append(elemento("h3", { class: "titulo-cartao", texto: `Ícone de ${app.nome}` }));

  const busca = elemento("input", {
    type: "search", value: GLIFOS.termo || "", "data-foco": "glifos",
    placeholder: "Buscar desenho no acervo Arcticons…",
    "aria-label": "Buscar desenho",
    oninput: (e) => carregarGlifos(e.target.value.trim().toLowerCase()),
  });
  painel.append(busca);

  let escolhido = app.mapa ? app.mapa.glifo : null;
  let corEscolhida = app.mapa ? app.mapa.cor : ((ESQUEMA.paleta.ordem || [])[0] || "mauve");

  const tiraGlifos = elemento("div", { class: "tira-glifos" });
  const pintarGlifos = () => {
    for (const b of tiraGlifos.querySelectorAll("button")) {
      b.setAttribute("aria-pressed", String(b.dataset.glifo === escolhido));
    }
  };
  if (GLIFOS.carregando) {
    tiraGlifos.append(elemento("p", { class: "sem-previa", texto: "Procurando…" }));
  } else if (!GLIFOS.itens.length) {
    tiraGlifos.append(elemento("p", { class: "sem-previa",
      texto: "Nenhum desenho com esse nome — mostrando o acervo do repositório." }));
    if (GLIFOS.termo) carregarGlifos("");
  }
  for (const g of GLIFOS.itens) {
    tiraGlifos.append(elemento("button", {
      type: "button", "data-glifo": g.glifo, title: `${g.glifo} — ${g.grupo}`,
      "aria-pressed": String(g.glifo === escolhido),
      onclick: () => { escolhido = g.glifo; pintarGlifos(); },
    }, [
      elemento("img", { src: g.url, alt: "", loading: "lazy" }),
      elemento("span", { texto: g.glifo }),
    ]));
  }
  painel.append(tiraGlifos);

  const cores = elemento("div", { class: "cores-grade" });
  /* `ordem` e não `ordem_canonica`: o nome errado deixava a fileira de cores
   * VAZIA — o painel abria sem como escolher cor, e nada avisava. Visto ao
   * testar no navegador, contando os botões: zero. */
  const flavorAtual = flavorEmVigor();
  for (const nome of (ESQUEMA.paleta.ordem || [])) {
    const hex = ((ESQUEMA.paleta.flavors || {})[flavorAtual] || {})[nome];
    cores.append(elemento("button", {
      type: "button", "data-cor": nome, title: nome,
      "aria-pressed": String(nome === corEscolhida),
      style: hex ? `background:${hex}` : "",
      onclick: () => {
        corEscolhida = nome;
        for (const b of cores.querySelectorAll("button")) {
          b.setAttribute("aria-pressed", String(b.dataset.cor === corEscolhida));
        }
      },
    }));
  }
  painel.append(elemento("div", { class: "rotulo-mini", texto: "Cor" }));
  painel.append(cores);

  const acoes = elemento("div", { class: "escolha-botoes" });
  acoes.append(elemento("button", {
    type: "button", class: "btn btn-accent", texto: "Usar este ícone",
    onclick: async () => {
      if (!escolhido) { torrada("Escolha um desenho primeiro", "erro"); return; }
      const r = await api("/api/app-icone", {
        method: "POST",
        /* O ensaio viaja no corpo, e quem recusa é o servidor: o cliente
         * também poderia parar aqui, mas a escrita mora lá, e é lá que a
         * recusa tem de estar para valer contra um POST que não veio daqui. */
        body: JSON.stringify({ app: app.id, glifo: escolhido, cor: corEscolhida, seco: ensaiando() }),
      });
      if (r.erro) { torrada(r.erro, "erro"); return; }
      if (r.seco) { torrada(r.aviso, "igual"); return; }
      torrada(
        `${app.nome}: ${escolhido} em ${corEscolhida}`
        + (r.trouxe_do_acervo ? " — o desenho entrou no repositório" : "")
        + (r.alias ? " (marcado como alias: o desenho ou a cor já eram de outro app)" : ""),
        "ok");
      APP_ABERTO = null;
      await relerLista();
    },
  }));
  if (app.mapa) {
    acoes.append(elemento("button", {
      type: "button", class: "btn", texto: "Tirar do mapa",
      onclick: async () => {
        const r = await api("/api/app-icone", {
          method: "POST",
          body: JSON.stringify({ app: app.id, remover: true, seco: ensaiando() }),
        });
        if (r.erro) { torrada(r.erro, "erro"); return; }
        if (r.seco) { torrada(r.aviso, "igual"); return; }
        torrada(`${app.nome} saiu do mapa — volta para o ícone de fábrica`, "ok");
        APP_ABERTO = null;
        await relerLista();
      },
    }));
  }
  acoes.append(botaoAcervo("icone", async () => { await relerLista(); }));
  acoes.append(elemento("button", {
    type: "button", class: "btn", texto: "Reconstruir o tema",
    title: "A escolha só aparece na tela depois disto",
    onclick: () => rodarAcao("icones_reconstruir"),
  }));
  painel.append(acoes);
  painel.append(elemento("p", { class: "frase",
    texto: "A escolha é gravada em assets/icones/apps-arcticons.map, no repositório." }));
  return painel;
}

/* --- os jogos da Steam ----------------------------------------------------- */
/* Ela, 02/09/2026: "veja se está integrado ao app meowsystem." Não estava — tirar
 * um jogo da tela, ou apagar a sobra de um que perdeu a licença, era editar
 * `assets/icones/jogos-fora.map` num editor de texto.
 *
 * A PÁGINA NÃO APAGA NADA, E ISSO É DE PROPÓSITO
 *   Aqui ela escolhe; quem age é o `scripts/jogos_steam.sh` no botão "Arrumar
 *   os jogos no lançador", que já passa pelo confirmar e pela gaveta de saída.
 *   É a regra da casa (a receita vai para o repositório, o resultado não) e
 *   mantém `rm -rf` fora de um servidor HTTP.
 *
 * TRÊS ESTADOS, TRÊS PALAVRAS — e a etiqueta diz qual é sem ela abrir nada:
 *   "no lançador"  o normal: cartão na tela, arquivos onde estão
 *   "fora"         escondido a pedido dela; o disco não é tocado
 *   "apagar"       fora E os arquivos saem na próxima passagem
 * Com o registro de disparo, "apagar" que já rodou vira "apagado" — a linha
 * está gasta e não dispara de novo, nem se ela reinstalar o jogo. */
let JOGOS = null;
let JOGOS_BUSCA = "";
let JOGO_ABERTO = null;

async function carregarJogos() {
  const r = await api("/api/jogos");
  /* O molde de erro traz `apps` e `total_apps` porque a grade de ícones dos
   * jogos os lê: sem os campos, um erro do servidor viraria um `undefined` no
   * `.length` e derrubaria a aba inteira em vez de mostrá-la vazia. */
  JOGOS = r.erro ? { jogos: [], total: 0, apps: [], total_apps: 0 } : r;
  render();
}

async function definirJogo(appid, acao, motivo, remover) {
  const r = await api("/api/jogo-fora", {
    method: "POST",
    /* A linha que isto grava é uma RECEITA: quem apaga os gigabytes é o
     * `jogos_steam.sh` na passagem seguinte. Escrevê-la em ensaio deixaria o
     * apagamento armado sem que nada na tela tivesse dito que houve decisão. */
    body: JSON.stringify({ appid, acao, motivo, remover: !!remover, seco: ensaiando() }),
  });
  if (r.erro) { torrada(r.erro, "ruim"); return; }
  if (r.seco) { torrada(r.aviso, "igual"); return; }
  torrada(remover ? "Voltou ao normal — vale depois de arrumar os jogos"
                  : `Escolha gravada — ${r.depois}`);
  JOGO_ABERTO = null;
  await carregarJogos();
}

function etiquetaDoJogo(j) {
  if (j.gasto) return { texto: "apagado", classe: "jogo-gasto" };
  if (j.acao === "apagar") return { texto: "apagar", classe: "jogo-apagar" };
  if (j.acao === "esconder") return { texto: "fora", classe: "jogo-fora" };
  return { texto: "no lançador", classe: "app-fabrica" };
}

function montarJogos() {
  const caixa = elemento("div");
  if (!JOGOS) {
    carregarJogos();
    caixa.append(elemento("p", { class: "sem-previa", texto: "Lendo a biblioteca da Steam…" }));
    return caixa;
  }

  caixa.append(elemento("div", { class: "linha-filtro" }, [
    elemento("input", {
      type: "search", class: "busca-apps", value: JOGOS_BUSCA, "data-foco": "jogos",
      placeholder: "Filtrar jogo…", "aria-label": "Filtrar jogo",
      oninput: (e) => { JOGOS_BUSCA = e.target.value; render(); },
    }),
    elemento("span", { class: "frase nota-secao",
      texto: `${JOGOS.total} jogos instalados na Steam.` }),
  ]));

  /* OS DOIS BOTÕES MORAM AQUI, e não numa aba "Fazer" separada.
   *   É o que a galeria já faz com banir e devolver: a ação fica ao lado da
   *   coisa em que ela age. Sem isto, marcar um jogo aqui e ir procurar em outra
   *   seção o botão que aplica seria a página pedindo que ela guardasse na
   *   cabeça o passo seguinte. */
  const linhaAcoes = elemento("div", { class: "linha-botoes acoes-da-secao" });
  linhaAcoes.append(elemento("button", {
    type: "button", class: "btn",
    texto: "Conferir",
    title: "Lista o que mudaria. Não escreve nada.",
    onclick: () => rodarDaSecao("jogos", () => { JOGOS = null; }),
  }));
  linhaAcoes.append(elemento("button", {
    type: "button", class: "btn btn-accent",
    texto: "Arrumar os jogos no lançador",
    title: "Aplica as escolhas: cria e remove cartões, e apaga o que estiver marcado.",
    onclick: () => rodarDaSecao("jogos_aplicar", () => { JOGOS = null; }),
  }));
  caixa.append(linhaAcoes);

  const termo = semAcento(JOGOS_BUSCA.trim());
  const lista = (JOGOS.jogos || []).filter((j) =>
    !termo || semAcento(j.nome).includes(termo) || j.appid.includes(termo));

  /* A DECISÃO NÃO É UM JOGO, E NÃO PODE PARECER UM — 07/09/2026
   *   Queixa dela, sobre o Mad King: *"apagado, esse jogo já foi excluído mas
   *   algo insiste em trazer ele de volta"*. Nada o trazia. O que ela via era a
   *   LINHA do `jogos-fora.map` que sobreviveu ao jogo, desenhada como um
   *   ladrilho do mesmo tamanho dos outros, na mesma grade, com um retângulo
   *   cinza no lugar da capa. Do lado de fora isso lê "o jogo voltou, e sem
   *   capa" — que é a leitura certa para aquele desenho.
   *
   *   Ela continua tendo de aparecer: sem manifesto, o laço do servidor não a
   *   encontra, e tirá-la da tela seria esconder a única coisa que ainda existe
   *   sobre aquela decisão. Então ela sai da grade e vira uma LINHA, com o
   *   botão de tirar ali mesmo — antes era preciso abrir o cartão para achar o
   *   "Tirar a linha gasta", e quem não sabe que o cartão abre não acha. */
  const orfas = lista.filter((j) => j.sem_manifesto);
  const comJogo = lista.filter((j) => !j.sem_manifesto);

  const grade = elemento("div", { class: "grade-jogos" });
  for (const j of comJogo) {
    const marca = etiquetaDoJogo(j);
    const capa = j.url
      ? elemento("img", { src: j.url, alt: "", loading: "lazy" })
      /* Jogo sem capa é jogo sem manifesto: a linha do mapa que sobreviveu ao
       * jogo. O retângulo com o appid diz isso sem precisar de frase. */
      : elemento("div", { class: "jogo-sem-capa", texto: j.appid });
    grade.append(elemento("button", {
      type: "button",
      class: "jogo" + (JOGO_ABERTO === j.appid ? " aberto" : "")
             + (j.acao || j.gasto ? " marcado" : ""),
      title: `appid ${j.appid}`,
      onclick: () => { JOGO_ABERTO = JOGO_ABERTO === j.appid ? null : j.appid; render(); },
    }, [
      capa,
      elemento("span", { class: "app-nome", texto: j.nome }),
      elemento("span", { class: "app-marca " + marca.classe, texto: marca.texto }),
    ]));
    if (JOGO_ABERTO === j.appid) grade.append(montarEscolhaDeJogo(j));
  }
  caixa.append(grade);

  if (orfas.length) {
    caixa.append(elemento("h3", { class: "subsecao-titulo", texto: "Decisões já executadas" }));
    caixa.append(elemento("p", { class: "nota-secao",
      texto: orfas.length === 1
        ? "Este jogo não está mais na máquina. A linha fica aqui só para você "
          + "poder tirá-la: ela não traz o jogo de volta, e não apaga mais nada."
        : `Estes ${orfas.length} jogos não estão mais na máquina. As linhas ficam `
          + "aqui só para você poder tirá-las: elas não trazem os jogos de volta, "
          + "e não apagam mais nada." }));
    const cxOrfas = elemento("div", { class: "lista-orfas" });
    for (const j of orfas) {
      cxOrfas.append(elemento("div", { class: "linha-orfa" }, [
        elemento("span", { class: "orfa-nome", texto: j.nome }),
        elemento("span", { class: "orfa-nota",
          texto: j.apagado_em
            ? `arquivos apagados em ${j.apagado_em} · appid ${j.appid}`
            : `appid ${j.appid}` }),
        elemento("button", {
          type: "button", class: "btn btn-mini",
          texto: "Tirar da lista",
          title: "Apaga a linha do jogos-fora.map. Nenhum arquivo é tocado, e o "
               + "jogo não volta — ele não está no disco.",
          onclick: () => definirJogo(j.appid, "", "", true),
        }),
      ]));
    }
    caixa.append(cxOrfas);
  }

  /* ==========================================================================
   * O ÍCONE DE CADA JOGO, QUE ERA DA ABA DE ÍCONES — 06/09/2026
   * ==========================================================================
   * Pedido dela: *"na parte de ícones, os ícones que forem de jogos, coloca pra
   * serem selecionados na aba Lançadores e Jogos"*. A razão é de uso, e não de
   * arrumação: a aba de ícones existe para vestir os PROGRAMAS com o traço do
   * projeto, e um jogo não se veste — ele tem capa própria, vem e vai com a
   * licença, e o que ela decide sobre ele é outra coisa. Eram duas perguntas
   * diferentes na mesma página, e a de jogo era a que não tinha resposta ali.
   *
   * A LISTA É A DO SERVIDOR, E ELA NÃO É A MESMA DAS CAPAS — medido em
   * 06/09/2026 nesta máquina: 23 jogos com manifesto da Steam, 24 `.desktop` de
   * jogo, 22 casando por `meow-steam-<appid>`. Os que não casam são a própria
   * Steam e o ProtonUp-Qt (que se declaram `Categories=Game`) e um jogo cujo
   * cartão ainda não foi escrito. Grudar o seletor de ícone dentro do cartão da
   * capa perderia esses três — e é justamente a Steam que ela mais olha.
   *
   * NÃO É DUPLICAÇÃO: são duas perguntas sobre a mesma coisa, e cada uma tem um
   * cartão só. A capa decide se o jogo APARECE no lançador; esta grade decide
   * com que DESENHO ele aparece. O filtro é o mesmo do topo da página, então
   * procurar um jogo estreita as duas de uma vez.
   *
   * `total_apps` e não `apps.length`: o servidor filtra pela busca do lado de
   * lá quando ela é enviada, e o total é o número da máquina. */
  if ((JOGOS.apps || []).length) {
    caixa.append(elemento("h3", { class: "subsecao-titulo", texto: "O ícone de cada jogo" }));
    caixa.append(elemento("p", { class: "nota-secao",
      texto: `${JOGOS.total_apps ?? JOGOS.apps.length} jogos com .desktop nesta `
           + "máquina. A capa acima decide se ele aparece no lançador; aqui se "
           + "escolhe o desenho com que ele aparece." }));
    caixa.append(gradeDeApps(JOGOS.apps, JOGOS_BUSCA, carregarJogos));
  }
  return caixa;
}

function montarEscolhaDeJogo(j) {
  const painel = elemento("div", { class: "escolha-jogo" });
  painel.append(elemento("h3", { class: "titulo-cartao", texto: j.nome }));

  /* O ESTADO ATUAL EM UMA FRASE, ANTES DAS ESCOLHAS. Sem isto o painel abre com
   * três botões e nenhuma dica de onde aquele jogo está agora. */
  let onde = j.cartao ? "Tem cartão no lançador." : "Sem cartão no lançador.";
  if (j.gasto) {
    onde = `Arquivos apagados em ${j.apagado_em || "uma passagem anterior"}. `
         + "A linha está gasta: não apaga de novo, nem se você reinstalar.";
  } else if (j.acao === "apagar") {
    onde = "Marcado para apagar — os arquivos saem na próxima passagem.";
  } else if (j.acao === "esconder") {
    onde = "Fora do lançador a pedido. Os arquivos continuam no disco.";
  }
  painel.append(elemento("p", { class: "frase", texto: onde }));
  if (j.motivo) painel.append(elemento("p", { class: "frase nota-secao", texto: j.motivo }));

  const motivo = elemento("input", {
    type: "text", class: "motivo-jogo", "data-foco": "motivo-jogo",
    placeholder: "Por quê? (fica escrito no mapa, ao lado da linha)",
    "aria-label": "Motivo",
  });
  painel.append(motivo);

  const linha = elemento("div", { class: "linha-botoes" });

  if (j.acao !== "esconder") {
    linha.append(elemento("button", {
      type: "button", class: "btn",
      texto: "Tirar do lançador",
      title: "Some da lista de aplicativos. Nenhum arquivo é tocado.",
      onclick: () => definirJogo(j.appid, "esconder", motivo.value),
    }));
  }

  /* O "apagar" só aparece quando há o que apagar. Numa linha já gasta ele seria
   * um botão que promete uma ação que o script vai recusar — e um botão que não
   * faz nada é pior que um botão a menos. */
  if (!j.gasto && j.no_disco) {
    linha.append(elemento("button", {
      type: "button", class: "btn btn-perigo",
      texto: "Apagar os arquivos",
      title: "Tira do lançador E remove a pasta do jogo e o manifesto, uma vez só.",
      onclick: async () => {
        /* A PERGUNTA É AQUI, e não só no botão que executa. Gravar no mapa se
         * desfaz com um clique, mas ela precisa saber, ANTES de escolher, que
         * esta é a opção que leva gigabytes embora. */
        const sim = await perguntar({
          titulo: `Apagar os arquivos de ${j.nome}?`,
          texto: "A pasta do jogo e o manifesto saem do disco na próxima vez que "
               + "você arrumar os jogos, com a Steam fechada. Dispara uma vez só: "
               + "se você reinstalar depois, nada é apagado.",
          comando: `${j.appid}:apagar:  →  jogos-fora.map`,
          ok: "Marcar para apagar", perigo: true,
        });
        if (sim) definirJogo(j.appid, "apagar", motivo.value);
      },
    }));
  }

  if (j.acao || j.gasto) {
    linha.append(elemento("button", {
      type: "button", class: "btn",
      texto: j.gasto ? "Tirar a linha gasta" : "Voltar ao normal",
      title: "Apaga a linha do jogos-fora.map. O cartão volta na próxima passagem.",
      onclick: () => definirJogo(j.appid, "", "", true),
    }));
  }

  painel.append(linha);
  painel.append(elemento("p", { class: "frase nota-secao",
    texto: "Escolher grava no mapa. Quem age é \u201cArrumar os jogos no lançador\u201d." }));
  return painel;
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

/* ===========================================================================
 * O LADO DE CADA IMAGEM — DIA, NOITE, OU O QUE A MEDIÇÃO ACHAR
 * ===========================================================================
 * O comando é `meow wallpaper lado <arquivo> dia|noite|auto`, e ele grava a
 * escolha num registro de duas colunas que o `_resolver_grupo` consulta ANTES
 * de comparar luminância. `auto` apaga a linha: o registro só guarda
 * discordância, e ausência é o padrão.
 *
 * A PÁGINA NÃO MOVE ARQUIVO, E ISTO NÃO É ZELO — é a regra da casa. Mover a
 * imagem daqui seria uma segunda implementação do que o `wallpaper.sh` faz, com
 * as guardas dele de fora (o link duro entre `ativos/` e `ativos-<lado>/`, o
 * aviso de grupo com menos de duas imagens, o banimento que sobrevive). O botão
 * dispara o comando, e é só isso que ele faz.
 *
 * SÃO TRÊS AÇÕES, E NÃO UMA COM PARÂMETRO, e a razão é do servidor: o `argv`
 * dele troca UM `@ARG@` por UM elemento da lista. Um id só não teria por onde
 * levar o segundo argumento — dois tokens colados numa string chegariam ao
 * `subprocess` como um argumento só, e o `cmd_lado` receberia "arquivo dia"
 * como nome de arquivo. Então `wallpaper_dia`, `wallpaper_noite` e
 * `wallpaper_lado_auto`, medidos no `/api/esquema` de 06/09/2026, as três
 * `oculta` e as três aceitando ensaio.
 *
 * O DESFAZER SÓ APARECE ONDE HÁ O QUE DESFAZER — quando o item traz o lado
 * escrito. É a mesma disciplina do "Apagar os arquivos" na tela de jogos, que
 * não nasce numa linha já gasta: um botão que promete uma ação que o script vai
 * recusar é pior que um botão a menos.
 *
 * MEDIDO E RELATADO: o `/api/previas?tipo=parede` de hoje devolve, por item,
 * `id · rotulo · grupo · pronta · origem · url · banir` — e NENHUM campo com o
 * lado escrito (conferido nos 46 itens de `ativos`, todos com o mesmo conjunto
 * de chaves). Ler o `lado.tsv` daqui seria a página inventando uma leitura de
 * arquivo do repositório, que é exatamente o que ela não faz; então o desfazer
 * fica esperando o campo, e ele se acende sozinho no dia em que o servidor o
 * mandar — sem uma linha nova aqui. */
function botoesDeLado(imagem) {
  /* PELO CAMINHO CANÔNICO, e não pelo que está sendo mostrado: `ativos-dia/` e
   * `ativos-noite/` são LINK DURO do mesmo arquivo, e agir pelo link mexeria só
   * no link. É o mesmo `i.banir` que o "Tirar" ao lado já usa. */
  const alvo = imagem.banir || imagem.origem || imagem.rotulo;
  const botoes = [
    ["wallpaper_dia", "Dia",
     "Ela passa a girar só de dia, mesmo que a medição a ache escura."],
    ["wallpaper_noite", "Noite",
     "Ela passa a girar só de noite, mesmo que a medição a ache clara."],
  ];
  /* O DESFAZER SÓ APARECE QUANDO HÁ O QUE DESFAZER. `lado` vazio é o caso comum
   * — a medição decide —, e ali o botão prometeria tirar uma escolha que não
   * existe. Ele chega desde 07/09/2026: o `previas()` passou a copiar todo campo
   * que a fonte acrescenta, em vez de só o `banir`. */
  if (imagem.lado) {
    botoes.push(["wallpaper_lado_auto", "Medir",
      `Hoje está escrita como ${rotuloDeValor(imagem.lado)}. Tira a escolha e `
      + "devolve a imagem à luminância medida."]);
  }
  return botoes.map(([id, rotulo, ajuda]) => elemento("button", {
    type: "button", class: "btn btn-mini",
    texto: rotulo,
    title: `${ajuda} (meow wallpaper lado ${imagem.rotulo} `
         + `${id === "wallpaper_lado_auto" ? "auto" : rotulo.toLowerCase()})`,
    onclick: () => rodarNaGaleria(id, alvo),
  }));
}

function montarGaleria() {
  const caixa = elemento("div");
  const abas = elemento("div", { class: "abas" });
  for (const g of GRUPOS_PAREDE) {
    /* A CONTAGEM VEM NA PRIMEIRA RESPOSTA, para todas as abas de uma vez — o
     * servidor passou a mandar `contagens`. Antes o número só aparecia depois
     * de abrir a sub-aba, então a galeria abria com quatro abas mudas e uma
     * numerada. */
    const cheia = PREVIAS.get("parede/" + ABA_GALERIA);
    const quantos = cheia && cheia.contagens ? cheia.contagens[g.id] : undefined;
    const lista = PREVIAS.get("parede/" + g.id);
    abas.append(elemento("button", {
      type: "button", "aria-pressed": String(g.id === ABA_GALERIA),
      onclick: () => { ABA_GALERIA = g.id; LIMITE_GALERIA = 60; render(); },
    }, [
      elemento("span", { texto: g.rotulo }),
      elemento("span", { class: "conta",
        texto: quantos !== undefined ? ` ${quantos}`
             : (lista ? ` ${lista.itens.length}` : "") }),
    ]));
  }
  caixa.append(abas);

  /* O BOTÃO DE ACRESCENTAR FALTAVA NA GALERIA — 06/09/2026.
   *   Pergunta dela: *"como adicionamos os wallpapers pelo html e eles vão pra
   *   pasta correta"*. A resposta era "não adiciona": a aba mais visual da
   *   página, com 46 fotos na tela, era a única onde não havia como pôr uma
   *   foto. Não é capacidade nova — o `ACERVOS["parede"]` do servidor já
   *   respondia; faltava a ligação, e a ligação é esta linha.
   *
   *   Quem decide o lado (dia ou noite) é a luminância, e o servidor mede na
   *   hora e diz na torrada. Discordar da medição é o par de botões de cada
   *   ficha, abaixo. */
  caixa.append(botaoAcervo("parede", async () => {
    for (const g of GRUPOS_PAREDE) PREVIAS.delete("parede/" + g.id);
    render();
  }));

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
    /* BANIR APARECE EM TODA ABA QUE TENHA O CAMINHO CANÔNICO — não só em "No
     * carrossel". A validação mediu: "em Noite (25 fotos) e Dia (21 fotos)
     * nenhuma ficha tem ação… ela vê a foto clara demais na aba da noite e
     * precisa ir procurá-la pelo nome em No carrossel para poder recusar".
     * O servidor já manda o `banir` de cada item justamente para isto. */
    if (banidos) {
      acoes.append(elemento("button", {
        type: "button", class: "btn",
        texto: "Devolver",
        title: `meow wallpaper desbanir ${i.rotulo}`,
        onclick: () => rodarNaGaleria("wallpaper_desbanir", i.rotulo),
      }));
    } else if (i.banir) {
      /* DIA · NOITE · TIRAR — pedido dela, literal: *"quando eu colocar o mouse
       * em cima da imagem temos que ter as opções de Dia e a opção Noite, não
       * apenas a Tirar"*.
       *
       *   Hoje quem separa `ativos-dia/` de `ativos-noite/` é a LUMINÂNCIA da
       *   imagem, medida contra `WALLPAPER_LIMIAR_LUZ`. A medição acerta na
       *   maioria e erra em alguns — uma foto clara que ela quer de madrugada,
       *   um gráfico escuro que ela quer de dia — e não havia nenhuma porta para
       *   discordar. Estes botões são a porta: decisão escrita vence a
       *   heurística, a heurística continua sendo o padrão. */
      acoes.append(...botoesDeLado(i));
      acoes.append(elemento("button", {
        type: "button", class: "btn btn-perigo",
        texto: "Tirar",
        /* BANE PELO CAMINHO CANÔNICO (`i.banir`), e não pelo que está sendo
         * mostrado: `ativos-noite/` e `ativos-dia/` são LINK DURO do mesmo
         * arquivo, e banir pelo link moveria só o link — meio banimento, e
         * mudo. O servidor passou a devolver esse campo justamente por isso. */
        title: `Sai do carrossel e vai para banidos/. Nunca é apagada. (meow wallpaper banir ${i.rotulo})`,
        onclick: () => rodarNaGaleria("wallpaper_banir", i.banir || i.origem),
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

/* Roda uma ação `oculta` a partir da tela a que ela pertence, e recarrega essa
 * tela quando o trabalho termina. Generaliza o que o `rodarNaGaleria` fazia só
 * para as imagens: a lista muda por baixo enquanto o script corre, e mostrar por
 * um minuto um estado que já não existe é como se aprende a não confiar na
 * página. */
async function rodarDaSecao(acaoId, invalidar) {
  const acao = ESQUEMA.acoes.find((a) => a.id === acaoId);
  if (!acao) return;
  const seco = ensaiando();
  if (acao.confirma && !(await confirmar(acao, "", seco))) return;
  const r = await api("/api/rodar", {
    method: "POST",
    body: JSON.stringify({ acao: acaoId, argumento: "", seco, confirmado: true }),
  });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirGaveta(r);
  const esperar = setInterval(() => {
    if (TRABALHO) return;
    clearInterval(esperar);
    invalidar();
    render();
  }, 700);
}

async function rodarNaGaleria(acaoId, argumento) {
  const acao = ESQUEMA.acoes.find((a) => a.id === acaoId);
  /* A RECUSA DEIXOU DE SER MUDA — 06/09/2026. Este `return` calado é a forma
   * como 46 botões "Banir" e 255 "Devolver" ficaram sem chamar nada até
   * 01/09/2026: o id não existia no `ACOES`, e a página não dizia uma palavra.
   * Ela clicava e concluía que a página mente. Um botão desenhado sobre uma
   * ação que não existe é defeito nosso, e agora ele aparece na tela em vez de
   * aparecer só no console de quem estiver olhando. */
  if (!acao) { torrada(`Ação desconhecida: ${acaoId}`, "erro"); return; }
  const r = await api("/api/rodar", {
    method: "POST",
    body: JSON.stringify({ acao: acaoId, argumento, seco: ensaiando() }),
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
    "data-chave": item.chave,
  });

  /* O TÍTULO DO CARTÃO É UMA FRASE, não o identificador.
   * `LOGO_ROTACAO` diz o que a chave se chama; "O gato do painel troca sozinho"
   * diz o que ela FAZ — e é isso que ela precisa ler para escolher. O
   * identificador continua existindo, agora dentro da dica, porque é como a
   * chave se chama no arquivo e é por ele que ela procura lá. */
  const titulo = tituloDoCartao(item);
  if (titulo) cartao.append(elemento("h3", { class: "titulo-cartao", texto: titulo }));
  cartao.append(...porqueEDica(item));

  /* QUEM MANDA HOJE, DITO NO CARTÃO — 02/09/2026.
   *   Dois achados da validação, e o mesmo defeito nos dois: uma chave que a
   *   página oferece com um controle vivo, mas que OUTRA chave está anulando.
   *     · `LOGO_ROTACAO` é um interruptor morto enquanto `LOGO_MODO` estiver
   *       preenchido (scripts/logo.sh:113-119). Ela marca "Sim", salva, e não
   *       acontece nada.
   *     · `LOGO` promete "qual gato fica no ar", mas em `LOGO_MODO="hora"` quem
   *       escolhe é `LOGO_DIA`/`LOGO_NOITE` — o gato escolhido é desfeito pelo
   *       relógio na virada seguinte.
   *   O `bin/meow logo` já diz isso em voz alta na última linha da saída dele;
   *   faltava a página dizer. É a mesma disciplina do `meow logo girar`, que
   *   anuncia não ter efeito em vez de fingir que girou.
   *
   *   A regra é derivada e mora no servidor (`dominada_por`), não aqui: quem
   *   sabe qual chave vence qual é quem lê o conf. */
  if (item.chave === "FLAVOR" || item.chave === "ACCENT") {
    const aviso = avisoDeCombinacao();
    if (aviso) cartao.append(aviso);
  }
  /* O QUE ESTÁ VALENDO, quando não é o arquivo que manda. O cartão mostrava
   * 3500 (o padrão de fábrica) com a máquina em 4700 — o número do applet. */
  if (item.valendo_agora && item.valendo_agora !== valorEmVigor(item)) {
    cartao.append(elemento("p", { class: "frase dominada" }, [
      elemento("b", { texto: `Na máquina agora: ${rotuloDeValor(item.valendo_agora)}. ` }),
      elemento("span", { texto: "Quem guarda esse valor é o controle da barra. Salvar faz este ajuste vencer." }),
    ]));
  }
  if (item.dominada_por) {
    const d = item.dominada_por;
    cartao.append(elemento("p", { class: "frase dominada" }, [
      /* CITA O CARTÃO, NÃO A VARIÁVEL. "LOGO_MODO=\"hora\" está mandando" manda
       * procurar um nome que a tela não usa em lugar nenhum; o rótulo do cartão
       * dominante é o mesmo texto que ela acabou de ler no menu. */
      elemento("b", { texto: `Quem manda é «${d.titulo || d.chave}», em ${rotuloDeValor(d.valor)}. ` }),
      elemento("span", { texto: d.porque || "" }),
    ]));
  }
  cartao.append(montarControle(item, cartao));

  if (item.frase) {
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

  /* O "▸ Por quê" NÃO É MAIS DESENHADO AQUI — 06/09/2026. O comentário inteiro
   * do `meow.conf.exemplo` não se perdeu: ele é o `.motivo` dentro da `.dica`,
   * que o `?` ao lado do título abre (ver `porqueEDica`, acima). Era a sexta
   * camada de um cartão de seis; hoje são três. */
  return cartao;
}

/* ===========================================================================
 * O `?` E A DICA — a outra metade da folha de estilo
 * ===========================================================================
 * Pedido dela, literal, com a tela na frente: *"o tooltip fica em `?` ao lado
 * direito do nome da seção"* — e, apontando o rodapé de um cartão, *"essa parte
 * que selecionei tem que sumir também… isso pra todos"*.
 *
 * O CARTÃO PASSOU DE SEIS CAMADAS PARA TRÊS: título, controle, explicação. As
 * três que saíram (o nome da chave, o padrão de fábrica e o "▸ Por quê") não
 * foram apagadas — elas NASCEM aqui dentro, a um clique. `chave` e `fabrica` são
 * criação, e não mudança de casa: o que havia antes era `.cartao-topo` com um
 * `<code>` solto e um `.padrao` que só aparecia quando o valor divergia. Agora
 * os dois aparecem SEMPRE, porque quem abriu a dica está justamente procurando
 * por eles.
 *
 * AS CINCO TRAVAS DO CONTRATO COM O `estilo.css`, todas medidas do outro lado:
 *   1. a `.dica` é o irmão IMEDIATO do `button.porque` — o hover é
 *      `button.porque:hover + .dica`, e um nó entre os dois apaga o balão;
 *   2. os dois são filhos DIRETOS do `.cartao`, que é quem os posiciona
 *      (`.cartao > .dica`, ancorada na linha 1 da grade);
 *   3. o `?` sai em TODO cartão, mesmo sem comentário: `.motivo` é opcional,
 *      `.chave` e `.fabrica` não;
 *   4. o texto do motivo entra CRU (o `white-space: pre-wrap` do CSS preserva as
 *      quebras que o autor do `meow.conf.exemplo` escreveu), sem o `# ` que
 *      abre cada linha de comentário no arquivo;
 *   5. a `.marca-essencial` é opcional e vem logo depois da `.chave`.
 *
 * O `hidden` E O `aria-expanded` SÃO DAQUI, O HOVER É DO CSS.
 *   A folha de estilo já abre o balão no `:hover` do gatilho e no `:focus-visible`
 *   dele, com `!important`, porque o atributo `hidden` traz um
 *   `display: none !important` da folha do navegador. O que ela não pode fazer é
 *   o CLIQUE (que tem de ficar aberto depois que o dedo sai) e o estado
 *   ANUNCIADO: `hidden` mantém o balão fora da árvore de acessibilidade mesmo
 *   quando o CSS o desenha — quem usa leitor de tela chegaria ao `?` e não
 *   alcançaria o texto. Por isso o `hidden` cai TAMBÉM no foco.
 *
 * POR QUE O FOCO SÓ ABRE QUANDO É TECLADO (`:focus-visible`)
 *   Um clique de rato dá foco ANTES de disparar o `click`. Se o `focus` abrisse
 *   sempre, o `click` seguinte encontraria o balão aberto e o fecharia: o botão
 *   ficaria inerte para quem usa rato, que é a maioria dos cliques desta página.
 *   `:focus-visible` é exatamente a pergunta "este foco veio do teclado?", e é o
 *   mesmo critério que a folha de estilo já usa para o hover do teclado. */
function porqueEDica(item) {
  /* O id sai da CHAVE, e não de um contador. Um contador cresceria a cada
   * `render()` — e esta página se redesenha a cada clique — deixando o
   * `aria-controls` apontando para números que já não existem em nenhum lugar.
   * A chave é única por construção (cada item aparece em um grupo só) e é
   * estável entre redesenhos, que é o que um id precisa ser. */
  const idDica = "dica-" + item.chave;
  const gatilho = elemento("button", {
    type: "button", class: "porque", texto: "?",
    "aria-expanded": "false", "aria-controls": idDica,
    "aria-label": `O que é ${tituloDoCartao(item) || item.chave}`,
  });
  const dica = elemento("div", { class: "dica", id: idDica, role: "tooltip", hidden: true });

  if (item.ajuda) {
    /* O `# ` que abre cada linha de comentário é sintaxe do arquivo, não texto.
     * O `.trim()` tira a linha em branco que quase todo bloco deixa no fim. */
    dica.append(elemento("p", { class: "motivo", texto: item.ajuda.replace(/^# ?/gm, "").trim() }));
  }
  dica.append(elemento("code", { class: "chave", texto: item.chave }));
  if (item.essencial) {
    dica.append(elemento("span", { class: "marca-essencial", title: "Chave essencial", texto: "•" }));
  }
  dica.append(elemento("span", {
    class: "fabrica",
    texto: item.padrao === "" ? "De fábrica: nada" : `De fábrica: ${rotuloDeValor(item.padrao)}`,
    title: "O valor que o projeto traz de fábrica.",
  }));

  const mostrar = (aberta) => {
    dica.hidden = !aberta;
    gatilho.setAttribute("aria-expanded", String(aberta));
  };
  gatilho.addEventListener("click", () => mostrar(dica.hidden));
  gatilho.addEventListener("focus", () => {
    /* `matches` pode não conhecer `:focus-visible` num navegador antigo, e uma
     * exceção aqui apagaria o cartão inteiro. Sem ele, o teclado continua tendo
     * o clique (Enter e Espaço disparam `click` num `<button>`). */
    try { if (gatilho.matches(":focus-visible")) mostrar(true); } catch (e) { /* idem */ }
  });
  gatilho.addEventListener("blur", () => mostrar(false));
  gatilho.addEventListener("keydown", (ev) => {
    if (ev.key !== "Escape" || dica.hidden) return;
    /* O `stopPropagation` impede que o mesmo Esc que fecha a dica atravesse até
     * o atalho global e limpe a busca — dois desfazeres num toque só. */
    ev.stopPropagation();
    mostrar(false);
  });
  return [gatilho, dica];
}

/* --- as ações ------------------------------------------------------------- */
function montarAcao(acao) {
  const bloco = elemento("article", { class: "acao" });
  bloco.append(elemento("h3", { texto: acao.rotulo }));
  bloco.append(elemento("p", { texto: acao.ajuda }));

  let escolha = null;
  if (acao.opcoes && acao.opcoes.length) {
    const sel = elemento("select", { "aria-label": `Valor para ${acao.rotulo}` });
    for (const o of acao.opcoes) {
      sel.append(elemento("option", { value: o, texto: rotuloDeValor(o) }));
    }
    /* O SELETOR NASCE NO ESTADO DA MÁQUINA, e não no primeiro item da lista.
     *   A auditoria mediu: o "Claro / escuro / automático" abria em "claro"
     *   com a máquina em `MODO="escuro"` — o controle mostrava o oposto do
     *   que estava valendo, e um clique em Rodar sem tocar no seletor
     *   TROCARIA o tema dela achando que não estava mudando nada.
     *   A ligação entre a ação e a chave é DERIVADA: se a lista de opções da
     *   ação for igual à de alguma chave do conf, aquela chave é o estado
     *   dela. Vale para `tema_modo` hoje e para a próxima ação que nascer
     *   assim, sem lista de nomes em lugar nenhum. */
    /* COMPARA COMO CONJUNTO, não como sequência: a ação lista
     * `claro, escuro, auto` e a chave `MODO` lista `escuro, claro, auto` — o
     * mesmo conjunto em outra ordem. Exigir a ordem fazia a ligação nunca
     * acontecer, e o seletor continuava nascendo em "claro". */
    const mesmoConjunto = (a, b) =>
      a && b && a.length === b.length && a.every((o) => b.includes(o));
    const chaveDoEstado = (ESQUEMA.chaves || []).find(
      (k) => mesmoConjunto(k.opcoes, acao.opcoes));
    if (chaveDoEstado) {
      const atual = valorEmVigor(chaveDoEstado);
      if (atual && acao.opcoes.includes(atual)) sel.value = atual;
      sel.title = `Agora: ${rotuloDeValor(atual)} (${chaveDoEstado.chave})`;
    }
    bloco.append(sel);
    escolha = sel;
  }

  const rodape = elemento("div", { class: "rodape" });
  if (acao.sudo) rodape.append(elemento("span", { class: "pastilha p-sudo", texto: "pede senha" }));
  if (acao.destrutivo) rodape.append(elemento("span", { class: "pastilha p-perigo", texto: "desfaz o que foi feito" }));
  /* `rede` é DECLARADA pela ação, nunca adivinhada do texto dela. A primeira
   * versão fazia `/rede|baixa/i.test(acao.ajuda)` e o resultado apareceu na
   * tela em 01/09/2026: o cartão "Conferir (doctor)" — cuja ajuda diz, com
   * todas as letras, que ele "nunca usa sudo e nunca baixa nada" — ganhou uma
   * pastilha "usa rede". Um marcador que lê a prosa acaba dizendo o contrário
   * dela; quem sabe se a ação toca a rede é quem a escreveu. */
  if (acao.rede) rodape.append(elemento("span", { class: "pastilha p-rede", texto: "baixa da internet" }));
  /* O SELO "PODE ENSAIAR" SAIU EM 06/09/2026, e a razão é dela: *"o botão Pode
   * ensaiar não faz sentido se temos o executar ali em todas as páginas — é pq
   * o user quer arrumar só aquilo"*. O interruptor de ensaio é UM, global, e
   * fica no alto da tela: aceso, cada `Executar` já ensaia; apagado, executa de
   * verdade. Repetir por cartão o que o interruptor governa era trinta e quatro
   * etiquetas amarelas dizendo a mesma coisa numa tela de oito ações — ruído
   * que empurrava para baixo as duas pastilhas que de fato distinguem uma ação
   * da vizinha (pede senha, desfaz o que foi feito).
   *
   * O `acao.seco` NÃO MORREU: ele continua decidindo, no `rodar()`, se o
   * interruptor tem efeito sobre ESTA ação (`ensaiando() && acao.seco`) e se a
   * caixa de confirmação promete "Rodar em seco" ou "Rodar de verdade". O que
   * saiu foi só a etiqueta; a regra ficou. A regra `.p-seco` saiu do
   * `estilo.css` na mesma passagem. */

  rodape.append(elemento("button", {
    type: "button",
    class: "btn " + (acao.destrutivo ? "btn-perigo" : "btn-accent"),
    texto: "Executar",
    onclick: () => rodar(acao, escolha ? escolha.value : ""),
  }));
  bloco.append(rodape);
  bloco.append(elemento("code", { class: "cmd", texto: acao.argv, title: acao.argv }));
  return bloco;
}

async function rodar(acao, argumento) {
  const seco = ensaiando() && acao.seco;
  if (acao.confirma || acao.sudo || acao.destrutivo) {
    const ok = await confirmar(acao, argumento, seco);
    if (!ok) return;
  }
  let r = await api("/api/rodar", {
    method: "POST",
    body: JSON.stringify({ acao: acao.id, argumento, seco }),
  });
  /* O SERVIDOR PASSOU A TRANCAR AS AÇÕES QUE ESCREVEM — 02/09/2026.
   *   Ele devolve 409 com `precisa_confirmar: true` e os fatos da ação
   *   (o que escreve, se usa sudo, se aceita seco) em vez de rodar. Isso é uma
   *   segunda tranca, depois da que a página já faz: se ela chegar aqui, é
   *   porque a primeira não perguntou — e sem este tratamento as cinco ações
   *   destrutivas simplesmente parariam de funcionar, com um erro seco na tela.
   *   Aqui a recusa vira a pergunta que faltou, e o `confirmado` só é enviado
   *   depois de ela responder. */
  if (r && r.precisa_confirmar) {
    const ok = await confirmar(acao, argumento, seco);
    if (!ok) return;
    r = await api("/api/rodar", {
      method: "POST",
      body: JSON.stringify({ acao: acao.id, argumento, seco, confirmado: true }),
    });
  }
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirGaveta(r);
}

/* UMA CAIXA DE PERGUNTA, E NÃO DUAS — 02/09/2026
 *   A seção "Jogos da Steam" precisava perguntar antes de marcar um jogo para
 *   apagar, e a saída rápida seria `window.confirm`. Ela abriria uma caixa do
 *   NAVEGADOR no meio de uma página inteira em Catppuccin, com o botão em
 *   inglês e sem o traço de perigo — e, pior, dizendo a mesma coisa de um jeito
 *   diferente de todas as outras confirmações da página. O `<dialog>` já existia
 *   e já sabia mostrar "isto usa sudo" e "isto é destrutivo"; o que faltava era
 *   ele aceitar uma pergunta que não fosse uma ação do servidor. */
function perguntar({ titulo, texto, comando = "", ok = "Sim", sudo = false,
                     perigo = false, neutro = false }) {
  const dlg = $("#confirmar");
  $("#confirmar-titulo").textContent = titulo;
  $("#confirmar-texto").textContent = texto;
  $("#confirmar-sudo").hidden = !sudo;
  $("#confirmar-comando").textContent = comando;
  /* Esconder o <code> deixaria o <p> que o embrulha ocupando espaço vazio — o
   * que vira um buraco no meio da caixa quando a pergunta não tem comando. */
  $("#confirmar-comando").closest("p").hidden = !comando;
  $("#confirmar-ok").textContent = ok;
  /* Três pesos, e o do meio existe: rodar em seco não é compromisso nenhum, e
   * pintar aquele botão com a cor de acento o faria parecer a ação principal. */
  $("#confirmar-ok").className =
    "btn " + (neutro ? "" : perigo ? "btn-perigo" : "btn-accent");
  dlg.showModal();
  return new Promise((resolve) => {
    dlg.addEventListener("close", () => resolve(dlg.returnValue === "sim"), { once: true });
  });
}

function confirmar(acao, argumento, seco) {
  return perguntar({
    titulo: acao.rotulo,
    texto: acao.ajuda,
    comando: (seco ? "MEOW_DRY_RUN=1 " : "") + acao.argv.replace("@ARG@", argumento),
    ok: seco ? "Rodar em seco" : "Rodar de verdade",
    sudo: acao.sudo,
    perigo: acao.destrutivo,
    neutro: seco,
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
/* A frase de uma linha de cada seção. Vem do servidor (`DESCRICAO_SECAO`), com
 * o NOME da seção como chave — quem batiza as seções é o `meow.conf.exemplo`, e
 * um segundo identificador aqui seria a lista que discorda da outra no dia em
 * que alguém renomear um título lá. Seção sem frase simplesmente não mostra
 * nenhuma; não há texto de reserva, porque frase genérica é pior que silêncio. */
function descricaoDe(g) {
  const d = (ESQUEMA && ESQUEMA.descricoes) || {};
  if (typeof g === "string") return d[g] || "";
  /* O BLOCO DESEMPATA. "Papel de parede" existe em Ajustar (o carrossel, a
   * noite) e em Fazer (avançar, banir, semear): mesmo nome, trabalhos
   * diferentes, e uma frase só serviria mal aos dois. A chave `bloco/nome` vem
   * primeiro; sem ela, cai no nome, que é o caso da grande maioria. */
  /* O `|| d[g.secaoPai]` saiu em 06/09/2026: ele existia porque as subabas não
   * tinham frase própria e herdavam a do pai — três abas abriam com a mesma
   * linha. Agora há uma frase por assunto, e a herança viraria ruído. */
  return d[chaveDeAba(g)] || d[g.nome] || "";
}

function assuntoDe(g) {
  /* O assunto de um grupo de chaves é o TÍTULO DE SEÇÃO do meow.conf.exemplo
   * (`secaoPai`); o de uma galeria e o de um grupo de ações é declarado. */
  if (g.tipo === "chaves") return g.secaoPai || g.nome;
  return g.assunto || g.nome;
}

/* A ORDEM DOS ASSUNTOS VEM DO ARQUIVO, e não de uma lista escrita aqui.
 * Primeiro os assuntos na ordem em que suas seções aparecem no
 * `meow.conf.exemplo`; depois os que não têm chave nenhuma — hoje "Instalar e
 * conferir" e "Ver o estado", as duas páginas de verbo que sobraram depois da
 * unificação. Renomear uma seção no arquivo reordena o menu sozinho. */
function assuntosEmOrdem() {
  const ordem = [];
  for (const g of GRUPOS) {
    if (g.tipo !== "chaves") continue;
    const a = assuntoDe(g);
    if (!ordem.includes(a)) ordem.push(a);
  }
  for (const g of GRUPOS) {
    if (g.tipo === "home") continue;
    const a = assuntoDe(g);
    if (!ordem.includes(a)) ordem.push(a);
  }
  return ordem;
}

/* ===========================================================================
 * O BLOCO DE UM ASSUNTO — DECISÃO ESCRITA, E NÃO MAIS UMA ADIVINHAÇÃO
 * ===========================================================================
 * São DOIS blocos, e os nomes são dela: *"No menu, Assuntos vira Tópicos, A
 * Máquina vira Sistema. E aqui dentro temos Manutenção, Instalação (antigo
 * instalar e conferir), Idempotência (antigo atualizar o sistema)"*.
 *
 * A REGRA ANTIGA ERRAVA, E A MEDIÇÃO MOSTROU ONDE. Esta função perguntava
 * "este assunto tem chave do `meow.conf`?" — sim virava Assuntos, não virava
 * máquina. A pergunta funcionava por coincidência, e a coincidência acabou: a
 * **Manutenção tem nove chaves** e mesmo assim é Sistema, porque o que ela
 * ajusta não é a aparência da tela — é o que o computador faz sozinho enquanto
 * ninguém olha. Heurística que erra num caso é heurística errada.
 *
 * A tabela mora no `servidor.py` (`BLOCO_DA_SECAO`) e chega em `ESQUEMA.blocos`,
 * porque é lá que as seções são NOMEADAS: uma segunda lista aqui seria a que
 * discorda da primeira no dia em que alguém renomear um título no
 * `meow.conf.exemplo`. Ausente da tabela = "Tópicos", que é onde a esmagadora
 * maioria mora — assunto novo nasce no lugar certo sem uma linha a mais.
 *
 * O `bloco` declarado na AÇÃO continua valendo como segunda porta: é por ele
 * que as três `sistema_*` já se declaravam, e ele cobre um grupo de ação que
 * nasça sem entrada na tabela. */
function blocoDoAssunto(assunto) {
  const tabela = (ESQUEMA && ESQUEMA.blocos) || {};
  if (tabela[assunto]) return tabela[assunto];
  for (const g of GRUPOS) {
    if (assuntoDe(g) !== assunto) continue;
    for (const a of g.itens || []) if (a.bloco) return a.bloco;
  }
  return "Tópicos";
}

function montarTrilho() {
  const trilho = $("#trilho");
  /* O FOCO SOBREVIVE À RECONSTRUÇÃO: guardar o nome e devolver o foco ao botão
   * equivalente custa estas três linhas, e sem elas o Tab depois de um Enter no
   * menu voltava para o começo da página. */
  const focado = document.activeElement?.dataset?.grupo;
  trilho.replaceChildren();

  /* UM ITEM POR ASSUNTO, E NENHUM NÍVEL — 06/09/2026.
   *   O menu tinha 22 itens em três blocos de verbo (Escolher · Configurar ·
   *   Executar) e dois níveis, e o mesmo assunto aparecia em dois ou três
   *   deles: "Papéis de parede" para olhar, "Papel de parede" para ajustar,
   *   "Papel de parede" para rodar. Os ícones tinham três páginas.
   *
   *   Agora o assunto é a página, e ela carrega o que existir sobre ele: a
   *   galeria, os ajustes e as ações. Sobraram doze itens e um nível.
   *
   *   E DOIS BLOCOS, com os nomes dela — 06/09/2026: *"No menu, Assuntos vira
   *   Tópicos, A Máquina vira Sistema. E aqui dentro temos Manutenção,
   *   Instalação, Idempotência"*. Chegou a haver um terceiro ("A nova versão"),
   *   e ele voltou para dentro de Sistema como `Idempotência`: atualizar o
   *   Pop!_OS é uma coisa que se faz À MÁQUINA, e a página existe justamente
   *   para conferir se o MeowSystem sobrevive a essa atualização.
   *
   *   O bloco NÃO é uma lista escrita aqui, e desde 06/09/2026 também não é uma
   *   adivinhação: ele vem da tabela `BLOCO_DA_SECAO` do servidor, que chega em
   *   `ESQUEMA.blocos` (ver `blocoDoAssunto`). Um lugar só, que é a regra deste
   *   projeto desde o primeiro dia. */
  for (const g of GRUPOS) if (g.tipo === "home") trilho.append(botaoTrilho(g));
  let bloco = null;
  for (const assunto of assuntosEmOrdem()) {
    const nome = blocoDoAssunto(assunto);
    if (nome !== bloco) {
      bloco = nome;
      trilho.append(rotuloDeBloco(nome));
    }
    trilho.append(botaoDeAssunto(assunto));
  }
  for (const item of itensExternos()) trilho.append(item);
  if (focado) {
    const volta = trilho.querySelector(`[data-grupo="${CSS.escape(focado)}"]`);
    if (volta) volta.focus();
  }
}

/* O ÚLTIMO ITEM DO MENU SAI DA MÁQUINA — 07/09/2026
 *   Pedido dela: "cria um botão tipo esse abaixo de sistema mas ao ser clicado
 *   ele leva pro meu README do GitHub".
 *
 *   É um `<a>` e não um `<button>`, e isso não é detalhe de gosto: o botão
 *   do meio abre em aba nova, o Ctrl+clique também, e o leitor de tela anuncia
 *   "link" em vez de "botão" — três comportamentos que ela teria de descobrir
 *   que não existem. O trilho estiliza pelo elemento e pela classe, então o
 *   `<a>` recebe as mesmas regras dos irmãos.
 *
 *   `rel="noopener noreferrer"`: a página que abre não ganha referência a esta,
 *   e a origem `127.0.0.1:<porta aleatória>` não vaza no cabeçalho. Não há
 *   segredo nessa URL, mas o padrão certo custa dois atributos.
 *
 *   O ENDEREÇO É FIXO, e é o do repositório dela. Ele não sai do `git remote`:
 *   a página é servida a partir do disco e o remoto pode ser um espelho, um
 *   clone de terceiro, ou nenhum. Um link de menu que aponta para lugar
 *   diferente conforme a máquina é pior que um link só. */
/* O ENDEREÇO VEM DO SERVIDOR, que o lê do `git remote` — nunca escrito aqui.
 * Escrito aqui ele não sobrevive ao commit: o hook troca o nome dela por
 * `[REDACTED]`, e o link vai para o ar apontando para uma URL morta. Foi o que
 * aconteceu no primeiro commit que tentou, em 07/09/2026. */
function itensExternos() {
  const repo = (ESQUEMA && ESQUEMA.repositorio) || "";
  /* Sem remoto não há para onde ir, e um item que não abre é pior que um item a
   * menos: ela clicaria uma vez, não aconteceria nada, e a partir dali o menu
   * inteiro seria suspeito. */
  if (!repo) return [];
  /* "O manual" entrou e saiu no mesmo dia, a pedido dela: apontava para o topo
   * do README, e o topo do README é a mesma coisa que esta página já é. Ficou o
   * que o painel não tem em lugar nenhum — a licença de cada acervo de terceiro
   * que este projeto veste. */
  const LINKS_EXTERNOS = [
    { nome: "Créditos", href: repo + "#créditos",
      titulo: "A paleta, os glifos e a base de ícones que este projeto usa — "
            + "com a licença de cada um, no GitHub" },
  ];
  return LINKS_EXTERNOS.map((l) => elemento("a", {
    class: "item-externo",
    href: l.href,
    target: "_blank",
    rel: "noopener noreferrer",
    title: l.titulo,
  }, [
    iconeDeMenu(l.nome, "externo"),
    elemento("span", { texto: l.nome }),
    elemento("span", { class: "seta-externa", "aria-hidden": "true", texto: "↗" }),
  ]));
}

/* O número ao lado do nome soma o que a página mostra: as imagens da galeria,
 * as chaves de cada bloco de ajuste e as ações. */
function botaoDeAssunto(assunto) {
  const meus = GRUPOS.filter((g) => assuntoDe(g) === assunto);
  const conta = meus.reduce((s, g) => s + (Number(contaDoGrupo(g)) || 0), 0);
  return elemento("button", {
    type: "button",
    "data-grupo": assunto,
    "aria-current": String(assunto === ABA),
    title: assunto,
    onclick: () => { $("#busca").value = ""; ABA = assunto; gravarHash(); render(); },
  }, [
    iconeDeMenu(assunto, "assunto"),
    elemento("span", { texto: encurtar(assunto) }),
    elemento("span", { class: "conta", texto: conta ? String(conta) : "" }),
  ]);
}

/* ===========================================================================
 * OS ÍCONES DO MENU — no lugar do traço
 * ===========================================================================
 * OS DESENHOS SÃO OS ARQUIVOS DO ACERVO, e não uma imitação deles.
 * A primeira versão destes ícones foi desenhada à mão na mesma gramática do
 * acervo — e era isso o que estava errado: um desenho parecido com o Arcticons
 * não é o Arcticons, e a barra e o dock da máquina mostram os de verdade a três
 * centímetros deste menu. Cada entrada abaixo é o conteúdo de um arquivo de
 * `assets/icones/arcticons/` (39 glifos, Arcticons, CC BY-SA 4.0), sem o
 * invólucro <svg> e sem os atributos que o invólucro daqui já dá.
 *
 * DUAS SÃO AUTORAIS, E ESTÃO MARCADAS: o acervo não tem gato. Os dois cartões de
 * gato usam as orelhas do mascote — três traços, mesma gramática (48/48, sem
 * preenchimento, ponta e junta redondas).
 *
 * A ESPESSURA É A ÚNICA COISA QUE MUDA. O acervo desenha para 48 px reais na
 * dock, com traço 1; aqui os glifos vivem a 17 px, e 1/48 × 17 dá 0,35 px —
 * some numa tela sem hidpi. 2.75 devolve 0,97 px, que é onde um traço fica
 * nítido sem engrossar o desenho até virar mancha.
 *
 * NENHUMA COR: `stroke="currentColor"`. O ícone herda a cor do item, então ele fica
 * cinza no repouso e accent no item aberto, sem uma regra a mais — a mesma
 * disciplina da paleta, aplicada a desenho. */
const ICONES_MENU = {
  /* OS DOIS BLOCOS DO MENU, com os nomes de 06/09/2026: `Assuntos` virou
   * `Tópicos` e `A máquina` virou `Sistema`. As chaves aqui são o TEXTO que o
   * trilho desenha, então renomear o bloco sem renomear a chave derruba o
   * desenho no círculo padrão, calado — foi o que a conferência mediu. */
  "bloco/Tópicos": '<circle cx="12.281" cy="22.389" r="2.781"/><circle cx="24" cy="18.613" r="2.781"/><circle cx="35.719" cy="24.646" r="2.781"/><path d="M24 21.394v14.925m11.719-8.893v8.893M12.281 25.17v11.149m0-16.711v-1.591m0-1.577v-1.591m0-1.578v-1.59M24 15.833v-.984m0-1.578v-1.59m11.719 7.927v-1.591m0 3.848v-.702m0-4.723v-1.591m0-1.578v-1.59"/><circle cx="24" cy="24" r="21.5"/>',
  /* O foguete do Arcticons: a máquina indo para a versão seguinte. Ele perdeu a
   * entrada `bloco/` — o terceiro bloco deixou de existir em 06/09/2026, e a
   * página de atualizar passou a se chamar `Idempotência`, dentro de Sistema. */
  "Idempotência": '<path d="M5.896 22.443L42.105 5.5l-10.836 37l-11.453-13.323z"/><path d="m31.326 16.95l-11.51 12.227v8.747l3.316-4.824"/>',
  "bloco/Sistema": '<path d="M24 8.408V19.81m5.255-7.944A13.22 13.22 0 0 1 37.223 24h0c0 7.303-5.92 13.223-13.223 13.223h0c-7.303 0-13.223-5.92-13.223-13.223h0c0-5.27 3.129-10.037 7.964-12.133M45.5 24c0 11.874-9.626 21.5-21.5 21.5S2.5 35.874 2.5 24S12.126 2.5 24 2.5S45.5 12.126 45.5 24"/>',
  /* AUTORAL: o acervo não tem gato — e aqui o gato É o assunto, porque a logo de
   * fábrica deste projeto são a Coquinha e o Mimir. As orelhas do mascote, em
   * três traços. A seção mudou de nome (`O gato` -> `Logo do sistema`); o
   * desenho não muda, porque a marca não mudou. */
  "Logo do sistema": '<path d="M13 21V11l8 6M35 21V11l-8 6"/><path d="M13 20c0 10 5 17 11 17s11-7 11-17"/>',

  /* as abas */
  "Início": '<path d="M42.5 23.075L26.062 7.525a3 3 0 0 0-4.124 0L5.5 23.075m5.86 1.54v14.68a2 2 0 0 0 2 2h7.14v-9.5h7v9.5h7.14a2 2 0 0 0 2-2v-14.68"/>',
  "Cor e tela": '<rect width="18.314" height="39" x="14.843" y="4.5" rx="3"/><path d="M14.843 33.4h18.314M14.843 22.236s3.933-.233 5.292 2.27s2.605 3.387 4.466.291s3.5-6.83 8.556-.514m-.001-11.601s-1.669-2.183-3.418-2.088s-4.099 4.972-5.418 4.852s-2.285-6.481-4.118-7.03s-5.36 2.35-5.36 2.35"/><ellipse cx="24" cy="38.01" rx="1.965" ry="1.957"/>',
  /* AUTORAL: o acervo não tem gato. As orelhas do mascote, em três traços. */
  "Ícones": '<path d="M17.5 5.5h-8a4 4 0 0 0-4 4v8a4 4 0 0 0 4 4h8a4 4 0 0 0 4-4v-8a4 4 0 0 0-4-4m21 0h-8a4 4 0 0 0-4 4v8a4 4 0 0 0 4 4h8a4 4 0 0 0 4-4v-8a4 4 0 0 0-4-4m-21 21h-8a4 4 0 0 0-4 4v8a4 4 0 0 0 4 4h8a4 4 0 0 0 4-4v-8a4 4 0 0 0-4-4m21 0h-8a4 4 0 0 0-4 4v8a4 4 0 0 0 4 4h8a4 4 0 0 0 4-4v-8a4 4 0 0 0-4-4"/>',
  "Barra e dock": '<rect width="22.05" height="32.42" x="12.98" y="7.79" rx="2"/><path d="M35 38.18h5.95a2.6 2.6 0 0 0 2.59-2.59V12.41a2.6 2.6 0 0 0-2.59-2.59H35"/><path d="M35.02 34.8h5.32V15.93h-5.32M13 38.18H7.09a2.6 2.6 0 0 1-2.59-2.59V12.41a2.6 2.6 0 0 1 2.59-2.59H13"/><path d="M12.98 34.8H7.66V15.93h5.32m2.65-3.39h16.75v24.21H15.63z"/>',
  "Papel de parede": '<path d="M31.315 12.123a4.465 4.465 0 1 1 0 8.93a4.465 4.465 0 0 1 0-8.93m-11.294 8.909l7.224 7.223a.7.7 0 0 0 .992 0l1.383-1.383a.7.7 0 0 1 .993 0l7.807 7.807a.702.702 0 0 1-.497 1.198H10.076a.702.702 0 0 1-.577-1.101l9.45-13.648a.702.702 0 0 1 1.072-.097Z"/><path d="M38.5 5.5h-29a4 4 0 0 0-4 4v29a4 4 0 0 0 4 4h29a4 4 0 0 0 4-4v-29a4 4 0 0 0-4-4"/>',
  /* A TELA, do `tv.svg` do acervo: é a tela inteira que o modo de leitura
   * esquenta, e não uma parte dela. Sem esta entrada a seção nova caía no
   * círculo padrão — que é o desenho de "não sei o que é isto". */
  "Modo de leitura": '<rect width="39" height="25" x="4.5" y="9.75" rx="4" ry="4"/><path d="M16 38.25h16"/>',
  "Dia e noite": '<path d="M42.213 35.215C38.476 41.551 31.585 45.8 23.702 45.8C11.838 45.8 2.22 36.174 2.22 24.3S11.837 2.8 23.7 2.8c-9.647 19.619 6.773 33.218 18.512 32.415"/>',
  "Terminal": '<path d="m10.559 22.908l12.586 7.269l-12.586 7.268m27.329 0H24.445"/><path d="M38.5 5.5h-29a4 4 0 0 0-4 4v29a4 4 0 0 0 4 4h29a4 4 0 0 0 4-4v-29a4 4 0 0 0-4-4"/>',
  /* AUTORAL: idem. */
  "Manutenção": '<path d="M24 43.5c9.043-3.117 15.489-10.363 16.5-19.589a79.4 79.4 0 0 0-.071-12.027a2.54 2.54 0 0 0-2.468-2.366c-4.091-.126-8.846-.808-12.52-4.427a2.05 2.05 0 0 0-2.881 0c-3.675 3.619-8.43 4.301-12.52 4.427a2.54 2.54 0 0 0-2.468 2.366A79.4 79.4 0 0 0 7.5 23.911C8.511 33.137 14.957 40.383 24 43.5"/>',
  "Instalação": '<circle cx="13.05" cy="24" r="8.55"/><path d="M43.5 32.55V24h0h-21.91m16.3 4.93V24"/>',
  /* Duas janelas lado a lado numa moldura: é o que uma área de trabalho é, e
   * distingue da "Cor e tela", que também desenha janela mas com o acento. */
  "Áreas de trabalho": '<rect width="39" height="29" x="4.5" y="9.5" rx="3"/><path d="M24 9.5v29M9.5 16h9m-9 6h9m6-6h9m-9 6h9"/>',
  /* O `contacts.svg` do acervo para os Créditos: crédito é gente. O `star.svg`
   * deste pack não serve — é um cartão com letras dentro, e não uma estrela. */
  "Créditos": '<path d="M35.5 4.5h-23a4 4 0 0 0-4 4v31a4 4 0 0 0 4 4h23a4 4 0 0 0 4-4v-31a4 4 0 0 0-4-4M24 13.275A5.362 5.362 0 1 1 24 24a5.362 5.362 0 1 1 0-10.725m0 12.675c5.966 0 10.725 1.667 10.725 3.656v5.119h-21.45v-5.119c0-1.989 4.758-3.656 10.725-3.656"/>',
  "Lançadores e jogos": '<path d="M24 2.5A21.51 21.51 0 0 0 2.5 24v.91l10.79 3.95a6 6 0 0 1 2.54-1.4a6 6 0 0 1 1.8-.21a8 8 0 0 1 .84.1h0L25 18.12a7.63 7.63 0 0 1 5.65-7.39a7.5 7.5 0 0 1 2.26-.25a7.62 7.62 0 0 1 1.68 15h0a7.5 7.5 0 0 1-2 .25h0l-9.22 6.52h0a6.06 6.06 0 0 1-11.81 2.64h0a6 6 0 0 1-.15-.82l-7.63-2.81A21.49 21.49 0 1 0 24 2.5m8.93 8a7.5 7.5 0 0 0-2.26.25a7.63 7.63 0 0 0-5.39 9.33h0A7.62 7.62 0 0 0 40 16.12h0a7.59 7.59 0 0 0-7.07-5.64ZM17.42 27.25a6.05 6.05 0 0 0-6.05 6h0a6.05 6.05 0 0 0 6.05 6h0a6.05 6.05 0 0 0 6.06-6h0a6.05 6.05 0 0 0-6.05-6.06Z"/>',
};
/* O «bloco/nome» vem primeiro porque "Papel de parede" existe em Configurar e em
 * Executar — o mesmo nome, dois trabalhos. Hoje os dois usam o mesmo desenho, e a
 * chave existe para o dia em que não usarem. */
const ICONE_PADRAO = '<circle cx="24" cy="24" r="4"/>';

function iconeDeMenu(nome, bloco) {
  const d = ICONES_MENU[(bloco || "") + "/" + nome] || ICONES_MENU[nome] || ICONE_PADRAO;
  const casca = document.createElement("span");
  casca.className = "menu-icone";
  casca.setAttribute("aria-hidden", "true");
  casca.innerHTML = '<svg viewBox="0 0 48 48" width="17" height="17" fill="none" '
    + 'stroke="currentColor" stroke-width="2.75" stroke-linecap="round" '
    + 'stroke-linejoin="round">' + d + "</svg>";
  return casca;
}

/* O rótulo de bloco, com o desenho na mesma coluna dos itens. */
function rotuloDeBloco(nome) {
  return elemento("div", { class: "rotulo-grupo" }, [
    iconeDeMenu(nome, "bloco"),
    elemento("span", { texto: nome }),
  ]);
}

/* O subtítulo de um grupo dentro da página do assunto. Quando o grupo se chama
 * como o assunto — é o caso do bloco de ajustes de uma seção sem subtítulo no
 * arquivo — o nome não diz nada de novo, e o que separa os grupos é o que eles
 * SÃO: ajustes, ou ações. */
function rotuloDoGrupo(g) {
  /* O `humanizar` é o mesmo que o menu já aplica: os subtítulos moram em CAIXA
   * ALTA no `meow.conf.exemplo` porque é assim que o arquivo distingue as duas
   * alturas de título, e essa é uma convenção de ARQUIVO. Na tela ela virava
   * grito — "NO DOCK", "FORMA", "MÚSICA NA BARRA" — no meio de uma página que
   * não grita em nenhum outro lugar. */
  if (g.nome !== assuntoDe(g)) return humanizar(g.nome);
  /* "AJUSTES" NÃO É TÍTULO, É RUÍDO — 06/09/2026
   *   Uma seção sem subtítulo no arquivo ganhava um `<h3>Ajustes</h3>` entre o
   *   título da página e a primeira coisa útil. Ele não separa nada (é o único
   *   grupo de chaves da página) e não informa nada (a página inteira é de
   *   ajustes). Custava uma linha de altura e um degrau de leitura em oito das
   *   dez seções. "Ações" fica: ali o rótulo SEPARA de fato — é o que distingue
   *   o que se escolhe do que se executa.
   *
   *   `null` e não `""`: quem chama testa o valor e simplesmente não desenha o
   *   `<h3>`, em vez de desenhar um vazio que continua ocupando margem. */
  return g.tipo === "acoes" ? "Ações" : null;
}

function botaoTrilho(g, filho, rotulo) {
  return elemento("button", {
    type: "button",
    /* `e-inicio` é o que a folha usa para pintar de verde — ver o comentário
     * lá. A marca sai do TIPO do grupo, e não do nome: "Início" é texto de
     * tela e pode ser traduzido ou reescrito; `tipo === "home"` é o que o
     * servidor promete. */
    class: (filho ? "filho" : "") + (g.tipo === "home" ? " e-inicio" : ""),
    "data-grupo": chaveDeAba(g),
    "aria-current": String(chaveDeAba(g) === ABA),
    title: g.original || g.nome,
    onclick: () => {
      /* CLICAR NO MENU LIMPA A BUSCA — a validação mediu: "o menu para de
       * funcionar enquanto houver texto na busca". É verdade e é inevitável:
       * com busca ativa a página mostra os RESULTADOS, não a aba, então o
       * clique parecia não fazer nada. Trocar de seção é dizer "quero ver esta
       * aba"; a busca sai do caminho. */
      $("#busca").value = "";
      ABA = chaveDeAba(g);
      gravarHash();
      render();
    },
  }, [
    iconeDeMenu(g.nome, g.bloco || "fazer"),
    elemento("span", { texto: rotulo || encurtar(g.nome) }),
    elemento("span", { class: "conta", texto: contaDoGrupo(g) }),
    /* A LINHA QUE DIZ O QUE A SEÇÃO É — pedido dela em 02/09/2026 ("deixar mais
     * obvio o que é aquela seção"). Só no nível de cima: num subitem ela
     * empurraria o menu para uma altura que não cabe na tela, e o subitem já é
     * lido dentro do assunto do pai. */
    !filho && descricaoDe(g)
      ? elemento("span", { class: "descricao-menu", texto: descricaoDe(g) })
      : null,
  ].filter(Boolean));
}

/* O NÚMERO AO LADO DO NOME TEM DE CONTAR O QUE A SEÇÃO MOSTRA.
 *   A galeria aparecia como "Galeria de papéis de parede  0" — porque o
 *   contador lia `itens.length`, e a galeria não é feita de chaves do
 *   meow.conf: os itens dela são as imagens, que chegam depois, do
 *   `/api/previas`. Um zero ao lado de 46 fotos é pior que nenhum número: diz à
 *   pessoa que não há nada ali, justamente na seção mais visual da página. */
function contaDoGrupo(g) {
  if (g.tipo === "home") return "";
  if (g.tipo === "galeria") {
    const lista = PREVIAS.get("parede/" + ABA_GALERIA);
    return lista ? String(lista.itens.length) : "";
  }
  if (g.tipo === "apps") return APPS ? String(APPS.total) : "";
  if (g.tipo === "jogos") return JOGOS ? String(JOGOS.total) : "";
  return String(g.itens.length);
}

/* ===========================================================================
 * UM DESENHO POR BLOCO — O ANTES E O DEPOIS
 * ===========================================================================
 * A frente mais importante da rodada, e a razão é dura de ouvir: *"eu mesma tô
 * extremamente confusa sobre o que tal coisa faz. Eu mesma não consigo fazer
 * nada sem te pedir ajuda."* Se a dona do projeto não consegue usar o painel
 * sozinha, ninguém consegue. O bloco FORMA era o único lugar da tela onde isso
 * não acontecia, e o que ele tem de diferente não é texto melhor: é um desenho
 * que responde ANTES da leitura, e que muda quando o valor muda.
 *
 * QUEM DESENHA NÃO É ESTE ARQUIVO. Cada bloco tem uma função em
 * `previas-tela.js` ou `previas-sistema.js`, registrada em `window.MEOW_PREVIAS`
 * sob a chave `"Seção :: BLOCO"` — e só `"Seção"` quando a seção não tem bloco
 * em CAIXA ALTA, que é exatamente a regra pela qual esta página já nomeia os
 * grupos (`subsecao || secao`). Aqui só se pergunta e se põe na tela.
 *
 * A CHAMADA LEVA DOIS ARGUMENTOS, e o segundo é o coração da coisa:
 *     fn(v, escolhido) -> { antes, depois, legenda }
 *   `v`         o que está no `meow.conf` HOJE, chave a chave, como texto;
 *   `escolhido` só o que ela clicou e ainda não salvou (o `MUDANCAS` filtrado
 *               para este bloco), ou nada quando não há escolha pendente.
 *   Com uma entrada só não existiria caminho por onde `depois` pudesse diferir
 *   de `antes`: a função é pura, e a mesma entrada só pode produzir o mesmo
 *   desenho. É por isso que o par REAGE AO CLIQUE antes do Salvar — e é isso que
 *   transforma o desenho em resposta à pergunta "o que este botão vai fazer com
 *   a minha tela?". O `escolher()` já chama `render()` a cada clique, então não
 *   é preciso nada além disto para o desenho acompanhar.
 *
 * A AUSÊNCIA DOS ARQUIVOS NÃO PODE APAGAR A PÁGINA. Os dois `<script>` são
 * carregados antes do `app.js` no `index.html`, mas um deles pode não existir
 * ainda (estão sendo escritos em frentes separadas), e um `404` de `<script>` é
 * silencioso. Daí o `window.MEOW_PREVIAS || {}`: sem o arquivo, o bloco fica
 * como estava, sem desenho e sem erro. O mesmo vale para um retorno estranho —
 * um desenho que quebra não pode levar a tela junto. */
/* O DESENHO ACOMPANHA O DEDO — 06/09/2026
 * ===========================================================================
 * Pedido dela: *"os slides mostrando os ajustes … real time quando for algo
 * nesse sentido"*.
 *
 * Até aqui o deslizante só mexia no número enquanto ela arrastava; o desenho só
 * mudava no `change`, isto é, quando ela SOLTAVA — e mesmo assim pelo caminho
 * comprido: `aplica()` grava em `MUDANCAS` e chama `render()`, que reconstrói a
 * página inteira. Arrastar um deslizante para procurar o valor certo é
 * exatamente o gesto em que o desenho precisa responder, e era o único em que
 * ele ficava parado.
 *
 * O registro abaixo é o que permite repintar SÓ o bloco daquela chave. Redesenhar
 * a página a cada pixel de arrasto custaria caro e, pior, tiraria o foco do
 * deslizante — o arrasto morreria no meio.
 *
 * `PROVISORIO` não é `MUDANCAS`: ele vive enquanto o dedo está no controle e
 * some quando solta. Nada dele chega ao disco, e nada dele conta na barra do
 * "Salvar" — é o que mantém de pé a regra da casa, "gravar não é aplicar". */
const PREVIA_VIVA = new Map();   /* chave do meow.conf -> { g | forma, alvo } */

function repintarPrevia(chave, valor) {
  const reg = PREVIA_VIVA.get(chave);
  if (!reg || !reg.alvo || !reg.alvo.parentNode) return;
  PROVISORIO = { chave: chave, valor: valor };
  try {
    if (reg.forma) {
      /* O mock lê tudo por `valorEmVigor`, que já conhece o `PROVISORIO`:
       * reconstruir os dois basta, e não há contrato novo a inventar. */
      const par = reg.alvo;
      par.replaceChildren(mockDaBarra({ chave: "FORMA_RAIO_PAINEL" }),
                          mockDaBarra({ chave: "FORMA_RAIO_DOCK" }));
      return;
    }
    const novo = parDePrevias(reg.g);
    if (novo) {
      reg.alvo.replaceWith(novo);
      reg.alvo = novo;
      /* Todas as chaves do bloco apontam para o MESMO nó, e ele acabou de ser
       * trocado: sem isto, a segunda chave do bloco repintaria um nó órfão. */
      for (const [k, r] of PREVIA_VIVA) if (r.g === reg.g) r.alvo = novo;
    }
  } finally {
    PROVISORIO = null;
  }
}

function parDePrevias(g) {
  if (g.tipo !== "chaves" || !g.itens.length) return null;
  const mapa = (typeof window !== "undefined" && window.MEOW_PREVIAS) || {};
  /* A chave é montada com a MESMA regra que batiza o grupo: quando o bloco em
   * caixa alta existe, ele é o `g.nome` e a seção é o `g.secaoPai`. */
  const nome = g.nome === g.secaoPai ? g.nome : `${g.secaoPai} :: ${g.nome}`;
  const desenhar = mapa[nome];
  if (typeof desenhar !== "function") return null;

  const v = {};
  const escolhido = {};
  for (const item of g.itens) {
    v[item.chave] = item.valor ?? "";
    if (MUDANCAS.has(item.chave)) escolhido[item.chave] = MUDANCAS.get(item.chave);
    /* O valor sob o dedo vence o que já estava escolhido, e vence o disco: é o
     * que ela está vendo no deslizante neste instante, e o desenho tem de
     * concordar com o número que está na tela ao lado dele. */
    if (PROVISORIO && PROVISORIO.chave === item.chave) escolhido[item.chave] = PROVISORIO.valor;
  }
  let r;
  try {
    /* Passar `undefined` e não `{}` quando nada está pendente: é assim que o
     * contrato pede `depois: null`, e um objeto vazio faria o outro lado
     * calcular um segundo desenho idêntico para descobrir isso. */
    r = desenhar(v, Object.keys(escolhido).length ? escolhido : undefined);
  } catch (e) {
    /* As funções já prometem não lançar, e ainda assim: uma promessa quebrada
     * aqui apagaria a aba inteira, e o custo de não confiar são três linhas. */
    return null;
  }
  if (!r || !r.antes) return null;

  /* O PAR NÃO É ILUSTRAÇÃO: ELE É O CONTROLE — 06/09/2026
   *   Pedido dela, literal: *"como teremos o antes e depois nessa seção ao
   *   invés de selecionar o sim e o não. selecionamos o antes ou o depois com
   *   bordas indicando se tratarem de botões"*.
   *
   *   Três desenhos maiores foram propostos e os três caíram na conferência —
   *   um deles produzia, depois do recorte, dois botões PIXEL A PIXEL IDÊNTICOS.
   *   O que sobreviveu é a leitura mais literal do que ela escreveu, e é a mais
   *   barata: o par que já está no alto do bloco, e que já reage ao dedo dela,
   *   ganha borda e passa a ser onde se escolhe.
   *
   *   A semântica é a que o par já tinha, dita em voz alta:
   *     - "Como fica" existe só quando há escolha esperando, e é o que está
   *       marcado. Apertá-lo não muda nada, e por isso ele NÃO é botão: um
   *       botão que não faz nada ensina a não confiar nos outros.
   *     - "Como está" é o desfazer DAQUELE bloco. É a única coisa nova, e é o
   *       que faltava: até aqui, desistir custava achar cada cartão mexido, ou
   *       o "Descartar" do topo, que joga fora as escolhas da página inteira.
   *
   *   Nada disto toca o disco: `MUDANCAS` é a bandeja, e "gravar não é
   *   aplicar" continua valendo palavra por palavra. */
  const desfazerBloco = () => {
    let quantas = 0;
    for (const item of g.itens) if (MUDANCAS.delete(item.chave)) quantas++;
    if (!quantas) return;
    atualizarBarraSalvar();
    render();
    torrada(quantas === 1
      ? "1 escolha deste bloco desfeita — o meow.conf não foi tocado"
      : `${quantas} escolhas deste bloco desfeitas — o meow.conf não foi tocado`, "igual");
  };
  const temEscolha = Boolean(r.depois);
  const lado = (rotulo, svg, aoClicar) => {
    /* SEM PAR, SEM RÓTULO. "Como está" só quer dizer alguma coisa ao lado de um
     * "Como fica"; sozinho, ele nomeia a única coisa na tela e pede ao olho um
     * degrau que não leva a lugar nenhum. */
    const legenda = temEscolha
      ? elemento("p", { class: "rotulo-mini", texto: rotulo })
      : null;
    /* Sem escolha esperando não há o que desfazer, e o "Como está" volta a ser
     * o que sempre foi: um desenho. Uma borda de botão sem ação por trás é a
     * mesma promessa vazia. */
    if (!aoClicar) return elemento("div", {}, [legenda, svg]);
    return elemento("button", {
      type: "button",
      class: "lado-previa",
      "aria-pressed": String(rotulo !== "Como está"),
      title: "Desfaz as escolhas deste bloco. O meow.conf não é tocado.",
      onclick: aoClicar,
    }, [legenda, svg]);
  };
  /* CLASSE PRÓPRIA, E NÃO A `grade-barras` DA FORMA — 06/09/2026
   *   Reaproveitar a caixa da FORMA parecia certo (o mesmo enquadramento que
   *   ela já entende), e a medição na tela mostrou que não era: os dois mocks
   *   da FORMA são `div` que ESTICAM, e um SVG de `viewBox` 100×60 com altura
   *   fixa não estica — ele se centraliza. Numa coluna de 1600 px o desenho
   *   saía com 200 px de largura no meio de um oceano vazio, e a primeira
   *   impressão de um desenho que existe para explicar era "isto está perdido
   *   na página".
   *
   *   `.par-previa` limita a coluna à largura que o desenho realmente ocupa,
   *   então ele preenche o que lhe cabe — com par ou sem par. A `grade-barras`
   *   continua intocada, e a FORMA com ela. */
  const par = elemento("div", { class: "par-previa" }, [
    lado("Como está", r.antes, temEscolha ? desfazerBloco : null),
    /* Sem escolha pendente é UM desenho, e não um par com metade vazia: um
     * quadro em branco rotulado "Como fica" prometeria uma diferença que não
     * existe. */
    r.depois ? lado("Como fica", r.depois, null) : null,
  ]);
  return elemento("div", { class: "previa-bloco" }, [
    par,
    /* A legenda é uma linha, no padrão que a FORMA já usa: começa por "desenho,
     * não captura:" e diz os números desenhados. */
    r.legenda ? elemento("p", { class: "sem-previa", texto: r.legenda }) : null,
  ]);
}

/* ===========================================================================
 * A ABA "LOGO DO SISTEMA" DIZ ONDE A LOGO APARECE — 06/09/2026
 * ===========================================================================
 * O alvo é dela, e é de produto: *"por default temos os meus dois gatos ali,
 * mas pensando em produto ele precisa dizer pro user que ele pode colocar o
 * ícone do Menu de Lançamento — apertar a tecla Windows, e o atual logo do
 * Pop!_OS"*.
 *
 * A aba tinha 21 chaves e nenhuma frase dizendo em QUE LUGAR DA TELA cada uma
 * age. Quem chega vê "Qual gato fica no dock" e conclui que isto é uma seção
 * sobre os gatos de outra pessoa — quando o que ela está oferecendo é trocar a
 * marca do sistema em três lugares nomeados. Então a aba passa a nomeá-los,
 * antes de qualquer controle:
 *
 *   · o MENU DE LANÇAMENTO, que é o que abre ao apertar a tecla Super e hoje
 *     mostra a coquinha do Pop!_OS;
 *   · a DOCK;
 *   · o TERMINAL, onde o fastfetch desenha a logo em letras.
 *
 * E as duas coisas que a lista não diz sozinha: que a troca acontece SOZINHA de
 * dia e de noite, e o que vem de fábrica.
 *
 * OS TERMOS DA ABA DEIXARAM DE FALAR EM GATO — exceto onde o assunto é
 * literalmente o gato de fábrica, que é a última linha. A Coquinha e o Mimir não
 * saíram de lugar nenhum: eles continuam sendo o acervo de `assets/gatos/` e o
 * que a chave `LOGO` escolhe. O que mudou é que eles são o PADRÃO, e não o
 * assunto — o assunto é a logo de quem estiver usando.
 *
 * NADA AQUI SUBSTITUI O TEXTO DAS CHAVES. As frases dos cartões continuam vindo
 * do `meow.conf.exemplo`, que é a fonte única; esta é a moldura que faltava em
 * volta delas, e ela mora na página porque é da página, e não do arquivo de
 * configuração, a pergunta "onde eu vejo isto?". */
const NOTA_DO_ASSUNTO = {
  "Logo do sistema": {
    /* As três pastilhas dizem só os NOMES dos lugares — é o que se lê de
     * relance, e é o que faltava. A frase abaixo carrega o que uma pastilha não
     * comporta sem virar parágrafo redondo. */
    lugares: ["Logo do menu de lançamento", "Logo da dock", "Logo do terminal"],
    fecho: "No menu de lançamento é o que aparece ao apertar a tecla Super, hoje "
         + "no lugar da coquinha do Pop!_OS; no terminal, a logo é desenhada em "
         + "letras. A troca acontece sozinha, de dia e de noite. De fábrica vêm "
         + "a Coquinha e o Mimir — solte um .svg em «Adicionar logo» e a sua "
         + "entra na lista ao lado deles.",
  },
};

function notaDoAssunto(assunto) {
  const nota = NOTA_DO_ASSUNTO[assunto];
  if (!nota) return null;
  const caixa = elemento("div");
  const lista = elemento("div", { class: "fichas" });
  for (const nome of nota.lugares) {
    lista.append(elemento("span", { class: "ficha" }, [elemento("b", { texto: nome })]));
  }
  caixa.append(lista);
  /* `nota-secao` sozinha, e não `frase nota-secao`: a `.frase` corta em três
   * linhas (é o que impede um comentário de seis linhas de empurrar o cartão),
   * e aqui o texto é o assunto da tela — cortá-lo esconderia justamente a parte
   * que diz o que vem de fábrica. */
  caixa.append(elemento("p", { class: "nota-secao", texto: nota.fecho }));
  return caixa;
}

/* ===========================================================================
 * O QUE ENTRA DE FORA, NA PÁGINA A QUE PERTENCE
 * ===========================================================================
 * Dois dos seis destinos do `botaoAcervo` não têm um CONTROLE de onde pendurar:
 * a fonte e o tema de ícones de base não são a opção de uma chave — são coisas
 * que a máquina precisa TER para que as chaves façam sentido. O gato pendura no
 * controle de `LOGO`, o ponteiro no de `CURSOR`, a imagem na galeria; estes dois
 * penduram no assunto.
 *
 * A FONTE MORA NO TERMINAL porque é lá que ela decide alguma coisa nesta
 * máquina: o gato em ANSI do fastfetch é desenhado em células da fonte do
 * terminal, e o `FASTFETCH_LOGO_PROPORCAO` existe justamente para converter
 * pixel em célula "na sua fonte". Medido no `meow.conf.exemplo`: nenhuma chave
 * nomeia uma família de fonte, então não há cartão a que ela pertença. */
const ACERVO_DO_ASSUNTO = {
  "Ícones": {
    tipo: "tema-icones",
    nota: "Um tema de ícones de base, em .zip. Ele entra na máquina, e o "
        + "«Tema de base» acima passa a poder escolhê-lo.",
  },
  "Terminal": {
    tipo: "fonte",
    nota: "Uma fonte para o terminal, em .zip, .ttf ou .otf. Ela é instalada e "
        + "registrada na máquina; escolhê-la é coisa dos Ajustes do terminal.",
  },
};

function acervoDoAssunto(assunto) {
  const conf = ACERVO_DO_ASSUNTO[assunto];
  if (!conf) return null;
  const botao = botaoAcervo(conf.tipo, async () => {
    /* Reler o esquema porque a lista de temas de ícones e a de fontes são
     * lidas do disco pelo servidor: sem isto o que acabou de entrar só
     * apareceria depois de um F5, que é o mesmo defeito que o acervo de gatos
     * teve até 02/09/2026. */
    await recarregarEsquema();
    render();
  });
  if (!botao) return null;
  return elemento("div", { class: "com-acervo" }, [
    elemento("p", { class: "frase", texto: conf.nota }),
    botao,
  ]);
}

/* ===========================================================================
 * O FOCO SOBREVIVE AO REDESENHO — 02/09/2026
 * ===========================================================================
 * `render()` refaz o conteúdo inteiro. Quem estava com o foco deixa de existir,
 * e o navegador devolve o foco ao `<body>`.
 *
 * A auditoria pegou o caso pior: no deslizante do `MIDIA_LARGURA`, "a primeira
 * seta anda um passo, a segunda não faz nada" — porque a primeira seta dispara
 * o `change`, que escolhe, que chama `render()`, que joga fora o deslizante que
 * estava sob o dedo dela. Quem usa mouse não vê; quem usa teclado perde o
 * controle no meio do gesto.
 *
 * A âncora é a CHAVE do cartão mais o tipo do elemento — e não uma posição na
 * árvore, que muda quando um cartão nasce ou some. */
function ancoraDoFoco() {
  const el = document.activeElement;
  if (!el || el === document.body) return null;
  /* CAMPO COM `data-foco` É ÂNCORA POR SI SÓ.
   *   Os dois campos de busca da aba de aplicativos ("Filtrar aplicativo" e
   *   "Buscar desenho") nascem fora de qualquer cartão, então não tinham
   *   âncora: a validação mediu que eles perdiam o foco NA PRIMEIRA TECLA —
   *   digitar uma letra redesenhava a grade e o cursor caía fora. Agora eles se
   *   identificam, e o foco volta com a posição do cursor junto. */
  if (el.dataset && el.dataset.foco) {
    return { foco: el.dataset.foco, pos: el.selectionStart };
  }
  const cartao = el.closest("[data-chave]");
  if (!cartao) return el.id || null;
  return {
    chave: cartao.dataset.chave,
    tag: el.tagName,
    valor: el.dataset ? el.dataset.valor : null,
    tipo: el.type || null,
  };
}

function devolverFoco(ancora) {
  if (!ancora) return;
  if (ancora.foco) {
    const alvo = document.querySelector(`[data-foco="${CSS.escape(ancora.foco)}"]`);
    if (alvo) {
      alvo.focus();
      /* O cursor volta para onde estava: sem isto, ele salta para o fim do
       * texto a cada tecla, e apagar uma letra no meio vira impossível. */
      if (ancora.pos != null && alvo.setSelectionRange) {
        try { alvo.setSelectionRange(ancora.pos, ancora.pos); } catch (e) { /* type=search */ }
      }
    }
    return;
  }
  if (typeof ancora === "string") {
    const alvo = document.getElementById(ancora);
    if (alvo) alvo.focus();
    return;
  }
  const cartao = document.querySelector(`[data-chave="${CSS.escape(ancora.chave)}"]`);
  if (!cartao) return;
  const iguais = [...cartao.querySelectorAll(ancora.tag)];
  const alvo = ancora.valor
    ? iguais.find((e) => e.dataset && e.dataset.valor === ancora.valor)
    : iguais.find((e) => !ancora.tipo || e.type === ancora.tipo);
  if (alvo) alvo.focus();
}

function render() {
  /* Os nós da passagem anterior morreram com ela. Um registro que sobrevive
   * ao `render` guarda referência para árvore descartada, e o repintar acha um
   * nó sem pai — silencioso, e cada vez mais caro. */
  PREVIA_VIVA.clear();
  const ancora = ancoraDoFoco();
  montarTrilho();
  const alvo = $("#conteudo");
  alvo.replaceChildren();
  ACERVO_DESENHADO.clear();
  const busca = semAcento($("#busca").value.trim());

  /* A busca atravessa TODOS os grupos, e é assim que uma página de cem chaves
   * deixa de exigir que ela lembre em qual aba a chave mora. Sem busca, mostra
   * só a aba escolhida. */
  const grupos = busca
    ? GRUPOS.filter((g) => g.tipo !== "home")
        .map((g) => ({ ...g, itens: g.itens.filter((i) => casa(i, busca)) })).filter((g) => g.itens.length)
    : GRUPOS.filter((g) => chaveDeAba(g) === ABA);

  if (!grupos.length) {
    alvo.append(elemento("p", { class: "vazio-msg", texto: `Nada casa com “${$("#busca").value}”.` }));
    return;
  }

  /* As quatro pílulas de fundo só aparecem onde há imagem para pôr sobre elas —
   * numa aba de texto puro seriam quatro botões que não fazem nada visível. */
  const temImagem = grupos.some((g) => g.tipo === "galeria" || g.nome === GRUPO_ICONES
    || (g.itens || []).some((i) => i.previa === "gato" || i.previa === "cursor"));
  if (temImagem) alvo.append(barraDeFundos());
  let ultimoAssunto = null;
  let barraDesenhada = false;   // o par painel+dock sai uma vez por página

  /* OS AJUSTES VÊM ANTES DO ACERVO — 06/09/2026
   *   Medido na tela: em "Papel de parede" a galeria tem 255 imagens e nasce no
   *   alto da página; os nove cartões de ajuste — e o desenho do bloco, que
   *   existe justamente para explicá-los — ficavam depois de todas elas. Para
   *   mudar o intervalo do carrossel era preciso rolar por um acervo inteiro. O
   *   mesmo em "Ícones", com 48.
   *
   *   O acervo não some nem encolhe: ele deixa de ser a porta. Quem chega numa
   *   seção chega para ajustar; olhar a coleção é a segunda coisa que se faz
   *   ali, e agora ela está uma rolagem abaixo em vez de na frente. */
  const PESO = { chaves: 0, acoes: 1, galeria: 2, apps: 2, jogos: 2, folhas: 3 };
  /* `sort` ESTÁVEL E POR SEÇÃO: devolver 0 entre grupos de seções diferentes
   * preserva a ordem que o servidor mandou (o `sort` do JavaScript é estável
   * desde 2019), então a sequência das seções na página não muda — só a ordem
   * DENTRO de cada uma. E é uma cópia: `grupos` é `const` e é lido de novo
   * adiante, no cálculo do trilho. */
  const ordenados = grupos.slice().sort((a, b) => {
    if (a.tipo === "home" || b.tipo === "home") return 0;
    if (assuntoDe(a) !== assuntoDe(b)) return 0;
    return (PESO[a.tipo] ?? 9) - (PESO[b.tipo] ?? 9);
  });
  for (const g of ordenados) {
    /* A home desenha o próprio cabeçalho: um `h2` "Início" acima dela seria o
     * título de uma tela que já se apresenta. */
    if (g.tipo === "home") { alvo.append(montarHome()); continue; }
    /* TODA ABA TEM TÍTULO — e catorze delas não tinham.
     *   A condição era `if (busca || g.tipo !== "chaves")`: as abas de chaves
     *   abriam direto na frase de descrição, com um degrau de tipografia que
     *   simplesmente não existia ali. O nome da aba estava no menu, e o menu
     *   está sempre visível — mas quem clicou já não olha o menu, e uma tela
     *   sem título é uma tela sem lugar.
     *
     *   Quando a aba é uma SUBABA, o título diz o caminho: "Barra e dock ·
     *   Forma". Sozinho, "Forma" não diz de que forma se fala. */
    /* O TÍTULO É O ASSUNTO, UMA VEZ POR PÁGINA.
     *   Uma página de assunto pode ter a galeria, dois ou três blocos de ajuste
     *   e as ações — quatro grupos, um título. Cada grupo ganha um subtítulo
     *   próprio, e só quando há mais de um: numa página de um grupo só, o
     *   subtítulo seria o título repetido em corpo menor.
     *
     *   A frase da seção repete a do menu de propósito: no menu ela serve para
     *   escolher onde entrar, aqui para confirmar que se entrou no lugar certo.
     *   Fora da busca, que mostra resultados de vários assuntos ao mesmo tempo. */
    const assunto = assuntoDe(g);
    if (assunto !== ultimoAssunto) {
      ultimoAssunto = assunto;
      alvo.append(elemento("h2", { class: "secao-titulo", title: assunto,
                                   texto: encurtar(assunto) }));
      if (!busca) {
        const frase = descricaoDe(assunto);
        if (frase) alvo.append(elemento("p", { class: "descricao-secao", texto: frase }));
        /* A nota da aba vem depois da frase da seção e antes de tudo o mais:
         * ela é o que responde "onde isto aparece na minha tela?", e essa é a
         * primeira pergunta de quem abre a aba. */
        const nota = notaDoAssunto(assunto);
        if (nota) alvo.append(nota);
        const acervo = acervoDoAssunto(assunto);
        if (acervo) alvo.append(acervo);
      }
    }
    if (grupos.length > 1) {
      const rotulo = rotuloDoGrupo(g);
      if (rotulo) alvo.append(elemento("h3", { class: "subsecao-titulo", texto: rotulo }));
    }
    if (g.tipo === "folhas") { alvo.append(montarFolhas(g.itens)); continue; }
    if (g.tipo === "apps") { alvo.append(montarApps()); continue; }
    if (g.tipo === "jogos") { alvo.append(montarJogos()); continue; }
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
     * `FORMA_RAIO_DOCK` moram na mesma seção) e comparar é metade da escolha.
     *
     * UMA VEZ POR PÁGINA, E NÃO POR GRUPO — 06/09/2026. Com uma página por
     * assunto, "Forma" e "Vidro e relógio" passaram a morar juntas em "Barra e
     * dock", e as duas têm chaves de prévia `barra`: o par aparecia duas vezes
     * na mesma tela, com números diferentes, como se fossem barras diferentes.
     * O desenho é do assunto, não do bloco. */
    if (!busca && !barraDesenhada && (g.itens || []).some((i) => i.previa === "barra")) {
      barraDesenhada = true;
      /* A FORMA TAMBÉM GRUDA — 07/09/2026
       *   Queixa dela: "a forma em barra e dock não congela". Estava certa: o
       *   `sticky` mora na `.previa-bloco`, e a FORMA é a única prévia que não
       *   passa pelo `parDePrevias` — ela tem mock próprio, montado aqui.
       *   Então ela ganha a MESMA caixa, em vez de uma segunda regra de CSS que
       *   teria de ser mantida em dia com a primeira. "Barra e dock" é a seção
       *   de 30 chaves, a que ela mais rola: era a que mais precisava. */
      const caixa = elemento("div", { class: "previa-bloco" });
      const par = elemento("div", { class: "grade-barras" });
      par.append(mockDaBarra({ chave: "FORMA_RAIO_PAINEL" }));
      par.append(mockDaBarra({ chave: "FORMA_RAIO_DOCK" }));
      /* O PAR DA FORMA TAMBÉM DESFAZ — 06/09/2026
       *   Medida a interação aba a aba: em nove das dez seções o "Como está"
       *   virava botão e devolvia as escolhas do bloco; em "Barra e dock" não,
       *   porque o desenho da FORMA não passa pelo `parDePrevias` — e "Barra e
       *   dock" é justamente a seção que ela mais mexe, com 30 chaves.
       *
       *   O desfazer aqui cobre as DEZ chaves que o mock lê, e não as 30 da
       *   seção: é o desfazer DESTE desenho, e prometer mais do que o desenho
       *   mostra seria outra promessa vazia. */
      const pendentes = CHAVES_DO_MOCK.filter((c) => MUDANCAS.has(c));
      if (pendentes.length) {
        par.classList.add("par-desfazivel");
        par.prepend(elemento("button", {
          type: "button",
          class: "btn btn-mini desfazer-forma",
          texto: pendentes.length === 1 ? "Desfazer 1 escolha" : `Desfazer ${pendentes.length} escolhas`,
          title: "Devolve a forma da barra e da dock ao que está no disco. O meow.conf não é tocado.",
          onclick: () => {
            for (const c of pendentes) MUDANCAS.delete(c);
            atualizarBarraSalvar();
            render();
            torrada(pendentes.length === 1
              ? "1 escolha da forma desfeita — o meow.conf não foi tocado"
              : `${pendentes.length} escolhas da forma desfeitas — o meow.conf não foi tocado`, "igual");
          },
        }));
      }
      caixa.append(par);
      alvo.append(caixa);
      /* A FORMA É O BLOCO QUE ELA MAIS MEXE, e era o único sem tempo real:
       * o desenho dele não vem do `MEOW_PREVIAS`, então o registro por bloco não
       * o alcançava. Medido: em "Barra e dock", arrastar o raio não mudava
       * desenho nenhum, enquanto as outras três abas com deslizante já
       * respondiam. As dez chaves que o mock lê ficam registradas apontando
       * para este mesmo par. */
      for (const chave of CHAVES_DO_MOCK) PREVIA_VIVA.set(chave, { forma: par, alvo: par });
    }
    /* O PAR ANTES/DEPOIS ABRE O BLOCO, e é por bloco mesmo: o desenho responde
     * às chaves DAQUELE bloco, e pô-lo no alto da página misturaria a barra com
     * o relógio e a música. A exceção é a FORMA, logo acima, cujo par
     * painel+dock é do ASSUNTO — porque as chaves dele vêm em pares que moram em
     * blocos vizinhos, e comparar os dois é metade da escolha. */
    if (!busca) {
      const previa = parDePrevias(g);
      if (previa) {
        alvo.append(previa);
        /* Uma entrada por chave do bloco, todas apontando para o mesmo nó: o
         * deslizante conhece a própria chave e nada mais, e é por ela que ele
         * acha o desenho que precisa repintar. */
        for (const item of g.itens) PREVIA_VIVA.set(item.chave, { g: g, alvo: previa });
      }
    }
    const grade = elemento("div", { class: "grade" });
    for (const item of g.itens) {
      /* Ação `oculta` não é cartão: o argumento dela é uma imagem, e a galeria
       * já a oferece no lugar certo (o botão embaixo de cada foto). Um
       * `<select>` com 255 nomes de arquivo seria a pior forma de perguntar
       * "qual foto?" numa página que sabe desenhá-las. */
      if (g.tipo === "acoes" && item.oculta) continue;
      grade.append(g.tipo === "acoes" ? montarAcao(item) : montarCartao(item));
    }
    alvo.append(grade);

    /* A GRADE DO DISCO VEM DEPOIS DOS CONTROLES — 06/09/2026
     *   Ela abria a seção, e na tela isso punha DUAS prévias em sequência: os
     *   ícones que estão instalados agora e, logo abaixo, o desenho do que as
     *   chaves fazem. Duas imagens seguidas, com propósitos diferentes e sem
     *   nada entre elas, leem-se como a mesma coisa repetida.
     *
     *   Elas respondem a perguntas de tempos diferentes, e a ordem passa a
     *   dizê-lo: primeiro o desenho ("o que estas chaves fazem"), depois os
     *   controles, e por último o disco ("o que já está lá") — que não é
     *   escolha, é conferência, e a frase ao lado dela avisa que só muda depois
     *   de reconstruir. */
    if (!busca && g.nome === GRUPO_ICONES) {
      alvo.append(elemento("p", {
        class: "frase",
        texto: "O tema como está no disco agora. Trocar uma chave acima só muda "
             + "isto depois de “Reconstruir o tema de ícones”.",
      }));
      alvo.append(gradeDeIcones());
    }
  }
  devolverFoco(ancora);
  /* A ABA ABERTA APARECE — em 375px o trilho vira uma tira horizontal com vinte
   * botões, e a validação mediu que "a marcação existe fora da tela": a aba
   * ativa podia estar a 600px de rolagem, invisível. `nearest` não sacode a
   * página quando ela já está à vista. */
  const ativa = document.querySelector('#trilho button[aria-current="true"]');
  if (ativa && ativa.scrollIntoView) {
    ativa.scrollIntoView({ block: "nearest", inline: "nearest" });
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

/* A BUSCA ALCANÇA TUDO O QUE A PÁGINA MOSTRA — chave, ação e folha.
 * A auditoria mediu: "a busca do topo nunca encontra uma folha — a aba inteira
 * é invisível para o único atalho de navegação da página". A causa era este
 * `item.chave ?` na frente: quem não tem `chave` caía no ramo das ações, que
 * lê `rotulo`/`ajuda`/`id` — campos que uma folha não tem. Agora os campos são
 * a união, e cada tipo contribui com os seus. */
function casa(item, busca) {
  const campos = [
    item.chave, item.frase, item.valor, item.secao, item.subsecao,
    item.rotulo, item.ajuda, item.id, item.arquivo, item.nome, item.caminho,
  ];
  return campos.filter(Boolean).some((c) => semAcento(String(c)).includes(busca));
}

/* AS FOLHAS ABREM — 02/09/2026.
 * A auditoria mediu esta aba como "texto morto": dezoito nomes e dezoito
 * caminhos absolutos, nada clicável. Um caminho que ela precisa selecionar,
 * copiar e colar num gerenciador de arquivos é a interface pedindo para ser
 * contornada. Agora cada folha é um link que o servidor serve. */
/* ===========================================================================
 * A HOME — "o que está no ar, o que espera por mim, e por onde entro"
 * ===========================================================================
 * A página abria na galeria: 46 fotos e nenhuma resposta. Quem chega uma vez
 * por semana precisa de três coisas antes de escolher aba, e todas as três já
 * existem nos dados — só não estavam em lugar nenhum:
 *
 *   1. COMO A MÁQUINA ESTÁ VESTIDA. A variante, a cor de destaque, o modo, o
 *      gato em vigor, o tema de ícones, o ponteiro. A tira de cores é o próprio
 *      flavor, desenhado — "mocha" não diz nada, a tira diz.
 *   2. O QUE ESPERA POR VOCÊ. As escolhas guardadas e não salvas, e quantos
 *      ajustes estão diferentes do que vem de fábrica. Sem pendência a frase
 *      não desaparece: ela é onde o modelo do produto ("clicar guarda, Salvar
 *      grava") é dito antes do primeiro clique arriscado, e não depois.
 *   3. POR ONDE ENTRAR. Os três blocos como três portas, com o tamanho de cada
 *      um — e não como três rótulos cinza no alto de um menu.
 *
 * E o rodapé: as quatro ações que se roda toda semana. Elas já existem em
 * "Rodar"; aqui elas estão a um clique de onde a página abre. */
function montarHome() {
  const chave = (c) => ESQUEMA.chaves.find((k) => k.chave === c);
  const vale = (c) => { const k = chave(c); return k ? (k.efetivo || k.valor || k.padrao || "") : ""; };
  const caixa = elemento("div", { class: "home" });

  /* --- 1. o retrato ------------------------------------------------------- */
  const retrato = elemento("section", { class: "home-retrato" });
  const gatoNome = vale("LOGO");
  const gatos = previasDe("gato");
  const gato = gatos && gatos.itens.find((i) => i.id === gatoNome);
  if (gato && gato.url) {
    retrato.append(elemento("img", { class: "home-gato", src: gato.url, alt: "",
                                     title: `A logo em vigor: ${gatoNome}` }));
  }

  const ident = elemento("div", { class: "home-id" });
  ident.append(elemento("p", { class: "home-rotulo", texto: "Como a máquina está vestida" }));
  ident.append(elemento("h2", { class: "home-titulo",
    texto: [vale("FLAVOR"), vale("ACCENT"), vale("MODO")]
      .map((v) => maiuscula(rotuloDeValor(v))).join(" · ") }));

  /* A TIRA É O FLAVOR, DESENHADO. Mesma disciplina do cartão de variante: um
   * nome não se compara, uma tira se compara. O acento ganha um anel — é a
   * única cor da tira que significa algo em toda a interface. */
  const paleta = (ESQUEMA.paleta.flavors || {})[vale("FLAVOR")] || {};
  const tira = elemento("div", { class: "home-tira", title: "A paleta desta variante, na ordem do Catppuccin" });
  for (const nome of (ESQUEMA.paleta.ordem || [])) {
    if (!paleta[nome]) continue;
    const s = elemento("span", { title: nome });
    s.style.background = paleta[nome];
    if (nome === vale("ACCENT")) s.dataset.acento = "1";
    tira.append(s);
  }
  ident.append(tira);

  const comoEscolhido = { hora: "escolhido pelo relógio", rotacao: "girando pela lista", fixo: "fixo" };
  ident.append(elemento("p", { class: "home-linha", texto:
    `Logo ${gatoNome || "—"}, ${comoEscolhido[vale("LOGO_MODO")] || "fixo"} · ícones ${vale("NOME_TEMA_ICONES")} · ponteiro ${vale("CURSOR") || "de fábrica"}` }));
  retrato.append(ident);

  /* As fotos são a COLEÇÃO, não "a que está na tela" — a página não sabe qual
   * está na tela, e dizer que sabe seria a primeira mentira dela. */
  const paredes = previasDe("parede", "ativos");
  if (paredes && paredes.itens.length) {
    const fotos = elemento("div", { class: "home-fotos" });
    for (const i of paredes.itens.slice(0, 6)) {
      if (i.url) fotos.append(elemento("img", { src: i.url, alt: "", title: i.rotulo }));
    }
    const n = (paredes.contagens && paredes.contagens.ativos) || paredes.itens.length;
    fotos.append(elemento("span", { class: "home-fotos-conta",
      texto: `${n} no carrossel, trocando a cada ${rotuloDeValor(vale("WALLPAPER_INTERVALO"))}` }));
    retrato.append(fotos);
  }
  caixa.append(retrato);

  /* --- 2. o que espera por você ------------------------------------------ */
  const mexidas = ESQUEMA.chaves.filter((i) => (i.valor ?? "") !== i.padrao).length;
  const atencao = elemento("section", { class: "home-atencao" });
  if (MUDANCAS.size) {
    atencao.dataset.esperando = "1";
    atencao.append(elemento("p", {}, [
      elemento("strong", { texto: `${MUDANCAS.size} ${MUDANCAS.size === 1 ? "escolha" : "escolhas"} esperando. ` }),
      elemento("span", { texto: "Elas estão guardadas aqui, e não no disco. “Salvar e aplicar”, no alto, grava tudo de uma vez e roda o instalador em seguida." }),
    ]));
  } else {
    atencao.append(elemento("p", {}, [
      elemento("strong", { texto: "Nada esperando. " }),
      elemento("span", { texto: "Escolher aqui não muda a máquina: clicar guarda, e “Salvar e aplicar” é o que grava e aplica." }),
    ]));
  }

  /* --- 3. as portas: uma por bloco do menu, sempre ------------------------
   * Elas saem do MESMO `blocoDoAssunto` que desenha o menu: bloco novo aparece
   * na home no mesmo dia, e bloco que sair some junto. Era esse o defeito de
   * quando as portas eram escritas à mão — o menu ganhou um bloco e a home
   * ficou com uma porta a menos, sem nada dizer.
   *
   * As frases seguem os DOIS nomes de 06/09/2026 (Tópicos · Sistema). As três
   * entradas antigas ("Assuntos", "A máquina", "A nova versão") saíram em vez
   * de ficar de reserva: uma frase que nenhum bloco alcança não é retrocompa-
   * tibilidade, é uma linha que mente para quem lê o arquivo. Bloco sem frase
   * cai no `|| ""`, que é silêncio — e silêncio é melhor que frase genérica. */
  const ordemDosAssuntos = assuntosEmOrdem();
  const FRASE_DO_BLOCO = {
    "Tópicos": "Cada assunto numa página: a coleção, os ajustes e as ações, juntos.",
    "Sistema": "Instalar, conferir, manter, e o Pop!_OS em dia sem desfazer isto aqui.",
  };
  const blocos = [];
  for (const assunto of ordemDosAssuntos) {
    const nome = blocoDoAssunto(assunto);
    let b = blocos.find((x) => x.nome === nome);
    if (!b) blocos.push((b = { nome, primeiro: assunto, chaves: 0, acoes: 0, assuntos: 0 }));
    b.assuntos += 1;
    for (const g of GRUPOS) {
      if (assuntoDe(g) !== assunto) continue;
      if (g.tipo === "chaves") b.chaves += g.itens.length;
      else if (g.tipo === "acoes") b.acoes += g.itens.length;
    }
  }
  const portas = blocos.map((b) => [
    b.primeiro, b.nome,
    b.chaves
      ? `${b.chaves} ajustes em ${b.assuntos} assunto${b.assuntos > 1 ? "s" : ""}`
      : `${b.acoes} ${b.acoes > 1 ? "ações" : "ação"}`,
    FRASE_DO_BLOCO[b.nome] || "",
  ]);
  const grade = elemento("div", { class: "home-portas" });
  caixa.append(grade);
  for (const [destino, nome, conta, frase] of portas) {
    if (!destino) continue;
    grade.append(elemento("button", {
      type: "button", class: "porta",
      title: `Ir para ${destino}`,
      onclick: () => { ABA = destino; gravarHash(); render(); },
    }, [
      elemento("b", { texto: nome }),
      elemento("span", { class: "porta-conta", texto: conta }),
      elemento("span", { class: "porta-frase", texto: frase }),
    ]));
  }

  /* --- 3b. o que a noite muda --------------------------------------------
   * Nada aqui é escrito à mão: cada frase só aparece quando a chave que a
   * sustenta está ligada, e o texto sai do valor em vigor. Uma chave desligada
   * não vira frase negativa — vira silêncio, menos o modo de leitura, que é a
   * única que dá para confundir com defeito quando a tela não esquenta. */
  const liga = (c) => ["sim", "true", "1"].includes(String(vale(c)).toLowerCase());
  const noite = elemento("section", { class: "home-noite" });
  /* `NOITE_INICIO` vazio não é "não há noite": é "quem decide a hora é o
   * horário do modo de leitura", que é o que os comentários das duas chaves
   * dizem. A home mostra a hora que de fato vale, e não a célula vazia. */
  const comecaAs = vale("NOITE_INICIO") || vale("LEITURA_HORARIO_INICIO");
  const terminaAs = vale("NOITE_FIM") || vale("LEITURA_HORARIO_FIM");
  noite.append(elemento("h3", {}, [
    iconeDeMenu("Dia e noite", "ajustar"),
    elemento("span", { texto: comecaAs && terminaAs
      ? `À noite, das ${comecaAs} às ${terminaAs}` : "À noite" }),
  ]));
  const frases = [];
  if (vale("LOGO_MODO") === "hora" && vale("LOGO_NOITE")) {
    /* "logo", e não "gato": a aba passou a se chamar `Logo do sistema` em
     * 06/09/2026, e o vocabulário da home tem de ser o mesmo — o VALOR continua
     * sendo o nome de um gato quando é o de fábrica, e é ele que aparece aqui. */
    frases.push(`A logo da dock passa a ser ${maiuscula(vale("LOGO_NOITE"))}`
      + (vale("FASTFETCH_LOGO_MODO") === "espelho" && vale("LOGO_DIA")
         ? `, e o do terminal, ${maiuscula(vale("LOGO_DIA"))}.` : "."));
  }
  if (liga("WALLPAPER_NOITE")) {
    frases.push("O carrossel sorteia só entre as imagens escuras.");
  }
  if (liga("LEITURA_AGENDA")) {
    const textura = Number(vale("LEITURA_TEXTURA") || 0);
    const rampa = Number(vale("LEITURA_RAMPA_MIN") || 0);
    frases.push(`A tela esquenta até ${vale("LEITURA_TEMPERATURA")} K`
      + (textura > 0 ? ` e ganha ${Math.round(textura * 100)} % de textura de papel` : "")
      + (rampa > 0 ? `, em ${rampa} min de rampa.` : "."));
  } else {
    frases.push("O modo de leitura fica desligado.");
  }
  noite.append(elemento("p", { class: "home-linha", texto: frases.join(" ") }));

  /* DUAS PORTAS, E NENHUM NÚMERO CRAVADO — 06/09/2026.
   *   Este botão era um só, dizia "As 13 chaves que respondem «soltar o que
   *   muda de noite»" e levava a "Dia e noite". As duas metades estavam erradas
   *   depois de a Frente A partir a seção em duas:
   *     · o número. "Dia e noite" ficou com SEIS chaves; as outras sete
   *       (`LEITURA_*`) mudaram-se para "Modo de leitura". Treze era a soma de
   *       antes, e um número escrito à mão numa página derivada envelhece na
   *       primeira vez que alguém mexe no arquivo — foi o que aconteceu;
   *     · o destino. Este bloco fala das DUAS coisas (o carrossel e a logo, que
   *       são de "Dia e noite"; a tela quente, que é de "Modo de leitura"), e
   *       mandava para uma só. Quem lesse "A tela esquenta até 3500 K" e
   *       clicasse aqui chegaria numa página onde essa chave não está.
   *   Agora a contagem é somada dos grupos, e há um botão por assunto que
   *   EXISTE — se um deles sumir do `meow.conf.exemplo`, o botão dele some
   *   junto, sem deixar um caminho morto na home. */
  for (const assunto of ["Dia e noite", "Modo de leitura"]) {
    const meus = GRUPOS.filter((g) => g.tipo === "chaves" && assuntoDe(g) === assunto);
    if (!meus.length) continue;
    const quantas = meus.reduce((s, g) => s + g.itens.length, 0);
    noite.append(elemento("button", {
      type: "button", class: "btn btn-mini",
      texto: `Abrir ${assunto}`,
      title: `${quantas} ${quantas === 1 ? "chave" : "chaves"} em «${assunto}»`,
      onclick: () => { ABA = assunto; gravarHash(); render(); },
    }));
  }
  caixa.append(noite);

  /* --- 4. a coluna da direita -------------------------------------------- */
  const lado = elemento("aside", { class: "home-lado" });
  lado.append(atencao);

  /* ONDE VOCÊ MEXEU — o único número da tela que não poderia existir em outro
   * painel, e que era um `<p>` cinza calculado uma vez. Aqui ele é a lista, e
   * cada nome leva ao cartão: doze fatos, não um adjetivo. */
  const diferentes = ESQUEMA.chaves.filter((i) => (i.valor ?? "") !== i.padrao);
  const bloco = elemento("section", { class: "home-mexeu" });
  bloco.append(elemento("h3", {}, [
    elemento("strong", { texto: String(diferentes.length) }),
    elemento("span", { texto: ` de ${ESQUEMA.chaves.length} mudados por você` }),
  ]));
  if (!diferentes.length) {
    bloco.append(elemento("p", { class: "home-nota", texto: "Tudo como vem de fábrica." }));
  } else {
    const fichas = elemento("div", { class: "home-fichas" });
    for (const i of diferentes) {
      const grupo = GRUPOS.find((g) => (g.itens || []).some((x) => x.chave === i.chave));
      fichas.append(elemento("button", {
        type: "button", class: "home-ficha",
        title: `${i.chave} · de fábrica: ${rotuloDeValor(i.padrao) || "nada"} · agora: ${rotuloDeValor(i.valor) || "nada"}`,
        texto: tituloDoCartao(i) || i.chave,
        onclick: grupo ? () => { ABA = chaveDeAba(grupo); gravarHash(); render(); } : null,
      }));
    }
    bloco.append(fichas);
  }
  lado.append(bloco);

  /* --- 5. o que se roda toda semana -------------------------------------- */
  const semana = elemento("section", { class: "home-semana" });
  semana.append(elemento("h3", { texto: "Toda semana" }));
  const linha = elemento("div", { class: "linha-botoes" });
  for (const [id, rotulo, principal] of [
    ["doctor", "Conferir a máquina", true],
    ["doctor_consertar", "Consertar o que estiver fora", false],
    ["wallpaper_proximo", "Próxima imagem", false],
    ["painel_reciclar", "Recarregar a barra", false],
  ]) {
    const acao = (ESQUEMA.acoes || []).find((a) => a.id === id);
    if (!acao) continue;
    linha.append(elemento("button", {
      type: "button", class: "btn" + (principal ? " btn-accent" : ""),
      "data-acao-rapida": id, texto: rotulo, title: acao.ajuda || "",
    }));
  }
  semana.append(linha);
  lado.append(semana);
  caixa.append(lado);
  return caixa;
}

function montarFolhas(folhas) {
  const caixa = elemento("div");
  caixa.append(elemento("p", {
    class: "frase nota-secao",
    texto: "As folhas que decidiram este tema, versionadas em docs/folhas/.",
  }));
  const grade = elemento("div", { class: "grade-folhas" });
  for (const f of folhas) {
    grade.append(elemento("a", {
      class: "folha",
      href: `/folha?id=${encodeURIComponent(f.arquivo)}`,
      target: "_blank",
      rel: "noopener",
      title: f.caminho,
    }, [
      elemento("b", { texto: maiuscula(f.arquivo.replace(/\.html$/, "").replace(/[-_]/g, " ")) }),
      elemento("span", { class: "oque", texto: f.arquivo }),
    ]));
  }
  caixa.append(grade);
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
/* MONTAR OS GRUPOS É UMA FUNÇÃO, e não um trecho do arranque — porque agora
 * há um segundo momento em que isso precisa acontecer: quando ela acrescenta
 * um arquivo ao acervo, o catálogo do servidor muda (as opções de `LOGO` são
 * a pasta `assets/gatos/`) e a página tem de se remontar sem recarregar. */
function montarGrupos() {
  GRUPOS = [];
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
    /* O TÍTULO DE QUEM HERDA O COMENTÁRIO VEM DA DIFERENÇA ENTRE AS IRMÃS.
   *   Quatro chaves do mesmo bloco — `FORMA_MARGEM_DOCK`, `FORMA_RAIO_DOCK`,
   *   `FORMA_ESPACO_DOCK`, `FORMA_RECHEIO_DOCK` — dividem o comentário, então
   *   dividiam o título. Usar a última parte do nome deu "Dock" nas quatro; o
   *   que as separa é `MARGEM/RAIO/ESPACO/RECHEIO`, no meio.
   *   Aqui as irmãs são comparadas parte a parte: o que é igual em todas sai,
   *   e o que sobra vira o título. `FORMA_RAIO_DOCK` -> "Raio",
   *   `LOGO_DIA` -> "Dia", `NOITE_INICIO` -> "Início".
   *   Se nada distinguir (nomes idênticos, que não existem), o título volta a
   *   ser a frase — nunca fica vazio. */
  for (const itens of porGrupo.values()) {
    /* O DONO DO COMENTÁRIO ENTRA NO GRUPO, e não só os herdeiros. Sem ele,
     * `WALLPAPER_BASE` (dono) e `WALLPAPER_INTERVALO` (herdeiro) formavam um
     * grupo de UM, a regra não disparava, e os dois continuavam com o mesmo
     * título. Quem divide o comentário divide o problema. */
    const irmas = new Map();
    for (const i of itens) {
      if (!i.ajuda) continue;
      if (!irmas.has(i.ajuda)) irmas.set(i.ajuda, []);
      irmas.get(i.ajuda).push(i);
    }
    for (const grupo of irmas.values()) {
      if (grupo.length < 2) continue;
      const partes = grupo.map((i) => i.chave.split("_"));
      const comuns = new Set(
        partes[0].filter((p) => partes.every((ps) => ps.includes(p))));
      for (const i of grupo) {
        const sobrou = i.chave.split("_").filter((p) => !comuns.has(p));
        if (!sobrou.length) continue;
        i.titulo_irmas = maiuscula(sobrou
          .map((p) => ROTULO_DE_VALOR[p.toLocaleLowerCase("pt-BR")]
                   || p.toLocaleLowerCase("pt-BR"))
          .join(" "));
      }
    }

    /* DESEMPATE ENTRE GRUPOS DIFERENTES DA MESMA ABA.
     *   Três pares da aba Automação — `AUTO_REPARO`/`_NOTIFICAR`,
     *   `ASSETS_VIGIA`/`_NOTIFICAR`, `FLATPAK_VIGIA`/`_NOTIFICAR` — não dividem
     *   comentário entre si, mas a diferença DENTRO de cada par é a mesma
     *   palavra: os três cartões viravam "Notificar". Aqui, quando dois títulos
     *   colidem na mesma aba, cada um recupera a palavra anterior do próprio
     *   nome: "Reparo notificar", "Vigia notificar", "Vigia notificar"… e o que
     *   ainda colidir volta para a frase, que é longa mas é distinta. */
    const palavra = (p) => ROTULO_DE_VALOR[p] || p;
    const daCauda = (chave, n) => {
      const partes = chave.split("_").map((x) => x.toLocaleLowerCase("pt-BR"));
      return maiuscula(partes.slice(-n).map(palavra).join(" ")
        .toLocaleLowerCase("pt-BR"));
    };
    /* Cresce da direita para a esquerda até parar de colidir: "Notificar" ->
     * "Vigia notificar" -> "Assets vigia notificar". Três voltas bastam para os
     * nomes deste arquivo; o que ainda colidir perde o título curto e volta
     * para a frase, que é longa mas distingue. */
    for (let n = 1; n <= 3; n++) {
      const contagem = new Map();
      for (const i of itens) {
        if (!i.titulo_irmas) continue;
        contagem.set(i.titulo_irmas, (contagem.get(i.titulo_irmas) || 0) + 1);
      }
      const colidem = itens.filter(
        (i) => i.titulo_irmas && contagem.get(i.titulo_irmas) > 1);
      if (!colidem.length) break;
      for (const i of colidem) {
        const maior = daCauda(i.chave, n + 1);
        i.titulo_irmas = maior === i.titulo_irmas ? null : maior;
      }
    }
  }

  GRUPOS = [...porGrupo].map(([nome, itens]) => ({
      tipo: "chaves", bloco: "ajustar", nome, itens,
      secaoPai: itens[0]?.secao || "Outras",
    }));

    /* As ações vêm agrupadas pelo `grupo` que o servidor declara — uma aba por
     * assunto, na ordem em que o dicionário as define. */
    const porAcao = new Map();
    for (const acao of ESQUEMA.acoes) {
      if (!porAcao.has(acao.grupo)) porAcao.set(acao.grupo, []);
      porAcao.get(acao.grupo).push(acao);
    }
    for (const [nome, itens] of porAcao) {
      /* GRUPO EM QUE TODA AÇÃO É OCULTA NÃO VIRA SEÇÃO.
       *   As duas ações dos jogos moram dentro da própria tela de jogos, como as
       *   de banir papel de parede moram dentro da galeria. Sem esta linha o
       *   menu ganharia um "Jogos da Steam" vazio ao lado do que tem as capas —
       *   dois botões com o mesmo nome, e o `ABA` casa por nome. */
      if (itens.every((a) => a.oculta)) continue;
      GRUPOS.push({ tipo: "acoes", nome, itens });
    }


    /* A galeria é um grupo do trilho como os outros — ela não é uma chave do
     * meow.conf, é o acervo em si, que neste projeto É a configuração ("soltou o
     * arquivo, entrou; apagou, saiu"). */
    /* ELAS NÃO DECLARAM BLOCO, E NÃO PRECISAM.
     *   A galeria e os ícones por aplicativo viviam numa aba "Fazer", ao lado do
     *   botão que roda o instalador. Olhar uma capa e escolher um desenho não é
     *   disparar um script — e são as telas em que ela passa mais tempo. Hoje
     *   cada uma entra no ASSUNTO a que pertence, e o bloco do assunto vem da
     *   tabela do servidor (ver `blocoDoAssunto`): as três caem em "Tópicos"
     *   porque nenhuma das três seções está na tabela, que é o padrão. */
    GRUPOS.push({ tipo: "galeria", assunto: "Papel de parede", nome: "A coleção", itens: [] });
    GRUPOS.push({ tipo: "apps", assunto: "Ícones", nome: "Um ícone por programa", itens: [] });
    /* O ASSUNTO É O NOME DA SEÇÃO DO `meow.conf.exemplo`, e ele mudou em
     * 06/09/2026: `Programas e jogos` virou `Lançadores e jogos`. Um assunto
     * declarado aqui que não case com o do arquivo NÃO dá erro — ele abre uma
     * décima terceira página no menu, com as capas dos jogos sozinhas, ao lado
     * da página de mesmo assunto que tem as quatro chaves. Duas páginas para um
     * assunto só é exatamente o que a unificação do menu desfez. */
    GRUPOS.push({ tipo: "jogos", assunto: "Lançadores e jogos", nome: "Os jogos instalados", itens: [] });

    /* AS FOLHAS SAÍRAM DO PAINEL — 06/09/2026: "remover estudos de tela, tem que
     * sair, é sobre meu pc". Elas são a memória do desenho, não um lugar onde se
     * mexe na máquina; continuam versionadas em docs/folhas/ e o servidor
     * continua sabendo abri-las. */

    /* A HOME É UM GRUPO, e é por isso que ela é a aba que abre por padrão
     * (`ABA = abaDoHash() || chaveDeAba(GRUPOS[0])`). Ela não é um assunto entre
     * os outros — é a porta, e por isso entra antes dos dois blocos do menu. */
    GRUPOS.unshift({ tipo: "home", nome: "Início", itens: [] });

    /* AS GALERIAS ENTRAM NO ASSUNTO A QUE PERTENCEM, e é por isso que a página
     * de papel de parede tem a coleção, os nove ajustes e as sete ações: os três
     * grupos respondem pelo mesmo assunto. O `render()` desenha na ordem desta
     * lista, então é aqui que eles se juntam — a galeria primeiro, porque é o
     * objeto; os ajustes depois; as ações no fim, que é a ordem em que se usa
     * uma página. */
    const ordemDosAssuntos = assuntosEmOrdem();
    const peso = { galeria: 0, apps: 0, chaves: 1, jogos: 1.5, acoes: 2 };
    const posicao = (g) => g.tipo === "home" ? -1 : ordemDosAssuntos.indexOf(assuntoDe(g));
    GRUPOS.sort((a, b) => (posicao(a) - posicao(b))
      || ((peso[a.tipo] ?? 3) - (peso[b.tipo] ?? 3)));

    GRUPOS_VISUAIS = new Set(
      GRUPOS.filter((g) => g.tipo === "chaves" && g.itens.some((i) => i.previa))
            .map((g) => g.nome));
    const chaveTema = ESQUEMA.chaves.find((k) => k.chave === "NOME_TEMA_ICONES");
    GRUPO_ICONES = chaveTema ? (chaveTema.subsecao || chaveTema.secao) : null;
    if (GRUPO_ICONES) GRUPOS_VISUAIS.add(GRUPO_ICONES);
    aplicarFundo();
}

async function iniciar() {
  ESQUEMA = await api("/api/esquema");
  if (ESQUEMA.erro) {
    $("#conteudo").append(elemento("p", { class: "vazio-msg", texto: ESQUEMA.erro }));
    return;
  }

  montarGrupos();

  /* O SECO SOBREVIVE AO F5.
   *   Dois validadores independentes pegaram o mesmo: o interruptor voltava
   *   DESLIGADO e calado depois de recarregar. Numa página cujo botão seguinte
   *   pode rodar o instalador, a rede de segurança tem de ser a coisa que mais
   *   lembra do estado. `sessionStorage` e não `localStorage`: vale enquanto a
   *   aba viver, que é o tempo de vida do próprio servidor.
   *
   *   O ESTADO É O `aria-pressed`, E POR ISSO ESTAS DOZE LINHAS MUDARAM JUNTO
   *   COM O CONTROLE. Com a caixa de marcar, restaurar era `.checked = true` e
   *   ouvir era `change`. Num `<button>` as duas são mudas: `.checked` não
   *   existe e `change` não dispara. A restauração escreve o atributo (que é o
   *   que o `estilo.css` lê para acender o amarelo, e o que o `ensaiando()` lê
   *   para decidir), e quem ouve é o `click`, que é o único evento que um botão
   *   de dois estados tem. */
  try {
    if (sessionStorage.getItem("meow-seco") === "1") {
      $("#seco").setAttribute("aria-pressed", "true");
    }
  } catch (e) { /* aba sem armazenamento: o padrão desligado continua valendo */ }
  $("#seco").addEventListener("click", () => {
    /* Vira o estado ANTES de gravar: o clique é o gesto, e o atributo é a
     * memória dele. Um `<button>` não vira sozinho como uma caixa de marcar
     * virava — quem inverte é esta linha. */
    const ligado = !ensaiando();
    $("#seco").setAttribute("aria-pressed", String(ligado));
    try {
      sessionStorage.setItem("meow-seco", ligado ? "1" : "0");
    } catch (e) { /* idem */ }
  });

  $("#botao-salvar").addEventListener("click", salvarEscolhas);
  $("#botao-descartar").addEventListener("click", descartarEscolhas);

  /* O menu do Exportar fecha ao clicar fora e no Esc. O `<details>` nativo não
   * faz nem uma coisa nem outra sozinho, e um menu que fica aberto atrás do
   * dedo dela é a diferença entre um botão e um estorvo. */
  const menu = $("#menu-exportar");
  document.addEventListener("click", (e) => {
    if (menu.open && !menu.contains(e.target)) menu.open = false;
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && menu.open) { menu.open = false; menu.querySelector("summary").focus(); }
  });
  /* Baixar não fecha a aba nem recarrega nada — mas o menu tem de sair da
   * frente, senão parece que o clique não fez efeito (o download acontece sem
   * pintar nada na tela). */
  for (const a of menu.querySelectorAll("a[download]")) {
    a.addEventListener("click", () => {
      menu.open = false;
      torrada("Baixando…", "igual");
    });
  }

  /* O `value = ""` no fim não é zelo: sem ele, escolher O MESMO arquivo duas
   * vezes seguidas não dispara `change`, e o segundo Importar não faz nada. */
  $("#arquivo-importar").addEventListener("change", async (e) => {
    const arquivo = e.target.files && e.target.files[0];
    e.target.value = "";
    await importarArquivo(arquivo);
  });

  ABA = abaDoHash() || chaveDeAba(GRUPOS[0]);
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
    `${ESQUEMA.chaves.length} ajustes · ${mexidas} mudados por você`
    + (ESQUEMA.conf_existe ? "" : " · o arquivo ainda não existe");
  $("#resumo").title = ESQUEMA.conf;

  render();
}

/* --- O PULSO: ESTA PÁGINA É O INTERRUPTOR DO SERVIDOR ----------------------
 * Pedido dela em 02/09/2026: "quando eu fechar ele via navegador ele ser
 * finalizado". Quem decide isso é o `servidor.py` (ver lá o bloco "O PAINEL
 * MORRE COM A JANELA QUE O ABRIU"); daqui sai só o sinal, e ele é uma conexão
 * que fica aberta — não uma batida por temporizador, que o Chrome estrangula em
 * aba oculta e congela de vez depois de alguns minutos.
 *
 * O `EventSource` reconecta sozinho quando cai, e é isso que faz o F5 e a troca
 * de papel de parede (que recarrega a página) não derrubarem o painel.
 *
 * O TOKEN VAI NO COOKIE, e tem de ir: `EventSource` não aceita cabeçalho
 * nenhum. O cookie de sessão que o servidor planta ao servir a página cobre
 * este pedido como cobre o `estilo.css`. */
try {
  const pulso = new EventSource("/api/pulso");
  /* Sem `onerror` o console enche de vermelho a cada reconexão — e a
   * reconexão é o comportamento CERTO, não um defeito para relatar. */
  pulso.onerror = () => {};
} catch (e) {
  /* Navegador sem EventSource: o servidor sai sozinho pela espera de
   * `MEOW_APP_ESPERA`, e o painel funciona igual até lá. */
}

iniciar();


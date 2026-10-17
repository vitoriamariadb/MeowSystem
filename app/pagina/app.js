/* app/pagina/app.js — monta a página a partir do que o servidor derivou.
 *
 * NÃO HÁ UM NOME DE CHAVE NESTE ARQUIVO, e isso é o ponto inteiro. O
 * `servidor.py` lê o `meow.conf.exemplo` e devolve, para cada chave, o que ela
 * é (opções, faixa, horário, lista), o que o exemplo traz de fábrica, o que o
 * meow.conf dela diz hoje e o comentário que explica a decisão.
 *
 * Clicar guarda a escolha na página (`MUDANCAS`), e ela atravessa abas, busca e
 * F5. */
"use strict";

/* --- o token, e o primeiro cuidado com ele -------------------------------- */
const TOKEN = document.body.dataset.token;
/* Fora da barra de endereço no primeiro instante: um token no histórico do
 * navegador sobrevive à sessão que o criou, e este não deve. */
if (location.search) {
  /* `+ location.hash` NÃO é detalhe: sem ele, esta linha — que roda antes de
   * tudo — levava o hash junto com o token, e abrir a página numa seção
   * específica nunca funcionava. */
  history.replaceState(null, "", location.pathname + location.hash);
}

const $ = (sel, raiz = document) => raiz.querySelector(sel);

async function api(rota, opcoes = {}) {
  /* O SERVIDOR PODE TER MORRIDO — e a página tem de dizer isso. O `fetch`
   * rejeita, a exceção sobe até o `onclick` e some — e ela fica clicando num
   * botão que não responde, sem saber que o problema não é o clique. */
  let resposta;
  try {
    resposta = await fetch(rota, {
      ...opcoes,
      headers: { "X-Meow-Token": TOKEN, "Content-Type": "application/json", ...(opcoes.headers || {}) },
    });
  } catch (e) {
    /* A faixa entra no primeiro erro de rede, fica até uma resposta chegar
     * inteira, e diz a verdade: a aba é o cofre, fechar é perder. */
    faixaSemServidor(true);
    return {
      erro: "O painel perdeu o servidor — veja a faixa no alto.",
      sem_servidor: true,
    };
  }
  faixaSemServidor(false);
  const texto = await resposta.text();
  let dados;
  try { dados = JSON.parse(texto); } catch { dados = { erro: texto }; }
  if (resposta.status === 409 && !dados.erro) {
    dados.erro = "Já há um trabalho rodando. Espere ele terminar (ou pare-o na gaveta).";
  }
  if (!resposta.ok && !dados.erro) dados.erro = "HTTP " + resposta.status;
  return dados;
}

/* --- estado --------------------------------------------------------------- */
let ESQUEMA = null;          // o que veio de /api/esquema

/* `previas-sistema.js` carrega ANTES deste arquivo (a ordem está no
 * index.html, e o exportador a repete), então ele não pode ler `ESQUEMA` no
 * corpo do módulo: quando aquele arquivo roda, este ainda não existe.
 *
 * Por que não deixar o desenho pedir ao servidor: ele desenha dezenas de vezes
 * por sessão (repinta enquanto ela arrasta o deslizante) e o número não muda
 * entre dois quadros. */
function publicarMedidas() {
  window.MEOW_MEDIDAS = (ESQUEMA && ESQUEMA.medidas) || {};
  window.MEOW_PACK = (ESQUEMA && ESQUEMA.pack) || null;
  /* (`controleCor`), e a legenda do desenho logo acima continuava dizendo
   * «o nome em mauve e a banda em green»: a mesma cor com dois nomes na
   * mesma tela. */
  window.MEOW_NOME_DA_COR = (slot) => nomeDaCor(slot, flavorEmVigor());
  /* Ver `parAplica`. */
  window.MEOW_PAR_APLICA = parAplica;
}
let GRUPOS = [];             // [{nome, chaves:[...]}] + as abas de ação e folhas
let ABA = null;              // qual grupo está aberto

/* --- A ABA MORA NA URL ------------------------------------------------------
 * Sem isto, `F5` devolvia ela para a primeira aba, e não havia como mandar a si
 * mesma (ou a mim) o endereço de uma seção — numa página de cem chaves em
 * dezoito grupos, "abre a galeria" virava instrução de três passos.
 *
 * O identificador é o nome do grupo achatado (sem acento, sem espaço), e não um
 * índice: índice muda quando um grupo nasce no meio, e o link guardado
 * apontaria para outra coisa sem avisar. */
function idDeAba(nome) {
  return semAcento(String(nome)).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

/* Enquanto "Fazer" era o único bloco de ações, o NOME bastava: nenhuma seção de
 * chave se chamava igual a um grupo de ação. */
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
 * texto lido no editor. */
/* Duas regras dela, no mesmo dia: "acentuação e primeira letra sempre
 * maiúscula" "temos que ter menos palavras na interface como um todo"
 *
 * O conflito aparente entre as duas se resolve assim: o que a página ESCREVE
 * por conta própria é curto e bem escrito; o que ela MOSTRA do meow.conf é
 * literal, porque é o valor que vai para o arquivo. */
const ROTULO_DE_VALOR = {
  sim: "Sim", nao: "Não", auto: "Auto", escuro: "Escuro", claro: "Claro",
  aleatoria: "Aleatória", alfabetica: "Alfabética", silencioso: "Silencioso",
  traco: "Traço", chapado: "Chapado",
  espelho: "Espelho", hora: "Hora", rotacao: "Rotação", fixo: "Fixo",
  nitida: "Nítida", preencher: "Preencher", caber: "Caber", esticar: "Esticar",
  /* Os valores que a tela mostrava crus, como o arquivo os escreve. `auto`,
   * `info` e `debug` apareciam DUAS VEZES neste objeto — a primeira definição
   * com o rótulo velho, logo acima, e esta com o novo. */
  auto: "Automático", info: "Informação", debug: "Detalhado",
  global: "Todas as áreas", workspace: "Só a atual",
  /* Os cinco valores de `FASTFETCH_LOGO_ALINHAR` moram na mesma fileira de
   * botões, e só os dois primeiros tinham apelido: a fileira misturava "Em
   * coluna", "Contornando", "degraus", "crescente", "reto". */
  tabular: "Em coluna", contorno: "Contornando",
  degraus: "Degraus", crescente: "Crescente", reto: "Reto",
  quadrante: "Médio", sextante: "Alto",
  /* O valor `port` do `TERMINAL_CURSOR` quer dizer "a cor que o Catppuccin
   * oficial escolheu para o cursor" (o rosewater; ver o bloco da chave no
   * meow.conf.exemplo). */
  accent: "Cor de destaque", port: "Do tema",
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
  /* O cartão do pack dizia «Dracula», o retrato «Drácula», e a «Variante do
   * tema» oferecia «Drácula» ao lado de «alucard» minúsculo: dois flavors do
   * mesmo pack com regras diferentes, porque só um deles tinha linha aqui. */
  coquinha: "Coquinha", mimir: "Mimir",
};

/** O nome que o PACK NO AR dá a um flavor dele, ou "". */
function nomeDoFlavor(v) {
  const f = ((ESQUEMA && ESQUEMA.pack && ESQUEMA.pack.flavors) || []).find((x) => x.id === v);
  return f ? f.nome : "";
}

/** O nome em português de uma cor da paleta, no flavor pedido — ou o slot.
 * Quem nomeia é o servidor, pelo hex (`_nomes_de_cor`): o slot é o valor
 * gravado, e o nome acompanha o pack no ar. */
function nomeDaCor(slot, flavor) {
  const f = ((ESQUEMA && ESQUEMA.pack && ESQUEMA.pack.flavors) || []).find((x) => x.id === flavor);
  return (f && f.nomes_de_cor && f.nomes_de_cor[slot]) || slot;
}

/** O rótulo VISÍVEL de um valor do conf. O valor gravado nunca muda. */
function rotuloDeValor(v) {
  if (v === "" || v == null) return "vazio";
  return ROTULO_DE_VALOR[v] || nomeDoFlavor(v) || v;
}

/** Primeira letra maiúscula, o resto intacto (nomes próprios sobrevivem). */
function maiuscula(txt) {
  if (!txt) return txt;
  return txt.charAt(0).toLocaleUpperCase("pt-BR") + txt.slice(1);
}

/** O título curto de um cartão: a primeira oração da explicação, sem ponto.
 *  Não inventa texto — só corta o que já está escrito no meow.conf.exemplo. */
/* O TÍTULO DA CHAVE DONA DO BLOCO DE COMENTÁRIO — vazio quando a chave tem o
 * bloco dela. */
function tituloDaDona(item) {
  if (!item.ajuda_de) return "";
  const dona = ESQUEMA.chaves.find((k) => k.chave === item.ajuda_de);
  return dona ? tituloDoCartao(dona) : item.ajuda_de;
}

function tituloDoCartao(item) {
  /* `LOGO_DIA` e `LOGO_NOITE` dividem o mesmo bloco de comentário, então os
   * dois cartões apareciam lado a lado com o título idêntico ("Os dois
   * rostos…") — o teste novo contou dezesseis repetições assim. */
  /* Derivar o título da primeira oração do comentário produziu "Reparo
   * notificar", "Vírgula-separado", "Base" e "Na virada". */
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
 * entra NA HORA"). */
const FUNCIONAIS_GRITADAS = new Set([
  "UM", "UMA", "NA", "NO", "NAS", "NOS", "EM", "DE", "DO", "DA", "DOS", "DAS",
  "E", "OU", "SE", "JÁ", "SÓ", "AO", "AOS", "À", "ÀS", "COM", "SEM", "POR",
  "QUE", "NÃO", "SIM", "TEM", "É", "SER", "VAI", "ELA", "ELE", "ISSO", "ESTE",
]);

function destacarSemGritar(txt) {
  /* Duas regras, e a segunda existe porque a primeira sozinha produziu "entra
   * NA Hora" — feio de um jeito novo: · palavra de quatro letras ou mais em
   * caixa alta é ênfase -> minúscula; · palavra funcional curta em caixa alta
   * (UM, NA, DE…) também é ênfase. */
  return txt.replace(/\b[\p{Lu}ÁÉÍÓÚÂÊÔÃÕÇ]{1,}\b/gu, (p) => {
    const letras = p.replace(/[^\p{L}]/gu, "");
    if (letras.length >= 4 || FUNCIONAIS_GRITADAS.has(p))
      return p.toLocaleLowerCase("pt-BR");
    return p;
  });
}

/* "tem muita mas muita palavra que ta poluindo desde menu ao titulo de secoes"
 *
 * Os títulos dos blocos do `meow.conf.exemplo` foram escritos para um ARQUIVO,
 * onde uma frase inteira ajuda: "A NOITE DA MÁQUINA, EM UM LUGAR SÓ", "O MODO
 * DE LEITURA, E O RELÓGIO QUE O LIGA SOZINHO".
 *
 * Nada é inventado e nada é traduzido: o nome inteiro continua no `title` e na
 * busca. */
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
   * proporção para 0,65 e o título escapava da conversão. */
  const limpo = txt.replace(/\([^)]*\)/g, "");
  const letras = [...limpo].filter((c) => /\p{L}/u.test(c));
  const gritado = letras.length && letras.filter((c) => c === c.toUpperCase()).length / letras.length > 0.7;
  if (!gritado) return txt;
  const baixo = txt.toLocaleLowerCase("pt-BR");
  return baixo.charAt(0).toLocaleUpperCase("pt-BR") + baixo.slice(1);
}

function elemento(tag, props = {}, filhos = []) {
  const el = document.createElement(tag);
  let ajuda = null;
  for (const [k, v] of Object.entries(props || {})) {
    if (k === "class") el.className = v;
    else if (k === "texto") el.textContent = v;
    else if (k === "html") el.innerHTML = v;
    /* Ele fica guardado e só é aplicado DEPOIS dos filhos, porque duas das
     * decisões do `porBalao` dependem do que o elemento escreve na tela: o
     * balão que repete o texto visível não nasce, e o elemento sem texto
     * nenhum precisa do balão como nome acessível. */
    else if (k === "title") ajuda = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (v === true) el.setAttribute(k, "");
    else if (v !== false && v != null) el.setAttribute(k, v);
  }
  for (const f of [].concat(filhos)) if (f) el.append(f);
  if (ajuda) porBalao(el, ajuda);
  return el;
}

const BALAO_LIMITE = 80;
const BALAO_ESPERA = 400;   // ms, e só para o rato

/* O que é comando e não frase: `meow …`, ou o caminho até o `bin/meow` e até
 * um script do projeto. */
const BALAO_COMANDO = /^(?:meow\s+[a-z]|[/~]\S*\/(?:meow|[\w.-]+\.sh)(?=\s|$))/;

/* Um caminho absoluto não é frase: cortá-lo pelo fim apagaria justamente o
 * nome do arquivo, que é a única parte que identifica alguma coisa. */
function encurtarCaminho(txt) {
  const partes = txt.split("/").filter(Boolean);
  let fim = partes[partes.length - 1] || txt;
  for (let i = partes.length - 2; i >= 0; i--) {
    const maior = partes[i] + "/" + fim;
    if (maior.length + 2 > BALAO_LIMITE) break;
    fim = maior;
  }
  /* O `filter(Boolean)` acima come a barra final, então um caminho de
   * DIRETÓRIO nunca era igual ao original e ganhava um "…/" que mentia:
   * `/home/<usuário>/Imagens/` voltava como `…/home/<usuário>/Imagens`, 26
   * caracteres, nada cortado, e a reticência anunciando que havia mais acima
   * de `/home`. */
  return fim === txt.replace(/^\/+/, "").replace(/\/+$/, "") ? txt : "…/" + fim;
}

/* A linha embaixo de cada cartão de ação imprimia o `argv` inteiro, com o
 * caminho absoluto na frente: `/home/<usuário>/…/bin/meow doctor`.
 *
 * O prefixo não é adivinhado nem escrito à mão: ele é o `ESQUEMA.raiz`, que o
 * servidor já manda porque é ele quem sabe de onde o painel está rodando.
 *
 *   1. `<raiz>/bin/meow …` vira `meow …`. Este é o comando que ela digita de
 *      verdade: o `install.sh` põe o `meow` no PATH, e `meow doctor` é como o
 *      README e a documentação inteira o escrevem.
 *   2. `<raiz>/qualquer/outro.sh …` vira `qualquer/outro.sh …`, relativo à
 *      raiz. Estes NÃO ganham nome curto porque não têm: o que se perde é só o
 *      prefixo repetido, e o que fica ainda diz qual script é. */
function semRaiz(caminho) {
  const raiz = String((ESQUEMA && ESQUEMA.raiz) || "").replace(/\/+$/, "");
  const txt = String(caminho == null ? "" : caminho);
  return raiz && txt.startsWith(raiz + "/") ? txt.slice(raiz.length + 1) : txt;
}

/* A casa da pessoa NÃO vem de uma expressão sobre `/home/`: ela é DERIVADA do
 * par que o cartão já tem na mão — o valor cru começa em `$HOME`, o efetivo
 * termina no mesmo resto, logo o que sobra na frente do efetivo é a casa dela,
 * seja ela `/home/<usuário>` ou qualquer outro lugar. */
function semCasa(cru, efetivo) {
  const m = /^\$(?:HOME\b|\{HOME\})/.exec(String(cru || ""));
  if (!m) return efetivo;
  const resto = String(cru).slice(m[0].length);
  return efetivo.endsWith(resto) ? "~" + resto : efetivo;
}

/* Um caminho com a casa trocada por `~`, como o gerenciador de arquivos mostra.
 * Só a casa INTEIRA: `/home/<nome>` não come o começo de `/home/<nome>zinho`. */
function comTil(caminho) {
  const casa = String((ESQUEMA && ESQUEMA.casa) || "").replace(/\/+$/, "");
  if (!casa || casa === "~") return caminho;
  return caminho === casa ? "~"
       : caminho.startsWith(casa + "/") ? "~" + caminho.slice(casa.length) : caminho;
}

/* Separa uma ajuda em «o que cabe no balão» e «o que é comando». É a única
 * porta: `elemento()` e o `porBalao()` passam por aqui, e o teste de
 * acessibilidade mede o resultado. */
function partirAjuda(txt) {
  let balao = String(txt == null ? "" : txt).trim();
  let comando = "";
  /* Quantos caracteres a rede teve de aparar, ou 0. É este número que o
   * `porBalao` pendura no elemento para o teste poder reprovar a apara — ver a
   * REDE, logo abaixo. */
  let aparado = 0;
  if (!balao) return { balao, comando, aparado };
  /* O comando entre parênteses, no fim da frase — a forma que os 119 balões da
   * galeria usavam. */
  balao = balao.replace(/\s*\(\s*(meow\s[^()]*)\)\s*$/, (m, cmd) => {
    comando = cmd.trim();
    return "";
  }).trim();
  /* O título que É um comando, sem frase à volta: nada se perde mandando-o
   * inteiro para o «ver comando», e o botão continua dizendo o que faz pelo
   * próprio rótulo. */
  if (!comando && BALAO_COMANDO.test(balao)) { comando = balao; balao = ""; }
  /* Os balões de ícone e de ponteiro são a origem do arquivo, e os curtos
   * cabiam inteiros em 80: `/home/<usuário>/.local/share/icons/…/btop.svg`, com
   * o nome de usuário, que a varredura das 14 abas achou em três deles. */
  if (balao.includes("/") && !/\s/.test(balao)) balao = encurtarCaminho(comTil(balao));
  if (balao.length > BALAO_LIMITE) {
    /* Toda frase fixa da página cabe em 80; o que chega aqui é texto montado
     * com dado de fora (um nome de arquivo, um valor de chave) que estourou.
     *
     * A rede apagava a própria pegada. */
    aparado = balao.length;
    const corte = balao.lastIndexOf(" ", BALAO_LIMITE - 1);
    balao = balao.slice(0, corte > 40 ? corte : BALAO_LIMITE - 1).trimEnd() + "…";
  }
  return { balao, comando, aparado };
}

function balaoFocavel(el) {
  return el.matches("a[href], button, input, select, textarea, summary, [tabindex]");
}

/* Põe (ou tira) o balão de um elemento. Substitui o `el.title = …` em toda a
 * página; o atributo nativo sai aqui, e não sobra em lugar nenhum. */
function porBalao(el, texto) {
  const { balao, comando, aparado } = partirAjuda(texto);
  el.removeAttribute("title");
  if (comando) el.dataset.comando = comando;
  else delete el.dataset.comando;
  /* A PEGADA DA REDE, para o teste ter o que reprovar. Não muda nada na tela:
   * é atributo de dado, e o balão já saiu aparado daqui. */
  if (aparado) el.dataset.balaoAparado = String(aparado);
  else delete el.dataset.balaoAparado;
  /* BALÃO QUE REPETE O QUE JÁ ESTÁ ESCRITO NÃO NASCE. Eram 42 na página: a
   * linha `<code class="cmd">` de cada cartão de ação levava no `title` o
   * mesmo comando que ela imprime dois centímetros abaixo. */
  const visivel = (el.textContent || "").trim();
  if (balao && balao !== visivel) el.setAttribute("data-balao", balao);
  else el.removeAttribute("data-balao");
  /* Num botão SEM texto — a bolinha de cor, o glifo — era o `title` que dava
   * nome ao botão para o leitor de tela. */
  if (balao && !visivel && !el.getAttribute("aria-label") && balaoFocavel(el))
    el.setAttribute("aria-label", balao);
}

/* --- o balão na tela ------------------------------------------------------ */
/* É UM SÓ na página, e isso é parte do conserto: dois balões ao mesmo tempo é
 * defeito do nativo, não recurso dele. */
let BALAO_EL = null;
let BALAO_DONO = null;
let BALAO_RELOGIO = null;

function esconderBalao() {
  clearTimeout(BALAO_RELOGIO);
  BALAO_RELOGIO = null;
  if (BALAO_DONO) BALAO_DONO.removeAttribute("aria-describedby");
  BALAO_DONO = null;
  if (BALAO_EL) BALAO_EL.hidden = true;
}

function mostrarBalao(alvo) {
  const texto = alvo.getAttribute("data-balao");
  if (!texto || !alvo.isConnected) return;
  if (!BALAO_EL) {
    BALAO_EL = elemento("div", { id: "balao", class: "balao", role: "tooltip" });
    document.body.append(BALAO_EL);
  }
  BALAO_EL.textContent = texto;
  BALAO_EL.hidden = false;
  /* A ÂNCORA É O CARTÃO, NÃO O BOTÃO — é daqui que sai a promessa de nunca
   * cobrir os irmãos. Sem cartão à vista (o botão solto do cabeçalho, uma
   * ficha), o próprio elemento serve. */
  const ancora = alvo.closest("figure, article.cartao, .acao, .bloco-acao, .ficha") || alvo;
  const r = ancora.getBoundingClientRect();
  /* Um balão curto num cartão da direita seguido de um longo na esquerda dava
   * altura maior que a real, e o longo nascia alguns px acima do cartão — ou
   * descia quando ainda cabia acima. */
  BALAO_EL.style.left = "0px";
  BALAO_EL.style.top = "0px";
  const cx = BALAO_EL.getBoundingClientRect();
  const lugar = lugarDoBalao(alvo, ancora, r, cx);
  BALAO_EL.classList.toggle("abaixo", lugar.lado === "abaixo");
  BALAO_EL.classList.toggle("ao-lado", lugar.lado === "direita" || lugar.lado === "esquerda");
  BALAO_EL.classList.toggle("a-esquerda", lugar.lado === "esquerda");
  BALAO_EL.style.left = `${Math.round(lugar.x)}px`;
  BALAO_EL.style.top = `${Math.round(lugar.y)}px`;
  alvo.setAttribute("aria-describedby", "balao");
  BALAO_DONO = alvo;
}

/* A regra «acima do cartão, ou abaixo se não couber» servia à grade, onde a
 * âncora é o cartão inteiro; no menu lateral a âncora é o próprio item, e o
 * balão de «Ícones — 8 ajustes e 4 ações» nascia em cima de «Logo do
 * sistema». */
function lugarDoBalao(alvo, ancora, r, cx) {
  const M = 8;
  const meioY = r.top + (r.height - cx.height) / 2;
  const deLado = Math.max(M, Math.min(r.left, innerWidth - cx.width - M));
  const candidatos = {
    acima: { x: deLado, y: r.top - cx.height - M },
    abaixo: { x: deLado, y: r.bottom + M },
    direita: { x: r.right + M, y: meioY },
    esquerda: { x: r.left - cx.width - M, y: meioY },
  };
  /* No menu, o vizinho que importa é o item do lado — é para ele que o rato
   * vai. O conteúdo da página à direita está fora do caminho do gesto. */
  const noMenu = alvo.closest("#trilho");
  const ordem = noMenu ? ["direita", "acima", "abaixo"] : ["acima", "abaixo", "direita", "esquerda"];
  const cabe = (c) => c.x >= M && c.y >= M
    && c.x + cx.width <= innerWidth - M && c.y + cx.height <= innerHeight - M;
  const vizinhos = [...(noMenu || document).querySelectorAll(
    "button, a[href], input, select, textarea, summary, [role=button], [role=tab]")]
    .filter((el) => !ancora.contains(el) && !el.contains(ancora))
    .map((el) => el.getBoundingClientRect())
    .filter((v) => v.width && v.height);
  const encosta = (c) => vizinhos.some((v) => v.left < c.x + cx.width && v.right > c.x
    && v.top < c.y + cx.height && v.bottom > c.y);
  for (const lado of ordem) {
    const c = candidatos[lado];
    if (cabe(c) && !encosta(c)) return { lado, ...c };
  }
  /* Sem lugar livre: o de antes — acima, ou abaixo quando não cabe acima. */
  const acima = candidatos.acima.y >= M;
  return acima ? { lado: "acima", ...candidatos.acima } : { lado: "abaixo", ...candidatos.abaixo };
}

/* Um ouvinte por botão seriam setecentos jogados fora a cada pintura da grade;
 * delegado no documento, o balão sobrevive ao `render()` sem saber dele. */
function ligarBalao() {
  document.addEventListener("mouseover", (e) => {
    const alvo = e.target.closest && e.target.closest("[data-balao]");
    if (!alvo || alvo === BALAO_DONO) return;
    esconderBalao();
    BALAO_RELOGIO = setTimeout(() => mostrarBalao(alvo), BALAO_ESPERA);
  });
  document.addEventListener("mouseout", (e) => {
    const saiu = e.target.closest && e.target.closest("[data-balao]");
    if (!saiu) return;
    if (e.relatedTarget && saiu.contains(e.relatedTarget)) return;
    clearTimeout(BALAO_RELOGIO);
    if (saiu === BALAO_DONO) esconderBalao();
  });
  /* O FOCO NÃO ESPERA, e é ele que faz esta troca não piorar o teclado. Só o
   * `:focus-visible` — clicar num botão também o foca, e ali o balão seria um
   * estorvo em cima do gesto que a pessoa acabou de fazer. */
  document.addEventListener("focusin", (e) => {
    const alvo = e.target.closest && e.target.closest("[data-balao]");
    clearTimeout(BALAO_RELOGIO);
    if (!alvo || !alvo.matches(":focus-visible")) return;
    esconderBalao();
    mostrarBalao(alvo);
  });
  document.addEventListener("focusout", (e) => {
    if (e.target === BALAO_DONO) esconderBalao();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") esconderBalao();
  });
  /* Rolar move o cartão e deixaria o balão parado no meio da tela. O `true`
   * é para ouvir a rolagem dos contêineres internos, não só a da janela. */
  addEventListener("scroll", esconderBalao, true);
  addEventListener("resize", esconderBalao);
  /* OS DOIS `title` QUE NÃO NASCEM NO `elemento()` moram no `index.html`
   * (Exportar e Importar). Esta varredura os adota na partida, e é também a
   * rede para qualquer `title` que apareça por fora daqui. */
  for (const el of document.querySelectorAll("[title]")) porBalao(el, el.getAttribute("title"));
}

function torrada(texto, classe = "") {
  if (classe && !["ok", "igual", "erro"].includes(classe)) classe = "erro";
  /* Quem repete a frase não está dizendo mais; está gritando. Enquanto uma
   * torrada com este exato texto estiver na tela, a nova não nasce — a que
   * existe ganha sobrevida. */
  for (const viva of $("#torradas").children) {
    if (viva.textContent === texto) {
      clearTimeout(viva._timer);
      viva._timer = setTimeout(() => viva.remove(), classe === "erro" ? 7000 : 2600);
      return;
    }
  }
  const el = elemento("div", { class: "torrada " + classe, texto });
  $("#torradas").append(el);
  /* O RATO SEGURA A TORRADA. `pointer-events` era none: impossível pausar a
   * leitura ou selecionar o texto de um erro para pesquisar. Com o ponteiro em
   * cima o relógio para; saindo, ela ainda vive um respiro. */
  el.addEventListener("mouseenter", () => clearTimeout(el._timer));
  el.addEventListener("mouseleave", () => {
    el._timer = setTimeout(() => el.remove(), 1500);
  });
  el._timer = setTimeout(() => el.remove(), classe === "erro" ? 7000 : 2600);
}

/* Agora: clicar guarda em `MUDANCAS`, que vive fora do render e por isso
 * atravessa a troca de aba, a busca e o recarregamento da grade. O cartão fica
 * marcado como não-salvo, o cabeçalho conta quantas esperam.
 *
 * Sem escolha esperando, `Salvar` aplica o que já está no disco. */
const MUDANCAS = new Map();   // chave -> valor escolhido e ainda não salvo

/* O valor sob o dedo, enquanto o dedo está no controle. */
let PROVISORIO = null;

function valorEmVigor(item) {
  /* A ORDEM É: o dedo, a escolha pendente, o disco. */
  if (PROVISORIO && PROVISORIO.chave === item.chave) return PROVISORIO.valor;
  return MUDANCAS.has(item.chave) ? MUDANCAS.get(item.chave) : (item.valor ?? "");
}

/** "0.9" e "0.90" são o mesmo número; o disco e a máquina não escrevem igual. */
function mesmoValor(a, b) {
  const numero = (x) => /^-?\d+(\.\d+)?$/.test(String(x));
  return String(a) === String(b) || (numero(a) && numero(b) && Number(a) === Number(b));
}

/** O que a tela dela mostra agora: a máquina, quando o servidor sabe lê-la
 * (`valendo_agora`); senão, o que está no meow.conf. */
function valorNaTela(item) {
  const agora = item.valendo_agora;
  return agora != null && agora !== "" ? agora : (item.valor ?? "");
}

/** O flavor que vale agora — a escolha pendente dela, ou o que está no disco. */
function flavorEmVigor() {
  const item = ESQUEMA.chaves.find((k) => k.chave === "FLAVOR");
  /* Caía em `"mocha"`, o padrão de UM pack: com o Dracula no ar e o FLAVOR
   * vazio, as amostras procuravam o mocha na paleta do Dracula e saíam sem
   * cor. */
  const pack = ESQUEMA.pack || {};
  return (item ? valorEmVigor(item) : "") || pack.flavor_padrao
    || Object.keys((ESQUEMA.paleta && ESQUEMA.paleta.flavors) || {})[0] || "";
}

/* O `meow_noite_janela` (lib/noite.sh) só usa as `NOITE_*` com as DUAS
 * preenchidas. */
const PAR_DA_NOITE = { NOITE_INICIO: "NOITE_FIM", NOITE_FIM: "NOITE_INICIO" };
function completarParDaNoite(chave, valor) {
  const irma = PAR_DA_NOITE[chave];
  if (!irma || !HORA_OK.test(String(valor)) || valeDaChave(irma) !== "") return;
  const j = janelaDoGato();
  const hora = irma === "NOITE_INICIO" ? j.ini : j.fim;
  const item = ESQUEMA.chaves.find((i) => i.chave === irma);
  if (item && HORA_OK.test(hora)) MUDANCAS.set(irma, hora);
}

function escolher(chave, valor, cartao) {
  const item = ESQUEMA.chaves.find((i) => i.chave === chave);
  if (!item) return;
  /* Em «Cor e tela» a escolha do pack ia para a bandeja e esperava o «Salvar e
   * aplicar»; na Início, o «Usar este» trocava na hora. Duas portas, dois
   * comportamentos para a mesma escolha. */
  if (chave === "PACK" && valor && valor !== (item.valor ?? "")) {
    usarPack(PACKS.find((p) => p.id === valor) || { id: valor, nome: rotuloDeValor(valor) });
    return false;
  }
  completarParDaNoite(chave, valor);
  const noDisco = item.valor ?? "";
  if (valor === noDisco) MUDANCAS.delete(chave);
  else MUDANCAS.set(chave, valor);
  if (cartao) {
    cartao.classList.toggle("nao-salvo", MUDANCAS.has(chave));
    cartao.classList.toggle("mexeu", valor !== item.padrao);
  }
  atualizarBarraSalvar();
  render();
  /* Os controles foram escritos contra o `gravar()` de antes, que devolvia se a
   * escrita deu certo: `onclick: async () => { if (await aplica(v)) pintar(v)
   * }`. */
  return true;
}

/* A faixa de servidor perdido. Um nó só, criado na primeira falha e removido
 * na primeira resposta inteira — sem contador de tentativas, sem pulso: quem
 * liga e desliga é o próprio `api()`, que é por onde toda conversa passa. */
function faixaSemServidor(mostrar) {
  let faixa = document.getElementById("faixa-sem-servidor");
  if (!mostrar) { if (faixa) faixa.remove(); return; }
  if (faixa) return;
  const n = MUDANCAS.size;
  faixa = elemento("div", { id: "faixa-sem-servidor", role: "alert" }, [
    elemento("strong", { texto: "O painel perdeu o servidor." }),
    elemento("span", {
      texto: n
        ? ` ${n === 1 ? "Sua escolha continua" : `Suas ${n} escolhas continuam`} nesta aba. O painel novo nasce em OUTRO endereço, então recarregar não reconecta: `
        : " Rode ./app/run.sh no terminal — o painel novo nasce em outro endereço.",
    }),
  ]);
  if (n) {
    /* O «Exportar» do menu baixa por /api/…, que agora é um beco; este arquivo
     * nasce no próprio navegador, no formato que o «Importar» do painel novo
     * confere chave a chave. */
    const blob = new Blob([
      "# Escolhas que esperavam o Salvar quando o painel caiu.\n"
      + "# No painel novo: Importar — cada linha volta a ser escolha pendente.\n"
      + [...MUDANCAS].map(([c, v2]) => `${c}="${String(v2).replace(/"/g, '\\"')}"`).join("\n")
      + "\n",
    ], { type: "text/plain" });
    const link = elemento("a", {
      class: "btn btn-mini",
      href: URL.createObjectURL(blob),
      download: "escolhas-pendentes.conf",
      texto: "Baixar as escolhas (.conf)",
      title: "Gerado aqui mesmo, sem servidor. No painel novo, use Importar.",
    });
    faixa.append(link, elemento("span", { texto: " e rode ./app/run.sh de novo." }));
  }
  document.querySelector("header").after(faixa);
}

/* Pior: a mensagem de servidor caído manda "feche esta aba e rode ./app/run.sh
 * de novo" — ou seja, mandava jogar fora o trabalho.
 *
 * O espelho vive no `sessionStorage` porque vale enquanto a aba viver, que é a
 * vida do próprio servidor. */
const BANDEJA_GUARDADA = "meow-bandeja";

function guardarBandeja() {
  try {
    if (MUDANCAS.size) {
      sessionStorage.setItem(BANDEJA_GUARDADA, JSON.stringify([...MUDANCAS]));
    } else {
      sessionStorage.removeItem(BANDEJA_GUARDADA);
    }
  } catch (e) { /* aba sem armazenamento: a bandeja vive só na memória, como antes */ }
}

function restaurarBandeja() {
  let pares;
  try {
    pares = JSON.parse(sessionStorage.getItem(BANDEJA_GUARDADA) || "[]");
  } catch (e) { return; }
  if (!Array.isArray(pares) || !pares.length) return;
  let vivas = 0;
  for (const par of pares) {
    if (!Array.isArray(par) || par.length !== 2 || typeof par[0] !== "string") continue;
    const [chave, valor] = par;
    const item = (ESQUEMA.chaves || []).find((i) => i.chave === chave);
    if (!item) continue;
    if (String(valor) === String(item.valor ?? "")) continue;
    MUDANCAS.set(chave, String(valor));
    vivas++;
  }
  if (vivas) {
    torrada(vivas === 1
      ? "1 escolha da sessão continua esperando o Salvar"
      : `${vivas} escolhas da sessão continuam esperando o Salvar`, "igual");
  }
}

function atualizarBarraSalvar() {
  guardarBandeja();
  const n = MUDANCAS.size;
  /* Agora o Salvar fica sempre; sem escolha ele aplica o que já está salvo. O
   * que acende e apaga são as peças de dentro: o contador, o Descartar e o
   * destaque do próprio botão. */
  $("#barra-salvar").classList.toggle("vazia", n === 0);
  $("#botao-descartar").hidden = n === 0;
  const salvar = $("#botao-salvar");
  salvar.classList.toggle("btn-accent", n > 0);
  porBalao(salvar, n
    ? "Grava as escolhas no meow.conf e aplica na máquina"
    : "Aplica na máquina o que já está salvo");
  const painel = document.getElementById("lista-pendentes");
  if (painel && (!n || painel.dataset.quantas !== String(n))) painel.remove();
  $("#salvar-conta").hidden = n === 0;
  if (!n) return;
  /* Agora o contador é clicável: cada linha diz o cartão pelo nome que a
   * página usa, o de → para pelos rótulos que os botões usam, e clicar nela
   * leva à aba da chave. */
  const conta = $("#salvar-conta");
  conta.textContent = n === 1 ? "1 escolha" : `${n} escolhas`;
  porBalao(conta, "Clique para ver quais são");
}

function abaDaChave(chave) {
  for (const g of GRUPOS) {
    if (g.tipo === "chaves" && (g.itens || []).some((i) => i.chave === chave)) return assuntoDe(g);
  }
  return null;
}

function alternarListaPendentes() {
  const aberto = document.getElementById("lista-pendentes");
  if (aberto) { aberto.remove(); return; }
  if (!MUDANCAS.size) return;
  const linhas = [];
  for (const [chave, valor] of MUDANCAS) {
    const item = (ESQUEMA.chaves || []).find((i) => i.chave === chave);
    if (!item) continue;
    const aba = abaDaChave(chave);
    linhas.push(elemento("button", {
      type: "button",
      class: "linha-pendente",
      onclick: () => {
        document.getElementById("lista-pendentes")?.remove();
        if (!aba) return;
        $("#busca").value = "";
        ABA = aba;
        gravarHash();
        render();
        /* O cartão da chave entra na tela — depois da pintura, senão não há
         * quem rolar até ele. */
        requestAnimationFrame(() => {
          const alvo = document.querySelector(`#conteudo .cartao[data-chave="${CSS.escape(chave)}"]`);
          if (alvo && alvo.scrollIntoView) alvo.scrollIntoView({ block: "center" });
        });
      },
    }, [
      elemento("span", { class: "p-nome", texto: (item && tituloDoCartao(item)) || chave }),
      elemento("span", {
        class: "p-troca",
        texto: `${rotuloDeValor(item.valor ?? "")} → ${rotuloDeValor(valor)}`,
      }),
      elemento("span", { class: "p-aba", texto: aba || "" }),
    ]));
  }
  const painel = elemento("div", { id: "lista-pendentes", "data-quantas": String(MUDANCAS.size) }, linhas);
  $("#barra-salvar").append(painel);
}

async function descartarEscolhas() {
  /* O Descartar mora a 8 px do «Salvar e aplicar» (medido), dispara na hora e
   * não tem desfazer: errar o dedo com catorze escolhas na bandeja custava a
   * sessão inteira. */
  if (MUDANCAS.size >= 2) {
    const ok = await perguntar({
      titulo: "Descartar as escolhas?",
      texto: `${MUDANCAS.size} escolhas ainda não salvas seriam jogadas fora. O meow.conf não é tocado.`,
      ok: "Descartar", neutro: true,
    });
    if (!ok) return;
  }
  MUDANCAS.clear();
  atualizarBarraSalvar();
  render();
  torrada("Escolhas descartadas — o meow.conf não foi tocado", "igual");
}

/* SALVAR = GRAVAR + APLICAR, nessa ordem e sem meio-termo.
 *
 * Eram N gravações em fila (0,45 s cada) e depois `rodarAcao("instalar")`, que
 * abria o diálogo de confirmação do instalador.
 *
 * SEM ESCOLHA ESPERANDO, O BOTÃO APLICA O QUE JÁ ESTÁ SALVO: é o gesto de quem
 * editou o meow.conf à mão, ou de quem acabou de salvar um ícone. */
/* Quem responde "o que estas escolhas fariam" é o `/api/salvar` com `seco:
 * true`, que passa as escolhas ao instalador como ambiente, sem tocar no
 * meow.conf (o porquê está lá).
 *
 * NÃO HÁ CAIXA DE CONFIRMAÇÃO NOS DOIS LADOS, e não é esquecimento: clicar em
 * «Salvar e aplicar» já É a confirmação (ver logo acima), e um ensaio que não
 * escreve nada tem ainda menos o que confirmar. */
async function salvarEscolhas(seco = false) {
  if (TRABALHO && TRABALHO.timer !== null) {
    torrada(`Espere «${TRABALHO.rotulo || "o trabalho"}» terminar`, "igual");
    abrirJanela();
    return;
  }
  const quantas = MUDANCAS.size;
  const botao = $(seco ? "#botao-ensaiar" : "#botao-salvar");
  botao.disabled = true;
  const anterior = botao.textContent;
  botao.textContent = seco ? "Ensaiando…" : quantas ? "Salvando…" : "Aplicando…";
  const r = await api("/api/salvar", {
    method: "POST",
    body: JSON.stringify({ mudancas: Object.fromEntries(MUDANCAS), seco }),
  });
  botao.disabled = false;
  botao.textContent = anterior;

  if (r.recusadas && r.recusadas.length) {
    for (const rec of r.recusadas.slice(0, 4)) {
      torrada(`${nomeVisivel(rec.chave)}: ${rec.erro}`, "erro");
    }
    torrada("Nada foi gravado, e nada foi aplicado", "erro");
    return;
  }
  /* O ENSAIO SAI POR AQUI, e é o caminho mais curto de propósito: tudo o que
   * vem abaixo é consequência de ter gravado — tirar chave da bandeja, repintar
   * cartão, limpar o aviso do alto. */
  if (seco) {
    if (!r.trabalho) { torrada(r.erro || "Não consegui ensaiar", "erro"); return; }
    torrada(quantas
      ? `Ensaio de ${quantas === 1 ? "1 escolha" : `${quantas} escolhas`} — nada será escrito`
      : "Ensaio do que já está salvo — nada será escrito", "igual");
    abrirResultado(r.trabalho, () => salvarEscolhas(false));
    return;
  }
  if (!r.gravadas) { torrada(r.erro || "Não consegui salvar", "erro"); return; }

  /* O DISCO MUDOU: o valor escolhido passa a ser o valor do cartão, e sai da
   * bandeja. */
  for (const chave of [...r.gravadas, ...(r.iguais || [])]) {
    const item = ESQUEMA.chaves.find((i) => i.chave === chave);
    if (item && MUDANCAS.has(chave)) item.valor = MUDANCAS.get(chave);
    MUDANCAS.delete(chave);
  }
  for (const f of (r.falhas || []).slice(0, 4)) {
    torrada(`${nomeVisivel(f.chave)}: ${f.erro}`, "erro");
  }
  atualizarBarraSalvar();
  render();

  if (!r.trabalho) {
    /* Gravou e não aplicou: outro trabalho corria na hora. O aviso fica, com o
     * botão que aplica, até um instalador passar. */
    for (const c of r.gravadas) PENDENTES.add(c);
    atualizarAviso();
    torrada(r.erro || "Gravado, mas ainda não aplicado", "erro");
    return;
  }
  torrada(quantas
    ? `${quantas === 1 ? "1 escolha gravada" : `${quantas} escolhas gravadas`} — aplicando`
    : "Aplicando o que está salvo", "ok");
  abrirResultado(r.trabalho);
}

/* O MODELO NÃO MUDOU — clicar guarda, salvar grava. O botão só existe enquanto
 * há pendência naquele cartão, e some ao ser usado — porque depois de gravado
 * não há mais nada para aplicar.
 *
 * A saída honesta, com o `app/servidor.py` fora dos arquivos desta frente, é
 * não inventar um caminho novo de escrita: este botão usa o MESMO `/api/salvar`
 * do «Salvar e aplicar», mandando apenas a chave deste cartão. */
async function aplicarCartao(item, botao) {
  if (!MUDANCAS.has(item.chave)) return;
  /* A MESMA GUARDA DO SALVAR: dois instaladores ao mesmo tempo é o 409 que o
   * servidor recusa, e a resposta certa é mostrar o trabalho que já corre. */
  if (TRABALHO && TRABALHO.timer !== null) {
    torrada(`Espere «${TRABALHO.rotulo || "o trabalho"}» terminar`, "igual");
    abrirJanela();
    return;
  }
  botao.disabled = true;
  botao.textContent = "Aplicando…";
  const r = await api("/api/salvar", {
    method: "POST",
    body: JSON.stringify({ mudancas: { [item.chave]: MUDANCAS.get(item.chave) } }),
  });
  botao.disabled = false;
  botao.textContent = "Aplicar";

  if (r.recusadas && r.recusadas.length) {
    torrada(`${nomeVisivel(item.chave)}: ${r.recusadas[0].erro}`, "erro");
    return;
  }
  if (!r.gravadas) { torrada(r.erro || "Não consegui salvar", "erro"); return; }
  /* O disco mudou: o valor escolhido vira o valor do cartão e sai da bandeja.
   * É o mesmo trecho do `salvarEscolhas`, e pelo mesmo motivo — sem ele o
   * cartão voltaria a mostrar o valor antigo até um F5. */
  for (const chave of [...r.gravadas, ...(r.iguais || [])]) {
    const alvo = ESQUEMA.chaves.find((i) => i.chave === chave);
    if (alvo && MUDANCAS.has(chave)) alvo.valor = MUDANCAS.get(chave);
    MUDANCAS.delete(chave);
  }
  for (const f of (r.falhas || []).slice(0, 4)) {
    torrada(`${nomeVisivel(f.chave)}: ${f.erro}`, "erro");
  }
  atualizarBarraSalvar();
  render();

  if (!r.trabalho) {
    /* Gravou e não aplicou: outro trabalho corria na hora. O aviso do alto fica,
     * com o botão que aplica, até um instalador passar. */
    for (const c of r.gravadas) PENDENTES.add(c);
    atualizarAviso();
    torrada(r.erro || "Gravado, mas ainda não aplicado", "erro");
    return;
  }
  torrada(`«${nomeVisivel(item.chave)}» gravado — aplicando`, "ok");
  abrirResultado(r.trabalho);
}

/* Ele lê o arquivo, manda o texto para o servidor conferir chave a chave, e o
 * que passa vira ESCOLHA PENDENTE — igual a um clique, com o cartão marcado e o
 * banner contando.
 *
 * Importar 96 chaves gravando seriam 43 segundos de página parada — para uma
 * operação que ela dispara ao escolher o arquivo errado por engano. */
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

  /* O `escolher()` redesenha a página a cada chamada, e chamá-lo noventa e seis
   * vezes seria noventa e seis reconstruções da árvore inteira. */
  for (const m of r.mudam) MUDANCAS.set(m.chave, m.valor);
  atualizarBarraSalvar();
  render();

  const partes = [];
  if (r.mudam.length) partes.push(`${r.mudam.length} esperando o Salvar`);
  if (r.iguais.length) partes.push(`${r.iguais.length} já estavam assim`);
  if (r.recusadas.length) partes.push(`${r.recusadas.length} recusadas`);
  if (r.desconhecidas.length) partes.push(`${r.desconhecidas.length} fora do catálogo`);
  torrada(partes.join(" · ") || "O arquivo não trazia nenhum ajuste",
          r.mudam.length ? "ok" : "igual");

  /* As recusas não cabem numa torrada e não podem sumir com ela: cada uma diz
   * qual ajuste e por quê, e é o que ela precisa para consertar o arquivo.
   *
   * AQUI O NOME CRU PODE SOBRAR, e está certo: uma linha recusada pode ser uma
   * chave que o esquema nem conhece (foi por isso que ela foi recusada), e o
   * `nomeVisivel` devolve o cru justamente nesse caso — é o único texto que ela
   * pode procurar no arquivo que está tentando importar. */
  if (r.recusadas.length) {
    for (const rec of r.recusadas.slice(0, 4)) {
      torrada(`${nomeVisivel(rec.chave)}: ${rec.erro}`, "erro");
    }
    if (r.recusadas.length > 4) {
      torrada(`…e mais ${r.recusadas.length - 4} recusadas`, "erro");
    }
  }

  /* O contador acima dizia "1 fora do catálogo" e parava aí. E o cabeçalho do
   * arquivo exportado recomenda exatamente essa rota de volta.
   *
   * Um número sem nome não deixa consertar: ela não tem como saber o que perdeu
   * nem onde procurar.
   *
   * O caso continua valendo para qualquer chave que o catálogo não conheça. */
  if (r.desconhecidas && r.desconhecidas.length) {
    for (const chave of r.desconhecidas.slice(0, 4)) {
      torrada(`${chave}: fora do catálogo — ficou como estava`, "igual");
    }
    if (r.desconhecidas.length > 4) {
      torrada(`…e mais ${r.desconhecidas.length - 4} fora do catálogo`, "igual");
    }
  }

  if (r.ausentes && r.ausentes.length) {
    const nomes = r.ausentes.slice(0, 3).map(nomeVisivel).join(", ");
    const resto = r.ausentes.length > 3 ? ` e mais ${r.ausentes.length - 3}` : "";
    torrada(`o arquivo não trazia ${nomes}${resto} — ficaram como estavam`, "igual");
  }
}

/* O `rodar()` volta quando a gaveta abre, e não quando o trabalho acaba; quem
 * quer o estado DEPOIS do passo espera aqui. */
function fimDoTrabalho() {
  return new Promise((pronto) => {
    const olhar = () => (TRABALHO ? setTimeout(olhar, 300) : pronto());
    olhar();
  });
}

/* Roda uma acao pelo id — o `Salvar` precisa disparar o instalador sem que
 * exista um cartao clicado para ele. */
async function rodarAcao(id, argumento) {
  const acao = (ESQUEMA.acoes || []).find((a) => a.id === id);
  if (!acao) { torrada(`Ação desconhecida: ${id}`, "erro"); return; }
  return rodar(acao, argumento);
}

/* --- escrita de um ajuste --------------------------------------------------- */
/* Ela salvava e lia "FASTFETCH_LOGO_ALINHAR = tabular".
 *
 * O nome cru NÃO SUMIU do painel: ele continua no pé do cartão, em `<code>`,
 * que é onde serve — procurar a linha no `meow.conf`.
 *
 * `nomeVisivel` cai no nome cru quando o esquema não conhece o ajuste. */
function nomeVisivel(chave) {
  const item = ESQUEMA.chaves.find((i) => i.chave === chave);
  return (item && tituloDoCartao(item)) || chave;
}

function atualizarAviso() {
  const aviso = $("#aviso-aplicar");
  const n = PENDENTES.size;
  if (!n) { aviso.hidden = true; return; }
  aviso.hidden = false;
  /* O banner conta "109 ajustes · 15 mudados por você" e a busca pede "um
   * ajuste ou uma ação": AJUSTE é a palavra que a página ensina na primeira
   * linha que ela lê. */
  $("#aviso-texto").textContent =
    n === 1
      ? "1 ajuste foi gravado no meow.conf e ainda não valeu na tela."
      : `${n} ajustes foram gravados no meow.conf e ainda não valeram na tela.`;
}

/* É a mesma regra que o `index.html` já aplicou à busca ("chave era o nome da
 * variável, e quem lê a tela nunca precisa saber o nome da variável"), e ela
 * vale mais aqui do que lá: no rótulo visível o nome cru ao menos aparece ao
 * lado do título, e no áudio ele é a ÚNICA coisa dita.
 *
 * `tituloDoCartao` e não `item.titulo`: metade dos cartões tem título derivado
 * (do vizinho dono do comentário), e o campo cru deixaria essa metade sem
 * rótulo nenhum. O `|| item.chave` no fim é o cinto — um cartão sem título
 * é melhor anunciado pelo nome cru do que por nada. */
function rotuloAcessivel(item) {
  return tituloDoCartao(item) || item.chave;
}

/* O cartão era uma caixa de texto com `cat-${FLAVOR}-${ACCENT}` dentro, a frase
 * «Deixe escrito com ${FLAVOR} e ${ACCENT}» embaixo e «Vale como:
 * cat-dracula-mauve» no pé — três linhas de sintaxe de shell pedidas a quem só
 * queria escolher uma cor.
 *
 * AS OPÇÕES SAEM DO SERVIDOR (`molde_pastas`), e ele as tira do DISCO e do
 * pack: todo flavor do pack no ar, e as cores que o papirus-folders tem. */
function partirMoldeDasPastas(valor) {
  const m = /^cat-(.+)-([^-]+)$/.exec(valor || "");
  return m ? { variante: m[1], cor: m[2] } : null;
}

/* O que as pastas vestem, em português — é o que o «Vale como» dizia em shell,
 * e o que a legenda do desenho da seção passa a dizer no lugar do molde. */
function descreverPastas(valor) {
  const item = ESQUEMA.chaves.find((k) => k.chave === "ICONES_PASTAS");
  const molde = item && item.molde_pastas;
  const partes = partirMoldeDasPastas(valor);
  if (!molde || !partes) return "";
  const nome = (lista, v) => ((lista.find((o) => o.valor === v) || {}).rotulo || v);
  const cor = partes.cor === "${ACCENT}" ? "na cor de destaque" : `em ${nome(molde.cores, partes.cor).toLowerCase()}`;
  const variante = partes.variante === "${FLAVOR}" ? "do tema" : nome(molde.variantes, partes.variante);
  return `pastas ${cor}, variante ${variante}`;
}

function controlePastas(item, aplica) {
  const molde = item.molde_pastas;
  const valor = valorEmVigor(item);
  const partes = partirMoldeDasPastas(valor);
  if (!partes) return null;
  /* O valor de agora entra na lista quando está fora dela — escrito à mão, ou
   * uma variante de outro pack. Esconder a opção faria o seletor mostrar outra
   * coisa como escolhida, e o próximo clique gravaria o que ela não pediu. */
  const opcoes = (lista, atual) => (lista.some((o) => o.valor === atual)
    ? lista : [...lista, { valor: atual, rotulo: maiuscula(atual) }]);
  const seletor = (rotulo, lista, atual) => {
    const sel = elemento("select", { "aria-label": `${rotulo} das pastas` });
    for (const o of opcoes(lista, atual)) sel.append(elemento("option", { value: o.valor, texto: o.rotulo }));
    sel.value = atual;
    return sel;
  };
  const selVariante = seletor("Variante", molde.variantes, partes.variante);
  const selCor = seletor("Cor", molde.cores, partes.cor);
  /* A amostra é a cor DA PALETA NO AR, pelo mesmo `var(--<slot>)` do desenho da
   * seção: o papirus-folders pinta com a paleta dele, e a diferença entre as
   * duas é de tom, não de cor. O desenho em cima diz o resto. */
  const amostra = elemento("span", { class: "pastas-amostra", "aria-hidden": "true" });
  const nota = elemento("div", { class: "selos" });
  const atualizar = () => {
    const cor = selCor.value;
    amostra.style.background = cor === "${ACCENT}" ? "var(--accent)" : `var(--${cor})`;
    nota.replaceChildren();
    if (molde.sem_upstream) {
      nota.append(selo("rede", { texto: "papirus-folders",
        balao: "As pastas ganham esta cor quando o instalador baixar o papirus-folders" }));
    } else if (selVariante.value === "${FLAVOR}" && molde.fora_do_papirus) {
      nota.append(selo("lua", { texto: "escura",
        balao: `Sem pastas «${molde.fora_do_papirus}»: saem na variante escura, na mesma cor` }));
    }
    nota.hidden = !nota.childElementCount;
  };
  const mudar = () => { atualizar(); aplica(`cat-${selVariante.value}-${selCor.value}`); };
  selVariante.addEventListener("change", mudar);
  selCor.addEventListener("change", mudar);
  atualizar();
  return elemento("div", { class: "pastas-molde" }, [
    elemento("div", { class: "pastas-seletores" }, [
      elemento("label", {}, [elemento("span", { texto: "Variante" }), selVariante]),
      elemento("label", {}, [elemento("span", { texto: "Cor" }), selCor, amostra]),
    ]),
    nota,
  ]);
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

  /* O MOLDE DAS PASTAS VEM ANTES DE TUDO, porque ele é texto para o esquema e
   * dois seletores para quem olha — ver `controlePastas`. */
  if (item.molde_pastas) {
    const c = controlePastas(item, aplica);
    if (c) return c;
  }

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
  /* O `controlePorArea` devolve `null` quando `AREAS_NOMES` está vazio, e o
   * comentário dele promete cair "no campo comum, que ao menos deixa escrever". */
  if (item.previa === "areas") {
    const c = controlePorArea(item, aplica);
    if (c) return c;
  }
  if (item.chave === "AREAS_NOMES") return controleAreas(item, aplica);

  /* 1. lista separada por vírgula -> fichas */
  if (item.lista || item.lista_pathsep) {
    const sep = item.lista_pathsep ? ":" : ",";
    const caixa = elemento("div", { class: "fichas" });
    const desenhar = () => {
      caixa.replaceChildren();
      const itens = (valorEmVigor(item) || "").split(sep).map((s) => s.trim()).filter(Boolean);
      for (const nome of itens) {
        /* Quando o servidor achou o `.desktop` do id (`item.programas`, ver o
         * `_dados_esquema`), a ficha mostra o ícone e o nome que o lançador
         * mostra, e o id vai para o balão: é ele que a linha do meow.conf
         * guarda, e é por ele que se procura no arquivo. */
        const programa = (item.programas || {})[nome];
        const rotulo = programa ? programa.nome : nome;
        caixa.append(elemento("span", {
          class: "ficha" + (programa ? " ficha-programa" : ""),
          title: programa ? nome : null,
        }, [
          programa && programa.icone
            ? elemento("img", { src: programa.icone, alt: "", width: "16", height: "16" })
            : null,
          elemento("span", { texto: rotulo }),
          elemento("button", {
            type: "button", "aria-label": `Tirar ${rotulo}`, texto: "×",
            onclick: async () => {
              const novos = itens.filter((x) => x !== nome);
              if (await aplica(novos.join(sep))) desenhar();
            },
          }),
        ]));
      }
      const entrada = elemento("input", {
        type: "text", class: "nova", placeholder: "+ acrescentar",
        "aria-label": `Acrescentar item a ${rotuloAcessivel(item)}`,
      });
      /* Só o Enter acrescentava, e nada na tela contava isso — o `+
       * acrescentar` do placeholder era a única pista. */
      const acrescentar = async () => {
        const novo = entrada.value.trim();
        if (!novo) return;
        if (itens.includes(novo)) { torrada(`${novo} já está na lista`, "igual"); return; }
        const novos = [...itens, novo];
        /* NÃO se escreve em `item.valor` aqui: aquilo é o que está NO DISCO, e
         * a escolha ainda não foi salva. */
        if (await aplica(novos.join(sep))) desenhar();
      };
      entrada.addEventListener("keydown", (ev) => {
        if (ev.key !== "Enter") return;
        ev.preventDefault();
        acrescentar();
      });
      /* `blur` e não `change`: o `change` de um `<input type=text>` só dispara
       * se o valor mudou DESDE O FOCO, e o `desenhar()` reconstrói o campo a
       * cada acréscimo — havia caso em que ele não vinha. */
      entrada.addEventListener("blur", () => { acrescentar(); });
      caixa.append(entrada);
    };
    desenhar();
    return caixa;
  }

  /* 2. horário -> <input type="time">, que já traz o teclado e a validação */
  if (item.horario) {
    const caixa = elemento("div", { class: "controle" });
    /* «A noite começa às» vazia aparecia `--:--`, com a Início dizendo «das
     * 18:00 às 07:00»: o campo vazio não é hora nenhuma, é «siga outra
     * janela». */
    const herdada = horaHerdada(item);
    const campo = elemento("input", {
      type: "time", value: valor || (herdada && herdada.hora) || "",
      class: valor === "" && herdada && herdada.hora ? "hora-herdada" : null,
      "aria-label": rotuloAcessivel(item),
      "aria-description": valor === "" && herdada && herdada.hora ? `${herdada.balao}: ${herdada.hora}` : null,
    });
    campo.addEventListener("change", () => aplica(campo.value));
    caixa.append(campo);
    if (herdada) {
      caixa.append(herdada.anulada
        ? selo("anulado", { balao: herdada.balao })
        : selo("herdado", { balao: herdada.balao }));
    }
    if (temOQueRestaurar(item, valor)) {
      caixa.append(elemento("div", { class: "faixa-estados" }, [
        botaoVazio(item, (v) => { campo.value = v; }, aplica)]));
    }
    return caixa;
  }

  /* 2b. hora cheia -> o mesmo <input type="time"> do horário, sem minutos. */
  if (item.hora_cheia) {
    const caixa = elemento("div", { class: "controle" });
    const emHora = (v) => (/^\d{1,2}$/.test(String(v ?? "")) ? `${String(v).padStart(2, "0")}:00` : "");
    const herdada = valor === "" ? emHora(item.vazio_vale) : "";
    const campo = elemento("input", {
      type: "time", step: "3600", value: emHora(valor) || herdada,
      class: herdada ? "hora-herdada" : null,
      "aria-label": rotuloAcessivel(item),
      "aria-description": herdada ? `Padrão: ${herdada}` : null,
    });
    campo.addEventListener("change", () => {
      const hora = /^(\d{1,2}):/.exec(campo.value);
      if (!hora) return;
      /* Os minutos não existem nesta chave: o campo volta à hora cheia. */
      campo.value = `${hora[1].padStart(2, "0")}:00`;
      aplica(String(Number(hora[1])));
    });
    caixa.append(campo);
    if (temOQueRestaurar(item, valor)) {
      caixa.append(elemento("div", { class: "faixa-estados" }, [
        botaoVazio(item, (v) => { campo.value = emHora(v) || emHora(item.vazio_vale); }, aplica)]));
    }
    return caixa;
  }

  /* 3. faixa numérica -> deslizante + número, os dois amarrados */
  if (item.faixa) {
    const [lo, hi, passo] = item.faixa;
    /* A régua do raio vem do comentário do `meow.conf.exemplo` («0 a 32 px»),
     * que é o teto de quando o compositor media pela caixa do frame anterior. */
    const teto = item.teto && item.teto.trava ? Number(item.teto.valor) : null;
    const topo = teto == null ? hi : String(Math.max(Number(lo), Math.min(Number(hi), teto)));
    const caixa = elemento("div", { class: "faixa" });
    /* Um deslizante em 0 diz "raio zero, canto reto", que é uma escolha
     * diferente e visível na tela dela. */
    /* A palavra especial vem das opções OU do próprio padrão: `MIDIA_FONTE`
     * nasce `auto` e não declara lista nenhuma — a palavra está no valor de
     * fábrica, que é onde o arquivo a diz. */
    /* Dois cliques antes do primeiro gesto. */
    const naoNumero = (v) => v && !/^[\d.,]+$/.test(v);
    const especial = (item.opcoes || []).find(naoNumero)
      || (naoNumero(item.padrao) ? item.padrao : null);
    const forcado = especial && valor === especial;
    const vazio = valor === "";
    const naRegua = !vazio && !forcado;
    /* O "COMO ESTÁ" DIZ QUANTO. Vazio é "não toca", e o que fica é o número que
     * a máquina já tem (`valendo_agora`); a alça para nele, e não no piso da
     * régua, que desenhava 0 onde a dock dela tem 24. */
    /* Sem número da máquina, o que o vazio vale pelo arquivo (`vazio_vale`):
     * «O tema escuro termina às» vazio é 7, e a alça para no 7. */
    const agora = item.valendo_agora ?? (vazio ? item.vazio_vale : null);
    const agoraNaRegua = agora != null && /^-?\d+(\.\d+)?$/.test(String(agora));
    const partida = agoraNaRegua
      ? String(Math.min(Number(topo), Math.max(Number(lo), Number(agora))))
      : naoNumero(String(item.padrao ?? "")) ? String(lo) : String(item.padrao || lo);
    const comoEsta = agoraNaRegua ? `como está: ${rotuloDeValor(agora)}` : "como está";
    const slider = elemento("input", {
      type: "range", min: lo, max: topo, step: passo,
      value: naRegua ? valor : partida,
      class: naRegua ? "" : "faixa-comoesta",
      "aria-label": rotuloAcessivel(item),
      /* O leitor de tela lê o `aria-valuetext` NO LUGAR do número, e é por isso
       * que ele é a peça obrigatória deste estado: é a única que não é visual. */
      "aria-valuetext": naRegua ? false
        : (forcado ? `${rotuloDeValor(valor)} — ninguém escolheu um número aqui`
                   : `${comoEsta} — ninguém escolheu, quem decide é o COSMIC`),
    });
    const saida = elemento("output", {
      class: naRegua ? "" : "como-esta",
      texto: naRegua ? String(valor || lo)
                     : (forcado ? rotuloDeValor(valor) : comoEsta),
    });
    slider.addEventListener("input", () => {
      saida.textContent = slider.value;
      slider.classList.remove("faixa-comoesta");
      slider.removeAttribute("aria-valuetext");
      saida.classList.remove("como-esta");
      /* Repintar aqui, e não no `change`: o `change` só dispara ao SOLTAR, e o
       * gesto inteiro de procurar um valor acontece antes disso. */
      repintarPrevia(item.chave, slider.value);
    });
    slider.addEventListener("change", () => aplica(slider.value));
    caixa.append(slider, saida);
    /* O selo diz o teto com o número e o porquê vai no balão; a frase inteira
     * do servidor continua na recusa do `validar_valor`, que é onde ela
     * decide alguma coisa. */
    if (item.teto) {
      const t = item.teto;
      caixa.append(t.estado === "clampa"
        ? selo("maquina", { balao: "Sem teto: o compositor desta sessão corta o excesso" })
        : t.estado === "experimental"
        ? selo("anulado", { texto: `${t.valor} px`,
            balao: `Modo experimental: acima de ${t.valor} px pode derrubar painel e dock` })
        : selo("anulado", { texto: `≤ ${t.valor} px`,
            balao: t.estado === "pendente"
              ? `Acima de ${t.valor} px, painel e dock caem até o próximo login`
              : `Acima de ${t.valor} px, painel e dock caem juntos nesta sessão` }));
    }

    const alternativas = elemento("div", { class: "faixa-estados" });
    /* O botão aparecia em todo deslizante que aceita vazio, e com a chave já
     * vazia ele dizia «Restaurar ao padrão (0)» sobre um valor que já É o
     * padrão: um botão que não muda nada, e que faz duvidar de qual dos dois
     * estados está valendo. */
    if (temOQueRestaurar(item, valor)) {
      /* «DEIXAR COMO ESTÁ» PROMETIA PRESERVAR E EXECUTAVA DESCARTAR */
      alternativas.append(elemento("button", {
        type: "button", class: "btn btn-mini",
        "aria-pressed": String(vazio),
        texto: rotuloVazio(item),
        title: tituloDoRestaurar(item),
        onclick: () => aplica(padraoDe(item)),
      }));
    }
    const naoToca = botaoNaoTocar(item, valor, aplica, "btn btn-mini");
    if (naoToca) alternativas.append(naoToca);
    if (especial && !forcado) {
      alternativas.append(elemento("button", {
        type: "button", class: "btn btn-mini",
        "aria-pressed": String(forcado),
        texto: rotuloDeValor(especial),
        onclick: () => aplica(especial),
      }));
    }
    /* O «USAR NÚMERO» SAIU DAQUI. Eram 17 botões na página, e a única função
     * de cada um era destravar o deslizante ao lado. Com a alça livre, o
     * gesto que ele substituía virou o gesto natural: arrastar. */
    if (alternativas.childNodes.length) caixa.append(alternativas);
    return caixa;
  }

  /* 4. opções -> segmentos até 5, <select> acima disso */
  if (item.opcoes.length) {
    /* 4a. DUAS OPÇÕES QUE MUDAM A FIGURA -> os dois desenhos, e eles são os
     *     botões. Ver o bloco `O PAR VIRA O CONTROLE`. Quando a figura não muda
     *     o bastante, cai nos segmentos de sempre — sem aviso e sem caixa
     *     vazia: uma frase explicando por que não há desenho, repetida em onze
     *     cartões, seria pior do que não ter desenho. */
    if (item.opcoes.length === 2) {
      const par = parDeBotoes(item, aplica);
      if (par) return par;
    }
    if (item.opcoes.length <= 5) {
      const caixa = elemento("div", { class: "segmentos" });
      const pintar = (v) => {
        for (const b of caixa.querySelectorAll("button")) {
          b.setAttribute("aria-pressed", String(b.dataset.valor === v));
        }
      };
      for (const opcao of item.opcoes) {
        caixa.append(elemento("button", {
          /* `item.rotulos` é o nome que o PACK NO AR dá à opção — «Macchiato
           * (herdado do Catppuccin)» na variante dos ícones de arquivo com o
           * Dracula no ar. */
          type: "button", "data-valor": opcao,
          texto: (item.rotulos && item.rotulos[opcao]) || rotuloDeValor(opcao),
          "aria-pressed": "false",
          onclick: async () => { if (await aplica(opcao)) pintar(opcao); },
        }));
      }
      /* , pela mesma regra do deslizante: com a chave vazia, o botão «Restaurar
       * ao padrão» aceso era a única coisa acesa da fileira e dizia «escolha
       * isto» sobre o que já estava escolhido. */
      /* O pack no ar é o `ESQUEMA.pack.id`, a mesma adoção do
       * `scripts/pack.py` que veste a máquina. */
      const naMaquina = item.valendo_agora != null ? item.valendo_agora
        : item.chave === "PACK" && ESQUEMA.pack ? ESQUEMA.pack.id : null;
      /* Com a chave vazia e nenhum degrau da máquina que a página saiba ler
       * («Tamanho de tudo na tela», que o servidor não lê no COSMIC), tirar o
       * ladrilho deixava a fileira sem nenhum botão marcado: um controle sem
       * estado. */
      const semComoEsta = naMaquina == null
        || !item.opcoes.some((o) => String(o) === String(naMaquina));
      const deFabrica = padraoDe(item);
      if (temOQueRestaurar(item, valor)) {
        caixa.append(elemento("button", {
          type: "button", class: "vazio", "data-valor": deFabrica === "" ? "" : null,
          texto: rotuloVazio(item),
          "aria-pressed": "false",
          title: tituloDoRestaurar(item),
          onclick: async () => { if (await aplica(deFabrica)) pintar(deFabrica); },
        }));
      }
      const naoToca = botaoNaoTocar(item, valor, aplica, "vazio", pintar);
      if (naoToca) caixa.append(naoToca);
      if (item.aceita_vazio && valor === "" && semComoEsta) {
        caixa.append(elemento("button", {
          type: "button", class: "vazio", "data-valor": "",
          texto: "como está",
          "aria-pressed": "false",
          title: "Devolve a decisão ao COSMIC.",
          onclick: async () => { if (await aplica("")) pintar(""); },
        }));
      }
      if (valor === "" && naMaquina != null) {
        const comoEsta = caixa.querySelector(
          `button[data-valor="${CSS.escape(String(naMaquina))}"]`);
        if (comoEsta) {
          comoEsta.classList.add("como-esta");
          porBalao(comoEsta, `Como está: ${rotuloDeValor(naMaquina)}`);
        }
      }
      pintar(valor);
      return caixa;
    }
    const caixa = elemento("div", { class: "controle" });
    const sel = elemento("select", { "aria-label": rotuloAcessivel(item) });
    /* «como está» é a palavra que o deslizante já usa para o mesmo estado. */
    if (item.aceita_vazio) sel.append(elemento("option", { value: "", texto: "— não tocar —" }));
    for (const opcao of item.opcoes) {
      sel.append(elemento("option", {
        value: opcao, texto: (item.rotulos && item.rotulos[opcao]) || rotuloDeValor(opcao) }));
    }
    sel.value = valor;
    sel.addEventListener("change", () => aplica(sel.value));
    caixa.append(sel);
    /* A opção continua (é o jeito de o `<select>` mostrar o vazio), e o botão
     * aparece ao lado quando há escolha para desfazer — é na mesma fileira que
     * o «Aplicar» do cartão entra. */
    if (temOQueRestaurar(item, valor)) {
      caixa.append(elemento("div", { class: "faixa-estados" }, [
        botaoVazio(item, (v) => { sel.value = v; }, aplica)]));
    }
    return caixa;
  }

  /* DURAÇÃO SEM LISTA -> número em minutos. */
  if (item.tipo_numero === "duracao" && !item.opcoes.length && !item.faixa) {
    const minutos = minutosDaDuracao(valor === "" ? item.padrao : valor);
    if (minutos !== null) {
      const caixa = elemento("div", { class: "controle controle-minutos" });
      const campo = elemento("input", {
        type: "number", min: "0", step: "1", inputmode: "numeric",
        value: String(minutos), "aria-label": `${rotuloAcessivel(item)}, em minutos`,
      });
      campo.addEventListener("change", () => {
        const n = Math.max(0, Math.round(Number(campo.value)));
        if (!Number.isFinite(n)) return;
        campo.value = String(n);
        aplica(`${n}m`);
      });
      campo.addEventListener("keydown", (ev) => {
        if (ev.key === "Enter") { ev.preventDefault(); campo.blur(); }
      });
      caixa.append(campo, elemento("span", { class: "unidade", "aria-hidden": "true", texto: "min" }));
      return caixa;
    }
  }

  /* 5. o resto -> texto. Caminho longo ganha uma <textarea> para caber. */
  const caixa = elemento("div", { class: "controle" });
  const longo = valor.length > 46;
  const campo = elemento(longo ? "textarea" : "input", {
    type: longo ? false : "text",
    "aria-label": rotuloAcessivel(item),
    placeholder: item.aceita_vazio
      ? (item.valendo_agora != null && item.valendo_agora !== ""
        ? `como está: ${rotuloDeValor(item.valendo_agora)}` : "como está")
      : item.padrao,
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
  if (temOQueRestaurar(item, valor)) {
    caixa.append(elemento("div", { class: "faixa-estados" }, [
      botaoVazio(item, (v) => { campo.value = v; }, aplica)]));
  }
  return caixa;
}

/* O «DEIXAR COMO ESTÁ» DIZ COMO ESTÁ. Vazio é "não toca", e o que fica é o que
 * a máquina tem; quando o servidor sabe ler isso, o botão diz, e a escolha
 * deixa de ser feita às cegas. */
/* Eram 31 botões na página com a palavra errada. */
/* `30m` -> 30, `2h` -> 120, `0` -> 0; `null` quando não dá minutos inteiros
 * (ou não é duração). As unidades são as do `segundos_de` do `wallpaper.sh`:
 * s, m e h, e o número sem unidade é segundos. */
function minutosDaDuracao(v) {
  const m = /^(\d+)([smh]?)$/.exec(String(v || "").trim());
  if (!m) return null;
  const n = Number(m[1]);
  const seg = m[2] === "h" ? n * 3600 : m[2] === "m" ? n * 60 : n;
  return seg % 60 === 0 ? seg / 60 : null;
}

/* A regra «só com escolha feita» olhava só o vazio, e três chaves que
 * aceitam vazio têm o valor de fábrica PREENCHIDO no meow.conf.exemplo
 * (`JANELAS_TILING="sim"`, `RELOGIO_SEGUNDOS="nao"`, o título do fastfetch). */
/* «Restaurar ao padrão» é voltar ao valor de fábrica, e ele gravava o vazio:
 * nas chaves de fábrica preenchida (`RELOGIO_SEGUNDOS="nao"`, «Janelas lado a
 * lado» = sim, `LEITURA_AGENDA`) o nome dizia uma coisa e o clique fazia outra,
 * com o valor da MÁQUINA no parêntese. */
function padraoDe(item) {
  if (item.padrao_do_pack != null) return String(item.padrao_do_pack);
  return item.padrao == null ? "" : String(item.padrao);
}

function temOQueRestaurar(item, valor) {
  return !!item.aceita_vazio && valor !== padraoDe(item);
}

function rotuloVazio(item) {
  const deFabrica = padraoDe(item);
  if (deFabrica !== "") return `Restaurar ao padrão (${rotuloDeValor(deFabrica)})`;
  const agora = item.valendo_agora;
  return agora != null && agora !== ""
    ? `Restaurar ao padrão (${rotuloDeValor(agora)})`
    : "Restaurar ao padrão";
}

function tituloDoRestaurar(item) {
  return padraoDe(item) === "" ? "Devolve a decisão ao COSMIC." : "Volta ao valor de fábrica.";
}

function botaoVazio(item, limpar, aplica) {
  const deFabrica = padraoDe(item);
  return elemento("button", {
    type: "button", class: "btn", texto: rotuloVazio(item),
    title: tituloDoRestaurar(item),
    onclick: async () => { if (await aplica(deFabrica)) limpar(deFabrica); },
  });
}

/* O «NÃO TOCAR» — o vazio da chave cuja fábrica não é o vazio (decisão 10). Só
 * com uma escolha feita: com a chave já vazia não há o que devolver. */
function botaoNaoTocar(item, valor, aplica, classe, depois) {
  if (!item.aceita_vazio || padraoDe(item) === "" || valor === "") return null;
  return elemento("button", {
    type: "button", class: classe, "data-valor": "", "aria-pressed": "false",
    texto: "Não tocar", title: "Devolve a decisão ao COSMIC.",
    onclick: async () => { if (await aplica("") && depois) depois(""); },
  });
}


/* Sem as imagens fica difícil."
 *
 * QUEM DECIDE QUE PRÉVIA CADA CHAVE GANHA É O SERVIDOR, e ele decide olhando o
 * CONTEÚDO da chave, não o nome (ver `_tipo_de_previa`, em servidor.py). */

/* O fundo de teste vale para a página inteira e é lembrado — é o mesmo gesto
 * das folhas visuais, onde quatro pílulas repintam todos os cartões de uma vez.
 *
 * Eram «Mocha» e «Latte»: com o Dracula no ar a barra oferecia dois flavors do
 * Catppuccin, e os dois pintavam o fundo de nada, porque a paleta no ar não os
 * tem. */
const FUNDOS = [
  { id: "escuro", rotulo: "Escuro", varr: "--fundo-escuro" },
  { id: "vidro-escuro", rotulo: "Vidro escuro", varr: "--fundo-vidro-escuro" },
  { id: "vidro-claro", rotulo: "Vidro claro", varr: "--fundo-vidro-claro" },
  { id: "claro", rotulo: "Claro", varr: "--fundo-claro" },
];
let FUNDO = FUNDOS[0];
/* A página que mostra a fileira: a do nome da seção do
 * meow.conf.exemplo, «Cor e tela». */
const PAGINA_DO_FUNDO = "Cor e tela";

function aplicarFundo() {
  document.documentElement.style.setProperty("--fundo-teste", `var(${FUNDO.varr})`);
}

function barraDeFundos() {
  const caixa = elemento("div", { class: "fundos" }, [elemento("b", { texto: "Fundo" })]);
  for (const f of FUNDOS) {
    caixa.append(elemento("button", {
      type: "button", "aria-pressed": String(f.id === FUNDO.id),
      /* Minúscula no meio da frase: «Ver sobre Escuro» lia como nome
       * próprio. O `rotulo` fica maiúsculo no botão, onde abre. */
      title: `Ver sobre ${f.rotulo.toLocaleLowerCase("pt-BR")}`,
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

/* Era feito uma vez, ao abrir a página. Quem relê o catálogo redesenha o resumo
 * junto. */
function pintarResumo() {
  /* O ajuste de um programa que a máquina não tem (`sem_programa`) não ganha
   * cartão nem conta como mudado na Início; aqui ele ainda contava, e uma casa
   * com a chave preenchida e sem o programa via o topo e a Início discordarem
   * por um. */
  const mexidas = ESQUEMA.chaves.filter((i) => !i.sem_programa
    && (i.valor ?? "") !== i.padrao).length;
  $("#resumo").textContent =
    /* O caminho do meow.conf saiu da linha e foi para o `title`: ele tem 44
     * caracteres, aparece em toda tela e nunca muda. Fica o que muda. */
    `${ESQUEMA.chaves.length} ajustes · ${mexidas} mudados por você`
    + (ESQUEMA.conf_existe ? "" : " · o arquivo ainda não existe");
  porBalao($("#resumo"), ESQUEMA.conf);
}

/** Relê o catálogo do servidor sem perder as escolhas ainda não salvas. */
async function recarregarEsquema() {
  const novo = await api("/api/esquema");
  if (novo && !novo.erro && novo.chaves) {
    ESQUEMA = novo;
    lerRestauros();
    pintarResumo();
    /* Uma etapa nova no install.sh no meio da sessão dela muda o desenho da
     * aba «Instalação» na releitura seguinte, sem F5. */
    publicarMedidas();
    /* A CLASSIFICAÇÃO DO PAR É CONTRA O DISCO, e o disco acabou de mudar. */
    PAR_VISIVEL.clear();
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

/* Um `.lugar` vazio no lugar da miniatura diz duas coisas ao mesmo tempo, e
 * nenhuma com clareza: "a imagem está vindo" e "esta opção está quebrada".
 *
 * O caminho é, letra por letra, o do ponteiro que o desenho da área de
 * trabalho usa (`previas-tela.js`): a mesma coisa na tela desenha-se com a
 * mesma figura. */
const CAMINHO_PONTEIRO = "M0,0 L0,9.4 L2.5,7.2 L4.1,10.8 L5.8,10 L4.2,6.5 L7.2,6.3 Z";

function silhuetaDePonteiro() {
  const NS = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(NS, "svg");
  svg.setAttribute("viewBox", "0 0 48 48");
  svg.setAttribute("width", "48");
  svg.setAttribute("height", "48");
  /* O rótulo do botão já diz o nome do tema; a figura é decoração dele. */
  svg.setAttribute("aria-hidden", "true");
  svg.setAttribute("style", "display:block;opacity:.55");
  const traco = document.createElementNS(NS, "path");
  traco.setAttribute("d", CAMINHO_PONTEIRO);
  /* O caminho nasce num quadro de 7,2 x 10,8; o 3,6 o leva a 25,92 x 38,88
   * dentro do viewBox de 48, e o translate o centra — com a conta feita, não
   * no olho: (48 - 25,92)/2 = 11,04 e (48 - 38,88)/2 = 4,56. */
  traco.setAttribute("transform", "translate(11.04,4.56) scale(3.6)");
  traco.setAttribute("fill", "none");
  traco.setAttribute("stroke", "currentColor");
  traco.setAttribute("stroke-width", "0.6");
  traco.setAttribute("stroke-linejoin", "round");
  traco.setAttribute("stroke-linecap", "round");
  svg.append(traco);
  return svg;
}

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
    const miniatura = p && p.pronta
      ? elemento("img", { src: p.url, alt: "", loading: "lazy" })
      /* Sem item na lista de prévias não há miniatura a esperar: o `.lugar`
       * ficaria ali para sempre, e um cartão vazio é indistinguível de um
       * cartão quebrado. A silhueta diz o que é. */
      : !p && tipo === "cursor"
        ? silhuetaDePonteiro()
        : elemento("div", { class: "lugar", style: "width:48px;height:48px;border-radius:6px" });
    const botao = elemento("button", {
      type: "button", "data-valor": opcao, "aria-pressed": "false",
      /* O que fica identifica o arquivo. */
      title: p ? semRaiz(p.origem) : opcao,
      onclick: async () => { if (await aplica(opcao)) pintar(opcao); },
    }, [miniatura, elemento("span", { texto: rotuloDeValor(opcao) })]);
    caixa.append(botao);
  }
  /* As duas chaves (`FASTFETCH_LOGO_DIA/NOITE`) nascem vazias, e vazio ali quer
   * dizer "herda a logo do dock" — uma escolha de verdade, e a que estava
   * valendo. */
  /* O botão vazio era um ladrilho «Restaurar ao padrão» do tamanho de um gato,
   * no meio dos gatos (print 13 do uso real), aceso justamente quando já
   * estava valendo. */
  const emVigor = valorEmVigor(item);
  if (temOQueRestaurar(item, emVigor)) {
    const deFabrica = padraoDe(item);
    caixa.append(elemento("button", {
      type: "button", class: "vazio", "data-valor": deFabrica === "" ? "" : null, "aria-pressed": "false",
      title: deFabrica === "" ? "Quem decide passa a ser o ajuste vizinho." : "Volta ao valor de fábrica.",
      texto: rotuloVazio(item),
      onclick: async () => { if (await aplica(deFabrica)) pintar(deFabrica); },
    }));
  }
  const naoToca = botaoNaoTocar(item, emVigor, aplica, "vazio", pintar);
  if (naoToca) caixa.append(naoToca);
  const herda = emVigor === "" && /herda\s+([A-Z][A-Z0-9_]+)/.exec(item.inline || "");
  const mae = herda && ESQUEMA.chaves.find((k) => k.chave === herda[1]);
  const herdado = mae && caixa.querySelector(
    `button[data-valor="${CSS.escape(String(valorEmVigor(mae)))}"]`);
  if (herdado) {
    herdado.classList.add("como-esta");
    porBalao(herdado, `Herdado de «${tituloDoCartao(mae) || mae.chave}»`);
  }
  pintar(emVigor);
  /* Os seis fazem exatamente a mesma coisa: o acervo é um só, e um arquivo
   * solto ali aparece nas seis listas ao mesmo tempo.
   *
   * É o mesmo defeito que o par painel+dock teve e que o selo "pode ensaiar"
   * teve — uma coisa que vale para a página inteira repetida uma vez por
   * cartão. */
  /* Era só o gato. O ponteiro tinha a mesma fileira de miniaturas e nenhuma
   * porta de entrada: "Temas do Ponteiro só aparece um" parecia defeito da
   * lista e não era. */
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

/* ACRESCENTAR AO ACERVO — o mesmo botão para tudo o que entra de fora
 *
 * "ela tem que integrar e atuar diretamente no repo local do user", e depois:
 * "é esse tipo de solução pra toda aba viu?".
 *
 * Um só componente, SEIS destinos.
 *
 * Mostrar isso como falha ensinaria a desconfiar de uma resposta correta. */
const ACERVO_ACEITA = {
  /* "Adicionar logo", e não "Adicionar gato". Quem chega sem gato nenhum ainda
   * pode pôr a própria marca no menu de lançamento, na dock e no terminal. */
  gato: { aceita: ".svg,image/svg+xml", rotulo: "Adicionar logo" },
  parede: { aceita: "image/jpeg,image/png,image/webp", rotulo: "Adicionar imagem" },
  icone: { aceita: ".svg,image/svg+xml", rotulo: "Adicionar ícone" },
  cursor: { aceita: ".zip", rotulo: "Adicionar tema", naMaquina: true },
  /* As três extensões são as do `instalar_fontes.sh adicionar`: um `.zip` de
   * Nerd Font, ou o arquivo de uma família solta. */
  fonte: { aceita: ".zip,.ttf,.otf", rotulo: "Adicionar fonte", naMaquina: true },
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
          body: JSON.stringify({ tipo, nome: arq.name, conteudo: b64 }),
        });
        if (r.erro) { torrada(r.erro, "erro"); return; }
        if (conf.naMaquina) {
          /* A torrada é ele, e não uma frase nossa que teria de adivinhar qual
           * dos casos foi. */
          torrada(r.depois || `${r.nome} instalado`, r.rc === 1 ? "ok" : "igual");
          /* A SAÍDA DO COMANDO VAI PARA A TELA, e não para o console: é a mesma
           * saída que ela leria no terminal, e é onde está o nome do tema que
           * acabou de entrar. */
          if (r.log) torrada(r.log.split("\n").slice(-3).join(" · "), "igual");
          if (aoEntrar) await aoEntrar();
          return;
        }
        /* Antes ela soltava o arquivo e não sabia se ele entrava no grupo de
         * dia ou no de noite: quem separa é a luminância, e só na próxima
         * vez que o carrossel reaplica. */
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

/* O `install.sh` recusa a combinação sem captura (o pré-voo avisa), mas só
 * DEPOIS — ela escolhe, salva, roda o instalador e leva o não. */
/* O servidor manda, por flavor, os acentos que aplicam e, quando nenhum
 * aplica, o porquê (`acentos_que_aplicam`) — a mesma conta que o instalador
 * faz. */
function combinacaoTemCaptura() {
  const capturas = (ESQUEMA.capturas || []).map((c) => String(c).toLowerCase());
  const aplicam = ESQUEMA.acentos_que_aplicam || {};
  if (!capturas.length && !Object.keys(aplicam).length) return null;
  const f = flavorEmVigor();
  const item = ESQUEMA.chaves.find((k) => k.chave === "ACCENT");
  const a = item ? valorEmVigor(item) : "";
  if (!f || !a) return null;
  const doFlavor = aplicam[f] || null;
  const existe = parAplica(f, a);
  return { par: `${f}-${a}`, existe, capturas, motivo: doFlavor ? doFlavor.motivo : "" };
}

/* O desenho de «Cor e tela» precisa saber se um par aplica para não prometer a
 * cor de uma variante sem tema; ele a recebe por `window.MEOW_PAR_APLICA` (ver
 * `publicarMedidas`), e a conta é esta, a do cartão. */
function parAplica(f, a) {
  const capturas = (ESQUEMA.capturas || []).map((c) => String(c).toLowerCase());
  const aplicam = ESQUEMA.acentos_que_aplicam || {};
  if (!capturas.length && !Object.keys(aplicam).length) return null;
  const doFlavor = aplicam[f] || null;
  return capturas.includes(`${f}-${a}`)
    || !!(doFlavor && (doFlavor.acentos || []).includes(a));
}

/* Com FLAVOR=alucard e «Claro ou escuro» em escuro, a prévia desenhava uma tela
 * clara, a página se vestia de claro e o desktop ficava escuro. */
function avisoDeLado() {
  const pack = ESQUEMA.pack || {};
  const f = flavorEmVigor();
  const lados = (pack.lados || {})[f];
  const modoItem = ESQUEMA.chaves.find((k) => k.chave === "MODO");
  const modo = (modoItem && (valorEmVigor(modoItem) || modoItem.efetivo)) || "";
  if (!lados || modo !== "escuro" || !lados.escuro || lados.escuro === f) return null;
  const nome = (id) => ((pack.flavors || []).find((x) => x.id === id) || {}).nome || id;
  /* O selo diz o que se vê na tela agora: no escuro, a outra variante. */
  return {
    selo: selo("lua", { texto: encurtarValor(nome(lados.escuro)),
                        balao: `No escuro, a tela veste o ${nome(lados.escuro)}` }),
    frase: elemento("p", { class: "frase dominada" }, [
      elemento("b", { texto: `${nome(f)} é o lado claro. ` }),
      elemento("span", {
        texto: `Com «Claro ou escuro» em escuro, a tela veste o ${nome(lados.escuro)}; `
          + `o ${nome(f)} aparece no claro, e de dia no automático.`,
      }),
    ]),
  };
}

function avisoDeCombinacao() {
  const c = combinacaoTemCaptura();
  if (!c || c.existe) return null;
  /* O porquê vem do derivador quando ele respondeu ("não há tema capturado do
   * frappe para derivar…"); a lista das fotografadas continua de reserva. */
  const porque = c.motivo
    ? `O tema do COSMIC fica como está: ${c.motivo}.`
    : `A etapa do tema vai ser pulada — o tema do COSMIC fica como está. Existem: ${c.capturas.join(", ")}.`;
  /* O selo é o ⊘ de «sem efeito»: com esta combinação o tema do COSMIC não
   * muda, e é isso que quem escolhe precisa ver antes de salvar. */
  return {
    selo: selo("anulado", { balao: `Não há tema para ${c.par}` }),
    frase: elemento("p", { class: "frase dominada" }, [
      elemento("b", { texto: `Não há tema para ${c.par}. ` }),
      elemento("span", { texto: porque }),
    ]),
  };
}

/* Errar uma letra era gravar uma linha que o `areas.sh` não casa com área
 * nenhuma — e ele não reclama, porque do ponto de vista dele a lista pode
 * nomear uma área que ainda vai existir.
 *
 * AS ÁREAS SAEM DO `valorEmVigor` DA CHAVE DE CIMA, e não do disco: se ela
 * acabou de renomear "OS" para "Trabalho" e ainda não salvou, é "Trabalho" que
 * tem de aparecer aqui. */
/* «Nomes das áreas de trabalho» era um campo de texto separado por vírgula
 * («Pop, OS»), e a chave inteira é sobre ORDEM: o cosmic-comp cria as áreas
 * alfinetadas na ordem desta lista (o comentário do `meow.conf.exemplo` conta
 * por que «Meow» vem antes de «OS»).
 *
 * O VAZIO NÃO É UMA LISTA VAZIA: é «as áreas são suas», e elas existem — o
 * servidor lê as do COSMIC (`valendo_agora`). */
function controleAreas(item, aplica) {
  const proprio = String(valorEmVigor(item) || "");
  const comoEsta = proprio === "";
  const nomes = (comoEsta ? String(item.valendo_agora || "") : proprio)
    .split(",").map((x) => x.trim()).filter(Boolean);
  const gravar = (lista) => aplica(lista.join(", "));
  const caixa = elemento("div", { class: "areas-pilulas" + (comoEsta ? " como-esta" : ""),
                                  role: "list", "aria-label": rotuloAcessivel(item) });
  let arrastada = -1;
  nomes.forEach((nome, i) => {
    const campo = elemento("input", {
      type: "text", value: nome, size: String(Math.max(3, nome.length)),
      /* O foco segue a ÁREA, e não a posição: Alt+← repinta a página, e o
       * campo de antes some — sem isto o segundo Alt+← não teria onde cair. */
      "data-foco": `area:${nome}`,
      "aria-label": `Área ${i + 1}: ${nome}`,
      title: "Alt+← e Alt+→ mudam a área de lugar",
    });
    const renomear = () => {
      const novo = campo.value.trim();
      if (!novo || novo === nome) { campo.value = nome; return; }
      const lista = nomes.slice(); lista[i] = novo; gravar(lista);
    };
    campo.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter") { ev.preventDefault(); renomear(); return; }
      if (ev.altKey && (ev.key === "ArrowLeft" || ev.key === "ArrowRight")) {
        ev.preventDefault();
        const j = i + (ev.key === "ArrowLeft" ? -1 : 1);
        if (j < 0 || j >= nomes.length) return;
        const lista = nomes.slice(); [lista[i], lista[j]] = [lista[j], lista[i]];
        gravar(lista);
      }
    });
    campo.addEventListener("blur", renomear);
    const pilula = elemento("div", { class: "area-pilula", draggable: "true", role: "listitem",
                                     "data-indice": String(i) }, [
      elemento("span", { class: "area-alca", "aria-hidden": "true",
                         html: '<svg viewBox="0 0 8 14"><circle cx="2" cy="3" r="1"/><circle cx="6" cy="3" r="1"/>'
                             + '<circle cx="2" cy="7" r="1"/><circle cx="6" cy="7" r="1"/>'
                             + '<circle cx="2" cy="11" r="1"/><circle cx="6" cy="11" r="1"/></svg>' }),
      campo,
    ]);
    pilula.addEventListener("dragstart", (ev) => {
      arrastada = i;
      pilula.classList.add("arrastando");
      try { ev.dataTransfer.setData("text/plain", nome); ev.dataTransfer.effectAllowed = "move"; } catch (e) { /* sem dataTransfer */ }
    });
    pilula.addEventListener("dragend", () => {
      pilula.classList.remove("arrastando");
      caixa.querySelectorAll(".soltar-antes, .soltar-depois")
        .forEach((p) => p.classList.remove("soltar-antes", "soltar-depois"));
    });
    /* A metade da pastilha onde o ponteiro está diz de que lado ela cai. */
    const lado = (ev) => {
      const r = pilula.getBoundingClientRect();
      return ev.clientX < r.left + r.width / 2 ? "antes" : "depois";
    };
    pilula.addEventListener("dragover", (ev) => {
      if (arrastada < 0 || arrastada === i) return;
      ev.preventDefault();
      const l = lado(ev);
      pilula.classList.toggle("soltar-antes", l === "antes");
      pilula.classList.toggle("soltar-depois", l === "depois");
    });
    pilula.addEventListener("dragleave", () => pilula.classList.remove("soltar-antes", "soltar-depois"));
    pilula.addEventListener("drop", (ev) => {
      if (arrastada < 0 || arrastada === i) return;
      ev.preventDefault();
      const lista = nomes.slice();
      const [movida] = lista.splice(arrastada, 1);
      let alvo = lista.indexOf(nome) + (lado(ev) === "depois" ? 1 : 0);
      lista.splice(alvo, 0, movida);
      arrastada = -1;
      gravar(lista);
    });
    caixa.append(pilula);
  });
  /* A pastilha do fim acrescenta: um nome a mais é uma área nova, herdando o
   * monitor de uma que já existe (o comentário da chave). */
  const nova = elemento("input", { type: "text", class: "area-nova", placeholder: "+",
                                   "aria-label": "Acrescentar uma área", size: "3" });
  const acrescentar = () => {
    const novo = nova.value.trim();
    if (!novo) return;
    if (nomes.includes(novo)) { torrada(`${novo} já é uma área`, "igual"); return; }
    gravar([...nomes, novo]);
  };
  nova.addEventListener("keydown", (ev) => { if (ev.key === "Enter") { ev.preventDefault(); acrescentar(); } });
  nova.addEventListener("blur", acrescentar);
  caixa.append(nova);
  return caixa;
}

/* A PRÉVIA REAL DAS ÁREAS: o applet de áreas do painel como ele desenha, uma
 * pastilha por área na ordem da lista, a primeira acesa, a folga invisível
 * alargando as que a levam e o traço do encaixe sob as que encaixam. */
function barraDasAreas(val) {
  const nomes = String(val.AREAS_NOMES || "").split(",").map((x) => x.trim()).filter(Boolean);
  const folga = new Set(String(val.AREAS_FOLGA || "").split(",").map((x) => x.trim()).filter(Boolean));
  const enc = String(val.AREAS_ENCAIXE || "").split(",").map((x) => x.trim());
  const encaixa = (i) => (enc.length === 1 ? enc[0] : enc[i]) === "sim";
  const barra = elemento("div", { class: "areas-barra", role: "img",
    "aria-label": nomes.length ? `Áreas, na ordem: ${nomes.join(", ")}` : "Nenhuma área com nome" });
  nomes.forEach((n, i) => {
    barra.append(elemento("span", {
      class: "areas-barra-area" + (i === 0 ? " acesa" : "") + (folga.has(n) ? " com-folga" : "")
             + (encaixa(i) ? " encaixa" : ""),
      texto: n,
    }));
  });
  if (!nomes.length) barra.append(elemento("span", { class: "areas-barra-area vazia", texto: "·" }));
  return elemento("div", { class: "areas-tela" }, [barra]);
}

function previaRealDasAreas(val, escolhido) {
  const junto = escolhido ? { ...val, ...escolhido } : null;
  const frase = (v) => {
    const n = String(v.AREAS_NOMES || "").split(",").map((x) => x.trim()).filter(Boolean);
    return n.length
      ? `o applet de áreas do painel: ${n.join(", ")}, nesta ordem — a primeira é a da esquerda`
        + (v.AREAS_FOLGA ? `; com folga: ${v.AREAS_FOLGA}` : "")
        + (v.AREAS_ENCAIXE ? `; encaixe: ${v.AREAS_ENCAIXE}` : "")
      : "nenhuma área com nome";
  };
  return { antes: barraDasAreas(val), depois: junto ? barraDasAreas(junto) : null, legenda: frase(val) };
}

function controlePorArea(item, aplica) {
  const nomesItem = ESQUEMA.chaves.find((k) => k.chave === "AREAS_NOMES");
  const nomes = String(nomesItem ? valorEmVigor(nomesItem) : "")
    .split(",").map((x) => x.trim()).filter(Boolean);
  if (!nomes.length) return elemento("div", { class: "por-area" });

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
       * independentemente da ordem dos cliques. */
      const novas = new Set(marcadas);
      if (quer) novas.add(nome); else novas.delete(nome);
      const daria = nomes.filter((n) => novas.has(n)).join(", ");
      par.append(elemento("button", {
        type: "button",
        class: "btn btn-mini" + (ligada === quer ? " escolhido" : ""),
        "aria-pressed": String(ligada === quer),
        /* O QUE ESTE BOTÃO GRAVARIA, escrito no próprio botão. */
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
    }, [
      /* O rótulo pela tabela ("Frappé", com acento e maiúscula) — o VALOR que
       * vai para o arquivo continua sendo o cru, no data-valor. */
      elemento("span", { class: "nome",
                         texto: (item.rotulos && item.rotulos[nome]) || rotuloDeValor(nome) }),
      tira,
    ]));
  }
  /* `valorEmVigor` e não `item.valor`: o disco não sabe da escolha que ela
   * acabou de fazer, e era o disco que estava pintando. */
  pintar(valorEmVigor(item));
  return caixa;
}

/* --- bolinhas de cor ------------------------------------------------------ */
function controleCor(item, aplica) {
  /* AS CORES OFERECIDAS SÃO AS DO FLAVOR ESCOLHIDO, e não as do gravado. */
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
    /* O LEITOR DE TELA OUVIA `mauve`, `sapphire`, `maroon`: os nomes que o
     * Catppuccin dá às cores dele, com o Dracula no ar. */
    const dito = nomeDaCor(nome, flavor);
    caixa.append(elemento("button", {
      type: "button", "data-valor": nome, "aria-pressed": "false",
      style: `background:${cores[nome]}`,
      title: `${maiuscula(dito)} — ${cores[nome]}`,
      "aria-label": maiuscula(dito),
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
 * descrevem a GEOMETRIA da barra. */
/* Exatamente as chaves que o `mockDaBarra` lê — as cinco do painel e as cinco
 * da dock. Escrita aqui, e não deduzida do nome, porque `VIDRO_OPACIDADE_*` não
 * começa por `FORMA_` e ficaria de fora de qualquer regra de prefixo. */
const CHAVES_DO_MOCK = [
  "FORMA_RAIO_PAINEL", "FORMA_MARGEM_PAINEL", "FORMA_ESPACO_PAINEL",
  "FORMA_RECHEIO_PAINEL", "VIDRO_OPACIDADE_PAINEL",
  "FORMA_RAIO_DOCK", "FORMA_MARGEM_DOCK", "FORMA_ESPACO_DOCK",
  "FORMA_RECHEIO_DOCK", "VIDRO_OPACIDADE_DOCK",
  /* As dez abaixo não mexiam um pixel — e são justamente as que mais mudam a
   * tela: a barra virar pastilha, colar na borda, e o tamanho de cada segmento.
   *
   * Elas não entraram antes porque não são NÚMERO DE GEOMETRIA: as quatro
   * primeiras são sim/não e as seis últimas são degraus (XS..XL). */
  "FORMA_PAINEL_SOLTO", "FORMA_PAINEL_ILHA",
  "FORMA_CENTRO_PAINEL", "FORMA_ALA_INICIAL_PAINEL", "FORMA_ALA_FINAL_PAINEL",
  "FORMA_DOCK_SOLTO", "FORMA_DOCK_ILHA",
  "FORMA_CENTRO_DOCK", "FORMA_ALA_INICIAL_DOCK", "FORMA_ALA_FINAL_DOCK",
];

/* O desenho usa os mesmos cinco números para que subir um segmento engorde a
 * barra aqui como engorda lá — é a consequência que o arquivo avisa e que
 * nenhum controle mostrava. */
/* A RÉGUA DE VERDADE VEM DO SERVIDOR: ele lê os cinco números do próprio
 * `meow_painel_T` (`medidas.tamanho_applet`). Esta cópia fica só como reserva
 * para uma leitura que falhe. */
const TAMANHO_APPLET = { XS: 32, S: 40, M: 56, L: 64, XL: 80 };
function reguaDeApplets() {
  const lida = (ESQUEMA && ESQUEMA.medidas && ESQUEMA.medidas.tamanho_applet) || {};
  return Object.keys(lida).length ? lida : TAMANHO_APPLET;
}
/* Um quarto: com `M` (56) o quadrado sai com 14 px, que era a medida fixa do
 * desenho antigo. O antigo vira o caso médio do novo, e nada encolhe de
 * surpresa na tela dela. */
const ESCALA_APPLET = 0.25;
/* Vazio herda o tamanho GERAL da barra, que não é chave do meow.conf: mora no
 * `size` do cosmic-panel. */
const TAMANHO_GERAL = { painel: "S", dock: "M" };

/* `opcoes.semLegenda` existe para o par de botões: dentro de um botão a legenda
 * de sessenta palavras não é informação, é uma parede de texto por cima da
 * figura que o botão veio mostrar. */
function mockDaBarra(item, opcoes) {
  /* AO VIVO QUER DIZER LENDO A ESCOLHA, e não o disco. Lia `k.valor`, que é
   * o que está gravado; agora lê `valorEmVigor`, que é o que ela acabou de
   * escolher. */
  let reserva = false;
  /* `opcoes.disco` desenha o «Como está» do par da tela: o que a máquina tem,
   * sem a escolha pendente — a mesma leitura do `parDePrevias`. */
  const disco = Boolean(opcoes && opcoes.disco);
  const val = (chave, padrao) => {
    const k = ESQUEMA.chaves.find((x) => x.chave === chave);
    const v = k ? (disco ? valorNaTela(k) : valorEmVigor(k)) : "";
    if (v !== "" && v != null) return v;
    /* Agora o vazio desenha o `valendo_agora`, que o servidor lê na máquina. */
    if (k && k.valendo_agora != null && k.valendo_agora !== "") return k.valendo_agora;
    if (padrao !== "") reserva = true;
    return padrao;
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
  const regua = reguaDeApplets();
  const lido = (ESQUEMA.medidas && ESQUEMA.medidas.barra) || {};
  const geral = lido[dock ? "dock" : "painel"] || TAMANHO_GERAL[dock ? "dock" : "painel"];
  const degrau = (chave) => {
    const bruto = String(val(chave, "")).trim().toUpperCase();
    const proprio = Object.prototype.hasOwnProperty.call(regua, bruto);
    const nome = proprio ? bruto : geral;
    return { nome: nome, proprio: proprio, px: (regua[nome] || 0) * ESCALA_APPLET };
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
  /* O primeiro applet da ponta esquerda da dock é a logo que abre o lançador;
   * na tela da forma ele passa de quadrado de acento ao desenho do gato que
   * está no dock (`gato_no_dock`, o mesmo que o retrato da Início usa). */
  const gatos = dock && opcoes && opcoes.paraTela ? previasDe("gato") : null;
  const nomeDoGato = ESQUEMA.gato_no_dock
    || valorEmVigor(ESQUEMA.chaves.find((x) => x.chave === "LOGO") || { valor: "" });
  const gato = gatos && (gatos.itens || []).find((i) => i.id === nomeDoGato && i.pronta);
  for (const seg of segs) {
    const caixa = elemento("div", { class: "seg", style: `--sq:${seg.px}px` });
    for (let i = 0; i < seg.quantos; i++) {
      caixa.append(gato && seg.id === "inicial" && i === 0
        ? elemento("img", { class: "gato-da-dock", src: gato.url, alt: "" })
        : elemento("span"));
    }
    barra.append(caixa);
  }

  /* O desenho pintava o vão assim mesmo — ou seja, mostrava uma tela que a
   * máquina não ia produzir. */
  const margemVale = solto ? margem : 0;
  const mock = elemento("div", {
    class: "mock" + (dock ? " dock" : " painel"),
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
    /* A ALTURA DITA É A DA MÁQUINA, em unidades lógicas. A conta antiga dividia
     * o desenho inteiro pela escala, recheio incluído, e dizia "altura 56" para
     * o painel dela, que o `meow_painel_altura` mede em 44. */
    `altura ${2 * (Number(recheio) || 0) + Math.max(...segs.map((s2) => regua[s2.nome] || 0))}`
      + " = 2×recheio + o maior segmento",
  ];

  if (opcoes && opcoes.semLegenda) return mock;
  const descricao = `${dock ? "A dock" : "O painel"} ` + notas.join("; ") + ".";
  if (opcoes && opcoes.paraTela) return { mock, legenda: descricao, reserva };
  /* Eram duas legendas de quatro linhas, uma sob cada barra (print 11 do uso
   * real), com os números que o próprio desenho já mostra. */
  const legenda = `${dock ? "a dock" : "o painel"} `
    + notas.join("; ")
    + (reserva
      ? ". Onde a máquina não pôde ser lida, o desenho usa medidas de exemplo."
      : ". Vazio no meow.conf deixa o que a máquina tem, e é isso que aparece aqui.");
  const caixa = elemento("div", { class: "com-dica", style: "width:100%" }, [mock]);
  const dica = dicaDoDesenho(dock ? "forma-dock" : "forma-painel", legenda);
  if (dica) caixa.append(...dica);
  return caixa;
}

function telaDaForma(disco) {
  const p = mockDaBarra({ chave: "FORMA_RAIO_PAINEL" }, { paraTela: true, disco });
  const d = mockDaBarra({ chave: "FORMA_RAIO_DOCK" }, { paraTela: true, disco });
  const paredes = previasDe("parede", "ativos");
  const foto = paredes && (paredes.itens || []).find((i) => i.pronta && i.url);
  const tela = elemento("div", { class: "tela-forma" + (foto ? " com-foto" : "") }, [p.mock, d.mock]);
  if (foto) tela.style.backgroundImage = `url("${foto.url}")`;
  const legenda = `${p.legenda} ${d.legenda}`
    + (p.reserva || d.reserva
      ? " Onde a máquina não pôde ser lida, o desenho usa medidas de exemplo."
      : " Vazio no meow.conf deixa o que a máquina tem, e é isso que aparece aqui.")
    + (foto ? " O fundo é uma imagem do seu carrossel." : "");
  return { tela, legenda };
}

/* O CONTEÚDO DA FAIXA DA FORMA: um lado ou o par. É o que o `render` põe na
 * `.grade-barras` e o que o `repintarPrevia` troca a cada pixel de arrasto. */
function ladosDaForma() {
  const pendentes = CHAVES_DO_MOCK.filter((c) => MUDANCAS.has(c)
    || (PROVISORIO && PROVISORIO.chave === c));
  const lado = (rotulo, tela, aoClicar) => {
    const filhos = [rotulo ? elemento("p", { class: "rotulo-mini", texto: rotulo }) : null, tela];
    if (!aoClicar) return elemento("div", {}, filhos);
    return elemento("button", {
      type: "button", class: "lado-previa", "aria-pressed": "false",
      title: "Desfaz as escolhas da forma. O meow.conf não é tocado.",
      onclick: aoClicar,
    }, filhos);
  };
  if (!pendentes.length) {
    const agora = telaDaForma(false);
    return { lados: [lado(null, agora.tela, null)], legenda: agora.legenda };
  }
  /* O «COMO ESTÁ» DESFAZ AS DEZ CHAVES QUE O DESENHO LÊ, e não as 30 da
   * página — é o desfazer DESTE desenho (era o botão «Desfazer N escolhas»,
   * que o par tornou redundante). */
  const antes = telaDaForma(true);
  const depois = telaDaForma(false);
  const desfazer = () => {
    const quais = CHAVES_DO_MOCK.filter((c) => MUDANCAS.has(c));
    for (const c of quais) MUDANCAS.delete(c);
    atualizarBarraSalvar();
    render();
    torrada(quais.length === 1
      ? "1 escolha da forma desfeita — o meow.conf não foi tocado"
      : `${quais.length} escolhas da forma desfeitas — o meow.conf não foi tocado`, "igual");
  };
  return {
    lados: [lado("Como está", antes.tela, desfazer), lado("Como fica", depois.tela, null)],
    legenda: antes.legenda + " À direita, a mesma tela com a escolha que ainda não foi salva: "
      + depois.legenda,
  };
}

function pintarForma(par) {
  const { lados, legenda } = ladosDaForma();
  par.replaceChildren(...lados);
  par.classList.toggle("com-par", lados.length > 1);
  const dica = dicaDoDesenho("forma", legenda);
  if (dica) ancorarDicaDoDesenho(par, dica);
}

/* A prévia «No terminal» desenhava um contorno de gato genérico, o mesmo para a
 * Coquinha, o Mimir e o morcego: «só um contorno vazio», no uso real. */
const AMOSTRAS_DE_GATO = new Map();   // url|colunas|linhas|proporção -> Promise<ImageData|null>

function amostraDoGato(url, colunas, linhas, proporcao) {
  const chave = `${url}|${colunas}|${linhas}|${proporcao.toFixed(3)}`;
  if (!AMOSTRAS_DE_GATO.has(chave)) {
    AMOSTRAS_DE_GATO.set(chave, new Promise((ok) => {
      const img = new Image();
      img.onload = () => {
        try {
          const c = document.createElement("canvas");
          c.width = colunas;
          c.height = linhas;
          const ctx = c.getContext("2d", { willReadFrequently: true });
          /* `proporcao` é a largura do bloco sobre a altura. */
          const ar = (img.naturalWidth || 1) / (img.naturalHeight || 1);
          const [fw, fh] = ar > proporcao ? [1, proporcao / ar] : [ar / proporcao, 1];
          const w = fw * colunas, h = fh * linhas;
          ctx.drawImage(img, (colunas - w) / 2, (linhas - h) / 2, w, h);
          ok(ctx.getImageData(0, 0, colunas, linhas));
        } catch (e) { ok(null); }
      };
      img.onerror = () => ok(null);
      img.src = url;
    }));
  }
  return AMOSTRAS_DE_GATO.get(chave);
}

function gatoDoTerminal(d) {
  const vale = (k) => {
    const item = ESQUEMA.chaves.find((x) => x.chave === k);
    return item ? valorEmVigor(item) : "";
  };
  const dia = vale("LOGO_DIA"), noite = vale("LOGO_NOITE");
  /* O dock diz em que metade do dia estamos: o gato que ele mostra agora. */
  const noDock = ESQUEMA.gato_no_dock || vale("LOGO");
  if (d.modo === "fixo") return d.gato;
  /* Por horário o terminal segue o relógio, com os gatos dele (vazio herda os
   * do dock); em espelho ele mostra o que o dock NÃO está mostrando. */
  if (d.modo === "hora") return noDock === dia ? (d.dia || dia) : (d.noite || noite);
  return noDock === noite ? dia : noite;
}

/* O desenho (`previas-tela.js`) deixa o gato de traço como reserva dentro de
 * `g.gato-no-dock`; aqui ele vira a imagem do acervo, a mesma da escolha. */
function pintarGatosNoDock(raiz) {
  const grupos = (raiz || document).querySelectorAll("g.gato-no-dock:not([data-pintado])");
  if (!grupos.length) return;
  const gatos = previasDe("gato");
  if (!gatos) return;
  for (const g of grupos) {
    const p = (gatos.itens || []).find((i) => i.id === g.dataset.gato && i.pronta && i.url);
    if (!p) continue;
    g.dataset.pintado = g.dataset.gato;
    const img = document.createElementNS("http://www.w3.org/2000/svg", "image");
    for (const [k, v] of [["x", g.dataset.x], ["y", g.dataset.y], ["width", g.dataset.lado],
                          ["height", g.dataset.lado], ["href", p.url],
                          ["preserveAspectRatio", "xMidYMid meet"]]) img.setAttribute(k, v);
    g.replaceChildren(img);
  }
}

function pintarGatosEmCelulas(raiz) {
  pintarGatosNoDock(raiz);
  const grupos = (raiz || document).querySelectorAll("g.gato-em-celulas:not([data-pintado])");
  if (!grupos.length) return;
  const gatos = previasDe("gato");
  if (!gatos) return;
  const NS_SVG = "http://www.w3.org/2000/svg";
  for (const g of grupos) {
    const d = g.dataset;
    const nome = gatoDoTerminal(d);
    const p = (gatos.itens || []).find((i) => i.id === nome && i.pronta && i.url);
    if (!p) continue;
    g.dataset.pintado = nome;
    const x0 = Number(d.x), y0 = Number(d.y), w = Number(d.w), h = Number(d.h);
    const colunas = Number(d.colunas), linhas = Number(d.linhas), fundo = Number(d.fundo);
    if (!(w > 0 && h > 0 && colunas > 0 && linhas > 0)) continue;
    amostraDoGato(p.url, colunas, linhas, w / h).then((dados) => {
      if (!dados || !g.isConnected) return;
      const largSub = w / colunas, altSub = h / linhas;
      const nos = [];
      /* Uma faixa por sequência da mesma cor na linha, e não um quadrado por
       * subcélula: o gato de 80×32 vira algumas centenas de nós em vez de dois
       * mil e quinhentos. */
      for (let y = 0; y < linhas; y++) {
        const topo = y0 + y * altSub;
        if (topo + altSub > fundo + 0.4) break;   // o que passa do quadro é cortado, como lá
        let inicio = -1, cor = "";
        const fechar = (fim) => {
          if (inicio < 0) return;
          const r = document.createElementNS(NS_SVG, "rect");
          r.setAttribute("x", (x0 + inicio * largSub).toFixed(2));
          r.setAttribute("y", topo.toFixed(2));
          r.setAttribute("width", ((fim - inicio) * largSub + 0.05).toFixed(2));
          r.setAttribute("height", (altSub + 0.05).toFixed(2));
          /* `style`, e não o atributo `fill`: a folha das prévias pinta traço
           * e preenchimento por CSS, e o CSS vence o atributo de apresentação
           * — o gato saía de uma cor só, a do traço. */
          r.setAttribute("style", `fill:${cor};stroke:none`);
          nos.push(r);
          inicio = -1;
        };
        for (let x = 0; x < colunas; x++) {
          const i = (y * colunas + x) * 4;
          const a = dados.data[i + 3];
          if (a < 128) { fechar(x); continue; }
          const q = (v) => Math.min(255, Math.round(v / 17) * 17);
          const c = `rgb(${q(dados.data[i])} ${q(dados.data[i + 1])} ${q(dados.data[i + 2])})`;
          if (inicio >= 0 && c !== cor) fechar(x);
          if (inicio < 0) { inicio = x; cor = c; }
        }
        fechar(colunas);
      }
      if (nos.length) g.replaceChildren(...nos);
    });
  }
}

/* --- o modo de leitura, aplicado de verdade a uma imagem ------------------ */
/* Eram duas simulações, uma em cada cartão (temperatura e textura), com a mesma
 * foto e um véu por cima: o uso real disse «a prévia é a mesma foto estática
 * nos dois cartões; não simula a temperatura nem a textura».
 *
 * A imagem é um papel de parede da coleção — o efeito sobre a foto que se usa
 * diz mais do que sobre um degradê —, cortada ao meio: à esquerda como o dia a
 * mostra, à direita como a noite a pinta. */
const MEOW_PAPEL_TINTA = [0.118, 0.113, 0.104];
const MEOW_PAPEL_GANHO = [0.815, 0.800, 0.760];
const MEOW_PAPEL_DESSATURA = 0.30;
const MEOW_PAPEL_GRAO = 0.085;
const LEITURA_WHITEPOINTS = [
  [1000, [1.00000, 0.18172, 0.00000]], [1500, [1.00000, 0.42101, 0.00000]],
  [2000, [1.00000, 0.54862, 0.08754]], [2500, [1.00000, 0.64546, 0.28802]],
  [3000, [1.00000, 0.71760, 0.42107]], [3500, [1.00000, 0.77987, 0.54468]],
  [4000, [1.00000, 0.82854, 0.64606]], [4500, [1.00000, 0.87325, 0.74112]],
  [5000, [1.00000, 0.90993, 0.82219]], [5500, [1.00000, 0.94380, 0.89904]],
  [6000, [1.00000, 0.97481, 0.96759]], [6500, [1.00000, 1.00000, 1.00000]],
];

function brancoDeKelvin(k) {
  const t = Number(k) || 0;
  if (t <= 0) return [1, 1, 1];
  const W = LEITURA_WHITEPOINTS;
  if (t <= W[0][0]) return W[0][1];
  if (t >= W[W.length - 1][0]) return W[W.length - 1][1];
  for (let i = 0; i < W.length - 1; i++) {
    const [lk, lo] = W[i], [hk, hi] = W[i + 1];
    if (t >= lk && t <= hk) {
      const f = (t - lk) / (hk - lk);
      return lo.map((v, j) => v + (hi[j] - v) * f);
    }
  }
  return [1, 1, 1];
}

const corDoBranco = (k) => `rgb(${brancoDeKelvin(k).map((v) => Math.round(v * 255)).join(" ")})`;

/* O passe do compositor sobre os pixels de `dados`, da coluna `x0` em diante. */
function pintarComoONoite(dados, x0, kelvin, textura) {
  const t = Math.max(0, Math.min(1, Number(textura) || 0));
  const w = brancoDeKelvin(kelvin);
  const grao = (x, y) => { const v = Math.sin(x * 12.9898 + y * 78.233) * 43758.5453; return v - Math.floor(v); };
  const px = dados.data, larg = dados.width;
  for (let y = 0; y < dados.height; y++) {
    for (let x = x0; x < larg; x++) {
      const i = (y * larg + x) * 4;
      let r = px[i] / 255, g = px[i + 1] / 255, b = px[i + 2] / 255;
      if (t > 0) {
        let pr = MEOW_PAPEL_TINTA[0] + MEOW_PAPEL_GANHO[0] * r;
        let pg = MEOW_PAPEL_TINTA[1] + MEOW_PAPEL_GANHO[1] * g;
        let pb = MEOW_PAPEL_TINTA[2] + MEOW_PAPEL_GANHO[2] * b;
        const tinta = 0.2126 * pr + 0.7152 * pg + 0.0722 * pb;
        pr += (tinta - pr) * MEOW_PAPEL_DESSATURA;
        pg += (tinta - pg) * MEOW_PAPEL_DESSATURA;
        pb += (tinta - pb) * MEOW_PAPEL_DESSATURA;
        r += (pr - r) * t; g += (pg - g) * t; b += (pb - b) * t;
        const gr = (grao(x, y) + grao(Math.floor(x * 0.34) + 11, Math.floor(y * 0.34) + 11)) * 0.5 - 0.5;
        const m = 1 + gr * (MEOW_PAPEL_GRAO * t);
        r = Math.min(1, Math.max(0, r * m)); g = Math.min(1, Math.max(0, g * m)); b = Math.min(1, Math.max(0, b * m));
      }
      px[i] = r * w[0] * 255; px[i + 1] = g * w[1] * 255; px[i + 2] = b * w[2] * 255;
    }
  }
}

/* A imagem da prévia, uma vez por URL: decodificar a foto a cada arrasto do
 * deslizante seria o arrasto inteiro esperando o disco. */
const IMAGEM_DA_LEITURA = new Map();
function imagemDaLeitura(url) {
  if (!IMAGEM_DA_LEITURA.has(url)) {
    IMAGEM_DA_LEITURA.set(url, new Promise((ok) => {
      const img = new Image();
      img.onload = () => ok(img);
      img.onerror = () => ok(null);
      img.src = url;
    }));
  }
  return IMAGEM_DA_LEITURA.get(url);
}

/* Uma tela da prévia: a imagem cortada (dia | noite) e, embaixo, a régua das
 * 24 horas com a noite do modo de leitura pintada na cor que ela põe na tela.
 * `val` são os valores que a tela mostra (os da máquina, ou os escolhidos). */
function telaDaLeitura(val) {
  const L = 320, A = 150;
  const temp = val.LEITURA_TEMPERATURA || "6500";
  const textura = val.LEITURA_TEXTURA || "0";
  const agenda = val.LEITURA_AGENDA;
  const canvas = elemento("canvas", { width: String(L), height: String(A), class: "leitura-real-imagem",
    role: "img", "aria-label": `À esquerda o dia; à direita a noite, a ${temp} K com textura ${textura}` });
  const pintar = (img) => {
    const ctx = canvas.getContext("2d", { willReadFrequently: true });
    if (!ctx) return;
    if (img) {
      const ar = img.naturalWidth / img.naturalHeight;
      const [w, h] = ar > L / A ? [A * ar, A] : [L, L / ar];
      ctx.drawImage(img, (L - w) / 2, (A - h) / 2, w, h);
    } else {
      const css = getComputedStyle(document.documentElement);
      const g = ctx.createLinearGradient(0, 0, 0, A);
      g.addColorStop(0, css.getPropertyValue("--crust").trim() || "#111");
      g.addColorStop(0.5, css.getPropertyValue("--mauve").trim() || "#c6a0f6");
      g.addColorStop(1, "#ffffff");
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, L, A);
    }
    let dados;
    try { dados = ctx.getImageData(0, 0, L, A); } catch (e) { return; }
    pintarComoONoite(dados, L / 2, temp, textura);
    ctx.putImageData(dados, 0, 0);
    /* O fio do corte: o dia de um lado, a noite do outro. */
    ctx.fillStyle = "rgba(255,255,255,.75)";
    ctx.fillRect(L / 2, 0, 1, A);
  };
  const paredes = previasDe("parede", "ativos");
  const amostra = paredes && paredes.itens.find((i) => i.pronta && i.url);
  if (amostra) imagemDaLeitura(amostra.url).then(pintar);
  else pintar(null);

  /* A régua: o dia liso, a noite na cor do branco que a tela vai ter. Sem
   * agenda («Não», ou o vazio que não toca), a régua fica a traço e sem noite
   * — o relógio não liga nada sozinho. */
  const ini = val.LEITURA_HORARIO_INICIO || "18:00", fim = val.LEITURA_HORARIO_FIM || "07:00";
  const regua = elemento("div", { class: "leitura-real-regua" + (agenda === "sim" ? "" : " sem-agenda") });
  if (agenda === "sim" && HORA_OK.test(ini) && HORA_OK.test(fim)) {
    const a = minutosDe(ini) / 1440 * 100, b = minutosDe(fim) / 1440 * 100;
    const faixas = a === b ? [[0, 100]] : a < b ? [[a, b]] : [[a, 100], [0, b]];
    for (const [de, ate] of faixas) {
      regua.append(elemento("span", { class: "leitura-real-noite",
        style: `left:${de}%;width:${ate - de}%;background:${corDoBranco(temp)}` }));
    }
  }
  /* Cada hora sob a sua ponta, presa entre 8% e 92% para não sair da régua. */
  const naRegua = (h) => `left:${Math.min(92, Math.max(8, minutosDe(h) / 1440 * 100))}%`;
  const horas = agenda === "sim" && HORA_OK.test(ini) && HORA_OK.test(fim)
    ? elemento("div", { class: "leitura-real-horas" }, [
        elemento("span", { texto: ini, style: naRegua(ini) }),
        elemento("span", { texto: fim, style: naRegua(fim) }),
      ])
    : null;
  return elemento("div", { class: "leitura-real" }, [canvas, regua, horas]);
}

/* O contrato dos desenhos de `MEOW_PREVIAS` (`{antes, depois, legenda}`), para
 * o `parDePrevias` não saber que esta prévia é feita de pixels. */
function previaRealDaLeitura(val, escolhido) {
  const junto = escolhido ? { ...val, ...escolhido } : null;
  const frase = (v) => `à esquerda o dia, à direita a noite: a mesma imagem a ${v.LEITURA_TEMPERATURA || 6500} K `
    + `com textura ${v.LEITURA_TEXTURA || 0}`
    + (v.LEITURA_AGENDA === "sim"
      ? `, das ${v.LEITURA_HORARIO_INICIO || "18:00"} às ${v.LEITURA_HORARIO_FIM || "07:00"}`
      : ", sem horário: o relógio não liga nada sozinho")
    + ". A conta é a do compositor, pixel a pixel";
  return { antes: telaDaLeitura(val), depois: junto ? telaDaLeitura(junto) : null, legenda: frase(val) };
}
/* As prévias feitas de pixel, e não de traço, pelo nome do bloco. */
const PREVIAS_REAIS = { "Modo de leitura": previaRealDaLeitura,
                        "Áreas de trabalho": previaRealDasAreas };

/* --- a grade de ícones do tema INSTALADO ---------------------------------- */
function gradeDeIcones(limite = 24) {
  const lista = previasDe("icone");
  if (!lista) return elemento("p", { class: "sem-previa", texto: "lendo o tema instalado…" });
  if (!lista.itens.length) {
    return elemento("p", {
      class: "sem-previa",
      texto: "o tema de ícones ainda não está no disco — rode «Reconstruir o tema de ícones».",
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


/* OS APLICATIVOS E SEUS ÍCONES — a aba que ela cobrou
 *
 * Aqui não temos isso.
 *
 * Cada aplicativo da máquina, com o ícone que está NA TELA agora. */
let APPS = null;
let APPS_BUSCA = "";
let APP_ABERTO = null;
let GLIFOS = { termo: null, itens: [], carregando: false };
/* A página se repinta a cada clique, e um `<details>` aberto à mão nasceria
 * fechado de novo no clique seguinte (o mesmo defeito que a oficina já teve,
 * ver `OFICINA`). */
const PASTAS_ABERTAS = new Map();
/* A repintura da ficha que está na tela (ver "A TIRA SOBREVIVE À REPINTURA"). */
let PINTAR_FICHA = null;

/* Depois do «Usar este ícone» a ficha fecha e a grade se relê: a página encurta
 * e a rolagem, que estava na ficha, caía no fim dela, longe do cartão que
 * acabou de mudar. */
function appAVista(id) {
  const cartao = [...document.querySelectorAll("#conteudo .grade-apps button.app")]
    .find((b) => b.dataset.app === id);
  if (!cartao) return;
  cartao.scrollIntoView({ block: "center" });
  cartao.focus({ preventScroll: true });
  ROLAGEM_PENDENTE = 0;
}

async function carregarApps() {
  const r = await api("/api/apps");
  APPS = r.erro ? { apps: [], total: 0 } : r;
  render();
}

async function carregarGlifos(termo, app) {
  if (GLIFOS.termo === termo && GLIFOS.app === app && !GLIFOS.carregando) return;
  GLIFOS = { termo, app, itens: [], carregando: true };
  const r = await api(`/api/glifos?busca=${encodeURIComponent(termo || "")}`
                      + `&app=${encodeURIComponent(app || "")}`);
  if (GLIFOS.termo !== termo || GLIFOS.app !== app) return;
  /* O `aviso` é a frase de quando o pack no ar tem desenhos e a camada que os
   * põe no tema está desligada. */
  GLIFOS = { termo, app, itens: r.glifos || [], grupos: r.grupos || [], carregando: false,
             aviso: r.aviso || "", pack: r.pack || null, escolha: r.escolha || null,
             minha: r.minha || null, veste: r.veste || null };
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
    /* É o nome da extensão do arquivo de atalho (a convenção freedesktop), e
     * ninguém precisa dela para entender o número: o que ele conta é quanta
     * coisa desta máquina aparece no menu de lançamento. */
    elemento("div", { class: "selos" }, [
      selo("icones", { texto: String(APPS.total),
                       balao: `${APPS.total} aplicativos no lançador desta máquina` }),
      APPS.jogos ? selo("jogo", { texto: String(APPS.jogos),
        balao: `${APPS.jogos} ${APPS.jogos === 1 ? "jogo: o ícone dele mora" : "jogos: o ícone deles mora"} em «Lançadores e jogos»` })
        : null,
    ]),
  ]));

  /* Esta linha existe porque vinte e quatro cartões sumirem de uma aba sem uma
   * palavra é a página mentindo por omissão: quem estava procurando o ícone de
   * um jogo concluiria que ele não tem `.desktop`. */

  caixa.append(pulaGrade("apos-apps", "Pular a lista de aplicativos"));
  caixa.append(gradeDeApps(APPS.apps || [], APPS_BUSCA, carregarApps));
  caixa.append(alvoDoPulo("apos-apps"));
  /* Os desenhos autorais do pack — o gerador, com tela. Ficam DEPOIS da
   * grade: a pergunta desta aba é "que ícone veste cada programa?", e
   * desenhar um novo é o passo seguinte, não o primeiro. */
  const autoral = oficinaAutoral();
  if (autoral) caixa.append(autoral);
  return caixa;
}

/* Copiar as trinta linhas para lá seria a segunda grade que deixa de acompanhar
 * a primeira na próxima mudança.
 *
 * `recarregar` é o que muda entre as duas: a aba de ícones relê `/api/apps`, a
 * de jogos relê `/api/jogos` — e reler a errada deixaria a grade mostrando o
 * ícone velho depois de trocá-lo. */
function gradeDeApps(apps, filtro, recarregar) {
  const termo = semAcento(String(filtro || "").trim());
  const lista = apps.filter((a) =>
    !termo || semAcento(a.nome).includes(termo) || semAcento(a.id).includes(termo));

  /* BUSCA QUE NÃO ACHA NADA TEM DE DIZER ISSO — a mesma regra que a grade de
   * jogos ganhou hoje, medida aqui também: filtrar "steam" deixava a grade com
   * zero filhos e NENHUMA palavra, com o texto ao lado ainda dizendo "40
   * aplicativos". */
  if (termo && !lista.length) {
    return elemento("p", {
      class: "sem-previa",
      texto: `Nenhum dos ${apps.length} aplicativos casa com “${String(filtro).trim()}” — `
           + "a Steam e os jogos dela moram em «Lançadores e jogos».",
    });
  }

  const grade = elemento("div", { class: "grade-apps" });
  for (const a of lista) {
    const fig = elemento("button", {
      type: "button",
      class: "app" + (APP_ABERTO === a.id ? " aberto" : ""),
      title: `${a.id}  ·  ${a.origem}`,
      "data-app": a.id,
      onclick: () => {
        APP_ABERTO = APP_ABERTO === a.id ? null : a.id;
        /* A busca guardada respondia ao mesmo termo e ao mesmo aplicativo sem
         * ir ao servidor, e a `escolha` no pack que vem nela muda com os botões
         * da própria ficha, que a fecham ao terminar: reaberta, ela esconderia
         * o «Desfazer a escolha no pack» da escolha que acabou de ser feita. */
        if (APP_ABERTO) {
          GLIFOS = { termo: null, itens: [], carregando: false };
          carregarGlifos("", a.id);
        }
        render();
      },
    }, [
      a.url
        ? elemento("img", { src: a.url, alt: "", loading: "lazy" })
        : elemento("div", { class: "lugar", style: "width:40px;height:40px;border-radius:8px" }),
      elemento("span", { class: "app-nome", texto: a.nome }),
      /* A etiqueta diz o ESTADO, em uma palavra: a cor quando o app já está no
       * nosso mapa, "de fábrica" quando o ícone que aparece é o que veio com
       * ele. */
      /* Ela dizia a cor só para quem está no `apps-arcticons.map`; os 33 do
       * `apps-convertidos.map` — Spotify, GIMP, Chrome, os seis jogos de hoje —
       * caíam todos em "nosso", sem cor. */
      /* O pack autoral Dracula escreve em `scalable/apps`, que vence o
       * `48x48/apps` do Arcticons no resolvedor. */
      /* A etiqueta dizia `lavender`, `maroon` com o Dracula no ar; o traço é
       * pintado com o hex desse slot na paleta do pack no ar (o
       * `icones_apps_arcticons.sh` lê o `meow_paleta` no FLAVOR), e o nome sai
       * do mesmo hex (`nomeDaCor`), como nos botões da «Cor de destaque». */
      seloDaOrigem(a),
    ]);
    grade.append(fig);
    if (APP_ABERTO === a.id) grade.append(montarEscolhaDeIcone(a, recarregar));
  }
  return grade;
}

/* O selo da origem do ícone na grade — ver "A ORIGEM VIRA SELO", acima. */
function seloDaOrigem(a) {
  const traco = a.mapa || a.traco;
  const [tipo, dica] = a.escolhido
    ? ["escolha", "Escolhido por você nesta conta"]
    : a.dracula
    ? ["pack", "Desenho do pack no ar"]
    : traco
    ? ["traco", `Traço do MeowSystem, em ${nomeDaCor(traco.cor, flavorEmVigor())}`]
    : a.nosso
    ? ["nosso", "Desenho do MeowSystem"]
    : ["fabrica", "De fábrica: nenhum acervo veste este app"];
  const hex = traco && !a.escolhido && !a.dracula
    ? ((ESQUEMA.paleta.flavors || {})[flavorEmVigor()] || {})[traco.cor] : "";
  return elemento("span", {
    class: `app-marca selo selo-${tipo}`, role: "img", "aria-label": dica, title: dica,
    style: hex ? `--cor-do-selo:${hex}` : null,
  });
}

function montarEscolhaDeIcone(app, recarregar) {
  /* Quem mandou desenhar diz o que reler depois da escolha; sem ninguém dizer,
   * é a lista de aplicativos, que é de onde esta tela nasceu. */
  const relerLista = recarregar || carregarApps;
  const painel = elemento("div", { class: "escolha-icone" });
  painel.append(elemento("h3", { class: "titulo-cartao", texto: `Ícone de ${app.nome}` }));

  painel.append(oficinaDeDesenho(app, relerLista));

  /* «NO ACERVO ARCTICONS» SAIU DO CAMPO. A busca passou a achar também os
   * desenhos do pack no ar, e o campo prometendo um acervo só mandaria
   * procurar o Dracula em outro lugar. */
  const busca = elemento("input", {
    type: "search", value: GLIFOS.termo || "", "data-foco": "glifos",
    placeholder: "Buscar desenho pelo nome…",
    "aria-label": "Buscar desenho",
    oninput: (e) => carregarGlifos(e.target.value.trim().toLowerCase(), app.id),
  });
  /* A `trava` diz por que um glifo do TRAÇO não valeria neste aplicativo
   * (intocável, curadoria, desenho convertido), e escondia a busca inteira —
   * com o grupo do pack dentro. */
  /* Agora a busca e as pastas ficam sempre; o desenho que não valeria neste
   * app aparece apagado, sem «Usar», e o porquê — a frase da trava, com o dono
   * do ícone — vai para a dica. */
  painel.append(busca);

  /* O glifo do mapa do traço não é escolha que a ficha travada ofereça: ele
   * nem está na tira, e o «Usar este ícone» o mandaria para a recusa. */
  /* A tira é reaproveitada entre repinturas (ver "A TIRA SOBREVIVE À
   * REPINTURA", abaixo), e um botão dela que gravasse numa variável daqui
   * gravaria na ficha de três cliques atrás. */
  /* Estava `app.mapa ? app.mapa.cor : ordem[0]`: quem tem desenho no acervo de
   * TRAÇO (`apps-convertidos.map`) e não está no mapa do Arcticons caía na
   * PRIMEIRA cor da paleta.
   *
   * A cadeia certa já existia em `corDaOficina()`; o que faltava era usá-la
   * aqui. */
  let corEscolhida = (app.traco && app.traco.cor)
                     || (app.mapa && app.mapa.cor)
                     || ((ESQUEMA.paleta.ordem || [])[0] || "mauve");

  /* O servidor manda o pack no ar primeiro, num grupo com o nome dele (ver
   * `_desenhos_do_pack_no_ar`), e a tira os separa com um rótulo: sem ele, o
   * `google-chrome` do Dracula e o do Arcticons seriam dois quadrados com o
   * mesmo nome.
   *
   * A ESCOLHA É PELA CHAVE, E NÃO PELO NOME, pelo mesmo motivo: marcando pelo
   * `data-glifo`, um clique marcaria os dois. */
  /* A ESCOLHA É PELA CHAVE GRUPO|NOME. A mesma pasta não repete nome, e o
   * `google-chrome` do Dracula e o do Arcticons continuam distintos. */
  const chaveDe = (g) => `${g.grupo}|${g.glifo}`;
  const itens = GLIFOS.itens;
  /* QUAL TRAVA VALE PARA QUAL DESENHO: o traço é do `48x48/apps`, e obedece à
   * `trava`; o desenho que entra como está vai para o `scalable/apps`, e
   * obedece à `trava_pack`. */
  const travaDe = (g) => g.trava || (g.tipo === "traco" ? app.trava : app.trava_pack) || "";
  const vestido = app.mapa && !app.trava
    ? itens.find((g) => g.tipo === "traco" && g.glifo === app.mapa.glifo) : null;
  /* Desde a I3 a escolha mora no `icones-escolhidos.map` dela, e o servidor a
   * manda em `minha`; só o traço abria marcado, e quem reabria a ficha não via
   * qual desenho tinha escolhido — só o «Desfazer». */
  const daMinha = GLIFOS.app === app.id && GLIFOS.minha
    ? itens.find((g) => g.arquivo === GLIFOS.minha.arquivo && !travaDe(g)) : null;
  /* Só a escolha dela e o traço abriam marcados: o Waterfox, vestido pelo
   * desenho do pack no ar, abria a ficha sem marca nenhuma. */
  const daVeste = GLIFOS.app === app.id && GLIFOS.veste
    ? itens.find((g) => g.arquivo === GLIFOS.veste && !travaDe(g)) : null;
  if (GLIFOS.escolhido === undefined) {
    GLIFOS.escolhido = daMinha ? chaveDe(daMinha) : daVeste ? chaveDe(daVeste)
      : vestido ? chaveDe(vestido) : null;
  }
  const grupoDe = (id) => (GLIFOS.grupos || []).find((x) => x.id === id) || { id, acervo: "", nome: id };
  const itemEscolhido = () => itens.find((g) => chaveDe(g) === GLIFOS.escolhido) || null;
  /* Ela é montada uma vez por resposta da busca (e por estado de trava do app)
   * e guardada na própria `GLIFOS`; a repintura a recoloca. */
  const chaveDaTira = `${app.id}|${app.trava || ""}|${app.trava_pack || ""}`;
  const reaproveita = !GLIFOS.carregando && GLIFOS.tira && GLIFOS.chaveDaTira === chaveDaTira;
  const tiraGlifos = reaproveita ? GLIFOS.tira : elemento("div", { class: "tira-glifos" });
  const pintarGlifos = () => {
    for (const b of tiraGlifos.querySelectorAll("button[data-escolha]")) {
      b.setAttribute("aria-pressed", String(b.dataset.escolha === GLIFOS.escolhido));
    }
    /* A COR NÃO VAI COM O DESENHO DO PACK, E A TELA DIZ: ele entra no tema com
     * as cores que tem (o pack declara `recolorir: false`, e nenhum passo o
     * recolore). */
    const g = itemEscolhido();
    const comCor = !!(g && g.tipo === "traco");
    cores.hidden = !comCor;
    rotuloDaCor.hidden = !comCor;
  };
  /* Embaixo de cada desenho vinha o nome do arquivo, cortado: `net.waterfo…`,
   * `org.gnome.…`, `005-potion`. */
  const origemDe = (g) => `${g.glifo} — ${grupoDe(g.grupo).acervo} · ${grupoDe(g.grupo).nome}`;
  const botaoDe = (g) => elemento("button", {
    type: "button",
    class: (g.tipo === "traco" ? "" : "do-pack") + (travaDe(g) ? " travado" : ""),
    "data-glifo": g.glifo, "data-escolha": travaDe(g) ? null : chaveDe(g),
    "aria-disabled": travaDe(g) ? "true" : null,
    title: travaDe(g) || origemDe(g),
    "aria-pressed": String(chaveDe(g) === GLIFOS.escolhido),
    onclick: () => {
      if (travaDe(g)) return;
      GLIFOS.escolhido = chaveDe(g);
      if (PINTAR_FICHA) PINTAR_FICHA();
    },
  }, [
    elemento("img", { src: g.url, alt: "", loading: "lazy" }),
    elemento("span", { texto: g.rotulo || g.glifo }),
  ]);
  /* «Era pra aparecerem todos os Drácula feitos e todos os do MeowSystem
   * feitos, numa pasta cada.» */
  const pasta = (id, cabeca, conta, filhos, abertaPadrao) => {
    const aberta = PASTAS_ABERTAS.has(id) ? PASTAS_ABERTAS.get(id) : abertaPadrao;
    /* O ESTADO É GRAVADO NO CLIQUE, E NÃO SÓ NO `toggle`: o `toggle` chega
     * numa tarefa depois, e uma repintura no meio (a busca que responde)
     * nasceria com o estado velho — a pasta aberta fechava sozinha. */
    const resumo = elemento("summary", {
      onclick: () => PASTAS_ABERTAS.set(id, !det.open),
    }, [...cabeca, elemento("span", { class: "conta", texto: conta })]);
    const det = elemento("details", { class: "pasta-acervo", "data-grupo": id }, [
      resumo, elemento("div", { class: "grade-glifos" }, filhos),
    ]);
    det.open = aberta;
    det.addEventListener("toggle", () => PASTAS_ABERTAS.set(id, det.open));
    return det;
  };
  PINTAR_FICHA = pintarGlifos;
  if (reaproveita) {
    /* nada a montar: a tira de antes, com as pastas e as miniaturas dela */
  } else if (GLIFOS.carregando) {
    tiraGlifos.append(elemento("p", { class: "sem-previa", texto: "Procurando…" }));
  } else if (!itens.length) {
    tiraGlifos.append(elemento("p", { class: "sem-previa",
      texto: GLIFOS.termo ? `Nenhum desenho casa com “${GLIFOS.termo}”.` : "Nenhum desenho no acervo." }));
  }
  const sugeridos = reaproveita ? [] : itens.filter((g) => g.sugerido);
  if (sugeridos.length) {
    tiraGlifos.append(pasta("sugeridos",
      [elemento("span", { class: "dono", texto: "Sugeridos" })],
      String(sugeridos.length), sugeridos.map(botaoDe), true));
  }
  const primeiraNoAr = (GLIFOS.grupos || []).find((x) => x.no_ar && x.achados);
  for (const gr of reaproveita ? [] : GLIFOS.grupos || []) {
    const deles = itens.filter((g) => g.grupo === gr.id);
    if (!deles.length) continue;
    const travaDaPasta = deles.every((g) => travaDe(g)) ? travaDe(deles[0]) : "";
    tiraGlifos.append(pasta(gr.id,
      [elemento("span", { class: "dono", texto: gr.acervo }),
       elemento("span", { class: "nome-pasta", texto: gr.nome }),
       /* O cadeado é desenho, e não palavra: a pasta inteira apagada diz «não
        * vale aqui», e a dica diz por quê. */
       travaDaPasta ? selo("trava", { balao: travaDaPasta }) : null],
      /* Com busca, a conta é a do que casou; sem busca, o total da pasta. */
      String(GLIFOS.termo ? gr.achados : gr.total),
      deles.map(botaoDe),
      /* A pasta da escolha dela também abre: marcada e fechada não se vê. */
      !!GLIFOS.termo || (!sugeridos.length && primeiraNoAr && primeiraNoAr.id === gr.id)
        || (!!daMinha && daMinha.grupo === gr.id)));
  }
  if (!reaproveita && !GLIFOS.carregando) {
    GLIFOS.tira = tiraGlifos;
    GLIFOS.chaveDaTira = chaveDaTira;
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
        /* As duas fileiras respondem à mesma pergunta — "de que cor é o ícone
         * do Brave?" — e o que muda é só o botão que grava. Deixá-las
         * divergir era a própria tela discordando de si mesma. */
        sincronizarCorDaOficina(nome);
      },
    }));
  }
  const rotuloDaCor = elemento("div", { class: "rotulo-mini", texto: "Cor" });
  painel.append(rotuloDaCor);
  painel.append(cores);

  const acoes = elemento("div", { class: "escolha-botoes" });
  /* Medido pela interface no Hefesto: «Usar este ícone» gravou a linha, a
   * torrada disse "Hefesto: steam em green", a gaveta disse "os ícones novos
   * já estão na dock" — e a dock ficou igual, porque o script pula os
   * intocáveis sem uma palavra. */
  /* Sem nenhum desenho que valha (as duas travas, como no CosmicEdit), o
   * «Usar» não nasce: só o acervo, apagado, com a dica do dono. */
  const algumVale = itens.some((g) => !travaDe(g));
  if (algumVale) acoes.append(elemento("button", {
    type: "button", class: "btn btn-accent", texto: "Usar este ícone",
    /* Até aqui ela ia para o repositório (o mapa do traço, ou o `apps.map` do
     * pack); agora vai para o estado dela, ao lado do meow.conf, e o pack só
     * recebe pelo «Levar para o pack». */
    title: "A escolha fica nesta conta; «Levar para o pack» a põe no pack",
    onclick: async () => {
      if (!GLIFOS.escolhido) { torrada("Escolha um desenho primeiro", "erro"); return; }
      /* A cor não vai junto. */
      const g = itemEscolhido();
      if (g && g.tipo !== "traco") {
        const r = await api("/api/app-icone", {
          method: "POST",
          body: JSON.stringify({ app: app.id, arquivo: g.arquivo }),
        });
        if (r.erro) { torrada(r.erro, "erro"); return; }
        torrada(`${app.nome}: ${g.glifo}`, "ok");
        await rodarAcao("icones_pack");
        APP_ABERTO = null;
        await fimDoTrabalho();
        await relerLista();
        appAVista(app.id);
        return;
      }
      const r = await api("/api/app-icone", {
        method: "POST",
        body: JSON.stringify({ app: app.id, glifo: g ? g.glifo : "", arquivo: g ? g.arquivo : "",
                               cor: corEscolhida }),
      });
      if (r.erro) { torrada(r.erro, "erro"); return; }
      torrada(
        `${app.nome}: ${r.glifo} em ${corEscolhida}`
        + (r.trouxe_do_acervo ? " — o desenho entrou no projeto" : "")
        /* O parêntese já explicava o QUE é — bastou tirar o nome e deixar a
         * explicação. */
        + (r.alias ? " (o desenho ou a cor já eram de outro programa)" : ""),
        "ok");
      /* Este botão só gravava a linha no mapa, e o ícone esperava um
       * «Reconstruir o tema» — que nem é quem põe desenho em traço na tela (ver
       * o `icones_traco` no servidor). */
      await rodarAcao("icones_traco");
      /* O traço tirou a escolha de desenho deste app: é o passo do pack que
       * tira o desenho do `scalable/apps`, que vence o traço. */
      if (r.tirou_escolha) { await fimDoTrabalho(); await rodarAcao("icones_pack"); }
      APP_ABERTO = null;
      await fimDoTrabalho();
      await relerLista();
      appAVista(app.id);
    },
  }));
  if (app.mapa && app.mapa.meu) {
    acoes.append(elemento("button", {
      /* "MAPA" ERA O NOME DO ARQUIVO (apps-arcticons.map), não do que o botão
       * faz. */
      type: "button", class: "btn", texto: "Desfazer a escolha no traço",
      onclick: async () => {
        const r = await api("/api/app-icone", {
          method: "POST",
          body: JSON.stringify({ app: app.id, remover: true }),
        });
        if (r.erro) { torrada(r.erro, "erro"); return; }
        /* O servidor olha os mapas depois de gravar (`_o_que_fica`). */
        torrada(`${app.nome} fica com ${r.fica.frase}`, "ok");
        /* O desenho que sobra na tela vira órfão, e é a varredura do mesmo
         * script que o tira — o mesmo passo do «Usar este ícone». */
        await rodarAcao("icones_traco");
        APP_ABERTO = null;
        await fimDoTrabalho();
        await relerLista();
      },
    }));
  }
  /* O «Usar este ícone» com um desenho do pack troca a linha do aplicativo no
   * `apps.map` do pack no ar, e não havia volta: o botão acima só mexe no mapa
   * do traço. */
  /* Com a camada do pack desligada ele fica apagado, e o porquê na dica. */
  const minha = GLIFOS.app === app.id ? GLIFOS.minha : null;
  if (minha) {
    acoes.append(elemento("button", {
      type: "button", class: "btn", texto: "Desfazer a minha escolha",
      onclick: async () => {
        const r = await api("/api/app-icone", {
          method: "POST", body: JSON.stringify({ app: app.id, escolha: true, remover: true }),
        });
        if (r.erro) { torrada(r.erro, "erro"); return; }
        torrada(`${app.nome} fica com ${r.fica.frase}`, "ok");
        await rodarAcao("icones_pack");
        APP_ABERTO = null;
        await fimDoTrabalho();
        await relerLista();
      },
    }));
    if (minha.pack && minha.desenho) {
      acoes.append(elemento("button", {
        type: "button", class: "btn", texto: "Levar para o pack",
        disabled: !!GLIFOS.aviso,
        title: GLIFOS.aviso || "Grava no pack: vale em toda máquina que instalar daqui",
        onclick: async () => {
          const r = await api("/api/app-icone", {
            method: "POST",
            body: JSON.stringify({ app: app.id, pack: minha.pack, desenho: minha.desenho }),
          });
          if (r.erro) { torrada(r.erro, "erro"); return; }
          torrada(`${app.nome}: ${minha.glifo}, no pack «${r.nome_pack}»`, "ok");
          await rodarAcao("icones_pack");
          APP_ABERTO = null;
          await fimDoTrabalho();
          await relerLista();
        },
      }));
    }
  }
  const escolhaNoPack = GLIFOS.app === app.id ? GLIFOS.escolha : null;
  if (escolhaNoPack) {
    acoes.append(elemento("button", {
      type: "button", class: "btn", texto: "Desfazer a escolha no pack",
      onclick: async () => {
        const r = await api("/api/app-icone", {
          method: "POST",
          body: JSON.stringify({ app: app.id, pack: escolhaNoPack.pack, remover: true }),
        });
        if (r.erro) { torrada(r.erro, "erro"); return; }
        torrada(`${app.nome} fica com ${r.fica.frase}`, "ok");
        await rodarAcao("icones_pack");
        APP_ABERTO = null;
        await fimDoTrabalho();
        await relerLista();
      },
    }));
  }
  acoes.append(botaoAcervo("icone", async () => { await relerLista(); }));
  /* O título dele dizia "a escolha só aparece na tela depois disto", e não era
   * verdade: quem põe na tela é o `icones_traco`, que os dois botões acima
   * agora rodam sozinhos. */
  painel.append(acoes);
  /* "assets/icones/ apps-arcticons.map, no repositório" respondia uma
   * pergunta que ninguém faz na frente desta grade ("onde isto é gravado?")
   * e escondia a que ela faz de fato: isto vale só aqui, ou em toda
   * máquina? */
  pintarGlifos();
  return painel;
}

/* A tira de cima ESCOLHE um desenho pronto entre os 14.996 do Arcticons — é
 * desenho de outra gente, e serve quando existe um glifo honesto.
 *
 * Era um clique, um desenho; para ver outro, mexer num número e clicar de novo
 * — e quem não sabe o que o número faz não mexe.
 *
 * Clicar num cartão troca a lupa, a tira do dock e as réguas, e não escreve
 * nada. */
let OFICINA = oficinaZerada(null);

function oficinaZerada(id) {
  return {
    app: id,              // id do .desktop
    aberta: false, carregou: false, ocupada: false, erro: "",
    cor: "",              // a cor escolhida; abre em `corDaOficina(app)` e daí
                          // em diante quem manda é a fileira de amostras daqui
    origem: "", original: "", capa: "", nome: "",
    variacoes: [], vizinhos: [], salvo: null,
    pack: [],             // os desenhos de pack deste aplicativo
    emVigor: null,
    arte: false,          // o desenho vivo é arte acabada de pack, e não traço
    escolhida: null,      // "pack:<id>" | "salvo" | "fiel" | … | "editado" | null
    escolhidaAntes: null, // o cartão de onde o desenho veio, para o Desfazer
                          // devolver a marca quando a última mão for desfeita
    base: "",             // o desenho do cartão escolhido, como veio
    svg: "",              // o texto VIVO — o que a lupa mostra e o Usar grava
    parametros: "", fonte: "icone",
    /* Com elas em 0 o servidor não acrescenta bandeira nenhuma ao conversor, e
     * a folha sai BYTE A BYTE como saía ontem (provado com `cmp`, 25
     * conversões). */
    detalhe: 6, suavidade: 2, cheia: false, fracas: 0, minimo: 0,
    historico: [],        // pilha para o Desfazer (máx. 30)
    temporizador: null,   // a espera das réguas
    /* `editor` é o que o servidor respondeu ({tem, nome}); `editorMtime` é a
     * marca do rascunho na última vez que o painel o leu, e `editorRelogio` é o
     * vigia que pergunta "mudou?". */
    editor: null, editorMtime: 0, editorRelogio: null, editorEspiadas: 0,
  };
}

/* `houveMao()` é só informativo: quem decide se o desenho é regenerável ou
 * retoque à mão é o SERVIDOR, reconvertendo e comparando. Uma decisão do
 * cliente aqui seria uma promessa que o navegador não tem como cumprir. */
function houveMao() {
  return OFICINA.svg.trim() !== OFICINA.base.trim();
}

/* Uma função para todos os tamanhos: o cartão a 48 e a 96, a tira do dock a 48,
 * a lupa a 200. Devolve `null` quando o texto não é SVG — quem chama decide o
 * que dizer.
 *
 * `innerHTML` com o que veio de uma caixa de texto é a porta aberta de sempre. */
function desenhar(texto, px, cor, opcoes = {}) {
  let doc;
  try { doc = new DOMParser().parseFromString(String(texto || "").trim(), "image/svg+xml"); }
  catch (e) { return null; }
  const raiz = doc.documentElement;
  if (!raiz || raiz.nodeName === "parsererror" || doc.querySelector("parsererror")) return null;
  const no = document.importNode(raiz, true);
  no.setAttribute("width", String(px));
  no.setAttribute("height", String(px));
  /* A espessura e a cor NÃO estão no arquivo, de propósito — quem as põe é o
   * instalador. */
  no.setAttribute("stroke-width", "2.25");
  if (cor) no.style.color = `var(--${cor})`;
  /* Os ouvintes entram DEPOIS do `importNode`: postos no documento do
   * `DOMParser` eles morreriam na importação, e o clique não chegaria em nada. */
  if (opcoes.clicavel) {
    no.querySelectorAll("path").forEach((p, i) => {
      p.dataset.i = String(i);
      /* `tabindex="-1"`: os traços não entram na fila do Tab — seriam quarenta
       * paradas entre um controle e o seguinte. O caminho por teclado para tirar
       * um traço é a caixa de texto, dobrada em «Editar o SVG». */
      p.setAttribute("tabindex", "-1");
      p.addEventListener("click", (e) => { e.preventDefault(); tirar(i); });
    });
  }
  return no;
}

/* Os desenhos de `packs/<id>/icones/apps/` são arte acabada, de 6 a 10 cores
 * próprias.
 *
 * `<img>` com `data:` resolve os dois: cada desenho num documento só dele, e
 * imagem SVG não roda script nem busca nada fora. */
function desenharArte(texto, px) {
  const t = String(texto || "").trim();
  if (!t.includes("<svg")) return null;
  return elemento("img", {
    src: "data:image/svg+xml;charset=utf-8," + encodeURIComponent(t),
    alt: "", width: String(px), height: String(px),
  });
}

function tirar(i) {
  const doc = new DOMParser().parseFromString(OFICINA.svg, "image/svg+xml");
  const caminhos = doc.querySelectorAll("path");
  if (!caminhos[i]) return;
  OFICINA.historico.push(OFICINA.svg);
  if (OFICINA.historico.length > 30) OFICINA.historico.shift();
  caminhos[i].remove();
  /* O `XMLSerializer` devolve o mesmo documento menos um nó: `xmlns`,
   * `viewBox`, `fill="none"` e `stroke="currentColor"` do `<g>` sobrevivem
   * inteiros — e é por isso que o `_conferir_dialeto` do servidor continua
   * passando depois de tirar traço. */
  OFICINA.svg = new XMLSerializer().serializeToString(doc);
  if (OFICINA.escolhida !== "editado" && houveMao()) OFICINA.escolhida = "editado";
  redesenharOficina();
}

function desfazerOficina() {
  if (!OFICINA.historico.length) return;
  OFICINA.svg = OFICINA.historico.pop();
  if (!houveMao()) OFICINA.escolhida = OFICINA.escolhidaAntes || OFICINA.escolhida;
  redesenharOficina();
}

/* O gancho que o nó vivo instala; trocado a cada montagem, e é o que faz o
 * estado mandar na tela em vez de o contrário. */
let redesenharOficina = () => {};

/* Abrir o SVG no Boxy SVG é meia funcionalidade. A outra metade é o painel
 * PERCEBER que ela salvou lá: sem isso ela edita, volta, vê o desenho de antes
 * e conclui — com razão — que não funcionou.
 *
 * · o VIGIA (2 s, `mtime`) é o que faz parecer mágica: ela dá Ctrl+S no Boxy e
 * a lupa aqui repinta sozinha.
 *
 * `redesenharOficina` é o gancho que aponta sempre para o nó vivo. */
function pararVigiaEditor() {
  if (OFICINA.editorRelogio) clearInterval(OFICINA.editorRelogio);
  OFICINA.editorRelogio = null;
}

async function espiarEditor(pedido) {
  const r = await api("/api/app-desenho", {
    method: "POST",
    body: JSON.stringify({ app: OFICINA.app, acao: "editor-ler", mtime: OFICINA.editorMtime }),
  });
  if (r.erro) { pararVigiaEditor(); if (pedido) torrada(r.erro, "erro"); return; }
  if (!r.tem) { if (pedido) torrada("Ainda não há rascunho — abra no editor primeiro", "igual"); return; }
  if (!r.mudou) { if (pedido) torrada("O arquivo está como o painel deixou", "igual"); return; }
  OFICINA.historico.push(OFICINA.svg);
  if (OFICINA.historico.length > 30) OFICINA.historico.shift();
  OFICINA.editorMtime = r.mtime;
  OFICINA.svg = r.svg || "";
  /* O que volta do editor é o rascunho de TRAÇO que foi para lá — o botão de
   * abrir não existe para arte de pack —, então a lupa volta a ser de traço
   * mesmo que o cartão do pack tenha sido marcado no meio da espera. */
  OFICINA.arte = false;
  OFICINA.erro = "";
  /* Voltou de fora: já não é o desenho do cartão, é dela. O «editado» é o mesmo
   * estado em que a lupa e a caixa de texto deixam o desenho, e o servidor
   * decide sozinho, medindo, se isso vira `conversao` ou `mao` no mapa. */
  if (houveMao()) OFICINA.escolhida = "editado";
  redesenharOficina();
  /* O AVISO É O DO SERVIDOR, e ele chega ANTES do «Usar» de propósito: editor
   * de vetor grava `<defs>`, metadado e às vezes cor chapada, e o
   * `_conferir_dialeto` recusa. */
  torrada(r.aviso ? `Voltou do editor — ${r.aviso}` : "Voltou do editor", r.aviso ? "erro" : "ok");
}

function vigiarEditor() {
  pararVigiaEditor();
  OFICINA.editorEspiadas = 0;
  OFICINA.editorRelogio = setInterval(() => {
    if (!document.querySelector("details.oficina")) { pararVigiaEditor(); return; }
    if (++OFICINA.editorEspiadas > 450) { pararVigiaEditor(); return; }
    espiarEditor(false);
  }, 2000);
}

function oficinaDeDesenho(app, relerLista) {
  /* O VIGIA MORRE COM O APLICATIVO A QUE PERTENCE: sem isto, trocar de ficha
   * deixaria um `setInterval` perguntando pelo rascunho do aplicativo anterior
   * e escrevendo o desenho DELE por cima do que está na tela. */
  if (OFICINA.app !== app.id) { pararVigiaEditor(); OFICINA = oficinaZerada(app.id); }
  if (!OFICINA.cor) OFICINA.cor = corDaOficina(app);

  const caixa = elemento("details", { class: "oficina" });
  if (OFICINA.aberta) caixa.setAttribute("open", "");

  /* --- o resumo, e o único verbo que escreve ------------------------------ */
  const botaoUsar = elemento("button", {
    type: "button", class: "btn btn-accent btn-mini", texto: "Usar",
    title: "Grava este desenho e o põe na tela.",
    /* O `Usar` mora DENTRO do `<summary>`, e sem isto o clique nele borbulharia
     * até o summary e FECHARIA a oficina em cima do que ela acabou de gravar. */
    onclick: (e) => { e.stopPropagation(); e.preventDefault(); usar(); },
  });
  /* «Desenho no nosso traço» descrevia o RESULTADO para quem já sabe o que é "o
   * nosso traço"; o rótulo novo diz o VERBO e de quem é a oficina, que é o que
   * se lê antes de abrir. */
  caixa.append(elemento("summary", {}, [
    elemento("span", { texto: "Gerar ícone — MeowSystem" }), botaoUsar,
  ]));

  /* --- os lugares fixos: o estado pinta neles, nunca lê deles ------------- */
  const caixaFolha = elemento("div", { class: "oficina-folha", role: "group",
                                       "aria-label": "Variações" });
  /* O cartão «Do pack» abre marcado, e numa máquina onde a tela mostra OUTRA
   * coisa (a conversão em traço, com o pack desligado) uma marca sem palavra
   * seria a oficina dizendo que o trabalho dela foi trocado. */
  const aviso = elemento("p", { class: "frase", role: "status" });
  const caixaDock = elemento("div", { class: "oficina-dock-caixa" });
  const caixaLupa = elemento("div", { class: "oficina-lupa" });
  const dica = elemento("p", { class: "oficina-lupa-dica" });
  const caixaReguas = elemento("div", { class: "oficina-lado" });

  const area = elemento("textarea", {
    class: "oficina-fonte", rows: "10", spellcheck: "false",
    "data-foco": "oficina-svg", "aria-label": "O SVG do desenho",
    placeholder: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" …',
    oninput: () => {
      OFICINA.historico.push(OFICINA.svg);
      if (OFICINA.historico.length > 30) OFICINA.historico.shift();
      OFICINA.svg = area.value;
      OFICINA.erro = "";
      if (houveMao()) OFICINA.escolhida = "editado";
      pintarLupa(); pintarDock(); pintarFolha(); pintarAviso(); sincronizarReguas();
    },
  });
  area.value = OFICINA.svg;

  const botaoDesfazer = elemento("button", {
    type: "button", class: "btn btn-mini", texto: "Desfazer",
    disabled: !OFICINA.historico.length,
    onclick: desfazerOficina,
  });

  /* --- as réguas: nomes de gosto, não de algoritmo ------------------------ */
  /* As réguas descrevem o RESULTADO; a tradução para as bandeiras mora no
   * servidor, num lugar só.
   *
   * As duas novas nascem em 0 = desligado, e em 0 elas não acrescentam bandeira
   * nenhuma: a folha continua saindo byte a byte como saía ontem. */
  /* O `title` só entra quando há o que dizer — `title=""` no DOM é um atributo
   * a mais que não mostra balão nenhum. As duas réguas velhas se explicam pelo
   * nome; as novas precisam dizer que 0 é "não mexer". */
  const regua = (nome, rotulo, titulo) => elemento("label", {
    class: "oficina-regua", title: titulo || false,
  }, [
    elemento("span", { texto: rotulo }),
    elemento("input", {
      type: "range", name: nome, min: "0", max: "10", step: "1",
      value: String(OFICINA[nome]), "aria-label": rotulo,
      "data-foco": "oficina-" + nome,
      oninput: (e) => { OFICINA[nome] = Number(e.target.value); reguar(); },
    }),
  ]);
  const reguaDetalhe = regua("detalhe", "Detalhe");
  const reguaSuavidade = regua("suavidade", "Suavidade");
  const reguaFracas = regua("fracas", "Linhas fracas",
                            "Descarta a fronteira de pouco contraste. Em 0, nada muda.");
  const reguaMinimo = regua("minimo", "Traço mínimo",
                            "Descarta o traço curto demais para ler a 48 px. Em 0, nada muda.");

  /* --- a cor, escolhida aqui e não herdada -------------------------------- */
  /* A oficina já DESENHAVA na cor certa (`corDaOficina`), e é justamente isso
   * que fazia faltar: a cor estava na tela, viva, e não havia como trocá-la sem
   * fechar a oficina e descer até a fileira do acervo.
   *
   * O nome (`mauve`, `peach`) é o que vai para o mapa e serve os quatro
   * flavors; o hex entra só como `style` de fundo do botão, lido do
   * `ESQUEMA.paleta` que a página já recebeu. */
  const cores = elemento("div", { class: "cores-grade" });
  const flavorOficina = flavorEmVigor();
  const pintarCores = () => {
    for (const b of cores.querySelectorAll("button")) {
      b.setAttribute("aria-pressed", String(b.dataset.cor === OFICINA.cor));
    }
  };
  for (const nome of (ESQUEMA.paleta.ordem || [])) {
    const hex = ((ESQUEMA.paleta.flavors || {})[flavorOficina] || {})[nome];
    cores.append(elemento("button", {
      type: "button", "data-cor": nome, title: nome,
      "aria-pressed": String(nome === OFICINA.cor),
      style: hex ? `background:${hex}` : "",
      onclick: () => {
        OFICINA.cor = nome; pintarCores(); redesenharOficina();
        sincronizarCorDoCartao(nome);
      },
    }));
  }

  caixaReguas.append(reguaDetalhe, reguaSuavidade, reguaFracas, reguaMinimo,
                     elemento("div", { class: "rotulo-mini", texto: "Cor" }), cores,
                     elemento("div", { class: "escolha-botoes" }, [botaoDesfazer]));

  /* --- «Editar o SVG»: a caixa de texto, e o editor que a máquina já tem --- */
  /* A CAIXA DE TEXTO CONTINUA, E NÃO É TEIMOSIA: é o caminho de quem não tem
   * editor de vetor instalado, é o caminho por TECLADO para tirar um traço (a
   * lupa só responde ao mouse), e é o que o `tests/app-navegador.py` exercita.
   *
   * O BOTÃO NÃO PODE MENTIR: sem handler para `image/svg+xml` nesta máquina ele
   * simplesmente não nasce, e o `details` fica como estava. */
  const botoesEditor = elemento("div", { class: "escolha-botoes oficina-editor" });

  const edicao = elemento("details", { class: "oficina-edicao" }, [
    elemento("summary", { texto: "Editar o SVG" }), botoesEditor, area,
  ]);

  caixa.append(caixaFolha, aviso, caixaDock,
               elemento("div", { class: "oficina-par" }, [
                 elemento("div", {}, [caixaLupa, dica]), caixaReguas,
               ]),
               edicao);

  /* --- as pinturas: todas a partir de OFICINA, nunca do DOM --------------- */
  function pintarFolha() {
    caixaFolha.replaceChildren();
    if (OFICINA.original) {
      caixaFolha.append(elemento("figure", { class: "oficina-cartao oficina-original" }, [
        elemento("img", { src: OFICINA.original, alt: "", width: "48", height: "48" }),
        elemento("img", { src: OFICINA.original, alt: "", width: "96", height: "96" }),
        elemento("figcaption", { class: "oficina-rotulo", texto: "Original" }),
      ]));
    }
    /* A BORDA DUPLA diz que ele é de outra espécie antes de ela clicar, como a
     * tracejada do Original diz "régua": não é traço desta oficina, é arte
     * acabada, e o «Usar» não a grava — quem a põe na tela é o pack. */
    for (const p of OFICINA.pack) {
      const id = `pack:${p.pack}`;
      const b = elemento("button", {
        type: "button", class: "oficina-cartao", "data-id": id,
        "aria-pressed": String(OFICINA.escolhida === id),
        style: "border-style:double;border-width:3px",
        title: `Desenho do pack «${p.nome_pack}»` + (p.em_vigor ? " — é o que está na tela" : ""),
        onclick: () => escolher(id),
      });
      const a48 = desenharArte(p.svg, 48);
      const a96 = desenharArte(p.svg, 96);
      if (a48 && a96) b.append(a48, a96);
      else b.append(elemento("span", { class: "oficina-lugar", style: "width:96px;height:96px" }));
      b.append(elemento("span", { class: "oficina-rotulo",
        texto: OFICINA.pack.length > 1 ? `Do pack ${p.nome_pack}` : "Do pack" }));
      caixaFolha.append(b);
    }
    const cartoes = [];
    if (OFICINA.salvo && OFICINA.salvo.tem) {
      cartoes.push({ id: "salvo", rotulo: "Salvo", svg: OFICINA.salvo.svg,
                     nota: OFICINA.salvo.modo === "mao" ? "Retoque à mão" : "Conversão do mapa" });
    }
    cartoes.push(...OFICINA.variacoes);
    if (!cartoes.length) {
      if (OFICINA.ocupada) {
        for (let i = 0; i < 4; i++) {
          caixaFolha.append(elemento("span", { class: "oficina-cartao oficina-original" }, [
            elemento("span", { class: "oficina-lugar", style: "width:96px;height:96px" }),
            elemento("span", { class: "oficina-rotulo", texto: "Desenhando…" }),
          ]));
        }
      } else if (!OFICINA.erro) {
        caixaFolha.append(elemento("p", { class: "oficina-lupa-dica",
          texto: "Sem arte de fábrica — desenhe em «Editar o SVG»." }));
      }
      return;
    }
    for (const v of cartoes) {
      const b = elemento("button", {
        type: "button", class: "oficina-cartao", "data-id": v.id,
        "aria-pressed": String(OFICINA.escolhida === v.id),
        title: v.nota || v.erro || "",
        disabled: !!v.erro,
        onclick: () => escolher(v.id),
      });
      const g48 = v.erro ? null : desenhar(v.svg, 48, OFICINA.cor);
      const g96 = v.erro ? null : desenhar(v.svg, 96, OFICINA.cor);
      if (g48 && g96) {
        b.append(g48, g96);
      } else {
        b.append(elemento("span", { class: "oficina-lugar", style: "width:96px;height:96px" }));
      }
      b.append(elemento("span", {
        class: "oficina-rotulo" + (v.erro ? " oficina-erro" : ""), texto: v.rotulo }));
      caixaFolha.append(b);
    }
  }

  function pintarDock() {
    caixaDock.replaceChildren();
    const eu = OFICINA.arte ? desenharArte(OFICINA.svg, 48) : desenhar(OFICINA.svg, 48, OFICINA.cor);
    if (!eu) return;
    /* Um desenho lido sozinho a 200 px engana: metade dos convertidos de
     * 08/2026 foi refeita porque lia grande e sumia pequena. */
    const tira = elemento("div", { class: "oficina-dock" });
    const [a, b] = OFICINA.vizinhos;
    if (a) tira.append(desenhar(a.svg, 48, a.cor));
    tira.append(elemento("span", { class: "oficina-dock-eu" }, [eu]));
    if (b) tira.append(desenhar(b.svg, 48, b.cor));
    caixaDock.append(elemento("span", { class: "oficina-legenda", texto: "Como fica no dock" }), tira);
  }

  function pintarLupa() {
    caixaLupa.replaceChildren();
    dica.textContent = "";
    if (OFICINA.erro) {
      caixaLupa.append(elemento("p", { class: "oficina-lupa-dica oficina-erro", texto: OFICINA.erro }));
      return;
    }
    if (OFICINA.ocupada) {
      caixaLupa.append(elemento("p", { class: "oficina-lupa-dica", texto: "Desenhando…" }));
      return;
    }
    /* A ARTE DE PACK NÃO SE EDITA POR TRAÇO: ela é chapada, e "clique num
     * traço para tirar" num desenho de dez cores tiraria uma mancha, não uma
     * linha. A lupa mostra, e a dica diz por que não responde ao clique. */
    if (OFICINA.arte) {
      const img = desenharArte(OFICINA.svg, 200);
      if (img) {
        caixaLupa.append(img);
        dica.textContent = "Arte acabada do pack — ela não se edita por traço";
      }
      return;
    }
    const no = desenhar(OFICINA.svg, 200, OFICINA.cor, { clicavel: true });
    if (!no) {
      /* Sem arte de fábrica quem explica é a folha, uma vez — repetir a mesma
       * linha a 20 px de distância é o contrário de "menos palavras". */
      if (String(OFICINA.svg || "").trim()) {
        caixaLupa.append(elemento("p", { class: "oficina-lupa-dica oficina-erro",
          texto: "O texto não é um SVG — falta fechar alguma etiqueta?" }));
      }
      return;
    }
    caixaLupa.append(no);
    dica.textContent = "Clique num traço para tirar";
  }

  /* O que a linha de aviso diz, a partir do cartão escolhido — ver `aviso`. */
  function cartaoDoPack(id) {
    return OFICINA.pack.find((p) => `pack:${p.pack}` === id) || null;
  }

  function pintarAviso() {
    aviso.textContent = "";
    const p = cartaoDoPack(OFICINA.escolhida);
    const vigor = OFICINA.emVigor;
    if (p && p.em_vigor) {
      aviso.textContent = `Na tela está este desenho, do pack «${p.nome_pack}». `
        + "As variações ao lado são as alternativas em traço.";
    } else if (p) {
      aviso.textContent = `Este é o desenho do pack «${p.nome_pack}», e não o que está na tela`
        + (vigor ? ` — lá está ${vigor.frase}` : "") + ". Marcar o cartão não troca nada"
        + (p.ativo ? "." : `: ele vale com o pack «${p.nome_pack}» no ar.`);
    } else if (OFICINA.arte) {
      /* Mexeram no texto de uma arte de pack pela caixa «Editar o SVG». */
      aviso.textContent = "Isto é arte de pack: a oficina de traço não a grava. "
        + "O retoque se faz no arquivo do pack.";
    }
  }

  function pintarEditor() {
    botoesEditor.replaceChildren();
    const ed = OFICINA.editor;
    if (!ed || !ed.tem) return;
    botoesEditor.append(elemento("button", {
      type: "button", class: "btn btn-mini",
      /* O NOME DO EDITOR ENTRA NO RÓTULO, e é medido, não cravado: o servidor
       * pergunta ao `xdg-mime` quem abre `image/svg+xml` e lê o `Name=` do
       * `.desktop`. */
      texto: ed.nome ? `Abrir no ${ed.nome}` : "Abrir no editor",
      title: "Grava um rascunho fora do projeto e o abre. Salve lá e o painel relê sozinho.",
      disabled: !String(OFICINA.svg || "").trim(),
      onclick: abrirNoEditor,
    }));
    botoesEditor.append(elemento("button", {
      type: "button", class: "btn btn-mini", texto: "Reler",
      title: "Traz de volta o que está no arquivo agora.",
      onclick: () => espiarEditor(true),
    }));
  }

  function sincronizarReguas() {
    reguaDetalhe.querySelector("input").value = String(OFICINA.detalhe);
    reguaSuavidade.querySelector("input").value = String(OFICINA.suavidade);
    reguaFracas.querySelector("input").value = String(OFICINA.fracas);
    reguaMinimo.querySelector("input").value = String(OFICINA.minimo);
    pintarCores();
    botaoDesfazer.disabled = !OFICINA.historico.length;
    /* Ele escreve no acervo de TRAÇO (`apps-convertidos.map` e `retoques/`), e
     * um desenho de dez cores ali seria recusado pelo `_conferir_dialeto` com
     * uma frase sobre cor que não explica nada. */
    botaoUsar.disabled = !String(OFICINA.svg || "").trim() || OFICINA.ocupada || OFICINA.arte;
    /* O «Abrir no …» segue o mesmo juízo do «Usar»: sem desenho não há o que
     * levar para fora. O «Reler» NÃO: ele é justamente o que traz desenho
     * quando não há nenhum aqui. */
    const abrir = botoesEditor.querySelector("button");
    if (abrir) abrir.disabled = !String(OFICINA.svg || "").trim() || OFICINA.arte;
    if (area.value !== OFICINA.svg) area.value = OFICINA.svg;
  }

  function pintarTudo() {
    pintarFolha(); pintarAviso(); pintarDock(); pintarLupa(); pintarEditor(); sincronizarReguas();
  }
  redesenharOficina = pintarTudo;

  /* --- carregar: a folha inteira numa chamada ----------------------------- */
  async function carregar() {
    OFICINA.ocupada = true; OFICINA.erro = ""; pintarTudo();
    const r = await api("/api/app-desenho", {
      method: "POST", body: JSON.stringify({ app: OFICINA.app, acao: "variacoes" }),
    });
    OFICINA.ocupada = false;
    OFICINA.carregou = true;
    if (r.erro) { OFICINA.erro = r.erro; pintarTudo(); return; }
    OFICINA.origem = r.origem || "";
    OFICINA.original = r.original || "";
    OFICINA.capa = r.capa || "";
    OFICINA.variacoes = r.variacoes || [];
    OFICINA.vizinhos = r.vizinhos || [];
    OFICINA.salvo = r.salvo || null;
    OFICINA.pack = r.pack || [];
    OFICINA.emVigor = r.em_vigor || null;
    OFICINA.editor = r.editor || null;
    /* O NOME DO ÍCONE, que nem sempre é o id do `.desktop` — num jogo da Steam
     * o `.desktop` é `meow-steam-1715980` e o arquivo é `steam_icon_1715980`.
     * Quem resolve isso é o servidor; a página só guarda a resposta. */
    OFICINA.nome = r.nome || "";
    /* QUANDO HÁ UM: abrir a ficha de um aplicativo que já tem desenho e ver uma
     * variação nova marcada seria a tela dizendo que o trabalho dela foi
     * trocado.
     *
     * VENCE OS DOIS: é o desenho que alguém fez à mão para este aplicativo, e a
     * conversão automática é o plano B, não o A. */
    const inicial = OFICINA.pack.length ? `pack:${OFICINA.pack[0].pack}`
      : (OFICINA.salvo && OFICINA.salvo.tem)
      ? "salvo" : ((OFICINA.variacoes.find((v) => !v.erro) || {}).id || null);
    if (inicial) escolher(inicial); else pintarTudo();
  }

  function escolher(id) {
    let c = null;
    if (id === "salvo" && OFICINA.salvo && OFICINA.salvo.tem) {
      /* O salvo não traz parâmetros: ele é o que é. Gravá-lo de volta vira
       * retoque à mão, que é a verdade — o servidor decide isso medindo. */
      c = { id: "salvo", svg: OFICINA.salvo.svg, parametros: "", fonte: "icone" };
    } else if (id.startsWith("pack:")) {
      /* O do pack também não traz parâmetros, e traz `arte`: é o que muda a
       * lupa, a tira do dock e o «Usar» para o modo de arte acabada. */
      const p = cartaoDoPack(id);
      c = p ? { id, svg: p.svg, parametros: "", fonte: "icone", arte: true } : null;
    } else {
      c = OFICINA.variacoes.find((v) => v.id === id);
    }
    if (!c || c.erro) return;
    OFICINA.escolhida = id;
    OFICINA.escolhidaAntes = id;
    OFICINA.arte = !!c.arte;
    OFICINA.base = OFICINA.svg = c.svg || "";
    OFICINA.parametros = c.parametros || "";
    OFICINA.fonte = c.fonte || "icone";
    if (c.detalhe != null) OFICINA.detalhe = c.detalhe;
    if (c.suavidade != null) OFICINA.suavidade = c.suavidade;
    OFICINA.fracas = c.fracas || 0;
    OFICINA.minimo = c.minimo || 0;
    OFICINA.cheia = !!c.cheia;
    OFICINA.historico = [];
    OFICINA.erro = "";
    pintarTudo();
  }

  /* --- as réguas re-vetorizam a ESCOLHIDA, e só ela ----------------------- */
  function reguar() {
    clearTimeout(OFICINA.temporizador);
    /* 250 ms DE ESPERA, e não é enfeite: `input` numa régua dispara a cada
     * pixel do arrasto, e sem a espera um gesto de ponta a ponta pediria dez
     * conversões — dez processos, para ela ver só a última. */
    OFICINA.temporizador = setTimeout(async () => {
      OFICINA.ocupada = true; OFICINA.erro = ""; pintarLupa(); sincronizarReguas();
      const r = await api("/api/app-desenho", {
        method: "POST", body: JSON.stringify({
          app: OFICINA.app, acao: "vetorizar", fonte: OFICINA.fonte,
          detalhe: OFICINA.detalhe, suavidade: OFICINA.suavidade, cheia: OFICINA.cheia,
          fracas: OFICINA.fracas, minimo: OFICINA.minimo }),
      });
      OFICINA.ocupada = false;
      if (r.erro) { OFICINA.erro = r.erro; pintarTudo(); return; }
      OFICINA.base = OFICINA.svg = r.svg || "";
      /* A régua vetoriza a arte de FÁBRICA, e o que volta é traço — mesmo que
       * o cartão marcado antes fosse o do pack. */
      OFICINA.arte = false;
      OFICINA.parametros = r.parametros || "";
      OFICINA.historico = [];
      /* NENHUM CARTÃO FICA MARCADO depois da régua, porque o desenho já não é o
       * dele. Clicar num cartão de novo devolve as réguas para os valores dele. */
      OFICINA.escolhida = "editado";
      OFICINA.escolhidaAntes = "editado";
      pintarTudo();
    }, 250);
  }

  /* --- o editor de fora: a ida ------------------------------------------- */
  /* UM PAINEL SUBIDO SEM JANELA NÃO ABRE O EDITOR (`r.sem_janela`): é o `run.sh
   * --sem-abrir` dos testes, e a janela nasceria na tela dela. */
  async function abrirNoEditor() {
    const r = await api("/api/app-desenho", {
      method: "POST",
      body: JSON.stringify({ app: OFICINA.app, acao: "editor", svg: OFICINA.svg }),
    });
    if (r.erro) { torrada(r.erro, "erro"); return; }
    OFICINA.editorMtime = r.mtime || 0;
    if (r.sem_janela) { torrada(r.aviso, "igual"); return; }
    /* O VIGIA COMEÇA AQUI E NÃO ANTES: só faz sentido perguntar "mudou?" depois
     * de haver arquivo e editor abertos. Ver o cabeçalho do `espiarEditor`. */
    vigiarEditor();
    torrada(`Aberto no ${(r.editor && r.editor.nome) || "editor"} — salve lá e o desenho volta`, "ok");
  }

  async function usar() {
    const r = await api("/api/app-desenho", {
      method: "POST", body: JSON.stringify({
        app: OFICINA.app, acao: "salvar", svg: OFICINA.svg, cor: OFICINA.cor,
        fonte: OFICINA.fonte, parametros: OFICINA.parametros }),
    });
    if (r.erro) { OFICINA.erro = r.erro; torrada(r.erro, "erro"); pintarLupa(); return; }
    /* O NOME GRAVADO ENTRA NA TORRADA quando difere do aplicativo: num jogo da
     * Steam o `.desktop` é `meow-steam-1715980` e o desenho vai para
     * `steam_icon_1715980`, que é o que o `Icon=` pede. */
    torrada(`${app.nome}: desenho salvo em ${r.cor}`
            + (r.nome && r.nome !== app.id ? ` (como ${r.nome})` : "")
            + (r.modo === "mao" ? ", à mão" : "")
            + (r.tirou_retoque ? " — o retoque anterior saiu" : "")
            + (r.saiu_do_arcticons ? " — e saiu do mapa Arcticons" : ""), "ok");
    /* As duas coisas que até ontem eram dois botões: gravar e pôr na tela. */
    await rodarAcao("icones_traco");
    OFICINA.carregou = false;      // o «Salvo» mudou; a folha relê ao remontar
    await fimDoTrabalho();
    await relerLista();
  }

  caixa.addEventListener("toggle", () => {
    OFICINA.aberta = caixa.open;
    /* A FOLHA ABRE JUNTO COM O `details`: sem clique em «Vetorizar», porque
     * abrir já é pedir para ver. */
    if (caixa.open && !OFICINA.carregou && !OFICINA.ocupada) carregar();
    /* Um `setInterval` perguntando pelo rascunho de uma oficina que não está
     * mais na tela é uma chamada a cada 2 s pelo resto da sessão, e o desenho
     * que ele traria não teria onde aparecer. */
    if (!caixa.open) pararVigiaEditor();
  });

  pintarTudo();
  if (OFICINA.aberta && !OFICINA.carregou && !OFICINA.ocupada) carregar();
  return caixa;
}

/* A cor com que a oficina ABRE — e só a abertura,. Agora a fileira de amostras
 * dentro da oficina manda, e esta função responde só à primeira pergunta: com
 * que cor este aplicativo já está na tela?
 *
 * Continua sendo a MESMA cor da fileira do acervo, e por isso o `if
 * (!OFICINA.cor)` do `oficinaDeDesenho`: as duas fileiras escrevem no mesmo
 * campo do mapa, e abrir com valores diferentes seriam duas verdades sobre ele. */
/* Elas mexem no DOM da OUTRA fileira e não no estado dela, de propósito: cada
 * fileira é dona do seu valor (`corEscolhida` mora no fecho do cartão,
 * `OFICINA.cor` no objeto da oficina), e uma função que atravessasse os dois
 * fechos precisaria de um terceiro dono — que é justamente a terceira fonte de
 * verdade que este repositório recusa em toda parte. */
function sincronizarCorDaOficina(nome) {
  if (typeof OFICINA === "object" && OFICINA) OFICINA.cor = nome;
  const grade = document.querySelector(".oficina-lado .cores-grade");
  if (!grade) return;
  for (const b of grade.querySelectorAll("button")) {
    b.setAttribute("aria-pressed", String(b.dataset.cor === nome));
  }
  if (typeof redesenharOficina === "function") redesenharOficina();
}

function sincronizarCorDoCartao(nome) {
  const grade = document.querySelector(".escolha-icone .cores-grade");
  if (!grade) return;
  for (const b of grade.querySelectorAll("button")) {
    b.setAttribute("aria-pressed", String(b.dataset.cor === nome));
  }
}

function corDaOficina(app) {
  /* O acervo de traço vem PRIMEIRO: é o mapa em que esta oficina grava, e um
   * aplicativo que já tem desenho à mão não pode voltar para a primeira cor da
   * paleta só porque o outro mapa não o conhece. */
  if (app.traco && app.traco.cor) return app.traco.cor;
  if (app.mapa && app.mapa.cor) return app.mapa.cor;
  const marcada = document.querySelector(".escolha-icone .cores-grade button[aria-pressed=\"true\"]");
  if (marcada && marcada.dataset.cor) return marcada.dataset.cor;
  return (ESQUEMA.paleta.ordem || [])[0] || "mauve";
}

/* O `gerar_icones_autorais.py` desenhava dois aplicativos cravados no Python.
 *
 * Quem desenha é o `pack.py`, pela mesma função que escreve o arquivo; a
 * página só pede e mostra.
 *
 * ESCOLHER NÃO É GRAVAR, a regra dela. */
let AUTORAL = { carregou: false, ocupada: false, erro: "", pack: "", nomePack: "",
                desenhos: [], cores: [], nome: null, papeis: null, herdadoDe: "",
                previas: [], temporizador: null };
let redesenharAutoral = () => {};

async function carregarAutoral() {
  AUTORAL.ocupada = true;
  const r = await api("/api/autorais", { method: "POST", body: JSON.stringify({ acao: "listar" }) });
  AUTORAL.ocupada = false;
  AUTORAL.carregou = true;
  AUTORAL.erro = r.erro || "";
  if (!r.erro) {
    AUTORAL.pack = r.pack || "";
    AUTORAL.nomePack = r.nome_pack || "";
    AUTORAL.desenhos = r.desenhos || [];
    AUTORAL.cores = r.cores || [];
    /* Depois de salvar, o desenho aberto passa a ser do pack no ar: o que diz
     * de onde ele vem é a lista nova, não a lembrança de antes do clique. */
    const aberto = AUTORAL.desenhos.find((d) => d.nome === AUTORAL.nome);
    if (aberto) AUTORAL.herdadoDe = aberto.herdado ? (aberto.nome_origem || aberto.pack) : "";
  }
  render();
}

function previaAutoral() {
  clearTimeout(AUTORAL.temporizador);
  /* A mesma espera das réguas da oficina: trocar três selects seguidos não
   * precisa de três desenhos, só do último. */
  AUTORAL.temporizador = setTimeout(async () => {
    const r = await api("/api/autorais", {
      method: "POST",
      body: JSON.stringify({ acao: "previa", nome: AUTORAL.nome, papeis: AUTORAL.papeis }),
    });
    AUTORAL.erro = r.erro || "";
    AUTORAL.previas = r.erro ? [] : (r.previas || []);
    redesenharAutoral();
  }, 200);
}

async function salvarAutoral() {
  if (!AUTORAL.nome) return;
  AUTORAL.ocupada = true;
  redesenharAutoral();
  const r = await api("/api/autorais", {
    method: "POST",
    body: JSON.stringify({ acao: "salvar", nome: AUTORAL.nome, papeis: AUTORAL.papeis }),
  });
  AUTORAL.ocupada = false;
  if (r.erro) { AUTORAL.erro = r.erro; torrada(r.erro, "erro"); redesenharAutoral(); return; }
  /* Onde, porque um desenho herdado vira cópia no pack no ar, e ela precisa
   * saber que o do pack de origem continua como estava.
   *
   * ATÉ A REVISÃO A SEGUNDA METADE ERA SEMPRE A MESMA: "chega à tela na próxima
   * passagem dos ícones". */
  const onde = `${AUTORAL.nome}: salvo no pack «${r.nome_pack}»`
             + (r.copiou && AUTORAL.herdadoDe ? `, e o do «${AUTORAL.herdadoDe}» fica como estava` : "");
  if ((r.na_tela || []).length) {
    torrada(onde + " — chega à tela na próxima passagem dos ícones", "ok");
  } else {
    torrada(onde + ". Nenhum ícone na tela usa este desenho hoje: o pack mudou, a tela não", "igual");
  }
  AUTORAL.carregou = false;
  render();
}

function oficinaAutoral() {
  const caixa = elemento("section", {
    class: "oficina-autoral",
    style: "display:flex;flex-direction:column;gap:.7rem;margin:1.2rem 0;padding:1.1rem;"
         + "border:1px solid var(--surface1);border-radius:var(--r-3);background:var(--mantle)",
  });
  const topo = elemento("div", { class: "oficina-topo com-dica" }, [
    elemento("h3", { class: "titulo-cartao",
      texto: AUTORAL.nomePack ? `Desenhos autorais do pack «${AUTORAL.nomePack}»`
                              : "Desenhos autorais do pack" }),
  ]);
  caixa.append(topo);
  if (!AUTORAL.carregou) {
    if (!AUTORAL.ocupada) carregarAutoral();
    caixa.append(elemento("p", { class: "sem-previa", texto: "Lendo os desenhos do pack…" }));
    return caixa;
  }
  topo.append(...gatilhoDeDica("dica-oficina-autoral", "Sobre os desenhos autorais", [
    elemento("p", { class: "resumo", texto: "Desenhos que nascem da paleta, por papel. "
      + "Trocar uma cor repinta a prévia; só «Salvar no pack» grava." }),
  ]));

  const escolha = elemento("div", { class: "escolha-botoes", role: "group", "aria-label": "Desenho" });
  for (const d of AUTORAL.desenhos) {
    escolha.append(elemento("button", {
      type: "button", class: "btn btn-mini", texto: d.nome,
      "aria-pressed": String(AUTORAL.nome === d.nome),
      disabled: !!d.erro,
      title: d.erro ? "A declaração foi recusada — rode meow pack validar"
                    : (d.herdado ? `Herdado do pack ${d.nome_origem || d.pack}` : ""),
      onclick: () => {
        AUTORAL.nome = d.nome;
        AUTORAL.herdadoDe = d.herdado ? (d.nome_origem || d.pack) : "";
        /* Cópia, e não referência: mexer num select não pode mudar a lista
         * que veio do servidor — é ela que diz o que está gravado. */
        AUTORAL.papeis = JSON.parse(JSON.stringify(d.papeis || {}));
        AUTORAL.previas = [];
        AUTORAL.erro = "";
        previaAutoral();
        render();
      },
    }));
  }
  /* Era a frase «Este pack não declara nenhum desenho autoral.» com o
   * «Salvar no pack» aceso embaixo, sem nada a salvar: texto no lugar do
   * gesto. */
  if (!AUTORAL.desenhos.length && !AUTORAL.erro) return null;
  caixa.append(escolha);

  const papeis = elemento("div", { role: "group", "aria-label": "Papéis",
    style: "display:grid;grid-template-columns:auto 1fr 1fr;gap:.4rem .6rem;align-items:center" });
  const previas = elemento("div", { style: "display:flex;flex-direction:column;gap:.5rem" });
  const nota = elemento("p", { class: "frase", role: "status" });
  const botaoSalvar = elemento("button", {
    type: "button", class: "btn btn-accent", texto: "Salvar no pack", onclick: salvarAutoral,
  });
  caixa.append(papeis, previas, nota, elemento("div", { class: "escolha-botoes" }, [botaoSalvar]));

  function pintarPapeis() {
    papeis.replaceChildren();
    if (!AUTORAL.nome || !AUTORAL.papeis) return;
    papeis.append(elemento("span", { class: "rotulo-mini", texto: "Papel" }),
                  elemento("span", { class: "rotulo-mini", texto: "Escuro" }),
                  elemento("span", { class: "rotulo-mini", texto: "Claro" }));
    for (const [papel, par] of Object.entries(AUTORAL.papeis)) {
      papeis.append(elemento("span", { texto: papel }));
      for (const lado of ["escuro", "claro"]) {
        const sel = elemento("select", {
          "aria-label": `${papel}, flavor ${lado}`, "data-foco": `autoral-${papel}-${lado}`,
          onchange: (e) => { par[lado] = e.target.value; previaAutoral(); },
        });
        for (const cor of AUTORAL.cores) {
          /* `<accent>` é o marcador do formato — na tela, a palavra. */
          const opcao = elemento("option", { value: cor, texto: cor === "<accent>" ? "acento" : cor });
          if (cor === par[lado]) opcao.selected = true;
          sel.append(opcao);
        }
        papeis.append(sel);
      }
    }
  }

  function pintarPrevias() {
    previas.replaceChildren();
    for (const p of AUTORAL.previas) {
      const fileira = elemento("div", { style: "display:flex;align-items:center;gap:.5rem;flex-wrap:wrap" },
        [elemento("span", { class: "rotulo-mini", style: "min-width:6rem", texto: p.flavor })]);
      for (const f of p.fundos || []) {
        fileira.append(elemento("span", {
          title: `Sobre ${f.nome}`,
          style: "display:grid;place-items:center;width:64px;height:64px;"
               + `border-radius:var(--r-2);background:${f.cor}`,
        }, [desenharArte(p.svg, 48)]));
      }
      previas.append(fileira);
    }
  }

  /* OS SELECTS NASCEM UMA VEZ POR MONTAGEM, e a volta da prévia não os refaz:
   * refazê-los tiraria o foco do select que ela acabou de mudar pelo teclado,
   * e a próxima seta cairia no vazio. A prévia, a nota e o botão, sim. */
  function pintar() {
    pintarPrevias();
    nota.textContent = AUTORAL.erro
      || (AUTORAL.nome && AUTORAL.herdadoDe
          ? `Este desenho vem do pack «${AUTORAL.herdadoDe}». Salvar grava uma cópia no «${AUTORAL.nomePack}».`
          : "");
    botaoSalvar.disabled = !AUTORAL.nome || AUTORAL.ocupada;
  }
  redesenharAutoral = pintar;
  pintarPapeis();
  pintar();
  return caixa;
}

/* --- os jogos da Steam ----------------------------------------------------- */
/* Aqui ela escolhe; quem age é o `scripts/jogos_steam.sh` no botão "Arrumar os
 * jogos no lançador", que já passa pelo confirmar e pela gaveta de saída. */
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
    body: JSON.stringify({ appid, acao, motivo, remover: !!remover }),
  });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  torrada(remover ? "Voltou ao normal" : "Escolha gravada", "ok");
  JOGO_ABERTO = null;
  /* O `confirmado` vai direto, sem uma segunda caixa: o que a tranca do
   * `jogos_aplicar` protege é o apagamento, e só se apaga jogo cuja decisão foi
   * perguntada no botão dele («Marcar para apagar»). */
  const t = await api("/api/rodar", {
    method: "POST",
    body: JSON.stringify({ acao: "jogos_aplicar", argumento: "", confirmado: true }),
  });
  if (t.erro) torrada(t.erro, "erro");
  else abrirResultado(t);
  await carregarJogos();
}

/* Só que a arrumação é a passagem INTEIRA do `jogos_steam.sh`: ela aplica toda
 * marca que estiver esperando no mapa — inclusive um «Marcar para apagar» de
 * outro dia —, e o clique num jogo disparava tudo sem dizer.
 *
 * QUEM RESPONDE É A PRÓPRIA PASSAGEM, em ensaio, sobre uma cópia do mapa com a
 * decisão dentro (`previa: true` no mesmo POST de gravar — ver o
 * `_api_jogo_fora`). */
function pintarEfeitoDosJogos(caixa, r) {
  if (r.erro) {
    caixa.replaceChildren(elemento("p", {
      texto: `Não deu para conferir antes: ${r.erro}. O «Ver sem mudar» mostra a passagem inteira.`,
    }));
    return;
  }
  const partes = [];
  for (const [campo, rotulo] of [
    ["saem", "Saem do lançador"],
    ["entram", "Entram no lançador"],
    ["repetem", "Cartões duplicados ou antigos que saem"],
    ["apagam", "Têm os arquivos apagados"],
  ]) {
    const itens = r[campo] || [];
    if (!itens.length) continue;
    partes.push(elemento("p", { "data-efeito": campo }, [
      elemento("strong", { texto: `${rotulo}: ` }),
      itens.map((x) => x.nome).join(", "),
    ]));
  }
  if (!partes.length) {
    partes.push(elemento("p", { "data-efeito": "nada",
      texto: "Nenhum atalho entra nem sai do lançador, e nenhum arquivo é apagado." }));
  }
  caixa.replaceChildren(...partes);
}

/* `rotulos` ({titulo, ok}) é de quem chama com outro gesto que não os dois de
 * cima: o «Voltar ao normal» remove a linha como o «Tirar da lista», e a caixa
 * tem de falar a língua do botão que ela clicou. */
async function confirmarJogo(j, acao, motivo, remover, rotulos = {}) {
  const pedido = { appid: j.appid, acao, motivo, remover: !!remover };
  const efeito = elemento("div", { class: "efeito-jogos" }, [
    elemento("p", { texto: "Conferindo o que a arrumação faria…" }),
  ]);
  const resposta = perguntar({
    titulo: rotulos.titulo
         || (remover ? `Tirar ${j.nome} da lista?` : `Tirar ${j.nome} do lançador?`),
    texto: (remover ? "A linha sai da lista" : "A decisão fica anotada")
         + " e o lançador é arrumado agora — com todas as marcas que estiverem "
         + "esperando, e não só esta.",
    corpo: efeito,
    ok: rotulos.ok || (remover ? "Tirar da lista" : "Tirar do lançador"),
    ensaio: true,
  });
  api("/api/jogo-fora", { method: "POST", body: JSON.stringify({ ...pedido, previa: true }) })
    .then((r) => pintarEfeitoDosJogos(efeito, r));
  const escolha = await resposta;
  if (escolha === "sim") { await definirJogo(j.appid, acao, motivo, remover); return; }
  if (escolha !== "seco") return;
  const t = await api("/api/jogo-fora", { method: "POST", body: JSON.stringify({ ...pedido, seco: true }) });
  if (t.erro) { torrada(t.erro, "erro"); return; }
  abrirResultado(t, () => definirJogo(j.appid, acao, motivo, remover));
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

  /* Conta o que tem manifesto, que é o que a grade desenha. */
  const instalados = (JOGOS.jogos || []).filter((j) => !j.sem_manifesto).length;
  caixa.append(elemento("div", { class: "linha-filtro" }, [
    elemento("input", {
      type: "search", class: "busca-apps", value: JOGOS_BUSCA, "data-foco": "jogos",
      placeholder: "Filtrar jogo…", "aria-label": "Filtrar jogo",
      oninput: (e) => { JOGOS_BUSCA = e.target.value; render(); },
    }),
    elemento("div", { class: "selos" }, [
      selo("jogo", { texto: String(instalados),
        balao: instalados === 0 ? "Nenhum jogo da Steam. O Proton e os runtimes são ferramentas"
          : instalados === 1 ? "1 jogo instalado na Steam" : `${instalados} jogos instalados na Steam` }),
    ]),
  ]));

  /* OS DOIS BOTÕES MORAM AQUI, e não numa aba "Fazer" separada. É o que a
   * galeria já faz com banir e devolver: a ação fica ao lado da coisa em que
   * ela age. */
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

  /* Ela continua tendo de aparecer: sem manifesto, o laço do servidor não a
   * encontra, e tirá-la da tela seria esconder a única coisa que ainda existe
   * sobre aquela decisão. */
  const orfas = lista.filter((j) => j.sem_manifesto);
  const comJogo = lista.filter((j) => !j.sem_manifesto);

  /* Uma grade vazia e uma grade que ainda está carregando são a mesma tela, e
   * quem digitou não sabe se errou o nome, se o jogo saiu, ou se a página
   * quebrou. */
  if (termo && !lista.length) {
    caixa.append(elemento("p", {
      class: "sem-previa",
      texto: `Nenhum jogo casa com “${JOGOS_BUSCA.trim()}”.`,
    }));
    return caixa;
  }

  /* Sem jogo instalado ela nascia como um retângulo sem nada, com o «Pular os
   * jogos» apontando para ele; agora é uma frase. */

  const grade = elemento("div", { class: "grade-jogos" });
  for (const j of comJogo) {
    const marca = etiquetaDoJogo(j);
    const capa = j.url
      ? elemento("img", { src: j.url, alt: "", loading: "lazy" })
      /* Jogo sem capa é jogo sem manifesto: a decisão que sobreviveu ao jogo.
       * O retângulo com o número da Steam diz isso sem precisar de frase. */
      : elemento("div", { class: "jogo-sem-capa", texto: j.appid });
    grade.append(elemento("button", {
      type: "button",
      class: "jogo" + (JOGO_ABERTO === j.appid ? " aberto" : "")
             + (j.acao || j.gasto ? " marcado" : ""),
      /* Quem passa o rato numa capa quer saber que número é aquele, não como
       * a Steam chama o campo dela. */
      title: `Número deste jogo na Steam: ${j.appid}`,
      onclick: () => { JOGO_ABERTO = JOGO_ABERTO === j.appid ? null : j.appid; render(); },
    }, [
      capa,
      elemento("span", { class: "app-nome", texto: j.nome }),
      elemento("span", { class: "app-marca " + marca.classe, texto: marca.texto }),
    ]));
    if (JOGO_ABERTO === j.appid) grade.append(montarEscolhaDeJogo(j));
  }
  if (comJogo.length) {
    caixa.append(pulaGrade("apos-jogos", "Pular os jogos"));
    caixa.append(grade);
    caixa.append(alvoDoPulo("apos-jogos"));
  }

  if (orfas.length) {
    caixa.append(elemento("h3", { class: "subsecao-titulo com-dica" }, [
      elemento("span", { texto: "Decisões já executadas" }),
      ...gatilhoDeDica("dica-jogos-orfas", "Sobre as decisões já executadas", [
        elemento("p", { texto: orfas.length === 1
          ? "Este jogo não está mais na máquina. A linha fica aqui só para você "
            + "poder tirá-la: ela não traz o jogo de volta, e não apaga mais nada."
          : `Estes ${orfas.length} jogos não estão mais na máquina. As linhas ficam `
            + "aqui só para você poder tirá-las: elas não trazem os jogos de volta, "
            + "e não apagam mais nada." }),
      ]),
    ]));
    const cxOrfas = elemento("div", { class: "lista-orfas" });
    for (const j of orfas) {
      cxOrfas.append(elemento("div", { class: "linha-orfa" }, [
        elemento("span", { class: "orfa-nome", texto: j.nome }),
        elemento("span", { class: "orfa-nota",
          /* É o nome do campo na Steam, e numa linha que já traz o NOME do
           * jogo ele não distingue nada: quem lê "Mad King Redemption Demo"
           * não precisa do número para saber de qual jogo se trata. */
          title: `Número deste jogo na Steam: ${j.appid}`,
          texto: j.apagado_em
            ? `arquivos apagados em ${j.apagado_em}`
            : "ainda na lista" }),
        elemento("button", {
          type: "button", class: "btn btn-mini",
          texto: "Tirar da lista",
          /* 96 -> 49 caracteres, pelo teto do balão. A segunda metade dizia
           * duas vezes a mesma coisa: se nenhum arquivo é tocado, o jogo que
           * não está no disco continua não estando. */
          title: "Tira a decisão da lista. Pergunta antes de arrumar.",
          onclick: () => confirmarJogo(j, "", "", true),
        }),
      ]));
    }
    caixa.append(cxOrfas);
  }

  /* A razão é de uso, e não de arrumação: a aba de ícones existe para vestir os
   * PROGRAMAS com o traço do projeto, e um jogo não se veste — ele tem capa
   * própria, vem e vai com a licença, e o que ela decide sobre ele é outra
   * coisa.
   *
   * Os que não casam são a própria Steam e o ProtonUp-Qt (que se declaram
   * `Categories=Game`) e um jogo cujo cartão ainda não foi escrito. */
  if ((JOGOS.apps || []).length) {
    const comAtalho = JOGOS.total_apps ?? JOGOS.apps.length;
    caixa.append(elemento("h3", { class: "subsecao-titulo com-dica" }, [
      elemento("span", { texto: "O ícone de cada jogo" }),
      selo("jogo", { texto: String(comAtalho),
        balao: `${comAtalho} ${comAtalho === 1 ? "jogo tem" : "jogos têm"} atalho nesta máquina` }),
      ...gatilhoDeDica("dica-icone-dos-jogos", "Sobre o ícone de cada jogo", [
        elemento("p", { texto: "A capa acima decide se o jogo aparece no lançador; aqui se "
                             + "escolhe o desenho com que ele aparece." }),
      ]),
    ]));
    caixa.append(pulaGrade("apos-apps-jogos", "Pular a lista"));
  caixa.append(gradeDeApps(JOGOS.apps, JOGOS_BUSCA, carregarJogos));
  caixa.append(alvoDoPulo("apos-apps-jogos"));
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
    placeholder: "Por quê? (fica anotado junto com a decisão)",
    "aria-label": "Por que este jogo sai do lançador",
  });
  painel.append(motivo);

  const linha = elemento("div", { class: "linha-botoes" });

  if (j.acao !== "esconder") {
    linha.append(elemento("button", {
      type: "button", class: "btn",
      texto: "Tirar do lançador",
      title: "Some da lista de aplicativos. Pergunta antes de arrumar.",
      onclick: () => confirmarJogo(j, "esconder", motivo.value, false),
    }));
  }

  /* O "apagar" só aparece quando há o que apagar. Numa linha já gasta ele seria
   * um botão que promete uma ação que o script vai recusar — e um botão que não
   * faz nada é pior que um botão a menos. */
  if (!j.gasto && j.no_disco) {
    linha.append(elemento("button", {
      type: "button", class: "btn btn-perigo",
      texto: "Apagar os arquivos",
      title: "Tira do lançador e remove a pasta do jogo e o manifesto, uma vez só.",
      onclick: async () => {
        /* A PERGUNTA É AQUI, e não só no botão que executa. A anotação se
         * desfaz com um clique, mas ela precisa saber, ANTES de escolher, que
         * esta é a opção que leva gigabytes embora. */
        const sim = await perguntar({
          titulo: `Apagar os arquivos de ${j.nome}?`,
          texto: "A pasta do jogo e o manifesto saem do disco agora — com a Steam "
               + "aberta, na próxima passagem. Dispara uma vez só: se você "
               + "reinstalar depois, nada é apagado.",
          ok: "Marcar para apagar", perigo: true,
        });
        if (sim) definirJogo(j.appid, "apagar", motivo.value);
      },
    }));
  }

  if (j.acao || j.gasto) {
    /* A decisão nomeia a CLASSE («as ações de jogos que aplicam todas as marcas
     * pendentes»), e não dois botões: este também grava a linha e roda a
     * passagem inteira, e um «Marcar para apagar» de outro jogo, esperando a
     * Steam fechar, saía no clique daqui sem caixa nenhuma. */
    const rotulo = j.gasto ? "Tirar a linha gasta" : "Voltar ao normal";
    linha.append(elemento("button", {
      type: "button", class: "btn",
      texto: rotulo,
      title: "Tira esta decisão da lista. O cartão volta na próxima passagem.",
      onclick: () => confirmarJogo(j, "", "", true, {
        titulo: j.gasto ? `Tirar a linha gasta de ${j.nome}?` : `Voltar ${j.nome} ao normal?`,
        ok: rotulo,
      }),
    }));
  }

  painel.append(linha);
  /* "O MAPA" e "jogos-fora.map" SAÍRAM DOS QUATRO TEXTOS DESTA OFICINA. */
  painel.append(elemento("p", { class: "frase nota-secao",
    /* "SÓ ANOTA" DEIXOU DE SER VERDADE: cada botão acima grava a decisão e
     * arruma o lançador na mesma hora (ver `definirJogo`). */
    texto: "Cada escolha já arruma o lançador. Arquivo de jogo só sai com a Steam fechada." }));
  return painel;
}

/* --- a galeria de papéis de parede ---------------------------------------- */
/* É O CASO DE USO MAIS VISUAL DO PROJETO, e era o que ela fazia à mão: abrir a
 * pasta no gerenciador de arquivos e apagar o que não gostava (o
 * `meow-ativos.path` percebe o sumiço em ~4 s e grava o nome no BANIDOS.txt).
 *
 * Sem a segunda metade o estado se contradiz — a foto girando no carrossel e o
 * repositório dizendo que ela foi recusada. */
let ABA_GALERIA = "ativos";
/* Três fileiras de seis na largura da tela dela: o bastante para a coleção se
 * mostrar no alto da página sem empurrar os ajustes para longe. */
const PRIMEIRA_LEVA_GALERIA = 18;
let LIMITE_GALERIA = PRIMEIRA_LEVA_GALERIA;

/* «Recusadas 62» ao lado de «No carrossel 29», no mesmo trilho de pílulas,
 * parecia dizer que o carrossel perdeu para alguma coisa. */
const GRUPOS_PAREDE = [
  { id: "ativos", rotulo: "No carrossel", bloco: "carrossel",
    balao: "As imagens que o carrossel gira" },
  { id: "noite", rotulo: "Noite", bloco: "carrossel",
    balao: "Do carrossel, as que entram à noite" },
  { id: "dia", rotulo: "Dia", bloco: "carrossel",
    balao: "Do carrossel, as que entram de dia" },
  { id: "favoritos", rotulo: "Favoritos", bloco: "favoritos",
    balao: "A pasta favoritos" },
  { id: "banidos", rotulo: "Recusadas", bloco: "fora",
    balao: "Fora do carrossel. Nunca são apagadas" },
];

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
  if (imagem.lado) {
    /* Ver o comentário lá. O ACRÉSCIMO SAIU, com o teto de 80 do balão: era
     * ele que levava a frase a 87 caracteres, e era ele que obrigava a
     * reescrita. */
    botoes.push(["wallpaper_lado_auto", "Medir",
      "Tira a escolha e deixa o brilho medido da imagem decidir."]);
  }
  return botoes.map(([id, rotulo, ajuda]) => elemento("button", {
    type: "button", class: "btn btn-mini",
    texto: rotulo,
    title: ajuda,
    onclick: () => rodarNaGaleria(id, alvo),
  }));
}

/* A galeria tinha a aba «Favoritos» e nenhuma imagem oferecia o gesto: o menu
 * era Usar, Dia, Noite, Tirar. */
function estrelaDaImagem(i) {
  if (!i.favorito && !i.banir) return null;
  return elemento("button", {
    type: "button", class: "btn btn-mini estrela",
    "aria-pressed": String(!!i.favorito),
    "aria-label": i.favorito ? "Tirar das favoritas" : "Guardar nas favoritas",
    texto: i.favorito ? "★" : "☆",
    title: i.favorito ? "Tirar das favoritas" : "Guardar nas favoritas",
    onclick: () => i.favorito ? rodarNaGaleria("wallpaper_desfavoritar", i.rotulo)
                              : rodarNaGaleria("wallpaper_favoritar", i.banir),
  });
}

function montarGaleria() {
  const caixa = elemento("div");
  const abas = elemento("div", { class: "abas abas-galeria" });
  const blocos = new Map();
  for (const g of GRUPOS_PAREDE) {
    /* Antes o número só aparecia depois de abrir a sub-aba, então a galeria
     * abria com quatro abas mudas e uma numerada. */
    const cheia = PREVIAS.get("parede/" + ABA_GALERIA);
    const quantos = cheia && cheia.contagens ? cheia.contagens[g.id] : undefined;
    const lista = PREVIAS.get("parede/" + g.id);
    if (!blocos.has(g.bloco)) {
      const b = elemento("div", { class: "abas-bloco", "data-bloco": g.bloco });
      blocos.set(g.bloco, b);
      abas.append(b);
    }
    blocos.get(g.bloco).append(elemento("button", {
      type: "button", "aria-pressed": String(g.id === ABA_GALERIA),
      "data-grupo-parede": g.id, title: g.balao,
      onclick: () => { ABA_GALERIA = g.id; LIMITE_GALERIA = PRIMEIRA_LEVA_GALERIA; render(); },
    }, [
      elemento("span", { texto: g.rotulo }),
      elemento("span", { class: "conta",
        texto: quantos !== undefined ? ` ${quantos}`
             : (lista ? ` ${lista.itens.length}` : "") }),
    ]));
  }
  caixa.append(abas);

  /* A resposta era "não adiciona": a aba mais visual da página, com 46 fotos
   * na tela, era a única onde não havia como pôr uma foto.
   *
   * Quem decide o lado (dia ou noite) é a luminância, e o servidor mede na
   * hora e diz na torrada. */
  abas.append(botaoAcervo("parede", async () => {
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
     * carrossel". O servidor já manda o `banir` de cada item justamente para
     * isto. */
    const estrela = banidos ? null : estrelaDaImagem(i);
    if (estrela) acoes.append(estrela);
    if (banidos) {
      acoes.append(elemento("button", {
        type: "button", class: "btn",
        texto: "Devolver",
        title: `meow wallpaper desbanir ${i.rotulo}`,
        onclick: () => rodarNaGaleria("wallpaper_desbanir", i.rotulo),
      }));
    } else if (i.banir) {
      /* Hoje quem separa `ativos-dia/` de `ativos-noite/` é a LUMINÂNCIA da
       * imagem, medida contra `WALLPAPER_LIMIAR_LUZ`. */
      /* "Usar" é o par do "Próxima imagem" da Início, apontado: fixa AGORA,
       * pelo tempo que «Quanto tempo dura a imagem escolhida» mandar. */
      acoes.append(elemento("button", {
        type: "button", class: "btn btn-mini btn-accent",
        texto: "Usar",
        title: "Passa a valer agora.",
        onclick: () => rodarNaGaleria("wallpaper_usar", i.banir || i.origem),
      }));
      acoes.append(...botoesDeLado(i));
      acoes.append(elemento("button", {
        type: "button", class: "btn btn-perigo",
        texto: "Tirar",
        /* BANE PELO CAMINHO CANÔNICO (`i.banir`), e não pelo que está sendo
         * mostrado: `ativos-noite/` e `ativos-dia/` são LINK DURO do mesmo
         * arquivo, e banir pelo link moveria só o link — meio banimento, e
         * mudo. */
        /* "banidos/" É O NOME DA PASTA NO DISCO. A aba ao lado já se chama
         * "Recusadas" e é para lá que a imagem vai; citar o diretório
         * obrigava a saber que os dois nomes são a mesma coisa. */
        title: "Sai do carrossel e vai para as recusadas. Nunca é apagada.",
        onclick: () => rodarNaGaleria("wallpaper_banir", i.banir || i.origem),
      }));
    }
    fig.append(elemento("figcaption", {}, [
      elemento("span", { class: "nome", texto: i.rotulo }),
      acoes.children.length ? acoes : null,
    ]));
    grade.append(fig);
  }
  caixa.append(pulaGrade("apos-galeria", "Pular a galeria"));
  caixa.append(grade);
  caixa.append(alvoDoPulo("apos-galeria"));

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
 * tela quando o trabalho termina. */
/* Medido pelo `tests/app-completo.py` no «Arrumar os jogos no lançador», que
 * é `destrutivo`: Cancelar mandava `jogos_aplicar` rodar de verdade, e «Ver o
 * que faria» também — sem o `seco`. */
async function rodarDaSecao(acaoId, invalidar) {
  const acao = ESQUEMA.acoes.find((a) => a.id === acaoId);
  if (!acao) return;
  let seco = false;
  if (acao.confirma || acao.sudo || acao.destrutivo) {
    const resposta = await confirmar(acao, "");
    if (resposta === "nao") return;
    seco = resposta === "ensaio";
  }
  const r = await api("/api/rodar", {
    method: "POST",
    body: JSON.stringify({ acao: acaoId, argumento: "", confirmado: true, seco }),
  });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirResultado(r, seco ? () => rodarDeVerdade(acao, "") : null);
  const esperar = setInterval(() => {
    if (TRABALHO) return;
    clearInterval(esperar);
    invalidar();
    render();
  }, 700);
}

async function rodarNaGaleria(acaoId, argumento) {
  const acao = ESQUEMA.acoes.find((a) => a.id === acaoId);
  /* Este `return` calado é a forma como 46 botões "Banir" e 255 "Devolver"
   * ficaram sem chamar nada: o id não existia no `ACOES`, e a página não dizia
   * uma palavra. */
  if (!acao) { torrada(`Ação desconhecida: ${acaoId}`, "erro"); return; }
  const r = await api("/api/rodar", {
    method: "POST",
    body: JSON.stringify({ acao: acaoId, argumento }),
  });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirResultado(r);
  /* A lista muda por baixo: a imagem sai de `ativos/` e entra em `banidos/`.
   * Quem a relê no fim é o `puxar`, como a de todo trabalho que escreve — e
   * as seis ações da galeria escrevem. */
}

/* --- os cartões ----------------------------------------------------------- */
/* `{chave, ate}`, ou null. */
let CARTAO_CHEGADA = null;

function montarCartao(item) {
  const emVigor = valorEmVigor(item);
  const mexeu = emVigor !== item.padrao;
  const naoSalvo = MUDANCAS.has(item.chave);
  const chegou = CARTAO_CHEGADA && CARTAO_CHEGADA.chave === item.chave
                 && Date.now() < CARTAO_CHEGADA.ate;
  const cartao = elemento("article", {
    class: "cartao" + (mexeu ? " mexeu" : "") + (naoSalvo ? " nao-salvo" : "")
           + (chegou ? " chegou" : ""),
    "data-chave": item.chave,
  });

  /* O TÍTULO DO CARTÃO É UMA FRASE, não o identificador. `LOGO_ROTACAO` diz o
   * que a chave se chama; "O gato do painel troca sozinho" diz o que ela FAZ —
   * e é isso que ela precisa ler para escolher. */
  const titulo = tituloDoCartao(item);
  if (titulo) cartao.append(elemento("h3", { class: "titulo-cartao", texto: titulo }));
  const [gatilho, dica] = porqueEDica(item);
  cartao.append(gatilho, dica);
  /* As quatro frases de estado abaixo (desligado, na máquina, vestígio,
   * dominada) eram parágrafos visíveis com uma borda amarela, e no print 13 do
   * uso real «Quem manda é…» aparecia em três cartões seguidos. */
  const selos = elemento("div", { class: "selos" });
  const estado = [];

  /* A regra é derivada e mora no servidor (`dominada_por`), não aqui: quem sabe
   * qual chave vence qual é quem lê o conf. */
  if (item.chave === "FLAVOR" || item.chave === "ACCENT") {
    const aviso = avisoDeCombinacao();
    if (aviso) { selos.append(aviso.selo); estado.push(aviso.frase); }
  }
  if (item.chave === "FLAVOR") {
    const lado = avisoDeLado();
    if (lado) { selos.append(lado.selo); estado.push(lado.frase); }
  }
  /* O QUE ESTÁ VALENDO, quando não é o arquivo que manda. O cartão mostrava
   * 3500 (o padrão de fábrica) com a máquina em 4700 — o número do applet.
   *
   * Era só o modo de leitura. */
  const agora = item.valendo_agora;
  const escolhido = valorEmVigor(item);
  /* De dia a máquina guarda 0 na temperatura do modo de leitura, e o cartão
   * dizia «Na máquina agora: 0» — que não é temperatura nenhuma. */
  if (item.desligado_agora && escolhido !== "") {
    selos.append(selo("maquina", { texto: "desligado", balao: "Na máquina agora: desligado" }));
    estado.push(elemento("p", { class: "frase" }, [
      elemento("b", { texto: "Na máquina agora: desligado. " }),
      elemento("span", { texto: item.chave === "LEITURA_TEXTURA"
        ? "O modo de leitura não está pondo a textura de papel na tela neste momento."
        : "O modo de leitura não está esquentando a tela neste momento." }),
    ]));
  }
  if (agora != null && escolhido !== "" && !mesmoValor(agora, escolhido)) {
    selos.append(selo("maquina", { texto: encurtarValor(rotuloDeValor(agora)),
                                   balao: `Na máquina agora: ${rotuloDeValor(agora)}` }));
    estado.push(elemento("p", { class: "frase dominada" }, [
      elemento("b", { texto: `Na máquina agora: ${rotuloDeValor(agora)}. ` }),
      elemento("span", {
        texto: item.chave.startsWith("LEITURA_")
          ? "O controle do painel guarda o valor de agora. Salvar e aplicar grava a escolha nele também."
          : "Salvar e aplicar faz este ajuste valer.",
      }),
    ]));
  }
  /* Mesma régua do `dominada_por` logo abaixo: a regra é derivada e mora no
   * servidor, a página só desenha. */
  if (item.vestigio_de_pack) {
    const v = item.vestigio_de_pack;
    selos.append(selo("pack", { texto: `«${encurtarValor(v.pack)}»`, balao: `Vem do pack «${v.pack}»` }));
    estado.push(elemento("p", { class: "frase dominada" }, [
      elemento("b", { texto: `Vestígio do pack «${v.pack}». ` }),
      elemento("span", { texto: v.porque || "" }),
    ]));
  }
  /* O servidor já apaga a distância quando a barra está colada
   * (`dominada_por`); o caso inverso não é anulação, é contradição:
   * «descolada» marcado e a distância que vale (a escolhida, ou a da máquina
   * quando a chave está vazia) em 0. */
  const barraSolta = /^FORMA_MARGEM_(PAINEL|DOCK)$/.exec(item.chave);
  if (barraSolta && !item.dominada_por) {
    const solto = ESQUEMA.chaves.find((k) => k.chave === `FORMA_${barraSolta[1]}_SOLTO`);
    const vale = escolhido !== "" ? escolhido : agora;
    if (solto && valorEmVigor(solto) === "sim" && vale != null && vale !== ""
        && Number(vale) === 0) {
      const [quem, o] = barraSolta[1] === "DOCK" ? ["A dock", "a"] : ["O painel", "o"];
      selos.append(selo("anulado", { texto: "0 px", balao: `${quem} descolad${o} com 0 px fica encostad${o}` }));
      estado.push(elemento("p", { class: "frase dominada" }, [
        elemento("b", { texto: `${quem} está descolad${o}, mas a distância é 0 px. ` }),
        elemento("span", { texto: "Com zero a barra continua encostada na borda: arraste a distância para ela se soltar." }),
      ]));
    }
  }
  /* Com «AREAS_NOMES» vazio o `areas.sh` se pula, e os dois cartões por área
   * não têm o que ligar: nascem travados, com o ⊘ e o porquê na dica, como
   * as outras travas. */
  if (item.previa === "areas" || item.chave === "AREAS_ENCAIXE") {
    const nomesItem = ESQUEMA.chaves.find((k) => k.chave === "AREAS_NOMES");
    if (nomesItem && !String(valorEmVigor(nomesItem)).split(",").some((x) => x.trim())) {
      const dono = nomeVisivel("AREAS_NOMES");
      cartao.classList.add("anulado");
      selos.append(selo("anulado", { balao: "Nenhuma área com nome" }));
      estado.push(elemento("p", { class: "frase dominada" }, [
        elemento("b", { texto: "Nenhuma área com nome. " }),
        elemento("span", { texto: `Vale por área: dê nome às áreas em «${dono}».` }),
      ]));
    }
  }
  /* O cartão que o modo mostra só existe com o modo que o usa; o
   * `dominada_por` do servidor fala do modo GRAVADO, e com outro modo
   * esperando «Salvar» ele apagava o cartão que o modo novo acabou de trazer
   * à tela. */
  const anulacaoVelha = item.dominada_por && DECISOES.some((dec) => dec.modo
    && dec.modo.chave === item.dominada_por.chave
    && Object.values(dec.modo.por).some((l) => l.includes(item.chave)));
  if (item.dominada_por && !anulacaoVelha) {
    const d = item.dominada_por;
    /* ANULADO SE VÊ NO CONTROLE: ele fica apagado (`.anulado`, no CSS) e o
     * selo ⊘ diz quem manda. Continua clicável — a escolha vale no arquivo e
     * passa a valer na tela quando a outra chave deixar de mandar. */
    cartao.classList.add("anulado");
    selos.append(selo("anulado", { balao: `Quem manda: «${d.titulo || d.chave}»` }));
    estado.push(elemento("p", { class: "frase dominada" }, [
      /* CITA O CARTÃO, NÃO A VARIÁVEL. "LOGO_MODO=\"hora\" está mandando" manda
       * procurar um nome que a tela não usa em lugar nenhum; o rótulo do cartão
       * dominante é o mesmo texto que ela acabou de ler no menu. */
      elemento("b", { texto: `Quem manda é «${d.titulo || d.chave}», em ${rotuloDeValor(d.valor)}. ` }),
      elemento("span", { texto: d.porque || "" }),
    ]));
  }
  if (selos.childElementCount) cartao.append(selos);
  if (estado.length) dica.prepend(...estado);
  cartao.append(montarControle(item, cartao));

  /* O CARTÃO PENDENTE MOSTRA O QUE FAZER COM A PENDÊNCIA. A borda de accent já
   * dizia "esperando"; faltava dizer esperando O QUÊ. Ver o bloco do
   * `aplicarCartao`. */
  if (naoSalvo) {
    const aplicar = elemento("button", {
      /* `btn-aplicar` não é estilo: é o gancho pelo qual o
       * `tests/app-navegador.py` conta os botões, já que o lugar deles no
       * cartão depende do controle. */
      type: "button", class: "btn btn-mini btn-accent btn-aplicar",
      texto: "Aplicar",
      title: "Grava esta escolha e aplica. As outras continuam esperando.",
    });
    aplicar.addEventListener("click", () => aplicarCartao(item, aplicar));
    /* AO LADO DO «RESTAURAR AO PADRÃO», E NÃO NUMA LINHA ABAIXO. */
    const fileira = cartao.querySelector(".faixa-estados");
    if (fileira) fileira.append(aplicar);
    else cartao.append(elemento("div", { class: "acao-cartao" }, [aplicar]));
  }

  /* A frase curta sob o controle era a explicação do ajuste em uma a três
   * linhas, repetida em cada cartão da grade; ela entra no `?`, logo depois das
   * frases de estado e antes do comentário inteiro do arquivo. */
  if (item.frase) {
    const achatar = (t) => String(t || "").replace(/^# ?/gm, "").replace(/\s+/g, " ").trim();
    const motivo = dica.querySelector(".motivo");
    if (!motivo || !achatar(motivo.textContent).includes(achatar(item.frase))) {
      const resumo = elemento("p", { class: "resumo" + (item.ajuda_herdada ? " herdada" : ""),
                                     texto: item.frase });
      const antes = dica.querySelector(".de-quem, .motivo, .chave");
      dica.insertBefore(resumo, antes);
    }
  }

  /* O valor EFETIVO só aparece quando difere do cru — é o caso das chaves que
   * usam `$HOME` ou `${FLAVOR}`, onde o que está escrito e o que vale são
   * textos diferentes, e esconder um dos dois confunde. */
  /* O MOLDE DAS PASTAS NÃO GANHA O «Vale como» — ele dizia `cat-dracula-mauve`,
   * um nome que o papirus-folders não tem. Os dois seletores e a nota deles
   * dizem o que as pastas vestem, em português (ver `controlePastas`). */
  /* O «Vale como» TAMBÉM É DICA: é a resposta a «o que `$HOME/…` quer
   * dizer?», que só quem abre o `?` está perguntando. */
  if (item.efetivo && item.efetivo !== (item.valor ?? "")
      && !(item.molde_pastas && partirMoldeDasPastas(valorEmVigor(item)))) {
    dica.append(elemento("p", {
      class: "vale-como",
      /* Os dois usam agora o mesmo `item.rotulos`. */
      texto: `Vale como: ${(item.rotulos && item.rotulos[item.efetivo])
                           || semCasa(item.valor, item.efetivo)}`,
    }));
  }

  /* A prévia que acompanha o controle em vez de substituí-lo: o degrau do modo
   * de leitura e a geometria das barras continuam sendo número, e o que a
   * imagem faz é dizer o que aquele número PARECE. */
  if (item.previa === "barra") {
    /* A BARRA NÃO SE REPETE POR CARTÃO — visto na primeira captura da seção:
     * seis desenhos idênticos da mesma barra, um por chave, empurrando o
     * controle para baixo e dizendo a mesma frase seis vezes. */
  } else if (!item.previa && GRUPOS_VISUAIS.has(item.subsecao || item.secao)) {
    /* NEM TODA CHAVE VISUAL TEM PRÉVIA HONESTA, e onde não tem a página DIZ —
     * mas UMA VEZ POR SEÇÃO, não uma vez por cartão.
     *
     * Numa seção de catorze chaves, a mesma linha aparecia catorze vezes:
     * metade do texto da tela era um aviso repetido, e ele empurrava a
     * explicação de verdade para fora do corte. */
    cartao.dataset.semPrevia = "1";
  }

  /* O comentário inteiro do `meow.conf.exemplo` não se perdeu: ele é o
   * `.motivo` dentro da `.dica`, que o `?` ao lado do título abre (ver
   * `porqueEDica`, acima). */
  const buscaViva = semAcento($("#busca").value.trim());
  if (buscaViva) {
    const motivo = ondeCasa(item, buscaViva);
    if (motivo) cartao.append(elemento("p", { class: "casa-por", texto: motivo }));
  }
  return cartao;
}

/* O `?` E A DICA — a outra metade da folha de estilo
 *
 * O CARTÃO PASSOU DE SEIS CAMADAS PARA TRÊS: título, controle, explicação.
 *
 * A folha de estilo já abre o balão no `:hover` do gatilho e no
 * `:focus-visible` dele, com `!important`, porque o atributo `hidden` traz um
 * `display: none !important` da folha do navegador.
 *
 * Um clique de rato dá foco ANTES de disparar o `click`. */
function porqueEDica(item) {
  /* O id sai da CHAVE, e não de um contador. */
  const idDica = "dica-" + item.chave;
  const filhos = [];
  if (item.ajuda) {
    /* Trinta chaves herdam o comentário da irmã de cima (o `ajuda_herdada` do
     * servidor), e até aqui só a FRASE do cartão dizia isso, por um traço à
     * esquerda. */
    /* Mesma troca de vocabulário do `title` herdado, e pela mesma razão —
     * ver o comentário lá. As duas frases são a mesma afirmação em dois
     * tamanhos, então elas têm de usar as mesmas palavras. */
    const dona = tituloDaDona(item);
    if (dona) {
      filhos.push(elemento("p", {
        class: "de-quem",
        texto: `De «${dona}», que explica este ajuste e os vizinhos de uma vez.`,
      }));
    }
    /* O `# ` que abre cada linha de comentário é sintaxe do arquivo, não texto.
     * O `.trim()` tira a linha em branco que quase todo bloco deixa no fim. */
    filhos.push(elemento("p", { class: "motivo", texto: item.ajuda.replace(/^# ?/gm, "")
      .replace(/\[(?:avancado|so-com-app [^\]]*)\] ?/g, "").trim() }));
  }
  filhos.push(elemento("code", { class: "chave", texto: item.chave }));
  if (item.essencial) {
    filhos.push(elemento("span", { class: "marca-essencial", title: "Ajuste essencial", texto: "•" }));
  }
  filhos.push(elemento("span", {
    class: "fabrica",
    texto: item.padrao === "" ? "De fábrica: nada" : `De fábrica: ${rotuloDeValor(item.padrao)}`,
    title: "O valor que o projeto traz de fábrica.",
  }));

  return gatilhoDeDica(idDica, `O que é ${tituloDoCartao(item) || item.chave}`, filhos);
}

/* O `?` do cartão de ajuste já era essa dica, com o comportamento inteiro
 * medido (espia no hover, fixa no clique, Esc fecha, abre no foco do teclado —
 * ver o bloco de cima).
 *
 * O CONTRATO COM O CSS É O MESMO DO CARTÃO: a `.dica` é o irmão IMEDIATO do
 * `button.porque` (o hover é `button.porque:hover + .dica`), e quem chama
 * acrescenta os dois, nessa ordem, no mesmo pai. */
function gatilhoDeDica(idDica, rotulo, filhos) {
  const gatilho = elemento("button", {
    type: "button", class: "porque", texto: "?",
    "aria-expanded": "false", "aria-controls": idDica,
    "aria-label": rotulo,
  });
  /* `tabindex="-1"` tira o balão da fila do Tab. */
  const dica = elemento("div", { class: "dica", id: idDica, role: "tooltip", tabindex: "-1", hidden: true },
                       filhos);

  const mostrar = (aberta) => {
    dica.hidden = !aberta;
    gatilho.setAttribute("aria-expanded", String(aberta));
  };
  gatilho.addEventListener("click", () => {
    const abrir = dica.hidden;
    mostrar(abrir);
    /* O clique que FECHA suspende o espiar do CSS enquanto o ponteiro não sair
     * daqui — senão o `:hover` do gatilho reabriria o balão no mesmo gesto e o
     * `?` pareceria não responder. */
    if (abrir) gatilho.removeAttribute("data-fechei");
    else gatilho.setAttribute("data-fechei", "");
  });
  gatilho.addEventListener("mouseleave", () => gatilho.removeAttribute("data-fechei"));
  gatilho.addEventListener("focus", () => {
    /* `matches` pode não conhecer `:focus-visible` num navegador antigo, e uma
     * exceção aqui apagaria o cartão inteiro. Sem ele, o teclado continua tendo
     * o clique (Enter e Espaço disparam `click` num `<button>`). */
    try { if (gatilho.matches(":focus-visible")) mostrar(true); } catch (e) { /* idem */ }
  });
  gatilho.addEventListener("blur", () => {
    mostrar(false);
    gatilho.removeAttribute("data-fechei");
  });
  gatilho.addEventListener("keydown", (ev) => {
    if (ev.key !== "Escape") return;
    /* Para quem chegou de TECLADO, o balão está na tela por CSS
     * (`:focus-visible`) com o atributo `hidden` ainda posto: o teste
     * `dica.hidden` dizia "não há nada aberto" e o Esc saía cedo, sem fechar o
     * que o olho via. */
    const desenhada = getComputedStyle(dica).display !== "none";
    if (!desenhada) return;
    /* O `stopPropagation` impede que o mesmo Esc que fecha a dica atravesse até
     * o atalho global e limpe a busca — dois desfazeres num toque só. */
    ev.stopPropagation();
    mostrar(false);
    gatilho.setAttribute("data-fechei", "");
  });
  return [gatilho, dica];
}

/* O estado de um cartão era dito em frase — «PEDE SENHA», «Na máquina agora:
 * 6300. Quem guarda esse valor é…», «Quem manda é «X», em Hora.
 *
 * NÃO É FOCÁVEL, de propósito: um selo não faz nada, e uma parada de Tab que
 * não faz nada é ruído para quem anda de teclado. */
const SELO_ICONES = {
  sudo: '<rect x="3.5" y="7" width="9" height="6.5" rx="1.5"/><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2"/>',
  /* O desenho que não vale aqui: o mesmo cadeado do sudo, com outro nome,
   * porque o porquê é outro. */
  trava: '<rect x="3.5" y="7" width="9" height="6.5" rx="1.5"/><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2"/>',
  ponte: '<rect x="3.5" y="7" width="9" height="6.5" rx="1.5"/><path d="M5.5 7V5a2.5 2.5 0 0 1 4.9-.7"/>',
  rede: '<path d="M8 2.5v7.5M4.8 7 8 10.2 11.2 7M3 13.5h10"/>',
  desfaz: '<path d="M5.5 4 2.5 7l3 3"/><path d="M2.5 7h7a3.5 3.5 0 0 1 0 7H7"/>',
  maquina: '<rect x="2" y="3" width="12" height="8" rx="1.2"/><path d="M6 13.5h4M8 11v2.5"/>',
  anulado: '<circle cx="8" cy="8" r="5.5"/><path d="m4.1 11.9 7.8-7.8"/>',
  pack: '<path d="M2.5 5 8 2.5 13.5 5v6L8 13.5 2.5 11z"/><path d="M2.5 5 8 7.5 13.5 5M8 7.5v6"/>',
  mexeu: '<circle cx="8" cy="8" r="3.5" fill="currentColor" stroke="none"/>',
  pendente: '<circle cx="8" cy="8" r="3.5"/>',
  gente: '<circle cx="8" cy="5.2" r="2.4"/><path d="M3.2 13.5a4.8 4.8 0 0 1 9.6 0"/>',
  proprio: '<path d="m3.5 8.5 3 3 6-7"/>',
  herdado: '<path d="M4 2.5v5a3 3 0 0 0 3 3h6"/><path d="m10 7.5 3 3-3 3"/>',
  motor: '<circle cx="8" cy="8" r="2.2"/><path d="M8 2v2M8 12v2M2 8h2M12 8h2M3.8 3.8l1.4 1.4M10.8 10.8l1.4 1.4M3.8 12.2l1.4-1.4M10.8 5.2l1.4-1.4"/>',
  icones: '<rect x="2.5" y="2.5" width="4.5" height="4.5" rx="1"/><rect x="9" y="2.5" width="4.5" height="4.5" rx="1"/><rect x="2.5" y="9" width="4.5" height="4.5" rx="1"/><rect x="9" y="9" width="4.5" height="4.5" rx="1"/>',
  ponteiro: '<path d="M4.5 2.5v10l2.6-2.4 1.8 3.9 1.6-.8-1.8-3.8h3.6z"/>',
  relogio: '<circle cx="8" cy="8" r="5.5"/><path d="M8 5v3l2 1.5"/>',
  gira: '<path d="M13 8a5 5 0 1 1-1.5-3.5"/><path d="M13 2.5v3h-3"/>',
  foto: '<rect x="2" y="3" width="12" height="10" rx="1.5"/><path d="m2.5 11 3.5-3.5 3 3 2-2 2.5 2.5"/>',
  lua: '<path d="M12.5 10.5a5.5 5.5 0 0 1-7-7 5.5 5.5 0 1 0 7 7z"/>',
  terminal: '<rect x="2" y="3" width="12" height="10" rx="1.5"/><path d="m4.5 6.5 2 1.5-2 1.5M8 10h3"/>',
  calor: '<path d="M8 2.5v6.6"/><circle cx="8" cy="11.3" r="2.2"/><path d="M10 4h1.5M10 6.5h1.5"/>',
  textura: '<path d="M3 4.5h1.5M7 4.5h1.5M11 4.5h2M3 8h2M7.5 8h1.5M11.5 8h1.5M3 11.5h1.5M6.5 11.5h2M11 11.5h2"/>',
  rampa: '<path d="M2.5 12.5h3l5-9h3"/>',
  jogo: '<rect x="1.5" y="5" width="13" height="7" rx="3.5"/><path d="M4.5 8.5h2.5M5.75 7.25v2.5M10.5 7.8h.01M12 9.3h.01"/>',
};
/* A classe antiga de cada tipo, para os ganchos do CSS — ver acima. */
const SELO_LEGADO = { sudo: "p-sudo", ponte: "p-ok", rede: "p-rede", desfaz: "p-perigo" };

/* Um texto montado com dado de fora (o título de outro cartão, o nome de um
 * pack) cortado ANTES do balão, numa fronteira de palavra. */
function caberNoBalao(txt) {
  const t = String(txt || "").trim();
  if (t.length <= BALAO_LIMITE) return t;
  const corte = t.lastIndexOf(" ", BALAO_LIMITE - 2);
  return t.slice(0, corte > 40 ? corte : BALAO_LIMITE - 2).trimEnd() + "…";
}

/* O valor curto que vai ao lado do ícone do selo: o selo é um sinal, e um
 * caminho inteiro ao lado dele o transformaria de volta em frase. O valor
 * inteiro continua no balão. */
function encurtarValor(txt) {
  const t = String(txt == null ? "" : txt).trim();
  return t.length > 18 ? t.slice(0, 17).trimEnd() + "…" : t;
}

/* `img` troca o ícone de traço por uma imagem real (o gato do dock, na
 * Início): quando há o que mostrar, o desenho genérico perde para o real — a
 * regra 2 da direção. */
function selo(tipo, { texto = "", balao = "", img = "" } = {}) {
  const nome = caberNoBalao(balao);
  const el = elemento("span", {
    class: `selo selo-${tipo}` + (SELO_LEGADO[tipo] ? ` ${SELO_LEGADO[tipo]}` : ""),
    role: "img",
    "aria-label": nome || texto,
    "data-selo": tipo,
  });
  if (img) el.append(elemento("img", { class: "selo-img", src: img, alt: "" }));
  else el.insertAdjacentHTML("afterbegin", '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">'
    + (SELO_ICONES[tipo] || SELO_ICONES.mexeu) + "</svg>");
  if (texto) el.append(elemento("span", { class: "selo-valor", texto: String(texto) }));
  /* O balão passa pela porta de sempre (`porBalao`), que sabe não repetir o que
   * já está escrito e sabe tirar comando de dentro dele. */
  if (nome) porBalao(el, nome);
  return el;
}

/* Cada desenho da página abria com «Desenho, não é a sua tela: …» e duas a
 * quatro linhas de números embaixo dele.
 *
 * O AVISO SAI NA ORIGEM DA DICA, e não nos `previas-*.js`: são dezesseis
 * legendas em dois arquivos, e reescrevê-las agora seria mexer em todas as
 * páginas de uma vez. */
function semAvisoDeDesenho(txt) {
  const resto = String(txt || "").replace(/^\s*desenho,\s*não é a sua tela\s*[:—–-]\s*/i, "").trim();
  return resto ? maiuscula(resto) : "";
}

/* O `?` de um desenho. `id` é o nome estável do desenho (o grupo, a barra);
 * devolve `null` quando a legenda não tem nada além do aviso. Quem chama põe
 * a classe `com-dica` no recipiente, que é a âncora do balão. */
function dicaDoDesenho(id, texto) {
  const legenda = semAvisoDeDesenho(texto);
  if (!legenda) return null;
  return gatilhoDeDica("dica-desenho-" + idDeAba(id), "O que o desenho mostra",
                       [elemento("p", { class: "legenda-desenho", texto: legenda })]);
}

/* A caixa da direita é sempre um `div` (o «Como fica», ou o desenho único); a
 * da esquerda pode ser o `button.lado-previa`, e botão dentro de botão não
 * existe. */
function ancorarDicaDoDesenho(par, dica) {
  const caixa = par.lastElementChild;
  if (!caixa) return;
  caixa.classList.add("com-dica");
  caixa.append(...dica);
}

/* Só depois da pintura se sabe até onde o traço vai (`getBBox` em unidades do
 * desenho, levadas à tela pela matriz dele), e então o `?` anda o que falta.
 * Em tela estreita o CSS o põe dentro da caixa, e lá ele fica. */
function afastarDicasDoTraco() {
  if (matchMedia("(max-width: 620px)").matches) return;
  for (const b of document.querySelectorAll("#conteudo .par-previa > .com-dica > button.porque")) {
    const svg = b.parentElement.querySelector("svg");
    if (!svg || !svg.getBBox || !svg.getScreenCTM) continue;
    let fim;
    try {
      const caixa = svg.getBBox();
      const m = svg.getScreenCTM();
      if (!m) continue;
      fim = m.a * (caixa.x + caixa.width) + m.e;
    } catch (e) { continue; }
    const sobra = fim + 6 - b.getBoundingClientRect().left;
    if (sobra > 0) b.style.right = `calc(-2rem - ${Math.ceil(sobra)}px)`;
  }
}

/* Cada página abria com o título, um subtítulo e, em duas delas, um parágrafo
 * de nota (Logo do sistema) ou de acervo (Ícones, Terminal) antes do primeiro
 * controle.
 *
 *   título  (?)                                  ● 3  ○ 1   [Adicionar …]
 *
 * Na BUSCA o cabeçalho é só o título, como era: o resultado da busca mistura
 * páginas, e resumo de uma página no meio dele confundiria de quem é o número. */
function cabecalhoDePagina(assunto, busca) {
  const linha = elemento("div", { class: "cabecalho-linha com-dica" }, [
    elemento("h2", { class: "secao-titulo", title: assunto, texto: encurtar(assunto) }),
  ]);
  const cab = elemento("header", { class: "cabecalho-pagina" }, [linha]);
  if (busca) return cab;

  const explica = [];
  const frase = descricaoDe(assunto);
  if (frase) explica.push(elemento("p", { class: "resumo", texto: frase }));
  const nota = NOTA_DO_ASSUNTO[assunto];
  if (nota && nota.fecho) explica.push(elemento("p", { class: "motivo", texto: nota.fecho }));
  const acervo = ACERVO_DO_ASSUNTO[assunto];
  if (acervo && acervo.nota) explica.push(elemento("p", { class: "motivo", texto: acervo.nota }));
  if (explica.length) linha.append(...gatilhoDeDica("dica-pagina-" + idDeAba(assunto),
                                                    `Sobre ${assunto}`, explica));

  /* O RESUMO SAI DO MESMO LUGAR QUE A ARESTA DO CARTÃO: `valorEmVigor` contra o
   * `padrao` (o «mexeu») e a bandeja `MUDANCAS` (o «não salvo»). */
  let mexeu = 0, esperando = 0;
  for (const g of GRUPOS) {
    if (g.tipo !== "chaves" || assuntoDe(g) !== assunto) continue;
    for (const item of g.itens || []) {
      if (valorEmVigor(item) !== item.padrao) mexeu++;
      if (MUDANCAS.has(item.chave)) esperando++;
    }
  }
  const resumo = elemento("div", { class: "selos cabecalho-selos" });
  if (mexeu) resumo.append(selo("mexeu", { texto: mexeu,
    balao: mexeu === 1 ? "1 ajuste diferente de fábrica" : `${mexeu} ajustes diferentes de fábrica` }));
  if (esperando) resumo.append(selo("pendente", { texto: esperando,
    balao: esperando === 1 ? "1 escolha esperando «Salvar e aplicar»"
                           : `${esperando} escolhas esperando «Salvar e aplicar»` }));
  if (resumo.childElementCount) linha.append(resumo);
  const botao = acervoDoAssunto(assunto);
  if (botao) linha.append(elemento("div", { class: "cabecalho-acoes" }, [botao]));
  return cab;
}

/* --- as ações ------------------------------------------------------------- */
/* O servidor manda o motivo em DADO, e a frase nasce aqui por uma razão só:
 * os nomes que ela cita têm de ser os que a pessoa vê. */
function fraseIndisponivel(motivo) {
  if (motivo.antes) {
    const antes = (ESQUEMA.acoes || []).find((a) => a.id === motivo.antes);
    return `Antes, «${antes ? antes.rotulo : motivo.antes}»: ${motivo.porque}.`;
  }
  if (motivo.feito) {
    const depois = (ESQUEMA.acoes || []).find((a) => a.id === motivo.feito);
    return `Já feito: ${motivo.porque}. O passo seguinte é «${depois ? depois.rotulo : motivo.feito}».`;
  }
  /* SÓ O PORQUÊ, SEM PASSO SEGUINTE: «Instalar o starship» com ele já
   * instalado. */
  if (motivo.porque && !motivo.chave) return `Já feito: ${motivo.porque}.`;
  return `Sem efeito com «${nomeVisivel(motivo.chave)}» em `
    + `«${rotuloDeValor(motivo.vale)}». Mude para «${rotuloDeValor(motivo.pede)}» `
    + "para usar este botão.";
}

function montarAcao(acao) {
  const bloco = elemento("article", { class: "acao" });
  /* Eram quatro: título, ajuda, comando cru e rodapé. */
  const explica = [];
  if (acao.ajuda) explica.push(elemento("p", { class: "resumo", texto: acao.ajuda }));
  const topo = elemento("div", { class: "acao-topo com-dica" }, [elemento("h3", { texto: acao.rotulo })]);
  bloco.append(topo);

  let escolha = null;
  if (acao.opcoes && acao.opcoes.length) {
    const sel = elemento("select", { "aria-label": `Valor para ${acao.rotulo}` });
    for (const o of acao.opcoes) {
      sel.append(elemento("option", { value: o, texto: rotuloDeValor(o) }));
    }
    /* O SELETOR NASCE NO ESTADO DA MÁQUINA, e não no primeiro item da lista.
     * A ligação entre a ação e a chave é DERIVADA: se a lista de opções da
     * ação for igual à de alguma chave do conf, aquela chave é o estado
     * dela. */
    /* COMPARA COMO CONJUNTO, não como sequência: a ação lista `claro,
     * escuro, auto` e a chave `MODO` lista `escuro, claro, auto` — o mesmo
     * conjunto em outra ordem. */
    const mesmoConjunto = (a, b) =>
      a && b && a.length === b.length && a.every((o) => b.includes(o));
    const chaveDoEstado = (ESQUEMA.chaves || []).find(
      (k) => mesmoConjunto(k.opcoes, acao.opcoes));
    if (chaveDoEstado) {
      const atual = valorEmVigor(chaveDoEstado);
      if (atual && acao.opcoes.includes(atual)) sel.value = atual;
      porBalao(sel, `Agora: ${rotuloDeValor(atual)} (${chaveDoEstado.chave})`);
    }
    bloco.append(sel);
    escolha = sel;
  }

  const rodape = elemento("div", { class: "rodape" });
  if (acao.sudo) rodape.append(selo("sudo", { balao: "Pede a senha do sudo" }));
  /* Só que a ausência não se lê. */
  else if (acao.pela_ponte) rodape.append(selo("ponte", {
    balao: "Sem senha: o perfil do sudo está registrado" }));
  if (acao.destrutivo) rodape.append(selo("desfaz", { balao: "Desfaz o que foi feito" }));
  /* `rede` é DECLARADA pela ação, nunca adivinhada do texto dela. Um marcador
   * que lê a prosa acaba dizendo o contrário dela; quem sabe se a ação toca a
   * rede é quem a escreveu. */
  if (acao.rede) rodape.append(selo("rede", { balao: "Baixa da internet" }));
  /* global (*"eu tinha pedido pra tirar o app do modo sandbox"*): `Executar`
   * As pastilhas que ficam são as que de fato distinguem uma ação da vizinha —
   * pede senha, desfaz o que foi feito, baixa da internet. */

  const executar = elemento("button", {
    type: "button",
    class: "btn " + (acao.destrutivo ? "btn-perigo" : "btn-accent"),
    texto: "Executar",
    onclick: () => rodar(acao, escolha ? escolha.value : ""),
  });
  rodape.append(executar);
  /* O Restaurar desfaz a ÚLTIMA execução desta ação, e só existe quando há o
   * que desfazer: a ação que só lê nunca o mostra. */
  if (acao.escreve && RESTAUROS.has(acao.id)) {
    rodape.append(elemento("button", {
      type: "button", class: "btn restaurar",
      texto: "Restaurar",
      onclick: () => restaurarAcao(acao.id),
    }));
  }
  /* Uma ação que recebe argumento (`arg`, o `@ARG@` do comando) e cuja lista
   * veio vazia não tinha seletor, e o «Executar» mandava o argumento vazio: o
   * servidor recusava com 409 ("argumento fora da lista do disco") depois de a
   * caixa já ter perguntado e oferecido o ensaio. */
  if (acao.arg && !escolha) {
    executar.disabled = true;
    rodape.insertBefore(selo("anulado", { balao: "Nada para escolher nesta máquina agora" }), executar);
    explica.unshift(elemento("p", { class: "frase",
      texto: "Nada para escolher nesta máquina agora: a lista desta ação está vazia." }));
  }
  /* A mesma regra do bloco de cima, para a ação que tem o que escolher e não
   * teria efeito nenhum: «Pôr um gato no dock» com o gato por horário e
   * «Gravar as áreas» sem área fixada. */
  if (acao.indisponivel) {
    executar.disabled = true;
    rodape.insertBefore(selo("anulado", { balao: "Sem efeito agora" }), executar);
    explica.unshift(elemento("p", { class: "frase indisponivel",
      texto: fraseIndisponivel(acao.indisponivel) }));
  }
  if (explica.length) topo.append(...gatilhoDeDica("dica-acao-" + idDeAba(acao.id || acao.rotulo),
                                                   `O que faz ${acao.rotulo}`, explica));
  bloco.append(rodape);
  return bloco;
}

async function rodar(acao, argumento) {
  const perguntou = !!(acao.confirma || acao.sudo || acao.destrutivo);
  let seco = false;
  if (perguntou) {
    const resposta = await confirmar(acao, argumento);
    if (resposta === "nao") return;
    seco = resposta === "ensaio";
  }
  /* A RESPOSTA VIAJA NA PRIMEIRA IDA */
  let r = await api("/api/rodar", {
    method: "POST",
    body: JSON.stringify({ acao: acao.id, argumento, confirmado: perguntou, seco }),
  });
  /* Ele devolve 409 com `precisa_confirmar: true` e os fatos da ação (o que
   * escreve, se usa sudo) em vez de rodar. */
  if (r && r.precisa_confirmar) {
    const resposta = await confirmar(acao, argumento);
    if (resposta === "nao") return;
    seco = resposta === "ensaio";
    r = await api("/api/rodar", {
      method: "POST",
      body: JSON.stringify({ acao: acao.id, argumento, confirmado: true, seco }),
    });
  }
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirResultado(r, seco ? () => rodarDeVerdade(acao, argumento) : null);
}

/* Reabri-la aqui seria pedir a mesma autorização duas vezes — o defeito que o
 * comentário do `rodar()` acima narra, voltando por outra porta. */
async function rodarDeVerdade(acao, argumento) {
  const r = await api("/api/rodar", {
    method: "POST",
    body: JSON.stringify({ acao: acao.id, argumento, confirmado: true, seco: false }),
  });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirResultado(r);
}

/* A seção "Jogos da Steam" precisava perguntar antes de marcar um jogo para
 * apagar, e a saída rápida seria `window.confirm`. */
/* Ele é criado UMA vez e reaproveitado: o `<dialog>` é um só na página, e
 * recriá-lo a cada pergunta trocaria o elemento debaixo do foco do teclado.
 *
 * `value="seco"` é o que faz o `returnValue` dizer qual botão foi apertado — é
 * o mecanismo nativo do `<form method="dialog">`, o mesmo do "sim"/"nao" que
 * já existia, e não um estado paralelo em variável. */
function botaoDeEnsaio() {
  let b = document.getElementById("confirmar-ensaio");
  if (!b) {
    b = elemento("button", {
      value: "seco", class: "btn btn-ensaio", id: "confirmar-ensaio",
      texto: "Ver sem mudar",
      title: "Roda em ensaio (MEOW_DRY_RUN=1): mostra tudo e não escreve nada",
    });
    /* ANTES do gatilho, e não depois: a ordem de leitura da caixa termina no
     * botão que age, do mesmo jeito que a do rodapé dos cartões de ação (ver o
     * `estilo.css`). */
    $("#confirmar-ok").before(b);
  }
  return b;
}

/* Uma paleta escrita como 26 códigos não é paleta desenhada. Sem `corpo`, o
 * lugar fica vazio e escondido — as outras perguntas da página não mudam em
 * nada. */
function lugarDoCorpo() {
  let lugar = document.getElementById("confirmar-corpo");
  if (!lugar) {
    lugar = elemento("div", {
      id: "confirmar-corpo",
      style: "display:flex;flex-direction:column;gap:.55rem;margin:.6rem 0 0",
    });
    $("#confirmar-texto").after(lugar);
  }
  return lugar;
}

/* `ensaio: true` acende o botão «Ver sem mudar» */
/* «Sem texto na interface, máximo vira dica»: o que vai ser feito com root fica
 * na linha, e o porquê (nada aqui pede senha; a máquina a lembra por uma hora;
 * sem ela, as etapas se pulam) vai para o `?`. */
function caixaDoSudo() {
  const caixa = $("#confirmar-sudo");
  if (!caixa || caixa.dataset.montada) return;
  caixa.dataset.montada = "1";
  caixa.classList && caixa.classList.add("com-dica");
  caixa.replaceChildren(
    elemento("strong", { texto: "Partes desta ação rodam como root (sudo)." }),
    ...gatilhoDeDica("dica-confirmar-sudo", "Sobre o sudo", [
      elemento("p", { class: "resumo", texto:
        "Nada aqui pede, lê ou guarda senha. Esta máquina lembra da senha do sudo "
        + "por uma hora, valendo em qualquer terminal: com ela digitada nesse "
        + "período, as etapas que precisam dela rodam sem perguntar; sem ela, se "
        + "pulam sozinhas e aparecem como «pulado:»." })]));
}

function perguntar({ titulo, texto, ok = "Sim", sudo = false,
                     perigo = false, neutro = false, ensaio = false, corpo = null }) {
  const dlg = $("#confirmar");
  $("#confirmar-titulo").textContent = titulo;
  $("#confirmar-texto").textContent = texto;
  const lugar = lugarDoCorpo();
  lugar.replaceChildren(...(corpo ? [corpo] : []));
  lugar.hidden = !corpo;
  if (sudo) caixaDoSudo();
  $("#confirmar-sudo").hidden = !sudo;
  $("#confirmar-ok").textContent = ok;
  /* Três pesos, e o do meio existe: descartar escolhas não escreve nada, e
   * pintar aquele botão com a cor de acento o faria parecer a ação principal. */
  $("#confirmar-ok").className =
    "btn " + (neutro ? "" : perigo ? "btn-perigo" : "btn-accent");
  botaoDeEnsaio().hidden = !ensaio;
  dlg.showModal();
  return new Promise((resolve) => {
    dlg.addEventListener("close", () => resolve(
      ensaio ? dlg.returnValue : dlg.returnValue === "sim"), { once: true });
  });
}

/* Não é toda ação com `confirma` — há ações que escrevem e não desfazem nada
 * de ninguém (instalar um tema, pôr um ícone), e um segundo botão em toda
 * caixa transformaria a escolha entre ver e fazer em burocracia de dois
 * cliques para sempre.
 *
 * DEVOLVE PALAVRA, E NÃO BOOLEANO: "rodar", "ensaio" ou "nao". */
async function confirmar(acao, argumento) {
  const oferece = !!(acao.destrutivo || acao.sudo);
  const r = await perguntar({
    titulo: acao.rotulo,
    texto: acao.ajuda,
    /* O "de verdade" só volta lá na gaveta, depois do ensaio, onde não há outra
     * frase segurando o sentido. */
    ok: "Rodar",
    sudo: acao.sudo,
    perigo: acao.destrutivo,
    ensaio: oferece,
  });
  if (!oferece) return r ? "rodar" : "nao";
  return r === "seco" ? "ensaio" : r === "sim" ? "rodar" : "nao";
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

/* A FAIXA AMARELA DO ENSAIO
 *
 * A única diferença entre "instalei isto" e "instalaria isto" são os verbos
 * dentro das linhas, no meio de centenas delas.
 *
 * O AMARELO NÃO É ESCOLHA DE GOSTO: é a cor que o projeto já usa para "mudou /
 * mudaria" — o glifo `~~` do `lib/comum.sh`, que nesta mesma gaveta já sai em
 * `--yellow` (`#saida .l-muda`). */
function faixaDeEnsaio(ligada) {
  const velha = document.getElementById("faixa-ensaio");
  if (velha) velha.remove();
  if (!ligada) return;
  $(".resultado-topo").after(elemento("div", { class: "faixa-ensaio", id: "faixa-ensaio" }, [
    elemento("strong", { texto: "ENSAIO · nada foi escrito" }),
    elemento("span", { texto: "Cada linha «~~» é uma mudança que ficou só na tela." }),
  ]));
}

/* O «Conferir a máquina» terminava com a última linha do doctor, «rode: meow
 * doctor --consertar»: a página mandando digitar o que ela mesma tem como
 * botão, dois cartões ao lado. */
function oferecerConserto(id) {
  const acao = (ESQUEMA.acoes || []).find((a) => a.id === id);
  if (!acao || document.getElementById("resultado-consertar")) return;
  const selo = acao.rede
    ? elemento("span", { class: "pastilha p-rede", id: "resultado-consertar-rede", texto: "baixa da internet" })
    : null;
  const botao = elemento("button", {
    type: "button", class: "btn", id: "resultado-consertar",
    texto: acao.rotulo,
    onclick: (ev) => { ev.currentTarget.remove(); if (selo) selo.remove(); rodar(acao, ""); },
  });
  if (selo) $("#resultado-guardar").before(selo);
  $("#resultado-guardar").before(botao);
}

/* O BOTÃO QUE FECHA O FLUXO: vejo, aprovo, rodo. Ele só aparece quando o ensaio
 * TERMINA — oferecer "rodar" no meio de uma saída que ainda corre é convidar a
 * pessoa a decidir com meia página lida. */
function oferecerRodarDeVerdade(aplicar) {
  const faixa = document.getElementById("faixa-ensaio");
  if (!faixa || !aplicar) return;
  faixa.append(elemento("button", {
    type: "button", class: "btn btn-accent", id: "ensaio-rodar",
    texto: "Rodar de verdade",
    title: "Roda de novo, agora escrevendo na máquina",
    /* É o mesmo remédio que o `salvarEscolhas` já usa: o botão se desabilita
     * entre o clique e a resposta. */
    onclick: async (ev) => {
      const botao = ev.currentTarget;
      const anterior = botao.textContent;
      botao.disabled = true;
      botao.textContent = "Rodando…";
      try {
        await aplicar();
      } finally {
        botao.disabled = false;
        botao.textContent = anterior;
      }
    },
  }));
}

function abrirJanela() {
  const d = $("#resultado");
  if (!d.open) d.showModal();
  pastilhaDeTrabalho(false);
  marcarLinhasAbaixo();
}

function abrirResultado(trabalho, aplicar = null) {
  if (TRABALHO?.timer) clearInterval(TRABALHO.timer);
  TRABALHO = { id: trabalho.id, proximo: 0, timer: null, escreve: trabalho.escreve,
               rotulo: trabalho.rotulo, mudou: false, acao: trabalho.acao || null,
               seco: !!trabalho.seco, fim: trabalho.fim || {}, aplicar,
               conserta: trabalho.conserta_com || null };
  /* O Guardar vale depois do fim, quando o `TRABALHO` já foi esquecido. */
  ULTIMO_TRABALHO = { id: trabalho.id, acao: trabalho.acao || null };
  for (const velho of ["resultado-consertar", "resultado-consertar-rede"]) {
    const no = document.getElementById(velho);
    if (no) no.remove();
  }
  faixaDeEnsaio(!!trabalho.seco);
  $("#resultado-titulo").textContent = trabalho.rotulo;
  $("#saida").replaceChildren();
  $("#parar").hidden = false;
  $("#parar").disabled = false;
  $("#resultado-restaurar").hidden = true;
  $("#resultado-guardado").hidden = true;
  marcarEstado("correndo", "correndo…");
  abrirJanela();
  TRABALHO.timer = setInterval(puxar, 400);
  puxar();
}
let ULTIMO_TRABALHO = null;

/* O que não está na tabela é erro, e a frase diz o código — é o mesmo "saiu N"
 * de antes, e é ele que o «Parar» mostra (o SIGTERM volta como -15).
 *
 * O `tests/restos-do-painel.sh` conta os nomes do topo. */
function linhaDoFim(fim, rc, mudou) {
  const tabela = fim || {};
  const linha = (rc === 0 && mudou && tabela["0~"]) || tabela[String(rc)];
  return linha || ["erro", `saiu ${rc}`];
}

function marcarEstado(classe, texto) {
  const el = $("#resultado-estado");
  el.className = "pastilha p-" + classe;
  el.textContent = texto;
}

/* Quem sobe para reler um erro perde o fio: a saída continua correndo, o
 * `puxar` deixa de rolar sozinho de propósito (ver o `noFim`), e nada na tela
 * diz quanto ficou para trás.
 *
 * A conta é uma BUSCA BINÁRIA, e não um laço pelos filhos: os `<span>` nascem
 * em ordem crescente de `offsetTop`, ler `offsetTop` força recálculo de layout,
 * e um trabalho longo passa de mil linhas — a cada 400 ms. */
function linhasAbaixo(saida) {
  const fim = saida.offsetTop + saida.scrollTop + saida.clientHeight;
  const n = saida.childElementCount;
  let baixo = 0, alto = n;
  while (baixo < alto) {
    const meio = (baixo + alto) >> 1;
    if (saida.children[meio].offsetTop >= fim) alto = meio;
    else baixo = meio + 1;
  }
  return n - baixo;
}

function marcarLinhasAbaixo() {
  const saida = $("#saida");
  /* O `fim` da busca binária vira 0, o primeiro filho já o alcança, e a conta
   * devolve TODAS as linhas. */
  if (!$("#resultado").open) return;
  let aviso = document.getElementById("mais-abaixo");
  if (!aviso) {
    /* Nasce do JavaScript, e não do `index.html`: enquanto não há linha
     * escondida ela não tem o que dizer, e um elemento vazio no HTML é um
     * elemento que alguém um dia estiliza por engano. */
    aviso = elemento("button", {
      type: "button",
      id: "mais-abaixo",
      class: "btn btn-mini",
      hidden: true,
      /* Sem este `off`, o leitor de tela reanuncia a contagem junto com cada
       * leva de saída. */
      "aria-live": "off",
      onclick: () => { saida.scrollTop = saida.scrollHeight; marcarLinhasAbaixo(); },
    });
    $("#resultado").append(aviso);
  }
  const n = linhasAbaixo(saida);
  aviso.hidden = n === 0;
  if (n) aviso.textContent = `mais ${n} ${n === 1 ? "linha" : "linhas"} abaixo`;
}

async function puxar() {
  /* O intervalo de 400 ms não espera a leitura anterior: com o servidor lento
   * (a máquina carregada), duas ficam no ar, e o que vinha depois do `await`
   * escrevia no `TRABALHO` de AGORA com a resposta de ANTES. */
  const t = TRABALHO;
  if (!t) return;
  const desde = t.proximo;
  const r = await api(`/api/trabalho?id=${t.id}&desde=${desde}`);
  if (TRABALHO !== t || t.proximo !== desde) return;
  if (r.erro) { clearInterval(TRABALHO.timer); pastilhaDeTrabalho(false); return; }
  TRABALHO.proximo = r.proximo;

  const saida = $("#saida");
  /* Só rola sozinho se ela já estava no fim. Rolar por cima de quem subiu para
   * ler uma linha de erro é a coisa mais irritante que um console faz. */
  const noFim = saida.scrollTop + saida.clientHeight >= saida.scrollHeight - 24;
  for (const linha of r.linhas) {
    saida.append(elemento("span", { class: classeDaLinha(linha), texto: linha + "\n" }));
    if (linha.trimStart().startsWith("~~")) TRABALHO.mudou = true;
  }
  if (noFim) saida.scrollTop = saida.scrollHeight;
  marcarLinhasAbaixo();

  if (!r.vivo) {
    clearInterval(TRABALHO.timer);
    $("#parar").hidden = true;
    /* Há o que desfazer: o Restaurar repõe o estado de antes desta execução. */
    $("#resultado-restaurar").hidden = !(r.restauravel && TRABALHO.acao && !TRABALHO.seco);
    if (r.restauravel && TRABALHO.acao) RESTAUROS.add(TRABALHO.acao);
    if (TRABALHO.acao === "restaurar" && (r.rc === 0 || r.rc === 1)) RESTAUROS.delete(TRABALHO.restaura);
    /* Até ali o `escreveu` também escolhia a frase: falso, o código 1 era
     * traduzido como "há divergências" em vez de "mexeu e consertou". */
    const escreveu = TRABALHO.escreve && !TRABALHO.seco;
    /* Os códigos de saída do projeto, traduzidos com as palavras dele. Um "exit
     * 1" cru pareceria falha, e quase sempre ele é a boa notícia.
     *
     * O 1 DEPENDE DE QUEM RODOU, e ignorar isso era uma mentira na tela: um
     * `meow status`, que só olha, terminava com a pastilha "mexeu e consertou". */
    const rc = r.rc;
    /* O `install.sh` sai 0 quando passa inteiro, tenha escrito ou não, e conta
     * o que escreveu nas linhas `~~` ("~~ mexeu: icones_apps_arcticons logo"). */
    /* O código não sabe se a ação confere, troca, toca ou recicla; a ação sabe,
     * e o servidor manda a tabela do fim DESTE trabalho (`fim`, ver `NATUREZAS`
     * no `servidor.py`), já trocada pela do ensaio quando é ensaio. */
    const [classeFim, fraseFim] = linhaDoFim(TRABALHO.fim, rc, TRABALHO.mudou);
    marcarEstado(classeFim, `${fraseFim} · ${r.segundos}s`);
    /* Um doctor --consertar ou um install que passou zera a lista de pendentes:
     * o que estava escrito no conf acabou de valer na tela. */
    if (escreveu && (rc === 0 || rc === 1)) { PENDENTES.clear(); atualizarAviso(); }
    /* O que os cartões mostram da máquina (`valendo_agora`), os ícones da grade
     * e os jogos eram lidos uma vez e ficavam: um instalador que mudava a dock
     * terminava com a página ainda desenhando a dock de antes. */
    if (escreveu) {
      /* Esquecidas aqui, as listas se releem na primeira pintura (o `previasDe`
       * e o `montarApps` já sabem buscar o que falta); a troca é um "lendo…" de
       * um instante no lugar da imagem quebrada. */
      const vista = "parede/" + ABA_GALERIA;
      const paredes = PREVIAS.get(vista) ? [vista] : [];
      for (const chave of [...PREVIAS.keys()]) {
        if (chave.startsWith("icone/") || chave.startsWith("parede/")) PREVIAS.delete(chave);
      }
      /* A lista que estava aberta é pedida aqui, com o trabalho já terminado, e
       * as duas repinturas de baixo esperam por ela — a grade passa da lista de
       * antes para a de depois sem sumir no meio. */
      const aberta = APPS !== null;
      APPS = null;
      const lista = aberta ? carregarApps() : null;
      /* (a dos packs, logo abaixo, e a do intervalo do `rodarNaGaleria`),
       * medidas por um vigia no `tests/app-completo.py`. */
      const galeria = Promise.all(paredes.map(
        (chave) => carregarPrevias("parede", chave.slice("parede/".length))));
      /* Uma etapa que escreveu pode ter RESOLVIDO uma pendência (ou criado
       * outra): quem apaga a linha do TSV é o próprio script, no caminho feliz.
       * Reler aqui é o que faz o bloco sumir da Home sem F5. */
      recarregarPendencias();
      /* Um trabalho que escreveu pode ter trocado o pack (o «Usar este» da
       * Home), o flavor ou o acento — e a página continuava pintada com a
       * paleta que ela tinha ao abrir. */
      const folha = document.querySelector('link[rel="stylesheet"][href^="/paleta.css"]');
      if (folha) folha.href = `/paleta.css?v=${Date.now()}`;
      Promise.all([recarregarPacks(), lista, galeria]).then(render);
      Promise.all([recarregarEsquema(), lista, galeria]).then(() => {
        PREVIAS.delete("icone/");
        /* Com a `lista` acima já relida do disco depois do trabalho, pedi-la
         * de novo aqui era o mesmo `/api/apps` duas vezes. */
        if (APPS && !lista) carregarApps();
        if (JOGOS) carregarJogos();
        render();
      });
    }
    if (!$("#resultado").open) {
      /* O desfecho não pode depender de a gaveta estar à vista: quem fechou
       * continua tendo direito de saber como acabou. A frase é a mesma da
       * pastilha de estado, com o nome do trabalho na frente. */
      const fim = $("#resultado-estado").textContent;
      /* A cor da torrada é a da pastilha: o 1 do instalador que não aplicou
       * tudo e o «há divergências» de quem só confere não são o verde de
       * «ok», nem o vermelho de erro. */
      torrada(`${TRABALHO.rotulo || "O trabalho"}: ${fim}`,
              { ok: "ok", erro: "erro" }[classeFim] || "igual");
    }
    /* O ensaio acabou: o botão que o transforma em execução entra agora. Antes
     * do `TRABALHO = null`, que é quem guarda o gesto.
     *
     * Este ramo (`!r.vivo`) é o mesmo a que se chega quando ela aperta «Parar»,
     * e o botão aparecia igual: meia página lida virava permissão para escrever
     * na máquina, que é exatamente o que o comentário do
     * `oferecerRodarDeVerdade` promete não fazer. */
    const interrompido = typeof rc !== "number" || rc < 0;
    if (TRABALHO.seco && !interrompido) oferecerRodarDeVerdade(TRABALHO.aplicar);
    if (!TRABALHO.seco && rc === 1 && TRABALHO.conserta) oferecerConserto(TRABALHO.conserta);
    pastilhaDeTrabalho(false);
    TRABALHO = null;
  }
}

/* --- navegação ------------------------------------------------------------ */
/* A frase de uma linha de cada seção. */
function descricaoDe(g) {
  const d = (ESQUEMA && ESQUEMA.descricoes) || {};
  if (typeof g === "string") return d[g] || "";
  /* "Papel de parede" existe em Ajustar (o carrossel, a noite) e em Fazer
   * (avançar, banir, semear): mesmo nome, trabalhos diferentes, e uma frase só
   * serviria mal aos dois. */
  /* O `|| d[g.secaoPai]` saiu: ele existia porque as subabas não
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

/* A ORDEM DOS ASSUNTOS VEM DO ARQUIVO, e não de uma lista escrita aqui. */
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

/* Esta função perguntava "este assunto tem chave do `meow.conf`?" — sim virava
 * Assuntos, não virava máquina.
 *
 * A tabela mora no `servidor.py` (`BLOCO_DA_SECAO`) e chega em
 * `ESQUEMA.blocos`, porque é lá que as seções são NOMEADAS: uma segunda lista
 * aqui seria a que discorda da primeira no dia em que alguém renomear um título
 * no `meow.conf.exemplo`. */
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

  /* O menu tinha 22 itens em três blocos de verbo (Escolher · Configurar ·
   * Executar) e dois níveis, e o mesmo assunto aparecia em dois ou três deles:
   * "Papéis de parede" para olhar, "Papel de parede" para ajustar, "Papel de
   * parede" para rodar.
   *
   * Agora o assunto é a página, e ela carrega o que existir sobre ele: a
   * galeria, os ajustes e as ações. */
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

/* É um `<a>` e não um `<button>`, e isso não é detalhe de gosto: o botão do
 * meio abre em aba nova, o Ctrl+clique também, e o leitor de tela anuncia
 * "link" em vez de "botão" — três comportamentos que ela teria de descobrir que
 * não existem.
 *
 * `rel="noopener noreferrer"`: a página que abre não ganha referência a esta, e
 * a origem `127.0.0.1:<porta aleatória>` não vaza no cabeçalho. */
/* O ENDEREÇO VEM DO SERVIDOR, que o lê do `git remote` — nunca escrito aqui.
 * Escrito aqui, o hook de commit trocava o nome dela por uma redação e o link
 * ia para o ar apontando para uma URL morta.
 *
 * O endereço continua vindo do servidor pelo motivo do bloco acima, que é o do
 * fork, e não por medo do hook. */
function itensExternos() {
  const repo = (ESQUEMA && ESQUEMA.repositorio) || "";
  /* Sem remoto não há para onde ir, e um item que não abre é pior que um item a
   * menos: ela clicaria uma vez, não aconteceria nada, e a partir dali o menu
   * inteiro seria suspeito. */
  if (!repo) return [];
  /* O início do README é onde estão a logo, os números medidos e o link para
   * `docs/CREDITOS.md` — a licença de cada acervo de terceiro que este projeto
   * veste, que o painel não tem em lugar nenhum.
   *
   * A âncora `#créditos` que estava aqui apontava para uma seção de quatro
   * linhas no meio da página; o GitHub ainda a resolveria, mas ela deixaria a
   * leitora no lugar mais pobre dos dois. */
  const LINKS_EXTERNOS = [
    /* O que saiu foi o inventário ("a paleta, os glifos, as fontes e a base de
     * ícones"): num balão de item de menu ele é uma lista que ninguém lê de
     * passagem, e a página inteira do GitHub a mostra melhor do que um balão
     * poderia. */
    { nome: "Créditos", href: repo,
      titulo: "O projeto no GitHub, com a licença de cada acervo que ele veste" },
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

/* O número ao lado do nome soma O QUE HÁ PARA MEXER: as chaves de cada bloco de
 * ajuste e as ações. Não as imagens da galeria, nem os jogos, nem os programas
 * — ver `contaDoGrupo`. */
function botaoDeAssunto(assunto) {
  const meus = GRUPOS.filter((g) => assuntoDe(g) === assunto);
  const conta = meus.reduce((s, g) => s + (Number(contaDoGrupo(g)) || 0), 0);
  /* O PONTO DE PENDÊNCIA: a aba que tem escolha esperando ganha um ponto na
   * cor de acento ao lado do nome. */
  const pendente = meus.some((g) => g.tipo === "chaves"
    && (g.itens || []).some((i) => MUDANCAS.has(i.chave)));
  /* O hover responde sem gastar largura do menu. */
  const soAjustes = meus.filter((g) => g.tipo === "chaves")
    .reduce((t, g) => t + (g.itens || []).length, 0);
  const soAcoes = meus.filter((g) => g.tipo === "acoes")
    .reduce((t, g) => t + (g.itens || []).length, 0);
  return elemento("button", {
    type: "button",
    "data-grupo": assunto,
    "aria-current": String(assunto === ABA),
    title: conta
      ? `${assunto} — ${soAjustes === 1 ? "1 ajuste" : soAjustes + " ajustes"}`
        + (soAcoes ? ` e ${soAcoes === 1 ? "1 ação" : soAcoes + " ações"}` : "")
      : assunto,
    onclick: () => { $("#busca").value = ""; ABA = assunto; gravarHash(); render(); },
  }, [
    iconeDeMenu(assunto, "assunto"),
    elemento("span", { texto: encurtar(assunto) }),
    pendente ? elemento("span", { class: "ponto-pendente", "aria-label": "há escolha esperando aqui" }) : null,
    elemento("span", { class: "conta", texto: conta ? String(conta) : "" }),
  ]);
}

/* OS ÍCONES DO MENU — no lugar do traço
 *
 * OS DESENHOS SÃO OS ARQUIVOS DO ACERVO, e não uma imitação deles.
 *
 * DUAS SÃO AUTORAIS, E ESTÃO MARCADAS: o acervo não tem gato.
 *
 * O acervo desenha para 48 px reais na dock, com traço 1; aqui os glifos vivem
 * a 17 px, e 1/48 × 17 dá 0,35 px — some numa tela sem hidpi. */
const ICONES_MENU = {
  /* OS DOIS BLOCOS DO MENU, com os nomes: `Assuntos` virou `Tópicos` e `A
   * máquina` virou `Sistema`. */
  "bloco/Tópicos": '<circle cx="12.281" cy="22.389" r="2.781"/><circle cx="24" cy="18.613" r="2.781"/><circle cx="35.719" cy="24.646" r="2.781"/><path d="M24 21.394v14.925m11.719-8.893v8.893M12.281 25.17v11.149m0-16.711v-1.591m0-1.577v-1.591m0-1.578v-1.59M24 15.833v-.984m0-1.578v-1.59m11.719 7.927v-1.591m0 3.848v-.702m0-4.723v-1.591m0-1.578v-1.59"/><circle cx="24" cy="24" r="21.5"/>',
  /* O foguete do Arcticons: a máquina indo para a versão seguinte. Ele perdeu a
   * entrada `bloco/` — o terceiro bloco deixou de existir, e a página de
   * atualizar passou a se chamar `Idempotência`, dentro de Sistema. */
  "Atualização": '<path d="M5.896 22.443L42.105 5.5l-10.836 37l-11.453-13.323z"/><path d="m31.326 16.95l-11.51 12.227v8.747l3.316-4.824"/>',
  "bloco/Sistema": '<path d="M24 8.408V19.81m5.255-7.944A13.22 13.22 0 0 1 37.223 24h0c0 7.303-5.92 13.223-13.223 13.223h0c-7.303 0-13.223-5.92-13.223-13.223h0c0-5.27 3.129-10.037 7.964-12.133M45.5 24c0 11.874-9.626 21.5-21.5 21.5S2.5 35.874 2.5 24S12.126 2.5 24 2.5S45.5 12.126 45.5 24"/>',
  /* AUTORAL: o acervo não tem gato — e aqui o gato É o assunto, porque a logo
   * de fábrica deste projeto são a Coquinha e o Mimir. As orelhas do mascote,
   * em três traços. */
  "Logo do sistema": '<path d="M13 21V11l8 6M35 21V11l-8 6"/><path d="M13 20c0 10 5 17 11 17s11-7 11-17"/>',

  /* as abas */
  "Início": '<path d="M42.5 23.075L26.062 7.525a3 3 0 0 0-4.124 0L5.5 23.075m5.86 1.54v14.68a2 2 0 0 0 2 2h7.14v-9.5h7v9.5h7.14a2 2 0 0 0 2-2v-14.68"/>',
  "Cor e tela": '<rect width="18.314" height="39" x="14.843" y="4.5" rx="3"/><path d="M14.843 33.4h18.314M14.843 22.236s3.933-.233 5.292 2.27s2.605 3.387 4.466.291s3.5-6.83 8.556-.514m-.001-11.601s-1.669-2.183-3.418-2.088s-4.099 4.972-5.418 4.852s-2.285-6.481-4.118-7.03s-5.36 2.35-5.36 2.35"/><ellipse cx="24" cy="38.01" rx="1.965" ry="1.957"/>',
  /* AUTORAL: o acervo não tem gato. As orelhas do mascote, em três traços. */
  "Ícones": '<path d="M17.5 5.5h-8a4 4 0 0 0-4 4v8a4 4 0 0 0 4 4h8a4 4 0 0 0 4-4v-8a4 4 0 0 0-4-4m21 0h-8a4 4 0 0 0-4 4v8a4 4 0 0 0 4 4h8a4 4 0 0 0 4-4v-8a4 4 0 0 0-4-4m-21 21h-8a4 4 0 0 0-4 4v8a4 4 0 0 0 4 4h8a4 4 0 0 0 4-4v-8a4 4 0 0 0-4-4m21 0h-8a4 4 0 0 0-4 4v8a4 4 0 0 0 4 4h8a4 4 0 0 0 4-4v-8a4 4 0 0 0-4-4"/>',
  "Painel e dock": '<rect width="22.05" height="32.42" x="12.98" y="7.79" rx="2"/><path d="M35 38.18h5.95a2.6 2.6 0 0 0 2.59-2.59V12.41a2.6 2.6 0 0 0-2.59-2.59H35"/><path d="M35.02 34.8h5.32V15.93h-5.32M13 38.18H7.09a2.6 2.6 0 0 1-2.59-2.59V12.41a2.6 2.6 0 0 1 2.59-2.59H13"/><path d="M12.98 34.8H7.66V15.93h5.32m2.65-3.39h16.75v24.21H15.63z"/>',
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

/* O subtítulo de um grupo dentro da página do assunto. */
function rotuloDoGrupo(g) {
  /* O `humanizar` é o mesmo que o menu já aplica: os subtítulos moram em CAIXA
   * ALTA no `meow.conf.exemplo` porque é assim que o arquivo distingue as duas
   * alturas de título, e essa é uma convenção de ARQUIVO. */
  if (g.nome !== assuntoDe(g)) return humanizar(g.nome);
  /* Uma seção sem subtítulo no arquivo ganhava um `<h3>Ajustes</h3>` entre o
   * título da página e a primeira coisa útil.
   *
   * `null` e não `""`: quem chama testa o valor e simplesmente não desenha o
   * `<h3>`, em vez de desenhar um vazio que continua ocupando margem. */
  return g.tipo === "acoes" ? "Ações" : null;
}

function botaoTrilho(g, filho, rotulo) {
  return elemento("button", {
    type: "button",
    /* `e-inicio` é o que a folha usa para pintar de verde — ver o comentário
     * lá. */
    class: (filho ? "filho" : "") + (g.tipo === "home" ? " e-inicio" : ""),
    "data-grupo": chaveDeAba(g),
    "aria-current": String(chaveDeAba(g) === ABA),
    title: g.original || g.nome,
    onclick: () => {
      /* É verdade e é inevitável: com busca ativa a página mostra os
       * RESULTADOS, não a aba, então o clique parecia não fazer nada. Trocar
       * de seção é dizer "quero ver esta aba"; a busca sai do caminho. */
      $("#busca").value = "";
      ABA = chaveDeAba(g);
      gravarHash();
      render();
    },
  }, [
    iconeDeMenu(g.nome, g.bloco || "fazer"),
    elemento("span", { texto: rotulo || encurtar(g.nome) }),
    elemento("span", { class: "conta", texto: contaDoGrupo(g) }),
    /* Só no nível de cima: num subitem ela empurraria o menu para uma altura
     * que não cabe na tela, e o subitem já é lido dentro do assunto do pai. */
    !filho && descricaoDe(g)
      ? elemento("span", { class: "descricao-menu", texto: descricaoDe(g) })
      : null,
  ].filter(Boolean));
}

/* A galeria aparecia como "Galeria de papéis de parede  0" — porque o contador
 * lia `itens.length`, e a galeria não é feita de chaves do meow.conf: os itens
 * dela são as imagens, que chegam depois, do `/api/previas`. */
/* As três listas grandes — a galeria de papéis de parede, os programas e os
 * jogos da Steam — chegam por rede depois da primeira pintura, e cada uma
 * somava ao contador quando chegava.
 *
 * Antes de carregar ele contava "quantos ajustes há aqui"; depois, "quantos
 * ajustes mais quantos jogos".
 *
 * Agora o número é UM: o que há para mexer nesta página — as chaves e as ações. */
function contaDoGrupo(g) {
  if (g.tipo === "home") return "";
  if (g.tipo === "galeria" || g.tipo === "apps" || g.tipo === "jogos") return "";
  return String(g.itens.length);
}

/* QUEM DESENHA NÃO É ESTE ARQUIVO. Cada bloco tem uma função em
 * `previas-tela.js` ou `previas-sistema.js`, registrada em `window.MEOW_PREVIAS`
 * sob a chave `"Seção :: BLOCO"` — e só `"Seção"` quando a seção não tem bloco
 * em CAIXA ALTA, que é exatamente a regra pela qual esta página já nomeia os
 * grupos (`subsecao || secao`). Aqui só se pergunta e se põe na tela. */
/* Até aqui o deslizante só mexia no número enquanto ela arrastava; o desenho só
 * mudava no `change`, isto é, quando ela SOLTAVA — e mesmo assim pelo caminho
 * comprido: `aplica()` grava em `MUDANCAS` e chama `render()`, que reconstrói a
 * página inteira.
 *
 * O registro abaixo é o que permite repintar SÓ o bloco daquela chave. */
const PREVIA_VIVA = new Map();   /* chave do meow.conf -> { g | forma, alvo } */

function repintarPrevia(chave, valor) {
  const reg = PREVIA_VIVA.get(chave);
  if (!reg || !reg.alvo || !reg.alvo.parentNode) return;
  PROVISORIO = { chave: chave, valor: valor };
  try {
    if (reg.forma) {
      /* O mock lê tudo por `valorEmVigor`, que já conhece o `PROVISORIO`:
       * reconstruir os dois basta, e não há contrato novo a inventar. */
      pintarForma(reg.alvo);
      return;
    }
    /* O relógio da noite também lê por `valorEmVigor`: arrastar a hora do tema
     * move o anel dele no mesmo gesto. */
    if (reg.relogio) {
      const novo = relogioDaNoite();
      reg.alvo.replaceWith(novo);
      for (const r of PREVIA_VIVA.values()) if (r.relogio) r.alvo = novo;
      return;
    }
    const novo = parDePrevias(reg.g);
    if (novo) {
      reg.alvo.replaceWith(novo);
      reg.alvo = novo;
      pintarGatosEmCelulas(novo);
      /* Todas as chaves do bloco apontam para o MESMO nó, e ele acabou de ser
       * trocado: sem isto, a segunda chave do bloco repintaria um nó órfão. */
      for (const [k, r] of PREVIA_VIVA) if (r.g === reg.g) r.alvo = novo;
    }
  } finally {
    PROVISORIO = null;
  }
}

/* A IDEIA É VELHA E JÁ CAIU DUAS VEZES, PELO MESMO DEFEITO: dois botões com
 * borda, lado a lado, e o mesmo desenho nos dois. */

/* O medidor vive fora da tela e é UM só: criar e destruir um contêiner por
 * cartão custaria um `layout` a mais por medição, e são dezenas por aba. */
function medidorDeDesenho() {
  let el = document.getElementById("medidor-de-desenho");
  if (!el) {
    el = elemento("div", { id: "medidor-de-desenho", "aria-hidden": "true" });
    document.body.append(el);
  }
  return el;
}

/* O retrato de um desenho: uma linha por elemento, com a CAIXA que o navegador
 * calculou e a TINTA que ele vai pintar. */
function retratoDoDesenho(no, largura) {
  const cx = medidorDeDesenho();
  cx.style.width = largura + "px";
  cx.replaceChildren(no);
  const raiz = cx.getBoundingClientRect();
  const linhas = [];
  const anda = (e) => {
    const r = e.getBoundingClientRect();
    const cs = getComputedStyle(e);
    let proprio = "";
    for (const f of e.childNodes) if (f.nodeType === 3) proprio += f.data;
    /* QUEM NÃO PINTA NÃO CONTA ÁREA — e isto foi medido, não suposto. Um `<g>`
     * que só agrupa tem a caixa de todos os filhos juntos. */
    const semTinta = (x) => !x || x === "none" || x === "rgba(0, 0, 0, 0)"
                         || x === "transparent";
    /* O `d` (e o `points`, e o `transform`) fecha o buraco por um punhado
     * de bytes de string. */
    linhas.push({
      tag: e.nodeName,
      forma: (e.getAttribute && [e.getAttribute("d"), e.getAttribute("points"),
                                 e.getAttribute("transform"), e.getAttribute("rx"),
                                 e.getAttribute("ry")].filter(Boolean).join(";")) || "",
      x: r.left - raiz.left, y: r.top - raiz.top, w: r.width, h: r.height,
      pinta: !((semTinta(cs.fill) || cs.fillOpacity === "0")
               && (semTinta(cs.stroke) || cs.strokeOpacity === "0")
               && semTinta(cs.backgroundColor) && !proprio.trim()),
      /* O `fill-opacity` foi o caso que ensinou: `VIDRO_AO_MAXIMIZAR` troca 0,8
       * por 1 em dois retângulos grandes — 10,05% dos pixels — e esta conta
       * dizia ZERO, porque `opacity` e `fill-opacity` são propriedades
       * diferentes e só a primeira estava aqui. */
      tinta: [cs.fill, cs.stroke, cs.backgroundColor, cs.opacity, cs.strokeWidth,
              cs.strokeDasharray, cs.display, cs.borderRadius, cs.fillOpacity,
              cs.strokeOpacity, cs.visibility, cs.filter, cs.clipPath, cs.mask,
              proprio.trim()].join("|"),
    });
    for (const f of e.children) anda(f);
  };
  anda(no);
  cx.replaceChildren();
  return linhas;
}

/* A ÁREA QUE MUDOU, em pixels do tamanho em que o botão vai ser desenhado.
 * Elementos são comparados em ordem de árvore; quando um existe de um lado só,
 * a caixa dele conta inteira — sumir é a mudança mais visível que existe.
 *
 * Formas aninhadas contam duas vezes, e o número estourava a própria figura: o
 * `JANELAS_TILING_ESCOPO` marcava 50.402 px² num desenho de 21.792, enquanto a
 * fotografia dos dois lados dizia 0,25% dos pixels diferentes. */
const CELULA = 8;

function areaQueMuda(a, b) {
  const chaveDe = (l) => [l.tag, Math.round(l.x), Math.round(l.y),
                          Math.round(l.w), Math.round(l.h), l.forma, l.tinta].join("~");
  const contar = (lista) => {
    const m = new Map();
    for (const l of lista) {
      const c = chaveDe(l);
      const t = m.get(c);
      if (t) t.n++; else m.set(c, { linha: l, n: 1 });
    }
    return m;
  };
  const A = contar(a), B = contar(b);
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  const celulas = new Set();
  const marcar = (c) => {
    if (!c || !c.w || !c.h) return;
    x0 = Math.min(x0, c.x); y0 = Math.min(y0, c.y);
    x1 = Math.max(x1, c.x + c.w); y1 = Math.max(y1, c.y + c.h);
    if (!c.pinta) return;
    const i0 = Math.floor(c.x / CELULA), i1 = Math.floor((c.x + c.w) / CELULA);
    const j0 = Math.floor(c.y / CELULA), j1 = Math.floor((c.y + c.h) / CELULA);
    if ((i1 - i0 + 1) * (j1 - j0 + 1) > 4096) return;
    for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) celulas.add(i + "," + j);
  };
  for (const [c, t] of A) if ((B.get(c) || { n: 0 }).n !== t.n) marcar(t.linha);
  for (const [c, t] of B) if ((A.get(c) || { n: 0 }).n !== t.n) marcar(t.linha);
  if (x1 < x0 || y1 < y0) return { larg: 0, alt: 0, uniao: 0, tinta: 0 };
  return { larg: x1 - x0, alt: y1 - y0, uniao: (x1 - x0) * (y1 - y0),
           tinta: celulas.size * CELULA * CELULA };
}

function grupoDaChave(chave) {
  for (const g of GRUPOS) {
    if (g.tipo !== "chaves") continue;
    if ((g.itens || []).some((i) => i.chave === chave)) return g;
  }
  return null;
}

/* O desenho do bloco desta chave, com ELA no valor pedido e todo o resto como
 * está no DISCO. O disco e não a bandeja: ver `parDeBotoes`. */
function desenhoNoValor(item, valor) {
  if (CHAVES_DO_MOCK.indexOf(item.chave) >= 0) {
    /* O mock lê tudo por `valorEmVigor`, que já consulta o `PROVISORIO` — o
     * mesmo caminho que o deslizante usa para repintar enquanto ela arrasta. */
    const salvo = PROVISORIO;
    PROVISORIO = { chave: item.chave, valor: valor };
    try {
      return mockDaBarra({ chave: item.chave }, { semLegenda: true });
    } catch (e) {
      return null;
    } finally {
      PROVISORIO = salvo;
    }
  }
  const g = grupoDaChave(item.chave);
  if (!g) return null;
  const mapa = (typeof window !== "undefined" && window.MEOW_PREVIAS) || {};
  const nome = g.nome === g.secaoPai ? g.nome : `${g.secaoPai} :: ${g.nome}`;
  const fn = mapa[nome];
  if (typeof fn !== "function") return null;
  const v = {};
  /* A base é a tela dela, como no par do alto do bloco. */
  for (const it of g.itens) v[it.chave] = valorNaTela(it);
  let r;
  try {
    r = fn(v, { [item.chave]: valor });
  } catch (e) {
    return null;
  }
  if (!r || !r.antes) return null;
  /* `depois` só existe quando o valor pedido difere do que está em `v`. Quando
   * é o mesmo, o desenho pedido É o `antes`. */
  return (String(v[item.chave] ?? "") === String(valor)) ? r.antes : (r.depois || r.antes);
}

/* O `viewBox` da peça que esta chave mexe, quando o desenho do bloco declara
 * um `recorte` (hoje, só a Manutenção); `null` no resto. A base é a mesma tela
 * que o `desenhoNoValor` usa, para o enquadramento seguir a figura. */
function recorteDoPar(item) {
  const g = grupoDaChave(item.chave);
  if (!g) return null;
  const mapa = (typeof window !== "undefined" && window.MEOW_PREVIAS) || {};
  const fn = mapa[g.nome === g.secaoPai ? g.nome : `${g.secaoPai} :: ${g.nome}`];
  if (!fn || typeof fn.recorte !== "function") return null;
  const v = {};
  for (const it of g.itens) v[it.chave] = valorNaTela(it);
  try {
    return fn.recorte(item.chave, v) || null;
  } catch (e) {
    return null;
  }
}

/* Quem já foi medido, e o que deu. A resposta é cara (dois desenhos e dois
 * `layout`) e não muda enquanto o DISCO não mudar — então mede-se uma vez por
 * chave e guarda-se. */
const PAR_VISIVEL = new Map();

/* A LARGURA EM QUE O BOTÃO VAI APARECER, e é nela que se mede. Na tela dela
 * (1918 px) a grade tem três colunas de ~500 px; dois botões lado a lado dentro
 * do cartão dão ~220 px cada, descontado o recheio. */
const LARGURA_DO_BOTAO = 220;

/* Os dois números caem no mesmo lugar, e o vão entre as duas famílias é limpo:
 *
 *     tinta      foto      chaves
 *         0    0,00–0,25%  FASTFETCH_LOGO_CONF, FILES_MENU_AUTOBUILD,
 *                          LOGO_RECICLAR, JANELAS_TILING_ESCOPO
 *     ----------------- o vão -----------------
 *       192    0,53%       LEITURA_APPLET
 *       384    0,53–0,75%  os três *_NOTIFICAR, TERMINAL_CURSOR
 *      1024+   ≥1,5%       todo o resto, até 59.136 / 51,7% (FORMA_PAINEL_SOLTO)
 *
 *     tinta      foto      chaves
 *       1536    1,94%      WALLPAPER_ORDEM
 *       1600    1,62%      STEAM_VIGIA
 *     ----------------- o vão ----------------- */
const TINTA_MINIMA = 2000;

function parVisivel(item) {
  if (PAR_VISIVEL.has(item.chave)) return PAR_VISIVEL.get(item.chave);
  let resposta = false;
  try {
    const a = desenhoNoValor(item, item.opcoes[0]);
    const b = desenhoNoValor(item, item.opcoes[1]);
    if (a && b) {
      const d = areaQueMuda(retratoDoDesenho(a, LARGURA_DO_BOTAO),
                            retratoDoDesenho(b, LARGURA_DO_BOTAO));
      resposta = d.tinta >= TINTA_MINIMA;
    }
  } catch (e) {
    resposta = false;
  }
  PAR_VISIVEL.set(item.chave, resposta);
  return resposta;
}

function parDeBotoes(item, aplica) {
  /* NA BUSCA, NÃO. Ela mostra resultados de várias seções ao mesmo tempo e
   * repinta a cada tecla; dezenas de desenhos por tecla é o custo que a busca
   * não pode pagar. É a mesma decisão que o par do topo do bloco já toma. */
  if (semAcento($("#busca").value.trim())) return null;
  if (!parVisivel(item)) return null;

  const valor = valorEmVigor(item);
  const caixa = elemento("div", { class: "par-botoes" });
  const desenhos = new Map();
  for (const opcao of item.opcoes) {
    const desenho = desenhoNoValor(item, opcao);
    if (!desenho) return null;
    desenhos.set(opcao, desenho);
  }
  /* Quando o desenho do bloco sabe onde mora a peça que a chave mexe (o
   * `recorte` dele), o par mostra só ela, grande, em vez da figura inteira
   * com uma diferença de dez pixels. */
  const recorte = recorteDoPar(item);
  if (recorte) {
    for (const desenho of desenhos.values()) {
      const svg = desenho.matches && desenho.matches("svg") ? desenho : desenho.querySelector && desenho.querySelector("svg");
      if (!svg) continue;
      /* O QUE FICA FORA DO RECORTE NÃO APARECE: o SVG mostra o que cabe na
       * caixa dele, e não só o `viewBox` — com o botão mais largo que a peça,
       * a engrenagem vizinha entrava cortada pelas laterais. */
      const [x, y, w, h] = recorte.split(/\s+/).map(Number);
      const NS = "http://www.w3.org/2000/svg";
      const id = `recorte-${item.chave}-${desenho === desenhos.get(item.opcoes[0]) ? 0 : 1}`;
      const clip = document.createElementNS(NS, "clipPath");
      clip.setAttribute("id", id);
      const caixaDoRecorte = document.createElementNS(NS, "rect");
      for (const [k, val] of Object.entries({ x, y, width: w, height: h })) caixaDoRecorte.setAttribute(k, val);
      clip.append(caixaDoRecorte);
      const dentro = document.createElementNS(NS, "g");
      dentro.setAttribute("clip-path", `url(#${id})`);
      dentro.append(...[...svg.childNodes].filter((n) => n.nodeName !== "title"));
      svg.append(clip, dentro);
      svg.setAttribute("viewBox", recorte);
    }
  }
  const pintar = (v) => {
    for (const b of caixa.querySelectorAll("button[data-valor]")) {
      b.setAttribute("aria-pressed", String(b.dataset.valor === v));
    }
  };
  for (const opcao of item.opcoes) {
    /* OS DOIS SÃO BOTÃO, ao contrário do par grudado no alto da seção — lá o
     * "Como fica" não é botão porque não leva a lugar nenhum. Aqui os dois
     * levam: cada um é uma escolha que ela ainda não fez.
     *
     * O desenho é a promessa, a palavra é a garantia — e quem lê por leitor de
     * tela só tem a palavra. */
    const moldura = elemento("span", { class: "desenho-botao", "aria-hidden": "true" });
    moldura.append(desenhos.get(opcao));
    caixa.append(elemento("button", {
      type: "button",
      class: "lado-botao",
      "data-valor": opcao,
      "aria-pressed": "false",
      onclick: async () => { if (await aplica(opcao)) pintar(opcao); },
    /* O rótulo que o servidor deu vem primeiro, como no seletor e nos botões
     * de opção: o `item.rotulos` do TERMINAL_CURSOR diz o nome do pack no
     * ar, e este par o ignorava. */
    }, [moldura, elemento("span", { class: "rotulo-lado",
        texto: (item.rotulos && item.rotulos[opcao]) || rotuloDeValor(opcao) })]));
  }
  /* O «Deixar como está» das três chaves que aceitam vazio fica numa linha
   * própria embaixo, e sem desenho: o desenho dele seria igual ao de uma das
   * duas opções, e dois botões iguais é o defeito que este bloco inteiro
   * existe para evitar. */
  if (temOQueRestaurar(item, valor)) {
    const deFabrica = padraoDe(item);
    caixa.append(elemento("button", {
      type: "button", class: "vazio linha-inteira", "data-valor": deFabrica === "" ? "" : null,
      texto: rotuloVazio(item), "aria-pressed": "false",
      title: tituloDoRestaurar(item),
      onclick: async () => { if (await aplica(deFabrica)) pintar(deFabrica); },
    }));
  }
  const naoToca = botaoNaoTocar(item, valor, aplica, "vazio linha-inteira", pintar);
  if (naoToca) caixa.append(naoToca);
  /* Com a chave vazia, o lado que a máquina tem fica a traço — o «como está»
   * dos segmentos, e pelo mesmo motivo: nenhum dos dois foi escolhido. */
  if (valor === "" && item.valendo_agora != null) {
    const comoEsta = caixa.querySelector(
      `button[data-valor="${CSS.escape(String(item.valendo_agora))}"]`);
    if (comoEsta) {
      comoEsta.classList.add("como-esta");
      porBalao(comoEsta, `Como está: ${rotuloDeValor(item.valendo_agora)}`);
    }
  }
  pintar(valor);
  return caixa;
}

function desenhoDaSecaoSemChaves(assunto) {
  /* Só quando NÃO há grupo de chaves nesta seção: se houver, o desenho é o do
   * bloco, com par e tempo real, e dois desenhos na mesma página seriam a mesma
   * figura repetida com números diferentes. */
  for (const g of GRUPOS) {
    if (g.tipo === "chaves" && assuntoDe(g) === assunto && (g.itens || []).length) return null;
  }
  const mapa = (typeof window !== "undefined" && window.MEOW_PREVIAS) || {};
  const fn = mapa[assunto];
  if (typeof fn !== "function") return null;
  let r;
  try {
    r = fn({});
  } catch (e) {
    return null;
  }
  if (!r || !r.antes) return null;
  const caixa = elemento("div", { class: "previa-bloco" });
  const par = elemento("div", { class: "par-previa" });
  par.append(elemento("div", {}, [r.antes]));
  caixa.append(par);
  /* A legenda vai para o `?` do desenho — ver `dicaDoDesenho`. */
  const dica = dicaDoDesenho(assunto, r.legenda);
  if (dica) ancorarDicaDoDesenho(par, dica);
  return caixa;
}

function parDePrevias(g) {
  if (g.tipo !== "chaves" || !g.itens.length) return null;
  const mapa = (typeof window !== "undefined" && window.MEOW_PREVIAS) || {};
  /* A chave é montada com a MESMA regra que batiza o grupo: quando o bloco em
   * caixa alta existe, ele é o `g.nome` e a seção é o `g.secaoPai`. */
  const nome = g.nome === g.secaoPai ? g.nome : `${g.secaoPai} :: ${g.nome}`;
  const desenhar = PREVIAS_REAIS[nome] || mapa[nome];
  if (typeof desenhar !== "function") return null;

  const v = {};
  const escolhido = {};
  for (const item of g.itens) {
    /* O meow.conf diz o que vai ser aplicado; a tela dela é o que o
     * `valendo_agora` leu. */
    v[item.chave] = valorNaTela(item);
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

  /* O desenho da aba Ícones escreve o valor cru («pastas em
   * cat-${FLAVOR}-${ACCENT}»), e é certo que escreva: o arquivo de prévia não
   * sabe o que é um pack. */
  for (const item of g.itens) {
    if (!item.molde_pastas || !r.legenda || !v[item.chave]) continue;
    const humano = descreverPastas(v[item.chave]);
    if (humano) r.legenda = r.legenda.split(`pastas em ${v[item.chave]}`).join(humano);
  }

  /* O que sobreviveu é a leitura mais literal do que ela escreveu, e é a mais
   * barata: o par que já está no alto do bloco, e que já reage ao dedo dela,
   * ganha borda e passa a ser onde se escolhe.
   *
   *   A semântica é a que o par já tinha, dita em voz alta:
   *     - "Como fica" existe só quando há escolha esperando, e é o que está
   *       marcado. Apertá-lo não muda nada, e por isso ele NÃO é botão: um
   *       botão que não faz nada ensina a não confiar nos outros.
   *     - "Como está" é o desfazer DAQUELE bloco. É a única coisa nova, e é o
   *       que faltava: até aqui, desistir custava achar cada cartão mexido, ou
   *       o "Descartar" do topo, que joga fora as escolhas da página inteira. */
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
  /* Numa coluna de 1600 px o desenho saía com 200 px de largura no meio de um
   * oceano vazio, e a primeira impressão de um desenho que existe para
   * explicar era "isto está perdido na página".
   *
   * `.par-previa` limita a coluna à largura que o desenho realmente ocupa,
   * então ele preenche o que lhe cabe — com par ou sem par. */
  const par = elemento("div", { class: "par-previa" }, [
    lado("Como está", r.antes, temEscolha ? desfazerBloco : null),
    /* Sem escolha pendente é UM desenho, e não um par com metade vazia: um
     * quadro em branco rotulado "Como fica" prometeria uma diferença que não
     * existe. */
    r.depois ? lado("Como fica", r.depois, null) : null,
  ]);
  const bloco = elemento("div", { class: "previa-bloco" }, [par]);
  /* A maiúscula e o «Desenho, não é a sua tela» são resolvidos lá, num lugar só
   * para os dez desenhos. */
  const dica = dicaDoDesenho(nome, temEscolha && r.legenda
    ? r.legenda.replace(/\.$/, "") + " — à direita, o mesmo desenho com a escolha que ainda não foi salva."
    : r.legenda);
  if (dica) ancorarDicaDoDesenho(par, dica);
  return bloco;
}

/* A aba tinha 21 chaves e nenhuma frase dizendo em QUE LUGAR DA TELA cada uma
 * age.
 *
 * · o MENU DE LANÇAMENTO, que é o que abre ao apertar a tecla Super e hoje
 * mostra a coquinha do Pop!_OS; · a DOCK; · o TERMINAL, onde o fastfetch
 * desenha a logo em letras. */
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
  /* Eram cinco linhas de texto corrido antes do primeiro controle (print 13 do
   * uso real). */
  return caixa;
}

/* Dois dos seis destinos do `botaoAcervo` não têm um CONTROLE de onde pendurar:
 * a fonte e o tema de ícones de base não são a opção de uma chave — são coisas
 * que a máquina precisa TER para que as chaves façam sentido. */
/* Na busca a nota não nasce, então «abaixo» vale em todo lugar onde ela
 * aparece. */
const ACERVO_DO_ASSUNTO = {
  /* Ele pendurava no primeiro cartão de gato da página, que com o seletor
   * único depende do modo: por horário seria o gato do dia, fixo seria o
   * gato. */
  "Logo do sistema": {
    tipo: "gato",
    nota: "Um .svg seu entra na lista de gatos, ao lado dos de fábrica, para o "
        + "dock e para o terminal.",
  },
  "Ícones": {
    tipo: "tema-icones",
    nota: "Um tema de ícones de base, em .zip. Ele entra na máquina, e o "
        + "«Tema de onde herdar», abaixo, passa a poder escolhê-lo.",
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
     * teve. */
    await recarregarEsquema();
    if (conf.tipo === "gato") await carregarPrevias("gato");
    render();
  });
  /* SÓ O BOTÃO. A nota que ia ao lado dele é explicação, e explicação é
   * dica: ela entra no `?` do cabeçalho da página, que é onde o botão passou
   * a morar (ver `cabecalhoDePagina`). */
  return botao || null;
}

/* `render()` refaz o conteúdo inteiro. Quem estava com o foco deixa de existir,
 * e o navegador devolve o foco ao `<body>`.
 *
 * A âncora é a CHAVE do cartão mais o tipo do elemento — e não uma posição na
 * árvore, que muda quando um cartão nasce ou some. */
function ancoraDoFoco() {
  const el = document.activeElement;
  if (!el || el === document.body) return null;
  /* Agora eles se identificam, e o foco volta com a posição do cursor junto. */
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

/*   1. "ao clicar em alguma config e setar algo ele sobe automaticamente a
 *      barra de rolagem" — na página de papel de parede.
 *
 *   2. "nas abas mais curtas ... esse problema que impede de descer a
 *      navegação". Medido entrando em "Instalação" vinda de "Papel de parede"
 *      rolada a 1200: `scrollTop=100`, com o título da página 19 px ACIMA da
 *      área visível. Ela chega numa tela sem cabeçalho e sem lugar. */
let PAGINA_ROLADA = null;   // que página o `main` está mostrando agora
let ROLAGEM_PENDENTE = 0;   // ponto que ainda não coube na pintura anterior

function identidadeDaPagina() {
  return String(ABA) + "\u0000" + $("#busca").value.trim();
}

/* `passive: true` porque nenhum destes ouvintes chama `preventDefault` — sem
 * isso o Chrome atrasa a rolagem esperando para saber. */
function ouvirGestoDeRolagem() {
  const m = $("#principal");
  if (!m) return;
  const apagar = () => { ROLAGEM_PENDENTE = 0; };
  for (const evento of ["wheel", "touchstart", "pointerdown", "keydown"]) {
    m.addEventListener(evento, apagar, { passive: true });
  }
}

function guardarRolagem() {
  const m = $("#principal");
  if (!m) return null;
  const pagina = identidadeDaPagina();
  const mesma = pagina === PAGINA_ROLADA;
  PAGINA_ROLADA = pagina;
  /* Página outra: o alvo é o topo, EXPLÍCITO, e o pendente da página anterior
   * morre com ela. Deixar por conta do grampo do navegador é o que produzia o
   * `scrollTop=100` da aba curta. */
  if (!mesma) { ROLAGEM_PENDENTE = 0; return { topo: 0, presas: 0 }; }
  return {
    topo: Math.max(m.scrollTop, ROLAGEM_PENDENTE),
    presas: document.querySelectorAll("#conteudo .previa-bloco.presa").length,
  };
}

function devolverRolagem(guardado) {
  const m = $("#principal");
  if (!m || !guardado) return;
  if (guardado.presas) {
    const faixas = document.querySelectorAll("#conteudo .previa-bloco");
    for (let i = 0; i < guardado.presas && i < faixas.length; i++) {
      presilha(faixas[i], true);
    }
  }
  m.scrollTop = guardado.topo;
  /* Não alcançou: a página ainda está baixa (a galeria pintou vazia, as
   * miniaturas não chegaram). Fica pendente para a pintura seguinte. */
  ROLAGEM_PENDENTE = m.scrollTop < guardado.topo - 1 ? guardado.topo : 0;
}

/* «Dia e noite» tinha três agendas para o mesmo conceito, em seis cartões
 * soltos: a noite do gato (dois campos vazios, `--:--`, enquanto a Início dizia
 * «das 18:00 às 07:00»), a do tema claro (dois deslizantes que diziam só «como
 * está») e a da imagem escura (18:00 e 07:00).
 *
 * As três janelas saem das mesmas regras que os scripts aplicam, e cada uma
 * cita a sua dona. */
const HORA_OK = /^([01]?\d|2[0-3]):[0-5]\d$/;
const doisDigitos = (h) => String(h).padStart(5, "0");
const minutosDe = (h) => { const [a, b] = String(h).split(":"); return Number(a) * 60 + Number(b); };

function valeDaChave(chave) {
  const item = ESQUEMA.chaves.find((x) => x.chave === chave);
  return item ? String(valorEmVigor(item) ?? "") : "";
}

/* A noite do gato do dock e do terminal: o `meow_noite_janela` do
 * `lib/noite.sh`, degrau por degrau — `NOITE_*` (as DUAS, ou nenhuma), a janela
 * que o controle do modo de leitura guarda (o servidor a lê no CosmicComp,
 * `noite_do_applet`), `WALLPAPER_NOITE_*`, e 18:00–07:00. */
function janelaDoGato(ler) {
  const vale = (c) => {
    const v = ler ? ler(c) : undefined;
    return v === undefined || v === null ? valeDaChave(c) : String(v);
  };
  const ni = vale("NOITE_INICIO"), nf = vale("NOITE_FIM");
  if (HORA_OK.test(ni) && HORA_OK.test(nf)) return { ini: doisDigitos(ni), fim: doisDigitos(nf), fonte: "conf" };
  const ap = ESQUEMA.noite_do_applet;
  if (ap && HORA_OK.test(ap.ini) && HORA_OK.test(ap.fim)) return { ini: ap.ini, fim: ap.fim, fonte: "applet" };
  const pi = vale("WALLPAPER_NOITE_INICIO"), pf = vale("WALLPAPER_NOITE_FIM");
  if (HORA_OK.test(pi) && HORA_OK.test(pf)) return { ini: doisDigitos(pi), fim: doisDigitos(pf), fonte: "parede" };
  return { ini: "18:00", fim: "07:00", fonte: "padrao" };
}

/* A noite do tema: o escuro vai do fim do claro ao começo dele, em horas
 * cheias (`modo_desejado`, bin/meow). */
function janelaDoTema() {
  const hora = (chave) => {
    const item = ESQUEMA.chaves.find((x) => x.chave === chave);
    const v = item ? String(valorEmVigor(item) ?? "") : "";
    return { h: Number(v !== "" ? v : (item && item.vazio_vale) || 0), herdado: v === "" };
  };
  const de = hora("MODO_AUTO_CLARO_DE"), ate = hora("MODO_AUTO_CLARO_ATE");
  return { ini: `${String(ate.h).padStart(2, "0")}:00`, fim: `${String(de.h).padStart(2, "0")}:00`,
           herdado: de.herdado && ate.herdado, ativo: valeDaChave("MODO") === "auto" };
}

/* A noite do carrossel: o `e_noite` do `wallpaper.sh`, sobre as
 * `WALLPAPER_NOITE_*` (vazias, 18:00 e 07:00). Só vale com «Separar imagens de
 * dia e de noite» ligado. */
function janelaDaImagem() {
  const pi = valeDaChave("WALLPAPER_NOITE_INICIO"), pf = valeDaChave("WALLPAPER_NOITE_FIM");
  return { ini: HORA_OK.test(pi) ? doisDigitos(pi) : "18:00", fim: HORA_OK.test(pf) ? doisDigitos(pf) : "07:00",
           ativo: valeDaChave("WALLPAPER_NOITE") !== "nao" };
}

/* O que um campo de hora VAZIO vale agora, e de onde vem — ou, num campo
 * preenchido que não vale, por quê. `null` quando o campo diz a verdade
 * sozinho. */
function horaHerdada(item) {
  if (item.chave !== "NOITE_INICIO" && item.chave !== "NOITE_FIM") return null;
  const j = janelaDoGato();
  if (j.fonte === "conf") return null;
  const proprio = valorEmVigor(item);
  const ponta = item.chave === "NOITE_INICIO" ? j.ini : j.fim;
  const balao = { applet: "Segue a janela do controle do modo de leitura",
                  parede: "Segue a imagem escura", padrao: "Padrão" }[j.fonte];
  /* Preenchida com a irmã vazia ela não vale: o `meow_noite_janela` pede as
   * duas pontas, e com uma só cai no degrau seguinte inteiro. */
  if (proprio !== "") {
    const irma = item.chave === "NOITE_INICIO" ? "A noite termina às" : "A noite começa às";
    return { anulada: true, balao: `Só vale com «${irma}» preenchida` };
  }
  return { hora: ponta, balao };
}

const NS_RELOGIO = "http://www.w3.org/2000/svg";
function noSvg(tag, attrs) {
  const n = document.createElementNS(NS_RELOGIO, tag);
  for (const [k, v] of Object.entries(attrs || {})) n.setAttribute(k, String(v));
  return n;
}

/* As três linhas, na ordem dos anéis de fora para dentro. A cor é o que liga
 * o anel à linha; o ícone, o que diz o que ela troca. */
const LINHAS_DA_NOITE = [
  { id: "gato", nome: "O gato do dock e do terminal", cor: "var(--mauve, var(--accent))",
    chaves: ["NOITE_INICIO", "NOITE_FIM"],
    icone: '<path d="M3 13.5V4.5l3 2.5h4l3-2.5v9z"/><path d="M6.5 10h.01M9.5 10h.01"/>' },
  { id: "tema", nome: "O tema claro ou escuro", cor: "var(--blue, var(--accent))",
    chaves: ["MODO_AUTO_CLARO_ATE", "MODO_AUTO_CLARO_DE"],
    icone: '<circle cx="8" cy="8" r="5.5"/><path d="M8 2.5a5.5 5.5 0 0 1 0 11z" fill="currentColor"/>' },
  { id: "imagem", nome: "A imagem do carrossel", cor: "var(--teal, var(--accent))",
    chaves: ["WALLPAPER_NOITE_INICIO", "WALLPAPER_NOITE_FIM"],
    icone: SELO_ICONES.foto },
];

function estadoDasLinhas() {
  const gato = janelaDoGato(), tema = janelaDoTema(), imagem = janelaDaImagem();
  return {
    gato: { ...gato, herdado: gato.fonte !== "conf", ativo: true },
    tema, imagem,
  };
}

function relogioDaNoite() {
  const est = estadoDasLinhas();
  const C = 64;
  const svg = noSvg("svg", { viewBox: "0 0 128 128", class: "relogio-noite-svg", role: "img",
    "aria-label": `Noite do gato ${est.gato.ini}–${est.gato.fim}, do tema ${est.tema.ini}–${est.tema.fim}, `
                + `da imagem ${est.imagem.ini}–${est.imagem.fim}` });
  const ponto = (r, min) => {
    const a = (min / 1440) * 2 * Math.PI - Math.PI / 2;
    return [C + r * Math.cos(a), C + r * Math.sin(a)];
  };
  LINHAS_DA_NOITE.forEach((l, i) => {
    const r = 48 - i * 11;
    const e = est[l.id];
    const g = noSvg("g", { class: "anel" + (e.ativo ? "" : " parado") + (e.herdado ? " herdado" : ""),
                           style: `color:${l.cor}`, "data-linha": l.id });
    g.append(noSvg("circle", { cx: C, cy: C, r, class: "trilha" }));
    const a = minutosDe(e.ini), b = minutosDe(e.fim);
    if (a === b) {
      g.append(noSvg("circle", { cx: C, cy: C, r, class: "arco" }));
    } else {
      const dur = ((b - a) % 1440 + 1440) % 1440;
      const [x0, y0] = ponto(r, a), [x1, y1] = ponto(r, b);
      g.append(noSvg("path", { class: "arco",
        d: `M${x0.toFixed(2)} ${y0.toFixed(2)} A${r} ${r} 0 ${dur > 720 ? 1 : 0} 1 ${x1.toFixed(2)} ${y1.toFixed(2)}` }));
    }
    svg.append(g);
  });
  /* As quatro horas que se leem num mostrador: 0, 6, 12 e 18. */
  for (const h of [0, 6, 12, 18]) {
    const [x, y] = ponto(59, h * 60);
    const t = noSvg("text", { x: x.toFixed(1), y: (y + 2.4).toFixed(1), class: "hora-marca" });
    t.textContent = String(h);
    svg.append(t);
  }
  /* O ponteiro é a hora de agora, lida do relógio de quem olha. */
  const agora = new Date();
  const [px, py] = ponto(54, agora.getHours() * 60 + agora.getMinutes());
  const [qx, qy] = ponto(12, agora.getHours() * 60 + agora.getMinutes());
  svg.append(noSvg("line", { x1: qx.toFixed(2), y1: qy.toFixed(2), x2: px.toFixed(2), y2: py.toFixed(2),
                             class: "ponteiro" }));
  svg.append(noSvg("circle", { cx: C, cy: C, r: 2, class: "eixo" }));

  const caixa = elemento("div", { class: "relogio-noite" }, [svg]);
  /* Os números, para quem quer conferir, atrás do `?` do desenho. */
  const fonteGato = { conf: "as duas linhas do gato", applet: "a janela do controle do modo de leitura",
                      parede: "a imagem escura", padrao: "o padrão" }[est.gato.fonte];
  const dica = dicaDoDesenho("relogio-noite",
    `Gato: das ${est.gato.ini} às ${est.gato.fim} (${fonteGato}). `
    + `Tema escuro: das ${est.tema.ini} às ${est.tema.fim}`
    + (est.tema.ativo ? "" : ", só com «Claro ou escuro» em Automático") + ". "
    + `Imagem escura: das ${est.imagem.ini} às ${est.imagem.fim}`
    + (est.imagem.ativo ? "" : ", só com «Separar imagens de dia e de noite» ligado") + ". "
    + "O ponteiro é a hora de agora.");
  if (dica) { caixa.classList.add("com-dica"); caixa.append(...dica); }
  return caixa;
}

/* O ícone que abre cada linha, na cor do anel dela. Apagado quando a linha
 * não está valendo, e o porquê no balão. */
function iconeDaLinhaDaNoite(linha, numero) {
  const e = estadoDasLinhas()[linha.id];
  const porque = linha.id === "tema" ? " — só com «Claro ou escuro» em Automático"
    : " — só com «Separar imagens de dia e de noite» ligado";
  const el = elemento("span", {
    class: "linha-noite-icone" + (e.ativo ? "" : " parado"),
    style: `color:${linha.cor}`, "data-linha": String(numero), role: "img",
    "aria-label": linha.nome + (e.ativo ? "" : porque),
  });
  el.insertAdjacentHTML("afterbegin", '<svg viewBox="0 0 16 16" aria-hidden="true" focusable="false">'
    + linha.icone + "</svg>");
  porBalao(el, linha.nome + (e.ativo ? "" : porque));
  return el;
}

/* A moldura da noite: o relógio à esquerda, e uma linha por anel — o ícone, o
 * começo e o fim. */
function encherMolduraDaNoite(m, g) {
  m.classList.add("decisao-relogio");
  const relogio = relogioDaNoite();
  m.append(relogio);
  LINHAS_DA_NOITE.forEach((l, i) => {
    const itens = l.chaves.map((c) => g.itens.find((x) => x.chave === c));
    if (!itens.some(Boolean)) return;
    m.append(iconeDaLinhaDaNoite(l, i + 1));
    itens.forEach((item, j) => {
      if (!item) return;
      const cartao = montarCartao(item);
      cartao.dataset.linha = String(i + 1);
      cartao.dataset.ponta = j === 0 ? "ini" : "fim";
      m.append(cartao);
      /* O deslizante do tema repinta o relógio sob o dedo (`repintarPrevia`). */
      PREVIA_VIVA.set(item.chave, { relogio: true, alvo: relogio });
    });
  });
}

/* Em «Cor e tela», «Theme pack», «Variante do tema» e «Claro ou escuro» eram
 * três cartões soltos na grade, separados por um hash de commit e um
 * repositório, e os três respondem a mesma pergunta: com que tema a máquina se
 * veste.
 *
 * A LISTA MORA AQUI, E NÃO NO `meow.conf.exemplo`: o que é uma decisão na tela
 * é assunto de arranjo da página, e o arquivo descreve chaves. */
const DECISOES = [
  { id: "tema", nome: "Tema", chaves: ["PACK", "FLAVOR", "MODO"] },
  /* Os três pares de horário de «Dia e noite» numa moldura com o relógio: uma
   * linha por coisa que a noite troca, o começo da noite numa coluna e o fim
   * na outra. */
  { id: "noite", nome: "Noite", relogio: true,
    chaves: LINHAS_DA_NOITE.flatMap((l) => l.chaves) },
  /* QUANDO: ligar no horário abre a moldura, e o começo, o fim e a virada só
   * aparecem com ele em «Sim» — com «Não» ou vazio o relógio não liga nada, e
   * três horas de um agendamento desligado eram três controles sem efeito. */
  { id: "leitura-quando", nome: "Quando a tela esquenta",
    chaves: ["LEITURA_AGENDA", "LEITURA_HORARIO_INICIO", "LEITURA_HORARIO_FIM", "LEITURA_RAMPA_MIN"],
    modo: { chave: "LEITURA_AGENDA",
            por: { sim: ["LEITURA_HORARIO_INICIO", "LEITURA_HORARIO_FIM", "LEITURA_RAMPA_MIN"] } } },
  { id: "leitura-quanto", nome: "Quanto a tela esquenta",
    chaves: ["LEITURA_TEMPERATURA", "LEITURA_TEXTURA"] },
  /* «Descolado: Sim» e «Distância: 0» moravam em cartões distantes e diziam o
   * contrário um do outro sem que a tela mostrasse a ligação: a distância só
   * existe com a barra descolada (o compositor a descarta com ela colada), e
   * descolada com 0 px fica encostada. */
  { id: "painel", nome: "Painel", chaves: ["FORMA_PAINEL_SOLTO", "FORMA_MARGEM_PAINEL", "FORMA_PAINEL_ILHA"] },
  { id: "dock", nome: "Dock", chaves: ["FORMA_DOCK_SOLTO", "FORMA_MARGEM_DOCK", "FORMA_DOCK_ILHA"] },
  /* Eram seis cartões entrelaçados para o dock (qual gato, troca sozinho,
   * como é escolhido, de dia, de noite, de quanto em quanto), três deles com
   * a caixa «Quem manda é…» explicando por que não valiam. */
  /*   (item 23; decisão 25). «Pôr um gato no dock» e «Passar ao próximo gato»
   *   eram cartões soltos, apagados em dois dos três modos. Agora cada uma
   *   aparece dentro da moldura, no modo em que ela faz alguma coisa: o
   *   `acoes` diz qual, como o `por` diz as chaves.] */
  { id: "gato-dock", nome: "Gato do dock",
    chaves: ["LOGO_MODO", "LOGO_DIA", "LOGO_NOITE", "LOGO_INTERVALO", "LOGO"],
    modo: { chave: "LOGO_MODO",
            por: { hora: ["LOGO_DIA", "LOGO_NOITE"], rotacao: ["LOGO_INTERVALO"], fixo: ["LOGO"] } },
    acoes: { fixo: ["logo_trocar"], rotacao: ["logo_girar"] } },
  /* O mesmo no terminal: o gato no lugar do logo, o modo, e só o que o modo
   * usa. Em «espelho» o terminal mostra o gato que o dock não está mostrando,
   * e não há o que escolher além do modo. */
  { id: "gato-terminal", nome: "Gato do terminal",
    chaves: ["FASTFETCH_LOGO", "FASTFETCH_LOGO_MODO", "FASTFETCH_LOGO_DIA",
             "FASTFETCH_LOGO_NOITE", "FASTFETCH_LOGO_GATO"],
    modo: { chave: "FASTFETCH_LOGO_MODO",
            por: { espelho: [], hora: ["FASTFETCH_LOGO_DIA", "FASTFETCH_LOGO_NOITE"],
                   fixo: ["FASTFETCH_LOGO_GATO"] } } },
];

/* O modo em vigor de uma decisão com `modo`. */
function modoEmVigor(decisao) {
  if (!decisao.modo) return "";
  const modoItem = ESQUEMA.chaves.find((k) => k.chave === decisao.modo.chave);
  return modoItem ? (valorEmVigor(modoItem) || modoItem.valendo_agora || "") : "";
}
/* As ações que moram dentro de uma moldura (o `acoes` das `DECISOES`): fora
 * da busca, elas não ganham cartão no bloco de ações. */
const ACOES_EM_MOLDURA = new Set(DECISOES.flatMap((d) => Object.values(d.acoes || {}).flat()));

/* A chave aparece na moldura com o modo em vigor? As que nenhum modo cita
 * aparecem sempre; as citadas, só no modo que as usa. */
function mostraNoModo(decisao, chave) {
  if (!decisao.modo) return true;
  const listas = Object.values(decisao.modo.por);
  if (!listas.some((l) => l.includes(chave))) return true;
  const modoItem = ESQUEMA.chaves.find((k) => k.chave === decisao.modo.chave);
  /* Com `LOGO_MODO=""` a moldura procurava o modo vazio e não mostrava gato
   * nenhum; o servidor manda o modo efetivo (`_modo_do_gato`, pelo `logo.sh
   * modo`) no `valendo_agora` da chave. */
  const vale = modoItem ? (valorEmVigor(modoItem) || modoItem.valendo_agora || "") : "";
  return (decisao.modo.por[vale] || []).includes(chave);
}

/* Ele fica recolhido num «⋯» ao fim do bloco: a página mostra o que se escolhe,
 * e o resto está a um clique, gravando a mesma chave.
 *
 * A página se redesenha a cada escolha, e um «⋯» que fechasse a cada letra
 * digitada no campo de dentro seria um controle impossível de usar. */
const TECNICOS_ABERTOS = new Set();
/* A régua é a `natureza` que o servidor declara para cada ação, e não uma lista
 * de rótulos: uma ação nova de «mostrar» nasce no lugar certo. */
const PAGINAS_COM_ACOES_TECNICAS = new Set(["Painel e dock", "Papel de parede",
                                            "Logo do sistema", "Modo de leitura",
                                            "Áreas de trabalho", "Lançadores e jogos",
                                            "Manutenção", "Instalação"]);
const NATUREZAS_TECNICAS = new Set(["mostrar", "aplicar", "reciclar", "baixar"]);
function acaoTecnica(assunto, acao) {
  return (PAGINAS_COM_ACOES_TECNICAS.has(assunto) && NATUREZAS_TECNICAS.has(acao.natureza))
    || !!acao.tecnica;
}
function ajustesTecnicos(assunto, g, itens) {
  /* O TIPO ENTRA NO NOME DO «⋯»: o bloco de ajustes e o de ações de uma
   * página costumam ter o mesmo `g.nome`, e com o mesmo id abrir um abria os
   * dois na pintura seguinte. */
  const id = assunto + "·" + g.nome + "·" + g.tipo;
  const acoes = g.tipo === "acoes";
  const nome = acoes ? "Ações técnicas" : "Ajustes técnicos";
  const desenho = elemento("span", { class: "tecnicos-icone", "aria-hidden": "true" });
  desenho.innerHTML = '<svg viewBox="0 0 48 48" width="15" height="15" fill="none" '
    + 'stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">'
    + (acoes ? '<path d="M16 10l22 14l-22 14z"/>'
       : '<path d="M8 14h20m8 0h4M8 34h4m8 0h20"/><circle cx="32" cy="14" r="4"/><circle cx="16" cy="34" r="4"/>')
    + "</svg>";
  const caixa = elemento("details", { class: "ajustes-tecnicos" }, [
    elemento("summary", { title: nome }, [
      desenho,
      elemento("span", { class: "tecnicos-glifo", "aria-hidden": "true", texto: "⋯" }),
      elemento("span", { class: "so-leitor", texto: " " + nome }),
    ]),
  ]);
  if (TECNICOS_ABERTOS.has(id)) caixa.open = true;
  caixa.addEventListener("toggle", () => {
    if (caixa.open) TECNICOS_ABERTOS.add(id);
    else TECNICOS_ABERTOS.delete(id);
  });
  const grade = elemento("div", { class: "grade" });
  for (const item of itens) grade.append(acoes ? montarAcao(item) : montarCartao(item));
  caixa.append(grade);
  return caixa;
}

function render() {
  /* A figura da seção sem chaves espera a primeira grade. */
  let figuraNaGrade = null;
  /* Os nós da passagem anterior morreram com ela. Um registro que sobrevive
   * ao `render` guarda referência para árvore descartada, e o repintar acha um
   * nó sem pai — silencioso, e cada vez mais caro. */
  PREVIA_VIVA.clear();
  const ancora = ancoraDoFoco();
  const rolagem = guardarRolagem();
  montarTrilho();
  const alvo = $("#conteudo");
  alvo.replaceChildren();
  ACERVO_DESENHADO.clear();
  const busca = semAcento($("#busca").value.trim());
  /* O acervo que a página põe no cabeçalho não se repete num cartão. Na busca
   * o cabeçalho é só o título, e o botão volta ao primeiro cartão. */
  if (!busca && ACERVO_DO_ASSUNTO[ABA]) ACERVO_DESENHADO.add(ACERVO_DO_ASSUNTO[ABA].tipo);

  /* A busca atravessa TODOS os grupos, e é assim que uma página de cem chaves
   * deixa de exigir que ela lembre em qual aba a chave mora. Sem busca, mostra
   * só a aba escolhida. */
  const grupos = busca
    ? GRUPOS.filter((g) => g.tipo !== "home")
        .map((g) => ({
          ...g,
          /* O filtro achava certo e ordenava pelo arquivo, então buscar «som»
           * devolvia 23 cartões com «Som ao mudar o volume» em ÚLTIMO — atrás
           * de 22 que só citam a palavra na ajuda longa.
           *
           * A régua não é nova: `ondeCasa` já devolve null exatamente quando
           * todas as palavras aparecem em texto visível (título + frase +
           * rótulo), e é o que a lupa usa para decidir se explica ONDE casou. */
          itens: g.itens.filter((i) => casa(i, busca))
            .sort((a, b) => (ondeCasa(a, busca) === null ? 0 : 1)
                          - (ondeCasa(b, busca) === null ? 0 : 1)),
        })).filter((g) => g.itens.length)
        /* Ordenar só dentro do grupo não bastava: os grupos saem na ordem das
         * páginas, e «Som ao mudar o volume» mora em Manutenção, que é das
         * últimas.
         *
         * Um grupo vale pelo melhor item que ele tem — se algum dos seus casa
         * no texto à vista, o grupo inteiro sobe. */
        .sort((a, b) => {
          const visivel = (g) => g.itens.some((i) => ondeCasa(i, busca) === null);
          return (visivel(a) ? 0 : 1) - (visivel(b) ? 0 : 1);
        })
    : GRUPOS.filter((g) => chaveDeAba(g) === ABA);

  if (!grupos.length) {
    alvo.append(elemento("p", { class: "vazio-msg", texto: `Nada casa com “${$("#busca").value}”.` }));
    /* Este `return` corta o `devolverRolagem` do fim, e a frase tem de ficar À
     * VISTA: sem isto, uma busca digitada com a página rolada deixaria a única
     * linha da tela lá em cima, fora do campo de visão. */
    ROLAGEM_PENDENTE = 0;
    const rolador = $("#principal");
    if (rolador) rolador.scrollTop = 0;
    return;
  }

  /* As quatro pílulas de fundo só aparecem onde há imagem para pôr sobre elas —
   * numa aba de texto puro seriam quatro botões que não fazem nada visível. */
  if (grupos.some((g) => g.nome === PAGINA_DO_FUNDO)) alvo.append(barraDeFundos());
  let ultimoAssunto = null;
  let barraDesenhada = false;   // o par painel+dock sai uma vez por página

  /* Os ajustes ficam a uma rolagem curta, e as ações técnicas no «⋯». */
  const PESO = { galeria: -1, chaves: 0, acoes: 1, apps: 2, jogos: 2, folhas: 3 };
  /* `sort` ESTÁVEL E POR SEÇÃO: devolver 0 entre grupos de seções diferentes
   * preserva a ordem que o servidor mandou (o `sort` do JavaScript é estável
   * desde 2019), então a sequência das seções na página não muda — só a ordem
   * DENTRO de cada uma. */
  const ordenados = grupos.slice().sort((a, b) => {
    if (a.tipo === "home" || b.tipo === "home") return 0;
    if (assuntoDe(a) !== assuntoDe(b)) return 0;
    return (PESO[a.tipo] ?? 9) - (PESO[b.tipo] ?? 9);
  });
  for (const g of ordenados) {
    /* A home desenha o próprio cabeçalho: um `h2` "Início" acima dela seria o
     * título de uma tela que já se apresenta. */
    /* Registrar "Início" no `MEOW_PREVIAS` sem esta linha não põe desenho
     * nenhum na tela. */
    if (g.tipo === "home") {
      alvo.append(montarHome());
      const soloDaHome = desenhoDaSecaoSemChaves(g.nome);
      if (soloDaHome) alvo.append(soloDaHome);
      continue;
    }
    /* TODA ABA TEM TÍTULO — e catorze delas não tinham.
     *   A condição era `if (busca || g.tipo !== "chaves")`: as abas de chaves
     *   abriam direto na frase de descrição, com um degrau de tipografia que
     *   simplesmente não existia ali. O nome da aba estava no menu, e o menu
     *   está sempre visível — mas quem clicou já não olha o menu, e uma tela
     *   sem título é uma tela sem lugar. */
    /* Uma página de assunto pode ter a galeria, dois ou três blocos de ajuste e
     * as ações — quatro grupos, um título.
     *
     * A frase da seção repete a do menu de propósito: no menu ela serve para
     * escolher onde entrar, aqui para confirmar que se entrou no lugar certo. */
    const assunto = assuntoDe(g);
    if (assunto !== ultimoAssunto) {
      ultimoAssunto = assunto;
      /* O título, a descrição, a nota e o acervo da página viraram UMA linha
       * de cabeçalho. Ver `cabecalhoDePagina`. */
      alvo.append(cabecalhoDePagina(assunto, busca));
      if (!busca) {
        /* As pastilhas da nota (os nomes dos lugares) vêm logo depois do
         * cabeçalho e antes de tudo o mais: elas respondem "onde isto aparece
         * na minha tela?", que é a primeira pergunta de quem abre a aba. */
        const nota = notaDoAssunto(assunto);
        if (nota) alvo.append(nota);
        /* `parDePrevias` só roda sobre um grupo de CHAVES, então "Instalação" e
         * "Atualização" — que são só ações — nunca chegavam a ter desenho, por
         * mais que alguém registrasse um.
         *
         * Aqui o desenho é da SEÇÃO e não de um bloco: não há valores para ler,
         * então não há par antes/depois nem tempo real. */
        figuraNaGrade = desenhoDaSecaoSemChaves(assunto);
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
     * e não uma miniatura repetida dentro de cada cartão. */
    /* Uma frase de vinte e duas palavras para explicar um traço de dois pixels
     * é a interface pedindo desculpa por si mesma. O traço fica; quem quiser o
     * texto abre o "Por quê" do cartão. */

    /* O par painel + dock, uma vez, antes dos controles da seção. Os dois
     * juntos porque as chaves vêm em par (`FORMA_RAIO_PAINEL` e
     * `FORMA_RAIO_DOCK` moram na mesma seção) e comparar é metade da escolha.
     *
     * O desenho é do assunto, não do bloco. */
    if (!busca && !barraDesenhada && (g.itens || []).some((i) => i.previa === "barra")) {
      barraDesenhada = true;
      /* Estava certa: o `sticky` mora na `.previa-bloco`, e a FORMA é a única
       * prévia que não passa pelo `parDePrevias` — ela tem mock próprio,
       * montado aqui. */
      const caixa = elemento("div", { class: "previa-bloco" });
      const par = elemento("div", { class: "grade-barras par-forma" });
      pintarForma(par);
      caixa.append(par);
      alvo.append(caixa);
      /* A FORMA É O BLOCO QUE ELA MAIS MEXE, e era o único sem tempo real: o
       * desenho dele não vem do `MEOW_PREVIAS`, então o registro por bloco não
       * o alcançava. */
      for (const chave of CHAVES_DO_MOCK) PREVIA_VIVA.set(chave, { forma: par, alvo: par });
    }
    /* O PAR ANTES/DEPOIS ABRE O BLOCO, e é por bloco mesmo: o desenho responde
     * às chaves DAQUELE bloco, e pô-lo no alto da página misturaria a barra com
     * o relógio e a música. */
    /* A `.previa-bloco` era filha direta do `#conteudo`, e o `sticky` dela
     * valia para a página inteira: em «Ícones», rolando até a grade de
     * aplicativos, a tira do desenho das pastas continuava presa no alto, por
     * cima dos nomes dos programas e das ações — o comentário do CSS sempre
     * prometeu que ela «sai junto com a seção», e ela não saía. */
    let destino = alvo;
    /* O bloco cujo desenho É o relógio da moldura não ganha o desenho do topo:
     * seriam dois relógios da mesma noite, um em cima do outro. */
    const comRelogio = DECISOES.some((d) => d.relogio
      && g.itens.some((i) => d.chaves.includes(i.chave)));
    if (!busca && !comRelogio) {
      const previa = parDePrevias(g);
      if (previa) {
        destino = elemento("section", { class: "secao-com-previa" });
        alvo.append(destino);
        destino.append(previa);
        /* Uma entrada por chave do bloco, todas apontando para o mesmo nó: o
         * deslizante conhece a própria chave e nada mais, e é por ela que ele
         * acha o desenho que precisa repintar. */
        for (const item of g.itens) PREVIA_VIVA.set(item.chave, { g: g, alvo: previa });
      }
    }
    const grade = elemento("div", { class: "grade" });
    if (figuraNaGrade) { grade.append(figuraNaGrade); figuraNaGrade = null; }
    /* Os ajustes técnicos (`[avancado]`) vão para o «⋯» do fim do bloco, e os
     * que formam UMA decisão (`DECISOES`) para uma moldura só. */
    const tecnicos = [];
    const molduras = new Map();
    for (const item of g.itens) {
      /* Ação `oculta` não é cartão: o argumento dela é uma imagem, e a galeria
       * já a oferece no lugar certo (o botão embaixo de cada foto). */
      if (g.tipo === "acoes" && item.oculta) continue;
      /* Do par «ver / aplicar» fica o aplicar: o ver é o «Ver sem mudar» dele. */
      if (g.tipo === "acoes" && !busca && item.par) continue;
      /* E a que mora na moldura de um modo. */
      if (g.tipo === "acoes" && !busca && ACOES_EM_MOLDURA.has(item.id)) continue;
      if (g.tipo === "acoes") {
        if (!busca && acaoTecnica(assunto, item)) tecnicos.push(item);
        else grade.append(montarAcao(item));
        continue;
      }
      if (!busca && item.avancado) { tecnicos.push(item); continue; }
      const decisao = !busca && DECISOES.find((d) => d.chaves.includes(item.chave));
      if (decisao) {
        if (!molduras.has(decisao.id)) {
          const m = elemento("div", { class: "decisao", "data-decisao": decisao.id,
                                      role: "group", "aria-label": decisao.nome });
          molduras.set(decisao.id, m);
          grade.append(m);
        }
        continue;
      }
      grade.append(montarCartao(item));
    }
    /* A moldura nasce no lugar do primeiro dos seus ajustes e se enche na
     * ordem da decisão, não na do arquivo: o pack, depois a variante dele,
     * depois o claro ou escuro. */
    for (const [id, m] of molduras) {
      const d = DECISOES.find((x) => x.id === id);
      if (d.relogio) { encherMolduraDaNoite(m, g); continue; }
      for (const chave of d.chaves) {
        const item = g.itens.find((i) => i.chave === chave);
        if (item && mostraNoModo(d, chave)) m.append(montarCartao(item));
      }
      /* As ações do modo em vigor, dentro da moldura. */
      for (const id of ((d.acoes || {})[modoEmVigor(d)] || [])) {
        const acao = (ESQUEMA.acoes || []).find((a) => a.id === id);
        if (acao) m.append(montarAcao(acao));
      }
      m.style.setProperty("--cartoes", String(m.childElementCount));
    }
    if (grade.childElementCount) destino.append(grade);
    if (tecnicos.length) destino.append(ajustesTecnicos(assunto, g, tecnicos));

    /* Ela abria a seção, e na tela isso punha DUAS prévias em sequência: os
     * ícones que estão instalados agora e, logo abaixo, o desenho do que as
     * chaves fazem. */
  }

  /* Fora do laço ela é uma só, e cai onde o parágrafo acima diz que ela tem de
   * cair: depois de tudo. */
  if (!busca && GRUPOS.some((g) => g.nome === GRUPO_ICONES && assuntoDe(g) === ABA)) {
    alvo.append(elemento("h3", {
      class: "subsecao-titulo",
      /* "SÓ MUDA DEPOIS DE «RECONSTRUIR»" SAIU: o «Salvar e aplicar» roda o
       * instalador inteiro, que reconstrói o tema, e a grade é relida quando
       * ele termina. */
      texto: "No disco agora",
      title: "O tema de ícones como está instalado",
    }));
    alvo.append(gradeDeIcones());
  }
  grudarPrevias();
  afastarDicasDoTraco();
  pintarGatosEmCelulas($("#conteudo"));
  devolverFoco(ancora);
  assentarGrades();
  devolverRolagem(rolagem);
  /* `nearest` não sacode a página quando ela já está à vista. */
  const ativa = document.querySelector('#trilho button[aria-current="true"]');
  if (ativa && ativa.scrollIntoView) {
    const t = $("#trilho").getBoundingClientRect();
    const b = ativa.getBoundingClientRect();
    if (b.top < t.top || b.bottom > t.bottom || b.left < t.left || b.right > t.right) {
      ativa.scrollIntoView({ block: "nearest", inline: "nearest" });
    }
  }
}

/* A cura é na grade de todas as páginas, e não numa página: com mais de uma
 * coluna, a grade vira ALVENARIA. */
const ALVENARIA_PASSO = 4;
const ALVENARIA_EMPATE = 64;
let OBSERVADOR_GRADES = null;
/* O QUE ESTÁ À VISTA FICA À VISTA: a alvenaria refeita depois da pintura (um
 * desenho que chegou, a janela que mudou) muda os cartões de lugar, e o
 * cartão a que a Início levou (`.chegou`), ou o que tem o foco, saía da
 * janela. */
function assentarComAncora() {
  const m = $("#principal");
  const foco = document.activeElement;
  const ancora = document.querySelector("#conteudo .grade > .chegou")
    || (foco && foco.closest && foco.closest("#conteudo .grade > *"));
  const antes = ancora ? ancora.getBoundingClientRect().top : null;
  assentarGrades();
  if (m && ancora && ancora.isConnected) m.scrollTop += ancora.getBoundingClientRect().top - antes;
}
function assentarGrades() {
  if (typeof ResizeObserver === "function" && !OBSERVADOR_GRADES) {
    let pedido = 0;
    OBSERVADOR_GRADES = new ResizeObserver(() => {
      cancelAnimationFrame(pedido);
      pedido = requestAnimationFrame(assentarComAncora);
    });
    addEventListener("resize", assentarComAncora);
  }
  for (const g of document.querySelectorAll("#conteudo .grade")) {
    const filhos = [...g.children];
    for (const c of filhos) { c.style.gridColumn = ""; c.style.gridRow = ""; c.style.minHeight = ""; }
    const colunas = getComputedStyle(g).gridTemplateColumns.split(" ").filter(Boolean).length;
    g.classList.toggle("alvenaria", colunas > 1);
    if (colunas < 2) continue;
    const vao = parseFloat(getComputedStyle(g).columnGap) * .6 || 18;
    const fundo = new Array(colunas).fill(1);
    const postos = [];
    for (const c of filhos) {
      if (OBSERVADOR_GRADES) OBSERVADOR_GRADES.observe(c);
      const alto = c.getBoundingClientRect().height;
      if (!alto) continue;
      const linhas = Math.max(1, Math.ceil((alto + vao) / ALVENARIA_PASSO));
      const largo = getComputedStyle(c).gridColumnEnd === "-1"
        || c.matches(".decisao, .escolha-icone, .escolha-jogo, .pack.aberto");
      if (largo) {
        const de = Math.max(...fundo);
        c.style.gridColumn = "1 / -1";
        c.style.gridRow = `${de} / span ${linhas}`;
        fundo.fill(de + linhas);
        continue;
      }
      let k = 0;
      for (let i = 1; i < colunas; i++) if (fundo[i] < fundo[k]) k = i;
      const p = { c, k, de: fundo[k], linhas, alto, natural: linhas };
      postos.push(p);
      /* A fileira: os já postos que começam na mesma linha, com nada embaixo,
       * em grupos de quase empate, do mais baixo para o mais alto. */
      const fileira = c.matches(".acao") ? postos.filter((o) => o !== p && o.de === p.de
        && o.c.matches(".acao") && fundo[o.k] === o.de + o.linhas) : [];
      fileira.push(p);
      fileira.sort((a, b) => a.alto - b.alto);
      for (let i = 0; i < fileira.length;) {
        let j = i;
        while (j + 1 < fileira.length && fileira[j + 1].alto - fileira[i].alto <= ALVENARIA_EMPATE) j++;
        const maior = fileira[j];
        for (const o of fileira.slice(i, j + 1)) {
          o.linhas = maior.natural;
          o.c.style.minHeight = o === maior ? "" : `${maior.alto}px`;
          o.c.style.gridRow = `${o.de} / span ${o.linhas}`;
          fundo[o.k] = o.de + o.linhas;
        }
        i = j + 1;
      }
      c.style.gridColumn = String(k + 1);
      c.style.gridRow = `${p.de} / span ${p.linhas}`;
      fundo[k] = p.de + p.linhas;
    }
  }
}

/* Parada no alto da página ela é o desenho inteiro, com legenda — é ali que ela
 * é lida.
 *
 * COMO SE SABE QUE ESTÁ PRESA: `position: sticky` não avisa ninguém, e não há
 * seletor de CSS para "encostou".
 *
 * O observador é UM só, criado na primeira chamada. */
let OBSERVADOR_PREVIA = null;

function grudarPrevias() {
  const raiz = document.getElementById("principal");
  if (!raiz || typeof IntersectionObserver !== "function") return;
  if (!OBSERVADOR_PREVIA) {
    OBSERVADOR_PREVIA = new IntersectionObserver((entradas) => {
      for (const e of entradas) {
        const faixa = e.target.nextElementSibling;
        if (!faixa || !faixa.classList.contains("previa-bloco")) continue;
        /* Encolhida é a faixa cujo lugar de descanso já passou — a sentinela
         * acima do teto do `main`. */
        const acima = e.boundingClientRect.top < (e.rootBounds ? e.rootBounds.top : 0);
        presilha(faixa, !e.isIntersecting && acima);
      }
    }, { root: raiz, threshold: 0 });
  } else {
    OBSERVADOR_PREVIA.disconnect();
  }
  for (const faixa of document.querySelectorAll("#conteudo .previa-bloco")) {
    let sentinela = faixa.previousElementSibling;
    if (!sentinela || !sentinela.classList.contains("sentinela-previa")) {
      sentinela = elemento("div", { class: "sentinela-previa", "aria-hidden": "true" });
      faixa.parentNode.insertBefore(sentinela, faixa);
    }
    OBSERVADOR_PREVIA.observe(sentinela);
  }
  vagaDoConteudo();
}

/* Funcionou e ficou feio: com a faixa presa e a rolagem a 106, sobrava um
 * buraco de 174 px entre a tira do alto e o primeiro cartão — no meio da
 * página, do tamanho de um cartão inteiro, e sem nada dentro.
 *
 * O buraco é inevitável: se a página tem de continuar com 877 px de altura para
 * caber 106 de rolagem, e o conteúdo encolhido só precisa de 703, os 174 de
 * diferença existem em algum lugar. */
function vagaDoConteudo() {
  const c = document.getElementById("conteudo");
  if (!c) return null;
  let v = c.lastElementChild;
  if (!v || !v.classList.contains("vaga-previa")) {
    v = elemento("div", { class: "vaga-previa", "aria-hidden": "true" });
    c.append(v);
  }
  return v;
}

/* Aqui ele sai da própria faixa, uma vez por pintura, e fica guardado no nó.
 *
 * Não há pintura entre a primeira e a última linha, então nada disso aparece
 * na tela. */
function encolhimentoDaFaixa(faixa) {
  if (faixa.dataset.encolhe) return Number(faixa.dataset.encolhe);
  const estava = faixa.classList.contains("presa");
  faixa.classList.add("medindo");
  faixa.classList.remove("presa");
  const solta = faixa.offsetHeight;
  faixa.classList.add("presa");
  const presa = faixa.offsetHeight;
  faixa.classList.toggle("presa", estava);
  faixa.classList.remove("medindo");
  const d = Math.max(0, solta - presa);
  faixa.dataset.encolhe = String(d);
  return d;
}

/* PRENDER E SOLTAR, SEMPRE PELA VAGA. Ver o comentário `.vaga-previa` no
 * `estilo.css`: prender sem devolver a altura à página é o que trancava a
 * rolagem nas abas curtas. Este é o único lugar que põe e tira a classe. */
function presilha(faixa, deve) {
  if (!faixa || deve === faixa.classList.contains("presa")) return;
  /* PRIMEIRO ENGORDA, DEPOIS EMAGRECE — nesta ordem, sempre. Trocar as duas na
   * ordem contrária deixa a página 174 px mais curta entre uma linha e a
   * outra. */
  const m = $("#principal");
  const onde = m ? m.scrollTop : 0;
  const quanto = encolhimentoDaFaixa(faixa);
  const vaga = vagaDoConteudo();
  const tinha = vaga ? (parseFloat(vaga.style.height) || 0) : 0;
  const soma = Math.max(0, deve ? tinha + quanto : tinha - quanto);
  if (deve) {
    if (vaga) vaga.style.height = soma + "px";
    faixa.classList.add("presa");
  } else {
    faixa.classList.remove("presa");
    if (vaga) vaga.style.height = soma ? soma + "px" : "";
  }
  /* O lugar é devolvido aqui, ainda dentro da mesma volta síncrona — nada
   * disso chega a ser pintado. */
  if (m && m.scrollTop !== onde) m.scrollTop = onde;
}

/* Visto ao usar,: digitei "estado da maquina" e a página respondeu "nada casa"
 * — a ação se chama "Estado da máquina", com o `á`.
 *
 * `NFD` separa a letra do sinal, e a faixa `U+0300–U+036F` são exatamente os
 * sinais separados — tirá-los deixa "máquina" e "maquina" iguais dos dois lados
 * da comparação. */
function semAcento(texto) {
  return String(texto)
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLocaleLowerCase("pt-BR");
}

/* A BUSCA ALCANÇA TUDO O QUE A PÁGINA MOSTRA — chave, ação e folha. A causa
 * era este `item.chave ?` na frente: quem não tem `chave` caía no ramo das
 * ações, que lê `rotulo`/`ajuda`/`id` — campos que uma folha não tem. */
/* Um resultado que não mostra o porquê parece sorteio, e a busca perde a
 * confiança que o atalho `/` promete. */
function ondeCasa(item, busca) {
  const visivel = semAcento([tituloDoCartao(item), item.frase, item.rotulo]
    .filter(Boolean).join(" "));
  /* Mesma régua do `casa`: com busca de várias palavras, "visível" é quando
   * TODAS aparecem no texto que está na tela. */
  const palavras = busca.split(/\s+/).filter(Boolean);
  if (palavras.every((p) => visivel.includes(p))) return null;
  const c = item.chave || item.id || "";
  if (semAcento(String(c)).includes(busca)) return `casa pelo nome no arquivo: ${c}`;
  if (semAcento(String(item.ajuda || "")).includes(busca)) return "casa pelo «Por quê» — o ? abre";
  if (semAcento(String(item.valor ?? "")).includes(busca)) return "casa pelo valor atual";
  return "casa por algo escrito no arquivo";
}

/* O mecanismo é o mesmo do «Pular para o conteúdo» do topo: um link invisível
 * até ser focado, logo antes da grade, levando ao primeiro ponto depois dela. */
function pulaGrade(idAlvo, rotulo) {
  return elemento("a", { class: "pular pular-grade", href: "#" + idAlvo, texto: rotulo });
}
function alvoDoPulo(idAlvo) {
  return elemento("div", { id: idAlvo, tabindex: "-1" });
}

/* O arquivo não precisa mudar de vocabulário; a busca precisa conhecer os
 * sinônimos de quem procura. Chaves SEM acento, porque a busca inteira roda em
 * `semAcento`. */
const APELIDOS_DE_BUSCA = {
  quadrada: "canto raio", quadrado: "canto raio", redondo: "canto raio",
  arredondado: "canto raio",
  restaurar: "voltar reverter fabrica", original: "fabrica reverter",
  wallpaper: "papel de parede", fundo: "papel de parede",
  atualizar: "atualizacao", update: "atualizacao",
};

function casa(item, busca) {
  const campos = [
    item.chave, item.frase, item.valor, item.secao, item.subsecao,
    item.rotulo, item.ajuda, item.id, item.arquivo, item.nome, item.caminho,
    tituloDoCartao(item),
  ].filter(Boolean).map((c) => semAcento(String(c)));
  /* POR PALAVRA, COM E-LÓGICO — "terminal gato" dava zero enquanto "gato"
   * sozinho dava 37: a busca exigia a frase contígua. */
  const palavras = busca.split(/\s+/).filter(Boolean);
  return palavras.every((p) => {
    const formas = [p].concat((APELIDOS_DE_BUSCA[p] || "").split(" ").filter(Boolean));
    return formas.some((f) => campos.some((c) => c.includes(f)));
  });
}

/* Um caminho que ela precisa selecionar, copiar e colar num gerenciador de
 * arquivos é a interface pedindo para ser contornada. Agora cada folha é um
 * link que o servidor serve. */

/* "Um engenheiro lê isso como cortesia; um designer leigo lê como «o programa
 * desistiu»."
 *
 * Agora cada uma dessas etapas registra uma linha em `pendencias.tsv`, e esta
 * lista é o que a Home mostra delas. TRÊS DESFECHOS, E A TELA MOSTRA OS TRÊS:
 *   com `acao`       um botão «Resolver», que roda na gaveta como qualquer ação
 *   com `recusavel`  mais um «Não, obrigado», que grava a recusa e não volta
 *   sem nenhum dos dois  só a frase: a decisão está dita, e não há botão que
 *                        a cumpra — inventar um seria prometer e sumir */
let PENDENCIAS = [];

async function recarregarPendencias() {
  const [r, g] = await Promise.all([api("/api/pendencias"), api("/api/precisa-de-gente")]);
  PENDENCIAS = (r && !r.erro && Array.isArray(r.pendencias)) ? r.pendencias : [];
  PRECISA_DE_GENTE = (g && !g.erro && Array.isArray(g.itens)) ? g.itens : [];
}

/* O QUE PRECISA DE GENTE: o que a máquina não conserta sozinha, num cartão só.
 * Cada linha traz o nome curto e, ao lado, o selo «desde quando»; o porquê vai
 * para o `?`. Sem linha, o cartão não nasce. Na página exportada a lista nasce
 * vazia. */
let PRECISA_DE_GENTE = [];

function desdeCurto(iso) {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "";
  return String(d.getDate()).padStart(2, "0") + "/" + String(d.getMonth() + 1).padStart(2, "0");
}

function montarPrecisaDeGente() {
  if (!PRECISA_DE_GENTE.length) return null;
  const caixa = elemento("section", { class: "home-pendencias home-gente" });
  caixa.append(elemento("h3", {}, [elemento("span", { texto: "Precisa de gente" })]));
  for (const g of PRECISA_DE_GENTE) {
    const desde = desdeCurto(g.desde);
    const linha = elemento("div", { class: "pendencia" });
    linha.append(elemento("div", { class: "pendencia-topo com-dica" }, [
      elemento("p", { class: "pendencia-frase", texto: g.nome }),
      ...gatilhoDeDica("dica-gente-" + idDeAba(g.id), `Sobre ${g.nome}`,
                       [elemento("p", { class: "resumo", texto: g.porque })]),
    ]));
    if (desde) linha.append(elemento("div", { class: "pendencia-botoes" }, [
      selo("gente", { texto: "desde " + desde, balao: "Espera uma pessoa desde " + desde }),
    ]));
    caixa.append(linha);
  }
  return caixa;
}

/* NÃO executa a string do arquivo — ele roda a AÇÃO que o servidor casou com o
 * id da pendência (`ACAO_DA_PENDENCIA`, servidor.py). */
async function resolverPendencia(p) {
  const acao = (ESQUEMA.acoes || []).find((a) => a.id === p.acao);
  if (!acao) { torrada("esta pendência não tem conserto registrado", "erro"); return; }
  await rodar(acao, "");
  await recarregarPendencias();
  render();
}

/* A pendência de tema de terceiro traz `escolha`: «Trocar pelo tema do pack»
 * e «Manter o meu», cada um uma ação do servidor com o app de argumento. */
async function escolherNaPendencia(e) {
  const acao = (ESQUEMA.acoes || []).find((a) => a.id === e.acao);
  if (!acao) { torrada("esta escolha não tem ação registrada", "erro"); return; }
  await rodar(acao, e.argumento);
  await recarregarPendencias();
  render();
}

async function recusarPendencia(p) {
  const ok = await perguntar({
    titulo: "Não perguntar de novo?",
    /* A frase vem do log de um script e NÃO termina em ponto — as mensagens do
     * projeto não pontuam o fim. Emendar as duas direto dava "…do Pop!_OS
     * Dizendo não…", visto na tela. */
    texto: p.frase + ". Dizendo não, o MeowSystem para de oferecer isto — "
         + "e a etapa passa a se pular, sem escrever nada.",
    ok: "Não, obrigado",
    neutro: true,
  });
  if (!ok) return;
  const r = await api("/api/pendencia-recusar", {
    method: "POST", body: JSON.stringify({ id: p.id }),
  });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  await recarregarPendencias();
  render();
}

/* A seção, ou nada. Devolve `null` sem pendência — quem chama usa isso para
 * não pôr um `<section>` vazio no meio da coluna. */
function montarPendencias() {
  if (!PENDENCIAS.length) return null;
  /* Numa Home com uma pendência só, sem botão, ele dizia "1 coisa espera um
   * clique" sobre uma linha em que não há o que clicar.
   *
   * Agora são duas contas e duas frases. */
  const comClique = PENDENCIAS.filter((p) => p.acao || p.recusavel || (p.escolha || []).length).length;
  const semClique = PENDENCIAS.length - comClique;
  const caixa = elemento("section", { class: "home-pendencias" });
  /* TUDO DENTRO DE UM <span> SÓ, e isto não é capricho: o `h3` é `display:
   * flex` com `gap`, então cada filho vira um item e ganha folga dos dois
   * lados. */
  const frase = elemento("span");
  if (comClique) {
    frase.append(elemento("strong", { texto: String(comClique) }));
    /* "coisa" e não "pendência": a palavra do produto é a que ela usaria em voz
     * alta. */
    frase.append(document.createTextNode(
      comClique === 1 ? " coisa espera um clique" : " coisas esperam um clique"));
  }
  if (semClique) {
    /* Com as duas espécies na tela a segunda entra como continuação da
     * primeira ("…, e mais 1 que…"), e aí o substantivo já foi dito. Sozinha,
     * ela precisa dele. */
    if (comClique) frase.append(document.createTextNode(", e mais "));
    frase.append(elemento("strong", { texto: String(semClique) }));
    frase.append(document.createTextNode(
      (comClique ? "" : (semClique === 1 ? " coisa" : " coisas"))
      + " que eu não conserto sozinha"));
  }
  caixa.append(elemento("h3", {}, [frase]));

  for (const p of PENDENCIAS) {
    /* A linha era a frase do log inteira («O onlyoffice está no tema
     * 'theme-dracula-dark-ajustado-2', que não veio do MeowSystem — deixei como
     * está…», quatro linhas na coluna estreita). */
    const acaoDela = p.acao ? (ESQUEMA.acoes || []).find((a) => a.id === p.acao) : null;
    const programa = ((p.escolha || [])[0] || {}).argumento || "";
    const nome = p.nome ? p.nome : acaoDela ? acaoDela.rotulo
      : programa ? `${maiuscula(programa)}: tema de fora` : maiuscula(p.etapa || p.id);
    const linha = elemento("div", { class: "pendencia" });
    linha.append(elemento("div", { class: "pendencia-topo com-dica" }, [
      elemento("p", { class: "pendencia-frase", texto: nome }),
      ...gatilhoDeDica("dica-pendencia-" + idDeAba(p.id), `Sobre ${nome}`,
                       [elemento("p", { class: "resumo", texto: p.frase })]),
    ]));
    const botoes = elemento("div", { class: "pendencia-botoes" });
    if (p.acao) {
      /* Ele era `p.comando`, o texto cru do TSV, e a aposta era que o
       * `porBalao` reconheceria a linha como comando e a tiraria do balão.
       *
       * O que entra é o RÓTULO da ação que o botão dispara, lida do MESMO
       * `ESQUEMA.acoes` que o `resolverPendencia` roda: «Instalar o starship». */
      const acao = (ESQUEMA.acoes || []).find((a) => a.id === p.acao);
      botoes.append(elemento("button", {
        type: "button", class: "btn btn-mini btn-accent",
        texto: "Resolver",
        title: acao ? acao.rotulo : "",
        onclick: () => resolverPendencia(p),
      }));
    }
    /* A ESCOLHA, SEM LADO PREFERIDO: nenhum dos dois ganha o acento,
     * porque a decisão é dela e a tela não empurra para um lado. */
    for (const e of (p.escolha || [])) {
      botoes.append(elemento("button", {
        type: "button", class: "btn btn-mini",
        texto: e.rotulo,
        onclick: () => escolherNaPendencia(e),
      }));
    }
    if (p.recusavel) {
      botoes.append(elemento("button", {
        type: "button", class: "btn btn-mini",
        texto: "Não, obrigado",
        title: "Grava a recusa; isto não volta a ser oferecido.",
        onclick: () => recusarPendencia(p),
      }));
    }
    /* A PASTILHA VEM DEPOIS DOS BOTÕES, e não entre eles: dois botões separados
     * por um selo leem-se como dois grupos, e eles são um. */
    if ((p.acao || (p.escolha || []).length) && p.rede) botoes.append(selo("rede", { balao: "Baixa da internet" }));
    if (p.id === "vscode-extensao-de-terceiro" && (p.escolha || []).length)
      botoes.append(selo("pack", { balao: "Pedida por um pack importado: extensão é código de terceiro" }));
    /* SEM BOTÃO, A ORIGEM. Uma linha que não oferece nada precisa dizer de onde
     * veio, ou vira uma reclamação sem endereço. */
    if (botoes.childElementCount) linha.append(botoes);
    caixa.append(linha);
  }
  return caixa;
}

/* OS THEME PACKS, COM CARA
 *
 * "Ninguém escolhe um tema por um `id`." Até aqui um pack era isso e 26
 * hexadecimais, e esta página não tinha o que desenhar.
 *
 * A capa é o `logo.svg` do pack; a tira continua, de 6 px, como amostra.
 *
 * O `vitrine.descricao` é um Markdown de quem publicou o pack, e esta página
 * carrega o token de sessão: ela entra só por `textContent`, nunca como HTML,
 * e só o link `https://` vira `href` (o `tests/pack.sh` cobra). */
let PACKS = [];

async function recarregarPacks() {
  const r = await api("/api/packs");
  PACKS = (r && !r.erro && Array.isArray(r.packs)) ? r.packs : [];
}

/* O cartão dizia «herdado de catppuccin», pelo ID, e o «Mais sobre» da mesma
 * caixa, logo abaixo, «herdado do Catppuccin», pelo NOME: duas palavras para
 * o mesmo pack. */
/* Agora cada tipo tem a frase dele, com as palavras do `info`, e um tipo que o
 * pack.py venha a ganhar aparece pelo nome em vez de se passar por outro. */
const ORIGEM_NA_TELA = {
  "próprio": "próprio",
  motor: "do motor, ou ausente",
  fixo: "do motor — não declarável",
};
function deOndeVem(c) {
  return c.tipo === "herdado" ? `herdado do ${c.nome_de || c.de}`
    : ORIGEM_NA_TELA[c.tipo] || c.tipo;
}

/* A linha do cartão: o agrupamento do `resumo_de_origem`, com o nome. Sem as
 * categorias fixas do motor, pelo motivo que ele conta — são as mesmas em todo
 * cartão, e não distinguem pack nenhum. */
function linhaDeOrigem(p) {
  const grupos = new Map();
  for (const c of p.categorias || []) {
    if (c.tipo === "fixo") continue;
    const de = deOndeVem(c);
    grupos.set(de, [...(grupos.get(de) || []), c.categoria]);
  }
  return [...grupos].map(([de, cats]) => `${de}: ${cats.join(", ")}`).join(" · ") || p.origem || "";
}

/* Os selos de origem do cartão: um por grupo do `linhaDeOrigem`, na mesma
 * ordem e com as mesmas palavras (`deOndeVem`), cada um com a conta de
 * categorias ao lado e a lista no balão. */
function selosDeOrigem(p, origem) {
  const caixa = elemento("div", { class: "selos pack-origem", role: "group", "aria-label": origem });
  const grupos = new Map();
  for (const c of p.categorias || []) {
    if (c.tipo === "fixo") continue;
    const de = deOndeVem(c);
    const g = grupos.get(de) || { tipo: c.tipo, nome: c.nome_de || c.de || "", cats: [] };
    g.cats.push(c.categoria);
    grupos.set(de, g);
  }
  const TIPO = { "próprio": "proprio", herdado: "herdado", motor: "motor" };
  for (const [de, g] of grupos) {
    const conta = String(g.cats.length);
    caixa.append(selo(TIPO[g.tipo] || "pack", {
      texto: g.tipo === "herdado" && g.nome ? `${conta} · ${encurtarValor(g.nome)}` : conta,
      balao: `${maiuscula(de)}: ${g.cats.join(", ")}`,
    }));
  }
  if (!caixa.childElementCount) caixa.append(selo("pack", { balao: origem }));
  return caixa;
}

/* Nada do texto do pack vira HTML: só título, lista, negrito, código e link viram
 * nó, com o texto por `textContent`; o link só ganha `href` com `https://`. */
function trechosDaLinha(linha) {
  const nos = [];
  const forma = /\*\*([^*]+)\*\*|`([^`]+)`|\[([^\]]+)\]\(([^)\s]+)\)/g;
  let fim = 0;
  let m;
  while ((m = forma.exec(linha))) {
    if (m.index > fim) nos.push(linha.slice(fim, m.index));
    if (m[1] !== undefined) nos.push(elemento("strong", { texto: m[1] }));
    else if (m[2] !== undefined) nos.push(elemento("code", { texto: m[2] }));
    else if (m[4].startsWith("https://")) {
      nos.push(elemento("a", { href: m[4], target: "_blank", rel: "noopener noreferrer",
                               texto: m[3] }));
    } else nos.push(m[3]);
    fim = forma.lastIndex;
  }
  if (fim < linha.length) nos.push(linha.slice(fim));
  return nos;
}

function historiaDoPack(texto) {
  const caixa = elemento("div", { class: "pack-historia" });
  let paragrafo = null;
  let lista = null;
  for (const bruta of String(texto || "").split("\n")) {
    const linha = bruta.trim();
    let m;
    if (!linha) {
      paragrafo = null;
      lista = null;
    } else if ((m = /^(#{1,6})\s+(.*)$/.exec(linha))) {
      paragrafo = null;
      lista = null;
      caixa.append(elemento(m[1].length <= 2 ? "h4" : "h5", {}, trechosDaLinha(m[2])));
    } else if ((m = /^(?:[-*+]|\d+[.)])\s+(.*)$/.exec(linha))) {
      paragrafo = null;
      const numerada = /^\d/.test(linha);
      if (!lista || (lista.tagName === "OL") !== numerada) {
        lista = elemento(numerada ? "ol" : "ul");
        caixa.append(lista);
      }
      lista.append(elemento("li", {}, trechosDaLinha(m[1])));
    } else if (lista && /^\s/.test(bruta)) {
      // A linha recuada logo abaixo de um item é a continuação dele.
      lista.lastElementChild.append(" ", ...trechosDaLinha(linha));
    } else {
      lista = null;
      if (paragrafo) paragrafo.append(" ");
      else caixa.append(paragrafo = elemento("p"));
      paragrafo.append(...trechosDaLinha(linha));
    }
  }
  return caixa;
}

/* Quem decide o que pode sair é a `remocao` do scripts/pack.py; o cartão só lê
 * a resposta (`p.remover`). */
async function removerPack(p) {
  const acao = (ESQUEMA.acoes || []).find((a) => a.id === "pack_remover");
  if (!acao) { torrada("Remover um pack não está disponível nesta página.", "erro"); return; }
  await rodar(acao, p.id);
}

function cartaoDePack(p) {
  /* O CARTÃO GANHOU CLASSES, E O DESENHO FOI PARA O `estilo.css`
   *
   * É a mesma regra do resto da página — accent quer dizer "aceso" — e um «Usar
   * este» no pack que já está em uso seria um botão que não faz nada. */
  const cartao = elemento("article", {
    class: "pack" + (p.no_ar ? " no-ar" : ""),
    "aria-label": p.no_ar ? `${p.nome}, o pack no ar` : p.nome,
  });

  /* A capa é o logo do pack, e ela fica EM CIMA: o cartão é a escolha de uma
   * identidade, e a identidade é o desenho. */
  const capa = elemento("div", { class: "pack-capa" });
  if (p.capa) capa.append(elemento("img", { src: p.capa, alt: "", width: "64", height: "64" }));
  cartao.append(capa);

  /* Fina, colada na capa, com as 26 cores do flavor padrão na ordem dos slots.
   * As cores já passaram pelo `#RRGGBB` do `validar` antes de sair do
   * servidor. */
  if ((p.amostra || []).length) {
    const tira = elemento("div", { class: "pack-amostra", "aria-hidden": "true" });
    for (const cor of p.amostra) {
      const s = elemento("span");
      s.style.background = cor;
      tira.append(s);
    }
    cartao.append(tira);
  }

  const corpo = elemento("div", { class: "pack-corpo" });
  const variantes = (p.flavors || []).length;
  corpo.append(elemento("div", { class: "pack-nome" }, [
    elemento("b", { texto: p.nome }),
    elemento("span", {
      class: "pack-estado",
      texto: p.no_ar ? "no ar" : variantes ? `${variantes} ${variantes === 1 ? "variante" : "variantes"}` : "",
    }),
  ]));
  if (p.autor) corpo.append(elemento("p", { class: "pack-autor", texto: `Por ${p.autor}` }));
  if (p.descricao_curta) corpo.append(elemento("p", { class: "pack-desc", texto: p.descricao_curta }));
  if ((p.tags || []).length) {
    const tags = elemento("ul", { class: "pack-tags", "aria-label": "Etiquetas" });
    for (const tag of p.tags) tags.append(elemento("li", { texto: tag }));
    corpo.append(tags);
  }
  /* A linha «Próprio: paleta, pastas, … · do motor, ou ausente: …» era um
   * bloco monoespaçado de seis linhas no meio do cartão: dado técnico tratado
   * como leitura. */
  const origem = linhaDeOrigem(p);
  if (origem) corpo.append(selosDeOrigem(p, origem));
  /* O pack que não valida aparece assim mesmo, dizendo por quê — como no
   * `meow pack info`. Esconder o cartão esconderia também o motivo. Fica na
   * tela: é o único estado do cartão que impede o «Usar este». */
  for (const problema of (p.problemas || [])) {
    corpo.append(elemento("p", { class: "pack-problema", texto: "Não valida: " + problema }));
  }

  const site = (p.site || "").startsWith("https://") ? p.site : "";
  const categorias = p.categorias || [];
  const flavors = p.flavors || [];
  const remover = p.remover || null;
  const podeSair = !!(remover && remover.pode);
  const notas = [];
  /* Um pack feito de CSV tem paleta e nada mais, e o claro dele pode ter
   * nascido do escuro pelo método do Latte, sem ninguém desenhá-lo. */
  for (const d of (p.claros_derivados || [])) {
    notas.push(elemento("p", { class: "pack-herda",
      texto: `Claro «${d.flavor}»: derivado de «${d.de}» pelo método do Latte, não desenhado. `
           + "Para usar o seu, ponha as 26 linhas dele no CSV e importe-o de novo em "
           + (podeSair ? "«Importar um pack», depois de tirar este com o «Remover»."
                       : "«Importar um pack», com outro nome de arquivo.") }));
  }
  /* O «REMOVER» só existe no pack que mora na casa dela. O que não pode sair
   * diz por quê — no detalhe, em vez de um botão que a caixa recusaria depois
   * (o pack no ar, o que outro herda). */
  if (remover && !remover.pode && remover.motivo) {
    notas.push(elemento("p", { class: "pack-fica", texto: `Não sai daqui: ${remover.motivo}.` }));
  }
  if (p.descricao || (p.capturas || []).length || site || categorias.length || flavors.length
      || notas.length) {
    const mais = elemento("details", { class: "pack-mais" }, [
      elemento("summary", { title: `Detalhes do ${p.nome}` }, [
        elemento("span", { class: "so-leitor", texto: "Detalhes do pack" }),
      ]),
    ]);
    /* A seta nasce nó a nó, e não por `insertAdjacentHTML`: neste cartão nada
     * entra como HTML. */
    const NS = "http://www.w3.org/2000/svg";
    const seta = document.createElementNS(NS, "svg");
    seta.setAttribute("class", "pack-seta");
    seta.setAttribute("viewBox", "0 0 16 16");
    seta.setAttribute("aria-hidden", "true");
    const traco = document.createElementNS(NS, "path");
    traco.setAttribute("d", "m4 6 4 4 4-4");
    seta.append(traco);
    mais.querySelector("summary").append(seta);
    const ler = elemento("div", { class: "pack-ler" });
    if (p.descricao) ler.append(historiaDoPack(p.descricao));
    ler.append(...notas);
    if ((p.capturas || []).length) {
      const fotos = elemento("div", { class: "home-fotos" });
      for (const url of p.capturas) fotos.append(elemento("img", { src: url, alt: "" }));
      ler.append(fotos);
    }
    if (site) {
      ler.append(elemento("p", { class: "pack-autor" }, [
        "Site: ",
        elemento("a", { href: site, target: "_blank", rel: "noopener noreferrer",
                        texto: site.replace(/^https:\/\//, "") }),
      ]));
    }
    /* O `meow pack info` VIRA TELA. As categorias saem da mesma conta dos selos
     * de origem (o `origens` do pack.py), e as 26 cores de cada flavor, das
     * mesmas cores que o `validar` conferiu. */
    const ficha = elemento("div", { class: "pack-ficha" });
    if (categorias.length) {
      const lista = elemento("dl", { class: "pack-categorias" });
      /* «pastas: próprio» sozinho dizia que os desenhos do pack vestem as
       * pastas, e eles vestem só as especiais; as outras são o papirus-folders
       * na paleta do pack. */
      for (const c of categorias) {
        lista.append(elemento("dt", { texto: c.categoria }),
                     elemento("dd", { "data-origem": c.tipo,
                                      texto: deOndeVem(c) + (c.nota ? ` — ${c.nota}` : "") }));
      }
      ficha.append(lista);
    }
    for (const f of flavors) {
      const linha = elemento("div", { class: "pack-flavor" }, [
        elemento("span", { texto: f.nome + (f.claro ? " · claro" : "") }),
      ]);
      const tira = elemento("div", { class: "pack-amostra", "aria-hidden": "true" });
      for (const cor of f.cores || []) {
        const s = elemento("span");
        s.style.background = cor;
        tira.append(s);
      }
      linha.append(tira);
      ficha.append(linha);
    }
    /* Um invólucro, e não a grade no próprio `<details>`: o Chromium põe o
     * conteúdo do `<details>` num slot interno, e `display: grid` nele não faz
     * dos filhos itens de grade — medido, a ficha caía embaixo da história. */
    const detalhe = elemento("div", { class: "pack-detalhe" });
    if (ler.childElementCount) detalhe.append(ler);
    if (ficha.childElementCount) detalhe.append(ficha);
    mais.append(detalhe);
    /* O cartão aberto ocupa a linha inteira; a classe segue o `open`, que é a
     * verdade (o teclado e o próprio `<summary>` o mudam sem passar por aqui). */
    mais.addEventListener("toggle", () => cartao.classList.toggle("aberto", mais.open));
    cartao.addEventListener("click", (ev) => {
      if (ev.target.closest("button, a, summary, input, select, .pack-mais > :not(summary)")) return;
      mais.open = !mais.open;
    });
    cartao.classList.add("abre");
    cartao.append(mais);
  }

  const botoes = [];
  if (remover && remover.pode) {
    botoes.push(elemento("button", {
      type: "button", class: "btn btn-perigo",
      texto: "Remover",
      title: `Tira o ${p.nome} da sua casa de packs`,
      onclick: () => removerPack(p),
    }));
  }
  if (!p.no_ar && p.valido !== false) {
    botoes.push(elemento("button", {
      type: "button", class: "btn",
      texto: "Usar este",
      title: `Veste a máquina inteira com o ${p.nome}`,
      onclick: () => usarPack(p),
    }));
    /* Trocar de pack leva o ponteiro do pack (o do Dracula desce da rede), e o
     * instalador que a troca roda baixa e compila. */
    const troca = (ESQUEMA.acoes || []).find((a) => a.id === "pack_usar");
    if (troca && troca.rede) botoes.push(selo("rede", { balao: "Baixa da internet" }));
  }
  if (botoes.length) corpo.append(elemento("div", { class: "pack-acoes" }, botoes));
  /* O corpo vem antes do detalhe no documento: é a ordem de leitura (o nome,
   * depois o que ele tem), e a grade do cartão aberto põe o detalhe ao lado. */
  const detalhe = cartao.querySelector(":scope > .pack-mais");
  if (detalhe) cartao.insertBefore(corpo, detalhe);
  else cartao.append(corpo);
  return cartao;
}

/* É o `meow pack usar`, pela ação `pack_usar` do servidor, e com a mesma caixa
 * de confirmação de todo gesto que escreve na máquina — inclusive o «Ver o que
 * faria», que ensaia a TROCA (o verbo grava numa cópia do conf quando roda
 * seco).
 *
 * A pergunta vem antes; o descarte, só se a troca de fato começar — cancelar a
 * caixa seguinte devolve tudo como estava. */
async function usarPack(p) {
  const acao = (ESQUEMA.acoes || []).find((a) => a.id === "pack_usar");
  if (!acao) { torrada("Trocar de pack não está disponível nesta página.", "erro"); return; }
  const esperando = MUDANCAS.size;
  if (esperando) {
    const ok = await perguntar({
      titulo: `Trocar para o ${p.nome}?`,
      texto: esperando === 1
        ? `1 escolha ainda não salva foi feita olhando o pack de agora. Trocando para o ${p.nome}, `
          + "ela é descartada — o meow.conf não é tocado por ela."
        : `${esperando} escolhas ainda não salvas foram feitas olhando o pack de agora. Trocando `
          + `para o ${p.nome}, elas são descartadas — o meow.conf não é tocado por elas.`,
      ok: "Descartar e seguir", neutro: true,
    });
    if (!ok) return;
  }
  const descartar = () => {
    if (!MUDANCAS.size) return;
    MUDANCAS.clear();
    atualizarBarraSalvar();
    render();
    torrada("As escolhas que esperavam foram descartadas — o meow.conf não foi tocado", "igual");
  };
  const antes = TRABALHO && TRABALHO.id;
  await rodar(acao, p.id);
  const comecou = TRABALHO && TRABALHO.id !== antes;
  if (!esperando || !comecou) return;
  if (!TRABALHO.seco) { descartar(); return; }
  const deVerdade = TRABALHO.aplicar;
  if (!deVerdade) return;
  TRABALHO.aplicar = async () => {
    const doEnsaio = TRABALHO && TRABALHO.id;
    await deVerdade();
    if (TRABALHO && TRABALHO.id !== doEnsaio && !TRABALHO.seco) descartar();
  };
}

/* O contrato que estes botões esperam, e que o merge das duas metades tem de
 * fechar:
 *
 * Enquanto a rota não existe, o servidor responde 404 "não existe aqui", e a
 * torrada diz isso em português em vez de repetir o texto cru. */
function lerComoBase64(arquivo) {
  return new Promise((ok, falha) => {
    const leitor = new FileReader();
    leitor.onerror = () => falha(new Error("não consegui ler o arquivo"));
    leitor.onload = () => ok(String(leitor.result).split(",")[1] || "");
    leitor.readAsDataURL(arquivo);
  });
}

async function importarPack(arquivo) {
  if (!arquivo) return;
  let r;
  try {
    const pedido = { nome: arquivo.name, conteudo: await lerComoBase64(arquivo) };
    r = await api("/api/pack-importar", { method: "POST", body: JSON.stringify(pedido) });
    if (r && r.precisa_confirmar) {
      const ok = await perguntar({
        titulo: r.titulo || `Importar ${arquivo.name}?`,
        texto: r.resumo || "",
        corpo: r.pack ? telaDoPack(r.pack) : null,
        ok: "Importar",
      });
      if (!ok) return;
      r = await api("/api/pack-importar", {
        method: "POST", body: JSON.stringify({ ...pedido, confirmado: true }) });
    }
  } catch (e) {
    torrada(String(e.message || e), "erro");
    return;
  }
  if (r.erro) {
    torrada(r.erro === "não existe aqui"
      ? "Importar um pack ainda não chegou a este painel." : r.erro, "erro");
    return;
  }
  if (!r.instalado) {
    torrada(`${arquivo.name} não foi instalado — o servidor não confirmou a instalação.`, "erro");
    return;
  }
  torrada(r.frase || `${arquivo.name} entrou — ele aparece entre os packs, e usar é outro clique.`, "ok");
  /* O «Remover» não precisa disto: ele é um trabalho que escreve, e o fim de
   * todo trabalho que escreve já relê os dois. */
  await Promise.all([recarregarPacks(), recarregarEsquema()]);
  render();
}

/* Cada linha sai do `pack` que a rota devolveu, que é o `o_que_traz` do pack.py
 * — a mesma conta que o `meow pack importar` imprime no terminal, e não uma
 * segunda.
 *
 * AS CORES VÊM DE UM ARQUIVO DE TERCEIRO, e entram por `style.background` só
 * depois de o `validar` — que o `importar --seco` rodou sobre estes mesmos
 * bytes — ter conferido o `#RRGGBB` de cada uma. */
function telaDoPack(pack) {
  const tela = elemento("div", { style: "display:flex;flex-direction:column;gap:.55rem" });
  const claros = new Set(pack.claros || []);
  /* A marca diz de onde ele saiu, e uma linha abaixo diz como trocar. A
   * `regua` só vem do CSV: avisa com a lista, e não bloqueia — o botão de
   * importar continua ali. */
  const derivados = pack.derivados || {};
  for (const [flavor, cores] of Object.entries(pack.paleta || {})) {
    const claro = !claros.has(flavor) ? ""
      : derivados[flavor] ? `claro derivado de ${maiuscula(derivados[flavor])}` : "claro";
    const marcas = [flavor === pack.flavor_padrao ? "padrão" : "", claro];
    const tira = elemento("div", { class: "pack-amostra", "aria-hidden": "true" });
    for (const cor of cores) {
      const s = elemento("span");
      s.style.background = cor;
      tira.append(s);
    }
    tela.append(elemento("div", { class: "pack-flavor" }, [
      elemento("span", { texto: [maiuscula(flavor), ...marcas.filter(Boolean)].join(" · ") }),
      tira,
    ]));
  }
  const icones = pack.icones === 1 ? "1 ícone" : `${pack.icones} ícones`;
  const linhas = [
    ["Ícones", `${icones} no pacote · os de aplicativo: ${pack.icones_de_aplicativo}`],
    ["Papéis de parede", pack.papeis_de_parede],
    ["Ponteiro", pack.ponteiro],
    ["Som", pack.som],
  ];
  if (pack.imagens) linhas.push(["Imagens", `${pack.imagens} no pacote`]);
  for (const [claro, escuro] of Object.entries(derivados)) {
    linhas.push(["Claro", `«${claro}» saiu de «${escuro}» pelo método do Latte, sem ninguém `
      + "desenhá-lo. Para usar o seu, ponha as 26 linhas dele no CSV."]);
  }
  const lista = elemento("dl", { class: "pack-categorias" });
  for (const [rotulo, valor] of linhas) {
    lista.append(elemento("dt", { texto: rotulo }), elemento("dd", { texto: valor }));
  }
  /* É a mesma lista que o terminal imprime. */
  const regua = pack.regua || [];
  if (regua.length) {
    lista.append(elemento("dt", { texto: "Contraste" }), elemento("dd", {}, [
      `${regua.length} abaixo da régua do projeto — não bloqueia, a decisão é sua:`,
      elemento("ul", {}, regua.map((linha) => elemento("li", { texto: linha }))),
    ]));
  }
  tela.append(lista);
  return tela;
}

/* O exportar precisa perguntar se as imagens vão junto, e dizer quantos MB
 * antes." No terminal o `meow pack exportar` já fazia isso; aqui o botão era um
 * `<a download>`, que não pergunta nada.
 *
 * A ORDEM: o `medir` primeiro, que é o exportar em ENSAIO — a licença, o
 * CREDITOS.md e o `validar` já são conferidos ali, e um pack que seria recusado
 * recebe a recusa antes da pergunta, não depois. */
async function exportarPack(p) {
  const rota = `/api/pack-exportar?id=${encodeURIComponent(p.id)}`;
  const m = await api(rota + "&medir=1");
  if (m.erro) {
    torrada(m.erro, "erro");
    return;
  }
  const contar = (n) => `${Number(n).toLocaleString("pt-BR")} arquivo(s)`;
  /* O `meow pack exportar` avisa quando o pack herda de um pack que não vem
   * com o MeowSystem, e pela tela o aviso não chegava: o pack saía para ser
   * recusado na máquina de quem o recebesse. */
  const avisos = (m.avisos || []).map((a) => ` ${maiuscula(a)}.`).join("");
  let semImagens = false;
  if (m.imagens || avisos) {
    const levar = elemento("input", { type: "checkbox", checked: true });
    const ok = await perguntar({
      titulo: `Exportar o ${p.nome}?`,
      texto: `${contar(m.arquivos)}, ${m.tamanho} antes de comprimir`
        + (m.imagens
          ? ` — ${m.imagens === 1 ? "1 imagem soma" : `${m.imagens} imagens somam`} ${m.tamanho_imagens} disso.`
          : ".")
        + avisos,
      corpo: m.imagens ? elemento("label", { style: "display:flex;gap:.5rem;align-items:baseline" }, [
        levar,
        elemento("span", {
          texto: `Levar as imagens junto. Sem elas, o pack fica com ${m.tamanho_sem_imagens}, `
            + "e a vitrine da cópia deixa de citá-las.",
        }),
      ]) : null,
      ok: "Exportar",
    });
    if (!ok) return;
    semImagens = !levar.checked;
  }
  let resposta;
  try {
    resposta = await fetch(rota + (semImagens ? "&imagens=nao" : ""),
                           { headers: { "X-Meow-Token": TOKEN } });
  } catch {
    faixaSemServidor(true);
    torrada("O painel perdeu o servidor — veja a faixa no alto.", "erro");
    return;
  }
  faixaSemServidor(false);
  if (!resposta.ok) {
    let erro = "";
    try { erro = (await resposta.json()).erro || ""; } catch { /* resposta que não é JSON */ }
    torrada(erro || `O exportar falhou (HTTP ${resposta.status}).`, "erro");
    return;
  }
  const nome = (/filename="([^"]+)"/.exec(resposta.headers.get("Content-Disposition") || "") || [])[1]
    || `${p.id}.meowpack`;
  const url = URL.createObjectURL(await resposta.blob());
  elemento("a", { href: url, download: nome }).click();
  /* Um minuto, e não na hora: revogar logo depois do clique cancela o
   * download em navegador que ainda não começou a ler o blob. */
  setTimeout(() => URL.revokeObjectURL(url), 60000);
  const peso = semImagens
    ? `${contar(m.arquivos - m.imagens)}, ${m.tamanho_sem_imagens} antes de comprimir, sem as imagens`
    : `${contar(m.arquivos)}, ${m.tamanho} antes de comprimir`;
  torrada(`${nome} baixado — ${peso}.`, "ok");
}

/* A seção, ou nada — o mesmo contrato do `montarPendencias`. */
function montarPacks() {
  if (!PACKS.length) return null;
  const secao = elemento("section", { class: "home-packs", "aria-labelledby": "titulo-packs" });
  const noAr = PACKS.find((p) => p.no_ar);
  const acoes = elemento("div", { class: "home-packs-acoes" });
  if (noAr) {
    acoes.append(elemento("button", {
      type: "button", class: "btn",
      texto: "Exportar o meu",
      title: `Empacota o ${noAr.nome} num .meowpack, para mandar a alguém`,
      onclick: () => exportarPack(noAr),
    }));
  }
  /* O `.csv` ENTRA PELO MESMO BOTÃO: "Vinte e seis linhas e o tema existe." Não
   * é um segundo botão porque não é um segundo gesto: nos dois casos um arquivo
   * vira um pack a mais, com a mesma caixa de confirmar, e nada do tema no ar
   * muda. */
  const campo = elemento("input", {
    type: "file", accept: ".meowpack,.csv", hidden: true,
    onchange: async () => {
      const arquivo = campo.files && campo.files[0];
      campo.value = "";
      await importarPack(arquivo);
    },
  });
  acoes.append(campo, elemento("button", {
    type: "button", class: "btn", texto: "Importar um pack",
    title: "Um .meowpack, ou um .csv de 26 cores: ele entra como opção, sem trocar nada",
    onclick: () => campo.click(),
  }));
  secao.append(elemento("div", { class: "home-packs-topo" }, [
    elemento("h2", { class: "home-rotulo", id: "titulo-packs", texto: "Theme packs" }),
    acoes,
  ]));
  const grade = elemento("div", { class: "packs" });
  for (const p of PACKS) grade.append(cartaoDePack(p));
  secao.append(grade);
  return secao;
}

/* A HOME — "o que está no ar, o que espera por mim, e por onde entro"
 *
 * A página abria na galeria: 46 fotos e nenhuma resposta.
 *
 * Elas já existem em "Rodar"; aqui elas estão a um clique de onde a página
 * abre. */
function montarHome() {
  const chave = (c) => ESQUEMA.chaves.find((k) => k.chave === c);
  const vale = (c) => { const k = chave(c); return k ? (k.efetivo || k.valor || k.padrao || "") : ""; };
  const caixa = elemento("div", { class: "home" });

  /* --- 0. os theme packs, EM CIMA ----------------
   * "o que eu quero nessa aba de home: tenhamos o theme pack Catppuccin e o
   * theme pack Dracula e que qualquer um possa exportar o proprio tema e
   * importar outros pro seu sistema operacional. disso em diante o app se
   * modifica pra apresentar ao user o que ele pede."
   *
   * O pack é o centro, então ele vem primeiro — no documento E na tela. */
  const packs = montarPacks();
  if (packs) caixa.append(packs);

  /* --- 1. o retrato ------------------------------------------------------- */
  const retrato = elemento("section", { class: "home-retrato" });
  /* A `LOGO` é a do modo fixo; no modo hora quem põe o gato é o relógio, e às
   * 03:28 este retrato dizia «Logo Coquinha» com o morcego-noite no dock. */
  const gatoNome = ESQUEMA.gato_no_dock || vale("LOGO");
  const gatos = previasDe("gato");
  const gato = gatos && gatos.itens.find((i) => i.id === gatoNome);
  if (gato && gato.url) {
    retrato.append(elemento("img", { class: "home-gato", src: gato.url, alt: "",
                                     title: `A logo em vigor: ${gatoNome}` }));
  }

  const ident = elemento("div", { class: "home-id" });
  ident.append(elemento("p", { class: "home-rotulo", texto: "Como a máquina está vestida" }));
  /* O cartão do pack dizia «Dracula» e este título «Drácula · Mauve»: o flavor
   * vinha de uma tabela escrita à mão e a cor pelo nome do slot do Catppuccin. */
  ident.append(elemento("h2", { class: "home-titulo",
    texto: [rotuloDeValor(vale("FLAVOR")),
            nomeDaCor(vale("ACCENT"), vale("FLAVOR")) || rotuloDeValor(""),
            rotuloDeValor(vale("MODO"))].map((v) => maiuscula(v)).join(" · ") }));

  /* Mesma disciplina do cartão de variante: um nome não se compara, uma tira se
   * compara.
   *
   * O BALÃO DIZIA "na ordem do Catppuccin". */
  const paleta = (ESQUEMA.paleta.flavors || {})[vale("FLAVOR")] || {};
  const tira = elemento("div", { class: "home-tira", title: "A paleta desta variante, na ordem da paleta do pack" });
  for (const nome of (ESQUEMA.paleta.ordem || [])) {
    if (!paleta[nome]) continue;
    const s = elemento("span", { title: nome });
    s.style.background = paleta[nome];
    if (nome === vale("ACCENT")) s.dataset.acento = "1";
    tira.append(s);
  }
  ident.append(tira);

  /* Era «Logo Coquinha, escolhida pelo relógio · ícones MeowSystem-Icons ·
   * ponteiro catppuccin-mocha-light», uma frase de 90 caracteres para três
   * fatos. */
  const comoEscolhido = { hora: "escolhida pelo relógio", rotacao: "girando pela lista", fixo: "fixa" };
  const modoLogo = vale("LOGO_MODO");
  const nomeGato = gatoNome ? maiuscula(rotuloDeValor(gatoNome)) : "—";
  const pecas = elemento("div", { class: "selos home-pecas" });
  pecas.append(selo(modoLogo === "hora" ? "relogio" : modoLogo === "rotacao" ? "gira" : "mexeu", {
    texto: encurtarValor(nomeGato),
    balao: `Logo ${nomeGato}, ${comoEscolhido[modoLogo] || "fixa"}`,
  }));
  pecas.append(selo("icones", { texto: encurtarValor(vale("NOME_TEMA_ICONES")),
                                balao: `Tema de ícones: ${vale("NOME_TEMA_ICONES")}` }));
  pecas.append(selo("ponteiro", { texto: encurtarValor(vale("CURSOR") || "de fábrica"),
                                  balao: `Ponteiro: ${vale("CURSOR") || "de fábrica"}` }));
  ident.append(pecas);
  retrato.append(ident);

  /* As fotos são a COLEÇÃO, não "a que está na tela" — a página não sabe qual
   * está na tela, e dizer que sabe seria a primeira mentira dela. */
  const paredes = previasDe("parede", "ativos");
  if (paredes && paredes.itens.length) {
    const fotos = elemento("div", { class: "home-fotos" });
    /* A que não está pronta aparece na próxima pintura. */
    for (const i of paredes.itens.slice(0, 6)) {
      if (i.url && i.pronta) fotos.append(elemento("img", { src: i.url, alt: "", title: i.rotulo }));
    }
    const n = (paredes.contagens && paredes.contagens.ativos) || paredes.itens.length;
    const intervalo = rotuloDeValor(vale("WALLPAPER_INTERVALO"));
    fotos.append(elemento("div", { class: "selos home-fotos-conta" }, [
      selo("foto", { texto: String(n), balao: `${n} no carrossel` }),
      selo("relogio", { texto: intervalo, balao: `Troca a cada ${intervalo}` }),
    ]));
    retrato.append(fotos);
  }
  caixa.append(retrato);

  /* --- 2. o que espera por você ------------------------------------------ */
  /* A caixa tinha duas frases de três linhas: «Nada esperando. Escolher aqui
   * não muda a máquina…» e «Consertos de sistema sem senha: desligado. */
  const atencao = elemento("section", { class: "home-atencao com-dica" });
  const explica = [];
  const estado = elemento("div", { class: "selos home-estado" });
  if (MUDANCAS.size) {
    atencao.dataset.esperando = "1";
    estado.append(selo("pendente", { texto: `${MUDANCAS.size} por salvar`,
      balao: `${MUDANCAS.size} ${MUDANCAS.size === 1 ? "escolha esperando" : "escolhas esperando"} «Salvar e aplicar»` }));
    explica.push(elemento("p", { class: "resumo", texto:
      "Elas estão guardadas aqui, e não no disco. «Salvar e aplicar», no alto, grava tudo de uma vez e roda o instalador em seguida." }));
  } else {
    estado.append(selo("pendente", { texto: "Nada por salvar", balao: "Nenhuma escolha esperando «Salvar e aplicar»" }));
    explica.push(elemento("p", { class: "resumo", texto:
      "Escolher aqui não muda a máquina: clicar guarda, e «Salvar e aplicar» é o que grava e aplica." }));
  }

  /* --- 2b. os consertos sem senha, aqui e não no 17º ajuste ---
   * O interruptor da ponte root existe e mora na aba «Manutenção», primeiro de
   * dezessete ajustes. */
  estado.append(ESQUEMA.ponte
    ? selo("ponte", { texto: "sem senha", balao: "Consertos de sistema sem senha: ligado" })
    : selo("sudo", { texto: "pede senha", balao: "Consertos de sistema sem senha: desligado" }));
  if (ESQUEMA.ponte) {
    explica.push(elemento("p", { class: "motivo", texto:
      "Um perfil registrado no sudo faz o que precisa de root — atualizar o sistema, "
      + "repor o hook do apt, vestir a tela de login — sem voltar a pedir senha." }));
  } else if ((vale("PONTE_ROOT") || "sim") === "sim") {
    explica.push(elemento("p", { class: "motivo", texto:
      "O ajuste já está em «sim», e a ponte não está instalada: quem a instala é o "
      + "instalador, e ele precisa da senha uma vez. Rode no terminal: ./install.sh" }));
  } else {
    explica.push(elemento("p", { class: "motivo", texto:
      "Cada conserto de sistema volta a pedir senha no terminal — e este painel, que "
      + "não tem terminal, não tem como pedir." }));
    estado.append(elemento("button", {
      type: "button", class: "btn btn-mini", texto: "Ligar",
      title: "Ir ao ajuste «Consertos de sistema sem pedir senha»",
      /* O MESMO GESTO DA LISTA DE PENDENTES: troca de aba, pinta, e só então
       * rola até o cartão — antes da pintura não há a quem rolar. */
      onclick: () => {
        const aba = abaDaChave("PONTE_ROOT");
        if (!aba) return;
        $("#busca").value = "";
        ABA = aba;
        gravarHash();
        render();
        requestAnimationFrame(() => {
          const alvo = document.querySelector('#conteudo .cartao[data-chave="PONTE_ROOT"]');
          if (alvo && alvo.scrollIntoView) alvo.scrollIntoView({ block: "center" });
        });
      },
    }));
  }
  atencao.append(estado, ...gatilhoDeDica("dica-home-atencao", "O que espera e o que pede senha", explica));

  /* --- 3. as portas: uma por bloco do menu, sempre ------------------------
   * Elas saem do MESMO `blocoDoAssunto` que desenha o menu: bloco novo aparece
   * na home no mesmo dia, e bloco que sair some junto. */
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
  /* A porta dizia "97 ajustes" e os crachás do trilho somavam 131, porque o
   * crachá conta ajustes E ações e a porta contava só ajustes. */
  const portas = blocos.map((b) => [
    b.primeiro, b.nome,
    b.chaves
      ? `${b.chaves} ajustes e ${b.acoes} ${b.acoes === 1 ? "ação" : "ações"} em `
        + `${b.assuntos} assunto${b.assuntos > 1 ? "s" : ""}`
      : `${b.acoes} ${b.acoes > 1 ? "ações" : "ação"}`,
    FRASE_DO_BLOCO[b.nome] || "",
  ]);
  const grade = elemento("div", { class: "home-portas" });
  caixa.append(grade);
  for (const [destino, nome, conta, frase] of portas) {
    if (!destino) continue;
    /* Medido, com o painel no ar: estes dois botões anunciavam 113 e 114
     * caracteres — «Tópicos 105 AJUSTES E 38 AÇÕES EM 10 ASSUNTOS Cada assunto
     * numa página: a coleção, os ajustes e as ações, juntos.» —, que é o cartão
     * inteiro lido de uma vez para dizer «Tópicos». */
    const base = "porta-" + semAcento(nome).replace(/[^a-z0-9]+/g, "-");
    const elConta = elemento("span", { class: "porta-conta", id: base + "-conta", texto: conta });
    grade.append(elemento("button", {
      type: "button", class: "porta",
      "aria-label": nome,
      "aria-describedby": `${base}-conta`,
      title: frase || `Ir para ${destino}`,
      onclick: () => { ABA = destino; gravarHash(); render(); },
    }, [
      elemento("b", { texto: nome }),
      elConta,
    ]));
  }

  /* --- 3b. o que a noite muda --------------------------------------------
   * Nada aqui é escrito à mão: cada frase só aparece quando a chave que a
   * sustenta está ligada, e o texto sai do valor em vigor. */
  const liga = (c) => ["sim", "true", "1"].includes(String(vale(c)).toLowerCase());
  const noite = elemento("section", { class: "home-noite" });
  /* O título mostra a janela geral, a do gato do dock e do terminal, na ordem
   * do `lib/noite.sh`: as `NOITE_*`; vazias, as do papel de parede; vazias as
   * quatro, 18:00–07:00 (a janela que se arrasta no applet a página não lê). */
  const { ini: comecaAs, fim: terminaAs } = janelaDoGato();
  const horaPropria = (ini, fim) => (ini && fim && (ini !== comecaAs || fim !== terminaAs))
    ? `, das ${ini} às ${fim}` : "";
  noite.append(elemento("h3", {}, [
    iconeDeMenu("Dia e noite", "ajustar"),
    elemento("span", { texto: `À noite, das ${comecaAs} às ${terminaAs}` }),
  ]));
  /* «A logo da dock passa a ser Coquinha, e a do terminal, Mimir. O carrossel
   * sorteia só entre as imagens escuras. */
  const urlDoGato = (n) => {
    const i = gatos && gatos.itens.find((x) => x.id === n);
    return (i && i.url) || "";
  };
  const efeitos = elemento("div", { class: "selos home-pecas" });
  if (vale("LOGO_MODO") === "hora" && vale("LOGO_NOITE")) {
    /* "logo", e não "gato": a aba passou a se chamar `Logo do sistema`, e o
     * vocabulário da home tem de ser o mesmo — o VALOR continua sendo o nome de
     * um gato quando é o de fábrica, e é ele que aparece aqui. */
    const noiteNome = maiuscula(vale("LOGO_NOITE"));
    efeitos.append(selo("lua", { img: urlDoGato(vale("LOGO_NOITE")), texto: encurtarValor(noiteNome),
                                 balao: `A logo da dock passa a ser ${noiteNome}` }));
    if (vale("FASTFETCH_LOGO_MODO") === "espelho" && vale("LOGO_DIA")) {
      const termNome = maiuscula(vale("LOGO_DIA"));
      efeitos.append(selo("terminal", { img: urlDoGato(vale("LOGO_DIA")), texto: encurtarValor(termNome),
                                        balao: `A logo do terminal passa a ser ${termNome}` }));
    }
  }
  if (liga("WALLPAPER_NOITE")) {
    const hora = horaPropria(vale("WALLPAPER_NOITE_INICIO") || "18:00",
                             vale("WALLPAPER_NOITE_FIM") || "07:00");
    efeitos.append(selo("foto", { texto: "escuras",
      balao: "O carrossel sorteia só entre as imagens escuras" + hora }));
  }
  if (liga("LEITURA_AGENDA")) {
    const textura = Number(vale("LEITURA_TEXTURA") || 0);
    const rampa = Number(vale("LEITURA_RAMPA_MIN") || 0);
    efeitos.append(selo("calor", { texto: `${vale("LEITURA_TEMPERATURA")} K`,
      balao: `A tela esquenta até ${vale("LEITURA_TEMPERATURA")} K`
        + horaPropria(vale("LEITURA_HORARIO_INICIO"), vale("LEITURA_HORARIO_FIM")) }));
    if (textura > 0) {
      efeitos.append(selo("textura", { texto: `${Math.round(textura * 100)}%`,
        balao: `E ganha ${Math.round(textura * 100)}% de textura de papel` }));
    }
    if (rampa > 0) {
      efeitos.append(selo("rampa", { texto: `${rampa} min`, balao: `Em ${rampa} min de rampa` }));
    }
  } else {
    efeitos.append(selo("calor", { texto: "desligado", balao: "O modo de leitura fica desligado" }));
  }
  noite.append(efeitos);

  /* DUAS PORTAS, E NENHUM NÚMERO CRAVADO. */
  const abrirNoite = elemento("div", { class: "linha-botoes" });
  noite.append(abrirNoite);
  for (const assunto of ["Dia e noite", "Modo de leitura"]) {
    const meus = GRUPOS.filter((g) => g.tipo === "chaves" && assuntoDe(g) === assunto);
    if (!meus.length) continue;
    const quantas = meus.reduce((s, g) => s + g.itens.length, 0);
    abrirNoite.append(elemento("button", {
      type: "button", class: "btn btn-mini",
      texto: `Abrir ${assunto}`,
      title: `${quantas} ${quantas === 1 ? "ajuste" : "ajustes"} em «${assunto}»`,
      onclick: () => { ABA = assunto; gravarHash(); render(); },
    }));
  }
  caixa.append(noite);

  /* --- 4. a coluna da direita -------------------------------------------- */
  const lado = elemento("aside", { class: "home-lado" });
  /* ACIMA DO "Nada esperando", e a ordem é o argumento: o que o programa sabe
   * consertar vem antes do que ele está esperando que ela decida. Sem pendência
   * o bloco não nasce, e a coluna fica exatamente como era. */
  const gente = montarPrecisaDeGente();
  if (gente) lado.append(gente);
  const pendencias = montarPendencias();
  if (pendencias) lado.append(pendencias);
  lado.append(atencao);

  /* ONDE VOCÊ MEXEU — o único número da tela que não poderia existir em outro
   * painel, e que era um `<p>` cinza calculado uma vez. Aqui ele é a lista, e
   * cada nome leva ao cartão: doze fatos, não um adjetivo. */
  const diferentes = ESQUEMA.chaves.filter((i) => !i.sem_programa && (i.valor ?? "") !== i.padrao);
  const bloco = elemento("section", { class: "home-mexeu" });
  bloco.append(elemento("h3", {}, [
    elemento("strong", { texto: String(diferentes.length) }),
    elemento("span", { texto: ` de ${ESQUEMA.chaves.length} mudados por você` }),
  ]));
  if (!diferentes.length) {
    bloco.append(elemento("p", { class: "home-nota", texto: "Tudo como vem de fábrica." }));
  } else {
    /* Eram vinte e cinco fichas soltas, na ordem do arquivo: «Variante do
     * tema», «Theme pack», «Nomes das áreas», «Gato de dia no dock»… — a pessoa
     * lia todas para achar as da página que queria. */
    const porAssunto = new Map();
    for (const i of diferentes) {
      const grupo = GRUPOS.find((g) => (g.itens || []).some((x) => x.chave === i.chave));
      const assunto = grupo ? assuntoDe(grupo) : "";
      porAssunto.set(assunto, [...(porAssunto.get(assunto) || []), [i, grupo]]);
    }
    const ordem = [...assuntosEmOrdem(), ""];
    const linhas = elemento("div", { class: "home-mexeu-linhas" });
    for (const assunto of ordem) {
      const desta = porAssunto.get(assunto);
      if (!desta) continue;
      const fichas = elemento("div", { class: "home-fichas" });
      const marca = iconeDeMenu(assunto || "", null);
      marca.removeAttribute("aria-hidden");
      marca.setAttribute("role", "img");
      marca.setAttribute("aria-label", assunto || "Outros");
      porBalao(marca, assunto || "Outros");
      linhas.append(elemento("div", { class: "home-mexeu-linha" }, [marca, fichas]));
      for (const [i, grupo] of desta) {
        fichas.append(elemento("button", {
          type: "button", class: "home-ficha",
          /* Com ele, um valor comprido (um commit de 40 caracteres, um
           * repositório) levava a frase a 94 caracteres, acima do teto de 80. */
          title: `De fábrica: ${rotuloDeValor(i.padrao) || "nada"} · agora: ${rotuloDeValor(i.valor) || "nada"}`,
          texto: tituloDoCartao(i) || i.chave,
          /* O gesto agora é o da lista de escolhas pendentes: troca de aba,
           * pinta, e só então rola até o cartão, que fica aceso uns segundos
           * (`CARTAO_CHEGADA`, lido pelo `montarCartao`: uma prévia que chegue
           * nesse meio repinta a aba, e o aceso tem de sobreviver a ela). */
          "data-leva": i.chave,
          onclick: grupo ? () => {
            ABA = chaveDeAba(grupo);
            gravarHash();
            const chegada = { chave: i.chave, ate: Date.now() + 2600 };
            CARTAO_CHEGADA = chegada;
            render();
            requestAnimationFrame(() => {
              const alvo = document.querySelector(`#conteudo .cartao[data-chave="${CSS.escape(i.chave)}"]`);
              if (alvo && alvo.scrollIntoView) alvo.scrollIntoView({ block: "center" });
            });
            /* Só apaga o aceso que ELA acendeu: um segundo clique noutra ficha
             * antes do prazo já trocou o `CARTAO_CHEGADA`, e é dele a vez. */
            setTimeout(() => {
              if (CARTAO_CHEGADA !== chegada) return;
              CARTAO_CHEGADA = null;
              document.querySelectorAll("#conteudo .cartao.chegou")
                .forEach((c) => c.classList.remove("chegou"));
            }, 2600);
          } : null,
        }));
      }
    }
    bloco.append(linhas);
  }
  lado.append(bloco);

  /* --- 5. o que se roda toda semana -------------------------------------- */
  const semana = elemento("section", { class: "home-semana" });
  const explicaSemana = [];
  /* Para quem está aprendendo o contrato, o susto desmente o aviso e mina a
   * confiança no resto. */
  explicaSemana.push(elemento("p", { class: "resumo",
    texto: "Estes rodam na hora — ação não espera o Salvar." }));
  semana.append(elemento("div", { class: "home-semana-topo com-dica" }, [
    elemento("h3", { texto: "Toda semana" }),
    ...gatilhoDeDica("dica-home-semana", "Sobre as ações da semana", explicaSemana),
  ]));
  const linha = elemento("div", { class: "linha-botoes" });
  for (const [id, rotulo, principal] of [
    ["doctor", "Conferir a máquina", true],
    ["doctor_consertar", "Consertar o que estiver fora", false],
    ["wallpaper_proximo", "Próxima imagem", false],
    ["painel_reciclar", "Recarregar o painel", false],
  ]) {
    const acao = (ESQUEMA.acoes || []).find((a) => a.id === id);
    if (!acao) continue;
    const botao = elemento("button", {
      type: "button", class: "btn" + (principal ? " btn-accent" : ""),
      "data-acao-rapida": id, texto: rotulo, title: acao.ajuda || "",
    });
    /* O «Consertar» roda sem pergunta e baixa da internet; o mesmo selo do
     * cartão da aba Instalação, logo depois do botão, do mesmo campo
     * `acao.rede`. Botão e selo quebram de linha juntos: soltos, a 1440 px o
     * selo descia sozinho e parecia ser da «Próxima imagem». */
    if (acao.rede) {
      linha.append(elemento("span", { class: "botao-com-selo" }, [
        botao, elemento("span", { class: "pastilha p-rede", texto: "baixa da internet" }),
      ]));
    } else {
      linha.append(botao);
    }
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
    /* O que ela precisa saber é que elas ficam guardadas, e não se perdem. */
    texto: "As folhas que decidiram este tema, guardadas junto com o projeto.",
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
  /* A guarda tratava TODO <input> como campo de texto, e um deslizante é
   * <input type=range>: depois de ajustar uma régua com as setas, o «/»
   * morria — 12 réguas só em "Painel e dock", 12 lugares onde o atalho da
   * busca parava de funcionar. */
  const el = document.activeElement;
  const digitando = /^(TEXTAREA|SELECT)$/.test(el.tagName)
    || (el.tagName === "INPUT" && /^(text|search|time|number|file)$/.test(el.type));
  if (ev.key === "/" && !digitando) { ev.preventDefault(); $("#busca").focus(); return; }
  if (ev.key === "Escape" && document.activeElement === $("#busca")) {
    $("#busca").value = ""; render(); return;
  }
  /* WCAG 1.4.13 (Content on Hover or Focus) pede três coisas do conteúdo que
   * aparece no hover: ser dispensável sem mover o ponteiro, sustentar o
   * ponteiro por cima, e persistir até sair dali.
   *
   * O mecanismo aqui é o MESMO que o gatilho já usa em app.js:3808: marcar
   * `data-fechei` no gatilho irmão faz o CSS esconder o balão, e o `mouseleave`
   * (linha 3810) limpa a marca depois, então o próximo hover volta a abrir. */
  if (ev.key === "Escape") {
    let fechou = false;
    for (const dica of document.querySelectorAll(".dica")) {
      if (getComputedStyle(dica).display === "none") continue;
      const gatilho = dica.previousElementSibling;
      if (gatilho) { gatilho.setAttribute("data-fechei", ""); fechou = true; }
    }
    if (fechou) { ev.preventDefault(); return; }
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
/* Subir no meio de um trabalho tem de acender o «mais N linhas abaixo» NA HORA,
 * e não no puxão seguinte, 400 ms depois: quem rolou está olhando para a tela. */
$("#saida").addEventListener("scroll", marcarLinhasAbaixo);
/* A janela de resultado. Fechar não para nada: com trabalho vivo, a pastilha do
 * cabeçalho a reabre, e o desfecho chega como torrada. */
function aoFecharJanela() {
  if (TRABALHO && TRABALHO.timer !== null) pastilhaDeTrabalho(true);
}
$("#resultado").addEventListener("close", aoFecharJanela);
$("#resultado-ok").addEventListener("click", () => $("#resultado").close());
$("#resultado-guardar").addEventListener("click", async () => {
  if (!ULTIMO_TRABALHO) return;
  const r = await api("/api/guardar-log", { method: "POST",
    body: JSON.stringify({ id: ULTIMO_TRABALHO.id }) });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  const selo = $("#resultado-guardado");
  const partes = r.caminho.split("/");
  selo.textContent = partes.slice(-2).join("/");
  porBalao(selo, r.caminho);
  selo.hidden = false;
});
$("#resultado-restaurar").addEventListener("click", () => {
  if (ULTIMO_TRABALHO && ULTIMO_TRABALHO.acao) restaurarAcao(ULTIMO_TRABALHO.acao);
});

/* As ações cuja última execução se desfaz. Nasce do esquema e acompanha cada
 * fim de trabalho, sem esperar a releitura. */
const RESTAUROS = new Set();
function lerRestauros() {
  RESTAUROS.clear();
  for (const a of (ESQUEMA && ESQUEMA.acoes) || []) if (a.restauro) RESTAUROS.add(a.id);
}

async function restaurarAcao(id) {
  const r = await api("/api/rodar", { method: "POST",
    body: JSON.stringify({ acao: "restaurar", argumento: id, confirmado: true }) });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirResultado(r);
  TRABALHO.restaura = id;
}

function pastilhaDeTrabalho(mostrar) {
  let p = document.getElementById("pastilha-trabalho");
  if (!mostrar) { if (p) p.remove(); return; }
  if (p || !TRABALHO) return;
  p = elemento("button", {
    type: "button",
    id: "pastilha-trabalho",
    class: "btn btn-mini",
    texto: `${TRABALHO.rotulo || "trabalho"} rodando… — reabrir`,
    /* O `marcarLinhasAbaixo` na reabertura não é zelo: de portas fechadas a
     * pastilha não pôde ser medida (ver a guarda lá em cima), então o número
     * que está nela é o do instante em que a gaveta sumiu. */
    onclick: () => abrirJanela(),
  });
  $("#barra-salvar").before(p);
}
$("#parar").addEventListener("click", async () => {
  if (!TRABALHO) return;
  await api("/api/parar", { method: "POST", body: JSON.stringify({ id: TRABALHO.id }) });
  torrada("Pedido de parada enviado", "igual");
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
     * seção quando não. */
    const porGrupo = new Map();
    for (const item of ESQUEMA.chaves) {
      /* O ajuste de um programa que esta máquina não tem não vira cartão, nem
       * conta no menu, nem aparece na busca: não há o que trocar. O valor
       * continua no arquivo. */
      if (item.sem_programa) continue;
      const nome = item.subsecao || item.secao || "Outras";
      if (!porGrupo.has(nome)) porGrupo.set(nome, []);
      porGrupo.get(nome).push(item);
    }
    /* O grupo guarda a SEÇÃO de onde veio: é ela que vira o nível de cima do
     * menu. Um trilho de vinte itens planos obriga a ler os vinte para achar um;
     * com dois níveis, ela lê cinco. */
    /* Quatro chaves do mesmo bloco — `FORMA_MARGEM_DOCK`, `FORMA_RAIO_DOCK`,
     * `FORMA_ESPACO_DOCK`, `FORMA_RECHEIO_DOCK` — dividem o comentário, então
     * dividiam o título. */
  for (const itens of porGrupo.values()) {
    /* O DONO DO COMENTÁRIO ENTRA NO GRUPO, e não só os herdeiros. */
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

    /* Três pares da aba Automação — `AUTO_REPARO`/`_NOTIFICAR`,
     * `ASSETS_VIGIA`/`_NOTIFICAR`, `FLATPAK_VIGIA`/`_NOTIFICAR` — não dividem
     * comentário entre si, mas a diferença DENTRO de cada par é a mesma
     * palavra: os três cartões viravam "Notificar". */
    const palavra = (p) => ROTULO_DE_VALOR[p] || p;
    const daCauda = (chave, n) => {
      const partes = chave.split("_").map((x) => x.toLocaleLowerCase("pt-BR"));
      return maiuscula(partes.slice(-n).map(palavra).join(" ")
        .toLocaleLowerCase("pt-BR"));
    };
    /* Cresce da direita para a esquerda até parar de colidir: "Notificar" ->
     * "Vigia notificar" -> "Assets vigia notificar". */
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
      /* As duas ações dos jogos moram dentro da própria tela de jogos, como as
       * de banir papel de parede moram dentro da galeria. */
      if (itens.every((a) => a.oculta)) continue;
      GRUPOS.push({ tipo: "acoes", nome, itens });
    }


    /* A galeria é um grupo do trilho como os outros — ela não é uma chave do
     * meow.conf, é o acervo em si, que neste projeto É a configuração ("soltou o
     * arquivo, entrou; apagou, saiu"). */
    /* A galeria e os ícones por aplicativo viviam numa aba "Fazer", ao lado do
     * botão que roda o instalador. */
    GRUPOS.push({ tipo: "galeria", assunto: "Papel de parede", nome: "A coleção", itens: [] });
    GRUPOS.push({ tipo: "apps", assunto: "Ícones", nome: "Um ícone por programa", itens: [] });
    /* O ASSUNTO É O NOME DA SEÇÃO DO `meow.conf.exemplo`, e ele mudou:
     * `Programas e jogos` virou `Lançadores e jogos`. */
    GRUPOS.push({ tipo: "jogos", assunto: "Lançadores e jogos", nome: "Os jogos instalados", itens: [] });

    /* AS FOLHAS SAÍRAM DO PAINEL: "remover estudos de tela, tem que sair, é
     * sobre meu pc". */

    /* A HOME É UM GRUPO, e é por isso que ela é a aba que abre por padrão
     * (`ABA = abaDoHash() || chaveDeAba(GRUPOS[0])`). Ela não é um assunto entre
     * os outros — é a porta, e por isso entra antes dos dois blocos do menu.
     * O NOME VEM DO SERVIDOR, como o das outras abas: é
     * de lá que o `--onde inicio` o dá aos scripts, e escrito aqui seria o
     * segundo dono de um nome de tela — o `install.sh` citava a «aba Início»
     * à mão. As chaves "Início" do `ICONES_MENU` e das prévias continuam
     * sendo o texto da aba, como as das seções. */
    GRUPOS.unshift({ tipo: "home", nome: ESQUEMA.aba_inicio, itens: [] });

    /* AS GALERIAS ENTRAM NO ASSUNTO A QUE PERTENCEM, e é por isso que a página
     * de papel de parede tem a coleção, os nove ajustes e as sete ações: os
     * três grupos respondem pelo mesmo assunto. */
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
  /* Eram em fila: o esquema, depois as pendências, depois os packs, e a
   * primeira pintura esperava a soma das três. */
  const [esquema] = await Promise.all([api("/api/esquema"), recarregarPendencias(), recarregarPacks()]);
  ESQUEMA = esquema;
  lerRestauros();
  publicarMedidas();
  if (ESQUEMA.erro) {
    /* O esqueleto sai também no erro: ele promete uma página que não vem. */
    $("#trilho").replaceChildren();
    $("#trilho").removeAttribute("aria-busy");
    $("#conteudo").removeAttribute("aria-busy");
    $("#conteudo").replaceChildren(elemento("p", { class: "vazio-msg", texto: ESQUEMA.erro }));
    return;
  }

  montarGrupos();
  /* O ouvinte de gesto é UM só, e nasce aqui: o `main` sobrevive a toda
   * pintura, então registrá-lo dentro do `render()` vazaria um por clique. */
  ouvirGestoDeRolagem();
  /* O balão próprio, pelo mesmo motivo: delegado no documento, uma vez. */
  ligarBalao();
  /* A bandeja volta ANTES da primeira pintura: restaurar depois do `render`
   * faria a página nascer limpa e piscar para o estado pendente. */
  restaurarBandeja();
  atualizarBarraSalvar();

  /* Uma aba que ainda guarde `meow-seco` no `sessionStorage` não muda nada:
   * ninguém mais lê essa chave.
   *
   * Este é um BOTÃO IRMÃO do Salvar: um gesto, uma pergunta, uma resposta.
   *
   * ELE NASCE AQUI porque o `app/pagina/index.html` está fora dos arquivos
   * desta frente; o lugar dele na barra é ANTES do Salvar, que é a ordem de
   * leitura de quem ainda não decidiu — vejo, depois aplico. */
  $("#botao-salvar").before(elemento("button", {
    type: "button", class: "btn btn-ensaio", id: "botao-ensaiar",
    texto: "Ver sem mudar",
    title: "Ensaia as escolhas sem gravar: o meow.conf não é tocado",
    onclick: () => salvarEscolhas(true),
  }));
  /* O `() =>` não é enfeite: passado direto, o `addEventListener` entrega o
   * MouseEvent como primeiro argumento, e o parâmetro `seco` do
   * `salvarEscolhas` nasceria valendo um evento — que é verdadeiro. */
  $("#botao-salvar").addEventListener("click", () => salvarEscolhas());
  $("#botao-descartar").addEventListener("click", descartarEscolhas);

  /* O painel fica de pé enquanto a janela existe e sai junto com ela — o que é
   * o desenho certo e está documentado em app/run.sh.
   *
   * O LIMIAR É O MESMO DO `descartarEscolhas` (app.js:651), e pelo mesmo
   * motivo já escrito lá: com UMA escolha, refazer é um clique, e a pergunta
   * vira burocracia. */
  window.addEventListener("beforeunload", (ev) => {
    if (MUDANCAS.size >= 2) ev.preventDefault();
  });
  /* O botão do aviso é o mesmo Salvar: sem escolha esperando, ele aplica o que
   * já está gravado — que é exatamente o que o aviso diz que falta. */
  /* Embrulhado pelo mesmo motivo do Salvar, dez linhas acima: este botão aplica
   * de verdade, e o MouseEvent entrando pelo `seco` o transformaria em ensaio. */
  $("#aviso-aplicar-botao").addEventListener("click", () => salvarEscolhas());
  $("#salvar-conta").addEventListener("click", alternarListaPendentes);
  /* Medido pelo censo do `tests/app-completo.py`, que conta o que recebe foco
   * ou tem papel de controle: o contador estava na tela e não existia para
   * ele. */
  $("#salvar-conta").setAttribute("role", "button");
  $("#salvar-conta").tabIndex = 0;
  $("#salvar-conta").addEventListener("keydown", (e) => {
    if (e.key !== "Enter" && e.key !== " ") return;
    e.preventDefault();
    alternarListaPendentes();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") document.getElementById("lista-pendentes")?.remove();
  });

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
  $("#rotulo-importar").addEventListener("click", () => $("#arquivo-importar").click());
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

  pintarResumo();
  render();
  $("#trilho").removeAttribute("aria-busy");
  $("#conteudo").removeAttribute("aria-busy");
}

/* --- O PULSO: ESTA PÁGINA É O INTERRUPTOR DO SERVIDOR ----------------------
 * Quem decide isso é o `servidor.py` (ver lá o bloco "O PAINEL MORRE COM A
 * JANELA QUE O ABRIU"); daqui sai só o sinal, e ele é uma conexão que fica
 * aberta — não uma batida por temporizador, que o Chrome estrangula em aba
 * oculta e congela de vez depois de alguns minutos.
 *
 * O `EventSource` reconecta sozinho quando cai, e é isso que faz o F5 e a troca
 * de papel de parede (que recarrega a página) não derrubarem o painel. */
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

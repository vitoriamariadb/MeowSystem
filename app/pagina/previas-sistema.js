/* app/pagina/previas-sistema.js — um desenho por bloco, metade dos "sistemas".
 *
 * POR QUE ESTE ARQUIVO EXISTE
 *   A dona do projeto olhou a própria tela e disse, com todas as letras, que
 *   não consegue usar o painel sozinha: "eu mesma tô extremamente confusa sobre
 *   o que tal coisa faz". O único lugar onde isso não acontece é o bloco FORMA
 *   de "Barra e dock", e o que ele tem de diferente não é texto melhor — é um
 *   desenho que responde ANTES da leitura e que muda quando o valor muda.
 *   Daí a regra: todo bloco tem um desenho, e o desenho reage aos valores do
 *   próprio bloco. Não é ilustração; é a resposta à pergunta "o que isto faz
 *   com a minha tela?".
 *
 *   O critério de qualidade de cada função aqui NÃO é "o traço ficou bonito".
 *   É: alguém que nunca abriu o meow.conf olha os dois desenhos e entende o que
 *   a chave faz. Um desenho correto que não passa nesse teste está errado.
 *
 * O QUE ESTE ARQUIVO DEVOLVE
 *   `window.MEOW_PREVIAS["Seção :: BLOCO"](v, escolhido)` devolve `{ antes,
 *   depois, legenda }` — o segundo argumento é opcional e traz só as chaves
 *   que ela mexeu e ainda não salvou:
 *     antes    SVGElement com os valores em vigor (ou o padrão, quando a chave
 *              está vazia);
 *     depois   o MESMO desenho com o valor que ela acabou de escolher, ou
 *              `null` quando não há escolha pendente no bloco;
 *     legenda  uma linha, começando por "desenho, não captura:", dizendo os
 *              números que foram desenhados.
 *   Os dois lados usam o mesmo viewBox e o mesmo enquadramento — desenho que
 *   muda de escala entre um e outro não deixa comparar nada, que é a única
 *   coisa que o par existe para permitir.
 *
 * TUDO AQUI DENTRO DE UMA FUNÇÃO, E ISSO NÃO É ESTILO
 *   A outra metade desta frente é `previas-tela.js`, escrita ao mesmo tempo,
 *   com o mesmo contrato e certamente com auxiliares de nome parecido
 *   (`linha`, `texto`, `moldura`…). Dois `<script>` clássicos dividem o MESMO
 *   escopo global, e dois `const linha` no topo dos dois arquivos são um
 *   SyntaxError na hora do parse — o segundo arquivo simplesmente não carrega,
 *   sem uma linha no console que diga qual dos dois brigou. A folha da frente
 *   mostra o mapa em nível de topo e não fala disso; a casca abaixo é o preço
 *   de uma linha para que a colisão não exista.
 *
 * O ESTILO DO TRAÇO É O DELA, DE 11/08/2026: "o nosso tema é o traço, não o
 *   chapado". Então `fill="none"` por padrão, ponta e canto arredondados, e
 *   preenchimento só onde ele é a informação (o vidro que esconde a janela
 *   atrás, a tarja preta de quem escolheu "caber"). Cor só de `currentColor` e
 *   das variáveis de `/paleta.css` — nenhum literal de cor neste arquivo, com
 *   uma exceção medida e explicada lá embaixo, no modo de leitura.
 */
"use strict";

(function () {
  "use strict";

  /* --- o quadro ----------------------------------------------------------- */
  /* UM viewBox SÓ PARA OS SETE, e ele é largo de propósito: todo desenho desta
   * metade é sobre uma TELA, e tela é larga. 100x60 é a proporção 5:3, que é o
   * que sobra de um monitor 16:9 depois da legenda e das margens do cartão.
   *
   * A folha pede "stroke-width por volta de 2 num viewBox de 48". Aqui a
   * unidade é outra, e copiar o 2 ao pé da letra num quadro duas vezes maior
   * daria metade do peso do desenho da FORMA — que é o vizinho com quem estes
   * sete vão dividir a tela. Então o traço fica em 2 mesmo, medido pelo lado
   * CURTO (2/60 contra 2/48 da folha): é o mesmo peso visual, não o mesmo
   * número.
   *
   * `height` em pixel e `width` em 100% deixam o desenho crescer com o cartão
   * sem nunca deformar — `preserveAspectRatio` de fábrica já centraliza. */
  const LARGURA = 100;
  const ALTURA = 60;
  const ALTURA_CSS = 120;      // dentro dos 90..140 que a folha pede

  const NS = "http://www.w3.org/2000/svg";

  /* Números que entram em atributo passam por aqui. Duas razões: um `NaN` num
   * atributo de SVG não levanta exceção nenhuma — ele apaga a forma em silêncio,
   * que é o pior defeito possível numa página que promete explicar —, e três
   * casas decimais em cada coordenada engordam o DOM sem mudar um pixel. */
  const q = (x) => (Number.isFinite(x) ? Math.round(x * 100) / 100 : 0);

  const aLista = (x) => (x === null || x === undefined ? [] : (Array.isArray(x) ? x : [x]));

  function no(nome, atributos, filhos) {
    const el = document.createElementNS(NS, nome);
    if (atributos) {
      for (const chave of Object.keys(atributos)) {
        const valor = atributos[chave];
        if (valor === null || valor === undefined || valor === false) continue;
        el.setAttribute(chave, String(valor));
      }
    }
    for (const filho of aLista(filhos)) {
      if (filho === null || filho === undefined || filho === false) continue;
      el.appendChild(typeof filho === "object" ? filho : document.createTextNode(String(filho)));
    }
    return el;
  }

  /* O `<title>` não é enfeite de acessibilidade: com `role="img"` ele É o
   * desenho para quem usa leitor de tela, e a promessa da frente ("o desenho
   * responde antes da leitura") só vale para os dois se ele descrever a mesma
   * coisa que o traço mostra. */
  function moldura(titulo) {
    const svg = no("svg", {
      viewBox: "0 0 " + LARGURA + " " + ALTURA,
      width: "100%",
      height: ALTURA_CSS,
      role: "img",
      focusable: "false",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 2,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
    });
    svg.appendChild(no("title", null, String(titulo)));
    return svg;
  }

  const grupo = (extra, filhos) => no("g", extra, filhos);

  const retangulo = (x, y, w, h, r, extra) => no("rect", Object.assign({
    x: q(x), y: q(y),
    width: q(Math.max(0, w)), height: q(Math.max(0, h)),
    rx: q(r || 0),
  }, extra || {}));

  const linha = (x1, y1, x2, y2, extra) => no("line", Object.assign({
    x1: q(x1), y1: q(y1), x2: q(x2), y2: q(y2),
  }, extra || {}));

  const circulo = (cx, cy, r, extra) => no("circle", Object.assign({
    cx: q(cx), cy: q(cy), r: q(Math.max(0, r)),
  }, extra || {}));

  const elipse = (cx, cy, rx, ry, extra) => no("ellipse", Object.assign({
    cx: q(cx), cy: q(cy), rx: q(Math.max(0, rx)), ry: q(Math.max(0, ry)),
  }, extra || {}));

  const caminho = (d, extra) => no("path", Object.assign({ d: d }, extra || {}));

  /* Texto dentro do desenho é sempre um NÚMERO ou um RÓTULO de uma palavra —
   * frase é trabalho da legenda. `stroke: none` porque o traço padrão do quadro
   * contornaria cada glifo e a 5 unidades isso vira borrão.
   *
   * O PISO DE TAMANHO É 4. Medido no pior caso: o par antes/depois lado a lado
   * num cartão estreito dá ~150 px de largura, ou seja 1,5 px por unidade —
   * texto de 4 unidades sai com 6 px, que é o limite do legível. Abaixo disso
   * o rótulo mente: ocupa espaço e não informa. */
  const texto = (x, y, conteudo, extra) => no("text", Object.assign({
    x: q(x), y: q(y),
    "font-size": 5,
    "text-anchor": "middle",
    fill: "currentColor",
    stroke: "none",
  }, extra || {}), String(conteudo));

  /* Polar com 0 no TOPO e sentido horário — a convenção do relógio, que é a que
   * o arco de 24 horas precisa. A direção do movimento em graus de tela (0 à
   * direita, positivo para baixo) coincide com o próprio ângulo polar, o que
   * dá a ponta da seta de graça. */
  function ponto(cx, cy, r, graus) {
    const rad = (graus - 90) * Math.PI / 180;
    return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
  }

  function arco(cx, cy, r, de, ate) {
    const p1 = ponto(cx, cy, r, de);
    const p2 = ponto(cx, cy, r, ate);
    const varre = ((ate - de) % 360 + 360) % 360;
    return "M " + q(p1.x) + "," + q(p1.y)
         + " A " + q(r) + "," + q(r) + " 0 " + (varre > 180 ? 1 : 0) + " 1 "
         + q(p2.x) + "," + q(p2.y);
  }

  function seta(x, y, direcaoGraus, tam) {
    const rad = direcaoGraus * Math.PI / 180;
    const a = rad + Math.PI * 0.8;
    const b = rad - Math.PI * 0.8;
    return grupo(null, [
      linha(x, y, x + tam * Math.cos(a), y + tam * Math.sin(a)),
      linha(x, y, x + tam * Math.cos(b), y + tam * Math.sin(b)),
    ]);
  }

  /* --- os glifos que se repetem ------------------------------------------- */

  function sol(cx, cy, r, extra) {
    const g = grupo(extra || null, [circulo(cx, cy, r * 0.55)]);
    for (let i = 0; i < 8; i++) {
      const a = i * 45;
      const p1 = ponto(cx, cy, r * 0.8, a);
      const p2 = ponto(cx, cy, r * 1.15, a);
      g.appendChild(linha(p1.x, p1.y, p2.x, p2.y));
    }
    return g;
  }

  /* A lua é o truque clássico dos dois arcos que abaulam para o mesmo lado: o
   * de fora com raio inteiro, o de dentro achatado no eixo x. Sai um crescente
   * aberto à direita, que é como quase todo mundo desenha lua. */
  function lua(cx, cy, r, extra) {
    return caminho(
      "M " + q(cx) + "," + q(cy - r)
      + " A " + q(r) + "," + q(r) + " 0 1 0 " + q(cx) + "," + q(cy + r)
      + " A " + q(r * 0.66) + "," + q(r) + " 0 1 1 " + q(cx) + "," + q(cy - r),
      extra || null);
  }

  function sino(cx, cy, tam, extra) {
    const w = tam * 0.62;
    const h = tam;
    return grupo(Object.assign({ "stroke-width": 1.4 }, extra || {}), [
      caminho(
        "M " + q(cx - w) + "," + q(cy + h * 0.5)
        + " C " + q(cx - w) + "," + q(cy - h * 0.2)
        + " " + q(cx - w * 0.7) + "," + q(cy - h * 0.9)
        + " " + q(cx) + "," + q(cy - h * 0.9)
        + " C " + q(cx + w * 0.7) + "," + q(cy - h * 0.9)
        + " " + q(cx + w) + "," + q(cy - h * 0.2)
        + " " + q(cx + w) + "," + q(cy + h * 0.5) + " Z"),
      linha(cx - 0.9, cy + h * 0.9, cx + 0.9, cy + h * 0.9),
    ]);
  }

  /* A TARJA DE AVISO — o que as chaves NOTIFICAR fazem de verdade.
   * O sino sozinho é um glifo de raio 4,5 num quadro de 100x60: dez pixels no
   * botão do par, e os dois lados desenhavam a mesma figura (0,53% dos pixels
   * diferentes, fotografados em 07/09/2026). E o sino ainda dizia a coisa
   * errada — a chave não pendura sino nenhum em lugar nenhum: ela manda o
   * `notify-send` pôr uma TARJA na tela dela. Então é a tarja que se desenha, no
   * tamanho em que uma tarja se vê.
   *
   * O PREENCHIMENTO AQUI É A INFORMAÇÃO, e é por isso que ele existe num arquivo
   * de traço: uma notificação é uma superfície opaca que aparece POR CIMA do que
   * ela está fazendo. Desligada, a mesma tarja fica só o contorno pontilhado com
   * o sino cortado — o lugar onde o aviso apareceria, e não aparece.
   *
   * A BARRA DA DIREITA É BARRA, E NÃO PALAVRA, de propósito: o texto da
   * notificação é o nome do arquivo (ou da imagem) que entrou, e ele não se sabe
   * na hora de desenhar. Inventar um nome seria a única mentira possível aqui. */
  function tarjaDeAviso(x, y, w, h, palavra, avisa) {
    const nome = emTexto(palavra);
    const fonte = Math.min(4.8, h * 0.62);
    const cy = y + h / 2;
    const rSino = h * 0.42;
    const xSino = x + h * 0.52;
    const fimDaPalavra = x + h + nome.length * fonte * 0.55;
    const g = grupo(avisa ? null : { opacity: 0.5 }, [
      retangulo(x, y, w, h, Math.min(2.5, h * 0.38), avisa
        ? { fill: "var(--surface1)", stroke: "var(--overlay1)", "stroke-width": 1 }
        : { "stroke-width": 1.1, "stroke-dasharray": "4 3" }),
      sino(xSino, cy, rSino, {
        stroke: "var(--mauve)", "stroke-width": q(Math.max(0.75, h * 0.1)),
      }),
      texto(x + h, cy + fonte * 0.36, nome, {
        "font-size": q(fonte), "text-anchor": "start",
      }),
    ]);
    /* A barra só entra se sobrar largura para ela SER barra: um toco de duas
     * unidades ao lado da palavra seria sujeira, não linha de texto. */
    const barra = (x + w - 3) - (fimDaPalavra + 2.5);
    if (barra >= 6) {
      g.appendChild(retangulo(fimDaPalavra + 2.5, cy - 0.75, barra, 1.5, 0.75, {
        fill: "var(--overlay1)", stroke: "none", opacity: 0.55,
      }));
    }
    if (!avisa) {
      g.appendChild(linha(xSino - rSino * 0.9, cy + rSino, xSino + rSino * 0.9, cy - rSino,
        { "stroke-width": q(Math.max(0.9, h * 0.12)) }));
    }
    return g;
  }

  function engrenagem(cx, cy, r, extra) {
    const g = grupo(extra || null, [circulo(cx, cy, r * 0.5)]);
    for (let i = 0; i < 8; i++) {
      const a = i * 45;
      const p1 = ponto(cx, cy, r * 0.72, a);
      const p2 = ponto(cx, cy, r, a);
      g.appendChild(linha(p1.x, p1.y, p2.x, p2.y));
    }
    return g;
  }

  /* --- ler o que veio ----------------------------------------------------- */
  /* `v` chega como `{ NOME_DA_CHAVE: "valor" }`, valores do jeito que estão no
   * meow.conf. Mas o par antes/depois só existe se der para saber o que ela
   * ACABOU DE ESCOLHER, e isso não cabe numa string por chave: com uma entrada
   * só, e sendo a função pura, `depois` seria `null` SEMPRE — a mesma entrada
   * não tem como dar dois desenhos diferentes. Daí o segundo argumento, que é
   * a convenção combinada entre as duas metades:
   *
   *     previa(v)                     -> depois: null (o caso comum)
   *     previa(v, escolhido)          -> depois desenhado com o que ela mexeu
   *
   * `escolhido` traz só as chaves ainda não salvas, no mesmo formato de `v`.
   * Escolha igual ao que já vale também devolve `null`: não há o que comparar.
   *
   * Por garantia este arquivo também aceita a escolha embutida no próprio `v`,
   * na forma `{ RELOGIO_SEGUNDOS: { valor: "nao", escolhido: "sim" } }` — quem
   * consome decide, e nenhuma das formas quebra a outra. */
  function primeiro() {
    for (let i = 0; i < arguments.length; i++) {
      if (arguments[i] !== undefined && arguments[i] !== null) return arguments[i];
    }
    return undefined;
  }

  const emTexto = (x) => (x === null || x === undefined ? "" : String(x).trim());
  const vazio = (x) => emTexto(x) === "";

  function normalizar(v, escolhido) {
    const agora = {};
    const depois = {};
    const bruto = (v && typeof v === "object") ? v : {};
    for (const chave of Object.keys(bruto)) {
      const item = bruto[chave];
      let atual = item;
      let pendente;
      if (item && typeof item === "object" && !Array.isArray(item)) {
        atual = primeiro(item.valor, item.atual, item.emVigor, item.em_vigor, "");
        pendente = primeiro(item.escolhido, item.escolha, item.pendente, item.novo);
      }
      agora[chave] = emTexto(atual);
      depois[chave] = (pendente === undefined) ? agora[chave] : emTexto(pendente);
    }
    const extras = (escolhido && typeof escolhido === "object") ? escolhido : {};
    for (const chave of Object.keys(extras)) {
      if (!(chave in agora)) agora[chave] = "";
      depois[chave] = emTexto(extras[chave]);
    }
    let mudou = false;
    for (const chave of Object.keys(depois)) {
      if (depois[chave] !== agora[chave]) mudou = true;
    }
    /* QUAIS CHAVES FORAM PEDIDAS — e isso não é o mesmo que quais mudaram.
     * O par de botões do `app.js` desenha o bloco INTEIRO para responder por uma
     * chave só, e chama esta função uma vez por lado: o botão da esquerda pede o
     * valor que JÁ vale. Se o desenho olhasse a DIFERENÇA para decidir a quem
     * dar destaque, o lado esquerdo (onde não há diferença) sairia num
     * enquadramento e o direito noutro — que é a única coisa que o par existe
     * para não fazer. Então o que sai daqui é o PEDIDO. */
    const pedidas = [];
    for (const chave of Object.keys(bruto)) {
      const item = bruto[chave];
      if (item && typeof item === "object" && !Array.isArray(item)
          && primeiro(item.escolhido, item.escolha, item.pendente, item.novo) !== undefined) {
        pedidas.push(chave);
      }
    }
    for (const chave of Object.keys(extras)) {
      if (pedidas.indexOf(chave) < 0) pedidas.push(chave);
    }
    return { agora: agora, depois: depois, mudou: mudou, pedidas: pedidas };
  }

  /* Sem acento e em caixa baixa: o meow.conf escreve `aleatoria`, mas quem
   * edita o arquivo à mão num teclado pt_BR escreve `aleatória` metade das
   * vezes, e recusar a segunda seria transformar um acerto em erro. */
  function achatar(s) {
    return emTexto(s).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
  }

  const SIM = ["sim", "s", "1", "true", "yes", "on"];
  const NAO = ["nao", "n", "0", "false", "no", "off"];

  function ligado(valor, padrao) {
    const s = achatar(valor);
    if (SIM.indexOf(s) >= 0) return true;
    if (NAO.indexOf(s) >= 0) return false;
    return !!padrao;
  }

  const booleanoValido = (s) => (SIM.indexOf(achatar(s)) >= 0 || NAO.indexOf(achatar(s)) >= 0);

  /* FORA DA FAIXA É INVÁLIDO, E INVÁLIDO DESENHA O PADRÃO — não o extremo.
   * Grampear um `-5` em 0 e um `999` em 1 desenharia uma barra invisível e uma
   * barra opaca, as duas com cara de escolha deliberada; e o `999` do
   * MIDIA_LARGURA nem chega a ser gravado (a chave o recusa). O desenho que
   * responde à verdade é o do padrão, com a legenda dizendo que o valor escrito
   * não serve. */
  /* `parseFloat` sozinho não serve de leitor: ele lê "25:99" como 25 e "1.0.0"
   * como 1, e um número que veio de um texto que não era número entraria no
   * desenho como se fosse escolha. A linha inteira tem de ser um número. */
  function paraNumero(valor) {
    const s = emTexto(valor).replace(",", ".");
    if (!/^[+-]?\d+(?:\.\d+)?$/.test(s)) return NaN;
    return parseFloat(s);
  }

  function numero(valor, padrao, min, max) {
    const n = paraNumero(valor);
    if (!Number.isFinite(n) || n < min || n > max) return padrao;
    return n;
  }

  const numeroValido = (s, min, max) => {
    const n = paraNumero(s);
    return Number.isFinite(n) && n >= min && n <= max;
  };

  function escolha(valor, opcoes, padrao) {
    const s = achatar(valor);
    for (const o of opcoes) if (achatar(o) === s) return o;
    return padrao;
  }

  const escolhaValida = (s, opcoes) => opcoes.some((o) => achatar(o) === achatar(s));

  /* "18:00" vira 1080 minutos. Devolve também o rótulo já normalizado, porque a
   * legenda tem de dizer a hora do jeito que o relógio a lê, não do jeito que
   * ela foi digitada. */
  function relogio(valor, padraoMinutos) {
    const m = /^(\d{1,2})\s*:\s*(\d{1,2})$/.exec(emTexto(valor));
    if (!m) return { min: padraoMinutos, rotulo: doRelogio(padraoMinutos), ok: false };
    const h = parseInt(m[1], 10);
    const mi = parseInt(m[2], 10);
    if (!(h >= 0 && h <= 23 && mi >= 0 && mi <= 59)) {
      return { min: padraoMinutos, rotulo: doRelogio(padraoMinutos), ok: false };
    }
    const total = h * 60 + mi;
    return { min: total, rotulo: doRelogio(total), ok: true };
  }

  function doRelogio(minutos) {
    const m = ((Math.round(minutos) % 1440) + 1440) % 1440;
    const h = Math.floor(m / 60);
    const r = m % 60;
    return (h < 10 ? "0" : "") + h + ":" + (r < 10 ? "0" : "") + r;
  }

  /* "30s", "5m", "2h", "1d" — a mesma gramática que o `wallpaper.sh` entende.
   * Número solto conta como minuto. */
  function duracao(valor, padraoTexto) {
    const s = achatar(valor);
    const m = /^(\d+(?:[.,]\d+)?)\s*([smhd])?$/.exec(s);
    if (!m) return Object.assign(duracao(padraoTexto, "5m"), { ok: false });
    const n = parseFloat(m[1].replace(",", "."));
    const unidade = m[2] || "m";
    const fator = { s: 1 / 60, m: 1, h: 60, d: 1440 }[unidade];
    /* Número sem letra é minuto, e o rótulo diz a unidade em vez de deixar um
     * "999" solto na legenda — que tanto pode ser minuto quanto segundo para
     * quem está lendo. */
    return {
      minutos: n * fator,
      rotulo: m[2] ? emTexto(valor).replace(",", ".") : (m[1].replace(",", ".") + " min"),
      ok: true,
    };
  }

  function lista(valor, separador) {
    return emTexto(valor).split(separador).map((x) => x.trim()).filter(Boolean);
  }

  const NOMES_DA_PALETA = [
    "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow",
    "green", "teal", "sky", "sapphire", "blue", "lavender", "text", "subtext1",
    "subtext0", "overlay2", "overlay1", "overlay0", "surface2", "surface1",
    "surface0", "base", "mantle", "crust",
  ];

  /* NUNCA interpolar texto do meow.conf dentro de um `var(--…)` sem conferir
   * contra esta lista. Não é medo de execução — é que um nome inventado vira
   * uma variável que não existe, a cor cai para o valor de fallback e o desenho
   * mente sobre o que está gravado, calado. */
  function corDaPaleta(valor, padrao) {
    const s = achatar(valor);
    if (s === "auto" || s === "") return "currentColor";
    if (NOMES_DA_PALETA.indexOf(s) >= 0) return "var(--" + s + ")";
    return padrao;
  }

  const corValida = (s) => (achatar(s) === "auto" || NOMES_DA_PALETA.indexOf(achatar(s)) >= 0);

  function cortar(s, quantos) {
    const n = Math.max(1, Math.floor(quantos));
    if (s.length <= n) return s;
    return s.slice(0, Math.max(1, n - 1)) + "…";
  }

  const pct = (x) => Math.round(x * 100);

  /* Plural na legenda. Parece detalhe e não é: "1 dos 1 programas" e "2 pasta
   * sua" são o tipo de frase que faz quem lê desconfiar de tudo o que está
   * escrito ao redor. */
  const plural = (n, um, muitos) => n + " " + (Math.abs(n) === 1 ? um : muitos);

  /* --- as legendas --------------------------------------------------------- */
  /* O PADRÃO DA FRASE É O DA FORMA, e ele é curto de propósito: uma linha, os
   * números desenhados, e o aviso de vazio quando há vazio. A folha crava a
   * frase do vazio falando em COSMIC — e ela só é verdade para as chaves que o
   * COSMIC também escreve (as duas opacidades, o relógio). Para uma chave que é
   * só nossa, dizer "o COSMIC decide" seria mentira; aí a frase é a do padrão
   * de fábrica. É a divergência desta metade em relação à folha, e ela está
   * aqui em vez de escondida. */
  const VAZIO_COSMIC = "vazio no meow.conf significa que o COSMIC decide, e aqui aparece o padrão dele";
  const VAZIO_FABRICA = "vazio no meow.conf significa que vale o padrão de fábrica, e é ele que aparece aqui";

  function montarLegenda(corpo, notas) {
    let frase = "desenho, não captura: " + String(corpo).replace(/\s+/g, " ").trim();
    const extras = aLista(notas).filter(Boolean);
    if (extras.length) frase += " — " + extras.join("; ");
    return /[.!?…]$/.test(frase) ? frase : frase + ".";
  }

  /* Conferência de valores para a legenda: quais chaves do bloco estão vazias e
   * quais trazem coisa que a chave não aceita. As duas informações mudam o que
   * o desenho mostra, então as duas têm de aparecer escritas. */
  function conferir(val, regras) {
    const vazias = [];
    const erradas = [];
    for (const regra of regras) {
      const s = emTexto(val[regra.chave]);
      if (s === "") { vazias.push(regra.chave); continue; }
      if (regra.ok && !regra.ok(s)) erradas.push(regra.chave);
    }
    return { vazias: vazias, erradas: erradas };
  }

  function notaDeErradas(erradas) {
    if (!erradas.length) return "";
    const nomes = erradas.slice(0, 2).join(" e ") + (erradas.length > 2 ? " (e outras)" : "");
    return nomes + " tem valor que a chave não aceita, e o desenho mostra o padrão";
  }

  /* --- a casca que nunca deixa a exceção subir ----------------------------- */
  /* Um desenho que quebra apaga a página inteira: quem consome monta os cartões
   * num laço só, e uma exceção no terceiro cartão leva os outros noventa junto.
   * Então cada entrada do mapa é embrulhada aqui, e o pior caso desta função é
   * um quadro vazio com a legenda dizendo que o desenho falhou — nunca o
   * silêncio, e nunca a página branca. */
  function seguro(titulo, desenhar, legendar) {
    return function (v, escolhido) {
      let leitura;
      try {
        leitura = normalizar(v, escolhido);
      } catch (e) {
        leitura = { agora: {}, depois: {}, mudou: false, pedidas: [] };
      }
      const pedidas = leitura.pedidas || [];
      let antes = null;
      let depois = null;
      let legenda = "";
      try {
        antes = desenhar(leitura.agora, pedidas);
      } catch (e) {
        antes = quadroDeSocorro(titulo);
      }
      try {
        depois = leitura.mudou ? desenhar(leitura.depois, pedidas) : null;
      } catch (e) {
        depois = null;
      }
      try {
        legenda = legendar(leitura.agora, leitura.mudou ? leitura.depois : null);
      } catch (e) {
        legenda = montarLegenda(titulo + " (não deu para ler os valores desta seção)");
      }
      if (!legenda) legenda = montarLegenda(titulo);
      /* A frase que diz "e o da direita é a escolha pendente" NÃO nasce aqui.
       * Ela era escrita neste ponto e por isso saía só nos desenhos deste
       * arquivo — as dez prévias do `previas-tela.js` ficavam com uma legenda
       * que descrevia a esquerda sem dizer que descrevia a esquerda. Medido em
       * "Cor e tela": com latte escolhido, o `<title>` do SVG da direita já
       * dizia "latte" e a frase embaixo dos dois continuava dizendo "mocha".
       * Agora quem a acrescenta é o `parDePrevias` do `app.js`, uma vez, para
       * todo desenho que ganhe par. */
      return { antes: antes, depois: depois, legenda: legenda };
    };
  }

  function quadroDeSocorro(titulo) {
    try {
      const svg = moldura(titulo);
      svg.appendChild(retangulo(4, 8, 92, 44, 4, {
        "stroke-dasharray": "4 4", opacity: 0.5, "stroke-width": 1.6,
      }));
      return svg;
    } catch (e) {
      return null;
    }
  }

  /* ======================================================================== */
  /* 1. Barra e dock :: VIDRO E RELÓGIO                                        */
  /* ======================================================================== */
  /* A PERGUNTA QUE O DESENHO RESPONDE: "0 é transparente, 1 é opaco" não diz
   * nada sozinho — transparente em cima de quê? A resposta é a janela
   * maximizada ATRÁS da barra. Por isso o desenho põe uma janela com texto
   * embaixo do painel e embaixo da dock: onde a barra é translúcida, as linhas
   * da janela atravessam; onde ela é opaca, somem. É a mesma pergunta que o
   * VIDRO_AO_MAXIMIZAR faz, e são as duas no mesmo quadro porque na tela dela
   * elas também são a mesma cena.
   *
   * O relógio entra com o texto, e não com um ponteiro: RELOGIO_SEGUNDOS mexe
   * no relógio DIGITAL da barra de cima. "9:41" e "9:41:07" lado a lado é a
   * diferença inteira, sem uma palavra.
   *
   * O 0,8 de padrão não é chute: é o mesmo número que o desenho da FORMA já usa
   * quando as chaves estão vazias, e duas prévias vizinhas discordando do
   * padrão seria a pior coisa que este arquivo poderia fazer. */
  const REGRAS_VIDRO = [
    { chave: "VIDRO_AO_MAXIMIZAR", ok: booleanoValido },
    { chave: "VIDRO_OPACIDADE_PAINEL", ok: (s) => numeroValido(s, 0, 1) },
    { chave: "VIDRO_OPACIDADE_DOCK", ok: (s) => numeroValido(s, 0, 1) },
    { chave: "RELOGIO_SEGUNDOS", ok: booleanoValido },
  ];

  function lerVidro(val) {
    const manter = ligado(val.VIDRO_AO_MAXIMIZAR, true);
    const painel = numero(val.VIDRO_OPACIDADE_PAINEL, 0.8, 0, 1);
    const dock = numero(val.VIDRO_OPACIDADE_DOCK, 0.8, 0, 1);
    return {
      manter: manter,
      painel: painel,
      dock: dock,
      /* Com "nao" e uma janela maximizada, o COSMIC devolve o comportamento de
       * fábrica: as duas ficam opacas. O desenho obedece a isso — mostrar 19%
       * numa cena onde o valor não vale seria desenhar uma coisa que ela nunca
       * vai ver. */
      painelDesenhada: manter ? painel : 1,
      dockDesenhada: manter ? dock : 1,
      segundos: ligado(val.RELOGIO_SEGUNDOS, false),
    };
  }

  function desenharVidro(val, pedidas) {
    const d = lerVidro(val);
    /* O RELÓGIO DE PERTO, E SÓ NO CARTÃO DELE
     * O que o RELOGIO_SEGUNDOS governa são três caracteres: "9:41" vira
     * "9:41:07". No relógio da barra isso dá 0,92% dos pixels do botão (medido
     * em 07/09/2026) e os dois lados saem a mesma figura. Aumentar o relógio DA
     * BARRA para resolver seria mentir sobre o tamanho do relógio dela; então
     * entra a mesma gramática de desenho técnico da cota da largura da música,
     * aqui embaixo: o canto direito da barra aparece de novo, ampliado, com o
     * mesmo recheio e a mesma opacidade — é aquele pedaço, de perto.
     * Nos outros três cartões deste bloco a ampliação não aparece: lá o assunto
     * é o vidro, que já ocupa o quadro inteiro. */
    const perto = Array.isArray(pedidas) && pedidas.length === 1
      && pedidas[0] === "RELOGIO_SEGUNDOS";
    const svg = moldura("o painel e a dock sobre uma janela maximizada, com o relógio da barra"
      + (perto ? ", e o mesmo relógio ampliado no meio" : ""));

    svg.appendChild(retangulo(2, 3, 96, 54, 3.5, { "stroke-width": 1.6, opacity: 0.55 }));
    svg.appendChild(retangulo(6, 7, 88, 45, 2, { "stroke-width": 1.3, opacity: 0.45 }));

    /* O conteúdo da janela é o que PROVA a transparência, e por isso as linhas
     * que passam por baixo da barra e por baixo da dock são desenhadas mais
     * fortes que as outras: a primeira versão deste desenho tinha uma linha só
     * atrás do painel, fraca, e a diferença entre 19% e 80% não aparecia — a
     * conferência a olho mostrou dois desenhos idênticos onde deveria haver a
     * resposta inteira da chave. */
    const linhas = [[9, 66], [14, 78], [22, 76], [27, 46], [32, 66], [37, 52], [42, 74], [48.5, 58]];
    for (const [y, largura] of linhas) {
      const atras = (y < 17) || (y > 43);
      svg.appendChild(linha(11, y, 11 + largura, y, {
        "stroke-width": atras ? 2 : 1.6, opacity: atras ? 0.8 : 0.35,
      }));
    }

    /* `--surface2` e não `--surface0`: o fundo da página já é `--base`, e uma
     * superfície vizinha dela some no próprio fundo quando a opacidade cai. O
     * tom médio é o único que dá para ver mudando de 0 a 1 nos quatro sabores. */
    svg.appendChild(retangulo(6, 5, 88, 12, 3, {
      fill: "var(--surface2)", "fill-opacity": q(d.painelDesenhada), "stroke-width": 1.4,
    }));
    for (const x of [12, 16.5, 21]) {
      svg.appendChild(circulo(x, 11, 1.2, { fill: "currentColor", stroke: "none" }));
    }
    svg.appendChild(texto(90, 13.4, d.segundos ? "9:41:07" : "9:41", {
      "font-size": 6.5, "text-anchor": "end",
    }));

    if (perto) {
      /* A moldura da ampliação é a MESMA receita da barra — `--surface2` com a
       * opacidade do painel —, e é isso que a faz ler como "aquele pedaço" em
       * vez de um cartaz colado por cima: as linhas da janela continuam
       * atravessando por baixo dela, do mesmo jeito que atravessam a barra.
       * As duas linhas de chamada saem das quinas do cerco do relógio pequeno. */
      const chamada = { "stroke-width": 0.8, "stroke-dasharray": "2 1.6", opacity: 0.55 };
      svg.appendChild(retangulo(62, 7.2, 29.5, 8, 1.6, chamada));
      svg.appendChild(linha(62, 15.2, 6, 19, chamada));
      svg.appendChild(linha(91.5, 15.2, 94, 19, chamada));
      svg.appendChild(retangulo(5, 19, 90, 24, 3, {
        fill: "var(--surface2)", "fill-opacity": q(d.painelDesenhada), "stroke-width": 1.4,
      }));
      /* 22 é o maior corpo em que "9:41:07" ainda cabe nesta moldura, e é o
       * ponto: no botão de 228 px o relógio sai com a altura em que ela lê o
       * relógio da barra na TV. */
      svg.appendChild(texto(89, 37.6, d.segundos ? "9:41:07" : "9:41", {
        "font-size": 22, "text-anchor": "end",
      }));
    }

    svg.appendChild(retangulo(31, 44, 38, 9, 4, {
      fill: "var(--surface2)", "fill-opacity": q(d.dockDesenhada), "stroke-width": 1.4,
    }));
    for (const x of [39, 46, 53, 60]) {
      svg.appendChild(circulo(x, 48.5, 1.4, { fill: "currentColor", stroke: "none" }));
    }
    return svg;
  }

  function legendaVidro(val) {
    const d = lerVidro(val);
    const c = conferir(val, REGRAS_VIDRO);
    const corpo = "uma janela maximizada com o painel a " + pct(d.painelDesenhada) + "%"
      + " e a dock a " + pct(d.dockDesenhada) + "%, "
      + (d.manter ? "o vidro mantido" : "o vidro desligado (com janela maximizada as duas ficam opacas)")
      + " e o relógio " + (d.segundos ? "com" : "sem") + " segundos";
    return montarLegenda(corpo, [
      notaDeErradas(c.erradas),
      c.vazias.length ? VAZIO_COSMIC : "",
    ]);
  }

  /* ======================================================================== */
  /* 2. Barra e dock :: MÚSICA NA BARRA                                        */
  /* ======================================================================== */
  /* A PERGUNTA: "quantos pixels o nome da música pode ocupar antes de virar
   * reticências" é impossível de responder de cabeça. Então o desenho mostra a
   * pastilha inteira e, embaixo dela, a MEDIDA — a mesma cota que um desenho
   * técnico usa —, com o nome cortando de verdade quando a largura não dá.
   *
   * A calibração não é livre: ela foi ajustada para reproduzir o fato medido
   * que está no meow.conf — em 260 (o número do upstream) o nome corta, em 440
   * (o dela) cabe. Um desenho que coubesse nos dois faria a chave parecer
   * inútil; um que cortasse nos dois faria o 440 dela parecer errado.
   *
   * A cor do álbum é uma cor de disco, não da paleta — o próprio meow.conf
   * mede que ela SEMPRE destoa do Catppuccin. Como não há hex neste arquivo, o
   * lugar dela é ocupado por `var(--peach)` e a legenda diz que é exemplo: o
   * que o desenho precisa responder é ONDE a cor entra (no traço ou no fundo),
   * não qual ela é. */
  const REGRAS_MIDIA = [
    { chave: "MIDIA", ok: booleanoValido },
    { chave: "MIDIA_LARGURA", ok: (s) => numeroValido(s, 80, 900) },
    { chave: "MIDIA_COR_ALBUM", ok: (s) => escolhaValida(s, ["traco", "chapado"]) },
    { chave: "MIDIA_CAPA", ok: booleanoValido },
    { chave: "MIDIA_FONTE", ok: (s) => achatar(s) === "auto" || numeroValido(s, 6, 48) },
    { chave: "MIDIA_COR_TITULO", ok: corValida },
    { chave: "MIDIA_COR_ARTISTA", ok: corValida },
    { chave: "MIDIA_CONTROLES", ok: booleanoValido },
  ];

  const COR_DO_ALBUM = "var(--peach)";

  /* O ENQUADRAMENTO: A BARRA EM CIMA, O APPLET AMPLIADO EMBAIXO — 07/09/2026
   *   A primeira versão desenhava a barra inteira na escala da barra, e nela o
   *   applet cabia num naco de 56x18 unidades. Medido nos dois botões do
   *   cartão, no tamanho em que eles aparecem (228x96): trocar `MIDIA_CAPA`
   *   mudava 1,51% dos pixels, e `MIDIA_CONTROLES`, os mesmos 1,51% —
   *   tecnicamente dois desenhos, a mesma figura para quem olha. Os pares que
   *   funcionam neste painel vivem entre 6% e 20%.
   *
   *   O conserto é de ENQUADRAMENTO, e não de capricho: o assunto do bloco é o
   *   applet, então é ele que ocupa o quadro. A tira de cima continua sendo a
   *   barra — com o relógio, que é o vizinho que o próprio bloco cita, e com os
   *   outros applets em cinza — e as duas linhas pontilhadas são a chamada de
   *   detalhe que todo desenho técnico usa: "o que está marcado ali é isto
   *   aqui, ampliado". A seção não sumiu; virou o contexto, que é o papel dela.
   *
   * A CAPA E A COR SÃO A MESMA CHAVE, E O DESENHO NÃO PODE SEPARÁ-LAS
   *   `MIDIA_CAPA` não é "mostrar a capa": é BAIXAR a capa quando o tocador
   *   publica `mpris:artUrl` como link (`album-art-remote`, em
   *   `scripts/midia.sh`). O Spotify só publica link. E a cor dominante é
   *   EXTRAÍDA do arquivo da capa — sem imagem no disco não há de onde tirá-la.
   *   As duas queixas dela caíam na mesma linha do `src/media.rs`, e por isso
   *   em "não" o desenho tira as duas coisas: o quadrado da capa (que o applet
   *   nem chega a pôr no `Row`, ele some, não fica um vazio) e a cor do álbum
   *   do botão inteiro. Um tocador local que publica arquivo continua com capa
   *   mesmo em "não" — é o que a legenda diz, porque o desenho mostra o caso
   *   dela, que é o Spotify.
   *
   * O `ZOOM` NÃO MEXE NA CALIBRAÇÃO DA LARGURA, e isso é o que permite ampliar
   *   sem refazer a conta: ele multiplica a largura desenhada do nome E o
   *   tamanho da letra pelo mesmo número, e `cabem` é a razão entre os dois. O
   *   fato medido lá em cima continua de pé — em 260 o nome corta, em 440
   *   cabe. */
  const TIRA = { y: 3, h: 10, x: 26 };   // a barra, e onde o applet se apoia nela
  const LUPA = { x: 2, y: 19, h: 26 };   // o applet ampliado
  const RECUO = 3.5;                     // a folga interna do botão do applet
  const CAPA_LADO = 17;                  // o quadrado da capa, no aumento
  const PASSO_BOTAO = 11;                // um ⏮ ⏸ ⏭ e o vão até o seguinte
  const ZOOM = 1.15;

  function lerMidia(val) {
    const larguraPx = numero(val.MIDIA_LARGURA, 440, 80, 900);
    const auto = achatar(val.MIDIA_FONTE) === "auto" || vazio(val.MIDIA_FONTE);
    const fontePx = auto ? 0 : numero(val.MIDIA_FONTE, 12, 6, 48);
    /* 5 unidades é a letra que o painel usa quando a chave diz `auto`; a partir
     * daí o tamanho cravado sobe na mesma proporção, e o teto de 10 existe só
     * para o desenho não sair do quadro — que já é o sintoma que a chave
     * descreve, e ele aparece de qualquer jeito. */
    const fonte = (auto ? 5 : Math.max(3, Math.min(10, 5 * (fontePx / 12)))) * ZOOM;
    const larguraDesenhada = (7 + (larguraPx / 900) * 31) * ZOOM;
    const capa = ligado(val.MIDIA_CAPA, true);
    const controles = ligado(val.MIDIA_CONTROLES, false);
    /* A ORDEM DO `Row` DO APPLET: [capa][nome · banda][⏮⏸⏭], e o botão é
     * `Length::Shrink` — ele mede o próprio conteúdo. Então tirar a capa
     * encosta o nome na borda esquerda, e pôr os três controles alarga o botão
     * de verdade. É essa conta, e não um enfeite, que move as bordas aqui. */
    const textoX = LUPA.x + RECUO + (capa ? CAPA_LADO + RECUO : 0);
    const fimTexto = textoX + larguraDesenhada;
    const trioX = fimTexto + RECUO;
    const fimConteudo = controles ? trioX + PASSO_BOTAO * 3 - 2 : fimTexto;
    return {
      ligada: ligado(val.MIDIA, true),
      larguraPx: larguraPx,
      larguraDesenhada: larguraDesenhada,
      chapado: escolha(val.MIDIA_COR_ALBUM, ["traco", "chapado"], "traco") === "chapado",
      capa: capa,
      controles: controles,
      auto: auto,
      fontePx: fontePx,
      fonte: fonte,
      corTitulo: corDaPaleta(val.MIDIA_COR_TITULO, "var(--mauve)"),
      corArtista: corDaPaleta(val.MIDIA_COR_ARTISTA, "var(--green)"),
      cabem: Math.max(1, Math.floor(larguraDesenhada / (fonte * 0.52))),
      textoX: textoX,
      trioX: trioX,
      larguraApplet: fimConteudo + RECUO - LUPA.x,
    };
  }

  function desenharMidia(val) {
    const d = lerMidia(val);
    const svg = moldura("a barra da dock em cima e, ampliado, o applet de música: capa, nome, os três botões e a medida da largura");

    /* A tira corre para fora dos dois lados de propósito: é um PEDAÇO da barra,
     * e um pedaço não promete onde ficam as pontas dela. */
    svg.appendChild(retangulo(-12, TIRA.y, 124, TIRA.h, 4, {
      fill: "var(--surface0)", "fill-opacity": 0.45, "stroke-width": 1.2, opacity: 0.85,
    }));
    svg.appendChild(texto(96, TIRA.y + TIRA.h * 0.74, "9:41", {
      "font-size": 5.5, "text-anchor": "end",
    }));
    /* Os outros applets. Não são enfeite: é para dentro deles que o botão
     * cresce quando ela liga os três controles, e é o aperto da asa que o
     * meow.conf mede quando fala em empurrar bluetooth e rede para o `⋯`. */
    for (const x of [60, 68, 76]) {
      svg.appendChild(retangulo(x, TIRA.y + 2.5, 5, 5, 1.5, { "stroke-width": 1, opacity: 0.3 }));
    }

    if (!d.ligada) {
      /* Desligar não é "ficar sem a cor": é a pastilha inteira sair da barra, e
       * o applet do flatpak voltar no próximo login. O vazio pontilhado no
       * lugar dela, nos dois tamanhos, é a resposta. */
      svg.appendChild(retangulo(TIRA.x, TIRA.y + 1.5, 16, TIRA.h - 3, 2, {
        "stroke-dasharray": "2.5 2.5", "stroke-width": 1.1, opacity: 0.45,
      }));
      svg.appendChild(retangulo(LUPA.x, LUPA.y, 53, LUPA.h, 5, {
        "stroke-dasharray": "3.5 3.5", "stroke-width": 1.6, opacity: 0.5,
      }));
      svg.appendChild(linha(LUPA.x + 7, LUPA.y + LUPA.h - 6, LUPA.x + 46, LUPA.y + 6, {
        "stroke-width": 1.3, opacity: 0.35,
      }));
      return svg;
    }

    /* SEM CAPA NO DISCO NÃO HÁ COR DE ÁLBUM. Ver o cabeçalho: a cor dominante
     * sai da imagem, e o botão volta à cor do painel quando ela não existe. */
    const temCor = d.capa;
    const tinta = temCor ? COR_DO_ALBUM : "currentColor";
    const corGlifo = (temCor && !d.chapado) ? COR_DO_ALBUM : "currentColor";
    const pintura = (largura) => (temCor && d.chapado
      ? { fill: COR_DO_ALBUM, "fill-opacity": 0.45, stroke: "none" }
      : { stroke: tinta, "stroke-width": largura, opacity: temCor ? 1 : 0.75 });

    /* A pegada do applet na barra, e o aumento dela embaixo. As duas linhas
     * pontilhadas ligam uma à outra — sem elas, o desenho de baixo seria uma
     * pastilha flutuando fora de qualquer lugar. */
    const tiraLarg = d.larguraApplet * 0.3;
    svg.appendChild(retangulo(TIRA.x, TIRA.y + 1.5, tiraLarg, TIRA.h - 3, 2, pintura(1.2)));
    for (const par of [[TIRA.x, LUPA.x], [TIRA.x + tiraLarg, LUPA.x + d.larguraApplet]]) {
      svg.appendChild(linha(par[0], TIRA.y + TIRA.h, par[1], LUPA.y, {
        "stroke-width": 0.9, "stroke-dasharray": "2 2", opacity: 0.4,
      }));
    }
    svg.appendChild(retangulo(LUPA.x, LUPA.y, d.larguraApplet, LUPA.h, 5, pintura(1.9)));

    const meio = LUPA.y + LUPA.h / 2;
    if (d.capa) {
      const cx = LUPA.x + RECUO;
      const cy = meio - CAPA_LADO / 2;
      svg.appendChild(retangulo(cx, cy, CAPA_LADO, CAPA_LADO, 2.5, {
        "stroke-width": 1.6, stroke: corGlifo,
      }));
      const nx = cx + CAPA_LADO * 0.34;
      const ny = cy + CAPA_LADO * 0.72;
      svg.appendChild(circulo(nx, ny, 2.3, { "stroke-width": 1.5, stroke: corGlifo }));
      svg.appendChild(linha(nx + 2.3, ny, nx + 2.3, cy + CAPA_LADO * 0.2, { "stroke-width": 1.5, stroke: corGlifo }));
      svg.appendChild(linha(nx + 2.3, cy + CAPA_LADO * 0.2, nx + 7, cy + CAPA_LADO * 0.34, { "stroke-width": 1.5, stroke: corGlifo }));
    }

    /* A pastilha cresce com a letra. Com `MIDIA_FONTE` cravado em 30 ou 48 a
     * banda desce para fora do botão — que é exatamente o defeito que ela
     * reparou primeiro em 24/08/2026, quando o applet passava o tamanho do
     * ÍCONE como tamanho da FONTE. O desenho mostra o transbordo em vez de
     * escondê-lo. */
    const yTitulo = meio - d.fonte * 0.21 - 0.75;
    const yArtista = yTitulo + d.fonte * 0.95 + 1.5;
    svg.appendChild(texto(d.textoX, yTitulo, cortar("A música", d.cabem), {
      "font-size": q(d.fonte), "text-anchor": "start", fill: d.corTitulo,
    }));
    svg.appendChild(texto(d.textoX, yArtista, cortar("A banda", d.cabem), {
      "font-size": q(d.fonte * 0.85), "text-anchor": "start", fill: d.corArtista,
    }));

    if (d.controles) {
      /* DO TAMANHO QUE ELES TÊM: no `src/ui.rs` do applet o ícone de controle é
       * pedido na MESMA medida do ícone da capa (`.size(size.0)` para os dois),
       * então desenhá-los como três risquinhos ao lado de uma capa grande seria
       * desenhar outro applet. Cheios porque `media-skip-*-symbolic` é glifo
       * cheio, e é assim que eles aparecem na barra. */
      const alt = 15;
      const topo = meio - alt / 2;
      const base = meio + alt / 2;
      const cheio = { fill: corGlifo, stroke: corGlifo, "stroke-width": 1 };
      const x0 = d.trioX;
      svg.appendChild(retangulo(x0, topo, 2, alt, 0.6, cheio));
      svg.appendChild(caminho("M " + q(x0 + 9) + "," + q(topo)
        + " L " + q(x0 + 9) + "," + q(base) + " L " + q(x0 + 2) + "," + q(meio) + " Z", cheio));
      const x1 = x0 + PASSO_BOTAO;
      svg.appendChild(retangulo(x1 + 1.2, topo, 2.6, alt, 0.6, cheio));
      svg.appendChild(retangulo(x1 + 5.2, topo, 2.6, alt, 0.6, cheio));
      const x2 = x0 + PASSO_BOTAO * 2;
      svg.appendChild(caminho("M " + q(x2) + "," + q(topo)
        + " L " + q(x2) + "," + q(base) + " L " + q(x2 + 7) + "," + q(meio) + " Z", cheio));
      svg.appendChild(retangulo(x2 + 7, topo, 2, alt, 0.6, cheio));
    }

    /* A cota. As duas hastes pontilhadas ligam o começo e o fim do espaço do
     * nome à medida embaixo — sem elas o traço solto seria só um traço. */
    const baseLupa = LUPA.y + LUPA.h;
    const fim = d.textoX + d.larguraDesenhada;
    for (const x of [d.textoX, fim]) {
      svg.appendChild(linha(x, baseLupa + 0.5, x, baseLupa + 3.5, {
        "stroke-width": 1, "stroke-dasharray": "1.5 1.5", opacity: 0.5,
      }));
      svg.appendChild(linha(x, baseLupa + 3.5, x, baseLupa + 7, { "stroke-width": 1.4 }));
    }
    svg.appendChild(linha(d.textoX, baseLupa + 5.5, fim, baseLupa + 5.5, { "stroke-width": 1.4 }));
    svg.appendChild(texto((d.textoX + fim) / 2, 57.5, d.larguraPx + " px", { "font-size": 5.5 }));
    return svg;
  }

  function legendaMidia(val) {
    const d = lerMidia(val);
    const c = conferir(val, REGRAS_MIDIA);
    let corpo;
    if (!d.ligada) {
      corpo = "a barra sem a pastilha da música — desligar não deixa de instalar, reverte: o applet do flatpak volta no próximo login";
    } else {
      const nomeDeCor = (bruta, padrao) => {
        const s = achatar(bruta) || padrao;
        return (s === "auto" || NOMES_DA_PALETA.indexOf(s) < 0) ? "cor padrão do painel" : s;
      };
      corpo = "a barra em cima e o applet ampliado embaixo, "
        + (d.capa
          ? "com capa e com a cor do álbum "
            + (d.chapado ? "chapando o fundo do botão" : "tingindo só o traço")
          : "sem capa e sem cor de álbum — a cor é extraída da imagem, e sem imagem não há de onde tirá-la")
        + ", o nome em " + nomeDeCor(val.MIDIA_COR_TITULO, "mauve")
        + " e a banda em " + nomeDeCor(val.MIDIA_COR_ARTISTA, "green")
        + ", " + d.larguraPx + " px de nome antes das reticências, letra "
        + (d.auto ? "na escala do painel" : "cravada em " + d.fontePx + " px")
        + " e " + (d.controles ? "com os três botões, que alargam a pastilha na barra" : "sem os três botões");
    }
    return montarLegenda(corpo, [
      notaDeErradas(c.erradas),
      d.ligada && !d.capa
        ? "«não» desliga o DOWNLOAD da capa por link (é o que o Spotify publica); um tocador que publica arquivo no disco continua com capa"
        : "",
      d.ligada && d.capa && !d.chapado ? "a cor do álbum aqui é só um exemplo: a de verdade vem do disco que estiver tocando" : "",
      d.ligada && d.controles ? "o applet de Som, ao lado, já desenha os dele quando há player — é por isso que estes nascem desligados" : "",
      c.vazias.length ? VAZIO_FABRICA : "",
    ]);
  }

  /* ======================================================================== */
  /* 3. Papel de parede                                                        */
  /* ======================================================================== */
  /* A PERGUNTA: "preencher, caber ou esticar" é a palavra mais cara desta
   * seção — foi ela que, cravada em `Fit` dentro do script, pôs duas tarjas
   * pretas na tela dela em 11/08/2026. As três palavras só significam alguma
   * coisa quando a MESMA foto aparece nos três ajustes:
   *   preencher  a foto é maior que a tela e sobra para fora (o pontilhado)
   *   caber      a foto inteira aparece e sobram as tarjas hachuradas
   *   esticar    o sol vira ovo
   * O sol virando elipse é o coração deste desenho: é a única forma de mostrar
   * deformação sem escrever a palavra "deforma".
   *
   * A foto de origem é 4:3 e a tela é mais larga que isso, de propósito: com as
   * duas proporções iguais os três ajustes desenhariam a mesma coisa e a chave
   * pareceria não fazer nada.
   *
   * O CORTE TEM `id` FIXO, e isso é seguro aqui: `antes` e `depois` são o mesmo
   * enquadramento por contrato, então os dois recortes são geometricamente
   * idênticos e tanto faz qual dos dois o navegador resolve primeiro. */
  const CORTE_PAREDE = "meow-previa-parede";
  const REGRAS_PAREDE = [
    { chave: "WALLPAPER_AJUSTE", ok: (s) => escolhaValida(s, ["preencher", "caber", "esticar"]) },
    { chave: "WALLPAPER_INTERVALO", ok: (s) => duracao(s, "5m").ok },
    { chave: "WALLPAPER_FIXO_TTL", ok: (s) => duracao(s, "30m").ok },
    { chave: "WALLPAPER_ORDEM", ok: (s) => escolhaValida(s, ["aleatoria", "alfabetica"]) },
    { chave: "WALLPAPER_NOTIFICAR", ok: booleanoValido },
    { chave: "FILES_MENU", ok: booleanoValido },
  ];

  /* A tela e a área útil dela. Tudo o que a foto faz é calculado a partir
   * destes quatro números, para que os três ajustes sejam comparáveis. */
  const TELA = { x: 5, y: 6, w: 58, h: 33 };

  function fotoDeTraco(x, y, w, h, extra) {
    const g = grupo(Object.assign({ "stroke-width": 1.6 }, extra || {}), []);
    g.appendChild(elipse(x + w * 0.26, y + h * 0.3, w * 0.11, h * 0.145, {
      stroke: "var(--peach)",
    }));
    g.appendChild(caminho(
      "M " + q(x) + "," + q(y + h)
      + " L " + q(x + w * 0.3) + "," + q(y + h * 0.42)
      + " L " + q(x + w * 0.52) + "," + q(y + h * 0.78)
      + " L " + q(x + w * 0.72) + "," + q(y + h * 0.34)
      + " L " + q(x + w) + "," + q(y + h)));
    return g;
  }

  function lerParede(val) {
    const ttl = duracao(val.WALLPAPER_FIXO_TTL, "30m");
    return {
      ajuste: escolha(val.WALLPAPER_AJUSTE, ["preencher", "caber", "esticar"], "preencher"),
      intervalo: duracao(val.WALLPAPER_INTERVALO, "5m"),
      ttl: ttl,
      ttlEterno: /^0+([.,]0+)?$/.test(achatar(val.WALLPAPER_FIXO_TTL)),
      ordem: escolha(val.WALLPAPER_ORDEM, ["aleatoria", "alfabetica"], "aleatoria"),
      avisa: ligado(val.WALLPAPER_NOTIFICAR, true),
      menu: ligado(val.FILES_MENU, true),
      fontes: lista(val.WALLPAPER_FONTES_DELA, ":"),
    };
  }

  function desenharParede(val) {
    const d = lerParede(val);
    const svg = moldura("a tela com a imagem no ajuste escolhido e o relógio da troca");

    svg.appendChild(no("defs", null, [
      no("clipPath", { id: CORTE_PAREDE }, [retangulo(TELA.x, TELA.y, TELA.w, TELA.h, 2.5)]),
    ]));

    const dentro = grupo({ "clip-path": "url(#" + CORTE_PAREDE + ")" }, []);
    if (d.ajuste === "caber") {
      /* Cabe inteira: a foto 4:3 encolhe até a altura da tela e sobram duas
       * tarjas. Hachura em vez de preto chapado — a tarja preta de verdade é
       * preta, mas um retângulo cheio aqui brigaria com o traço do resto e, no
       * sabor claro, com o próprio fundo da página. */
      const w = TELA.h * 4 / 3;
      const x = TELA.x + (TELA.w - w) / 2;
      for (const faixa of [[TELA.x, x - TELA.x], [x + w, TELA.x + TELA.w - (x + w)]]) {
        for (let i = 0; i < 5; i++) {
          const px = faixa[0] + (faixa[1] * (i + 0.5)) / 5;
          dentro.appendChild(linha(px, TELA.y + 2, px - 3, TELA.y + TELA.h - 2, {
            "stroke-width": 1, opacity: 0.4,
          }));
        }
        dentro.appendChild(retangulo(faixa[0], TELA.y, faixa[1], TELA.h, 0, {
          "stroke-width": 1, opacity: 0.35,
        }));
      }
      dentro.appendChild(fotoDeTraco(x, TELA.y, w, TELA.h));
    } else if (d.ajuste === "esticar") {
      dentro.appendChild(fotoDeTraco(TELA.x, TELA.y, TELA.w, TELA.h));
    } else {
      const h = TELA.w * 3 / 4;
      const y = TELA.y + (TELA.h - h) / 2;
      dentro.appendChild(fotoDeTraco(TELA.x, y, TELA.w, h));
    }
    svg.appendChild(dentro);

    if (d.ajuste === "preencher") {
      /* O que fica de fora não some do desenho: ele aparece pontilhado, porque
       * "o que não couber, corta" é a metade da frase que só se entende vendo o
       * pedaço cortado. */
      const h = TELA.w * 3 / 4;
      const y = TELA.y + (TELA.h - h) / 2;
      svg.appendChild(retangulo(TELA.x, y, TELA.w, h, 1, {
        "stroke-dasharray": "3 3", "stroke-width": 1.2, opacity: 0.4,
      }));
    }
    if (d.ajuste === "esticar") {
      /* As duas setas ficam ACIMA do sol, no céu: cruzando o sol elas
       * disfarçariam a elipse, que é a informação inteira deste ajuste. */
      svg.appendChild(seta(8, 9.5, 180, 2.8));
      svg.appendChild(linha(8, 9.5, 18, 9.5, { "stroke-width": 1.3 }));
      svg.appendChild(seta(60, 9.5, 0, 2.8));
      svg.appendChild(linha(50, 9.5, 60, 9.5, { "stroke-width": 1.3 }));
    }
    svg.appendChild(retangulo(4, 5, 60, 35, 3, { "stroke-width": 2 }));

    /* O relógio da troca. A seta circular é o único jeito de dizer "de quanto
     * em quanto" sem a palavra "intervalo". */
    svg.appendChild(caminho(arco(82, 16, 9, 35, 325), { "stroke-width": 1.8 }));
    const fim = ponto(82, 16, 9, 325);
    svg.appendChild(seta(fim.x, fim.y, 325, 3.4));
    svg.appendChild(texto(82, 18.5, d.intervalo.rotulo, { "font-size": 7 }));

    if (d.ordem === "alfabetica") {
      svg.appendChild(linha(74, 30, 90, 30, { "stroke-width": 1.6 }));
      svg.appendChild(seta(90, 30, 0, 3));
      svg.appendChild(texto(70, 32, "A", { "font-size": 5.5 }));
      svg.appendChild(texto(95, 32, "Z", { "font-size": 5.5 }));
    } else {
      svg.appendChild(linha(70, 26, 92, 34, { "stroke-width": 1.5 }));
      svg.appendChild(seta(92, 34, 20, 3));
      svg.appendChild(linha(70, 34, 92, 26, { "stroke-width": 1.5 }));
      svg.appendChild(seta(92, 26, -20, 3));
    }

    /* O prazo da imagem escolhida: o alfinete diz "esta fica", o número diz
     * quanto tempo. */
    svg.appendChild(circulo(9, 47, 2.2, { "stroke-width": 1.5 }));
    svg.appendChild(linha(9, 49.2, 9, 54, { "stroke-width": 1.5 }));
    svg.appendChild(texto(14, 53, d.ttlEterno ? "sempre" : d.ttl.rotulo, {
      "font-size": 5.5, "text-anchor": "start",
    }));

    /* O AVISO É UMA TARJA, E NÃO UM SINO — 07/09/2026
     * A chave não pendura sino nenhum em lugar nenhum: ela manda o
     * `meow_notificar` pôr uma notificação na tela dizendo QUAL imagem entrou.
     * O sino de raio 4,5 que morava aqui mudava 0,67% dos pixels do botão do
     * par — os dois lados desenhavam a mesma figura, e a conferência de uso
     * relatou exatamente isso.
     *   A largura sai do que sobrou: o alfinete do prazo ocupa até x≈30 e o
     * menu do botão direito começa em x=66, então a tarja mora entre os dois.
     * Ela é a mesma `tarjaDeAviso` das três de "Manutenção", e é de propósito:
     * quatro chaves fazem a mesma coisa e passam a ter a mesma figura. */
    svg.appendChild(tarjaDeAviso(31, 45.5, 33, 11, "imagem", d.avisa));

    /* O MENU DO BOTÃO DIREITO, INTEIRO — e não uma caixinha pontilhada. Medido
     * em 07/09/2026, a caixinha mudava 1,91% dos pixels do botão entre "sim" e
     * "nao": os dois lados eram a mesma figura com o traço tracejado. Mas a
     * chave não acende nem apaga uma caixa; ela ACRESCENTA DOIS ITENS ao menu
     * da área de trabalho, e com isso o menu cresce e o que estava embaixo
     * desce. Desenhar o menu dos dois tamanhos é desenhar o que ela vai ver
     * quando clicar com o botão direito.
     *
     * Os itens de fábrica são barras, e não palavras: quantos e quais o COSMIC
     * põe ali muda de versão para versão, e escrever nomes que este arquivo não
     * lê de lugar nenhum seria a única mentira possível neste canto. Os NOSSOS
     * dois vão com seta, um para cada lado, porque é isso que eles fazem —
     * "Próximo papel de parede" e "Papel de parede anterior". */
    const itensDeFabrica = [[69.5, 93], [69.5, 88], [69.5, 91]];
    if (d.menu) {
      svg.appendChild(retangulo(66, 37, 32, 22, 2, { "stroke-width": 1.6 }));
      for (const [y, graus] of [[41.5, 0], [45.5, 180]]) {
        const ponta = graus === 0 ? 74 : 68.5;
        svg.appendChild(linha(68.5, y, 74, y, { "stroke-width": 1.8, stroke: "var(--mauve)" }));
        svg.appendChild(seta(ponta, y, graus, 3.2));
        svg.appendChild(linha(76.5, y, 95, y, { "stroke-width": 2.4, stroke: "var(--mauve)" }));
      }
      svg.appendChild(linha(67.5, 48.5, 96.5, 48.5, { "stroke-width": 1.1, opacity: 0.4 }));
      for (let i = 0; i < itensDeFabrica.length; i++) {
        svg.appendChild(linha(itensDeFabrica[i][0], 51 + i * 3.4, itensDeFabrica[i][1], 51 + i * 3.4, {
          "stroke-width": 2.2, opacity: 0.55,
        }));
      }
    } else {
      svg.appendChild(retangulo(66, 37, 32, 13.5, 2, { "stroke-width": 1.6 }));
      for (let i = 0; i < itensDeFabrica.length; i++) {
        svg.appendChild(linha(itensDeFabrica[i][0], 41 + i * 3.4, itensDeFabrica[i][1], 41 + i * 3.4, {
          "stroke-width": 2.2, opacity: 0.55,
        }));
      }
    }
    return svg;
  }

  function legendaParede(val) {
    const d = lerParede(val);
    const c = conferir(val, REGRAS_PAREDE);
    const comoOcupa = {
      preencher: "a imagem preenchendo a tela (o que não couber é cortado)",
      caber: "a imagem inteira na tela, com tarja dos dois lados",
      esticar: "a imagem esticada até caber, deformada",
    }[d.ajuste];
    const corpo = comoOcupa
      + ", troca a cada " + d.intervalo.rotulo
      + " em ordem " + (d.ordem === "alfabetica" ? "de nome" : "sorteada")
      + ", a escolhida fica " + (d.ttlEterno ? "até você soltar o carrossel" : "por " + d.ttl.rotulo)
      + ", " + (d.avisa ? "com tarja na tela dizendo qual imagem entrou" : "sem tarja na tela")
      + " e " + (d.menu ? "com" : "sem") + " os itens no botão direito";
    return montarLegenda(corpo, [
      notaDeErradas(c.erradas),
      d.fontes.length ? plural(d.fontes.length, "pasta sua fica", "pastas suas ficam") + " de fora do conserto automático" : "",
      c.vazias.length ? VAZIO_FABRICA : "",
    ]);
  }

  /* ======================================================================== */
  /* 4. Dia e noite                                                            */
  /* ======================================================================== */
  /* A PERGUNTA: "18:00" e "07:00" em duas caixas de texto não mostram que a
   * janela ATRAVESSA a meia-noite — e é justamente essa a regra da seção
   * (início > fim quer dizer "depois do início OU antes do fim"). Num arco de
   * 24 horas isso não precisa ser explicado: o trecho pintado passa por cima do
   * topo e pronto.
   *
   * A PRECEDÊNCIA TAMBÉM É DESENHO. As duas chaves gerais vencem; vazias, elas
   * herdam as do papel de parede; vazias as quatro, valem 18:00–07:00. O
   * desenho mostra a janela que está VALENDO e a legenda diz de onde ela veio —
   * "está vazio e mesmo assim tem noite" é uma das perguntas mais caras desta
   * seção. */
  const REGRAS_NOITE = [
    { chave: "NOITE_INICIO", ok: (s) => relogio(s, 0).ok },
    { chave: "NOITE_FIM", ok: (s) => relogio(s, 0).ok },
    { chave: "WALLPAPER_NOITE", ok: booleanoValido },
    { chave: "WALLPAPER_NOITE_INICIO", ok: (s) => relogio(s, 0).ok },
    { chave: "WALLPAPER_NOITE_FIM", ok: (s) => relogio(s, 0).ok },
    { chave: "WALLPAPER_LIMIAR_LUZ", ok: (s) => numeroValido(s, 0, 1) },
  ];

  function lerNoite(val) {
    const geralIni = relogio(val.NOITE_INICIO, -1);
    const geralFim = relogio(val.NOITE_FIM, -1);
    const paredeIni = relogio(val.WALLPAPER_NOITE_INICIO, -1);
    const paredeFim = relogio(val.WALLPAPER_NOITE_FIM, -1);
    const ini = geralIni.ok ? geralIni : (paredeIni.ok ? paredeIni : relogio("18:00", 1080));
    const fim = geralFim.ok ? geralFim : (paredeFim.ok ? paredeFim : relogio("07:00", 420));
    let fonte;
    if (geralIni.ok && geralFim.ok) fonte = "das duas linhas gerais desta seção";
    else if (!geralIni.ok && !geralFim.ok && paredeIni.ok && paredeFim.ok) fonte = "herdada do papel de parede, porque as duas linhas gerais estão vazias";
    else if (!geralIni.ok && !geralFim.ok && !paredeIni.ok && !paredeFim.ok) fonte = "o padrão de 18:00 às 07:00, porque as quatro linhas estão vazias";
    else fonte = "herdada em parte: cada ponta veio da primeira linha preenchida";
    const dura = ((fim.min - ini.min) % 1440 + 1440) % 1440;
    return {
      ini: ini,
      fim: fim,
      fonte: fonte,
      duraMin: dura === 0 ? 1440 : dura,
      diaInteiro: ini.min === fim.min,
      separa: ligado(val.WALLPAPER_NOITE, true),
      limiar: numero(val.WALLPAPER_LIMIAR_LUZ, 0.37, 0, 1),
    };
  }

  const ANEL = { cx: 32, cy: 28, r: 15 };

  function desenharNoite(val) {
    const d = lerNoite(val);
    const svg = moldura("um arco de 24 horas com o trecho da noite pintado, e o acervo separado em claras e escuras");

    svg.appendChild(circulo(ANEL.cx, ANEL.cy, ANEL.r, {
      stroke: "var(--surface2)", "stroke-width": 2.5,
    }));
    for (const g of [0, 90, 180, 270]) {
      const a = ponto(ANEL.cx, ANEL.cy, ANEL.r - 4.5, g);
      const b = ponto(ANEL.cx, ANEL.cy, ANEL.r - 2, g);
      svg.appendChild(linha(a.x, a.y, b.x, b.y, { "stroke-width": 1.1, opacity: 0.45 }));
    }

    const grausIni = (d.ini.min / 1440) * 360;
    const grausFim = (d.fim.min / 1440) * 360;
    if (d.diaInteiro) {
      svg.appendChild(circulo(ANEL.cx, ANEL.cy, ANEL.r, {
        stroke: "var(--blue)", "stroke-width": 4.5,
      }));
    } else {
      svg.appendChild(caminho(arco(ANEL.cx, ANEL.cy, ANEL.r, grausIni, grausFim), {
        stroke: "var(--blue)", "stroke-width": 4.5,
      }));
    }

    /* O meio da noite e o meio do dia ganham lua e sol: sem eles o arco pintado
     * é só um arco pintado, e nada diz qual dos dois lados é a noite. */
    const meioNoite = grausIni + d.duraMin / 1440 * 360 / 2;
    const pl = ponto(ANEL.cx, ANEL.cy, 7, meioNoite);
    svg.appendChild(lua(pl.x, pl.y, 3, { "stroke-width": 1.4, stroke: "var(--blue)" }));
    if (!d.diaInteiro) {
      const meioDia = grausFim + (1440 - d.duraMin) / 1440 * 360 / 2;
      const ps = ponto(ANEL.cx, ANEL.cy, 7, meioDia);
      svg.appendChild(sol(ps.x, ps.y, 3.2, { "stroke-width": 1.4, stroke: "var(--yellow)" }));
    }

    svg.appendChild(texto(ANEL.cx, ANEL.cy - ANEL.r - 3, "0h", { "font-size": 4.5, opacity: 0.5 }));

    for (const marca of [{ g: grausIni, t: d.ini.rotulo }, { g: grausFim, t: d.fim.rotulo }]) {
      const a = ponto(ANEL.cx, ANEL.cy, ANEL.r - 3.5, marca.g);
      const b = ponto(ANEL.cx, ANEL.cy, ANEL.r + 3.5, marca.g);
      svg.appendChild(linha(a.x, a.y, b.x, b.y, { "stroke-width": 2 }));
      const p = ponto(ANEL.cx, ANEL.cy, ANEL.r + 5, marca.g);
      const dx = (p.x - ANEL.cx) / ANEL.r;
      const ancora = dx > 0.3 ? "start" : (dx < -0.3 ? "end" : "middle");
      svg.appendChild(texto(p.x + (ancora === "start" ? 1 : (ancora === "end" ? -1 : 0)),
        p.y + (p.y < ANEL.cy ? 0 : 3.4), marca.t, { "font-size": 5, "text-anchor": ancora }));
    }

    /* O ACERVO É A COLUNA DA DIREITA INTEIRA, e não uma tira de 12 unidades no
     * alto: era ali que a chave desta seção ficava invisível. Medido em
     * 07/09/2026, o par "sim"/"nao" mudava 2,05% dos pixels do botão — duas
     * pastinhas viravam uma, e nada mais. A régua do corte desceu para a faixa
     * de baixo (onde não havia nada) e o acervo herdou os 42 de altura.
     *
     * AS MESMAS DOZE FICHAS NOS DOIS LADOS, porque a chave não move arquivo
     * nenhum: ligada, o `wallpaper.sh` mede a luminância de cada imagem de
     * `ativos/` e monta duas pastas de LINK DURO ao lado dela (`ativos-dia/` e
     * `ativos-noite/`), apontando o carrossel para a do horário; desligada, as
     * duas somem do disco e volta a haver um sorteio só. Por isso as fichas se
     * REAGRUPAM em vez de aparecer e sumir — separar não é apagar. E a divisão
     * é desigual (sete claras, cinco escuras) porque no acervo dela também é:
     * o `wallpaper.sh` imprime "32 de 54" numa hora e "22 de 54" na outra. */
    const FICHAS = [1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0];   // 1 = clara · 0 = escura
    function fichaDeAcervo(x, y, clara) {
      svg.appendChild(retangulo(x, y, 6.6, 7.6, 1, { "stroke-width": 1.2, opacity: 0.85 }));
      if (clara) svg.appendChild(sol(x + 3.3, y + 3.8, 2.5, { "stroke-width": 1.1, stroke: "var(--yellow)" }));
      else svg.appendChild(lua(x + 3.3, y + 3.8, 2.3, { "stroke-width": 1.1, stroke: "var(--blue)" }));
    }
    if (d.separa) {
      /* Duas pastas, uma por horário. A da vez é a que o carrossel está
       * sorteando AGORA — mas "agora" não cabe num desenho puro, então as duas
       * aparecem inteiras e quem diz qual está valendo é a legenda. */
      for (const [px, quais, nome] of [
        [67, FICHAS.filter((c) => c), "dia"],
        [84, FICHAS.filter((c) => !c), "noite"],
      ]) {
        svg.appendChild(retangulo(px, 4, 14, 42, 2, { "stroke-width": 1.5 }));
        svg.appendChild(texto(px + 7, 11, nome, { "font-size": 4.6, opacity: 0.8 }));
        for (let i = 0; i < quais.length; i++) {
          fichaDeAcervo(px + 0.4 + (i % 2) * 6.9, 14 + Math.floor(i / 2) * 7.8, quais[i]);
        }
      }
    } else {
      svg.appendChild(retangulo(67, 4, 31, 42, 2, { "stroke-width": 1.5 }));
      svg.appendChild(texto(82.5, 11, "ativos", { "font-size": 4.6, opacity: 0.8 }));
      for (let i = 0; i < FICHAS.length; i++) {
        fichaDeAcervo(67.9 + (i % 4) * 7.4, 15.5 + Math.floor(i / 4) * 9.5, FICHAS[i]);
      }
    }

    /* O corte: uma régua do escuro ao claro com a marca onde a imagem deixa de
     * contar como de noite. Na faixa de baixo, larga, porque é ela que diz
     * QUAIS fichas caem em cada pasta do acervo ao lado. */
    svg.appendChild(lua(22, 54, 3, { "stroke-width": 1.2, stroke: "var(--blue)" }));
    svg.appendChild(sol(78, 54, 3.2, { "stroke-width": 1.2, stroke: "var(--yellow)" }));
    svg.appendChild(linha(28, 54, 72, 54, { "stroke-width": 1.4, opacity: 0.6 }));
    const marca = 28 + 44 * d.limiar;
    svg.appendChild(linha(marca, 50, marca, 58, { "stroke-width": 2 }));
    svg.appendChild(texto(Math.max(33, Math.min(67, marca)), 48, String(d.limiar), { "font-size": 5 }));
    return svg;
  }

  function legendaNoite(val) {
    const d = lerNoite(val);
    const c = conferir(val, REGRAS_NOITE);
    const horas = Math.round(d.duraMin / 60 * 10) / 10;
    const corpo = "a noite das " + d.ini.rotulo + " às " + d.fim.rotulo
      + " (" + horas + " h, " + d.fonte + ")"
      + (d.diaInteiro ? ", ou seja o dia inteiro: início igual ao fim"
        : (d.ini.min > d.fim.min ? ", atravessando a meia-noite" : ""))
      + ", " + (d.separa
        ? "com o acervo separado em claras e escuras no corte " + d.limiar
        : "com um acervo só, claras e escuras no mesmo sorteio");
    return montarLegenda(corpo, [
      notaDeErradas(c.erradas),
      "manda em tudo que pergunta \"é noite?\": a logo, o papel de parede e o modo de leitura",
    ]);
  }

  /* ======================================================================== */
  /* 5. Modo de leitura                                                        */
  /* ======================================================================== */
  /* A PERGUNTA é a que ela fez em voz alta em 29/08/2026: "3500 é demais?".
   * Nenhum texto responde isso. Duas metades da MESMA página, uma neutra e
   * outra na temperatura escolhida, respondem em meio segundo — e é por isso
   * que o desenho é uma página de texto e não um retângulo abstrato: o que
   * incomoda numa tela quente é ler nela.
   *
   * A ÚNICA COR DESTE ARQUIVO QUE NÃO VEM DA PALETA ESTÁ AQUI, e é decisão, não
   * descuido. Temperatura de cor é física: 3500 K tem uma cor, e ela não é
   * `var(--peach)` nem nenhuma outra das 26. Fingir que é faria o desenho
   * mentir sobre o número — que é exatamente o que ele existe para responder.
   * A aproximação é a mesma (Tanner Helland) que a simulação do modo de leitura
   * já usa em `app.js`, e de propósito: as duas aparecem na mesma aba, e duas
   * aproximações diferentes para o mesmo Kelvin seriam duas respostas para a
   * mesma pergunta. Sai em `rgb()`, sem literal hexadecimal.
   *
   * Quem pinta de verdade é o cosmic-comp recompilado, e o que ele faz com os
   * mesmos dois números não é um multiply em cima de uma imagem. A direção e a
   * intensidade batem; a legenda não promete mais que isso. */
  function corDeKelvin(k) {
    const t = Math.max(1000, Math.min(6500, Number(k) || 6500)) / 100;
    const lim = (x) => Math.max(0, Math.min(255, x));
    const r = t <= 66 ? 255 : lim(329.7 * Math.pow(t - 60, -0.1332));
    const g = t <= 66 ? lim(99.47 * Math.log(t) - 161.1) : lim(288.1 * Math.pow(t - 60, -0.0755));
    const b = t >= 66 ? 255 : (t <= 19 ? 0 : lim(138.5 * Math.log(t - 10) - 305.0));
    return "rgb(" + Math.round(r) + " " + Math.round(g) + " " + Math.round(b) + ")";
  }

  const REGRAS_LEITURA = [
    { chave: "LEITURA_AGENDA", ok: booleanoValido },
    { chave: "LEITURA_HORARIO_INICIO", ok: (s) => relogio(s, 0).ok },
    { chave: "LEITURA_HORARIO_FIM", ok: (s) => relogio(s, 0).ok },
    { chave: "LEITURA_TEMPERATURA", ok: (s) => numeroValido(s, 1000, 6500) },
    { chave: "LEITURA_TEXTURA", ok: (s) => numeroValido(s, 0, 1) },
    { chave: "LEITURA_RAMPA_MIN", ok: (s) => numeroValido(s, 0, 600) },
    { chave: "LEITURA_APPLET", ok: booleanoValido },
  ];

  function lerLeitura(val) {
    const bruta = emTexto(val.LEITURA_TEXTURA);
    return {
      /* Três estados, não dois: vazio é "o modo de leitura é seu e de mais
       * ninguém", e "nao" é apagar o efeito. Nos dois casos o relógio não
       * vira a cor da tela sozinho — que é o que o desenho tem de dizer.
       * O padrão do que não é nem uma coisa nem outra é o de fábrica ("sim"),
       * pela mesma regra das outras seis: valor que a chave não entende
       * desenha o padrão e a legenda avisa. */
      agenda: !vazio(val.LEITURA_AGENDA) && ligado(val.LEITURA_AGENDA, true),
      agendaVazia: vazio(val.LEITURA_AGENDA),
      ini: relogio(val.LEITURA_HORARIO_INICIO, 1080),
      fim: relogio(val.LEITURA_HORARIO_FIM, 420),
      temp: Math.round(numero(val.LEITURA_TEMPERATURA, 3500, 1000, 6500)),
      textura: numero(val.LEITURA_TEXTURA, 0.35, 0, 1),
      /* A vírgula do teclado pt_BR é o erro mais fácil desta linha e o mais
       * mudo: lá dentro o número vira 0 e o papel fica desligado para sempre.
       * Aqui ele é lido como ponto, e a legenda avisa. */
      virgula: bruta.indexOf(",") >= 0,
      rampa: Math.round(numero(val.LEITURA_RAMPA_MIN, 0, 0, 600)),
      applet: ligado(val.LEITURA_APPLET, true),
    };
  }

  /* Um deslizante do popup: o trilho e o cursor onde o número desta seção o
   * põe. A fração já chega entre 0 e 1 — quem a calcula é quem conhece a faixa
   * daquele deslizante, que é a do APPLET e não uma inventada aqui. */
  function deslizante(x1, x2, y, fracao) {
    const f = Math.max(0, Math.min(1, Number(fracao) || 0));
    return grupo(null, [
      linha(x1, y, x2, y, { "stroke-width": 1.2, opacity: 0.5 }),
      circulo(x1 + (x2 - x1) * f, y, 1.7, { "stroke-width": 1.2, fill: "var(--surface2)" }),
    ]);
  }

  function desenharLeitura(val) {
    const d = lerLeitura(val);
    const svg = moldura("a mesma página em duas metades: fria à esquerda, na temperatura e na"
      + " textura escolhidas à direita"
      + (d.applet ? ", e o controle da barra com o popup aberto" : ", sem o controle na barra"));

    svg.appendChild(retangulo(3, 3, 94, 34, 3, { "stroke-width": 1.8 }));
    svg.appendChild(linha(4, 10, 96, 10, { "stroke-width": 1, opacity: 0.35 }));
    /* 21:41 e não 9:41: a metade da direita é a tela quente, o selo do canto é
     * a lua, e o corte de baixo diz "das 18:00 às 07:00". A hora de manhã era a
     * única frase falsa do quadro. */
    svg.appendChild(texto(9, 8.2, "21:41", { "font-size": 4.5, "text-anchor": "start", opacity: 0.6 }));

    /* A textura levanta o preto: o mesmo parágrafo, do lado do papel, perde
     * contraste. É metade do que a chave faz, e a única metade que dá para ver
     * num desenho de traço.
     *
     * AS DUAS COLUNAS ENCOLHERAM DE 41 PARA 32 UNIDADES em 07/09/2026, as duas
     * na mesma medida — o que a comparação exige é que as metades sejam a MESMA
     * página, não que sejam largas. O que entrou na largura que sobrou está no
     * bloco do controle na barra, logo abaixo. */
    const opacidadeDireita = 1 - d.textura * 0.45;
    const linhasEsq = [39, 38, 40, 31];
    const linhasDir = [78, 77, 79, 70];
    for (let i = 0; i < 4; i++) {
      const y = 16 + i * 6;
      svg.appendChild(linha(8, y, linhasEsq[i], y, { "stroke-width": 1.8, opacity: 0.75 }));
      svg.appendChild(linha(47, y, linhasDir[i], y, { "stroke-width": 1.8, opacity: q(0.75 * opacidadeDireita) }));
    }

    /* O CONTROLE NA BARRA PRECISAVA SER VISTO — 07/09/2026
     *   Ele era dois riscos de 9 unidades no canto da topbar, e o par de
     *   desenhos do `LEITURA_APPLET` mudava 0,53% dos pixels do botão:
     *   fotografados lado a lado, o «Sim» e o «Não» desenhavam a mesma figura.
     *   Foi a conferência de uso, clicando botão a botão, quem pegou.
     *
     *   O QUE ENTROU NO LUGAR é o que a chave dá: o selo no canto da barra e,
     *   pendurado nele, o popup com os DOIS DESLIZANTES — que é o nome que o
     *   próprio meow.conf.exemplo dá a esta chave ("um ícone com dois
     *   deslizantes, para mexer sem abrir este painel").
     *
     *   O POPUP ESTÁ DESENHADO ABERTO, E A LEGENDA DIZ ISSO. Na barra ele é só
     *   o selo; o popup abre no clique. Um desenho não é captura, mas também
     *   não pode deixar quem olha achar que a tela dela fica assim parada — daí
     *   a nota, e não só o traço.
     *
     *   TRÊS COISAS SÃO COPIADAS DO APPLET, não inventadas aqui: o selo da
     *   barra é a LUA quando é noite, e o popup repete o MESMO selo na primeira
     *   linha (`arte_da_barra` e o comentário do `view_window`, em
     *   src/applets/leitura/src/main.rs); o deslizante de cima é a temperatura,
     *   de 1000 a 6500 K (PISO e NEUTRO, no mesmo arquivo); o de baixo é a
     *   textura, de 0 a 100%. Os dois cursores ficam onde os números desta
     *   seção os põem — um controle que não anda com o número ao lado seria uma
     *   segunda mentira, menor e mais fácil de acreditar.
     *
     *   Com "nao" nada disso está lá: nem pontilhado, nem fantasma. É o que a
     *   chave faz com o ícone. */
    if (d.applet) {
      svg.appendChild(lua(88, 6.4, 2, { "stroke-width": 1.3 }));
      /* O popup é a única coisa CHAPADA deste quadro, e aqui o chapado é a
       * informação: popup é superfície, e superfície esconde a página atrás —
       * a mesma decisão do vidro da barra e da janela solta. `surface0` porque
       * o fundo do cartão é `base`/`mantle`: um popup pintado de `base` teria
       * só o contorno, e sumiria de novo no tamanho do botão.
       *
       * ELE ENTRA ANTES DO VÉU DE PROPÓSITO: o cosmic-comp esquenta a saída
       * inteira, popup incluído. Desenhá-lo por cima do véu o deixaria frio
       * dentro de uma tela quente, que é coisa que a máquina não faz. */
      svg.appendChild(retangulo(70, 11.5, 25, 22.5, 2.5, {
        fill: "var(--surface0)", "stroke-width": 1.4,
      }));
      svg.appendChild(lua(73.8, 15.4, 1.7, { "stroke-width": 1.1 }));
      svg.appendChild(retangulo(83.5, 13.6, 9, 3.6, 1.8, { "stroke-width": 1.1 }));
      svg.appendChild(circulo(90.6, 15.4, 1.15, { fill: "currentColor", stroke: "none" }));
      svg.appendChild(linha(72.5, 19.2, 92.5, 19.2, { "stroke-width": 0.8, opacity: 0.3 }));
      svg.appendChild(texto(74, 24.8, "K", { "font-size": 4.4, opacity: 0.8 }));
      svg.appendChild(deslizante(78.5, 92.5, 23.2, (d.temp - 1000) / 5500));
      svg.appendChild(texto(74, 31.4, "%", { "font-size": 4.4, opacity: 0.8 }));
      svg.appendChild(deslizante(78.5, 92.5, 29.8, d.textura));
    }

    const intensidade = Math.max(0, Math.min(1, (6500 - d.temp) / 5500)) * 0.55;
    if (intensidade > 0) {
      /* O véu para 1,5 antes da moldura e tem o mesmo raio dela: um retângulo
       * de canto reto encostado numa moldura arredondada aparece como um erro
       * de desenho, e chama atenção justamente para o canto em vez da cor. */
      svg.appendChild(retangulo(43.5, 4.5, 51.5, 31, 2.5, {
        fill: corDeKelvin(d.temp), "fill-opacity": q(intensidade), stroke: "none",
      }));
    }
    if (d.textura > 0) {
      const fibras = Math.max(1, Math.round(d.textura * 5));
      /* A FIBRA É DA PÁGINA, O VÉU É DA TELA — e é por isso que uma para na
       * borda do popup e o outro passa por cima dele. O grão do cosmic-comp
       * cai sobre a saída inteira, popup incluído; desenhado, ele virava um
       * tracejado atravessando o "%" e o cursor do deslizante, que se lê como
       * defeito de desenho e não como grão. Então a fibra fica no papel, que é
       * onde a metáfora deste quadro a põe, e o popup a cobre como qualquer
       * janela cobre o que está embaixo. */
      const fimDaFibra = d.applet ? 69 : 94;
      for (let i = 0; i < fibras; i++) {
        const y = 13 + (i + 0.5) * (23 / fibras);
        svg.appendChild(linha(45, y, fimDaFibra, y, {
          "stroke-width": 0.6,
          "stroke-dasharray": "5 4",
          stroke: "var(--rosewater)",
          opacity: q(0.2 + 0.35 * d.textura),
        }));
      }
    }
    svg.appendChild(linha(43, 4, 43, 36, { "stroke-width": 1, "stroke-dasharray": "2 3", opacity: 0.5 }));

    svg.appendChild(texto(23, 44, "6500 K", { "font-size": 5.5 }));
    svg.appendChild(texto(69, 44, d.temp + " K", { "font-size": 5.5 }));

    /* O relógio da virada, em corte: o degrau seco salta, a rampa sobe. E ela
     * sobe DEPOIS da hora, nunca antes — "ligar às 18:00" não pode significar
     * "às 17:30 a tela já mexeu". */
    if (!d.agenda) {
      svg.appendChild(linha(8, 52, 92, 52, {
        "stroke-width": 1.4, "stroke-dasharray": "3 3", opacity: 0.45,
      }));
      svg.appendChild(linha(47, 49, 53, 55, { "stroke-width": 1.4, opacity: 0.6 }));
      svg.appendChild(linha(53, 49, 47, 55, { "stroke-width": 1.4, opacity: 0.6 }));
    } else {
      const subida = d.rampa > 0 ? Math.max(3, Math.min(16, (d.rampa / 60) * 16)) : 0;
      svg.appendChild(caminho(
        "M 8,52 L 30,52 L " + q(30 + subida) + ",46 L 74,46 L 74,52 L 92,52",
        { "stroke-width": 1.8 }));
      svg.appendChild(texto(30, 59, d.ini.rotulo, { "font-size": 4.5 }));
      svg.appendChild(texto(74, 59, d.fim.rotulo, { "font-size": 4.5 }));
    }
    return svg;
  }

  function legendaLeitura(val) {
    const d = lerLeitura(val);
    const c = conferir(val, REGRAS_LEITURA);
    const corpo = "a mesma página a 6500 K à esquerda e a " + d.temp + " K com textura "
      + d.textura + " à direita, "
      + (d.agenda
        ? "das " + d.ini.rotulo + " às " + d.fim.rotulo + ", "
          + (d.rampa > 0 ? "subindo em " + d.rampa + " min depois da hora" : "com virada seca")
        : (d.agendaVazia
          ? "sem agendamento: vazio quer dizer que o modo de leitura é só seu"
          : "com o agendamento desligado: a virada não acontece sozinha"))
      + ", " + (d.applet
        ? "com o controle na barra: o selo no canto e o popup dele, com os dois deslizantes"
        : "sem o controle na barra: quem mexe passa a ser esta página, ou o relógio");
    return montarLegenda(corpo, [
      notaDeErradas(c.erradas),
      d.applet ? "o popup está desenhado ABERTO para caber na figura; na barra ele é só o selo, e abre no clique" : "",
      d.temp >= 6500 ? "6500 K é o neutro: nesta temperatura os dois lados ficam iguais, ou seja, desligado" : "",
      d.virgula ? "a textura foi escrita com vírgula, e lá dentro isso vira 0 (papel desligado): use ponto" : "",
      "é simulação: quem pinta de verdade é o cosmic-comp recompilado, e o slider do applet vence este número",
    ]);
  }

  /* ======================================================================== */
  /* 6. Lançadores e jogos                                                     */
  /* ======================================================================== */
  /* A PERGUNTA: "Programas que o MeowSystem veste" é uma lista de 22 nomes
   * separados por vírgula, e ninguém lê 22 nomes para saber o que a chave faz.
   * A fileira de cima mostra o lançador com quatro atalhos ACESOS — os quatro
   * primeiros da lista, escritos como estão nela —, e é aí que a palavra
   * "veste" ganha sentido: são os aplicativos que ganham a cara do tema.
   *
   * A FILEIRA DE BAIXO É "ARRUMAR O LANÇADOR", E ELA MUDOU EM 07/09/2026.
   *   Era UM atalho com um olho cortado dentro, e o par "nao"/"sim" mudava
   *   2,29% dos pixels do botão — dois desenhos que a olho eram o mesmo. A
   *   causa não era falta de capricho: um glifo de 14x14 num quadro de 100x60
   *   não tem como responder nada. Agora são cinco atalhos de sistema que
   *   viram dois, porque é isso que a chave faz — a lista do
   *   `scripts/ocultar_apps.sh` tem TRINTA nomes, e o que se vê na tela é uma
   *   fileira do lançador esvaziando. Continua sendo a única coisa que este
   *   projeto faz fora do home dela.
   *
   * E O SPOTIFY VIROU UMA JANELA INTEIRA, pelo mesmo motivo: o Marketplace do
   *   spicetify é uma PÁGINA dentro do programa (um item na lateral e uma grade
   *   de extensões), e não uma janelinha com um mais. */
  const REGRAS_LANCADOR = [
    { chave: "APPS_ATIVOS", ok: null },
    { chave: "SPOTIFY_MARKETPLACE", ok: booleanoValido },
    { chave: "LANCADOR_SISTEMA", ok: booleanoValido },
    { chave: "AUTOSTART_BLOQUEADOS", ok: null },
  ];

  function lerLancador(val) {
    return {
      apps: lista(val.APPS_ATIVOS, ","),
      loja: ligado(val.SPOTIFY_MARKETPLACE, true),
      arruma: ligado(val.LANCADOR_SISTEMA, false),
      bloqueados: lista(val.AUTOSTART_BLOQUEADOS, ","),
    };
  }

  function desenharLancador(val) {
    const d = lerLancador(val);
    const svg = moldura("o lançador com os atalhos vestidos, a fileira do sistema e a janela do Spotify");

    /* --- o lançador ------------------------------------------------------- */
    svg.appendChild(retangulo(3, 3, 64, 47, 4, { "stroke-width": 1.8 }));
    svg.appendChild(retangulo(8, 4.5, 54, 6, 3, { "stroke-width": 1.2, opacity: 0.6 }));
    svg.appendChild(circulo(12, 7.2, 1.5, { "stroke-width": 1.2, opacity: 0.6 }));
    svg.appendChild(linha(13.2, 8.4, 14.4, 9.6, { "stroke-width": 1.2, opacity: 0.6 }));

    for (let i = 0; i < 4; i++) {
      const x = 6 + i * 15;
      const nome = d.apps[i];
      if (nome) {
        svg.appendChild(retangulo(x, 12.5, 11, 11, 2.6, { "stroke-width": 1.7, stroke: "var(--mauve)" }));
        svg.appendChild(circulo(x + 5.5, 18, 2.5, { "stroke-width": 1.3, stroke: "var(--mauve)" }));
        svg.appendChild(caminho(
          "M " + q(x + 7.4) + ",11.7 l 1.4,1.4 l 2.8,-3.2",
          { "stroke-width": 1.4, stroke: "var(--green)" }));
        svg.appendChild(texto(x + 5.5, 27.5, cortar(nome, 6), { "font-size": 4.2, opacity: 0.85 }));
      } else {
        svg.appendChild(retangulo(x, 12.5, 11, 11, 2.6, {
          "stroke-width": 1.4, "stroke-dasharray": "3 3", opacity: 0.4,
        }));
      }
    }

    svg.appendChild(texto(6, 31.5, "sistema", { "font-size": 4.2, "text-anchor": "start", opacity: 0.6 }));
    for (let i = 0; i < (d.arruma ? 2 : 5); i++) {
      const x = 5.5 + i * 12.2;
      svg.appendChild(retangulo(x, 33, 12.4, 12.4, 2.8, { "stroke-width": 2.3 }));
      svg.appendChild(circulo(x + 6.2, 39.2, 3.4, { "stroke-width": 1.9 }));
      const larg = d.arruma ? 5.5 : 10.8;
      svg.appendChild(linha(x + 6.2 - larg / 2, 48.4, x + 6.2 + larg / 2, 48.4, {
        "stroke-width": 2.6, opacity: 0.75,
      }));
    }

    const bloqueia = d.bloqueados.length > 0;
    const atrib = bloqueia ? { "stroke-width": 1.6 } : { "stroke-width": 1.3, opacity: 0.4 };
    svg.appendChild(caminho(arco(9, 56, 3.4, 35, 325), atrib));
    svg.appendChild(linha(9, 51.8, 9, 54.6, atrib));
    if (bloqueia) {
      svg.appendChild(linha(5, 59.4, 13, 51.8, { "stroke-width": 1.5 }));
      svg.appendChild(texto(16, 58, String(d.bloqueados.length), {
        "font-size": 5.5, "text-anchor": "start",
      }));
    }

    /* --- o Spotify -------------------------------------------------------- */
    svg.appendChild(retangulo(70, 3, 27, 56, 3, { "stroke-width": 1.6 }));
    svg.appendChild(texto(83.5, 9, "Spotify", { "font-size": 5, opacity: 0.8 }));
    svg.appendChild(linha(70, 11.5, 97, 11.5, { "stroke-width": 1.1, opacity: 0.5 }));
    svg.appendChild(linha(79.5, 11.5, 79.5, 59, { "stroke-width": 1.1, opacity: 0.5 }));

    for (let i = 0; i < 2; i++) {
      svg.appendChild(linha(72, 17 + i * 6, 77.5, 17 + i * 6, { "stroke-width": 1.5, opacity: 0.6 }));
    }
    const lojaAtrib = d.loja
      ? { "stroke-width": 1.8, stroke: "var(--mauve)" }
      : { "stroke-width": 1.3, "stroke-dasharray": "2.5 2.5", opacity: 0.4 };
    svg.appendChild(linha(72, 29, 77.5, 29, lojaAtrib));

    if (d.loja) {
      svg.appendChild(retangulo(81.5, 15, 14, 5, 2.5, { "stroke-width": 1.2, opacity: 0.6 }));
      for (let i = 0; i < 6; i++) {
        const cx = 81.5 + (i % 2) * 7.5;
        const cy = 23 + Math.floor(i / 2) * 11.5;
        svg.appendChild(retangulo(cx, cy, 6.5, 9.5, 1.5, { "stroke-width": 1.4, stroke: "var(--mauve)" }));
        svg.appendChild(linha(cx + 1, cy + 7.4, cx + 5.5, cy + 7.4, {
          "stroke-width": 1.1, opacity: 0.55,
        }));
      }
    } else {
      svg.appendChild(retangulo(81.5, 17, 14, 14, 2, { "stroke-width": 1.4, opacity: 0.7 }));
      svg.appendChild(circulo(88.5, 24, 3.2, { "stroke-width": 1.2, opacity: 0.7 }));
      svg.appendChild(linha(81.5, 35, 95.5, 35, { "stroke-width": 1.5, opacity: 0.6 }));
      svg.appendChild(linha(81.5, 39.5, 90.5, 39.5, { "stroke-width": 1.3, opacity: 0.45 }));
      svg.appendChild(caminho(
        "M 85,46 L 92,49.5 L 85,53 Z", { "stroke-width": 1.5, opacity: 0.75 }));
    }
    return svg;
  }

  function legendaLancador(val) {
    const d = lerLancador(val);
    const c = conferir(val, REGRAS_LANCADOR);
    const quantos = d.apps.length;
    const corpo = "o lançador com "
      + (quantos === 0 ? "nenhum programa vestido pelo MeowSystem"
        : (quantos === 1 ? "o único programa que o MeowSystem veste"
          : Math.min(4, quantos) + " dos " + quantos + " programas que o MeowSystem veste"))
      + ", " + (d.arruma
        ? "com o lançador arrumado (aplicativos de sistema escondidos e nomes longos encurtados)"
        : "com o lançador do jeito que o sistema entregou")
      + ", " + (d.bloqueados.length
        ? plural(d.bloqueados.length, "programa impedido", "programas impedidos") + " de subir no login"
        : "nenhum programa impedido de subir no login")
      + " e a loja do Spotify " + (d.loja ? "ligada" : "desligada");
    return montarLegenda(corpo, [
      notaDeErradas(c.erradas),
      d.arruma ? "é a única coisa que o MeowSystem faz fora da sua pasta pessoal, e um apt do pacote desfaz" : "",
      d.loja ? "" : "desligada, a loja só deixa de ser INSTALADA — se ela já estiver no seu Spotify, continua lá",
      d.arruma ? "a fileira de baixo é desenho: quantos atalhos de sistema esta máquina tem, o painel não sabe" : "",
    ]);
  }

  /* ======================================================================== */
  /* 7. Manutenção                                                             */
  /* ======================================================================== */
  /* A PERGUNTA: esta seção tem nove chaves e todas parecem a mesma coisa —
   * "conferir", "vigiar", "avisar". A diferença que importa é POR QUE cada uma
   * existe, e ela é de TEMPO: o conserto é um relógio (uma vez por dia, às 5h)
   * e os três vigias são gatilhos de EVENTO (soltou um SVG, atualizou um
   * flatpak, desinstalou um jogo). Por isso o relógio fica separado, à
   * esquerda, movendo a esteira onde as três engrenagens estão presas: quem
   * olha entende na hora que uma coisa espera e as outras três reagem.
   *
   * O sino em cima de uma engrenagem é o par NOTIFICAR dela. O vigia do Steam
   * não tem sino porque não tem chave de aviso — e essa ausência é informação:
   * o desenho não inventa um interruptor que não existe.
   *
   * A FOLHA PEDIU TRÊS ENGRENAGENS e é isso que está desenhado; o relógio não é
   * a quarta. Ele é o que move a linha, porque AUTO_REPARO="nao" não desliga os
   * vigias — desliga o conserto diário (e, por tabela, o modo de leitura). */
  const REGRAS_MANUTENCAO = [
    { chave: "AUTO_REPARO", ok: booleanoValido },
    { chave: "AUTO_REPARO_NOTIFICAR", ok: booleanoValido },
    { chave: "ASSETS_VIGIA", ok: booleanoValido },
    { chave: "ASSETS_VIGIA_NOTIFICAR", ok: booleanoValido },
    { chave: "FLATPAK_VIGIA", ok: booleanoValido },
    { chave: "FLATPAK_VIGIA_NOTIFICAR", ok: booleanoValido },
    { chave: "STEAM_VIGIA", ok: booleanoValido },
    { chave: "BACKUPS_MANTIDOS", ok: (s) => numeroValido(s, 0, 999) },
    { chave: "LOG_NIVEL", ok: (s) => escolhaValida(s, ["silencioso", "info", "debug"]) },
  ];

  function lerManutencao(val) {
    return {
      reparo: ligado(val.AUTO_REPARO, true),
      reparoAvisa: ligado(val.AUTO_REPARO_NOTIFICAR, true),
      vigias: [
        { rotulo: "logo", ligado: ligado(val.ASSETS_VIGIA, true), avisa: ligado(val.ASSETS_VIGIA_NOTIFICAR, true) },
        { rotulo: "bandeja", ligado: ligado(val.FLATPAK_VIGIA, true), avisa: ligado(val.FLATPAK_VIGIA_NOTIFICAR, true) },
        { rotulo: "jogos", ligado: ligado(val.STEAM_VIGIA, true), avisa: null },
      ],
      backups: Math.round(numero(val.BACKUPS_MANTIDOS, 10, 0, 999)),
      fala: escolha(val.LOG_NIVEL, ["silencioso", "info", "debug"], "info"),
    };
  }

  function desenharManutencao(val) {
    const d = lerManutencao(val);
    const svg = moldura("o conserto diário movendo a esteira dos três vigias, e as tarjas de aviso que cada um põe na tela");

    /* A FAIXA DE CIMA são os dois medidores de QUANTO — quantos backups ficam
     * guardados e quanto o MeowSystem fala. Eles subiram para cá em 07/09/2026
     * para abrir o rodapé inteiro às tarjas de aviso, e a máquina do meio não
     * andou um milímetro: é ela que responde pelas quatro chaves de liga-desliga
     * desta seção, e mexer nela seria mexer no par que já funciona. */

    /* Os backups: uma pilha, e o número. Com "0" a poda está desligada e a pilha
     * não para de crescer — daí a folha pontilhada continuando embaixo dela. */
    svg.appendChild(retangulo(4, 0, 13, 5, 1.5, { "stroke-width": 1.4 }));
    svg.appendChild(retangulo(7, 2.5, 13, 5, 1.5, { "stroke-width": 1.4 }));
    svg.appendChild(retangulo(10, 5, 13, 5, 1.5, { "stroke-width": 1.4 }));
    if (d.backups === 0) {
      svg.appendChild(retangulo(13, 6.5, 13, 5, 1.5, {
        "stroke-width": 1.2, "stroke-dasharray": "3 3", opacity: 0.5,
      }));
    }
    svg.appendChild(texto(28, 8.5, d.backups === 0 ? "todos" : String(d.backups), {
      "font-size": 5.5, "text-anchor": "start",
    }));

    /* Quanto o MeowSystem fala: três degraus, e o escolhido aceso. Um número
     * seria mais preciso e menos claro — verbosidade é quantidade, e quantidade
     * se desenha com altura. */
    const niveis = ["silencioso", "info", "debug"];
    const alturas = [4, 7, 10];
    for (let i = 0; i < 3; i++) {
      const x = 73 + i * 7;
      const h = alturas[i];
      svg.appendChild(retangulo(x, 10 - h, 5, h, 1, d.fala === niveis[i]
        ? { "stroke-width": 1.8, stroke: "var(--mauve)" }
        : { "stroke-width": 1.2, opacity: 0.35 }));
    }
    svg.appendChild(texto(71, 8.5, d.fala, { "font-size": 4.5, "text-anchor": "end", opacity: 0.85 }));

    /* --- a máquina: o relógio espera, as três engrenagens reagem ----------- */
    svg.appendChild(linha(20, 20, 93, 20, { "stroke-width": 1.2, opacity: 0.35 }));

    const relogioAtrib = d.reparo
      ? { "stroke-width": 1.8 }
      : { "stroke-width": 1.4, "stroke-dasharray": "3 3", opacity: 0.4 };
    svg.appendChild(circulo(12, 20, 8, relogioAtrib));
    svg.appendChild(linha(12, 20, 12, 14.5, relogioAtrib));
    svg.appendChild(linha(12, 20, 15.5, 22.5, relogioAtrib));
    svg.appendChild(texto(12, 33, "diário", { "font-size": 4.5, opacity: 0.75 }));

    const centros = [39, 62, 85];
    for (let i = 0; i < 3; i++) {
      const v = d.vigias[i];
      const cx = centros[i];
      svg.appendChild(engrenagem(cx, 20, 8, v.ligado
        ? { "stroke-width": 1.8, stroke: "var(--mauve)" }
        : { "stroke-width": 1.4, "stroke-dasharray": "2.5 2.5", opacity: 0.4 }));
      svg.appendChild(texto(cx, 33, v.rotulo, { "font-size": 4.5, opacity: 0.75 }));
    }

    /* --- o que chega na tela dela ----------------------------------------- */
    /* Uma tarja por peça que TEM chave de aviso, na ordem em que as peças estão
     * lá em cima: o conserto diário, o vigia do logo, o vigia da bandeja. O
     * vigia dos jogos não ganha linha nenhuma porque não tem chave de aviso — e
     * essa ausência é informação, a mesma que o sino ausente carregava antes.
     *
     * A PEÇA DESLIGADA NÃO GANHA TARJA, nem pontilhada: quem não roda não tem
     * como avisar, e desenhar o lugar de um aviso impossível seria oferecer um
     * interruptor que não existe. Ligada e calada, aí sim: a tarja fica em
     * contorno pontilhado, dizendo onde o aviso apareceria. */
    const avisos = [
      { palavra: "conserto", ligado: d.reparo, avisa: d.reparoAvisa },
      { palavra: "logo", ligado: d.vigias[0].ligado, avisa: d.vigias[0].avisa },
      { palavra: "bandeja", ligado: d.vigias[1].ligado, avisa: d.vigias[1].avisa },
    ];
    const naTela = avisos.filter((a) => a.ligado);
    for (let i = 0; i < naTela.length; i++) {
      svg.appendChild(tarjaDeAviso(3, 37 + i * 7.6, 94, 6.6, naTela[i].palavra, naTela[i].avisa));
    }
    return svg;
  }

  function legendaManutencao(val) {
    const d = lerManutencao(val);
    const c = conferir(val, REGRAS_MANUTENCAO);
    const acesos = d.vigias.filter((v) => v.ligado);
    const avisando = [
      d.reparo && d.reparoAvisa ? "conserto" : "",
      d.vigias[0].ligado && d.vigias[0].avisa ? "logo" : "",
      d.vigias[1].ligado && d.vigias[1].avisa ? "bandeja" : "",
    ].filter(Boolean);
    const corpo = (d.reparo ? "o conserto diário às 5h" : "o conserto diário desligado")
      + " e " + (acesos.length
        ? acesos.length + " dos 3 vigias acesos (" + acesos.map((v) => v.rotulo).join(", ") + ")"
        : "nenhum dos 3 vigias aceso")
      + ", " + (avisando.length
        ? plural(avisando.length, "tarja na tela", "tarjas na tela") + " (" + avisando.join(", ") + ")"
        : "nenhuma tarja na tela")
      + ", " + (d.backups === 0 ? "todos os backups guardados" : plural(d.backups, "backup guardado", "backups guardados"))
      + " e o MeowSystem falando em " + d.fala;
    return montarLegenda(corpo, [
      notaDeErradas(c.erradas),
      "a tarja é a notificação do sistema; o vigia dos jogos não tem chave de aviso e por isso não tem tarja",
      !d.reparo ? "com o conserto desligado o modo de leitura também não é aplicado nem agendado" : "",
      c.vazias.length ? VAZIO_FABRICA : "",
    ]);
  }

  /* ======================================================================== */
  /* 8. Áreas de trabalho                                                      */
  /* ======================================================================== */
  /* A PERGUNTA QUE O DESENHO RESPONDE: as três chaves desta seção falam de uma
   * coisa que ela NÃO VÊ ao salvar. O `pinned_workspaces` é lido pelo
   * cosmic-comp uma vez, ao iniciar a sessão: mudar aqui e olhar a barra não
   * mostra nada até o próximo login. Sem desenho, a seção inteira é um campo de
   * texto e um ato de fé.
   *
   * Então o desenho é a BARRA COMO ELA VAI FICAR. Em cima, as pastilhas na
   * ordem exata da lista — a primeira da lista desenhada na primeira posição,
   * que é a frase da chave dita em figura. Embaixo, uma tela por área com as
   * janelas encaixadas ou soltas, porque "encaixe" é palavra e duas janelas
   * lado a lado contra duas empilhadas é a diferença.
   *
   * A FOLGA É O CASO MAIS DIFÍCIL, e é o que mais precisa de figura: o valor é
   * um caractere INVISÍVEL (U+2007) dos dois lados do nome. Desenhar um espaço
   * invisível é desenhar a pastilha mais larga com o texto no mesmo tamanho, e
   * marcar onde o espaço entrou — os dois tracinhos internos são isso, e são a
   * única parte do desenho que não existe na tela dela de verdade. */
  function lerAreas(val) {
    const nomes = lista(val.AREAS_NOMES, ",");
    const folga = lista(val.AREAS_FOLGA, ",").map(achatar);
    /* Uma resposta vale para todas; uma lista vale área a área, na ordem de
     * cima. É a regra da chave, e é aqui que ela vira desenho. */
    const encaixe = lista(val.AREAS_ENCAIXE, ",");
    const porArea = nomes.map((nome, i) => {
      const bruto = encaixe.length === 1 ? encaixe[0] : encaixe[i];
      return {
        nome: nome,
        folga: folga.indexOf(achatar(nome)) >= 0,
        /* `null` não é "não": é "esta chave não fala deste assunto, quem manda
         * é o `JANELAS_TILING` da seção Cor e tela". O desenho tem de saber a
         * diferença, senão promete um lado a lado desligado que ele não sabe. */
        encaixe: bruto === undefined || bruto === "" ? null
          : (booleanoValido(bruto) ? ligado(bruto, false) : null),
      };
    });
    return { areas: porArea, herda: encaixe.length === 0 };
  }

  function desenharAreas(val) {
    const d = lerAreas(val);
    const svg = moldura("a barra com as áreas na ordem da lista, e as janelas de cada uma");

    /* --- a barra, e as pastilhas na ordem da lista --- */
    svg.appendChild(retangulo(3, 3, 94, 13, 3, { "stroke-width": 1.8 }));

    /* Cabem quatro pastilhas com folga; a partir daí o desenho contaria um
     * número em vez de mostrar a ordem, que é o assunto. As excedentes viram
     * um "+N" — o desenho continua honesto sobre quantas existem. */
    const MOSTRA = Math.min(d.areas.length, 4);
    const sobra = d.areas.length - MOSTRA;
    let x = 6.5;
    for (let i = 0; i < MOSTRA; i++) {
      const a = d.areas[i];
      /* A LARGURA SAI DA MEDIÇÃO, NÃO DO CHUTE. `getBBox()` na página, com
       * `font-size: 4.4`: "Meow" ocupa 12,65 unidades — 3,16 por caractere.
       * A conta é meia-largura do texto + a folga do tracinho + um respiro,
       * e as duas primeiras versões (2,6 e 3,2 por caractere sem respiro)
       * desenharam o tracinho POR CIMA da palavra. */
      const larg = Math.min(30, Math.max(14, a.nome.length * 3.2 + (a.folga ? 8 : 5)));
      /* A PRIMEIRA É A ATIVA. Não é enfeite: a chave promete que "a primeira da
       * lista é a primeira da barra", e sem nada distinguindo a primeira o
       * desenho não diria se a ordem foi respeitada. */
      const ativa = i === 0;
      svg.appendChild(retangulo(x, 5.5, larg, 8, 4, ativa
        ? { "stroke-width": 1.7, stroke: "var(--mauve)" }
        : { "stroke-width": 1.3, opacity: 0.6 }));
      svg.appendChild(texto(x + larg / 2, 11.2, cortar(a.nome, 7), {
        "font-size": 4.4, opacity: ativa ? 1 : 0.75,
      }));
      if (a.folga) {
        /* Os dois tracinhos são o espaço-figura, um de cada lado. Pontilhados
         * porque o caractere é invisível: traço cheio leria como borda. */
        const marca = { "stroke-width": 1, "stroke-dasharray": "1.4 1.4", opacity: 0.75 };
        svg.appendChild(linha(x + 2.2, 7, x + 2.2, 12, marca));
        svg.appendChild(linha(x + larg - 2.2, 7, x + larg - 2.2, 12, marca));
      }
      x += larg + 3;
    }
    if (sobra > 0) {
      svg.appendChild(texto(Math.min(x + 4, 94), 11.2, "+" + sobra, {
        "font-size": 4.4, opacity: 0.6,
      }));
    }

    /* --- uma tela por área, com as janelas dentro --- */
    const n = Math.max(1, MOSTRA);
    const vao = 4;
    const larguraTela = (94 - vao * (n - 1)) / n;
    for (let i = 0; i < n; i++) {
      const a = d.areas[i] || { nome: "", encaixe: null };
      const tx = 3 + i * (larguraTela + vao);
      svg.appendChild(retangulo(tx, 22, larguraTela, 25, 2.5, { "stroke-width": 1.5, opacity: 0.85 }));

      const mx = tx + 2.5;
      const mw = larguraTela - 5;
      if (a.encaixe === true) {
        /* Encaixado: duas janelas dividem a área e não se tocam. */
        svg.appendChild(retangulo(mx, 25, mw / 2 - 1, 19, 1.5,
          { "stroke-width": 1.3, stroke: "var(--green)" }));
        svg.appendChild(retangulo(mx + mw / 2 + 1, 25, mw / 2 - 1, 19, 1.5,
          { "stroke-width": 1.3, stroke: "var(--green)" }));
      } else if (a.encaixe === false) {
        /* Solto: duas janelas empilhadas, uma por cima da outra. O `fill` da de
         * cima é o que diz "ela esconde a de baixo" — é a mesma decisão do
         * vidro, e é o único lugar do desenho onde o chapado informa. */
        svg.appendChild(retangulo(mx, 25, mw * 0.62, 14, 1.5, { "stroke-width": 1.2, opacity: 0.55 }));
        svg.appendChild(retangulo(mx + mw * 0.3, 30, mw * 0.62, 14, 1.5, {
          "stroke-width": 1.3, fill: "var(--base)",
        }));
      } else {
        /* Herdado: as janelas em pontilhado, porque quem decide está em outra
         * seção e este desenho não sabe o valor dela. */
        const solto = { "stroke-width": 1.2, "stroke-dasharray": "2.5 2.5", opacity: 0.45 };
        svg.appendChild(retangulo(mx, 25, mw / 2 - 1, 19, 1.5, solto));
        svg.appendChild(retangulo(mx + mw / 2 + 1, 25, mw / 2 - 1, 19, 1.5, solto));
      }
      if (a.nome) {
        svg.appendChild(texto(tx + larguraTela / 2, 54, cortar(a.nome, 9), {
          "font-size": 4.4, opacity: 0.8,
        }));
      }
    }
    return svg;
  }

  function legendaAreas(val) {
    const d = lerAreas(val);
    const c = conferir(val, [
      { chave: "AREAS_NOMES" },
      { chave: "AREAS_FOLGA" },
      { chave: "AREAS_ENCAIXE" },
    ]);
    if (!d.areas.length) {
      return montarLegenda("nenhuma área nomeada — sem nomes, a barra mostra a posição, não o nome");
    }
    const comFolga = d.areas.filter((a) => a.folga).map((a) => a.nome);
    const corpo = "a barra com " + plural(d.areas.length, "área", "áreas")
      + " nesta ordem: " + d.areas.map((a) => a.nome).join(", ");
    return montarLegenda(corpo, [
      comFolga.length ? "com folga invisível em " + comFolga.join(" e ") : "sem folga invisível em nenhuma",
      d.herda
        ? "o encaixe vem do lado a lado geral, em Cor e tela"
        : "encaixe por área: " + d.areas.map(
            (a) => a.nome + " " + (a.encaixe === null ? "herdado" : (a.encaixe ? "sim" : "não"))).join(", "),
      /* Esta nota não é sobre os valores: é sobre QUANDO eles valem, e é a
       * única coisa desta seção que surpreende quem salva e vai olhar a barra. */
      "vale no próximo início de sessão",
      c.erradas.length ? notaDeErradas(c.erradas) : "",
    ]);
  }

  /* ======================================================================== */
  /* 9. Instalação                                                             */
  /* ======================================================================== */
  /* ESTA SEÇÃO NÃO TEM CHAVE NENHUMA — são sete botões e nada mais, e é por
   * isso que ela ficou sem figura até hoje: o `parDePrevias` do app.js só roda
   * sobre grupo de CHAVES. Medido nas 14 abas, as três sem desenho são também
   * as que deixam mais tela vazia. Quem chama esta função é o
   * `desenhoDaSecaoSemChaves`, com `{}` na mão, e o contrato muda de lugar: sem
   * valores não há par antes/depois nem tempo real, e a figura responde uma
   * pergunta que não depende do meow.conf.
   *
   * A PERGUNTA QUE O DESENHO RESPONDE: "o que acontece quando eu aperto um
   * destes botões?". Os sete são variações de UM mecanismo, e é ele que está no
   * quadro:
   *
   *     a fila de etapas   →  cada uma OLHA a máquina antes de escrever
   *     já está no lugar   →  confere, e não escreve nada        (verde)
   *     está fora          →  guarda cópia, e então escreve      (pêssego)
   *
   * A ideia mais forte do projeto está aí e não aparecia em canto nenhum da
   * página: rodar de novo numa máquina pronta não escreve um byte. Quem decide
   * isso é a `meow_escrever` do lib/comum.sh, que compara o CONTEÚDO e volta
   * sem tocar no arquivo quando ele já está do jeito que devia — a volta de
   * baixo, da máquina para a fila, é essa segunda passagem.
   *
   * A GRAMÁTICA DAS DUAS CORES É A MESMA nas linhas da fila e nos dois
   * caminhos, senão o quadro seria dois riscos paralelos sem sentido. E o que
   * separa os caminhos não é a cor: é a PONTA. A do confere para antes da
   * moldura da tela e termina num visto; a do escreve atravessa a moldura, e só
   * depois de passar pela cópia. Cor confirma, geometria informa — quem não
   * distingue verde de pêssego continua vendo um traço que entra e um que não.
   *
   * OS DOIS NÚMEROS SÃO CONTADOS, NÃO LEMBRADOS: 52 é o tamanho do
   * `local etapas=(…)` do install.sh e 46 o do `VERIFICAVEIS=(…)` do bin/meow.
   * Os botões desta mesma página já dizem esses dois números na ajuda, e um
   * desenho que discordasse do botão ao lado seria pior que um desenho sem
   * número nenhum. As cinco linhas da fila, essas, são esquemáticas: quantas
   * escrevem muda a cada passagem, e é exatamente o que a segunda zera. */
  const ETAPAS_DO_INSTALADOR = 52;
  const CONFERENCIAS_DO_DOCTOR = 46;

  /* O visto mora aqui e não lá em cima com o sol e a lua, de propósito: é o
   * único desenho que precisa dele. Glifo genérico no topo do arquivo vira o
   * "check" que cada seção usa com um sentido diferente, e aí ele deixa de
   * significar alguma coisa. */
  function visto(cx, cy, tam, extra) {
    return caminho(
      "M " + q(cx - tam) + "," + q(cy + tam * 0.05)
      + " L " + q(cx - tam * 0.28) + "," + q(cy + tam * 0.72)
      + " L " + q(cx + tam) + "," + q(cy - tam * 0.78),
      Object.assign({ "stroke-width": 1.5 }, extra || {}));
  }

  function desenharInstalacao(val) {
    /* `val` chega `{}`. O parâmetro fica na assinatura porque o contrato é o
     * mesmo das outras oito entradas do mapa — não porque haja o que ler. Ler
     * qualquer coisa dele aqui seria inventar uma chave que esta seção não tem. */
    const svg = moldura(
      "as " + ETAPAS_DO_INSTALADOR + " etapas do instalador passando pela máquina: "
      + "a que já está no lugar confere e não escreve, a que está fora guarda cópia e escreve");

    /* --- a fila de etapas --- */
    svg.appendChild(texto(19, 7.6, ETAPAS_DO_INSTALADOR + " etapas", { "font-size": 5 }));
    svg.appendChild(retangulo(3, 10, 32, 38, 3, { "stroke-width": 1.5, opacity: 0.9 }));

    const LINHAS_DA_FILA = [15, 22, 29, 36, 43];
    for (let i = 0; i < LINHAS_DA_FILA.length; i++) {
      const y = LINHAS_DA_FILA[i];
      const escreve = i >= 3;
      if (escreve) {
        /* O quadradinho cheio é o único preenchimento do quadro, e ele É a
         * informação: cheio = alguma coisa foi gravada no disco. Em todo o
         * resto o traço basta. */
        svg.appendChild(retangulo(6.5, y - 1.7, 3.4, 3.4, 0.8, {
          fill: "var(--peach)", stroke: "none",
        }));
      } else {
        svg.appendChild(visto(8.2, y, 2.4, { stroke: "var(--green)", "stroke-width": 1.5 }));
      }
      svg.appendChild(linha(13, y, 31.5, y, escreve
        ? { "stroke-width": 1.5, stroke: "var(--peach)", opacity: 0.85 }
        : { "stroke-width": 1.2, opacity: 0.35 }));
    }

    /* --- a máquina --- */
    /* Tela com barra em cima e dock embaixo: é o mesmo desenho de máquina do
     * VIDRO E RELÓGIO, lá na Barra e dock, e quem viu um reconhece o outro sem
     * legenda. O pé existe só para que a moldura não seja lida como "janela" —
     * o que a etapa atravessa é o computador inteiro. */
    svg.appendChild(retangulo(68, 13, 29, 26, 2.5, { "stroke-width": 1.6 }));
    svg.appendChild(retangulo(70.5, 15, 24, 4, 1.2, { "stroke-width": 1.1, opacity: 0.55 }));
    svg.appendChild(retangulo(77, 31, 11, 3, 1.5, { "stroke-width": 1.1, opacity: 0.55 }));
    svg.appendChild(linha(82.5, 39, 82.5, 43, { "stroke-width": 1.4, opacity: 0.8 }));
    svg.appendChild(linha(76, 43.5, 89, 43.5, { "stroke-width": 1.6, opacity: 0.8 }));

    /* --- quem só confere --- */
    /* Tracejado e parando ANTES da moldura: conferir lê a máquina e não deixa
     * nada nela. O visto no fim é o mesmo glifo das três primeiras linhas da
     * fila, e é ele que amarra a fila ao caminho. */
    svg.appendChild(texto(45, 17.5, "confere", {
      "font-size": 4.4, fill: "var(--green)", opacity: 0.95,
    }));
    svg.appendChild(linha(35.5, 22, 51.5, 22, {
      "stroke-width": 1.4, stroke: "var(--green)", "stroke-dasharray": "3 2.5",
    }));
    svg.appendChild(visto(57, 22, 4, { stroke: "var(--green)", "stroke-width": 1.9 }));

    /* --- quem escreve --- */
    /* A cópia vem ANTES da seta, e a ordem é a de verdade: nenhuma escrita
     * deste projeto acontece sem que o arquivo de antes esteja guardado. Duas
     * folhas sobrepostas, e não uma: uma folha só seria "arquivo", e o que se
     * guarda é a segunda via. As duas linhas dentro da folha da frente foram
     * medidas na tela — sem elas, na primeira conferência a olho, o par de
     * retângulos lia como um interruptor. */
    svg.appendChild(linha(35.5, 36, 37.5, 36, { "stroke-width": 1.6, stroke: "var(--peach)" }));
    svg.appendChild(retangulo(37.5, 27.5, 11, 12, 1, { "stroke-width": 1.3, opacity: 0.55 }));
    svg.appendChild(retangulo(40.5, 30, 11, 12, 1, { "stroke-width": 1.5 }));
    /* As duas linhas de dentro ficam LONGE do caminho — uma acima, outra
     * abaixo. Amontoadas em volta dele (35 e 37,5, com a seta em 36) o conjunto
     * virava um borrão de três riscos paralelos. */
    svg.appendChild(linha(43, 33.5, 49, 33.5, { "stroke-width": 1, opacity: 0.5 }));
    svg.appendChild(linha(43, 38.5, 47.5, 38.5, { "stroke-width": 1, opacity: 0.5 }));
    svg.appendChild(linha(51.5, 36, 71, 36, { "stroke-width": 1.6, stroke: "var(--peach)" }));
    /* OS DOIS RÓTULOS FICAM NA MESMA LINHA DE BASE, embaixo do caminho, e os
     * centros estão medidos na tela: com "cópia" em 46,5 e "escreve" em 60 as
     * duas palavras se encostaram e leram como uma só. A folga de agora é de
     * quase quatro unidades, que na tela dela dão dez pixels. */
    svg.appendChild(texto(44.5, 46.5, "cópia", { "font-size": 4.4, opacity: 0.85 }));
    svg.appendChild(texto(62, 46.5, "escreve", {
      "font-size": 4.4, fill: "var(--peach)", opacity: 0.95,
    }));
    /* A ponta entra 3 unidades DENTRO da moldura. Encostar na borda seria o
     * mesmo desenho do caminho de cima com outra cor. */
    svg.appendChild(grupo({ stroke: "var(--peach)", "stroke-width": 1.6 }, [
      seta(71, 36, 0, 3.4),
    ]));

    /* --- rodar de novo --- */
    /* A volta da máquina para o começo da fila, apagada de propósito: ela é a
     * promessa que a página inteira faz e que nenhum botão mostra. Na segunda
     * passagem as cinco linhas ficam verdes e o instalador termina dizendo, com
     * essas palavras, que nenhuma etapa precisou escrever nada. */
    svg.appendChild(caminho("M 88,44 L 88,54 L 19,54 L 19,50", {
      "stroke-width": 1.2, opacity: 0.5,
    }));
    svg.appendChild(grupo({ "stroke-width": 1.2, opacity: 0.5 }, [seta(19, 50, -90, 3)]));
    /* O rótulo fica do lado da PONTA, e não no meio da volta: no meio ele caía
     * embaixo de "cópia" e de "escreve", e os três viravam um bloco de texto. */
    svg.appendChild(texto(31, 52.5, "de novo", { "font-size": 4.4, opacity: 0.6 }));
    return svg;
  }

  function legendaInstalacao(val) {
    /* Sem chave não há número lido do disco, então a legenda não confere valor
     * nenhum: ela diz o que foi desenhado e emenda o que o desenho não cabe —
     * qual botão é qual caminho. */
    const corpo = "as " + ETAPAS_DO_INSTALADOR + " etapas do instalador passando uma a uma pela"
      + " máquina — a que já está no lugar confere e não escreve nada, a que está fora guarda"
      + " cópia e só então escreve";
    return montarLegenda(corpo, [
      "o «Conferir a máquina» é só o caminho verde: " + CONFERENCIAS_DO_DOCTOR
        + " conferências, e nenhuma escrita",
      "a cópia é o que o «Voltar ao tema de antes» devolve",
      "a volta de baixo é rodar de novo: numa máquina já pronta, nenhuma etapa escreve",
    ]);
  }

  /* ======================================================================== */
  /* 9. Idempotência                                                           */
  /* ======================================================================== */
  /* A PERGUNTA QUE O DESENHO RESPONDE: por que ATUALIZAR A MÁQUINA é assunto
   * deste projeto, e não do terminal dela. Ela já tem o comando — está escrito
   * no cabeçalho do `atualizar_sistema.sh`, uma linha com `apt full-upgrade`,
   * `topgrade` e `cargo install-update`. O que essa linha não tem é a SEGUNDA
   * METADE: cada troca de pacote (cosmic-comp, cosmic-panel, fastfetch,
   * papirus) desfaz alguma coisa que este projeto escreveu, e ninguém se lembra
   * de rodar o `doctor` depois de uma atualização de meia hora.
   *
   * Então o desenho é a linha do tempo das duas metades: as três fontes
   * atualizam, uma peça do MeowSystem cai da prateleira, a lupa do `doctor`
   * fica em cima do buraco e a seta verde repõe a peça. Os dois colchetes
   * embaixo são a frase inteira sem frase nenhuma — o pontilhado mede até onde
   * vai o comando digitado à mão, o cheio mede o que esta página faz.
   *
   * ESTA SEÇÃO NÃO TEM CHAVE, SÓ TRÊS AÇÕES, e por isso a função é chamada com
   * `{}`. Não há valor para ler, não há par antes/depois e não há tempo real:
   * é uma figura sobre o que a página faz com a máquina, não sobre um número
   * gravado no meow.conf. As duas funções abaixo mantêm a forma das outras oito
   * (o mesmo `val`, o mesmo `seguro`) e não tocam em chave nenhuma — o dia em
   * que a seção ganhar uma, o contrato já está de pé.
   *
   * AS QUATRO PEÇAS SÃO AS DO SCRIPT, não uma invenção: o passo "4/4 O que a
   * atualização desfez" nomeia o tema, os ícones, o applet da barra e o gato do
   * terminal. Quatro com nome, e não as 46 conferências do `doctor`: medido na
   * página, este quadro sai com 250 x 150 px na tela dela — 2,5 px por unidade
   * do viewBox —, e 46 quadradinhos ali dentro seriam 46 pontos de 5 px, que é
   * o mesmo que nada.
   *
   * A PEÇA CAI, NÃO GANHA UM X. Um X vermelho em cima do quadrado leria "deu
   * erro"; o que um `full-upgrade` faz é outra coisa — a peça deixa de estar no
   * lugar. Buraco pontilhado em cima e o quadrado tombado embaixo dizem isso, e
   * dizem também que a peça não sumiu: ela está ali para ser reposta. */
  const PECAS_DA_PRATELEIRA = ["tema", "ícones", "barra", "gato"];
  /* A terceira, e não a primeira: uma peça no meio da fila deixa o buraco
   * cercado dos dois lados, e na ponta ele leria como o fim da prateleira. E é
   * a "barra" porque o `cosmic-panel` é um dos quatro pacotes que o cabeçalho
   * do script nomeia como os que a atualização troca. */
  const PECA_QUE_CAI = 2;
  const PRATELEIRA = { x: 44, y: 8, w: 11, h: 10, passo: 13.5, linha: 19.5 };

  function desenharIdempotencia(val) {
    const svg = moldura("apt, flatpak e cargo atualizando a máquina, uma peça do MeowSystem caindo da prateleira e a conferência repondo a peça");

    /* --- as três fontes, empilhadas e etiquetadas --- */
    /* São os três nomes que aparecem na saída do script, na ordem em que ele os
     * roda. A seta para cima é a versão subindo; ela fica em `currentColor` de
     * propósito, para que o verde do desenho signifique uma coisa só (repor) e
     * o vermelho, uma só (o que caiu). */
    const fontes = ["apt", "flatpak", "cargo"];
    for (let i = 0; i < fontes.length; i++) {
      const y = 5 + i * 11;
      svg.appendChild(retangulo(3, y, 27, 8, 3, { "stroke-width": 1.6 }));
      svg.appendChild(texto(6.5, y + 5.6, fontes[i], {
        "font-size": 4.8, "text-anchor": "start",
      }));
      svg.appendChild(linha(26.5, y + 6, 26.5, y + 2.4, { "stroke-width": 1.5 }));
      svg.appendChild(grupo({ "stroke-width": 1.5 }, [seta(26.5, y + 2.4, -90, 2.1)]));
    }

    /* A atualização passando: uma seta só, do bloco das fontes para a
     * prateleira. Ela é o "logo depois" do texto da ação. */
    svg.appendChild(linha(32.5, 20, 39.5, 20, { "stroke-width": 1.6 }));
    svg.appendChild(grupo({ "stroke-width": 1.6 }, [seta(39.5, 20, 0, 3)]));

    /* --- a prateleira do MeowSystem --- */
    /* Os nomes ficam ACIMA dos quadrados: embaixo da prateleira é onde a peça
     * caída mora, e rótulo em cima de peça caída seria a legenda do lugar
     * errado. */
    for (let i = 0; i < PECAS_DA_PRATELEIRA.length; i++) {
      const x = PRATELEIRA.x + i * PRATELEIRA.passo;
      const cx = x + PRATELEIRA.w / 2;
      const caiu = i === PECA_QUE_CAI;
      svg.appendChild(texto(cx, 5.5, PECAS_DA_PRATELEIRA[i], {
        "font-size": 4.2, opacity: caiu ? 1 : 0.75,
      }));
      if (caiu) {
        svg.appendChild(retangulo(x, PRATELEIRA.y, PRATELEIRA.w, PRATELEIRA.h, 2, {
          "stroke-width": 1.5, "stroke-dasharray": "3 3", stroke: "var(--red)",
        }));
      } else {
        /* Quadrado limpo, sem miolo. A primeira versão punha um círculo dentro
         * de cada peça, e na captura da página o círculo saiu do tamanho da
         * lente da lupa: as três peças inteiras e o buraco com a lupa em cima
         * viraram quatro quadrados com uma bolinha dentro, e o buraco — que é a
         * informação — desapareceu. */
        svg.appendChild(retangulo(x, PRATELEIRA.y, PRATELEIRA.w, PRATELEIRA.h, 2, {
          "stroke-width": 1.8, stroke: "var(--mauve)",
        }));
      }
    }
    svg.appendChild(linha(42, PRATELEIRA.linha, 97, PRATELEIRA.linha, {
      "stroke-width": 1.8, opacity: 0.7,
    }));

    /* A peça no chão. O giro é o que a faz LER como caída — o mesmo quadrado
     * sem giro, embaixo da prateleira, leria como uma quinta peça guardada. */
    svg.appendChild(grupo({ stroke: "var(--red)", transform: "rotate(-16 69 35)" }, [
      retangulo(63.5, 30, PRATELEIRA.w, PRATELEIRA.h, 2, { "stroke-width": 1.8 }),
    ]));

    /* A volta. Verde, e é a única coisa verde do quadro: é a metade que só este
     * projeto tem. Ela atravessa a linha da prateleira de propósito — a peça
     * volta PARA CIMA dela, e uma seta que parasse embaixo diria "achei", que é
     * meio serviço. */
    svg.appendChild(caminho("M 74.5,29 C 78.2,27 78.6,23 77.8,18.4", {
      "stroke-width": 1.8, stroke: "var(--green)",
    }));
    svg.appendChild(grupo({ stroke: "var(--green)", "stroke-width": 1.8 }, [
      seta(77.8, 18.4, -99, 3),
    ]));

    /* A lupa em cima do buraco é o `doctor`: ele não conserta sozinho no
     * "aplicar" — ele DIZ o que saiu do lugar, e o conserto é o botão seguinte.
     * Por isso ela fica em `currentColor`, entre o vermelho do que caiu e o
     * verde do que volta. */
    svg.appendChild(circulo(78, 11, 3.6, { "stroke-width": 1.8 }));
    svg.appendChild(linha(80.5, 13.5, 84, 17, { "stroke-width": 2 }));
    /* O nome embaixo, na direção em que o cabo aponta: é a palavra que ela lê
     * nos três botões desta página ("e logo depois o doctor"), e sem ela a lupa
     * seria só uma lupa — a figura ficaria dizendo "alguém olha" em vez de
     * "este comando olha". */
    svg.appendChild(texto(89, 30, "doctor", { "font-size": 4.6, opacity: 0.75 }));

    /* --- os dois colchetes: a medida do que cada caminho cobre --- */
    /* O pontilhado abraça só as três fontes — é onde o comando à mão termina. O
     * cheio abraça o quadro inteiro, prateleira e lupa incluídas. Colchete e
     * não chave porque é medida, e medida neste arquivo já se desenha assim (a
     * cota da largura da música). */
    svg.appendChild(caminho("M 3,38.5 L 3,42.5 L 30,42.5 L 30,38.5", {
      "stroke-width": 1.3, "stroke-dasharray": "3 3", opacity: 0.6,
    }));
    svg.appendChild(texto(16.5, 47.8, "à mão", { "font-size": 4.8, opacity: 0.7 }));

    svg.appendChild(caminho("M 3,50 L 3,53 L 96,53 L 96,50", { "stroke-width": 1.6 }));
    svg.appendChild(texto(49.5, 58.2, "esta página", { "font-size": 4.8 }));
    return svg;
  }

  function legendaIdempotencia(val, depois) {
    const corpo = "apt, flatpak e cargo atualizando a máquina numa tela só e, logo depois,"
      + " a conferência: a troca de pacotes derrubou uma peça do MeowSystem, a lupa do"
      + " doctor está em cima do buraco e a seta verde repõe a peça na prateleira";
    return montarLegenda(corpo, [
      "o colchete pontilhado mede até onde vai um full-upgrade digitado à mão; o cheio, o que esta página faz",
      "as quatro peças são exemplo: o doctor faz 46 conferências e diz quais saíram do lugar",
      "\"O que a atualização mudaria\" não escreve nada; quem mexe na máquina é \"Atualizar a máquina inteira\"",
    ]);
  }

  /* ======================================================================== */
  /* 10. Início                                                                */
  /* ======================================================================== */
  /* A PERGUNTA QUE O DESENHO RESPONDE: "o que este painel faz com a minha
   * máquina?" — e a resposta certa NÃO é o mapa das páginas.
   *
   * O mapa já está na tela três vezes no instante em que ela abre o painel: o
   * trilho da esquerda lista as treze páginas com a contagem de cada uma, as
   * duas portas somam os ajustes por bloco, e o cabeçalho traz o total. Um
   * desenho do mapa seria a quarta cópia da única coisa que a home já diz bem.
   *
   * O QUE NÃO ESTÁ DESENHADO EM LUGAR NENHUM é a regra da casa — "gravar não é
   * aplicar", e antes dela "clicar não é gravar". Hoje ela é uma frase cinza no
   * canto da coluna da direita ("Escolher aqui não muda a máquina: clicar
   * guarda, e «Salvar e aplicar» é o que grava e aplica"), e é exatamente o que
   * quem chega não sabe: em todo outro painel de ajustes do mundo, clicar É
   * aplicar.
   *
   * ENTÃO O DESENHO É O CAMINHO DE UMA ESCOLHA, e cada traço dele sai do
   * código, não da imaginação: `escolher()` põe a chave em `MUDANCAS` e não
   * fala com o servidor; `salvarEscolhas()` é o único caminho de escrita da
   * página e faz DUAS coisas, nesta ordem — grava chave a chave no `meow.conf`
   * e só então chama `rodarAcao("instalar")`. Os dois traços verdes são essas
   * duas metades, e é por isso que são dois, e não um.
   *
   * A PAREDE PONTILHADA É O DISCO, e o botão é o único buraco nela. Por isso
   * ele fica montado EM CIMA da linha, e não ao lado dela: mais nada atravessa.
   *
   * AS TRÊS ESCOLHAS SÃO ESQUEMÁTICAS, como as cinco linhas da fila da
   * Instalação. Esta função é chamada com `{}` — não há valor nenhum para ler,
   * e desenhar "3 escolhas esperando" seria inventar um número. Quem conta é o
   * banner do alto da página, que é onde o número vive de verdade. */
  function desenharInicio(val) {
    /* `val` chega `{}`, como em "Instalação" e "Idempotência": a home não tem
     * chave, e ler qualquer coisa daqui seria inventar uma. */
    const svg = moldura(
      "o caminho de uma escolha: os cartões marcados ficam guardados na página, e só o "
      + "«Salvar e aplicar» atravessa a linha do disco — primeiro grava o meow.conf, "
      + "depois roda o instalador, que é quem muda a tela");

    /* --- deste lado: a página --- */
    /* A moldura com uma barra no alto é a mesma que o desenho da Instalação usa
     * para "a máquina", virada para dentro: aqui ela é a PÁGINA, e a barra do
     * alto é onde nasce o banner do «Salvar e aplicar» quando há escolha. */
    svg.appendChild(retangulo(2, 9, 27, 38, 2.5, { "stroke-width": 1.6 }));
    svg.appendChild(retangulo(4.5, 11.8, 22, 4, 1.2, { "stroke-width": 1, opacity: 0.5 }));

    /* Cada linha é um cartão de duas opções com o lado apertado marcado, e o
     * preenchimento É a informação — é o mesmo tratamento que o botão de
     * verdade recebe (borda no acento e um véu do acento por dentro). */
    for (let i = 0; i < 3; i++) {
      const cy = 23 + i * 9;
      svg.appendChild(retangulo(5.5, cy - 3.2, 9, 6.4, 1.4, {
        "stroke-width": 1.1, opacity: 0.45,
      }));
      svg.appendChild(retangulo(16.5, cy - 3.2, 9, 6.4, 1.4, {
        "stroke-width": 1.7, stroke: "var(--accent)",
        fill: "var(--accent)", "fill-opacity": 0.3,
      }));
    }
    svg.appendChild(texto(15.5, 53.5, "só guardado", { "font-size": 4.6, opacity: 0.8 }));

    /* --- a linha do disco, e o único buraco nela --- */
    /* Dois pedaços, com a falha na altura exata do botão: a linha separa
     * "escolhido" de "escrito", e o botão é a porta. Ele fica montado EM CIMA
     * dela, e não ao lado, porque mais nada atravessa. */
    svg.appendChild(linha(46.5, 4.5, 46.5, 19.5, {
      "stroke-width": 1.2, "stroke-dasharray": "3 3", opacity: 0.45,
    }));
    svg.appendChild(linha(46.5, 36.5, 46.5, 52, {
      "stroke-width": 1.2, "stroke-dasharray": "3 3", opacity: 0.45,
    }));

    svg.appendChild(linha(29.5, 28, 33.5, 28, { "stroke-width": 1.6 }));
    svg.appendChild(grupo({ "stroke-width": 1.6 }, [seta(33.5, 28, 0, 3)]));

    svg.appendChild(retangulo(35, 21, 23, 14, 3.2, {
      "stroke-width": 1.9, stroke: "var(--accent)",
    }));
    /* O rótulo inteiro, em duas linhas: "Salvar" sozinho seria outro botão. */
    svg.appendChild(texto(46.5, 26.6, "Salvar e", {
      "font-size": 4.4, fill: "var(--accent)",
    }));
    svg.appendChild(texto(46.5, 31.8, "aplicar", {
      "font-size": 4.4, fill: "var(--accent)",
    }));

    /* --- do outro lado: o arquivo, e só depois a tela --- */
    /* DOIS TRAÇOS, E NÃO UM. `salvarEscolhas()` faz duas coisas em ordem: grava
     * chave a chave no meow.conf e só então chama o instalador. Um traço só
     * leria como um gesto, e é justamente o gesto que a frase da casa parte em
     * dois — "gravar não é aplicar". */
    svg.appendChild(linha(59, 28, 75, 28, { "stroke-width": 1.6, stroke: "var(--green)" }));
    svg.appendChild(grupo({ "stroke-width": 1.6, stroke: "var(--green)" }, [
      seta(75, 28, 0, 3),
    ]));
    svg.appendChild(texto(66, 24.4, "grava", {
      "font-size": 4.2, fill: "var(--green)", opacity: 0.95,
    }));

    /* O nome do arquivo fica ACIMA dele: embaixo é por onde a segunda seta
     * sai, e rótulo em cima de seta é o mesmo borrão de sempre. */
    svg.appendChild(texto(82.5, 17.4, "meow.conf", { "font-size": 4.2, opacity: 0.9 }));
    svg.appendChild(retangulo(76, 20, 13, 16, 1.4, { "stroke-width": 1.4 }));
    svg.appendChild(linha(78.5, 24.5, 86.5, 24.5, { "stroke-width": 1, opacity: 0.45 }));
    svg.appendChild(linha(78.5, 31.5, 86.5, 31.5, { "stroke-width": 1, opacity: 0.45 }));

    /* A PONTA PARA NA BORDA, e não 3 unidades dentro como a da Instalação: a
     * faixa de cima da tela é a barra, e uma seta pousada em cima dela leria
     * como "mexe na barra" em vez de "entra na máquina". */
    svg.appendChild(linha(82.5, 37, 82.5, 42.6, {
      "stroke-width": 1.6, stroke: "var(--green)",
    }));
    svg.appendChild(grupo({ "stroke-width": 1.6, stroke: "var(--green)" }, [
      seta(82.5, 42.6, 90, 3),
    ]));
    svg.appendChild(texto(74, 40.4, "aplica", {
      "font-size": 4.2, fill: "var(--green)", opacity: 0.95,
    }));

    /* A tela é o mesmo glifo de máquina do VIDRO E RELÓGIO e da Instalação —
     * moldura, barra em cima, dock embaixo. Quem viu um reconhece o outro. */
    svg.appendChild(retangulo(63, 44, 34, 13, 2, { "stroke-width": 1.6 }));
    svg.appendChild(retangulo(65.5, 45.7, 29, 3, 1, { "stroke-width": 1, opacity: 0.55 }));
    svg.appendChild(retangulo(74, 52.4, 12, 2.6, 1.3, { "stroke-width": 1, opacity: 0.55 }));
    return svg;
  }

  function legendaInicio(val) {
    /* UMA LINHA, COMO AS OUTRAS DEZ — 07/09/2026
     * A primeira versão desta legenda tinha o corpo mais três notas, e na tela
     * virou um bloco de quatro linhas correndo a página inteira: a legenda mais
     * comprida do painel, embaixo do desenho mais simples dele. As três notas
     * diziam coisas verdadeiras que o desenho já diz (que os cartões são
     * esquemáticos), que a tela já diz (o «Descartar» está ao lado do «Salvar»,
     * escrito), ou que pertencem a outra aba (as etapas do instalador). O
     * desenho existe para ser lido antes do texto; uma legenda de quatro linhas
     * inverte isso. */
    const corpo = "o caminho de uma escolha: clicar guarda na página, e só o «Salvar e aplicar»"
      + " atravessa a linha do disco — grava o meow.conf e roda o instalador, que é quem muda"
      + " a tela";
    return montarLegenda(corpo);
  }

  /* ======================================================================== */
  /* o mapa                                                                    */
  /* ======================================================================== */
  /* OS NOMES SÃO OS NOVOS. "Lançadores e jogos" era "Programas e jogos" e
   * "Modo de leitura" nasce agora, com as sete chaves LEITURA_* que hoje moram
   * em "Dia e noite" — as duas mudanças estão sendo feitas no meow.conf.exemplo
   * pela frente dos nomes. Enquanto ela não chegar, estas duas entradas não são
   * encontradas por ninguém e o resto continua funcionando; nenhuma delas
   * quebra nada por não achar a seção. */
  window.MEOW_PREVIAS = Object.assign(window.MEOW_PREVIAS || {}, {
    "Barra e dock :: VIDRO E RELÓGIO": seguro("o vidro da barra e o relógio", desenharVidro, legendaVidro),
    "Barra e dock :: MÚSICA NA BARRA": seguro("a música na barra", desenharMidia, legendaMidia),
    "Papel de parede": seguro("o papel de parede", desenharParede, legendaParede),
    "Dia e noite": seguro("o dia e a noite", desenharNoite, legendaNoite),
    "Modo de leitura": seguro("o modo de leitura", desenharLeitura, legendaLeitura),
    "Lançadores e jogos": seguro("os lançadores e os jogos", desenharLancador, legendaLancador),
    "Manutenção": seguro("a manutenção", desenharManutencao, legendaManutencao),
    "Áreas de trabalho": seguro("as áreas de trabalho", desenharAreas, legendaAreas),
    /* A CHAVE É O NOME DA SEÇÃO, sem bloco: esta página não tem grupo de chaves
     * para batizar um, e é o `desenhoDaSecaoSemChaves` que a procura por aqui. */
    "Instalação": seguro("a instalação", desenharInstalacao, legendaInstalacao),
    /* PELO NOME DA SEÇÃO, DE NOVO: quem a procura é o `desenhoDaSecaoSemChaves`
     * do app.js — a Idempotência só tem ações, e o `parDePrevias` nunca passa
     * por ela. */
    "Idempotência": seguro("a atualização e a conferência", desenharIdempotencia, legendaIdempotencia),
    /* A HOME TAMBÉM ENTRA PELO NOME, e ela é a terceira sem chave nenhuma. Uma
     * ressalva que as outras duas não têm: o `render` corta o grupo `home`
     * antes do bloco que chama o `desenhoDaSecaoSemChaves`, então registrar
     * aqui não basta — o `if (g.tipo === "home")` do app.js precisa chamá-lo. */
    "Início": seguro("o caminho de uma escolha", desenharInicio, legendaInicio),
  });
})();

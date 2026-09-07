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
    return { agora: agora, depois: depois, mudou: mudou };
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
        leitura = { agora: {}, depois: {}, mudou: false };
      }
      let antes = null;
      let depois = null;
      let legenda = "";
      try {
        antes = desenhar(leitura.agora);
      } catch (e) {
        antes = quadroDeSocorro(titulo);
      }
      try {
        depois = leitura.mudou ? desenhar(leitura.depois) : null;
      } catch (e) {
        depois = null;
      }
      try {
        legenda = legendar(leitura.agora, leitura.mudou ? leitura.depois : null);
      } catch (e) {
        legenda = montarLegenda(titulo + " (não deu para ler os valores desta seção)");
      }
      if (!legenda) legenda = montarLegenda(titulo);
      /* A legenda descreve o desenho da ESQUERDA, que é o que está valendo.
       * Quando existe o segundo desenho, ela precisa dizer o que ele é — senão
       * sobram dois desenhos parecidos e nenhuma pista de qual é qual. */
      if (depois) {
        legenda = legenda.replace(/\.$/, "")
          + " — à direita, o mesmo desenho com a escolha que ainda não foi salva.";
      }
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

  function desenharVidro(val) {
    const d = lerVidro(val);
    const svg = moldura("o painel e a dock sobre uma janela maximizada, com o relógio da barra");

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
  /* A asa direita da barra em corte: [capa][nome e banda][⏮⏸⏭][relógio]. Os
   * quatro números abaixo são a divisão desse espaço, e ela é apertada de
   * propósito — na dock dela o Now Playing divide a asa com a Área de status, e
   * um desenho folgado esconderia justamente o aperto que a chave da largura
   * existe para administrar. */
  const TEXTO_X = 20;
  const TEXTO_FIM = 58;

  function lerMidia(val) {
    const larguraPx = numero(val.MIDIA_LARGURA, 440, 80, 900);
    const auto = achatar(val.MIDIA_FONTE) === "auto" || vazio(val.MIDIA_FONTE);
    const fontePx = auto ? 0 : numero(val.MIDIA_FONTE, 12, 6, 48);
    /* 5 unidades é a letra que o painel usa quando a chave diz `auto`; a partir
     * daí o tamanho cravado sobe na mesma proporção, e o teto de 10 existe só
     * para o desenho não sair do quadro — que já é o sintoma que a chave
     * descreve, e ele aparece de qualquer jeito. */
    const fonte = auto ? 5 : Math.max(3, Math.min(10, 5 * (fontePx / 12)));
    const larguraDesenhada = 7 + (larguraPx / 900) * (TEXTO_FIM - TEXTO_X - 7);
    return {
      ligada: ligado(val.MIDIA, true),
      larguraPx: larguraPx,
      larguraDesenhada: larguraDesenhada,
      chapado: escolha(val.MIDIA_COR_ALBUM, ["traco", "chapado"], "traco") === "chapado",
      capa: ligado(val.MIDIA_CAPA, true),
      controles: ligado(val.MIDIA_CONTROLES, false),
      auto: auto,
      fontePx: fontePx,
      fonte: fonte,
      corTitulo: corDaPaleta(val.MIDIA_COR_TITULO, "var(--mauve)"),
      corArtista: corDaPaleta(val.MIDIA_COR_ARTISTA, "var(--green)"),
      cabem: Math.max(1, Math.floor(larguraDesenhada / (fonte * 0.52))),
    };
  }

  function desenharMidia(val) {
    const d = lerMidia(val);
    const svg = moldura("a pastilha da música na barra, com capa, nome e a medida da largura");

    svg.appendChild(retangulo(2, 10, 96, 30, 5, {
      fill: "var(--surface0)", "fill-opacity": 0.45, "stroke-width": 1.5,
    }));
    svg.appendChild(texto(95, 27.5, "9:41", { "font-size": 6, "text-anchor": "end" }));

    if (!d.ligada) {
      /* Desligar não é "ficar sem a cor": é a pastilha inteira sair da barra, e
       * o applet do flatpak voltar no próximo login. O vazio pontilhado no
       * lugar dela é a resposta. */
      svg.appendChild(retangulo(6, 17, 56, 16, 3, {
        "stroke-dasharray": "3 3", "stroke-width": 1.4, opacity: 0.45,
      }));
      svg.appendChild(linha(12, 30, 56, 20, { "stroke-width": 1.2, opacity: 0.35 }));
      return svg;
    }

    const yTitulo = 24;
    const yArtista = yTitulo + d.fonte * 0.95 + 1.5;
    /* A pastilha cresce com a letra. Com `MIDIA_FONTE` cravado em 30 ou 48 a
     * banda desce para fora da barra — que é exatamente o defeito que ela
     * reparou primeiro em 24/08/2026, quando o applet passava o tamanho do
     * ÍCONE como tamanho da FONTE. O desenho mostra o transbordo em vez de
     * escondê-lo. */
    const alturaPastilha = Math.max(18, yArtista + d.fonte * 0.35 + 1 - 16);
    if (d.chapado) {
      svg.appendChild(retangulo(4, 16, 56, alturaPastilha, 4, {
        fill: COR_DO_ALBUM, "fill-opacity": 0.45, stroke: "none",
      }));
    } else {
      svg.appendChild(retangulo(4, 16, 56, alturaPastilha, 4, {
        stroke: COR_DO_ALBUM, "stroke-width": 1.4,
      }));
    }

    const corDoTraco = d.chapado ? "currentColor" : COR_DO_ALBUM;
    svg.appendChild(retangulo(6, 19, 12, 12, 2, Object.assign(
      { "stroke-width": 1.5, stroke: corDoTraco },
      d.capa ? {} : { "stroke-dasharray": "2.5 2.5", opacity: 0.6 })));
    if (d.capa) {
      svg.appendChild(circulo(9.6, 27.4, 1.6, { "stroke-width": 1.3, stroke: corDoTraco }));
      svg.appendChild(linha(11.2, 27.4, 11.2, 21.8, { "stroke-width": 1.3, stroke: corDoTraco }));
      svg.appendChild(linha(11.2, 21.8, 14.4, 22.9, { "stroke-width": 1.3, stroke: corDoTraco }));
    } else {
      svg.appendChild(linha(7.5, 29.5, 16.5, 20.5, { "stroke-width": 1.3, opacity: 0.6 }));
    }

    svg.appendChild(texto(TEXTO_X, yTitulo, cortar("A música", d.cabem), {
      "font-size": q(d.fonte), "text-anchor": "start", fill: d.corTitulo,
    }));
    svg.appendChild(texto(TEXTO_X, yArtista, cortar("A banda", d.cabem), {
      "font-size": q(d.fonte * 0.85), "text-anchor": "start", fill: d.corArtista,
    }));

    if (d.controles) {
      const y0 = 21.5;
      const y1 = 28.5;
      svg.appendChild(linha(62, y0, 62, y1, { "stroke-width": 1.4 }));
      svg.appendChild(caminho("M 66.5,21.5 L 66.5,28.5 L 63.5,25 Z", { "stroke-width": 1.4 }));
      svg.appendChild(linha(70, y0, 70, y1, { "stroke-width": 1.4 }));
      svg.appendChild(linha(72.5, y0, 72.5, y1, { "stroke-width": 1.4 }));
      svg.appendChild(caminho("M 76,21.5 L 76,28.5 L 79,25 Z", { "stroke-width": 1.4 }));
      svg.appendChild(linha(80, y0, 80, y1, { "stroke-width": 1.4 }));
    }

    /* A cota. As duas hastes pontilhadas ligam o começo e o fim do espaço do
     * nome à medida embaixo — sem elas o traço solto seria só um traço. */
    const fim = TEXTO_X + d.larguraDesenhada;
    for (const x of [TEXTO_X, fim]) {
      svg.appendChild(linha(x, 40, x, 44, { "stroke-width": 1, "stroke-dasharray": "1.5 1.5", opacity: 0.5 }));
      svg.appendChild(linha(x, 44, x, 48, { "stroke-width": 1.4 }));
    }
    svg.appendChild(linha(TEXTO_X, 46, fim, 46, { "stroke-width": 1.4 }));
    svg.appendChild(texto((TEXTO_X + fim) / 2, 56, d.larguraPx + " px", { "font-size": 5.5 }));
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
      corpo = "a pastilha com " + (d.capa ? "capa" : "o lugar da capa vazio (a capa por link não é baixada)")
        + ", o nome em " + nomeDeCor(val.MIDIA_COR_TITULO, "mauve")
        + " e a banda em " + nomeDeCor(val.MIDIA_COR_ARTISTA, "green")
        + ", " + d.larguraPx + " px de nome antes das reticências, a cor do álbum "
        + (d.chapado ? "chapando o fundo do botão" : "tingindo só o traço")
        + ", letra " + (d.auto ? "na escala do painel" : "cravada em " + d.fontePx + " px")
        + " e " + (d.controles ? "com" : "sem") + " os três botões";
    }
    return montarLegenda(corpo, [
      notaDeErradas(c.erradas),
      d.ligada && !d.chapado ? "a cor do álbum aqui é só um exemplo: a de verdade vem do disco que estiver tocando" : "",
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
      svg.appendChild(linha(74, 32, 90, 32, { "stroke-width": 1.6 }));
      svg.appendChild(seta(90, 32, 0, 3));
      svg.appendChild(texto(70, 34, "A", { "font-size": 5.5 }));
      svg.appendChild(texto(95, 34, "Z", { "font-size": 5.5 }));
    } else {
      svg.appendChild(linha(70, 28, 92, 36, { "stroke-width": 1.5 }));
      svg.appendChild(seta(92, 36, 20, 3));
      svg.appendChild(linha(70, 36, 92, 28, { "stroke-width": 1.5 }));
      svg.appendChild(seta(92, 28, -20, 3));
    }

    /* O prazo da imagem escolhida: o alfinete diz "esta fica", o número diz
     * quanto tempo. */
    svg.appendChild(circulo(9, 47, 2.2, { "stroke-width": 1.5 }));
    svg.appendChild(linha(9, 49.2, 9, 54, { "stroke-width": 1.5 }));
    svg.appendChild(texto(14, 53, d.ttlEterno ? "sempre" : d.ttl.rotulo, {
      "font-size": 5.5, "text-anchor": "start",
    }));

    const bell = sino(38, 50, 4.5, d.avisa ? {} : { opacity: 0.4 });
    svg.appendChild(bell);
    if (!d.avisa) svg.appendChild(linha(34, 54, 42, 46, { "stroke-width": 1.3, opacity: 0.6 }));

    const menuAtrib = d.menu ? { "stroke-width": 1.4 } : { "stroke-width": 1.2, "stroke-dasharray": "2.5 2.5", opacity: 0.45 };
    svg.appendChild(retangulo(52, 44, 20, 13, 1.5, menuAtrib));
    svg.appendChild(linha(55, 48.5, 69, 48.5, Object.assign({}, menuAtrib, { "stroke-width": 1.1 })));
    svg.appendChild(linha(55, 52.5, 65, 52.5, Object.assign({}, menuAtrib, { "stroke-width": 1.1 })));
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
      + ", " + (d.avisa ? "com aviso" : "sem aviso")
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

    /* O acervo: com a separação ligada são duas pastas de horário; desligada,
     * é uma só, com claras e escuras no mesmo sorteio. */
    if (d.separa) {
      svg.appendChild(retangulo(66, 7, 14, 12, 1.5, { "stroke-width": 1.5 }));
      svg.appendChild(sol(73, 13, 3.4, { "stroke-width": 1.3, stroke: "var(--yellow)" }));
      svg.appendChild(retangulo(83, 7, 14, 12, 1.5, { "stroke-width": 1.5 }));
      svg.appendChild(lua(90, 13, 3.4, { "stroke-width": 1.3, stroke: "var(--blue)" }));
    } else {
      svg.appendChild(retangulo(66, 7, 31, 12, 1.5, { "stroke-width": 1.5 }));
      svg.appendChild(sol(76, 13, 3.4, { "stroke-width": 1.3, stroke: "var(--yellow)" }));
      svg.appendChild(lua(88, 13, 3.4, { "stroke-width": 1.3, stroke: "var(--blue)" }));
    }

    /* O corte: uma régua do escuro ao claro com a marca onde a imagem deixa de
     * contar como de noite. */
    svg.appendChild(lua(68, 33, 2.4, { "stroke-width": 1.2, stroke: "var(--blue)" }));
    svg.appendChild(sol(95, 33, 2.6, { "stroke-width": 1.2, stroke: "var(--yellow)" }));
    svg.appendChild(linha(73, 33, 90, 33, { "stroke-width": 1.4, opacity: 0.6 }));
    const marca = 73 + 17 * d.limiar;
    svg.appendChild(linha(marca, 29.5, marca, 36.5, { "stroke-width": 2 }));
    svg.appendChild(texto(Math.max(78, Math.min(88, marca)), 42, String(d.limiar), { "font-size": 5 }));
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

  function desenharLeitura(val) {
    const d = lerLeitura(val);
    const svg = moldura("a mesma página em duas metades: fria à esquerda, na temperatura e na textura escolhidas à direita");

    svg.appendChild(retangulo(3, 3, 94, 34, 3, { "stroke-width": 1.8 }));
    svg.appendChild(linha(4, 10, 96, 10, { "stroke-width": 1, opacity: 0.35 }));
    svg.appendChild(texto(9, 8.2, "9:41", { "font-size": 4.5, "text-anchor": "start", opacity: 0.6 }));

    /* O controle na barra: dois deslizantes minúsculos no canto da topbar. Ele
     * não aparece pontilhado quando está desligado — ele simplesmente não está
     * lá, que é o que "nao" faz com o ícone. */
    if (d.applet) {
      svg.appendChild(linha(83, 6, 92, 6, { "stroke-width": 1.1 }));
      svg.appendChild(circulo(86, 6, 1.2, { "stroke-width": 1.1 }));
      svg.appendChild(linha(83, 8.6, 92, 8.6, { "stroke-width": 1.1 }));
      svg.appendChild(circulo(89.5, 8.6, 1.2, { "stroke-width": 1.1 }));
    }

    /* A textura levanta o preto: o mesmo parágrafo, do lado do papel, perde
     * contraste. É metade do que a chave faz, e a única metade que dá para ver
     * num desenho de traço. */
    const opacidadeDireita = 1 - d.textura * 0.45;
    const linhasEsq = [45, 44, 46, 36];
    const linhasDir = [90, 89, 91, 80];
    for (let i = 0; i < 4; i++) {
      const y = 16 + i * 6;
      svg.appendChild(linha(9, y, linhasEsq[i], y, { "stroke-width": 1.8, opacity: 0.75 }));
      svg.appendChild(linha(54, y, linhasDir[i], y, { "stroke-width": 1.8, opacity: q(0.75 * opacidadeDireita) }));
    }

    const intensidade = Math.max(0, Math.min(1, (6500 - d.temp) / 5500)) * 0.55;
    if (intensidade > 0) {
      /* O véu para 1,5 antes da moldura e tem o mesmo raio dela: um retângulo
       * de canto reto encostado numa moldura arredondada aparece como um erro
       * de desenho, e chama atenção justamente para o canto em vez da cor. */
      svg.appendChild(retangulo(50.5, 4.5, 44.5, 31, 2.5, {
        fill: corDeKelvin(d.temp), "fill-opacity": q(intensidade), stroke: "none",
      }));
    }
    if (d.textura > 0) {
      const fibras = Math.max(1, Math.round(d.textura * 5));
      for (let i = 0; i < fibras; i++) {
        const y = 13 + (i + 0.5) * (23 / fibras);
        svg.appendChild(linha(52, y, 94, y, {
          "stroke-width": 0.6,
          "stroke-dasharray": "5 4",
          stroke: "var(--rosewater)",
          opacity: q(0.2 + 0.35 * d.textura),
        }));
      }
    }
    svg.appendChild(linha(50, 4, 50, 36, { "stroke-width": 1, "stroke-dasharray": "2 3", opacity: 0.5 }));

    svg.appendChild(texto(27, 44, "6500 K", { "font-size": 5.5 }));
    svg.appendChild(texto(73, 44, d.temp + " K", { "font-size": 5.5 }));

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
      + ", " + (d.applet ? "com o controle na barra" : "sem o controle na barra");
    return montarLegenda(corpo, [
      notaDeErradas(c.erradas),
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
   * O desenho mostra o lançador com quatro atalhos ACESOS — os quatro primeiros
   * da lista, escritos como estão nela —, e é aí que a palavra "veste" ganha
   * sentido: são os aplicativos que ganham a cara do tema.
   *
   * O quinto atalho é o do sistema, e ele existe para responder a chave mais
   * perigosa da seção: com "Arrumar o lançador" ligado, ele SOME (fica
   * pontilhado, com o olho cortado). É a única coisa que este projeto faz fora
   * do home dela, e ver o atalho desaparecendo é mais honesto que ler
   * "[essencial]" num rodapé. */
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
    const svg = moldura("o lançador com quatro atalhos vestidos pelo MeowSystem e o atalho do sistema");

    svg.appendChild(retangulo(3, 3, 94, 40, 4, { "stroke-width": 1.8 }));
    svg.appendChild(retangulo(9, 6.5, 82, 7, 3.5, { "stroke-width": 1.2, opacity: 0.6 }));
    svg.appendChild(circulo(13.5, 10, 1.8, { "stroke-width": 1.2, opacity: 0.6 }));
    svg.appendChild(linha(15, 11.4, 16.5, 12.8, { "stroke-width": 1.2, opacity: 0.6 }));

    const xs = [7, 25, 43, 61, 79];
    for (let i = 0; i < 4; i++) {
      const x = xs[i];
      const nome = d.apps[i];
      if (nome) {
        svg.appendChild(retangulo(x, 18, 14, 14, 3, { "stroke-width": 1.8, stroke: "var(--mauve)" }));
        svg.appendChild(circulo(x + 7, 25, 3, { "stroke-width": 1.4, stroke: "var(--mauve)" }));
        svg.appendChild(caminho(
          "M " + q(x + 9.5) + ",17 l 1.6,1.6 l 3.2,-3.6",
          { "stroke-width": 1.5, stroke: "var(--green)" }));
        svg.appendChild(texto(x + 7, 38, cortar(nome, 7), { "font-size": 4.2, opacity: 0.85 }));
      } else {
        svg.appendChild(retangulo(x, 18, 14, 14, 3, {
          "stroke-width": 1.4, "stroke-dasharray": "3 3", opacity: 0.4,
        }));
      }
    }

    /* O atalho do sistema. Ligado, o `.desktop` de /usr/share/applications é
     * marcado e o aplicativo some do lançador — o olho cortado é a única figura
     * que diz "escondido" sem uma palavra. */
    const x5 = xs[4];
    if (d.arruma) {
      svg.appendChild(retangulo(x5, 18, 14, 14, 3, {
        "stroke-width": 1.4, "stroke-dasharray": "3 3", opacity: 0.5,
      }));
      svg.appendChild(caminho(
        "M " + q(x5 + 1.5) + ",25 C " + q(x5 + 4) + ",21 " + q(x5 + 10) + ",21 " + q(x5 + 12.5) + ",25"
        + " C " + q(x5 + 10) + ",29 " + q(x5 + 4) + ",29 " + q(x5 + 1.5) + ",25 Z",
        { "stroke-width": 1.3, opacity: 0.7 }));
      svg.appendChild(circulo(x5 + 7, 25, 1.6, { "stroke-width": 1.2, opacity: 0.7 }));
      svg.appendChild(linha(x5 + 2, 30, x5 + 12, 20, { "stroke-width": 1.4 }));
    } else {
      svg.appendChild(retangulo(x5, 18, 14, 14, 3, { "stroke-width": 1.6, opacity: 0.8 }));
      svg.appendChild(circulo(x5 + 7, 25, 3, { "stroke-width": 1.3, opacity: 0.8 }));
    }
    svg.appendChild(texto(x5 + 7, 38, "sistema", { "font-size": 4.2, opacity: 0.7 }));

    /* Bloqueado no início: o botão de ligar cortado. O número ao lado é quantos
     * programas estão na lista — sem ele o desenho não diria se é um ou dez. */
    const bloqueia = d.bloqueados.length > 0;
    const atrib = bloqueia ? { "stroke-width": 1.6 } : { "stroke-width": 1.3, opacity: 0.4 };
    svg.appendChild(caminho(arco(12, 51, 4.5, 35, 325), atrib));
    svg.appendChild(linha(12, 45, 12, 49.5, atrib));
    if (bloqueia) {
      svg.appendChild(linha(6.5, 56, 17.5, 45.5, { "stroke-width": 1.5 }));
      svg.appendChild(texto(21, 53, String(d.bloqueados.length), {
        "font-size": 6, "text-anchor": "start",
      }));
    }

    /* A loja dentro do Spotify: uma janelinha com um mais. Pontilhada quando a
     * chave está em "nao" — que só deixa de instalar, e não desinstala o que já
     * está lá. */
    const lojaAtrib = d.loja
      ? { "stroke-width": 1.6 }
      : { "stroke-width": 1.3, "stroke-dasharray": "3 3", opacity: 0.45 };
    svg.appendChild(texto(64, 53, "Spotify", { "font-size": 5, "text-anchor": "end", opacity: 0.8 }));
    svg.appendChild(retangulo(68, 45, 24, 13, 2, lojaAtrib));
    svg.appendChild(linha(68, 49, 92, 49, Object.assign({}, lojaAtrib, { "stroke-width": 1.1 })));
    svg.appendChild(linha(80, 51, 80, 56, lojaAtrib));
    svg.appendChild(linha(77.5, 53.5, 82.5, 53.5, lojaAtrib));
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
    const svg = moldura("o conserto diário movendo a esteira dos três vigias, com os sinos de aviso");

    svg.appendChild(linha(20, 20, 93, 20, { "stroke-width": 1.2, opacity: 0.35 }));

    const relogioAtrib = d.reparo
      ? { "stroke-width": 1.8 }
      : { "stroke-width": 1.4, "stroke-dasharray": "3 3", opacity: 0.4 };
    svg.appendChild(circulo(12, 20, 8, relogioAtrib));
    svg.appendChild(linha(12, 20, 12, 14.5, relogioAtrib));
    svg.appendChild(linha(12, 20, 15.5, 22.5, relogioAtrib));
    svg.appendChild(texto(12, 33, "diário", { "font-size": 4.5, opacity: 0.75 }));
    if (d.reparo && d.reparoAvisa) svg.appendChild(sino(12, 7, 4.5));

    const centros = [39, 62, 85];
    for (let i = 0; i < 3; i++) {
      const v = d.vigias[i];
      const cx = centros[i];
      svg.appendChild(engrenagem(cx, 20, 8, v.ligado
        ? { "stroke-width": 1.8, stroke: "var(--mauve)" }
        : { "stroke-width": 1.4, "stroke-dasharray": "2.5 2.5", opacity: 0.4 }));
      svg.appendChild(texto(cx, 33, v.rotulo, { "font-size": 4.5, opacity: 0.75 }));
      if (v.ligado && v.avisa) svg.appendChild(sino(cx, 7, 4.5));
    }

    /* Os backups: uma pilha, e o número. Com "0" a poda está desligada e a
     * pilha não tem topo — daí a folha solta em cima, pontilhada. */
    svg.appendChild(retangulo(8, 43, 14, 9, 1.5, { "stroke-width": 1.4 }));
    svg.appendChild(retangulo(11, 45.5, 14, 9, 1.5, { "stroke-width": 1.4 }));
    svg.appendChild(retangulo(14, 48, 14, 9, 1.5, { "stroke-width": 1.4 }));
    if (d.backups === 0) {
      svg.appendChild(retangulo(5, 40.5, 14, 9, 1.5, {
        "stroke-width": 1.2, "stroke-dasharray": "3 3", opacity: 0.5,
      }));
    }
    svg.appendChild(texto(32, 53, d.backups === 0 ? "todos" : String(d.backups), {
      "font-size": 6.5, "text-anchor": "start",
    }));

    /* Quanto o MeowSystem fala: três degraus, e o escolhido aceso. Um número
     * seria mais preciso e menos claro — verbosidade é quantidade, e quantidade
     * se desenha com altura. */
    const niveis = ["silencioso", "info", "debug"];
    const alturas = [5, 9, 13];
    for (let i = 0; i < 3; i++) {
      const x = 72 + i * 8;
      const h = alturas[i];
      svg.appendChild(retangulo(x, 56 - h, 5, h, 1, d.fala === niveis[i]
        ? { "stroke-width": 1.8, stroke: "var(--mauve)" }
        : { "stroke-width": 1.2, opacity: 0.35 }));
    }
    svg.appendChild(texto(68, 54, d.fala, { "font-size": 5, "text-anchor": "end", opacity: 0.85 }));
    return svg;
  }

  function legendaManutencao(val) {
    const d = lerManutencao(val);
    const c = conferir(val, REGRAS_MANUTENCAO);
    const acesos = d.vigias.filter((v) => v.ligado);
    const sinos = [d.reparo && d.reparoAvisa].concat(d.vigias.map((v) => v.ligado && v.avisa))
      .filter(Boolean).length;
    const corpo = (d.reparo ? "o conserto diário às 5h" : "o conserto diário desligado")
      + " e " + (acesos.length
        ? acesos.length + " dos 3 vigias acesos (" + acesos.map((v) => v.rotulo).join(", ") + ")"
        : "nenhum dos 3 vigias aceso")
      + ", " + (sinos ? sinos + " deles avisando" : "nenhum aviso")
      + ", " + (d.backups === 0 ? "todos os backups guardados" : plural(d.backups, "backup guardado", "backups guardados"))
      + " e o MeowSystem falando em " + d.fala;
    return montarLegenda(corpo, [
      notaDeErradas(c.erradas),
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
  });
})();

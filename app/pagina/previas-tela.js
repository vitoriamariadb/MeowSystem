/* ============================================================================
 * previas-tela.js — um desenho por bloco (metade H1)
 * ============================================================================
 * POR QUE ESTE ARQUIVO EXISTE, e a razão é dura de ouvir: a dona do projeto
 * olhou a tela e disse que não consegue usar o painel sozinha. O único lugar
 * onde isso não acontece é o bloco FORMA de "Barra e dock", e o que ele tem de
 * diferente não é texto melhor — é um desenho que responde ANTES da leitura, e
 * que muda quando o valor muda.
 *
 * Então o critério de qualidade aqui não é "o SVG ficou bonito". É:
 *
 *     alguém que nunca leu o meow.conf olha os dois desenhos e entende
 *     o que a chave faz.
 *
 * Um desenho que não passa nesse teste está errado, por mais correto que seja.
 *
 * O CONTRATO
 *   window.MEOW_PREVIAS["Seção :: BLOCO"](v, escolhido)
 *       -> { antes: SVGElement, depois: SVGElement|null, legenda: string }
 *
 *   `v`         valores COMO ESTÃO no meow.conf (string, podendo ser vazia).
 *   `escolhido` (opcional) o que ela acabou de escolher na tela e ainda não
 *               salvou. Só as chaves que mudaram; o resto vem de `v`.
 *   `antes`     como está agora.
 *   `depois`    como fica com a escolha — `null` quando não há escolha pendente
 *               ou quando a escolha não muda um pixel deste desenho.
 *   `legenda`   UMA linha, começando por "desenho, não captura:".
 *
 *   O SEGUNDO ARGUMENTO NÃO ESTÁ NA FOLHA, E A MEDIÇÃO MOSTROU QUE ELE FALTAVA.
 *   A folha pede `antes` e `depois` no retorno mas descreve a entrada como um
 *   objeto só, com "os valores como estão no meow.conf". Com uma entrada só não
 *   existe caminho por onde `depois` possa ser diferente de `antes` — a função é
 *   pura, e a mesma entrada só pode produzir o mesmo desenho. Daí o segundo
 *   argumento, opcional e retrocompatível: chamar com um argumento continua
 *   valendo e devolve `depois: null`, que é exatamente o que a folha manda
 *   fazer quando não há escolha pendente.
 *
 * AS REGRAS DE DESENHO, todas da folha, e nenhuma é gosto:
 *   - `document.createElementNS`, nó por nó. Nada de marcação crua atribuída a
 *     um elemento, nada de biblioteca — a conferência da folha passa um grep
 *     por isso neste arquivo e ele tem de sair vazio.
 *   - Nenhum literal hexadecimal: as cores são `currentColor` e as variáveis de
 *     `/paleta.css`, que o servidor gera a partir da paleta do FLAVOR salvo.
 *   - Traço, não chapado: `fill="none"`, traço por volta de 2 num viewBox de
 *     48, pontas e cantos arredondados. Onde há preenchimento, ele é tom de
 *     superfície — e as poucas exceções (a barra de título no acento, a tira
 *     ANSI do terminal) estão comentadas onde acontecem, porque ali a cor É o
 *     assunto do cartão.
 *   - Mesmo viewBox e mesmo enquadramento no `antes` e no `depois`, senão não
 *     há o que comparar.
 *   - Função pura: sem rede, sem relógio, sem `Math.random`.
 *   - NUNCA lançar. Um desenho que quebra apaga a página inteira, então todo
 *     valor vazio ou inválido cai no padrão e a legenda diz isso em voz alta.
 * ========================================================================= */

(function () {
  "use strict";

  var NS = "http://www.w3.org/2000/svg";

  /* --- o quadro ----------------------------------------------------------
   * 96 por 48: a tela, a dock, o terminal e a fileira de ícones são todos
   * DEITADOS, e um quadro quadrado sobraria em cima e embaixo em todos eles. O
   * "viewBox de 48" da folha vale como referência do traço: é a altura, e é
   * contra ela que a espessura 2 foi calibrada. */
  var LARG = 96;
  var ALT = 48;
  var TRACO = 2;
  var FINO = 1.2;

  /* --- as cores ----------------------------------------------------------
   * DUAS ÂNCORAS ABSOLUTAS, e elas resolvem um problema que parecia sem saída.
   * O `/paleta.css` é gerado no FLAVOR salvo: `var(--base)` já é o base do
   * sabor em vigor, então usá-lo para desenhar "como fica no mocha" seria
   * desenhar o sabor de agora com outro nome. Mas o mesmo arquivo publica
   * `--fundo-mocha` e `--fundo-latte`, que são fixos — o escuro mais escuro e o
   * claro mais claro da paleta, independentes do que está salvo.
   * Com esses dois eu construo qualquer degrau de claridade por `color-mix`, e
   * nenhum hexadecimal precisa aparecer aqui. */
  var ESCURO = "var(--fundo-mocha, var(--crust))";
  var CLARO = "var(--fundo-latte, var(--surface2))";

  /* Os catorze nomes que a paleta publica como variável. Servem para dois usos
   * diferentes e é por isso que a lista é uma só: um ACCENT válido é um nome
   * daqui, e o sufixo de um tema de ponteiro (`catppuccin-mocha-mauve`) também. */
  var CORES = [
    "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
    "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender",
  ];

  var FLAVORS = ["mocha", "macchiato", "frappe", "latte"];

  /* Quanto cada sabor caminha do escuro para o claro. Não são medidas de
   * luminância: são a ORDEM, que é o que a pergunta "qual escuro?" quer saber.
   * Mocha é o mais escuro, latte é o claro, e macchiato e frappe são os dois
   * degraus no meio — desenhar os três iguais faria a escolha parecer inócua. */
  var CLAREZA = { mocha: 0, macchiato: 9, frappe: 19, latte: 100 };

  function mistura(a, b, pct) {
    return "color-mix(in srgb, " + a + " " + n2(pct) + "%, " + b + ")";
  }

  function tomDoFlavor(flavor) {
    var p = CLAREZA[flavor];
    if (p === undefined || p === 0) return ESCURO;
    if (p >= 100) return CLARO;
    return mistura(CLARO, ESCURO, p);
  }

  function corDaPaleta(nome, alternativa) {
    var t = String(nome == null ? "" : nome).trim().toLowerCase();
    if (CORES.indexOf(t) >= 0) return "var(--" + t + ")";
    return alternativa || "currentColor";
  }

  /* --- as ferramentas de montagem ---------------------------------------- */

  function n2(x) {
    var v = Math.round(Number(x) * 100) / 100;
    if (!isFinite(v)) return 0;
    return v === 0 ? 0 : v;
  }

  function el(tag, atributos, filhos, dentro) {
    var no = document.createElementNS(NS, tag);
    if (atributos) {
      for (var k in atributos) {
        if (!Object.prototype.hasOwnProperty.call(atributos, k)) continue;
        var val = atributos[k];
        if (val === null || val === undefined || val === false) continue;
        no.setAttribute(k, String(val));
      }
    }
    if (dentro !== undefined && dentro !== null) no.textContent = String(dentro);
    if (filhos) {
      for (var i = 0; i < filhos.length; i++) if (filhos[i]) no.appendChild(filhos[i]);
    }
    return no;
  }

  /* O `<title>` não é enfeite de acessibilidade: quem usa leitor de tela recebe
   * por ele a MESMA informação que o desenho dá, em meia linha. Sem ele o
   * cartão fica mudo justamente para quem mais depende de texto. */
  function quadro(titulo) {
    var s = el("svg", {
      xmlns: NS,
      viewBox: "0 0 " + LARG + " " + ALT,
      width: "100%",
      height: "120",
      preserveAspectRatio: "xMidYMid meet",
      role: "img",
      class: "previa-svg",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": TRACO,
      "stroke-linecap": "round",
      "stroke-linejoin": "round",
    });
    s.appendChild(el("title", null, null, titulo));
    return s;
  }

  function grupo(filhos, atributos) {
    return el("g", atributos || null, filhos || null);
  }

  function ret(x, y, w, h, rx, atributos) {
    var a = { x: n2(x), y: n2(y), width: n2(Math.max(0, w)), height: n2(Math.max(0, h)) };
    if (rx) a.rx = n2(rx);
    return el("rect", juntar(a, atributos));
  }

  function lin(x1, y1, x2, y2, atributos) {
    return el("line", juntar({ x1: n2(x1), y1: n2(y1), x2: n2(x2), y2: n2(y2) }, atributos));
  }

  function circ(cx, cy, r, atributos) {
    return el("circle", juntar({ cx: n2(cx), cy: n2(cy), r: n2(r) }, atributos));
  }

  function cam(d, atributos) {
    return el("path", juntar({ d: d }, atributos));
  }

  function juntar(base, extra) {
    if (extra) {
      for (var k in extra) {
        if (Object.prototype.hasOwnProperty.call(extra, k)) base[k] = extra[k];
      }
    }
    return base;
  }

  function faixa(n, min, max) {
    return Math.max(min, Math.min(max, n));
  }

  /* --- a leitura dos valores ---------------------------------------------
   * Todo `ler*` recebe um DIÁRIO e anota nele o que veio vazio e o que veio
   * inválido. É o diário que escreve o fim da legenda, e é por isso que ele
   * existe em vez de um `try/catch` mudo: a folha manda dizer na legenda quando
   * o desenho caiu no padrão, e a única forma de dizer é ter registrado.
   *
   * O diário é OPCIONAL de propósito. Há chaves cujo vazio é documentado e não
   * significa "o COSMIC decide" — `FASTFETCH_LOGO_LINHAS` vazio quer dizer
   * "calculada", `FASTFETCH_LOGO_DIA` vazio quer dizer "herda a do dock". Anotar
   * essas como falta encheria a legenda de um aviso falso. */

  function diario() {
    return { vazias: [], invalidas: [] };
  }

  function texto(bruto) {
    return String(bruto == null ? "" : bruto).trim();
  }

  function lerTexto(v, d, chave, padrao) {
    var t = texto(v[chave]);
    if (t === "") {
      if (d) d.vazias.push(chave);
      return padrao;
    }
    return t;
  }

  function lerOpcao(v, d, chave, lista, padrao) {
    var t = texto(v[chave]).toLowerCase();
    if (t === "") {
      if (d) d.vazias.push(chave);
      return padrao;
    }
    if (lista.indexOf(t) < 0) {
      if (d) d.invalidas.push(chave);
      return padrao;
    }
    return t;
  }

  function lerNumero(v, d, chave, padrao, min, max) {
    var t = texto(v[chave]).replace(",", ".");
    if (t === "") {
      if (d) d.vazias.push(chave);
      return padrao;
    }
    var n = Number(t);
    if (!isFinite(n)) {
      if (d) d.invalidas.push(chave);
      return padrao;
    }
    return faixa(n, min, max);
  }

  /* Três estados, e o terceiro não é detalhe: "sim", "nao" e VAZIO, que em
   * várias chaves deste projeto quer dizer "não toca" — o COSMIC fica com o que
   * já estava. Devolver `null` obriga quem desenha a decidir o que fazer com o
   * desconhecido, em vez de fingir que vazio é "nao". */
  function lerTriEstado(v, d, chave) {
    var t = texto(v[chave]).toLowerCase();
    if (t === "") {
      if (d) d.vazias.push(chave);
      return null;
    }
    if (t === "sim" || t === "s" || t === "true" || t === "1") return true;
    if (t === "nao" || t === "não" || t === "n" || t === "false" || t === "0") return false;
    if (d) d.invalidas.push(chave);
    return null;
  }

  function lerSimNao(v, d, chave, padrao) {
    var r = lerTriEstado(v, d, chave);
    return r === null ? padrao : r;
  }

  function fechoDaLegenda(d) {
    var partes = [];
    if (d.vazias.length) {
      partes.push("vazio no meow.conf significa que o COSMIC decide, e aqui aparece o padrão dele ("
        + d.vazias.join(", ") + ")");
    }
    if (d.invalidas.length) {
      partes.push("o valor de " + d.invalidas.join(", ")
        + " não é um dos aceitos, então o desenho mostra o padrão");
    }
    return partes.length ? " — " + partes.join("; ") + "." : "";
  }

  function umaLinha(s) {
    return String(s).replace(/\s+/g, " ").trim();
  }

  /* NOME LIVRE NÃO É NOME CURTO, e a legenda paga a conta. Chaves como LOGO,
   * CURSOR e NOME_TEMA_ICONES aceitam qualquer texto — é o desenho delas: solte
   * um SVG na pasta e o nome do arquivo vira o valor. Um valor comprido (ou
   * colado torto) empurraria a legenda de uma linha para três, e a medição do
   * roteiro mostrou isso acontecendo com um valor de quarenta caracteres. */
  function curto(s, limite) {
    var t = umaLinha(s);
    var max = limite || 28;
    return t.length > max ? t.slice(0, max - 1) + "…" : t;
  }

  /* ==========================================================================
   * O GATO DE TRAÇO
   * ==========================================================================
   * O acervo de logos é um punhado de SVGs em `assets/gatos/`, e uma função pura
   * não pode buscá-los. Desenhar o gato aqui não é reproduzir a Coquinha — é
   * mostrar O LUGAR dela e QUANDO ela troca, que é a pergunta do cartão. A
   * legenda diz "desenho, não captura" exatamente por isto.
   *
   * O que precisa ser verdade é a DIFERENÇA: se o de dia e o de noite forem
   * iguais na tela, a chave que decide os dois vira invisível. Por isso cada
   * nome recebe um rosto, e os dois gatos de fábrica têm rosto fixo — a Mimir
   * dormindo, porque "mimir" é dormir, e a Coquinha de olhos alegres. Qualquer
   * outro nome cai num dos quatro rostos por uma conta sobre as letras: mesma
   * palavra, mesmo rosto, sempre. */
  var ROSTOS_FIXOS = { coquinha: 2, mimir: 1 };

  function rostoDoGato(nome) {
    var t = String(nome == null ? "" : nome).trim().toLowerCase();
    if (Object.prototype.hasOwnProperty.call(ROSTOS_FIXOS, t)) return ROSTOS_FIXOS[t];
    var soma = 7;
    for (var i = 0; i < t.length; i++) soma = (soma * 31 + t.charCodeAt(i)) % 9973;
    return soma % 4;
  }

  function gatoDeTraco(cx, cy, r, cor, nome) {
    var rosto = rostoDoGato(nome);
    var g = grupo([], { stroke: cor, "stroke-width": n2(faixa(r * 0.26, 0.7, 1.8)) });

    g.appendChild(circ(cx, cy, r));
    /* As orelhas, dois triângulos apoiados no alto da cabeça. Sem elas o
     * desenho é uma bola, e uma bola não diz "logo". */
    g.appendChild(cam("M" + n2(cx - r * 0.72) + "," + n2(cy - r * 0.68)
      + " L" + n2(cx - r * 0.98) + "," + n2(cy - r * 1.52)
      + " L" + n2(cx - r * 0.16) + "," + n2(cy - r * 0.98) + " Z"));
    g.appendChild(cam("M" + n2(cx + r * 0.72) + "," + n2(cy - r * 0.68)
      + " L" + n2(cx + r * 0.98) + "," + n2(cy - r * 1.52)
      + " L" + n2(cx + r * 0.16) + "," + n2(cy - r * 0.98) + " Z"));

    var ex = r * 0.38;
    var ey = cy - r * 0.06;
    /* A DIFERENÇA ENTRE DOIS ROSTOS TEM DE SOBREVIVER AO TAMANHO DA DOCK, que
     * é onde eles aparecem menores. Na conferência visual, com arcos rasos, o
     * gato de dia e o de noite ficaram parecidos demais — e o cartão inteiro
     * existe para mostrar que eles TROCAM. Arcos fundos e olhos mais afastados
     * é o que devolve a diferença sem inventar detalhe novo. */
    if (rosto === 1) {
      /* dormindo: as pálpebras caídas */
      g.appendChild(cam("M" + n2(cx - ex - r * 0.26) + "," + n2(ey - r * 0.08)
        + " q" + n2(r * 0.26) + "," + n2(r * 0.42) + " " + n2(r * 0.52) + ",0"));
      g.appendChild(cam("M" + n2(cx + ex - r * 0.26) + "," + n2(ey - r * 0.08)
        + " q" + n2(r * 0.26) + "," + n2(r * 0.42) + " " + n2(r * 0.52) + ",0"));
    } else if (rosto === 2) {
      /* alegre: os olhos em arco para cima */
      g.appendChild(cam("M" + n2(cx - ex - r * 0.26) + "," + n2(ey + r * 0.24)
        + " q" + n2(r * 0.26) + "," + n2(-r * 0.46) + " " + n2(r * 0.52) + ",0"));
      g.appendChild(cam("M" + n2(cx + ex - r * 0.26) + "," + n2(ey + r * 0.24)
        + " q" + n2(r * 0.26) + "," + n2(-r * 0.46) + " " + n2(r * 0.52) + ",0"));
    } else if (rosto === 3) {
      /* piscando: um aberto, um fechado */
      g.appendChild(circ(cx - ex, ey, r * 0.13, { fill: cor, stroke: "none" }));
      g.appendChild(cam("M" + n2(cx + ex - r * 0.2) + "," + n2(ey)
        + " q" + n2(r * 0.2) + "," + n2(r * 0.26) + " " + n2(r * 0.4) + ",0"));
    } else {
      g.appendChild(circ(cx - ex, ey, r * 0.13, { fill: cor, stroke: "none" }));
      g.appendChild(circ(cx + ex, ey, r * 0.13, { fill: cor, stroke: "none" }));
    }

    /* Focinho e bigodes: é o que faz um círculo com duas orelhas virar gato. */
    g.appendChild(cam("M" + n2(cx - r * 0.14) + "," + n2(cy + r * 0.3)
      + " L" + n2(cx) + "," + n2(cy + r * 0.44)
      + " L" + n2(cx + r * 0.14) + "," + n2(cy + r * 0.3)));
    g.appendChild(lin(cx - r * 0.34, cy + r * 0.36, cx - r * 0.82, cy + r * 0.26));
    g.appendChild(lin(cx + r * 0.34, cy + r * 0.36, cx + r * 0.82, cy + r * 0.26));
    return g;
  }

  /* O lugar da logo quando ela é DESCONHECIDA: em rotação, o próximo do acervo
   * depende do que estiver na pasta, e uma função pura não tem como saber. Um
   * gato inventado ali seria mentira; o quadrado tracejado com a seta circular
   * diz a verdade — "o próximo, seja qual for". */
  function logoIndefinida(cx, cy, r, cor) {
    var g = grupo([], { stroke: cor, "stroke-width": n2(faixa(r * 0.26, 0.7, 1.6)) });
    g.appendChild(circ(cx, cy, r, { "stroke-dasharray": n2(r * 0.5) + " " + n2(r * 0.42) }));
    g.appendChild(setaCircular(cx, cy, r * 0.55, cor, n2(faixa(r * 0.26, 0.7, 1.6))));
    return g;
  }

  function setaCircular(cx, cy, r, cor, largura) {
    var g = grupo([], { stroke: cor, "stroke-width": largura });
    g.appendChild(cam("M" + n2(cx + r) + "," + n2(cy)
      + " A" + n2(r) + "," + n2(r) + " 0 1 1 " + n2(cx) + "," + n2(cy - r)));
    g.appendChild(cam("M" + n2(cx - r * 0.42) + "," + n2(cy - r * 1.0)
      + " L" + n2(cx) + "," + n2(cy - r)
      + " L" + n2(cx - r * 0.18) + "," + n2(cy - r * 1.48)));
    return g;
  }

  /* --- sol, lua e o "automático" -----------------------------------------
   * Três glifos que aparecem em dois cartões e significam a mesma coisa nos
   * dois: o mundo de dia, o mundo de noite, e "o relógio decide".
   * A lua é feita por OCLUSÃO — um círculo cheio da cor do fundo comendo parte
   * do outro — em vez de um arco duplo. O arco duplo depende de acertar dois
   * `sweep-flag` e quebra em silêncio quando a corda passa do diâmetro; a
   * oclusão não tem como dar errado. */
  /* OITO RAIOS, E NÃO QUATRO. Com quatro, a conferência visual mostrou uma
   * MIRA, não um sol: uma cruz em volta de um círculo é o desenho de mira mais
   * comum que existe. O oitavo raio é o que resolve, e custa quatro linhas. */
  function glifoSol(cx, cy, r, cor) {
    var g = grupo([], { stroke: cor, "stroke-width": n2(faixa(r * 0.32, 0.8, 1.5)) });
    g.appendChild(circ(cx, cy, r * 0.52));
    for (var i = 0; i < 8; i++) {
      var a = (Math.PI / 4) * i;
      g.appendChild(lin(
        cx + Math.cos(a) * r * 0.8, cy + Math.sin(a) * r * 0.8,
        cx + Math.cos(a) * r * 1.24, cy + Math.sin(a) * r * 1.24));
    }
    return g;
  }

  function glifoLua(cx, cy, r, cor, fundo) {
    var lw = n2(faixa(r * 0.34, 0.8, 1.6));
    var g = grupo();
    g.appendChild(circ(cx, cy, r, { stroke: cor, "stroke-width": lw }));
    g.appendChild(circ(cx - r * 0.62, cy - r * 0.42, r * 0.92, { fill: fundo, stroke: fundo, "stroke-width": lw }));
    return g;
  }

  function glifoAuto(cx, cy, r, cor) {
    var lw = n2(faixa(r * 0.34, 0.8, 1.6));
    var g = grupo();
    g.appendChild(circ(cx, cy, r, { stroke: cor, "stroke-width": lw }));
    g.appendChild(cam("M" + n2(cx) + "," + n2(cy - r)
      + " A" + n2(r) + "," + n2(r) + " 0 0 1 " + n2(cx) + "," + n2(cy + r) + " Z",
      { fill: cor, stroke: "none" }));
    return g;
  }

  /* ==========================================================================
   * O EMBRULHO QUE NÃO DEIXA LANÇAR
   * ==========================================================================
   * Um desenho que estoura não estraga o cartão dele: estraga a PÁGINA, porque
   * quem chama monta os cartões num laço só. Então a fronteira é aqui, e ela é
   * dupla — o desenho por dentro e o desenho de falha por fora, cada um no seu
   * `try`. No pior caso devolvemos `antes: null` e uma legenda que diz o que
   * houve, e a página continua de pé. */
  function bloco(cfg) {
    return function (v, escolhido) {
      try {
        var va = normalizar(v);
        var vb = escolhido ? juntar(normalizar(v), normalizar(escolhido)) : null;
        var ma = cfg.modelo(va);
        var mb = vb ? cfg.modelo(vb) : null;
        var mudou = !!(mb && JSON.stringify(ma) !== JSON.stringify(mb));
        /* O contexto existe por um motivo só, e ele está na folha: "desenho que
         * muda de escala entre um e outro não deixa comparar nada". No terminal
         * a altura da linha depende do tamanho do gato, então ela é calculada
         * UMA vez, olhando os dois modelos, e vale para os dois desenhos. */
        var ctx = cfg.contexto ? cfg.contexto(ma, mudou ? mb : ma) : null;
        return {
          antes: cfg.desenho(ma, ctx),
          depois: mudou ? cfg.desenho(mb, ctx) : null,
          legenda: umaLinha("desenho, não captura: " + cfg.legenda(ma, mudou ? mb : null)),
        };
      } catch (e) {
        return quadroDeFalha(cfg.rotulo);
      }
    };
  }

  function normalizar(v) {
    var saida = {};
    if (v && typeof v === "object") {
      for (var k in v) {
        if (!Object.prototype.hasOwnProperty.call(v, k)) continue;
        var val = v[k];
        if (val === null || val === undefined) continue;
        if (typeof val === "object") continue;
        saida[k] = String(val);
      }
    }
    return saida;
  }

  function quadroDeFalha(rotulo) {
    var legenda = "desenho, não captura: não foi possível desenhar " + rotulo
      + " com os valores atuais — nada na sua máquina mudou por causa disto.";
    try {
      var s = quadro("Não foi possível desenhar " + rotulo);
      s.appendChild(ret(3, 3, 90, 42, 4, { "stroke-dasharray": "4 3", opacity: "0.6" }));
      s.appendChild(lin(38, 24, 58, 24, { opacity: "0.6" }));
      return { antes: s, depois: null, legenda: legenda };
    } catch (e) {
      return { antes: null, depois: null, legenda: legenda };
    }
  }

  /* ==========================================================================
   * 1. "Cor e tela"
   * ==========================================================================
   * FLAVOR · ACCENT · MODO · JANELAS_TILING · JANELAS_TILING_ESCOPO ·
   * ESCALA_TELA · CURSOR · CURSOR_VERSAO
   *
   * A pergunta que este desenho responde é "o que isto faz com a minha tela?",
   * e ela tem quatro respostas ao mesmo tempo. O desenho as separa em quatro
   * lugares que não competem:
   *
   *   o FUNDO da tela   diz claro ou escuro, e qual escuro (o sabor).
   *   a BARRA de título diz onde a cor de destaque aparece.
   *   a ARRUMAÇÃO       diz encaixado (lado a lado) ou solto (uma sobre a outra).
   *   o TAMANHO do que  diz a escala: no mesmo monitor, com escala maior, cabe
   *   está dentro         MENOS linha de texto e o ponteiro fica maior. Foi a
   *                       forma que sobrou de mostrar escala sem mudar o
   *                       enquadramento — aumentar o desenho inteiro faria os
   *                       dois quadros ficarem incomparáveis.
   *
   * As três pastilhas de área de trabalho embaixo existem por causa do ESCOPO,
   * que é a armadilha documentada da chave: com `workspace`, ligar o lado a
   * lado muda ZERO pixel nas áreas que já existem. Desenhar a divisão só na
   * pastilha atual é dizer isso sem uma palavra.
   *
   * CURSOR_VERSAO não aparece no desenho e é de propósito: ela fixa o release
   * do acervo para o tema não mudar sozinho, e não muda um pixel da tela. */

  var ESCALAS_NOMEADAS = { nitida: 1, auto: 1 };

  function lerEscala(v, d) {
    var t = texto(v.ESCALA_TELA).toLowerCase().replace(",", ".");
    if (t === "") {
      d.vazias.push("ESCALA_TELA");
      return { fator: 1, rotulo: "tudo em 100%", nitida: false };
    }
    if (Object.prototype.hasOwnProperty.call(ESCALAS_NOMEADAS, t)) {
      return { fator: 1, rotulo: "escala arredondada para o inteiro mais próximo", nitida: true };
    }
    var n = Number(t);
    if (!isFinite(n) || n < 0.5 || n > 3) {
      d.invalidas.push("ESCALA_TELA");
      return { fator: 1, rotulo: "tudo em 100%", nitida: false };
    }
    return { fator: faixa(n, 0.75, 2), rotulo: "tudo em " + Math.round(n * 100) + "%", nitida: false };
  }

  /* O NOME DO TEMA DE PONTEIRO MENTE SOBRE A COR, e isso está medido no
   * meow.conf: nos temas `-mauve`, `-blue` e afins o CORPO recebe o accent e o
   * contorno recebe a base — o oposto do que o nome sugere. O `-light` é o
   * único claro e neutro. Desenhar o ponteiro na cor que ele realmente tem é o
   * que faz o cartão responder "esse aqui some no meu papel de parede?". */
  function corDoPonteiro(nome) {
    var t = texto(nome).toLowerCase();
    if (t === "") return { corpo: CLARO, rotulo: "" };
    var ultimo = t.split("-").pop();
    if (CORES.indexOf(ultimo) >= 0) return { corpo: "var(--" + ultimo + ")", rotulo: t };
    if (ultimo === "dark") return { corpo: ESCURO, rotulo: t };
    return { corpo: CLARO, rotulo: t };
  }

  var COR_E_TELA = bloco({
    rotulo: "a cor e a tela",

    modelo: function (v) {
      var d = diario();
      var flavor = lerOpcao(v, d, "FLAVOR", FLAVORS, "mocha");
      var accent = lerOpcao(v, d, "ACCENT", CORES, "mauve");
      var modo = lerOpcao(v, d, "MODO", ["escuro", "claro", "auto"], "escuro");
      var encaixe = lerTriEstado(v, d, "JANELAS_TILING");
      var escopo = lerOpcao(v, d, "JANELAS_TILING_ESCOPO", ["global", "workspace"], "global");
      var escala = lerEscala(v, d);
      var cursor = texto(v.CURSOR);
      var ponteiro = corDoPonteiro(cursor);
      /* O sabor diz QUAL escuro; o modo diz SE a máquina veste claro. Quando os
       * dois se contradizem (latte com modo escuro) quem vence é o par que a
       * máquina de fato usa: latte é claro, e o modo claro é claro. */
      var claro = modo === "claro" || flavor === "latte";
      return {
        flavor: flavor,
        accent: accent,
        modo: modo,
        claro: claro,
        encaixe: encaixe,
        escopo: escopo,
        escala: escala.fator,
        escalaRotulo: escala.rotulo,
        cursor: cursor,
        cursorCor: ponteiro.corpo,
        fecho: fechoDaLegenda(d),
      };
    },

    desenho: function (m) {
      var tom = m.claro ? CLARO : tomDoFlavor(m.flavor);
      var tinta = m.claro ? ESCURO : CLARO;
      var corpo = mistura(tinta, tom, m.claro ? 7 : 11);
      var contorno = mistura(tinta, tom, 45);
      var fraco = mistura(tinta, tom, 62);
      var acento = corDaPaleta(m.accent, "var(--accent)");
      var esc = m.escala;

      var s = quadro("Uma tela em " + m.flavor + " " + (m.claro ? "claro" : "escuro")
        + ", com destaque " + m.accent + ", "
        + (m.encaixe ? "janelas lado a lado" : "janelas soltas")
        + " e o ponteiro em " + Math.round(esc * 100) + "%.");

      s.appendChild(ret(2, 2, 92, 44, 4, { fill: tom }));

      /* A barra de baixo é o painel do COSMIC, e é onde moram as pastilhas de
       * área de trabalho e o indicador de claro/escuro. Pôr as duas coisas ali
       * não é licença: é onde elas ficam na tela dela. */
      s.appendChild(lin(4, 36.4, 92, 36.4, { stroke: fraco, "stroke-width": 1 }));

      var pips = grupo();
      for (var i = 0; i < 3; i++) {
        var px = 7 + i * 9.4;
        var atual = i === 0;
        pips.appendChild(ret(px, 38.6, 7, 5.4, 1.6, {
          stroke: atual ? tinta : contorno,
          "stroke-width": atual ? 1.5 : 1,
        }));
        var vale = m.encaixe === true && (m.escopo === "global" || atual);
        if (vale) {
          pips.appendChild(lin(px + 3.5, 39.8, px + 3.5, 42.9, {
            stroke: acento, "stroke-width": 1.2,
          }));
        }
      }
      s.appendChild(pips);

      if (m.modo === "claro") s.appendChild(glifoSol(85.8, 41.3, 3.1, tinta));
      else if (m.modo === "auto") s.appendChild(glifoAuto(85.8, 41.3, 3, tinta));
      else s.appendChild(glifoLua(85.8, 41.3, 3, tinta, tom));

      /* A janela: barra de título no acento, corpo um degrau acima do fundo, e
       * as linhas de conteúdo no tamanho da escala. O preenchimento da barra é
       * a única cor chapada deste desenho, e ela é o ASSUNTO do cartão — "onde
       * a cor de destaque aparece" não se responde com contorno. */
      function janela(x, y, w, h, foco) {
        var g = grupo();
        var tb = faixa(3.1 * esc, 2.4, 7);
        g.appendChild(ret(x, y, w, h, 2.2, {
          fill: corpo,
          stroke: foco ? acento : contorno,
          "stroke-width": foco ? 1.7 : 1.1,
        }));
        g.appendChild(ret(x + 0.9, y + 0.9, w - 1.8, tb, 1.5, {
          fill: foco ? acento : contorno, stroke: "none",
        }));
        var espessura = faixa(1 * esc, 0.8, 2.6);
        var passo = faixa(2.9 * esc, 2.2, 6.4);
        var comprimentos = [0.86, 0.6, 0.74, 0.48, 0.8, 0.56, 0.7];
        var yy = y + tb + passo;
        var k = 0;
        while (yy < y + h - 1.6 && k < 12) {
          g.appendChild(lin(x + 3, yy, x + 3 + (w - 6) * comprimentos[k % comprimentos.length], yy, {
            stroke: fraco, "stroke-width": espessura,
          }));
          yy += passo;
          k++;
        }
        return g;
      }

      if (m.encaixe === true) {
        /* Encaixado: as duas dividem o espaço, nenhuma cobre a outra. */
        s.appendChild(janela(6, 5.6, 40.5, 28, true));
        s.appendChild(janela(49.5, 5.6, 40.5, 28, false));
      } else {
        /* Solto: as mesmas DUAS janelas, uma sobre a outra. O número de janelas
         * é igual nos dois casos de propósito — assim a única diferença que
         * salta é a arrumação, e não "sumiu uma janela". */
        s.appendChild(janela(30, 9.5, 44, 24, false));
        s.appendChild(janela(16, 5.6, 44, 24, true));
      }

      var pc = m.cursorCor;
      s.appendChild(cam("M0,0 L0,9.4 L2.5,7.2 L4.1,10.8 L5.8,10 L4.2,6.5 L7.2,6.3 Z", {
        transform: "translate(52,14) scale(" + n2(esc * 0.82) + ")",
        fill: pc,
        stroke: m.claro ? ESCURO : CLARO,
        "stroke-width": 1.4,
      }));

      return s;
    },

    legenda: function (m) {
      var arrumacao;
      if (m.encaixe === true) {
        arrumacao = "janelas lado a lado "
          + (m.escopo === "global"
            ? "em todas as áreas de trabalho"
            : "só na área de trabalho atual (as que já existem não mudam)");
      } else if (m.encaixe === false) {
        arrumacao = "janelas soltas, uma sobre a outra";
      } else {
        arrumacao = "o lado a lado fica como você deixou pelo Super+Y";
      }
      var luz = m.modo === "auto"
        ? "alternando claro e escuro pelo relógio"
        : (m.claro ? "claro" : "escuro");
      var ponteiro = m.cursor ? ", ponteiro " + curto(m.cursor, 30) : ", ponteiro do sistema";
      return m.flavor + " " + luz + " com destaque " + m.accent + ", "
        + arrumacao + ", " + m.escalaRotulo + ponteiro + "." + m.fecho;
    },
  });

  /* ==========================================================================
   * 2. "Logo do sistema :: NO DOCK"
   * ==========================================================================
   * LOGO · LOGO_ROTACAO · LOGO_MODO · LOGO_DIA · LOGO_NOITE · LOGO_RECICLAR ·
   * LOGO_INTERVALO
   *
   * Sete chaves para uma pergunta só: QUAL logo fica na ponta da dock, e quando
   * ela troca. Então o desenho é a dock DUAS vezes, empilhada — a de cima é o
   * mundo de dia, a de baixo o de noite, e a seta que liga as duas é a troca.
   *
   * Duas decisões que valem explicação:
   *
   *   A dock aparece de perto, e não dentro de um monitor inteiro. Num monitor
   *   a logo teria uns quatro pixels na tela dela e a comparação — que é o
   *   ponto do cartão — não existiria.
   *
   *   A seta é TRACEJADA quando LOGO_RECICLAR="nao". Está medido no meow.conf:
   *   sem reciclar o painel, reescrever o SVG não muda um pixel, e o gato novo
   *   só aparece no próximo login. Uma seta cheia promete "agora"; a tracejada
   *   promete "depois", que é a verdade. */

  var LOGO_NO_DOCK = bloco({
    rotulo: "a logo no dock",

    modelo: function (v) {
      var d = diario();
      var logo = lerTexto(v, null, "LOGO", "coquinha");
      var rotacaoLigada = lerSimNao(v, null, "LOGO_ROTACAO", false);
      var modo = lerOpcao(v, d, "LOGO_MODO", ["hora", "rotacao", "fixo"], "hora");
      /* A chave antiga continua ligando o modo novo, e é o que o meow.conf
       * promete: LOGO_ROTACAO="sim" liga a rotação sozinha. */
      if (rotacaoLigada) modo = "rotacao";
      var dia = lerTexto(v, null, "LOGO_DIA", logo);
      var noite = lerTexto(v, null, "LOGO_NOITE", logo);
      var reciclar = lerSimNao(v, null, "LOGO_RECICLAR", true);
      var intervalo = lerTexto(v, null, "LOGO_INTERVALO", "1d");
      return {
        modo: modo,
        logo: logo,
        dia: modo === "hora" ? dia : logo,
        noite: modo === "hora" ? noite : logo,
        reciclar: reciclar,
        intervalo: intervalo,
        fecho: fechoDaLegenda(d),
      };
    },

    desenho: function (m) {
      var rotativo = m.modo === "rotacao";
      /* Em rotação as duas faixas não são dia e noite — são "agora" e "depois
       * de um intervalo". Pintá-las de claro e escuro ali seria dizer que a
       * troca segue o sol, e ela não segue. */
      /* CLARO, NÃO BRANCO — 07/09/2026
       *   `CLARO` é o base do Latte, que é quase branco: correto como ideia
       *   ("de dia a tela é clara") e violento como desenho. Medido na tela
       *   dela: um retângulo de 94×22 em branco chapado no meio de uma página
       *   escura puxa o olho antes de qualquer traço, e a folha dela diz que o
       *   tema deste projeto é o TRAÇO, não o chapado.
       *
       *   62% de claro sobre o escuro mantém a distância entre a faixa de dia e
       *   a de noite — que é a única coisa que este desenho precisa provar — sem
       *   abrir um buraco branco na página. A tinta continua sendo escolhida
       *   pelo mesmo teste, agora contra a constante certa. */
      var DIA = mistura(CLARO, ESCURO, 62);
      var tomCima = rotativo ? tomDoFlavor("mocha") : DIA;
      var tomBaixo = ESCURO;
      var s = quadro("A dock com a logo na ponta, de dia e de noite.");

      function faixaDock(y, tom, nomeLogo, indefinida) {
        var tinta = tom === DIA ? ESCURO : CLARO;
        var vidro = mistura(tinta, tom, 13);
        var borda = mistura(tinta, tom, 38);
        var g = grupo();
        g.appendChild(ret(1, y, 94, 22, 3.5, { fill: tom, stroke: "none" }));
        g.appendChild(ret(15, y + 4, 78, 14, 7, { fill: vidro, stroke: borda, "stroke-width": FINO }));
        g.appendChild(ret(17.5, y + 5.5, 11, 11, 3, { stroke: borda, "stroke-width": 1 }));
        if (indefinida) g.appendChild(logoIndefinida(23, y + 11, 3.6, tinta));
        else g.appendChild(gatoDeTraco(23, y + 11.2, 3.4, tinta, nomeLogo));
        g.appendChild(lin(32, y + 6.5, 32, y + 15.5, { stroke: borda, "stroke-width": 1 }));
        for (var i = 0; i < 4; i++) {
          g.appendChild(ret(36 + i * 11, y + 6.5, 9, 9, 2.4, { stroke: borda, "stroke-width": 1 }));
        }
        return g;
      }

      s.appendChild(faixaDock(1, tomCima, m.dia, false));
      s.appendChild(faixaDock(25, tomBaixo, m.noite, rotativo));

      /* EM ROTAÇÃO NÃO HÁ NOITE, e desenhar uma lua embaixo dizia que havia. A
       * conferência visual pegou isto: com LOGO_MODO="rotacao" o quadro mostrava
       * a seta circular em cima e a lua embaixo ao mesmo tempo — duas causas
       * diferentes para a mesma troca. Em rotação as faixas são "agora" (o
       * ponto) e "a próxima" (a seta circular); só no modo por hora elas são o
       * sol e a lua. */
      if (rotativo) {
        s.appendChild(circ(8.5, 12, 1.9, { fill: CLARO, stroke: CLARO, "stroke-width": 1 }));
        s.appendChild(setaCircular(8.5, 36, 3, CLARO, 1.3));
      } else {
        s.appendChild(glifoSol(8.5, 12, 3.2, ESCURO));
        s.appendChild(glifoLua(8.5, 36, 3.2, CLARO, tomBaixo));
      }

      var corSeta = mistura(CLARO, ESCURO, 55);
      s.appendChild(lin(8.5, 18.5, 8.5, 29.5, {
        stroke: corSeta,
        "stroke-width": 1.4,
        "stroke-dasharray": m.reciclar ? null : "2.2 2",
      }));
      s.appendChild(cam("M6.9,27.9 L8.5,29.8 L10.1,27.9", {
        stroke: corSeta, "stroke-width": 1.4,
      }));

      return s;
    },

    legenda: function (m) {
      var quando;
      if (m.modo === "rotacao") {
        quando = "a logo gira pelo acervo a cada " + curto(m.intervalo, 10)
          + ", e a de baixo é a próxima da pasta, seja qual for";
      } else if (m.modo === "fixo") {
        quando = "a logo é sempre " + curto(m.logo) + ", de dia e de noite";
      } else {
        quando = "a logo segue o relógio: " + curto(m.dia) + " de dia, "
          + curto(m.noite) + " de noite";
      }
      var troca = m.reciclar
        ? "a barra recicla na virada, então o troco aparece na hora"
        : "sem reciclar a barra, o troco só aparece no próximo login (a seta é tracejada por isso)";
      return quando + " na ponta da dock, e " + troca + "." + m.fecho;
    },
  });

  /* ==========================================================================
   * 3. "Logo do sistema :: NO TERMINAL"
   * ==========================================================================
   * As catorze chaves FASTFETCH_*.
   *
   * Este é o bloco onde o painel mais precisava de um desenho, porque as chaves
   * são todas MEDIDA: colunas, linhas, quebras, recuo, proporção de célula,
   * alinhamento. Ler "tabular | contorno | degraus | crescente | reto" não diz
   * nada; ver a borda esquerda do texto acompanhando ou não a silhueta do gato
   * responde na hora.
   *
   * O DESENHO É FEITO DE CÉLULAS, E ISSO NÃO É ESTILO — é o assunto. O gato do
   * fastfetch é desenhado com CARACTERES, e por isso a silhueta aqui é uma
   * escadinha presa à grade: cada degrau é meia célula. Com `quadrante` a grade
   * é 2x2 por célula, com `sextante` é 2x3, e a escadinha fica visivelmente
   * mais fina — que é exatamente a diferença entre as duas opções.
   *
   * A REDONDEZA DO GATO É CONSEQUÊNCIA, e o desenho a mostra sem avisar: a
   * silhueta é uma elipse ajustada ao bloco de N colunas por M linhas, com a
   * largura da célula derivada de FASTFETCH_LOGO_CELULA. Deixar LINHAS vazia
   * mantém a conta redonda; cravar um valor fora da proporção deforma o gato
   * aqui na tela antes de deformá-lo no terminal.
   *
   * FASTFETCH_LOGO_CONF não entra no desenho: ela não decide um pixel do que
   * aparece, decide se o MeowSystem tem permissão para manter sozinho a linha
   * `logo.source` no config.jsonc, que é território do Ritual da Aurora. */

  var TERM = { x: 4.5, y: 10.5, w: 88, h: 34 };
  var LINHAS_DE_TEXTO = 11;   /* título + régua + nove linhas de informação */

  /* A silhueta, em coordenadas do bloco (0 a 1 nos dois eixos, y para baixo).
   * A cabeça é uma elipse; as orelhas são desenhadas por fora e entram só no
   * perfil que o TEXTO consulta — se o contorno as ignorasse, as primeiras
   * linhas começariam por cima delas. */
  function perfilCabeca(u) {
    var dy = (u - 0.6) / 0.4;
    if (dy <= -1 || dy >= 1) return 0;
    return 0.5 + 0.44 * Math.sqrt(1 - dy * dy);
  }

  function perfilOrelha(u) {
    if (u < 0.05 || u > 0.3) return 0;
    return 0.84 - 0.32 * (u - 0.05);
  }

  function perfilDoTexto(u) {
    return Math.max(perfilCabeca(u), perfilOrelha(u));
  }

  var TERM_ALINHAMENTOS = ["tabular", "contorno", "degraus", "crescente", "reto"];

  function modeloDoTerminal(v) {
    var d = diario();
    var ligado = lerSimNao(v, null, "FASTFETCH_LOGO", true);
    var modo = lerOpcao(v, d, "FASTFETCH_LOGO_MODO", ["espelho", "hora", "fixo"], "espelho");
    var gato = lerTexto(v, null, "FASTFETCH_LOGO_GATO", "coquinha");
    /* Vazio nas duas de baixo é DOCUMENTADO: herda a do dock. Anotá-las no
     * diário encheria a legenda de um aviso que não é sobre falta. */
    var dia = lerTexto(v, null, "FASTFETCH_LOGO_DIA", "");
    var noite = lerTexto(v, null, "FASTFETCH_LOGO_NOITE", "");
    var colunas = Math.round(lerNumero(v, null, "FASTFETCH_LOGO_COLUNAS", 40, 20, 120));
    var celula = lerNumero(v, null, "FASTFETCH_LOGO_CELULA", 2.556, 1, 4);
    /* Vazio aqui NÃO é falta: o meow.conf diz que a altura vazia é calculada de
     * `colunas / celula`, e é isso que mantém o gato redondo. Um valor que não
     * é número cai na mesma conta — e nesse caso ele É falta, porque a pessoa
     * quis cravar uma altura e não cravou. A medição do roteiro mostrou a
     * legenda dizendo "cravadas" justamente no caso em que nada foi cravado. */
    var calculadas = Math.round(colunas / celula);
    var linhasBrutas = texto(v.FASTFETCH_LOGO_LINHAS).replace(",", ".");
    var linhasValidas = linhasBrutas !== "" && isFinite(Number(linhasBrutas));
    if (linhasBrutas !== "" && !linhasValidas) d.invalidas.push("FASTFETCH_LOGO_LINHAS");
    var linhas = linhasValidas
      ? Math.round(faixa(Number(linhasBrutas), 8, 60))
      : calculadas;
    var quebrasBrutas = texto(v.FASTFETCH_LOGO_QUEBRAS).toLowerCase();
    var quebras = (quebrasBrutas === "" || quebrasBrutas === "auto")
      ? "auto"
      : Math.round(lerNumero(v, d, "FASTFETCH_LOGO_QUEBRAS", 0, 0, 24));
    var alinhar = lerOpcao(v, d, "FASTFETCH_LOGO_ALINHAR", TERM_ALINHAMENTOS, "tabular");
    var recuo = Math.round(lerNumero(v, null, "FASTFETCH_LOGO_RECUO", 3, 0, 12));
    var blocos = lerOpcao(v, d, "FASTFETCH_LOGO_BLOCOS", ["auto", "quadrante", "sextante"], "auto");
    var titulo = texto(v.FASTFETCH_TITULO);

    /* `auto` cai em QUADRANTE, e não é palpite: está medido no meow.conf que a
     * fonte do terminal dela não tem os sextantes, nem nenhuma instalada aqui.
     * Desenhar sextantes no `auto` prometeria um detalhe que a tela não entrega. */
    var grade = blocos === "sextante" ? 3 : 2;

    var qual = gato;
    if (modo === "hora") qual = noite || dia || gato;

    return {
      ligado: ligado,
      modo: modo,
      gato: qual,
      /* Com o logo desligado quem aparece é o de fábrica, e a largura dele é
       * fixa: 40 colunas, que é justamente o número que FASTFETCH_LOGO_COLUNAS
       * imita para o texto não escorregar de lugar. */
      colunas: ligado ? colunas : 40,
      linhas: ligado ? linhas : 16,
      linhasCalculadas: !linhasValidas,
      celula: celula,
      quebras: quebras,
      alinhar: alinhar,
      recuo: recuo,
      blocos: blocos,
      grade: grade,
      titulo: titulo,
      fecho: fechoDaLegenda(d),
    };
  }

  function desenhoDoTerminal(m, ctx) {
    var linhasQuadro = (ctx && ctx.linhas) || 16;
    var alturaLinha = TERM.h / linhasQuadro;
    /* A largura da coluna sai da ALTURA da linha dividida pela proporção da
     * célula. É a mesma conta do terminal de verdade, e é o que faz um valor de
     * FASTFETCH_LOGO_CELULA errado achatar o gato aqui também. */
    var largColuna = alturaLinha / m.celula;

    var topoGato = m.quebras === "auto"
      ? Math.max(0, (LINHAS_DE_TEXTO - m.linhas) / 2)
      : m.quebras;
    var topoTexto = m.quebras === "auto"
      ? Math.max(0, (m.linhas - LINHAS_DE_TEXTO) / 2)
      : 0;

    var blocoX = TERM.x;
    var blocoY = TERM.y + topoGato * alturaLinha;
    var blocoW = Math.min(m.colunas * largColuna, TERM.w * 0.86);
    var blocoH = m.linhas * alturaLinha;
    var fundoDoQuadro = TERM.y + TERM.h;
    var cortado = blocoY + blocoH > fundoDoQuadro + 0.4;

    var tom = "var(--crust, var(--base))";
    var tinta = "var(--text, " + CLARO + ")";
    var fraco = mistura(tinta, tom, 55);
    var acento = "var(--accent, var(--mauve))";

    var s = quadro("O terminal com o desenho à esquerda em " + m.colunas
      + " colunas e o texto à direita, alinhamento " + m.alinhar + ".");

    s.appendChild(ret(1.5, 1.5, 93, 45, 3.5, { fill: tom }));
    s.appendChild(lin(3, 8.6, 93, 8.6, { stroke: fraco, "stroke-width": 1 }));
    for (var p = 0; p < 3; p++) {
      s.appendChild(circ(6 + p * 3.6, 5, 1.1, { stroke: fraco, "stroke-width": 0.9 }));
    }

    if (m.ligado) {
      s.appendChild(silhuetaEmCelulas(blocoX, blocoY, blocoW, blocoH, m, acento, fundoDoQuadro));
      /* As orelhas saem por fora da escadinha de propósito: rasterizadas, elas
       * viram um trapézio no alto da cabeça (a silhueta tem UM vão por linha e
       * não sabe fazer dois picos), e o desenho deixa de parecer gato. */
      s.appendChild(orelhasDoBloco(blocoX, blocoY, blocoW, blocoH, acento));
    } else {
      /* Logo de fábrica: um lugar reservado, tracejado, do tamanho que ele
       * ocupa. Inventar um desenho aqui seria dizer qual é, e não é nosso. */
      s.appendChild(ret(blocoX, blocoY, blocoW, Math.min(blocoH, fundoDoQuadro - blocoY), 2, {
        stroke: fraco, "stroke-width": 1, "stroke-dasharray": "3 2.4",
      }));
      s.appendChild(circ(blocoX + blocoW / 2, blocoY + Math.min(blocoH, fundoDoQuadro - blocoY) / 2,
        Math.min(blocoW, blocoH) * 0.26, { stroke: fraco, "stroke-width": 1.2 }));
    }

    if (cortado) {
      s.appendChild(lin(TERM.x, fundoDoQuadro - 0.6, TERM.x + TERM.w, fundoDoQuadro - 0.6, {
        stroke: "var(--peach, currentColor)", "stroke-width": 1, "stroke-dasharray": "2 2",
      }));
    }

    /* --- o texto, e a borda esquerda que responde pelo alinhamento ------- */
    var chaves = [0.16, 0.2, 0.18, 0.24, 0.15, 0.22, 0.19, 0.17, 0.21];
    var valores = [0.46, 0.34, 0.52, 0.28, 0.4, 0.48, 0.32, 0.44, 0.36];

    var inicios = [];
    var maiorAte = 0;
    var maiorTudo = 0;
    var r;
    for (r = 0; r < LINHAS_DE_TEXTO; r++) {
      var yLinha = TERM.y + (topoTexto + r + 0.5) * alturaLinha;
      var u = blocoH > 0 ? (yLinha - blocoY) / blocoH : -1;
      var perfil = (m.ligado && u >= 0 && u <= 1) ? perfilDoTexto(u) : 0;
      var colunasAte = perfil * m.colunas;
      if (colunasAte > maiorTudo) maiorTudo = colunasAte;
      inicios.push(colunasAte);
    }

    var esquerda = [];
    for (r = 0; r < LINHAS_DE_TEXTO; r++) {
      var col;
      if (m.alinhar === "tabular") {
        col = m.colunas;
      } else if (m.alinhar === "reto") {
        col = maiorTudo;
      } else if (m.alinhar === "degraus") {
        col = Math.ceil(inicios[r] / 4) * 4;
      } else if (m.alinhar === "crescente") {
        maiorAte = Math.max(maiorAte, inicios[r]);
        col = maiorAte;
      } else {
        col = inicios[r];
      }
      if (!m.ligado && m.alinhar !== "tabular") col = Math.max(col, m.colunas);
      esquerda.push(TERM.x + (col + m.recuo) * largColuna);
    }

    var direita = TERM.x + TERM.w;
    var espessura = faixa(alturaLinha * 0.42, 0.55, 1.4);
    var textoG = grupo();
    for (r = 0; r < LINHAS_DE_TEXTO; r++) {
      var y = TERM.y + (topoTexto + r + 0.5) * alturaLinha;
      if (y > fundoDoQuadro - 0.4) break;
      var x0 = esquerda[r];
      var disponivel = Math.max(0, direita - x0);
      if (disponivel < 2) continue;
      if (r === 0) {
        /* O título. Vazio não some: o fastfetch monta o dele com usuário e
         * host, e o desenho mostra isso em traço fraco para a diferença entre
         * "meu título" e "o de fábrica" ficar visível. */
        textoG.appendChild(lin(x0, y, x0 + disponivel * 0.72, y, {
          stroke: m.titulo ? acento : fraco,
          "stroke-width": espessura * 1.25,
          "stroke-dasharray": m.titulo ? null : "2.4 1.8",
        }));
      } else if (r === 1) {
        textoG.appendChild(lin(x0, y, x0 + disponivel * 0.72, y, {
          stroke: fraco, "stroke-width": espessura * 0.7,
        }));
      } else {
        var i = r - 2;
        var lc = disponivel * chaves[i % chaves.length];
        var lv = disponivel * valores[i % valores.length];
        textoG.appendChild(lin(x0, y, x0 + lc, y, { stroke: acento, "stroke-width": espessura }));
        textoG.appendChild(lin(x0 + lc + largColuna, y, Math.min(direita, x0 + lc + largColuna + lv), y, {
          stroke: fraco, "stroke-width": espessura,
        }));
      }
    }
    s.appendChild(textoG);

    return s;
  }

  /* A escadinha: para cada sub-linha da grade, a borda direita e a esquerda são
   * arredondadas para a sub-COLUNA mais próxima. Sub-linhas seguidas com a
   * mesma borda viram um segmento só — sem isso o caminho ganha duzentos pontos
   * repetidos e a escadinha some numa mancha. */
  function silhuetaEmCelulas(x0, y0, w, h, m, cor, fundoDoQuadro) {
    var subLinhas = Math.max(4, Math.min(240, Math.round(m.linhas * m.grade)));
    var subColunas = Math.max(4, Math.min(480, Math.round(m.colunas * 2)));
    var altSub = h / subLinhas;
    var largSub = w / subColunas;

    var faixas = [];
    for (var i = 0; i < subLinhas; i++) {
      var topo = y0 + i * altSub;
      if (topo >= fundoDoQuadro) break;
      var u = (i + 0.5) / subLinhas;
      var dir = perfilCabeca(u);
      if (dir <= 0.5) continue;
      var cd = Math.round(dir * subColunas);
      var ce = subColunas - cd;
      if (cd - ce < 1) continue;
      faixas.push({
        topo: topo,
        base: Math.min(topo + altSub, fundoDoQuadro),
        e: x0 + ce * largSub,
        d: x0 + cd * largSub,
      });
    }
    if (!faixas.length) return grupo();

    var d = "M" + n2(faixas[0].d) + "," + n2(faixas[0].topo);
    var j;
    for (j = 1; j < faixas.length; j++) {
      if (faixas[j].d !== faixas[j - 1].d) {
        d += " L" + n2(faixas[j - 1].d) + "," + n2(faixas[j].topo);
        d += " L" + n2(faixas[j].d) + "," + n2(faixas[j].topo);
      }
    }
    var ultima = faixas[faixas.length - 1];
    d += " L" + n2(ultima.d) + "," + n2(ultima.base);
    d += " L" + n2(ultima.e) + "," + n2(ultima.base);
    for (j = faixas.length - 1; j > 0; j--) {
      if (faixas[j].e !== faixas[j - 1].e) {
        d += " L" + n2(faixas[j].e) + "," + n2(faixas[j].topo);
        d += " L" + n2(faixas[j - 1].e) + "," + n2(faixas[j].topo);
      }
    }
    d += " L" + n2(faixas[0].e) + "," + n2(faixas[0].topo) + " Z";

    return cam(d, {
      stroke: cor,
      "stroke-width": faixa(altSub * 0.7, 0.5, 1.2),
      "stroke-linejoin": "miter",
    });
  }

  function orelhasDoBloco(x0, y0, w, h, cor) {
    function pt(fx, fu) {
      return n2(x0 + fx * w) + "," + n2(y0 + fu * h);
    }
    var lw = faixa(w * 0.035, 0.5, 1.2);
    return grupo([
      cam("M" + pt(0.24, 0.3) + " L" + pt(0.16, 0.05) + " L" + pt(0.4, 0.235) + " Z",
        { stroke: cor, "stroke-width": lw }),
      cam("M" + pt(0.76, 0.3) + " L" + pt(0.84, 0.05) + " L" + pt(0.6, 0.235) + " Z",
        { stroke: cor, "stroke-width": lw }),
    ]);
  }

  var LOGO_NO_TERMINAL = bloco({
    rotulo: "a logo no terminal",
    modelo: modeloDoTerminal,

    /* As duas alturas de linha viram UMA só. Se cada quadro calculasse a sua, o
     * "como está" e o "como fica" sairiam em escalas diferentes e a comparação
     * — que é o motivo do par existir — não valeria nada. */
    contexto: function (a, b) {
      var pedido = Math.max(
        (a.quebras === "auto" ? 0 : a.quebras) + a.linhas, LINHAS_DE_TEXTO,
        (b.quebras === "auto" ? 0 : b.quebras) + b.linhas, LINHAS_DE_TEXTO);
      return { linhas: Math.round(faixa(pedido, 12, 30)) };
    },

    desenho: desenhoDoTerminal,

    legenda: function (m) {
      if (!m.ligado) {
        return "o terminal fica com o logo de fábrica do fastfetch, em 40 colunas, "
          + "e o texto começa " + (m.recuo) + " colunas depois dele." + m.fecho;
      }
      var alturaTexto = m.linhasCalculadas
        ? m.linhas + " linhas calculadas pela célula " + m.celula
        : m.linhas + " linhas cravadas";
      var alinhamentos = {
        tabular: "o texto todo na mesma coluna",
        contorno: "o texto abraçando a silhueta",
        degraus: "o texto acompanhando a silhueta de quatro em quatro colunas",
        crescente: "o texto acompanhando a silhueta enquanto ela engorda e ficando onde está quando ela afina",
        reto: "o texto na mesma coluna, medida pelo trecho que ele ocupa",
      };
      var quebras = m.quebras === "auto"
        ? "os dois blocos centrados um no outro"
        : m.quebras + " linhas em branco antes do desenho";
      return "o gato " + curto(m.gato) + " em " + m.colunas + " colunas por " + alturaTexto
        + ", desenhado em " + (m.grade === 3 ? "sextantes" : "quadrantes") + ", com "
        + alinhamentos[m.alinhar] + " a " + m.recuo + " colunas de distância, e "
        + quebras + "." + m.fecho;
    },
  });

  /* ==========================================================================
   * 4. "Ícones"
   * ==========================================================================
   * NOME_TEMA_ICONES · ICONES_BASE · ICONES_PASTAS · ICONES_FLAVOR ·
   * ICONES_COR_MARCA · PASTAS_XDG
   *
   * Duas fileiras, porque são dois assuntos que as chaves misturam:
   *
   *   EM CIMA, quatro pastas. As duas primeiras são pastas comuns, na cor do
   *   ICONES_PASTAS. As duas últimas são as pastas especiais (Imagens,
   *   Transferências) e são elas que PASTAS_XDG troca — de cheias na cor do
   *   tema para vazadas de traço claro. A queixa dela sobre esse pack foi
   *   exatamente essa: "pasta VAZADA de traço claro ao lado das mauve CHEIAS".
   *   Ver as quatro lado a lado é ver a queixa.
   *
   *   EMBAIXO, quatro programas e um lugar tracejado. Os quatro mudam de cor
   *   com ICONES_COR_MARCA, e as cores dos dois lados não são inventadas: são a
   *   tabela que o próprio meow.conf publica (o mensageiro sai de sky para
   *   green, a loja de jogos de green para sapphire, o navegador de blue para
   *   peach). O lugar tracejado no fim é o ICONES_BASE — "todo ícone que falta
   *   sai daqui", que é a única coisa que essa chave faz.
   *
   * O FUNDO é o ICONES_FLAVOR, e ele fica atrás de tudo porque é o que ele é:
   * o sabor dos ícones de tipo de arquivo, o pano de fundo do gerenciador.
   *
   * NOME_TEMA_ICONES não tem desenho — trocar o nome cria uma pasta nova em
   * ~/.local/share/icons e não muda um traço. A legenda o diz. */

  /* ICONES_PASTAS chega escrito com as variáveis por expandir, e ISSO É O
   * PEDIDO do meow.conf: `cat-${FLAVOR}-${ACCENT}` acompanha o tema sozinho.
   * Então o valor tem de ser lido sem ser expandido — o que sobra depois do
   * último traço é o nome da cor, e quando ele é a variável do accent a cor é a
   * de destaque da página. */
  function corDasPastas(valor) {
    var t = texto(valor);
    if (t === "") return { cor: "var(--accent, var(--mauve))", rotulo: "" };
    var ultimo = t.split("-").pop();
    var limpo = ultimo.replace(/[${}]/g, "").toLowerCase();
    if (limpo === "accent") return { cor: "var(--accent, var(--mauve))", rotulo: t };
    if (CORES.indexOf(limpo) >= 0) return { cor: "var(--" + limpo + ")", rotulo: t };
    return { cor: "var(--accent, var(--mauve))", rotulo: t };
  }

  function pastaD(x, y, w, h) {
    var r = 1.5;
    var aba = w * 0.42;
    return "M" + n2(x + r) + "," + n2(y)
      + " h" + n2(aba - 2 * r)
      + " l2.2,2.4"
      + " h" + n2(w - aba - 2.2 - r)
      + " a" + r + "," + r + " 0 0 1 " + r + "," + r
      + " v" + n2(h - 2.4 - 2 * r)
      + " a" + r + "," + r + " 0 0 1 " + (-r) + "," + r
      + " h" + n2(-(w - 2 * r))
      + " a" + r + "," + r + " 0 0 1 " + (-r) + "," + (-r)
      + " V" + n2(y + r)
      + " a" + r + "," + r + " 0 0 1 " + r + "," + (-r)
      + " Z";
  }

  var ICONES = bloco({
    rotulo: "os ícones",

    modelo: function (v) {
      var d = diario();
      var pastas = corDasPastas(v.ICONES_PASTAS);
      return {
        tema: lerTexto(v, null, "NOME_TEMA_ICONES", "MeowSystem-Icons"),
        base: lerTexto(v, null, "ICONES_BASE", "Papirus-Dark"),
        pastasCor: pastas.cor,
        pastasFrase: pastas.rotulo
          ? "pastas em " + curto(pastas.rotulo, 30)
          : "pastas na cor de destaque",
        flavor: lerOpcao(v, d, "ICONES_FLAVOR", FLAVORS, "macchiato"),
        marca: lerSimNao(v, d, "ICONES_COR_MARCA", false),
        xdg: lerSimNao(v, d, "PASTAS_XDG", false),
        fecho: fechoDaLegenda(d),
      };
    },

    desenho: function (m) {
      var tom = tomDoFlavor(m.flavor);
      var claro = m.flavor === "latte";
      var tinta = claro ? ESCURO : CLARO;
      var fraco = mistura(tinta, tom, 55);
      var s = quadro("Quatro pastas e quatro programas no tema " + m.tema
        + ", sabor " + m.flavor + ", cor "
        + (m.marca ? "pela marca de cada programa" : "por categoria") + ".");

      s.appendChild(ret(1.5, 1.5, 93, 45, 3.5, { fill: tom }));

      /* --- as quatro pastas ---------------------------------------------- */
      var larguraPasta = 18;
      for (var i = 0; i < 4; i++) {
        var px = 6 + i * 22;
        var especial = i >= 2;
        var vazada = especial && m.xdg;
        var cor = vazada ? fraco : m.pastasCor;
        s.appendChild(cam(pastaD(px, 8, larguraPasta, 14), {
          stroke: cor,
          "stroke-width": vazada ? 1 : 1.8,
          /* As pastas do papirus são CHEIAS na cor do tema; as do outro pack
           * são vazadas. O preenchimento leve é o que deixa isso visível sem
           * virar um bloco chapado no meio de um desenho de traço. */
          fill: vazada ? "none" : mistura(cor, tom, 20),
        }));
        if (especial) {
          if (i === 2) {
            /* Imagens: o morrinho e o sol, o emblema do pack. */
            s.appendChild(cam("M" + n2(px + 4.5) + ",19 L" + n2(px + 7.6) + ",15.2 L"
              + n2(px + 10.4) + ",19", { stroke: cor, "stroke-width": 1.1 }));
            s.appendChild(circ(px + 12.6, 15, 1.1, { stroke: cor, "stroke-width": 1.1 }));
          } else {
            /* Transferências: a seta para baixo sobre a linha. */
            s.appendChild(lin(px + 9, 13.4, px + 9, 18, { stroke: cor, "stroke-width": 1.1 }));
            s.appendChild(cam("M" + n2(px + 7) + ",16.2 L" + n2(px + 9) + ",18.4 L"
              + n2(px + 11) + ",16.2", { stroke: cor, "stroke-width": 1.1 }));
          }
        }
      }

      /* --- os quatro programas ------------------------------------------- */
      /* As duas listas saem da tabela que o meow.conf publica em
       * ICONES_COR_MARCA. Não são cores escolhidas aqui: são as que a máquina
       * entrega de um lado e do outro da chave. */
      var porCategoria = ["sky", "green", "blue", "sky"];
      var porMarca = ["green", "sapphire", "peach", "lavender"];
      var paleta = m.marca ? porMarca : porCategoria;

      for (var k = 0; k < 4; k++) {
        var ax = 6 + k * 18;
        var ac = "var(--" + paleta[k] + ")";
        s.appendChild(ret(ax, 29, 14, 14, 3.4, { stroke: ac, "stroke-width": 1.6 }));
        s.appendChild(glifoDeApp(k, ax + 7, 36, 3.4, ac));
      }

      /* O tema herdado: o lugar de onde vem o que o nosso não desenha. */
      s.appendChild(ret(78, 29, 14, 14, 3.4, {
        stroke: fraco, "stroke-width": 1.1, "stroke-dasharray": "3 2.4",
      }));
      /* TRÊS PONTOS, E NÃO UMA SETA PARA BAIXO. A seta que estava aqui era a
       * MESMA da pasta Transferências três centímetros acima, e o quadro passava
       * a ter dois desenhos iguais querendo dizer coisas diferentes. Os três
       * pontos dizem "e os demais", que é o que o tema herdado é. */
      for (var t = 0; t < 3; t++) {
        s.appendChild(circ(81.6 + t * 3.4, 36, 0.85, { fill: fraco, stroke: "none" }));
      }

      return s;
    },

    legenda: function (m) {
      return "tema " + curto(m.tema) + ", " + m.pastasFrase
        + ", ícones de arquivo no sabor " + m.flavor + ", cor "
        + (m.marca
          ? "pela marca de cada programa (o mensageiro fica verde, a loja de jogos safira, o navegador pêssego)"
          : "por categoria (programas do mesmo assunto na mesma cor)")
        + ", pastas especiais "
        + (m.xdg ? "vazadas, do outro pack" : "na mesma cor das outras")
        + ", e o que faltar vem do " + curto(m.base) + "." + m.fecho;
    },
  });

  function glifoDeApp(indice, cx, cy, r, cor) {
    var a = { stroke: cor, "stroke-width": 1.3 };
    if (indice === 0) {
      /* balão de conversa */
      return cam("M" + n2(cx - r) + "," + n2(cy - r * 0.7)
        + " a" + n2(r * 0.5) + "," + n2(r * 0.5) + " 0 0 1 " + n2(r * 0.5) + "," + n2(-r * 0.5)
        + " h" + n2(r) + " a" + n2(r * 0.5) + "," + n2(r * 0.5) + " 0 0 1 " + n2(r * 0.5) + "," + n2(r * 0.5)
        + " v" + n2(r * 0.8) + " a" + n2(r * 0.5) + "," + n2(r * 0.5) + " 0 0 1 " + n2(-r * 0.5) + "," + n2(r * 0.5)
        + " h" + n2(-r * 0.7) + " l" + n2(-r * 0.7) + "," + n2(r * 0.7)
        + " v" + n2(-r * 0.7) + " a" + n2(r * 0.5) + "," + n2(r * 0.5) + " 0 0 1 " + n2(-r * 0.3) + "," + n2(-r * 0.5)
        + " Z", a);
    }
    if (indice === 1) {
      /* alvo: a loja de jogos */
      return grupo([circ(cx, cy, r * 0.85, a), circ(cx, cy, r * 0.22, juntar({ fill: cor }, a))]);
    }
    if (indice === 2) {
      /* globo: o navegador */
      return grupo([
        circ(cx, cy, r * 0.85, a),
        cam("M" + n2(cx - r * 0.85) + "," + n2(cy) + " h" + n2(r * 1.7), a),
        cam("M" + n2(cx) + "," + n2(cy - r * 0.85)
          + " q" + n2(r * 0.6) + "," + n2(r * 0.85) + " 0," + n2(r * 1.7)
          + " q" + n2(-r * 0.6) + "," + n2(-r * 0.85) + " 0," + n2(-r * 1.7), a),
      ]);
    }
    /* janela: um programa qualquer */
    return grupo([
      ret(cx - r * 0.85, cy - r * 0.7, r * 1.7, r * 1.5, 0.6, a),
      lin(cx - r * 0.85, cy - r * 0.18, cx + r * 0.85, cy - r * 0.18, a),
    ]);
  }

  /* ==========================================================================
   * 5. "Terminal"
   * ==========================================================================
   * TERMINAL_ESQUEMA · TERMINAL_CURSOR · PROMPT_STARSHIP
   *
   * Três chaves, três coisas visíveis, e as três na mesma linha de comando:
   *
   *   PROMPT_STARSHIP muda a FORMA do prompt. O preset powerline são pastilhas
   *   emendadas com bico à direita, e não existe nada na tela que se pareça com
   *   isso — é a diferença mais reconhecível dos três, então ela é o corpo do
   *   desenho.
   *   TERMINAL_ESQUEMA muda as DEZESSEIS cores. A tira embaixo é a paleta ANSI
   *   inteira, em traços verticais: com o esquema ligado, as cores do
   *   Catppuccin; desligado, a tira apagada, porque o que fica ali é o que o
   *   cosmic-term traz de fábrica e não é nosso para desenhar.
   *   TERMINAL_CURSOR muda a COR do cursor — não a forma. O bloco depois do
   *   prompt é o cursor, e ele sai na cor de destaque ou na do port oficial.
   *
   * O rosewater do port não é escolha: é a cor que o port oficial do Catppuccin
   * usa para o cursor, e "port" quer dizer exatamente devolver o arquivo dele. */

  /* Os dezesseis nomes na ordem ANSI, por NOME de paleta — nunca por valor. As
   * oito de cima são as normais, as oito de baixo as claras. */
  var ANSI = [
    "surface1", "red", "green", "yellow", "blue", "pink", "teal", "subtext1",
    "surface2", "maroon", "green", "peach", "sapphire", "mauve", "sky", "text",
  ];

  var TERMINAL = bloco({
    rotulo: "o terminal",

    modelo: function (v) {
      var d = diario();
      return {
        esquema: lerSimNao(v, d, "TERMINAL_ESQUEMA", true),
        cursor: lerOpcao(v, d, "TERMINAL_CURSOR", ["accent", "port"], "accent"),
        starship: lerSimNao(v, d, "PROMPT_STARSHIP", true),
        fecho: fechoDaLegenda(d),
      };
    },

    desenho: function (m) {
      var tom = "var(--crust, var(--base))";
      var tinta = "var(--text, " + CLARO + ")";
      var fraco = mistura(tinta, tom, 52);
      var corCursor = m.cursor === "port" ? "var(--rosewater)" : "var(--accent, var(--mauve))";

      var s = quadro("Uma linha de comando com "
        + (m.starship ? "o prompt do starship em pastilhas" : "o prompt simples")
        + ", cursor " + (m.cursor === "port" ? "na cor do port oficial" : "na cor de destaque")
        + " e a paleta " + (m.esquema ? "do Catppuccin" : "de fábrica") + ".");

      s.appendChild(ret(1.5, 1.5, 93, 45, 3.5, { fill: tom }));
      s.appendChild(lin(3, 8.6, 93, 8.6, { stroke: fraco, "stroke-width": 1 }));
      for (var p = 0; p < 3; p++) {
        s.appendChild(circ(6 + p * 3.6, 5, 1.1, { stroke: fraco, "stroke-width": 0.9 }));
      }

      var x = 5;
      if (m.starship) {
        /* As pastilhas do powerline: retângulo com bico à direita, emendadas.
         * O preenchimento é leve porque a cor É a informação, mas o contorno
         * continua sendo o traço — a pastilha chapada viraria um bloco de cor
         * no meio de um desenho de linha. */
        var segmentos = [
          { w: 20, cor: m.esquema ? "var(--mauve)" : fraco },
          { w: 15, cor: m.esquema ? "var(--blue)" : fraco },
          { w: 11, cor: m.esquema ? "var(--green)" : fraco },
        ];
        for (var i = 0; i < segmentos.length; i++) {
          var seg = segmentos[i];
          s.appendChild(cam("M" + n2(x) + ",12 h" + n2(seg.w)
            + " l3.4,4.4 l-3.4,4.4 h" + n2(-seg.w) + " Z", {
            fill: mistura(seg.cor, tom, 24),
            stroke: seg.cor,
            "stroke-width": 1.2,
            "stroke-linejoin": "miter",
          }));
          x += seg.w + 3.4;
        }
        x += 2.4;
        s.appendChild(cam("M" + n2(x) + ",13.6 l2.6,2.8 l-2.6,2.8", {
          stroke: m.esquema ? "var(--green)" : tinta, "stroke-width": 1.6,
        }));
        x += 5.4;
      } else {
        /* Sem starship: usuário, host e o cifrão, tudo na cor do texto. */
        s.appendChild(lin(x, 16.4, x + 20, 16.4, { stroke: tinta, "stroke-width": 1.4 }));
        s.appendChild(lin(x + 23, 16.4, x + 31, 16.4, { stroke: fraco, "stroke-width": 1.4 }));
        x += 34;
        s.appendChild(cam("M" + n2(x) + ",13.6 l2.6,2.8 l-2.6,2.8", {
          stroke: tinta, "stroke-width": 1.6,
        }));
        x += 5.4;
      }

      s.appendChild(ret(x, 12.4, 3.6, 8, 0.8, {
        fill: corCursor, stroke: corCursor, "stroke-width": 0.8,
      }));

      /* Três linhas de saída, para a paleta aparecer em uso e não só na tira. */
      var saida = m.esquema
        ? [["var(--green)", 16, "var(--text, currentColor)", 34],
           ["var(--peach)", 11, "var(--text, currentColor)", 46],
           ["var(--teal)", 20, "var(--text, currentColor)", 26]]
        : [[tinta, 16, fraco, 34], [tinta, 11, fraco, 46], [tinta, 20, fraco, 26]];
      for (var r = 0; r < saida.length; r++) {
        var y = 26 + r * 4.6;
        s.appendChild(lin(5, y, 5 + saida[r][1], y, { stroke: saida[r][0], "stroke-width": 1.3 }));
        s.appendChild(lin(7.4 + saida[r][1], y, 7.4 + saida[r][1] + saida[r][3], y, {
          stroke: saida[r][2], "stroke-width": 1.3,
        }));
      }

      /* A tira das dezesseis. Traço vertical e não quadradinho cheio: é a
       * mesma paleta, no estilo da casa. */
      for (var c = 0; c < 16; c++) {
        s.appendChild(lin(5.5 + c * 5.5, 40.4, 5.5 + c * 5.5, 43.8, {
          stroke: m.esquema ? "var(--" + ANSI[c] + ")" : fraco,
          "stroke-width": 2.4,
          "stroke-dasharray": m.esquema ? null : "1.2 1.4",
        }));
      }

      return s;
    },

    legenda: function (m) {
      return (m.esquema
        ? "as dezesseis cores do terminal vêm do Catppuccin"
        : "o terminal fica com a paleta de fábrica do cosmic-term")
        + ", o cursor sai "
        + (m.cursor === "port" ? "no rosewater do port oficial" : "na cor de destaque")
        + ", e o prompt do zsh "
        + (m.starship ? "é o preset powerline do starship" : "é o simples, sem starship")
        + "." + m.fecho;
    },
  });

  /* ==========================================================================
   * O MAPA
   * ==========================================================================
   * As chaves são "Seção :: BLOCO" com os nomes NOVOS das seções — a Frente A
   * juntou "Cor e tema" e "Janelas e tela" numa só "Cor e tela", e "O gato"
   * virou "Logo do sistema". Os nomes de bloco em caixa alta (NO DOCK, NO
   * TERMINAL) continuam os mesmos. */
  window.MEOW_PREVIAS = Object.assign(window.MEOW_PREVIAS || {}, {
    "Cor e tela": COR_E_TELA,
    "Logo do sistema :: NO DOCK": LOGO_NO_DOCK,
    "Logo do sistema :: NO TERMINAL": LOGO_NO_TERMINAL,
    "Ícones": ICONES,
    "Terminal": TERMINAL,
  });
})();

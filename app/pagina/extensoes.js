"use strict";

const EXT = { dados: null, quando: 0, pedindo: false, religar: null, mudou: 0, trocou: false };
const REPOSITORIO_DA_CASA = "https://github.com/vitoriamariadb/MeowSystem";
const AUTORES = [
  { nome: "Vitória Maria", papel: "autora" },
  { nome: "André Farias", papel: "coautor" },
];
const ABAS_EXT = [
  { id: "applets", nome: "Applets", icone: "grade" },
  { id: "builds", nome: "Builds", icone: "terminal" },
];

async function carregarExtensoes() {
  if (EXT.pedindo) return;
  EXT.pedindo = true;
  EXT.quando = Date.now();
  const marca = EXT.mudou;
  const r = await api("/api/extensoes");
  EXT.pedindo = false;
  if (marca !== EXT.mudou) { EXT.quando = 0; return carregarExtensoes(); }
  EXT.dados = r.erro ? { erro: r.erro, extensoes: [], builds: null, ocupado: null } : r;
  clearTimeout(EXT.religar);
  if (EXT.dados.ocupado) EXT.religar = setTimeout(() => { EXT.quando = 0; if (ROTA.porta === "extensoes") render(); }, 2500);
  if (ROTA.porta === "extensoes") render();
}

function extensaoPorId(id) {
  return ((EXT.dados && EXT.dados.extensoes) || []).find((e) => e.id === id) || null;
}

function iconeDaExtensao(e, classe = "") {
  const img = elemento("img", { src: "/extensao-icone?id=" + encodeURIComponent(e.id), alt: "", class: classe || null });
  img.addEventListener("error", () => {
    img.replaceWith(elemento("span", { class: "lugar-applet" }, [icone("grade")]));
  }, { once: true });
  return img;
}

function versaoDaExtensao(e) {
  const dica = elemento("span", { class: "dica-repo", role: "tooltip" }, [
    elemento("span", { texto: e.url }),
    e.commit ? elemento("span", { texto: "commit " + e.commit }) : null,
    e.data ? elemento("span", { texto: e.data }) : null,
  ]);
  const texto = [e.versao, e.commit].filter(Boolean).join(" · ");
  return elemento("span", { class: "versao", tabindex: "0" }, [texto, dica]);
}

function pilulaDeExtensao(e, ocupado) {
  if (ocupado && ocupado.id === e.id) return ["correndo", "Compilando"];
  if (e.falhou) return ["erro", "Falhou"];
  if (!e.instalada) return ["neutro", "Não instalada"];
  if (e.atualizacao) return ["ensaio", "Atualização"];
  return e.na_barra ? ["ok", "Na barra"] : ["neutro", "Instalada, fora da barra"];
}

function depoisDoGesto() {
  EXT.mudou += 1;
  EXT.quando = 0;
  carregarExtensoes();
}
function gestoDeExtensao(acaoId, e, verbo) {
  EXT.quando = 0;
  return rodar(ACAO.get(acaoId), e.id, { verbo, depois: depoisDoGesto });
}
const idDaAcao = (e, casa, repo) => (e.casa ? casa : repo);
const tipoDe = (e) => e.tipo || "applet";
const ehApplet = (e) => tipoDe(e) === "applet";
const BINARIO_DO_TIPO = { compositor: "cosmic-comp", menu: "cosmic-files" };

function botoesDoCartao(e, parado) {
  const b = (texto, props, acao) => botao(texto, { class: "bt pequeno" + (props.principal ? " principal" : ""),
    icone: props.icone, disabled: parado, controle: props.controle, onclick: acao });
  const remover = botao("", { class: "bt leve pequeno so-icone", icone: "lixo", disabled: parado,
    "aria-label": "Remover " + e.nome, dica: "Remover", controle: "extensao:remover:" + e.id,
    onclick: () => gestoDeExtensao("extensao_remover", e, "Remover") });
  if (e.falhou) {
    return [b("Tentar de novo", { icone: "girar", principal: true, controle: "extensao:refazer:" + e.id },
      () => gestoDeExtensao("extensao_refazer", e, "Tentar de novo")), e.instalada ? remover : null];
  }
  if (!e.instalada) {
    return [b("Instalar", { icone: "baixar", principal: true, controle: "extensao:instalar:" + e.id },
      () => gestoDeExtensao(idDaAcao(e, "extensao_instalar", "extensao_instalar_repo"), e, "Instalar"))];
  }
  const fila = [];
  if (e.atualizacao) {
    fila.push(b("Atualizar", { icone: "subir", principal: true, controle: "extensao:atualizar:" + e.id },
      () => gestoDeExtensao(idDaAcao(e, "extensao_atualizar", "extensao_atualizar_repo"), e, "Atualizar")));
  }
  if (!e.na_barra) {
    fila.push(b("Pôr no painel", { icone: "mais", controle: "extensao:por:" + e.id },
      () => gestoDeExtensao("extensao_por_no_painel", e, "Pôr no painel")));
  }
  fila.push(remover);
  return fila;
}

function cartaoDeExtensao(e, ocupado) {
  const [estado, texto] = pilulaDeExtensao(e, ocupado);
  const parado = !!ocupado;
  return elemento("article", { class: "bloco cartao-acao", "data-applet": e.id, "data-nome": e.nome }, [
    elemento("div", { class: "cartao-cabeca" }, [
      elemento("span", { class: "icone" }, [iconeDaExtensao(e)]),
      elemento("div", {}, [elemento("h3", { texto: e.nome }), versaoDaExtensao(e)]),
    ]),
    elemento("span", { class: "estado-pilula", "data-estado": estado, "data-pilula": true, texto }),
    e.falhou && e.registro ? elemento("details", { class: "registro" }, [
      elemento("summary", { texto: "Registro" }), elemento("pre", {}, linhasDoRegistro(e.registro))]) : null,
    elemento("div", { class: "fila" }, botoesDoCartao(e, parado)),
  ]);
}

function pilulaDoBuildDaCasa(e, ocupado, construindo) {
  if ((ocupado && ocupado.id === e.id) || (construindo && !e.instalada)) return ["correndo", "Compilando"];
  if (e.falhou) return ["erro", "Falhou"];
  if (e.situacao === "nao-encaixa") return ["erro", "Não encaixa"];
  if (e.atualizacao) return ["ensaio", "Atualização"];
  if (!e.instalada) return ["neutro", "Não instalada"];
  return e.ativa ? ["ok", "Em dia"] : ["neutro", "Pronto, desligado"];
}

function botoesDoBuildDaCasa(e, parado) {
  const b = (texto, icone, verbo, acao, livre, principal) => botao(texto, {
    class: "bt pequeno" + (principal ? " principal" : ""), icone, disabled: parado || !livre,
    controle: "extensao:" + verbo + ":" + e.id, onclick: () => gestoDeExtensao(acao, e, texto) });
  const ligar = !e.atualizacao && (!e.instalada || !e.ativa);
  return [
    b("Instalar", "baixar", "instalar", "extensao_instalar", ligar, ligar),
    b("Atualizar", "subir", "atualizar", "extensao_atualizar", e.atualizacao, e.atualizacao),
    b("Refazer", "girar", "refazer", "extensao_refazer", true, false),
    botao("", { class: "bt leve pequeno so-icone", icone: "lixo", disabled: parado || !e.ativa,
      "aria-label": "Remover " + e.nome, dica: "Remover", controle: "extensao:remover:" + e.id,
      onclick: () => gestoDeExtensao("extensao_remover", e, "Remover") }),
  ];
}

function cartaoDoBuildDaCasa(e, ocupado, construindo, remendos) {
  const [estado, texto] = pilulaDoBuildDaCasa(e, ocupado, construindo);
  const detalhes = [e.versao ? (BINARIO_DO_TIPO[tipoDe(e)] || e.id) + " " + e.versao : "",
    tipoDe(e) === "compositor" && remendos ? remendos + " remendos" : ""].filter(Boolean).join(" · ");
  return elemento("article", { class: "bloco cartao-acao", "data-build": e.id, "data-nome": e.nome }, [
    elemento("div", { class: "cartao-cabeca" }, [
      elemento("span", { class: "icone" }, [iconeDaExtensao(e)]),
      elemento("div", {}, [elemento("h3", { texto: e.nome }), elemento("span", { class: "versao", texto: detalhes })]),
    ]),
    elemento("span", { class: "estado-pilula", "data-estado": estado, "data-pilula": true, texto }),
    elemento("div", { class: "fila" }, botoesDoBuildDaCasa(e, !!ocupado || !!construindo)),
  ]);
}

function linhasDoRegistro(texto) {
  return String(texto || "").split("\n").map((l) =>
    elemento("span", { class: classeDaLinha(l) || null, texto: l + "\n" }));
}

function pendenciaDeTroca(e, parado) {
  const velho = e.troca_nome || e.troca;
  return elemento("li", { class: "linha", "data-troca": e.id }, [
    elemento("span", { class: "rot troca" }, [
      elemento("span", { class: "lugar-applet" }, [icone("seta")]),
      iconeDaExtensao(e),
      elemento("span", {}, [elemento("b", { texto: e.nome }), " no lugar de " + velho]),
    ]),
    elemento("span", { class: "ctl" }, [
      botao("Trocar", { class: "bt principal pequeno", icone: "certo", disabled: parado, controle: "extensao:trocar:" + e.id,
        onclick: () => { EXT.trocou = true; return gestoDeExtensao("extensao_trocar", e, "Trocar"); } }),
      botao("Manter", { class: "bt leve pequeno", disabled: parado, controle: "extensao:manter:" + e.id,
        onclick: async () => {
          const r = await api("/api/extensao-manter", { method: "POST", body: JSON.stringify({ id: e.id }) });
          if (r.erro) { torrada(r.erro, "erro"); return; }
          EXT.mudou += 1;
          EXT.quando = 0;
          await carregarExtensoes();
        } }),
    ]),
  ]);
}

function previaDeExtensoes(lista) {
  const previa = mesaDaPagina("extensoes");
  const bandeja = previa.querySelector(".p-barra .bandeja");
  const nossos = lista.filter((e) => e.instalada && e.na_barra);
  if (bandeja && nossos.length) {
    const mini = elemento("span", { class: "applets-mini" }, nossos.map((e) => iconeDaExtensao(e)));
    bandeja.prepend(mini);
  }
  const hora = new Date().toLocaleString("pt-BR", { weekday: "short", day: "2-digit", month: "short",
    hour: "2-digit", minute: "2-digit" }).replace(/\./g, "").replace(",", "");
  const direita = nossos.map((e) => elemento("span", { class: "applet-na-barra nosso", title: e.nome }, [iconeDaExtensao(e)]));
  for (const e of lista) {
    if (e.troca) direita.push(elemento("span", { class: "applet-na-barra", title: e.troca_nome || e.troca }, [icone("grade")]));
  }
  const barra = elemento("div", { class: "barra-perto", "aria-label": "Barra de cima" }, [
    elemento("div", {}, [elemento("span", { class: "applet-na-barra", title: "Áreas de trabalho" }, [icone("janelas")])]),
    elemento("div", {}, [elemento("span", { class: "relogio", texto: hora })]),
    elemento("div", { id: "asa-direita" }, direita),
  ]);
  return [previa, barra];
}

function linhaDeBuild({ rotulo, imagem, detalhes, estado, texto, botaoRefazer }) {
  return elemento("li", { class: "linha" }, [
    elemento("span", { class: "rot" }, [
      imagem || elemento("span", { class: "lugar-applet" }, [icone("terminal")]),
      elemento("span", { class: "duas" }, [elemento("b", { texto: rotulo }),
        ...detalhes.filter(Boolean).map((d) => elemento("small", { texto: d }))]),
    ]),
    elemento("span", { class: "ctl" }, [
      elemento("span", { class: "estado-pilula", "data-estado": estado, "data-pilula": true, texto }),
      botaoRefazer,
    ]),
  ]);
}

function blocoDeBuilds(dados) {
  const b = dados.builds || {};
  const ocupado = dados.ocupado;
  const parado = !!ocupado || !!b.construindo;
  const daCasa = (dados.extensoes || []).filter((e) => !ehApplet(e));
  const linhas = [
    ...(dados.extensoes || []).filter(ehApplet).map((e) => {
      const [es, te] = pilulaDeBuild(e, ocupado);
      const onde = e.instalada ? "~/.local" : "fora do computador";
      return linhaDeBuild({
        rotulo: e.nome, imagem: iconeDaExtensao(e), estado: es, texto: te,
        detalhes: [[e.versao, e.commit].filter(Boolean).join(" · ") + " · " + onde],
        botaoRefazer: botao(e.instalada ? "Refazer" : "Compilar", { class: "bt pequeno", icone: "girar", disabled: parado,
          controle: "build:extensao:" + e.id, onclick: () => gestoDeExtensao("extensao_refazer", e, "Refazer") }),
      });
    }),
  ];
  const falhas = (dados.extensoes || []).filter((e) => e.falhou && e.registro);
  return elemento("section", { class: "bloco", "data-bloco": "Builds" }, [
    elemento("header", {}, [elemento("h2", { texto: "Builds" }),
      botao("Refazer tudo", { class: "bt pequeno", icone: "girar", disabled: parado, controle: "build:tudo",
        onclick: () => { EXT.quando = 0; rodar(ACAO.get("builds_refazer_tudo"), "", { verbo: "Refazer tudo",
          depois: depoisDoGesto }); } })]),
    daCasa.length ? elemento("div", { class: "grade-extensoes grade-builds" },
      daCasa.map((e) => cartaoDoBuildDaCasa(e, ocupado, b.construindo, b.remendos))) : null,
    elemento("ul", { class: "linhas" }, linhas),
    ...falhas.map((e) => elemento("details", { class: "registro", open: true }, [
      elemento("summary", { texto: "Registro de " + e.nome }), elemento("pre", {}, linhasDoRegistro(e.registro))])),
  ]);
}

function pilulaDeBuild(e, ocupado) {
  if (ocupado && ocupado.id === e.id) return ["correndo", "Compilando"];
  if (e.falhou) return ["erro", "Falhou"];
  if (!e.instalada) return ["neutro", "Não instalada"];
  return e.atualizacao ? ["ensaio", "Atualização"] : ["ok", "Em dia"];
}

function chaveDeBuilds(dados) {
  const ligada = !!(dados.builds && dados.builds.ao_entrar);
  const chave = elemento("button", { class: "chave", type: "button", role: "switch", "aria-checked": String(ligada),
    "aria-label": "Refazer ao entrar na sessão", controle: "build:ao-entrar" });
  chave.addEventListener("click", async () => {
    const nova = chave.getAttribute("aria-checked") !== "true";
    chave.disabled = true;
    const r = await api("/api/definir", { method: "POST", body: JSON.stringify({ chave: "BUILDS_AO_ENTRAR", valor: nova ? "sim" : "nao" }) });
    chave.disabled = false;
    if (r.erro || (typeof r.rc === "number" && r.rc > 1)) { torrada(r.erro || r.saida || "Não gravou", "erro"); return; }
    EXT.mudou += 1;
    if (EXT.dados && EXT.dados.builds) EXT.dados.builds.ao_entrar = nova;
    if (chave.isConnected) chave.setAttribute("aria-checked", String(nova));
    else if (ROTA.porta === "extensoes") render();
  });
  return elemento("section", { class: "bloco" }, [elemento("ul", { class: "linhas" }, [
    elemento("li", { class: "linha" }, [elemento("span", { class: "rot", texto: "Refazer ao entrar na sessão" }),
      elemento("span", { class: "ctl" }, [chave])])])]);
}

function abasDeExtensoes(sub) {
  $("#abas").setAttribute("aria-label", "Extensões");
  const lista = $("#abas-lista");
  if (!lista.querySelector('[data-controle^="aba:"]')) {
    lista.replaceChildren(...ABAS_EXT.map((a) => elemento("li", {}, [
      elemento("a", { href: "#extensoes/" + a.id, "data-aba": a.id, controle: "aba:" + a.id },
        [icone(a.icone), elemento("span", { texto: a.nome })]),
    ])));
    $("#abas-fila").replaceChildren(
      botao("Adicionar repositório", { class: "bt principal pequeno", icone: "mais", controle: "extensao:abrir-adicionar",
        onclick: abrirAdicionar }));
  }
  for (const a of lista.querySelectorAll("a")) {
    if (a.dataset.aba === sub) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  }
  return null;
}

function linhaDeReiniciar(parado) {
  return elemento("li", { class: "linha", "data-reiniciar": true }, [
    elemento("span", { class: "rot troca" }, [elemento("span", { class: "lugar-applet" }, [icone("girar")]),
      elemento("b", { texto: "Painel" })]),
    elemento("span", { class: "ctl" }, [
      botao("Reiniciar o painel", { class: "bt pequeno", icone: "girar", disabled: parado, controle: "extensao:reiniciar-painel",
        onclick: () => { EXT.quando = 0; return rodar(ACAO.get("extensao_reiniciar_painel"), "", { verbo: "Reiniciar o painel",
          depois: () => { EXT.trocou = false; depoisDoGesto(); } }); } }),
    ]),
  ]);
}

function corpoDeApplets(dados) {
  const lista = (dados.extensoes || []).filter(ehApplet);
  const parado = !!dados.ocupado;
  const trocas = lista.filter((e) => e.troca);
  const grade = elemento("div", { class: "grade-extensoes" }, [
    ...lista.map((e) => cartaoDeExtensao(e, dados.ocupado)),
    botao("Adicionar", { class: "cartao-novo", icone: "mais", controle: "extensao:novo", onclick: abrirAdicionar }),
  ]);
  return [
    trocas.length || EXT.trocou ? elemento("div", { class: "bloco", id: "pendencia" }, [
      elemento("ul", { class: "linhas" }, [...trocas.map((e) => pendenciaDeTroca(e, parado)), linhaDeReiniciar(parado)])]) : null,
    lista.length ? grade : elemento("div", { class: "vazio" }, [icone("grade"), elemento("p", { texto: "Nenhuma extensão no catálogo" }),
      botao("Adicionar repositório", { class: "bt principal", icone: "mais", controle: "extensao:vazio-adicionar", onclick: abrirAdicionar })]),
  ];
}

function paginaExtensoes(sub) {
  if (!EXT.pedindo && Date.now() - EXT.quando > 1500) carregarExtensoes();
  const dados = EXT.dados;
  const aba = sub === "builds" ? "builds" : "applets";
  if (!dados) {
    return [abasDeExtensoes(aba), elemento("h1", { class: "sr", texto: "Extensões" }),
      elemento("div", { class: "grade-extensoes" }, [1, 2, 3, 4].map(() => elemento("span", { class: "esqueleto", style: "height: 196px" })))];
  }
  if (dados.erro) {
    return [abasDeExtensoes(aba), elemento("div", { class: "vazio" }, [icone("alerta"), elemento("p", { texto: dados.erro })])];
  }
  const corpo = aba === "builds" ? [blocoDeBuilds(dados), chaveDeBuilds(dados)] : corpoDeApplets(dados);
  return [
    abasDeExtensoes(aba),
    elemento("h1", { class: "sr", texto: "Extensões" }),
    elemento("div", { class: "oficina extensoes" }, [
      elemento("div", { class: "palco" }, previaDeExtensoes((dados.extensoes || []).filter(ehApplet))),
      elemento("div", { class: "pilha", id: "miolo" }, [elemento("section", { class: "pilha", "data-aba-corpo": aba }, corpo.filter(Boolean))]),
    ]),
  ];
}

function nomeDoRepositorio(url) {
  const m = /^https:\/\/[^/]+\/(.+?)(?:\.git)?\/?$/.exec(url || "");
  return m ? m[1] : url || "";
}

let ADICIONAR = null;

function dialogoAdicionar() {
  let d = document.getElementById("adicionar");
  if (d) return d;
  const campo = elemento("input", { class: "campo", id: "repo-url", type: "url", spellcheck: "false",
    placeholder: "https://github.com/…", controle: "adicionar:url", autocomplete: "off" });
  const ficha = elemento("div", { class: "ficha-repo p-ficha" }, [
    elemento("span", { class: "lugar-applet" }, [icone("grade")]),
    elemento("div", {}, [elemento("b", { id: "ficha-nome" }), elemento("dl", {}, [
      elemento("dt", { texto: "Repositório" }), elemento("dd", { id: "ficha-repo" }),
      elemento("dt", { texto: "Commit" }), elemento("dd", { id: "ficha-commit" }),
      elemento("dt", { texto: "Substitui" }), elemento("dd", { id: "ficha-substitui" }),
    ])]),
  ]);
  const pre = elemento("pre", { id: "adicionar-saida", tabindex: "0", "aria-live": "polite" });
  d = elemento("dialog", { id: "adicionar", "aria-labelledby": "adicionar-t", "data-passo": "url" }, [
    elemento("div", { class: "dentro" }, [
      elemento("h2", { id: "adicionar-t", texto: "Adicionar repositório" }),
      elemento("label", { class: "pilha-campo p-url" }, [elemento("span", { texto: "Endereço" }), campo]),
      elemento("p", { class: "oficina-erro p-erro-url", id: "adicionar-queixa", role: "alert" }),
      ficha,
      elemento("span", { class: "selo p-ficha", texto: "baixa e compila" }),
      elemento("span", { class: "estado-pilula p-compilando", "data-estado": "correndo", texto: "Compilando" }),
      elemento("span", { class: "estado-pilula p-erro", "data-estado": "erro", texto: "Não compilou" }),
      elemento("span", { class: "estado-pilula p-pronto", "data-estado": "ok", texto: "Instalada, fora da barra" }),
      elemento("details", { class: "registro p-compilando p-erro", open: true }, [elemento("summary", { texto: "Registro" }), pre]),
      elemento("div", { class: "acoes" }, [
        elemento("button", { class: "bt leve", type: "button", controle: "adicionar:cancelar", texto: "Cancelar",
          onclick: () => d.close() }),
        botao("Ler", { class: "bt principal p-url", id: "adicionar-ler", controle: "adicionar:ler", onclick: lerRepositorio }),
        botao("Instalar", { class: "bt principal p-ficha", id: "adicionar-instalar", icone: "baixar", controle: "adicionar:instalar",
          onclick: instalarRepositorio }),
        botao("Parar", { class: "bt p-compilando", id: "adicionar-parar", controle: "adicionar:parar", onclick: pararRepositorio }),
        botao("Tentar de novo", { class: "bt principal p-erro", id: "adicionar-de-novo", icone: "girar", controle: "adicionar:de-novo",
          onclick: () => rodarRepositorio() }),
        botao("OK", { class: "bt principal p-pronto", id: "adicionar-ok", controle: "adicionar:ok", onclick: () => d.close() }),
      ]),
    ]),
  ]);
  campo.addEventListener("keydown", (ev) => { if (ev.key === "Enter") { ev.preventDefault(); lerRepositorio(); } });
  campo.addEventListener("input", () => { if (d.dataset.passo === "erro-url") d.dataset.passo = "url"; });
  d.addEventListener("cancel", (ev) => { if (d.dataset.passo === "compilando") ev.preventDefault(); });
  d.addEventListener("close", () => { if (ADICIONAR && ADICIONAR.timer) clearInterval(ADICIONAR.timer); carregarExtensoes(); });
  document.body.append(d);
  return d;
}

function abrirAdicionar() {
  const d = dialogoAdicionar();
  ADICIONAR = { ficha: null, timer: null, trabalho: null };
  $("#repo-url").value = "";
  $("#adicionar-saida").replaceChildren();
  d.dataset.passo = "url";
  if (!d.open) d.showModal();
  $("#repo-url").focus();
}

async function lerRepositorio() {
  const d = $("#adicionar");
  const url = $("#repo-url").value.trim();
  const queixa = (texto) => { $("#adicionar-queixa").textContent = maiuscula(texto); d.dataset.passo = "erro-url"; };
  if (!/^https:\/\/\S+$/.test(url)) { queixa("Só endereço https"); return; }
  const b = $("#adicionar-ler");
  b.dataset.estado = "carregando";
  const r = await api("/api/extensao-ler", { method: "POST", body: JSON.stringify({ url }) });
  delete b.dataset.estado;
  if (r.erro) { queixa(r.erro); return; }
  const f = r.ficha;
  ADICIONAR.ficha = f;
  $("#ficha-nome").textContent = f.nome || f.id;
  $("#ficha-repo").textContent = nomeDoRepositorio(f.url || url);
  $("#ficha-commit").textContent = [String(f.commit || "").slice(0, 7), f.data].filter(Boolean).join(" · ");
  $("#ficha-substitui").textContent = f.substitui || "nada";
  d.dataset.passo = "ficha";
}

async function instalarRepositorio() {
  const f = ADICIONAR && ADICIONAR.ficha;
  if (!f) return;
  const b = $("#adicionar-instalar");
  b.dataset.estado = "carregando";
  const r = await api("/api/extensao-adicionar", { method: "POST", body: JSON.stringify({ id: f.id }) });
  delete b.dataset.estado;
  if (r.erro) { falharRepositorio(r.erro); return; }
  await rodarRepositorio();
}

function falharRepositorio(texto) {
  $("#adicionar-saida").append(elemento("span", { class: "erro", texto: maiuscula(texto) + "\n" }));
  $("#adicionar").dataset.passo = "erro";
}

async function rodarRepositorio() {
  const f = ADICIONAR && ADICIONAR.ficha;
  if (!f) return;
  const d = $("#adicionar");
  $("#adicionar-saida").replaceChildren();
  d.dataset.passo = "compilando";
  const r = await api("/api/rodar", { method: "POST", body: JSON.stringify({
    acao: "extensao_instalar_repo", argumento: f.id, confirmado: true }) });
  if (r.erro) { falharRepositorio(r.erro); return; }
  ADICIONAR.trabalho = { id: r.id, proximo: 0 };
  ADICIONAR.timer = setInterval(puxarRepositorio, 500);
  puxarRepositorio();
}

async function puxarRepositorio() {
  const t = ADICIONAR && ADICIONAR.trabalho;
  if (!t || t.puxando) return;
  t.puxando = true;
  const r = await api(`/api/trabalho?id=${t.id}&desde=${t.proximo}`);
  t.puxando = false;
  if (ADICIONAR.trabalho !== t) return;
  if (r.erro) { clearInterval(ADICIONAR.timer); falharRepositorio(r.erro); return; }
  t.proximo = r.proximo;
  const saida = $("#adicionar-saida");
  for (const l of r.linhas || []) saida.append(elemento("span", { class: classeDaLinha(l) || null, texto: l + "\n" }));
  saida.scrollTop = saida.scrollHeight;
  if (r.vivo) return;
  clearInterval(ADICIONAR.timer);
  ADICIONAR.timer = null;
  $("#adicionar").dataset.passo = r.rc === 0 || r.rc === 1 ? "pronto" : "erro";
  EXT.quando = 0;
  carregarExtensoes();
}

async function pararRepositorio() {
  const t = ADICIONAR && ADICIONAR.trabalho;
  if (t) await api("/api/parar", { method: "POST", body: JSON.stringify({ id: t.id }) });
}

async function abrirCreditos() {
  let d = document.getElementById("creditos");
  if (!d) {
    d = elemento("dialog", { id: "creditos", "aria-labelledby": "creditos-t" }, [
      elemento("div", { class: "dentro" }, [
        elemento("h2", { id: "creditos-t", texto: "MeowSystem" }),
        elemento("ul", { class: "creditos" }, AUTORES.map((a) =>
          elemento("li", {}, [elemento("b", { texto: a.nome }), elemento("span", { texto: a.papel })]))),
        elemento("a", { class: "versao", href: REPOSITORIO_DA_CASA, target: "_blank", rel: "noopener",
          controle: "creditos:repositorio", texto: REPOSITORIO_DA_CASA }),
        elemento("ul", { class: "creditos upstreams", id: "creditos-upstreams" }),
        elemento("div", { class: "acoes" }, [
          botao("OK", { class: "bt principal", controle: "creditos:ok", onclick: () => d.close() })]),
      ]),
    ]);
    document.body.append(d);
  }
  d.showModal();
  if (!EXT.dados) {
    const r = await api("/api/extensoes");
    if (!r.erro) EXT.dados = r;
  }
  const origens = ((EXT.dados && EXT.dados.extensoes) || []).filter((e) => e.casa && e.upstream);
  $("#creditos-upstreams").replaceChildren(...origens.map((e) => elemento("li", {}, [
    elemento("b", { texto: e.nome }),
    elemento("a", { class: "versao", href: e.upstream, target: "_blank", rel: "noopener",
      controle: "creditos:upstream:" + e.id, texto: nomeDoRepositorio(e.upstream) })])));
}

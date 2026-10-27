"use strict";

let PROVISORIO = null;
function valeNaPrevia(chave) {
  if (PROVISORIO && PROVISORIO.chave === chave) return PROVISORIO.valor;
  return vale(chave);
}
function urlDoGato(nome) {
  const g = previasDe("gato");
  const i = g && g.itens.find((x) => x.id === nome);
  return i && i.pronta ? i.url : "/gato.svg";
}
function paredeDaPrevia() {
  const p = previasDe("parede", "ativos");
  const i = p && p.itens.find((x) => x.pronta);
  return i ? i.url : "";
}
const REGIAO = [
  [/^(FORMA_.*PAINEL|VIDRO_OPACIDADE_PAINEL|VIDRO_AO_MAXIMIZAR|MIDIA|RELOGIO)/, "painel"],
  [/^(FORMA_.*DOCK|VIDRO_OPACIDADE_DOCK|LOGO)/, "dock"],
  [/^(TERMINAL_|PROMPT_|FASTFETCH_)/, "term"],
  [/^(ICONES_|PASTAS_)/, "arq"],
];
function mesaDaPagina(pagina = "") {
  const marca = new Set();
  for (const c of MUDANCAS.keys()) for (const [re, r] of REGIAO) if (re.test(c)) marca.add(r);
  const gato = ESQUEMA.gato_no_dock || vale("LOGO");
  const ff = (pagina === "mascote" || pagina === "terminal") && ligado(valeNaPrevia("FASTFETCH_LOGO"))
    ? urlDoGato(valeNaPrevia("FASTFETCH_LOGO_GATO") || gato) : null;
  return MESA.mesa({
    val: valeNaPrevia, marca, gato: urlDoGato(gato), ff, parede: paredeDaPrevia(),
    ajuste: valeNaPrevia("WALLPAPER_AJUSTE"),
    quente: pagina === "dia-e-noite" && ligado(valeNaPrevia("LEITURA_AGENDA")) ? valeNaPrevia("LEITURA_TEMPERATURA") : 0,
    rotulo: "Prévia",
  });
}
function repintarPrevia(chave, valor) {
  PROVISORIO = { chave, valor };
  const velha = $("#conteudo .palco .previa");
  if (velha) velha.replaceWith(mesaDaPagina(ROTA.sub));
  PROVISORIO = null;
}

function cabeca(titulo, direita = []) {
  return elemento("div", { class: "cabeca" }, [
    elemento("h1", { texto: titulo }),
    direita.length ? elemento("div", { class: "fila" }, direita) : null,
  ]);
}

function estadoDaMaquina() {
  const n = PENDENCIAS.length + PRECISA_DE_GENTE.length;
  if (!ESQUEMA.ponte) return { bom: false, titulo: "Falta a ponte", icone: "alerta" };
  if (n) return { bom: false, titulo: n === 1 ? "1 pendência" : `${n} pendências`, icone: "alerta" };
  return { bom: true, titulo: "Tudo em ordem", icone: "certo" };
}

function coresDoFlavor(p, flavorId) {
  const f = (p.flavors || []).find((x) => x.id === flavorId);
  return (f && f.cores) || p.amostra || [];
}
function amostraDeVariante(cores) {
  const ordem = ESQUEMA.paleta.ordem || [];
  const de = (n) => cores[ordem.indexOf(n)] || "";
  const i = elemento("i");
  i.style.setProperty("--a", de("base"));
  i.style.setProperty("--b", de("mauve"));
  i.style.setProperty("--c", de("green"));
  return i;
}

async function vestir(p, flavorId) {
  if (p.no_ar) {
    if (flavorId && flavorId !== flavorEmVigor()) await salvarEscolhas({ FLAVOR: flavorId });
    return;
  }
  await rodar(ACAO.get("pack_usar"), p.id, {
    semPerguntar: true,
    depois: () => {
      const f = CHAVE.get("FLAVOR");
      if (flavorId && f && flavorId !== (f.valor || "")) salvarEscolhas({ FLAVOR: flavorId });
    },
  });
}

function cartaoDePack(p) {
  const ordem = ESQUEMA.paleta.ordem || [];
  const flavor = p.no_ar ? flavorEmVigor() : ((p.flavors || []).find((f) => !f.claro) || (p.flavors || [])[0] || {}).id;
  const previa = MESA.mesa({
    cores: MESA.estiloDeCores(coresDoFlavor(p, flavor), ordem, p.no_ar ? vale("ACCENT") : "mauve"),
    gato: p.no_ar || !p.mascote ? urlDoGato(ESQUEMA.gato_no_dock || vale("LOGO")) : p.mascote,
    rotulo: "Prévia do " + p.nome,
    sem: new Set(p.no_ar ? [] : ["musica"]),
  });
  previa.dataset.controle = "pack:" + p.id + ":previa";
  previa.tabIndex = -1;
  previa.addEventListener("click", () => vestir(p, p.no_ar ? null : flavor));
  const direita = [];
  if (p.no_ar) {
    direita.push(elemento("span", { class: "estado-no-ar", role: "img", "aria-label": "No ar", dica: "No ar" }, [icone("certo")]));
  } else {
    direita.push(botao("Vestir", { class: "bt principal", controle: "pack:" + p.id + ":vestir",
      dica: primeiraFrase((ACAO.get("pack_usar") || {}).ajuda), onclick: () => vestir(p, flavor) }));
  }
  if (p.remover && !p.remover.motivo) {
    direita.push(botao("", { class: "bt so-icone", icone: "lixo", "aria-label": "Remover", dica: "Remover",
      controle: "pack:" + p.id + ":remover",
      onclick: () => rodar(ACAO.get("pack_remover"), p.id, { verbo: "Remover" }) }));
  }
  const variantes = elemento("div", { class: "variantes", role: "group", "aria-label": "Variantes do " + p.nome });
  for (const f of p.flavors || []) {
    const derivado = f.derivado || (p.claros_derivados || []).includes(f.id);
    variantes.append(elemento("button", {
      type: "button", controle: "pack:" + p.id + ":variante=" + f.id, dica: derivado ? "Claro derivado" : null,
      "aria-pressed": String(!!p.no_ar && f.id === flavorEmVigor()),
      onclick: () => vestir(p, f.id),
    }, [amostraDeVariante(f.cores || []), maiuscula(f.nome)]));
  }
  return elemento("article", { class: "pack" + (p.no_ar ? " no-ar" : ""), "data-pack": p.id }, [
    previa,
    elemento("div", { class: "pack-corpo" }, [
      p.capa ? elemento("img", { class: "logo", src: p.capa, alt: "" }) : elemento("span"),
      elemento("h2", { texto: p.nome }),
      elemento("div", { class: "fila" }, direita),
      variantes,
    ]),
  ]);
}

async function importarPack(arquivo) {
  if (!arquivo) return;
  let pedido;
  try { pedido = { nome: arquivo.name, conteudo: await lerComoBase64(arquivo) }; }
  catch (e) { torrada(String(e.message || e), "erro"); return; }
  let r = await api("/api/pack-importar", { method: "POST", body: JSON.stringify(pedido) });
  if (r.precisa_confirmar) {
    const tira = elemento("div", { class: "vinte-seis", style: "padding:0" });
    for (const c of ((r.pack && r.pack.paleta && Object.values(r.pack.paleta)[0]) || []).slice(0, 26)) {
      const i = elemento("i"); i.style.setProperty("--c", c); tira.append(i);
    }
    if (!await perguntar({ titulo: r.titulo || "Abrir este tema?", ok: "Abrir", corpo: tira })) return;
    r = await api("/api/pack-importar", { method: "POST", body: JSON.stringify({ ...pedido, confirmado: true }) });
  }
  if (r.erro || !r.instalado) { torrada(r.erro || "Não abriu", "erro"); return; }
  torrada(`${(r.pack && r.pack.nome) || arquivo.name}: entrou`, "ok");
  await Promise.all([recarregarPacks(), recarregarEsquema()]);
  render();
}
function botaoAbrirTema() {
  const campo = elemento("input", { type: "file", accept: ".meowpack,.csv", hidden: true });
  campo.addEventListener("change", () => { const a = campo.files && campo.files[0]; campo.value = ""; importarPack(a); });
  return elemento("span", { style: "display:contents" }, [
    botao("Abrir um tema", { class: "bt", icone: "subir", controle: "tema:abrir",
      dica: "Um .meowpack ou um .csv de cores", onclick: () => campo.click() }),
    campo,
  ]);
}
function pilulaDeSaude() {
  const e = estadoDaMaquina();
  return elemento("a", { href: "#cuidar", class: "saude" + (e.bom ? "" : " alerta"), controle: "tema:saude" },
    [icone(e.icone), e.titulo]);
}

function paginaTema() {
  const grade = elemento("div", { class: "grade-tema" });
  const packs = PACKS.length ? PACKS : [];
  for (const p of packs) {
    const c = cartaoDePack(p);
    c.style.gridColumn = "span 2";
    grade.append(c);
  }
  const ACCENT = CHAVE.get("ACCENT");
  const MODO = CHAVE.get("MODO");
  const imediato = (chave) => (v) => {
    if (String(v) === String(CHAVE.get(chave).valor || "")) return;
    MUDANCAS.delete(chave);
    salvarEscolhas({ [chave]: v });
  };
  if (ACCENT) {
    const b = bloco("Cor de destaque", [elemento("div", { class: "corpo" }, [controleCor(ACCENT, imediato("ACCENT"), true)])]);
    b.dataset.linha = "ACCENT";
    b.style.gridColumn = "span 2";
    grade.append(b);
  }
  if (MODO) {
    const seg = elemento("div", { class: "seg", role: "group", "aria-label": "Claro ou escuro" });
    const valor = vale("MODO");
    for (const op of MODO.opcoes) {
      seg.append(elemento("button", { type: "button", "aria-pressed": String(op === valor),
        controle: "chave:MODO=" + op, texto: rotuloDeValor(op, MODO), onclick: () => imediato("MODO")(op) }));
    }
    const b = bloco("Claro ou escuro", [elemento("div", { class: "corpo" }, [seg])]);
    b.dataset.linha = "MODO";
    grade.append(b);
  }
  grade.append(elemento("a", { class: "criar-meu", href: "#criar/cores", controle: "tema:criar" },
    [icone("mais"), elemento("span", { texto: "Criar o meu" })]));
  const mais = maisAjustes("tema:tema", LUGAR_TEMA.mais);
  if (mais) grade.append(mais);
  return [cabeca("Tema", [pilulaDeSaude(), botaoAbrirTema()]), grade];
}

const SEIS = [
  ["base", "Fundo"], ["mantle", "Barras"], ["text", "Texto"],
  ["mauve", "Destaque"], ["green", "Deu certo"], ["red", "Deu errado"],
];
let RASCUNHO = null;
function rascunho() {
  if (RASCUNHO) return RASCUNHO;
  try { RASCUNHO = JSON.parse(localStorage.getItem("meow-criar") || "null"); } catch (e) { RASCUNHO = null; }
  if (!RASCUNHO || !RASCUNHO.base) {
    const p = packNoAr() || PACKS[0] || { id: "", flavors: [] };
    RASCUNHO = { nome: "Meu tema", base: { pack: p.id, flavor: flavorEmVigor() }, cores: {}, pack: "" };
  }
  return RASCUNHO;
}
function guardarRascunho() {
  try { localStorage.setItem("meow-criar", JSON.stringify(RASCUNHO)); } catch (e) { }
}
function vinteSeis() {
  const r = rascunho();
  const p = PACKS.find((x) => x.id === r.base.pack) || packNoAr() || PACKS[0] || { flavors: [] };
  const cores = coresDoFlavor(p, r.base.flavor);
  const ordem = ESQUEMA.paleta.ordem || [];
  const mapa = Object.fromEntries(ordem.map((n, i) => [n, cores[i] || "#000000"]));
  for (const [n, v] of Object.entries(r.cores || {})) mapa[n] = v;
  if (r.cores && r.cores.mantle && !r.cores.crust) mapa.crust = r.cores.mantle;
  return mapa;
}
function luz(hex) {
  const x = parseInt(String(hex).slice(1), 16);
  const c = [(x >> 16) & 255, (x >> 8) & 255, x & 255].map((v) => {
    v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}
function contraste(a, b) {
  const x = luz(a), y = luz(b);
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}
function idDoNome(nome) {
  return String(nome || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "meu-tema";
}

async function guardarTema() {
  const r = rascunho();
  const id = idDoNome(r.nome);
  const flavor = id.replace(/[^a-z0-9]/g, "") || "meu";
  const mapa = vinteSeis();
  const linhas = ["slot,flavor,hex", ...(ESQUEMA.paleta.ordem || []).map((n) => `${n},${flavor},${String(mapa[n]).toUpperCase()}`)];
  const conteudo = btoa(unescape(encodeURIComponent(linhas.join("\n") + "\n")));
  const b = document.querySelector('[data-controle="criar:guardar"]');
  if (b) b.dataset.estado = "carregando";
  const resp = await api("/api/pack-importar", { method: "POST",
    body: JSON.stringify({ nome: id + ".csv", nome_do_tema: r.nome, conteudo, confirmado: true }) });
  if (b) delete b.dataset.estado;
  if (resp.erro || !resp.instalado) {
    torrada(/contraste/.test(resp.erro || "") ? "Pouco contraste entre texto e fundo" : primeiraFrase(resp.erro || "Não guardou"), "erro");
    return;
  }
  r.pack = resp.id || id;
  guardarRascunho();
  const sons = await api("/api/criar", { method: "POST",
    body: JSON.stringify({ id: r.pack, tipo: "sons", de: r.base.pack, levar: true }) });
  if (sons.erro) torrada(maiuscula(primeiraFrase(sons.erro)), "erro");
  torrada(`${r.nome}: guardado`, "ok");
  await recarregarPacks();
  render();
}

async function exportarPack(id) {
  const rota = `/api/pack-exportar?id=${encodeURIComponent(id)}`;
  const m = await api(rota + "&medir=1");
  if (m.erro) { torrada(m.erro, "erro"); return; }
  const avisos = (m.avisos || []).map((a) => maiuscula(a));
  let semImagens = false;
  if (m.imagens || avisos.length) {
    const levar = elemento("input", { type: "checkbox", checked: true, "aria-label": "Imagens", controle: "exportar:imagens" });
    const corpo = elemento("div", { class: "pilha", style: "gap:8px" }, [
      ...avisos.map((a) => elemento("div", { class: "fila" }, [icone("alerta"), elemento("span", { texto: a })])),
      m.imagens ? elemento("label", { class: "fila", dica: `${m.tamanho} · ${m.tamanho_sem_imagens} sem as imagens` },
        [levar, elemento("span", { texto: "Imagens" })]) : null,
    ]);
    if (!await perguntar({ titulo: `Baixar o ${id}?`, ok: "Baixar", corpo })) return;
    semImagens = !!m.imagens && !levar.checked;
  }
  let resposta;
  try { resposta = await fetch(rota + (semImagens ? "&imagens=nao" : ""), { headers: { "X-Meow-Token": TOKEN } }); }
  catch { faixaSemServidor(true); return; }
  if (!resposta.ok) {
    let erro = "";
    try { erro = (await resposta.json()).erro || ""; } catch { }
    torrada(erro || `HTTP ${resposta.status}`, "erro");
    return;
  }
  const nome = (/filename="([^"]+)"/.exec(resposta.headers.get("Content-Disposition") || "") || [])[1] || `${id}.meowpack`;
  const url = URL.createObjectURL(await resposta.blob());
  elemento("a", { href: url, download: nome }).click();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
  torrada(`${nome}: baixado`, "ok");
}

function tocarSino() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const f1 = Number(vale("SOM_FUNDAMENTAL")) || 784, f2 = Number(vale("SOM_HARMONICO")) || 1176;
    const p1 = Number(vale("SOM_PESO_FUNDAMENTAL")) || 0.58, p2 = Number(vale("SOM_PESO_HARMONICO")) || 0.32;
    const d = Number(vale("SOM_DECAIMENTO")) || 40;
    const dur = Math.max(0.15, Math.min(2.5, 60 / d));
    for (const [f, p] of [[f1, p1], [f2, p2]]) {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.frequency.value = f;
      g.gain.setValueAtTime(p * 0.4, ctx.currentTime);
      g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + dur);
      o.connect(g).connect(ctx.destination);
      o.start();
      o.stop(ctx.currentTime + dur);
    }
  } catch (e) { }
}

function passoCores() {
  const r = rascunho();
  const mapa = vinteSeis();
  const comeca = elemento("div", { class: "comeca", role: "group", "aria-label": "Começar de" });
  for (const p of PACKS) {
    for (const f of p.flavors || []) {
      comeca.append(elemento("button", {
        type: "button", controle: "criar:comeca=" + p.id + ":" + f.id,
        "aria-pressed": String(r.base.pack === p.id && r.base.flavor === f.id),
        onclick: () => { r.base = { pack: p.id, flavor: f.id }; r.cores = {}; guardarRascunho(); render(); },
      }, [amostraDeVariante(f.cores || []), maiuscula(f.nome)]));
    }
  }
  const pocos = elemento("div");
  for (const [slot, nome] of SEIS) {
    const hex = String(mapa[slot] || "#000000").toUpperCase();
    const entrada = elemento("input", { type: "color", value: hex.toLowerCase(), "aria-label": nome,
      controle: "criar:cor=" + slot });
    entrada.addEventListener("change", () => { r.cores[slot] = entrada.value.toUpperCase(); guardarRascunho(); render(); });
    const rotulo = elemento("label", {}, [entrada]);
    rotulo.style.setProperty("--cor", hex);
    let medida = null;
    if (["text", "mauve", "green", "red"].includes(slot)) {
      const c = contraste(hex, mapa.base);
      const bom = c >= 4.5;
      medida = elemento("span", { class: "contraste" + (bom ? "" : " ruim"), dica: "Contraste com o fundo" },
        [icone(bom ? "certo" : "alerta"), c.toFixed(1).replace(".", ",") + ":1"]);
    }
    pocos.append(elemento("div", { class: "poco" }, [
      rotulo, elemento("div", {}, [elemento("b", { texto: nome }), elemento("code", { texto: hex })]), medida,
    ]));
  }
  const tira = elemento("div", { class: "vinte-seis", role: "img", "aria-label": "As 26 cores" });
  for (const n of ESQUEMA.paleta.ordem || []) { const i = elemento("i", { dica: maiuscula(n) }); i.style.setProperty("--c", mapa[n]); tira.append(i); }
  return [
    bloco("Começar de", [elemento("div", { class: "corpo" }, [comeca])]),
    bloco("Cores", [pocos, tira]),
  ];
}
let ABA_ICONES = "apps";
let LIMITE_ICONES = 48;
function gradeDeLevar(pasta, pack) {
  const itens = (LEVA && !LEVA.carregando && LEVA[pasta]) || [];
  const sem = pack ? "" : "Guarde o tema em Cores";
  const grade = elemento("div", { class: "grade-apps levar", "aria-busy": LEVA && !LEVA.carregando ? null : "true" });
  for (const i of itens.slice(0, LIMITE_ICONES)) {
    grade.append(elemento("button", {
      type: "button", class: "app", controle: "levar:" + pasta, "aria-pressed": String(!!i.levado),
      disabled: !!sem, "aria-disabled": sem ? "true" : null,
      dica: sem || `${i.levado ? "Tirar do tema" : "Levar para o tema"} · ${maiuscula(i.de)}`,
      onclick: () => levarParaOTema(pasta, i.nome, !i.levado, { de: i.de }),
    }, [elemento("img", { src: i.url, alt: "", loading: "lazy" }), elemento("span", { class: "nome", texto: i.nome })]));
  }
  const filhos = [grade];
  if (itens.length > LIMITE_ICONES) {
    filhos.push(botao("Mais ícones", { class: "bt", controle: "levar:mais", onclick: () => { LIMITE_ICONES += 96; render(); } }));
  }
  return elemento("div", { class: "pilha", style: "gap:16px" }, filhos);
}
function passoIcones() {
  const p = PASSOS.find((x) => x.id === "icones");
  const pack = packDoRascunho();
  const abas = [["apps", "Aplicativos"], ["sistema", "Sistema"], ["biblioteca", "Biblioteca"]]
    .filter(([id]) => id === "apps" || !LEVA || LEVA.carregando || (LEVA[id] || []).length);
  if (!abas.some(([id]) => id === ABA_ICONES)) ABA_ICONES = "apps";
  const seg = elemento("div", { class: "seg", role: "group", "aria-label": "Pasta de ícones" },
    abas.map(([id, nome]) => elemento("button", { type: "button", "aria-pressed": String(id === ABA_ICONES),
      controle: "icones:aba=" + id, onclick: () => { ABA_ICONES = id; LIMITE_ICONES = 48; render(); } }, [nome])));
  const cabeca = elemento("div", { class: "fila abas-icones" }, [seg]);
  if (ABA_ICONES !== "apps") {
    const nome = ABA_ICONES === "sistema" ? "Sistema" : "Biblioteca";
    return [cabeca, bloco(nome, [elemento("div", { class: "corpo" }, [gradeDeLevar(ABA_ICONES, pack)])])];
  }
  const linhas = lista(p.linhas, (l) => l.g === "acervo:icone");
  return [
    cabeca,
    bloco("Aplicativos", [elemento("div", { class: "corpo" }, [montarApps()])],
      { direita: [botaoAcervo("icone", "Trazer .svg")] }),
    bloco("Pastas", [linhas]),
    maisAjustes("criar:icones", p.mais, [oficinaAutoral()].filter(Boolean)),
  ];
}
let LEVA = null;
async function carregarLeva(id) {
  LEVA = { id, carregando: true, fotos: [] };
  const r = await api(`/api/criar?id=${encodeURIComponent(id)}`);
  LEVA = r.erro ? { id, fotos: [] } : { ...r, id };
  render();
}
function packDoRascunho() {
  const r = rascunho();
  const pack = (r.pack && PACKS.find((x) => x.id === r.pack)) || null;
  const id = pack ? pack.id : "";
  if (!LEVA || LEVA.id !== id) carregarLeva(id);
  return pack;
}
async function levarParaOTema(tipo, nome, levar, extra = {}) {
  const id = rascunho().pack;
  const r = await api("/api/criar", { method: "POST", body: JSON.stringify({ id, tipo, nome, levar, ...extra }) });
  if (r.erro) { torrada(maiuscula(primeiraFrase(r.erro)), "erro"); return; }
  await carregarLeva(id);
}
function passoPapel() {
  const pack = packDoRascunho();
  const pronto = pack && LEVA && !LEVA.carregando;
  const leva = { sem: pack ? (pronto ? "" : "Carregando") : "Guarde o tema em Cores",
    no: (nome) => !!pronto && (LEVA.fotos || []).includes(nome),
    levar: (nome, sim) => levarParaOTema("foto", nome, sim) };
  return [bloco("Papel de parede", [elemento("div", { class: "corpo" }, [montarGaleria(leva)])],
    { direita: [botaoAcervo("parede", "Trazer imagens")] })];
}
const NOMES_DE_SOM = {
  "message-new-instant": "Mensagem nova", complete: "Tarefa pronta", "device-added": "Pendrive entrou",
  "battery-low": "Bateria fraca", "screen-capture": "Captura de tela", "desktop-screen-lock": "Tela bloqueada",
  "message-new-email": "E-mail novo", message: "Mensagem", "device-removed": "Pendrive saiu",
  "battery-caution": "Bateria baixa", "battery-full": "Bateria cheia", "power-plug": "Na tomada",
  "power-unplug": "Fora da tomada", "power-unplug-battery-low": "Bateria acabando",
  "alarm-clock-elapsed": "Despertador", "software-update-urgent": "Atualização urgente",
  "system-ready": "Sistema pronto", "system-shutdown": "Desligando", "theme-demo": "Amostra do tema",
  "window-attention-inactive": "Janela pedindo atenção", bell: "Sino", "camera-focus": "Foco da câmera",
  "camera-shutter": "Foto tirada", "count-down": "Contagem",
};
const ORDEM_DE_SOM = Object.keys(NOMES_DE_SOM);
function nomeDoSom(evento) { return NOMES_DE_SOM[evento] || maiuscula(evento.replace(/-/g, " ")); }
let SOM_TOCANDO = null;
function ouvirSom(pack, evento, b) {
  if (SOM_TOCANDO) SOM_TOCANDO.pause();
  for (const x of document.querySelectorAll(".sons [data-tocando]")) delete x.dataset.tocando;
  const audio = new Audio(`/som?pack=${encodeURIComponent(pack)}&evento=${encodeURIComponent(evento)}`);
  SOM_TOCANDO = audio;
  b.dataset.tocando = "";
  audio.addEventListener("ended", () => { delete b.dataset.tocando; });
  audio.play().catch(() => { delete b.dataset.tocando; });
}
function trocarSom(evento) {
  const campo = elemento("input", { type: "file", accept: ".oga,.ogg,audio/ogg", hidden: true });
  campo.addEventListener("change", async () => {
    const arq = campo.files && campo.files[0];
    if (!arq) return;
    await levarParaOTema("som", evento, true, { arquivo: arq.name, conteudo: await lerComoBase64(arq) });
    torrada(`${nomeDoSom(evento)}: trocado`, "ok");
  });
  return campo;
}
function sonsDeAviso() {
  const pack = packDoRascunho();
  const sons = pack && LEVA && !LEVA.carregando ? (LEVA.sons || []) : [];
  if (!sons.length) return null;
  const ordem = (e) => { const i = ORDEM_DE_SOM.indexOf(e); return i < 0 ? ORDEM_DE_SOM.length : i; };
  const ul = elemento("ul", { class: "sons" });
  for (const s of [...sons].sort((a, b) => ordem(a.evento) - ordem(b.evento))) {
    const nome = nomeDoSom(s.evento);
    const campo = trocarSom(s.evento);
    const tocar = elemento("button", { type: "button", class: "p", "aria-label": "Ouvir " + nome.toLowerCase(),
      dica: "Ouvir", controle: "som:ouvir" }, [icone("tocar")]);
    tocar.addEventListener("click", () => ouvirSom(pack.id, s.evento, tocar));
    ul.append(elemento("li", { "data-som": s.evento }, [
      tocar, elemento("span", { texto: nome }),
      botao("Trocar", { class: "bt pequeno", controle: "som:trocar", dica: "Um .oga no lugar deste",
        onclick: () => campo.click() }), campo,
    ]));
  }
  return bloco("Sons de aviso", [ul]);
}
function passoSons() {
  const p = PASSOS.find((x) => x.id === "sons");
  const sino = elemento("div", { class: "sino" }, [
    elemento("button", { type: "button", class: "tocar", "aria-label": "Tocar o sino", dica: "Tocar o sino",
      controle: "criar:sino", onclick: tocarSino }, [icone("tocar")]),
    elemento("h2", { texto: "Sino do volume" }),
  ]);
  return [bloco(null, [sino, lista(p.linhas)]), sonsDeAviso(), maisAjustes("criar:sons", p.mais)];
}
function passoMandar() {
  const r = rascunho();
  const pack = r.pack && PACKS.find((x) => x.id === r.pack);
  const sem = !pack;
  return [bloco(pack ? pack.nome : r.nome, [
    elemento("div", { class: "corpo fila" }, [
      botao("Baixar o tema", { class: "bt principal", icone: "baixar", controle: "criar:baixar",
        disabled: sem, "aria-disabled": sem ? "true" : null, dica: sem ? "Guarde o tema em Cores" : "Um .meowpack para mandar",
        onclick: () => exportarPack(r.pack) }),
      botao("Vestir", { class: "bt", icone: "tema", controle: "criar:vestir",
        disabled: sem, "aria-disabled": sem ? "true" : null, dica: sem ? "Guarde o tema em Cores" : null,
        onclick: () => vestir(pack, null) }),
    ]),
  ])];
}

function paginaCriar(sub) {
  const r = rascunho();
  const i = PASSOS.findIndex((p) => p.id === sub);
  const nome = elemento("input", { class: "nome-tema", value: r.nome, "aria-label": "Nome do tema",
    controle: "criar:nome", maxlength: "48" });
  nome.addEventListener("change", () => { r.nome = maiuscula(nome.value.trim()) || "Meu tema"; guardarRascunho(); render(); });
  const passos = elemento("ol", { class: "passos" }, PASSOS.map((p, j) => elemento("li", {}, [
    elemento("a", { href: "#criar/" + p.id, controle: "passo:" + p.id, "aria-current": j === i ? "step" : null },
      [elemento("b", {}, [j < i ? icone("certo") : String(j + 1)]), p.nome]),
  ])));
  const corpo = sub === "icones" ? passoIcones() : sub === "papel" ? passoPapel()
    : sub === "sons" ? passoSons() : sub === "mandar" ? passoMandar() : passoCores();
  const seguir = elemento("div", { class: "seguir" }, [
    i > 0 ? elemento("a", { class: "bt", href: "#criar/" + PASSOS[i - 1].id, controle: "criar:voltar" },
      [icone("voltar"), elemento("span", { texto: "Voltar" })]) : elemento("span"),
    elemento("div", { class: "fila" }, [
      sub === "cores" ? (() => {
        const m = vinteSeis();
        const pouco = contraste(m.text, m.base) < 4.5;
        return botao("Guardar", { class: "bt principal", controle: "criar:guardar", disabled: pouco,
          "aria-disabled": pouco ? "true" : null,
          dica: pouco ? "Pouco contraste entre texto e fundo" : "Grava o tema entre os seus", onclick: guardarTema });
      })() : null,
      i < PASSOS.length - 1 ? elemento("a", { class: "bt", href: "#criar/" + PASSOS[i + 1].id, controle: "criar:proximo" },
        [elemento("span", { texto: PASSOS[i + 1].nome }), icone("seta")]) : null,
    ]),
  ]);
  const ordem = ESQUEMA.paleta.ordem || [];
  const mapa = vinteSeis();
  const previa = MESA.mesa({
    cores: MESA.estiloDeCores(ordem.map((n) => mapa[n]), ordem, "mauve"),
    gato: urlDoGato(ESQUEMA.gato_no_dock || vale("LOGO")), parede: sub === "papel" ? paredeDaPrevia() : "",
    rotulo: "Prévia do tema",
  });
  return [
    elemento("div", { class: "cabeca" }, [nome]),
    passos,
    elemento("div", { class: "oficina sem-trilho" }, [
      elemento("div", { class: "palco" }, [previa]),
      elemento("div", { class: "pilha" }, [...corpo.filter(Boolean), seguir]),
    ]),
  ];
}

function reguaDaNoite() {
  const hora = (v) => { const m = /^(\d{1,2}):(\d{2})$/.exec(String(v || "")); return m ? Number(m[1]) + Number(m[2]) / 60 : null; };
  const ini = hora(vale("NOITE_INICIO")) ?? 18, fim = hora(vale("NOITE_FIM")) ?? 7;
  const fila = (nome, rotulo, de, ate, ligada) => {
    const barra = elemento("div", { style: "position:relative;height:28px;border-radius:8px;background:var(--fundo);overflow:hidden" });
    const pinta = (a, b) => {
      const s = elemento("span");
      s.style.cssText = `position:absolute;top:0;bottom:0;left:${a / 24 * 100}%;width:${(b - a) / 24 * 100}%;background:${ligada ? "var(--accent-suave)" : "transparent"};border:1px ${ligada ? "solid var(--accent-linha)" : "dashed var(--linha-forte)"};border-radius:8px`;
      barra.append(s);
    };
    if (de > ate) { pinta(de, 24); pinta(0, ate); } else pinta(de, ate);
    return elemento("div", { style: "display:grid;grid-template-columns:28px minmax(0,1fr);gap:12px;align-items:center" }, [
      elemento("span", { role: "img", "aria-label": rotulo, dica: rotulo }, [icone(nome)]), barra]);
  };
  const leituraIni = hora(vale("LEITURA_HORARIO_INICIO")) ?? ini, leituraFim = hora(vale("LEITURA_HORARIO_FIM")) ?? fim;
  const parIni = hora(vale("WALLPAPER_NOITE_INICIO")) ?? ini, parFim = hora(vale("WALLPAPER_NOITE_FIM")) ?? fim;
  const agora = new Date();
  const marca = elemento("span", { role: "img", "aria-label": "Agora" });
  marca.style.cssText = `position:absolute;top:0;bottom:0;left:calc(40px + (100% - 40px) * ${(agora.getHours() + agora.getMinutes() / 60) / 24});width:2px;background:var(--tinta)`;
  const regua = elemento("div", { class: "corpo", style: "position:relative;display:grid;gap:8px" }, [
    fila("gato", "Mascote", ini, fim, vale("LOGO_MODO") === "hora"),
    fila("lua", "Claro ou escuro", Number(vale("MODO_AUTO_CLARO_ATE") || 18), Number(vale("MODO_AUTO_CLARO_DE") || 7), vale("MODO") === "auto"),
    fila("imagem", "Papel de parede", parIni, parFim, ligado(vale("WALLPAPER_NOITE"))),
    fila("sol", "Tela quente", leituraIni, leituraFim, ligado(vale("LEITURA_AGENDA"))),
    marca,
  ]);
  return regua;
}

function linhaMesmoHorario() {
  const areas = ESQUEMA.horario_das_areas || [];
  if (!areas.length) return null;
  const ligado = !!ESQUEMA.mesmo_horario;
  const porque = `${areas.map((a, i) => (i ? a.area.toLowerCase() : a.area)).join(", ").replace(/, ([^,]*)$/, " e $1")} seguem a noite`;
  const chave = elemento("button", { type: "button", class: "chave", role: "switch", "aria-checked": String(ligado),
    "aria-label": "Mesmo horário", controle: "noite:mesmo-horario", dica: porque,
    onclick: async () => {
      chave.disabled = true;
      const r = await api("/api/mesmo-horario", { method: "POST", body: JSON.stringify({ ligar: !ligado }) });
      if (r.erro) torrada(maiuscula(primeiraFrase(r.erro)), "erro");
      await recarregarEsquema();
      render();
    } });
  return elemento("ul", { class: "linhas" }, [elemento("li", { class: "linha", "data-linha": "mesmo-horario" }, [
    elemento("div", { class: "rot" }, [elemento("span", { texto: "Mesmo horário", dica: porque })]),
    elemento("div", { class: "ctl" }, [chave]),
  ])]);
}

function gradeDeProgramas() {
  const item = CHAVE.get("APPS_ATIVOS");
  if (!item) return null;
  const ativos = String(valorEmVigor(item) || "").split(",").map((s) => s.trim()).filter(Boolean);
  const todos = [...new Set([...String(item.padrao || "").split(","), ...ativos].map((s) => s.trim()).filter(Boolean))];
  const grade = elemento("div", { class: "liga-programas", "data-linha": "APPS_ATIVOS" });
  for (const id of todos) {
    const liga = ativos.includes(id);
    grade.append(elemento("div", { class: "programa" }, [
      elemento("span", { texto: nomeDePrograma(id) }),
      elemento("button", { type: "button", class: "chave", role: "switch", "aria-checked": String(liga),
        "aria-label": nomeDePrograma(id), controle: "programa:" + id,
        onclick: () => escolher("APPS_ATIVOS", (liga ? ativos.filter((x) => x !== id) : [...ativos, id]).join(",")) }),
    ]));
  }
  return grade;
}

function paginaAjustes(sub) {
  const p = AJUSTES.find((x) => x.id === sub) || AJUSTES[0];
  const trilho = elemento("ul", { class: "trilho" }, AJUSTES.map((x) => elemento("li", {}, [
    elemento("a", { href: "#ajustes/" + x.id, controle: "ajuste:" + x.id, "aria-current": x.id === p.id ? "page" : null },
      [icone(x.icone), elemento("span", { texto: x.nome })]),
  ])));
  const direita = (p.cabeca || []).map((l) => {
    const a = ACAO.get(l.a);
    return a ? controleDeAcao(a, l.b, "")[0] : null;
  }).filter(Boolean);
  for (const b of direita) b.classList.add("principal");
  const blocos = [];
  for (const b of p.blocos) {
    const sobra = (l) => l.e || (l.g && !l.g.startsWith("acervo:")) || l.g === "acervo:gato" || l.g === "acervo:cursor"
      || (b.programas && l.c === "APPS_ATIVOS");
    const filhos = [];
    if (b.noite) filhos.push(reguaDaNoite());
    if (b.programas) filhos.push(gradeDeProgramas());
    if (b.jogos) filhos.push(montarJogos());
    filhos.push(lista(b.linhas, sobra));
    if (b.noite) filhos.push(linhaMesmoHorario());
    blocos.push(bloco(b.titulo, filhos.filter(Boolean), { colunas: b.colunas }));
  }
  const mais = maisAjustes("ajustes:" + p.id, p.mais || []);
  return [
    cabeca(p.nome, direita),
    elemento("div", { class: "oficina" }, [
      elemento("nav", { "aria-label": "Definir" }, [trilho]),
      elemento("div", { class: "palco" }, [mesaDaPagina(p.id)]),
      elemento("div", { class: "pilha" }, [...blocos, mais].filter(Boolean)),
    ]),
  ];
}

function faixaDoEstado() {
  const p = packNoAr();
  const itens = [
    ["Tema", p ? `${p.nome} · ${rotuloDeValor(flavorEmVigor())}` : rotuloDeValor(flavorEmVigor()), "#tema", "ok"],
    ["Ícones", maiuscula(vale("NOME_TEMA_ICONES")), "#criar/icones", "ok"],
    ["Painel e dock", ligado(vale("FORMA_DOCK_SOLTO")) ? "Solta" : "Na borda", "#ajustes/painel", "ok"],
    ["Mascote", rotuloDeValor(ESQUEMA.gato_no_dock || vale("LOGO")), "#ajustes/mascote", "ok"],
    ["Som", ligado(vale("SOM")) ? "Ligado" : "Desligado", "#criar/sons", ligado(vale("SOM")) ? "ok" : "alerta"],
    ["Ponte", ESQUEMA.ponte ? "Instalada" : "Falta", "#cuidar", ESQUEMA.ponte ? "ok" : "fora"],
  ];
  return elemento("div", { class: "faixa-estado" }, itens.map(([nome, valor, href, estado]) =>
    elemento("a", { href, "data-estado": estado, controle: "estado:" + nome },
      [elemento("b", { texto: nome }), elemento("span", { texto: valor || "Padrão" })])));
}

function linhaDePendencia(p) {
  const acao = p.acao ? ACAO.get(p.acao) : null;
  const programa = ((p.escolha || [])[0] || {}).argumento || "";
  const nome = maiuscula(p.nome || (acao && acao.rotulo) || (programa ? nomeDePrograma(programa) : (p.etapa || p.id)));
  const botoes = [];
  if (acao) botoes.push(botao("Resolver", { class: "bt pequeno principal", controle: "pendencia:resolver",
    dica: maiuscula(acao.rotulo), onclick: async () => { await rodar(acao, ""); await recarregarPendencias(); render(); } }));
  for (const e of p.escolha || []) {
    const a = ACAO.get(e.acao);
    botoes.push(botao(maiuscula(e.rotulo), { class: "bt pequeno", controle: "pendencia:" + e.acao,
      onclick: async () => { await rodar(a, e.argumento, { verbo: e.rotulo }); await recarregarPendencias(); render(); } }));
  }
  if (p.recusavel) botoes.push(botao("Não, obrigado", { class: "bt pequeno", controle: "pendencia:recusar",
    onclick: async () => {
      if (!await perguntar({ titulo: "Não perguntar de novo?", ok: "Não, obrigado" })) return;
      const r = await api("/api/pendencia-recusar", { method: "POST", body: JSON.stringify({ id: p.id }) });
      if (r.erro) { torrada(r.erro, "erro"); return; }
      await recarregarPendencias();
      render();
    } }));
  return elemento("li", { class: "linha", "data-linha": "pendencia:" + p.id }, [
    elemento("div", { class: "rot" }, [icone("alerta"), elemento("span", { texto: nome, dica: primeiraFrase(p.frase) })]),
    elemento("div", { class: "ctl" }, botoes),
  ]);
}
function desdeCurto(iso) {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "";
  return String(d.getDate()).padStart(2, "0") + "/" + String(d.getMonth() + 1).padStart(2, "0");
}
function linhaDeGente(g) {
  const desde = desdeCurto(g.desde);
  const dica = [primeiraFrase(g.porque), desde ? `Desde ${desde}` : ""].filter(Boolean).join(" · ");
  return elemento("li", { class: "linha", "data-linha": "gente:" + g.id }, [
    elemento("div", { class: "rot" }, [icone("alerta"), elemento("span", { texto: maiuscula(g.nome), dica })]),
    elemento("div", { class: "ctl" }, []),
  ]);
}

function cartaoDeCuidar(c) {
  const botoes = [];
  for (const l of c.linhas) {
    if (l.a) {
      const a = ACAO.get(l.a);
      if (a) botoes.push(...controleDeAcao(a, l.b, ""));
    } else if (l.g === "exportar-conf") {
      botoes.push(elemento("a", { class: "bt", href: "/api/exportar/conf", download: true, controle: "cuidar:exportar",
        dica: "Um .conf para a máquina nova" }, [icone("baixar"), elemento("span", { texto: l.b })]));
    } else if (l.g === "importar") {
      const campo = elemento("input", { type: "file", accept: ".conf,text/plain", hidden: true });
      campo.addEventListener("change", () => { const a = campo.files && campo.files[0]; campo.value = ""; importarArquivo(a); });
      botoes.push(botao(l.b, { class: "bt", icone: "subir", controle: "cuidar:importar", onclick: () => campo.click() }), campo);
    }
  }
  const primeiro = botoes.find((b) => b.classList && b.classList.contains("bt"));
  if (primeiro && !primeiro.classList.contains("perigo")) primeiro.classList.add("principal");
  return elemento("section", { class: "bloco cartao-acao terco", "data-bloco": c.titulo }, [
    elemento("span", { class: "icone" }, [icone(c.icone)]),
    elemento("h2", { texto: c.titulo }),
    elemento("div", { class: "fila" }, botoes),
  ]);
}

function paginaCuidar() {
  const e = estadoDaMaquina();
  const estado = LUGAR_CUIDAR.estado.filter((l) => l.a !== "doctor_consertar" || !ESQUEMA.ponte).map((l) => {
    const a = ACAO.get(l.a);
    return a ? controleDeAcao(a, l.b, "")[0] : null;
  }).filter(Boolean);
  if (estado[0]) estado[0].classList.add("principal");
  const topo = elemento("section", { class: "bloco inteiro" }, [
    elemento("div", { class: "estado-maquina" + (e.bom ? "" : " alerta") }, [
      elemento("span", { class: "selo-grande" }, [icone(e.icone)]),
      elemento("h1", { texto: e.titulo }),
      elemento("div", { class: "fila" }, estado),
    ]),
    faixaDoEstado(),
  ]);
  const pend = elemento("ul", { class: "linhas pendencias" }, [
    ...PRECISA_DE_GENTE.map(linhaDeGente), ...PENDENCIAS.map(linhaDePendencia)]);
  const blocos = LUGAR_CUIDAR.blocos.map((b) => bloco(b.titulo, [lista(b.linhas)], { class: "metade" }));
  const perigo = bloco(null, [lista(LUGAR_CUIDAR.perigo)], { class: "tracejado" });
  const restaurar = LUGAR_CUIDAR.mais.filter((l) => l.a);
  return [
    elemento("div", { class: "grade-cuidar" }, [
      topo,
      pend.children.length ? bloco("Pendências", [pend], { class: "inteiro" }) : null,
      ...LUGAR_CUIDAR.cartoes.map(cartaoDeCuidar),
      blocos[0],
      elemento("div", { class: "pilha metade" }, [blocos[1], perigo]),
      (() => { const m = maisAjustes("cuidar:cuidar", restaurar); if (m) m.classList.add("inteiro"); return m; })(),
    ].filter(Boolean)),
  ];
}

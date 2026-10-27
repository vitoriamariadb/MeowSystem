"use strict";

const TOKEN = document.body.dataset.token;
if (location.search) history.replaceState(null, "", location.pathname + location.hash);

const $ = (sel, raiz = document) => raiz.querySelector(sel);

const IC = {
  tema: '<circle cx="13.5" cy="6.5" r="1.5"/><circle cx="17.5" cy="10.5" r="1.5"/><circle cx="8.5" cy="7.5" r="1.5"/><circle cx="6.5" cy="12.5" r="1.5"/><path d="M12 2a10 10 0 0 0 0 20c1.1 0 2-.9 2-2 0-.5-.2-1-.5-1.3-.3-.4-.5-.8-.5-1.3 0-1.1.9-2 2-2h2.3A5.7 5.7 0 0 0 22 9.7C22 5.4 17.5 2 12 2Z"/>',
  criar: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
  ajustes: '<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>',
  cuidar: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/><path d="m9 12 2 2 4-4"/>',
  subir: '<path d="M12 21V9M7 14l5-5 5 5M5 3h14"/>',
  baixar: '<path d="M12 3v12M7 10l5 5 5-5M5 21h14"/>',
  mais: '<path d="M12 5v14M5 12h14"/>',
  certo: '<path d="M20 6 9 17l-5-5"/>',
  tocar: '<path d="M7 4v16l13-8Z"/>',
  trocar: '<path d="M7 4 3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7"/>',
  refazer: '<path d="M20 12a8 8 0 1 1-2.4-5.7L20 8.5"/><path d="M20 3.5v5h-5"/>',
  sol: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  lua: '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z"/>',
  painel: '<rect x="3" y="3" width="18" height="18" rx="3"/><path d="M3 8h18M8 17h8"/>',
  janelas: '<rect x="3" y="4" width="11" height="8" rx="1.5"/><rect x="10" y="12" width="11" height="8" rx="1.5"/>',
  imagem: '<rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="9" cy="9" r="2"/><path d="m21 15-5-5L5 21"/>',
  gato: '<path d="M5 9 4 3l5 3a8 8 0 0 1 6 0l5-3-1 6"/><path d="M5 9a7 7 0 1 0 14 0"/><path d="M9.5 13h.01M14.5 13h.01M11 16h2"/>',
  grade: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  terminal: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="m7 9 3 3-3 3M13 15h4"/>',
  alerta: '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/>',
  fechar: '<path d="M18 6 6 18M6 6l12 12"/>',
  enviar: '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
  desfazer: '<path d="M9 14 4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/>',
  som: '<path d="M11 5 6 9H2v6h4l5 4Z"/><path d="M15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14"/>',
  computador: '<rect x="2" y="4" width="20" height="13" rx="2"/><path d="M8 21h8M12 17v4"/>',
  girar: '<path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/>',
  lixo: '<path d="M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14"/>',
  estrela: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9Z"/>',
  ponte: '<path d="M2 18h20M4 18V9M20 18V9M4 9c4 4 12 4 16 0M9 13v5M15 13v5"/>',
  seta: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  voltar: '<path d="M19 12H5M11 6l-6 6 6 6"/>',
  pasta: '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z"/>',
  ponteiro: '<path d="M5 3l14 8-6 2-2 6Z"/>',
};

function icone(nome, classe = "i") {
  const el = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  el.setAttribute("viewBox", "0 0 24 24");
  el.setAttribute("aria-hidden", "true");
  el.setAttribute("class", classe);
  el.innerHTML = IC[nome] || "";
  return el;
}

function maiuscula(txt) {
  if (txt == null) return "";
  const t = String(txt).trimStart();
  return t.charAt(0).toLocaleUpperCase("pt-BR") + t.slice(1);
}
function primeiraFrase(txt) {
  const t = String(txt || "").replace(/\s+/g, " ").trim();
  if (!t) return "";
  const m = /^(.{12,}?[.!?])(\s|$)/.exec(t);
  let f = m ? m[1] : t;
  if (f.length > 110) f = f.slice(0, 110).replace(/[\s,;:—-]+\S*$/, "") + "…";
  return maiuscula(f);
}
function semAcento(t) {
  return String(t || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}

const ROTULO_DE_VALOR = {
  sim: "Sim", nao: "Não", auto: "Automático", escuro: "Escuro", claro: "Claro",
  aleatoria: "Sorteada", alfabetica: "De A a Z", silencioso: "Pouco", info: "O que mudou", debug: "Tudo",
  traco: "Traço", chapado: "Chapado", espelho: "O outro", hora: "Pela hora", rotacao: "Girando", fixo: "Sempre o mesmo",
  nitida: "Automático", preencher: "Preencher", caber: "Caber", esticar: "Esticar",
  global: "Todas as áreas", workspace: "Cada área",
  tabular: "Em coluna", contorno: "Contornando", degraus: "Degraus", crescente: "Crescente", reto: "Reto",
  quadrante: "Médio", sextante: "Alto", accent: "Destaque", port: "Do tema",
  "30s": "30 s", "5m": "5 min", "2h": "2 h", "6h": "6 h", "12h": "12 h", "1d": "1 dia", "7d": "7 dias",
  "1.0": "100%", "1.25": "125%", "1.5": "150%", "2.0": "200%",
};
const MINUSCULOS_DE_FATO = ["zsh", "fzf", "bat", "btop", "fastfetch", "qt5ct", "qBittorrent"];

function rotuloDeValor(v, item) {
  if (item && item.rotulos && item.rotulos[v]) return maiuscula(item.rotulos[v]);
  if (v in ROTULO_DE_VALOR) return ROTULO_DE_VALOR[v];
  const f = ((ESQUEMA && ESQUEMA.pack && ESQUEMA.pack.flavors) || []).find((x) => x.id === v);
  if (f) return f.nome;
  return maiuscula(String(v).replace(/-/g, " "));
}
function nomeDaCor(slot) {
  const f = ((ESQUEMA && ESQUEMA.pack && ESQUEMA.pack.flavors) || []).find((x) => x.id === flavorEmVigor());
  return maiuscula((f && f.nomes_de_cor && f.nomes_de_cor[slot]) || slot);
}

function elemento(tag, props = {}, filhos = []) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(props || {})) {
    if (v === false || v == null) continue;
    if (k === "class") el.className = v;
    else if (k === "texto") el.textContent = v;
    else if (k === "dica") { if (v) { el.dataset.dica = maiuscula(v); el.setAttribute("aria-description", maiuscula(v)); } }
    else if (k === "controle") el.dataset.controle = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (v === true) el.setAttribute(k, "");
    else el.setAttribute(k, v);
  }
  for (const f of [].concat(filhos)) if (f != null && f !== false) el.append(f);
  return el;
}
function botao(texto, props = {}, extra = []) {
  const { icone: nomeIcone, ...resto } = props;
  return elemento("button", { type: "button", class: "bt", ...resto }, [
    nomeIcone ? icone(nomeIcone) : null, texto ? elemento("span", { texto }) : null, ...extra]);
}

let DICA_ALVO = null;
let DICA_RELOGIO = null;
function esconderDica() {
  clearTimeout(DICA_RELOGIO);
  DICA_ALVO = null;
  const d = $("#dica");
  if (d) d.hidden = true;
}
function mostrarDica(alvo) {
  const d = $("#dica");
  if (!d || !alvo.isConnected || !alvo.dataset.dica) return;
  DICA_ALVO = alvo;
  d.textContent = alvo.dataset.dica;
  d.hidden = false;
  const r = alvo.getBoundingClientRect();
  const largura = d.offsetWidth, altura = d.offsetHeight;
  const x = Math.min(Math.max(8, r.left + r.width / 2 - largura / 2), innerWidth - largura - 8);
  let y = r.bottom + 8;
  if (y + altura > innerHeight - 8) y = r.top - altura - 8;
  d.style.left = x + "px";
  d.style.top = Math.max(8, y) + "px";
}
function ligarDicas() {
  document.addEventListener("mouseover", (ev) => {
    const alvo = ev.target.closest && ev.target.closest("[data-dica]");
    if (alvo === DICA_ALVO) return;
    esconderDica();
    if (alvo) DICA_RELOGIO = setTimeout(() => mostrarDica(alvo), 800);
  });
  document.addEventListener("focusin", (ev) => {
    const alvo = ev.target.closest && ev.target.closest("[data-dica]");
    esconderDica();
    if (alvo && ev.target.matches(":focus-visible")) mostrarDica(alvo);
  });
  document.addEventListener("focusout", esconderDica);
  document.addEventListener("keydown", (ev) => { if (ev.key === "Escape") esconderDica(); });
  addEventListener("scroll", esconderDica, true);
}

function torrada(texto, classe = "") {
  texto = maiuscula(texto);
  for (const viva of $("#torradas").children) {
    if (viva.textContent === texto) return;
  }
  const el = elemento("div", { class: "torrada " + classe, texto, role: classe === "erro" ? "alert" : null });
  $("#torradas").append(el);
  el._t = setTimeout(() => el.remove(), classe === "erro" ? 7000 : 3000);
}

async function api(rota, opcoes = {}) {
  let resposta;
  try {
    resposta = await fetch(rota, {
      ...opcoes,
      headers: { "X-Meow-Token": TOKEN, "Content-Type": "application/json", ...(opcoes.headers || {}) },
    });
  } catch (e) {
    faixaSemServidor(true);
    return { erro: "Sem servidor", sem_servidor: true };
  }
  faixaSemServidor(false);
  const texto = await resposta.text();
  let dados;
  try { dados = JSON.parse(texto); } catch { dados = { erro: texto }; }
  if (resposta.status === 409 && !dados.erro) dados.erro = "Já há um trabalho rodando";
  if (!resposta.ok && !dados.erro) dados.erro = "HTTP " + resposta.status;
  return dados;
}
function faixaSemServidor(mostrar) {
  let faixa = document.getElementById("faixa-sem-servidor");
  if (!mostrar) { if (faixa) faixa.remove(); return; }
  if (faixa) return;
  faixa = elemento("div", { id: "faixa-sem-servidor", class: "torrada erro", role: "alert",
    dica: "As escolhas que esperam continuam nesta aba" }, [icone("alerta"), " Sem servidor"]);
  faixa.style.cssText = "position:fixed;left:50%;top:72px;transform:translateX(-50%);z-index:45;display:flex;gap:8px;align-items:center";
  document.body.append(faixa);
}

let ESQUEMA = null;
const CHAVE = new Map();
const ACAO = new Map();
let PACKS = [];
let PENDENCIAS = [];
let PRECISA_DE_GENTE = [];
const PREVIAS = new Map();
const MUDANCAS = new Map();
let ROTA = { porta: "tema", sub: "" };

function indexar() {
  CHAVE.clear(); ACAO.clear();
  for (const i of ESQUEMA.chaves || []) CHAVE.set(i.chave, i);
  for (const a of ESQUEMA.acoes || []) ACAO.set(a.id, a);
}
async function recarregarEsquema() {
  const r = await api("/api/esquema");
  if (!r.erro) { ESQUEMA = r; indexar(); }
}
async function recarregarPacks() {
  const r = await api("/api/packs");
  PACKS = (r && Array.isArray(r.packs)) ? r.packs : [];
}
async function recarregarPendencias() {
  const [r, g] = await Promise.all([api("/api/pendencias"), api("/api/precisa-de-gente")]);
  PENDENCIAS = (r && Array.isArray(r.pendencias)) ? r.pendencias : [];
  PRECISA_DE_GENTE = (g && Array.isArray(g.itens)) ? g.itens : [];
}
const PREVIAS_PEDIDAS = new Map();
function previasDe(tipo, grupo = "") {
  const k = tipo + "/" + grupo;
  if (PREVIAS.has(k)) return PREVIAS.get(k);
  if (!PREVIAS_PEDIDAS.has(k)) carregarPrevias(tipo, grupo);
  return null;
}
async function carregarPrevias(tipo, grupo = "", tentativa = 0) {
  const k = tipo + "/" + grupo;
  PREVIAS_PEDIDAS.set(k, true);
  const r = await api(`/api/previas?tipo=${encodeURIComponent(tipo)}&grupo=${encodeURIComponent(grupo)}`);
  PREVIAS.set(k, r.erro ? { itens: [], contagens: {}, total: 0 } : r);
  PREVIAS_PEDIDAS.delete(k);
  render();
  if (r.faltam && tentativa < 12) setTimeout(() => carregarPrevias(tipo, grupo, tentativa + 1), 1500);
}

function valorEmVigor(item) {
  return MUDANCAS.has(item.chave) ? MUDANCAS.get(item.chave) : (item.valor ?? "");
}
function vale(chave) {
  const item = CHAVE.get(chave);
  if (!item) return "";
  const v = valorEmVigor(item);
  if (v !== "") return v;
  return item.valendo_agora ?? item.efetivo ?? item.padrao ?? "";
}
function flavorEmVigor() {
  const item = CHAVE.get("FLAVOR");
  return (item && valorEmVigor(item)) || (ESQUEMA.pack && ESQUEMA.pack.flavor_padrao) || "";
}
function packNoAr() {
  return PACKS.find((p) => p.no_ar) || null;
}
const ligado = (v) => ["sim", "1", "true"].includes(String(v || "").toLowerCase());

const PAR_DA_NOITE = { NOITE_INICIO: "NOITE_FIM", NOITE_FIM: "NOITE_INICIO" };
const HORA_DA_PONTA = { NOITE_INICIO: "18:00", NOITE_FIM: "07:00" };
function completarParDaNoite(lote, chave, valor) {
  const irma = PAR_DA_NOITE[chave];
  if (!irma || !/^\d{1,2}:\d{2}$/.test(String(valor))) return;
  const item = CHAVE.get(irma);
  if (!item || valorEmVigor(item) !== "") return;
  const hora = item.efetivo || item.valendo_agora || item.padrao;
  lote[irma] = /^\d{1,2}:\d{2}$/.test(String(hora || "")) ? hora : HORA_DA_PONTA[irma];
}

const HISTORICO = [];
const HISTORICO_MAX = 20;
let EM_VOO = 0;
let FILA_DE_GRAVACAO = Promise.resolve();
let ACOMPANHANDO = false;

function escolher(chave, valor) {
  const item = CHAVE.get(chave);
  if (!item) return false;
  if (String(valor) === String(valorEmVigor(item))) return true;
  const lote = { [chave]: String(valor) };
  completarParDaNoite(lote, chave, valor);
  gravarAgora(lote);
  return true;
}

function chavesRecentes() {
  return new Set([...MUDANCAS.keys(), ...(HISTORICO[0] ? HISTORICO[0].itens.map((it) => it.chave) : [])]);
}

function mostrarGravando(estado, frase = "") {
  const g = $("#gravando");
  if (!g) return;
  g.dataset.estado = estado;
  const texto = estado === "gravando" ? "Gravando" : estado === "erro" ? (frase || "Não aplicou") : "Gravado";
  g.setAttribute("aria-label", texto);
  g.dataset.dica = texto;
}

function rotuloDoHistorico(chave) {
  const inv = inventarioDoPainel();
  const l = inv.find((x) => x.tipo === "chave" && x.id === chave);
  if (!l) return (CHAVE.get(chave) || {}).titulo || chave;
  const irmas = inv.filter((x) => x.tipo === "chave" && x.rotulo === l.rotulo && x.pagina === l.pagina && x.bloco === l.bloco);
  if (irmas.length !== 2) return l.rotulo;
  return `${l.rotulo} (${irmas[0].id === chave ? "barra de cima" : "dock"})`;
}
function valorParaLer(v, item) {
  return v === "" ? "Padrão" : rotuloDeValor(v, item);
}

function gravarAgora(lote, opc = {}) {
  const chaves = Object.keys(lote).filter((c) => CHAVE.has(c));
  if (!chaves.length) return Promise.resolve(false);
  const antes = {};
  for (const c of chaves) { antes[c] = String(CHAVE.get(c).valor ?? ""); MUDANCAS.set(c, String(lote[c])); }
  EM_VOO++;
  mostrarGravando("gravando");
  render();
  FILA_DE_GRAVACAO = FILA_DE_GRAVACAO.then(() => enviarLote(lote, antes, chaves, opc));
  return FILA_DE_GRAVACAO;
}

async function enviarLote(lote, antes, chaves, opc) {
  const so = chaves.length === 1;
  const r = so
    ? await api("/api/definir", { method: "POST", body: JSON.stringify({ chave: chaves[0], valor: String(lote[chaves[0]]) }) })
    : await api("/api/salvar", { method: "POST", body: JSON.stringify({ mudancas: lote }) });
  EM_VOO--;
  for (const c of chaves) MUDANCAS.delete(c);
  const certas = so ? (r.erro || r.rc === 2 ? [] : chaves)
    : [...(r.gravadas || []), ...(r.iguais || [])].filter((c) => chaves.includes(c));
  for (const c of certas) CHAVE.get(c).valor = String(lote[c]);
  const queixas = [];
  for (const rec of [...(r.recusadas || []), ...(r.falhas || [])]) queixas.push(`${nomeDeChave(rec.chave)}: ${rec.erro}`);
  if (!queixas.length && (r.erro || r.rc === 2)) queixas.push(r.erro || r.saida || "Não gravou");
  if (queixas.length) {
    for (const q of queixas.slice(0, 3)) torrada(q, "erro");
    mostrarGravando("erro", queixas[0]);
    render();
    return false;
  }
  const itens = chaves.filter((c) => String(antes[c]) !== String(lote[c]))
    .map((c) => ({ chave: c, antes: antes[c], depois: String(lote[c]) }));
  if (opc.historico !== false && itens.length) {
    const p = itens[0];
    HISTORICO.unshift({ itens, rotulo: rotuloDoHistorico(p.chave),
      detalhe: `${valorParaLer(p.antes, CHAVE.get(p.chave))} → ${valorParaLer(p.depois, CHAVE.get(p.chave))}` });
    HISTORICO.length = Math.min(HISTORICO.length, HISTORICO_MAX);
  }
  if (r.sem_ponte) {
    torrada("Gravado; falta a ponte para aplicar", "erro");
    mostrarGravando("erro", "Falta a ponte para aplicar");
    await recarregarPendencias();
  } else if (r.aplicando) {
    mostrarGravando("gravando");
    acompanharAplicacao();
  } else if (!EM_VOO) {
    mostrarGravando("ok");
  }
  atualizarAplicar();
  render();
  return true;
}

async function acompanharAplicacao() {
  if (ACOMPANHANDO) return;
  ACOMPANHANDO = true;
  try {
    for (let n = 0; n < 6000; n++) {
      const r = await api("/api/aplicando");
      if (r.erro) return;
      if (!r.correndo) {
        if (r.falhou) {
          mostrarGravando("erro", "Não aplicou");
          await recarregarPendencias();
          render();
        } else if (!EM_VOO) {
          mostrarGravando("ok");
          await recarregarEsquema();
          render();
        }
        return;
      }
      await new Promise((ok) => setTimeout(ok, 600));
    }
  } finally {
    ACOMPANHANDO = false;
  }
}

async function desfazerEntradas(entradas) {
  if (!entradas.length) return;
  const lote = {};
  for (const e of entradas) for (const it of e.itens) lote[it.chave] = it.antes;
  const certo = await gravarAgora(lote, { historico: false });
  if (!certo) return;
  for (const e of entradas) { const k = HISTORICO.indexOf(e); if (k >= 0) HISTORICO.splice(k, 1); }
  atualizarAplicar();
  render();
}
function desfazerTudo() {
  desfazerEntradas(HISTORICO.slice());
}

function padraoDe(item) {
  if (item.padrao_do_pack != null) return String(item.padrao_do_pack);
  return item.padrao == null ? "" : String(item.padrao);
}
function temOQueRestaurar(item, valor) {
  return String(valor) !== String(padraoDe(item));
}
function botaoPadrao(item, aplica, coluna) {
  const fabrica = padraoDe(item);
  const de = coluna ? ` (${coluna.toLowerCase()})` : "";
  return elemento("button", {
    type: "button", class: "padrao", controle: "padrao:" + item.chave,
    "aria-label": "Voltar ao padrão" + de,
    dica: (fabrica === "" ? "Padrão: o sistema decide" : "Padrão: " + rotuloDeValor(fabrica, item)) + de,
    onclick: () => aplica(fabrica),
  }, [icone("desfazer")]);
}

function botaoAutomatico(item, valor, aplica, coluna) {
  if (!item.aceita_vazio || padraoDe(item) === "" || valor === "") return null;
  const de = coluna ? ` (${coluna.toLowerCase()})` : "";
  return elemento("button", {
    type: "button", class: "padrao", controle: "automatico:" + item.chave,
    "aria-label": "O sistema decide" + de, dica: "O sistema decide" + de, onclick: () => aplica(""),
  }, [icone("girar")]);
}

const TAMANHOS = { XS: "Muito pequeno", S: "Pequeno", M: "Médio", L: "Grande", XL: "Muito grande" };

function controle(item) {
  const valor = valorEmVigor(item);
  const aplica = (v) => escolher(item.chave, v);
  const nome = item.chave;
  const dica = primeiraFrase(item.frase);

  if (item.molde_pastas) { const c = controlePastas(item, aplica); if (c) return c; }
  if (item.previa === "gato" || item.previa === "cursor") return controleImagem(item, aplica);
  if (item.previa === "cor") return controleCor(item, aplica);
  if (item.chave === "AREAS_NOMES") return controleAreas(item, aplica);
  if (item.chave === "AREAS_FOLGA" || item.chave === "AREAS_ENCAIXE") return controlePorArea(item, aplica);
  if (item.chave === "ACCENT") return controleCor(item, aplica, true);
  if (item.chave === "CURSOR") return controleImagem(item, aplica);
  if (item.lista || item.lista_pathsep) return controleLista(item, aplica);

  if (item.horario || item.hora_cheia) {
    const cheia = item.hora_cheia;
    const emHora = (v) => (/^\d{1,2}$/.test(String(v ?? "")) ? `${String(v).padStart(2, "0")}:00` : String(v || ""));
    const irmaDoEscuro = { NOITE_INICIO: "MODO_AUTO_CLARO_ATE", NOITE_FIM: "MODO_AUTO_CLARO_DE" }[nome];
    const herdada = item.efetivo || item.valendo_agora || (cheia ? emHora(item.vazio_vale) : "")
      || (irmaDoEscuro ? emHora(vale(irmaDoEscuro)) : "");
    const campo = elemento("input", {
      type: "time", class: "campo hora", value: (cheia ? emHora(valor) : valor) || emHora(herdada) || "",
      step: cheia ? "3600" : null, "aria-label": item.titulo || nome, controle: "chave:" + nome, dica,
    });
    campo.addEventListener("change", () => {
      if (!campo.value) return;
      if (cheia) { const h = /^(\d{1,2}):/.exec(campo.value); if (h) aplica(String(Number(h[1]))); }
      else aplica(campo.value);
    });
    return campo;
  }

  if (item.faixa) return controleFaixa(item, aplica);

  if (item.opcoes && item.opcoes.length) {
    const o = item.opcoes;
    if (o.length === 2 && o.includes("sim") && o.includes("nao")) {
      const liga = ligado(valor || item.efetivo || item.padrao);
      return elemento("button", {
        type: "button", class: "chave", role: "switch", "aria-checked": String(liga),
        "aria-label": item.titulo || nome, controle: "chave:" + nome, dica,
        onclick: () => aplica(liga ? "nao" : "sim"),
      });
    }
    if (o.length <= 5) {
      const seg = elemento("div", { class: "seg", role: "group", "aria-label": item.titulo || nome });
      const caiu = valor !== "" && o.some((op) => String(op) === String(valor));
      const marcado = caiu ? valor : (item.valendo_agora ?? item.efetivo ?? "");
      const tamanhos = o.every((op) => TAMANHOS[op]);
      for (const op of o) {
        seg.append(elemento("button", {
          type: "button", "aria-pressed": String(String(op) === String(marcado)),
          controle: "chave:" + nome + "=" + op, texto: rotuloDeValor(op, item),
          dica: tamanhos ? TAMANHOS[op] : rotuloDeValor(op, item), onclick: () => aplica(op),
        }));
      }
      return seg;
    }
    const sel = elemento("select", { class: "campo", "aria-label": item.titulo || nome, controle: "chave:" + nome, dica });
    if (item.aceita_vazio) sel.append(elemento("option", { value: "", texto: "Automático" }));
    for (const op of o) sel.append(elemento("option", { value: op, texto: rotuloDeValor(op, item) }));
    sel.value = valor;
    sel.addEventListener("change", () => aplica(sel.value));
    return sel;
  }

  if (item.tipo_numero === "duracao") {
    const m = /^(\d+)([smh]?)$/.exec(String(valor || item.padrao || "").trim());
    if (m) {
      const min = m[2] === "h" ? Number(m[1]) * 60 : m[2] === "s" ? Math.round(Number(m[1]) / 60) : Number(m[1]);
      const campo = elemento("input", { type: "number", min: "0", step: "1", class: "campo numero",
        value: String(min), "aria-label": (item.titulo || nome) + ", em minutos", controle: "chave:" + nome, dica });
      campo.addEventListener("change", () => {
        const n = Math.max(0, Math.round(Number(campo.value)));
        if (Number.isFinite(n)) aplica(`${n}m`);
      });
      return elemento("span", { class: "fila" }, [campo, elemento("span", { texto: "Min", class: "unidade" })]);
    }
  }

  const campo = elemento("input", {
    type: "text", class: "campo largo", value: valor, "aria-label": item.titulo || nome,
    placeholder: item.aceita_vazio ? "Automático" : (item.padrao ? maiuscula(item.padrao) : null),
    controle: "chave:" + nome, dica,
  });
  campo.addEventListener("change", () => aplica(campo.value));
  campo.addEventListener("keydown", (ev) => { if (ev.key === "Enter") { ev.preventDefault(); campo.blur(); } });
  return campo;
}

function controleFaixa(item, aplica) {
  const [lo, hi, passo] = item.faixa;
  const teto = item.teto && item.teto.trava ? Number(item.teto.valor) : null;
  const topo = teto == null ? hi : Math.max(Number(lo), Math.min(Number(hi), teto));
  const valor = valorEmVigor(item);
  const base = valor !== "" ? valor : (item.valendo_agora ?? item.vazio_vale ?? item.padrao ?? lo);
  const numero = /^-?\d+(\.\d+)?$/.test(String(base)) ? Number(base) : Number(lo);
  const vazio = valor === "";
  const pct = (n) => `${((n - lo) / ((topo - lo) || 1)) * 100}%`;
  const slider = elemento("input", {
    type: "range", min: lo, max: topo, step: passo, value: String(numero),
    "aria-label": item.titulo || item.chave, controle: "chave:" + item.chave, dica: primeiraFrase(item.frase),
  });
  slider.style.setProperty("--p", pct(numero));
  const saida = elemento("output", { texto: vazio ? "Auto" : String(numero) });
  const caixa = elemento("div", { class: "faixa" }, [slider, saida]);
  if (vazio) caixa.setAttribute("data-vazio", "");
  slider.addEventListener("input", () => {
    caixa.removeAttribute("data-vazio");
    saida.textContent = slider.value;
    slider.style.setProperty("--p", pct(Number(slider.value)));
    repintarPrevia(item.chave, slider.value);
  });
  slider.addEventListener("change", () => aplica(slider.value));
  return caixa;
}

function controleCor(item, aplica, grandes = false) {
  const cores = ((ESQUEMA.paleta.flavors || {})[flavorEmVigor()]) || {};
  const nomes = item.opcoes && item.opcoes.length ? item.opcoes
    : ["mauve", "pink", "blue", "green", "peach", "lavender", "red", "yellow", "teal", "sky", "text"];
  const valor = valorEmVigor(item) || item.efetivo || item.padrao;
  const caixa = elemento("div", { class: "cores" + (grandes ? " grandes" : ""), role: "group",
    "aria-label": item.titulo || item.chave });
  for (const nome of nomes) {
    if (!cores[nome]) continue;
    const b = elemento("button", {
      type: "button", "aria-pressed": String(nome === valor), "aria-label": nomeDaCor(nome),
      controle: "chave:" + item.chave + "=" + nome, dica: nomeDaCor(nome),
      onclick: () => aplica(nome),
    });
    b.style.setProperty("--c", cores[nome]);
    caixa.append(b);
  }
  return caixa;
}

function controlePastas(item, aplica) {
  const molde = item.molde_pastas;
  const m = /^cat-(.+)-([^-]+)$/.exec(valorEmVigor(item) || item.padrao || "");
  if (!m) return null;
  const [variante, cor] = [m[1], m[2]];
  const sel = elemento("select", { class: "campo", "aria-label": "Variante das pastas", controle: "chave:ICONES_PASTAS:variante" });
  for (const o of molde.variantes) sel.append(elemento("option", { value: o.valor, texto: maiuscula(o.rotulo) }));
  if (!molde.variantes.some((o) => o.valor === variante)) sel.append(elemento("option", { value: variante, texto: maiuscula(variante) }));
  sel.value = variante;
  sel.addEventListener("change", () => aplica(`cat-${sel.value}-${cor}`));
  const cores = ((ESQUEMA.paleta.flavors || {})[flavorEmVigor()]) || {};
  const caixa = elemento("div", { class: "cores pequenas", role: "group", "aria-label": "Cor das pastas" });
  for (const o of molde.cores) {
    const b = elemento("button", {
      type: "button", "aria-pressed": String(o.valor === cor), "aria-label": maiuscula(o.rotulo),
      controle: "chave:ICONES_PASTAS:cor=" + o.valor, dica: maiuscula(o.rotulo),
      onclick: () => aplica(`cat-${variante}-${o.valor}`),
    });
    b.style.setProperty("--c", o.valor === "${ACCENT}" ? "var(--accent)" : (cores[o.valor] || `var(--${o.valor})`));
    caixa.append(b);
  }
  return elemento("div", { class: "fila" }, [sel, caixa]);
}

function controleImagem(item, aplica) {
  const tipo = item.previa === "gato" ? "gato" : "cursor";
  const lista = previasDe(tipo);
  const porId = new Map(((lista && lista.itens) || []).map((i) => [i.id, i]));
  const opcoes = item.opcoes.length ? item.opcoes : [...new Set([...porId.keys(), valorEmVigor(item) || item.padrao].filter(Boolean))];
  const valor = valorEmVigor(item) || item.efetivo || item.padrao;
  const grande = item.chave === "LOGO" || item.chave === "CURSOR";
  const caixa = elemento("div", { class: grande ? "escolhas" : "seg", role: "group", "aria-label": item.titulo || item.chave });
  for (const op of opcoes) {
    const p = porId.get(op);
    const desenho = p && p.pronta ? elemento("img", { src: p.url, alt: "", loading: "lazy" })
      : tipo === "cursor" ? icone("ponteiro", "i ponteiro") : elemento("span", { class: "lugar" });
    if (!grande) {
      desenho.style.cssText = "width:22px;height:22px;display:inline-block;vertical-align:middle;border-radius:50%";
    }
    caixa.append(elemento("button", {
      type: "button", class: grande ? "escolha" : null, "aria-pressed": String(op === valor),
      controle: "chave:" + item.chave + "=" + op, onclick: () => aplica(op),
    }, grande ? [desenho, elemento("span", { texto: rotuloDeValor(op, item) })]
              : [desenho, " ", rotuloDeValor(op, item)]));
  }
  if (grande) caixa.append(botaoAcervo(tipo, tipo === "gato" ? "Trazer .svg" : "Trazer .zip", true));
  return caixa;
}

const LISTAS_DE_APPS = new Set(["LANCADOR_OCULTAR", "AUTOSTART_BLOQUEADOS"]);
let APPS_DA_LISTA = null;
function appsDaLista() {
  if (!APPS_DA_LISTA) APPS_DA_LISTA = api("/api/apps").then((r) => (r && r.apps) || []);
  return APPS_DA_LISTA;
}
function controleLista(item, aplica) {
  const sep = item.lista_pathsep ? ":" : ",";
  const itens = String(valorEmVigor(item) || "").split(sep).map((s) => s.trim()).filter(Boolean);
  const caixa = elemento("div", { class: "fichas", role: "list", "aria-label": item.titulo || item.chave });
  for (const nome of itens) {
    const programa = (item.programas || {})[nome];
    const rotulo = programa ? maiuscula(programa.nome) : nomeDePrograma(nome);
    caixa.append(elemento("span", { class: "ficha", role: "listitem", dica: programa ? maiuscula(nome) : null }, [
      programa && programa.icone ? elemento("img", { src: programa.icone, alt: "" }) : null,
      elemento("span", { texto: rotulo }),
      elemento("button", { type: "button", "aria-label": "Tirar " + rotulo, controle: "ficha:" + item.chave,
        onclick: () => aplica(itens.filter((x) => x !== nome).join(sep)) }, [icone("fechar")]),
    ]));
  }
  const nova = elemento("input", { type: "text", class: "campo ficha-nova", placeholder: "Acrescentar",
    "aria-label": "Acrescentar a " + (item.titulo || item.chave), controle: "chave:" + item.chave + ":nova" });
  const deApps = LISTAS_DE_APPS.has(item.chave);
  if (deApps) {
    const sugestoes = elemento("datalist", { id: "apps-" + item.chave });
    nova.setAttribute("list", sugestoes.id);
    nova.setAttribute("placeholder", "Procurar um programa");
    appsDaLista().then((apps) => {
      for (const a of apps) sugestoes.append(elemento("option", { value: a.id, label: a.nome }));
    });
    caixa.append(sugestoes);
  }
  const acrescentar = async () => {
    let v = nova.value.trim();
    if (!v || itens.includes(v)) { nova.value = ""; return; }
    if (deApps) {
      const apps = await appsDaLista();
      const solto = v.replace(/^-/, "");
      const prefixo = v.startsWith("-") && item.chave === "LANCADOR_OCULTAR" ? "-" : "";
      const certo = apps.find((a) => a.id === solto)
        || apps.find((a) => a.nome.toLowerCase() === solto.toLowerCase());
      if (!certo) { torrada("Não achei esse programa", "erro"); nova.value = ""; return; }
      v = prefixo + certo.id;
      if (itens.includes(v)) { nova.value = ""; return; }
    }
    aplica([...itens, v].join(sep));
  };
  nova.addEventListener("keydown", (ev) => { if (ev.key === "Enter") { ev.preventDefault(); acrescentar(); } });
  nova.addEventListener("change", acrescentar);
  caixa.append(nova);
  return caixa;
}

const NOME_DE_PROGRAMA = {
  "cosmic-term": "Terminal", vscode: "VS Code", obsidian: "Obsidian", qbittorrent: "qBittorrent",
  firefox: "Firefox", brave: "Brave", chrome: "Chrome", thunderbird: "Thunderbird", discord: "Discord",
  telegram: "Telegram", spotify: "Spotify", zapzap: "WhatsApp", obs: "OBS", gimp: "GIMP", krita: "Krita",
  vlc: "VLC", steam: "Steam", heroic: "Heroic", kitty: "Kitty", "gnome-terminal": "GNOME Terminal",
  onlyoffice: "OnlyOffice", fastfetch: "fastfetch", zsh: "zsh", fzf: "fzf", bat: "bat", btop: "btop", qt5ct: "qt5ct",
};
function nomeDePrograma(id) {
  return NOME_DE_PROGRAMA[id] || maiuscula(String(id).replace(/[-_.]/g, " "));
}

function controleAreas(item, aplica) {
  const proprio = String(valorEmVigor(item) || "");
  const nomes = (proprio || String(item.valendo_agora || "")).split(",").map((x) => x.trim()).filter(Boolean);
  const gravar = (lista) => aplica(lista.filter(Boolean).join(", "));
  const caixa = elemento("div", { class: "areas", role: "list", "aria-label": "Áreas de trabalho" });
  nomes.forEach((nome, i) => {
    const campo = elemento("input", { type: "text", value: nome, "aria-label": `Área ${i + 1}`,
      controle: "chave:AREAS_NOMES:area", dica: "Alt + setas mudam a ordem" });
    campo.addEventListener("keydown", (ev) => {
      if (ev.key === "Enter") { ev.preventDefault(); campo.blur(); return; }
      if (ev.altKey && (ev.key === "ArrowLeft" || ev.key === "ArrowRight")) {
        ev.preventDefault();
        const j = i + (ev.key === "ArrowLeft" ? -1 : 1);
        if (j < 0 || j >= nomes.length) return;
        const l = nomes.slice(); [l[i], l[j]] = [l[j], l[i]]; gravar(l);
      }
    });
    campo.addEventListener("change", () => { const l = nomes.slice(); l[i] = campo.value.trim(); gravar(l); });
    caixa.append(elemento("span", { class: "area", role: "listitem" }, [elemento("b", { texto: String(i + 1) }), campo]));
  });
  const nova = elemento("input", { type: "text", class: "campo ficha-nova", placeholder: "Nova área",
    "aria-label": "Nova área", controle: "chave:AREAS_NOMES:nova" });
  nova.addEventListener("change", () => { if (nova.value.trim() && !nomes.includes(nova.value.trim())) gravar([...nomes, nova.value.trim()]); });
  caixa.append(nova);
  return caixa;
}

function controlePorArea(item, aplica) {
  const nomes = String(vale("AREAS_NOMES") || "").split(",").map((x) => x.trim()).filter(Boolean);
  const caixa = elemento("div", { class: "areas", role: "group", "aria-label": item.titulo || item.chave });
  if (!nomes.length) {
    caixa.append(elemento("span", { class: "area" }, [elemento("b", { texto: "0" })]));
    return caixa;
  }
  const posicional = item.chave === "AREAS_ENCAIXE";
  const cru = String(valorEmVigor(item) || "").split(",").map((x) => x.trim());
  const deUm = cru.length === 1 && cru[0];
  nomes.forEach((nome, i) => {
    const liga = posicional ? (deUm ? cru[0] : cru[i]) === "sim" : cru.includes(nome);
    const trocar = () => {
      if (posicional) {
        aplica(nomes.map((_, j) => (j === i ? (liga ? "nao" : "sim") : ((deUm ? cru[0] : cru[j]) || "nao"))).join(","));
      } else {
        const s = new Set(cru.filter(Boolean));
        if (liga) s.delete(nome); else s.add(nome);
        aplica(nomes.filter((n) => s.has(n)).join(", "));
      }
    };
    caixa.append(elemento("span", { class: "area" }, [
      elemento("span", { texto: maiuscula(nome) }),
      elemento("button", { type: "button", class: "chave", role: "switch", "aria-checked": String(liga),
        "aria-label": nome, controle: "chave:" + item.chave + ":area", onclick: trocar }),
    ]));
  });
  return caixa;
}

const SOLTO_DE = { FORMA_MARGEM_PAINEL: ["FORMA_PAINEL_SOLTO", "o painel"], FORMA_MARGEM_DOCK: ["FORMA_DOCK_SOLTO", "a dock"] };

function dominada(item) {
  const solto = SOLTO_DE[item.chave];
  if (solto && CHAVE.get(solto[0]) && String(vale(solto[0])) === "nao") {
    return `A distância só vale com ${solto[1]} solto da borda.`;
  }
  const d = item.dominada_por;
  if (!d) return null;
  if (!CHAVE.get(d.chave) || String(vale(d.chave)) !== String(d.valor)) return null;
  return maiuscula(d.porque || "");
}

const COLUNAS = ["Barra de cima", "Dock"];

function linhaDeChave(l) {
  const chaves = [].concat(l.c);
  const itens = chaves.map((c) => CHAVE.get(c)).filter(Boolean);
  if (!itens.length || itens.every((i) => i.sem_programa)) return null;
  const um = itens[0];
  const dupla = Array.isArray(l.c) && l.c.length === 2;
  const mudou = chaves.some((c) => MUDANCAS.has(c) || HISTORICO.some((e) => e.itens.some((it) => it.chave === c)));
  const presa = (dupla ? (itens.every(dominada) ? dominada(um) : null) : dominada(um)) || (ESQUEMA.mesmo_horario
    && (ESQUEMA.horario_das_areas || []).some((a) => a.chaves.includes(um.chave)) ? "Segue o horário da noite" : null);
  const classe = "linha" + (dupla ? " dupla" : "") + (l.sub ? " sub" : "")
    + (mudou ? " mudou" : "") + (presa ? " dominada" : "") + (l.larga ? " larga" : "");
  const frases = [...new Set(itens.map((i) => primeiraFrase(i.frase)).filter(Boolean))];
  const junta = frases.map((f, i) => `${COLUNAS[i]}: ${f}`).join(" ");
  const rot = elemento("div", { class: "rot" }, [
    elemento("span", { texto: l.r, dica: presa || (frases.length > 1 && dupla && junta.length <= 120
      ? junta : frases[0]) || null }),
  ]);
  if (!dupla) {
    for (const it of itens) {
      const aplica = (v) => escolher(it.chave, v);
      if (temOQueRestaurar(it, valorEmVigor(it))) rot.append(botaoPadrao(it, aplica));
      const auto = botaoAutomatico(it, valorEmVigor(it), aplica);
      if (auto) rot.append(auto);
    }
  }
  const li = elemento("li", { class: classe, "data-linha": chaves.join(" ") }, [rot]);
  if (dupla) {
    l.c.forEach((c, i) => {
      const it = CHAVE.get(c);
      const coluna = COLUNAS[i];
      const ctl = elemento("div", { class: "ctl", "data-coluna": coluna }, [it ? controle(it) : null]);
      if (it) {
        const presaDela = dominada(it);
        if (presaDela) {
          ctl.classList.add("desligado");
          ctl.setAttribute("data-dica", presaDela);
          for (const e of ctl.querySelectorAll("input, button, select")) e.disabled = true;
        }
        const aplica = (v) => escolher(it.chave, v);
        if (temOQueRestaurar(it, valorEmVigor(it))) ctl.append(botaoPadrao(it, aplica, coluna));
        const auto = botaoAutomatico(it, valorEmVigor(it), aplica, coluna);
        if (auto) ctl.append(auto);
      }
      li.append(ctl);
    });
  } else {
    li.append(elemento("div", { class: "ctl" }, [controle(um)]));
  }
  return li;
}

function motivoIndisponivel(acao) {
  const m = acao.indisponivel;
  if (!m) return "";
  if (m.porque) return maiuscula(m.porque);
  if (m.chave) {
    const l = inventarioDoPainel().find((x) => x.tipo === "chave" && x.id === m.chave);
    return `Vale com «${l ? l.rotulo : m.chave}» em ${rotuloDeValor(m.pede, CHAVE.get(m.chave))}`;
  }
  return "Sem efeito agora";
}

function controleDeAcao(acao, texto, classe = "pequeno") {
  const partes = [];
  let escolha = null;
  if (acao.opcoes && acao.opcoes.length) {
    escolha = elemento("select", { class: "campo", "aria-label": maiuscula(acao.rotulo), controle: "acao:" + acao.id + ":escolha" });
    for (const o of acao.opcoes) escolha.append(elemento("option", { value: o, texto: rotuloDeValor(o) }));
    partes.push(escolha);
  }
  const vazia = acao.arg && !escolha;
  const motivo = motivoIndisponivel(acao) || (vazia ? "Nada para escolher agora" : "");
  partes.push(botao(texto || maiuscula(acao.rotulo), {
    class: "bt " + classe + (acao.destrutivo ? " perigo" : ""),
    controle: "acao:" + acao.id, dica: motivo || primeiraFrase(acao.ajuda),
    disabled: !!motivo, "aria-disabled": motivo ? "true" : null,
    onclick: () => rodar(acao, escolha ? escolha.value : ""),
  }));
  if (RESTAUROS.has(acao.id) && acao.escreve) {
    partes.push(botao("Restaurar", { class: "bt " + classe, controle: "restaurar:" + acao.id,
      onclick: () => restaurarAcao(acao.id) }));
  }
  return partes;
}
function linhaDeAcao(l) {
  const acao = ACAO.get(l.a);
  if (!acao) return null;
  return elemento("li", { class: "linha", "data-linha": acao.id }, [
    elemento("div", { class: "rot" }, [elemento("span", { texto: l.r, dica: primeiraFrase(acao.ajuda) })]),
    elemento("div", { class: "ctl" }, controleDeAcao(acao, l.b)),
  ]);
}
function linha(l) {
  if (l.c) return linhaDeChave(l);
  if (l.a) return linhaDeAcao(l);
  if (l.g && l.g.startsWith("acervo:")) {
    return elemento("li", { class: "linha", "data-linha": l.g }, [
      elemento("div", { class: "rot" }, [elemento("span", { texto: l.r })]),
      elemento("div", { class: "ctl" }, [botaoAcervo(l.g.slice(7), l.b)]),
    ]);
  }
  return null;
}
function lista(linhas, pula = () => false) {
  const ul = elemento("ul", { class: "linhas" });
  for (const l of linhas) {
    if (pula(l)) continue;
    const li = linha(l);
    if (li) ul.append(li);
  }
  return ul;
}
function bloco(titulo, filhos, props = {}) {
  return elemento("section", { class: "bloco " + (props.class || ""), "data-bloco": titulo || null }, [
    titulo ? elemento("header", { class: props.colunas ? "dupla" : null }, [
      elemento("h2", { texto: titulo }),
      ...(props.colunas || []).map((c) => elemento("span", { texto: c })),
      ...(props.direita || []),
    ]) : null,
    ...[].concat(filhos),
  ]);
}
const ACERVO_ACEITA = {
  gato: ".svg,image/svg+xml", parede: "image/jpeg,image/png,image/webp", icone: ".svg,image/svg+xml",
  cursor: ".zip", fonte: ".zip,.ttf,.otf", "tema-icones": ".zip",
};
function lerComoBase64(arquivo) {
  return new Promise((ok, falha) => {
    const leitor = new FileReader();
    leitor.onerror = () => falha(new Error("Não consegui ler o arquivo"));
    leitor.onload = () => ok(String(leitor.result).split(",")[1] || "");
    leitor.readAsDataURL(arquivo);
  });
}
function botaoAcervo(tipo, texto, comoEscolha = false) {
  const campo = elemento("input", { type: "file", accept: ACERVO_ACEITA[tipo] || "", hidden: true,
    "data-acervo": tipo });
  const b = comoEscolha
    ? elemento("button", { type: "button", class: "escolha trazer", controle: "acervo:" + tipo,
        onclick: () => campo.click() }, [icone("mais"), elemento("span", { texto })])
    : botao(texto, { class: "bt pequeno", icone: "subir", controle: "acervo:" + tipo, onclick: () => campo.click() });
  campo.addEventListener("change", async () => {
    const arq = campo.files && campo.files[0];
    campo.value = "";
    if (!arq) return;
    b.dataset.estado = "carregando";
    try {
      const r = await api("/api/acervo", { method: "POST",
        body: JSON.stringify({ tipo, nome: arq.name, conteudo: await lerComoBase64(arq) }) });
      if (r.erro) { torrada(r.erro, "erro"); return; }
      torrada(`${r.nome || arq.name}: entrou`, "ok");
      for (const k of [...PREVIAS.keys()]) if (k.startsWith(tipo + "/")) PREVIAS.delete(k);
      if (tipo === "icone") APPS = null;
      await recarregarEsquema();
      render();
    } catch (e) {
      torrada(String(e.message || e), "erro");
    } finally {
      delete b.dataset.estado;
    }
  });
  return elemento("span", { style: "display:contents" }, [b, campo]);
}

function perguntar({ titulo, ok = "OK", perigo = false, corpo = null, ensaio = false }) {
  const d = $("#pergunta");
  $("#pergunta-titulo").textContent = maiuscula(titulo);
  $("#pergunta-corpo").replaceChildren(...(corpo ? [corpo] : []));
  $("#pergunta-corpo").hidden = !corpo;
  const sim = $("#pergunta-sim");
  sim.textContent = maiuscula(ok);
  sim.className = "bt " + (perigo ? "perigo" : "principal");
  $("#confirmar-ensaio").hidden = !ensaio;
  d.returnValue = "";
  d.showModal();
  return new Promise((resolver) => {
    d.addEventListener("close", () => resolver(d.returnValue === "seco" ? "seco" : d.returnValue === "sim"), { once: true });
  });
}

let TRABALHO = null;
let ULTIMO_TRABALHO = null;
const RESTAUROS = new Set();
function lerRestauros() {
  RESTAUROS.clear();
  for (const a of (ESQUEMA && ESQUEMA.acoes) || []) if (a.restauro) RESTAUROS.add(a.id);
}
const deRoot = (a) => !!(a && (a.sudo || a.pela_ponte));

async function semPonte() {
  const ok = await perguntar({ titulo: "Falta a ponte", ok: "Consertar a ponte" });
  if (ok) rodar(ACAO.get("doctor_consertar"), "");
}

async function esperarOSinoGravado() {
  await FILA_DE_GRAVACAO;
  return !CHAVES_DO_SINO.some((chave) => MUDANCAS.has(chave));
}

async function rodar(acao, argumento = "", opcoes = {}) {
  if (!acao) return null;
  if (acao.id === "som_aplicar" && !(await esperarOSinoGravado())) return null;
  if (TRABALHO && TRABALHO.timer) { torrada("Espere o trabalho terminar"); abrirJanela(); return null; }
  if (deRoot(acao) && !ESQUEMA.ponte) { await semPonte(); return null; }
  let seco = false;
  if (acao.confirma && !opcoes.semPerguntar) {
    const ok = await perguntar({ titulo: maiuscula(acao.rotulo) + "?", ok: opcoes.verbo || acao.rotulo,
      perigo: !!acao.destrutivo, ensaio: !!acao.escreve });
    if (!ok) return null;
    seco = ok === "seco";
  }
  const r = await api("/api/rodar", { method: "POST",
    body: JSON.stringify({ acao: acao.id, argumento, confirmado: true, seco }) });
  if (r.erro) { torrada(r.erro, "erro"); return null; }
  abrirResultado(r, opcoes.depois || null,
    seco ? () => rodar(acao, argumento, { ...opcoes, semPerguntar: true }) : null);
  return r;
}
async function rodarAcao(id, argumento = "") {
  return rodar(ACAO.get(id), argumento, { semPerguntar: true });
}
async function restaurarAcao(id) {
  const r = await api("/api/rodar", { method: "POST",
    body: JSON.stringify({ acao: "restaurar", argumento: id, confirmado: true }) });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  abrirResultado(r);
  if (TRABALHO) TRABALHO.restaura = id;
}
function fimDoTrabalho() {
  return new Promise((ok) => {
    const ver = () => (TRABALHO && TRABALHO.timer ? setTimeout(ver, 300) : ok());
    ver();
  });
}

function abrirJanela() {
  const d = $("#resultado");
  if (!d.open) d.showModal();
  pastilhaDeTrabalho(false);
}
function marcarEstado(estado, texto) {
  const el = $("#resultado-estado");
  el.dataset.estado = estado;
  el.textContent = maiuscula(texto);
}
function abrirResultado(trabalho, depois = null, deVerdade = null) {
  if (TRABALHO && TRABALHO.timer) clearInterval(TRABALHO.timer);
  TRABALHO = { id: trabalho.id, proximo: 0, timer: null, escreve: trabalho.escreve, rotulo: maiuscula(trabalho.rotulo),
               acao: trabalho.acao || null, fim: trabalho.fim || {}, mudou: false, depois,
               conserta: trabalho.conserta_com || null, seco: !!trabalho.seco, deVerdade };
  ULTIMO_TRABALHO = { id: trabalho.id, acao: trabalho.acao || null };
  $("#resultado-titulo").textContent = maiuscula(trabalho.rotulo || "Trabalho");
  $("#saida").replaceChildren();
  $("#registro").open = false;
  $("#parar").hidden = false;
  $("#resultado-restaurar").hidden = true;
  $("#faixa-ensaio").hidden = !trabalho.seco;
  $("#ensaio-rodar").hidden = true;
  delete $("#resultado-guardar").dataset.estado;
  for (const v of document.querySelectorAll("#resultado .consertar")) v.remove();
  marcarEstado("correndo", "Rodando");
  abrirJanela();
  TRABALHO.timer = setInterval(puxar, 400);
  puxar();
}
function classeDaLinha(l) {
  const t = l.trimStart();
  if (/^ok\b/.test(t)) return "ok";
  if (/^(erro|FALHOU|falhou|!!)/.test(t)) return "erro";
  if (t.startsWith("~~")) return "mudou";
  return "";
}
async function puxar() {
  const t = TRABALHO;
  if (!t) return;
  const desde = t.proximo;
  const r = await api(`/api/trabalho?id=${t.id}&desde=${desde}`);
  if (TRABALHO !== t || t.proximo !== desde) return;
  if (r.erro) { clearInterval(t.timer); t.timer = null; TRABALHO = null; pastilhaDeTrabalho(false); return; }
  t.proximo = r.proximo;
  const saida = $("#saida");
  for (const l of r.linhas || []) {
    saida.append(elemento("span", { class: classeDaLinha(l) || null, texto: l + "\n" }));
    if (l.trimStart().startsWith("~~")) t.mudou = true;
  }
  saida.scrollTop = saida.scrollHeight;
  if (r.vivo) return;
  clearInterval(t.timer);
  t.timer = null;
  $("#parar").hidden = true;
  if (r.restauravel && t.acao) RESTAUROS.add(t.acao);
  if (t.acao === "restaurar" && (r.rc === 0 || r.rc === 1)) RESTAUROS.delete(t.restaura);
  $("#resultado-restaurar").hidden = !(r.restauravel && t.acao);
  const tabela = t.fim || {};
  const [classe, frase] = (r.rc === 0 && t.mudou && tabela["0~"]) || tabela[String(r.rc)] || ["erro", `Saiu ${r.rc}`];
  marcarEstado(classe === "ok" ? "ok" : classe === "erro" ? "erro" : "correndo", `${maiuscula(frase)} · ${r.segundos}s`);
  if (classe === "erro") $("#registro").open = true;
  if (r.rc === 1 && t.conserta && ACAO.get(t.conserta)) {
    const a = ACAO.get(t.conserta);
    $("#resultado .acoes").prepend(botao(maiuscula(a.rotulo), { class: "bt consertar", controle: "resultado:consertar",
      onclick: () => { $("#resultado").close(); rodar(a, ""); } }));
  }
  if (t.seco && t.deVerdade && typeof r.rc === "number" && r.rc >= 0) {
    const b = $("#ensaio-rodar");
    b.hidden = false;
    b.onclick = () => { $("#resultado").close(); t.deVerdade(); };
  }
  if (!$("#resultado").open) torrada(`${t.rotulo}: ${frase}`, classe === "erro" ? "erro" : "ok");
  pastilhaDeTrabalho(false);
  TRABALHO = null;
  if (t.escreve && !t.seco) await depoisDeEscrever();
  if (t.depois && (r.rc === 0 || r.rc === 1)) t.depois();
}
async function depoisDeEscrever() {
  for (const k of [...PREVIAS.keys()]) if (/^(icone|parede|gato)\//.test(k)) PREVIAS.delete(k);
  APPS = null;
  JOGOS = null;
  await Promise.all([recarregarEsquema(), recarregarPacks(), recarregarPendencias()]);
  lerRestauros();
  repintarPaleta();
  render();
}
function repintarPaleta() {
  const folha = document.querySelector('link[rel="stylesheet"][href^="/paleta.css"]');
  if (!folha) return;
  folha.addEventListener("load", () => { lerClaro(); render(); }, { once: true });
  folha.href = `/paleta.css?v=${Date.now()}`;
}
function lerClaro() {
  const esquema = getComputedStyle(document.documentElement).colorScheme || "";
  if (esquema.includes("light")) document.documentElement.dataset.claro = "1";
  else delete document.documentElement.dataset.claro;
}
function pastilhaDeTrabalho(mostrar) {
  let p = document.getElementById("pastilha-trabalho");
  if (!mostrar) { if (p) p.remove(); return; }
  if (p || !TRABALHO) return;
  p = botao(TRABALHO.rotulo || "Trabalho", { class: "bt pequeno", id: "pastilha-trabalho",
    controle: "trabalho", icone: "girar", onclick: abrirJanela });
  $("#aplicar").before(p);
}

function atualizarAplicar() {
  const n = HISTORICO.length;
  $("#aplicar").dataset.n = String(n);
  $("#conta").textContent = n === 1 ? "1 mudança" : `${n} mudanças`;
  const caixa = $("#ultimas");
  if (!n) { caixa.hidden = true; $("#conta").setAttribute("aria-expanded", "false"); }
  caixa.replaceChildren(...HISTORICO.map((e) => elemento("div", { class: "ultima", role: "listitem" }, [
    elemento("span", {}, [elemento("b", { texto: e.rotulo }), elemento("small", { texto: e.detalhe })]),
    botao("Desfazer", { class: "bt leve pequeno", controle: "desfazer-uma", icone: "desfazer",
      onclick: () => desfazerEntradas([e]) }),
  ])));
}
function nomeDeChave(chave) {
  const l = inventarioDoPainel().find((x) => x.tipo === "chave" && x.id === chave);
  return l ? l.rotulo : ((CHAVE.get(chave) || {}).titulo || chave);
}
function fecharUltimas() {
  $("#ultimas").hidden = true;
  $("#conta").setAttribute("aria-expanded", "false");
}
function alternarUltimas() {
  const caixa = $("#ultimas");
  if (!HISTORICO.length) return;
  caixa.hidden = !caixa.hidden;
  $("#conta").setAttribute("aria-expanded", String(!caixa.hidden));
}

async function importarArquivo(arquivo) {
  if (!arquivo) return;
  if (arquivo.size > 512 * 1024) { torrada("Arquivo grande demais", "erro"); return; }
  let texto;
  try { texto = await arquivo.text(); } catch { torrada("Não consegui ler o arquivo", "erro"); return; }
  const r = await api("/api/importar", { method: "POST", body: JSON.stringify({ texto }) });
  if (r.erro) { torrada(r.erro, "erro"); return; }
  const n = (r.mudam || []).length;
  for (const rec of (r.recusadas || []).slice(0, 3)) torrada(`${nomeDeChave(rec.chave)}: ${rec.erro}`, "erro");
  if (n) await gravarAgora(Object.fromEntries(r.mudam.map((m) => [m.chave, m.valor])));
  else torrada("Nada mudou");
}

function indiceDaBusca() {
  const onde = (l) => (l.porta === "tema" ? "Tema" : l.porta === "cuidar" ? "Manter"
    : l.porta === "criar" ? "Personalizar · " + l.pagina : "Definir · " + l.pagina);
  const visto = new Set();
  const saida = [];
  for (const l of inventarioDoPainel()) {
    if (l.porta === "topo" || l.porta === "janela" || (l.tipo === "chave" && !CHAVE.has(l.id)) || (l.tipo === "acao" && !ACAO.has(l.id))) continue;
    const k = l.porta + l.pagina + l.rotulo;
    if (visto.has(k)) continue;
    visto.add(k);
    const extra = l.tipo === "chave" ? (CHAVE.get(l.id).titulo || "") : l.tipo === "acao" ? ACAO.get(l.id).rotulo : "";
    saida.push({ ...l, onde: onde(l), busca: semAcento(l.rotulo + " " + extra + " " + l.pagina) });
  }
  return saida;
}
function procurar() {
  const caixa = $("#busca").parentElement;
  const q = semAcento($("#busca").value.trim());
  const achados = $("#achados");
  achados.replaceChildren();
  if (!q) { caixa.classList.remove("aberta"); $("#busca").setAttribute("aria-expanded", "false"); return; }
  const lista = indiceDaBusca().filter((x) => x.busca.includes(q)).slice(0, 8);
  if (!lista.length) achados.append(elemento("div", { class: "nada", texto: "Nada com esse nome" }));
  for (const x of lista) {
    achados.append(elemento("button", { type: "button", role: "option", controle: "achado",
      onclick: () => { $("#busca").value = ""; procurar(); irPara(x); } },
      [elemento("span", { texto: x.rotulo }), elemento("small", { texto: x.onde })]));
  }
  caixa.classList.add("aberta");
  $("#busca").setAttribute("aria-expanded", "true");
}
function ligarBusca() {
  const campo = $("#busca");
  campo.addEventListener("input", procurar);
  campo.addEventListener("keydown", (ev) => {
    const itens = [...document.querySelectorAll("#achados button")];
    const i = itens.findIndex((b) => b.classList.contains("vez"));
    if (ev.key === "ArrowDown" || ev.key === "ArrowUp") {
      ev.preventDefault();
      if (!itens.length) return;
      const j = ev.key === "ArrowDown" ? Math.min(itens.length - 1, i + 1) : Math.max(0, i - 1);
      itens.forEach((b, k) => b.classList.toggle("vez", k === j));
    } else if (ev.key === "Enter") {
      ev.preventDefault();
      const alvo = itens[i] || itens[0];
      if (alvo) alvo.click();
    } else if (ev.key === "Escape") {
      campo.value = ""; procurar(); campo.blur();
    }
  });
  const caixa = campo.parentElement;
  const abrirCampo = () => { caixa.classList.add("campo-aberto"); campo.focus(); };
  $("#abrir-busca").addEventListener("click", abrirCampo);
  campo.addEventListener("blur", () => setTimeout(() => {
    if ($("#achados").contains(document.activeElement)) return;
    caixa.classList.remove("aberta", "campo-aberto");
  }, 150));
  document.addEventListener("keydown", (ev) => {
    if (ev.key === "/" && !/^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement.tagName)) {
      ev.preventDefault();
      abrirCampo();
    }
  });
}
let CHEGADA = null;
function reacenderChegada() {
  if (!CHEGADA || Date.now() > CHEGADA.ate) { CHEGADA = null; return; }
  const alvo = [...document.querySelectorAll("#conteudo [data-linha]")]
    .find((el) => el.dataset.linha.split(" ").includes(CHEGADA.id));
  if (alvo) alvo.classList.add("chegou");
}
function irPara(l) {
  const sub = l.porta === "ajustes" ? (AJUSTES.find((p) => p.nome === l.pagina) || {}).id
    : l.porta === "criar" ? (PASSOS.find((p) => p.nome === l.pagina) || {}).id : "";
  const hash = "#" + l.porta + (sub ? "/" + sub : "");
  if (location.hash !== hash) history.pushState(null, "", hash);
  ROTA = rotaDoHash();
  render();
  requestAnimationFrame(() => {
    const alvo = [...document.querySelectorAll("#conteudo [data-linha]")]
      .find((el) => el.dataset.linha.split(" ").includes(l.id));
    if (!alvo) return;
    alvo.scrollIntoView({ block: "center" });
    CHEGADA = { id: l.id, ate: Date.now() + 2600 };
    alvo.classList.add("chegou");
    const foco = alvo.querySelector("button, input, select");
    if (foco) foco.focus({ preventScroll: true });
  });
}

function rotaDoHash() {
  const [porta, sub] = decodeURIComponent(location.hash.replace(/^#/, "")).split("/");
  if (!PORTAS.some((p) => p.id === porta)) return { porta: "tema", sub: "" };
  if (porta === "ajustes") return { porta, sub: AJUSTES.some((p) => p.id === sub) ? sub : AJUSTES[0].id };
  if (porta === "criar") return { porta, sub: PASSOS.some((p) => p.id === sub) ? sub : PASSOS[0].id };
  if (porta === "extensoes") return { porta, sub: sub === "builds" ? "builds" : "applets" };
  return { porta, sub: "" };
}
function desenharPortas() {
  $("#portas").replaceChildren(...PORTAS.map((p) => elemento("li", {}, [
    elemento("a", { href: "#" + p.id, controle: "porta:" + p.id, "aria-current": ROTA.porta === p.id ? "page" : null },
      [icone(p.icone), elemento("span", { texto: p.nome })]),
  ])));
}
function desenharMenu() {
  const itens = [];
  itens.push(elemento("button", { type: "button", role: "menuitem", controle: "menu:creditos", texto: "Créditos",
    onclick: () => { $("#menu").open = false; abrirCreditos(); } }));
  itens.push(elemento("a", { href: "/api/exportar/pagina", download: true, role: "menuitem",
    controle: "menu:pagina", texto: "Esta tela num arquivo" }));
  $("#menu-corpo").replaceChildren(...itens);
}

function render() {
  if (!ESQUEMA || ESQUEMA.erro) return;
  const ativo = document.activeElement;
  const foco = ativo && ativo.dataset && $("#conteudo").contains(ativo) ? ativo.dataset.controle : null;
  desenharPortas();
  $("#abas").hidden = ROTA.porta !== "ajustes" && ROTA.porta !== "extensoes";
  const pagina = ROTA.porta === "criar" ? paginaCriar(ROTA.sub)
    : ROTA.porta === "ajustes" ? paginaAjustes(ROTA.sub)
    : ROTA.porta === "cuidar" ? paginaCuidar()
    : ROTA.porta === "extensoes" ? paginaExtensoes(ROTA.sub) : paginaTema();
  $("#conteudo").replaceChildren(...[].concat(pagina).filter(Boolean));
  $("#conteudo").removeAttribute("aria-busy");
  reacenderChegada();
  document.title = "MeowSystem · " + (PORTAS.find((p) => p.id === ROTA.porta) || PORTAS[0]).nome;
  if (foco) {
    const alvo = [...document.querySelectorAll("#conteudo [data-controle]")].find((el) => el.dataset.controle === foco);
    if (alvo) alvo.focus({ preventScroll: true });
  }
}

async function iniciar() {
  const [esquema] = await Promise.all([api("/api/esquema"), recarregarPendencias(), recarregarPacks()]);
  ESQUEMA = esquema;
  if (ESQUEMA.erro) {
    $("#conteudo").replaceChildren(elemento("h1", { texto: maiuscula(ESQUEMA.erro) }));
    return;
  }
  await lerRascunhoDoServidor();
  indexar();
  lerRestauros();
  lerClaro();
  atualizarAplicar();
  ligarDicas();
  ligarBusca();
  desenharMenu();
  $(".pular").addEventListener("click", (ev) => { ev.preventDefault(); $("#principal").focus(); });
  $("#desfazer").addEventListener("click", desfazerTudo);
  $("#conta").addEventListener("click", alternarUltimas);
  const menu = $("#menu");
  document.addEventListener("click", (e) => {
    if (menu.open && !menu.contains(e.target)) menu.open = false;
    if (!$("#aplicar").contains(e.target)) fecharUltimas();
  });
  document.addEventListener("keydown", (e) => {
    if (e.key !== "Escape") return;
    if (menu.open) { menu.open = false; menu.querySelector("summary").focus(); }
    fecharUltimas();
  });
  $("#resultado").addEventListener("close", () => { if (TRABALHO && TRABALHO.timer) pastilhaDeTrabalho(true); });
  $("#resultado-ok").addEventListener("click", () => $("#resultado").close());
  $("#parar").addEventListener("click", async () => {
    if (!TRABALHO) return;
    await api("/api/parar", { method: "POST", body: JSON.stringify({ id: TRABALHO.id }) });
  });
  $("#resultado-guardar").addEventListener("click", async () => {
    if (!ULTIMO_TRABALHO) return;
    const r = await api("/api/guardar-log", { method: "POST", body: JSON.stringify({ id: ULTIMO_TRABALHO.id }) });
    if (r.erro) { torrada(r.erro, "erro"); return; }
    $("#resultado-guardar").dataset.estado = "feito";
    $("#resultado-guardar").dataset.dica = maiuscula(r.caminho || "");
  });
  $("#resultado-restaurar").addEventListener("click", () => {
    if (ULTIMO_TRABALHO && ULTIMO_TRABALHO.acao) restaurarAcao(ULTIMO_TRABALHO.acao);
  });
  addEventListener("beforeunload", (ev) => { if (EM_VOO > 0) ev.preventDefault(); });
  ROTA = rotaDoHash();
  addEventListener("hashchange", () => { ROTA = rotaDoHash(); render(); scrollTo(0, 0); });
  addEventListener("popstate", () => { ROTA = rotaDoHash(); render(); });
  render();
}

try {
  const pulso = new EventSource("/api/pulso");
  pulso.onerror = () => {};
} catch (e) { }

iniciar();

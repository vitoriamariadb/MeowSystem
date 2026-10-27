const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

const ESTADOS = ["normal", "vazio", "carregando", "erro", "sem-ponte"];
function lerEstado() {
  const m = /estado=([a-z-]+)/.exec(location.hash);
  const e = m && ESTADOS.includes(m[1]) ? m[1] : "normal";
  document.body.dataset.estado = e;
  for (const el of $$("[data-so]")) el.hidden = !el.dataset.so.split(" ").includes(e);
  for (const el of $$("[data-nao]")) el.hidden = el.dataset.nao.split(" ").includes(e);
}

function torrada(texto, classe = "") {
  const t = document.createElement("div");
  t.className = "torrada " + classe;
  t.textContent = texto;
  $("#torradas").append(t);
  setTimeout(() => t.remove(), 3200);
}

let MUDANCAS = $$("#ultimas .ultima").map((u) => ({ r: $("b", u).textContent, d: $("small", u).textContent }));
function pintarMudancas() {
  const n = MUDANCAS.length;
  $("#aplicar").dataset.n = String(n);
  $("#conta").textContent = n === 1 ? "1 mudança" : `${n} mudanças`;
  const lista = $("#ultimas");
  lista.replaceChildren(...MUDANCAS.slice(0, 20).map((m, i) => {
    const u = document.createElement("div");
    u.className = "ultima";
    u.setAttribute("role", "listitem");
    u.innerHTML = `<span><b></b><small></small></span><button type="button" class="bt leve pequeno" data-controle="desfazer-uma">${$("#desfazer svg").outerHTML}Desfazer</button>`;
    $("b", u).textContent = m.r;
    $("small", u).textContent = m.d;
    $("button", u).onclick = () => { MUDANCAS.splice(i, 1); gravar(); pintarMudancas(); };
    return u;
  }));
  if (!n) { lista.hidden = true; $("#conta").setAttribute("aria-expanded", "false"); }
}
function gravar(falha = false) {
  const g = $("#gravando");
  g.dataset.estado = "gravando";
  g.setAttribute("aria-label", "Gravando");
  setTimeout(() => {
    g.dataset.estado = falha ? "erro" : "ok";
    g.setAttribute("aria-label", falha ? "Não gravou" : "Gravado");
  }, 700);
}
function anotar(rotulo, de, para) {
  const velha = MUDANCAS.findIndex((m) => m.r === rotulo);
  if (velha >= 0) {
    de = MUDANCAS[velha].d.split(" → ")[0];
    MUDANCAS.splice(velha, 1);
  }
  if (de !== para) MUDANCAS.unshift({ r: rotulo, d: `${de} → ${para}` });
  MUDANCAS = MUDANCAS.slice(0, 20);
  gravar(document.body.dataset.estado === "erro");
  pintarMudancas();
}

function moldura() {
  $("#conta").onclick = () => {
    const l = $("#ultimas");
    l.hidden = !l.hidden;
    $("#conta").setAttribute("aria-expanded", String(!l.hidden));
  };
  $("#desfazer").onclick = () => {
    if (!MUDANCAS.length) return;
    MUDANCAS.shift();
    gravar();
    pintarMudancas();
  };
  document.addEventListener("click", (e) => {
    if (!e.target.closest("#aplicar")) { $("#ultimas").hidden = true; $("#conta").setAttribute("aria-expanded", "false"); }
    if (!e.target.closest("#menu")) $("#menu").open = false;
    if (!e.target.closest("#caixa-busca")) fecharBusca();
  });
  const caixa = $("#caixa-busca");
  const abrir = () => { caixa.classList.add("campo-aberto"); $("#busca").focus(); };
  $("#abrir-busca").onclick = abrir;
  document.addEventListener("keydown", (e) => {
    if (e.key === "/" && !/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)) { e.preventDefault(); abrir(); }
    if (e.key === "Escape") fecharBusca();
  });
  $("#busca").addEventListener("input", procurar);
  $("#resultado-ok").onclick = () => $("#resultado").close();
  $("#parar").onclick = () => { pararTrabalho(); };
  $("#resultado-guardar").onclick = () => { $("#resultado-guardar").dataset.estado = "feito"; };
  for (const b of $$("[data-controle='creditos'], [data-controle='exportar-pagina']")) b.onclick = () => { $("#menu").open = false; torrada(b.textContent.trim(), "ok"); };
  pintarMudancas();
}
function fecharBusca() {
  const caixa = $("#caixa-busca");
  caixa.classList.remove("campo-aberto", "aberta");
}
const ACHAVEIS = [
  ["Solta da borda", "Painel e dock", "definir.html#painel"],
  ["Em pastilha", "Painel e dock", "definir.html#painel"],
  ["Cantos", "Painel e dock", "definir.html#painel"],
  ["Segundos no relógio", "Painel e dock", "definir.html#painel"],
  ["Lado a lado", "Janelas e tela", "definir.html#janelas"],
  ["Ponteiro", "Janelas e tela", "definir.html#janelas"],
  ["Próxima imagem", "Papel de parede", "definir.html#papel"],
  ["Mascote na dock", "Mascote", "definir.html#mascote"],
  ["Modo de leitura", "Dia e noite", "definir.html#noite"],
  ["Quão quente", "Dia e noite", "definir.html#noite"],
  ["Cor do cursor", "Terminal", "definir.html#terminal"],
  ["Escondidos", "Programas", "definir.html#programas"],
  ["Não abrem sozinhos", "Programas", "definir.html#programas"],
  ["Conferir todo dia", "Manter", "manter.html"],
  ["Cópias guardadas", "Manter", "manter.html"],
  ["Cor de destaque", "Tema", "tema.html"],
];
function procurar() {
  const q = $("#busca").value.trim().toLowerCase();
  const caixa = $("#caixa-busca");
  const achados = $("#achados");
  if (!q) { caixa.classList.remove("aberta"); return; }
  const lista = ACHAVEIS.filter(([r]) => r.toLowerCase().includes(q)).slice(0, 8);
  achados.replaceChildren(...(lista.length ? lista.map(([r, p, h]) => {
    const b = document.createElement("button");
    b.type = "button";
    b.setAttribute("role", "option");
    b.innerHTML = "<span></span><small></small>";
    b.firstChild.textContent = r;
    b.lastChild.textContent = p;
    b.onclick = () => { location.href = h; fecharBusca(); };
    return b;
  }) : [Object.assign(document.createElement("div"), { className: "nada", textContent: "Nada com esse nome" })]));
  caixa.classList.add("aberta");
}

let TRABALHO = null;
const LOG_INSTALAR = [
  "== Instalar tudo",
  "ok  tema do COSMIC: mocha mauve",
  "ok  ícones: 82 apps, 41 do sistema",
  "~~  painel e dock: Solta da borda (dock) sim → não",
  "ok  terminal: cores do tema",
  "ok  mascote: coquinha na dock",
  "~~  papel de parede: carrossel a cada 30 min",
  "ok  login: cosmic-greeter vestido",
  "ok  hicolor: nada a mudar",
  "ok  " + "~/.local/share/meowsystem/estado/".repeat(6) + "icones-resgatados.tsv",
  "erro  " + "x".repeat(200),
  "ok  temas de apps: 23 de 27",
];
function abrirTrabalho(titulo, { erro = false, restauravel = false, linhas = LOG_INSTALAR } = {}) {
  const d = $("#resultado");
  $("#resultado-titulo").textContent = titulo;
  $("#saida").replaceChildren();
  $("#registro").open = false;
  $("#parar").hidden = false;
  $("#resultado-restaurar").hidden = true;
  delete $("#resultado-guardar").dataset.estado;
  marcar("correndo", "Rodando");
  if (!d.open) d.showModal();
  let i = 0;
  clearInterval(TRABALHO);
  TRABALHO = setInterval(() => {
    if (i < linhas.length) {
      const l = linhas[i++];
      const s = document.createElement("span");
      if (/^ok\b/.test(l)) s.className = "ok";
      else if (/^erro/.test(l)) s.className = "erro";
      else if (l.startsWith("~~")) s.className = "mudou";
      s.textContent = l + "\n";
      $("#saida").append(s);
      return;
    }
    clearInterval(TRABALHO);
    TRABALHO = null;
    $("#parar").hidden = true;
    $("#resultado-restaurar").hidden = !restauravel;
    if (erro) { marcar("erro", "Falhou · 4.1s"); $("#registro").open = true; }
    else marcar("ok", "Pronto · 4.1s");
  }, 220);
}
function pararTrabalho() {
  clearInterval(TRABALHO);
  TRABALHO = null;
  $("#parar").hidden = true;
  marcar("erro", "Parado");
}
function marcar(estado, texto) {
  const el = $("#resultado-estado");
  el.dataset.estado = estado;
  el.textContent = texto;
}
async function perguntar(titulo, ok, perigo = false) {
  const d = $("#pergunta");
  $("#pergunta-titulo").textContent = titulo;
  const sim = $("#pergunta-sim");
  sim.textContent = ok;
  sim.className = "bt " + (perigo ? "perigo" : "principal");
  d.returnValue = "";
  d.showModal();
  return new Promise((r) => d.addEventListener("close", () => r(d.returnValue === "sim"), { once: true }));
}
async function semPonte() {
  const d = $("#pergunta");
  $("#pergunta-titulo").textContent = "Falta a ponte";
  const sim = $("#pergunta-sim");
  sim.className = "bt principal";
  sim.innerHTML = "";
  sim.append(document.createRange().createContextualFragment('<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M2 18h20M4 18V9M20 18V9M4 9c4 4 12 4 16 0M9 13v5M15 13v5"/></svg>'), "Consertar a ponte");
  d.returnValue = "";
  d.showModal();
  d.addEventListener("close", () => { if (d.returnValue === "sim") abrirTrabalho("Consertar a ponte", { linhas: ["== Consertar a ponte", "ok  regra do polkit no lugar", "ok  serviço da ponte de pé", "ok  ponte responde"] }); }, { once: true });
}
async function rodarAcao(b) {
  const titulo = b.dataset.titulo || b.textContent.trim();
  if (b.dataset.root !== undefined && document.body.dataset.estado === "sem-ponte") { semPonte(); return; }
  if (b.dataset.confirma !== undefined) {
    const ok = await perguntar(titulo + "?", b.dataset.verbo || titulo, b.dataset.perigo !== undefined);
    if (!ok) return;
  }
  abrirTrabalho(titulo, { erro: document.body.dataset.estado === "erro", restauravel: b.dataset.restauravel !== undefined });
}

window.addEventListener("hashchange", lerEstado);
document.addEventListener("DOMContentLoaded", () => {
  lerEstado();
  moldura();
  for (const b of $$("[data-acao]")) b.addEventListener("click", () => rodarAcao(b));
  if (typeof pagina === "function") pagina();
});

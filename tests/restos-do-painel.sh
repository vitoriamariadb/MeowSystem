#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PAG="$RAIZ/app/pagina"
ARQS=(lugares.js mesa.js oficina.js paginas.js app.js)
for a in "${ARQS[@]}"; do [ -f "$PAG/$a" ] || { printf 'FALHOU: não achei app/pagina/%s\n' "$a" >&2; exit 2; }; done

falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

nomes="$(cd "$PAG" && grep -ho '^\(async \)\?function [A-Za-z0-9_$]*' "${ARQS[@]}" | sed 's/^async //')"
total="$(printf '%s\n' "$nomes" | grep -c .)"
repetidas="$(printf '%s\n' "$nomes" | sort | uniq -d)"
fim="$(printf '%s\n' "$nomes" | grep -cx 'function fimDoTrabalho')"
if [ -z "$repetidas" ] && [ "$fim" = 1 ]; then
  ok "no topo dos ${#ARQS[@]} arquivos da página, $total funções e um nome por função"
else
  falha "a página declara no topo o mesmo nome mais de uma vez" "repetidas: $repetidas"
fi

NODE="$(command -v node || true)"
if [ -z "$NODE" ]; then
  [ "$falhas" -eq 0 ] || exit 1
  printf 'pulado: sem node — o parser do V8 e a ficha no vm ficaram de fora\n'
  exit 3
fi

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
(cd "$PAG" && cat "${ARQS[@]}") > "$T/pagina.mjs"
if saida="$("$NODE" --check "$T/pagina.mjs" 2>&1)"; then
  ok "o parser do V8, lendo a página inteira como módulo, não acha declaração repetida no topo"
else
  falha "o parser do V8 recusa a página lida como módulo" "$(printf '%s\n' "$saida" | head -3)"
fi

"$NODE" - "$PAG" "${ARQS[@]}" <<'JS'
"use strict";
const fs = require("fs"), vm = require("vm"), path = require("path");
const falhas = [];
const ok = (frase) => console.log("ok: " + frase);
const checa = (cond, frase, detalhe) => {
  if (cond) ok(frase); else falhas.push(frase + (detalhe ? " — " + detalhe : ""));
  return cond;
};
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));
process.on("unhandledRejection", () => {});

/* O DOM DE MENTIRA: só o que os construtores usam. Um toco responde ao resto. */
const toco = new Proxy(function () {}, {
  get(_a, k) {
    if (k === "then") return undefined;
    if (k === Symbol.toPrimitive) return () => "";
    if (k === Symbol.iterator) return function* () {};
    return toco;
  },
  apply() { return toco; }, construct() { return toco; }, set() { return true; },
});
const camelo = (s) => s.replace(/-([a-z])/g, (_m, c) => c.toUpperCase());
class El {
  constructor(tag) {
    this.tagName = String(tag).toUpperCase();
    this.filhos = []; this.attrs = {}; this.dataset = {}; this.ouvintes = {};
    this.className = ""; this._texto = ""; this.hidden = false; this.disabled = false;
    this.style = { setProperty() {}, cssText: "" }; this.classList = { add() {}, remove() {}, toggle() {}, contains: () => false };
  }
  set textContent(v) { this._texto = String(v); this.filhos = []; }
  get textContent() { return this._texto + this.filhos.map((f) => (f instanceof El ? f.textContent : String(f))).join(""); }
  set innerHTML(v) { this.html = v; }
  setAttribute(k, v) {
    this.attrs[k] = String(v);
    if (k.startsWith("data-")) this.dataset[camelo(k.slice(5))] = String(v);
  }
  getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; }
  removeAttribute(k) { delete this.attrs[k]; }
  addEventListener(ev, fn) { (this.ouvintes[ev] = this.ouvintes[ev] || []).push(fn); }
  append(...fs) { for (const f of fs) this.filhos.push(f); }
  prepend(...fs) { this.filhos.unshift(...fs); }
  get children() { return this.filhos.filter((f) => f instanceof El); }
  replaceChildren(...fs) { this.filhos = fs; }
  todos() { return this.children.flatMap((f) => [f, ...f.todos()]); }
  querySelectorAll() { return []; }
  querySelector() { return null; }
  clicar() { return Promise.all((this.ouvintes.click || []).map((fn) => fn({ target: this, preventDefault() {}, stopPropagation() {} }))); }
}
const documento = {
  createElement: (tag) => new El(tag), createElementNS: (_ns, tag) => new El(tag),
  body: Object.assign(new El("body"), { dataset: { token: "brinquedo" } }),
  documentElement: new El("html"),
  querySelector: () => new El("div"), querySelectorAll: () => [], addEventListener() {},
};
const ctx = vm.createContext({
  document: documento, location: { search: "", hash: "", pathname: "/" },
  history: toco, window: toco, navigator: toco, localStorage: toco, sessionStorage: toco,
  EventSource: toco, matchMedia: toco, requestAnimationFrame: toco, getComputedStyle: () => ({ colorScheme: "dark" }),
  addEventListener() {}, fetch: () => new Promise(() => {}),
  console, setTimeout, clearTimeout, setInterval, clearInterval, URLSearchParams,
});
const [pasta, ...arquivos] = process.argv.slice(2);
vm.runInContext(arquivos.map((a) => fs.readFileSync(path.join(pasta, a), "utf8")).join("\n;\n"), ctx, { filename: "pagina.js" });
const js = (codigo) => vm.runInContext(codigo, ctx);

const chamadas = { api: [], torradas: [], acoes: [], releituras: 0 };
let respostas = () => ({});
js("render = () => {}; oficinaDeDesenho = () => document.createElement('details');");
ctx.__api = async (rota, opcoes = {}) => {
  chamadas.api.push({ rota, corpo: opcoes.body ? JSON.parse(opcoes.body) : null });
  return respostas(rota, opcoes);
};
ctx.__torrada = (texto, classe) => chamadas.torradas.push({ texto, classe });
ctx.__acao = async (id) => { chamadas.acoes.push(id); };
js("api = (...a) => __api(...a); torrada = (...a) => __torrada(...a); rodarAcao = (...a) => __acao(...a);");
js(`ESQUEMA = { paleta: { ordem: ["mauve"], flavors: { dracula: { mauve: "#BD93F9" } } }, pack: { flavor_padrao: "dracula", flavors: [] }, chaves: [], acoes: [] }`);
const zerar = () => {
  chamadas.api.length = 0; chamadas.torradas.length = 0; chamadas.acoes.length = 0;
  chamadas.releituras = 0; js("TRABALHO = null; APP_ABERTO = null");
};
const PACK = { glifo: "alien", grupo: "pack:dracula:biblioteca", tipo: "desenho", arquivo: "packs/dracula/icones/biblioteca/alien.svg", url: "/previa?x" };
const TRACO = { glifo: "google-chrome", grupo: "motor:arcticons-apps", tipo: "traco", arquivo: "packs/meowsystem/icones/apps/google-chrome.svg", url: "/previa?y" };
const GRUPOS = [
  { id: "pack:dracula:biblioteca", acervo: "Dracula", nome: "biblioteca", no_ar: true, total: 1, achados: 1 },
  { id: "motor:arcticons-apps", acervo: "MeowSystem", nome: "traço", no_ar: false, total: 1, achados: 1 }];
const glifos = (extra) => js(`GLIFOS = ${JSON.stringify(Object.assign({
  termo: "chrome", app: "google-chrome", itens: [PACK, TRACO], grupos: GRUPOS, carregando: false,
  aviso: "", escolha: null, minha: null }, extra))}`);
const aplicativo = (extra) => Object.assign({ id: "google-chrome", nome: "Chrome de Brinquedo",
  trava: null, trava_pack: null, mapa: null, traco: null }, extra);
const ficha = (app) => ctx.escolhaDeIcone(app, async () => { chamadas.releituras += 1; });
const porControle = (painel, nome) => painel.todos().filter((e) => e.dataset.controle === nome);

(async () => {
  // --- a espera do trabalho ---------------------------------------------------
  js("TRABALHO = { id: 'brinquedo', timer: 1 }");
  const p = ctx.fimDoTrabalho();
  if (checa(p && typeof p.then === "function", "o fimDoTrabalho() devolve uma Promise")) {
    let resolvida = false;
    p.then(() => { resolvida = true; });
    await dormir(700);
    checa(!resolvida, "com um trabalho correndo, ela não se resolve");
    js("TRABALHO = null");
    await dormir(700);
    checa(resolvida, "e se resolve quando o trabalho acaba");
  }

  // --- o «Usar» do desenho do pack espera o passo -------------------------------
  zerar(); glifos();
  respostas = (rota) => (rota === "/api/app-icone" ? { ok: true } : {});
  ctx.__acao = async (id) => { chamadas.acoes.push(id); js("TRABALHO = { id: 'passo', timer: 1 }"); };
  let painel = ficha(aplicativo());
  const doPack = porControle(painel, "icone:desenho").find((b) => b.dataset.dica === "Alien");
  if (checa(doPack, "a ficha oferece o alien do pack")) {
    await doPack.clicar();
    painel = ficha(aplicativo());
    const usar = porControle(painel, "icone:usar")[0];
    if (checa(usar, "e o «Usar»")) {
      const clique = usar.clicar();
      await dormir(700);
      const correndo = chamadas.releituras;
      js("TRABALHO = null");
      await clique;
      checa(chamadas.acoes.join() === "icones_pack" && correndo === 0 && chamadas.releituras === 1,
            "o ramo do pack espera o passo: a lista não é relida com ele correndo, e é relida quando ele acaba",
            `ações ${chamadas.acoes.join() || "nenhuma"}; com o passo correndo ${correndo}, depois ${chamadas.releituras}`);
      const pedido = chamadas.api.find((c) => c.rota === "/api/app-icone");
      checa(pedido && pedido.corpo.arquivo === PACK.arquivo && !("cor" in pedido.corpo),
            "e o pedido leva o arquivo do pack, sem cor de traço", JSON.stringify(pedido));
    }
  }
  ctx.__acao = async (id) => { chamadas.acoes.push(id); };

  // --- a busca de agora vence a resposta velha ----------------------------------
  zerar();
  js("GLIFOS = { termo: null, itens: [], carregando: false }");
  const pendentes = {};
  respostas = (rota) => new Promise((pronto) => { pendentes[new URLSearchParams(rota.split("?")[1]).get("busca")] = pronto; });
  const velha = ctx.carregarGlifos("chr", "google-chrome");
  const nova = ctx.carregarGlifos("chro", "google-chrome");
  pendentes.chro({ glifos: [{ glifo: "da-busca-chro", grupo: "g", url: "" }] });
  await nova;
  pendentes.chr({ glifos: [{ glifo: "da-busca-chr", grupo: "g", url: "" }] });
  await velha;
  const agora = js("({ termo: GLIFOS.termo, itens: GLIFOS.itens.map((g) => g.glifo) })");
  checa(agora.termo === "chro" && agora.itens.join() === "da-busca-chro",
        "a resposta da busca velha, chegando depois, não pinta a lista da busca de agora", JSON.stringify(agora));

  // --- a trava é estado, e não sumiço -------------------------------------------
  zerar(); glifos();
  const trava = "chrome de brinquedo já tem desenho convertido do projeto.";
  painel = ficha(aplicativo({ trava }));
  let apagados = porControle(painel, "icone:travado");
  checa(apagados.length === 1 && porControle(painel, "icone:desenho").length === 1 && porControle(painel, "icone:usar").length === 1,
        "com a trava do traço, o pack e o «Usar» ficam, e o traço fica apagado na pasta dele");
  checa(apagados.every((b) => b.getAttribute("aria-disabled") === "true" && b.dataset.dica === "Chrome de brinquedo já tem desenho convertido do projeto."),
        "o desenho apagado diz que não vale (aria-disabled), e o porquê vai para a dica com maiúscula");
  painel = ficha(aplicativo({ trava, trava_pack: "o ícone é decidido por outro passo." }));
  checa(porControle(painel, "icone:travado").length === 2 && !porControle(painel, "icone:usar").length,
        "com as duas travas, tudo fica apagado e não há «Usar»");

  // --- o desfazer da escolha no pack -------------------------------------------
  zerar();
  respostas = (rota) => (rota === "/api/app-icone" ? { ok: true, removido: true } : {});
  glifos({ escolha: { pack: "dracula" }, app: "outro-programa" });
  checa(!porControle(ficha(aplicativo()), "icone:tirar-do-pack").length,
        "a escolha que a busca trouxe para OUTRO aplicativo não vira botão nesta ficha");
  glifos({ escolha: { pack: "dracula" } });
  const tirar = porControle(ficha(aplicativo()), "icone:tirar-do-pack")[0];
  if (checa(tirar, "com uma escolha no pack, a ficha oferece «Tirar do tema»")) {
    await tirar.clicar();
    const pedido = chamadas.api.find((c) => c.rota === "/api/app-icone");
    checa(pedido && pedido.corpo.pack === "dracula" && pedido.corpo.remover === true,
          "o clique pede ao servidor para tirar a escolha do mapa do pack", JSON.stringify(pedido));
    checa(chamadas.acoes.join() === "icones_pack" && chamadas.releituras === 1,
          "e o passo do pack roda antes de a lista ser relida", chamadas.acoes.join());
  }

  // --- os dois gestos do padrão (decisão 10) ------------------------------------
  const gravados = [];
  ctx.__gravar = (v) => { gravados.push(v); return true; };
  const item = (extra) => Object.assign({ chave: "RELOGIO_SEGUNDOS", aceita_vazio: true, padrao: "nao", opcoes: ["sim", "nao"] }, extra);
  const b1 = ctx.botaoPadrao(item(), (v) => ctx.__gravar(v));
  await b1.clicar();
  checa(gravados.pop() === "nao", "«Voltar ao padrão» grava o de fábrica");
  const b2 = ctx.botaoPadrao(item({ chave: "CURSOR", padrao: "catppuccin-mocha-light", padrao_do_pack: "Dracula-Cursor" }), (v) => ctx.__gravar(v));
  await b2.clicar();
  checa(gravados.pop() === "Dracula-Cursor", "e, quando o pack diz o dele, grava o do pack");
  checa(!ctx.temOQueRestaurar(item({ chave: "CURSOR", padrao_do_pack: "Dracula-Cursor" }), "Dracula-Cursor"),
        "no valor do pack, o «Voltar ao padrão» não nasce");
  const auto = ctx.botaoAutomatico(item(), "sim", (v) => ctx.__gravar(v));
  if (checa(auto, "«O sistema decide» existe na chave que aceita vazio e tem fábrica preenchida")) {
    await auto.clicar();
    checa(gravados.pop() === "", "e grava o vazio");
  }
  checa(!ctx.botaoAutomatico(item({ aceita_vazio: false }), "sim", () => true)
        && !ctx.botaoAutomatico(item({ padrao: "" }), "sim", () => true)
        && !ctx.botaoAutomatico(item(), "", () => true),
        "e não existe sem aceitar vazio, com fábrica vazia, ou já no vazio");

  if (falhas.length) {
    for (const f of falhas) console.error("FALHOU: " + f);
    process.exit(1);
  }
  process.exit(0);
})().catch((e) => { console.error("FALHOU: erro no teste: " + (e && e.stack || e)); process.exit(2); });
JS
rc=$?
[ "$rc" = 0 ] || falhas=$((falhas+1))
if [ "$falhas" -eq 0 ]; then echo "restos-do-painel: tudo certo"; exit 0; fi
exit 1

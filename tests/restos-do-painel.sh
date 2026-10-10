#!/usr/bin/env bash
# restos-do-painel.sh — a gaveta que a ficha espera, o desfazer da escolha no
# pack e a busca da ficha, no motor de JavaScript e sem navegador. Sprint P64,
# 25/09/2026.
#
# O QUE ABRIU ISTO — as revisões da leva D (P50 e P60)
#   1. O `app/pagina/app.js` declarava DUAS funções `fimDoTrabalho` no topo do
#      script: a da P46, sem parâmetros, que devolve uma Promise que só se
#      resolve quando o trabalho da gaveta acaba; e a da P50, com três, que
#      devolve a linha da tabela do fim. Num script, a segunda declaração
#      vence as duas: o `await fimDoTrabalho()` do ramo do pack (P60) e dos
#      três vizinhos recebia um ARRAY, e não esperava nada — a lista era relida
#      com o passo ainda correndo, que é o defeito que a P46 veio fechar.
#   2. O «Voltar ao ícone de fábrica» dizia «voltou para o ícone de fábrica»
#      mesmo com o aplicativo no mapa do pack no ar, e a escolha de um desenho
#      do pack não tinha desfazer.
#   3. A busca da ficha pintava a resposta de uma busca VELHA que chegasse
#      depois da de agora, e sumia inteira para o aplicativo com trava do
#      traço, levando junto o grupo do pack, que não depende dessa trava.
#
# E O QUE A REVISÃO DA P64 ACHOU NO CONSERTO
#   · O rótulo «Voltar ao ícone de fábrica» era a mentira da torrada em outro
#     lugar: com o Chrome nos dois mapas, ele prometia a fábrica logo acima da
#     torrada que dizia o pack. Ele diz agora o que desfaz («Desfazer a escolha
#     no traço»), e a torrada diz o que fica.
#   · Na ficha travada com pack, a frase da busca sem resultado prometia «o
#     acervo que veio com o projeto» e mostrava só os desenhos do pack.
#   · (A trava do intocável e a da curadoria, que voltaram a travar o pack, são
#     do servidor, e é o tests/seletor-do-pack.sh que as cobra.)
#
# COMO SE MEDE
#   · A contagem das declarações no topo sai do texto (a regra da casa: toda
#     função de topo começa na coluna 0), e roda sem node.
#   · Com node, o próprio parser do V8 confirma: o arquivo, lido como MÓDULO,
#     não pode declarar o mesmo nome duas vezes no topo (num script pode, e é
#     por isso que o navegador nunca reclamou).
#   · E o arquivo INTEIRO roda num `vm` do node, com um DOM de mentira que só
#     tem o que a ficha usa. É o mesmo içamento de declarações do navegador: a
#     função que se chama aqui é a que a página chama. As rotas do servidor são
#     trocadas por respostas escritas aqui — o que elas respondem de verdade é
#     do tests/seletor-do-pack.sh.
#
# PORTÁTIL NA PRIMEIRA METADE: bash e grep. A segunda pede node; sem ele o
#   teste diz "pulado" depois de contar.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = tudo cobrado passou · 1 = achados · 2 = erro deste teste · 3 = pulado.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
APP="$RAIZ/app/pagina/app.js"
[ -f "$APP" ] || { printf 'FALHOU: não achei %s\n' "$APP" >&2; exit 2; }

falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

# --- 1. as declarações no topo, contadas no texto ------------------------------
total="$(grep -c '^\(async \)\?function [A-Za-z0-9_$]* *(' "$APP")"
fim="$(grep -n '^\(async \)\?function fimDoTrabalho *(' "$APP")"
repetidas="$(grep -o '^\(async \)\?function [A-Za-z0-9_$]*' "$APP" | sed 's/^async //' | sort | uniq -d)"
if [ "$(printf '%s\n' "$fim" | grep -c .)" = "1" ] && [ -z "$repetidas" ]; then
  ok "no topo do app.js, $total funções e um nome por função — o fimDoTrabalho é um só (linha ${fim%%:*})"
else
  falha "o app.js declara no topo o mesmo nome mais de uma vez" "$(printf 'repetidas: %s\nfimDoTrabalho: %s' "$repetidas" "$fim")"
fi

NODE="$(command -v node || true)"
if [ -z "$NODE" ]; then
  [ "$falhas" -eq 0 ] || exit 1
  printf 'pulado: sem node — o parser do V8 e a ficha no vm ficaram de fora\n'
  exit 3
fi

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT

# --- 2. o parser do V8, com o arquivo lido como módulo -------------------------
cp "$APP" "$T/app.mjs" || exit 2
if saida="$("$NODE" --check "$T/app.mjs" 2>&1)"; then
  ok "o parser do V8, lendo o app.js como módulo, não acha declaração repetida no topo"
else
  falha "o parser do V8 recusa o app.js lido como módulo" \
    "$(printf '%s\n' "$saida" | grep -E 'app\.mjs:[0-9]+|Error' | head -2 | sed "s#$T/app.mjs#app/pagina/app.js#")"
fi

# --- 3. a ficha e a gaveta, no vm ----------------------------------------------
"$NODE" - "$APP" <<'JS'
"use strict";
const fs = require("fs");
const vm = require("vm");

const falhas = [];
const ok = (frase) => console.log("ok: " + frase);
const checa = (cond, frase, detalhe) => {
  if (cond) ok(frase);
  else falhas.push(frase + (detalhe ? " — " + detalhe : ""));
  return cond;
};
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));
// A página tem promessas que ninguém espera (o `iniciar` fica pendurado no
// `fetch` de mentira); elas não são o assunto daqui.
process.on("unhandledRejection", () => {});

/* O DOM DE MENTIRA: só o que a ficha de ícone e o `elemento` usam. Um toco
 * responde a todo o resto — o que o topo do script liga ao carregar. */
const toco = new Proxy(function () {}, {
  get(_a, k) {
    if (k === "then") return undefined;
    if (k === Symbol.toPrimitive) return () => "";
    if (k === Symbol.iterator) return function* () {};
    return toco;
  },
  apply() { return toco; },
  construct() { return toco; },
  set() { return true; },
});
const camelo = (s) => s.replace(/-([a-z])/g, (_m, c) => c.toUpperCase());
class El {
  constructor(tag) {
    this.tagName = String(tag).toUpperCase();
    this.filhos = []; this.attrs = {}; this.dataset = {}; this.ouvintes = {};
    this.className = ""; this.textContent = ""; this.hidden = false; this.style = toco;
  }
  setAttribute(k, v) {
    this.attrs[k] = String(v);
    if (k.startsWith("data-")) this.dataset[camelo(k.slice(5))] = String(v);
    if (k === "value") this.value = String(v);
  }
  getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; }
  removeAttribute(k) { delete this.attrs[k]; }
  addEventListener(ev, fn) { (this.ouvintes[ev] = this.ouvintes[ev] || []).push(fn); }
  append(...fs) { for (const f of fs) this.filhos.push(f); }
  get children() { return this.filhos.filter((f) => f instanceof El); }
  get childNodes() { return this.filhos; }
  todos() { return this.children.flatMap((f) => [f, ...f.todos()]); }
  querySelectorAll(sel) { return this.todos().filter((e) => e.tagName === sel.toUpperCase()); }
  querySelector(sel) { return this.querySelectorAll(sel)[0] || null; }
  clicar() { return Promise.all((this.ouvintes.click || []).map((fn) => fn({ target: this }))); }
}
const documento = {
  createElement: (tag) => new El(tag),
  body: Object.assign(new El("body"), { dataset: { token: "brinquedo" } }),
  querySelector: () => new El("div"),
  addEventListener() {},
};

const ctx = vm.createContext({
  document: documento, location: { search: "", hash: "", pathname: "/" },
  history: toco, window: toco, navigator: toco, localStorage: toco,
  sessionStorage: toco, EventSource: toco, matchMedia: toco,
  requestAnimationFrame: toco, fetch: () => new Promise(() => {}),
  console, setTimeout, clearTimeout, setInterval, clearInterval, URLSearchParams,
});
vm.runInContext(fs.readFileSync(process.argv[2], "utf8"), ctx, { filename: "app.js" });
const js = (codigo) => vm.runInContext(codigo, ctx);

// O que a ficha chama e não é dela: trocado por quem só anota.
const chamadas = { api: [], torradas: [], acoes: [], releituras: 0 };
let respostas = () => ({});
ctx.api = async (rota, opcoes = {}) => {
  chamadas.api.push({ rota, corpo: opcoes.body ? JSON.parse(opcoes.body) : null });
  return respostas(rota, opcoes);
};
ctx.torrada = (texto, classe) => chamadas.torradas.push({ texto, classe });
ctx.rodarAcao = async (id) => { chamadas.acoes.push(id); };
ctx.render = () => {};
ctx.porBalao = () => {};
ctx.oficinaDeDesenho = () => new El("details");
ctx.botaoAcervo = () => new El("button");
ctx.sincronizarCorDaOficina = () => {};
ctx.flavorEmVigor = () => "dracula";
js(`ESQUEMA = { paleta: { ordem: ["mauve"], flavors: { dracula: { mauve: "#BD93F9" } } } }`);
const zerar = () => {
  chamadas.api.length = 0; chamadas.torradas.length = 0; chamadas.acoes.length = 0;
  chamadas.releituras = 0; js("TRABALHO = null; APP_ABERTO = null");
};

// [P73, 09/10/2026: a resposta da busca ganhou `grupos` (as pastas por acervo),
// e cada item o `grupo` (o id da pasta), o `tipo` e o `arquivo`.]
const PACK = { glifo: "alien", grupo: "pack:dracula:biblioteca", tipo: "desenho", pack: "dracula",
               desenho: "biblioteca/alien.svg", arquivo: "packs/dracula/icones/biblioteca/alien.svg",
               url: "/previa?x" };
const TRACO = { glifo: "google-chrome", grupo: "motor:arcticons-apps", tipo: "traco",
                arquivo: "assets/icones/arcticons-apps/google-chrome.svg", url: "/previa?y" };
const GRUPOS = [
  { id: "pack:dracula:biblioteca", acervo: "Dracula", nome: "biblioteca", no_ar: true, total: 1, achados: 1 },
  { id: "motor:arcticons-apps", acervo: "MeowSystem", nome: "traço", no_ar: false, total: 1, achados: 1 }];
const glifos = (extra) => js(`GLIFOS = ${JSON.stringify(Object.assign({
  termo: "chrome", app: "google-chrome", itens: [PACK, TRACO], grupos: GRUPOS, carregando: false,
  aviso: "", pack: { id: "dracula", nome: "Dracula" }, escolha: null, minha: null }, extra))}`);
const aplicativo = (extra) => Object.assign({ id: "google-chrome", nome: "Chrome de Brinquedo",
  trava: null, trava_pack: null, mapa: null, traco: null }, extra);
const ficha = (app) => ctx.montarEscolhaDeIcone(app, async () => { chamadas.releituras += 1; });
const botao = (painel, texto) => painel.todos().find((e) => e.tagName === "BUTTON" && e.textContent === texto);

(async () => {
  // --- 3.1 a função que a página chama, e a espera dela ----------------------
  js("TRABALHO = { id: 'brinquedo' }");
  const p = ctx.fimDoTrabalho();
  if (checa(p && typeof p.then === "function",
            "o fimDoTrabalho() que a página chama devolve uma Promise",
            Array.isArray(p) ? "devolveu o array " + JSON.stringify(p) + ": a declaração da P50 venceu a da P46"
                             : "devolveu " + typeof p)) {
    let resolvida = false;
    p.then(() => { resolvida = true; });
    await dormir(700);
    checa(!resolvida, "com um trabalho na gaveta, ela não se resolve");
    js("TRABALHO = null");
    await dormir(700);
    checa(resolvida, "e se resolve quando o trabalho acaba");
  }
  js("TRABALHO = null");

  // --- 3.2 o ramo do pack do «Usar este ícone» espera o passo --------------------
  zerar(); glifos();
  respostas = (rota) => (rota === "/api/app-icone" ? { ok: true, nome_pack: "Dracula" } : {});
  // O `rodarAcao` volta quando a gaveta abre, e não quando o trabalho acaba —
  // é isso que o TRABALHO de pé representa.
  ctx.rodarAcao = async (id) => { chamadas.acoes.push(id); js("TRABALHO = { id: 'passo' }"); };
  let painel = ficha(aplicativo());
  const doPack = painel.todos().find((e) => e.tagName === "BUTTON" && e.dataset.escolha === "pack:dracula:biblioteca|alien");
  const usar = botao(painel, "Usar este ícone");
  if (checa(doPack && usar, "a ficha do Chrome oferece o alien do pack e o «Usar este ícone»")) {
    await doPack.clicar();
    const clique = usar.clicar();
    await dormir(700);
    const correndo = chamadas.releituras;
    js("TRABALHO = null");
    await clique;
    checa(chamadas.acoes.join() === "icones_pack" && correndo === 0 && chamadas.releituras === 1,
          "o ramo do pack espera o passo: a lista não é relida com ele correndo, e é relida quando ele acaba",
          `ações ${chamadas.acoes.join() || "nenhuma"}; releituras com o passo correndo ${correndo}, `
          + `depois ${chamadas.releituras}`);
  }
  ctx.rodarAcao = async (id) => { chamadas.acoes.push(id); };

  // --- 3.3 a busca de agora vence a resposta velha --------------------------
  zerar();
  js(`GLIFOS = { termo: null, itens: [], carregando: false }`);
  const pendentes = {};
  respostas = (rota) => new Promise((pronto) => {
    pendentes[new URLSearchParams(rota.split("?")[1]).get("busca")] = pronto;
  });
  const velha = ctx.carregarGlifos("chr", "google-chrome");
  const nova = ctx.carregarGlifos("chro", "google-chrome");
  pendentes.chro({ glifos: [{ glifo: "da-busca-chro", grupo: "g", url: "" }] });
  await nova;
  pendentes.chr({ glifos: [{ glifo: "da-busca-chr", grupo: "g", url: "" }] });
  await velha;
  const agora = js("({ termo: GLIFOS.termo, itens: GLIFOS.itens.map((g) => g.glifo) })");
  checa(agora.termo === "chro" && agora.itens.join() === "da-busca-chro",
        "a resposta da busca velha, chegando depois, não pinta a lista da busca de agora",
        JSON.stringify(agora));

  // --- 3.4 a trava é estado, e não sumiço (P73, T4) ------------------------------
  // [Até a P73 este bloco cobrava que a trava TIRASSE o traço da tira, e que as
  // duas travas tirassem a busca. A P73 inverteu: o acervo fica, apagado, sem
  // «Usar», e o porquê vai para a dica de cada desenho.]
  zerar(); glifos();
  const trava = "Chrome de Brinquedo já tem desenho convertido do projeto.";
  const travaPack = "O ícone é decidido por outro passo.";
  const temBusca = (pn) => pn.todos().some((e) => e.tagName === "INPUT" && e.dataset.foco === "glifos");
  const pastas = (pn) => pn.todos().filter((e) => e.tagName === "DETAILS" && e.dataset.grupo)
                                   .map((e) => e.dataset.grupo);
  const apagados = (pn) => pn.todos().filter((e) => e.tagName === "BUTTON"
                                             && (e.className || "").includes("travado"));
  painel = ficha(aplicativo({ trava }));
  const tira = painel.todos().filter((e) => e.tagName === "BUTTON" && e.dataset.escolha);
  checa(temBusca(painel) && tira.length === 1 && tira[0].dataset.escolha.startsWith("pack:")
        && apagados(painel).length === 1 && botao(painel, "Usar este ícone"),
        "com a trava do traço, a busca, o pack e o «Usar este ícone» ficam, e o traço fica APAGADO na pasta dele",
        `busca ${temBusca(painel)}, tira [${tira.map((b) => b.dataset.escolha)}], apagados ${apagados(painel).length}`);
  painel = ficha(aplicativo({ trava, trava_pack: travaPack }));
  checa(temBusca(painel) && pastas(painel).join() === "pack:dracula:biblioteca,motor:arcticons-apps"
        && apagados(painel).length === 2 && !botao(painel, "Usar este ícone"),
        "com as duas travas (o CosmicEdit), a ficha mostra a busca e as pastas do acervo, tudo apagado, "
        + "e sem «Usar este ícone»", `pastas [${pastas(painel)}], apagados ${apagados(painel).length}`);
  checa(apagados(painel).every((b) => b.getAttribute("aria-disabled") === "true"),
        "e cada desenho apagado diz que não vale (aria-disabled), com o porquê na dica");
  glifos({ pack: null });
  painel = ficha(aplicativo({ trava }));
  checa(temBusca(painel), "e sem pack no ar, a busca continua");

  // A BUSCA QUE NÃO ACHOU NADA DIZ O QUE VEM A SEGUIR (revisão da P64): na ficha
  // travada, o traço sai da tira, e o que a busca vazia traz são os desenhos
  // do pack — a frase não pode prometer o acervo do projeto. A busca da ficha
  // travada acha um traço, que a trava tira da tira.
  const semAchado = (app, itens) => {
    zerar(); glifos({ termo: "xyz", itens });
    respostas = () => ({ glifos: [] });
    const frase = ficha(app).todos().find((e) => e.tagName === "P" && e.className === "sem-previa");
    return frase ? frase.textContent : "(sem frase)";
  };
  // [P73: a busca sem achado não troca mais a tira pelo acervo inteiro — o
  // acervo inteiro é a ficha sem busca. Ela diz só que nada casou.]
  let frase = semAchado(aplicativo({ trava }), []);
  checa(frase === "Nenhum desenho casa com “xyz”.",
        "a busca sem achado diz que nada casou com o termo", frase);

  // --- 3.5 o desfazer da escolha no pack, e a torrada que diz o que fica ---------
  zerar();
  const escolha = { pack: "dracula", nome_pack: "Dracula", glifo: "alien", antes: "google-chrome" };
  const fica = { tipo: "pack", frase: "o desenho «google-chrome» do pack «Dracula»" };
  respostas = (rota) => (rota === "/api/app-icone" ? { ok: true, removido: true, fica } : {});
  glifos({ escolha, app: "outro-programa" });
  checa(!botao(ficha(aplicativo()), "Desfazer a escolha no pack"),
        "a escolha que a busca trouxe para OUTRO aplicativo não vira botão nesta ficha");
  glifos({ escolha });
  painel = ficha(aplicativo());
  const desfazer = botao(painel, "Desfazer a escolha no pack");
  if (checa(desfazer, "com uma escolha no pack, a ficha oferece «Desfazer a escolha no pack»")) {
    await desfazer.clicar();
    const pedido = chamadas.api.find((c) => c.rota === "/api/app-icone");
    const t = (chamadas.torradas[0] || {}).texto || "";
    checa(pedido && pedido.corpo.app === "google-chrome" && pedido.corpo.pack === "dracula"
          && pedido.corpo.remover === true,
          "o clique pede ao servidor para tirar a escolha do mapa do pack", JSON.stringify(pedido));
    checa(t === "Chrome de Brinquedo fica com o desenho «google-chrome» do pack «Dracula»",
          "a torrada diz o ícone que fica, com as palavras do servidor", t);
    checa(chamadas.acoes.join() === "icones_pack" && chamadas.releituras === 1,
          "e o passo do pack roda antes de a lista ser relida", chamadas.acoes.join());
  }

  // REABRIR A FICHA PERGUNTA DE NOVO: a escolha no pack muda com os botões da
  // própria ficha, que a fecham ao terminar; a busca guardada, com o mesmo
  // termo e o mesmo aplicativo, diria a escolha de antes.
  zerar(); glifos({ termo: "chrome" });
  respostas = () => ({ glifos: [], escolha });
  const grade = ctx.gradeDeApps([aplicativo({ nome: "Chrome", origem: "brinquedo", url: "" })],
                                "", async () => {});
  const noGrid = grade.todos().find((e) => e.tagName === "BUTTON");
  await noGrid.clicar();
  await dormir(50);
  checa(chamadas.api.some((c) => c.rota.startsWith("/api/glifos?") && c.rota.includes("app=google-chrome"))
        && js("GLIFOS.escolha && GLIFOS.escolha.pack") === "dracula",
        "reabrir a ficha do mesmo aplicativo pede a busca de novo, e a escolha no pack vem dela",
        chamadas.api.map((c) => c.rota).join(" "));
  js("APP_ABERTO = null");

  zerar(); glifos();
  respostas = (rota) => (rota === "/api/app-icone" ? { ok: true, removido: true, fica } : {});
  // [P73: só a escolha de traço DE QUEM USA (`meu`) tem «Desfazer»; a linha do
  // mapa do projeto é curadoria do repositório.]
  painel = ficha(aplicativo({ mapa: { glifo: "google-chrome", cor: "yellow", meu: true } }));
  // O RÓTULO NÃO PROMETE O QUE FICA (revisão da P64): «Voltar ao ícone de
  // fábrica» dizia a fábrica logo acima da torrada que dizia o pack.
  const voltar = botao(painel, "Desfazer a escolha no traço");
  const fabrica = painel.todos().filter((e) => e.tagName === "BUTTON" && /fábrica/.test(e.textContent));
  if (checa(voltar && !fabrica.length,
            "com o Chrome no mapa do traço, a ficha oferece «Desfazer a escolha no traço», e botão "
            + "nenhum promete a fábrica", fabrica.map((b) => b.textContent).join(", "))) {
    await voltar.clicar();
    const t = (chamadas.torradas[0] || {}).texto || "";
    checa(t.includes("o desenho «google-chrome» do pack «Dracula»") && !t.includes("fábrica"),
          "e, com o desenho do pack ficando, a torrada não diz «de fábrica»", t);
  }

  // --- 3.x «RESTAURAR AO PADRÃO» GRAVA O DE FÁBRICA — decisão 10 (P79) ---------
  //   O botão gravava o vazio («não toca») e, nas chaves com o padrão de fábrica
  //   preenchido (RELOGIO_SEGUNDOS="nao", JANELAS_TILING="sim"), o nome mentia.
  //   Agora ele grava `item.padrao`, nasce só quando o valor difere dele, e o
  //   «não tocar» é outro gesto, com outro nome. Chave de padrão vazio segue
  //   igual: restaurar É o vazio.
  {
    const gravados = [];
    ctx.escolher = async (_chave, v) => { gravados.push(v); return true; };
    ctx.parDeBotoes = () => null;
    ctx.selo = () => new El("span");
    ctx.gatilhoDeDica = () => [];
    ctx.CSS = { escape: (x) => x };
    const item = (valor, extra) => Object.assign({ chave: "RELOGIO_SEGUNDOS", aceita_vazio: true,
      padrao: "nao", opcoes: ["sim", "nao"], valor, valendo_agora: "sim" }, extra);
    const montar = (it) => { ctx.valorEmVigor = () => it.valor; return ctx.montarControle(it, new El("div")); };
    const botoes = (c) => c.todos().filter((e) => e.tagName === "BUTTON");
    const restaurar = (c) => botoes(c).find((b) => /^Restaurar ao padrão/.test(b.textContent));
    const naoTocar = (c) => botoes(c).find((b) => b.textContent === "Não tocar");

    checa(!restaurar(montar(item("nao"))),
          "no padrão de fábrica preenchido, nenhum «Restaurar ao padrão»");
    let c = montar(item("sim"));
    let r = restaurar(c);
    if (checa(r && r.textContent === "Restaurar ao padrão (Não)",
              "fora do padrão, o botão diz o valor de FÁBRICA no parêntese, e não o da máquina",
              r ? r.textContent : botoes(c).map((b) => b.textContent).join(" | "))) {
      gravados.length = 0; await r.clicar();
      checa(gravados[0] === "nao", "e grava o valor de fábrica, não o vazio", JSON.stringify(gravados));
    }
    const n = naoTocar(c);
    if (checa(n, "o «não tocar» é outro botão, com outro nome", botoes(c).map((b) => b.textContent).join(" | "))) {
      gravados.length = 0; await n.clicar();
      checa(gravados[0] === "", "e ele grava o vazio", JSON.stringify(gravados));
    }
    c = montar(item(""));
    r = restaurar(c);
    if (checa(r, "com a chave vazia («não toca») e fábrica preenchida, o restaurar aparece")) {
      gravados.length = 0; await r.clicar();
      checa(gravados[0] === "nao", "e grava o de fábrica", JSON.stringify(gravados));
    }
    c = montar(item("x", { opcoes: ["a", "b", "c", "d", "e", "x"], padrao: "a", chave: "LONGA" }));
    r = restaurar(c);
    if (checa(r, "o seletor longo também restaura ao de fábrica")) {
      gravados.length = 0; await r.clicar();
      checa(gravados[0] === "a", "e grava o de fábrica no seletor", JSON.stringify(gravados));
    }
    c = montar(item("8", { chave: "FORMA_RAIO_PAINEL", padrao: "", opcoes: [], faixa: ["0", "32", "1"], valendo_agora: "4" }));
    r = restaurar(c);
    if (checa(r && !naoTocar(c), "de padrão vazio, o restaurar continua e não ganha o «não tocar»",
              botoes(c).map((b) => b.textContent).join(" | "))) {
      gravados.length = 0; await r.clicar();
      checa(gravados[0] === "", "e grava o vazio, que é o de fábrica", JSON.stringify(gravados));
    }
  }

  if (falhas.length) {
    console.error("FALHOU: a ficha de ícone e a gaveta:");
    for (const f of falhas) console.error("    " + f);
    process.exit(1);
  }
  console.log("ok: a ficha espera o passo, desfaz a escolha no pack e busca o que se pediu por último");
  process.exit(0);
})().catch((e) => { console.error("FALHOU: erro no teste: " + (e && e.stack || e)); process.exit(2); });
JS
rc=$?
[ "$rc" = "0" ] || { [ "$rc" = "1" ] && falhas=$((falhas+1)) || exit 2; }

[ "$falhas" -eq 0 ] && { printf '\nrestos-do-painel: tudo certo\n'; exit 0; }
printf '\nrestos-do-painel: %s achado(s)\n' "$falhas" >&2
exit 1

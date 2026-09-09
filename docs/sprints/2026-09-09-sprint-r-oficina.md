# Sprint R, materializada — a oficina: variações, o original ao lado, clicar para tirar

Detalhamento da Sprint R de
[`2026-09-09-heroic-e-oficina.md`](2026-09-09-heroic-e-oficina.md). É para
quem vai **escrever o código**: contrato de API com o JSON exato, o estado
do cliente campo a campo, cada função com nome, o CSS, cada palavra da
tela, e as conferências do teste com os seletores. Nada aqui foi executado.

**As palavras dela que esta sprint responde** (08/09/2026):

> *"o nosso gerador de ícones é fraco, não gera variações nem é tão bonito
> quanto o original, além de ficar pixelado e não ser intuitivo e fácil de
> usar."*

E as quatro regras de interface dela (01/09): **menos palavras**,
**acentuação**, **maiúscula inicial**, **escolher não é gravar**.

**Arquivos desta sprint, e só estes:**

| arquivo | o quê |
|---|---|
| `app/servidor.py` | `_api_app_desenho`: a ação `variacoes`, a `vetorizar` por réguas, a `salvar` que decide o modo pela medida |
| `app/pagina/app.js` | `oficinaDeDesenho()` reescrita (linhas 2041–2255 de hoje) |
| `app/pagina/estilo.css` | o bloco `.oficina-*` (linhas 1786–1869 de hoje) |
| `tests/app-navegador.py` | a seção 22 |
| `docs/SPRINTS.md` | a linha de fechamento |

`scripts/converter_icone.py` **não é tocado aqui**: a chave `--cheia` e as
curvas são da Sprint Q. Esta sprint funciona com o conversor de hoje (a
folha sai em polilinha até a Q entrar) — o contrato é o mesmo.

---

## 0. O que existe hoje, e o que cada queixa dela aponta

`app/pagina/app.js:2044 oficinaDeDesenho(app, relerLista)` monta: um
`<details class="oficina">` com resumo de uma linha; uma frase; a prévia de
48 e a de 200 numa coluna; três `<input type=number>` (Cores, Fusão, Aparo)
que disparam `vetorizar()` no `change`; um `<textarea>` com o XML; quatro
botões (Vetorizar, Abrir o que já está salvo, Usar este desenho, Pôr na
tela); uma frase de rodapé. A rota `/api/app-desenho` tem três verbos:
`vetorizar`, `ler`, `salvar`.

| queixa | onde está a causa |
|---|---|
| não gera variações | um clique, um desenho; para ver outro, mexer em número e clicar de novo |
| não é tão bonito quanto o original | o original **nunca aparece**; e a escada (Sprint Q) |
| pixelado | a escada, a 200 px |
| não é intuitivo | "Cores/Fusão/Aparo" é vocabulário do conversor; editar é XML; dois botões para ver na tela |

---

## 1. A tela

```
▾ Desenho no nosso traço                                              [ Usar ]

  Original    Salvo      Fiel      Limpo     Silhueta   Detalhe   Área cheia   Da capa
  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐    ┌──────┐
  │  48  │  │  48  │  │  48  │  │  48  │  │  48  │  │  48  │  │  48  │    │  48  │
  │  96  │  │  96  │  │  96  │  │  96  │  │  96  │  │  96  │  │  96  │    │  96  │
  └──────┘  └──────┘  └══════┘  └──────┘  └──────┘  └──────┘  └──────┘    └──────┘
                          ↑ a escolhida: borda de acento, aria-pressed

  Como fica no dock      [ btop ]  [ ESCOLHIDA ]  [ CosmicTweaks ]        (48 px, cor real, vidro)

  ┌──────────────────────────────┐    Detalhe     ──────●────
  │                              │    Suavidade   ────●──────
  │            200 px            │
  │                              │    [ Desfazer ]
  │  Clique num traço para tirar │
  └──────────────────────────────┘
  ▸ Editar o SVG
```

Regras da tela, cada uma com o porquê:

- **A folha abre junto com o `details`.** Sem clique em "Vetorizar": abrir
  já é pedir para ver. Enquanto carrega, os cartões mostram o esqueleto
  (`.lugar`) e o texto "Desenhando…".
- **`Original` não é clicável** — é régua, não opção. `Salvo` só existe
  quando há desenho gravado, e é clicável (ela pode partir dele).
- **A escolhida é a que a lupa mostra.** Clicar num cartão troca a lupa, o
  dock e o texto; não grava nada.
- **`Usar` é o único verbo que escreve**, e faz as duas coisas que hoje são
  dois botões: grava e roda `icones_traco`. Em ensaio, nem uma nem outra.
- **A lupa é o editor.** Clique num traço = tira. `Desfazer` devolve. Nada de
  XML na frente — o `<textarea>` continua existindo, dobrado em `Editar o SVG`.
- **Duas réguas**, com nomes de gosto, não de algoritmo. Mexer re-vetoriza a
  escolhida (só ela), com 250 ms de espera.

---

## 2. O contrato da rota `/api/app-desenho`

Todos os verbos: `POST`, JSON, cabeçalho `X-Meow-Token` (o `api()` do
cliente já põe). `app` continua obrigatório e validado por
`^[A-Za-z0-9._+-]{1,120}$`. O nome de arquivo continua sendo o do `Icon=`
(`_nome_do_icone`), nunca o do `.desktop`.

### 2.1 `variacoes` — **novo**

Pedido:

```json
{"app": "org.gimp.GIMP", "acao": "variacoes"}
```

Resposta (200):

```json
{
  "ok": true,
  "nome": "org.gimp.GIMP",
  "origem": "/usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg",
  "original": "/previa?tipo=arquivo&id=%2Fusr%2Fshare%2Ficons%2FPapirus%2F64x64%2Fapps%2Forg.gimp.GIMP.svg",
  "capa": "/previa?tipo=arquivo&id=…library_header.jpg",
  "cor": "pink",
  "salvo": {"tem": true, "svg": "<svg …>", "modo": "mao"},
  "variacoes": [
    {"id": "fiel",     "rotulo": "Fiel",       "detalhe": 6,  "suavidade": 2, "cheia": false, "fonte": "icone",
     "parametros": "--k 8 --funde 52 --tol 1.0", "svg": "<svg …>", "nota": "4 classes, 6 traços, 41 curvas"},
    {"id": "limpo",    "rotulo": "Limpo",      "detalhe": 2,  "suavidade": 6, "cheia": false, "fonte": "icone", "parametros": "--k 4 --funde 84 --tol 2.2", "svg": "…", "nota": "…"},
    {"id": "silhueta", "rotulo": "Silhueta",   "detalhe": 0,  "suavidade": 4, "cheia": false, "fonte": "icone", "parametros": "--k 2 --funde 100 --tol 1.6", "svg": "…", "nota": "…"},
    {"id": "detalhe",  "rotulo": "Detalhe",    "detalhe": 10, "suavidade": 1, "cheia": false, "fonte": "icone", "parametros": "--k 12 --funde 20 --tol 0.7", "svg": "…", "nota": "…"},
    {"id": "cheia",    "rotulo": "Área cheia", "detalhe": 4,  "suavidade": 4, "cheia": true,  "fonte": "icone", "parametros": "--k 6 --funde 68 --tol 1.6 --cheia", "svg": "…", "nota": "…"},
    {"id": "capa",     "rotulo": "Da capa",    "detalhe": 3,  "suavidade": 5, "cheia": false, "fonte": "capa",  "parametros": "--k 5 --funde 76 --tol 1.9", "svg": "…", "nota": "…"}
  ],
  "vizinhos": [
    {"nome": "btop", "cor": "maroon", "svg": "<svg …>"},
    {"nome": "dev.edfloreshz.CosmicTweaks", "cor": "lavender", "svg": "<svg …>"}
  ]
}
```

Regras da resposta:

- `capa` e a variação `capa` só existem quando `app` casa com `_RE_STEAM`
  **e** `_capa_do_jogo(appid, vertical=False)` acha arquivo. Fora isso, a
  lista tem cinco.
- `cheia` só entra quando a métrica `cheia` do conversor não é `null`
  (Sprint Q, `--json`). Com o conversor de hoje (sem `--cheia`), a rota
  detecta a ausência da chave em `--help` uma vez (`subprocess.run([...,
  "--help"])`, cacheado) e não oferece o cartão — **a oficina funciona antes
  da Q entrar**.
- Uma variação que falhar (o conversor recusou, 422) sai da lista com
  `{"id": "…", "rotulo": "…", "erro": "…"}` e o cliente mostra o cartão
  apagado com a frase curta. As outras seguem.
- `vizinhos` são **sempre os mesmos dois**: a primeira e a última linha de
  dados do `apps-arcticons.map` (hoje `btop:osmonitor:maroon` e
  `dev.edfloreshz.CosmicTweaks:equalizer:lavender`), lidas do arquivo, com o
  SVG de `assets/icones/arcticons-apps/<glifo>.svg` e a cor do campo 3. Se o
  mapa mudar, mudam junto.
- `salvo.svg` é `retoques/<nome>.svg` se existir, senão
  `convertidos-apps/<nome>.svg` se existir; `modo` é `mao` ou `conversao`
  conforme a linha do mapa.
- **As seis conversões rodam em paralelo** num
  `concurrent.futures.ThreadPoolExecutor(max_workers=6)`; cada uma é o mesmo
  `subprocess.run` de hoje, com `timeout=60`. O servidor é
  `ThreadingHTTPServer`, então a rota ocupada não trava as outras.
- **Cache em memória**, `_CACHE_DESENHO: dict[(origem, mtime, parametros)] →
  (svg, nota)`, no máximo 64 entradas (descarta a mais antiga). Reabrir a
  mesma ficha não converte de novo.

### 2.2 `vetorizar` — estendido, compatível

Continua aceitando `k`, `funde`, `tol`, `fonte` como hoje. Ganha:

```json
{"app": "…", "acao": "vetorizar", "fonte": "icone", "detalhe": 6, "suavidade": 2, "cheia": false}
```

O servidor traduz réguas em parâmetros — **uma tabela, num lugar só**
(`_parametros_de(detalhe, suavidade, cheia)`), e é a mesma que gera os
presets de 2.1:

```python
def _parametros_de(detalhe, suavidade, cheia):
    d = max(0, min(10, int(detalhe)))
    s = max(0, min(10, int(suavidade)))
    k = 2 + d                     # 2 … 12
    funde = 100 - 8 * d           # 100 … 20
    tol = round(0.4 + 0.3 * s, 1) # 0,4 … 3,4
    argv = ["--k", str(k), "--funde", str(funde), "--tol", "%g" % tol]
    if cheia:
        argv.append("--cheia")
    return argv, " ".join(argv)   # (para o subprocess, para o campo 4 do mapa)

PRESETS = (  # id, rótulo, detalhe, suavidade, cheia, fonte
    ("fiel", "Fiel", 6, 2, False, "icone"),
    ("limpo", "Limpo", 2, 6, False, "icone"),
    ("silhueta", "Silhueta", 0, 4, False, "icone"),
    ("detalhe", "Detalhe", 10, 1, False, "icone"),
    ("cheia", "Área cheia", 4, 4, True, "icone"),
    ("capa", "Da capa", 3, 5, False, "capa"),
)
```

Resposta: a de hoje (`ok, svg, origem, nota`) mais `parametros` (a string
canônica). As faixas de `k`/`funde`/`tol` continuam sendo conferidas no
servidor como hoje — um POST forjado com `detalhe: 900` cai no `min/max`.

### 2.3 `salvar` — decide o modo pela medida, não pelo que o cliente diz

Pedido:

```json
{"app": "…", "acao": "salvar", "svg": "<svg …>", "cor": "pink", "seco": false,
 "fonte": "icone", "parametros": "--k 8 --funde 52 --tol 1.0"}
```

O servidor:

1. `_conferir_dialeto(svg)` — igual a hoje (viewBox, sem `stroke-width`,
   sem cor, `stroke="currentColor"`, `fill="none"`, sem `<script>`…).
2. Em `seco`: responde `{"ok": true, "seco": true, "aviso": "Em ensaio: …"}`
   sem escrever — como hoje.
3. **Decide o modo**: se `fonte == "icone"` e `parametros` vieram, roda o
   conversor de novo na `origem` com esses parâmetros (o cache de 2.1
   responde na hora) e compara `svg.rstrip()` com o resultado. **Iguais →
   `conversao`. Diferentes, ou `fonte == "capa"`, ou sem `parametros` →
   `mao`.** A capa é sempre `mao` porque o caminho dela na Steam tem um hash
   que muda; o mapa não pode apontar para lá.
4. Escreve:
   - `conversao`: a linha `<nome>:<origem>:<cor>:<parametros>` no
     `apps-convertidos.map` (trocando a linha se o nome já existe — hoje o
     `_gravar_linha_convertidos` só sabe escrever `mao`; ganha o parâmetro
     `origem` e `extra`), o construído em `convertidos-apps/<nome>.svg`
     (sem `\n` final, formato do `meow_escrever`), **e apaga
     `retoques/<nome>.svg` se existir** — senão o retoque velho venceria a
     conversão nova no `_desejado_de` do construtor. É a única remoção
     desta rota, restrita ao diretório `retoques/` pelo `realpath`, e a
     resposta diz que aconteceu.
   - `mao`: exatamente o que a rota faz hoje (retoque com `\n`, construído
     sem, linha `<nome>:mao:<cor>`).
5. `_tirar_do_mapa_arcticons(nome)` — como hoje.

Resposta:

```json
{"ok": true, "app": "…", "nome": "org.gimp.GIMP", "cor": "pink", "modo": "conversao",
 "saiu_do_arcticons": false, "tirou_retoque": true}
```

### 2.4 `ler` — como hoje

Continua respondendo `{"ok", "svg", "tem"}`; a tela não o chama mais
(`salvo` vem em `variacoes`), mas a porta fica — é o que um script externo
usaria.

---

## 3. O cliente — `oficinaDeDesenho(app, relerLista)`

### 3.1 O estado, um objeto só, fora do nó

Sobrevive ao `relerLista()` (regra de 08/09: a página inteira é
redesenhada ao salvar, e o `details` morreria fechado sob o cursor).

```js
let OFICINA = {
  app: null,            // id do .desktop; muda → tudo abaixo volta ao zero
  aberta: false,        // o `open` do details
  ocupada: false, erro: "",
  cor: "",              // corDaOficina(app), fixada ao abrir
  origem: "", original: "", capa: "",
  variacoes: [],        // como vieram do servidor
  vizinhos: [],
  salvo: null,          // {tem, svg, modo} ou null
  escolhida: null,      // id do cartão: "salvo" | "fiel" | … | "editado"
  base: "",             // o SVG do cartão escolhido, como veio (para saber se houve mão)
  svg: "",              // o texto vivo — o que a lupa mostra e o Usar grava
  parametros: "",       // do cartão escolhido, refeitos pelas réguas
  fonte: "icone",
  detalhe: 6, suavidade: 2, cheia: false,
  historico: [],        // pilha de `svg` para o Desfazer (máx. 30)
  temporizador: null,   // o debounce das réguas
};
```

`houveMao()` é `OFICINA.svg.trim() !== OFICINA.base.trim()`. É só
informativo na tela (o servidor decide o modo por conta própria, §2.3).

### 3.2 As funções, e o que cada uma faz

```
oficinaDeDesenho(app, relerLista)       monta o details; se OFICINA.app mudou, zera o estado e
                                        chama carregar() ao abrir (evento toggle → open)
carregar()                              POST variacoes → preenche OFICINA → escolhe o cartão
                                        inicial (salvo, se houver; senão fiel) → pintarTudo()
montarFolha()                           os cartões; Original é <figure>, os outros <button>
montarDock()                            a tira: vizinho · escolhida · vizinho, cor real
montarLupa()                            o SVG a 200 px com os paths clicáveis
montarReguas()                          dois <input type=range> + Desfazer
montarEdicao()                          o <details> "Editar o SVG" com o textarea de hoje
desenhar(texto, px, cor, {clicavel})    DOMParser → importNode → width/height/stroke-width/color
escolher(id)                            OFICINA.escolhida/base/svg/parametros/detalhe/suavidade/cheia/fonte
                                        ← do cartão; historico = []; pintarTudo()
tirar(i)                                empilha svg; remove o i-ésimo <path> do texto; pintarLupa+Dock+48
desfazer()                              desempilha; pintarLupa+Dock+48
reguar()                                debounce 250 ms → POST vetorizar {detalhe, suavidade, cheia, fonte}
                                        → base = svg = resposta; parametros = resposta; historico = []
usar()                                  POST salvar {svg, cor, seco, fonte, parametros} → torrada →
                                        se !seco: rodarAcao("icones_traco") → relerLista()
pintarTudo() / pintarLupa()             redesenham a partir de OFICINA, nunca do DOM
```

### 3.3 `desenhar()` — uma função para todos os tamanhos

```js
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
   * instalador. Aqui entram só para olhar, com os mesmos números que vão para
   * o disco: 2,25 de traço (o TRACO de 48x48/apps) e a cor da fileira acima. */
  no.setAttribute("stroke-width", "2.25");
  no.style.color = `var(--${cor})`;
  if (opcoes.clicavel) {
    no.querySelectorAll("path").forEach((p, i) => {
      p.dataset.i = String(i);
      p.setAttribute("tabindex", "-1");
      p.addEventListener("click", (e) => { e.preventDefault(); tirar(i); });
    });
  }
  return no;
}
```

`var(--pink)`, `var(--mauve)`… são os tokens por cor que o `estilo.css` já
usa (`.trilho > button.e-inicio { color: var(--mauve) }`). A prévia de hoje
pinta em `var(--text)`; a nova pinta na **cor real** — é o que a dock vai
mostrar.

### 3.4 `tirar(i)` — o texto é a verdade, o DOM é a vista

```js
function tirar(i) {
  const doc = new DOMParser().parseFromString(OFICINA.svg, "image/svg+xml");
  const paths = doc.querySelectorAll("path");
  if (!paths[i]) return;
  OFICINA.historico.push(OFICINA.svg);
  if (OFICINA.historico.length > 30) OFICINA.historico.shift();
  paths[i].remove();
  OFICINA.svg = new XMLSerializer().serializeToString(doc);
  pintarLupa(); pintarDock(); pintar48();
  botaoDesfazer.disabled = false;
}
```

O `XMLSerializer` preserva `xmlns`, `viewBox`, `fill="none"`,
`stroke="currentColor"` do `<g>` — é o mesmo documento, menos um nó. O
`_conferir_dialeto` do servidor continua sendo a cerca na hora de gravar.

### 3.5 Os cartões

```js
function montarFolha() {
  const folha = elemento("div", { class: "oficina-folha", role: "group", "aria-label": "Variações" });
  folha.append(elemento("figure", { class: "oficina-cartao oficina-original" }, [
    elemento("img", { src: OFICINA.original, alt: "", width: "48", height: "48", class: "oficina-original-48" }),
    elemento("img", { src: OFICINA.original, alt: "", width: "96", height: "96" }),
    elemento("figcaption", { texto: "Original" }),
  ]));
  const cartoes = [];
  if (OFICINA.salvo && OFICINA.salvo.tem) cartoes.push({ id: "salvo", rotulo: "Salvo", svg: OFICINA.salvo.svg });
  cartoes.push(...OFICINA.variacoes);
  for (const v of cartoes) {
    const b = elemento("button", {
      type: "button", class: "oficina-cartao", "data-id": v.id,
      "aria-pressed": String(OFICINA.escolhida === v.id),
      title: v.nota || v.erro || "",
      disabled: !!v.erro,
      onclick: () => escolher(v.id),
    });
    if (v.erro) {
      b.append(elemento("span", { class: "lugar", style: "width:48px;height:48px" }));
      b.append(elemento("span", { class: "oficina-rotulo oficina-erro", texto: v.rotulo }));
    } else {
      b.append(desenhar(v.svg, 48, OFICINA.cor));
      b.append(desenhar(v.svg, 96, OFICINA.cor));
      b.append(elemento("span", { class: "oficina-rotulo", texto: v.rotulo }));
    }
    folha.append(b);
  }
  return folha;
}
```

### 3.6 O dock

```js
function montarDock() {
  const tira = elemento("div", { class: "oficina-dock", "aria-label": "Como fica no dock" });
  const [a, b] = OFICINA.vizinhos;
  if (a) tira.append(desenhar(a.svg, 48, a.cor));
  tira.append(elemento("span", { class: "oficina-dock-eu" }, [desenhar(OFICINA.svg, 48, OFICINA.cor)]));
  if (b) tira.append(desenhar(b.svg, 48, b.cor));
  return elemento("div", { class: "oficina-dock-caixa" },
    [elemento("span", { class: "oficina-legenda", texto: "Como fica no dock" }), tira]);
}
```

### 3.7 As réguas

O mesmo `<input type="range">` que `montarControle()` produz para as doze
réguas de «Painel e dock» — copiar a classe e a estrutura de `label` dali,
para a régua da oficina ser igual às outras da página. Dois campos:

```js
const regua = (nome, rotulo, min, max) => {
  const entrada = elemento("input", {
    type: "range", name: nome, min: String(min), max: String(max), step: "1",
    value: String(OFICINA[nome]), "aria-label": rotulo, "data-foco": "oficina-" + nome,
    oninput: (e) => { OFICINA[nome] = Number(e.target.value); reguar(); },
  });
  return elemento("label", { class: "oficina-regua" }, [elemento("span", { texto: rotulo }), entrada]);
};
reguas.append(regua("detalhe", "Detalhe", 0, 10), regua("suavidade", "Suavidade", 0, 10));
```

`reguar()`:

```js
function reguar() {
  clearTimeout(OFICINA.temporizador);
  OFICINA.temporizador = setTimeout(async () => {
    OFICINA.ocupada = true; pintarLupa();
    const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({
      app: OFICINA.app, acao: "vetorizar", fonte: OFICINA.fonte,
      detalhe: OFICINA.detalhe, suavidade: OFICINA.suavidade, cheia: OFICINA.cheia }) });
    OFICINA.ocupada = false;
    if (r.erro) { OFICINA.erro = r.erro; pintarLupa(); return; }
    OFICINA.base = OFICINA.svg = r.svg; OFICINA.parametros = r.parametros || "";
    OFICINA.historico = []; OFICINA.escolhida = "editado";
    pintarTudo();
  }, 250);
}
```

Quando as réguas mudam, o cartão escolhido deixa de estar marcado
(`escolhida = "editado"`), porque o desenho já não é o dele. Clicar num
cartão de novo devolve as réguas para os valores dele.

### 3.8 `usar()`

```js
async function usar() {
  const seco = ensaiando();
  const r = await api("/api/app-desenho", { method: "POST", body: JSON.stringify({
    app: OFICINA.app, acao: "salvar", svg: OFICINA.svg, cor: OFICINA.cor, seco,
    fonte: OFICINA.fonte, parametros: OFICINA.parametros }) });
  if (r.erro) { OFICINA.erro = r.erro; torrada(r.erro, "erro"); pintarLupa(); return; }
  if (r.seco) { torrada(r.aviso, "igual"); return; }
  torrada(`${app.nome}: desenho salvo em ${r.cor}`
    + (r.nome && r.nome !== app.id ? ` (como ${r.nome})` : "")
    + (r.modo === "mao" ? ", à mão" : "")
    + (r.tirou_retoque ? " — o retoque anterior saiu" : "")
    + (r.saiu_do_arcticons ? " — e saiu do mapa Arcticons" : ""), "ok");
  await rodarAcao("icones_traco");     // abre a gaveta com a saída, como toda ação
  await relerLista();                  // OFICINA.aberta segura o details aberto
}
```

### 3.9 O `details` de edição

O `<textarea class="oficina-fonte">` de hoje, dentro de
`<details class="oficina-edicao"><summary>Editar o SVG</summary>`. No
`input`: `OFICINA.historico.push(OFICINA.svg); OFICINA.svg = area.value;
pintarLupa(); pintarDock(); pintar48();`. Quem edita o texto e volta para a
lupa vê o que editou.

### 3.10 Teclado e foco

- Os cartões são `<button>`: Tab percorre, Enter escolhe.
- Os `<path>` da lupa têm `tabindex="-1"`: não entram na fila do Tab (seriam
  40 paradas), e o caminho por teclado para tirar um traço é o textarea.
- Todos os campos novos levam `data-foco` (`oficina-detalhe`,
  `oficina-suavidade`, `oficina-svg`), para o `ancoraDoFoco` devolver o foco
  depois do `relerLista()`.

---

## 4. O CSS — substitui o bloco `.oficina-*`

Sem hex: o `tests/app.sh` varre o `estilo.css` por cor solta (fora dos
comentários). O vidro da dock, que na folha é `#3C3B50`, aqui é uma mistura
de tokens que dá o mesmo tom: `color-mix(in srgb, var(--base) 82%,
var(--text))` — em mocha, `0,82·#1e1e2e + 0,18·#cdd6f4 = #3d3e53`; em latte,
`#d2d4dc`, o vidro claro sobre papel claro.

```css
/* --- a oficina de desenho ------------------------------------------------- */
/* 09/09/2026, Sprint R. A tela responde a quatro queixas dela de 08/09: não
 * gerava variações, não mostrava o original ao lado, o traço saía em escada,
 * e editar era escrever XML. Agora: uma folha de cartões, o original como
 * régua, a lupa como editor (clique tira o traço), duas réguas de gosto. */
.oficina { margin: .2rem 0 1rem; }
.oficina > summary {
  cursor: pointer; display: flex; align-items: center; justify-content: space-between; gap: .4rem;
  padding: .4rem .6rem; border: 1px solid var(--surface1); border-radius: var(--r-2);
  background: var(--mantle); font-weight: 600; color: var(--text);
}
.oficina > summary:hover, .oficina[open] > summary { border-color: var(--accent); }
.oficina[open] > summary { margin-bottom: .6rem; }
.oficina-folha { display: flex; flex-wrap: wrap; gap: .6rem; margin: .4rem 0 .8rem; }
.oficina-cartao {
  display: flex; flex-direction: column; align-items: center; gap: .3rem;
  padding: .5rem .6rem .4rem; margin: 0;
  background: var(--fundo-teste, var(--mantle)); border: 1px solid var(--surface0);
  border-radius: var(--r-2); color: var(--text); font: inherit; cursor: pointer;
}
.oficina-cartao:hover { border-color: var(--overlay1); }
.oficina-cartao[aria-pressed="true"] { border-color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent); }
.oficina-cartao:disabled { cursor: default; opacity: .55; }
.oficina-original { cursor: default; border-style: dashed; }
.oficina-cartao svg, .oficina-cartao img { display: block; }
.oficina-rotulo { font-size: var(--t-legenda); color: var(--subtext0); }
.oficina-erro { color: var(--red); }
.oficina-dock-caixa { display: flex; align-items: center; gap: .8rem; margin: .4rem 0 .8rem; }
.oficina-legenda { font-size: var(--t-legenda); color: var(--subtext0); }
.oficina-dock {
  display: inline-flex; align-items: center; gap: 1rem; padding: .5rem .9rem;
  background: color-mix(in srgb, var(--base) 82%, var(--text));
  border-radius: var(--r-3);
}
.oficina-dock-eu { display: inline-flex; }
.oficina-par { display: grid; grid-template-columns: minmax(216px, 232px) 1fr; gap: .8rem; }
@media (max-width: 760px) { .oficina-par { grid-template-columns: 1fr; } }
.oficina-lupa {
  display: grid; place-items: center; width: 100%; min-height: 216px;
  background: var(--fundo-teste, var(--mantle)); border: 1px solid var(--surface0);
  border-radius: var(--r-2); color: var(--text);
}
.oficina-lupa svg { display: block; }
/* SEM `stroke` NO pointer-events O CLIQUE ATRAVESSA O TRAÇO: com fill:none, a
 * área "dentro" do path não é do path. É a primeira coisa a testar à mão. */
.oficina-lupa svg path { pointer-events: stroke; cursor: pointer; }
.oficina-lupa svg path:hover { stroke: var(--red); }
.oficina-lupa-dica { font-size: var(--t-legenda); color: var(--overlay1); text-align: center; }
.oficina-lado { display: flex; flex-direction: column; gap: .6rem; min-width: 0; }
.oficina-regua { display: flex; align-items: center; gap: .6rem; font-size: var(--t-frase); color: var(--subtext0); }
.oficina-regua span { min-width: 5.5rem; }
.oficina-regua input { flex: 1; }
.oficina-edicao > summary { font-size: var(--t-frase); color: var(--subtext0); cursor: pointer; }
.oficina-fonte { /* igual a hoje */ }
```

A prévia de 48 px ao lado da lupa sai: o 48 já está no cartão escolhido e
no dock. **Menos uma caixa.**

---

## 5. As palavras, todas

| onde | texto |
|---|---|
| resumo do `details` | `Desenho no nosso traço` |
| botão do resumo | `Usar` |
| cartões | `Original` · `Salvo` · `Fiel` · `Limpo` · `Silhueta` · `Detalhe` · `Área cheia` · `Da capa` |
| enquanto carrega | `Desenhando…` |
| sem arte de fábrica | `Sem arte de fábrica — desenhe em «Editar o SVG».` |
| legenda da tira | `Como fica no dock` |
| dica da lupa | `Clique num traço para tirar` |
| réguas | `Detalhe` · `Suavidade` |
| botão | `Desfazer` |
| edição | `Editar o SVG` |
| torrada em ensaio | a do servidor: `Em ensaio: <app> ficaria com este desenho em <cor>` |
| torrada ao gravar | `<App>: desenho salvo em <cor>` + os sufixos de §3.8 |
| `title` do cartão | a `nota` do conversor (`4 classes, 6 traços, 41 curvas`) |

Saem: as duas frases de hoje (*"Traz a arte de fábrica para o nosso
traço…"*, *"Grava em assets/icones/convertidos-apps/retoques/…"*), os
rótulos *Cores / Fusão / Aparo*, e os botões *Vetorizar*, *Abrir o que já
está salvo*, *Usar este desenho*, *Pôr na tela*.

---

## 6. `tests/app-navegador.py` — a seção 22

Depois da 20b e antes da 21, no padrão das conferências de 02/09 (responde
**certo**, não só responde). Usa `checa`, `seco`, `pixels_diferentes` e
`secao` que o arquivo já tem, e **dois helpers novos**, de três linhas cada,
ao lado de `md5_conf()`:

```python
def md5_de(caminho):
    with open(caminho, "rb") as fh:
        return hashlib.md5(fh.read()).hexdigest()

def foto(alvo, nome):
    """Captura de um locator (ou da pagina) num PNG temporario; devolve o caminho."""
    caminho = os.path.join(tempfile.gettempdir(), f"meow-nav-{nome}.png")
    alvo.screenshot(path=caminho)
    return caminho
```

```python
            print("\n22. A OFICINA: VARIACOES, O ORIGINAL AO LADO, CLIQUE PARA TIRAR")
            secao("Ícones")
            pag.wait_for_selector(".grade-apps button.app", timeout=15000)
            # Um aplicativo com arte de fabrica: o primeiro dos doze primeiros
            # cuja oficina responde com pelo menos cinco cartoes. Nao se fixa
            # um nome porque a grade e a maquina dela; se nenhum servir, pula.
            achou = None
            for botao in pag.locator(".grade-apps button.app").all()[:12]:
                botao.click(); pag.wait_for_timeout(250)
                det = pag.locator("details.oficina")
                if not det.count():
                    botao.click(); continue
                if not det.first.get_attribute("open"):
                    det.first.locator("summary").click()
                try:
                    pag.wait_for_selector(".oficina-folha button.oficina-cartao", timeout=12000)
                except Exception:
                    botao.click(); continue
                if pag.locator(".oficina-folha button.oficina-cartao").count() >= 5:
                    achou = botao; break
                botao.click()
            checa(achou is not None, "achei uma ficha cuja oficina desenha pelo menos cinco variacoes")
            if achou is not None:
                folha = pag.locator(".oficina-folha")
                checa(folha.locator("figure.oficina-original img").count() == 2,
                      "o original esta na folha, a 48 e a 96, ao lado das variacoes")
                lupa = pag.locator(".oficina-lupa")
                antes = foto(lupa, "22-lupa-antes")
                alvo = folha.locator("button.oficina-cartao[data-id='limpo']")
                alvo.click(); pag.wait_for_timeout(200)
                checa(alvo.get_attribute("aria-pressed") == "true", "o cartao clicado fica marcado")
                checa(folha.locator("button.oficina-cartao[aria-pressed='true']").count() == 1,
                      "e so um cartao fica marcado")
                dif = pixels_diferentes(antes, foto(lupa, "22-lupa-depois"))
                checa(dif is not None and dif > 1.0, f"a lupa muda quando o cartao muda ({dif:.1f}% dos pixels)")
                # o dock desenha a escolhida entre dois vizinhos
                checa(pag.locator(".oficina-dock svg").count() == 3, "a tira do dock tem os dois vizinhos e a escolhida")
                # clicar num traco tira o traco — e o CSS deixa o clique chegar no traco
                caminhos = lupa.locator("svg path")
                n = caminhos.count()
                pe = caminhos.first.evaluate("p => getComputedStyle(p).pointerEvents")
                checa(pe == "stroke", f"o traco recebe o clique pelo stroke (pointer-events={pe})")
                caminhos.first.dispatch_event("click"); pag.wait_for_timeout(150)
                checa(lupa.locator("svg path").count() == n - 1, f"clicar num traco tira o traco ({n} -> {n - 1})")
                pag.get_by_role("button", name="Desfazer").click(); pag.wait_for_timeout(150)
                checa(lupa.locator("svg path").count() == n, "Desfazer devolve o traco")
                # a regua re-vetoriza a escolhida
                regua = pag.locator(".oficina-regua input[name='suavidade']")
                antes = foto(lupa, "22-lupa-regua-antes")
                with pag.expect_response(lambda r: "/api/app-desenho" in r.url, timeout=20000):
                    regua.fill("9"); regua.dispatch_event("input")
                pag.wait_for_timeout(300)
                dif = pixels_diferentes(antes, foto(lupa, "22-lupa-regua-depois"))
                checa(dif is not None and dif > 0.3, f"mover a Suavidade redesenha a lupa ({dif:.1f}%)")
                checa(folha.locator("button.oficina-cartao[aria-pressed='true']").count() == 0,
                      "depois da regua nenhum cartao fica marcado — o desenho ja nao e o dele")
                # Usar em ensaio: torrada, e nada escrito
                retoques = os.path.join(RAIZ, "assets", "icones", "convertidos-apps", "retoques")
                mapa = os.path.join(RAIZ, "assets", "icones", "apps-convertidos.map")
                antes_r, antes_m = sorted(os.listdir(retoques)), md5_de(mapa)
                checa(seco(pag, True), "o ensaio liga")
                pag.locator("details.oficina > summary button", has_text="Usar").click()
                pag.wait_for_selector(".torrada", timeout=5000)
                checa("ensaio" in pag.locator(".torrada").last.inner_text().lower(), "Usar em ensaio avisa que e ensaio")
                checa(sorted(os.listdir(retoques)) == antes_r and md5_de(mapa) == antes_m,
                      "e nao escreveu em retoques/ nem no mapa")
                seco(pag, False)
                if FOTOS:
                    foto(pag, "22-oficina")
                    pag.evaluate("document.getElementById('principal').scrollTop = 600")
                    foto(pag, "22-oficina-rolada")
```

O `Usar` no
`summary` é um `<button>` dentro do `<summary>`: o clique nele **não** pode
fechar o `details` — `e.stopPropagation()` no `onclick` do botão, e um teste
de que o `details` continua `open` depois do clique entra na lista acima.

A seção 18 ("toda porta que escreve recusa em ensaio") já percorre as
portas; `variacoes` e `vetorizar` não escrevem e não entram lá; `salvar` já
está.

---

## 7. Navegar como usuária — o que se olha nas fotos

Com `tests/app-navegador.py --fotos`, em mocha **e** latte
(`MEOW_CONF` apontando para uma cópia com `FLAVOR="latte"`):

1. `22-oficina.png`: a folha inteira cabe em 1240 px de largura sem
   quebrar em três linhas? Oito cartões de ~112 px = 896 px — cabe. Se um
   rótulo quebrar (`Área cheia`), o cartão tem largura mínima de 104 px.
2. O vidro do dock: em latte, os três ícones continuam legíveis sobre
   `#d2d4dc`? Se não, a mistura vira 76/24.
3. `22-oficina-rolada.png`: a lupa e as réguas ficam alinhadas no topo? O
   `details` de edição fechado não deixa buraco?
4. **Ler as fotos** — não só salvá-las. Foi a foto, e não a suíte, que pegou
   os dois defeitos de 07/09.

---

## 8. Ordem de execução

1. §2 no servidor: `_parametros_de`, `PRESETS`, `variacoes`, o `vetorizar`
   por réguas, o `salvar` que decide o modo. `curl` de cada verbo com o
   token, antes de tocar no cliente:
   ```bash
   curl -s -H "X-Meow-Token: $T" -d '{"app":"org.gimp.GIMP","acao":"variacoes"}' http://127.0.0.1:$P/api/app-desenho | python3 -m json.tool | head -40
   ```
2. §3 + §4 no cliente. **Primeira coisa à mão**: o clique num traço da lupa
   chega no `<path>` (`pointer-events: stroke`).
3. §6 — a seção 22 passa; `tests/app.sh` passa (sem cor solta).
4. §7 — navegar como usuária, fotos em mocha e latte. **Mostrar a ela** —
   é a folha desta sprint. Até aqui nada foi gravado no repositório além do
   código.
5. Commit: `feat(painel): a oficina mostra variações, o original ao lado, e
   tira traço com um clique`.
6. `docs/SPRINTS.md`: Sprint R FECHADA, data, o que a medição derrubou.

**Tamanho:** um dia. ~150 linhas de Python, ~350 de JS, ~80 de CSS, ~80 de
teste.

---

## 9. O que pode dar errado, com o remédio ao lado

| sintoma | causa | remédio |
|---|---|---|
| clicar no traço não tira nada | `pointer-events` sem `stroke`; ou o listener foi posto antes do `importNode` | o CSS do §4; listeners depois de importar |
| a folha demora > 2 s | seis conversões em série, ou a capa da Steam de 600×900 | `ThreadPoolExecutor`; a capa só converte ao clicar em «Da capa» (`svg: null, tardio: true` na resposta, e o cliente pede `vetorizar {fonte:"capa"}` no clique) |
| a folha some depois de Usar | `relerLista()` recriou o nó e `OFICINA.variacoes` estava vazio | `carregar()` só quando `OFICINA.app` mudou; senão `pintarTudo()` do estado |
| o `Usar` fecha o `details` | o clique no botão borbulha para o `summary` | `e.stopPropagation()` |
| «Salvo» aparece diferente da dock | a dock mostra o **instalado** (`48x48/apps`), o cartão mostra o **construído** | é o estado real quando ela salvou e não pôs na tela; a torrada de `Usar` explica |
| `Original` sai 404 | a origem é um link simbólico do Papirus e o `realpath` sai das raízes permitidas | resolver o link **antes** de comparar na `/previa`, sem ampliar a lista |
| a régua dispara dez pedidos | `input` sem debounce | os 250 ms de `reguar()` |
| gravou `conversao` mas o construtor diz "divergente" | o cache respondeu com uma versão velha da origem | a chave do cache tem o `mtime` da origem; conferir que ele entra |
| `tests/app.sh` acusa cor solta | `#…` no CSS novo | só tokens e `color-mix` |
| latte: a tira do dock sem contraste | 82/18 clareia demais sobre papel claro | 76/24; remedir na foto |

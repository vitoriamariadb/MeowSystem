# O Heroic sem tema, e a oficina que não convence — sprints de 09/09/2026

Três sprints **abertas, nenhuma executada**. Este arquivo é autossuficiente:
quem for executar não precisa de contexto de conversa. Cada sprint traz o que
já foi medido, o que fazer, em que arquivo, como conferir, e o que pode dar
errado.

**O pedido dela, na noite de 08/09/2026, com uma captura do Heroic:**

> *"heroic games launcher não deu certo e o nosso gerador de ícones é fraco,
> não gera variações nem é tão bonito quanto o original, além de ficar
> pixelado e não ser intuitivo e fácil de usar. preciso que repense, crie as
> novas soluções em formato de sprints apenas. não as execute."*

São duas queixas, e a segunda tem quatro partes. Cada parte tem uma causa
medida, e nenhuma delas é a que o repositório supunha.

## As regras que valem nas três

1. **Nenhuma janela na tela dela.** Navegador é o Playwright sem cabeça em
   `~/.local/share/meowsystem/venv-testes`. Um aplicativo que precise abrir de
   verdade nasce e morre no workspace reservado a testes, nunca na frente dela;
   se o estacionamento da janela for recusado, a passagem para e avisa.
2. **A folha visual vem antes do código que muda pixel na tela dela.** Sprint
   Q e Sprint R geram folha; ela olha; só depois se instala.
3. **Medir antes de escrever, e medir de novo depois.** Cada sprint termina
   com uma seção "o que a medição derrubou" — foi de onde saiu quase todo o
   valor das sprints anteriores.
4. **Navegar como usuária no fim de cada leva, com foto.** A suíte verde não
   prova que a tela está certa. Esta leva nasce de um caso em que "medido de
   ponta a ponta" mediu arquivos, e a tela estava de fábrica.
5. O trabalho vai **em ondas por arquivo**, nunca duas frentes no mesmo
   arquivo. Cada frente reporta o que a medição dela contradisse neste texto.
6. Commit no formato dos recentes (`tipo(escopo): descrição`), um por sprint,
   só os arquivos tocados. Nada de `git add -A`.

---

## O que a captura dela mostra, medido em 09/09/2026

| | |
|---|---|
| Heroic | flatpak `com.heroicgameslauncher.hgl`, **2.22.1** (lido no `app.asar`) |
| processo | subiu às **23:52:44 de 08/09** — nove horas DEPOIS de o módulo aplicar (14:16) |
| `store/config.json` → `theme` | `catppuccin-mocha-mauve` |
| `config.json` → `defaultSettings.customThemesPath` | `…/.var/app/com.heroicgameslauncher.hgl/config/heroic/themes` |
| a pasta | os 56 CSS, 1,8 KB cada, permissão 644 |
| a tela | acento ciano, fundo de fábrica: **nada aplicado** |

Ou seja: tudo o que o módulo se propôs a escrever está escrito, o Heroic leu
o arquivo com o nosso valor ao subir, e mesmo assim mostra o tema de fábrica.

**As capas cinza não são nossas.** As seis capas da captura trazem o ícone de
baixar — jogo não instalado — e o CSS do próprio Heroic diz
`.gameImg:not(.installed){filter:grayscale(var(--installing-effect))}`. É o
jeito dele de mostrar "ainda não instalei". O tema não toca nisso.

### A causa, lida no código do 2.22.1 (não deduzida)

O backend, no `app.asar` (offset 20 638 126):

```js
addHandler("getThemeCSS", async (event, theme) => {
  const { customThemesPath = "" } = GlobalConfig.get().getSettings();
  const cssPath = path.join(customThemesPath, theme);     // ← sem acrescentar ".css"
  if (!existsSync(cssPath)) return "";
  return readFileSync(cssPath, "utf-8");
});
addHandler("getCustomThemes", async () =>
  readdirSync(customThemesPath).filter(f => f.endsWith(".css")));  // ← devolve NOMES COM ".css"
```

O front (offset 15 624 526):

```js
window.setTheme = async e => {
  document.querySelector("style.customTheme")?.remove();
  if (e !== "midnightMirage" && !Object.keys(temasEmbutidos).includes(e)) {
    const css = await window.api.getThemeCSS(e);        // pede o ARQUIVO pelo nome gravado
    e = e.replace(".css", "").replace(/[\s.]/, "_");    // e só DEPOIS tira o ".css" para virar classe
    const o = document.createElement("style"); o.classList.add("customTheme");
    o.innerHTML = css; document.body.insertAdjacentElement("afterbegin", o);
  }
  document.body.className = e;
};
window.setTheme(configStore.get("theme", "midnightMirage"));
```

**O valor gravado em `theme` tem de ser o nome do arquivo COM a extensão:
`catppuccin-mocha-mauve.css`.** O módulo grava `catppuccin-mocha-mauve`; o
backend procura um arquivo com esse nome exato, não acha, devolve vazio; o
front injeta um `<style>` vazio e põe `body.catppuccin-mocha-mauve` — uma
classe que nenhum CSS define — e a página cai nos valores de `:root`, que são
os de fábrica. Sem erro, sem aviso. É exatamente a captura.

O commit `764e230` afirma *"o valor de `theme` é o nome do arquivo sem o
`.css`"*. A afirmação veio do seletor do CSS (`body.catppuccin-mocha-mauve`),
não do handler. **O `.replace(".css","")` do front é a prova de que o valor
gravado carrega a extensão** — a substituição só existe porque há o que
substituir.

**E o "medido de ponta a ponta" daquele commit mediu arquivos.** Aplica,
confere, reaplica sem escrever um byte, reverte — tudo verdade, e nenhuma
dessas medições abriu o Heroic. A tela nunca foi olhada. É o mesmo modo de
falha de 07/09 (a suíte 84/84 com a faixa sambando), e a instrução dela
*"navegar como user ao final"* passa a valer para módulo de app também.

### Uma segunda coisa, menor, que vai aparecer assim que a primeira for curada

O acervo `catppuccin/heroic` parou em **maio de 2025** (último commit real:
"generate all accent colors"). O Heroic 2.22.1 usa **256 variáveis** via
`var(--…)`; o CSS do acervo define **56**. A maioria das ausentes é fonte,
espaçamento e FontAwesome, que não são cor. Mas há cor entre elas, e são
variáveis que o build define **só dentro do bloco de cada tema embutido** —
logo, com a nossa classe no `body`, ficam sem valor:

`--accent-overlay` · `--accent-02` · `--background-secondary` (`#323035`) ·
`--background-light` (`#eceff4`) · `--gamecard-title-color` · `--text-hover` ·
`--primary-hover` · `--secondary-hover` · `--brand-secondary` ·
`--brand-text-01/02` · `--status-*-hover` · `--installing-effect` ·
`--text-muted` · `--tour-*`

Uma variável sem valor dentro de `var()` invalida a propriedade inteira. O
resultado é botão sem hover, título de cartão sem cor, e — caso curioso —
`filter: grayscale(var(--installing-effect))` inválido, o que faria as capas
não instaladas **aparecerem coloridas**. Isso é para ela decidir olhando, não
para eu decidir escrevendo.

---

## Sprint P — O Heroic: o nome do tema leva `.css`  ← **FECHADA em 09/09/2026**

> **A TELA RESPONDEU, e é o que fechou esta sprint.** Com o Heroic aberto e
> medido por depuração remota do Electron:
>
> | | antes (a captura dela) | agora |
> |---|---|---|
> | `document.body.className` | `catppuccin-mocha-mauve` | `catppuccin-mocha-mauve` |
> | `style.customTheme` | **vazio** | **3 052 caracteres** |
> | `--accent` | ciano de fábrica | `#cba6f7` |
> | `--background` | de fábrica | `#1e1e2e` |
> | `--modal-backdrop` · `--gamecard-title-color` | vazias | `#000000cc` · `#11111bcc` |
>
> A classe do `body` era a MESMA nos dois lados — é por isso que o defeito
> parecia aplicado. O que mudou foi o `<style>` deixar de nascer vazio.
> Na foto, o acento mauve substitui o ciano em tudo: "Adicionar jogo", os
> botões de baixar, as letras do alfabeto, "Biblioteca" na barra lateral.
> Restam 115 das 256 variáveis sem valor, e são as que o Heroic **não define
> em tema nenhum** — FontAwesome (`--fa-*`), escopos locais (`--a`, `--b`,
> `--color`) e fonte. Quebram igual no tema de fábrica.
>
> **As capas cinza não eram nossas, e a premissa do remendo estava errada.**
> O `--installing-effect` não vem do tema: vem de estilo inline no cartão,
> escrito pelo JS (`style={{"--installing-effect": …}}`). Estilo inline num
> ancestral mais próximo vence a linha do `body` sempre. A linha ficou no
> remendo como guarda, não como cura, e está comentada dizendo isso.

**Tamanho:** ~1 h. A correção são três linhas; a validação é o trabalho.

### O que fazer

**1. `assets/temas-de-apps/heroic/manifesto.sh`** — `_heroic_tema()` (linha
80) devolve `catppuccin-<flavor>-<accent>.css`. O `meow_app_conferir`
(linha 222) e o `meow_app_aplicar` (linha 276) já usam a função, então
seguem sozinhos. O `reverter` (linha 310) continua gravando `midnightMirage`
**sem** extensão: é tema embutido, e o front pula o `getThemeCSS` para ele
(`Object.keys(temasEmbutidos).includes(e)`).

Corrigir o cabeçalho do módulo e o `PROCEDENCIA.md` onde dizem "sem o
`.css`", citando o handler acima como prova. Uma afirmação errada num
cabeçalho é o que fez este defeito parecer medido.

**2. O remendo das variáveis (a "segunda coisa").** O arquivo instalado em
`<config>/heroic/themes/catppuccin-<f>-<a>.css` passa a ser **o CSS do
upstream + um bloco nosso no fim**:

```css
/* MeowSystem: variáveis que o Heroic 2.22.1 usa e o acervo de 2025 não define */
body.catppuccin-mocha-mauve {
  --accent-overlay: <accent, mais claro>;
  --background-secondary: <surface0>;
  --background-light: <base do latte>;
  --gamecard-title-color: <text>;
  --text-hover: <accent>;
  --primary-hover: <accent, mais claro>;
  --secondary-hover: <accent, mais claro>;
  --brand-secondary: <accent>;
  --brand-text-01: <text>; --brand-text-02: <subtext1>;
  --status-success-hover: <green>; --status-warning-hover: <yellow>; --status-danger-hover: <red>;
  --text-muted: <overlay1>;
  --installing-effect: 100%;   /* decisão dela: capas de jogo não instalado ficam cinza, como de fábrica */
}
```

Os hex saem de `assets/paleta/catppuccin.json`, pelo mesmo `python3` que o
módulo já usa para o JSON — nunca escritos à mão no `.sh`. A lista acima é
a **candidata**; a lista **real** sai da medição do passo 4: só entra
variável que a tela mostrar vazia. O `SHA256SUMS` continua conferindo a
cópia do upstream no repositório; o `meow_app_conferir` compara o arquivo
instalado com o texto composto (upstream + bloco), pela régua do
`meow_escrever` (sem `\n` final), como hoje.

**3. Um conferidor no `meow doctor`** que lê o `app.asar` da versão instalada
(`flatpak info --show-location` → `files/bin/heroic/resources/app.asar`) e
confere que o handler ainda é `join(customThemesPath, theme)`:

```bash
grep -a -c 'join(customThemesPath, theme)' "$asar"    # 1 = a forma que este módulo grava
```

Se um Heroic futuro passar a acrescentar `".css"` ele mesmo, o doctor
**avisa** em vez de a tela apagar em silêncio. Não é auto-cura (não dá para
adivinhar a forma nova), mas transforma um defeito mudo num defeito com nome.

**4. Validar como usuária — sem tocar na tela dela.** Este passo é o que
faltou em 08/09.

- O Heroic dela tem de estar **fechado** (`SingletonLock`: uma segunda
  instância só dá foco à primeira, que está na frente dela). O módulo já
  recusa aplicar com ele aberto, e está certo. Se estiver aberto, a sprint
  espera; nunca `flatpak kill` na instância dela.
- Aplicar: `meow apps aplicar heroic` (ou o botão da aba "Lançadores e jogos").
- Abrir no workspace `OS`, com a porta de depuração do Electron — o
  `heroic-run` do flatpak repassa os argumentos (`zypak-wrapper … "$@"`):

  ```bash
  # O identificador da janela TEM de ser dito. O estacionamento adivinha pelo
  # primeiro argumento, e com um lançador no meio (`flatpak run`, `env`,
  # `python3 -m`) o palpite é `flatpak`/`env`/`python3` — a janela que ninguém
  # acha fica onde nasceu, que é o workspace DELA. Medido em 09/09: 35 s na
  # tela dela, e o log dizendo "App id not found: flatpak".
  AURORA_APPID=com.heroicgameslauncher.hgl \
    <estacionar> run flatpak run com.heroicgameslauncher.hgl --remote-debugging-port=9222
  ```

  E a janela de exposição não é zero nem assim: o estacionamento só age depois
  de a janela existir, e o Heroic leva ~8 s para desenhar. **Quando a janela
  não for necessária, não abra** — a medição por depuração remota funciona com
  ela em workspace inativo.

- Medir por CDP, no venv de testes, e tirar a foto **da janela**, não da tela:

  ```python
  from playwright.sync_api import sync_playwright
  with sync_playwright() as p:
      nav = p.chromium.connect_over_cdp("http://127.0.0.1:9222")
      pag = nav.contexts[0].pages[0]
      print(pag.evaluate("document.body.className"))                                  # catppuccin-mocha-mauve
      print(pag.evaluate("document.querySelector('style.customTheme')?.textContent.length"))  # > 1500, não 0
      print(pag.evaluate("getComputedStyle(document.body).getPropertyValue('--accent').trim()"))  # #cba6f7
      vazias = pag.evaluate("""(lista) => lista.filter(v =>
          !getComputedStyle(document.body).getPropertyValue(v).trim())""", LISTA_DO_BUILD)
      pag.screenshot(path="heroic-depois.png")
  ```

  `LISTA_DO_BUILD` são as 256 variáveis que o build usa, extraídas do asar
  com `grep -a -o 'var(--[a-z][a-z0-9-]*' | sort -u`. O que voltar em
  `vazias` e for cor é o conteúdo do bloco do passo 2 — **medido, não
  chutado**.
- Fechar a instância de teste (`flatpak kill com.heroicgameslauncher.hgl` —
  aqui sim, é a nossa), e mostrar a foto a ela.

### Como conferir que ficou certo

- `meow apps` → `heroic · aplicado`; `meow doctor` → "nada a consertar";
  `./install.sh` numa máquina pronta não escreve um byte.
- Trocar `FLAVOR`/`ACCENT` no `meow.conf` e reaplicar troca o arquivo
  gravado **e** a variável `--accent` medida por CDP.
- `reverter` deixa `midnightMirage` e leva embora só os 56 nossos.
- A foto de `heroic-depois.png` tem botão "Adicionar jogo" mauve e fundo
  `#1e1e2e`.

### O que pode dar errado

- **`.replace(/[\s.]/,"_")` sem `g`**: só o primeiro ponto vira `_`. Nossos
  nomes não têm ponto além da extensão; um tema com dois pontos no nome
  viraria classe quebrada. Não é nosso caso, fica registrado.
- **`select, input { box-shadow: none !important }`** no fim do CSS do
  upstream: é do acervo, não nosso; se ela estranhar campo sem borda, é ali.
- **Latte**: `--background-light` e `--text-tertiary` invertem de sentido no
  flavor claro. A folha do passo 4 tem de ser tirada em mocha **e** latte.
- O `park` recusar mover a janela do Heroic (alvo genérico, ou ela estar no
  `OS`): aceitar a recusa, avisar, e pedir que ela mesma abra o Heroic quando
  quiser ver.

---

## Sprint Q — O conversor: curva em vez de escada  ← **ABERTA**

> **Materializada em [`2026-09-09-sprint-q-conversor.md`](2026-09-09-sprint-q-conversor.md)**
> — as funções com corpo, a folha, o teste e a régua dos dois números. O que
> segue abaixo é o resumo; quem executa lê aquele.

**Tamanho:** meio dia. Só `numpy`, nenhuma dependência nova — salvo se a
folha provar que vale uma.

### A causa do "pixelado", e por que é a terceira causa com esse nome

Já houve duas: tamanho de arquivo (08/08: PNG de 512 reduzido a 48 em tempo
de desenho) e escala da tela (01/09: a TV em 90%). As duas estão curadas. A
terceira mora **dentro do arquivo**, e o próprio repositório a descreve sem
chamar de defeito:

- `scripts/converter_icone.py`, `segmentos()`: *"marching squares na forma
  discreta"* — cada aresta é um lado de pixel, em coordenadas de canto, numa
  grade de 256. A fronteira sai como **escada**.
- `dp()` (Douglas–Peucker, tolerância 1,6 px de 256) apara a escada mas não a
  desfaz: cada degrau que sobrevive é um vértice, e o traço vira uma
  polilinha de segmentos curtos em ângulos de 90° e 45°.
- `converter()` emite **só** `M x y x y …`. O `retoques/LEIA-ME.txt` diz com
  todas as letras: *"O conversor SÓ emite polilinha — não há uma linha nele
  que escreva `C`"*.

A 200 px na oficina a escada é visível a olho nu. A 48 px, com traço de 2,25,
ela vira a "tremida" que ela chama de pixelado. **Nenhum parâmetro conserta**,
porque `--tol` só escolhe quais degraus ficam.

### O que fazer

**1. Alisar, achar os cantos, ajustar curvas** — em `converter()`, entre
`encadear()` e a emissão:

- **Alisar ao longo da cadeia**: média móvel de janela 5 nos pontos do
  contorno (laço fechado: circular; linha aberta: pontas fixas). Mata a
  escada sem mudar a forma — o desvio máximo de uma janela 5 numa grade de
  256 é < 0,5 px, ou seja, < 0,1 px de 48.
- **Cantos**: depois de alisar, ângulo entre os vetores de ±3 pontos maior
  que 60° é canto. Cantos partem a cadeia em trechos. Sem isto o `>_` do
  terminal e o `B` do btop viram bolhas — e o limiar se **mede** nesses dois
  antes de fechar.
- **Curvas**: em cada trecho, ajuste de Bézier cúbica pelo algoritmo de
  Schneider (Graphics Gems, 1990): tangentes nas pontas pela corda,
  parametrização por comprimento, no máximo 4 iterações de Newton, e
  divisão no ponto de maior erro quando o erro passa de 1,0 px de 256.
  Trecho que não converge em 4 divisões cai para polilinha **daquele
  trecho** — a guarda contra laço auto-intersectante.
- **Emitir** `M x y C … [Z]`, duas casas decimais, como hoje.

**2. A gramática continua a mesma para quem lê.** `_vestido()` do
`icones_apps_arcticons.sh` injeta `stroke-width` em `<path ` — o espaço
depois do nome é o que ele procura, e continua lá. `_conferir_dialeto` do
painel não tem regra sobre comandos de path. Nada muda nos dois.

**3. Chaves**: `--curvas` (padrão) e `--polilinha` (o comportamento de hoje),
para a folha do passo 5 comparar lado a lado. A resolução fica em 256 — subir
para 384 custa 2,25× e só entra se a folha provar que muda algo.

**4. Corrigir o `retoques/LEIA-ME.txt`**: a frase "só emite polilinha" passa a
ser falsa, e a prova de que a boca do Wilber é manual ("o último subcaminho é
um `C`") envelhece junto. Reescrever a prova: os seis subcaminhos do
`org.gimp.GIMP.svg` são os de uma conversão **em `--polilinha`** de
`/usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg`, e é assim que se
confere. **O retoque não se reconverte** — é decisão registrada, e a regra do
diretório continua: nunca sobrescrito.

**5. A folha, antes de instalar.** `scripts/folha_conversor.py`, no molde de
`folha_icones.py` (48 px nos quatro fundos já medidos — `#1e1e2e`, `#eff1f5`,
`#3C3B50`, `#826E92` — e 200 px): uma linha por ícone, quatro colunas:

| original | polilinha (hoje) | curvas | potrace |
|---|---|---|---|

Todos os 33 do `apps-convertidos.map` mais os 5 que ela recusou em 11/08
(firefox, krita, thunderbird, BoxySVG, btop) — se as curvas resgatarem algum
deles, é ela quem diz. A coluna **potrace** existe para responder com medida
se vale uma dependência: `apt` tem `potrace 1.16` (≈100 KB); instala-se
**uma vez, à mão, só para a folha**, e ele traça cada classe de cor como
região fechada. Ele NÃO deduplica a fronteira entre duas classes vizinhas
(o `converter()` deduplica, e a nota de 11/08 mediu que duas cópias
"divergem e engrossam o traço"); se mesmo assim a coluna dele sair melhor,
entra em `etapa_pacotes` (`NECESSARIOS[potrace]=potrace`) e o `_desejado_de`
do `construir_convertidos.sh` passa a chamá-lo. Se não, nada novo no install.
**A escolha é dela, olhando a folha.**

**6. Depois do "sim" dela**: `scripts/construir_convertidos.sh` regenera os
33 (o `git diff` é a folha aprovada); `meow` → ação `icones_traco` põe na
tela; captura da dock — a dock é a tela dela, e é a única foto desta sprint
que é da tela de verdade.

**7. `tests/conversor.sh`**: três origens fixas do repositório (um autoral, um
Papirus SVG, um PNG); para cada uma, a saída em `--curvas` tem `C`, tem no
máximo 40 % dos pontos da saída em `--polilinha`, rasteriza no
`rsvg-convert` sem erro, não tem `stroke-width`, não tem cor, tem
`viewBox="0 0 48 48"`, e leva menos de 1 s. É o teste que impede a escada de
voltar sem ninguém ver.

### O que pode dar errado

- **Canto alisado**: o `>_` e o `B` são a régua. Se o limiar de 60° comer um
  deles, baixar para 45° e remedir — nunca "ficou bom no Spotify".
- **Laço que se cruza** depois do ajuste: a guarda do passo 1 (cai para
  polilinha no trecho). Contar quantos trechos caíram e imprimir no `stderr`,
  como as métricas de hoje.
- **A oficina fica mais lenta**: Schneider é vetorizado em `numpy`, e a rota
  do painel tem 60 s de prazo; a Sprint R roda seis conversões por clique,
  então cada uma tem de ficar abaixo de 0,3 s. Medir com `time` nos 33.
- **O GIMP muda de cara no `git diff`** mesmo sem ser reconvertido? Não pode:
  `retoques/` vence a conversão sempre. Se mudar, o construtor está lendo o
  lugar errado.

---

## Sprint R — A oficina: variações, o original ao lado, clicar para tirar  ← **ABERTA**

> **Materializada em [`2026-09-09-sprint-r-oficina.md`](2026-09-09-sprint-r-oficina.md)**
> — o contrato da rota com o JSON exato, o estado do cliente, cada função, o
> CSS, cada palavra da tela e a seção 22 do teste. O que segue é o resumo.

**Tamanho:** um dia. Depende da Sprint Q só para ficar bonita, não para
funcionar — pode ser construída em paralelo, em arquivos diferentes.

### O que existe, e por que não convence

A oficina de 08/09 (`app/pagina/app.js:2044`, rota `/api/app-desenho`) é: um
`details` com duas frases, três campos numéricos com o vocabulário do
conversor ("Cores", "Fusão", "Aparo"), uma caixa de texto com o XML do SVG,
duas prévias (48 e 200) e quatro botões. As quatro partes da queixa dela, uma
a uma:

| queixa | causa |
|---|---|
| "não gera variações" | um clique, um resultado; para ver outro, mexer em número |
| "não é tão bonito quanto o original" | o original **nunca aparece** ao lado, no mesmo tamanho; e a escada (Sprint Q) |
| "pixelado" | a escada, a 200 px |
| "não é intuitivo nem fácil" | editar é escrever XML; os números são do conversor, não dela; e o desenho salvo ainda precisa de um segundo botão para ir à tela |

E as quatro regras de interface dela (01/09) valem aqui como em toda tela:
menos palavras, acentuação, maiúscula inicial, e escolher não é gravar.

### A tela

```
Desenho no nosso traço                                                  [Usar]

 Original    Fiel      Limpo    Silhueta   Detalhe   Área cheia  (Da capa)
 ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐     ┌─────┐
 │ 48  │   │ 48  │   │ 48  │   │ 48  │   │ 48  │   │ 48  │     │ 48  │
 │ 96  │   │ 96  │   │ 96  │   │ 96  │   │ 96  │   │ 96  │     │ 96  │
 └─────┘   └═════┘   └─────┘   └─────┘   └─────┘   └─────┘     └─────┘
              ↑ a escolhida, com borda de acento

 Como fica no dock:   [ vizinho ]  [ ESCOLHIDA ]  [ vizinho ]     (48 px, cor real, vidro da dock)

 ┌───────────────────────────────┐   Detalhe    ────●─────
 │         200 px                │   Suavidade  ──●───────
 │  clique num traço para tirar  │
 └───────────────────────────────┘   Desfazer
 ▸ Editar o SVG
```

### O que fazer

**1. Servidor — `acao: "variacoes"`** em `_api_app_desenho`
(`app/servidor.py:4698`). Uma chamada devolve o original e seis desenhos. O
servidor é `ThreadingHTTPServer`; as seis conversões rodam num
`ThreadPoolExecutor(6)` e a rota responde em ~1 s hoje (< 0,5 s depois da
Sprint Q). Os presets, exatos:

| id | rótulo | Detalhe | Suavidade | `--k` | `--funde` | `--tol` | extra |
|---|---|---|---|---|---|---|---|
| `fiel` | Fiel | 6 | 2 | 8 | 52 | 1,0 | |
| `limpo` | Limpo | 2 | 6 | 4 | 84 | 2,2 | |
| `silhueta` | Silhueta | 0 | 4 | 2 | 100 | 1,6 | |
| `detalhe` | Detalhe | 10 | 1 | 12 | 20 | 0,7 | |
| `cheia` | Área cheia | 4 | 4 | 6 | 68 | 1,6 | `--cheia`: a maior classe interna sai como `<path fill="currentColor">` |
| `capa` | Da capa | 3 | 5 | 5 | 76 | 1,9 | só jogo da Steam; `fonte: "capa"` |

Cada preset é uma **posição das duas réguas** (`k = 2 + Detalhe`,
`funde = 100 − 8·Detalhe`, `tol = 0,4 + 0,3·Suavidade`): clicar num cartão
põe as réguas onde ele está, e mexer nas réguas parte dele.

"Área cheia" é dialeto legítimo: 13 dos 39 Arcticons têm
`fill="currentColor"`, e o `_vestido()` já troca o literal pela cor. A
`_conferir_dialeto` só exige que `fill="none"` exista no texto (está no
`<g>`), então passa. Precisa da chave `--cheia` no conversor — é a única
linha da Sprint R em `converter_icone.py`, e por isso **quem toca aquele
arquivo é a frente da Sprint Q**, que a recebe como item.

A resposta traz também `original: "/previa?tipo=arquivo&id=<origem>"` — a
rota já serve `/usr/share/icons`, os `exports` do flatpak, `~/.local/share/
icons` e a Steam, que são exatamente as raízes de `_arte_de_fabrica`. Cache
em memória por `(origem, mtime, preset)`: clicar de novo não converte de novo.

**2. Cliente — `oficinaDeDesenho` reescrita** (`app.js`), mesmo `OFICINA`
global que sobrevive ao `relerLista()` (regra de 08/09: aberta continua
aberta):

- **A folha de variações** abre junto com o `details`, sem clique. Cada
  cartão desenha o SVG a 48 e a 96, na cor de `corDaOficina(app)` e com
  `stroke-width="2.25"` só para olhar, como hoje. Clicar escolhe; a escolhida
  ganha `aria-pressed="true"` e borda de acento.
- **Como fica no dock**: a escolhida a 48 px entre dois vizinhos fixos do
  acervo Arcticons (o primeiro e o último do `apps-arcticons.map`, servidos
  pela mesma `/previa?tipo=arquivo`), sobre o vidro da dock (`#3C3B50`). É
  aqui que "tão bonito quanto o original" vira uma pergunta respondível.
- **Clique num traço para tirar**: na prévia de 200 px, cada `<path>` recebe
  `pointer-events: stroke; cursor: pointer` (com `fill:none`, sem isto o
  clique passa direto) e um `click` que marca `data-fora`. O traço some da
  prévia e do texto; **Desfazer** devolve o último. A 200 px o traço tem
  ~9 px de largura na tela, alvo suficiente.
- **Duas réguas, não três números**: *Detalhe* (0–10 → `k = 2 + d`,
  `funde = 100 − 8·d`) e *Suavidade* (0–10 → `tol = 0,4 + 0,3·s`). Mexer
  re-vetoriza a escolhida com 250 ms de espera, sem tocar nas outras.
- **Editar o SVG** vira um `details` fechado, com a caixa de texto de hoje.
  Quem quer XML acha; quem não quer não vê.
- **Usar** faz as duas coisas que hoje são dois botões: grava **e** roda
  `icones_traco`. A torrada diz "na tela em alguns segundos". Em ensaio
  (`seco`), nem grava nem roda — a rota já respeita, e `rodarAcao` também.

**3. Gravar o que é regenerável como regenerável.** Hoje tudo vira `mao` +
retoque. Passa a ser:

- escolheu uma variação e **não** tirou traço nem editou texto → linha
  `<nome>:<origem>:<cor>:<parâmetros>` no `apps-convertidos.map` (o campo 4
  já existe para isso) e o construído em `convertidos-apps/<nome>.svg`;
  **sem retoque**. O `construir_convertidos.sh` regenera igual amanhã.
- tirou traço ou editou → `mao` + `retoques/<nome>.svg`, como hoje. Retoque é
  decisão humana registrada, e só existe quando houve mão.

A rota recebe `modo: "conversao" | "mao"` e `parametros`; o servidor decide
a linha. O `--conferir` do construtor continua sendo o teste de que os dois
arquivos concordam.

**4. As palavras, todas** (acentuadas, maiúscula inicial, e nenhuma a mais):
`Desenho no nosso traço` · `Original` · `Fiel` · `Limpo` · `Silhueta` ·
`Detalhe` · `Área cheia` · `Da capa` · `Como fica no dock` ·
`Clique num traço para tirar` · `Desfazer` · `Detalhe` · `Suavidade` ·
`Editar o SVG` · `Usar`. As duas frases de hoje ("Traz a arte de fábrica…",
"Grava em assets/icones/…") saem: a folha explica o que a frase explicava.

**5. Testes — `tests/app-navegador.py`, cinco conferências novas**, no
padrão das de 02/09 (responde **certo**, não só responde):

1. abrir a ficha de um app com arte de fábrica → a folha tem o original e
   pelo menos seis cartões;
2. clicar num cartão → a prévia de 200 px muda (`pixels_diferentes`) e o
   cartão fica `aria-pressed`;
3. clicar num traço → um `<path>` a menos na prévia; Desfazer → volta;
4. mover *Suavidade* → uma chamada a `/api/app-desenho` e a prévia muda;
5. Usar em ensaio → torrada "em ensaio", e nenhum arquivo novo em
   `retoques/` nem linha nova no mapa.

`tests/app.sh` continua tendo de passar (sem cor solta no CSS: os cartões
usam `var(--…)`; o vidro da dock entra como variável nova em `estilo.css`).

**6. Navegar como usuária no fim**, com foto da ficha aberta e da ficha
rolada, em mocha e latte. Ler as fotos.

### O que pode dar errado

- **Seis conversões por abertura de ficha** em app com capa da Steam de
  600×900: o `rasterizar()` já reduz a 256, mas o `convert` da capa JPEG
  custa mais; medir e, se passar de 1,5 s, converter a capa **só quando o
  cartão "Da capa" for clicado**.
- **`pointer-events` em `<path fill="none">`**: sem `stroke` no
  `pointer-events`, o clique não pega. É a primeira coisa a testar, à mão,
  antes da suíte.
- **O `details` fechando após `relerLista()`**: já curado em 08/09 pelo
  `OFICINA.aberta`; a folha de variações precisa guardar-se no mesmo objeto,
  senão some sob o cursor depois do Usar.
- **`/previa?tipo=arquivo` recusando a origem**: a raiz está na lista, mas o
  `realpath` de um link do Papirus pode sair dela; nesse caso a rota deve
  resolver o link **antes** de comparar, não ampliar a lista.
- **Duas verdades sobre a cor**: a fileira de cor de cima continua sendo a
  única; a oficina lê `corDaOficina(app)` e nunca grava cor própria.

---

## Ordem, ondas e quem faz

**Onda 1 — em paralelo, um conjunto de arquivos por frente:**

| sprint | arquivos | não toca |
|---|---|---|
| P | `assets/temas-de-apps/heroic/manifesto.sh`, `PROCEDENCIA.md`, o conferidor no doctor (`bin/meow` ou `lib/`) | nada do painel |
| Q | `scripts/converter_icone.py` (inclui `--cheia` da R), `scripts/folha_conversor.py`, `tests/conversor.sh`, `retoques/LEIA-ME.txt` | `construir_convertidos.sh` só depois da folha |
| R | `app/pagina/app.js`, `app/pagina/estilo.css`, `app/servidor.py`, `tests/app-navegador.py` | `converter_icone.py` — pede a `--cheia` à Q |

**Onda 2 — depois de ela olhar as folhas:** Q regenera os 33 e põe na tela;
R fecha com a caminhada de usuária; P fecha com a foto do Heroic por CDP.

Cada frente reporta **o que a medição dela contradisse neste arquivo**, e o
relato é hipótese até ser reproduzido — a validação é medir de novo.

## O que a medição derrubou ao escrever este plano

- *"O valor de `theme` é o nome do arquivo sem o `.css`"* (commit `764e230`,
  cabeçalho do módulo, `PROCEDENCIA.md`): **falso** no 2.22.1; o handler
  não acrescenta extensão, e o front a remove depois de pedir o arquivo.
- *"Medido, de ponta a ponta"* (mesmo commit): mediu os arquivos; a tela
  nunca foi aberta. Passa a valer, para módulo de app, a mesma regra do
  painel: a foto fecha a sprint.
- *"Gerar o CSS a partir da nossa paleta daria o mesmo resultado com mais
  código"* (`PROCEDENCIA.md`): meia verdade — o mapeamento do upstream é o
  trabalho de verdade dele **e está um ano atrás do Heroic**. O remendo da
  Sprint P é o menor complemento que fecha a diferença, medido na tela.
- *"O pixelado"* já teve duas causas curadas (tamanho, 08/08; escala, 01/09).
  A terceira está no arquivo, e o repositório a descrevia como característica
  ("forma discreta", "só emite polilinha"), não como defeito.
- *"A oficina gera variações"* (resposta de 08/09 ao pedido dela sobre as
  capas): entregou um par Ícone/Capa. Variação, para ela, é **ver várias e
  escolher** — e o original ao lado para comparar.

# O painel vira produto — frentes de 06/09/2026

Este documento é a fonte autossuficiente das frentes abaixo. Quem trabalha em
uma delas não precisa de mais nada além do repositório e desta folha.

> **NOTA DE 07/09/2026 — DUAS SEÇÕES MUDARAM DE NOME DEPOIS DESTE DOCUMENTO.**
> Onde se lê **«Barra e dock»**, hoje é **«Painel e dock»**; onde se lê
> **«Idempotência»**, hoje é **«Atualização»**. Isso vale inclusive para as
> **chaves de registro** do `window.MEOW_PREVIAS` citadas mais abaixo — a chave
> viva é `"Painel e dock :: VIDRO E RELÓGIO"`, e o bloco da música é
> `MÚSICA NO PAINEL`, não `MÚSICA NA BARRA`. Copiar daqui sem trocar registra
> um desenho que nunca aparece. O elemento se chama *painel* em todo texto de
> tela; onde "barra" sobrevive no `meow.conf.exemplo`, é o termo genérico para
> "painel **ou** dock". Estado atual em
> `docs/sprints/2026-09-07-acabamento-do-painel.md`.

## A decisão que originou tudo

O painel nasceu como a interface do `meow.conf` **dela**. Hoje ele é público, e
a tela precisa fazer sentido para quem não tem a Coquinha e a Mimir, não sabe o
que é `VIDRO_OPACIDADE_DOCK` e nunca leu um `.conf`. Toda mudança aqui responde
a uma frase só: **o nome na tela diz do que se trata, e o detalhe fica a um
clique.**

## As regras que valem em todas as frentes

1. **Não abrir janela na tela dela.** Nenhum navegador, nenhum app, nenhuma GUI.
   Quem precisar de navegador usa o Playwright em
   `~/.local/share/meowsystem/venv-testes` contra `http://127.0.0.1:<porta>`.
2. **Não reiniciar o `cosmic-panel`, o `cosmic-comp` nem a sessão.**
3. **`git add` só nos arquivos que a frente tocou.** Nunca `git add -A`.
4. **Mensagem de commit `tipo: descricao`, sem acentos** — há um gancho que
   recusa outros formatos. Sem rodapé de co-autoria, sem link de sessão.
5. **O vocabulário do repositório é `frente`, `passagem`, `medição`,
   `conferência`.** Nenhum arquivo versionado menciona ferramenta de assistência.
6. **Contrato de idempotência**, para todo script: `0` já estava assim · `1`
   estava diferente e eu consertei · `2` erro · `3` falta dependência · `4`
   pendência que não é nossa para consertar.
7. **`MEOW_SECO=1` / `MEOW_DRY_RUN=1` tem de atravessar tudo.** Ensaiar nunca
   escreve.
8. **Nada de literal hexadecimal no `estilo.css`.** As cores vêm das variáveis
   de `/paleta.css` (`var(--yellow)`, `var(--surface0)`, `var(--mauve)`…).
9. **O catálogo é derivado, nunca escrito à mão.** Os comentários do
   `meow.conf.exemplo` são lidos por `wiz_ler_esquema` (bash, `bin/meow`) e por
   `ler_esquema()` (`app/servidor.py`). O `tests/app.sh` falha se os dois
   divergirem.
10. **Ao terminar, relate o que a sua medição CONTRADISSE nesta folha.** É de
    onde sai o valor. Uma frase escrita aqui é hipótese até ser reproduzida.

## O estado antes destas frentes

- 103 chaves no `meow.conf.exemplo`, 37 ações no painel, tudo verde:
  `tests/app.sh`, `seco.sh`, `reversao.sh`, `midia.sh`,
  `um-cartao-por-jogo.sh`, `convergencia.sh`, `app-navegador.py` (61/61).
- `./install.sh` converge na segunda passagem; `meow doctor` diz "nada a
  consertar".
- Menu em três blocos: `Assuntos` · `A Máquina` · `A nova versão`.

---

## Frente A — os nomes, no `meow.conf.exemplo`

**Só toca `meow.conf.exemplo`.**

O painel deriva as seções deste arquivo, então o menu muda aqui, não no
JavaScript.

| Antes | Depois |
| --- | --- |
| `# --- Cor e tema ---` (3 chaves) + `# --- Janelas e tela ---` (5 chaves) | uma seção só: `# --- Cor e tela ---` (8 chaves) |
| `# --- O gato ---` (21 chaves) | `# --- Logo do sistema ---` |
| `# --- Programas e jogos ---` (4 chaves) | `# --- Lançadores e jogos ---` |
| as 7 chaves `LEITURA_*`, hoje dentro de `# --- Dia e noite ---` | seção própria: `# --- Modo de leitura ---` |

Depois disto `Dia e noite` fica com 6 chaves e `Modo de leitura` com 7 —
`LEITURA_AGENDA`, `LEITURA_HORARIO_INICIO`, `LEITURA_HORARIO_FIM`,
`LEITURA_TEMPERATURA`, `LEITURA_TEXTURA`, `LEITURA_RAMPA_MIN`,
`LEITURA_APPLET`.

**As três travas desta frente:**

- **As linhas de chave ficam byte-idênticas.** Só a ordem e os títulos de seção
  mudam. Confira com
  `git show HEAD:meow.conf.exemplo | grep -E '^[A-Z][A-Z0-9_]*=' | sort > /tmp/antes`
  e o mesmo sobre o arquivo novo: o `diff` tem de ser vazio.
- **A colagem sustenta a herança.** 29 chaves herdam o comentário da chave
  anterior, e o que sustenta isso é a **ausência de linha em branco** entre
  elas. Mover um bloco sem mover as linhas coladas junto quebra 29 cartões em
  silêncio.
- **Os marcadores.** `# @ ` abre o título do cartão e `# > ` a frase de uma
  linha embaixo do controle. Eles são retirados ANTES da decisão de herança.
  Um deles perdido vira um cartão sem nome.

`# --- Capitulares ---` abre uma seção; `# --- CAIXA ALTA ---` abre um bloco
dentro dela (a razão de maiúsculas acima de 0,7 é o que separa os dois).

**Conferência:** `bash tests/app.sh` verde, e `grep -c '^# --- '` com o número
de seções esperado.

---

## Frente B — os scripts que o painel ainda não tem como chamar

**Só toca `scripts/`.** Não mexer em `app/`.

Três botões que a tela pede e que hoje não existem do lado de cá:

1. **`scripts/cursor.sh`** ganha `listar` e `adicionar`.
   - `listar` imprime, uma por linha, o nome de cada tema de ponteiro instalado
     em `$CURSOR_ICONES` (`$HOME/.local/share/icons`, pastas `*-cursors` com
     `cursors/` dentro). Hoje só um aparece no painel porque só um está
     instalado — **meça isso antes de chamar de erro**: `ls ~/.local/share/icons`.
   - `adicionar <url-ou-arquivo>` instala um tema novo. A rota de descarga já
     existe no arquivo; reaproveite-a em vez de escrever outra.
2. **`scripts/instalar_fontes.sh`** ganha `adicionar <arquivo>` — `.zip`,
   `.ttf` ou `.otf` — que instala em `~/.local/share/fonts` e roda `fc-cache`.
   As famílias que o projeto já usa (`JetBrainsMono Nerd Font Mono`,
   `Fira Sans`) continuam intactas.
3. **A pasta de ícones**: um `adicionar <pasta-ou-zip>` que aceita um acervo de
   ícones novo e o deixa onde o resto do projeto o enxerga. Ache o script que
   hoje instala os acervos e acrescente lá, sem criar um script paralelo.

Todos respeitam o contrato de idempotência e `MEOW_SECO=1`. Todos são
reversíveis (`cmd_reverter`, se o arquivo já tiver um).

**Conferência:** cada subcomando novo rodado duas vezes seguidas — a segunda
devolve `0`. E `MEOW_SECO=1 <subcomando>` não deixa arquivo no disco (`find
~/.local/share/fonts -newermt '-2 minutes'` vazio).

---

## Frente C — o respiro do cartão, no `estilo.css`

**Só toca `app/pagina/estilo.css`.**

A queixa dela, com a tela na frente: *"tem algo no nosso estilo que deixa tudo
muito confuso e difícil de entender. temos que melhorar isso e darmos respiro
nesse sentido."*

O cartão hoje carrega **seis camadas**: título · aviso · controle · explicação ·
rodapé (nome da chave, selo, padrão de fábrica) · "▸ Por quê". Ela leu isso e
disse duas coisas, e as duas são literais:

- *"essa parte que selecionei tem que sumir também"* — apontando o
  `VIDRO_OPACIDADE_DOCK` — *"isso pra todos"*.
- *"o tooltip fica em `?` ao lado direito do nome da seção"*.

**Como o cartão fica:**

```
Opacidade da dock  (?)
[ deixar como está          ]
0 é transparente, 1 é opaco.
```

Três camadas. O `?` fica **à direita do título**, é do tamanho de uma legenda, e
a dica que ele abre contém **o porquê, o nome da chave e o padrão de fábrica** —
nada se perde, tudo fica a um clique.

**O contrato de marcação, para que esta frente e a Frente F não colidam:**

- `.cartao > .titulo` continua o título. O gatilho é
  `<button class="porque" aria-expanded="false" aria-controls="dica-N">` com o
  texto `?`, irmão imediato do título.
- A dica é `<div class="dica" id="dica-N" role="tooltip" hidden>` e dentro dela,
  nesta ordem: `<p class="motivo">`, `<code class="chave">`, `<span
  class="fabrica">`.
- Abre no `hover`, no `focus` e no clique — teclado tem de alcançar. Fecha no
  `Esc` e ao sair.
- Ela se posiciona sem transbordar a janela e **sem** biblioteca externa.
- `.cartao .chave` e `.cartao .fabrica` no corpo do cartão deixam de existir.
  Apagar a regra, não escondê-la com `display:none`.

**O botão de ensaio**, no mesmo arquivo: `.seco` deixa de ser caixa de marcar e
vira botão que fica aceso. As regras de `var(--yellow)` que já estão nas linhas
181–186 são exatamente a cor certa — reaproveite-as em
`.btn-ensaio[aria-pressed="true"]`. Apagado quando desligado, amarelo fraco
quando ligado.

**O selo de "pode ensaiar"** dos cartões de ação sai. A razão dela: *"o botão
Pode ensaiar não faz sentido se temos o executar ali em todas as páginas — é pq
o user quer arrumar só aquilo."* Com o interruptor global aceso no topo, cada
`Executar` já ensaia; sem ele, executa de verdade. O selo por cartão virou ruído.

**Conferência:** `grep -nE '#[0-9a-fA-F]{3,8}' app/pagina/estilo.css` vazio, e a
folha continua válida.

---

## Frente D — o banner e o cabeçalho, no `index.html`

**Só toca `app/pagina/index.html`.**

1. **A logo.** `<img class="gato" src="/gato.svg">` passa a mostrar a logo
   autoral do painel — o gato de traço roxo que é o ícone do `.desktop`, em
   `assets/icones/autorais/meowsystem-painel-<sabor>.svg`, resolvido como
   `com.meowsystem.Painel`. Pedido dela: *"a logo do .desktop deve ser usada
   para ser a logo oficial do banner do app ao invés da coquinha e do mimir"*.
   A Coquinha e a Mimir não somem do projeto — elas continuam sendo o que vem de
   fábrica na aba **Logo do sistema**. O que muda é que a marca do aplicativo
   deixa de ser um gato dela e passa a ser a marca do produto.
   O `alt` fica vazio: ao lado já está escrito MeowSystem.
2. **`Importar ajustes` vira `Importar`.** Pedido dela, literal.
3. **A caixa de marcar `#seco` vira botão:**
   `<button type="button" id="seco" class="btn btn-ensaio" aria-pressed="false">Ensaiar sem gravar</button>`.
   O `title` continua dizendo o que ele faz.

**Cuidado:** `app.js` lê `$("#seco").checked` em seis lugares. Esta frente **não
mexe no JavaScript** — a Frente F faz a troca por um `ensaiando()`. Deixe o
comentário no HTML dizendo isso, para o próximo não achar que está quebrado.

---

## Frente E — o servidor

**Só toca `app/servidor.py`.** Depende das frentes A e B estarem no lugar.

1. **`DESCRICAO_SECAO`** ganha as entradas novas — `Cor e tela`,
   `Logo do sistema`, `Lançadores e jogos`, `Modo de leitura` — e perde
   `Janelas e tela`. Uma linha por seção, do jeito que as outras já são.
2. **Os blocos do menu**, pedido dela:
   - `Assuntos` → **`Tópicos`**
   - `A Máquina` → **`Sistema`**, e dentro dele **`Manutenção`**,
     **`Instalação`** (era "Instalar e conferir") e **`Idempotência`** (era
     "Atualizar o sistema").
   - Atenção: hoje `Manutenção` cai em `Tópicos` porque `blocoDoAssunto` decide
     por "este assunto tem chaves?", e ela tem 9. Passar `Manutenção` para
     `Sistema` exige que o servidor mande o bloco explicitamente, como já faz
     com `"bloco": "A nova versão"` nas três ações `sistema_*`. **Este é o
     ponto onde a folha pode estar errada — meça antes.**
3. **Os acervos que faltam.** O `ACERVOS` já aceita `gato`, `parede` e `icone`
   por `POST /api/acervo`. Acrescente `cursor` e `fonte`, chamando os
   subcomandos da Frente B. E o `parede` passa a aceitar **para qual lado** a
   imagem vai — dia ou noite —, porque a pergunta dela era essa: *"como
   adicionamos os wallpapers pelo html e eles vão pra pasta correta"*.
4. **O lado da imagem.** Já existe `_grupo_de_luz(caminho)` devolvendo
   `{"lado","luz","corte"}`. Ele mede; agora ele também **decide o destino** de
   uma imagem enviada, com o palpite dele como padrão e a escolha dela por
   cima. Cada ficha da galeria passa a mandar as duas ações — `dia` e `noite` —
   além de `Tirar`.
5. **Os ícones de jogo.** Pedido: *"na parte de ícones, os ícones que forem de
   jogos, coloca pra serem selecionados na aba Lançadores e Jogos"*. O
   `_dados_jogos` já sabe quem é jogo; use o mesmo critério para tirar esses
   ícones da aba de ícones e servi-los na de jogos. **Não duplique a lista** —
   um jogo tem um cartão só, e existe um teste que garante isso
   (`tests/um-cartao-por-jogo.sh`).

**Conferência:** `bash tests/app.sh` verde. As ações novas rodadas em seco não
tocam o disco.

---

## Frente F — a página

**Só toca `app/pagina/app.js`.** É o arquivo mais disputado do repositório;
ninguém mais escreve nele nesta rodada. Depende de C, D e E.

1. **O `?` e a dica** — a outra metade da Frente C. `.chave` e `.fabrica` saem
   do corpo do cartão e passam para dentro da dica. O `<details>`/"▸ Por quê"
   deixa de ser desenhado.
2. **`ensaiando()`** substitui os seis `$("#seco").checked`. Ela leu a regra
   assim: *"uma box pra marcar se quero ensaiar sem gravar. Se ela tiver
   marcada, cada executar faz isso. Caso contrário ele executa de fato."* — o
   comportamento não muda, só o controle. O selo por cartão sai.
3. **Os botões que faltam**, todos por `botaoAcervo`, que já existe e já
   protege contra o modo seco:
   - **Papel de parede: falta o botão de adicionar.** É ligação, não capacidade
     nova — o `ACERVOS["parede"]` já responde. Junto dele, cada imagem passa a
     oferecer **Dia**, **Noite** e **Tirar** ao passar o rato.
   - **Tema do ponteiro: falta o botão de adicionar**, e a lista tem de mostrar
     todos os que o `cursor.sh listar` devolve.
   - **Fontes: não há como instalar uma.** Passa a haver.
   - **Ícones: falta adicionar pasta nova de ícones.**
4. **A aba `Logo do sistema`, reescrita.** Ela deixou o alvo claro: *"por
   default temos os meus dois gatos ali, mas pensando em produto ele precisa
   dizer pro user que ele pode colocar o ícone do Menu de Lançamento — apertar a
   tecla Windows, e o atual logo do Pop!_OS."* Então a aba passa a dizer, em
   três lugares nomeados:
   - **Logo do menu de lançamento** — o que aparece ao apertar a tecla Super, no
     lugar da coquinha do Pop!_OS.
   - **Logo da dock.**
   - **Logo do terminal.**
   Mais *"troca sozinho de dia e de noite"*. De fábrica: Coquinha e Mimir. E um
   botão **Adicionar logo**. Os termos da aba deixam de falar em gato para falar
   em logo — **exceto** onde o assunto é literalmente o gato que vem de fábrica.
5. **Os grafismos do menu** (`ICONES_MENU`) seguem os nomes novos:
   `bloco/Tópicos`, `bloco/Sistema`, `Cor e tela`, `Logo do sistema`,
   `Lançadores e jogos`, `Modo de leitura`. As entradas mortas saem.
6. **`FRASE_DO_BLOCO`** e as portas da página inicial acompanham.

---

## Frente G — os testes e as duas folhas de rosto

**Toca `tests/app.sh`, `tests/app-navegador.py`, `README.md`, `README.en.md`.**
Por último, quando A–F estiverem no lugar.

- Os nomes de aba do `app-navegador.py` mudam todos. A contagem de trilhos do
  menu muda (uma seção a mais, duas viraram uma).
- O `tests/app.sh` conta chaves e cartões — os números mudam.
- Os dois README trocam os nomes das seções e ganham a linha do que passou a
  ser possível: adicionar papel de parede escolhendo dia ou noite, adicionar
  tema de ponteiro, instalar fonte, adicionar pasta de ícones.
- **Toda imagem nova passa por `mogrify -strip` antes de ser versionada.**
  Imagens carregam metadados que o grep de marca acusa.

---

## A conferência final, minha

Depois das sete frentes: `install.sh` duas vezes (a segunda converge),
`meow doctor`, a bateria inteira de testes, e a navegação aba a aba pelo
Playwright — com a tela dela intocada.

E a varredura que precede qualquer envio:

```
# os colchetes existem para que a linha nao encontre a si mesma
git ls-files -z | xargs -0 grep -liE '[c]laude|[a]nthropic|\b[a]gentes?\b'
```

Vazio, sem filtrar para texto — imagem é arquivo como qualquer outro. A
mesma varredura corre sobre as mensagens de commit.

---

## Frente H — um desenho por bloco

Pedido dela, com a tela de "Barra e dock" na frente:

> *"talvez não fosse melhor cada seção interna ter um exemplo igual temos a
> forma ali? Pq eu mesma tô extremamente confusa sobre o que tal coisa faz. Eu
> mesma não consigo fazer nada sem te pedir ajuda."* — *"tudo com svg simples"*

Esta é a frente mais importante da rodada, e a razão é dura de ouvir: **a dona
do projeto não consegue usar o painel sozinha.** Se ela não consegue, ninguém
consegue. O bloco `FORMA` é o único lugar da tela onde isso não acontece, e o
que ele tem de diferente não é texto melhor — é um desenho que responde antes
da leitura, e que muda quando o valor muda.

A regra que sai daqui: **todo bloco tem um desenho, e o desenho reage aos
valores do próprio bloco.** Não é ilustração; é a resposta à pergunta "o que
isto faz com a minha tela?".

### O contrato, para que as duas metades não colidam

Cada metade escreve **um arquivo novo seu**, e nenhuma das duas toca `app.js` ou
`estilo.css` — a Frente F liga os fios depois.

```js
/* previas-<metade>.js */
window.MEOW_PREVIAS = Object.assign(window.MEOW_PREVIAS || {}, {
  "Barra e dock :: VIDRO E RELÓGIO": (v) => ({ svg, legenda }),
  "Ícones": (v) => ({ svg, legenda }),
});
```

- A chave é `"Seção :: BLOCO"`, e só `"Seção"` quando a seção não tem bloco em
  CAIXA ALTA. Os nomes de seção são os **novos** (Frente A): `Cor e tela`,
  `Logo do sistema`, `Lançadores e jogos`, `Modo de leitura`.
- `v` é um objeto simples `{ NOME_DA_CHAVE: "valor" }` com as chaves daquele
  bloco, valores como estão no `meow.conf` (string, podendo ser vazia).
- O retorno é `{ antes, depois, legenda }`. Pedido dela, e é o coração da
  frente: *"tipo mostrando visualmente o que vai fazer o negócio"* — *"o antes e
  depois talvez"*.
  - `antes` é um `SVGElement` desenhando **como está agora** (os valores em
    vigor, ou o padrão do COSMIC quando a chave está vazia).
  - `depois` é o mesmo desenho **com o valor escolhido**, e é `null` quando não
    há escolha pendente no bloco — aí a tela mostra um desenho só.
  - Os dois usam o mesmo `viewBox` e o mesmo enquadramento, para que a diferença
    salte. Desenho que muda de escala entre um e outro não deixa comparar nada.
  - `legenda` é **uma linha**, no padrão que a `FORMA` já usa: começa por
    `desenho, não captura:` e diz os números desenhados. Valor vazio se diz
    assim: *"vazio no meow.conf significa que o COSMIC decide, e aqui aparece o
    padrão dele"*.
- Ambos são montados por `document.createElementNS`. Quem consome desenha
  `antes` e `depois` lado a lado, rotulados **Como está** e **Como fica** — a
  Frente F faz isso; aqui basta devolver os dois.
- Sem biblioteca, sem `innerHTML`, sem literal hexadecimal: as cores são
  `currentColor` e as variáveis de `/paleta.css` (`var(--mauve)`,
  `var(--surface0)`, `var(--text)`…).
- **Traço, não chapado.** É o estilo do projeto: `fill="none"`,
  `stroke-width` por volta de 2 num `viewBox` de 48, cantos e pontas
  arredondados. Um desenho que precise de preenchimento usa a cor de superfície,
  nunca uma cor de marca chapada.
- `viewBox` fixo e `width="100%"`, `height` entre 90 e 140 px. `role="img"` e um
  `<title>` que descreva o desenho em meia linha — quem usa leitor de tela
  recebe a mesma informação.
- A função é **pura**: mesmo `v`, mesmo desenho. Nada de rede, nada de relógio,
  nada de `Math.random`.
- Se um valor de `v` for inválido ou vazio, desenhe o padrão e diga isso na
  legenda. Nunca lance exceção: um desenho que quebra apaga a página inteira.

### Metade H1 — `app/pagina/previas-tela.js`

| Chave | O que o par antes/depois precisa responder |
| --- | --- |
| `Cor e tela` | uma janela com a barra de título no sabor e no acento escolhidos, duas janelas lado a lado quando o encaixe está ligado, e o ponteiro desenhado no tamanho da escala |
| `Logo do sistema :: NO DOCK` | a dock com a logo na ponta, e a diferença entre a do dia e a da noite |
| `Logo do sistema :: NO TERMINAL` | o retângulo do terminal com a logo à esquerda em N colunas e o texto à direita, mostrando recuo e quebras |
| `Ícones` | quatro ícones de pasta no tema e no sabor escolhidos, com e sem a cor de marca |
| `Terminal` | uma linha de comando com o esquema de cores e a forma do cursor escolhidos |

### Metade H2 — `app/pagina/previas-sistema.js`

| Chave | O que o par antes/depois precisa responder |
| --- | --- |
| `Barra e dock :: VIDRO E RELÓGIO` | a barra com a opacidade escolhida sobre uma janela, e o relógio com e sem segundos |
| `Barra e dock :: MÚSICA NA BARRA` | a pastilha da música na largura escolhida, com capa, título e a cor vinda do álbum |
| `Papel de parede` | a tela com a imagem no ajuste escolhido (preencher, caber, esticar) e a seta do intervalo de troca |
| `Dia e noite` | um arco de 24 horas com o trecho da noite pintado, marcando início e fim |
| `Modo de leitura` | a mesma tela em duas metades: fria à esquerda, na temperatura e na textura escolhidas à direita |
| `Lançadores e jogos` | o lançador com quatro atalhos, marcando quais estão ativos |
| `Manutenção` | três engrenagens ligadas por uma linha, acesas conforme os vigias ligados |

### Conferência das duas metades

Não há navegador nesta frente. Cada metade prova o seu arquivo assim:

1. `node --check <arquivo>` passa.
2. Um roteiro curto numa pasta temporária que carrega o arquivo com um
   `document`/`SVGElement` de mentira e chama **toda** função do mapa três
   vezes: com os valores de fábrica do `meow.conf.exemplo`, com todos os valores
   vazios, e com valores inválidos. Nenhuma pode lançar exceção, e as três têm
   de devolver `svg` e `legenda`.
3. As três chamadas devolvem `antes` sempre, e `depois` quando recebem um
   valor escolhido diferente do que está em vigor.
4. `grep -nE '#[0-9a-fA-F]{3,8}'` no arquivo: vazio.
5. `grep -n 'innerHTML'` no arquivo: vazio.

Reporte a legenda que cada função produziu com os valores de fábrica — é o texto
que ela vai ler na tela, e é onde se vê se o desenho responde à pergunta certa.

---

## Correções à folha, medidas durante a rodada

Escrevi as frentes acima antes de medir. A conferência da Frente D derrubou
cinco coisas, e elas valem mais do que o texto original — quem for tocar E, F ou
G lê **isto**, não o que está escrito lá em cima.

### 1. O modo seco tem NOVE pontos no `app.js`, não seis — e três não são leitura

A folha diz "seis lugares". Medido:

| Linha | O que é |
| --- | --- |
| 395, 500, 912, 1685, 1706, 1926 | leituras — viram `ensaiando()` |
| 3026 | **escrita**: `$("#seco").checked = true` restaura do `sessionStorage` |
| 3028 | **`addEventListener("change", …)`** |
| 3030 | leitura dentro desse ouvinte |

Um `<button>` **nunca dispara `change`**, e `.checked` nele é propriedade morta.
Trocar só as seis leituras deixa o botão aceso e mata em silêncio o
"o seco sobrevive ao F5" — que dois validadores independentes já pegaram uma vez.

A Frente F precisa de **três** coisas, não uma:

- `ensaiando()` lendo `$("#seco").getAttribute("aria-pressed") === "true"`;
- um ouvinte de **`click`** que inverte o `aria-pressed` e grava no `sessionStorage`;
- a restauração escrevendo `setAttribute("aria-pressed", "true")`.

### 2. A Frente G quebra no Playwright, e o texto dela não sabe disso

`tests/app-navegador.py` chama, em `#seco`: `.check()` (696, 738), `.uncheck()`
(706) e `.is_checked()` (745) — e ainda `.check()`/`.uncheck()` pelo seletor
`.seco input[type=checkbox]` (765, 776). O Playwright recusa os cinco num
`<button>`: *"Not a checkbox or radio button"*. Viram `.click()` e
`get_attribute("aria-pressed")`, e o seletor de classe vira `#seco`.

### 3. A rota da logo é da Frente E, e a folha não a atribuiu a ninguém

Não existe URL que um HTML estático possa escrever e que alcance
`assets/icones/autorais/`: a rota estática do servidor só serve
`app/pagina/`, e a rota de prévia exigiria o caminho absoluto e o sabor já
resolvidos. O `index.html` ficou apontando para `/logo.svg`; **sem a rota, o
banner é um 404.** A Frente E ganha dois itens:

- o bloco `if caminho == "/logo.svg":`, irmão do `if caminho == "/gato.svg":`
  (~3028), servindo `assets/icones/autorais/meowsystem-painel-<sabor>.svg`. E
  `MODO="claro"` força `latte`, como `/paleta.css` já faz — senão o painel claro
  fica com a logo escura;
- `_imagens_da_amostra` (~4052) troca `mapa["/gato.svg"]` por `mapa["/logo.svg"]`,
  senão o `.html` que ela baixa em "Esta tela num arquivo" abre com a marca
  quebrada.

### 4. A logo crava mauve, e a página pode não ser mauve

Os quatro SVG autorais têm o **mauve** de cada sabor cravado no `stroke`, e
`completar_icones.sh` escolhe só pelo `FLAVOR`. Mas `/paleta.css` constrói
`var(--accent)` a partir da chave **`ACCENT`**, com `mauve` apenas de padrão. Com
`ACCENT="peach"`, a logo seria a única coisa roxa numa página pêssego.

**Decisão:** a marca do produto segue o acento escolhido, como todo o resto da
página. A rota `/logo.svg` da Frente E lê o arquivo do sabor e **substitui o
valor do `stroke` pela cor de `--accent` já resolvida** — o mesmo valor que
`/paleta.css` calcula, sem duplicar a tabela. O `gerar_icones_autorais.py` não
muda: o arquivo em disco continua sendo o ícone do `.desktop`, e o `.desktop`
não tem paleta para seguir.

### 5. Para a Frente C

O bloco amarelo do modo seco abre em `.seco:has(:checked)` na linha **180**, não
181. E `accent-color` não tem sentido num `<button>` — essa declaração morre em
vez de migrar.

### 6. O contrato do cartão, medido — é isto que a Frente F emite

A Frente C mediu e a folha errava em três nomes. O que vale:

```html
<article class="cartao" data-chave="VIDRO_OPACIDADE_DOCK">
  <h3 class="titulo-cartao">Opacidade da dock</h3>
  <button class="porque" type="button" aria-expanded="false" aria-controls="dica-7">?</button>
  <div class="dica" id="dica-7" role="tooltip" hidden>
    <p class="motivo">…o comentário inteiro, com as quebras…</p>
    <code class="chave">VIDRO_OPACIDADE_DOCK</code>
    <span class="marca-essencial" title="Chave essencial">•</span>
    <span class="fabrica">De fábrica: 0,8</span>
  </div>
  <div class="controle">…</div>
  <p class="frase">0 é transparente, 1 é opaco.</p>
</article>
```

As cinco travas, todas medidas:

1. `.dica` é o irmão **imediato** de `button.porque` — o hover é
   `button.porque:hover + .dica`.
2. Os dois são filhos **diretos** de `.cartao`.
3. O `?` sai em **todo** cartão, mesmo sem comentário: `.motivo` é opcional,
   `.chave` e `.fabrica` não.
4. O texto do `.motivo` entra cru (`white-space: pre-wrap` no CSS); manter o
   `.replace(/^# ?/gm, "").trim()`.
5. `.marca-essencial` é opcional e vem logo depois da `.chave`.

Deixam de ser desenhados: `.cartao-topo`, `.padrao`, `details.porque`, e a
pastilha `p-seco`.

**A folha errou três nomes.** A classe do título é `titulo-cartao`, não
`titulo` — o `app.js` já a escreve em três lugares. E `.cartao .chave` /
`.cartao .fabrica` nunca existiram: o que havia era `.cartao > .cartao-topo`,
`.cartao-topo code` e `.cartao .padrao`. `chave` e `fabrica` **nascem** dentro da
dica; é criação, não mudança de casa.

**O selo de essencial não cabia no contrato de três elementos** que a folha
prometia. Ele sobreviveu dentro da dica, porque "nada se perde" tinha de valer
para ele também.

Clique, `Esc`, saída, `hidden` e `aria-expanded` são do `app.js` — e o `hidden`
**cai também no foco**, senão quem usa leitor de tela não alcança a dica.

### 7. E o `app.js` tem "Dia e noite" e o número 13 cravados

Linhas 2729-2735: `GRUPOS.find(g => g.nome === "Dia e noite")` com
`title: "As 13 chaves que respondem…"`. Medido: a seção agora tem **6**, e as
outras 7 estão em "Modo de leitura". A Frente F conserta as duas coisas.

### 8. `MEOW_SECO=1` no ambiente não liga o modo seco — em script nenhum

A regra 7 desta folha está errada pela metade. Medido pela Frente B:
`lib/comum.sh:25` faz `MEOW_SECO="${MEOW_DRY_RUN:-0}"` no `source`, **sobrescrevendo
o que veio de fora** — está documentado ali, com o incidente de 24/08.

- `MEOW_SECO=1 ./scripts/cursor.sh adicionar …` → **instalou de verdade**.
- `MEOW_DRY_RUN=1 …` → não escreveu nada.

Quem for conferir modo seco em script usa **`MEOW_DRY_RUN=1`**. `MEOW_SECO` é a
variável interna, lida depois do `source`, nunca a porta de entrada.

Dois detalhes desta máquina que a folha também errou: o `find` aqui é o `bfs` e
recusa `-newermt '-3 minutes'` (use `touch <marco>` + `-newer <marco>`), e uma
conferência de seco para fontes precisa olhar **três** lugares, não um:
`~/.local/share/fonts`, `assets/fontes/locais/` e `~/.cache/fontconfig`.

### 9. Os temas de ponteiro: a tela não estava errada

"Temas do Ponteiro só aparece um" não era defeito. Medido: existe **um só**
instalado que a chave `CURSOR` sabe alcançar
(`catppuccin-mocha-light-cursors`). `Adwaita` e `Pop` têm `cursors/` dentro mas
não terminam em `-cursors`, e a regra que o painel aplica exige o sufixo. O que
faltava era **o botão de adicionar** — e ele agora existe.

---

## Frente I — a escolha dela vence a medição, no papel de parede

**Só toca `scripts/wallpaper.sh`.**

Ela pediu: *"quando eu colocar o mouse em cima da imagem temos que ter as opções
de Dia e a opção Noite, não apenas a Tirar"*.

Medido: hoje **não existe como escolher**. `_resolver_grupo` separa
`ativos-dia/` de `ativos-noite/` só pela luminância (`-colorspace Gray` +
`%[fx:mean]`, contra `WALLPAPER_LIMIAR_LUZ`, padrão 0.37). A medição está certa
na maioria dos casos e errada em alguns — uma foto clara de madrugada, um
gráfico escuro que ela quer de dia — e não há nenhuma porta para discordar dela.

**O desenho:** uma decisão escrita vence a heurística; a heurística continua
sendo o padrão. É o mesmo padrão que o projeto já usa em outros lugares —
automação age por decisão escrita, e a medição só opina quando ninguém decidiu.

- `meow wallpaper lado <arquivo> dia|noite|auto` grava a escolha.
- O registro é um arquivo de duas colunas em
  `assets/papeis-de-parede/lado.tsv` — `<nome-do-arquivo>\t<dia|noite>` —, uma
  linha por imagem, ordenado, e `auto` **apaga** a linha em vez de escrever
  `auto`. Ausente é o padrão; o arquivo só guarda discordância.
- `_resolver_grupo` consulta o registro **antes** de comparar luminância. O
  aviso de "grupo com menos de duas imagens" continua valendo depois disso.
- `meow wallpaper estado` passa a dizer quantas imagens estão em cada lado **por
  escolha** e quantas **por medição**.
- Uma imagem banida ou apagada some do registro na mesma passagem — registro que
  cresce para sempre vira lixo silencioso.
- Contrato de idempotência: escrever o lado que já valia devolve `0`.

**Conferência:** gravar `noite` numa imagem clara e conferir que ela aparece em
`ativos-noite/` depois de `aplicar`; gravar `auto` e conferir que ela volta
sozinha para `ativos-dia/`; `MEOW_DRY_RUN=1` não escreve o `.tsv`; duas
passagens seguidas devolvem `1` e depois `0`; `tests/convergencia.sh` continua
convergindo.

### 10. O contrato da prévia não fechava: a função recebe DOIS argumentos

Escrevi `(v) => ({antes, depois, legenda})` e a Frente H1 mediu o furo: **uma
função pura com uma entrada só não pode produzir `antes` diferente de
`depois`.** Do jeito que estava, `depois` seria `null` sempre, e o par que ela
pediu — *"o antes e depois talvez"* — nunca apareceria.

O contrato que vale:

```js
window.MEOW_PREVIAS["Seção :: BLOCO"](v, escolhido) -> { antes, depois, legenda }
```

- `v` = os valores **em vigor** no `meow.conf`, para as chaves do bloco.
- `escolhido` = opcional, mesmo formato, só o que ela mexeu e **ainda não
  salvou** — no painel, o `MUDANCAS` filtrado para o bloco.
- Um argumento só, ou `escolhido` igual ao que já vale, devolve `depois: null`:
  um desenho só, rotulado apenas **Como está**.

A consequência é a melhor parte: o par **reage ao clique antes do Salvar**. É o
que transforma o desenho de ilustração em resposta à pergunta "o que este botão
vai fazer com a minha tela".

### 11. Três correções menores, medidas

- **`TERMINAL_CURSOR` decide a COR do cursor** (`accent | port`), não a forma.
  Forma de cursor não existe como chave neste projeto.
- **`ESCALA_TELA` aceita `auto` além de `nitida`** — `scripts/escala.sh:226`
  trata os dois no mesmo caminho.
- **`grep -n 'innerHTML'` vazio proíbe até citar a palavra num comentário.** Uma
  frase dizendo "sem innerHTML" reprova a própria conferência.

E um limite do "sem literal hexadecimal" que só aparece ao desenhar: o
`/paleta.css` é gerado no **sabor salvo**, então `var(--base)` já é o sabor de
agora — desenhar "como ficaria no latte" com ele seria desenhar o sabor atual
com outro nome. O que salva são `--fundo-mocha` e `--fundo-latte`, publicados
fixos pelo `servidor.py`. Sem essas duas, o contrato de cor seria impossível.

### 12. Duas regras novas que as prévias impuseram

**Rasterize e olhe.** A conferência que escrevi — `node --check`, dois greps e um
roteiro com `document` de mentira — passou verde num desenho que, na tela, era
ilegível: o painel a 19% e a 80% saíam **idênticos**, porque o fundo era
`--surface0` sobre `--base` e havia uma linha fraca só atrás da barra. Nenhuma
das checagens automáticas podia pegar isso; o olho pegou em um segundo.

Então a conferência de todo desenho ganha um passo: serializar o SVG, resolver
as `var()`/`color-mix()` contra o sabor, e rasterizar com `rsvg-convert`. É
barato — sem navegador, sem tela dela — e é o único passo que responde à
pergunta que importa: *isto se entende?*

A outra metade fez o mesmo e pegou quatro defeitos que nenhum teste pegaria: um
sol de quatro raios que lia como mira de rifle, duas causas desenhadas para a
mesma troca, uma seta idêntica ao emblema de outra pasta, e dois rostos de gato
indistinguíveis no tamanho da dock.

**Todo arquivo de prévia se embrulha numa IIFE.** Dois `<script>` clássicos
dividem o escopo global: dois `const linha` no topo seriam `SyntaxError`, e o
segundo arquivo simplesmente não carregaria — em silêncio, com metade dos
desenhos faltando. As duas metades chegaram a isso por conta própria; fica
escrito antes de existir uma terceira.

### 13. Mais correções medidas

- **"vazio no meow.conf significa que o COSMIC decide" é falso para a maioria
  das chaves.** Vale só para `VIDRO_OPACIDADE_*`, `VIDRO_AO_MAXIMIZAR` e
  `RELOGIO_SEGUNDOS` — as que os Ajustes do COSMIC também escrevem. Para
  `WALLPAPER_*`, `LEITURA_*`, vigias e lançador, vazio é o padrão de fábrica.
  São duas frases, não uma.
- **`stroke-width` ~2 num viewBox de 48 não sobrevive a desenho de tela.** Tela
  é larga; o quadro dos desenhos de sistema é `0 0 100 60`, e o traço é 2 medido
  pelo **lado curto**, para casar com o peso do desenho da FORMA.
- **`parseFloat` engana:** `"25:99"` vira 25 e `"1.0.0"` vira 1 — um valor
  inválido entraria no desenho como se fosse escolha. E grampear (`-5`→0)
  desenha um extremo com cara de decisão. A linha inteira tem de ser número; fora
  da faixa, desenha o padrão e diz na legenda.
- **`AUTO_REPARO` não é o quarto vigia** — é o relógio que move os três, e
  desligá-lo não os desliga. E `STEAM_VIGIA` é o único sem par `_NOTIFICAR`: a
  ausência do sino é informação.
- **`APPS_ATIVOS` tem 23 nomes, não 22.**
- **"Papel de parede" carrega também `FILES_MENU` e `FILES_MENU_AUTOBUILD`.**
  As duas únicas chaves que não viraram desenho são `WALLPAPER_BASE` (é um
  caminho) e `FILES_MENU_AUTOBUILD` (é uma decisão de build).

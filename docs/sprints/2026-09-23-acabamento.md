# A onda de acabamento — 23/09/2026

As sprints P1 a P29 entraram em `dev`. Cada uma deixou anotado, nos riscos,
o que viu na borda do próprio território e não era dela. Esta onda recolhe
essas anotações, mais duas decisões tomadas hoje, com as medições na mesa:

- **a biblioteca Dracula** (295 SVG + 214 ligações de app) mora no
  `Dracula_OS-Theme` e só 11 desenhos chegaram ao pack (P36);
- **tudo do Spellbook que conflita com o MeowSystem migra para cá e é
  desativado lá** (P37).

A ordem: P30–P36 são independentes entre si. A P37 depende da P36 (a montagem
do tema Dracula lê do pack que a P36 completa).

Toda sprint aqui segue as regras de sempre: medir antes, `MEOW_RAIZ` apontando
para o worktree, o `sudo` falso na frente do PATH, e nenhum teste escrevendo no
sistema real.

---

# P30 — O pack que viaja não leva o nome de ninguém

**A anotação (P11, 23/09):** *"Ao exportar o dracula, o
`temas/capturados/dracula-mauve/captura.txt` vai junto, e ele carrega
`/home/andrefarias/.config/cosmic`. É metadado de procedência, e o exportar não
o filtra, mas o PACKS.md pede 'nenhum nome de usuário' em quem publica."*

### O que medi

```
git grep -n "/home/" -- packs
packs/catppuccin/temas/capturados/latte-mauve/captura.txt:3:origem: /home/vitoriamaria/.config/cosmic
packs/catppuccin/temas/capturados/mocha-mauve/captura.txt:3:origem: /home/vitoriamaria/.config/cosmic
packs/catppuccin/temas/capturados/mocha-pink/captura.txt:3:origem: /home/vitoriamaria/.config/cosmic
packs/dracula/temas/capturados/dracula-mauve/captura.txt:3:origem: /home/andrefarias/.config/cosmic
```

**Dois nomes de usuário, de duas máquinas, em quatro arquivos versionados** — e
todo `.meowpack` exportado de qualquer um dos dois packs os leva.

A causa está na origem: o `scripts/capturar_tema.sh` escreve o caminho
absoluto na linha `origem:`. Filtrar no exportar seria curar o sintoma; a
próxima captura escreveria de novo.

### O que fazer

1. **Na origem:** o `capturar_tema.sh` escreve `origem: ~/.config/cosmic`
   (com `~`), nunca o `$HOME` expandido. Confira quem LÊ a linha `origem:`
   (`grep -rn "origem:" bin scripts lib app`) e faça os leitores aceitarem o
   `~` — se algum compara com caminho absoluto, ele passa a expandir.
2. **Os quatro `captura.txt` versionados** são corrigidos para `~`. Eles são
   `byte-exact` no `.gitattributes` (as capturas são fotografia do COSMIC), mas
   o `captura.txt` é metadado escrito pelo MeowSystem, não pelo COSMIC: confira
   se o padrão do `.gitattributes` o pega e, se pegar, se isso é certo.
3. **A régua, para não voltar:** o `meow pack validar` recusa qualquer arquivo
   de texto do pack que contenha `/home/<nome>/` ou `/Users/<nome>/`, dizendo
   o arquivo e a linha. O `exportar` já recusa o que não valida — ele herda a
   régua sem código novo.
4. **Varra o resto do pack** com a mesma régua (`CREDITOS.md`,
   `PROCEDENCIA.md`, `pack.json`, mapas). O `PROCEDENCIA.md` do Dracula tem uma
   coluna "lido de" com `~/Desenvolvimento/...` — com `~`, é aceito; confira
   que nenhuma linha escapou com o caminho expandido.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `scripts/capturar_tema.sh` | a linha `origem:` com `~` |
| quem lê `origem:` (medir) | aceitar o `~` |
| `packs/*/temas/capturados/*/captura.txt` | os quatro, com `~` |
| `scripts/pack.py` | a régua no `validar` |
| `tests/pack.sh` | uma seção: pack com `/home/fulano/` é recusado; os packs do repo validam |
| `docs/PACKS.md` | a frase "nenhum nome de usuário" ganha a régua que a cobra |

### Como conferir

```sh
git grep -c "/home/" -- packs          # antes: 4 · depois: 0
meow pack exportar dracula /tmp/x.meowpack && tar --zstd -xOf /tmp/x.meowpack | grep -c "/home/"   # 0
meow pack validar catppuccin && meow pack validar dracula   # rc 0
```

### O que pode dar errado

- **O `meow desfazer` e o `aplicar_tema.sh` podem ler `origem:`** para decidir
  de onde restaurar. Trocar para `~` sem ensinar o leitor quebra a restauração
  em silêncio. Meça quem lê antes de trocar quem escreve.
- **A régua não pode pegar o `.git` nem binário.** Só texto, e só dentro do pack.

---

# P31 — O Catppuccin que sobrou na tela

**A anotação (P10, 23/09):** *"Ainda sobra vocabulário do Catppuccin fora da aba
Ícones: o «Variante do tema» (FLAVOR), em Cor e tela, lista
mocha/macchiato/frappe/latte/dracula, que é a cerca do meow.conf.exemplo, e não
oferece alucard; o balão da tira da Home diz 'na ordem do Catppuccin'; o
logo_do_painel cai para 'mocha'; o shell ainda não lê icones.mimetypes.flavor:
com o ICONES_FLAVOR=\"$FLAVOR\" de fábrica e o Dracula no ar, os ícones de
arquivo não se vestem."*

### O que medi

```
meow.conf.exemplo:585     ICONES_FLAVOR="$FLAVOR"
scripts/icones_mimetypes.sh:47   FLAVOR_ICONES="${ICONES_FLAVOR:-macchiato}"
scripts/icones_apps.sh:57        FLAVOR_ICONES="${ICONES_FLAVOR:-macchiato}"
scripts/icones_pastas.sh:61      FLAVOR_ICONES="${ICONES_FLAVOR:-macchiato}"
app/servidor.py (logo_do_painel)  cores = flavors.get(flavor) or flavors.get("mocha") or {}
app/pagina/app.js:8210           title: "A paleta desta variante, na ordem do Catppuccin"
```

Com o Dracula no ar e o conf de fábrica, `ICONES_FLAVOR` vale `dracula`, e não
existe acervo de mimetype `dracula` — o pack declara
`icones.mimetypes.flavor: "macchiato"` justamente para isso, e **o shell não o
lê**. A P10 ensinou o painel a lê-lo (o `vocabulario`); o shell ficou para trás.
É o defeito "a lista não acompanhou a irmã" que a P17 pegou duas vezes.

### O que fazer

1. **Uma regra só para o flavor dos ícones herdados**, no `pack.py`, chamada
   pelo shell e pelo painel. A ordem de quem vence está no "Quem vence" do
   `docs/PACKS.md`: o `ICONES_FLAVOR` explícito do conf vence; o de fábrica
   (`"$FLAVOR"`) que não existe no acervo herdado cai para o
   `icones.mimetypes.flavor` do pack. Os três `icones_*.sh` passam a perguntar
   à regra, e não ao `:-macchiato`.
2. **«Variante do tema»** oferece os flavors do PACK NO AR (lidos do
   `paleta.json` dele, incluindo o claro derivado, com o rótulo "derivado"),
   e não a cerca fixa do exemplo. Com o Dracula no ar: dracula e alucard.
3. **O `logo_do_painel`** cai para o `flavor_padrao` do pack no ar, e não para
   `"mocha"`.
4. **O balão da tira** diz "na ordem da paleta do pack", ou o nome do pack.
5. **Reconte a tela inteira** com o Dracula no ar, como a P10 fez na aba Ícones:
   Playwright a 1600x900, texto visível de TODAS as abas, contagem de
   `Mocha|Macchiato|Frappé|Latte|Catppuccin|cat-` antes e depois. Cada
   ocorrência que sobrar tem de ser um rótulo de herança dito ("herdado do
   Catppuccin"), nunca um vocabulário solto.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `scripts/pack.py` | a regra do flavor de ícone herdado |
| `scripts/icones_mimetypes.sh`, `icones_apps.sh`, `icones_pastas.sh` | perguntam à regra |
| `app/servidor.py` | `logo_do_painel`, a lista da «Variante do tema» |
| `app/pagina/app.js` | o balão da tira e o que a recontagem achar |
| `meow.conf.exemplo` | o comentário do `ICONES_FLAVOR` diz a regra nova |
| `tests/pack.sh` | shell e painel respondem o mesmo flavor, com o Dracula e com o Catppuccin |

### Como conferir

```sh
# com PACK=dracula, FLAVOR=dracula, ICONES_FLAVOR="$FLAVOR" (o de fábrica):
python3 scripts/pack.py <verbo da regra>        # macchiato (do pack), e não dracula
MEOW_DRY_RUN=1 ./scripts/icones_mimetypes.sh   # instalaria o macchiato
# e a recontagem da tela: nenhum vocabulário do Catppuccin solto, em nenhuma aba
```

### O que pode dar errado

- **O `ICONES_FLAVOR` explícito continua vencendo.** Quem escreveu
  `ICONES_FLAVOR="latte"` com o Dracula no ar escolheu isso; a regra nova só
  decide quando o valor é o de fábrica e não existe.

---

# P32 — O que a tela diz é o que o código faz

**As anotações (P12, 23/09):** *"(b) `origens.wallpapers.*` não tem leitor, e o
info diz PRÓPRIO; ficou documentado. (c) `icones.autorais.gerar` aparece como
campo morto, mas o `cmd_construir` o lê. (d) `instalar_fontes.sh` usa
`assets/fontes/locais`, enquanto o acervo real no git é
`assets/fontes/fonts/locais` (o git-limpo.sh registra isso)."*

### O que medi

```
scripts/instalar_fontes.sh:181   ACERVO_LOCAL="$RAIZ/assets/fontes/locais"
git ls-files assets/fontes       -> assets/fontes/fonts/locais/...
```

Três lugares em que a tela ou o aviso dizem uma coisa e o código faz outra:

1. **`meow pack info` marca os papéis de parede como PRÓPRIO**, e nenhum
   código lê `origens.wallpapers.*`. A pessoa lê "próprio" e acredita que o
   pack traz os papéis de parede dele.
2. **O aviso de campo morto acusa `icones.autorais.gerar`**, que o
   `cmd_construir` lê. O aviso mente para o outro lado: chama de morto o que
   está vivo.
3. **As fontes locais**: o script procura numa pasta e o acervo está em outra.
   Toda fonte que alguém soltou em `assets/fontes/fonts/locais/` nunca foi
   instalada.

### O que fazer

1. **Papéis de parede:** ou `origens.wallpapers` ganha leitor (o
   `wallpaper.sh` passa a semear do repositório que o pack declara), ou o
   `info` deixa de dizer PRÓPRIO e diz o que é verdade. Meça o que o
   `wallpaper.sh` faz hoje (`WALLPAPER_SEMENTE_REPO`) e escolha o que for
   menor e verdadeiro; diga no relatório por quê.
2. **O aviso de campo morto** tira `icones.autorais.gerar` da lista de mortos.
   Reconte a lista inteira: todo campo que o aviso chama de morto tem de ter
   `grep` vazio de leitor, medido.
3. **As fontes:** descubra qual das duas pastas é a certa (o histórico do git
   diz quem criou cada uma; o `git-limpo.sh` registra a divergência). Uma
   pasta só, e o script lê dela. Se mover arquivo, `git mv`.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `scripts/pack.py` | o `info` dos papéis de parede; a lista do aviso de campo morto |
| `scripts/wallpaper.sh` | só se a escolha for dar leitor ao campo |
| `scripts/instalar_fontes.sh` | a pasta certa |
| `assets/fontes/` | só `git mv`, se for preciso |
| `tests/git-limpo.sh` | a divergência registrada deixa de existir |
| `tests/pack.sh` | o info e o aviso dizem a verdade |
| `docs/PACKS.md` | a exceção registrada pela P12 sai, ou vira regra |

### Como conferir

```sh
meow pack info dracula | grep -i wallpaper     # não diz PRÓPRIO sem leitor
meow pack validar <pack com icones.autorais.gerar> 2>&1 | grep -c "gerar"   # 0 avisos
MEOW_DRY_RUN=1 ./scripts/instalar_fontes.sh    # vê as fontes do acervo versionado
```

### O que pode dar errado

- **A pasta de fontes pode ter dono fora do projeto** (o Spellbook, um
  instalador antigo). Procure quem mais escreve lá antes de mover.

---

# P33 — Os dois testes de navegador voltam a ser verdes

**As anotações (P10, 23/09):** *"app-acessibilidade.py: 1 reprovação. É o balão
da pendência do starship, './scripts/prompt.sh instalar-starship', que já
estava lá. app-navegador.py: o page.goto estoura o tempo de 30 s esperando
'networkidle'. Acontece igual no dev."*

### O que medi

- O `/usr/bin/python3` não tem Playwright; o `python3` do PATH (pyenv) tem, e o
  Chromium está em `~/.cache/ms-playwright/chromium-1228`. Por isso a suíte
  inteira os marcou como **pulados** — e pulado não é verde.
- `networkidle` espera 500 ms sem conexão de rede. Uma página que mantém uma
  conexão aberta (SSE, long-poll, um `fetch` periódico) **nunca** chega lá.

### O que fazer

1. **Rode os dois com o python que tem Playwright** e confirme as duas falhas.
2. **O balão do starship:** leia qual regra do `app-acessibilidade.py` ele
   viola e conserte o balão, não a regra. Se o balão mostra um comando cru
   (`./scripts/prompt.sh instalar-starship`), a tela está mandando a pessoa
   para o terminal — e a regra do projeto é que nenhuma pendência manda
   consertar à mão: a pendência ganha um botão que resolve.
3. **O `networkidle`:** descubra que conexão fica aberta. Se for do painel e
   legítima, o teste espera um seletor que prove a página pronta
   (`domcontentloaded` + o elemento), e não o silêncio de rede. Se for um
   vazamento (um intervalo que nunca para), conserte a página.
4. **A suíte não pula em silêncio:** o `tests/todos.sh` procura um python com
   Playwright (o do PATH) antes de declarar "pulado".

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `tests/app-acessibilidade.py`, `tests/app-navegador.py` | só o que for defeito do teste |
| `app/pagina/*.js`, `app/servidor.py` | o balão do starship; a conexão que fica aberta |
| `scripts/prompt.sh` | só se o botão da pendência precisar de um verbo |
| `tests/todos.sh` | achar o python com Playwright |

### Como conferir

```sh
./tests/todos.sh      # os dois de navegador: ok, e não pulado
```

### O que pode dar errado

- **Instalar o starship pelo painel escreve no sistema real.** O teste do botão
  roda num HOME de brinquedo, com o `sudo` falso — nunca na máquina.

---

# P34 — Os miúdos que as sprints anotaram

Cada item é pequeno e tem dono anotado. Nenhum reprova sozinho; juntos, são o
que faz o código mentir devagar.

1. **Duas cópias do algoritmo do claro** (P16): `scripts/pack.py`
   (`derivar_claro`) e o `main()` de `scripts/derivar_claro.py`. O
   `derivar_claro.py` passa a importar do `pack.py` e deixa de gravar em
   `/tmp/dracula-claro.json` (linha ~190): imprime, e quem quiser redireciona.
   O `tests/pack.sh` já prende a cópia do `pack.py` ao alucard (26 de 26);
   depois da junção, as duas portas dão o mesmo resultado.
2. **O exemplo inválido do `docs/PACKS.md`** (P11/P16): o bloco de paleta do
   topo usa o flavor `meu-tema`, com hífen, que o `validar` recusa. Todo
   exemplo do PACKS.md passa pelo `validar` — escreva um teste que extrai os
   blocos JSON da doc e os valida.
3. **`claros[0]` copiado três vezes no `servidor.py`** (P10): uma função só.
4. **O rótulo de herança** (P10): o cartão diz «herdado de catppuccin» (pelo
   id) e o «Mais sobre» diz «herdado do Catppuccin» (pelo nome). O nome, nos
   dois. E «Ver sobre Escuro» / «Ver sobre Claro», com maiúscula no meio da
   frase, viram minúscula.
5. **O importar** (P11): o erro mostra o caminho temporário do servidor, que
   não diz nada à pessoa — diga o nome do arquivo que ela escolheu; e o aviso
   "este pack herda de um pack que não vem com o MeowSystem" aparece no CLI e
   não no painel — apareça nos dois.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `scripts/derivar_claro.py`, `scripts/pack.py` | item 1 |
| `docs/PACKS.md`, `tests/pack.sh` | item 2 |
| `app/servidor.py` | itens 3 e 5 |
| `app/pagina/app.js` | itens 4 e 5 |

### Como conferir

```sh
python3 scripts/derivar_claro.py ... | diff - <(python3 scripts/pack.py de-csv ...)   # mesma régua
./tests/pack.sh     # os exemplos da doc validam
grep -c "claros\[0\]" app/servidor.py   # 1, dentro da função
```

---

# P35 — O script e o painel respondem a mesma coisa

**As anotações (P12, 23/09):** *"`cursor.sh listar` só lista diretórios
`*-cursors`, enquanto o painel lista também nomes exatos (Adwaita, Pop,
Dracula-Cursor)."* E: *"com FLAVOR=alucard e PACK vazio o painel adota dracula
e o shell adota o padrão. Essa divergência entre as duas adoções já existia e
continua existindo."*

Os dois são o defeito que a P17 pegou duas vezes e a P10 foi reprovada por
repetir: **a mesma regra escrita duas vezes, em duas línguas, e as duas
cópias divergindo.**

### O que fazer

1. **A adoção do pack** (`PACK` vazio, `FLAVOR` nomeando um flavor de algum
   pack): uma regra só, no `pack.py` (ou onde a ponte já a resolve), e o
   `meow_pack_dir` do shell e o `_pack_adotado` do painel perguntam a ela.
   Decida pelo que o `docs/PACKS.md` promete ("um FLAVOR que nomeie um pack
   existente adota esse pack") e estenda a regra ao flavor que um pack DECLARA
   (o alucard é do Dracula).
2. **A lista de ponteiros:** o `cursor.sh listar` e o `_temas_de_cursor` do
   painel listam o mesmo conjunto. Meça as duas listas nesta máquina e escolha
   a regra certa (a que a P17 fixou para a RESOLUÇÃO), aplicada à listagem.
3. **Um teste que prende as duas metades**: roda o shell e o painel no mesmo
   HOME de brinquedo e compara as respostas. Mutante: mude um lado e o teste
   cai.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `scripts/pack.py` | a regra da adoção |
| `lib/comum.sh` (`meow_pack_dir`) | pergunta à regra |
| `app/servidor.py` (`_pack_adotado`, `_temas_de_cursor`) | perguntam à regra |
| `scripts/cursor.sh` (`listar`) | a mesma lista do painel |
| `tests/pack.sh` | as duas metades comparadas |

### Como conferir

```sh
# FLAVOR=alucard, PACK vazio: shell e painel dizem dracula
# cursor.sh listar e o painel: o mesmo conjunto, na mesma ordem
```

---

# P36 — A biblioteca Dracula inteira mora no pack

**A queixa (23/09):** *"cara uma coisa que me preocupa são os svgs vc tinha
achado mais de 300 acho do tema dracula mas eles não estão no pack"* — *"isso é
uma preocupação real."*

### O que medi

```
~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual/   295 SVG
    (commit 30f826c9, 16/04/2026: "importa 295 SVGs novos e ícones de projetos pessoais")
~/Desenvolvimento/Dracula_OS-Theme/mapping.json                  214 ligações app -> desenho
    fonte: current 73 (quase todos PNG) · upstream 51 (m4thewz) · new-sessao-atual 34
           projects 16 · nomes de ícone de tema ~40

packs/dracula/ (dev)     49 SVG: icones/apps 19 · autorais 22 · pastas 7 · logo 1
dos 295 da biblioteca, no MeowSystem (por sha256): 11
```

**Onze de duzentos e noventa e cinco.** O pack Dracula parecia completo e
carregava 4% da biblioteca. As 34 ligações de app que usam a biblioteca viraram
11 no `packs/dracula/icones/apps.map`.

### As decisões de 23/09

- **Os 295 + todas as ligações que apontam para SVG** entram em
  `packs/dracula`. Os desenhos sem app ligado entram também: são a biblioteca
  de onde a pessoa escolhe depois.
- **Os ícones dos PROJETOS PESSOAIS ficam fora** (as 16 ligações de `projects`:
  Beholder, Elden Ring Tracker, Nyx, Protocolo Ouroboros…). São desta máquina,
  como o Spellbook; um pack é exportável e publicável.
- A licença é a que o `PROCEDENCIA.md` já registra para os 11: GPL-3.0, do
  `Dracula_OS-Theme`.

### O que fazer

1. **A biblioteca:** `packs/dracula/icones/biblioteca/` recebe os 295, com o
   nome de origem (`alien.svg`, `amphora.svg`…). Os 11 que já estão em
   `icones/apps/` com nome de app continuam lá; confira por sha256 que são
   cópias literais e registre a correspondência.
2. **As ligações:** para cada entrada do `mapping.json` cuja `fonte` seja SVG
   (`new-sessao-atual/*.svg`, `upstream/*.svg`, `current/*.svg`) e que não seja
   de `projects`, uma linha no `packs/dracula/icones/apps.map` — no formato que
   o mapa já usa (leia o cabeçalho dele e o `apps-dracula` que a P28 tornou
   fonte única). As que apontam para PNG ficam fora, contadas no relatório.
   As que apontam para nome de ícone de tema (`applications-system-symbolic`,
   `pop-support`…) não são desenho: meça o que o Dracula_OS-Theme faz com elas
   e diga.
3. **O upstream (m4thewz/dracula-icons, 51 ligações):** é arte de terceiro. A
   P28 fixou a regra: arte de terceiro entra com procedência e licença no
   `PROCEDENCIA.md`, ou não entra. Copie só os SVG que uma ligação usa (não o
   upstream inteiro, que tem 25 mil arquivos), cada um com a sua linha.
4. **`PROCEDENCIA.md`:** uma linha por arquivo novo — de onde, lido de (com
   `~`, nunca `/home/<nome>`; ver P30), licença, data, sha256. Gere a tabela
   por script, não à mão.
5. **O `meow pack info dracula`** passa a contar a biblioteca: "N apps, M na
   biblioteca sem app ligado".
6. **O `meow pack validar dracula`** continua rc 0, e o `exportar` continua
   cabendo no teto que a P11 mediu — meça o tamanho do `.meowpack` antes e
   depois e diga.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `packs/dracula/icones/biblioteca/` | **novo** — os 295 |
| `packs/dracula/icones/apps/` | os desenhos que as ligações novas usam |
| `packs/dracula/icones/apps.map` | as ligações novas |
| `packs/dracula/PROCEDENCIA.md` | uma linha por arquivo novo |
| `scripts/pack.py` | a contagem do `info`; o `validar` conhece `biblioteca/` |
| `tests/pack.sh` | conta contra o Dracula_OS-Theme por sha256, se ele existir; pula dizendo por quê, se não |
| `docs/PACKS.md` | a seção do acervo ganha a biblioteca |

### Como conferir

```sh
ls packs/dracula/icones/biblioteca/*.svg | wc -l          # 295
# por sha256, os 295 do Dracula_OS-Theme estão no pack: 295 de 295
grep -vc '^#' packs/dracula/icones/apps.map               # antes 19 · depois: o que o relatório contar
meow pack validar dracula                                  # rc 0
git grep -c "/home/" -- packs/dracula                      # 0
```

### O que pode dar errado

- **295 arquivos num commit.** Commit só da cópia, sem mais nada dentro.
- **Nome de app que já tem desenho.** Se o `apps.map` já liga um app a um
  desenho, a ligação do `mapping.json` NÃO o substitui sem a pessoa ver:
  liste os conflitos no relatório, e a escolha fica com quem mantém o projeto.
- **O Dracula_OS-Theme não existe na máquina de outra pessoa.** Nada do
  MeowSystem pode LER de lá em tempo de execução — ele é só a origem da cópia.

---

# P37 — O Spellbook para de brigar com o MeowSystem

**A regra (23/09):** *"tudo do spellbook que entrar em conflito com o
meowsystem. migramos pra cá e desativamos no spellbook, pra evitar conflito."*
E antes (21/09): *"O Spellbook é do meu PC. Exclusivo pra ele. Tudo que for
relacionado a tema é pra ser do MeowSystem."*

**Depende da P36:** a montagem do tema Dracula passa a ler do pack que a P36
completa.

### O que medi

- O Spellbook é o repositório `~/.config/zsh` (último commit `d2d3868`).
- `functions/sistema.zsh` tem o `rebuild_dracula_theme()`, que monta o tema
  `Dracula-Icones` (3.400 ícones em `/usr/share/icons/Dracula-Icones`, e 1.778
  em `~/.local/share/icons/Dracula-Icones`) a partir do `Dracula_OS-Theme`.
- `functions/sistema.zsh` e `functions/restaurar.zsh` casam com
  `gsettings set .*(icon-theme|cursor-theme|gtk-theme)`, com
  `.local/share/icons`, com `backgrounds` ou com `CosmicTheme`.

### O que fazer

1. **O inventário, primeiro, e ele é o entregável principal:** cada função,
   alias, timer, hook ou script do Spellbook que ESCREVE algo que o MeowSystem
   gerencia (tema de ícone, cursor, GTK, COSMIC, papel de parede, som, fontes,
   `~/.local/share/icons`, `~/.config/cosmic`, gsettings de aparência). Uma
   tabela: o quê, onde, o que escreve, qual etapa do MeowSystem escreve o
   mesmo, e o destino (migrar / desativar / fica — é só do PC).
2. **Migrar:** o que o MeowSystem ainda não faz passa a morar nele, lendo do
   pack (a montagem do Dracula-Icones lê de `packs/dracula`, nunca do
   `Dracula_OS-Theme`).
3. **Desativar no Spellbook:** a função não é apagada em silêncio — vira um
   aviso curto que aponta para o `meow` equivalente e sai sem escrever nada.
   Os completions (`completions/_rebuild_dracula_theme`) e a doc dela
   acompanham. O commit no Spellbook é separado, no repositório dele, e segue
   as regras de commit de lá.
4. **O que é só do PC fica:** projetos pessoais, atalhos, o que o MeowSystem
   não gerencia. Na dúvida, fica — e vai para o relatório como pergunta.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `~/.config/zsh/functions/sistema.zsh`, `restaurar.zsh` e o que o inventário achar | desativar, com aviso |
| `~/.config/zsh/completions/`, `docs/` | acompanham |
| MeowSystem: o script/etapa que recebe o que migrar | a lógica, lendo do pack |
| `tests/` | nada do MeowSystem lê do `Dracula_OS-Theme` em execução |

### Como conferir

```sh
rebuild_dracula_theme       # imprime o aviso apontando para o meow, e sai sem escrever
grep -rn "Dracula_OS-Theme" bin scripts lib app install.sh   # nenhum leitor em execução
meow doctor                 # nada divergente por causa da migração
```

### O que pode dar errado

- **O Spellbook roda no login.** Uma função desativada que ainda é chamada por
  um hook de inicialização tem de sair em silêncio e rápido — sem aviso a cada
  terminal aberto. Meça quem a chama.
- **`/usr/share/icons/Dracula-Icones` é do root e foi escrito pelo Spellbook.**
  Não apague: o MeowSystem passa a escrever o dele onde a arquitetura dele
  escreve, e o antigo vira órfão registrado no relatório, com o comando para
  removê-lo, que a pessoa roda se quiser.

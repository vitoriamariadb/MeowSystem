# Leva de 21/09/2026, eixo I — de "aplicar o Catppuccin" a produto de theme packs

Dezesseis sprints, medidas no app **rodando** em 21/09/2026 com Playwright
(janela 1600×900, `./app/run.sh --sem-abrir`, as 14 abas percorridas uma a
uma) e no código. **Nada aqui foi executado** — é spec, não mudança.

> **Este arquivo tem um irmão.**
> [`2026-09-21-packs-modulares.md`](2026-09-21-packs-modulares.md) traz o
> **eixo II** — P13 a P16 e P18 —, que reordena a árvore do projeto para que um
> tema caiba dentro de um pack. **P10, P11 e P12 deste arquivo dependem dele**:
> não se exporta um pack enquanto o conteúdo do pack mora em `assets/`.

> **Ele, 21/09/2026:**
> *"o programa original foi feito não pensando em um produto mas em aplicar o
> tema catppuccin. porém eu quero transformar em produto pra ser usado por
> qualquer um e de forma que qualquer um possa criar um theme pack completo,
> com cursor, temas de ícones, geradores de ícone, faixa de cores, som e todo
> o resto das features."*
>
> *"imagina que é um leigo, um designer, que tá usando. esse app não tá nenhum
> pouco acessível."*
>
> *"nenhuma feature do MeowSystem pode ter esse tipo de problema, temos que
> corrigir essa falha de produto na origem."*
>
> *"nada da interface é aplicado em sandbox. Tudo é aplicado na máquina da
> pessoa."*

**Por que não uso letra nesta leva:** o alfabeto já colidiu. Existem duas
Sprints T (a de 25/08, "a regra da atenção", e a de 09/09, "a fidelidade do
traço") e duas Sprints Q, R e S. A leva usa **P1 a P18** — P de produto —
repartida em dois arquivos, e cada uma carrega a data no nome, para nunca mais
haver dúvida sobre qual é qual.

---

## Sumário

| # | sprint | classe | esforço |
|---|---|---|---|
| **P1** | O instalador converge sozinho | falha de origem | 1 dia |
| **P2** | Nenhuma etapa termina em "faça você mesmo" | falha de origem | 3 dias |
| **P3** | A mensagem nunca mente | falha de origem | 1 dia |
| **P4** | O deslizante nasce livre, e os dois botões | interface | 1 dia |
| **P5** | A gaveta cabe em 25% e não encosta no menu | interface | 3 h |
| **P6** | Alvo de clique e balão | interface | 2 dias |
| **P7** | A tela fala português de gente | interface | 2 dias |
| **P8** | Ver antes de aplicar — o ensaio volta | confiança | 2 dias |
| **P9** | Uma senha só, e ela é a do install | confiança | 1 dia |
| **P10** | O pack é o centro, e o Catppuccin é só um deles | produto | 3 dias |
| **P11** | Exportar e importar um theme pack | produto | 3 dias |
| **P12** | O pack cobre o resto: ponteiro, som, gerador, fontes | produto | 4 dias |
| **P17** | A prévia do ponteiro, e a irmã que não acompanhou | interface | 2 h |
| **P22** | O primeiro comando do README não roda | falha de origem | 1 dia |
| **P23** | A suíte está vermelha há três dias e nada a roda | falha de origem | 2 dias |
| **P24** | A primeira instalação num estranho | falha de origem | 4 dias |

---

## O dossiê: os números desta máquina, em 21/09/2026

Colhidos com o app no ar, percorrendo as 14 abas. É o antes de que cada
sprint cobra o depois.

| medida | valor | onde dói |
|---|---|---|
| botões na página inteira | 731 | — |
| **deslizantes que nascem travados** | **17 de 25 (68%)** | P4 |
| botões "Usar número" | 17 | P4 |
| botões "Deixar como está" | 31 | P4 |
| **alvos de clique abaixo de 24×24 px** | **169** (119 só em Papel de parede, a 38×22) | P6 |
| **balões (`title`) com mais de 60 caracteres** | **306** (o maior: 154) | P6 |
| balões com um comando `meow` cru dentro | 119 | P6 |
| **botões cujo nome acessível passa de 40 caracteres** | **56** (o pior: 144, para um botão "Sim") | P7 |
| caminhos `/home/andrefarias/...` visíveis na tela | 43 | P7 |
| parágrafos com mais de 220 caracteres | 122 | P7 |
| **altura da gaveta de saída** | **414 px = 46% da tela** | P5 |
| **altura do menu lateral com a gaveta aberta** | **cai de 842 px para 428 px** | P5 |
| vocabulário do Catppuccin na aba Ícones com o pack Dracula no ar | `Mocha` x2, `Macchiato`, `Frappé`, `Latte` x2, `${FLAVOR}` x2, `${ACCENT}` x2, `cat-` x2 | P10 |
| verbos de `meow pack` | 4 (`listar`, `validar`, `info`, `raizes`) — nenhum escreve | P11 |
| modo de ensaio na interface | **não existe** (removido em 13/09, `app/pagina/app.js:4006`) | P8 |

Por aba, o que mais pesa:

| aba | botões | travados/sliders | alvos <24px | balões >60 | nome poluído |
|---|---|---|---|---|---|
| Papel de parede | 160 | — | **119** | **155** | 4 |
| Painel e dock | 165 | **11/12** | 12 | 37 | 12 |
| Logo do sistema | 91 | 1/4 | 4 | 37 | 4 |
| Ícones | 73 | — | 0 | 27 | 4 |
| Manutenção | 49 | **3/3** | 3 | 8 | **12** |
| Lançadores e jogos | 43 | — | 25 | 5 | 4 |
| Dia e noite | 17 | 2/3 | 3 | 7 | 2 |

---

## A classe de falha que atravessa a leva

Ele não reclamou de dezoito coisas. Reclamou de **uma**, dezoito vezes:

> **O app descobre o problema, sabe o conserto, e manda a pessoa consertar.**

As seis provas, colhidas no log da própria máquina dele:

1. `scripts/areas.sh:1001` — *"não há área alfinetada ... alfinete uma área
   pelo COSMIC (visão geral, botão direito) e rode de novo"*.
2. `install.sh:2930` — *"4 etapa(s) mudaram nesta passagem. ... Rode mais uma
   vez, até a tela dizer «nenhuma etapa precisou escrever nada»"*.
3. `assets/temas-de-apps/spotify/manifesto.sh:463` — *"instale: git clone
   --depth 1 https://github.com/catppuccin/spicetify /tmp/cat-spice && ..."*.
4. `scripts/terminal.sh` (o bloco do starship) — *"instalar é decisão sua. Sem
   sudo, em ~/.local/bin: curl -sS https://starship.rs/install.sh | sh ..."*.
5. `assets/temas-de-apps/qbittorrent/manifesto.sh` — *"sem
   ~/.config/zsh/scripts/aurora-qbittorrent-config.sh não há quem escreva o
   qBittorrent.conf"* — delega a um script que **não é deste projeto**.
6. `scripts/fastfetch_logo.sh` — *"o gato vai sair 68% fora da proporção da
   célula (esticado) ... para o desenho redondo: deixe FASTFETCH_LOGO_LINHAS
   vazio, ou use 37 linhas para 95 colunas"*.

Todas as seis têm a mesma forma: **diagnóstico certo, conserto conhecido,
nenhum botão.** Um engenheiro lê isso como cortesia; um designer leigo lê como
"o programa desistiu".

**A regra que esta leva instala, e que vale para toda feature futura:**

> Uma etapa que sabe o conserto ou **faz**, ou oferece **um botão que faz**.
> Mandar a pessoa rodar um comando é o último recurso, e exige que o comando
> esteja num botão "Copiar" — nunca solto no meio de um parágrafo.
>
> Quando nem o botão é possível (depende de decisão humana genuína: qual
> repositório é seu, qual tema você prefere), a mensagem diz **a decisão**, não
> a receita — e a decisão aparece na tela como uma escolha, não no log.

P2 é essa regra virando código; P1 e P3 são os dois casos que doem mais.

---

# P1 — O instalador converge sozinho

**A queixa:** *"4 etapa(s) mudaram nesta passagem. ... Rode mais uma vez ...
isso é uma falha claríssima de produto."*

### O que medi

`install.sh:2925-2936`. O instalador termina, conta quantas etapas escreveram,
e **pede que a pessoa rode de novo**. O comentário acima do bloco admite que o
README já diz que numa máquina nova são **três passagens** até o silêncio, e
trata isso como algo que "quem tem de saber é o instalador, não quem leu o
parágrafo 4". Está certo no diagnóstico e errado na conclusão: se quem tem de
saber é o instalador, o instalador é quem tem de rodar de novo.

A dependência é real — `index.theme` descreve os diretórios que **existem**, e
as pastas coloridas nascem na etapa seguinte. Não é bug: é ordem de construção.
O bug é terceirizar o laço.

### O que fazer

1. `main()` passa a rodar as etapas **em laço**, até `${#FEITOS[@]} -eq 0`.
2. **Teto de 5 passagens.** Acima disso, para e diz o que ainda muda — porque
   uma etapa que escreve toda passagem é um defeito de idempotência, e
   escondê-lo num laço infinito é pior que a frase de hoje.
3. **Detector de oscilação:** se a mesma etapa aparece em `FEITOS` em duas
   passagens seguidas e o conteúdo que ela escreve não muda, é oscilação —
   para, nomeia a etapa e manda para `meow doctor`.
4. A tela passa a mostrar `passagem 2 de até 5 · 4 etapas ainda mudam`, e no
   fim **uma** frase: `Pronto. 3 passagens, 58 etapas, nada mais a escrever.`
5. `--uma-passagem` preserva o comportamento de hoje, para o timer e para
   depuração. O `systemd` e o `meow doctor --consertar` usam essa flag.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `install.sh` | `main()` vira laço; o bloco `2925-2936` é substituído; `--uma-passagem` entra no `case` das opções e no `--help` |
| `systemd/*.service` | o serviço passa a chamar `--uma-passagem` |
| `tests/instalacao.sh` | a conferência nova (abaixo) |
| `README.md` | o parágrafo 4 perde a frase das três passagens |

### Como conferir

```sh
# numa máquina já pronta: uma passagem, zero escritas
./install.sh | tail -3          # espera: "Pronto. 1 passagem, ... nada mais a escrever."

# forçando a cadeia: apaga o index.theme e roda
rm ~/.local/share/icons/MeowSystem-Icons/index.theme
./install.sh | grep -c 'passagem'   # espera: 2 ou mais, e termina em "Pronto."
```

### O que pode dar errado

- **Uma etapa não idempotente vira laço de 5.** É o cenário que o teto existe
  para expor. Se acontecer, a etapa está errada — e hoje isso está escondido
  atrás de "rode mais uma vez", que a pessoa roda e desiste.
- **Tempo total.** Três passagens de 58 etapas numa máquina fria. A tela precisa
  dizer em qual passagem está, ou o silêncio vira travamento aparente.

---

# P2 — Nenhuma etapa termina em "faça você mesmo"

**A queixa:** *"nenhuma feature do MeowSystem pode ter esse tipo de problema,
temos que corrigir essa falha de produto na origem."*

### O que medi

As seis mensagens listadas na seção "A classe de falha". Todas usam
`meow_info` ou `meow_aviso` para carregar uma **receita de terminal** que o
projeto sabe executar.

### O que fazer

1. **Um verbo novo em `lib/comum.sh`: `meow_pendencia_acionavel`.**
   Assinatura: `meow_pendencia_acionavel <id> "<o que falta, em uma linha>" "<o comando que resolve>"`.
   Ele escreve a linha no log **e** registra a pendência em
   `$MEOW_ESTADO/pendencias.tsv` (`id`, `etapa`, `frase`, `comando`, `iso8601`).
2. **Uma rota nova no painel: `/api/pendencias`**, que lê esse TSV.
3. **Na tela:** a Home ganha um bloco **"3 coisas esperam um clique"** acima de
   "Nada esperando", com uma linha por pendência e um botão **Resolver**, que
   roda o comando registrado na gaveta de saída. Sem pendência, o bloco não
   aparece — não vira caixa vazia.
4. **As seis mensagens migram**, nesta ordem de valor:
   - `areas.sh:1001` passa a chamar
     `meow_pendencia_acionavel areas-sem-alfinete "Nenhuma área de trabalho está fixada; sem isso não sei em que monitor escrever" "meow areas alfinetar-primeira"`.
     E nasce o subcomando `areas.sh alfinetar-primeira`, que **cria** o primeiro
     alfinete no monitor em uso — derivado do estado real do `cosmic-comp`,
     nunca de uma lista de nomes.
   - `spotify/manifesto.sh:463` vira a pendência `spicetify-tema-ausente`, e o
     comando é uma função do próprio projeto que baixa o tema para
     `~/.config/spicetify/Themes/` — repositório público fixado por tag, a mesma
     disciplina que o pack já usa para cursores.
   - `terminal.sh` (starship) vira a pendência `starship-ausente`. O comando
     instala em `~/.local/bin`, sem sudo. **A tela pergunta uma vez**; a recusa
     fica gravada e não volta a perguntar.
   - `qbittorrent/manifesto.sh` (Aurora): **este sai de vez.** Um módulo deste
     projeto não pode depender de um script de outro projeto do autor. Ou o
     `qBittorrent.conf` é escrito aqui, ou a etapa declara honestamente que só
     instala o tema e que o `.conf` não é escopo dela — sem citar o Aurora.
   - `fastfetch_logo.sh`: a proporção **é calculada**, não sugerida. Se o gato
     sai 68% fora, o script ajusta as linhas e diz o que ajustou.
   - `compositor_patches.sh`: a linha `auto-build DISPARADO em background` vira
     pendência com estado visível (`construindo`, `pronto`, `falhou`), porque
     hoje ela dispara e some.
5. **A regra entra no `docs/FRONTEIRA.md`** como fronteira nova, e ganha teste.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `lib/comum.sh` | `meow_pendencia_acionavel`, e o TSV |
| `scripts/areas.sh` | `alfinetar-primeira`; a linha 1001 migra |
| `assets/temas-de-apps/spotify/manifesto.sh` | a linha 463 migra; a função que baixa o tema |
| `scripts/terminal.sh` | o bloco do starship migra |
| `assets/temas-de-apps/qbittorrent/manifesto.sh` | o Aurora sai |
| `scripts/fastfetch_logo.sh` | a proporção passa a ser calculada |
| `scripts/compositor_patches.sh` | o auto-build ganha estado |
| `app/servidor.py` | `/api/pendencias` |
| `app/pagina/app.js` | o bloco na Home |
| `docs/FRONTEIRA.md` | a fronteira nova |
| `tests/sem-receita-no-log.sh` | **novo** (abaixo) |

### Como conferir

```sh
# o teste que cobra a regra: nenhuma mensagem de log carrega receita de terminal
./tests/sem-receita-no-log.sh
# ele falha se achar, em scripts/ lib/ assets/temas-de-apps/,
# uma linha meow_info ou meow_aviso contendo  "curl | sh"  ou  "git clone"  ou
# "apt install"  que não esteja registrada como pendência acionável.

# e a prova de ponta a ponta, na máquina dele:
meow areas aplicar          # antes: "alfinete uma área e rode de novo"
                            # depois: alfineta a primeira e segue
```

### O que pode dar errado

- **Nem toda receita deve virar botão.** `WALLPAPER_DRACULA_REPO` nomeia a conta
  de alguém: isso é decisão, não conserto. O teste precisa de uma lista de
  isenção explícita, e cada isenção carrega o motivo na mesma linha.
- **Baixar da internet sem pedir.** Todo comando de pendência que baixe algo
  herda o rótulo `BAIXA DA INTERNET` que os cartões de ação já usam.

---

# P3 — A mensagem nunca mente

**A queixa:** *"isso é falha de app, temos esse mesmo app aqui e não foi
aplicado."*

### O que medi

Na máquina dele, agora:

```
flatpak list --app | grep -i spotify
Spotify   com.spotify.Client   1.2.95.453.g0eeebbed   stable   user
```

O Spotify **está** instalado, como flatpak de usuário, que é exatamente o que o
módulo procura. E o log diz:

```
--   Spotify não instalado (ou não é o flatpak de usuário)
```

A causa: `assets/temas-de-apps/spotify/manifesto.sh:461-465` descobre a verdade
(*"o tema catppuccin não está em ~/.config/spicetify/Themes/catppuccin"*) e
devolve `MEOW_SEM_DEPENDENCIA`. Aí `meow_app_aplicar` (linha 555) recebe só o
código de saída, perde o motivo, e imprime **a frase errada** — a primeira de
uma lista de causas possíveis.

Não é um caso isolado: o mesmo desenho existe em `zapzap:232`, `vscode:732` e
`obsidian:423`. É um contrato ruim — `detectar` sabe a causa, `aplicar` chuta.

### O que fazer

1. `meow_app_detectar` passa a gravar a causa em `MEOW_APP_MOTIVO` antes de
   devolver `SEM_DEPENDENCIA`.
2. `meow_app_aplicar` imprime `$MEOW_APP_MOTIVO`. Motivo vazio é **erro de
   programação do módulo**, não um caso a cobrir com frase genérica: o log diz
   `sem motivo declarado — defeito no módulo <nome>` e o teste falha.
3. Os quatro módulos migram.
4. Cada causa que tem conserto vira pendência de P2. "O tema do spicetify não
   está instalado" tem conserto; "o Spotify não está instalado" não tem.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `assets/temas-de-apps/spotify/manifesto.sh` | `MEOW_APP_MOTIVO` |
| `assets/temas-de-apps/zapzap/manifesto.sh` | idem |
| `assets/temas-de-apps/vscode/manifesto.sh` | idem |
| `assets/temas-de-apps/obsidian/manifesto.sh` | idem |
| `lib/comum.sh` | o contrato, e a guarda do motivo vazio |
| `tests/reversao.sh` | a conferência do contrato |

### Como conferir

```sh
# na máquina dele, hoje, sem mudar nada no sistema:
./install.sh --uma-passagem 2>&1 | grep -i spotify
# antes:  "-- Spotify não instalado (ou não é o flatpak de usuário)"
# depois: "-- Spotify: falta o tema catppuccin do spicetify — há um botão para isto"
```

### O que pode dar errado

- Um módulo com vários `return SEM_DEPENDENCIA` precisa escrever o motivo em
  **cada** um. É a razão de o motivo vazio quebrar o teste em vez de virar
  silêncio.

---

# P4 — O deslizante nasce livre, e os dois botões

**A queixa:** *"em qualquer canto que eu precise apertar em «usar número» pra
poder usar o slicer, tá errado. ele tem que tá liberado por default."*
E: *"deixar como está induz ao erro. vc muda o slicer e quer que fique como
está. clica e ele reseta. Deixa dois botões: «Restaurar ao Padrão» e «Aplicar»
(que vai aplicar e salvar). o app tá extremamente confuso."*

### O que medi

**17 dos 25 deslizantes da página nascem `disabled`** — 11 deles só na aba
Painel e dock. Ao lado de cada um, um botão "Usar número" cuja única função é
destravar. E 31 botões "Deixar como está".

O mecanismo está em `app/pagina/app.js:1022-1078`. Vazio ("não toca, quem
decide é o COSMIC") é o terceiro estado do deslizante. Para representá-lo, o
código **trava a alça** e acrescenta um botão para destravar.

A armadilha que ele descreve é exata: **"Deixar como está" lê como "mantenha o
valor que eu acabei de escolher"** e significa o oposto — `aplica("")`, que
devolve a decisão ao COSMIC e reseta a alça. O rótulo promete preservar e
executa descartar.

### O que fazer

1. **O deslizante nunca nasce travado.** `disabled` sai. Vazio passa a ser
   desenhado, não travado: a alça fica no valor que a máquina tem hoje
   (`valendo_agora`, que o servidor já entrega), com a trilha em traço e a
   legenda `como está: 24`. Mexer nela é o gesto que escolhe — não é preciso
   pedir licença antes.
2. **"Usar número" some** (os 17). O gesto que ele substituía agora é o gesto
   natural: arrastar.
3. **"Deixar como está" vira "Restaurar ao padrão"** nos 31 lugares, e passa a
   dizer o que restaura: `Restaurar ao padrão (24)`. O balão explica em uma
   linha: *"Devolve a decisão ao COSMIC."*
4. **Cada cartão com escolha pendente ganha "Aplicar".** Aplicar é gravar no
   `meow.conf` **e** rodar a etapa daquela chave — o que hoje só existe como
   "Salvar e aplicar" global, no alto, para tudo de uma vez. O botão só aparece
   quando aquele cartão tem escolha pendente, e some ao ser usado.
5. O modelo continua o de hoje (clicar guarda, salvar grava), mas **deixa de
   ser invisível**: um cartão com pendência ganha a borda de acento e o
   "Aplicar". Ninguém mais precisa descobrir a regra lendo a frase da Home.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `app/pagina/app.js` | bloco `1022-1078` (a faixa numérica), `rotuloVazio`, `botaoVazio` |
| `app/pagina/estilo.css` | `.faixa`, `.faixa-estados`, o estado "como está" em traço, a borda do cartão pendente |
| `tests/app-navegador.py` | seção nova |

### Como conferir

```js
// com o app no ar, no console — a conferência é um número:
[...document.querySelectorAll('#principal input[type=range]')].filter(s=>s.disabled).length
// antes: 11 (aba Painel e dock) · depois: 0, em todas as 14 abas

[...document.querySelectorAll('#principal button')].filter(b=>/Usar n.mero/.test(b.textContent)).length
// antes: 11 · depois: 0
```

E o gesto dele, ponta a ponta, na aba Painel e dock: arrastar "Espaço entre
ícones — dock" para 8, ver o cartão acender, clicar **Aplicar**, ver a dock
mudar. Sem passar por "Usar número" e sem que nada resete.

### O que pode dar errado

- **O terceiro estado precisa continuar visível.** Um deslizante livre que
  mostra 24 e um que *escolheu* 24 são coisas diferentes, e o COSMIC se comporta
  de forma diferente nos dois. A trilha em traço mais a palavra "como está" são
  o que os separa; se isso ficar sutil demais, o problema só muda de lugar.
- **"Aplicar" por cartão roda uma etapa sozinha.** Algumas etapas dependem de
  outras (é o assunto de P1). O botão precisa saber rodar a cadeia daquela
  chave, ou dizer que a aplicação completa é a do alto.

---

# P5 — A gaveta cabe em 25% e não encosta no menu

**A queixa:** *"a tela do terminal, quando clicamos em aplicar ou salvar, toma
até a tela do menu e cresce mais verticalmente — ocupa quase metade
verticalmente da tela, ao invés de ser no máximo 25% (não afetando o menu
lateral)."*

### O que medi

Com a gaveta aberta, janela de 901 px:

| medida | hoje | alvo |
|---|---|---|
| altura da gaveta | **414 px (46%)** | 225 px ou menos (25%) |
| altura do menu lateral | **428 px** (era 842) | 842 px, sempre |

A causa é estrutural, não de número: `app/pagina/index.html:181` põe
`<section class="gaveta">` como **irmã de `.corpo`**, direto no `<body>`. O
`.corpo` é quem contém o menu (`#trilho`) e o conteúdo (`#principal`). Uma
irmã que cresce rouba altura dos dois — por isso o menu encolhe pela metade.
`estilo.css:1370` só agrava, com `max-height: 46vh`.

### O que fazer

1. **A gaveta muda de pai:** passa para dentro de `#principal`, como última
   filha. O `#trilho` deixa de ser afetado por construção, não por CSS.
2. `max-height: 25vh`, com `min-height: 120px` para que o cabeçalho (título,
   comando, pastilha de estado, Parar, Fechar) nunca seja comprimido.
3. **A pessoa pode crescer a gaveta** arrastando a borda de cima
   (`resize: vertical` no contêiner, teto de 60vh). O padrão volta a 25% na
   próxima abertura — o arrasto é para o momento, não é preferência gravada.
4. Quando a saída passa do que cabe, o `#saida` rola sozinho para o fim, como já
   faz — e ganha um `mais 40 linhas abaixo` clicável quando a pessoa rolou para
   cima no meio de um trabalho correndo.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `app/pagina/index.html` | a `<section class="gaveta">` muda de lugar |
| `app/pagina/estilo.css` | `.gaveta` (linha 1368): `max-height`, `min-height`, `resize` |
| `app/pagina/app.js` | o indicador de "abaixo" |
| `tests/app-navegador.py` | a conferência numérica |

### Como conferir

```js
// gaveta aberta, no console:
const g = document.getElementById('gaveta').getBoundingClientRect();
const t = document.getElementById('trilho').getBoundingClientRect();
[Math.round(g.height/innerHeight*100), Math.round(t.height)]
// antes: [46, 428] · depois: [25, 842]
```

### O que pode dar errado

- Dentro do `#principal`, a gaveta compete com a rolagem do conteúdo. Ela
  precisa ser `position: sticky; bottom: 0`, ou o conteúdo passa por baixo dela.

---

# P6 — Alvo de clique e balão

**A queixa:** *"aqui outra falha: botão impossível de clicar devido à largura da
imagem."*

### O que medi

Na aba Papel de parede, cada imagem tem quatro botões — **Usar, Dia, Noite,
Tirar** — de **38x22, 32x22, 42x22 e 38x22 px**. São **119 alvos abaixo de
24 px de altura** só nessa aba; **169 na página inteira**.

E o que os cobre não é a imagem: é **o balão do próprio botão**. O `title` do
"Noite" tem 154 caracteres:

> *"Ela passa a girar só de noite, mesmo que a medição a ache clara. (meow
> wallpaper lado drac-illustrations-trees-and-mountains-night.png noite)"*

O balão nativo do navegador tem a largura do texto — perto de 600 px — nasce
sob o cursor e cobre os três botões vizinhos, que têm 22 px. Na página inteira
são **306 balões acima de 60 caracteres**, e **119 deles carregam um comando
`meow` cru dentro dos parênteses**.

O mesmo acontece na aba Painel e dock, onde o balão *"Quem decide passa a ser o
COSMIC, ou você pelos Ajustes dele."* cobre o botão do cartão ao lado.

### O que fazer

1. **Piso de 24x24 px** para todo alvo de clique (WCAG 2.2, critério 2.5.8).
   `.btn-mini` passa a ter `min-height: 24px` e `padding` que o sustente. Onde
   isso apertar a grade, a grade ganha coluna — não o botão perde altura.
2. **O balão nativo sai.** Entra um balão próprio (`role="tooltip"`), com:
   - **limite duro de 80 caracteres** — o teste falha acima disso;
   - largura máxima de 28rem, posicionado **fora** da fileira de botões
     (acima do cartão, nunca sobre os irmãos);
   - atraso de 400 ms, e some no `Escape`.
3. **O comando sai do balão.** Os 119 `(meow wallpaper ...)` viram um botão
   **"ver comando"** por cartão, que abre uma linha com o comando e um
   **Copiar**. Quem quer o comando continua tendo; quem não quer para de
   esbarrar nele.
4. Os quatro botões do cartão de imagem passam a aparecer **no hover e no
   foco** sobre a imagem (hoje ocupam uma fileira permanente de 22 px sob ela),
   com 28 px de altura e fundo escuro — a imagem ganha o espaço, e o alvo
   dobra.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `app/pagina/estilo.css` | `.btn-mini`, `.acoes`, o balão novo |
| `app/pagina/app.js` | `elemento(..., {title})` deixa de emitir `title` nativo e passa pelo balão; o "ver comando" |
| `app/servidor.py` | as ajudas com mais de 80 caracteres encurtam na fonte |
| `tests/app-acessibilidade.py` | **novo** — o teste dos três números |

### Como conferir

O teste novo roda o app e falha se qualquer um passar:

```
alvos com menos de 24 px ................. 0   (hoje: 169)
balões com mais de 80 caracteres ......... 0   (hoje: 306 acima de 60)
balões com comando meow dentro ........... 0   (hoje: 119)
```

### O que pode dar errado

- **Balão próprio precisa funcionar no teclado.** O `title` nativo, por pior que
  seja, aparece no foco. O substituto tem de aparecer em `:focus-visible`, ou a
  troca piora a acessibilidade em vez de melhorar.
- 91 papéis de parede com quatro botões de 28 px cada mudam a altura da grade.
  Vale medir a página antes de decidir entre "aparece no hover" e "sempre
  visível".

---

# P7 — A tela fala português de gente

**A queixa:** *"imagina que é um leigo, um designer, que tá usando. esse app não
tá nenhum pouco acessível."*

### O que medi

Quatro coisas, todas contáveis:

1. **56 botões com nome acessível acima de 40 caracteres.** O pior, na aba
   Manutenção, tem **144**: a descrição do desenho do cartão está *dentro* do
   `<button>`, então o leitor de tela anuncia

   > *"o conserto diário movendo a esteira dos três vigias, e as notificações
   > que cada um põe na tela 10 info diário logo bandeja jogos conserto logo
   > bandeja **Sim**"*

   para um botão cujo nome é "Sim". São 12 botões assim só nessa aba.

2. **43 caminhos `/home/andrefarias/...` visíveis na tela.** Todo cartão de
   ação imprime o caminho absoluto do script embaixo do botão Executar.

3. **122 parágrafos acima de 220 caracteres.** O da aba Atualização tem 70
   palavras numa frase só, e começa em minúscula: *"desenho, não é a sua tela:
   apt, flatpak e cargo atualizando a máquina numa tela só e, logo depois,
   ..."*.

4. **Um erro de redação em produção:** `app/servidor.py:2226` — *"Não escreve,
   **não escreve** e não pede senha"*.

### O que fazer

1. **O nome acessível do botão é só o rótulo.** A descrição do desenho sai de
   dentro do `<button>` e vira `aria-describedby` apontando para o parágrafo
   que já existe embaixo do cartão. Alvo: **zero** botões acima de 40
   caracteres.
2. **O caminho absoluto some da tela.** O cartão passa a mostrar `meow doctor`
   — o comando como a pessoa o digitaria — e o caminho completo fica no
   "ver comando" de P6. Alvo: **zero** ocorrências de `/home/`.
3. **Teto de 220 caracteres** por parágrafo de ajuda, e maiúscula inicial em
   todos. As legendas de desenho ("desenho, não é a sua tela: ...") passam a ser
   **uma frase**; o resto, que é bom, vira o balão do `?` que já existe ao lado
   de cada rótulo.
4. `servidor.py:2226` corrigido.
5. **O teste de palavras que já existe passa a cobrar isto.** `tests/numeros.sh`
   cobra números escritos à mão; o irmão dele cobra estes quatro tetos.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `app/pagina/app.js` | os cartões Sim/Não e os cartões de ação |
| `app/servidor.py` | as ajudas acima de 220 caracteres; a linha 2226 |
| `app/pagina/estilo.css` | o parágrafo de legenda |
| `tests/app-acessibilidade.py` | os quatro tetos |

### Como conferir

```js
[...document.querySelectorAll('#principal button')]
  .filter(b => b.textContent.trim().replace(/\s+/g,' ').length > 40).length   // 56 -> 0
(document.getElementById('principal').innerText.match(/\/home\/[a-z]+\//g)||[]).length  // 43 -> 0
```

### O que pode dar errado

- **Cortar texto não é o mesmo que explicar melhor.** O teto de 220 caracteres
  tem de vir junto com o balão do `?`, ou a sprint troca "longo demais" por
  "curto e incompreensível" — e aí o leigo fica pior do que estava.

---

# P8 — Ver antes de aplicar: o ensaio volta

**A queixa:** *"nada da interface é aplicado em sandbox. Tudo é aplicado na
máquina da pessoa."*

### O que medi

O motor **sabe** ensaiar: `lib/comum.sh:25` tem `MEOW_SECO`, `meow_seco()` na
linha 70, e `meow_escrever` respeita o seco (linha 565). O `--conferir` usa
isso.

A interface **perdeu** o ensaio. `app/pagina/app.js:4006`, em 13/09/2026:

> *"«Rodar de verdade» existia para contrastar com «Ensaiar»; sem o ensaio, o
> «de verdade» é palavra a mais."*

O botão sumiu junto com a palavra. Hoje, todo cartão de ação tem um único
botão — **Executar** — e ele escreve na máquina dela. É por isso que a frase
dele acima não é uma reclamação vaga: é a descrição exata do que sobrou.

### O que fazer

1. **O ensaio volta, e como padrão do gesto arriscado.** Todo cartão de ação
   marcado `destrutivo` ou `sudo` abre o diálogo com **dois** botões:
   **Ver o que faria** (roda com `MEOW_SECO=1`) e **Rodar**.
2. A gaveta de saída ganha um cabeçalho distinto no ensaio — `ENSAIO · nada foi
   escrito`, em amarelo — para que ninguém confunda as duas saídas.
3. **Depois de um ensaio, o botão "Rodar" fica ao lado da saída**, sem precisar
   reabrir o diálogo. É o fluxo: vejo, aprovo, rodo.
4. **"Salvar e aplicar", no alto, ganha o mesmo par.** Com 17 escolhas
   pendentes, "ver o que isto vai fazer" é a pergunta óbvia, e hoje ela não tem
   resposta.
5. **A dívida registrada de 31/08 entra aqui:** `etapa_logo` e
   `etapa_wallpaper` são **cegas ao seco** (dívida 6 do `docs/SPRINTS.md`). Um
   ensaio que escreve é pior que nenhum ensaio. Ou as duas passam a respeitar
   `MEOW_SECO`, ou o ensaio as declara na tela como "esta etapa não sabe
   ensaiar" — e elas não rodam.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `app/pagina/app.js` | `confirmar()` (linha 4001), a gaveta, o "Rodar" pós-ensaio |
| `app/servidor.py` | `/api/rodar` aceita `seco: true` e exporta `MEOW_SECO=1` |
| `app/pagina/estilo.css` | o cabeçalho de ensaio |
| `scripts/logo.sh`, `scripts/vigia_assets.sh` | as duas etapas cegas ao seco |
| `tests/seco.sh` | **novo**: roda as 58 etapas em seco e confere que o `MEOW_MANIFESTO` não cresceu um byte |

### Como conferir

```sh
# a prova dura: em seco, nada é escrito
sha256sum ~/.local/state/meowsystem/manifesto.tsv > /tmp/antes
MEOW_DRY_RUN=1 ./install.sh --uma-passagem >/dev/null
sha256sum -c /tmp/antes    # espera: OK
```

### O que pode dar errado

- **Ensaio que mente é pior que nada.** É exatamente a dívida de 31/08, e é o
  motivo de `tests/seco.sh` ser entrega desta sprint e não da seguinte.

---

# P9 — Uma senha só, e ela é a do install

**A queixa:** *"a ideia do app é pedir sudo no install e criarmos um perfil, e
esse perfil poder fazer sempre as aplicações do software, sem voltar a pedir
sudo."*

### O que medi

**Já existe, e está escondido.** `scripts/ponte_root.sh` é o braço root do
projeto: um programa em `/usr/local/lib/meowsystem/`, `root:root`, com uma
regra em `/etc/sudoers.d/49-meowsystem-ponte` sem um único curinga. O
cabeçalho cita a decisão de 08/09/2026, nas palavras dela: *"não conseguimos de
alguma forma usar sudo só na instalação?"*.

O que falta é o **fluxo**:

- O interruptor mora na aba **Manutenção**, com o rótulo *"Consertos de sistema
  sem pedir senha — Sim / Não"*, entre 19 outros ajustes. Quem instala nunca
  passa por ali.
- Os cartões de ação continuam ostentando **PEDE SENHA** (Instalar tudo,
  Desinstalar), sem dizer que existe um jeito de não pedir mais.
- O `install.sh` pede a senha e **não oferece** registrar o perfil na mesma
  hora, que é o único momento em que ele já tem a senha na mão.

### O que fazer

1. **O `install.sh` pergunta uma vez, na primeira instalação:**
   *"Registrar um perfil para que os consertos não peçam senha de novo? [S/n]"*
   Com `S`, `etapa_ponte_root` roda ali mesmo — a senha já está na mão.
   Resposta gravada; não volta a perguntar.
2. **A Home mostra o estado**, em uma linha: *"Consertos sem senha: ligado"* ou
   *"desligado — ligar"*. Uma pessoa não deveria caçar isso entre 19 ajustes.
3. **O rótulo `PEDE SENHA` passa a ser verdade condicional.** Com o perfil
   registrado, o cartão diz `SEM SENHA (perfil registrado)`. Hoje ele mente
   para quem já ligou a ponte.
4. **O `meow doctor` confere a ponte**: instalada, com o md5 certo, regra
   presente. Ponte quebrada vira pendência acionável de P2.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `install.sh` | a pergunta, e a chamada de `etapa_ponte_root` |
| `scripts/ponte_root.sh` | nada de novo — só passa a ser chamado no momento certo |
| `app/pagina/app.js` | a linha na Home; o rótulo condicional |
| `app/servidor.py` | o estado da ponte no esquema |
| `bin/meow` | `cmd_doctor` confere a ponte |

### Como conferir

```sh
meow doctor | grep -i ponte
# espera: "ok  ponte root registrada — consertos de sistema não pedem senha"
sudo -n /usr/local/lib/meowsystem/ponte_root.sh estado   # espera: sai 0, sem pedir senha
```

### O que pode dar errado

- **Escrever em `/etc/sudoers.d` é irreversível por acidente.** O `--uninstall`
  já remove a regra; `tests/reversao.sh` precisa cobrir a remoção, porque a
  regra do projeto ("toda unidade nova entra nas DUAS listas") já foi violada
  três vezes, segundo o `docs/SPRINTS.md`.

---

# P10 — O pack é o centro, e o Catppuccin é só um deles

> **Depende de P13 e P14** ([eixo II](2026-09-21-packs-modulares.md)). O bloco
> "Theme packs" da Home precisa de dois packs de verdade para desenhar, e hoje
> o Catppuccin é uma constante em `scripts/pack.py:86`.

**A queixa:** *"o programa original foi feito não pensando em um produto mas em
aplicar o tema catppuccin."* E, sobre a Home: *"o que eu quero nessa aba de
home: tenhamos o theme pack Catppuccin e o theme pack Dracula, e que qualquer
um possa exportar o próprio tema e importar outros pro seu sistema
operacional. disso em diante o app se modifica pra apresentar ao user o que ele
pede."*

### O que medi

O formato de pack **está bem escrito e mal implementado** — e esta frase
corrige o que eu mesmo afirmei aqui antes de medir. `docs/PACKS.md` tem 454
linhas e descreve um contrato coerente; **parte dele não tem leitor nenhum no
código**. A medição está em
[P20](2026-09-21-packs-modulares.md#p20--o-packjson-promete-o-que-ninguém-lê):
`cosmic.nome_da_paleta`, `cosmic.mapa`, `icones.*.herda`, `origens.cursores.*`
e `origens.wallpapers.*` são declarados pelo `packs/dracula/pack.json` e lidos
por ninguém.

O que de fato funciona hoje é a paleta e os dois acervos de ícone. O resto o
Dracula recebe porque **o arquivo do Catppuccin foi contaminado com o flavor
dele** — não porque a herança funcione.

O que não acompanhou foi a **tela**. Com o pack Dracula no ar, a aba Ícones
mostra, agora:

| o que aparece | por que está errado |
|---|---|
| `Mocha`, `Macchiato`, `Frappé`, `Latte` (variante dos ícones de arquivo) | são flavors do Catppuccin, numa máquina vestida de Dracula |
| `Mocha`, `Vidro escuro`, `Vidro claro`, `Latte` (a barra "Fundo") | idem, e são os fundos de teste de toda a página |
| `cat-${FLAVOR}-${ACCENT}` numa caixa de texto | sintaxe de shell pedida ao usuário |
| `vale como: cat-dracula-mauve` | o prefixo `cat-` é do Catppuccin, e sobrou |
| **"Pack de ícones Dracula nos aplicativos"** | o nome de um pack cravado no rótulo de um ajuste |

E a Home diz *"Drácula · Mauve · Escuro"* sem dizer **que isso é um pack**, sem
citar o outro que existe, e sem caminho para trocar.

A CLI é o espelho: `meow pack` tem quatro verbos (`listar`, `validar`, `info`,
`raizes`) e **nenhum deles escreve**. Trocar de pack é editar `PACK=` no
`meow.conf` à mão.

### O que fazer

1. **`meow pack usar <id>`** — escreve `PACK=` e `FLAVOR=` no `meow.conf`,
   valida antes, e roda a aplicação. É o verbo que falta para o formato ser
   produto.
2. **A Home ganha o bloco "Theme packs"**, em cima: um cartão por pack
   instalado (miniatura da paleta, nome, autor, o que ele fornece de próprio),
   o que está no ar com anel de acento, e **Usar este** nos outros. Ao lado,
   **Exportar o meu** e **Importar um pack** (P11).
3. **O vocabulário passa a vir do pack, não do Catppuccin:**
   - "Variante dos ícones de arquivo" lista os flavors **do pack no ar**;
     quando o pack herda mimetypes do Catppuccin (é o caso do Dracula), o
     rótulo diz `Macchiato (herdado do Catppuccin)` — honesto, e explica o nome
     estranho em vez de deixá-lo solto.
   - A barra "Fundo" passa a nomear os fundos **por função** — `Escuro`,
     `Vidro escuro`, `Vidro claro`, `Claro` — e não por flavor. Isso vale para
     qualquer pack, inclusive os que não têm "Latte".
   - "Pack de ícones **Dracula** nos aplicativos" vira **"Ícones do pack nos
     aplicativos"**, e a frase embaixo diz de qual pack vieram.
   - `cat-${FLAVOR}-${ACCENT}` deixa de ser texto digitado: vira **dois
     seletores** (variante e cor) com prévia, e o molde some da tela. Quem
     precisar do molde cru o encontra em "ver comando" (P6).
4. **`meow pack info` vira tela.** As 26 cores, o que é próprio, o que é
   herdado e de quem — hoje só existe no terminal.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `bin/meow` | `cmd_pack`: o verbo `usar` |
| `scripts/pack.py` | validação antes de trocar; o JSON que a tela consome |
| `app/servidor.py` | `/api/packs`; o vocabulário de flavor e de fundo sai do pack |
| `app/pagina/app.js` | o bloco na Home; a barra de fundos; os dois seletores da cor de pasta |
| `app/pagina/estilo.css` | os cartões de pack |
| `docs/PACKS.md` | o verbo `usar` |
| `tests/pack.sh` | trocar de pack e voltar, conferindo o tema no disco |

### Como conferir

```sh
meow pack usar catppuccin && meow status | head -3
meow pack usar dracula    && meow status | head -3
# e na tela, com o Dracula no ar:
#   nenhuma ocorrência de "Mocha", "Frappé" ou "${FLAVOR}" na aba Ícones
```

### O que pode dar errado

- **Trocar de pack com 17 escolhas pendentes.** A troca tem de avisar e
  oferecer descartar — ou uma escolha de outro pack vaza para dentro deste.
- **Os 26 nomes de cor continuam sendo do Catppuccin**, e isso é deliberado
  (`docs/PACKS.md` explica: são o vocabulário interno, não uma marca). O que
  sai da tela são os nomes de **flavor**, não os de slot.

---

# P11 — Exportar e importar um theme pack

> **Depende de P14** ([eixo II](2026-09-21-packs-modulares.md)). Empacotar
> `packs/dracula/` hoje entrega 28 arquivos e nenhum tema: os dois `.ron`, o
> capturado e os papéis de parede dele moram fora do pack.

**A queixa:** *"que qualquer um possa exportar o próprio tema e importar outros
pro seu sistema operacional."*

### O que medi

Os botões **Exportar** e **Importar**, no alto da página, existem e funcionam —
mas são de **ajustes**: exportam o `meow.conf` (`app/pagina/index.html:112` e
`:140`; `servidor.py:3319` e `:3357`). Não existe caminho, nem na tela nem na
CLI, para empacotar o que a pessoa montou e mandar para alguém.

### O que fazer

1. **`meow pack novo <id>`** — cria `packs/<id>/` a partir do que está no ar:
   `pack.json` preenchido, `paleta.json` com as 26 cores em uso, e os acervos
   que a pessoa adicionou (ícones, papéis de parede, ponteiro) **copiados**,
   nunca referenciados por caminho absoluto.
2. **`meow pack exportar <id> [arquivo.meowpack]`** — um `.tar.zst` com o
   diretório do pack, mais um `MANIFESTO` com `sha256` de cada arquivo e a
   versão do formato. Recusa exportar um pack que não valida.
3. **`meow pack importar <arquivo.meowpack>`** — valida **antes** de escrever:
   formato, as 26 cores, `https://` em toda URL, todo caminho caindo dentro do
   pack (as regras que `docs/PACKS.md` já declara). Instala em
   `~/.local/share/meowsystem/packs/<id>/`. **Não aplica** — importar é ganhar
   uma opção, não trocar de tema.
4. **Na tela:** os dois botões do bloco "Theme packs" da Home (P10). O importar
   mostra **o que o pack traz** antes de confirmar: paleta desenhada, quantos
   ícones, quantos papéis de parede, se traz ponteiro e som.
5. **Um pack importado nunca executa nada.** A regra de `docs/PACKS.md` ("um
   pack é dado, nunca é código") passa a ser **verificada na importação**: um
   `.sh` dentro do tarball é motivo de recusa, com a linha dizendo qual
   arquivo.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `bin/meow` | `cmd_pack`: `novo`, `exportar`, `importar` |
| `scripts/pack.py` | empacotar, desempacotar, validar o tarball |
| `app/servidor.py` | `/api/pack-exportar`, `/api/pack-importar` (upload) |
| `app/pagina/app.js` | os dois botões e a tela de confirmação |
| `docs/PACKS.md` | a seção "Publicar" ganha o formato `.meowpack` |
| `tests/pack.sh` | exportar, apagar, importar, conferir `sha256` |

### Como conferir

```sh
meow pack novo meu-tema && meow pack exportar meu-tema /tmp/meu-tema.meowpack
rm -rf packs/meu-tema
meow pack importar /tmp/meu-tema.meowpack && meow pack validar meu-tema   # sai 0
```

### O que pode dar errado

- **Tamanho.** Um pack com 91 papéis de parede é grande. O exportar precisa
  perguntar se as imagens vão junto, e dizer quantos MB antes.
- **Licença.** Acervo de terceiro (ícones, papel de parede) não pode ser
  reempacotado sem o `CREDITOS.md`. O exportar recusa sem ele.

---

# P12 — O pack cobre o resto: ponteiro, som, gerador, fontes

> **Depende de P14** ([eixo II](2026-09-21-packs-modulares.md)): as quatro
> categorias que faltam só têm onde morar depois que o pack passa a ser o dono
> do próprio conteúdo.

**A queixa:** *"que qualquer um possa criar um theme pack completo, com cursor,
temas de ícones, geradores de ícone, faixa de cores, som e todo o resto das
features."*

### O que medi

Categoria por categoria, o que o formato de hoje cobre:

| categoria | estado |
|---|---|
| paleta (26 cores) | **próprio** |
| tema do COSMIC | **próprio** (via `cosmic-map.json`) |
| ícones de aplicativo | **próprio** |
| ícones de pasta | **próprio** |
| mimetypes | próprio ou herdado |
| papéis de parede | **próprio** (árvore do GitHub) |
| som | **próprio** (frequências, pesos, decaimento) |
| **ponteiro** | **só herdado** — `packs/dracula/pack.json` declara `origens.cursores.herda: "catppuccin"`, com a nota *"não há pack de agente Dracula com release fixável por tag"* |
| **fontes** | **não declarável** — sai de `assets/fontes/`, igual para todo pack |
| **gerador de ícone** | **não declarável** — o traço do MeowSystem é fixo; a oficina gera sempre no mesmo estilo |
| **prompt, fastfetch, gatos** | **não declarável** — herdados sempre |

Ou seja: **quatro categorias das onze** ainda são do projeto, não do pack. E a
que mais aparece na tela é o ponteiro, que é o que ele fotografou.

### O que fazer

1. **`origens.cursores` ganha `proprio`:** um diretório de tema Xcursor dentro
   do pack (`cursores/<nome>/cursors/`), instalado em
   `~/.local/share/icons/` como qualquer outro. Continua valendo `herda`, para
   quem não tem.
2. **`fontes` vira declarável:** lista de `{nome, url, sha256}`, ou arquivos
   dentro do pack. A regra de `https://` e de `realpath` vale igual.
3. **`gerador` vira declarável** — e é a parte grande. O traço do MeowSystem
   hoje está cravado em `scripts/converter_icone.py` e `estilo_icone.py`. O
   pack passa a declarar um **perfil**: espessura, aparo, fusão, cantos, se
   preenche área, a cor. Não é código: são os parâmetros que a oficina já
   aceita, com nome.
4. **`prompt`, `fastfetch` e `gatos`** ganham `herda`/`proprio` pelo mesmo
   desenho dos ícones.
5. **`meow pack info` passa a imprimir as onze categorias**, com próprio ou
   herdado e de quem — é o que torna a herança auditável em vez de folclórica.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `scripts/pack.py` | as chaves novas e a validação de cada uma |
| `scripts/cursor.sh` | ler o ponteiro do pack antes de baixar |
| `scripts/instalar_fontes.sh` | ler a lista do pack |
| `scripts/converter_icone.py`, `scripts/estilo_icone.py` | os parâmetros saem do perfil do pack |
| `docs/PACKS.md` | as quatro seções novas |
| `packs/dracula/pack.json` | ganha ponteiro próprio se houver, ou mantém `herda` **com o motivo** |
| `tests/pack.sh` | um pack de teste com as onze categorias próprias |

### Como conferir

```sh
meow pack info dracula
# espera: as ONZE categorias, cada uma com próprio ou herdado, e a origem
```

### O que pode dar errado

- **O gerador é o risco real.** "Declarar o traço" pode virar um mini-DSL, e aí
  o pack deixa de ser dado. O limite é duro: **só os parâmetros que a oficina
  já aceita hoje**, com nome. Nada de expressão, nada de condicional.
- **Ponteiro próprio é trabalho de desenho**, não de formato. Abrir a chave não
  cria um ponteiro Dracula; só deixa de impedir quem tiver um.

---

# P17 — A prévia do ponteiro, e a irmã que não acompanhou

**A queixa:** *"por que os ícones dos outros cursores não aparecem no
preview?"*

### O que medi

Chamando as duas funções do servidor direto, nesta máquina:

```
_temas_de_cursor()  -> ['Adwaita', 'Dracula-Cursor', 'Pop', 'catppuccin-mocha-light']   (4)
_prev_cursores()    -> ['catppuccin-mocha-light']                                       (1)
```

**Quatro opções, uma prévia.** Não é falta de arquivo: os quatro têm ponteiro
decodificável no disco.

```
Adwaita        -> /usr/share/icons/Adwaita/cursors/left_ptr
Pop            -> /usr/share/icons/Pop/cursors/left_ptr
Dracula-Cursor -> ~/.local/share/icons/Dracula-Cursor/cursors/left_ptr
```

A causa está em `app/servidor.py:2974`, dentro de `_prev_cursores`:

```python
for valor in _temas_de_cursor():
    pasta_tema = valor + SUFIXO_CURSOR      # SEMPRE acrescenta "-cursors"
```

Ela monta o caminho **só por convenção**. A irmã `_temas_de_cursor`
(`servidor.py:1426`) foi corrigida em **15/09/2026** para aceitar **nome exato
OU convenção** — foi assim que o `Dracula-Cursor`, que não tem sufixo, passou a
aparecer. **`_prev_cursores` não acompanhou.** Então:

| opção | a prévia procura | existe? |
|---|---|---|
| `catppuccin-mocha-light` | `catppuccin-mocha-light-cursors/cursors/` | sim |
| `Dracula-Cursor` | `Dracula-Cursor-**cursors**/cursors/` | **não** |
| `Adwaita` | `Adwaita-**cursors**/cursors/` | **não** |
| `Pop` | `Pop-**cursors**/cursors/` | **não** |

E o docstring dela ainda afirma, em letras de hoje:

> *"Diretório que não termine em `-cursors` — Adwaita, Pop, breeze — fica de
> fora da lista, e isso não é perda: escolhê-los NUNCA funcionou."*

Deixou de ser verdade em 15/09. **O comentário está descrevendo um mundo que a
irmã dele já mudou** — e o próprio docstring de `_temas_de_cursor` registra que
esse erro já aconteceu uma vez, com estas palavras: *"A lista não acompanhou."*
É a segunda ocorrência do mesmo defeito, no mesmo par de funções.

### O que fazer

1. **A resolução vira uma função só, e as duas a chamam.** Nasce
   `_cursor_pasta_do_valor(valor)` em `servidor.py`, com a regra única: nome
   exato primeiro, convenção `<valor>-cursors` depois — espelhando
   `_cursor_dir_exato` e `_cursor_dir_tema` do `scripts/cursor.sh`. É o único
   conserto que impede a terceira ocorrência; corrigir só a linha 2974 deixaria
   duas cópias da regra vivas.
2. `_prev_cursores` passa a usar a função nova. Esperado: **4 prévias de 4
   opções**.
3. **O docstring desatualizado sai**, e no lugar entra a regra de verdade —
   com a data e o motivo, que é como o resto do arquivo escreve.
4. **Prévia ausente deixa de ser silêncio.** Se um dia um tema listado não
   render imagem, o cartão mostra a silhueta de um ponteiro em traço com o
   rótulo, em vez de um retângulo vazio. Um cartão vazio é indistinguível de um
   cartão quebrado.
5. **Um teste amarra as duas listas:** `len(_prev_cursores()) == len(_temas_de_cursor())`.
   Divergência entre elas é, por definição, um defeito — e é o único teste que
   teria pego isto em 15/09.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `app/servidor.py` | `_cursor_pasta_do_valor`; `_prev_cursores` (2971-2985); o docstring |
| `app/pagina/app.js` | o cartão sem prévia ganha silhueta |
| `tests/app-navegador.py` | a igualdade das duas listas |

### Como conferir

```sh
cd app && python3 -c "
import importlib.util, sys
spec = importlib.util.spec_from_file_location('srv','servidor.py')
m = importlib.util.module_from_spec(spec); sys.modules['srv']=m; spec.loader.exec_module(m)
print(len(m._temas_de_cursor()), len(m._prev_cursores()))"
# antes: 4 1  ·  depois: 4 4
```

### O que pode dar errado

- **O Adwaita e o Pop continuam sendo escolhas que o `cursor.sh` resolve por
  nome exato** — o `_cursor_dir_exato` de 15/09 cobre os dois. Se a medição
  mostrar que escolher um deles ainda tenta a rede, a sprint cresce para
  incluir o `cursor.sh`, e isso precisa ser medido **antes** de mexer na prévia:
  mostrar prévia de um ponteiro que quebra ao ser clicado é pior que não
  mostrar.

---

# P22 — O primeiro comando do README não roda

**De onde veio:** uma varredura de portabilidade, em 21/09, perguntando o que
impede um estranho de instalar. A resposta estava na linha 39 do README.

### O que medi

```
README.md:39      git clone https://github.com/[REDACTED]/MeowSystem.git
README.en.md:34   git clone https://github.com/[REDACTED]/MeowSystem.git
```

**O passo 1 do projeto não roda.** O sanitizador de identidade — que existe por
um bom motivo, e o `packs/dracula/pack.json` explica qual — apagou a conta e
**ninguém repôs**. São 8 ocorrências de `[REDACTED]` no repositório, em
`README.md`, `README.en.md`, `meow.conf.exemplo`, `app/servidor.py`,
`app/pagina/app.js`, `scripts/wallpaper.sh`,
`assets/papeis-de-parede/CREDITOS.md` e `docs/historico/`.

**As outras receitas que não rodam**, todas em documentação:

| onde | o que manda fazer | por que falha |
|---|---|---|
| `assets/prompt/LEIAME.md:145-174` e `aurora.patch:14-20` | `patch -p1 < /mnt/Apate/.../src/prompt/aurora.patch` | o disco não existe **e** `src/prompt/` virou `assets/prompt/` |
| `src/applets/now-playing/LEIA.md:199,202` | regenerar o patch do applet gravando em `/mnt/Apate` | idem |
| `scripts/compositor_patches.sh:137-145` | sem o "Ritual da Aurora", `conferir` devolve divergência e manda rodar `aurora-cosmic-comp-ws.sh --build` | o script não existe nesta máquina, nem no repositório |

**O `compositor_patches.sh` é o pior dos três**, porque não é doc: ele faz o
`meow doctor` devolver divergência **todo dia, para sempre**, apontando para um
script de outro projeto. Um doctor que nunca fica verde é um doctor que a pessoa
aprende a ignorar — e aí ele para de servir para qualquer coisa.

### O que a mesma varredura achou de CERTO, e que não se deve mexer

Isto entra na sprint para que ninguém "conserte" o que está bom:

- **Zero** e-mail, token, chave, UUID, MAC, serial, resolução cravada ou número
  de monitores em código.
- **Zero** `/mnt/Apate` ou `/mnt/Mnemosyne` **em código** — as 369 ocorrências
  são todas comentário e documentação, e foram conferidas uma a uma.
- `lib/comum.sh:236-249` — os vizinhos saíram do código para `vizinhos.conf`,
  sem `eval`, semeados do disco real por `install.sh:216`. É o padrão que o
  resto do projeto deveria seguir.
- `bin/meow:75-97` — a raiz é resolvida em quatro degraus, sem caminho cravado.
- `jogos_steam.sh` e `jogos_heroic.sh` — as bibliotecas saem do estado, nunca de
  lista.
- `LC_ALL=C` em todo `awk`/`sort`/`comm` que toca número. A suposição de pt_BR
  está tratada, com a cicatriz documentada.
- `bin/meow:2873` — o caminho de casa na `captura.txt` é **guarda de
  propósito**, não descuido.

### O que fazer

1. **O `[REDACTED]` do README vira a URL real**, nos dois idiomas. A decisão de
   qual conta (`vitoriamariadb` é o `origin`) é dele — a sprint só cobra que
   **haja uma**, e que o comando rode.
2. **As outras 6 ocorrências de `[REDACTED]`** são revisadas uma a uma: o
   sanitizador apagou em lugares onde a palavra era necessária, e o resultado é
   texto que não se entende. Onde a identidade não puder voltar, a frase é
   reescrita para não depender dela.
3. **`assets/prompt/LEIAME.md` e `src/applets/now-playing/LEIA.md`** passam a
   citar o caminho **relativo ao repositório**, que é o único que existe na
   máquina de quem clonou.
4. **`compositor_patches.sh` para de cobrar o Ritual da Aurora.** Sem os patches
   do compositor, o estado correto é *"os patches do compositor não estão
   aplicados — isto é opcional e não afeta o tema"*, e o doctor fica **verde**.
   Divergência é para o que o projeto sabe consertar; o resto é informação.
5. **`scripts/ocultar_apps.sh:84-136`** — 35 aplicativos ocultados por lista
   fechada, sem chave que a edite. A lista vira uma chave do `meow.conf` com
   esses 35 como valor de fábrica. Quem não tem aqueles apps não perde nada;
   quem tem outros passa a poder dizer.
6. **O teste que impede a volta:** `tests/portabilidade.sh` — regras para home
   de pessoa em código, disco que não é padrão, `[REDACTED]` em instrução de
   instalação, e `$HOME/.config/zsh` sem variável de escape. **Com isenções
   casadas pelo conteúdo da linha, nunca pelo número** — isenção presa a número
   apodrece no primeiro rebase.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `README.md`, `README.en.md` | a URL do clone |
| `meow.conf.exemplo`, `app/servidor.py`, `app/pagina/app.js`, `scripts/wallpaper.sh`, `assets/papeis-de-parede/CREDITOS.md` | as outras 6 ocorrências |
| `assets/prompt/LEIAME.md`, `src/applets/now-playing/LEIA.md` | o caminho relativo |
| `scripts/compositor_patches.sh` | o Ritual deixa de ser divergência |
| `scripts/ocultar_apps.sh` | a lista vira chave |
| `tests/portabilidade.sh` | **novo** |

### Como conferir

```sh
grep -rn "REDACTED" --exclude-dir=.git .     # antes: 8 · depois: 0
./tests/portabilidade.sh                      # antes: exit 1, 12 achados · depois: exit 0
meow doctor | grep -i compositor              # verde numa máquina sem os patches
```

### O que pode dar errado

- **O sanitizador vai apagar de novo.** Ele é versionado e roda no que entra em
  commit. A URL do clone precisa estar numa lista de exceção **dele**, ou este
  conserto dura até o próximo commit — e aí o defeito volta silencioso, que é
  como ele chegou aqui.

---

# P23 — A suíte está vermelha há três dias e nada a roda

**De onde veio:** uma auditoria de pontas soltas, em 21/09.

### O que medi

**1. O teste está vermelho, e correto.** `tests/numeros.sh` roda e sai com
`rc=1`, apontando **14 números fora do lugar**:

```
FALHOU: README.md diz 50 conferências; são 55
FALHOU: README.md diz 109 ajustes; são 121
FALHOU: README.en.md diz 54 steps (badge); são 58
FALHOU: app/LEIA-ME.md diz 109 chaves; são 121
FALHOU: docs/SPRINTS.md diz 54 etapas (estado de hoje); são 58
FALHOU: README.md diz 46 ações; são 50
  (e mais 8)
```

O teste está fazendo exatamente o trabalho dele. **Ninguém o rodou.** O
`README.md` foi editado em **19/09** — um dia depois de o teste ficar vermelho
— e os números não foram corrigidos.

**2. Porque nada roda a suíte.** O único workflow do repositório é
`.github/workflows/anonymity-check.yml`, que confere identidade. **Não existe
CI que execute `tests/`.** São 13 arquivos de teste, e a única forma de saber
que um está vermelho é lembrar de chamá-lo pelo nome.

Isso explica por que o `docs/SPRINTS.md` consegue afirmar *"123/123 passando"*
ao lado da frase, dele mesmo, *"a suíte verde não fecha sprint"*.

**3. E a suíte cobre pouco.** 13 arquivos de teste executam **6 dos 83 scripts**
— e 3 desses 6 são quase-órfãos. `scripts/pack.py` e `scripts/painel.sh` têm
**zero cobertura**. `pack.py` é o coração de tudo que P13 a P21 propõem.

**4. Sete etapas do instalador sem doctor e sem teste:** `cli`, `pacotes`,
`escala`, `upstream`, `fontes`, `logo`, `autoreparo`. Três são as **únicas** que
tocam rede ou `apt`; `autoreparo` é a que faz tudo convergir.

**5. Um contrato citado por número que não existe em lugar nenhum.** As palavras
"regra N" e "o contrato do projeto" aparecem **50 vezes** em código, apontando
para as regras 1, 4, 5, 7, 8 e 10. **A lista numerada não existe** — nem em
`docs/`, nem em `lib/`. Cada leitor inventa a sua.

**6. Afirmações que envelheceram em silêncio.** `lib/comum.sh:103` diz "54
etapas, 46 ações"; o arquivo foi editado em 19/09, depois do commit que as levou
a 58 e 50. E `lib/comum.sh:105` promete uma cobertura que não existe:
`tests/estilo.sh` **não tem** o `grep` que ele afirma ter.

**7. Duplicação medida:**

| o quê | onde | observação |
|---|---|---|
| a fórmula de contraste WCAG, **3 cópias** | `derivar_claro.py:38-47`, `pack.py:111-123`, `spotify/xpui.py:125-130` | as duas primeiras nasceram no mesmo commit |
| **3 resolvedores de ícone que se contradizem** | `icones_orfaos.py` chama o método de `app/servidor.py:4935` de *"mente com convicção"*; `lib/icones.sh:183` afirma que o painel usa o outro | dois arquivos descrevendo o mesmo sistema de formas incompatíveis |
| 4 vigias com **70-72 linhas idênticas de ~87** | medido com `comm -12` | |

**8. Dois órfãos duros** (zero referências em todo o repositório):
`scripts/derivar_claro.py` — gerador de tiro único cuja saída já está colada em
`packs/dracula/paleta.json`, nascido e morto no commit `045b82b` — e
`scripts/folha_barra.py`. Mais 12 quase-órfãos, ~220 KB inalcançáveis.

**E zero `TODO`/`FIXME` no repositório.** Não é limpeza: a dívida está em prosa
afirmativa, dentro dos comentários, onde nenhuma busca a encontra.

### O que fazer

1. **Um runner:** `tests/todos.sh`, que roda os 13 e devolve `rc` diferente de
   zero se qualquer um falhar. Hoje não existe a pergunta "a suíte passa?".
2. **Um workflow que o chama**, ao lado do `anonymity-check.yml`. Sem isso, o
   item 1 depende de alguém lembrar — que é o que falhou em 19/09.
3. **Os 14 números são corrigidos** no `README.md`, `README.en.md`,
   `app/LEIA-ME.md` e `docs/SPRINTS.md`. Como o próprio teste manda: *"o conserto
   é atualizar o TEXTO, nunca o código: quem manda é a contagem."*
4. **`lib/comum.sh:103` e `:105`** — o número velho sai; a promessa de cobertura
   ou vira verdade (o `grep` entra no `tests/estilo.sh`) ou sai do comentário.
5. **A lista numerada de regras passa a existir**, em `docs/FRONTEIRA.md`, com
   as 6 que são citadas. As 50 citações passam a apontar para algo.
6. **Os dois órfãos são mencionados, não apagados** — é a regra do projeto. O
   `tests/orfaos.sh` entra e falha nos dois, com isenção comentada para os 11
   casos legítimos. Apagar é decisão dele, numa linha de commit própria.
7. **As sete etapas descobertas ganham conferência no doctor**, começando por
   `autoreparo`, que é a que faz o resto convergir (e é pré-requisito de P1).

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `tests/todos.sh` | **novo** — o runner |
| `.github/workflows/testes.yml` | **novo** |
| `tests/orfaos.sh` | **novo** |
| `README.md`, `README.en.md`, `app/LEIA-ME.md`, `docs/SPRINTS.md` | os 14 números |
| `lib/comum.sh` | as linhas 103 e 105 |
| `tests/estilo.sh` | o `grep` prometido |
| `docs/FRONTEIRA.md` | a lista numerada |
| `bin/meow` | as sete conferências novas do doctor |

### Como conferir

```sh
./tests/todos.sh              # rc=0, e diz quantos rodaram
./tests/numeros.sh            # antes: rc=1, 14 fora · depois: rc=0
grep -rn "regra [0-9]" --include="*.sh" --include="*.py" . | wc -l   # 50 citações,
grep -c "^" docs/FRONTEIRA.md                                        # e agora há lista
```

### O que pode dar errado

- **Ligar CI numa suíte vermelha pinta tudo de vermelho no primeiro dia.** A
  ordem é: corrigir os 14 números (item 3), depois o runner, depois o workflow.
  Ligar antes ensina a ignorar o vermelho, que é o defeito que esta sprint veio
  consertar.
- **Os testes tocam a máquina.** Um workflow em máquina sem COSMIC precisa de
  `MEOW_IGNORA_DESKTOP=1` e do modo seco (P8) — vale rodar primeiro só o
  subconjunto que não escreve, e dizer na tela qual subconjunto é.

---

# P24 — A primeira instalação num estranho

**De onde veio:** a simulação, por leitura, de alguém que acabou de clonar o
repositório num Pop!_OS com COSMIC. É a sprint que responde literalmente ao
*"não só pra minha máquina ou da Vitória, mas pra qualquer user"*.

### O achado que vem primeiro, porque também atinge vocês dois

```
$ cat assets/temas/capturados/original/captura.txt
captura: original
quando:  2026-08-04T17:33:15-03:00
origem:  /home/vitoriamaria/.config/cosmic
arquivos: 121
```

**O "tema de antes" que o `meow desfazer` restaura é o desktop da Vitória, de 4
de agosto.** O botão **"Voltar ao tema de antes"** da aba Instalação — que a
tela descreve como *"Devolve o COSMIC ao backup feito antes da instalação"* —
devolve a máquina **de outra pessoa**, com 121 arquivos.

Não é hipótese sobre um estranho: **é o que acontece nesta máquina hoje.** E o
`capturar_tema.sh:67` **recusa recapturar** o `original`, então ele não se
conserta sozinho.

O `README.md:138` promete uma coisa e o `lib/desinstalar.sh:300` diz o oposto —
os dois descrevendo o mesmo botão.

### Os outros cinco tropeços, na ordem em que derrubam alguém

**1. O wizard oferece 60 combinações e existem 4.**

```
meow.conf.exemplo:62   # mocha | macchiato | frappe | latte | dracula      (5)
meow.conf.exemplo:109  # mauve | pink | lavender | blue | sapphire | sky |
                       #   teal | green | yellow | peach | maroon | red    (12)
assets/temas/capturados/   dracula-mauve  latte-mauve  mocha-mauve  mocha-pink
```

**5 × 12 = 60 pares apresentados como escolha; 4 têm captura.** Quem responder
"macchiato" + "teal" — opções que a própria pergunta ofereceu — cai fora.

E encadeia: sem `etapa_tema`, o `aplicar_tema.sh:302` nunca cria o backup
`-tema-PRIMEIRO-`; sem ele, o `--uninstall` não tem para onde voltar
(`lib/desinstalar.sh:286,298`). **Uma escolha legítima no wizard deixa a pessoa
sem tema e sem desinstalação.**

**2. Sem rede, o instalador morre em vez de pular.** `baixar_upstream.sh:55-58`
e `instalar_fontes.sh:464-467` devolvem `MEOW_ERRO` (2) quando o download falha,
onde as outras 56 etapas devolveriam `SEM_DEPENDENCIA` (3). O resultado é
`falhou: upstream fontes` e `return 2`. **O remédio já existe no próprio
repositório:** `midia_build.sh:144-146` e `cursor.sh:376-384` fazem o mesmo
download e devolvem 3. E o pré-voo não pergunta pela rede.

**3. `install.sh:536` converte um 3 deliberado em 2.** A linha é
`python3 … | sed … || return "$MEOW_ERRO"`, e com o `pipefail` de
`lib/comum.sh:16` o `sys.exit(3)` de `gerar_tema_v1.py:441` vira
`falhou: gerar`. O comentário em `gerar_tema_v1.py:424-430` diz, com todas as
letras, que sair 2 ali **seria mentira**. E `install.sh:581`, três linhas
adiante, faz certo, com `PIPESTATUS[0]`.

**4. O pré-voo confere 6 comandos; o caminho de instalação usa 36.** Faltam
`md5sum` e `cmp`, e os dois causam divergência **silenciosa e eterna**: sem
`md5sum`, `install.sh:1035-1037` lê vazio como "diverge" e **reinstala a ponte
root, pedindo senha, em toda passagem**. Faltam também `xz`, `fc-list`,
`fc-match`, `gsettings`, `busctl`, `systemd-escape`, `pgrep`, `fuser`,
`flatpak`, `starship`, `fastfetch` e `cosmic-randr`. E a linha de conserto de
`preflight.sh:122` tem sete pacotes digitados à mão.

**5. O carrossel prometido nasce vazio.**

```
grep -c semear install.sh   ->  0
```

`etapa_wallpaper` chama `aplicar`, que sai 3 com *"só 0 imagem(ns)… o carrossel
precisa de 2 ou mais"* (`wallpaper.sh:1504-1508`). Quem baixa é `cmd_semear`
(`wallpaper.sh:2446`), e **o instalador nunca o chama**. O `README.md` promete
"43 imagens" duas vezes (`:77`, `:116`).

### E o `meow.conf` nasce com sete padrões que são dele

O arquivo nasce por cópia integral do exemplo (`install.sh:180-181`), o que está
**certo**: 121 chaves, 87,4% de comentário, zero duplicatas, e **nenhuma quebra
o install** — a guarda de `install.sh:202-207` cobre as obrigatórias e falha com
mensagem limpa.

O que não serve num estranho: `APPS_ATIVOS` com 24 aplicativos dele,
`AREAS_NOMES="Meow, OS"`, `AUTOSTART_BLOQUEADOS=org.qbittorrent.qBittorrent`,
`MIDIA_LARGURA=440` e `FASTFETCH_LOGO_CELULA=2.556` (ambos **medidos na tela
dele**), e `ICONES_FLAVOR="macchiato"` divergindo do `FLAVOR="mocha"` da linha
63 — duas linhas do mesmo arquivo discordando.

E o `README` diz "quatro chaves essenciais" (`:41`, `:158`); são **cinco**
(`[essencial]` marca `FLAVOR`, `ACCENT`, `MODO`, `LANCADOR_SISTEMA`,
`PONTE_ROOT`) — e `LOGO`, que o `install.sh:147` **exige**, não está entre elas.

### O que fazer

1. **O `original` deixa de ser versionado como molde de restauração.** Ele vira
   o que sempre foi: a captura de referência do projeto, renomeada para
   `referencia/`, e documentada como tal. **O backup de restauração passa a ser
   feito na máquina de quem instala**, na primeira passagem, antes da primeira
   escrita — que é o que a tela já promete. Sem isso, "Voltar ao tema de antes"
   é um botão que mente para todo mundo.
2. **A lista de flavors e accents sai do comentário e passa a vir do disco.**
   O wizard oferece **só os pares que têm captura**; os outros aparecem
   cinzentos, com a frase *"sem captura de referência — o tema sai por
   derivação"*, ou não aparecem. Nenhuma pergunta oferece resposta que quebra.
3. **As duas etapas de rede devolvem 3, não 2**, copiando o que
   `midia_build.sh` e `cursor.sh` já fazem. E o pré-voo passa a perguntar pela
   rede, dizendo quais etapas dependem dela.
4. **`install.sh:536` passa a usar `PIPESTATUS[0]`**, como a linha 581.
5. **O pré-voo confere os 36 comandos**, com `md5sum` e `cmp` primeiro, e a
   linha de conserto **é gerada** a partir da tabela, não digitada.
6. **`etapa_wallpaper` semeia antes de aplicar**, ou o README para de prometer
   43 imagens. As duas são aceitáveis; a combinação de hoje não.
7. **Os sete padrões pessoais do `meow.conf.exemplo`** viram vazios com
   comentário explicando como preencher, ou valores derivados da máquina. O
   `ICONES_FLAVOR` passa a herdar `FLAVOR` quando vazio.
8. **`README.md` e `README.en.md`:** "quatro chaves essenciais" vira cinco,
   `LOGO` entra na conta, e a promessa sobre `aplicar_tema.sh original` passa a
   dizer o que o código faz.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `lib/preflight.sh` | os 36 comandos; a rede; o relatório "isto falta, isto resolve" |
| `install.sh` | `:536` (PIPESTATUS); o backup na máquina; a semeadura |
| `scripts/baixar_upstream.sh`, `scripts/instalar_fontes.sh` | 2 vira 3 |
| `scripts/capturar_tema.sh`, `lib/desinstalar.sh` | `original` vira `referencia` |
| `assets/temas/capturados/original/` | renomeado, e documentado |
| `meow.conf.exemplo` | os sete padrões pessoais |
| `bin/meow` (`cmd_configurar`) | o wizard oferece só o que existe |
| `README.md`, `README.en.md` | as três divergências |

### Como conferir

```sh
# 1. o backup é da máquina de quem instala
grep origem ~/.local/state/meowsystem/backups/*/captura.txt
# espera: o HOME de quem rodou. Nunca /home/vitoriamaria

# 2. o wizard não oferece o que não existe
meow configurar   # responder "macchiato" + "teal" tem de ser impossível ou avisado

# 3. sem rede, o instalador pula e termina em 0
sudo ip link set <iface> down; ./install.sh --uma-passagem; echo $?   # espera: 0
```

### O que pode dar errado

- **Mexer no `original` mexe no `meow desfazer`**, que é a rede de segurança de
  tudo. A renomeação só pode acontecer **depois** de o backup por máquina
  existir e ter sido testado, ou o projeto passa um intervalo sem desfazer
  nenhum.
- **"O wizard oferece só o que existe" reduz a escolha de 60 para 4** no primeiro
  dia. Isso vai parecer regressão. A frase na tela tem de dizer que os outros 56
  pares saem por derivação e que a captura é refinamento, não requisito — ou a
  sprint troca uma promessa falsa por uma porta fechada.

---

## Ordem sugerida, e por quê

| onda | sprints | dias | por quê nesta ordem |
|---|---|---|---|
| 0 | **P22**, **P23**, **P24** | ~7 | o `git clone` do README tem `[REDACTED]` no lugar da conta, e a suíte está vermelha sem que nada a rode. Enquanto isso estiver assim, nenhum estranho chega às outras, nenhuma das outras é verificável, e o «Voltar ao tema de antes» restaura o desktop de outra pessoa |
| 1 | **P17, P5, P4, P3, P1** | ~3 | custo baixo, dor diária. P17 são duas horas e são três linhas. P5 são três horas e resolve uma queixa literal; P4 destrava 17 deslizantes; P3 faz o log parar de mentir; P1 acaba com "rode mais uma vez" |
| 2 | **P2, P9, P6, P7** | ~8 | P2 instala a regra (e por isso não é a primeira: a regra fica melhor depois que três casos concretos passaram por ela). P9 usa a pendência que P2 criou |
| 3 | **P8** | ~2 | depende de P2 para as pendências, e é **pré-requisito de P14** (a árvore se move em seco na primeira passagem) |
| 4 | **P13, P14** (eixo II) | ~7 | a árvore se reordena. Sem isso, P10 a P12 não têm o que mostrar nem o que empacotar |
| 5 | **P15, P16** (eixo II) | ~3 | a vitrine e o CSV |
| 6 | **P10, P11, P12** | ~10 | a Home, o exportar/importar e as onze categorias |

**As quatro primeiras cabem numa semana e mudam o que ele vê todo dia.** As
ondas 1 a 3 são de interface e não tocam em `packs/`; as ondas 4 a 6 são de
estrutura e não tocam em `app/pagina/`, a não ser pelo cartão de pack. As duas
frentes podem correr em paralelo.

---

## O que NÃO entra nesta leva, e por quê

- **"O tema do ponteiro não aparece."** Medi na máquina dele:
  `~/.icons/default/index.theme` herda `Dracula-Cursor`, o `gsettings` devolve
  `'Dracula-Cursor'`, e o diretório existe. **A configuração está certa.** O
  que a foto mostra é outra coisa: três dos quatro cartões de ponteiro estão
  **sem desenho** — `Dracula-Cursor` traz `preview.png`, e `Adwaita` e `Pop`
  não. Isso é prévia faltando, e entra em P6 como item, não como sprint. Se,
  mesmo com a configuração certa, o ponteiro na tela continuar o antigo, é
  reinício de sessão do `cosmic-comp` — e aí vira sprint própria, com medição.
- **Redesenhar as abas.** Ele pediu um app acessível, não um app diferente. As
  14 abas e os dois blocos (Tópicos e Sistema) ficam; P4 a P7 mexem em como
  cada controle se comporta, não em onde ele mora.
- **`favicon.ico` devolve 404** (único erro de console na página). Linha de
  correção, não sprint: entra junto de P7.
- **As oito dívidas abertas do `docs/SPRINTS.md`.** Só a dívida 6 (as duas
  etapas cegas ao seco) foi puxada, porque P8 não funciona sem ela.

---

## Como isto foi medido, para quem quiser refazer

```sh
cd ~/Desenvolvimento/MeowSystem
./app/run.sh --sem-abrir          # imprime a URL com o token
```

Com a URL no Playwright (janela 1600x900), percorrendo os 14 botões de
`#trilho` e, em cada aba, contando: `input[type=range][disabled]`, botões com
`getBoundingClientRect()` abaixo de 24 px, `[title]` acima de 60 caracteres,
`title` casando `\(meow [a-z]`, botões com `textContent` acima de 40
caracteres, ocorrências de `/home/[a-z]+/` em `innerText`, e parágrafos acima
de 220 caracteres. A gaveta foi medida abrindo-a por `hidden = false` e
comparando o `getBoundingClientRect()` dela com o do `#trilho` — **nenhuma
ação foi executada, e nada foi escrito na máquina.**

O teste que P6 e P7 entregam (`tests/app-acessibilidade.py`) é exatamente essa
varredura, virada conferência: os números acima são o **antes**, e cada sprint
declara o **depois** que ela cobra.

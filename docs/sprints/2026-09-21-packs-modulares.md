# Leva de 21/09/2026, eixo II — o pack vira a unidade do produto

Treze sprints — **P13 a P16, P18 a P21 e P25 a P29** — que resolvem a queixa
estrutural. Irmãs
de [`2026-09-21-de-tema-a-produto.md`](2026-09-21-de-tema-a-produto.md), e
**anteriores** a P10, P11 e P12 daquele arquivo: não dá para exportar um pack
enquanto o conteúdo do pack não mora dentro dele. **Nada aqui foi executado.**

**P18 entrou depois das outras quatro**, em 21/09, quando a pergunta dele
— *"por que ou não aplicou, ou por que o log mentiu?"* — foi medida até o fim
e revelou que os **oito** módulos de `assets/temas-de-apps/` citam
"catppuccin" **446 vezes** e **nenhum** lê o pack ativo.

> **Ele, 21/09/2026, abrindo `packs/dracula/`:**
> *"aqui deveria ter tudo do theme dracula, e deveríamos ter um theme do
> catppuccin, um pack disso também. mas não temos nada. isso é preocupante."*
>
> *"preciso que vc escreva as sprints pra reordenarmos os arquivos pra eles
> funcionarem modularizado."*
>
> *"até o catppuccin, a ideia é darmos via json ou csv um theme completo. com
> imagem de capa (svg) e afins. além de descrição e tudo mais. catppuccin vem
> por default, mas o user pode criar o dele e usar um dracula da vida."*

---

## Sumário

| # | sprint | o que resolve | esforço |
|---|---|---|---|
| **P13** | O Catppuccin deixa de ser código e vira pack | `PACK_EMBUTIDO = "catppuccin"` sai do Python | 3 dias |
| **P14** | Tudo do tema mora dentro do pack | a árvore se reordena; `assets/` fica só com o motor | 4 dias |
| **P15** | O pack tem cara: capa, descrição, metadados | ninguém escolhe um tema por um `id` | 2 dias |
| **P16** | A paleta entra por JSON ou CSV | 26 linhas num CSV é o que um designer já sabe fazer | 1 dia |
| **P18** | Os temas de aplicativo obedecem ao pack | 8 módulos, 446 citações de "catppuccin", zero leem o pack | 4 dias |
| **P20** | O `pack.json` promete o que ninguém lê | campos declarados sem leitor; a ponte shell→Python não existe | 3 dias |
| **P19** | A raiz da configuração tem dois idiomas | 14 honram a variável, 23 cravam o caminho | 4 h |
| **P21** | Usar o programa não pode sujar o repositório | o painel grava em 5 arquivos e 91 SVG versionados | 3 dias |
| **P25** | Cada pack tem um logo em SVG | tira de cor não é identidade; e o logo vira o ícone do lançador | 2 dias |
| **P26** | O acervo do pack é uma origem na oficina | os 18 SVG do Dracula estão instalados e invisíveis na tela | 3 dias |
| **P27** | Todo ícone que veste alguém mora no pack | 25 de 3.566 SVG estão em `packs/`; 11 do Dracula moram em `assets/` | 4 dias |
| **P28** | A fonte única: um desenho, todo o resto derivado | 23 linhas de mapa apontam para fora do repositório | 5 dias |
| **P29** | O que é tema volta para casa | a série de patches, o spicetify e o construtor do Dracula moram no Spellbook | 4 dias |

---

## O que medi, e por que ele está certo em chamar de preocupante

### O `packs/dracula/` inteiro, hoje

```
packs/dracula/
  pack.json                  4.051 bytes
  paleta.json                3.213 bytes
  icones/apps.map
  icones/apps/               18 SVG
  icones/pastas/              7 SVG
```

**28 arquivos.** É tudo. O que **não** está ali, e é do Dracula:

| do Dracula, mas fora do pack | onde está hoje |
|---|---|
| os dois temas do COSMIC gerados | `assets/temas/meowsystem-dracula-mauve.ron`, `meowsystem-alucard-mauve.ron` |
| o tema capturado de referência | `assets/temas/capturados/dracula-mauve/` |
| os papéis de parede | baixados de um repositório nomeado no `meow.conf` (`WALLPAPER_DRACULA_REPO`) — nenhum fica no pack |
| o ponteiro | não existe; `pack.json` declara `origens.cursores.herda: "catppuccin"` |
| o som | existe como **cinco números** dentro do `pack.json` — não como arquivo |
| a capa, a descrição, a licença de arte | não existem |

### O `packs/catppuccin/` não existe

```
scripts/pack.py:86      PACK_EMBUTIDO = "catppuccin"
scripts/pack.py:91      os.path.join(RAIZ, "assets", "paleta", "catppuccin.json")
```

O pack padrão do projeto **é uma constante em Python**, apontando para um JSON
dentro de `assets/`. Por isso `meow pack listar` precisa de uma linha especial,
que o próprio código admite:

> *"O embutido não tem pack.json e não aparece na varredura — mas existe, e
> esconder isso faria a lista mentir por omissão."* (`bin/meow:3221`)

E o acervo dele — **3.281 arquivos** (413 KB versionados; o `du` diz 13 MB
porque são milhares de SVG minúsculos num bloco de 4 KB) — mora em
`assets/icones/catppuccin/`, ao lado dos acervos que são do motor.

**`assets/paleta/catppuccin.json` é citado por nome em 20 arquivos**, dos quais
**dez são código**: `install.sh`, `lib/comum.sh`, `scripts/pack.py`,
`scripts/gerar_temas.py`, `scripts/gerar_icones_autorais.py`,
`scripts/icones_apps_arcticons.sh`, `scripts/folha_proposta.py`,
`scripts/folha_marcas.py`, `app/pagina/estilo.css` e o
`assets/icones/apps-convertidos.map`. Cada um desses é um lugar onde um pack de
terceiro **não chega**.

### `assets/` hoje mistura três coisas que não são a mesma

| o que é | exemplos | de quem deveria ser |
|---|---|---|
| **motor** — molde, vocabulário, ferramenta | `assets/paleta/cosmic-map.json`, `assets/fastfetch/config.jsonc`, `assets/prompt/starship.toml` | do projeto |
| **tema** — o que muda quando você troca de pack | `assets/paleta/catppuccin.json`, `assets/icones/catppuccin/` (3.281 arq), `assets/temas/*.ron` (7 arq, dois packs misturados) e `capturados/` (881 arq) | **do pack** |
| **saída gerada, versionada** | `assets/temas/meowsystem-*.ron`, `assets/temas/capturados/` | de ninguém: é produto de build |

A prova mais clara de que a fronteira não existe: **`assets/temas/` tem sete
`.ron` de dois packs diferentes no mesmo diretório**, com o nome do flavor
cravado no nome do arquivo — `mocha`, `macchiato`, `frappe`, `latte` (do
Catppuccin) ao lado de `dracula` e `alucard` (do Dracula). Um terceiro pack
despeja os dele no mesmo lugar, e a partir daí ninguém sabe de quem é o quê.

### A regra que falta, e que estas sprints instalam

> **`assets/` guarda o que o MeowSystem é. `packs/<id>/` guarda o que ele
> veste.** Se um arquivo muda quando você troca de pack, ele não pode morar em
> `assets/`. Se ele é gerado, não pode ser versionado em nenhum dos dois.

---

# P13 — O Catppuccin deixa de ser código e vira pack

**A queixa:** *"deveríamos ter um theme do catppuccin, um pack disso também.
mas não temos nada."* E: *"catppuccin vem por default, mas o user pode criar o
dele e usar um dracula da vida."*

### O que medi

`scripts/pack.py:86` e `:91` (acima). Mais os dez pontos de código que citam
`assets/paleta/catppuccin.json` por nome. Enquanto o pack padrão for uma
constante, **todo pack de terceiro é cidadão de segunda classe** — e o Dracula
já é a prova: ele herda sete categorias do "embutido" porque não há como
declarar as dela.

### O que fazer

1. **Nasce `packs/catppuccin/`**, com a mesma estrutura que `packs/dracula/`
   tem hoje:
   ```
   packs/catppuccin/
     pack.json          nome, autor, licença, créditos, capa, descrição (P15)
     paleta.json        <- move de assets/paleta/catppuccin.json
     icones/apps/       <- move de assets/icones/catppuccin/apps/
     icones/pastas/
     icones/mimetypes/  <- os 656 x 4 flavors
   ```
2. **`PACK_EMBUTIDO` deixa de ser o nome de um tema e passa a ser um
   caminho:** `PACK_PADRAO = "packs/catppuccin"`. O padrão continua sendo o
   Catppuccin — o que muda é que ele passa a ser **um pack como os outros**, e
   não uma exceção no código.
3. **Os dez pontos que citam o JSON pelo nome passam a perguntar ao
   resolvedor:** `pack.paleta_do_pack_ativo()`. Nenhum arquivo de código volta a
   conter a palavra `catppuccin` como caminho. O teste cobra isso.
4. **`bin/meow:3221` perde a linha especial.** `meow pack listar` varre o disco
   e acha os dois, porque os dois são iguais. A linha que o código chamava de
   "esconder faria a lista mentir por omissão" deixa de ser necessária, que é
   uma resposta melhor que a de hoje.
5. **`docs/PACKS.md` deixa de dizer "o pack embutido"** e passa a dizer "o pack
   padrão, `catppuccin`, que acompanha o projeto e pode ser trocado". A
   diferença não é de palavra: é a promessa de que o formato descreve **todos**
   os temas, inclusive o de casa.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `packs/catppuccin/` | **novo** — recebe a paleta e o acervo |
| `scripts/pack.py` | `PACK_EMBUTIDO` sai; `PACK_PADRAO` entra; o resolvedor |
| `install.sh`, `lib/comum.sh` | passam pelo resolvedor |
| `scripts/gerar_temas.py`, `scripts/gerar_icones_autorais.py`, `scripts/icones_apps_arcticons.sh`, `scripts/folha_proposta.py`, `scripts/folha_marcas.py` | idem |
| `app/pagina/estilo.css` | a referência à paleta sai para `/paleta.css`, que o servidor já gera |
| `bin/meow` | `cmd_pack listar` perde a exceção |
| `assets/icones/apps-convertidos.map` | o caminho cravado sai |
| `docs/PACKS.md` | "embutido" vira "padrão" |
| `tests/pack.sh` | a conferência (abaixo) |

### Como conferir

```sh
# 1. o Catppuccin aparece na varredura, como qualquer pack
meow pack listar          # espera: "catppuccin — Catppuccin" vindo do DISCO,
                          # sem a linha meow_info especial

# 2. nenhum arquivo de código cita o pack padrão pelo nome
grep -rn "paleta/catppuccin.json" install.sh lib/ scripts/ app/ bin/
# espera: nenhuma linha

# 3. o Catppuccin valida com as mesmas regras do Dracula
meow pack validar catppuccin   # sai 0
```

### O que pode dar errado

- **`git mv` de 3.281 arquivos** vai encher o histórico. Vale um commit só,
  isolado, com `--find-renames`, e nada mais dentro dele.
- **O `catppuccin.json` é citado em nove documentos** (`docs/`, `meow.conf.exemplo`).
  Documento que descreve o passado (as sprints antigas) **não se reescreve**: a
  frase de hoje vai no `docs/PACKS.md`, e as sprints antigas ficam como estão.
  Reescrever histórico para parecer coerente é o defeito que o `docs/SPRINTS.md`
  já registra duas vezes.
- **Ordem obrigatória:** P13 antes de P14. Mover o conteúdo antes de existir o
  pack que o recebe é ficar sem os dois.

---

# P14 — Tudo do tema mora dentro do pack

**A queixa:** *"aqui deveria ter tudo do theme dracula ... preciso que vc
escreva as sprints pra reordenarmos os arquivos pra eles funcionarem
modularizado."*

### O que medi

> **CORREÇÃO DE 21/09, e ela muda a justificativa desta sprint.** A primeira
> versão deste texto media o **disco** e concluía que o repositório tinha 96 MB
> de acervo de terceiro versionado. **Falso.** Medido com `git ls-files`:
>
> | o que eu disse | o que o git diz |
> |---|---|
> | `assets/icones/upstream/` = 21.893 arquivos, 96 MB versionados | **0 arquivos versionados.** Já está ignorado em `.gitignore:3`, e `scripts/baixar_upstream.sh` está do outro lado. **O problema não existe** |
> | `assets/icones/catppuccin/` = 13 MB | 3.281 arquivos e **413 KB**. O `du` mentiu pelo bloco de 4 KB: são milhares de SVG minúsculos |
> | o clone cairia de ~115 MB para ~19 MB | **o clone inteiro tem 13,34 MiB** |
>
> **Peso não é o problema, e o passo 4 da lista abaixo foi apagado.** O que
> sobra — e é o que importava desde o início — é **fronteira**: quem é dono de
> qual arquivo. Um `git filter-repo` não se paga: o histórico morto inteiro são
> 1,75 MB, e 1,59 MB disso é uma renomeação.

A tabela das três coisas misturadas em `assets/`, agora **medida no git**:

| diretório | arquivos no git | de quem é |
|---|---|---|
| `assets/icones/catppuccin/` | 3.281 (413 KB) | **do pack Catppuccin** |
| `assets/temas/*.ron` | 7 | **saída gerada**, de dois packs, no mesmo diretório |
| `assets/temas/capturados/` | **881** | referência de captura, de packs diferentes — e é muito mais do que os 7 `.ron` que eu tinha visto |
| `assets/icones/autorais/` | 63 | do motor (o traço MeowSystem) |
| `assets/icones/arcticons*`, `convertidos-apps`, `resgatados` | 166 | do motor (acervos de apoio) |
| `assets/gatos/`, `assets/fastfetch/`, `assets/prompt/`, `assets/paleta/cosmic-map.json` | 13 | do motor |
| `assets/icones/upstream/` | **0** | já ignorado; nada a fazer |

**O par mais fácil de errar:** `assets/paleta/cosmic-map.json` é **motor** e
`assets/paleta/catppuccin.json` é **tema**. São irmãos no mesmo diretório e vão
para lados opostos da fronteira.

### O que fazer

**A árvore depois desta sprint:**

```
assets/                       o que o MeowSystem É
  paleta/cosmic-map.json      o molde (sem hex nenhum dentro)
  icones/autorais/            o traço do projeto
  icones/arcticons*/          acervos de apoio do motor
  icones/convertidos-apps/
  icones/resgatados/
  gatos/                      a marca
  fastfetch/  prompt/         moldes de configuração
  temas-de-apps/              contrato próprio, fica

packs/                        o que o MeowSystem VESTE
  catppuccin/                 (nasce em P13)
    pack.json  paleta.json  capa.svg  LEIA-ME.md
    icones/{apps,pastas,mimetypes}/
    temas/capturado/          a referência de captura dele
  dracula/
    pack.json  paleta.json  capa.svg  LEIA-ME.md
    icones/{apps,pastas}/
    cursores/                 (a porta que P12 abre)
    temas/capturado/

~/.local/state/meowsystem/    o que é GERADO — e some do git
  temas/*.ron                 <- saem de assets/temas/
  upstream/                   <- saem de assets/icones/upstream/ (96 MB)
```

Cinco movimentos, nesta ordem:

1. **O acervo do Catppuccin desce para `packs/catppuccin/`** (é o fim de P13).
2. **Os `.ron` gerados saem do git.** Eles são saída de `scripts/gerar_temas.py`
   a partir da paleta e do `cosmic-map.json`. Versionar saída gerada é o que
   permite que o disco e a receita divirjam — e o `docs/SPRINTS.md` já registra
   exatamente esse defeito (*"o doctor enxerga receita diferente de produto"*).
   Passam a ser gerados em `~/.local/state/meowsystem/temas/`, e o `meow doctor`
   confere receita contra produto em vez de confiar no arquivo versionado.
3. **Os capturados vão cada um para o seu pack** (`packs/<id>/temas/capturado/`).
   Hoje `assets/temas/capturados/` tem cinco diretórios de packs diferentes,
   mais o `original`, que é da máquina e vai para `~/.local/state/`.
4. ~~`assets/icones/upstream/` sai do repositório.~~ **APAGADO** — ele já está
   fora (`.gitignore:3`, 0 arquivos versionados). Era um passo baseado em
   medição de disco.
5. **O resolvedor de caminho vira um só.** Toda leitura de acervo passa por
   `pack.caminho(categoria)`, que procura, nesta ordem: o pack ativo, o pack de
   quem ele herda, o motor. É o que `docs/PACKS.md` já descreve em prosa e que
   hoje cada script implementa do seu jeito.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `scripts/pack.py` | `caminho(categoria)`, a ordem de resolução |
| `scripts/gerar_temas.py` | escreve em `~/.local/state/`, não em `assets/` |
| `scripts/capturar_tema.sh` | grava no pack, não em `assets/temas/capturados/` |
| `scripts/baixar_upstream.sh` | passa a ser obrigatório no primeiro install; `upstream.lock` |
| `scripts/icones_*.sh` (11 arquivos) | passam pelo resolvedor |
| `install.sh` | a etapa que baixa o upstream antes das de ícone |
| `.gitignore` | `assets/icones/upstream/`, `assets/temas/*.ron` |
| `lib/desinstalar.sh` | os caminhos novos entram nas **duas** listas |
| `docs/PACKS.md`, `docs/FRONTEIRA.md` | a regra `assets/` contra `packs/` |
| `tests/arvore.sh` | **novo** (abaixo) |

### Como conferir

```sh
# 1. o teste da fronteira: nada de tema em assets/, nada de gerado no git
./tests/arvore.sh
#    falha se achar um arquivo em assets/ cujo nome case com um flavor conhecido,
#    ou um .ron versionado, ou assets/icones/upstream/ com conteúdo

# 2. nenhum arquivo de tema ficou em assets/, e nenhum gerado no git
git ls-files assets/temas | wc -l          # antes: 888 · depois: 0
git ls-files packs/ | wc -l                # cresce na mesma medida

# 3. e o tema continua saindo igual — a prova que importa
meow pack usar dracula && meow doctor    # 55 conferências, nenhuma divergente
```

### O que pode dar errado

- **Esta é a sprint que mais pode quebrar a máquina dela.** São cinco
  movimentos e onze scripts. Ela roda **depois** de P8 (o ensaio), e a primeira
  passagem é em seco, obrigatoriamente.
- **`lib/desinstalar.sh` tem de acompanhar.** A regra *"toda unidade nova entra
  nas DUAS listas"* já foi violada três vezes segundo o `docs/SPRINTS.md`. Aqui
  não são unidades novas, são caminhos mudados — o mesmo erro com outra roupa.
- **Os 881 arquivos de `capturados/` não são todos descartáveis.**
  `assets/temas/capturados/original/` é o que `meow desfazer` restaura, e é o
  molde do `gerar_tema_v1.py`. O `capturar_tema.sh:67` **recusa recapturá-lo**
  — fora do git, ele é irrecuperável. Esse diretório fica, e vai para
  `~/.local/state/` só a cópia da máquina, nunca o molde.

---

# P15 — O pack tem cara: capa, descrição, metadados

**A queixa:** *"com imagem de capa (svg) e afins. além de descrição e tudo
mais."*

### O que medi

O `packs/dracula/pack.json` tem `nome`, `versao`, `autor`, `licenca` e
`creditos`. **Não tem capa, não tem descrição, não tem tag, não tem
captura de tela.** A tela que P10 desenha — um cartão por pack, para escolher —
não tem o que desenhar: hoje, um pack é um `id` e 26 hexadecimais.

Ninguém escolhe um tema por um `id`.

### O que fazer

1. **`pack.json` ganha o bloco `vitrine`:**
   ```json
   "vitrine": {
     "capa": "capa.svg",
     "descricao_curta": "O roxo do Dracula, com o gato do MeowSystem.",
     "descricao": "LEIA-ME.md",
     "tags": ["escuro", "roxo", "alto contraste"],
     "capturas": ["capturas/area-de-trabalho.png", "capturas/terminal.png"],
     "site": "https://draculatheme.com"
   }
   ```
   - **`capa` é SVG**, e é obrigatória. Vetor porque o cartão aparece em quatro
     tamanhos na tela e porque um PNG de capa envelhece junto com a resolução.
   - **`descricao_curta` tem teto de 80 caracteres** — o mesmo teto dos balões
     de P6, pelo mesmo motivo.
   - **`descricao` aponta para um Markdown dentro do pack**, para quem quiser
     contar a história. Ele é **renderizado como texto, nunca como HTML** — um
     pack é dado, e dado não injeta.
2. **Uma capa que ninguém desenhou ainda assim existe:** `meow pack novo` (P11)
   **gera** uma capa a partir da paleta — a tira das 26 cores, o acento em
   destaque, o nome. Feia e honesta é melhor que ausente, e quem quiser trocar
   troca o arquivo.
3. **O cartão de pack da Home (P10) passa a mostrar:** capa, nome, autor,
   descrição curta, as tags, e uma linha **"próprio: paleta, ícones, som ·
   herdado do catppuccin: ponteiro, mimetypes"** — que é o `meow pack info` que
   já existe, virado uma linha.
4. **A validação cobra a vitrine:** `meow pack validar` recusa capa ausente,
   capa que não é SVG, capa fora do pack, descrição acima do teto, e URL que
   não seja `https://`. As mesmas regras de sempre, aplicadas ao bloco novo.
5. **`docs/PACKS.md` ganha a seção "A vitrine"**, e o pack mínimo do topo do
   documento passa a ter três arquivos: `pack.json`, `paleta.json`, `capa.svg`.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `scripts/pack.py` | o bloco `vitrine`, a validação, a capa gerada |
| `packs/dracula/pack.json`, `packs/dracula/capa.svg`, `packs/dracula/LEIA-ME.md` | a vitrine do Dracula |
| `packs/catppuccin/` | idem |
| `app/servidor.py` | a vitrine entra em `/api/packs`; a capa é servida |
| `app/pagina/app.js` | o cartão de pack |
| `docs/PACKS.md` | a seção nova |
| `tests/pack.sh` | a conferência da vitrine |

### Como conferir

```sh
meow pack info dracula | head -6
# espera: nome, autor, descrição curta, tags, e "próprio / herdado" em uma linha

meow pack validar dracula     # sai 0, com capa.svg presente
# e, tirando a capa: sai 2, dizendo qual arquivo falta
```

### O que pode dar errado

- **Descrição em Markdown é uma porta.** Renderizar Markdown de terceiro numa
  página com token de sessão é risco real. A regra é dura: **texto puro**, num
  `<pre>`, sem interpretar nada. Quem quiser negrito, escreve no site dele.

---

# P16 — A paleta entra por JSON ou CSV

**A queixa:** *"a ideia é darmos via json ou csv um theme completo."*

### O que medi

`docs/PACKS.md` exige `paleta.json` com `ordem_canonica`, `claros`, `nomes` e
`flavors` — um JSON aninhado de quatro níveis. Para quem programa, é natural.
Para o designer que ele descreve, a tarefa real é outra: **ele tem 26 cores
numa coluna do Figma** e quer que elas virem tema.

E o projeto já sabe que o gargalo é esse: o `docs/PACKS.md` dedica três regras
e um método inteiro só a explicar como derivar o flavor claro.

### O que fazer

1. **`paleta.csv` passa a ser aceito no lugar de `paleta.json`.** Uma linha por
   cor, colunas fixas:
   ```csv
   slot,flavor,hex
   base,dracula,#282A36
   text,dracula,#F8F8F2
   mauve,dracula,#BD93F9
   ```
   Os 26 slots são os que `docs/PACKS.md` já lista. Slot desconhecido é erro
   com o nome da linha; slot faltando é erro com a lista do que falta.
2. **`meow pack novo --de-csv <arquivo>`** monta o pack a partir disso: valida,
   deriva o que puder, e escreve o `paleta.json` equivalente. **O CSV é entrada,
   o JSON continua sendo a forma canônica** — um formato de leitura, um de
   escrita, e nenhuma ambiguidade sobre quem manda.
3. **Se o CSV traz só um flavor escuro, o claro é derivado** pelo método das
   três regras que o `docs/PACKS.md` já documenta (matiz do tema, luminância e
   saturação do Latte, matiz do `base` onde o slot é quase neutro). O pack novo
   nasce com o claro e **diz que ele foi derivado**, não fingido.
4. **A conferência de contraste roda na importação**, com as réguas que o
   documento já fixa: `text` sobre `base` no mínimo 7:1, e nenhum slot pior que
   o Latte no mesmo slot. Reprovação **não bloqueia** — avisa, com a lista do
   que reprovou. A régua é do projeto; a decisão é de quem fez o tema.
5. **A tela também aceita:** o "Importar um pack" de P11 aceita um `.csv`
   solto, não só um `.meowpack`. Vinte e seis linhas e o tema existe.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `scripts/pack.py` | o leitor de CSV, a derivação do claro, a régua de contraste |
| `bin/meow` | `pack novo --de-csv` |
| `app/servidor.py` | `/api/pack-importar` aceita `text/csv` |
| `app/pagina/app.js` | o seletor aceita `.csv` |
| `docs/PACKS.md` | a seção "Começar por um CSV", antes da seção das 26 cores |
| `tests/pack.sh` | CSV de 26 linhas, pack válido no fim |

### Como conferir

```sh
meow pack novo meu-tema --de-csv /tmp/minhas-cores.csv
meow pack validar meu-tema        # sai 0
meow pack info meu-tema | grep -i claro
# espera: "claro: derivado do escuro pelo método do Latte (não é próprio)"
```

### O que pode dar errado

- **Derivar o claro é opinativo, e o `docs/PACKS.md` sabe disso** — o próprio
  documento conta que a primeira tentativa do Dracula saiu `#BDC6FF`, um azul
  forte, e reprovou em 14 acentos. O derivado precisa dizer na cara que é
  derivado, e a tela precisa deixar trocar.
- **CSV não carrega acervo.** Um pack feito de CSV tem paleta e nada mais —
  ícones, ponteiro e papel de parede continuam vindo por herança. Isso é
  legítimo (é o que o Dracula faz com sete categorias), mas a tela tem de
  mostrar, ou a pessoa acha que ganhou menos do que ganhou.

---

# P18 — Os temas de aplicativo obedecem ao pack

**A queixa, e é a pergunta certa:** *"tanto ele quanto o qBittorrent. E o ponto
é: por que ou não aplicou, ou por que o log mentiu?"*

**A resposta medida: as duas coisas, e por uma causa que nenhum dos dois
revela.** O tema já estava aplicado — em Dracula — e o MeowSystem não sabe
olhar.

### O que medi, nesta máquina, em 21/09/2026

**Spotify.** Instalado, patchado, e **já tematizado**:

```
~/.config/spicetify/config-xpui.ini
    current_theme  = Sleek
    color_scheme   = Dracula
    inject_css     = 1
~/.local/share/flatpak/.../spotify/Apps/xpui        <- existe: o app ESTÁ patchado
~/.config/spicetify/Themes/                         <- 20 temas, e nenhum "catppuccin"
```

O módulo exige o tema `catppuccin` do spicetify como pré-condição
(`manifesto.sh:461-465`), não acha, devolve `SEM_DEPENDENCIA`, e a camada de
cima imprime *"Spotify não instalado (ou não é o flatpak de usuário)"*.

**qBittorrent.** Também já tematizado, e por ele mesmo:

```
~/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent/qBittorrent.conf
    General\UseCustomUITheme     = true
    General\CustomUIThemePath    = /home/andrefarias/.themes/dracula.qbtheme
    Advanced\useSystemIconTheme  = false

~/.themes/dracula.qbtheme        4.468 bytes, escrito em 21/09/2026 16:49 (por ele)
```

E o que o módulo traz é **um arquivo só**:
`assets/temas-de-apps/qbittorrent/catppuccin-mocha.qbtheme`. Ele se declara
bloqueado por um script de outro projeto
(`~/.config/zsh/scripts/aurora-qbittorrent-config.sh`, que não existe aqui) e
diz *"não há quem escreva o qBittorrent.conf"* — **enquanto o conf já está
escrito**, com um tema que o MeowSystem não conhece.

**Obsidian é a prova pelo avesso.** Esse "funcionou": o log diz *"obsidian:
Catppuccin Mocha já estava aplicado"*. Numa máquina cujo pack ativo é o
**Dracula**. O módulo que dá certo é o que está mais errado — ele aplicou o
tema do outro pack e chamou de sucesso.

### A causa, em um número

```
módulo            citações de "catppuccin"   lê o pack ativo?
btop-bat                    58                     não
heroic                     246                     não
obsidian                    48                     não
qbittorrent                 28                     não
spotify                     39                     não
toolkits-gtk-qt              5                     não
vscode                      19                     não
zapzap                       3                     não
                        ------                 --------
                           446                  0 de 8
```

**`assets/temas-de-apps/` é anterior ao sistema de packs e nunca soube que ele
existe.** Os oito módulos são, na prática, "aplicadores de Catppuccin" — e é
literalmente a frase dele sobre o projeto inteiro, encontrada num subsistema:
*"o programa original foi feito não pensando em um produto mas em aplicar o
tema catppuccin."*

Daí as três respostas, que são a mesma:

| pergunta dele | resposta |
|---|---|
| não aplicou? | **não aplicou** — o módulo só sabe aplicar o Catppuccin, e o pack ativo é o Dracula |
| o log mentiu? | **mentiu** — e duas vezes: escondeu a causa (P3) e afirmou o que é falso |
| e o que nenhum dos dois conta | **o tema já estava aplicado, em Dracula**, por fora. O módulo confere a própria receita, nunca o estado da máquina |

### O que fazer

1. **Todo módulo passa a perguntar ao pack qual tema aplicar.** Nasce o
   contrato: `meow_app_tema_do_pack <categoria>` devolve o que o pack ativo
   declara para aquele aplicativo, ou o que ele herda. O módulo deixa de
   conhecer a palavra `catppuccin`.
2. **`pack.json` ganha o bloco `apps`:**
   ```json
   "apps": {
     "spotify":     {"spicetify_tema": "Sleek", "esquema": "Dracula"},
     "qbittorrent": {"arquivo": "apps/dracula.qbtheme"},
     "obsidian":    {"tema": "Dracula"},
     "btop":        {"arquivo": "apps/dracula.theme"}
   }
   ```
   Pack que não declara um app **herda**, e o log diz de quem herdou — a mesma
   disciplina que `origens` e `icones` já usam.
3. **Antes de aplicar, o módulo LÊ O QUE ESTÁ NO AR.** Três saídas possíveis, e
   as três aparecem na tela:
   - **já está no tema do pack** -> nada a fazer, e diz qual;
   - **está num tema que não é do pack** -> *"o qBittorrent está em
     `dracula.qbtheme`, que não veio daqui. Trocar pelo do pack?"* — **pergunta,
     não sobrescreve**;
   - **está sem tema** -> aplica.

   Hoje nenhum dos oito faz a segunda, e é por isso que o trabalho que ele já
   tinha feito à mão ficou invisível para o programa.
4. **O Dracula ganha os arquivos que faltam.** `packs/dracula/apps/` recebe o
   `dracula.qbtheme` (o que está em `~/.themes/`, com procedência registrada) e
   o que mais existir. Hoje o pack declara som e paleta e **nenhum tema de
   aplicativo** — é a nona categoria ausente, e não estava na tabela de P12.
5. **A dependência do Aurora sai** (já é item de P2, eixo I). Com o tema vindo
   do pack, o escritor do `.conf` é deste projeto ou a etapa declara
   honestamente que não escreve conf.
6. **O teste:** nenhum arquivo de `assets/temas-de-apps/` pode conter a palavra
   `catppuccin` fora de um comentário histórico. Hoje são 446 ocorrências; o
   teste fixa o teto em zero para código.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `lib/comum.sh` | `meow_app_tema_do_pack`; o contrato de "ler antes de escrever" |
| `assets/temas-de-apps/*/manifesto.sh` (8) | o tema vem do pack; a leitura do estado real |
| `scripts/pack.py` | o bloco `apps` e sua validação |
| `packs/dracula/pack.json`, `packs/dracula/apps/` | os temas de aplicativo do Dracula |
| `packs/catppuccin/apps/` | os de hoje, movidos de `assets/temas-de-apps/*/` |
| `docs/PACKS.md` | a seção "Temas de aplicativo" |
| `tests/temas-de-apps.sh` | o teto de zero, e a conferência das três saídas |

### Como conferir

```sh
# 1. com o pack Dracula no ar, nenhum módulo aplica Catppuccin
meow pack usar dracula && ./install.sh --uma-passagem 2>&1 | grep -ci catppuccin
# antes: o obsidian anuncia "Catppuccin Mocha já estava aplicado" · depois: 0

# 2. o estado real é lido, e dito
./install.sh --uma-passagem 2>&1 | grep -iE "qbittorrent|spotify"
# espera, para cada um: ou "já está no tema do pack", ou "está em <x>, que não
# veio daqui — trocar?", ou "apliquei". Nunca "não instalado" para um app instalado.

# 3. o teto, e ele vale para CÓDIGO, não para a história
#    O `grep -r` prefixa `arquivo:`, então o filtro `grep -v '^\s*#'` é inerte:
#    ele nunca casa. Medido em 22/09: o pipeline literal devolve 124, das quais
#    97 são comentário — que o item 6 desta mesma sprint manda PRESERVAR.
#    A régua certa tira o prefixo antes de julgar:
grep -rn catppuccin assets/temas-de-apps/ --include=manifesto.sh \
  | sed 's/^[^:]*:[0-9]*://' | grep -vE '^\s*(#|$)' | wc -l
# antes: 27 linhas de código nos seis módulos não migrados · depois: 0
```

> **CORREÇÃO DE 22/09, e o erro era meu.** A conferência original pedia `0` do
> pipeline com `grep -v '^\s*#'`. Esse filtro **nunca dispara** num `grep -r`,
> porque a linha começa com o nome do arquivo. O número não chegaria a zero nem
> com os oito módulos migrados: ele conta a prosa que a sprint protege.

### O que pode dar errado

- **Perguntar antes de sobrescrever muda o contrato do instalador**, que hoje é
  não-interativo e roda em timer. A pergunta não pode travar o timer: fora da
  tela, o caso "tema de terceiro no lugar" vira **pendência acionável** (P2) e o
  arquivo dele fica intocado. Sobrescrever calado o tema que ele escolheu à mão
  seria trocar um defeito por um pior.
- **446 ocorrências em 8 módulos** é trabalho de dias, não de horas. O heroic
  sozinho tem 246. Vale partir: Spotify e qBittorrent primeiro (são os dois que
  ele viu), heroic por último.
- **O `.qbtheme` dele é arte de terceiro.** Entrar no pack exige procedência —
  `assets/temas-de-apps/qbittorrent/PROCEDENCIA.md` já existe e é o molde.

---

# P21 — Usar o programa não pode sujar o repositório

**De onde veio:** uma auditoria do git, em 21/09. **É a sprint que mais atrapalha
o "produto para qualquer um"** — e ela já está doendo em dois usuários reais.

### O que medi

**1. O painel escreve dentro do repositório versionado.** Cinco arquivos e dois
diretórios de SVG, todos rastreados pelo git, são gravados por `app/servidor.py`
enquanto a pessoa usa a interface:

| arquivo | quem escreve | no git? |
|---|---|---|
| `assets/papeis-de-parede/BANIDOS.txt` | `wallpaper.sh` (botão **Tirar**) | sim |
| `assets/papeis-de-parede/lado.tsv` | `wallpaper.sh` (botões **Dia**/**Noite**) | sim |
| `assets/icones/apps-arcticons.map` | `servidor.py:4884` | sim |
| `assets/icones/apps-convertidos.map` | `servidor.py:4819` | sim |
| `assets/icones/jogos-fora.map` | `servidor.py:155` | sim |
| `assets/icones/arcticons-apps/*.svg` + `convertidos-apps/*.svg` | painel, ao gerar desenho | **91 arquivos** |
| `assets/gatos/*.svg` | upload pela tela | sim |

**A prova está no `git status` desta sessão.** Às 17:09 e 17:10 de hoje ele
baniu papéis de parede pelo app; o repositório ficou com `+47` linhas em
`BANIDOS.txt` e `-3` em `lado.tsv`. Ninguém programou nada. **Usar o produto é
um commit pendente.**

**2. E existem dois usuários reais, com repositórios separados:**

```
origin  git@github.com:vitoriamariadb/MeowSystem.git
fork    git@github.com:[REDACTED]/MeowSystem.git
maria   /home/andrefarias/Remotos/Andromeda-OS/home/vitoriamaria/Desenvolvimento/MeowSystem
```

Dois desktops, dois carrosséis de papel de parede, dois conjuntos de jogos.
**Cada `git pull` entre eles é um conflito de merge em arquivos que nenhum dos
dois editou de propósito.**

**3. A defesa existe e é inerte em qualquer clone novo.**

```
.gitattributes:   assets/papeis-de-parede/BANIDOS.txt merge=ours
git config merge.ours.driver  ->  true          (só no .git/config DELE)
grep -rn "merge.ours.driver" install.sh lib/ scripts/   ->  vazio
```

O `merge=ours` do `.gitattributes` **não faz nada** sem o driver registrado, e
**nada no repositório o registra**. Quem clonar tem a declaração e não tem o
mecanismo — que é a pior combinação, porque parece protegido.

**4. Um bug de caminho no `.gitignore`, com risco de licença.**

```
.gitignore:18   assets/fontes/locais/*.otf
.gitignore:19   assets/fontes/locais/*.ttf
diretório real: assets/fontes/fonts/
```

`assets/fontes/locais/` **não existe**. A regra não casa nada. O comentário das
linhas 12-15 existe justamente para manter fora do git binário de fonte com EULA
própria — e uma fonte solta no diretório real **entra no commit**.

### O que fazer

1. **O estado do usuário sai do repositório**, e o padrão fica:
   - `BANIDOS.txt`, `lado.tsv` e os três `.map` ganham um irmão `.padrao`
     **versionado** (o conteúdo de fábrica) e passam a ser escritos em
     `~/.local/state/meowsystem/`.
   - **O `.padrao` tem de existir ANTES de o arquivo sair do git**, ou um clone
     novo instala sem ícone de aplicativo nenhum. Esta é a ordem que não se
     inverte.
   - A leitura vira: estado do usuário, e o `.padrao` como base.
2. **Os 91 SVG gerados pelo painel** saem para
   `~/.local/state/meowsystem/icones/`. Desenho que a pessoa **adota** é outra
   coisa: ele vai para o pack dela (P11), por gesto explícito, não por uso.
3. **O driver de merge é registrado pelo instalador.** Uma linha em
   `install.sh`: `git config merge.ours.driver true` quando o diretório é um
   clone — com a ressalva de que, depois do passo 1, ele vira cinto de
   segurança e não defesa principal.
4. **O `.gitignore` é corrigido** para `assets/fontes/fonts/locais/*` — e o
   conserto é conferido com `git check-ignore -v`, não por leitura.
5. **Um teste cobra a regra:** rodar o painel e executar uma ação de curadoria
   (banir uma imagem) **não pode** mudar `git status`. É a única conferência
   que pega a próxima ocorrência.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `app/servidor.py` | as sete escritas mudam de destino |
| `scripts/wallpaper.sh` | `BANIDOS.txt` e `lado.tsv` |
| `lib/comum.sh` | o resolvedor "estado do usuário, com `.padrao` de base" |
| `assets/.../*.padrao` | **novos** — o conteúdo de fábrica dos cinco |
| `install.sh` | o `git config merge.ours.driver`; a semeadura do estado inicial |
| `.gitignore` | o caminho das fontes; os cinco arquivos e os dois diretórios |
| `lib/desinstalar.sh` | os caminhos novos nas **duas** listas |
| `tests/git-limpo.sh` | **novo** (abaixo) |

### Como conferir

```sh
# a prova: usar o produto não suja o repositório
git status --short > /tmp/antes
meow wallpaper banir ~/.local/share/backgrounds/meowsystem/ativos/<alguma>.jpg
git status --short | diff /tmp/antes -     # espera: sem diferença

# o .gitignore conserta o que prometia
git check-ignore -v assets/fontes/fonts/locais/teste.otf   # espera: casa a regra
```

### O que pode dar errado

- **A ordem do passo 1 é a sprint inteira.** Tirar os três `.map` do git antes
  de existir o `.padrao` deixa todo clone novo sem ícone de aplicativo. É o
  mesmo tipo de inversão que P20 tem entre a ponte e a limpeza do
  `catppuccin.json`.
- **`assets/temas-de-apps/heroic/` tem 240 KB versionados** que o
  `PROCEDENCIA.md` afirma serem o que permite instalar **sem rede**. Isso não é
  sujeira: é decisão de produto, e fica fora desta sprint.
- **O que já está sujo hoje** (o `+47` no `BANIDOS.txt` dele) precisa ser
  commitado ou descartado **antes** da migração, ou vira conflito na primeira
  troca com o outro repositório.

---

# P20 — O `pack.json` promete o que ninguém lê

**De onde veio:** uma varredura de acoplamento ao Catppuccin, em 21/09.
**Ela derruba a premissa com que P10 foi escrita** — eu havia afirmado que "o
formato de pack já é bom". Ele é bem escrito. Ele não é lido.

### O que medi

**1. Campos declarados pelo Dracula e sem um único leitor em código:**

```
grep -rn "nome_da_paleta" --exclude-dir=.git .
  docs/PACKS.md:183          <- a spec
  docs/PACKS.md:210          <- a spec explicando o campo
  packs/dracula/pack.json:29 <- a declaração
  (nenhum arquivo de código)
```

A mesma varredura vale para `cosmic.mapa`, `icones.*.herda`,
`icones.apps.camada`, `origens.cursores.*`, `origens.wallpapers.*` e
`claro_de_reserva`.

**2. E a consequência está gravada no disco:**

```
assets/temas/meowsystem-dracula-mauve.ron:8:   name: "catppuccin-dracula",
assets/temas/meowsystem-alucard-mauve.ron:8:   name: "catppuccin-alucard",
```

O `packs/dracula/pack.json:29` declara `"nome_da_paleta": "dracula-<flavor>"`
**exatamente para impedir isto**, e o comentário ao lado diz por quê: *"o molde
crava `catppuccin-<flavor>` (cosmic-map.json:4), o que faria este tema aparecer
como `catppuccin-dracula` na GUI"*.

**É o que está acontecendo.** O pack previu o defeito, declarou o conserto, e o
conserto não tem leitor. Na GUI do COSMIC, o tema Dracula dele se chama
`catppuccin-dracula`.

**3. A fronteira já rompeu no arquivo:**

```
python3 -c "import json;print(list(json.load(open('assets/paleta/catppuccin.json'))['flavors']))"
['latte', 'frappe', 'macchiato', 'mocha', 'dracula']
```

**O `dracula` está dentro do `catppuccin.json`.** É por isso que o pack Dracula
"funciona" hoje: não é herança, é uma cópia enfiada no arquivo do outro pack. E
`alucard` — o flavor claro do Dracula — **não está lá**, o que significa que
`meowsystem-alucard-mauve.ron` foi gerado de outra fonte. Saída versionada sem
receita que a reproduza.

**4. O Python nunca recebe a paleta do pack.** `meow_paleta()`
(`lib/comum.sh:112`) consulta o diretório do pack — mas é função de **shell**.
Os consumidores em Python (`gerar_temas.py`, `gerar_icones_autorais.py`,
`app/servidor.py`, `folha_conversor.py`, `folha_marcas.py`,
`folha_proposta.py`) resolvem sozinhos por `$MEOW_PALETA` → `$PALETA_ARQUIVO` →
`catppuccin.json`. E **`MEOW_PALETA` não é exportado por ninguém**: nem
`install.sh`, nem `bin/meow`, nem `app/run.sh`.

Ou seja: **a ponte entre o shell e o Python não existe.** Todo consumidor
Python cai no fallback, sempre.

**5. Achados colaterais da mesma varredura:**

| achado | prova |
|---|---|
| `packs/dracula/CREDITOS.md` é declarado e **não existe** | `pack.json` diz `"creditos": "CREDITOS.md"`; o arquivo não está lá — e `meow pack validar dracula` passa |
| `assets/icones/catppuccin-apps/` **não existe** | e o log dele diz *"o acervo Catppuccin de aplicativos não está em `assets/icones/catppuccin-apps/macchiato`"*. O acervo está em `assets/icones/catppuccin/` (3.281 arquivos). O código procura um caminho que nunca existiu |
| **quatro cópias à mão** da lista de raízes de pack | `pack.py:58`, `comum.sh:162`, `comum.sh:172`, `servidor.py:709` — e uma quinta, `servidor.py:4866`, que só conhece `RAIZ/packs/` e ignora XDG e `$MEOW_PACKS` |
| **sete padrões distintos** de resolver um acervo | `meow_pack_arquivo` (o certo) tem **2** usuários; o caminho cravado sob `$RAIZ/assets/` tem **12** |

### O que aconteceria com um pack de terceiro

Com `PACK="nord"` e `FLAVOR="nord"`, medido por leitura:

1. `gerar_temas.py` falha duro: `flavor 'nord' desconhecido`.
2. `gerar_icones_autorais.py` levanta `KeyError`.
3. `concluir()` marca as duas em `FALHOS` — **e o instalador segue** para as
   ~48 etapas restantes, contra um tema meio construído.
4. Pastas, mimetypes, agente, papel de parede e painel saem **Catppuccin**, em
   silêncio.

O estranho termina com uma máquina metade Nord, metade Catppuccin, e um log que
diz que duas etapas falharam.

### O que fazer

1. **A ponte shell→Python, primeiro.** `install.sh` e `bin/meow` exportam
   `MEOW_PALETA` e `MEOW_PACK_DIR` antes de chamar qualquer Python. É o
   conserto mais barato desta sprint e o que desbloqueia os outros.
2. **`assets/paleta/catppuccin.json` perde o flavor `dracula`.** Ele passa a
   morar só em `packs/dracula/paleta.json`, onde já está. Isto **só pode
   acontecer depois do passo 1**, ou o Dracula some da máquina dele.
3. **Um resolvedor de acervo, e só um:** o verbo `acervo(categoria, arquivo)`
   em `scripts/pack.py`, que percorre pack ativo → herança → motor.
   **Atenção medida:** o nome `caminho` **já está tomado** —
   `lib/comum.sh:168` o usa como sonda de existência, e reaproveitá-lo faria
   todo script de shell deixar de enxergar o pack, **em silêncio**.
4. **As quatro cópias da lista de raízes viram uma**, e `servidor.py:4866`
   passa a usá-la (hoje ele ignora XDG e `$MEOW_PACKS`).
5. **Os campos sem leitor ganham leitor, um a um**, na ordem do estrago:
   `cosmic.nome_da_paleta` primeiro — é o que faz o tema dele se chamar
   `catppuccin-dracula` na GUI.
6. **`meow pack validar` passa a conferir o que o pack declara**: arquivo
   declarado e ausente é erro (o caso do `CREDITOS.md`), e campo declarado que o
   projeto não lê é **aviso nomeado**, não silêncio. Um formato que aceita
   declaração morta ensina a escrever declaração morta.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `install.sh`, `bin/meow`, `app/run.sh` | exportam `MEOW_PALETA` e `MEOW_PACK_DIR` |
| `scripts/pack.py` | `acervo()`, a lista única de raízes, a validação que cobra o declarado |
| `lib/comum.sh` | as duas cópias da lista de raízes saem |
| `app/servidor.py` | a cópia da linha 709 e a da 4866 |
| `scripts/gerar_temas.py` | lê `cosmic.nome_da_paleta` |
| `assets/paleta/catppuccin.json` | o flavor `dracula` sai (**depois** do passo 1) |
| `packs/dracula/CREDITOS.md` | **novo** — o arquivo que o pack promete |
| `tests/pack.sh` | um pack `nord` de mentira que precisa instalar inteiro ou falhar inteiro |

### Como conferir

```sh
# 1. a ponte existe
MEOW_PALETA=/tmp/nao-existe.json ./install.sh --uma-passagem 2>&1 | grep -i paleta
# espera: erro dizendo que a paleta apontada não existe — prova que o Python a recebeu

# 2. o tema do Dracula tem o nome do Dracula
grep 'name:' ~/.local/state/meowsystem/temas/meowsystem-dracula-mauve.ron
# antes: name: "catppuccin-dracula"  ·  depois: name: "dracula-dracula"

# 3. o pack que mente não valida
meow pack validar dracula     # antes: sai 0 sem CREDITOS.md · depois: sai 2, nomeando o arquivo

# 4. o pack de terceiro instala inteiro, ou para
./tests/pack.sh nord          # nunca "metade Nord, metade Catppuccin"
```

### O que pode dar errado

- **A ordem dos passos 1 e 2 não é negociável.** Tirar o `dracula` do
  `catppuccin.json` antes de a ponte existir apaga o tema da máquina dele.
- **O nome `caminho` está tomado**, e o erro seria mudo. Está escrito acima
  porque é o tipo de coisa que só se descobre depois de quebrar.
- **Esta sprint muda a premissa de P10.** Quem executar P10 sem P20 vai desenhar
  o cartão de pack em cima de campos que ninguém lê.

---

# P19 — A raiz da configuração tem dois idiomas, e um deles é o do teste

**De onde veio:** não é queixa dele — é o achado de uma varredura de
plataforma feita em 21/09, perguntando o que amarra o projeto a uma máquina só.

### O que medi

Existem **duas formas** de dizer onde mora a configuração do COSMIC, e as duas
estão vivas:

| forma | ocorrências | onde |
|---|---|---|
| honra `MEOW_COSMIC_DIR` | **14** (em 10 arquivos) | o caminho que os testes usam |
| crava `$HOME/.config/cosmic` | **23** em código | 12 arquivos, abaixo |

```
3  scripts/logo.sh          2  scripts/construir_icones.sh   1  scripts/painel.sh
3  bin/meow                 2  scripts/coleta-meowsystem.sh  1  scripts/fastfetch_logo.sh
2  scripts/instalar_fontes.sh  2  install.sh                 1  scripts/completar_icones.sh
1  scripts/wallpaper.sh     1  scripts/auditar_icones.sh     1  lib/preflight.sh
```

(Outras 33 ocorrências são comentário e não contam — foram conferidas uma a
uma.)

**O caso que prova que isso já dói:** `lib/preflight.sh:66` crava
`$HOME/.config/cosmic`. É o arquivo **guardião**, o que roda antes de tudo — e
está do lado errado da conta, enquanto `tests/convergencia.sh` roda com
`MEOW_COSMIC_DIR` apontando para outro lugar. Ou seja: **o teste mede uma raiz
e o pré-voo confere outra.**

Uma costura meio construída é pior que nenhuma: quem lê o código vê a variável
e assume que ela é respeitada.

### O que fazer

1. **Um verbo só:** `meow_cosmic_dir()` em `lib/comum.sh`, que devolve
   `${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}`. Não é camada de abstração de
   desktop — é o fim de uma divergência que já existe.
2. **As 23 ocorrências passam a chamá-lo.** Inclusive, e primeiro,
   `lib/preflight.sh:66`.
3. **Uma regra no `tests/estilo.sh`:** `$HOME/.config/cosmic` cravado em código
   é erro. Comentário continua livre — é onde a explicação mora, e reescrevê-la
   seria apagar o porquê.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `lib/comum.sh` | `meow_cosmic_dir()` |
| `lib/preflight.sh`, `bin/meow`, `install.sh` + 9 scripts | as 23 ocorrências |
| `tests/estilo.sh` | a regra nova |

### Como conferir

```sh
grep -rn '\$HOME/\.config/cosmic' scripts/ lib/ bin/meow install.sh \
  | grep -v '^\([^:]*\):[0-9]*: *#' | grep -vc MEOW_COSMIC_DIR
# antes: 23 · depois: 0
./tests/convergencia.sh    # continua verde, agora medindo a mesma raiz que o pré-voo
```

### O que pode dar errado

- **Isto NÃO é o primeiro passo de portar para GNOME.** Ver a seção abaixo. Se
  a sprint for lida como "começo da camada de desktop", ela vai crescer para
  oito verbos que não têm segundo caso de uso — e aí vira o defeito que a
  diretriz do projeto chama de "flexibilidade que não foi pedida".

---

## O veredicto sobre portar para GNOME ou KDE: não

Medido em 21/09: de **89 arquivos executáveis** (`scripts/*.sh`, `scripts/*.py`,
`lib/*.sh`, `bin/meow`), **72 citam COSMIC**. Os 17 que não citam são
conversores de ícone e vigias `.path` — nenhum é uma razão para instalar o
projeto.

O projeto já se declara COSMIC-only e recusa instalar fora dele
(`lib/preflight.sh:42-59`, com rc 2 e a frase *"num GNOME/KDE o resultado é
`~/.config/cosmic/` que ninguém lê"*). A escotilha `MEOW_IGNORA_DESKTOP=1`
existe só para instalar por TTY antes do primeiro login.

**Abrir uma camada `lib/desktop.sh` seria trabalho especulativo:** cerca de
3.000 linhas — painel, vidro, forma, modo de leitura, áreas, greeter, applets,
patches do compositor — **não têm para onde ir** num GNOME. E o tema GTK/Qt,
que hoje vem de graça do `cosmic-settings-daemon`, teria de nascer do zero. Um
`case` com um ramo só é pior que nenhum: ele mente dizendo que existe
alternativa.

**E o "qualquer user" que ele pediu não é o GNOME.** A frase dele é *"qualquer
um possa criar um theme pack completo"* — a resposta está em P10 a P16 e P18,
não numa segunda plataforma. Um estranho com Pop!_OS e COSMIC é o usuário, e
hoje **nem ele** consegue usar um pack que não seja o Catppuccin.

Fica registrado, para não ser reaberto sem medição nova.

---

## Ordem, e a amarração com o outro arquivo

| onda | o que roda | por quê |
|---|---|---|
| A00 | **P21** | o estado do usuário sai do git. **Antes de P14**, que move arquivos: mover o que o app reescreve, sem o `.padrao` no lugar, deixa todo clone novo sem ícone de aplicativo |
| A0 | **P20** (passos 1 e 5), **P19** | a ponte shell→Python e a raiz única. **Vêm antes de tudo**: sem elas, todo consumidor Python cai no `catppuccin.json` e nenhuma migração posterior é observável |
| A | **P13** | sem o Catppuccin como pack, `packs/` tem um morador só e nada prova que o formato serve |
| B | **P14** | a árvore se reordena; exige P13 pronta e P8 (ensaio) para a primeira passagem ser em seco |
| C | **P15**, **P16** | a vitrine e o CSV; as duas são aditivas e podem ir juntas |
| C' | **P18** | os temas de aplicativo. Exige P13 (o pack padrão existir) e P2 do eixo I (a pendência, para o caso "tema de terceiro no lugar"). Spotify e qBittorrent primeiro; o heroic, com 246 citações, por último |
| D | **P10**, **P11**, **P12** (do outro arquivo) | a Home, o exportar/importar e as onze categorias. **Todas dependem de P14** |

A leva de interface (P1 a P9) é **independente** desta e pode correr em
paralelo: nenhuma das quatro toca em `app/pagina/`, a não ser pelo cartão de
pack de P15, que é o último a entrar.

---

## O que NÃO entra, e por quê

- **Reescrever o histórico do git** para apagar os 96 MB de `upstream/`. P14
  para o crescimento; o `git filter-repo` é decisão dele, tem custo para quem
  já clonou, e não cabe dentro de uma sprint que já move onze scripts.
- **Um repositório de packs de terceiros** ("a loja"). Só faz sentido depois de
  P11 estar no ar e alguém de fora ter publicado um `.meowpack`. Até lá, seria
  desenhar uma prateleira antes de existir produto.
- **Migrar as sprints antigas** que citam `assets/paleta/catppuccin.json`.
  Documento que descreve o passado fica como está — o `docs/SPRINTS.md` já
  registra duas vezes o estrago de reescrever histórico para parecer coerente.

---

# P25 — Cada pack tem um logo em SVG, e ele é o ícone do lançador

**A queixa:** *"precisa usar um svg pra cada logo do theme pack, o icon do menu
de lançamento."*

**Isto corrige o mockup de 21/09**, que desenhou a capa do pack como uma tira de
cores. Tira de cor é paleta, não identidade — dois packs de paleta parecida
ficam indistinguíveis no cartão, e um pack não tem cara.

### O que medi

- `packs/dracula/` não tem nenhum SVG de identidade. Tem 18 ícones de
  aplicativo e 7 de pasta — nenhum representa **o pack**.
- `packs/dracula/pack.json` não tem campo para isso (P15 propôs `vitrine.capa`;
  esta sprint diz o que a capa é e para onde mais ela vai).
- A logo do projeto mora em `docs/logo.svg` e os mascotes em `assets/gatos/`
  (6 SVG) — os dois são **do motor**, e continuam sendo. Um pack de terceiro
  não tem onde pôr a cara dele.

### O que fazer

1. **`packs/<id>/logo.svg` passa a ser obrigatório**, e é a identidade do pack:
   ```
   packs/dracula/
     logo.svg          a cara do pack — quadrado, viewBox 0 0 128 128
     logo-mono.svg     opcional: a versão de traço único, para barra e bandeja
   ```
   Quadrado e com `viewBox` porque o mesmo arquivo serve a quatro tamanhos no
   cartão da Home **e** ao lançador, que pede 48, 64, 128 e 256.

2. **As cores do logo saem da paleta, por PAPEL.** É a regra que
   `scripts/gerar_icones_autorais.py` já aplica há meses, no cabeçalho dele:
   *"o desenho nasce da paleta — nenhum hex é digitado aqui"*. Cada forma
   declara `sujeito`, `tinta`, `fundo`; o papel resolve para um dos 26 nomes.
   **É o que faz o logo acompanhar o flavor claro sem redesenho** — no Latte o
   `text` e o `crust` se invertem sozinhos.

3. **O logo alimenta o ícone do lançador.** Com um pack ativo, o `.desktop` do
   MeowSystem passa a apontar para o logo dele, instalado em
   `~/.local/share/icons/hicolor/scalable/apps/meowsystem.svg`. Quem trocar de
   pack vê o ícone do menu de lançamento trocar junto — é o sinal mais barato
   de que a troca aconteceu.

4. **Pack sem logo não fica sem cara.** `meow pack novo` **gera** um: a inicial
   do nome sobre o `base` do pack, com o acento como contorno. Feio e honesto é
   melhor que ausente — a mesma regra de P15 para a capa.

5. **A validação cobra:** SVG de verdade (não PNG renomeado), `viewBox`
   quadrado, sem `<script>`, sem `<image>` embutida, sem URL remota, e todo
   caminho dentro do pack. As regras que `docs/PACKS.md` já declara, aplicadas
   ao arquivo novo.

6. **O cartão da Home (P10/P15) passa a mostrar o logo**, não a tira. A tira
   continua existindo — embaixo do logo, fina, como amostra da paleta.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `packs/dracula/logo.svg` | **novo** — a cara do Dracula |
| `packs/catppuccin/logo.svg` | **novo** (nasce em P13) |
| `scripts/pack.py` | `vitrine.logo`, a validação, o logo gerado |
| `scripts/logo.sh` | o `.desktop` do MeowSystem aponta para o logo do pack |
| `app/servidor.py`, `app/pagina/app.js` | o cartão de pack mostra o logo |
| `docs/PACKS.md` | a seção "O logo do pack" |
| `docs/folhas/folha-sprints-2026-09-21.html` | a capa do mockup vira logo |

### Como conferir

```sh
meow pack validar dracula          # recusa sem logo.svg
meow pack usar catppuccin && ls -l ~/.local/share/icons/hicolor/scalable/apps/meowsystem.svg
# o ícone do lançador troca junto com o pack
```

### O que pode dar errado

- **O lançador cacheia ícone.** O `docs/SPRINTS.md` registra isso duas vezes
  (`lancador-cosmic-cacheia-icones`, 11/08). Trocar o arquivo pode não trocar a
  tela sem `gtk-update-icon-cache` — e é o tipo de coisa que faz parecer que a
  troca de pack não funcionou.

---

# P26 — O acervo do pack é uma origem na oficina de ícone

**A queixa:** *"você viu que os ícones do Dracula, todos os SVGs meus, não
aparecem lá, né? Tudo isso não passou despercebido por você?"*

**Passou.** Eu registrei que `packs/dracula/icones/apps/` tem 18 SVG e não
verifiquei se a oficina os oferece. Verificado agora: não oferece.

### O que medi

**Os 18 SVG do Dracula estão instalados.** Conferi um a um contra
`~/.local/share/icons/MeowSystem-Icons/*/apps/` — **18 de 18 presentes**,
nenhum fora. O pack funciona.

**O que não existe é a origem na tela.** Ao abrir a oficina do Warehouse — que
tem desenho autoral no pack (`io.github.flattool.Warehouse.svg`) — o app diz,
em `app/servidor.py:6302`:

> *"Warehouse já tem desenho convertido do projeto. O traço dele se troca na
> oficina «Gerar ícone», acima."*

A oficina oferece **converter** e **gerar no traço MeowSystem**. Ela não sabe
que existe um desenho autoral do pack para aquele mesmo aplicativo. O acervo do
pack entra no tema pelo `icones_apps_dracula.sh` e **nunca aparece como escolha**.

**E o gerador é de dois aplicativos, cravados.**
`scripts/gerar_icones_autorais.py`, primeira linha:

> *"Desenha os ícones dos DOIS aplicativos da Vitória, a partir da paleta
> canônica: FogStripper — removedor de fundo; Hefesto — gerenciador de
> DualSense."*

É um gerador bom: nasce da paleta, por papel, e sobrevive ao flavor claro. E
serve **dois aplicativos nomeados no código**. Um terceiro não tem como entrar
sem editar Python.

### O que fazer

1. **A oficina passa a listar TODAS as origens que existem para aquele app**,
   como cartões lado a lado — a mesma folha de variações que a Sprint R já
   desenhou:

   ```
   Original   Do pack    Salvo     Fiel      Limpo     Silhueta
   ┌──────┐  ┌══════┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐
   │  48  │  │  48  │  │  48  │  │  48  │  │  48  │  │  48  │
   └──────┘  └══════┘  └──────┘  └──────┘  └──────┘  └──────┘
                ↑ o SVG autoral do pack, que hoje não aparece
   ```

2. **"Do pack" vence por padrão** quando existe. É o desenho que alguém fez à
   mão para aquele aplicativo; a conversão automática é o plano B, não o A.

3. **A frase que trava muda.** Em vez de *"já tem desenho convertido do
   projeto"*, a tela diz de quem é o desenho em vigor e quais são as
   alternativas — incluindo a do pack.

4. **O gerador deixa de nomear aplicativos.** `gerar_icones_autorais.py` passa
   a ler o que desenhar de uma **declaração**, não de duas constantes:
   ```json
   "autorais": {
     "gerar": true,
     "desenhos": "icones/autorais/*.json"
   }
   ```
   Cada `.json` descreve um desenho por papéis (`sujeito`, `tinta`, `fundo`) —
   exatamente o vocabulário que o script já usa internamente. FogStripper e
   Hefesto viram os dois primeiros arquivos, no pack do projeto. **Nenhum
   comportamento muda; o que muda é quem pode acrescentar.**

5. **O painel ganha a oficina de autoral**: escolher os papéis, ver a prévia nos
   quatro fundos, salvar no pack. É o gerador que já existe, com tela.

6. **Um teste amarra:** todo SVG em `packs/<id>/icones/apps/` cujo nome case com
   um `Icon=` da máquina **precisa** aparecer como cartão na oficina daquele
   app. Hoje seriam 18 cartões ausentes; o teste fixa o teto em zero.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `app/servidor.py` | `variacoes` ganha a origem `pack`; `_motivo_da_trava` (6288-6304) |
| `app/pagina/app.js` | o cartão "Do pack" na folha de variações |
| `scripts/gerar_icones_autorais.py` | os dois apps saem do código e viram declaração |
| `packs/catppuccin/icones/autorais/` | **novo** — FogStripper e Hefesto, declarados |
| `scripts/pack.py` | valida `autorais.desenhos` |
| `docs/PACKS.md` | a seção "Desenhos autorais" |
| `tests/oficina.sh` | **novo** — o teto de zero |

### Como conferir

```sh
# 1. o desenho do pack aparece na oficina
#    abrir o painel > Ícones > Warehouse > a oficina
#    espera: um cartão "Do pack", escolhido por padrão

# 2. o teto
./tests/oficina.sh    # 0 SVG de pack sem cartão · hoje: 18

# 3. um terceiro desenho autoral entra sem tocar em Python
cp meu-app.json packs/dracula/icones/autorais/ && meow icones traco
```

### O que pode dar errado

- **"Do pack vence por padrão" muda o que está na tela de quem já instalou.**
  Para os 18 aplicativos do Dracula, o desenho em vigor já é o do pack — então
  não muda nada nesta máquina. Numa máquina onde a conversão está valendo, muda
  — e isso precisa de aviso, não de troca calada.

---

# P27 — Todo ícone que veste alguém mora no pack

**A queixa:** *"aproveitando, os ícones SVG, todos eles, e os mapeamentos que
fizemos anteriormente, onde foram parar? Preciso que centralizemos todos eles
dentro das pastas packs. Todos os ícones que podem fazer parte do theme pack,
tudo tem que ficar lá."*

Esta sprint é o inventário que P14 prometeu e não detalhou: **arquivo por
arquivo, para onde vai e por quê.**

### O número que resume

```
SVG versionados no projeto ......... 3.566
dentro de packs/ ...................... 25   (0,7%)
fora .................................. 3.541
```

**Vinte e cinco de três mil quinhentos e sessenta e seis.** O `packs/dracula/`
tem 18 ícones de aplicativo e 7 de pasta; todo o resto do acervo do projeto
mora em `assets/`.

### E os SVG do Dracula estão em três lugares

```
packs/dracula/icones/apps/       18 SVG   <- os únicos que estão no lugar
packs/dracula/icones/pastas/      7 SVG
assets/icones/autorais/          11 SVG   <- *-dracula.svg, FORA do pack
```

Os onze de `assets/icones/autorais/` são, por nome:

```
cosmic-edit-dracula.svg        cosmic-store-dracula.svg
cosmic-files-dracula.svg       cosmic-term-dracula.svg
cosmic-monitor-dracula.svg     fogstripper-dracula.svg
cosmic-player-dracula.svg      hefesto-dracula.svg
cosmic-screenshot-dracula.svg  meowsystem-painel-dracula.svg
cosmic-settings-dracula.svg
```

O mesmo diretório guarda **onze para cada flavor do Catppuccin** — `mocha`,
`macchiato`, `frappe`, `latte` — 44 no total. São 55 desenhos de dois packs
diferentes, num diretório que se chama `autorais` e não diz de quem.

**E `alucard` tem ZERO.** O flavor claro do Dracula nasceu em 19/09 e nenhum dos
onze foi gerado para ele. No modo claro do Dracula, esses onze ícones caem no
`latte` — que é o claro **do outro pack**. É o mesmo defeito que o
`packs/dracula/pack.json` já tinha corrigido para a paleta e que continua vivo
para os ícones.

### O inventário completo, e o destino de cada um

**VAI PARA O PACK — muda quando você troca de pack:**

| hoje | quantos | destino |
|---|---|---|
| `assets/icones/catppuccin/{mocha,macchiato,frappe,latte}/` | **2.624** SVG | `packs/catppuccin/icones/mimetypes/<flavor>/` |
| `assets/icones/catppuccin/css-variables/` | **656** SVG | `packs/catppuccin/icones/mimetypes/css-variables/` |
| `assets/icones/autorais/*-{mocha,macchiato,frappe,latte}.svg` | **44** | `packs/catppuccin/icones/autorais/` |
| `assets/icones/autorais/*-dracula.svg` | **11** | `packs/dracula/icones/autorais/` |
| `assets/icones/mimetypes.map` | 123 linhas | `packs/catppuccin/icones/mimetypes.map` |
| `assets/icones/sistema.map` | 30 linhas | do pack — é *qual ícone do COSMIC veste o quê* |
| `assets/icones/pastas.map` | 7 linhas | do pack |
| `assets/icones/apps-convertidos.map` | 31 linhas | do pack — **o mapa é a decisão de tema** |
| `assets/icones/apps-resgatados.map` | 22 linhas | do pack |
| `assets/icones/apps-arcticons.map` | 16 linhas | do pack |
| `assets/icones/apps-marca.map` | 13 linhas | do pack |

**FICA NO MOTOR — é ferramenta e acervo de apoio, não muda com o pack:**

| fica | quantos | por quê |
|---|---|---|
| `assets/icones/arcticons/` + `arcticons-apps/` + `previa-arcticons/` | **113** SVG | acervo de terceiro, base de conversão. Um pack *aponta* para ele; não o carrega |
| `assets/icones/convertidos-apps/` + `retoques/` | **50** SVG | saída do conversor sobre o acervo acima, com retoque à mão |
| `assets/icones/resgatados/` | **29** SVG | resgatados do PNG **desta máquina** — são da máquina, não do tema |
| `assets/icones/autorais/leitura/` | 8 SVG | `e1..e4, r1, r2, r6, s3` — sem flavor no nome: são recoloridos em tempo de build |
| `assets/gatos/` | 5 SVG | a marca MeowSystem. P12 abre a porta para o pack trazer os dele; estes continuam sendo os de casa |
| `appid.map`, `wmclass.map`, `jogos-fora.map`, `apps-nomes.map` | 15 linhas | identidade técnica de aplicativo (id de janela, appid da Steam). Não é gosto, é fato da máquina |

**A regra que separa as duas colunas, e ela cabe numa frase:**

> **O mapa é do pack; o acervo pode ser do motor.** Um pack diz *"o Telegram
> veste o desenho X"* — essa é uma decisão de tema, e vai para o pack. O
> desenho X pode vir do acervo Arcticons, que é ferramenta compartilhada e
> fica onde está. O que não pode é a decisão morar em `assets/`.

**Os três mapas vazios ficam, e não são código morto:** `apps.map` (0 linhas,
**9 leitores**), `apps-hicolor.map` (0, 3 leitores) e `bandeja.map` (0, 7
leitores). Vazio-mas-vivo é diferente de morto — o `docs/SPRINTS.md` já registra
que o `apps.map` está vazio desde 10/08 **de propósito**.

### O que fazer

1. **`packs/<id>/icones/` ganha a estrutura completa:**
   ```
   packs/<id>/icones/
     apps.map          apps/         quais aplicativos, e os desenhos
     pastas.map        pastas/
     mimetypes.map     mimetypes/<flavor>/
     sistema.map       sistema/      os ícones do próprio COSMIC
     autorais.map      autorais/     os desenhos do projeto, por flavor
   ```
   Mesma forma para todo pack — o Catppuccin deixa de ser exceção (P13).

2. **Os onze `-dracula.svg` vão para `packs/dracula/icones/autorais/`**, e o
   `alucard` ganha os onze dele. Gerar, não copiar do latte: o gerador já sabe
   derivar por papel, e é o que P26 generaliza.

3. **Um mapa pode apontar para fora do pack**, com prefixo declarado:
   ```
   org.telegram.desktop : motor:arcticons/telegram.svg
   io.github.flattool.Warehouse : apps/Warehouse.svg
   ```
   `motor:` resolve em `assets/icones/`; sem prefixo, dentro do pack. É o que
   permite tirar a decisão de `assets/` **sem** duplicar 113 SVG em cada pack.

4. **`meow pack info` passa a contar o acervo**: *"Dracula: 18 apps, 7 pastas,
   11 autorais (2 flavors), mimetypes herdados do catppuccin"*. Hoje não há como
   saber o tamanho de um pack sem `find`.

5. **Nada é apagado de `assets/` antes de o pack ler do lugar novo.** A ordem é:
   estrutura → resolvedor com `motor:` → mover → apagar. Inverter deixa a
   máquina sem ícone entre dois passos.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `packs/catppuccin/icones/` | **novo** — recebe 3.324 SVG e 5 mapas |
| `packs/dracula/icones/autorais/` | **novo** — os 11, mais os 11 do alucard |
| `scripts/pack.py` | a estrutura, o prefixo `motor:`, a contagem |
| `scripts/icones_*.sh` (11 arquivos) | passam a ler pelo resolvedor |
| `assets/icones/` | perde o que é tema; mantém acervo e mapas técnicos |
| `docs/PACKS.md` | a seção "O acervo de ícones do pack" |
| `tests/pack.sh` | conta 3.566 SVG antes e depois; nenhum some |

### Como conferir

```sh
# 1. nenhum ícone de tema ficou em assets/
git ls-files 'assets/icones/*/*.svg' | grep -cE '(mocha|macchiato|frappe|latte|dracula|alucard)'
# antes: 3.324 · depois: 0

# 2. nenhum SVG desapareceu no caminho
git ls-files '*.svg' | wc -l      # 3.566 antes e depois

# 3. o alucard deixa de cair no tema do outro pack
ls packs/dracula/icones/autorais/ | grep -c alucard     # antes: 0 · depois: 11

# 4. e a máquina continua vestida igual
meow doctor    # 55 conferências, nenhuma divergente
```

### O que pode dar errado

- **3.324 arquivos movidos num commit.** Use `git mv` e deixe o commit sozinho,
  sem mais nada dentro, ou o histórico fica ilegível para sempre.
- **O `css-variables` não é um flavor.** São 656 SVG que usam
  `var(--vscode-ctp-text)` — é o acervo **para o VS Code**, com variável de CSS
  em vez de cor. Tratá-lo como quinto flavor quebra o seletor de variante.
- **Os 29 `resgatados/` são desta máquina.** Eles vieram de PNG que existiam
  aqui. Mandá-los para o pack faria um pack carregar o resgate do desktop de
  outra pessoa — que é a mesma classe de erro do `capturados/original/` (P24).

---

# P28 — A fonte única: um desenho no pack, todo o resto derivado

**A diretriz, dele, 21/09/2026:**

> *"Qual a ideia: unificando tudo em packs dentro do MeowSystem, centralizar os
> SVGs — e alterando lá alteraremos o resto dos ícones que têm eles como base.
> Vamos centralizar ao máximo tudo."*

**E a decisão que a abriu:** o Waterfox passa a usar o **Firefox-Dracula**.

Esta sprint é a espinha de P25, P26 e P27: as três movem arte para o pack; esta
diz **como a arte vira todo o resto** depois que chega lá.

### O que medi, e é o defeito que motivou a diretriz

```
assets/icones/apps-resgatados.map:54
net.waterfox.waterfox : ~/.local/share/icons/Dracula-Icones/scalable/apps/net.waterfox.waterfox.png : terceiro
```

O mapa do projeto manda buscar a arte **num diretório da máquina, fora do
repositório** — o `Dracula-Icones`, que é tema de terceiro e é reescrito de
fora. Aconteceu em 21/09 às 16:52:33: os cinco tamanhos do Waterfox,
reescritos. O auto-reparo das 5h então reinstala **o que o mapa manda**, e a
arte do projeto nunca chega à tela.

**Não é uma linha. São 23:**

| destino fora do repositório | linhas |
|---|---|
| `~/.local/share/icons/Dracula-Icones/` | 10 |
| `~/.local/share/icons/hicolor/` | 8 |
| outras | 5 |
| **marcadas `: terceiro`** | **9** |

E `packs/dracula/icones/apps.map:120` guarda a pendência, comentada, com uma
interrogação: `# net.waterfox.waterfox : ?   # Waterfox`.

### Quem reescreve o `Dracula-Icones`, e por que isso fecha o caso

`rebuild_dracula_theme()` — **`~/.config/zsh/functions/sistema.zsh:103`**, uma
função do **Spellbook-OS**. Não é script do MeowSystem: é outro projeto dele,
que reconstrói o tema a partir de `src/icons/upstream/dracula-icons-main/`.

Então o ciclo completo, com nome em cada passo:

```
1. rebuild_dracula_theme()      reescreve ~/.local/share/icons/Dracula-Icones/
   (Spellbook-OS, fora daqui)   -> 21/09 16:52:33, cinco tamanhos do Waterfox
2. apps-resgatados.map:54       aponta para lá
3. icones_resgatados.sh         instala o que o mapa manda
4. meow doctor --consertar      reafirma, todo dia às 5h
```

**E a regra que isso viola já estava escrita — neste repositório.**
`assets/icones/PROCEDENCIA.md`, linhas 403-408:

> ***Por que copiar em vez de apontar.*** *A segunda coluna do
> `apps-dracula.map` apontava para dentro do `Dracula_OS-Theme`. Aquele
> repositório só existe na máquina dele — um script que o lesse funcionaria de
> um lado e quebraria do outro, e este projeto é puxado dos dois. Cada arquivo
> foi copiado com o **nome do ícone que ele veste**.*

A regra estava certa, escrita, e no lugar certo. **Vinte e três linhas a
violam.** É o padrão que o `docs/SPRINTS.md` já nomeou: *"a regra que só existe
como comentário se repete"* — e desta vez ela nem era só comentário, era
documentação com o porquê e o precedente.

O mesmo arquivo também confirma, de passagem, a hipótese de resolução que eu
não tinha como testar: *"o `scalable/apps` vence o `48x48/apps` no resolvedor"*.

**A lição já estava paga, um projeto antes.** A memória do `Dracula-OS-Theme`,
de 18/08/2026:

> *"Arte em `src/icons/projects/` é **cópia** da arte-mestre — nunca uma segunda
> arte-mestre. Se defasar, o tema sombreia o hicolor e regride o ícone. **Why:**
> o tema copia arte em vez de referenciar, então divergência silenciosa é o modo
> de falha natural."*

Aqui é pior: a fonte não é uma cópia defasada, é **um diretório que outro
programa reescreve**.

### O desenho: uma fonte, derivados calculados

```
  packs/<id>/icones/apps/<nome>.svg          <- A FONTE. É isto que se edita.
            │
            ├─ scalable/apps/<nome>.svg       o vetor, como está
            ├─ 48x48/apps/<nome>.png          rasterizado da fonte
            ├─ 64x64 · 128x128 · 256x256      idem
            ├─ bandeja/<nome>.png             o corte de bandeja, da mesma fonte
            └─ <nome>-<flavor>.svg            recolorido por PAPEL, por flavor
```

**Oito regras, e elas são o contrato:**

1. **Um nome, uma fonte.** Para cada `Icon=` existe **exatamente um** arquivo
   fonte, e ele mora no pack. Duas fontes para o mesmo nome é erro de
   validação, não escolha de precedência.
2. **Derivado nunca é editado.** Todo PNG de tamanho, toda variante de flavor e
   todo corte de bandeja são **calculados** da fonte, na instalação. Editar um
   derivado é trabalho que a próxima instalação apaga — e é exatamente o que
   vinha acontecendo.
3. **Derivado não é versionado.** Ele nasce em
   `~/.local/state/meowsystem/icones/` e vai para o tema. O que o git guarda é
   a fonte.
4. **Mapa não aponta para fora.** Um destino só pode ser: dentro do pack
   (`apps/x.svg`), no acervo do motor com prefixo (`motor:arcticons/x.svg`), ou
   em **outro pack** com prefixo (`pack:catppuccin:apps/x.svg`). Caminho
   absoluto e `~/` são recusados pela validação.
5. **Arte de terceiro entra por cópia, com procedência.** Querer o
   Firefox-Dracula no Waterfox é legítimo — então o desenho é **copiado** para
   `packs/dracula/icones/apps/` com uma linha em `PROCEDENCIA.md` dizendo de
   onde veio, sob que licença, e em que data. O que não vale é *apontar* para
   uma pasta que outro programa dono reescreve.
6. **A recoloração é por papel, nunca por hex.** É a regra que o
   `gerar_icones_autorais.py` já cumpre: cada forma declara `sujeito`, `tinta`,
   `fundo`; o papel resolve na paleta do flavor. É o que faz o `alucard` nascer
   sem redesenho — e P27 mediu que hoje ele nasce com **zero** dos onze.
7. **Uma linha de comando fecha o ciclo:** `meow icones fonte <nome>` diz qual é
   a fonte de um ícone e o que dela deriva. Hoje, responder isso exige ler três
   mapas e dois scripts.

Como a fonte de verdade do Dracula-Icones é **outro projeto**, copiar sem
caminho de volta troca um problema por outro: a cópia congela, o upstream anda,
e ninguém percebe.

8. **`meow pack sincronizar <id>`** — relê as origens declaradas no
   `PROCEDENCIA.md`, compara o `sha256` de cada arte copiada com a do upstream,
   e **diz o que divergiu**. Não copia sozinho: mostra o par lado a lado e
   espera o gesto. Uma arte que ele retocou depois de copiar **não pode** ser
   sobrescrita por um `git pull` de outro repositório.
   O `meow doctor` reporta a divergência como informação, **nunca** como
   conserto automático — porque escolher entre a sua versão e a do upstream é
   decisão de autor, não de programa.

### O caso Waterfox, resolvido pelas oito regras

```
1. o desenho do Firefox-Dracula é COPIADO para
     packs/dracula/icones/apps/net.waterfox.waterfox.svg
2. PROCEDENCIA.md ganha a linha: origem, licença, data, sha256
3. apps-resgatados.map:54 PERDE a linha que aponta para ~/.local/share/icons/
4. packs/dracula/icones/apps.map:120 deixa de ser comentário e vira mapeamento
5. os PNG de 32/48/64/128/256 passam a ser derivados dessa fonte
6. a raposa roxa da lua continua existindo em assets/icones/resgatados/ —
   vira uma ALTERNATIVA na oficina (P26), não o que vence calado
```

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `scripts/pack.py` | os prefixos `motor:` e `pack:`; a recusa de caminho externo |
| `lib/icones.sh` | `derivar(fonte)` — tamanhos, flavors, bandeja |
| `scripts/icones_*.sh` (11) | passam a instalar de derivado, nunca de fonte externa |
| `assets/icones/apps-resgatados.map` e os outros 5 | as 23 linhas externas saem |
| `packs/dracula/icones/apps/net.waterfox.waterfox.svg` | **novo** — o Firefox-Dracula, copiado |
| `packs/dracula/PROCEDENCIA.md` | **novo** — origem e licença de cada arte de terceiro |
| `bin/meow` | `icones fonte <nome>`; `pack sincronizar <id>` (regra 8) |
| `docs/PACKS.md` | a seção "Fonte e derivados" |
| `tests/fonte-unica.sh` | **novo** (abaixo) |

### Como conferir

```sh
# 1. nenhum mapa aponta para fora do repositório
grep -rn "~/\.local\|^/home/" assets/icones/*.map packs/*/icones/*.map | grep -v '^\s*#' | wc -l
# antes: 23 · depois: 0

# 2. cada Icon= da máquina tem UMA fonte, e ela está no pack
./tests/fonte-unica.sh      # falha se um nome tiver duas fontes, ou nenhuma

# 3. o Waterfox mostra o Firefox-Dracula, e sobrevive ao doctor
meow icones fonte net.waterfox.waterfox
#   fonte: packs/dracula/icones/apps/net.waterfox.waterfox.svg
#   deriva: scalable, 32, 48, 64, 128, 256, bandeja
meow doctor --consertar && meow icones fonte net.waterfox.waterfox   # a mesma linha
```

### O que pode dar errado

- **Copiar arte de terceiro tem limite de licença.** O `Dracula-Icones` é
  GPL-compatível, mas cada acervo tem o seu. `PROCEDENCIA.md` não é burocracia:
  é o que permite o `meow pack exportar` (P11) recusar empacotar o que não pode
  ser redistribuído.
- **Derivar na instalação custa tempo.** São ~180 ícones × 5 tamanhos. Vale
  cachear por `sha256` da fonte e só refazer o que mudou — senão a primeira
  regra (P1, o instalador que converge) fica lenta demais para rodar em laço.
- **"Um nome, uma fonte" quebra o que hoje é precedência.** Três acervos podem
  oferecer o mesmo nome (arcticons, convertidos, resgatados). Hoje vence o
  último que escreveu; depois, o mapa do pack decide e **a validação recusa o
  empate**. Isso vai expor conflitos que estavam escondidos — e expor é o ponto.

---

# P29 — O que é tema volta para casa

**A fronteira, dele, 21/09/2026:**

> *"O Spellbook é do meu PC, exclusivo para ele. Tudo que for relacionado a tema
> é para ser do MeowSystem, tá bom? Temos que trazer tudo para cá."*

Isso encerra a pergunta que P28 deixou aberta — não há upstream externo para
sincronizar. **A origem passa a ser aqui.**

### O que medi

O `Spellbook-OS` tem 5.213 arquivos. A esmagadora maioria é da máquina dele
— `aurora/` com thermal, GPU, wifi, `acer_wmi`, watchdogs; `venv/` com 4.712
arquivos; `cca/`, `completions/`, `vault/`. Nada disso é tema e nada disso se
move.

**O que é tema e está do lado errado:**

| item | onde | tamanho | por que é tema |
|---|---|---|---|
| `patches/patches.d/series` | Spellbook | ~60 linhas | **é quem sabe aplicar os patches** — classes `req`/`opt`, marcadores, ordem, e a análise de colisão de arquivos |
| `patches/patches.d/cosmic-comp-sem-workspace-vazio.patch` | Spellbook | 12.243 B | o único `req` da série; o MeowSystem não o tem |
| `scripts/spicetify-setup.sh` | Spellbook | 277 linhas | **é a pendência do Spotify** (P2 e P3) |
| `functions/sistema.zsh:103` — `rebuild_dracula_theme()` | Spellbook | — | constrói o `Dracula-Icones` que P28 mandou parar de apontar |
| `fastfetch/config.jsonc` | Spellbook | difere | o MeowSystem tem o seu; **são duas configurações do mesmo programa** |
| `aurora/aurora-editor-apply.sh` | Spellbook | 41 linhas | tema de editor |
| `ghostty/config` | Spellbook | — | tema de terminal |

### Os patches já estão nos dois lugares, e são idênticos

```
MeowSystem patches/            Spellbook patches/patches.d/
  blur-cache-textura.patch   =   blur-cache-textura.patch      IGUAL
  menu-clique-curto.patch    =   menu-clique-curto.patch       IGUAL
  modo-leitura.patch         =   modo-leitura.patch            IGUAL
  raio-clampado.patch        =   raio-clampado.patch           IGUAL
  files-wallpaper-menu.patch     (só aqui)
                                 sem-workspace-vazio.patch     (só lá)
                                 series                        (só lá)
```

Quatro cópias byte a byte. Não há duas verdades — há **uma verdade em dois
lugares**, o que é pior: ninguém sabe qual editar.

**E os cinco patches são features que o MeowSystem já expõe na tela:**

| patch | a feature, aqui |
|---|---|
| `sem-workspace-vazio` | `scripts/areas.sh` — a aba «Áreas de trabalho» |
| `raio-clampado` | `scripts/painel.sh` — «Canto arredondado», painel e dock |
| `modo-leitura` | `scripts/leitura.sh` — a aba «Modo de leitura» |
| `blur-cache-textura` | `scripts/vidro.sh` — o vidro |
| `menu-clique-curto` | o menu do compositor |

**O MeowSystem tem quatro dos cinco desenhos e não tem a planta.** Por isso o
`compositor_patches.sh` só **confere** e nunca conserta, e por isso o `doctor`
devolve divergência todo dia mandando rodar `aurora-cosmic-comp-ws.sh --build`
— um script que **não existe nesta máquina** (P22, achado 2).

### E o script fantasma do qBittorrent

`assets/temas-de-apps/qbittorrent/manifesto.sh:110` exige
`~/.config/zsh/scripts/aurora-qbittorrent-config.sh`. Procurado no Spellbook
inteiro: **não existe lá também.** Não é "está no outro projeto" — é uma
dependência de um arquivo que não existe em lugar nenhum. P2 mandava tirar; esta
sprint confirma que não há de onde trazer.

### O que fazer

1. **A série de patches vem inteira**, para `patches/`: o `series`, o
   `sem-workspace-vazio.patch` e o `LEIA-ME.txt`. As quatro cópias idênticas no
   Spellbook **saem de lá** — uma verdade, um lugar.
2. **O aplicador passa a ser deste projeto.** `scripts/compositor_patches.sh`
   deixa de conferir contra `~/.config/zsh/patches/` e passa a **aplicar** a
   série daqui. O `CP_COPIA`/`CP_COPIA_ALT` somem, e com eles a divergência
   eterna do doctor.
3. **O `spicetify-setup.sh` vira etapa**, e a pendência do Spotify (P2) ganha o
   botão que faltava: o comando que resolve passa a existir dentro do projeto.
4. **`rebuild_dracula_theme()` vira `meow pack construir dracula`**, que escreve
   em `packs/dracula/icones/`, não em `~/.local/share/icons/Dracula-Icones/`.
   A função sai do `sistema.zsh`.
5. **O `fastfetch/config.jsonc` duplicado**: os dois são comparados linha a
   linha, o que for tema fica aqui, e o do Spellbook vira um `include` ou some.
   Duas configurações do mesmo programa é o defeito, não o conteúdo de nenhuma
   delas.
6. **O Spellbook ganha uma linha no `README`** dizendo o que saiu e para onde,
   com a data. Quem procurar `rebuild_dracula_theme` lá em seis meses precisa
   achar o caminho, não o silêncio.
7. **A regra fica escrita, nos dois projetos:** *"tema é do MeowSystem; máquina
   é do Spellbook"*. Um teste do MeowSystem recusa qualquer caminho
   `~/.config/zsh/` em código — é a mesma regra de P28 (nada aponta para fora),
   aplicada ao vizinho.

### Arquivos, e só estes

| arquivo | o quê |
|---|---|
| `patches/series`, `patches/cosmic-comp-sem-workspace-vazio.patch` | **novos** — vêm do Spellbook |
| `scripts/compositor_patches.sh` | passa a aplicar, não só conferir; `CP_COPIA` sai |
| `scripts/spicetify_setup.sh` | **novo** — vem do Spellbook, vira etapa |
| `assets/temas-de-apps/spotify/manifesto.sh` | a pendência ganha comando que existe |
| `assets/temas-de-apps/qbittorrent/manifesto.sh` | a dependência fantasma sai |
| `scripts/pack.py`, `bin/meow` | `meow pack construir <id>` |
| `assets/fastfetch/config.jsonc` | recebe o que era tema no do Spellbook |
| `tests/portabilidade.sh` | recusa `~/.config/zsh/` em código (regra 7) |
| `docs/FRONTEIRA.md` | a fronteira entre os dois projetos |

### Como conferir

```sh
# 1. nada mais aponta para o vizinho — NOS ARQUIVOS QUE ESTA SPRINT AUTORIZA
grep -rn "config/zsh" scripts/compositor_patches.sh assets/temas-de-apps/qbittorrent/ \
  | sed 's/^[^:]*:[0-9]*://' | grep -vE '^\s*(#|$)' | wc -l
# antes: 4 · depois: 0

# 2. o doctor fica verde no compositor
meow doctor | grep -i compositor
# antes: divergencia todo dia, mandando rodar script que nao existe
# depois: "ok  5 patches na serie, 5 aplicados" ou "-- nao aplicados (opcional)"

# 3. o Spotify tem o comando que a pendencia promete
meow pendencias | grep -i spicetify   # e o botao Resolver de fato resolve
```

> **CORREÇÃO DE 22/09, e o erro era meu.** A conferência original varria
> `scripts/ lib/ install.sh` inteiros e exigia `0`. Medido: sobram **15
> linhas**, todas em arquivos que a tabela "Arquivos, e só estes" **não
> autoriza** — `install.sh` (×5), `fastfetch_logo.sh` (×2), `areas.sh`,
> `prompt.sh`, `coleta-meowsystem.sh`, `btop-bat/manifesto.sh` (×2) e três
> `.md`. E duas delas usam `${ZDOTDIR:-...}`, que **é** a variável de escape
> que o teste cobra. Pedir zero de uma varredura mais larga que o escopo é
> pedir o impossível; a régua passou a medir só o que a sprint pode tocar.

### O que pode dar errado

- **Compilar o `cosmic-comp` derruba a tela de login se der errado.** O próprio
  `series` avisa: o greeter é o mesmo binário, e é por isso que o modo de
  leitura e o blur são `opt` e vêm por último. **Trazer a série para cá não
  muda esse risco — mas passa a ser risco deste projeto.** O `--uninstall`
  precisa saber voltar ao binário do pacote.
- **O `series` é documentação cara.** Sessenta linhas com medição de 30/08,
  31/08 e 17/09, incluindo a correção de uma afirmação errada sobre arquivos
  disjuntos. Vem **inteiro**, comentário por comentário. Reescrever para
  "limpar" apagaria três medições que custaram um crash de sessão.

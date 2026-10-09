# Paridade de ícones, seletor e exportação: auditoria de 09/10/2026

Queixa de 09/10: *"ao trocar o ícone na home, com o Dracula no ar, os 600+ SVG
Dracula não aparecem, nem os feitos à mão nem os ajustados; muitos SVG sumiram;
temos paridade com os temas padrão? conseguimos gerar e exportar temas completos?"*

Três auditorias em paralelo, mais uma conferência que refez as contas. Nada foi
alterado no repositório nem no sistema. Todo teste que escreve rodou com
`HOME` temporário. Este arquivo é o único criado.

## Resposta curta

1. **Os desenhos não sumiram do git.** Em todo o histórico foram apagados 23
   SVG, e o único do Dracula é o `nyx.svg`, tirado de propósito na P43 (projeto
   pessoal). Nenhuma versão antiga apagada bate com a arte do `Dracula_OS-Theme`.
2. **O seletor esconde o acervo.** No máximo 120 desenhos por tela (60 do pack e
   60 do motor). A ficha abre filtrada pela 1ª palavra do nome do app e não tem
   "ver mais". Dos 591 desenhos versionados distintos, 146 nunca podem aparecer.
3. **O "600+" existe nos dois sentidos.** São 647 SVG de ícone versionados no
   repositório (591 distintos). O universo Drácula tem 630 desenhos únicos, que
   viram 480 sem as cópias do Papirus. **175 desenhos Drácula próprios nunca
   entraram no pack**: estão só em `Dracula_OS-Theme/src/icons/current/scalable/apps`.
4. **A paridade com o Catppuccin é parcial.** O Dracula herda os mimetypes
   (cor macchiato), tem 7 pastas contra 3.280 e herda o mapa do COSMIC e as
   fontes.
5. **Gerar funciona, exportar um tema completo não existe.** O
   `meow pack exportar` leva a receita (o pack), não o tema montado (0
   `index.theme`). Escolher o pack Dracula também não liga os desenhos de app
   dele: 28 ícones em `scalable/apps` no padrão, contra 230 com
   `ICONES_DRACULA="sim"`.

---

## 1. As cinco contagens, refeitas

Cada conta foi refeita do zero, por sha256 do conteúdo e nunca por nome. Os
scripts e as listas ficaram no scratchpad da sessão (ver o fim deste arquivo).

| # | Medida | Valor conferido | O que os auditores disseram | Qual vale e por quê |
|---|---|---|---|---|
| 1 | SVG Drácula únicos | **630** brutos (295 da `new-sessao-atual` + 362 próprios de `current/`, com 27 em comum); **480** sem as 150 cópias do Papirus; 482 contando os 2 de `projects/` | Frente 1: 630/480. Frente 2: "393 não vêm do upstream". Frente 3: "387 próprios do antigo" | **Frente 1.** A Frente 2 não contou os 1.562 links do `upstream/` cujo alvo é o próprio texto do SVG, nem as cópias do Papirus. A Frente 3 somou, nos 387, 148 cópias do Papirus, 30 desenhos do upstream (via esses links) e 34 PNG. Decomposição: 387 = 175 + 148 + 30 + 34 |
| 2 | No pack Dracula | 396 arquivos, 385 únicos. Arte Drácula própria: **305** (295 + 10). **Faltam 175**, todos de `current/scalable/apps` | Frente 1: 305 e 175. Frente 3: "367 desenhos, 273 sem mapa" | **Frente 1.** Em `apps/` + `biblioteca/` são 367 arquivos, mas 356 desenhos distintos (11 gêmeos). O mapa usa 93 deles e **263** ficam sem app, o mesmo número do `meow pack info`. O 273 contou os gêmeos duas vezes |
| 3 | Opções do seletor | 378 desenhos do pack oferecíveis (72 + 295 + 11). Busca vazia: 120 (60 Dracula, todos de `apps/`, e 0 da biblioteca). 39 buscas de 1 caractere alcançam 318. Por app: Chrome 2, Discord 2 (0 Dracula), Spotify 2 (0), Telegram 3, Edge 0 | Frente 2: os mesmos números | **Frente 2**, conferida chamando `_api_glifos` no próprio processo. Acréscimo: dos 591 versionados distintos, 445 são alcançáveis em teoria e **146 nunca são oferecidos** |
| 4 | SVG apagados no git | **23** (19 gatos, `nyx`, 2 convertidos, 1 de `uploads/`). Blobs SVG do histórico ausentes no HEAD: 107, nenhum do `Dracula_OS-Theme` além do `nyx` | Frentes 1 e 3: 23. Frente 1: "100 versões antigas" | **Todos.** O 100 da Frente 1 compara com o disco, que tem arquivos fora do git. O 107 compara com o índice do HEAD. São versões anteriores regeradas (autorais P34/P61, pastas, convertidos) |
| 5 | Cobertura do tema gerado e exportado | Tema gerado com Dracula e `sim`: 230 em `scalable/apps`. Com o padrão `nao`: 28. O real tem 231 (o `nyx.svg` órfão). `.meowpack`: 0 `index.theme`. Mapa: 94 caminhos, 93 desenhos distintos | Frente 3: 230/28, 0 `index.theme`, "94 de 367" | **Frente 3**, com a correção do item 2: são 93 de 356 desenhos distintos |

Provas curtas (comando e saída):

```
# 1 e 2: sha256 de todas as fontes (scratchpad/conf/shas.py, conta.py, links.py)
cur_own 362 pap 150 próprios 212 só cur 185 no pack 10 faltam 175
universo bruto 632 sem papirus 482          # 630/480 sem os 2 de projects/
nsa no pack 295

# 3: _api_glifos chamado no processo, HOME temporário, cópia do meow.conf real
pack dracula desenhos oferecíveis 378 aviso ''
busca vazia: total 120 limitado True {'Dracula': 60, 'traço (Arcticons)': 39, 'convertido': 13, 'desenho nosso': 8}
do pack por pasta Counter({'apps': 60})
alcance com 39 buscas de 1 caractere: 318
versionados únicos 591 oferecíveis em teoria (sem teto) 445 nunca oferecidos 146

# 4
git log --all --diff-filter=D --name-only -- '*.svg' | grep -c svg   → 23

# 5
zstd -dc dracula.meowpack | tar -t | grep -c index.theme              → 0
ls casa-dracula/.../scalable/apps | wc -l  → 230 ; casa-dracula-padrao → 28
```

## 2. Por que os 600+ não aparecem no seletor

A causa está em quatro camadas, todas no código. Nenhum arquivo sumiu.

1. **Filtro de abertura.** Em `app/pagina/app.js:2981`, a ficha chama
   `carregarGlifos(a.nome.split(/\s+/)[0].toLowerCase(), a.id)`. A busca já
   abre com a 1ª palavra do nome ("google", "microsoft"), e o servidor filtra
   por substring do **nome do arquivo** (`servidor.py:9190`).
2. **Teto silencioso.** `limite = 60` (`servidor.py:9174`) vale para cada
   lado. Na ordem `apps/` → `biblioteca/` → `autorais/`, a busca vazia enche
   os 60 só com `apps/`, e os 295 da biblioteca nunca aparecem sem busca. A
   página grava `limitado` (`app.js:2877`), mas nenhuma linha lê esse valor, e
   não existe páginação.
3. **Pastas que a rota não lê.**
   - Do pack: `pastas/` (7) e os autorais do outro flavor (`-alucard`, 11).
   - Do motor: `resgatados/` (29). São os vetores refeitos à mão (Discord,
     Spotify, Edge, WhatsApp…), e 28 deles não existem em nenhum grupo
     oferecido. Também fica fora `arcticons/` (34 desenhos sem gêmeo).
   - O `previa-arcticons/` também não é lido, mas os 35 desenhos dele já chegam
     por outra pasta (sha256 idêntico), então ali não há perda.
4. **A busca só casa o nome do arquivo.**
   - O Firefox-Dracula mora em `apps/net.waterfox.waterfox.svg`, e por isso a
     busca "firefox" não o acha (achado 2 de `00-achados-como-usuario.md`).
   - O `catalog.json` do `Dracula_OS-Theme`, com descrição em pt-BR e tags para
     os 295 da biblioteca (`alien` → "alienígena", `espaco_scifi`), nunca veio
     para o pack.
   - Além disso, a `trava_pack` (`app.js:3110`) esconde o grupo Dracula nos
     apps COSMIC e em mais 6.

A prova de aceite da P60 (`docs/sprints/2026-09-25-corretivas.md:120`) só
exigia que a busca «alien» achasse o desenho. Ela passa, mas só ajuda quem já
sabe o nome em inglês. Navegar pelo acervo nunca foi exigido. Já o
`docs/PACKS.md:692` promete que a biblioteca é *"de onde a pessoa escolhe o
próximo ícone"*.

## 3. O que "sumiu", e de onde restaurar

Do git não sumiu nada. O que existe fora do produto:

| O quê | Quantos | Onde está hoje | Desde quando fora da tela |
|---|---|---|---|
| Desenhos Drácula próprios de `current/` nunca trazidos | **175** SVG (119 logos e apps, 16 `steam_icon_*`, 11 da série `0xx-`, 6 de status, 6 pastas coloridas, 5 `calendar-*`, 5 `distributor-logo-*`, 4 mimetypes, 3 symbolic). Dois são PNG embutido (`gnome-remote-desktop`, `skype-call-recorder`) | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/current/scalable/apps/` | Desde **16/04/2026**. O `build.sh` v1.0 já montava o `Dracula-Icones` só pelo `mapping.json`. A cópia congelada de 24/09 tem **0** desses 175 |
| PNG desenhados à mão | 38 únicos (35 em `scalable/apps`, 3 em `48x48/apps-global`); mais 30 PNG do tema antigo | `Dracula_OS-Theme/src/icons/current/` e o backup congelado | 0 deles estão no repositório ou no tema instalado |
| O tema antigo inteiro (`Dracula-Icones`, `dracula-icons-main/circle`, cursor) | 4.414 arquivos | `~/.local/state/meowsystem/backups/2026-09-24T03-50-20-copias-congeladas-dracula/` (o `COMO-RESTAURAR.txt` traz o `mv`) | 24/09 (P37/P41) |
| Nomes simbólicos do tema antigo | 458 nomes `*-symbolic` ausentes em Base + tema; 318 contando os fallbacks (Cosmic, Adwaita, breeze-dark, hicolor) | backup acima (vinham da `main` do m4thewz) | 24/09: a base passou de `main` para `circle` |
| Rascunhos nunca versionados | 8 SVG: `folder-download`, `_discord-b`, `_discord-c`, `extase-em-4r73`, `guvcview`, `whatsapp-linux-app`, `net.waterfox.waterfox`, `photogimp` | `.trabalho-icones/` (no `.gitignore`) | Risco: só existem nesse disco |

A promessa de 23/09 foi cumprida, e é por isso que o pack *parecia* completo.
O combinado era trazer os 295 e "TODAS as ligações que apontam para SVG". As
ligações do `mapping.json` que apontam para SVG estão **todas** no pack, menos
4 caminhos de pacote do sistema (`ibus-*`, `snapcraft`) e 2 projetos pessoais
(`mnemo`, `nyx`). Os 175 nunca estiveram em nenhuma ligação. São o acervo de
`current/`, importado em 16/04 como "tema atual Dracula-Icones com 3437 SVGs
custom" (commit `75f1933a` do `Dracula_OS-Theme`).

Lista dos 175 com sha256: `scratchpad/inv/faltam-175.tsv` (a Frente 1 e a
conferência chegaram ao mesmo conjunto, sha a sha). Nenhum é dos projetos
pessoais da lista. Quatro nomes pedem sua confirmação: `calcdeirao`, `jogos`,
`rede` e `clima2`.

## 4. Paridade entre Dracula e Catppuccin

Fonte: `scripts/pack.py info <pack>`, rodado com `HOME` temporário.

| Camada | Catppuccin | Dracula |
|---|---|---|
| ícones de app | do motor (o acervo `catppuccin-apps` fica fora do git, sem licença) | próprio: 204 apps, 263 desenhos da biblioteca sem app |
| mimetypes | próprio: 656 por flavor, ×4, mais `css-variables` | **herdado** do Catppuccin (`macchiato`), sem cor Dracula |
| pastas | 3.280 | **7** (faltam `folder`, `user-home` e `user-desktop`, ver I7 em `01-regressoes.md`) |
| autorais | 11 bases × 4 flavors | 11 bases × 2 flavors |
| mapa do COSMIC e fontes | próprio / motor | **herdado** do Catppuccin |
| base | Papirus-Dark (apt, não vai no export) | m4thewz `circle`, pinada por sha256 |
| temas de app | qbittorrent, vscode-icones | kitty, gnome-terminal, telegram, discord, onlyoffice (sem qbittorrent por falta de procedência; sem vscode-icones) |

Conclusão: o Dracula ganha nos ícones de app e perde em mimetypes, pastas e
COSMIC. O Catppuccin, por sua vez, depende de um acervo que o git não leva, e
a etapa `icones_apps` sai com rc=3 numa máquina nova.

## 5. Gerar e exportar um tema completo

- **Gerar: funciona e é fiel.** As 204 linhas do `apps.map` saem idênticas no
  tema, e a base é baixada e pinada sem link quebrado. Porém o `index.theme`
  da 1ª passada sai sem `48x48/apps`, `scalable/mimetypes` e os `status`. Só o
  `install.sh` corrige isso, porque repete até 5 vezes.
- **Escolher o pack não liga os desenhos dele.** O `meow pack usar` só grava
  `PACK`, `FLAVOR` e `PORQUE` (`scripts/pack.py:5883`). O padrão do
  `ICONES_DRACULA` é `nao` (`meow.conf.exemplo:547`). Resultado: 28 ícones em
  `scalable/apps` contra 230. Sua máquina tem `sim` porque você ligou o ajuste
  à mão.
- **Exportar: só a receita.**
  - O `.meowpack` do Dracula leva o pack inteiro (apps 72, autorais 22,
    biblioteca 295, pastas 7, `apps.map`, 573 temas capturados) e 0
    `index.theme`.
  - Não existe verbo que empacote o tema montado. Os `exportar` que existem são
    `meow pack exportar` (`bin/meow:4491` → `scripts/pack.py`) e as rotas
    `/api/exportar/conf`, `/api/exportar/pagina` e `/api/pack-exportar`.
  - O tema montado se chama `MeowSystem-Icons` em qualquer pack, depende do
    `MeowSystem-Icons-Base` ao lado e diz `Comment=Catppuccin $FLAVOR para o
    COSMIC` (`scripts/construir_icones.sh:660`) mesmo quando é Dracula.
- **Os ajustes não viajam.**
  - As escolhas do painel vão para o `apps.map` do clone (regressão I3, já
    registrada). O `.meowpack` exporta a cópia de trabalho, inclusive a linha
    não commitada do `org.kde.ghostwriter`.
  - Importar em outra instalação é recusado ("já existe packs/dracula").
  - Um pack derivado (`meow pack novo`) herda por id e exporta 4 arquivos, com
    zero desenhos.

## 6. O que ficou de fora das três frentes, e o que se fechou aqui

| Lacuna | Situação |
|---|---|
| Fonte não lida: `~/Desenvolvimento/Project_Beholder/data/sessao_atual` (307 SVG) | **Fechada.** 295 são idênticos à biblioteca. Os 12 restantes são arte de site (Sabin, QR code, bandeiras), não ícone |
| Varredura do `$HOME` atrás de outros acervos de SVG com mais de 30 arquivos | **Fechada.** Fora do que já foi contado, só há venv, flatpak, Steam, cargo e VS Code |
| O 23/09 prometia "trazer tudo"? | **Fechada.** A promessa era biblioteca + ligações SVG, e foi cumprida. Os 175 nunca foram prometidos (seção 3) |
| `previa-arcticons` fora do seletor (Frente 2) | **Corrigida.** Os 35 já chegam por outra pasta (sha256 idêntico) |
| Os PNG feitos à mão (38 + 30) | **Medida.** Nenhum está no repositório. Falta decidir se entram (são PNG, não SVG) |
| Tema antigo, simbólicos | **Medida.** 458 nomes, ou 318 com fallbacks. A Frente 3 disse 497, contra uma cadeia sem os fallbacks |
| Importar o `.meowpack` numa máquina limpa, de ponta a ponta | **Aberta.** A Frente 3 só testou a recusa por id repetido |
| Conferir na tela, com o painel, depois da correção | **Aberta.** É prova das tarefas abaixo |

## 7. Tarefas de correção

Agrupadas em dois blocos: **A, Seletor** (T1 a T4) e **B, Pack e tema** (T5 a
T10). Cada tarefa traz o que se mediu, a causa, a cura na origem e a prova.
Nada foi implementado.

### T1. O seletor mostra o acervo inteiro, em pastas por acervo
- **Medido:** no máximo 120 por tela; a busca vazia dá 60 de `apps/` e 0 da
  biblioteca; 146 de 591 desenhos versionados nunca são oferecidos; 18 de 38
  apps abrem com 0 opções; `limitado` é ignorado.
- **Causa:** `limite = 60` sem páginação (`servidor.py:9174`, `:9192`,
  `:9249`); a ficha abre com o filtro da 1ª palavra (`app.js:2981`); o
  `GLIFOS.limitado` nunca é lido.
- **Cura na origem:** a rota devolve **grupos** (acervo e subpasta) com
  contagem total e páginação por grupo, ou o índice inteiro só com metadados
  (cerca de 600 itens, leve). A ficha abre **sem filtro**. Os grupos ficam
  recolhíveis: "Dracula: feitos para apps / biblioteca / autorais" e
  "MeowSystem: autorais / convertidos / traço / resgatados". O nome do app vira
  destaque ("sugeridos"), não filtro.
- **Prova:** teste em `tests/` com `HOME` temporário que chama
  `_api_glifos({'busca':[''],'app':['firefox']})` e confere que, para cada
  grupo, `total == número de .svg da pasta declarada` (pack: 72 + 295 + 11;
  motor: soma das pastas lidas), e que nenhuma resposta corta sem um cursor de
  próxima página.

### T2. A rota lê todas as pastas de acervo do motor e os dois flavors do pack
- **Medido:** `resgatados/` tem 29 desenhos, e 28 deles não existem em grupo
  nenhum. `arcticons/` tem 34 desenhos sem gêmeo. Os autorais `-alucard` (11)
  ficam de fora.
- **Causa:** a tupla fixa `("arcticons-apps","autorais","convertidos-apps")`
  (`servidor.py:9230`) e o filtro `-<FLAVOR>.svg` dos autorais
  (`servidor.py:8811`).
- **Cura na origem:** a lista de acervos do motor sai de **um** lugar
  declarado. Pode ser o mesmo `PROCEDENCIA.md`/mapas que o `meow icones fonte`
  já lê, e não uma tupla no servidor. Os autorais entram nos flavors do pack em
  vigor, com o flavor como subgrupo. `pastas/` continua fora de propósito
  (pasta não é ícone de app). O Catppuccin com o Dracula no ar continua fora
  pela regra da P60, salvo decisão sua em contrário (pergunta 3).
- **Prova:** script de sha256 ao lado do teste da T1. A conta
  `versionados únicos − oferecíveis` só pode sobrar `pastas/`, `gatos/`,
  `logo.svg` e o acervo do pack fora do ar. Hoje sobram 146.

### T3. A busca acha pelo nome do app e pelo significado
- **Medido:** "firefox" não acha o `apps/net.waterfox.waterfox.svg`
  (Firefox-Dracula), e "alienígena" não acha `biblioteca/alien.svg`.
- **Causa:** a busca casa só o nome do arquivo (`servidor.py:9190`, `:9243`).
  O `catalog.json` do `Dracula_OS-Theme` (descrição pt-BR e tags dos 295)
  nunca veio para o pack.
- **Cura na origem:** trazer o catálogo para `packs/dracula/icones/biblioteca/`
  com linha no `PROCEDENCIA.md`. A busca passa a casar também o comentário da
  linha do `apps.map` (o nome do app que o desenho veste) e a descrição e as
  tags do catálogo.
- **Prova:** `_api_glifos({'busca':['firefox']})` contém
  `apps/net.waterfox.waterfox.svg`; `{'busca':['alienígena']}` contém
  `biblioteca/alien.svg`.

### T4. A trava do pack explica em vez de sumir
- **Medido:** em CosmicFiles, Settings, Store, Term, Edit e mais 6 apps, o
  grupo Dracula não aparece. O CosmicEdit, com as duas travas, nem mostra a
  busca.
- **Causa:** `app.js:3110` filtra `g.pack ? !app.trava_pack : !app.trava`, e
  a `trava_pack` vem dos donos de `scalable/apps` (`completar_icones.sh`,
  `logo.sh`).
- **Cura na origem:** a ficha mostra o acervo em modo só-leitura, com a frase
  de quem é o dono do ícone desse app e onde se troca. Assim o desenho continua
  visível e nada grava onde a instalação seguinte apagaria.
- **Prova:** teste de página que abre a ficha do CosmicEdit e encontra os
  grupos do acervo, sem botão "usar" no grupo travado.

### T5. Os 175 desenhos Drácula de `current/` entram no pack
- **Medido:** 175 SVG próprios (sha256 fora de upstream, Papirus, pack, motor e
  tema) existem só em `Dracula_OS-Theme/src/icons/current/scalable/apps`.
- **Causa:** a P36 trouxe a `new-sessao-atual` e as ligações do
  `mapping.json`. O resto de `current/` nunca teve ligação e ficou para trás.
  Ele está fora da tela desde 16/04.
- **Cura na origem:** copiar para `packs/dracula/icones/biblioteca/` (ou numa
  subpasta `biblioteca/tema-antigo/`), com nome de origem e linha no
  `PROCEDENCIA.md` (sha medido no dia), depois que você confirmar `calcdeirao`,
  `jogos`, `rede` e `clima2`. Os 2 SVG com PNG embutido entram marcados como
  tal ou ficam fora, conforme você decidir. Decidir no mesmo gesto os 38 PNG
  feitos à mão (pergunta 2).
- **Prova:** o script de sha256 (seção 1) deve dar `faltam 0`, e
  `meow pack validar dracula` deve passar.

### T6. Escolher o pack Dracula liga os desenhos de app dele
- **Medido:** com `PACK=dracula` e o padrão, `scalable/apps` tem 28 ícones;
  com `sim`, tem 230.
- **Causa:** `ICONES_DRACULA="nao"` de fábrica (`meow.conf.exemplo:547`), e
  nem o `meow pack usar` nem o card da home escrevem a chave.
- **Cura na origem:** o padrão da camada vem do pack. Pack que declara
  `icones.apps` próprio já vem ligado, e a chave do conf só serve para
  **desligar**. Assim `pack usar` não precisa de dois passos.
- **Prova:** casa temporária só com `PACK="dracula"` no conf, rodando as
  etapas de ícone: `ls .../MeowSystem-Icons/scalable/apps | wc -l` → 230.

### T7. Exportar um tema de ícones montado e portátil
- **Medido:** o `.meowpack` tem 0 `index.theme`; o tema se chama
  `MeowSystem-Icons` em qualquer pack; o `Comment=` diz Catppuccin.
- **Causa:** só existe o export da receita (`pack.py exportar`). O nome e o
  `Comment` são fixos em `scripts/construir_icones.sh:38` e `:660`.
- **Cura na origem:** um verbo de exportação do tema montado, que gera um tar
  com o tema e a base, nome próprio por pack e flavor
  (`MeowSystem-Dracula-Icons`), `Inherits` só do que vai junto mais `hicolor`,
  e o `Comment` lido do pack. O mesmo nome e o mesmo `Comment` passam a valer
  na instalação local.
- **Prova:** extrair o tar num `HOME` limpo e rodar
  `gtk-update-icon-cache -f`. Todo `Inherits` deve resolver dentro do tar ou
  em `hicolor`; 0 links para fora; `scalable/apps` → 230; `grep -c Catppuccin
  index.theme` → 0 no Dracula.

### T8. O `index.theme` sai certo na primeira passada
- **Medido:** na 1ª passada faltam `48x48/apps`, `scalable/mimetypes` e os
  dois `status` no `Directories=`.
- **Causa:** o índice é escrito antes das etapas que criam essas pastas. Só o
  laço de até 5 repetições do `install.sh` esconde isso.
- **Cura na origem:** o `Directories=` é calculado do disco no fim, por uma
  etapa única, depois de todas as que escrevem no tema.
- **Prova:** uma única passada das etapas de ícone numa casa temporária, e
  então `validar_index.py` sem faltas.

### T9. Os mimetypes e as pastas do Dracula ficam com cor Dracula
- **Medido:** o Dracula herda 3.280 mimetypes `macchiato` do Catppuccin e tem
  7 pastas contra 3.280.
- **Causa:** o pack não declara `icones.mimetypes`, então a herança cai no
  Catppuccin.
- **Cura na origem:** o Catppuccin já traz o flavor `css-variables` (656 SVG
  com cor por variável). Gerar `packs/dracula/icones/mimetypes/dracula` a
  partir dele e do `paleta.json`, pelo gerador do motor, e declarar no
  `pack.json`. As pastas que faltam (`folder`, `user-home`, `user-desktop`)
  são a I7 de `01-regressoes.md`.
- **Prova:** `scripts/pack.py info dracula` deve mostrar
  `icones.mimetypes PRÓPRIO 656`; `grep -L` das cores do macchiato nos SVG
  gerados → todos.

### T10. A base e os simbólicos do tema antigo
- **Medido:** 458 nomes `*-symbolic` do tema antigo não existem em Base + tema
  (318 contando os fallbacks). Dos desenhos do tema antigo, 1.013 vinham da
  `main` e só 32 da `circle`.
- **Causa:** em 24/09 a base pinada passou a ser só a `circle`. O
  `build.sh:267` do antigo copiava os simbólicos da `main`.
- **Cura na origem:** depende da sua decisão (pergunta 1). Se a `main` volta,
  ela entra pinada por sha256 em `icones.base` como segunda camada de
  `Inherits`, do mesmo jeito que a `circle`.
- **Prova:** o `comm -23` entre os nomes `*-symbolic` do backup e os do tema +
  Base deve dar 0, ou só a lista aceita por escrito.

**Fora destes blocos, só registrados:**
- os 8 rascunhos de `.trabalho-icones/` que não estão em commit nenhum (risco
  de perda: decidir se entram);
- o `nyx.svg` órfão em `~/.local/share/icons/MeowSystem-Icons/scalable/apps/`;
- o `index.theme` do upstream herda de `-Dark` (inválido);
- a escrita do painel no clone (I3) também contamina o `.meowpack`.

## 8. Perguntas para quem usa

1. **Base:** voltar à `main` do m4thewz, ficar na `circle`, ou usar as duas
   (circle por cima, main por trás, como o tema antigo)?
2. **PNG feitos à mão (38 + 30):** entram no pack como PNG, viram vetor
   (como os 29 resgatados) ou ficam fora?
3. **Catppuccin no seletor com o Dracula no ar:** a regra da P60 diz que não.
   Sua frase "todos os do MeowSystem feitos" pede que sim. Qual vale?
4. **Os 4 nomes duvidosos** (`calcdeirao`, `jogos`, `rede`, `clima2`) são de
   projeto pessoal?

## Arquivos de prova (scratchpad da sessão, fora do repositório)

`/tmp/claude-1000/-home-andrefarias-Desenvolvimento-MeowSystem/dc213a2a-e0f4-450b-a4ae-66168a57aa5f/scratchpad/`

- `conf/shas.py`, `conf/conta.py`, `conf/links.py`: sha256 de todas as fontes
  e a conta dos 630/480/175.
- `conf/glifos.py`: a rota do seletor chamada no processo, com `HOME`
  temporário.
- `conf/faltam-nomes.txt` e `inv/faltam-175.tsv`: os 175, com sha256.
- `conf/apagados.txt`, `conf/gone.h`: os 23 apagados e os 107 blobs fora do
  HEAD.
- `conf/nomes-perdidos.txt`: nomes do tema antigo ausentes na cadeia nova.
- `conf/trab-fora.txt`: os 8 rascunhos sem commit.
- `export/*.meowpack`, `casa-*/`, `rodar.sh`, `validar_index.py`: a geração e
  a exportação da Frente 3.

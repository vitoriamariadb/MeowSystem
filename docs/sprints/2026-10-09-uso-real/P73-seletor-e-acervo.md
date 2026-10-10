# P73 — O seletor de ícone mostra o acervo inteiro, em pastas

**Branch:** `sprint/p73` · **Fontes:** `docs/pesquisas/2026-10-09-paridade-de-icones.md` (T1–T5),
`01-regressoes.md` (I3, I4, I8, I9), `00-achados-como-usuario.md` (1, 2, 7, 24), `02-decisoes.md` (2, 3, 4).

## Pedido de quem usa (09/10)
«Era pra aparecerem todos os Drácula feitos e todos os do MeowSystem feitos, numa pasta cada.
Independente do app que eu escolher, eu deveria acessar todas as imagens disponíveis, não só as
que mapeamos à mão.» «Sem texto na interface; no máximo vira dica.»

## Tarefas
1. **T1** — fim do teto de 60 por grupo (`servidor.py` ~9174); a ficha abre sem filtro pela 1ª
   palavra (`app.js` ~2981); grupos = pastas por acervo, com contagem, rolagem/paginação e o pack
   no ar primeiro.
2. **T2** — o motor lê todas as pastas (inclui `resgatados/`, `arcticons/`, autorais de todos os
   flavors, `-alucard`). Decisão 3: acervos de TODOS os packs aparecem, cada um na sua pasta.
3. **T3** — busca pelo nome do app (comentário do `apps.map`) e pelo significado (`catalog.json`
   do Dracula_OS-Theme trazido para `packs/dracula/icones/biblioteca/`, linha no PROCEDENCIA.md).
4. **T4** — apps com trava (COSMIC, Hefesto, Fogstripper, mozc): o acervo aparece, e a trava é
   estado visual + dica, não grupo sumido.
5. **T5** — os 175 SVG de `Dracula_OS-Theme/src/icons/current/scalable/apps` entram na biblioteca
   (sha256, PROCEDENCIA). Decisão 2: os 38+30 PNG feitos à mão entram como PNG agora (pasta própria).
   Decisão 4: `calcdeirao` fica fora; `jogos`, `rede`, `clima2` entram.
6. **I3** — escolher ícone no painel NÃO grava no repositório: a escolha vai para o estado do
   usuário (`~/.config/meow/…`); gravar no pack só por gesto explícito («Levar para o pack»).
   Reverter o ` M packs/dracula/icones/apps.map` do dev que o painel sujou.
7. **I8** — syncthing, spotify, discord: os resgatados aprovados entram nos mapas.
8. **I9** — o ícone do lançador do MeowSystem é o `logo.svg` do pack no ar.
9. **Achado 24** — a origem de cada ícone da grade (pack / nosso / traço / de fábrica) vira
   estado visual (selo, cor, agrupamento), sem frase; o «por quê» fica na dica.

## Prova
- teste novo: para cada pasta de acervo, total oferecido == nº de SVG/PNG da pasta (sha256);
  conta `versionados − oferecíveis` sobra só `pastas/`, `gatos/`, `logo.svg`.
- busca: «firefox» acha `net.waterfox.waterfox.svg`; «alienígena» acha `alien.svg`.
- `git status` limpo depois de escolher 3 ícones no painel (teste no repositório real, não em cópia).
- uso real no navegador com prints antes/depois: seletor de 3 apps, busca, troca de ícone.

## Estado da execução — 09/10/2026 (branch `sprint/p73`)

| tarefa | estado | commit |
|---|---|---|
| T1 — sem teto, sem filtro de abertura, pastas com contagem, pack no ar primeiro | feita | `2137c5e` |
| T2 — todas as pastas, de todos os packs, de um lugar declarado (`pack.py acervos_de_icone`) | feita | `d8e316a` |
| T3 — busca pelo comentário do `apps.map` e pelo `catalog.json` (trazido, com linha no PROCEDENCIA) | feita | `b8db432` |
| T4 — trava é estado visual + dica; o acervo nunca some | feita | `a6fee5f` |
| T5 — 174 SVG de `current/` na biblioteca, 39 PNG em `icones/feitos-a-mao/` | feita | `9cd7550` |
| I3 — a escolha vai para `~/.config/meow/icones-escolhidos.map` e `icones-traco.map`; o pack só pelo «Levar para o pack» | feita, menos a reversão no dev (abaixo) | `3034554` |
| I8 — Discord, Spotify e Syncthing no mapa do Dracula | feita | `fabaf5c` |
| I9 — o lançador veste o `logo.svg` do pack no ar | feita | `0d580aa` |
| Achado 24 — origem vira selo (forma), o porquê vai para a dica | feita | `874a5a7` |
| Prova — `tests/acervo-da-ficha.sh`, `restos-do-painel.sh` refeito | feita | `6883982` |
| T1, conserto achado pelo gate — a tira de pastas sobrevive à repintura (o `/previa` é `no-store`: eram 342 pedidos de miniatura a cada `render()` com a biblioteca aberta, agora 0) | feita | `22935c6` |
| Gate `tests/app-completo.py` adaptado (pastas, desenho travado, escolha no estado da casa e raiz intacta) | feita, verde em 543 s | `7cf9b1c` |

**Testes rodados na branch** (HOME de brinquedo; sudo falso onde o teste sobe o painel):
`acervo-da-ficha`, `seletor-do-pack`, `git-limpo`, `restos-do-painel`, `fonte-unica`,
`pack`, `sem-dracula-os-theme`, `notas-de-funcao`, `numeros`, `orfaos`, `arvore`,
`frases-velhas`, `app`, `estilo`, `app-acessibilidade.py` e `app-completo.py` — todos 0.
`portabilidade.sh` sai 1 por `docs/pesquisas/2026-10-09-cosmic-vivo.md:198` (um `/home/<pessoa>`
escrito), arquivo que veio no `f24868c`, antes desta branch.

**O que não deu para fazer como escrito, e por quê:**

- **«Reverter o ` M packs/dracula/icones/apps.map` do dev».** As regras desta leva
  proíbem tocar o checkout principal (`~/Desenvolvimento/MeowSystem`,
  branch `dev`). A linha suja é a escolha dela (`org.kde.ghostwriter : apps/org.gnome.gitlab.somas.Apostrophe.svg`),
  e reverter sem guardar seria desfazer o que ela decidiu. Fica para a integração, nesta
  ordem: (1) acrescentar ao `~/.config/meow/icones-escolhidos.map` dela a linha
  `org.kde.ghostwriter : packs/dracula/icones/apps/org.gnome.gitlab.somas.Apostrophe.svg   # ghostwriter — escolhido no painel`;
  (2) `git -C ~/Desenvolvimento/MeowSystem checkout -- packs/dracula/icones/apps.map`;
  (3) rodar o passo do pack (`scripts/icones_apps_dracula.sh aplicar`). O `.gitignore` do
  dev também está ` M`, e esta branch muda o `.gitignore` (a exceção dos PNG): conferir o
  merge dessas duas mudanças.
- **T5, «faltam 0».** Dos 175, entraram 174: o `calcdeirao.svg` fica fora pela decisão 4.
  Três entraram sem o atributo `inkscape:export-filename` (guardava `/home/<nome>/`, que o
  `validar` recusa), então o sha256 da cópia difere do da origem; a linha do PROCEDENCIA
  guarda os dois. Dos PNG, 13 dos 30 do tema antigo têm os mesmos bytes de
  `src/icons/projects/` (projetos pessoais) e ficaram fora pela mesma regra de 23/09.
- **T5, PNG escolhíveis.** Os 39 PNG aparecem na ficha, apagados, com a dica: raster não é
  fonte (`meow_icones_derivados`), e a decisão 2 manda vetorizar num lote por RMSE. O lote
  não foi feito aqui.

## Conferência — 09/10/2026

Cada tarefa refeita na branch, com HOME de brinquedo e sudo falso no PATH:

- **T1–T4:** `tests/acervo-da-ficha.sh` dá 0. São 814 desenhos em 15 pastas, sem corte.
  «firefox» acha o `net.waterfox.waterfox.svg`, e «alienígena» e «alienigena» acham o
  `alien.svg`. A rota leva 0,11–0,17 s e devolve 294 KB.
- **T5:** dos 175 da lista da auditoria (`faltam-175.tsv`), por sha256, 171 estão no pack. Os
  três sem `inkscape:export-filename` têm o sha da origem na linha deles. O `calcdeirao` fica
  fora. `pack.py validar dracula` sai 0, e os 584 sha256 do PROCEDENCIA batem com o disco.
- **I3:** o passo do pack rodou 3 vezes com duas escolhas, com a camada ligada e desligada, e
  é idempotente: rc 1, depois 0 e 0, e o `--conferir` dá 0. Desfeita uma escolha, o desenho sai
  do tema pelo registro (P66). O `icones-traco.map` com glifo por caminho também é
  idempotente no `icones_apps_arcticons.sh`. A seção 3b do `git-limpo.sh` sai 0 no
  repositório de verdade.
- **I8:** o `fonte` dos três nomes aponta para `apps/` do pack. Os `Icon=` reais da máquina
  são os mesmos do mapa.
- **I9:** o `com.meowsystem.Painel.svg` instalado pelo `completar_icones.sh` é igual à saída
  do `pack.py logo dracula dracula mauve`, e a segunda passada e o `--conferir` saem 0.

**Corrigido nesta conferência:** escolher um **traço** depois de um **desenho** para o mesmo
app respondia ok, e a tela ficava com o desenho, porque a escolha de desenho mora no
`scalable/apps`, que vence o `48x48/apps`. Agora o traço tira a escolha de desenho, e a
página roda também o passo do pack. A prova está no fim do `tests/seletor-do-pack.sh`.

**Isenção registrada, sem mudança:** a conta por sha256 do `tests/acervo-da-ficha.sh`
deixa fora os 3.280 `mimetypes/` do Catppuccin antes de contar. A frase do teste não os
cita. A spec só nomeia `pastas/`, `gatos/` e `logo.svg`. O motivo é o mesmo das pastas, e o
`pack.py` o escreve: tipo de arquivo não é ícone de aplicativo.

## Achados para a próxima leva

- O lote de vetorização dos 39 PNG de `packs/dracula/icones/feitos-a-mao/` (decisão 2): até
  ele, nenhum dos 39 entra no tema.
- Os 39 PNG pesam 41 MB (o `clapper.png` sozinho, 7,8 MB) e viajam no `.meowpack` do
  Dracula; o teto de envio do painel é 64 MB. Medir o `exportar` depois da P74.
- «Adicionar ícone» (`/api/acervo`, tipo `icone`) grava em `assets/icones/overrides/`, dentro
  do clone, e essa pasta não está em nenhuma pasta da ficha: o desenho enviado nem aparece
  para ser escolhido. Mesma dívida da P21.
- A oficina de desenho («Usar» da oficina) ainda grava `apps-convertidos.map` e
  `convertidos-apps/retoques/` no clone (o `tests/git-limpo.sh` lista como pendente).
- A prévia flutuante da página Ícones (achado 6) aparece por cima da grade nos prints desta
  sprint — é da P77.
- `scripts/icones_apps_dracula.sh`: o comentário «O PADRÃO É `nao`» do `_dracula_aplicar` vai
  envelhecer com a T6 da P74.
- (conferência) A nota «O desenho de «…» entra com as cores dele: a cor abaixo vale só para o
  traço» era da P60 e só aparecia com desenho de pack. Agora aparece com qualquer desenho
  marcado, e é frase na tela. O princípio pede estado visual, por exemplo apagar a fileira de
  cores quando um desenho está marcado.
  [Resolvido no QA de uso, 72d9bf3: a fileira se apaga e a frase foi para a dica dela.]
- (conferência) Abrir a pasta «feitos à mão (PNG)» baixa os 39 PNG inteiros, 41 MB, como
  miniatura, e o `/previa` responde `no-store`. Uma miniatura reduzida resolve.
- (conferência) Os desenhos de 4 mimetypes e de 6 pastas coloridas da leva da T5 estão na
  `biblioteca/` e aparecem na ficha como ícone de app. Os de `pastas/` e os `mimetypes/` ficam
  de fora.
- (conferência) No `app/pagina/app.js`, o `const comBusca = true` da T4 sobrou como constante
  morta, sem efeito.
- (QA de uso) O «Usar este ícone» com desenho roda o «Pôr os desenhos do pack na tela» na hora
  (desde a P60): escreve em `~/.local/share/icons/MeowSystem-Icons/scalable/apps` e reindexa a
  cache. Quem testa o painel com o HOME real escreve no tema da máquina ao escolher um ícone;
  o QA desta leva escreveu três arquivos assim e os tirou (ver o relatório). Teste de uso do
  seletor só com HOME temporário.
- (QA de uso) A ficha marca a escolha dela (7602ec3) e o traço vestido, mas não o desenho do
  pack que o app já veste sem escolha (o Waterfox abre com o `net.waterfox.waterfox` do pack
  sem marca). Falta o servidor dizer qual arquivo veste o app.
- (QA de uso) A busca «firefox» não acha a raposa roxa resgatada
  (`resgatados/net.waterfox.waterfox.svg`): a linha do Waterfox saiu do `apps-resgatados.map`
  na P28, e com ela o nome que a busca casaria.
- (QA de uso) O Discord resgatado (`apps/com.discordapp.Discord.svg`) é roxo-escuro sobre o
  fundo escuro da ficha e quase some na miniatura; é da arte, não do seletor.

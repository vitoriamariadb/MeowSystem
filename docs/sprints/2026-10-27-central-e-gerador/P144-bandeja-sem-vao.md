# P144 — a Bandeja abre do tamanho dos ícones, sem vão

Anotada em 29/10, com captura dela: «fica um espação vazio na bandeija tambem». Com um ícone só na bandeja, o
popup abre largo, o ícone fica à esquerda e o «| ⚙» colado na borda direita, com um vão vazio no meio.

## O que se mediu (fork `vitoriamariadb/meowsystem-status-hub`, `main` 8e869d5, pino `assets/extensoes/status-hub.pino`)
- `src/applet/popup.rs`: `tray_grid_width()` = `SURFACE_WIDTH` menos a coluna da ação; o `tray_row` põe a grade em
  `container(..).width(Length::Fill)`, e o popup tem largura fixa (`size_limits`, `SURFACE_WIDTH`). A engrenagem
  vai para a borda direita qualquer que seja o número de ícones.

## Cura na origem (no fork; o MeowSystem só atualiza o pino)
- A largura do popup segue o conteúdo: ícones × (largura do item + espaço) + traço + engrenagem + margens, com
  `SURFACE_WIDTH` como teto (acima dele a grade quebra em linhas, como hoje). O «| ⚙» fica logo depois do último
  ícone, à direita deles, separado pelo traço (o pedido de 28/10 da P136 continua valendo).
- Bandeja vazia: só a engrenagem, popup pequeno.

## Prova
- No fork: teste da função de largura (1, 3 e muitos ícones; vazio), `cargo build --release --locked` e
  `cargo test --release --locked` verdes; commit e push na `main`.
- No MeowSystem: pino com `COMMIT` e `VERSAO` novos; `tests/extensoes.sh` verde; depois do install, captura da
  Bandeja aberta sem vão.

## Execução

- Fork `meowsystem-status-hub`, `main`, publicado no origin:
  - `c9e7943` a largura do popup acompanha a quantidade de ícones. `popup.rs`: `tray_columns`, `tray_icons_width`
    e `tray_surface_width` (ícones × largura do item + espaços + traço + engrenagem + margens, com teto em
    `SURFACE_WIDTH`; vazio = margem, engrenagem, margem). O `tray_row` fixa a largura da grade nos ícones (o
    `flex_row` da libcosmic ocupa sempre o máximo que recebe, e era isso que abria o vão) e a engrenagem vem logo
    depois do traço. `mod.rs`: `hub_width()` dá a largura à superfície do hub e ao tamanho inicial do popup, para
    ele nascer pequeno em vez de encolher depois.
  - `06a9749` e `7fa8824`: versão 1.7.1 (`Cargo.toml`, `Cargo.lock`, metainfo).
- Prova no fork: `cargo build --release --locked` e `cargo test --release --locked` verdes (262 testes da lib, mais
  os de integração), com testes novos de 1, 3, muitos ícones (quebra em 5 colunas e fica abaixo do teto) e vazio.
- Pino `assets/extensoes/status-hub.pino`: `COMMIT=7fa8824…`, `VERSAO=1.7.1`; `LIBCOSMIC` a401af8 confere com o
  `Cargo.lock`. Provas com o HOME temporário do arranjo do `todos.sh`: `extensoes.sh`, `applet-pino.sh`,
  `extensoes-gesto.sh`, `cadeia-de-atualizacao.sh` e `extensoes-install.sh` verdes (este exigiu avançar o clone
  `~/Desenvolvimento/forks/meowsystem-status-hub` para o 7fa8824, fast-forward local).
- Com o menu de um item aberto no hub, o popup volta a `SURFACE_WIDTH` (o menu precisa da largura); os ícones e a
  engrenagem ficam juntos à esquerda. Configurações também seguem em `SURFACE_WIDTH`.
- Falta: o install do binário e a captura da Bandeja aberta sem vão (o coordenador instala no fim). A largura
  exata do encaixe do `flex_row` (soma igual ao máximo) não foi vista numa tela real.

### Conferência (29/10)

- O diff do fork confere com o que a libcosmic faz: o `flex_row` (taffy, `flex_wrap`) recebe do `container`
  `Fixed(icons_width)` exatamente colunas × item + (colunas − 1) × espaço; a linha tem item, espaço `ACTION_GAP`,
  traço de 1, `ACTION_GAP`, engrenagem de 32 e margem 16, o que é a `action_column()`. O `autosize` do hub mede o
  conteúdo com os próprios limites (1 a `SURFACE_WIDTH`), então o popup encolhe e cresce junto. Vazio, um ícone,
  quebra de linha, densidade (o `spacing` do painel entra igual na conta e no `flex_row`) e painel vertical (o
  mesmo `button_size()` na conta e no botão) não deixam vão nem cortam ícone. Zero comentário.
- Achado: os testes do implementador provavam só a aritmética; nada mostrava o `flex_row` deitando os ícones na
  largura calculada, e o caso da soma igual ao máximo ficou sem prova. Correção: fork `ebce4f6`, teste que monta o
  `tray_row` dentro do `hub_surface` e faz o layout de verdade (renderizador tiny-skia, sem GPU), para 0 a 12 ícones
  em quatro geometrias, conferindo a largura do popup, o número de linhas, a borda direita dos ícones, o traço e a
  engrenagem a 16 da borda; e o caso de encaixe exato (5 × 51 + 4 × 6 = 279, a grade inteira) numa linha só. Com a
  grade 1 px menor o teste fica vermelho. `cargo build --release --locked`, `cargo test --release --locked` (264 da
  lib) e o `clippy -D warnings` da CI verdes; push na `main`.
- Pino: `COMMIT=ebce4f6…` (commit `27724160`), `VERSAO` segue 1.7.1 (só teste), `LIBCOSMIC` a401af8 igual ao
  `Cargo.lock`; o clone `~/Desenvolvimento/forks/meowsystem-status-hub` avançou para o `ebce4f6`.
- `./tests/todos.sh` inteiro na worktree: 118 verdes, 2 vermelhos aceitos (`readme.sh`, badge v2.2.0;
  `restaurar.sh`, `pack_usar` e `desinstalar`).
- Fica para a tela: com o menu de um item aberto o popup volta a 360 e sobra espaço à direita da engrenagem (o
  menu precisa da largura); o popup centraliza sob o botão (gravidade do painel) ao mudar de largura.

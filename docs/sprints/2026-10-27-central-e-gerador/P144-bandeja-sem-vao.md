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

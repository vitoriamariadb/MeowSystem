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

# P239 — a janela marcada nasce na área «OS», sem piscar nem roubar o foco (17/11/2026)

Texto de quem usa, 17/11, sobre o plano B do P238 («ou usar o workspace os», «ou só o monitor da tela direita»):
«Pode criar a Sprint e integrar e executar via agente ela?»

## O que se mediu (bloco K, leitura do código, sem janela)
- `cosmic-comp`, `shell/mod.rs` `map_window`: janela nova nasce na área ativa da tela ativa e ganha o foco do teclado.
- O token do `xdg-activation` só aponta para a área ativa quando foi criado: não mira «OS».
- `zcosmic_toplevel_manager_v1.move_to_ext_workspace` (v4) e `move_to_workspace` movem a janela depois de nascer,
  inclusive para a tela da direita, mas ela aparece um quadro na área dela e rouba o foco até mover.
- O caminho sem piscar existe dentro do compositor: o de janela «urgente» (`was_activated`) já põe a janela em
  outra área sem trocar a que ela vê.

## A cura na origem
Patch novo na série do compositor (`patches/series`, no molde do `cosmic-comp-app-id-do-cliente.patch`, que já lê
o cliente): no `map_window`, se o processo do cliente (pid pelas credenciais do socket, `/proc/<pid>/environ`) tem
`MEOW_AREA=<nome>`, a janela nasce na área de trabalho com esse nome (o nome do `pinned_workspaces`/`AREAS_NOMES`)
e, se houver `MEOW_TELA=<saída>`, nessa tela; não troca a área visível, não ganha o foco do teclado e não marca
urgente. Sem a variável, nada muda. Nome que não existe: comportamento de fábrica e uma linha no log.
O `scripts/palco.sh` ganha o modo «na área» (`palco.sh rodar --area OS <app>`) que roda o app na sessão real com
`MEOW_AREA` (plano B do P238), só para o que o palco headless não prova; o GSD diz quando ele vale.

## Como se prova
- Teste de unidade no patch (a leitura do ambiente do cliente e a escolha da área) com `cargo test` na árvore com
  a série aplicada; a série aplica limpa no commit fixado.
- No palco headless (que roda a build do compositor do MeowSystem): duas áreas com nome, a ativa «Pop»; um app com
  `MEOW_AREA=OS` aparece em «OS» (sonda das áreas e janelas do palco), a área visível segue «Pop» e o foco segue na
  janela que o tinha.
- Na máquina (coordenador, depois do `meow compositor` e do login): `MEOW_AREA=OS zenity --info` não aparece na
  área dela.

## Medido (agente do bloco, 17/11)
- `patches/cosmic-comp-area-do-cliente.patch` (`AURORA-AREA-DO-CLIENTE-1`), `req`, antes do
  `cosmic-comp-nomes-nas-duas-telas.patch`, que segue o último. A série inteira aplica com `-F0` e sem
  deslocamento no fonte do `ec674cd` (o instalado e o que o shim aponta) pelo `compositor_patches.sh aplicar`.
  O fonte do `66524a0`, a última linha de `patches/versao`, não está nesta máquina.
- O pid vem das credenciais do soquete Wayland e, no X11, do `_NET_WM_PID`. Janela filha segue a mãe. O nome casa
  sem o U+2007 do `AREAS_NOMES`. Sem `MEOW_TELA`, vale a área da tela ativa.
- `cargo build --release` limpo, sem aviso; `cargo test --lib area_do_cliente`: 7 de 7.
- Palco headless com o binário do patch (`AREA_OS_COMPOSITOR=<binário> tests/area-os.sh`): duas áreas, Pop e OS.
  A janela com `MEOW_AREA=OS` nasce em OS, tanto pelo Wayland quanto pelo X11. Pop segue visível, OS não fica
  urgente, o foco segue na janela que o tinha, e a foto de Pop não muda nem um pixel. Com nome ou tela que não
  existem, o comportamento é o de fábrica, com uma linha no log. Sem o patch (a mesma série, sem ele), a janela
  nasce em Pop e toma o foco.
- `palco.sh areas` (a sonda `appid_sonda.py --areas`) e `palco.sh rodar --area <nome> [--tela <saída>] <cmd…>`:
  roda na sessão de quem chama e recusa sem sessão, com compositor sem o marcador, área que não existe ou área na
  tela. Com o build de hoje (sem o patch), o `tests/area-os.sh` prova a recusa e sai `pulado` até o
  `meow compositor`.

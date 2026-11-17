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

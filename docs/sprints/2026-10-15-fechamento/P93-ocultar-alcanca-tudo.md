# P93 — O `ocultar` alcança flatpak e home

**Status: REGISTRADA em 17/10 pela P91 — NÃO executar sem quem usa mandar.**
Origem: [`docs/pesquisas/2026-10-17-vizinhos.md`](../../pesquisas/2026-10-17-vizinhos.md), falha F3.

## O que se mediu
O `scripts/ocultar_apps.sh` marca `NoDisplay=true` só em `/usr/share/applications` (pela ponte e pelo
gancho do apt). Em `~/.local/share/applications` há 25 cópias INTEIRAS de `.desktop` postas pelo
`Dracula_OS-Theme/scripts/aplicar_overrides.sh` em 15/09 (24 iguais byte a byte às de `overrides/`,
medido com `cmp`; a do Mozc difere). Onze dos aplicativos que elas escondem não estão no
`LANCADOR_OCULTAR` (KeePassXC, gThumb e o importador dele, File Roller, COSMIC Monitor e Screenshot,
Contas Online, Mozc, Ubuntu e dois projetos pessoais), e parte deles é flatpak ou do home — o
MeowSystem não teria como escondê-los. As cópias também congelam o `.desktop`: um
update do app não chega ao lançador, e o `Name=`/`Icon=` que o MeowSystem escreve no original fica
escondido atrás delas.

## A causa
O `ocultar` nasceu para o que vem do apt; app de flatpak e do home não têm arquivo em
`/usr/share/applications`.

## A cura na origem
- para o que não está em `/usr/share`, uma sombra de mesmo basename em `~/.local/share/applications`
  com só o necessário e a marca do MeowSystem (o mesmo mecanismo da sombra do applet de mídia),
  refeita quando o original muda;
- a lista continua sendo o `LANCADOR_OCULTAR` do `meow.conf`; quem usa decide se os 11 que só o
  Dracula escondia entram nela (a escolha foi dela em 15/09, no outro repositório).

## Como se prova
Teste com um flatpak e um app do home de brinquedo: o doctor vê, o `--consertar` esconde, a
segunda passada não escreve, e o `--reverter` devolve. Depois: as 25 cópias saem por
`scripts/vizinhos.sh --desativar` (um tipo novo, que move o arquivo para a cópia datada e o devolve no
`--restaurar`, com os itens no `contratos/vizinhos.tsv`) e o `aplicar_overrides.sh` é desativado no Dracula.

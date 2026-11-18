# Estado da leva de 17/11 (coordenador)

| tarefa | árvore / branch | situação |
| --- | --- | --- |
| P212 navegadores no modo GTK | `.meow-wt-navegadores` / `bloco/navegadores` | escrita; agentes a lançar |
| P213 Electron | `.meow-wt-toolkits` / `bloco/toolkits` | escrita; agentes a lançar |
| P214 Qt e outros formatos | `.meow-wt-toolkits` / `bloco/toolkits` | escrita; agentes a lançar |
| P220 arte dos botões do Dracula | `.meow-wt-arte-botoes` / `bloco/arte-botoes` | escrita; bloco C, entra quando A ou B voltar |
| P231 vagas no pack e no criador | `.meow-wt-produto` / `bloco/produto` | conferido (`3bf3632f`, `05d071ea`, `b15e99c0`, `3e48f9d5`); suíte inteira, cargo test da Soneca 41/41; Soneca `67741ed` em `../meowsystem-soneca-p231`, sem push: o `extensoes-install.sh` só fica verde depois do push e do clone em `~/.local/state/meowsystem/extensoes/soneca/src` |

| Quadro de arte (Soneca no pack, botões no criador e no MeowSystem, notificação, rede, bateria, papéis SVG dia e noite) | <https://claude.ai/artifact/WkX5Moc3PoYQt6H1rkzZrP> | publicado 17/11; esperando as escolhas (coleção `escolhas`) para virar sprints e o workflow de desenho |

Pedido de 17/11: workflows liberados sem teto de agentes nem de cota nesta leva («Sem limitação de percentual e sem
limitação de uso […] aumentarmos a qualidade do produto como um todo»).

## Próximo passo
1. Criar as duas árvores a partir do `master` e lançar os dois workflows (4 agentes: 2 por bloco).
2. Integrar cada bloco em `integracao/2026-11-17` quando o conferente voltar; suíte inteira; `master`; push.
3. Coordenador: `meow doctor --consertar` real com Chrome e Edge fechados; quem usa confere as fotos.

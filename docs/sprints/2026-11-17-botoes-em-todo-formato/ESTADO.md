# Estado da leva de 17/11 (coordenador)

| tarefa | árvore / branch | situação |
| --- | --- | --- |
| P212 navegadores no modo GTK | `.meow-wt-navegadores` / `bloco/navegadores` | escrita; agentes a lançar |
| P213 Electron | `.meow-wt-toolkits` / `bloco/toolkits` | escrita; agentes a lançar |
| P214 Qt e outros formatos | `.meow-wt-toolkits` / `bloco/toolkits` | escrita; agentes a lançar |
| P220 arte dos botões do Dracula | `.meow-wt-arte-botoes` / `bloco/arte-botoes` | conferido; folha aprovada por quem usa 17/11 («Aprovo»); restaurar = grade meio erguida («Grade meio erguida», AskUserQuestion 17/11), feito pelo coordenador; pronto para integrar |

| Quadro de arte (Soneca no pack, botões no criador e no MeowSystem, notificação, rede, bateria, papéis SVG dia e noite) | <https://claude.ai/artifact/WkX5Moc3PoYQt6H1rkzZrP> | publicado 17/11; esperando as escolhas (coleção `escolhas`) para virar sprints e o workflow de desenho |

Pedido de 17/11: workflows liberados sem teto de agentes nem de cota nesta leva («Sem limitação de percentual e sem
limitação de uso […] aumentarmos a qualidade do produto como um todo»).

| P231 vagas no pack e no criador (D) | `.meow-wt-produto` / `bloco/produto` | workflow no ar (3 agentes) |
| P232 arte do Dracula na barra (E) | `.meow-wt-arte-dracula2` / `bloco/arte-dracula2` | espera o P220 voltar; nasce do `bloco/arte-botoes` |
| P233 arte do MeowSystem (F) | `.meow-wt-arte-meow` / `bloco/arte-meow` | conferido e corrigido (`b2aaa8a7`, `2ac2d2cc`); testes de ícone e procedência verdes; falta quem usa escolher na folha (no lugar: arranhão, novelo, peixe; em `biblioteca/`: espinhas, gato deitado, tigela); depois, integrar |
| P234 papéis dia e noite (G) | `.meow-wt-papeis` / `bloco/papeis` | conferido (`4d461716`, `e76a0d33`): 6 pares em `packs/*/wallpapers/pares/<cena>-{dia,noite}.svg`; na integração, casar com a declaração de par do P231; folha em `fotos/pares-dia-e-noite.jpg` para quem usa |

## Próximo passo
1. Criar as duas árvores a partir do `master` e lançar os dois workflows (4 agentes: 2 por bloco).
2. Integrar cada bloco em `integracao/2026-11-17` quando o conferente voltar; suíte inteira; `master`; push.
3. Coordenador: `meow doctor --consertar` real com Chrome e Edge fechados; quem usa confere as fotos.

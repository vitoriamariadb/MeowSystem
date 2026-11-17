# Estado da leva de 17/11 (coordenador)

| tarefa | árvore / branch | situação |
| --- | --- | --- |
| P212 navegadores no modo GTK | `.meow-wt-navegadores` / `bloco/navegadores` | escrita; agentes a lançar |
| P213 Electron | `.meow-wt-toolkits` / `bloco/toolkits` | escrita; agentes a lançar |
| P214 Qt e outros formatos | `.meow-wt-toolkits` / `bloco/toolkits` | escrita; agentes a lançar |
| P220 arte dos botões do Dracula | `.meow-wt-arte-botoes` / `bloco/arte-botoes` | desenhada e conferida: fechar ossos de pirata, `+` cruz de Malta, minimizar morcego de asas abertas (dentro da margem de 1 px), maximizar grade levadiça (viga de 1 px, uma travessa, pontas longas; tinta de 47% para 42% em 16 px); restaurar (duas lápides) fica; testes de ícone e procedência verdes; falta quem usa aprovar a folha antigo × novo e decidir se o restaurar vira duas grades |

| Quadro de arte (Soneca no pack, botões no criador e no MeowSystem, notificação, rede, bateria, papéis SVG dia e noite) | <https://claude.ai/artifact/WkX5Moc3PoYQt6H1rkzZrP> | publicado 17/11; esperando as escolhas (coleção `escolhas`) para virar sprints e o workflow de desenho |

Pedido de 17/11: workflows liberados sem teto de agentes nem de cota nesta leva («Sem limitação de percentual e sem
limitação de uso […] aumentarmos a qualidade do produto como um todo»).

| P231 vagas no pack e no criador (D) | `.meow-wt-produto` / `bloco/produto` | workflow no ar (3 agentes) |
| P232 arte do Dracula na barra (E) | `.meow-wt-arte-dracula2` / `bloco/arte-dracula2` | desenhada e conferida: Soneca (morcego da noite em voo e morcego do dia pendurado, em contorno, fora do círculo; o pendurado foi redesenhado com as asas fechadas, a cabeça com as orelhas para baixo e o «z» maior, porque lia como sino; vagas `soneca-desperto-symbolic` e `soneca-ronronar-symbolic` no `sistema.map`), notificação (sino menor com o morcego de asas abertas da casa no lugar do badalo; corvo chegando; não perturbe = sino apagado com a teia no canto, porque a teia grande escondia o sino), Wi-Fi em ecolocalização (quatro arcos por nível), cabo em corrente (desconectado agora são dois elos separados com o estalo da quebra, distinto em 16 px) e bateria em vela no lugar (39 vagas, com `ac-adapter`; a vela inteira aparece apagada atrás, para o nível ler como medidor); teia e as baterias frasco e ampulheta em `packs/dracula/variantes/` (fora de `icones/`, que não aceita subpasta); traço convertido em silhueta, porque o `icones_sistema.sh` injeta a espessura do MeowSystem em todo `stroke="currentColor"`; testes de ícone, pack e procedência verdes; falta quem usa escolher na folha antigo × novo × variantes |
| P233 arte do MeowSystem (F) | `.meow-wt-arte-meow` / `bloco/arte-meow` | workflow no ar (2 agentes) |
| P234 papéis dia e noite (G) | `.meow-wt-papeis` / `bloco/papeis` | workflow no ar (2 agentes) |

## Próximo passo
1. Criar as duas árvores a partir do `master` e lançar os dois workflows (4 agentes: 2 por bloco).
2. Integrar cada bloco em `integracao/2026-11-17` quando o conferente voltar; suíte inteira; `master`; push.
3. Coordenador: `meow doctor --consertar` real com Chrome e Edge fechados; quem usa confere as fotos.

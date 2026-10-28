# Conferência do bloco ícones do sistema: P131

Branch `bloco/icones-sistema`, os 9 commits de `8e0efb2a` a `7d5cac6f`, contra `integracao/central-e-gerador`.

## O que conferi
- O inventário: `scripts/inventario_do_sistema.py conferir` nesta máquina dá 167 medidos, 168 no contrato e 0
  faltando. O nome a mais é o `network-wireless-signal-none-symbolic`, que fecha a família do wifi.
- A cura está na origem: os desenhos e os mapas moram em `packs/<pack>/icones/`, e o `icones_sistema.sh` lê a pasta
  de cada nome no contrato. O traço só entra em desenho de traço, e o `construir_icones.sh` declara `actions` e
  `devices` no índice. A instalação roda antes do índice (`etapa_icones_sistema` vem antes de `etapa_icones_indice`).
- `tests/icones-do-sistema.sh`, rodado de novo: os 168 nomes saem dentro do tema, nos dois packs, sem passar pelo
  `Inherits`. Num HOME temporário, nenhum nome do contrato cai no Papirus.
- As folhas de contato. Instalei os dois packs numa casa de brinquedo e montei uma folha por família, com o
  MeowSystem e o Dracula lado a lado, em 16, 24 e 48 px, a partir do tema instalado. Elas estão em
  `capturas/p131-conferencia-*.png`, na árvore do bloco. Olhei também as folhas do implementador e as quatro
  capturas do painel.
- As famílias estão inteiras e os estados se distinguem: wifi, rede por cabo, volume, microfone, bateria nos
  quatro jeitos, brilho, bluetooth, notificações e energia. O Dracula não usa traço do MeowSystem em nenhum nome
  do sistema. Nenhum desenho de um pack aparece no outro: o teste confere pelo sha256, e eu conferi nas folhas.
  A única exceção é o molde dos tipos de arquivo, que o Dracula herda pintado com a paleta dele (P96).
- O painel: aba Sistema com os cinco grupos e Biblioteca, nos dois packs, pelas capturas p131-*.png. Comparei com
  a maquete da leva anterior (`a/` e `b/`). A moldura, os blocos e a grade são os mesmos da aba Apps.

## Achados e correções
| # | achado | correção | commit | prova |
|---|---|---|---|---|
| 1 | MeowSystem: cinco páginas das Configurações usavam logo de app do Arcticons, não glifo de sistema. Aplicativos padrão e Áreas de trabalho eram um quadro com as letras «STAR» e «TILE». Acessibilidade era uma chave. Aparência era um celular. A Dock era a mesma casa do `user-home`. | cinco desenhos no traço do pack: estrela no círculo, duas áreas empilhadas, pessoa no círculo, paleta e tela com a dock. Os cinco logos foram para a `biblioteca/`, e o PROCEDENCIA passou a contar 137 glifos de traço. | 4bdd8739 | `capturas/p131-conferencia-resto.png`; `icones-do-sistema.sh` verde |
| 2 | Dracula: a bateria com limite de carga parecia a lixeira do mesmo pack. A barra do teto era mais larga que o corpo e ficava logo abaixo do polo, como a tampa do `edit-delete`. Em 80%, a limitada só se distinguia da comum por essa tampa. | o teto virou um bloco cheio dentro do corpo, colado no polo, com uma folga antes da carga (`clipPath`). Isso vale para os 16 desenhos (8 níveis, com e sem carregar), e os sha256 do PROCEDENCIA foram refeitos. | 5da43358 | `capturas/p131-conferencia-bateria-l.png` e `-bateria-lc.png`; `pack-dracula-completo.sh` verde |
| 3 | Dracula: os três pontos estavam trocados. O dracula-icons desenha o `view-more-symbolic` deitado e o `view-more-horizontal-symbolic` em pé. Cosmic, Adwaita e Papirus fazem o contrário, e o menu de três pontos do COSMIC saía deitado. | o `sistema.map` do Dracula entrega cada desenho do upstream no nome certo. Os arquivos continuam idênticos ao upstream, como o PROCEDENCIA diz. | f1ee59ee | `capturas/p131-conferencia-resto.png` (as linhas `view-more`); `icones-do-sistema.sh` verde |
| 4 | a `## Execução` da sprint dizia 132 desenhos novos no MeowSystem | 137, contado no lugar | o mesmo commit deste relatório | — |

## O que ficou como estava, de propósito
- Os desenhos próprios do dracula-icons: `help-about` é uma estrela de quatro pontas, `system-log-out` é só a seta
  e `image-red-eye` é o olho riscado. É o estilo do pack, e a sprint pede o estilo dele.
- Os tipos de arquivo repetem desenho: vários tipos usam o mesmo molde, como os dez de «Zip» e os dez de «Image».
  O grupo mostra um item por nome que o tema instala, como a sprint pede. Os rótulos em inglês já eram pendência
  do implementador.
- O microfone do MeowSystem a 16 px: o alto e o médio ficam próximos, mas o enchimento ainda separa os dois. A
  barra usa 22 px, onde a diferença aparece.

## Placar
Rodados sozinhos depois das correções: `icones-do-sistema.sh`, `pack-dracula-completo.sh`, `tres-pastas.sh`,
`pastas-do-pack.sh`, `acervo-do-pack-em-edicao.sh`, `pack-traz-o-que-usa.sh`, `arvore.sh`, `pack.sh` e
`icones-por-pack.py`. Deram 9 verdes, e o `icones-por-pack.py --fotos` refez as capturas `p131-sistema-*` e
`p131-biblioteca-*`.

Último `./tests/todos.sh`, em `f1ee59ee`: 109 testes, 107 verdes, 0 pulados, 2 vermelhos. Os dois são aceitos:
- `decisoes.sh`: a GPU do compositor, e a decisão 24, porque o `tests/enxugar.sh:243` cita `docs/pesquisas/`. O
  arquivo veio do `dev`, fora deste bloco.
- `restaurar.sh`: `pack_usar` e `desinstalar`.

Os três testes que o implementador consertou e não tinha rodado na suíte inteira passam no `todos.sh`. Houve 6
chamadas de `sudo` recusadas, todas de leitura, e nenhum teste escreveu no sistema.

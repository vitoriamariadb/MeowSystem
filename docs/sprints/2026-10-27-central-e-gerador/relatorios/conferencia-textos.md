# Conferência do bloco Textos (P119 → P118), 27/10/2026

Branch `bloco/textos`, worktree `~/Desenvolvimento/MeowSystem-textos`. Conferidos os 17 commits do implementador
(`ea1b7d02` a `0212ae57`) contra as duas sprints. As telas tocadas foram abertas headless numa casa de brinquedo
(`tests/app-completo.py` como base) e comparadas com a foto 3 e com a maquete `qa-final/maquete/a/definir.js`.

## O que está certo e foi provado de novo
- **Busca de programas (P119 item 1).** O combobox é o da maquete (`sugestoes()`/`porFicha()`): ícone, nome, id
  pequeno, até 8 opções, setas, Enter, Esc. O campo tem 360 px nas duas listas, com o texto «Esconder um programa»
  e «Impedir um programa», e a lista abre na largura do campo. Não sobra `datalist`.
  `app-completo.py --aba ajustes/programas` verde (118 conferências); `p113-navegador.py` verde.
- **Spotify em Manter (item 2).** O cartão diz «Tema do Spotify», com «Resolver» → `apps_aplicar`.
  `--aba cuidar` verde (169 conferências), e a captura confirma o cartão.
- **Som (item 3).** A conferência roda antes do `meow_guardar_pasta`. `sons-do-pack.sh` seção 6 verde.
- **Citações de `docs/pesquisas/` (item 4).** As seis citações abrem com `git show 1b15ccb1^:…`, e as três
  pesquisas citadas existem nessa ponta. A regra nova da decisão 24 está no `decisoes.sh`. O patch do compositor só
  mudou no cabeçalho, e o build não lê hash do patch.
- **Imagens órfãs (item 5).** Nenhum arquivo cita as três, e o `orfaos.sh` está verde.
- **P118, painel.** Na captura, o Tema mostra «Aplicar tema», e o passo 5 do Personalizar mostra «Disponibilizar»
  com o botão «Aplicar tema». O README fecha com «Aplicar tema troca o pack.».

## Achados e correções
| # | achado | correção | commit | prova |
|---|---|---|---|---|
| 1 | `icones_tray_zapzap.sh:212` dizia «ícone da bandeja do ZapZap **recom o** Arcticons». A troca de «vestido de» por «com o» comeu o «revestido de». A sprint pedia «refeito com». As duas linhas do protocolo FABRICA/ESCRITO ainda diziam *vestir* e eram isentadas da classe 8. | «refeito com o Arcticons». O protocolo diz «aplicar»/«aplicado», e a isenção sai. A classe 8 passa a barrar também «recom o». | `e8202c77` | `frases-velhas.sh` verde. Com o arquivo velho plantado, a classe 8 acusa as 3 linhas. |
| 2 | A classe 9 (saída que manda digitar) só pegava as formas exatas das cinco linhas consertadas: «com:», «ou:», «é:». Outras onze saídas de `scripts/` ainda mandavam digitar, por exemplo «pede: meow areas aplicar», «refazer: meow compositor», «bana uma a uma: meow wallpaper banir», «para ver agora: meow painel reciclar» e «Ele é seu: meow pack remover». | A classe 9 barra qualquer «: meow <verbo>» e «rode/use/digite/execute … meow <verbo>». As onze linhas passam a dizer quem faz: o doctor, que compila o patch e confere depois da atualização, ou o botão e o lugar no painel (`meow_onde_no_painel`). `pack.sh` e `vidro-do-cosmic.sh` conferem o texto novo. | `9f6d1935` | `frases-velhas.sh`, `nada-manda-digitar.sh`, `pack.sh` e `vidro-do-cosmic.sh` verdes. Com o `areas.sh` velho plantado, a classe 9 acusa a linha 705. |
| 3 | A cura da aba «Builds» em 390 px (`estilo.css`, `.abas-ajustes > .fila .bt span { display: none }`) valia para todo botão do topo. Em Definir › Painel e dock e › Papel de parede, o «Recarregar o painel» e o «Próxima imagem» viravam uma pílula vazia de 34 px, sem nome e sem ícone (medido na captura em 390 px). | A regra vai para o `extensoes.css`, na classe `adicionar-repo` do botão da Extensões. | `2f03714d` | `extensoes-pagina.py` ganhou a conferência do topo de Definir em 390 px. Verde (85); com a regra velha plantada, vermelho («acao:painel_reciclar» sem nome). |
| 4 | A prova da P118 (`--aba tema` e `--aba criar/mandar` mostram «Aplicar tema» e «Disponibilizar») não existia: o percurso passava sem ler os rótulos. | `h_rotulos_de_aplicar`: nenhuma forma de *vestir* nem «Mandar» no `main`, e os botões e a aba com o texto novo. | `c4506639` | As duas abas verdes. Com «Vestir» e «Mandar» plantados, as duas saem com 2 achados cada. |
| 5 | O `PACKS.md` dizia que a linha do doctor nomeia o dono do desenho. Ela nomeia o pack no ar: no Dracula o desenho é o molde do meowsystem. Dizia também que um pack sem `icones.sistema` «não escreve nada», mas ele tira os ícones que outro pack deixou. | Os dois trechos reescritos no lugar. | `10b16cd7` | `decisoes.sh` só com a falha aceita (GPU); `readme.sh` e `numeros.sh` verdes. |

## Fica de fora (anotado)
- **`.git/hooks`.** As 15 cópias mortas (`*.bak-*`, `*.antes-*`) moram no checkout principal, fora desta worktree, e
  a guarda recusou o `rm` do implementador. Quem coordena apaga: a proposta está em
  `~/.local/share/hefesto-travas/proposta/2026-10-27-ganchos-bak-meowsystem.txt`.
- **`restaurar.sh sistema_limpar`.** Já está vermelho no `dev` e entra na P125 (`ANDAMENTO.md`).
- **Capturas do README.** `docs/capturas/readme/tema.png` ainda mostra «Vestir», até rodar `scripts/readme.py capturas`.
- **Saídas que citam um comando sem mandar digitar.** A classe 9 não barra frases como «o meow compositor faz os
  dois» e «depois 'meow aplicar'» (`cursor.sh:390`, `construir_icones.sh:182`, `forma.sh:94,129`,
  `janelas.sh:182`, `relogio.sh:105`). Também ficam as `pack.py` de terminal: `meow pack info`, `validar` e o
  «meow pack usar» de `:3943`. A busca larga que as achou está descrita no achado 2. Fica para uma sprint própria.
- **`som.sh`.** O aviso de arquivo do pack que é link («saem dele») fica calado na passada em que o tema já está no
  lugar, porque a primeira conferência vai com `2>/dev/null`. Só um pack com link mostra isso.
- **README.** `README.md:7,15` ainda diz «O COSMIC vestido inteiro» e «vestida pelo MeowSystem». É a frase de
  apresentação do projeto, fora da lista da P118.

# P169 — as dicas e o painel miúdo (06/11/2026)

Achados de 04/11, no fecho da P155 a P158. Cada item é pequeno; vale para todo PC.

## O que se mediu

- quick-settings: já dá dica por ícone, mas algumas não são curtas («· 2 h até carregar»). A Bateria em ASCII mostra «NN%» mesmo com a barra só em brilho.
- Tocando não corta música longa.
- `chaveDoAcervo`/`chaveDaPrevia` sem o modo na chave. `/api/autorais` não passa por `pack_da_pessoa`.
- Biblioteca no Latte com contraste de 2,3 a 2,8.
- O nome das variantes do tema novo sai como slug («Gatofinal»).

## A cura

Corrigir cada item na origem, no applet (versão nova e pino) ou no painel. Arte de terceiros não se repinta: no Latte só muda o que é do painel (decisão 38).

## Como se prova

Teste por item, na suíte; applet com versão nova, no GitHub, com o pino em dia.

## Execução

Feito no painel (quatro commits e dois do conferente); os três itens dos applets ficaram de fora, por falta de clone limpo.

- `657f34db` `/api/autorais`: o «salvar» passa por `pack_da_pessoa` (403 em pack que não é da casa da pessoa, nada escrito) e a página manda `aprimorar` quando está no Personalizar (`oficina.js`). Prova: `tests/oficina.sh` ganhou o caso do pack de fora; com o `servidor.py` velho `FALHOU: a oficina de autoral, num pack sem desenhos, não lê o que salva`, com o novo `ok: a oficina de autoral, … e recusa salvar num pack que não é da pessoa`.
- `c8d6146c` `chaveDoAcervo` e `chaveDaPrevia` levam `modoDoRascunho()`. Prova nova, `tests/chave-do-acervo.sh` (no `todos.sh`, node): com o código velho `FALHOU: chaveDoAcervo: criar e aprimorar com o mesmo tema dão a mesma chave…`; com o novo `ok: a chave do acervo e a da prévia mudam com o modo (criar ou aprimorar) e não mudam sem ele`.
- `453dd1b6` Biblioteca e Sistema no Latte: o servidor manda `cores` (as cores do traço de cada desenho) em `/api/criar`; o cartão troca de fundo, entre base, mantle, crust, texto e preto (`0677ce58`, no lugar do `#181825` do Mocha, que levava cor de um pack para todo tema), só quando o padrão não chega a 3:1 e outro fundo dá mais. A arte não muda (decisão 38). O teste agora também reprova desenho de cor própria que siga abaixo de 3:1. Medido no navegador (`tests/sistema-latte-e-rotulos.py`, propriedade nova «todo desenho de cor própria fica no melhor fundo que o painel tem»): antes, Latte Sistema 50 e Biblioteca 142 desenhos abaixo de 3:1 e 3 conferências vermelhas com o código velho; depois, `0 seguem abaixo de 3:1` nos dois e nos dois outros temas, `ok: o Latte no Sistema e na Biblioteca, os rótulos inteiros e os tipos em português`.
- `e4d5346b` Variante do tema novo: quando o flavor do CSV é o slug do nome do tema (`gatofinal` com «Gato Final»), a variante leva o nome digitado e o claro derivado vira «Gato Final claro». `beeb5b85`: com acento também, porque o painel tira o acento antes de gerar o flavor e «Açaí Final» dava `aafinal` contra `acaifinal`. Prova em `tests/pack.sh`: `ok: a variante do tema novo leva o nome digitado, e não o slug («Gato Final», não «Gatofinal»; «Açaí Final», não «Acaifinal»); a que não é o slug do nome segue como veio`.

Não feito, por quê: `meowsystem-quick-settings`, `meowsystem-ascii-battery` e `meowsystem-now-playing` estão sujos (`.gitignore` modificado e `.github/` solto nos três, de antes deste bloco). A regra do bloco manda não tocar clone sujo e anotar, então não mexi, e os pinos de `assets/extensoes/` seguem como estavam. Sem mudança: dicas curtas do quick-settings («· 2 h até carregar», `i18n.rs` `until_full` e `tiles.rs`/`pages.rs`), «NN%» da Bateria em ASCII com a barra só em brilho (`main.rs:866`, a `dica` do botão) e a música longa do Tocando. O próximo bloco que tiver os clones limpos faz os três, cada um em branch própria, versão nova, commit, push e pino.

Falta da mão de quem usa: depois do install e do reboot, no Personalizar com o Latte, abrir Ícones › Biblioteca e ver os cartões coloridos legíveis; no Criar o meu tema por CSV, ver o nome certo na variante.

# Conferência do bloco Modificações (P130), 27/10

Esta conferência cobre os 9 commits do implementador, de `a18c22e4` a `1fd16318`, na `bloco/modificacoes`. O
painel foi aberto headless numa casa de brinquedo, em 1829 e em 390 px de largura, nas rotas `#modificacoes`,
`#modificacoes/terminal` e `#ajustes/programas`. As capturas foram comparadas com a foto 3 de quem usa e com a
`maquete/modificacoes.html`.

## O que a sprint pediu, item por item

| pedido | estado | prova |
|---|---|---|
| Porta nova ao lado da Extensões | feito | `PORTAS` tem 6 portas; `app-acessibilidade.py` e `readme.sh` leem `PORTAS.length` |
| Um cartão por programa instalado, tema e correções juntos | feito | `meow apps cartoes` + `assets/contratos/modificacoes.tsv`; o servidor só faz cartão de módulo com `instalado = 0` |
| Estado pelo mesmo `chk_` do doctor | feito | correção: `chk_<alvo>`; tema: o `conferir` do módulo, o mesmo do `chk_apps` |
| Módulo novo vira cartão sem mudar o painel | feito | `tests/modificacoes.sh` e `app-completo.py` plantam o módulo `brinquedo`; `modificacoes.js` não cita programa |
| Desligar desfaz; ligar de novo não escreve na segunda vez | feito | os dois testes: o arquivo some ao desligar, e o mtime não muda na segunda aplicação |
| «Recebem o tema» e «Loja do Spotify» saem da Programas | feito | prova nova (abaixo), que lê o inventário e olha a tela |
| O Terminal sai do Definir e vira cartão com a tela inteira | feito | `#modificacoes/terminal`: prévia, cores, linha de comando e fonte (captura conferida) |
| Porta e controles no inventário do `app-completo.py` | feito | as rotas `modificacoes` e `modificacoes/terminal` entram em `ROTAS`; cada molde `acao:modificacao_*` e `chave:APPS_ATIVOS:*` é acionado |
| Maquete primeiro | feito | `maquete/modificacoes.html` (a18c22e4) |

## Achados e correções

### 1. O `--onde` e a busca mandavam para «Modificações › Programas», uma página que não existe

- **Achado:** o inventário punha a grade de cartões numa página chamada «Programas». Por isso a pendência e a
  busca diziam «em Modificações › Programas». Essa página não existe, e o nome se confunde com Definir › Programas,
  de onde esses controles acabaram de sair. A Loja do Spotify também caía nessa página, e não no cartão do Spotify.
- **Correção (na origem, o inventário):** a grade passa a ser a própria porta, com página vazia, como Tema e
  Manter. A Loja leva o bloco do cartão. O `_caminho_na_tela` do servidor, o `indiceDaBusca` e o `onde()` do
  `migracao-do-painel.py` tratam a página vazia como a porta.
  - Antes: «Tema», em Modificações › Programas; «Loja do Spotify», em Modificações › Programas.
  - Agora: «Tema», em Modificações; «Loja do Spotify», em Modificações › Spotify; «Cores do tema», em
    Modificações › Terminal › Cores.
- **Commit:** `d7f440c2`.
- **Prova:** `python3 app/servidor.py`, pelo `onde_na_tela`, dá as frases acima. `migracao-do-painel.py` dá
  «ok: 126 chaves, 72 ações e 24 gestos; 0 sem destino», e o caminho de cada `--onde` existe no `lugares.js`.

### 2. Nenhuma prova guardava «nenhum controle em dois lugares»

- **Achado:** o `migracao-do-painel.py` só prova que todo controle tem destino. Ele não pega um controle que mora
  em dois lugares. A volta do bloco «Recebem o tema» ou da aba Terminal ao Definir passaria verde. O
  `app-completo.py` também nunca desenhava a Loja do Spotify: na casa de brinquedo não há Spotify, e o filtro
  `semCartao` a tirava da conta.
- **Correção:**
  - `tests/modificacoes.sh` lê o `inventarioDoPainel()`. Ele recusa que `APPS_ATIVOS`, `SPOTIFY_MARKETPLACE`,
    `TERMINAL_ESQUEMA`, `TERMINAL_CURSOR`, `PROMPT_STARSHIP`, `acervo:fonte`, `apps` ou `apps_aplicar` morem em
    mais de um lugar, ou fora da Modificações. Recusa também a aba `terminal` no `AJUSTES` e o bloco
    «Recebem o tema».
  - `app-completo.py` (`h_modificacoes`) põe na tela um cartão para cada chave de `LUGAR_MODIFICACOES.chaves`. Ele
    confere que a chave aparece uma vez, dentro do cartão dela. Depois abre o Definir › Programas e confere que lá
    não há tema de programa, Loja do Spotify nem aba Terminal.
- **Commit:** `7a5c8654`.
- **Prova:** a checagem nova, rodada contra o `lugares.js` da `integracao/central-e-gerador`, dá 10 FALHOU (rc 1).
  Os 10 são as 8 chaves no Definir, a aba Terminal e o «Recebem o tema». No código do bloco ela dá rc 0.
  `app-completo.py --aba modificacoes`: 91 conferências, «ok: o painel inteiro» (antes eram 88).

### 3. O botão do topo dizia só «Aplicar»

- **Achado:** a maquete diz «Aplicar em todos», e a página dizia «Aplicar» ao lado de uma grade de cartões, o que
  não diz em quê. A dica repetia o nome do botão («Conferir» / «Conferir»).
- **Correção:** o botão passa a dizer «Aplicar em todos», e a dica só aparece quando diz algo diferente do botão.
- **Commit:** `b888afb2`.
- **Prova:** a tela foi capturada depois da correção, e a suíte inteira passou por ela (abaixo).

## Conferido e sem defeito

- **Desligar:** só tira o nome do `APPS_ATIVOS` depois que o `meow apps reverter` volta com 0 ou 1. Um módulo
  pendente (rc 3) volta 0 pelo `aplicar_apps.sh`. Um módulo que falha (rc 2) deixa o interruptor ligado, e a janela
  do trabalho mostra o erro. Assim o interruptor nunca diz «desligado» com o tema ainda escrito. Todos os 13
  módulos têm `meow_app_reverter`.
- **`meow apps corrigir`:** só aceita um nome que tenha `correcao` no TSV e um `fix_` declarado. As ações do
  servidor validam o argumento pelos provedores `modulos_de_app` e `correcoes_de_app`.
- **Nomes de verdade:** os nomes `flatpakadwaita`, `flatpakicones` e `flatpakruntime` existem como `chk_`/`fix_` na
  `bloco/flatpak`, e o módulo `libadwaita` também mora lá. `git merge-tree` com a `bloco/flatpak` só dá conflito em
  `README.md`, `README.en.md` e `bin/meow` (`VERIFICAVEIS`), como o implementador disse. O `lugares.js` não conflita.
- **Telas:**
  - Na largura de 390 px, os cartões empilham sem rolagem lateral.
  - A página do Terminal é a tela de antes.
  - O Definir mostra 6 abas, sem Terminal. A Programas tem Lançador, Ao ligar e Jogos, sem o bloco da foto 3.

## Fica para depois (não é deste bloco)

- **A corrida do `enviarLote`** (`app.js`): um lote velho que volta apaga a `MUDANCAS` mais nova. É a causa do
  `app-layout.py` instável com a máquina carregada. É anterior ao bloco e vale virar sprint.
- **Controles em dois lugares, anteriores ao bloco:**
  - `pack_usar`, no Tema e no Personalizar › Disponibilizar;
  - `extensao_refazer`, no Manter e em Extensões › Applets.
- **A captura do README** (`docs/capturas/readme/modificacoes.png`) ainda mostra «Aplicar». Ela se refaz com o
  `scripts/readme.sh` na integração, que já precisa regerar o README por causa do conflito com a `bloco/flatpak`.
- **Inventário no mesmo commit:** a P130 pedia o inventário do `app-completo.py` no mesmo commit da porta, e o
  implementador separou em dois (`08b4dd79` e `e1b7e081`). O resultado é o mesmo, e não reescrevi o histórico.

## Suíte

`./tests/todos.sh` foi rodado depois do último commit de código (`b888afb2`).

- **Resultado:** «todos os 109 · 107 verde(s), 0 pulado(s), 2 vermelho(s)», com rc 1.
- **Os dois vermelhos** já eram aceitos e são anteriores ao bloco:
  - `decisoes.sh`: o D6, a GPU do compositor fora da RTX, e o «24: cita docs/pesquisas/» do `tests/enxugar.sh`;
  - `restaurar.sh`: o `pack_usar` e o `desinstalar`.
- **Os testes que este bloco toca, todos verdes:**
  - `modificacoes.sh`, `migracao-do-painel.py`;
  - `app-completo.py` (1185 s), `app-layout.py` (122 s);
  - `app-navegador.py`, `app-acessibilidade.py`, `app-uso-real.py`, `app-texto-visivel.py`;
  - `extensoes-pagina.py`, `readme.sh`.
- **Escritas recusadas:** a suíte recusou 6 chamadas de sudo e parou 13 escritas de busctl.

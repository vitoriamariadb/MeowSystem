# QA-2 — Ajustes (vai ser «Definir»), a prévia da tela e o layout geral

Data: 26/10/2026 · branch `dev` (`16927be8`) · sem correção nem commit: só achados.

**Como medi.** O painel subiu na casa de brinquedo do `tests/app-completo.py`, importada como
o `tests/app-navegador.py` faz (HOME temporário, PID próprio, falsos de `sudo`/`pkexec`/`apt`,
`MEOW_PONTE=sem-ponte`, sem barramento). O Chrome do sistema rodou só headless
(`channel="chrome"`: o `chromium-headless-shell` do Playwright não está baixado). Scripts e
medidas brutas em
`/tmp/claude-1000/-home-vitoriamaria-Desenvolvimento-MeowSystem/314702cb-6fd7-4227-9dcc-7970f525cc19/scratchpad/qa-2/`:

| script | mede | saída |
|---|---|---|
| `layout.py` | geometria das 7 páginas em 1920×1080, 1550×860, 1500×900 e 1280×800, no topo e rolada 700 px | `layout.json`, fotos `L-*` |
| `previa.py` | cada controle visível contra o estado da prévia (posição, raio, cor, variáveis CSS) | `previa.json` |
| `fluxo.py` | «Mais ajustes», contador, «Ver sem mudar», Aplicar vazio, busca, dicas, Escondidos, Spotify, Terminal, 1100 e 960 px | `fluxo.json`, fotos `F-*` |
| `aplicar.py` | ensaio e Aplicar de verdade até o fim, «Voltar ao padrão» depois, cabeçalho em 1500 e 1280 | `aplicar.json`, fotos `A-*` |

Fotos em `relatorios/fotos/qa-2/`. As da usuária (3.png a 8.png) são citadas pelo nome que ela deu.
Nenhum erro de JavaScript na página durante as medidas.

**Para quem executa.**
- Q2-01 a Q2-03 (prévia) mexem em `mesa.js` e `estilo.css`: vão juntos.
- Q2-04 a Q2-07 (Aplicar, ensaio e «grava ao soltar») são um bloco só, e o Q2-07 é o plano dele.
- Q2-08 a Q2-12 (layout) mexem em `paginas.js` e `estilo.css`: vão juntos, depois da prévia.
- Q2-13 («Mais ajustes» sai) toca `lugares.js`, `app.js`, `paginas.js`, `servidor.py` e 5 testes.
- Q2-14 a Q2-18 são independentes entre si.
- A fiação comum é a mesma do QA-1 e do QA-3 (`lugares.js`, `paginas.js`, `estilo.css`): integrar
  por bloco, não em paralelo no mesmo arquivo.

---

## Prévia

### Q2-01 · A dock da prévia é sempre uma pastilha no meio; «Em pastilha» e «Solta da borda» da dock não aparecem

Confirma a queixa 1 (3.png, 4.png).

- **Passos.** Ajustes › Painel e dock. Na coluna «Dock», trocar «Em pastilha» (`FORMA_DOCK_ILHA`) e
  depois «Solta da borda» (`FORMA_DOCK_SOLTO`).
- **Visto.**
  - «Em pastilha» da dock: a prévia não muda nada. Só ganha a moldura tracejada
    (`previa.json`: `previa_mudou: []`, `marca: ["p-dock mudou-aqui"]`). Foto `F-dock-ilha-sim.png`.
  - «Solta da borda» desligada: a pastilha só desce até a borda. Continua centrada, arredondada
    e com 7 ícones (`dock.y` muda, `dock.w` e `raio` não). Foto `F-dock-solto-nao.png`.
  - O estado de fábrica (`SOLTO=sim`, `ILHA=nao`) é desenhado como pastilha centrada.
- **Esperado.** O que o `scripts/forma.sh` faz no COSMIC:
  - `ILHA` é o `expand_to_edges` invertido (`forma.sh:109-116`, `:239-245`). Com `ILHA=nao` a
    dock vai de ponta a ponta: mascote à esquerda, apps no meio, bandeja à direita
    (`meow.conf.exemplo:700-864`).
  - `SOLTO` é o `anchor_gap`. A margem só existe com ele ligado.
  - Colada na borda: sem raio nos cantos de baixo.
- **Causa.**
  - `app/pagina/mesa.js:132-135`: a dock é um `div.p-dock` com gato, separador e 6 ícones, sem
    segmentos.
  - `app/pagina/mesa.js:104`: só `FORMA_PAINEL_ILHA` é lida (26 %/26 %). `FORMA_DOCK_ILHA` não
    aparece em lugar nenhum de `mesa.js`.
  - `app/pagina/estilo.css:320`: `.p-dock { left: 50%; transform: translateX(-50%) }` fixa o centro.
- **Cura na origem.**
  - `mesa.js`: a dock nasce com três segmentos (`.ala-ini` com o gato, `.centro` com os apps,
    `.ala-fim` com 2 ícones de bandeja).
  - Com `FORMA_DOCK_ILHA` = sim: os três viram uma pastilha só (o que existe hoje).
  - Com `FORMA_DOCK_ILHA` = nao: `left: var(--p-margem-dock); right: var(--p-margem-dock)` e
    `justify-content: space-between`.
  - Com `SOLTO` = nao: margem 0 e `border-radius: var(--p-raio-dock) var(--p-raio-dock) 0 0`.
  - O mesmo vale para a barra de cima. Hoje a «pastilha» do painel é 26 % fixo, e no COSMIC ela
    abraça o conteúdo: usar `left:auto; right:auto; width:max-content` centrado.
- **Prova** (`tests/app-navegador.py`, item novo):
  ```python
  dock = lambda: pag.evaluate("() => { const d = document.querySelector('#conteudo .previa .p-dock').getBoundingClientRect(), p = document.querySelector('#conteudo .previa').getBoundingClientRect(); return [d.left - p.left, p.right - d.right, d.width / p.width]; }")
  # fábrica: SOLTO=sim, ILHA=nao -> de ponta a ponta
  checa(dock()[2] > 0.9, "dock de fábrica vai de ponta a ponta")
  pag.click('[data-controle="chave:FORMA_DOCK_ILHA"]')
  checa(dock()[2] < 0.6 and abs(dock()[0] - dock()[1]) < 2, "em pastilha: estreita e centrada")
  ```
- **Tamanho.** M.
- **Fotos.** `F-dock-ilha-sim.png`, `F-dock-solto-nao.png`; da usuária, 3.png e 4.png.

### Q2-02 · Metade dos controles de «Painel e dock» só pinta a moldura tracejada

- **Passos.** Ajustes › Painel e dock. Mexer em cada controle e olhar a prévia.
- **Visto** (`previa.json`). Estes controles só ganham `mudou-aqui`, sem mudança de desenho:
  - `FORMA_DOCK_ILHA` e `FORMA_ESPACO_PAINEL`;
  - os 30 botões XS…XL de «Tamanho dos ícones» (`FORMA_ALA_INICIAL_*`, `FORMA_CENTRO_*`,
    `FORMA_ALA_FINAL_*`, painel e dock);
  - `RELOGIO_SEGUNDOS` e `VIDRO_AO_MAXIMIZAR`;
  - `MIDIA_CAPA`, `MIDIA_CONTROLES`, `MIDIA_LARGURA` e `MIDIA_FONTE`;
  - os `FORMA_RECHEIO_*` do «Mais ajustes».

  Mudam de verdade: `*_SOLTO` (só a altura), `FORMA_PAINEL_ILHA`, margem, raio,
  `FORMA_ESPACO_DOCK`, vidro, `MIDIA`, `MIDIA_COR_TITULO` e `MIDIA_COR_ARTISTA`.
- **Esperado.** Todo controle desta página que tem desenho na tela tem desenho na prévia. Os que
  não têm desenho não marcam a prévia.
- **Causa.**
  - `app/pagina/mesa.js:75-104`: só lê as chaves acima. `--p-espaco-dock` existe, o espaço do
    painel não.
  - Os ícones da barra são `varias(4)` e `varias(3)` de tamanho fixo (`mesa.js:100-102`).
  - O relógio, a capa e os controles da mídia não existem no desenho.
  - `app/pagina/paginas.js:24-29` (`REGIAO`): o regex marca qualquer `FORMA_.*PAINEL`, `MIDIA`
    ou `RELOGIO`, desenhado ou não.
- **Cura na origem.**
  - `mesa.js`:
    - `--p-espaco-painel` (gap de `.p-barra .ws` e `.bandeja`);
    - tamanho por segmento, com `--p-ala-ini`, `--p-centro` e `--p-ala-fim` de XS=2.6cqi a
      XL=4.4cqi, aplicado aos ícones do segmento (depende do Q2-01 para a dock);
    - relógio com `:ss` quando `RELOGIO_SEGUNDOS`;
    - capa (quadradinho) e três controles na `.musica`;
    - largura e fonte da `.musica`.
  - `VIDRO_AO_MAXIMIZAR` só existe com janela maximizada: tirar da `REGIAO`.
  - Regra: chave que a prévia não desenha não entra na `REGIAO`.
- **Prova.** Para cada chave da lista, clicar ou mover e comparar a prévia antes e depois. A
  `ESTADO` de `previa.py` serve de molde. Asserção: `previa_mudou != []` para toda chave em
  `REGIAO`, e nenhuma chave fora dela marca `mudou-aqui`.
- **Tamanho.** M.
- **Fotos.** `L-1920x1080-painel-topo.png`; da usuária, 4.png.

### Q2-03 · Janelas, Papel de parede, Dia e noite, Mascote e Programas: a prévia não responde

- **Visto** (`previa.json`).
  - **Janelas e tela**: nenhum controle mexe na prévia (tiling, escala, cursor, áreas).
  - **Papel de parede**: só `WALLPAPER_AJUSTE`. Intervalo, ordem, notificar e menu do Arquivos:
    nada.
  - **Dia e noite**:
    - `LEITURA_TEMPERATURA`, `LEITURA_TEXTURA` e `LEITURA_RAMPA_MIN` só pintam com
      `LEITURA_AGENDA=sim`;
    - com a agenda desligada, mover «Quão quente» não muda nada;
    - `WALLPAPER_NOITE` e `WALLPAPER_LIMIAR_LUZ`: nada.
  - **Mascote**: `LOGO_MODO`, `LOGO_DIA`, `LOGO_NOITE`, `LOGO_INTERVALO`, `LOGO_ROTACAO` e os
    tamanhos do `FASTFETCH_LOGO_*` só marcam.
  - **Programas**: nenhum dos 27 interruptores, nem `LANCADOR_SISTEMA` ou `SPOTIFY_MARKETPLACE`.
    A prévia fica parada ao lado (6.png).
- **Causa.**
  - `app/pagina/paginas.js:30-42` (`mesaDaPagina`): o `quente` só passa com
    `ligado(LEITURA_AGENDA)`.
  - `mesa.js` não tem cursor, escala, textura nem segundo papel.
  - A prévia rica do modo de leitura saiu na P98: `telaDaLeitura`/`previaRealDaLeitura`
    pintava a imagem real na temperatura e textura, com régua de 24 h. Está em
    `git show 20b285d8^:app/pagina/app.js`, linhas 2609-2760. Ver Q2-17.
- **Cura na origem.**
  - Dia e noite:
    - o `quente` vale sempre que a página é «dia-e-noite» e o controle mexido é `LEITURA_*`,
      pelo `PROVISORIO` do `repintarPrevia`;
    - a agenda decide o horário, não se a prévia mostra;
    - textura como `filter: url(#ruido)` ou um `background-image` de ruído com opacidade.
  - Janelas: escala muda o tamanho das janelas da mesa; o cursor aparece na mesa.
  - Mascote: o modo «rotação» mostra os dois gatos (dia e noite) lado a lado na dock.
  - Programas: ver Q2-12.
- **Prova.** Na Dia e noite com `LEITURA_AGENDA=nao`, mover «Quão quente» para 2000 deixa `.quente`
  com `opacity > 0`.
- **Tamanho.** M (Dia e noite e Janelas); a prévia de leitura rica é G.
- **Fotos.** `L-1920x1080-dia-e-noite-topo.png`, `L-1920x1080-programas-rolado.png`.

---

## Aplicar, ensaio e «grava ao soltar»

### Q2-04 · «Aplicar» roda o instalador inteiro, mesmo para uma chave

- **Passos.** Painel e dock, desligar «Solta da borda» da dock, «Aplicar».
- **Visto** (`aplicar.json`).
  - A janela abre com o título «Instalar tudo».
  - Roda 136 linhas de etapa: as 68 do `install.sh`, duas vezes, porque a fila se repete até
    ninguém escrever.
  - Leva 71,3 s e termina com «Saiu 2». Na casa de brinquedo os falsos recusam `sudo`, e a
    falha não é da chave.
  - A chave foi gravada (`FORMA_DOCK_SOLTO="nao"`).
  - Foto `A-aplicar-janela.png`.
- **Esperado.** Mudar uma chave aplica o que ela governa (o `forma.sh`, segundos), sem a janela de
  instalação.
- **Causa.** `app/servidor.py:10494-10580` (`/api/salvar`): depois do `definir_varias` chama
  sempre `iniciar("instalar", …, confirmado=True)`. A ação `instalar` é o `install.sh` inteiro
  (`app/servidor.py:3842-3850`).
- **Cura na origem.** O Q2-07 (grava ao soltar) troca este caminho. Se a decisão do Q2-07 não
  vier, o mínimo é a ação de aplicar receber a lista de chaves e rodar só os aplicadores delas
  (tabela do Q2-07).
- **Prova.** Aplicar `FORMA_DOCK_SOLTO` na casa e conferir que o trabalho não é `instalar` e que o
  registro dos falsos tem só o `forma.sh`.
- **Tamanho.** G (é o Q2-07).

### Q2-05 · «Aplicar» com zero mudanças continua na tela e roda o «Instalar tudo»

- **Passos.** Abrir qualquer página de Ajustes sem mexer em nada e clicar «Aplicar».
- **Visto.**
  - O botão está sempre visível (6.png, `L-*-topo.png`).
  - O clique manda `POST /api/salvar {"mudancas":{},"seco":false}`, e o servidor abre o
    «Instalar tudo» (`fluxo.json` › `aplicar_vazio`).
  - Foto `F-aplicar-vazio.png`.
- **Esperado.** Sem mudança, nada para aplicar: o botão não existe (e com o Q2-07, não existe
  nunca).
- **Causa.**
  - `app/pagina/app.js:982-986` (`atualizarAplicar`) só troca o número.
  - `app/servidor.py:10494-10580` não recusa um `mudancas` vazio.
- **Cura na origem.**
  - `estilo.css`: `#aplicar[data-n="0"] #bt-aplicar, #aplicar[data-n="0"] #botao-ensaiar { display:none }`.
  - O `/api/salvar` com `mudancas` vazio responde `{"gravadas": []}` sem `iniciar`.
- **Prova.** Com 0 mudanças, `#bt-aplicar` não é visível. Um `POST /api/salvar` vazio não cria
  trabalho (`/api/trabalho` sem id novo).
- **Tamanho.** P.

### Q2-06 · «Ver sem mudar» de uma chave é o ensaio do instalador inteiro (53 s)

- **Passos.** Mexer numa chave e clicar «Ver sem mudar».
- **Visto.**
  - Janela «Instalar tudo», 68 etapas, 663 linhas, «Mudaria · 53.1s».
  - Nada diz o que muda por causa da chave: as linhas de etapa sem relação com ela também
    aparecem.
  - Foto `A-ensaio-1-chave.png`.
- **Causa.** `app/servidor.py:10494-10580`: `seco` vira `_conf_de_ensaio` mais
  `iniciar("instalar", seco=True)`.
- **Cura na origem.** Com o Q2-07 o ensaio perde o lugar (a prévia é o ensaio): sai da barra. Ver
  «conflita com decisão registrada» (decisão 18).
- **Tamanho.** P (sai junto com o Q2-07).

### Q2-07 · Decisão nova: cada controle grava ao soltar; a barra fica só para desfazer

Este item é o plano do bloco, não um defeito.

**O caminho de hoje.**

1. O controle chama `escolher(chave, valor)` (`app/pagina/app.js:292`).
2. `escolher` grava no `MUDANCAS` (Map), em `guardarBandeja()` (sessionStorage `meow-bandeja`),
   chama `atualizarAplicar()` e `render()` (`app.js:1171`, que refaz o `#conteudo` inteiro).
   - O deslizante repinta só a prévia no `input` (`controleFaixa`, `app.js:435`) e chama
     `escolher` no `change`.
   - A lista de fichas chama `escolher` no Enter (`controleLista`, `app.js:531`).
3. «Desfazer» é `MUDANCAS.clear()` (`app.js:1190`). Ele só desfaz o que ainda não foi gravado.
4. «Aplicar» chama `salvarEscolhas()` (`app.js:987-1015`), que manda `POST /api/salvar` e roda o
   `install.sh` inteiro (Q2-04).
5. Outros que dependem do pendente:
   - `beforeunload` com 2 ou mais mudanças (`app.js:1190`);
   - `listaDePendentes()` (`app.js:1020`);
   - `importarArquivo()`, que diz «mudanças esperando o Aplicar» (`app.js:1036`);
   - `valeNaPrevia`/`PROVISORIO` (`paginas.js:9-13`);
   - a `REGIAO` (`mudou-aqui`, `paginas.js:24-29`).

**O que já existe e serve.** `POST /api/definir {chave, valor}` (`app/servidor.py:10461-10489`)
valida, grava uma chave, trata o «mesmo horário» e adota a leitura (`_adotar_leitura`). Nenhum JS
o chama hoje.

**O que muda.**

1. `escolher(chave, valor)` vira gravação.
   - Guardar `antes = valorEmVigor(item)` e `POST /api/definir`.
   - Com `rc` ok: `item.valor = valor`, empilhar `{chave, antes, depois: valor}` em
     `HISTORICO` (array, só da aba, sem sessionStorage) e chamar `render()`.
   - Com erro: torrada com a frase e o controle volta ao `antes`.
   - O deslizante grava só no `change` (soltar), nunca no `input`.
   - Texto e lista gravam no Enter e no `blur`.
2. Aplicar no sistema, no servidor, depois do `/api/definir`.
   - Uma tabela `APLICADOR` liga o prefixo da chave ao script que já existe:

     | prefixo | aplicador |
     |---|---|
     | `FORMA_*` | `scripts/forma.sh` |
     | `VIDRO_*` | `scripts/vidro.sh` |
     | `LEITURA_*` | `_adotar_leitura` / `meow leitura` |
     | `TERMINAL_*`, `PROMPT_*`, `FASTFETCH_*` | a etapa do terminal |
     | `WALLPAPER_*` | `meow wallpaper` |
     | `LOGO*` | `meow logo` |
     | `APPS_ATIVOS`, `SPOTIFY_*` | `meow apps aplicar <app>` |
     | `LANCADOR_*` | a etapa do lançador |

   - O executor confirma cada linha lendo a etapa correspondente no `install.sh` (`etapa_vidro`
     em `:2109`, `etapa_forma` em `:2286`, `etapa_painel` em `:2162` etc.).
   - Os aplicadores rodam em segundo plano, um por vez por prefixo (trava em `MEOW_ESTADO`),
     com coalescência: um segundo pedido do mesmo prefixo durante a corrida marca «de novo» e
     roda uma vez no fim.
   - Sem janela de resultado. O cabeçalho mostra o estado discreto (girando, depois ok ou erro).
     O registro abre só por clique.
   - Chave sem aplicador: grava e entra na fila de um `instalar` em segundo plano, coalescido
     (um só, depois de 3 s sem pedido).
   - A regra do `install.sh` contra flag que escolhe etapa (`install.sh:3799-3803`) continua: o
     aplicador chama o script da etapa, não o `install.sh`.
3. A barra de mudanças vira histórico.
   - `#conta` mostra «N feitas».
   - «Desfazer» tira o último do `HISTORICO` e manda `POST /api/definir {chave, valor: antes}`
     (passa pelo aplicador).
   - Uma lista (`listaDePendentes`) mostra as N últimas com «Desfazer» em cada uma.
   - Saem: `#bt-aplicar`, `#botao-ensaiar`, `guardarBandeja`, o `beforeunload`, `MUDANCAS` como
     pendente e a frase do `importarArquivo` («esperando o Aplicar» vira «trazido»).
   - `LUGAR_TOPO` (`lugares.js:354-357`) perde «Aplicar» e «Ver sem mudar».
4. «Voltar ao padrão» (`botaoPadrao`, `app.js:319-336`) hoje só cria uma mudança pendente
   (`aplicar.json` › `padrao`: `n=1`, conf continua `nao`). Passa a gravar na hora, pelo mesmo
   `escolher`.
5. A prévia: `valeNaPrevia` e `PROVISORIO` ficam para o arrasto do deslizante. A moldura
   `mudou-aqui` passa a marcar o último gesto por 1,5 s, ou sai.
6. Testes que mudam:
   - `tests/app-navegador.py` item 3: espera `mudou-aqui` depois do clique e só grava no Aplicar.
     Passa a esperar o conf gravado logo depois do clique e o «Desfazer» devolvendo o valor.
   - `tests/app-completo.py`: os passos que clicam «Aplicar» e «Ver sem mudar».
   - `tests/app-uso-real.py` e o `tests/app.sh` (o `/api/salvar`).
   - `tests/decisoes.sh`, se guarda a decisão 18.

- **Prova.**
  ```python
  pag.click('[data-controle="chave:FORMA_DOCK_SOLTO"]')
  pag.wait_for_function("() => !document.querySelector('#aplicar [data-estado=carregando]')")
  checa(casa.valor_de("FORMA_DOCK_SOLTO") == "nao", "gravou ao clicar")
  checa(not pag.locator("#bt-aplicar").count(), "não existe Aplicar")
  checa("instalar" not in [t["acao"] for t in api("/api/trabalho?todos=1")], "nenhum Instalar tudo")
  pag.click("#desfazer")
  checa(casa.valor_de("FORMA_DOCK_SOLTO") == "sim", "desfazer devolveu")
  ```
- **Tamanho.** G. É o maior item deste relatório: um bloco Opus.

---

## Layout

### Q2-08 · O menu lateral e o título rolam para fora; a prévia fica sozinha

Confirma a queixa 2 (6.png).

- **Passos.** Qualquer página de Ajustes, rolar 700 px.
- **Visto** (`layout.json`, nas 4 larguras).
  - `.trilho` vai a `top = -540` (some).
  - `.cabeca` (título e «Recarregar o painel») vai a `-604`.
  - O `.palco` fica em `top = 96`.
  - Em Programas sobra só a prévia parada ao lado das fichas (`L-1500x900-programas-rolado.png`,
    6.png).
- **Causa.**
  - `app/pagina/estilo.css:332`: o `position: sticky` está no `ul.trilho`.
  - O pai dele é o `<nav>` que `paginaAjustes` cria (`app/pagina/paginas.js:685`), e é esse
    `<nav>` o item da grade. A altura dele é a do `ul`, então o sticky não tem onde andar.
  - A `.cabeca` não é sticky (`estilo.css:215`).
- **Cura na origem.** O layout do Q2-09 resolve. Se o Q2-09 não for aceito, o mínimo é mover o
  sticky para `.oficina > nav { position: sticky; top: 96px; align-self: start }`.
- **Prova.**
  ```python
  pag.evaluate("scrollTo(0, 700)")
  checa(pag.evaluate("document.querySelector('.oficina nav, .abas-ajustes').getBoundingClientRect().top") >= 64, "menu fica")
  ```
- **Tamanho.** P (sozinho) / parte do Q2-09.
- **Fotos.** `L-1920x1080-programas-rolado.png`, `L-1500x900-programas-rolado.png`; da usuária, 6.png.

### Q2-09 · Proposta: abas horizontais acima da prévia, prévia maior e fixa

A prévia tem 632 px numa tela de 1920 (33 %), 535 em 1550, 512 em 1500 e 411 em 1280. A coluna
de 210 px do trilho come espaço, e `.pagina { max-width: 1760px }` (`estilo.css:214`) deixa 80 px
de cada lado em 1920.

**1920×1080**
```
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ ◉ MeowSystem   Tema  Personalizar  [Definir]  Manter      [⌕ Procurar  /]  3 feitas ↶  ⋯ │ sticky top 0, 64 px
├───────────────────────────────────────────────────────────────────────────────────────────┤
│ [Painel e dock] Janelas e tela  Papel de parede  Mascote  Dia e noite  Terminal  Programas │ sticky top 64, 52 px
│                                                                  [Recarregar o painel]    │ (a ação da página à direita)
├──────────────────────────────────────────────────┬────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────┐ │ Forma            Barra de cima   Dock  │
│ │                                              │ │ Solta da borda      (●)         (●)    │
│ │                prévia ~980 px                │ │ Em pastilha         ( )         (●)    │
│ │           sticky top 116 (64+52)             │ │ Distância da borda  ━━●━━       ━━●━━  │
│ │                                              │ │ …                                      │
│ │ ▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭▭ │ │ Tamanho dos ícones                     │
│ └──────────────────────────────────────────────┘ │ …   (só esta coluna rola)              │
│        minmax(0, 1.15fr)                         │        minmax(0, 1fr) ~ 850 px         │
└──────────────────────────────────────────────────┴────────────────────────────────────────┘
```

**1280×800** (e meia tela de 1920, 960 px)
```
┌──────────────────────────────────────────────────────────────┐
│ ◉ MeowSystem  Tema Personalizar [Definir] Manter  ⌕  ↶ 3  ⋯ │ busca vira ícone que abre o campo
├──────────────────────────────────────────────────────────────┤
│ [Painel e dock] Janelas e tela  Papel de parede  Mascote  ▸  │ rola na horizontal, sem quebrar
├───────────────────────────┬──────────────────────────────────┤
│ ┌───────────────────────┐ │ Forma         Cima       Dock    │
│ │  prévia ~560 px       │ │ Solta         (●)        (●)     │
│ │  sticky top 116       │ │ Distância     ━●━        ━●━     │
│ └───────────────────────┘ │ …                                │
│   minmax(0, .9fr)         │   minmax(0, 1fr)                 │
└───────────────────────────┴──────────────────────────────────┘
abaixo de 1000 px: uma coluna; a prévia fica sticky no topo com 38vh de altura máxima e os
controles rolam por baixo dela.
```

**O que muda.**

- **HTML** (`app/pagina/paginas.js:658-689`, `paginaAjustes`):
  - O `ul.trilho` sai da `.oficina`.
  - Nasce antes dela um `elemento("nav", { class: "abas-ajustes", "aria-label": "Definir" })`
    com os 7 links (os mesmos `controle: "ajuste:<id>"`, `aria-current`).
  - A ação da `cabeca` («Recarregar o painel») vai para o fim desse `nav`.
  - O `h1` da página sai (a aba ativa já diz o nome) ou fica só para leitor de tela
    (`.so-leitor`).
  - A `.oficina` fica com `[palco, pilha]`.
- **CSS** (`app/pagina/estilo.css`):
  - `:214`: `.pagina { max-width: 1880px }` (ou `none` com `padding-inline: clamp(16px, 2.5vw, 48px)`).
  - Novo: `.abas-ajustes { position: sticky; top: 64px; z-index: 5; display: flex; gap: 4px; overflow-x: auto; scrollbar-width: none; height: 52px; align-items: center; background: var(--fundo); border-bottom: 1px solid var(--linha); margin-inline: calc(-1 * var(--pad)); padding-inline: var(--pad) }`.
  - Novo: `.abas-ajustes a[aria-current="page"]`, com sublinhado de 2 px em `--accent` no lugar
    do `inset 3px` do trilho.
  - `:329`: `.oficina { grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr) }`.
  - `:331`: `.oficina .palco { top: 132px }` (64 + 52 + 16).
  - `:332-336`: as regras `.trilho` saem.
  - `:551-558` (≤1180): `.oficina { grid-template-columns: minmax(0, .9fr) minmax(0, 1fr) }`. O
    palco continua sticky (hoje vira `static`).
  - `:563-572` (≤860, e passar o limite para 1000): uma coluna. `.palco` sticky com
    `max-height: 38vh` e a `.previa` com `max-height: 100%; width: auto; aspect-ratio: 16/9.4`.
- **Testes que leem o trilho.** `tests/app-completo.py` («trilho de Ajustes», docstring `:16`),
  `tests/app-navegador.py` e `tests/app-acessibilidade.py` usam `[data-controle^="ajuste:"]`. O
  seletor continua valendo se os links mantêm o `controle`.
- **Prova.**
  - Em 1920: `.previa.width >= 900`.
  - Nas 4 larguras, depois de `scrollTo(0, 700)`: `.abas-ajustes.top == 64` e `.palco.top >= 116`.
  - `document.documentElement.scrollWidth == innerWidth`.
- **Tamanho.** M.

### Q2-10 · As linhas de duas colunas (Forma, Tamanho dos ícones) vazam do cartão

Confirma a queixa 3 (5.png).

- **Passos.** Painel e dock em 1550, 1500 ou 1280 px de largura.
- **Visto** (`layout.json`). Controles passam da borda direita do `.bloco`:
  - 15 controles até 64 px em 1550;
  - 21 até 91 px em 1500;
  - 27 até 110 px em 1280.

  Fotos `L-1500x900-painel-topo.png` e `A-topo-1280.png` (os deslizantes da dock somem cortados).
- **Causa.**
  - `app/pagina/estilo.css:233`: `.linha.dupla { grid-template-columns: minmax(140px,1fr) 240px 240px }`.
  - `:548`: `minmax(120px,1fr) 200px 200px` abaixo de 1360.
  - Somando padding e gap, a linha pede de 620 a 690 px, e a `.pilha` tem 629, 602 e 483 px.
  - `:236`: `flex-wrap: nowrap`. O `.bloco` não corta (`:217`).
- **Cura na origem.**
  - `.oficina > .pilha { container-type: inline-size }`.
  - `.linha.dupla, .bloco > header.dupla { grid-template-columns: minmax(110px, 1fr) minmax(0, 220px) minmax(0, 220px) }`.
  - `@container (max-width: 560px) { .linha.dupla { grid-template-columns: minmax(0,1fr) minmax(0,1fr) } .linha.dupla > .rot { grid-column: 1 / -1 } }`.
  - O `.seg` XS…XL com `button { padding: 0 6px }` no container estreito.
- **Prova.** O `MEDIR` de `layout.py` dá `nvazam == 0` nas 4 larguras e em 960×1000.
- **Tamanho.** P.
- **Fotos.** `L-1550x860-painel-topo.png`, `L-1500x900-painel-topo.png`, `A-topo-1280.png`; da usuária, 5.png.

### Q2-11 · Em meia tela a busca some, e «/» foca um campo escondido

- **Passos.** Janela com 1100 ou 960 px (meia tela de 1920) e apertar «/».
- **Visto.**
  - `.busca` fica `display: none`.
  - O «/» não abre nada: o foco fica em `principal` (`fluxo.json` › `busca_1100`, `busca_960`).
  - Em 1280 o campo encolhe para 220 px e corta o texto («Procurar um ajust»), e o contador e
    os 3 botões ocupam 415 px (`aplicar.json` › `topo_1280`).
  - Fotos `F-1100-painel.png`, `F-960-painel.png`, `A-topo-1280.png`.
- **Causa.**
  - `app/pagina/estilo.css:551`: `.busca { display: none }` abaixo de 1180.
  - `:547`: largura de 220 px.
  - `app/pagina/app.js:1053-1113`: o atalho chama `focus()` num campo invisível.
- **Cura na origem.**
  - Abaixo de 1180 a busca vira botão-ícone (lupa) que abre o campo por cima do cabeçalho
    (`.busca.aberta { position:absolute; inset: 8px 16px; width:auto }`).
  - O «/» abre e foca.
  - Com o Q2-07 a barra de Aplicar encolhe para «↶ N», o que devolve espaço.
- **Prova.** Em 960×900, `keyboard.press("/")` deixa `document.activeElement.id == "busca"`, e o
  campo fica visível (`offsetWidth > 200`).
- **Tamanho.** P.

### Q2-12 · Programas: a prévia não tem o que mostrar e ocupa meia tela

- **Visto.**
  - Nenhum controle da página mexe na prévia (Q2-03).
  - Ao rolar, ela fica sozinha à esquerda enquanto a lista de 27 programas, o Lançador e os
    Jogos ocupam 2295 a 2925 px de altura (`layout.json`).
  - Fotos `L-1920x1080-programas-rolado.png`; da usuária, 6.png.
- **Causa.** `paginaAjustes` põe `mesaDaPagina` em toda página (`paginas.js:686`).
- **Cura na origem** (precisa da usuária decidir, ver o fim). Duas saídas:
  - (a) Programas sem prévia: `oficina sem-trilho`, uma coluna larga com a grade de programas
    em 3 ou 4 colunas.
  - (b) A prévia mostra os programas vestidos: miniatura do app com o tema.
- **Tamanho.** P (a) / G (b).

---

## «Mais ajustes» sai

### Q2-13 · Todas as ocorrências do «Mais ajustes» e os testes que o exigem recolhido

- **Visto** (`fluxo.json`). O «Mais ajustes» nasce fechado nas 7 páginas, com 6, 3, 10, 10, 1, 1
  e 2 itens (Painel e dock, Janelas, Papel, Mascote, Dia e noite, Terminal, Programas).
- **Onde mora.**
  - **Dados** (`app/pagina/lugares.js`), 12 listas `mais:`:
    - Tema (`:35`), passos de Criar tema (`:56` ícones, `:94` sons);
    - Ajustes: `:133` painel, `:161` janelas, `:182` papel, `:216` mascote, `:256` dia e noite,
      `:268` terminal, `:294` programas;
    - Cuidar (`:350`).
  - **Inventário**: `lugares.js:371-394` marca `mais: true` e o bloco «Mais ajustes».
  - **Desenho**: `app/pagina/app.js:745-755` (`MAIS_ABERTO` e `maisAjustes`). Chamadas em
    `paginas.js:210` (tema), `:426` (criar ícones), `:522` (criar sons), `:681` (ajustes) e
    `:795` (Cuidar, o `restaurar`).
  - **Ir até a linha**: `app.js:1122-1127` (`irPara` abre o `MAIS_ABERTO`).
  - **CSS**: `estilo.css:245-252` e `:379` (`.grade-tema .mais`).
  - **Servidor** (`--onde`): `app/servidor.py:5938`, `:5943`, `:5951`, `:5965` e `:5980`
    (`« › Mais ajustes»`).
- **Testes que exigem o recolhido ou o usam.**
  - `tests/app-navegador.py:16` (docstring item 4) e `:164-167`
    (`every((d) => !d.open)` nas 7 páginas): sai, ou vira «não existe `details.mais`».
  - `tests/app-completo.py:16` (docstring), `:623` e `:627` (`"mais:*"` nas listas de
    controles) e `:1298` e `:1330` (abre os `details.mais > summary`).
  - `tests/app-acessibilidade.py:7` e `:96`: abre todos antes de medir.
  - `tests/app-uso-real.py:197`.
  - `tests/migracao-do-painel.py:91` e `tests/app.sh:980-981`: esperam
    «… › Papel de parede › Mais ajustes» no `--onde` do `WALLPAPER_DRACULA_REPO`.
- **Cura na origem.**
  - Em `lugares.js`, cada item de `mais:` vai para o fim do bloco temático da página, ou para
    um bloco final «Raros» sem `details`. Por exemplo:
    - `FORMA_RECHEIO_*` → Forma;
    - `MIDIA_LARGURA`/`MIDIA_FONTE`/`MIDIA_COR_ALBUM` → o bloco da barra;
    - `CURSOR_VERSAO` → o bloco do ponteiro;
    - `AREAS_FOLGA` → Áreas.
  - Sai a chave `mais` das páginas.
  - `maisAjustes` e `MAIS_ABERTO` saem de `app.js`, as regras `.mais` do CSS e o `pus(…, "Mais
    ajustes", True)` do servidor.
  - O `--onde` diz o bloco onde o item caiu.
  - Os testes acima trocam a asserção.
- **Prova.**
  - `document.querySelectorAll('details.mais').length == 0` em toda página.
  - Todo `l.r` que estava em `mais:` aparece visível sem clique: o laço de `fluxo.py` › `mais`
    serve de molde.
  - `servidor.onde_na_tela("WALLPAPER_DRACULA_REPO")` não contém «Mais ajustes».
- **Tamanho.** M.

---

## Programas, Terminal e o que pede para baixar

### Q2-14 · «Escondidos» não sugere programas e aceita qualquer texto

Confirma a queixa 6 (6.png).

- **Passos.** Programas › Lançador › «Escondidos», digitar «lei».
- **Visto.**
  - Nenhuma sugestão aparece: o campo não tem `list` (`fluxo.json` › `escondidos`).
  - Enter grava «lei» como ficha «Lei». Não é id de nenhum `.desktop`.
  - O `/api/apps` da casa devolve 20 programas com `id` e `nome`: o dado existe.
  - O «Não abrem sozinhos» (`AUTOSTART_BLOQUEADOS`) usa o mesmo controle e tem o mesmo defeito.
  - Foto `F-escondidos-digitando.png`.
- **Causa.**
  - `app/pagina/app.js:531-556` (`controleLista`): `input.ficha-nova` sem `datalist` nem
    filtro. O `acrescentar` aceita qualquer `v`.
  - O servidor só manda `programas` (nome e ícone) para os ids que já estão na lista
    (`app/servidor.py:10366-10384`).
- **Cura na origem.**
  - `controleLista` recebe a fonte de sugestões quando a chave é de programa
    (`LANCADOR_OCULTAR`, `AUTOSTART_BLOQUEADOS`; marcar no esquema, por exemplo
    `item.sugere = "apps"`).
  - Ao focar, carrega `/api/apps` uma vez e mostra um menu abaixo do campo com até 8 programas
    que casam por `semAcento(nome)` ou id, com ícone e nome.
  - Enter ou clique grava o `id`.
  - Texto que não casa com nenhum id não vira ficha: o campo treme e fica.
- **Prova.**
  ```python
  pag.fill('[data-controle="chave:LANCADOR_OCULTAR:nova"]', "fire")
  checa(pag.locator(".sugestoes [role=option]").count() >= 1, "sugere")
  pag.fill('[data-controle="chave:LANCADOR_OCULTAR:nova"]', "zzz"); pag.keyboard.press("Enter")
  checa("zzz" not in (casa.valor_de("LANCADOR_OCULTAR") or ""), "não aceita id inventado")
  ```
- **Tamanho.** M.

### Q2-15 · «Tema do Spotify» pede «Baixar»; o tema não mora no pack meowsystem

Confirma a queixa 7 (6.png).

- **Visto.**
  - Programas › Lançador tem a linha «Tema do Spotify» com o botão «Baixar», que abre
    «Tema do Spotify?». A dica: «Baixa o tema catppuccin do spicetify de um commit fixo…»
    (`fluxo.json` › `spotify`, foto `F-spotify.png`).
  - A linha está no bloco «Lançador», que não é sobre o Spotify.
- **Onde está hoje.**
  - **Ação**: `app/servidor.py:4491-4500`, `spotify_baixar_tema` → `meow apps aplicar spotify`,
    `rede: True`. Botão em `app/pagina/lugares.js:280`.
  - **Código**: `scripts/temas-de-apps/spotify/manifesto.sh`. `_spot_tema_baixar` (`:588-640`)
    usa primeiro a arte do pack (`meow_app_tema_do_pack spotify.arquivo`); sem ela, baixa
    `github.com/<repo>/archive/<commit>.tar.gz` da origem que o pack declara.
  - **Pack meowsystem**: `packs/meowsystem/pack.json:50-61` declara só a `origem` (repo e
    commit pinados). Não há `packs/meowsystem/temas-de-apps/spotify/`: a pasta tem só `btop-bat`,
    `heroic`, `obsidian`, `qbittorrent` e `PROCEDENCIA.md`.
  - **Pack dracula**: já faz o certo. `packs/dracula/temas-de-apps/spotify/Sleek/`
    (`color.ini`, `user.css`, `LICENSE`) e `packs/dracula/pack.json:130-133` com `arquivo`.
  - **Órfão**: `assets/temas-de-apps/spotify/` (não rastreado; `acento.py`, `manifesto.sh`,
    `RECUPERACAO.md`, `xpui.py` de 01/09) é uma cópia antiga do que a P96 moveu para
    `scripts/temas-de-apps/`. Os outros `assets/temas-de-apps/*` também.
- **Cura na origem.**
  1. Vendorar o `catppuccin/spicetify` no commit já pinado do `pack.json`, só a pasta
     `catppuccin/` (`color.ini`, `user.css`, `theme.js` se houver, `LICENSE`), em
     `packs/meowsystem/temas-de-apps/spotify/catppuccin/`, com linha no `PROCEDENCIA.md` e
     `SHA256SUMS`.
  2. `packs/meowsystem/pack.json`: `spotify.arquivo = "temas-de-apps/spotify/catppuccin/color.ini"`.
     A `origem` fica só como procedência.
  3. O tema se aplica pelo caminho normal (`apps_aplicar` e o `install`, com `spotify` em
     `APPS_ATIVOS`) sem rede. O spicetify em si continua sendo o braço; se ele faltar, é
     pendência do doctor, não botão.
  4. Sai a linha `spotify_baixar_tema` de `lugares.js:280` e a ação de `servidor.py:4491-4500`
     (ou fica sem botão, chamada só pelo doctor).
  5. `assets/temas-de-apps/` não rastreado: apagar (entra no B0 «enxugar o repo»).
- **Prova.**
  - `pack.py validar meowsystem` verde com o sha do tema.
  - `MEOW_DRY_RUN=1 meow apps aplicar spotify` numa casa sem rede (falso `curl` que falha)
    termina sem a linha «baixaria o tema».
  - No painel, `[data-controle="acao:spotify_baixar_tema"]` não existe.
- **Tamanho.** M.

### Q2-16 · Tudo que, na interface, pede para baixar ou instalar

Queixa 8. A regra pedida: o pack traz, e a interface no máximo oferece «trazer .zip», como o
ponteiro. Lista completa, tirada de `lugares.js` e das ações com `rede: True`:

| onde | linha | botão | ação | o que faz | proposta |
|---|---|---|---|---|---|
| Ajustes › Terminal › Linha de comando | `lugares.js:265` | «Instalar» | `prompt_instalar_starship` (`servidor.py:4379-4386`) | baixa o starship de starship.rs | sai: a decisão 26 (02-decisoes) já põe o starship no install. Hoje a linha aparece apagada mesmo com ele instalado (dica «O starship já está instalado», `F-terminal.png`) |
| Ajustes › Terminal › Mais ajustes | `lugares.js:268` | «Trazer fonte» | `acervo:fonte` (`servidor.py:6998-7002`) | instala .zip/.ttf/.otf da usuária | **fica** (é o modelo do ponteiro); vai para o bloco do terminal ao sair o «Mais ajustes». Falta escolher a fonte: a mensagem do acervo diz «escolha-a onde quiser usá-la», e não há esse lugar no painel |
| (sem botão) fonte do terminal | `scripts/instalar_fontes.sh:1-3` | — | etapa do install | **baixa** o JetBrainsMono Nerd Font da release pinada | o pack traz: vendorar a fonte (licença OFL) em `packs/meowsystem/fontes/` e o script instala dali; fica fora da interface |
| Ajustes › Papel de parede › cabeça | `lugares.js:172` | «Baixar» («Coleção do tema») | `wallpaper_semear` (`servidor.py:4333-4340`) | refaz a coleção da lista de fontes, com rede | sai: a decisão 23 diz que o install semeia sozinho; quem conserta é o doctor |
| Ajustes › Papel de parede › Mais ajustes | `lugares.js:192` | «Construir» | `files_menu_build` (`servidor.py:4425-4432`) | baixa o fonte do cosmic-files e compila (minutos) | sai da interface: o `garantir_builds.sh` e o `meow-builds-login.service` já fazem sozinhos; vira estado no Manter |
| Ajustes › Programas › Lançador | `lugares.js:280` | «Baixar» | `spotify_baixar_tema` | Q2-15 | sai |
| Cuidar › pendências | `lugares.js:312` | «Instalar» | `vscode_instalar_extensao` (`servidor.py:4479-4487`) | instala extensão do VS Code da loja | **fica**: a decisão 9 exige gesto para pack importado |
| Cuidar › Instalar de novo | `lugares.js:325` | «Instalar» | `instalar` | install inteiro | fora da minha área (QA-3) |
| Criar tema › ícones | `lugares.js:66` | «Trazer .zip» | `acervo:tema-icones` | tema de ícones de fora | fica (é o modelo); o QA-1 questiona o sentido |
| Ajustes › Janelas › ponteiro | `lugares.js:150` | «Trazer .zip» | `acervo:cursor` | o modelo pedido | fica |

- **Prova.**
  - Um teste percorre `inventarioDoPainel()` e falha se algum botão com `b` em
    `{"Baixar","Instalar","Construir"}` estiver em Ajustes.
  - `grep -n 'rede: True'` nas ações ligadas a Ajustes dá só as que ficam.
- **Tamanho.** M (a fonte vendorada é a parte maior).

---

## O que sumiu

### Q2-17 · O «Modo de leitura» virou o bloco «Tela quente» e perdeu a prévia

Queixa 9, parte 1.

- **Achado.**
  - Até a P98 o painel tinha a aba «Modo de leitura»
    (`git show 20b285d8^:app/servidor.py`, linha 3448: «A tela quente à noite: a temperatura, a
    textura e o horário.»), com prévia própria: a imagem real pintada na temperatura, com
    régua de 24 h (`git show 20b285d8^:app/pagina/app.js`, linhas 2609-2760).
  - A P98 (`20b285d8`, 23/10, «o painel novo - quatro portas…») juntou a aba em Ajustes › Dia e
    noite como bloco «Tela quente» (`app/pagina/lugares.js:238-247`), com:
    - «Esquentar agora» e «Desligar agora» (`leitura_aplicar`, `leitura_remover`);
    - «Tela quente agora · Ver» no «Mais ajustes» (`:256`).
  - A prévia rica não voltou, e a de hoje só esquenta com a agenda ligada (Q2-03).
  - A palavra «leitura» não aparece em rótulo nenhum. Só pode achar pela busca se o título da
    chave tiver a palavra. Não medi a busca por «leitura».
- **Cura na origem.**
  - O bloco volta a se chamar «Modo de leitura», e o interruptor `LEITURA_AGENDA` fica como
    primeira linha.
  - A prévia segue o Q2-03.
  - O applet da barra (`LEITURA_APPLET`, «Botão na barra») é o `meowsystem-leitura`, e a
    integração dele é de outro bloco (ANDAMENTO).
  - Se ela quer de volta uma página própria em Definir, ver o fim.
- **Prova.**
  - A busca por «leitura» acha o bloco: `procurar()` com `#busca` = «leitura» dá 1 ou mais
    `#achados [role=option]`.
  - A prévia esquenta com a agenda desligada.
- **Tamanho.** P (nome e busca) / G (prévia rica).

### Q2-18 · «Gerador de build (idempotência do PC)»: não há nada com esse nome

Queixa 9, parte 2.

- **Achado.**
  - `git log -S gerador` em `app/`, `bin/` e `scripts/` só acha o gerador de temas, de logo e
    de mascotes.
  - Toda ação do servidor de antes da P98 continua ligada a um botão hoje: das 69, só a
    `consertar` não está na tela, e ela é interna. Comparei as chaves de `ACOES` em `20b285d8^`
    com o `lugares.js`.
  - Candidatos ao que ela chama assim:
    1. **A aba «Instalação»** de antes da P98: «Instalar, conferir, consertar, desfazer, e ver o
       que está no ar». Tinha «Instalar tudo», «Conferir a máquina», «O que está no ar agora»,
       registro, «Restaurar», «Voltar ao tema de antes» e «Desinstalar». A P98 espalhou tudo
       por Cuidar (cartão «Instalar de novo», `Registro`, `perigo`) e Tema («No ar agora»,
       `lugares.js:39`). A segunda passada que «não escreve nada» é o assunto do QA-3 (hicolor).
    2. **Os builds do compositor e do menu do Arquivos.** `scripts/garantir_builds.sh` refaz o
       que falta para a versão do apt. Roda só pelo `meow-builds-login.service`, pelo doctor
       e pelo `cosmic_pos_apt.sh`. O painel não mostra o estado nem tem botão.
    3. **«Outro computador»** (Cuidar: «Guardar ajustes» e «Trazer ajustes») é o que reproduz
       um PC.
- **Cura na origem.** Precisa dela dizer qual dos três. Ver o fim.
- **Tamanho.** —

---

## Miúdos

### Q2-19 · Linha de duas colunas: dois ↶ iguais e uma dica só

- **Visto.**
  - Na linha dupla, o botão «Voltar ao padrão» de cada coluna fica no rótulo, um ao lado do
    outro, sem dizer qual é qual (4.png; `aplicar.json` › `padrao_onde: "no rotulo"`).
  - A dica do rótulo usa só a frase da coluna «Barra de cima».
  - Os botões XS…XL (`.seg`) não têm dica.
- **Causa.**
  - `app/pagina/app.js:638-680` (`linhaDeChave`): o `rot` recebe um `botaoPadrao` por item e a
    `dica` do primeiro.
  - `controle()` (`app.js:347`) não põe `dica` nos botões do `.seg`.
- **Cura na origem.**
  - O ↶ de cada coluna mora na célula dela (`.ctl`), à direita do controle.
  - A dica do rótulo é a frase comum.
  - Cada botão do `.seg` ganha `dica` com o tamanho em px que o valor dá.
- **Prova.**
  - `[data-controle="padrao:FORMA_DOCK_SOLTO"]` tem `.closest('.ctl')` não nulo.
  - `.seg button` tem `title` ou dica.
- **Tamanho.** P.

### Q2-20 · Deslizante «Auto» no mínimo, e margem ativa com a barra colada

- **Visto.**
  - Os `FORMA_MARGEM_*`, `FORMA_RAIO_*` e `FORMA_ESPACO_*` aceitam vazio («não toca»). O
    deslizante mostra o polegar no 0 e o rótulo «Auto»: parece «zero» (4.png,
    `L-1920x1080-painel-topo.png`).
  - Com «Solta da borda» desligada, o deslizante de «Distância da borda» continua ativo, e
    o `forma.sh` descarta o número (4.png).
- **Causa.**
  - `app/pagina/app.js:435` (`controleFaixa`): o vazio cai no `min`.
  - O esquema não declara `dominada_por` da `FORMA_MARGEM_*` pela `FORMA_*_SOLTO`.
- **Cura na origem.**
  - Vazio = polegar escondido e trilho tracejado. O primeiro arrasto dá valor.
  - O «↶» volta ao vazio só se a decisão 10 permitir (lá diz: padrão de fábrica, e «não tocar»
    é outro gesto).
  - `FORMA_MARGEM_PAINEL` e `FORMA_MARGEM_DOCK` ganham `dominada_por` do `SOLTO` do mesmo lado
    (apagado com `SOLTO=nao`).
- **Prova.** Com `FORMA_DOCK_SOLTO=nao`, `[data-controle="chave:FORMA_MARGEM_DOCK"]` está `disabled`.
- **Tamanho.** P.

### Q2-21 · A lista de pendentes repete o rótulo sem dizer a coluna

- **Visto.** Depois de mexer nas duas colunas, a lista mostra duas vezes
  «Solta da borda · Painel e dock» (`F-lista-pendentes.png`).
- **Causa.** `app/pagina/app.js:1020` (`listaDePendentes`) usa o `rotulo` da linha, sem a coluna.
- **Cura na origem.** Rótulo «Solta da borda (dock)». Com o Q2-07 esta lista vira o histórico e
  herda a mesma regra.
- **Tamanho.** P.

### Q2-22 · A casa de teste morre no checkout atual (repositório aninhado)

- **Visto.**
  - `tests/app-completo.py` (e quem o importa: `app-navegador.py`, `app-acessibilidade.py`)
    caem em `IsADirectoryError`.
  - O `git ls-files --others` lista o repositório aninhado `assets/icones/upstream/papirus-folders/`
    como pasta, e o `shutil.copy2` não copia pasta.
- **Causa.** `tests/app-completo.py:150-160` (`copiar_raiz`).
- **Cura na origem.** Pular a entrada que termina em `/` (ou `os.path.isdir`) com `copytree`. O
  B0 (enxugar o repo) tira o não rastreado de `assets/`, mas o teste não pode depender disso.
- **Prova.** `tests/app-navegador.py` sobe a casa com esse diretório presente.
- **Tamanho.** P.

### Q2-23 · `app/pagina/previas-tela.js` e `previas-sistema.js` são órfãos

- **Visto.** Dois arquivos não rastreados (72 KB e 137 KB, de 09/09). A P98 os apagou do git
  (`20b285d8`), e o `index.html` não os carrega.
- **Cura na origem.** Apagar (entra no B0).
- **Tamanho.** P.

---

## Conflita com decisão registrada

| decisão | o que diz | o que este relatório propõe | por quê conflita |
|---|---|---|---|
| **18** (`02-decisoes.md`) | «Ações do painel: só Executar e Restaurar; o resultado abre numa janela…; «Ver o que faria» vira «Ver sem mudar»» | Q2-07 tira o «Ver sem mudar» e a janela de resultado do gesto de ajuste | o «grava ao soltar» de 26/10 sobrescreve a parte do ensaio para controles; para **ações** (botões) a decisão 18 continua. Pede trocar a linha 18 com o sim de 26/10 citado |
| **10** (`02-decisoes.md`) | «Deixa dois botões: Restaurar ao Padrão e Aplicar» (21/09) | Q2-07 tira o «Aplicar»; o «Restaurar ao padrão» passa a gravar na hora | o «Aplicar» da frase de 21/09 cai pela decisão de 26/10; a regra do valor de fábrica continua |
| **14** (`P82-abertos.md`) | «O doctor instala o starship? Não… o botão fica, e some quando ele existe» | Q2-16 tira o «Instalar» do starship | a decisão 26 (`02-decisoes.md`, 23/10) já pôs o starship no install; a 14 da P82 ficou velha. Hoje o botão também não some: aparece apagado |
| **7** (`02-decisoes.md`) e **12** | o consertar baixa com selo de rede, sem pergunta; trocar de pack baixa o ponteiro | Q2-15 e Q2-16 (fonte e Spotify vendorados no pack) | não desfaz: diminui o que baixa. Fica registrado porque o selo de rede some dessas ações |
| **9** (`02-decisoes.md`) | extensão do VS Code de pack importado só por gesto | Q2-16 **mantém** o «Instalar» da extensão | a regra «nada pede para instalar» de 26/10 não pode tirar este, sem sim explícito sobre o tema |
| `tests/app-navegador.py` item 4 | «O «Mais ajustes» nasce recolhido em toda página» | Q2-13 tira o «Mais ajustes» | é teste, não decisão; a decisão de 26/10 («Mais ajustes some») o derruba |

## Precisa da usuária decidir

1. **Q2-07, a chave sem aplicador próprio.** Gravar e rodar um «Instalar tudo» em segundo plano,
   sem janela (proposto), ou gravar e esperar o doctor da manhã?
2. **Q2-07, o tamanho do histórico.** Desfazer só o último gesto, ou uma lista com as últimas N
   (proposto: 20, só enquanto a aba estiver aberta)?
3. **Q2-12, Programas.** (a) sem prévia, com a grade larga, ou (b) prévia dos programas vestidos?
4. **Q2-17, o modo de leitura.** Volta como bloco «Modo de leitura» dentro de Dia e noite
   (proposto), ou como página própria em Definir?
5. **Q2-18, o «gerador de build».** É (1) a antiga aba «Instalação», (2) o estado e o refazer dos
   builds do compositor e do menu do Arquivos, ou (3) o «Outro computador» (guardar e trazer os
   ajustes)?
6. **Q2-16, a fonte do terminal.** Vendorar o JetBrainsMono Nerd Font no pack (cerca de 2 MB por
   peso) e parar de baixar? E ela quer escolher a fonte do terminal no painel (hoje não há onde)?

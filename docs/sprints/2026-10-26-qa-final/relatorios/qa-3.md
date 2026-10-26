# QA-3 — Cuidar (vai ser «Manter»), o modal «Instalar tudo», idempotência, o «…», créditos, README e Extensões

Data: 26/10/2026 · branch `dev` (`16927be8`) · sem correção nem commit: só achados.

**Como medi.** O painel subiu na casa de brinquedo do `tests/app-completo.py` (HOME temporário,
PID próprio, falsos de `sudo`/`pkexec`/`apt`, sem barramento), e o Chrome rodou só headless.
Script: `/tmp/claude-1000/-home-vitoriamaria-Desenvolvimento-MeowSystem/314702cb-6fd7-4227-9dcc-7970f525cc19/scratchpad/qa-3/qa3.py`
(medidas brutas em `resultado.json`, ao lado dele). O instalador foi lido no código, e o
comportamento real foi lido (só lido) no log e nas datas de arquivo do HOME real. Fotos em
`relatorios/fotos/qa-3/`.

**Para quem executa.** Cada item diz o arquivo e a linha, a cura e o teste que fica verde. Os
itens Q3-01, Q3-02 e Q3-06 são independentes entre si. Q3-03 e Q3-04 mexem nos mesmos arquivos
(`lugares.js`, `paginas.js`, `estilo.css`) e vão juntos. Q3-10 é plano: só se executa depois que
ela responder as perguntas do fim.

---

## Q3-01 · O modal «Instalar tudo» fica mais largo que a janela e corta os botões

- **Passos.** Rodar «Instalar tudo» (ou «Aplicar», ou «Ver sem mudar» de qualquer ajuste: é o
  mesmo instalador) até o registro mostrar uma linha com um caminho longo. No log real de hoje
  (`~/.local/state/meowsystem/logs/2026-10-26-155910-instalar-tudo.log`) a mais longa é o caminho
  de 108 caracteres do tema do qBittorrent (`~/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent/themes/catppuccin-mocha.qbtheme`).
- **Visto** (1920×1080, medido no DOM):
  - a janela tem 560 px, mas a coluna de dentro cresceu para 744 px;
  - o «Guardar» vai de x=1278 a 1375, e a janela termina em x=1240;
  - a janela rola na horizontal (`scrollWidth` 768 contra `clientWidth` 558);
  - «Parar» e «Guardar» aparecem cortados; «OK» fica fora;
  - as linhas do registro passam da moldura.
  - Fotos: `q3-01-modal-log-real-1920x1080.png` (o defeito) e `q3-01-modal-ensaio-1920x1080.png`
    (com log curto não acontece, e por isso o teste de hoje não pega).
- **Esperado.** A janela nunca rola na horizontal, os botões ficam sempre dentro, e a linha longa
  quebra dentro do registro.
- **Causa** (`app/pagina/estilo.css`):
  - `:515`: `dialog .dentro { display: grid; … }` não define colunas. A coluna implícita é `auto`,
    e um item de grid tem `min-width: auto`: ela cresce até o min-content do `details#registro`.
  - `:527`: `.registro pre { white-space: pre-wrap; … }` sem `overflow-wrap`. O min-content dele
    é a palavra mais longa (o caminho de 108 caracteres, ou a linha de 52 `─` do título do passo),
    e o `overflow: auto` do `pre` não segura, porque a coluna já cresceu antes.
- **Cura na origem** (só CSS):
  - `dialog .dentro { grid-template-columns: minmax(0, 1fr); }`
  - `.registro pre { overflow-wrap: anywhere; }`
  - Opcional: `dialog.resultado { width: min(880px, calc(100vw - 32px)); }`, porque um registro de
    instalador em 560 px quebra quase toda linha.
  - Medido com a cura injetada: coluna de 510 px, sem rolagem, «Guardar» e «OK» dentro
    (`q3-01-modal-com-cura-1920x1080.png`).
- **Prova.** Num teste de navegador do painel (`tests/app-navegador.py`, onde já se abre o
  `#resultado`):
  1. abrir `#resultado` com uma linha de 200 caracteres sem espaço no `#saida`;
  2. exigir `dialog.scrollWidth <= dialog.clientWidth`;
  3. exigir que a borda direita de `#resultado-ok` fique dentro da borda direita do dialog;
  4. fazer o mesmo em 1280×800.
- **Tamanho.** P.
- **Fotos.** `q3-01-modal-log-real-1920x1080.png`, `q3-01-modal-com-cura-1920x1080.png`,
  `q3-01-modal-ensaio-1920x1080.png`, `q3-01-modal-ensaio-fim-1920x1080.png` (e as de 1280×800,
  com o mesmo nome).
- **Junto, menor.** O título da janela é sempre o rótulo da ação («Instalar tudo»), mesmo quando
  ela clicou «Ver sem mudar» num ajuste (`app.js:883`). Isso sai de graça quando o Q3-07 trocar o
  caminho do Aplicar.

## Q3-02 · O instalador sai 2: o «hicolor» escreve em toda passagem

- **Passos.** `install.sh` numa casa com pelo menos um jogo da Steam (ou do Heroic) com ícone
  plantado. No log real de 26/10 15:59:
  - a passagem 1 diz `mexeu: hicolor`;
  - a passagem 2 diz `mexeu: hicolor`;
  - depois vem `as mesmas etapas escreveram em duas passagens seguidas: hicolor` (`install.sh:4120`)
    e `saiu 2`.
- **Visto no HOME real** (só lido):
  - a `~/.local/share/icons/hicolor/icon-theme.cache` tem data 16:00:09;
  - as pastas `16x16/apps`, `22x22/apps`, `24x24/apps`, `32x32/apps`, `48x48/apps`, `56x56/apps`,
    `64x64/apps`, `72x72/apps` e `80x80/apps` têm 16:00:15, 6 s depois;
  - nenhum arquivo dentro delas é de hoje (os mais novos são de 25/10).
  - Ou seja: alguém criou e apagou um arquivo em cada pasta.
  - O `doctor.log` mostra o mesmo todo dia (`~~ hicolor reindexaria…` e
    `cache do hicolor do usuário reindexada`).
- **Causa** (a origem, não o hicolor):
  - **`scripts/jogos_steam.sh:207`**, em `plantar_icone`: cria o temporário com
    `mktemp -p "$dir"` DENTRO de `~/.local/share/icons/hicolor/<px>x<px>/apps`. Depois converte,
    compara com `cmp -s` e, quando é igual, faz `rm -f "$tmp"` (`:213-214`).
    - Criar e apagar muda a data da pasta, em todos os degraus da escada (16 a 80 nesta tela),
      em toda passagem, mesmo sem mudar nenhum ícone.
  - **`scripts/jogos_heroic.sh:274`**: o mesmo molde.
  - A etapa `jogos` roda depois da `hicolor` (`install.sh:2572` e `:2581`).
  - Na passagem seguinte, `scripts/hicolor.sh:119-122` (`find "$BASE" -mindepth 1 -newer icon-theme.cache`)
    acha as pastas, reindexa e sai 1. Isso se repete em toda passagem, e o guarda sai 2.
  - **Pior: no modo seco também.** O `meow_seco` só é olhado depois do `mktemp`, então «Ver sem
    mudar» e todo `chk_` do doctor (`bin/meow:714`) escrevem no HOME, que o seco promete não
    tocar.
  - Prova da mecânica, numa pasta de rascunho: depois de `mktemp -p <pasta>` e `rm`, o
    `find -newer cache` passa a listar a pasta; com `-type f` não lista nada.
- **Cura na origem.**
  - Nos dois scripts, o render e a comparação vão para um temporário FORA do destino:
    `mktemp "${TMPDIR:-/tmp}/meow-icone.XXXXXX.png"`.
  - Só quando difere, e fora do seco, faz `install -m644 "$render" "$dir/.meow.XXXXXX.png"` e
    `mv -f` para o destino. Assim o `mv` continua atômico no mesmo sistema de arquivos (trava 2 do
    `lib/comum.sh`).
  - É o molde de `lib/comum.sh:721` (`meow_escrever`, que compara antes de criar o temporário) e
    de `scripts/temas-de-apps/btop-bat/manifesto.sh:390-400` (no seco, o temporário vai para o
    `$TMPDIR`).
  - **Não** «consertar» trocando o `hicolor.sh:121` por `-type f`: apagar um ícone só aparece na
    data da pasta, e a cache precisa ver isso.
- **Prova.**
  1. `tests/um-cartao-por-jogo.sh`, na «2ª rodada: idempotência» (`:119`): com `convert`
     presente e um PNG de verdade como fonte, guardar `stat -c %Y` de cada `$HICOLOR/*/apps`
     antes da segunda rodada e exigir que nenhuma mude.
  2. No mesmo teste: rodar `scripts/hicolor.sh`, depois `jogos_steam.sh`, depois `hicolor.sh` de
     novo, e exigir que o segundo `hicolor.sh` saia 0.
  3. Rodar `jogos_steam.sh` com `MEOW_DRY_RUN=1` e exigir que nenhum arquivo nem data de pasta
     mude no HOME.
  4. O mesmo em `tests/jogos-heroic.sh:87`.
  5. `tests/convergencia.sh` ganha um jogo da Steam na casa dele. Hoje não tem nenhum, por isso o
     defeito passa invisível pela suíte.
- **Tamanho.** P.
- **Fotos.** Nenhuma (é do instalador).
- **Mesma família, anotado.**
  - O `doctor.log` real repete todo dia `~~ lancador o mimeinfo.cache do home é mais velho que um
    lançador`. É o mesmo cheiro (uma data que algo mexe sem mudar conteúdo); vale medir no
    próximo bloco.
  - O rodapé do guarda diz `o que olhar primeiro: meow doctor` (`install.sh:4123` e `:4145`). É
    uma saída que manda digitar, contra a regra «nenhuma saída manda digitar».

## Q3-03 · Cuidar: nos três cartões, o desenho fica em cima do texto e dos botões

- **Passos.** Abrir Cuidar em 1920×1080 e em 1280×800 e olhar «Outro computador», «Atualizar»
  e «Instalar de novo».
- **Visto** (medido em 1920×1080, no cartão «Outro computador»):
  - o ícone ocupa x 161–205, y 858–902;
  - o título começa em y 918, embaixo do ícone;
  - os botões começam em y 955;
  - são três andares, e cada cartão tem 187 px de altura para uma linha de botões.
  - Foto: `q3-03-cuidar-1920x1080.png`.
- **Esperado.** O desenho à esquerda; à direita dele, o título em cima e os botões embaixo.
- **Causa.** `app/pagina/estilo.css:507`: `.cartao-acao { display: grid;
  grid-template-rows: auto auto 1fr; … }` tem uma coluna só, então ícone, `h2` e `.fila` empilham.
  O DOM vem de `paginas.js:768-772`.
- **Cura na origem** (só CSS; o DOM fica):
  ```css
  .cartao-acao { grid-template-columns: auto minmax(0, 1fr); grid-template-rows: auto 1fr; column-gap: var(--e-4); }
  .cartao-acao .icone { grid-row: 1 / span 2; align-self: start; }
  .cartao-acao h2, .cartao-acao .fila { grid-column: 2; }
  ```
  A `.fila` já quebra linha. Em 1180 px ou menos os cartões viram `span 3` (`estilo.css`, bloco
  `@media`), e o arranjo continua cabendo.
- **Prova.** Em `tests/app-completo.py` (casa já pronta, rota `cuidar`):
  1. para cada `.cartao-acao`, exigir `icone.right <= h2.left` e `|icone.top - h2.top| <= 4`;
  2. exigir `fila.left == h2.left`;
  3. medir em 1920×1080 e em 1280×800.
- **Tamanho.** P.
- **Fotos.** `q3-03-cuidar-1920x1080.png`, `q3-03-cuidar-1280x800.png`.

## Q3-04 · «Conferir e consertar» sai do Cuidar

- **Pedido dela** (ANDAMENTO 26/10): «Conferir e consertar» some.
- **Onde ele está hoje:**
  - `app/pagina/lugares.js:303`: primeiro botão do topo do Cuidar, e por isso «principal»
    (`paginas.js:782`);
  - `app/pagina/app.js:832`: é o OK da caixa «Falta a ponte»;
  - `app/pagina/app.js:935-939`: aparece de novo dentro do resultado do «Conferir», quando o
    doctor sai 1 (`conserta_com`, `servidor.py:3887`);
  - `app/servidor.py:5766`: é o «Resolver» da pendência `leitura-applet`, cujo nome na tela é
    «Conferir e consertar» (ver Q3-06).
- **Cura.**
  1. Tirar a linha `doctor_consertar` de `LUGAR_CUIDAR.estado` (`lugares.js:302-305`). O topo fica
     só com «Conferir».
  2. A ação `doctor_consertar` continua existindo no servidor. Ela segue em três lugares: no
     botão que nasce no resultado do «Conferir» quando há o que consertar; no OK da «Falta a
     ponte»; e nas pendências. Assim nada que hoje se conserta perde o caminho, e o doctor das
     5h continua consertando sozinho.
  3. Atualizar as provas que procuram o texto:
     - `tests/app-navegador.py:137`
     - `tests/app-completo.py:1433-1437`
     - `tests/migracao-do-painel.py:234`
     - `tests/app.sh:625`
     - `tests/ponte-reparo.sh:334`
     - Elas passam a achar o botão no resultado do «Conferir» ou na caixa da ponte.
  4. Junto: a troca de nome Cuidar → «Manter» (ANDAMENTO 26/10):
     - `lugares.js:19`;
     - as frases do servidor que dizem «em Cuidar» (`servidor.py:5990-5992`, `onde_na_tela`);
     - `tests/app.sh:982`;
     - `tests/nada-manda-digitar.sh`;
     - `app/pagina/standalone.js`;
     - `index.html`.
     - `grep -rn Cuidar app tests` dá 23 linhas no código. O id da rota (`#cuidar`) pode ficar,
       para não quebrar link guardado.
- **Prova.**
  - `tests/app-completo.py`: na rota `cuidar`, nenhum `[data-controle="acao:doctor_consertar"]`
    no topo.
  - Com a casa sem ponte, clicar «Conferir» e exigir que o resultado traga
    `[data-controle="resultado:consertar"]`.
  - `tests/decisoes.sh` segue verde.
- **Tamanho.** M (pelas provas).
- **Conflito.** A decisão 11 (`02-decisoes.md:19`, ampliada na P104) cita o «Conferir e
  consertar» como o caminho que repõe a ponte sem senha. A cura acima não desfaz isso: o caminho
  continua, só sai do topo. Ver «conflita com decisão registrada».

## Q3-05 · Cuidar, botão por botão

Rodado na casa de brinquedo, em 1920×1080: sem ponte, sem rede e com `sudo` falso. Por isso
toda ação de root para em «Falta a ponte», e isso é o esperado. As ações que perguntam foram
respondidas com «Ver sem mudar» quando havia essa opção. Nenhum erro de JavaScript nas duas
larguras.

| botão | o que aconteceu | veredito |
|---|---|---|
| Guardar ajustes | baixou `meow-20261026-1656.conf` (121 KB) | ok |
| Trazer ajustes | conf com `LOG_NIVEL="debug"` e uma chave inexistente: entrou 1 mudança na barra, com a torrada «1 mudança esperando o Aplicar»; a chave inexistente sumiu calada | ok; sobre a barra, ver Q3-07 |
| Atualizar | «Falta a ponte» → Cancelar | ok (sem ponte) |
| Ver | janela «O que muda», «Mostrou · 0.2s» | ok |
| Limpar | «Falta a ponte» | ok (sem ponte) |
| Instalar | «Falta a ponte» (também em 1280×800) | ok (sem ponte) |
| Conferir | janela «Conferir a máquina», «Há divergências · 14.6s», última linha «o conserto do doctor as acerta» | ok; é o botão que fica no topo (Q3-04) |
| Conferir e consertar | rodou 90 s e saiu 2: 16 verificações «continua fora depois do conserto» (ponte, upstream, greeter…) | esperado sem ponte e sem rede; não é achado |
| Registro › Ver | janela «Ver o registro», com as últimas linhas do log | ok |
| Quanto fala: Pouco / O que mudou / Tudo | cada clique põe `LOG_NIVEL` na barra; voltar ao valor de agora tira a mudança | ok |
| Cópias guardadas | seta → `BACKUPS_MANTIDOS=11`, e o número ao lado acompanha | ok |
| Sozinho (9 interruptores) | todos trocam e vão para a barra (1 → 9 mudanças); nenhum aplica sozinho | ok hoje; muda com o «aplica ao soltar» (Q3-07) |
| Tema de antes › Voltar | pergunta com «Ver sem mudar» → «Nada mudaria» («o backup de antes não tem tema do COSMIC») | ok |
| Desinstalar | «Falta a ponte» | ok (sem ponte) |
| Restaurar (Mais ajustes) | existe, desabilitado (sem ponto de restauro) | ok; mas é o único item do «Mais ajustes», que vai sair (ver «Menores») |
| Pendência Resolver (Construir o menu) | pergunta com «Ver sem mudar» → «compilaria o cosmic-files… (~161 MB, minutos)» | ok |
| Pendência Trocar (tema de terceiro, Discord na casa; qBittorrent na máquina dela) | pergunta com «Ver sem mudar» → «Nada mudaria», porque o Discord não está instalado na casa | ok |
| Pendência Manter | roda direto, sem pergunta: «Já estava assim» | ok |
| Pendência Não, obrigado | «Não perguntar de novo?» → Cancelar | ok |
| «…» › Créditos | link `https://github.com/[REDACTED]/MeowSystem`, `target=_blank` | **defeito**: ver Q3-09 |

**Defeitos achados aqui:**

- os nomes das pendências (Q3-06);
- o «Créditos» (Q3-09);
- em 1280×800, os botões dos três cartões ficam desalinhados: «Guardar ajustes» e «Trazer
  ajustes» quebram em duas linhas (fila de 92 px contra 40 px). Com o Q3-03, conferir de novo
  nessa largura (`q3-03-cuidar-1280x800.png`).

**Visto e não medido:** o «Resolver» das três pendências «Instalar tudo» cai em «Falta a ponte»,
porque a ação é a de root.

- **Prova.** O `tests/app-completo.py` já clica os controles do Cuidar
  (`OBRIGATORIOS`/`:619`). Pede-se acrescentar:
  1. o `menu:creditos` (Q3-09);
  2. o alinhamento dos cartões (Q3-03).
- **Tamanho.** —, porque é inventário.
- **Fotos.** `q3-03-cuidar-1920x1080.png`, `q3-03-cuidar-1280x800.png`,
  `q3-03-trazer-ajustes.png`, `q3-03-sozinho-mexido.png`, `q3-05-menu.png`, `q3-05-creditos.png`.

## Q3-06 · Três pendências com o mesmo nome «Instalar tudo», e uma chamada «Conferir e consertar»

- **Passos.** Abrir Cuidar com as pendências `instalar-com-root`, `flatpak-global-sistema` e
  `libreoffice-sistema` (a casa de brinquedo já tem as três).
- **Visto.**
  - Três linhas iguais, «Instalar tudo», cada uma com «Resolver».
  - Uma linha chamada «Conferir e consertar» (é a `leitura-applet`).
  - Não dá para saber o que cada uma resolve. Só a dica (o `title`) tem a frase.
  - Foto: `q3-03-cuidar-1920x1080.png`.
- **Causa.**
  - `app/servidor.py:6063-6064`: quando a pendência tem ação, o nome fica vazio.
  - `app/pagina/paginas.js:713`: com o nome vazio, a página cai no rótulo da AÇÃO
    (`acao.rotulo`).
  - Quatro pendências apontam para só duas ações (`ACAO_DA_PENDENCIA`, `servidor.py:5755-5767`).
- **Cura na origem.**
  - Um mapa `NOME_DA_PENDENCIA` ao lado do `ACAO_DA_PENDENCIA` (`servidor.py:5755`), com o
    assunto da pendência e não o verbo do botão. Por exemplo:
    - `instalar-com-root` → «Ponte de root»
    - `flatpak-global-sistema` → «Tema dos flatpaks do sistema»
    - `libreoffice-sistema` → «LibreOffice do sistema»
    - `leitura-applet` → «Applet de leitura»
    - `files-menu-build` → «Menu do Arquivos»
  - O `fora.append` usa esse nome.
  - O botão segue «Resolver», com a dica do rótulo da ação, como já é hoje (`paginas.js:715-716`).
- **Prova.** Em `tests/app.sh`: para toda chave de `ACAO_DA_PENDENCIA`, exigir um nome em
  `NOME_DA_PENDENCIA`; nas pendências lidas da casa de brinquedo, exigir nomes todos diferentes e
  nenhum igual a um `rotulo` de ação.
- **Tamanho.** P.
- **Fotos.** `q3-03-cuidar-1920x1080.png`.

## Q3-07 · Como «Instalar» e «Aplicar» se ligam hoje (só o mapa; os controles são da QA-2)

- **«Aplicar»** (`app.js:1210`, a barra do topo):
  1. chama `salvarEscolhas()`, que manda `POST /api/salvar` (`servidor.py:10494`);
  2. o servidor valida e grava as chaves no `meow.conf`;
  3. em seguida chama **sempre** `iniciar("instalar", …)` (`servidor.py:10528` e `:10575`), o
     `install.sh` inteiro: 68 etapas, duas ou mais passagens. Isso leva minutos, e hoje termina
     sempre em «saiu 2» por causa do Q3-02.
  - O «Ver sem mudar» é o mesmo caminho com `seco`: o instalador inteiro em ensaio, sobre uma
    cópia do conf.
- **«Instalar»** (Cuidar › Instalar de novo):
  - é a ação `instalar` (`servidor.py:3842`, `sudo: True`) por `/api/rodar`;
  - o mesmo `install.sh`;
  - a única diferença é que a página barra antes, quando falta a ponte (`app.js:839`). O `/api/salvar`
    não barra: o «Aplicar» roda o instalador mesmo sem ponte.
- **O que não existe.** Rodar só a etapa de uma chave. O cabeçalho das opções do `install.sh`
  (`:3788-3816`) diz «QUAIS etapas rodam é decisão do meow.conf, não da linha de comando», e não
  há flag de etapa.
- **«Trazer ajustes»** também entra por essa barra (`app.js` `importarArquivo`): as chaves vão
  para `MUDANCAS` e a torrada diz «N mudanças esperando o Aplicar».
- **O que a ideia «cada controle aplica ao soltar» pede**, para a QA-2 decidir com isso na mão:
  - **(a)** Um mapa chave → etapa(s) e um verbo de uma etapa só no instalador (ou no doctor, que
    já tem `chk_`/`fix_` por nome em `bin/meow:1923`). É o caminho que faz o soltar valer em
    segundos. Ele conflita com a regra do cabeçalho do `install.sh` citada acima.
  - **(b)** O instalador inteiro a cada soltar: minutos por gesto, e um trabalho por vez
    (`app.js:838`, «Espere o trabalho terminar»). Não serve.
  - Em qualquer dos dois: o «Trazer ajustes» precisa mudar junto, para aplicar direto e deixar o
    desfazer na barra. E o `/api/salvar` precisa da mesma barreira de ponte do `rodar`.
- **Tamanho.** G, se for (a). Cabe à QA-2.

## Q3-08 · README: para quem chega pelo GitHub, ele descreve outro programa

- **Visto** (lendo `README.md` como quem abre o repositório pela primeira vez):
  - **Versão errada.** O selo diz `v1.2.4` (`README.md:14`). A publicada é `v2.1.0` (tag). O
    `README.en.md` está igual.
  - **Painel errado.**
    - O texto descreve o painel antigo: a página «Início» (`:69`); «122 ajustes e 67 ações em
      catorze páginas» (`:83`); as abas «Modo de leitura» e «Áreas de trabalho» (`:88`, `:99`); o
      botão «Salvar e aplicar» (`:116`).
    - O painel de hoje tem quatro portas (Tema, Criar tema, Ajustes, Cuidar) e logo vai ter os
      nomes novos (Personalizar, Definir, Manter).
  - **Capturas antigas.** As de `docs/capturas/` (`painel.png`, `painel-leitura.png`,
    `painel-areas.png`, `painel-forma.png`) mostram o painel antigo.
  - **Clone.** Ele aponta para `github.com/AndreBFarias/MeowSystem` (`:40`). É a decisão 22, mas
    o `fork/master` está 5 commits atrás do `dev`, e o `origin` ([REDACTED]) está 1022 atrás
    (último push em 28/09).
  - **Autoria.** Ninguém é nomeado como autor; o `LICENSE` é o GPL-3.0 sem titular.
- **Estrutura proposta** (uma tela antes da primeira rolagem; o resto em `docs/`):
  1. Nome, uma frase do que faz, os selos (versão lida da tag, plataforma, licença).
  2. Uma captura grande do painel de hoje, e uma do desktop vestido.
  3. **Instalar**: três linhas (clone do repositório que ela escolher, `./install.sh`, a senha
     uma vez só), e o que ele baixa.
  4. **O painel em quatro portas**: uma linha por porta, com uma captura pequena cada.
  5. **Packs**: o que é um pack, e o link para `docs/PACKS.md`.
  6. **Extensões** (quando existir): os applets e os repositórios `meowsystem-*`.
  7. **Manter**: o doctor, o «Conferir», o desinstalar.
  8. **Autores**: Vitória Maria (autora) e André Farias (coautor), com links. Depois,
     «Créditos» → `docs/CREDITOS.md`.
  9. Licença.
  - Fora do README: a lista de 122 ajustes, os detalhes de cada aba e o histórico (já moram em
    `docs/`).
- **Cura na origem.**
  - O número de versão sai da tag: o `scripts/higiene.sh` já corrige números que os testes
    sabem, e pode carimbar o selo.
  - As capturas vêm de um script headless sobre a casa de brinquedo (o mesmo do
    `tests/app-completo.py`). Assim elas não envelhecem à mão.
- **Prova.**
  - `tests/decisoes.sh` (ou um teste novo, `tests/readme.sh`) exige que o selo do README seja
    igual a `git describe --tags --abbrev=0`.
  - Exige que nenhuma palavra do painel antigo («Início», «Salvar e aplicar», «Modo de leitura»
    como aba) apareça.
  - Exige que toda imagem citada exista.
- **Tamanho.** M.
- **Fotos.** Nenhuma nova (as velhas estão em `docs/capturas/`).

## Q3-09 · O «…»: o item «Créditos» não tem créditos, e ninguém é coautor

- **Visto** (código; o «…» foi aberto no teste, ver Q3-05):
  - `app.js:1158-1166` monta o menu com só dois itens:
    - **«Créditos»**: um link externo (`target=_blank`) para `ESQUEMA.repositorio`, que é a URL do
      `origin` (`servidor.py`, `_repositorio_no_ar`), ou seja, a página do GitHub;
    - «Esta tela num arquivo».
  - Clicar «Créditos» abre o GitHub, não os créditos. Sem `origin` (um zip, um clone sem remoto),
    o item some.
  - Hoje o `origin` é `[REDACTED]/MeowSystem`, 1022 commits atrás. Quem clica cai num README
    de setembro.
  - `docs/CREDITOS.md` (136 linhas) lista os terceiros e «O que é deste projeto», mas não nomeia
    autora nem coautor.
- **O fork do André.**
  - `git log master..andre --oneline | wc -l` = **0**. O branch local `andre` (`427625c9`,
    16/09) está 990 commits atrás do `master` e não traz nada.
  - O `fork/master` (AndreBFarias/MeowSystem) tem 0 commits à frente do `master` local e 5 atrás.
  - O `fork/dev` tem 1 à frente: é o `16927be8`, o mesmo `HEAD` do `dev` daqui.
  - O `fork/theme-packs` tem 0 à frente.
  - **Conclusão:** o fork não traz código novo. Ele já É este histórico (autores no `master`:
    AndreBFarias 1022 commits, [REDACTED] 159, «[REDACTED]» 21).
  - O que falta é: o `origin` receber o histórico; e o README e os créditos nomearem os dois.
- **Cura na origem.**
  1. «Créditos» vira uma janela do próprio painel (o mesmo `<dialog>` da casa), lida de
     `docs/CREDITOS.md` por um `GET /api/creditos`:
     - em cima, **Autores**: Vitória Maria (autora), André Farias (coautor);
     - depois, os terceiros por grupo (paleta, ícones, fontes, sons, applets de origem);
     - embaixo, um link «Repositório».
     - Funciona sem `origin` e sem rede.
  2. `docs/CREDITOS.md` ganha a seção «Autores» no topo.
  3. `LICENSE` ganha a linha `Copyright (C) 2026 Vitória Maria, André Farias`. **Precisa dela.**
  4. Os commits de coautoria seguem a regra do repositório; não reescrever histórico.
- **Prova.** Em `tests/app-completo.py`, numa casa sem `origin`:
  1. clicar `menu:creditos` abre `#creditos` dentro do painel;
  2. o texto contém os dois nomes;
  3. nenhum `target=_blank` fica no menu, salvo o link «Repositório».
- **Tamanho.** M.
- **Fotos.** `q3-05-menu.png`.

## Q3-10 · Plano da seção «Extensões»

Plano, não código. Os modelos são `scripts/midia_build.sh` (now-playing: pino + patch, carimbo,
`MIDIA_COMPILAR=1`) e `scripts/leitura_build.sh` (`--aplicar`/`--reverter`; instala o binário
antes da sombra e remove a sombra antes do binário; nunca escreve `plugins_wings`/`plugins_center`).
Os repositórios novos já existem em `~/Desenvolvimento/meowsystem-{leitura,now-playing,quick-settings,status-hub}`
(o `meowsystem-performance` ainda está vazio). O `meowsystem-leitura/INTEGRACAO.md` já descreve
a troca da receita local por um clone pinado.

### A página (texto)

- **Lugar.** Uma porta nova, «Extensões», depois de «Definir». Ou uma seção de «Manter». Ela
  decide (ver o fim).
- **Grade de cartões**, um por applet, no mesmo molde do `.cartao-acao` já com o Q3-03: desenho
  à esquerda; à direita, o nome, a pastilha de estado e os botões.
  - **Pastilha:** «Na barra» · «Instalada, fora da barra» · «Não instalada» · «Atualização» ·
    «Falhou» (com o registro).
  - **Botões:** Instalar | Atualizar | Remover. Só aparece o que vale no estado.
  - **Dica** (hover): repositório, commit pinado e data.
  - Sem parágrafo; a interface mostra, não explica.
- **Último cartão: «+ Adicionar»**. Abre um `<dialog>` com um campo de URL e um botão «Ler»:
  1. o painel lê o manifesto do repositório e mostra nome, desenho, o que substitui e o selo
     «baixa e compila»;
  2. só então aparece «Instalar».
- **Conflito com um applet que o COSMIC já tem** (o manifesto declara `substitui`): vira uma
  pendência com dois botões, «Trocar» e «Manter», no mesmo molde da pendência de tema de
  terceiro (`ESCOLHA_TEMA_DE_TERCEIRO`).
  - Nunca se troca sozinho. Escolher juntos é o pedido dela.

### Onde mora o estado

| o quê | onde | quem escreve |
|---|---|---|
| quais extensões ela quer | `meow.conf`, chave nova `EXTENSOES="now-playing leitura …"` (lista) | o painel, por `/api/definir`; o conf é a verdade das etapas |
| o catálogo de fábrica | `assets/extensoes/catalogo.tsv` (id, URL `https://github.com/[REDACTED]/meowsystem-<id>`, commit pinado) | o repositório |
| as que ela adicionou | `~/.config/meowsystem/extensoes.tsv` (id, URL, commit pinado, `origem=usuario`) | o servidor, no «Adicionar» |
| o manifesto | `meowsystem-extensao.json` na raiz de cada repo: `id`, `app_id` (`io.github.meowsystem.*`), `binario`, `build` (`cargo build --release --locked`), `desktop` (`data/*.desktop.in`), `substitui` (lista de app ids) | o repositório da extensão |
| fonte, alvo e carimbo | `$MEOW_ESTADO/extensoes/<id>/{src,target,carimbo}` | a etapa |
| o binário e a sombra | `~/.local/bin/<binario>`, `~/.local/share/applications/<app_id>.desktop` | a etapa |

O carimbo é o do `midia_build.sh`: commit, sha do binário, `rustc` e `libcosmic`. É ele que
deixa a segunda passada sem `cargo`.

### A API do servidor

- `GET /api/extensoes` devolve, por extensão:
  - catálogo e adicionadas, cada uma com `id`, `nome`, `estado`;
  - `na_barra` (lido de `plugins_wings`/`plugins_center`, só leitura);
  - `commit`, `commit_remoto` (cache de 6 h, para não ir à rede a cada render), `origem`, `erro`.
- Ações novas no `ACOES`, por `/api/rodar` com `argumento=<id>`:
  - `extensao_instalar` (`rede: True`, `escreve: True`, sem `sudo`);
  - `extensao_atualizar` (idem);
  - `extensao_remover` (`destrutivo: True`, com `restauro`).
  - Elas rodam `scripts/extensoes.sh {aplicar|atualizar|remover} <id>`.
- `POST /api/extensao-adicionar {url}`:
  1. aceita só `https://` de host público (sem `file:`, sem `ssh`, sem caminho local);
  2. roda `git ls-remote` e pina o SHA de HEAD;
  3. faz um clone raso num rascunho;
  4. lê e valida o manifesto: `app_id` sem `/`; `binario` só nome; `build` de uma lista fechada
     (`cargo build --release --locked`);
  5. devolve a ficha.
  - **Não compila.** O «Instalar» da ficha é que grava a linha no `extensoes.tsv`, liga a chave e
    roda `extensao_instalar`.
- `POST /api/extensao-esquecer {id}`: só para as de `origem=usuario`. Remove primeiro, depois
  tira a linha.

### A etapa e o doctor

- **`scripts/extensoes.sh`** substitui `scripts/midia_build.sh` e `scripts/leitura_build.sh`:
  uma receita para todas, lida do manifesto.
  - **Migração:**
    - `MIDIA="sim"` (`meow.conf.exemplo:973`) e `LEITURA_APPLET="sim"` (`:1489`) viram
      `EXTENSOES="now-playing leitura"`;
    - as chaves velhas ficam lidas por uma versão;
    - o binário e o estado antigos (`~/.local/bin/meow-applet-*`,
      `$MEOW_ESTADO/{midia,leitura}`) saem quando o novo estiver no ar.
  - No `install.sh`, `etapa_extensoes` toma o lugar de `etapa_midia_build` (`:2725`) e de
    `etapa_leitura_applet` (`:2759`).
- **Idempotência**, no molde da regra 5:
  1. O carimbo bate e o binário existe: sai 0 sem rede e sem `cargo`.
  2. Clone e compilação só em `$MEOW_ESTADO/extensoes/<id>`.
  3. O binário vai por `install -m755` para um temporário no `~/.local/bin` e `mv`. A sombra vai
     por `meow_escrever`, que compara antes.
  4. A ordem é a do `leitura_build.sh`: instalar = binário e depois a sombra; remover = sombra e
     depois o binário.
  5. **Fail-safe** (o do `midia.sh`): sombra sem binário → tira a sombra, para não deixar um
     applet quebrado na barra.
- **Doctor:**
  - `chk_extensoes` faz o seco (carimbo contra a lista do conf);
  - `fix_extensoes` compila o que falta. Ele entra fora do `VERIFICAVEIS` rápido, como o
    `midiabin` saiu na P76 (`bin/meow:1941`): compilar é longo, e vai ao fundo como o
    `garantir_builds.sh --fundo`.
- **Nunca:**
  - escrever `plugins_wings`/`plugins_center` (são da Aurora e do COSMIC); a página mostra «fora
    da barra» e ela põe pelo COSMIC;
  - escrever em `/usr`;
  - usar `sudo`;
  - instalar extensão de usuário sem gesto (repo de usuário = código arbitrário que compila na
    máquina dela; mesma lógica da decisão 9).
- **O commit pinado** só muda pelo «Atualizar» (gesto). O doctor nunca puxa um HEAD novo; ele
  repõe o pinado.

### Prova (para quando for executado)

- `tests/extensoes.sh` com uma receita falsa (um `build` que só copia um script), como o
  `GB_COMPOSITOR` do `garantir_builds.sh`. Ele exige:
  1. a segunda passada não chama o build e sai 0;
  2. remover tira a sombra antes do binário;
  3. URL `file://`, `ssh://` ou caminho local é recusada;
  4. manifesto com `binario: "../x"` é recusado;
  5. nenhum arquivo de `plugins_*` muda.
- `tests/convergencia.sh` com `EXTENSOES` ligada: duas passadas, a segunda com 0 escrita.
- **Tamanho.** G (três blocos: etapa e migração; API e página; «Adicionar»).

---

## Menores, de uma linha

- `tests/app-completo.py`, `copiar_raiz`: quebra neste checkout (`IsADirectoryError` em
  `assets/icones/upstream/papirus-folders/`, um repositório aninhado não rastreado que o
  `git ls-files --others` lista). Precisei contornar no meu script.
- Os testes de navegador não acham o Chromium do Playwright nesta máquina (não há
  `~/.cache/ms-playwright`). Rodei com `executable_path=/usr/bin/google-chrome`, headless.
- «Mais ajustes» do Cuidar guarda só o «Restaurar». Com a decisão de 26/10 («Mais ajustes» sai),
  o «Restaurar» precisa de outro lugar; o natural é o resultado de cada ação, que já tem
  «Restaurar».
- `scripts/temas-de-apps/btop-bat/manifesto.sh:397`: o mesmo «temporário no destino, compara
  depois» do Q3-02 (fora do seco), fora do hicolor; só muda data de pasta.

## Conflita com decisão registrada

- **Decisão 11** (`docs/sprints/2026-10-09-uso-real/02-decisoes.md:19`, P98/P104): nomeia o
  «Conferir e consertar» como o caminho sem senha que repõe a ponte. O pedido de 26/10 tira o
  botão do topo. O Q3-04 mantém o caminho (resultado do «Conferir», caixa «Falta a ponte»,
  pendências). Se ela quiser a ação fora de **todo** lugar, a decisão 11 precisa de um sim
  explícito.
- **Decisão 18** (`02-decisoes.md:26`): «Só Executar e Restaurar; o resultado abre numa janela…».
  O «cada controle aplica ao soltar» (Q3-07) troca a janela de resultado, para os ajustes, por
  aplicação silenciosa com desfazer. Isso é decisão nova, e não está escrita.
- **Decisão 22** (`02-decisoes.md:30`): «O dev vai para o master do fork AndreBFarias/MeowSystem,
  e o README aponta para lá». O pedido de agora (fundir o fork, André coautor, applets em
  `[REDACTED]/…`) sugere que o repositório da casa é o `[REDACTED]/MeowSystem`. O clone
  do README e o «Créditos» seguem a 22 até ela dizer outra coisa.
- **Decisão 9** (`02-decisoes.md:17`): pack de terceiro não instala extensão do VS Code porque
  integridade não é confiança. O «Adicionar» de applet de terceiro (Q3-10) é o mesmo risco em
  maior grau, porque compila e roda na sessão. O plano respeita isso (só por gesto, SHA pinado,
  sem `sudo`), mas abrir a porta é uma decisão dela.
- **P82, decisão 7** (doctor que baixa declara `rede: True`, sem pergunta): vale para as
  extensões de fábrica. Para as adicionadas por ela, o plano pede gesto. Isso é uma exceção, e
  precisa ficar escrita.

## Precisa da usuária decidir

1. **Extensões: porta própria ou seção do «Manter»?** Uma porta a mais no topo, ou um bloco
   dentro de Manter.
2. **Adicionar applet de qualquer repositório, ou só de `github.com/[REDACTED]/meowsystem-*`?**
   Abrir para qualquer URL é código arbitrário compilando na máquina dela.
3. **Repositório da casa:** o README e o «Créditos» apontam para `[REDACTED]/MeowSystem` ou
   para `AndreBFarias/MeowSystem` (decisão 22)? E quem empurra os 1022 commits para o `origin`?
4. **`LICENSE` com titulares** «Vitória Maria, André Farias»? E com qual nome dela (o de commit
   é «[REDACTED]»)?
5. **«Cada controle aplica ao soltar»:** aceita que isso exige rodar uma etapa por vez (Q3-07 a),
   contra a regra do `install.sh` de não escolher etapa pela linha de comando?

# QA 1: abas Tema e Criar tema (vira «Personalizar»)

Data: 26/10/2026. Painel rodado só na casa de brinquedo (`tests/app-completo.py` via importlib,
HOME temporário, PID próprio), Chrome headless, viewports 1920x1080, 1550x860 e 1280x800 (e
1248x862, a largura da janela dela em 10.png). O HOME real foi só lido, nunca escrito.
Fotos: `relatorios/fotos/qa-1/`. Scripts de prova: no scratchpad da sessão (`qa-1/t*.py`).

Estado da casa: packs `meowsystem` (no ar, mocha/mauve, escuro) e `dracula`. Sem ponte.

Leitura rápida, do mais grave ao menos grave:

| id | o quê | tamanho |
|---|---|---|
| Q1-01 | o desenho mais recente da oficina nunca chega ao tema de ícones (mapa sem `\n` final) | P |
| Q1-02 | «Usar» grava o desenho na máquina, não no pack que está sendo criado | M |
| Q1-03 | três sinos diferentes: o da prévia, o do controle e o gravado | M |
| Q1-04 | o sino e os sons não são do pack: o `SOM_*` é global e vence o pack | M |
| Q1-05 | Dracula aparece no MeowSystem (seletor, «Do tema» pré-escolhido, Sistema, Biblioteca) | M |
| Q1-06 | Sistema: pastas do Dracula, cinza fixo, nome técnico | M |
| Q1-07 | Biblioteca: 477 do Dracula + 36 do MeowSystem misturados | P |
| Q1-08 | não existe gerador no estilo Dracula (base `circle`) | G |
| Q1-09 | «Mais ajustes» de Ícones: dez linhas que não são de quem cria tema | M |
| Q1-10 | layout da ficha de ícone e da oficina: caixa dentro de caixa, dois «Usar» | M |
| Q1-11 | Tema: «Ver», «No ar agora» e «Mais ajustes» ainda estão; «Criar o meu» | P |
| Q1-12 | renomes: onde mora cada texto | M |
| Q1-13 | Mandar vazia antes de guardar, e o pack sai sem sons nem desenhos | P |
| Q1-14 | controles do Personalizar ficam pendentes na barra (contraria «grava ao soltar») | M |
| Q1-15 | selects da aba Tema abrem com valor falso («Latte mauve», «Claro») | P |
| Q1-16 | «Temas prontos › Ver» manda digitar `meow tema <nome>` | P |
| Q1-17 | o nome do tema perde a forma («QA Um» vira «Qa um») | P |
| Q1-18 | rascunho do Personalizar mora só no `localStorage` do navegador | P |
| Q1-19 | outras gravações de mapa sem `\n` final (mesma família de Q1-01) | P |
| Q1-20 | `tests/app-completo.py` quebra com repositório aninhado não rastreado | P |

---

## Q1-01 O desenho mais recente da oficina nunca chega ao ícone instalado

- **Passos:** Criar tema › Ícones › Aplicativos › Firefox › Gerar ícone › cartão «Fiel» › «Usar».
- **Visto (casa):** a janela diz «Desenhos em traço · Mexeu e aplicou · 9.6s».
  `convertidos-apps/firefox.svg` existe e é idêntico ao escolhido, mas
  `MeowSystem-Icons/48x48/apps/firefox.svg` recebeu o glifo do Arcticons do mapa do projeto
  (md5 `cfae4cfc`, `path` do glifo `firefox`), não o desenho. O mapa
  `~/.config/meow/icones-convertidos.map` termina em
  `firefox:/usr/share/icons/hicolor/scalable/apps/firefox.svg:peach:--k 8 --funde 52 --tol 1`
  **sem `\n`**. Depois de só acrescentar `\n` ao arquivo e rodar `icones_traco` de novo, o
  `48x48/apps/firefox.svg` passou a ser o desenho (`<g ... stroke="#FAB387"><path
  stroke-width="1.25" d="M31.07 0.19 ...`), «1 posto(s)».
- **Visto (HOME real, só leitura):** o mesmo mapa termina em
  `com.cherry_ai.CherryStudio:mao:maroon` sem `\n` (`cat -A`); o `.svg` do Cherry Studio está em
  `convertidos-apps/`, e nenhum arquivo `*cherry*` existe em `MeowSystem-Icons`. As três linhas
  anteriores do mapa estão instaladas. É exatamente a queixa 4 (10.png é o Cherry Studio).
- **Esperado:** «Usar» → o ícone do dock e do lançador muda.
- **Causa:** `app/servidor.py:9471` grava `fh.write("\n".join(linhas))`, sem quebra final.
  `scripts/icones_apps_arcticons.sh:196` (`while IFS= read -r linha`) descarta a última linha
  sem `\n`; `scripts/icones_apps_arcticons.sh:224` (`_ceder_ao_pack`, `while IFS=':' read`) a
  perde do mesmo jeito. Sempre o último desenho salvo some.
- **Cura na origem:** (1) `servidor.py:9471` escreve `"\n".join(linhas) + "\n"`; (2) os
  laços do shell aceitam última linha sem `\n` (`|| [ -n "$linha" ]`), porque o arquivo é de
  quem usa e pode ter sido editado à mão.
- **Prova:** teste de casa: grava dois desenhos pela API `/api/app-desenho` (`acao: salvar`),
  roda `icones_traco`, assere que `48x48/apps/<os dois>.svg` têm `cmp` igual a
  `convertidos-apps/<os dois>.svg` com a cor aplicada; e teste de shell que roda o script com
  um mapa sem `\n` final.
- **Risco a medir depois:** se um app tiver também `scalable/apps/<nome>.svg` no tema (na casa,
  o Firefox tem), o traço em `48x48` (Fixed) perde em todo tamanho ≠ 48 (`scalable` 8–512
  casa exato). No HOME real hoje não há interseção, então não é a causa da queixa.
  `servidor.py:7525` (`TAMANHOS` começa por `scalable`) faz o painel dizer que está «na tela» o
  `scalable`, enquanto o dock a 48 mostra o `48x48`.
- **Tamanho:** P. **Fotos:** `usar-firefox-janela.png`, `oficina-1550.png`.

## Q1-02 «Usar» grava o desenho na máquina, não no tema que está sendo criado

- **Passos:** guardar «QA Um» em Cores; Ícones › Firefox › Gerar › «Usar»; Mandar ›
  `GET /api/pack-exportar?id=qa-um&medir=1`.
- **Visto:** o pack `qa-um` tem 22 arquivos: `pack.json`, `paleta.json`, logo e 16 autorais
  `cosmic-*`. Nada de `firefox`. O desenho foi para `~/.local/share/meowsystem/convertidos-apps/`
  e para `~/.config/meow/icones-convertidos.map`, que valem para qualquer tema.
- **Esperado:** no Personalizar, o que ela desenha é do tema e vai no `.meowpack`.
- **Causa:** `servidor.py:9098` `_api_app_desenho` (salvar, ~9374) usa
  `_oficina_do_usuario("convertidos-apps")` e `_gravar_linha_convertidos` (9428): o destino é
  sempre a oficina da pessoa; o pack do rascunho nem é enviado (`oficina.js:390-400` manda só
  `app`, `acao`, `svg`).
- **Cura na origem:** a oficina, aberta dentro do Personalizar, salva em
  `<pack>/icones/apps/<nome>.svg` com linha no `apps.map` do pack (o mesmo caminho do
  `_escolher_do_pack`) e roda `icones_pack`. A oficina de máquina (fora do pack) fica para
  Definir, se ela quiser manter.
- **Prova:** Playwright: guardar pack, «Usar» num app, assere que `pack-exportar` lista
  `icones/apps/<nome>.svg` e que o arquivo instalado mudou.
- **Tamanho:** M. **Precisa dela decidir:** ver o fim.

## Q1-03 Três sinos diferentes

- **Passos:** Sons (conf sem `SOM_*`, pack `meowsystem`) › tocar o sino; mexer «Primeira nota»;
  tocar; «Regravar».
- **Visto:** prévia do navegador: 784 Hz + 1176 Hz, 1,5 s, ganho 0,232/0,128 (instrumentado no
  `AudioContext`). O controle «Primeira nota» mostra «Auto» encostado no mínimo (60) e, mexido,
  90; a prévia passa a tocar 90 Hz. «Regravar» rodou `som_aplicar` e o `.oga` gravado
  (decodificado) tem **880 Hz + 1320 Hz, 0,085 s**: o 90 da tela foi ignorado, e o conf ficou
  `SOM_FUNDAMENTAL=''`.
- **Esperado:** o que toca no navegador é o que vai tocar no volume; mexer e regravar dá o
  mesmo som.
- **Causa:** `paginas.js:326-343` `tocarSino`: padrão 784/1176 (o som.sh usa 880/1320,
  `scripts/som.sh` nos padrões), duração `60/d` limitada a 0,15–2,5 s (o WAV real tem
  `SOM_DURACAO=0.085` fixo, `som.sh:36`), ganho `p*0.4` (real `SOM_GANHO=0.18`, `som.sh:40`).
  O controle está pendente na barra (Q1-14) e o «Regravar» lê o `meow.conf`, onde a mudança
  ainda não está. «Duração» (`lugares.js:90`) mexe em `SOM_DECAIMENTO`, que não muda a duração
  do arquivo de 85 ms.
- **Cura na origem:** uma fonte só: a prévia pede o WAV ao servidor (`som.sh gerar` num
  temporário com os valores da tela) ou o JS usa as mesmas constantes e fórmula do gerador;
  os valores vazios mostram o valor real do pack, não «Auto» no mínimo.
- **Prova:** Playwright mede o `AudioContext` (frequências, duração) e compara com o `.oga`
  decodificado depois de «Regravar»; os dois têm de bater.
- **Tamanho:** M. **Fotos:** `sons-guardado.png`, `sons-regravar.png`.

## Q1-04 O sino e os sons de aviso não são do pack

- **Visto:** o pack salvo `qa-um` não tem `som` no `pack.json` nem pasta `sons/`
  (`/api/criar?id=qa-um` → `sons: 0`). `packs/meowsystem/pack.json` não tem `som` nem `sons/`;
  só o Dracula tem (784/932,3/0,58/0,32/38 e 25 efeitos Kenney). «Sons de aviso» só aparecem
  depois de guardar, e com base MeowSystem a lista fica vazia.
- **Causa:** os controles do passo Sons são chaves `SOM_*` do `meow.conf`
  (`lugares.js:85-97`); `som.sh:50-66` `_som_do_pack` só preenche o que o conf não define, então
  o conf global vence qualquer pack. O conf real dela tem `SOM_FUNDAMENTAL=666`,
  `SOM_HARMONICO=6646`, `SOM_DECAIMENTO=44`: trocar de pack não troca o sino.
- **O que o COSMIC toca de fato (Pop!_OS 24.04, cosmic 1.11, lido nos binários):**

  | som | quem toca | quando | dá para o pack trocar? |
  |---|---|---|---|
  | `freedesktop/stereo/audio-volume-change.oga` | `cosmic-osd` (`pw-play --media-role Notification`, procura em `XDG_DATA_HOME` primeiro) | tecla de volume | sim: já é o que o `som.sh` faz em `~/.local/share/sounds/freedesktop/` |
  | `power-plug`, `power-unplug`, `power-unplug-battery-low`, `battery-caution`, `battery-low`, `dialog-warning`, `complete` | `cosmic-settings-daemon` (strings: `/usr/share/sounds/Pop`, `freedesktop`, `pw-play`) | ligar/tirar o carregador, bateria baixa | provável que não pelo HOME: o caminho `/usr/share/sounds/Pop` é cravado no binário. Confirmar com o mesmo teste de `/proc/*/cmdline` do `som.sh` |
  | notificação (`message-new-instant`) | ninguém no COSMIC; o `meow-som.service` (`som.sh vigiar`, `dbus-monitor` em `Notify`) toca `MeowSystem-Sons/stereo/notification/message-new-instant.oga` | cada notificação | sim, já é do pack (`som.tema`) |
  | o resto do tema Pop (`bell`, `camera-shutter`, `screen-capture`, `device-added/removed`, `desktop-screen-lock`, `system-ready/shutdown`, `alarm-clock-elapsed`, `software-update-urgent`, `message-new-email`, `window-attention-inactive`) e do freedesktop (36) | nenhum programa do COSMIC encontrado os toca; o tema do sistema é `freedesktop` (`gsettings`), usado só por apps GTK com libcanberra | apps GTK | só via `index.theme` de um tema de som do usuário e `gsettings sound theme-name`, que o `som.sh` evita de propósito |

  Upstream: o COSMIC Epoch 1.4 trouxe um tema de som próprio, `cosmic-sound-theme`, em
  `/usr/share/sounds/COSMIC/stereo/{action,alert,notification}` (CC-BY-SA-4.0); esta máquina
  ainda tem só `Pop` e `freedesktop`. Quando o pacote chegar, a tabela muda.
- **Cura na origem:** `som` passa a ser do pack: o passo Sons grava no `pack.json` do pack do
  rascunho (`som.fundamental`… e `sons/`) e o `som.sh` lê o pack no ar antes do conf (o conf
  vira só a sobra de quem não usa pack). O pack base MeowSystem ganha seu `som` e `sons/`, ou
  a tela diz qual pack os empresta.
- **Prova:** teste: guardar dois packs com sinos diferentes, vestir um, `.oga` A; vestir o
  outro, `.oga` B (frequências medidas). Teste de `tests/decisoes.sh` para «som é do pack».
- **Tamanho:** M. **Conflito:** ver o fim (conf global contra decisão nova).

## Q1-05 Dracula aparece no MeowSystem

- **Passos:** MeowSystem no ar; Ícones › Aplicativos › Firefox.
- **Visto:** o seletor mostra 11 pastas: 6 do MeowSystem e 5 do Dracula («Dracula · feitos para
  apps» 121, «Dracula · biblioteca» 477, «… (PNG)» 2, autorais alucard e dracula). Na oficina, o
  cartão «Do tema» é o lobo do Dracula, e ele vem **pré-escolhido** (`OFICINA.escolhida =
  "pack:dracula"`), com «Usar» desligado.
- **Causa:** `scripts/pack.py:3663` `acervos_de_icone` varre todos os packs de `raizes()`;
  `servidor.py:8416` `_acervo_da_ficha` usa isso; `servidor.py:7340` `_desenhos_de_pack` lista
  «todo pack no disco» para os cartões; `oficina.js:359` escolhe o primeiro desenho de pack
  como inicial, de qualquer pack.
- **Cura na origem:** filtrar pelo pack no ar (ou pelo pack do rascunho e sua `heranca`) nas
  três funções; o inicial da oficina é o salvo ou o «Fiel».
- **Prova:** Playwright com MeowSystem no ar: nenhuma pasta com «Dracula»; cartão «Do tema»
  ausente ou do MeowSystem; o inverso com Dracula no ar.
- **Tamanho:** M. **Conflito:** GSD decisão 3 («o seletor mostra o acervo de todos os
  packs, o pack no ar primeiro»). **Fotos:** `icone-escolha-{1280,1550,1920}.png`,
  `oficina-*.png`.

## Q1-06 Aba Sistema: pastas do Dracula, cinza escuro, nome técnico

- **Visto:** 10 itens, todos `packs/dracula/icones/sistema/*.svg` (`folder-documents`… com
  `fill="#383a4c"` e `#44475a`, cores fixas do Dracula) num tema de base MeowSystem/mocha.
  Rótulos: `folder-docume...`, `folder-publics...`, `user-home`. Antes de guardar, todos
  desligados com dica «Guarde o tema em Cores» (11.png).
- **Causa:** `pack.py:6064` `acervo_para_levar` oferece «o que os outros packs trazem», e o
  único com `icones.pastas` é o Dracula (`pack.py:6033` `_pastas_desenhadas`); o rótulo é
  `i.nome` (`paginas.js:398`); a trava é `paginas.js:390`.
- **Cura na origem:** pastas do Sistema pintadas na paleta do rascunho (o molde que já pinta
  tipos de arquivo), com nome de gente («Documentos», o `aria-label` que o SVG já traz); levar
  sem precisar guardar antes (guardar sozinho na primeira ação, como a decisão nova de gravar
  ao soltar pede).
- **Prova:** Playwright: rótulos sem `-`; cor dominante de cada pasta = acento do rascunho.
- **Tamanho:** M. **Fotos:** `criar-icones-sistema-1550-cheia.png`,
  `criar-icones-sistema-guardado.png`.

## Q1-07 Aba Biblioteca: estilos misturados

- **Visto:** 513 itens: 477 do Dracula (`005-potion.svg`…, coloridos) + 36 do MeowSystem
  (`whatsapp.svg`…, traço), na mesma grade, nomes técnicos (12.png).
- **Causa:** `pack.py:6064` `acervo_para_levar` (mesma de Q1-06); `paginas.js:398`.
- **Cura:** biblioteca do estilo do pack no ar/rascunho; os outros, se ficarem, num grupo
  separado e fechado.
- **Prova:** Playwright: com MeowSystem, nenhum item com `src` em `packs/dracula/`.
- **Tamanho:** P. **Fotos:** `criar-icones-biblioteca-1550-cheia.png`.

## Q1-08 Falta o gerador no estilo Dracula

- **O que existe:** `servidor.py:5337` `PRESETS_DESENHO` (Fiel, Limpo, Silhueta, Detalhe, Área
  cheia, Da capa) — todos convertem o ícone original em **traço** Arcticons (stroke na cor
  escolhida). O cartão «Do tema» só copia um desenho pronto do pack. `oficinaAutoral`
  (`oficina.js:432`) gera os autorais `cosmic-*` por paleta. `scripts/icones_apps_dracula.sh`
  só instala os desenhos prontos do pack em `scalable/apps`.
- **O que falta:** um gerador que produza o estilo Dracula da decisão 1 do GSD (base `circle`
  na frente, `main` atrás): disco de fundo na paleta, glifo cheio por cima, como os 121
  «feitos para apps» do Dracula. Nenhum preset faz preenchimento sobre disco.
- **Cura:** um conjunto de presets por pack, declarado no `pack.json`
  (`icones.gerador: "traco" | "circle"`), com o motor `circle` gerando `<circle>` +
  silhueta cheia recortada; a oficina mostra só os presets do pack do rascunho.
- **Prova:** teste de unidade do conversor (SVG tem `circle` e `path` com `fill`, sem
  `stroke`) e Playwright (com Dracula, cartões do estilo `circle`; com MeowSystem, traço).
- **Tamanho:** G.

## Q1-09 «Mais ajustes» de Ícones (9.png)

- **Visto:** «Variante dos ícones» (pílulas Catppuccin Mocha/Macchiato/Frappé e «Catppuccin
  Latte» sozinha na 2ª linha, nenhuma marcada), «Desenhos do pack» (interruptor), «Ícones
  resgatados», «Cor da marca», «Pastas especiais», «Nome do tema» (`MeowSystem-Icons`),
  «Logo do Hefesto», «Tema de ícones · Trazer .zip», «Tema instalado · Ver», «Reconstruir os
  ícones», «Desenhos em traço · Aplicar/Restaurar», e de novo «Desenhos do pack · Aplicar»
  (rótulo repetido para outra coisa). Sons: só «Peso da primeira/segunda · Auto».
- **Causa:** `lugares.js:56-71` (ícones) e `:94-97` (sons) despejam chaves de manutenção da
  máquina no passo de criar; `maisAjustes` em `paginas.js:426` e `:522`.
- **Cura (decisão nova: «Mais ajustes» some):** no passo Ícones ficam só Aplicativos, Sistema,
  Biblioteca, Pastas (cor). A variante vem do pack (não é escolha no Personalizar). «Trazer
  .zip», «Tema instalado», «Reconstruir», «Desenhos em traço/do pack», «Nome do tema», «Logo do
  Hefesto», «Ícones resgatados» vão para Definir › Ícones ou Manter (o raro no fim). Pesos do
  sino entram na seção Sons, no fim.
- **Prova:** Playwright: `details.mais` não existe em `#criar/*`; `tests/app-acessibilidade.py`
  e o índice de busca (`lugares.js:379-394`, `servidor.py:5938-5980`) acompanham.
- **Tamanho:** M. **Fotos:** `icones-mais-ajustes*.png`, `sons-mais-ajustes*.png`.

## Q1-10 Layout da ficha de ícone e da oficina (10.png)

- **Visto:** grade de apps › ficha do app (caixa com borda) › seletor com rolagem interna ›
  «Usar» › caixa «Gerar ícone» com outro «Usar» no cabeçalho › cartões › tira do dock › lupa +
  4 sliders + 28 cores › «Desfazer» › «Editar o SVG». Três bordas aninhadas e dois «Usar» que
  fazem coisas diferentes. Os cartões quebram em 5+3 (1550), 4+4 (1280), 6+1 em 10.png. A ficha
  abre no meio da grade e empurra os apps seguintes para baixo da oficina (a ficha mede 1313 px
  em 1550). Na casa não houve rolagem horizontal em 1248, 1100, 1024 e 900 px; o corte à
  esquerda em 10.png parece ser recorte da imagem, não estouro.
- **Causa:** `oficina.js:73-179` (`escolhaDeIcone`) e `:243-409` (`oficinaDeDesenho`) montam a
  oficina dentro da ficha dentro da grade.
- **Cura:** a ficha abre como painel próprio (no lugar da prévia ou em diálogo) com duas colunas:
  à esquerda o seletor de desenhos, à direita a oficina; um «Usar» só, no rodapé fixo, que
  aplica o cartão escolhido, seja desenho pronto ou gerado.
- **Prova:** Playwright nas três larguras: um único `[data-controle$="usar"]` visível; nenhum
  `.oficina-desenho` dentro de `.grade-apps`; altura da ficha ≤ altura da janela.
- **Tamanho:** M. **Fotos:** `oficina-{1280,1550,1920}.png`, `icone-escolha-*.png`,
  `largura-1248-oficina.png`.

## Q1-11 Aba Tema

- **Visto:** «Mais ajustes» da aba Tema ainda existe com «Tema pronto», «Modo agora», «Temas
  prontos · Ver», «No ar agora · Ver». «No ar agora» ficou «Rodando» mais de 60 s e mostra
  saída de terminal. O botão diz «Criar o meu». «Aplicar» aparece com zero mudanças.
- **Causa:** `lugares.js:35-40` (`LUGAR_TEMA.mais`), `paginas.js:209` («Criar o meu»),
  `paginas.js:210` (`maisAjustes("tema:tema", …)`); ações `servidor.py:3902` (`status`) e
  `:3977` (`tema`).
- **Cura:** tirar `LUGAR_TEMA.mais` inteiro (os selects já são o cartão do pack); trocar o
  texto para «Criar o meu tema».
- **Prova:** Playwright: `#tema` sem `details.mais`, sem texto «No ar agora»; botão com texto
  exato «Criar o meu tema».
- **Tamanho:** P. **Fotos:** `tema-*.png`, `tema-ver-temas.png`, `tema-ver-no-ar.png`.

## Q1-12 Renomes: onde mora cada texto

| texto | código | testes |
|---|---|---|
| «Criar tema» → «Personalizar» | `lugares.js:17` (`PORTAS`), `app.js:1055`, `standalone.js:134`; comentários `paginas.js:1`, `:429`, `index.html:3`, `estilo.css:386`, `:592`, `pack.py:125`, `:135`, `:5789`, `:5799`, `icones_pastas.sh:64` | `tests/app-navegador.py`, `app-completo.py`, `criar-tema-leva.sh`, `mesmo-horario.sh`, `pack.sh`, `todos.sh` |
| «Ajustes» → «Definir» | `lugares.js:18`, `paginas.js:685` (`aria-label`), `app.js:1055` | idem (28 ocorrências de Cuidar/Criar tema/Ajustes em `tests/`) |
| «Cuidar» → «Manter» | `lugares.js:19`, `:389-394`, `app.js:1054`, `standalone.js:136`, `servidor.py:5953-5965` (índice da busca) | `tests/app.sh:625`, `migracao-do-painel.py:234` |
| «Conferir e consertar» sai | `servidor.py:3892` (rótulo), `lugares.js:303`, `app.js:832` (botão do «Falta a ponte»), `bin/meow:1354` | `app-completo.py:1433-1437`, `app-navegador.py:137`, `app.sh:625`, `migracao-do-painel.py:234`, `ponte-reparo.sh:334` |
| «Criar o meu» → «Criar o meu tema» | `paginas.js:209` | — |
| «Mais ajustes» some | `app.js:747-755`, `lugares.js:379-394`, `servidor.py:5938-5980`, `estilo.css:245` | `app-acessibilidade.py:7` |

O id de rota (`#criar`, `#ajustes`, `#cuidar`) pode ficar; só o texto muda. `docs/*.md`,
`README.md` e `GSD.md` não citam esses nomes. **Sem «Conferir e consertar», o diálogo «Falta a
ponte» (`app.js:832`) fica sem botão:** precisa de outro destino (Q1, fim).

## Q1-13 Mandar

- **Visto:** antes de guardar, um bloco com o nome e «Baixar o tema» e «Vestir» desligados
  («Guarde o tema em Cores»). Depois de guardar, os dois ligam; a medição do export dá 22
  arquivos, 15 KB, sem sons, sem papel, sem os desenhos gerados (Q1-02, Q1-04).
- **Causa:** `paginas.js:524-538` e `lugares.js:98-102`.
- **Cura:** Mandar mostra o que vai no pack (cores, quantos ícones, papel, sons) e guarda
  sozinho se ainda não guardou; os dois botões nunca nascem mortos.
- **Prova:** Playwright: sem guardar, «Baixar o tema» ligado e baixa um `.meowpack` com os
  itens da lista.
- **Tamanho:** P. **Fotos:** `criar-mandar-*.png`, `mandar-guardado.png`.

## Q1-14 Os controles do Personalizar ficam pendentes

- **Visto:** mexer «Primeira nota» põe «1 mudança · Desfazer · Ver sem mudar · Aplicar» na
  barra; o conf não muda até «Aplicar» (`SOM_FUNDAMENTAL=''` depois do controle). Em 13.png,
  «3 mudanças».
- **Causa:** as linhas `c:` de `PASSOS` usam o mesmo fluxo pendente de Definir.
- **Cura:** decisão de 26/10 («cada controle grava ao soltar; a barra fica só para desfazer»):
  `change` grava e aplica; a barra só oferece «Desfazer».
- **Prova:** Playwright: soltar o controle → `meow.conf` (ou `pack.json`, ver Q1-04) muda sem
  clicar «Aplicar».
- **Tamanho:** M (é do painel inteiro; o QA 2 deve ver o mesmo em Definir).

## Q1-15 Selects da aba Tema abrem com valor falso

- **Visto:** sistema em mocha/escuro; «Tema pronto» mostra «Latte mauve», «Modo agora» mostra
  «Claro».
- **Causa:** ações `tema_aplicar`/`tema_modo` (`servidor.py:3988`, `:4001`, `arg: capturas`/
  `modos`) viram select sem valor atual; o navegador mostra a primeira opção.
- **Cura:** some com Q1-11; se ficar, o servidor manda o valor atual.
- **Tamanho:** P.

## Q1-16 «Temas prontos › Ver» manda digitar

- **Visto:** saída «meow tema <nome> aplica · meow tema claro|escuro|auto troca o modo».
- **Causa:** ação `tema` (`servidor.py:3977`) mostra a ajuda da CLI. Viola «nenhuma saída manda
  digitar» (`tests/nada-manda-digitar.sh` não pega porque o texto vem do `bin/meow`).
- **Cura:** some com Q1-11.
- **Tamanho:** P.

## Q1-17 O nome do tema perde a forma

- **Visto:** nome «QA Um» → pack «Qa um» em Mandar e no `pack.json`.
- **Causa:** `paginas.js:273` manda só `nome: id + ".csv"`; o importador refaz o nome a partir
  do id.
- **Cura:** mandar o nome digitado junto, gravado em `pack.json:nome`.
- **Prova:** guardar «QA Um» → `pack.json` `"nome": "QA Um"`.
- **Tamanho:** P.

## Q1-18 O rascunho mora só no navegador

- **Visto:** em outro navegador (contexto novo) o Personalizar volta para «Meu tema» sem pack.
- **Causa:** `paginas.js:226` e `:234` (`localStorage "meow-criar"`).
- **Cura:** rascunho no servidor (`~/.local/state/meowsystem/criar.json`), já que o pack também
  é do servidor.
- **Tamanho:** P.

## Q1-19 Outras gravações de mapa sem `\n` final

`servidor.py:7988` (`MAPA_JOGOS`), `:8206` (`_escolher_do_pack`, `apps.map` do pack), `:8293`
(`_desfazer_do_pack`): mesmo `"\n".join(...)` sem quebra final; os mesmos leitores em shell
perdem a última linha. `_gravar_escolha` (`:1492`) está certo. Mesma cura de Q1-01, um helper
só. Prova: teste que grava cada mapa e confere `tail -c1` = `\n`. **P.**

## Q1-20 `tests/app-completo.py` quebra com repositório aninhado

`copiar_raiz` (`tests/app-completo.py:160`, `shutil.copy2`) dá `IsADirectoryError` em
`assets/icones/upstream/papirus-folders/` (repositório git não rastreado: `git ls-files
--others` lista a pasta). Isso derruba toda a suíte de navegador nesta árvore. Cura: copiar
pasta com `copytree` (ou `--exclude-standard` + pular diretórios). **P.**

---

## Conflita com decisão registrada

1. **GSD decisão 3** («o seletor mostra o acervo de todos os packs, o pack no ar primeiro»,
   guardada por `tests/decisoes.sh`) contra a queixa 2 («Dracula não aparece no MeowSystem»).
   Q1-05, Q1-06 e Q1-07 só se curam desfazendo a decisão 3.
2. **`SOM_*` no `meow.conf` vence o pack** (`som.sh:50-66`, desenho deliberado de 17/09) contra
   «sons separados por pack» (decisão de 26/10). Q1-04.
3. **Oficina grava na máquina** (`convertidos-apps`, dono único do `48x48/apps`, GSD) contra
   «o que se faz no Personalizar vai no tema». Q1-02.

## Precisa da usuária decidir

1. Decisão 3 do GSD: desfazer (cada pack só vê o seu) ou manter os outros packs num grupo
   fechado no fim?
2. A oficina dentro do Personalizar grava no pack (vai no `.meowpack`) e a de fora vai para
   Definir? Ou só existe a do pack?
3. O MeowSystem ganha sino e sons próprios (hoje não tem `som` nem `sons/`), ou empresta do
   Dracula?
4. Sem «Conferir e consertar», o que o diálogo «Falta a ponte» oferece?
5. Onde moram os itens de Q1-09 que saem do Personalizar: Definir › Ícones ou Manter?
6. Os sons do carregador e da bateria (`cosmic-settings-daemon`, caminho `/usr/share/sounds/Pop`
   cravado) parecem não trocar pelo HOME; trocar exige escrever em `/usr` (root). Vale a pena?

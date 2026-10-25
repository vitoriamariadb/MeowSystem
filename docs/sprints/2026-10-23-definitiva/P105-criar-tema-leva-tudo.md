# P105 — O Criar tema leva papéis e sons para o pack, e o mockup ganha motor

**Status: REGISTRADA em 24/10; entra depois da P102 (o formato de foto no pack sai dela) e da P104.**
Vem da P98, «ficou de fora» 3 e 4. O desenho de referência é o mockup final da P97:
`docs/design/2026-10-23/final/` (`criar-papel.html`, `criar-sons.html`, `criar-icones.html`,
`ajustes-dia-e-noite.html`).

Cada item: teste vermelho antes, verde depois, um commit por item. QA do painel só com HOME temporário
(decisão 8). Interface sem texto explicativo (GSD §2). Trabalho visual passa pela skill `hallmark`.

## 1. Papéis de parede do Criar tema vão para dentro do pack
- Medido (P98): o passo Papel de parede do Criar tema usa as fotos da máquina, e o «Mandar» (`pack.py novo`)
  não as grava no pack.
- Cura: as fotos escolhidas no passo vão para `packs/<novo>/wallpapers/`, no formato que a P102 criou (leia a
  seção «Execução» da P102). Vestir esse pack põe essas fotos na rotação, sem rede.
- Prova: criar um pack no HOME temporário com 2 fotos, vestir, e as 2 aparecem na rotação.

## 2. Sons do Criar tema vão para dentro do pack
- Medido: o pack já tem o bloco `som` (`packs/dracula/pack.json`, `"tema": "sons/"`), mas o «Mandar» não grava
  os sons escolhidos no passo.
- Cura: os sons escolhidos vão para `packs/<novo>/sons/`, e o bloco `som` aponta para eles. Só formatos que o
  tema de sons já aceita, e nome validado (pack é dado, nunca código).
- Prova: criar o pack, vestir, e o tema de sons instalado é o do pack.

## 3. «Sons de aviso» (Criar › Sons)
- Do mockup: a lista de sons de aviso, um por evento, com prévia ao clicar.
- Cura: liga a lista ao motor de sons do item 2. Se um evento do mockup não tem som no tema de sons, ele não
  aparece (nada de fingir na tela).

## 4. Abas Sistema e Biblioteca em Criar › Ícones
- Do mockup: além da grade de aplicativos, as abas Sistema (`icones/sistema`) e Biblioteca (`icones/biblioteca`).
- Cura: as duas abas leem as pastas do pack, como a de aplicativos. «Levar para o tema» funciona igual.

## 5. «Tudo segue este horário» (Ajustes › Dia e noite)
- Do mockup: um interruptor que faz mascote, papel de parede e o resto seguirem o mesmo horário de dia e de noite.
- Cura: se o motor tem horários separados por área, o interruptor grava todos com o mesmo valor; desligado,
  cada área volta a ter o seu. Se uma área não tem horário próprio, ela não aparece.
- Prova: ligar e desligar no HOME temporário, conferindo o `meow.conf`.

## Como se prova
- `tests/todos.sh` duas vezes, verde. Prints do painel em 1829x1029 e 375 px nas telas tocadas
  (`tests/app-uso-real.py --fotos`).

## 6. O `desbanir` com foto da curadoria de fábrica (quem coordena, 24/10)
- Medido na máquina real: 8 fotos estavam em `ativos/` e no `BANIDOS.txt` vivo (vindas do `.padrao`), mas não
  em `banidos/`. O `wallpaper.sh desbanir <nome>` recusava com «não achei … em banidos/». Quem coordena tirou as
  linhas à mão (backup em `~/.local/state/meowsystem/backup-limpeza-20261024/`).
- Cura: com a foto em `ativos/` e o nome na lista, o `desbanir` só tira a linha (o `grep -vxF` que ele já tem).
  Sem foto em lugar nenhum, a recusa continua.
- Prova: teste com HOME temporário cobrindo os três casos (em `banidos/`, só na lista com foto em `ativos/`,
  nada em lugar nenhum).

## Fora deste bloco
- A P104 (ponte) e a P106/P107 (temas de app) estão em voo ou esperando integração. Não toque em
  `scripts/ponte_root.sh` nem em `scripts/temas-de-apps/`.

## Execução

### Os commits (`sprint/p105`, sem push)
- `cb9d2657` item 6: o `desbanir` de foto que está em `ativos/` e na lista só tira a linha, e a devolvida não
  volta à lista pelo `reconciliar_banidos_pasta`. Prova: `tests/desbanir.sh` (os três casos).
- `b15ea77c` item 1: `pack.py levar <id> foto` copia para `wallpapers/` do pack da pessoa, com o id na frente do
  nome, e declara `origens.wallpapers.prefixo`. O botão «Levar para o tema» fica em cada foto da galeria do passo.
- `71addc5f` item 2: o «Guardar» copia o tema de sons do pack de partida para `sons/`, e `som.tema` aponta para ele.
  Só `.oga`/`.ogg` com cabeçalho Ogg, num evento que o tema já tem.
- `5301914c` item 3: «Sons de aviso» em Criar › Sons, um por evento do tema do pack, com prévia (`/som`, que só
  serve arquivo da lista do pack) e «Trocar».
- `69d947eb` item 4: abas Sistema e Biblioteca em Criar › Ícones; «Levar para o tema» copia para `icones/sistema/`
  e `icones/biblioteca/`. SVG com script, `javascript:` ou atributo de evento é recusado. O
  `scripts/icones_pastas.sh` veste a pasta levada no lugar da herdada.
- `c192854e` item 5: «Mesmo horário» em Ajustes › Dia e noite. Ligado, claro ou escuro, papel de parede e tela quente
  gravam o horário da noite. O que cada área tinha fica em `horario-por-area.tsv` no estado e volta quando ele é
  desligado. Prova: `tests/mesmo-horario.sh`.
- `5d374a45` conferência: `-.png` perdia a extensão ao ser limpo e entrava no pack como `<id>-png`, que nem a rotação
  nem a lista viam. Agora a extensão sai antes da limpeza, e foto sem extensão é recusada. E o nome do som que vem
  da página (`..`, `.`) virava caminho no servidor e respondia 500 com a pasta temporária. Agora só a extensão é
  usada. As duas coisas estão no `tests/criar-tema-leva.sh`, que deu vermelho antes da correção.

### Ida e volta (conferência, HOME temporário, painel com PID próprio)
- Pelo painel, `/api/pack-importar` (o «Guardar») e `/api/criar`: o pack `noite-de-brinquedo` recebeu 25 sons do
  Dracula e duas fotos do carrossel. `Noite Roxa.png` entrou como `noite-de-brinquedo-Noite-Roxa.png`.
- Recusados: `../../../../etc/passwd`, `..`, `.` e `pack.json` como foto; tirar `../pack.json`; levar para o
  `dracula` (não é pack da pessoa); sons de `../dracula`.
- Vestido como o install faz (meow.conf com `PACK`, `semear-se-faltar`, `aplicar`, `som.sh aplicar`):
  - «2 foto(s) do pack copiadas», e o carrossel passou a girar com elas.
  - O `MeowSystem-Sons` instalado é igual (`diff -r`) ao `sons/` do pack.
- Exportado para `.meowpack` e importado noutro HOME: `wallpapers/`, `sons/` e `icones/sistema/` foram junto.
- Reimportar o mesmo CSV é recusado («tire o que está lá primeiro»), então um segundo «Guardar» não apaga o que já
  foi levado.

### Suíte
`tests/todos.sh` duas vezes seguidas, depois do `5d374a45`, na árvore com esta seção:
`== todos os 82 · 82 verde(s), 0 pulado(s), 0 vermelho(s) ==` nas duas.
Uma passada anterior deu vermelho no `portabilidade.sh`, porque o rascunho desta seção citava um caminho de casa.
Esse caminho já saiu.

### Prints
Em `p105-prints/`, ao lado da worktree em `.wt-meow/`, em 1829x1029 e em 375 px:
- Papel de parede, com e sem tema guardado.
- Sons, com a lista «Sons de aviso».
- Ícones nas abas Aplicativos, Sistema e Biblioteca.
- Dia e noite com o «Mesmo horário» desligado e ligado.
- Em `uso-real/`, as 14 páginas nos dois packs.

Nenhuma tela leva texto explicativo: o porquê está na dica («Guarde o tema em Cores», «Segue o horário da noite»).

### O que ficou
- **Sons de aviso:** o MeowSystem só toca o de mensagem nova. Os outros ficam no tema para quem o usar, e o som de
  volume do tema não aparece, porque quem toca no volume é o sino. O pack de partida `meowsystem` não tem tema de
  sons, então o tema que nasce dele não mostra a lista.
- **Rotação com a mesma foto duas vezes:** a foto levada fica em `ativos/` com o nome original e volta com o
  prefixo quando o pack é vestido. Com o pack no ar, ela entra duas vezes. Fica para o próximo bloco: o conserto
  é no semear do `wallpaper.sh` (P102), conferindo o conteúdo antes de copiar.
- **Aba Sistema:**
  - Mostra o nome cru do ícone (`folder-documents`), como a Biblioteca.
  - Só oferece as 10 pastas que o Dracula desenhou.
- **Mesmo horário:**
  - Claro ou escuro só aceita hora cheia, então os minutos da noite se perdem.
  - Ligado, as linhas das áreas ficam esmaecidas com a dica, mas ainda dá para editar.
- **Já era assim e não foi mexido:**
  - O «Guardar» herda sempre do pack padrão.
  - O «Trazer imagens» grava em `packs/meowsystem/wallpapers/ativos`.

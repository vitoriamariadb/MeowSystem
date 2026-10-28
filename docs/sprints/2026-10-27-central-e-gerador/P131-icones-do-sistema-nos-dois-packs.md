# P131 — os ícones do sistema e a biblioteca, nos dois packs

## O pedido (ela, 27/10/2026, depois do install)

«os ícones do sistema de ambos os packs, os ícones das bibliotecas de ambos os packs e afins não estão devidamente
mapeados. Tem pouquíssimos, e os ícones do sistema tipo desligar, wifi e afins, que deveriam popular os dois theme
packs, não aparecem lá. Isso precisa ser corrigido.»

## O que se mediu (27/10, no `dev` 4419df82 e no tema instalado)

1. **A aba Sistema do painel só mostra pastas.** `acervo_para_levar(None, "sistema", pack)` devolve 7 pastas no
   MeowSystem e 10 no Dracula. Nenhum dos 27 alvos do `packs/meowsystem/icones/sistema.map` (páginas das
   Configurações, rede, bateria, som...), nenhum dos 68 desenhos de tipo de arquivo (`mimetypes.map`), nada de
   bandeja. O bloco chama «Pastas e tipos» e não traz os tipos.
2. **A Biblioteca do MeowSystem tem 36 desenhos**, e a pasta `packs/meowsystem/icones/sistema/` guarda 688 SVG,
   dos quais 589 nenhum mapa cita. Os moldes dos tipos de arquivo e os glifos do traço estão misturados numa pasta
   só, e o painel não olha para ela (`PASTAS_DA_FICHA = ("icones/apps/", PASTA_BIBLIOTECA)`). O
   `sistema.map` cita `box`, `shield` e `tablet`, que não existem no pack. O Dracula tem 477 na biblioteca e 10
   no sistema (só pastas). O `icones.sistema` dele é `herda: meowsystem, pintar: text`, e nada herdado aparece.
3. **O tema instalado (`~/.local/share/icons/MeowSystem-Icons`) não tem os ícones do sistema.** Ele tem 28
   em `status/` (só as páginas das Configurações), 123 em `mimetypes/` e 58 em `apps/`. `system-shutdown-symbolic`,
   `network-wireless-signal-*-symbolic`, `audio-volume-*-symbolic` e `battery-*-symbolic` não existem, e o
   COSMIC cai no `Inherits=Papirus-Dark`. É de propósito no `sistema.map` (linhas 10-25: «as famílias de estado
   continuam vindo do Papirus», porque o Arcticons não tem `-off`, `-muted` e afins, e `#system-shutdown-symbolic:power`
   está comentado). O pedido de hoje desfaz essa escolha: o sistema mora no pack.

## A causa

O pack só declara o que um glifo solto do Arcticons cobre. Nenhum pack desenha as famílias de estado, e o painel
só lista duas das três pastas do pack, sem os mapas do sistema e sem herança.

## A cura, na origem

1. **Inventário do que o COSMIC pede.** Script que lista os nomes de ícone de sistema que o COSMIC e os applets
   da barra pedem de fato (painel, applets de rede/som/bateria/energia/bluetooth/notificações, Configurações, janela
   de desligar, OSD de volume e brilho). Fonte: o que o tema herdado (Papirus-Dark, Cosmic) resolve hoje e os
   nomes que os binários do `cosmic-*` citam. Sai em `relatorios/nomes-de-sistema-do-cosmic.md`, com a contagem.
2. **Cada pack desenha o sistema inteiro, famílias de estado incluídas**, no estilo dele:
   - MeowSystem: traço, `currentColor`, o mesmo do gerador `traco`;
   - Dracula: o do pack (o `base.origem` do dracula-icons, se ele trouxer; senão, o gerador `circle` dele).
   Cada estado de uma família (wifi 0 a 4 barras e desligado, volume mudo/baixo/médio/alto, bateria por nível e
   carregando, microfone, bluetooth, brilho, desligar/reiniciar/suspender/sair/travar) tem desenho próprio e
   coerente. Pack é dado: os SVG e os mapas moram em `packs/<pack>/icones/`. A família fica inteira no pack ou
   inteira fora; meia família não entra (o motivo do `sistema.map` continua valendo para isso).
3. **A pasta do sistema se arruma.** Os moldes dos tipos de arquivo saem de junto dos glifos do sistema (cada um em
   sua pasta), os glifos sem mapa que são biblioteca vão para a `biblioteca/`, e os três alvos que faltam
   (`box`, `shield`, `tablet`) ganham desenho ou saem do mapa.
4. **O painel mostra o que o pack põe.** A aba Sistema lista, por pack, tudo o que o tema dele instala: sistema,
   bandeja, pastas e tipos de arquivo, incluindo o que herda (pintado como a herança manda). A Biblioteca lista a
   biblioteca inteira. Os grupos com nome do dia a dia («Barra e bandeja», «Configurações», «Pastas», «Tipos de
   arquivo»).
5. **O instalador põe tudo no tema.** `scripts/construir_icones.sh` e os mapas entregam os nomes novos em
   `status/`, `actions/` e `devices/`, nos tamanhos que o tema já usa.

## Como se prova

- Teste que, para os dois packs, conta os nomes do inventário que o tema instalado (num HOME temporário) resolve
  dentro do próprio tema e não no `Inherits`: a meta é a lista inteira do inventário, e o teste lista o que falta.
- Teste do painel: a aba Sistema traz, nos dois packs, os grupos acima, com `system-shutdown-symbolic` e
  `network-wireless-signal-excellent-symbolic` entre os itens; a Biblioteca do MeowSystem passa de 36.
- `tests/app-completo.py` e a captura headless das abas Sistema e Biblioteca dos dois packs, em
  `capturas/p131-*.png`.
- `./tests/todos.sh` sem vermelho novo.

## Fora daqui

As cores do sistema: o COSMIC repinta o simbólico com a cor do texto (`docs/COSMIC-THEMING.md` §4g). Os ícones
dos apps (`apps.map`) não entram, salvo os da biblioteca que o inventário pede.

## Execução

Bloco `icones-sistema`, branch `bloco/icones-sistema`, 27/10/2026. Um agente só, sem merge.

1. **Inventário.** `scripts/inventario_do_sistema.py medir|conferir|relatorio` lê os binários do COSMIC
   (applets, osd, painel, notificações, configurações, biblioteca de apps, lançador) e os `cosmic-applet-*` do
   hicolor. O contrato é `assets/contratos/nomes-de-sistema.tsv`: **168 nomes**, 167 medidos mais
   `network-wireless-signal-none-symbolic`, que fecha a família do wifi (o applet pede de 1 a 4 barras e o
   desligado; sem o «nenhuma barra» a família ficaria pela metade). Cada nome tem pasta (status 105, actions 38,
   devices 25), grupo e rótulo. Relatório: `relatorios/nomes-de-sistema-do-cosmic.md`.
2. **Os desenhos.**
   - MeowSystem: **132 desenhos novos** em `icones/sistema/`, no traço do Arcticons (viewBox 48, `currentColor`),
     gerados por script e conferidos em folha de contato antes de mapear
     (`capturas/p131-familias-meowsystem.png`, 16/22/32/48 px, escuro e claro). Famílias inteiras: wifi
     (4 barras a nenhuma, procurando, erro, desligado), volume (mudo, baixo, médio, alto, acima do máximo),
     microfone (4 estados), bateria (10 níveis × carregando × limite de carga), brilho da tela, bluetooth,
     notificações, energia (desligar, reiniciar, suspender, sair, travar), mídia, janelas e as páginas das
     Configurações. O microfone foi redesenhado depois da primeira folha: os níveis em linha viravam borrão a
     16 px, e passaram a enchimento.
   - Dracula: o bloco `icones.sistema` deixa de herdar o traço do MeowSystem. **143** glifos são os simbólicos do
     dracula-icons (ramo `circle`, `00a230a2`), com a cor trocada por `currentColor`; **19** foram desenhados no
     mesmo preenchido de 16 px, onde o dracula-icons não tem o nome (as baterias com limite de carga, a pasta
     nova, a alça, as áreas de trabalho). Folha: `capturas/p131-familias-dracula.png`. Cada glifo tem linha no
     `PROCEDENCIA.md` (GPL-3.0, com o sha256).
   - Os geradores ficaram fora do repositório (pack é dado): `meow.py`, `dracula.py` e `folha.py` no scratchpad
     da sessão.
3. **A pasta do sistema.** Ficam em `icones/sistema/` só os desenhos que um mapa entrega. Os 581 moldes do
   catppuccin sem tipo de arquivo ligado, o `phone` e o `signal` (logo do app, que respondia pela página de sem
   fio) foram para `biblioteca/`; `folder` e `shield` voltaram da biblioteca porque agora têm nome mapeado.
   `box` virou o desenho `preferences-X11-applications`, `shield` é a VPN e `tablet` ganhou desenho.
   **Limite da decisão 14:** os 75 moldes de tipo de arquivo em uso continuam em `icones/sistema/`, ao lado dos
   glifos. Uma pasta só deles seria a quarta pasta, que o `tests/tres-pastas.sh` recusa; não abri essa decisão.
4. **O painel.** A aba Sistema tem cinco grupos: «Barra e bandeja», «Configurações», **«Botões e janelas»**,
   «Pastas» e «Tipos de arquivo». O terceiro não estava na lista da sprint. Ele leva os 35 nomes de botão, seta e
   janela que o COSMIC também pede e que não são barra nem página de configuração. Cada bloco é lido pela herança
   (`herda`) a partir do pack da cadeia. Assim o Dracula mostra os tipos de arquivo que herda do molde do
   MeowSystem, pintados com a paleta dele. A Biblioteca do MeowSystem lista as 617 e pinta os moldes do
   catppuccin. A saída do `pack.py acervo-para-levar` não mudou.
5. **O instalador.** `scripts/icones_sistema.sh` lê no contrato a pasta de cada nome e escreve em
   `22x22/` e `scalable/` de `status`, `actions` e `devices`. Um nome que muda de pasta sai da antiga. A
   espessura do traço só entra em desenho de traço (`stroke="currentColor"`), e o preenchido do Dracula fica
   como veio. `scripts/construir_icones.sh` declara `actions` e `devices` no `index.theme`.

**Muda o que ela vê:** o desligar da dock deixa de ser a logo antiga do Papirus, que ela escolheu em 27/08
(«volta a logo antiga do desligar apenas»). A família de energia mora agora inteira no pack, pela decisão do
coordenador de 27/10. As famílias da barra só aparecem no próximo login, porque o painel não relê o tema.

**Provas.**
- `tests/icones-do-sistema.sh` (novo, portátil) instala os dois packs numa casa de brinquedo. Os 168 nomes saem
  dentro do tema e no índice, sem herança, nos dois packs. A família fica inteira no mapa, a segunda passada não
  escreve nada e o Dracula não recebe o traço.
- `tests/icones-por-pack.py` confere:
  - os cinco grupos nos dois packs;
  - `system-shutdown-symbolic` e `network-wireless-signal-excellent-symbolic` na barra;
  - 617 itens na Biblioteca do MeowSystem;
  - a barra do MeowSystem no traço e a do Dracula sem ele.
- Capturas headless: `capturas/p131-sistema-{meowsystem,dracula}.png` e
  `capturas/p131-biblioteca-{meowsystem,dracula}.png`. O `.gitignore` recusa `*.png`, então as capturas e as
  folhas ficam em disco, na pasta `capturas/` da árvore do bloco.
- `tests/pack-dracula-completo.sh` passou a contar os moldes de tipo de arquivo (75, pintados 150) e confere o
  display em `devices/`.
- Três testes contavam a pasta `sistema/` do Dracula como se fosse só de pastas, ou o rótulo do Sistema como se
  fosse só de pasta. Agora o `pastas-do-pack.sh` e o `tres-pastas.sh` leem as pastas pelo `pastas.map`. O
  `acervo-do-pack-em-edicao.sh` só recusa hífen no rótulo de pasta («Wi-Fi» e «Alto-falante» são nomes do dia a
  dia) e recusa nome técnico em qualquer rótulo. Os três passaram rodados sozinhos.
- `./tests/todos.sh` (27/10, antes desses três consertos): **109 testes, 104 verdes, 0 pulados, 5 vermelhos**.
  - `acervo-do-pack-em-edicao.sh`, `tres-pastas.sh` e `pastas-do-pack.sh` foram consertados e passaram rodados
    sozinhos.
  - Os outros dois já eram aceitos:
    - `restaurar.sh` (`pack_usar`, `desinstalar`);
    - `decisoes.sh`. Este falha na GPU do compositor e também na decisão 24, porque o `tests/enxugar.sh:243`
      cita `docs/pesquisas/`. Esse arquivo veio do `dev`, e este bloco não mexeu nem nele nem no
      `tests/decisoes.sh`.

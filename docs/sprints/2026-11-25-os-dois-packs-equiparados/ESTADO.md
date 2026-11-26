# Os dois packs equiparados (25/11/2026)

Pedido: «concluir os dois temas, equiparar eles de fato». Parte da folha
`../2026-11-25-os-tres-pcs-em-dia/O-QUE-FALTA-NOS-DOIS-PACKS.md`.

## O que a medida mudou na folha
- Ponteiro e ícones-base do `meowsystem` não são falta: o Catppuccin resolve os dois pelo `meow.conf` (`CURSOR`, com
  variante por flavor e acento, e o Papirus com as pastas pintadas), o Dracula pelo `pack.json`. Dois caminhos, o
  mesmo resultado; declarar no pack tiraria a escolha de variante dela.
- VLC não precisa de módulo: é Qt e segue o `qt5ct`/`qt6ct` que o `toolkits-gtk-qt` já escreve.
- Das seis «cores cravadas», três eram texto de ajuda; o ramo do btop nunca rodava (saiu na P299); a reserva do
  `_tinta_do_traco` só vale com paleta sem `text`. Sobra o `gerador_circulo.py`, que crava a paleta do Dracula.
- Ninguém usa VS Code no nitro-5: o tema de ícones de arquivo do Dracula não aparece em tela nenhuma hoje.

## Os blocos
| bloco | o quê | estado |
|---|---|---|
| 1 · código | P299, o btop sem o mauve do Mocha cravado | feito, commit `b02bd98` |
| 2 · desenhos do Catppuccin | oito escolhidos e instalados: os seis do Arcticons (decisão 69), o COSMIC Viewer 1G (decisão 70) e o FogStripper 8G, desenho à mão, no estado de quem usa do MeowSystem (não há FogStripper no portátil) | feito; A Forja e o Pipeline esperam o atalho |
| 3 · módulos de app | Godot, GIMP, ghostwriter (`BLOCO-APPS-SEM-MODULO.md`) | voando na worktree `.worktrees/meow-apps-2511`, branch `bloco/apps-sem-modulo` |
| 4 · desenhos do Dracula | Dédalo, FogStripper, Pipeline EducaDados no nitro-5 | na fila do André (`b6b2791a`) |

## O que falta do bloco 2
- FogStripper: ela pediu o logo repensado como «a pata de um gato tocando um espelho quebrado» e aprovou o 8G («é
  incrível»): SVG escrito à mão, pata na diagonal com dedos recortados e almofada, cinco trincas. Entrou pelo mesmo
  caminho da oficina do painel (`_api_app_desenho`, ação `salvar`): linha `fogstripper:mao:sky` em
  `~/.config/meow/icones-convertidos.map`, retoque em `~/.local/share/meowsystem/retoques/`, e `fogstripper` em
  `icones-destravados.list`. Cópia do SVG em `~/.cache/meow-leva/fogstripper-8G.svg`.
- A Forja (9A, mauve), Pipeline EducaDados (10A, green) e o FogStripper são projetos dela: `tests/pack-dracula-completo.sh`
  recusa arte pessoal em `packs/`. Vão no mapa de quem usa (`~/.config/meow/icones-convertidos.map`), por PC. A Forja
  e o Pipeline têm `Icon=` de caminho absoluto no atalho (`forja.desktop`, `pipelines-educadados.desktop`), que
  nenhum tema alcança: o atalho muda no projeto de cada um. O FogStripper é intocável até entrar em
  `~/.config/meow/icones-destravados.list`.
- O Godot da Steam (`steam_icon_404790`) também é intocável por regra: foi destravado no MeowSystem, pela escolha
  dela. No portátil não há atalho do Godot.

## O bloco 3
Fechado na worktree `.worktrees/meow-apps-2511` (branch `bloco/apps-sem-modulo`), fora do `master`:
`29f8bad` godot, `feb29d5` gimp, `9054fbc` ghostwriter (implementa-apps); `d995ac0` e `fc2c769`, dois consertos do
Godot, `9ef0a18`, teste do ghostwriter no formato real, e `5d3fbde`, o `ACHADO-chave-etapa-intermitente.md`
(confere-apps). Veredito do conferente: godot aprovado com dois consertos, gimp e ghostwriter aprovados;
`./tests/todos.sh --portatil` com 146 verdes, 0 pulados, 0 vermelhos.

**Por que não entrou no `master`:** `gimp` já está no `APPS_ATIVOS` dos três PCs (`meow.conf`, linha 67 nos dois dela,
1482 no nitro-5). Integrar liga o tema do GIMP nos três na atualização seguinte (decisão 65), sem ninguém ter visto.
Godot e ghostwriter não estão em nenhum `APPS_ATIVOS`. Espera o cartão «módulos» da página de decisões.

Falta: a passada na tela (GIMP e Godot com cópia da configuração, na área OS), a suíte inteira com COSMIC e a
integração. O ghostwriter só existe no nitro-5, onde o dono tem `theme=Sem nome 1`: o módulo grava o tema e não o
escolhe.

## A bandeja e a barra, medidas em 25/11
- Os dois packs desenham os mesmos 269 nomes do `sistema.map` (barra, applets e Configurações), cada um no seu
  estilo. Nenhum nome falta em nenhum dos dois.
- Só o `meowsystem` declara `icones.bandeja`: com o Dracula no ar, `icones_bandeja.sh`, `icones_tray_steam.sh` e
  `icones_tray_zapzap.sh` pulam, e os ícones de bandeja da Steam e do ZapZap ficam de fábrica.
- Ao vivo: MeowSystem com Hefesto e Steam (os dois com `IconThemePath` próprio); portátil com Hefesto; nitro-5 com o
  ZapZap, que não manda `IconName`. OBS e qBittorrent não foram medidos (fechados).
- A Soneca no `meowsystem` aponta para `soneca-desperto` e `soneca-ronronar`, que não existem no pack: valem os SVG
  do próprio applet, como diz a decisão 59.

## As decisões dela
Página privada «O que falta decidir»: coleções `decisoes` (14 cartões: opção e comentário), `barra` (ícones
marcados para rever) e `geral` (`bandeja`, `cota`). Ler de lá antes de abrir o próximo bloco.

## Depois das catorze decisões (25/11, noite)
As decisões estão em `DECISOES-DE-25-11.md`. O que já saiu delas:

- **Portátil:** `apt dist-upgrade` completo (44 pacotes, rc=0, nada pendente, sem pedido de reinício) e limite de
  carga ligado: `acer-wmi-battery` 0.1.9f90d75 por DKMS (a mesma fonte do nitro-5, sha256 conferido),
  `/etc/modprobe.d/acer-wmi-battery.conf` com `enable_health_mode=1`, `/etc/modules-load.d/acer-wmi-battery.conf`.
  `health_mode=1`, bateria em «Not charging». Registro em `~/.cache/meow-leva/portatil-2511.log` do portátil.
- **Atalhos:** A Forja (9A, mauve) e Pipeline EducaDados (10A, green) no mapa de quem usa dos dois PCs dela, pela
  oficina (`forja:mao:mauve`, `pipelines-educadados:mao:green`); o ícone de fábrica de cada um copiado para o
  `hicolor`; `Icon=forja` e `Icon=pipelines-educadados` nos atalhos (a linha de antes em
  `~/.cache/meow-leva/*.desktop.antes`). Recado sem commit em cada projeto:
  `Hefesto-Forja/docs/RECADO-o-atalho-usa-nome-de-icone.md` e
  `pipelines-educadados-apresentacao/RECADO-o-atalho-usa-nome-de-icone.md`.
- **Bandeja dos apps fechados**, abertos num Xvfb e fechados: qBittorrent (`Id=qBittorrent`) e ZapZap (`Id=ZapZap`)
  publicam `IconName` vazio e só `IconPixmap` 22x22, sem `IconThemePath`: tema de ícones não os alcança. O OBS
  registrou um item na primeira abertura e nenhum na segunda (`SysTrayEnabled=true`); ficou sem medida.
  O `flatpak kill` deixa trava velha no qBittorrent (`config/qBittorrent/lockfile`, pid 2 do sandbox): ele não abre
  até a trava sair. Fechar com `SIGTERM` no processo `qbittorrent` leva 2 s e não deixa trava.
- **Bloco 3, a passada de tela:** achou o P302 (o Godot da Steam é autocontido: `._sc_` ao lado do binário,
  preferências em `editor_data/`; o módulo não olhava lá). Conserto com teste em `51a2556`, na branch
  `bloco/apps-sem-modulo`. Capturas de antes e depois, num Xvfb com cópia da instalação:
  `~/.cache/meow-leva/captura-godot-2026-11-25.png` e `captura-gimp-2026-11-25.png`, enviadas a ela. Neste PC a
  pasta `~/.var/app/org.gimp.GIMP/config/GIMP/` não tem `3.x`: o GIMP 3.2 nunca foi aberto aqui e o módulo se pula
  até ele abrir uma vez. Espera o sim dela para entrar no `master`.
- **Dois blocos voando** (uma worktree cada, agente implementa, agente confere):
  `bloco/nucleo-do-pack` em `.worktrees/meow-nucleo-2511` (`BLOCO-NUCLEO-DO-PACK.md`: tabela da procedência em
  `procedencia.tsv`, `73f434c`; prompt de pack pessoal por lista, `b0a65e4`, decisão 71, com três furos de segurança
  apontados na revisão e devolvidos ao implementador) e `bloco/cli-e-bandeja` em `.worktrees/meow-cli-2511`
  (`BLOCO-CLI-E-BANDEJA.md`: `meow ganchos`, `869462f`; bandeja do Dracula, `a09139f` e `b586c96`). Na integração:
  acrescentar ao `packs/dracula/procedencia.tsv` os dois glifos novos da bandeja, e uma linha de `pack.py` é tocada
  pelos dois blocos (`CAMPOS_COM_LEITOR`).
- **Falta:** a captura da vitrine do Catppuccin (pede a área de trabalho na tela: só com o sim dela para trocar de
  área por alguns segundos); a folha de papéis de parede e a página de temas de ícone do VS Code para o Dracula
  (bloco de pesquisa, depois destes dois); a explicação do P276 item D; ler a calibração do nitro-5 em 26/11.

## A integração dos três blocos (25/11, 23h)
Árvore de integração `integra/2511`, em linha reta sobre o `master` (`2107764`), sem conflito. Nenhum agente voa.

- **Módulos de app** (`bloco/apps-sem-modulo`): Godot, GIMP e ghostwriter, com o P302. Ela viu as capturas e
  escolheu ligar o Godot e o GIMP; o GIMP do nitro-5 muda junto (item `1020689c` na fila do dono do pack).
- **Núcleo do pack** (`bloco/nucleo-do-pack`): `procedencia.tsv` nos dois packs; prompt de pack pessoal por lista
  (decisão 71, exceção na 67). O conferente fechou: referência no `format` e no `continuation_prompt`, tipo
  `ligavel` (`starship-ligaveis.tsv`, 27 módulos, nenhum roda binário que o starship não rode de fábrica), linha
  não imprimível, aninhamento fundo, pasta e FIFO no `starship.toml`, e `pack.json`/`paleta.json` aninhados fundo
  (`ba86321`). Sem conserto, escrito em `ACHADO-arquivo-de-pack-de-fora-sem-teto.md`.
- **Ganchos e bandeja** (`bloco/cli-e-bandeja`): `meow ganchos instalar|conferir|remover`; o Dracula declara
  `icones.bandeja` (ela aprovou os dois glifos na folha). P303: o glifo do pack virava código no `tray_icon.py` do
  ZapZap; agora entra por `repr()` trocado pela AST, e ZapZap e Steam passam o glifo por `scripts/glifo_tracado.py`.
  O desfazer não depende mais do glifo (caso em `tests/bandeja-por-pack.sh`).
- **Na integração:** as duas linhas dos glifos no `packs/dracula/procedencia.tsv` (a do fantasma com licença
  «a confirmar», perguntada ao dono do pack); a captura `packs/meowsystem/capturas/area-de-trabalho.jpg`, sobre o
  `patinhas-noite` do próprio pack, declarada em `vitrine.capturas`, com a exceção no `.gitignore` para
  `packs/*/capturas/`.
- **Prova:** `./tests/todos.sh` inteira em `fa59deb`: 185 verdes, 0 pulados, 0 vermelhos
  (`~/.cache/meow-leva/suite-integra-2511.log`). Depois dela entrou só `37cf783`, que toca um arquivo de teste,
  rodado verde sozinho.
- **Sem medida:** o OBS na bandeja (escolha dela). **Sem prova na tela:** o ícone do ZapZap na bandeja com o app
  aberto no formato novo; o prompt de um pack pessoal num terminal.

## Os blocos seguintes
1. `meow.conf.exemplo`: o esquema do painel sai dos comentários para um arquivo de dados (decisão dela); reescreve o
   leitor do painel e o `migrar_conf.py`. Tarefa escrita antes do agente.
2. Leitor único para arquivo de pack de fora, com teto de tamanho, cobrindo os mapas
   (`ACHADO-arquivo-de-pack-de-fora-sem-teto.md`); junto, o `user.css` do Spotify de pack de fora, que pode buscar
   na rede por `url()`.
3. Pesquisa, em página com opções: papéis de parede do Catppuccin e tema de ícones de arquivo do VS Code no Dracula.
4. A calibração do nitro-5 (`~/.cache/meow-leva/bateria-calibra.log`, em 26/11).

## Fica com quem usa
- Os códigos da folha de desenhos (e a cor de cada um).
- Os cinco campos do Dracula sem leitor: estão no formato do manual (`docs/PACKS.md`, exemplo e aviso); ganhar leitor
  ou sair do formato muda o manual, não a tela.
- Papéis de parede do Catppuccin (3 pares contra 19 desenhos do Dracula) e as capturas da vitrine: arte.
- GitHub Desktop, Foundry VTT e cliente da Steam: sem tema possível sem cliente modificado.

## A entrega (25/11, 23h50)
- `master` em `fc1f25b`, no GitHub. `meow levantamento` com «nada a resolver» e instalador com rc=0 nos três PCs
  (`~/.cache/meow-leva/install-2511-final.log` em cada um).
- `godot` no `APPS_ATIVOS` dos dois PCs dela (a linha de antes em `~/.cache/meow-leva/meow.conf.antes-do-godot`).
  Neste PC o Godot foi vestido em `~/.config/godot` e na `editor_data` da Steam.
- nitro-5: o ícone da bandeja do ZapZap foi refeito com o glifo do Dracula; a Steam não está instalada lá; o GIMP
  espera ser aberto uma vez.
- As worktrees e as branches dos blocos e da integração foram removidas: todo commit delas está no `master`.
- Sem prova na tela: o Godot e o GIMP abertos de verdade depois do instalador, o ZapZap na bandeja do nitro-5 e a
  captura na vitrine do painel.

## Próximo passo
1. Escrever a tarefa do bloco do `meow.conf.exemplo` (item 1 de «Os blocos seguintes») e lançar: uma worktree, um
   agente implementa, um confere.
2. Ler a calibração do nitro-5 (`~/.cache/meow-leva/bateria-calibra.log`).
3. A página de papéis de parede do Catppuccin e a dos ícones de arquivo do VS Code no Dracula.

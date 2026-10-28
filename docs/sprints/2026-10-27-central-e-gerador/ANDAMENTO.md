# Leva central e gerador (27/10/2026) — andamento

## Agora
- 28/10, depois do login: o compositor vivo é o build do MeowSystem (`meow compositor conferir`: 5 patches no disco e
  na sessão). O Vencord está injetado no `app-1.0.166`; falta só o `enabledThemes`, que o install liga com o Discord
  fechado. A D6 não fica verde com login: o ID da decisão (`25a2`) não existe nesta máquina (RTX 4060, `28a0`). Ela
  decidiu: produto universal, a GPU detectada por máquina, e a P132 faz isso (worktree `~/Desenvolvimento/MeowSystem-gpu`,
  branch `bloco/gpu`, 2 agentes). A linha do `jogos-fora.map` fica apagada, por decisão dela (ab44877d).
  PRÓXIMO: integrar a P132 no `dev` e rodar o install com o HOME real pelo askpass (pedido dela). Depois, pedido
  dela: `master` no `origin` (hoje em 89064565, de 28/09; as tags v2.0.0 e v2.1.0 só existem aqui) e o release.
  Os forks (pergunta dela): o install não chama o install de nenhum, e o que falta está na P133.
- FECHO (28/10, madrugada): tudo no `dev` (merge 9e5bf737) e instalado com o HOME real (69 etapas, rc=0).
  `meow doctor --consertar` rodado: as 348 imagens foram para `~/.local/share/backgrounds/meowsystem`, a
  árvore velha `midia/` e `leitura/` (1,6 GB) saiu, e o corte da Aurora (compositor e luz noturna) está no
  self-heal e no install do zsh, com cópia em `~/.local/state/meowsystem/vizinhos/`. Conserto do coordenador:
  o vigia de `ativos/` era gravado com o `@ATIVOS@` cru (e78bf239). A pasta foi enxugada por decisão dela
  (2,6 GB para 319 MB; o registro em `arquivo:levas/2026-10-27-pasta-local/`), e o enxugar saiu (bec9c745).
  O qBittorrent trocou o Dracula dela pelo tema do pack, por decisão dela (cópia em
  `~/.local/state/meowsystem/backups/qbittorrent-antes-2026-10-28`).
  PRÓXIMO: o Vencord do Discord entra quando ela fechar o Discord. O build do compositor vale no próximo login
  (aí a D6 da GPU deve ficar verde). `assets/apps/jogos-fora.map` tem uma linha apagada que não é desta leva:
  a decisão é dela. Sprints anotadas: a corrida do `enviarLote`, o contraste do traço no Latte, os rótulos
  cortados da bateria, os tipos de arquivo em inglês, o Ghostwriter no Nitro, o `sistema_limpar` em
  `restaurar.sh`, o Vencord pelo `meow`, o fundo do chat do ZapZap e a frase «abra o Waterfox uma vez».
- Desinstalado da máquina (27/10), tudo movido para
  `~/.local/state/meowsystem/backups/desinstalacao-2026-10-27/` (reversível):
  - applets em `~/.local`: os cinco `meowsystem-*` (instalados à mão pelos agentes, não pelo MeowSystem),
    os legados `meow-applet-leitura` e `meow-applet-now-playing`, os `.desktop`, metainfo e ícones;
  - flatpaks de terceiros: QuickSettings (DrakRosmann), Status Hub (marcelogomes90), Eyedropper,
    Clipboard Manager, Drives, ASCII-dot-battery (dados mantidos);
  - build do compositor do MeowSystem (`~/.local/libexec/meow/cosmic-comp/<versão>`), `matriz.tsv`,
    `applet-pino-base.tsv`.
  - Compositor: `/usr/bin/cosmic-comp` era o build da Aurora (23/10). O self-heal da Aurora o regravava
    depois de todo apt (`aurora-cosmic-comp-ws.sh --ensure`). Feito por `sudo -A`: o artefato
    `/var/lib/aurora/cosmic-comp-<versão>.aurora-ws` virou `.aurora-ws.QUARENTENA`, freio
    `/var/lib/aurora/cosmic-comp-ws-autobuild-off` ligado, `apt-get install --reinstall cosmic-comp`.
    Agora o binário bate com o `.pkg-orig` (pacote + shader da luz noturna que o pós-apt da Aurora injeta).
    Decidido por ela (27/10): o MeowSystem é dono do compositor e da luz noturna. Uma sprint tira da Aurora
    (`~/.config/zsh/scripts`: `aurora-cosmic-comp-ws.sh`, o `--ensure` e a injeção do shader no
    `ritual-aurora-self-heal.sh`, `aurora-night-light.py`, `aurora-cosmic-nightlight-watch.sh`) tudo o que
    mexe no compositor, só depois que o shim e o build do MeowSystem estiverem no ar, sem janela sem luz noturna.
  - Menu do Arquivos: `~/.local/bin/cosmic-files`, `cosmic-files-applet` e a guarda
    `~/.local/state/meowsystem/cosmic-files`.
- A configuração do painel (`plugins_wings`) ficou como estava: as entradas antigas são o alvo do
  «Trocar» da página Extensões.
- Achado: o shim do compositor do MeowSystem nunca foi ligado nesta máquina; quem valia era o binário
  da Aurora gravado por cima do de fábrica.
- Levantamento feito (2 agentes): `relatorios/levantamento-*.md`, sprints P115 a P123, commit 58b531be no `dev`.
- INTEGRADO em `integracao/central-e-gerador` (worktree `~/Desenvolvimento/MeowSystem-integracao`): Painel (P115-P117,
  `relatorios/conferencia-painel.md`), Central (P120-P121, `relatorios/conferencia-central.md`) e Forks (P122,
  `relatorios/conferencia-forks.md`, merge c2187964; repos `vitoriamariadb/meowsystem-{eyedropper,clipboard,drives,
  ascii-battery}` na main, nada instalado ainda) Pasta (P123, `relatorios/conferencia-pasta.md`, merge 39e3264c) e Textos (P118-P119,
  `relatorios/conferencia-textos.md`, merge 50f259de; as 15 cópias mortas de `.git/hooks` foram para
  `~/.local/state/meowsystem/backups/git-hooks-mortos-2026-10-27`) e Aurora (P124-P125, `relatorios/conferencia-aurora.md`, merge 704c8be0;
  doctor com 76 conferências). Correção do coordenador na integração: a grade do acervo pinta o traço (10d9f698).
- EM VOO, a partir da integração (ela pediu os blocos juntos, 27/10):
  Nada. Modificações (P130) entrou na integração em 28/10 (merge 947fb272, `relatorios/conferencia-modificacoes.md`);
  falta a suíte, o `dev` e o install. Anotado da P130: a corrida do `enviarLote` (app.js) que devolve valor velho com
  o servidor lento vira sprint; só o Terminal tem página de detalhe. Flatpak (P127-P129) integrado às 23:20 (merge d75f0c1b, doctor com 79
  conferências; `relatorios/conferencia-flatpak.md`). No fecho dele: o `APPS_ATIVOS` dela ganha `libadwaita` e
  `waterfox`, o install com o HOME real limpa o override global; o Ghostwriter fica para medir no Nitro; o
  `restaurar.sh` também acusa `sistema_limpar` (o `atualizar_sistema.sh limpar` copia o .deb real do cosmic-comp para
  a casa de brinquedo), anotado para a sprint das saídas.
- 27/10 21:10: o `dev` recebeu a integração (c4fade96) e o install rodou com o HOME real, pedido dela: 69 etapas,
  ponte root posta pela caixa do askpass (4419df82). Os dois blocos em voo integram e o install roda de novo.
- 28/10: Ícones do sistema (P131) integrado (merge 46a5ceee, `relatorios/conferencia-icones-sistema.md`): 168 nomes de
  sistema nos dois packs, Biblioteca do MeowSystem de 36 para 622. Levado ao `dev` (ccdca340) com o install. Anotado
  para depois: traço do Latte sem contraste no cartão escuro do painel; rótulos da bateria cortados; Tipos de
  arquivo em inglês; os geradores dos desenhos guardados em `~/.local/state/meowsystem/backups/p131-geradores-2026-10-28`;
  a decisão 24 do `decisoes.sh` (o `tests/enxugar.sh:243` cita `docs/pesquisas/`) some quando o enxugar sair no fecho.
- Era EM VOO (ela, 27/10: «lança a 131 agora»), `wf_b64cd132-75f`: P131 (os ícones do sistema e a biblioteca nos dois packs, «Blocos», rodada 6).
  Decisão dela de 27/10 que desfaz o `sistema.map:10-25`: as famílias de estado (desligar, wifi, som, bateria)
  moram no pack, não no Papirus.
  Worktrees `~/Desenvolvimento/MeowSystem-<bloco>`, branches `bloco/<bloco>`.
- Próximo passo: integrar cada um assim que voltar. Fecho da pasta, no checkout dela, nesta ordem: `du -sh`; `meow doctor`
  (ver `basefundo` e `estadovelho` acusarem); `meow doctor --consertar`; `scripts/enxugar.sh --raiz ~/Desenvolvimento/MeowSystem`
  (lista); `--aplicar`; `du -sh`; depois um commit tira `scripts/enxugar.sh`, `tests/enxugar.sh` e as linhas deles; por fim instalar do zero na máquina.
- 27/10 17:46: um teste da suíte (o desinstalar da casa de brinquedo) tirou o bloco do MeowSystem do `.zshrc` real, pelo
  `ZDOTDIR` herdado. Bloco devolvido às 17:56 (cópia em `~/.local/state/meowsystem/backups/zshrc-antes-2026-10-27-1756`);
  cura na integração (65d53c56, 8c946886). As suítes de Aurora, Textos e Pasta começaram antes da cura: depois de cada
  uma voltar, conferir `tail -3 ~/.config/zsh/.zshrc` e rodar `scripts/terminal_bloco.sh aplicar` se faltar.
- Modificações (27/10, trazido do Nitro): as sprints P127 a P130 entraram nesta leva por pedido dela («aí pra executar
  dispara um workflow no mesmo estilo do nosso»). A auditoria está em `relatorios/auditoria-tema-por-app.md` e o
  contorno que roda no Nitro em `relatorios/contorno-local.md`; a pasta `modificacoes/` da raiz saiu. Decidido por
  quem usa no Nitro e mantido: P127 opção b; um tema para cada app (P129); a Modificações é uma porta nova ao lado da
  Extensões, a Programas fica no Definir, o Terminal vira cartão, e todo tema de programa («Recebem o tema» e a Loja do
  Spotify) sai da Programas para a Modificações (P130). Decidido pelo coordenador: a Modificações mostra só os apps
  instalados; `/usr/share/themes` também sai do override global (o Flatpak recusa montar `/usr`); a issue no Clapper
  pedindo o runtime novo fica para ela decidir.
- 27/10 15:58, segundo vazamento do `ZDOTDIR`: o `fix_vizinhos` de um teste cortou 21 trechos da Aurora real
  (`~/.config/zsh` e `/usr/local/sbin/ritual-aurora-self-heal.sh`). Restaurado às 20:40 por `scripts/vizinhos.sh
  --restaurar` (cópias de antes em `~/.local/state/meowsystem/backups/zsh-antes-restauro-2026-10-27`), tudo menos o
  que o bloco do terminal do meow já faz (`spellbook-terminal-*`, `aurora-fastfetch-*`, `aurora-completion-meow`). O
  `/usr/local/sbin` recebeu a cópia restaurada. Cura: bce27b9c (o `vizinhos.sh` só corta `ZDOTDIR` dentro do HOME).
  No fecho, o doctor com o código novo corta de novo, já com as trocas no ar.
- Pendências do Aurora para o fecho: o `/usr/bin/cosmic-comp` não é o do pacote (md5 85f5b0dd, o dpkg diz 1907a3d0;
  o verbo `cosmic-comp-de-fabrica` da ponte nova devolve); só `Meow` e `OS` estão alfinetados no disco (o `III` não,
  e o `Meow` tem a folga U+2007 do `AREAS_FOLGA`); o `fix_autoreparo` instala as unidades com `AUTO_REPARO` diferente
  de sim (defeito antigo, anotado); o CLAUDE.md global ainda cita o `aurora-cosmic-workspaces.py`.
- Anotado para depois (27/10): P126, o Vencord no Discord oficial pelo meow (hoje injetado à mão pelo coordenador).
- Anotado para depois (vindo do bloco Textos): saídas que ainda citam comando sem mandar digitar (`cursor.sh:188-191` e `:390`,
  `construir_icones.sh:182`, `forma.sh:94,129`, `janelas.sh:182`, `relogio.sh:105`, `pack.py`) viram uma sprint própria;
  depois do merge no `dev`, confirmar o commit «docs(readme): regerado do código» (a captura `tema.png` ainda diz «Vestir»).
- Anotado para depois (vindo da conferência do Painel): `docs/PACKS.md` sem os campos `icones.sistema` e
  `icones.bandeja` (entra na P118); `restaurar.sh sistema_limpar` vermelho já no `dev` (o `.deb` do cosmic-comp em
  `~/.local/share/meowsystem/debs` muda sem «Restaurar»; entra na P125, junto do resto do compositor); numa casa sem
  rede o doctor regrava a cada passada as tentativas de compilar, o `pendencias.tsv` e a semeadura do papel de parede
  (quebra a segunda passada sem escrita; entra na P124, que mexe no doctor).

## Pedido de quem usa (27/10), lista fechada desta leva
Fotos em `fotos/1.png` a `fotos/5.png`.
1. Tema (foto 1): Dracula e MeowSystem mostram os mesmos ícones na prévia (pastas e dock iguais).
2. Personalizar > Ícones > Biblioteca (foto 2): ícones num preto transparente, ilegíveis.
3. Os dois theme packs equiparados em tudo; o Dracula tem que chegar ao nível do MeowSystem.
4. Aba «Mandar» vira «Disponibilizar». «Vestir agora» vira «Aplicar tema».
5. Definir > Programas (foto 3): o campo «Procurar um programa» é estreito demais (a lista abre larga,
   o campo não).
6. Toda a interface: trocar termos como «vestir» por palavras do dia a dia (arrumar, pôr, ver, aplicar).
7. Gerador de ícone (foto 4): o trilho preenchido dos sliders fica parado em ~50% e não acompanha a
   bolinha.
8. Gerador de ícone (foto 5): a moldura sai em quatro cantos soltos, não dá para fechar a borda do
   retângulo. O gerador em si precisa melhorar.
9. Análise: o gerador de temas é completo e dinâmico para um designer usar? Erros, QoL, integração
   que passou, o repo local.
10. Extensões: concluída? Todos os applets e mods gráficos são os nossos (forks `meowsystem-*`),
    inclusive o que hoje vinha de terceiros (Eyedropper, Clipboard Manager, Drives, ASCII-dot-battery).
11. Extensões é a central de gerenciamento: applets e builds (compositor, menu do Arquivos) no mesmo
    lugar, no mesmo método, com o mesmo propósito.
12. A pasta local reflete a infra enxuta (poucas pastas)? Hoje não: 44 entradas não rastreadas
    (`src/applets/` 1,5 GB, `assets/icones/upstream`, `assets/papeis-de-parede`, zip, `.playwright-mcp`).
13. Instalar as extensões e builds novas pelo MeowSystem, do zero, na máquina.

## Respostas de quem usa (27/10)
- Builds: desinstalar tudo, inclusive o compositor, para o MeowSystem refazer do zero.
- Terceiros sem versão nossa: viram fork nosso (`vitoriamariadb/meowsystem-*`), com tema do pack e pino
  em `assets/extensoes/`.
- Centralizar no MeowSystem: o que hoje mora em outros repos (Aurora) e faz o papel do MeowSystem sai de lá
  e passa a ser daqui. Começa pelo compositor e pela luz noturna.
- Eu (o coordenador) decido por ela e registro aqui; `sudo` por askpass (`sudo -A`).
- «Unificar»: a aba Extensões unifica applets e builds, que seguem o mesmo propósito no programa; é a
  central de gerenciamento.

## Decisões do coordenador (27/10), pelas perguntas dos levantamentos
- Moldura do gerador (P115): sempre fechada, sem botão «com / sem».
- Bandeja e status no Dracula (P117): medir a camada-base `dracula-icons` contra o `sistema.map`; cobre → ela
  cuida (A); não cobre → molde do MeowSystem pintado com a paleta Dracula (B). O agente decide pela medida.
- Botão do cartão do Tema e do Personalizar: «Aplicar tema» nos dois (P118).
- `.git/hooks`: apagar as 13 cópias `.bak-*` e `.antes-*`, ficam os `.sample` (P119).
- Luz noturna = Modo de leitura (pergunta dela, 27/10): uma só, a do applet `meowsystem-leitura` + o patch
  `cosmic-comp-modo-leitura.patch` (temperatura, agendamento, textura). A da Aurora (`aurora-night-light.py`,
  shader injetado no binário) sai inteira. Anotado para depois: o vigia da issue pop-os/cosmic-comp#2059
  (`aurora-cosmic-nightlight-watch.sh`) passa ao MeowSystem, para o Modo de leitura trocar pelo nativo quando sair.
- Centralizar a Aurora (pedido dela, 27/10): «migrar pro meowsystem e desabilitar onde mais tiver, pensando numa
  solução que possa ser usada em outros pcs». O que é desktop COSMIC genérico sai da Aurora e vira do MeowSystem
  (desligado na Aurora por item do `vizinhos.tsv`); o pessoal da máquina fica. Levantamento em voo (1 agente) →
  `relatorios/levantamento-aurora.md` e P124; implementa numa rodada depois da Central (mexe no `vizinhos.tsv`).
- Compositor e luz noturna: do MeowSystem (sim dela). P121 corta da Aurora o bloco do `--ensure` e, quando o
  modo de leitura da casa estiver no ar, a injeção do `aurora-night-light.py` (segundo item de vizinho).
- Applets que o doctor instala sozinho: os cinco da casa e os quatro forks, `PADRAO=sim`, com o selo de rede da
  decisão 50.
- Forks (conferência, 27/10): app id da bateria `io.github.meowsystem.AsciiBattery` fica; ordem dos cartões 6 a 9 fica.
  O wl-clip-persist e o corte da poda no `aurora-clipboard` são da P125.
- Papéis de parede: `assets/papeis-de-parede` vai inteiro para `~/.local/share/backgrounds/meowsystem`, o doctor
  aponta o fundo para lá; nenhuma imagem é apagada (P123).
- Painel depois do «Trocar»: botão «Reiniciar o painel» no aviso; nunca reinicia sozinho.
- Forks: `meowsystem-eyedropper`, `meowsystem-clipboard`, `meowsystem-drives`, `meowsystem-ascii-battery`. O agente
  cria o repo em `vitoriamariadb` com `gh` (fork do upstream) e faz push, como os cinco da casa na leva anterior.
- Limpeza da pasta (P123): o sim é meu. Cache e build vão embora; registro vai para a branch `arquivo`; o que é
  dela (imagens) só se move.

- Aurora (levantamento-aurora.md, 27/10), decidido pelo coordenador:
  - D11: quem corta é o doctor (`fix_vizinhos`, P124), chave `VIZINHOS_DESATIVAR` para desligar; item que ela
    restaurar não volta a ser cortado. Sem isso nenhum item do `vizinhos.tsv`, nem o da P121, vale.
  - D1 alfinetes: A (P125), o doctor confere e refaz o alfinete. O coordenador atualiza o CLAUDE.md global depois.
  - D2 clipboard: A, a poda vai para o fork `meowsystem-clipboard` (P122); o corte na Aurora entra na P125.
  - D3 applet da bandeja inserido pelo script do qBittorrent: cortar na P125 (depois da P120).
  - D10 o resto da instalação do compositor na Aurora (self-heal ~1331-1411, install ~1915-1916): P125 assume.
  - D4 a D9: ficam na Aurora (C). O handler de MIME da Aurora reescreve 49 vezes (`eog`, `thunderbird` ausentes):
    defeito da Aurora, anotado para ela, fora deste repo.
  - `scripts/painel.sh` manda digitar «meow painel reciclar»: entra na P119 (nenhuma saída manda digitar).

## Blocos
| rodada | bloco | sprints | worktree / branch | agentes |
|---|---|---|---|---|
| 1 | Painel | P115 → P116 → P117 | `~/Desenvolvimento/MeowSystem-painel`, `bloco/painel` | implementa (Sonnet high), confere e corrige (Opus high), final (Opus high) |
| 1 | Central | P120 → P121 | `~/Desenvolvimento/MeowSystem-central`, `bloco/central` | implementa (Opus high), confere e corrige (Opus high), final (Opus high) |
| 2 | Forks | P122 | `~/Desenvolvimento/MeowSystem-forks`, `bloco/forks` | implementa, confere |
| 2 | Textos | P119 → P118 | `~/Desenvolvimento/MeowSystem-textos`, `bloco/textos` | implementa, confere, final |
| 3 | Aurora | P124 → P125 | `~/Desenvolvimento/MeowSystem-aurora`, `bloco/aurora` | implementa, confere, final |
| 3 | Pasta | P123 | `~/Desenvolvimento/MeowSystem-pasta`, `bloco/pasta` | script + confere |
| 5 | Flatpak | P127 → P128 → P129 | `~/Desenvolvimento/MeowSystem-flatpak`, `bloco/flatpak` | implementa (Sonnet high), confere e corrige (Opus high), final (Opus high) |
| 5b | Modificações | P130, junto com o Flatpak (ela, 27/10) | `~/Desenvolvimento/MeowSystem-modificacoes`, `bloco/modificacoes` | implementa (Opus high), confere e corrige (Opus high), final (Opus high) |
| 6 | Ícones do sistema | P131, junto com os outros dois (ela, 27/10) | `~/Desenvolvimento/MeowSystem-icones-sistema`, `bloco/icones-sistema` | implementa (Opus high), confere e corrige (Opus high), final (Opus high) |
| 4 | Máquina | instalar do zero pelo MeowSystem, na máquina dela | checkout principal | coordenador |
Os dois blocos da rodada 1 só dividem `app/servidor.py`, em funções diferentes (P116 `_cartoes_de_pack`; P120 o
bloco `EXT_*` e as tabelas de pendência). P119 mexe nas mesmas tabelas da P120, por isso vai na rodada 2.
Integração por bloco em `integracao/central-e-gerador`; o `dev` só recebe no fim.

# Leva central e gerador (27/10/2026) — andamento

## Agora
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
  ascii-battery}` na main, nada instalado ainda).
- EM VOO, a partir da integração (ela pediu os blocos juntos, 27/10):
  Aurora (`wf_32a9b69a-21d`, P124 → P125), Textos (`wf_af23fd58-b64`, P119 → P118), Pasta (`wf_064bfaa6-0dc`, P123).
  Worktrees `~/Desenvolvimento/MeowSystem-<bloco>`, branches `bloco/<bloco>`.
- Próximo passo: integrar cada um assim que voltar; o coordenador roda `scripts/enxugar.sh --aplicar` no checkout
  principal depois que tudo chegar ao `dev`; por fim instalar do zero na máquina.
- 27/10 17:46: um teste da suíte (o desinstalar da casa de brinquedo) tirou o bloco do MeowSystem do `.zshrc` real, pelo
  `ZDOTDIR` herdado. Bloco devolvido às 17:56 (cópia em `~/.local/state/meowsystem/backups/zshrc-antes-2026-10-27-1756`);
  cura na integração (65d53c56, 8c946886). As suítes de Aurora, Textos e Pasta começaram antes da cura: depois de cada
  uma voltar, conferir `tail -3 ~/.config/zsh/.zshrc` e rodar `scripts/terminal_bloco.sh aplicar` se faltar.
- Anotado para depois (27/10): P126, o Vencord no Discord oficial pelo meow (hoje injetado à mão pelo coordenador).
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
| 4 | Máquina | instalar do zero pelo MeowSystem, na máquina dela | checkout principal | coordenador |
Os dois blocos da rodada 1 só dividem `app/servidor.py`, em funções diferentes (P116 `_cartoes_de_pack`; P120 o
bloco `EXT_*` e as tabelas de pendência). P119 mexe nas mesmas tabelas da P120, por isso vai na rodada 2.
Integração por bloco em `integracao/central-e-gerador`; o `dev` só recebe no fim.

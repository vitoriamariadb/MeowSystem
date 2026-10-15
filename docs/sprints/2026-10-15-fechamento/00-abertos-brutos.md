
===== 03-integracao-onda-1.md :: ## Aberto, com dono
1. **O gate barra o dev: o «Consertar» baixa sem declarar rede.** Dono: **decisão de quem usa**,
   depois P77 ou a próxima leva.
   - A P75 tirou `upstream` e `fontes` do `SEM_CONSERTO` (o doctor corrige, e o que baixa é
     pinado). A P76 tirou `midiabin` e `leiturabin` (rebuild sem sudo).
   - Agora o `doctor --consertar` clona o papirus-folders e o now-playing, baixa a fonte e o
     `Cargo.lock` do painel e roda `cargo build`. A ação `doctor_consertar` do painel continua
     com `rede: False`.
   - Declarar `rede: True` (a verdade) acende a regra do gate da P46: ação que baixa não roda sem
     caixa de pergunta. Isso põe uma pergunta no botão de consertar, e o princípio da P75 diz que
     o doctor corrige sem perguntar.
   - As duas regras são dela. Não escolhi entre elas, e não pus a frase em «defeitos conhecidos»
     do gate, porque seria contorno.
2. **A segurança da P73 não chegou à branch.** Dono: **a varredura de segurança** do `ESTADO.md`
   do dev, o próximo passo 2.
   - A seção «Segurança» foi acrescentada à spec da P73 no dev às 18:40, depois de a worktree
     nascer, e o conferente não a viu. Ela pede:
     - `realpath` e recusa de symlink no acervo da ficha;
     - CSP com `sandbox` e `nosniff` em todo SVG ou PNG de acervo, com teste de SVG com `<script>`.
   - Não conferi esses itens aqui. A P74 tratou os dela.
3. **O dev vai conflitar ao receber a integração** nas specs P73 e P74, porque o dev acrescentou
   a seção «Segurança» nas duas. Dono: **quem fizer o merge no dev**. São só documentos: fica a
   seção do dev mais a conferência da branch.
4. **Sem teste para o `ICONES_DRACULA` ausente no passo do pack.** O `10a139f` foi provado com um
   script de rodada, não com um teste. Dono: **próxima leva**.
5. **O `portabilidade.sh` vermelho pelo `cosmic-vivo.md:198`** e o **`doctor-so-le.sh` que
   depende do HOME da sessão.** Dono: **próxima leva**. Os dois já vinham do dev.

Os achados de cada bloco continuam nas specs, em «Achados para a próxima leva». A P75 traz o
runner que só falsifica sudo. A P74 traz os gatos com cor do Catppuccin e os 24 ícones do COSMIC
Ajustes, as duas decisões dela. A P73 traz o Waterfox sem marca e a raposa resgatada. A P76 traz
o coredump e o `meow-doctor.service` sem `~/.cargo/bin`.

===== 04-integracao-onda-2.md :: ## Aberto, com dono
1. **O VS Code instala a extensão que o pack nomeia** (P78, gravidade alta). Dono: **decisão de
   quem usa**. O sha256 vem do próprio pack: prova integridade, não confiança. Um pack de terceiro
   escolhe código que roda a cada abertura do editor. As opções:
   - só pack do motor instala extensão;
   - uma lista fechada de publicadores;
   - a pergunta da P46.
2. **O nome do «Restaurar ao padrão»** nas chaves com padrão de fábrica preenchido
   (`RELOGIO_SEGUNDOS`, «Janelas lado a lado», `LEITURA_AGENDA`). Fora do padrão, o botão grava
   vazio («não toca») e mostra o valor da máquina no parêntese. Dono: **decisão de produto**, e
   depois a próxima leva. As saídas possíveis:
   - dois gestos com dois nomes;
   - o botão grava `item.padrao`.
3. **Casa real** (achados do QA da P77). Dono: **doctor / próxima leva**, com decisão de pack
   no primeiro item.
   - `ICONES_FLAVOR="macchiato"` com o Dracula no ar.
   - Trocar de pack deixa `CURSOR` e `ICONES_PASTAS` no Dracula.
   - O `CosmicBackground` aponta para uma pasta, e o doctor não acusa.
4. **Saídas que ainda mandam digitar** (`pkill`, `sudo -v && ./install.sh`,
   `meow files-menu build`) e a caixa do sudo com parágrafo de 4 linhas. Dono: **próxima leva**.
   O texto da caixa é decisão de quem usa.
5. **Achados técnicos.** Dono: **próxima leva**. Estão listados nas specs: P78 e P77, em
   «Achados para a próxima leva».
   - Mapa CRLF perde as linhas.
   - O `_proibido` não vê o BOM antes do `#!`.
   - O `vidro_janela.py` ignora o `MEOW_COSMIC_DIR`.
   - O `LOGO_MODO=""` deixa a moldura do gato vazia.
   - O «Créditos» do gate é intermitente.
   - Não há gesto de favoritar papel de parede.
6. **Restos fora desta integração.** Dono: **quem usa**.
   - O painel PID 1985165, do checkout principal, que é de 09/10 e não foi derrubado.
   - O arquivo `mktemp` que um teste da trava da P78 deixou em `/tmp`.
7. **O dev vai conflitar** nas specs P73/P74 (onda 1, item 3), se o dev ainda não recebeu a
   onda 1. Dono: **quem fizer o merge no dev**.

===== 04-integracao-onda-2.md :: ### Aberto, com dono
1. **A corrida do `Trabalho.vivo()`** deixa o gate intermitente: «saiu null · 0s» numa ação
   rápida. Dono: **próxima leva**. A cura na origem é o `vivo()` responder pelo desfecho
   gravado (`self.fim is None`), e não pelo `poll()`. Para provar, monte no
   `app-navegador.py` uma pergunta entre o fim do processo e o `rc`.
2. **O gate falhou uma vez na corrida do conferente e passou em seguida.** Foram três ações
   do «⋯» de Lançadores e jogos, com «nunca apareceu». Pode ser a mesma família de corrida, e
   não está provado. Dono: **próxima leva**.
3. **Ainda há linhas mandando digitar.** Dono: **próxima leva**.
   - O «resolve: <comando>» de toda pendência.
   - O `meow wallpaper permitir`.
   - O «instale com rustup e rode o install.sh de novo» do `leitura_build.sh`.
4. **Uma instalação pode reciclar o painel até três vezes.** O arcticons, o dracula e os
   resgatados chamam o `meow_tela_reler`, cada um. Dono: **próxima leva**.
5. **Trocar do Catppuccin de fábrica para o Dracula muda o ponteiro para `Dracula-Cursor`,**
   que baixa da rede. Segue o «o pack decide» da spec, mas muda o comportamento. Dono:
   **decisão de quem usa**.
6. **O `convergencia.sh` depende do falso do `systemctl`.** Um falso que finge escrever deixa
   o teste vermelho. Os itens da onda 2 não registram como era o falso da rodada verde.
   Dono: **quem escrever o próximo roteiro de suíte**. O falso de escrita tem de recusar
   (rc≠0), como o `sudo`.

Da lista «Aberto» da onda 2, a P79 fecha os itens 2, 3, 4 e 5 e a decisão do item 1. Os itens
6 (restos fora da integração) e 7 (o dev conflitar nas specs P73/P74) continuam como estavam.

===== 05-integracao-p80.md :: ## Aberto, com dono
1. **`obsidian.png` do pack é um SVG com nome de PNG.** O painel já mostra, mas o arquivo continua
   travado como «feito à mão em PNG». Dono: **decisão de quem usa** (renomear para `.svg` no pack,
   que é dado).
2. **A pendência `wallpaper-fonte-revertida` não tem como ser dispensada.** Se a devolução estava
   certa, o cartão fica na Início até alguém clicar «Era escolha minha», e esse clique autorizaria
   a imagem errada. Dono: **decisão de produto**, depois a próxima leva.
3. **Botão aceso sobre trabalho já feito: «Instalar o starship»**, com o starship em
   `~/.cargo/bin`. É a mesma contradição das áreas, só que sem passo seguinte para apontar. Dono:
   **próxima leva**.
4. **Ainda mandam digitar.** Dono: **próxima leva**.
   - o `painel.sh reciclar` («arme o supervisor… systemctl --user start …»);
   - o `construir_icones.sh` («diagnóstico: meow painel estado»);
   - o `midia_build.sh`, o `lib/preflight.sh` e o «veja o motivo com…» do `leitura_build.sh`.
5. **Nomes e textos.** Dono: **próxima leva**; os erros de digitação são **dado do pack**.
   - App sem linha de mapa nem `.desktop` ganha nome genérico: `io.github.shiftey.Desktop` vira
     «Desktop», `com.obsproject.Studio` vira «Studio».
   - 174 de 469 desenhos da biblioteca Dracula não têm descrição no `catalog.json` e mostram o nome
     do arquivo em inglês.
   - Erros de digitação no pack: «Visalizador», «Calendario», «Gerenciador de extensoes».
   - Nomes em inglês que vêm do próprio `.desktop` («Online Accounts», «Mobile Network»).
   - O balão do app diz a origem como «usuária» (`DIRS_DESKTOP`).
6. **A 375 px.** Dono: **próxima leva**.
   - O item da página aberta não rola para a vista no menu horizontal.
   - A prévia fixa no topo cobre parte dos cartões.
   - O «?» da prévia de Manutenção fica por cima do desenho.
   - A `trava_pack` passa do teto do balão e sai cortada (já era assim antes da P80).
7. **Achados técnicos.** Dono: **próxima leva**.
   - `Trabalho.vivo()`: um neto que segure o stdout deixaria o trabalho «vivo» para sempre. Nenhuma
     ação de hoje faz isso.
   - O `assentar` do gate tem a mesma corrida em qualquer gesto cujo pedido nasça depois de um
     salto assíncrono (como o `close` de uma caixa). Curei o caso que ficou vermelho; os outros só
     aparecem se o servidor demorar mais de 3 s.
   - O `app-completo.py` e o `app.sh` deixam resto em `/tmp` a cada rodada (ver «As duas suítes»).
8. **Abertos que vêm da onda 2 e seguem de pé** (`04-integracao-onda-2.md`): a extensão do VS Code
   que o pack nomeia (decisão de quem usa) e o nome do «Restaurar ao padrão» (decisão de produto).
9. **O dev ainda não recebeu nada disto.** Dono: **quem fizer o merge no dev**, de uma vez, no fim.

===== P73-seletor-e-acervo.md :: ## Estado da execução — 09/10/2026 (branch `sprint/p73`)
| tarefa | estado | commit |
|---|---|---|
| T1 — sem teto, sem filtro de abertura, pastas com contagem, pack no ar primeiro | feita | `2137c5e` |
| T2 — todas as pastas, de todos os packs, de um lugar declarado (`pack.py acervos_de_icone`) | feita | `d8e316a` |
| T3 — busca pelo comentário do `apps.map` e pelo `catalog.json` (trazido, com linha no PROCEDENCIA) | feita | `b8db432` |
| T4 — trava é estado visual + dica; o acervo nunca some | feita | `a6fee5f` |
| T5 — 174 SVG de `current/` na biblioteca, 39 PNG em `icones/feitos-a-mao/` | feita | `9cd7550` |
| I3 — a escolha vai para `~/.config/meow/icones-escolhidos.map` e `icones-traco.map`; o pack só pelo «Levar para o pack» | feita, menos a reversão no dev (abaixo) | `3034554` |
| I8 — Discord, Spotify e Syncthing no mapa do Dracula | feita | `fabaf5c` |
| I9 — o lançador veste o `logo.svg` do pack no ar | feita | `0d580aa` |
| Achado 24 — origem vira selo (forma), o porquê vai para a dica | feita | `874a5a7` |
| Prova — `tests/acervo-da-ficha.sh`, `restos-do-painel.sh` refeito | feita | `6883982` |
| T1, conserto achado pelo gate — a tira de pastas sobrevive à repintura (o `/previa` é `no-store`: eram 342 pedidos de miniatura a cada `render()` com a biblioteca aberta, agora 0) | feita | `22935c6` |
| Gate `tests/app-completo.py` adaptado (pastas, desenho travado, escolha no estado da casa e raiz intacta) | feita, verde em 543 s | `7cf9b1c` |

**Testes rodados na branch** (HOME de brinquedo; sudo falso onde o teste sobe o painel):
`acervo-da-ficha`, `seletor-do-pack`, `git-limpo`, `restos-do-painel`, `fonte-unica`,
`pack`, `sem-dracula-os-theme`, `notas-de-funcao`, `numeros`, `orfaos`, `arvore`,
`frases-velhas`, `app`, `estilo`, `app-acessibilidade.py` e `app-completo.py` — todos 0.
`portabilidade.sh` sai 1 por `docs/pesquisas/2026-10-09-cosmic-vivo.md:198` (um `/home/<pessoa>`
escrito), arquivo que veio no `f24868c`, antes desta branch.

**O que não deu para fazer como escrito, e por quê:**

- **«Reverter o ` M packs/dracula/icones/apps.map` do dev».** As regras desta leva
  proíbem tocar o checkout principal (`~/Desenvolvimento/MeowSystem`,
  branch `dev`). A linha suja é a escolha dela (`org.kde.ghostwriter : apps/org.gnome.gitlab.somas.Apostrophe.svg`),
  e reverter sem guardar seria desfazer o que ela decidiu. Fica para a integração, nesta
  ordem: (1) acrescentar ao `~/.config/meow/icones-escolhidos.map` dela a linha
  `org.kde.ghostwriter : packs/dracula/icones/apps/org.gnome.gitlab.somas.Apostrophe.svg   # ghostwriter — escolhido no painel`;
  (2) `git -C ~/Desenvolvimento/MeowSystem checkout -- packs/dracula/icones/apps.map`;
  (3) rodar o passo do pack (`scripts/icones_apps_dracula.sh aplicar`). O `.gitignore` do
  dev também está ` M`, e esta branch muda o `.gitignore` (a exceção dos PNG): conferir o
  merge dessas duas mudanças.
- **T5, «faltam 0».** Dos 175, entraram 174: o `calcdeirao.svg` fica fora pela decisão 4.
  Três entraram sem o atributo `inkscape:export-filename` (guardava `/home/<nome>/`, que o
  `validar` recusa), então o sha256 da cópia difere do da origem; a linha do PROCEDENCIA
  guarda os dois. Dos PNG, 13 dos 30 do tema antigo têm os mesmos bytes de
  `src/icons/projects/` (projetos pessoais) e ficaram fora pela mesma regra de 23/09.
- **T5, PNG escolhíveis.** Os 39 PNG aparecem na ficha, apagados, com a dica: raster não é
  fonte (`meow_icones_derivados`), e a decisão 2 manda vetorizar num lote por RMSE. O lote
  não foi feito aqui.

===== P73-seletor-e-acervo.md :: ## Achados para a próxima leva
- O lote de vetorização dos 39 PNG de `packs/dracula/icones/feitos-a-mao/` (decisão 2): até
  ele, nenhum dos 39 entra no tema.
- Os 39 PNG pesam 41 MB (o `clapper.png` sozinho, 7,8 MB) e viajam no `.meowpack` do
  Dracula; o teto de envio do painel é 64 MB. Medir o `exportar` depois da P74.
- «Adicionar ícone» (`/api/acervo`, tipo `icone`) grava em `assets/icones/overrides/`, dentro
  do clone, e essa pasta não está em nenhuma pasta da ficha: o desenho enviado nem aparece
  para ser escolhido. Mesma dívida da P21.
- A oficina de desenho («Usar» da oficina) ainda grava `apps-convertidos.map` e
  `convertidos-apps/retoques/` no clone (o `tests/git-limpo.sh` lista como pendente).
- A prévia flutuante da página Ícones (achado 6) aparece por cima da grade nos prints desta
  sprint — é da P77.
- `scripts/icones_apps_dracula.sh`: o comentário «O PADRÃO É `nao`» do `_dracula_aplicar` vai
  envelhecer com a T6 da P74.
- (conferência) A nota «O desenho de «…» entra com as cores dele: a cor abaixo vale só para o
  traço» era da P60 e só aparecia com desenho de pack. Agora aparece com qualquer desenho
  marcado, e é frase na tela. O princípio pede estado visual, por exemplo apagar a fileira de
  cores quando um desenho está marcado.
  [Resolvido no QA de uso, 72d9bf3: a fileira se apaga e a frase foi para a dica dela.]
- (conferência) Abrir a pasta «feitos à mão (PNG)» baixa os 39 PNG inteiros, 41 MB, como
  miniatura, e o `/previa` responde `no-store`. Uma miniatura reduzida resolve.
- (conferência) Os desenhos de 4 mimetypes e de 6 pastas coloridas da leva da T5 estão na
  `biblioteca/` e aparecem na ficha como ícone de app. Os de `pastas/` e os `mimetypes/` ficam
  de fora.
- (conferência) No `app/pagina/app.js`, o `const comBusca = true` da T4 sobrou como constante
  morta, sem efeito.
- (QA de uso) O «Usar este ícone» com desenho roda o «Pôr os desenhos do pack na tela» na hora
  (desde a P60): escreve em `~/.local/share/icons/MeowSystem-Icons/scalable/apps` e reindexa a
  cache. Quem testa o painel com o HOME real escreve no tema da máquina ao escolher um ícone;
  o QA desta leva escreveu três arquivos assim e os tirou (ver o relatório). Teste de uso do
  seletor só com HOME temporário.
- (QA de uso) A ficha marca a escolha dela (7602ec3) e o traço vestido, mas não o desenho do
  pack que o app já veste sem escolha (o Waterfox abre com o `net.waterfox.waterfox` do pack
  sem marca). Falta o servidor dizer qual arquivo veste o app.
- (QA de uso) A busca «firefox» não acha a raposa roxa resgatada
  (`resgatados/net.waterfox.waterfox.svg`): a linha do Waterfox saiu do `apps-resgatados.map`
  na P28, e com ela o nome que a busca casaria.
- (QA de uso) O Discord resgatado (`apps/com.discordapp.Discord.svg`) é roxo-escuro sobre o
  fundo escuro da ficha e quase some na miniatura; é da arte, não do seletor.

===== P74-pack-dracula-completo.md :: ## Estado da execução — 09/10/2026
Branch `sprint/p74`, a partir do `f24868c`. Um commit por tarefa (o item 9 tem
um por subitem; o item 7 tem dois). Toda prova abaixo rodou numa casa de
brinquedo, com `sudo`, `apt`, `systemctl`, `pkill` e companhia falsos no PATH
(o registro deles ficou vazio de `sudo`/`apt`).

| item | estado | commit | prova curta |
|---|---|---|---|
| 1 (I1/I2) | feito | `da6cb3c` | `pack.py base-apelidos`: com `ICONES_BASE="MeowSystem-Icons-Base"` as pastas e o apelido do repoman copiam do Papirus-Dark; antes, «não está instalado — pastas coloridas puladas». `tests/pastas-do-pack.sh` seção 11: 2 falhas antes, 0 depois. |
| 2 (T10, decisão 1) | feito | `13929d4` | `icones.base.por_tras` (o `main` do m4thewz, `de2a8edd`, sha256 `51db7832…`, baixado duas vezes igual) em `<tema>-Base-2`. Simbólicos do `Dracula-Icones` antigo fora de tema+base: 458 antes, **0** depois. |
| 3 (T6) | feito | `c0b89b0` | `ICONES_DRACULA` de fábrica passou a `"sim"` (o padrão vem do pack; `nao` desliga). Conf sem a linha, Dracula no ar: 229 ícones em `scalable/apps` (eram 28). O 230 da auditoria contava a linha não versionada do `ghostwriter` no `apps.map` do dev (I3). |
| 5 (T8) | feito | `71c95ea` | Feito antes do 4, porque o 4 o usa. `construir_icones.sh indice` e a etapa `icones_indice` (install.sh, depois da dos gatos; `indice` no fim do doctor). Uma passada: `validar_index.py` → `com_arte_nao_declarados=0` (eram 4); a 2ª passada não escreve. O laço de 5 do install.sh continua para as outras etapas (fontes), mas os ícones não dependem mais dele. README/SPRINTS: 61 etapas, 64 conferências. |
| 4 (T7) | feito | `24e2b3b` | `meow pack exportar-tema <id> [flavor] [arquivo]` (`scripts/exportar_tema.sh`): `MeowSystem-Dracula-Icons.tar.gz` com o tema e as duas bases; instalado num HOME limpo: cache reconstruída nos três, 0 links para fora, 0 quebrados, 229 em `scalable/apps`, `grep -c Catppuccin index.theme` → 0, `Inherits` só do que vai junto + `hicolor`, simbólicos do tema antigo fora → 0. `Comment=` do índice local também é o do pack. |
| 6 (T9 + I7) | feito | `ea2b565` | `meow pack construir dracula` deriva do `css-variables` do Catppuccin pela paleta do Dracula (a mesma conta dá o `mocha/` byte a byte): `info` → `icones.mimetypes PRÓPRIO 1.312` (656 × 2 flavors); 0 dos 1.312 com cor do macchiato. `folder`, `user-home` e `user-desktop` desenhados na silhueta das sete, com mapa próprio do pack; o `construir_pastas.sh` cede pelo mesmo mapa. |
| 7 (T1) | feito | `f49c592`, `3c6dedf` | starship com `palette = 'dracula_<flavor>'` e os 26 slots do pack (com o Catppuccin Mocha, o preset de antes); mimetypes «vestidos de Dracula dracula»; quatro `or "mocha"` do servidor caem no padrão do pack; legendas da aba Terminal sem Catppuccin; `info` sem «herdado de catppuccin» (mapa do COSMIC e fontes são do motor). |
| 8 (T2) | feito | `22670bf` | Filtro de git (`filtro_git.py`, só no `.git/config` e `.git/info/attributes` do cofre): o disco tem o tema desta máquina, o commit guarda o do cofre, `git status` limpo, `git checkout` do arquivo devolve o tema daqui, 2ª passada 0, o desfazer tira o filtro. Mapeia o caminho do portal (`/run/user/…/doc/…`) para a origem (`flatpak documents`): no cofre real, o `conferir` acha `/home/…/Controle de Bordo` e diz que falta o filtro — nada foi escrito nele. |
| 9 · T3 sons | feito | `a7da6df` | Os 25 `.oga` (Kenney, CC0) em `packs/dracula/sons/`; o `som.sh` os instala em `~/.local/share/sounds/MeowSystem-Sons` e o `meow-som.service` (`som.sh vigiar`) toca o de notificação a cada `Notify`, calando no `suppress-sound`. 25 instalados, 2ª passada 0, sai com o Catppuccin. O sino de volume não mudou. |
| 9 · T4 qBittorrent | feito | `b611286` | Sem o script do Aurora o módulo escreve as duas chaves do conf (com o app fechado). O pack traz o `dracula.qbtheme` oficial (dracula/qbittorrent `9020f6eb`, MIT). `*.qbtheme` virou `byte-exact` no `.gitattributes`: o auto-fix do pre-commit tinha posto um `\n` no binário. |
| 9 · T5 overrides | feito | `ef72c9c` | `lancador.ocultar` no pack (24 dos 27 que escondiam; `mnemo`, `elden-ring-tracker` e `Ubuntu` são só daquela máquina). Soma à lista do conf; `-nome` no conf tira um. |
| 9 · T6 Vesktop | feito | `88530a5` | O tema entra em `enabledThemes` do `settings/settings.json` do Vencord/Vesktop (só essa chave muda; com o cliente aberto, espera). O BetterDiscord segue pedindo o clique. |
| 9 · T7 papéis | feito | `b3c0f24` | Os 13 SVG do tulip-orchid em `packs/dracula/wallpapers/`; numa casa nova, sem repositório no conf, o Dracula semeia os 8 não recusados em PNG 3840×2160 (RMSE 0 contra o PNG da máquina), sem nada do Catppuccin. |
| 10 (I10) | feito | `412ff75` | `meow_flavor_vestido`: com `MODO="claro"` o traço do dock sai da paleta do Alucard (108 de 108 cores) e as pastas em `cat-alucard-mauve` (derivada do Latte). |

Dois commits de acerto, depois da suíte: `86f1458` (variáveis internas que o
`tests/app.sh` lia como chave do conf; o `pack.py novo` copiava o `som.tema`) e
`6445237` (sem `MODO` no ambiente, o lado vestido é o FLAVOR — o
`tests/pastas-do-pack.sh` roda os flavors claros sem conf).

===== P74-pack-dracula-completo.md :: ## Achados para a próxima leva
- `icones_apps_arcticons.sh` sai 3 depois de escrever, fora da sessão gráfica: o `meow_tela_reler` devolve 3 sob `set -e`. O `exportar-tema` o lista entre os «sem dependência».
- Conf antigo com `ICONES_DRACULA="nao"` (o de fábrica de antes) não se distingue de um «não» à mão; o `migrar_conf.py` (P75) pode tratá-lo.
- O desinstalador ainda não leva `<tema>-Base` nem `<tema>-Base-2` (pendência antiga do `construir_icones.sh`).
- O tema instalado continua `MeowSystem-Icons`; só o exportado leva o nome do pack. Unificar é decisão.
- Duas regras do «lado vestido»: o `_flavor_no_modo` do painel (o primeiro claro) e o `meow_flavor_vestido` (o par do outro lado). Concordam nos casos de hoje.
- O tocador de som cobre só a notificação; dispositivo, bloqueio de tela e captura de tela não têm gatilho ligado.
- O cabeçalho de `assets/prompt/starship.toml` ainda diz «só o flavor mocha»: o arquivo instalado já troca a paleta.
- (conferência) Trocar de pack não devolve ao lançador os 24 que o Dracula esconde: o `ocultar_apps.sh` nunca desfaz uma marca que saiu da lista (o mesmo vale para a lista do conf); hoje só o `-nome` e o `meow desfazer --lancador` devolvem.
- (conferência) Há 37 `python3 -` sem `-I` no código de produto fora do que a P74 escreveu (`git grep -c 'python3 - ' -- '*.sh' bin/meow ':!tests/'`): todos importam do diretório corrente. É a varredura de segurança da integração (o quinto alerta, `bin/meow`).
- (conferência) O `meow_flavor` ainda devolve o `flavor_padrao` do pack sem conferir a forma do nome; a P74 só fechou o `meow_flavor_vestido`.
- (conferência) O `icones_pastas.sh` lê o `pastas.map` novo do Dracula e não foi tocado pela P74: os nomes dele viram arquivo no tema sem a régua `[A-Za-z0-9._+-]`.
- (conferência) O `icones_apps.sh` (camada de aplicativos do Catppuccin) aproxima o Dracula para o `macchiato` do Catppuccin; hoje não pesa porque o acervo `assets/icones/catppuccin-apps` não existe, mas com ele no disco o Dracula vestiria Catppuccin.
- (conferência) As bases exportadas aparecem nos seletores de tema com o `Name=` do upstream («Dracula Circle» e «Dracula»), ao lado do tema exportado.
- (QA) Os gatos `coquinha` e `mimir` (`assets/gatos/`, desenho dela) têm o arco em seis hex do macchiato (`#c6a0f6 #7dc4e4 #a6da95 #eed49f #f5a97f #ed8796`); com o Dracula no ar eles vão para `scalable/apps/com.system76.CosmicAppLibrary.svg`, `CosmicPanelAppButton.svg` e `~/.config/cosmic/logos/`. Repintar o arco pela paleta do pack mexe na arte dela: é decisão (liga com a I9, «um svg pra cada logo do theme pack»).
- (QA) O tema exportado não herda `Cosmic`/`Adwaita` (o T7 pede só o que vai junto): numa casa limpa, os 24 `preferences-*` do COSMIC Ajustes que a instalação local tira do `Cosmic` ficam sem desenho na cadeia exportada. Herdar um tema que não viaja é inofensivo quando ele falta; a regra do T7 é decisão.
- (QA) Dos 577 nomes de app do `Dracula-Icones` antigo, 52 não resolvem na cadeia nova: 25 `org.kde.krita.*` (tipos do Krita), 9 `Ubuntu-*` e `citrix` (Citrix Workspace, 9 deles pedidos por `.desktop` desta máquina), `edge`, `files`, `gnome-extensions`, `gradia`, `hplj1020`, 3 `ibus-setup-*`, `io.snapcraft.SessionAgent`, `universal-android-debloater`, `whatsapp-linux-app_whatsapp-linux-app`, `zapzap`, `com.visualstudio.code-url-handler`, e os pessoais (`mnemo`, `io.github.andrebfarias.Mnemo`, `neurosonancy`, `nyx`, `ouroboros`), que a decisão de 23/09 deixa de fora. Eram PNG do `current/`.
- (QA) `dev.vencord.Vesktop` (o `Icon=` do Vesktop desta máquina) não tem desenho nem no pack nem nas bases (nem tinha no tema antigo); cai no ícone do próprio flatpak.
- (QA) As bases do upstream declaram `32/actions`, que não existe, e não declaram `16/emblems` nem `24/emblems` (85 emblemas a 16 px fora do índice). É do upstream, copiado como veio.
- (QA) A spec pede 230+ apps e saem 229: o 230 da pesquisa contava o `org.kde.ghostwriter.svg`, órfão de uma passada antiga (no HOME real ele é de 26/09); o `ghostwriter` hoje vem em traço pelo `48x48/apps`.
- (QA) Na folha de contato, o `firefox` do tema é o traço do Arcticons em `blue` (o `apps-marca.map:151` já anota que devia ser `peach`), apagado ao lado dos círculos da base.

===== P75-doctor-corrige.md :: ## Estado da execução (09/10/2026, branch `sprint/p75`)
| # | estado | commit | prova curta |
|---|---|---|---|
| 1 D1 | feito | `25d2f1a` | ponte root ganhou o verbo `pacotes` (lista literal, igual à do `etapa_pacotes`, cobrada no teste); `pacotes`, `upstream`, `fontes`, `cursor` e `cli` saíram do `SEM_CONSERTO`; o 3 se confere de novo antes de ser pulado; o `--consertar` termina pelo DEPOIS (o que continua fora é nomeado e sai 2); o pulado que avisou (`!!`) pesa no veredito. `tests/doctor-veredito.sh` verde; numa casa temporária, `pacotes upstream icones completar pastas`: 1ª passada instala base e upstream, conserta `completar` e `pastas`, e termina VERMELHA nomeando `icones` (ver nota); 2ª passada `consertado`, rc=1; doctor seguinte `nada a consertar`, rc=0. `grep -ciE 'apt(-get)? install\|instale com'` na saída do doctor: 0. |
| 2 D2 | feito | `c276080` | `tema_ativo` pergunta o alvo primeiro: no `meow status` desta máquina (só leitura, sudo falso) `ativo alucard-mauve (o alvo é dracula-mauve)` virou `ativo dracula-mauve`; a lista «Divergências» usa a régua do veredito (`fora_do_lugar`) — pulado de rotina e escolha (4) saem dela. |
| 3 achados 3, 4, 5 | feito | `8b55fc8` | `files_menu`, `resgatados`, `escala`, `fontes` e `janelas` têm primeira linha inteira; a linha do pulado que avisou é a do aviso. Teste: nenhuma linha da tabela vazia ou terminada em `:`. A contradição do achado 4 some com o conf migrado (item 5): `icones ok … confere`, `pastas ok`, sem «não está instalada». |
| 4 D3 | feito | `2733c4b` | a passada do doctor não chama `pack.py sincronizar`; `tests/sem-dracula-os-theme.sh` agora cobra a ausência. |
| 5 chaves aposentadas | feito | `18c1d88`, `1098fb5` | `APOSENTADAS = {ICONES_BASE}` no `migrar_conf.py`; cópia do conf real: só a linha ativa `:1841` sai, o comentário de 24/09 fica; com o exemplo velho (com a chave) ela não volta. O doctor migra (`chk_conf`/`fix_conf`) — `tests/chaves-aposentadas.sh` verde. A chave saiu do exemplo; o servidor segue respondendo a base do pack sem o cartão. |
| 6 testes | feito, com uma ressalva | `af2686b` | `sem-receita-no-log.sh` sem as isenções do Papirus (e das outras seis frases que saíram; sobra a do `lib/preflight.sh`, que fala antes de existir ponte); `git-limpo.sh` §4 sobe o painel sobre o repositório real e o pega gravando ` M packs/dracula/icones/apps.map` (I3) — VERMELHO até a P73 item 6 entrar, de propósito; o teste devolve o que ele mesmo sujou. `todos.sh` põe `sudo`/`pkexec`/`su` falsos no PATH e HOME de brinquedo para a suíte inteira. Ressalva: o `seletor-do-pack.sh` segue numa cópia da árvore — ele cobra o comportamento da P60 que a P73 desfaz; a cobertura do repositório real foi para o `git-limpo.sh`. |
| 7 S4 | feito | `f561972` | a causa da recusa era `tar --no-absolute-names`, opção que o GNU tar 1.35 não tem (rc 64): o verbo `greeter-aplicar` recusava TODA chamada. Numa cópia isolada da ponte: antes rc=2 «tar recusado», depois rc=0 e o arquivo no destino; link simbólico recusado. O `greeter.sh` diz o motivo na linha da recusa. |
| 8 achado 23 | feito | `550e076` | registro por painel em `$MEOW_ESTADO/paineis/<pid>.pid`; `--parar`/`--estado` só tocam o processo vivo que roda o servidor DESTE clone. Medido com dois painéis no mesmo estado (um deste clone, um do checkout principal): `--parar` derrubou só o deste clone; o outro seguiu de pé. |

Suíte (`./tests/todos.sh --portatil`, com o sudo falso e a casa de brinquedo novos): 28 verdes, 2 vermelhos
— `git-limpo.sh` (o I3, de propósito, até a P73) e `portabilidade.sh` (anterior, ver achados). Sudo recusado
e registrado: 2 chamadas (`ponte_root.sh estado`, do `chk_ponte`). Nenhum arquivo mudou em `~/.config/meow`,
`~/.local/share/icons`, `~/.local/state/meowsystem`, `~/.local/bin`, `~/.config/systemd/user`,
`/usr/local/lib/meowsystem` nem `/etc/sudoers.d` durante a passada. O `pack.sh` saía «pulado» sob a casa de
brinquedo (lia a origem da biblioteca no HOME) e o `doctor-so-le.sh` vermelho (procurava o painel da sessão
pelo HOME): os dois leem a casa real por `SUITE_CASA_REAL`, só leitura — rodados à parte, verdes.
Da máquina: `previa-cerca.sh` e `pastas-do-pack.sh` verdes; os de navegador não foram rodados.

Notas para a integração:
- **A ponte instalada precisa ser reinstalada** (`./install.sh`, pede a senha uma vez): o verbo `pacotes` e o conserto do `greeter-aplicar` só valem depois. Até lá o `chk_ponte` diz «diverge do repositório» (a ponte segue no `SEM_CONSERTO`: escrever em `/etc/sudoers.d` é decisão com senha).
- **1ª passada vermelha numa casa nova**: o `index.theme` do `icones` não converge numa passada (é a P74 item 5). O veredito agora diz isso, em vez de «consertado».
- Arquivos de outros blocos tocados no mínimo: `scripts/completar_icones.sh` e `scripts/construir_pastas.sh` (só as linhas da mensagem e o código de saída; as linhas 107/149 do leitor são da P74), `scripts/files_menu.sh` (1 linha, ~199; P76), `scripts/escala.sh` (bloco do `--conferir`; a P76 mexe no `saidas()`), `app/servidor.py` (o `ICONES_BASE` ~1456 e o `finally` do `main`; P73/P77), `tests/app.sh` (isenção das aposentadas, lida do `migrar_conf.py`), `tests/sem-dracula-os-theme.sh`.
- `meow doctor` sem `--consertar` continua só lendo (contrato da P44 e o «Conferir a máquina», que promete não escrever): quem corrige é o `--consertar` — o botão «Consertar» e o auto-reparo das 5h. O veredito dos dois agora é o mesmo.

===== P75-doctor-corrige.md :: ## Achados para a próxima leva
- `meow-doctor.service`: com o veredito honesto, «ficou fora» sai 2 e a unidade fica `failed` sem notificação (o `ExecStopPost` só avisa no 1). Decidir se o 2 também avisa.
- Frases que ainda mandam fazer à mão, fora do recorte desta spec: `chk_tema` («importe … pela GUI e rode: meow tema capturar»), `greeter.sh` («rode o install.sh de novo com sudo disponível», «capture antes»), `files_menu.sh` («para construir agora: meow files-menu build»), `midia_build.sh`/`leitura_build.sh` («instale com rustup» — P76 item 8), o aviso do `NOPASSWD: ALL` («veja de onde vem: sudo -l», decisão 5 de 02-decisoes.md).
- `instalar_fontes.sh`: ferramentas que faltam (curl, xz, unzip…) e a `pop-fonts` são nomeadas, mas não estão no `pacotes` da ponte — sem cura.
- `docs/FRONTEIRA.md` ainda conta «oito verbos fechados»; a ponte tem o `pacotes` agora.
- `pack.py:ICONES_BASE_DO_EXEMPLO` e os leitores `${ICONES_BASE:-…}` (install.sh, construir_icones.sh, bin/meow) ficam sem razão quando a P74 item 1 os trocar pela pergunta ao pack; aí a isenção das aposentadas no `tests/app.sh` deixa de casar sozinha.
- `tests/portabilidade.sh` falha no dev desde `f24868c`: `docs/pesquisas/2026-10-09-cosmic-vivo.md:198` escreve a casa de uma pessoa.
- A suíte (`tests/todos.sh`) só falsifica `sudo`, `pkexec` e `su`; `systemctl --user`, `gsettings`, `dconf` e o barramento de sessão seguem reais. A passada inteira do `doctor --consertar` numa casa de brinquedo chama `systemctl --user enable --now meow-*.timer/.path` e `gsettings set …cursor-theme` — na conferência só não chegaram à sessão porque o harness os falsificava. Hoje nenhum teste da suíte roda a passada inteira, mas a proteção é de cada teste, não do runner.
- `prompt` sem starship e sem recusa termina `!!` com «resolve: ./scripts/prompt.sh instalar-starship»: a cura é conhecida, mas baixa sem pino (`curl | sh` do starship.rs) e é pendência com pergunta desde a P2. Decidir se o doctor a aplica.
- `wallpaper` numa casa nova: «só 0 imagem(ns) … o carrossel precisa de 2 ou mais» em `!!` — o doctor recém-instalado termina vermelho até haver imagens.
- `greeter-aplicar` (`ponte_root.sh`): a recusa de `..` roda num `while` de pipe e o `morrer` sai só do subshell (é código morto: o GNU tar já recusa `..`, e o `find` não devolve `..`); e o `cp -a` para o `.config/cosmic` do greeter segue link simbólico que já exista no destino. Os dois são anteriores à P75.
- `iconesapps` ainda diz «o acervo Catppuccin de aplicativos não está em …» com o Dracula no ar (P70 item 3; cabe na T1/P74 item 7).
- Depois da migração, o meow.conf dela guarda o bloco de comentário que o install.sh acrescentou com a `ICONES_BASE` (`# @ Tema de onde herdar`, ~25 linhas) sem chave embaixo: inerte (o painel lê o esquema do exemplo), mas é texto sobre uma chave que não existe mais.

===== P76-cosmic-vivo.md :: ## Estado da execução (09/10/2026, sprint/p76)
Tudo medido nesta máquina; nada aplicado no HOME de verdade, nada com sudo.

| # | Estado | Commit | Prova rodada |
|---|---|---|---|
| 1 | feito | 1140ed0 | `patch -p1 -F0 --dry-run` do patch novo no `cosmic-files` 1.10 (ac5cef7) puro: rc=0; o do 1.9 no mesmo fonte: rc=1. Build do `cosmic-files-applet` 1.10 patchado: 3 min 43 s, `grep -a -c MEOW-FILES-WALLPAPER-PATCH-1` = 1. O do 1.9 ficou como `cosmic-files-wallpaper-menu-1.9.patch`; o `files_menu.sh build` tenta os dois com `-F0`, do mais novo ao mais velho |
| 2 | feito, **desligado** | fe37d6f | `tests/compositor-shim.sh`: 24 ok (versão igual/diferente, `ruim`, sem build, estado sem `req`, duas quedas -> `ruim`, sessão longa zera, verbos). Ligar: `meow compositor` (compila em `~/.local/libexec/meow/cosmic-comp/<versão>`) e `meow compositor ativar`; voltar: `meow compositor desativar`. O `/usr/bin` volta de fábrica no próximo apt do `cosmic-comp` (ou reinstalando o pacote, decisão dela). Falta a prova do login, à mão |
| 3 | feito | 59d062d | `cosmic_prever.sh --debs <1.10> --fontes <1.10>`: esquema igual nos 4 pacotes; todas as chaves presentes, `leitura_temperatura` ausente no de fábrica (esperado); série: 4 com `-F0`, modo de leitura só com `-F1`; menu do cosmic-files verde (é o rebase do item 1); toolchain 1.93 contra 1.93.1/1.93.0 "no limite"; `theme.rs` mudou entre c003a58 e 5a8bd94. `tests/cosmic-prever.sh`: o bom sai rc 0, o quebrado rc 1 |
| 4 | feito | 9d9dc3c | `tests/pos-apt.sh`: um build por versão nova, zero na segunda passagem (o arquivo de versões nem é reescrito), passo que falha não grava. Escada contra o 41497b4, com os alvos puros do 0fbd457: **2 no degrau 1** (raio, blur) **e 3 no degrau 2** (workspace-vazio e menu-clique-curto: `-F0` limpo, mas o upstream mexeu em `tiling/mod.rs`, `shell/mod.rs`, `workspace.rs`, `grabs/menu/mod.rs`; modo de leitura: `-F1`). A pesquisa esperava "4 no 1 e o modo de leitura no 2"; o critério dela mesma (`diff -q` dos arquivos tocados) dá o que está aqui |
| 5 | feito | 13c79e8, e16a83f | `atualizar_sistema.sh limpar` em seco: "guardaria cosmic-comp_0.1~1790118748~24.04~0fbd457_amd64.deb". `tests/volta-do-cosmic.sh`: 15 ok. O pós-apt roda `rustup update` quando o pré-voo acusa toolchain vermelho (`tests/pos-apt.sh`) |
| 6 | feito | a5e9afb | `tests/contrato-cosmic.sh`: janelas, relógio, terminal, vidro e forma gravam no `v2` de um `/usr/share/cosmic` falso, sem nascer `v1`; o pré-voo dá aviso para `v1 v2 v3` e `v2 v3`. Na máquina: as 15 chaves do contrato presentes nos binários instalados, `meow_cosmic_v` = v1 (comp, painel), v2 (tema) |
| 7 | parcial | 5277441 | Oráculo (`src/oraculo-tema`) compilado contra d77e99f (o libcosmic do cosmic-settings 1.9 instalado) e 5a8bd94 (o do 1.10), 38 s e 32 s. Contra o Python, no dracula-mauve (254 campos): d77e99f igual nas duas árvores; 5a8bd94 igual na Dark e diferente **só** em `background.component.pressed` na Light (#E9EAF5E1 -> #B6B7C2E1) — e o mesmo campo nas Light das três capturas do Catppuccin. A hipótese do §2.4 se confirma para o Dracula escuro. `tests/oraculo-tema.sh`: 5 ok. **Não feito**: o oráculo refazendo o produto na montagem do tema (é o `aplicar_tema.sh`, território da P74) |
| 8 | feito, menos o coredump | 9fc905f | `tests/applet-pino.sh`: 16 ok (o build só quando o painel anda depois da base; volta ao pino quando falha; `--conferir` não escreve). `leiturabin` e `midiabin` saíram do `SEM_CONSERTO`, com `fix_` que recompila. Na máquina: painel 1.9 pina 23f5d63, os applets 1f6dc99; a regra adota a base sem recompilar, e o applet anda no próximo apt. **Não feito**: o coredump retirando a sombra |
| 9 | feito | 67f5ecd, c1969d7, 872b913, e96ec04 | `escala.sh` pelo `--kdl`: saída igual byte a byte à do awk antigo nesta máquina; `tests/escala-kdl.sh`. Backoff sem medida vira `nao-medida` e o `reciclar` recusa: `tests/backoff-do-supervisor.sh`. `meow cosmic icones`: "sem desenho: com.system76.CosmicViewer"; no 1.10 nenhum `.desktop` entra ou sai. `meow cosmic prever` acusa "cosmic-applets instalado é o 82e7cd8; scripts/appid_dock.sh foi medido no 40248fb" |

Testes (HOME temporário, `sudo` falso no PATH): `tests/todos.sh --portatil` — 35 verdes, 1
pulado (`pack.sh`, que pula sozinho) e 2 vermelhos. Os dois existem também no dev (f24868c),
com o mesmo ambiente: `portabilidade.sh` (o `/home/<nome>` na linha 198 da pesquisa) e
`doctor-so-le.sh` (a conferência "com o HOME da sessão" não acha o painel com HOME de
brinquedo). Os da máquina (Playwright) não rodaram.

===== P76-cosmic-vivo.md :: ## Achados para a próxima leva
- O gatilho do pós-apt mora no `99-meow-lancador`, que só se instala com
  `LANCADOR_SISTEMA="sim"`. Um hook próprio desacopla, mas pede um verbo novo na ponte root.
- O doctor não confere as unidades `meow-pos-apt.*` (é da P75); e o pré-voo não roda no
  doctor quando `apt list --upgradable` mostra `cosmic-*` (§4.2), nem o `lib/preflight.sh`
  saiu da instalação para o doctor (§4.4).
- A chave ausente no binário ainda não impede o escritor de gravar (§4.4, princípio D).
- O `completar_icones.sh` não lê a lista do `meow cosmic icones` (território de ícones, P73/P74).
- `v1` cravado fora da lista da spec: `lib/noite.sh`, `logo.sh`, `instalar_fontes.sh`,
  `construir_icones.sh`, `completar_icones.sh`, `auditar_icones.sh`, `leitura_build.sh`
  (ASA/MEIO), `janelas.sh:348` (`Dark/v1/gaps`) e os de estado do `wallpaper.sh`.
- A ponte faz `update` e `full-upgrade` num verbo só: o pré-voo lê a fila do último
  `apt update` do sistema, não a que o upgrade vai instalar.
- Decisões abertas da pesquisa (§6) que o código assumiu e são dela: a escada aceita o
  degrau 2 sozinha (sob a guarda de queda); o GitHub é a única fonte da revisão do
  libcosmic (o fonte do apt como reserva não foi feito).
- Com o shim ligado e o primeiro apt, o `/var/lib/meowsystem/cosmic-comp/patches.estado` e
  o `.pacote` antigos ficam sem uso (o `conferir` os ignora no modo shim); apagá-los é sudo.
- A doutrina "nunca `apt upgrade`" (`docs/COSMIC-THEMING.md` §6) não foi tocada: é a
  tarefa 10 da pesquisa, decisão de gente depois do login com o shim.
- (conferência) Com o shim ligado e sem build da versão instalada, o `conferir` sai 0 com
  um `!!` na mesma saída: segue o princípio D da pesquisa (degradar e voltar sozinho não
  acende nada), mas bate com o princípio 1 dela ("nunca TUDO CONFERE com algo fora").
  A saída limpa é o doctor compilar (um `fix_patches` com o shim ligado, como os applets);
  é decisão do doctor (P75).
- (conferência) O `meow-doctor.service` também roda sem `~/.cargo/bin` no PATH: o
  `fix_leiturabin`/`fix_midiabin` só compila pelo doctor do pós-apt (que agora acha o
  cargo) ou pelo terminal; o das 5h cai em "sem cargo". O lugar da cura é a unidade do
  doctor (P75).
- (conferência) A base do pino dos applets só nasce numa passagem que aplica (o
  `install.sh`): se o instalador rodar depois de um apt que mudou o painel, a base nasce
  com o painel novo e o applet fica no pino até o painel mudar de novo.
- (conferência) O `compilar` deixa `~/.local/state/meowsystem/cosmic-comp/alvos.novo` para
  trás quando o binário sai igual, e troca os `alvos` por uma cópia parcial quando a
  árvore do cache já estava patchada (os arquivos com marcador são pulados). Os dois só
  tornam o degrau 1 mais raro (arquivo faltando conta como "mudou"), nunca o contrário.
- (conferência) `tests/contrato-cosmic.sh` cobre cinco dos oito escritores; `areas.sh`,
  `wallpaper.sh` e a fronteira do `aplicar_tema.sh` ficaram sem caso.
- (conferência) `docs/pesquisas/2026-10-09-cosmic-vivo.md:198` faz o
  `tests/portabilidade.sh` falhar (vem do dev, f24868c).

===== P77-interface-mostra.md :: ## Achados para a próxima leva
- `comandoCurto` (app.js) perdeu o último chamador quando a linha `code.cmd` do cartão de ação saiu; ficou com a nota, pela regra da casa.
- `.descricao-secao` (estilo.css) não tem mais quem a gere: o subtítulo da página virou o `?` do cabeçalho.
- A faixa da simulação do modo de leitura perdeu «quem pinta de verdade é o cosmic-comp»; a prévia real do item 4 decide o que fica.
- ~~`avisoDeCombinacao` e `avisoDeLado` (Cor e tela) ainda são frase visível: viram selo na reescrita da página.~~ Resolvido no grupo 1: os selos ⊘ e lua na linha do título, frase no topo da dica.
- ~~Início continua com 2 306 caracteres: o bloco «Próprio / herdado / do motor» do cartão do pack (achado 8, U1) é da página.~~ Resolvido no grupo 1: 966 caracteres, origem em selos e detalhe na linha inteira.
- `tests/app-acessibilidade.py` ainda isenta as «12 legendas de desenho»: elas saíram da tela, e a isenção pode cair.
- Grupo 1: os «Desenhos autorais do pack «Catppuccin»» oferecem `fogstripper` e `hefesto`, que são projetos pessoais (decisão 4, S2). É conteúdo do pack, não do painel.
- Grupo 1: em «Cor e tela», as ações «Trocar de tema» e «Passar para claro ou escuro» repetem a decisão da moldura e rodam na hora. São candidatas ao «⋯» de ações técnicas da direção (seção 4), que ainda não existe como componente.
- Grupo 1: o pack se escolhe em dois lugares com dois comportamentos: «Theme pack» em Cor e tela grava `PACK` e espera o «Salvar e aplicar», e o «Usar este» da Início roda o `pack_usar` na hora. O achado 11 fica pela metade até as duas portas dizerem a mesma coisa.
- Grupo 1: a marca `[avancado]` saiu de `LANCADOR_OCULTAR`. Ela nunca tinha efeito, e com o «⋯» de agora esconderia a lista que o achado 20 precisa ver. Quem reescrever Lançadores decide se ela volta.
- ~~Grupo 1: o resumo do topo («N mudados por você», `app.js` perto de `mexidas`) ainda conta a chave `sem_programa`, e a Início já não conta. Os dois números podem diferir por um numa casa que tenha a chave preenchida sem o Hefesto.~~ Resolvido no grupo 4 (`pintarResumo` faz a conta da Início).
- Grupo 1: a faixa da FORMA (Painel e dock) continua grudada na página inteira, de propósito, porque é o desenho do assunto. As outras faixas agora ficam na própria seção. Se Painel e dock também mudar, o `render` é o lugar.
- Grupo 2: o «Restaurar ao padrão» das chaves que aceitam vazio grava VAZIO («não toca»), e para a maioria (forma, vidro) vazio é mesmo o padrão. Em `RELOGIO_SEGUNDOS` o padrão é `nao`: o botão aparece com o valor já no padrão e grava outra coisa, com o nome errado. Precisa de dois gestos com dois nomes (voltar ao padrão do arquivo, devolver ao COSMIC), ou o botão gravar `item.padrao`.
- Grupo 2: `meow_estado_com_padrao` (lib/comum.sh) semeia o estado do papel de parede na primeira LEITURA, inclusive no `meow wallpaper` sem argumento, que só mostra. Com as ações técnicas no «⋯», «O carrossel agora» passou a ser o primeiro script da aba no gate e o achou; ficou em `DEFEITOS_CONHECIDOS` do `tests/app-completo.py`, com o endereço do conserto.
- Grupo 2: o desenho «No dock» (Logo do sistema) ainda usa um gato de traço genérico (`gatoDeTraco`). A mesma técnica do terminal (o SVG do acervo pintado pela página) poria o gato de verdade na ponta da dock.
- Grupo 2: «Pôr um gato no dock» e «Passar ao próximo gato» repetem a decisão da moldura do gato e ficam apagadas (⊘) em dois dos três modos. Candidatas a sair da tela ou a morar dentro da moldura, no modo que as usa.
- Grupo 2: a grade de três colunas deixa buraco quando um cartão de par de desenhos é mais alto que os vizinhos (Papel de parede, sob «Como a imagem ocupa a tela»). É da grade universal, não da página.
- Grupo 2: o «Instalar o starship» mudou de página (Manutenção → Terminal) e aparece mesmo com o starship instalado; a pendência `starship-ausente` já sabe quando ele falta e poderia apagar o botão.
- Grupo 3: o tema claro (`MODO_AUTO_CLARO_DE/ATE`) é hora cheia num deslizante de 0 a 23, ao lado de dois pares de `<input type=time>` no mesmo relógio. Uma régua de horas (ou o campo de hora com passo de 1 h, gravando só a hora) deixaria as três linhas com o mesmo controle.
- Grupo 3: «A noite começa às» preenchida com «A noite termina às» vazia não vale (o `meow_noite_janela` pede as duas pontas); a página agora mostra o ⊘ com o porquê, mas o arquivo aceita a meia escolha calado. O `validar_valor` poderia recusar o par incompleto, ou o `lib/noite.sh` herdar só a ponta vazia.
- Grupo 3: `previas-sistema.js` (`lerNoite`) e o `desenharNoite` do par «Separar imagens» ainda resolvem a noite do gato sem a janela do applet; o relógio e a Início usam o `janelaDoGato`. O desenho do par só mostra a imagem escura, então não mente hoje — mas é a terceira cópia da regra.
- Grupo 3: o applet do modo de leitura lê o ponto dos sliders (`ultima_*`) só ao nascer; depois do «Salvar e aplicar» o relógio e a tela seguem o painel no minuto seguinte, mas o interruptor do popup religa no ponto que o applet tinha na memória até ele reiniciar. Um `watch_state` no `src/applets/leitura` fecharia a última ponta.
- Grupo 3: o «Restaurar ao padrão (Sim/Não)» do `LEITURA_AGENDA` grava vazio («não toca»), com o nome do valor no rótulo — o mesmo defeito de nome que o grupo 2 anotou no `RELOGIO_SEGUNDOS`.
- Grupo 3: «Ver o que mudaria nos jogos do Heroic» (natureza `conferir`) fica aberto e «Pôr os jogos do Heroic no lançador» (`aplicar`) vai para o «⋯»: o par se separa. Candidatos a virar os dois botões da seção de jogos, como o «Conferir» e o «Arrumar» da Steam.
- Grupo 3: achado 20 (o lançador esconde Google Chrome, Steam e github-desktop) é o VALOR de fábrica do `LANCADOR_OCULTAR` (32 ids, de quando a lista saiu do código em 21/09), e só vale com «Arrumar o lançador» em Sim. Pode ser o par sistema × atalho do MeowSystem (o `appid_dock.sh` cita um invólucro do Chrome em `/usr/local/share`), pode ser gosto de quem fez: decisão de produto, não de interface. A lista continua visível (sem `[avancado]`).
- Grupo 3: «Ver o que mudaria nos jogos do Heroic» saiu uma vez com «SAIU NULL» no gate (uma corrida em quatro, sem mudança no script); intermitente, como o clique do jogo da Steam que o grupo 1 anotou.
- Grupo 3: `controlePorArea` (folga e encaixe por área) só existe com `AREAS_NOMES` preenchida; com as áreas do COSMIC na tela (vazio = «são suas»), os dois cartões continuam campo de texto até o primeiro gesto nas pastilhas. É honesto (o `areas.sh` se pula com a lista vazia), mas a folga em texto livre é o último campo cru da página.
- ~~Grupo 4: no gate completo (as 14 abas), o «O que está no ar agora» (`meow status`) passou a reprovar com «mudou 4»: `com.system76.CosmicTheme.{Dark,Light}/v2/{background,primary}` mudam na casa durante os 15 s dele. Ele não escreve sozinho (medido: `meow status` duas vezes numa casa nova, e depois de `doctor --consertar` e de `desfazer`, não muda nada), e a aba Instalação sozinha passa (`--aba Instalação`, duas corridas). O que mudou foi a ORDEM: no «⋯» ele roda depois do «Desinstalar» (ensaio) e do «Voltar ao tema de antes» (ensaio e de verdade), e antes rodava logo depois do «Consertar». Algum escritor do tema (os `derivar_*.py`) está rodando fora do gesto que o pediu e cai na janela do `status`; a causa não ficou achada nesta leva. No `af3159f`+grupos 1-3 o mesmo gate não tem a reprovação.~~ Resolvido na conferência (`c114d75`): o `chk_vidro` roda o `vidro.sh` em ensaio, e o remendo `vidro_janela.py` escrevia assim mesmo; num tema sem `frosted_maximized_apps` (o que o «Voltar ao tema de antes» devolve) ele mudava os 4 arquivos. Agora o ensaio só confere, com teste em `tests/vidro-do-cosmic.sh` (vermelho no código de antes).
- Grupo 4: a Atualização não mudou. «O que a atualização mudaria» é o ensaio do «Atualizar a máquina inteira» (natureza `mostrar`, mas procurado de propósito), e os dois são candidatos a um par «ver / aplicar» como o «Conferir» e o «Arrumar» da Steam, em vez de dois cartões soltos.
- Grupo 4: o desenho de seção sem chaves (`desenhoDaSecaoSemChaves`: Instalação, Atualização, Manutenção) ocupa a linha inteira com o desenho de 260 px à esquerda e o resto vazio. É da faixa comum, não das páginas.
- Grupo 4: no menu a 375 px (faixa horizontal), o balão não cabe à direita e vai para cima, sobre o campo de busca. Não cobre item do menu (a regra do U3), mas cobre a busca enquanto o rato está no item.
- Grupo 4: o `<select>` das chaves que aceitam vazio mantém a opção «— como está —» ao lado do novo «Restaurar ao padrão»: dois gestos para o mesmo vazio. A opção é o jeito de o `<select>` mostrar o vazio; tirá-la pede outro jeito de desenhar «como está» no seletor.
- Grupo 4: o gate de uso real confere o achado 19 (a Steam como jogo) e o 18 (o terminal só com o contorno) pelo que a casa de brinquedo consegue reproduzir: com a loja plantada, o `dev` de hoje não a põe na grade de jogos, e a prévia do terminal tem 27 traços (a moldura das células). Os dois ficam cobertos pelos testes da página (`app-navegador.py`, `um-cartao-por-jogo.sh`), não por este gate.
- Grupo 4: S2 nos documentos continua: as 362 linhas com `/mnt/Apate` e o «pedido dela» de `docs/` não são tela; o gate só olha o que a tela mostra (texto e campos).
- Conferência: o `scripts/vidro_janela.py` acha o tema em `~/.config/cosmic` cravado (`COSMIC_DIR`) e não lê o `MEOW_COSMIC_DIR` que o `vidro.sh` respeita; numa casa com o COSMIC noutro lugar, as duas metades da mesma chave olham pastas diferentes.
- Conferência: com `LOGO_MODO=""` escrito no meow.conf (a compatibilidade do `logo.sh` lê isso como `rotacao` se `LOGO_ROTACAO="sim"`, senão `hora`), a moldura «Gato do dock» não mostra nenhum gato, porque o `mostraNoModo` procura o modo vazio. O servidor já tem o modo efetivo (`_modo_do_gato`) e não o manda à página.
- Conferência: o «Restaurar ao padrão» das chaves que aceitam vazio e têm padrão de fábrica preenchido («Janelas lado a lado» = sim, «Ligar o modo de leitura no horário» = sim) aparece com o valor no padrão e grava vazio («não toca»). O achado 14 ficou resolvido para o vazio; o nome do botão segue o defeito que o grupo 2 anotou no `RELOGIO_SEGUNDOS`.
- Conferência: o clique no «Créditos» do menu (`menu · link externo`) estourou o tempo uma vez no gate completo e passou na corrida seguinte (`--aba Atualização`, que também roda o topo); intermitente, como o clique do jogo da Steam.
- QA de uso real: fora do padrão de fábrica, o «Restaurar ao padrão» das chaves com fábrica preenchida mostra o valor da MÁQUINA no parêntese («Restaurar ao padrão (Não)» com a fábrica em Sim, no modo de leitura) e grava o vazio. O caso «já no padrão» saiu da tela; o nome do gesto segue o achado do grupo 2.
- QA de uso real: a caixa de pergunta das ações com sudo tem um parágrafo de 4 linhas («Nada aqui pede, lê ou guarda senha…»). O gate de uso real não olha `<dialog>`; é a superfície de consentimento, e a decisão de encurtar é de quem usa.
- QA de uso real: saídas que mandam digitar dentro do painel: o `icones_apps_dracula.sh` («para ver agora… pkill -x cosmic-panel»), o instalador («Para completá-las: sudo -v && ./install.sh») e o doctor («conserto: LEITURA_COMPILAR=1 …», «para construir agora: meow files-menu build»). O «há divergências» do conferir ganhou o botão; estes não.
- QA de uso real: a casa real guarda `ICONES_FLAVOR="macchiato"` (herança do Dracula de antes da P74), e o doctor diz «123 tipos de arquivo já vestidos de Catppuccin macchiato» com o Dracula completo no ar. Migrar o valor ou perguntar é decisão de pack, não de tela.
- QA de uso real: o ensaio de trocar o Dracula pelo Catppuccin avisa que `CURSOR` e `ICONES_PASTAS` continuam citando o Dracula («Vestígio do pack»): a troca de pack sai pela metade numa casa que escolheu o ponteiro e as pastas do pack.
- QA de uso real: na casa real, o `CosmicBackground/v1/all` aponta para `ativos-noite` (uma pasta, não o carrossel); o `wallpaper.sh` corrige no primeiro gesto («isso não é o carrossel; devolvendo»), e o doctor não acusa.
- QA de uso real: os «Desenhos autorais do pack «Dracula»» também oferecem `fogstripper` e `hefesto` (a nota do grupo 1 era só do Catppuccin), e o doctor ainda cita `~/Desenvolvimento/hefesto-dualsense4unix/…` pela `ICONES_LOGO_HEFESTO` da casa real (S2).
- QA de uso real: a galeria do papel de parede tem a aba «Favoritos», e nenhuma imagem oferece o gesto de favoritar (o menu da imagem é Usar, Dia, Noite, Tirar).
- QA de uso real: «Usar este ícone» abre a gaveta e a página rola até o fim; o cartão do app que acabou de mudar sai de vista.
- QA de uso real: Manutenção tem dois «⋯» idênticos (ajustes técnicos e ações técnicas) sem nada que os distinga além do lugar; «Quantos backups guardar» e «Largura do nome da música» são campo de texto para um número.

===== P78-seguranca-e-gate.md :: ## Achados para a próxima leva
- ~~Conteúdo dos temas de app não é filtrado, só o caminho.~~ **Curado na conferência** para os
  dois que viravam comando: o modelo de kitty e o de GNOME Terminal de um pack só levam chave de
  cor (e `visible-name`, e a seção `[/]`); `shell`, `map … launch`, `geninclude`, `include`,
  `custom-command` e outra seção são pulados e contados (`_kitty_so_cor`, `_gt_so_cor`). Telegram,
  Discord e OnlyOffice continuam passando inteiros: nenhum deles executa o que o tema diz, mas o
  CSS do Discord pode buscar na rede (`@import`), como o próprio tema Dracula faz.
- **O VS Code instala a extensão que o pack nomeia** (achado da conferência, gravidade alta). O
  `apps.vscode.origem` traz `extensao`, `url` e `sha256`, e o módulo baixa o `.vsix` e roda
  `--install-extension`; sem `url`, instala pelo id da Marketplace. O sha256 é do próprio pack:
  prova integridade, não confiança. Uma extensão é código que roda com a conta de quem usa a cada
  abertura do editor, então um pack de terceiro escolhe código para rodar. Cura a decidir por quem
  usa: só pack do motor (`packs/` do repositório) instala extensão sozinho, ou uma lista fechada de
  publicadores, ou a pergunta da P46 para esse caso.
- **Mapa com CRLF perde as linhas em silêncio-contado.** Um `pastas.map`/`mimetypes.map` escrito
  no Windows tem `\r` no glifo, e o `meow_nome_seguro` o recusa: a linha é pulada e contada, nada
  sai da raiz, mas o pack inteiro fica sem pastas. O `pack.py` (`splitlines`) aceita o mesmo
  arquivo; o shell não. Tirar o `\r` no leitor de mapa do shell.
- **O `_proibido` do `.meowpack` olha só `.sh` e `#!` no primeiro byte**: um `leia.txt` que começa
  com BOM e `#!` entra (medido). Nada do pack é executado nem fica executável (chmod 644), então
  não é porta; anotado para a régua não prometer mais do que mede.
- **Painel de pé que não é desta leva**: o PID 1985165, `app/servidor.py` do checkout principal,
  de 09/10 18:52, com o HOME em `scratchpad/pp/casa`. Não é desta conferência, e por isso não foi
  derrubado.
- **`rsvg-convert` sobre SVG de pack** (semente de papel de parede, prévias): o librsvg resolve
  `<image href>` relativo ao arquivo; não medi se um symlink dentro do pack o leva para fora.
- **Duas políticas para a linha ruim.** No `validar` (inclusive o silencioso, o do motor), um alvo
  de `apps.map` que sai da raiz recusa o pack INTEIRO (a máquina veste o padrão); nome de destino
  torto e linha de `pastas.map` torta são pulados e contados pelo consumidor. Decidir se o alvo
  também passa a ser pulado e contado.
- **`pack.py sincronizar`** abre os caminhos da coluna `lido de` do `PROCEDENCIA.md` do pack (só
  para comparar sha256, nada sai). Saiu do doctor na P75; continua no verbo manual.
- **O filtro de nome do `_dracula_pares_do_mapa` fica no `awk`**, com o mesmo conjunto do
  `meow_nome_seguro`, porque três testes extraem a função verbatim e a rodam sem o lib/comum.sh.
  Se os testes passarem a carregar o lib, o `awk` pode chamar a regra única.

===== P80-acabamento.md :: ## Abertos da P79 que entram aqui (`04-integracao-onda-2.md`, seção P79)
6. **Corrida do `Trabalho.vivo()`** (`app/servidor.py`): responde por `proc.poll()` antes de a thread
   `_ler` gravar `rc`/`fim`; a página recebe `vivo: false, rc: null` («SAIU NULL · 0S») e o gate fica
   intermitente. Cura na origem: `vivo()` responde por `self.fim is None`. Teste que força a janela.
7. **A instalação recicla o painel até três vezes** (arcticons, dracula, resgatados chamam
   `meow_tela_reler` cada um). Um reciclo do `cosmic-panel` foi o gatilho da faixa verde de 09/10
   (`Migração-OS/levas/leva-08-gpu-regressao.md`). Cura: um reler só, no fim da passada (marcar
   «precisa reler» e reler uma vez), e o `painel.sh reciclar` registra quem o chamou.
8. **Ainda mandam digitar**: o «resolve: <comando>» das pendências (vira o botão que resolve), o
   `meow wallpaper permitir`, o «instale com rustup…» do `leitura_build.sh` (o doctor instala).
9. **Falsos de teste**: o falso de `systemctl` de escrita recusa (como o do sudo), para o
   `convergencia.sh` não mentir.
10. **Decisão 12**: trocar de pack leva o ponteiro do pack mesmo que baixe (o pack decide); o
    download aparece com o selo «baixa da internet», sem pergunta.

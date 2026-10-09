# P74 — O pack Dracula é um tema completo, montado certo e exportável

**Branch:** `sprint/p74` · **Fontes:** paridade T6–T10, `01-regressoes.md` (I1, I2, I7, I10, T1–T7),
achado 9, `02-decisoes.md` (1).

## Pedido de quem usa
«aqui deveria ter tudo do theme dracula», «onde o nosso faltar preciso que vc crie», «ao resetar o
PC terei tudo conforme o tema dracula?», «conseguiremos gerar e exportar temas completos?».

## Tarefas
1. **I1/I2** — todo leitor da base de ícones pergunta ao `pack.py:_base_escolhida`
   (`construir_pastas.sh:107`, `completar_icones.sh:149` e qualquer outro); pastas coloridas
   voltam. (A aposentadoria da chave `ICONES_BASE` no conf/exemplo/migrador é da P75.)
2. **T10 + decisão 1** — base em duas camadas: `circle` por cima, `main` por trás, ambas pinadas
   por sha256; os 458 simbólicos perdidos voltam.
3. **T6** — escolher o pack Dracula liga os desenhos de app dele (sem `ICONES_DRACULA=nao` padrão).
4. **T7** — `meow pack exportar` (ou o verbo que já existir) gera tema instalável: nome por
   pack+flavor, `Inherits` só do que vai junto, `Comment` do pack (não «Catppuccin»).
5. **T8** — `index.theme` certo na 1ª passada (Directories calculado do disco no fim); o laço de
   5 repetições do install.sh deixa de ser necessário.
6. **T9 + I7** — mimetypes Dracula próprios (do flavor `css-variables` + paleta) e as pastas que
   faltam (`folder`, `user-home`, `user-desktop`).
7. **T1 (regressões)** — nada Catppuccin com o Dracula no ar: starship `palette`, ícones de
   arquivo, prompt, aba Terminal.
8. **T2** — Obsidian para de oscilar: o tema do cofre é aplicado sem brigar com o git do cofre.
9. **T3, T4, T5, T6, T7** — sons do pack (os 25 .oga ou o motivo virar cura), qBittorrent sem
   depender da Aurora, os 30 overrides de .desktop no pack, Vesktop com `enabledThemes`,
   papéis de parede SVG 4k rasterizados.
10. **I10** — com MODO=claro, traço do dock e pastas usam a paleta do lado vestido.

## Prova
- uma passada das etapas de ícone numa casa temporária → `validar_index.py` sem faltas.
- `pack.py info dracula`: nada «herdado do Catppuccin» que tenha cura; mimetypes PRÓPRIO.
- exportar → instalar num HOME limpo → cache reconstruído, 0 links para fora, 230+ apps.
- `comm` dos simbólicos do tema antigo contra tema+base → 0.

## Estado da execução — 09/10/2026

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

### Testes (HOME temporário, `sudo`/`apt`/`systemctl`/`pkill` falsos no PATH)

`tests/todos.sh --portatil`: 23 verdes, 1 pulado, 6 vermelhos na primeira
rodada; depois dos acertos acima, rodados de novo um a um:

| teste | resultado |
|---|---|
| `pack-dracula-completo.sh` (novo, 25 conferências) | verde |
| `pack.sh` | verde (5 expectativas atualizadas: o Dracula deixou de herdar o macchiato) |
| `pastas-do-pack.sh` (máquina) | verde (seção 11 nova; a contagem das pastas especiais é 10) |
| `temas-de-apps.sh` | verde (qBittorrent com escritor próprio; Vencord com `enabledThemes`) |
| `fonte-unica.sh`, `app.sh`, `numeros.sh`, `reversao.sh`, `seletor-do-pack.sh`, `notas-de-funcao.sh`, `convergencia.sh`, `seco.sh`, `instalacao.sh`, `variante.sh`, `claro-do-pack.sh`, `flavor-padrao.sh`, `acento.sh`, `sem-dracula-os-theme.sh`, `sem-receita-no-log.sh`, `git-limpo.sh` e os outros portáteis | verdes |
| `doctor-so-le.sh` | verde com o HOME da sessão; com HOME temporário falha a conferência «com o HOME da sessão o reciclo acha o painel», que precisa do HOME de verdade (só leitura) |
| `portabilidade.sh` | vermelho, e não é desta branch: `docs/pesquisas/2026-10-09-cosmic-vivo.md:198` (commit `f24868c`) |

Arquivos de outros blocos que esta branch tocou (para a integração):
`app/servidor.py` (P73/P77: as quatro quedas no `mocha` e o `ICONES_DRACULA`),
`tests/seletor-do-pack.sh` (P73: `ICONES_DRACULA=""` → `"nao"`), `bin/meow` e
`meow.conf.exemplo` (P75), `lib/comum.sh` (função nova no fim do bloco do
flavor), `lib/desinstalar.sh` (`meow-som.service` na lista), `install.sh`,
`README.md`, `README.en.md`, `docs/SPRINTS.md` (contagens).

## Conferência — 09/10/2026 (conferente que corrige)

Toda prova refeita do zero, numa casa de brinquedo com `sudo`, `apt`,
`systemctl`, `pkill` e companhia falsos (o registro deles não tem `sudo` que
escreva). O HOME real só foi lido: nada de `MeowSystem-Sons`, `meow-som.service`
nem `-Base-2` nele, e o cofre do Obsidian sem filtro nem linha em
`.git/info/attributes`.

**Confirmado, com a prova refeita:** item 1 (todo leitor da base pergunta ao
`pack.py`; seção 11 do `pastas-do-pack.sh` verde); item 2 (simbólicos do
`Dracula-Icones` congelado fora da cadeia: 458 só com o circle, **0** com o
main atrás); item 3 (229 em `scalable/apps`; o conf desta máquina já diz
`ICONES_DRACULA="sim"`); item 4 (exportar → instalar num HOME limpo: cache nos
três, 0 links para fora, 0 quebrados, 229 apps, 0 «Catppuccin», `Inherits` só
das duas bases e do `hicolor`); item 5 (uma passada das 18 etapas de ícone do
`install.sh` → `validar_index.py` com `com_arte_nao_declarados=0`; a 2ª passada
não escreve nenhum arquivo); item 6 (a conta do `css-variables` dá os 656 do
`mocha/` byte a byte, e os 656 × 2 do Dracula também; as dez pastas na mesma
silhueta); item 7 (`/paleta.css` com FLAVOR vazio sai `#282A36`/`#BD93F9`);
item 8 (num cofre com o HEAD e o disco DESTE cofre real: `git status` limpo, um
checkout de commit antigo mantém o Dracula, o HEAD guarda «Catppuccin»); item 9
(25 `.oga` iguais aos da origem; o `.qbtheme` bate com o do commit `9020f6eb`
do upstream; 24 dos 27 overrides que escondem; os dois papéis comparados dão
RMSE 0); item 10 (com `MODO=claro`, as 10 cores dos 47 traços são do Alucard).

**Corrigido (um commit cada):**

| commit | o que estava errado |
|---|---|
| `e184c73` | `som.sh aplicar` dizia «som de volume do MeowSystem instalado» quando só o tema de som mudava. |
| `70f5967` | O `-nome` do `LANCADOR_OCULTAR` não devolvia ao lançador o que uma passada anterior já tinha escondido: a frase do exemplo era falsa. Agora desfaz a marca na forma que o script escreve. |
| `a733a48` | O cabeçalho do `starship.toml` e a `_nota_modelos` do pack diziam o contrário do que a P74 fez. |
| `b2030f4` | O Vesktop do flatpak roda como `vesktop.bin`, e o `pgrep -x vesktop` não o via: com ele aberto, a lista `enabledThemes` era escrita e perdida. |
| `b9b7419` | O `som.sh vigiar` acordava 3 vezes por segundo sem aviso nenhum (13 `select` em 3 s, medido com `strace`). Agora são 0. |
| `2b60bed` | Segurança (seção «Segurança» da spec no dev): a `pasta` da base podia ser link para fora, e o `.meow-origem` era escrito no alvo; `../` no nome do `apps.map` e do mapa de tipos de arquivo escrevia fora do tema; links no som, nos tipos de arquivo e na origem da derivação eram seguidos; a derivação escrevia através de um link no destino. |
| `3d74268` | Segurança: os `python3 -` novos importavam módulo do diretório corrente (um `json.py` no cwd rodava). Agora é `python3 -I -`. O `exportar-tema` só aceita id e flavor na forma do pack.py, porque os dois vão para um conf carregado com `.`. |
| `f73b13f` | Segurança: um slot a mais na paleta de um pack importado fechava a aspa no `starship.toml` e abria um `[custom.*]` com `command`. Agora só entram nome simples e `#RRGGBB`. |
| `8f23668` | Segurança: o flavor do lado vestido (uma chave da paleta) só sai como `[a-z0-9_]+`. |

O teste do pack malicioso está no `tests/pack-dracula-completo.sh` (seção
«segurança»). Com a árvore de antes dos acertos ele falha em tudo: base rc 1, 2
arquivos escritos no alvo do link, 2 `escapou`, 4 cópias do segredo, segredo
sobrescrito, 1 `[custom]` no starship. Com a de agora, tudo 0.

**Testes depois dos acertos** (HOME temporário e `sudo` falso): ver o fim do
relatório da conferência; `portabilidade.sh` continua vermelho pelo
`docs/pesquisas/2026-10-09-cosmic-vivo.md:198`, que vem do `f24868c`.

## Achados para a próxima leva

- `icones_apps_arcticons.sh` sai 3 depois de escrever, fora da sessão gráfica: o `meow_tela_reler` devolve 3 sob `set -e`. O `exportar-tema` o lista entre os «sem dependência».
- Conf antigo com `ICONES_DRACULA="nao"` (o de fábrica de antes) não se distingue de um «nao» à mão; o `migrar_conf.py` (P75) pode tratá-lo.
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

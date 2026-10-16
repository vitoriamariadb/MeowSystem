# O estado final do MeowSystem

O que o projeto entrega, o que é decisão de quem usa e onde ela mora, o que ficou de fora de
propósito, o que ainda está aberto, e como ele se mantém. Escrito em 16/10/2026, no fechamento
(P83), sobre a árvore da leva H. O índice de todas as sprints está em
[`SPRINTS.md`](SPRINTS.md); os números de hoje, no quadro do topo de lá, cobrados pelo
`tests/numeros.sh`.

---

## 1. O que ele entrega

| área | o que faz | onde ler |
|---|---|---|
| **Instalador** | `./install.sh` veste a máquina inteira, converge (a segunda passada não escreve nada), guarda cópia antes de escrever, e recusa por caminho escrever fora do que conhece. `--wizard` pergunta só as cinco chaves essenciais; `MEOW_DRY_RUN=1` ensaia | [README](../README.md) |
| **Theme packs** | as cores, os ícones, a base de ícones, o ponteiro, o som, os papéis de parede, os temas de dentro dos programas e o que se esconde do lançador vêm de um pack, que é dado e nunca código. Catppuccin (o padrão) e Dracula (completo, com o claro Alucard) vêm com o projeto. Usar, importar, exportar, exportar o tema de ícones montado e remover | [PACKS](PACKS.md) |
| **Segurança de pack** | todo caminho cai dentro do pack, link para fora e script são recusados, nome de flavor tem forma fixa, desenho de pack chega ao painel numa caixa de areia, e extensão do VS Code de pack importado só se instala por gesto | [PACKS, «O que um pack não pode fazer»](PACKS.md#o-que-um-pack-não-pode-fazer) |
| **Painel** | `meow abrir`: uma página por assunto e a Início com os packs. A interface mostra em vez de explicar: só fica na tela o que nomeia ou mede, o porquê mora atrás do **?**, e a prévia é a explicação. **Salvar e aplicar**, **Ver o que faria**, **Restaurar ao padrão**, e o selo em toda ação que baixa da internet | [app/LEIA-ME](../app/LEIA-ME.md) |
| **Seletor de ícone** | um ícone por programa, trocável um a um, com o acervo inteiro em pastas: os desenhos de cada pack, a biblioteca, os feitos à mão (em vetor), o traço, os resgatados e os enviados. A escolha mora com quem usa, nunca no repositório | [PACKS, «O seletor de ícone»](PACKS.md#o-seletor-de-ícone-o-acervo-inteiro-em-pastas) |
| **Doctor** | `meow doctor` confere e não escreve; `meow doctor --consertar` conserta o que estiver fora, sem mandar ninguém digitar. Roda sozinho às 5h, e o **Consertar** do painel é o mesmo gesto | [README](../README.md) |
| **Ponte root** | a senha do sudo uma vez, no instalador; depois, um conjunto fechado de verbos (`.desktop` do sistema, tela de login, hook do apt, completion, atualizar, os pacotes da lista) roda sem senha e sem terminal | [FRONTEIRA, «A ponte root»](FRONTEIRA.md) |
| **COSMIC vivo** | o compositor com a série de `patches/` e o menu do `cosmic-files` são builds da casa, sem sudo, refeitos sozinhos quando o apt traz versão nova; o shim escolhe a cada sessão entre o build e o de fábrica, e um patch obrigatório que não entra não troca nada | [MANUTENCAO](MANUTENCAO.md), [COSMIC-THEMING §6](COSMIC-THEMING.md) |
| **Testes** | `./tests/todos.sh` roda a suíte inteira numa casa de brinquedo, sem o barramento da sessão, com os comandos que escrevem no sistema recusando; o gate do painel pelo navegador está dentro dela, e nada entra no `dev` sem ela verde | [SPRINTS, «A regra de merge»](SPRINTS.md#a-regra-de-merge) |

---

## 2. O que é decisão de quem usa, e onde mora

Nada do que é escolha de quem usa mora no repositório. Usar o produto não vira commit.

| o quê | onde | quem escreve |
|---|---|---|
| todas as chaves (pack, flavor, cor de destaque, claro ou escuro, horários, o que esconder…) | `~/.config/meow/meow.conf` | o painel, o `--wizard`, ou à mão. O `meow.conf.exemplo` do repositório é só o de fábrica |
| a escolha de ícone por programa | `~/.config/meow/icones-escolhidos.map`, `icones-traco.map` e `icones-convertidos.map`, ao lado do `meow.conf` | o seletor e a oficina do painel |
| os desenhos enviados e os retoques da oficina | `~/.local/share/meowsystem/icones-enviados/`, `retoques/` e `convertidos-apps/` | o painel |
| os packs de quem usa | `~/.local/share/meowsystem/packs/<id>/` | `meow pack novo`, `meow pack importar` |
| os vizinhos (outros projetos que mandam em pedaços do home) | `~/.config/meow/vizinhos.conf` (o modelo é o `vizinhos.conf.exemplo`) | à mão; vazio é o normal |
| o que a máquina gerou (logs, a matriz dos builds, o estado do pós-apt) | `~/.local/state/meowsystem/` | o próprio MeowSystem |

**As decisões tomadas em nome de quem usa** têm o registro, com a pergunta, a decisão e a base
de cada uma, e se desfazem trocando a linha e o código que a lê:

- [`sprints/2026-10-09-uso-real/02-decisoes.md`](sprints/2026-10-09-uso-real/02-decisoes.md),
  1 a 12 (09 e 10/10/2026);
- a seção «Decisões» da [P82](sprints/2026-10-15-fechamento/P82-abertos.md), 13 a 49
  (15/10/2026).

**O que é da conta de quem usa, e não do projeto**, fica fora do repositório e é decidido só por
quem usa: o `NOPASSWD: ALL` do sudoers da conta (com a ponte root e o askpass ativo, ele deixou
de ser necessário para o MeowSystem, e o doctor só diz o estado — decisão 48 da P82), o
dispositivo de render do compositor (decisão 6) e o askpass da sessão (decisão 5).

---

## 3. O que ficou de fora, de propósito

Cada linha tem dono e porquê; nenhuma é esquecimento.

| o quê | por quê | registro |
|---|---|---|
| o nome do tema instalado continua `MeowSystem-Icons`, e só o exportado leva o nome do pack | é o nome que o COSMIC lê; trocá-lo mexeria no conf de toda casa sem ganho | decisão 31 (P82) |
| o som só na notificação | ninguém pediu som de dispositivo, de bloqueio nem de captura | decisão 33 (P82) |
| 52 nomes do tema Dracula antigo sem desenho | eram PNG (raster não é fonte) ou projeto pessoal; caem no ícone do próprio programa | decisão 35 (P82) |
| os leitores `${ICONES_BASE:-Papirus-Dark}` | é variável interna, com o mesmo padrão em todo lugar, e nenhum defeito medido | decisão 43 (P82) |
| projetos pessoais nos packs (os desenhos e as logos deles) | o pack é produto público; o que é de uma máquina mora no conf dela | regra de 23/09/2026; decisão 4 (09/10) e 16 (P82) |
| portar para GNOME ou KDE | o veredito de 21/09/2026 foi «não»: o produto é o COSMIC | [packs-modulares](sprints/2026-09-21-packs-modulares.md) |
| prompt, fastfetch, gatos e o traço do gerador de ícone como campo de pack | continuam do motor, iguais para todo pack, até um leitor perguntar ao pack | [PACKS, «O que ainda não é do pack»](PACKS.md#o-que-ainda-não-é-do-pack) |
| o patch binário de luz noturna do vizinho | não é da série, não tem marcador, e o modo de leitura o substituiu | [FRONTEIRA](FRONTEIRA.md) |

---

## 4. O que ainda está aberto

Escrito para não ser lido como pronto.

- **As sprints depois da leva H**: P88 (o formato de três pastas de ícone por pack), P87 (tudo
  o que foi achado e recuperado entra no pack) e P89 (o repositório enxuto). As specs e as
  decisões que elas pedem estão no `dev`. A P86 (a regra da vida) está na seção 6.
- **A numeração das decisões colide.** O `dev` acrescentou ao `02-decisoes.md` as decisões 13 a
  17 de 15/10/2026 (tudo para o pack, três pastas, derivados que se atualizam sozinhos, os
  achados da varredura, o repositório enxuto), e a P82 usou 13 a 49 para outras decisões. Quem
  integrar a leva H no `dev` renumera um dos dois lados.
- **Linhas do doctor que ainda dizem «rode:»**: as razões do `SEM_CONSERTO` (`ponte`,
  `ocultar`, `absolutos`, `convertidos` e `heroictema`) e algumas saídas de
  `icones_absolutos.sh`, `nomes_apps.sh` e `completar_icones.sh`. A integração da leva H as
  lista em [`01-integracao.md`](sprints/2026-10-15-fechamento/01-integracao.md).
- **Para conferir na máquina, depois de a leva H chegar ao `dev`**: o `./install.sh` rodar uma
  vez (só ele instala o `meow-builds-login.service` e reinstala a ponte root com a lista nova de
  pacotes), e o compositor no 4d14528 depois do primeiro gatilho.

---

## 5. Como ele se mantém

### O que roda sozinho, e quando

| quando | o quê | unidade |
|---|---|---|
| todo dia às 5h (e no boot seguinte, se a máquina estava desligada) | `meow doctor --consertar`: conserta o que estiver fora, e o build que faltar entra em segundo plano | `meow-doctor.timer` |
| depois de todo apt | o hook do apt toca um carimbo, e o pós-apt refaz em escopo de usuário o que o COSMIC novo desfez: o oráculo do tema, os builds do compositor e do `cosmic-files`, e no fim um `meow doctor --consertar` | `meow-pos-apt.path` |
| uma vez por login | o build que falta para a versão instalada (pega o apt feito pelo TTY ou com a sessão fechada) | `meow-builds-login.service` |
| todo apt, como root | o lançador: marca de novo os `.desktop` do sistema que o pacote reescreveu, e toca o carimbo do pós-apt | `/etc/apt/apt.conf.d/99-meow-lancador` |
| a cada minuto | o modo de leitura no degrau que o relógio pede | `meow-leitura.timer` |
| a cada 5 minutos | o gato da hora (dia e noite) | `meow-gato.timer` |
| 3 min depois do boot, e a cada 15 | o carrossel de papéis de parede volta se foi resetado | `meow-wallpaper.timer` |
| quando o painel do COSMIC cai, ou fica vivo sem desenhar | repõe o painel | `meow-painel.service` |
| quando um arquivo vigiado muda | o gato novo do acervo, o papel de parede apagado, o fundo que a janela de papel de parede reseta, o raio que não cabe na barra, o tema de ícones do Qt, a bandeja depois de um flatpak, os jogos da Steam e do Heroic no lançador | `meow-assets.path`, `meow-ativos.path`, `meow-fundo.path`, `meow-painel-raio.path`, `meow-qt.path`, `meow-flatpak.path`, `meow-steam.path`, `meow-heroic.path` |

`AUTO_REPARO="nao"` no `meow.conf` desliga o doctor das 5h, o pós-apt e o build do login.

### O que uma pessoa faz

1. **Atualizar o projeto**: `git pull` no clone e `meow ativar`. A segunda passada de um
   instalador que já convergiu não escreve nada.
2. **Atualizar a máquina**: `apt full-upgrade` à vontade. O que acontece depois de cada passo
   está em [`MANUTENCAO.md`](MANUTENCAO.md); `meow cosmic prever` diz antes se o COSMIC da fila
   vai receber a série.
3. **Quando a série de patches não entra numa versão nova**: a sessão segue no compositor de
   fábrica, sem nada quebrado, e o patch obrigatório precisa de um rebase em `patches/`, num
   commit. O próximo gatilho compila sozinho a mesma versão.
4. **Conferir**: `meow doctor`, ou a Início do painel. Mudança no projeto passa pela suíte
   inteira, `./tests/todos.sh`, antes do `dev`.

### O caminho de volta de cada coisa

| para voltar | faça |
|---|---|
| o tema do COSMIC de antes do MeowSystem | `meow desfazer` |
| o MeowSystem inteiro fora da máquina | `./install.sh --uninstall` |
| o compositor de fábrica no próximo login | `meow compositor desativar` (religar: `meow compositor ativar`) |
| o menu de fábrica do `cosmic-files` | `FILES_MENU="nao"` no `meow.conf` |
| sem ponte root (o sudo volta a ser pedido no terminal) | `PONTE_ROOT="nao"` no `meow.conf` |
| outro pack | `meow pack usar <id>`, ou o **Usar este** da Início |
| um pack importado fora | `meow pack remover <id>` |
| um ajuste ao valor de fábrica | **Restaurar ao padrão**, no cartão dele |

---

## 6. A regra da vida

O que mantém o MeowSystem vivo sem ninguém olhar, o que só uma pessoa faz, e como cada coisa
volta atrás. Veio da P86.

### O que roda sozinho, e quando

| quando | o quê | unidade |
|---|---|---|
| todo dia por volta do meio-dia (até 30 min de folga) | a sentinela lê `apt list --upgradable` (só leitura) e, havendo `cosmic-*` novo, mede o candidato com o `meow cosmic prever`: esquema, chaves, série de patches com a escada, ferramenta de build (`just`, `make` ou `cargo`) e `rust-version`. O resultado fica em `~/.local/state/meowsystem/sentinela.tsv`. A mesma fila não é medida duas vezes | `meow-sentinela.timer` |
| todo dia às 5h | o doctor conserta o que estiver fora | `meow-doctor.timer` |
| depois de todo apt | o pós-apt refaz o que o COSMIC novo desfez | `meow-pos-apt.path` |
| uma vez por login | o build que falta para a versão instalada | `meow-builds-login.service` |
| a cada tique do doctor, do pós-apt e do login | o cartão «Precisa de gente» se confere: a linha sai sozinha quando o problema some | os três de cima |

`AUTO_REPARO="nao"` no `meow.conf` desliga a sentinela junto com o resto.

### O que só uma pessoa faz

A Início tem **um cartão só**, «Precisa de gente», com uma linha por pendência, o desde quando
ao lado e o porquê atrás do **?**. Hoje duas coisas o alimentam:

1. **O COSMIC da fila não entra.** A sentinela mediu vermelho: um patch obrigatório não entra,
   uma chave que o MeowSystem grava sumiu do binário, falta ferramenta de build, ou o `rustc`
   ficou para trás. O cartão aparece antes do apt, e some quando a fila muda.
2. **Patch obrigatório precisa de rebase.** O COSMIC já instalado recusou o `req` (degrau 4 do
   `garantir_builds.sh`). A sessão segue no compositor de fábrica, sem nada quebrado, até um
   rebase em `patches/`. O cartão some quando o build da versão existe ou a série muda.

O resto não passa por ali: escolha de quem usa (tema de terceiro, papel de parede devolvido,
extensão de pack importado) continua pendência com botão. A regra de quem decide está no
[`GSD.md`](../GSD.md): decisão de quem usa só se desfaz com sim explícito sobre aquele tema, e o
`tests/decisoes.sh` fica vermelho se alguém a desfaz.

### O caminho de volta de cada coisa

| para voltar | faça |
|---|---|
| sem a sentinela | `AUTO_REPARO="nao"` no `meow.conf`, e `./install.sh` remove o timer; ou `systemctl --user disable --now meow-sentinela.timer` |
| ver o último resultado dela | `meow cosmic sentinela ler`, ou o `sentinela.tsv` |
| medir de novo o mesmo candidato | apague `~/.local/state/meowsystem/sentinela.tsv` |
| tirar uma linha do cartão | resolva a causa: ele se confere sozinho. O arquivo é `~/.local/state/meowsystem/precisa-de-gente.tsv` |
| desfazer uma decisão de quem usa | troque a linha em `02-decisoes.md` e o código que a lê, no mesmo commit, citando o sim; o `tests/decisoes.sh` acompanha |

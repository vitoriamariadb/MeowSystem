# O estado do MeowSystem

O que o projeto entrega, onde mora o que é de quem usa, o que fica de fora de propósito e como ele
se mantém. As decisões de quem usa estão em [`DECISOES.md`](DECISOES.md).

## 1. O que ele entrega

| área | o que faz | onde ler |
|---|---|---|
| **Instalador** | `./install.sh` veste a máquina inteira e converge: a segunda passada não escreve nada. Guarda cópia antes de escrever e recusa caminho que não conhece. `--wizard` pergunta as chaves essenciais, `--perfil <nome>` instala com um perfil, `MEOW_DRY_RUN=1` ensaia | [README](../README.md) |
| **Theme packs** | cores, ícones, base de ícones, ponteiro, som, papéis de parede, mascote, temas de dentro dos programas e o que se esconde do lançador vêm do pack, que é dado e nunca código. `meowsystem` (o padrão, Catppuccin) e `dracula` (com o claro Alucard) vêm com o projeto | [PACKS](PACKS.md) |
| **Segurança de pack** | todo caminho cai dentro do pack; link para fora e script são recusados; desenho de pack chega ao painel numa caixa de areia; extensão do VS Code de pack importado só se instala por gesto | [PACKS, «O que um pack não pode fazer»](PACKS.md#o-que-um-pack-não-pode-fazer) |
| **Painel** | `meow abrir`: cinco portas, **Tema**, **Personalizar**, **Definir**, **Manter** e **Extensões**. A interface mostra em vez de explicar; o porquê mora atrás do **?**. A barra de cima tem **Aplicar**, **Desfazer** e **Ver sem mudar**; a ação que escreve tem **Restaurar** ao lado; o resultado abre numa janela com **Parar** e **Guardar**; o que baixa da internet leva o selo | [app/LEIA-ME](../app/LEIA-ME.md) |
| **Doctor** | `meow doctor` confere sem escrever; `meow doctor --consertar` conserta o que estiver fora, sem mandar ninguém digitar. Roda sozinho às 5h, e o **Consertar** do painel é o mesmo gesto | [README](../README.md) |
| **Ponte root** | a senha do sudo uma vez, no instalador; depois, um conjunto fechado de verbos roda sem senha e sem terminal | [FRONTEIRA](FRONTEIRA.md) |
| **COSMIC vivo** | o compositor com a série de `patches/` e o menu do `cosmic-files` são builds da casa, refeitos sozinhos quando o apt traz versão nova; o shim escolhe a cada sessão entre o build e o de fábrica | [MANUTENCAO](MANUTENCAO.md), [COSMIC-THEMING](COSMIC-THEMING.md) |
| **Testes** | `./tests/todos.sh` roda a suíte numa casa de brinquedo, sem o barramento da sessão e com os comandos que escrevem no sistema recusando; o gate do painel pelo navegador está dentro dela | [AGENTS](../AGENTS.md) |

## 2. Onde mora o que é de quem usa

Usar o produto não vira commit.

| o quê | onde | quem escreve |
|---|---|---|
| as chaves (pack, flavor, destaque, modo, horários, o que esconder) | `~/.config/meow/meow.conf` | o painel, o `--wizard` ou à mão; o `meow.conf.exemplo` é o de fábrica |
| a escolha de ícone por programa | `~/.config/meow/icones-escolhidos.map`, `icones-traco.map`, `icones-convertidos.map` | o seletor e a oficina do painel |
| desenhos enviados e retoques | `~/.local/share/meowsystem/icones-enviados/`, `retoques/`, `convertidos-apps/` | o painel |
| os packs de quem usa | `~/.local/share/meowsystem/packs/<id>/` | `meow pack novo`, `meow pack importar` |
| os vizinhos (outros projetos que mandam em pedaços do home) | `~/.config/meow/vizinhos.conf`, modelo em `assets/contratos/vizinhos.conf.exemplo` | à mão; vazio é o normal |
| o que a máquina gerou (logs, matriz dos builds, sentinela, pendências) | `~/.local/state/meowsystem/` | o próprio MeowSystem |

O que é da conta, e não do projeto, só quem usa decide: o `NOPASSWD: ALL` do sudoers (decisão 43),
o dispositivo de render do compositor (decisão 6) e o askpass da sessão (decisão 5).

## 3. O que fica de fora, de propósito

| o quê | por quê | decisão |
|---|---|---|
| o tema instalado continua `MeowSystem-Icons`; só o exportado leva o nome do pack | é o nome que o COSMIC lê | 36 |
| o pack traz os sons do sistema; carregador e bateria pela ponte root | o COSMIC os toca de `/usr/share/sounds/Pop`, caminho cravado | 37 |
| 52 nomes do tema Dracula antigo sem desenho | eram PNG ou projeto pessoal; caem no ícone do próprio programa | 38 |
| projetos pessoais nos packs | o pack é produto público; o que é de uma máquina mora no conf dela | 4, 29 |
| GNOME e KDE | o produto é o COSMIC | |
| prompt, fastfetch e o traço do gerador de ícone como campo de pack | são do motor, iguais para todo pack, até um leitor perguntar ao pack | [PACKS, «O que ainda não é do pack»](PACKS.md#o-que-ainda-não-é-do-pack) |

## 4. Como ele se mantém

| quando | o quê | unidade |
|---|---|---|
| todo dia às 5h (ou no boot seguinte) | `meow doctor --consertar`; o build que faltar entra em segundo plano | `meow-doctor.timer` |
| por volta do meio-dia | a sentinela lê `apt list --upgradable` e, com `cosmic-*` novo, mede o candidato com `meow cosmic prever`; o resultado fica em `sentinela.tsv` | `meow-sentinela.timer` |
| depois de todo apt | o pós-apt refaz o que o COSMIC novo desfez (oráculo do tema, builds, doctor); a sentinela relê a fila | `meow-pos-apt.path`, `meow-sentinela.path` |
| todo apt, como root | o lançador remarca os `.desktop` que o pacote reescreveu | `/etc/apt/apt.conf.d/99-meow-lancador` |
| uma vez por login | o build que falta para a versão instalada | `meow-builds-login.service` |
| a cada minuto | o modo de leitura no degrau da hora | `meow-leitura.timer` |
| a cada 5 minutos | o mascote da hora | `meow-gato.timer` |
| 3 min depois do boot, e a cada 15 | o carrossel de papéis de parede volta se foi resetado | `meow-wallpaper.timer` |
| quando o painel do COSMIC cai | repõe o painel | `meow-painel.service` |
| quando um arquivo vigiado muda | acervo de mascote, papel apagado, fundo resetado, raio da barra, tema do Qt, bandeja do flatpak, jogos da Steam e do Heroic, derivados do pack | `meow-*.path` |

`AUTO_REPARO="nao"` no `meow.conf` desliga o doctor das 5h, a sentinela, o pós-apt e o build do
login.

O que só uma pessoa faz aparece na porta **Manter**, uma linha por pendência, e a linha sai
sozinha quando a causa some: o COSMIC da fila que não recebe a série, e o patch obrigatório que
precisa de rebase em `patches/`. Até lá a sessão segue no compositor de fábrica.

## 5. O caminho de volta

| para voltar | faça |
|---|---|
| o tema do COSMIC de antes do MeowSystem | `meow desfazer` |
| o MeowSystem inteiro fora da máquina | `./install.sh --uninstall` |
| o compositor de fábrica no próximo login | `meow compositor desativar` (religar: `meow compositor ativar`) |
| o menu de fábrica do `cosmic-files` | `FILES_MENU="nao"` no `meow.conf` |
| sem ponte root | `PONTE_ROOT="nao"` no `meow.conf` |
| outro pack | `meow pack usar <id>`, ou **Vestir** na porta Tema |
| um pack importado fora | `meow pack remover <id>` |
| um ajuste ao valor de fábrica | **Restaurar**, no cartão dele |
| uma decisão de quem usa | troque a linha em [`DECISOES.md`](DECISOES.md) e o código que a lê, no mesmo commit, citando o sim |

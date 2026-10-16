<div align="center">

<img src="docs/logo.svg" width="128" alt="A logo do MeowSystem: um gato de traço lilás dentro de um círculo">

# MeowSystem

**O COSMIC vestido inteiro, a partir de um theme pack, e um doctor que conserta sozinho.**

*Tudo o que ele escreve, ele sabe desfazer — e rodar de novo numa máquina pronta não escreve um byte.*

[![licença](https://img.shields.io/badge/licen%C3%A7a-GPL--3.0-CBA6F7?style=for-the-badge&labelColor=1E1E2E)](LICENSE)
[![plataforma](https://img.shields.io/badge/Pop!__OS%2024.04-COSMIC-89B4FA?style=for-the-badge&labelColor=1E1E2E)](https://github.com/pop-os/cosmic-epoch)
[![linguagens](https://img.shields.io/badge/bash%204.3+-python%203%20s%C3%B3%20stdlib-A6E3A1?style=for-the-badge&labelColor=1E1E2E)](install.sh)
![versão](https://img.shields.io/badge/vers%C3%A3o-v1.2.4-FAB387?style=for-the-badge&labelColor=1E1E2E)

[![instalador](https://img.shields.io/badge/instalador-63%20etapas-89DCEB?style=for-the-badge&labelColor=1E1E2E)](install.sh)
[![doctor](https://img.shields.io/badge/doctor-65%20confer%C3%AAncias-94E2D5?style=for-the-badge&labelColor=1E1E2E)](bin/meow)
[![conferência do navegador](https://img.shields.io/badge/navegador-123%2F123-F5C2E7?style=for-the-badge&labelColor=1E1E2E)](tests/app-navegador.py)

Tema, ícones, painel, dock, terminal, tela de login, papel de parede e os temas de dentro dos
programas, no Pop!_OS com COSMIC, num instalador só, e um painel local para mexer em tudo sem
abrir um arquivo de texto.

As cores vêm de um **theme pack**: um diretório de dados, sem nenhuma linha de código. O
Catppuccin é o pack padrão; o Dracula vem completo, com o lado claro (Alucard). O que um pack
não declara ele herda, e `meow pack info` diz, categoria por categoria, o que veio de onde. O
formato está em **[docs/PACKS.md](docs/PACKS.md)**.

<img src="docs/capturas/painel.png" width="920" alt="O painel de configuração do MeowSystem, na tela inicial">

[English](README.en.md) · [Manual completo](docs/) · [Estado final](docs/ESTADO-FINAL.md) · [Créditos](docs/CREDITOS.md) · GPL-3.0

</div>

---

## Instalar

```bash
git clone https://github.com/vitoriamariadb/MeowSystem.git
cd MeowSystem
./install.sh --wizard     # a primeira vez: pergunta cinco coisas e instala
meow ativar               # todas as outras
```

São 63 etapas. Rodar de novo numa máquina já pronta **não escreve um byte** — e diz isso, em vez
de listar as etapas como se as tivesse refeito. Para ver o que aconteceria antes de deixar
acontecer: `MEOW_DRY_RUN=1 ./install.sh`, ou o **Ver o que faria** do painel.

A senha do sudo é pedida **uma vez**, no instalador, para registrar a ponte root: um conjunto
fechado de verbos (marcar `.desktop` do sistema, vestir a tela de login, o hook do apt, os
pacotes de que o projeto depende) que depois rodam sem senha e sem terminal. `PONTE_ROOT="nao"`
no `meow.conf` tira a ponte na passagem seguinte.

## Os packs

```bash
meow pack listar                      # os packs instalados, e se cada um valida
meow pack usar dracula                # troca o pack da máquina e aplica
meow pack usar catppuccin latte       # com o flavor escolhido
meow pack exportar dracula            # um .meowpack para levar a outra máquina
meow pack importar meu-tema.meowpack  # confere tudo antes de pôr no disco
meow pack remover meu-tema            # tira um pack importado
meow pack exportar-tema dracula       # o tema de ícones montado, para usar sem o MeowSystem
```

No painel, a **Início** abre com um cartão por pack: o logo, a paleta, o que ele traz e o que
herda. **Usar este** troca o pack; o cartão do pack no ar tem o anel de acento. Trocar de pack
leva junto o que é do pack — a base de ícones, o ponteiro, o som, o que ele esconde do lançador
— e devolve o que o pack anterior escondia.

**Um pack é dado, nunca código.** Nada dentro dele é executado: todo caminho tem de cair dentro
do pack, link para fora é recusado, script é recusado, e o desenho de um pack de terceiro é
servido ao painel numa caixa de areia. Um pack importado que pede uma extensão do VS Code mostra
a extensão, e ela só se instala por um gesto naquela extensão.

## O painel

```bash
meow abrir                # ou o ícone MeowSystem no lançador
```

122 ajustes e 64 ações em catorze páginas: a Início e treze de assunto, cada uma com tudo o que
existe sobre ele. O menu tem dois blocos: **Tópicos**, que é a sua tela, e **Sistema**, que é o
que a máquina faz sozinha.

### A interface mostra, em vez de explicar

<img src="docs/capturas/painel-leitura.png" width="920" alt="A aba Modo de leitura: o desenho mostra a mesma página fria à esquerda e quente à direita">

Na tela fica só o que nomeia ou mede: título, rótulo, valor. O porquê de cada coisa mora atrás de
um **?**, que abre a dica. Cada bloco abre com uma prévia que responde «o que isto faz com a
minha tela?», desenhada a partir dos valores de verdade — o papel de parede da coleção, o gato do
acervo, o ícone do tema instalado — e ela **repinta enquanto você arrasta o deslizante**.

Quando há uma escolha esperando, a prévia vira duas: **Como está** e **Como fica**, lado a lado.
Apertar «Como está» desfaz aquele bloco e só aquele.

### O que dá para fazer aqui

<img src="docs/capturas/painel-areas.png" width="920" alt="A aba Áreas de trabalho, com o desenho da barra e das duas telas acima dos ajustes">

- **Ícones** — um ícone por programa instalado, trocável um a um. O seletor mostra o acervo
  inteiro, em pastas: os desenhos de cada pack (o no ar primeiro), a biblioteca, os feitos à mão,
  o traço do Arcticons, os resgatados e os que você enviou. O desenho que veste o programa agora
  vem marcado.
- **Papel de parede** — a coleção e as ações dela na mesma tela. Soltar um arquivo diz na hora se
  ele entrou no grupo de dia ou no de noite, e **Dia** e **Noite** mandam a imagem para o lado
  que você quiser.
- **Áreas de trabalho** — o nome e a **ordem** das suas áreas, e o encaixe de janelas de cada
  uma.
- **Modo de leitura** — a tela quente da noite: temperatura, textura, horário e a rampa da
  virada.
- **Instalar sem sair do painel** — um `.zip` de tema de ponteiro, uma fonte, um tema de ícones,
  um gato novo, um papel de parede, um ícone. O arquivo enviado nunca toca o repositório: ele
  mora no seu estado, em `~/.local/share/meowsystem/`.
- E **Cor e tela**, **Logo do sistema**, **Painel e dock**, **Dia e noite**, **Terminal**,
  **Lançadores e jogos**, **Manutenção**, **Instalação** e **Atualização** — esta última com
  `apt`, `flatpak` e `cargo` numa tela e, logo depois, o `doctor` consertando o que a
  atualização desfez.

Toda variável que o instalador lê tem um controle aqui — e um teste cobra isso, para que uma
chave nova não nasça invisível.

Clicar não muda a máquina: as escolhas se acumulam, e **Salvar e aplicar** grava tudo e roda o
instalador na mesma hora. **Ver o que faria** ensaia antes, sem escrever nada. **Restaurar ao
padrão** volta ao valor de fábrica. Ação que baixa da internet leva o selo dela.

<img src="docs/capturas/painel-forma.png" width="920" alt="A aba Painel e dock, com o desenho do painel e da dock acima dos controles">

## O que ele veste

| | |
|---|---|
| **As cores** | De um theme pack: `pack.json` e `paleta.json` com 26 slots nomeados. Catppuccin (latte, frappé, macchiato, mocha) e Dracula (dracula e o claro alucard) vêm com o projeto; o seu mora em `~/.local/share/meowsystem/packs`. |
| **O tema do COSMIC** | As quatro árvores, aplicadas por cópia de arquivo. Claro e escuro são o mesmo tema com um interruptor, e com `MODO=claro` o lado claro do pack veste também o traço do dock e as pastas. |
| **A tela de login** | O `cosmic-greeter` tem configuração própria, e a ponte a veste. |
| **Painel e dock** | Forma, raio, margem, espaço e recheio de cada segmento; o vidro que segue o COSMIC instalado, **na barra e na janela**; os segundos no relógio; e a música tocando ao lado dele, com capa e controles. E um vigia que repõe a barra quando ela cai **ou quando fica viva sem desenhar**. |
| **As áreas de trabalho** | Nome, ordem e encaixe de cada uma. A ordem da lista é a ordem da barra. |
| **Os ícones** | A base vem do pack (o Papirus no Catppuccin; os `dracula-icons` no Dracula, o ramo `circle` por cima do `main`), as pastas e os tipos de arquivo na paleta do pack, e um desenho por programa — trocável um a um, pelo painel. |
| **O terminal** | As dezesseis cores, o prompt do `starship`, as cores do `fzf`, e o gato no lugar do logo do `fastfetch`, redesenhado em caracteres a cada geração. |
| **O papel de parede** | Um carrossel com pastas de dia e de noite separadas por luminosidade, avançar e voltar no botão direito, e favoritos. O pack pode trazer os dele. |
| **Dia e noite** | À noite o gato do dock e o do terminal trocam de rosto, a imagem de fundo passa às escuras e o modo de leitura esquenta a tela e lhe dá textura de papel, em rampa — cada um com o seu horário, todos das 18:00 às 07:00 de fábrica. |
| **Os programas** | Spotify, VS Code, Obsidian, qBittorrent, Heroic, Telegram, Discord (Vesktop e Vencord), OnlyOffice, kitty, GNOME Terminal, ZapZap, btop e bat no tema do pack no ar; os jogos da Steam e os do Heroic com um atalho por jogo no lançador, com a capa, e o atalho saindo junto com o jogo. |

## A máquina

<table>
<tr>
<td width="50%"><img src="docs/capturas/desktop.jpg" alt="A área de trabalho com a barra e a dock"></td>
<td width="50%"><img src="docs/capturas/desktop-claro.png" alt="A mesma área de trabalho no tema claro"></td>
</tr>
<tr>
<td><img src="docs/capturas/fastfetch.png" alt="O fastfetch com o gato desenhado em caracteres"></td>
<td><img src="docs/capturas/lancador.jpg" alt="O lançador com os ícones do Arcticons"></td>
</tr>
</table>

## O doctor conserta

```bash
meow doctor                            # 65 conferências. Não escreve nada.
meow doctor --consertar                # conserta o que estiver fora do lugar
meow desfazer                          # devolve o tema de antes desta máquina
./install.sh --uninstall               # tira tema, ícones e agendamentos
```

O `doctor` não manda ninguém digitar nada: o que ele sabe consertar, o `--consertar` conserta, e
a linha diz o estado. Ele roda sozinho todo dia às 5h, e o **Consertar** do painel é o mesmo
gesto. O que precisa da rede leva, no painel, o selo de quem baixa da internet.

Cada escrita em arquivo do sistema deixa uma cópia antes, e o instalador **recusa por caminho** —
não por boa intenção — escrever fora dos lugares que ele conhece.

## O COSMIC pode atualizar

O MeowSystem mantém dois builds próprios: o compositor (`cosmic-comp` com a série de `patches/`)
e o menu de papel de parede do `cosmic-files`. Quando o apt traz uma versão nova do COSMIC, o
build é refeito sozinho, sem sudo e sem pergunta — depois do apt, no login seguinte e no doctor
das 5h, pela mesma função. A sessão aberta segue com o binário antigo, e o novo vale no próximo
login. Patch que não entra na versão nova não troca nada: a sessão sobe com o compositor de
fábrica até a série ser refeita.

Pode rodar `apt full-upgrade` à vontade. O que acontece depois de cada passo da cadeia de
atualização, e como voltar, está em **[docs/MANUTENCAO.md](docs/MANUTENCAO.md)**.

## O que esperar

Este repositório nasceu para uma máquina — **Pop!_OS 24.04 LTS com COSMIC** — e boa parte do
trabalho desde então foi tirar dele o que só valia ali. O que sobrou de acoplamento está escrito,
não escondido, e o `doctor` fala antes de você descobrir na tela.

O que ele derruba sozinho, em vez de exigir da sua máquina:

- **as cores** saem de um theme pack, não de um nome cravado no código;
- **o que não existe aqui é pulado, não é erro**: sem painel configurado, sem tema em disco, sem
  Steam, sem Heroic, cada etapa diz o que pulou e segue;
- **o COSMIC que você tem decide o caminho**: onde há chave nativa para um ajuste, é ela que é
  escrita; o remendo só entra onde a chave ainda não existe;
- **nada é aplicado sem cópia do que havia antes**, e o `--wizard` pergunta só as cinco chaves
  essenciais — `FLAVOR`, `ACCENT`, `MODO`, `LANCADOR_SISTEMA` e `PONTE_ROOT`. O `LOGO`, que o
  instalador também exige, vem preenchido do `meow.conf.exemplo` e não precisa de resposta.

Se a sua máquina é um COSMIC, instale.

## Requisitos

Pop!_OS 24.04 LTS · COSMIC (medido do 1.0 ao 1.10) · `bash`, `python3` e `apt`. Os builds
próprios pedem o `cargo`, e quem compila o instala pelo rustup quando falta. O painel abre no
navegador que já estiver instalado, e só escuta em `127.0.0.1`.

## Créditos

O MeowSystem é uma casca: quase tudo o que aparece na tela foi desenhado por outra pessoa, sob uma
licença que permite isso. Os maiores:

- [Catppuccin](https://github.com/catppuccin/catppuccin) — a paleta do pack padrão (MIT)
- [Dracula](https://draculatheme.com) — a paleta do pack Dracula, e os [`dracula-icons`](https://github.com/m4thewz/dracula-icons) como base de ícones dele (GPL-3.0)
- [Arcticons](https://github.com/Donnnno/Arcticons) — os glifos dos programas e do painel (CC BY-SA 4.0)
- [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) — a base de ícones do Catppuccin (GPL-3.0)
- [catppuccin/papirus-folders](https://github.com/catppuccin/papirus-folders) — as pastas coloridas, pinado em `f83671d1`

**A lista inteira está em [`docs/CREDITOS.md`](docs/CREDITOS.md)** e no `CREDITOS.md` de cada
pack — os cursores, as fontes, os papéis de parede, os temas de dentro dos programas, o que foi
recusado e por quê, e o que você precisa fazer se redistribuir alguma coisa daqui.

Licença: GPL-3.0.

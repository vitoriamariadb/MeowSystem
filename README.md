<div align="center">

<img src="docs/logo.svg" width="128" alt="A logo do MeowSystem: um gato de traço lilás dentro de um círculo">

# MeowSystem

**O COSMIC vestido inteiro, a partir de um theme pack, e um doctor que conserta sozinho.**

*Tudo o que ele escreve, ele sabe desfazer — e rodar de novo numa máquina pronta não escreve um byte.*

[![licença](https://img.shields.io/badge/licen%C3%A7a-GPL--3.0-CBA6F7?style=for-the-badge&labelColor=1E1E2E)](LICENSE)
[![plataforma](https://img.shields.io/badge/Pop!__OS%2024.04-COSMIC-89B4FA?style=for-the-badge&labelColor=1E1E2E)](https://github.com/pop-os/cosmic-epoch)
[![linguagens](https://img.shields.io/badge/bash%204.3+-python%203%20s%C3%B3%20stdlib-A6E3A1?style=for-the-badge&labelColor=1E1E2E)](install.sh)
![versão](https://img.shields.io/badge/vers%C3%A3o-v1.2.4-FAB387?style=for-the-badge&labelColor=1E1E2E)

[![instalador](https://img.shields.io/badge/instalador-66%20etapas-89DCEB?style=for-the-badge&labelColor=1E1E2E)](install.sh)
[![doctor](https://img.shields.io/badge/doctor-69%20confer%C3%AAncias-94E2D5?style=for-the-badge&labelColor=1E1E2E)](bin/meow)
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

São 66 etapas. Numa máquina já pronta, rodar de novo **não escreve um byte** e diz isso. Para
ensaiar antes: `MEOW_DRY_RUN=1 ./install.sh`, ou **Ver sem mudar** no painel.

A senha do sudo é pedida **uma vez**, para registrar a ponte root: um conjunto fechado de verbos
(`.desktop` do sistema, tela de login, hook do apt, dependências) que depois roda sem senha.
`PONTE_ROOT="nao"` no `meow.conf` tira a ponte na passagem seguinte.

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

No painel, a **Início** mostra um cartão por pack: logo, paleta, o que traz e o que herda.
**Usar este** troca o pack. A troca leva o que é do pack (base de ícones, ponteiro, som, o que ele
esconde do lançador) e devolve o que o anterior escondia.

**Um pack é dado, nunca código.** Nada dele é executado: caminho tem de cair dentro do pack, link
para fora e script são recusados, e o desenho de um pack de terceiro é servido numa caixa de
areia. Extensão do VS Code pedida por pack importado só se instala por um gesto nela.

## O painel

```bash
meow abrir                # ou o ícone MeowSystem no lançador
```

122 ajustes e 67 ações em catorze páginas: a Início e treze de assunto. O menu tem dois blocos:
**Tópicos** (a sua tela) e **Sistema** (o que a máquina faz sozinha).

### A interface mostra, em vez de explicar

<img src="docs/capturas/painel-leitura.png" width="920" alt="A aba Modo de leitura: o desenho mostra a mesma página fria à esquerda e quente à direita">

Na tela fica só título, rótulo e valor. O porquê mora atrás do **?**. Cada bloco abre com uma
prévia desenhada com os valores de verdade (o papel de parede, o gato, o ícone instalado), que
**repinta enquanto você arrasta o deslizante**.

Com uma escolha pendente, a prévia vira duas: **Como está** e **Como fica**. «Como está» desfaz
só aquele bloco.

### O que dá para fazer aqui

<img src="docs/capturas/painel-areas.png" width="920" alt="A aba Áreas de trabalho, com o desenho da barra e das duas telas acima dos ajustes">

- **Ícones**: um por programa, trocável um a um. O seletor mostra o acervo inteiro em pastas
  (cada pack, o no ar primeiro; biblioteca; feitos à mão; Arcticons; resgatados; enviados). O
  desenho em uso vem marcado.
- **Papel de parede**: a coleção e as ações. Um arquivo solto entra no grupo de dia ou de noite,
  e **Dia** e **Noite** o mudam de lado.
- **Áreas de trabalho**: nome, **ordem** e encaixe de janelas de cada uma.
- **Modo de leitura**: temperatura, textura, horário e rampa da tela quente da noite.
- **Instalar pelo painel**: tema de ponteiro (`.zip`), fonte, tema de ícones, gato, papel de
  parede, ícone. O enviado mora em `~/.local/share/meowsystem/`, nunca no repositório.
- E **Cor e tela**, **Logo do sistema**, **Painel e dock**, **Dia e noite**, **Terminal**,
  **Lançadores e jogos**, **Manutenção**, **Instalação** e **Atualização** (`apt`, `flatpak` e
  `cargo`, seguidos do `doctor`).

Toda variável que o instalador lê tem um controle aqui, e um teste cobra isso.

Clicar não muda a máquina: as escolhas se acumulam e **Salvar e aplicar** grava e roda o
instalador. **Ver sem mudar** ensaia sem escrever. **Restaurar ao padrão** volta ao valor de
fábrica. Ação que baixa da internet leva o selo de rede.

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
meow doctor                            # 69 conferências. Não escreve nada.
meow doctor --consertar                # conserta o que estiver fora do lugar
meow desfazer                          # devolve o tema de antes desta máquina
./install.sh --uninstall               # tira tema, ícones e agendamentos
```

O `doctor` não manda digitar: o que ele sabe consertar, o `--consertar` conserta. Roda sozinho
às 5h, e o **Consertar** do painel é o mesmo gesto.

Toda escrita em arquivo do sistema guarda uma cópia antes, e o instalador **recusa por caminho**
escrever fora dos lugares que conhece.

## O COSMIC pode atualizar

Dois builds são próprios: o compositor (`cosmic-comp` com a série de `patches/`) e o menu de
papel de parede do `cosmic-files`. Quando o apt traz um COSMIC novo, o build se refaz sozinho,
sem sudo: depois do apt, no login seguinte e no doctor das 5h. O binário novo vale no próximo
login. Patch que não entra na versão nova não troca nada: a sessão sobe com o compositor de
fábrica.

`apt full-upgrade` à vontade. A cadeia de atualização e como voltar: **[docs/MANUTENCAO.md](docs/MANUTENCAO.md)**.

## O que esperar

Feito para **Pop!_OS 24.04 LTS com COSMIC**. O acoplamento que sobrou está escrito, e o `doctor`
avisa antes da tela.

- **as cores** saem de um theme pack, não do código;
- **o que não existe é pulado, não é erro**: sem Steam, sem Heroic, sem tema em disco, cada etapa
  diz o que pulou e segue;
- **o COSMIC instalado decide o caminho**: chave nativa quando existe, remendo só onde não;
- **nada se aplica sem cópia do que havia**, e o `--wizard` pergunta só cinco chaves: `FLAVOR`,
  `ACCENT`, `MODO`, `LANCADOR_SISTEMA` e `PONTE_ROOT` (o `LOGO` vem do `meow.conf.exemplo`).

Se a sua máquina é um COSMIC, instale.

## Requisitos

Pop!_OS 24.04 LTS · COSMIC (medido do 1.0 ao 1.10) · `bash`, `python3` e `apt`. Os builds
próprios pedem o `cargo`, e quem compila o instala pelo rustup quando falta. O painel abre no
navegador que já estiver instalado, e só escuta em `127.0.0.1`.

## Créditos

Quase tudo o que aparece na tela foi desenhado por outras pessoas, sob licenças que permitem
isso. Os maiores:

- [Catppuccin](https://github.com/catppuccin/catppuccin) — a paleta do pack padrão (MIT)
- [Dracula](https://draculatheme.com) — a paleta do pack Dracula, e os [`dracula-icons`](https://github.com/m4thewz/dracula-icons) como base de ícones dele (GPL-3.0)
- [Arcticons](https://github.com/Donnnno/Arcticons) — os glifos dos programas e do painel (CC BY-SA 4.0)
- [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) — a base de ícones do Catppuccin (GPL-3.0)
- [catppuccin/papirus-folders](https://github.com/catppuccin/papirus-folders) — as pastas coloridas, pinado em `f83671d1`

**A lista inteira está em [`docs/CREDITOS.md`](docs/CREDITOS.md)** e no `CREDITOS.md` de cada
pack: cursores, fontes, papéis de parede, temas de programas, o recusado e o que fazer ao
redistribuir.

Licença: GPL-3.0.

# Procedência dos temas btop e bat

Dois apps, um módulo só. Nenhum dos dois estava instalado quando isto foi escrito
(2026-08-04) — os arquivos já ficam aqui vendorizados para que o dia da instalação
seja só `meow_app_aplicar`, sem rede.

## Origem

| | bat | btop |
|---|---|---|
| repositório | <https://github.com/catppuccin/bat> | <https://github.com/catppuccin/btop> |
| **commit pinado** | `6810349b28055dce54076712fc05fc68da4b8ec0` | `f437574b600f1c6d932627050b15ff5153b58fa3` |
| ref | `refs/heads/main` (o repo não tem UMA tag) | `refs/heads/main` |
| tag mais recente | — | `1.0.0` -> `89ff712eb62747491a76a7902c475007244ff202` |
| licença | MIT (Catppuccin) | MIT (Catppuccin) |
| baixado em | 2026-08-04 | 2026-08-04 |

Os dois repositórios foram conferidos por WebFetch **antes** do download, e os SHAs
vieram de `git ls-remote`, não de memória. O `catppuccin/bat` não publica release
nenhuma: só dá para prender pelo SHA. O `catppuccin/btop` tem a tag `1.0.0`, mas ela
é anterior ao `main` atual — pinamos o `main` medido e deixamos a tag registrada
aqui para o dia em que alguém quiser recuar.

Pinar, e não seguir `main`, é a mesma regra do `scripts/baixar_upstream.sh`: um
upstream que muda sozinho transforma "rodei o instalador" em "rodei o instalador num
dia em que o repositório estava de um jeito".

## Arquivos vendorizados

Todos os quatro flavors dos dois apps, em `upstream/`. Integridade em `SHA256SUMS`:

```sh
cd app-themes/btop-bat && sha256sum -c SHA256SUMS
```

Para rebaixar tudo nos commits pinados e regravar o `SHA256SUMS`:

```sh
. app-themes/btop-bat/manifesto.sh && _bb_rebaixar_upstream
```

Vendorizamos os **quatro** flavors, e não só o mocha como no módulo qbittorrent.
O motivo é o custo: lá era um blob binário de 6 KB por flavor e a escolha já estava
feita; aqui são arquivos de texto (273 KB somados) e o módulo tem a chave
`MEOW_FLAVOR`. Faltar um flavor significaria uma viagem à rede no dia em que ela
mudar de ideia — que é exatamente o que este diretório existe para evitar.

## Como cada app acha o tema (lido no fonte, não no README)

**btop** — `src/btop_theme.cpp` da v1.3.0, que é a versão do apt nesta máquina.
`setTheme()` casa o valor de `color_theme` de três jeitos: caminho absoluto,
`p.stem()` (`catppuccin_mocha`) ou `p.filename()` (`catppuccin_mocha.theme`).
Gravamos o **stem**: o caminho absoluto funcionaria, mas engessaria o `$HOME` dentro
do arquivo de config, e nesta máquina os discos já trocaram de letra uma vez.

**bat** — o nome que vai em `--theme` é o `<key>name</key>` de dentro do plist, não o
nome do arquivo. Conferido com `plistlib`: `Catppuccin Mocha`. E o tema só passa a
existir depois de `bat cache --build`, que compila `<config-dir>/themes/*` em
`<cache-dir>/themes.bin`. Sem esse passo o bat ignora o `--theme` calado.

**Nos dois, a ÚLTIMA linha vence** — medido, e é o que decide como o merge funciona:

| arquivo | conteúdo | resultado medido |
|---|---|---|
| config do bat | `--theme="Catppuccin Mocha"` e depois `--theme="Dracula"` | keyword em `#ff79c6` (Dracula) |
| config do bat | a ordem inversa | keyword em `#cba6f7` (Catppuccin) |
| `btop.conf` | `color_theme` = mocha e depois latte | o btop carregou **latte** e regravou o arquivo com ele |

Por isso o módulo julga e reescreve a **última** ocorrência da chave, não a primeira:
reescrever a primeira e deixar outra embaixo gravaria uma linha decorativa, e o
`conferir` diria "aplicado" com a tela dela mostrando outro tema.

## Armadilhas medidas nesta máquina

### 1. No Ubuntu, o `bat` chama-se `batcat`

`dpkg-deb -c bat_0.24.0-1build1_amd64.deb` lista **um** binário, e ele é
`./usr/bin/batcat` — o nome `bat` já é do `bacula-console-qt`. Ou seja:
`command -v bat` continua falhando depois de `sudo apt install bat`. Um módulo que
detectasse só por `bat` devolveria 3 para sempre sem nunca dar erro. O
`_bb_bat_bin()` procura os dois nomes.

O que o rename **não** muda: o NOME do diretório continua `bat`. O que muda é ONDE ele
fica, e a primeira versão deste módulo errava isso. Medido com o binário do `.deb`:

| pergunta ao binário | cadeia observada |
|---|---|
| `bat --config-dir` | `BAT_CONFIG_DIR` > `$XDG_CONFIG_HOME/bat` > `~/.config/bat` |
| `bat --cache-dir` | `BAT_CACHE_PATH` > `$XDG_CACHE_HOME/bat` > `~/.cache/bat` |
| `bat --config-file` | `BAT_CONFIG_PATH` > `<config-dir>/config` |

Cravar `~/.config/bat` significaria, no dia em que ela exportasse `XDG_CONFIG_HOME`,
instalar o tema num diretório em que o bat nem olha — e o módulo jurando "aplicado".
Por isso os três caminhos são **perguntados ao binário**, com a cadeia acima só como
reserva para um bat velho demais para as flags. Testado: com `XDG_CONFIG_HOME` e
`XDG_CACHE_HOME` apontando para outro lugar, o tema cai lá e o bat de verdade
renderiza `#cba6f7`.

### 1b. `BAT_THEME` no ambiente VENCE o arquivo de config

Também medido, e também o contrário do que este módulo afirmava antes: com
`--theme="Catppuccin Mocha"` no config e `BAT_THEME=Dracula` exportado, a keyword saiu
`#ff79c6`. O conserto — tirar a variável do shell dela — mora em `~/.config/zsh`,
território proibido. Então nesse caso o bat devolve **3**, com a linha exata que
resolve: `0` seria mentira e `1` faria o self-heal tentar de hora em hora sem nunca
conseguir, que é a armadilha de idempotência nº 1 da casa.

Não criamos `alias bat=batcat`: o lugar disso seria o `~/.config/zsh`, que é o repo
Andromeda com auto-commit de 10 em 10 minutos — território proibido pela TRAVA 1 do
`lib/comum.sh`. O módulo avisa na tela; a decisão é dela.

### 2. O btop reescreve o `btop.conf` inteiro ao sair — comprovado

Não é teoria. No teste, o `btop.conf` tinha **1 linha** (só o `color_theme` que
gravamos); depois de rodar o btop por 4 s num pty, passou a ter **244 linhas**, com
todos os comentários e chaves default dele — e o nosso `color_theme =
"catppuccin_mocha"` sobreviveu, porque ele regrava o valor que carregou.

A consequência perigosa é a outra ponta: se o btop estiver **aberto** enquanto o
módulo aplica, o que ele tem em memória é o config antigo, e ao fechar ele apaga o
que acabamos de gravar. Por isso `meow_app_aplicar` avisa quando encontra um btop
vivo — e **avisa**, não mata o processo dela.

O `pgrep` é `-x btop`, nunca `-f btop`: sem âncora, `-f` casaria qualquer comando que
só cite "btop", inclusive o shell que roda o módulo. "btop" tem 4 caracteres, bem
abaixo do corte de 15 do `/proc/PID/comm`, então o `-x` é seguro aqui.

### 3. O acento do upstream é AZUL, o da casa é mauve

Mesmo achado do módulo qbittorrent. No `catppuccin_mocha.theme`:

```
theme[hi_fg]="#89b4fa"        # blue — atalhos de teclado
theme[selected_fg]="#89b4fa"  # blue — linha selecionada
```

É Catppuccin Mocha legítimo, mas acentuado em **blue**. O MeowSystem-Theme é Mocha
**+ accent mauve `#CBA6F7`**.

Por padrão instalamos o upstream **byte a byte** — é o que o `SHA256SUMS` promete.
Quem quiser o acento da casa liga `MEOW_BTOP_ACENTO=mauve`: aí um tema **derivado**
(`meowsystem_mocha.theme`) é gerado na hora a partir do vendorizado, trocando só
essas duas chaves, e o `color_theme` passa a apontar para ele. O derivado é gerado e
não vendorizado de propósito: não existe uma segunda cópia para desincronizar do
upstream. (O `catppuccin_mocha.theme` só fica instalado do lado se uma passagem
anterior, sem a variável, já o tiver instalado — com `mauve` desde o começo o módulo
instala apenas o derivado.)

O `#89b4fa` de `proc_box` **não** entra na troca: ali ele é a cor da borda da caixa
de processos, parte do rodízio cpu=mauve / mem=verde / net=vermelho / proc=azul —
não é acento. O `sed` é ancorado na chave inteira justamente para não pegá-lo, nem
os `#89b4fa` dos gradientes.

**No bat não existe esse ajuste, de propósito.** Lá as cores são semânticas
(keyword, string, comentário), não "acento" — e o mauve `#CBA6F7` já é a cor de
keyword, com 19 ocorrências no arquivo. Mexer seria estragar realce de sintaxe
achando que se está trocando um acento.

## Instalação dos apps (não rodada por este módulo)

```sh
sudo apt install btop bat
```

Versões que o apt do Pop!_OS 24.04 oferece hoje: `btop 1.3.0-1` e
`bat 0.24.0-1build1`, ambas de `noble/universe`. Depois de instalar, é só rodar o
módulo: ele instala os temas, faz o merge das duas configs e roda o
`bat cache --build`.
